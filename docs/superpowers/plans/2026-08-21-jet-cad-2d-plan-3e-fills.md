# Plan 3e — Solid fills — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A closed boundary paints a solid colour beneath its own outline, in the correct draw order, at zero per-entity frame cost, on both render backends.

**Architecture:** A new `EntityKind.fill` stores no geometry — only its boundary entity's handle. Draw order is *reserved* rather than overridden: one command allocates both handles, fill first, so "draw order is ascending handle value" stays literally true and no other subsystem moves. Polygon boundaries are ear-clipped once, off the frame path, into a cache keyed by the boundary's `Handle`; circles are never cached because their triangulation is scale-dependent, and are fanned per frame like the stroked circle already is.

**Tech Stack:** Dart 3.13 (`packages/jet_cad_2d`, no `dart:ui`), Flutter 3.47 (`packages/jet_cad_2d_flutter`), `vector_math`, `dart:typed_data`. Tests: `package:test`, `flutter_test`, the repo's `TriangleRasterizer`, `sink_comparison.dart`, `reference_query.dart`.

**Spec:** [`docs/superpowers/specs/2026-08-21-jet-cad-2d-plan-3e-design.md`](../specs/2026-08-21-jet-cad-2d-plan-3e-design.md) — binding. Read it before Task 1.

**Branch:** work happens directly on `main`. There is no worktree for this plan.

## Global Constraints

Copied from `CLAUDE.md` and the spec. Every task's requirements implicitly include this section.

- **The frame path allocates nothing per entity in steady state, and O(1) per flush.** `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` and `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart` measure it.
- **Draw order is ascending handle value**, stable across undo, save, load and purge.
- **Geometric *decisions* use `Tolerance`; *stored value* comparisons are exact `==`.** A boundary's closedness is a stored-value comparison: exact, never tolerant.
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three of them in this workspace. Check `git status` after any pub operation.
- **Never commit `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`** — CocoaPods rewrites it on every `flutter run`/`flutter drive`.
- **Never synthesize test output.** Reviewers verify claims independently; a fabricated transcript invalidates the task.
- **Never `git checkout` a file to revert a mutation.** It restores HEAD and wipes every uncommitted change in that file. Copy the file aside first (`cp`) and restore from the copy in a `trap`.
- Code, comments and commit messages in English.
- **The triangulation cache is keyed by the boundary's `Handle`, never by `geomIndex`.** `purge()` renumbers every `geomIndex` wholesale.
- **The frame path reads the cache and never computes it.** Entries are materialised at `AddRegionCommand`, `SetEntityGeometryCommand`, codec load, and undo/redo.
- **`TriangleRasterizer` does not blend** — `pixels[i] = rgba`, last write wins. It can measure coverage and never a blending artefact.

### Every task ends green

```sh
cd packages/jet_cad_2d       && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

Tasks 14 onwards also run `flutter test --tags golden`.

### Testing bar

A new test is worth landing only if a **named mutation** makes it go red. Every task that adds a test names the mutation in its commit message and states whether it was run. The dominant defect class here is the **degenerate fixture**: every boundary convex, every winding counter-clockwise, every document un-purged, every lineweight normal.

---

## Shared test vocabulary

Several tasks use the same fixture names. They are defined **once**, here, and
each task that uses one copies it into its own test file's top — these packages
have no shared test-fixture library beyond `test/support/`, and inventing one
for this plan is out of scope.

```dart
// Engine tests (packages/jet_cad_2d/test/). Task 4 introduces `region`; Tasks
// 5, 6, 9 and 10 use it unchanged.
GeometryPayload squareLoop() => GeometryPayload(
    coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
    scalars: Float64List(0));

AddRegionCommand region(DraftDocument doc) => AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.polyline,
      boundaryPayload: squareLoop(),
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x3366CC),
      boundaryColor: const TrueColor(0x000000),
    );
```

```dart
// Sink tests (Tasks 11 and 12).
final Float64List square =
    Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]);
final Int32List tri = Int32List.fromList([0, 1, 2, 0, 2, 3]);
const ResolvedStyle opaque =
    ResolvedStyle(argb: 0xFF3366CC, lineweightHundredths: 30);
const ResolvedStyle style = opaque;

/// A sink at a known device pixel ratio, so the width floor and the flattening
/// step count are both determined rather than inherited from the test binding.
VerticesDrawSink harness() => VerticesDrawSink(
    pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 3.0);
```

```dart
// Painter tests (Task 13). `DraftPainter`'s existing tests already build this
// shape; copy the setup from `test/draft_painter_test.dart` rather than
// re-deriving it.
DraftPainter paintOnce(DraftDocument doc, DrawSink sink);
void paintAgain(DraftPainter painter, DrawSink sink);
```

```dart
// Comparison and seam tests (Tasks 14 and 15).
DraftDocument fillComparisonDoc();   // the five-property fixture named in Task 14
void drawAll(DrawSink sink);         // walks fillComparisonDoc through a painter
void translucentFill(DrawSink sink); // one alpha-0x80 notched polygon
Iterable<(int, int)> interiorPixels();       // the fill's interior, eroded 1 device px
int maxChannelDelta(ByteData a, ByteData b, int x, int y);
DrawSink canvasSink(Canvas c);       // CanvasDrawSink at kLogicalPixelsPerMm
DrawSink verticesSink(Canvas c);     // VerticesDrawSink writing into `c` on flush
```

---

## File Structure

**Created**

| path | responsibility |
|---|---|
| `packages/jet_cad_2d/lib/src/geometry/triangulate.dart` | `triangulateSimplePolygon` — ear clipping, winding normalisation, pure math, no document types |
| `packages/jet_cad_2d/lib/src/document/fill_index.dart` | `FillIndex` — the boundary→triangles cache and the boundary→fills reverse map, in one object because they are invalidated together |
| `packages/jet_cad_2d/test/geometry/triangulate_test.dart` | triangulator unit tests |
| `packages/jet_cad_2d/test/document/fill_index_test.dart` | cache and reverse-map tests, including purge |
| `packages/jet_cad_2d/test/document/region_command_test.dart` | `AddRegionCommand`, `SetEntityGeometryCommand`, cascade removal |
| `packages/jet_cad_2d_flutter/test/fill_render_test.dart` | fill ops through the painter into both sinks |
| `packages/jet_cad_2d_flutter/test/fill_seam_test.dart` | the translucent-seam measurement, against `picture.toImage()` |
| `packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart` | fill goldens, both backends |

**Modified**

| path | change |
|---|---|
| `packages/jet_cad_2d/lib/src/store/entity_store.dart` | `EntityKind.fill` appended |
| `packages/jet_cad_2d/lib/src/document/extents.dart` | `entityBounds` gains `boundaryKind` / `boundaryPayload`; `fill` case |
| `packages/jet_cad_2d/lib/src/document/commands.dart` | `AddRegionCommand`, `SetEntityGeometryCommand`, `RemoveEntityCommand` cascade |
| `packages/jet_cad_2d/lib/src/document/command.dart` | `CommandTarget` gains `FillIndex get fills` |
| `packages/jet_cad_2d/lib/src/document/draft_document.dart` | owns the `FillIndex`; `purge()` leaves it alone, deliberately |
| `packages/jet_cad_2d/lib/src/document/validate.dart` | five `fill.*` codes |
| `packages/jet_cad_2d/lib/src/codec/schema_version.dart` | `kSchemaVersion = 5` |
| `packages/jet_cad_2d/lib/src/codec/json_codec.dart` | load rebuilds the `FillIndex` |
| `packages/jet_cad_2d/lib/src/index/spatial_index.dart` | `fill` cases: no pick, no snap |
| `packages/jet_cad_2d/test/invariants/reference_query.dart` | `fill` cases in both switches |
| `packages/jet_cad_2d_flutter/lib/src/draw_sink.dart` | `fillPolygon`, `fillCircle`, and their `DrawOp`s |
| `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart` | path fill; circle fill |
| `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` | indexed triangles; circle fan; `_coveredArgb` invariant |
| `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart` | fill emission, `skippedFillCount`, the empty-triangulation skip |
| `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart` | fills, independently |
| `apps/dev_harness_2d/lib/main.dart` | `FILLS` define and the corpus's fills |
| `apps/dev_harness_2d/lib/measurement_rig.dart` | fill counters in `printInvariants` |

---

## Task 1: `EntityKind.fill` and the four exhaustive switches

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/store/entity_store.dart:9`
- Modify: `packages/jet_cad_2d/lib/src/document/extents.dart`
- Modify: `packages/jet_cad_2d/lib/src/index/spatial_index.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`
- Modify: `packages/jet_cad_2d/test/invariants/reference_query.dart`
- Test: `packages/jet_cad_2d/test/store/entity_store_test.dart`

**Interfaces:**
- Produces: `EntityKind.fill`, appended last. `Handle boundaryHandleOf(GeometryPayload)` in `entity_store.dart`, returning `Handle.none` when `scalars` is empty.

**Why appended:** `EntityRecord` serialises `kind.name` and reads it with `EntityKind.values.byName`, so JSON never depends on ordinal — but `EntityStore` stores `_kind[slot] = r.kind.index` in a `Uint8List`, which does. Appending costs nothing and settles both.

Adding the member breaks compilation at four `switch` sites in `lib/` plus one in the oracle. That is the safety net working; this task closes all five with the *inert* answer, so a fill is storable and draws nothing yet.

- [ ] **Step 1: Write the failing test**

In `packages/jet_cad_2d/test/store/entity_store_test.dart`:

```dart
test('fill is the last EntityKind, and its ordinal is stable', () {
  // The store writes `kind.index` into a Uint8List column. Inserting a member
  // rather than appending would silently renumber every stored kind.
  expect(EntityKind.values.last, EntityKind.fill);
  expect(EntityKind.fill.index, 7);
});

test('boundaryHandleOf reads the boundary from scalars, and none when absent',
    () {
  final withBoundary = GeometryPayload(
      coords: Float64List(0), scalars: Float64List.fromList([4919.0]));
  expect(boundaryHandleOf(withBoundary), const Handle(4919));

  final empty =
      GeometryPayload(coords: Float64List(0), scalars: Float64List(0));
  expect(boundaryHandleOf(empty), Handle.none);
});
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/store/entity_store_test.dart`
Expected: FAIL — `EntityKind.fill` is not defined.

- [ ] **Step 3: Add the member and the reader**

In `entity_store.dart`, line 9:

```dart
/// `fill` is appended, never inserted: [EntityStore] stores `kind.index` in a
/// `Uint8List` column, so an insertion renumbers every stored document's kinds
/// in memory. The JSON is safe either way -- it carries `kind.name`.
enum EntityKind { point, line, polyline, circle, arc, text, attrib, fill }
```

and, below `EntityRecord`:

```dart
/// The boundary a fill entity names, or [Handle.none] if its payload carries
/// none.
///
/// A fill stores no coordinates. Its whole geometry is one scalar: the handle
/// of the entity whose loop it fills. A handle is an `int` at most
/// `kMaxHandle` (0xFFFFFFFF), far under 2^53, so the round trip through
/// `double` is exact in both directions.
Handle boundaryHandleOf(GeometryPayload payload) =>
    payload.scalars.isEmpty ? Handle.none : Handle(payload.scalars[0].toInt());
```

- [ ] **Step 4: Close the four `lib/` switches with the inert answer**

`extents.dart` — a fill's own payload has no points, and this task does not yet resolve boundaries:

```dart
      case EntityKind.fill:
        // Task 9 gives this case the boundary's box. Until then a fill bounds
        // to nothing, which is what its own payload says.
        return Aabb2.empty();
```

`spatial_index.dart` — every `switch (kind)` in `_considerLeaf` and
`_considerSnapLeaf` gets:

```dart
      case EntityKind.fill:
        // A fill is drawn, not picked. See Task 10 -- this is the final
        // answer, not a placeholder.
        break;
```

`reference_walk.dart` and `draft_painter.dart` — the same shape:

```dart
      case EntityKind.fill:
        // Task 13 draws it.
        break;
```

`reference_query.dart` — the two `switch (record.kind)` statements get a
`case EntityKind.fill: break;` each, with the comment `a fill produces no hit
and no snap candidate`.

- [ ] **Step 5: Run the whole suite on both packages**

```sh
cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```
Expected: all green, and the two new tests pass.

- [ ] **Step 6: Run the named mutation**

```sh
cd packages/jet_cad_2d
cp lib/src/store/entity_store.dart /tmp/t1.dart
trap 'cp /tmp/t1.dart lib/src/store/entity_store.dart' EXIT
# MUTANT T1a: insert rather than append
perl -0pi -e 's/enum EntityKind \{ point, line, polyline, circle, arc, text, attrib, fill \}/enum EntityKind { fill, point, line, polyline, circle, arc, text, attrib }/' lib/src/store/entity_store.dart
dart test test/store/entity_store_test.dart   # must FAIL
cp /tmp/t1.dart lib/src/store/entity_store.dart
```

- [ ] **Step 7: Commit**

```bash
git add -A packages/jet_cad_2d packages/jet_cad_2d_flutter
git commit -m "feat: EntityKind.fill, stored and inert"
```

---

## Task 2: The triangulator

**Files:**
- Create: `packages/jet_cad_2d/lib/src/geometry/triangulate.dart`
- Create: `packages/jet_cad_2d/test/geometry/triangulate_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart` (export)

**Interfaces:**
- Produces: `Int32List triangulateSimplePolygon(Float64List coords, int count)` — returns triple-indices into `coords`, counter-clockwise, or an **empty** `Int32List` when the loop cannot be reduced. Never throws.

**Contract.** `count` is the polyline's stored point count *including* the duplicated closing point, exactly as the store holds it. The function ignores the last point. It requires at least 3 distinct points after that; anything less returns empty.

- [ ] **Step 1: Write the failing tests**

`packages/jet_cad_2d/test/geometry/triangulate_test.dart`:

