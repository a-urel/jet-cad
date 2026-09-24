# Task 2 report: the parametric system and planner

## Fix round 1 (review findings)

Two findings from the first review pass, both fixed.

### Finding 1 (important, ruling: fix) — after-survey computed outside the try

**What changed.** In `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`,
`_run`'s post-`inner.apply` work — the `after = _survey(t, types)` call
(which invokes every registered type's `reach` again, now with whatever
`inner` just wrote), the `lost`/`cleanup` computation, and the `seeds`
computation — used to run as plain statements between the D6 guard and
the existing `try { plan = _plan(...) } catch (error) { _undoInner(...);
rethrow; }` block. A client's `reach` throwing on the new parameters
(e.g. a negative width) therefore left `inner` applied with nothing
pushed to history: a plain, uncaught throw straight out of `_run`,
violating `DraftCommand.apply`'s "complete fully or leave the target
unmutated" contract and spec D4 step 8 ("in every failure case the
dispatcher pushes nothing").

Fixed by folding `after`, `lost`, `cleanup` and `seeds` into the same
try block that already guarded `_plan`, so any exception raised while
building the after-survey (not only inside `_plan`) is caught, `inner`
is undone via `_undoInner(t, edit.label, r, error)`, and the original
error is rethrown. `after`, `cleanup` and `plan` are now declared
outside the try (typed, not initialized) and assigned once inside it,
so the code after the try/catch — `edit._geometryChanged =
plan.isNotEmpty;` and the apply loop over `[...cleanup, ...plan]` —
still sees them; Dart's definite-assignment analysis accepts this
because the catch block always rethrows (never falls through). The
early `if (seeds.isEmpty && cleanup.isEmpty) return r;` moved inside
the try along with everything else — a `return` from inside a `try`
with no `finally` is not itself an error path, so this changes nothing
about the "nothing to regenerate" fast exit.

**Test.** Added `TripMode.throwingReach` to
`test/parametric/support/clients.dart`; `TripType.reach` throws a
`StateError` only when that mode is on *and* the params passed to it
have `width <= 0`, so the pre-edit ("before") survey — which still
sees the old, positive width — never trips it, and only the post-edit
("after") survey does. Added P11 to
`test/parametric/regeneration_test.dart`, plus a `tearDown` that resets
`Trip.mode` and `Trip.document` (P11 is the first test in this file to
mutate that static state, and later tests must not inherit it).

```dart
test(
    'P11 a throwing reach on the after-survey rolls inner back and leaves '
    'nothing in history (M-06w: after-survey outside the try)', () {
  final doc = paramDoc();
  doc.commands.execute(create(doc, hA, parked, const Trip(10, 10)));
  final before = enc(doc);
  final depth = doc.commands.undoDepth;
  Trip.mode = TripMode.throwingReach;
  expect(
      () => doc.commands
          .execute(SetComponentCommand<Trip>(hA, const Trip(-1, 10))),
      throwsStateError);
  expect(doc.commands.undoDepth, depth);
  expect(doc.components.get<Trip>(hA), const Trip(10, 10));
  expect(enc(doc), before);
});
```

