# Plan 3g — the rasterised tile cache: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A world-anchored cache of rasterised viewport tiles, behind a flag, that takes a settled or panning frame at 500,000 entities from 40.27 ms to under 4 ms without changing a pixel.

**Architecture:** `TileCache` owns a generation of `ui.Image` tiles keyed by `(scaleGeneration, x, y)`, each baked by running the existing `DraftPainter` into a `PictureRecorder` and calling `Picture.toImageSync`. The frame's screen translation is quantised to whole device pixels on both the tiled and the live path, so every tile blits 1:1 and the tiled frame can be required to equal the live frame exactly. A scale change retires the generation into one carry-over composite; document edits invalidate per tile in two directions.

**Tech Stack:** Dart 3, Flutter 3.47.1, `dart:ui` (`PictureRecorder`, `Picture.toImageSync`, `Canvas.drawImageRect`), the existing `DraftPainter` / `DrawSink` / `VerticesDrawSink` stack.

**Spec:** [docs/superpowers/specs/2026-08-23-jet-cad-2d-plan-3g-tile-cache-design.md](../specs/2026-08-23-jet-cad-2d-plan-3g-tile-cache-design.md) — read it before Task 1. It carries the fourteen decisions, the thirteen failable criteria, the seventeen named mutants and the four accepted gaps this plan is measured against.

**Measurement of record:** [docs/superpowers/notes/2026-08-23-picture-cache-price-spike.md](../notes/2026-08-23-picture-cache-price-spike.md).

## Global Constraints

Copied verbatim from the spec. Every task's requirements implicitly include this section.

- **The frame path allocates nothing per entity in steady state, and O(1) per flush.** Per-tile allocation is viewport-bounded and compliant; the spec's Architecture section says why, and criterion 13 measures it.
- **Draw order is ascending handle value**, stable across undo, save, load and purge.
- **Geometric decisions use `Tolerance`; stored value comparisons are exact `==`.**
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three of them in this workspace.
- **Never synthesize test output.** Reviewers verify claims independently; a fabricated transcript invalidates the task.
- **Never `git checkout` a file to revert a mutation.** Copy it aside, mutate, restore from the copy. Sanctioned exception: `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`, which `flutter drive` rewrites on every run.
- **Prefix every test command with `CI=true`.** Without it Dart's analytics phone-home blocks the runner for minutes at ~0% CPU.
- `unused_import` is an **ERROR** in `packages/jet_cad_2d_flutter`.
- **This plan may not amend `CLAUDE.md`.** A gate passable by editing the rule it is measured against is not a gate.
- Code, comments and commit messages in English.
- **Work directly on `main`.** No worktree, as for Plans 3e, 3f and 3f.1.

### Every task ends green

```sh
cd packages/jet_cad_2d          && CI=true dart test    && CI=true dart analyze    && CI=true dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter  && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
cd apps/dev_harness_2d          && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed lib
```

### The anti-degenerate rule — binding on every test this plan writes

Seven clauses, from the spec. A reviewer rejects a test that violates any of them.

1. **No fixture may fit inside a single tile.** `kTileDevicePixels` is injectable; tests pass 64.
2. **No ink comparison may run at the initial `fit` camera.** `ViewportTransform.fit` applies a 0.95 margin (`viewport_transform.dart:32`) and deriving an expected on-screen quantity through it cost Plan 3f two tasks. Build the camera by hand.
3. **No test may use a single-tile viewport.**
4. **No invalidation test may touch a handle at the document root only.** The definition-owned path is D11.
5. **The invalidation matrix must include an instance transform and its undo.** `TransformNodeCommand` reports only the node handle (`commands.dart:304`).
6. **A long-pan fixture must travel farther than the retained ring.**
7. **An eviction fixture must return to tiles the cap has reclaimed.**

---

## File structure

**Create:**

| file | responsibility |
|---|---|
| `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` | `TileKey`, `TileGrid`, `TileCache`, `quantiseCamera`, the constants. Grid arithmetic, baking, blitting, invalidation, eviction. |
| `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart` | The live-vs-tiled ink instrument: paint both ways to a `ui.Image`, compare bytes, report stray and uncovered pixel counts. |
| `packages/jet_cad_2d_flutter/test/tile_grid_test.dart` | Grid arithmetic and camera quantisation, no drawing. |
| `packages/jet_cad_2d_flutter/test/tile_cache_test.dart` | Criteria 1–4. |
| `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart` | Criteria 5–9. |
| `packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart` | Criteria 12–13, always on. |

**Modify:**

| file | change |
|---|---|
| `packages/jet_cad_2d/lib/src/document/tables.dart` | A mutation counter and a `Listenable` on `DocumentTables`; `TableSection` gains an `onMutated` callback. **The only engine change in this plan.** |
| `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart` | An injectable rebase origin and a visit callback. |
| `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart` | The `tiles` flag, the `TileCache`, the quantised camera, the tiled paint path, the table `Listenable` in `_repaint`. |
| `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` | `export 'src/tile_cache.dart';` |
| `apps/dev_harness_2d/lib/main.dart` | A `TILES` dart-define and a `TILE_PX` sweep define. |
| `apps/dev_harness_2d/lib/measurement_rig.dart` | Tile counters in the printed invariants. |

**Interfaces produced, once, so every later task can name them exactly:**

```dart
// tile_cache.dart
const int kTileDevicePixels = 256;
const int kTilesBakedPerFrame = 8;
const int kTileCacheBytes = 96 * 1024 * 1024;

@immutable class TileKey { const TileKey(this.x, this.y); final int x, y; }

@immutable class TileGrid {
  const TileGrid({required this.anchor, required this.devicePixelRatio, required this.tileDevicePixels});
  final ViewportTransform anchor;
  final double devicePixelRatio;
  final int tileDevicePixels;

  double get scale;                                    // anchor.scale
  bool matchesScale(ViewportTransform camera);          // exact ==
  (int, int) deviceDeltaFrom(ViewportTransform camera); // integral, in device px
  Iterable<TileKey> visibleKeys(ViewportTransform camera, Size viewport);
  ViewportTransform bakeCameraFor(TileKey key);
  Rect destRectFor(TileKey key, ViewportTransform camera);   // logical
}

ViewportTransform quantiseCamera(ViewportTransform camera, double devicePixelRatio);

class TileCache {
  TileCache({int tileDevicePixels = kTileDevicePixels,
             int tilesBakedPerFrame = kTilesBakedPerFrame,
             int cacheBytes = kTileCacheBytes});
  void paintFrame({required Canvas canvas, required Size viewport,
                   required double devicePixelRatio,
                   required ViewportTransform camera,
                   required DraftPainter painter,
                   required CanvasDrawSink sink,
                   required VerticesDrawSink? vertices});
  void applyChange(DocChange change, DraftDocument document);
  void onTablesChanged();
  void dispose();
  // counters, all read by tests
  int get liveTileCount; int get liveBytes; int get bakeCount;
  int get blitCount; int get evictionCount; int get generation;
  bool get hasCarryOver; Paint get debugBlitPaint;
}
```

```dart
// draft_painter.dart, added -- both fields are mutable, set per bake by TileCache
DraftPainter({ ..., this.debugRebaseOrigin, this.debugOnVisit });
Vector2? debugRebaseOrigin;                   // overrides rebaseOriginFor when non-null
void Function(Handle handle)? debugOnVisit;   // every leaf drawn, every container descended
```

```dart
// tables.dart, added
class DocumentTables {
  int get mutationRevision;
  Listenable get changes;
}
```

```dart
// draft_canvas.dart, added
DraftCanvas({ ..., this.tiles = false, this.tileDevicePixels = kTileDevicePixels });
```

---

## Task 1: The frame-global audit, and `DraftPainter`'s injectable rebase origin

**Why first:** the spec's D1 says tiling turns *every* frame-global quantity into a per-tile one unless it is pinned. Nothing later in this plan is safe until the list of such quantities is written down.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`
- Test: `packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `DraftPainter({..., Vector2? debugRebaseOrigin, void Function(Handle)? debugOnVisit})`. Task 5 injects the origin; Task 8 uses the visit callback.

- [ ] **Step 1: Audit and record the frame-global quantities**

Read `DraftPainter.paint` (`draft_painter.dart:296-350`) and write down every value it derives from *this call's* `camera` and `viewport` rather than from a field. Put the list in the commit message. The four the spec expects are:

| quantity | line | frame-global? |
|---|---|---|
| `rebaseOriginFor(world)` → `origin` | `:307-308` | **yes** — snaps to a power-of-two grid from the view span |
| `_screenOrigin = camera.worldToScreen(origin)` | `:310` | derived from the above |
| `_screenSpaceClip` / `_rebasedClip` (inflated by `kScreenClipInflate`) | `:311-322` | **no** — must be the tile's own rect, which is what the bake camera gives it |
| `minTextCapPixels` level-of-detail threshold | field, `:102` | already a field, so already frame-global |

If the audit finds a fifth, say so in the report; the plan's later tasks assume these four.

- [ ] **Step 2: Write the failing test**

Create `packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart`:

```dart
// Rebasing is frame-global by construction: `rebaseOriginFor` snaps the view
// centre to a power-of-two grid whose step comes from the view *span*
// (`camera_controller.dart:18-33`). Plan 3g bakes tiles through per-tile
// cameras, and a per-tile span would give each tile its own step and its own
// origin — different `float32` residuals from the live frame, against a
// criterion that allows zero differing pixels.
//
// This pins that the override exists and that it wins. Mutant M17 deletes it.

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

import 'support/fixtures.dart';

void main() {
  test('an injected rebase origin overrides the one the view span would give',
      () {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
    // Far from the origin, so the rebase origin is a large number and a wrong
    // one is visible in the emitted coordinates rather than lost in rounding.
    // 4.5e6 is the magnitude `viewport_transform.dart`'s header names.
    addLine(doc, doc.rootHandle, const Handle(1001), 4.5e6, 4.5e6, 4.5e6 + 400,
        4.5e6 + 300);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    const viewport = Size(400, 300);
    final camera = ViewportTransform(
        worldToScreenMatrix:
            Transform2(1, 0, 0, -1, -4.5e6, 4.5e6 + viewport.height));

    Float64List firstPolyline(DraftPainter painter) {
      final sink = RecordingDrawSink();
      painter.paint(sink, camera, viewport);
      final op = sink.ops.whereType<PolylineOp>().first;
      return Float64List.fromList(op.points);
    }

    final derived = firstPolyline(DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc)));

    // A deliberately different origin: the same grid, one step over. The
    // emitted points are rebased against it, so every x moves by exactly the
    // difference and nothing else changes.
    final defaultOrigin = rebaseOriginFor(camera.visibleWorld(viewport));
    final shifted = Vector2(defaultOrigin.x + 4096, defaultOrigin.y);
    final overridden = firstPolyline(DraftPainter(
        document: doc,
        index: index,
        resolver: DocumentStyleResolver(doc),
        debugRebaseOrigin: shifted));

    expect(overridden.length, derived.length);
    for (var i = 0; i < derived.length; i += 2) {
      expect(overridden[i], derived[i] - 4096,
          reason: 'x rebased against the injected origin');
      expect(overridden[i + 1], derived[i + 1], reason: 'y untouched');
    }
  });

  test('debugOnVisit reports every leaf drawn and every container descended',
      () {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
    // One root leaf, one definition holding one leaf, one instance placing it.
    // A root-only fixture would let M16 survive — see anti-degenerate clause 4.
    addLine(doc, doc.rootHandle, const Handle(1001), 10, 10, 90, 90);
    addDefinition(doc, const Handle(210), 'PLATE');
    addLine(doc, const Handle(210), const Handle(1002), 0, 0, 40, 40);
    addInstance(doc, doc.rootHandle, const Handle(300), const Handle(210),
        Transform2(1, 0, 0, 1, 120, 20));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final seen = <Handle>[];
    final painter = DraftPainter(
      document: doc,
      index: index,
      resolver: DocumentStyleResolver(doc),
      debugOnVisit: seen.add,
    );
    painter.paint(RecordingDrawSink(), unitCamera(), const Size(400, 300));

    expect(seen, contains(const Handle(1001)), reason: 'the root leaf');
    expect(seen, contains(const Handle(1002)), reason: 'the definition leaf');
    expect(seen, contains(const Handle(300)),
        reason: 'the instance node itself — TransformNodeCommand reports only '
            'this handle, so a tile that never records it cannot find the '
            'pixels a drag left behind');
  });
}
```

`unitCamera()`, `addLine`, `addDefinition`, `addInstance` come from `test/support/fixtures.dart`. If any is missing, add it there in this task rather than inlining a local copy.

- [ ] **Step 3: Run it and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/draft_painter_rebase_test.dart
```

Expected: compile failure — `DraftPainter` has no `debugRebaseOrigin` and no `debugOnVisit`.

- [ ] **Step 4: Add the two parameters**

In `draft_painter.dart`, add to the constructor and the fields:

```dart
  /// Overrides the rebase origin `paint` would derive from this call's visible
  /// world.
  ///
  /// **Rebasing is frame-global by construction.** `rebaseOriginFor` snaps the
  /// view centre to a power-of-two grid whose step comes from the view *span*
  /// (`camera_controller.dart:18-33`), precisely so a pan does not re-quantise
  /// every coordinate. Plan 3g bakes tiles through per-tile cameras; without
  /// this each tile would take its own span, its own exponent and its own
  /// origin, and its `float32` residuals would differ from the live frame's.
  ///
  /// Not `debugDisableRebasing`, which forces the origin to zero and destroys
  /// the precision rebasing exists for at 4.5e6.
  /// **Deliberately mutable.** `TileCache` sets it around each bake and clears
  /// it afterwards, so one painter serves the live frame and every tile in it.
  /// A `final` field would force a painter instance per tile, and a painter
  /// carries the scratch buffers `paint_allocation_test.dart` exists to keep
  /// still.
  Vector2? debugRebaseOrigin;

  /// Called with every leaf drawn and every container descended into.
  ///
  /// Plan 3g's tile invalidation records what a tile baked. **Both halves are
  /// needed**: `TransformNodeCommand` reports only the moved node's handle
  /// (`commands.dart:304`), and the leaves it moved keep their own, so a tile
  /// that recorded leaves alone cannot find a dragged instance's old pixels.
  ///
  /// Null on the production frame path, so it costs one null check per leaf and
  /// allocates nothing.
  /// Mutable for the same reason as [debugRebaseOrigin].
  void Function(Handle handle)? debugOnVisit;
```

