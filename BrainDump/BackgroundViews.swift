import SwiftUI
import Combine
import UIKit
import Foundation
import UniformTypeIdentifiers
import QuartzCore
import UserNotifications
import CryptoKit
import Darwin

// MARK: - Cosmic Background View

struct AppBackgroundView: View {
    let theme: BackgroundTheme

    var body: some View {
        switch theme {
        case .space:
            CosmicBackgroundView()
        case .gradientOne:
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.16),
                    Color(red: 0.15, green: 0.12, blue: 0.26)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gradientTwo:
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.12, blue: 0.16),
                    Color(red: 0.04, green: 0.06, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .clouds:
            CloudBackgroundView()
        case .offBlack:
            Color(red: 0.06, green: 0.06, blue: 0.07)
        }
    }
}

struct CloudBackgroundView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.14, blue: 0.24),
                        Color(red: 0.14, green: 0.18, blue: 0.28)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: geometry.size.width * 0.95)
                    .blur(radius: 36)
                    .offset(x: -geometry.size.width * 0.18, y: -geometry.size.height * 0.2)

                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: geometry.size.width * 0.8)
                    .blur(radius: 32)
                    .offset(x: geometry.size.width * 0.2, y: -geometry.size.height * 0.05)

                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: geometry.size.width * 1.05)
                    .blur(radius: 44)
                    .offset(x: 0, y: geometry.size.height * 0.3)
            }
        }
    }
}

struct CosmicBackgroundView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient (deep space)
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2),
                        Color(red: 0.05, green: 0.1, blue: 0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Middle layer - nebula glow
                RadialGradient(
                    colors: [
                        Color(red: 0.2, green: 0.4, blue: 0.8).opacity(0.4),
                        Color(red: 0.3, green: 0.2, blue: 0.6).opacity(0.3),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.5),
                    startRadius: 50,
                    endRadius: geometry.size.width * 0.8
                )

                // Top layer - bright center light
                RadialGradient(
                    colors: [
                        Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.5),
                        Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.3),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.5),
                    startRadius: 20,
                    endRadius: geometry.size.width * 0.5
                )

                // Stars layer (subtle shimmer)
                StarsView()
            }
        }
    }
}

// MARK: - Stars View

struct StarsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    // Generate random star positions (static so computed once)
    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let baseOpacity: Double
        let phase: Double
        let speed: Double
        let twinkles: Bool
    }

    private static let starCount = 100
    private static let stars: [Star] = {
        var stars: [Star] = []
        for _ in 0..<starCount {
            let twinkles = Double.random(in: 0...1) < 0.35
            stars.append(Star(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 1...3),
                baseOpacity: Double.random(in: 0.4...0.9),
                phase: Double.random(in: 0.0...(2.0 * Double.pi)),
                speed: Double.random(in: 0.1...0.4),
                twinkles: twinkles
            ))
        }
        return stars
    }()

    var body: some View {
        Group {
            if scenePhase == .active && !reduceMotion && !lowPower {
                TimelineView(.periodic(from: Date(), by: 1)) { context in
                    stars(time: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                stars(time: 0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    private func stars(time: TimeInterval) -> some View {
        GeometryReader { geometry in
            ForEach(0..<Self.starCount, id: \.self) { index in
                let star = Self.stars[index]
                let shimmer = star.twinkles ? (0.35 * sin(time * star.speed + star.phase)) : 0.0
                let opacity = min(1.0, max(0.05, star.baseOpacity + shimmer))
                Circle()
                    .fill(Color.white)
                    .frame(width: star.size, height: star.size)
                    .opacity(opacity)
                    .position(x: star.x * geometry.size.width, y: star.y * geometry.size.height)
            }
        }
    }
}
