// Host embedding API spec, Slice 1, G-5, G-6, G-7 and H-8: the host's
// widgets on the tables (`FloorPlanView.tableOverlayBuilder`), their
// placement (`FloorPlanOverlayLayout`), the detail levels, and the layer's
// cost (`RenderFloorPlanOverlays`), over the shared non-degenerate fixture
// (embedding_fixture): an off-base box, tables turned, mirrored and scaled
// 40 m off the origin, a hidden and a locked layer, a shared number, and a
// panned camera at 0.37 px/mm. Expected places are computed here by the
// forward transform of the fixture's box, never read back from the code.
import 'dart:math' as math;
import 'dart:ui' as ui show ImageByteFormat;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OffsetLayer, SemanticsNode;
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

/// [layer]'s children, in paint order.
Iterable<RenderBox> childrenOf(RenderFloorPlanOverlays layer) sync* {
  var child = layer.firstChild;
  while (child != null) {
    yield child;
    child = (child.parentData! as FloorPlanOverlayParentData).nextSibling;
  }
}

/// A builder whose widget is a semantics node labelled by its table: `T`,
/// the number, and for the shared `7` its centre's x, so both are told
/// apart.
Widget? labelled(BuildContext context, FloorPlanTableOverlay t) {
  final n = t.detail.table.number!;
  return Semantics(
    label: 'T$n-${n == '7' ? t.detail.center!.dx.round() : 0}',
    container: true,
    child: SizedBox.fromSize(size: Badge.size),
  );
}

/// The overlays' semantics nodes in the live tree, by label, each with
/// its rectangle in the view's physical pixels.
Map<String, Rect> overlaySemantics(WidgetTester tester) {
  final out = <String, Rect>{};
  void walk(SemanticsNode n, Matrix4 m) {
    final t = n.transform == null ? m : (m.clone()..multiply(n.transform!));
    if (n.label.startsWith('T')) {
      out[n.label] = MatrixUtils.transformRect(t, n.rect);
    }
    n.visitChildren((child) {
      walk(child, t);
      return true;
    });
  }

  walk(
      tester
          .binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!,
      Matrix4.identity());
  return out;
}

/// A host whose overlay builder is a method tear-off reading its own
/// field: `==` across its builds.
class TearOffHost extends StatefulWidget {
  const TearOffHost({super.key, required this.controller, required this.calls});

  final FloorPlanController controller;
  final Calls calls;

  @override
  State<TearOffHost> createState() => TearOffHostState();
}

class TearOffHostState extends State<TearOffHost> {
  String prefix = 'a';

  void rename(String next) => setState(() => prefix = next);

  Widget? _badge(BuildContext context, FloorPlanTableOverlay t) {
    final n = t.detail.table.number!;
    widget.calls.byNumber[n] = (widget.calls.byNumber[n] ?? 0) + 1;
    return Text('$prefix-$n', textDirection: TextDirection.ltr);
  }

