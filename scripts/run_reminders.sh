#!/usr/bin/env bash
# Reminder dispatch tick, intended for host cron or Cloud Scheduler.
#
# ReminderService owns all the scheduling logic (24h-before interview reminders,
# 15-minute follow-up windows, day-after overdue notices) and dedupes via
# notification dedupe keys, so this only needs to run often enough to land inside
# those windows. Every 5 minutes is the smallest interval that reliably catches
# the 15-minute follow-up window.
#
# Safe to run concurrently with the API: reminders are deduped by key, so a
# duplicate tick creates nothing.
set -euo pipefail

cd "$(dirname "$0")/../backend"

if [ -x .venv/bin/python ]; then
  PYTHON=.venv/bin/python
else
  PYTHON=python3
fi

exec "$PYTHON" -m app.workers.notification_worker
