//
//  RecipeURLImportView.swift
//  Food Basket
//
//  Created by Codex on 5/6/2026.
//

import SwiftData
import SwiftUI

struct RecipeURLImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var urlText = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var automaticImportTask: Task<Void, Never>?
    @State private var runningImportTask: Task<Void, Never>?
    @State private var activeImportURL: URL?

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
                    .submitLabel(.go)
                    .onSubmit {
                        importRecipe()
                    }
                    .onChange(of: urlText) { oldValue, newValue in
                        scheduleAutomaticImport(from: oldValue, to: newValue)
                    }

                Button {
                    importRecipe()
                } label: {
                    HStack {
                        Text("Import Recipe")

                        if isLoading {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(importURL == nil || isLoading)

                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Importing recipe...")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
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
        .onDisappear {
            automaticImportTask?.cancel()
            runningImportTask?.cancel()
        }
    }

    private func scheduleAutomaticImport(from oldText: String, to newText: String) {
        automaticImportTask?.cancel()

        guard importURL != nil else {
            errorMessage = nil
            return
        }

        let insertedCharacterCount = newText.count - oldText.count
        let oldTextWasEmpty = oldText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let newTextLooksURLSized = newText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8
        guard insertedCharacterCount >= 8 || (oldTextWasEmpty && newTextLooksURLSized) else {
            return
        }

        automaticImportTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }

            importRecipe()
        }
    }

    private func importRecipe() {
        guard let importURL else { return }
        guard activeImportURL != importURL else { return }

        automaticImportTask?.cancel()
        activeImportURL = importURL
        isLoading = true
        errorMessage = nil

        runningImportTask?.cancel()
        runningImportTask = Task { @MainActor in
            defer {
                if activeImportURL == importURL {
                    isLoading = false
                    activeImportURL = nil
                }
            }

            do {
                _ = try await RecipeURLRecipeImporter.importRecipe(from: importURL, in: modelContext)
                IngredientEnrichmentScheduler.schedulePendingIngredientEnrichment(
                    in: modelContext
                )
                dismiss()
            } catch {
                guard !Task.isCancelled, activeImportURL == importURL else { return }
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
    let previewData = PreviewData()

    NavigationStack {
        RecipeURLImportView()
    }
    .modelContainer(previewData.container)
}
