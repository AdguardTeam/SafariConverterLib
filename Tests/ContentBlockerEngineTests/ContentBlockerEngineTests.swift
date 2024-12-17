import XCTest
import Foundation

@testable import ContentBlockerEngine

class ContentBlockerEngineTests: XCTestCase {
    let json = """
                   [
                       {
                           "trigger": {
                               "url-filter": "example.org"
                           },
                           "action": {
                               "type": "script",
                               "script": "included-script"
                           }
                       },
                       {
                           "trigger": {
                               "url-filter": "not-example.org"
                           },
                           "action": {
                               "type": "css-extended",
                               "css": "#excluded-css:has(div) { height: 5px; }"
                           }
                       }
                   ]
               """

    func buildUrl(_ path: String) -> URL {
        let thisSourceFile = URL(fileURLWithPath: #file)
        let thisDirectory = thisSourceFile.deletingLastPathComponent()
        return thisDirectory.appendingPathComponent(path)
    }

    func getString(_ path: String) -> String {
        let path = buildUrl(path)
        return try! String(contentsOf: path, encoding: String.Encoding.utf8)
    }

    func getData(_ path: String) -> Data {
        let path = buildUrl(path)
        return try! Data(contentsOf: path)
    }

    func testInitiatesFromJson() {
        let contentBlockerEngine = try! ContentBlockerEngine(json)
        let data = try! contentBlockerEngine.getData(url: URL(string: "http://example.org")!)
        XCTAssertNotNil(data)
    }

    func testInitiatesFromEncodedData() {
        let firstEngine = try! ContentBlockerEngine(json)
        let firstEngineData = try! firstEngine.getData(url: URL(string: "http://example.org")!)
        XCTAssertNotNil(firstEngineData)

        let encoder = JSONEncoder()
        let encodedData = try! encoder.encode(firstEngine)

        let decoder = JSONDecoder()
        let secondEngine = try! decoder.decode(ContentBlockerEngine.self, from: encodedData)
        let secondEngineData = try! secondEngine.getData(url: URL(string: "http://example.org")!)

        XCTAssertEqual(firstEngineData, secondEngineData)
    }

    /**
     Tested on Basic + Russian rules, average result is ~860ms
     on Macbook Pro 2,6 GHz 6-Core Intel Core i7, 16 GB 2400 MHz DDR4
     */
    func testPerformanceInitFromJson() {
        let json = getString("advanced-rules.json")
        self.measure {
            let firstEngine = try! ContentBlockerEngine(json)
            let firstEngineData = try! firstEngine.getData(url: URL(string: "http://example.org")!)
            XCTAssertNotNil(firstEngineData)
        }
    }

    /**
     Tested on Basic + Russian rules, average result is ~300ms
     on Macbook Pro 2,6 GHz 6-Core Intel Core i7, 16 GB 2400 MHz DDR4
     */
    func testPerformanceInitFromEncodedData() {
        let json = getString("advanced-rules.json")
        let firstEngine = try! ContentBlockerEngine(json)
        let encoder = JSONEncoder()
        let encodedData = try! encoder.encode(firstEngine)

        let decoder = JSONDecoder()
        self.measure {
            let secondEngine = try! decoder.decode(ContentBlockerEngine.self, from: encodedData)
            let secondEngineData = try! secondEngine.getData(url: URL(string: "http://example.org")!)
            XCTAssertNotNil(secondEngineData)
        }
    }

    /**
     This test tests that between process launches ContentBlockerEngine returns same results
     "sample-rules.encoded.data" contains encoded instance of ContentBlockerEngine
     initiated with rules from "sample-rules.json"
     */
    func testJsonAndEncodedDataReturnSameRules() {
        let json = getString("sample-rules.json")
        let firstEngine = try! ContentBlockerEngine(json)

        let encodedData = getData("sample-rules.encoded.data")
        let decoder = JSONDecoder()
        let secondEngine = try! decoder.decode(ContentBlockerEngine.self, from: encodedData)

        let firstEngineData = try! firstEngine.getData(url: URL(string: "http://example.org")!)
        let secondEngineData = try! secondEngine.getData(url: URL(string: "http://example.org")!)

        XCTAssertEqual(firstEngineData, secondEngineData, "should be equal")
    }
}
