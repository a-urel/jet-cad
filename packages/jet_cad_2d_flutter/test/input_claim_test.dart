// Host embedding API spec G-5 (Slice 1, Task 4): an InputClaim inside the
// canvas takes the pointers that go down on it, from the down to the up or
// cancel, away from both raw listeners -- the interaction layer (no tool
// hears them) and the camera gesture detector (no pan, no pinch finger) --
// while every pointer that goes down off it is the canvas's as before. A
// hover onto a claim is one exit for the tool; a wheel over a claim zooms
// unless something inside it registers for the signal first. The rig is
// the canvas's real nesting (detector, layer, stack), its camera off the
// identity (0.1 px/mm, y up, translated), and a recording tool sees exactly
// what the layer routes.
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// Records every call the layer makes.
class RecordingTool extends Tool {
  final List<String> log = [];
  ToolPhase _phase = ToolPhase.idle;

  void _add(String what, ToolPointerEvent e) => log
      .add('$what ${e.pointer} ${e.screen.dx.round()},${e.screen.dy.round()}');

  @override
  String get name => 'Recording';
  @override
  TouchPress get touchPress => TouchPress.press;
  @override
  ToolPhase get phase => _phase;
  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    _phase = ToolPhase.pressed;
    _add('down', e);
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) => _add('move', e);
  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {
    _phase = ToolPhase.idle;
    _add('up', e);
  }

  @override
  void onPointerExit(ToolContext ctx) => log.add('exit');
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;
  @override
  void cancel(ToolContext ctx) {
    _phase = ToolPhase.idle;
    log.add('cancel');
  }

  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {}

  /// The log without exits: the routing alone.
  List<String> get routed => log.where((l) => l != 'exit').toList();
}

/// The canvas's local rects (the rig is 400 x 300, its top left at
/// (200, 150) on the 800 x 600 surface).
const Rect kBadge = Rect.fromLTWH(40, 30, 80, 40); // a tappable claim
const Rect kScroller = Rect.fromLTWH(240, 30, 80, 40); // takes the wheel
const Rect kGap = Rect.fromLTWH(40, 200, 80, 40); // a claim that hits nothing
const Rect kPlain = Rect.fromLTWH(240, 200, 80, 40); // no recognizer at all
const Offset kFloor = Offset(180, 160); // on no claim
const Offset kTopLeft = Offset(200, 150);

final class Rig {
  Rig()
      : document = DraftDocument.empty(),
        camera = CameraController(ViewportTransform(
            worldToScreenMatrix: Transform2(0.1, 0, 0, -0.1, 150, 260))) {
    index = SpatialIndex(document);
    selection = SelectionController(document);
    tools = ToolController(
        initial: tool,
        context: ToolContext(
            document: document,
            index: index,
            camera: camera,
            selection: selection));
  }

  final RecordingTool tool = RecordingTool();
  final DraftDocument document;
  final CameraController camera;
  late final SpatialIndex index;
  late final SelectionController selection;
  late final ToolController tools;

  int badgeTaps = 0;
  final List<Offset> badgeDowns = [];
  int scrollerSignals = 0;

  void dispose() {
    tools.dispose();
    selection.dispose();
    index.dispose();
    camera.dispose();
    document.dispose();
  }
}