  @override
  Widget build(BuildContext context) =>
      FloorPlanView(controller: widget.controller, tableOverlayBuilder: _badge);
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
      'host rebuild builds every overlay again, keeping its State, with the '
      'same builder or another (G-5)', (tester) async {
    final c = controller();
    final calls = Calls();
    final builders =
        ValueNotifier<FloorPlanTableOverlayBuilder?>(calls.builder());
    final layouts = ValueNotifier(const FloorPlanOverlayLayout());
    await mount(tester, c, builders: builders, layouts: layouts);
    expect(Badge.created, 7);
    final state = tester.state(badgeOf('1'));

    // The host rebuilds the view with another layout, the same builder
    // (review R-1: the spec's rule, whatever the builder's identity).
    layouts.value = const FloorPlanOverlayLayout(hideBelowScale: 0.001);
    await tester.pump();
    expect(calls.total, 14, reason: 'a host rebuild: every table again');
    expect(identical(tester.state(badgeOf('1')), state), isTrue,
        reason: 'rebuilt, not remounted');
    expect(Badge.created, 7);

    c.resetLayout();
    await tester.pump();
    await tester.pump();
    expect(Badge.created, 14, reason: 'a reset remounts every overlay');
    expect(identical(tester.state(badgeOf('1')), state), isFalse);
    expect(calls.total, 21);

    final other = Calls();
    builders.value = other.builder();
    await tester.pump();
    expect(other.total, 7, reason: 'another builder: every table');
    expect(calls.total, 21);
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

  testWidgets(
      'TO19 a host rebuild with a closure written in build builds every '
      'overlay again, keeping its State; pan and zoom still build none '
      '(review R-1, G-5)', (tester) async {
    final c = controller();
    final calls = Calls();
    late StateSetter rebuild;
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
      rebuild = setState;
      return FloorPlanView(
          controller: c,
          tableOverlayBuilder: (context, t) => calls.builder()(context, t));
    }))));
    await tester.pump();
    await tester.pump();
    c.cameraController.value = embeddingCamera();
    await tester.pump();
    expect(calls.byNumber, {'1': 1, '2': 1, '3': 1, '4': 1, 'L': 1, '7': 2});
    final state = tester.state(badgeOf('1'));
    rebuild(() {});
    await tester.pump();
    expect(calls.byNumber, {'1': 2, '2': 2, '3': 2, '4': 2, 'L': 2, '7': 4},
        reason: 'a host rebuild: every table once more');
    expect(identical(tester.state(badgeOf('1')), state), isTrue,
        reason: 'rebuilt, not remounted');
    c.panBy(const Offset(-20, 10));
    c.zoomBy(1.3);
    await tester.pump();
    expect(calls.total, 14, reason: 'pan and zoom build nothing');
  });

  testWidgets(
      'TO20 a host rebuild with a method tear-off, == across the host\'s '
      'builds, builds every overlay again: one reading the host\'s field is '
      'never stale (review R-1, G-5)', (tester) async {
    final c = controller();
    final calls = Calls();
    final host = GlobalKey<TearOffHostState>();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TearOffHost(key: host, controller: c, calls: calls))));
    await tester.pump();
    await tester.pump();
    expect(find.text('a-1'), findsOneWidget);
    expect(find.text('a-7'), findsNWidgets(2));
    host.currentState!.rename('b');
    await tester.pump();
    expect(find.text('a-1'), findsNothing, reason: 'stale');
    expect(find.text('b-1'), findsOneWidget);
    expect(find.text('b-7'), findsNWidgets(2));
    expect(calls.byNumber, {'1': 2, '2': 2, '3': 2, '4': 2, 'L': 2, '7': 4});
    c.select({'2'});
    await tester.pump();
    expect(calls.byNumber, {'1': 2, '2': 3, '3': 2, '4': 2, 'L': 2, '7': 4},
        reason: 'an internal trigger: that table alone');
  });

  testWidgets(
      'TO21 box: across 50 camera changes the render object allocates '
      'nothing, hands the framework one paint offset per overlay shown at '
      'most, and lays out each shown overlay once per frame (review R-2, '
      'H-8)', (tester) async {
    final c = controller();
    final calls = Calls();
    await mount(tester, c,
        builder: calls.builder(),
        layout: const FloorPlanOverlayLayout(size: FloorPlanOverlaySize.box));
    final layer = layerOf(tester);
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
    expect(layer.debugPaintOffsets - offsets, lessThanOrEqualTo(painted),
        reason: 'one Offset per painted overlay at most, none for the culled');
    expect(layer.debugChildLayouts - layouts, painted,
        reason: 'box: one layout per shown overlay per frame, none else');
    expect(painted, inExclusiveRange(0, 50 * 7),
        reason: 'premise: some culled');
    expect(calls.total, 7);
  });

  testWidgets(
      'TO22 each shown overlay is composited at its place after pans and '
      'zooms; a culled one is not composited (review R-3, H-8)',
      (tester) async {
    final c = controller();
    await mount(tester, c, builder: Calls().builder());
    for (var i = 0; i < 3; i++) {
      c.panBy(Offset(-31.5 * (i + 1), 7.25));
      expect(c.zoomBy(1.13, focus: const Offset(311, 207)), isTrue);
      await tester.pump();
      final layer = layerOf(tester);
      var shown = 0, culled = 0;
      for (final child in childrenOf(layer)) {
        final d = child.parentData! as FloorPlanOverlayParentData;
        final composited = child.debugLayer;
        if (d.shown) {
          shown++;
          expect((composited! as OffsetLayer).offset, Offset(d.dx, d.dy),
              reason: 'frame $i: painted at its place');
          expect(composited.parent, isNotNull, reason: 'frame $i: composited');
          final at = child.localToGlobal(Offset.zero) -
              layer.localToGlobal(Offset.zero);
          expect(at.dx, closeTo(d.dx, 1e-9));
          expect(at.dy, closeTo(d.dy, 1e-9));
        } else {
          culled++;
          expect(composited?.parent, isNull,
              reason: 'frame $i: culled, not composited');
        }
      }
      expect(shown, greaterThan(0), reason: 'premise: frame $i shows some');
      expect(culled, greaterThan(0), reason: 'premise: frame $i culls some');
    }
    // Where it is painted is where the transform says it is.
    final cam = c.cameraController.value;
    final one = slotOf(tester, '1');
    final layer = layerOf(tester);
    final want = badgeWanted(tester, tableNumbered('1'), cam)
        .shift(-layer.localToGlobal(Offset.zero));
    final offset = (one.debugLayer! as OffsetLayer).offset;
    expect(offset.dx, closeTo(want.left, 1e-6));
    expect(offset.dy, closeTo(want.top, 1e-6));
  });

  testWidgets(
      'TO23 overlays in both modes across mode switches, then camera '
      'changes: no listener outlives its render object (review R-4)',
      (tester) async {
    final c = controller();
    await mount(tester, c,
        builder: Calls().builder(),
        modes: {FloorPlanMode.selection, FloorPlanMode.design});
    for (final mode in [FloorPlanMode.design, FloorPlanMode.selection]) {
      c.setMode(mode);
      await tester.pump();
      await tester.pump();
      c.panBy(const Offset(10, 10));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: mode.name);
    }
    expect(tester.allRenderObjects.whereType<RenderFloorPlanOverlays>(),
        hasLength(1));
  });

  testWidgets(
      'TO24 semantics: the shown overlays alone, at their places after a '
      'pan; none when every one is panned off (review R-5)', (tester) async {
    final handle = tester.ensureSemantics();
    final c = controller();
    await mount(tester, c, builder: labelled);
    final layer = layerOf(tester);
    final before = overlaySemantics(tester);
    expect(before.length, shownCount(layer), reason: 'the shown alone');
    expect(before.length, inExclusiveRange(0, 7), reason: 'premise: culled');
    c.panBy(const Offset(-123.5, 45.25));
    await tester.pump();
    final after = overlaySemantics(tester);
    expect(after.length, shownCount(layer));
    final dpr = tester.view.devicePixelRatio;
    for (final MapEntry(key: label, value: rect) in after.entries) {
      final widget = tester.getRect(find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == label));
      expect(rect.left / dpr, closeTo(widget.left, 1e-6), reason: label);
      expect(rect.top / dpr, closeTo(widget.top, 1e-6), reason: label);
    }
    c.panBy(const Offset(-5000, 0));
    await tester.pump();
    expect(shownCount(layer), 0, reason: 'premise: all off');
    expect(overlaySemantics(tester), isEmpty);
    handle.dispose();
  });

  testWidgets(
      'TO25 semantics below hideBelowScale: none, after having been shown '
      '(review R-5, G-6)', (tester) async {
    final handle = tester.ensureSemantics();
    final c = controller();
    await mount(tester, c,
        builder: labelled,
        layout: const FloorPlanOverlayLayout(hideBelowScale: 0.3));
    expect(overlaySemantics(tester), isNotEmpty, reason: 'premise: at 0.37');
    c.cameraController.value = cameraAt(0.29);
    await tester.pump();
    expect(overlaySemantics(tester), isEmpty);
    handle.dispose();
  });

  testWidgets(
      'TO26 box: a canvas resize with the camera unchanged culls and shows '
      'again (review R-6, G-6)', (tester) async {
    final c = controller();
    await mount(tester, c,
        builder: Calls().builder(),
        layout: const FloorPlanOverlayLayout(size: FloorPlanOverlaySize.box),
        camera: cameraAt(0.2));
    final cam = c.cameraController.value;
    Map<String, bool> shown() => {
          for (final n in ['1', '2', '3', '4']) n: dataOf(tester, n).shown
        };
    Map<String, bool> wanted() {
      final layer = layerOf(tester);
      return {
        for (final n in ['1', '2', '3', '4'])
          n: canvasBox(tableNumbered(n), cam).overlaps(Offset.zero & layer.size)
      };
    }

    final wide = shown();
    expect(wide, wanted());
    await tester.binding.setSurfaceSize(const Size(560, 900));
    await tester.pump();
    await tester.pump();
    expect(identical(c.cameraController.value, cam), isTrue,
        reason: 'premise: the camera unchanged');
    final narrow = shown();
    expect(narrow, wanted(), reason: 'narrower: culled');
    expect(narrow, isNot(wide), reason: 'premise: the resize culls one');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pump();
    await tester.pump();
    expect(identical(c.cameraController.value, cam), isTrue);
    expect(shown(), wide, reason: 'wider again: shown again');
    for (final n in ['1', '2', '3']) {
      if (!wide[n]!) continue;
      expectRect(tester.getRect(badgeOf(n)),
          canvasBox(tableNumbered(n), cam).shift(canvasOrigin(tester)), n);
    }
  });

  testWidgets(
      'TO27 the box cache follows the geometry alone: a selection tap, a '
      'status and a detail crossing keep it (no relayout), a moved table '
      'replaces it (review R-9, H-8)', (tester) async {
    final c = controller();
    await mount(tester, c,
        builder: Calls().builder(),
        layout: const FloorPlanOverlayLayout(
            size: FloorPlanOverlaySize.box, detailBreakpoints: [0.3]),
        camera: cameraAt(0.2));
    final layer = layerOf(tester);
    final corners = layer.corners;
    final layouts = layer.debugChildLayouts;
    final start = tester.getRect(badgeOf('1'));
    await tester.tapAt(start.center, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.selectedTables.value, {'1'}, reason: 'premise: selected');
    expect(tester.widget<Badge>(badgeOf('1')).overlay.selected, isTrue);
    expect(identical(layer.corners, corners), isTrue, reason: 'a selection');
    c.setTableStatus({'2': TableStatus(color: const Color(0xFFD03030))});
    await tester.pump();
    expect(identical(layer.corners, corners), isTrue, reason: 'a status');
    expect(layer.debugChildLayouts, layouts, reason: 'no relayout');
    c.cameraController.value = cameraAt(0.31);
    await tester.pump();
    expect(tester.widget<Badge>(badgeOf('1')).overlay.detailLevel, 1,
        reason: 'premise: crossed');
    expect(identical(layer.corners, corners), isTrue, reason: 'a crossing');

    final at = tester.getRect(badgeOf('1')).center;
    final g = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(40, 0));
    await tester.pump();
    await g.moveBy(const Offset(40, 0));
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(identical(layer.corners, corners), isFalse,
        reason: 'a moved table: a new cache');
    expect(
        tester.getRect(badgeOf('1')).left,
        closeTo(
            canvasBox(tableNumbered('1'), cameraAt(0.31)).left +
                80 +
                canvasOrigin(tester).dx,
            1e-6));
  });

  // ---- Task 4: interactive overlays (G-5's pointers) ----------------------

  testWidgets(
      'TO28 interactive: a tap on a badge is the badge\'s alone: its onTap, '
      'no onTableTap, no selection; a drag from it moves no table and pans '
      'nothing; a long press and a secondary click on it open no menu '
      '(M-H16, G-5)', (tester) async {
    final c = controller();
    final host = await mountInteractive(tester, c);
    final camera = c.cameraController.value;
    final badge = tester.getCenter(find.byKey(const ValueKey('probe-1')));
    await tester.tapAt(badge, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tapAt(badge, kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 500));
    expect(host.badgeTaps, ['1', '1'], reason: 'the badge\'s own tap');
    expect(host.tableTaps, isEmpty, reason: 'M-H16: the table tool heard it');
    expect(c.selectedTables.value, isEmpty);
    // A drag from the badge: the table stays, the camera too.
    final center = centerOf(c, '1');
    final drag =
        await tester.startGesture(badge, kind: PointerDeviceKind.mouse);
    for (var i = 0; i < 3; i++) {
      await drag.moveBy(const Offset(40, 25));
      await tester.pump();
    }
    await drag.up();
    await tester.pump();
    expect(centerOf(c, '1'), center, reason: 'the table moved');
    expect(identical(c.cameraController.value, camera), isTrue,
        reason: 'the camera panned');
    // A long press (the menu's) and a secondary click on the badge.
    final hold =
        await tester.startGesture(badge, kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(seconds: 1));
    await hold.up();
    await tester.pump();
    await tester.tapAt(badge,
        kind: PointerDeviceKind.mouse, buttons: kSecondaryButton);
    await tester.pump();
    expect(host.menus, isEmpty, reason: 'a menu from a claimed pointer');
    expect(host.tableTaps, isEmpty);
    expect(c.selectedTables.value, isEmpty);
    // The premise: on table 1 off its badge, the same gestures are the
    // table's.
    final off = onTableOffBadge(tester, c, '1');
    await tester.tapAt(off, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tapAt(off,
        kind: PointerDeviceKind.mouse, buttons: kSecondaryButton);
    await tester.pump();
    expect(host.tableTaps, ['1']);
    expect(host.menus, ['1']);
    expect(c.selectedTables.value, {'1'});
    // The badge's own recognizer counted the hold as its third tap.
    expect(host.badgeTaps, ['1', '1', '1']);
  });

  testWidgets(
      'TO29 interactive: a pan that starts off a badge pans, across a badge '
      'too; a pinch with one finger on a badge does not count it; a wheel '
      'over a badge zooms (G-5)', (tester) async {
    final c = controller();
    final host = await mountInteractive(tester, c);
    final origin = canvasOrigin(tester);
    // Empty floor between tables 1 and 2, in the canvas of the camera now.
    Offset floor() {
      final p = canvasOf(c.cameraController.value, 41600, -26900);
      final at = Offset(p.x, p.y);
      expect(c.tableAt(at), isNull, reason: 'premise: empty floor');
      expect((Offset.zero & const Size(1440, 856)).contains(at), isTrue,
          reason: 'premise: on the canvas');
      return at;
    }

    Offset probe(String n) {
      expect(probeData(tester, n).shown, isTrue, reason: 'premise: $n shown');
      return tester.getCenter(find.byKey(ValueKey('probe-$n')));
    }

    // A mouse drag from the floor that crosses onto badge 2 and ends there.
    final from = origin + floor();
    final to = probe('2');
    var before = c.cameraController.value.worldToScreenMatrix;
    final pan = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    await pan.moveTo(from + (to - from) / 2);
    await tester.pump();
    await pan.moveTo(to);
    await tester.pump();
    await pan.up();
    await tester.pump();
    var after = c.cameraController.value.worldToScreenMatrix;
    expect(after.e - before.e, closeTo((to - from).dx, 1e-9));
    expect(after.f - before.f, closeTo((to - from).dy, 1e-9));
    expect(after.a, before.a);
    expect(host.badgeTaps, isEmpty);
    expect(host.tableTaps, isEmpty);
    // A finger on badge 1, then one on the floor moving away from it: a
    // pinch of the two would zoom.
    final onBadge = probe('1');
    final onFloor = origin + floor();
    before = c.cameraController.value.worldToScreenMatrix;
    final f1 = await tester.startGesture(onBadge,
        pointer: 31, kind: PointerDeviceKind.touch);
    final f2 = await tester.startGesture(onFloor,
        pointer: 32, kind: PointerDeviceKind.touch);
    for (final step in const [Offset(30, 20), Offset(70, 45)]) {
      await f2.moveTo(onFloor + step);
      await tester.pump();
    }
    after = c.cameraController.value.worldToScreenMatrix;
    expect(after.a, before.a, reason: 'the badge finger was in a pinch');
    // The floor finger alone pans by its own motion.
    expect(after.e - before.e, closeTo(70, 1e-9));
    expect(after.f - before.f, closeTo(45, 1e-9));
    await f2.up();
    await f1.up();
    await tester.pump(const Duration(milliseconds: 500));
    expect(host.badgeTaps, ['1'], reason: 'premise: the finger was on it');
    expect(host.tableTaps, isEmpty);
    // A wheel notch up over a badge zooms about the pointer.
    final at = probe('1');
    final scale = c.cameraController.value.scale;
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(at));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
    await tester.pump();
    expect(c.cameraController.value.scale / scale,
        closeTo(GesturePolicy.forPlatform().wheelZoomStep, 1e-9));
  });

  testWidgets(
      'TO30 interactive: under a non-identity camera a badge is hit where it '
      'is painted, at its own coordinates, before and after a pan and zoom '
      '(M-H17, G-5)', (tester) async {
    final c = controller();
    final host = await mountInteractive(tester, c);
    Future<void> check(String when) async {
      final cam = c.cameraController.value;
      for (final n in ['1', '2', '3']) {
        if (!probeData(tester, n).shown) continue;
        final want = badgeWanted(tester, tableNumbered(n), cam);
        final probe = find.byKey(ValueKey('probe-$n'));
        expectRect(tester.getRect(probe), want, '$when $n: localToGlobal');
        final layer = probeSlot(tester, n).debugLayer! as OffsetLayer;
        final painted = layer.offset + canvasOrigin(tester);
        expect(painted.dx, closeTo(want.left, 1e-6), reason: '$when $n: x');
        expect(painted.dy, closeTo(want.top, 1e-6), reason: '$when $n: y');
        host.downs.clear();
        // Off the badge's centre, so a mirrored or halved offset shows.
        const inside = Offset(31, 4);
        await tester.tapAt(want.topLeft + inside,
            kind: PointerDeviceKind.mouse);
        await tester.pump(const Duration(milliseconds: 500));
        expect(host.downs.map((d) => d.$1), [n], reason: '$when $n: hit');
        expect(host.downs.single.$2.dx, closeTo(inside.dx, 1e-6),
            reason: '$when $n: local x');
        expect(host.downs.single.$2.dy, closeTo(inside.dy, 1e-6),
            reason: '$when $n: local y');
      }
    }

    expect(probeData(tester, '1').shown, isTrue, reason: 'premise: 1 shown');
    await check('fixture camera');
    c.panBy(const Offset(-130, 85));
    expect(c.zoomBy(1.37, focus: const Offset(300, 200)), isTrue);
    await tester.pump();
    expect(probeData(tester, '1').shown, isTrue, reason: 'premise: 1 shown');
    await check('panned and zoomed');
    expect(host.tableTaps, isEmpty);
    expect(c.selectedTables.value, isEmpty);
  });

  testWidgets(
      'TO31 switching interactive builds every overlay afresh; the default '
      'puts no claim in the tree (G-5)', (tester) async {
    final c = controller();
    final layouts = ValueNotifier(const FloorPlanOverlayLayout());
    addTearDown(layouts.dispose);
    await mount(tester, c, builder: Calls().builder(), layouts: layouts);
    expect(find.byType(InputClaim), findsNothing);
    final created = Badge.created;
    layouts.value = const FloorPlanOverlayLayout(interactive: true);
    await tester.pump();
    expect(find.byType(InputClaim), findsNWidgets(kOverlaid.length));
    expect(Badge.created - created, kOverlaid.length);
    layouts.value = const FloorPlanOverlayLayout();
    await tester.pump();
    expect(find.byType(InputClaim), findsNothing);
    expect(Badge.created - created, 2 * kOverlaid.length);
  });

  testWidgets(
      'TO32 each overlay is keyed by its own table\'s instance: with the '
      'hidden 5 before L and the 7s, showing and hiding its layer keeps '
      'every other badge\'s State (final review F-4)', (tester) async {
    final c = controller(design: true);
    final calls = Calls();
    await mount(tester, c,
        builder: calls.builder(), modes: {FloorPlanMode.design});
    Map<Offset, State> states() => {
          for (final e in find.byType(Badge).evaluate())
            (e.widget as Badge).overlay.detail.center!:
                (e as StatefulElement).state,
        };
    final before = states();
    expect(before.length, 7, reason: 'premise: 5 is hidden');
    final created = Badge.created;
    final d = c.activeDocument;
    final hidden = d.tables.layers.byName(kEmbeddingHidden)!;

    d.commands.execute(SetLayerCommand(hidden.copyWith(visible: true)));
    await tester.pump();
    await tester.pump();
    final shown = states();
    expect(shown.length, 8, reason: '5 is shown');
    expect(Badge.created, created + 1, reason: 'only 5\'s badge is new');
    for (final MapEntry(key: at, value: state) in before.entries) {
      expect(identical(shown[at], state), isTrue,
          reason: 'the badge at $at keeps its State');
    }

    final again = Badge.created;
    d.commands.execute(SetLayerCommand(
        d.tables.layers.byName(kEmbeddingHidden)!.copyWith(visible: false)));
    await tester.pump();
    await tester.pump();
    final after = states();
    expect(after.length, 7, reason: '5 is hidden again');
    expect(Badge.created, again, reason: 'no badge is new');
    for (final MapEntry(key: at, value: state) in before.entries) {
      expect(identical(after[at], state), isTrue,
          reason: 'the badge at $at keeps its State');
    }
  });

  testWidgets(
      'TO33 a badge straddling the canvas\'s top edge is clipped to the '
      'canvas: it does not paint over the service bar (G-5, final review '
      'F-2)', (tester) async {
    final c = controller();
    final calls = Calls();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final frame = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: frame,
        child: hostOf(c,
            builder: ValueNotifier(calls.builder()),
            layout: ValueNotifier(const FloorPlanOverlayLayout()))));
    await tester.pump();
    await tester.pump();
    // The fixture's camera moved up so table 1's centre is 4 px below the
    // canvas's top edge: its 20 px high badge sits across it.
    final one = canvasBox(tableNumbered('1'), embeddingCamera()).center;
    final m = embeddingCamera().worldToScreenMatrix;
    c.cameraController.value = ViewportTransform(
        worldToScreenMatrix:
            Transform2(m.a, m.b, m.c, m.d, m.e, m.f + 4 - one.dy));
    await tester.pump();

    final canvas = tester.getRect(find.byType(InteractionLayer));
    final badge = tester.getRect(badgeOf('1'));
    expect(canvas.top, greaterThan(10), reason: 'premise: a bar above');
    expect(badge.top, closeTo(canvas.top - 6, 1e-6), reason: 'premise');
    expect(badge.bottom, closeTo(canvas.top + 14, 1e-6), reason: 'premise');

    // The nearest clip above the badge is the layer's own, the canvas's
    // rect (G-5). The drawing area's `Flow` clips to the same rect today,
    // so the pixels below would not tell this one gone (final review F-2,
    // mutant I); they guard the two together.
    final clip =
        find.ancestor(of: badgeOf('1'), matching: find.byType(ClipRect)).first;
    expect(tester.widget<ClipRect>(clip).clipBehavior, isNot(Clip.none));
    final clipBox = tester.renderObject<RenderBox>(clip);
    expect(clipBox.localToGlobal(Offset.zero) & clipBox.size, canvas);

    // What is painted: the badge's colour below the edge, not above it.
    final boundary = tester.renderObject<RenderBox>(find.byKey(frame));
    final layer = boundary.debugLayer! as OffsetLayer;
    final bytes = (await tester.runAsync(() async {
      final image = await layer.toImage(Offset.zero & boundary.size);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data;
    }))!;
    final width = boundary.size.width.round();
    int pixel(double x, double y) {
      final i = (y.floor() * width + x.floor()) * 4;
      return bytes.getUint8(i) << 24 |
          bytes.getUint8(i + 1) << 16 |
          bytes.getUint8(i + 2) << 8 |
          bytes.getUint8(i + 3);
    }

    const blue = 0x3060C0FF;
    final x = badge.center.dx;
    expect(pixel(x, canvas.top + 3).toRadixString(16), blue.toRadixString(16),
        reason: 'premise: the badge is painted on the canvas');
    expect(pixel(x, canvas.top - 3).toRadixString(16),
        isNot(blue.toRadixString(16)),
        reason: 'the bar above the canvas is not painted over');
  });
}

