//
//  ShareViewController.swift
//  FoodBasketShareExtension
//
//  Created by Codex on 5/6/2026.
//

import Combine
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UIKit

final class ShareRecipeImportViewModel: ObservableObject {
    enum State: Equatable {
        case importing
        case imported(String)
        case failed(String)
    }

    @Published var state: State = .importing
}

final class ShareViewController: UIViewController {
    private let viewModel = ShareRecipeImportViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        installRootView()

        Task { @MainActor in
            await importSharedRecipe()
        }
    }

    private func installRootView() {
        let rootView = ShareRecipeImportView(
            viewModel: viewModel,
            onDismiss: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        )
        let hostingController = UIHostingController(rootView: rootView)

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)
    }

    @MainActor
    private func importSharedRecipe() async {
        do {
            let url = try await sharedRecipeURL()
            let container = FoodBasketModelContainer.make()
            let recipe = try await RecipeURLRecipeImporter.importRecipe(
                from: url,
                in: container.mainContext
            )
            viewModel.state = .imported(recipe.name)

            try? await Task.sleep(for: .milliseconds(700))
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            viewModel.state = .failed(error.localizedDescription)
        }
    }

    private func sharedRecipeURL() async throws -> URL {
        let extensionItems = extensionContext?.inputItems.compactMap {
            $0 as? NSExtensionItem
        } ?? []

        for item in extensionItems {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = try await loadURL(from: provider) {
                    return url
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let url = try await loadTextURL(from: provider) {
                    return url
                }
            }
        }

        throw ShareRecipeImportError.noURLFound
    }

    private func loadURL(from provider: NSItemProvider) async throws -> URL? {
        let item = try await provider.loadSharedItem(
            forTypeIdentifier: UTType.url.identifier
        )

        if let url = item as? URL {
            return url
        }

        if let url = item as? NSURL {
            return url as URL
        }

        if let data = item as? Data,
           let value = String(data: data, encoding: .utf8) {
            return URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        if let value = item as? String {
            return URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return nil
    }

    private func loadTextURL(from provider: NSItemProvider) async throws -> URL? {
        guard let item = try await provider.loadSharedItem(
            forTypeIdentifier: UTType.plainText.identifier
        ) as? String else {
            return nil
        }

        return firstURL(in: item)
    }

    private func firstURL(in value: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        let match = detector?.firstMatch(in: value, range: range)
        return match?.url
    }
}

private struct ShareRecipeImportView: View {
    @ObservedObject var viewModel: ShareRecipeImportViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            switch viewModel.state {
            case .importing:
                ProgressView()
                    .controlSize(.large)
                Text("Importing Recipe")
                    .font(.headline)
                Text("Food Basket is creating the recipe.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

            case .imported(let recipeName):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text("Recipe Imported")
                    .font(.headline)
                Text(recipeName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.orange)
                Text("Recipe Import Failed")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Close") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

private enum ShareRecipeImportError: LocalizedError {
    case noURLFound

    var errorDescription: String? {
        switch self {
        case .noURLFound:
            return "Share a recipe web page URL with Food Basket."
        }
    }
}

private extension NSItemProvider {
    func loadSharedItem(forTypeIdentifier typeIdentifier: String) async throws -> NSSecureCoding {
        try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let item {
                    continuation.resume(returning: item)
                } else {
                    continuation.resume(throwing: ShareRecipeImportError.noURLFound)
                }
            }
        }
    }
}
