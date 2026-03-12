# Kaggle Training Guide

Training runs are designed to execute independently in separate Kaggle notebooks. PaySim and IEEE-CIS can be run in parallel by different people.

## Prerequisites

Each Kaggle notebook needs:
```
!pip install xgboost scikit-learn pandas numpy joblib
```

## PaySim Training

### Data
- Source: [Synthetic Financial Datasets for Fraud Detection](https://www.kaggle.com/datasets/ealaxi/paysim1) on Kaggle
- Expected file: `PS_20174392719_1491204439457_log.csv`

### Run
1. Upload or link the PaySim dataset
2. Copy `training/kaggle/paysim_notebook.py` into a notebook cell
3. Execute — artifacts export to `/kaggle/working/artifacts/paysim/v1/`
4. Download the `artifacts/` directory

### Quick validation (dry-run)
Set `SAMPLE_ROWS = 500` in the notebook to validate pipeline in ~30 seconds.

## IEEE-CIS Training

### Data
- Source: [IEEE-CIS Fraud Detection](https://www.kaggle.com/competitions/ieee-fraud-detection/data) on Kaggle
- Expected files: `train_transaction.csv`, `train_identity.csv`

### Run
1. Add the IEEE-CIS competition dataset
2. Copy `training/kaggle/ieee_cis_notebook.py` into a notebook cell
3. Execute — artifacts export to `/kaggle/working/artifacts/ieee_cis/v1/`
4. Download the `artifacts/` directory

### Quick validation (dry-run)
Set `SAMPLE_ROWS = 500` in the notebook.

## GPU Notes

- Both pipelines auto-detect GPU: `device="cuda"` if available, else `"cpu"`
- No CUDA or RAPIDS dependency — clean CPU fallback
- Kaggle P100 GPUs work out of the box with XGBoost

## Exporting Artifacts Back to Repo

After training completes:
1. Download the `artifacts/` directory from Kaggle
2. Place versioned artifacts at:
   - `artifacts/paysim/<version>/`
   - `artifacts/ieee_cis/<version>/`
3. The `manifest.json` from each version is automatically copied to:
   - `artifacts/manifests/paysim_latest.json`
   - `artifacts/manifests/ieee_cis_latest.json`
4. The backend's `artifact_loader.py` reads these `*_latest.json` files at startup

## Compatibility Notes

- `training_features` (9 per domain) is a superset of `online_features` (6 MVP)
- The 6 MVP online feature names must remain exact — backend and frontend contracts depend on them
- Extra training features improve model accuracy but are not surfaced in the API response `features` dict
