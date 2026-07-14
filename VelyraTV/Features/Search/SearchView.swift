import SwiftUI

struct SearchView: View {
    @State private var query = ""

    var body: some View {
        VelyraPlaceholderScreen(
            titleKey: "search.title",
            bodyKey: "search.body",
            systemImage: "magnifyingglass",
            accent: .blue
        ) {
            TextField("search.placeholder", text: $query)
                .textFieldStyle(.plain)
                .font(.title2)
                .padding(22)
                .velyraGlass(cornerRadius: 24, interactive: true)
                .frame(maxWidth: 900)
                .accessibilityLabel(Text("search.accessibilityLabel"))
        }
    }
}
