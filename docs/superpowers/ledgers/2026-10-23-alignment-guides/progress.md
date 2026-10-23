# SDD ledger — plan: docs/superpowers/plans/2026-10-23-alignment-guides.md

Spec: docs/superpowers/specs/2026-10-23-alignment-guides-design.md (rev 3, approved, amended P-1/P-2).
Branch: claude/alignment-guides-50cacb. Start: 4d9dac91.
Review mode: the human's rule — no reviewer subagents; the controller self-reviews each task
(reads the diff, runs its own mutation, re-runs the gates). Implementers: Sonnet.

## Pre-flight scan

| Pair / task | Shared | Finding |
|---|---|---|
| 1 → 6,7,8 | `PaperPalette.guideColor` | consistent |
| 2 → 6 | `MoveAdjuster` (begin/adjust/suppress/paint/end/changes) | consistent; 6 implements `changes` = settings |
| 3 → 4 | `GuideReferences(boxes, handles)` | consistent |
| 3 → 6,7,8,10 | `solveGuides`, `GuideSolution` (refX/refY, lines, marks) | consistent |
| 4 → 6,7,8 | `GuideReferenceCache(document, units: ...)`, `unionOf`, `worldBoxOf` | 4 needs `UnitIndexCache` lazily; design session creates `units` late, fine via closure |
| 5 → 6,7,8,9,9b | `PlanGuideSettings`, `alignmentGuidesAllowed`, `guideStrokePixels` | consistent |
| 6 → 7,8 | `GuidePainter`, `kGuideOverhangPixels`, `kGuideTickPixels` | 7/8 consume painter defined in 6 |
| 9 ↔ 9b | both edit plan_editor.dart / plan_service_view.dart | sequential, no conflict |
| 9b ↔ existing tests | enum order pinned in editor_bar_test/service_bar_test | 9b updates them in same commit |
| 10 ← 3,6,7,8 | rigs, painter drawRawPoints | consistent |
| 11 | docs, probe, demo | consistent |
| Task 2 self | tests use fake adjuster; wiring in SelectTool | agrees |
| Task 3 self | between fixture fixed (P-8) | agrees |
| Task 7 self | solve inside _syncPlacement; _place commits guided | agrees |
| Task 8 self | camera listener only when eligible+on | agrees |
| Task 10 self | budgets 0.05/event vs control | agrees |

Ruling: Task 3's solver lives in jet_cad_2d_plan (not jet_cad_2d) as the spec says — keeps engine API unchanged before 1.0 — cost if wrong: a later move to the engine.

