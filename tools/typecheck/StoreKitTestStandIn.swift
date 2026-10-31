// A stand-in for StoreKitTest's `SKTestSession` (the Mac Catalyst SDK of the Command Line Tools has
// no StoreKitTest.framework; docs/M5.md §2.2). tools/typecheck/typecheck.sh emits this file as module
// `StoreKitTest`. Only the signatures StoreKitSessionTests uses; nothing here runs.
import Foundation
import StoreKit

public final class SKTestSession {
    public init(configurationFileNamed: String) throws {}
    public var disableDialogs: Bool = false
    public var storefront: String = ""
    public var locale: Locale = .current
    public func clearTransactions() {}
    public func resetToDefaultState() {}
    public func expireSubscription(productIdentifier: String) throws {}
    public func refundTransaction(identifier: UInt) throws {}
    public func buyProduct(identifier: String, options: Set<Product.PurchaseOption> = []) async throws -> Transaction {
        fatalError("stand-in")
    }
}
