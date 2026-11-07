import Access
import UIKit
#if canImport(DeclaredAgeRange)
import DeclaredAgeRange
#endif

/// 1.2.2 (docs/R1_2_2.md §3): Apple's Declared Age Range, the minimum. Reads Apple's regulatory flag for
/// this person and, only where it says a law requires it, asks with the system's own sheet. The answer
/// is never looked at, kept or sent, and nothing on the screen changes. `CalendarRootScreen.askAgeRangeIfDue`
/// decides when (`AgeAssurance.canAskNow`) and runs `AgeAssurance.nextStep`; this is the only file of the
/// app that imports DeclaredAgeRange (iOS 26), behind `#if canImport` and `#available`, so iOS 17–26.1 never
/// touch it (the framework is weak-linked, project.yml).
@MainActor
enum AgeRangeAsker {
    /// This launch's state (docs/R1_2_2.md §3.5). Nothing is stored: the next launch starts again.
    static var signal: AgeAssurance.Signal = .notRead
    static var askedThisLaunch = false
    /// The steps of this launch reached `.stop` (the rating prompt waits for it, §3.7).
    static var finished = false

    /// The OS band of this device (§2.6).
    static var band: AgeAssurance.Band {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return AgeAssurance.band(major: version.majorVersion, minor: version.minorVersion)
    }

    /// An iPad app on a Mac ("Designed for iPad") or on Apple Vision Pro: Apple's flag is never set on a
    /// Mac, and DeclaredAgeRange is unavailable on visionOS (§2.6).
    static var onMac: Bool {
        if ProcessInfo.processInfo.isiOSAppOnMac { return true }
        if #available(iOS 26.1, *) { return ProcessInfo.processInfo.isiOSAppOnVision }
        return false
    }

    /// The view controller the system's sheet was asked over (weak). `sheetIsGone` looks at it (§3.4).
    static weak var shownOver: UIViewController?

    /// Nothing is presented over `shownOver` any more (or it is gone): the sheet is not up, whether or not
    /// Apple's call has returned. Looked at on the return to the foreground (§3.8).
    static var sheetIsGone: Bool { shownOver?.presentedViewController == nil }

    /// `.readRegulatoryFeatures` / `.readEligibility` → the signal. Any error → `.unreadable` (§3.4).
    static func read(_ step: AgeAssurance.Step) async -> AgeAssurance.Signal {
        #if AGE_FORCE
        // The check build only (testflight.yml `age_force`, docs/R1_2_2.md §6.4; never submitted): the flag
        // is taken as set, so Apple's sheet comes up on any account on iOS / iPadOS 26.2 or later.
        if step == .readRegulatoryFeatures || step == .readEligibility { return .required }
        #endif
        #if canImport(DeclaredAgeRange)
        switch step {
        case .readRegulatoryFeatures:
            if #available(iOS 26.4, *) {
                do {
                    let features = try await AgeRangeService.shared.requiredRegulatoryFeatures
                    return features.contains(.declaredAgeRangeRequired) ? .required : .notRequired
                } catch {
                    return .unreadable
                }
            }
        case .readEligibility:
            if #available(iOS 26.2, *) {
                do {
                    return try await AgeRangeService.shared.isEligibleForAgeFeatures ? .required : .notRequired
                } catch {
                    return .unreadable
                }
            }
        case .stop, .requestAgeRange:
            break
        }
        #endif
        return .unreadable
    }

    /// The system's sheet over `anchor`. Shared, declined, cancelled or an error: all the same, nothing
    /// changes (§3.4). The response is dropped here without being looked at.
    static func request(in anchor: UIViewController) async {
        shownOver = anchor
        #if canImport(DeclaredAgeRange)
        if #available(iOS 26.0, *) {
            let gates = AgeAssurance.ageGates
            _ = try? await AgeRangeService.shared.requestAgeRange(ageGates: gates[0], gates[1], gates[2], in: anchor)
        }
        #endif
    }

    /// The root view controller of the window in front (the system presents its sheet over it), only while
    /// nothing is presented over it. Anything presented (or still going away), even something the calm
    /// checks do not know of such as the account question's erase alert, means the moment is not calm: nil,
    /// and the next calm moment tries again (docs/R1_2_2.md §12.2).
    static func anchor() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }),
              let root = (scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first)?.rootViewController,
              root.presentedViewController == nil else { return nil }
        return root
    }
}
