import Access
import XCTest
@testable import TegakiCalendar

/// 1.2.2 (docs/R1_2_2.md §3, §6.3): Apple's Declared Age Range, the minimum. In the XCTest host the steps
/// stop before any call to Apple (`.stop(.testHost)`), so nothing here reads the flag or shows the sheet.
/// The rule itself (`AgeAssurance`) is tested in TegakiKit (AgeAssuranceTests and KitChecks).
@MainActor
final class AgeRangeAskerTests: XCTestCase {
    /// With this process's own values the first step is `.stop(.testHost)`, and nothing was read or asked.
    func testTheTestHostStopsBeforeAnyCall() {
        XCTAssertTrue(SyncEngine.isTestHost)
        XCTAssertFalse(ScreenshotMode.isActive, "the unit tests do not run in screenshot mode")
        let step = AgeAssurance.nextStep(band: AgeRangeAsker.band, signal: AgeRangeAsker.signal,
                                         askedThisLaunch: AgeRangeAsker.askedThisLaunch,
                                         screenshot: ScreenshotMode.isActive, testHost: SyncEngine.isTestHost,
                                         onMac: AgeRangeAsker.onMac)
        XCTAssertEqual(step, .stop(.testHost))
        XCTAssertFalse(AgeRangeAsker.askedThisLaunch, "the host never asks")
        XCTAssertEqual(AgeRangeAsker.signal, .notRead, "the host never reads the flag")
    }

    /// The band is the one of the simulator's OS, and the simulator is neither a Mac nor Apple Vision Pro.
    func testBandFollowsTheSystem() {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        XCTAssertEqual(AgeRangeAsker.band, AgeAssurance.band(major: version.majorVersion, minor: version.minorVersion))
        XCTAssertFalse(AgeRangeAsker.onMac)
    }

    /// Only the two read steps read: any other step gives `.unreadable` without touching DeclaredAgeRange.
    func testOnlyTheTwoReadStepsRead() async {
        let afterStop = await AgeRangeAsker.read(.stop(.oldSystem))
        XCTAssertEqual(afterStop, .unreadable)
        let afterRequest = await AgeRangeAsker.read(.requestAgeRange)
        XCTAssertEqual(afterRequest, .unreadable)
        XCTAssertEqual(AgeRangeAsker.signal, .notRead, "read does not change this launch's signal")
    }
}
