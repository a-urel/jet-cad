# Task 3 review (independent) — 359a70a
Status: in progress
- Diff 7bed823..359a70a: 3 files, all packages/jet_cad_2d_flutter (export line, src/symbol_thumbnails.dart new, test/symbol_thumbnails_test.dart new). Invariant tests, engine, app untouched.
- Paint path read (symbol_thumbnails.dart:103-145): DocumentStyleResolver(doc, foreground) :112; fit(extents padded by 8% of larger side) :114-117; recorder canvas scaled by DPR :119; SpatialIndex disposed in finally :134; VerticesDrawSink(kLogicalPixelsPerMm, canvas, dpr), no fallback :122-126; DraftPainter.paint + flush :127-129; toImage(round(w*dpr), round(h*dpr)) :138-141; picture disposed in finally :143. One render path; nothing on the frame path.
- Render gate (real): `00:46 +987 ~1 -7: Some tests failed.`; the 7 [E] are text_ladder rungs 1-5 and text_lod_ladder rungs 1-2 (RenderBackend.canvas), the standing ones. analyze `No issues found!`; format `Formatted 180 files (0 changed)` fmt=0.
- App: `02:55 +819: All tests passed!`.
- M-09k (:76 key->0): RED T1, T4 version (Expected <2> Actual <1>), T5. restored diff=0
- M-09x size (:76): RED T4 logical size. DPR: RED T2 (Expected [62,46] Actual [83,61]), T4 DPR. foreground: RED T4 foreground, T8 (Actual [0,0,0]). restored diff=0 each
- M-09y (:112): RED T8 (Expected <40, Actual [255,255,255]). M-09z (:87): RED T5, T6. M-09b15 (:139): RED T2 (Expected [83,61] Actual [41,61]), T6, T8, T9. hunt off-by-one (:85 >=): RED T5, T6. restored diff=0 each
- hunt canvas not DPR-scaled (:119): RED T8 (Actual [244,241,234]). key includes builder closure (:76): RED T5. FIFO (:77): RED T5. error not swallowed (:158 rethrow in onError): RED T9. use after dispose allowed (:74): RED T7. restored diff=0 each
- HUNT padding ignored (:114 `0.0 *`): SURVIVED `+13: All tests passed!`. padding not applied to fit (:117 `extents`): SURVIVED +13. restored diff=0 -> finding 1
- HUNT sink DPR ignored (:125 `1.0`): SURVIVED +13 (the sink's DPR only matters below 1 device px, vertices_draw_sink.dart:562,580; fixture strokes are 1-2 mm). restored diff=0 -> finding 2
- extra pending dispose immediate (:154): RED T6. no flush (:129): RED T1, T8. restored diff=0
- Final git status --short: empty.

## Verdict: Needs fixes (test-only)
1. MAJOR test/symbol_thumbnails_test.dart (no test; impl :114-117): the 8% padding (spec D5) is untested; `pad = 0.0 *` and fit on raw extents both survive. Fix: assert the image's outer border (e.g. 2 device px) has zero alpha for both fixtures, and ink reaches within ~15% of an edge (so excess padding is also caught).
2. MINOR (impl :125): the sink's devicePixelRatio ignored survives; add a sub-pixel lineweight leaf (e.g. 5 = 0.05 mm) and compare its max alpha at DPR 1 vs 2, or the alpha at one DPR against the expected coverage.
3. NOTE: picture disposal (:143) is not observable from outside; accepted by reading.
Decisions accepted: microtask-delayed disposal (documented; Task 4 must clone in the completion callback); cached failed futures (immutable library, D5 "no other trigger"); imageFor after dispose throws StateError.
Fixtures non-degenerate: base points (300,150)/(-120,410), instances rotated 0.7/-1.2 and mirrored, at (52000,-31000)/(-18000,74000), BYBLOCK leaves; guarded by a test.

## Re-review (3b) — 3faabd4 (parent 1951d01)
- Diff: only packages/jet_cad_2d_flutter/test/symbol_thumbnails_test.dart (+118).
- Render gate (real): `00:57 +999 ~1 -7`, the 7 = text_ladder 1-5 + text_lod_ladder 1-2 only; analyze `No issues found!`; format `Formatted 182 files (0 changed)` fmt=0.
- Mutants (scratchpad/rb3b, restored diff=0 each):
  - pad `0.0 *` (:114): RED padding test, `Expected: every element(>= 2) Actual: [5, 0]`
  - fit on raw extents (:117): RED, same output
  - sink devicePixelRatio 1.0 (:125): RED sub-pixel test, `Expected: be in range from 175 to 210 Actual: <96>`
  - pad `0.25 *` (:114): RED padding test, `Expected: true Actual: <false>` (padded too far)
- Alpha ranges justified: _coveredArgb (vertices_draw_sink.dart:575-588) gives coverage = 2 x deviceWidth; 0.05 mm x 3.7795 = 0.189 logical px -> alpha 0.378x255 = 96 at DPR 1, 0.756x255 = 193 at DPR 2. The ranges 80-110 / 175-210 bracket the formula (the mutant reads exactly 96), not a mutant.
- Hairline fixture: base point (640,-275), rotation 0.4, mirrored scale(-1,1), at (-37000,-91000). It is not added to the "fixtures are not degenerate" guard loop (note only; visibly non-degenerate).
- Line symbol border-only: honest; its ring's extents are the rotated local box (looser than the ink), so the near-edge half would be false for the right reason; the 2 px border half still applies to it.
- git status --short: empty.
### Verdict (3b): Approved (one note: add hairlineSymbol to the guard loop at a later touch)
