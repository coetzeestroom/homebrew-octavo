#!/usr/bin/env bash
# Demonstrate size reduction of a Pake bottle by stripping non-runtime
# files from node_modules. Run AFTER extracting a bottle tarball.
#
# Usage: ./scripts/reduce-bottle-size.sh <extracted-bottle-dir>
set -euo pipefail

DIR="${1:?usage: ${0} <extracted-bottle-dir>}"
cd "${DIR}"

before=$(du -sb . | cut -f1)
echo "Before: $(du -sh . | cut -f1)"

# Strip TypeScript declarations, source maps, tests, docs from node_modules
find . -path '*/node_modules/*' \( \
  -name '*.d.ts' -o -name '*.d.ts.map' -o -name '*.map' \
  -o -name 'README.md' -o -name 'CHANGELOG.md' -o -name 'LICENSE*' \
  -o -name '*.test.js' -o -name '*.spec.js' \
\) -type f -delete 2>/dev/null || true

# Remove empty directories left behind
find . -path '*/node_modules/*' -type d -empty -delete 2>/dev/null || true

after=$(du -sb . | cut -f1)
echo "After:  $(du -sh . | cut -f1)"
echo "Saved:  $(( (before - after) / 1024 / 1024 )) MB"
