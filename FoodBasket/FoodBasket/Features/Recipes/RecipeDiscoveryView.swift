//
//  RecipeDiscoveryView.swift
//  Food Basket
//
//  Created by Codex on 21/6/2026.
//

import SwiftData
import SwiftUI
import UIKit

private enum RecipeDiscoveryTransitionSource: Hashable {
    case addRecipeToolbar
}

private struct RecipeMealTypeRoute: Hashable {
    let mealTypeID: UUID
}

struct RecipeDiscoveryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Query(sort: \MealType.name) private var mealTypes: [MealType]
    @Binding private var selectedRecipeID: UUID?
    private let onOpenThisWeekCalendar: (Set<UUID>) -> Void
    @Namespace private var recipeDiscoveryTransitionNamespace
    @State private var navigationPath = NavigationPath()
    @State private var featuredRecipeID: UUID?
    @State private var showingAddRecipe = false
    @State private var pendingCreatedRecipeID: UUID?
    @State private var showingImportRecipeAlert = false
    @State private var importURLText = ""
    @State private var isImportingRecipe = false
    @State private var importErrorMessage: String?
    @State private var showingImportError = false
    @State private var runningImportTask: Task<Void, Never>?

    init(
        selectedRecipeID: Binding<UUID?> = .constant(nil),
        onOpenThisWeekCalendar: @escaping (Set<UUID>) -> Void = { _ in }
    ) {
        _selectedRecipeID = selectedRecipeID
        self.onOpenThisWeekCalendar = onOpenThisWeekCalendar
    }

    private var importURL: URL? {
        recipeURL(from: importURLText)
    }

    private var featuredRecipe: Recipe? {
        guard let featuredRecipeID,
              let recipe = recipes.first(where: { $0.id == featuredRecipeID }) else {
            return recipes.first
        }

        return recipe
    }

    private func recipeURL(from text: String) -> URL? {
        let trimmedURL = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return nil }

        if trimmedURL.contains("://") {
            return URL(string: trimmedURL)
        }

        return URL(string: "https://\(trimmedURL)")
    }

    @ViewBuilder
    private func zoomTransitionSource<Content: View>(
        id: RecipeDiscoveryTransitionSource,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(iOS 18.0, *) {
            content()
                .matchedTransitionSource(id: id, in: recipeDiscoveryTransitionNamespace)
        } else {
            content()
        }
    }

    @ViewBuilder
    private func zoomTransitionDestination<Content: View>(
        id: RecipeDiscoveryTransitionSource,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(iOS 18.0, *) {
            content()
                .navigationTransition(.zoom(sourceID: id, in: recipeDiscoveryTransitionNamespace))
        } else {
            content()
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    recipeGroupsSection
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .ignoresSafeArea(edges: .top)
            .navigationTitle("Recipes")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    addRecipeMenu
                }
            }
            .navigationDestination(for: UUID.self) { recipeID in
                recipeDestination(for: recipeID)
            }
            .navigationDestination(for: RecipeMealTypeRoute.self) { route in
                RecipesView(
                    initialMealTypeFilterID: route.mealTypeID,
                    onOpenThisWeekCalendar: onOpenThisWeekCalendar
                )
            }
            .sheet(isPresented: $showingAddRecipe, onDismiss: openPendingCreatedRecipeIfNeeded) {
                zoomTransitionDestination(id: .addRecipeToolbar) {
                    NavigationStack {
                        RecipeFormView { recipeID in
                            pendingCreatedRecipeID = recipeID
                        }
                    }
                }
            }
            .alert("Import Recipe", isPresented: $showingImportRecipeAlert) {
                TextField("https://example.com/recipe", text: $importURLText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Cancel", role: .cancel) {}

                Button("Paste from Clipboard") {
                    pasteRecipeURLFromClipboard()
                }
                .disabled(isImportingRecipe)

                Button("Import") {
                    importRecipeFromURL()
                }
                .disabled(importURL == nil || isImportingRecipe)
            } message: {
                Text("Paste a recipe URL.")
            }
            .alert("Import Failed", isPresented: $showingImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage ?? "The recipe could not be imported.")
            }
            .onDisappear {
                runningImportTask?.cancel()
            }
            .onAppear {
                chooseFeaturedRecipeIfNeeded()
                openSelectedRecipeIfNeeded()
            }
            .onChange(of: recipes.map(\.id)) { _, _ in
                chooseFeaturedRecipeIfNeeded()
            }
            .onChange(of: selectedRecipeID) { _, _ in
                openSelectedRecipeIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        if let featuredRecipe {
            Button {
                navigationPath.append(featuredRecipe.id)
            } label: {
                RecipeDiscoveryHeroView(recipe: featuredRecipe)
            }
            .buttonStyle(.plain)
        } else {
            RecipeDiscoveryEmptyHeroView()
        }
    }

    private var recipeGroupsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recipe Groups")
                .font(.title3.weight(.bold))
                .padding(.horizontal, 20)
                .padding(.top, 22)

            if mealTypes.isEmpty {
                ContentUnavailableView {
                    Label("No Recipe Groups", systemImage: "tray")
                } description: {
                    Text("Add a recipe group from a recipe to organize your collection.")
                }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 36)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(mealTypes.enumerated()), id: \.element.id) { index, mealType in
                        Button {
                            navigationPath.append(RecipeMealTypeRoute(mealTypeID: mealType.id))
                        } label: {
                            RecipeDiscoveryGroupRow(
                                mealTypeName: mealType.name,
                                subtitle: mealTypeSubtitle(for: mealType),
                                photoData: mealTypePhotoData(for: mealType)
                            )
                        }
                        .buttonStyle(.plain)

                        if index < mealTypes.count - 1 {
                            Divider()
                                .padding(.leading, 88)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var addRecipeMenu: some View {
        zoomTransitionSource(id: .addRecipeToolbar) {
            Menu {
                Button {
                    showingAddRecipe = true
                } label: {
                    Label("Add Manually", systemImage: "square.and.pencil")
                }

                Button {
                    showingImportRecipeAlert = true
                } label: {
                    Label("Add from URL", systemImage: "link.badge.plus")
                }
                .disabled(isImportingRecipe)
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add Recipe")
        }
    }

    @ViewBuilder
    private func recipeDestination(for recipeID: UUID) -> some View {
        if let recipe = recipes.first(where: { $0.id == recipeID }) {
            RecipeDetailView(
                recipe: recipe,
                onOpenThisWeekCalendar: onOpenThisWeekCalendar
            )
        } else {
            Text("Recipe not found.")
                .foregroundStyle(.secondary)
                .navigationTitle("Recipe")
        }
    }

    private func mealTypeSubtitle(for mealType: MealType) -> String {
        let mealTypeRecipes = recipes(for: mealType)
        guard !mealTypeRecipes.isEmpty else { return "No recipes yet" }

        let recipeNames = mealTypeRecipes.prefix(3).map(\.name).joined(separator: ", ")
        if mealTypeRecipes.count <= 3 {
            return recipeNames
        }

        return "\(recipeNames), and \(mealTypeRecipes.count - 3) more"
    }

    private func mealTypePhotoData(for mealType: MealType) -> Data? {
        recipes(for: mealType).first { $0.photoData != nil }?.photoData
    }

    private func recipes(for mealType: MealType) -> [Recipe] {
        recipes.filter { $0.mealType?.id == mealType.id }
    }

    private func chooseFeaturedRecipeIfNeeded() {
        guard !recipes.isEmpty else {
            featuredRecipeID = nil
            return
        }

        if let featuredRecipeID,
           recipes.contains(where: { $0.id == featuredRecipeID }) {
            return
        }

        featuredRecipeID = recipes.randomElement()?.id
    }

    private func openSelectedRecipeIfNeeded() {
        guard let selectedRecipeID else { return }

        navigationPath = NavigationPath()
        navigationPath.append(selectedRecipeID)
        self.selectedRecipeID = nil
    }

    private func openPendingCreatedRecipeIfNeeded() {
        guard let pendingCreatedRecipeID else { return }

        navigationPath = NavigationPath()
        navigationPath.append(pendingCreatedRecipeID)
        self.pendingCreatedRecipeID = nil
    }

    private func importRecipeFromURL() {
        importRecipe(from: importURL)
    }

    private func pasteRecipeURLFromClipboard() {
        guard let clipboardText = UIPasteboard.general.string,
              let clipboardURL = recipeURL(from: clipboardText) else {
            importErrorMessage = "The clipboard does not contain a recipe URL."
            showingImportError = true
            return
        }

        importURLText = clipboardText
        importRecipe(from: clipboardURL)
    }

    private func importRecipe(from importURL: URL?) {
        guard let importURL else { return }

        runningImportTask?.cancel()
        isImportingRecipe = true
        importErrorMessage = nil

        runningImportTask = Task { @MainActor in
            defer {
                isImportingRecipe = false
            }

            do {
                _ = try await RecipeURLRecipeImporter.importRecipe(
                    from: importURL,
                    in: modelContext
                )
                importURLText = ""
                IngredientEnrichmentScheduler.schedulePendingIngredientEnrichment(
                    in: modelContext
                )
            } catch {
                guard !Task.isCancelled else { return }
                importErrorMessage = localizedMessage(for: error)
                showingImportError = true
            }
        }
    }

    private func localizedMessage(for error: Error) -> String {
        if let error = error as? LocalizedError, let message = error.errorDescription {
            return message
        }

        return error.localizedDescription
    }
}

private enum RecipeDiscoveryLayout {
    static let heroHeight: CGFloat = 460
}

private struct RecipeDiscoveryHeroView: View {
    let recipe: Recipe

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RecipeDiscoveryHeroImage(photoData: recipe.photoData)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.44), location: 0),
                    .init(color: .clear, location: 0.36),
                    .init(color: .black.opacity(0.62), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY'S PICK")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.76))

                Text(recipe.name)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text(recipe.discoveryHeroSubtitle)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
            }
            .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
            .padding(.horizontal, 20)
            .padding(.bottom, 26)
        }
        .frame(height: RecipeDiscoveryLayout.heroHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's pick, \(recipe.name), \(recipe.discoveryHeroSubtitle)")
        .accessibilityAddTraits(.isButton)
    }
}

