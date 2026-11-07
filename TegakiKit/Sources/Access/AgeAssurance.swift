// 1.2.2 (docs/R1_2_2.md §3): whether to ask the system for the person's age range (Apple's Declared Age
// Range), and when. Pure: the app reads Apple's regulatory flag and shows the system's own sheet
// (Sources/TegakiCalendar/Views/AgeRangeAsker.swift); this file only says what comes next. Nothing is
// stored: the state is one launch's, kept in memory by the app.
import Foundation

public enum AgeAssurance {
    /// The three ages that give the four categories of the US state laws (under 13, 13–15, 16–17,
    /// 18 and over; Texas Business & Commerce Code §121.021(b)). Where a law asks, Apple replaces them
    /// with the region's own; elsewhere the app never asks.
    public static let ageGates = [13, 16, 18]
    /// Seconds from a calm moment to the system sheet; `canAskNow` is asked again after them.
    public static let settle: Double = 1
    /// Seconds without new ink before the sheet may come (the same 3 s as `ReviewPrompt.quietAfterInk`),
    /// so it never cuts into a pen stroke.
    public static let quietAfterInk: Double = 3

    /// The device's OS in the three bands of docs/R1_2_2.md §2.6.
    public enum Band: Equatable, Sendable {
        /// iOS / iPadOS 17.0 – 26.1: no API says whether a law applies to this person, so never ask.
        case noRegionCheck
        /// 26.2 – 26.3: `AgeRangeService.isEligibleForAgeFeatures`.
        case eligibility
        /// 26.4 and later: `AgeRangeService.requiredRegulatoryFeatures` contains `.declaredAgeRangeRequired`.
        case regulatoryFeatures
    }

    /// What the system said about this person in this launch.
    public enum Signal: Equatable, Sendable {
        /// Not read yet in this launch.
        case notRead
        /// A law asks for the age range (the flag is there / eligible is true).
        case required
        /// No law asks (the flag is missing / eligible is false).
        case notRequired
        /// The read failed (notAvailable, a network error, …): nothing in this launch.
        case unreadable
    }

    /// Why nothing more happens in this launch. `mac`: an iPad app on a Mac or on Apple Vision Pro (§2.6).
    public enum Reason: Equatable, Sendable {
        case screenshotMode, testHost, mac, askedThisLaunch, oldSystem, notRequired, unreadable
    }

    public enum Step: Equatable, Sendable {
        case stop(Reason)
        case readRegulatoryFeatures
        case readEligibility
        case requestAgeRange
    }

    /// `ProcessInfo.operatingSystemVersion`'s major and minor → the band.
    public static func band(major: Int, minor: Int) -> Band {
        if major > 26 || (major == 26 && minor >= 4) { return .regulatoryFeatures }
        if major == 26 && minor >= 2 { return .eligibility }
        return .noRegionCheck
    }

    /// The next step of this launch. The app runs it until `.stop`: read the flag of the band, then ask
    /// only when the flag says a law requires it, once.
    public static func nextStep(band: Band, signal: Signal, askedThisLaunch: Bool,
                                screenshot: Bool, testHost: Bool, onMac: Bool) -> Step {
        if screenshot { return .stop(.screenshotMode) }
        if testHost { return .stop(.testHost) }
        if onMac { return .stop(.mac) }
        if askedThisLaunch { return .stop(.askedThisLaunch) }
        switch (band, signal) {
        case (.noRegionCheck, _): return .stop(.oldSystem)
        case (.eligibility, .notRead): return .readEligibility
        case (.regulatoryFeatures, .notRead): return .readRegulatoryFeatures
        case (_, .required): return .requestAgeRange
        case (_, .notRequired): return .stop(.notRequired)
        case (_, .unreadable): return .stop(.unreadable)
        }
    }

    /// The screen is calm enough for the system sheet: in front, past the first-time guide, nothing of
    /// ours up (a sheet, the account question, the save-failed alert, a toast), the first-launch paywall
    /// decided and no ink in the last `quietAfterInk` seconds.
    public static func canAskNow(active: Bool, onboardingDone: Bool, sheetIsUp: Bool, accountQuestion: Bool,
                                 saveFailed: Bool, firstPaywallPending: Bool, toastShowing: Bool,
                                 inkRecently: Bool) -> Bool {
        active && onboardingDone && !sheetIsUp && !accountQuestion && !saveFailed && !firstPaywallPending
            && !toastShowing && !inkRecently
    }
}
