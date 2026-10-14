"""Reflection warnings (Phase D, FR-09): detect + warn only.

Reflections are never items and never auto-removed in v1 (design
X12–X14; requirements §15 D11). This module decides whether a
removed person probably left a visible reflection behind, so the
Result screen can say so and route the user to the brush.

Two independent signals, either of which can raise a warning. Both
were frozen against the Phase D investigation set
(docs/architecture/phase-d-investigation.md §4) before shipping:

A. Candidate boxes. The open-vocab detector, prompted for
   reflections of people, sometimes boxes the reflection itself.
   That prompt also re-fires on direct people almost everywhere, so
   a box counts only when it does NOT coincide with any detected
   person, lies inside a detected reflective surface, associates
   geometrically to a REMOVED person, and does not associate to any
   keeper (absolute keeper veto). A candidate that is itself a
   detected person needs no warning: the main pass removes it.

B. Flip match. Horizontal-surface reflections (water, puddles,
   glossy floors) are flipped smears a person detector misses. For
   each removed person standing at a horizontal reflective region,
   the person's own box, flipped vertically, is template-matched
   (normalized cross-correlation) in the strip below their feet.
   A match at/above FLIP_SCORE_THRESHOLD starting at the feet line
   is evidence. Persons shorter than MIN_PERSON_HEIGHT_FRAC of the
   image height are skipped: tiny templates match noise.

Warnings attach to removed people only. A reflection with no
removed person to belong to (the photographer's own, a stranger
seen in glass) never warns.
"""

import cv2
import numpy as np

# Prompts for the two extra open-vocab passes /process runs when
# somebody is being removed. Labels come back lowercased.
SURFACE_PROMPTS = [
    "mirror", "window", "glass window", "shop window", "car",
    "puddle", "water", "polished floor", "glossy floor",
]
REFLECTION_PROMPTS = [
    "reflection of a person", "person reflection",
    "reflected person", "person in mirror",
]

HORIZONTAL_SURFACE_LABELS = {"water", "puddle", "polished floor", "glossy floor"}
VERTICAL_SURFACE_LABELS = {
    "mirror", "window", "glass window", "shop window", "car",
}

SURFACE_SCORE_MIN = 0.30           # signal A host surface
REFLECTION_CANDIDATE_SCORE_MIN = 0.30
SURFACE_SCORE_MIN_FLIP = 0.35      # signal B host surface
FLIP_SCORE_THRESHOLD = 0.50        # frozen §4: midpoint of the
                                   # observed 0.424–0.567 gap
MIN_PERSON_HEIGHT_FRAC = 0.08
FLIP_SCALES = (1.0, 0.7, 0.5, 0.35)


def _iou(a, b):
    xa, ya = max(a[0], b[0]), max(a[1], b[1])
    xb, yb = min(a[2], b[2]), min(a[3], b[3])
    inter = max(0, xb - xa) * max(0, yb - ya)
    union = ((a[2] - a[0]) * (a[3] - a[1])
             + (b[2] - b[0]) * (b[3] - b[1]) - inter)
    return inter / union if union > 0 else 0.0


def _containment(inner, outer):
    xa, ya = max(inner[0], outer[0]), max(inner[1], outer[1])
    xb, yb = min(inner[2], outer[2]), min(inner[3], outer[3])
    inter = max(0, xb - xa) * max(0, yb - ya)
    area = (inner[2] - inner[0]) * (inner[3] - inner[1])
    return inter / area if area > 0 else 0.0


def _dedupe(dets, thr=0.5):
    kept = []
    for d in sorted(dets, key=lambda d: -d["score"]):
        if any(_iou(d["box"], k["box"]) >= thr for k in kept):
            continue
        kept.append(d)
    return kept


def _coincides_with_person(box, persons):
    for p in persons:
        if (
            _iou(box, p["box"]) >= 0.4
            or _containment(box, p["box"]) >= 0.6
            or _containment(p["box"], box) >= 0.6
        ):
            return True
    return False


def _orientation(label):
    if label in HORIZONTAL_SURFACE_LABELS:
        return "h"
    if label in VERTICAL_SURFACE_LABELS:
        return "v"
    return None


def _associates(cand, person_box, orient):
    cx1, cy1, cx2, cy2 = cand
    px1, py1, px2, py2 = person_box
    cw, ch = cx2 - cx1, cy2 - cy1
    pw, ph = px2 - px1, py2 - py1
    if cw <= 0 or ch <= 0 or pw <= 0 or ph <= 0:
        return False
    if orient == "v":
        y_overlap = max(0, min(cy2, py2) - max(cy1, py1))
        if y_overlap / min(ch, ph) < 0.4:
            return False
        gap = max(0, max(cx1 - px2, px1 - cx2))
        if gap > 0.75 * pw:
            return False
        return 0.3 <= ch / ph <= 1.8
    if cy1 < py2 - 0.15 * ph:
        return False
    if cy2 > py2 + 1.3 * ph:
        return False
    x_overlap = max(0, min(cx2, px2) - max(cx1, px1))
    if x_overlap < 0.3 * min(cw, pw):
        return False
    return ch <= 1.2 * ph


