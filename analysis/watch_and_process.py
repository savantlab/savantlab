#!/usr/bin/env python3
"""
Watch for new session files and automatically process them.

Usage:
    python watch_and_process.py
    
This will monitor the session directory and automatically:
1. Detect new CSV files
2. Process them as soon as they're created
3. Generate metrics, plots, and statistics
"""

import time
from pathlib import Path
from datetime import datetime
import json

import data_loader
import metrics
import visualize


class SessionWatcher:
    """Watch for and process new session files."""
    
    def __init__(self, session_dir, output_dir, check_interval=2.0):
        self.session_dir = Path(session_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        self.check_interval = check_interval
        self.processed_files = set()
        
        # Load already existing files to avoid reprocessing
        self._load_existing_files()
    
    def _load_existing_files(self):
        """Remember files that already exist."""
        existing = self.session_dir.glob('session-*.csv')
        self.processed_files = {f.name for f in existing}
        print(f"Found {len(self.processed_files)} existing files (will not reprocess)")
    
    def process_new_session(self, csv_path):
        """Process a newly detected session file."""
        try:
            print(f"\n{'='*60}")
            print(f"NEW SESSION DETECTED: {csv_path.name}")
            print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"{'='*60}")
            
            # Wait a bit to ensure file is fully written
            time.sleep(0.5)
            
            # Load session
            session = data_loader.load_session(csv_path)
            
            if len(session.df) == 0:
                print("⚠️  Session has no events, skipping")
                return
            
            print(f"Events: {len(session.df)}")
            
            # Create output directory for this session
            session_output = self.output_dir / session.session_id
            session_output.mkdir(exist_ok=True)
            
            # Compute metrics
            metrics_df = metrics.compute_all_metrics(session, 'pointer')
            
            if not metrics_df.empty:
                # Get statistics
                stats = metrics.session_statistics(metrics_df)
                print(f"Duration: {stats.get('duration_sec', 0):.1f}s")
                print(f"Total distance: {stats.get('total_distance', 0):.1f} px")
                print(f"Mean speed: {stats.get('mean_speed', 0):.1f} px/s")
                
                # Save metrics
                metrics_path = session_output / f"{session.session_id}_metrics.csv"
                metrics_df.to_csv(metrics_path, index=False)
                print(f"✓ Saved metrics: {metrics_path}")
                
                # Save statistics
                stats_path = session_output / f"{session.session_id}_stats.json"
                with open(stats_path, 'w') as f:
                    json.dump(stats, f, indent=2, default=str)
                print(f"✓ Saved statistics: {stats_path}")
                
                # Generate visualizations
                try:
                    visualize.save_plots(session, session_output, metrics_df)
                    print(f"✓ Saved visualizations to: {session_output}")
                except Exception as e:
                    print(f"⚠️  Visualization error: {e}")
            else:
                print("⚠️  No pointer events to analyze")
            
            print(f"✅ Processing complete!")
            
        except Exception as e:
            print(f"❌ Error processing {csv_path.name}: {e}")
            import traceback
            traceback.print_exc()
    
    def check_for_new_files(self):
        """Check for new session files."""
        current_files = set(f.name for f in self.session_dir.glob('session-*.csv'))
        new_files = current_files - self.processed_files
        
        for filename in new_files:
            csv_path = self.session_dir / filename
            self.process_new_session(csv_path)
            self.processed_files.add(filename)
    
    def run(self):
        """Run the watcher continuously."""
        print("="*60)
        print("TRACKPAD SESSION WATCHER")
        print("="*60)
        print(f"Watching: {self.session_dir}")
        print(f"Output: {self.output_dir}")
        print(f"Check interval: {self.check_interval}s")
        print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("\nWaiting for new sessions... (Press Ctrl+C to stop)")
        print("="*60)
        
        try:
            while True:
                self.check_for_new_files()
                time.sleep(self.check_interval)
        except KeyboardInterrupt:
            print("\n\n✋ Watcher stopped by user")
            print(f"Processed {len(self.processed_files)} total sessions")


def main():
    # Configuration
    session_dir = Path.home() / 'Library/Containers/savant.savantlab/Data/Documents/savantlab-trackpad-sessions'
    output_dir = Path(__file__).parent / 'output'
    
    # Create and run watcher
    watcher = SessionWatcher(session_dir, output_dir, check_interval=2.0)
    watcher.run()


if __name__ == '__main__':
    main()
