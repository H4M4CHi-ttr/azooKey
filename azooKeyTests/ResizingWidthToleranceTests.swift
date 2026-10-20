import AzooKeyUtils
import SwiftUI
import XCTest
@testable import KeyboardViews

@MainActor
final class ResizingWidthToleranceTests: XCTestCase {
    private func isAtDefaultWidth(_ width: CGFloat) -> Bool {
        ResizingBindingFrame<AzooKeyKeyboardViewExtension>(
            size: .constant(CGSize(width: width, height: 300)),
            position: .constant(.zero), bottomOffset: .constant(0),
            initialSize: CGSize(width: 400, height: 300)
        ).isAtDefaultWidth
    }

    func testWidthResetKeepsItsPointTolerance() {
        XCTAssertTrue(isAtDefaultWidth(400))
        XCTAssertTrue(isAtDefaultWidth(400.0625))
        XCTAssertTrue(isAtDefaultWidth(399.9375))
        XCTAssertFalse(isAtDefaultWidth(400.125))
        XCTAssertFalse(isAtDefaultWidth(399.875))
    }
}
