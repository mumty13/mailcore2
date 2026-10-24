#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REVISION="5fb0f93010ff7af426e72e9066db8cb19b8154be"
SOURCE="$ROOT/sources/mailcore2"
ARCHIVE="$ROOT/sources/MailCore2-2020-09-24.xcframework.zip"
ARCHIVE_URL="https://raw.githubusercontent.com/mattmaddux/mailcore2/e8831a81b2ff21fc2b3eb8e8ab39bd3054408001/bin/MailCore2-2020-09-24.xcframework.zip"
ARCHIVE_SHA="c3479968c758094165fb0b4de5ca7dd9f8aafac423388c51406c447f69a1b853"

mkdir -p "$ROOT/sources" "$ROOT/original" "$ROOT/logs"
if [[ ! -d "$SOURCE/.git" ]]; then
    git clone https://github.com/MailCore/mailcore2.git "$SOURCE"
    git -C "$SOURCE" checkout --detach "$REVISION"
fi
test "$(git -C "$SOURCE" rev-parse HEAD)" = "$REVISION"
test -z "$(git -C "$SOURCE" status --porcelain --untracked-files=no)"

if [[ ! -d "$ROOT/original/MailCore2.xcframework" ]]; then
    if [[ ! -f "$ARCHIVE" ]]; then
        curl --fail --location --retry 2 "$ARCHIVE_URL" -o "$ARCHIVE"
    fi
    test "$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')" = "$ARCHIVE_SHA"
    ditto -x -k "$ARCHIVE" "$ROOT/original"
fi
test "$(shasum -a 256 "$ROOT/original/MailCore2.xcframework/ios-arm64_armv7/MailCore.framework/MailCore" | awk '{print $1}')" = \
    "f1d17949bc6445314b1d7a8cffc7d1d8a848077387f48c6b31a88f5e4d1f725f"
