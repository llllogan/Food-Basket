//
//  ImageGenerationSettingsGroup.swift
//  Food Basket
//
//  Created by Codex on 20/6/2026.
//

import SwiftUI

struct ImageGenerationSettingsView: View {
    @State private var ingredientImagePromptDraft = IngredientImagePromptDefaults.savedTemplate
    @State private var ingredientImagePromptBeforeEditing: String?
    @State private var recipeImagePromptDraft = RecipeImagePromptDefaults.savedTemplate
    @State private var recipeImagePromptBeforeEditing: String?
    @FocusState private var isEditingIngredientImagePrompt
    @FocusState private var isEditingRecipeImagePrompt

    @AppStorage(IngredientImagePromptDefaults.templateKey) private var ingredientImagePromptTemplate = IngredientImagePromptDefaults.defaultTemplate
    @AppStorage(RecipeImagePromptDefaults.templateKey) private var recipeImagePromptTemplate = RecipeImagePromptDefaults.defaultTemplate

    private var hasIngredientImagePromptChanges: Bool {
        ingredientImagePromptDraft != ingredientImagePromptTemplate
    }

    private var hasRecipeImagePromptChanges: Bool {
        recipeImagePromptDraft != recipeImagePromptTemplate
    }

    private var hasImagePromptChanges: Bool {
        hasIngredientImagePromptChanges || hasRecipeImagePromptChanges
    }

    private var canSaveIngredientImagePrompt: Bool {
        IngredientImagePromptDefaults.isValid(ingredientImagePromptDraft)
    }

    private var canSaveRecipeImagePrompt: Bool {
        RecipeImagePromptDefaults.isValid(recipeImagePromptDraft)
    }

    private var canSaveImagePrompts: Bool {
        (!hasIngredientImagePromptChanges || canSaveIngredientImagePrompt)
            && (!hasRecipeImagePromptChanges || canSaveRecipeImagePrompt)
    }

    var body: some View {
        ImageGenerationSettingsGroup(
            ingredientImagePromptDraft: $ingredientImagePromptDraft,
            ingredientImagePromptTemplate: $ingredientImagePromptTemplate,
            recipeImagePromptDraft: $recipeImagePromptDraft,
            recipeImagePromptTemplate: $recipeImagePromptTemplate,
            isEditingIngredientImagePrompt: $isEditingIngredientImagePrompt,
            isEditingRecipeImagePrompt: $isEditingRecipeImagePrompt,
            hasImagePromptChanges: hasImagePromptChanges,
            canSaveImagePrompts: canSaveImagePrompts,
            onSaveImagePrompts: saveImagePrompts,
            onCancelImagePromptEditing: cancelImagePromptEditing,
            onResetIngredientImagePrompt: resetIngredientImagePrompt,
            onResetRecipeImagePrompt: resetRecipeImagePrompt
        )
        .onAppear {
            ingredientImagePromptDraft = ingredientImagePromptTemplate
            recipeImagePromptDraft = recipeImagePromptTemplate
        }
        .onChange(of: isEditingIngredientImagePrompt) { _, isEditing in
            if isEditing {
                ingredientImagePromptBeforeEditing = ingredientImagePromptDraft
            } else {
                ingredientImagePromptBeforeEditing = nil
            }
        }
        .onChange(of: isEditingRecipeImagePrompt) { _, isEditing in
            if isEditing {
                recipeImagePromptBeforeEditing = recipeImagePromptDraft
            } else {
                recipeImagePromptBeforeEditing = nil
            }
        }
    }

    private func saveImagePrompts() {
        guard canSaveImagePrompts else { return }

        if hasIngredientImagePromptChanges {
            ingredientImagePromptTemplate = ingredientImagePromptDraft
            ingredientImagePromptBeforeEditing = ingredientImagePromptDraft
        }

        if hasRecipeImagePromptChanges {
            recipeImagePromptTemplate = recipeImagePromptDraft
            recipeImagePromptBeforeEditing = recipeImagePromptDraft
        }
    }

    private func cancelImagePromptEditing() {
        if isEditingIngredientImagePrompt {
            ingredientImagePromptDraft = ingredientImagePromptBeforeEditing ?? ingredientImagePromptTemplate
            isEditingIngredientImagePrompt = false
        }

        if isEditingRecipeImagePrompt {
            recipeImagePromptDraft = recipeImagePromptBeforeEditing ?? recipeImagePromptTemplate
            isEditingRecipeImagePrompt = false
        }
    }

    private func resetIngredientImagePrompt() {
        ingredientImagePromptDraft = IngredientImagePromptDefaults.defaultTemplate
        ingredientImagePromptTemplate = IngredientImagePromptDefaults.defaultTemplate
        ingredientImagePromptBeforeEditing = IngredientImagePromptDefaults.defaultTemplate
    }

