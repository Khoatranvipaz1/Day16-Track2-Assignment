#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user_data setup for CPU ML benchmark node"

dnf update -y
dnf install -y python3 python3-pip

fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

python3 -m pip install --upgrade pip
python3 -m pip install lightgbm scikit-learn pandas numpy kaggle

mkdir -p /home/ec2-user/ml-benchmark
chown -R ec2-user:ec2-user /home/ec2-user/ml-benchmark

cat > /home/ec2-user/ml-benchmark/benchmark.py <<'PY'
import json
import time
from pathlib import Path

import lightgbm as lgb
import numpy as np
import pandas as pd
from sklearn.metrics import accuracy_score, f1_score, precision_score, recall_score, roc_auc_score
from sklearn.model_selection import train_test_split


DATA_PATH = Path("creditcard.csv")
RESULT_PATH = Path("benchmark_result.json")
RANDOM_STATE = 42
MAX_ROWS = None


def timed(label, fn):
    start = time.perf_counter()
    value = fn()
    elapsed = time.perf_counter() - start
    return value, elapsed


def main():
    if not DATA_PATH.exists():
        raise FileNotFoundError(
            "creditcard.csv not found. Download it first with: "
            "kaggle datasets download -d mlg-ulb/creditcardfraud --unzip -p ~/ml-benchmark/"
        )

    df, load_time = timed("load_data", lambda: pd.read_csv(DATA_PATH))
    if MAX_ROWS and len(df) > MAX_ROWS:
        df = df.sample(n=MAX_ROWS, random_state=RANDOM_STATE)

    x = df.drop(columns=["Class"])
    y = df["Class"]

    x_train, x_test, y_train, y_test = train_test_split(
        x,
        y,
        test_size=0.2,
        random_state=RANDOM_STATE,
        stratify=y,
    )

    scale_pos_weight = float((y_train == 0).sum() / max((y_train == 1).sum(), 1))
    model = lgb.LGBMClassifier(
        objective="binary",
        n_estimators=300,
        learning_rate=0.05,
        num_leaves=31,
        subsample=0.9,
        colsample_bytree=0.9,
        scale_pos_weight=scale_pos_weight,
        random_state=RANDOM_STATE,
        n_jobs=1,
    )

    def train():
        model.fit(
            x_train,
            y_train,
            eval_set=[(x_test, y_test)],
            eval_metric="auc",
            callbacks=[lgb.early_stopping(50), lgb.log_evaluation(50)],
        )
        return model

    _, training_time = timed("training", train)

    proba = model.predict_proba(x_test)[:, 1]
    pred = (proba >= 0.5).astype(int)

    one_row = x_test.iloc[[0]]
    _, latency_time = timed("single_inference", lambda: model.predict_proba(one_row))
    latency_ms = latency_time * 1000

    batch = x_test.iloc[:1000]
    _, batch_time = timed("batch_inference", lambda: model.predict_proba(batch))
    throughput = len(batch) / batch_time

    best_iteration = getattr(model, "best_iteration_", None)
    results = {
        "rows": int(len(df)),
        "note": "CPU fallback benchmark on r5.large.",
        "features": int(x.shape[1]),
        "load_data_seconds": round(load_time, 4),
        "training_seconds": round(training_time, 4),
        "best_iteration": int(best_iteration or model.n_estimators),
        "auc_roc": round(float(roc_auc_score(y_test, proba)), 6),
        "accuracy": round(float(accuracy_score(y_test, pred)), 6),
        "f1_score": round(float(f1_score(y_test, pred, zero_division=0)), 6),
        "precision": round(float(precision_score(y_test, pred, zero_division=0)), 6),
        "recall": round(float(recall_score(y_test, pred, zero_division=0)), 6),
        "inference_latency_1_row_ms": round(latency_ms, 4),
        "inference_throughput_1000_rows_per_second": round(throughput, 2),
    }

    RESULT_PATH.write_text(json.dumps(results, indent=2), encoding="utf-8")

    print("\nLightGBM CPU Benchmark Results")
    print("=" * 32)
    for key, value in results.items():
        print(f"{key}: {value}")
    print(f"\nSaved metrics to {RESULT_PATH}")


if __name__ == "__main__":
    main()
PY

chown ec2-user:ec2-user /home/ec2-user/ml-benchmark/benchmark.py

echo "CPU ML benchmark dependencies installed"
