import Foundation

extension MediaItem {
  var traktReference: TraktMediaReference {
    let ids = TraktIDs(
      trakt: traktID,
      slug: nil,
      imdb: imdbID,
      tmdb: tmdbID
    )
    if kind == .movie {
      return TraktMediaReference(
        movie: TraktMovie(title: title, year: releaseYear, ids: ids)
      )
    }
    return TraktMediaReference(
      show: TraktShow(title: title, year: releaseYear, ids: ids)
    )
  }
}
