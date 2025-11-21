# Harmony Sessions Data Analysis Pipeline

Comprehensive Python tools for analyzing trackpad session data collected from the Harmony Sessions Tracking and Data App (macOS).

## Features

- **Data Loading**: Parse CSV session files with automatic timestamp conversion
- **Metrics Computation**: Calculate velocity, acceleration, distance traveled, and more
- **Visualizations**: Trajectory maps, heatmaps, time series, distributions, polar plots
- **Session Comparison**: Compare metrics across multiple sessions
- **Interactive Exploration**: Jupyter notebook for hands-on analysis
- **Export**: Save processed metrics and statistics in CSV/JSON formats

## Installation

1. **Create a virtual environment** (recommended):
```bash
python3 -m venv venv
source venv/bin/activate  # On macOS/Linux
```

2. **Install dependencies**:
```bash
pip install -r requirements.txt
```

## Quick Start

### Using the Jupyter Notebook

1. **Launch Jupyter**:
```bash
cd analysis
jupyter notebook explore_trackpad_data.ipynb
```

2. **Follow the notebook cells** to:
   - Load session data
   - Compute metrics
   - Create visualizations
   - Export results

### Using Python Scripts

```python
from pathlib import Path
import data_loader
import metrics
import visualize

# Load a session
session_dir = Path.home() / 'Library/Containers/savant.savantlab/Data/Documents/savantlab-trackpad-sessions'
session = data_loader.load_session(session_dir / 'session-20251119-005312.csv')

# Compute metrics
metrics_df = metrics.compute_all_metrics(session, 'pointer')

# Create visualizations
visualize.plot_session_overview(session, metrics_df)

# Get statistics
stats = metrics.session_statistics(metrics_df)
print(stats)
```

## Modules

### `data_loader.py`
Load and parse session CSV files.

**Key functions:**
- `load_session(csv_path)` - Load single session
- `load_sessions_from_directory(directory)` - Load all sessions from folder
- `SessionData` class - Container with helper methods for filtering events

### `metrics.py`
Compute derived metrics from raw trackpad data.

**Key functions:**
- `compute_velocity(df)` - Calculate speed and direction
- `compute_acceleration(df)` - Calculate acceleration magnitude
- `compute_distance_traveled(df)` - Cumulative distance
- `compute_all_metrics(session, event_type)` - All metrics at once
- `session_statistics(df)` - Summary statistics
- `compare_sessions(sessions)` - Cross-session comparison

### `visualize.py`
Create publication-quality plots.

**Key functions:**
- `plot_trajectory(df)` - 2D path with time/speed coloring
- `plot_velocity_over_time(df)` - Speed time series
- `plot_acceleration_over_time(df)` - Acceleration time series
- `plot_heatmap(df)` - Position density heatmap
- `plot_event_distribution(df)` - Event type bar chart
- `plot_session_overview(session)` - Comprehensive multi-panel figure
- `plot_session_comparison(sessions)` - Compare metric across sessions
- `plot_speed_distribution(df)` - Histogram of speeds
- `plot_direction_polar(df)` - Polar plot of movement directions

## Example Analyses

### Analyze Drawing Patterns
```python
session = data_loader.load_session('session-20251119-005312.csv')
metrics_df = metrics.compute_all_metrics(session, 'pointer')

# Plot trajectory colored by speed
visualize.plot_trajectory(metrics_df, color_by='speed')

# Check drawing statistics
stats = metrics.session_statistics(metrics_df)
print(f"Total distance: {stats['total_distance']:.1f} pixels")
print(f"Average speed: {stats['mean_speed']:.1f} px/sec")
```

### Compare Sessions Over Time
```python
sessions = data_loader.load_sessions_from_directory(session_dir)
comparison = metrics.compare_sessions(sessions)

# Plot mean speed across sessions
visualize.plot_session_comparison(sessions, metric='mean_speed')
```

### Time-Binned Analysis
```python
# Compute statistics in 1-second bins
binned = metrics.time_binned_statistics(metrics_df, bin_size_sec=1.0)
print(binned)
```

## Data Format

Session CSV files contain:
- `timestamp_local`: ISO 8601 timestamp with milliseconds
- `event_type`: Type of event (mouseMoved, scrollWheel, touch, etc.)
- `x`, `y`: Position coordinates (for pointer events)
- `deltaX`, `deltaY`: Position deltas
- `scrollDeltaX`, `scrollDeltaY`: Scroll amounts
- `touch_*`: Touch-specific fields (normalized position, phase, etc.)

## Tips

1. **Filter by event type** before computing metrics:
   ```python
   pointer_events = session.get_pointer_events()
   touch_events = session.get_touch_events()
   ```

2. **Handle empty sessions**: Some sessions may have no events. Check:
   ```python
   if not session.df.empty:
       # Process data
   ```

3. **Export for ML**: Save processed metrics as features:
   ```python
   metrics_df.to_csv('features.csv', index=False)
   ```

4. **Batch processing**: Process all sessions in a loop:
   ```python
   for session in sessions:
       visualize.save_plots(session, 'output_dir')
   ```

## Extending the Pipeline

Add custom metrics in `metrics.py`:
```python
def compute_custom_metric(df):
    df['my_metric'] = # your calculation
    return df
```

Add custom plots in `visualize.py`:
```python
def plot_my_visualization(df):
    fig, ax = plt.subplots()
    # your plotting code
    return ax
```

## Troubleshooting

- **Import errors**: Make sure you're running Python from the `analysis/` directory
- **No data**: Check that session CSV files have actual events (not just headers)
- **Plot issues**: If plots don't display in Jupyter, add `%matplotlib inline`
- **Memory issues**: Process sessions one at a time instead of loading all at once

## Next Steps

- Add machine learning models for gesture recognition
- Implement real-time analysis during data collection
- Create interactive dashboards with Plotly/Dash
- Add statistical tests for comparing sessions
- Export animations of trajectories