In `paint`, replace the origin derivation:

```dart
    final origin = debugRebaseOrigin ??
        (debugDisableRebasing ? Vector2.zero() : rebaseOriginFor(world));
```

Note the precedence: an injected origin wins over `debugDisableRebasing`, because a caller that supplies one has already decided.

In `paint`'s leaf visitor, immediately before the `_drawLeaf` call:

> **Corrected 2026-08-23, mid-execution.** An earlier revision named
> `_rootLeaves++` and `_defLeaves++` as the anchors. **Those counters do not
> exist on `main`** — they are Probe B instrumentation on the unmerged
> `spike/picture-cache-price` branch, and the plan cited them from memory of
> that tree. Place the calls by structure, not by the missing anchors, and
> the reviewer verifies the placement fires exactly once per leaf drawn and
> once per container descended.

```dart
      debugOnVisit?.call(document.entities.handleAt(slot));
```

In `_drawContainer`'s leaf loop, immediately before the `_drawLeafComposed` call and **after** the tree/overlay duplicate `continue` — use `leafHandle`, which the loop already computed:

```dart
      debugOnVisit?.call(Handle(leafHandle));
```

In `_drawInstance`, after the `is! InstanceNode` guard:

```dart
    debugOnVisit?.call(instance);
```

In `_descend`, after its `is! InstanceNode` guard:

```dart
    debugOnVisit?.call(handle);
```

- [ ] **Step 5: Run it and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/draft_painter_rebase_test.dart
```

- [ ] **Step 6: Fire mutant M17 by hand**

Copy the file aside first — **never `git checkout` to revert a mutation**:

```sh
cp lib/src/draft_painter.dart /tmp/draft_painter.dart.bak
```

Change the origin line to ignore the override:

```dart
    final origin = debugDisableRebasing ? Vector2.zero() : rebaseOriginFor(world);
```

Run the test; it must fail on the x assertion. Then:

```sh
cp /tmp/draft_painter.dart.bak lib/src/draft_painter.dart && rm /tmp/draft_painter.dart.bak
```

Record the transcript in the task report.

- [ ] **Step 7: Green the whole suite and commit**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/lib/src/draft_painter.dart packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart packages/jet_cad_2d_flutter/test/support/fixtures.dart
git commit -m "feat: the painter's rebase origin and visit list become injectable

Rebasing is frame-global by construction -- rebaseOriginFor snaps the view
centre to a power-of-two grid whose step comes from the view span, so a pan
does not re-quantise coordinates. Baking tiles through per-tile cameras would
give each tile its own span and its own origin, and float32 residuals that
differ from the live frame's against a criterion that allows zero differing
pixels.

debugOnVisit reports leaves and containers both. TransformNodeCommand reports
only the moved node's handle and its leaves keep theirs, so a tile recording
leaves alone cannot find a dragged instance's old pixels."
```

---

## Task 2: `DocumentTables` gets a mutation counter and a `Listenable`

**Why:** the spec's D12. `TableSection.add`, `remove` and `clear` notify nothing, and `DraftCanvas` repaints only for `Listenable.merge([camera, _changes])` where `_changes` is command-backed. A layer colour change today causes no paint at all, so a revision integer read inside `paint` would be correct and never reached.

**This is the only change this plan makes to `packages/jet_cad_2d`.**

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/tables.dart`
- Test: `packages/jet_cad_2d/test/document/tables_revision_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `DocumentTables.mutationRevision` (`int`) and `DocumentTables.changes` (`Listenable`). Task 9 merges the `Listenable` into `_repaint`.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/document/tables_revision_test.dart`:

```dart
// Table mutations reach nobody today. `DocChange` is emitted only by
// `undo.dart` when a command is applied, undone or redone, and
// `TableSection.add`, `remove` and `clear` go through no command at all
// (`tables.dart:51-68`). Plan 3g's tile cache must invalidate on a layer
// colour change, so the tables grow a revision and a `Listenable`.
//
// All three mutators, because `clear` is the one an earlier draft of the spec
// missed and a load path that clears would otherwise leave every tile stale.

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

LayerRecord layer(int handle, String name) => LayerRecord(
      handle: Handle(handle),
      name: name,
      // Not the default: the anti-degenerate habit applies to fixtures in this
      // repository generally, and a record that differs only by handle proves
      // less than one that differs in a field a resolver reads.
      color: const DraftColor.indexed(3),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: 50,
      transparency: 40,
    );

void main() {
  test('every table mutator bumps the revision and notifies', () {
    final tables = DocumentTables.standard();
    var notifications = 0;
    void listener() => notifications++;
    tables.changes.addListener(listener);
    addTearDown(() => tables.changes.removeListener(listener));

    final start = tables.mutationRevision;

    tables.layers.add(layer(900, 'WALLS'));
    expect(tables.mutationRevision, start + 1, reason: 'add');
    expect(notifications, 1);

    tables.layers.remove(const Handle(900));
    expect(tables.mutationRevision, start + 2, reason: 'remove');
    expect(notifications, 2);

    tables.linetypes.clear();
    expect(tables.mutationRevision, start + 3, reason: 'clear');
    expect(notifications, 3);
  });

  test('a rejected add bumps nothing', () {
    final tables = DocumentTables.standard();
    tables.layers.add(layer(901, 'GRID'));
    final after = tables.mutationRevision;

    expect(() => tables.layers.add(layer(901, 'OTHER')),
        throwsA(isA<DuplicateHandleError>()));
    expect(tables.mutationRevision, after,
        reason: 'a throw is not a mutation; bumping here would invalidate '
            'every tile for an edit the document refused');
  });

  test('a remove of an absent handle bumps nothing', () {
    final tables = DocumentTables.standard();
    final after = tables.mutationRevision;
    tables.layers.remove(const Handle(9999));
    expect(tables.mutationRevision, after);
  });

  test('every section is wired, not just layers', () {
    final tables = DocumentTables.standard();
    var revision = tables.mutationRevision;
    // Six sections; a per-section wiring mistake would leave one silent, and
    // a test that checked `layers` alone would not see it.
    tables.layers.add(layer(910, 'A'));
    expect(tables.mutationRevision, ++revision);
    tables.linetypes.add(LinetypeRecord(
        handle: const Handle(911),
        name: 'DASHED2',
        description: '',
        pattern: const [4.0, -2.0]));
    expect(tables.mutationRevision, ++revision);
    tables.textStyles.add(const TextStyleRecord(
        handle: Handle(912), name: 'TITLE', font: 'Roboto', widthFactor: 1.2));
    expect(tables.mutationRevision, ++revision);
    tables.patterns.add(const PatternRecord(handle: Handle(913), name: 'NET'));
    expect(tables.mutationRevision, ++revision);
    tables.dimStyles.add(const DimStyleRecord(handle: Handle(914), name: 'D1'));
    expect(tables.mutationRevision, ++revision);
    tables.appIds.add(const AppIdRecord(handle: Handle(915), name: 'ACAD2'));
    expect(tables.mutationRevision, ++revision);
  });
}
```

**Before writing this file**, read the six record classes in `tables.dart` and correct the constructor calls above to their real required parameters. The shapes above are what the plan expects; the tree is the authority, and a constructor that does not compile is a plan defect to fix in place, not to work around.

- [ ] **Step 2: Run it and watch it fail**

```sh
cd packages/jet_cad_2d && CI=true dart test test/document/tables_revision_test.dart
```

Expected: compile failure — `DocumentTables` has no `mutationRevision` and no `changes`.

- [ ] **Step 3: Implement**

`TableSection` gains a callback, defaulting to null so every existing construction still compiles:

```dart
class TableSection<T extends TableRecord> {
  /// Called after a mutation that actually changed this section.
  ///
  /// **Not a `ChangeNotifier` of its own.** `DocumentTables` holds six sections
  /// as bare field initializers with no back-reference (`tables.dart`), and a
  /// notifier per section would make a listener subscribe six times and a
  /// caller reason about six revisions. One counter on the owner is the whole
  /// contract Plan 3g needs.
  TableSection({this.onMutated});

  final void Function()? onMutated;
```

`add` bumps only after both guards have passed:

```dart
  void add(T record) {
    if (_byHandle.containsKey(record.handle)) {
      throw DuplicateHandleError(record.handle);
    }
    final key = record.name.toLowerCase();
    if (_byName.containsKey(key)) throw DuplicateTableNameError(record.name);
    _byHandle[record.handle] = record;
    _byName[key] = record.handle;
    onMutated?.call();
  }
```

`remove` bumps only when something left:

```dart
  void remove(Handle handle) {
    final record = _byHandle.remove(handle);
    if (record == null) return;
    _byName.remove(record.name.toLowerCase());
    onMutated?.call();
  }
```

`clear` bumps unconditionally — a clear of an empty section is still the caller declaring the table replaced, and treating it as a no-op would make a load path that clears then adds bump once instead of twice:

```dart
  void clear() {
    _byHandle.clear();
    _byName.clear();
    onMutated?.call();
  }
```

`DocumentTables` owns the counter and the notifier:

```dart
class DocumentTables {
  DocumentTables() {
    layers = TableSection(onMutated: _bump);
    linetypes = TableSection(onMutated: _bump);
    textStyles = TableSection(onMutated: _bump);
    patterns = TableSection(onMutated: _bump);
    dimStyles = TableSection(onMutated: _bump);
    appIds = TableSection(onMutated: _bump);
  }

  late final TableSection<LayerRecord> layers;
  late final TableSection<LinetypeRecord> linetypes;
  late final TableSection<TextStyleRecord> textStyles;
  late final TableSection<PatternRecord> patterns;
  late final TableSection<DimStyleRecord> dimStyles;
  late final TableSection<AppIdRecord> appIds;

  int _revision = 0;
  final _TablesNotifier _changes = _TablesNotifier();

  /// Bumped by every table mutation that changed something.
  ///
  /// **Table mutations reach the command system not at all.** `DocChange` is
  /// emitted only by `undo.dart`, and a layer edit goes through `TableSection`
  /// directly, so before this counter existed a layer colour change produced
  /// no signal of any kind. Plan 3g's tile cache reads it, and
  /// `DraftCanvas` merges [changes] into its repaint listenable — the counter
  /// alone would be correct and never reached, because a layer edit causes no
  /// paint.
  ///
  /// **Every table record is `@immutable` with final fields, and `add` throws
  /// on a duplicate handle, so changing a record is necessarily
  /// remove-then-add and both are counted. If a record ever gains a setter,
  /// that mutation is invisible here.**
  int get mutationRevision => _revision;

  /// Notifies after any table mutation.
  Listenable get changes => _changes;

