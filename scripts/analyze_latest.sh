#!/usr/bin/env bash
set -euo pipefail

# Analyze the latest trackpad + canvas session.
# Assumes:
#   - Python virtualenv is already activated
#   - data/touch_lifetimes_*.csv and data/finger_counts_*.csv exist
#   - data/canvas_log.json exists (or pass a different path via --canvas-log)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR%/scripts}"

cd "$PROJECT_ROOT"

python -m src.run_session_analysis "$@"
