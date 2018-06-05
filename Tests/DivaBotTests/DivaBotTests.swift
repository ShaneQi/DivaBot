import XCTest
@testable import DivaBot

final class DivaBotTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(DivaBot().text, "Hello, World!")
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
