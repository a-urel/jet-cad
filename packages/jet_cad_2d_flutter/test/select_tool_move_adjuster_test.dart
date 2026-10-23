// The Select tool's move adjuster seam (alignment guides spec, C-8): a body
// move's target, after the snap chain, is replaced by what the adjuster
// writes; the tool tells it when a move begins and ends, re-targets when its
// `changes` fires, and keeps its touch and Alt state across a camera pan or a
// key. The scene is two rectangles off the origin and a node, under a camera
// at scale 2 turned 30 degrees, y up.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ChangeNotifier, Listenable;
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/canvas_palette.dart';
import 'package:jet_cad_2d_flutter/src/grip_drag.dart' show DragKind;
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart'
    show kPickRadiusPixels;
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/grip_fixture.dart';
import 'support/selection_fixture.dart';

typedef Adjust = ({
  Vector2 raw,
  Vector2 base,
  Vector2? orthoBase,
  bool objectSnapped,
  bool touch,
  bool alt,
  Vector2 target,
});

final class _Changes extends ChangeNotifier {
  void fire() => notifyListeners();
  bool get listened => hasListeners;
}

/// Records every call, and offsets the target by (+3, -2).
final class FakeAdjuster implements MoveAdjuster {
  FakeAdjuster({this.offset = true});

  final bool offset;
  final List<Set<Handle>> begins = [];
  final List<Adjust> adjusts = [];
  int ends = 0, suppresses = 0, paints = 0;
  final _Changes _changes = _Changes();

  void fire() => _changes.fire();
  bool get listened => _changes.listened;

  @override
  Listenable get changes => _changes;

  @override
  void begin(ToolContext ctx, Set<Handle> moving) => begins.add({...moving});

  @override
  void adjust(ToolContext ctx,
      {required Vector2 raw,
      required Vector2 base,
      required Vector2? orthoBase,
      required bool objectSnapped,
      required bool touch,
      required bool alt,
      required Vector2 target}) {
    adjusts.add((
      raw: raw.clone(),
      base: base.clone(),
      orthoBase: orthoBase?.clone(),
      objectSnapped: objectSnapped,
      touch: touch,
      alt: alt,
      target: target.clone(),
    ));
    if (offset) {
      target.x += 3;
      target.y -= 2;
    }
  }

  @override
  void suppress() => suppresses++;

  @override
  void paint(ui.Canvas canvas, ViewportTransform camera, ui.Size viewport,
          PaperPalette paper) =>
      paints++;

  @override
  void end() => ends++;
}

/// Answers a fixed transform while [attach] is true.
final class FlipResolver implements MoveResolver {
  bool attach = true;

  @override
  ({Transform2 transform, Vector2 marker})? resolveMove(
      ToolContext ctx, Handle node, Transform2 delta) {
    if (!attach) return null;
    return (
      transform: Transform2.translation(7611, 3377)
          .multiply(Transform2.rotation(70 * math.pi / 180)),
      marker: Vector2(7620.5, 3380.25),
    );
  }
}

final class Scene {
  Scene({
    required this.adjuster,
    bool objectSnap = false,
    MoveResolver? resolver,
  }) {
    final doc = DraftDocument.empty();
    final root = doc.rootHandle;
    a = addEntity(doc, root, EntityKind.polyline,
        [7010, 3020, 7110, 3020, 7110, 3070, 7010, 3070, 7010, 3020], []);
    b = addEntity(doc, root, EntityKind.polyline,
        [7300, 3000, 7400, 3000, 7400, 3100, 7300, 3100, 7300, 3000], []);
    final def = addDefinition(doc, 'Def');
    addEntity(doc, def, EntityKind.line, [0, 0, 100, 0], []);
    node = addInstance(doc, def, Transform2.translation(7500, 3300));
    doc.commands.clearHistory();
    rig = gripRig(doc,
        camera: gripCamera(scale: 2, rotation: 30 * math.pi / 180),
        objectSnap: objectSnap);
    tool = SelectTool(moveAdjuster: adjuster, moveResolver: resolver);
    addTearDown(tool.dispose);
    rig.tools.activate(tool);
    // Teardown order: the rig's own dispose is registered first and runs
    // last; leave the tool before it goes.
    addTearDown(() => rig.tools.activate(rig.tool));
  }

  final FakeAdjuster? adjuster;
  late final Handle a, b, node;
  late final GripRig rig;
  late final SelectTool tool;

