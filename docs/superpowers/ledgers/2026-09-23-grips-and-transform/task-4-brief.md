### Task 4: `OutlineCache.worldBoundsOf`, the style constants, `GripCache`

**Files:**
- Modify: `lib/src/outline_cache.dart` (add `worldBoundsOf` after `worldPointOf`)
- Modify: `lib/src/selection_style.dart` (append the constants)
- Create: `lib/src/grip_cache.dart`
- Modify: `lib/jet_cad_2d_flutter.dart`: add `export
  'src/grip_cache.dart';` after the `src/gpu/...` exports and before
  `src/interaction_layer.dart`.
- Create: `test/support/grip_fixture.dart` (first version)
- Test: `test/outline_cache_test.dart` (O1), `test/grip_cache_test.dart` (C1–C7)

**Interfaces:**
- Consumes: `Grip`, `GripRole` and `leafGrips` (Task 1); `arcBounds`,
  `Aabb2`, `Transform2`, `Capability` and `DraftPermissions` (engine);
  `SelectionController`; `OutlineCache`.
- Produces:
  - `Aabb2? OutlineCache.worldBoundsOf(SelectionKey key)`
  - in `selection_style.dart`: `kGripPixels`, `kGripColor`,
    `kGripMoveColor`, `kGripHotColor`, `kRotationGripPixels`,
    `kRotationGripOffset`, `kPreviewColor`, `kPreviewStrokePixels`,
    `kSnapMarkerColor`, `kSnapMarkerPixels`, `kSnapMarkerStrokePixels`,
    `kGridMarkerPixels`
  - in `grip_cache.dart`:
    - `const int kMaxGrips = 400;`
    - `const double kGripHitPixels = 7.0;`
    - `final class GripRef { const GripRef(SelectionKey key, Grip grip, int ordinal); }`
    - `({Offset anchor, Offset centre}) rotationGripOf(Aabb2 box, Transform2 worldToScreen)`
  - `class GripCache extends ChangeNotifier`:
    - `GripCache(DraftDocument document, SelectionController selection, OutlineCache outlines)`
    - `List<GripRef> get grips` (an unmodifiable view, the same object every
      call)
    - `int get moveCount`
    - `int get stretchCount`
    - `Aabb2? get box`
    - `bool get rotatable`
    - `int hot` (writable; `-1` for none)
    - `bool get leafGripsLive`
    - `int hitTest(Offset screen, Transform2 worldToScreen)`
    - `bool hitsRotationGrip(Offset screen, Transform2 worldToScreen)`
  - in `test/support/grip_fixture.dart`: `GripScene`,
    `GripScene gripScene({TextMeasurer measurer, PageComponent? page})`,
    `CameraController gripCamera({Vector2? centre, Size viewport, double scale, double rotation})`,
    `Offset screenOf(CameraController, double x, double y)`,
    `GeometryPayload payloadOf(DraftDocument, Handle)`,
    `String snapshot(DraftDocument)`

- [ ] **Step 1: Write the fixture.**

