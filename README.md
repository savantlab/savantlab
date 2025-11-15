# Mouse Trackpad Science Lab

This project is a science lab environment for recording and analyzing data from the mouse trackpad.

## Goals
- Capture raw trackpad events (position, velocity, gestures, timestamps).
- Store experiment sessions for later analysis.
- Provide tools to visualize and export the collected data.

## Current Components

### Python environment

Create and activate a virtual environment (recommended):

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Install Python dependencies as you go (there is no `requirements.txt` yet). For the current analysis workflow you will at least need:

```bash
pip install numpy pandas matplotlib jupyter
```

### Trackpad pointer logger (Python)

A simple pointer logger (mouse/trackpad) lives under `src/` and can be run with:

```bash
python -m src.trackpad_logger
```

It records pointer moves, clicks, and scroll events into CSV files under `data/`.

### macOS finger-contact logger (Swift)

A separate macOS app (built in Xcode, in a sibling project) logs per-finger contact on the trackpad using `NSTouch`. When the app runs:

- A window titled "Trackpad Finger Logger" appears.
- While the window is active, touches on the trackpad are recorded.
- On quit, the app writes CSV files into this repo's `data/` directory:
  - `touch_lifetimes_<session>.csv` – per-finger contact intervals, with
    - relative and absolute timestamps
    - normalized start/end positions on the trackpad
  - `finger_counts_<session>.csv` – time series of number of fingers in contact with the trackpad

### Browser canvas logger (JavaScript)

An HTML canvas-based drawing surface in the browser logs pointer events to a JSON file. The page should:

- Attach `pointerdown` / `pointermove` / `pointerup` handlers to the canvas.
- For each event, record at least:
  - `time_abs_iso` – `new Date().toISOString()`
  - `time_rel_ms` – milliseconds since the canvas session started
  - `event_type` – e.g. `"pointerdown"`, `"pointermove"`, `"pointerup"`
  - `x_canvas`, `y_canvas` – pointer coordinates in canvas space
- Provide a function (e.g. `endSession()`) that triggers download of `canvas_log.json`.

Save `canvas_log.json` into this repo's `data/` directory. The same page can also export the canvas image (e.g. `canvas_01.png`) for pixel-level analysis.

### Session analysis CLI (Python)

The script `src/run_session_analysis.py` ties together the finger-contact logs and canvas logs, aligns them in time, and generates basic plots.

Run it with:

```bash
python -m src.run_session_analysis
```

By default it:

- Looks for the latest `touch_lifetimes_*.csv` and `finger_counts_*.csv` in `data/`.
- Loads `data/canvas_log.json`.
- Aligns the timelines using absolute timestamps.
- Attaches the approximate finger count to each canvas event.
- Writes outputs under `data/analysis/`:
  - `canvas_log_with_fingers.csv`
  - `finger_count_over_time.png`
  - `touch_duration_hist.png`
  - `finger_count_vs_drawing.png`

You can customize inputs/outputs, for example:

```bash
python -m src.run_session_analysis \
  --canvas-log data/canvas_log.json \
  --output-dir data/analysis
```

### One-command analysis script

For convenience, there is a small shell script:

```bash
scripts/analyze_latest.sh
```

It assumes your virtual environment is already activated and simply runs:

```bash
python -m src.run_session_analysis "$@"
```

You can pass the same flags as to the Python module, e.g.:

```bash
scripts/analyze_latest.sh --output-dir data/analysis
```

## Typical end-to-end workflow

1. **Start the Swift finger-contact logger app**.
2. **Use the browser canvas app** to draw:
   - When finished, export `canvas_log.json` and the canvas image (e.g. `canvas_01.png`) into `data/`.
3. **Quit the Swift app** so it writes `touch_lifetimes_*.csv` and `finger_counts_*.csv` into `data/`.
4. **Run analysis** from the repo root:

   ```bash
   scripts/analyze_latest.sh
   ```

5. Inspect results in `data/analysis/` and/or load the CSVs into a Jupyter notebook for deeper analysis.
