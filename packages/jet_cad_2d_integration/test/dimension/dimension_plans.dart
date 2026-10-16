// Plans for the dimension's integration tests (3a Tasks 21, 22), built in
// code through the plan's build seam (spec C1.9) over the architecture
// kit's public types, and read back through the plan's public API (C6).
// Copied, not imported (the plan's Ruling 11-22), from
// jet_cad_floor_plan/test/support/room_fixture.dart (:118-194),
// dimension_fixture.dart (:366-403) and room_diagnostics_test.dart's
// `staleFile`. The rig's helpers and the integration package's own copies
// of the room and wall fixtures (the plan model, `kids`, `canon`,
// `deleteObject`, ...) are imported, not copied again (R-P14): the sample
// plan's walls, openings, separator, column and seeds, `addRoom` and
// `clickAt` (a primary tap at a world point) are room_plans.dart's (Task
// 22).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, ViewportTransform;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/room_plans.dart';
import '../support/wall_fixture.dart';

export '../support/canvas_rig.dart' show byKey;
export '../support/editor_rig.dart'
    show activeTool, kitCatalog, press, pumpEditor, status;
export '../support/room_plans.dart'
    show
        O,
        Placement,
        S,
        W,
        addRoom,
        clickAt,
        corpusGroups,
        deleteObject,
        groupFor,
        origin,
        sampleColumn,
        sampleOpenings,
        sampleSeeds,
        sampleSeparator,
        sampleWalls,
        select;
export '../support/wall_fixture.dart'
    show addWallLocal, canon, driftOf, enc, kids, kindOf, payloadOf;

/// C2: an L, A east then B north, 200 each (dimension_fixture.dart:76).
const List<W> c2Walls = [W(0, 0, 4000, 0, 200), W(4000, 0, 4000, 3000, 200)];

/// A page at 1:50 in millimetres (dimension_fixture.dart:366-367).
PageComponent get mmPage =>
    PageComponent().copyWith(displayUnit: DisplayUnit.millimeters);

/// [page] on [doc]'s root, one command.
void setPage(DraftDocument doc, PageComponent page) => doc.commands
    .execute(SetComponentCommand<PageComponent>(doc.rootHandle, page));

/// A controller over the architecture kit whose new plan [build] fills
/// (spec C1.9: the plan's own document, system and DASHED record; the
/// history cleared after). A throw inside [build] fails the test (the
/// controller would only report it as a diagnostic). Disposed at
/// tear-down.
PlanController planOf(void Function(DraftDocument doc) build) {
  Object? failure;
  StackTrace? trace;
  final c = PlanController(
      kits: [architectureKit],
      build: (doc, _) {
        try {
          build(doc);
        } catch (e, s) {
          failure = e;
          trace = s;
          rethrow;
        }
      });
  addTearDown(c.dispose);
  if (failure != null) fail('the build threw: $failure\n$trace');
  return c;
}

/// What [buildPlanIn] added, in the order given.
typedef Built = ({
  List<Handle> walls,
  List<Handle> seps,
  List<Handle> openings
});

/// room_fixture.dart:118-163's `buildPlan` on [doc], the plan's own
/// document inside a `PlanBuild`: [walls], then [seps], then [wallsAfter]
/// (walls whose handles come after the separators'), then [openings]
/// (hosted by the walls they index in `[...walls, ...wallsAfter]`), each
/// object one command, at [place]. Without `installParametric` and
/// `ensureDashedLinetype`: the plan installed its system and prepared the
/// DASHED record (spec C1.3, C1.9).
Built buildPlanIn(DraftDocument doc, List<W> walls,
    {List<S> seps = const [],
    List<W> wallsAfter = const [],
    List<O> openings = const [],
    Placement place = origin}) {
  final wh = <Handle>[], sh = <Handle>[], oh = <Handle>[];
  var k = 0;
  void addWalls(List<W> ws) {
    for (final w in ws) {
      final h = doc.handleSeed.next();
      final g = place.groups ? groupFor(place, k++) : Transform2.identity();
      final inv = g.invert();
      final s = inv.transformPoint(place.at(w.sx, w.sy));
      final e = inv.transformPoint(place.at(w.ex, w.ey));
      doc.commands.execute(
          addWallLocal(doc, h, WallParams(s.x, s.y, e.x, e.y, w.t, w.j), g));
      wh.add(h);
    }
  }

  addWalls(walls);
  for (final (sx, sy, ex, ey) in seps) {
    sh.add(addSeparator(doc, place.at(sx, sy), place.at(ex, ey),
        at: place.groups ? groupFor(place, k++) : null));
  }
  addWalls(wallsAfter);
  for (final (i, position, width, kind, swing) in openings) {
    oh.add(addOpening(
        doc, OpeningParams(wh[i], position, width, kind, swing: swing)));
  }
  return (walls: wh, seps: sh, openings: oh);
}