```dart
// test/support/grip_fixture.dart
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'selection_fixture.dart';

/// The spec's standard 03 fixture (Testing).
///
/// - Everything sits at x ≈ 7000–7550, y ≈ 3000–3330, so the rebase origin
///   is non-zero.
/// - A closed room.
/// - Arcs with a non-zero start, one of them with a negative sweep.
/// - A group whose own transform is a rotation.
/// - Two instances of one definition.
/// - The root stays the identity.
final class GripScene {
  GripScene._(this.document);

  final DraftDocument document;
  late final Handle line, polyline, room, circle, arcPos, arcNeg, point;
  late final Handle group, groupLeaf, def, defLeaf, instA, instB;
}

GripScene gripScene(
    {TextMeasurer measurer = const InsertionPointMeasurer(),
    PageComponent? page}) {
  final doc = DraftDocument.empty(measurer: measurer);
  final s = GripScene._(doc);
  final root = doc.rootHandle;
  s.line = addEntity(doc, root, EntityKind.line, [7010, 3020, 7130, 3060], []);
  s.polyline = addEntity(doc, root, EntityKind.polyline,
      [7010, 3100, 7040, 3130, 7070, 3100, 7100, 3130, 7130, 3100], []);
  s.room = addEntity(doc, root, EntityKind.polyline,
      [7200, 3000, 7400, 3000, 7400, 3150, 7200, 3150, 7200, 3000], []);
  s.circle = addEntity(doc, root, EntityKind.circle, [7300, 3250], [25]);
  s.arcPos = addEntity(doc, root, EntityKind.arc, [7050, 3200], [40, 0.3, 1.9]);
  s.arcNeg =
      addEntity(doc, root, EntityKind.arc, [7150, 3250], [30, 2.2, -1.4]);
  s.point = addEntity(doc, root, EntityKind.point, [7250, 3300], []);
  s.group = addGroup(doc, root,
      Transform2.translation(7400, 3300).multiply(Transform2.rotation(0.6)));
  s.groupLeaf = addEntity(doc, s.group, EntityKind.line, [0, 0, 40, 0], []);
  s.def = addDefinition(doc, 'Table');
  s.defLeaf = addEntity(doc, s.def, EntityKind.line, [0, 0, 30, 10], []);
  s.instA = addInstance(doc, s.def,
      Transform2.translation(7450, 3050).multiply(Transform2.rotation(0.3)));
  s.instB = addInstance(doc, s.def,
      Transform2.translation(7500, 3200).multiply(Transform2.rotation(-0.5)));
  if (page != null) {
    PageComponent.register(doc.components);
    doc.commands.execute(SetComponentCommand<PageComponent>(root, page));
  }
  // `undoDepth` counts the drag under test only.
  doc.commands.clearHistory();
  expect(doc.tree[root]!.transform.isIdentity, isTrue,
      reason: 'spec, Testing: the root stays the identity');
  return s;
}

/// Zoomed (scale ≠ 1), rotated (not 0°, not 90°), y flipped, and panned so
/// [centre] sits in the middle of [viewport].
CameraController gripCamera(
    {Vector2? centre,
    Size viewport = const Size(800, 600),
    double scale = 1.1,
    double rotation = 0.35}) {
  final c = centre ?? Vector2(7270, 3161);
  final linear =
      Transform2.rotation(rotation).multiply(Transform2.scale(scale, -scale));
  final mid = linear.transformPoint(c);
  return CameraController(ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              viewport.width / 2 - mid.x, viewport.height / 2 - mid.y)
          .multiply(linear)));
}

/// World (x, y) on screen under [camera].
Offset screenOf(CameraController camera, double x, double y) {
  final s = camera.value.worldToScreen(Vector2(x, y));
  return Offset(s.x, s.y);
}

/// The stored payload of [h], as a `read` copy.
GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

/// The codec's output: equal strings are a byte-identical document
/// (invariant 2).
String snapshot(DraftDocument doc) => DraftDocumentCodec.encodeToString(doc);
```

- [ ] **Step 2: Write the failing tests.** Append O1 to
  `test/outline_cache_test.dart`, inside `main()`:

```dart
  test('worldBoundsOf: an arc by arcBounds, a point by its position '
      '(M-03ah)', () {
    final doc = DraftDocument.empty();
    // Start 2.9, sweep −1.6: clockwise to 1.3, through the top extreme
    // (π/2) and no other.
    final arc = addEntity(
        doc, doc.rootHandle, EntityKind.arc, [7050, 3200], [40, 2.9, -1.6]);
    final dot =
        addEntity(doc, doc.rootHandle, EntityKind.point, [7250, 3300], []);
    final line = addEntity(
        doc, doc.rootHandle, EntityKind.line, [7010, 3020, 7130, 3060], []);
    final (selection, cache) = wire(doc);
    selection.replace([
      SelectionKey.root(arc),
      SelectionKey.root(dot),
      SelectionKey.root(line),
    ]);

    final a = cache.worldBoundsOf(SelectionKey.root(arc))!;
    expect(a.minX, closeTo(7050 + 40 * math.cos(2.9), 1e-9));
    expect(a.maxX, closeTo(7050 + 40 * math.cos(2.9 - 1.6), 1e-9));
    expect(a.minY, closeTo(3200 + 40 * math.sin(2.9), 1e-9));
    expect(a.maxY, closeTo(3240, 1e-9),
        reason: 'the top extreme is inside the sweep; a control-point box '
            'or a full circle would say otherwise');
    final p = cache.worldBoundsOf(SelectionKey.root(dot))!;
    expect([p.minX, p.minY, p.maxX, p.maxY], [7250, 3300, 7250, 3300],
        reason: 'a point is its position, never Rect.zero');
    expect(cache.worldBoundsOf(SelectionKey.root(line))!.maxY, 3060);
    expect(cache.worldBoundsOf(SelectionKey.root(const Handle(999999))),
        isNull);
  });
```

