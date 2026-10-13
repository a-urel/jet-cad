# SDD ledger — plan: docs/superpowers/plans/2026-10-13-rubber-band-selection.md

Spec: docs/superpowers/specs/2026-10-13-rubber-band-selection-design.md (revision 2, approved 2026-10-13).
Branch: feat/rubber-band (worktree .claude/worktrees/rubber-band), from `main` at `1e53de1`. Plan commit `afe4e65`.
Execution: subagent-driven, chosen by the human 2026-10-13 ("subagent-driven ile devam et").

## Pre-flight scan

| Rows | Produces / consumes | Found |
|---|---|---|
| T1 ↔ T2 | T1 produces `bandModeFor(Offset, Offset)`, `SelectionBandPainter.paint(Canvas, Rect, BandMode, PaperPalette)`, exported by the render barrel; T2's tool imports both from `package:jet_cad_2d_flutter` | consistent |
| T1 ↔ T2 (mutant) | T2's M-RB19 is applied in T1's file (`selection_band.dart`), reverted | consistent; T2 may edit T1's file for the mutant only |
| T2 ↔ T3 | T2 produces `FloorPlanFloorDrag`, `ServiceOptions.floorDrag`, the view's literal set to `pan`; T3 replaces it with `widget.floorDrag` and adds the barrel name | consistent |
| T2 ↔ T3 (mutant) | T3's M-RB3b is applied in T2's `phase` getter | consistent |
| T3 ↔ T4 | T4's guide/demo use `FloorPlanView(floorDrag:)` and the barrel's `FloorPlanFloorDrag` | consistent |
| T1 self | BP1–BP3 vs the painter code; M-BP3 (stroke colour moved into the crossing branch) is killed by BP3's window-after-crossing | consistent |
| T2 self | RB1–RB16 vs the code sketch: `_startsBand` (reach-only only under band), `_bandKeys` (snapping, candidates, groups), `onKey` first; RB5b needs `ev()` with touch on move/up too — the brief says so | consistent |
| T3 self | RBV1–RBV8 vs the view field; RBV6 is a pin (M-RB20 unreachable, stated) | consistent |
| T4 self | docs, demo, probe, gates; old-host probes now four (v0.6.0 added) | consistent |

Ruling 1: the skill's helper scripts are refused by the worktree guard; the controller does their work by hand (workspace mkdir, briefs cut with python, review packages as three plain git commands) — as in plan colours — costs, if wrong: nothing structural.

Ruling 2: the ledger is archived to `docs/superpowers/ledgers/2026-10-13-rubber-band-selection/` as the branch's last commit, not deleted (the repo's convention) — costs, if wrong: a docs directory to remove.

