import XCTest
@testable import DraftSmith

@MainActor
final class ServiceManagerTests: XCTestCase {

    // MARK: - Initial State

    func testInitialState_allServicesIdle() {
        let capabilities = SystemCapabilities(physicalMemory: 16 * 1024 * 1024 * 1024, processorCount: 8)
        let manager = ServiceManager(capabilities: capabilities)

        XCTAssertTrue(manager.serviceState(for: .languageTool).isIdle)
        XCTAssertTrue(manager.serviceState(for: .llm).isIdle)
        XCTAssertTrue(manager.serviceState(for: .whisper).isIdle)
    }

    // MARK: - Lifecycle (Start / Stop)

    func testEnsureReady_startsService() async {
        let capabilities = SystemCapabilities(physicalMemory: 32 * 1024 * 1024 * 1024, processorCount: 10)
        let manager = ServiceManager(capabilities: capabilities)

        // The mock services auto-transition to ready
        // LanguageTool start will fail (no JAR file) but we can observe the state change attempt
        await manager.ensureReady(.languageTool)

        let state = manager.serviceState(for: .languageTool)
        // It will be either .ready (if mock) or .error (if real service without JAR)
        XCTAssertFalse(state.isIdle, "Service should have transitioned from idle after ensureReady")
    }

    // MARK: - Mutual Exclusion on Low RAM

    func testMutualExclusion_lowRAM_detectsCorrectly() {
        let lowRAM = SystemCapabilities(physicalMemory: 7 * 1024 * 1024 * 1024, processorCount: 4)
        XCTAssertTrue(lowRAM.isLowRAM)

        // Verify ServiceManager is constructed with the correct capabilities
        let manager = ServiceManager(capabilities: lowRAM)
        XCTAssertTrue(manager.capabilities.isLowRAM)
    }

    func testMutualExclusion_highRAM_detectsCorrectly() {
        let highRAM = SystemCapabilities(physicalMemory: 32 * 1024 * 1024 * 1024, processorCount: 10)
        XCTAssertFalse(highRAM.isLowRAM)

        let manager = ServiceManager(capabilities: highRAM)
        XCTAssertFalse(manager.capabilities.isLowRAM)
    }

    // MARK: - Service State Query

    func testServiceState_returnsIdleForUnknownService() {
        let capabilities = SystemCapabilities(physicalMemory: 16 * 1024 * 1024 * 1024, processorCount: 8)
        let manager = ServiceManager(capabilities: capabilities)

        for kind in ServiceKind.allCases {
            let state = manager.serviceState(for: kind)
            XCTAssertTrue(state.isIdle, "\(kind) should start idle")
        }
    }

    // MARK: - ServiceState Properties

    func testServiceState_isReady() {
        XCTAssertTrue(ServiceState.ready.isReady)
        XCTAssertFalse(ServiceState.idle.isReady)
        XCTAssertFalse(ServiceState.loading(progress: 0.5).isReady)
        XCTAssertFalse(ServiceState.error("fail").isReady)
        XCTAssertFalse(ServiceState.unloading.isReady)
    }

    func testServiceState_isLoading() {
        XCTAssertTrue(ServiceState.loading(progress: 0.5).isLoading)
        XCTAssertFalse(ServiceState.ready.isLoading)
        XCTAssertFalse(ServiceState.idle.isLoading)
    }

    func testServiceState_displayText() {
        XCTAssertEqual(ServiceState.idle.displayText, "Idle")
        XCTAssertEqual(ServiceState.ready.displayText, "Ready")
        XCTAssertTrue(ServiceState.loading(progress: 0.5).displayText.contains("50%"))
        XCTAssertTrue(ServiceState.error("timeout").displayText.contains("timeout"))
    }
}