Create `test/grip_cache_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/grip_cache.dart';
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/selection_style.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/grip_fixture.dart';
import 'support/selection_fixture.dart';

/// Selection, outlines and grips over [doc], built in the shell's order
/// (spec D6) and torn down with the test.
(SelectionController, OutlineCache, GripCache) wire(DraftDocument doc) {
  final selection = SelectionController(doc);
  final outlines = OutlineCache(doc, selection);
  final grips = GripCache(doc, selection, outlines);
  addTearDown(() {
    grips.dispose();
    outlines.dispose();
    selection.dispose();
  });
  return (selection, outlines, grips);
}

SelectionKey k(Handle h) => SelectionKey.root(h);

void main() {
  test('grips of the selected root leaves, in world, in ascending handle '
      'order (M-03y)', () {
    final s = gripScene();
    final doc = s.document;
    final (selection, _, grips) = wire(doc);
    selection.replace([
      k(s.instA),
      k(s.arcNeg),
      k(s.group),
      k(s.room),
      k(s.circle),
      k(s.line),
    ]);
    final expected = <(Handle, Grip)>[
      for (final h in [s.line, s.room, s.circle, s.arcNeg])
        for (final g in leafGrips(
            doc.entities.kindAt(doc.entities.slotOf(h)!), payloadOf(doc, h)))
          (h, g),
    ];
    expect([for (final r in grips.grips) (r.key.target, r.grip)], expected);
    expect(grips.grips, hasLength(2 + 4 + 5 + 4),
        reason: 'a group and an instance have no grips (spec D3)');
    expect([for (final r in grips.grips) r.ordinal].take(6), [0, 1, 0, 1, 2, 3]);
    expect(grips.moveCount, 2, reason: "the circle's and the arc's centres");
    expect(grips.stretchCount, 13);
  });

  test('the selection box is the union of worldBoundsOf; fills alone have '
      'none (M-03ah)', () {
    final s = gripScene();
    final doc = s.document;
    final region = AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.polyline,
      boundaryPayload: GeometryPayload(
          coords: Float64List.fromList(
              [7600, 3000, 7700, 3000, 7700, 3100, 7600, 3000]),
          scalars: Float64List(0)),
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x8844AA),
      boundaryColor: const ByLayerColor(),
    );
    doc.commands.execute(region);
    final (selection, outlines, grips) = wire(doc);
    selection.replace([k(s.arcNeg), k(s.point)]);
    final arc = outlines.worldBoundsOf(k(s.arcNeg))!;
    final box = grips.box!;
    expect(box.minX, arc.minX);
    expect(box.minY, arc.minY);
    expect(box.maxX, 7250, reason: 'the point counts by its position');
    expect(box.maxY, 3300);
    expect(grips.rotatable, isTrue);
    selection.replace([k(region.fill.handle)]);
    expect(grips.box, isNull);
    expect(grips.rotatable, isFalse,
        reason: 'a fill has no outline of its own (spec D4, Ruling 03-15)');
    expect(grips.grips, isEmpty);
  });

  test('a DocChange rebuilds the grips after the outline cache (M-03al)',
      () async {
    final s = gripScene();
    final doc = s.document;
    final (selection, _, grips) = wire(doc);
    selection.replace([k(s.line)]);
    expect(grips.grips[1].grip.x, 7130);
    var notified = 0;
    grips.addListener(() => notified++);
    doc.commands.execute(SetEntityGeometryCommand(
        s.line,
        GeometryPayload(
            coords: Float64List.fromList([7010, 3020, 7160, 3090]),
            scalars: Float64List(0))));
    await Future<void>.delayed(Duration.zero);
    expect(grips.grips[1].grip.x, 7160);
    expect(grips.box!.maxY, 3090);
    expect(notified, greaterThan(0));
  });

  test('the cap: kMaxGrips grips are kept, kMaxGrips + 1 keep none (M-03z)',
      () {
    final doc = DraftDocument.empty();
    List<double> zigzag(int n) => [
          for (var i = 0; i < n; i++) ...[7000.0 + i, i.isEven ? 3000.0 : 3005.0],
        ];
    final atCap =
        addEntity(doc, doc.rootHandle, EntityKind.polyline, zigzag(kMaxGrips), []);
    final overCap = addEntity(
        doc, doc.rootHandle, EntityKind.polyline, zigzag(kMaxGrips + 1), []);
    final (selection, _, grips) = wire(doc);
    selection.replace([k(atCap)]);
    expect(grips.grips, hasLength(kMaxGrips));
    selection.replace([k(overCap)]);
    expect(grips.grips, isEmpty);
    expect(grips.box, isNotNull,
        reason: 'body move and rotate still work over the cap (spec D6)');
  });

  test('leaf grips are not live under a geometry denial (M-03ad)', () {
    final s = gripScene();
    final doc = s.document;
    final (selection, _, grips) = wire(doc);
    selection.replace([k(s.line), k(s.instA)]);
    final camera = gripCamera();
    addTearDown(camera.dispose);
    final m = camera.value.worldToScreenMatrix;
    final vertex = screenOf(camera, 7130, 3060);
    expect(grips.leafGripsLive, isTrue);
    expect(grips.hitTest(vertex, m), 1);
    doc.commands.permissions = DraftPermissions.runtime;
    expect(grips.leafGripsLive, isFalse);
    expect(grips.hitTest(vertex, m), -1);
    expect(grips.rotatable, isTrue,
        reason: 'the rotation grip is not a leaf grip (Ruling 03-6)');
  });

  test('hitTest: the nearest, then the greater handle, then the lower '
      'ordinal (M-03ai)', () {
    final doc = DraftDocument.empty();
    final wallA = addEntity(
        doc, doc.rootHandle, EntityKind.line, [7600, 3400, 7650, 3400], []);
    final wallB = addEntity(
        doc, doc.rootHandle, EntityKind.line, [7650, 3400, 7650, 3450], []);
    final twin = addEntity(doc, doc.rootHandle, EntityKind.polyline,
        [7800, 3400, 7800, 3400, 7850, 3420], []);
    final (selection, _, grips) = wire(doc);
    selection.replace([k(wallA), k(wallB), k(twin)]);
    final camera = gripCamera(centre: Vector2(7700, 3420));
    addTearDown(camera.dispose);
    final m = camera.value.worldToScreenMatrix;

    final corner =
        grips.hitTest(screenOf(camera, 7650, 3400) + const Offset(2, 1), m);
    expect(grips.grips[corner].key.target, wallB,
        reason: 'coincident grips of two objects: the greater handle moves');
    expect(grips.grips[corner].ordinal, 0);
    final dup = grips.hitTest(screenOf(camera, 7800, 3400), m);
    expect(grips.grips[dup].key.target, twin);
    expect(grips.grips[dup].ordinal, 0,
        reason: "one object's coincident grips: the lower ordinal");
    final near =
        grips.hitTest(screenOf(camera, 7600, 3400) + const Offset(5, 0), m);
    expect(grips.grips[near].key.target, wallA);
    expect(grips.hitTest(screenOf(camera, 7600, 3400) + const Offset(8, 0), m),
        -1,
        reason: 'kGripHitPixels is 7');
  });

  test('the rotation grip hangs 24 px above the screen box, screen-up '
      '(M-03ak)', () {
    final camera = gripCamera();
    addTearDown(camera.dispose);
    final m = camera.value.worldToScreenMatrix;
    expect(m.b, isNot(closeTo(0, 1e-3)),
        reason: 'rotated, so the screen box is not the projected world box');
    const box = Aabb2.raw(7010, 3020, 7130, 3060);
    final corners = [
      for (final (x, y) in const [
        (7010.0, 3020.0),
        (7130.0, 3020.0),
        (7010.0, 3060.0),
        (7130.0, 3060.0),
      ])
        screenOf(camera, x, y),
    ];
    final minX = corners.map((c) => c.dx).reduce(math.min);
    final maxX = corners.map((c) => c.dx).reduce(math.max);
    final minY = corners.map((c) => c.dy).reduce(math.min);
    final g = rotationGripOf(box, m);
    expect(g.anchor.dx, closeTo((minX + maxX) / 2, 1e-9));
    expect(g.anchor.dy, closeTo(minY, 1e-9));
    expect(g.centre.dx, closeTo(g.anchor.dx, 1e-12));
    expect(g.centre.dy, closeTo(minY - kRotationGripOffset, 1e-9));
  });
}
```