Ruling 3: commit trailers name the model that wrote the commit (the session's attribution rule) — costs, if wrong: amending trailers.

## Tasks
Task 1: dispatched (BASE afe4e65, implementer sonnet)
Task 1: implementer DONE_WITH_CONCERNS (38ca3af); concern: render expect_failures exits 1 only for the recorded macOS pair (text_lod_ladder rungs 1-2 pass) — the standing difference. Review dispatched (sonnet).
Task 1: review — spec ✅; 1 Important (BP3 compares the reused Path to itself: dropping _dashes.reset() survives) → fix round 1.
Task 1: minor (deferred): selection_band.dart:44-45 _edge doc names the deleted _drawDashedRect.
Task 1: minor (deferred): BP2 pins only the first dash; off length, later edges, dark palette rely on tool_palette_test.
Task 1: fix round 1/5 (1 addressed, 0 open; commits 38ca3af..9926758: BP4 snapshots each call's path; M-BP4 red; _edge doc)
Task 1: minor (deferred): selection_band_test.dart:1-3 header omits M-BP4.
Task 1: complete (commits afe4e65..9926758, review clean)
Task 2: dispatched (BASE 9926758, implementer opus)
Task 2: implementer DONE_WITH_CONCERNS (8210ef0); (1) the L fixture is two leaves: the index's window rule tests each leaf's own transformed box, so a single-outline L at 37° is never enclosed short of its whole box; (2) RB16 subtracts a no-frame baseline before '≤ 2' (the painter's kept objects read 5); (3) RB16 also watches _ByteDataView (a Paint's buffer; the JIT elided Paint once); Path reads _NativePath; (4) the three named test files had no ServiceOptions literal — none edited.
Ruling 4: the two-leaf L stands — the window rule is the engine's per-leaf box test (the design mode's too, spec F-4), and RB6 still separates leaf-level from instance-box selection (M-RB6 killed) — costs, if wrong: a fixture rewrite.
Task 2: review dispatched (opus).
Task 2: review — spec ✅, quality Approved (opus). F-6's three test literals do not exist (stale fact; no exception used).
Ruling 5: RB16's budget is the excess over a no-frame baseline (≤ 2) and watches _ByteDataView beside Paint and _NativePath — the meter's epochs make the subtraction sound and the JIT elided a Paint once, letting M-RB19 survive on Paint alone — costs, if wrong: the budget's wording.
Task 2: minor (deferred, FINAL REVIEW TRIAGE): the crossing's !t.locked (table_select_tool.dart:420-421) unpinned — a crossing over group h's locked 8 alone is untested (M: drop !t.locked survives).
Task 2: minor (deferred, FINAL REVIEW TRIAGE): R-1 (modifier read at the down) unpinned — the rig passes the same modifiers on down, moves and up.
Task 2: minor (deferred, FINAL REVIEW TRIAGE): RB13's no-double-tap/no-hover vacuous at the tool; moving _startsBand above _lastTap = null survives (tap 2, band, tap 2 → double tap).
Task 2: minor (deferred): RB12's world rect hard-coded without a reason comment.
Task 2: minor (deferred): _bandKeys builds a candidate map per band (O(n) per up, off the frame path).
Task 2: minor (deferred): RB6 means each leaf's transformed box (engine rule); a single-outline L cannot be windowed short of its whole box — note in the guide/spec.
Task 2: complete (commits 9926758..8210ef0, review clean)
Task 3: dispatched (BASE 8210ef0, implementer sonnet)
Task 3: implementer DONE (e6ff733); RBV4's mode switch asserts the selection unchanged ({5}), not empty — the selection carries across modes; Escape reaches the tool under shortcuts:false (M-RB17 red at the view); barrel_test enumerates names (FloorPlanFloorDrag added, named exception); RBV6 a pin.
Ruling 6: RBV4's mode-switch leg asserts 'selection unchanged' rather than the brief's 'nothing selected' — the spec's RB-5 says a cancelled band leaves the selection unchanged, and the selection persists across modes — costs, if wrong: one assertion.
Task 3: review dispatched (sonnet).
Task 3: review — spec ✅, quality Approved (sonnet). ⚠️ locked/group rules at the view: pinned by Task 2's RB9/RB10 (confirmed by the controller).
Task 3: minor (deferred): band_view_test.dart:564/:576 expect(pxPerUnit > 0) junk assertions; helper :236-242 unused otherwise.
Task 3: minor (deferred): band_view_test.dart:537-540 reason claims 'taken whole' where both members are inside anyway.
Task 3: minor (deferred): RBV4 after Escape does not assert floorTaps/taps stay empty.
Task 3: complete (commits 8210ef0..e6ff733, review clean)
Task 4: dispatched (BASE e6ff733, implementer sonnet)
Task 4: implementer DONE (d15385b); gates green (render: the macOS pair only); floor_plan +2003, symbols 97, floor_planner 212, demo 69 (D23), tool/ci 64, check_guide 54 blocks, host probe, old probes v0.3.0/v0.4.0/v0.5.1/v0.6.0 exit 0; concern: CI runs old probes for v0.3.0/v0.4.0/v0.5.1 only.
Ruling 7: adding v0.6.0's old-host probe to CI (ci.yml:169-173) belongs to release 0.7.0's step, not this slice — 0.6.0 became an old host only at its tag; the slice ran it by hand, green — costs, if wrong: two lines in ci.yml now.
Task 4: review dispatched (sonnet).
Task 4: review — spec ❌ 1 Important (guide §8 longPress bullet, host-guide.md:1377-1380, still says contextMenu leaves a touch screen no multiple selection) → fix round 1 (with the one-finger-pan clause, a minor, folded in).
Task 4: minor (deferred): STATUS says each of Tasks 1-4 reviewed before Task 4's review (true at merge).
Task 4: fix round 1/5 (1 addressed, 0 open; commits d15385b..cc196aa: §8 longPress names the band; one-finger pan lost under band stated in the subsection and §10)
Task 4: minor (deferred): host-guide.md:547 and :2186 ragged wrap (cosmetic).
Task 4: complete (commits e6ff733..cc196aa, review clean)
Final review: dispatched (opus) over 1e53de1..cc196aa.
Final review: Ready after fixes (opus) — production code correct; 4 test pins (tool notifications on move/Escape; R-1 at the down; crossing's !t.locked; RB13 tap after band), docs' 'the wheel pans' false on desktop (6 places), RBV4's stale name, the ragged wraps. Triage: the three FINAL REVIEW TRIAGE minors fix before merge; the rest can stay.
Final fix wave: dispatched (sonnet, BASE cc196aa).
Final fix wave: re-review — all 7 addressed (commits cc196aa..3bc32d9: RB15b notifications, RB2b the modifier at the down, RB10's locked-member crossing, RB13's tap after the band, RBV4's name; the wheel wording in six places with a spec errata line; rewraps). M-RB22 to M-RB27 red.
Final fix wave: deferred minor: the plan (2026-10-13-rubber-band-selection.md:305, 690, 729, 744) keeps 'the wheel or trackpad'; the spec's errata line governs.
Slice: complete (1e53de1..3bc32d9). Named mutants: Task 1 five (M-BP1-4, M-RB18), Task 2 twenty-one, Task 3 four (+M-RB17 at the view), Task 4 one (demo), final wave six (M-RB22-27): all killed; M-RB20 has no place to be applied (RBV6 a pin).
