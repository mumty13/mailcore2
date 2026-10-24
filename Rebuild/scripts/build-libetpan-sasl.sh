#!/bin/bash
set -euo pipefail

WORK_DIR=$(cd "$(dirname "$0")/.." && pwd)
SOURCE_DIR="$WORK_DIR/sources/libetpan"
OUTPUT_DIR="$WORK_DIR/output/libetpan"
BUILD_DIR="$OUTPUT_DIR/build"
SOURCE_REVISION=5164ba2ebd3c7cbc7a9230aad32bdf8e24e207de
REFERENCE_ARCHIVE="$WORK_DIR/sources/libetpan-ios-21.zip"
REFERENCE_URL=https://d.etpan.org/mailcore2-deps/libetpan-ios/libetpan-ios-21.zip
REFERENCE_SHA256=68366045653b8c1db5aaf77b9ae8dda459e779ec41b32929266792e13b4b8655

mkdir -p "$WORK_DIR/logs" "$OUTPUT_DIR"
if [ ! -d "$SOURCE_DIR/.git" ]; then
    git clone https://github.com/dinhviethoa/libetpan.git "$SOURCE_DIR"
    git -C "$SOURCE_DIR" checkout --detach "$SOURCE_REVISION"
fi
if [ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" != "$SOURCE_REVISION" ]; then
    echo "Unexpected libetpan source revision" >&2
    exit 1
fi
if [ ! -f "$REFERENCE_ARCHIVE" ]; then
    curl --fail --location --retry 2 "$REFERENCE_URL" -o "$REFERENCE_ARCHIVE"
fi
if [ "$(shasum -a 256 "$REFERENCE_ARCHIVE" | awk '{print $1}')" != "$REFERENCE_SHA256" ]; then
    echo "Original libetpan dependency archive checksum mismatch" >&2
    exit 1
fi
if [ "$(unzip -p "$REFERENCE_ARCHIVE" libetpan-ios-21/git-rev)" != "$SOURCE_REVISION" ]; then
    echo "Original libetpan dependency source revision mismatch" >&2
    exit 1
fi

"$WORK_DIR/scripts/build-sasl.sh"

cd "$SOURCE_DIR"
for PATCH_NAME in libetpan-clang-forward-declaration.patch libetpan-ios-system-availability.patch; do
    if git apply --check "$WORK_DIR/patches/$PATCH_NAME" 2>/dev/null; then
        git apply --whitespace=nowarn "$WORK_DIR/patches/$PATCH_NAME"
    else
        git apply --reverse --check "$WORK_DIR/patches/$PATCH_NAME"
    fi
done
tar xzf build-mac/autogen-result.tar.gz
# The bundled autotools archive contains older copies of these tracked inputs.
for SOURCE_FILE in build-windows/libetpan_version.h libetpan-config.h.in src/main/libetpan_version.h.in; do
    git show "HEAD:$SOURCE_FILE" > "$SOURCE_FILE"
done
./configure --with-expat=no --with-curl=no --enable-debug > "$WORK_DIR/logs/libetpan-configure.log" 2>&1
make stamp-prepare-target libetpan-config.h > "$WORK_DIR/logs/libetpan-prepare.log" 2>&1
md5 build-mac/autogen-result.tar.gz > build-mac/autogen-result.md5
if [ ! -e build-mac/libsasl-ios ]; then
    ln -s ../../../output/sasl build-mac/libsasl-ios
fi

xcodebuild -project build-mac/libetpan.xcodeproj \
    -scheme 'libetpan ios' -configuration Release \
    -destination 'generic/platform=iOS Simulator' -sdk iphonesimulator \
    -derivedDataPath "$BUILD_DIR" \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES EXCLUDED_ARCHS= \
    IPHONEOS_DEPLOYMENT_TARGET=15.0 ENABLE_BITCODE=NO \
    CODE_SIGNING_ALLOWED=NO ENABLE_USER_SCRIPT_SANDBOXING=NO \
    build > "$WORK_DIR/logs/libetpan-build.log" 2>&1

mkdir -p "$OUTPUT_DIR/lib" "$OUTPUT_DIR/include"
cp "$BUILD_DIR/Build/Products/Release-iphonesimulator/libetpan-ios.a" "$OUTPUT_DIR/lib/"
rsync -aL "$BUILD_DIR/Build/Products/Release-iphonesimulator/include/libetpan/" "$OUTPUT_DIR/include/libetpan/"
printf '%s\n' "$SOURCE_REVISION" > "$OUTPUT_DIR/source-revision.txt"
xcrun lipo -archs "$OUTPUT_DIR/lib/libetpan-ios.a"
cp COPYRIGHT "$OUTPUT_DIR/LICENSE"
python3 - "$OUTPUT_DIR" "$REFERENCE_ARCHIVE" "$SOURCE_REVISION" <<'PY'
from pathlib import Path
from zipfile import ZipFile
import hashlib
import json
import re
import subprocess
import sys

output = Path(sys.argv[1])
reference = Path(sys.argv[2])
library = output / 'lib/libetpan-ios.a'
architectures = subprocess.check_output(['xcrun', 'lipo', '-archs', str(library)], text=True).strip()
metadata = subprocess.check_output(['xcrun', 'otool', '-l', str(library)], text=True)
platforms = re.findall(r'^\s*platform\s+(\d+)', metadata, re.M)
if architectures != 'arm64' or not platforms or set(platforms) != {'7'}:
    raise SystemExit('libetpan must contain only arm64 iOS Simulator objects')
with ZipFile(reference) as archive:
    original_revision = archive.read('libetpan-ios-21/git-rev').decode().strip()
    original_library = archive.read('libetpan-ios-21/libetpan-ios/lib/libetpan-ios.a')
    original_library_sha256 = hashlib.sha256(original_library).hexdigest()
    (output / 'original-library.a').write_bytes(original_library)
    original_sasl = archive.read('libetpan-ios-21/libsasl-ios/lib/libsasl2.a')
    (output.parent / 'sasl/original-library.a').write_bytes(original_sasl)

def symbols(path):
    result = subprocess.check_output(['nm', '-arch', 'arm64', '-gU', str(path)], text=True, stderr=subprocess.DEVNULL)
    return {line.split()[-1] for line in result.splitlines() if len(line.split()) >= 3 and not line.endswith(':')}

symbol_checks = {}
for dependency, original, rebuilt in [
    ('libetpan', output / 'original-library.a', library),
    ('sasl', output.parent / 'sasl/original-library.a', output.parent / 'sasl/lib/libsasl2.a'),
]:
    original_symbols, rebuilt_symbols = symbols(original), symbols(rebuilt)
    missing = sorted(original_symbols - rebuilt_symbols)
    added = sorted(rebuilt_symbols - original_symbols)
    if missing:
        raise SystemExit('%s replacement is missing exported symbols: %s' % (dependency, missing))
    symbol_checks[dependency] = {'original_count': len(original_symbols), 'rebuilt_count': len(rebuilt_symbols), 'missing': missing, 'added': added}
record = {
    'source_repository': 'https://github.com/dinhviethoa/libetpan.git',
    'source_revision': sys.argv[3],
    'original_dependency_archive': {
        'url': 'https://d.etpan.org/mailcore2-deps/libetpan-ios/libetpan-ios-21.zip',
        'sha256': hashlib.sha256(reference.read_bytes()).hexdigest(),
        'recorded_source_revision': original_revision,
        'original_library_sha256': original_library_sha256,
    },
    'target': 'arm64-apple-ios15.0-simulator',
    'verification': {'architecture': architectures, 'macho_platform': 'IOSSIMULATOR (7)', 'object_count': len(platforms)},
    'exported_symbol_compatibility': symbol_checks,
    'patches': [
        {'file': 'libetpan-clang-forward-declaration.patch', 'purpose': 'Declare the parser context at file scope for current Clang.'},
        {'file': 'libetpan-ios-system-availability.patch', 'upstream_commit': '0413d6dedbce7870bb530709af8bdc5c7eb39de5', 'purpose': 'Apply upstream iOS guards for unavailable system() calls in the external-command privacy helpers.'},
    ],
}
(output / 'provenance.json').write_text(json.dumps(record, indent=2) + '\n')
print('Verified %d arm64 iOS Simulator libetpan objects' % len(platforms))
PY
