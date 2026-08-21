# Task 8 report: `validate()` learns five fill codes

## What changed

- `packages/jet_cad_2d/lib/src/document/validate.dart`
  - Added two imports: `../store/entity_store.dart` (for `EntityKind` and
    `boundaryHandleOf`) and `commands.dart` (for `triangulationFor`).
  - Added five constants to `ValidationCodes`: `fillBoundaryMissing`,
    `fillBoundaryNotFillable`, `fillBoundaryNotClosed`,
    `fillBoundaryForeignOwner`, `fillDrawOrderInverted`.
  - Added a seventh numbered block to `validate()` (comment says "7." — the
    existing six were numbered 1-6, this is the next one) that walks every
    live entity, filters to `EntityKind.fill`, resolves the boundary via
    `boundaryHandleOf`, and reports (never mutates, never `continue`s past a
    resolvable boundary except when the boundary is entirely missing):
    - `fillBoundaryMissing` when the named boundary handle is not in the
      document (`entities.slotOf(boundary) == null`), then `continue`s —
      nothing else can be checked without a resolvable boundary.
    - `fillBoundaryNotFillable` when the boundary's kind is neither
      `polyline` nor `circle`.
    - `fillBoundaryNotClosed` only for a polyline boundary whose
      `triangulationFor(kind, payload)` is `null` (the null/empty
      distinction from Tasks 1-7: null = not fillable at all / open,
      empty = a fillable shape the clipper reduced to nothing — a circle is
      never routed through this branch since `triangulationFor` for a
      circle is handled by the `NotFillable` check's `kind` guard, i.e. a
      circle boundary skips this branch entirely because it already passed
      the `kind == EntityKind.circle` half of the fillable check).
    - `fillBoundaryForeignOwner` when the fill's owner differs from the
      boundary's owner (exact `==` on stored `Handle`, no tolerance — this
      is a stored-value comparison, not geometric).
    - `fillDrawOrderInverted` when `fill.value > boundary.value`.

    Exact diff:
    ```diff
    diff --git a/packages/jet_cad_2d/lib/src/document/validate.dart b/packages/jet_cad_2d/lib/src/document/validate.dart
    index 9ccfa8e..9982529 100644
    --- a/packages/jet_cad_2d/lib/src/document/validate.dart
    +++ b/packages/jet_cad_2d/lib/src/document/validate.dart
    @@ -1,5 +1,7 @@
     import '../core/diagnostic.dart';
     import '../core/handle.dart';
    +import '../store/entity_store.dart';
    +import 'commands.dart';
     import 'draft_document.dart';
     import 'node.dart';
     import 'tree.dart';
    @@ -16,6 +18,11 @@ abstract final class ValidationCodes {
       static const String cycle = 'tree.cycle';
       static const String definitionCycle = 'tree.definition_cycle';
       static const String ownerMissing = 'entity.owner_missing';
    +  static const String fillBoundaryMissing = 'fill.boundary_missing';
    +  static const String fillBoundaryNotFillable = 'fill.boundary_not_fillable';
    +  static const String fillBoundaryNotClosed = 'fill.boundary_not_closed';
    +  static const String fillBoundaryForeignOwner = 'fill.boundary_foreign_owner';
    +  static const String fillDrawOrderInverted = 'fill.draw_order_inverted';
     }

     extension DocumentValidation on DraftDocument {
    @@ -222,6 +229,53 @@ extension DocumentValidation on DraftDocument {
           }
         }

    +    // 7. Fills. Every check reports; none repairs.
    +    for (final slot in entities.liveSlots) {
    +      if (entities.kindAt(slot) != EntityKind.fill) continue;
    +      final fill = entities.handleAt(slot);
    +      final boundary =
    +          boundaryHandleOf(geometry.peek(entities.geomIndexAt(slot)));
    +      final boundarySlot = entities.slotOf(boundary);
    +      if (boundarySlot == null) {
    +        out.add(error(
    +            ValidationCodes.fillBoundaryMissing,
    +            'fill ${fill.toHex()} names ${boundary.toHex()}, which is not in '
    +            'this document',
    +            [fill, boundary]));
    +        continue;
    +      }
    +      final kind = entities.kindAt(boundarySlot);
    +      if (kind != EntityKind.polyline && kind != EntityKind.circle) {
    +        out.add(error(
    +            ValidationCodes.fillBoundaryNotFillable,
    +            'fill ${fill.toHex()} names a ${kind.name}, which has no interior',
    +            [fill, boundary]));
    +      } else if (kind == EntityKind.polyline &&
    +          triangulationFor(
    +                  kind, geometry.peek(entities.geomIndexAt(boundarySlot))) ==
    +              null) {
    +        out.add(error(
    +            ValidationCodes.fillBoundaryNotClosed,
    +            'fill ${fill.toHex()} names an open polyline; closedness is the '
    +            'stored first point repeated as the last, compared exactly',
    +            [fill, boundary]));
    +      }
    +      if (entities.ownerAt(slot) != entities.ownerAt(boundarySlot)) {
    +        out.add(error(
    +            ValidationCodes.fillBoundaryForeignOwner,
    +            'fill ${fill.toHex()} and its boundary are in different owners, so '
    +            'the reference cannot resolve under an instance',
    +            [fill, boundary]));
    +      }
    +      if (fill.value > boundary.value) {
    +        out.add(error(
    +            ValidationCodes.fillDrawOrderInverted,
    +            'fill ${fill.toHex()} has a higher handle than its boundary '
    +            '${boundary.toHex()}, so it draws over its own outline',
    +            [fill, boundary]));
    +      }
    +    }
    +
         return out;
       }
     }
    ```

