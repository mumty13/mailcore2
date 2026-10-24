#!/bin/bash
set -euo pipefail

WORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEPLOYMENT_TARGET="15.0"

build_dependency() {
    local name="$1"
    local repository="$2"
    local revision="$3"
    local project="$4"
    local scheme="$5"
    local library="$6"
    local output_name="$7"
    local source_dir="$WORK_DIR/sources/$name"
    local output_dir="$WORK_DIR/output/$output_name"
    local build_dir="$output_dir/build"
    local products_dir="$build_dir/Build/Products/Release-iphonesimulator"

    if [[ ! -d "$source_dir/.git" ]]; then
        git clone "$repository" "$source_dir"
        git -C "$source_dir" checkout --detach "$revision"
    fi
    if [[ "$(git -C "$source_dir" rev-parse HEAD)" != "$revision" ]]; then
        echo "Unexpected source revision in $source_dir" >&2
        exit 1
    fi
    if [[ -n "$(git -C "$source_dir" status --porcelain --untracked-files=no)" ]]; then
        echo "Tracked source changes found in $source_dir" >&2
        exit 1
    fi

    mkdir -p "$output_dir" "$WORK_DIR/logs"
    xcodebuild \
        -project "$source_dir/build-mac/$project" \
        -scheme "$scheme" \
        -configuration Release \
        -sdk iphonesimulator \
        -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath "$build_dir" \
        ARCHS=arm64 \
        ONLY_ACTIVE_ARCH=YES \
        IPHONEOS_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
        ENABLE_BITCODE=NO \
        CODE_SIGNING_ALLOWED=NO \
        build > "$WORK_DIR/logs/$output_name-build.log" 2>&1

    cp "$products_dir/$library" "$output_dir/$library"
    mkdir -p "$output_dir/include"
    cp -R "$products_dir/include/." "$output_dir/include/"
    git -C "$source_dir" rev-parse HEAD > "$output_dir/source-revision.txt"
    xcrun lipo -archs "$output_dir/$library" > "$output_dir/architectures.txt"
    xcrun otool -l "$output_dir/$library" > "$output_dir/load-commands.txt"
    shasum -a 256 "$output_dir/$library" > "$output_dir/sha256.txt"
    echo "Built $library for arm64 iOS Simulator"
}

build_dependency \
    ctemplate \
    https://github.com/dinhviethoa/ctemplate.git \
    2c6ff9ae7d0ae1b973e57dd19859b95282776194 \
    ctemplate.xcodeproj \
    ctemplate-ios \
    libctemplate-ios.a \
    ctemplate

build_dependency \
    tidy-html5 \
    https://github.com/dinhviethoa/tidy-html5.git \
    71aaa8669c664447743bba73e07d70c291548dca \
    Tidy.xcodeproj \
    tidy \
    libtidy.a \
    tidy
