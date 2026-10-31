// A stand-in for the XCTest API the tests use, so they can be type-checked on a Mac that has only
// the Command Line Tools (tools/typecheck/typecheck.sh emits this file as module `XCTest`). Only the
// signatures matter: nothing here runs a test. Add a declaration when a test starts using another
// part of XCTest (the type-check then says what is missing).
@_exported import Foundation // the real XCTest re-exports Foundation

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
