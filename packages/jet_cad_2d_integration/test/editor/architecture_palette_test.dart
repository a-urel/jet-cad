// Ported from jet_cad_floor_plan/test/planner_draw_test.dart (3a Task 26, spec C6); assertions unchanged.
//
// A12b with the planner's architecture rows restored (ruling IT-R9, D-26):
// the plan library's copy (jet_cad_2d_plan/test/editor/palette_draw_test.dart)
// stays as it is; this one runs the palette over the architecture kit.
// Beside it the new D-26/D-48 cases: each architecture letter arms its
// tool (IT-letters), each tool id is armed by selectTool and its row
// (IT-ids), and the guard built from the letters in use keeps a panel
// field's letters (IT-guard).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show FlutterTextMeasurer, SelectionKey;
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/chrome/rows.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_rig.dart';

/// `planner_draw_test.dart`'s `drawDoc` (`:16-32`, the plan library's
/// `canvas_fixture.dart:383-409`) as a plan file: a 1:20 page anchored at
/// (7000, 3000), grid snap off, and one line, measured by the Flutter
/// text measurer.
String drawPlanJson() {
  final m = FlutterTextMeasurer();
  final doc = DraftDocument.empty(measurer: m);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: 7000,
          originY: 3000,
          snapToGrid: false)));
  doc.commands.execute(addDrafted(doc, EntityKind.line,
      linePayload(Vector2(7137.3, 3161.7), Vector2(7300.9, 3190.1)),
      layer: ReservedHandles.layerZero));
  doc.commands.clearHistory();
  final json = ensureManifest(DraftDocumentCodec.encodeToString(doc));
  m.clear();
  return json;
}

/// The kit's tools, their letters and their English labels (D-26; the
/// letters are spec C2's; the labels today's strings).
const List<(String, LogicalKeyboardKey, String)> kArchitectureTools = [
  (ArchitectureTools.box, LogicalKeyboardKey.keyB, 'Box'),
  (ArchitectureTools.wall, LogicalKeyboardKey.keyW, 'Wall'),
  (ArchitectureTools.door, LogicalKeyboardKey.keyD, 'Door'),
  (ArchitectureTools.window, LogicalKeyboardKey.keyN, 'Window'),
  (ArchitectureTools.gap, LogicalKeyboardKey.keyG, 'Gap'),
  (ArchitectureTools.room, LogicalKeyboardKey.keyM, 'Room'),
  (ArchitectureTools.separator, LogicalKeyboardKey.keyS, 'Separator'),
  (ArchitectureTools.dimension, LogicalKeyboardKey.keyI, 'Dimension'),
];