  void _bump() {
    _revision++;
    _changes.fire();
  }
```

`_TablesNotifier` is a three-line `ChangeNotifier` subclass exposing `notifyListeners`. **`package:jet_cad_2d` must not depend on Flutter**, so it cannot use `foundation.ChangeNotifier`; write the minimal listener list here:

```dart
/// A `Listenable` without Flutter.
///
/// `package:jet_cad_2d` is pure Dart on purpose — no `dart:ui`, no Flutter —
/// so `foundation.ChangeNotifier` is not available. This is the whole of the
/// contract `Listenable.merge` needs.
class _TablesNotifier implements Listenable {
  final List<VoidCallback> _listeners = [];

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void fire() {
    // Copied before iteration: a listener that removes itself while being
    // notified would otherwise mutate the list under the loop.
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }
}
```

`Listenable` and `VoidCallback` are Flutter types. **They are not available in this package.** Declare the minimal equivalents in `tables.dart`:

```dart
typedef VoidCallback = void Function();

/// The subset of Flutter's `Listenable` that `Listenable.merge` requires.
///
/// Declared here rather than imported: this package has no Flutter dependency
/// and gains none for one interface. Flutter's `Listenable.merge` accepts any
/// object with these two methods through its own `Listenable` type, so
/// `DraftCanvas` adapts this in Task 9 rather than passing it directly.
abstract class TableListenable {
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
}
```

and change `_TablesNotifier implements TableListenable`, `Listenable get changes` → `TableListenable get changes`. Task 9 wraps it.

- [ ] **Step 4: Run it and watch it pass**

```sh
cd packages/jet_cad_2d && CI=true dart test test/document/tables_revision_test.dart
```

- [ ] **Step 5: Run the whole engine suite**

The `DocumentTables` constructor changed from field initializers to `late final` assignment. `DocumentTables.standard()` and the JSON codec both construct sections; both must still pass.

```sh
cd packages/jet_cad_2d && CI=true dart test
```

- [ ] **Step 6: Fire mutant M8's counter half**

```sh
cp lib/src/document/tables.dart /tmp/tables.dart.bak
```

Remove `onMutated?.call();` from `clear` only. The `clear` assertion must go red and the other two stay green — which is the point: a per-mutator wiring mistake is invisible to a test that checks `add` alone. Restore:

```sh
cp /tmp/tables.dart.bak lib/src/document/tables.dart && rm /tmp/tables.dart.bak
```

- [ ] **Step 7: Green both packages and commit**

```sh
cd packages/jet_cad_2d && CI=true dart test && CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze
git add packages/jet_cad_2d/lib/src/document/tables.dart packages/jet_cad_2d/test/document/tables_revision_test.dart
git commit -m "feat: table mutations finally emit a signal

DocChange is emitted only by undo.dart when a command is applied, undone or
redone. Layer and linetype edits go through TableSection.add, remove and clear,
outside the command system, and emitted nothing at all -- so a layer colour
change produced no signal for any consumer to act on.

DocumentTables now owns a revision counter and a listener list, and every
section reports into it. The Listenable is declared here rather than imported:
this package has no Flutter dependency and gains none for one interface.

A rejected add and a remove of an absent handle both bump nothing. A clear
always does, because a clear of an empty section is still the caller declaring
the table replaced."
```

---

## Task 3: `TileKey`, `TileGrid` and `quantiseCamera` — arithmetic only, nothing drawn

**Why separate:** every correctness claim in this plan rests on tile destinations being integral device pixels at *every* camera. That is pure arithmetic and it is worth a reviewer's gate of its own, before a single pixel is baked.

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Create: `packages/jet_cad_2d_flutter/test/tile_grid_test.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`

**Interfaces:**
- Consumes: `ViewportTransform`, `Transform2`.
- Produces: `kTileDevicePixels`, `TileKey`, `TileGrid`, `quantiseCamera`. Task 4 bakes and blits with them.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d_flutter/test/tile_grid_test.dart`:

```dart
// The grid is the whole of Plan 3g's exactness claim. A tile blits 1:1 only
// if its destination lands on whole device pixels, and criterion 1 requires
// that at *every* camera, not at a privileged one -- the key excludes
// translation by design, and a pan drops nothing, so there is no moment when
// the camera returns to where the grid was anchored.
//
// Nothing here draws. The arithmetic is worth failing on its own.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// Deliberately not `ViewportTransform.fit`, and deliberately not the
/// identity: `fit` applies a 0.95 margin and cost Plan 3f two tasks, and a
/// scale of 1.0 with a zero translation hides every mistake this file exists
/// to catch. Scale 2.5, y flipped, and an offset that is not a whole device
/// pixel.
ViewportTransform awkwardCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2(2.5, 0, 0, -2.5, 17.31, 409.77));

const double kDpr = 2.0;
const Size kViewport = Size(400, 300);
const int kTestTile = 64;

void main() {
  group('quantiseCamera', () {
    test('snaps the translation to whole device pixels and nothing else', () {
      final q = quantiseCamera(awkwardCamera(), kDpr);
      final m = q.worldToScreenMatrix;
      expect(m.a, 2.5, reason: 'scale untouched');
      expect(m.d, -2.5);
      expect(m.b, 0.0);
      expect(m.c, 0.0);
      expect((m.e * kDpr) % 1.0, 0.0, reason: 'e is a whole device pixel');
      expect((m.f * kDpr) % 1.0, 0.0, reason: 'f is a whole device pixel');
      // 17.31 * 2 = 34.62 -> 35 -> 17.5;  409.77 * 2 = 819.54 -> 820 -> 410.0
      expect(m.e, 17.5);
      expect(m.f, 410.0);
    });

    test('returns the same instance when already quantised', () {
      final already = ViewportTransform(
          worldToScreenMatrix: Transform2(2.5, 0, 0, -2.5, 17.5, 410.0));
      expect(identical(quantiseCamera(already, kDpr), already), isTrue,
          reason: 'rebuilding would recompute the inverse for nothing, once '
              'per frame, on the frame path');
    });

    test('a dpr of 1 still quantises', () {
      final q = quantiseCamera(awkwardCamera(), 1.0);
      expect(q.worldToScreenMatrix.e, 17.0);
      expect(q.worldToScreenMatrix.f, 410.0);
    });
  });

  group('TileGrid', () {
    TileGrid gridAt(ViewportTransform anchor) => TileGrid(
        anchor: quantiseCamera(anchor, kDpr),
        devicePixelRatio: kDpr,
        tileDevicePixels: kTestTile);

    test('the visible key count matches ceil(extent / tile) + 1 per axis', () {
      final grid = gridAt(awkwardCamera());
      // 400 x 300 logical at dpr 2 = 800 x 600 device. 800/64 = 12.5 -> 13,
      // 600/64 = 9.375 -> 10; the +1 per axis covers an arbitrary alignment.
      final keys = grid.visibleKeys(grid.anchor, kViewport).toList();
      final xs = keys.map((k) => k.x).toSet();
      final ys = keys.map((k) => k.y).toSet();
      expect(xs.length, inInclusiveRange(13, 14));
      expect(ys.length, inInclusiveRange(10, 11));
      expect(keys.length, xs.length * ys.length,
          reason: 'the visible set is a full rectangle of keys');
    });

    test('every destination is a whole device pixel, at every panned camera',
        () {
      final grid = gridAt(awkwardCamera());
      // Twenty-three pans of a deliberately awkward step. Each is quantised,
      // so each destination must still land exactly.
      var camera = grid.anchor;
      for (var i = 0; i < 23; i++) {
        final m = camera.worldToScreenMatrix;
        camera = quantiseCamera(
            ViewportTransform(
                worldToScreenMatrix: Transform2(
                    m.a, m.b, m.c, m.d, m.e - 7.37, m.f - 3.19)),
            kDpr);
        for (final key in grid.visibleKeys(camera, kViewport)) {
          final dest = grid.destRectFor(key, camera);
          expect((dest.left * kDpr) % 1.0, 0.0,
              reason: 'pan $i, key (${key.x}, ${key.y}) left');
          expect((dest.top * kDpr) % 1.0, 0.0,
              reason: 'pan $i, key (${key.x}, ${key.y}) top');
          expect(dest.width * kDpr, kTestTile);
          expect(dest.height * kDpr, kTestTile);
        }
      }
    });

    test('adjacent tiles abut exactly, with no gap and no overlap', () {
      final grid = gridAt(awkwardCamera());
      final camera = grid.anchor;
      final a = grid.destRectFor(const TileKey(3, 5), camera);
      final right = grid.destRectFor(const TileKey(4, 5), camera);
      final below = grid.destRectFor(const TileKey(3, 6), camera);
      expect(right.left, a.right, reason: 'a gap shows background');
      expect(below.top, a.bottom,
          reason: 'an overlap double-composites translucent ink');
    });

    test('the bake camera puts a tile top-left at the logical origin', () {
      final grid = gridAt(awkwardCamera());
      const key = TileKey(3, 5);
      final bake = grid.bakeCameraFor(key);
      final anchor = grid.anchor.worldToScreenMatrix;
      final baked = bake.worldToScreenMatrix;
      expect(baked.a, anchor.a, reason: 'scale is the generation, not the tile');
      expect(baked.d, anchor.d);
      expect(baked.e, anchor.e - 3 * kTestTile / kDpr);
      expect(baked.f, anchor.f - 5 * kTestTile / kDpr);
    });

    test('matchesScale is exact, not tolerant', () {
      final grid = gridAt(awkwardCamera());
      final m = grid.anchor.worldToScreenMatrix;
      expect(grid.matchesScale(grid.anchor), isTrue);
      // One ulp of zoom retires the generation. Stored-value comparisons in
      // this repository are exact `==`; a tolerant scale test would replay a
      // generation baked at a different stroke width and dash phase.
      final nudged = ViewportTransform(
          worldToScreenMatrix: Transform2(
              m.a + m.a * 1e-15, m.b, m.c, m.d, m.e, m.f));
      expect(grid.matchesScale(nudged), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart
```

Expected: compile failure — `tile_cache.dart` does not exist.

- [ ] **Step 3: Write `tile_cache.dart`'s arithmetic half**

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

import 'viewport_transform.dart';

/// A tile's side, in **device** pixels.
///
/// 256 is a starting value with a measured shape behind it and a sweep still
/// owed. Memory and bake cost pull in opposite directions: at a `dpr` of 2 on a
/// 3200x2400 device viewport, 128 px costs 32.5 MiB of visible set but bakes
/// **4.00x** its own area, because `kScreenClipInflate` is 32 *logical* pixels
/// and a 128 px tile is only 64 logical wide; 512 px costs 48.0 MiB and bakes
/// 1.56x. 1024 px is excluded outright — its 80.0 MiB visible set leaves no
/// room under [kTileCacheBytes] for the carry-over composite.
const int kTileDevicePixels = 256;

/// Tiles baked per frame while a generation fills in.
///
/// The settle after a zoom leaves the whole visible set stale, and baking it in
/// one frame is the ~60 ms stall this plan exists to remove, moved rather than
/// removed. At 256 px this covers a 154-tile visible set in twenty frames.
const int kTilesBakedPerFrame = 8;

/// The cache's byte ceiling, counting the carry-over composite and every
/// generation's tiles together.
///
/// 96 MiB, not 64, for two reasons. A retired generation lives on as one
/// viewport-sized composite (29.3 MiB on the reference viewport) beside the
/// incoming generation's tiles (38.5 MiB at 256 px). And 96 MiB is the figure
/// this cache may *replace*: the vertex buffer's high-water mark at 500,000
/// entities, which falls to a single tile's geometry once bakes flush per tile.
const int kTileCacheBytes = 96 * 1024 * 1024;

/// One tile's position in its generation's grid. Not world coordinates: the
/// grid is anchored to the generation's own device-pixel lattice.
@immutable
class TileKey {
  const TileKey(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is TileKey && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'TileKey($x, $y)';
}

/// Snaps a camera's screen translation to whole device pixels.
///
/// **This is the whole of Plan 3g's exactness claim, and it applies to the live
/// path too.** A world-anchored tile lands at a fractional device offset after
/// an arbitrary pan, and settling never returns the camera to the one the grid
/// was anchored at — the tile key excludes translation by design, and a pan is
/// required to invalidate nothing. Quantising both paths puts every tile
/// destination on whole device pixels at every camera, which is what lets the
/// tiled frame be required to equal the live frame with zero differing pixels.
///
/// The cost is up to half a device pixel of global position error, identical in
/// both paths and uniform across the frame. Nothing on screen provides a
/// reference against which it could read as jitter.
ViewportTransform quantiseCamera(
    ViewportTransform camera, double devicePixelRatio) {
  final m = camera.worldToScreenMatrix;
  final e = (m.e * devicePixelRatio).roundToDouble() / devicePixelRatio;
  final f = (m.f * devicePixelRatio).roundToDouble() / devicePixelRatio;
  // Returning the same instance matters: `ViewportTransform`'s constructor
  // inverts the matrix, and this runs once per frame on the frame path.
  if (e == m.e && f == m.f) return camera;
  return ViewportTransform(
      worldToScreenMatrix: Transform2(m.a, m.b, m.c, m.d, e, f));
}

/// One scale generation's lattice.
///
/// Tile `(x, y)` occupies device pixels `[x*T, (x+1)*T) x [y*T, (y+1)*T)` in
/// the **anchor's** screen space. A later camera at the same scale differs from
/// the anchor by a whole number of device pixels, so a tile's destination is
/// that rect plus an integral offset — never a resample.
@immutable
class TileGrid {
  const TileGrid({
    required this.anchor,
    required this.devicePixelRatio,
    required this.tileDevicePixels,
  });

  /// The quantised camera this generation was baked against.
  final ViewportTransform anchor;
  final double devicePixelRatio;
  final int tileDevicePixels;

  /// A tile's side in logical pixels.
  double get _tileLogical => tileDevicePixels / devicePixelRatio;

  /// **Exact, not tolerant.** Stored-value comparisons in this repository are
  /// exact `==`, and a tolerant test would replay a generation baked at a
  /// different stroke width and a different dash phase.
  bool matchesScale(ViewportTransform camera) {
    final a = anchor.worldToScreenMatrix;
    final b = camera.worldToScreenMatrix;
    return a.a == b.a && a.b == b.b && a.c == b.c && a.d == b.d;
  }

  /// How far [camera] sits from the anchor, in device pixels.
  ///
  /// Integral whenever both cameras came through [quantiseCamera], which is
  /// the invariant the whole grid rests on. `round` rather than a bare cast so
  /// a `0.9999999` from the division does not truncate to a one-pixel shift.
  (int, int) deviceDeltaFrom(ViewportTransform camera) {
    final a = anchor.worldToScreenMatrix;
    final b = camera.worldToScreenMatrix;
    return (
      ((b.e - a.e) * devicePixelRatio).round(),
      ((b.f - a.f) * devicePixelRatio).round(),
    );
  }

  /// Every key covering [viewport] at [camera], as a full rectangle.
  Iterable<TileKey> visibleKeys(ViewportTransform camera, Size viewport) sync* {
    final (dx, dy) = deviceDeltaFrom(camera);
    final left = -dx;
    final top = -dy;
    final right = left + (viewport.width * devicePixelRatio).ceil();
    final bottom = top + (viewport.height * devicePixelRatio).ceil();
    final x0 = _floorDiv(left, tileDevicePixels);
    final x1 = _floorDiv(right - 1, tileDevicePixels);
    final y0 = _floorDiv(top, tileDevicePixels);
    final y1 = _floorDiv(bottom - 1, tileDevicePixels);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        yield TileKey(x, y);
      }
    }
  }

  /// The camera a bake uses, so the tile's top-left is the logical origin.
  ///
  /// Scale and skew come from the anchor untouched: the scale *is* the
  /// generation.
  ViewportTransform bakeCameraFor(TileKey key) {
    final m = anchor.worldToScreenMatrix;
    return ViewportTransform(
        worldToScreenMatrix: Transform2(m.a, m.b, m.c, m.d,
            m.e - key.x * _tileLogical, m.f - key.y * _tileLogical));
  }

  /// Where a tile blits, in logical pixels. Always a whole device pixel.
  Rect destRectFor(TileKey key, ViewportTransform camera) {
    final (dx, dy) = deviceDeltaFrom(camera);
    return Rect.fromLTWH(
      (key.x * tileDevicePixels + dx) / devicePixelRatio,
      (key.y * tileDevicePixels + dy) / devicePixelRatio,
      _tileLogical,
      _tileLogical,
    );
  }

