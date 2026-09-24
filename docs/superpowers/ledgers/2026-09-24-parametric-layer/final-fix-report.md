# Plan 06 — final whole-branch review: fix-wave report

Branch `plan-06/parametric-layer`, starting at `af4149d`. One dispatch, all
six findings (F1–F6). No branch switch, no push, no merge.

## F1 (Important) — hovering the canvas wiped a typed value

**Change** (`apps/floor_planner/lib/selection_panel.dart`): `_load` now
tracks the box and `BoxParams` it last copied into the fields (`_loadedBox`,
`_loadedParams`) and returns immediately if neither changed since the last
load — a hover change and an unrelated document edit both notify without
changing either. Even when something did change, a field with focus is
never overwritten (`if (!_widthFocus.hasFocus && ...)`).

**Test:** `SE9` (`apps/floor_planner/test/selection_panel_test.dart`) —
select a box, type into Width (no commit), call
`view.selection.setHover(...)` (the real hover API), assert the typed text
survives; execute an unrelated `AddEntityCommand`, assert it still survives;
commit with Enter and assert the model and undo depth reflect the typed
value. (Hover is reset to `null` again inside the test, before the widget
tree tears down — `InteractionLayer._release` also clears hover on
`deactivate`/`dispose`, and leaving hover non-null at test end turns that
into a real, order-sensitive notification during the framework's own
teardown recursion; unrelated to this fix, confirmed by reproducing it
against the pre-fix `selection_panel.dart` and even with no box selected at
all.)

**RED → GREEN:** confirmed against the pre-fix `selection_panel.dart` (`git
show HEAD:...`): `SE9` failed with `Expected: '150' Actual: '120'`. Restored
the fix (`cp` backup / restore, `diff` clean) and `SE9` passes.

## F2 (Important) — `onTapOutside` is not focus-out

**Change:** each field now has its own `FocusNode` (`_widthFocus`,
`_heightFocus`), created in `initState`, disposed in `dispose`. Each
node's listener (`_onFocusChange`) commits that field's current text the
moment it loses focus — whichever field took the focus, or a tap outside
both. `onTapOutside` now only calls `.unfocus()` on that field's own node;
it no longer submits directly.

**Tests:** `SE8` re-pointed (comment updated to describe the focus-loss
path; same steps — tap outside the panel commits Width with no Enter).
`SE10` added: type into Width, tap Height, type into Height, Enter — model
ends at `width=150, height=90`.

**RED → GREEN:** confirmed against the pre-fix code: `SE10` failed
(`Expected: <150> Actual: <120.0>`) and `SE8`/`SE9` also failed there (F1
and F2 compound on the unfixed file). Restored the fix; all ten
`selection_panel_test.dart` tests pass.

**Mutant fired:** removed the body of `_onFocusChange` (`cp` backup of
`selection_panel.dart`). `SE8` and `SE10` both went red (`SE8`: assertion
failure on the tap-outside commit; `SE10`: `Actual: <120.0>`). Restored
from the backup, `diff` clean.

## F3 (Minor) — undo/redo index freshness was only incidentally tested

**No production change** — a test gap, closed with a test.

**Test:** `P13` (`packages/jet_cad_2d/test/parametric/regeneration_test.dart`)
— P4's shape (live `SpatialIndex`; A at width 500, then 2000 so both
re-clip), then `undo()` and `redo()`, checking `index.forEachInRect` finds
every child midpoint of A and B at each restored geometry.

**Mutant fired:** `ParametricReplay.capability` forced to return
`Capability.components` unconditionally (`cp` backup of
`parametric_system.dart`). `P13` went red: `Expected: non-empty, Actual:
Set:[]` — undo's capability summary reads as `components`, which
`SpatialIndex`'s listener explicitly skips (`spatial_index.dart:2611`), so
the index goes stale across the undo. Restored from the backup, `diff`
clean; full engine suite re-verified green.

