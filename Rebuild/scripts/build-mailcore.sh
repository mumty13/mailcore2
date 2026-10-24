#!/bin/bash
set -eo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/sources/mailcore2"
REVISION="5fb0f93010ff7af426e72e9066db8cb19b8154be"

if [[ "$(git -C "$SOURCE" rev-parse HEAD)" != "$REVISION" ]]; then
    echo "MailCore source must be at $REVISION" >&2
    exit 1
fi

mkdir -p "$SOURCE/Externals" "$ROOT/logs" "$ROOT/output/mailcore/build"
for pair in "ctemplate-ios:ctemplate:libctemplate-ios.a" "tidy-html5-ios:tidy:libtidy.a" "libetpan-ios:libetpan:libetpan-ios.a" "libsasl-ios:sasl:libsasl2.a"; do
    dependency="${pair%%:*}"
    remainder="${pair#*:}"
    artifact="${remainder%%:*}"
    library="${remainder#*:}"
    if [[ ! -d "$ROOT/output/$artifact/include" ]]; then
        echo "Missing built dependency: $artifact" >&2
        exit 1
    fi
    input="$ROOT/output/$artifact/$library"
    if [[ ! -f "$input" ]]; then
        input="$ROOT/output/$artifact/lib/$library"
    fi
    test -f "$input"
    mkdir -p "$SOURCE/Externals/$dependency/lib"
    cp "$input" "$SOURCE/Externals/$dependency/lib/$library"
    ln -sfn "$ROOT/output/$artifact/include" "$SOURCE/Externals/$dependency/include"
done

# The original build phase stages Externals after checking these versions.
# All three dependencies above were rebuilt locally instead of downloaded.
cp "$SOURCE/scripts/deps-versions.plist" "$SOURCE/scripts/installed-deps-versions.plist"

xcodebuild \
    -project "$SOURCE/build-mac/mailcore2.xcodeproj" \
    -target "mailcore ios" \
    -configuration Release \
    -sdk iphonesimulator \
    SYMROOT="$ROOT/output/mailcore/build/products" \
    OBJROOT="$ROOT/output/mailcore/build/intermediates" \
    ARCHS=arm64 VALID_ARCHS=arm64 EXCLUDED_ARCHS= \
    ONLY_ACTIVE_ARCH=YES \
    IPHONEOS_DEPLOYMENT_TARGET=15.0 \
    CODE_SIGNING_ALLOWED=NO ENABLE_BITCODE=NO \
    build > "$ROOT/logs/mailcore-build.log" 2>&1

FRAMEWORK="$ROOT/output/mailcore/build/products/Release-iphonesimulator/MailCore.framework"
test -f "$FRAMEWORK/MailCore"
echo "Built: $FRAMEWORK"
