import Foundation

/// Framework-facing entry point.
///
/// `publicAPI` MUST stay by default (framework rule): renaming a `public` symbol
/// would break the package's API. Its signature uses only primitive types so it
/// can stay `public` while the internal `Tbecb8` / `Tdc9c0` it uses are
/// renamed.
public func publicAPI(monthly: Double, months: Int, discount: Double) -> Double {
    let plan = Tbecb8(id: "public", monthlyPrice: monthly, discountRate: discount)
    return Tdc9c0().renewalPrice(for: plan, months: months)
}