```dart
import 'dart:typed_data';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

/// A closed loop in store form: first point repeated as the last.
Float64List loop(List<double> xy) => Float64List.fromList([...xy, xy[0], xy[1]]);

/// Twice the signed area of the triangle, so orientation is readable.
double cross(Float64List c, int a, int b, int d) =>
    (c[b * 2] - c[a * 2]) * (c[d * 2 + 1] - c[a * 2 + 1]) -
    (c[b * 2 + 1] - c[a * 2 + 1]) * (c[d * 2] - c[a * 2]);

double areaOf(Float64List c, Int32List t) {
  var sum = 0.0;
  for (var i = 0; i < t.length; i += 3) {
    sum += cross(c, t[i], t[i + 1], t[i + 2]).abs() / 2;
  }
  return sum;
}

void main() {
  test('a square yields two triangles covering its whole area', () {
    final c = loop([0, 0, 10, 0, 10, 10, 0, 10]);
    final t = triangulateSimplePolygon(c, c.length ~/ 2);
    expect(t.length, 6);
    expect(areaOf(c, t), closeTo(100.0, 1e-9));
  });

  test('an L-shape is triangulated, and the concave vertex is not an ear', () {
    // The product case. A fan from any vertex would leave the notch filled.
    final c = loop([0, 0, 20, 0, 20, 10, 10, 10, 10, 20, 0, 20]);
    final t = triangulateSimplePolygon(c, c.length ~/ 2);
    expect(t.length, 12, reason: 'six vertices reduce to four triangles');
    expect(areaOf(c, t), closeTo(300.0, 1e-9),
        reason: 'an L of 20x10 plus 10x10 is 300, not the 400 a naive fan '
            'across the notch would produce');
  });

  test('a clockwise loop is normalised, not rejected', () {
    // The degenerate fixture this repo keeps shipping: every fixture wound the
    // same way. DXF produces both windings.
    final ccw = loop([0, 0, 10, 0, 10, 10, 0, 10]);
    final cw = loop([0, 0, 0, 10, 10, 10, 10, 0]);
    final a = triangulateSimplePolygon(ccw, ccw.length ~/ 2);
    final b = triangulateSimplePolygon(cw, cw.length ~/ 2);
    expect(b.length, a.length);
    expect(areaOf(cw, b), closeTo(100.0, 1e-9));
    for (var i = 0; i < b.length; i += 3) {
      expect(cross(cw, b[i], b[i + 1], b[i + 2]), greaterThan(0),
          reason: 'every emitted triangle must be counter-clockwise whatever '
              'the input winding');
    }
  });

  test('collinear runs do not stall the clipper', () {
    final c = loop([0, 0, 5, 0, 10, 0, 10, 10, 0, 10]);
    final t = triangulateSimplePolygon(c, c.length ~/ 2);
    expect(areaOf(c, t), closeTo(100.0, 1e-9));
  });

  test('a self-intersecting loop returns empty rather than guessing', () {
    final c = loop([0, 0, 10, 10, 10, 0, 0, 10]); // a bow tie
    expect(triangulateSimplePolygon(c, c.length ~/ 2), isEmpty);
  });

  test('fewer than three distinct points returns empty', () {
    final c = loop([0, 0, 10, 0]);
    expect(triangulateSimplePolygon(c, c.length ~/ 2), isEmpty);
  });
}
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/geometry/triangulate_test.dart`
Expected: FAIL — `triangulateSimplePolygon` is not defined.

- [ ] **Step 3: Implement**

`packages/jet_cad_2d/lib/src/geometry/triangulate.dart`:

```dart
import 'dart:typed_data';

/// Triangulates one simple closed loop by ear clipping.
///
/// [coords] is the boundary's stored `coords` -- interleaved x, y, with the
/// first point repeated as the last, which is how this model records
/// closedness. [count] is the stored point count including that duplicate; the
/// last point is ignored.
///
/// Returns triple-indices into [coords]' point numbering, every triangle wound
/// counter-clockwise whatever the input winding. Returns an **empty** list --
/// never throws, never guesses -- when the loop has fewer than three distinct
/// points, is degenerate, or cannot be reduced, which is what a
/// self-intersecting loop looks like from inside the clipper.
///
/// O(n^2). Room boundaries are tens of points, and this runs once per edit,
/// off the frame path -- see the plan's global constraints.
Int32List triangulateSimplePolygon(Float64List coords, int count) {
  final n = count - 1; // drop the duplicated closing point
  if (n < 3) return Int32List(0);

  final index = List<int>.generate(n, (i) => i);
  if (_signedArea(coords, index) < 0) {
    // Normalised, not rejected: DXF produces both windings, and every ear test
    // below assumes counter-clockwise.
    index.setAll(0, index.reversed.toList());
  }

  final out = <int>[];
  var guard = n * n; // the clipper must strictly shrink; this bounds a stall
  while (index.length > 3 && guard-- > 0) {
    var clipped = false;
    for (var i = 0; i < index.length; i++) {
      final a = index[(i - 1 + index.length) % index.length];
      final b = index[i];
      final c = index[(i + 1) % index.length];
      if (!_isEar(coords, index, a, b, c)) continue;
      out..add(a)..add(b)..add(c);
      index.removeAt(i);
      clipped = true;
      break;
    }
    // No ear anywhere means the loop is not simple. Say so by returning
    // nothing rather than emitting a partial cover that looks like a drawing.
    if (!clipped) return Int32List(0);
  }
  if (index.length != 3) return Int32List(0);
  out..add(index[0])..add(index[1])..add(index[2]);
  return Int32List.fromList(out);
}

double _signedArea(Float64List c, List<int> index) {
  var sum = 0.0;
  for (var i = 0; i < index.length; i++) {
    final p = index[i], q = index[(i + 1) % index.length];
    sum += c[p * 2] * c[q * 2 + 1] - c[q * 2] * c[p * 2 + 1];
  }
  return sum / 2;
}

double _cross(Float64List c, int a, int b, int d) =>
    (c[b * 2] - c[a * 2]) * (c[d * 2 + 1] - c[a * 2 + 1]) -
    (c[b * 2 + 1] - c[a * 2 + 1]) * (c[d * 2] - c[a * 2]);

bool _isEar(Float64List c, List<int> index, int a, int b, int d) {
  final area = _cross(c, a, b, d);
  // Reflex or collinear: not an ear. `<= 0` rather than `< 0` so a collinear
  // run is skipped here and clipped from one of its neighbours instead, which
  // is why the collinear fixture does not stall.
  if (area <= 0) return false;
  for (final p in index) {
    if (p == a || p == b || p == d) continue;
    if (_cross(c, a, b, p) >= 0 &&
        _cross(c, b, d, p) >= 0 &&
        _cross(c, d, a, p) >= 0) {
      return false;
    }
  }
  return true;
}
```

Export it from `packages/jet_cad_2d/lib/jet_cad_2d.dart` beside the other
`src/geometry/` exports.

- [ ] **Step 4: Run and watch it pass**

Run: `cd packages/jet_cad_2d && dart test test/geometry/triangulate_test.dart`
Expected: PASS, six tests.

- [ ] **Step 5: Run the named mutations**

```sh
cd packages/jet_cad_2d
F=lib/src/geometry/triangulate.dart
cp "$F" /tmp/t2.dart
trap 'cp /tmp/t2.dart "$F"' EXIT
run() { dart test test/geometry/triangulate_test.dart >/dev/null 2>&1 && echo SURVIVED || echo KILLED; }

# T2a: drop winding normalisation
perl -0pi -e 's/  if \(_signedArea\(coords, index\) < 0\) \{/  if (false) {/' "$F"; run; cp /tmp/t2.dart "$F"
# T2b: emit a fan instead of clipping ears
perl -0pi -e 's/    if \(!_isEar\(coords, index, a, b, c\)\) continue;/    if (false) continue;/' "$F"; run; cp /tmp/t2.dart "$F"
# T2c: return a partial cover instead of nothing when no ear is found
perl -0pi -e 's/    if \(!clipped\) return Int32List\(0\);/    if (!clipped) break;/' "$F"; run; cp /tmp/t2.dart "$F"
# T2d: accept reflex vertices as ears
perl -0pi -e 's/  if \(area <= 0\) return false;/  if (area == 0) return false;/' "$F"; run; cp /tmp/t2.dart "$F"
```

All four must print `KILLED`. **T2a is killed only by the clockwise fixture** — if it survives, the fixture set is degenerate and the task is not done.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d/lib/src/geometry/triangulate.dart \
        packages/jet_cad_2d/lib/jet_cad_2d.dart \
        packages/jet_cad_2d/test/geometry/triangulate_test.dart
git commit -m "feat: ear-clipping triangulator for simple closed loops"
```

---

## Task 3: `FillIndex` — the cache and the reverse map

**Files:**
- Create: `packages/jet_cad_2d/lib/src/document/fill_index.dart`
- Create: `packages/jet_cad_2d/test/document/fill_index_test.dart`
- Modify: `packages/jet_cad_2d/lib/src/document/command.dart` (`CommandTarget` gains `FillIndex get fills`)
- Modify: `packages/jet_cad_2d/lib/src/document/draft_document.dart` (owns one, exposes it)
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart` (export)

**Interfaces:**
- Consumes: `triangulateSimplePolygon` (Task 2), `boundaryHandleOf` (Task 1).
- Produces:
```dart
class FillIndex {
  Int32List? trianglesFor(Handle boundary);
  void putTriangles(Handle boundary, Int32List triangles);
  void link(Handle fill, Handle boundary);
  void unlink(Handle fill);
  List<Handle> fillsOf(Handle boundary);   // ascending handle order
  void dropTriangles(Handle boundary);     // triangles only; links stay (Task 5)
  void dropBoundary(Handle boundary);      // triangles + every link naming it
  void clear();
  int get entryCount;                      // triangulations held
  int get linkCount;                       // fill -> boundary links held
}
```

**Why one object.** The cache and the reverse map are written by the same three commands, invalidated at the same moments, and rebuilt together on load. Two objects would be two chances to update one and forget the other — the shape of the defect this plan is most exposed to.

**Why the key is a `Handle`.** `purge()` renumbers every `geomIndex` wholesale (`draft_document.dart`), so a `geomIndex`-keyed cache is not stale after a purge but **permuted**. Handles survive purge, are never reissued, and undo restores them. A missed invalidation is then a leak, not a wrong drawing.

- [ ] **Step 1: Write the failing tests**

`packages/jet_cad_2d/test/document/fill_index_test.dart`:

```dart
import 'dart:typed_data';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  test('triangles round-trip by boundary handle', () {
    final ix = FillIndex();
    expect(ix.trianglesFor(const Handle(20)), isNull);
    ix.putTriangles(const Handle(20), Int32List.fromList([0, 1, 2]));
    expect(ix.trianglesFor(const Handle(20)), [0, 1, 2]);
    expect(ix.entryCount, 1);
  });

  test('a hit returns the stored list itself, not a copy', () {
    // The frame path reads this per fill per frame. A defensive copy here
    // would allocate per entity and break the global constraint.
    final ix = FillIndex();
    final stored = Int32List.fromList([0, 1, 2]);
    ix.putTriangles(const Handle(20), stored);
    expect(identical(ix.trianglesFor(const Handle(20)), stored), isTrue);
  });

  test('fillsOf returns every fill naming a boundary, in handle order', () {
    final ix = FillIndex();
    ix.link(const Handle(31), const Handle(40));
    ix.link(const Handle(19), const Handle(40));
    ix.link(const Handle(22), const Handle(41));
    expect(ix.fillsOf(const Handle(40)), [const Handle(19), const Handle(31)]);
    expect(ix.fillsOf(const Handle(41)), [const Handle(22)]);
    expect(ix.fillsOf(const Handle(99)), isEmpty);
  });

  test('dropBoundary removes the triangles and every link naming it', () {
    final ix = FillIndex();
    ix.putTriangles(const Handle(40), Int32List.fromList([0, 1, 2]));
    ix.link(const Handle(19), const Handle(40));
    ix.link(const Handle(31), const Handle(40));
    ix.dropBoundary(const Handle(40));
    expect(ix.trianglesFor(const Handle(40)), isNull);
    expect(ix.fillsOf(const Handle(40)), isEmpty);
    expect(ix.entryCount, 0);
    expect(ix.linkCount, 0,
        reason: 'a link left behind after its boundary died is the leak the '
            'handle key was chosen to make harmless -- but it is still a leak');
  });

  test('unlink removes one fill and leaves its siblings', () {
    final ix = FillIndex();
    ix.link(const Handle(19), const Handle(40));
    ix.link(const Handle(31), const Handle(40));
    ix.unlink(const Handle(19));
    expect(ix.fillsOf(const Handle(40)), [const Handle(31)]);
  });

  test('the index survives a purge because handles do', () {
    // The purge test that a geomIndex-keyed cache cannot pass. Two entities,
    // one removed, then purge -- which renumbers every geomIndex and leaves
    // every handle alone.
    final doc = DraftDocument.empty();
    final a = doc.handleSeed.next();
    final b = doc.handleSeed.next();
    for (final h in [a, b]) {
      doc.commands.execute(AddEntityCommand(
        record: EntityRecord(
          handle: h,
          owner: doc.rootHandle,
          kind: EntityKind.polyline,
          layer: ReservedHandles.layerZero,
          linetype: ReservedHandles.continuousLinetype,
          linetypeScale: 1.0,
          geomIndex: 0,
          color: const TrueColor(0x000000),
          lineweight: 30,
          transparency: 0,
          flags: 0,
        ),
        payload: GeometryPayload(
            coords: Float64List.fromList(
                h == a ? [0, 0, 1, 0, 1, 1, 0, 0] : [5, 5, 6, 5, 6, 6, 5, 5]),
            scalars: Float64List(0)),
      ));
    }
    doc.fills.putTriangles(b, Int32List.fromList([0, 1, 2]));
    doc.commands.execute(RemoveEntityCommand(a));
    doc.purge();
    expect(doc.fills.trianglesFor(b), [0, 1, 2],
        reason: 'purge renumbers every geomIndex and touches no handle, so a '
            'handle-keyed entry is still attached to the same entity');
  });
}
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/document/fill_index_test.dart`
Expected: FAIL — `FillIndex` is not defined.

- [ ] **Step 3: Implement**

`packages/jet_cad_2d/lib/src/document/fill_index.dart`:

```dart
import 'dart:typed_data';

import '../core/handle.dart';

/// Derived state for fills: one triangulation per boundary, and the reverse
/// map from a boundary to the fills that name it.
///
/// **Keyed by `Handle`, never by `geomIndex`.** `DraftDocument.purge()`
/// renumbers every `geomIndex` from a remap table, so a slot-keyed cache does
/// not go stale across a purge -- it goes *permuted*, every surviving entry
/// attached to the wrong entity at once. Handles are never reissued
/// (`HandleSeed.next` only increments) and `RemoveEntityCommand`'s inverse
/// restores the same handle, so a stale entry here can only ever be an entry
/// nobody reads. The failure mode is a leak, not a lie.
///
/// **Never populated on the frame path.** Commands and the codec fill it; the
/// painter only reads. [trianglesFor] returns the stored list itself rather
/// than a copy, because the alternative allocates once per fill per frame.
///
/// Both halves live in one object because the same three commands write both
/// and the same moments invalidate both.
class FillIndex {
  final Map<Handle, Int32List> _triangles = {};
  final Map<Handle, Handle> _boundaryOfFill = {};

  Int32List? trianglesFor(Handle boundary) => _triangles[boundary];

  void putTriangles(Handle boundary, Int32List triangles) {
    _triangles[boundary] = triangles;
  }

  void link(Handle fill, Handle boundary) {
    _boundaryOfFill[fill] = boundary;
  }

  void unlink(Handle fill) {
    _boundaryOfFill.remove(fill);
  }

  /// Every fill naming [boundary], in ascending handle order.
  ///
  /// Ordered because callers put these into a command's `touched` set and into
  /// removal cascades, and this project's determinism rests on stable orders.
  List<Handle> fillsOf(Handle boundary) {
    final out = <Handle>[
      for (final e in _boundaryOfFill.entries)
        if (e.value == boundary) e.key,
    ];
    out.sort((a, b) => a.value.compareTo(b.value));
    return out;
  }

  void dropBoundary(Handle boundary) {
    _triangles.remove(boundary);
    _boundaryOfFill.removeWhere((_, b) => b == boundary);
  }

  void clear() {
    _triangles.clear();
    _boundaryOfFill.clear();
  }

  int get entryCount => _triangles.length;
  int get linkCount => _boundaryOfFill.length;
}
```

In `command.dart`, add to `CommandTarget`:

```dart
  /// The fill cache and the boundary->fills map. A command that changes a
  /// boundary's geometry or removes one must keep this current; see
  /// `SetEntityGeometryCommand` and `RemoveEntityCommand`.
  FillIndex get fills;
```

In `draft_document.dart`, add the field, the getter, and — deliberately — **no
call in `purge()`**:

```dart
  final FillIndex fills = FillIndex();
```

