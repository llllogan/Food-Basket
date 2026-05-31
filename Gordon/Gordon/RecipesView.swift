//
//  RecipesView.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import SwiftUI
import SwiftData

struct RecipesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @State private var showingAddRecipe = false
    @State private var searchText = ""

    private var filteredRecipes: [Recipe] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else { return recipes }

        return recipes.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if recipes.isEmpty {
                    Text("Add a recipe to get started.")
                        .foregroundStyle(.secondary)
                } else if filteredRecipes.isEmpty {
                    Text("No recipes found.")
                        .foregroundStyle(.secondary)
                }

                ForEach(filteredRecipes) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipe: recipe)
                    } label: {
                        HStack(spacing: 12) {
                            RecipeThumbnailView(photoData: recipe.photoData)

                            VStack(alignment: .leading) {
                                Text(recipe.name)
                                Text("\(recipe.ingredientLines.count) ingredients")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteRecipes)
            }
            .listStyle(.plain)
            .navigationTitle("Recipes")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search recipes"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddRecipe = true
                    } label: {
                        Label("Add Recipe", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRecipe) {
                NavigationStack {
                    RecipeFormView()
                }
            }
        }
    }

    private func deleteRecipes(at offsets: IndexSet) {
        let deletedRecipes = offsets.map { filteredRecipes[$0] }

        for recipe in deletedRecipes {
            for plannedMeal in recipe.plannedMeals {
                modelContext.delete(plannedMeal)
            }

            modelContext.delete(recipe)
        }
    }
}

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let recipe: Recipe
    @State private var showingAddIngredient = false
    @State private var showingEditRecipe = false
    @State private var showingCamera = false
    @State private var showingCameraUnavailable = false
    @State private var showingCountEditor = false
    @State private var editedIngredientLine: RecipeIngredient?
    @State private var editedQuantity = ""

    private var ingredientLines: [RecipeIngredient] {
        recipe.ingredientLines.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        List {
            RecipeHeroImageView(photoData: recipe.photoData, takePhoto: takePhoto)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            Section {
                Text(recipe.name)
                    .font(.largeTitle.bold())
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            Section("Ingredients") {
                if ingredientLines.isEmpty {
                    Text("No ingredients yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ingredientLines) { line in
                        HStack(spacing: 12) {
                            IngredientThumbnailView(photoData: line.ingredient?.photoData)

                            Text(line.ingredient?.name ?? "Deleted ingredient")

                            Spacer()

                            Text(line.formattedQuantity)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                modelContext.delete(line)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                editCount(for: line)
                            } label: {
                                Label("Count", systemImage: "number")
                            }
                            .tint(.blue)
                        }
                    }
                }

            }
            .listRowBackground(Color.clear)

            Section("Method") {
                Text(recipe.method.isEmpty ? "No method added." : recipe.method)
                    .foregroundStyle(recipe.method.isEmpty ? .secondary : .primary)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {

                Button {
                    takePhoto()
                } label: {
                    Label("Take Meal Photo", systemImage: "camera")
                }

                Button {
                    showingEditRecipe = true
                } label: {
                    Label("Edit Recipe", systemImage: "pencil")
                }
                
                Button {
                    showingAddIngredient = true
                } label: {
                    Label("Add Ingredient", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEditRecipe) {
            NavigationStack {
                RecipeFormView(recipe: recipe)
            }
        }
        .sheet(isPresented: $showingAddIngredient) {
            NavigationStack {
                AddIngredientToRecipeView(recipe: recipe)
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                recipe.photoData = image.recipePhotoData
                try? modelContext.save()
            }
            .ignoresSafeArea()
        }
        .alert("Camera Unavailable", isPresented: $showingCameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A camera is not available on this device.")
        }
        .alert("Change Count", isPresented: $showingCountEditor) {
            TextField("Count", text: $editedQuantity)
                .keyboardType(.decimalPad)

            Button("Cancel", role: .cancel) {}

            Button("Save") {
                saveEditedCount()
            }
            .disabled(editedQuantityValue == nil)
        } message: {
            Text("Enter the amount needed for this recipe.")
        }
    }

    private var editedQuantityValue: Double? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        let value = formatter.number(from: editedQuantity)?.doubleValue ?? Double(editedQuantity)
        guard let value, value > 0 else { return nil }
        return value
    }

    private func editCount(for line: RecipeIngredient) {
        editedIngredientLine = line
        editedQuantity = line.quantity.formatted(.number.precision(.fractionLength(0...2)))
        showingCountEditor = true
    }

    private func saveEditedCount() {
        guard let editedIngredientLine, let editedQuantityValue else { return }
        editedIngredientLine.quantity = editedQuantityValue
    }

    private func takePhoto() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showingCameraUnavailable = true
            return
        }

        showingCamera = true
    }
}

