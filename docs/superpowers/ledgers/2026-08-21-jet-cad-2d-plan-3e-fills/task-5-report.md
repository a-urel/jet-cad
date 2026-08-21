# Task 5 report: `SetEntityGeometryCommand`

## What changed

- `packages/jet_cad_2d/lib/src/document/commands.dart`: added `SetEntityGeometryCommand`,
  verbatim per the brief's Step 3, inserted between `SetComponentCommand` and
  `AddRegionCommand`. It:
  1. Refuses `EntityKind.fill` with the same message shape as `SetEntityTextCommand`.
  2. Reads the previous payload through `GeometryStore.read` (a defensive copy) before
     calling `GeometryStore.replace`, so the inverse never aliases the store's live buffer.
  3. Re-triangulates every dependent fill via `triangulationFor`, replacing the cached
     triangles with `FillIndex.putTriangles` or dropping them with the already-existing
     `FillIndex.dropTriangles` (confirmed present at `fill_index.dart:55` — not re-added,
     per the correction in the task instructions).
  4. Puts the boundary handle **and every dependent fill handle** into `touched`.
- `packages/jet_cad_2d/lib/src/document/fill_index.dart`: **not modified.**
  `dropTriangles` already existed from a prior task; the brief's Step-3 snippet for it
  would have been a duplicate.
- `packages/jet_cad_2d/test/document/region_command_test.dart`: appended the brief's four
  tests verbatim, with one necessary adaptation, plus one new test for T5d (see below).

### Adaptation required: `execute` is `void`

The brief's Step-1 test for "touches its fills" reads
`final result = doc.commands.execute(SetEntityGeometryCommand(...)); ... result.touched`.
In this codebase `CommandDispatcher.execute` returns `void` (`lib/src/document/undo.dart:102`)
— `CommandResult` never escapes it. No existing test in the suite captures `execute`'s
return value; the established pattern for observing `touched` synchronously
(`test/document/command_test.dart:148-165`) is `CommandDispatcher.onAfterMutate`, which
fires synchronously with a `DocChange` carrying `touched`. I used that instead:

```dart
Set<Handle>? touched;
doc.commands.onAfterMutate = (change) => touched = change.touched;
doc.commands.execute(SetEntityGeometryCommand(...));
...
expect(touched, contains(cmd.fill.handle), reason: '...');
```

Everything else in that test, and the other three brief tests, is verbatim.

### T5d: the added test, and the real verdict

The brief calls T5d (keeping the inverse's payload via `peek` instead of `read`) expected
to survive its four given tests, and asks for a test whose only shape is "two successive
edits to the same boundary followed by two undos." I added exactly that
(`'two edits then two undos: the inverse must not share the store\'s buffer'`).

**T5d survives even with that test.** Root cause, read from `GeometryStore.replace`
(`lib/src/store/geometry_store.dart:135-141`):

```dart
void replace(int slot, GeometryPayload payload) {
  _requireLive(slot);
  _payloads[slot] = GeometryPayload(
    coords: Float64List.fromList(payload.coords),
    scalars: Float64List.fromList(payload.scalars),
  );
}
```

`replace` never mutates an existing `GeometryPayload` object in place — it always builds
a **new** `GeometryPayload` with fresh `Float64List` copies and reassigns `_payloads[slot]`.
So a payload captured earlier by `peek` (which aliases `_payloads[slot]` at the time of the
call) is orphaned, not mutated, by any later `replace` on that same slot. The hazard the
`peek` doc comment on `geometry_store.dart:118-129` describes — "holding one past the next
edit to this slot gives a caller a payload that changes underneath it" — has no reachable
code path through `SetEntityGeometryCommand`, because nothing in this codebase writes into
a `GeometryPayload`'s `coords`/`scalars` arrays in place (confirmed by
`grep -rn '\.coords\[' lib/` — every hit is a read). This makes T5d a genuine surviving
mutant given the current store implementation, not a gap in the added test. Flagging this
per the task's "do not leave it unaccounted for" — see Concerns below.

## Suite output — `packages/jet_cad_2d`

```
$ CI=true dart test
...
00:02 +745: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:01 +746: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +747: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +748: test/invariants/query_allocation_test.dart: (tearDownAll)
00:02 +748: All tests passed!
```

Target file alone, all 11 tests (10 from the brief plus the T5d-catching test) named:

```
$ CI=true dart test test/document/region_command_test.dart
00:00 +0: loading test/document/region_command_test.dart
00:00 +0: the fill gets the lower handle, so it draws underneath
00:00 +1: apply refuses an inverted pair rather than drawing it wrong
00:00 +2: the fill names its boundary and the index links them
00:00 +3: the triangulation is materialised by the command, not by a draw
00:00 +4: an unfillable boundary is refused before anything is written
00:00 +5: undo removes both halves and redo restores the same handles
00:00 +6: editing a boundary re-triangulates and touches its fills
00:00 +7: the handle and the geomIndex survive the edit
00:00 +8: it refuses a fill, because a fill's payload is a reference
00:00 +9: undo restores the previous geometry and its triangulation
00:00 +10: two edits then two undos: the inverse must not share the store's buffer
00:00 +11: All tests passed!
```

```
$ CI=true dart analyze
Analyzing jet_cad_2d...
No issues found!
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 110 files (0 changed) in 0.14 seconds.
```

