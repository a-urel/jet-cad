# Interaction core (sub-project 02) — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clicking, shift-clicking, hovering and rubber-banding select
root-level objects in `apps/floor_planner`; the selection is outlined by a
separate overlay that never repaints the drawing and stays exact at
x = 4.5e6; Escape and Delete work; a `Tool` interface exists with
`SelectTool` as its first implementation — every rule under a named mutant.

**Architecture:** the engine gains two band walks on `SpatialIndex`
(`forEachLeafInBand`, `forEachInstanceInBand`) over pure predicates in
`band_predicates.dart`, exact per entity kind, descending instances with the
same transform pair `_descend` uses. The render layer gains a
`SelectionController` (keys and hover, pruned from `document.changes`), a
`Tool` interface and `ToolController`, `SelectTool` (a phase table),
`InteractionLayer` (a `Listener` + `Focus` that routes on button transitions
and one active pointer), an `OutlineCache` (world-space `Float64List`s at
selection time, a rebased `ui.Path` per origin tag), and `SelectionOverlay`
(a sibling `CustomPainter` in its own `RepaintBoundary`). The app owns the
controllers in its shell state and shows the tool name and count.

**Tech Stack:** Dart, Flutter **3.47.2** (the installed SDK, under a cask
directory named `3.27.3`), `flutter_test`, `vector_math`, `jet_cad_2d`,
`jet_cad_2d_flutter`. No new dependency anywhere.

**Spec:** [docs/superpowers/specs/2026-09-21-interaction-core-design.md](../specs/2026-09-21-interaction-core-design.md),
**revision 2**. Read it whole before Task 1: decisions D1–D12, the pointer
routing table, the `SelectTool` table, the invariants, the thirty mutants and
the fifteen exit criteria. The review that produced revision 2 is
[docs/superpowers/notes/2026-09-21-interaction-core-spec-review-r1.md](../notes/2026-09-21-interaction-core-spec-review-r1.md);
its B2 (the float32 rebase) is the one a Flutter developer is most likely to
undo by reflex — read it before Task 7.

**Roadmap input:** [roadmap/02-interaction-core.md](../../../roadmap/02-interaction-core.md).
Its M-02c and M-02e are declared equivalent by the spec, with reasons; the
plan records them in the mutation log rather than firing them.

**Branch:** `plan-02/interaction-core`, cut from `main` at `76b5a2e` or later,
in its own worktree (`superpowers:using-git-worktrees`). The ledger lives at
`.superpowers/sdd/2026-09-21-interaction-core/` while the plan is in flight
and is archived to `docs/superpowers/ledgers/` on merge.

---

## Rulings made here rather than left to an implementer

- **Ruling 02-1 — the predicates take six raw coefficients, not a
  `Transform2`.** The spec says "a composed transform". `_considerLeaf`
  passes `ta..tf` by value so the descent allocates no matrix per
  candidate; the band predicates are called from the same descent and take
  the same six doubles. A `Transform2`-taking wrapper exists for tests and
  for the brute-force differential arm.
- **Ruling 02-2 — the group every/any rule is computed in the tool from the
  set of passing leaf slots.** The engine walk cannot know which leaves are
  "all of a group's"; the tool collects `forEachLeafInBand`'s slots into a
  `Set<int>`, buckets the document's leaves once with `leavesByOwner()`, and
  decides each group: window → every owned leaf (nested groups included) is
  in the set; crossing → any is. No engine change for groups.
- **Ruling 02-3 — a `SelectionKey`'s `chain` is a `Uint32List` compared
  element-wise; `hashCode` is `Object.hash(Object.hashAll(chain), target)`.**
  `Uint32List` has identity `==`, so the class must not lean on it.
- **Ruling 02-4 — the outline of a text is its four oriented corners, laid
  out exactly as `_considerLeaf` does it** (`resolveTextAttributes`,
  `textLocalTransform`, `textLocalBounds`, then the composed world
  transform), through the document's `textMeasurer`. Allocation is fine
  there: it runs at selection-change rate.
- **Ruling 02-5 — `SelectionController.remove` exists** (spec D6 lists it):
  Delete drops only what it removed; `clear()` would also drop refused
  objects, which D10 says stay selected.
- **Ruling 02-6 — the differential's brute-force arm uses `Transform2`s and
  `GeometryPayload.transformedBy`** and applies the *same* predicate
  functions through the `Transform2` wrapper. It is a check on the broad
  phase, the descent and the deduplication, not a second implementation of
  the geometry. The geometry itself is pinned by the per-kind fixtures.
- **Ruling 02-7 — no ledger row for the harness count is needed beyond
  Task 1's measurement**: it is 82 at `main@76b5a2e` (STATUS), re-measured
  at the branch point and again in Task 12.

## Global Constraints

Copied from `CLAUDE.md` and the spec; this plan's additions marked.

- **The frame path allocates nothing per entity in steady state, and O(1)
  per flush.** `query_allocation_test.dart` and `paint_allocation_test.dart`
  stay green unedited. **This plan adds:** `SelectionOverlay.paint`
  allocates nothing per key (its two `Paint`s and its transform matrix are
  fields; paths are rebuilt only when the rebase origin or the selection
  changes); the hover pick allocates nothing per entity.
- **Draw order is ascending handle value.** Both band walks sort before
  reporting (M-02z). Nothing here writes to the document except through
  `RemoveEntityCommand` and `RemoveNodeCommand`.
- **Geometric decisions use `Tolerance`; stored value comparisons are exact
  `==`.** Nothing in this plan introduces a tolerance comparison; the pick
  radius and the band are query parameters. `scale == _gestureZoom`-style
  stored comparisons stay exact.
- **No absolute world coordinate reaches `dart:ui`.** The overlay builds its
  `ui.Path` in the space rebased by `rebaseOriginFor` (spec D9, M-02v).
- **Never commit a rewrite of `analysis_options.yaml`** (Ruling 01-1).
  `git status --short` before every commit; `git checkout --` any
  `analysis_options.yaml` that `pub get` rewrote.
- **Never synthesize test output.** Run the command, paste what it printed,
  including the exit code.
- **Before firing a mutation, back the file up with `cp`, and restore from
  that copy.** Never `git checkout --` a file to revert a mutation.
- **Prefix every test command with `CI=true`.**
- Code, comments and commit messages in English.
- **`apps/dev_harness_2d` is untouched.** 82 tests at the branch point.
- **`DraftCanvas`, `DraftPainter`, `CameraGestureDetector`, `TileCache` are
  untouched.** None of their files is in this plan's diff.
- **Every fixture is off the identity.** Cameras via `fitOffOrigin` or a
  scale ≠ 1 with a non-zero translation; geometry off the origin; every
  instance at the reference placement `(300, −200)`, 30°, ×1.5 or another
  placement with all three non-trivial; every band fixture has a straddling
  entity; the overlay precision fixture at `kDefaultOriginX`.
- **Overlay tests never rebuild the widget between a controller mutation
  and the assertion** — a repaint may only come from the listenable.
- **Every task ends green.** The eleven gate commands (spec, criterion 12):

  ```sh
  cd packages/jet_cad_2d         && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
  cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
  cd apps/dev_harness_2d         && CI=true flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
  cd apps/floor_planner          && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build macos --debug && flutter build web
  ```

  Tasks 1–2 run the `jet_cad_2d` line. Tasks 3–9 run the
  `jet_cad_2d_flutter` line (its `flutter test` exits 1 on the five
  pre-existing `text_ladder_golden_test.dart` failures and on nothing else —
  the 01 baseline ruling; paste the summary line and check the failing names
  are those five). Task 10 adds the `floor_planner` line. Tasks 11 and 12
  run all four.

## File structure

| file | responsibility |
|---|---|
| `packages/jet_cad_2d/lib/src/geometry/band_predicates.dart` | **create** — `leafEnclosedByBand`, `leafTouchedByBand` (six coefficients), `Transform2` wrappers |
| `packages/jet_cad_2d/lib/src/index/spatial_index.dart` | **modify** — `BandMode`; `forEachLeafInBand`, `forEachInstanceInBand`, `_descendBand` |
| `packages/jet_cad_2d/lib/jet_cad_2d.dart` | **modify** — export `band_predicates.dart` |
| `packages/jet_cad_2d/test/geometry/band_predicates_test.dart` | **create** |
| `packages/jet_cad_2d/test/index/band_query_test.dart` | **create** — walks, descent, dirty overlay, order, differential |
| `packages/jet_cad_2d_flutter/lib/src/selection.dart` | **create** — `SelectionKey`, `resolveHit`, `SelectionController` |
| `packages/jet_cad_2d_flutter/lib/src/tool.dart` | **create** — `Tool`, `ToolContext`, `ToolPointerEvent`, `ToolPhase`, `ToolController` |
| `packages/jet_cad_2d_flutter/lib/src/select_tool.dart` | **create** — `SelectTool`, `kBandSlopPixels`, the delete preflight |
| `packages/jet_cad_2d_flutter/lib/src/selection_style.dart` | **create** — the constants |
| `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart` | **create** — `OutlineCache` |
| `packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart` | **create** — `SelectionOverlay` |
| `packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart` | **create** — `InteractionLayer`, `kPickRadiusPixels` |
| `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` | **modify** — seven exports |
| `packages/jet_cad_2d_flutter/test/support/selection_fixture.dart` | **create** — documents, instances, groups, a camera, `pumpInteraction` |
| `packages/jet_cad_2d_flutter/test/selection_test.dart` | **create** |
| `packages/jet_cad_2d_flutter/test/tool_controller_test.dart` | **create** |
| `packages/jet_cad_2d_flutter/test/select_tool_test.dart` | **create** |
| `packages/jet_cad_2d_flutter/test/outline_cache_test.dart` | **create** |
| `packages/jet_cad_2d_flutter/test/selection_overlay_test.dart` | **create** |
| `packages/jet_cad_2d_flutter/test/interaction_layer_test.dart` | **create** |
| `apps/floor_planner/lib/main.dart` | **modify** — controllers on the shell, status text |
| `apps/floor_planner/lib/planner_view.dart` | **modify** — the interaction tree |
| `apps/floor_planner/test/planner_shell_test.dart` | **modify** — status text follows the selection |
| `docs/superpowers/notes/plan-02-mutation-log.md` | **create** |
| `docs/superpowers/notes/2026-09-21-plan-02-results.md` | **create** |
| `roadmap/00-README.md`, `roadmap/02-interaction-core.md`, `STATUS.md` | **modify** — plan and execution recorded |

Paths under `lib/` and `test/` in Tasks 1–2 are relative to
`packages/jet_cad_2d/`; in Tasks 3–9 to `packages/jet_cad_2d_flutter/`; in
Task 10 to `apps/floor_planner/`.

---

### Task 1: The branch point, and the band predicates

**Files:**
- Create: `lib/src/geometry/band_predicates.dart`
- Modify: `lib/jet_cad_2d.dart` (one export)
- Test: `test/geometry/band_predicates_test.dart`

