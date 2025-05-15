#!/bin/sh

pushd "`dirname "$0"`" > /dev/null
scriptpath="`pwd`"
popd > /dev/null

. "$scriptpath/include.sh/build-dep.sh"

url="https://github.com/mumty13/libetpan.git"
rev=aa9b5d1080cdf667cffc165d623bf05471ed2bae
name="libetpan-osx"
xcode_target="static libetpan"
xcode_project="libetpan.xcodeproj"
library="libetpan.a"
embedded_deps=""

build_git_osx
