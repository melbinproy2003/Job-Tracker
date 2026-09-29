#!/usr/bin/env bash
# Vercel Ignored Build Step for the Job Tracker FastAPI backend.
#
# Exit codes (Vercel convention):
#   0 → skip this deployment
#   1 → proceed with build/deploy
#
# Assumes Vercel Project Root Directory = `backend` so this script's cwd is
# `backend/` and pathspec `.` covers only FastAPI sources (not Flutter).
#
# Uses VERCEL_GIT_PREVIOUS_SHA → VERCEL_GIT_COMMIT_SHA so multi-commit pushes
# and merges are evaluated as a range, not a single parent (HEAD^).
set -euo pipefail

PREV="${VERCEL_GIT_PREVIOUS_SHA:-}"
CURR="${VERCEL_GIT_COMMIT_SHA:-}"

echo "Ignored Build Step: prev=${PREV:-<none>} curr=${CURR:-<none>} cwd=$(pwd)"

# First deployment, manual redeploy without SHAs, or missing git metadata:
# always build so production is never left empty by accident.
if [[ -z "$PREV" || -z "$CURR" ]]; then
  echo "Missing previous/current commit SHA — proceeding with build."
  exit 1
fi

if [[ "$PREV" == "$CURR" ]]; then
  echo "Previous SHA equals current (redeploy) — proceeding with build."
  exit 1
fi

# Ensure both commits are available (shallow clones can omit PREV).
if ! git cat-file -e "${PREV}^{commit}" 2>/dev/null; then
  echo "Previous SHA not in clone — fetching..."
  git fetch --depth=50 origin "$PREV" 2>/dev/null || true
fi

if ! git cat-file -e "${PREV}^{commit}" 2>/dev/null; then
  echo "Still cannot resolve previous SHA — proceeding with build."
  exit 1
fi

# `.` = everything under Root Directory (backend/). Flutter/docs/root CI files
# outside this directory do not trigger a deploy.
if git diff --quiet "$PREV" "$CURR" -- .; then
  echo "No changes under backend/ between commits — skipping deployment."
  exit 0
fi

echo "Backend changes detected — proceeding with build."
exit 1
