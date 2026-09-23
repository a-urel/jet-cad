# Task 1 report — `drafting.dart` — records, commands, payloads, text height

## What was implemented

Created `packages/jet_cad_2d/lib/src/document/drafting.dart` with the exact
public surface the brief specifies:

- `kDraftFillColor`, `kDraftTextPaperMm` — spec 05 D13 / D9 constants.
- `draftRecord(handle, owner, kind, {text})` — builds an `EntityRecord` with
  the D2 defaults: layer 0, ByLayer everything, Standard text style, no
  text-attribute override bits.
- `addDrafted(doc, kind, payload, {text})` — allocates the handle from
  `doc.handleSeed` at build time and returns an unexecuted `AddEntityCommand`.
- `addDraftedRegion(doc, boundaryKind, boundaryPayload, {fillColor,
  boundaryColor, boundaryLineweight})` — wraps `AddRegionCommand.allocate`,
  refusing (returning `null`, allocating nothing) when
  `triangulationFor` returns `null` (not fillable) or an empty list for a
  polyline boundary (self-intersecting/degenerate closed loop). A circle's
  empty triangulation is its normal case and is accepted.
- `linePayload`, `polylinePayload` (with `closed`), `rectanglePayload`,
  `circlePayload`, `arcPayload`, `textPayload` — all copy their inputs into
  fresh `Float64List`s.
- `textHeightMm(page)` — 2.5 paper mm at the page's scale denominator, or 2.5
  with no page.
- `isDegenerateSegment`, `isDegenerateRectangle`, `isDegenerateRadius` — use
  `Tolerance.standard.linear` for the geometric decision.