/// A separator from world [s] to world [e] in its own root group [at]
/// (room_fixture.dart:165-178).
Handle addSeparator(DraftDocument doc, Vector2 s, Vector2 e, {Transform2? at}) {
  final h = doc.handleSeed.next();
  final g = at ?? Transform2.identity();
  final inv = g.invert();
  final ls = inv.transformPoint(s), le = inv.transformPoint(e);
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h, parent: doc.rootHandle, transform: g, children: const [])),
    SetComponentCommand<SeparatorParams>(
        h, SeparatorParams(ls.x, ls.y, le.x, le.y)),
  ], label: 'Add separator'));
  return h;
}

/// Opening [o] in its own root group at the identity, one command
/// (room_fixture.dart:180-194).
Handle addOpening(DraftDocument doc, OpeningParams o) {
  final h = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h,
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        children: const [])),
    SetComponentCommand<OpeningParams>(h, o),
  ], label: 'Add opening'));
  return h;
}

/// A dimension from [a] to [b] in its own root group at [at]: the
/// Dimension tool's commit (dimension_fixture.dart:373-386).
Handle addDimension(DraftDocument doc, DimEnd a, DimEnd b,
    {DimKind kind = DimKind.aligned, double offset = 500, Transform2? at}) {
  final h = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h,
        parent: doc.rootHandle,
        transform: at ?? Transform2.identity(),
        children: const [])),
    SetComponentCommand<DimensionParams>(
        h, DimensionParams(a, b, kind, offset)),
  ], label: 'Add dimension'));
  return h;
}

/// A fixed end at world [w] in a group at [at] (dimension_fixture.dart:
/// 390-393).
FixedEnd fixedAt(Vector2 w, [Transform2? at]) {
  final l = (at ?? Transform2.identity()).invert().transformPoint(w);
  return FixedEnd(l.x, l.y);
}

/// Dimension [h]'s TEXT child: its one TEXT (dimension_fixture.dart:
/// 395-399).
Handle dimTextHandle(DraftDocument doc, Handle h) =>
    kids(doc, h).singleWhere((k) => kindOf(doc, k) == EntityKind.text);

/// Dimension [h]'s value string: its one TEXT child's
/// (dimension_fixture.dart:401-403).
String dimText(DraftDocument doc, Handle h) =>
    doc.entities.textAt(doc.entities.slotOf(dimTextHandle(doc, h))!);

/// Dimension [h]'s LINE children, world points, ascending by handle: the
/// dimension line, the extension lines at `a` and `b`, the slashes at `a`
/// and `b` (dimension_fixture.dart:405-422).
List<(Vector2, Vector2)> dimLines(DraftDocument doc, Handle h) {
  final m = doc.tree.accumulatedTransform(h);
  return [
    for (final k in kids(doc, h))
      if (kindOf(doc, k) == EntityKind.line)
        () {
          final c = payloadOf(doc, k).coords;
          return (
            m.transformPoint(Vector2(c[0], c[1])),
            m.transformPoint(Vector2(c[2], c[3])),
          );
        }(),
  ];
}

/// A saved plan with what [add] adds to a copy of [saved] that has no
/// parametric system (room_diagnostics_test.dart's `staleFile`): the
/// commands land as given and nothing is generated, as a file written by
/// another program.
String stalePlan(String saved, void Function(DraftDocument bare) add) {
  final bare = decodePlan(saved, register: (r) {
    PageComponent.register(r);
    registerKitComponents(r);
    kitCatalog().registerComponents(r);
  }, diagnostics: <Diagnostic>[]);
  add(bare);
  return encodePlan(bare, validateKitSet([architectureKit]));
}

/// [c]'s editor in a 1440 x 900 window, one frame: the rig's [pumpEditor].
Future<void> pumpPlan(WidgetTester tester, PlanController c,
        {Locale locale = const Locale('en')}) =>
    pumpEditor(tester, c, locale: locale);

/// Every live dimension of [doc], ascending (today's `liveObjectsOf`,
/// asked of the kit's types).
List<Handle> dims(DraftDocument doc) => [
      for (final h in doc.components.withComponent<DimensionParams>())
        if (kitCatalog().typeIdOf(doc, h) == ArchitectureTypes.dimension) h,
    ];

/// The active tool's notice in words, or null (spec C1.2).
String? noticeText(PlanController c) {
  final notice = c.toolNotice.value;
  return notice == null ? null : c.textOf(notice);
}

/// [c]'s camera at [pxPerMm], centred on world [at] (y down, as today's
/// `centreOn`, dimension_tool_test.dart:162-171).
Future<void> centreOn(
    WidgetTester tester, PlanController c, Vector2 at, double pxPerMm) async {
  final size = tester.getSize(find.byType(InteractionLayer));
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - pxPerMm * at.x, size.height / 2 - pxPerMm * at.y)
          .multiply(Transform2.scale(pxPerMm, pxPerMm)));
  await tester.pump();
}

/// Plan vector ([x], [y]) turned by [place]'s rotation
/// (dimension_tool_test.dart:119-124).
Vector2 turnedBy(Placement place, double x, double y) {
  final rad = place.deg * math.pi / 180;
  return Vector2(x * math.cos(rad) - y * math.sin(rad),
      x * math.sin(rad) + y * math.cos(rad));
}
