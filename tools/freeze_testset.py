"""
Freezing Script — PeopleGone Phase 0 Test Set
Computes SHA-256 for all 30 photos in testset/photos/ and freezes them in testset/manifest.csv.
"""

import csv
import hashlib
import os
import sys

MANIFEST_PATH = os.path.join(os.path.dirname(__file__), "..", "testset", "manifest.csv")
PHOTOS_DIR = os.path.join(os.path.dirname(__file__), "..", "testset", "photos")

def sha256_file(filepath: str) -> str:
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

def main():
    if not os.path.exists(MANIFEST_PATH):
        print(f"Error: Manifest not found at {MANIFEST_PATH}")
        sys.exit(1)

    with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
        reader = list(csv.DictReader(f))

    fieldnames = reader[0].keys()
    updated_rows = []
    missing_count = 0
    hashed_count = 0

    for row in reader:
        filename = row["filename"]
        photo_path = os.path.join(PHOTOS_DIR, filename)

        if os.path.exists(photo_path):
            computed_hash = sha256_file(photo_path)
            row["sha256"] = computed_hash
            hashed_count += 1
            print(f"Hashed {filename}: {computed_hash[:12]}...")
        else:
            missing_count += 1
            print(f"Missing photo: {filename} in {PHOTOS_DIR}")
        updated_rows.append(row)

    with open(MANIFEST_PATH, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(updated_rows)

    print(f"\nManifest updated: {hashed_count} photos hashed, {missing_count} missing.")
    if missing_count == 0:
        print("SUCCESS: All 30 photos present and frozen with SHA-256!")
    else:
        print(f"NOTE: Drop the remaining {missing_count} photos into testset/photos/ and re-run.")

if __name__ == "__main__":
    main()