Future<Rig> pumpRig(WidgetTester tester) async {
  final rig = Rig();
  addTearDown(rig.dispose);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  Widget at(Rect r, Widget child) => Positioned.fromRect(rect: r, child: child);
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 400,
        height: 300,
        child: CameraGestureDetector(
          camera: rig.camera,
          policy: GesturePolicy.wheelZooms,
          child: InteractionLayer(
            tools: rig.tools,
            child: Stack(children: [
              const SizedBox.expand(),
              at(
                  kBadge,
                  InputClaim(
                    child: GestureDetector(
                      onTapDown: (d) => rig.badgeDowns.add(d.localPosition),
                      onTap: () => rig.badgeTaps++,
                      child: const ColoredBox(color: Color(0xFF3060C0)),
                    ),
                  )),
              at(
                  kScroller,
                  InputClaim(
                    child: Listener(
                      onPointerSignal: (e) => GestureBinding
                          .instance.pointerSignalResolver
                          .register(e, (_) => rig.scrollerSignals++),
                      child: const ColoredBox(color: Color(0xFF30C060)),
                    ),
                  )),
              // A claim around a box that paints and hits nothing.
              at(kGap, const InputClaim(child: SizedBox.expand())),
              at(
                  kPlain,
                  const InputClaim(
                      child: ColoredBox(color: Color(0xFFC06030)))),
            ]),
          ),
        ),
      ),
    ),
  ));
  return rig;
}

Offset g(Offset local) => kTopLeft + local;

Future<TestGesture> finger(WidgetTester tester, int pointer, Offset local) =>
    tester.startGesture(g(local),
        pointer: pointer, kind: PointerDeviceKind.touch);

Future<void> wheelUp(WidgetTester tester, Offset local) async {
  final p = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(p.hover(g(local)));
  await tester.sendEventToBinding(p.scroll(const Offset(0, -120)));
  await tester.pump();
}

