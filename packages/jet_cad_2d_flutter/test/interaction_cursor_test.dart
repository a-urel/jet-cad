import 'dart:ui' show Canvas, Size;

import 'package:flutter/services.dart'
    show KeyEvent, MouseCursor, SystemMouseCursors;
import 'package:flutter/widgets.dart'
    show
        Align,
        EdgeInsets,
        GlobalKey,
        KeyEventResult,
        MouseRegion,
        Offset,
        Padding,
        SizedBox,
        Widget;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart';
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';

import 'support/selection_fixture.dart';

/// A tool that has only a cursor, and says when it changes.
class _CursorTool extends Tool {
  MouseCursor _cursor = MouseCursor.defer;

  @override
  MouseCursor get cursor => _cursor;

  void show(MouseCursor next) {
    _cursor = next;
    notifyListeners();
  }

  @override
  String get name => 'Cursor';
  @override
  ToolPhase get phase => ToolPhase.idle;
  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerExit(ToolContext ctx) {}
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;
  @override
  void cancel(ToolContext ctx) {}
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport) {}
}

/// A [ToolController] whose active tool is a fresh [_CursorTool], over a
/// bare context; everything is disposed at tear-down.
({ToolController tools, _CursorTool probe}) _cursorController() {
  final doc = DraftDocument.empty();
  final index = SpatialIndex(doc);
  final selection = SelectionController(doc);
  final camera = cameraAt(2.0, const Offset(-1850, 1120));
  final probe = _CursorTool();
  final tools = ToolController(
      initial: probe,
      context: ToolContext(
          document: doc, index: index, camera: camera, selection: selection));
  addTearDown(() {
    tools.dispose();
    probe.dispose();
    camera.dispose();
    selection.dispose();
    index.dispose();
  });
  return (tools: tools, probe: probe);
}

MouseCursor _shown(WidgetTester tester) => tester
    .widget<MouseRegion>(find
        .descendant(
            of: find.byType(InteractionLayer),
            matching: find.byType(MouseRegion))
        .first)
    .cursor;

void main() {
  testWidgets(
      "the MouseRegion follows the active tool's cursor (spec D5, "
      'M-03ab)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
    final rig = await pumpInteraction(tester,
        document: doc, camera: cameraAt(2.0, const Offset(-1850, 1120)));
    MouseCursor current() => tester
        .widget<MouseRegion>(find
            .descendant(
                of: find.byType(InteractionLayer),
                matching: find.byType(MouseRegion))
            .first)
        .cursor;

    expect(current(), MouseCursor.defer, reason: 'SelectTool, idle');
    final probe = _CursorTool();
    addTearDown(probe.dispose);
    rig.tools.activate(probe);
    probe.show(SystemMouseCursors.move);
    await tester.pump();
    expect(current(), SystemMouseCursors.move,
        reason: 'a notification rebuilds the MouseRegion');
    probe.show(SystemMouseCursors.grabbing);
    await tester.pump();
    expect(current(), SystemMouseCursors.grabbing);
    rig.tools.activate(rig.tool);
    await tester.pump();
    expect(current(), MouseCursor.defer);
  });
  testWidgets(
      'a layer re-pumped with another ToolController follows the new '
      "controller's cursor, not the old one's (didUpdateWidget)",
      (tester) async {
    final a = _cursorController();
    final b = _cursorController();
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
        InteractionLayer(tools: a.tools, child: const SizedBox.expand()));
    await tester.pumpWidget(
        InteractionLayer(tools: b.tools, child: const SizedBox.expand()));
    b.probe.show(SystemMouseCursors.grabbing);
    await tester.pump();
    expect(_shown(tester), SystemMouseCursors.grabbing,
        reason: 'the layer listens to the controller it now holds');
    a.probe.show(SystemMouseCursors.move);
    await tester.pump();
    expect(_shown(tester), SystemMouseCursors.grabbing,
        reason: 'and no longer to the one it held before');
  });

  testWidgets(
      'a layer reparented through a GlobalKey still follows the cursor '
      '(activate unmutes what deactivate muted)', (tester) async {
    final c = _cursorController();
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    final key = GlobalKey();
    Widget layer() => InteractionLayer(
        key: key, tools: c.tools, child: const SizedBox.expand());
    await tester.pumpWidget(Padding(padding: EdgeInsets.zero, child: layer()));
    final state = tester.state(find.byType(InteractionLayer));
    await tester.pumpWidget(Align(child: layer()));
    expect(
        identical(tester.state(find.byType(InteractionLayer)), state), isTrue,
        reason: 'reparented, not rebuilt: deactivate then activate ran');
    c.probe.show(SystemMouseCursors.move);
    await tester.pump();
    expect(_shown(tester), SystemMouseCursors.move);
  });
}
