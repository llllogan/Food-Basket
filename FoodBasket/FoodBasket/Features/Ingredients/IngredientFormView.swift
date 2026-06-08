//
//  IngredientFormView.swift
//  Food Basket
//
//  Created by Codex on 31/5/2026.
//

import SwiftData
import SwiftUI
import ImagePlayground
import UIKit

struct IngredientFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
    @Query(sort: \IngredientCategory.name) private var categories: [IngredientCategory]

    let onSave: ((Ingredient) -> Void)?

    @State private var name = ""
    @State private var selectedCategoryID: UUID?
    @State private var newCategoryName = ""
    @State private var showingNewCategoryAlert = false
    @State private var locallyCreatedCategories: [IngredientCategory] = []
    @State private var categorySuggestionState: CategorySuggestionState = .idle
    @State private var suggestedCategoryID: UUID?
    @State private var manuallySelectedCategoryName: String?
    @State private var draftPhotoData: Data?
    @State private var draftPhotoSource: IngredientDraftPhotoSource = .none
    @State private var isGeneratingImage = false
    @State private var activeImageGenerationID: UUID?
    @State private var showingCamera = false
    @State private var showingCameraUnavailable = false
    @State private var didFinish = false

    init(onSave: ((Ingredient) -> Void)? = nil) {
        self.onSave = onSave
    }

    private var categorySelection: Binding<UUID?> {
        Binding {
            selectedCategoryID
        } set: { newValue in
            guard newValue != selectedCategoryID else { return }
            selectCategory(newValue, manually: true)
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var categorySuggestionKey: String {
        let categoryKey = categories
            .map(\.normalizedName)
            .joined(separator: "|")
        return "\(canSuggestCategory)|\(trimmedName.normalizedLookupValue)|\(categoryKey)"
    }

    private var imageGenerationKey: String {
        "\(supportsImagePlayground)|\(trimmedName.normalizedLookupValue)"
    }

    private var canSuggestCategory: Bool {
        IngredientCategorySuggestionService.isAvailable
    }

    private var canGenerateIngredientImage: Bool {
        supportsImagePlayground && !trimmedName.isEmpty && !isGeneratingImage
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 18) {
                    IngredientDraftPhotoThumbnail(
                        photoData: draftPhotoData,
                        isGenerating: isGeneratingImage
                    )

                    HStack(spacing: 8) {
                        if supportsImagePlayground {
                            IngredientPhotoActionButton(
                                title: "Regenerate",
                                systemImage: "wand.and.sparkles",
                                isDisabled: !canGenerateIngredientImage
                            ) {
                                regenerateDraftImage()
                            }
                        }

                        IngredientPhotoActionButton(
                            title: "Take Photo",
                            systemImage: "camera",
                            isDisabled: false
                        ) {
                            takePhoto()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
            
            Section("Ingredient") {
                TextField("Name", text: $name)
            }

            Section {
                Picker(selection: categorySelection) {
                    Text("None").tag(nil as UUID?)

                    ForEach(categories) { category in
                        Text(category.name).tag(category.id as UUID?)
                    }
                } label: {
                    HStack(spacing: 6) {
                        if categorySuggestionState == .generating {
                            ProgressView()
                                .controlSize(.small)
                        } else if case .suggested(_) = categorySuggestionState {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.purple)
                        }

                        Text("Category")
                    }
                }

                Button {
                    newCategoryName = ""
                    showingNewCategoryAlert = true
                } label: {
                    Text("New Category")
                }
            }

        }
        .navigationTitle("New Ingredient")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    cancel()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .task(id: categorySuggestionKey) {
            await suggestCategoryIfNeeded()
        }
        .task(id: imageGenerationKey) {
            await generateDraftImageIfNeeded()
        }
        .alert("New Category", isPresented: $showingNewCategoryAlert) {
            TextField("Category name", text: $newCategoryName)

            Button("Add") {
                createCategoryFromAlert()
            }
            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                activeImageGenerationID = nil
                isGeneratingImage = false
                draftPhotoData = image.recipePhotoData
                draftPhotoSource = .captured
            }
            .ignoresSafeArea()
        }
        .alert("Camera Unavailable", isPresented: $showingCameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A camera is not available on this device.")
        }
        .onDisappear {
            guard !didFinish else { return }
            cleanupTemporaryItems(keepingCategoryID: nil)
        }
    }

    private func save() {
        if let existingIngredient = ingredients.first(where: {
            $0.normalizedName == trimmedName.normalizedLookupValue
        }) {
            cleanupTemporaryItems(keepingCategoryID: nil)
            didFinish = true
            onSave?(existingIngredient)
            dismiss()
            return
        }

        var category = categories.first { $0.id == selectedCategoryID }
        category = category ?? locallyCreatedCategories.first { $0.id == selectedCategoryID }

        let ingredient = Ingredient(
            name: trimmedName,
            photoData: draftPhotoData,
            category: category
        )
        modelContext.insert(ingredient)
        cleanupTemporaryItems(keepingCategoryID: category?.id)
        locallyCreatedCategories = []
        didFinish = true
        onSave?(ingredient)
        dismiss()
    }

    private func cancel() {
        cleanupTemporaryItems(keepingCategoryID: nil)
        didFinish = true
        dismiss()
    }

    private func selectCategory(_ categoryID: UUID?, manually: Bool) {
        selectedCategoryID = categoryID

        if manually {
            manuallySelectedCategoryName = trimmedName.normalizedLookupValue
            suggestedCategoryID = nil
            categorySuggestionState = .idle
        }

        cleanupTemporaryItems(keepingCategoryID: categoryID)
    }

    private func createCategoryFromAlert() {
        let normalizedName = newCategoryName.normalizedLookupValue
        guard !normalizedName.isEmpty else { return }

        let existingCategory = categories.first {
            $0.normalizedName == normalizedName
        } ?? locallyCreatedCategories.first {
            $0.normalizedName == normalizedName
        }

        let category: IngredientCategory
        if let existingCategory {
            category = existingCategory
        } else {
            category = IngredientCategory(
                name: newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            modelContext.insert(category)
            locallyCreatedCategories.append(category)
        }

        selectCategory(category.id, manually: true)
        try? modelContext.save()
    }

    private func cleanupTemporaryItems(keepingCategoryID: UUID?) {
        locallyCreatedCategories.removeAll { category in
            guard category.id != keepingCategoryID else { return false }

            if category.ingredients?.isEmpty ?? true {
                modelContext.delete(category)
            }

            if selectedCategoryID == category.id {
                selectedCategoryID = nil
            }

            return true
        }

        try? modelContext.save()
    }

    private func suggestCategoryIfNeeded() async {
        guard canSuggestCategory else {
            categorySuggestionState = .idle
            return
        }

        let ingredientName = trimmedName
        let normalizedIngredientName = ingredientName.normalizedLookupValue
        guard !ingredientName.isEmpty, manuallySelectedCategoryName != normalizedIngredientName else {
            categorySuggestionState = .idle
            return
        }

        if selectedCategoryID == suggestedCategoryID {
            selectedCategoryID = nil
        }
        suggestedCategoryID = nil
        categorySuggestionState = .generating

        do {
            try await Task.sleep(nanoseconds: 700_000_000)
            try Task.checkCancellation()

            applyCategorySuggestion(
                await IngredientCategorySuggestionService.suggestedCategory(
                    for: ingredientName,
                    from: categories
                ),
                for: ingredientName
            )
        } catch is CancellationError {
        } catch {
            categorySuggestionState = .idle
        }
    }

    private func applyCategorySuggestion(
        _ category: IngredientCategory?,
        for ingredientName: String
    ) {
        guard
            trimmedName == ingredientName,
            manuallySelectedCategoryName != ingredientName.normalizedLookupValue
        else {
            return
        }

        guard let category else {
            categorySuggestionState = .idle
            return
        }

        selectedCategoryID = category.id
        suggestedCategoryID = category.id
        categorySuggestionState = .suggested(category.name)
    }

    private func generateDraftImageIfNeeded() async {
        guard supportsImagePlayground else {
            isGeneratingImage = false
            return
        }

        guard !trimmedName.isEmpty else {
            guard draftPhotoSource != .captured else { return }
            activeImageGenerationID = nil
            isGeneratingImage = false
            draftPhotoData = nil
            draftPhotoSource = .none
            return
        }

        guard draftPhotoSource != .captured else { return }
        await generateDraftImage(replacingCapturedPhoto: false)
    }

    private func regenerateDraftImage() {
        Task {
            await generateDraftImage(replacingCapturedPhoto: true)
        }
    }

    private func generateDraftImage(replacingCapturedPhoto: Bool) async {
        let ingredientName = trimmedName
        guard supportsImagePlayground, !ingredientName.isEmpty else { return }
        guard replacingCapturedPhoto || draftPhotoSource != .captured else { return }

        let generationID = UUID()
        activeImageGenerationID = generationID
        isGeneratingImage = true
        draftPhotoData = nil
        draftPhotoSource = .none

        do {
            try Task.checkCancellation()
            let photoData = await IngredientImageGenerator.generateImageData(for: ingredientName)
            try Task.checkCancellation()

            guard activeImageGenerationID == generationID else { return }
            activeImageGenerationID = nil
            isGeneratingImage = false

            guard trimmedName == ingredientName else { return }
            guard replacingCapturedPhoto || draftPhotoSource != .captured else { return }

            draftPhotoData = photoData
            draftPhotoSource = photoData == nil ? .none : .generated
        } catch is CancellationError {
            guard activeImageGenerationID == generationID else { return }
            activeImageGenerationID = nil
            isGeneratingImage = false
        } catch {
            guard activeImageGenerationID == generationID else { return }
            activeImageGenerationID = nil
            isGeneratingImage = false
            draftPhotoSource = .none
        }
    }

    private func takePhoto() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showingCameraUnavailable = true
            return
        }

        showingCamera = true
    }
}

private enum IngredientDraftPhotoSource {
    case none
    case generated
    case captured
}

private struct IngredientDraftPhotoThumbnail: View {
    let photoData: Data?
    let isGenerating: Bool

    var body: some View {
        Group {
            if let image = photoData.flatMap(UIImage.init(data:)), !isGenerating {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(uiColor: .tertiarySystemFill)

                    if isGenerating {
                        ProgressView()
                            .controlSize(.large)
                    } else {
                        Image(systemName: "carrot")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(width: 132, height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct IngredientPhotoActionButton: View {
    let title: String
    let systemImage: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                Text(title)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .fontWeight(.medium)
            .foregroundColor(Color(uiColor: .label))
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
        .disabled(isDisabled)
    }
}

private enum CategorySuggestionState: Equatable {
    case idle
    case generating
    case suggested(String)
}

#Preview("New Ingredient") {
    let previewData = PreviewData()

    NavigationStack {
        IngredientFormView()
    }
    .modelContainer(previewData.container)
}
