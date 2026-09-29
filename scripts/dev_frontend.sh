#!/usr/bin/env bash
# Start Flutter app in development mode.
set -euo pipefail
cd "$(dirname "$0")/../frontend/job_tracker"
flutter run
