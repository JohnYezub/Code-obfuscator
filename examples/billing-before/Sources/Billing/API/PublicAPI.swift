import Foundation

/// Framework-facing entry point.
///
/// `publicAPI` MUST stay by default (framework rule): renaming a `public` symbol
/// would break the package's API. Its signature uses only primitive types so it
/// can stay `public` while the internal `Plan` / `PricingEngine` it uses are
/// renamed.
public func publicAPI(monthly: Double, months: Int, discount: Double) -> Double {
    let plan = Plan(id: "public", monthlyPrice: monthly, discountRate: discount)
    return PricingEngine().renewalPrice(for: plan, months: months)
}