**Interfaces:**
- Consumes: `GeometryPayload` (`coords`, `scalars`, `pointCount`), `Aabb2`,
  `clipSegment`, `circleClipWindows`, `angleInSweep`, `EntityKind`,
  `resolveTextAttributes`, `textLocalTransform`, `textLocalBounds`,
  `TextMetrics`, `TextStyleRecord`.
- Produces, for Task 2 and Task 7:

```dart
/// Some point of the stroke lies inside [band] (spec D8, crossing).
bool leafTouchedByBand(EntityKind kind, GeometryPayload payload,
    double ta, double tb, double tc, double td, double te, double tf,
    Aabb2 band, {TextBox? textBox});

/// Every point of the leaf's world AABB lies inside [band] (spec D8, window).
/// [worldBox] is `boxOfLeaf(slot) ?? dirty.boxOf(slot)` — the caller reads it.
bool boxEnclosedByBand(Aabb2 worldBox, Aabb2 band);

/// The four oriented corners of a text or attrib in the leaf's own space,
/// laid out as `_considerLeaf` does. Null when the box is degenerate.
TextBox? textBoxOf(GeometryPayload payload, int textAttrs,
    TextStyleRecord style, TextMetrics metrics);

final class TextBox { final double minX, minY, maxX, maxY; final Transform2 local; }

/// Transform2-taking wrapper for tests and the differential arm.
bool leafTouchedByBandT(EntityKind kind, GeometryPayload payload,
    Transform2 toWorld, Aabb2 band, {TextBox? textBox});
```

- [ ] **Step 1: Branch point and baselines**

```sh
git -C /Users/ahmeturel/Projects/oss/jet-cad log --oneline -1   # expect 76b5a2e or later
git rev-parse --abbrev-ref HEAD                                   # plan-02/interaction-core
cd packages/jet_cad_2d && CI=true dart test 2>&1 | tail -3        # record the count in the ledger (798 at main)
cd ../../apps/dev_harness_2d && CI=true flutter test --concurrency=1 2>&1 | tail -3   # 82
```

Write both counts into the ledger.

- [ ] **Step 2: Write the failing predicate tests**

`test/geometry/band_predicates_test.dart`. Every fixture is transformed by
a non-identity placement — `Transform2.translation(300, -200)
.multiply(Transform2.rotation(math.pi / 6)).multiply(Transform2.scale(1.5, 1.5))`
— and every band is placed in **world** space where the transformed geometry
lands. Helper:

```dart
final placement = Transform2.translation(300, -200)
    .multiply(Transform2.rotation(math.pi / 6))
    .multiply(Transform2.scale(1.5, 1.5));

GeometryPayload pl(List<double> coords, [List<double> scalars = const []]) =>
    GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars));

Vector2 w(double x, double y) => placement.transformPoint(Vector2(x, y));

/// A band around [centre] with half-size [h], in world space.
Aabb2 bandAt(Vector2 centre, double h) =>
    Aabb2.raw(centre.x - h, centre.y - h, centre.x + h, centre.y + h);
```

Tests (each a `test(...)`):

1. `'a line is touched when the band crosses it and not when it sits beside it'`:
   line `[0,0, 10,0]`; band at `w(5,0)` half 1 → true; band at `w(5,3)` half 1
   → false (the band's own AABB overlaps nothing there under rotation either
   — check the assertion by computing `bandAt(w(5,3),1)`).
2. `'a band fully inside a closed polyline touches nothing'`: square
   `[0,0, 10,0, 10,10, 0,10, 0,0]`; band at `w(5,5)` half 1 → false; band at
   `w(0,5)` half 1 → true.
3. `'a circle is touched on its rim, not in its interior'`: circle `[0,0]`
   scalars `[10]`; band at `w(0,0)` half 2 → false; band at `w(10,0)` half 2
   → true; band enclosing the whole circle → true (`circleClipWindows == -1`).
4. `'an arc is touched only on its sweep'`: arc `[0,0]` scalars
   `[10, 0, math.pi/2]` (quarter, 0..90°); band at `w(10,0)` half 1 → true;
   band at `w(-10,0)` half 1 → false (the full circle would hit).
5. `'a point is touched when inside'`: point `[3,4]`; band at `w(3,4)` half
   0.5 → true; band at `w(6,4)` half 0.5 → false.
6. `'a text is touched on its oriented box edges, through textBoxOf'`: use
   `resolveTextAttributes`-driven `textBoxOf` with the `InsertionPointMeasurer`
   replaced by a fake `TextMeasurer` returning `advanceWidth 20, ascent 8,
   descent 2, capHeight 7` and a `TextStyleRecord` with `fixedHeight: 0`;
   payload `[0,0]` scalars `[5]` (height 5), rotation 0; band on the box's
   right edge → true; band well inside the box → false; band left of the
   box → false.
7. `'boxEnclosedByBand is inclusive on the edge and false when straddling'`.

Under the ×10-widen or swapped-predicate mutants of Task 2 these are the
leaf-level truth; keep the assertions tight (half-sizes of 1–2 units).

- [ ] **Step 3: Run, expect compile failure**

```sh
cd packages/jet_cad_2d && CI=true dart test test/geometry/band_predicates_test.dart
```

- [ ] **Step 4: Implement `band_predicates.dart`**

```dart
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import '../document/tables.dart' show TextStyleRecord;
import '../document/text_geometry.dart';
import '../document/text_metrics.dart';
import '../store/entity_store.dart' show EntityKind;
import '../store/geometry_store.dart';
import 'aabb2.dart';
import 'primitives.dart' show angleInSweep;
import 'segment_clip.dart';
import 'transform2.dart';

/// The oriented glyph box of a text or attrib in the leaf's own space.
final class TextBox {
  const TextBox(this.minX, this.minY, this.maxX, this.maxY, this.local);
  final double minX, minY, maxX, maxY;
  /// Box space → leaf space (`textLocalTransform`).
  final Transform2 local;
}

TextBox? textBoxOf(GeometryPayload payload, int textAttrs,
    TextStyleRecord style, TextMetrics metrics) {
  final attrs = resolveTextAttributes(payload, textAttrs, style);
  final box = textLocalBounds(attrs, metrics);
  if (box.maxX <= box.minX || box.maxY <= box.minY) return null;
  final local = textLocalTransform(attrs, metrics, payload.pointAt(0));
  return TextBox(box.minX, box.minY, box.maxX, box.maxY, local);
}

bool boxEnclosedByBand(Aabb2 worldBox, Aabb2 band) =>
    !worldBox.isEmpty &&
    worldBox.minX >= band.minX &&
    worldBox.maxX <= band.maxX &&
    worldBox.minY >= band.minY &&
    worldBox.maxY <= band.maxY;

/// Scratch for [clipSegment]'s `t` pair and [circleClipWindows]'s windows.
final Float64List _t = Float64List(2);
final Float64List _windows = Float64List(8);

bool _segmentTouches(double x0, double y0, double x1, double y1, Aabb2 band) =>
    clipSegment(x0, y0, x1, y1, band, _t);

bool leafTouchedByBand(EntityKind kind, GeometryPayload payload, double ta,
    double tb, double tc, double td, double te, double tf, Aabb2 band,
    {TextBox? textBox}) {
  final c = payload.coords;
  final n = payload.pointCount;
  if (n == 0 && kind != EntityKind.text && kind != EntityKind.attrib) {
    return false; // a fill has no coordinates and is never picked (spec D8)
  }
  switch (kind) {
    case EntityKind.point:
      final wx = ta * c[0] + tc * c[1] + te, wy = tb * c[0] + td * c[1] + tf;
      return wx >= band.minX && wx <= band.maxX && wy >= band.minY && wy <= band.maxY;
    case EntityKind.line:
    case EntityKind.polyline:
      if (n == 1) {
        final wx = ta * c[0] + tc * c[1] + te, wy = tb * c[0] + td * c[1] + tf;
        return band.containsPoint(Vector2(wx, wy));
      }
      var px = ta * c[0] + tc * c[1] + te, py = tb * c[0] + td * c[1] + tf;
      for (var i = 1; i < n; i++) {
        final lx = c[i * 2], ly = c[i * 2 + 1];
        final qx = ta * lx + tc * ly + te, qy = tb * lx + td * ly + tf;
        if (_segmentTouches(px, py, qx, qy, band)) return true;
        px = qx; py = qy;
      }
      return false;
    case EntityKind.circle:
      final cx = ta * c[0] + tc * c[1] + te, cy = tb * c[0] + td * c[1] + tf;
      final r = payload.scalars[0] * _scaleMagnitude(ta, tb, tc, td);
      return circleClipWindows(cx, cy, r, band, _windows) != 0;
    case EntityKind.arc:
      final cx = ta * c[0] + tc * c[1] + te, cy = tb * c[0] + td * c[1] + tf;
      final r = payload.scalars[0] * _scaleMagnitude(ta, tb, tc, td);
      // World start angle from the transformed start point; a mirror flips
      // the turning sense — the same rule `_considerLeaf` uses for arcs.
      final s0 = payload.scalars[1], sweep0 = payload.scalars[2];
      final lsx = c[0] + payload.scalars[0] * math.cos(s0);
      final lsy = c[1] + payload.scalars[0] * math.sin(s0);
      final wsx = ta * lsx + tc * lsy + te, wsy = tb * lsx + td * lsy + tf;
      final start = math.atan2(wsy - cy, wsx - cx);
      final sweep = (ta * td - tb * tc) < 0 ? -sweep0 : sweep0;
      final count = circleClipWindows(cx, cy, r, band, _windows);
      if (count == -1) return true;
      for (var i = 0; i < count; i++) {
        final a = _windows[i * 2], b = _windows[i * 2 + 1];
        // A window intersects the sweep when an endpoint of either lies in
        // the other, or the window contains the sweep's start.
        if (angleInSweep(a, start, sweep) ||
            angleInSweep(b, start, sweep) ||
            _angleInWindow(start, a, b)) {
          return true;
        }
      }
      return false;
    case EntityKind.text:
    case EntityKind.attrib:
      final box = textBox;
      if (box == null) return false;
      // Compose leaf→world with box→leaf, then walk the four edges.
      final l = box.local;
      final ma = ta * l.a + tc * l.b, mb = tb * l.a + td * l.b;
      final mc = ta * l.c + tc * l.d, md = tb * l.c + td * l.d;
      final me = ta * l.e + tc * l.f + te, mf = tb * l.e + td * l.f + tf;
      double xOf(double x, double y) => ma * x + mc * y + me;
      double yOf(double x, double y) => mb * x + md * y + mf;
      final xs = [box.minX, box.maxX, box.maxX, box.minX];
      final ys = [box.minY, box.minY, box.maxY, box.maxY];
      for (var i = 0; i < 4; i++) {
        final j = (i + 1) % 4;
        if (_segmentTouches(xOf(xs[i], ys[i]), yOf(xs[i], ys[i]),
            xOf(xs[j], ys[j]), yOf(xs[j], ys[j]), band)) {
          return true;
        }
      }
      return false;
    case EntityKind.fill:
      return false;
  }
}

bool _angleInWindow(double angle, double a, double b) {
  const twoPi = 2 * math.pi;
  var d = (angle - a) % twoPi;
  if (d < 0) d += twoPi;
  return d <= b - a;
}

double _scaleMagnitude(double a, double b, double c, double d) =>
    math.sqrt((a * d - b * c).abs());

bool leafTouchedByBandT(EntityKind kind, GeometryPayload payload,
        Transform2 t, Aabb2 band, {TextBox? textBox}) =>
    leafTouchedByBand(kind, payload, t.a, t.b, t.c, t.d, t.e, t.f, band,
        textBox: textBox);
```

