# Task 4 — carried (binding, in addition to the plan's Task 4)

1. **M-08s must be killed on a JOINED host.** Task 3's review: at Task 3's pure
   level M-08s (clamp into [0, len] instead of the straight span) only goes red
   incidentally, because HF5's host is free (uS ≈ 1.3e-10 vs 0 under exact
   equality). OG2 (and OG9) must carry the real kill: an opening clamped against
   a real corner cap (an L or a node) at the far origin in a rotated group, so
   the mutant draws the cut into the cap. Report the red line.
2. **Spec D7 was amended** (d15c5a1, "Task 3 review S1"): a T obstacle covers
   the stem's whole footprint in the host's band (cap points ∪ stem faces ×
   near face). The document-level oracles you build (oracleObstacles etc.)
   must follow the amended rule (reuse Task 3's independent
   `oracleTeeFootprint`).
3. Task 3 moved `strictlyInside` public and gave `WorldWall` `params` and
   `toWorld`; `hostFrameOf` re-checks in local space. `mergeCuts` and
   `overlaps` exist in opening_geometry.dart but are unpinned: OG1/OG2 may
   pin mergeCuts's use; the tolerance extras for them are Task 5's (do not
   pin them here unless natural).
4. `unused_import` is a warning, not an error, in the app (the plan's Global
   Constraint overstates it) — still fix any before committing.
