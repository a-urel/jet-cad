// Table-groups spec G3: the group frames and label chips
// (`TableGroupPainter`), and the status painter's group status: the
// override, the one caption under the lead, the allocation bar.
//
// Fixtures are off the origin, turned and mirrored; numbers are not sorted
// in handle order (`G7` holds 12, 3 and 7, placed in that order); one
// variant carries a number twice (a hand-edited file), one has a member on
// a hidden layer, one a member with no top. The frame's geometry is checked
// on an asymmetric definition whose box is off its base point, one member
// mirrored and one not, with a non-member placed beside them.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show Color, CustomPainter;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/service/table_group_painter.dart';
import 'package:jet_cad_floor_plan/src/service/table_groups.dart';
import 'package:jet_cad_floor_plan/src/service/table_picker.dart';
import 'package:jet_cad_floor_plan/src/service/table_status_painter.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:jet_cad_floor_plan/symbols.dart'
    show FurnitureSymbol, PolylineShape;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_fixture.dart';
import 'table_status_painter_test.dart' show SpyCanvas;

/// Records what a group painter hands the canvas: identities, the stroke
/// width each path is drawn with (the paint is reused, so it is read at
/// the call), the chips' translations, rects and paragraphs.
class GroupSpy implements ui.Canvas {
  final List<Object> seen = [];
  final List<Float64List> matrices = [];
  final List<ui.Path> paths = [];
  final List<ui.Paint> paints = [];
  final List<double> strokeWidths = [];
  final List<ui.Offset> translations = [];
  final List<ui.RRect> rrects = [];
  final List<ui.Paragraph> paragraphs = [];

  @override
  void save() {}
  @override
  void restore() {}
  @override
  void translate(double dx, double dy) => translations.add(ui.Offset(dx, dy));
  @override
  void transform(Float64List matrix4) {
    seen.add(matrix4);
    matrices.add(Float64List.fromList(matrix4));
  }

  @override
  void drawPath(ui.Path path, ui.Paint paint) {
    seen
      ..add(path)
      ..add(paint);
    paths.add(path);
    paints.add(paint);
    strokeWidths.add(paint.strokeWidth);
  }

  @override
  void drawRRect(ui.RRect rrect, ui.Paint paint) {
    seen
      ..add(rrect)
      ..add(paint);
    rrects.add(rrect);
    paints.add(paint);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) {
    expect(offset, ui.Offset.zero, reason: 'no Offset per frame (R-3)');
    seen.add(paragraph);
    paragraphs.add(paragraph);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

/// An open first shape: the table has no top (14c R-8), so it is never
/// filled and never leads.
FurnitureSymbol openTable() => const FurnitureSymbol(
      key: 'test.open',
      name: 'Open table',
      category: 'Tests',
      tags: ['table', 'test'],
      seats: 2,
      baseX: 900,
      baseY: 700,
      shapes: [
        PolylineShape([(300, 300), (1500, 300), (1500, 1100)]),
        PolylineShape([(300, 300), (1500, 300), (1500, 1100), (300, 1100)],
            closed: true),
      ],
    );

/// An asymmetric definition whose box (200..2100 x 300..1000) is far off
/// its base point (400, 400): a mirror moves the box (selection spec R-2).
const FurnitureSymbol skewTable = FurnitureSymbol(
  key: 'test.skew',
  name: 'Skew table',
  category: 'Tests',
  tags: ['table', 'test'],
  seats: 3,
  baseX: 400,
  baseY: 400,
  shapes: [
    PolylineShape([(200, 300), (1600, 300), (1300, 1000), (500, 900)],
        closed: true),
    PolylineShape([(1700, 400), (2100, 400), (2100, 800), (1700, 800)],
        closed: true),
  ],
);

/// A layer named [name], visible or not.
Handle addLayer(DraftDocument doc, String name, {required bool visible}) {
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  final h = doc.handleSeed.next();
  doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: h,
      name: name,
      color: const IndexedColor(3),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: visible,
      locked: false)));
  return h;
}

