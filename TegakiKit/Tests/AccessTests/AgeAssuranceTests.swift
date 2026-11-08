import XCTest
import Foundation
import Access

/// `AgeAssurance`, whether and when the app reads Apple's regulatory flag and asks for the age range
/// (Apple's Declared Age Range, docs/R1_2_2.md §3.2, §3.3). The same cases run in KitChecks ("age range (1.2.2)").
final class AgeAssuranceTests: XCTestCase {
    private let bands: [AgeAssurance.Band] = [.noRegionCheck, .eligibility, .regulatoryFeatures]
    private let signals: [AgeAssurance.Signal] = [.notRead, .required, .notRequired, .unreadable]

    private func step(_ band: AgeAssurance.Band, _ signal: AgeAssurance.Signal, asked: Bool = false,
                      screenshot: Bool = false, testHost: Bool = false, onMac: Bool = false) -> AgeAssurance.Step {
        AgeAssurance.nextStep(band: band, signal: signal, askedThisLaunch: asked, screenshot: screenshot,
                              testHost: testHost, onMac: onMac)
    }

    func testConstants() {
        XCTAssertEqual(AgeAssurance.ageGates, [13, 16, 18])
        XCTAssertEqual(AgeAssurance.settle, 1)
        XCTAssertEqual(AgeAssurance.quietAfterInk, 3)
        // Apple: each range between the gates is at least 2 years (16–17 is the shortest).
        let gates = AgeAssurance.ageGates
        for i in 1..<gates.count {
            XCTAssertGreaterThanOrEqual(gates[i] - gates[i - 1], 2, "\(gates[i - 1])–\(gates[i] - 1)")
        }
    }

    func testBands() {
        for (major, minor) in [(17, 0), (18, 7), (26, 0), (26, 1)] {
            XCTAssertEqual(AgeAssurance.band(major: major, minor: minor), .noRegionCheck, "\(major).\(minor)")
        }
        for (major, minor) in [(26, 2), (26, 3)] {
            XCTAssertEqual(AgeAssurance.band(major: major, minor: minor), .eligibility, "\(major).\(minor)")
        }
        for (major, minor) in [(26, 4), (26, 5), (27, 0), (27, 2)] {
            XCTAssertEqual(AgeAssurance.band(major: major, minor: minor), .regulatoryFeatures, "\(major).\(minor)")
        }
    }

    /// The named rows of docs/R1_2_2.md §3.3 (the first row that matches wins).
    func testTheRowsOfTheTable() {
        XCTAssertEqual(step(.regulatoryFeatures, .required, screenshot: true), .stop(.screenshotMode), "row 1")
        XCTAssertEqual(step(.regulatoryFeatures, .required, testHost: true), .stop(.testHost), "row 2")
        XCTAssertEqual(step(.regulatoryFeatures, .required, onMac: true), .stop(.mac), "row 3")
        XCTAssertEqual(step(.regulatoryFeatures, .required, asked: true), .stop(.askedThisLaunch), "row 4")
        XCTAssertEqual(step(.noRegionCheck, .notRead), .stop(.oldSystem), "row 5")
        XCTAssertEqual(step(.noRegionCheck, .required), .stop(.oldSystem), "row 5, whatever the signal")
        XCTAssertEqual(step(.eligibility, .notRead), .readEligibility, "row 6")
        XCTAssertEqual(step(.eligibility, .required), .requestAgeRange, "row 8 (26.2–26.3)")
        XCTAssertEqual(step(.eligibility, .notRequired), .stop(.notRequired), "row 9 (26.2–26.3)")
        XCTAssertEqual(step(.eligibility, .unreadable), .stop(.unreadable), "row 10 (26.2–26.3)")
        XCTAssertEqual(step(.regulatoryFeatures, .notRead), .readRegulatoryFeatures, "row 7")
        XCTAssertEqual(step(.regulatoryFeatures, .required), .requestAgeRange, "row 8 (26.4–)")
        XCTAssertEqual(step(.regulatoryFeatures, .notRequired), .stop(.notRequired), "row 9 (26.4–): Japan")
        XCTAssertEqual(step(.regulatoryFeatures, .unreadable), .stop(.unreadable), "row 10 (26.4–)")
        XCTAssertEqual(step(.regulatoryFeatures, .notRead, screenshot: true), .stop(.screenshotMode), "screenshot mode stops before any read")
    }