with a comment at `purge()`:

```dart
    // `fills` is deliberately untouched. It is keyed by handle, and purge
    // renumbers slots, not handles. Adding an invalidation here would be
    // correct-looking and wrong: it would throw away work nothing invalidated.
```

- [ ] **Step 4: Run and watch it pass**

Run: `cd packages/jet_cad_2d && dart test test/document/fill_index_test.dart`
Expected: PASS, six tests.

- [ ] **Step 5: Run the named mutations**

```sh
cd packages/jet_cad_2d
F=lib/src/document/fill_index.dart
cp "$F" /tmp/t3.dart
trap 'cp /tmp/t3.dart "$F"' EXIT
run() { dart test test/document/fill_index_test.dart >/dev/null 2>&1 && echo SURVIVED || echo KILLED; }

# T3a: return a defensive copy -- allocates per fill per frame
perl -0pi -e 's/  Int32List\? trianglesFor\(Handle boundary\) => _triangles\[boundary\];/  Int32List? trianglesFor(Handle boundary) { final t = _triangles[boundary]; return t == null ? null : Int32List.fromList(t); }/' "$F"; run; cp /tmp/t3.dart "$F"
# T3b: dropBoundary forgets the links
perl -0pi -e 's/    _boundaryOfFill\.removeWhere\(\(_, b\) => b == boundary\);//' "$F"; run; cp /tmp/t3.dart "$F"
# T3c: fillsOf returns insertion order
perl -0pi -e 's/    out\.sort\(\(a, b\) => a\.value\.compareTo\(b\.value\)\);//' "$F"; run; cp /tmp/t3.dart "$F"
```

All three must print `KILLED`.

Also run the **keying** mutant, which is the one the purge test exists for. It
cannot be expressed as a one-line edit of this file; do it by hand: change
`trianglesFor`/`putTriangles`/`dropBoundary` to take an `int geomIndex`, and
have the purge test key by `doc.entities.read(doc.entities.slotOf(b)!).geomIndex`.
The purge test must go red. Record the transcript in the commit message.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d/lib/src/document/fill_index.dart \
        packages/jet_cad_2d/lib/src/document/command.dart \
        packages/jet_cad_2d/lib/src/document/draft_document.dart \
        packages/jet_cad_2d/lib/jet_cad_2d.dart \
        packages/jet_cad_2d/test/document/fill_index_test.dart
git commit -m "feat: FillIndex, keyed by handle so purge cannot permute it"
```

---

## Task 4: `AddRegionCommand`

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/commands.dart`
- Create: `packages/jet_cad_2d/test/document/region_command_test.dart`

**Interfaces:**
- Consumes: `FillIndex` (Task 3), `triangulateSimplePolygon` (Task 2), `boundaryHandleOf` (Task 1).
- Produces:
```dart
class AddRegionCommand extends DraftCommand {
  AddRegionCommand({required this.fill, required this.boundary,
      required this.boundaryPayload});
  final EntityRecord fill;         // handle strictly lower
  final EntityRecord boundary;
  final GeometryPayload boundaryPayload;

  static AddRegionCommand allocate({
    required HandleSeed seed,
    required Handle owner,
    required EntityKind boundaryKind,
    required GeometryPayload boundaryPayload,
    required Handle layer,
    required DraftColor fillColor,
    required DraftColor boundaryColor,
    int fillTransparency = 0,
    int boundaryLineweight = kLineweightDefault,
  });
}
class RemoveRegionCommand extends DraftCommand { ... }  // the inverse

/// Also produced here, and consumed by Tasks 5, 7 and 8.
///
/// null  = not a fillable boundary at all -> refused at command time
/// empty = a circle (fanned per frame, never cached), OR a fillable shape the
///         clipper could not reduce -> the painter skips it and counts it
Int32List? triangulationFor(EntityKind kind, GeometryPayload payload);
```

**The one rule this command exists for.** It allocates `fill` **before**
`boundary`, so the fill's handle is strictly lower and ascending handle order
draws it underneath. `apply` re-checks that invariant and throws if it does not
hold, so a hand-built command cannot invert it silently.

**One `apply`, not two composed.** The fill is written first and at that instant
its boundary does not exist. Composing two `AddEntityCommand`s would fire
`invalidateDerived()` between them and let an observer see a fill with a
dangling reference. This command writes both, then invalidates once.

- [ ] **Step 1: Write the failing tests**

`packages/jet_cad_2d/test/document/region_command_test.dart`:

```dart
import 'dart:typed_data';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

GeometryPayload squareLoop() => GeometryPayload(
    coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
    scalars: Float64List(0));

AddRegionCommand region(DraftDocument doc) => AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.polyline,
      boundaryPayload: squareLoop(),
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x3366CC),
      boundaryColor: const TrueColor(0x000000),
    );

void main() {
  test('the fill gets the lower handle, so it draws underneath', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    expect(cmd.fill.handle.value, lessThan(cmd.boundary.handle.value),
        reason: 'draw order is ascending handle value; a fill above its own '
            'boundary paints over its outline');
    doc.commands.execute(cmd);
    expect(doc.entities.slotOf(cmd.fill.handle), isNotNull);
    expect(doc.entities.slotOf(cmd.boundary.handle), isNotNull);
  });

  test('apply refuses an inverted pair rather than drawing it wrong', () {
    final doc = DraftDocument.empty();
    final good = region(doc);
    final inverted = AddRegionCommand(
      fill: good.fill.copyWith(handle: Handle(good.boundary.handle.value + 1)),
      boundary: good.boundary,
      boundaryPayload: good.boundaryPayload,
    );
    expect(() => doc.commands.execute(inverted), throwsStateError);
  });

  test('the fill names its boundary and the index links them', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    final slot = doc.entities.slotOf(cmd.fill.handle)!;
    final payload = doc.geometry.peek(doc.entities.geomIndexAt(slot));
    expect(payload.coords, isEmpty, reason: 'a fill stores no geometry');
    expect(boundaryHandleOf(payload), cmd.boundary.handle);
    expect(doc.fills.fillsOf(cmd.boundary.handle), [cmd.fill.handle]);
  });

  test('the triangulation is materialised by the command, not by a draw', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    expect(doc.fills.trianglesFor(cmd.boundary.handle), hasLength(6),
        reason: 'a square is two triangles; the frame path reads and never '
            'computes');
  });

  test('an unfillable boundary is refused before anything is written', () {
    final doc = DraftDocument.empty();
    final open = GeometryPayload(
        coords: Float64List.fromList([0, 0, 10, 0, 10, 10]), // not closed
        scalars: Float64List(0));
    expect(
        () => doc.commands.execute(AddRegionCommand.allocate(
              seed: doc.handleSeed,
              owner: doc.rootHandle,
              boundaryKind: EntityKind.polyline,
              boundaryPayload: open,
              layer: ReservedHandles.layerZero,
              fillColor: const TrueColor(0x3366CC),
              boundaryColor: const TrueColor(0x000000),
            )),
        throwsStateError);
    expect(doc.entities.liveSlots, isEmpty,
        reason: 'apply must either complete fully or leave the target '
            'unmutated');
  });

  test('undo removes both halves and redo restores the same handles', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    doc.commands.undo();
    expect(doc.entities.liveSlots, isEmpty);
    expect(doc.fills.entryCount, 0);
    expect(doc.fills.linkCount, 0);
    doc.commands.redo();
    expect(doc.entities.slotOf(cmd.fill.handle), isNotNull);
    expect(doc.entities.slotOf(cmd.boundary.handle), isNotNull);
    expect(doc.fills.trianglesFor(cmd.boundary.handle), hasLength(6));
  });
}
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/document/region_command_test.dart`
Expected: FAIL — `AddRegionCommand` is not defined.

- [ ] **Step 3: Implement**

Append to `commands.dart`:

```dart
/// Creates a boundary and the fill beneath it, as one mutation.
///
/// **The pair's handles are the whole point.** Draw order is ascending handle
/// value, and the natural authoring order -- draw the outline, then hatch it --
/// produces exactly the failing case. [allocate] takes the fill's handle first,
/// so it is strictly lower, and [apply] re-checks that rather than trusting it:
/// a hand-built command must not be able to invert the order silently.
///
/// **One `apply`, not two composed commands.** The fill is written first and at
/// that instant the boundary it names does not exist. Two `AddEntityCommand`s
/// would fire `invalidateDerived()` between them and let the index observe a
/// fill with a dangling reference.
class AddRegionCommand extends DraftCommand {
  AddRegionCommand({
    required this.fill,
    required this.boundary,
    required this.boundaryPayload,
  });

  final EntityRecord fill;
  final EntityRecord boundary;
  final GeometryPayload boundaryPayload;

  /// Allocates the pair, **fill first**.
  static AddRegionCommand allocate({
    required HandleSeed seed,
    required Handle owner,
    required EntityKind boundaryKind,
    required GeometryPayload boundaryPayload,
    required Handle layer,
    required DraftColor fillColor,
    required DraftColor boundaryColor,
    int fillTransparency = 0,
    int boundaryLineweight = kLineweightDefault,
  }) {
    final fillHandle = seed.next();
    final boundaryHandle = seed.next();
    return AddRegionCommand(
      fill: EntityRecord(
        handle: fillHandle,
        owner: owner,
        kind: EntityKind.fill,
        layer: layer,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: fillColor,
        lineweight: kLineweightDefault,
        transparency: fillTransparency,
        flags: 0,
      ),
      boundary: EntityRecord(
        handle: boundaryHandle,
        owner: owner,
        kind: boundaryKind,
        layer: layer,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: boundaryColor,
        lineweight: boundaryLineweight,
        transparency: 0,
        flags: 0,
      ),
      boundaryPayload: boundaryPayload,
    );
  }

  @override
  Capability get capability => Capability.geometry;

  @override
  String get label => 'Add region';

  @override
  CommandResult apply(CommandTarget target) {
    if (fill.handle.value >= boundary.handle.value) {
      throw StateError(
          'a region\'s fill must carry the lower handle: got fill '
          '${fill.handle.toHex()} against boundary ${boundary.handle.toHex()}');
    }
    if (fill.owner != boundary.owner) {
      throw StateError('a region\'s two halves must share one owner');
    }
    // Everything that can refuse, refuses before anything is written --
    // `apply` must either complete fully or leave the target unmutated.
    final triangles = triangulationFor(boundary.kind, boundaryPayload);
    if (triangles == null) {
      throw StateError('${boundary.handle.toHex()} is not a fillable boundary');
    }
    if (target.entities.containsHandle(fill.handle) ||
        target.entities.containsHandle(boundary.handle)) {
      throw DuplicateHandleError(fill.handle);
    }

    final fillGeom = target.geometry.add(GeometryPayload(
      coords: Float64List(0),
      scalars: Float64List.fromList([boundary.handle.value.toDouble()]),
    ));
    target.entities.add(fill.copyWith(geomIndex: fillGeom));
    final boundaryGeom = target.geometry.add(boundaryPayload);
    target.entities.add(boundary.copyWith(geomIndex: boundaryGeom));
    target.handleSeed.raiseTo(boundary.handle);

    target.fills.link(fill.handle, boundary.handle);
    if (triangles.isNotEmpty) {
      target.fills.putTriangles(boundary.handle, triangles);
    }
    target.invalidateDerived();

    return CommandResult(
      inverse: RemoveRegionCommand(
          fill: fill, boundary: boundary, boundaryPayload: boundaryPayload),
      touched: {fill.handle, boundary.handle},
    );
  }
}

/// The triangulation for a fillable boundary, or null when it is not one.
///
/// An **empty** result is different from null: null means "this is not a
/// boundary at all" and is refused at command time; empty means "a fillable
/// shape that could not be reduced", which the painter skips and counts.
/// A circle returns an empty list and is fanned per frame instead -- its
/// triangulation is scale-dependent and must never be cached.
Int32List? triangulationFor(EntityKind kind, GeometryPayload payload) {
  if (kind == EntityKind.circle) {
    return payload.scalars.isNotEmpty && payload.scalars[0] > 0
        ? Int32List(0)
        : null;
  }
  if (kind != EntityKind.polyline) return null;
  final count = payload.pointCount;
  // Closedness is a stored-value question, so the comparison is exact. This is
  // the same test `SpatialIndex` already applies before answering
  // `HitKind.fill` for a closed polyline's interior.
  if (count < 3) return null;
  if (payload.coords[0] != payload.coords[(count - 1) * 2] ||
      payload.coords[1] != payload.coords[(count - 1) * 2 + 1]) {
    return null;
  }
  return triangulateSimplePolygon(payload.coords, count);
}

/// Removes a region as one mutation. [AddRegionCommand]'s inverse.
///
/// Removal order is boundary first, then fill: the reverse of creation, so no
/// observer ever sees a live fill whose boundary has gone.
class RemoveRegionCommand extends DraftCommand {
  RemoveRegionCommand({
    required this.fill,
    required this.boundary,
    required this.boundaryPayload,
  });

  final EntityRecord fill;
  final EntityRecord boundary;
  final GeometryPayload boundaryPayload;

  @override
  Capability get capability => Capability.geometry;

  @override
  String get label => 'Remove region';

  @override
  CommandResult apply(CommandTarget target) {
    final boundarySlot = target.entities.slotOf(boundary.handle);
    final fillSlot = target.entities.slotOf(fill.handle);
    if (boundarySlot == null || fillSlot == null) {
      throw StateError('region ${boundary.handle.toHex()} is not intact');
    }
    target.geometry.remove(target.entities.geomIndexAt(boundarySlot));
    target.entities.remove(boundarySlot);
    target.geometry.remove(target.entities.geomIndexAt(fillSlot));
    target.entities.remove(fillSlot);
    target.fills.dropBoundary(boundary.handle);
    target.invalidateDerived();
    return CommandResult(
      inverse: AddRegionCommand(
          fill: fill, boundary: boundary, boundaryPayload: boundaryPayload),
      touched: {fill.handle, boundary.handle},
    );
  }
}
```

- [ ] **Step 4: Run and watch it pass**

Run: `cd packages/jet_cad_2d && dart test test/document/region_command_test.dart`
Expected: PASS, six tests.

- [ ] **Step 5: Run the named mutations**

```sh
cd packages/jet_cad_2d
F=lib/src/document/commands.dart
cp "$F" /tmp/t4.dart
trap 'cp /tmp/t4.dart "$F"' EXIT
run() { dart test test/document/region_command_test.dart >/dev/null 2>&1 && echo SURVIVED || echo KILLED; }

# T4a: allocate the boundary first, so the fill paints over its outline
perl -0pi -e 's/    final fillHandle = seed\.next\(\);\n    final boundaryHandle = seed\.next\(\);/    final boundaryHandle = seed.next();\n    final fillHandle = seed.next();/' "$F"; run; cp /tmp/t4.dart "$F"
# T4b: drop the ordering re-check, so a hand-built command inverts silently
perl -0pi -e 's/    if \(fill\.handle\.value >= boundary\.handle\.value\) \{/    if (false) {/' "$F"; run; cp /tmp/t4.dart "$F"
# T4c: triangulate lazily -- do not populate at command time
perl -0pi -e 's/      target\.fills\.putTriangles\(boundary\.handle, triangles\);//' "$F"; run; cp /tmp/t4.dart "$F"
# T4d: accept a nearly-closed loop
perl -0pi -e 's/  if \(payload\.coords\[0\] != payload\.coords\[\(count - 1\) \* 2\] \|\|\n      payload\.coords\[1\] != payload\.coords\[\(count - 1\) \* 2 \+ 1\]\) \{\n    return null;\n  \}//' "$F"; run; cp /tmp/t4.dart "$F"
```

