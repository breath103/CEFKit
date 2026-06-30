@testable import HelloChromium
import SwiftData
import XCTest

/// Round-trips the persisted models through SwiftData to prove the schema and
/// the session→tabs relationship survive a save + re-fetch.
@MainActor
final class SessionPersistenceTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Session.self, TabRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    func testSessionAndTabsRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = Session()
        context.insert(session)
        let first = TabRecord(url: URL(string: "https://a.example")!, title: "A", sortIndex: 0, session: session)
        let second = TabRecord(url: URL(string: "https://b.example")!, title: "B", sortIndex: 1, session: session)
        context.insert(first)
        context.insert(second)
        session.selectedTabID = second.id
        try context.save()

        // Re-fetch from a fresh context on the same store.
        let refetched = try XCTUnwrap(
            container.mainContext.fetch(FetchDescriptor<Session>()).first
        )
        XCTAssertEqual(refetched.selectedTabID, second.id)
        XCTAssertEqual(refetched.orderedTabs.map(\.title), ["A", "B"])
        XCTAssertEqual(refetched.orderedTabs.map(\.sortIndex), [0, 1])
        XCTAssertEqual(refetched.orderedTabs.first?.url, URL(string: "https://a.example"))
    }

    func testDisplayTitleFallsBackToHost() {
        let tab = TabRecord(url: URL(string: "https://news.example/path")!, title: "", sortIndex: 0)
        XCTAssertEqual(tab.displayTitle, "news.example")
    }
}
