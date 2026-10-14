"""
Belongings tiering — synthetic-mask geometry tests (Phase A, FR-08).

Pure numpy: no models are loaded. The cases mirror the Phase A
investigation's named scenarios (docs/architecture/
phase-a-investigation.md §3-§5) at toy scale:

  worn backpack            -> attached to its wearer
  held bag                 -> attached to its holder
  keeper's bag, graze      -> a sub-bar graze of a removed person's
                              halo does NOT steal the keeper's bag
  keeper veto              -> a real touch of the keeper's own mask
                              demotes a would-be attachment to a
                              removed person to ambiguous
  bag touching two people  -> ambiguous by construction
  ground item, no contact  -> ambiguous (X10: the user decides)
  duplicate detections     -> merged before tiering (box + mask level)

Run:  cd modal-deploy/server && python -m unittest discover -s tests -t .
"""

import unittest

import numpy as np

from worker.belongings import (
    merge_duplicate_items,
    person_halo,
    tier_belongings,
)
from worker.detector import dedupe_detections

CANVAS = (400, 600)  # (h, w)


def mask_of(*rects):
    """uint8 mask with the given (x1, y1, x2, y2) rects filled."""
    m = np.zeros(CANVAS, dtype=np.uint8)
    for x1, y1, x2, y2 in rects:
        m[y1:y2, x1:x2] = 255
    return m


def person(pid, box):
    return {"id": pid, "box": box, "score": 0.9, "label": "person"}


def item(iid, box, label="handbag", score=0.9):
    return {"id": iid, "box": box, "score": score, "label": label}


def tier_one(persons, person_masks, keepers, items, item_masks):
    results = tier_belongings(persons, person_masks, set(keepers), items, item_masks)
    assert len(results) == 1
    return results[0]


class TestTiering(unittest.TestCase):
    def test_worn_backpack_attaches_to_wearer(self):
        # Person mask fills most of the box; backpack sits inside it.
        p = person(0, [100, 50, 200, 350])
        p_mask = mask_of((120, 80, 180, 320))
        bag = item(0, [130, 120, 175, 220], label="backpack")
        bag_mask = mask_of((130, 120, 175, 220))
        r = tier_one([p], [p_mask], keepers=[], items=[bag], item_masks=[bag_mask])
        self.assertEqual(r["tier"], "attached")
        self.assertEqual(r["person_id"], 0)

    def test_held_bag_attaches_via_halo(self):
        # Bag hangs just outside the body mask but inside the halo.
        p = person(0, [100, 50, 200, 350])
        p_mask = mask_of((120, 80, 180, 320))
        bag = item(0, [184, 200, 230, 280])
        bag_mask = mask_of((184, 200, 230, 280))
        r = tier_one([p], [p_mask], keepers=[], items=[bag], item_masks=[bag_mask])
        self.assertEqual(r["tier"], "attached")
        self.assertEqual(r["person_id"], 0)

    def test_keepers_bag_survives_removed_neighbours_graze(self):
        # The investigation's critical case 2, in miniature: the
        # keeper's bag overlaps the keeper's halo hugely and grazes
        # the removed person's halo by a few dozen px (below the
        # de-minimis floor) -> still attaches to the KEEPER.
        keeper = person(0, [40, 50, 140, 350])
        keeper_mask = mask_of((60, 80, 130, 320))
        removed = person(1, [164, 50, 264, 350])
        removed_mask = mask_of((184, 80, 254, 320))
        # Bag hangs on the keeper (halo overlap 78x170) and grazes the
        # removed person's halo by 3 px (510 px < bar of 663 px).
        bag = item(0, [60, 150, 179, 320])
        bag_mask = mask_of((60, 150, 179, 320))
        r = tier_one(
            [keeper, removed], [keeper_mask, removed_mask],
            keepers=[0], items=[bag], item_masks=[bag_mask],
        )
        self.assertEqual(r["tier"], "attached")
        self.assertEqual(r["person_id"], 0)

    def test_keeper_veto_demotes_to_ambiguous(self):
        # A big item mostly against a REMOVED person (halo overlap far
        # above the bar) but with a thin tab physically touching the
        # KEEPER's own mask: the veto fires -> ambiguous, never
        # attached to the removed person (the hard gate).
        keeper = person(0, [100, 50, 200, 350])
        keeper_mask = mask_of((110, 80, 200, 320))
        removed = person(1, [400, 50, 500, 350])
        removed_mask = mask_of((410, 80, 490, 320))
        # Main body against the removed person + thin tab to the keeper.
        bag_mask = mask_of((380, 200, 470, 290), (195, 240, 380, 250))
        bag = item(0, [195, 200, 470, 290], label="suitcase")
        r = tier_one(
            [keeper, removed], [keeper_mask, removed_mask],
            keepers=[0], items=[bag], item_masks=[bag_mask],
        )
        self.assertEqual(r["tier"], "ambiguous")
        self.assertIsNone(r["person_id"])

    def test_bag_touching_two_people_is_ambiguous(self):
        p0 = person(0, [60, 50, 160, 350])
        m0 = mask_of((80, 80, 150, 320))
        p1 = person(1, [220, 50, 320, 350])
        m1 = mask_of((240, 80, 310, 320))
        # Bag hangs between them, overlapping both halos well above bar.
        bag = item(0, [140, 200, 250, 270])
        bag_mask = mask_of((140, 200, 250, 270))
        r = tier_one(
            [p0, p1], [m0, m1], keepers=[0], items=[bag], item_masks=[bag_mask]
        )
        self.assertEqual(r["tier"], "ambiguous")

    def test_ground_item_without_contact_is_ambiguous(self):
        p = person(0, [100, 50, 200, 300])
        p_mask = mask_of((115, 70, 185, 290))
        suitcase = item(0, [300, 280, 370, 350], label="suitcase")
        suitcase_mask = mask_of((300, 280, 370, 350))
        r = tier_one(
            [p], [p_mask], keepers=[], items=[suitcase],
            item_masks=[suitcase_mask],
        )
        self.assertEqual(r["tier"], "ambiguous")

    def test_no_persons_everything_ambiguous(self):
        bag = item(0, [10, 10, 60, 60])
        bag_mask = mask_of((10, 10, 60, 60))
        results = tier_belongings([], [], set(), [bag], [bag_mask])
        self.assertEqual(results[0]["tier"], "ambiguous")


