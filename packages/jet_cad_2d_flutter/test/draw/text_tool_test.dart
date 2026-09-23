import 'dart:typed_data';

import 'package:flutter/services.dart'
    show LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/text_tool.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;

Handle? textOf(DraftDocument doc) {
  for (final slot in doc.entities.liveSlots) {
    if (doc.entities.kindAt(slot) == EntityKind.text) {
      return doc.entities.handleAt(slot);
    }
  }
  return null;
}

void main() {
  for (final flipY in const [true, false]) {
    test(
        'TX1 flipY $flipY: a click sets pending at the exact point, 2.5 '
        'paper mm at 1:20, and dispatches nothing (M-05j)', () {
      final s = drawScene();
      final tool = TextTool();
      addTearDown(tool.dispose);
      final rig = drawRig(s.document, tool, flipY: flipY, objectSnap: false);
      final before = snapshot(s.document);
      final at = screenOf(rig.camera, 7050.5, 3080.25);
      clickAt(rig, at);
      final placed = tool.pending.value!;
      expect(placed.point, worldAt(rig, at));
      expect(placed.heightMm, 50.0);
      expect(snapshot(s.document), before);
    });
  }

  test('TX2 commitText commits one text with the string and height', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    final at = screenOf(rig.camera, 7050.5, 3080.25);
    clickAt(rig, at);
    tool.commitText('Kitchen ', rig.context);
    final h = textOf(s.document)!;
    final slot = s.document.entities.slotOf(h)!;
    final r = s.document.entities.read(slot);
    final p = s.document.geometry.read(s.document.entities.geomIndexAt(slot));
    expect(r.text, 'Kitchen ', reason: 'stored exactly as typed');
    expect(r.textAttrs, 0);
    final w = worldAt(rig, at);
    expect(p.coords, Float64List.fromList([w.x, w.y]));
    expect(p.scalars, Float64List.fromList([50, 0, 1, 0]));
    expect(tool.pending.value, isNull);
    expect(s.document.commands.undoDepth, 1);
  });

  test('TX3 an empty string cancels, byte-identical', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    final before = snapshot(s.document);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    tool.commitText('', rig.context);
    expect(snapshot(s.document), before);
    expect(tool.pending.value, isNull);
  });

  test(
      'TX4 a canvas click while pending commits the controller text and '
      'starts nothing new (M-05y)', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    tool.controller.text = 'Bath';
    clickAt(rig, screenOf(rig.camera, 7120, 3040));
    final h = textOf(s.document)!;
    expect(
        s.document.entities.read(s.document.entities.slotOf(h)!).text, 'Bath');
    expect(tool.pending.value, isNull);
    expect(tool.controller.text, isEmpty);
  });

  test('TX5 Escape and a tool switch each cancel, byte-identical', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    final before = snapshot(s.document);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    tool.controller.text = 'x';
    keyDown(rig, LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape);
    expect(tool.pending.value, isNull);
    expect(snapshot(s.document), before);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    tool.controller.text = 'y';
    rig.tools.activate(SelectTool());
    expect(tool.pending.value, isNull);
    expect(snapshot(s.document), before);
  });

  test('TX6 Enter with the canvas focused commits the controller text', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    tool.controller.text = 'Hall';
    keyDown(rig, LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
    expect(textOf(s.document), isNotNull);
  });

  test('TX7 a shift click takes no ortho', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    final at = screenOf(rig.camera, 7050.5, 3080.25);
    clickAt(rig, at, shift: true);
    expect(tool.pending.value!.point, worldAt(rig, at));
    expect(tool.orthoBase, isNull);
  });
}
