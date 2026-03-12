"""PaySim Kaggle Notebook Script

Copy this entire file into a Kaggle notebook cell and run.
Does NOT import from app/ — fully self-contained with training/ modules.

Prerequisites:
  !pip install xgboost scikit-learn pandas numpy joblib
"""

import sys
from pathlib import Path

# === CONFIGURATION ===
# Set to None for full training, or a small number (e.g. 500) for dry-run
SAMPLE_ROWS = None

# Kaggle paths — adjust if your dataset mount point differs
DATA_PATH = "/kaggle/input/paysim1/PS_20174392719_1491204439457_log.csv"
OUTPUT_DIR = "/kaggle/working/artifacts"
ARTIFACT_VERSION = "v1"

# === SETUP PATH ===
# If running from repo root (local dev), add it to path
repo_root = Path(".").resolve()
if str(repo_root) not in sys.path:
    sys.path.insert(0, str(repo_root))

# === TRAIN ===
from training.paysim.train_supervised import train_paysim_xgboost

result_dir = train_paysim_xgboost(
    DATA_PATH,
    OUTPUT_DIR,
    artifact_version=ARTIFACT_VERSION,
    sample_rows=SAMPLE_ROWS,
    n_estimators=300,
    max_depth=6,
    learning_rate=0.1,
    run_anomaly=False,
)

print(f"\nArtifacts written to: {result_dir}")
print("Download the artifacts/ directory from Kaggle output.")
