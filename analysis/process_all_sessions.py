#!/usr/bin/env python3
"""
Automated batch processing of all trackpad sessions.

Usage:
    python process_all_sessions.py
    
This will:
1. Find all session CSV files
2. Compute metrics for each
3. Generate visualizations
4. Export statistics and processed data
"""

import sys
from pathlib import Path
import json
from datetime import datetime
import pandas as pd

import data_loader
import metrics
import visualize


def process_session(session, output_dir):
    """Process a single session: compute metrics, create plots, export data."""
    session_output = output_dir / session.session_id
    session_output.mkdir(exist_ok=True)
    
    print(f"\nProcessing: {session.session_id}")
    print(f"  Events: {len(session.df)}")
    
    # Compute metrics
    metrics_df = metrics.compute_all_metrics(session, 'pointer')
    
    if metrics_df.empty:
        print("  ⚠️  No pointer events to analyze")
        return None
    
    # Get statistics
    stats = metrics.session_statistics(metrics_df)
    print(f"  Duration: {stats.get('duration_sec', 0):.1f}s")
    print(f"  Total distance: {stats.get('total_distance', 0):.1f} px")
    print(f"  Mean speed: {stats.get('mean_speed', 0):.1f} px/s")
    
    # Save metrics CSV
    metrics_path = session_output / f"{session.session_id}_metrics.csv"
    metrics_df.to_csv(metrics_path, index=False)
    print(f"  ✓ Saved metrics: {metrics_path.name}")
    
    # Save statistics JSON
    stats_path = session_output / f"{session.session_id}_stats.json"
    with open(stats_path, 'w') as f:
        json.dump(stats, f, indent=2, default=str)
    print(f"  ✓ Saved statistics: {stats_path.name}")
    
    # Generate overview plot
    try:
        visualize.save_plots(session, session_output, metrics_df)
        print(f"  ✓ Saved visualizations")
    except Exception as e:
        print(f"  ⚠️  Visualization error: {e}")
    
    return stats


def generate_summary_report(all_stats, output_dir):
    """Create a summary report comparing all sessions."""
    if not all_stats:
        return
    
    # Convert to DataFrame
    summary_df = pd.DataFrame(all_stats)
    
    # Sort by start time
    if 'start_time' in summary_df.columns:
        summary_df = summary_df.sort_values('start_time')
    
    # Save summary CSV
    summary_path = output_dir / "summary_all_sessions.csv"
    summary_df.to_csv(summary_path, index=False)
    print(f"\n✓ Saved summary report: {summary_path}")
    
    # Print summary statistics
    print("\n" + "="*60)
    print("SUMMARY STATISTICS")
    print("="*60)
    print(f"Total sessions processed: {len(all_stats)}")
    
    if 'total_events' in summary_df.columns:
        print(f"Total events: {summary_df['total_events'].sum()}")
    
    if 'duration_sec' in summary_df.columns:
        print(f"Total recording time: {summary_df['duration_sec'].sum():.1f}s")
    
    if 'total_distance' in summary_df.columns:
        print(f"Average distance per session: {summary_df['total_distance'].mean():.1f} px")
    
    if 'mean_speed' in summary_df.columns:
        print(f"Average speed across sessions: {summary_df['mean_speed'].mean():.1f} px/s")
    
    print("="*60)


def main():
    # Configuration
    session_dir = Path.home() / 'Library/Containers/savant.savantlab/Data/Documents/savantlab-trackpad-sessions'
    output_dir = Path(__file__).parent / 'output'
    output_dir.mkdir(exist_ok=True)
    
    print("="*60)
    print("TRACKPAD SESSION BATCH PROCESSOR")
    print("="*60)
    print(f"Session directory: {session_dir}")
    print(f"Output directory: {output_dir}")
    print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Load all sessions
    print("\nLoading sessions...")
    sessions = data_loader.load_sessions_from_directory(session_dir)
    print(f"Found {len(sessions)} sessions with data")
    
    if not sessions:
        print("\n⚠️  No sessions found with data")
        return
    
    # Process each session
    all_stats = []
    for i, session in enumerate(sessions, 1):
        print(f"\n[{i}/{len(sessions)}]", end=" ")
        stats = process_session(session, output_dir)
        if stats:
            all_stats.append(stats)
    
    # Generate summary report
    generate_summary_report(all_stats, output_dir)
    
    print(f"\n✅ Complete! Results saved to: {output_dir}")
    print(f"Finished: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")


if __name__ == '__main__':
    main()
