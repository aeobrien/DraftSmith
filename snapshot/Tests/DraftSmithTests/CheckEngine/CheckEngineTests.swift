import XCTest
import SwiftData
@testable import DraftSmith

@MainActor
final class CheckEngineTests: XCTestCase {

    // MARK: - SwiftData Schema Validation

    func testSchema_allModels_containerCreation() {
        let schema = Schema([Issue.self, ReviewSession.self, ExamplePair.self,
                            FeedbackEvent.self, StyleCapsule.self, PromptTemplate.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        XCTAssertNotNil(container)
    }

    func testInsert_Issue_viaContainer() {
        let container = TestHelpers.createTestModelContainer()
        let ctx = container.mainContext
        ctx.insert(Issue(pageIndex: 0, selectionText: "t", message: "m"))
        try? ctx.save()

        let fetched = try? ctx.fetch(FetchDescriptor<Issue>())
        XCTAssertEqual(fetched?.count, 1)
    }

    // MARK: - Service Creation

    func testServiceManager_creation() {
        let capabilities = SystemCapabilities(physicalMemory: 16 * 1024 * 1024 * 1024, processorCount: 8)
        let sm = ServiceManager(capabilities: capabilities)
        XCTAssertNotNil(sm)
    }
}
