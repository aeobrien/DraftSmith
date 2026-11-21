import Foundation
import SwiftData
@testable import DraftSmith

enum TestHelpers {
    /// Creates an in-memory ModelContainer and returns both container and context.
    /// The caller MUST retain the container for the lifetime of the context,
    /// otherwise SwiftData operations (insert/fetch) will crash with SIGTRAP.
    @MainActor
    static func createTestModelContainer() -> ModelContainer {
        let schema = Schema([
            Issue.self,
            ReviewSession.self,
            ExamplePair.self,
            FeedbackEvent.self,
            StyleCapsule.self,
            PromptTemplate.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create test ModelContainer: \(error)")
        }
    }

    /// Convenience: creates an in-memory ModelContext.
    /// WARNING: The returned context's container may be deallocated if not retained
    /// separately. Prefer `createTestModelContainer()` and use `container.mainContext`.
    @MainActor
    static func createTestModelContext() -> ModelContext {
        return createTestModelContainer().mainContext
    }
}