class TestDedupe(unittest.TestCase):
    def test_detector_box_dedupe_keeps_highest_score(self):
        dets = [
            {"box": [100, 100, 200, 300], "score": 0.80, "label": "person"},
            {"box": [104, 102, 203, 298], "score": 0.92, "label": "person"},
            {"box": [400, 100, 460, 300], "score": 0.70, "label": "person"},
        ]
        out = dedupe_detections(dets)
        self.assertEqual(len(out), 2)
        self.assertEqual(out[0]["score"], 0.92)  # winner, first position
        self.assertEqual(out[1]["box"], [400, 100, 460, 300])

    def test_mask_merge_of_duplicate_items(self):
        # Same physical backpack fired twice (class split, as measured
        # on the bench photo): masks overlap heavily -> one item,
        # higher-score entry wins, mask is the union.
        a = item(0, [100, 100, 180, 200], label="handbag", score=0.70)
        b = item(1, [105, 95, 185, 205], label="backpack", score=0.40)
        ma = mask_of((100, 100, 180, 200))
        mb = mask_of((105, 95, 185, 205))
        items, masks = merge_duplicate_items([a, b], [ma, mb])
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["label"], "handbag")
        self.assertEqual(int((masks[0] > 0).sum()), int(((np.maximum(ma, mb)) > 0).sum()))

    def test_distinct_items_not_merged(self):
        a = item(0, [50, 50, 90, 90], score=0.9)
        b = item(1, [300, 50, 340, 90], score=0.8)
        ma = mask_of((50, 50, 90, 90))
        mb = mask_of((300, 50, 340, 90))
        items, _ = merge_duplicate_items([a, b], [ma, mb])
        self.assertEqual(len(items), 2)


class TestHalo(unittest.TestCase):
    def test_halo_matches_mask_prep_formula(self):
        # Dilation = max(8, 2% of box height): box height 300 -> 8 px,
        # so the halo's extent grows by exactly 8 px on every side
        # (the ellipse kernel rounds the corners, so extent — not a
        # rectangle pixel count — is the exact invariant).
        m = mask_of((100, 100, 140, 300))
        halo = person_halo(m, [90, 90, 150, 390])
        ys, xs = np.where(halo > 0)
        self.assertEqual(
            (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())),
            (92, 92, 147, 307),
        )
        self.assertTrue(bool((halo[m > 0] > 0).all()))  # superset


if __name__ == "__main__":
    unittest.main()
