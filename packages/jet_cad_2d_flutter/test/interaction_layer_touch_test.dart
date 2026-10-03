// Spec 14t T3, R-1, R-9, R-10: touch sessions in the interaction layer --
// the first finger held back (press and lift modes), a second finger taking
// the gesture away from the tool until every finger lifts, no promotion and
// no hover for a finger, the session cleared with the layer. A recording
// tool sees exactly what the layer routes. The camera is off the identity
// (0.1 px/mm, y up, translated), so a world point read back proves the
// camera used.
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kPrimaryButton, kTouchSlop;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// Records every call the layer makes, with the event's essentials.
class RecordingTool extends Tool {
  RecordingTool(this.touchPress, {this.pressPhase = ToolPhase.pressed});

  @override
  final TouchPress touchPress;

  /// The phase reported between a down and its up.
  final ToolPhase pressPhase;

  final List<String> log = [];
  final List<ToolPointerEvent> events = [];
  ToolPhase _phase = ToolPhase.idle;

  void _add(String what, ToolPointerEvent e) {
    events.add(e);
    log.add('$what ${e.pointer} ${e.screen.dx.round()},${e.screen.dy.round()}'
        ' b${e.buttons}');
  }

  @override
  String get name => 'Recording';
  @override
  ToolPhase get phase => _phase;
  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    _phase = pressPhase;
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
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport) {}

  /// The log without exits, for the routing alone.
  List<String> get routed => log.where((l) => l != 'exit').toList();
}

final class Rig {
  Rig(this.tool)
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

  final RecordingTool tool;
  final DraftDocument document;
  final CameraController camera;
  late final SpatialIndex index;
  late final SelectionController selection;
  late final ToolController tools;

  void dispose() {
    tools.dispose();
    selection.dispose();
    index.dispose();
    camera.dispose();
    document.dispose();
  }
}

Future<Rig> pumpLayer(WidgetTester tester, TouchPress mode,
    {ToolPhase pressPhase = ToolPhase.pressed}) async {
  final rig = Rig(RecordingTool(mode, pressPhase: pressPhase));
  addTearDown(rig.dispose);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 400,
        height: 300,
        child: InteractionLayer(
          tools: rig.tools,
          child: const SizedBox.expand(),
        ),
      ),
    ),
  ));
  return rig;
}

Offset at(WidgetTester tester, Offset local) =>
    tester.getTopLeft(find.byType(InteractionLayer)) + local;

Future<TestGesture> finger(WidgetTester tester, int pointer, Offset local) =>
    tester.startGesture(at(tester, local),
        pointer: pointer, kind: PointerDeviceKind.touch);

FocusNode layerFocus(WidgetTester tester) => tester
    .widget<Focus>(find
        .descendant(
            of: find.byType(InteractionLayer), matching: find.byType(Focus))
        .first)
    .focusNode!;

const Duration kPast = Duration(milliseconds: 200);