  /// Floor division that stays correct for negative numerators.
  ///
  /// Dart's `~/` truncates toward zero, so `-1 ~/ 64` is `0` and the tile to
  /// the left of the origin would share a key with the tile at it. A pan in
  /// either direction reaches negative keys within one tile of the anchor.
  static int _floorDiv(int a, int b) => (a / b).floor();
}
```

`math` is unused for now; do not import it until Task 10 needs it — `unused_import` is an error in this package.

- [ ] **Step 4: Export it**

In `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`, add in alphabetical position:

```dart
export 'src/tile_cache.dart';
```

- [ ] **Step 5: Run it and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_grid_test.dart
```

- [ ] **Step 6: Fire two mutants by hand**

```sh
cp lib/src/tile_cache.dart /tmp/tile_cache.dart.bak
```

**M10's arithmetic half:** delete the rounding in `quantiseCamera` (`final e = m.e;`). The whole-device-pixel assertions must go red.

**The negative-key mutant:** change `_floorDiv` to `a ~/ b`. **The `visibleKeys` tests must go red once the pan reaches a negative key**, and a key is negative only when the anchor-relative device delta is *positive* — that is, when the camera's `e`/`f` moved **up**, not down. A pan that only subtracts from `e` and `f` drives `left` and `top` further positive and never reaches a negative key at all, which makes the test degenerate rather than passing.

> **Corrected 2026-08-24, mid-execution.** An earlier revision said the
> `abut exactly` test would redden too. **It cannot**: `destRectFor` never
> calls `_floorDiv` — only `visibleKeys` does — so no pan and no key choice
> makes that test sensitive to this mutant. It tests a distinct property and
> is correct as written. The earlier revision also chose a pan sign that could
> never reach a negative key; if the mutant survives, the required response is
> to fix the **test**, and the fix is the pan's sign, not its size.

```sh
cp /tmp/tile_cache.dart.bak lib/src/tile_cache.dart && rm /tmp/tile_cache.dart.bak
```

- [ ] **Step 7: Green and commit**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/lib/src/tile_cache.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/tile_grid_test.dart
git commit -m "feat: the tile grid, and the quantisation the exactness claim rests on

A world-anchored tile lands at a fractional device offset after an arbitrary
pan, and settling never returns the camera to the one the grid was anchored at
-- the key excludes translation by design and a pan invalidates nothing. So the
frame's screen translation is quantised to whole device pixels on both the
tiled and the live path, and every tile destination is integral at every
camera.

Nothing here draws. The arithmetic is the whole of the exactness claim and it
fails on its own: destinations across twenty-three awkward pans, adjacent tiles
abutting with no gap and no overlap, and a scale test that is exact rather than
tolerant because a tolerant one would replay a generation baked at a different
dash phase.

Floor division, not truncation: -1 ~/ 64 is 0 in Dart, which would give the
tile left of the origin the same key as the tile at it, one tile into any pan."
```

---

## Task 4: `TileCache` bakes and blits, and draws live where it cannot

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Test: `packages/jet_cad_2d_flutter/test/tile_cache_test.dart` (create — the criteria land in Task 5; this task's tests are structural)

**Interfaces:**
- Consumes: `TileGrid`, `quantiseCamera`, `DraftPainter.debugRebaseOrigin`.
- Produces: `TileCache.paintFrame`, `TileCache.bakeCount`, `blitCount`, `liveDrawCount`, `liveTileCount`, `debugBlitPaint`, `dispose`.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d_flutter/test/tile_cache_test.dart` with the structural half only:

```dart
// What the cache does, counted. Criteria 1-4 arrive in Tasks 5 and 6 and
// compare pixels; these three ask whether the machine ran at all, which is
// what makes a later zero-difference result mean something rather than
// meaning nothing was drawn -- the trap the 3g spike walked into with Probe C.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/tile_fixture.dart';

void main() {
  test('a first frame bakes up to its budget and draws the rest live',
      () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 3);
    addTearDown(rig.dispose);

    rig.paintOnce();

    expect(rig.cache.bakeCount, 3, reason: 'the budget, not the visible set');
    expect(rig.cache.blitCount, 3, reason: 'what was baked is what blitted');
    expect(rig.cache.liveDrawCount, 1,
        reason: 'one walk for the union of the uncovered rects, not one per '
            'tile: 154 painter invocations in a frame would be slower than '
            'the live path this cache replaces');
  });

  test('a warm frame bakes nothing and blits the whole visible set', () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);

    rig.paintOnce();
    final visible = rig.cache.blitCount;
    expect(visible, greaterThan(30),
        reason: 'anti-degenerate clause 3: a single-tile viewport would make '
            'every grid and seam claim vacuous');

    rig.cache.resetCounters();
    rig.paintOnce();

    expect(rig.cache.bakeCount, 0);
    expect(rig.cache.blitCount, visible);
    expect(rig.cache.liveDrawCount, 0, reason: 'nothing left uncovered');
  });

  test('the blit Paint is one instance for the life of the cache', () {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    final first = rig.cache.debugBlitPaint;
    rig.paintOnce();
    expect(identical(rig.cache.debugBlitPaint, first), isTrue,
        reason: 'criterion 13, and the shape VerticesDrawSink.debugPaint '
            'already uses: debugCapacityVertices cannot see a Paint');
  });
}
```

- [ ] **Step 2: Write the fixture rig**

Create `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`:

```dart
// One document, one camera, one cache, and a `Canvas` that goes nowhere.
//
// The camera is built by hand and is **not** `ViewportTransform.fit`:
// anti-degenerate clause 2. `fit` applies a 0.95 margin
// (`viewport_transform.dart:32`) and deriving an expected on-screen quantity
// through it cost Plan 3f two tasks.
//
// The tile size is 64 device pixels, not the production 256: anti-degenerate
// clause 1. At this size a fixture cannot fit inside one tile, so every
// boundary-crossing claim is exercised by the geometry rather than by the
// author remembering to exercise it.

import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'fixtures.dart';

const Size kTileViewport = Size(400, 300);
const double kTileDpr = 2.0;

/// World == screen at scale 1.4, y flipped, offset off both axes.
///
/// Not the identity and not the origin: a fixture at the identity transform is
/// this repository's dominant failure mode, and a tile grid anchored at (0, 0)
/// would never exercise [TileGrid] negative keys.
ViewportTransform tileCamera() => ViewportTransform(
    worldToScreenMatrix:
        Transform2(1.4, 0, 0, -1.4, -37.0, kTileViewport.height + 23.0));

class TileRig {
  TileRig({
    required int tileDevicePixels,
    required int tilesBakedPerFrame,
    int cacheBytes = kTileCacheBytes,
    DraftDocument? document,
  })  : measurer = FlutterTextMeasurer(),
        _ownsDocument = document == null {
    doc = document ?? crossingGrid(measurer);
    index = SpatialIndex(doc);
    sink = CanvasDrawSink(
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        measurer: measurer,
        textStyleOf: doc.textStyleOf);
    vertices = VerticesDrawSink(
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        devicePixelRatio: kTileDpr,
        fallback: sink);
    painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    cache = TileCache(
        tileDevicePixels: tileDevicePixels,
        tilesBakedPerFrame: tilesBakedPerFrame,
        cacheBytes: cacheBytes);
  }

  final FlutterTextMeasurer measurer;
  final bool _ownsDocument;
  late final DraftDocument doc;
  late final SpatialIndex index;
  late final CanvasDrawSink sink;
  late final VerticesDrawSink vertices;
  late final DraftPainter painter;
  late final TileCache cache;

  ViewportTransform camera = tileCamera();

  /// Paints one frame into a recorder whose picture is discarded.
  ///
  /// The picture is disposed rather than dropped: a `Picture` holds native
  /// memory past the Dart object, and leaving one alive is the "moved the
  /// leak" shape this repository's rules were written against.
  void paintOnce() {
    final recorder = PictureRecorder();
    cache.paintFrame(
      canvas: Canvas(recorder),
      viewport: kTileViewport,
      devicePixelRatio: kTileDpr,
      camera: camera,
      painter: painter,
      sink: sink,
      vertices: vertices,
    );
    recorder.endRecording().dispose();
  }

  void panBy(double dx, double dy) {
    final m = camera.worldToScreenMatrix;
    camera = ViewportTransform(
        worldToScreenMatrix:
            Transform2(m.a, m.b, m.c, m.d, m.e + dx, m.f + dy));
  }

  void zoomBy(double factor) {
    final m = camera.worldToScreenMatrix;
    camera = ViewportTransform(
        worldToScreenMatrix: Transform2(
            m.a * factor, m.b, m.c, m.d * factor, m.e, m.f));
  }

  void dispose() {
    cache.dispose();
    index.dispose();
    if (_ownsDocument) measurer.clear();
  }
}

/// A grid of lines long enough that many of them cross tile boundaries.
///
/// Anti-degenerate clause 1 is structural here: at a 64 device-pixel tile and
/// a `dpr` of 2, a tile is 32 logical pixels wide, and every line below is 90
/// logical pixels long at this camera.
DraftDocument crossingGrid(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  var handle = 1000;
  for (var i = 0; i < 12; i++) {
    final t = i * 24.0;
    addLine(doc, doc.rootHandle, Handle(handle++), 10, 10 + t, 200, 10 + t);
    addLine(doc, doc.rootHandle, Handle(handle++), 10 + t, 10, 10 + t, 200);
  }
  return doc;
}
```

If `fixtures.dart` has no `addLine` with this signature, add one there rather than inlining a local copy — the anti-degenerate rule applies to every test this plan writes, and a private fixture helper is where degenerate values hide.

- [ ] **Step 3: Run it and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
```

Expected: compile failure — `TileCache` has no members yet.

- [ ] **Step 4: Implement the cache's drawing half**

Append to `tile_cache.dart`:

```dart
/// A cache of rasterised viewport tiles.
///
/// **What it is for, in numbers.** Plan 3d's clean rows put a 500,000-entity
/// frame at 17.79 ms of build and 22.40 ms of raster — 40.27 ms of `totalSpan`
/// against a 16.67 ms budget. The 2026-08-23 spike's Probe D measured the same
/// frame drawn from a rasterised blit at **1.61 ms**, and the blit is
/// corpus-independent: 0.97 ms of raster at 50,000 entities and at 500,000
/// alike. The margin therefore widens with the drawing.
///
/// **What it is not for.** Rebaking every frame — the zoom regime — was
/// measured at 32.06 ms against the same 40.27, an 11-26% saving across the
/// two corpus sizes. This is a pan-and-settle optimisation and nothing else.
class TileCache {
  TileCache({
    this.tileDevicePixels = kTileDevicePixels,
    this.tilesBakedPerFrame = kTilesBakedPerFrame,
    this.cacheBytes = kTileCacheBytes,
  });

  final int tileDevicePixels;
  final int tilesBakedPerFrame;
  final int cacheBytes;

  TileGrid? _grid;
  final Map<TileKey, Image> _tiles = <TileKey, Image>{};

  /// One `Paint` for the life of the cache.
  ///
  /// `FilterQuality.none`: every blit is a 1:1 texel-to-pixel copy by
  /// construction, so a filter has nothing to interpolate and would only cost
  /// a sampler. The carry-over path in Task 9 is the one exception and states
  /// its own.
  final Paint _blitPaint = Paint()..filterQuality = FilterQuality.none;

  int _bakes = 0;
  int _blits = 0;
  int _liveDraws = 0;
  int _generation = 0;

  /// Tiles rasterised since [resetCounters].
  int get bakeCount => _bakes;

  /// `drawImageRect` calls issued since [resetCounters].
  int get blitCount => _blits;

  /// Frames that fell back to a live walk for an uncovered region.
  ///
  /// **Not zero in normal operation**, and a design that expected it to be
  /// would ship an intermittent blank strip: the fallback fires on the first
  /// frame, on a pan past the retained ring, and after eviction reclaims tiles
  /// the camera returns to.
  int get liveDrawCount => _liveDraws;

  int get liveTileCount => _tiles.length;

  int get generation => _generation;

  /// The blit `Paint`'s identity, for criterion 13.
  ///
  /// Exposed the way `VerticesDrawSink.debugPaint` is, and for the same
  /// reason: `paint_allocation_test.dart` reads
  /// `VerticesDrawSink.debugCapacityVertices` and that field can see neither a
  /// `Paint` nor a `Rect`. `STATUS.md` records why there is no heap-level
  /// instrument on this side — trap 5 — so the allocation criterion is a field
  /// read or it is prose.
  Paint get debugBlitPaint => _blitPaint;

  void resetCounters() {
    _bakes = 0;
    _blits = 0;
    _liveDraws = 0;
  }

  void paintFrame({
    required Canvas canvas,
    required Size viewport,
    required double devicePixelRatio,
    required ViewportTransform camera,
    required DraftPainter painter,
    required CanvasDrawSink sink,
    required VerticesDrawSink? vertices,
  }) {
    final quantised = quantiseCamera(camera, devicePixelRatio);
    final grid = _gridFor(quantised, devicePixelRatio);

    // Derived once and handed to every bake. Rebasing is frame-global by
    // construction; a per-tile origin would give each tile its own
    // quantisation step and `float32` residuals the live frame does not have.
    final origin = rebaseOriginFor(quantised.visibleWorld(viewport));

    var budget = tilesBakedPerFrame;
    Rect? uncovered;

    for (final key in grid.visibleKeys(quantised, viewport)) {
      var image = _tiles[key];
      if (image == null && budget > 0) {
        image = _bake(key, grid, painter, sink, vertices, origin);
        _tiles[key] = image;
        budget--;
      }
      final dest = grid.destRectFor(key, quantised);
      if (image == null) {
        uncovered = uncovered == null ? dest : uncovered.expandToInclude(dest);
        continue;
      }
      canvas.drawImageRect(image, _tileSourceRect, dest, _blitPaint);
      _blits++;
    }

    if (uncovered == null) return;
    // One walk for the union, not one per tile: at 256 px a full visible set is
    // 154 tiles, and 154 painter invocations in one frame would be slower than
    // the live path this cache exists to replace. Clipped, so the covered tiles
    // keep the pixels they just blitted.
    canvas.save();
    canvas.clipRect(uncovered, doAntiAlias: false);
    _drawInto(canvas, viewport, quantised, painter, sink, vertices, origin,
        null);
    canvas.restore();
    _liveDraws++;
  }

  Rect get _tileSourceRect => Rect.fromLTWH(
      0, 0, tileDevicePixels.toDouble(), tileDevicePixels.toDouble());

  TileGrid _gridFor(ViewportTransform quantised, double devicePixelRatio) {
    final grid = _grid;
    if (grid != null &&
        grid.devicePixelRatio == devicePixelRatio &&
        grid.tileDevicePixels == tileDevicePixels &&
        grid.matchesScale(quantised)) {
      return grid;
    }
    _retireGeneration();
    final fresh = TileGrid(
        anchor: quantised,
        devicePixelRatio: devicePixelRatio,
        tileDevicePixels: tileDevicePixels);
    _grid = fresh;
    _generation++;
    return fresh;
  }

  /// Drops the current generation's tiles. Task 9 gives this a carry-over.
  void _retireGeneration() {
    for (final image in _tiles.values) {
      image.dispose();
    }
    _tiles.clear();
  }

  Image _bake(
    TileKey key,
    TileGrid grid,
    DraftPainter painter,
    CanvasDrawSink sink,
    VerticesDrawSink? vertices,
    Vector2 origin,
  ) {
    final side = tileDevicePixels / grid.devicePixelRatio;
    final recorder = PictureRecorder();
    final into = Canvas(recorder);
    into.scale(grid.devicePixelRatio);
    // **A hard clip on the pixel grid, and the flag is the point.** An entity
    // crossing a tile boundary is drawn into both tiles. If the clip edge were
    // antialiased, each tile would contribute partial coverage along the shared
    // edge and their `source-over` would not reach full coverage: a seam. A
    // hard clip is exact for strokes, fills and glyphs alike, because the
    // geometry's own rasterisation is untouched and each tile keeps exactly
    // the pixels it owns.
    into.clipRect(Rect.fromLTWH(0, 0, side, side), doAntiAlias: false);
    _drawInto(into, Size(side, side), grid.bakeCameraFor(key), painter, sink,
        vertices, origin, null);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(tileDevicePixels, tileDevicePixels);
    picture.dispose();
    _bakes++;
    return image;
  }

