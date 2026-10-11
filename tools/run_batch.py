"""
Batch Runner — PeopleGone Phase 0
Runs the worker prototype and Clipdrop comparison arm across the frozen test set.
Saves results at native resolution under results/<arm>/<id>.jpg + timings_and_costs.csv.
"""

import csv
import os
import sys
import time
from typing import Dict, Any, List

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "server"))

from worker.pipeline import process
from clipdrop_arm import ClipdropClient

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MANIFEST_PATH = os.path.join(ROOT_DIR, "testset", "manifest.csv")
PHOTOS_DIR = os.path.join(ROOT_DIR, "testset", "photos")
RESULTS_PRIMARY_DIR = os.path.join(ROOT_DIR, "results", "primary")
RESULTS_CLIPDROP_DIR = os.path.join(ROOT_DIR, "results", "clipdrop")
TIMINGS_CSV_PATH = os.path.join(ROOT_DIR, "results", "timings_and_costs.csv")

def run_batch():
    os.makedirs(RESULTS_PRIMARY_DIR, exist_ok=True)
    os.makedirs(RESULTS_CLIPDROP_DIR, exist_ok=True)

    if not os.path.exists(MANIFEST_PATH):
        print(f"Error: Manifest not found at {MANIFEST_PATH}")
        sys.exit(1)

    with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    clipdrop_client = ClipdropClient()
    timing_records: List[Dict[str, Any]] = []

    print(f"=== Starting PeopleGone Phase 0 Batch Run ({len(rows)} photos) ===")

    processed_count = 0
    missing_count = 0

    for row in rows:
        photo_id = row["id"]
        filename = row["filename"]
        photo_path = os.path.join(PHOTOS_DIR, filename)

        if not os.path.exists(photo_path):
            missing_count += 1
            continue

        print(f"\nProcessing [{photo_id}/30] {filename} ({row['category']})...")
        with open(photo_path, "rb") as f:
            photo_bytes = f.read()

        # 1. Primary pipeline arm
        t0 = time.perf_counter()
        primary_bytes, metadata = process(photo_bytes)
        primary_elapsed = time.perf_counter() - t0

        primary_out_path = os.path.join(RESULTS_PRIMARY_DIR, f"{photo_id}.jpg")
        with open(primary_out_path, "wb") as f:
            f.write(primary_bytes)

        # 2. Clipdrop comparison arm (mock or live)
        # Using PIL to array
        import numpy as np
        from PIL import Image
        import io

        orig_pil = Image.open(io.BytesIO(photo_bytes)).convert("RGB")
        orig_np = np.array(orig_pil)
        # Dummy/reused mask for dry run
        dummy_mask = np.zeros(orig_np.shape[:2], dtype=np.uint8)
        dummy_mask[int(orig_np.shape[0]*0.2):int(orig_np.shape[0]*0.5), int(orig_np.shape[1]*0.6):int(orig_np.shape[1]*0.8)] = 255

        t0_cd = time.perf_counter()
        cd_np, cd_meta = clipdrop_client.cleanup(orig_np, dummy_mask)
        cd_elapsed = time.perf_counter() - t0_cd

        clipdrop_out_path = os.path.join(RESULTS_CLIPDROP_DIR, f"{photo_id}.jpg")
        Image.fromarray(cd_np).save(clipdrop_out_path, format="JPEG", quality=95)

        record = {
            "id": photo_id,
            "filename": filename,
            "category": row["category"],
            "input_w": metadata["input_dimensions"][0],
            "input_h": metadata["input_dimensions"][1],
            "output_w": metadata["output_dimensions"][0],
            "output_h": metadata["output_dimensions"][1],
            "persons_detected": metadata["persons_detected"],
            "gpu_seconds": metadata["total_gpu_seconds"],
            "cost_usd": metadata["cost_estimate_usd"],
            "primary_e2e_sec": round(primary_elapsed, 3),
            "clipdrop_e2e_sec": round(cd_elapsed, 3),
            "ghost_check_fired": metadata["ghost_check_fired"],
            "retry_count": metadata["retry_count"]
        }
        timing_records.append(record)
        processed_count += 1
        print(f"  -> Primary: {metadata['total_gpu_seconds']}s (${metadata['cost_estimate_usd']:.6f}) | Saved to {primary_out_path}")

    # Write timings CSV if any photos were processed
    if timing_records:
        fieldnames = list(timing_records[0].keys())
        with open(TIMINGS_CSV_PATH, "w", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(timing_records)
        print(f"\nBatch run complete: {processed_count} photos processed.")
        print(f"Timings & cost log written to: {TIMINGS_CSV_PATH}")
    else:
        print(f"\nNo test photos found in {PHOTOS_DIR} ({missing_count} missing).")
        print("Drop photos into testset/photos/ and run tools/run_batch.py.")

if __name__ == "__main__":
    run_batch()
