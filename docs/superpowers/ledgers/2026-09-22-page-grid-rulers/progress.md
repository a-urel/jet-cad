# SDD ledger — plan: docs/superpowers/plans/2026-09-22-page-grid-rulers.md

Spec: docs/superpowers/specs/2026-09-22-page-grid-rulers-design.md (rev 2).
Branch: plan-04/page-grid-rulers, worktree .claude/worktrees/plan-04-page-grid-rulers, cut from main at 1e5001d.
Controller: Claude Fable 5.1, session 01e4edaf. Started 2026-09-22.

## Pre-flight conflict scan

| pair / task | produces → consumes | finding |
|---|---|---|
| T1 → T3, T4, T5–T10 | `PageComponent` (fields, `copyWith`, `preset`, `register`) | consistent; every later task uses the same names |
| T1 self | `SheetSize.name` via a `switch` with constant patterns on a class overriding `==` | Ruling 04-8 below |
| T2 → T6 | `DocChange.capability` + index skip → T6's chrome-toggle test asserts `rebuildCount` unchanged | consistent; T6's test is meaningless without T2 |
| T2 self | tile cache `applyChange`: skip placed inside the command arm, `_dropCarryOver()` above the switch untouched | consistent with the file's own comment |
| T3 self | `decodeString` forwards `registerComponents` | consistent |
| T4 → T6, T7 | `GridScale?` from `pick`, `divisor`, `minorMinPixels` (Ruling 04-7) | consistent: T6 `skipEvery: scale.divisor`, T7 `i % divisor`; divisor is 1 when minor is null so every tick is major |
| T4 → T6 | `formatLength` labels vs T7 test parsing `split(' ').first` | consistent for metric labels; the vertical test uses metres |
| T5 → T6, T7, T8, T9 | `PageNotifier` is a `ValueNotifier<PageComponent?>`; painters take `ValueListenable<PageComponent?>` | consistent |
| T5 → T6, T7, T8 | `standardPage`, `standardCamera`, `documentWithPage`, `kChromeSize` | consistent |
| T7 → T8 | `debugLastTicks` record `(double, bool, String?)`; `RulerFrameState` public | consistent |
| T8 → T9 | `RulerFrame({camera, page, child})`; `LayoutBuilder` inside the child | consistent |
| T9 self | `startupPlan` clears history (Ruling 04-1); existing shell test comment about the 200-entry stack becomes stale | Ruling 04-9 below |
| T9 → T10 | `PageNotifier` owned by the shell (Ruling 04-2), passed to `PagePanel` | consistent |
| T6 self | differential: scale range [1e-3, 1e2], intersection often empty → zero lines on both sides | consistent (both sides compute the same empty set) |
| T6 self | bounded test at scale 100: camera translated so the sheet's left edge is on screen | checked: 1 mm major (100 px), 0.2 mm minor (20 px) → ≤ 40/axis < 102 |
| T6 self | breaks test at the standard camera: one vertical (x = 7350), one horizontal (y = −1230) line intersect the view | checked: count 2, inside [1, 4] |
| T10 self | `page-orientation-portrait` key on the segment's label `Text` | plan says fall back to `find.text` if the key cannot be tapped |

## Rulings

- Ruling 04-1..04-7: in the plan's header (startup clears history; shell owns the notifier; coincident minors skipped; ruler range from the bar's size; one comment in compound test; panel is stateful for the scale field; `pick` takes `minorMinPixels`).
- **Ruling 04-8** — if Dart rejects the constant patterns in `SheetSize.name` (a class with a user-defined `==`), write it as an if-chain over `SheetSize.presets`. Cost if wrong: none; behaviour identical.
- **Ruling 04-9** — Task 9 rewrites the stale comment in `planner_shell_test.dart` ("the startup plan … already fills the 200-entry undo stack") to say the history is cleared at startup (Ruling 04-1); the live-count assertions stay. Cost if wrong: a misleading comment.

## Branch point

Measured by Task 1 at 1e5001d: engine `+830: All tests passed!`; render layer `+771 ~1 -5` (the five text_ladder goldens only); harness `+82`; app `+13` + macOS debug + web builds. See task-1-report.md.