All four must print `KILLED`. **T4d needs the open-boundary fixture**; if it
survives, no test is exercising an unclosed loop and the task is not done.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d/lib/src/document/commands.dart \
        packages/jet_cad_2d/test/document/region_command_test.dart
git commit -m "feat: AddRegionCommand reserves the pair's draw order"
```

---

## Task 5: `SetEntityGeometryCommand`

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/commands.dart`
- Modify: `packages/jet_cad_2d/test/document/region_command_test.dart`

**Interfaces:**
- Produces: `SetEntityGeometryCommand(Handle handle, GeometryPayload payload)`.

**Why it exists.** `GeometryStore.replace` has no production caller, because there is no geometry-edit command: editing points today means remove + add, which issues a **new handle**. A fill that names its boundary by handle loses its referent the instant that happens. Associativity is not an extra — it is unreachable without this command.

**Three things it must do beyond the write:**
1. **Refuse `EntityKind.fill`.** A fill's payload is a *reference*, not geometry. `SetEntityTextCommand` is the precedent for the refusal, right down to the message shape.
2. **Re-triangulate.** `replace` keeps the `geomIndex`, so the cache key does not change and a stale entry would never be noticed.
3. **Put every dependent fill in `touched`.** `SpatialIndex` re-derives boxes only for touched handles. A fill's box is *derived* from its boundary, so editing the boundary alone leaves the fill indexed against geometry that no longer exists — pick and cull both answer against the old outline.

- [ ] **Step 1: Write the failing tests**

Append to `region_command_test.dart`:

```dart
  test('editing a boundary re-triangulates and touches its fills', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    final before = doc.fills.trianglesFor(cmd.boundary.handle)!;

    // An L, not a translation: a moved square re-triangulates to the same
    // index list and cannot tell a working invalidation from a missing one.
    final result = doc.commands.execute(SetEntityGeometryCommand(
      cmd.boundary.handle,
      GeometryPayload(
          coords: Float64List.fromList(
              [0, 0, 20, 0, 20, 10, 10, 10, 10, 20, 0, 20, 0, 0]),
          scalars: Float64List(0)),
    ));
    final after = doc.fills.trianglesFor(cmd.boundary.handle)!;
    expect(after.length, 12, reason: 'six vertices reduce to four triangles');
    expect(after.length, isNot(before.length));
    expect(result.touched, contains(cmd.fill.handle),
        reason: 'the fill\'s indexed box is derived from this boundary; if the '
            'fill is not touched, SpatialIndex never re-derives it');
  });

  test('the handle and the geomIndex survive the edit', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    final slot = doc.entities.slotOf(cmd.boundary.handle)!;
    final geomBefore = doc.entities.geomIndexAt(slot);
    doc.commands.execute(SetEntityGeometryCommand(
        cmd.boundary.handle,
        GeometryPayload(
            coords: Float64List.fromList([0, 0, 5, 0, 5, 5, 0, 5, 0, 0]),
            scalars: Float64List(0))));
    expect(doc.entities.slotOf(cmd.boundary.handle), slot);
    expect(doc.entities.geomIndexAt(slot), geomBefore,
        reason: 'identity preserved is the whole reason this command exists');
  });

  test('it refuses a fill, because a fill\'s payload is a reference', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    expect(
        () => doc.commands.execute(SetEntityGeometryCommand(
            cmd.fill.handle,
            GeometryPayload(
                coords: Float64List(0),
                scalars: Float64List.fromList([999.0])))),
        throwsStateError);
  });

  test('undo restores the previous geometry and its triangulation', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    doc.commands.execute(SetEntityGeometryCommand(
        cmd.boundary.handle,
        GeometryPayload(
            coords: Float64List.fromList(
                [0, 0, 20, 0, 20, 10, 10, 10, 10, 20, 0, 20, 0, 0]),
            scalars: Float64List(0))));
    doc.commands.undo();
    expect(doc.fills.trianglesFor(cmd.boundary.handle), hasLength(6));
  });
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/document/region_command_test.dart`
Expected: FAIL — `SetEntityGeometryCommand` is not defined.

- [ ] **Step 3: Implement**

```dart
/// Replaces one entity's geometry, preserving its handle and its `geomIndex`.
///
/// The command `GeometryStore.replace` was waiting for. Without it, editing
/// points means remove + add, which issues a new handle -- and a fill that
/// names its boundary by handle loses its referent the moment that happens.
///
/// Rejects [EntityKind.fill]: a fill's payload is a *reference*, not geometry,
/// and letting this command rewrite it would repoint a fill at another
/// boundary with no validation, no cache move and no `touched` story.
/// Re-association is a different operation and is out of this plan's scope.
class SetEntityGeometryCommand extends DraftCommand {
  SetEntityGeometryCommand(this.handle, this.payload);

  final Handle handle;
  final GeometryPayload payload;

  @override
  Capability get capability => Capability.geometry;

  @override
  String get label => 'Edit geometry';

  @override
  CommandResult apply(CommandTarget target) {
    final slot = target.entities.slotOf(handle);
    if (slot == null) {
      throw StateError('no entity with handle ${handle.toHex()}');
    }
    final record = target.entities.read(slot);
    if (record.kind == EntityKind.fill) {
      throw StateError(
          '${handle.toHex()} is a fill: its payload names a boundary and is '
          'not geometry this command may rewrite');
    }
    // `read`, not `peek`: the inverse keeps this payload, and `peek` returns
    // the store's own buffer, which a later edit would rewrite underneath the
    // undo stack.
    final previous = target.geometry.read(record.geomIndex);
    target.geometry.replace(record.geomIndex, payload);

    // The fill's box is derived from this boundary, and `SpatialIndex`
    // re-derives only what a command touches. Leaving the fills out here
    // leaves them indexed against geometry that no longer exists.
    final dependents = target.fills.fillsOf(handle);
    if (dependents.isNotEmpty) {
      final triangles = triangulationFor(record.kind, payload);
      // `replace` keeps the geomIndex, so the key does not change and a stale
      // entry would never be noticed. Replace it, or drop it when the edit
      // made the boundary unfillable -- the painter then counts a skip.
      if (triangles == null || triangles.isEmpty) {
        target.fills.dropTriangles(handle);
      } else {
        target.fills.putTriangles(handle, triangles);
      }
    }
    target.invalidateDerived();
    return CommandResult(
      inverse: SetEntityGeometryCommand(handle, previous),
      touched: {handle, ...dependents},
    );
  }
}
```

`FillIndex` gains one method, beside `dropBoundary`:

```dart
  /// Drops a boundary's triangulation but keeps the links naming it. Used when
  /// an edit makes a live boundary unfillable: the fills still exist and still
  /// point here; they simply have nothing to draw, which the painter counts.
  void dropTriangles(Handle boundary) {
    _triangles.remove(boundary);
  }
```

- [ ] **Step 4: Run and watch it pass**

Run: `cd packages/jet_cad_2d && dart test test/document/region_command_test.dart`
Expected: PASS, ten tests.

- [ ] **Step 5: Run the named mutations**

```sh
cd packages/jet_cad_2d
F=lib/src/document/commands.dart
cp "$F" /tmp/t5.dart
trap 'cp /tmp/t5.dart "$F"' EXIT
run() { dart test test/document/region_command_test.dart >/dev/null 2>&1 && echo SURVIVED || echo KILLED; }

# T5a: drop the dependent fills from `touched`
perl -0pi -e 's/      touched: \{handle, \.\.\.dependents\},/      touched: {handle},/' "$F"; run; cp /tmp/t5.dart "$F"
# T5b: do not re-triangulate after the edit
perl -0pi -e 's/        target\.fills\.putTriangles\(handle, triangles\);//' "$F"; run; cp /tmp/t5.dart "$F"
# T5c: accept a fill
perl -0pi -e 's/    if \(record\.kind == EntityKind\.fill\) \{/    if (false) {/' "$F"; run; cp /tmp/t5.dart "$F"
# T5d: keep the inverse's payload by `peek`, sharing the store's buffer
perl -0pi -e 's/    final previous = target\.geometry\.read\(record\.geomIndex\);/    final previous = target.geometry.peek(record.geomIndex);/' "$F"; run; cp /tmp/t5.dart "$F"
```

T5a–T5c must print `KILLED`. **T5d may survive** — if it does, add a test that
edits the same boundary twice and then undoes twice, which is the only shape
that catches a shared buffer. Do not leave it unaccounted for either way.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d/lib/src/document/commands.dart \
        packages/jet_cad_2d/lib/src/document/fill_index.dart \
        packages/jet_cad_2d/test/document/region_command_test.dart
git commit -m "feat: SetEntityGeometryCommand, and the touched set fills depend on"
```

---

## Task 6: `RemoveEntityCommand` cascades to fills

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/commands.dart` (`RemoveEntityCommand`)
- Modify: `packages/jet_cad_2d/test/document/region_command_test.dart`

**Interfaces:**
- Consumes: `FillIndex.fillsOf`, `FillIndex.dropBoundary`, `FillIndex.unlink`.
- Produces: `RemoveEntityCommand` unchanged in signature; its inverse is now `AddRegionCommand` when it removed a pair.

**The rule:** removing a boundary removes its fills, in the same transaction, restored together by the inverse. An orphaned fill that draws nothing and reports nothing is the failure mode this codebase names as the worst kind — it looks like it works.

Removing a **fill** alone is allowed and unlinks it; the boundary's triangulation stays, because the boundary is still live and another fill may name it.

- [ ] **Step 1: Write the failing tests**

```dart
  test('removing a boundary removes its fill, and undo restores both', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    doc.commands.execute(RemoveEntityCommand(cmd.boundary.handle));
    expect(doc.entities.slotOf(cmd.fill.handle), isNull,
        reason: 'an orphaned fill draws nothing and reports nothing');
    expect(doc.fills.entryCount, 0);
    expect(doc.fills.linkCount, 0);
    doc.commands.undo();
    expect(doc.entities.slotOf(cmd.fill.handle), isNotNull);
    expect(doc.entities.slotOf(cmd.boundary.handle), isNotNull);
    expect(doc.fills.trianglesFor(cmd.boundary.handle), hasLength(6));
  });

  test('removing a fill alone unlinks it and leaves the boundary drawable', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    doc.commands.execute(RemoveEntityCommand(cmd.fill.handle));
    expect(doc.entities.slotOf(cmd.boundary.handle), isNotNull);
    expect(doc.fills.fillsOf(cmd.boundary.handle), isEmpty);
  });
```

- [ ] **Step 2: Run and watch it fail**

Expected: FAIL — the fill survives its boundary.

- [ ] **Step 3: Implement**

Replace `RemoveEntityCommand.apply`:

```dart
  @override
  CommandResult apply(CommandTarget target) {
    final slot = target.entities.slotOf(handle);
    if (slot == null) {
      throw StateError('no entity with handle ${handle.toHex()}');
    }
    final record = target.entities.read(slot);
    final payload = target.geometry.read(record.geomIndex);

    if (record.kind == EntityKind.fill) {
      target.entities.remove(slot);
      target.geometry.remove(record.geomIndex);
      target.fills.unlink(handle);
      target.invalidateDerived();
      return CommandResult(
        inverse: AddEntityCommand(record: record, payload: payload),
        touched: {handle},
      );
    }

    // Removing a boundary removes the fills that name it, in this same
    // mutation. The alternative is an orphaned fill: it draws nothing, reports
    // nothing, and looks like it works.
    final dependents = target.fills.fillsOf(handle);
    if (dependents.length == 1) {
      final fillSlot = target.entities.slotOf(dependents.single)!;
      final fillRecord = target.entities.read(fillSlot);
      target.entities.remove(fillSlot);
      target.geometry.remove(fillRecord.geomIndex);
      target.entities.remove(slot);
      target.geometry.remove(record.geomIndex);
      target.fills.dropBoundary(handle);
      target.invalidateDerived();
      return CommandResult(
        inverse: AddRegionCommand(
            fill: fillRecord, boundary: record, boundaryPayload: payload),
        touched: {handle, fillRecord.handle},
      );
    }
    if (dependents.isNotEmpty) {
      // More than one fill on one boundary is not something this plan's
      // commands can create, and inventing an n-ary inverse for it here would
      // be untested machinery. Refuse rather than half-handle it.
      throw StateError(
          '${handle.toHex()} carries ${dependents.length} fills; remove them '
          'before removing the boundary');
    }

    target.entities.remove(slot);
    target.geometry.remove(record.geomIndex);
    target.fills.dropBoundary(handle);
    target.invalidateDerived();
    return CommandResult(
      inverse: AddEntityCommand(record: record, payload: payload),
      touched: {handle},
    );
  }
```

- [ ] **Step 4: Run and watch it pass**

Run: `cd packages/jet_cad_2d && dart test` — the whole engine suite, because
this changes a command every other test uses.

- [ ] **Step 5: Run the named mutations**

```sh
cd packages/jet_cad_2d
F=lib/src/document/commands.dart
cp "$F" /tmp/t6.dart
trap 'cp /tmp/t6.dart "$F"' EXIT
run() { dart test test/document/region_command_test.dart >/dev/null 2>&1 && echo SURVIVED || echo KILLED; }

# T6a: do not cascade -- leave the fill orphaned
perl -0pi -e 's/    if \(dependents\.length == 1\) \{/    if (false) {/' "$F"; run; cp /tmp/t6.dart "$F"
# T6b: cascade but forget the index
perl -0pi -e 's/      target\.fills\.dropBoundary\(handle\);\n      target\.invalidateDerived\(\);\n      return CommandResult\(\n        inverse: AddRegionCommand\(/      target.invalidateDerived();\n      return CommandResult(\n        inverse: AddRegionCommand(/' "$F"; run; cp /tmp/t6.dart "$F"
# T6c: removing a fill forgets to unlink it
perl -0pi -e 's/      target\.fills\.unlink\(handle\);//' "$F"; run; cp /tmp/t6.dart "$F"
```

All three must print `KILLED`.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d/lib/src/document/commands.dart \
        packages/jet_cad_2d/test/document/region_command_test.dart
git commit -m "feat: removing a boundary removes its fill, in one mutation"
```

---

## Task 7: Codec — schema 5, and the load-time rebuild

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/codec/schema_version.dart:10`
- Modify: `packages/jet_cad_2d/lib/src/codec/json_codec.dart`
- Modify: `packages/jet_cad_2d/test/codec/json_codec_test.dart`

**Interfaces:**
- Produces: `kSchemaVersion = 5`. `JsonCodec.load` leaves `doc.fills` fully populated — every link, every triangulation.

**Why the bump.** `json_codec.dart:103` rejects `version > kSchemaVersion`, so a v4 build must refuse a document containing `kind: "fill"` rather than choke inside `EntityKind.values.byName`. Nothing about the *shape* of the JSON changes — a fill is an entity and the existing entity serialisation already carries it.

**Why the rebuild is here.** `FillIndex` is derived state with one source of truth, and the frame path must never compute. A loaded document's fills are triangulated before its first frame.

- [ ] **Step 1: Write the failing tests**

