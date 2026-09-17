import Foundation

/// Base class with an overridable method.
///
/// The type names `Base` / `Sub` are renamed, but `tick()` MUST stay: it is an
/// `override` (name dictated by the superclass) and also a non-unique name.
class Base {
    func tick() -> Int { 1 }
}

final class Sub: Base {
    override func tick() -> Int { 2 }
}

/// `@objc` selector target.
///
/// The type `Ticker` is renamed, but `fire()` MUST stay: it is resolved by
/// string at runtime through `#selector`. The obfuscator skips `@objc` funcs.
final class Ticker: NSObject {
    @objc func fire() {}

    // Unique func -> SHOULD be renamed. `#selector(Ticker.fire)` still resolves
    // because the selector string comes from `fire`, which is untouched.
    func selectorName() -> String {
        NSStringFromSelector(#selector(Ticker.fire))
    }
}
