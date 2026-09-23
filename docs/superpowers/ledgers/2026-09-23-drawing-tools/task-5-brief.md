### Task 5: `CircleTool` and `ArcTool`

Package: `packages/jet_cad_2d_flutter`.

**Files:**
- Create: `lib/src/draw/circle_tool.dart`, `lib/src/draw/arc_tool.dart`
- Modify: `lib/jet_cad_2d_flutter.dart` (two exports)
- Test: `test/draw/circle_tool_test.dart` (C1–C3),
  `test/draw/arc_tool_test.dart` (AR1–AR6)

**Interfaces:**
- Consumes:
  - Task 3: `PlacementTool` (`hovered`, `commitShape`).
  - Task 1: `circlePayload`, `arcPayload`, `isDegenerateRadius`.
  - Task 2: `SweepTracker`.
- Produces:
  - `class CircleTool extends PlacementTool { CircleTool({ValueListenable<bool>? fill}); }`
  - `class ArcTool extends PlacementTool { ArcTool(); }`

- [ ] **Step 1: Write the failing tests.** Create
  `test/draw/circle_tool_test.dart`:

```dart
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/circle_tool.dart';

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

List<Handle> ofKind(DraftDocument doc, EntityKind kind) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == kind) doc.entities.handleAt(slot),
    ];

void main() {
  for (final flipY in const [true, false]) {
    test('C1 flipY $flipY: centre and a point on the circle', () {
      final s = drawScene();
      final rig =
          drawRig(s.document, CircleTool(), flipY: flipY, objectSnap: false);
      final c = screenOf(rig.camera, 7050.5, 3080.25);
      final r = screenOf(rig.camera, 7091.75, 3102.5);
      clickAt(rig, c);
      clickAt(rig, r);
      final p =
          payloadOf(s.document, ofKind(s.document, EntityKind.circle).single);
      final wc = worldAt(rig, c), wr = worldAt(rig, r);
      expect(p.coords.toList(), [wc.x, wc.y]);
      expect(p.scalars.toList(), [wc.distanceTo(wr)]);
    });
  }

  test('C2 with Fill on, a circle commits as one region', () {
    final s = drawScene();
    final fill = ValueNotifier<bool>(true);
    addTearDown(fill.dispose);
    final rig =
        drawRig(s.document, CircleTool(fill: fill), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    clickAt(rig, screenOf(rig.camera, 7090, 3100));
    final circle = ofKind(s.document, EntityKind.circle).single;
    expect(s.document.fills.fillsOf(circle), hasLength(1));
    expect(s.document.commands.undoDepth, 1);
  });

  test('C3 a zero radius is refused', () {
    final s = drawScene();
    final rig = drawRig(s.document, CircleTool(), objectSnap: false);
    final c = screenOf(rig.camera, 7050, 3080);
    clickAt(rig, c);
    final before = snapshot(s.document);
    clickAt(rig, c);
    expect(snapshot(s.document), before);
    expect(rig.tool.isPending, isTrue);
  });
}
```

  Create `test/draw/arc_tool_test.dart`. The camera is non-identity, so the
  helper places pointer positions by **world** coordinates on a circle
  around the centre:

