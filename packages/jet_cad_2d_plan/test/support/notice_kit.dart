// The notice kit (3a Task 4, spec C1.2): kit "note", one tool, note.mark
// (letter N), that implements ToolNotice over its own notifier, which a
// test sets through controller.toolFor('note.mark'). English and Turkish
// words for its label and its one text.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

const String noteToolId = 'note.mark';

/// "Already marked: {name}".
KitText busy(String name) => KitText('text:note.busy', {'name': name});

final class NoteTool extends Tool implements ToolNotice {
  final ValueNotifier<KitText?> said = ValueNotifier(null);

  @override
  ValueListenable<KitText?> get notice => said;

  @override
  String get name => 'Note';
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
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {}

  @override
  void dispose() {
    said.dispose();
    super.dispose();
  }
}

final PlanKit noteKit = PlanKit(
  id: 'note',
  version: '1.0.0',
  tools: [
    PlanTool(
        id: noteToolId,
        icon: Icons.sticky_note_2,
        letter: 'N',
        create: (_) => NoteTool()),
  ],
  names: const KitNames({
    'en': {
      'tool:note.mark': 'Mark',
      'text:note.busy': 'Already marked: {name}',
    },
    'tr': {
      'tool:note.mark': 'İşaret',
      'text:note.busy': 'Zaten işaretli: {name}',
    },
  }),
);
