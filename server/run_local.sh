#!/usr/bin/env bash
set -euo pipefail

# PeopleGone Phase 0 - Local Worker Run Script
# Usage: ./run_local.sh [photo_path] [output_path] [keep_ids]

PHOTO_IN="${1:-test_photo.jpg}"
PHOTO_OUT="${2:-result.jpg}"
KEEP_IDS="${3:-}"

echo "=== PeopleGone Phase 0 Worker (Local Run) ==="
echo "Input: $PHOTO_IN"
echo "Output: $PHOTO_OUT"

if [ -n "$KEEP_IDS" ]; then
    python3 cli.py --input "$PHOTO_IN" --output "$PHOTO_OUT" --keep "$KEEP_IDS"
else
    python3 cli.py --input "$PHOTO_IN" --output "$PHOTO_OUT"
fi
