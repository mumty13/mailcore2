#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
for script in prepare-mailcore build-ctemplate-tidy build-libetpan-sasl build-mailcore package-framework; do
    bash "$ROOT/scripts/$script.sh"
done
