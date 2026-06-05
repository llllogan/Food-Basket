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
    @Query(sort: \MeasurementUnit.name) private var units: [MeasurementUnit]

    let onSave: ((Ingredient) -> Void)?

    @State private var name = ""
    @State private var defaultQuantity = 1.0
    @State private var selectedCategoryID: UUID?
    @State private var selectedUnitID: UUID?
    @State private var newCategoryName = ""
    @State private var newUnitName = ""
    @State private var newUnitSymbol = ""
    @State private var showingNewCategoryAlert = false
    @State private var showingNewUnitAlert = false
    @State private var locallyCreatedCategories: [IngredientCategory] = []
    @State private var locallyCreatedUnits: [MeasurementUnit] = []
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

    private var unitSelection: Binding<UUID?> {
        Binding {
            selectedUnitID
        } set: { newValue in
            selectedUnitID = newValue
            cleanupTemporaryItems(
                keepingCategoryID: selectedCategoryID,
                keepingUnitID: newValue
            )
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

                    HStack(spacing: 10) {
                        if supportsImagePlayground {
                            IngredientPhotoActionButton(
                                title: "Regenerate",
                                systemImage: "wand.and.sparkles",
                                isDisabled: !canGenerateIngredientImage,
                                isAi: true
                            ) {
                                regenerateDraftImage()
                            }
                        }

                        IngredientPhotoActionButton(
                            title: "Take Photo",
                            systemImage: "camera",
                            isDisabled: false,
                            isAi: false
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
                Picker("Unit", selection: unitSelection) {
                    Text("None").tag(nil as UUID?)

                    ForEach(units) { unit in
                        Text("\(unit.name) (\(unit.symbol))").tag(unit.id as UUID?)
                    }
                }

                Button {
                    newUnitName = ""
                    newUnitSymbol = ""
                    showingNewUnitAlert = true
                } label: {
                    Text("New Unit")
                }
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
            
            Section {
                TextField("Default quantity", value: $defaultQuantity, format: .number)
                    .keyboardType(.decimalPad)
            } header: {
                Text("Default Amount")
            } footer: {
                Text("When adding this ingredient to a recipe, this is the amount that will be used if you don't specify anything.")
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
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    defaultQuantity <= 0
                )
            }
        }
        .task {
            selectDefaultUnitIfNeeded()
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
        .alert("New Unit", isPresented: $showingNewUnitAlert) {
            TextField("Unit name", text: $newUnitName)
            TextField("Symbol (mL, tsp)", text: $newUnitSymbol)

            Button("Add") {
                createUnitFromAlert()
            }
            .disabled(newUnitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

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
            cleanupTemporaryItems(keepingCategoryID: nil, keepingUnitID: nil)
        }
    }

    private func save() {
        if let existingIngredient = ingredients.first(where: {
            $0.normalizedName == trimmedName.normalizedLookupValue
        }) {
            cleanupTemporaryItems(keepingCategoryID: nil, keepingUnitID: nil)
            didFinish = true
            onSave?(existingIngredient)
            dismiss()
            return
        }

        var category = categories.first { $0.id == selectedCategoryID }
        category = category ?? locallyCreatedCategories.first { $0.id == selectedCategoryID }

        var unit = units.first { $0.id == selectedUnitID }
        unit = unit ?? locallyCreatedUnits.first { $0.id == selectedUnitID }

        let ingredient = Ingredient(
            name: trimmedName,
            defaultQuantity: defaultQuantity,
            photoData: draftPhotoData,
            category: category,
            unit: unit
        )
        modelContext.insert(ingredient)
        cleanupTemporaryItems(keepingCategoryID: category?.id, keepingUnitID: unit?.id)
        locallyCreatedCategories = []
        locallyCreatedUnits = []
        didFinish = true
        onSave?(ingredient)
        dismiss()
    }

    private func cancel() {
        cleanupTemporaryItems(keepingCategoryID: nil, keepingUnitID: nil)
        didFinish = true
        dismiss()
    }

    private func selectDefaultUnitIfNeeded() {
        guard selectedUnitID == nil else { return }
        selectedUnitID = units.first(where: { $0.normalizedName == "each" })?.id
    }

    private func selectCategory(_ categoryID: UUID?, manually: Bool) {
        selectedCategoryID = categoryID

        if manually {
            manuallySelectedCategoryName = trimmedName.normalizedLookupValue
            suggestedCategoryID = nil
            categorySuggestionState = .idle
        }

        cleanupTemporaryItems(
            keepingCategoryID: categoryID,
            keepingUnitID: selectedUnitID
        )
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

    private func createUnitFromAlert() {
        let normalizedName = newUnitName.normalizedLookupValue
        guard !normalizedName.isEmpty else { return }

        let existingUnit = units.first {
            $0.normalizedName == normalizedName
        } ?? locallyCreatedUnits.first {
            $0.normalizedName == normalizedName
        }

        let unit: MeasurementUnit
        if let existingUnit {
            unit = existingUnit
        } else {
            let trimmedName = newUnitName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedSymbol = newUnitSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
            unit = MeasurementUnit(
                name: trimmedName,
                symbol: trimmedSymbol.isEmpty ? trimmedName : trimmedSymbol
            )
            modelContext.insert(unit)
            locallyCreatedUnits.append(unit)
        }

        selectedUnitID = unit.id
        cleanupTemporaryItems(
            keepingCategoryID: selectedCategoryID,
            keepingUnitID: unit.id
        )
        try? modelContext.save()
    }

    private func cleanupTemporaryItems(keepingCategoryID: UUID?, keepingUnitID: UUID?) {
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

        locallyCreatedUnits.removeAll { unit in
            guard unit.id != keepingUnitID else { return false }

            if unit.ingredients?.isEmpty ?? true {
                modelContext.delete(unit)
            }

            if selectedUnitID == unit.id {
                selectedUnitID = nil
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
    let isAi: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                Text(title)
            }
            .foregroundStyle(isAi ? .purple : .primary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
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
