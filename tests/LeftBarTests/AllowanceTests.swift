import XCTest
@testable import LeftBar

final class AllowanceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func window(_ used: Double?, label: String = "Week", short: String = "w") -> Window {
        Window(label: label, short: short, used: used, resetsAt: now.addingTimeInterval(3600))
    }

    func testFullPartialAndEmptyAllowance() {
        XCTAssertEqual(window(0).remaining(at: now), 100)
        XCTAssertEqual(window(23).remaining(at: now), 77)
        XCTAssertEqual(window(100).remaining(at: now), 0)
    }

    func testUnknownInvalidAndExpiredReadingsStayUnknown() {
        for used in [nil, -1, 101, Double.nan, Double.infinity] as [Double?] {
            XCTAssertNil(window(used).remaining(at: now))
        }
        let expired = Window(label: "Week", short: "w", used: 70, resetsAt: now)
        XCTAssertNil(expired.remaining(at: now))
        XCTAssertNil(expired.remaining(at: now.addingTimeInterval(1)))
    }

    func testRoundingDoesNotClaimFullOrEmptyEarly() {
        XCTAssertEqual(percentText(100), "100")
        XCTAssertEqual(percentText(99.8), "99")
        XCTAssertEqual(percentText(0.2), "<1")
        XCTAssertEqual(percentText(0), "0")
        XCTAssertEqual(percentText(nil), "—")
    }

    func testClaudeUsesAllModelWeekEvenWhenCacheHasSessionFirst() throws {
        let session = window(4, label: "5-hour", short: "5h")
        let model = window(99, label: "Opus week")
        let week = window(63)
        let old = Snapshot(vendor: .claude, bar: session, windows: [session, model, week])
        let decoded = try JSONDecoder().decode(Snapshot.self, from: JSONEncoder().encode(old))
        XCTAssertEqual(decoded.displayWindow, week)
        XCTAssertEqual(decoded.displayWindow?.remaining(at: now), 37)
        XCTAssertEqual(decoded.displayWindows.first, week)
        XCTAssertEqual(decoded.displayWindows.count, 3)
    }

    func testClaudeNeverSubstitutesSessionOrModelForMissingWeeklyAllowance() {
        let session = window(0, label: "5-hour", short: "5h")
        let model = window(20, label: "Opus week")
        let snapshot = Snapshot(vendor: .claude, bar: session, windows: [session, model])
        XCTAssertNil(snapshot.displayWindow)
        XCTAssertEqual(snapshot.displayWindows.count, 2)
    }

    func testCodexKeepsPrimaryWindow() {
        let session = window(12, label: "5-hour", short: "5h")
        let snapshot = Snapshot(vendor: .codex, bar: session, windows: [session, window(89)])
        XCTAssertEqual(snapshot.displayWindow, session)
        XCTAssertEqual(snapshot.displayWindow?.remaining(at: now), 88)
    }

    func testBothClaudeCollectorsPreferWeeklyAllowance() throws {
        let file = try XCTUnwrap(Fetch.claudeFileSnapshot([
            "at": now.timeIntervalSince1970,
            "limits": ["five_hour": ["percent": 4], "seven_day": ["percent": 63]]
        ]))
        let cli = Fetch.claudeUsageSnapshot("Current session: 4% used\nCurrent week (all models): 63% used\nCurrent week (Opus): 89% used")
        for snapshot in [file, cli] {
            XCTAssertEqual(snapshot.bar?.label, "Week")
            XCTAssertEqual(snapshot.windows.first?.label, "Week")
            XCTAssertEqual(snapshot.displayWindow?.remaining(at: now), 37)
        }
        XCTAssertEqual(cli.windows.count, 3)
    }

    func testBothClaudeCollectorsKeepMissingWeeklyAllowanceUnknown() throws {
        let file = try XCTUnwrap(Fetch.claudeFileSnapshot([
            "limits": ["five_hour": ["percent": 4]]
        ]))
        let cli = Fetch.claudeUsageSnapshot("Current session: 4% used")
        for snapshot in [file, cli] {
            XCTAssertEqual(snapshot.state, .ok)
            XCTAssertNil(snapshot.bar)
            XCTAssertNil(snapshot.displayWindow)
            XCTAssertEqual(snapshot.windows.count, 1)
        }
    }

    func testSecondaryExhaustionStillWarnsWhenClaudeWeekHasRoom() {
        let future = Date().addingTimeInterval(3600)
        let week = Window(label: "Week", short: "w", used: 30, resetsAt: future)
        var session = Window(label: "5-hour", short: "5h", used: 95, resetsAt: future)
        XCTAssertTrue(Snapshot(vendor: .claude, bar: week, windows: [week, session]).otherHot)
        session.resetsAt = Date().addingTimeInterval(-1)
        XCTAssertFalse(Snapshot(vendor: .claude, bar: week, windows: [week, session]).otherHot)
        XCTAssertFalse(Snapshot(vendor: .claude, bar: week, windows: [week]).otherHot)
    }
}
