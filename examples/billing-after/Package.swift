// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Billing",
    products: [
        .library(name: "Billing", targets: ["Billing"]),
    ],
    targets: [
        .target(name: "Billing"),
        .testTarget(name: "BillingTests", dependencies: ["Billing"]),
    ]
)
