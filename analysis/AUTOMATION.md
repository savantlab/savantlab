# Automation Guide

Multiple ways to automate trackpad data analysis.

## Option 1: Manual Batch Processing

Process all sessions at once when you want.

```bash
cd analysis
python process_all_sessions.py
```

**Output:**
- `output/` directory with subdirectories for each session
- Each session gets: metrics CSV, statistics JSON, overview plots
- Summary report: `output/summary_all_sessions.csv`

## Option 2: Real-Time File Watcher

Automatically process new sessions as soon as they're saved.

```bash
cd analysis
python watch_and_process.py
```

**Features:**
- Monitors session directory every 2 seconds
- Processes new CSV files immediately
- Runs continuously until you press Ctrl+C
- Skips files that already exist

**Use case:** Run this in the background while using the trackpad app.

## Option 3: Shell Script Runner

Convenient wrapper with multiple modes.

```bash
cd analysis
./run_analysis.sh [mode]
```

**Modes:**
- `batch` - Process all sessions once (default)
- `watch` - Run file watcher continuously  
- `latest` - Process only the most recent session

**Features:**
- Auto-creates virtual environment if needed
- Installs dependencies automatically
- Logs all output to `logs/` directory
- Timestamps every run

**Examples:**
```bash
./run_analysis.sh              # Batch mode
./run_analysis.sh watch        # File watcher
./run_analysis.sh latest       # Just the newest
```

## Option 4: Scheduled Automation (launchd)

Run analysis automatically on a schedule (e.g., daily at 6 AM).

### Setup

1. **Install the launch agent:**
```bash
cd analysis
mkdir -p logs
cp com.savantlab.trackpad-analysis.plist ~/Library/LaunchAgents/
```

2. **Load it:**
```bash
launchctl load ~/Library/LaunchAgents/com.savantlab.trackpad-analysis.plist
```

3. **Check status:**
```bash
launchctl list | grep trackpad
```

### Configuration

Edit the plist file to change the schedule:

**Daily at specific time:**
```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key>
    <integer>6</integer>   <!-- 6 AM -->
    <key>Minute</key>
    <integer>0</integer>
</dict>
```

**Every N seconds/minutes/hours:**
```xml
<key>StartInterval</key>
<integer>3600</integer>  <!-- Every hour -->
```

**Multiple times per day:**
```xml
<key>StartCalendarInterval</key>
<array>
    <dict>
        <key>Hour</key>
        <integer>9</integer>   <!-- 9 AM -->
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <dict>
        <key>Hour</key>
        <integer>18</integer>  <!-- 6 PM -->
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</array>
```

### Managing the Service

**Stop:**
```bash
launchctl unload ~/Library/LaunchAgents/com.savantlab.trackpad-analysis.plist
```

**Restart:**
```bash
launchctl unload ~/Library/LaunchAgents/com.savantlab.trackpad-analysis.plist
launchctl load ~/Library/LaunchAgents/com.savantlab.trackpad-analysis.plist
```

**Check logs:**
```bash
tail -f ~/mouse-trackpad-science-lab/analysis/logs/launchd-out.log
tail -f ~/mouse-trackpad-science-lab/analysis/logs/launchd-err.log
```

## Option 5: Run on App Close

Process the latest session when you quit the trackpad app.

Add to your shell config (`~/.zshrc` or `~/.bashrc`):

```bash
alias trackpad-close='cd ~/mouse-trackpad-science-lab/analysis && ./run_analysis.sh latest'
```

Then run `trackpad-close` after closing the app.

## Choosing the Right Option

| Option | Use When | Pros | Cons |
|--------|----------|------|------|
| **Manual Batch** | You want control | Simple, on-demand | Manual trigger |
| **File Watcher** | Recording many sessions | Real-time, automatic | Must keep running |
| **Shell Script** | Quick runs, testing | Flexible, logged | Still manual |
| **Scheduled** | Regular processing | Hands-off, reliable | Fixed schedule |
| **On Close** | After each use | Convenient | Need to remember |

## Recommended Workflows

### Research Workflow
1. Start file watcher: `./run_analysis.sh watch`
2. Use trackpad app to record sessions
3. Analysis happens automatically
4. Review results in `output/` directory

### Daily Workflow  
1. Install launchd service (runs at 6 AM daily)
2. Use app throughout the day
3. Check results next morning
4. Or run `./run_analysis.sh batch` anytime

### Quick Test Workflow
```bash
# Record a session in the app
./run_analysis.sh latest  # Process just that one
open output/session-*/    # View results
```

## Output Structure

All automation methods create the same output:

```
output/
├── session-20251119-005312/
│   ├── session-20251119-005312_metrics.csv      # Full metrics
│   ├── session-20251119-005312_stats.json       # Summary stats
│   └── session-20251119-005312_overview.png     # Visualization
├── session-20251119-010245/
│   └── ...
└── summary_all_sessions.csv                     # Cross-session comparison
```

## Troubleshooting

**"Command not found: python"**
- Use `python3` instead or create alias

**"No module named 'pandas'"**
- Activate venv: `source venv/bin/activate`
- Or run shell script which handles this

**"Permission denied"**
- Make executable: `chmod +x run_analysis.sh`

**launchd not running**
- Check: `launchctl list | grep trackpad`
- View errors: `cat logs/launchd-err.log`

**Plots not generating**
- Install matplotlib backend: `pip install pyobjc-framework-Cocoa`

## Performance

- Typical session (100 events): ~1 second
- Large session (10,000 events): ~5 seconds  
- Batch 50 sessions: ~2-3 minutes

## Advanced: Custom Automation

Create your own automation by importing the modules:

```python
from pathlib import Path
import data_loader, metrics, visualize

# Your custom logic
def my_automation():
    sessions = data_loader.load_sessions_from_directory(session_dir)
    for session in sessions:
        # Your processing
        pass
```

## Next Steps

- Set up notification on completion
- Export to cloud storage automatically
- Email summary reports
- Dashboard with real-time updates
