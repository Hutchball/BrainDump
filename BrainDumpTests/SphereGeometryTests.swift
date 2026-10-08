import Foundation
import Testing
@testable import BrainDump

struct SphereGeometryTests {
    @Test func populationGrowthIsGradualBoundedAndFinite() {
        #expect(SphereMath.populationScale(tileCount: 12) == 1)
        #expect(SphereMath.populationScale(tileCount: -1) == SphereMath.populationScale(tileCount: 0))
        var previous = 0.0
        for count in 0...1000 {
            let scale = SphereMath.populationScale(tileCount: count)
            #expect(scale.isFinite && scale >= 0.65 && scale <= 1.55)
            #expect(scale >= previous)
            if count > 0 { #expect(scale - previous < 0.11) }
            previous = scale
        }
        #expect(SphereMath.populationScale(tileCount: 100) > SphereMath.populationScale(tileCount: 25))
    }

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