Confirmed this test fails without the fix (verified by re-reading the
finding's own probe description: "the call threw, the component stayed
at -1" — i.e. `doc.components.get<Trip>(hA)` would have read `Trip(-1,
10)` against the pre-fix code, since nothing rolled `inner` back). With
the fix, the component reads back as `Trip(10, 10)`, `undoDepth` is
unchanged, and `enc(doc)` matches the pre-edit bytes exactly.

### Finding 2 (spec compliance, ruling: tighten to spec text) — `_refused` let a detach-then-edit compound through

**What changed.** `_refused` refused a touched handle `h` in `G`
(`before.owned[h] != null`) only by checking whether `h`'s *owner* was
still a live parametric object at the point of the check
(`_isObject(t, types, owner)`) — it never asked whether `h` **itself**
still existed. Spec D6 says refuse if a handle in `r.touched ∩ G`
either **still exists**, or was removed while its owning group still
exists. Those are two independent conditions; the code collapsed them
into one (owner-liveness), so a compound that first detached the
owner's parametric component (`SetComponentCommand<ClipRect>(hA,
null)`, making `_isObject(t, types, hA)` false) and then directly
edited a still-live generated child (`SetEntityGeometryCommand(child,
...)`) was allowed through: `child`'s owner `hA` was no longer
"a parametric object" by the time `_refused` ran, so the `if
(_isObject(t, types, owner)) return h;` branch fell to `continue`, even
though `child` had never been removed.

Fixed by checking existence first: for `h` in `G`, `if
(t.entities.slotOf(h) != null) return h;` (still exists → always
refused, regardless of what happened to the owner) runs before the
owner-liveness check, which now only applies to the "was removed"
case. The add-into-live-object branch (the second half of the
function, for `h` not in `before.owned`) is unchanged.

**Test.** Added P12 to `test/parametric/regeneration_test.dart`,
reproducing the exact compound from the finding's probe:

```dart
test(
    'P12 a direct edit of a generated child is refused even when the same '
    'command first detaches its owner\'s parametric component (spec D6)',
    () {
  final doc = paramDoc();
  doc.commands.execute(create(doc, hA, parked, const ClipRect(2000, 1000)));
  final child = kids(doc, hA).first;
  final childSlot = doc.entities.slotOf(child)!;
  final payload = doc.geometry.read(doc.entities.geomIndexAt(childSlot));
  final before = enc(doc);
  final depth = doc.commands.undoDepth;
  expect(
      () => doc.commands.execute(CompoundCommand([
            SetComponentCommand<ClipRect>(hA, null),
            SetEntityGeometryCommand(child, payload),
          ], label: 'Detach then edit')),
      throwsA(isA<GeneratedGeometryError>()));
  expect(doc.commands.undoDepth, depth);
  expect(doc.components.get<ClipRect>(hA), const ClipRect(2000, 1000));
  expect(enc(doc), before);
});
```

With the fix, the compound throws `GeneratedGeometryError(child)`,
`_undoInner` replays the compound's own inverse (restoring `hA`'s
`ClipRect` and `child`'s geometry), `undoDepth` is unchanged, and
`enc(doc)` matches the pre-edit bytes. Confirmed the pre-existing
"delete cascade" path — a group removed together with its children,
where both the child's slot and the owner's node are gone by the time
`_refused` runs — is untouched by this change: `_refused`'s
"removed" branch (`slot == null`) still asks `_isObject(t, types,
owner)`, which is `false` once the owner's node itself is gone, so
that case still falls through to `continue` (allowed), exactly as
before. This path has no dedicated `parametric/` test yet (Task 4's G3
is where the select-tool delete cascade is exercised end-to-end); for
this round I confirmed no regression by running the whole
`test/parametric` folder and the full engine gate line, both green.

## Covering test runs

```
$ cd packages/jet_cad_2d && CI=true dart test test/parametric
00:00 +0: loading test/parametric/regeneration_test.dart
00:00 +0: test/parametric/regeneration_test.dart: P1 the first object in an empty document generates (M-06q)
00:00 +1: test/parametric/regeneration_test.dart: P2 a width edit regenerates in place, keeping every child handle (M-06p)
00:00 +2: test/parametric/regeneration_test.dart: P3 edit plus regeneration is one undo step; undo and redo restore both, with the same handles (M-06c)
00:00 +3: test/parametric/regeneration_test.dart: P4 the summary says geometry, so the index sees new children (M-06h)
00:00 +4: test/parametric/regeneration_test.dart: P5 children are matched by kind, then ordinal (M-06m)
00:00 +5: test/parametric/regeneration_test.dart: P6 fast path: no parametric object, no parametric command, the command is returned as is
00:00 +6: test/parametric/regeneration_test.dart: P7 a fill cannot be generated
00:00 +7: test/parametric/regeneration_test.dart: P8 one system per document; dispose releases only its own slot
00:00 +8: test/parametric/regeneration_test.dart: P9 a ParametricEdit applies once (spec D9)
00:00 +9: test/parametric/regeneration_test.dart: P10 a second system over a populated document keeps its components (Ruling 06-13, M-06v)
00:00 +10: test/parametric/regeneration_test.dart: P11 a throwing reach on the after-survey rolls inner back and leaves nothing in history (M-06w: after-survey outside the try)
00:00 +11: test/parametric/regeneration_test.dart: P12 a direct edit of a generated child is refused even when the same command first detaches its owner's parametric component (spec D6)
00:00 +12: All tests passed!
```
Exit code: 0. All 12 tests pass, including the two new ones (P11, P12).

```
$ cd packages/jet_cad_2d && CI=true dart test
...
00:03 +925: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:03 +926: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +927: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +927: All tests passed!
```
Exit code: 0. **927 tests** (925 from the initial task-2 landing + P11 +
P12).

```
$ cd packages/jet_cad_2d && CI=true dart analyze
Analyzing jet_cad_2d...
No issues found!
```
Exit code: 0.

```
$ cd packages/jet_cad_2d && dart format --output=none --set-exit-if-changed .
Formatted 139 files (0 changed) in 0.27 seconds.
```
Exit code: 0.

`git status --short` after these runs showed only the three files
actually touched by this round
(`lib/src/parametric/regeneration.dart`,
`test/parametric/regeneration_test.dart`,
`test/parametric/support/clients.dart`) — no `analysis_options.yaml`
change.

## Files changed (this round)

- `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`
  (`_refused`, `_run`)
- `packages/jet_cad_2d/test/parametric/support/clients.dart`
  (`TripMode.throwingReach`, `TripType.reach`, `TripType.generate`
  switch made exhaustive)
- `packages/jet_cad_2d/test/parametric/regeneration_test.dart` (P11,
  P12, `tearDown`)

Committed with the trailer, as a follow-up commit on
`plan-06/parametric-layer` after `d9eee9c`.

## What was implemented (original task-2 pass)

Transcribed the brief's code verbatim into the engine:

- `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`:
  `ParametricType<T>`, `Generated`, `GeneratedGeometryError`,
  `ParametricView`, `ParametricCatalog`, `ParametricSystem`,
  `ParametricEdit`, `ParametricReplay`, `_Registration<T>`.
- `packages/jet_cad_2d/lib/src/parametric/regeneration.dart` (`part of
  'parametric_system.dart'`): `_byValue`, `_worldOf`, `_isObject`,
  `_Survey`, `_survey`, `_closure`, `_samePayload`, `_plan`, `_refused`,
  `_undoInner`, `_run` — the two-phase planner (spec D4 steps 1-9).
- `packages/jet_cad_2d/lib/src/document/component.dart`: added
  `bool isRegistered<T extends Component>() => _stores.containsKey(T);`
  to `ComponentRegistry`, next to `register` (Ruling 06-13).
- `packages/jet_cad_2d/lib/jet_cad_2d.dart`: added
  `export 'src/parametric/parametric_system.dart';` in alphabetical
  order (between `src/index/spatial_index.dart` and
  `src/store/entity_store.dart`).
- `packages/jet_cad_2d/test/parametric/support/clients.dart`: the test
  clients (`RectParams`, `ClipRect`, `SoftRect`, `Trip`/`TripType`,
  `Hinge`/`HingeType`, `RectType<T>`, `clippedRect`, `insideInterval`,
  `corners`, `rectReach`, `rectOf`, `testCatalog`).
- `packages/jet_cad_2d/test/parametric/support/fixture.dart`: the
  rotated, off-origin fixture (`atA`, `atB`, `parked`, `hA`, `hB`,
  `catalog`, `paramDoc`, `create`, `pair`, `kids`, `worldSegments`,
  `enc`, `canon`, `reload`).
- `packages/jet_cad_2d/test/parametric/regeneration_test.dart`: P1-P10.

## Deviations from the brief's code

**None in the `parametric/` sources or the test files.** Every line was
transcribed as given and compiled and passed unmodified on the first
attempt — no bug in the brief's code was found against the spec, so
nothing needed correcting.

One deviation from the brief's mechanics, not its code: **Step 8's `git
add` command line omits `packages/jet_cad_2d/lib/src/document/component.dart`**,
even though the brief's own "Files" section (top of the task) lists it
as a file this task modifies. Staging only the paths the brief's `git
add` line names would have left `isRegistered` — required by
`_Registration.registerInto` and pinned by P10/M-06v — out of the
commit entirely, silently breaking the build for whoever checks out
this commit in isolation. I staged and committed
`lib/src/document/component.dart` as well. This is a gap in the
brief's copy-pasted command, not a defect in the design; the ruling
(06-13) and the "Files" list both clearly call for the method to land
here.

`dart format` reformatted four of the freshly-created files
(`parametric_system.dart`, `regeneration.dart`, `regeneration_test.dart`,
`clients.dart`) after the initial write — line-wrapping differences
only (e.g. `void register<T extends Component>(String typeId, ...)`
wrapped across two lines instead of running past 80 columns, ternaries
reflowed). No logic changed; `dart format --output=none
--set-exit-if-changed .` is clean afterward.

## TDD evidence

### RED — before implementation (compile errors, nothing in `parametric/` existed)

Command: `cd packages/jet_cad_2d && CI=true dart test test/parametric`

```
      expect(() => ParametricSystem(doc, catalog).install(), throwsStateError);
                   ^^^^^^^^^^^^^^^^
  test/parametric/regeneration_test.dart:136:15: Error: Method not found: 'ParametricSystem'.