```dart
  test('a document with a region round-trips byte-identically', () {
    final doc = DraftDocument.empty();
    final cmd = AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.polyline,
      boundaryPayload: GeometryPayload(
          coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
          scalars: Float64List(0)),
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x3366CC),
      boundaryColor: const TrueColor(0x000000),
    );
    doc.commands.execute(cmd);
    final first = jsonEncode(JsonCodec.save(doc));
    final reloaded = JsonCodec.load(jsonDecode(first) as Map<String, Object?>);
    expect(jsonEncode(JsonCodec.save(reloaded)), first);
  });

  test('load leaves the fill index populated, not empty', () {
    // The frame path reads and never computes. A load that left this empty
    // would ear-clip on the first paint of every visible fill.
    final doc = DraftDocument.empty();
    final cmd = AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.polyline,
      boundaryPayload: GeometryPayload(
          coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
          scalars: Float64List(0)),
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x3366CC),
      boundaryColor: const TrueColor(0x000000),
    );
    doc.commands.execute(cmd);
    final reloaded =
        JsonCodec.load(jsonDecode(jsonEncode(JsonCodec.save(doc))) as Map<String, Object?>);
    expect(reloaded.fills.fillsOf(cmd.boundary.handle), [cmd.fill.handle]);
    expect(reloaded.fills.trianglesFor(cmd.boundary.handle), hasLength(6));
  });

  test('the schema version is 5, and a v6 document is refused', () {
    expect(kSchemaVersion, 5);
    expect(() => JsonCodec.load({'schemaVersion': 6}), throwsA(anything));
  });
```

- [ ] **Step 2: Run and watch it fail**

Expected: FAIL — `kSchemaVersion` is 4, and `reloaded.fills` is empty.

- [ ] **Step 3: Implement**

`schema_version.dart`:

```dart
/// 5: `EntityKind.fill`. The JSON shape is unchanged -- a fill is an ordinary
/// entity and `kind` is written by name -- but a v4 reader must refuse a
/// document containing one rather than fail inside `EntityKind.values.byName`,
/// and the version check at `json_codec.dart:103` is what makes it.
const int kSchemaVersion = 5;
```

In `json_codec.dart`, after entities are loaded and before `doc.invalidateDerived()`:

```dart
    _rebuildFills(doc, diagnostics);
```

```dart
/// Rebuilds the fill index from the loaded entities.
///
/// Derived state with one source of truth: the document stores a fill's
/// boundary handle and nothing else, and everything else about a fill --
/// its link and its boundary's triangulation -- is computed here, once,
/// before the first frame.
///
/// A fill whose boundary is missing or unfillable is **linked anyway and left
/// without triangles**. Dropping the link would silently discard the user's
/// data; `validate()` reports the condition and the painter counts the skip.
void _rebuildFills(DraftDocument doc, List<Diagnostic>? diagnostics) {
  doc.fills.clear();
  for (final slot in doc.entities.liveSlots) {
    if (doc.entities.kindAt(slot) != EntityKind.fill) continue;
    final fill = doc.entities.handleAt(slot);
    final boundary =
        boundaryHandleOf(doc.geometry.peek(doc.entities.geomIndexAt(slot)));
    doc.fills.link(fill, boundary);
    final boundarySlot = doc.entities.slotOf(boundary);
    if (boundarySlot == null) continue;
    if (doc.fills.trianglesFor(boundary) != null) continue;
    final triangles = triangulationFor(
        doc.entities.kindAt(boundarySlot),
        doc.geometry.peek(doc.entities.geomIndexAt(boundarySlot)));
    if (triangles != null && triangles.isNotEmpty) {
      doc.fills.putTriangles(boundary, triangles);
    }
  }
}
```

- [ ] **Step 4: Run and watch it pass**

Run: `cd packages/jet_cad_2d && dart test test/codec/json_codec_test.dart`

- [ ] **Step 5: Run the named mutations**

```sh
# T7a: do not rebuild on load -- the frame path would then compute
perl -0pi -e 's/    _rebuildFills\(doc, diagnostics\);//' lib/src/codec/json_codec.dart   # must KILL
# T7b: leave kSchemaVersion at 4
perl -0pi -e 's/const int kSchemaVersion = 5;/const int kSchemaVersion = 4;/' lib/src/codec/schema_version.dart  # must KILL
```

Use the `cp`/`trap` harness from Task 2 for both.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d/lib/src/codec packages/jet_cad_2d/test/codec
git commit -m "feat: schema 5, and the fill index rebuilt at load"
```

---

## Task 8: `validate()` learns five fill codes

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/validate.dart`
- Modify: `packages/jet_cad_2d/test/document/validate_test.dart`

**Interfaces:**
- Produces, on `ValidationCodes`:
```dart
  static const String fillBoundaryMissing = 'fill.boundary_missing';
  static const String fillBoundaryNotFillable = 'fill.boundary_not_fillable';
  static const String fillBoundaryNotClosed = 'fill.boundary_not_closed';
  static const String fillBoundaryForeignOwner = 'fill.boundary_foreign_owner';
  static const String fillDrawOrderInverted = 'fill.draw_order_inverted';
```

**`validate()` reports and never mutates.** In particular, a document carrying `fill.handle > boundary.handle` is **not** reordered, renumbered or refused. A loader that silently re-sorts to preserve "ascending handle is draw order" breaks that rule in the act of defending it: the drawing would then differ from the file. The document draws as written, and the diagnostic says it will look wrong.

- [ ] **Step 1: Write the failing tests**

One fixture document per code — a suite that only asserts "validate returns
something" cannot tell which check was deleted.

```dart
/// Builds a fill naming [boundary] directly, bypassing AddRegionCommand, which
/// is the only way to produce the malformed documents this test is about.
Handle rawFill(DraftDocument doc, Handle boundary,
    {Handle? owner, Handle? handle}) {
  final h = handle ?? doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: h,
      owner: owner ?? doc.rootHandle,
      kind: EntityKind.fill,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x3366CC),
      lineweight: kLineweightDefault,
      transparency: 0,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List(0),
        scalars: Float64List.fromList([boundary.value.toDouble()])),
  ));
  return h;
}

test('a fill naming nothing is reported', () {
  final doc = DraftDocument.empty();
  rawFill(doc, const Handle(9999));
  expect(doc.validate().map((d) => d.code),
      contains(ValidationCodes.fillBoundaryMissing));
});

/// Adds a leaf of [kind] with [coords] and returns its handle. `rawFill` and
/// these three tests are the only way to build the malformed documents
/// `validate()` is about -- `AddRegionCommand` refuses every one of them.
Handle rawLeaf(DraftDocument doc, EntityKind kind, List<double> coords,
    {Handle? owner, List<double> scalars = const [], String text = ''}) {
  final h = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: h,
      owner: owner ?? doc.rootHandle,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x000000),
      lineweight: 30,
      transparency: 0,
      flags: 0,
      text: text,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars)),
  ));
  return h;
}

test('a fill on a text entity is reported as not fillable', () {
  final doc = DraftDocument.empty();
  final textHandle =
      rawLeaf(doc, EntityKind.text, [0, 0], scalars: [2.5], text: 'ROOM 3');
  rawFill(doc, textHandle);
  expect(doc.validate().map((d) => d.code),
      contains(ValidationCodes.fillBoundaryNotFillable));
});

test('a fill on an open polyline is reported as not closed', () {
  final doc = DraftDocument.empty();
  final open = rawLeaf(doc, EntityKind.polyline, [0, 0, 10, 0, 10, 10]);
  rawFill(doc, open);
  expect(doc.validate().map((d) => d.code),
      contains(ValidationCodes.fillBoundaryNotClosed));
});

test('a fill in a different owner than its boundary is reported', () {
  final doc = DraftDocument.empty();
  final group = doc.handleSeed.next();
  doc.commands.execute(AddNodeCommand(
      GroupNode(handle: group, parent: doc.rootHandle)));
  final boundary = rawLeaf(
      doc, EntityKind.polyline, [0, 0, 10, 0, 10, 10, 0, 10, 0, 0],
      owner: group);
  rawFill(doc, boundary);   // owner defaults to the root
  expect(doc.validate().map((d) => d.code),
      contains(ValidationCodes.fillBoundaryForeignOwner));
});

test('an inverted pair is reported and nothing is changed', () {
  final doc = DraftDocument.empty();
  final boundary = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: boundary,
      owner: doc.rootHandle,
      kind: EntityKind.polyline,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x000000),
      lineweight: 30,
      transparency: 0,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
        scalars: Float64List(0)),
  ));
  final fill = rawFill(doc, boundary); // allocated after, so higher
  expect(fill.value, greaterThan(boundary.value));
  final before = jsonEncode(JsonCodec.save(doc));
  expect(doc.validate().map((d) => d.code),
      contains(ValidationCodes.fillDrawOrderInverted));
  expect(jsonEncode(JsonCodec.save(doc)), before,
      reason: 'validate reports and never mutates; a loader that re-sorted to '
          'defend the draw-order rule would make the drawing differ from the '
          'file');
});
```

- [ ] **Step 2: Run and watch each fail**

Expected: FAIL — the codes are not defined.

- [ ] **Step 3: Implement**

Add a sixth numbered block to `DocumentValidation.validate()`:

```dart
    // 6. Fills. Every check reports; none repairs.
    for (final slot in entities.liveSlots) {
      if (entities.kindAt(slot) != EntityKind.fill) continue;
      final fill = entities.handleAt(slot);
      final boundary =
          boundaryHandleOf(geometry.peek(entities.geomIndexAt(slot)));
      final boundarySlot = entities.slotOf(boundary);
      if (boundarySlot == null) {
        out.add(error(ValidationCodes.fillBoundaryMissing,
            'fill ${fill.toHex()} names ${boundary.toHex()}, which is not in '
            'this document', [fill, boundary]));
        continue;
      }
      final kind = entities.kindAt(boundarySlot);
      if (kind != EntityKind.polyline && kind != EntityKind.circle) {
        out.add(error(ValidationCodes.fillBoundaryNotFillable,
            'fill ${fill.toHex()} names a ${kind.name}, which has no interior',
            [fill, boundary]));
      } else if (kind == EntityKind.polyline &&
          triangulationFor(kind, geometry.peek(entities.geomIndexAt(boundarySlot))) ==
              null) {
        out.add(error(ValidationCodes.fillBoundaryNotClosed,
            'fill ${fill.toHex()} names an open polyline; closedness is the '
            'stored first point repeated as the last, compared exactly',
            [fill, boundary]));
      }
      if (entities.ownerAt(slot) != entities.ownerAt(boundarySlot)) {
        out.add(error(ValidationCodes.fillBoundaryForeignOwner,
            'fill ${fill.toHex()} and its boundary are in different owners, so '
            'the reference cannot resolve under an instance', [fill, boundary]));
      }
      if (fill.value > boundary.value) {
        out.add(error(ValidationCodes.fillDrawOrderInverted,
            'fill ${fill.toHex()} has a higher handle than its boundary '
            '${boundary.toHex()}, so it draws over its own outline',
            [fill, boundary]));
      }
    }
```

- [ ] **Step 4: Run and watch them pass**

- [ ] **Step 5: Run the named mutation**

Delete each of the five `out.add(...)` blocks in turn. Each deletion must fail
**its own** test and no other — that is what one fixture per code buys.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d/lib/src/document/validate.dart \
        packages/jet_cad_2d/test/document/validate_test.dart
git commit -m "feat: validate() reports five fill conditions and repairs none"
```

---

## Task 9: `entityBounds` and every one of its call sites

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/extents.dart`
- Modify: `packages/jet_cad_2d/lib/src/index/spatial_index.dart` (`_reconcileEntity`, and the rebuild path)
- Modify: `packages/jet_cad_2d/lib/src/index/container_index.dart`
- Modify: `packages/jet_cad_2d/lib/src/document/draft_document.dart` (`extents`)
- Modify: `packages/jet_cad_2d/test/document/extents_test.dart`

**Interfaces:**
- Produces:
```dart
Aabb2 entityBounds({
  required EntityKind kind,
  required GeometryPayload payload,
  required TextMeasurer measurer,
  required TextStyleRecord textStyle,
  int textAttrs = 0,
  String text = '',
  EntityKind? boundaryKind,          // fill only
  GeometryPayload? boundaryPayload,  // fill only
});
```

**`entityBounds` does not resolve the handle, and the file says why in writing.** Its doc comment, about the text style it takes as a record rather than a handle:

> giving this function a document dependency so it could look one up would be worse: every caller already holds the document and can resolve the record once.

A boundary handle is the same lookup and gets the same answer. The **caller** resolves. Both new parameters are null for every kind but `fill`; a fill with neither resolved bounds to `Aabb2.empty()` and is counted by the painter, never guessed at.

**Find every call site first.** `grep -rn "entityBounds(" packages/jet_cad_2d/lib packages/jet_cad_2d/test packages/jet_cad_2d_flutter`. **One task owns the function and all of them** — update the function, miss a call site, and the index carries a wrong box silently. Each call site must state **`peek` or `read`** for the boundary payload: the index's hot paths use `peek` (three fewer allocations per candidate); commands, which keep what they read, use `read`.

- [ ] **Step 1: Write the failing test**

```dart
test('a fill bounds to its boundary, not to nothing', () {
  final square = GeometryPayload(
      coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
      scalars: Float64List(0));
  final fill = GeometryPayload(
      coords: Float64List(0), scalars: Float64List.fromList([40.0]));
  final box = entityBounds(
    kind: EntityKind.fill,
    payload: fill,
    measurer: const InsertionPointMeasurer(),
    textStyle: const TextStyleRecord(),
    boundaryKind: EntityKind.polyline,
    boundaryPayload: square,
  );
  expect(box.min.x, 0.0);
  expect(box.max.x, 10.0);
  expect(box.max.y, 10.0);
});

test('a fill with no boundary resolved bounds to empty, not to a guess', () {
  final box = entityBounds(
    kind: EntityKind.fill,
    payload: GeometryPayload(
        coords: Float64List(0), scalars: Float64List.fromList([40.0])),
    measurer: const InsertionPointMeasurer(),
    textStyle: const TextStyleRecord(),
  );
  expect(box.isEmpty, isTrue);
});

test('a fill on a circle boundary bounds to the circle', () {
  final circle = GeometryPayload(
      coords: Float64List.fromList([5, 5]),
      scalars: Float64List.fromList([3]));
  final box = entityBounds(
    kind: EntityKind.fill,
    payload: GeometryPayload(
        coords: Float64List(0), scalars: Float64List.fromList([40.0])),
    measurer: const InsertionPointMeasurer(),
    textStyle: const TextStyleRecord(),
    boundaryKind: EntityKind.circle,
    boundaryPayload: circle,
  );
  expect(box.min.x, 2.0);
  expect(box.max.y, 8.0);
});
```

And the one that catches a missed call site — through the **index**, not the
function:

```dart
test('an edited boundary moves its fill\'s indexed box', () {
  final doc = DraftDocument.empty();
  final cmd = region(doc);           // square at 0,0..10,10
  doc.commands.execute(cmd);
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);

  doc.commands.execute(SetEntityGeometryCommand(
      cmd.boundary.handle,
      GeometryPayload(
          coords: Float64List.fromList(
              [100, 100, 110, 100, 110, 110, 100, 110, 100, 100]),
          scalars: Float64List(0))));

  final slot = doc.entities.slotOf(cmd.fill.handle)!;
  final box = index.boxOfLeaf(slot) ?? index.dirty.boxOf(slot);
  expect(box!.min.x, 100.0,
      reason: 'the fill is derived from the boundary; if the reconcile misses '
          'it, the fill is culled and picked against an outline that moved');
});
```