## Suite output — `packages/jet_cad_2d_flutter`

```
$ CI=true flutter test
...
00:02 +238 ~1: .../test/lineweight_test.dart: curves cannot be bypassed an anisotropic circle stays on the residual path and is counted
00:02 +239 ~1: .../test/lineweight_test.dart: curves cannot be bypassed an anisotropic arc is counted too
00:02 +240 ~1: .../test/lineweight_test.dart: curves cannot be bypassed a conformal circle is not counted
00:02 +241 ~1: .../test/lineweight_test.dart: curves cannot be bypassed the threshold is exclusive, so a circle exactly at 2.0 is not counted
00:02 +242 ~1: All tests passed!
```

(The `~1` is one pre-existing skip, unrelated to this task — present before any change here.)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 45 files (0 changed) in 0.06 seconds.
```

`git status --porcelain` after `flutter pub get` (run as part of `flutter analyze`/`flutter
test`) showed no `analysis_options.yaml` changes — only the two files listed above are
modified.

## Mutation transcripts

Procedure per the brief's Step 5, run inside one shell call each (mutate, test, restore),
with `diff /tmp/t5_report.dart "$F"` confirming the file was byte-identical to the
pre-mutation copy after every restore.

### T5a — drop the dependent fills from `touched` → **KILLED**

Mutation: `touched: {handle, ...dependents},` → `touched: {handle},`

```
00:00 +6 -1: editing a boundary re-triangulates and touches its fills [E]
  Expected: contains <18>
    Actual: Set:[19]
     Which: does not contain <18>
  the fill's indexed box is derived from this boundary; if the fill is not touched, SpatialIndex never re-derives it

  package:matcher                               expect
  test/document/region_command_test.dart 121:5  main.<fn>

00:00 +10 -1: Some tests failed.

Failing tests:
  test/document/region_command_test.dart: editing a boundary re-triangulates and touches its fills
```

### T5b — do not re-triangulate after the edit → **KILLED**

Mutation: deleted `target.fills.putTriangles(handle, triangles);` from
`SetEntityGeometryCommand.apply` (the `AddRegionCommand` call site at line 480 was
untouched, confirmed by `grep -n putTriangles` showing only that one surviving line).

```
00:00 +6 -1: editing a boundary re-triangulates and touches its fills [E]
  Expected: <12>
    Actual: <6>
  six vertices reduce to four triangles

  package:matcher                               expect
  test/document/region_command_test.dart 119:5  main.<fn>

00:00 +10 -1: Some tests failed.

Failing tests:
  test/document/region_command_test.dart: editing a boundary re-triangulates and touches its fills
```

### T5c — accept a fill → **KILLED**

Mutation: `if (record.kind == EntityKind.fill) {` → `if (false) {`

```
00:00 +8 -1: it refuses a fill, because a fill's payload is a reference [E]
  Expected: throws <Instance of 'StateError'>
    Actual: <Closure: () => void>
     Which: returned <null>

  package:matcher                               expect
  test/document/region_command_test.dart 146:5  main.<fn>

00:00 +10 -1: Some tests failed.

Failing tests:
  test/document/region_command_test.dart: it refuses a fill, because a fill's payload is a reference
```

### T5d — inverse reads via `peek` instead of `read` → **SURVIVED** (accounted for above)

Mutation: `target.geometry.read(record.geomIndex)` → `target.geometry.peek(record.geomIndex)`

```
00:00 +11: All tests passed!
```

Ran against all 11 tests including the added two-edit/two-undo test aimed exactly at this
mutation. See "T5d: the added test, and the real verdict" above for why it is unreachable
given `GeometryStore.replace`'s copy-on-write semantics — not a test-design gap.

## Concerns / things I was unsure about

1. **T5d is a real surviving mutant, not a missing test.** I traced it to
   `GeometryStore.replace` always allocating a fresh `GeometryPayload` + fresh
   `Float64List`s rather than mutating the stored object in place, so nothing in the
   current codebase can make a `peek`-based inverse observably diverge from a `read`-based
   one. The `read`/`peek` distinction is still correct defensive practice (and matches
   `RemoveEntityCommand`'s precedent, which also uses `read` for its inverse), so I kept
   the brief's `read` call — but flagging that the mutation itself is currently untestable
   by any command-level test, since it would require some other write path that mutates a
   stored payload's arrays in place, which doesn't exist. If a future task adds such a
   path (e.g. an in-place vertex-drag optimization), this would become a live hazard again.
2. The brief's Step-1 test source used `execute`'s return value directly; I adapted via
   `onAfterMutate`, matching the pattern already established in `command_test.dart`. Flagging
   this in case the reviewer wants the brief's literal shape reconciled some other way (e.g.
   if a later task changes `execute`'s signature to return `CommandResult`).

## Commit

Committed per the brief's Step 6 (see commit SHA in the top-level summary returned to the
controller). Files staged: exactly
- `packages/jet_cad_2d/lib/src/document/commands.dart`
- `packages/jet_cad_2d/test/document/region_command_test.dart`

(`fill_index.dart` was not staged: it was not modified, since `dropTriangles` already
existed.) No `analysis_options.yaml` changes; `git status --porcelain` confirmed clean
otherwise before committing.
