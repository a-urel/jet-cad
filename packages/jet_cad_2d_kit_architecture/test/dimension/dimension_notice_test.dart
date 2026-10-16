// 3a Task 22, spec C1.2, C1.5, C3.6: the Dimension tool's notice is a word
// id and its argument (text:architecture.dimension-value, {value}), the
// value exactly the TEXT the commit draws, put into words by the plan; and
// the plan tool's declaration, whose tool reads the plan's live types (a
// frozen wall attaches nothing). Fixture: C2's L at the corpus far origin,
// every wall in its own turned group, on a 1:50 page in metres, grid snap
// off.
import 'dart:ui' show Locale, Offset;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/painting.dart' show Canvas, Paint, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension.dart';
import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension_plan.dart';
import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension_tool.dart';
import 'package:jet_cad_2d_kit_architecture/src/ids.dart';
import 'package:jet_cad_2d_kit_architecture/src/words/words.dart'
    show architectureNames;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/dimension_fixture.dart';

const l = WallSide.left;

/// A ToolContext over [doc] at 0.3 px/mm (aperture 33.3 mm), F3 on, the
/// document's page (TL's `dimRig`, dimension_tool_test.dart:50-80).
ToolContext contextOf(DraftDocument doc) {
  final index = SpatialIndex(doc);
  final camera = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2.scale(0.3, 0.3)));
  final selection = SelectionController(doc);
  final snap = SnapSettings();
  final page = PageNotifier(doc);
  addTearDown(() {
    page.dispose();
    snap.dispose();
    selection.dispose();
    camera.dispose();
    index.dispose();
  });
  return ToolContext(
      document: doc,
      index: index,
      camera: camera,
      selection: selection,
      page: page,
      snap: snap);
}

ToolPointerEvent eventAt(Vector2 world, {int buttons = 0}) => ToolPointerEvent(
    screen: Offset.zero,
    world: world,
    pointer: 1,
    buttons: buttons,
    shift: false,
    control: false,
    meta: false,
    alt: false,
    pickRadiusWorld: 1);

void hover(Tool tool, ToolContext ctx, Vector2 w) =>
    tool.onPointerMove(eventAt(w), ctx);

void click(Tool tool, ToolContext ctx, Vector2 w) {
  hover(tool, ctx, w);
  tool.onPointerDown(eventAt(w, buttons: kPrimaryButton), ctx);
}

/// C2's L at the corpus far origin in own groups; a 1:50 page in metres,
/// no grid snap.
Plan lPlan() {
  final plan = buildPlan(c2Walls, place: corpusGroups);
  attachPage(plan.doc, PageComponent(snapToGrid: false));
  return plan;
}

List<Handle> dimsOf(DraftDocument doc) =>
    doc.components.withComponent<DimensionParams>().toList();

