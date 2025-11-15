import glob
import json
import signal
import subprocess
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from time import time, sleep
from typing import List, Optional

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service

HARMONY_URL = "https://mrdoob.github.io/harmony/#shaded"
LAB_DIR = Path("lab")
POLL_INTERVAL = 0.25

# CHANGE THIS to your screen index from `ffmpeg -f avfoundation -list_devices true -i ""`
SCREEN_INDEX = "0"  # usually "0" is the main screen on macOS

# Optional ffmpeg video options (tweak as needed)
FFMPEG_VIDEO_OPTS = [
    "-r",
    "30",  # fps
]


@dataclass
class StrokeEvent:
    t: float
    type: str
    x: int
    y: int
    button: int
    buttons: int


@dataclass
class Session:
    started_at_local: str
    ended_at_local: str
    duration_seconds: float
    url: str
    label: str
    events: List[StrokeEvent]


JS_INIT_LISTENERS = r"""
(function() {
  if (window._harmonyLabInitialized) return;
  window._harmonyLabInitialized = true;
  window._harmonyLabEvents = [];
  window._harmonyLabStartTime = performance.now();
  window._harmonyLabDone = false;

  function record(type, ev) {
    var t = (performance.now() - window._harmonyLabStartTime) / 1000.0;
    window._harmonyLabEvents.push({
      t: t,
      type: type,
      x: ev.clientX,
      y: ev.clientY,
      button: ev.button,
      buttons: ev.buttons
    });
  }

  document.addEventListener('mousedown', function(ev) { record('down', ev); });
  document.addEventListener('mouseup',   function(ev) { record('up', ev); });
  document.addEventListener('mousemove', function(ev) { record('move', ev); });

  document.addEventListener('keydown', function(ev) {
    if (ev.key === 'Escape') {
      window._harmonyLabDone = true;
    }
  });
})();
"""


JS_POP_EVENTS = r"""
(function() {
  if (!window._harmonyLabEvents) return [];
  var evts = window._harmonyLabEvents;
  window._harmonyLabEvents = [];
  return evts;
})();
"""


JS_IS_DONE = r"""
(function() {
  return !!window._harmonyLabDone;
})();
"""


def next_label_for_today() -> str:
    LAB_DIR.mkdir(parents=True, exist_ok=True)
    today = datetime.now().strftime("%Y-%m-%d")
    pattern = str(LAB_DIR / f"{today}_*.json")
    existing = glob.glob(pattern)

    max_idx = 0
    for path in existing:
        name = Path(path).stem  # "YYYY-MM-DD_NNN"
        parts = name.split("_")
        if len(parts) == 2 and parts[0] == today:
            try:
                idx = int(parts[1])
                max_idx = max(max_idx, idx)
            except ValueError:
                continue

    return f"{max_idx + 1:03d}"


def start_screen_recording(label: str) -> subprocess.Popen:
    today = datetime.now().strftime("%Y-%m-%d")
    LAB_DIR.mkdir(parents=True, exist_ok=True)
    video_path = LAB_DIR / f"{today}_{label}.mp4"

    cmd = [
        "ffmpeg",
        "-y",
        "-f",
        "avfoundation",
        "-framerate",
        "30",
        "-i",
        f"{SCREEN_INDEX}:",
        *FFMPEG_VIDEO_OPTS,
        str(video_path),
    ]

    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return proc


def stop_screen_recording(proc: Optional[subprocess.Popen]) -> None:
    if proc is None:
        return
    try:
        proc.send_signal(signal.SIGINT)
        proc.wait(timeout=10)
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass


def save_screenshot(driver: webdriver.Chrome, label: str) -> Path:
    LAB_DIR.mkdir(parents=True, exist_ok=True)
    today = datetime.now().strftime("%Y-%m-%d")
    path = LAB_DIR / f"{today}_{label}.png"
    driver.save_screenshot(str(path))
    return path


def run_harmony_session(label: str) -> Session:
    options = Options()
    options.add_argument("--start-maximized")

    driver: Optional[webdriver.Chrome] = None
    started_at = datetime.now()
    t0 = time()
    events: List[StrokeEvent] = []

    try:
        driver = webdriver.Chrome(service=Service(), options=options)
        driver.get(HARMONY_URL)
        driver.execute_script(JS_INIT_LISTENERS)

        recorder = start_screen_recording(label)

        try:
            while True:
                try:
                    _ = driver.title
                except Exception:
                    break

                try:
                    done = bool(driver.execute_script(JS_IS_DONE))
                except Exception:
                    done = True

                raw_events = driver.execute_script(JS_POP_EVENTS) or []
                for ev in raw_events:
                    events.append(
                        StrokeEvent(
                            t=float(ev["t"]),
                            type=str(ev["type"]),
                            x=int(ev["x"]),
                            y=int(ev["y"]),
                            button=int(ev["button"]),
                            buttons=int(ev["buttons"]),
                        )
                    )

                if done:
                    save_screenshot(driver, label)
                    break

                sleep(POLL_INTERVAL)
        finally:
            stop_screen_recording(recorder)

    finally:
        if driver is not None:
            try:
                driver.quit()
            except Exception:
                pass

    ended_at = datetime.now()
    duration = time() - t0

    return Session(
        started_at_local=started_at.strftime("%Y-%m-%dT%H:%M:%S"),
        ended_at_local=ended_at.strftime("%Y-%m-%dT%H:%M:%S"),
        duration_seconds=duration,
        url=HARMONY_URL,
        label=label,
        events=events,
    )


def save_session(session: Session) -> Path:
    LAB_DIR.mkdir(parents=True, exist_ok=True)
    today = datetime.now().strftime("%Y-%m-%d")
    path = LAB_DIR / f"{today}_{session.label}.json"

    with path.open("w", encoding="utf-8") as f:
        json.dump(
            {
                "started_at_local": session.started_at_local,
                "ended_at_local": session.ended_at_local,
                "duration_seconds": session.duration_seconds,
                "url": session.url,
                "label": session.label,
                "events": [asdict(e) for e in session.events],
            },
            f,
            indent=2,
        )

    return path


if __name__ == "__main__":
    label = next_label_for_today()
    print(f"Starting lab session {label} for today...")
    session = run_harmony_session(label=label)
    out_path = save_session(session)
    print(f"Captured {len(session.events)} events")
    print(f"Saved session to {out_path}")
    print("Video and screenshot recorded alongside JSON with same label.")
