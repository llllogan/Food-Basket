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
    @State private var importedIngredients: ImportedRecipeIngredients?
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

            if let importedIngredients {
                Section(importedIngredients.title ?? "Ingredients") {
                    ForEach(importedIngredients.ingredientLines, id: \.self) { ingredientLine in
                        Text(ingredientLine)
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
        importedIngredients = nil

        Task {
            defer {
                isLoading = false
            }

            do {
                importedIngredients = try await RecipeURLIngredientImporter.importRecipe(from: importURL)
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
