import Foundation

/// Orchestrates subscription renewals.
///
/// SHOULD be renamed: unique type name + unique private helpers, no external
/// references, not public. The obfuscator renames `SubscriptionService`,
/// `renew`, `auditLine`, and `applyFloor`.
final class SubscriptionService {
    let engine = PricingEngine()
    private(set) var lastAudit = ""

    func renew(_ plan: Plan, months: Int) -> Double {
        let price = engine.renewalPrice(for: plan, months: months)
        lastAudit = auditLine()
        return applyFloor(price)
    }

    // Unique private helper -> SHOULD be renamed.
    // The returned string literal "SubscriptionService" MUST stay untouched:
    // the class *identifier* is renamed, but the *string* is masked.
    private func auditLine() -> String { "SubscriptionService" }

    // Unique private helper -> SHOULD be renamed.
    private func applyFloor(_ value: Double) -> Double { max(value, 0) }
}
