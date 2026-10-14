"""Phase D reflection-warning logic (worker/reflections.py).

Synthetic geometry only — no models. Covers the frozen §4 rules:
candidate coincidence rejection, surface hosting, removed-person
association, the absolute keeper veto, the nobody-removed silence,
and the flip match on a synthetic flipped pattern.
"""

import unittest

import numpy as np

from worker.reflections import reflection_warnings


def _person(pid, box):
    return {"id": pid, "box": box, "score": 0.9}


def _det(label, score, box):
    return {"label": label, "score": score, "box": box}


def _gray(h=1000, w=1000):
    return np.full((h, w), 200, dtype=np.uint8)


class CandidateSignalTests(unittest.TestCase):
    def setUp(self):
        # Keeper left, removed person right, mirror on the right.
        self.persons = [
            _person(0, [50, 100, 250, 900]),
            _person(1, [600, 100, 800, 900]),
        ]
        self.surfaces = [_det("mirror", 0.6, [550, 50, 1000, 950])]

    def test_candidate_beside_removed_person_warns(self):
        refl = [_det("reflected person", 0.6, [830, 150, 990, 850])]
        warnings = reflection_warnings(
            self.persons, [0], [1], self.surfaces, refl, _gray()
        )
        self.assertEqual(len(warnings), 1)
        self.assertEqual(warnings[0]["person_id"], 1)
        self.assertEqual(warnings[0]["kind"], "candidate")

    def test_candidate_coinciding_with_person_is_ignored(self):
        # The reflection prompt re-firing on the direct person.
        refl = [_det("reflected person", 0.9, [600, 100, 800, 900])]
        warnings = reflection_warnings(
            self.persons, [0], [1], self.surfaces, refl, _gray()
        )
        self.assertEqual(warnings, [])

    def test_keeper_veto(self):
        # Same candidate, but it also associates to a keeper placed
        # beside the removed person.
        persons = self.persons + [_person(2, [810, 100, 900, 900])]
        refl = [_det("reflected person", 0.6, [830, 150, 990, 850])]
        warnings = reflection_warnings(
            persons, [0, 2], [1], self.surfaces, refl, _gray()
        )
        self.assertEqual(warnings, [])

    def test_keeper_reflection_alone_never_warns(self):
        # Candidate associates only to the keeper (person 0 removed
        # nobody near it); removed person is far away.
        surfaces = [_det("mirror", 0.6, [0, 50, 550, 950])]
        refl = [_det("reflected person", 0.6, [280, 150, 430, 850])]
        warnings = reflection_warnings(
            self.persons, [0], [1], surfaces, refl, _gray()
        )
        self.assertEqual(warnings, [])

    def test_candidate_outside_surface_is_ignored(self):
        refl = [_det("reflected person", 0.6, [280, 150, 430, 850])]
        warnings = reflection_warnings(
            self.persons, [0], [1], self.surfaces, refl, _gray()
        )
        self.assertEqual(warnings, [])

    def test_nobody_removed_never_warns(self):
        refl = [_det("reflected person", 0.6, [830, 150, 990, 850])]
        warnings = reflection_warnings(
            self.persons, [0, 1], [], self.surfaces, refl, _gray()
        )
        self.assertEqual(warnings, [])


class FlipSignalTests(unittest.TestCase):
    def _scene(self, with_reflection=True):
        """A dark 'person' standing on a bright horizontal surface,
        optionally with its flipped copy below the feet line."""
        gray = np.full((1000, 1000), 210, dtype=np.uint8)
        # Person: dark body with a brighter head band so the flip
        # has structure to match.
        gray[100:500, 400:600] = 40
        gray[100:180, 400:600] = 120
        if with_reflection:
            person = gray[100:500, 400:600].copy()
            gray[500:900, 400:600] = np.flipud(person)
        surfaces = [_det("water", 0.6, [0, 480, 1000, 1000])]
        persons = [_person(0, [400, 100, 600, 500])]
        return gray, persons, surfaces

    def test_flip_match_warns(self):
        gray, persons, surfaces = self._scene(with_reflection=True)
        warnings = reflection_warnings(persons, [], [0], surfaces, [], gray)
        self.assertEqual(len(warnings), 1)
        self.assertEqual(warnings[0]["kind"], "flip")
        self.assertGreaterEqual(warnings[0]["score"], 0.5)

    def test_no_reflection_no_warning(self):
        gray, persons, surfaces = self._scene(with_reflection=False)
        warnings = reflection_warnings(persons, [], [0], surfaces, [], gray)
        self.assertEqual(warnings, [])

    def test_small_person_skipped(self):
        gray, persons, surfaces = self._scene(with_reflection=True)
        tiny = [_person(0, [400, 430, 440, 500])]  # 7% of height
        warnings = reflection_warnings(tiny, [], [0], surfaces, [], gray)
        self.assertEqual(warnings, [])

    def test_vertical_surface_no_flip(self):
        gray, persons, _ = self._scene(with_reflection=True)
        surfaces = [_det("mirror", 0.6, [0, 480, 1000, 1000])]
        warnings = reflection_warnings(persons, [], [0], surfaces, [], gray)
        self.assertEqual(warnings, [])


if __name__ == "__main__":
    unittest.main()
