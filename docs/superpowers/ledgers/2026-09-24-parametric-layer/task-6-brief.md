### Task 6: `BoxParams` and `BoxType`

**Files:**
- Create: `apps/floor_planner/lib/parametric/box.dart`
- Test: `apps/floor_planner/test/box_test.dart`

**Interfaces:**
- Consumes: `ParametricType`, `ParametricCatalog`, `ParametricSystem`,
  `Generated` and `ParametricView` (Task 2).
- Produces, used by Tasks 7 and 8:
  - `final class BoxParams implements Component`, with:
    - `const BoxParams(double width, double height)`;
    - `static const String componentTypeId = 'floor_planner.box'`;
    - `BoxParams copyWith({double? width, double? height})`;
    - `static BoxParams fromJson(Map<String, Object?>)`.
  - `final class BoxType extends ParametricType<BoxParams>`, with
    `editCapability == Capability.geometry`.
  - `final ParametricCatalog boxCatalog`.
  - `ParametricSystem installBoxes(DraftDocument doc)`.

- [ ] **Step 1: Write BT1–BT6.**

```dart
// apps/floor_planner/test/box_test.dart
import 'dart:math' as math;

import 'package:floor_planner/parametric/box.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

final Transform2 atA =
    Transform2.translation(7010, 3020).multiply(Transform2.rotation(math.pi / 6));
Transform2 onA(double x, double y, double turn) => atA
    .multiply(Transform2.translation(x, y))
    .multiply(Transform2.rotation(turn));

DraftCommand box(DraftDocument doc, Handle h, Transform2 at, double w, double hh) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h, parent: doc.rootHandle, transform: at, children: const [])),
      SetComponentCommand<BoxParams>(h, BoxParams(w, hh)),
    ], label: 'Add box');

List<Handle> kids(DraftDocument doc, Handle g) => [
      for (final s in doc.entities.liveSlots)
        if (doc.entities.ownerAt(s) == g) doc.entities.handleAt(s),
    ];

void main() {
  const a = Handle(1000), b = Handle(2000);

  test('BT1 BoxParams: value equality, key order, round trip', () {
    const p = BoxParams(1200, 800);
    expect(p.toJson().keys.toList(), ['width', 'height']);
    expect(BoxParams.fromJson(p.toJson()), p);
    expect(p.copyWith(height: 5), const BoxParams(1200, 5));
    expect(p.typeId, 'floor_planner.box');
  });

  test('BT2 an isolated box is four lines at its corners', () {
    final doc = DraftDocument.empty();
    installBoxes(doc);
    doc.commands.execute(box(doc, a, atA, 1200, 800));
    expect(kids(doc, a), hasLength(4));
  });

  test('BT3 a rotated overlapping pair clips each other: A 5, B 3 '
      '(M-06g app, M-06o)', () {
    final doc = DraftDocument.empty();
    installBoxes(doc);
    doc.commands.execute(box(doc, a, atA, 2000, 1000));
    doc.commands.execute(box(doc, b, onA(800, 700, 0.3), 400, 900));
    expect(kids(doc, a), hasLength(5));
    expect(kids(doc, b), hasLength(3));
    expect(ParametricSystem(doc, boxCatalog).drift(), isEmpty);
  });

  test('BT4 two boxes sharing an edge exactly are not neighbours '
      '(Review Focus 5)', () {
    final doc = DraftDocument.empty();
    installBoxes(doc);
    doc.commands.execute(box(doc, a, atA, 1000, 1000));
    doc.commands.execute(box(doc, b, onA(1000, 0, 0), 1000, 1000));
    expect(kids(doc, a), hasLength(4));
    expect(kids(doc, b), hasLength(4));
  });

  test('BT5 editCapability is geometry', () {
    expect(const BoxType().editCapability, Capability.geometry);
  });

  test('BT6 a box reaches exactly its transformed corners', () {
    final r = const BoxType().reach(const BoxParams(2000, 1000), atA);
    final c = [Vector2(0, 0), Vector2(2000, 0), Vector2(2000, 1000), Vector2(0, 1000)]
        .map(atA.transformPoint);
    expect(r.minX, c.map((v) => v.x).reduce(math.min));
    expect(r.maxY, c.map((v) => v.y).reduce(math.max));
  });
}
```

- [ ] **Step 2: Run; it fails to compile.**
- [ ] **Step 3: Implement `box.dart`.** `BoxType.generate` is the test
  client's `clippedRect` restricted to `BoxParams` neighbours. Copy
  `insideInterval` verbatim, as `_insideInterval` (Ruling 06-9).