- `packages/jet_cad_2d/test/document/validate_test.dart`
  - Appended (not created — the file already existed with 12 tests for
    Tasks 1-7's checks) two builder helpers (`rawFill`, `rawLeaf`) and five
    tests, one fixture per code, exactly as specified in the brief with two
    substitutions per the controller's rulings:
    - `GroupNode(handle: group, parent: doc.rootHandle)` →
      `GroupNode(handle: group, parent: doc.rootHandle, transform: Transform2.identity(), children: const [])`.
    - `jsonEncode(JsonCodec.save(doc))` → `DraftDocumentCodec.encodeToString(doc)`
      (which already returns a JSON string, so `dart:convert`'s `jsonEncode`
      wrapper became unnecessary and was not imported).
  - Total test count in the file: 12 (pre-existing) + 5 (new) = 17.

## Suite output — `packages/jet_cad_2d`

`CI=true dart test test/document/validate_test.dart -r expanded` (all 17,
including the 5 new ones):

```
00:00 +0: loading test/document/validate_test.dart
00:00 +0: a document built by commands validates clean
00:00 +1: reports a root that names no node
00:00 +2: reports an entity whose owner names no container
00:00 +3: reports a children entry that resolves to nothing
00:00 +4: reports parent and children disagreeing
00:00 +5: a parent/children mismatch names the actual lister, not just the claimed parent
00:00 +6: reports a group cycle rather than hanging
00:00 +7: reports a definition that reaches itself
00:00 +8: does not throw when a group cycle sits inside a definition reachable from another definition
00:00 +9: reports a definition cycle through every shared edge, not just one
00:00 +10: reports a leaf handle sitting in a children list
00:00 +11: diagnostics come back in ascending-handle order, not insertion order
00:00 +12: a fill naming nothing is reported
00:00 +13: a fill on a text entity is reported as not fillable
00:00 +14: a fill on an open polyline is reported as not closed
00:00 +15: a fill in a different owner than its boundary is reported
00:00 +16: an inverted pair is reported and nothing is changed
00:00 +17: All tests passed!
```

Full package suite, `CI=true dart test` (tail):

```
00:01 +752: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:01 +753: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:01 +754: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:01 +755: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:01 +756: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +757: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +758: test/invariants/query_allocation_test.dart: (tearDownAll)
00:02 +758: All tests passed!
```

758 tests total, all pass (was 741 before this task's 17-test file grew by 5;
the delta from STATUS.md's last-recorded 720 reflects Tasks 1-7's own test
additions, not anything from this task beyond the 5 new ones).

`dart analyze`:
```
Analyzing jet_cad_2d...
No issues found!
```

`dart format --output=none --set-exit-if-changed .`:
```
Formatted 110 files (0 changed) in 0.14 seconds.
```
(One earlier run of `dart format --set-exit-if-changed` on the freshly
hand-edited file did flag it — the multi-line `out.add(error(...))` calls I
typed did not match `dart format`'s own wrapping. I ran plain `dart format`
on the file, which reformatted the same logic onto different line breaks,
then reran the check clean. No behavior changed, confirmed by rerunning the
full test suite after reformatting.)

## Suite output — `packages/jet_cad_2d_flutter`

`CI=true flutter test` (tail):

```
00:02 +235 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: a bypassed leaf lands exactly where the residual path would put it
00:02 +236 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: a bypassed leaf hands the sink small numbers
00:02 +237 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: a bypassed leaf gets the exact paper width
00:02 +238 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: curves cannot be bypassed an anisotropic circle stays on the residual path and is counted
00:02 +239 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: curves cannot be bypassed an anisotropic arc is counted too
00:02 +240 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: curves cannot be bypassed a conformal circle is not counted
00:02 +241 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: curves cannot be bypassed the threshold is exclusive, so a circle exactly at 2.0 is not counted
00:02 +242 ~1: All tests passed!
```

242 pass, 1 skipped (the pre-existing `rig`-tagged benchmark skip, untouched
by this task) — this package is unaffected by the Task 8 change; run to
satisfy "ends green on both packages."

`flutter analyze`:
```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)
```

`dart format --output=none --set-exit-if-changed .` (jet_cad_2d_flutter):
```
Formatted 45 files (0 changed) in 0.06 seconds.
```

`git status --porcelain` after `flutter analyze` (which ran an implicit `pub
get`): only the two files listed under "What changed" above — no
`analysis_options.yaml` was modified or staged.

## Named-mutation transcript

For each of the five `out.add(...)` blocks, in the numbered order they
appear in the file: copied the pre-mutation file aside with `cp` (not `git
checkout`, per the rule against using it to revert a mutation), deleted the
block with `sed`, ran `CI=true dart test test/document/validate_test.dart -r
expanded`, then restored with `cp` from the copy and confirmed with `diff`
that the restored file was byte-identical to the original — all inside one
shell call per mutation.

### Mutation 1: delete the `fillBoundaryMissing` block (kept the `continue`)

```
00:00 +12: a fill naming nothing is reported
00:00 +12 -1: a fill naming nothing is reported [E]
  Expected: contains 'fill.boundary_missing'
    Actual: MappedListIterable<Diagnostic, String>:[]
     Which: does not contain 'fill.boundary_missing'

  package:matcher                         expect
  test/document/validate_test.dart 502:5  main.<fn>

00:00 +12 -1: a fill on a text entity is reported as not fillable
00:00 +13 -1: a fill on an open polyline is reported as not closed
00:00 +14 -1: a fill in a different owner than its boundary is reported
00:00 +15 -1: an inverted pair is reported and nothing is changed
00:00 +16 -1: Some tests failed.

Failing tests:
  test/document/validate_test.dart: a fill naming nothing is reported
```

**Verdict: kill.** Failed only `a fill naming nothing is reported`.
File restored; `diff` against the pre-mutation copy was empty.

### Mutation 2: delete the `fillBoundaryNotFillable` block

```
00:00 +13: a fill on a text entity is reported as not fillable
00:00 +13 -1: a fill on a text entity is reported as not fillable [E]
  Expected: contains 'fill.boundary_not_fillable'
    Actual: MappedListIterable<Diagnostic, String>:['fill.draw_order_inverted']
     Which: does not contain 'fill.boundary_not_fillable'

  package:matcher                         expect
  test/document/validate_test.dart 511:5  main.<fn>

00:00 +13 -1: a fill on an open polyline is reported as not closed
00:00 +14 -1: a fill in a different owner than its boundary is reported
00:00 +15 -1: an inverted pair is reported and nothing is changed
00:00 +16 -1: Some tests failed.

Failing tests:
  test/document/validate_test.dart: a fill on a text entity is reported as not fillable
```

**Verdict: kill.** Failed only `a fill on a text entity is reported as not
fillable`. File restored; `diff` was empty.

### Mutation 3: delete the `fillBoundaryNotClosed` block

```
00:00 +14: a fill on an open polyline is reported as not closed
00:00 +14 -1: a fill on an open polyline is reported as not closed [E]
  Expected: contains 'fill.boundary_not_closed'
    Actual: MappedListIterable<Diagnostic, String>:['fill.draw_order_inverted']
     Which: does not contain 'fill.boundary_not_closed'

  package:matcher                         expect
  test/document/validate_test.dart 519:5  main.<fn>

00:00 +14 -1: a fill in a different owner than its boundary is reported
00:00 +15 -1: an inverted pair is reported and nothing is changed
00:00 +16 -1: Some tests failed.

Failing tests:
  test/document/validate_test.dart: a fill on an open polyline is reported as not closed
```

**Verdict: kill.** Failed only `a fill on an open polyline is reported as
not closed`. File restored; `diff` was empty.

### Mutation 4: delete the `fillBoundaryForeignOwner` block

```
00:00 +15: a fill in a different owner than its boundary is reported
00:00 +15 -1: a fill in a different owner than its boundary is reported [E]
  Expected: contains 'fill.boundary_foreign_owner'
    Actual: MappedListIterable<Diagnostic, String>:['fill.draw_order_inverted']
     Which: does not contain 'fill.boundary_foreign_owner'

  package:matcher                         expect
  test/document/validate_test.dart 536:5  main.<fn>

00:00 +15 -1: an inverted pair is reported and nothing is changed
00:00 +16 -1: Some tests failed.

Failing tests:
  test/document/validate_test.dart: a fill in a different owner than its boundary is reported
```

**Verdict: kill.** Failed only `a fill in a different owner than its
boundary is reported`. File restored; `diff` was empty.

### Mutation 5: delete the `fillDrawOrderInverted` block

```
00:00 +16: an inverted pair is reported and nothing is changed
00:00 +16 -1: an inverted pair is reported and nothing is changed [E]
  Expected: contains 'fill.draw_order_inverted'
    Actual: MappedListIterable<Diagnostic, String>:[]
     Which: does not contain 'fill.draw_order_inverted'

  package:matcher                         expect
  test/document/validate_test.dart 564:5  main.<fn>

00:00 +16 -1: Some tests failed.

Failing tests:
  test/document/validate_test.dart: an inverted pair is reported and nothing is changed
```

**Verdict: kill.** Failed only `an inverted pair is reported and nothing is
changed`. File restored; `diff` was empty.

### Summary

All five deletions failed exactly their own fixture's test and no other —
the one-fixture-per-code discipline the brief called for is borne out: no
deletion turned two tests red, so none of the five fixtures overlap in what
they exercise. After the fifth restore, `diff` of the live file against the
pre-mutation copy was empty, and the full suite (`CI=true dart test`) was
rerun once more end-to-end (758 pass) as a final confirmation that nothing
was left mutated.

## What I was unsure about

- The brief's Step 3 snippet numbers its own new block "6." in a comment,
  but the six existing blocks in the pre-Task-8 file are already numbered
  1 through 6 (root, owners, children-resolve, parent-agrees, group-cycles,
  definition-cycles). I used "7." for the new block instead of reusing "6."
  to avoid a duplicate number, since duplicating an existing block's number
  seemed more likely to be a brief typo than an instruction to renumber
  anything. This is purely a comment-text choice with no behavioral
  effect; flagging it in case the reviewer wants "6." to match the brief
  literally.
- The "not closed" check only fires for a polyline boundary
  (`kind == EntityKind.polyline`); a circle boundary's `triangulationFor`
  can also return `null` in principle per the Tasks 1-7 contract description
  ("null = not fillable at all", vs. "empty = a circle, or a fillable shape
  the clipper could not reduce"), but the brief's own Step 3 snippet gates
  the `NotClosed` check on `kind == EntityKind.polyline` explicitly, and a
  circle can't be "not closed" in the stored-value sense the code documents
  (closedness is defined as "first point repeated as last," which has no
  meaning for a circle's scalar-radius representation) — so a circle never
  reaches this branch, matching the brief. I did not find a circle-with-null-
  triangulation fixture in the five and did not add one since the brief's
  five codes and five fixtures already have a 1:1 map without it.

---

# Fix round 1 — single-fault fixtures

**Provenance.** The fix agent applied the fixture change and then stalled on the
600-second stream watchdog, before running the deletion matrix. Its work was
intact and uncommitted on disk. The **controller** ran the matrix and committed.
Transcripts are in `task-8-fix-matrix.md`, all from real runs.

## The finding

`rawFill` allocated the fill's handle *after* the boundary's, so
`fill.value > boundary.value` in the not-fillable, not-closed and foreign-owner
fixtures, and `fillDrawOrderInverted` fired alongside each fixture's own code.
Every assertion used `contains(...)`, so the extra code went unseen. The kill
matrix looked clean, but the isolation was incidental rather than real: a sixth
check added to this block could have reported a kill it had not earned.

## The fix

Two changes, both in `test/document/validate_test.dart`; `validate.dart` is
untouched.

1. The three affected fixtures allocate the **fill's handle before the
   boundary's** — the order `AddRegionCommand.allocate` uses in production — so
   `fillDrawOrderInverted` no longer fires and each fixture is malformed in
   exactly one way. The foreign-owner fixture keeps a real foreign owner: the
   boundary still lives under `group` while the fill defaults to the root. Only
   the handle order changed.
2. All five assertions moved from `contains(...)` to **exact list equality**, so
   an extra code now fails the test rather than passing unnoticed.

## The matrix, re-run with the property the finding was about

Each deletion in one shell invocation — delete, test, restore. For each, both the
failing test **and** the count of fill tests failing, which must be exactly 1.

| deleted check | failing test | fill tests failing |
|---|---|---|
| `fillBoundaryMissing` | a fill naming nothing is reported | **1** |
| `fillBoundaryNotFillable` | a fill on a text entity is reported as not fillable | **1** |
| `fillBoundaryNotClosed` | a fill on an open polyline is reported as not closed | **1** |
| `fillBoundaryForeignOwner` | a fill in a different owner than its boundary is reported | **1** |
| `fillDrawOrderInverted` | an inverted pair is reported and nothing is changed | **1** |

`validate.dart` byte-identical after every restore, confirmed by
`git diff --stat`.

**A first controller attempt at this matrix was discarded and is recorded in the
transcript file.** It used a shell array indexed from 0, and this shell is zsh,
where arrays are 1-based: the first iteration deleted a block chosen by an empty
name and every later verdict was shifted by one. It read as five plausible
results. That is the third time on this plan that a measurement harness — not the
code under test — produced a confident wrong answer.

## Gate

```
CI=true dart test                                  -> 758 tests, All tests passed!
dart analyze                                       -> No issues found!
dart format --output=none --set-exit-if-changed .  -> clean
git status --porcelain                             -> only validate_test.dart
```
