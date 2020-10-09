import XCTest
@testable import proxy_nio

final class proxy_nioTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(proxy_nio().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
