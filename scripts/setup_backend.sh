#!/usr/bin/env bash
# Create venv and install backend dependencies.
set -euo pipefail
cd "$(dirname "$0")/../backend"
python3 -m venv .venv
# shellcheck disable=SC1091
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
cp -n .env.example .env || true
echo "Backend setup complete. Edit backend/.env with your secrets."
