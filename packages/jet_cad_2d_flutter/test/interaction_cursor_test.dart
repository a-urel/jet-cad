import 'dart:ui' show Canvas, Size;

import 'package:flutter/services.dart'
    show KeyEvent, MouseCursor, SystemMouseCursors;
import 'package:flutter/widgets.dart' show KeyEventResult, MouseRegion, Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart';
import 'package:jet_cad_2d_flutter/src/interaction_layer.dart';
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
}
