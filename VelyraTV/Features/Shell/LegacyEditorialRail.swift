import SwiftUI

struct LegacyEditorialRail<Content: View>: View {
  @Binding var selection: AppSection
  @FocusState private var focusedSection: AppSection?

  private let content: () -> Content

  init(
    selection: Binding<AppSection>,
    @ViewBuilder content: @escaping () -> Content
  ) {
    _selection = selection
    self.content = content
  }

  var body: some View {
    HStack(spacing: 0) {
      rail
        .frame(width: isExpanded ? 320 : 108)
        .animation(.easeInOut(duration: 0.18), value: isExpanded)

      content()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
    .background(Color.black)
  }

  private var isExpanded: Bool {
    focusedSection != nil
  }

  private var rail: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(isExpanded ? "VELYRA" : "V")
        .font(.system(size: isExpanded ? 24 : 32, weight: .black, design: .rounded))
        .tracking(isExpanded ? 4 : 0)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: isExpanded ? .leading : .center)
        .padding(.horizontal, isExpanded ? 24 : 0)
        .padding(.bottom, 24)
        .accessibilityLabel("Velyra")

      ForEach(AppSection.allCases) { section in
        Button {
          selection = section
        } label: {
          HStack(spacing: 18) {
            Image(systemName: section.systemImage)
              .font(.title2.weight(.semibold))
              .frame(width: 42)

            if isExpanded {
              Text(LocalizedStringKey(section.titleKey))
                .font(.headline.weight(section == selection ? .bold : .medium))
                .lineLimit(1)
            }
          }
          .foregroundStyle(section == selection ? VelyraTheme.primary : Color.white)
          .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
          .padding(.horizontal, 18)
          .background {
            if section == selection {
              RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(VelyraTheme.primary.opacity(0.14))
            }
          }
        }
        .buttonStyle(VelyraGlassButtonStyle())
        .focused($focusedSection, equals: section)
        .accessibilityAddTraits(section == selection ? .isSelected : [])
      }

      Spacer()
    }
    .padding(.top, 48)
    .padding(.horizontal, 12)
    .padding(.bottom, 36)
    .background(.ultraThinMaterial)
    .overlay(alignment: .trailing) {
      Rectangle()
        .fill(.white.opacity(0.1))
        .frame(width: 1)
    }
  }
}
