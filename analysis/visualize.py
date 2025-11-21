"""
Visualization tools for trackpad session data.
"""
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import pandas as pd
from matplotlib.colors import LinearSegmentedColormap


# Set default style
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (12, 8)


def plot_trajectory(df, x_col='x', y_col='y', color_by='time_delta_sec', 
                   title='Trackpad Trajectory', ax=None):
    """
    Plot 2D trajectory of pointer/touch movement.
    
    Args:
        df: DataFrame with position data
        x_col, y_col: column names for x and y coordinates
        color_by: column to use for color gradient (e.g. 'time_delta_sec', 'speed')
        title: plot title
        ax: matplotlib axis (optional)
    """
    if ax is None:
        fig, ax = plt.subplots(figsize=(10, 8))
    
    if df.empty:
        ax.text(0.5, 0.5, 'No data', ha='center', va='center')
        return ax
    
    # Create scatter plot with color gradient
    if color_by in df.columns:
        scatter = ax.scatter(df[x_col], df[y_col], c=df[color_by], 
                           s=20, alpha=0.6, cmap='viridis')
        plt.colorbar(scatter, ax=ax, label=color_by)
    else:
        ax.scatter(df[x_col], df[y_col], s=20, alpha=0.6)
    
    # Plot start and end points
    if len(df) > 0:
        ax.plot(df[x_col].iloc[0], df[y_col].iloc[0], 'go', 
               markersize=12, label='Start', zorder=5)
        ax.plot(df[x_col].iloc[-1], df[y_col].iloc[-1], 'ro', 
               markersize=12, label='End', zorder=5)
    
    ax.set_xlabel(x_col)
    ax.set_ylabel(y_col)
    ax.set_title(title)
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    return ax


def plot_velocity_over_time(df, title='Speed Over Time', ax=None):
    """Plot speed as a time series."""
    if ax is None:
        fig, ax = plt.subplots(figsize=(12, 4))
    
    if df.empty or 'speed' not in df.columns:
        ax.text(0.5, 0.5, 'No velocity data', ha='center', va='center')
        return ax
    
    ax.plot(df['time_delta_sec'], df['speed'], linewidth=1, alpha=0.7)
    ax.fill_between(df['time_delta_sec'], 0, df['speed'], alpha=0.3)
    
    ax.set_xlabel('Time (seconds)')
    ax.set_ylabel('Speed (units/sec)')
    ax.set_title(title)
    ax.grid(True, alpha=0.3)
    
    return ax


def plot_acceleration_over_time(df, title='Acceleration Over Time', ax=None):
    """Plot acceleration magnitude as a time series."""
    if ax is None:
        fig, ax = plt.subplots(figsize=(12, 4))
    
    if df.empty or 'acceleration_magnitude' not in df.columns:
        ax.text(0.5, 0.5, 'No acceleration data', ha='center', va='center')
        return ax
    
    ax.plot(df['time_delta_sec'], df['acceleration_magnitude'], 
           linewidth=1, alpha=0.7, color='orangered')
    ax.fill_between(df['time_delta_sec'], 0, df['acceleration_magnitude'], 
                    alpha=0.3, color='orangered')
    
    ax.set_xlabel('Time (seconds)')
    ax.set_ylabel('Acceleration (units/sec²)')
    ax.set_title(title)
    ax.grid(True, alpha=0.3)
    
    return ax


def plot_heatmap(df, x_col='x', y_col='y', bins=50, title='Position Heatmap', ax=None):
    """
    Create a 2D histogram heatmap of positions.
    
    Args:
        df: DataFrame with position data
        x_col, y_col: column names for coordinates
        bins: number of bins for histogram
        title: plot title
        ax: matplotlib axis (optional)
    """
    if ax is None:
        fig, ax = plt.subplots(figsize=(10, 8))
    
    if df.empty:
        ax.text(0.5, 0.5, 'No data', ha='center', va='center')
        return ax
    
    # Create 2D histogram
    heatmap, xedges, yedges = np.histogram2d(
        df[x_col].dropna(), df[y_col].dropna(), bins=bins
    )
    
    # Plot heatmap
    extent = [xedges[0], xedges[-1], yedges[0], yedges[-1]]
    im = ax.imshow(heatmap.T, extent=extent, origin='lower', 
                  cmap='hot', aspect='auto', interpolation='bilinear')
    
    plt.colorbar(im, ax=ax, label='Event count')
    ax.set_xlabel(x_col)
    ax.set_ylabel(y_col)
    ax.set_title(title)
    
    return ax


def plot_event_distribution(df, title='Event Type Distribution', ax=None):
    """Plot distribution of event types."""
    if ax is None:
        fig, ax = plt.subplots(figsize=(10, 6))
    
    if df.empty or 'event_type' not in df.columns:
        ax.text(0.5, 0.5, 'No event data', ha='center', va='center')
        return ax
    
    event_counts = df['event_type'].value_counts()
    event_counts.plot(kind='bar', ax=ax, color='steelblue', alpha=0.7)
    
    ax.set_xlabel('Event Type')
    ax.set_ylabel('Count')
    ax.set_title(title)
    ax.tick_params(axis='x', rotation=45)
    ax.grid(True, alpha=0.3, axis='y')
    
    return ax


