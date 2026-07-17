import CoreGraphics

enum VelyraControlVisualState: Equatable {
  case normal
  case focused
  case pressed
  case disabled

  static func resolve(
    isEnabled: Bool,
    isFocused: Bool,
    isPressed: Bool
  ) -> Self {
    guard isEnabled else { return .disabled }
    if isPressed { return .pressed }
    if isFocused { return .focused }
    return .normal
  }

  var showsHighlight: Bool {
    self == .focused
  }

  var opacity: Double {
    self == .disabled ? 0.38 : 1
  }

  func scale(reduceMotion: Bool) -> CGFloat {
    guard !reduceMotion else { return 1 }
    return switch self {
    case .normal, .disabled: 1
    case .focused: 1.055
    case .pressed: 0.985
    }
  }
}
