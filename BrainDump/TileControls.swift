import SwiftUI
import Combine
import UIKit
import Foundation
import UniformTypeIdentifiers
import QuartzCore
import UserNotifications
import CryptoKit
import Darwin

// MARK: - Glass Button

struct GlassButton: View {
    let icon: String
    let foregroundColor: Color
    let borderColor: Color?
    let action: () -> Void

    private let buttonSize: CGFloat = 50

    init(
        icon: String,
        foregroundColor: Color = .primary,
        borderColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.foregroundColor = foregroundColor
        self.borderColor = borderColor
        self.action = action
    }

    private var accessibilityTitle: String {
        switch icon {
        case "plus": return "Add thought"
        case "brain": return "Open Brain Dump"
        case "gearshape": return "Settings"
        case "magnifyingglass": return "Search thoughts"
        case "xmark": return "Close"
        case "trash": return "Delete thought"
        case "checkmark": return "Save thought"
        default: return icon.replacingOccurrences(of: ".", with: " ")
        }
    }

    var body: some View {
        Button(action: {
            Haptics.optionTap()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(borderColor?.opacity(0.9) ?? .clear, lineWidth: borderColor == nil ? 0 : 2)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(accessibilityTitle)
    }
}

struct BrainDumpButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(16)
            .background(
                Group {
                    if #available(iOS 26.0, *) {
                        Circle()
                            .fill(Color.white.opacity(configuration.isPressed ? 0.42 : 0.32))
                            .glassEffect(in: Circle())
                    } else {
                        Circle()
                            .fill(Color.white.opacity(configuration.isPressed ? 0.9 : 0.82))
                    }
                }
            )
            .overlay(
                Circle()
                    .stroke(
                        Color.white.opacity(configuration.isPressed ? 0.45 : 0.22),
                        lineWidth: configuration.isPressed ? 1.5 : 0.9
                    )
            )
            .overlay(
                Circle()
                    .stroke(
                        Color.white.opacity(configuration.isPressed ? 0.18 : 0.0),
                        lineWidth: configuration.isPressed ? 4 : 0
                    )
                    .blur(radius: configuration.isPressed ? 5 : 0)
            )
            .shadow(
                color: Color.white.opacity(configuration.isPressed ? 0.14 : 0.0),
                radius: configuration.isPressed ? 10 : 0,
                x: 0,
                y: 0
            )
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.18 : 0.25),
                radius: configuration.isPressed ? 16 : 10,
                x: 0,
                y: configuration.isPressed ? 10 : 6
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 1.08 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - Settings View