- [ ] **Step 3: Run them to fail.** `cd packages/jet_cad_2d_flutter &&
  CI=true flutter test test/outline_cache_test.dart
  test/grip_cache_test.dart` → compile errors: `worldBoundsOf`,
  `GripCache`, `rotationGripOf` and `kRotationGripOffset` are undefined.

- [ ] **Step 4: Implement.** In `lib/src/outline_cache.dart`, after
  `worldPointOf`:

```dart
  /// The world AABB of [key]'s outline, in doubles (spec D6); null when
  /// [key] is not cached or its outline is empty (a fill, a hidden leaf).
  ///
  /// Computed from the world records, **never** from a `ui.Path`. The
  /// reason: `Path.getBounds` answers an arc's control-point bounds (see
  /// [debugWorldArcsOf]) and `Rect.zero` for a lone point, and a path is
  /// float32, rebased by whatever origin it was last built at (review
  /// finding #3).
  Aabb2? worldBoundsOf(SelectionKey key) {
    final outlines = _world[key];
    if (outlines == null) return null;
    var box = Aabb2.empty();
    for (final outline in outlines) {
      switch (outline) {
        case _Segments(:final coords):
          for (var i = 0; i + 1 < coords.length; i += 2) {
            box = box.expandedToPoint(Vector2(coords[i], coords[i + 1]));
          }
        case _Arc(:final cx, :final cy, :final r, :final start, :final sweep):
          box = box.union(arcBounds(Vector2(cx, cy), r, start, sweep));
        case _Point(:final x, :final y):
          box = box.expandedToPoint(Vector2(x, y));
      }
    }
    return box.isEmpty ? null : box;
  }
```

