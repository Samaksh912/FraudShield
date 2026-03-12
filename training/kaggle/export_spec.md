# Export Spec

Expected files per domain version:

- `supervised_model.joblib` — XGBoost binary classifier
- `anomaly_model.joblib` — optional Isolation Forest
- `feature_order.json` — ordered list of feature names used by the model
- `feature_defaults.json` — default values for each feature (used at inference for missing data)
- `thresholds.json` — dual threshold sets (level + decision)
- `metrics.json` — precision, recall, F1, PR-AUC, confusion matrix
- `metadata.json` — training metadata (data source, hyperparameters, export time)
- `manifest.json` — the canonical manifest read by the backend

## Directory Example

```
artifacts/
├── manifests/
│   ├── paysim_latest.json          ← backend reads this
│   └── ieee_cis_latest.json        ← backend reads this
├── paysim/
│   └── v1/
│       ├── supervised_model.joblib
│       ├── feature_order.json
│       ├── feature_defaults.json
│       ├── thresholds.json
│       ├── metrics.json
│       ├── metadata.json
│       └── manifest.json
└── ieee_cis/
    └── v1/
        ├── supervised_model.joblib
        ├── anomaly_model.joblib    ← optional
        ├── feature_order.json
        ├── feature_defaults.json
        ├── thresholds.json
        ├── metrics.json
        ├── metadata.json
        └── manifest.json
```

## Threshold Format

`thresholds.json` contains two threshold sets:

```json
{
  "level": {
    "low_to_medium": 0.4,
    "medium_to_high": 0.75
  },
  "decision": {
    "allow_to_review": 0.4,
    "review_to_block": 0.9
  }
}
```

## Compatibility

- `training_features` may be broader than `online_features`
- The 6 MVP online features must keep exact names across training and serving
- `manifest.json` schema matches `training.common.artifact_manifest.ArtifactManifest`
- Backend `artifact_loader.py` reads `artifacts/manifests/<domain>_latest.json`
