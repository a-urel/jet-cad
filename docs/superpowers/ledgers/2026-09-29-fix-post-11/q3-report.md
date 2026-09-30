# Q3 report: ParametricEdit refuses a parametric component off a live root-level group (post-11 (d))

**Commit:** `47a7fcb` on `fix/post-11`. Not pushed.
`fix(engine): ParametricEdit refuses a parametric component off a live root-level group (post-11 (d))`

## Guard shape
`packages/jet_cad_2d/lib/src/parametric/regeneration.dart`:
- `_written(t, types, before, r0.touched)` runs in `_run` right after `_refused`, before the cascade and the plan. It walks the touched handles in ascending order and skips any handle that is a live object after `inner` (`_isObject`). For each registered type it reads the component now on the handle (`_Registration.componentOrNull`, new in `parametric_system.dart`). It refuses the first non-null component that is not `==` to what the before-survey held for that type on that handle (`_heldBefore`).
- On a refusal, `_undoInner(t, label, r0, error)` runs and then `throw error`. Nothing is planned or pushed to history: the same path `_refused` takes.
- `_Survey.stray` is a new field: `Map<(Handle, _Registration), Component>`. It holds every registered component that the survey does not snapshot as an object's `params`. That means misplaced ones, plus the earlier registration's component when one object carries two registered types. It is filled inside the `r.handles(t)` walk the survey already makes, so it costs one insertion per such component and is empty in the app's documents. `_heldBefore` reads `params[h]` when the registration names the object, and `stray[(h, r)]` otherwise.
- **What is thrown:** `StateError`, with a message naming the edit, the type id and the handle, plus "not a live root-level group … (spec 06 D5)". I did not reuse `GeneratedGeometryError` because it names a generated child, which this is not. The precedent is the plan's refusal of a malformed boundary (`_ownBoundaryOf`), which is also a `StateError`. The comment at the throw site says so.
- **Doc comments:** `_written`, `_heldBefore`, `_Survey.stray` and step 3 of `_run` are documented. The doc of `diagnostics()` now says that `parametric.misplaced` stays, because a file can still bring one in (loading does not go through `ParametricEdit`) and a re-parented object keeps its component under spec 08 D4.

## Decision 1: which handles are checked (narrow form)
- **Chosen:** only `inner`'s own `r0.touched`. Cost: O(k log k + k·types) per edit, where k = |touched|. Nothing is paid per object beyond one insertion per stray component in the survey walk that already runs.
- **Refinement of the ruled condition (a deviation, needed):** the brief's rule was "touched, and now carries a non-null registered component, and is not a live root-level group". Taken literally, it refuses:
  - **every delete.** The removed object keeps its component until 06 D8's cleanup, which is planned after the guard.
  - **the re-parent in spec 08 D4.** `CS7` and `OB1` specify that a re-parented object stops being one and keeps its component.
  - **a move or removal of a holder that a file brought in misplaced.** This is an edit the app can reach.

  So the guard refuses only when the edit **wrote** the component, meaning it is not `==` to the before value. That comparison is on a stored value, so it is exact `==` per the non-negotiables; `identical` would be wrong (mutant M-Q3i). This refinement is what needs `_Survey.stray`.
- **Every-handle form (M-Q3f):** with the value comparison in place, checking every handle is equivalent for every engine command. A component write always touches its handle (`SetComponentCommand.touched == {handle}`), so an untouched handle's component cannot differ from its before value. The only thing the wide form would add is catching a custom command that under-reports `touched`, and it would cost O(components) per edit. Narrow was kept, as the brief prefers.

## Decision 2: what stays legal
- **Detach:** a null component is skipped, so a detach is legal on any handle, whether dead, nested, or the cleanup's own.
- **Undo and redo:** they replay `ParametricReplay` and never enter `_run`. Replaying a re-attach before the node is restored is therefore untouched.
- **Non-parametric components:** only registered types are read, so any other component lands as before.

## Red before the fix
File `packages/jet_cad_2d/test/parametric/misplaced_test.dart` (MP1–MP8 at that point), run with the engine unchanged: exit 1, `+4 -4`. Transcript: scratchpad `q3-red-before.txt`.

