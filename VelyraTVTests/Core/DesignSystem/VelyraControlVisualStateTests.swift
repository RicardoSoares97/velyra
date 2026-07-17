import XCTest

@testable import VelyraTV

final class VelyraControlVisualStateTests: XCTestCase {
  func testDisabledWinsOverFocusAndPress() {
    XCTAssertEqual(
      VelyraControlVisualState.resolve(
        isEnabled: false,
        isFocused: true,
        isPressed: true
      ),
      .disabled
    )
  }

  func testPressedWinsOverFocus() {
    XCTAssertEqual(
      VelyraControlVisualState.resolve(
        isEnabled: true,
        isFocused: true,
        isPressed: true
      ),
      .pressed
    )
  }

  func testFocusAndNormalAreDistinct() {
    XCTAssertEqual(
      VelyraControlVisualState.resolve(
        isEnabled: true,
        isFocused: true,
        isPressed: false
      ),
      .focused
    )
    XCTAssertEqual(
      VelyraControlVisualState.resolve(
        isEnabled: true,
        isFocused: false,
        isPressed: false
      ),
      .normal
    )
  }

  func testReduceMotionRemovesFocusScaleButKeepsHighlight() {
    XCTAssertEqual(VelyraControlVisualState.focused.scale(reduceMotion: true), 1)
    XCTAssertEqual(VelyraControlVisualState.focused.scale(reduceMotion: false), 1.055)
    XCTAssertTrue(VelyraControlVisualState.focused.showsHighlight)
  }
}
