"""
Compute derived metrics from trackpad session data.
"""
import numpy as np
import pandas as pd


def compute_velocity(df, x_col='x', y_col='y', time_col='time_delta_sec'):
    """
    Compute velocity (speed and direction) from position and time data.
    
    Returns DataFrame with added columns:
    - velocity_x: horizontal velocity (units/sec)
    - velocity_y: vertical velocity (units/sec)
    - speed: magnitude of velocity (units/sec)
    - direction: angle in degrees (0=right, 90=up)
    """
    df = df.copy()
    
    # Compute time differences
    dt = df[time_col].diff()
    
    # Compute position differences
    dx = df[x_col].diff()
    dy = df[y_col].diff()
    
    # Compute velocity components (avoid division by zero)
    df['velocity_x'] = np.where(dt > 0, dx / dt, 0)
    df['velocity_y'] = np.where(dt > 0, dy / dt, 0)
    
    # Compute speed (magnitude)
    df['speed'] = np.sqrt(df['velocity_x']**2 + df['velocity_y']**2)
    
    # Compute direction (in degrees)
    df['direction'] = np.degrees(np.arctan2(df['velocity_y'], df['velocity_x']))
    
    return df


def compute_acceleration(df, velocity_x_col='velocity_x', velocity_y_col='velocity_y', 
                        time_col='time_delta_sec'):
    """
    Compute acceleration from velocity data.
    
    Returns DataFrame with added columns:
    - acceleration_x: horizontal acceleration
    - acceleration_y: vertical acceleration
    - acceleration_magnitude: magnitude of acceleration
    """
    df = df.copy()
    
    # Compute time differences
    dt = df[time_col].diff()
    
    # Compute velocity differences
    dv_x = df[velocity_x_col].diff()
    dv_y = df[velocity_y_col].diff()
    
    # Compute acceleration components
    df['acceleration_x'] = np.where(dt > 0, dv_x / dt, 0)
    df['acceleration_y'] = np.where(dt > 0, dv_y / dt, 0)
    
    # Compute magnitude
    df['acceleration_magnitude'] = np.sqrt(df['acceleration_x']**2 + df['acceleration_y']**2)
    
    return df


def compute_distance_traveled(df, x_col='x', y_col='y'):
    """
    Compute cumulative distance traveled.
    
    Returns DataFrame with added columns:
    - segment_distance: distance for each movement
    - cumulative_distance: total distance traveled
    """
    df = df.copy()
    
    # Compute position differences
    dx = df[x_col].diff()
    dy = df[y_col].diff()
    
    # Compute segment distances
    df['segment_distance'] = np.sqrt(dx**2 + dy**2)
    
    # Compute cumulative distance
    df['cumulative_distance'] = df['segment_distance'].fillna(0).cumsum()
    
    return df


def compute_all_metrics(session_data, event_type='pointer'):
    """
    Compute all metrics for a session.
    
    Args:
        session_data: SessionData object from data_loader
        event_type: 'pointer', 'touch', 'scroll', or 'gesture'
    
    Returns:
        DataFrame with all computed metrics
    """
    # Get relevant events
    if event_type == 'pointer':
        df = session_data.get_pointer_events()
        x_col, y_col = 'x', 'y'
    elif event_type == 'touch':
        df = session_data.get_touch_events()
        x_col, y_col = 'touch_normalizedX', 'touch_normalizedY'
    elif event_type == 'scroll':
        df = session_data.get_scroll_events()
        x_col, y_col = 'scrollDeltaX', 'scrollDeltaY'
    else:
        df = session_data.df.copy()
        x_col, y_col = 'x', 'y'
    
    if df.empty:
        return df
    
    # Drop rows with missing position data
    df = df.dropna(subset=[x_col, y_col, 'time_delta_sec'])
    
    if len(df) < 2:
        return df
    
    # Compute metrics
    df = compute_velocity(df, x_col, y_col)
    df = compute_acceleration(df)
    df = compute_distance_traveled(df, x_col, y_col)
    
    return df


def session_statistics(df, event_type='pointer'):
    """
    Compute summary statistics for a session.
    
    Returns dict with statistics.
    """
    if df.empty:
        return {}
    
    stats = {
        'total_events': len(df),
        'duration_sec': df['time_delta_sec'].max() if 'time_delta_sec' in df.columns else 0,
    }
    
    # Add position statistics if available
    if 'x' in df.columns and 'y' in df.columns:
        stats.update({
            'x_range': (df['x'].min(), df['x'].max()),
            'y_range': (df['y'].min(), df['y'].max()),
            'x_mean': df['x'].mean(),
            'y_mean': df['y'].mean(),
        })
    
    # Add velocity statistics if available
    if 'speed' in df.columns:
        stats.update({
            'mean_speed': df['speed'].mean(),
            'max_speed': df['speed'].max(),
            'median_speed': df['speed'].median(),
        })
    
    # Add acceleration statistics if available
    if 'acceleration_magnitude' in df.columns:
        stats.update({
            'mean_acceleration': df['acceleration_magnitude'].mean(),
            'max_acceleration': df['acceleration_magnitude'].max(),
        })
    
    # Add distance statistics if available
    if 'cumulative_distance' in df.columns:
        stats.update({
            'total_distance': df['cumulative_distance'].max(),
        })
    
    return stats


def compare_sessions(sessions, event_type='pointer'):
    """
    Compare metrics across multiple sessions.
    
    Args:
        sessions: list of SessionData objects
        event_type: type of events to analyze
    
    Returns:
        DataFrame with comparison statistics
    """
    comparison_data = []
    
    for session in sessions:
        df = compute_all_metrics(session, event_type)
        stats = session_statistics(df, event_type)
        stats['session_id'] = session.session_id
        stats['start_time'] = session.start_time
        comparison_data.append(stats)
    
    return pd.DataFrame(comparison_data)


def time_binned_statistics(df, bin_size_sec=1.0, stat_cols=['speed', 'acceleration_magnitude']):
    """
    Compute statistics in time bins.
    
    Args:
        df: DataFrame with time_delta_sec column
        bin_size_sec: size of time bins in seconds
        stat_cols: columns to compute statistics for
    
    Returns:
        DataFrame with time-binned statistics
    """
    if df.empty or 'time_delta_sec' not in df.columns:
        return pd.DataFrame()
    
    # Create time bins
    max_time = df['time_delta_sec'].max()
    bins = np.arange(0, max_time + bin_size_sec, bin_size_sec)
    df['time_bin'] = pd.cut(df['time_delta_sec'], bins=bins, labels=bins[:-1], include_lowest=True)
    
    # Compute statistics per bin
    result = []
    for col in stat_cols:
        if col in df.columns:
            binned = df.groupby('time_bin')[col].agg(['mean', 'std', 'min', 'max', 'count'])
            binned.columns = [f'{col}_{agg}' for agg in binned.columns]
            result.append(binned)
    
    if result:
        return pd.concat(result, axis=1).reset_index()
    else:
        return pd.DataFrame()