(`import 'dart:math' as math;` at the top.) The four `List<double>`s in the
text branch allocate; that branch runs at pointer-up rate, which the spec
allows. If `flutter analyze` on the flutter package later flags the
`hide Aabb2` import as unused here, drop the `hide`.

Add to `lib/jet_cad_2d.dart`: `export 'src/geometry/band_predicates.dart';`.

- [ ] **Step 5: Run the tests, then the package gate line**

```sh
cd packages/jet_cad_2d && CI=true dart test test/geometry/band_predicates_test.dart
CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
```

- [ ] **Step 6: Commit**

```sh
git add lib/src/geometry/band_predicates.dart lib/jet_cad_2d.dart test/geometry/band_predicates_test.dart
git commit -m "feat(geometry): band predicates, exact per entity kind"
```

---

### Task 2: `forEachLeafInBand` and `forEachInstanceInBand`

**Files:**
- Modify: `lib/src/index/spatial_index.dart` (after `forEachInstanceInRect`, before the pick section)
- Test: `test/index/band_query_test.dart`

**Interfaces:**
- Consumes: Task 1's predicates; `ContainerIndex.searchLeaves/searchInstances/boxOfLeaf/dirty/transformOfLeaf/transformOfInstance`; `_filters`, `_beginQuery/_endQuery`, `_scratch`, `_instanceScratch`, `_scratchForDepth`, `_localQueryBox`, `_composeLeafTransform` and `_lta.._ltf`, `_broadPhaseMargin()`, `_textLayout`-style text access (via `document.textMeasurer`).
- Produces (spec D8):

```dart
enum BandMode { window, crossing }
void forEachLeafInBand(Aabb2 world, BandMode mode, QueryFilter filter, void Function(int slot) visit);
void forEachInstanceInBand(Aabb2 world, BandMode mode, QueryFilter filter, void Function(Handle instance) visit);
```

- [ ] **Step 1: Write the failing tests**

`test/index/band_query_test.dart`, reusing `addEntity` from `pick_test.dart`
(copy the helper; do not import a test file). Every document is built with
`DraftDocument.empty()`; instances via `AddNodeCommand(InstanceNode(...))`
at `placement` from Task 1; groups via `AddNodeCommand(GroupNode(...))`.

1. **M-02a / M-02g truth** — `'window keeps only the enclosed line; crossing adds the straddler'`:
   three root lines at world `y = 1000`: inside `[100,1000, 120,1000]`,
   straddling `[190,1000, 230,1000]`, outside `[300,1000, 320,1000]`; band
   `Aabb2.raw(90, 990, 200, 1010)`. Window visits `{inside}`, crossing
   `{inside, straddling}`, in ascending handle order.
2. **M-02b** — `'an instance is selected where its leaf lands after the transform'`:
   definition with line `[0,0, 10,0]`; instance at `placement`; a crossing
   band around `placement.transformPoint(Vector2(5, 0))` half 1 visits the
   instance; the same band at raw `(5, 0)` visits nothing.
3. **M-02o** — `'an L-shaped block is not crossed by a band in the empty quadrant of its box'`:
   definition with lines `[0,0, 10,0]` and `[0,0, 0,10]`; instance at
   `Transform2.translation(500, 700)` composed with a 30° rotation and ×1.5;
   band at the world image of local `(7, 7)` half 1 → crossing visits
   nothing; band at the image of `(5, 0)` → visits the instance.
4. **M-02s** — `'the window band sees a leaf edited since the last rebuild'`:
   the M-02a fixture; `SetEntityGeometryCommand(straddler, pl([100,1020,
   120,1020]))` moves the straddler inside; **no** rebuild; window visits
   `{inside, straddler}`.
5. **M-02t** — `'a grouped leaf inside a definition uses the group transform too'`:
   definition `def`; `GroupNode(handle: g, parent: def, transform:
   Transform2.translation(40, 0))` added via `AddNodeCommand`; leaf
   `addEntity(doc, g, line, [0,0, 10,0])`; instance of `def` at
   `placement`; band around `placement.transformPoint(Vector2(45, 0))` half
   1 → visits the instance; band around `placement.transformPoint(Vector2(5,
   0))` → nothing.
6. **M-02u** — `'a fill slot is never reported'`: `AddRegionCommand.allocate`
   (copy the `region()` helper's arguments from
   `test/document/region_command_test.dart`, with `squareLoop()` from
   there); crossing band on the boundary's edge visits the **boundary
   slot only**; window band enclosing the region visits the boundary only.
7. **M-02z** — `'results are ascending by handle even when the tree order differs'`:
   add lines with handles allocated in the order `c, a, b` (three
   `doc.handleSeed.next()` calls taken first, then `AddEntityCommand`s in
   the order 3rd, 1st, 2nd) at x positions that put them in a different
   R-tree leaf order; assert the visit sequence is ascending.
8. **Reentrancy** — `'a nested query inside the band visitor throws'`:
   `expect(() => index.forEachLeafInBand(..., (s) => index.forEachInRect(...)), throwsA(isA<QueryReentrancyError>()))`.
9. **Filter** — `'a locked layer is skipped under picking, kept under all'`:
   put one line on a locked layer (`LayerRecord(..., locked: true)` via
   `doc.tables.layers.put`); `QueryFilter.picking()` skips it,
   `QueryFilter.all()` reports it.
10. **Differential** (spec, Testing) — `'crossing and window agree with the brute-force arm on the generated corpus'`:

```dart
final doc = generateDocument(400,
    definitionCount: 8, instanceCount: 40, nestingDepth: 2,
    mirroredFraction: 0.2, nonUniformFraction: 0.3, groupCount: 6);
final index = SpatialIndex(doc);
addTearDown(index.dispose);
final ext = doc.extents;
final rng = math.Random(0xBAD5EED);
for (var trial = 0; trial < 12; trial++) {
  final cx = ext.minX + rng.nextDouble() * (ext.maxX - ext.minX);
  final cy = ext.minY + rng.nextDouble() * (ext.maxY - ext.minY);
  final hw = 5 + rng.nextDouble() * 200, hh = 5 + rng.nextDouble() * 200;
  final band = Aabb2.raw(cx - hw, cy - hh, cx + hw, cy + hh);
  for (final mode in BandMode.values) {
    final leaves = <int>[];
    index.forEachLeafInBand(band, mode, const QueryFilter.all(), leaves.add);
    final instances = <Handle>[];
    index.forEachInstanceInBand(band, mode, const QueryFilter.all(), instances.add);
    final brute = bruteForce(doc, band, mode);   // Ruling 02-6, below
    expect(leaves.toSet(), brute.leaves, reason: '$mode trial $trial');
    expect(instances.toSet(), brute.instances, reason: '$mode trial $trial');
    expect(leaves, orderedEquals(leaves.toList()..sort((a, b) =>
        doc.entities.handleAt(a).value.compareTo(doc.entities.handleAt(b).value))));
  }
}
```

`bruteForce`: for every live root-container slot (owner is the root or a
group whose ancestors reach the root without passing an instance),
compute the leaf's world `Transform2` (`tree.accumulatedTransform(owner)`
for a group owner, identity for the root), window → `entityBounds(...)
.transformedBy(t)` enclosed; crossing → `leafTouchedByBandT`. For every
root-level `InstanceNode`, recurse into its definition's leaves and child
nodes with `t.multiply(node.transform)` (and `accumulatedTransform` for
groups inside the definition), window → every leaf's box enclosed and at
least one leaf, crossing → any leaf touched. Skip `EntityKind.fill`
everywhere. Text boxes via `textBoxOf` with `doc.textMeasurer`.

- [ ] **Step 2: Run, expect failure**

```sh
cd packages/jet_cad_2d && CI=true dart test test/index/band_query_test.dart
```

- [ ] **Step 3: Implement**

In `spatial_index.dart`, import `../geometry/band_predicates.dart`, add
`enum BandMode { window, crossing }` above the class, and inside the class
after `forEachInstanceInRect`:

```dart
  // --- band selection (spec 02, D8) ----------------------------------

  /// Root-container leaves the band selects, ascending handle order, each
  /// slot once, fills skipped. Window: the leaf's world box (tree, else
  /// dirty overlay) is enclosed. Crossing: some point of its stroke lies
  /// inside, tested after a broad phase widened by the pick margin.
  void forEachLeafInBand(Aabb2 world, BandMode mode, QueryFilter filter,
      void Function(int slot) visit) {
    final root = rootIndex;
    if (world.isEmpty) return;
    _beginQuery();
    try {
      _scratch.reset();
      final query = mode == BandMode.crossing
          ? world.expandedBy(_broadPhaseMargin().pick)
          : world;
      root.searchLeaves(query, (slot) {
        if (!_filters.acceptsEntity(slot, filter)) return;
        if (document.entities.kindAt(slot) == EntityKind.fill) return;
        if (_scratchContains(slot)) return; // tree and overlay may both report it
        if (_leafPasses(root, Transform2.identity(), slot, mode, world)) {
          _scratch.add(slot);
        }
      });
      _scratch.sortByHandle(document.entities);
      for (var i = 0; i < _scratch.length; i++) {
        visit(_scratch[i]);
      }
    } finally {
      _endQuery();
    }
  }

  /// Root-level instances the band selects, ascending, descending into the
  /// definition: window when every member leaf is enclosed (and there is at
  /// least one), crossing when any member leaf is touched.
  void forEachInstanceInBand(Aabb2 world, BandMode mode, QueryFilter filter,
      void Function(Handle instance) visit) {
    final root = rootIndex;
    if (world.isEmpty) return;
    _beginQuery();
    try {
      _instanceScratch.reset();
      // Window must consider every root instance: one whose box straddles
      // the band fails on its own, and one wholly inside is found either
      // way. The all box keeps the two walks on one rule (`_bandDescend`).
      final query = mode == BandMode.crossing
          ? world.expandedBy(_broadPhaseMargin().pick)
          : _kAllBox;
      final level = _scratchForDepth(0)..reset();
      root.searchInstances(query, (node) {
        if (_filters.acceptsNode(node, filter)) level.add(node.value);
      });
      for (var i = 0; i < level.length; i++) {
        final node = Handle(level[i]);
        final resolved = document.tree[node];
        if (resolved is! InstanceNode) continue;
        final child = _byContainer[resolved.definition];
        if (child == null) continue;
        _containerPath[0] = root.container.value;
        final r = _bandDescend(child, root.transformOfInstance(node), mode,
            world, filter, 1);
        if (r == _BandVerdict.pass) _instanceScratch.add(node.value);
      }
      _instanceScratch.sortByValue();
      for (var i = 0; i < _instanceScratch.length; i++) {
        visit(Handle(_instanceScratch[i]));
      }
    } finally {
      _endQuery();
    }
  }
```

