# Task 1 report — `EntityKind.fill` and the exhaustive switches

## Starting state

The working tree already carried an uncommitted diff matching this task's
shape when I started (all seven files listed in the brief were `M`odified,
nothing committed, `main` at `3201cc5`). I read every hunk against the brief
and the controller's decisions rather than trusting it blind, then verified
independently: ran `dart analyze` / `flutter analyze` fresh, ran both full
suites, and ran the named mutation myself with the required `cp`/`trap`
harness. Everything below is from those independent runs, not from re-reading
the diff.

## What changed and why

**`packages/jet_cad_2d/lib/src/store/entity_store.dart`**
- `enum EntityKind` gains `fill`, appended last (index 7), with a doc comment
  explaining why append-only matters: `EntityStore` stores `kind.index` in a
  `Uint8List` column, so an insertion would silently renumber every stored
  document's kinds in memory (JSON is safe either way — it keys on
  `kind.name`).
- `Handle boundaryHandleOf(GeometryPayload payload)` added below
  `EntityRecord`: reads `payload.scalars[0]` as a boundary handle, or
  `Handle.none` when `scalars` is empty. Doc comment notes the `double` round
  trip is exact because a handle is at most `kMaxHandle` (0xFFFFFFFF), well
  under 2^53.
- Added `import 'geometry_store.dart';` for `GeometryPayload`.

**Barrel reachability (decision 3):** `packages/jet_cad_2d/lib/jet_cad_2d.dart`
exports the whole file via `export 'src/store/entity_store.dart';` (line 50),
not a `show` list, so `boundaryHandleOf` is reachable from the barrel
automatically, same as `EntityRecord`. No barrel edit was needed.

**The exhaustive switches — found by compiling, per decision 2.** I searched
the whole repo (`lib/`, `test/`, `apps/dev_harness_2d`) for every
`switch (kind)` / `switch (record.kind)` and cross-checked against a clean
`dart analyze` / `flutter analyze` run on the current diff. Sites found:

| File | Switch (enclosing method) | Line of `switch` | Answer given |
|---|---|---|---|
| `packages/jet_cad_2d/lib/src/document/extents.dart` | `entityBounds` | 29 | `case EntityKind.fill: return Aabb2.empty();` |
| `packages/jet_cad_2d/lib/src/index/spatial_index.dart` | `_considerLeaf` | 776 | `case EntityKind.fill: break;` (unreachable, see below) |
| `packages/jet_cad_2d/lib/src/index/spatial_index.dart` | `_considerSnapLeaf` | 1367 | `case EntityKind.fill: break;` (unreachable, see below) |
| `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart` | switch at 424 | 424 | `case EntityKind.fill: break; // Task 13 draws it.` |
| `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart` | switch at 571 | 571 | `case EntityKind.fill: break; // Task 13 draws it.` |
| `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart` | switch at 163 | 163 | `case EntityKind.fill: break; // Task 13 draws it.` |
| `packages/jet_cad_2d/test/invariants/reference_query.dart` | `referenceInstancesInRect` | 395 | `case EntityKind.fill: return null; // A fill produces no hit and no snap candidate.` |
| `packages/jet_cad_2d/test/invariants/reference_query.dart` | `_snapCandidates` | 663 | `case EntityKind.fill: break; // A fill produces no hit and no snap candidate.` |

**This is 6 sites in `lib/` and 2 in the oracle (`reference_query.dart`), not
the brief's "four in `lib/` plus one in the oracle."** The brief undercounted
both `spatial_index.dart` (two switches, `_considerLeaf` and
`_considerSnapLeaf`, not one) and `reference_query.dart` (two switches, not
one); `draft_painter.dart` does have two as the brief's file list implies.
I trust the compiler's enumeration over the brief's count, per decision 2 —
`dart analyze` and `flutter analyze` both report **no issues** with exactly
these 8 cases added and no `default:` anywhere, and no other file in the repo
contains a `switch` on `EntityKind`.

**`spatial_index.dart`'s two cases are unreachable by design, per decision
1.** Both `_considerLeaf` and `_considerSnapLeaf` return before the switch
when `payload.pointCount == 0`, and a fill payload carries no coordinates
(its geometry is one scalar, the boundary handle), so the `fill` case can
never execute. I did not simplify it away and did not add a `default:`. The
comment on both reads:

```dart
      case EntityKind.fill:
        // Unreachable: this method returns above when `count == 0`, and a
        // fill's payload carries no coordinates. This case exists only so the
        // switch stays exhaustive, so a future EntityKind still fails to
        // compile here instead of falling through silently.
        break;
```

**`extents.dart`** — a fill's own payload has no points; Task 9 will give it
the boundary's box:

```dart
    case EntityKind.fill:
      // Task 9 gives this case the boundary's box. Until then a fill bounds
      // to nothing, which is what its own payload says.
      return Aabb2.empty();
```

**`draft_painter.dart` / `reference_walk.dart`** — inert, `Task 13 draws it.`

**`reference_query.dart`** — both switches get `a fill produces no hit and no
snap candidate`, matching the brief's exact wording.

## Test output — `packages/jet_cad_2d`

### `dart test` (full suite)

```
$ cd packages/jet_cad_2d && dart test
...
00:01 +706: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +707: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +708: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
...
00:02 +721: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +722: test/invariants/query_allocation_test.dart: (tearDownAll)
00:02 +722: All tests passed!
```

