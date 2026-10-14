// 2b spec S4 "Painting"; S2 "Locked units", "Unlabelled, duplicate and bad
// labels": the status, group and focus painters over placed and generated
// units, on the controller's service copy. The fixture is Task 5's
// serviceFixture(): the table turned and mirrored off the origin, row A
// turned, row B curved. Painters are built over the session and recorded
// on a spy canvas; the expected matrices are the camera times the unit's
// world transform computed here from the row's group and the seat's
// instance, never read from the painter.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanKit, kUnitLabelTag;
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show placeSymbol;
import 'package:jet_cad_2d_plan/src/service/service_session.dart' show PlanMode;
import 'package:jet_cad_2d_plan/src/service/service_state.dart'
    show UnitGroup, UnitStatus;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../../support/harness.dart' show planText;
import '../../support/service_fixture.dart';
import '../../support/service_paint.dart';
import '../../support/service_rig.dart' show parts;
import '../../support/test_kit.dart';

/// Records the matrices and paths a painter hands the canvas.
class Spy implements ui.Canvas {
  final List<Float64List> matrices = [];
  final List<ui.Path> paths = [];
  final List<Color> colours = [];
  final List<ui.Paragraph> paragraphs = [];
  final List<ui.Offset> translations = [];

  @override
  void save() {}
  @override
  void restore() {}
  @override
  void translate(double dx, double dy) => translations.add(ui.Offset(dx, dy));
  @override
  void transform(Float64List m) => matrices.add(Float64List.fromList(m));
  @override
  void drawPath(ui.Path path, ui.Paint paint) {
    paths.add(path);
    // A Paint keeps its colour in float32: read back through its ARGB, so
    // a 0xAARRGGBB colour compares equal to the one handed in.
    colours.add(Color(paint.color.toARGB32()));
  }

  @override
  void drawRRect(ui.RRect rrect, ui.Paint paint) {}
  @override
  void drawParagraph(ui.Paragraph p, ui.Offset offset) => paragraphs.add(p);
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnsupportedError('${i.memberName}');
}

const Color red = Color(0xFFE53935), blue = Color(0xFF3949AB);

/// 0.1 px/mm, y up, panned.
const Transform2 cam = Transform2(0.1, 0, 0, -0.1, -3900, -2600);

({PlanController c, ServicePaintLayers layers}) service(String json,
    {List<PlanKit>? kits}) {
  final c = PlanController(kits: kits ?? [unitKit()], json: json);
  addTearDown(c.dispose);
  c.setMode(PlanMode.service);
  c.camera.value = ViewportTransform(worldToScreenMatrix: cam);
  final layers = ServicePaintLayers(
      controller: c, session: c.serviceSession!, darkCanvas: () => false);
  addTearDown(layers.dispose);
  return (c: c, layers: layers);
}

Spy frame(CustomPainter p) {
  final spy = Spy();
  p.paint(spy, const ui.Size(1600, 1200));
  return spy;
}

/// camera · [t] as the 4x4 the painter writes (a, b, c, d, e, f placed).
List<double> matrixOf(Transform2 t) {
  final a = cam.a * t.a + cam.c * t.b, b = cam.b * t.a + cam.d * t.b;
  final c = cam.a * t.c + cam.c * t.d, d = cam.b * t.c + cam.d * t.d;
  final e = cam.a * t.e + cam.c * t.f + cam.e;
  final f = cam.b * t.e + cam.d * t.f + cam.f;
  return [a, b, c, d, e, f];
}

