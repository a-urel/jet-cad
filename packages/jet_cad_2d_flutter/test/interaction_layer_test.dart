import 'package:flutter/gestures.dart'
    show
        PointerDeviceKind,
        PointerMoveEvent,
        kMiddleMouseButton,
        kPrimaryButton,
        kSecondaryButton;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart'
    show Focus, FocusManager, FocusNode, Offset, Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/camera_controller.dart';
import 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart';
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';

import 'support/selection_fixture.dart';

/// `DraftCanvas` lays text out through a real measurer, so the document the
/// layer sits over needs one.
DraftDocument document() {
  final measurer = FlutterTextMeasurer();
  addTearDown(measurer.clear);
  return DraftDocument.empty(measurer: measurer);
}

/// [local] in the test surface's global coordinates. Read back from the
/// layer's own box rather than assuming the centred (200, 150) origin.
Offset at(WidgetTester tester, Offset local) =>
    tester.getTopLeft(find.byType(InteractionLayer)) + local;

/// The node the layer owns, reached through its `Focus` widget.
FocusNode layerFocus(WidgetTester tester) => tester
    .widget<Focus>(find
        .descendant(
            of: find.byType(InteractionLayer), matching: find.byType(Focus))
        .first)
    .focusNode!;

/// Scale 2, translation (-1850, 1120): a horizontal world line from
/// (990, 500) to (1010, 500) lands on local y = 120, x = 130..170 — off the
/// identity, off the origin, and off the layer's centre.
CameraController lineCamera() => cameraAt(2.0, const Offset(-1850, 1120));
Handle addProbeLine(DraftDocument doc) =>
    addEntity(doc, doc.rootHandle, EntityKind.line, [990, 500, 1010, 500], []);

/// Scale 2, translation (-120, 2120): `sx = 2*wx - 120`, `sy = -2*wy + 2120`.
/// The band's world corners (90, 1010) and (210, 990) land at local (60, 100)
/// and (300, 140).
CameraController bandCamera() => cameraAt(2.0, const Offset(-120, 2120));

/// The band drag's two corners, in the layer's local coordinates.
const Offset kBandA = Offset(60, 100);
const Offset kBandB = Offset(300, 140);

/// `band_query_test.dart`'s inside / straddling / outside lines, at world
/// y = 1000. The band box [90, 210] x [990, 1010] encloses `inside`, cuts
/// `straddling`, and misses `outside` entirely.
({Handle inside, Handle straddling, Handle outside}) addBandLines(
    DraftDocument doc) {
  final inside = addEntity(
      doc, doc.rootHandle, EntityKind.line, [100, 1000, 120, 1000], []);
  final straddling = addEntity(
      doc, doc.rootHandle, EntityKind.line, [190, 1000, 230, 1000], []);
  final outside = addEntity(
      doc, doc.rootHandle, EntityKind.line, [300, 1000, 320, 1000], []);
  return (inside: inside, straddling: straddling, outside: outside);
}

Future<TestGesture> primary(WidgetTester tester, {required int pointer}) =>
    tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: pointer,
        buttons: kPrimaryButton);

