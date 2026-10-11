# Frozen Test Set — PeopleGone Phase 0 Quality Gate

This directory contains the specification, ground truth annotations, and frozen SHA-256 hashes for the 30 test photos mandated by `PEOPLEGONE_REQUIREMENTS.md` §3.1 and §3.2.

## Category Breakdown (n = 30)

| Category | Count | Description |
| :--- | :--- | :--- |
| **Simple backgrounds** | 6 | Sea, sky, sand, grass, plain walls (Target: ≥90% "Would post") |
| **Architecture / landmarks** | 5 | Repeating geometry, lines, tiles, bricks, railings |
| **Crowds / street scenes** | 5 | Dense pedestrian flow; keepers must survive untouched |
| **Overlap** | 4 | Background persons touching or partly occluded by keeper |
| **Strong cast shadow** | 3 | Directional shadows extending from removed persons |
| **Small / distant people** | 3 | Tiny tourists (<30px) far along ridgelines or plazas |
| **Large background person** | 2 | Background person occupying >20% of the frame |
| **Reflection present** | 2 | Reflections in glass windows or puddles |

*Cross-cutting stress tests included:*
- At least 2 low-light / noisy photos (e.g., Photos 15 and 23).
- At least 2 hair / fine-edge stress photos (e.g., Photos 9 and 18).

## Freezing Instructions (Human Step)

1. Place the 30 actual 12 MP+ phone photos into `testset/photos/` using the filenames designated in `manifest.csv`.
2. Run the freezing script:
   ```bash
   python3 tools/freeze_testset.py
   ```
3. Verify that all 30 SHA-256 hashes are written to `manifest.csv`.
4. Commit the frozen `manifest.csv`. **Never alter or replace a photo mid-test**.
