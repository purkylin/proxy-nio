import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(proxy_nioTests.allTests),
    ]
}
#endif
