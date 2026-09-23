# Task 6 report — `GripDrag`

## What I implemented

`packages/jet_cad_2d_flutter/lib/src/grip_drag.dart`, exactly as the brief's
Step 3 code, plus the export in `lib/jet_cad_2d_flutter.dart` after
`src/grip_cache.dart`, and the test file
`test/grip_drag_test.dart` exactly as the brief's Step 1 code.

- `enum DragKind { band, move, rotate, reshape }`
- `const double kRotationStep = math.pi / 12;`
- `final class GripDrag` with:
  - `static GripDrag? move(DraftDocument, Iterable<SelectionKey>)`
  - `static GripDrag? rotate(DraftDocument, Iterable<SelectionKey>, Vector2 pivot, Vector2 press)`
  - `static GripDrag? reshape(DraftDocument, SelectionKey, Grip)`
  - press-time captures (`_LeafCapture` holds a `read` copy of the payload,
    `_NodeCapture` holds the `Node` value), sorted ascending by target handle
  - `base`/`target` (world `Vector2`), `theta`, `transform`,
    `previewPayload`, `leafKind`, `capabilities`, `permittedBy`
  - `moveTo` (move/reshape), `rotateTo` (rotate, θ normalised to `(−π, π]`
    per Ruling 03-14, shift rounds to the nearest `kRotationStep`)
  - `command(DraftPermissions)`: revalidates captures against the live
    document, builds member commands (`SetEntityGeometryCommand` via
    `rigidTransformLeaf` for root leaves, `TransformNodeCommand(h,
    T.multiply(node.transform))` for groups/instances, `SetEntityGeometryCommand`
    via `reshapeLeaf` for a reshape), returns `null` for a no-op drag or a
    permission refusal on any member, else one `CompoundCommand` labelled
    `Move`/`Rotate`/`Stretch` with members in ascending target-handle order.

No deviation from the brief's code. I verified every symbol it calls
(`leafGrips`, `reshapeLeaf`, `rigidTransformLeaf`, `Grip`/`GripRole`,
`SetEntityGeometryCommand`, `TransformNodeCommand`, `CompoundCommand`,
`DraftPermissions`, `Capability`, `Node`/`GroupNode`/`InstanceNode ==`,
`DraftDocument.{tree,entities,geometry,commands,handleSeed,rootHandle}`,
`EntityStore.{slotOf,kindAt,geomIndexAt}`, `GeometryStore.{read,peek}`,
`CommandDispatcher.{execute,undo,undoDepth,permissions}`,
`AddRegionCommand.allocate`, `TrueColor`, `ByLayerColor`,
`ReservedHandles.layerZero`, `SelectionKey`) against the current source
before writing anything, and every call site in the brief's code matches the
real signatures.

## TDD evidence

**RED** — `CI=true flutter test test/grip_drag_test.dart` before
`grip_drag.dart` existed:

```
Error: Undefined name 'GripDrag'.
Error: Undefined name 'DragKind'.
... (repeated across the file)
00:00 +0 -1: Some tests failed.
Failing tests:
  .../test/grip_drag_test.dart: loading .../test/grip_drag_test.dart
```

Expected: the brief's Step 2 predicted a compile error because
`grip_drag.dart` did not exist. Confirmed.

**GREEN** — `CI=true flutter test test/grip_drag_test.dart` after adding
`lib/src/grip_drag.dart` and the export:

```
00:00 +0: a move is one CompoundCommand labelled Move, members in ascending handle order (M-03an)
00:00 +1: a rotated group moves by T.multiply(node.transform) (M-03i)
00:00 +2: an instance move rewrites the instance node, never the definition (M-03c)
00:00 +3: a rotate is labelled Rotate and turns an arc's start angle (M-03h)
00:00 +4: a reshape is one CompoundCommand labelled Stretch
00:00 +5: a drag that changes nothing builds no command (M-03p)
00:00 +6: release revalidates against the press-time captures (M-03t)
00:00 +7: a refused member cancels the whole drag (M-03k)
00:00 +8: fills are skipped; a fills-only selection has no drag (M-03am)
00:00 +9: undo restores every stored value with == (spec D11; M-03e is the designed survivor)
00:00 +10: the undo assertion enforces ==: one ulp is caught (M-03e companion, Ruling 03-20)
00:00 +11: All tests passed!
```