struct RecipeFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let recipe: Recipe?
    @State private var name: String
    @State private var method: String

    init(recipe: Recipe? = nil) {
        self.recipe = recipe
        _name = State(initialValue: recipe?.name ?? "")
        _method = State(initialValue: recipe?.method ?? "")
    }

    var body: some View {
        Form {
            Section("Recipe") {
                TextField("Name", text: $name)
            }

            Section("Method") {
                TextEditor(text: $method)
                    .frame(minHeight: 180)
            }
        }
        .navigationTitle(recipe == nil ? "New Recipe" : "Edit Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let recipe {
            recipe.name = trimmedName
            recipe.method = method.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            modelContext.insert(
                Recipe(
                    name: trimmedName,
                    method: method.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }

        dismiss()
    }
}

struct AddIngredientToRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]

    let recipe: Recipe
    @State private var createdIngredientForAmount: Ingredient?
    @State private var showingCreatedIngredientAmount = false
    @State private var showingNewIngredient = false
    @State private var searchText = ""

    private var filteredIngredients: [Ingredient] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else { return ingredients }

        return ingredients.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    var body: some View {
        List {
            Section("Ingredients") {
                if ingredients.isEmpty {
                    Text("Create your first ingredient.")
                        .foregroundStyle(.secondary)
                } else if filteredIngredients.isEmpty {
                    Text("No ingredients found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredIngredients) { ingredient in
                        NavigationLink {
                            AddIngredientAmountView(recipe: recipe, ingredient: ingredient) {
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                IngredientThumbnailView(photoData: ingredient.photoData)

                                Text(ingredient.name)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Ingredient")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search ingredients"
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .bottomBar) {
                Button("Create New Ingredient") {
                    createdIngredientForAmount = nil
                    showingNewIngredient = true
                }
            }
        }
        .navigationDestination(isPresented: $showingCreatedIngredientAmount) {
            if let createdIngredientForAmount {
                AddIngredientAmountView(recipe: recipe, ingredient: createdIngredientForAmount) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingNewIngredient, onDismiss: {
            guard createdIngredientForAmount != nil else { return }
            showingCreatedIngredientAmount = true
        }) {
            NavigationStack {
                IngredientFormView { ingredient in
                    searchText = ""
                    createdIngredientForAmount = ingredient
                    showingNewIngredient = false
                }
            }
        }
    }
}

struct AddIngredientAmountView: View {
    @Environment(\.modelContext) private var modelContext

    let recipe: Recipe
    let ingredient: Ingredient
    let onAdd: () -> Void
    @State private var quantity: Double

    init(recipe: Recipe, ingredient: Ingredient, onAdd: @escaping () -> Void) {
        self.recipe = recipe
        self.ingredient = ingredient
        self.onAdd = onAdd
        _quantity = State(initialValue: ingredient.defaultQuantity)
    }

    var body: some View {
        Form {
            Section("Ingredient") {
                LabeledContent("Name", value: ingredient.name)
                LabeledContent("Unit", value: ingredient.unit?.symbol ?? "No unit")
            }

            Section("Amount") {
                TextField("Quantity", value: $quantity, format: .number)
                    .keyboardType(.decimalPad)
            }
        }
        .navigationTitle("Select Amount")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addIngredient()
                }
                .disabled(quantity <= 0)
            }
        }
    }

    private func addIngredient() {
        let line = RecipeIngredient(
            quantity: quantity,
            sortOrder: recipe.ingredientLines.count,
            ingredient: ingredient
        )
        recipe.ingredientLines.append(line)
        modelContext.insert(line)
        onAdd()
    }
}

private extension RecipeIngredient {
    var formattedQuantity: String {
        let amount = quantity.formatted(.number.precision(.fractionLength(0...2)))
        guard let symbol = ingredient?.unit?.symbol, !symbol.isEmpty else {
            return amount
        }
        return "\(amount) \(symbol)"
    }
}

#Preview("Recipes") {
    let previewData = PreviewData()

    RecipesView()
        .modelContainer(previewData.container)
}

#Preview("Recipe Detail") {
    let previewData = PreviewData()

    NavigationStack {
        RecipeDetailView(recipe: previewData.recipe)
    }
    .modelContainer(previewData.container)
}

#Preview("New Recipe") {
    let previewData = PreviewData()

    NavigationStack {
        RecipeFormView()
    }
    .modelContainer(previewData.container)
}

#Preview("Edit Recipe") {
    let previewData = PreviewData()

    NavigationStack {
        RecipeFormView(recipe: previewData.recipe)
    }
    .modelContainer(previewData.container)
}

#Preview("Add Ingredient to Recipe") {
    let previewData = PreviewData()

    NavigationStack {
        AddIngredientToRecipeView(recipe: previewData.recipe)
    }
    .modelContainer(previewData.container)
}