void main() {
  testWidgets('a click selects; the layer took focus', (tester) async {
    final doc = document();
    final line = addProbeLine(doc);
    final rig =
        await pumpInteraction(tester, document: doc, camera: lineCamera());

    final node = layerFocus(tester);
    // Focus is surrendered first: with `autofocus` the layer already holds it
    // after the pump, and a test that only asserted the end state would pass
    // with `requestFocus` deleted from the down path.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNot(same(node)),
        reason: 'the layer must not hold focus when the click arrives');

    final gesture = await primary(tester, pointer: 1);
    await gesture.down(at(tester, const Offset(150, 120)));
    await gesture.up();
    await tester.pump();

    expect(rig.selection.length, 1);
    expect(rig.selection.contains(SelectionKey.root(line)), isTrue);
    expect(FocusManager.instance.primaryFocus, same(node));
  });

  testWidgets('drag direction selects the mode; a vertical drag is a window',
      (tester) async {
    // M-02g.
    final doc = document();
    final lines = addBandLines(doc);
    final rig =
        await pumpInteraction(tester, document: doc, camera: bandCamera());

    final leftToRight = await primary(tester, pointer: 1);
    await leftToRight.down(at(tester, kBandA));
    await leftToRight.moveTo(at(tester, kBandB));
    expect(rig.tool.phase, ToolPhase.dragging);
    expect(rig.tool.bandMode, BandMode.window);
    await leftToRight.up();
    await tester.pump();
    expect(rig.selection.length, 1);
    expect(rig.selection.contains(SelectionKey.root(lines.inside)), isTrue,
        reason: 'a window band encloses; the straddler is out');

    rig.selection.clear();
    final rightToLeft = await primary(tester, pointer: 2);
    await rightToLeft.down(at(tester, kBandB));
    await rightToLeft.moveTo(at(tester, kBandA));
    expect(rig.tool.phase, ToolPhase.dragging);
    expect(rig.tool.bandMode, BandMode.crossing);
    await rightToLeft.up();
    await tester.pump();
    expect(rig.selection.length, 2);
    expect(rig.selection.contains(SelectionKey.root(lines.inside)), isTrue);
    expect(rig.selection.contains(SelectionKey.root(lines.straddling)), isTrue);

    rig.selection.clear();
    final vertical = await primary(tester, pointer: 3);
    await vertical.down(at(tester, kBandA));
    await vertical.moveTo(at(tester, Offset(kBandA.dx, kBandB.dy)));
    expect(rig.tool.phase, ToolPhase.dragging);
    expect(rig.tool.bandMode, BandMode.window,
        reason: 'end.dx == start.dx is not a right-to-left drag: the rule is '
            '`end.dx >= start.dx`, so a purely vertical drag is a window');
    await vertical.up();
    await tester.pump();
    expect(rig.selection.isEmpty, isTrue,
        reason: 'the vertical band is the world box [90, 90] x [990, 1010] — '
            'zero width, so a window band encloses nothing; the mode is a '
            'window all the same, which is what the assertion above pins');
  });

  testWidgets('exiting the layer clears hover', (tester) async {
    // M-02i.
    final doc = document();
    final line = addProbeLine(doc);
    final rig =
        await pumpInteraction(tester, document: doc, camera: lineCamera());

    final mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse, pointer: 7);
    await mouse.addPointer(location: at(tester, const Offset(10, 10)));
    addTearDown(mouse.removePointer);
    expect(rig.selection.hover, isNull,
        reason: 'the corner the pointer entered at is empty space');

    await mouse.moveTo(at(tester, const Offset(150, 120)));
    await tester.pump();
    expect(rig.selection.hover, SelectionKey.root(line));

    // Outside the centred 400 x 300 box entirely, so no hover reaches the
    // layer and only `MouseRegion.onExit` can clear the state.
    await mouse.moveTo(const Offset(5, 5));
    await tester.pump();
    expect(rig.selection.hover, isNull);
  });

  testWidgets('the pick radius is converted by the camera scale',
      (tester) async {
    // M-02l. At scale 0.25 the 6 px radius is 24 world units, so a click
    // 5 px off the line (20 world units) picks it and one 25 px off
    // (100 world units) does not.
    final doc = document();
    final line = addEntity(
        doc, doc.rootHandle, EntityKind.line, [900, 500, 1100, 500], []);
    final rig = await pumpInteraction(tester,
        document: doc, camera: cameraAt(0.25, const Offset(-100, 245)));

    final near = await primary(tester, pointer: 1);
    await near.down(at(tester, const Offset(150, 125)));
    await near.up();
    await tester.pump();
    expect(rig.selection.length, 1,
        reason: 'a world-space radius of 6 would miss at 20 world units out');
    expect(rig.selection.contains(SelectionKey.root(line)), isTrue);

    final far = await primary(tester, pointer: 2);
    await far.down(at(tester, const Offset(150, 145)));
    await far.up();
    await tester.pump();
    expect(rig.selection.isEmpty, isTrue,
        reason: 'a radius that grew without bound would swallow this too');
  });

  testWidgets('one Delete press is one remove', (tester) async {
    // M-02x.
    final doc = document();
    final line = addProbeLine(doc);
    final other = addEntity(
        doc, doc.rootHandle, EntityKind.line, [990, 650, 1010, 650], []);
    final rig =
        await pumpInteraction(tester, document: doc, camera: lineCamera());
    // The fixture's own `AddEntityCommand`s are on the undo stack; drop them
    // so `canUndo` below answers about the delete and nothing else.
    doc.commands.clearHistory();
    expect(doc.commands.canUndo, isFalse);

    rig.selection.replace([SelectionKey.root(line)]);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    expect(doc.entities.slotOf(line), isNull);
    expect(doc.entities.slotOf(other), isNotNull,
        reason: 'only the selected entity goes');
    expect(doc.commands.canUndo, isTrue);

    doc.commands.undo();
    await tester.pump();

    expect(doc.entities.slotOf(line), isNotNull);
    expect(doc.commands.canUndo, isFalse,
        reason: 'a key down and its key up are one remove between them, so '
            'one undo empties the stack');
  });

  testWidgets('a pointer cancel ends the band', (tester) async {
    // M-02y.
    final doc = document();
    final lines = addBandLines(doc);
    final rig =
        await pumpInteraction(tester, document: doc, camera: bandCamera());
    // `outside` is the one line the band never touches, so "untouched" below
    // is a real statement and not a restatement of an empty selection.
    rig.selection.replace([SelectionKey.root(lines.outside)]);
    await tester.pump();

    final gesture = await primary(tester, pointer: 1);
    await gesture.down(at(tester, kBandA));
    await gesture.moveTo(at(tester, kBandB));
    expect(rig.tools.active.phase, ToolPhase.dragging);

    await gesture.cancel();
    await tester.pump();

    expect(rig.tools.active.phase, ToolPhase.idle);
    expect(rig.tool.bandMode, isNull);
    expect(rig.tool.bandScreen, isNull);
    expect(rig.selection.length, 1);
    expect(rig.selection.contains(SelectionKey.root(lines.outside)), isTrue);
  });

  testWidgets('a middle-button drag never reaches the tool', (tester) async {
    final doc = document();
    addBandLines(doc);
    final rig =
        await pumpInteraction(tester, document: doc, camera: bandCamera());

    final pan = await tester.createGesture(
        kind: PointerDeviceKind.mouse, pointer: 1, buttons: kMiddleMouseButton);
    await pan.down(at(tester, kBandA));
    expect(rig.tools.active.phase, ToolPhase.idle);
    await pan.moveTo(at(tester, kBandB));
    expect(rig.tools.active.phase, ToolPhase.idle);
    // The up carries `buttons == 0` and belongs to no active pointer: it must
    // be dropped rather than thrown on.
    await pan.up();
    await tester.pump();
    expect(rig.tools.active.phase, ToolPhase.idle);
    expect(rig.selection.isEmpty, isTrue);

    // A primary+middle mask is camera-owned too — the rule is on the mask,
    // not on the absence of the primary bit.
    final both = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 2,
        buttons: kPrimaryButton | kMiddleMouseButton);
    await both.down(at(tester, kBandA));
    await both.moveTo(at(tester, kBandB));
    await both.up();
    await tester.pump();
    expect(rig.tools.active.phase, ToolPhase.idle);
    expect(rig.selection.isEmpty, isTrue);
  });

  testWidgets('a middle-only move from the active pointer is camera-owned',
      (tester) async {
    // The spec's first routing row wins over the primary-disappeared row: a
    // mask containing the pan button is the camera's, so the move is ignored
    // outright and the press it interrupts stays exactly as it was. The
    // pointer's own up is what ends it.
    final doc = document();
    final lines = addBandLines(doc);
    final rig =
        await pumpInteraction(tester, document: doc, camera: bandCamera());

    final gesture = await primary(tester, pointer: 4);
    await gesture.down(at(tester, kBandA));
    await gesture.moveTo(at(tester, kBandB));
    expect(rig.tools.active.phase, ToolPhase.dragging);

    await tester.sendEventToBinding(PointerMoveEvent(
      viewId: tester.view.viewId,
      pointer: 4,
      kind: PointerDeviceKind.mouse,
      position: at(tester, const Offset(200, 160)),
      buttons: kMiddleMouseButton,
    ));

    expect(rig.tools.active.phase, ToolPhase.dragging,
        reason: 'a camera-owned move is not an up');
    expect(rig.tool.bandScreen, Rect.fromPoints(kBandA, kBandB),
        reason: 'and it did not move the band either');

    await gesture.up();
    await tester.pump();

    expect(rig.tools.active.phase, ToolPhase.idle);
    expect(rig.selection.length, 1);
    expect(rig.selection.contains(SelectionKey.root(lines.inside)), isTrue,
        reason: 'the band completed as though the middle move never arrived');
  });

  testWidgets('the primary disappearing from a move is an up', (tester) async {
    // The other half of the mask rules: a move that loses the primary while
    // gaining a button the camera does **not** own is an up, at the position
    // that move reports. A secondary press is the realistic way for a mouse
    // to produce one.
    final doc = document();
    final lines = addBandLines(doc);
    final rig =
        await pumpInteraction(tester, document: doc, camera: bandCamera());

    final gesture = await primary(tester, pointer: 5);
    await gesture.down(at(tester, kBandA));
    await gesture.moveTo(at(tester, kBandB));
    expect(rig.tools.active.phase, ToolPhase.dragging);

    // Local (350, 140) is world (235, 990) — a band corner that encloses the
    // straddler as well, which local (300, 140) does not. So this asserts the
    // up landed at the *synthesised move's* position, not at the last real
    // move's.
    await tester.sendEventToBinding(PointerMoveEvent(
      viewId: tester.view.viewId,
      pointer: 5,
      kind: PointerDeviceKind.mouse,
      position: at(tester, const Offset(350, 140)),
      buttons: kSecondaryButton,
    ));
    await tester.pump();

    expect(rig.tools.active.phase, ToolPhase.idle);
    expect(rig.selection.length, 2);
    expect(rig.selection.contains(SelectionKey.root(lines.inside)), isTrue);
    expect(rig.selection.contains(SelectionKey.root(lines.straddling)), isTrue,
        reason: 'the world band [90, 235] x [990, 1010] encloses it, which '
            'the band that ended at local 300 would not have');

    // The active pointer is already cleared, so the gesture's own up is a
    // stray: dropped, not thrown on, and it does not re-run the band.
    await gesture.up();
    await tester.pump();

    expect(rig.tools.active.phase, ToolPhase.idle);
    expect(rig.selection.length, 2);
  });

  testWidgets('a drag that leaves the box keeps its captured pointer',
      (tester) async {
    // A pointer that went down inside the layer is captured: its moves and
    // its up keep arriving wherever it goes. `MouseRegion.onExit` must not
    // hand that crossing to the tool — `SelectTool.onPointerExit` cancels a
    // live drag, and a band the user drags past the canvas edge would vanish.
    final doc = document();
    final lines = addBandLines(doc);
    final rig =
        await pumpInteraction(tester, document: doc, camera: bandCamera());

    final gesture = await primary(tester, pointer: 6);
    await gesture.down(at(tester, kBandA));
    await gesture.moveTo(at(tester, kBandB));
    expect(rig.tools.active.phase, ToolPhase.dragging);

    // Global (700, 300): past the centred box's right edge at global x = 600,
    // so local (500, 150) — world (310, 985).
    await gesture.moveTo(const Offset(700, 300));
    await tester.pump();

    expect(rig.tools.active.phase, ToolPhase.dragging,
        reason: 'leaving the box is not the end of a captured drag');
    expect(rig.tool.bandScreen, Rect.fromPoints(kBandA, const Offset(500, 150)),
        reason: "and the band's end followed the pointer out");

    await gesture.up();
    await tester.pump();

    expect(rig.tools.active.phase, ToolPhase.idle);
    // The world band [90, 310] x [985, 1010] encloses `inside` and
    // `straddling` and cuts `outside` (world x 300..320), which a window band
    // leaves out.
    expect(rig.selection.length, 2);
    expect(rig.selection.contains(SelectionKey.root(lines.inside)), isTrue);
    expect(rig.selection.contains(SelectionKey.root(lines.straddling)), isTrue);
    expect(rig.selection.contains(SelectionKey.root(lines.outside)), isFalse);
  });
}
