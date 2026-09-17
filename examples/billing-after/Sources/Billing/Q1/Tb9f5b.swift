import Foundation

/// Orchestrates subscription renewals.
///
/// SHOULD be renamed: unique type name + unique private helpers, no external
/// references, not public. The obfuscator renames `Tb9f5b`,
/// `renew`, `fcba7b`, and `f0b262`.
final class Tb9f5b {
    let engine = Tdc9c0()
    private(set) var lastAudit = ""

    func renew(_ plan: Tbecb8, months: Int) -> Double {
        let price = engine.renewalPrice(for: plan, months: months)
        lastAudit = fcba7b()
        return f0b262(price)
    }

    // Unique private helper -> SHOULD be renamed.
    // The returned string literal "SubscriptionService" MUST stay untouched:
    // the class *identifier* is renamed, but the *string* is masked.
    private func fcba7b() -> String { "SubscriptionService" }

    // Unique private helper -> SHOULD be renamed.
    private func f0b262(_ value: Double) -> Double { max(value, 0) }
}