void main() {
  testWidgets(
      'TL1 press mode: a tap is a down at the down\'s position, then the up; '
      'nothing more after (M-14t-6, -23)', (tester) async {
    final r = await pumpLayer(tester, TouchPress.press);
    final g = await finger(tester, 5, const Offset(120, 80));
    await tester.pump(const Duration(milliseconds: 40));
    await g.moveTo(at(tester, const Offset(132, 80)));
    await g.up();
    await tester.pump(kPast);
    expect(r.tool.routed, ['down 5 120,80 b1', 'up 5 132,80 b0']);
    final down = r.tool.events.first;
    expect(down.isTouch, isTrue);
    // (120, 80) through the camera: ((120 - 150) / 0.1, (80 - 260) / -0.1).
    expect(down.world.x, closeTo(-300, 1e-9));
    expect(down.world.y, closeTo(1800, 1e-9));
    expect(down.pickRadiusWorld, closeTo(60, 1e-9), reason: '6 px');
    expect(down.reachRadiusWorld, closeTo(240, 1e-9), reason: '24 px');
    expect(r.tool.log.last, 'exit', reason: 'a finger has no hover (R-10)');
  });

  testWidgets(
      'TL2 lift mode: a tap is a down and an up at the lift\'s position '
      '(M-14t-6)', (tester) async {
    final r = await pumpLayer(tester, TouchPress.lift);
    final g = await finger(tester, 5, const Offset(120, 80));
    await g.moveTo(at(tester, const Offset(132, 80)));
    await tester.pump(kPast);
    expect(r.tool.log, isEmpty, reason: 'never on a timeout');
    await g.up();
    await tester.pump(kPast);
    expect(r.tool.routed, ['down 5 132,80 b1', 'up 5 132,80 b0']);
  });

  testWidgets(
      'TL3 press mode: a finger held still is routed after kTouchHoldBack, '
      'and focus moves only then (R-9c)', (tester) async {
    final r = await pumpLayer(tester, TouchPress.press);
    final focus = layerFocus(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final g = await finger(tester, 5, const Offset(200, 150));
    await tester.pump(kTouchHoldBack - const Duration(milliseconds: 1));
    expect(r.tool.log, isEmpty);
    expect(FocusManager.instance.primaryFocus, isNot(same(focus)));
    await tester.pump(const Duration(milliseconds: 2));
    expect(r.tool.routed, ['down 5 200,150 b1']);
    expect(FocusManager.instance.primaryFocus, same(focus));
    await g.moveTo(at(tester, const Offset(203, 150)));
    await g.up();
    expect(r.tool.routed,
        ['down 5 200,150 b1', 'move 5 203,150 b1', 'up 5 203,150 b0']);
  });

  testWidgets(
      'TL4 press mode: within the slop nothing; past it the down, then the '
      'move', (tester) async {
    final r = await pumpLayer(tester, TouchPress.press);
    final g = await finger(tester, 5, const Offset(100, 100));
    await g.moveTo(at(tester, const Offset(100 + kTouchSlop, 100)));
    expect(r.tool.log, isEmpty, reason: 'exactly the slop');
    await g.moveTo(at(tester, const Offset(100, 100 + kTouchSlop + 1)));
    expect(r.tool.routed, ['down 5 100,100 b1', 'move 5 100,119 b1']);
    await g.up();
    await tester.pump(kPast);
    expect(r.tool.routed.where((l) => l.startsWith('down')), hasLength(1));
  });

  testWidgets(
      'TL5 lift mode: past the slop the finger hovers; it never presses '
      'until it lifts', (tester) async {
    final r = await pumpLayer(tester, TouchPress.lift);
    final g = await finger(tester, 5, const Offset(100, 100));
    await g.moveTo(at(tester, const Offset(130, 110)));
    await g.moveTo(at(tester, const Offset(150, 120)));
    await tester.pump(kPast);
    expect(r.tool.routed, ['move 5 130,110 b0', 'move 5 150,120 b0']);
    await g.up();
    expect(r.tool.routed.sublist(2), ['down 5 150,120 b1', 'up 5 150,120 b0']);
  });

  for (final mode in TouchPress.values) {
    testWidgets(
        'TL6 ${mode.name} mode: a pinch never reaches the tool; a tap after '
        'it does (M-14t-5, -22)', (tester) async {
      final r = await pumpLayer(tester, mode);
      final a = await finger(tester, 1, const Offset(100, 100));
      await tester.pump(const Duration(milliseconds: 60));
      final b = await finger(tester, 2, const Offset(300, 200));
      for (var i = 1; i <= 4; i++) {
        await a.moveTo(at(tester, Offset(100.0 - 10 * i, 100.0 - 5 * i)));
        await b.moveTo(at(tester, Offset(300.0 + 12 * i, 200.0 + 3 * i)));
      }
      await tester.pump(kPast);
      await a.up();
      await b.moveTo(at(tester, const Offset(250, 150)));
      await b.up();
      await tester.pump(kPast);
      expect(r.tool.routed, isEmpty);
      expect(r.tool.log, contains('exit'));

      final c = await finger(tester, 3, const Offset(60, 40));
      await c.up();
      expect(r.tool.routed, [
        'down 3 60,40 b1',
        'up 3 60,40 b0',
      ]);
    });
  }

  testWidgets(
      'TL7 a second finger cancels a routed press, and the rest of the '
      'session reaches nothing (M-14t-7, layer side)', (tester) async {
    final r = await pumpLayer(tester, TouchPress.press);
    final a = await finger(tester, 1, const Offset(100, 100));
    await a.moveTo(at(tester, const Offset(140, 100)));
    expect(r.tool.routed, ['down 1 100,100 b1', 'move 1 140,100 b1']);
    final b = await finger(tester, 2, const Offset(300, 200));
    expect(r.tool.log.sublist(2), ['cancel', 'exit']);
    expect(r.tool.phase, ToolPhase.idle);
    await a.moveTo(at(tester, const Offset(160, 100)));
    await a.up();
    await b.moveTo(at(tester, const Offset(260, 200)));
    await b.up();
    expect(r.tool.routed, ['down 1 100,100 b1', 'move 1 140,100 b1', 'cancel'],
        reason: 'nothing after the second finger');
  });

  testWidgets(
      'TL8 an idle tool is not cancelled by a second finger: a drawing '
      'tool\'s shape survives a pinch (M-14t-20, layer side)', (tester) async {
    final r =
        await pumpLayer(tester, TouchPress.press, pressPhase: ToolPhase.idle);
    final a = await finger(tester, 1, const Offset(100, 100));
    await tester.pump(kPast);
    expect(r.tool.routed, ['down 1 100,100 b1']);
    final b = await finger(tester, 2, const Offset(300, 200));
    await a.up();
    await b.up();
    expect(r.tool.log, isNot(contains('cancel')));
  });

  testWidgets(
      'TL9 after a pinch, one finger lifted and a new one tapped: the tool '
      'sees nothing until every finger lifts (14c F-10, M-14t-8, -9)',
      (tester) async {
    final r = await pumpLayer(tester, TouchPress.press);
    final a = await finger(tester, 1, const Offset(100, 100));
    final b = await finger(tester, 2, const Offset(300, 200));
    await a.up();
    await b.moveTo(at(tester, const Offset(200, 120)));
    await tester.pump(kPast);
    final c = await finger(tester, 3, const Offset(50, 50));
    await tester.pump(kPast);
    await c.moveTo(at(tester, const Offset(90, 50)));
    await c.up();
    await b.moveTo(at(tester, const Offset(180, 120)));
    expect(r.tool.routed, isEmpty);
    await b.up();
    final d = await finger(tester, 4, const Offset(70, 70));
    await d.up();
    expect(r.tool.routed, ['down 4 70,70 b1', 'up 4 70,70 b0']);
  });

  testWidgets(
      'TL10 a touch hover is never routed; a mouse hover is (TS-3, '
      'M-14t-10)', (tester) async {
    final r = await pumpLayer(tester, TouchPress.press);
    final touch =
        await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 0);
    await touch.addPointer(location: at(tester, const Offset(10, 10)));
    await touch.moveTo(at(tester, const Offset(40, 40)));
    expect(r.tool.log, isEmpty);
    final mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse, pointer: 9);
    await mouse.addPointer(location: at(tester, const Offset(10, 10)));
    await mouse.moveTo(at(tester, const Offset(40, 40)));
    expect(r.tool.routed, ['move 9 40,40 b0']);
    await mouse.removePointer();
    await touch.removePointer();
  });

  testWidgets(
      'TL11 a held finger never reaches a tool after the layer leaves, nor '
      'after the tool changes (M-14t-14, R-9b)', (tester) async {
    final r = await pumpLayer(tester, TouchPress.press);
    final g = await finger(tester, 1, const Offset(100, 100));
    final next = RecordingTool(TouchPress.press);
    addTearDown(next.dispose);
    r.tools.activate(next);
    await tester.pump(kPast);
    expect(r.tool.routed, ['cancel'], reason: 'activate\'s own; no down');
    expect(next.routed, isEmpty);
    await g.moveTo(at(tester, const Offset(160, 130)));
    await g.up();
    expect(next.routed, isEmpty,
        reason: 'that finger was dropped: never promoted (M-14t-9)');

    final h = await finger(tester, 2, const Offset(100, 100));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(kPast);
    expect(next.routed.where((l) => !l.startsWith('cancel')), isEmpty,
        reason: 'the leaving layer cancels; it routes no down');
    await h.up();
  });

  testWidgets(
      'TL12 a mouse and a stylus press are routed at once (M-14t-16, -25)',
      (tester) async {
    final r = await pumpLayer(tester, TouchPress.press);
    for (final (kind, p) in [
      (PointerDeviceKind.mouse, 7),
      (PointerDeviceKind.stylus, 8),
    ]) {
      final g = await tester.createGesture(
          kind: kind, pointer: p, buttons: kPrimaryButton);
      await g.down(at(tester, const Offset(150, 150)));
      expect(r.tool.routed.last, 'down $p 150,150 b1', reason: kind.name);
      expect(r.tool.events.last.reachRadiusWorld,
          r.tool.events.last.pickRadiusWorld);
      await g.up();
    }
  });

  testWidgets(
      'TL13 a held finger\'s cancel reaches nothing; a routed finger\'s '
      'cancels the tool (M-14t-24)', (tester) async {
    final r = await pumpLayer(tester, TouchPress.press);
    final a = await finger(tester, 1, const Offset(100, 100));
    await a.cancel();
    await tester.pump(kPast);
    expect(r.tool.routed, isEmpty);
    final b = await finger(tester, 2, const Offset(100, 100));
    await tester.pump(kPast);
    await b.cancel();
    expect(r.tool.routed, ['down 2 100,100 b1', 'cancel']);
  });

  testWidgets('TL14 no mouse is routed while a finger is held (R-9a)',
      (tester) async {
    final r = await pumpLayer(tester, TouchPress.press);
    final a = await finger(tester, 1, const Offset(100, 100));
    final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse, pointer: 9, buttons: kPrimaryButton);
    await mouse.down(at(tester, const Offset(200, 200)));
    await mouse.up();
    expect(r.tool.routed, isEmpty);
    await a.up();
    expect(r.tool.routed, ['down 1 100,100 b1', 'up 1 100,100 b0']);
  });

  testWidgets(
      'TL15 a finger while a mouse is pressed reaches nothing; the mouse '
      'keeps its press (T3)', (tester) async {
    final r = await pumpLayer(tester, TouchPress.press);
    final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse, pointer: 9, buttons: kPrimaryButton);
    await mouse.down(at(tester, const Offset(200, 200)));
    final a = await finger(tester, 1, const Offset(100, 100));
    await tester.pump(kPast);
    await a.up();
    await mouse.up();
    expect(r.tool.routed, ['down 9 200,200 b1', 'up 9 200,200 b0']);
  });
}
