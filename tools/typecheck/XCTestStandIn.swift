// A stand-in for the XCTest API the tests use, so they can be type-checked on a Mac that has only
// the Command Line Tools (tools/typecheck/typecheck.sh emits this file as module `XCTest`). Only the
// signatures matter: nothing here runs a test. Add a declaration when a test starts using another
// part of XCTest (the type-check then says what is missing).
@_exported import Foundation // the real XCTest re-exports Foundation
import CoreGraphics

open class XCTestCase: NSObject {
    public override init() { super.init() }
    open func setUp() {}
    open func tearDown() {}
    open func setUpWithError() throws {}
    open func tearDownWithError() throws {}
    open func setUp() async throws {}
    open func tearDown() async throws {}
    open func addTeardownBlock(_ block: @escaping () -> Void) {}
    open var continueAfterFailure: Bool = true
    open var name: String { "" }
}

public struct XCTSkip: Error {
    public init(_ message: String? = nil, file: StaticString = #filePath, line: UInt = #line) {}
}

public func XCTFail(_ message: String = "", file: StaticString = #filePath, line: UInt = #line) {}

public func XCTAssert(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertTrue(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertFalse(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertNotNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}

public func XCTAssertEqual<T: Equatable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertEqual<T: FloatingPoint>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, accuracy: T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertEqual<T: Numeric>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, accuracy: T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertNotEqual<T: Equatable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertNotEqual<T: FloatingPoint>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, accuracy: T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}

public func XCTAssertGreaterThan<T: Comparable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertGreaterThanOrEqual<T: Comparable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertLessThan<T: Comparable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertLessThanOrEqual<T: Comparable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}

public func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line, _ errorHandler: (_ error: Error) -> Void = { _ in }) {}
public func XCTAssertNoThrow<T>(_ expression: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}

public func XCTUnwrap<T>(_ expression: @autoclosure () throws -> T?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) throws -> T {
    guard let value = try expression() else { throw XCTSkip("XCTUnwrap") }
    return value
}

// MARK: - UI testing (1.0.1: Tests/TegakiCalendarUITests, type-checked as its own module)

open class XCTAttachment: NSObject {
    public enum Lifetime: Int { case keepAlways, deleteOnSuccess }
    public init(screenshot: XCUIScreenshot) {}
    open var name: String?
    open var lifetime: Lifetime = .deleteOnSuccess
}

extension XCTestCase {
    public func add(_ attachment: XCTAttachment) {}
}

open class XCUIScreenshot: NSObject {}

open class XCUICoordinate: NSObject {
    public func withOffset(_ offsetVector: CGVector) -> XCUICoordinate { self }
    public func tap() {}
    public func doubleTap() {}
}

open class XCUIElement: NSObject {
    public enum ElementType: UInt { case any, other, application, button, staticText, window, scrollView }
    public var exists: Bool { false }
    public var frame: CGRect { .zero }
    public var label: String { "" }
    public var value: Any? { nil }
    public var isSelected: Bool { false }
    public var isHittable: Bool { false }
    public func waitForExistence(timeout: TimeInterval) -> Bool { false }
    public func coordinate(withNormalizedOffset normalizedOffset: CGVector) -> XCUICoordinate { XCUICoordinate() }
    public func tap() {}
    public func doubleTap() {}
    public func screenshot() -> XCUIScreenshot { XCUIScreenshot() }
    public func descendants(matching type: ElementType) -> XCUIElementQuery { XCUIElementQuery() }
    public var buttons: XCUIElementQuery { XCUIElementQuery() }
    public var staticTexts: XCUIElementQuery { XCUIElementQuery() }
    public var windows: XCUIElementQuery { XCUIElementQuery() }
    public var scrollViews: XCUIElementQuery { XCUIElementQuery() }
}

open class XCUIElementQuery: NSObject {
    public subscript(key: String) -> XCUIElement { XCUIElement() }
    public var firstMatch: XCUIElement { XCUIElement() }
    public var count: Int { 0 }
    public func matching(_ predicate: NSPredicate) -> XCUIElementQuery { self }
    public func matching(identifier: String) -> XCUIElementQuery { self }
    public func element(boundBy index: Int) -> XCUIElement { XCUIElement() }
}

open class XCUIApplication: XCUIElement {
    public override init() {}
    open var launchArguments: [String] = []
    open var launchEnvironment: [String: String] = [:]
    public func launch() {}
    public func terminate() {}
}

#if canImport(UIKit)
import UIKit

open class XCUIDevice: NSObject {
    public static let shared = XCUIDevice()
    open var orientation: UIDeviceOrientation = .portrait
}
#endif

public func XCTSkipIf(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String? = nil, file: StaticString = #filePath, line: UInt = #line) throws {}
public func XCTSkipUnless(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String? = nil, file: StaticString = #filePath, line: UInt = #line) throws {}
