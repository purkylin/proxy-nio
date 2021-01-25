import XCTest
@testable import proxy_nio

final class proxy_nioTests: XCTestCase {
    func testPort() {
        let port: UInt16 = 1080
        XCTAssertEqual(port.bytes, [0x04, 0x38])
    }
    
//    func testIP1() {
//        let v4 = SocksV4Address(host: "192.168.1.12", port: 80)!
//        XCTAssertEqual(v4.bytes, [0xc0, 0xa8, 0x01, 0x0c, 0x00, 0x50])
//        
//        let v6 = SocksV6Address(host: "::ffff:c0a8:0102", port: 80)!
//        
//        let v6Bytes: [UInt8] = [
//            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//            0x00, 0x00, 0xff, 0xff, 0xc0, 0xa8, 0x01, 0x02,
//            0x00, 0x50
//        ]
//        XCTAssertEqual(v6.bytes, v6Bytes)
//    }
//    
//    func testIP2() {
//        let v4 = SocksV4Address(bytes: [0xc0, 0xa8, 0x01, 0x0c, 0x00, 0x50])!
//        XCTAssertEqual(v4.description, "192.168.1.12:80")
//        
//        let v6Bytes: [UInt8] = [
//            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//            0x00, 0x00, 0xff, 0xff, 0xc0, 0xa8, 0x01, 0x02,
//            0x00, 0x50
//        ]
//        
//        let v6 = SocksV6Address(bytes: v6Bytes)!
//        XCTAssertEqual(v6.description, "::ffff:192.168.1.2:80")
//    }

    static var allTests = [
        ("testExample", testPort),
    ]
}
