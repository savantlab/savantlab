"""
Load and parse trackpad session CSV files.
"""
import pandas as pd
from pathlib import Path
from datetime import datetime
import numpy as np


class SessionData:
    """Container for a single trackpad session."""
    
    def __init__(self, csv_path):
        self.path = Path(csv_path)
        self.df = self._load_csv()
        self.session_id = self._extract_session_id()
        self.start_time = self._get_start_time()
        
    def _load_csv(self):
        """Load CSV and parse timestamps."""
        df = pd.read_csv(self.path)
        
        # Parse timestamps
        df['timestamp_local'] = pd.to_datetime(df['timestamp_local'], errors='coerce')
        
        # Convert numeric columns
        numeric_cols = ['x', 'y', 'deltaX', 'deltaY', 'phase', 
                       'scrollDeltaX', 'scrollDeltaY',
                       'touch_normalizedX', 'touch_normalizedY']
        for col in numeric_cols:
            if col in df.columns:
                df[col] = pd.to_numeric(df[col], errors='coerce')
        
        # Add time delta from start
        if not df.empty and df['timestamp_local'].notna().any():
            first_time = df['timestamp_local'].dropna().iloc[0]
            df['time_delta_sec'] = (df['timestamp_local'] - first_time).dt.total_seconds()
        
        return df
    
    def _extract_session_id(self):
        """Extract session identifier from filename."""
        # Filename format: session-YYYYMMDD-HHMMSS.csv
        return self.path.stem
    
    def _get_start_time(self):
        """Get session start time."""
        if not self.df.empty and 'timestamp_local' in self.df.columns:
            return self.df['timestamp_local'].dropna().iloc[0] if len(self.df) > 0 else None
        return None
    
    def get_event_types(self):
        """Return unique event types in session."""
        return self.df['event_type'].dropna().unique().tolist()
    
    def filter_by_event_type(self, event_type):
        """Return DataFrame filtered to specific event type."""
        return self.df[self.df['event_type'] == event_type].copy()
    
    def get_pointer_events(self):
        """Get pointer movement events (mouseMoved, dragged)."""
        pointer_types = ['mouseMoved', 'leftMouseDragged', 'rightMouseDragged', 'otherMouseDragged']
        return self.df[self.df['event_type'].isin(pointer_types)].copy()
    
    def get_touch_events(self):
        """Get touch events."""
        return self.df[self.df['event_type'] == 'touch'].copy()
    
    def get_scroll_events(self):
        """Get scroll events."""
        return self.df[self.df['event_type'] == 'scrollWheel'].copy()
    
    def get_gesture_events(self):
        """Get gesture events (magnify, rotate, swipe)."""
        gesture_types = ['magnify', 'rotate', 'swipe']
        return self.df[self.df['event_type'].isin(gesture_types)].copy()
    
    def summary(self):
        """Return summary statistics for session."""
        return {
            'session_id': self.session_id,
            'start_time': str(self.start_time) if self.start_time else None,
            'duration_sec': self.df['time_delta_sec'].max() if 'time_delta_sec' in self.df.columns else 0,
            'total_events': len(self.df),
            'event_types': self.get_event_types(),
            'event_counts': self.df['event_type'].value_counts().to_dict()
        }


def load_session(csv_path):
    """Load a single session from CSV file."""
    return SessionData(csv_path)


def load_sessions_from_directory(directory_path, pattern="session-*.csv"):
    """Load all sessions from a directory."""
    directory = Path(directory_path)
    csv_files = sorted(directory.glob(pattern))
    
    sessions = []
    for csv_file in csv_files:
        try:
            session = SessionData(csv_file)
            # Only include sessions with actual events
            if len(session.df) > 0:
                sessions.append(session)
        except Exception as e:
            print(f"Error loading {csv_file}: {e}")
    
    return sessions


def load_all_sessions_combined(directory_path, pattern="session-*.csv"):
    """Load all sessions and combine into a single DataFrame with session labels."""
    sessions = load_sessions_from_directory(directory_path, pattern)
    
    combined_dfs = []
    for session in sessions:
        df = session.df.copy()
        df['session_id'] = session.session_id
        df['session_start'] = session.start_time
        combined_dfs.append(df)
    
    if combined_dfs:
        return pd.concat(combined_dfs, ignore_index=True)
    else:
        return pd.DataFrame()
