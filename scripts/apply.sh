#!/usr/bin/env bash
# Apply Track A patches to a Dify 1.17.0 checkout.
#
#   usage: bash scripts/apply.sh /path/to/dify
#
# The patches were produced with `git diff HEAD` against Dify 1.17.0
# (tag 1.17.0, commit 09a855dcef). They apply cleanly to that revision only.
set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "usage: bash scripts/apply.sh /path/to/dify" >&2
  exit 2
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -d "$TARGET/.git" ]; then
  echo "error: $TARGET is not a git checkout" >&2
  exit 2
fi

cd "$TARGET"

echo "==> checking patches against $TARGET"
git apply --check "$HERE/patches/01-track-a.patch"
git apply --check "$HERE/patches/02-weaviate-delete-fix.patch"

echo "==> applying"
git apply "$HERE/patches/01-track-a.patch"
git apply "$HERE/patches/02-weaviate-delete-fix.patch"

echo "==> done. changed files:"
git status --porcelain=v1

cat <<'NOTE'

Next steps:
  1. Append env/transcribe.env.snippet to docker/.env (that file is git-ignored).
  2. docker compose build api worker
  3. docker compose up -d api worker
  4. In the console, locate the vision model provider configured by
     TRANSCRIBE_MODEL_PROVIDER and make sure an API key is bound to it.

Rollback: bash scripts/rollback.sh /path/to/dify
NOTE
