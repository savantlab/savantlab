# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Repository snapshot

- Top-level layout:
  - `README.md` – project goals and high-level plan.
  - `src/` – Python package root (currently only `__init__.py`).
- The project is in a very early stage. No package metadata (`pyproject.toml`, `setup.cfg`), tests, or tooling configuration exist yet.

Key points from `README.md`:
- Purpose: "science lab" for recording and analyzing mouse trackpad data.
- Goals:
  - Capture raw trackpad events (position, velocity, gestures, timestamps).
  - Store experiment sessions for later analysis.
  - Provide tools to visualize and export collected data.
- Next steps (not yet implemented in the repo):
  - Choose a primary implementation language and framework.
  - Implement a small prototype that logs basic trackpad activity to a file.

## Commands & tooling

There are **no project-specific build, lint, or test commands defined yet** (no test suite or build configuration exists). Until tooling is added, use standard Python commands as needed:

- Create a virtual environment (recommended):
  - `python -m venv .venv`
  - `source .venv/bin/activate` (macOS/Linux)
- Install any dependencies you add with `pip` (there is currently no `requirements.txt`).
- Run ad-hoc experiments or prototypes by adding Python modules under `src/` and invoking them with:
  - `python -m src.<module_name>`

When a test framework (e.g., `pytest`) or linting setup (e.g., `ruff`, `flake8`, `mypy`) is introduced, **update this section** with:
- How to run the full test suite.
- How to run a single test or test file.
- How to run linting and type checks.

## Code layout & architecture intentions

Current code layout:
- `src/__init__.py` exists but is empty. Treat `src` as the root package for the eventual implementation.

Given the project goals in `README.md`, the future architecture will likely evolve around these conceptual areas (none of these modules exist yet):
- **Event capture** – interfaces to the operating system / trackpad APIs to stream raw events with timestamps.
- **Session management & storage** – data models and persistence for experiment sessions (e.g., saving to files or a database).
- **Analysis & visualization** – utilities to process captured data and visualize trajectories, velocities, gestures, etc.
- **Export/IO** – serialization of captured/processed data into shareable formats (CSV, JSON, etc.).

As the codebase grows, prefer organizing new modules under `src/` by these responsibilities (e.g., `src/capture.py`, `src/session.py`, `src/analysis/…`) and keep this section updated to reflect the actual structure.

## Notes for future Warp agents

- Do not assume tests, linters, or build scripts exist; check the repository first and add them explicitly if needed.
- When introducing new tooling (tests, linting, packaging), document the exact commands in this file under **Commands & tooling**.
- When adding significant new modules or packages under `src/`, update **Code layout & architecture intentions** to describe the real architecture rather than the conceptual one above.