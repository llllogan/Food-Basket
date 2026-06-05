//
//  RecipeURLImportView.swift
//  Food Basket
//
//  Created by Codex on 5/6/2026.
//

import SwiftUI

struct RecipeURLImportView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var importedRecipe: ImportedRecipeIngredients?
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var importURL: URL? {
        let trimmedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return nil }

        if trimmedURL.contains("://") {
            return URL(string: trimmedURL)
        }

        return URL(string: "https://\(trimmedURL)")
    }

    var body: some View {
        Form {
            Section("Recipe URL") {
                TextField("https://example.com/recipe", text: $urlText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(isLoading)

                Button {
                    findIngredients()
                } label: {
                    HStack {
                        Text("Find Ingredients")

                        if isLoading {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(importURL == nil || isLoading)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let importedRecipe {
                Section("Recipe") {
                    LabeledContent("Name", value: importedRecipe.title ?? "Unknown")
                    LabeledContent("Yield", value: importedRecipe.recipeYield ?? "Unknown")
                    LabeledContent(
                        "Cooking time",
                        value: importedRecipe.cookingTimeMinutes.map { "\($0) min" } ?? "Unknown"
                    )
                    LabeledContent("Ingredients", value: "\(importedRecipe.ingredients.count)")
                    LabeledContent("Instructions", value: "\(importedRecipe.instructions.count)")
                }

                Section("Parsed Ingredients") {
                    ForEach(importedRecipe.ingredients, id: \.rawLine) { ingredient in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ingredient.name)
                                .font(.headline)

                            HStack(spacing: 8) {
                                if let amountText = ingredient.amountText {
                                    Text("Amount: \(amountText)")
                                }

                                if let unitText = ingredient.unitText {
                                    Text("Unit: \(unitText)")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            if let preparationMethod = ingredient.preparationMethod {
                                Text("Preparation: \(preparationMethod)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(ingredient.rawLine)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                if !importedRecipe.instructions.isEmpty {
                    Section("Instructions") {
                        ForEach(Array(importedRecipe.instructions.enumerated()), id: \.offset) { index, instruction in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Step \(index + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(instruction)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Import Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }

    private func findIngredients() {
        guard let importURL else { return }

        isLoading = true
        errorMessage = nil
        importedRecipe = nil

        Task {
            defer {
                isLoading = false
            }

            do {
                importedRecipe = try await RecipeURLIngredientImporter.importRecipe(from: importURL)
            } catch {
                errorMessage = localizedMessage(for: error)
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

#Preview("Recipe URL Import") {
    NavigationStack {
        RecipeURLImportView()
    }
}
