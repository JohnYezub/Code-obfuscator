import Foundation

/// Tf632d class with an overridable method.
///
/// The type names `Tf632d` / `T55070` are renamed, but `tick()` MUST stay: it is an
/// `override` (name dictated by the superclass) and also a non-unique name.
class Tf632d {
    func tick() -> Int { 1 }
}

final class T55070: Tf632d {
    override func tick() -> Int { 2 }
}

/// `@objc` selector target.
///
/// The type `T3fc6c` is renamed, but `fire()` MUST stay: it is resolved by
/// string at runtime through `#selector`. The obfuscator skips `@objc` funcs.
final class T3fc6c: NSObject {
    @objc func fire() {}

    // Unique func -> SHOULD be renamed. `#selector(T3fc6c.fire)` still resolves
    // because the selector string comes from `fire`, which is untouched.
    func selectorName() -> String {
        NSStringFromSelector(#selector(T3fc6c.fire))
    }
}