/// [tables] placed in order (so in handle order) and numbered.
DraftDocument tablesPlan(List<(FurnitureSymbol, Transform2, String)> tables) {
  final doc = plan();
  for (final (s, p, _) in tables) {
    doc.commands.execute(
        placeSymbol(doc, entryOf(s), at: Vector2.zero(), transform: p));
  }
  final placed = TableSurvey.of(doc).tables;
  for (var i = 0; i < tables.length; i++) {
    doc.commands.execute(
        SetEntityTextCommand(placed[i].label!, tables[i].$3, kTableLabelTag));
  }
  return doc;
}

/// Where each table of [groupedPlan] sits (its base point, where its
/// number is), by index.
const List<(double, double)> kAt = [
  (40000, -27000), // 12
  (42600, -26500), // 3
  (45200, -27400), // 7
  (41300, -24300), // 20
  (38200, -24800), // 9, hidden
  (44000, -24600), // the duplicate 3
];

/// Tables numbered 12, 3, 7, 20 and 9 (on a hidden layer), in handle
/// order, turned and mirrored; [duplicate] adds a second 3 (a file
/// duplicate) after them; [noTop] makes table 3 one with no top.
DraftDocument groupedPlan({bool duplicate = false, bool noTop = false}) {
  final t = tableSymbol();
  final doc = tablesPlan([
    (t, placementAt(kAt[0].$1, kAt[0].$2, kDeg37, mirrored: true), '12'),
    (noTop ? openTable() : t, placementAt(kAt[1].$1, kAt[1].$2, -kDeg37), '3'),
    (t, placementAt(kAt[2].$1, kAt[2].$2, 2 * kDeg37, mirrored: true), '7'),
    (t, placementAt(kAt[3].$1, kAt[3].$2, 0, mirrored: true), '20'),
    (t, placementAt(kAt[4].$1, kAt[4].$2, 3 * kDeg37), '9'),
    if (duplicate) (t, placementAt(kAt[5].$1, kAt[5].$2, kDeg37), '3'),
  ]);
  final hidden = addLayer(doc, 'Hidden', visible: false);
  doc.commands.execute(SetInstanceLayerCommand(
      TableSurvey.of(doc).withNumber('9').single.instance, hidden));
  return doc;
}

/// The camera: world (42600, -26500) at screen (500, 400), [scale] px per
/// mm, y up.
ViewportTransform cameraAt(double scale) => ViewportTransform(
    worldToScreenMatrix: Transform2(
        scale, 0, 0, -scale, 500 - scale * 42600, 400 - scale * 26500));

/// The screen point of world ([x], [y]) through [camera].
(double, double) screenOf(ViewportTransform camera, double x, double y) {
  final s = camera.worldToScreen(Vector2(x, y));
  return (s.x, s.y);
}

TableGroup tg(Set<String> members, {String? label}) =>
    TableGroup(members: members, label: label);

/// The demo's statuses (`apps/restaurant_demo/lib/main.dart`).
const Color ordered = Color(0x99FFB300), eating = Color(0x9943A047);
const Color bill = Color(0x99E53935);

const ui.Size kSize = ui.Size(1000, 800);

/// A group painter of [layer] over [doc].
TableGroupPainter groupPainter(
    TableGroupLayer layer,
    DraftDocument doc,
    ValueNotifier<ViewportTransform> camera,
    ValueNotifier<Map<String, TableGroup>> groups,
    {ValueNotifier<int>? paper,
    TablePicker? picker}) {
  final p = paper ?? ValueNotifier<int>(0xFFFFFFFF);
  return TableGroupPainter(
      layer: layer,
      document: doc,
      picker: picker ?? TablePicker(doc),
      camera: camera,
      groups: groups,
      paper: p,
      repaint: Listenable.merge([camera, groups, p]));
}

/// The status painter over [doc] with groups.
TableStatusPainter statusPainter(
    DraftDocument doc,
    ValueNotifier<ViewportTransform> camera,
    ValueNotifier<Map<String, TableStatus>> statuses,
    ValueNotifier<Map<String, TableGroup>> groups,
    ValueNotifier<Map<String, TableStatus>> groupStatuses) {
  final paper = ValueNotifier<int>(0xFFFFFFFF);
  return TableStatusPainter(
      document: doc,
      camera: camera,
      statuses: statuses,
      tableGroups: groups,
      groupStatuses: groupStatuses,
      paper: paper,
      repaint: Listenable.merge([camera, statuses, groups, groupStatuses]));
}

