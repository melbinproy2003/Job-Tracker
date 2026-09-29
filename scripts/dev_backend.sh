#!/usr/bin/env bash
# Start FastAPI in development mode.
set -euo pipefail
cd "$(dirname "$0")/../backend"
if [[ -f .venv/bin/activate ]]; then
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi
uvicorn app.main:app --reload --host "${API_HOST:-0.0.0.0}" --port "${API_PORT:-8000}"
