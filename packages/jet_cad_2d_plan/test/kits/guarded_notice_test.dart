// Spec 3a C1.2, P4 "The failure boundary": the guard forwards a kit tool's
// notice. A tool that is no ToolNotice has none; a notice getter or value
// that throws is one diagnostic, then null for the tool's life.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/kits/guard.dart';

import '../support/notice_kit.dart';
import '../support/throwing_kit.dart';

/// [inner] in the plan's guard, as kit [kitId]'s tool [toolId].
({GuardedTool tool, DiagnosticsLog log}) guarded(Tool inner,
    {String kitId = 'note', String toolId = noteToolId}) {
  final log = DiagnosticsLog();
  final hint = ValueNotifier(false);
  final tool = GuardedTool(
      inner: inner,
      kitId: kitId,
      toolId: toolId,
      log: log,
      lockHint: hint,
      onFailed: () {});
  addTearDown(() {
    tool.dispose();
    hint.dispose();
    log.dispose();
  });
  return (tool: tool, log: log);
}

void main() {
  testWidgets(
      'TN-forward the inner\'s notice, one listenable for the tool\'s life, '
      'telling its listeners; none for a tool that has none (M-TN-forward)',
      (tester) async {
    final note = NoteTool();
    final g = guarded(note);
    // M-TN-forward: `notice` answers null for every tool.
    final notice = g.tool.notice!;
    expect(identical(g.tool.notice, notice), isTrue);
    expect(notice.value, isNull);
    var heard = 0;
    void hear() => heard++;
    notice.addListener(hear);
    note.said.value = busy('Mark 1');
    expect(heard, 1);
    expect(notice.value, busy('Mark 1'));
    notice.removeListener(hear);
    note.said.value = busy('Mark 2');
    expect(heard, 1);
    final plain =
        guarded(BoomTool(ThrowingKit()), kitId: 'boom', toolId: 'boom.tool');
    expect(plain.tool.notice, isNotNull, reason: 'premise: BoomTool speaks');
    final silent = guarded(_Silent(), kitId: 'box', toolId: 'box.stamp');
    expect(silent.tool.notice, isNull);
    await tester.pump();
    expect(g.log.entries.value, isEmpty);
  });

  testWidgets(
      'TN-guard a notice getter that throws: one diagnostic after the frame, '
      'no notice (M-TN-guard-getter)', (tester) async {
    final g = guarded(BoomTool(ThrowingKit(failing: ['notice'])),
        kitId: 'boom', toolId: 'boom.tool');
    expect(g.tool.notice, isNull);
    expect(g.tool.notice, isNull);
    await tester.pump();
    expect([for (final d in g.log.entries.value) (d.subject, d.code)],
        [('boom.tool', KitDiagnosticCode.hookFailed)]);
  });

  testWidgets(
      'TN-guard-value a notice value that throws: one diagnostic, then null '
      'even once it heals (M-TN-guard-value, M-TN-then-null)', (tester) async {
    final boom = ThrowingKit(failing: ['noticeValue']);
    final inner = BoomTool(boom);
    final g = guarded(inner, kitId: 'boom', toolId: 'boom.tool');
    final notice = g.tool.notice!;
    inner.said.value = const KitText('text:boom.alert', {'n': 1});
    expect(notice.value, isNull);
    boom.failing.clear();
    // M-TN-then-null: the wrapper reads the healed value again.
    expect(notice.value, isNull);
    await tester.pump();
    expect([for (final d in g.log.entries.value) (d.subject, d.code)],
        [('boom.tool', KitDiagnosticCode.hookFailed)]);
  });
}

/// A kit tool that has no notice.
final class _Silent extends Tool {
  @override
  String get name => 'Silent';
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
}
