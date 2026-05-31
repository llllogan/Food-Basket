//
//  KeyboardDismissModifier.swift
//  Gordon
//
//  Created by Codex on 31/5/2026.
//

import SwiftUI
import UIKit

extension View {
    func dismissKeyboardOnTapOutsideTextInputs() -> some View {
        modifier(KeyboardDismissModifier())
    }
}

private struct KeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            KeyboardDismissRecognizerView()
        }
    }
}

private struct KeyboardDismissRecognizerView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WindowObservingView {
        let view = WindowObservingView()
        view.backgroundColor = .clear
        view.onWindowChange = { window in
            context.coordinator.install(on: window)
        }
        return view
    }

    func updateUIView(_ uiView: WindowObservingView, context: Context) {
        context.coordinator.install(on: uiView.window)
    }

    static func dismantleUIView(_ uiView: WindowObservingView, coordinator: Coordinator) {
        uiView.onWindowChange = nil
        coordinator.install(on: nil)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var window: UIWindow?
        private var tapGestureRecognizer: UITapGestureRecognizer?

        func install(on window: UIWindow?) {
            guard self.window !== window else { return }

            if let tapGestureRecognizer {
                self.window?.removeGestureRecognizer(tapGestureRecognizer)
            }

            self.window = window
            guard let window else {
                tapGestureRecognizer = nil
                return
            }

            let tapGestureRecognizer = UITapGestureRecognizer(
                target: self,
                action: #selector(dismissKeyboard)
            )
            tapGestureRecognizer.cancelsTouchesInView = false
            tapGestureRecognizer.delegate = self
            window.addGestureRecognizer(tapGestureRecognizer)
            self.tapGestureRecognizer = tapGestureRecognizer
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            touch.view?.isInsideTextInput != true
        }

        @objc private func dismissKeyboard() {
            window?.endEditing(true)
        }
    }
}

private final class WindowObservingView: UIView {
    var onWindowChange: ((UIWindow?) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onWindowChange?(window)
    }
}

private extension UIView {
    var isInsideTextInput: Bool {
        var view: UIView? = self

        while let currentView = view {
            if currentView is UITextField || currentView is UITextView {
                return true
            }
            view = currentView.superview
        }

        return false
    }
}