/// What an interactive host heard (Task 4).
final class InteractiveHost {
  final List<String> badgeTaps = [];
  final List<(String, Offset)> downs = [];
  final List<String> tableTaps = [];
  final List<String> menus = [];
}

/// Mounts an interactive host at 1440 x 900 with the fixture's camera: each
/// overlay a 40 x 20 probe that records its taps and where its tap downs
/// land, in its own coordinates; the long press opens the context menu.
Future<InteractiveHost> mountInteractive(
    WidgetTester tester, FloorPlanController c) async {
  final host = InteractiveHost();
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: FloorPlanView(
        controller: c,
        onTableTap: host.tableTaps.add,
        onTableContextMenu: (n, _) => host.menus.add(n),
        longPress: FloorPlanLongPress.contextMenu,
        tableOverlayLayout: const FloorPlanOverlayLayout(interactive: true),
        tableOverlayBuilder: (context, table) {
          final n = table.detail.table.number!;
          return GestureDetector(
            key: ValueKey('probe-$n'),
            onTapDown: (d) => host.downs.add((n, d.localPosition)),
            onTap: () => host.badgeTaps.add(n),
            child: SizedBox.fromSize(
                size: Badge.size,
                child: const ColoredBox(color: Color(0xFF3060C0))),
          );
        },
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
  c.cameraController.value = embeddingCamera();
  await tester.pump();
  return host;
}

/// Table [n]'s centre in the world, as `tableDetails` reports it.
Offset? centerOf(FloorPlanController c, String n) =>
    c.tableDetails.firstWhere((d) => d.table.number == n).center;

/// A screen point on table [n], a quarter of its box's width from its
/// centre along its own x axis: on the table, off its centred badge.
Offset onTableOffBadge(WidgetTester tester, FloorPlanController c, String n) {
  final t = tableNumbered(n);
  final m = t.transform;
  final b = embeddingBox;
  final x = (b.minX + b.maxX) / 2 + (b.maxX - b.minX) / 4;
  final y = (b.minY + b.maxY) / 2;
  final p = canvasOf(c.cameraController.value, m.a * x + m.c * y + m.e,
      m.b * x + m.d * y + m.f);
  final at = canvasOrigin(tester) + Offset(p.x, p.y);
  final badge = tester.getRect(find.byKey(ValueKey('probe-$n')));
  expect(badge.contains(at), isFalse, reason: 'premise: off the badge');
  expect(c.tableAt(at - canvasOrigin(tester)), n, reason: 'premise: on $n');
  return at;
}

/// The layer's direct child holding probe [n], and its parent data.
RenderBox probeSlot(WidgetTester tester, String n) {
  RenderObject node = tester.renderObject(find.byKey(ValueKey('probe-$n')));
  while (node.parent is! RenderFloorPlanOverlays) {
    node = node.parent!;
  }
  return node as RenderBox;
}

FloorPlanOverlayParentData probeData(WidgetTester tester, String n) =>
    probeSlot(tester, n).parentData! as FloorPlanOverlayParentData;