Append to `lib/src/selection_style.dart`:

```dart
/// Grip squares (spec D6): side in screen pixels, drawn by `drawRawPoints`
/// with a square cap at this stroke width.
const double kGripPixels = 8.0;

/// Stretch and radius grips.
const Color kGripColor = Color(0xFF1E6FE8);

/// Move (centre) grips.
const Color kGripMoveColor = Color(0xFF7A3FD1);

/// The hovered grip, and the grabbed one during a drag.
const Color kGripHotColor = Color(0xFFE8541E);

/// The rotation grip: a disc of this diameter, [kRotationGripOffset] screen
/// pixels above the top-centre of the selection's screen box (spec D6).
const double kRotationGripPixels = 8.0;
const double kRotationGripOffset = 24.0;

/// The drag preview and its guide line (spec D7).
const Color kPreviewColor = Color(0xFFE8A11E);
const double kPreviewStrokePixels = 1.5;

/// Snap markers (spec D9).
const Color kSnapMarkerColor = Color(0xFF2E9E5B);
const double kSnapMarkerPixels = 10.0;
const double kSnapMarkerStrokePixels = 1.5;
const double kGridMarkerPixels = 6.0;
```

Create `lib/src/grip_cache.dart`:

```dart
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'outline_cache.dart';
import 'selection.dart';
import 'selection_style.dart';

/// Past this many grips in the selection, no leaf grip is shown (spec D6).
/// Body move and rotate still work.
const int kMaxGrips = 400;

/// A press or hover within this many screen pixels of a grip's centre hits
/// it (spec D2).
const double kGripHitPixels = 7.0;

/// One grip of one selected root leaf. For a root leaf, owner space is
/// world, so [grip]'s coordinates are world.
final class GripRef {
  const GripRef(this.key, this.grip, this.ordinal);

  final SelectionKey key;
  final Grip grip;

  /// The grip's position in `leafGrips`' list — D2's tie-break "grip index"
  /// (Ruling 03-2).
  final int ordinal;
}

/// Where the rotation grip sits (spec D6): the centre of the screen-space
/// bounding box of [box]'s four projected corners, [kRotationGripOffset]
/// pixels up. Under a rotated camera, "up" means screen-up. [anchor] is the
/// top-centre the grip hangs from.
({Offset anchor, Offset centre}) rotationGripOf(
    Aabb2 box, Transform2 worldToScreen) {
  final m = worldToScreen;
  var minX = double.infinity, maxX = double.negativeInfinity;
  var minY = double.infinity;
  for (var i = 0; i < 4; i++) {
    final x = i.isEven ? box.minX : box.maxX;
    final y = i < 2 ? box.minY : box.maxY;
    final sx = m.a * x + m.c * y + m.e;
    final sy = m.b * x + m.d * y + m.f;
    minX = math.min(minX, sx);
    maxX = math.max(maxX, sx);
    minY = math.min(minY, sy);
  }
  final cx = (minX + maxX) / 2;
  return (
    anchor: Offset(cx, minY),
    centre: Offset(cx, minY - kRotationGripOffset),
  );
}

/// The selection's grips and box, in world doubles (spec D6).
///
/// Rebuilt at selection-change and document-change rate, never per frame.
/// It listens to the selection controller and to the [OutlineCache], never
/// to `document.changes` (Ruling 03-19). The box is derived from the
/// outline cache's world records, so it must rebuild after them. The shell
/// constructs this after the outline cache, so on a selection change the
/// cache's listener has already run.
class GripCache extends ChangeNotifier {
  GripCache(this.document, this.selection, this.outlines) {
    selection.addListener(_onSelection);
    outlines.addListener(_rebuild);
    _rebuild();
  }

  final DraftDocument document;
  final SelectionController selection;
  final OutlineCache outlines;

  final List<GripRef> _grips = <GripRef>[];

  /// Every shown grip, in ascending handle order, then by ordinal. The same
  /// view object on every call, so a painter reading it per frame
  /// allocates nothing.
  late final List<GripRef> grips = UnmodifiableListView<GripRef>(_grips);

  Set<SelectionKey> _built = const {};
  int _moveCount = 0;
  Aabb2? _box;

  /// How many of [grips] are move (centre) grips.
  int get moveCount => _moveCount;

  /// How many are stretch or radius grips.
  int get stretchCount => _grips.length - _moveCount;

  /// The union of `worldBoundsOf` over the selection; null when nothing
  /// selected has an outline.
  Aabb2? get box => _box;

  /// A rotation grip is drawn and hit (spec D6). A fill has no outline of
  /// its own, so a non-null box already means a non-fill key
  /// (Ruling 03-15).
  bool get rotatable => _box != null;

  /// Index into [grips] of the hovered or grabbed grip, or -1.
  ///
  /// Written by the select tool, which notifies for the repaint itself.
  /// Reset on every rebuild.
  int hot = -1;

  /// Leaf grips need `geometry` (spec D2). Read live, never cached: a
  /// permission change is not notified (Ruling 03-5).
  bool get leafGripsLive =>
      document.commands.permissions.allows(Capability.geometry);

  /// The grip under [screen] within [kGripHitPixels], or -1.
  ///
  /// The nearest wins, then the greater handle (coincident grips of two
  /// objects: the later-drawn one moves), then the lower ordinal. Nothing
  /// hits while leaf grips are not live.
  int hitTest(Offset screen, Transform2 worldToScreen) {
    if (!leafGripsLive) return -1;
    final m = worldToScreen;
    var best = -1;
    var bestDistance = double.infinity;
    var bestHandle = -1;
    var bestOrdinal = 0;
    for (var i = 0; i < _grips.length; i++) {
      final ref = _grips[i];
      final g = ref.grip;
      final dx = m.a * g.x + m.c * g.y + m.e - screen.dx;
      final dy = m.b * g.x + m.d * g.y + m.f - screen.dy;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > kGripHitPixels) continue;
      final h = ref.key.target.value;
      final better = best < 0 ||
          d < bestDistance ||
          (d == bestDistance &&
              (h > bestHandle ||
                  (h == bestHandle && ref.ordinal < bestOrdinal)));
      if (!better) continue;
      best = i;
      bestDistance = d;
      bestHandle = h;
      bestOrdinal = ref.ordinal;
    }
    return best;
  }

  /// Whether [screen] is within [kGripHitPixels] of the rotation grip.
  bool hitsRotationGrip(Offset screen, Transform2 worldToScreen) {
    final b = _box;
    if (b == null) return false;
    return (rotationGripOf(b, worldToScreen).centre - screen).distance <=
        kGripHitPixels;
  }

  /// A hover change notifies the selection controller with the same keys.
  /// Rebuilding for it would reset [hot] under the pointer, so it is skipped
  /// (Ruling 03-19).
  void _onSelection() {
    if (setEquals(_built, selection.keys.toSet())) return;
    _rebuild();
  }

  void _rebuild() {
    _grips.clear();
    _moveCount = 0;
    hot = -1;
    var box = Aabb2.empty();
    final keys = selection.keys.toList()
      ..sort((a, b) => a.target.value.compareTo(b.target.value));
    for (final key in keys) {
      final bounds = outlines.worldBoundsOf(key);
      if (bounds != null) box = box.union(bounds);
      final slot = document.entities.slotOf(key.target);
      if (slot == null) continue; // a group or an instance: no grips (D3)
      if (document.entities.ownerAt(slot) != document.rootHandle) continue;
      final list = leafGrips(document.entities.kindAt(slot),
          document.geometry.peek(document.entities.geomIndexAt(slot)));
      for (var i = 0; i < list.length; i++) {
        _grips.add(GripRef(key, list[i], i));
        if (list[i].role == GripRole.move) _moveCount++;
      }
    }
    if (_grips.length > kMaxGrips) {
      _grips.clear();
      _moveCount = 0;
    }
    _box = box.isEmpty ? null : box;
    _built = selection.keys.toSet();
    notifyListeners();
  }

  @override
  void dispose() {
    selection.removeListener(_onSelection);
    outlines.removeListener(_rebuild);
    super.dispose();
  }
}
```

Add the export to `lib/jet_cad_2d_flutter.dart`, after the last
`src/gpu/...` export:

```dart
export 'src/grip_cache.dart';
```

- [ ] **Step 5: Run them to pass.** `CI=true flutter test
  test/outline_cache_test.dart test/grip_cache_test.dart` → all tests
  pass. Then run the `jet_cad_2d_flutter` gate line: only the five goldens
  fail.
- [ ] **Step 6: Commit.**

```bash
git add packages/jet_cad_2d_flutter/lib/src/outline_cache.dart packages/jet_cad_2d_flutter/lib/src/selection_style.dart packages/jet_cad_2d_flutter/lib/src/grip_cache.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/support/grip_fixture.dart packages/jet_cad_2d_flutter/test/outline_cache_test.dart packages/jet_cad_2d_flutter/test/grip_cache_test.dart
git commit -m "$(cat <<'EOF'
feat(render): worldBoundsOf and GripCache -- grips, box, cap, hit test

Spec 03 D6: the selection box in world doubles from the outline records
(arcs by arcBounds, points by position, never Path.getBounds), the world grips
of every selected root leaf, the kMaxGrips cap, D2's hit order, and the
rotation grip hung screen-up from the screen box.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

