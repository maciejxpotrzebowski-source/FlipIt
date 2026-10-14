import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Cross-Platform Toolbar Placement

extension ToolbarItemPlacement {
    static var platformTrailing: ToolbarItemPlacement {
        #if os(iOS)
        return .navigationBarTrailing
        #else
        return .automatic
        #endif
    }
}

// MARK: - Cross-Platform Navigation Bar Hiding

extension View {
    @ViewBuilder
    func hideNavigationBarCompat() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}

#if !os(iOS)

// MARK: - macOS Haptic Shims

struct UINotificationFeedbackGenerator {
    enum FeedbackType {
        case success, warning, error
    }
    func notificationOccurred(_ type: FeedbackType) {}
}

struct UIImpactFeedbackGenerator {
    enum FeedbackStyle {
        case light, medium, heavy, soft, rigid
    }
    init(style: FeedbackStyle) {}
    func impactOccurred() {}
}

// MARK: - macOS Pasteboard Shim

final class UIPasteboard {
    static let general = UIPasteboard()
    var string: String? {
        get {
            #if os(macOS)
            return NSPasteboard.general.string(forType: .string)
            #else
            return nil
            #endif
        }
        set {
            #if os(macOS)
            if let val = newValue {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(val, forType: .string)
            }
            #endif
        }
    }
}

// MARK: - macOS View Modifier Shims

enum NavigationBarTitleDisplayModePlaceholder {
    case inline
    case large
    case automatic
}

enum UIKeyboardTypePlaceholder {
    case `default`
    case emailAddress
    case numberPad
    case decimalPad
    case phonePad
    case asciiCapable
}

enum TextInputAutocapitalizationPlaceholder {
    case never
    case words
    case sentences
    case characters
}

extension View {
    @ViewBuilder
    func navigationBarTitleDisplayMode(_ mode: NavigationBarTitleDisplayModePlaceholder) -> some View {
        self
    }
    
    @ViewBuilder
    func keyboardType(_ type: UIKeyboardTypePlaceholder) -> some View {
        self
    }
    
    @ViewBuilder
    func textInputAutocapitalization(_ style: TextInputAutocapitalizationPlaceholder?) -> some View {
        self
    }
}

#endif