## Tasks
Task 1: dispatched (sonnet, base 4d9dac91)
Baseline at 4d9dac91: jet_cad_2d_plan flutter test --enable-vmservice: +1638 All tests passed. jet_cad_2d_flutter flutter test: fails only text_ladder_golden_test rungs (RenderBackend.canvas) — pre-existing, standing list has them (macOS too here).
Task 1: complete (commits 4d9dac91..92a23caf, self-review clean; controller mutation withGuide ignoring its argument -> 2 tests red)
Task 2: dispatched (sonnet, base 92a23caf)
Task 2: complete (commits 92a23caf..5513ade0, self-review clean; controller mutations: Alt key state forced false -> MA8 red; orthoBase always null -> MA5 red)
Task 3: dispatched (sonnet, base 5513ade0)
Task 3: implemented 87b7d574 (DONE_WITH_CONCERNS).
Ruling: the sequential-vs-simultaneous recheck mutation is not killable (implementer's argument: a failed spacing recheck implies the other axis took an edge capture, so the orders agree) — the code does the simultaneous version the spec states — cost if wrong: an untested corner where two spacing captures interact.
Ruling: plan's "40 references on one line -> lineCount == 16" is unreachable (step 6 draws only zero-offset candidates and merges equal coordinates: at most 3 lines per axis); the test checks merging and the bound instead — cost if wrong: capacity guards untested.
Task 3: fix round 1 dispatched (controller mutations survived: sign tie-break in _beats; continuing pair's perpendicular overlap in _outer).
Task 3: fix round 1/5 (F2 addressed, F1 ruled; commits 87b7d574..4165befb)
Ruling: F1 (the negative-before-positive tie) is unreachable with distinct handles — every earlier key (|o|, kind, pair, handle, second handle) already separates two candidates — kept as written, untested — cost if wrong: none observable.
Task 3: complete (commits 5513ade0..4165befb, self-review clean after round 1; controller mutation on _outer's overlap now red)
Task 4: dispatched (sonnet, base 4165befb)
Task 4: implemented d291024f (DONE_WITH_CONCERNS).
Ruling: the ATTRIB skip in the bucketing pass is redundant (boxOfLeaves skips attributes) but kept per the brief; the label test pins the behaviour — cost if wrong: none.
Ruling: the table-revision key is subsumed by the identical-UnitIndex check; kept to mirror the brief — cost if wrong: none.
Task 4: fix round 1 dispatched (controller mutation survived: nested non-unit instance counted as a reference).
Task 4: fix round 1/5 (1 addressed, 0 open; commits d291024f..794b7798)
Task 4: complete (commits 4165befb..794b7798, self-review clean after round 1; controller mutation now red)
Task 5: dispatched (sonnet, base 794b7798)
Task 5: complete (commits 794b7798..09d04ccd, self-review clean; controller mutation toggle-without-notify -> red)
Task 5: minor (deferred): guide_settings.dart header cites a spec section "The setting" that does not exist ("Turning them off"); the controller's guides import sits out of alphabetical order.
Task 6: dispatched (sonnet, base 09d04ccd)
Task 6: complete (commits 09d04ccd..da43f3c3, self-review clean; 19 implementer mutations red)
Ruling: `movable`'s root-parent check survives its mutation — a SelectTool move's handles are root-level captures, so a nested instance never reaches begin(); the check stays as a guard — cost if wrong: a nested generated unit dragged alone would get guides.
Ruling: the gap-mark tick reaches 4 px to each side (8 px across), the implementer's reading of "a short perpendicular tick (4 px)" — cost if wrong: a one-constant change (kGuideTickPixels = 2).
Ruling: DG-14 (attachment) is tool-level, since the plan package has no restaurant kit; fixtures use the fx kit — cost if wrong: attachment path covered only by the seam test.
Task 7: dispatched (sonnet, base da43f3c3)
Task 7: implemented eb6f8d0b (DONE).
Ruling: writing an uncaptured axis as raw + (at − raw) is numerically the same as copying at for nearby doubles; the captured-only write stays, pinned by M11 — cost if wrong: an ulp on the uncaptured axis.
Task 7: fix round 1 dispatched (F1 marker position unpinned; F2 Alt key bubbling mid-press breaks the swallow rule).
Task 7: fix round 1/5 (2 addressed, 0 open; commits eb6f8d0b..4942a0c8)
Task 7: complete (commits da43f3c3..4942a0c8, self-review clean after round 1)
Task 8: dispatched (sonnet, base 4942a0c8)
Task 8: implemented 185f706b (DONE_WITH_CONCERNS).
Ruling: test/support/service_host.dart's serviceController defaults guides off (opt in with guides: true) — four existing service tests (TG-G8, G12, G14, VE8) stand tables in rows and pin landings without guides; their assertions are untouched — cost if wrong: those suites no longer exercise the default (guides on) path; the guides suite does.
Ruling: implementer wrote code before tests (TDD order broken); red evidence is the compile failure plus 11 mutations — accepted, no rework — cost if wrong: none observable.
Task 8: fix round 1 dispatched (F1: Alt branch returns ignored during a band, breaking RB-5).
Task 8: fix round 1/5 (1 addressed, 0 open; commits 185f706b..8df6a2ab)
Task 8: complete (commits 4942a0c8..8df6a2ab, self-review clean after round 1; controller mutation _reset without _endGuides -> SG-cancel red)
Task 9: dispatched (sonnet, base 8df6a2ab)
Task 9: complete (commits 8df6a2ab..ed8bc6e5, self-review clean; controller mutation didUpdateWidget write removed -> M-GV-3 red)
Task 9: minor (deferred): two earlier full runs showed "did not complete" flakes (barrel_test, editor_modes_test F-3), a clean rerun after — watch in the exit gate.
Task 9b: dispatched (sonnet, base ed8bc6e5)
Task 9b: implemented d515b90b (DONE_WITH_CONCERNS).
Ruling: the architecture demo's DC12/DC12c 800 px floor stays (spec 12a D7); raising it to 840 px is an assertion weakened — the toggle must fit: compact the toggle first, else compact the demo's own open-sample button — cost if wrong: a slightly smaller hit target on the toggle.
Ruling: pinned bar tests (ED-4, O23, TB7, the enum name tables) updated to the grown enums and button sets — legitimate growth, not weakening — cost if wrong: none.
Task 9b: fix round 1 dispatched (F1: restore the 800 px floor).
Ruling: Task 9b space for the toggle comes from the architecture demo's _DocumentTitle max width (144 px lowered), the toggle stays uniform with the other toolbar buttons; DC12/DC12c unchanged at 800 px — cost if wrong: a long file name is cut 40 px sooner in the demo.
Task 9b: fix round 1/5 (1 addressed, 0 open; commits d515b90b..8e9e2b1e; DC12's own 144 px width assertion now pins 104, the bound the ruling changed)
Task 9b: complete (commits ed8bc6e5..8e9e2b1e, self-review clean; controller mutation editor toggle run no-op -> guide_bar_test red)
Task 10: dispatched (sonnet, base 8e9e2b1e)
Task 10: implemented dafb06b5 (perf: service re-aim without Vector2) + 2eb1a2c6 (test).
Ruling: the invariant meters with a per-epoch floor and asserts least(on) − most(off) ≤ 0.05/event over rounds, not the brief's single on−off subtraction — the JIT's escape analysis toggles the baseline's own Transform2/Vector2 between runs — cost if wrong: a small real regression hidden inside the noise band.
Ruling: a bare List of candidates and a non-escaping Vector2 clone are invisible to the meter (the JIT elides them); escaping allocations and Float64List/Set are watched — cost if wrong: an elided allocation that stops being elided would go unseen.
Task 10: fix round 1 dispatched (F1: file runtime ~5 min under vmservice).
Task 10: fix round 1/5 (1 addressed, 0 open; commits 2eb1a2c6..f256b9d8; file 5:05 -> 1:31)
Task 10: complete (commits 8e9e2b1e..f256b9d8, self-review clean; controller mutation: escaping Float32List per paint -> GA6 red; a non-escaping one is elided by the JIT, per the ruling)
Task 10: minor (deferred): in one GA[134] run GA3 stayed green under the Float64List-candidates mutation while GA1/GA4 went red (red alone); the merged pointer/camera windows share one allowance.
Task 11: dispatched (sonnet, base f256b9d8)
Task 11: implemented 0a7bb083..598b3e00 (DONE_WITH_CONCERNS: integration recording_plan_strings gained alignmentGuides; four integration landing tests opt out of guides, assertions unchanged; demo guideWidth 1.5 in the POS look themes).
Controller exit gate (re-run): integration +240, restaurant_demo +114, architecture_demo +176, tool/ci +114, analyze/format clean; jet_cad_2d_flutter only standing text-ladder failures; plan suite: one full run failed GA1 (allocation growth check), the next full run and two solo runs passed.
Ruling: the growth check compares guides-on at 200 refs with the baseline envelope (max of on@10, off@10, off@200 + budget) — JIT elision of the baseline's own Vector2/_Float64List varies by round, so on@10 alone is a flaky bound; a per-reference allocation still fails by orders of magnitude — cost if wrong: a growth below ~100 objects per 250 events hidden.
Task 10: fix round 2 dispatched (flaky growth check).
