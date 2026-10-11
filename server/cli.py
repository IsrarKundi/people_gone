"""
CLI Interface — PeopleGone Phase 0 Worker
Enables local single-image runs and batch processing via command line.
"""

import argparse
import json
import os
import sys
from typing import List, Optional
from worker.pipeline import process

def parse_keep_arg(keep_str: Optional[str]) -> Optional[List[int]]:
    if not keep_str:
        return None
    try:
        return [int(x.strip()) for x in keep_str.split(",") if x.strip()]
    except ValueError:
        print(f"Error: Invalid keeper IDs '{keep_str}'. Expected comma-separated integers.")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(
        description="PeopleGone Phase 0 Worker CLI (Single & Batch Runner)"
    )
    parser.add_argument(
        "--input", "-i", type=str, required=True,
        help="Path to input photo or folder"
    )
    parser.add_argument(
        "--output", "-o", type=str, default="result.jpg",
        help="Path to save result photo"
    )
    parser.add_argument(
        "--keep", "-k", type=str, default=None,
        help="Comma-separated IDs of persons to keep (e.g. '0,1')"
    )
    parser.add_argument(
        "--json", action="store_true",
        help="Print full metadata JSON to stdout"
    )

    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"Error: Input file does not exist: {args.input}")
        sys.exit(1)

    keep_ids = parse_keep_arg(args.keep)

    print(f"Processing photo: {args.input}")
    with open(args.input, "rb") as f:
        photo_bytes = f.read()

    result_bytes, metadata = process(photo_bytes, keep=keep_ids)

    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    with open(args.output, "wb") as f:
        f.write(result_bytes)

    print(f"Result saved to: {args.output}")
    print(f"Dimensions: {metadata['input_dimensions']} -> {metadata['output_dimensions']}")
    print(f"Persons detected: {metadata['persons_detected']} (Kept: {metadata['keeper_ids']}, Removed: {metadata['removed_ids']})")
    print(f"GPU-seconds: {metadata['total_gpu_seconds']}s | Estimated RunPod 16GB Cost: ${metadata['cost_estimate_usd']:.6f}")

    if args.json:
        print("\n--- METADATA JSON ---")
        print(json.dumps(metadata, indent=2))

if __name__ == "__main__":
    main()
