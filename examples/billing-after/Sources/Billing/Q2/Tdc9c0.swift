import Foundation

/// Computes subscription prices.
///
/// `Tdc9c0` (type) and `renewalPrice` / `f7bcc8` (unique funcs) SHOULD be
/// renamed. The two `total(...)` overloads share a name -> NON-UNIQUE, MUST stay.
struct Tdc9c0 {
    func renewalPrice(for plan: Tbecb8, months: Int) -> Double {
        let base = plan.monthlyPrice * Double(months)
        let discount = base * plan.discountRate
        return f7bcc8(base - discount)
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
    private func f7bcc8(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
