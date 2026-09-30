#!/usr/bin/env bash
# Revert Track A patches from a Dify checkout (reverse apply).
#
#   usage: bash scripts/rollback.sh /path/to/dify [--hard]
#
# Default mode reverse-applies the two patches, which keeps any unrelated
# local edits you made. --hard additionally deletes the two new files and
# discards every tracked change, returning to a clean HEAD.
set -euo pipefail

TARGET="${1:-}"
MODE="${2:-}"
if [ -z "$TARGET" ]; then
  echo "usage: bash scripts/rollback.sh /path/to/dify [--hard]" >&2
  exit 2
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TARGET"

echo "==> reverse-applying patches"
git apply -R "$HERE/patches/02-weaviate-delete-fix.patch"
git apply -R "$HERE/patches/01-track-a.patch"

if [ "$MODE" = "--hard" ]; then
  echo "==> hard mode: resetting to HEAD"
  git reset --hard HEAD
  git clean -fd api/core/rag/extractor api/core/rag/splitter
fi

echo "==> done. remaining changes:"
git status --porcelain=v1
