# Task 3 report: SelectionKey, resolveHit, SelectionController

## Fix round 1

**Finding (Important, plan-mandated):** `toggle` fired a spurious
`notifyListeners()` when its input contained a duplicate key that
cancelled itself out — `toggle([k, k])` on an empty selection added `k`
then removed it, ending exactly where it started, but the loop's
`changed = true` was set unconditionally on entry, so it notified
anyway. This is the brief's own Step 3 snippet reproduced verbatim; per
the controller's ruling, the spec's "none when nothing changed" wins
over the plan snippet.

**What changed** — `packages/jet_cad_2d_flutter/lib/src/selection.dart`,
`toggle`: replaced the per-key `changed` flag with a net-change check —
snapshot `_keys` before the loop, run the toggle loop unchanged, then
notify only if the resulting set differs from the snapshot
(`setEquals`), the same pattern `replace` already uses:

```dart
void toggle(Iterable<SelectionKey> keys) {
  final before = Set<SelectionKey>.of(_keys);
  for (final k in keys) {
    if (!_keys.remove(k)) _keys.add(k);
  }
  if (!setEquals(before, _keys)) notifyListeners();
}
```

**Covering test** — added to
`packages/jet_cad_2d_flutter/test/selection_test.dart`, right after
`'toggle adds then removes'`:

`'toggle with a self-cancelling duplicate does not notify'` —
`toggle([k, k])` on an empty controller leaves it empty and notifies
zero times; a further `toggle([k, k, k])` selects `k` and notifies
exactly once.

**RED** (old `toggle` restored temporarily via
`git show HEAD:.../selection.dart`, new test added):

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_test.dart
...
00:00 +6: toggle with a self-cancelling duplicate does not notify
00:00 +6 -1: toggle with a self-cancelling duplicate does not notify [E]
  Expected: <0>
    Actual: <1>
  a duplicate that cancels itself out must not notify
  ...
00:00 +10 -1: Some tests failed.
Failing tests:
  .../test/selection_test.dart: toggle with a self-cancelling duplicate does not notify
```

**GREEN** (fix restored):

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_test.dart
00:00 +0: loading .../test/selection_test.dart
00:00 +0: two instances of one definition are two keys; two leaves of one instance are one
00:00 +1: a leaf owned by a nested group resolves to the outer group; a single-level group to itself
00:00 +2: a truncated hit is a miss
00:00 +3: an external remove prunes; an unrelated add does not
00:00 +4: replace with the same set does not notify
00:00 +5: toggle adds then removes
00:00 +6: toggle with a self-cancelling duplicate does not notify
00:00 +7: remove drops only what it names
00:00 +8: clear drops hover too
00:00 +9: DocumentLoaded clears everything
00:00 +10: equality is by chain and target, not identity
00:00 +11: All tests passed!
```