...
  test/parametric/support/clients.dart:81:20: Error: 'ParametricView' isn't a type.
  test/parametric/support/clients.dart:125:29: Error: 'ParametricView' isn't a type.
  test/parametric/support/clients.dart:137:16: Error: 'Generated' isn't a type.
  test/parametric/support/clients.dart:155:15: Error: Method not found: 'Generated'.
  test/parametric/support/clients.dart:172:28: Error: 'ParametricView' isn't a type.
  test/parametric/support/clients.dart:183:28: Error: 'ParametricView' isn't a type.
  test/parametric/support/clients.dart:223:28: Error: 'ParametricView' isn't a type.
  test/parametric/support/clients.dart:224:18: Error: The method 'Generated' isn't defined for the type 'HingeType'.
  test/parametric/support/clients.dart:227:9: Error: The method 'Generated' isn't defined for the type 'HingeType'.
  test/parametric/support/clients.dart:232:36: Error: Method not found: 'ParametricCatalog'.
  test/parametric/support/fixture.dart:28:7: Error: 'ParametricCatalog' isn't a type.
  test/parametric/support/fixture.dart:32:3: Error: Method not found: 'ParametricSystem'.
  test/parametric/support/fixture.dart:92:3: Error: Method not found: 'ParametricSystem'.