/// A canvas that counts the attach rings `paintOverlay` draws (circles of
/// [kAttachRingPixels]) and ignores everything else.
class _RingCount implements Canvas {
  int rings = 0;

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    if (radius == kAttachRingPixels) rings++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The attach rings [tool] paints now over [ctx]'s camera.
int ringsOf(PlacementTool tool, ToolContext ctx) {
  final spy = _RingCount();
  tool.paintOverlay(
      spy, ctx.camera.value, const Size(1440, 900), PaperPalette.light);
  return spy.rings;
}

/// A Dimension tool over [plan]'s document and services whose frozen set
/// grows in place, as the plan's does (a freeze emits no document change):
/// DT-freeze's rig.
(DimensionTool, ToolContext, Set<Handle>) freezeRigOf(Plan plan) {
  final frozen = <Handle>{};
  final s = FakePlanServices(
      document: plan.doc, catalog: testCatalog(), frozen: frozen);
  addTearDown(s.dispose);
  final tool = dimensionPlanTool.create(s) as DimensionTool;
  addTearDown(tool.dispose);
  return (tool, contextOf(plan.doc), frozen);
}

void main() {
  test(
      'DT-notice the notice is text:architecture.dimension-value with the '
      'value the commit draws; every language words it alike; null after '
      'the commit (M-DT1, M-DT2)', () {
    final plan = lPlan();
    final doc = plan.doc;
    final tool = DimensionTool(live: liveOf(doc));
    addTearDown(tool.dispose);
    final ctx = contextOf(doc);
    expect(tool, isA<ToolNotice>());
    // Two free points 4,690 mm apart along the placement's x, clear of
    // both walls (B's faces at x 3,900-4,100 in the plan), and a third
    // 900.25 above them: aligned, 4,690 mm, 4.69 in metres.
    click(tool, ctx, plan.at(1000.25, 1500.5));
    click(tool, ctx, plan.at(5690.25, 1500.5));
    hover(tool, ctx, plan.at(3000.5, 2400.75));
    expect(tool.notice.value,
        const KitText('text:architecture.dimension-value', {'value': '4.69'}));
    final notice = tool.notice.value!;
    for (final language in const ['en', 'de', 'tr']) {
      expect(
          KitNamesWords(architectureNames, () => Locale(language))
              .text(notice.id, notice.args),
          '4.69',
          reason: language);
    }
    click(tool, ctx, plan.at(3000.5, 2400.75));
    expect(dimText(doc, dimsOf(doc).single), '4.69', reason: 'the commit');
    expect(tool.notice.value, isNull, reason: 'after the commit');
  });

  test(
      'DT-notice-separator the value takes the page\'s decimal separator, '
      'never the UI language\'s: a comma page reads 4,69 under a point UI, '
      'a point page 4.69 under a comma UI (spec C3.6, Q0; M-DT7)', () {
    for (final (page, ui, want) in const [
      (DecimalSeparator.comma, '.', '4,69'),
      (DecimalSeparator.point, ',', '4.69'),
    ]) {
      final why = 'page ${page.char}, UI $ui';
      final plan = buildPlan(c2Walls, place: corpusGroups);
      final doc = plan.doc;
      attachPage(doc, PageComponent(snapToGrid: false, decimalSeparator: page));
      final s = FakePlanServices(
          document: doc,
          catalog: testCatalog(),
          names: architectureNames,
          locale: const Locale('de'),
          decimalSeparator: ui);
      addTearDown(s.dispose);
      expect(s.words.decimalSeparator, ui, reason: '$why: premise');
      final tool = dimensionPlanTool.create(s) as DimensionTool;
      addTearDown(tool.dispose);
      final ctx = contextOf(doc);
      click(tool, ctx, plan.at(1000.25, 1500.5));
      click(tool, ctx, plan.at(5690.25, 1500.5));
      hover(tool, ctx, plan.at(3000.5, 2400.75));
      final notice = tool.notice.value!;
      expect(notice.args, {'value': want}, reason: why);
      expect(s.words.text(notice.id, notice.args), want, reason: why);
      click(tool, ctx, plan.at(3000.5, 2400.75));
      expect(dimText(doc, dimsOf(doc).single), want,
          reason: '$why: the commit draws the same');
    }
  });

  test(
      'DT-plan-tool letter I, the commit\'s needs, no settings; the tool it '
      'makes reads the services\' live types: a frozen wall fixes the end '
      '(M-DT3, M-DT4)', () {
    expect(dimensionPlanTool.id, ArchitectureTools.dimension);
    expect(dimensionPlanTool.letter, 'I');
    expect(dimensionPlanTool.needs,
        {Capability.structure, Capability.components, Capability.geometry});
    expect(dimensionPlanTool.settings, isNull);

    final plan = lPlan();
    final doc = plan.doc;
    final [a, _] = plan.walls;
    // The first click on A's free start's left corner (0, 100), A/0/left
    // alone (GE3's premise); the others free.
    DimEnd firstEnd(Set<Handle> frozen) {
      final s = FakePlanServices(
          document: doc, catalog: testCatalog(), frozen: frozen);
      addTearDown(s.dispose);
      final tool = dimensionPlanTool.create(s);
      addTearDown(tool.dispose);
      final ctx = contextOf(doc);
      final before = dimsOf(doc).toSet();
      click(tool, ctx, plan.at(0, 100));
      click(tool, ctx, plan.at(2500.75, 1800.25));
      click(tool, ctx, plan.at(1200.5, 2600.25));
      final d = dimsOf(doc).singleWhere((h) => !before.contains(h));
      return doc.components.get<DimensionParams>(d)!.a;
    }

    expect(firstEnd(const {}), AttachedEnd(a, 0, l), reason: 'control');
    expect(firstEnd({a}), isA<FixedEnd>(), reason: 'A frozen');
  });

  test(
      'DT-freeze-wall the hover memo re-checks the plan\'s live '
      'types: a wall frozen after a hover (no document change) rings '
      'nothing at the very next hover at the memoised point (FREEZE '
      'RULE; M-DT8)', () {
    // The wall itself, read first by a hover at the memoised point. A.1
    // and B.0's right corners meet at the L's outer corner (4,100, −100);
    // a hover 5 mm off snaps onto it (the aperture is 33.3 mm).
    final plan = lPlan();
    final [a, _] = plan.walls;
    final (tool, ctx, frozen) = freezeRigOf(plan);
    final corner = plan.at(4100, -100), near = plan.at(4103, -104);
    hover(tool, ctx, near);
    expect((tool.hoverPoint - corner).length, lessThan(dimAttach.linear),
        reason: 'premise: onto the corner');
    expect(ringsOf(tool, ctx), 1, reason: 'premise: the corner attaches');
    hover(tool, ctx, near);
    expect(ringsOf(tool, ctx), 1, reason: 'control: no freeze, a ring');
    final depth = plan.doc.commands.undoDepth;
    frozen.add(a);
    expect(plan.doc.commands.undoDepth, depth, reason: 'premise');
    hover(tool, ctx, near);
    expect((tool.hoverPoint - corner).length, lessThan(dimAttach.linear),
        reason: 'premise: the index still snaps onto the corner');
    // Fresh: A is no wall; B alone has a free start whose right corner
    // is (4,100, 0), 100 mm off.
    expect(ringsOf(tool, ctx), 0, reason: 'A frozen: the hover');
  });

  test(
      'DT-freeze-neighbour the hover memo re-checks the plan\'s live '
      'types: a neighbour frozen after a hover rings nothing through '
      'the memoised six points of the wall beside it (FREEZE RULE; '
      'M-DT8)', () {
    // A neighbour, read first through B's memoised six points: a hover
    // at B's inner corner (3,900, 100) lays B out among A; A freezes; a
    // hover at the outer corner, a point the memo never searched, finds B
    // through its stored children and must not read B's joined points.
    final plan = lPlan();
    final [a, _] = plan.walls;
    final (tool, ctx, frozen) = freezeRigOf(plan);
    hover(tool, ctx, plan.at(3903, 104));
    expect(ringsOf(tool, ctx), 1, reason: 'premise: B laid out among A');
    frozen.add(a);
    hover(tool, ctx, plan.at(4103, -104));
    expect((tool.hoverPoint - plan.at(4100, -100)).length,
        lessThan(dimAttach.linear),
        reason: 'premise: onto the outer corner');
    expect(ringsOf(tool, ctx), 0, reason: 'A frozen: B\'s points afresh');
  });

  test(
      'DT-freeze-click the hover memo re-checks the plan\'s live '
      'types: a wall frozen after a hover rings nothing at a click '
      'with no move before it, the click the first reader (FREEZE '
      'RULE; M-DT8)', () {
    // The click as first reader: a hover memoises the corner; A
    // freezes; a press there with no move before it places the point,
    // whose ring is read from the memo.
    final plan = lPlan();
    final [a, _] = plan.walls;
    final (tool, ctx, frozen) = freezeRigOf(plan);
    final near = plan.at(4103, -104);
    hover(tool, ctx, near);
    expect(ringsOf(tool, ctx), 1, reason: 'premise: the hover rings');
    frozen.add(a);
    tool.onPointerDown(eventAt(near, buttons: kPrimaryButton), ctx);
    expect(tool.points, hasLength(1), reason: 'premise: placed');
    expect(ringsOf(tool, ctx), 0, reason: 'A frozen: the click');
  });

  test(
      'DT-freeze-opening the hover memo re-checks the plan\'s live '
      'types: an opening frozen after a hover rings nothing at the '
      'jamb only its host gave (FREEZE RULE; M-DT8)', () {
    // An opening: spike C5's T with a flush door on the stem; the
    // stem's jamb corner S/0/left (2,450, 100) attaches only through the
    // door's host (the plan's Ruling 11-7). The door freezes.
    final plan = flushT(corpusGroups);
    final door = plan.openings.single;
    final (tool, ctx, frozen) = freezeRigOf(plan);
    final near = plan.at(2453, 104);
    hover(tool, ctx, near);
    expect((tool.hoverPoint - plan.at(2450, 100)).length,
        lessThan(dimAttach.linear),
        reason: 'premise: onto the jamb');
    expect(ringsOf(tool, ctx), 1, reason: 'premise: the jamb attaches');
    frozen.add(door);
    hover(tool, ctx, near);
    expect(ringsOf(tool, ctx), 0, reason: 'the door frozen: no host');
  });
}
