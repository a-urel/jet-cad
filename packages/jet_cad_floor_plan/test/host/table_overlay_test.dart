// Host embedding API spec, Slice 1, G-5, G-6, G-7 and H-8: the host's
// widgets on the tables (`FloorPlanView.tableOverlayBuilder`), their
// placement (`FloorPlanOverlayLayout`), the detail levels, and the layer's
// cost (`RenderFloorPlanOverlays`), over the shared non-degenerate fixture
// (embedding_fixture): an off-base box, tables turned, mirrored and scaled
// 40 m off the origin, a hidden and a locked layer, a shared number, and a
// panned camera at 0.37 px/mm. Expected places are computed here by the
// forward transform of the fixture's box, never read back from the code.
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/host/table_overlay.dart';

import 'embedding_fixture.dart';

/// A controller over the fixture, in the selection mode unless [design].
FloorPlanController controller({bool design = false}) {
  final c = FloorPlanController(json: embeddingPlanJson());
  addTearDown(c.dispose);
  if (!design) c.setMode(FloorPlanMode.selection);
  return c;
}

/// The numbers that get an overlay: numbered, with geometry (not `5` on the
/// hidden layer, not the unnumbered table, not `9` with no finite corner).
const List<String> kOverlaid = ['1', '2', '3', '4', 'L', '7', '7'];

/// The host's badge: a fixed natural size, its table's overlay kept.
class Badge extends StatefulWidget {
  const Badge(this.overlay, {super.key, this.onTap});

  final FloorPlanTableOverlay overlay;
  final VoidCallback? onTap;

  static const Size size = Size(40, 20);

  /// How many badge states were created.
  static int created = 0;

  @override
  State<Badge> createState() => _BadgeState();
}

class _BadgeState extends State<Badge> {
  @override
  void initState() {
    super.initState();
    Badge.created++;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: widget.onTap,
        child: SizedBox.fromSize(
            size: Badge.size,
            child: const ColoredBox(color: Color(0xFF3060C0))),
      );
}

/// The builder calls, by number.
final class Calls {
  final Map<String, int> byNumber = {};
  int get total => byNumber.values.fold(0, (a, b) => a + b);

  FloorPlanTableOverlayBuilder builder({VoidCallback? onTap}) =>
      (context, table) {
        final n = table.detail.table.number!;
        byNumber[n] = (byNumber[n] ?? 0) + 1;
        return Badge(table, onTap: onTap);
      };
}

/// The host: a [FloorPlanView] whose overlay builder and layout it reads
/// from [builder] and [layout] at each build.
Widget hostOf(FloorPlanController c,
        {required ValueNotifier<FloorPlanTableOverlayBuilder?> builder,
        required ValueNotifier<FloorPlanOverlayLayout> layout,
        Set<FloorPlanMode>? modes,
        void Function(String)? onTableTap}) =>
    MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: Listenable.merge([builder, layout]),
          builder: (context, _) => modes == null
              ? FloorPlanView(
                  controller: c,
                  onTableTap: onTableTap,
                  tableOverlayBuilder: builder.value,
                  tableOverlayLayout: layout.value)
              : FloorPlanView(
                  controller: c,
                  onTableTap: onTableTap,
                  tableOverlayBuilder: builder.value,
                  tableOverlayLayout: layout.value,
                  tableOverlayModes: modes),
        ),
      ),
    );

/// Mounts the host at 1440 x 900, lets the first fit land, then puts the
/// fixture's camera (or [camera]) in place.
Future<void> mount(WidgetTester tester, FloorPlanController c,
    {FloorPlanTableOverlayBuilder? builder,
    FloorPlanOverlayLayout layout = const FloorPlanOverlayLayout(),
    Set<FloorPlanMode>? modes,
    void Function(String)? onTableTap,
    ViewportTransform? camera,
    ValueNotifier<FloorPlanTableOverlayBuilder?>? builders,
    ValueNotifier<FloorPlanOverlayLayout>? layouts}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final b = builders ?? ValueNotifier(builder);
  final l = layouts ?? ValueNotifier(layout);
  await tester.pumpWidget(
      hostOf(c, builder: b, layout: l, modes: modes, onTableTap: onTableTap));
  await tester.pump();
  await tester.pump();
  c.cameraController.value = camera ?? embeddingCamera();
  await tester.pump();
}

