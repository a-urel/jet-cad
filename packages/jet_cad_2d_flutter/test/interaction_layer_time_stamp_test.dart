// Host embedding API spec E-2 and F-13: `ToolPointerEvent.timeStamp` is the
// raw pointer event's time, never the time the tool hears it. A finger's
// down held back by the layer (spec 14t T3) keeps its raw down's stamp
// whenever it is routed: at the hold-back, on leaving the slop, at the lift;
// a lift-mode tap's down carries the held down's stamp, its aiming hover the
// move's. Every stamp here is far from the fake clock's time (which starts
// at zero and is pumped by other amounts), so a stamp read from the clock,
// or the default zero, is told apart.
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kPrimaryButton, kTouchSlop;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// Records each routed call as `what stampInMs`, and the events.
class StampTool extends Tool {
  StampTool(this.touchPress);

  @override
  final TouchPress touchPress;

  final List<String> log = [];
  final List<ToolPointerEvent> events = [];
  ToolPhase _phase = ToolPhase.idle;

  void _add(String what, ToolPointerEvent e) {
    events.add(e);
    log.add('$what ${e.timeStamp.inMilliseconds}');
  }

  @override
  String get name => 'Stamps';
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
  void onPointerExit(ToolContext ctx) {}
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;
  @override
  void cancel(ToolContext ctx) => _phase = ToolPhase.idle;
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {}
}

Future<StampTool> pumpLayer(WidgetTester tester, TouchPress mode) async {
  final tool = StampTool(mode);
  final document = DraftDocument.empty();
  final camera = CameraController(ViewportTransform(
      worldToScreenMatrix: Transform2(0.1, 0, 0, -0.1, 150, 260)));
  final index = SpatialIndex(document);
  final selection = SelectionController(document);
  final tools = ToolController(
      initial: tool,
      context: ToolContext(
          document: document,
          index: index,
          camera: camera,
          selection: selection));
  addTearDown(() {
    tools.dispose();
    selection.dispose();
    index.dispose();
    camera.dispose();
    document.dispose();
  });
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 400,
        height: 300,
        child: InteractionLayer(tools: tools, child: const SizedBox.expand()),
      ),
    ),
  ));
  return tool;
}

Offset at(WidgetTester tester, Offset local) =>
    tester.getTopLeft(find.byType(InteractionLayer)) + local;

Duration ms(int n) => Duration(milliseconds: n);

void main() {
  test('TS0 a ToolPointerEvent built without a stamp reads Duration.zero', () {
    final e = ToolPointerEvent(
        screen: Offset.zero,
        world: Vector2.zero(),
        pointer: 1,
        buttons: kPrimaryButton,
        shift: false,
        control: false,
        meta: false,
        alt: false,
        pickRadiusWorld: 1);
    expect(e.timeStamp, Duration.zero);
  });

  testWidgets(
      'TS1 a mouse down, its moves, its up and a hover each carry their own '
      'raw event\'s stamp', (tester) async {
    final tool = await pumpLayer(tester, TouchPress.press);
    final hover = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await hover.addPointer(location: at(tester, const Offset(10, 10)));
    await hover.moveTo(at(tester, const Offset(20, 20)), timeStamp: ms(4321));
    await hover.removePointer();
    final g =
        await tester.createGesture(kind: PointerDeviceKind.mouse, pointer: 7);
    await g.down(at(tester, const Offset(100, 100)), timeStamp: ms(5000));
    await tester.pump(ms(17));
    await g.moveTo(at(tester, const Offset(140, 100)), timeStamp: ms(5040));
    await g.up(timeStamp: ms(5090));
    expect(tool.log, ['move 4321', 'down 5000', 'move 5040', 'up 5090']);
    expect(tool.events.first.buttons, 0, reason: 'premise: a hover');
  });

  testWidgets(
      'TS2 press mode: a finger held past kTouchHoldBack reaches the tool '
      'with its raw down\'s stamp, not the routing time', (tester) async {
    final tool = await pumpLayer(tester, TouchPress.press);
    final g = await tester.createGesture(pointer: 5);
    await g.down(at(tester, const Offset(200, 150)), timeStamp: ms(9000));
    await tester.pump(kTouchHoldBack + ms(30));
    expect(tool.log, ['down 9000'], reason: 'routed by the hold-back');
    await g.up(timeStamp: ms(9400));
    expect(tool.log, ['down 9000', 'up 9400']);
  });

  testWidgets(
      'TS3 press mode: a finger lifted before kTouchHoldBack, and one leaving '
      'the slop, reach the tool with the raw down\'s stamp', (tester) async {
    final tool = await pumpLayer(tester, TouchPress.press);
    final tap = await tester.createGesture(pointer: 5);
    await tap.down(at(tester, const Offset(200, 150)), timeStamp: ms(9000));
    await tester.pump(ms(20));
    await tap.up(timeStamp: ms(9050));
    expect(tool.log, ['down 9000', 'up 9050'], reason: 'routed at the lift');
    await tester.pump(ms(500));
    tool.log.clear();
    final drag = await tester.createGesture(pointer: 6);
    await drag.down(at(tester, const Offset(100, 100)), timeStamp: ms(12000));
    await tester.pump(ms(10));
    await drag.moveTo(at(tester, const Offset(100, 101 + kTouchSlop)),
        timeStamp: ms(12030));
    expect(tool.log, ['down 12000', 'move 12030'],
        reason: 'routed on leaving the slop');
    await drag.up(timeStamp: ms(12060));
    expect(tool.log.last, 'up 12060');
  });

  testWidgets(
      'TS4 lift mode: the aiming hover carries the move\'s stamp; the tap\'s '
      'down, at the lift\'s position, carries the held down\'s',
      (tester) async {
    final tool = await pumpLayer(tester, TouchPress.lift);
    final tap = await tester.createGesture(pointer: 5);
    await tap.down(at(tester, const Offset(120, 80)), timeStamp: ms(7000));
    await tap.moveTo(at(tester, const Offset(126, 80)), timeStamp: ms(7020));
    await tester.pump(ms(250));
    await tap.up(timeStamp: ms(7080));
    expect(tool.log, ['down 7000', 'up 7080']);
    expect(tool.events.first.screen, const Offset(126, 80),
        reason: 'premise: at the lift\'s position');
    await tester.pump(ms(500));
    tool.log.clear();
    final aim = await tester.createGesture(pointer: 6);
    await aim.down(at(tester, const Offset(100, 100)), timeStamp: ms(8000));
    await aim.moveTo(at(tester, const Offset(140, 110)), timeStamp: ms(8030));
    expect(tool.log, ['move 8030']);
    expect(tool.events.last.buttons, 0, reason: 'premise: an aiming hover');
    await aim.up(timeStamp: ms(8100));
    expect(tool.log, ['move 8030', 'down 8000', 'up 8100']);
  });
}