- [ ] **Step 2: Run and watch it fail**

Expected: FAIL — `boundaryKind` is not a named parameter, and the index test
reports the old box.

- [ ] **Step 3: Implement**

In `extents.dart`, extend the doc comment and the signature, and replace Task 1's
inert case:

```dart
/// [boundaryKind] and [boundaryPayload] are the resolved boundary of an
/// [EntityKind.fill], and null for every other kind. They are *resolved by the
/// caller*, for the same reason [textStyle] is: giving this function a document
/// dependency so it could look a handle up would be worse, and every caller
/// already holds the document.
      case EntityKind.fill:
        // A fill has no geometry of its own -- it occupies exactly its
        // boundary. Unresolved, it bounds to nothing rather than to a guess;
        // the painter counts that as a skip and `validate()` names the cause.
        if (boundaryKind == null || boundaryPayload == null) {
          return Aabb2.empty();
        }
        return entityBounds(
          kind: boundaryKind,
          payload: boundaryPayload,
          measurer: measurer,
          textStyle: textStyle,
        );
```

At every call site, resolve first. The index's hot path:

```dart
    // `peek`, not `read`: this runs per candidate and `read` copies three
    // objects. Nothing here keeps the payload past the call.
    EntityKind? boundaryKind;
    GeometryPayload? boundaryPayload;
    if (record.kind == EntityKind.fill) {
      final b = document.entities
          .slotOf(boundaryHandleOf(document.geometry.peek(record.geomIndex)));
      if (b != null) {
        boundaryKind = document.entities.kindAt(b);
        boundaryPayload = document.geometry.peek(document.entities.geomIndexAt(b));
      }
    }
```

- [ ] **Step 4: Run the whole engine suite**

Run: `cd packages/jet_cad_2d && dart test`

- [ ] **Step 5: Run the named mutations**

```sh
# T9a: return Aabb2.empty() for a fill even when the boundary resolves
# T9b: skip the fill resolution at ONE call site (do each in turn)
# T9c: use `read` in the index's hot path (survives correctness, caught by
#      test/invariants/query_allocation_test.dart -- run that too)
```

T9b is the point of the task: with the resolution removed at the index call
site only, the unit tests stay green and **the indexed-box test goes red**. If
both stay green, the fixture is not going through the index and the task is not
done.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d/lib/src/document/extents.dart \
        packages/jet_cad_2d/lib/src/index packages/jet_cad_2d/test
git commit -m "feat: a fill bounds to its boundary, resolved by the caller"
```

---

## Task 10: The index stays silent about fills

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/index/spatial_index.dart`
- Modify: `packages/jet_cad_2d/test/invariants/reference_query.dart`
- Modify: `packages/jet_cad_2d/test/index/pick_test.dart`, `snap_test.dart`

**Interfaces:**
- Produces: no new API. A fill contributes **no pick candidate and no snap candidate**, in both the real index and the oracle.

**This task deletes a requirement rather than adding a picker**, and that is the finding to carry: the spec's earlier claim that "a fill answers `HitKind.fill` on its own handle" was withdrawn under review because two independent facts make it unimplementable *and* undesirable.

1. `_considerLeaf` returns before any kind dispatch when `pointCount == 0`. A fill has no coordinates.
2. Even if it did not, it would always lose. Pick priority is kind, then ancestor, then **greater handle wins** — and a fill's handle is strictly lower than its boundary's by construction, while a closed polyline already answers `HitKind.fill` on its own interior.

So clicking inside a filled room selects the **boundary**, with `HitKind.fill`, exactly as it does today for an unfilled closed polyline. The region tool maps either half of the pair to the pair. That is the architecture spec's "the user never sees two entities" working as designed.

Two existing behaviours are **verified and left alone**, with the reasoning written down so a later reader does not "fix" them: `snapCentreOfLeaf` returns null for a fill and `NarrowPhaseSlack.ofLeaf` returns `none`, both through `if (kind != circle && kind != arc)` guards rather than a switch with a default. Both answers are right — a fill contributes no snap candidate because its boundary already contributes every vertex, and its box contains a narrow phase it does not have.

- [ ] **Step 1: Write the failing tests**

```dart
test('clicking inside a filled room selects the boundary, not the fill', () {
  final doc = DraftDocument.empty();
  final cmd = region(doc);           // square at 0,0..10,10
  doc.commands.execute(cmd);
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final hit = HitPath();
  expect(index.pickInto(Vector2(5, 5), 0.5, hit), isTrue);
  expect(hit.entity, cmd.boundary.handle,
      reason: 'the fill carries the lower handle by construction and would '
          'lose the tie-break anyway; the region tool maps the boundary to '
          'the pair');
  expect(hit.kind, HitKind.fill);
});

test('a fill never wins a snap, so boundary vertices are not doubled', () {
  final doc = DraftDocument.empty();
  final withFill = region(doc);
  doc.commands.execute(withFill);
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final out = SnapResult();
  expect(index.snapInto(Vector2(0, 0), 1.0, const SnapMask.all(), out), isTrue);
  expect(out.entity, isNot(withFill.fill.handle),
      reason: 'the boundary already contributes every vertex; a second '
          'candidate on the same point would corrupt the snap tie-break');
});

test('the reference oracle agrees about a document containing fills', () {
  // `test/invariants/differential_test.dart` compares `pickInto` against
  // `referencePick` and `snapInto` against `referenceSnap`, both from
  // `reference_query.dart`. This adds a region to that file's corpus rather
  // than writing a second differential: the oracle must fail for a real
  // disagreement, never for a missing case in its own switch.
  //
  // In `test/invariants/corpus.dart`, add one region to the generated
  // document behind the same shape of flag the corpus already uses for text,
  // and run:
  //   dart test test/invariants/differential_test.dart
});
```

- [ ] **Step 2: Run and watch them fail**

Expected: the oracle test fails first — its `fill` case from Task 1 is a bare
`break` with no comment tying it to this decision.

- [ ] **Step 3: Implement**

Replace Task 1's placeholder comments with the final reasoning at each of the
four sites, and add the two comment blocks to `container_index.dart` above
`snapCentreOfLeaf` and `NarrowPhaseSlack.ofLeaf`:

```dart
// A fill reaches neither of these. Its `pointCount` is zero, so
// `_considerLeaf` and `_considerSnapLeaf` return before any kind dispatch,
// and that is the intended behaviour rather than an oversight: a fill is
// drawn, not picked. Its boundary already answers `HitKind.fill` on the same
// interior and already contributes every snap vertex. If a later change gives
// a fill coordinates of its own, these two guards start answering for it --
// and `none`/`null` remain the right answers for the same reasons.
```

- [ ] **Step 4: Run and watch them pass**

- [ ] **Step 5: Run the named mutations**

```sh
# T10a: give the oracle a fill hit that the index does not produce
#       -> the differential must go red
# T10b: make snapCentreOfLeaf answer for a fill
#       -> the doubled-vertex test must go red
```

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat: a fill is drawn, not picked, in the index and the oracle"
```

---

## Task 11: `DrawSink` grows two fill operations

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/test/draw_sink_test.dart`

**Interfaces:**
- Produces:
```dart
void fillPolygon(Float64List points, int count, Int32List triangles,
    ResolvedStyle style);
void fillCircle(double cx, double cy, double r, ResolvedStyle style);

final class FillPolygonOp extends DrawOp { ... }   // == by value, triangles included
final class FillCircleOp extends DrawOp { ... }
```

`CanvasDrawSink` draws the polygon as a closed `Path` with `PaintingStyle.fill` and **ignores `triangles`** — `Canvas` resolves concavity itself — and the circle with `drawCircle`. Both sinks receive the same ops with the same arguments, so `RecordingDrawSink` equality and the differential oracle keep working.

- [ ] **Step 1: Write the failing tests**

```dart
test('two recordings of the same fill compare equal', () {
  final a = RecordingDrawSink()..fillPolygon(square, 5, tri, style);
  final b = RecordingDrawSink()..fillPolygon(square, 5, tri, style);
  expect(a.ops, b.ops);
});

test('a different triangulation of the same outline is a different op', () {
  // The op carries the triangles, so a painter that hands one sink a stale
  // triangulation and the other a fresh one is a disagreement the oracle sees.
  final a = RecordingDrawSink()
    ..fillPolygon(square, 5, Int32List.fromList([0, 1, 2, 0, 2, 3]), style);
  final b = RecordingDrawSink()
    ..fillPolygon(square, 5, Int32List.fromList([0, 1, 3, 1, 2, 3]), style);
  expect(a.ops, isNot(b.ops));
});

testWidgets('the canvas sink fills the path and does not stroke it',
    (tester) async {
  final spy = SpyCanvas();
  CanvasDrawSink(canvas: spy, pixelsPerPaperMm: kLogicalPixelsPerMm)
    ..beginResidual(Transform2.identity)
    ..fillPolygon(square, 5, tri, style)
    ..endResidual();
  expect(spy.lastPaintStyle, PaintingStyle.fill);
  expect(spy.drawPathCount, 1,
      reason: 'one path, not two triangles: Canvas resolves concavity itself '
          'and the triangles argument is for the vertices backend');
});

testWidgets('the canvas sink leaves its paint on stroke afterwards',
    (tester) async {
  // The sink reuses one Paint. A fill that leaves `style` on fill turns every
  // later stroke in the frame into a fill -- the shape of bug the point op
  // already guards against by restoring PaintingStyle.stroke.
  final spy = SpyCanvas();
  final sink = CanvasDrawSink(canvas: spy, pixelsPerPaperMm: kLogicalPixelsPerMm)
    ..beginResidual(Transform2.identity)
    ..fillPolygon(square, 5, tri, style)
    ..polyline(square, 5, style, closed: false)
    ..endResidual();
  expect(spy.lastPaintStyle, PaintingStyle.stroke);
  expect(sink.canvasCallCount, 2);
});
```

- [ ] **Step 2: Run and watch them fail**

- [ ] **Step 3: Implement**

On `DrawSink`:

```dart
  /// Fills a closed loop.
  ///
  /// [points] is the boundary's loop in this residual's local space, [count]
  /// its point count including the duplicated closing point. [triangles] is
  /// the loop's triangulation as triple-indices into [points]' point
  /// numbering -- computed once, off the frame path, and passed through
  /// because a sink must not reach into the document to get it.
  ///
  /// A sink that fills paths natively ignores [triangles]; a sink that batches
  /// geometry needs them. Both receive the same call, which is what keeps
  /// [RecordingDrawSink] equality meaningful.
  ///
  /// The painter never calls this with an empty [triangles]: an unfillable
  /// boundary is skipped and counted before it reaches a sink. See
  /// `DraftPainter.skippedFillCount`.
  void fillPolygon(Float64List points, int count, Int32List triangles,
      ResolvedStyle style);

  /// Fills a circle. Never triangulated ahead of time: a circle's
  /// tessellation is scale-dependent, so a batching sink fans it per frame at
  /// the step count its own stroke would use.
  void fillCircle(double cx, double cy, double r, ResolvedStyle style);
```

On `CanvasDrawSink`:

```dart
  @override
  void fillPolygon(Float64List points, int count, Int32List triangles,
      ResolvedStyle style) {
    if (count < 3) return;
    _pushTransform();
    _scratch.reset();
    _scratch.moveTo(points[0], points[1]);
    for (var i = 1; i < count; i++) {
      _scratch.lineTo(points[i * 2], points[i * 2 + 1]);
    }
    _scratch.close();
    _paint
      ..color = Color(style.argb)
      ..style = PaintingStyle.fill;
    canvas.drawPath(_scratch, _paint);
    // Restored for the same reason `point` restores it: one Paint is reused
    // for the whole frame, and a stroke drawn after this must not be filled.
    _paint.style = PaintingStyle.stroke;
    _popTransform();
    _canvasCalls++;
  }

  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) {
    _pushTransform();
    _paint
      ..color = Color(style.argb)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, _paint);
    _paint.style = PaintingStyle.stroke;
    _popTransform();
    _canvasCalls++;
  }
```

Plus `FillPolygonOp` and `FillCircleOp` on `RecordingDrawSink`, with `==`
comparing `points`, `triangles`, and `style` by value.

- [ ] **Step 4: Run and watch them pass**

- [ ] **Step 5: Run the named mutations**

```sh
# T11a: leave _paint.style on fill after the call    -> the stroke test reds
# T11b: drop `triangles` from FillPolygonOp's ==     -> the two-triangulations test reds
# T11c: draw the polygon unclosed (_scratch.close() removed)
```

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/draw_sink.dart \
        packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart \
        packages/jet_cad_2d_flutter/test/draw_sink_test.dart
git commit -m "feat: DrawSink.fillPolygon and fillCircle"
```

---

## Task 12: `VerticesDrawSink` fills

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart`

**Interfaces:**
- Consumes: `fillPolygon` / `fillCircle` (Task 11).
- Produces: `frameTriangleCount` now includes fill triangles.

**Two invariants, both of which have a named mutant:**

1. **`_coveredArgb` must never see a fill's style.** It fades alpha in proportion to device *stroke* width, mirroring `Geometry::ComputeStrokeAlphaCoverage`. A fill entity's `ResolvedStyle` still carries `lineweightHundredths`, because the column is per-entity and shared. Route a fill through it and a filled room on a hairline layer fades **on the vertices backend only**, where the ink floor then hides the disagreement. Fills use `style.argb` directly.
2. **The circle fan uses the stroke's step count, not a similar one** — the identical expression, `(theta * math.sqrt(deviceRadius / (8 * kFlattenTolerance))).ceil()` clamped to `kMaxFlattenSegments`. A different count makes a filled circle's silhouette and its own outline disagree, and the disagreement changes with zoom.

- [ ] **Step 1: Write the failing tests**

```dart
test('a polygon fill emits exactly the triangles it was handed', () {
  final sink = harness();
  sink
    ..beginResidual(Transform2.identity)
    ..fillPolygon(square, 5, Int32List.fromList([0, 1, 2, 0, 2, 3]), opaque)
    ..endResidual();
  expect(sink.frameTriangleCount, 2);
});

test('a hairline fill keeps full alpha', () {
  // _coveredArgb fades a sub-pixel STROKE. A fill has no width, so a fill on a
  // hairline layer must not fade -- and it would fade on this backend only,
  // where the comparison harness's ink floor would then hide it.
  final sink = harness();
  const hairline = ResolvedStyle(argb: 0xFF3366CC, lineweightHundredths: 1);
  late Int32List colors;
  sink.observer = (_, c) => colors = Int32List.fromList(c);
  sink
    ..beginResidual(Transform2.identity)
    ..fillPolygon(square, 5, Int32List.fromList([0, 1, 2, 0, 2, 3]), hairline)
    ..endResidual();
  sink.flush();
  expect(colors.first.toUnsigned(32), 0xFF3366CC);
});

test('a filled circle and its own outline use the same step count', () {
  final filled = harness()
    ..beginResidual(Transform2.identity)
    ..fillCircle(0, 0, 90, opaque)
    ..endResidual();
  final stroked = harness()
    ..beginResidual(Transform2.identity)
    ..circle(0, 0, 90, opaque)
    ..endResidual();
  // A closed stroked run is 4 triangles per chord (quad + join); a fan is 1.
  expect(filled.frameTriangleCount * 4, stroked.frameTriangleCount,
      reason: 'a different step count makes the fill\'s silhouette and its '
          'outline disagree, and the disagreement changes with zoom');
});
```

- [ ] **Step 2: Run and watch them fail**

