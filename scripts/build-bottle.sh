#!/usr/bin/env bash
# Build a Homebrew bottle for a Pake desktop formula, locally.
# This is the same script the GitHub Actions runner uses.
#
# Usage: ./scripts/build-bottle.sh <formula-name>
#   e.g. ./scripts/build-bottle.sh deepseek-harness-desktop
set -euo pipefail

FORMULA="${1:?usage: $0 <formula-name>}"
TAP="coetzeestroom/octavo"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Tapping (if needed)"
brew tap "${TAP}" 2>/dev/null || true

echo "==> Uninstalling any existing build"
brew uninstall --force "${TAP}/${FORMULA}" 2>/dev/null || true

echo "==> Installing with --build-bottle"
HOMEBREW_NO_AUTO_UPDATE=1 brew install --build-bottle "${TAP}/${FORMULA}"

echo "==> Building bottle"
cd "$ROOT"
brew bottle --json --no-rebuild "${TAP}/${FORMULA}"

echo "==> Bottle artifacts"
ls -lh *.bottle.* 2>/dev/null || true
du -sh ./*.bottle.* 2>/dev/null || true
