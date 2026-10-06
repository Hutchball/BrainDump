import Foundation
import Testing
@testable import BrainDump

struct SphereGeometryTests {
    @Test func departingSlotsRemainFiniteWhenMembershipShrinks() {
        for total in [0, 1, 2, 12, 100] {
            for slot in [-1, 0, total - 1, total, total + 1, 101] {
                let point = SphereMath.generatePoint(index: slot, total: total)
                #expect(point.x.isFinite && point.y.isFinite && point.z.isFinite)
                #expect(point.length <= 1.000001)
                let projected = SphereMath.projectTo2D(point: point, containerSize: CGSize(width: 390, height: 844), sphereScale: 1)
                #expect(projected.position.x.isFinite && projected.position.y.isFinite)
            }
        }
    }
}