- [ ] **Step 3: Implement**

```dart
  @override
  void fillPolygon(Float64List points, int count, Int32List triangles,
      ResolvedStyle style) {
    if (triangles.isEmpty) return;
    final t = _residual;
    // `style.argb` directly, NOT `_coveredArgb`: that function fades a stroke
    // thinner than a device pixel, and a fill has no width. A fill entity's
    // ResolvedStyle still carries a lineweight because the column is shared,
    // so routing it through would fade a filled room on a hairline layer on
    // this backend only.
    final argb = style.argb;
    for (var i = 0; i < triangles.length; i += 3) {
      final a = triangles[i], b = triangles[i + 1], c = triangles[i + 2];
      _emitTriangle(
        t.a * points[a * 2] + t.c * points[a * 2 + 1] + t.e,
        t.b * points[a * 2] + t.d * points[a * 2 + 1] + t.f,
        t.a * points[b * 2] + t.c * points[b * 2 + 1] + t.e,
        t.b * points[b * 2] + t.d * points[b * 2 + 1] + t.f,
        t.a * points[c * 2] + t.c * points[c * 2 + 1] + t.e,
        t.b * points[c * 2] + t.d * points[c * 2 + 1] + t.f,
        argb,
      );
    }
  }

  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) {
    if (r <= 0) return;
    final t = _residual;
    final deviceRadius = r * t.scaleMagnitude;
    if (deviceRadius <= 0) return;
    // The SAME expression `_flatten` uses, not a similar one. A fill whose
    // silhouette is tessellated differently from its own outline shows a
    // sliver between them that changes with zoom.
    const theta = 2 * math.pi;
    final steps = (theta * math.sqrt(deviceRadius / (8 * kFlattenTolerance)))
        .ceil()
        .clamp(1, kMaxFlattenSegments);
    final argb = style.argb;
    final ccx = t.a * cx + t.c * cy + t.e;
    final ccy = t.b * cx + t.d * cy + t.f;
    var px = cx + r, py = cy;
    var dx = t.a * px + t.c * py + t.e, dy = t.b * px + t.d * py + t.f;
    for (var i = 1; i <= steps; i++) {
      final angle = theta * i / steps;
      px = cx + r * math.cos(angle);
      py = cy + r * math.sin(angle);
      final nx = t.a * px + t.c * py + t.e, ny = t.b * px + t.d * py + t.f;
      _emitTriangle(ccx, ccy, dx, dy, nx, ny, argb);
      dx = nx;
      dy = ny;
    }
  }
```

- [ ] **Step 4: Run and watch them pass**

- [ ] **Step 5: Run the named mutations**

```sh
cd packages/jet_cad_2d_flutter
F=lib/src/vertices_draw_sink.dart
cp "$F" /tmp/t12.dart
trap 'cp /tmp/t12.dart "$F"' EXIT
run() { flutter test test/vertices_draw_sink_test.dart >/dev/null 2>&1 && echo SURVIVED || echo KILLED; }

# T12a: route the fill through _coveredArgb
perl -0pi -e 's/    final argb = style\.argb;\n    for \(var i = 0; i < triangles\.length/    final argb = _coveredArgb(style.argb, style.lineweightHundredths);\n    for (var i = 0; i < triangles.length/' "$F"; run; cp /tmp/t12.dart "$F"
# T12b: give the fan its own step count
perl -0pi -e 's/    final steps = \(theta \* math\.sqrt\(deviceRadius \/ \(8 \* kFlattenTolerance\)\)\)\n        \.ceil\(\)\n        \.clamp\(1, kMaxFlattenSegments\);/    final steps = 32;/' "$F"; run; cp /tmp/t12.dart "$F"
# T12c: drop every third triangle
perl -0pi -e 's/    for \(var i = 0; i < triangles\.length; i \+= 3\) \{/    for (var i = 0; i < triangles.length; i += 6) {/' "$F"; run; cp /tmp/t12.dart "$F"
```

All three must print `KILLED`. **T12a is killed only by the hairline fixture.**

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart \
        packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart
git commit -m "feat: VerticesDrawSink fills, with the two invariants pinned"
```

---

## Task 13: The painter draws fills, and counts the ones it skips

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart`
- Create: `packages/jet_cad_2d_flutter/test/fill_render_test.dart`

**Interfaces:**
- Produces: `int get skippedFillCount` on `DraftPainter`, reset per frame like `dashSpanCount`.

**The painter owns the skip, not the sinks.** `CanvasDrawSink` fills a path by non-zero winding, so a self-intersecting boundary would paint *something* there while `VerticesDrawSink` painted nothing — a divergence manufactured on exactly the case this plan refuses. So the painter checks for an unresolvable reference or an empty triangulation, skips, and counts. Neither sink is ever handed an empty fill.

**Where the fill goes in `_drawLeafComposed`.** A fill's geometry is its boundary's, and a boundary is a polyline or a circle. Polylines go through `_emitScreenSpace` (points carried into screen space, residual is a bare translation); circles keep the residual path. **A fill follows its boundary's route**, so a polygon fill's points are screen-space and its stroke-width question never arises, and a circle fill's residual is the same one its outline gets.

- [ ] **Step 1: Write the failing tests**

`packages/jet_cad_2d_flutter/test/fill_render_test.dart`:

```dart
test('a region draws the fill before its boundary', () {
  final doc = DraftDocument.empty();
  final cmd = region(doc);
  doc.commands.execute(cmd);
  final sink = RecordingDrawSink();
  paintOnce(doc, sink);
  final fillAt = sink.ops.indexWhere((o) => o is FillPolygonOp);
  final strokeAt = sink.ops.indexWhere((o) => o is PolylineOp);
  expect(fillAt, isNonNegative);
  expect(fillAt, lessThan(strokeAt),
      reason: 'draw order is ascending handle value and the fill holds the '
          'lower one; if this inverts, the fill paints over its own outline');
});

test('an unfillable boundary is skipped and counted, not handed to a sink', () {
  final doc = DraftDocument.empty();
  final cmd = region(doc);
  doc.commands.execute(cmd);
  // Edit the boundary into a bow tie: still closed, no longer simple.
  doc.commands.execute(SetEntityGeometryCommand(
      cmd.boundary.handle,
      GeometryPayload(
          coords: Float64List.fromList([0, 0, 10, 10, 10, 0, 0, 10, 0, 0]),
          scalars: Float64List(0))));
  final sink = RecordingDrawSink();
  final painter = paintOnce(doc, sink);
  expect(sink.ops.whereType<FillPolygonOp>(), isEmpty,
      reason: 'CanvasDrawSink fills a self-intersecting path by non-zero '
          'winding while VerticesDrawSink draws nothing -- handing either one '
          'this fill manufactures a divergence on the refused case');
  expect(painter.skippedFillCount, 1);
});

test('a circle boundary draws a fillCircle, never a triangulated polygon', () {
  // The scale-dependence rule, as a drawing property.
  final doc = DraftDocument.empty();
  doc.commands.execute(AddRegionCommand.allocate(
    seed: doc.handleSeed,
    owner: doc.rootHandle,
    boundaryKind: EntityKind.circle,
    boundaryPayload: GeometryPayload(
        coords: Float64List.fromList([0, 0]),
        scalars: Float64List.fromList([50])),
    layer: ReservedHandles.layerZero,
    fillColor: const TrueColor(0x3366CC),
    boundaryColor: const TrueColor(0x000000),
  ));
  final sink = RecordingDrawSink();
  paintOnce(doc, sink);
  expect(sink.ops.whereType<FillCircleOp>(), hasLength(1));
  expect(sink.ops.whereType<FillPolygonOp>(), isEmpty);
});

test('skippedFillCount is per frame, not a running total', () {
  // Plan 3c's Ruling 44: a counter that never resets prints a plausible number
  // beside two per-frame figures and reads as a working gate.
  final doc = DraftDocument.empty();
  doc.commands.execute(region(doc));
  doc.commands.execute(SetEntityGeometryCommand(
      doc.entities.handleAt(doc.entities.liveSlots.last),
      GeometryPayload(
          coords: Float64List.fromList([0, 0, 10, 10, 10, 0, 0, 10, 0, 0]),
          scalars: Float64List(0))));
  final painter = paintOnce(doc, RecordingDrawSink());
  paintAgain(painter, RecordingDrawSink());
  expect(painter.skippedFillCount, 1);
});

test('the painter walks fills and the reference walk agrees', () {
  // `expectPainterSupersetOfReference` in
  // `packages/jet_cad_2d_flutter/test/support/differential.dart` is the
  // existing oracle. It is a *superset* check by design, so it catches a
  // painter that forgets a fill and not one that draws an extra -- pair it
  // with the ordering test above, which is exact.
  final doc = DraftDocument.empty();
  doc.commands.execute(region(doc));
  expectPainterSupersetOfReference(doc);
});
```

- [ ] **Step 2: Run and watch them fail**

- [ ] **Step 3: Implement**

In `_drawLeafComposed`, before the kind switch:

```dart
      case EntityKind.fill:
        _drawFill(sink, camera, origin, placement, slot, style);
        return;
```

```dart
  /// Draws one fill, or skips it and says so.
  ///
  /// A fill has no geometry of its own: it occupies its boundary's loop and
  /// follows its boundary's route through this painter -- screen space for a
  /// polygon, the residual path for a circle -- so a filled shape and its own
  /// outline are transformed by the same code.
  ///
  /// **The skip lives here, not in a sink.** `CanvasDrawSink` fills a
  /// self-intersecting path by non-zero winding while `VerticesDrawSink`, given
  /// no triangles, draws nothing. Handing either of them an unfillable fill
  /// manufactures a backend divergence on exactly the case this plan refuses,
  /// so neither is ever handed one.
  void _drawFill(DrawSink sink, ViewportTransform camera, Vector2 origin,
      Transform2 placement, int slot, ResolvedStyle style) {
    final payload = document.geometry.peek(document.entities.geomIndexAt(slot));
    final boundary = boundaryHandleOf(payload);
    final boundarySlot = document.entities.slotOf(boundary);
    if (boundarySlot == null) {
      _skippedFills++;
      return;
    }
    final boundaryKind = document.entities.kindAt(boundarySlot);
    final boundaryPayload =
        document.geometry.peek(document.entities.geomIndexAt(boundarySlot));
    final toScreen = camera.worldToScreenMatrix.multiply(placement);

    if (boundaryKind == EntityKind.circle) {
      // Never triangulated ahead of time: a circle's tessellation is
      // scale-dependent, and the sink fans it at the step count its own stroke
      // uses.
      final localOrigin = _localOriginFor(placement, origin);
      final chain = camera.worldToScreenMatrix
          .multiply(placement)
          .multiply(Transform2.translation(localOrigin.x, localOrigin.y));
      sink.beginResidual(chain,
          debugHandle: document.entities.handleAt(slot));
      sink.fillCircle(boundaryPayload.coords[0] - localOrigin.x,
          boundaryPayload.coords[1] - localOrigin.y,
          boundaryPayload.scalars[0], style);
      sink.endResidual();
      return;
    }

    // Read, never compute: the triangulation was materialised by the command,
    // the codec or undo. A miss here means the boundary is unfillable.
    final triangles = document.fills.trianglesFor(boundary);
    if (triangles == null || triangles.isEmpty) {
      _skippedFills++;
      return;
    }

    final count = boundaryPayload.pointCount;
    _ensurePoints(count);
    for (var i = 0; i < count; i++) {
      final x = boundaryPayload.coords[i * 2];
      final y = boundaryPayload.coords[i * 2 + 1];
      _points[i * 2] =
          toScreen.a * x + toScreen.c * y + toScreen.e - _screenOrigin.x;
      _points[i * 2 + 1] =
          toScreen.b * x + toScreen.d * y + toScreen.f - _screenOrigin.y;
    }
    sink.beginResidual(Transform2.translation(_screenOrigin.x, _screenOrigin.y),
        debugHandle: document.entities.handleAt(slot));
    sink.fillPolygon(_points, count, triangles, style);
    sink.endResidual();
  }
```

`_skippedFills` resets in the same place `_screenSpaceLeaves` does, and is
exposed as `int get skippedFillCount => _skippedFills;`.

`reference_walk.dart` gets the same shape, written independently — it resolves
the boundary and calls `fillPolygon`/`fillCircle` itself. **It must not share a
helper with the painter**: the oracle exists to disagree, and a shared helper
would have it share the assumption it is testing.

- [ ] **Step 4: Run and watch them pass**

- [ ] **Step 5: Run the named mutations**

```sh
# T13a: draw the fill after the boundary          -> the ordering test reds
# T13b: hand an empty triangulation to the sink   -> the skip test reds
# T13c: never increment _skippedFills             -> the counter test reds
# T13d: do not reset _skippedFills per frame      -> the per-frame test reds
# T13e: triangulate a circle boundary instead of fanning it -> the circle test reds
# T13f: share _drawFill between painter and reference walk  -> no test reds;
#       this one is a REVIEW item, not a mutation. Recorded so nobody does it.
```

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/draft_painter.dart \
        packages/jet_cad_2d_flutter/lib/src/reference_walk.dart \
        packages/jet_cad_2d_flutter/test/fill_render_test.dart
git commit -m "feat: the painter draws fills, and counts the ones it skips"
```

---

## Task 14: Goldens and the opaque agreement floor

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart`
- Create: `packages/jet_cad_2d_flutter/test/golden/fill_ladder_*.png` and `vertices/fill_ladder_*.png`
- Modify: `packages/jet_cad_2d_flutter/test/support/sink_comparison.dart` (fill fixtures)
- Modify: `packages/jet_cad_2d_flutter/test/sink_comparison_test.dart`

**Interfaces:**
- Consumes: everything through Task 13.
- Produces: three fill goldens per backend, and one opaque agreement row.

**The fixture is the deliverable, not the PNGs.** It must carry, in one drawing: an **L-shaped** boundary (concave — a fan would fill the notch), a **clockwise** boundary (winding normalisation), a **circle** boundary (the un-cached path), a fill whose colour **differs** from its boundary's (so covering is visible), and a fill on a **hairline** layer (so `_coveredArgb` cannot hide). Every one of those is a mutant from an earlier task that a normal-looking fixture would let through.

**The opaque agreement threshold, declared:**

> `strayVerticesPixels` and `uncoveredCanvasPixels` must each be **at most 1 %** of `canvasInkPixels`, and `canvasInkPixels` must exceed **4000** so the row cannot pass against a near-blank surface.

- [ ] **Step 1: Write the fixture and the failing golden test**

Follow `dash_ladder_golden_test.dart` exactly — `_at()` plus `matchesGoldenFile`
for canvas, `TriangleRasterizer` at **device** resolution plus
`matchesGoldenFile` on the image for vertices, and the
`key.currentState!.vertices!.devicePixelRatio == dpr` assertion, which
`--update-goldens` cannot absorb.

