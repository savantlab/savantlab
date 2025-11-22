"""
Eye Tracking Analysis using MediaPipe Face Mesh

Extracts eye tracking data from camera recordings:
- Gaze direction and position
- Eye openness (left/right)
- Pupil position estimation
- Blink detection
- Fixation points and duration
- Saccade movements
"""

import cv2
import numpy as np
import pandas as pd
import mediapipe as mp
from pathlib import Path
from typing import Optional, Tuple, List, Dict
from dataclasses import dataclass
from datetime import datetime


@dataclass
class EyeMetrics:
    """Eye tracking metrics for a single frame"""
    timestamp: float
    frame_number: int
    
    # Eye openness (0=closed, 1=fully open)
    left_eye_openness: float
    right_eye_openness: float
    
    # Pupil positions (normalized 0-1)
    left_pupil_x: float
    left_pupil_y: float
    right_pupil_x: float
    right_pupil_y: float
    
    # Gaze direction (estimated)
    gaze_x: Optional[float] = None
    gaze_y: Optional[float] = None
    
    # Blink detection
    is_blinking: bool = False
    
    # Head pose (rotation angles in degrees)
    head_pitch: Optional[float] = None
    head_yaw: Optional[float] = None
    head_roll: Optional[float] = None


class EyeTracker:
    """Extract eye tracking data from video using MediaPipe Face Mesh"""
    
    # MediaPipe Face Mesh landmark indices for eyes
    LEFT_EYE_INDICES = [33, 160, 158, 133, 153, 144]
    RIGHT_EYE_INDICES = [362, 385, 387, 263, 373, 380]
    LEFT_IRIS_INDICES = [468, 469, 470, 471, 472]
    RIGHT_IRIS_INDICES = [473, 474, 475, 476, 477]
    
    def __init__(self):
        """Initialize MediaPipe Face Mesh"""
        self.mp_face_mesh = mp.solutions.face_mesh
        self.face_mesh = self.mp_face_mesh.FaceMesh(
            max_num_faces=1,
            refine_landmarks=True,  # Enable iris tracking
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
        
    def process_video(self, video_path: Path, output_csv: Optional[Path] = None) -> pd.DataFrame:
        """
        Process video and extract eye tracking data
        
        Args:
            video_path: Path to camera MOV file
            output_csv: Optional path to save CSV output
            
        Returns:
            DataFrame with eye tracking metrics
        """
        print(f"[EyeTracker] Processing video: {video_path}")
        
        cap = cv2.VideoCapture(str(video_path))
        if not cap.isOpened():
            raise ValueError(f"Could not open video: {video_path}")
            
        fps = cap.get(cv2.CAP_PROP_FPS)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        print(f"[EyeTracker] Video: {fps:.1f} FPS, {total_frames} frames")
        
        metrics_list = []
        frame_number = 0
        
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
                
            timestamp = frame_number / fps
            
            # Convert BGR to RGB for MediaPipe
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            
            # Process frame
            results = self.face_mesh.process(rgb_frame)
            
            if results.multi_face_landmarks:
                landmarks = results.multi_face_landmarks[0]
                metrics = self._extract_metrics(landmarks, frame.shape, timestamp, frame_number)
                metrics_list.append(metrics)
            else:
                # No face detected - add null metrics
                metrics_list.append(EyeMetrics(
                    timestamp=timestamp,
                    frame_number=frame_number,
                    left_eye_openness=0.0,
                    right_eye_openness=0.0,
                    left_pupil_x=0.5,
                    left_pupil_y=0.5,
                    right_pupil_x=0.5,
                    right_pupil_y=0.5
                ))
            
            frame_number += 1
            
            if frame_number % 100 == 0:
                print(f"[EyeTracker] Processed {frame_number}/{total_frames} frames")
        
        cap.release()
        print(f"[EyeTracker] ✓ Processed {frame_number} frames")
        
        # Convert to DataFrame
        df = pd.DataFrame([vars(m) for m in metrics_list])
        
        # Add derived metrics
        df = self._add_derived_metrics(df)
        
        if output_csv:
            df.to_csv(output_csv, index=False)
            print(f"[EyeTracker] Saved to: {output_csv}")
        
        return df
    
    def _extract_metrics(self, landmarks, frame_shape, timestamp: float, frame_number: int) -> EyeMetrics:
        """Extract eye metrics from face landmarks"""
        h, w = frame_shape[:2]
        
        # Convert normalized landmarks to pixel coordinates
        def get_coords(idx):
            lm = landmarks.landmark[idx]
            return np.array([lm.x * w, lm.y * h])
        
        # Calculate eye openness (vertical eye aspect ratio)
        left_openness = self._calculate_eye_openness(landmarks, self.LEFT_EYE_INDICES)
        right_openness = self._calculate_eye_openness(landmarks, self.RIGHT_EYE_INDICES)
        
        # Get iris/pupil positions
        left_pupil = self._get_pupil_position(landmarks, self.LEFT_IRIS_INDICES)
        right_pupil = self._get_pupil_position(landmarks, self.RIGHT_IRIS_INDICES)
        
        # Estimate gaze direction
        gaze_x, gaze_y = self._estimate_gaze(left_pupil, right_pupil)
        
        # Detect blinks
        is_blinking = left_openness < 0.2 or right_openness < 0.2
        
        return EyeMetrics(
            timestamp=timestamp,
            frame_number=frame_number,
            left_eye_openness=left_openness,
            right_eye_openness=right_openness,
            left_pupil_x=left_pupil[0],
            left_pupil_y=left_pupil[1],
            right_pupil_x=right_pupil[0],
            right_pupil_y=right_pupil[1],
            gaze_x=gaze_x,
            gaze_y=gaze_y,
            is_blinking=is_blinking
        )
    
    def _calculate_eye_openness(self, landmarks, eye_indices: List[int]) -> float:
        """
        Calculate eye openness ratio
        Returns value between 0 (closed) and 1 (fully open)
        """
        # Get eye landmarks
        points = np.array([[landmarks.landmark[i].x, landmarks.landmark[i].y] for i in eye_indices])
        
        # Calculate vertical distance (top-bottom)
        vertical = np.linalg.norm(points[1] - points[5])
        
        # Calculate horizontal distance (left-right)
        horizontal = np.linalg.norm(points[0] - points[3])
        
        # Eye aspect ratio (normalized)
        ratio = vertical / (horizontal + 1e-6)
        
        # Normalize to 0-1 range (empirically determined thresholds)
        openness = np.clip(ratio / 0.3, 0, 1)
        
        return float(openness)
    
    def _get_pupil_position(self, landmarks, iris_indices: List[int]) -> Tuple[float, float]:
        """Get normalized pupil/iris position (0-1 range)"""
        # Average iris landmark positions
        x = np.mean([landmarks.landmark[i].x for i in iris_indices])
        y = np.mean([landmarks.landmark[i].y for i in iris_indices])
        return (float(x), float(y))
    
    def _estimate_gaze(self, left_pupil: Tuple[float, float], right_pupil: Tuple[float, float]) -> Tuple[float, float]:
        """
        Estimate gaze direction from pupil positions
        Returns normalized gaze coordinates (0-1 range)
        """
        # Average left and right pupil positions
        gaze_x = (left_pupil[0] + right_pupil[0]) / 2
        gaze_y = (left_pupil[1] + right_pupil[1]) / 2
        return (gaze_x, gaze_y)
    
    def _add_derived_metrics(self, df: pd.DataFrame) -> pd.DataFrame:
        """Add derived metrics like blink rate, fixations, saccades"""
        
        # Blink detection
        df['blink_event'] = df['is_blinking'].astype(int).diff().eq(1).astype(int)
        df['blink_count'] = df['blink_event'].cumsum()
        
        # Calculate blink rate (blinks per second) in rolling window
        window_size = 30  # ~1 second at 30 FPS
        df['blink_rate'] = df['blink_event'].rolling(window=window_size, min_periods=1).sum()
        
        # Eye movement velocity (gaze change rate)
        df['gaze_velocity_x'] = df['gaze_x'].diff().abs()
        df['gaze_velocity_y'] = df['gaze_y'].diff().abs()
        df['gaze_velocity'] = np.sqrt(df['gaze_velocity_x']**2 + df['gaze_velocity_y']**2)
        
        # Detect saccades (rapid eye movements)
        saccade_threshold = 0.01  # Empirically determined
        df['is_saccade'] = (df['gaze_velocity'] > saccade_threshold).astype(int)
        
        # Detect fixations (stable gaze)
        fixation_threshold = 0.002
        df['is_fixation'] = (df['gaze_velocity'] < fixation_threshold).astype(int)
        
        # Fixation duration
        df['fixation_group'] = (df['is_fixation'].diff() != 0).cumsum()
        fixation_durations = df[df['is_fixation'] == 1].groupby('fixation_group').size()
        df['fixation_duration'] = df['fixation_group'].map(fixation_durations).fillna(0)
        
        return df


def analyze_session(session_dir: Path) -> Optional[pd.DataFrame]:
    """
    Analyze a session directory and extract eye tracking data
    
    Args:
        session_dir: Path to directory containing session files
        
    Returns:
        DataFrame with eye tracking metrics or None if no camera file
    """
    # Find camera MOV file
    camera_files = list(session_dir.glob("*-camera.mov"))
    
    if not camera_files:
        print(f"[EyeTracker] No camera recording found in {session_dir}")
        return None
    
    camera_file = camera_files[0]
    session_name = camera_file.stem.replace("-camera", "")
    output_csv = session_dir / f"{session_name}-eye-tracking.csv"
    
    tracker = EyeTracker()
    df = tracker.process_video(camera_file, output_csv)
    
    return df


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python eye_tracking.py <session_directory>")
        sys.exit(1)
    
    session_path = Path(sys.argv[1])
    if not session_path.exists():
        print(f"Error: {session_path} does not exist")
        sys.exit(1)
    
    df = analyze_session(session_path)
    
    if df is not None:
        print(f"\n=== Eye Tracking Summary ===")
        print(f"Total frames: {len(df)}")
        print(f"Duration: {df['timestamp'].max():.1f} seconds")
        print(f"Total blinks: {df['blink_count'].max()}")
        print(f"Average blink rate: {df['blink_rate'].mean():.2f} blinks/sec")
        print(f"Saccade percentage: {df['is_saccade'].mean()*100:.1f}%")
        print(f"Fixation percentage: {df['is_fixation'].mean()*100:.1f}%")
