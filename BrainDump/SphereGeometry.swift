import SwiftUI
import Combine
import UIKit
import Foundation
import UniformTypeIdentifiers
import QuartzCore
import UserNotifications
import CryptoKit
import Darwin

// MARK: - Math Helper

struct SphereMath {
    /// Gradual density-based growth. This is a layout factor, never a saved zoom value.
    static func populationScale(tileCount: Int) -> Double {
        let count = Double(max(0, tileCount))
        if count <= 12 { return 0.65 + 0.35 * sqrt(count / 12) }
        return 1 + 0.55 * (1 - exp(-(count - 12) / 40))
    }

    // Generate evenly distributed points on a sphere using golden angle spiral
    static func generatePoint(index: Int, total: Int) -> Point3D {
        // Handle edge case: when there's only one tile, place it at the center
        guard total > 1 else {
            return Point3D(x: 0.0, y: 0.0, z: 0.0)
        }

        // Golden angle in radians
        let goldenAngle = Double.pi * (3.0 - sqrt(5.0))

        // Normalized index (0 to 1)
        // SwiftUI may render a departing tile with its old slot and the new count
        // before layout membership updates. Keep that intermediate geometry finite.
        let slot = min(max(index, 0), total - 1)
        let y = 1.0 - (Double(slot) / Double(total - 1)) * 2.0

        // Radius at this y level
        let radius = sqrt(max(0, 1.0 - y * y))

        // Angle around the sphere
        let theta = goldenAngle * Double(slot)

        // Convert to 3D coordinates
        let x = cos(theta) * radius
        let z = sin(theta) * radius

        return Point3D(x: x, y: y, z: z)
    }

    // Rotate a 3D point using a quaternion orientation
    static func rotatePoint(point: Point3D, orientation: Quaternion) -> Point3D {
        orientation.rotate(point)
    }

    // Project 3D point to 2D screen coordinates
    static func projectTo2D(point: Point3D, containerSize: CGSize, sphereScale: Double) -> ProjectedPoint {
        // Perspective projection with field of view
        let fov: Double = 2.0
        let distance: Double = 3.0

        // Project to 2D
        let scale = fov / (distance - point.z)
        let screenX = point.x * scale
        let screenY = point.y * scale

        // Convert to screen coordinates (center of container)
        let centerX = containerSize.width / 2
        let centerY = containerSize.height / 2
        let screenSize = min(containerSize.width, containerSize.height)

        // Calculate position based on current sphere scale
        let positionX = centerX + CGFloat(screenX * Double(screenSize) * sphereScale)
        let positionY = centerY + CGFloat(screenY * Double(screenSize) * sphereScale)

        return ProjectedPoint(
            position: CGPoint(x: positionX, y: positionY),
            depth: point.z
        )
    }

    // Compute scale based on depth (front = 1.0, back = slightly smaller)
    static func computeScale(depth: Double) -> CGFloat {
        // Depth ranges from -1 to 1, map to scale 0.85 to 1.0
        let normalizedDepth = (depth + 1.0) / 2.0 // 0 to 1
        let scale = 0.85 + (normalizedDepth * 0.15) // 0.85 to 1.0
        return CGFloat(scale)
    }

    // Compute opacity based on depth (front = 1.0, back = more transparent)
    static func computeOpacity(depth: Double) -> Double {
        // Depth ranges from -1 to 1, map to opacity 0.2 to 1.0
        let normalizedDepth = (depth + 1.0) / 2.0 // 0 to 1
        let opacity = 0.2 + (normalizedDepth * 0.8) // 0.2 to 1.0
        return opacity
    }

    // Map 2D screen point to unit sphere (arcball)
    static func mapToSphere(point: CGPoint, in size: CGSize) -> Point3D {
        let radius = min(size.width, size.height) / 2.0
        guard radius > 0 else { return .zero }
        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        let x = (point.x - center.x) / radius
        let y = (point.y - center.y) / radius
        let lengthSquared = x * x + y * y
        if lengthSquared <= 1.0 {
            let z = sqrt(1.0 - lengthSquared)
            return Point3D(x: Double(x), y: Double(y), z: Double(z))
        } else {
            let length = sqrt(lengthSquared)
            let nx = x / length
            let ny = y / length
            return Point3D(x: Double(nx), y: Double(ny), z: 0.0)
        }
    }
}