void main() {
  testWidgets(
      'IC1 a mouse tap on a claim is the claim\'s: the badge hears it, no '
      'tool and no camera does; the claim ends with the pointer',
      (tester) async {
    final rig = await pumpRig(tester);
    final camera = rig.camera.value;
    await tester.tapAt(g(kBadge.center), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 500));
    expect(rig.badgeTaps, 1);
    // Where the badge was hit: its own coordinates, not the canvas's.
    expect(rig.badgeDowns, [kBadge.size.center(Offset.zero)]);
    expect(rig.tool.routed, isEmpty, reason: 'the tool heard a claimed tap');
    expect(identical(rig.camera.value, camera), isTrue);
    expect(RenderInputClaim.debugClaimedPointers, 0);
    // Off every claim, a tap is the tool's as before.
    await tester.tapAt(g(kFloor), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 500));
    expect(rig.tool.routed, [
      'down ${tester.nextPointer - 1} 180,160',
      'up ${tester.nextPointer - 1} 180,160'
    ]);
    expect(rig.badgeTaps, 1);
  });

  testWidgets(
      'IC2 the claim does not leak to the next pointer: the same id, down '
      'off the claim, is the tool\'s from down to up', (tester) async {
    final rig = await pumpRig(tester);
    await tester.tapAt(g(kBadge.center),
        pointer: 5, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 500));
    expect(rig.badgeTaps, 1);
    final drag = await tester.startGesture(g(kFloor),
        pointer: 5, kind: PointerDeviceKind.mouse);
    await drag.moveTo(g(kFloor + const Offset(30, 20)));
    await drag.up();
    expect(
        rig.tool.routed, ['down 5 180,160', 'move 5 210,180', 'up 5 210,180']);
    expect(RenderInputClaim.debugClaimedPointers, 0);
  });

  testWidgets(
      'IC3 a press-drag or a middle drag that starts on a claim moves '
      'nothing; one that starts off it is the canvas\'s across it',
      (tester) async {
    final rig = await pumpRig(tester);
    final camera = rig.camera.value;
    // Primary, from the claim across the floor.
    final a = await tester.startGesture(g(kBadge.center),
        kind: PointerDeviceKind.mouse);
    for (final p in const [Offset(100, 90), Offset(160, 140), kFloor]) {
      await a.moveTo(g(p));
    }
    await a.up();
    // Middle (the pan button), from the claim.
    final b = await tester.startGesture(g(kPlain.center),
        kind: PointerDeviceKind.mouse, buttons: kMiddleMouseButton);
    await b.moveTo(g(kPlain.center + const Offset(-40, -30)));
    await b.moveTo(g(kPlain.center + const Offset(-90, -50)));
    await b.up();
    expect(rig.tool.routed, isEmpty);
    expect(identical(rig.camera.value, camera), isTrue,
        reason: 'a drag that started on a claim moved the camera');
    // Middle, from the floor across the claim: it pans by the whole drag.
    final c = await tester.startGesture(g(kFloor),
        kind: PointerDeviceKind.mouse, buttons: kMiddleMouseButton);
    await c.moveTo(g(kPlain.center));
    await c.moveTo(g(kPlain.center + const Offset(10, 5)));
    await c.up();
    final pan = kPlain.center + const Offset(10, 5) - kFloor;
    final m = rig.camera.value.worldToScreenMatrix;
    expect(m.e, closeTo(150 + pan.dx, 1e-9));
    expect(m.f, closeTo(260 + pan.dy, 1e-9));
    // Primary, from the floor onto the claim: the tool's to its up.
    final d = await tester.startGesture(g(kFloor),
        pointer: 9, kind: PointerDeviceKind.mouse);
    await d.moveTo(g(kBadge.center));
    await d.up();
    expect(rig.tool.routed, ['down 9 180,160', 'move 9 80,50', 'up 9 80,50']);
    expect(rig.badgeTaps, 0);
  });

  testWidgets(
      'IC4 a finger tap on a claim reaches no tool, not even an exit; a '
      'long press there neither', (tester) async {
    final rig = await pumpRig(tester);
    final tap = await finger(tester, 3, kBadge.center);
    await tester.pump(const Duration(milliseconds: 50));
    await tap.up();
    await tester.pump(const Duration(milliseconds: 500));
    expect(rig.badgeTaps, 1);
    final hold = await finger(tester, 4, kPlain.center);
    await tester.pump(const Duration(seconds: 1));
    await hold.up();
    expect(rig.tool.log, isEmpty,
        reason: 'a claimed finger started or ended a touch session');
    // A finger off the claims is the tool's, as before.
    final floor = await finger(tester, 6, kFloor);
    await tester.pump(const Duration(milliseconds: 50));
    await floor.up();
    expect(rig.tool.log, ['down 6 180,160', 'up 6 180,160', 'exit']);
  });

  testWidgets(
      'IC5 a pinch with one finger on a claim does not count that finger, '
      'whichever lands first; two fingers on the floor pinch', (tester) async {
    final rig = await pumpRig(tester);
    final camera = rig.camera.value;
    // A finger on the claim, then one on the floor moving away from it:
    // a pinch of the two would zoom by the span's ratio.
    final onBadge = await finger(tester, 1, kBadge.center);
    final onFloor = await finger(tester, 2, const Offset(180, 110));
    for (final p in const [
      Offset(200, 124),
      Offset(226, 141),
      Offset(260, 170),
    ]) {
      await onFloor.moveTo(g(p));
    }
    expect(identical(rig.camera.value, camera), isTrue,
        reason: 'the claimed finger was one of a pinch');
    // The floor finger alone is a one-finger session: the tool's.
    expect(rig.tool.routed, [
      'down 2 180,110',
      'move 2 200,124',
      'move 2 226,141',
      'move 2 260,170',
    ]);
    await onFloor.up();
    await onBadge.up();
    rig.tool.log.clear();
    // The floor first, then the claim: the floor finger stays the tool's.
    final first = await finger(tester, 7, kFloor);
    final second = await finger(tester, 8, kPlain.center);
    await first.moveTo(g(kFloor + const Offset(40, 30)));
    await first.moveTo(g(kFloor + const Offset(70, 60)));
    await second.moveTo(g(kPlain.center + const Offset(30, 20)));
    expect(identical(rig.camera.value, camera), isTrue);
    expect(rig.tool.routed,
        ['down 7 180,160', 'move 7 220,190', 'move 7 250,220']);
    await first.up();
    await second.up();
    // The premise: two fingers on the floor do pinch in this rig.
    final p1 = await finger(tester, 10, const Offset(150, 120));
    final p2 = await finger(tester, 11, const Offset(200, 150));
    await p2.moveTo(g(const Offset(300, 180)));
    expect(
        rig.camera.value.scale / camera.scale,
        closeTo(
            (const Offset(300, 180) - const Offset(150, 120)).distance /
                (const Offset(200, 150) - const Offset(150, 120)).distance,
            1e-9));
    await p1.up();
    await p2.up();
    expect(RenderInputClaim.debugClaimedPointers, 0);
  });

  testWidgets(
      'IC6 a hover onto a claim is one exit for the tool; back on the floor '
      'it is a move again', (tester) async {
    final rig = await pumpRig(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: g(kFloor));
    await mouse.moveTo(g(kFloor + const Offset(10, 0)));
    await mouse.moveTo(g(kBadge.center));
    await mouse.moveTo(g(kBadge.center + const Offset(5, 5)));
    await mouse.moveTo(g(kPlain.center));
    await mouse.moveTo(g(kFloor));
    await mouse.moveTo(g(kPlain.center));
    final id =
        rig.tool.log.isEmpty ? -1 : int.parse(rig.tool.log.first.split(' ')[1]);
    expect(rig.tool.log, [
      'move $id 190,160',
      'exit',
      'move $id 180,160',
      'exit',
    ]);
    await mouse.removePointer();
  });

  testWidgets(
      'IC7 a wheel over a claim zooms as off it, unless the claim registers '
      'for the signal first', (tester) async {
    final rig = await pumpRig(tester);
    final scale = rig.camera.value.scale;
    await wheelUp(tester, kFloor);
    expect(rig.camera.value.scale / scale, closeTo(1.1, 1e-9));
    // Over a claim that takes no wheel: zoomed again, about the pointer.
    final under = rig.camera.value
        .screenToWorld(Vector2(kBadge.center.dx, kBadge.center.dy));
    await wheelUp(tester, kBadge.center);
    expect(rig.camera.value.scale / scale, closeTo(1.21, 1e-9));
    final still = rig.camera.value
        .screenToWorld(Vector2(kBadge.center.dx, kBadge.center.dy));
    expect(still.x, closeTo(under.x, 1e-9));
    expect(still.y, closeTo(under.y, 1e-9));
    // Over the claim that registers: it alone has the signal.
    final camera = rig.camera.value;
    await wheelUp(tester, kScroller.center);
    expect(rig.scrollerSignals, 1);
    expect(identical(rig.camera.value, camera), isTrue,
        reason: 'the camera zoomed under a claim that took the wheel');
  });

  testWidgets(
      'IC8 a claim is hit only where its child is: a gap is the '
      'canvas\'s', (tester) async {
    final rig = await pumpRig(tester);
    await tester.tapAt(g(kGap.center), kind: PointerDeviceKind.mouse);
    final id = tester.nextPointer - 1;
    expect(rig.tool.routed, ['down $id 80,220', 'up $id 80,220']);
  });

  testWidgets(
      'IC9 a claimed pointer whose up never came (the binding reset) does '
      'not claim the next down on its id', (tester) async {
    final rig = await pumpRig(tester);
    final before = RenderInputClaim.debugClaimedPointers;
    final lost = await tester.startGesture(g(kPlain.center),
        pointer: 41, kind: PointerDeviceKind.mouse);
    expect(RenderInputClaim.debugClaimedPointers, before + 1);
    // What flutter_test's binding does between tests: the down's hit test
    // is forgotten and its up never comes.
    // ignore: invalid_use_of_protected_member
    tester.binding.resetGestureBinding();
    final next = await tester.startGesture(g(kFloor),
        pointer: 41, kind: PointerDeviceKind.mouse);
    await next.moveTo(g(kFloor + const Offset(20, 10)));
    await next.up();
    expect(rig.tool.routed,
        ['down 41 180,160', 'move 41 200,170', 'up 41 200,170']);
    expect(RenderInputClaim.debugClaimedPointers, before);
    expect(lost, isNotNull);
  });
}