Exit code 0. 11/11 pass, no skips.

## Gate line output

`packages/jet_cad_2d`:

```
$ CI=true dart test
...
00:03 +888: All tests passed!

$ dart analyze
Analyzing jet_cad_2d...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 130 files (0 changed) in 0.23 seconds.
```

`packages/jet_cad_2d_flutter`:

```
$ CI=true flutter test
...
00:11 +817 ~1 -5: Some tests failed.
Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

Exit code 1 — exactly the five standing golden failures the standing
instructions document (`+817 ~1 -5`, up from the prior task's baseline of
806 pass + 1 skip; this task added 11 tests: 806 + 11 = 817). No other
failures.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.7s)

$ dart format --output=none --set-exit-if-changed lib/src/grip_drag.dart lib/jet_cad_2d_flutter.dart test/grip_drag_test.dart
Formatted 3 files (0 changed) in 0.01 seconds.
```

Note: `dart format` (run once, without `--set-exit-if-changed`, before the
gate check above) reformatted `grip_drag.dart`'s multi-line parameter lists
and `grip_drag_test.dart`'s wrapped `test(...)` calls and a couple of
multi-line collection literals — whitespace only, no semantic change. Ran
the full `grip_drag_test.dart` suite again afterward (still 11/11 green,
shown above) before treating format as done. `git status --short` showed no
`analysis_options.yaml` change from `pub get`.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/grip_drag.dart` (new)
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (added the
  export line after `src/grip_cache.dart`)
- `packages/jet_cad_2d_flutter/test/grip_drag_test.dart` (new)

## Self-review

- Checked every named mutant the brief's tests target has a corresponding
  assertion that would go red under it: ascending handle order (M-03an) is
  asserted directly against `[s.line, s.arcNeg, s.group, s.instA]`, which is
  not sorted-by-insertion order (`s.instA` was passed first in the `keys`
  iterable and sorts last by handle); the rotated-group multiply order
  (M-03i) is asserted against the specific `T.multiply(node.transform)`
  order, not the reverse, and the fixture's group really is rotated
  (`g0.transform.b != 0`); instance-vs-definition (M-03c) checks the
  *other* instance and the shared definition are untouched; the no-op tests
  (M-03p) hit all three no-op paths (zero Δ, zero θ, unchanged reshape
  payload, degenerate reshape) and assert `undoDepth == 0`; revalidation
  (M-03t) exercises leaf-changed, node-changed, and gone-entity, each via a
  real `execute`, not a hand-rolled mutation; the permission test (M-03k)
  checks both `capabilities` and `permittedBy` before checking `command`
  returns null, and that a single-node-only drag *is* permitted under
  `runtime` — so a mutant that made all-or-nothing "any" instead of "every",
  or vice versa, would be caught either way; fills-only (M-03am) checks both
  that a fill-only selection yields no drag at all and that a mixed
  selection drops the fill from `command.children`.
- Confirmed `GeometryPayload ==`, `GroupNode`/`InstanceNode ==` are exact
  (read the source), so the D11 undo test and its Ruling-03-20 companion are
  really exercising `==` and not some looser comparison.
- No `Transform2 ==` is used anywhere in the test (it is object identity);
  every `Transform2` comparison in the tests reads individual `a..f` fields
  or uses `closeTo`.
- `capabilities` getter and the `command()` all-or-nothing check both read
  live off `_captures`/`members`, never cached, consistent with Ruling
  03-5's spirit for this layer (this task does not touch `GripCache`, which
  is where that ruling's own cost note applies).
- No dead code, no unused imports (`flutter analyze` confirms), file is
  formatted.

## Concerns

None. The brief's code compiled and passed against the actual API surface
without any change.