  ToolContext get ctx => rig.context;
  DraftDocument get doc => rig.document;

  /// The screen point of world ([x], [y]).
  ui.Offset at(double x, double y) => screenOf(rig.camera, x, y);

  ToolPointerEvent ev(ui.Offset s,
          {int buttons = kPrimaryButton,
          bool shift = false,
          bool alt = false,
          bool touch = false}) =>
      ToolPointerEvent(
        screen: s,
        world: rig.camera.value.screenToWorld(Vector2(s.dx, s.dy)),
        pointer: 1,
        buttons: buttons,
        shift: shift,
        control: false,
        meta: false,
        alt: alt,
        pickRadiusWorld: kPickRadiusPixels / rig.camera.value.scale,
        kind: touch ? PointerDeviceKind.touch : PointerDeviceKind.mouse,
      );

  void down(ui.Offset s, {bool touch = false}) =>
      tool.onPointerDown(ev(s, touch: touch), ctx);

  void move(ui.Offset s,
          {bool shift = false, bool alt = false, bool touch = false}) =>
      tool.onPointerMove(ev(s, shift: shift, alt: alt, touch: touch), ctx);

  void up(ui.Offset s,
          {bool shift = false, bool alt = false, bool touch = false}) =>
      tool.onPointerUp(
          ev(s, buttons: 0, shift: shift, alt: alt, touch: touch), ctx);

  /// Select rectangle A and press on the middle of its bottom edge.
  void pressA({bool touch = false}) {
    rig.selection.replace([SelectionKey.root(a)]);
    down(at(7060, 3020), touch: touch);
  }
}

Scene scene(
        {FakeAdjuster? adjuster,
        bool objectSnap = false,
        MoveResolver? resolver}) =>
    Scene(
        adjuster: adjuster ?? FakeAdjuster(),
        objectSnap: objectSnap,
        resolver: resolver);

KeyEvent altDown() => const KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.altLeft,
    logicalKey: LogicalKeyboardKey.altLeft,
    timeStamp: Duration.zero);
KeyEvent altUp() => const KeyUpEvent(
    physicalKey: PhysicalKeyboardKey.altLeft,
    logicalKey: LogicalKeyboardKey.altLeft,
    timeStamp: Duration.zero);
KeyEvent altRepeat() => const KeyRepeatEvent(
    physicalKey: PhysicalKeyboardKey.altLeft,
    logicalKey: LogicalKeyboardKey.altLeft,
    timeStamp: Duration.zero);
KeyEvent shiftDown() => const KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.shiftLeft,
    logicalKey: LogicalKeyboardKey.shiftLeft,
    timeStamp: Duration.zero);
KeyEvent escape() => const KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.escape,
    logicalKey: LogicalKeyboardKey.escape,
    timeStamp: Duration.zero);

List<double> coordsOf(Scene s, Handle h) => payloadOf(s.doc, h).coords.toList();