722 tests, all pass (STATUS.md records 720 before this task; the two new
tests from Step 1 bring it to 722).

### `dart analyze`

```
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
```

### `dart format --output=none --set-exit-if-changed .`

```
Formatted 105 files (0 changed) in 0.12 seconds.
```

## Test output — `packages/jet_cad_2d_flutter`

### `flutter test` (full suite)

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:02 +237 ~1: .../test/lineweight_test.dart: curves cannot be bypassed an anisotropic circle stays on the residual path and is counted
00:02 +238 ~1: .../test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
...
00:02 +241 ~1: .../test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:02 +242 ~1: All tests passed!
```

242 tests pass, 1 skipped (`~1`) — matches STATUS.md's standing description
of the widget suite's one by-design skip (`paint_microbench_test.dart`, tag
`rig`).

### `flutter analyze`

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)
```

### `dart format --output=none --set-exit-if-changed .`

```
Formatted 45 files (0 changed) in 0.05 seconds.
```

`flutter pub get` (triggered by `flutter analyze`/`flutter test`) did not
rewrite any `analysis_options.yaml`: `git status --porcelain` before and
after every run in this task shows the same 7 modified files, never any
`analysis_options.yaml`.

## Mutation transcript — MUTANT T1a (insert rather than append)

Run with the required `cp`/`trap` harness (never `git checkout`):

```
$ cd packages/jet_cad_2d
$ cp lib/src/store/entity_store.dart /private/tmp/.../scratchpad/t1_entity_store_backup.dart
$ trap 'cp /private/tmp/.../scratchpad/t1_entity_store_backup.dart lib/src/store/entity_store.dart' EXIT
$ perl -0pi -e 's/enum EntityKind \{ point, line, polyline, circle, arc, text, attrib, fill \}/enum EntityKind { fill, point, line, polyline, circle, arc, text, attrib }/' lib/src/store/entity_store.dart
$ grep -n "enum EntityKind" lib/src/store/entity_store.dart
13:enum EntityKind { fill, point, line, polyline, circle, arc, text, attrib }
$ dart test test/store/entity_store_test.dart
...
00:00 +15: fill is the last EntityKind, and its ordinal is stable
00:00 +15 -1: fill is the last EntityKind, and its ordinal is stable [E]
  Expected: EntityKind:<EntityKind.fill>
    Actual: EntityKind:<EntityKind.attrib>

  package:matcher                          expect
  test/store/entity_store_test.dart 226:5  main.<fn>

00:00 +15 -1: boundaryHandleOf reads the boundary from scalars, and none when absent
00:00 +16 -1: Some tests failed.

Failing tests:
  test/store/entity_store_test.dart: fill is the last EntityKind, and its ordinal is stable

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
=== exit code: 1 ===
```

The mutant is killed: `EntityKind.values.last` becomes `EntityKind.attrib`
under the insertion, failing the `expect(EntityKind.values.last,
EntityKind.fill)` assertion. (`fill.index` under the mutant is `0`, which
would also fail the second `expect`, but the test runner reports the first
failing `expect` in the block and stops there — that is sufficient to call
the mutant dead.)

Restore verified after the `trap` fired on shell exit:

```
$ grep -n "enum EntityKind" lib/src/store/entity_store.dart
13:enum EntityKind { point, line, polyline, circle, arc, text, attrib, fill }
$ git diff --stat lib/src/store/entity_store.dart
 packages/jet_cad_2d/lib/src/store/entity_store.dart | 16 +++++++++++++++-
 1 file changed, 15 insertions(+), 1 deletion(-)
$ dart test test/store/entity_store_test.dart
...
00:00 +15: fill is the last EntityKind, and its ordinal is stable
00:00 +16: boundaryHandleOf reads the boundary from scalars, and none when absent
00:00 +17: All tests passed!
```

## Commit

```
git add -A packages/jet_cad_2d packages/jet_cad_2d_flutter
git commit -m "feat: EntityKind.fill, stored and inert"
```

`git status --porcelain` was empty of any `analysis_options.yaml` before
staging, so nothing was excluded.

## Uncertainties / things worth the controller's attention

1. **The brief's site count was wrong, corrected per decision 2.** It says
   "four `switch` sites in `lib/` plus one in the oracle." The true count is
   six in `lib/` (`extents.dart` ×1, `spatial_index.dart` ×2,
   `draft_painter.dart` ×2, `reference_walk.dart` ×1) and two in the oracle
   (`reference_query.dart` ×2). I trusted the compiler: both `dart analyze`
   and `flutter analyze` are clean with exactly these 8 cases added, no
   `default:` anywhere, and a repo-wide grep for `switch (kind)` /
   `switch (record.kind)` found no ninth site.
2. **The working tree already held this exact diff when I started this
   session.** I did not assume it was correct — I re-derived and re-verified
   every claim (fresh analyze, fresh full suites, fresh mutation run with a
   fresh `cp`/`trap`) rather than taking the pre-existing diff on faith. I
   flag this only so the reviewer knows the diff's origin is not this
   session's typing, in case that matters to provenance.
3. Step 1's brief test block asserts two things in one `expect` pair per
   test; under MUTANT T1a only the first assertion in the ordinal test is
   reached before the runner reports failure and moves on, so the transcript
   shows one `[E]` rather than two. I judged this sufficient to call the
   mutant killed (the brief's own Step 6 only requires the test to `FAIL`,
   which it does) but note it in case the controller wants a stricter read.