**Package gate line:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
...
00:11 +715 ~1 -5: Some tests failed.
Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```
709 passed, 1 skipped (pre-existing, unrelated), the same five
pre-existing golden-drift failures and nothing else.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.5s)
```
Exit code 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 125 files (0 changed) in 0.24 seconds.
```
Exit code 0. `git status --short` showed no `analysis_options.yaml`
diff throughout.

**Files changed in this round:**
- `packages/jet_cad_2d_flutter/lib/src/selection.dart` (modified —
  `toggle` only)
- `packages/jet_cad_2d_flutter/test/selection_test.dart` (modified —
  one new test added)

---

## What was implemented

- `packages/jet_cad_2d_flutter/lib/src/selection.dart`:
  - `SelectionKey` — immutable chain (defensive copy, `[0, chainLength)`
    only) + `target`, value equality (chain element-wise then target),
    `hashCode = Object.hash(Object.hashAll(chain), target)`.
  - `resolveHit(HitPath, DraftDocument)` — a miss or a truncated hit is
    `null`; a hit through an instance chain returns `chain[0]`; a
    root-level leaf returns itself; a leaf owned by a group walks
    `tree.ancestorsOf(owner)` via `topmostGroupOf` to find the outermost
    group before the root, falling back to the leaf itself on
    `NodeCycleError` or when no ancestor is a group.
  - `topmostGroupOf(document, owner, ancestors)` — top-level helper kept
    at the shape the brief specified, for Task 5 to reuse.
  - `SelectionController extends ChangeNotifier` — `replace`, `toggle`,
    `remove`, `clear`, hover, one notify per mutating call and none when
    nothing changed; subscribes to `document.changes` and prunes dead
    keys on `CommandApplied`/`CommandUndone`/`CommandRedone`, clears
    everything on `DocumentLoaded`/`DocumentPurged`; `debugOnChange` is
    the `@visibleForTesting` seam onto the private handler; `dispose`
    cancels the subscription.
- `packages/jet_cad_2d_flutter/test/support/selection_fixture.dart`:
  `addEntity` (copied from `pick_test.dart`), `addDefinition`,
  `addInstance`, `addGroup`, `kPlacement`, `cameraAt`, and
  `twoInstancesOfOneDefinition`.
- `packages/jet_cad_2d_flutter/test/selection_test.dart`: the seven
  scenarios from the brief (M-02c′, M-02p, truncated-hit-is-a-miss,
  M-02k and its sibling, M-02aa, toggle/remove/clear/DocumentLoaded, and
  the equality test), 10 `test()` blocks total (the toggle/remove/clear
  group is split into separate blocks per the brief's own list of
  titles).

## Departures from the brief

1. **Added `import 'dart:collection';`** to `selection.dart`. The
   brief's Step 3 snippet uses `UnmodifiableSetView(_keys)` in the
   `keys` getter but does not import `dart:collection`, and
   `flutter/foundation.dart` does not re-export it (it does provide
   `setEquals`, which is used as shown). Without this import the file
   fails to compile. Local, obvious fix — recorded here as instructed
   rather than treated as an ambiguity.
2. **`cameraAt`'s signature**: the brief names the fixture's parameters
   as `cameraAt(scale, translation)` without a type for `translation`.
   I typed it `Offset` (`dart:ui`), matching how translation is passed
   elsewhere in this package's camera code (`CameraController.panBy`
   takes an `Offset`). Not exercised by this task's tests — no later
   task depends on the exact type yet, per the brief — but flagged here
   in case Task 5+ expects a `Vector2` instead.
3. Did not add `selection.dart` to the `jet_cad_2d_flutter.dart` barrel
   export. The brief's Files section only lists `lib/src/selection.dart`
   as a create, and several other `lib/src/*.dart` files in this package
   are deliberately not re-exported from the barrel (e.g.
   `reference_walk.dart`'s sibling files under `gpu/`), with tests
   importing `package:jet_cad_2d_flutter/src/...` directly — which is
   exactly the pattern `selection_test.dart` follows. Left unexported so
   this task doesn't make a barrel-surface decision on Task 5's behalf.

## TDD evidence

**RED** — with `lib/src/selection.dart` moved aside:

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_test.dart
...
test/selection_test.dart:91:23: Error: Method not found: 'resolveHit'.
test/selection_test.dart:115:23: Error: Method not found: 'SelectionController'.
test/selection_test.dart:117:21: Error: Undefined name 'SelectionKey'.
... (SelectionKey/resolveHit/SelectionController undefined at every call site)
00:00 +0 -1: Some tests failed.
Failing tests:
  .../test/selection_test.dart: loading .../test/selection_test.dart
```

**GREEN** — `lib/src/selection.dart` restored:

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_test.dart
00:00 +0: loading .../test/selection_test.dart
00:00 +0: two instances of one definition are two keys; two leaves of one instance are one
00:00 +1: a leaf owned by a nested group resolves to the outer group; a single-level group to itself
00:00 +2: a truncated hit is a miss
00:00 +3: an external remove prunes; an unrelated add does not
00:00 +4: replace with the same set does not notify
00:00 +5: toggle adds then removes
00:00 +6: remove drops only what it names
00:00 +7: clear drops hover too
00:00 +8: DocumentLoaded clears everything
00:00 +9: equality is by chain and target, not identity
00:00 +10: All tests passed!
```

## Package gate line

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
...
00:10 +714 ~1 -5: Some tests failed.
Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```
709 passed, 1 skipped (pre-existing, unrelated), exactly the five named
pre-existing golden-drift failures — nothing else failed. Exit code 1
(from those five), consistent with the known baseline.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 2.3s)
```
Exit code 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 125 files (0 changed) in 0.25s
```
Exit code 0 (after formatting the two new source files in place with
`dart format lib/src/selection.dart test/selection_test.dart
test/support/selection_fixture.dart` — the initial `--set-exit-if-changed`
dry run correctly reported them as unformatted and exited 1, which is
why the format pass and re-check are both shown as separate steps in
this session).

`git status --short` before and after every gate-line run showed no
`analysis_options.yaml` diff in this package (`flutter pub get` ran
during the first `flutter test` invocation and did not rewrite it this
time).

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/selection.dart` (new)
- `packages/jet_cad_2d_flutter/test/selection_test.dart` (new)
- `packages/jet_cad_2d_flutter/test/support/selection_fixture.dart` (new)

## Self-review

- `SelectionKey.chain` is always a fresh `Uint32List` — the `chain:
  Uint32List, chainLength: int` constructor never retains the caller's
  buffer (`Uint32List.fromList(Uint32List.sublistView(...))`), which
  matters for a `HitPath`-backed chain that's about to be reset for the
  next pick.
- `_resolves` checks every handle in `k.chain` is still an `InstanceNode`
  before checking the target — a chain key nested inside an instance
  that got removed or retyped is pruned even if the target handle
  happens to still resolve to something.
- `replace`/`toggle`/`remove`/`clear`/`setHover` each notify at most
  once and only when the visible state actually changed, matching the
  non-negotiable in the task ("one notify per mutating call, none when
  nothing changed") — verified directly by the M-02aa test.
- Draw-order / allocation non-negotiables in the root CLAUDE.md don't
  apply here: this is application state on the render layer's
  interaction path, not the frame path, and the task brief does not ask
  for zero-allocation selection mutation (each of `replace`/`toggle` is
  user-gesture-rate, not per-frame).
- Confirmed by re-reading `tree.dart`'s `ancestorsOf` and
  `spatial_index.dart`'s `_instancePath`/`chain[...]` writes that
  `HitPath.chain` only ever carries *instance* nesting, never group
  nesting — which is why `resolveHit`'s two branches (chain vs.
  ancestor-walk) are both needed and don't overlap in practice; the
  M-02p test fixture (groups only, no instance) exercises the
  ancestor-walk branch exclusively, and M-02c′ (instances only)
  exercises the chain branch exclusively.

## Concerns

- None blocking. The two departures above (the `dart:collection` import
  and `cameraAt`'s `Offset` typing) are the only points where I made a
  call the brief didn't fully spell out; both are cheap to revisit if a
  later task's reviewer wants something different.