private struct RecipeDiscoveryEmptyHeroView: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.78, green: 0.88, blue: 0.82),
                    Color(red: 0.97, green: 0.93, blue: 0.82),
                    Color(red: 0.73, green: 0.82, blue: 0.92),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "fork.knife")
                .font(.system(size: 82, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 5) {
                Text("No Recipes Yet")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("Add recipes manually or import one from a URL.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .frame(height: RecipeDiscoveryLayout.heroHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityElement(children: .combine)
    }
}

private struct RecipeDiscoveryGroupRow: View {
    let mealTypeName: String
    let subtitle: String
    let photoData: Data?

    var body: some View {
        HStack(spacing: 12) {
            RecipeDiscoveryGroupThumbnail(
                photoData: photoData,
                mealTypeName: mealTypeName
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(mealTypeName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(mealTypeName), \(subtitle)")
        .accessibilityAddTraits(.isButton)
    }
}

private struct RecipeDiscoveryGroupThumbnail: View {
    let photoData: Data?
    let mealTypeName: String

    var body: some View {
        Group {
            if let image = photoData.flatMap(UIImage.init(data:)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: fallbackColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: "fork.knife")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var fallbackColors: [Color] {
        let palettes: [[Color]] = [
            [Color(red: 0.16, green: 0.28, blue: 0.35), Color(red: 0.86, green: 0.58, blue: 0.28)],
            [Color(red: 0.31, green: 0.47, blue: 0.86), Color(red: 0.56, green: 0.78, blue: 0.65)],
            [Color(red: 0.84, green: 0.37, blue: 0.45), Color(red: 0.98, green: 0.78, blue: 0.44)],
            [Color(red: 0.39, green: 0.29, blue: 0.72), Color(red: 0.86, green: 0.55, blue: 0.79)],
            [Color(red: 0.24, green: 0.56, blue: 0.45), Color(red: 0.84, green: 0.91, blue: 0.43)],
        ]

        let paletteSeed = mealTypeName.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult + Int(scalar.value)
        }
        let index = paletteSeed % palettes.count
        return palettes[index]
    }
}

private struct RecipeDiscoveryHeroImage: View {
    let photoData: Data?

    var body: some View {
        Group {
            if let image = photoData.flatMap(UIImage.init(data:)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(uiColor: .secondarySystemGroupedBackground),
                            Color(uiColor: .tertiarySystemGroupedBackground),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: "fork.knife")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: RecipeDiscoveryLayout.heroHeight)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

private extension Recipe {
    var discoveryHeroSubtitle: String {
        let mealTypeName = mealType?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let ingredientCount = ingredientLines?.count ?? 0
        let ingredientDescription = "\(ingredientCount) \(ingredientCount == 1 ? "ingredient" : "ingredients")"

        var details: [String] = []
        if let mealTypeName, !mealTypeName.isEmpty {
            details.append(mealTypeName)
        }

        if cookingTimeMinutes > 0 {
            details.append("\(cookingTimeMinutes) min")
        }

        if details.isEmpty {
            details.append(ingredientDescription)
        }

        return details.joined(separator: " | ")
    }
}

#Preview("Recipe Discovery") {
    let previewData = PreviewData()

    RecipeDiscoveryView()
        .modelContainer(previewData.container)
}

#Preview("Recipe Discovery Empty") {
    let previewData = EmptyPreviewData()

    RecipeDiscoveryView()
        .modelContainer(previewData.container)
}