def _candidate_warnings(persons_by_id, keeper_ids, removed_ids,
                        surfaces, reflection_dets):
    hosts = [s for s in surfaces if s["score"] >= SURFACE_SCORE_MIN]
    cands = _dedupe(
        [d for d in reflection_dets
         if d["score"] >= REFLECTION_CANDIDATE_SCORE_MIN]
    )
    all_persons = list(persons_by_id.values())
    warnings = []
    for cand in cands:
        box = cand["box"]
        if _coincides_with_person(box, all_persons):
            continue
        host = None
        for s in hosts:
            orient = _orientation(s["label"])
            if orient and _containment(box, s["box"]) >= 0.5:
                host = (s, orient)
                break
        if host is None:
            continue
        surface, orient = host
        hit_removed = [
            pid for pid in removed_ids
            if pid in persons_by_id
            and _associates(box, persons_by_id[pid]["box"], orient)
        ]
        hit_keeper = [
            pid for pid in keeper_ids
            if pid in persons_by_id
            and _associates(box, persons_by_id[pid]["box"], orient)
        ]
        if hit_removed and not hit_keeper:
            warnings.append({
                "person_id": hit_removed[0],
                "box": [int(v) for v in box],
                "surface": surface["label"],
                "kind": "candidate",
                "score": round(float(cand["score"]), 3),
            })
    return warnings


def _flip_match(gray, person_box, surface_box):
    """Best NCC of the person's flipped box below their feet.

    Returns (score, match_box) or (None, None)."""
    height, width = gray.shape
    px1, py1, px2, py2 = [int(v) for v in person_box]
    pw, ph = px2 - px1, py2 - py1
    if pw < 12 or ph < 24:
        return None, None
    sx1, sy1, sx2, sy2 = [int(v) for v in surface_box]
    if not (sy1 - 0.05 * height <= py2 <= sy2):
        return None, None
    win_x1 = max(0, sx1, int(px1 - 0.3 * pw))
    win_x2 = min(width, sx2, int(px2 + 0.3 * pw))
    win_y1 = max(0, int(py2 - 0.05 * ph))
    win_y2 = min(height, sy2, int(py2 + 1.05 * ph))
    if win_x2 - win_x1 < pw * 0.8 or win_y2 - win_y1 < ph * 0.3:
        return None, None
    window = gray[win_y1:win_y2, win_x1:win_x2]
    template = cv2.flip(gray[py1:py2, px1:px2], 0)
    best, best_box = None, None
    for scale in FLIP_SCALES:
        th = int(ph * scale)
        if th < 10 or th > window.shape[0]:
            continue
        tpl = cv2.resize(template, (pw, th), interpolation=cv2.INTER_AREA)
        if tpl.shape[1] > window.shape[1] or tpl.shape[0] > window.shape[0]:
            continue
        res = cv2.matchTemplate(window, tpl, cv2.TM_CCOEFF_NORMED)
        _, maxv, _, maxloc = cv2.minMaxLoc(res)
        top_y = win_y1 + maxloc[1]
        if top_y - py2 > 0.25 * ph:
            continue
        if best is None or maxv > best:
            best = float(maxv)
            best_box = [win_x1 + maxloc[0], top_y,
                        win_x1 + maxloc[0] + pw, top_y + th]
    return best, best_box


def _flip_warnings(gray, persons_by_id, removed_ids, surfaces):
    height = gray.shape[0]
    hosts = [
        s for s in surfaces
        if s["score"] >= SURFACE_SCORE_MIN_FLIP
        and _orientation(s["label"]) == "h"
    ]
    warnings = []
    for pid in removed_ids:
        person = persons_by_id.get(pid)
        if person is None:
            continue
        box = person["box"]
        if (box[3] - box[1]) < MIN_PERSON_HEIGHT_FRAC * height:
            continue
        best, best_box, best_surface = None, None, None
        for s in hosts:
            score, match_box = _flip_match(gray, box, s["box"])
            if score is not None and (best is None or score > best):
                best, best_box, best_surface = score, match_box, s["label"]
        if best is not None and best >= FLIP_SCORE_THRESHOLD:
            warnings.append({
                "person_id": pid,
                "box": [int(v) for v in best_box],
                "surface": best_surface,
                "kind": "flip",
                "score": round(float(best), 3),
            })
    return warnings


def reflection_warnings(persons, keeper_ids, removed_ids,
                        surface_dets, reflection_dets, gray):
    """All reflection warnings for one job.

    persons: [{"id", "box"}] for every detected person.
    surface_dets / reflection_dets: [{"label", "score", "box"}].
    gray: HxW uint8 grayscale of the original photo.
    Returns a list of warning dicts (possibly empty).
    """
    if not removed_ids:
        return []
    persons_by_id = {p["id"]: p for p in persons}
    warnings = _candidate_warnings(
        persons_by_id, keeper_ids, removed_ids,
        surface_dets, reflection_dets,
    )
    warned = {w["person_id"] for w in warnings}
    for w in _flip_warnings(gray, persons_by_id, removed_ids, surface_dets):
        if w["person_id"] not in warned:
            warnings.append(w)
            warned.add(w["person_id"])
    return warnings