List<double> abcdef(Float64List m) => [m[0], m[1], m[4], m[5], m[12], m[13]];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'SP-seat-fill a status on a seat fills at the row\'s group times the '
      'seat\'s instance, not the instance alone (M-SP-seat)', () {
    final f = serviceFixture();
    final s = service(f.json);
    final doc = s.c.serviceSession!.document;
    final seat = doc.tree[f.seatsA[1]]! as InstanceNode;
    final row = doc.tree[seat.parent]! as GroupNode;
    final world = row.transform.multiply(seat.transform);
    expect(parts(world), isNot(parts(seat.transform)),
        reason: 'premise: the row is placed off the origin and turned');
    s.c.setUnitStatus({'A2': UnitStatus(color: red, caption: 'Bill')});

    final spy = frame(s.layers.statuses);
    expect(spy.paths, hasLength(1));
    final got = abcdef(spy.matrices.single);
    final want = matrixOf(world);
    for (var i = 0; i < 6; i++) {
      expect(got[i], closeTo(want[i], 1e-9), reason: 'coefficient $i');
    }
  });

  test(
      'SP-group-mixed a group of the table and two seats with a group '
      'status: three fills in its colour, one caption, under the lead; a '
      'frame round all three, and one chip (M-SP-frame, M-SP-lead)', () {
    final f = serviceFixture();
    final s = service(f.json);
    final table = s.c.unitIndex[f.table]!.text!;
    expect(table.compareTo('A1'), lessThan(0),
        reason: 'premise: the table\'s number leads the plain label order');
    s.c.setUnitGroups({
      'g': UnitGroup(members: {table, 'A1', 'A2'})
    });
    s.c.setGroupStatus({'g': UnitStatus(color: blue, caption: 'Gr')});

    final fills = frame(s.layers.statuses);
    expect(fills.colours, [blue, blue, blue]);
    expect(fills.paragraphs, hasLength(1), reason: 'one caption');
    // The caption is centred under the lead's label: the table's anchor,
    // its definition-space point through the table's world transform and
    // the camera, computed here.
    final doc = s.c.serviceSession!.document;
    (double, double) anchorOf(Handle label, Transform2 toWorld) {
      final slot = doc.entities.slotOf(label)!;
      final p = doc.geometry.read(doc.entities.geomIndexAt(slot)).coords;
      final w = toWorld.transformPoint(Vector2(p[0], p[1]));
      return (
        cam.a * w.x + cam.c * w.y + cam.e,
        cam.b * w.x + cam.d * w.y + cam.f
      );
    }

    final (lx, ly) =
        anchorOf(f.tableLabel, (doc.tree[f.table]! as InstanceNode).transform);
    final a2 = s.c.unitIndex.withLabel('A2').single;
    final (ox, _) = anchorOf(a2.label!, a2.toWorld);
    expect((ox - lx).abs(), greaterThan(50),
        reason: 'premise: another member\'s anchor is elsewhere');
    final t = fills.translations.single;
    expect(t.dx + fills.paragraphs.single.width / 2, closeTo(lx, 1e-6),
        reason: 'centred under the table\'s label');
    expect(t.dy, greaterThan(ly), reason: 'below the table\'s label');
    final frames = frame(s.layers.frames);
    expect(frames.paths, hasLength(1), reason: 'one frame');
    expect(s.layers.chips.debugChipTexts, isEmpty,
        reason: 'premise: no chip before a chips frame');
    frame(s.layers.chips);
    expect(s.layers.chips.debugChipTexts, ['$table+A1+A2']);
  });

  test(
      'SP-locked-status Review Focus 4: the rows\' kit missing, a group '
      'status paints on the locked seats (M-SP-locked)', () {
    final f = serviceFixture();
    final s = service(f.json, kits: const <PlanKit>[]);
    expect(s.c.unitIndex[f.seatsA[0]]!.locked, isTrue, reason: 'premise');
    s.c.setUnitGroups({
      'g': UnitGroup(members: {'A1', 'A2'})
    });
    s.c.setGroupStatus({'g': UnitStatus(color: blue)});
    expect(frame(s.layers.statuses).colours, [blue, blue]);
  });

  test(
      'SP-dup-label a label two placed units share (a loaded file): a status '
      'on it fills both (M-SP-dup)', () {
    // Two tables, the second's label rewritten to the first's in the file
    // (a host cannot write a used label: setUnitLabel refuses it, Task 9).
    final json = planText([unitKit()], (d) {
      final entry = testEntry(tableSymbolId);
      final a = placeSymbol(d, entry,
          at: Vector2(-2400.5, 3100.25), quarterTurns: 1, mirrored: true);
      d.commands.execute(a);
      final b = placeSymbol(d, entry, at: Vector2(3600.25, -2900.5));
      d.commands.execute(b);
      Handle instanceOf(CompoundCommand c) =>
          c.children.whereType<AddNodeCommand>().last.node.handle;
      final first = instanceOf(a), second = instanceOf(b);
      // A label each: the numbering placer's (Task 7), or the fixture's.
      for (final (h, text) in [(first, '12'), (second, '13')]) {
        if (unitLabelsOf(d, h).isEmpty) {
          labelPlacedUnit(d, h, entry, text);
        }
      }
      d.commands.execute(SetEntityTextCommand(unitLabelsOf(d, second).first.$1,
          unitLabelsOf(d, first).first.$2, kUnitLabelTag));
    });
    final s = service(json);
    final shared = s.c.unitIndex.units.first.text!;
    expect(s.c.unitIndex.withLabel(shared), hasLength(2), reason: 'premise');
    s.c.setUnitStatus({shared: UnitStatus(color: red)});
    expect(frame(s.layers.statuses).colours, [red, red]);
  });
}
