#!/bin/bash
# Setup script for Harmony Sessions eye tracking analysis
# 
# This script:
# 1. Checks for Python 3.9-3.12 (required for MediaPipe)
# 2. Creates a virtual environment
# 3. Installs all dependencies
# 4. Verifies the installation

set -e  # Exit on error

echo "=== Harmony Sessions Eye Tracking Setup ==="
echo ""

# Check if pyenv is installed
if ! command -v pyenv &> /dev/null; then
    echo "⚠️  pyenv not found. Installing via Homebrew..."
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew not found. Please install Homebrew first:"
        echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    brew install pyenv
    echo "✓ pyenv installed"
fi

# Initialize pyenv in current shell
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"

# Check for Python 3.12
PYTHON_VERSION="3.12"
if ! pyenv versions | grep -q "$PYTHON_VERSION"; then
    echo "📦 Installing Python $PYTHON_VERSION via pyenv..."
    pyenv install $PYTHON_VERSION
    echo "✓ Python $PYTHON_VERSION installed"
else
    echo "✓ Python $PYTHON_VERSION already installed"
fi

# Get the full version (e.g., 3.12.12)
PYTHON_FULL_VERSION=$(pyenv versions | grep "$PYTHON_VERSION" | tail -1 | tr -d '* ' | xargs)
PYTHON_PATH="$HOME/.pyenv/versions/$PYTHON_FULL_VERSION/bin/python3"

echo ""
echo "Using Python: $PYTHON_PATH"
echo ""

# Create virtual environment
VENV_NAME="venv-eyetracking"
if [ -d "$VENV_NAME" ]; then
    echo "⚠️  Virtual environment already exists. Removing..."
    rm -rf "$VENV_NAME"
fi

echo "📦 Creating virtual environment: $VENV_NAME"
$PYTHON_PATH -m venv $VENV_NAME

# Activate virtual environment
source $VENV_NAME/bin/activate

# Upgrade pip
echo "📦 Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "📦 Installing dependencies..."
pip install opencv-python mediapipe pandas numpy matplotlib seaborn jupyter

echo ""
echo "✓ Installation complete!"
echo ""
echo "=== Next Steps ==="
echo ""
echo "1. Activate the environment:"
echo "   source venv-eyetracking/bin/activate"
echo ""
echo "2. Run eye tracking on a session:"
echo "   python -c \""
echo "from pathlib import Path"
echo "import eye_tracking"
echo ""
echo "sessions_dir = Path.home() / 'Library/Containers/savant.savantlab/Data/Documents/savantlab-trackpad-sessions'"
echo "camera_file = list(sessions_dir.glob('*-camera.mov'))[0]"
echo "output_csv = camera_file.parent / camera_file.name.replace('-camera.mov', '-eye-tracking.csv')"
echo ""
echo "tracker = eye_tracking.EyeTracker()"
echo "df = tracker.process_video(camera_file, output_csv)"
echo "\""
echo ""
echo "3. Or use Jupyter:"
echo "   jupyter notebook"
echo ""