Three rungs at half-spans `60.0`, `400.0`, `4000.0`.

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && flutter test --tags golden`
Expected: FAIL — no golden files exist yet.

- [ ] **Step 3: Generate the goldens and look at them**

```sh
flutter test --tags golden --update-goldens
```

**Open all six PNGs.** A golden accepted without being looked at pins whatever
the code did, including nothing — Plan 3d shipped two blank goldens that passed
under a renderer emitting no geometry. The non-vacuity assertion
(`rasterizer.pixels.any((p) => p != 0)`) is required, not optional.

- [ ] **Step 4: Add the opaque agreement row**

```dart
testWidgets('the two sinks agree on an opaque fill', (tester) async {
  final report = await measureAgreement(tester, fillComparisonDoc(), drawAll);
  expect(report.canvasInkPixels, greaterThan(4000),
      reason: 'non-vacuity: this row must not pass against a near-blank '
          'surface');
  expect(report.strayVerticesPixels,
      lessThanOrEqualTo(report.canvasInkPixels ~/ 100));
  expect(report.uncoveredCanvasPixels,
      lessThanOrEqualTo(report.canvasInkPixels ~/ 100));
});
```

- [ ] **Step 5: Run the named mutations**

```sh
# T14a: fan the polygon from vertex 0 instead of ear-clipping
#       -> the L-shaped rung must red on BOTH backends
# T14b: skip winding normalisation
#       -> the clockwise rung must red
# T14c: route the fill through _coveredArgb
#       -> the hairline rung must red on the vertices backend only
```

If T14a reds only the vertices rung, the canvas golden is not exercising the
notch and the fixture is wrong.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d_flutter/test/golden packages/jet_cad_2d_flutter/test/support \
        packages/jet_cad_2d_flutter/test/sink_comparison_test.dart
git commit -m "test: fill goldens on both backends, and the opaque floor"
```

---

## Task 15: The translucent seam, measured against the real engine

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/fill_seam_test.dart`
- Modify (only if the rule fires): `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`

**Interfaces:**
- Produces: a measured percentage and maximum, and either a routing change or a recorded number.

**Read this before writing a line.** `TriangleRasterizer` **cannot see this**. Its inner loop is `pixels[y * width + x] = rgba` — a plain store, no blending, no alpha compositing, no antialiasing. Both divergence modes are blending artefacts. A seam test written against the repository's own rasterizer — the natural instrument, the one every golden uses — would pass against a sink drawing the artefact at full strength. **That is the degenerate fixture in its most expensive form: one a review has already approved.**

The instrument is a `ui.Picture` recorded through each sink, `picture.toImage()`, `toByteData()`, compared pixel by pixel. Plan 3d's Task 2 used exactly this when it needed an answer the rasterizer could not give.

**There are two modes and both are measured:**

1. **Overlapping strokes**, exactly as Plan 3d recorded. At every join `_emitJoin` fills the notch on the *outer* side, and the two chord quads meeting at that vertex overlap in a lens on the *inner* side. Two rectangles of equal half-width sharing an endpoint at an angle intersect; that is geometry, not a bug. Under alpha every corner double-blends.
2. **Shared triangulation edges**, new with fills. A triangulation tiles its interior — triangles share edges, not area — so the artefact is at the edges: `isAntiAlias` defaults true and `VerticesDrawSink` does not clear it, so two adjacent triangles blend one edge pixel twice at partial coverage. `Canvas.drawPath` computes coverage once and has no seam.

**The rule, declared before the measurement.** Fixture: one convex-and-a-notch boundary filled at `alpha = 0x80` over white, one entity, 400 × 300 logical at the `flutter_test` default device pixel ratio of 3.0. Interior pixels only; the outer boundary ring, one device pixel wide, is excluded.

> **Routing fires if** more than **0.5 %** of interior pixels differ by more than **8/255** in any channel, **or** any single interior pixel differs by more than **32/255**.

**Both outcomes are results.** If it fires, translucent fills route through the fallback sink via `_flushBeforeUnbatchable` — whose only caller today is `text`. If it does not, translucent fills batch and both divergences are recorded as inert in practice **with the measured percentage and maximum beside them**. Measuring and stopping is the outcome; tuning until the number complies is not.

**A third answer is rejected on the record:** clearing `isAntiAlias` on the vertices `Paint` removes the partial coverage and with it the seam — and jags every stroke in the drawing, on every frame, to fix an artefact that appears only under alpha.

- [ ] **Step 1: Write the measurement**

```dart
/// Records [draw] into a Picture through a fresh sink and rasterises it in the
/// engine, WITH blending. `TriangleRasterizer` cannot be used here: it stores
/// `pixels[i] = rgba` with no compositing at all, so it cannot see a blending
/// artefact, and a test built on it would pass against a sink drawing the
/// artefact at full strength.
Future<ByteData> renderThrough(
    WidgetTester tester, DrawSink Function(Canvas) make, Drawing draw) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 1200, 900),
      Paint()..color = const Color(0xFFFFFFFF));
  draw(make(canvas));
  final picture = recorder.endRecording();
  final image = await tester.runAsync(() => picture.toImage(1200, 900));
  addTearDown(image!.dispose);
  return (await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
}

testWidgets('the translucent seam, measured', (tester) async {
  final canvasBytes = await renderThrough(tester, canvasSink, translucentFill);
  final verticesBytes =
      await renderThrough(tester, verticesSink, translucentFill);

  var over8 = 0, interior = 0, worst = 0;
  for (final (x, y) in interiorPixels()) {   // the fixture's own interior,
    interior++;                              // eroded by one device pixel
    final d = maxChannelDelta(canvasBytes, verticesBytes, x, y);
    if (d > 8) over8++;
    if (d > worst) worst = d;
  }
  final fraction = over8 / interior;
  // ignore: avoid_print
  print('SEAM interior=$interior over8=$over8 '
      'fraction=${(fraction * 100).toStringAsFixed(3)}% worst=$worst');

  expect(interior, greaterThan(4000),
      reason: 'non-vacuity: an empty interior would satisfy every bound below');
  expect(fraction, lessThanOrEqualTo(0.005),
      reason: 'above this the plan routes translucent fills through the '
          'fallback sink; see the design\'s declared rule');
  expect(worst, lessThanOrEqualTo(32));
});
```

- [ ] **Step 2: Run it and read the number**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/fill_seam_test.dart`
**Record the printed `SEAM` line verbatim.** It is the result whichever way it
goes.

- [ ] **Step 3: Prove the instrument can see a seam at all**

Before trusting a pass, force one: emit each triangle **twice** in
`fillPolygon`. The measurement must go red. If it does not, the instrument is
wrong and the pass in Step 2 meant nothing.

```sh
cp lib/src/vertices_draw_sink.dart /tmp/t15.dart
trap 'cp /tmp/t15.dart lib/src/vertices_draw_sink.dart' EXIT
# double-blend every triangle
perl -0pi -e 's/(      _emitTriangle\(\n(?:.*\n)*?        argb,\n      \);)/$1\n      _emitTriangle(\n        t.a * points[a * 2] + t.c * points[a * 2 + 1] + t.e,\n        t.b * points[a * 2] + t.d * points[a * 2 + 1] + t.f,\n        t.a * points[b * 2] + t.c * points[b * 2 + 1] + t.e,\n        t.b * points[b * 2] + t.d * points[b * 2 + 1] + t.f,\n        t.a * points[c * 2] + t.c * points[c * 2 + 1] + t.e,\n        t.b * points[c * 2] + t.d * points[c * 2 + 1] + t.f,\n        argb,\n      );/' lib/src/vertices_draw_sink.dart
flutter test test/fill_seam_test.dart   # must FAIL
cp /tmp/t15.dart lib/src/vertices_draw_sink.dart
```

- [ ] **Step 4: If the rule fired, route translucent fills to the fallback**

Only if Step 2 exceeded a bound:

```dart
  @override
  void fillPolygon(Float64List points, int count, Int32List triangles,
      ResolvedStyle style) {
    if (triangles.isEmpty) return;
    if ((style.argb >>> 24) != 0xFF) {
      // Measured, not assumed: see the plan's Task 15 and the results note.
      // A triangle soup blends shared edges twice; a path blends once.
      _flushBeforeUnbatchable();
      _fallback?.fillPolygon(points, count, triangles, style);
      return;
    }
    // ... the batched path
  }
```

and pin the routing with an order test — a translucent fill must flush before
the fallback draws, the same property Plan 3d pins for `text`.

- [ ] **Step 5: Record the number either way**

Write the `SEAM` line, the fixture, the viewport, the device pixel ratio and
the decision into the commit message. Task 17 copies it into the results note.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d_flutter/test/fill_seam_test.dart \
        packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart
git commit -m "test: the translucent seam, measured against the real engine"
```

---

## Task 16: The rig grows fills

**Files:**
- Modify: `apps/dev_harness_2d/lib/main.dart`
- Modify: `apps/dev_harness_2d/lib/measurement_rig.dart`
- Modify: `apps/dev_harness_2d/integration_test/frame_timing_test.dart`
- Modify: `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`

**Interfaces:**
- Produces: `--dart-define=FILLS=true|false`, `fillCount` and `skippedFills` on the invariants line.

**A `String.fromEnvironment`, and it stays one.** Plan 3c lost a full device run to `bool.fromEnvironment('TEXT')` reading `--dart-define=TEXT=1` as false while printing entirely plausible numbers. Follow `kBackend`'s shape: a string, with an unrecognised value throwing at startup.

- [ ] **Step 1: Extend the corpus**

Fills go in behind the define, on the same corpus, so on/off is one flag apart
on one drawing — exactly as text does. A fraction of the corpus's closed
polylines gain a region partner; the fraction is a named constant beside
`kDashedFraction`.

- [ ] **Step 2: Print the counters**

`printInvariants` gains two fields, so a backend pair is still a comparison of
two renderers and not of two drawings:

```dart
void printInvariants(DraftPainter painter, CanvasDrawSink sink) {
  print('  screenSpaceLeafCount=${painter.screenSpaceLeafCount} '
      'dashSpans=${painter.dashSpanCount} '
      'collapsed=${painter.collapsedDashCount} '
      'canvasCalls=${sink.canvasCallCount}');
  print('  fills=${painter.fillCount} '
      'skippedFills=${painter.skippedFillCount}');
}
```

- [ ] **Step 3: Extend the allocation gate**

`paint_allocation_test.dart` runs its two-flush comparison on a corpus
**containing fills**. The steady-state requirement is unchanged: **zero
allocations per fill**. A cache hit returns the stored `Int32List` by
reference, so a hit allocates nothing; a *miss* on the frame path would show up
here immediately, which is a second gate on "populated eagerly, never lazily".

- [ ] **Step 4: Measure, on the device**

```sh
cd apps/dev_harness_2d
# check first, and record it: pmset -g | grep lowpowermode
flutter drive --profile -d macos --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart \
  --dart-define=RIG=pan --dart-define=ENTITIES=10000 \
  --dart-define=BACKEND=vertices --dart-define=FILLS=true
```

Six runs: `{10000, 50000} × {canvas, vertices}` with `FILLS=true`, plus
`{10000} × {canvas, vertices}` with `FILLS=false` for the delta.

**After every `flutter drive`:** `git checkout -- apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`.

- [ ] **Step 5: Measure the load cost**

The one row eager materialisation owes:

```dart
test('load-time triangulation cost, recorded', () {
  final json = jsonEncode(JsonCodec.save(fillHeavyCorpus()));
  final sw = Stopwatch()..start();
  JsonCodec.load(jsonDecode(json) as Map<String, Object?>);
  // ignore: avoid_print
  print('LOAD fills=$n elapsed=${sw.elapsedMilliseconds}ms');
});
```

No threshold — but no plan may skip the row.

- [ ] **Step 6: Commit**

```bash
git status --porcelain   # project.pbxproj must NOT appear
git add apps/dev_harness_2d packages/jet_cad_2d_flutter/test/invariants
git commit -m "test: the rig corpus grows fills, behind a define"
```

---

## Task 17: Mutation testing, the exit gate, and the results note

**Files:**
- Create: `docs/superpowers/notes/plan-3e-mutation-log.md`
- Create: `docs/superpowers/notes/<the day it is written>-plan-3e-results.md`, dated like its siblings
- Modify: `STATUS.md`
- Modify: `CLAUDE.md` **only if** a non-negotiable turns out not to describe this backend — and then only to record that it does not. **The plan may not amend the rule it is measured against.**

- [ ] **Step 1: Re-run every mutation this plan named**

Every mutant from Tasks 1–15, on today's merged code, with the `cp`/`trap`
harness. **Never `git checkout` a file to revert one.** Record each as killed,
survived, unreachable, or equivalent — with the argument, never silently.

- [ ] **Step 2: Add the mutants no task owns**

The cross-task ones, which are where this plan is most exposed:

| mutation | the fixture property that kills it |
|---|---|
| key the cache by `geomIndex` | **purge a document containing fills and draw again** |
| drop dependent fills from `SetEntityGeometry`'s `touched` | edit a boundary, then pick or cull **inside the new-but-outside-the-old region** |
| make `AddRegionCommand` two composed commands | assert no observer sees a fill whose boundary is missing |
| populate the cache lazily on first draw | the allocation gate, on a corpus with fills |
| let the codec skip `_rebuildFills` | the same gate, after a load |

- [ ] **Step 3: Run the whole gate**

```sh
cd packages/jet_cad_2d       && dart test && dart analyze && dart format --output=none --set-exit-if-changed . \
  && dart test test/invariants/query_allocation_test.dart \
  && dart run benchmark/query_throughput.dart   # `snap at dirty threshold` is the known carried failure
cd packages/jet_cad_2d_flutter && flutter test && flutter test --tags golden \
  && flutter analyze && dart format --output=none --set-exit-if-changed .
cd apps/dev_harness_2d && flutter analyze
```

- [ ] **Step 4: Write the results note**

Every failable criterion, with its number:

| criterion | threshold |
|---|---|
| allocations per fill in a steady-state frame | **zero** |
| 10,000 entities with fills on, vertices backend | under 16.67 ms |
| a fill's cost in `canvasCalls` on the vertices backend | **zero** |
| ink agreement, opaque fills | stray and uncovered each ≤ 1 % of `canvasInkPixels`, with `canvasInkPixels > 4000` |
| translucent seam difference | measured against the real engine; routing fires above 0.5 % at 8/255, or any pixel at 32/255 |
| `skippedFillCount` on the rig corpus | **0** |
| a malformed fill in a loaded document | reported by `validate()` with the matching code, nothing mutated |
| triangulation entries after `purge()` | drawing unchanged, byte for byte |
| cache entries after removing every fill's boundary | **zero** |
| load-time triangulation cost | measured and recorded |
| the mutation log | every mutant killed or argued equivalent |

**If a failable row misses: record the number and stop.** Plan 3b's Task 4 stop
clause is the precedent. Say what it implies for 3f; do not tune until it
complies.

The note must state **whether macOS Low Power Mode was on** — read it with
`pmset -g | grep lowpowermode` and record the value.

- [ ] **Step 5: Update `STATUS.md`**

Commit **ranges**, never a count: a count is falsified by the commit that
writes it.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/notes STATUS.md
git commit -m "docs: Plan 3e results, mutation log, and the exit gate"
```

---

## Notes for whoever executes this

- **`git status --porcelain` after every `flutter test` or `flutter drive`.** `flutter pub get` rewrites three `analysis_options.yaml` files and `flutter drive` rewrites `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`. Neither is ever committed.
- **Never `git checkout` a file to revert a mutation.** Plan 3c's Task 10 lost a full task's work that way. `cp` aside, restore in a `trap`.
- **Never synthesize test output.** Reviewers verify claims independently.
- **The named mutation is the deliverable, not the test.** A task whose new tests stay green under its own named mutations is not done, whatever the suite says.
- **Work happens directly on `main`** for this plan. There is no worktree, so `.superpowers/sdd/<plan-slug>/` lives in the main checkout and must be archived to `docs/superpowers/ledgers/` in the same way a worktree plan's is.
