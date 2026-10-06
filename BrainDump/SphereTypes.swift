import SwiftUI
import Combine
import UIKit
import Foundation
import UniformTypeIdentifiers
import QuartzCore
import UserNotifications
import CryptoKit
import Darwin

// MARK: - Supporting Types

struct Point3D {
    let x: Double
    let y: Double
    let z: Double
}

struct ProjectedPoint {
    let position: CGPoint
    let depth: Double
}

// MARK: - 3D Vector Helpers

extension Point3D {
    static let zero = Point3D(x: 0, y: 0, z: 0)

    var length: Double {
        sqrt(x * x + y * y + z * z)
    }

    func normalized() -> Point3D {
        let len = length
        guard len > 0 else { return .zero }
        return self / len
    }

    func dot(_ other: Point3D) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    func cross(_ other: Point3D) -> Point3D {
        Point3D(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }

    static func +(lhs: Point3D, rhs: Point3D) -> Point3D {
        Point3D(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    static func -(lhs: Point3D, rhs: Point3D) -> Point3D {
        Point3D(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    static func *(lhs: Point3D, rhs: Double) -> Point3D {
        Point3D(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    static func /(lhs: Point3D, rhs: Double) -> Point3D {
        Point3D(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
    }
}

// MARK: - Quaternion

struct Quaternion {
    let w: Double
    let x: Double
    let y: Double
    let z: Double

    static let identity = Quaternion(w: 1, x: 0, y: 0, z: 0)

    func normalized() -> Quaternion {
        let len = sqrt(w * w + x * x + y * y + z * z)
        guard len > 0 else { return .identity }
        return Quaternion(w: w / len, x: x / len, y: y / len, z: z / len)
    }

    func inverted() -> Quaternion {
        Quaternion(w: w, x: -x, y: -y, z: -z)
    }

    static func *(lhs: Quaternion, rhs: Quaternion) -> Quaternion {
        Quaternion(
            w: lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z,
            x: lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,
            y: lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x,
            z: lhs.w * rhs.z + lhs.x * rhs.y - lhs.y * rhs.x + lhs.z * rhs.w
        )
    }

    static func fromAxisAngle(axis: Point3D, angle: Double) -> Quaternion {
        let half = angle / 2.0
        let s = sin(half)
        let n = axis.normalized()
        return Quaternion(w: cos(half), x: n.x * s, y: n.y * s, z: n.z * s).normalized()
    }

    static func fromVectors(_ v0: Point3D, _ v1: Point3D) -> Quaternion {
        let a = v0.normalized()
        let b = v1.normalized()
        let dot = max(-1.0, min(1.0, a.dot(b)))

        if dot > 0.999999 {
            return .identity
        }

        if dot < -0.999999 {
            let ortho = abs(a.x) < 0.1 ? Point3D(x: 1, y: 0, z: 0) : Point3D(x: 0, y: 1, z: 0)
            let axis = a.cross(ortho).normalized()
            return fromAxisAngle(axis: axis, angle: Double.pi)
        }

        let axis = a.cross(b)
        let angle = acos(dot)
        return fromAxisAngle(axis: axis, angle: angle)
    }

    func rotate(_ v: Point3D) -> Point3D {
        let qv = Quaternion(w: 0, x: v.x, y: v.y, z: v.z)
        let result = self * qv * inverted()
        return Point3D(x: result.x, y: result.y, z: result.z)
    }

    func toAxisAngle() -> (axis: Point3D, angle: Double) {
        let clampedW = max(-1.0, min(1.0, w))
        let angle = 2.0 * acos(clampedW)
        let s = sqrt(1.0 - clampedW * clampedW)
        if s < 0.0001 {
            return (Point3D(x: 1, y: 0, z: 0), 0)
        }
        return (Point3D(x: x / s, y: y / s, z: z / s), angle)
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}


// A focus token is unused for read-only tiles; a fixed token avoids spurious updates.
extension String {
    var stableUUID: UUID { UUID(uuidString: self) ?? UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)) }
}