## F4 (Minor) — the D6 guard's removal arm was looser than the spec

**Change** (`packages/jet_cad_2d/lib/src/parametric/regeneration.dart`,
`_refused`): a removed child in `G` is now refused when the owner's group
node still exists (`t.tree[owner] != null`), whatever its component is —
not only while `_isObject(t, types, owner)` (node **and** a registered
component) still holds. The delete cascade (children removed *together
with* the node) stays allowed, since by then `t.tree[owner]` is also gone.

**Test:** `P14` — `Compound([SetComponentCommand<ClipRect>(hA, null),
RemoveEntityCommand(firstChildOfA)])` throws `GeneratedGeometryError`;
bytes and undo depth unchanged.

**RED → GREEN:** ran `P14` against the pre-fix `_refused` (`git show
HEAD:...` into the file): failed with `Expected: throws
GeneratedGeometryError, Actual: returned null` (the compound was wrongly
allowed). Restored the fix; `P14` passes.

**Mutant fired:** reverted just the changed line back to
`_isObject(t, types, owner)` (`cp` backup). `P14` went red with the same
failure as above; `G3` (the delete cascade) was re-run under the same
mutant and still passed, confirming the mutant only affects the bundled-
detach case, not the legitimate cascade. Restored from the backup, `diff`
clean.

## F5 (Minor) — `drift()` did not guard re-entry

**Change** (`packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`,
`ParametricSystem.drift()`): wraps the survey + plan in
`_applying = true; try { ... } finally { _applying = false; }`, exactly the
guard `apply()` already sets around `_run`. A client `generate()` that
calls `execute()` during `drift()`'s dry run now hits the existing
reentrancy check in `_expand` and throws, instead of the command actually
landing.

**Test:** `G10` (`packages/jet_cad_2d/test/parametric/guards_test.dart`).
Deliberately does **not** reuse `Trip.reentrant`: that mode sets a `Trip`
on the same handle that is generating, so the resulting nested edit
re-triggers its own regeneration and trips the *existing* `apply()` guard
one level down — passing even with `drift()` unguarded, which was verified
and rejected as a test design. `G10` instead registers a small local
`ReentrantProbeType` whose `generate()` (when armed) issues a
`SetEntityGeometryCommand` on a **plain line owned by the root**, unrelated
to any parametric closure, so a successful reentrant execute has nothing to
re-plan and would actually land. Asserts `drift()` throws `StateError` and
the document's encoded bytes are unchanged.

**RED → GREEN:** ran `G10` against the pre-fix `drift()`: it failed with
`Expected: throws StateError, Actual: returned []` — the reentrant edit
landed for real (confirmed indirectly: the assertion failed before even
reaching the byte-comparison). Restored the fix; `G10` passes.

## F6 (docs)

- `docs/superpowers/notes/2026-09-24-plan-06-results.md`:
  - the Task 8 focus-out debt line and the `_sync` debt line each replaced
    with "fixed in the final-review fix wave", naming `SE8`/`SE9`/`SE10`;
  - the `drift()` re-entry debt line (found already present, describing
    exactly F5) also updated the same way, naming `G10`;
  - two new sub-project-07 debt items added: the swallowed-box selection/
    deletion gap (building on `N14`), and the doubled O(n²) neighbour
    search with the final reviewer's measured timings (0.7/4.3/16 ms at
    100/300/600 boxes, JIT);
  - a new "Final review" section: verdict **With fixes**, all five findings
    with what was fixed and which test pins each;
  - a new "The four gate lines, re-run after the final-review fix wave"
    subsection with this dispatch's own transcripts, and a note on the
    updated running totals (`jet_cad_2d` 950→953, `apps/floor_planner`
    67→69; the other two suites unchanged);
  - the "D13 is not amended" line corrected to point at the new D13
    amendment below it.
