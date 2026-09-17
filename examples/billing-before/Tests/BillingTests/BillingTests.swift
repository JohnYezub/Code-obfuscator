import XCTest
@testable import Billing

final class BillingTests: XCTestCase {
    let planPro = Plan(id: "pro", monthlyPrice: 9.99, discountRate: 0.10)

    // renewalPrice: 9.99 * 12 = 119.88; discount 10% = 11.988; net = 107.892 -> 107.89
    func testRenewalPrice() {
        let engine = PricingEngine()
        XCTAssertEqual(engine.renewalPrice(for: planPro, months: 12), 107.89, accuracy: 1e-6)
    }

    func testSubscriptionServiceRenew() {
        let service = SubscriptionService()
        let price = service.renew(planPro, months: 12)
        XCTAssertEqual(price, 107.89, accuracy: 1e-6)
    }

    // The log string literal "SubscriptionService" must survive obfuscation.
    func testAuditLogStringLiteral() {
        let service = SubscriptionService()
        _ = service.renew(planPro, months: 1)
        XCTAssertEqual(service.lastAudit, "SubscriptionService")
    }

    func testTotalOverloads() {
        let engine = PricingEngine()
        XCTAssertEqual(engine.total([1.0, 2.0, 3.0]), 6.0, accuracy: 1e-9)
        XCTAssertEqual(engine.total(2.0, 3.0), 5.0, accuracy: 1e-9)
    }

    // Dynamic dispatch through the override must be preserved.
    func testOverrideDispatch() {
        let value: Base = Sub()
        XCTAssertEqual(value.tick(), 2)
    }

    // #selector target name must be preserved.
    func testSelectorTargetName() {
        XCTAssertEqual(Ticker().selectorName(), "fire")
    }

    func testPublicAPI() {
        XCTAssertEqual(publicAPI(monthly: 9.99, months: 12, discount: 0.10), 107.89, accuracy: 1e-6)
    }

    // Exact JSON key set from the custom Codable machinery.
    func testPlanEncodesWithExactKeySet() throws {
        let data = try JSONEncoder().encode(planPro)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(obj.keys), ["plan_id", "monthly_price", "discount_rate"])
    }

    func testPlanRoundTrip() throws {
        let data = try JSONEncoder().encode(planPro)
        let decoded = try JSONDecoder().decode(Plan.self, from: data)
        XCTAssertEqual(decoded, planPro)
    }
}
