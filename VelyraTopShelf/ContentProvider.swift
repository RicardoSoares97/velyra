import TVServices

final class ContentProvider: TVTopShelfContentProvider {
  override func loadTopShelfContent() async throws -> TVTopShelfContent? {
    let snapshot = await TopShelfSnapshotStore.shared.load()
    let continueItems = snapshot.continueWatching.compactMap(makeItem)
    let recommendationItems = snapshot.recommendations.compactMap(makeItem)

    var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []
    if !continueItems.isEmpty {
      let collection = TVTopShelfItemCollection(items: continueItems)
      collection.title = String(localized: "home.continueWatching")
      sections.append(collection)
    }
    if !recommendationItems.isEmpty {
      let collection = TVTopShelfItemCollection(items: recommendationItems)
      collection.title = String(localized: "topshelf.recommended")
      sections.append(collection)
    }
    guard !sections.isEmpty else { return nil }
    return TVTopShelfSectionedContent(sections: sections)
  }

  private func makeItem(_ value: TopShelfSnapshot.Item) -> TVTopShelfSectionedItem? {
    guard let actionURL = value.deepLinkURL else { return nil }
    let item = TVTopShelfSectionedItem(identifier: value.id)
    item.title = value.title
    item.imageShape = .poster
    item.displayAction = TVTopShelfAction(url: actionURL)
    if let posterURL = value.posterURL {
      item.setImageURL(posterURL, for: .screenScale1x)
      item.setImageURL(posterURL, for: .screenScale2x)
    }
    return item
  }
}
