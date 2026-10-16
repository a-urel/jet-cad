# 3a whole-branch review (Opus), 7e65905b..945502cb

The controller copied this from the reviewer's hand-back message. The reviewer delivered its report as a message, not as a file. The fix wave that followed is in `fix-wave-brief.md` and `fix-wave-report.md`, and the ledger records its re-review verdict.

**Verdict: Ready to merge.** No Critical findings, no Important findings, eight Minor.

## Passes
1. Plan: the Shared interfaces, Global Constraints and Review Focus sections. Ledger: every `Ruling:` line. The parked-minors list.
2. Contract diff: barrels, properties, plan_type, plan_services, plan_tool, plan_kit, the new model files, FakePlanServices.
3. Plan-library diff: plan_controller, guard, locks, services, the property panel, the editor, shortcuts, the moved symbol-box users, SharedCache.
4. The kit's caches and every reader: live.dart, WallBands, RoomInputs, WallFaces and its provider, DimensionGrips, and the wall, opening, room, separator and dimension tools.
5. The non-negotiables in new paint and overlay code, and the Review Focus tests.
6. TL8, run once in each package, and the attach hot path.

The per-task reviews already diffed the ported files line by line, so this review did not repeat that. The tree stayed read-only.

## Strengths (summary)
- The freeze pattern holds at every reader. Each `generation` read follows a read that re-checks liveness: room_tool.dart:311, opening_tool.dart:325/330/340, wall_faces.dart:120.
- The Task 13 question is resolved. The engine builds `referrers` from a survey that skips frozen objects (`jet_cad_2d/.../parametric_system.dart:585`), so a frozen opening is not a cut source. C1.10's lock on the opening's host keeps the drawn cut, which matches C1.5.
- Disposal is right. Shared caches go through SharedCache and FakePlanServices and are disposed last-made-first. No tool disposes a shared cache, and every `changes.listen` is cancelled.
- The plan library is careful:
  - `_refusal` is one rule.
  - The notice is re-bound on every tool change and at the end of `_open`, and removed in `dispose`.
  - `_GuardedNotice` catches a throw from both the value and the listener.
  - The choice-row focus map is bounded.
  - `prepare` and build run in the right order.
- The contract is coherent: PlanSection, `needsObject` checked through validate, and KitText compared by value.
- The boundaries hold. Nothing changed under the old packages or apps/. The kit does not import the plan library. The integration package has no `src/` imports.
- Draw order follows handles, and exact `==` is used only for memo keys and stored values.
- New paint code allocates O(1) per frame.

## Minor
- **M1. TL8's face line is over D12's 1,000 µs, but the old line has the same cost.** Kit `on the face line 1488 us`; old line `1499 us`. The two runs were concurrent. The hot path is `_wallPointsOf` → `wallsInDocument`, which runs over every wall. The proposed fix, a follow-up, is neighbour-only layout.
- **M2. The liveness re-check costs O(objects × the catalog's types).** WT12 went from 38 to 75 µs and OT4 from 44 to 97 µs as the test catalog grew to six types. This strengthens the `PlanServices` liveness-revision follow-up.
- **M3. The Room and Separator tools run the liveness pass several times per event.** Fixed in the wave (A1).
- **M4. A second failing build or prepare is not reported.** Fixed in the wave (A2).
- **M5. PlanObject has no live view.** `openingPositionRange` uses the kit-private `kitTypeIdOf`. This is a contract amendment candidate for 3b.
- **M6. `@internal` ignores across 19 files.** The wave (D2) moved them to line level.
- **M7. DimensionGrips keeps its subscription after a cancelled drag.** Harmless.
- **M8. Review Focus 5's room half is tested only in the kit.** Optional to extend.

## Declined to judge
- The neighbour un-join spec question.
- The one-frame locale lag.
- The 2a drag snap.
- M-IA-3 green on SS16.
- Sample-flat names staying English when the locale arrives after the build.
- `build` being ignored when `json` is given.
- GuardedGrips swallowing `ArgumentError`, as C1.8 (1) specifies.
- plan.select swallowing `ArgumentError` at the drop, as C1.8 (2) and ruling 75 specify.
- `numberedNameIndex` matching only a trailing number.
- Allocations on the pointer path that the old line already had.
- Line-level parity of the ported files.
- The full package gates, which were not re-run; only TL8 was run.

## Recommendations
1. Bring the PlanServices liveness revision forward (M2, M3).
2. Add neighbour-only `wallsInDocument` for the dimension attach and grip memos (M1, and GE5b at 7.2 ms).
3. In the fix wave: M4, M6, and the M3 flag. Done.
4. Take M5 (`PlanObject.liveTypeIdOf`) to 3b as a contract amendment.