  void _drawInto(
    Canvas canvas,
    Size size,
    ViewportTransform camera,
    DraftPainter painter,
    CanvasDrawSink sink,
    VerticesDrawSink? vertices,
    Vector2 origin,
    void Function(Handle handle)? onVisit,
  ) {
    painter.debugRebaseOrigin = origin;
    painter.debugOnVisit = onVisit;
    try {
      sink.canvas = canvas;
      if (vertices == null) {
        painter.paint(sink, camera, size);
        return;
      }
      vertices.canvas = canvas;
      painter.paint(vertices, camera, size);
      // The flush is here for the reason `_DraftCustomPainter` puts it there:
      // it is a fact about this sink, not about the walk.
      vertices.flush();
    } finally {
      // Restored even on a throw: a painter left with a stale origin would
      // draw the *next* frame against a tile's rebase point.
      painter.debugRebaseOrigin = null;
      painter.debugOnVisit = null;
    }
  }

  void dispose() {
    _retireGeneration();
    _grid = null;
  }
}
```

Add the imports this needs at the top of the file — `package:vector_math/vector_math_64.dart hide Aabb2, Colors` for `Vector2`, and the sibling imports for `camera_controller.dart`, `canvas_draw_sink.dart`, `draft_painter.dart`, `vertices_draw_sink.dart`. **`unused_import` is an error here**, so add exactly what compiles.

- [ ] **Step 5: Run it and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
```

If `toImageSync` is slow enough to time the suite out, the fixture is too large — shrink `crossingGrid`, not the tile size, because the tile size is an anti-degenerate guarantee.

- [ ] **Step 6: Fire mutant M13**

```sh
cp lib/src/tile_cache.dart /tmp/tile_cache.dart.bak
```

Replace `_blitPaint` at its use site with a fresh `Paint()` per blit.

> **Corrected 2026-08-24, mid-execution.** An earlier revision expected the
> `debugBlitPaint` identity test to redden. **It does not, and cannot**: that
> getter returns the cache's own field, which the mutation never touches, so
> the assertion is a tautology. The same gap is why
> `paint_allocation_test.dart` exists beside `VerticesDrawSink.debugPaint`.
> **Use the repository's `test/support/spy_canvas.dart`** to read the `Paint`
> actually handed to `drawImageRect` and compare that to the field. Keep the
> identity test as a cheap check; the spy is the gate.

- [ ] **Step 7: Green and commit**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/lib/src/tile_cache.dart packages/jet_cad_2d_flutter/test/tile_cache_test.dart packages/jet_cad_2d_flutter/test/support/tile_fixture.dart packages/jet_cad_2d_flutter/test/support/fixtures.dart
git commit -m "feat: the cache bakes, blits, and draws live where it cannot

A tile bakes through a per-tile camera with the frame-global rebase origin
injected, hard-clipped to its own rect on the device pixel grid --
doAntiAlias: false, because an antialiased clip gives two tiles partial
coverage along a shared edge and their source-over does not reach full
coverage.

The uncovered path is not a startup special case. A tile is missing whenever no
image covers its rect, which happens on the first frame, on a pan past the
retained ring, and after eviction reclaims tiles the camera comes back to. It
draws live once for the union of those rects rather than once per tile: 154
painter invocations in a frame would be slower than the live path this replaces.

Counters, not pixels, in this task. A later zero-difference result means
nothing unless something is known to have drawn -- the trap the spike walked
into with Probe C."
```

---

## Task 5: The live-versus-tiled ink instrument, and criteria 1 and 2

**Why a new instrument:** `measureAgreement`'s vertices arm goes through the repository's **software rasterizer**, not a `Canvas` (`test/support/sink_comparison.dart`), so it never executes a `drawPicture` or a `drawImageRect` and cannot see a tile at all.

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`
- Modify: `packages/jet_cad_2d_flutter/test/tile_cache_test.dart`

**Interfaces:**
- Consumes: `TileRig`.
- Produces: `expectTiledEqualsLive(TileRig rig)` — asserts zero stray and zero uncovered pixels and returns the ink count for the caller to floor.

- [ ] **Step 1: Write the instrument**

Create `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`:

```dart
// Live frame against tiled frame, byte for byte.
//
// **Why not `measureAgreement`.** That instrument's vertices arm rasterises in
// Dart (`support/sink_comparison.dart`), so it never reaches a `Canvas` and
// never executes a `drawImageRect`. A tile is invisible to it.
//
// **Why zero rather than a tolerance.** `quantiseCamera` puts every tile
// destination on whole device pixels at every camera, so a blit is a 1:1
// texel-to-pixel copy and there is nothing for a tolerance to absorb. A
// tolerance here would hide exactly the defects the criteria exist to catch.
//
// **What this cannot prove.** Software Skia does not antialias `drawVertices`
// at all — `drawvertices_antialiasing_test.dart` pins that, in its own words
// as "a fact about `flutter_test`'s software Skia, not about this codebase" —
// so this instrument cannot produce an antialiased seam and a zero result here
// is partly a property of the instrument. It proves geometric completeness:
// no pixel missing, none drawn twice, no clipping arithmetic error. Accepted
// gap G1 owns the rest, and mutant M3 is deferred to it. **M15 is the mutant
// this instrument fires**, and it moves pixels software Skia renders perfectly
// well.

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'tile_fixture.dart';

class InkReport {
  const InkReport({
    required this.liveInk,
    required this.tiledInk,
    required this.strayPixels,
    required this.uncoveredPixels,
    required this.differingPixels,
  });

  /// Non-transparent pixels in the live capture.
  final int liveInk;
  final int tiledInk;

  /// Tiled pixels with ink where live has none.
  final int strayPixels;

  /// Live pixels with ink where tiled has none.
  final int uncoveredPixels;

  /// Pixels whose four bytes differ at all, stray and uncovered included.
  final int differingPixels;

  @override
  String toString() => 'InkReport(live: $liveInk, tiled: $tiledInk, '
      'stray: $strayPixels, uncovered: $uncoveredPixels, '
      'differing: $differingPixels)';
}

Future<Uint8List> _capture(void Function(Canvas canvas) draw) async {
  final width = (kTileViewport.width * kTileDpr).round();
  final height = (kTileViewport.height * kTileDpr).round();
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(kTileDpr);
  canvas.clipRect(Offset.zero & kTileViewport);
  draw(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData();
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Paints [rig] both ways and compares.
///
/// The live arm goes through the **quantised** camera, not the raw one: that is
/// the rule, not a concession to the tiled arm. `DraftCanvas` quantises the
/// camera it hands the live path for exactly this reason, so the two arms are
/// the same drawing seen twice and not two different drawings.
Future<InkReport> measureTiledAgreement(TileRig rig) async {
  final quantised = quantiseCamera(rig.camera, kTileDpr);

  final live = await _capture((canvas) {
    rig.painter.debugRebaseOrigin =
        rebaseOriginFor(quantised.visibleWorld(kTileViewport));
    rig.sink.canvas = canvas;
    rig.vertices.canvas = canvas;
    rig.painter.paint(rig.vertices, quantised, kTileViewport);
    rig.vertices.flush();
    rig.painter.debugRebaseOrigin = null;
  });

  final tiled = await _capture((canvas) {
    rig.cache.paintFrame(
      canvas: canvas,
      viewport: kTileViewport,
      devicePixelRatio: kTileDpr,
      camera: rig.camera,
      painter: rig.painter,
      sink: rig.sink,
      vertices: rig.vertices,
    );
  });

  var liveInk = 0, tiledInk = 0, stray = 0, uncovered = 0, differing = 0;
  for (var i = 0; i < live.length; i += 4) {
    final liveHasInk = live[i + 3] != 0;
    final tiledHasInk = tiled[i + 3] != 0;
    if (liveHasInk) liveInk++;
    if (tiledHasInk) tiledInk++;
    if (tiledHasInk && !liveHasInk) stray++;
    if (liveHasInk && !tiledHasInk) uncovered++;
    if (live[i] != tiled[i] ||
        live[i + 1] != tiled[i + 1] ||
        live[i + 2] != tiled[i + 2] ||
        live[i + 3] != tiled[i + 3]) {
      differing++;
    }
  }
  return InkReport(
      liveInk: liveInk,
      tiledInk: tiledInk,
      strayPixels: stray,
      uncoveredPixels: uncovered,
      differingPixels: differing);
}

/// The gate. Zero stray, zero uncovered, zero differing — and a real drawing.
Future<InkReport> expectTiledEqualsLive(TileRig rig,
    {int minimumInk = 500}) async {
  final report = await measureTiledAgreement(rig);
  // The floor first. A comparison of two blank captures agrees perfectly and
  // proves nothing, which is the failure mode this whole plan's spike named.
  expect(report.liveInk, greaterThan(minimumInk),
      reason: 'the live arm must actually draw: $report');
  expect(report.tiledInk, greaterThan(minimumInk),
      reason: 'the tiled arm must actually draw: $report');
  expect(report.strayPixels, 0, reason: '$report');
  expect(report.uncoveredPixels, 0, reason: '$report');
  expect(report.differingPixels, 0, reason: '$report');
  return report;
}
```

- [ ] **Step 2: Write criteria 1 and 2 as failing tests**

Append to `test/tile_cache_test.dart`:

```dart
  test('criterion 1: a warm tiled frame equals the live frame exactly',
      () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    // Warm first: criterion 1 is about a settled frame, and the uncovered path
    // is criterion 2's and Task 10's business.
    rig.paintOnce();
    await expectTiledEqualsLive(rig);
  });

  test('criterion 1: and it still holds after twenty-three awkward pans',
      () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    for (var i = 0; i < 23; i++) {
      // Not whole pixels, and not a whole tile: the claim is that quantisation
      // makes an arbitrary pan exact, so an arbitrary pan is what tests it.
      rig.panBy(-7.37, -3.19);
      rig.paintOnce();
      await expectTiledEqualsLive(rig);
    }
  });

  test('criterion 2: a fixture crossing tile boundaries still matches',
      () async {
    // `crossingGrid` is 190 world units per line, which at this camera's 1.4
    // scale is 266 logical pixels against a 32-logical-pixel tile: every line
    // spans about eight tiles. The seam is exercised by geometry, not by
    // intent -- anti-degenerate clause 1.
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    final report = await expectTiledEqualsLive(rig);
    expect(report.liveInk, greaterThan(5000),
        reason: 'a fixture this small would make the seam claim thin: $report');
  });
```

- [ ] **Step 3: Run them and watch them fail or pass, and read which**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
```

These may pass on the first run, because Task 4 already implemented the mechanism. **That is not a reason to skip Step 4.** A test that has never been red proves nothing; Step 4 is where it earns its place.

- [ ] **Step 4: Fire mutants M15 and M17**

```sh
cp lib/src/tile_cache.dart /tmp/tile_cache.dart.bak
```

**M15** — offset a tile's bake camera by one device pixel. In `TileGrid.bakeCameraFor`, change `m.e - key.x * _tileLogical` to `m.e - key.x * _tileLogical + 1 / devicePixelRatio`. Criterion 2 must go red with non-zero stray *and* uncovered counts. Record the numbers.

**M17** — drop the injected origin. In `_bake`, pass `Vector2.zero()` instead of `origin`.

> **Corrected 2026-08-24, mid-execution.** An earlier revision expected
> criterion 1 to go red, and offered "move the fixture out to 4.5e6" as the
> remedy if it did not. **Neither works, and the reason is algebraic.** The
> painter pushes the rebase origin *as the residual*
> (`draft_painter.dart:605,742`) and `VerticesDrawSink` applies that residual
> in `Float64` (`vertices_draw_sink.dart:322-323`) before its `Float32` store,
> so `(screen - origin) + origin = screen` exactly and the pixel cannot depend
> on the origin at any magnitude. **Fire M17 against a wiring test instead**:
> subclass `VerticesDrawSink` and read the coordinate `_bake` actually hands
> it, the way `large_coordinate_test.dart` and `draft_painter_rebase_test.dart`
> already do. Criteria 1 and 2 stand on their own; they simply do not gate this
> mutant.

Restore from the copy after each.

- [ ] **Step 5: Green and commit**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/test
git commit -m "test: criteria 1 and 2 -- the tiled frame equals the live frame exactly

Zero stray, zero uncovered, zero differing pixels, and an ink floor on both
arms first: two blank captures agree perfectly and prove nothing, which is the
failure mode this plan's own spike walked into.

A new instrument, because measureAgreement's vertices arm rasterises in Dart
and never reaches a Canvas, so it cannot see a drawImageRect at all.

The exactness holds after twenty-three pans of 7.37 by 3.19 logical pixels --
arbitrary on purpose, since the claim is that quantisation makes an arbitrary
pan exact.

What this cannot prove is written into the instrument's header. Software Skia
antialiases no drawVertices, so it cannot produce an antialiased seam and a
zero here is partly a property of the instrument. It proves geometric
completeness; G1 owns the rest and M3 is deferred to it. M15 is the mutant this
one fires."
```

---

## Task 6: Criteria 3 and 4 — text and translucency survive the texture round trip

**Files:**
- Modify: `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`, `packages/jet_cad_2d_flutter/test/tile_cache_test.dart`

**Interfaces:** consumes Task 5's `expectTiledEqualsLive`.

- [ ] **Step 1: Add two fixtures**

Append to `tile_fixture.dart`:

```dart
/// Labels large enough to clear `kMinTextCapPixels` and long enough to cross
/// tile boundaries.
///
/// Text is the one content type that does not reach the vertices sink: it
/// falls back to `CanvasDrawSink`, which flushes the batch first. A tile bake
/// therefore exercises a mid-picture flush, and criterion 3 is the only place
/// this plan sees it.
DraftDocument crossingLabels(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  var handle = 1000;
  for (var row = 0; row < 6; row++) {
    // 14 world units of cap height at scale 1.4 is 19.6 logical pixels, well
    // clear of the 3.0 default, and `culledTextCount` is asserted rather than
    // assumed below.
    addText(doc, doc.rootHandle, Handle(handle++), 'SECTION-A$row', 20,
        30 + row * 40.0, 14);
  }
  return doc;
}

/// Overlapping translucent strokes, all inside one tile and also across one.
///
/// Transparency rides on the vertex colour, and a tile is baked to a
/// transparent-backed `Image` and composited with `srcOver`. Both halves have
/// to survive, and a blend-mode mistake shows up as a uniform shift rather
/// than as a missing shape -- which is why the criterion compares bytes and
/// not ink counts.
DraftDocument translucentOverlap(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  var handle = 1000;
  for (var i = 0; i < 10; i++) {
    final line = addLine(doc, doc.rootHandle, Handle(handle++), 20,
        30 + i * 6.0, 220, 150 - i * 6.0);
    // 60% transparent, so an overlap is visibly darker than a single stroke
    // and a lost alpha is a byte difference on thousands of pixels.
    setTransparency(doc, line, 60);
  }
  return doc;
}
```

`addText` exists at `fixtures.dart:266`. **`setTransparency` does not exist, and the `SetComponentCommand` route an earlier revision suggested is wrong.**

> **Corrected 2026-08-24, mid-execution.** Transparency is a field on the
> `EntityRecord` itself (`entity_store.dart:52`), supplied at creation — not a
> component. **Give `addLine` an optional `transparency` parameter defaulting
> to `0`**, so every existing caller is unaffected, and pass a non-zero value
> from `translucentOverlap`. Note while you are there that `fixtures.dart`
> hardcodes `transparency: 0` at `:31` and `:286`: that is the multiplicative
> identity for this channel and it is exactly the degenerate default the
> anti-degenerate rule exists to catch. Leave those defaults in place — other
> tests depend on them — but do not inherit one.

- [ ] **Step 2: Write the two criteria**

Append to `test/tile_cache_test.dart`:

```dart
  test('criterion 3: text survives the tile round trip', () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: crossingLabels(measurer));
    addTearDown(rig.dispose);

    rig.paintOnce();
    // The fixture proves it drew text before any pixel is compared: a
    // level-of-detail cull would produce a smaller, self-consistent, wrong
    // picture that agreed with itself perfectly.
    expect(rig.painter.textOpCount, 6);
    expect(rig.painter.culledTextCount, 0);
    await expectTiledEqualsLive(rig);
  });

  test('criterion 4: overlapping translucent strokes composite identically',
      () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: translucentOverlap(measurer));
    addTearDown(rig.dispose);

    rig.paintOnce();
    await expectTiledEqualsLive(rig);
  });
```

- [ ] **Step 3: Run, then fire M14 and M11**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
cp lib/src/tile_cache.dart /tmp/tile_cache.dart.bak
```

**M14** — skip text in a bake. In `_bake`, construct the draw with text off. The simplest faithful mutation is to set `painter`'s text off for the bake only; if `drawText` is `final`, mutate `_drawText`'s entry guard in `draft_painter.dart` instead and copy *that* file aside. Criterion 3 must go red with a large `uncoveredPixels` count.

**M11** — blit with `BlendMode.src`. Add `..blendMode = BlendMode.src` to `_blitPaint`. Criterion 4 must go red. Criterion 1 probably goes red too; note both, and note that M11 is *named* for criterion 4 because alpha is what it targets.

Restore from the copy after each.

- [ ] **Step 4: Green and commit**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/test
git commit -m "test: criteria 3 and 4 -- text and alpha survive the texture

Text is the one content type that does not reach the vertices sink: it falls
back to CanvasDrawSink and flushes the batch first, so a tile bake exercises a
mid-picture flush that nothing else in this plan sees. The fixture asserts
textOpCount and culledTextCount before any pixel is compared, because a
level-of-detail cull produces a smaller picture that agrees with itself
perfectly.

Transparency is 60, not 0. Zero is the identity and would make the criterion
degenerate in exactly the way this repository's rule names."
```

---

## Task 7: Invalidation — two directions, five change arms, and the node list

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Create: `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart`

**Interfaces:**
- Consumes: `DraftPainter.debugOnVisit`, `TileGrid.destRectFor`.
- Produces: `TileCache.applyChange(DocChange change, DraftDocument document)`, `TileCache.invalidationCount`, `TileCache.tilesHolding(Handle)` (test-only).

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart`:

```dart
// Criteria 5, 6 and 9.
//
// `DocChange` has five subclasses and five emitters -- `CommandApplied`,
// `CommandUndone`, `CommandRedone`, `DocumentLoaded` and `DocumentPurged`, at
// `undo.dart:112`, `:140`, `:161`, `:169` and `:178`. A cache that handles
// apply and undo and forgets redo shows stale pixels after every redo while
// passing an undo-only gate, so all five are here.
//
// Every fixture reaches a definition, per anti-degenerate clause 4, and the
// matrix includes an instance transform and its undo, per clause 5:
// `TransformNodeCommand` reports only the moved node's handle
// (`commands.dart:304`) and the leaves it moved keep their own.

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/fixtures.dart';
import 'support/tile_fixture.dart';

/// A root leaf on the left, and a definition placed twice: once on the left,
/// once far to the right. Left and right are many tiles apart at a 64
/// device-pixel tile, so "did the other side survive" is a real question.
DraftDocument instancedFixture(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  addLine(doc, doc.rootHandle, const Handle(1001), 20, 20, 60, 60);
  addDefinition(doc, const Handle(210), 'PLATE');
  addLine(doc, const Handle(210), const Handle(1002), 0, 0, 25, 25);
  addInstance(doc, doc.rootHandle, const Handle(300), const Handle(210),
      Transform2(1, 0, 0, 1, 30, 120));
  addInstance(doc, doc.rootHandle, const Handle(301), const Handle(210),
      Transform2(1, 0, 0, 1, 210, 120));
  return doc;
}

void main() {
  test('criterion 5: a leaf edit invalidates its own tiles and no others',
      () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: instancedFixture(measurer));
    addTearDown(rig.dispose);
    rig.paintOnce();
    final before = rig.cache.liveTileCount;
    expect(before, greaterThan(30));

    final holdingLeft = rig.cache.tilesHolding(const Handle(1001));
    expect(holdingLeft, isNotEmpty, reason: 'the fixture must be findable');

    rig.doc.commands.execute(SetEntityGeometryCommand(
        handle: const Handle(1001),
        coords: Float64List.fromList(<double>[20, 20, 55, 58])));
    rig.cache.applyChange(
        CommandApplied(label: 'move', touched: {const Handle(1001)}),
        rig.doc);

    expect(rig.cache.liveTileCount, lessThan(before),
        reason: 'something was dropped');
    expect(rig.cache.liveTileCount, greaterThan(before - 12),
        reason: 'the far side of the drawing must survive: an edit that drops '
            'the generation passes every correctness criterion and destroys '
            'the reason the cache exists');
    for (final key in holdingLeft) {
      expect(rig.cache.holds(key), isFalse, reason: 'old position, $key');
    }
  });

  test('criterion 5: a dragged instance drops the tiles it left', () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: instancedFixture(measurer));
    addTearDown(rig.dispose);
    rig.paintOnce();

    // The node handle, not a leaf handle. This is the whole of M16.
    final holding = rig.cache.tilesHolding(const Handle(300));
    expect(holding, isNotEmpty,
        reason: 'a tile that never recorded the node cannot find the pixels '
            'a drag left behind, and the ghost is invisible to every '
            'leaf-handle test');

    rig.doc.commands.execute(TransformNodeCommand(
        handle: const Handle(300), transform: Transform2(1, 0, 0, 1, 30, 240)));
    rig.cache.applyChange(
        CommandApplied(label: 'drag', touched: {const Handle(300)}), rig.doc);

    for (final key in holding) {
      expect(rig.cache.holds(key), isFalse, reason: 'ghost at $key');
    }
  });

  test('criterion 6: a definition edit drops the generation, and less does not',
      () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: instancedFixture(measurer));
    addTearDown(rig.dispose);
    rig.paintOnce();
    expect(rig.cache.liveTileCount, greaterThan(30));

    // A leaf *inside* the definition. Anti-degenerate clause 4: a root-only
    // fixture never reaches this path at all.
    rig.doc.commands.execute(SetEntityGeometryCommand(
        handle: const Handle(1002),
        coords: Float64List.fromList(<double>[0, 0, 40, 12])));
    rig.cache.applyChange(
        CommandApplied(label: 'edit block', touched: {const Handle(1002)}),
        rig.doc);

    expect(rig.cache.liveTileCount, 0,
        reason: 'a definition edit changes every instance of it, so tile-level '
            'invalidation by definition is exact rather than coarse');
  });

  test('criterion 9: all five change arms, none omitted', () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);

    Future<int> tilesAfter(DocChange change) async {
      final rig = TileRig(
          tileDevicePixels: 64,
          tilesBakedPerFrame: 1000,
          document: instancedFixture(measurer));
      addTearDown(rig.dispose);
      rig.paintOnce();
      expect(rig.cache.liveTileCount, greaterThan(30));
      rig.cache.applyChange(change, rig.doc);
      return rig.cache.liveTileCount;
    }

    const touched = {Handle(1002)};  // definition-owned: drops everything
    expect(await tilesAfter(const CommandApplied(label: 'a', touched: touched)),
        0);
    expect(await tilesAfter(const CommandUndone(label: 'a', touched: touched)),
        0);
    expect(
        await tilesAfter(const CommandRedone(label: 'a', touched: touched)), 0,
        reason: 'the arm an undo-only gate never sees');
    expect(await tilesAfter(const DocumentLoaded()), 0);
    expect(await tilesAfter(const DocumentPurged()), 0,
        reason: 'a purge rewrites the entity store wholesale');
    expect(
        await tilesAfter(
            const CommandApplied(label: 'whole document', touched: {})),
        0,
        reason: 'DocChange documents an empty set as "the whole document '
            'changed" (doc_change.dart:11-12)');
  });
}
```

Correct the command constructor calls against `commands.dart` before running — the tree is the authority.

- [ ] **Step 2: Run it and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_invalidation_test.dart
```

