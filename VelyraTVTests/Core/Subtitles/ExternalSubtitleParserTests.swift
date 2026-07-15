import XCTest

@testable import VelyraTV

final class ExternalSubtitleParserTests: XCTestCase {
  func testParsesSRTAndRemovesMarkup() throws {
    let cues = ExternalSubtitleParser.parseSRT(
      """
      1
      00:00:01,250 --> 00:00:03,500
      <i>Olá</i> mundo

      2
      00:00:04,000 --> 00:00:05,000
      Segunda linha
      """
    )

    XCTAssertEqual(cues.count, 2)
    XCTAssertEqual(cues[0].start, 1.25, accuracy: 0.001)
    XCTAssertEqual(cues[0].end, 3.5, accuracy: 0.001)
    XCTAssertEqual(cues[0].text, "Olá mundo")
    XCTAssertTrue(cues[1].contains(4.5))
  }

  func testParsesWebVTTWithoutHourComponent() throws {
    let cues = ExternalSubtitleParser.parseWebVTT(
      """
      WEBVTT

      00:02.000 --> 00:04.250
      Hello
      """
    )

    XCTAssertEqual(cues.count, 1)
    XCTAssertEqual(cues[0].start, 2, accuracy: 0.001)
    XCTAssertEqual(cues[0].end, 4.25, accuracy: 0.001)
  }

  func testParsesBasicASSDialogue() {
    let cues = ExternalSubtitleParser.parseASS(
      """
      [Events]
      Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
      Dialogue: 0,0:00:01.20,0:00:03.40,Default,,0,0,0,,{\\i1}Olá{\\i0}\\NPortugal
      """
    )

    XCTAssertEqual(cues.count, 1)
    XCTAssertEqual(cues[0].start, 1.2, accuracy: 0.001)
    XCTAssertEqual(cues[0].end, 3.4, accuracy: 0.001)
    XCTAssertEqual(cues[0].text, "Olá\nPortugal")
  }

}