void main() {
  test(
      'MA1 begin once with the drag\'s handles before the first adjust; end '
      'once on release', () {
    final fake = FakeAdjuster();
    final s = scene(adjuster: fake);
    s.pressA();
    expect(fake.begins, isEmpty, reason: 'a press inside the slop');
    s.move(s.at(7100, 3045));
    expect(fake.begins, [
      {s.a}
    ]);
    expect(fake.adjusts, isNotEmpty, reason: 'the first target is adjusted');
    s.move(s.at(7105, 3050));
    expect(fake.begins, hasLength(1));
    expect(fake.ends, 0);
    s.up(s.at(7105, 3050));
    expect(fake.ends, 1);
    expect(fake.begins, hasLength(1));
  });

  test('MA2 end once on Escape-cancel, and nothing moves', () {
    final fake = FakeAdjuster();
    final s = scene(adjuster: fake);
    final before = coordsOf(s, s.a);
    s.pressA();
    s.move(s.at(7100, 3045));
    expect(s.tool.onKey(escape(), s.ctx), KeyEventResult.handled);
    expect(fake.ends, 1);
    expect(coordsOf(s, s.a), before);
    // A later drag does not hear the dead one's listener.
    final calls = fake.adjusts.length;
    fake.fire();
    expect(fake.adjusts, hasLength(calls));
  });

  test('MA3 a rotate and a reshape drag never begin or end the adjuster', () {
    final fake = FakeAdjuster();
    final s = scene(adjuster: fake);
    s.rig.selection.replace([SelectionKey.root(s.a)]);
    // Reshape: press a vertex grip of A.
    s.down(s.at(7110, 3070));
    s.move(s.at(7130, 3100));
    expect(s.tool.dragKind, DragKind.reshape);
    s.up(s.at(7130, 3100));
    // Rotate: the rotation grip.
    s.rig.selection.replace([SelectionKey.root(s.a)]);
    final grip = rotationGripNow(s.rig);
    s.down(grip);
    s.move(grip + const ui.Offset(30, 10));
    expect(s.tool.dragKind, DragKind.rotate);
    s.tool.cancel(s.ctx);
    expect(fake.begins, isEmpty);
    expect(fake.ends, 0);
    expect(fake.adjusts, isEmpty);
    fake.fire();
    expect(fake.adjusts, isEmpty);
  });

  test('MA4 the committed move is the chain delta plus the adjustment', () {
    final fake = FakeAdjuster();
    final s = scene(adjuster: fake);
    final before = coordsOf(s, s.a);
    s.pressA();
    s.move(s.at(7100, 3045));
    final t = s.tool.selectionPreviewTransform!;
    // The press is (7060, 3020); the pointer (7100, 3045): delta (40, 25).
    expect(t.e, closeTo(43, 1e-9));
    expect(t.f, closeTo(23, 1e-9));
    s.up(s.at(7100, 3045));
    final after = coordsOf(s, s.a);
    for (var i = 0; i < before.length; i += 2) {
      expect(after[i], closeTo(before[i] + 43, 1e-9));
      expect(after[i + 1], closeTo(before[i + 1] + 23, 1e-9));
    }
    expect(s.doc.commands.undoDepth, 1);
  });

  test('MA5 orthoBase is non-null only while Shift pins an axis', () {
    final fake = FakeAdjuster();
    final s = scene(adjuster: fake);
    s.pressA();
    s.move(s.at(7100, 3045));
    expect(fake.adjusts.last.orthoBase, isNull);
    s.move(s.at(7102, 3047), shift: true);
    final shifted = fake.adjusts.last;
    expect(shifted.orthoBase, isNotNull);
    expect(shifted.orthoBase!.x, closeTo(shifted.base.x, 1e-9));
    expect(shifted.orthoBase!.y, closeTo(shifted.base.y, 1e-9));
    expect(shifted.base.x, closeTo(7060, 1e-9));
    expect(shifted.base.y, closeTo(3020, 1e-9));
    s.move(s.at(7104, 3049));
    expect(fake.adjusts.last.orthoBase, isNull);
    s.tool.cancel(s.ctx);
  });

  test('MA6 objectSnapped is true on an object snap, false off one', () {
    final fake = FakeAdjuster();
    final s = scene(adjuster: fake, objectSnap: true);
    s.pressA();
    s.move(s.at(7100, 3045));
    expect(fake.adjusts.last.objectSnapped, isFalse);
    // B's lower-left corner.
    s.move(s.at(7300, 3000));
    final on = fake.adjusts.last;
    expect(on.objectSnapped, isTrue);
    expect(on.target.x, closeTo(7300, 1e-9), reason: 'the chain\'s point');
    expect(on.target.y, closeTo(3000, 1e-9));
    s.tool.cancel(s.ctx);
  });

  test('MA7 touch is true for a finger, alt for an Alt-held pointer', () {
    final fake = FakeAdjuster();
    final s = scene(adjuster: fake);
    s.pressA();
    s.move(s.at(7100, 3045));
    expect(fake.adjusts.last.touch, isFalse);
    expect(fake.adjusts.last.alt, isFalse);
    s.move(s.at(7101, 3046), alt: true);
    expect(fake.adjusts.last.alt, isTrue);
    expect(fake.adjusts.last.touch, isFalse);
    s.tool.cancel(s.ctx);

    final fake2 = FakeAdjuster();
    final t = scene(adjuster: fake2);
    t.pressA(touch: true);
    t.move(t.at(7100, 3045), touch: true);
    expect(t.tool.dragKind, DragKind.move);
    expect(fake2.adjusts.last.touch, isTrue);
    expect(fake2.adjusts.last.alt, isFalse);
    t.tool.cancel(t.ctx);
  });

  test('MA8 Alt pressed or released with no pointer move re-adjusts', () {
    final fake = FakeAdjuster();
    final s = scene(adjuster: fake);
    s.pressA();
    s.move(s.at(7100, 3045), alt: false);
    final n = fake.adjusts.length;
    final raw = fake.adjusts.last.raw;
    s.tool.onKey(altDown(), s.ctx);
    expect(fake.adjusts, hasLength(n + 1));
    expect(fake.adjusts.last.alt, isTrue);
    expect(fake.adjusts.last.raw.x, closeTo(raw.x, 1e-9));
    expect(fake.adjusts.last.raw.y, closeTo(raw.y, 1e-9));
    s.tool.onKey(altRepeat(), s.ctx);
    expect(fake.adjusts, hasLength(n + 1), reason: 'a repeat is not a change');
    s.tool.onKey(altUp(), s.ctx);
    expect(fake.adjusts, hasLength(n + 2));
    expect(fake.adjusts.last.alt, isFalse);
    s.tool.cancel(s.ctx);
  });

  test('MA9 a key-down in a drag is still the drag\'s after Alt', () {
    final fake = FakeAdjuster();
    final s = scene(adjuster: fake);
    s.pressA();
    s.move(s.at(7100, 3045));
    expect(s.tool.onKey(altDown(), s.ctx), KeyEventResult.handled);
    s.tool.cancel(s.ctx);
  });

  test('MA10 a camera pan mid-drag keeps the stored touch and Alt', () {
    final fake = FakeAdjuster();
    final s = scene(adjuster: fake);
    s.pressA(touch: true);
    s.move(s.at(7100, 3045), touch: true, alt: true);
    final n = fake.adjusts.length;
    s.rig.camera.panBy(const ui.Offset(7, -5));
    expect(fake.adjusts, hasLength(n + 1));
    expect(fake.adjusts.last.touch, isTrue);
    expect(fake.adjusts.last.alt, isTrue);
    s.tool.cancel(s.ctx);
  });

  test(
      'MA11 a resolver that attaches suppresses the adjuster and hides its '
      'paint', () {
    final fake = FakeAdjuster();
    final resolver = FlipResolver()..attach = false;
    final s = scene(adjuster: fake, resolver: resolver);
    s.rig.selection.replace([SelectionKey.root(s.node)]);
    s.down(s.at(7550, 3300));
    s.move(s.at(7560, 3310));
    expect(s.tool.dragKind, DragKind.move);
    expect(fake.suppresses, 0);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const size = ui.Size(800, 600);
    s.tool.paintOverlay(canvas, s.rig.camera.value, size, PaperPalette.light);
    expect(fake.paints, 1, reason: 'a plain move paints the adjuster');

    resolver.attach = true;
    s.move(s.at(7570, 3320));
    expect(fake.suppresses, 1);
    final before = fake.paints;
    s.tool.paintOverlay(canvas, s.rig.camera.value, size, PaperPalette.light);
    expect(fake.paints, before, reason: 'an attached move paints nothing');
    recorder.endRecording();
    s.tool.cancel(s.ctx);
  });

  test('MA12 the changes listener re-targets mid-drag, and not after the drag',
      () {
    final fake = FakeAdjuster();
    final s = scene(adjuster: fake);
    s.pressA();
    s.move(s.at(7100, 3045));
    expect(fake.listened, isTrue);
    final n = fake.adjusts.length;
    final raw = fake.adjusts.last.raw;
    fake.fire();
    expect(fake.adjusts, hasLength(n + 1));
    expect(fake.adjusts.last.raw.x, closeTo(raw.x, 1e-9));
    s.up(s.at(7100, 3045));
    expect(fake.listened, isFalse, reason: 'the listener left at the end');
    final m = fake.adjusts.length;
    fake.fire();
    expect(fake.adjusts, hasLength(m), reason: 'the listener left at the end');
  });

  test('MA13 without an adjuster, or with a no-op one, the move is today\'s',
      () {
    List<double> run(FakeAdjuster? fake) {
      final s = Scene(adjuster: fake, objectSnap: true);
      s.pressA();
      s.move(s.at(7100, 3045));
      s.move(s.at(7130, 3051), shift: true);
      s.up(s.at(7130, 3051), shift: true);
      return coordsOf(s, s.a);
    }

    final none = run(null);
    final noop = run(FakeAdjuster(offset: false));
    expect(noop, none);
    // Today's move: the press (7060, 3020) to (7130, 3051), Shift pinning
    // the minor world axis to the base.
    expect(none[0], closeTo(7080, 1e-9));
    expect(none[1], closeTo(3020, 1e-9));
  });
}
