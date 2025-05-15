#!/bin/sh

pushd "$(dirname "$0")" > /dev/null
scriptpath="$(pwd)"
popd > /dev/null

. "$scriptpath/include.sh/build-dep.sh"

externals_dir="$scriptpath/../Externals"

mkdir -p "$externals_dir"

prebuilt_deps="ctemplate-ios tidy-html5-ios"
for dep in $prebuilt_deps; do
  target_dir="$externals_dir/$dep"
  if [ ! -d "$target_dir" ]; then
    echo "Building or fetching prebuilt: $dep"
    name="$dep"
    get_prebuilt_dep
  else
    echo "Skipping $dep (already exists in externals)"
  fi
done

# libetpan settings
url="https://github.com/mumty13/libetpan.git"
rev=868845d9f35576fcc07543010201abf6d7d6d9ab
name="libetpan-ios"
xcode_target="libetpan ios"
xcode_project="libetpan.xcodeproj"
library="libetpan-ios.a"
embedded_deps="libsasl-ios"
build_for_external=1

dep_dir="$externals_dir/libetpan-ios"
if [ ! -d "$dep_dir" ]; then
  echo "Cloning and building libetpan-ios"
  build_git_ios
else
  echo "Skipping libetpan-ios (already exists in externals)"
fi

all_deps="ctemplate-ios tidy-html5-ios libsasl-ios libetpan-ios"

if [ -n "$CONFIGURATION_BUILD_DIR" ]; then
  mkdir -p "$CONFIGURATION_BUILD_DIR"
  cd "$externals_dir"
  for dep in $all_deps; do
    if [ -d "$dep" ]; then
      echo "Packaging $dep"
      if [ -d "$dep/lib" ]; then
        rsync -a "$dep/lib/" "$CONFIGURATION_BUILD_DIR/"
      fi
      if [ -d "$dep/include" ]; then
        rsync -a "$dep/include/" "$CONFIGURATION_BUILD_DIR/include/"
      fi
    else
      echo "Warning: $dep not found in externals, skipping packaging"
    fi
  done
fi
