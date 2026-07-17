import XCTest

@testable import VelyraTV

final class SearchFilteringTests: XCTestCase {
  func testYearFiltersUseCalendarDecades() {
    XCTAssertTrue(SearchViewModel.YearFilter.currentDecade.includes(2026, currentYear: 2026))
    XCTAssertFalse(SearchViewModel.YearFilter.currentDecade.includes(2019, currentYear: 2026))
    XCTAssertTrue(SearchViewModel.YearFilter.previousDecade.includes(2015, currentYear: 2026))
    XCTAssertTrue(SearchViewModel.YearFilter.older.includes(2009, currentYear: 2026))
    XCTAssertFalse(SearchViewModel.YearFilter.older.includes(nil, currentYear: 2026))
  }

  func testRatingFiltersExposeExpectedMinimums() {
    XCTAssertNil(SearchViewModel.RatingFilter.any.minimumValue)
    XCTAssertEqual(SearchViewModel.RatingFilter.sevenPlus.minimumValue, 7)
    XCTAssertEqual(SearchViewModel.RatingFilter.eightPlus.minimumValue, 8)
  }
}