Helpers, private, below:

```dart
  bool _scratchContains(int slot) {
    for (var i = 0; i < _scratch.length; i++) {
      if (_scratch[i] == slot) return true;
    }
    return false;
  }

  /// One leaf against the band, in world space. [toWorld] is the container's
  /// placement; the leaf's own flattened-group transform is composed on top,
  /// exactly as [_descend] does at its leaf visitor.
  bool _leafPasses(ContainerIndex index, Transform2 toWorld, int slot,
      BandMode mode, Aabb2 world) {
    _composeLeafTransform(toWorld, index.transformOfLeaf(slot));
    final kind = document.entities.kindAt(slot);
    final payload = document.geometry.peek(document.entities.geomIndexAt(slot));
    if (mode == BandMode.window) {
      final local = index.boxOfLeaf(slot) ?? index.dirty.boxOf(slot);
      if (local == null || local.isEmpty) return false;
      // Boxes are stored in the container's space; lift to world.
      final box = toWorld.isIdentity
          ? local
          : local.transformedBy(toWorld);
      return boxEnclosedByBand(box, world);
    }
    TextBox? textBox;
    if (kind == EntityKind.text || kind == EntityKind.attrib) {
      final style = document.textStyleOf(document.entities.textStyleAt(slot));
      final metrics = document.textMeasurer
          .measure(text: document.entities.textAt(slot), style: style);
      textBox = textBoxOf(
          payload, document.entities.textAttrsAt(slot), style, metrics);
    }
    return leafTouchedByBand(kind, payload, _lta, _ltb, _ltc, _ltd, _lte,
        _ltf, world, textBox: textBox);
  }

  /// Window: `pass` only if every member leaf under this container is
  /// enclosed and at least one exists (nested instances must pass too);
  /// crossing: `pass` on the first leaf that is touched.
  ///
  /// **Window walks the whole container, not the band's local box.** A leaf
  /// the local box does not find lies outside the band and therefore fails
  /// window on its own; an every-leaf rule that only saw the box's subset
  /// would pass a container half outside the band.
  _BandVerdict _bandDescend(ContainerIndex index, Transform2 toWorld,
      BandMode mode, Aabb2 world, QueryFilter filter, int depth) {
    _ensurePathCapacity(depth);
    _containerPath[depth] = index.container.value;
    final Transform2 toLocal;
    try {
      toLocal = toWorld.invert();
    } on SingularTransformError {
      return _BandVerdict.empty;
    }
    final Aabb2 localQuery;
    if (mode == BandMode.window) {
      localQuery = _kAllBox;
    } else {
      localQuery = _localBandBox(toLocal, world.expandedBy(_broadPhaseMargin().pick));
    }
    var anyLeaf = false;
    var allPass = true;
    var anyPass = false;
    index.searchLeaves(localQuery, (slot) {
      if (!_filters.acceptsEntity(slot, filter)) return;
      if (document.entities.kindAt(slot) == EntityKind.fill) return;
      if (mode == BandMode.crossing && anyPass) return;
      anyLeaf = true;
      if (_leafPasses(index, toWorld, slot, mode, world)) {
        anyPass = true;
      } else {
        allPass = false;
      }
    });
    if (mode == BandMode.crossing && anyPass) return _BandVerdict.pass;
    if (mode == BandMode.window && anyLeaf && !allPass) return _BandVerdict.fail;

    final level = _scratchForDepth(depth)..reset();
    index.searchInstances(localQuery, (node) {
      if (_filters.acceptsNode(node, filter)) level.add(node.value);
    });
    var childPass = false;
    for (var i = 0; i < level.length; i++) {
      final node = Handle(level[i]);
      final resolved = document.tree[node];
      if (resolved is! InstanceNode) continue;
      final child = _byContainer[resolved.definition];
      if (child == null) continue;
      var cyclic = false;
      for (var d = 0; d <= depth; d++) {
        if (_containerPath[d] == child.container.value) {
          cyclic = true;
          break;
        }
      }
      if (cyclic) continue;
      final r = _bandDescend(child,
          toWorld.multiply(index.transformOfInstance(node)), mode, world,
          filter, depth + 1);
      if (mode == BandMode.crossing) {
        if (r == _BandVerdict.pass) return _BandVerdict.pass;
      } else {
        if (r == _BandVerdict.fail) return _BandVerdict.fail;
        if (r == _BandVerdict.pass) childPass = true;
      }
    }
    if (mode == BandMode.crossing) return _BandVerdict.fail;
    return (anyLeaf && allPass) || childPass
        ? _BandVerdict.pass
        : _BandVerdict.empty;
  }

  /// Every container-space box; window mode walks the whole container.
  static final Aabb2 _kAllBox = Aabb2.raw(
      -double.maxFinite, -double.maxFinite, double.maxFinite, double.maxFinite);
```

The same-depth scratch reuse is safe: `_scratchForDepth(depth)` is consumed
by the loop before any recursion at `depth + 1` reads its own. In
`forEachInstanceInBand`, `root.searchInstances` uses `_kAllBox` for window
and the widened band for crossing, the same rule.

`_localBandBox(Transform2 toLocal, Aabb2 world)` is `_localQueryBox`'s
four-corner pullback applied to a rectangle instead of a point ± half-size;
write it beside `_localQueryBox`.

```dart
enum _BandVerdict { pass, fail, empty }
```

`empty` (no leaves anywhere under the container) is treated as `fail` by the
callers — a container with no member leaves is never band-selected (spec
D8).

- [ ] **Step 4: Run the tests until green, then the gate line**

```sh
cd packages/jet_cad_2d && CI=true dart test test/index/band_query_test.dart
CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
```

`query_allocation_test.dart` must still pass unedited — it does not call the
band walks, but the file was touched.

- [ ] **Step 5: Commit**

```sh
git add lib/src/index/spatial_index.dart test/index/band_query_test.dart
git commit -m "feat(index): window and crossing band walks, descending into instances"
```

---

### Task 3: `SelectionKey`, `resolveHit`, `SelectionController`

**Files:**
- Create: `lib/src/selection.dart`
- Create: `test/support/selection_fixture.dart`
- Test: `test/selection_test.dart`

**Interfaces:**
- Consumes: `HitPath`, `DraftDocument` (`tree`, `entities.slotOf`, `changes`), `DocChange` subtypes.
- Produces (spec D6, D2, D11):

```dart
final class SelectionKey {
  SelectionKey({required Uint32List chain, required int chainLength, required Handle target});
  SelectionKey.root(Handle target);           // chain = []
  final Uint32List chain; final Handle target;
}
SelectionKey? resolveHit(HitPath hit, DraftDocument document);   // null on a miss or a truncated hit
class SelectionController extends ChangeNotifier {
  SelectionController(DraftDocument document);
  Set<SelectionKey> get keys; int get length; bool get isEmpty;
  bool contains(SelectionKey key);
  void replace(Iterable<SelectionKey> keys); void toggle(Iterable<SelectionKey> keys);
  void remove(Iterable<SelectionKey> keys); void clear();
  SelectionKey? get hover; void setHover(SelectionKey? key);
  @override void dispose();   // cancels the changes subscription
}
```

- [ ] **Step 1: The fixture file**

`test/support/selection_fixture.dart`: `addEntity` (copied from
`pick_test.dart`), `addInstance(doc, def, Transform2)`, `addGroup(doc,
parent, Transform2)`, `addDefinition(doc, name)`, `kPlacement` (the reference
placement), `cameraAt(scale, translation)` returning a `CameraController`
over `ViewportTransform(worldToScreenMatrix: Transform2(s, 0, 0, -s, tx,
ty))`, and `twoInstancesOfOneDefinition(doc)` returning `(def, a, b, leaf)`
with `a` at `kPlacement` and `b` at `Transform2.translation(900, 400)
.multiply(Transform2.rotation(-math.pi / 4)).multiply(Transform2.scale(0.8, 0.8))`.

- [ ] **Step 2: Failing tests**

`test/selection_test.dart`:

1. **M-02c′** — `'two instances of one definition are two keys; two leaves of one instance are one'`:
   pick under `a` and under `b` through `SpatialIndex.pickInto` at the
   world image of the leaf's midpoint; `resolveHit` each; both `target`s are
   `InstanceNode`s per `doc.tree[target]`; `replace([ka]); toggle([kb])`;
   `length == 2`. Then a second leaf in the definition, picked under `a`,
   resolves to a key `== ka`.
2. **M-02p** — `'a leaf owned by a nested group resolves to the outer group; a single-level group to itself'`:
   `outer` under root, `inner` under `outer`, leaf owned by `inner` →
   `target == outer`; leaf owned by a group directly under root → that
   group.
3. `'a truncated hit is a miss'`: build a `HitPath(2)` by hand with
   `truncated = true`, `chainLength = 2`, `entity` a real leaf → `null`.
4. **M-02k and its sibling** — `'an external remove prunes; an unrelated add does not'`:
   select a leaf and an instance; `execute(RemoveEntityCommand(leaf))`;
   `await Future<void>.delayed(Duration.zero)`; only the instance remains;
   then `execute(AddEntityCommand(...))` elsewhere; still there.
5. **M-02aa** — `'replace with the same set does not notify'`: counter
   listener; `replace([k])` twice → 1; `setHover(k)` twice → 1 more.
6. `'toggle adds then removes'`, `'remove drops only what it names'`,
   `'clear drops hover too'`, `'DocumentLoaded clears everything'` (emit by
   loading: `doc.commands` has no public emitter — use
   `JsonCodec`-free path: call `SelectionController`'s private handler
   through a `@visibleForTesting void debugOnChange(DocChange)`).
7. `'equality is by chain and target, not identity'`: two keys built from
   separate buffers with the same contents are `==` and share a hash.

- [ ] **Step 3: Implement `selection.dart`**

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

final class SelectionKey {
  SelectionKey({required Uint32List chain, required int chainLength, required this.target})
      : chain = Uint32List.fromList(Uint32List.sublistView(chain, 0, chainLength));

  SelectionKey.root(this.target) : chain = Uint32List(0);

  final Uint32List chain;
  final Handle target;