GroupSpy frame(CustomPainter painter) {
  final spy = GroupSpy();
  painter.paint(spy, kSize);
  return spy;
}

SpyCanvas statusFrame(TableStatusPainter painter) {
  final spy = SpyCanvas();
  painter.paint(spy, kSize);
  return spy;
}

/// The world corners of each table numbered [n]'s definition box.
List<(double, double)> cornersOf(DraftDocument doc, String n) => [
      for (final t in TableSurvey.of(doc).withNumber(n))
        for (final (x, y) in _boxCorners(doc.definitionBounds(t.definition)))
          _world((doc.tree[t.instance]! as InstanceNode).transform, x, y),
    ];

List<(double, double)> _boxCorners(Aabb2 b) => [
      (b.minX, b.minY),
      (b.maxX, b.minY),
      (b.maxX, b.maxY),
      (b.minX, b.maxY),
    ];

(double, double) _world(Transform2 t, double x, double y) {
  final w = t.transformPoint(Vector2(x, y));
  return (w.x, w.y);
}

void main() {
  group('the status painter with groups (G3)', () {
    test(
        'TG-L1 a group status fills every visible member over its own status, '
        'with one caption, under the lead 3 of {12, 3, 7} (numeric order); '
        'cleared, the member\'s own status shows again (M-TG-10, M-TG-11)', () {
      final doc = groupedPlan();
      final camera = ValueNotifier(cameraAt(0.06));
      final statuses = ValueNotifier<Map<String, TableStatus>>({
        '3': TableStatus(color: ordered, caption: 'Ord'),
        '20': TableStatus(color: eating, caption: 'Eat'),
      });
      final groups = ValueNotifier<Map<String, TableGroup>>({
        'G7': tg({'12', '3', '7', '9'})
      });
      final groupStatuses = ValueNotifier<Map<String, TableStatus>>(
          {'G7': TableStatus(color: bill, caption: 'Bill')});
      final painter =
          statusPainter(doc, camera, statuses, groups, groupStatuses);

      final spy = statusFrame(painter);
      expect([
        for (final p in spy.paints) p.color.toARGB32()
      ], [
        for (final c in [bill, bill, bill, eating]) c.toARGB32()
      ], reason: '12, 3, 7 Bill (3 not Ordered, 9 hidden), 20 its own');
      expect(spy.paragraphs, hasLength(2), reason: 'G7 once, 20 once');
      // The paragraphs in draw order: G7's caption (under 3), then 20's.
      final (x3, _) = screenOf(camera.value, kAt[1].$1, kAt[1].$2);
      final (x20, _) = screenOf(camera.value, kAt[3].$1, kAt[3].$2);
      final p = spy.paragraphs;
      final t = spy.translations;
      expect(t[0].dx + p[0].width / 2, closeTo(x3, 1e-6),
          reason: 'the group caption is centred under 3');
      expect(t[1].dx + p[1].width / 2, closeTo(x20, 1e-6));

      groupStatuses.value = const {};
      final cleared = statusFrame(painter);
      expect([
        for (final p in cleared.paints) p.color.toARGB32()
      ], [
        ordered.toARGB32(),
        eating.toARGB32()
      ], reason: '3 its own Ordered again; 12 and 7 none');
      expect(cleared.paragraphs, hasLength(2));
      expect(cleared.translations.first.dx + cleared.paragraphs.first.width / 2,
          closeTo(x3, 1e-6),
          reason: '3\'s own caption');

      // A status set for the group again, then the member leaves it: the
      // groups alone change.
      groupStatuses.value = {'G7': TableStatus(color: bill, caption: 'Bill')};
      expect(statusFrame(painter).paints, hasLength(4));
      groups.value = {
        'G7': tg({'12', '7'})
      };
      expect([
        for (final p in statusFrame(painter).paints) p.color.toARGB32()
      ], [
        for (final c in [bill, ordered, bill, eating]) c.toARGB32()
      ], reason: '3 out of the group shows its own status');
    });

    test(
        'TG-L2 the lead\'s number duplicated by a file: the group caption is '
        'drawn once, under the lower handle (M-TG-11b)', () {
      final doc = groupedPlan(duplicate: true);
      final camera = ValueNotifier(cameraAt(0.06));
      final painter = statusPainter(
          doc,
          camera,
          ValueNotifier(const {}),
          ValueNotifier({
            'G7': tg({'12', '3', '7'})
          }),
          ValueNotifier({'G7': TableStatus(color: bill, caption: 'Bill')}));
      final spy = statusFrame(painter);
      expect(spy.paths, hasLength(4), reason: '12, 3, 7 and the second 3');
      expect(spy.paragraphs, hasLength(1));
      final (x3, _) = screenOf(camera.value, kAt[1].$1, kAt[1].$2);
      expect(spy.translations.single.dx + spy.paragraphs.single.width / 2,
          closeTo(x3, 1e-6),
          reason: 'under the first 3, not the duplicate');
    });

    test(
        'TG-L3 the lead is chosen among members with a top: 3 has none, so '
        'the caption is under 7 (G3)', () {
      final doc = groupedPlan(noTop: true);
      final camera = ValueNotifier(cameraAt(0.06));
      final painter = statusPainter(
          doc,
          camera,
          ValueNotifier(const {}),
          ValueNotifier({
            'G7': tg({'12', '3', '7'})
          }),
          ValueNotifier({'G7': TableStatus(color: bill, caption: 'Bill')}));
      final spy = statusFrame(painter);
      expect(spy.paths, hasLength(2), reason: '12 and 7; 3 has no top');
      final (x7, _) = screenOf(camera.value, kAt[2].$1, kAt[2].$2);
      expect(spy.paragraphs, hasLength(1));
      expect(spy.translations.single.dx + spy.paragraphs.single.width / 2,
          closeTo(x7, 1e-6));
    });
  });

  group('the frames (G3)', () {
    // Members A (mirrored, turned 37 degrees) and B (turned 74, not
    // mirrored) of the skew definition; C, not a member, beside them:
    // outside the hull plus the margin, inside the members' bounding box.
    DraftDocument skewPlan() => tablesPlan([
          (
            skewTable,
            placementAt(40000, -27000, kDeg37,
                mirrored: true, baseX: 400, baseY: 400),
            '4'
          ),
          (
            skewTable,
            placementAt(42600, -25000, 2 * kDeg37, baseX: 400, baseY: 400),
            '2'
          ),
          (
            tableSymbol(),
            placementAt(39000, -25200, kDeg37, mirrored: true),
            '30'
          ),
        ]);

    test(
        'TG-L4 the frame holds every member\'s box corner pushed out by less '
        'than the margin in any direction, not by more at the extremes, and '
        'excludes the non-member beside them (M-TG-12)', () {
      final doc = skewPlan();
      final camera = ValueNotifier(cameraAt(0.05));
      final painter = groupPainter(
          TableGroupLayer.frames,
          doc,
          camera,
          ValueNotifier({
            'G1': tg({'4', '2'})
          }));
      final spy = frame(painter);
      final path = spy.paths.single;
      // Drawn in world space under the camera's matrix.
      final cam = camera.value.worldToScreenMatrix;
      expect(spy.matrices.single.sublist(0, 2), [cam.a, cam.b]);
      expect([spy.matrices.single[4], spy.matrices.single[5]], [cam.c, cam.d]);
      expect(
          [spy.matrices.single[12], spy.matrices.single[13]], [cam.e, cam.f]);

      final corners = [...cornersOf(doc, '4'), ...cornersOf(doc, '2')];
      const m = kGroupFrameMarginMm;
      for (final (x, y) in corners) {
        for (var k = 0; k < 8; k++) {
          final a = k * math.pi / 4;
          final p =
              ui.Offset(x + 0.9 * m * math.cos(a), y + 0.9 * m * math.sin(a));
          expect(path.contains(p), isTrue, reason: '($x, $y) pushed at $k');
        }
      }
      final xs = [for (final c in corners) c.$1];
      final ys = [for (final c in corners) c.$2];
      final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
      final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
      for (final (x, y) in corners) {
        for (final (dx, dy, extreme) in [
          (-1.0, 0.0, x == minX),
          (1.0, 0.0, x == maxX),
          (0.0, -1.0, y == minY),
          (0.0, 1.0, y == maxY),
        ]) {
          if (!extreme) continue;
          expect(path.contains(ui.Offset(x + 0.9 * m * dx, y + 0.9 * m * dy)),
              isTrue);
          expect(path.contains(ui.Offset(x + 1.1 * m * dx, y + 1.1 * m * dy)),
              isFalse,
              reason: 'the margin is $m: ($x, $y) by ${1.1 * m}');
        }
      }

      // C: premises, then its box's outline (40 points per side) and its
      // centre are all outside.
      final c = TableSurvey.of(doc).withNumber('30').single;
      final cNode = doc.tree[c.instance]! as InstanceNode;
      final centre = _world(cNode.transform, 900, 700);
      expect(minX < centre.$1 && centre.$1 < maxX, isTrue,
          reason: 'premise: C is inside the members\' bounding box');
      expect(minY < centre.$2 && centre.$2 < maxY, isTrue);
      expect(path.contains(ui.Offset(centre.$1, centre.$2)), isFalse);
      final b = doc.definitionBounds(c.definition);
      final box = _boxCorners(b);
      for (var i = 0; i < 4; i++) {
        final (x0, y0) = box[i];
        final (x1, y1) = box[(i + 1) % 4];
        for (var k = 0; k <= 40; k++) {
          final (wx, wy) = _world(cNode.transform, x0 + (x1 - x0) * k / 40,
              y0 + (y1 - y0) * k / 40);
          expect(path.contains(ui.Offset(wx, wy)), isFalse,
              reason: 'C\'s box at side $i, $k');
        }
      }
      // Premise: a frame twice as wide would reach C (it is beside them).
      final (nx, ny) = (cornersOf(doc, '30')).reduce((p, q) =>
          _hullDistance(corners, p) < _hullDistance(corners, q) ? p : q);
      expect(_hullDistance(corners, (nx, ny)), inInclusiveRange(m, 2 * m));
    });

    test(
        'TG-L5 frames: a group of one visible member has none, frames are '
        'drawn in ascending lowest member handle, stroked 2 screen px at any '
        'zoom with one reused paint, in the paper\'s gripMove (M-TG-12, '
        'M-TG-13, M-TG-21)', () {
      final doc = groupedPlan();
      final camera = ValueNotifier(cameraAt(0.06));
      final paper = ValueNotifier<int>(0xFFFFFFFF);
      final groups = ValueNotifier<Map<String, TableGroup>>({
        'GB': tg({'7', '20'}),
        'GH': tg({'3', '9'}), // 9 hidden: one visible member
        'GA': tg({'12', '99'}), // 99 not in the plan
      });
      final painter = groupPainter(TableGroupLayer.frames, doc, camera, groups,
          paper: paper);
      expect(frame(painter).paths, hasLength(1),
          reason: 'GB only: GH and GA have one visible member each');

      // Interleaved handle ranges (review 3): GA = {12, 20} spans handles
      // 0..3 and GB = {7, 3} sits inside it, so only the *lowest* member
      // puts GA first; the highest would put GB first.
      groups.value = {
        'GB': tg({'7', '3'}),
        'GA': tg({'12', '20'}),
      };
      final spy = frame(painter);
      expect(spy.paths, hasLength(2));
      final at12 = ui.Offset(kAt[0].$1, kAt[0].$2);
      final at7 = ui.Offset(kAt[2].$1, kAt[2].$2);
      expect(spy.paths[0].contains(at12), isTrue,
          reason: 'GA (lowest member 12) first, whatever the map\'s order');
      expect(spy.paths[1].contains(at7), isTrue);
      expect(
          spy.strokeWidths, [closeTo(2 / 0.06, 1e-4), closeTo(2 / 0.06, 1e-4)]);
      expect(identical(spy.paints[0], spy.paints[1]), isTrue);
      expect(spy.paints[0].style, ui.PaintingStyle.stroke, reason: 'no fill');
      expect(spy.paints[0].color.toARGB32(), 0xFF7A3FD1);

      camera.value = cameraAt(0.13);
      final zoomed = frame(painter);
      expect(zoomed.strokeWidths,
          [closeTo(2 / 0.13, 1e-4), closeTo(2 / 0.13, 1e-4)]);
      expect(identical(zoomed.paints[0], spy.paints[0]), isTrue);

      paper.value = 0xFF1F3A5F; // Blueprint
      final dark = frame(painter);
      expect(dark.paints[0].color.toARGB32(), 0xFFC4A0FF);
      expect(identical(dark.paints[0], spy.paints[0]), isTrue);
    });
  });

  group('the chips (G3)', () {
    test(
        'TG-L6 the label: the distinct visible numbers in lead order, else '
        'the group\'s label cut to 24, on one line at its intrinsic width '
        '(M-TG-14)', () {
      final camera = ValueNotifier(cameraAt(0.06));
      final groups = ValueNotifier<Map<String, TableGroup>>({
        'G7': tg({'12', '3', '7', '9'})
      });
      final painter =
          groupPainter(TableGroupLayer.chips, groupedPlan(), camera, groups);
      frame(painter);
      expect(painter.debugChipTexts, ['3+7+12'],
          reason: 'lead order, the hidden 9 left out');

      final dup = groupPainter(
          TableGroupLayer.chips, groupedPlan(duplicate: true), camera, groups);
      frame(dup);
      expect(dup.debugChipTexts, ['3+7+12'], reason: 'never 3+3+7+12');

      groups.value = {
        'G7':
            tg({'12', '3', '7'}, label: '  Window table for the Smiths party ')
      };
      final spy = frame(painter);
      expect(painter.debugChipTexts, ['Window table for the Smi']);
      expect(painter.debugChipTexts.single.length, 24);
      final p = spy.paragraphs.single;
      expect(p.computeLineMetrics(), hasLength(1), reason: 'one line');
      expect(p.didExceedMaxLines, isFalse);
      expect(p.width, greaterThanOrEqualTo(p.maxIntrinsicWidth),
          reason: 'laid out at its intrinsic width, nothing cut');
      expect(groupLabel(tg({'5'}, label: ' '), const []), '');
    });

    test(
        'TG-L7 the chip is centred on the frame\'s top-most point, filled '
        'gripMove; it is skipped when the frame is narrower on screen than '
        'it (G3)', () {
      final doc = groupedPlan();
      final camera = ValueNotifier(cameraAt(0.06));
      final painter = groupPainter(
          TableGroupLayer.chips,
          doc,
          camera,
          ValueNotifier({
            'G7': tg({'12', '3', '7'})
          }));
      final corners = [
        for (final n in ['12', '3', '7']) ...cornersOf(doc, n)
      ];
      final xs = [for (final c in corners) c.$1];
      final ys = [for (final c in corners) c.$2];
      final ax = (xs.reduce(math.min) + xs.reduce(math.max)) / 2;
      final ay = ys.reduce(math.max) + kGroupFrameMarginMm;
      for (final scale in [0.06, 0.11]) {
        camera.value = cameraAt(scale);
        final spy = frame(painter);
        final p = spy.paragraphs.single;
        final (sx, sy) = screenOf(camera.value, ax, ay);
        expect(spy.translations.single.dx, closeTo(sx - p.width / 2, 1e-6));
        expect(spy.translations.single.dy, closeTo(sy - p.height / 2, 1e-6));
        expect(
            spy.rrects.single,
            ui.RRect.fromLTRBR(
                -kGroupChipPaddingX,
                -kGroupChipPaddingY,
                p.width + kGroupChipPaddingX,
                p.height + kGroupChipPaddingY,
                const ui.Radius.circular(kGroupChipRadius)));
        expect(spy.paints.single.color.toARGB32(), 0xFF7A3FD1);
        expect(spy.paints.single.style, ui.PaintingStyle.fill);
      }
      // The frame is (maxX - minX + 300) mm wide: at 0.004 px/mm about
      // 37 px, narrower than the chip "3+7+12".
      final width = xs.reduce(math.max) - xs.reduce(math.min) + 300;
      camera.value = cameraAt(0.004);
      final p = frame(groupPainter(
          TableGroupLayer.chips,
          doc,
          ValueNotifier(cameraAt(0.06)),
          ValueNotifier({
            'G7': tg({'12', '3', '7'})
          }))).paragraphs.single;
      expect(width * 0.004, lessThan(p.width + 2 * kGroupChipPaddingX),
          reason: 'premise');
      expect(frame(painter).paragraphs, isEmpty);
    });

    testWidgets(
        'TG-L8 the chip\'s ink follows foregroundFor on gripMove: white on '
        'the light set\'s purple, dark on the dark set\'s lilac (G3)',
        (tester) async {
      final doc = groupedPlan();
      final camera = ValueNotifier(cameraAt(0.08));
      final paper = ValueNotifier<int>(0xFFFFFFFF);
      final painter = groupPainter(
          TableGroupLayer.chips,
          doc,
          camera,
          ValueNotifier({
            'G7': tg({'12', '3', '7'})
          }),
          paper: paper);
      Future<(int, int)> glyphs() async {
        final spy = frame(painter);
        final t = spy.translations.single;
        final p = spy.paragraphs.single;
        final bytes = (await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder)
            ..drawColor(Color(paper.value), ui.BlendMode.src);
          painter.paint(canvas, kSize);
          final image = await recorder
              .endRecording()
              .toImage(kSize.width.toInt(), kSize.height.toInt());
          final data = await image.toByteData();
          image.dispose();
          return data!;
        }))!;
        var darkest = 0, brightest = 0, dMax = 256, bMin = -1;
        for (var y = t.dy.ceil(); y < (t.dy + p.height).floor(); y++) {
          for (var x = t.dx.ceil(); x < (t.dx + p.width).floor(); x++) {
            final i = (y * kSize.width.toInt() + x) * 4;
            final ch = [
              bytes.getUint8(i),
              bytes.getUint8(i + 1),
              bytes.getUint8(i + 2)
            ];
            final rgb = (ch[0] << 16) | (ch[1] << 8) | ch[2];
            final hi = ch.reduce(math.max), lo = ch.reduce(math.min);
            if (hi < dMax) (dMax, darkest) = (hi, rgb);
            if (lo > bMin) (bMin, brightest) = (lo, rgb);
          }
        }
        return (darkest, brightest);
      }

      expect(foregroundFor(0x7A3FD1), 0xFFFFFF, reason: 'premise');
      expect(foregroundFor(0xC4A0FF), 0x000000, reason: 'premise');
      final (_, onLight) = await glyphs();
      expect(onLight, 0xFFFFFF, reason: 'white glyphs on 0x7A3FD1');
      paper.value = 0xFF1F3A5F;
      final (onDark, _) = await glyphs();
      expect(onDark, 0x202020, reason: 'dark glyphs on 0xC4A0FF');
    });
  });

  test(
      'TG-L9 ten steady frames, the camera moving: the frames, the chips and '
      'the status painter build nothing and pass the same objects; a groups '
      'change rebuilds each group painter once (M-TG-15)', () {
    final doc = groupedPlan(duplicate: true);
    final camera = ValueNotifier(cameraAt(0.06));
    final groups = ValueNotifier<Map<String, TableGroup>>({
      'G7': tg({'12', '3', '7'}),
      'G2': tg({'20', '9', '5'}),
    });
    final picker = TablePicker(doc);
    final frames = groupPainter(TableGroupLayer.frames, doc, camera, groups,
        picker: picker);
    final chips = groupPainter(TableGroupLayer.chips, doc, camera, groups,
        picker: picker);
    final status = statusPainter(
        doc,
        camera,
        ValueNotifier({'20': TableStatus(color: eating, caption: 'Eat')}),
        groups,
        ValueNotifier({'G7': TableStatus(color: bill, caption: 'Bill')}));
    List<Object> seenOf(CustomPainter p) =>
        p is TableStatusPainter ? statusFrame(p).seen : frame(p).seen;
    for (final p in <CustomPainter>[frames, chips, status]) {
      for (var i = 0; i < 3; i++) {
        seenOf(p);
      }
    }
    final made = [
      frames.debugAllocations,
      chips.debugAllocations,
      status.debugAllocations
    ];
    final rebuilt = [
      frames.debugRebuilds,
      chips.debugRebuilds,
      status.debugRebuilds
    ];
    final reference = [
      for (final p in [frames, chips, status]) seenOf(p)
    ];
    expect(reference[0].whereType<ui.Path>(), hasLength(1),
        reason: 'G7 framed; G2 has one visible member (20)');
    expect(reference[1].whereType<ui.Paragraph>(), hasLength(1));
    expect(reference[2].whereType<ui.Paragraph>(), hasLength(2));
    for (var i = 0; i < 10; i++) {
      camera.value = cameraAt(0.05 + 0.002 * i);
      for (final p in <CustomPainter>[frames, chips, status]) {
        seenOf(p);
      }
    }
    camera.value = cameraAt(0.06);
    final again = [
      for (final p in [frames, chips, status]) seenOf(p)
    ];
    for (var k = 0; k < 3; k++) {
      expect(again[k].length, reference[k].length);
      for (var i = 0; i < again[k].length; i++) {
        expect(identical(again[k][i], reference[k][i]), isTrue,
            reason: 'painter $k item $i');
      }
    }
    expect([
      frames.debugAllocations,
      chips.debugAllocations,
      status.debugAllocations
    ], made, reason: 'nothing new per frame');
    expect([
      frames.debugRebuilds,
      chips.debugRebuilds,
      status.debugRebuilds
    ], rebuilt, reason: 'no rebuild per frame');

    final rebuilds = [frames.debugRebuilds, chips.debugRebuilds];
    groups.value = {
      'G7': tg({'12', '3', '7', '20'}),
    };
    for (var i = 0; i < 3; i++) {
      frame(frames);
      frame(chips);
    }
    expect([frames.debugRebuilds, chips.debugRebuilds],
        [rebuilds[0] + 1, rebuilds[1] + 1]);
    expect(chips.debugChipTexts, ['3+7+12+20']);
  });

  test('TG-L10 convexHull and offsetHull: a point, a segment, a polygon', () {
    const tol = Tolerance(linear: 1e-6, angular: 1e-9);
    expect(convexHull([5, 5, 5, 5], tol), [5, 5]);
    expect(convexHull([3, 1, 0, 0], tol), [0, 0, 3, 1]);
    // A square with an interior and a collinear point, counter-clockwise.
    expect(convexHull([0, 0, 2, 2, 2, 0, 1, 1, 0, 2, 1, 0], tol),
        [0, 0, 2, 0, 2, 2, 0, 2]);
    final circle = offsetHull([10, 10], 3);
    expect(circle.contains(const ui.Offset(12.9, 10)), isTrue);
    expect(circle.contains(const ui.Offset(13.1, 10)), isFalse);
    final stadium = offsetHull([0, 0, 10, 0], 2);
    expect(stadium.contains(const ui.Offset(5, 1.9)), isTrue);
    expect(stadium.contains(const ui.Offset(5, -1.9)), isTrue);
    expect(stadium.contains(const ui.Offset(5, 2.1)), isFalse);
    expect(stadium.contains(const ui.Offset(11.9, 0)), isTrue);
    expect(stadium.contains(const ui.Offset(12.1, 0)), isFalse);
    final square = offsetHull([0, 0, 2, 0, 2, 2, 0, 2], 1);
    // Round at a corner: (2.6, 2.6) is 0.85 from (2, 2); (2.8, 2.8) 1.13.
    expect(square.contains(const ui.Offset(2.6, 2.6)), isTrue);
    expect(square.contains(const ui.Offset(2.8, 2.8)), isFalse);
    expect(square.contains(const ui.Offset(1, 2.9)), isTrue);
    expect(square.contains(const ui.Offset(1, 3.1)), isFalse);
  });

  test('premise: the lead order of {12, 3, 7} is 3, 7, 12', () {
    expect(
        inLeadOrder([
          for (final (h, n) in [(1, '12'), (2, '3'), (3, '7')])
            GroupTable(
                handle: Handle(h), number: n, visible: true, locked: false)
        ]).map((t) => t.number),
        ['3', '7', '12']);
  });
}

/// The distance from [p] to the convex hull of [points], [p] outside it:
/// the least distance to a segment between two of them (a hull edge is one
/// such segment, and any other lies inside the hull).
double _hullDistance(List<(double, double)> points, (double, double) p) {
  var best = double.infinity;
  for (final a in points) {
    for (final b in points) {
      if (identical(a, b)) continue;
      final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
      final len2 = dx * dx + dy * dy;
      if (len2 == 0) continue;
      final t = (((p.$1 - a.$1) * dx + (p.$2 - a.$2) * dy) / len2).clamp(0, 1);
      final cx = a.$1 + t * dx - p.$1, cy = a.$2 + t * dy - p.$2;
      best = math.min(best, math.sqrt(cx * cx + cy * cy));
    }
  }
  return best;
}
