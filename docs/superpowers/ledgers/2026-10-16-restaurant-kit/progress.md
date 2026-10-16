# SDD ledger — plan: docs/superpowers/plans/2026-10-16-restaurant-kit.md

Spec: docs/superpowers/specs/2026-10-16-restaurant-kit-design.md (approved 2026-10-16, decision 9 included). Plan approved 2026-10-16 ("onaylıyorum").
Branch feat/restaurant-kit, worktree .claude/worktrees/restaurant-kit, from main 8caf8e00.
Reviews: none by subagents (human: "bağımsız review session'ı yaratma!"); the controller reviews each task (diff read, own mutations, gates re-run). Implementers: Sonnet.

## Pre-flight scan

| Pair / task | Shared | Finding |
|---|---|---|
| T1 → T2 | catalog files, asset, `restaurantSymbolDefinitions` | T2 adds units and regenerates; consistent |
| T2 → T6 | `restaurantKit`, `RestaurantSymbols`, defs | consistent |
| T3/T4/T5 | plan library; T5 also apps/architecture_demo | disjoint files except barrel (T3 only); consistent |
| T5 → T8 | `pageFlowBusy` | T8 consumes; consistent |
| T6 → T7 → T8 | demo main.dart, rig | sequential; consistent |
| T9 | needs T6-T8 | consistent |
| T10 | guide probe needs T2 + T3 public names | consistent |
| T11 | all | consistent |
| T1 own | geometry fixture via a one-off script in the old package dir | the script must not be committed; the old package untouched — consistent |
| T4 own | O1 may be green today | plan says close with the pin; consistent |

