import SwiftUI

struct VelyraBrandMark: View {
  var body: some View {
    VStack(spacing: 14) {
      Image("VelyraMark")
        .resizable()
        .scaledToFit()
        .frame(width: 88, height: 88)
        .accessibilityHidden(true)

      Text("VELYRA")
        .font(.system(size: 30, weight: .black, design: .rounded))
        .tracking(6)
        .foregroundStyle(.white)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Velyra")
  }
}
