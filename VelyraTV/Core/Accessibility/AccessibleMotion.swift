import SwiftUI

struct AccessibleMotion<Value: Equatable>: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let value: Value

  func body(content: Content) -> some View {
    content.animation(
      reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.84),
      value: value
    )
  }
}

extension View {
  func accessibleMotion<Value: Equatable>(value: Value) -> some View {
    modifier(AccessibleMotion(value: value))
  }
}
