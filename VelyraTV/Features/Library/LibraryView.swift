import SwiftUI

struct LibraryView: View {
    var body: some View {
        VelyraPlaceholderScreen(
            titleKey: "library.title",
            bodyKey: "library.body",
            systemImage: "rectangle.stack.fill",
            accent: .purple
        ) {
            Label("library.traktSource", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(20)
                .velyraGlass(cornerRadius: 22)
        }
    }
}
