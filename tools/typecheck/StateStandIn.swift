// A stand-in for SwiftUI's `@State` with the same shape (wrappedValue, a `Binding` projection,
// `DynamicProperty`, the nil-literal `init()`). tools/typecheck/typecheck.sh rewrites `@State` to
// `@StateStandIn` in its copy of the app sources and adds this file, because the Command Line Tools
// have no plugin for the macro the SDK's `@State` expands through. Never compiled into the app.
import SwiftUI

@propertyWrapper
struct StateStandIn<Value>: DynamicProperty {
    private final class Box {
        var value: Value
        init(_ value: Value) { self.value = value }
    }

    private let box: Box

    init(wrappedValue: Value) {
        box = Box(wrappedValue)
    }

    init(initialValue: Value) {
        box = Box(initialValue)
    }

    var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.value = newValue }
    }

    var projectedValue: Binding<Value> {
        Binding(get: { box.value }, set: { box.value = $0 })
    }
}

extension StateStandIn where Value: ExpressibleByNilLiteral {
    init() {
        box = Box(nil)
    }
}