- [ ] **Step 3: Implement**

In `tile_cache.dart`, hold a visit list per tile and switch on all five arms:

```dart
  /// What each tile baked: every leaf drawn and every container descended,
  /// ascending, for a binary search on change.
  ///
  /// **Both halves, and the node half is not a refinement.**
  /// `TransformNodeCommand` reports only the moved node's handle
  /// (`commands.dart:304`); the leaves it moved keep their own and appear
  /// nowhere in `touched`. A tile recording leaves alone cannot find the
  /// pixels a drag left behind.
  final Map<TileKey, Uint32List> _baked = <TileKey, Uint32List>{};

  int _invalidations = 0;
  int get invalidationCount => _invalidations;

  bool holds(TileKey key) => _tiles.containsKey(key);

  /// Every live tile whose bake touched [handle]. Test-only.
  List<TileKey> tilesHolding(Handle handle) => [
        for (final entry in _baked.entries)
          if (_contains(entry.value, handle.value)) entry.key
      ];

  static bool _contains(Uint32List sorted, int value) {
    var lo = 0, hi = sorted.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final at = sorted[mid];
      if (at == value) return true;
      if (at < value) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return false;
  }

  void applyChange(DocChange change, DraftDocument document) {
    switch (change) {
      // A purge rewrites the entity store's slots wholesale and a load
      // replaces the document; neither leaves anything worth keeping.
      case DocumentLoaded():
      case DocumentPurged():
        _dropEverything();
      case CommandApplied(:final touched):
      case CommandUndone(:final touched):
      case CommandRedone(:final touched):
        if (touched.isEmpty) {
          // `DocChange.touched` is documented as empty when the whole document
          // changed (`doc_change.dart:11-12`).
          _dropEverything();
          return;
        }
        _invalidateTouched(touched, document);
    }
  }

  void _invalidateTouched(Set<Handle> touched, DraftDocument document) {
    // **A definition edit drops the generation.** If a tile baked a definition
    // and that definition changed, every instance of it in that tile changed,
    // so invalidation by definition is exact at tile granularity. The one case
    // it does not cover -- a definition whose content bounds grew, spilling an
    // instance into a tile that never baked it -- is why this is a generation
    // drop rather than a per-tile pass. A definition edit is a block edit, not
    // ordinary drawing.
    for (final handle in touched) {
      if (_isDefinitionOwned(document, handle)) {
        _dropGeneration();
        return;
      }
    }

    final grid = _grid;
    if (grid == null) return;
    final doomed = <TileKey>{};

    // Direction one: the old position. `DocChange` carries no previous
    // geometry, and this is why each tile records what it baked.
    for (final key in _baked.keys) {
      final list = _baked[key]!;
      for (final handle in touched) {
        if (_contains(list, handle.value)) {
          doomed.add(key);
          break;
        }
      }
    }

    // Direction two: the new position. Both are needed, for the reason
    // `_letBoundRecede` exists in the index.
    for (final handle in touched) {
      final box = _worldBoxOf(document, handle);
      if (box == null || box.isEmpty) continue;
      for (final key in _baked.keys) {
        if (doomed.contains(key)) continue;
        if (_worldRectOf(key, grid).intersects(box)) doomed.add(key);
      }
    }

    for (final key in doomed) {
      _tiles.remove(key)?.dispose();
      _baked.remove(key);
      _invalidations++;
    }
  }
```

`_isDefinitionOwned`, `_worldBoxOf` and `_worldRectOf` are the three helpers.

> **Four corrections from execution, 2026-08-24. Each was found by running
> something, and each would have shipped a silently wrong gate.**
>
> 1. **`_isDefinitionOwned` must climb the ancestor chain.** The one-step test
>    `tree.definition(entities.ownerAt(slot)) != null` is **wrong for a leaf
>    owned by a group that is itself inside a definition** — the owner is the
>    group, and `tree.definition(group)` is null. Climb with `ancestorsOf`.
>    Note that `ancestorsOf` never returns the definition itself, so the
>    definition is the chain-top's `parent`.
> 2. **`definitionBounds` returns an empty box for an instance handle, with no
>    error.** `_childrenOf` (`draft_document.dart:331-341`) matches `GroupNode`
>    and otherwise falls to `tree.definition(container)?.children ?? const []`;
>    an `InstanceNode` is neither, so it yields nothing and the union stays
>    `Aabb2.empty()`. Direction two would have **skipped every instance and
>    dropped no tile**, while direction one kept the tests green. Pass the
>    instance's `definition` explicitly.
> 3. **The brief's leaf edit cannot separate the two directions.** Shrinking a
>    line makes the new tile set a subset of the old, so direction one alone
>    covers it and M2 survives; extending it makes the new set a superset, so
>    direction two alone covers it and M1 survives. **Only a move separates
>    them.** Every invalidation edit is now a move, and each test asserts at
>    runtime that the new and old tile sets are **disjoint** before asserting
>    anything else.
> 4. **M12 as written is a compile error, not a red test.** `DocChange` is
>    `sealed`, so deleting the `CommandRedone` arm fails to compile. Fire the
>    semantic equivalent — keep the arm and return immediately — and record the
>    compile error as the reason. Write them against the APIs the tree actually has — `DocumentTree.ancestorsOf`, `DocumentTree.definition`, `DocumentTree.accumulatedTransform`, `EntityStore.slotOf`, `EntityStore.ownerAt`, `DraftDocument.definitionBounds` — and copy `entityBounds`'s argument shape from its real call site at `container_index.dart:105-114`, which handles the `EntityKind.fill` boundary case this must handle too.