void main() {
  testWidgets(
      "A12b every palette entry's drawing flag, by key: under runtime "
      'permissions each drawing tool is disabled and Select is not; with '
      'every permission all are enabled (Plan 11 rvF-paletteNotDrawing)',
      (tester) async {
    // Whether each entry is a drawing tool. The palette must carry exactly
    // these keys: an entry missing here, or missing from the palette, fails.
    // The planner's box, wall, door, window, gap, room, separator and
    // dimension rows are the architecture kit's (3a Task 26, Appendix A
    // D-26).
    const drawing = {
      'tool-plan.select': false,
      'tool-plan.line': true,
      'tool-plan.polyline': true,
      'tool-plan.rectangle': true,
      'tool-plan.circle': true,
      'tool-plan.arc': true,
      'tool-plan.text': true,
      'tool-architecture.box': true,
      'tool-architecture.wall': true,
      'tool-architecture.door': true,
      'tool-architecture.window': true,
      'tool-architecture.gap': true,
      'tool-architecture.room': true,
      'tool-architecture.separator': true,
      'tool-architecture.dimension': true,
    };
    // The tool tiles: the Fill toggle's inner PlanListRow carries no key.
    List<String> paletteKeys() => [
          for (final t in tester.widgetList<PlanListRow>(find.descendant(
              of: find.byType(PlanToolPalette),
              matching: find.byType(PlanListRow))))
            if (t.key case final ValueKey<String> k) k.value,
        ];
    bool enabled(String key) =>
        tester.widget<PlanListRow>(find.byKey(Key(key))).onTap != null;

    final c = architectureController(json: drawPlanJson());
    addTearDown(c.dispose);
    expect(c.document.commands.permissions.allows(Capability.geometry), isTrue);
    await pumpPlanEditor(tester, c);
    expect(paletteKeys(), unorderedEquals(drawing.keys));
    for (final key in drawing.keys) {
      expect(enabled(key), isTrue, reason: '$key with every permission');
    }

    c.document.commands.permissions = DraftPermissions.runtime;
    expect(
        c.document.commands.permissions.allows(Capability.geometry), isFalse);
    // The source pumps its composition again (pumpDesign): the palette
    // reads the permissions when it builds.
    await pumpPlanEditor(tester, c);
    expect(paletteKeys(), unorderedEquals(drawing.keys));
    for (final MapEntry(:key, value: isDrawing) in drawing.entries) {
      expect(enabled(key), !isDrawing,
          reason: isDrawing ? '$key draws: disabled' : '$key: enabled');
    }
  });

  testWidgets(
      'IT-letters each architecture letter arms its tool, the status line '
      'reads its word, and an idle Escape returns to Select (D-26, D-48)',
      (tester) async {
    final c = architectureController(json: drawPlanJson());
    addTearDown(c.dispose);
    await pumpPlanEditor(tester, c);
    await focusCanvas(tester);
    for (final (id, key, word) in kArchitectureTools) {
      await pressKey(tester, key);
      expect(c.activeTool.value, id, reason: '$key');
      expect(status(tester), word, reason: id);
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(c.activeTool.value, 'plan.select', reason: '$id: Escape');
    }
  });

  testWidgets(
      'IT-ids every architecture tool id is armed by selectTool and its '
      'palette row (D-48: the closed tool enum is the kit\'s ids)',
      (tester) async {
    final c = architectureController(json: drawPlanJson());
    addTearDown(c.dispose);
    await pumpPlanEditor(tester, c);
    for (final (id, _, word) in kArchitectureTools) {
      expect(c.selectTool(id), isTrue, reason: id);
      await tester.pump();
      expect(status(tester), word, reason: id);
      expect(c.selectTool('plan.select'), isTrue);
      await tester.tap(byKey('tool-$id'));
      await tester.pump();
      expect(c.activeTool.value, id, reason: 'the row of $id');
      expect(c.selectTool('plan.select'), isTrue);
      await tester.pump();
    }
  });

  testWidgets(
      'IT-guard a panel field keeps the architecture letters: typed into the '
      'room\'s name, W D N G M S I B arm nothing; on the canvas W arms the '
      'Wall tool (D-48: the guard is built from the kit\'s letters)',
      (tester) async {
    final c = sampleFlatController();
    addTearDown(c.dispose);
    await pumpPlanEditor(tester, c);
    final hall = c.document.components.withComponent<RoomParams>().first;
    expect(c.document.components.get<RoomParams>(hall)!.name, 'Hall',
        reason: 'premise: the sample\'s first room');
    c.activeSelection.replace([SelectionKey.root(hall)]);
    await tester.pump();
    await tester.tap(field('name'));
    await tester.pump();
    final node = tester.widget<TextField>(field('name')).focusNode!;
    expect(node.hasFocus, isTrue, reason: 'premise: the field focused');
    for (final (id, key, _) in kArchitectureTools) {
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(c.activeTool.value, 'plan.select', reason: '$id typed');
      expect(node.hasFocus, isTrue, reason: '$id: the field keeps the focus');
    }
    // The control: the canvas focused, W is the Wall tool's.
    await focusCanvas(tester);
    await pressKey(tester, LogicalKeyboardKey.keyW);
    expect(c.activeTool.value, ArchitectureTools.wall);
  });
}