/// [t]'s box corners in the world, by the forward transform.
List<Offset> worldCorners(EmbeddingTable t) {
  final m = t.transform;
  Offset at(double x, double y) =>
      Offset(m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f);
  final b = embeddingBox;
  return [
    at(b.minX, b.minY),
    at(b.maxX, b.minY),
    at(b.maxX, b.maxY),
    at(b.minX, b.maxY)
  ];
}

/// [t]'s bounding box on the canvas of [camera], by the forward transform.
Rect canvasBox(EmbeddingTable t, ViewportTransform camera) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (final w in worldCorners(t)) {
    final p = canvasOf(camera, w.dx, w.dy);
    minX = math.min(minX, p.x);
    minY = math.min(minY, p.y);
    maxX = math.max(maxX, p.x);
    maxY = math.max(maxY, p.y);
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

EmbeddingTable tableNumbered(String n) =>
    embeddingTables.firstWhere((t) => t.number == n);

Finder badgeOf(String n) => find
    .byWidgetPredicate((w) => w is Badge && w.overlay.detail.table.number == n);

Offset canvasOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(InteractionLayer));

/// Within 1e-6 px of [want] (screen).
void expectRect(Rect got, Rect want, String reason) {
  expect(got.left, closeTo(want.left, 1e-6), reason: '$reason: left');
  expect(got.top, closeTo(want.top, 1e-6), reason: '$reason: top');
  expect(got.right, closeTo(want.right, 1e-6), reason: '$reason: right');
  expect(got.bottom, closeTo(want.bottom, 1e-6), reason: '$reason: bottom');
}

/// Where a natural [Badge] for [t] belongs on the screen under [cam]: its
/// [anchor] point on the anchor point of its canvas box (as `Align` places
/// a child), offset by the canvas's origin.
Rect badgeWanted(WidgetTester tester, EmbeddingTable t, ViewportTransform cam,
    {Alignment anchor = Alignment.center}) {
  final box = canvasBox(t, cam).shift(canvasOrigin(tester));
  final ax = (anchor.x + 1) / 2, ay = (anchor.y + 1) / 2;
  final w = Badge.size.width, h = Badge.size.height;
  return Rect.fromLTWH(box.left + ax * box.width - ax * w,
      box.top + ay * box.height - ay * h, w, h);
}

RenderFloorPlanOverlays layerOf(WidgetTester tester) =>
    tester.allRenderObjects.whereType<RenderFloorPlanOverlays>().single;

/// The layer's direct child holding [n]'s badge, and its parent data.
RenderBox slotOf(WidgetTester tester, String n) {
  RenderObject node = tester.renderObject(badgeOf(n));
  while (node.parent is! RenderFloorPlanOverlays) {
    node = node.parent!;
  }
  return node as RenderBox;
}

FloorPlanOverlayParentData dataOf(WidgetTester tester, String n) =>
    slotOf(tester, n).parentData! as FloorPlanOverlayParentData;

/// A camera at exactly [scale] px/mm (its determinant's root is exact)
/// that puts world (39,500, -25,500) at the canvas's top left: at 0.2,
/// tables 1 to 3 are on a 1440-pixel canvas and 4 is off it.
ViewportTransform cameraAt(double scale) => ViewportTransform(
    worldToScreenMatrix:
        Transform2(scale, 0, 0, -scale, -39500 * scale, -25500 * scale));

/// How many of [layer]'s children are shown (painted and hit).
int shownCount(RenderFloorPlanOverlays layer) {
  var shown = 0;
  var child = layer.firstChild;
  while (child != null) {
    final data = child.parentData! as FloorPlanOverlayParentData;
    if (data.shown) shown++;
    child = data.nextSibling;
  }
  return shown;
}