    private func resetRecipeImagePrompt() {
        recipeImagePromptDraft = RecipeImagePromptDefaults.defaultTemplate
        recipeImagePromptTemplate = RecipeImagePromptDefaults.defaultTemplate
        recipeImagePromptBeforeEditing = RecipeImagePromptDefaults.defaultTemplate
    }
}

struct ImageGenerationSettingsGroup: View {
    @Binding var ingredientImagePromptDraft: String
    @Binding var ingredientImagePromptTemplate: String
    @Binding var recipeImagePromptDraft: String
    @Binding var recipeImagePromptTemplate: String
    let isEditingIngredientImagePrompt: FocusState<Bool>.Binding
    let isEditingRecipeImagePrompt: FocusState<Bool>.Binding
    let hasImagePromptChanges: Bool
    let canSaveImagePrompts: Bool
    let onSaveImagePrompts: () -> Void
    let onCancelImagePromptEditing: () -> Void
    let onResetIngredientImagePrompt: () -> Void
    let onResetRecipeImagePrompt: () -> Void

    @State private var resetPromptConfirmation: ResetPromptConfirmation?

    var body: some View {
        List {
            Section {
                promptTextEditor(
                    placeholder: "Image prompt",
                    text: $ingredientImagePromptDraft,
                    focus: isEditingIngredientImagePrompt
                )

                resetPromptButton(
                    title: "Reset Image Prompt",
                    isDisabled: ingredientImagePromptTemplate == IngredientImagePromptDefaults.defaultTemplate
                        && ingredientImagePromptDraft == IngredientImagePromptDefaults.defaultTemplate,
                    confirmation: .ingredient
                )
            } header: {
                Text("Ingredient Images")
            } footer: {
                Text("The word 'ingredient_name' will be replaced with the ingredient being created.")
            }

            Section {
                promptTextEditor(
                    placeholder: "Image prompt",
                    text: $recipeImagePromptDraft,
                    focus: isEditingRecipeImagePrompt
                )

                resetPromptButton(
                    title: "Reset Image Prompt",
                    isDisabled: recipeImagePromptTemplate == RecipeImagePromptDefaults.defaultTemplate
                        && recipeImagePromptDraft == RecipeImagePromptDefaults.defaultTemplate,
                    confirmation: .recipe
                )
            } header: {
                Text("Recipe Images")
            } footer: {
                Text("The word 'recipe_name' will be replaced with the recipe. You can also use 'ingredient_list'.")
            }
        }
        .navigationTitle("Image Generation")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if isEditingIngredientImagePrompt.wrappedValue || isEditingRecipeImagePrompt.wrappedValue {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel, action: onCancelImagePromptEditing)
                }
            }

            if hasImagePromptChanges {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm, action: onSaveImagePrompts)
                        .disabled(!canSaveImagePrompts)
                }
            }
        }
        .listStyle(.insetGrouped)
        .alert(item: $resetPromptConfirmation) { confirmation in
            Alert(
                title: Text(confirmation.title),
                message: Text(confirmation.message),
                primaryButton: .destructive(Text("Reset")) {
                    resetPrompt(confirmation)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func promptTextEditor(
        placeholder: String,
        text: Binding<String>,
        focus: FocusState<Bool>.Binding
    ) -> some View {
        TextField(
            placeholder,
            text: text,
            axis: .vertical
        )
        .lineLimit(3...6)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused(focus)
    }

    private func resetPromptButton(
        title: String,
        isDisabled: Bool,
        confirmation: ResetPromptConfirmation
    ) -> some View {
        Button(role: .destructive) {
            resetPromptConfirmation = confirmation
        } label: {
            HStack {
                Text(title)
                Spacer()
            }
        }
        .disabled(isDisabled)
    }

    private func resetPrompt(_ confirmation: ResetPromptConfirmation) {
        switch confirmation {
        case .ingredient:
            onResetIngredientImagePrompt()
        case .recipe:
            onResetRecipeImagePrompt()
        }
    }
}

private enum ResetPromptConfirmation: Identifiable {
    case ingredient
    case recipe

    var id: Self { self }

    var title: String {
        switch self {
        case .ingredient:
            "Reset Image Prompt?"
        case .recipe:
            "Reset Recipe Image Prompt?"
        }
    }

    var message: String {
        switch self {
        case .ingredient:
            "This will replace your custom ingredient image generation prompt with the default prompt."
        case .recipe:
            "This will replace your custom recipe image generation prompt with the default prompt."
        }
    }
}
