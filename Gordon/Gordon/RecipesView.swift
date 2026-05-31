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

    var body: some View {
        NavigationStack {
            List {
                if recipes.isEmpty {
                    Text("Add a recipe to get started.")
                        .foregroundStyle(.secondary)
                }

                ForEach(recipes) { recipe in
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
        let deletedRecipes = offsets.map { recipes[$0] }

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

                Button {
                    showingAddIngredient = true
                } label: {
                    Label("Add Ingredient", systemImage: "plus")
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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]

    let recipe: Recipe
    @State private var selectedIngredientID: UUID?
    @State private var quantity = 1.0
    @State private var showingNewIngredient = false

    var body: some View {
        Form {
            Section("Ingredient") {
                if ingredients.isEmpty {
                    Text("Create your first ingredient.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Ingredient", selection: $selectedIngredientID) {
                        Text("Select an ingredient").tag(nil as UUID?)

                        ForEach(ingredients) { ingredient in
                            Text(ingredient.name).tag(ingredient.id as UUID?)
                        }
                    }
                }

                Button("Create New Ingredient") {
                    showingNewIngredient = true
                }
            }

            Section("Amount") {
                TextField("Quantity", value: $quantity, format: .number)
                    .keyboardType(.decimalPad)

                if let selectedIngredient {
                    LabeledContent("Unit", value: selectedIngredient.unit?.symbol ?? "No unit")
                }
            }
        }
        .navigationTitle("Add Ingredient")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addIngredient()
                }
                .disabled(selectedIngredient == nil || quantity <= 0)
            }
        }
        .task {
            selectFirstIngredientIfNeeded()
        }
        .onChange(of: selectedIngredientID) {
            guard let selectedIngredient else { return }
            quantity = selectedIngredient.defaultQuantity
        }
        .sheet(isPresented: $showingNewIngredient) {
            NavigationStack {
                IngredientFormView { ingredient in
                    selectedIngredientID = ingredient.id
                    quantity = ingredient.defaultQuantity
                    showingNewIngredient = false
                }
            }
        }
    }

    private var selectedIngredient: Ingredient? {
        ingredients.first { $0.id == selectedIngredientID }
    }

    private func selectFirstIngredientIfNeeded() {
        guard selectedIngredientID == nil, let ingredient = ingredients.first else { return }
        selectedIngredientID = ingredient.id
        quantity = ingredient.defaultQuantity
    }

    private func addIngredient() {
        guard let selectedIngredient else { return }

        let line = RecipeIngredient(
            quantity: quantity,
            sortOrder: recipe.ingredientLines.count,
            ingredient: selectedIngredient
        )
        recipe.ingredientLines.append(line)
        modelContext.insert(line)
        dismiss()
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