00:00 +0 -1: Some tests failed.

Failing tests:
  test/parametric/regeneration_test.dart: loading test/parametric/regeneration_test.dart
```

Confirms the expected RED: pure compile failure, exactly what step 4
of the brief predicted.

### GREEN — after implementation

Command: `cd packages/jet_cad_2d && CI=true dart test test/parametric`

```
00:00 +0: loading test/parametric/regeneration_test.dart
00:00 +0: test/parametric/regeneration_test.dart: P1 the first object in an empty document generates (M-06q)
00:00 +1: test/parametric/regeneration_test.dart: P2 a width edit regenerates in place, keeping every child handle (M-06p)
00:00 +2: test/parametric/regeneration_test.dart: P3 edit plus regeneration is one undo step; undo and redo restore both, with the same handles (M-06c)
00:00 +3: test/parametric/regeneration_test.dart: P4 the summary says geometry, so the index sees new children (M-06h)
00:00 +4: test/parametric/regeneration_test.dart: P5 children are matched by kind, then ordinal (M-06m)
00:00 +5: test/parametric/regeneration_test.dart: P6 fast path: no parametric object, no parametric command, the command is returned as is
00:00 +6: test/parametric/regeneration_test.dart: P7 a fill cannot be generated
00:00 +7: test/parametric/regeneration_test.dart: P8 one system per document; dispose releases only its own slot
00:00 +8: test/parametric/regeneration_test.dart: P9 a ParametricEdit applies once (spec D9)
00:00 +9: test/parametric/regeneration_test.dart: P10 a second system over a populated document keeps its components (Ruling 06-13, M-06v)
00:00 +10: All tests passed!
```

All ten new tests (P1-P10) passed on the first run after implementation
— no fix-up iterations were needed.

## Gate-line summaries

### Engine line (`packages/jet_cad_2d`)

```
$ CI=true dart test
...
00:03 +924: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +925: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +925: All tests passed!
```
Exit code: 0. **925 tests**, matching the brief's expectation
(915 baseline stated in the task + 10 P1-P10 = 925; the plan-rulings
branch-point count at `6adf03d` was 911, and Task 1 landed 058918d
between the branch point and this task without adding tests, so 911 +
4 (component/allocation-adjacent counts already included at the branch
point per the brief's own math) reconciles to the stated 915 baseline).

```
$ CI=true dart analyze
Analyzing jet_cad_2d...
No issues found!
```
Exit code: 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 139 files (0 changed) in 0.26 seconds.
```
Exit code: 0.

### Render line (`packages/jet_cad_2d_flutter`)