def plot_session_overview(session_data, metrics_df=None):
    """
    Create a comprehensive overview plot for a single session.
    
    Args:
        session_data: SessionData object
        metrics_df: DataFrame with computed metrics (optional, will compute if not provided)
    """
    from . import metrics as m
    
    if metrics_df is None:
        metrics_df = m.compute_all_metrics(session_data, 'pointer')
    
    fig = plt.figure(figsize=(16, 12))
    gs = fig.add_gridspec(3, 2, hspace=0.3, wspace=0.3)
    
    # Trajectory plot
    ax1 = fig.add_subplot(gs[0, :])
    plot_trajectory(metrics_df, title=f'Session: {session_data.session_id}', ax=ax1)
    
    # Speed over time
    ax2 = fig.add_subplot(gs[1, 0])
    plot_velocity_over_time(metrics_df, ax=ax2)
    
    # Acceleration over time
    ax3 = fig.add_subplot(gs[1, 1])
    plot_acceleration_over_time(metrics_df, ax=ax3)
    
    # Position heatmap
    ax4 = fig.add_subplot(gs[2, 0])
    plot_heatmap(metrics_df, ax=ax4)
    
    # Event distribution
    ax5 = fig.add_subplot(gs[2, 1])
    plot_event_distribution(session_data.df, ax=ax5)
    
    plt.suptitle(f'Session Overview: {session_data.session_id}', fontsize=16, y=0.995)
    
    return fig


def plot_session_comparison(sessions, metric='mean_speed', title=None):
    """
    Compare a specific metric across multiple sessions.
    
    Args:
        sessions: list of SessionData objects
        metric: metric to compare (from session_statistics)
        title: plot title (optional)
    """
    from . import metrics as m
    
    comparison_df = m.compare_sessions(sessions)
    
    if comparison_df.empty or metric not in comparison_df.columns:
        print(f"No data for metric: {metric}")
        return None
    
    fig, ax = plt.subplots(figsize=(12, 6))
    
    # Plot bars
    x = range(len(comparison_df))
    ax.bar(x, comparison_df[metric], color='steelblue', alpha=0.7)
    
    # Set labels
    ax.set_xlabel('Session')
    ax.set_ylabel(metric.replace('_', ' ').title())
    ax.set_title(title or f'Comparison: {metric.replace("_", " ").title()}')
    ax.set_xticks(x)
    ax.set_xticklabels(comparison_df['session_id'], rotation=45, ha='right')
    ax.grid(True, alpha=0.3, axis='y')
    
    plt.tight_layout()
    
    return fig


def plot_speed_distribution(df, bins=30, title='Speed Distribution', ax=None):
    """Plot histogram of speed values."""
    if ax is None:
        fig, ax = plt.subplots(figsize=(10, 6))
    
    if df.empty or 'speed' not in df.columns:
        ax.text(0.5, 0.5, 'No speed data', ha='center', va='center')
        return ax
    
    speed_data = df['speed'].dropna()
    ax.hist(speed_data, bins=bins, color='steelblue', alpha=0.7, edgecolor='black')
    
    # Add mean and median lines
    mean_speed = speed_data.mean()
    median_speed = speed_data.median()
    ax.axvline(mean_speed, color='red', linestyle='--', linewidth=2, label=f'Mean: {mean_speed:.1f}')
    ax.axvline(median_speed, color='green', linestyle='--', linewidth=2, label=f'Median: {median_speed:.1f}')
    
    ax.set_xlabel('Speed (units/sec)')
    ax.set_ylabel('Frequency')
    ax.set_title(title)
    ax.legend()
    ax.grid(True, alpha=0.3, axis='y')
    
    return ax


def plot_direction_polar(df, bins=36, title='Movement Direction Distribution', ax=None):
    """
    Plot polar histogram of movement directions.
    
    Args:
        df: DataFrame with 'direction' column (in degrees)
        bins: number of angular bins
        title: plot title
        ax: matplotlib polar axis (optional)
    """
    if ax is None:
        fig, ax = plt.subplots(figsize=(8, 8), subplot_kw=dict(projection='polar'))
    
    if df.empty or 'direction' not in df.columns:
        return ax
    
    # Convert degrees to radians
    directions = np.radians(df['direction'].dropna())
    
    # Create histogram
    counts, bin_edges = np.histogram(directions, bins=bins, range=(0, 2*np.pi))
    bin_centers = (bin_edges[:-1] + bin_edges[1:]) / 2
    
    # Plot bars
    width = 2 * np.pi / bins
    ax.bar(bin_centers, counts, width=width, alpha=0.7, edgecolor='black')
    
    ax.set_title(title, pad=20)
    ax.set_theta_zero_location('E')
    ax.set_theta_direction(1)
    
    return ax


def save_plots(session_data, output_dir, metrics_df=None):
    """
    Generate and save all plots for a session.
    
    Args:
        session_data: SessionData object
        output_dir: directory to save plots
        metrics_df: DataFrame with computed metrics (optional)
    """
    from pathlib import Path
    
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Generate overview
    fig = plot_session_overview(session_data, metrics_df)
    fig.savefig(output_path / f'{session_data.session_id}_overview.png', dpi=150, bbox_inches='tight')
    plt.close(fig)
    
    print(f"Saved plots to {output_path}")
