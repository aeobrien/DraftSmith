import XCTest
@testable import DraftSmith

final class SystemCapabilitiesTests: XCTestCase {

    // MARK: - RAM Detection

    func testIsLowRAM_trueAt8GB() {
        let caps = SystemCapabilities(physicalMemory: 8 * 1024 * 1024 * 1024, processorCount: 4)
        XCTAssertTrue(caps.isLowRAM, "8GB should be classified as low RAM (threshold is <=8GB)")
    }

    func testIsLowRAM_trueBelow8GB() {
        let caps = SystemCapabilities(physicalMemory: 4 * 1024 * 1024 * 1024, processorCount: 4)
        XCTAssertTrue(caps.isLowRAM)
    }

    func testIsLowRAM_falseAbove8GB() {
        let caps = SystemCapabilities(physicalMemory: 16 * 1024 * 1024 * 1024, processorCount: 8)
        XCTAssertFalse(caps.isLowRAM)
    }

    func testMemoryGB_computesCorrectly() {
        let caps = SystemCapabilities(physicalMemory: 16 * 1024 * 1024 * 1024, processorCount: 8)
        XCTAssertEqual(caps.memoryGB, 16.0, accuracy: 0.01)

        let caps32 = SystemCapabilities(physicalMemory: 32 * 1024 * 1024 * 1024, processorCount: 10)
        XCTAssertEqual(caps32.memoryGB, 32.0, accuracy: 0.01)
    }

    // MARK: - Model Recommendation Tiers

    func testRecommendedModelConfig_fullFor32GBPlus() {
        let caps = SystemCapabilities(physicalMemory: 32 * 1024 * 1024 * 1024, processorCount: 10)
        XCTAssertEqual(caps.recommendedModelConfig(), .full)
    }

    func testRecommendedModelConfig_fullFor64GB() {
        let caps = SystemCapabilities(physicalMemory: 64 * 1024 * 1024 * 1024, processorCount: 14)
        XCTAssertEqual(caps.recommendedModelConfig(), .full)
    }

    func testRecommendedModelConfig_standardFor16GB() {
        let caps = SystemCapabilities(physicalMemory: 16 * 1024 * 1024 * 1024, processorCount: 8)
        XCTAssertEqual(caps.recommendedModelConfig(), .standard)
    }

    func testRecommendedModelConfig_standardFor24GB() {
        let caps = SystemCapabilities(physicalMemory: 24 * 1024 * 1024 * 1024, processorCount: 8)
        XCTAssertEqual(caps.recommendedModelConfig(), .standard)
    }

    func testRecommendedModelConfig_compactFor8GB() {
        let caps = SystemCapabilities(physicalMemory: 8 * 1024 * 1024 * 1024, processorCount: 4)
        XCTAssertEqual(caps.recommendedModelConfig(), .compact)
    }

    func testRecommendedModelConfig_compactForBelow16GB() {
        let caps = SystemCapabilities(physicalMemory: 12 * 1024 * 1024 * 1024, processorCount: 6)
        XCTAssertEqual(caps.recommendedModelConfig(), .compact)
    }

    // MARK: - ModelRecommendation Display

    func testModelRecommendation_displayDescription() {
        XCTAssertTrue(ModelRecommendation.full.displayDescription.contains("Full"))
        XCTAssertTrue(ModelRecommendation.standard.displayDescription.contains("Standard"))
        XCTAssertTrue(ModelRecommendation.compact.displayDescription.contains("Compact"))
    }

    func testModelRecommendation_modelSizeWarning() {
        XCTAssertNotNil(ModelRecommendation.full.modelSizeWarning)
        XCTAssertNotNil(ModelRecommendation.standard.modelSizeWarning)
        XCTAssertNotNil(ModelRecommendation.compact.modelSizeWarning)
        XCTAssertTrue(ModelRecommendation.compact.modelSizeWarning!.contains("8 GB"))
    }

    // MARK: - Current System

    func testCurrent_hasNonZeroValues() {
        let current = SystemCapabilities.current
        XCTAssertGreaterThan(current.physicalMemory, 0)
        XCTAssertGreaterThan(current.processorCount, 0)
    }
}
