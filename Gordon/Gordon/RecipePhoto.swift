//
//  RecipePhoto.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import SwiftUI
import UIKit

struct RecipeThumbnailView: View {
    let photoData: Data?

    var body: some View {
        Group {
            if let image = photoData.flatMap(UIImage.init(data:)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(uiColor: .secondarySystemBackground)

                    Image(systemName: "fork.knife")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

struct RecipeHeroImageView: View {
    let photoData: Data?
    let takePhoto: () -> Void

    var body: some View {
        Group {
            if let image = photoData.flatMap(UIImage.init(data:)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(uiColor: .secondarySystemBackground)

                    VStack(spacing: 14) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)

                        Text("No meal photo yet")
                            .font(.headline)

                        Button {
                            takePhoto()
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .clipped()
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImageCaptured: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

extension UIImage {
    var recipePhotoData: Data? {
        resizedForRecipePhoto().jpegData(compressionQuality: 0.82)
    }

    private func resizedForRecipePhoto(maxDimension: CGFloat = 1800) -> UIImage {
        let largestDimension = max(size.width, size.height)
        guard largestDimension > maxDimension else { return self }

        let scale = maxDimension / largestDimension
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
