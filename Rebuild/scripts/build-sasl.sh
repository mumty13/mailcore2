#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SOURCE_DIR="$ROOT/sources/sasl"
ARCHIVE="$ROOT/sources/sasl-download/cyrus-sasl-2.1.26.tar.gz"
PREFIX="$ROOT/output/sasl"
SOURCE_URL="https://github.com/cyrusimap/cyrus-sasl/releases/download/cyrus-sasl-2.1.26/cyrus-sasl-2.1.26.tar.gz"
SOURCE_SHA256="8fbc5136512b59bb793657f36fadda6359cae3b08f01fd16b3d406f1345b7bc3"

mkdir -p "$(dirname "$ARCHIVE")" "$ROOT/logs" "$PREFIX"
if [ ! -f "$ARCHIVE" ]; then
    curl --fail --location --retry 2 "$SOURCE_URL" -o "$ARCHIVE"
fi
ACTUAL_SHA256=$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')
if [ "$ACTUAL_SHA256" != "$SOURCE_SHA256" ]; then
    echo "Cyrus SASL source checksum mismatch" >&2
    exit 1
fi

rm -rf "$SOURCE_DIR"
mkdir -p "$SOURCE_DIR"
tar -xzf "$ARCHIVE" -C "$SOURCE_DIR" --strip-components=1
patch -d "$SOURCE_DIR" -p1 < "$ROOT/patches/sasl-arm64-simulator.patch"

unset SDKROOT IPHONEOS_DEPLOYMENT_TARGET
xcrun --sdk macosx clang "$SOURCE_DIR/include/makemd5.c" -o "$SOURCE_DIR/include/makemd5-host"
SIMULATOR_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
SIMULATOR_CLANG=$(xcrun --sdk iphonesimulator --find clang)
TARGET_FLAGS="-target arm64-apple-ios15.0-simulator -isysroot $SIMULATOR_SDK"

cd "$SOURCE_DIR"
CC="$SIMULATOR_CLANG" \
CPPFLAGS="$TARGET_FLAGS" \
CFLAGS="$TARGET_FLAGS -Os -Wno-error=implicit-function-declaration -Wno-error=incompatible-function-pointer-types" \
LDFLAGS="$TARGET_FLAGS" \
./configure \
    --build=arm64-apple-darwin \
    --host=aarch64-apple-darwin \
    --prefix="$PREFIX" \
    --enable-shared=no \
    --enable-static=yes \
    --without-pam \
    --without-openssl \
    --enable-otp=no \
    --enable-digest=no \
    --with-des=no \
    --enable-login \
    --disable-macos-framework \
    --disable-saslauthd > "$ROOT/logs/sasl-configure.log" 2>&1

make -j 8 > "$ROOT/logs/sasl-build.log" 2>&1
make -C lib install > "$ROOT/logs/sasl-install.log" 2>&1
make -C include install >> "$ROOT/logs/sasl-install.log" 2>&1
make -C plugins install >> "$ROOT/logs/sasl-install.log" 2>&1
cp COPYING "$PREFIX/LICENSE"
xcrun lipo -archs "$PREFIX/lib/libsasl2.a"
python3 - "$PREFIX" "$SOURCE_URL" "$SOURCE_SHA256" <<'PY'
import json
from pathlib import Path
import re
import subprocess
import sys

prefix = Path(sys.argv[1])
library = prefix / "lib/libsasl2.a"
architecture = subprocess.check_output(["xcrun", "lipo", "-archs", str(library)], text=True).strip()
metadata = subprocess.check_output(["xcrun", "otool", "-l", str(library)], text=True)
platforms = re.findall(r"^\s*platform\s+(\S+)", metadata, re.M)
if architecture != "arm64" or not platforms or any(platform != "7" for platform in platforms):
    raise SystemExit("Cyrus SASL artifact must contain only arm64 iOS Simulator objects")
record = {
    "dependency": "Cyrus SASL",
    "version": "2.1.26",
    "source_url": sys.argv[2],
    "source_sha256": sys.argv[3],
    "historical_release_md5": "a7f4e5e559a0e37b3ffc438c9456e425",
    "target": "arm64-apple-ios15.0-simulator",
    "sdk": subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"], text=True).strip(),
    "static_plugins": ["sasldb", "cram-md5", "plain", "anonymous", "login"],
    "patches": [
        "Existing libetpan client FQDN fallback patch, carried without further changes.",
        "Recognize arm64/aarch64 CPU names in legacy config.sub.",
        "Run a separately compiled macOS makemd5 generator while cross-compiling.",
        "Refresh archive symbol index after adding static plugins.",
    ],
    "legacy_c_compatibility_flags": ["-Wno-error=implicit-function-declaration", "-Wno-error=incompatible-function-pointer-types"],
    "verification": {"architectures": [architecture], "object_count": len(platforms), "macho_platform": "IOSSIMULATOR (7)"},
}
(prefix / "provenance.json").write_text(json.dumps(record, indent=2) + "\n")
print("Verified %d arm64 iOS Simulator objects" % len(platforms))
PY
echo "Cyrus SASL arm64 simulator library ready: $PREFIX/lib/libsasl2.a"
