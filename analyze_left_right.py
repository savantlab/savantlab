import json
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional

LAB_DIR = Path("lab")


@dataclass
class StrokeEvent:
    t: float
    type: str
    x: float
    y: float
    button: int
    buttons: int


def load_events(path: Path) -> List[StrokeEvent]:
    with path.open("r", encoding="utf-8") as f:
        session = json.load(f)
    return [
        StrokeEvent(
            t=e["t"],
            type=e["type"],
            x=e["x"],
            y=e["y"],
            button=e["button"],
            buttons=e["buttons"],
        )
        for e in session["events"]
    ]


def segment_strokes(events: List[StrokeEvent]) -> List[List[StrokeEvent]]:
    strokes: List[List[StrokeEvent]] = []
    current: List[StrokeEvent] = []
    drawing = False

    for ev in events:
        if ev.type == "down":
            if current:
                strokes.append(current)
            current = [ev]
            drawing = True
        elif ev.type == "move" and drawing:
            current.append(ev)
        elif ev.type == "up" and drawing:
            current.append(ev)
            strokes.append(current)
            current = []
            drawing = False

    if current:
        strokes.append(current)

    return strokes


def analyze_left_right_reversal(stroke: List[StrokeEvent]) -> Optional[dict]:
    """Analyze horizontal (left/right) direction changes in a single stroke."""
    if len(stroke) < 2:
        return None

    # Compute dx between successive events
    dxs = []
    for e1, e2 in zip(stroke, stroke[1:]):
        dx = e2.x - e1.x
        dxs.append(dx)

    # Threshold to ignore tiny jitters
    THRESH = 1.0
    dirs = []
    for dx in dxs:
        if dx > THRESH:
            dirs.append(1)   # right
        elif dx < -THRESH:
            dirs.append(-1)  # left
        else:
            dirs.append(0)   # neutral / tiny

    # First clear horizontal direction
    initial_dir = next((d for d in dirs if d != 0), 0)
    if initial_dir == 0:
        # No clear left/right motion in this stroke
        return {
            "has_reversal": False,
            "initial_dir": 0,
            "reversal_count": 0,
        }

    reversal_count = 0
    prev_dir = initial_dir
    for d in dirs:
        if d == 0:
            continue
        if d != prev_dir:
            reversal_count += 1
            prev_dir = d

    return {
        "has_reversal": reversal_count > 0,
        "initial_dir": initial_dir,  # 1 = right, -1 = left
        "reversal_count": reversal_count,
    }


def main() -> None:
    json_files = sorted(LAB_DIR.glob("*.json"))
    if not json_files:
        print("No lab JSON files found in 'lab/'. Run harmony_lab.py first.")
        return

    json_path = json_files[-1]
    events = load_events(json_path)
    strokes = segment_strokes(events)

    print(f"Loaded {json_path.name}")
    print(f"Total strokes: {len(strokes)}")

    results = []
    for stroke in strokes:
        info = analyze_left_right_reversal(stroke)
        if info is not None:
            results.append(info)

    if not results:
        print("No analyzable strokes.")
        return

    total = len(results)
    with_reversal = sum(1 for r in results if r["has_reversal"])

    from_right = [r for r in results if r["initial_dir"] == 1]
    from_left = [r for r in results if r["initial_dir"] == -1]

    print(
        f"Strokes with at least one left/right reversal: {with_reversal}/{total} "
        f"({with_reversal/total:.2%})"
    )

    if from_right:
        fr_with_rev = sum(1 for r in from_right if r["has_reversal"])
        print(
            f"  Starting right -> reversed at least once: {fr_with_rev}/{len(from_right)} "
            f"({fr_with_rev/len(from_right):.2%})"
        )

    if from_left:
        fl_with_rev = sum(1 for r in from_left if r["has_reversal"])
        print(
            f"  Starting left  -> reversed at least once: {fl_with_rev}/{len(from_left)} "
            f"({fl_with_rev/len(from_left):.2%})"
        )

    avg_reversals = sum(r["reversal_count"] for r in results) / total
    print(f"Average number of left/right reversals per stroke: {avg_reversals:.2f}")


if __name__ == "__main__":
    main()
