import Foundation

/// Computes subscription prices.
///
/// `PricingEngine` (type) and `renewalPrice` / `round2` (unique funcs) SHOULD be
/// renamed. The two `total(...)` overloads share a name -> NON-UNIQUE, MUST stay.
struct PricingEngine {
    func renewalPrice(for plan: Plan, months: Int) -> Double {
        let base = plan.monthlyPrice * Double(months)
        let discount = base * plan.discountRate
        return round2(base - discount)
    }

    // Overloaded `total` -> non-unique name, MUST stay (renaming one but not the
    // other would change overload resolution silently).
    func total(_ amounts: [Double]) -> Double {
        amounts.reduce(0, +)
    }

    func total(_ lhs: Double, _ rhs: Double) -> Double {
        lhs + rhs
    }

    // Unique private helper -> SHOULD be renamed.
    private func round2(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
