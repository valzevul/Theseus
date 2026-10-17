import XCTest
@testable import Theseus

final class CaptureEdgesTests: XCTestCase {

    func testRegionPastTheVisibleBoundsTakesTheEdgePixels() {
        let width = 6
        let height = 4
        var pixels = [UInt32](repeating: 0, count: width * height)
        for row in 1..<height {
            for column in 0..<4 {
                pixels[row * width + column] = UInt32(100 + row * 10 + column)
            }
        }
        pixels.withUnsafeMutableBytes { buffer in
            CaptureEdges.extend(
                buffer.baseAddress!,
                width: width,
                height: height,
                bytesPerRow: width * 4,
                region: CGRect(x: 0, y: 0, width: 6, height: 4),
                visible: CGRect(x: -10, y: 1, width: 14, height: 10),
                scale: 1
            )
        }
        XCTAssertEqual(pixels[1 * width + 4], 113)
        XCTAssertEqual(pixels[1 * width + 5], 113)
        XCTAssertEqual(pixels[3 * width + 5], 133)
        XCTAssertEqual(Array(pixels[0..<width]), Array(pixels[width..<2 * width]))
    }

    func testFullyVisibleRegionIsLeftAlone() {
        var pixels: [UInt32] = [1, 2, 3, 4]
        pixels.withUnsafeMutableBytes { buffer in
            CaptureEdges.extend(
                buffer.baseAddress!,
                width: 2,
                height: 2,
                bytesPerRow: 8,
                region: CGRect(x: 0, y: 0, width: 2, height: 2),
                visible: .infinite,
                scale: 1
            )
        }
        XCTAssertEqual(pixels, [1, 2, 3, 4])
    }
}