`_worldRectOf(key, grid)` inverts the anchor camera over the tile's device rect. Every corner, not two: `ViewportTransform.visibleWorld` documents why, and a rotated camera makes a two-corner box wrong.

Then in `_bake`, collect the list:

```dart
    final visited = <int>[];
    _drawInto(into, Size(side, side), grid.bakeCameraFor(key), painter, sink,
        vertices, origin, (handle) => visited.add(handle.value));
    visited.sort();
    _baked[key] = Uint32List.fromList(visited);
```

Duplicates are left in: a handle drawn twice costs one extra slot and the binary search does not care. Deduplicating would be a sweep over a list that is already the right answer.

`_dropEverything` clears the carry-over too, once Task 9 adds one; for now it is `_retireGeneration()` plus `_grid = null`. `_dropGeneration` drops the tiles and keeps the grid, so the next frame rebakes into the same lattice rather than starting a new generation — **a definition edit is not a scale change**.

- [ ] **Step 4: Run, then fire M1, M2, M5, M12 and M16**

```sh
cp lib/src/tile_cache.dart /tmp/tile_cache.dart.bak
```

| mutant | change | must redden |
|---|---|---|
| M1 | delete the old-position loop | criterion 5, both tests |
| M2 | delete the new-position loop | criterion 5's leaf test — **if it survives, the fixture's edit does not move the leaf into a new tile; widen it** |
| M5 | make `_isDefinitionOwned` return `false` always | criterion 6 |
| M12 | delete the `CommandRedone()` arm from the switch | criterion 9's redo row only |
| M16 | pass `null` for `onVisit` on nodes — collect only leaves | criterion 5's dragged-instance test |

Restore from the copy after each. Record every transcript.

- [ ] **Step 5: Green and commit**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/lib/src/tile_cache.dart packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart
git commit -m "feat: tile invalidation, in two directions and across all five change arms

DocChange has five subclasses and five emitters, and a cache that handles apply
and undo and forgets redo shows stale pixels after every redo while passing an
undo-only gate. All five are switched on exhaustively.

Each tile records what it baked: leaf handles and node handles both. The node
half is not a refinement -- TransformNodeCommand reports only the moved node's
handle and its leaves keep their own, so a tile recording leaves alone cannot
find the pixels a drag left behind, and the ghost is invisible to every
leaf-handle test.

A definition edit drops the generation rather than a set of tiles. If a tile
baked a definition and that definition changed, every instance of it in that
tile changed, so invalidation by definition is exact at tile granularity; the
generation drop covers the one case it does not, a definition whose bounds grew
and spilled an instance into a tile that never baked it."
```

---

## Task 8: `DraftCanvas` integration, and the table signal that reaches the frame

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart`
- Test: `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart` (criterion 7), `packages/jet_cad_2d_flutter/test/draft_canvas_test.dart`

**Interfaces:**
- Consumes: `TileCache`, `DocumentTables.changes`, `DocumentTables.mutationRevision`.
- Produces: `DraftCanvas({..., bool tiles = false, int tileDevicePixels = kTileDevicePixels})`.

- [ ] **Step 1: Write criterion 7 as a failing widget test**

Append to `test/tile_invalidation_test.dart`:

```dart
  testWidgets('criterion 7: a layer edit repaints and drops the generation',
      (tester) async {
    // **Two claims, and the second is the one an integer counter alone would
    // fail.** `TableSection.add` and friends emit no `DocChange`, and
    // `DraftCanvas` repaints only for `Listenable.merge([camera, _changes])`
    // where `_changes` is command-backed. A revision read inside `paint` would
    // invalidate correctly and never be reached, leaving stale pixels until an
    // unrelated camera move.
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
    addLine(doc, doc.rootHandle, const Handle(1001), 20, 20, 260, 180);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final camera = CameraController(tileCamera());
    addTearDown(camera.dispose);

    var paints = 0;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(devicePixelRatio: kTileDpr),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: kTileViewport.width,
          height: kTileViewport.height,
          child: DraftCanvas(
            document: doc,
            index: index,
            camera: camera,
            tiles: true,
            tileDevicePixels: 64,
            onPaintForTest: () => paints++,
          ),
        ),
      ),
    ));
    await tester.pump();
    final paintsBefore = paints;

    doc.tables.layers.add(LayerRecord(
      handle: const Handle(900),
      name: 'WALLS',
      // `IndexedColor`, not `DraftColor.indexed` — an earlier revision of this
      // plan guessed the latter and Task 2 corrected it against the tree. The
      // three fields below are deliberately non-default for the reason the
      // anti-degenerate rule gives.
      color: const IndexedColor(3),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: 50,
      transparency: 40,
    ));
    await tester.pump();

    expect(paints, greaterThan(paintsBefore),
        reason: 'a layer edit must cause a frame at all -- the half a counter '
            'inside paint could never reach');
  });
```

If `DraftCanvas` has no `onPaintForTest` hook, add one as a nullable `void Function()?` called at the top of `_DraftCustomPainter.paint`, documented as test-only. Counting frames is the only way to separate "invalidated correctly" from "was asked to".

- [ ] **Step 2: Wire it**

In `DraftCanvas`, add `tiles`, `tileDevicePixels` and `onPaintForTest`. In `_attach`:

```dart
    _tables = _TableListenableAdapter(widget.document.tables.changes);
    _tileCache = widget.tiles
        ? TileCache(tileDevicePixels: widget.tileDevicePixels)
        : null;
    _changes = DocChangeNotifier(widget.document,
        onChange: (change) => _tileCache?.applyChange(change, widget.document));
    // **The table adapter is here and not a nicety.** Without it a layer edit
    // causes no frame at all, so the cache's own invalidation -- correct as it
    // is -- is never reached and stale pixels sit there until the camera moves.
    _repaint = Listenable.merge([widget.camera, _changes, _tables]);
```

`_TableListenableAdapter` is a `ChangeNotifier` that subscribes to the engine's `TableListenable` and re-fires. It exists because `package:jet_cad_2d` has no Flutter dependency and declares its own two-method interface; this is where the two meet. Dispose it in `dispose()` and in `didUpdateWidget`'s teardown, beside `_changes`.

The cache also reads `document.tables.mutationRevision` once per frame and drops the generation when it moved, so a document mutated outside a `DraftCanvas` frame still invalidates. Add to `TileCache.paintFrame` a `required int tablesRevision` parameter; a change drops everything.

In `_DraftCustomPainter.paint`, the tiled branch:

```dart
  @override
  void paint(Canvas canvas, Size size) {
    onPaintForTest?.call();
    canvas.clipRect(Offset.zero & size);
    final cache = tileCache;
    if (cache != null) {
      cache.paintFrame(
        canvas: canvas,
        viewport: size,
        devicePixelRatio: devicePixelRatio,
        camera: camera.value,
        painter: painter,
        sink: sink,
        vertices: vertices,
        tablesRevision: document.tables.mutationRevision,
      );
      return;
    }
    // **The live path quantises too.** This is the rule, not a concession:
    // both paths use the same camera so the tiled frame is the live frame,
    // and a live path on the raw camera would make criterion 1 unmeetable.
    final quantised = quantiseCamera(camera.value, devicePixelRatio);
    sink.canvas = canvas;
    ...
  }
```

`didUpdateWidget` must also re-attach when `tiles` or `tileDevicePixels` changes, and `dispose` must call `_tileCache?.dispose()` — a `ui.Image` holds native memory past its Dart object.

- [ ] **Step 3: Run, then fire M8**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_invalidation_test.dart test/draft_canvas_test.dart
cp lib/src/draft_canvas.dart /tmp/draft_canvas.dart.bak
```

**M8** — drop `_tables` from the merge, keeping the revision read inside `paintFrame`. Criterion 7 must go red on the frame count while the cache's own logic stays correct. That asymmetry is the finding; record it.

- [ ] **Step 4: Green and commit**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart packages/jet_cad_2d_flutter/test
git commit -m "feat: the tiles flag, and a table edit that actually causes a frame

DraftCanvas repainted only for the camera and the command-backed change
notifier. Table mutations reach neither, so a revision counter read inside
paint would have been correct and never reached -- stale pixels until an
unrelated camera move. The engine's table Listenable is adapted here, which is
where a pure-Dart two-method interface meets Flutter's.

The live path quantises its camera too. That is the rule and not a concession:
both paths draw the same camera, so the tiled frame is the live frame."
```

---

## Task 9: The generation, the carry-over composite, and the zoom path

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Test: `packages/jet_cad_2d_flutter/test/tile_cache_test.dart`

**Interfaces:** produces `TileCache.hasCarryOver`, `TileCache.carryOverBlitCount`.

- [ ] **Step 1: Write criterion 8 as failing tests**

```dart
  test('criterion 8: a pan drops nothing and a scale change drops everything',
      () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    final generation = rig.cache.generation;
    final tiles = rig.cache.liveTileCount;

    // Twelve pans, none of them a whole tile.
    for (var i = 0; i < 12; i++) {
      rig.panBy(-5.5, -2.5);
      rig.paintOnce();
    }
    expect(rig.cache.generation, generation,
        reason: 'a pan is not a new generation');
    expect(rig.cache.liveTileCount, greaterThanOrEqualTo(tiles),
        reason: 'a pan adds tiles at the leading edge and drops none');

    rig.zoomBy(1.03);
    rig.paintOnce();
    expect(rig.cache.generation, generation + 1);
    expect(rig.cache.hasCarryOver, isTrue,
        reason: 'the retired generation lives on as one composite: two live '
            'generations do not fit under the cap, and independently snapped '
            'scaled tiles gap or overlap along every shared edge');
  });

  test('a zoom gesture blits the carry-over and bakes nothing', () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 0);
    addTearDown(rig.dispose);
    // Budget 0 after the first frame: prove the gesture is a blit, not a bake.
    rig.paintOnce();
    rig.cache.resetCounters();
    for (var i = 0; i < 8; i++) {
      rig.zoomBy(1.03);
      rig.paintOnce();
    }
    expect(rig.cache.bakeCount, 0);
    expect(rig.cache.carryOverBlitCount, 8,
        reason: 'one composite blit per gesture frame');
    expect(rig.cache.liveDrawCount, 0,
        reason: 'the carry-over covers the viewport, so nothing is uncovered');
  });

  test('the settle spreads its bakes across frames', () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 4);
    addTearDown(rig.dispose);
    rig.paintOnce();
    rig.zoomBy(1.03);
    rig.cache.resetCounters();
    // Settled: the scale stops moving, so the new generation fills in.
    for (var i = 0; i < 3; i++) {
      rig.paintOnce();
    }
    expect(rig.cache.bakeCount, 12, reason: 'four per frame, three frames');
  });
```

- [ ] **Step 2: Implement**

`_retireGeneration` composites before it disposes:

```dart
  /// The retired generation, flattened to one viewport-sized image.
  ///
  /// **One image, not the old tiles.** `quantiseCamera` makes tile
  /// destinations exact only when they differ by whole multiples of the tile
  /// size, which holds at the generation's own scale and fails under an
  /// arbitrary zoom factor: snapped independently, adjacent scaled tiles leave
  /// a background gap or double-composite translucent ink along every shared
  /// edge. A composite has no internal edges. It also keeps the budget
  /// honest -- two live generations do not fit under [kTileCacheBytes], and
  /// LRU would never reclaim the outgoing one because the frame path reads it
  /// every frame.
  Image? _carryOver;
  ViewportTransform? _carryOverAnchor;
```

`_retireGeneration(Size viewport)` records the visible tiles into one picture at viewport size, `toImageSync`es it, disposes the tiles, and stores the anchor. `paintFrame`, when the grid is fresh, blits `_carryOver` first under `Rect` derived from the *old* anchor mapped through the *new* camera — this is the one blit that is **not** snapped and **does** want a filter, so it uses a second `Paint` with `FilterQuality.low` and the class comment says why.

The carry-over is dropped when the new generation covers the viewport (`uncovered == null` and no tile was baked this frame) or by `_dropEverything`.

- [ ] **Step 3: Run, then fire M4 and M9**

**M4** — make `TileGrid.matchesScale` return `true` always. Criterion 8 must go red, and criterion 1 after a zoom must go red too: the replayed generation carries the old scale's stroke widths and dash phase.

**M9** — ignore `tilesBakedPerFrame` and bake the whole visible set. The spread-bake test must go red. Note in the report that this mutant is *invisible* to every correctness criterion, which is why criterion 11 exists.

- [ ] **Step 4: Green and commit**

```sh
git add packages/jet_cad_2d_flutter/lib/src/tile_cache.dart packages/jet_cad_2d_flutter/test/tile_cache_test.dart
git commit -m "feat: generations, the carry-over composite, and the zoom path

A scale change retires the generation into one viewport-sized image and drops
its tiles. One image and not the old tiles, for two reasons that both bite:
snapping is exact only when destinations differ by whole multiples of the tile
size, which fails under an arbitrary zoom factor and leaves gaps or
double-composited overlaps along every shared edge; and two live generations do
not fit under the cap, with LRU unable to reclaim the outgoing one because the
frame path reads it every frame.

The settle spreads its bakes. Baking a whole visible set in one frame is the
~60 ms stall this cache exists to remove, moved rather than removed -- and it
is invisible to every correctness criterion, which is what criterion 11 is for."
```

---

## Task 10: The cap, eviction, and criteria 12 and 13

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Create: `packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart`

**Interfaces:** produces `TileCache.liveBytes`, `evictionCount`, `blitDestinationCount`.

- [ ] **Step 1: Write the failing invariants**

Create `packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart`:

```dart
// Criteria 12 and 13, always on.
//
// **Criterion 13 is a field read and not a heap measurement, and `STATUS.md`
// says why.** There is no working Flutter-side allocation meter -- trap 5 --
// and `paint_allocation_test.dart` reads one field,
// `VerticesDrawSink.debugCapacityVertices`, which can see neither a `Paint`
// nor a `Rect`. So this pins the `Paint`'s identity and the per-frame
// destination count instead, the same shape `VerticesDrawSink.debugPaint`
// already uses.

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/tile_fixture.dart';

void main() {
  test('criterion 12: the cap holds and eviction is real, not theoretical',
      () async {
    // A cap of eight tiles at 64 device pixels: 8 * 64 * 64 * 4 = 131,072 B.
    // Small on purpose -- the point is that the policy runs, and a production
    // cap would need a corpus this suite cannot afford.
    final rig = TileRig(
        tileDevicePixels: 64, tilesBakedPerFrame: 1000, cacheBytes: 131072);
    addTearDown(rig.dispose);

    for (var i = 0; i < 6; i++) {
      rig.panBy(-64, -32);
      rig.paintOnce();
      expect(rig.cache.liveBytes, lessThanOrEqualTo(131072),
          reason: 'pan $i');
    }
    expect(rig.cache.evictionCount, greaterThan(0),
        reason: 'anti-degenerate clause 7: a cap nothing reaches is not a cap');
  });

  test('criterion 12: a pan back to reclaimed tiles draws live, not blank',
      () async {
    // Anti-degenerate clause 7. This is the failure that would ship as an
    // intermittent blank strip: no settled-frame criterion can see it.
    final rig = TileRig(
        tileDevicePixels: 64, tilesBakedPerFrame: 2, cacheBytes: 131072);
    addTearDown(rig.dispose);
    rig.paintOnce();
    for (var i = 0; i < 6; i++) {
      rig.panBy(-64, 0);
      rig.paintOnce();
    }
    rig.cache.resetCounters();
    for (var i = 0; i < 6; i++) {
      rig.panBy(64, 0);
      rig.paintOnce();
    }
    expect(rig.cache.liveDrawCount, greaterThan(0),
        reason: 'the camera returned to tiles the cap reclaimed');
  });

  test('criterion 13: allocation is viewport-bounded and the Paint is one',
      () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    final paint = rig.cache.debugBlitPaint;
    rig.cache.resetCounters();
    rig.paintOnce();
    final first = rig.cache.blitDestinationCount;
    rig.cache.resetCounters();
    rig.paintOnce();

    expect(identical(rig.cache.debugBlitPaint, paint), isTrue);
    expect(rig.cache.blitDestinationCount, first,
        reason: 'two identical frames allocate the same number of rects: '
            'bounded by the viewport over the tile size, not by entity count');
    expect(first, lessThan(200),
        reason: 'a viewport quantity. If this grows with the document, the '
            'per-entity half of the rule is broken.');
  });
}
```

- [ ] **Step 2: Implement LRU**

Track insertion/use order and `liveBytes = _tiles.length * tileDevicePixels * tileDevicePixels * 4 + (carry-over bytes)`. Evict least-recently-blitted, never a tile blitted this frame. Import `dart:math` here if the eviction loop needs it; not before — `unused_import` is an error.

- [ ] **Step 3: Fire M6**

Delete the eviction call. Criterion 12's cap assertion must go red. Restore from a copy.

- [ ] **Step 4: Green and commit**

```sh
git add packages/jet_cad_2d_flutter/lib/src/tile_cache.dart packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart
git commit -m "feat: the cap, eviction, and the two invariants that run every suite

Criterion 13 is a field read and not a heap measurement. STATUS records that
there is no working Flutter-side allocation meter and that trap 5 needs a
direct assertion instead; paint_allocation_test reads one field that can see
neither a Paint nor a Rect. So the Paint's identity and the per-frame
destination count are pinned, the shape VerticesDrawSink.debugPaint uses.

The eviction test pans away and back. That path -- the camera returning to
tiles the cap reclaimed -- is the one that would have shipped as an
intermittent blank strip, and no settled-frame criterion can see it."
```

---

## Task 11: The harness, and the tile-size sweep

**Files:**
- Modify: `apps/dev_harness_2d/lib/main.dart`, `apps/dev_harness_2d/lib/measurement_rig.dart`

- [ ] **Step 1: Add the defines**

`TILES` (`off`/`on`) and `TILE_PX` (int, default `kTileDevicePixels`) and `TILE_BAKE` (int, default `kTilesBakedPerFrame`). All three follow `kBackend`'s rule: a `String.fromEnvironment` for the flag, and **throw on an unrecognised value rather than falling back**, because a run that silently took the control arm would publish the baseline twice and call one of them a measurement.

- [ ] **Step 2: Print the tile counters**

In `printInvariants`, add `tiles=`, `bakes=`, `blits=`, `carryOverBlits=`, `liveDraws=`, `evictions=` and `tileBytes=`. `report()` already prints `totalSpan` on `main` at `2218eab`; **criteria 10 and 11 read that column and not `rasterDuration`**, because Probe D rasterised 217,758 triangles per frame while `rasterDuration` read 0.87 ms.

- [ ] **Step 3: Run the sweep**

Machine state first, and it is not optional:

```sh
pmset -g | grep -i lowpowermode     # must read 0
pmset -g ps | head -2               # must read AC Power
```

Then, at `ENTITIES=500000`, `BACKEND=vertices`, `RIG=pan`, `TEXT=true`, for `TILE_PX` in {128, 256, 512} — **1024 is excluded before the sweep starts**: its 80.0 MiB visible set leaves no room under the 96 MiB cap for the 29.3 MiB carry-over.

Report **three** columns, not one:

| column | why it is not optional |
|---|---|
| blit cost per frame | what Probe D measured for a single viewport-sized blit (0.97 ms of raster) |
| **bake cost per tile** | criterion 11 is a pan frame, and a pan frame's cost is the strip it bakes |
| **measured overdraw factor** | `kScreenClipInflate` is 32 *logical* pixels, so a 128 px tile at `dpr` 2 culls against a 128×128 logical rect and bakes 4.00× its own area |

**Bake cost moves opposite to blit cost as the tile size changes.** A sweep reading blit cost alone would recommend the smallest tile and lose criterion 11.

- [ ] **Step 4: Decide, and record the decision**

Pick `kTileDevicePixels` from the table and write the three columns into the results note in Task 13. If the overdraw column justifies a tile-specific `kTileClipInflate`, name it there with the measurement behind it. **This plan does not guess that constant in advance.**

- [ ] **Step 5: Commit**

```sh
git add apps/dev_harness_2d/lib
git commit -m "feat: TILES, TILE_PX and TILE_BAKE, and the sweep reads three columns

Memory wants small tiles and bake cost wants large ones. kScreenClipInflate is
32 logical pixels and inflates whatever rect the painter culls against, so a
128 px tile at dpr 2 bakes four times its own area while costing the least
memory. A sweep that read blit cost alone would recommend it and lose criterion
11, whose cost is the strip a pan frame bakes.

The defines throw on an unrecognised value, as kBackend does: a run that
silently took the control arm would publish the baseline twice."
```

---

## Task 12: Criteria 10 and 11 on device

**Files:** none. This task measures and reports.

- [ ] **Step 1: Confirm the machine, and record the reading**

`pmset -g | grep -i lowpowermode` must read `0` and the machine must be on AC power. Plan 3c lost a whole session's timings to Low Power Mode, and the 2026-08-23 spike measured its contamination on this corpus at **+30% on build and +47% on raster** — which is not the uniform ~24% `STATUS.md:101-104` records from Plan 3c, and the results note must say so again if it holds.

- [ ] **Step 2: Reproduce the control before measuring anything**

```sh
cd apps/dev_harness_2d
CI=true flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=TEXT=true --dart-define=ENTITIES=50000 \
  --dart-define=RIG=pan --dart-define=BACKEND=vertices
```

Plan 3d's clean row is build 7.07 `[7.06, 7.38]` / raster 8.53 `[8.22, 8.63]`. **If the baseline does not land inside those intervals, the machine is talking and every number below falls with it.** Stop and say so rather than publishing.

- [ ] **Step 3: Measure criteria 10 and 11**

Median of three at `ENTITIES=500000`, `BACKEND=vertices`, `TILES=on`, at the tile size Task 11 chose.

| criterion | reading | threshold |
|---|---|---|
| 10 | settled frame `totalSpan` | **≤ 4.00 ms** — Probe D measured 1.61 ms for a single viewport blit; the allowance covers the grid's extra `drawImageRect` calls |
| 11 | pan frame baking a strip, `totalSpan` | **≤ 16.67 ms** — the frame budget, since a pan frame that misses it is a dropped frame |

**Criterion 11's threshold is the one number no measurement backs, and it does not move.** If it is unreachable at every size in {128, 256, 512}, the response is a smaller `kTilesBakedPerFrame`, or a `kTileClipInflate` the overdraw column justifies — **not a larger threshold**. A gate moved to fit its result is not a gate.

- [ ] **Step 4: Fire M7 on device**

Clip each tile to the viewport instead of to its own rect. **Every correctness criterion stays green** — the blit only ever shows a tile's own rect, so the extra baked content is never displayed — and criteria 10 and 11 collapse. Record the numbers. M7 is the mutation that passes the whole correctness suite and destroys the plan's reason for existing; a run that cannot kill it is not gating this plan.

- [ ] **Step 5: Record, do not commit code**

No source changes. The transcripts go into Task 13's results note verbatim. **Never synthesize test output.**

---

## Task 13: The results note, the mutation log, and `STATUS.md`

**Files:**
- Create: `docs/superpowers/notes/2026-08-2X-plan-3g-results.md`, `docs/superpowers/notes/plan-3g-mutation-log.md`
- Modify: `STATUS.md`

- [ ] **Step 1: Write the mutation log**

One section per mutant, seventeen of them, each with the exact edit, the command run, and the **verbatim** transcript of the red run and of the restored green run. M3 gets a section too, recording that it **could not be fired** and why — G1's instrument concession — rather than being quietly dropped.

**M17's section must name the wiring test as its killer, not criterion 1.** The rebase origin cancels exactly through `VerticesDrawSink`, so no pixel comparison on that backend can see it; Task 5 established this algebraically and with a magnitude sweep. Recording M17 as "killed by criterion 1" would be the same false coverage claim this plan's spec cites from Plan 3f.1.

- [ ] **Step 2: Write the results note**

Thirteen criteria, each PASS / MISS / unevaluable with the number beside it. The sweep's three columns. The chosen `kTileDevicePixels` and `kTilesBakedPerFrame` with the measurement that chose them. The Low Power Mode reading. Every accepted gap restated with what is still owed:

- **G1** — the seam is proven complete geometrically and **not** proven free of antialiasing artefacts on device. Say it in those words. A green criterion 2 is not a settled seam.
- **G2** — no table record may gain a setter.
- **G3** — zoom stays where it is; that is Plan 3h.
- **G4** — the web whole-drawing abort's back-to-back re-run, still owed.

And the second-order measurement this plan owes 3h: `debugCapacityVertices` with tiles on against tiles off at 500,000 entities. Baking per tile flushes and rewinds between tiles, so the 96.00 MiB high-water mark `STATUS.md:1066` records should fall to a single tile's geometry. **If it does, the tile budget replaces that memory rather than adding to it**, and 3h's budget starts from the new number.

- [ ] **Step 3: Update `STATUS.md`**

Replace the Plan 3g block with what shipped: the exit gate, the chosen constants, what is owed, and Plan 3h's inheritance. Link both notes and the plan. Keep the spike note's link — it is the measurement of record for why this plan exists at all.

- [ ] **Step 4: Commit**

```sh
git add docs STATUS.md
git commit -m "docs: Plan 3g results, mutation log, and STATUS"
```

---

## Self-review of this plan

**Spec coverage.** D1 → Task 1. D2, D5 → Task 3. D3, D13 → Task 9. D4 is a rejection and needs no task. D6 → Task 11. D7 → Tasks 4–6 (the injectable tile size, used at 64 throughout). D8 → Task 4, gated in Task 5. D9 → Tasks 3 and 8. D10, D11 → Task 7. D12 → Tasks 2 and 8. D14 → Task 8. Criteria 1–4 → Tasks 5, 6. Criteria 5, 6, 9 → Task 7. Criterion 7 → Task 8. Criterion 8 → Task 9. Criteria 12, 13 → Task 10. Criteria 10, 11 → Task 12. G1–G4 → Task 13. **No spec section is unclaimed.**

**Mutant coverage, as planned.** M1, M2, M5, M12, M16 → Task 7. M3 → deferred, recorded in Task 13. M4, M9 → Task 9. M6 → Task 10. M7 → Task 12. M8 → Tasks 2 and 8. M10 → Task 3. M11, M14 → Task 6. M13 → Tasks 4 and 10. M15, M17 → Task 5.

> **Superseded 2026-08-24 by execution.** This paragraph ended "sixteen fired,
> one recorded as unfirable". **The true count is 41 named and 39 fired**, and
> the record of it is
> [docs/superpowers/notes/plan-3g-mutation-log.md](../notes/plan-3g-mutation-log.md),
> not this line. Execution added M18 and M19 and roughly twenty more that
> individual tasks named locally, because repeatedly the mutant a task was given
> could not fire and a working one had to be built. Two remain unfired: **M3**,
> which `flutter_test`'s software Skia cannot produce an artefact for, and
> **M7**, which only criteria 10 and 11 can see. M17's killer is a wiring test
> and **not** criterion 1.

**Anti-degenerate coverage.** Clause 1 → the 64 px tile everywhere and `crossingGrid`'s 266-logical-pixel lines (190 world units at the fixture camera's 1.4 scale), spanning about eight 32-logical-pixel tiles. Clause 2 → `tileCamera()`, never `fit`. Clause 3 → asserted at `blitCount > 30`. Clauses 4 and 5 → `instancedFixture` and the dragged-instance test. Clauses 6 and 7 → Task 10's two eviction tests.

**Type consistency.** `TileCache.paintFrame` takes `CanvasDrawSink sink` (not `DrawSink`) throughout, and `tablesRevision` is added to its signature in Task 8 — Task 4's call sites in `tile_fixture.dart` must be updated there. `DraftPainter.debugRebaseOrigin` and `debugOnVisit` are mutable fields, not `final`, because `TileCache` sets them per bake.

**Known incompleteness, stated rather than hidden.** Tasks 9 and 10 give implementation *shape* and the exact tests, not line-by-line code for the composite and the LRU. Both are ordinary data-structure work whose contract is fully pinned by the tests above them, and writing speculative code for `Picture`/`Image` composition that the implementer will correct against the API is worth less than the tests that judge it. Every other task carries its code in full.
