// Spec 12b D7: each drawing tool family — the line tool, the text tool and a
// placement shape (its plain and its filled form) — draws on the effective
// current layer, `drawingLayer(document)`: the stored current layer when it
// is usable, layer 0 when it is hidden.
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/line_tool.dart';
import 'package:jet_cad_2d_flutter/src/draw/rectangle_tool.dart';
import 'package:jet_cad_2d_flutter/src/draw/text_tool.dart';

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf;

/// [scene]'s document with P-6's layers added by command: `A` (ACI 1), `B`
/// (ACI 5, locked) and `C` (ACI 3, hidden). Returns their handles.
(Handle, Handle, Handle) addLayers(DrawScene scene) {
  final doc = scene.document;
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  Handle add(String name, int aci, {bool visible = true, bool locked = false}) {
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: handle,
      name: name,
      color: IndexedColor(aci),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: visible,
      locked: locked,
    )));
    return handle;
  }

  final layers = (
    add('A', 1),
    add('B', 5, locked: true),
    add('C', 3, visible: false),
  );
  doc.commands.clearHistory();
  return layers;
}

/// Every live entity's handle except [scene]'s anchor (which is on layer 0).
Set<Handle> drawnBy(DrawScene scene) => {
      for (final slot in scene.document.entities.liveSlots)
        if (scene.document.entities.handleAt(slot) != scene.anchor)
          scene.document.entities.handleAt(slot),
    };

Handle layerOf(DraftDocument doc, Handle h) =>
    doc.entities.layerAt(doc.entities.slotOf(h)!);

/// One segment, one text, a plain rectangle and a filled one, each by its
/// tool, in that order; returns the handles each tool added.
List<Set<Handle>> drawEach(DrawScene s) {
  final out = <Set<Handle>>[];
  var before = drawnBy(s);
  void step(void Function() draw) {
    draw();
    final now = drawnBy(s);
    out.add(now.difference(before));
    before = now;
  }

  step(() {
    final rig = drawRig(s.document, LineTool(), objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7010.5, 3020.25));
    clickAt(rig, screenOf(rig.camera, 7090.75, 3110.5));
  });
  step(() {
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7050.5, 3080.25));
    tool.commitText('Hall', rig.context);
  });
  for (final filled in const [false, true]) {
    step(() {
      final fill = ValueNotifier<bool>(filled);
      addTearDown(fill.dispose);
      final rig =
          drawRig(s.document, RectangleTool(fill: fill), objectSnap: false);
      clickAt(rig, screenOf(rig.camera, 7020.5, 3030.25));
      clickAt(rig, screenOf(rig.camera, 7080.75, 3070.5));
    });
  }
  return out;
}

void main() {
  test(
      'with A current, the line, the text, the plain rectangle and both '
      'records of the filled one are on A (M-LP-16, drafting)', () {
    final s = drawScene();
    final (a, _, _) = addLayers(s);
    s.document.commands.execute(SetCurrentLayerCommand(a));
    final added = drawEach(s);
    expect(added.map((h) => h.length), [1, 1, 1, 2],
        reason: 'a line, a text, a polyline, a fill and its boundary');
    for (final step in added) {
      for (final h in step) {
        expect(layerOf(s.document, h), a, reason: h.toHex());
      }
    }
  });

  test(
      'a locked current layer still takes new drawing (D3: only a hidden '
      'one is unusable)', () {
    final s = drawScene();
    final (_, b, _) = addLayers(s);
    s.document.commands.execute(SetCurrentLayerCommand(b));
    for (final h in drawEach(s).expand((step) => step)) {
      expect(layerOf(s.document, h), b, reason: h.toHex());
    }
  });

  test(
      'a stored current layer that is hidden is not the drawing layer: every '
      'tool draws on layer 0 (drawingLayer, not header.currentLayer)', () {
    final s = drawScene();
    final (_, _, c) = addLayers(s);
    // Only a file (or the restore form) can store a hidden current layer.
    s.document.commands.execute(SetCurrentLayerCommand.restore(c));
    expect(s.document.header.currentLayer, c);
    final added = drawEach(s).expand((step) => step).toList();
    expect(added, hasLength(5));
    for (final h in added) {
      expect(layerOf(s.document, h), ReservedHandles.layerZero,
          reason: h.toHex());
    }
  });
}
