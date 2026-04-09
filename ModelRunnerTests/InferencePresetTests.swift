import XCTest
@testable import ModelRunner

final class InferencePresetTests: XCTestCase {

    func testPreciseValues() {
        XCTAssertEqual(InferencePreset.precise.temperature, 0.3, accuracy: 0.001)
        XCTAssertEqual(InferencePreset.precise.topP, 0.7, accuracy: 0.001)
    }

    func testBalancedValues() {
        XCTAssertEqual(InferencePreset.balanced.temperature, 0.7, accuracy: 0.001)
        XCTAssertEqual(InferencePreset.balanced.topP, 0.9, accuracy: 0.001)
    }

    func testCreativeValues() {
        XCTAssertEqual(InferencePreset.creative.temperature, 1.2, accuracy: 0.001)
        XCTAssertEqual(InferencePreset.creative.topP, 0.95, accuracy: 0.001)
    }

    func testAllCasesCount() {
        XCTAssertEqual(InferencePreset.allCases.count, 3)
    }

    func testTemperatureInValidRange() {
        for preset in InferencePreset.allCases {
            XCTAssertGreaterThanOrEqual(preset.temperature, 0.0)
            XCTAssertLessThanOrEqual(preset.temperature, 2.0)
        }
    }

    func testTopPInValidRange() {
        for preset in InferencePreset.allCases {
            XCTAssertGreaterThan(preset.topP, 0.0)
            XCTAssertLessThanOrEqual(preset.topP, 1.0)
        }
    }
}