void main() {
  setUp(() => Badge.created = 0);

  testWidgets(
      'TO1 one overlay per numbered table with geometry, two for the shared '
      'number, centred on its table\'s screen box; after pan and zoom they '
      'follow, rebuilt by neither (G-5, G-6, M-H19)', (tester) async {
    final c = controller();
    final calls = Calls();
    await mount(tester, c, builder: calls.builder());
    expect(find.byType(Badge, skipOffstage: false), findsNWidgets(7));
    expect(calls.byNumber, {'1': 1, '2': 1, '3': 1, '4': 1, 'L': 1, '7': 2});
    expect(badgeOf('7'), findsNWidgets(2), reason: 'a shared number: two');
    for (final n in ['1', '2', '3']) {
      expectRect(tester.getRect(badgeOf(n)),
          badgeWanted(tester, tableNumbered(n), embeddingCamera()), n);
    }

    c.panBy(const Offset(-37.25, 12.5));
    expect(c.zoomBy(1.7, focus: const Offset(500, 300)), isTrue);
    await tester.pump();
    final cam = c.cameraController.value;
    expect(cam.scale, isNot(closeTo(0.37, 1e-3)), reason: 'zoomed');
    for (final n in ['1', '2', '3']) {
      expectRect(tester.getRect(badgeOf(n)),
          badgeWanted(tester, tableNumbered(n), cam), 'M-H19: $n moved');
    }
    expect(calls.total, 7, reason: 'pan and zoom build nothing');
  });

  testWidgets(
      'TO2 the builder is never called on a camera change: 50 pans and '
      'zooms, no breakpoint crossed (M-H8, H-8)', (tester) async {
    final c = controller();
    final calls = Calls();
    await mount(tester, c,
        builder: calls.builder(),
        layout: const FloorPlanOverlayLayout(detailBreakpoints: [10]));
    expect(calls.total, 7);
    for (var i = 0; i < 50; i++) {
      if (i.isEven) {
        c.panBy(Offset(3.5 + i, -2.25));
      } else {
        c.zoomBy(i % 4 == 1 ? 1.03 : 1 / 1.02);
      }
      await tester.pump();
    }
    expect(calls.total, 7, reason: 'M-H8: no call across 50 camera changes');
    expect(layerOf(tester).debugCameraPasses, greaterThanOrEqualTo(50));
  });

  testWidgets(
      'TO3 detailLevel counts the breakpoints at or below the scale, one on '
      'the breakpoint included (M-H9, G-7)', (tester) async {
    final c = controller();
    final calls = Calls();
    await mount(tester, c,
        builder: calls.builder(),
        layout:
            const FloorPlanOverlayLayout(detailBreakpoints: [0.25, 0.5, 1.0]),
        camera: cameraAt(0.5));
    expect(c.cameraController.value.scale, 0.5, reason: 'exactly');
    Badge one() => tester.widget<Badge>(badgeOf('1'));
    expect(one().overlay.detailLevel, 2,
        reason: 'M-H9: 0.25 and 0.5 are at or below 0.5');
    c.cameraController.value = cameraAt(0.49);
    await tester.pump();
    expect(one().overlay.detailLevel, 1);
    c.cameraController.value = cameraAt(0.2);
    await tester.pump();
    expect(one().overlay.detailLevel, 0);
    c.cameraController.value = cameraAt(1.0);
    await tester.pump();
    expect(one().overlay.detailLevel, 3);
    expect(overlayDetailLevel(const [], 5), 0);
  });

  testWidgets(
      'TO4 a detail crossing builds every overlay once; zooms that cross '
      'nothing build none (G-7, H-8)', (tester) async {
    final c = controller();
    final calls = Calls();
    await mount(tester, c,
        builder: calls.builder(),
        layout: const FloorPlanOverlayLayout(detailBreakpoints: [0.4]),
        camera: cameraAt(0.37));
    expect(calls.total, 7);
    c.cameraController.value = cameraAt(0.38);
    await tester.pump();
    expect(calls.total, 7, reason: 'below the breakpoint still');
    c.cameraController.value = cameraAt(0.45);
    await tester.pump();
    expect(calls.byNumber, {'1': 2, '2': 2, '3': 2, '4': 2, 'L': 2, '7': 4},
        reason: 'one call per table on the crossing');
    for (final s in [0.5, 0.6, 0.41]) {
      c.cameraController.value = cameraAt(s);
      await tester.pump();
    }
    expect(calls.total, 14, reason: 'above it still');
    expect(tester.widget<Badge>(badgeOf('1')).overlay.detailLevel, 1);
  });

  testWidgets(
      'TO5 a status on one table builds that table only; a group\'s status '
      'is the effective one, over the table\'s own (M-H18, G-5)',
      (tester) async {
    final c = controller();
    final calls = Calls();
    await mount(tester, c, builder: calls.builder());
    final red = TableStatus(color: const Color(0xFFD03030), caption: 'Busy');
    final blue = TableStatus(color: const Color(0xFF3030D0));
    c.setTableStatus({'1': red});
    await tester.pump();
    expect(calls.byNumber, {'1': 2, '2': 1, '3': 1, '4': 1, 'L': 1, '7': 2},
        reason: 'M-H18: table 1 alone');
    FloorPlanTableOverlay of(String n) =>
        tester.widget<Badge>(badgeOf(n)).overlay;
    expect(of('1').status, red);
    expect(of('2').status, isNull);

    c.setTableStatus({'1': red, '2': red});
    c.setTableGroups({
      'g': TableGroup(members: {'2', '3'})
    });
    c.setGroupStatus({'g': blue});
    await tester.pump();
    expect(of('2').status, blue, reason: 'the group over the table');
    expect(of('3').status, blue);
    expect(of('1').status, red);
    expect(calls.byNumber['4'], 1, reason: 'untouched');
    c.setGroupStatus({});
    await tester.pump();
    expect(of('2').status, red, reason: 'the table\'s own again');
    expect(of('3').status, isNull);
  });

  testWidgets(
      'TO6 selected and focused follow the controller, for those tables '
      'alone', (tester) async {
    final c = controller();
    final calls = Calls();
    await mount(tester, c, builder: calls.builder());
    FloorPlanTableOverlay of(String n) =>
        tester.widget<Badge>(badgeOf(n)).overlay;
    expect(of('1').selected, isFalse);
    expect(of('1').focused, isTrue, reason: 'no focus set');
    c.select({'1'});
    await tester.pump();
    expect(of('1').selected, isTrue);
    expect(of('2').selected, isFalse);
    expect(calls.byNumber['2'], 1);
    c.setTableFocus({'2'});
    await tester.pump();
    expect(of('1').focused, isFalse);
    expect(of('2').focused, isTrue);
    expect(of('1').detail, c.tableDetails[0]);
  });

  testWidgets(
      'TO7 box: each widget is its table\'s screen bounding box, the turned '
      'and the scaled ones too, and follows a zoom (M-H10, G-6)',
      (tester) async {
    final c = controller();
    final calls = Calls();
    await mount(tester, c,
        builder: calls.builder(),
        layout: const FloorPlanOverlayLayout(size: FloorPlanOverlaySize.box),
        camera: cameraAt(0.2));
    for (final n in ['1', '2', '3']) {
      expect(dataOf(tester, n).shown, isTrue, reason: 'premise: $n on');
      expectRect(
          tester.getRect(badgeOf(n)),
          canvasBox(tableNumbered(n), cameraAt(0.2))
              .shift(canvasOrigin(tester)),
          'M-H10: $n');
    }
    c.zoomBy(1.25, focus: const Offset(400, 300));
    await tester.pump();
    final cam = c.cameraController.value;
    expectRect(tester.getRect(badgeOf('1')),
        canvasBox(tableNumbered('1'), cam).shift(canvasOrigin(tester)), '1');
    expect(calls.total, 7);
  });

  testWidgets(
      'TO8 the layer ignores pointers by default: a tap on a badge is the '
      'table\'s (M-H11, G-5)', (tester) async {
    final c = controller();
    final calls = Calls();
    var badgeTaps = 0;
    final taps = <String>[];
    await mount(tester, c,
        builder: calls.builder(onTap: () => badgeTaps++), onTableTap: taps.add);
    await tester.tapAt(tester.getCenter(badgeOf('1')),
        kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 500));
    expect(badgeTaps, 0, reason: 'M-H11: the badge took the tap');
    expect(taps, ['1']);
    expect(c.selectedTables.value, {'1'});
  });

  testWidgets(
      'TO9 box: an overlay off the canvas is neither laid out nor painted; '
      'panned on, it is (M-H12, G-6)', (tester) async {
    final c = controller();
    final calls = Calls();
    await mount(tester, c,
        builder: calls.builder(),
        layout: const FloorPlanOverlayLayout(size: FloorPlanOverlaySize.box));
    final four = canvasBox(tableNumbered('4'), embeddingCamera());
    expect(four.left, greaterThan(1440), reason: 'premise: 4 is off');
    expect(dataOf(tester, '4').shown, isFalse);
    expect(dataOf(tester, '1').shown, isTrue);
    final layer = layerOf(tester);
    final before = layer.debugChildLayouts;
    // A zoom about the canvas's left: every box grows, 4 stays off.
    expect(c.zoomBy(1.2, focus: const Offset(0, 300)), isTrue);
    await tester.pump();
    final cam = c.cameraController.value;
    final grown = canvasBox(tableNumbered('4'), cam);
    expect(grown.left, greaterThan(1440), reason: 'premise: 4 still off');
    expect(dataOf(tester, '4').shown, isFalse);
    // Laid out at the first frame's fit, when the page was on the canvas,
    // and not since: its size is not its box's now.
    expect(slotOf(tester, '4').size.width, isNot(closeTo(grown.width, 1e-6)),
        reason: 'M-H12: 4 laid out off the canvas');
    expect(layer.debugChildLayouts - before, shownCount(layer),
        reason: 'one layout per shown table, none for the others');
    expect(shownCount(layer), inInclusiveRange(1, 6),
        reason: 'premise: some on, some off');
    expectRect(tester.getRect(badgeOf('1')),
        canvasBox(tableNumbered('1'), cam).shift(canvasOrigin(tester)), '1');
    c.panBy(Offset(-(grown.left - 600), 0));
    await tester.pump();
    expect(slotOf(tester, '4').hasSize, isTrue);
    expect(dataOf(tester, '4').shown, isTrue);
    expectRect(
        tester.getRect(badgeOf('4')),
        canvasBox(tableNumbered('4'), c.cameraController.value)
            .shift(canvasOrigin(tester)),
        '4 on the canvas');
  });

  testWidgets(
      'TO10 natural: laid out once; culled off the canvas, painted on it; '
      'the render object allocates nothing across 50 camera changes (H-8)',
      (tester) async {
    final c = controller();
    final calls = Calls();
    await mount(tester, c, builder: calls.builder());
    final layer = layerOf(tester);
    expect(dataOf(tester, '4').shown, isFalse, reason: 'off the canvas');
    expect(dataOf(tester, '1').shown, isTrue);
    // A first change settles anything lazy.
    c.panBy(const Offset(1, 1));
    await tester.pump();
    final allocations = layer.debugAllocations;
    final layouts = layer.debugChildLayouts;
    final offsets = layer.debugPaintOffsets;
    var painted = 0;
    for (var i = 0; i < 50; i++) {
      if (i.isEven) {
        c.panBy(Offset(2.5, -1.25 - i / 10));
      } else {
        c.zoomBy(i % 4 == 1 ? 1.02 : 1 / 1.02, focus: const Offset(300, 300));
      }
      await tester.pump();
      painted += shownCount(layer);
    }
    expect(layer.debugAllocations, allocations,
        reason: '0 per table per camera change');
    expect(layer.debugChildLayouts, layouts, reason: 'natural: no relayout');
    expect(layer.debugPaintOffsets - offsets, lessThanOrEqualTo(painted),
        reason: 'one Offset per painted overlay at most, none for the culled');
    expect(painted, lessThan(50 * 7), reason: 'premise: some culled');
    expect(calls.total, 7);
  });

  testWidgets(
      'TO11 below hideBelowScale nothing is laid out or painted; above it, '
      'laid out once and placed (G-6)', (tester) async {
    final c = controller();
    final calls = Calls();
    await mount(tester, c,
        builder: calls.builder(),
        layout: const FloorPlanOverlayLayout(hideBelowScale: 0.4),
        camera: cameraAt(0.37));
    for (final n in ['1', '2', '3']) {
      expect(dataOf(tester, n).shown, isFalse, reason: '$n hidden');
      expect(slotOf(tester, n).hasSize, isFalse, reason: '$n not laid out');
    }
    c.cameraController.value = cameraAt(0.4);
    await tester.pump();
    final cam = c.cameraController.value;
    for (final n in ['1', '2']) {
      expect(dataOf(tester, n).shown, isTrue, reason: '$n at the bound');
    }
    for (final n in ['1', '2', '3']) {
      expectRect(tester.getRect(badgeOf(n)),
          badgeWanted(tester, tableNumbered(n), cam), n);
    }
    c.cameraController.value = cameraAt(0.39);
    await tester.pump();
    expect(dataOf(tester, '1').shown, isFalse);
    expect(calls.total, 7);
  });

  testWidgets(
      'TO12 the anchor pins the widget\'s own point on the box\'s (as Align '
      'places it)', (tester) async {
    final c = controller();
    const anchor = Alignment(0.5, -1);
    await mount(tester, c,
        builder: Calls().builder(),
        layout: const FloorPlanOverlayLayout(anchor: anchor));
    for (final n in ['1', '2', '3']) {
      final box = canvasBox(tableNumbered(n), embeddingCamera())
          .shift(canvasOrigin(tester));
      // x: three quarters across the box, the badge's own three quarters
      // there; y: the box's top, the badge's top there.
      final want = Rect.fromLTWH(
          box.left + 0.75 * box.width - 0.75 * Badge.size.width,
          box.top,
          Badge.size.width,
          Badge.size.height);
      expectRect(tester.getRect(badgeOf(n)), want, n);
    }
  });

  testWidgets(
      'TO13 overlays are not shown in the design mode by default; asked for, '
      'they are, on the design\'s canvas (M-H19b(design default), G-5)',
      (tester) async {
    final c = controller(design: true);
    final calls = Calls();
    await mount(tester, c, builder: calls.builder());
    expect(find.byType(Badge, skipOffstage: false), findsNothing,
        reason: 'M-H19b: the design mode shows none by default');
    expect(find.byType(TableOverlayLayer), findsNothing);
    expect(calls.total, 0);

    final d = controller(design: true);
    await mount(tester, d,
        builder: calls.builder(), modes: {FloorPlanMode.design});
    expect(find.byType(Badge, skipOffstage: false), findsNWidgets(7));
    expectRect(tester.getRect(badgeOf('1')),
        badgeWanted(tester, tableNumbered('1'), embeddingCamera()), 'design');
    d.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    expect(find.byType(Badge, skipOffstage: false), findsNothing,
        reason: 'not asked for in the selection mode');
  });

  testWidgets('TO14 no builder: no layer in the tree, in either mode (H-8)',
      (tester) async {
    final c = controller(design: true);
    await mount(tester, c);
    expect(find.byType(TableOverlayLayer), findsNothing);
    expect(
        tester.allRenderObjects.whereType<RenderFloorPlanOverlays>(), isEmpty);
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    expect(find.byType(TableOverlayLayer), findsNothing);
    expect(
        tester.allRenderObjects.whereType<RenderFloorPlanOverlays>(), isEmpty);
  });

  testWidgets(
      'TO15 a reset builds every overlay afresh (documented lifetime); a '
      'host rebuild with the same builder builds none, another builder '
      'builds all (G-5)', (tester) async {
    final c = controller();
    final calls = Calls();
    final builders =
        ValueNotifier<FloorPlanTableOverlayBuilder?>(calls.builder());
    final layouts = ValueNotifier(const FloorPlanOverlayLayout());
    await mount(tester, c, builders: builders, layouts: layouts);
    expect(Badge.created, 7);
    final state = tester.state(badgeOf('1'));

    // The host rebuilds the view with another layout, the same builder.
    layouts.value = const FloorPlanOverlayLayout(hideBelowScale: 0.001);
    await tester.pump();
    expect(calls.total, 7, reason: 'the same builder: no call');
    expect(identical(tester.state(badgeOf('1')), state), isTrue);

    c.resetLayout();
    await tester.pump();
    await tester.pump();
    expect(Badge.created, 14, reason: 'a reset remounts every overlay');
    expect(identical(tester.state(badgeOf('1')), state), isFalse);
    expect(calls.total, 14);

    final other = Calls();
    builders.value = other.builder();
    await tester.pump();
    expect(other.total, 7, reason: 'another builder: every table');
    expect(calls.total, 14);
  });

  testWidgets(
      'TO16 during a service drag the overlay stays at the committed place; '
      'it moves on the drop (G-5)', (tester) async {
    final c = controller();
    final calls = Calls();
    await mount(tester, c, builder: calls.builder());
    final start = tester.getRect(badgeOf('1'));
    await tester.tapAt(start.center, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.selectedTables.value, {'1'});
    final selected = calls.byNumber['1']!;
    final g =
        await tester.startGesture(start.center, kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(40, 0));
    await tester.pump();
    await g.moveBy(const Offset(40, 0));
    await tester.pump();
    expectRect(tester.getRect(badgeOf('1')), start, 'during the drag');
    await g.up();
    await tester.pump();
    expectRect(tester.getRect(badgeOf('1')), start.shift(const Offset(80, 0)),
        'after the drop');
    expect(calls.byNumber['1'], selected + 1, reason: 'its geometry changed');
    expect(calls.byNumber['2'], 1);
  });

  testWidgets(
      'TO17 a layout the view cannot use is an ArgumentError, only with a '
      'builder (G-7)', (tester) async {
    for (final bad in const [
      FloorPlanOverlayLayout(detailBreakpoints: [0.5, 0.25]),
      FloorPlanOverlayLayout(detailBreakpoints: [0.25, 0.25]),
      FloorPlanOverlayLayout(detailBreakpoints: [0, 1]),
      FloorPlanOverlayLayout(detailBreakpoints: [-1]),
      FloorPlanOverlayLayout(detailBreakpoints: [double.nan]),
      FloorPlanOverlayLayout(detailBreakpoints: [1, double.infinity]),
      FloorPlanOverlayLayout(hideBelowScale: -0.1),
      FloorPlanOverlayLayout(hideBelowScale: double.nan),
      FloorPlanOverlayLayout(maxNaturalSize: Size(double.infinity, 10)),
      FloorPlanOverlayLayout(maxNaturalSize: Size(10, -1)),
    ]) {
      expect(() => validateOverlayLayout(bad), throwsArgumentError,
          reason: '$bad');
    }
    validateOverlayLayout(const FloorPlanOverlayLayout(
        detailBreakpoints: [0.01, 0.05, 2], hideBelowScale: 0.001));

    final c = controller();
    await tester.pumpWidget(MaterialApp(
        home: FloorPlanView(
            controller: c,
            tableOverlayBuilder: Calls().builder(),
            tableOverlayLayout:
                const FloorPlanOverlayLayout(detailBreakpoints: [2, 1]))));
    expect(tester.takeException(), isArgumentError);
    await tester.pumpWidget(MaterialApp(
        home: FloorPlanView(
            controller: c,
            tableOverlayLayout:
                const FloorPlanOverlayLayout(detailBreakpoints: [2, 1]))));
    expect(tester.takeException(), isNull, reason: 'no builder: unused');
  });

  test('TO18 the value types: ==, hashCode, toString', () {
    final c = FloorPlanController(json: embeddingPlanJson());
    addTearDown(c.dispose);
    final d = c.tableDetails.first;
    final a = FloorPlanTableOverlay(
        detail: d,
        selected: true,
        focused: false,
        status: null,
        detailLevel: 1);
    final b = FloorPlanTableOverlay(
        detail: d,
        selected: true,
        focused: false,
        status: null,
        detailLevel: 1);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    for (final other in [
      FloorPlanTableOverlay(
          detail: d,
          selected: false,
          focused: false,
          status: null,
          detailLevel: 1),
      FloorPlanTableOverlay(
          detail: d,
          selected: true,
          focused: true,
          status: null,
          detailLevel: 1),
      FloorPlanTableOverlay(
          detail: d,
          selected: true,
          focused: false,
          status: TableStatus(color: const Color(0xFF000000)),
          detailLevel: 1),
      FloorPlanTableOverlay(
          detail: d,
          selected: true,
          focused: false,
          status: null,
          detailLevel: 2),
      FloorPlanTableOverlay(
          detail: c.tableDetails[1],
          selected: true,
          focused: false,
          status: null,
          detailLevel: 1),
    ]) {
      expect(a == other, isFalse, reason: '$other');
    }
    expect(a.toString(),
        'FloorPlanTableOverlay(1, selected: true, focused: false, status: null, detailLevel: 1)');
    const l = FloorPlanOverlayLayout();
    expect(l.anchor, Alignment.center);
    expect(l.size, FloorPlanOverlaySize.natural);
    expect(l.maxNaturalSize, const Size(200, 120));
    expect(l.hideBelowScale, 0);
    expect(l.detailBreakpoints, isEmpty);
    expect(l.interactive, isFalse);
    expect(l, FloorPlanOverlayLayout(detailBreakpoints: List.of(const [])));
    expect(l == const FloorPlanOverlayLayout(detailBreakpoints: [1]), isFalse);
    expect(l == const FloorPlanOverlayLayout(interactive: true), isFalse);
    expect(
        const FloorPlanOverlayLayout(detailBreakpoints: [1, 2]).hashCode,
        FloorPlanOverlayLayout(detailBreakpoints: List.of(const [1.0, 2.0]))
            .hashCode);
  });
}