  @override
  bool operator ==(Object other) {
    if (other is! SelectionKey || other.target != target) return false;
    if (other.chain.length != chain.length) return false;
    for (var i = 0; i < chain.length; i++) {
      if (other.chain[i] != chain[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(chain), target);

  @override
  String toString() => 'SelectionKey(${chain.join('>')} ${target.toHex()})';
}

/// Spec D2: the root-level object under a hit, or null for a miss or a
/// truncated chain. Never throws at hover rate.
SelectionKey? resolveHit(HitPath hit, DraftDocument document) {
  if (hit.entity.isNone || hit.truncated) return null;
  if (hit.chainLength > 0) return SelectionKey.root(Handle(hit.chain[0]));
  final slot = document.entities.slotOf(hit.entity);
  if (slot == null) return null;
  final owner = document.entities.ownerAt(slot);
  if (owner == document.rootHandle) return SelectionKey.root(hit.entity);
  final List<Handle> ancestors;
  try {
    ancestors = document.tree.ancestorsOf(owner);
  } on NodeCycleError {
    return SelectionKey.root(hit.entity);
  }
  return SelectionKey.root(topmostGroupOf(document, owner, ancestors) ?? hit.entity);
}

/// The last group in `[owner, ...ancestors]` before the root, or null when
/// none is a group. [ancestors] is `tree.ancestorsOf(owner)`, nearest first.
Handle? topmostGroupOf(DraftDocument document, Handle owner, List<Handle> ancestors) {
  Handle? topmost;
  for (final h in [owner, ...ancestors]) {
    if (h == document.rootHandle) break;
    if (document.tree[h] is GroupNode) topmost = h;
  }
  return topmost;
}

class SelectionController extends ChangeNotifier {
  SelectionController(this.document) {
    _subscription = document.changes.listen(_onChange);
  }

  final DraftDocument document;
  final Set<SelectionKey> _keys = <SelectionKey>{};
  SelectionKey? _hover;
  late final StreamSubscription<DocChange> _subscription;

  Set<SelectionKey> get keys => UnmodifiableSetView(_keys);
  int get length => _keys.length;
  bool get isEmpty => _keys.isEmpty;
  bool contains(SelectionKey key) => _keys.contains(key);
  SelectionKey? get hover => _hover;

  void replace(Iterable<SelectionKey> next) {
    final incoming = next.toSet();
    if (setEquals(incoming, _keys)) return;
    _keys..clear()..addAll(incoming);
    notifyListeners();
  }

  void toggle(Iterable<SelectionKey> keys) {
    var changed = false;
    for (final k in keys) {
      changed = true;
      if (!_keys.remove(k)) _keys.add(k);
    }
    if (changed) notifyListeners();
  }

  void remove(Iterable<SelectionKey> keys) {
    var changed = false;
    for (final k in keys) {
      changed = _keys.remove(k) || changed;
    }
    if (changed) notifyListeners();
  }

  void clear() {
    if (_keys.isEmpty && _hover == null) return;
    _keys.clear();
    _hover = null;
    notifyListeners();
  }

  void setHover(SelectionKey? key) {
    if (key == _hover) return;
    _hover = key;
    notifyListeners();
  }

  @visibleForTesting
  void debugOnChange(DocChange change) => _onChange(change);

  void _onChange(DocChange change) {
    if (change is DocumentLoaded || change is DocumentPurged) {
      clear();
      return;
    }
    var changed = false;
    _keys.removeWhere((k) {
      final dead = !_resolves(k);
      changed = changed || dead;
      return dead;
    });
    if (_hover != null && !_resolves(_hover!)) {
      _hover = null;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  bool _resolves(SelectionKey k) {
    for (final h in k.chain) {
      if (document.tree[Handle(h)] is! InstanceNode) return false;
    }
    return document.entities.slotOf(k.target) != null ||
        document.tree[k.target] != null;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run, gate line, commit**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_test.dart
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add lib/src/selection.dart test/selection_test.dart test/support/selection_fixture.dart
git commit -m "feat(selection): SelectionKey, resolveHit and SelectionController"
```

---

### Task 4: `Tool`, `ToolContext`, `ToolPointerEvent`, `ToolController`

**Files:**
- Create: `lib/src/tool.dart`
- Test: `test/tool_controller_test.dart`

**Interfaces:** exactly the Architecture block of the spec. `ToolContext`
also carries `void execute(DraftCommand)`.

- [ ] **Step 1: Failing tests** (criterion 7, spec M-02 none — the
  interface test): a `_CountingTool extends Tool` in the test file whose
  `cancel` increments a counter and whose `phase` is settable;
  `ToolController(initial: a, context: ctx)`; a listener counter on the
  controller; `a.notifyListeners()` → controller notified; `activate(b)` →
  `a.cancelCount == 1`, controller notified once more; `a.notifyListeners()`
  → **not** forwarded any more; `b.notifyListeners()` → forwarded;
  `dispose()` then `b.notifyListeners()` → nothing (no throw).

- [ ] **Step 2: Implement `tool.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show KeyEvent;
import 'package:flutter/widgets.dart' show KeyEventResult, Offset, Size, Canvas;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'camera_controller.dart';
import 'selection.dart';
import 'viewport_transform.dart';

final class ToolPointerEvent {
  const ToolPointerEvent({
    required this.screen, required this.world, required this.pointer,
    required this.buttons, required this.shift, required this.control,
    required this.meta, required this.alt, required this.pickRadiusWorld,
  });
  final Offset screen; final Vector2 world; final int pointer; final int buttons;
  final bool shift, control, meta, alt; final double pickRadiusWorld;
}

final class ToolContext {
  const ToolContext({required this.document, required this.index,
      required this.camera, required this.selection});
  final DraftDocument document; final SpatialIndex index;
  final CameraController camera; final SelectionController selection;
  void execute(DraftCommand command) => document.commands.execute(command);
}

enum ToolPhase { idle, pressed, dragging }

abstract class Tool extends ChangeNotifier {
  String get name;
  ToolPhase get phase;
  void onPointerDown(ToolPointerEvent e, ToolContext ctx);
  void onPointerMove(ToolPointerEvent e, ToolContext ctx);
  void onPointerUp(ToolPointerEvent e, ToolContext ctx);
  void onPointerExit(ToolContext ctx);
  KeyEventResult onKey(KeyEvent event, ToolContext ctx);
  void cancel(ToolContext ctx);
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport);
}

class ToolController extends ChangeNotifier {
  ToolController({required Tool initial, required this.context}) : _active = initial {
    _active.addListener(_forward);
  }
  final ToolContext context;
  Tool _active;
  Tool get active => _active;

  void activate(Tool next) {
    if (identical(next, _active)) return;
    _active.cancel(context);
    _active.removeListener(_forward);
    _active = next;
    _active.addListener(_forward);
    notifyListeners();
  }

  void _forward() => notifyListeners();

  @override
  void dispose() {
    _active.removeListener(_forward);
    super.dispose();
  }
}
```

- [ ] **Step 3: Run, gate line, commit**

```sh
git add lib/src/tool.dart test/tool_controller_test.dart
git commit -m "feat(tools): the Tool interface and ToolController"
```

---

### Task 5: `SelectTool` — hover, click, shift, band

**Files:**
- Create: `lib/src/select_tool.dart`
- Test: `test/select_tool_test.dart`

**Interfaces:**
- Consumes: Tasks 2–4; `SpatialIndex.pickInto`, `forEachLeafInBand`, `forEachInstanceInBand`; `document.leavesByOwner()`, `tree.childNodesOf`.
- Produces: `class SelectTool extends Tool`, `const double kBandSlopPixels = 4.0`, read-only `BandMode? get bandMode`, `Rect? get bandScreen` (for the overlay test), `Offset? get bandStart`.

Tests are driven with synthetic `ToolPointerEvent`s — no widgets. A helper
in the test file:

```dart
ToolPointerEvent ev(CameraController camera, Offset screen,
        {int buttons = kPrimaryButton, bool shift = false, int pointer = 1}) =>
    ToolPointerEvent(
      screen: screen,
      world: camera.value.screenToWorld(Vector2(screen.dx, screen.dy)),
      pointer: pointer, buttons: buttons, shift: shift, control: false,
      meta: false, alt: false,
      pickRadiusWorld: kPickRadiusPixels / camera.value.scale,
    );
```

(`kPickRadiusPixels` is defined in Task 9's file; until then declare
`const double kPickRadiusPixels = 6.0;` in `select_tool.dart` and move it in
Task 9.)

- [ ] **Step 1: Failing tests**

Camera: `cameraAt(scale: 2.0, translation: Offset(-1500, 900))` over a
document whose lines sit around world `(900..1100, 400..600)`; verify in a
first test that `screenOf(line midpoint)` lands inside a 800×600 surface.

1. `'hover sets the controller's hover and clears on a miss'`.
2. **M-02d** — `'the pick radius is six screen pixels'`: two parallel
   horizontal lines 30 screen px apart (world spacing `30 / scale`); down+up
   3 px from A → selected A; down+up 10 px from A → selection empty.
3. `'click replaces, shift-click toggles'` (**M-02h**): click A, click B →
   {B}; shift-click A → {A, B}; shift-click A → {B}.
4. `'click on empty space clears; shift-click on empty space does nothing'`.
5. **M-02f** — `'a 2 px move keeps the press a click'`: down on empty, move
   2 px → `phase == ToolPhase.pressed`; up → `phase == idle`, selection
   empty (the log records the second half as non-discriminating).
6. `'a 5 px move from empty space starts a band; from a hit it does not'`:
   → `dragging` vs `pressed`.
7. **M-02a at the tool level, both directions** — `'left-to-right encloses, right-to-left touches'`:
   the M-02a fixture in world; drag from left of `inside` to a point
   between `straddling`'s ends (band right edge through it) → {inside};
   the same corners dragged right-to-left → {inside, straddling}.
8. **M-02r** — `'a group is window-selected only when every leaf is enclosed'`:
   group with two leaves, band enclosing one; window → empty; crossing →
   {group}.
9. `'shift-band toggles'`.
10. `'Escape during a band drops it, selection untouched; cancel returns to idle'`
    — via `onKey(KeyDownEvent(...))` built with `KeyDownEvent(physicalKey:
    PhysicalKeyboardKey.escape, logicalKey: LogicalKeyboardKey.escape,
    timeStamp: Duration.zero)`.

- [ ] **Step 2: Implement `select_tool.dart`** (keys and Delete in Task 6;
  `onKey` returns `ignored` for now)

```dart
class SelectTool extends Tool {
  SelectTool();

  @override
  String get name => 'Select';
  ToolPhase _phase = ToolPhase.idle;
  @override
  ToolPhase get phase => _phase;

  final HitPath _hit = HitPath();
  Offset _start = Offset.zero;
  Vector2 _startWorld = Vector2.zero();
  SelectionKey? _downKey;
  bool _downHit = false;
  Offset _end = Offset.zero;
  BandMode? _bandMode;
  int _pointer = -1;

  BandMode? get bandMode => _phase == ToolPhase.dragging ? _bandMode : null;
  Rect? get bandScreen =>
      _phase == ToolPhase.dragging ? Rect.fromPoints(_start, _end) : null;

  SelectionKey? _pick(ToolPointerEvent e, ToolContext ctx) {
    if (!ctx.index.pickInto(e.world, e.pickRadiusWorld,
        const QueryFilter.picking(), _hit)) {
      return null;
    }
    return resolveHit(_hit, ctx.document);
  }

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    if (_phase != ToolPhase.idle) return;
    _phase = ToolPhase.pressed;
    _pointer = e.pointer;
    _start = e.screen;
    _startWorld.setFrom(e.world);
    _downKey = _pick(e, ctx);
    _downHit = _downKey != null;
    notifyListeners();
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    switch (_phase) {
      case ToolPhase.idle:
        if (e.buttons != 0) return;
        ctx.selection.setHover(_pick(e, ctx));
      case ToolPhase.pressed:
        if (e.pointer != _pointer) return;
        if ((e.screen - _start).distance < kBandSlopPixels) return;
        if (_downHit) return;
        _phase = ToolPhase.dragging;
        ctx.selection.setHover(null);
        _end = e.screen;
        _bandMode = _end.dx >= _start.dx ? BandMode.window : BandMode.crossing;
        notifyListeners();
      case ToolPhase.dragging:
        if (e.pointer != _pointer) return;
        _end = e.screen;
        _bandMode = _end.dx >= _start.dx ? BandMode.window : BandMode.crossing;
        notifyListeners();
    }
  }

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {
    if (e.pointer != _pointer) return;
    switch (_phase) {
      case ToolPhase.idle:
        return;
      case ToolPhase.pressed:
        final key = _downKey;
        if (key != null) {
          e.shift ? ctx.selection.toggle([key]) : ctx.selection.replace([key]);
        } else if (!e.shift) {
          ctx.selection.clear();
        }
      case ToolPhase.dragging:
        final keys = _bandKeys(ctx, e);
        e.shift ? ctx.selection.toggle(keys) : ctx.selection.replace(keys);
    }
    _reset();
    notifyListeners();
  }

  List<SelectionKey> _bandKeys(ToolContext ctx, ToolPointerEvent e) {
    final mode = _bandMode!;
    final a = _startWorld, b = e.world;
    final band = Aabb2.raw(math.min(a.x, b.x), math.min(a.y, b.y),
        math.max(a.x, b.x), math.max(a.y, b.y));
    final passing = <int>{};
    ctx.index.forEachLeafInBand(band, mode, const QueryFilter.picking(), passing.add);
    final keys = <SelectionKey>[];
    final seenGroups = <Handle>{};
    final doc = ctx.document;
    Map<Handle, List<int>>? byOwner;
    for (final slot in passing) {
      final owner = doc.entities.ownerAt(slot);
      if (owner == doc.rootHandle) {
        keys.add(SelectionKey.root(doc.entities.handleAt(slot)));
        continue;
      }
      final top = _topmostGroup(doc, owner);
      if (top == null || !seenGroups.add(top)) continue;
      byOwner ??= doc.leavesByOwner();
      if (mode == BandMode.crossing || _everyLeafIn(doc, top, byOwner, passing)) {
        keys.add(SelectionKey.root(top));
      }
    }
    ctx.index.forEachInstanceInBand(band, mode, const QueryFilter.picking(),
        (h) => keys.add(SelectionKey.root(h)));
    return keys;
  }

  /// Every leaf owned by [group] or a group nested in it is in [passing],
  /// and there is at least one.
  bool _everyLeafIn(DraftDocument doc, Handle group,
      Map<Handle, List<int>> byOwner, Set<int> passing) {
    var any = false;
    final stack = <Handle>[group];
    while (stack.isNotEmpty) {
      final g = stack.removeLast();
      for (final slot in byOwner[g] ?? const <int>[]) {
        if (doc.entities.kindAt(slot) == EntityKind.fill) continue;
        any = true;
        if (!passing.contains(slot)) return false;
      }
      final node = doc.tree[g];
      if (node is GroupNode) {
        for (final child in doc.tree.childNodesOf(node.children)) {
          if (doc.tree[child] is GroupNode) stack.add(child);
        }
      }
    }
    return any;
  }

  static Handle? _topmostGroup(DraftDocument doc, Handle owner) {
    final List<Handle> ancestors;
    try {
      ancestors = doc.tree.ancestorsOf(owner);
    } on NodeCycleError {
      return null;
    }
    return topmostGroupOf(doc, owner, ancestors);   // selection.dart
  }

  void _reset() {
    _phase = ToolPhase.idle;
    _pointer = -1;
    _downKey = null;
    _downHit = false;
    _bandMode = null;
  }

  @override
  void onPointerExit(ToolContext ctx) {
    ctx.selection.setHover(null);
    if (_phase == ToolPhase.dragging) cancel(ctx);
  }

  @override
  void cancel(ToolContext ctx) {
    if (_phase == ToolPhase.idle) return;
    _reset();
    notifyListeners();
  }

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) => KeyEventResult.ignored;

  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport) {
    final rect = bandScreen;
    if (rect == null) return;
    final crossing = _bandMode == BandMode.crossing;
    final color = crossing ? kCrossingBandColor : kWindowBandColor;
    canvas.drawRect(rect, Paint()..color = color.withAlpha(kBandFillAlpha));
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    if (!crossing) {
      canvas.drawRect(rect, stroke);
      return;
    }
    _drawDashedRect(canvas, rect, stroke);   // 6 on / 4 off, screen pixels
  }
}
```

The band-paint `Paint`s allocate per frame **while dragging only**; that is
the tool's preview, not the overlay's steady state, and the log records it
as accepted. `_drawDashedRect` walks the four edges with `Path.moveTo/lineTo`
in 6/4 steps. `selection_style.dart` is Task 7's; for Task 5 define
the two band colours and `kBandFillAlpha` there now (create the file with
just those three) so this compiles.

- [ ] **Step 3: Run, gate line, commit**

```sh
git add lib/src/select_tool.dart lib/src/selection_style.dart lib/src/selection.dart test/select_tool_test.dart
git commit -m "feat(tools): SelectTool hover, click, shift and band"
```

---

### Task 6: `SelectTool` — keys and Delete

**Files:**
- Modify: `lib/src/select_tool.dart`
- Test: `test/select_tool_test.dart` (a `group('keys and delete')`)

- [ ] **Step 1: Failing tests**

Build key events with
`KeyDownEvent(physicalKey: PhysicalKeyboardKey.delete, logicalKey: LogicalKeyboardKey.delete, timeStamp: Duration.zero)`
and the `KeyUpEvent`/`KeyRepeatEvent` twins.

1. `'Escape when idle clears'`.
2. **M-02x at tool level** — `'a KeyUpEvent and a KeyRepeatEvent do nothing'`:
   select two lines; send the up and the repeat for Delete → both still
   present, `onKey` returned `ignored`.
3. `'Delete removes a leaf and an instance through the log; undo restores geometry, not selection'`:
   `document.commands.undo()` twice → both present again, selection empty.
4. **M-02j** — `'Delete cascades a group: leaves, child instance, nested group, then the group'`:
   after Delete, all slots null, all nodes null; `document.commands.canUndo`.
5. `'a region inside a group is deleted once: the boundary's command takes the fill'`:
   group owning a boundary+fill pair (`AddRegionCommand.allocate(owner:
   group, ...)`); Delete → no `StateError`, both gone.
6. **M-02n** — `'a read-only document is selectable and Delete is a no-op'`:
   `DraftDocument.empty(permissions: DraftPermissions.readOnly)`; select;
   Delete → no throw, entity present, still selected.
7. `'a refused object stays selected, a permitted one goes'`:
   `DraftPermissions(transform: false, components: false, geometry: true,
   structure: false)`; select a leaf and an instance; Delete → leaf gone,
   instance present and still selected.

- [ ] **Step 2: Implement**

```dart
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_phase == ToolPhase.dragging) {
        cancel(ctx);
      } else if (_phase == ToolPhase.idle) {
        ctx.selection.clear();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      if (_phase != ToolPhase.idle) return KeyEventResult.ignored;
      _deleteSelection(ctx);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _deleteSelection(ToolContext ctx) {
    final doc = ctx.document;
    final permissions = doc.commands.permissions;
    final keys = ctx.selection.keys.toList()
      ..sort((a, b) => a.target.value.compareTo(b.target.value));
    Map<Handle, List<int>>? byOwner;
    for (final key in keys) {
      final List<DraftCommand> list;
      final node = doc.tree[key.target];
      if (node is GroupNode) {
        byOwner ??= doc.leavesByOwner();
        list = _groupCascade(doc, node, byOwner);
      } else if (node is InstanceNode) {
        list = [RemoveNodeCommand(key.target)];
      } else if (doc.entities.slotOf(key.target) != null) {
        list = [RemoveEntityCommand(key.target)];
      } else {
        continue;
      }
      if (!list.every((c) => permissions.allows(c.capability))) continue;
      for (final c in list) {
        ctx.execute(c);
      }
      ctx.selection.remove([key]);
    }
  }

  /// Leaves first (fills whose boundary is here skipped), child instances,
  /// nested groups recursively, the group last.
  List<DraftCommand> _groupCascade(
      DraftDocument doc, GroupNode group, Map<Handle, List<int>> byOwner) {
    final out = <DraftCommand>[];
    final leaves = byOwner[group.handle] ?? const <int>[];
    final boundaries = <Handle>{};
    for (final slot in leaves) {
      if (doc.entities.kindAt(slot) != EntityKind.fill) {
        boundaries.add(doc.entities.handleAt(slot));
      }
    }
    final skip = <Handle>{for (final b in boundaries) ...doc.fills.fillsOf(b)};
    for (final slot in leaves) {
      final h = doc.entities.handleAt(slot);
      if (skip.contains(h)) continue;
      out.add(RemoveEntityCommand(h));
    }
    for (final child in doc.tree.childNodesOf(group.children)) {
      final n = doc.tree[child];
      if (n is GroupNode) {
        out.addAll(_groupCascade(doc, n, byOwner));
      } else if (n is InstanceNode) {
        out.add(RemoveNodeCommand(child));
      }
    }
    out.add(RemoveNodeCommand(group.handle));
    return out;
  }
```

- [ ] **Step 3: Run, gate line, commit**

```sh
git add lib/src/select_tool.dart test/select_tool_test.dart
git commit -m "feat(tools): Escape and Delete on SelectTool, with the group cascade"
```

---

### Task 7: `selection_style.dart` and `OutlineCache`

**Files:**
- Modify: `lib/src/selection_style.dart` (the rest of the constants)
- Create: `lib/src/outline_cache.dart`
- Test: `test/outline_cache_test.dart`

**Read the review note's B2 first.** The path is built in **rebased**
space; the world geometry is kept as `Float64List`s.

**Interfaces:**

```dart
const Color kSelectionColor = Color(0xFF1E6FE8);
const Color kHoverColor = Color(0x991E6FE8);
const Color kWindowBandColor = Color(0xFF1E6FE8);
const Color kCrossingBandColor = Color(0xFF2E9E5B);
const int kBandFillAlpha = 0x22;
const double kSelectionStrokePixels = 2.0;
const double kHoverStrokePixels = 1.5;

class OutlineCache {
  OutlineCache(this.document, this.selection);   // listens to both selection and document.changes
  /// Rebuilds the rebased paths if [origin] differs from the tag; returns
  /// the path for [key] or null.
  Path? pathFor(SelectionKey key, Vector2 origin);
  Vector2 get origin;                          // the current tag
  @visibleForTesting Float64List? debugWorldSegmentsOf(SelectionKey key);
  void dispose();
}
```

The world record per key: a `List<_Outline>` where `_Outline` is one of
`_Segments(Float64List coords)` (polyline chain, `moveTo` first, `lineTo`
rest), `_Arc(cx, cy, r, start, sweep)` (a circle is `sweep = 2π`) — all in
**world** doubles. Building: `SelectionKey.target` → a leaf (its payload
through `transformOfLeaf`-composed world transform: use
`document.tree.accumulatedTransform(owner)` for a group owner, identity for
the root), a group (every owned leaf recursively, each through its owner's
accumulated transform), an instance (walk `definition.children` and
`leavesByOwner()[definition]` with `node.transform` composed, recursing into
nested instances and groups; the same every-leaf enumeration Task 6's
cascade uses, but through transforms). Circles and arcs under a non-uniform
transform: emit the transformed centre with `radius × scaleMagnitude` and
the world start angle from the transformed start point, sweep sign flipped
under a negative determinant — the pick's rule. Text: four corners via
`textBoxOf` and its `local` transform.

`pathFor`: if `origin != _origin`, for every key rebuild `Path()`: for
segments, `moveTo(x0 - ox, y0 - oy)` then `lineTo`; for arcs,
`addArc(Rect.fromCircle(center: Offset(cx - ox, cy - oy), radius: r),
start, sweep)`. Note `addArc` sweeps in **screen** angle sense under the
y-flip; the painter applies the world→screen transform to the whole path, so
the world angles are right here — the y-flip is in the matrix.

- [ ] **Step 1: Failing tests**

1. **M-02v** — `'the path is built in rebased space'`: a line from
   `(kDefaultOriginX + 10, 20)` to `(kDefaultOriginX + 110, 20)`; select;
   `origin = rebaseOriginFor(visibleWorld)` for a camera fitted around it;
   `pathFor(key, origin).getBounds()` has `left == 10 + (kDefaultOriginX -
   origin.x)` to 1e-6 — and, the discriminating half, `getBounds().left`
   is **not** within 0.25 of `kDefaultOriginX + 10` (a world-space path
   would put it there and float32 would round it).
2. `'the origin tag rebuilds once per change, not per call'`: a counter on
   rebuilds via `@visibleForTesting int debugRebuilds`; two `pathFor` calls
   with the same origin → 1; a new origin → 2.
3. **M-02w** — `'a DocChange inside a selected instance rebuilds the outline'`:
   select an instance; `SetEntityGeometryCommand` on a leaf in its
   definition; pump a microtask; `debugWorldSegmentsOf(key)` moved.
4. `'an instance outline composes the placement'`: instance at
   `kPlacement`; the segments equal `kPlacement.transformPoint` of the
   leaf's endpoints to 1e-9.
5. `'a grouped leaf inside a definition composes the group transform too'`.
6. `'a circle under a non-uniform instance scale is emitted with the geometric-mean radius'`.
7. `'keys dropped from the selection leave the cache'`.

- [ ] **Step 2: Implement, run, gate line, commit**

```sh
git add lib/src/selection_style.dart lib/src/outline_cache.dart test/outline_cache_test.dart
git commit -m "feat(overlay): the rebased outline cache and the selection style constants"
```

---

### Task 8: `SelectionOverlay`

**Files:**
- Create: `lib/src/selection_overlay.dart`
- Test: `test/selection_overlay_test.dart`

**Interfaces:**

```dart
class SelectionOverlay extends CustomPainter {
  SelectionOverlay({
    required SelectionController selection, required ToolController tools,
    required CameraController camera, required OutlineCache outlines,
    Listenable? repaint,            // the caller passes Listenable.merge([selection, tools, camera])
    void Function()? onPaintForTest,
  });
}
```

`paint(canvas, size)`:

```dart
    onPaintForTest?.call();
    final cam = camera.value;
    final origin = rebaseOriginFor(cam.visibleWorld(size));
    final m = cam.worldToScreenMatrix;
    // worldToScreen ∘ translate(origin): column-major 4x4.
    _matrix[0] = m.a; _matrix[1] = m.b; _matrix[4] = m.c; _matrix[5] = m.d;
    _matrix[12] = m.a * origin.x + m.c * origin.y + m.e;
    _matrix[13] = m.b * origin.x + m.d * origin.y + m.f;
    _selected.strokeWidth = kSelectionStrokePixels / cam.scale;
    _hover.strokeWidth = kHoverStrokePixels / cam.scale;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.transform(_matrix);
    for (final key in selection.keys) {
      final path = outlines.pathFor(key, origin);
      if (path != null) canvas.drawPath(path, _selected);
    }
    final hover = selection.hover;
    if (hover != null && !selection.contains(hover)) {
      final path = outlines.pathFor(hover, origin);
      if (path != null) canvas.drawPath(path, _hover);
    }
    canvas.restore();
    tools.active.paintOverlay(canvas, cam, size);
```

with fields `final Float64List _matrix = Float64List(16)..[10] = 1.0..[15] = 1.0;`
and the two `Paint`s (`style = stroke`, colours from the constants).
`shouldRepaint(old) => false`.

- [ ] **Step 1: Failing tests** — all on the same pumped tree, no rebuild
  between mutation and assertion:

```dart
await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Center(child: SizedBox(
  width: 400, height: 300,
  child: Stack(children: [
    RepaintBoundary(child: DraftCanvas(document: doc, index: index, camera: camera, onPaintForTest: () => canvasPaints++)),
    Positioned.fill(child: RepaintBoundary(child: CustomPaint(
      painter: SelectionOverlay(..., repaint: Listenable.merge([selection, tools, camera]), onPaintForTest: () => overlayPaints++),
      size: Size.infinite))),
  ])))));
```

1. **Criterion 6 / M-02e′** — `'a selection change repaints the overlay and not the canvas'`:
   record both counters; `selection.replace([k])`; `await tester.pump()`;
   overlay +1, canvas unchanged.
2. **M-02m** — `'stroke width is 2 px at any zoom'`: paint the overlay
   directly into a `SpyCanvas` at camera scale 4 → the `drawPath` call's
   `strokeWidth == 0.5`.
3. **M-02ab** — `'the two Paints are reused across frames'`: paint into a
   `SpyCanvas` twice; the `Paint` objects in `args` are `identical` across
   the two `drawPath` calls.
4. **M-02ac** — `'hover on a selected key draws once'`: select k, hover k,
   paint into a `SpyCanvas` → one `drawPath`; hover another key → two.
5. **Criterion 14** — `'the outline coincides with the drawn line at 4.5e6'`:
   the M-02v line; paint into a `SpyCanvas`; take the recorded `transform`
   matrix and the recorded path's bounds; map the bounds' corners through the
   matrix; compare with `camera.value.worldToScreen` of the line's endpoints
   → within 0.01 px.
6. `'the tool's band is painted after the outlines, in screen space'`:
   with `SelectTool` in `dragging` (drive it with two `ToolPointerEvent`s),
   the `SpyCanvas` shows `drawRect` after `restore`.

- [ ] **Step 2: Implement, run, gate line, commit**

```sh
git add lib/src/selection_overlay.dart test/selection_overlay_test.dart
git commit -m "feat(overlay): SelectionOverlay over the rebased cache"
```

---

### Task 9: `InteractionLayer`, and the exports

**Files:**
- Create: `lib/src/interaction_layer.dart`
- Modify: `lib/src/select_tool.dart` (move `kPickRadiusPixels` out)
- Modify: `lib/jet_cad_2d_flutter.dart` (exports)
- Test: `test/interaction_layer_test.dart`; `pumpInteraction` added to `test/support/selection_fixture.dart`

**Interfaces:**

```dart
const double kPickRadiusPixels = 6.0;

class InteractionLayer extends StatefulWidget {
  const InteractionLayer({super.key, required this.tools, required this.child});
  final ToolController tools;   // its context carries camera, selection, index, document
  final Widget child;
}
```

- [ ] **Step 1: The fixture** — `pumpInteraction(tester, {camera, selection, tools, doc, index})`
  pumps `Center(SizedBox(400×300, InteractionLayer(tools, child: Stack([RepaintBoundary(DraftCanvas), Positioned.fill(... SelectionOverlay ...)]))))`
  and asserts `tester.getSize(find.byType(InteractionLayer)) == Size(400, 300)`.

- [ ] **Step 2: Failing tests** (`TestGesture` via `tester.startGesture` /
  `tester.createGesture(kind: PointerDeviceKind.mouse)`; hovers via
  `gesture.moveTo` on a mouse gesture with no button down — use
  `tester.createGesture(kind: PointerDeviceKind.mouse, pointer: 7)` then
  `addPointer` / `moveTo`; keys via `tester.sendKeyDownEvent` /
  `sendKeyUpEvent`):

1. `'a click selects; the layer took focus'`: `FocusManager.instance.primaryFocus` is the layer's node after the click.
2. **M-02g** — `'drag direction selects the mode; a vertical drag is a window'`:
   the M-02a fixture in world; left→right, right→left, and a drag with
   `end.dx == start.dx`.
3. **M-02i** — `'exiting the layer clears hover'`: hover over a line →
   `selection.hover != null`; `moveTo` outside the layer → null.
4. **M-02l** — `'the pick radius is converted by the camera scale'`: camera
   at scale 0.25; click 5 px from a line on screen → selected.
5. **M-02x** — `'one Delete press is one remove'`: `sendKeyDownEvent(delete)`
   then `sendKeyUpEvent(delete)`; the document lost one entity; `canUndo`;
   `undo()` restores it; `canUndo` is then false.
6. **M-02y** — `'a pointer cancel ends the band'`: start a band with a
   `TestGesture`, then `gesture.cancel()`; `tools.active.phase == idle`,
   selection untouched.
7. `'a middle-button drag never reaches the tool'`: `createGesture(buttons:
   kMiddleMouseButton)` down/move/up → phase stays idle, selection empty.
8. `'primary released while middle is still held is an up'`: down primary,
   move, then a move whose `buttons` is middle only (build the
   `PointerMoveEvent` by hand and dispatch through
   `GestureBinding.instance.handlePointerEvent`) → phase idle; a later
   `PointerUpEvent` with `buttons == 0` is ignored without throwing.

- [ ] **Step 3: Implement `interaction_layer.dart`**

```dart
class _InteractionLayerState extends State<InteractionLayer> {
  final FocusNode _focus = FocusNode(debugLabel: 'InteractionLayer');
  int _activePointer = -1;
  int _lastButtons = 0;

  ToolContext get _ctx => widget.tools.context;
  Tool get _tool => widget.tools.active;

  ToolPointerEvent _wrap(PointerEvent e) {
    final cam = _ctx.camera.value;
    final local = e.localPosition;
    final k = HardwareKeyboard.instance;
    return ToolPointerEvent(
      screen: local,
      world: cam.screenToWorld(Vector2(local.dx, local.dy)),
      pointer: e.pointer, buttons: e.buttons,
      shift: k.isShiftPressed, control: k.isControlPressed,
      meta: k.isMetaPressed, alt: k.isAltPressed,
      pickRadiusWorld: kPickRadiusPixels / cam.scale,
    );
  }

  bool _cameraOwned(int buttons) => buttons & kMiddleMouseButton != 0;

  void _onDown(PointerDownEvent e) {
    if (_cameraOwned(e.buttons) || _activePointer != -1) return;
    if (e.buttons & kPrimaryButton == 0) return;
    _focus.requestFocus();
    _activePointer = e.pointer;
    _lastButtons = e.buttons;
    _tool.onPointerDown(_wrap(e), _ctx);
  }

  void _onMove(PointerMoveEvent e) {
    if (_cameraOwned(e.buttons)) return;
    final hadPrimary = _lastButtons & kPrimaryButton != 0;
    final hasPrimary = e.buttons & kPrimaryButton != 0;
    if (e.pointer == _activePointer) {
      _lastButtons = e.buttons;
      if (hadPrimary && !hasPrimary) {
        _activePointer = -1;
        _tool.onPointerUp(_wrap(e), _ctx);
      } else {
        _tool.onPointerMove(_wrap(e), _ctx);
      }
      return;
    }
    if (_activePointer == -1 && hasPrimary) {
      _activePointer = e.pointer;
      _lastButtons = e.buttons;
      _tool.onPointerDown(_wrap(e), _ctx);
    }
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = -1;
    _lastButtons = 0;
    _tool.onPointerUp(_wrap(e), _ctx);
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = -1;
    _lastButtons = 0;
    _tool.cancel(_ctx);
  }

  void _onHover(PointerHoverEvent e) {
    if (_activePointer != -1) return;
    _tool.onPointerMove(_wrap(e), _ctx);
  }

  @override
  void dispose() {
    _ctx.selection.setHover(null);
    _tool.cancel(_ctx);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (_, event) => _tool.onKey(event, _ctx),
        child: MouseRegion(
          onExit: (_) => _tool.onPointerExit(_ctx),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onDown,
            onPointerMove: _onMove,
            onPointerUp: _onUp,
            onPointerCancel: _onCancel,
            onPointerHover: _onHover,
            child: widget.child,
          ),
        ),
      );
}
```

Exports in `jet_cad_2d_flutter.dart`: `selection.dart`, `tool.dart`,
`select_tool.dart`, `selection_style.dart`, `outline_cache.dart`,
`selection_overlay.dart`, `interaction_layer.dart`.

- [ ] **Step 4: Run, the full package gate line, commit**

```sh
git add lib/src/interaction_layer.dart lib/src/select_tool.dart lib/jet_cad_2d_flutter.dart test/interaction_layer_test.dart test/support/selection_fixture.dart
git commit -m "feat(interaction): InteractionLayer routes pointer transitions and keys to the active tool"
```

---

### Task 10: The app — controllers on the shell, the interaction tree, the status text

**Files:**
- Modify: `lib/main.dart`, `lib/planner_view.dart`
- Test: `test/planner_shell_test.dart`

- [ ] **Step 1: Failing tests** (criterion 13):

1. `'the status text shows the tool name and follows the selection'`:
   `find.byKey(Key('status-text'))` reads `'Select'`; reach the
   controllers through `tester.widget<PlannerView>(...)` (`selection`,
   `tools` become `PlannerView` fields); `selection.replace([...])` with a
   key for one of the startup plan's entities (pick one with
   `SpatialIndex.pickInto` at a known wall's midpoint — `kPlanOriginX +
   100, kPlanOriginY` is on the outer wall; check with a first assertion);
   `await tester.pump()`; text reads `'Select — 1 selected'`.
2. `'the interaction tree is in place'`: `find.byType(InteractionLayer)`,
   `find.byType(SelectionOverlay)` (via `find.byWidgetPredicate((w) => w is
   CustomPaint && w.painter is SelectionOverlay)`), both once; the overlay's
   `RenderCustomPaint.size == DraftCanvas`'s size.
3. `'a click on a wall selects it in the running shell'`: `tester.tapAt`
   the screen position of that midpoint (through `view.camera.value
   .worldToScreen` plus the view's top-left from `tester.getTopLeft`);
   `selection.length == 1`.
4. The four existing tests stay green unedited.

- [ ] **Step 2: Implement**

`_PlannerShellState` gains:

```dart
  late final SelectionController _selection = SelectionController(_document);
  late final ToolContext _context = ToolContext(
      document: _document, index: _index, camera: _camera, selection: _selection);
  late final ToolController _tools =
      ToolController(initial: SelectTool(), context: _context);
  late final Listenable _status = Listenable.merge([_selection, _tools]);
```

disposed in `dispose()` (`_tools.dispose(); _selection.dispose();` before
the camera). `chrome-top` becomes a `Container` with an `Align(alignment:
Alignment.centerLeft, child: Padding(padding: EdgeInsets.symmetric(horizontal:
12), child: ListenableBuilder(listenable: _status, builder: (_, __) => Text(
_statusLine(), key: const Key('status-text')))))` where `_statusLine()` is
`'${_tools.active.name}'` plus `' — ${_selection.length} selected'` when
non-empty. `PlannerView` gains `selection` and `tools` parameters and builds:

```dart
          return CameraGestureDetector(
            camera: widget.camera,
            policy: widget.policy,
            child: InteractionLayer(
              tools: widget.tools,
              child: Stack(
                children: [
                  DraftCanvas(document: widget.document, index: widget.index,
                      camera: widget.camera, tiles: false),   // already inside its own RepaintBoundary
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: SelectionOverlay(
                          selection: widget.selection, tools: widget.tools,
                          camera: widget.camera, outlines: _outlines,
                          repaint: _repaint),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
```

with `_outlines = OutlineCache(widget.document, widget.selection)` and
`_repaint = Listenable.merge([widget.selection, widget.tools, widget.camera])`
as `late final` fields of `_PlannerViewState`, the cache disposed in
`dispose`.

- [ ] **Step 3: Run the app line, including both builds**

```sh
cd apps/floor_planner && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build macos --debug && flutter build web
git status --short   # restore any analysis_options.yaml pub get rewrote
```

- [ ] **Step 4: Commit**

```sh
git add lib/main.dart lib/planner_view.dart test/planner_shell_test.dart
git commit -m "feat(app): selection, hover and band in the floor planner; tool name and count in the top bar"
```

---

### Task 11: Mutation testing, the two allocation gates, the greps

**Files:**
- Create: `docs/superpowers/notes/plan-02-mutation-log.md`

For each of the thirty mutants in the spec's table: `cp` the file aside,
apply the mutation by hand (one edit), run **only the named test file**,
paste the failing test's name and the summary line, restore with `cp`,
`diff` to confirm. Log format per mutant:

```
### M-02a — swap window/crossing predicates
file: packages/jet_cad_2d/lib/src/index/spatial_index.dart, `_leafPasses`: `mode == BandMode.window` → `mode == BandMode.crossing`
test: CI=true dart test test/index/band_query_test.dart -N "window keeps only"
result: FIRED — `Expected: {inside}` … `Actual: {inside, straddling}`; 1 failed
restored: diff clean
```

M-02c and M-02e: entries headed `EQUIVALENT` with the spec's sentence.
M-02f: note the non-discriminating half. M-02l: the scale-0.25 fixture.

Then:

```sh
cd packages/jet_cad_2d && CI=true dart test test/invariants/query_allocation_test.dart
cd ../jet_cad_2d_flutter && CI=true flutter test test/invariants/paint_allocation_test.dart
git diff --stat main..HEAD -- apps/dev_harness_2d packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart packages/jet_cad_2d_flutter/lib/src/draft_painter.dart packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/lib/src/tile_cache.dart   # empty
grep -rn "kIsWeb\|dart:ui_web" packages/jet_cad_2d_flutter/lib/src/selection*.dart packages/jet_cad_2d_flutter/lib/src/tool.dart packages/jet_cad_2d_flutter/lib/src/select_tool.dart packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart packages/jet_cad_2d_flutter/lib/src/outline_cache.dart   # nothing
```

Paste all four outputs into the log's tail. Commit the log.

---

### Task 12: Gates, the results note, the owed look, the resume point

**Files:**
- Create: `docs/superpowers/notes/2026-09-21-plan-02-results.md`
- Modify: `roadmap/02-interaction-core.md` (status line), `roadmap/00-README.md` (status row), `STATUS.md` (a Plan 02 section and the Resume paragraph)

- [ ] **Step 1: The eleven gate commands, all four lines**, outputs pasted
  into the results note with exit codes; the five golden failures named.
- [ ] **Step 2: The results note**: one row per exit criterion 1–15 with its
  witness; criterion 15 (the human's look, macOS + Chrome + Firefox) marked
  **OWED — not looked at; the human looks after this branch is presented**,
  with the seven items itemised; D10's N-undo-steps debt and the partial-undo
  hazard stated in as many words; the differential's trial count.
- [ ] **Step 3: STATUS and roadmap** as 01 did (`STATUS.md` Plan 01 section
  is the template).
- [ ] **Step 4: Commit**, then hand to `superpowers:finishing-a-development-branch`.

---

## Exit gate

The spec's fifteen criteria, verbatim, each with the task that witnesses it:

| # | witness |
|---|---|
| 1 | Task 5 tests 2–4; Task 9 test 1 |
| 2 | Task 2 test 1; Task 5 test 7; Task 9 test 2 |
| 3 | Task 3 test 1 |
| 4 | Task 5 test 1; Task 9 test 3; Task 8 test 4 |
| 5 | Task 6 tests 1, 3; Task 9 test 5 |
| 6 | Task 8 test 1 |
| 7 | Task 4 |
| 8 | Task 11's log, thirty entries |
| 9 | Task 2 test 10 |
| 10 | Task 11 |
| 11 | Task 11's diff, Task 12's harness line |
| 12 | Task 12 |
| 13 | Task 10 tests 1–3 |
| 14 | Task 8 test 5 |
| 15 | OWED to the human, Task 12's note |

## Self-review

- **Spec coverage:** D1 → Tasks 5, 9; D2 → Task 3; D3 → Task 6; D4 → Task 4;
  D5 → the file table; D6 → Task 3; D7 → Tasks 5, 9; D8 → Tasks 1, 2, 5
  (Ruling 02-2); D9 → Tasks 7, 8; D10 → Task 6; D11 → Task 3; D12 → Task
  10. The pointer routing table → Task 9. Every mutant has a task: a, g, s,
  t, u, z → 2; b, o → 2; c′, k, p, aa → 3; d, f, h, r → 5; j, n, x (tool
  level) → 6; v, w → 7; e′, m, ab, ac → 8; g, i, l, x, y → 9. c and e →
  Task 11's equivalence entries.
- **Placeholder scan:** none. Task 2's `_bandDescend` is the corrected
  form (window walks the whole container through `_kAllBox`).
- **Type consistency:** `SelectionKey.root(Handle)` used in Tasks 3, 5, 6,
  10; `ToolPointerEvent` fields identical in Tasks 4, 5, 9;
  `OutlineCache.pathFor(key, origin)` in Tasks 7, 8; `SelectionOverlay`'s
  constructor identical in Tasks 8, 10; `kPickRadiusPixels` moves from Task
  5 to Task 9 and is imported from `interaction_layer.dart` after that.
