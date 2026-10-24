// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "MailCore2",
    platforms: [.iOS("15.0"), .macOS(.v10_10)],
    products: [.library(name: "MailCore2", targets: ["MailCore2"])],
    targets: [.binaryTarget(name: "MailCore2", path: "bin/MailCore2.xcframework.zip")]
)