```dart
// apps/floor_planner/lib/parametric/box.dart
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The demo parametric object's parameters (spec 06 D13), in mm.
final class BoxParams implements Component {
  const BoxParams(this.width, this.height);

  static const String componentTypeId = 'floor_planner.box';

  final double width;
  final double height;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'width': width, 'height': height};

  static BoxParams fromJson(Map<String, Object?> json) => BoxParams(
      (json['width']! as num).toDouble(), (json['height']! as num).toDouble());

  BoxParams copyWith({double? width, double? height}) =>
      BoxParams(width ?? this.width, height ?? this.height);

  @override
  bool operator ==(Object other) =>
      other is BoxParams && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

List<Vector2> _corners(BoxParams p) => [
      Vector2(0, 0),
      Vector2(p.width, 0),
      Vector2(p.width, p.height),
      Vector2(0, p.height),
    ];

/// A rectangle whose outline loses what lies strictly inside any
/// overlapping box: overlapping boxes read as one outline, the wall
/// clean-up preview (spec 06 D13).
final class BoxType extends ParametricType<BoxParams> {
  const BoxType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(BoxParams params, Transform2 toWorld) => Aabb2.fromPoints(
      [for (final c in _corners(params)) toWorld.transformPoint(c)]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<BoxParams>(self)!;
    // M-06o fires here: toWorld(self) without .invert().
    final toLocal = view.toWorld(self).invert();
    final quads = [
      for (final n in view.neighbours(self))
        if (view.paramsOf<BoxParams>(n) case final q?)
          [
            for (final c in _corners(q))
              toLocal.transformPoint(view.toWorld(n).transformPoint(c)),
          ],
    ];
    final c = _corners(p);
    const tol = Tolerance.standard;
    final out = <Generated>[];
    for (var i = 0; i < 4; i++) {
      final a = c[i], b = c[(i + 1) % 4];
      final len = (b - a).length;
      var keep = <(double, double)>[(0, 1)];
      for (final q in quads) {
        final inside = _insideInterval(a, b, q);
        if (inside == null) continue;
        keep = [
          for (final (lo, hi) in keep) ...[
            if ((math.min(hi, inside.$1) - lo) * len > tol.linear)
              (lo, math.min(hi, inside.$1)),
            if ((hi - math.max(lo, inside.$2)) * len > tol.linear)
              (math.max(lo, inside.$2), hi),
          ],
        ];
      }
      for (final (lo, hi) in keep) {
        out.add(Generated(
            EntityKind.line, linePayload(a + (b - a) * lo, a + (b - a) * hi)));
      }
    }
    return out;
  }
}

/// The open parameter interval of a->b strictly inside the convex quad [q].
(double, double)? _insideInterval(Vector2 a, Vector2 b, List<Vector2> q) {
  const tol = Tolerance.standard;
  var area = 0.0;
  for (var i = 0; i < 4; i++) {
    final u = q[i], v = q[(i + 1) % 4];
    area += u.x * v.y - v.x * u.y;
  }
  final s = area > 0 ? 1.0 : -1.0;
  final d = b - a;
  var lo = 0.0, hi = 1.0;
  for (var i = 0; i < 4; i++) {
    final u = q[i], v = q[(i + 1) % 4];
    final e = v - u;
    final len = e.length;
    final f0 = s * (e.x * (a.y - u.y) - e.y * (a.x - u.x)) / len;
    final fd = s * (e.x * d.y - e.y * d.x) / len;
    if (fd.abs() <= tol.linear) {
      if (f0 <= tol.linear) return null;
      continue;
    }
    final t = (tol.linear - f0) / fd;
    if (fd > 0) {
      lo = math.max(lo, t);
    } else {
      hi = math.min(hi, t);
    }
  }
  return (hi - lo) * d.length > tol.linear ? (lo, hi) : null;
}

/// The floor planner's parametric types.
final ParametricCatalog boxCatalog = ParametricCatalog()
  ..register<BoxParams>(
      BoxParams.componentTypeId, BoxParams.fromJson, const BoxType());

/// Builds and installs the document's parametric system.
ParametricSystem installBoxes(DraftDocument doc) =>
    ParametricSystem(doc, boxCatalog)..install();
```

- [ ] **Step 4: Run BT1–BT6; they pass. Then run the app line.**
- [ ] **Step 5: Commit.**

```bash
git add apps/floor_planner/lib/parametric/box.dart apps/floor_planner/test/box_test.dart
git commit -m "$(cat <<'EOF'
feat(floor_planner): BoxParams and BoxType, the parametric demo (spec 06 D13)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