## Tasks
Ruling (T1): 8 one-segment old keys renamed to satisfy the contract's key rule (kit id + ≥2 segments): cashier→cashier.desk, buffet→buffet.counter, highchair→highchair.child, parasol→parasol.round, heater→heater.patio, partition→partition.screen, stage→stage.platform, piano→piano.grand — the restaurant symbols were never published (no plan holds them), the architecture kit set the precedent (armchair→armchair.single) — cost if wrong: names only, before the first publish.
Task 1: complete — b40de57f (kit +85; check_kit_deps 3 packages). Controller review: diff scope only the new package + workspace + spec R1 note; old package untouched; only the kit's analysis_options committed; own mutation (square.two width 700→701) red on its geometry case, reverted clean; full kit suite re-run +85.
Task 2: complete — ec01ca6b, 1ba8ecf4 (kit +184; dry-run 0 warnings). Controller review: SC1 checked (kit units_test asserts family isNull per unit; SW5 exists in plan tests); own mutation (booth.two capacity +1, no regen) red on U3, reverted clean; suite re-run +184.
Ruling: restaurantSymbolEntries() added beside restaurantSymbolDefinitions() (a placed table needs its unit) — spec R1 amended — cost: one more public name.
Ruling: the snapshot regenerated (not appended) since key@1 is unpublished; from the first publish K7 holds — cost: none now.
Moved to the demo: RL15 (symbols_load_test), SC3 behaviour (corner_booth_test) → Task 6/7.
Task 3: implemented — cf10c08c (plan +1563 re-run by the controller; integration +228). Controller review: own mutation (unmount fallback .last→.first) SURVIVED — two views make first==last; and the fallback follows insertion, not report order. Fix round 1 sent: re-insert on report, a three-view case, both mutations.
Note for Task 10 (guide): "two views" = two PlanServiceViews (a second PlanCanvas on one controller asserts in debug); the shared camera stays shared, the last reporter drives canvasRect (zoomBy's focus); in one frame, mount the view that should drive after the others. H4's wheel is in the engine's CameraGestureDetector (one mutation covers pinch+wheel).
Fix round 1: 1186612b (test strengthened: three views, keyed; code already re-inserted on report) — controller re-ran its mutation (.last→.first): red now. plan +1564, integration +228. Task 3: complete.
Task 4: implemented — f7833d42 (O2 fixed: FittedBox, tested en/de/tr at 280/240 px and the editor at 1440x900; O1 reproduced in test/tools/drag_self_snap_test.dart, cause in the engine, landed skipped).
Ruling (the human, "Motoru 4a'da düzelt"): O1 fixed in the engine (jet_cad_2d resolveDragPoint/snapInto exclusion, jet_cad_2d_flutter SelectTool passes the dragged objects) under umbrella A12's seam rule; spec R2 amended; the engine and the Flutter layer join 4b's release — cost: two more packages in the wave.
Task 4b dispatched fresh (the resumed Task 4 agent ended without acting on the message).
Incident: the stopped Task 4 agent had resumed on the 4b message late and edited the engine in parallel with the fresh 4b agent; stopped it, discarded both agents' uncommitted engine edits, the fresh agent restarts clean.
Task 4b: implemented — 4f1545f7, fcc1803b (engine +1343 -2 standing; flutter +1451 ~1 -5 standing; plan +1574 re-run by the controller; integration +228; architecture_demo +176). Controller review: own mutation (SelectTool passes no exclusion) red on O1; BUT the exclusion also applies to the move base (`_moveBase`), which breaks own-corner-to-other-corner placement; M-03p's fixture was changed to route around it. Fix round 1 sent: base without exclusion, M-03p restored or split, a corner-to-corner test.
Fix round 1 (4b): 74f5e8b8 — base resolves without exclusion; corner-to-corner test; M-03p split (base half unchanged, target half on an extra unselected line, Decided). Controller mutation (exclusion back in _moveBase) red on the corner test, reverted clean. flutter +1453 standing only; plan +1574; integration +228.
Task 4: complete (O2 f7833d42; O1 via 4b 4f1545f7, fcc1803b, 74f5e8b8).
Task 5: complete — 7cf2e6eb (O3 pageFlowBusy public, architecture_demo N6-gap → N6-closed; O4 PlanLocaleScope.push → @internal adoptLocale, TN-relocale same frame). Controller: stopped the agent (it was idling on background work) before touching files; own mutation (no adoptLocale) red on TN-relocale; full plan suite re-run +1579.
Task 6: implemented — 3ce50a94, 17b8ca60 (demo +15; macOS build OK). Old tests parked in test/_pending/*.dart.txt (demo → T7; events, badges, host_chrome, look → T8); Task 11 checks it is empty.
Ruling: the old package's theme_colours_test scans the demo's lib; the demo now polices its own colours (a demo invariant test) and the old test drops its demo root/entries — the one sanctioned edit to jet_cad_floor_plan (4b deletes it) — cost: none.
Ruling: the old sample JSON held only tables; the Salon gets a rectangular room (4 walls, a door, 2 windows) built before the tables; the Teras stays outdoor without walls — spec R3's walls — cost: an invented but plain room.
Fix round 1 (T6): 2e0d0300 — demo colour invariant + old test's demo root removed (old package diff: that one test file only); Salon room (4 walls, door, 2 windows, SW1/SW2). Controller mutation (stray Color literal) red, reverted; demo +20. Task 6: complete.
Parked for the final fix wave: the Salon room is wider than its A4 1:50 sheet (centrelines x 400..15250) — fit the page (A3 or 1:75) or narrow the margin.
Task 7: implemented — f2910334, 7bea05c8 (demo +53; main.dart 510 lines + area/statuses/groups/zones/table_menu/editor_profiles/side_panel). Controller review: stopped the idling agent first; the old demo's Ordered had no caption — the agent added one for a test; fix round 1 reverts it (host-supplied caption in ST-caption-tr). Tables profile shows the wall tool disabled, not hidden — library behaviour, the old tests did not pin it; accepted.
Fix round 1 (T7): f865fe9b — Ordered as the old demo; both caption tests use host captions. Controller mutation (maxCaption 12→99) red on ST-caption-tr, reverted clean. Task 7: complete (demo +53).
Budget mode (human, ~$85 left): after Task 8 the human runs /compact; then lean: Tasks 9+11 to one implementer, fix rounds only for real defects or weakened assertions (minors into the results note), one controller mutation + gates per task, short messages. If short: drop Task 10 (guide) first, then the iOS build; demo, POS1 and parity first. Stop only at a committed, clean point.
Task 8: complete — 416faa0f, ef9f6596, 61f37e9e, 08533d65 (demo +100, re-run by the controller; web build OK; test/_pending deleted, every row ported). Controller review lean (budget): tree clean, suite re-run; the agent's mutation list in its report.
Parked for the final fix wave (a real defect): Revert before any Save empties the plan (the old demo reverted to its sample) — Revert with no stored save must rebuild the area's sample (newPlan(build: sample)); a test: Revert on a pristine Salon keeps its 11 tables.
Noted: the planner's own Export flow dies with its editor on an area switch (library rule; writes nothing) — no demo mutation; M20 equivalent.
Dispatch T9+T11+fix wave (a,b) to one Sonnet implementer, base 08533d65; report task-9-report.md. Task 10 deferred until after.
Task 9 + Task 11 + fix wave (a,b): complete — e6e72a5b, f7e498a7, f34567a1, 026ad859, aafb2840. Demo +102 re-run by the controller, analyze/format clean. Controller mutation: Salon sheet A3→A4 → SW3 red, reverted clean. D10/DQ2 now expect the sample (Decided note; matches the old demo). Screenshot inspected: room inside sheet, statuses, G1, log. Look note: table 2's status caption overlaps a chair (minor, results note). One parity row open: guide/host probe (Task 10).
Dispatch Task 10 (guide) to a fresh Sonnet implementer, base aafb2840.
Task 10: complete — 9acb5767 (guide 29 blocks in the probe; probe builds outside the workspace). Controller mutation: guide snippet kit order swapped → check_guide exit 1, reverted clean. Controller fix 3819f358: SC16/DL2 were branch-caused (the restaurant kit missing from the CI matrices; the demo dropped its jet_cad_floor_plan line, 21→20) — tool/ci +131 green. Wrap-up: no whole-branch reviewer (human's rule); ledger archived; STATUS.
