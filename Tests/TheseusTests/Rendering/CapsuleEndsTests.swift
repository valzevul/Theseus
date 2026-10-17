import XCTest
@testable import Theseus

final class CapsuleEndsTests: XCTestCase {

    func testEdgeRunsDeepestJustPastWhereTheCapBegins() {
        let radius: CGFloat = 105
        XCTAssertEqual(CapsuleEnds.inset(along: 0.1 * radius, radius: radius), 0.01684 * radius, accuracy: 1e-6)
        XCTAssertGreaterThan(CapsuleEnds.inset(along: 0.1 * radius, radius: radius), CapsuleEnds.inset(along: 0, radius: radius))
        XCTAssertGreaterThan(CapsuleEnds.inset(along: 0.1 * radius, radius: radius), CapsuleEnds.inset(along: 0.3 * radius, radius: radius))
    }

    func testEdgeLeavesTheStraightSideHalfARadiusBeforeTheCap() {
        let radius: CGFloat = 45
        XCTAssertEqual(CapsuleEnds.inset(along: -0.6 * radius, radius: radius), 0)
        XCTAssertGreaterThan(CapsuleEnds.inset(along: -0.4 * radius, radius: radius), 0)
        XCTAssertEqual(CapsuleEnds.inset(along: 0.7 * radius, radius: radius), 0)
    }

    func testInsetScalesWithTheRadius() {
        XCTAssertEqual(
            CapsuleEnds.inset(along: 15, radius: 150),
            2 * CapsuleEnds.inset(along: 7.5, radius: 75),
            accuracy: 1e-9
        )
    }
}