```dart
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/arc_tool.dart';

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

Handle arcOf(DraftDocument doc) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == EntityKind.arc)
          doc.entities.handleAt(slot),
    ].single;

const double cx = 7150.5, cy = 3120.25;

/// The pointer at [angle] on a circle of [r] around the centre.
void at(DrawRig rig, double angle, double r,
        {bool click = false, bool down = false}) =>
    down
        ? downAt(rig,
            screenOf(rig.camera, cx + r * math.cos(angle), cy + r * math.sin(angle)))
        : click
            ? clickAt(rig,
                screenOf(rig.camera, cx + r * math.cos(angle), cy + r * math.sin(angle)))
            : hoverAt(rig,
                screenOf(rig.camera, cx + r * math.cos(angle), cy + r * math.sin(angle)));

void main() {
  for (final flipY in const [true, false]) {
    test('AR1 flipY $flipY: an asymmetric CCW arc stores start then sweep '
        '(M-05e)', () {
      final s = drawScene();
      final rig =
          drawRig(s.document, ArcTool(), flipY: flipY, objectSnap: false);
      clickAt(rig, screenOf(rig.camera, cx, cy));
      at(rig, 0.3, 40, click: true);
      for (final a in const [0.8, 1.4, 2.0]) {
        at(rig, a, 40);
      }
      at(rig, 2.2, 55, click: true); // the end need not be on the circle
      final p = payloadOf(s.document, arcOf(s.document));
      final start = p.scalars[1], sweep = p.scalars[2];
      expect(start, closeTo(0.3, 1e-6));
      expect(sweep, closeTo(1.9, 1e-6));
      expect(p.scalars[0], closeTo(40, 1e-6));
      expect(rig.tool.points, isEmpty, reason: 'cleared after the commit');
    });
  }

  test('AR2 a clockwise path gives a negative sweep (M-05g)', () {
    final s = drawScene();
    final rig = drawRig(s.document, ArcTool(), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, cx, cy));
    at(rig, 0.3, 40, click: true);
    for (final a in const [0.0, -0.5, -1.0]) {
      at(rig, a, 40);
    }
    at(rig, -1.2, 40, click: true);
    final p = payloadOf(s.document, arcOf(s.document));
    expect(p.scalars[2], closeTo(-1.5, 1e-6));
  });

  test('AR3 a path across the ±π seam keeps its direction (M-05f)', () {
    final s = drawScene();
    final rig = drawRig(s.document, ArcTool(), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, cx, cy));
    at(rig, 2.9, 40, click: true);
    for (final a in const [3.05, -3.05, -2.9]) {
      at(rig, a, 40);
    }
    at(rig, -2.8, 40, click: true);
    final p = payloadOf(s.document, arcOf(s.document));
    expect(p.scalars[2], greaterThan(0));
    expect(p.scalars[2], closeTo(-2.8 + 2 * math.pi - 2.9, 1e-6));
  });

  test('AR4 an end press with no hover after the start is CCW (M-05z)', () {
    final s = drawScene();
    final rig = drawRig(s.document, ArcTool(), objectSnap: false);
    downAt(rig, screenOf(rig.camera, cx, cy));
    at(rig, 0.3, 40, down: true);
    at(rig, -1.0, 40, down: true);
    final p = payloadOf(s.document, arcOf(s.document));
    expect(p.scalars[2], greaterThan(0), reason: 'τ == 0 is CCW');
    expect(p.scalars[2], closeTo(2 * math.pi - 1.3, 1e-6));
  });

  test('AR5 Fill does not apply to an arc', () {
    final s = drawScene();
    final fill = ValueNotifier<bool>(true);
    addTearDown(fill.dispose);
    final rig = drawRig(s.document, ArcTool(), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, cx, cy));
    at(rig, 0.3, 40, click: true);
    at(rig, 1.0, 40);
    at(rig, 1.2, 40, click: true);
    expect(s.document.fills.fillsOf(arcOf(s.document)), isEmpty);
    expect(fill.value, isTrue);
  });

  test('AR6 an end on the start ray is refused and the tool waits', () {
    final s = drawScene();
    final rig = drawRig(s.document, ArcTool(), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, cx, cy));
    at(rig, 0.3, 40, click: true);
    final before = snapshot(s.document);
    downAt(rig,
        screenOf(rig.camera, cx + 70 * math.cos(0.3), cy + 70 * math.sin(0.3)));
    expect(snapshot(s.document), before);
    expect(rig.tool.isPending, isTrue);
  });
}
```

  The raw pointer goes through a screen round trip, so the angles hold only
  to about 1e-9 rad. The 1e-6 tolerances absorb that; the stored start is
  compared with `atan2` of the stored start point in AR1's intent.

  **AR6 depends on the round trip landing exactly on the start ray.** It
  may not. If AR6 misbehaves, place the end with a snap:
  - put a line on the ray in the scene;
  - turn object snap on, so the end lands exactly on the start's direction.

  In the test, replace `downAt` with a press at that line's endpoint, and
  assert the refusal.

- [ ] **Step 2: Run them and see them fail** (compile errors).

- [ ] **Step 3: Implement.** `lib/src/draw/circle_tool.dart`:

```dart
import 'dart:ui' show Canvas, Offset, Rect;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tool.dart';
import 'placement_tool.dart';

/// Spec 05 D7: the centre, then a point on the circle.
class CircleTool extends PlacementTool {
  CircleTool({super.fill});

  @override
  String get name => 'Circle';

  @override
  Vector2? get orthoBase => points.isEmpty ? null : points.first;

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    final c = points.first;
    final r = c.distanceTo(point);
    if (isDegenerateRadius(r)) return;
    commitShape(ctx, EntityKind.circle, circlePayload(c, r), fillable: true);
    clearShape();
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    if (points.isEmpty || !hoverVisible) return;
    final c = points.first, h = hoverPoint;
    final r = c.distanceTo(h);
    band
      ..reset()
      ..addOval(
          Rect.fromCircle(center: Offset(c.x - origin.x, c.y - origin.y), radius: r))
      ..moveTo(c.x - origin.x, c.y - origin.y)
      ..lineTo(h.x - origin.x, h.y - origin.y);
    canvas.drawPath(band, bandPaint);
  }
}
```

  `lib/src/draw/arc_tool.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui' show Canvas, Offset, Rect;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tool.dart';
import 'placement_tool.dart';

/// Spec 05 D8: centre, start, end. The start sets the radius and the start
/// angle; the end sets only the end angle. The sweep follows the angle the
/// pointer travelled around the centre ([SweepTracker]). Fill does not
/// apply.
class ArcTool extends PlacementTool {
  ArcTool();

  final SweepTracker _tracker = SweepTracker();
  double _r = 0;

  @override
  String get name => 'Arc';

  @override
  Vector2? get orthoBase => points.isEmpty ? null : points.first;

  double _angleOf(Vector2 p) =>
      math.atan2(p.y - points.first.y, p.x - points.first.x);

  @override
  void hovered(Vector2 raw) {
    if (points.length == 2) _tracker.track(_angleOf(raw));
  }

  @override
  void accept(Vector2 point, ToolContext ctx) {
    switch (points.length) {
      case 0:
        points.add(point);
      case 1:
        final r = points.first.distanceTo(point);
        if (isDegenerateRadius(r)) return;
        _r = r;
        _tracker.begin(_angleOf(point));
        points.add(point);
      default:
        final sweep = _tracker.sweepTo(_angleOf(point));
        if (sweep == 0) return;
        commitShape(ctx, EntityKind.arc,
            arcPayload(points.first, _r, _tracker.start, sweep));
        clearShape();
    }
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    if (points.isEmpty || !hoverVisible) return;
    final c = points.first;
    final co = Offset(c.x - origin.x, c.y - origin.y);
    final h = hoverPoint;
    band.reset();
    if (points.length == 1) {
      band
        ..moveTo(co.dx, co.dy)
        ..lineTo(h.x - origin.x, h.y - origin.y);
    } else {
      final sweep = _tracker.sweepTo(_angleOf(h));
      final start = _tracker.start;
      band
        ..addArc(Rect.fromCircle(center: co, radius: _r), start, sweep)
        ..moveTo(co.dx, co.dy)
        ..lineTo(co.dx + _r * math.cos(start), co.dy + _r * math.sin(start))
        ..moveTo(co.dx, co.dy)
        ..lineTo(co.dx + _r * math.cos(start + sweep),
            co.dy + _r * math.sin(start + sweep));
    }
    canvas.drawPath(band, bandPaint);
  }
}
```

  Add the two exports.

- [ ] **Step 4: Run the tests and see them pass.**
  Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/`

- [ ] **Step 5: Gate and commit.**

```bash
git add packages/jet_cad_2d_flutter/lib/src/draw/circle_tool.dart packages/jet_cad_2d_flutter/lib/src/draw/arc_tool.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/draw/circle_tool_test.dart packages/jet_cad_2d_flutter/test/draw/arc_tool_test.dart
git commit -m "$(cat <<'EOF'
feat(draw): circle and centre-start-end arc tools

The circle is a centre and a point on it, and fills with Fill on. The
arc's sweep follows the angle the pointer travelled around the centre:
seam-safe, counter-clockwise when nothing was travelled, and refused
when the end is on the start. The start and the sweep are stored in
that order. Spec 05 D7, D8.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