| Test | Result without the fix |
|---|---|
| MP1 (dead, never-allocated, nested) | red: "Expected: throws StateError … '7D7' … Actual: returned <null>" |
| MP3 (compound) | red at `7D6` |
| MP6 (writing a new value on a file's misplaced line) | red at `7D8` |
| MP8 (Hinge written on B while deleting B) | red at `7D0` |
| MP2 (control), MP4 (detach), MP5 (delete/undo/redo/undo), MP7 (non-parametric) | green by design: these kill mutants |

MP9 (an object carrying two registered types can be deleted) was added afterwards to kill M-Q3l. It was not run before the fix.

## Tests (MP1–MP9)
Every test uses `Hinge`, the 4th registration (not the first). All groups are rotated and off the origin, next to two live ClipRects (A, B).

| Test | What it checks |
|---|---|
| MP1 | Refused on a deleted group, a never-allocated handle and a nested group. Bytes (`enc`), undo depth and store are unchanged, and `diagnostics()` is empty. |
| MP2 | Control: a live root-level group generates 2 children, and undo restores it. |
| MP3 | A compound whose legal child edits A's ClipRect is refused as a whole. |
| MP4 | Detaching a file's misplaced Hinge from a dead handle and from a nested group works, with undo and redo. |
| MP5 | A live Hinge object across A's top edge: delete, undo, redo, undo all replay. |
| MP6 | With a file's misplaced Hinges present, these are not refused: an unrelated move, a move of their line, re-writing an `==` value (the loaded instance is not `identical`), removing their nested group. Writing a new value is refused. |
| MP7 | A non-parametric `Note` on a dead handle lands inside a wrapped edit and undoes. |
| MP8 | A delete of B plus a Hinge write on B in one compound is refused, and B stays live with its ClipRect. |
| MP9 | A ClipRect+Hinge object can be deleted and undone. |

Existing tests that built stray components through an edit are now refused, so they now write the component straight into the store, the way a file brings one in:
- **Engine:** `N11` (`neighbourhood_test`), `DG2` (`diagnose_test`), `OB1` (`objects_of_test`, the nested Caption only; its re-parent step still goes through the edit and is not refused). `N11` also gained a holder edit (a move of the line), which pins "not refused, still not regenerated".
- **App:** `EP6` (`opening_end_drag_test`), `HF9` (`opening_geometry_test`), `OT1` (`opening_tool_test`), `RI1` (`room_inputs_test`). The node adds stay as an edit.

## Mutants
Procedure: cp backup to the scratchpad (`q3-*.bak`), mutate, run `CI=true dart test test/parametric` (118 tests), cp back, `diff`. Every `diff` exited 0 for `regeneration.dart`, `parametric_system.dart` and `commands.dart`. Outputs are in the scratchpad, `q3-mut-<x>.txt`. Line numbers refer to `misplaced_test.dart` as committed.

| Mutant | Change | Result |
|---|---|---|
| M-Q3a | Guard removed | **red** (4): MP1 l.120, MP3 l.158, MP6 l.251 (new-value write), MP8 l.284 |
| M-Q3b | Liveness only (`t.tree[h] is GroupNode` instead of `_isObject`, so a nested group passes) | **red** (2): MP1 l.120 (nested `7D6`), MP3 l.158 |
| M-Q3c | Also refuses null (the `now == null` skip removed) | **red** (4): MP4 l.186; also CS6, CS8, G9 |
| M-Q3d | Throws without `_undoInner` (state leaks) | **red** (4): MP1 l.125 (`enc`), MP3 l.164 (A's ClipRect), MP6 l.255, MP8 l.290 |
| M-Q3e | Guard moved into `SetComponentCommand.apply` (non-null value on a handle that is not a root-level group throws), removed from `_run` | **red** (25): MP5 l.212, the **undo**. The stack goes `SetComponentCommand.apply` ← `CompoundCommand.apply` ← `ParametricReplay.apply` ← `CommandDispatcher.undo`, "7D9 is not a live root-level group". Also G3, CS1–CS3, CS6, CS7, CS10–CS12, SV1–SV3, DV1, OB1, PG1, PG2, RG6 and the rest of MP |
| M-Q3f | Every handle checked (all registered handles ∪ touched), value comparison kept | **survives**: equivalent for every command that reports its writes in `touched` (see Decision 1) |
| M-Q3f′ | Every handle checked **and** no value comparison (the naive wide form) | **red** (29): MP6 l.231 (the **unrelated** `TransformNodeCommand(hA)`), N11 l.192, MP4, MP5, MP8, MP9, G3, G6, CS1…, OB1, … |
| M-Q3g (own) | Command-scanning form, any component type (walk `inner` for a non-null `SetComponentCommand` off a root-level group) | **red** (9): MP7 l.267 (the non-parametric Note); also MP1, MP3, MP6, MP8, SV1, SV2, PG1, PG2 |
| M-Q3h (own) | Value comparison dropped, touched only (the brief's literal rule) | **red** (28): MP5 l.208 (the delete itself), MP6 l.234, MP8, MP9 l.307, N11, G3, G6, CS1–CS5, CS7, CS9–CS12, DR1, LV1, LV2, SV3, DV1, OB1, PG1, SD6, SD10, RF6, RG6 |
| M-Q3i (own) | `identical` instead of `==` | **red** (1): MP6 l.242 (re-writing the `==` loaded value) |
| M-Q3j (own) | Misplaced before-values not recorded in `stray` | **red** (2): MP6 l.234 (moving the line), N11 l.192 |
| M-Q3l (own) | The shadowed registration's before-value not recorded | **red** (1): MP9 l.307 |

## App paths (grep of every app `SetComponentCommand`)
- **Covered, cannot hit the guard:**
  - The tools (box, wall, separator, room, opening, dimension) and `startup_plan` add the group with `parent: doc.rootHandle` in the same compound.
  - `selection_panel` re-checks `_isObject<T>` (a root-level group).
  - The object grips (opening, room, dimension, separator) act on the selected root-level group (OG2).
  - `wall_grips._keptPut` filters for liveness.
  - `page_panel`'s `PageComponent` is not a registered parametric type.
- **One path hits the guard with a file:** `wall_grips._endsAt` has no liveness filter (post-11 (e)). A scratch probe, run and then deleted (never committed), built a wall plus a file-style orphan `WallParams` on a node-less handle whose start sits on the wall's end. `WallGrips().drag` returned a compound `[FA0, 1450]`, and `execute` threw: `Bad state: "Move wall ends": floor_planner.wall written on 1450, which is not a live root-level group after the edit, would never be regenerated (spec 06 D5); the edit is refused`.
  - Before this fix, the orphan was silently moved with the wall.
  - Now the select tool's pointer-up rethrows it (`select_tool.dart` ~l.425).
  - **(e)'s liveness filter, scheduled for Q1+Q2 on this branch, must land before merge.** Spec 06 D6's amendment records this.

## Gates (`export PATH=/root/flutter/bin:$PATH`)
- **Engine** (`packages/jet_cad_2d`):
  - `CI=true dart test`: exit 1, `+1087 -2`. The two failures are the standing `test/testing/generate_document_test.dart` pair ("both text fractions…", "the default document…"). 1078 + 9 new = 1087.
  - `dart analyze`: exit 0, "No issues found!"
  - `dart format --set-exit-if-changed`: exit 0, "0 changed".
- **Render** (`packages/jet_cad_2d_flutter`):
  - `CI=true flutter test`: exit 1, `+940 ~1 -7`. The seven failures are exactly the standing `text_ladder` rungs 1–5 and `text_lod_ladder` rungs 1–2.
  - `flutter analyze`: exit 0.
  - `format`: exit 0, "0 changed".
- **App** (`apps/floor_planner`):
  - `CI=true flutter test`: exit 0, `+491: All tests passed!`
  - `flutter analyze`: exit 0.
  - `format`: exit 0, "0 changed".
  - `flutter build web --release`: exit 0, "✓ Built build/web".
  - Before the four app fixtures were converted, the same run was `+487 -4` (EP6, HF9, OT1, RI1), all refused at "Add strays".
- The allocation invariants (`query_allocation_test`, `paint_allocation_test`) are in those runs and passed. The guard is on the edit path only.

## Deviations
1. **The guard's condition is "wrote", not "carries"** (see Decision 1). The literal rule contradicts spec 08 D4 (`CS7`, `OB1`) and 06 D8 (deletes).
2. **Seven existing fixtures changed** (N11, DG2, OB1, EP6, HF9, OT1, RI1): they now write their strays into the store directly. Their assertions are unchanged; N11 gained a holder edit.
3. **Where the spec paragraph sits:** it is in D6, where `_refused` is specified, with a one-line pointer in D5. `analysis_options.yaml` is not committed, and no `.dart` file was checked out.

## Found, outside scope (reported, not fixed)
- **(e) interaction** (above): Q2 must add the liveness filter to `wall_grips._endsAt`. Otherwise a file with an orphan wall at a joint makes that joint's drag throw.
- **Pre-existing:** 06 D8's cleanup detaches only the before-survey's naming registration (`before.objects[h]`, the last registered type on the handle). An object carrying two registered types leaves the other component orphaned on the dead handle after a delete. In MP9, ClipRect stays on dead hA; the test does not assert on it. This fix does not change that. The guard allows it because the delete does not write the component. No app path creates a two-type object.
- **Pre-existing, noted in passing:** the comment in `opening_end_drag_test` read "no tool or file path makes these". A file can, so it now says "only a file brings them in".
