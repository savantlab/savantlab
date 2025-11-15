import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


DATA_DIR = Path(__file__).resolve().parent.parent / "data"


def find_latest(pattern: str) -> Path:
    candidates = sorted(DATA_DIR.glob(pattern))
    if not candidates:
        raise FileNotFoundError(f"No files matching {pattern!r} in {DATA_DIR}")
    return candidates[-1]


def load_touch_data():
    lifetimes_path = find_latest("touch_lifetimes_*.csv")
    counts_path = find_latest("finger_counts_*.csv")

    lifetimes = pd.read_csv(lifetimes_path)
    counts = pd.read_csv(counts_path)

    # Parse timestamps
    lifetimes["start_time_abs_iso"] = pd.to_datetime(lifetimes["start_time_abs_iso"])
    lifetimes["end_time_abs_iso"] = pd.to_datetime(lifetimes["end_time_abs_iso"])
    counts["time_abs_iso"] = pd.to_datetime(counts["time_abs_iso"])

    # Epoch seconds for alignment
    lifetimes["start_epoch"] = lifetimes["start_time_abs_iso"].view("int64") / 1e9
    lifetimes["end_epoch"] = lifetimes["end_time_abs_iso"].view("int64") / 1e9
    counts["epoch"] = counts["time_abs_iso"].view("int64") / 1e9

    return lifetimes, counts


def load_canvas_log(canvas_log_path: Path | None = None):
    if canvas_log_path is None:
        canvas_log_path = DATA_DIR / "canvas_log.json"
    if not canvas_log_path.exists():
        raise FileNotFoundError(f"Canvas log not found at {canvas_log_path}")

    canvas_log = pd.read_json(canvas_log_path)
    canvas_log["time_abs_iso"] = pd.to_datetime(canvas_log["time_abs_iso"])
    canvas_log["epoch"] = canvas_log["time_abs_iso"].view("int64") / 1e9
    return canvas_log


def align_timelines(counts: pd.DataFrame, canvas_log: pd.DataFrame):
    # Use first event from each as anchor
    t0_counts = counts["epoch"].min()
    t0_canvas = canvas_log["epoch"].min()
    offset = t0_canvas - t0_counts

    counts_aligned = counts.copy()
    counts_aligned["epoch_aligned"] = counts_aligned["epoch"] + offset
    return counts_aligned, offset


def attach_finger_counts(canvas_log: pd.DataFrame, counts_aligned: pd.DataFrame) -> pd.DataFrame:
    counts_idx = counts_aligned[["epoch_aligned", "num_fingers"]].rename(
        columns={"epoch_aligned": "epoch"}
    ).set_index("epoch").sort_index()

    canvas_log = canvas_log.sort_values("epoch").copy()
    canvas_log["num_fingers"] = counts_idx["num_fingers"].reindex(
        canvas_log["epoch"], method="nearest"
    ).values
    return canvas_log


def make_summary_plots(lifetimes: pd.DataFrame, counts_aligned: pd.DataFrame,
                        canvas_log: pd.DataFrame, output_dir: Path):
    output_dir.mkdir(parents=True, exist_ok=True)

    # 1. Finger count over time
    fig, ax = plt.subplots(figsize=(10, 3))
    ax.step(counts_aligned["epoch_aligned"], counts_aligned["num_fingers"], where="post")
    ax.set_xlabel("time (s, aligned)")
    ax.set_ylabel("num fingers")
    ax.set_title("Finger count over time")
    fig.tight_layout()
    fig.savefig(output_dir / "finger_count_over_time.png", dpi=150)
    plt.close(fig)

    # 2. Histogram of touch durations
    fig, ax = plt.subplots(figsize=(5, 3))
    lifetimes["duration_sec"].hist(bins=50, ax=ax)
    ax.set_xlabel("touch duration (s)")
    ax.set_ylabel("count")
    ax.set_title("Touch duration distribution")
    fig.tight_layout()
    fig.savefig(output_dir / "touch_duration_hist.png", dpi=150)
    plt.close(fig)

    # 3. Canvas events with finger count
    draw_events = canvas_log[canvas_log["event_type"] == "pointermove"]

    if not draw_events.empty:
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 6), sharex=True)

        ax1.step(counts_aligned["epoch_aligned"], counts_aligned["num_fingers"], where="post")
        ax1.set_ylabel("num fingers")
        ax1.set_title("Finger count vs drawing")

        ax2.scatter(draw_events["epoch"], draw_events["x_canvas"], s=1, alpha=0.5, label="x_canvas")
        ax2.scatter(draw_events["epoch"], draw_events["y_canvas"], s=1, alpha=0.5, label="y_canvas")
        ax2.set_xlabel("time (s, approx aligned)")
        ax2.set_ylabel("canvas coords")
        ax2.legend(loc="upper right")

        fig.tight_layout()
        fig.savefig(output_dir / "finger_count_vs_drawing.png", dpi=150)
        plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description="Analyze a trackpad + canvas session.")
    parser.add_argument(
        "--canvas-log",
        type=str,
        default=None,
        help="Path to canvas_log.json (default: data/canvas_log.json)",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default=str(DATA_DIR / "analysis"),
        help="Directory to write plots and summary files.",
    )

    args = parser.parse_args()
    output_dir = Path(args.output_dir)

    lifetimes, counts = load_touch_data()
    canvas_log = load_canvas_log(Path(args.canvas_log) if args.canvas_log else None)

    counts_aligned, offset = align_timelines(counts, canvas_log)
    canvas_log_with_counts = attach_finger_counts(canvas_log, counts_aligned)

    # Save aligned canvas log for inspection
    output_dir.mkdir(parents=True, exist_ok=True)
    canvas_log_with_counts.to_csv(output_dir / "canvas_log_with_fingers.csv", index=False)

    make_summary_plots(lifetimes, counts_aligned, canvas_log_with_counts, output_dir)

    print(f"Analysis complete. Offset used (canvas - counts) = {offset:.6f} s")
    print(f"Results written to {output_dir}")


if __name__ == "__main__":
    main()
