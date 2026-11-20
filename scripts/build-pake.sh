#!/usr/bin/env bash
# Build and test a Pake desktop formula from source, locally.
#
# Usage: ./scripts/build-pake.sh <formula-name>
#   e.g. ./scripts/build-pake.sh deepseek-harness-desktop
set -euo pipefail

FORMULA="${1:?usage: $0 <formula-name>}"
TAP="coetzeestroom/octavo"

echo "==> Tapping (if needed)"
brew tap "$TAP" 2>/dev/null || true

echo "==> Uninstalling any existing build"
brew uninstall --force "$TAP/$FORMULA" 2>/dev/null || true

echo "==> Installing from source"
HOMEBREW_NO_AUTO_UPDATE=1 brew install --build-from-source "$TAP/$FORMULA"

echo "==> Running formula tests"
brew test "$TAP/$FORMULA"
