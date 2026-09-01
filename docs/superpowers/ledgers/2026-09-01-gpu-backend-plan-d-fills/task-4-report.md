# Task 4 report: the fill corpus, and a guard that it is not degenerate

Commit: `6c1b980` on `plan-d/fills` (parent `a102be5`).

## What changed

- `packages/jet_cad_2d_flutter/test/support/fixtures.dart`: added
  `fillFixture()` (handles 900–905, 910, exactly as specified), plus three
  private helpers it needs for the second guard test:
  `_screenBoxOf` (an entity's screen-space AABB, folding in an instance's
  placement and the camera), `_rasterizeFillFixture` (paints the document
  through `VerticesDrawSink` into a `TriangleRasterizer`), and the public
  `strokeInkInsideFill(doc)` (paints with and without handle 903, counts
  differing screen pixels inside the fill's own box). Imports gained
  `Canvas`, `PictureRecorder` from `dart:ui` and a relative import of
  `triangle_rasterizer.dart` (a sibling test-support file, not part of
  either package's public barrel).
- `packages/jet_cad_2d_flutter/test/support/fixtures_test.dart`: appended
  `group('fillFixture', ...)` with the brief's two guard tests, adapted for
  the real `DocumentTree` API (`doc.tree[handle]`, not `nodeOf`).

## Where the brief's literals were adapted (Ruling D-P2)

- **`AddLayerCommand` does not exist.** Layers are added directly via
  `doc.tables.layers.add(LayerRecord(...))` — verified against
  `packages/jet_cad_2d/test/document/style_resolver_test.dart`'s own
  `addLayer` helper, which does the same thing. The hairline layer's handle
  is a hardcoded `const Handle(895)` rather than `doc.handleSeed.next()`, to
  keep every handle in this fixture visible as a literal the way 890 and
  900–910 already are.
- **`LayerRecord` requires `transparency`** (a required named argument the
  brief's literal omitted); supplied `transparency: 0`.
- **`doc.tree.nodeOf(handle)` does not exist.** `DocumentTree` only exposes
  `operator [](Handle)`. Every place the brief used `nodeOf` — the guard
  test and `strokeInkInsideFill` — uses `doc.tree[handle]` instead, matching
  the existing `shadedDashFixture` guard test's own style two tests above.
- Everything else in the brief's `fillFixture()` body — `AddRegionCommand`'s
  three named parameters, `EntityRecord`'s eleven required fields,
  `GeometryPayload`, `TrueColor`, `Transform2`, `InstanceNode` — matched the
  real API verbatim against `packages/jet_cad_2d/lib/src/document/commands.dart`,
  `entity_store.dart`, `tables.dart`, `transform2.dart` and `node.dart`.
- One design deviation beyond API drift: **lineweight 60 (0.6 mm) on
  handles 900 and 903 was not enough** — the second guard test's own
  200-pixel floor measured 172 shared pixels and failed. Raised both to
  `lineweight: 120` (1.2 mm); re-measured at 337, comfortably past the
  floor. This only widens the strokes; it does not touch the fill's own
  hairline lineweight (still 1).

## Triangulation: materialised automatically, not supplied by hand

Read `AddRegionCommand.apply` in
`packages/jet_cad_2d/lib/src/document/commands.dart` directly rather than
assuming: it calls `triangulationFor(boundary.kind, boundaryPayload)` itself
and, when the result is non-empty, calls `target.fills.putTriangles(...)`
before returning — for **every** `AddRegionCommand`, not just the ones a
test builds by hand. So `fillFixture()`'s polygon boundary (902) needed no
manual `putTriangles` call, and the guard's
`doc.fills.trianglesFor(const Handle(902))` assertion checks a real
invariant of the command, not a fact only true because the fixture pre-fed
it. (Boundary 905 is a circle: `triangulationFor` returns an *empty*,
non-null `Int32List` for a circle with positive radius, and `apply` skips
`putTriangles` on an empty list — a circle boundary is fanned per frame
instead, by design, so `trianglesFor(905)` is correctly `null` and the
guard never checks it.)

## Measured overlap

`strokeInkInsideFill(doc)` returned **337** differing screen pixels inside
handle 902's screen-space box, against the guard's `greaterThan(200)` floor
— printed via a temporary `print()` during development, then removed before
the final commit (not present in the committed diff).

## Killability, verified by mutation (not assumed)

For each check, I broke the fixture, watched the specific test go red, then
restored the file (`diff` confirmed byte-identical after every restore)
before committing.

1. **Boundary not closed** (`2, 2.001` in place of the closing `2, 2`):
   `AddRegionCommand.apply` itself throws `Bad state: 386 is not a fillable
   boundary` — both `fillFixture` guard tests go red at construction. Kills
   any regression that lets the polygon boundary's closing point drift.
2. **Handle 903 moved away from the fill** (`[100, 100, 117, 90]` instead of
   `[3, 12, 17, 2]`): `strokeInkInsideFill` returns exactly `0`; the overlap
   test fails (`Expected: a value greater than <200>, Actual: <0>`) while
   the first guard test (which never reads 903's geometry) stays green.
   This is the guard the brief calls out as the reason the corpus exists:
   without it, a fixture where 903 only sits *near* the fill would pass
   silently and Task 7's order-permutation gate would pass vacuously too.
3. **Translucent fill made opaque** (`transparency: 0` instead of `128`):
   `translucent, greaterThan(0)` fails (`Actual: <0>`).
4. **Placement flattened to identity**: `node.transform.a` no longer differs
   from `.d` — `not a numeric value within <1e-9> of <1.0>` fails against
   `Actual: <1.0>`.

**One assertion in the brief's own guard is not killable by any mutation of
`fillFixture()`'s body, and I did not remove it because Ruling D-P2 binds
it as part of the required shape:**
`expect(const Handle(900).value, lessThan(const Handle(901).value))` and the
paired `Handle(903)` check compare `Handle` literals written directly in the
*test* file against each other — `900 < 901 < 903` is true at compile time
regardless of what `fillFixture()` builds, so no runtime mutation of the
fixture can turn it red. The property it's meant to guard (strokes really
do sit on both sides of the fill, in handle order, in the actual document)
is the thing the second guard test (`strokeInkInsideFill`) verifies for
real, by measurement rather than by literal comparison. Flagging this for
the reviewer rather than silently deleting or rewriting a check the ruling
described as part of the binding shape.

## Verbatim gate output

`packages/jet_cad_2d_flutter`:

```
$ flutter test
...
00:06 +552 ~1: All tests passed!
EXIT_TEST=0

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)
EXIT_ANALYZE=0

$ dart format --output=none --set-exit-if-changed .
Formatted 91 files (0 changed) in 0.13 seconds.
EXIT_FORMAT=0
```

(First `dart format` run before this report *did* print `Formatted test/support/fixtures.dart` / `(1 changed)` — the file wasn't yet
gofmt-clean. Ran `dart format test/support/fixtures.dart` to fix it, then
re-ran the full check above, which came back `(0 changed)`.)

`packages/jet_cad_2d`:

```
$ dart test
...
00:02 +798: All tests passed!
EXIT_TEST=0

$ dart analyze
Analyzing jet_cad_2d...
No issues found!
EXIT_ANALYZE=0

$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.14 seconds.
EXIT_FORMAT=0
```

552 tests in `jet_cad_2d_flutter` (up from STATUS.md's merged-tree baseline
of 540; Tasks 1–3 already added some, this task added 2 more), 1
pre-existing skip carried forward unchanged. `jet_cad_2d` unaffected at 798
(up from 797 pre-Task-1 baseline — this task touches only
`jet_cad_2d_flutter`, so the +1 there is from an earlier task in this plan).

## `analysis_options.yaml`

`git status --short` before commit showed only the two intended files;
nothing named `analysis_options.yaml` appeared, so no `git checkout --` was
needed.

## Files touched

- `/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/support/fixtures.dart`
- `/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/support/fixtures_test.dart`
