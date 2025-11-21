#!/bin/bash
#
# Automated trackpad session analysis runner
#
# Usage:
#   ./run_analysis.sh [mode]
#
# Modes:
#   batch   - Process all sessions once (default)
#   watch   - Watch for new sessions continuously
#   latest  - Process only the most recent session
#

set -e

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VENV_DIR="$SCRIPT_DIR/venv"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/analysis_$(date +%Y%m%d_%H%M%S).log"

# Create log directory
mkdir -p "$LOG_DIR"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "==========================="
log "Trackpad Analysis Runner"
log "==========================="

# Check if virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    log "Virtual environment not found. Creating..."
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    log "Installing dependencies..."
    pip install -r "$SCRIPT_DIR/requirements.txt" >> "$LOG_FILE" 2>&1
    log "Setup complete!"
else
    source "$VENV_DIR/bin/activate"
fi

# Determine mode
MODE="${1:-batch}"

log "Mode: $MODE"

# Run appropriate script
case "$MODE" in
    batch)
        log "Running batch processing..."
        cd "$SCRIPT_DIR"
        python process_all_sessions.py 2>&1 | tee -a "$LOG_FILE"
        ;;
    watch)
        log "Starting file watcher..."
        cd "$SCRIPT_DIR"
        python watch_and_process.py 2>&1 | tee -a "$LOG_FILE"
        ;;
    latest)
        log "Processing latest session only..."
        cd "$SCRIPT_DIR"
        python -c "
import data_loader
import metrics
import visualize
from pathlib import Path
import json

session_dir = Path.home() / 'Library/Containers/savant.savantlab/Data/Documents/savantlab-trackpad-sessions'
sessions = data_loader.load_sessions_from_directory(session_dir)

if not sessions:
    print('No sessions found')
    exit(1)

# Get latest session
session = sessions[-1]
print(f'Processing latest: {session.session_id}')

# Compute and save
output = Path('output') / session.session_id
output.mkdir(parents=True, exist_ok=True)

metrics_df = metrics.compute_all_metrics(session, 'pointer')
if not metrics_df.empty:
    metrics_df.to_csv(output / f'{session.session_id}_metrics.csv', index=False)
    stats = metrics.session_statistics(metrics_df)
    with open(output / f'{session.session_id}_stats.json', 'w') as f:
        json.dump(stats, f, indent=2, default=str)
    visualize.save_plots(session, output, metrics_df)
    print('Done!')
else:
    print('No pointer events found')
" 2>&1 | tee -a "$LOG_FILE"
        ;;
    *)
        log "ERROR: Unknown mode '$MODE'"
        log "Valid modes: batch, watch, latest"
        exit 1
        ;;
esac

log "Complete! Log saved to: $LOG_FILE"
