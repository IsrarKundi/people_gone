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
from typing import Dict, Any, List, Optional

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

    photos_with_native_count = 0
    primary_wins_vs_native = 0

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

            # Head-to-head vs native arms (google or apple) ONLY
            has_native_output = any(
                cand.get("actual_arm") in ("google", "apple")
                for cand in candidates.values()
            )

            if has_native_output:
                photos_with_native_count += 1
                if best_arm == "primary":
                    primary_wins_vs_native += 1

    # Computed rating metrics
    would_post_overall = (primary_would_post_count / primary_evals) if primary_evals > 0 else 0.0
    would_post_simple = (simple_would_post_count / simple_evals) if simple_evals > 0 else 0.0

    native_measured = (photos_with_native_count > 0)
    best_pick_vs_native_pct = (primary_wins_vs_native / photos_with_native_count) if native_measured else None

    # Parse timings & cost — NEVER invent measurements
    median_warm_sec = None
    cost_per_photo = None
    timings_measured = False

    if timings_file and os.path.exists(timings_file):
        import csv
        with open(timings_file, "r", encoding="utf-8") as tf:
            reader = list(csv.DictReader(tf))
            secs = []
            costs = []
            for r in reader:
                s = r.get("total_seconds") or r.get("gpu_seconds")
                if s is not None and s.strip() != "":
                    try:
                        secs.append(float(s))
                    except ValueError:
                        pass
                c = r.get("cost_usd")
                if c is not None and c.strip() != "":
                    try:
                        costs.append(float(c))
                    except ValueError:
                        pass
            if secs:
                secs.sort()
                median_warm_sec = secs[len(secs) // 2]
            if costs:
                cost_per_photo = sum(costs) / len(costs)
            if secs and costs:
                timings_measured = True

    # Criteria evaluation
    pass_wp_overall = (would_post_overall >= THRESH_WOULD_POST_OVERALL)
    pass_wp_simple = (would_post_simple >= THRESH_WOULD_POST_SIMPLE)
    pass_keeper = (keeper_defects_count == THRESH_KEEPER_DEFECTS)

    if native_measured:
        pass_win_tie = (best_pick_vs_native_pct >= THRESH_PRIMARY_WINS_TIES)
    else:
        pass_win_tie = None  # Excluded from GO requirements if not measured

    pass_time = (median_warm_sec <= THRESH_MEDIAN_E2E_SEC) if timings_measured else False
    pass_cost = (cost_per_photo <= THRESH_MAX_COST_PER_PHOTO) if timings_measured else False

    # Check criteria for GO (§3.4)
    # If timings are missing, verdict CANNOT be GO
    all_go = (
        pass_wp_overall and
        pass_wp_simple and
        pass_keeper and
        (pass_win_tie is not False) and
        timings_measured and
        pass_time and
        pass_cost
    )

    # Check criteria for STOP
    stop_condition = (
        would_post_overall < 0.50 or
        (native_measured and best_pick_vs_native_pct < 0.20)
    )

    if all_go:
        verdict = "GO"
        iterate_stage = None
    elif stop_condition:
        verdict = "STOP"
        iterate_stage = None
    else:
        verdict = "ITERATE"
        if not timings_measured:
            iterate_stage = "time/cost not measured (missing or empty timings file)"
        elif not pass_wp_simple or not pass_wp_overall:
            iterate_stage = "inpaint arm (own-pipeline fill swap / diffusion tile for hard crops)"
        elif keeper_defects_count > 0:
            iterate_stage = "detection / keeper heuristic (larger SAM 2.1 checkpoint, tuned weights)"
        elif native_measured and not pass_win_tie:
            iterate_stage = "inpaint arm / edge handling vs native competitors"
        else:
            iterate_stage = "shadow expansion heuristic (§6.4)"

    return {
        "raters_count": total_raters,
        "total_evals": primary_evals,
        "would_post_overall": would_post_overall,
        "pass_wp_overall": pass_wp_overall,
        "would_post_simple": would_post_simple,
        "pass_wp_simple": pass_wp_simple,
        "native_measured": native_measured,
        "photos_with_native": photos_with_native_count,
        "best_pick_vs_native_pct": best_pick_vs_native_pct,
        "pass_win_tie": pass_win_tie,
        "keeper_defects": keeper_defects_count,
        "pass_keeper": pass_keeper,
        "timings_measured": timings_measured,
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

    def mark(passed: Optional[bool]) -> str:
        if passed is None:
            return "[NOT MEASURED]"
        return "[PASS]" if passed else "[FAIL]"

    print(f"{'Metric':<42} | {'Measured':<12} | {'Threshold':<12} | {'Result'}")
    print("-" * 80)
    print(f"{'Overall Would Post %':<42} | {res['would_post_overall']*100:>10.1f}% | {'>= 70.0%':<12} | {mark(res['pass_wp_overall'])}")
    print(f"{'Simple-Background Would Post %':<42} | {res['would_post_simple']*100:>10.1f}% | {'>= 90.0%':<12} | {mark(res['pass_wp_simple'])}")

    # Native metric
    native_str = f"{res['best_pick_vs_native_pct']*100:>10.1f}%" if res["native_measured"] else "NOT MEASURED"
    print(f"{'Best-pick rate vs native arms':<42} | {native_str:<12} | {'>= 40.0%':<12} | {mark(res['pass_win_tie'])}")

    print(f"{'Keeper Damage Critical Defects':<42} | {res['keeper_defects']:>10}   | {'== 0':<12} | {mark(res['pass_keeper'])}")

    # Time and cost metrics
    time_str = f"{res['median_warm_sec']:>9.2f}s" if res["timings_measured"] else "NOT MEASURED"
    time_res = "[PASS]" if (res["timings_measured"] and res["pass_time"]) else ("[NOT MEASURED]" if not res["timings_measured"] else "[FAIL]")
    print(f"{'Median Warm E2E Time':<42} | {time_str:<12} | {'<= 20.0s':<12} | {time_res}")

    cost_str = f"${res['cost_per_photo']:>9.4f}" if res["timings_measured"] else "NOT MEASURED"
    cost_res = "[PASS]" if (res["timings_measured"] and res["pass_cost"]) else ("[NOT MEASURED]" if not res["timings_measured"] else "[FAIL]")
    print(f"{'Measured All-in Cost / Photo':<42} | {cost_str:<12} | {'<= $0.0100':<12} | {cost_res}")
    print("=" * 80)

    if not res["native_measured"]:
        print(">> Note: Native comparison not measured — no Google/Apple outputs in this run.")

    print(f"\nFINAL VERDICT: {res['verdict']}")
    if res['verdict'] == "GO":
        print(">> Proceed to Phase 1: Scaffold Flutter app on primary pipeline.")
    elif res['verdict'] == "ITERATE":
        print(f">> Outcome: ITERATE. Reason/stage: {res['iterate_stage']}.")
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