## Tasks

### Task 1 — PageComponent
- BASE 1e5001d. Implementer dispatched (Sonnet) 2026-09-22.
- DONE at 39ff5f2 (engine 838). Ruling 04-8 applied (if-chain). Review package built; reviewer dispatched (Sonnet).
- Task 1: complete — reviewer approved, spec OK. Deferred minor: toString says "custom" where SheetSize.name says "Custom".

### Task 2 — DocChange.capability, index and tile skips
- BASE 39ff5f2. Implementer dispatched (Sonnet).
- DONE at 362b422 (engine 842; render 772 = 766 pass + 1 skip + 5 goldens; the report's "700" is a misread of the counter). Reviewer dispatched (Sonnet).
- Task 2: complete — reviewer approved, spec OK. Ruling 04-10: the report's "700 passed" is a misread of `+772 ~1 -5` (766 pass); correction appended to the report, code unaffected. Minor: Undone/Redone doc comments cross-reference CommandApplied — accepted.

### Task 3 — codec hook
- BASE 362b422. Implementer dispatched (Sonnet).
- DONE at d182080 (engine +845). Reviewer dispatched (Sonnet).
- Task 3: complete — reviewer approved, spec OK, no findings.

### Task 4 — page_geometry, grid_scale
- BASE d182080. Implementer dispatched (Sonnet).
- DONE at 5f54569 (engine +859). Reviewer dispatched (Opus: arithmetic-heavy, the ladder feeds three consumers).
- Review (Opus): Needs fixes. Important: (1) imperial 6" rung (`6*25.4`) != `609.6/4` bit-for-bit; (2) imperial unit with a floor gets the metric mantissa divisor, spec D7 says /4 for every imperial step; (3) ascending test loops over the metric ladder only. Minors: `-0'-0"`; ladders allocated per pick; y-axis unasserted in the adaptive snap test.
- **Ruling 04-11** — imperial inch rungs are written as fractions of a foot (`304.8 * {1/192, 1/96, 1/48, 1/24, 1/12, 1/6, 1/2}`) so a foot-rung divided by 4 coincides bit-for-bit with the quarter rung; an exact `==` test pins it; downstream consumers compare only through `pick`'s output. Spec D7's "× 25.4" is amended at execution. Cost if wrong: none visible (same lengths to 1e-13).
- **Ruling 04-12** — `_divisorFor` returns 4 for any imperial unit, floor or not (the spec's words); test added for `pick(feetInches, 0.25, floorMm: 304.8)` → 304.8 / 76.2 / 4.
- Fix round 1 (resume implementer): fix 1–3, plus the minors: `-0'-0"` (sign after rounding), hoist the two constant ladders to `static final`, assert y in the adaptive snap test. Skip: the tautological zoomOf assertion, the worldOfPage doc.
- Fix round 1 done at 93e58ea (engine +860). Re-review dispatched (Sonnet).
- Task 4: complete — re-review: all six findings addressed, no new breakage. Deferred: the static ladders are plain mutable lists (wrap in List.unmodifiable in the final wave).

### Task 5 — chrome_style, page_fit, PageNotifier, fixture
- BASE 93e58ea. Implementer dispatched (Sonnet).
- DONE at 34e27ce (render +777 ~1 -5). Reviewer dispatched (Sonnet).
- Task 5: complete — reviewer approved, spec OK, no findings (note: unused_element is not elevated in this package's analysis_options; only unused_import and unused_local_variable are).

### Task 6 — PageChromePainter
- BASE 34e27ce. Implementer dispatched (Opus: SpyCanvas differential, buffer discipline, intersection range).
- DONE_WITH_CONCERNS at e786df4 (render +786 ~1 -5). Implementer corrections accepted: oracle now requires overlap on both axes; `Paint` stores colour as float32 so the sheet-colour test compares `toARGB32()`; `_lines(start:)` so the major pass does not overwrite the minors' `sublistView` (the brief's code was wrong — Ruling 04-14 records the fix).
- **Ruling 04-13** — the seeded sweep's translation is chosen relative to the sheet so every trial has the sheet at least partly on screen (24/50 trials were 0 == 0). Goes into fix round 1 with the reviewer's findings. Cost if wrong: none; more trials become meaningful.
- Reviewer dispatched (Opus).
- Review (Opus): Needs fixes. Critical: the seeded sweep is vacuous in 50/50 trials (not 24), so the differential verified nothing about positions. Important: `raw.last` is the minors' list when the major pass draws nothing; no anti-vacuity assertion. Painter itself re-derived by hand and correct (6 vertical majors, 58 minors, 2 breaks at the standard camera). Ruling 04-13 formula from the reviewer: tx = sx − s·wx, ty = sy + s·wy with (wx, wy) uniform in the sheet, (sx, sy) uniform in the viewport → 50/50 trials with 1..12 majors.
- Fix round 1 (resume implementer): findings 1–3 with the reviewer's lines; minors 4 (comment says why spans are disjoint, not a dart:ui claim), 10 (@visibleForTesting), 12 (export order). Deferred: 5 (SpyCanvas copies TypedData — outside the diff), 6–9, 11, 13.
- Fix round 1 done at 2a21fcd (render +786 ~1 -5; sweep asserts 50 trials with majors). Re-review dispatched (Sonnet).
- Task 6: complete — re-review: all six findings addressed, no new breakage.

### Task 7 — RulerPainter, RulerCornerPainter
- BASE 2a21fcd. Implementer dispatched (Sonnet).
- DONE at 6bc31eb (render +792 ~1 -5). Corrections: pointer-marker colour compared via toARGB32(); **Ruling 04-15** — the vertical bar iterates its lattice from the top of the bar down so `debugLastTicks` is in bar order on both axes (the brief's ascending-world loop produced descending screen y); drawing unaffected. Reviewer dispatched (Sonnet).
- Task 7: complete — reviewer approved (report delivered before a 429 cut the agent), spec OK, no findings. Minor deferred: per-frame `ticks` list for the debug record.

### Task 8 — RulerFrame, exports
- BASE 6bc31eb. Implementer dispatched (Sonnet).
- DONE_WITH_CONCERNS at 96c09d8 (render +795 ~1 -5). Accepted: `crossAxisAlignment: stretch` on both Rows (the brief's tree collapsed the top bar to zero height); "four keyed CustomPaints" in the dispatch was the controller's typo for three. Reviewer dispatched (Sonnet).
- Task 8: complete — reviewer approved, spec OK. Minor deferred: `late final` merged Listenables would go stale if a caller swapped the camera/page instance (no call site does).

### Task 9 — app: startup page, fit to page, tree, zoom text
- BASE 96c09d8. Implementer dispatched (Sonnet).
- DONE_WITH_CONCERNS at d4f0516 (app +17, both builds). **Ruling 04-16** — the one-time fit in PlannerView's LayoutBuilder is deferred to a post-frame callback: assigning `camera.value` during build now notifies the zoom-text ListenableBuilder (a sibling) and Flutter asserts. Cost: the first frame draws at the shell's nominal `fitToPage(page, 1440x900)`, the second at the real size. Ruling 01-2's intent (fit to the real size, once) holds from frame two; the results note must say so. Reviewer dispatched (Opus).
- Review (Opus): Approved; Ruling 04-16 judged the right call (silent camera set would fix frame 1 but needs a CameraController API and its own ruling — deferred). Important: the deferral comment and the `_fitted` field doc claim the fit lands before the canvas paints; it lands after frame 1. Fix round 1 = comment-only. **Ruling 04-17** — a comment-only fix diff is verified by the controller reading it; no re-review seat.
- Fix round 1 done at 9f08c10; controller read the diff: three comments, no code (Ruling 04-17). Task 9: complete.

### Task 10 — PagePanel
- BASE 9f08c10. Implementer dispatched (Sonnet).
- DONE at 39c88bd (app +21). Accepted: `hint` on the preset dropdown so Custom shows when closed; a `Material` ancestor for the panel (ListTile ink assertion broke four shell tests without it). Reviewer dispatched (Sonnet).
- Task 10: complete — reviewer approved, spec OK. Deferred: re-selecting the current preset/unit/orientation/swatch issues a no-op command (an undo entry); `_set` could skip when `next == page`.

### Task 11 — mutation log
- BASE 39c88bd. Implementer dispatched (Sonnet) with task-11-anchors.md.
- DONE at ba8d6ac: 23 fired (22 + tile twin), 0 survived. **Ruling 04-18** — M-04q as logged (`if (false)`) is a compile failure (null promotion lost), not a behavioural kill; re-fire with `floorMm * m * math.pow(10.0, k)` → `m * math.pow(10.0, k)` (the floor ignored in the values), which compiles; the `a floor is exact` test must go red. Implementer resumed.
- M-04q re-fired at 563fdd4 (compiling mutant, red on `a floor is exact`). Task 11: complete — 23 fired, 0 survived; controller re-checked the untouched-files diff (empty) and tile_cache (one hunk).

### Task 12 — gates, results note, spec amendments, STATUS, roadmap
- BASE 563fdd4. Implementer dispatched (Opus).
- Final whole-branch review dispatched (Opus) on the code range main..563fdd4 in parallel with Task 12 (docs only); its docs get a consistency pass in the fix wave's re-review.
- Task 12: complete at 1618111 — gates 860 / 795 ~1 -5 / 82 / 21 + both builds; results note with criterion 16 OWED itemised (eight items per platform); seven spec amendments; STATUS header/section/resume; roadmap 04 status and README execution row. Doc item for the fix wave: README:265 "the other twelve have not started" is stale (02 and 04 exist).

### Final review (Opus) and the fix wave
- Verdict: With fixes. Critical: `Capability.transform` (index 0) ranks below `components` (index 1), so a compound of a move and a page edit summarises as `components` and both D13 skips ignore it — latent today, live under 03. Important: circular S10 check in ruler_frame_test; vacuous load/dispose assertions in page_notifier_test; ruler_painter_test claims M-04i but calls formatLength for its expectation; two stale doc comments (CompoundCommand "informational only", spatial_index _onChange rationale); shared mutable ladders upgraded from minor.
- **Ruling 04-19** — reorder the enum to `{components, transform, geometry, structure}` so the summary is `components` only when every member is; documented on the enum; tested with a transform+page compound in both consumers; mutant M-04w. Cost if wrong: none observable (nothing serialises the ordinal; permissions are by name).
- Fix wave brief: final-fix-brief.md (A1–A9 code, B1–B5 docs). One dispatch (Opus), one scoped re-review, residuals adjudicated.
- Fix wave done: code 1fe1fcc, docs e6537dd. Gates 862 / 797 ~1 -5 / 82 / 21 + builds. M-04w fired. Deviations accepted: the tile twin is a narrowness guard (its skip is `== components`, unaffected by order); A3 RED shown against two notifier mutants. Scoped re-review dispatched (Sonnet).
- Re-review (Sonnet): all fourteen items addressed, no new breakage; one minor — the results note said "nine source files" for the fix wave where the stat shows seven; corrected by the controller in the closing docs commit.
- Residuals parked with rulings (all in the results note's debt section): the floored ladder allocates per `pick` (unreachable from the app); the grid buffer grows as needed rather than to the bound (spec D8 amended); metre labels collapse below a 0.5 mm major (unreachable under kMaxScale); `fitToPage` bypasses the camera clamp (pre-existing); the scale field resets on any page change; SpyCanvas by-reference; anisotropic camera assumption; `late final` merged listenables; the startup-frame flash (Ruling 04-16); `_set` no-op commands; `toString` casing.

## Close
- Plan 04 executed: twelve tasks, three fix rounds (Tasks 4, 6, 9), one final fix wave, re-reviewed clean. Exit gate 15 of 16; criterion 16 (the human's look) OWED. Ledger archived to docs/superpowers/ledgers/2026-09-22-page-grid-rulers/ as the branch's last commit. The merge is the human's decision.