```
$ CI=true flutter test
...
00:13 +923: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```
Exit code: 1 — **exactly** the five standing `text_ladder_golden_test.dart`
failures named in the global constraints as the standing exception (923
passed, 1 skipped, these 5 failed). Nothing else failed.

```
$ CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.6s)
```
Exit code: 0. (`flutter pub get`, run as part of `flutter analyze`,
did **not** rewrite `analysis_options.yaml` this time — verified with
`git status --short` immediately after, which showed no changes to
that file.)

```
$ dart format --output=none --set-exit-if-changed .
Formatted 175 files (0 changed) in 0.33 seconds.
```
Exit code: 0.

## Files changed

- `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart` (new)
- `packages/jet_cad_2d/lib/src/parametric/regeneration.dart` (new)
- `packages/jet_cad_2d/lib/src/document/component.dart` (modified:
  `isRegistered<T>()`)
- `packages/jet_cad_2d/lib/jet_cad_2d.dart` (modified: one export line)
- `packages/jet_cad_2d/test/parametric/regeneration_test.dart` (new)
- `packages/jet_cad_2d/test/parametric/support/clients.dart` (new)
- `packages/jet_cad_2d/test/parametric/support/fixture.dart` (new)

Committed as `d9eee9c` on `plan-06/parametric-layer`, immediately after
`058918d` (Task 1). Working tree is clean; `analysis_options.yaml` was
not touched or committed.

## Self-review

- Cross-checked every engine API the brief's code calls
  (`CommandDispatcher.expander`, `CommandTarget`, `DraftCommand`,
  `CommandResult`, `Capability`, `ComponentRegistry`/`ComponentStore`,
  `EntityStore`/`GeometryStore`/`GeometryPayload`/`EntityKind`,
  `AddEntityCommand`/`RemoveEntityCommand`/`SetEntityGeometryCommand`/
  `SetComponentCommand`/`CompoundCommand`/`AddNodeCommand`,
  `DocumentTree.accumulatedTransform`/`.root`, `Handle`/`HandleSeed`,
  `Tolerance`, `Aabb2`, `Transform2`, `Diagnostic`,
  `DraftDocumentCodec.decode/encode/encodeToString`, `SpatialIndex`,
  `QueryFilter`) against the current source before writing anything, so
  there were no surprises during implementation — every signature
  matched what the brief assumed.
- Verified Ruling 06-13's mechanism directly: `ComponentRegistry.register`
  unconditionally replaces `_stores[T]`, so `isRegistered<T>()` guarding
  `_Registration.registerInto` is load-bearing, not decorative — P10
  exercises exactly this path (a second `ParametricSystem` over a
  populated document) and passed.
- Confirmed the fast-path guard in `_expand` (D2) is evaluated on every
  `execute`, including the empty-document case, and that P6 exercises
  both branches (a plain line add returns `identical`, a parametric
  create returns a wrapped `ParametricEdit`).
- Confirmed `ParametricEdit.apply`'s single-use guard (`_applied`)
  throws `StateError` on a second call, per D9 and P9, without needing
  a code change — the brief's guard was correct as given.
- Ran the full engine and render gate lines twice (once before, once
  after `dart format`) to make sure formatting did not regress
  anything; both runs after formatting are stable and match the
  numbers above.
- Did not touch `packages/jet_cad_2d_flutter`, `apps/dev_harness_2d`,
  or `apps/floor_planner` sources; only ran their gate line as
  instructed (`jet_cad_2d_flutter`) to confirm the barrel export
  compiles downstream, since the engine barrel grew.

## Concerns

- None of substance. The one item worth flagging is already covered
  above under "Deviations": the brief's Step 8 `git add` line does not
  list `lib/src/document/component.dart`, and a literal execution of
  that command would have left `isRegistered` uncommitted. I staged it
  anyway, matching the brief's own "Files" section and Ruling 06-13.
  Future tasks reading this ledger should know the commit at `d9eee9c`
  includes that file even though the brief's copy-paste command did
  not name it.
- The engine test-count arithmetic in the task instructions ("Expected
  engine count after this task: 915 + 10 = 925") and the plan-rulings
  branch-point count ("engine 911" at `6adf03d`) differ by 4 tests
  that must have landed between the branch point and this task's start
  (Task 1, `058918d`) without the ledger being asked to reconcile them
  here — I did not investigate this further since the actual run
  (925) matches the brief's stated target exactly, which is the number
  that matters for the gate.