    /// One launch, step by step, as the app runs it: the read gives `flag`, the request sets `asked`.
    private func walk(band: AgeAssurance.Band, flag: AgeAssurance.Signal) -> [AgeAssurance.Step] {
        var signal = AgeAssurance.Signal.notRead
        var asked = false
        var steps: [AgeAssurance.Step] = []
        while steps.count < 10 {
            let next = step(band, signal, asked: asked)
            steps.append(next)
            switch next {
            case .stop: return steps
            case .readRegulatoryFeatures, .readEligibility: signal = flag
            case .requestAgeRange: asked = true
            }
        }
        return steps
    }

    func testOneLaunch() {
        XCTAssertEqual(walk(band: .regulatoryFeatures, flag: .required),
                       [.readRegulatoryFeatures, .requestAgeRange, .stop(.askedThisLaunch)], "a person with the flag (26.5)")
        XCTAssertEqual(walk(band: .regulatoryFeatures, flag: .notRequired),
                       [.readRegulatoryFeatures, .stop(.notRequired)], "a person in Japan (26.5)")
        XCTAssertEqual(walk(band: .eligibility, flag: .required),
                       [.readEligibility, .requestAgeRange, .stop(.askedThisLaunch)], "an eligible person (26.2)")
        XCTAssertEqual(walk(band: .eligibility, flag: .unreadable),
                       [.readEligibility, .stop(.unreadable)], "a read that failed (26.3)")
        XCTAssertEqual(walk(band: .noRegionCheck, flag: .required), [.stop(.oldSystem)], "iOS 18")
    }

    /// Every input (2⁴ × 3 × 4 = 192): only the four named inputs touch the API (read or ask), and only
    /// the two named ones show the sheet.
    func testOnlyTheNamedInputsTouchTheAPI() {
        var touching = 0
        var showing = 0
        for flags in 0..<16 {
            let asked = flags & 1 != 0, screenshot = flags & 2 != 0, testHost = flags & 4 != 0, onMac = flags & 8 != 0
            for band in bands {
                for signal in signals {
                    let next = step(band, signal, asked: asked, screenshot: screenshot, testHost: testHost, onMac: onMac)
                    let touches: Bool
                    let shows: Bool
                    switch next {
                    case .stop: touches = false; shows = false
                    case .readRegulatoryFeatures, .readEligibility: touches = true; shows = false
                    case .requestAgeRange: touches = true; shows = true
                    }
                    let plain = flags == 0 && band != .noRegionCheck
                    XCTAssertEqual(touches, plain && (signal == .notRead || signal == .required),
                                   "touches: \(band) \(signal) asked \(asked) screenshot \(screenshot) testHost \(testHost) onMac \(onMac)")
                    XCTAssertEqual(shows, plain && signal == .required,
                                   "shows: \(band) \(signal) asked \(asked) screenshot \(screenshot) testHost \(testHost) onMac \(onMac)")
                    if touches { touching += 1 }
                    if shows { showing += 1 }
                }
            }
        }
        XCTAssertEqual(touching, 4)
        XCTAssertEqual(showing, 2)
    }

    /// Every input (2⁸ = 256): calm only when in front, past the guide, nothing up, no question, no save
    /// failure, the paywall decided, no toast and no fresh ink.
    func testCanAskNow() {
        var calmCount = 0
        for bits in 0..<256 {
            let v = (0..<8).map { bits & (1 << $0) != 0 }
            let calm = AgeAssurance.canAskNow(active: v[0], onboardingDone: v[1], sheetIsUp: v[2], accountQuestion: v[3],
                                              saveFailed: v[4], firstPaywallPending: v[5], toastShowing: v[6], inkRecently: v[7])
            XCTAssertEqual(calm, v == [true, true, false, false, false, false, false, false], "\(v)")
            if calm { calmCount += 1 }
        }
        XCTAssertEqual(calmCount, 1)
    }
}