Added the export `export 'src/document/drafting.dart';` to
`packages/jet_cad_2d/lib/jet_cad_2d.dart`, alphabetically between
`draft_document.dart` and `extents.dart` (matches both the brief's placement
instruction and the file's existing alphabetical export order).

Created `packages/jet_cad_2d/test/document/drafting_test.dart` with the 10
tests E1–E10 from the brief, verbatim.

## Deviations from the brief's code

None. Every interface the brief said to consume
(`AddEntityCommand`, `AddRegionCommand.allocate`, `triangulationFor`,
`EntityRecord`, `GeometryPayload`, `ReservedHandles`, `ByLayerColor`,
`TrueColor`, `kByLayer`, `kLineweightDefault`, `Tolerance.standard`,
`PageComponent`, `DraftDocument.handleSeed`/`rootHandle`) was verified present
with the expected shape before writing the implementation, and the brief's
`drafting.dart` and test file compiled and passed without any changes.

## TDD evidence

**RED** — `cd packages/jet_cad_2d && CI=true dart test test/document/drafting_test.dart`,
run before `drafting.dart` existed:

```
  test/document/drafting_test.dart:176:20: Error: Method not found: 'polylinePayload'.
      final bowTie = polylinePayload([
                     ^^^^^^^^^^^^^^^
  test/document/drafting_test.dart:184:12: Error: Method not found: 'addDraftedRegion'.
      expect(addDraftedRegion(doc, EntityKind.polyline, bowTie), isNull);
             ^^^^^^^^^^^^^^^^
  test/document/drafting_test.dart:188:39: Error: Method not found: 'polylinePayload'.
              doc, EntityKind.polyline, polylinePayload([c1, c2, c1 + c2])),
                                        ^^^^^^^^^^^^^^^
  test/document/drafting_test.dart:187:9: Error: Method not found: 'addDraftedRegion'.
          addDraftedRegion(
          ^^^^^^^^^^^^^^^^
  test/document/drafting_test.dart:196:12: Error: Method not found: 'isDegenerateSegment'.
      expect(isDegenerateSegment(c1, tiny), isTrue);
             ^^^^^^^^^^^^^^^^^^^
  test/document/drafting_test.dart:197:12: Error: Method not found: 'isDegenerateSegment'.
      expect(isDegenerateSegment(c1, c2), isFalse);
             ^^^^^^^^^^^^^^^^^^^
  test/document/drafting_test.dart:198:12: Error: Method not found: 'isDegenerateRectangle'.
      expect(isDegenerateRectangle(c1, Vector2(c2.x, c1.y)), isTrue);
             ^^^^^^^^^^^^^^^^^^^^^
  test/document/drafting_test.dart:199:12: Error: Method not found: 'isDegenerateRectangle'.
      expect(isDegenerateRectangle(c1, Vector2(c1.x, c2.y)), isTrue);
             ^^^^^^^^^^^^^^^^^^^^^
  test/document/drafting_test.dart:200:12: Error: Method not found: 'isDegenerateRectangle'.
      expect(isDegenerateRectangle(c1, c2), isFalse);
             ^^^^^^^^^^^^^^^^^^^^^
  test/document/drafting_test.dart:201:12: Error: Method not found: 'isDegenerateRadius'.
      expect(isDegenerateRadius(0), isTrue);
             ^^^^^^^^^^^^^^^^^^
  test/document/drafting_test.dart:202:12: Error: Method not found: 'isDegenerateRadius'.
      expect(isDegenerateRadius(1e-10), isTrue);
             ^^^^^^^^^^^^^^^^^^
  test/document/drafting_test.dart:203:12: Error: Method not found: 'isDegenerateRadius'.
      expect(isDegenerateRadius(0.001), isFalse);
             ^^^^^^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.

Failing tests:
  test/document/drafting_test.dart: loading test/document/drafting_test.dart
```

(Output truncated to the tail; the full output listed a compile error for
every one of the brief's new names — `draftRecord`, `addDrafted`,
`addDraftedRegion`, the payload builders, `textHeightMm`, and the three
degeneracy predicates — exactly as expected, since none of them existed
yet.)

**GREEN** — after writing `drafting.dart` and the barrel export, same
command:

```
00:00 +0: loading test/document/drafting_test.dart
00:00 +0: E1 draftRecord carries the D2 defaults, owned by the given owner
00:00 +1: E2 addDrafted allocates from the seed when built, and does not run
00:00 +2: E3 draw, undo, draw again: the second handle is never the first (M-05d)
00:00 +3: E4 undo removes a drafted entity and redo restores the same handle
00:00 +4: E5 a rectangle is five exact corners and round-trips closed (M-05b)
00:00 +5: E6 polylinePayload copies points, and closed repeats the first
00:00 +6: E7 text: height is cap height, and width and oblique inherit the style (M-05c, M-05t)
00:00 +7: E8 textHeightMm is 2.5 paper mm at the page scale (M-05j)
00:00 +8: E9 addDraftedRegion: a rectangle and a circle fill; a bow tie does not (M-05q)
00:00 +9: E10 the degeneracy predicates decide under Tolerance
00:00 +10: All tests passed!
```

Re-ran again after `dart format` rewrote both new files (line-wrap only, no
semantic change) — still `+10: All tests passed!`.

## Gate line output

### `packages/jet_cad_2d`

```
$ CI=true dart test
...
00:03 +903: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +904: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +904: All tests passed!
```
Exit code: 0. Count matches the expected 894 + 10 = 904.

```
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
```
Exit code: 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 132 files (0 changed) in 0.25 seconds.
```
Exit code: 0.

### `packages/jet_cad_2d_flutter`

```
$ CI=true flutter test
...
00:12 +854 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```
Exit code: 1 — exactly the five standing `text_ladder_golden_test.dart`
failures named in the standing instructions, 854 pass + 1 skip, matching the
expected count for a grown barrel. No other failures.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 2.0s)
```
Exit code: 0. (This run triggered a `pub get`, which the house rules warn can
rewrite `analysis_options.yaml`; `git status --short` afterward showed no
such file touched, so nothing needed to be checked out.)

```
$ dart format --output=none --set-exit-if-changed .
Formatted 159 files (0 changed) in 0.35 seconds.
```
Exit code: 0.

## Files changed

- `packages/jet_cad_2d/lib/src/document/drafting.dart` (new)
- `packages/jet_cad_2d/lib/jet_cad_2d.dart` (one export line added)
- `packages/jet_cad_2d/test/document/drafting_test.dart` (new)

Commit: `607bb82 feat(engine): drafting builders for the drawing tools`,
trailer verified with `git log -1 --format=%B | grep -c "Claude Sonnet 5"` →
`1`. Working tree clean after commit (`git status --short` empty).

## Self-review

- Checked every consumed interface (`AddEntityCommand`, `AddRegionCommand`,
  `AddRegionCommand.allocate`'s parameter list, `triangulationFor`,
  `EntityRecord`'s constructor, `GeometryPayload`, `ReservedHandles`,
  `ByLayerColor`/`TrueColor`, `kByLayer`/`kLineweightDefault`,
  `Tolerance.standard.linear`, `PageComponent`, `DraftDocument`) against the
  actual source before writing the implementation — all matched the brief's
  assumptions exactly, so no signature drift to reconcile.
- Traced each named mutant against its covering test:
  - M-05d (handle reuse after undo) → E3 asserts `b.record.handle` both
    `isNot` and strictly greater than `a.record.handle`; reissuing the
    first handle would fail both.
  - M-05b (rectangle corners/closing pair) → E5 checks all five coordinate
    pairs exactly and round-trips through the codec.
  - M-05c (cap height vs em height) → E7 computes the transform from
    `resolveTextAttributes`/`textLocalTransform` and checks the capital's
    rendered height equals `heightMm`; using em height would fail the
    `closeTo` check.
  - M-05t (width/oblique override bits) → E7's second half swaps the style's
    `widthFactor` to 0.8 and checks the resolved value follows the style,
    which only holds if `textAttrs` carries no override bits and the
    payload's `1`/`0` are inert padding.
  - M-05j (paper-mm/page-scale arithmetic) → E8 checks `textHeightMm` at
    `page == null`, scale 20, and scale 100.
  - M-05q (region refusal on empty triangulation) → E9's bow-tie case
    checks `triangulationFor` returns `isEmpty` (not null) and that
    `addDraftedRegion` returns `null` and allocates no handle; an open
    polyline is checked separately, and the rectangle/circle positive
    cases are checked in the same test.
  - E10 pins the three degeneracy predicates against `Tolerance.standard`
    (1e-9), including a value one order of magnitude inside the tolerance
    (`1e-10`) and one clearly outside it (`0.001`).
- Confirmed the code performs no per-entity allocation beyond what
  `AddEntityCommand`/`AddRegionCommand.allocate` already do (this task adds
  only builder functions, not frame-path code, so the allocation invariant
  tests are unaffected and stayed at their prior counts inside
  `query_allocation_test.dart`).
- Confirmed no unused imports (`dart analyze` came back clean under the
  house rule that treats `unused_import`/`unused_element` as errors in the
  Flutter package; the pure-Dart package's analyzer also reported no
  issues).
- Confirmed the export line's placement keeps the barrel alphabetically
  sorted, consistent with its existing convention.

## Concerns

None. The brief's code compiled and passed verbatim; no ambiguity was found
in the plan's Rulings, Global Constraints or Review Focus sections that
bore on this task's scope (builder functions only — no tool, no UI, no
`SweepTracker`/`wrapAngle`, which the brief explicitly defers to Task 2 in
the same file).
