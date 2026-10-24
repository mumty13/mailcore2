#!/bin/bash
set -eo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORIGINAL="$ROOT/original/MailCore2.xcframework"
NATIVE="$ROOT/output/mailcore/build/products/Release-iphonesimulator/MailCore.framework"
COMBINED="$ROOT/output/combined-simulator/MailCore.framework"
PACKAGE="$ROOT/output/package"
OUTPUT="$ROOT/output/MailCore2.xcframework"
EXPECTED_DEVICE_SHA="f1d17949bc6445314b1d7a8cffc7d1d8a848077387f48c6b31a88f5e4d1f725f"

test -f "$NATIVE/MailCore"
actual_device_sha="$(shasum -a 256 "$ORIGINAL/ios-arm64_armv7/MailCore.framework/MailCore" | awk '{print $1}')"
test "$actual_device_sha" = "$EXPECTED_DEVICE_SHA"
if [[ -e "$OUTPUT" ]]; then
    echo "Output already exists: $OUTPUT" >&2
    exit 1
fi
mkdir -p "$(dirname "$COMBINED")" "$PACKAGE" "$ROOT/logs"
ditto "$NATIVE" "$COMBINED"
xcrun lipo -create \
    "$NATIVE/MailCore" \
    "$ORIGINAL/ios-x86_64-simulator/MailCore.framework/MailCore" \
    -output "$COMBINED/MailCore"
codesign --force --sign - --timestamp=none "$COMBINED"

xcodebuild -create-xcframework \
    -framework "$ORIGINAL/ios-arm64_armv7/MailCore.framework" \
    -framework "$COMBINED" \
    -framework "$ORIGINAL/macos-x86_64/MailCore.framework" \
    -output "$OUTPUT" > "$ROOT/logs/package.log" 2>&1

cmp "$ORIGINAL/ios-arm64_armv7/MailCore.framework/MailCore" \
    "$OUTPUT/ios-arm64_armv7/MailCore.framework/MailCore"
diff -rq "$ORIGINAL/ios-arm64_armv7/MailCore.framework" \
    "$OUTPUT/ios-arm64_armv7/MailCore.framework"
diff -rq "$ORIGINAL/macos-x86_64/MailCore.framework" \
    "$OUTPUT/macos-x86_64/MailCore.framework"

ditto "$OUTPUT" "$PACKAGE/MailCore2.xcframework"
cat > "$PACKAGE/Package.swift" <<'SWIFT'
// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "MailCore2",
    platforms: [.iOS("15.0"), .macOS(.v10_10)],
    products: [.library(name: "MailCore2", targets: ["MailCore2"])],
    targets: [.binaryTarget(name: "MailCore2", path: "MailCore2.xcframework")]
)
SWIFT
echo "Packaged: $OUTPUT"
echo "Local package: $PACKAGE"
