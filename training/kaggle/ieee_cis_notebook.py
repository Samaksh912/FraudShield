"""IEEE-CIS Kaggle Notebook Script

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
TXN_PATH = "/kaggle/input/ieee-fraud-detection/train_transaction.csv"
IDENTITY_PATH = "/kaggle/input/ieee-fraud-detection/train_identity.csv"
OUTPUT_DIR = "/kaggle/working/artifacts"
ARTIFACT_VERSION = "v1"

# === SETUP PATH ===
repo_root = Path(".").resolve()
if str(repo_root) not in sys.path:
    sys.path.insert(0, str(repo_root))

# === TRAIN ===
from training.ieee_cis.train_supervised import train_ieee_xgboost

result_dir = train_ieee_xgboost(
    TXN_PATH,
    OUTPUT_DIR,
    identity_path=IDENTITY_PATH,
    artifact_version=ARTIFACT_VERSION,
    sample_rows=SAMPLE_ROWS,
    n_estimators=300,
    max_depth=6,
    learning_rate=0.1,
    run_anomaly=False,
)

print(f"\nArtifacts written to: {result_dir}")
print("Download the artifacts/ directory from Kaggle output.")
