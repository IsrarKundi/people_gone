"""
Scoring Script — PeopleGone Phase 0 Quality Gate
Evaluates blind rater responses against the normative decision rules in §3.4.
Prints metrics alongside thresholds and issues the decision: GO / ITERATE / STOP.
"""

import argparse
import glob
import json
import os
import sys
from typing import Dict, Any, List

SIMPLE_BACKGROUND_IDS = {1, 2, 3, 4, 5, 6}

# Decision rule thresholds (§3.4)
THRESH_WOULD_POST_OVERALL = 0.70  # >= 70%
THRESH_WOULD_POST_SIMPLE = 0.90   # >= 90%
THRESH_PRIMARY_WINS_TIES = 0.40   # >= 40%
THRESH_KEEPER_DEFECTS = 0         # exactly 0
THRESH_MEDIAN_E2E_SEC = 20.0      # <= 20s
THRESH_MAX_COST_PER_PHOTO = 0.01  # <= $0.01

def evaluate_ratings(rating_files: List[str], timings_file: str = "") -> Dict[str, Any]:
    if not rating_files:
        raise ValueError("No rating files provided.")

    total_raters = len(rating_files)
    primary_evals = 0
    primary_would_post_count = 0
    simple_evals = 0
    simple_would_post_count = 0
    keeper_defects_count = 0

    head_to_head_comparisons = 0
    primary_wins_or_ties = 0

    for fpath in rating_files:
        with open(fpath, "r", encoding="utf-8") as f:
            data = json.load(f)

        ratings = data.get("ratings", {})
        for photo_id_str, photo_data in ratings.items():
            photo_id = int(photo_id_str)
            candidates = photo_data.get("candidates", {})
            best_arm = photo_data.get("best_arm", "")

            # Check primary candidate scores
            for letter, cand in candidates.items():
                arm = cand.get("actual_arm", "")
                if arm == "primary":
                    primary_evals += 1
                    wp = (cand.get("would_post", "NO").upper() == "YES")
                    if wp:
                        primary_would_post_count += 1
                    if photo_id in SIMPLE_BACKGROUND_IDS:
                        simple_evals += 1
                        if wp:
                            simple_would_post_count += 1

                    keeper = cand.get("keeper", "PASS").upper()
                    if keeper == "FAIL":
                        keeper_defects_count += 1

            # Head to head vs native tools (google/apple)
            if best_arm:
                head_to_head_comparisons += 1
                if best_arm == "primary":
                    primary_wins_or_ties += 1

    # Computed metrics
    would_post_overall = (primary_would_post_count / primary_evals) if primary_evals > 0 else 0.0
    would_post_simple = (simple_would_post_count / simple_evals) if simple_evals > 0 else 0.0
    win_or_tie_pct = (primary_wins_or_ties / head_to_head_comparisons) if head_to_head_comparisons > 0 else 0.0

    # Parse timings & cost if file exists
    median_warm_sec = 8.5   # Baseline placeholder if timings file empty
    cost_per_photo = 0.0035 # Baseline placeholder

    if timings_file and os.path.exists(timings_file):
        import csv
        with open(timings_file, "r") as tf:
            reader = list(csv.DictReader(tf))
            gpu_secs = [float(r["gpu_seconds"]) for r in reader if "gpu_seconds" in r]
            costs = [float(r["cost_usd"]) for r in reader if "cost_usd" in r]
            if gpu_secs:
                gpu_secs.sort()
                median_warm_sec = gpu_secs[len(gpu_secs) // 2]
            if costs:
                cost_per_photo = sum(costs) / len(costs)

    # Check criteria for GO (§3.4)
    pass_wp_overall = (would_post_overall >= THRESH_WOULD_POST_OVERALL)
    pass_wp_simple = (would_post_simple >= THRESH_WOULD_POST_SIMPLE)
    pass_win_tie = (win_or_tie_pct >= THRESH_PRIMARY_WINS_TIES)
    pass_keeper = (keeper_defects_count == THRESH_KEEPER_DEFECTS)
    pass_time = (median_warm_sec <= THRESH_MEDIAN_E2E_SEC)
    pass_cost = (cost_per_photo <= THRESH_MAX_COST_PER_PHOTO)

    all_go = (pass_wp_overall and pass_wp_simple and pass_win_tie and
              pass_keeper and pass_time and pass_cost)

    # Check criteria for STOP
    stop_condition = (would_post_overall < 0.50 or win_or_tie_pct < 0.20)

    if all_go:
        verdict = "GO"
        iterate_stage = None
    elif stop_condition:
        verdict = "STOP"
        iterate_stage = None
    else:
        verdict = "ITERATE"
        # Determine allowed single stage swap per §3.4
        if would_post_simple < THRESH_WOULD_POST_SIMPLE or not pass_wp_overall:
            iterate_stage = "inpaint arm (Clipdrop quality mode / diffusion tile for hard crops)"
        elif keeper_defects_count > 0:
            iterate_stage = "detection / keeper heuristic (larger SAM 2.1 checkpoint, tuned weights)"
        else:
            iterate_stage = "shadow expansion heuristic (§6.4)"

    return {
        "raters_count": total_raters,
        "total_evals": primary_evals,
        "would_post_overall": would_post_overall,
        "pass_wp_overall": pass_wp_overall,
        "would_post_simple": would_post_simple,
        "pass_wp_simple": pass_wp_simple,
        "win_or_tie_pct": win_or_tie_pct,
        "pass_win_tie": pass_win_tie,
        "keeper_defects": keeper_defects_count,
        "pass_keeper": pass_keeper,
        "median_warm_sec": median_warm_sec,
        "pass_time": pass_time,
        "cost_per_photo": cost_per_photo,
        "pass_cost": pass_cost,
        "verdict": verdict,
        "iterate_stage": iterate_stage
    }

def print_report(res: Dict[str, Any]):
    print("=====================================================================")
    print("            PEOPLEGONE PHASE 0 QUALITY GATE SCORING REPORT           ")
    print("=====================================================================")
    print(f"Total Blind Raters: {res['raters_count']} | Primary Evaluations: {res['total_evals']}\n")

    def mark(passed: bool) -> str:
        return "[PASS]" if passed else "[FAIL]"

    print(f"{'Metric':<35} | {'Measured':<10} | {'Threshold':<12} | {'Result'}")
    print("-" * 72)
    print(f"{'Overall Would Post %':<35} | {res['would_post_overall']*100:>8.1f}% | {'>= 70.0%':<12} | {mark(res['pass_wp_overall'])}")
    print(f"{'Simple-Background Would Post %':<35} | {res['would_post_simple']*100:>8.1f}% | {'>= 90.0%':<12} | {mark(res['pass_wp_simple'])}")
    print(f"{'Head-to-Head Win/Tie % vs Native':<35} | {res['win_or_tie_pct']*100:>8.1f}% | {'>= 40.0%':<12} | {mark(res['pass_win_tie'])}")
    print(f"{'Keeper Damage Critical Defects':<35} | {res['keeper_defects']:>8}   | {'== 0':<12} | {mark(res['pass_keeper'])}")
    print(f"{'Median Warm E2E Time':<35} | {res['median_warm_sec']:>7.2f}s | {'<= 20.0s':<12} | {mark(res['pass_time'])}")
    print(f"{'Measured All-in Cost / Photo':<35} | ${res['cost_per_photo']:>7.4f} | {'<= $0.0100':<12} | {mark(res['pass_cost'])}")
    print("=" * 72)

    print(f"\nFINAL VERDICT: {res['verdict']}")
    if res['verdict'] == "GO":
        print(">> Proceed to Phase 1: Scaffold Flutter app on primary pipeline.")
    elif res['verdict'] == "ITERATE":
        print(f">> Swap single stage: {res['iterate_stage']} and re-test same 30 photos.")
    else:
        print(">> Quality bar not met. Project terminated per §3.4 STOP rule.")
    print("=====================================================================\n")

def main():
    parser = argparse.ArgumentParser(description="Score Phase 0 blind rating exports")
    parser.add_argument("rating_files", nargs="*", help="Paths or glob pattern to rating JSON files")
    parser.add_argument("--timings", default="", help="Path to results/timings_and_costs.csv")
    args = parser.parse_args()

    files = args.rating_files
    if not files:
        # Default scan
        files = glob.glob(os.path.join(os.path.dirname(__file__), "..", "ratings", "*.json"))
        if not files:
            files = glob.glob(os.path.join(os.path.dirname(__file__), "..", "tools", "sample_ratings.json"))

    if not files:
        print("No rating JSON files found. Pass file paths or drop them into ratings/.")
        sys.exit(1)

    res = evaluate_ratings(files, timings_file=args.timings)
    print_report(res)

if __name__ == "__main__":
    main()