- `docs/superpowers/specs/2026-09-24-parametric-layer-design.md`:
  - D6: new "Amended at execution (Plan 06, final-review fix wave, F4)"
    paragraph;
  - D13: new "Amended at execution (Plan 06, final-review fix wave, F1/F2)"
    paragraph.

## Gate summaries (all four, re-run in full after all fixes)

**`packages/jet_cad_2d`**: `CI=true dart test`

```
00:03 +953: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +953: All tests passed!
```

Exit 0 (up from 950: `P13`, `P14`, `G10`). `dart analyze`: `No issues
found!`, exit 0. `dart format --output=none --set-exit-if-changed .`:
`Formatted 141 files (0 changed)`, exit 0.

**`packages/jet_cad_2d_flutter`**: `CI=true flutter test`

```
00:13 +925 ~1 -5: Some tests failed.
```

Exit 1 — **exactly** the five standing failures, named individually:
`text ladder rung 1..5 (RenderBackend.canvas)` in
`test/golden/text_ladder_golden_test.dart`, and nothing else (unchanged;
this fix wave touches nothing here). `flutter analyze`: `No issues found!`,
exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted
176 files (0 changed)`, exit 0.

**`apps/dev_harness_2d`**: `CI=true flutter test --concurrency=1`

```
00:19 +82: All tests passed!
```

Exit 0, unchanged. `flutter analyze`: `No issues found!`, exit 0. `dart
format --output=none --set-exit-if-changed .`: `Formatted 22 files (0
changed)`, exit 0.

**`apps/floor_planner`**: `CI=true flutter test`

```
00:03 +69: All tests passed!
```

Exit 0 (up from 67: `SE9`, `SE10`). `flutter analyze`: `No issues found!`,
exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted 19
files (0 changed)`, exit 0. `flutter build macos --release`: `✓ Built
build/macos/Build/Products/Release/floor_planner.app (51.4MB)`, exit 0.
`flutter build web --release`: `✓ Built build/web`, exit 0.

`git status --short` clean before and after every command; no
`analysis_options.yaml` rewritten by any `flutter analyze` / `flutter pub
get` step.

## Files touched

- `apps/floor_planner/lib/selection_panel.dart` (F1, F2)
- `apps/floor_planner/test/selection_panel_test.dart` (F1, F2)
- `packages/jet_cad_2d/lib/src/parametric/regeneration.dart` (F4)
- `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart` (F5)
- `packages/jet_cad_2d/test/parametric/regeneration_test.dart` (F3, F4)
- `packages/jet_cad_2d/test/parametric/guards_test.dart` (F5)
- `docs/superpowers/specs/2026-09-24-parametric-layer-design.md` (F6)
- `docs/superpowers/notes/2026-09-24-plan-06-results.md` (F6)

## Concerns

- **The `SelectionController.setHover` / `InteractionLayer` teardown
  interaction** discovered while building `SE9`: calling `setHover(...)`
  directly in a full-app widget test and leaving it non-null when the test
  ends turns `InteractionLayer._release`'s own teardown-time
  `setHover(null)` into a real, order-sensitive notification that can hit a
  `DEFUNCT`-but-still-`mounted` `State` mid-teardown
  (`setState()`/`markNeedsBuild() called during build`). Reproduced on the
  pre-fix `selection_panel.dart` and even with zero selection, so it is
  unrelated to F1/F2 and to any code this plan owns; worked around in
  `SE9` by resetting hover to `null` (with a `pump`) before the test's own
  body ends. Not filed as a new finding since it never reaches production
  code — it is a test-only interaction between two existing pieces of
  `jet_cad_2d_flutter` — but worth a look if a future test wants to leave
  hover set at teardown.
- **Criterion 14 (the human's look) remains OWED.** Untouched by this
  dispatch, as before.
- The two new sub-project-07 debt items (swallowed-box selection, doubled
  O(n²) neighbour search) are real but out of this plan's scope; recorded
  in the results note for 07 to pick up.
