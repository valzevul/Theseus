import XCTest
import UIKit
@testable import Theseus

final class LayerRenderTransformTests: XCTestCase {

    private func darkPixelCount(in parent: UIView) -> Int {
        let width = Int(parent.bounds.width)
        let height = Int(parent.bounds.height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return -1 }
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        parent.layer.render(in: ctx)
        var count = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            if pixels[i + 3] > 128 && pixels[i] < 64 && pixels[i + 1] < 64 && pixels[i + 2] < 64 {
                count += 1
            }
        }
        return count
    }

    func testLayerRenderAppliesSubviewScaleTransform() {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        parent.backgroundColor = .white
        let child = UIView(frame: CGRect(x: 75, y: 75, width: 50, height: 50))
        child.backgroundColor = .black
        parent.addSubview(child)
        let plain = darkPixelCount(in: parent)
        child.transform = CGAffineTransform(scaleX: 2, y: 2)
        let scaled = darkPixelCount(in: parent)
        XCTAssertEqual(plain, 2500)
        XCTAssertEqual(scaled, 10000)
    }

    func testLayerRenderAppliesTransformOnConstrainedContent() {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        parent.backgroundColor = .white
        let item = UIView(frame: CGRect(x: 70, y: 70, width: 60, height: 60))
        parent.addSubview(item)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        item.addSubview(stack)
        let box = UIView()
        box.backgroundColor = .black
        box.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(box)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: item.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: item.centerYAnchor),
            box.widthAnchor.constraint(equalToConstant: 20),
            box.heightAnchor.constraint(equalToConstant: 20)
        ])
        parent.setNeedsLayout()
        parent.layoutIfNeeded()
        let plain = darkPixelCount(in: parent)
        item.transform = CGAffineTransform(scaleX: 2, y: 2)
        parent.layoutIfNeeded()
        let scaled = darkPixelCount(in: parent)
        XCTAssertEqual(plain, 400)
        XCTAssertEqual(scaled, 1600)
    }
}
