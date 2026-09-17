import Foundation

/// Codable pricing plan.
///
/// The observable Codable behavior MUST stay intact. The JSON contract lives in
/// the `Tcce12` *string raw values* (masked as string literals) and in the
/// custom `encode(to:)` (in the obfuscator's deny list). `init(from:)` is not a
/// `func`, so it is never matched. Even if the `Tcce12` type identifier is
/// renamed, every reference is rewritten consistently and both custom methods
/// keep using it, so no silent auto-synthesis fallback can occur.
struct Tbecb8: Codable, Equatable {
    let id: String
    let monthlyPrice: Double
    let discountRate: Double

    enum Tcce12: String, CodingKey {
        case id = "plan_id"
        case monthlyPrice = "monthly_price"
        case discountRate = "discount_rate"
    }

    init(id: String, monthlyPrice: Double, discountRate: Double) {
        self.id = id
        self.monthlyPrice = monthlyPrice
        self.discountRate = discountRate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Tcce12.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.monthlyPrice = try c.decode(Double.self, forKey: .monthlyPrice)
        self.discountRate = try c.decode(Double.self, forKey: .discountRate)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Tcce12.self)
        try c.encode(id, forKey: .id)
        try c.encode(monthlyPrice, forKey: .monthlyPrice)
        try c.encode(discountRate, forKey: .discountRate)
    }
}
