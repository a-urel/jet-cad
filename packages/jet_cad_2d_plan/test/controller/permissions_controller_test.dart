// Spec P2 "Permissions" at the controller (Task 12): the tool gate
// (ids and needs), a change at runtime, host calls not gated, deleteSelection
// and the document's engine permissions. Through the controller alone, its
// tools driven with ToolPointerEvents under a turned, flipped, off-origin
// camera (test/support/tool_events.dart). The kit-free controller: these are
// the plan library's own tools.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/tool_events.dart';

final Vector2 a = Vector2(4120.5, -1415.25);
final Vector2 b = Vector2(4730.75, -1102.5);
final Vector2 away = Vector2(5480.25, -1630.75);

PlanController make({PlanPermissions permissions = PlanPermissions.full}) {
  final c = PlanController(kits: const [], permissions: permissions);
  addTearDown(c.dispose);
  useTestCamera(c);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the fixtures are not degenerate', () {
    expect(a.x != 0 && a.y != 0, isTrue);
    final c = make();
    expect(c.toolController.context.camera.value.scale,
        closeTo(kTestScale, 1e-12));
    expect(
        c.toolController.context.camera.value.worldToScreenMatrix.b, isNot(0),
        reason: 'a turned camera');
  });

  group('the tool gate', () {
    test(
        'PM-14 selectTool: select always; a tool the ids refuse is refused '
        'and changes nothing; an unknown id is refused', () {
      final c = make(
          permissions: PlanPermissions.full
              .copyWith(tools: {'plan.select', 'plan.arc'}));
      // M-PM14: `_allowsTool` drops the `_permissions.allowsTool(id)` test.
      expect(c.selectTool('plan.line'), isFalse);
      expect(c.activeTool.value, 'plan.select');
      expect(c.selectTool('plan.arc'), isTrue);
      expect(c.activeTool.value, 'plan.arc');
      expect(c.selectTool('acme.nothing'), isFalse);
      expect(c.activeTool.value, 'plan.arc');
      expect(c.selectTool('plan.select'), isTrue);
      expect(c.activeTool.value, 'plan.select');
      c.permissions = PlanPermissions.full;
      expect(c.selectTool('plan.line'), isTrue);
    });

    test(
        "PM-15 a tool's needs are checked against the document's engine "
        'permissions; select needs nothing', () {
      final c = make();
      c.document.commands.permissions = const DraftPermissions(
          transform: true, components: true, geometry: false, structure: true);
      // M-PM15: `_allowsTool` drops the needs test.
      for (final id in [
        'plan.line',
        'plan.polyline',
        'plan.rectangle',
        'plan.circle',
        'plan.arc',
        'plan.text',
      ]) {
        expect(c.selectTool(id), isFalse, reason: id);
      }
      expect(c.activeTool.value, 'plan.select');
      expect(c.selectTool('plan.select'), isTrue);
      expect(c.needsOf('plan.select'), isEmpty);
      expect(c.needsOf('plan.line'), {Capability.geometry});
      expect(c.needsOf('acme.nothing'), isNull);
    });
  });

  group('a change at runtime', () {
    test(
        'PM-16 plan.line one point in, then readOnly: select is armed, the '
        'pending point is gone, nothing was executed (M-H47)', () {
      final c = make();
      expect(c.selectTool('plan.line'), isTrue);
      tapAt(c, a);
      expect(c.toolController.active.isMidShape, isTrue, reason: 'premise');
      final state = c.document.commands.stateId;
      final depth = c.document.commands.undoDepth;
      var told = 0;
      void listener() => told++;
      c.addListener(listener);
      addTearDown(() => c.removeListener(listener));
      c.permissions = PlanPermissions.readOnly;
      // M-PM16: the setter drops its fallback to plan.select.
      expect(c.activeTool.value, 'plan.select');
      expect(told, isPositive, reason: 'the widgets rebuild');
      tapAt(c, away);
      tapAt(c, b);
      expect(c.document.commands.stateId, state);
      expect(c.document.commands.undoDepth, depth);
      c.permissions = PlanPermissions.full;
      expect(c.activeTool.value, 'plan.select', reason: 'no automatic return');
      expect(c.selectTool('plan.line'), isTrue);
      expect(c.toolController.active.isMidShape, isFalse,
          reason: 'the line starts afresh');
      // The same value again: no notification.
      final before = told;
      c.permissions = PlanPermissions.full;
      expect(told, before);
    });

    test(
        'PM-17 a body drag whose move gate closes before its up is cancelled '
        'at the change and executes nothing; kept open it moves (S-9 h)',
        () async {
      final c = make();
      final line = drawLine(c, a, b);
      // The drag starts on the line as drawn (grid-snapped ends).
      final mid = drawnMidOf(c.document, line);
      c.selection.replace([SelectionKey.root(line)]);
      final state = c.document.commands.stateId;
      dragFrom(c, mid, mid + Vector2(800, 0), beforeUp: () {
        expect(c.toolController.active.phase, ToolPhase.dragging,
            reason: 'premise: a drag under way');
        c.permissions = PlanPermissions.full.copyWith(move: false);
        // M-PM17: the setter drops its stale-drag cancel.
        expect(c.toolController.active.phase, ToolPhase.idle);
      });
      expect(c.document.commands.stateId, state);
      c.permissions = PlanPermissions.full;
      c.selection.replace([SelectionKey.root(line)]);
      dragFrom(c, mid, mid + Vector2(800, 0));
      expect(c.document.commands.stateId, isNot(state));
      await settleHistory();
      expect(c.canUndo.value, isTrue);
    });

    test(
        "PM-18 the document's engine permissions follow the profile, and a "
        'new plan gets them too', () {
      final c = make();
      expect(c.document.commands.permissions, same(DraftPermissions.all));
      c.permissions = PlanPermissions.readOnly;
      expect(c.document.commands.permissions, same(DraftPermissions.readOnly));
      c.newPlan();
      // M-PM18: the per-document `commands.permissions = _permissions.draft`
      // dropped.
      expect(c.document.commands.permissions, same(DraftPermissions.readOnly));
      c.permissions = PlanPermissions.full;
      expect(c.document.commands.permissions, same(DraftPermissions.all));
    });
  });

  group('host calls and deleteSelection', () {
    test(
        "PM-19 a host's undo and redo under readOnly still work, and the "
        'profile is back afterwards', () async {
      final c = make();
      final line = drawLine(c, a, b);
      await settleHistory();
      expect(c.canUndo.value, isTrue);
      c.permissions = PlanPermissions.readOnly;
      // M-PM19: undo() without the permission lift (PermissionDeniedError).
      c.undo();
      expect(linesOf(c.document), isNot(contains(line)));
      expect(c.document.commands.permissions, same(DraftPermissions.readOnly));
      c.redo();
      expect(linesOf(c.document), contains(line));
      expect(c.document.commands.permissions, same(DraftPermissions.readOnly));
    });

    test(
        'PM-20 deleteSelection: false with nothing selected and under '
        'delete: false; true under full, one undo step (T5-c)', () {
      final c = make();
      final line = drawLine(c, a, b);
      expect(c.deleteSelection(), isFalse, reason: 'nothing selected');
      c.selection.replace([SelectionKey.root(line)]);
      c.permissions = PlanPermissions.full.copyWith(delete: false);
      final state = c.document.commands.stateId;
      // M-PM8 turns this red too (the gate's delete ignores the flag).
      expect(c.deleteSelection(), isFalse);
      expect(c.document.commands.stateId, state);
      expect(linesOf(c.document), contains(line));
      c.permissions = PlanPermissions.full;
      expect(c.deleteSelection(), isTrue);
      expect(linesOf(c.document), isNot(contains(line)));
      c.undo();
      expect(linesOf(c.document), contains(line));
    });
  });
  test(
      "PM-21 an untouched new plan takes the reported locale's separator "
      "under readOnly too: the controller's own settling is not gated", () {
    final c = make(permissions: PlanPermissions.readOnly);
    expect(c.document.commands.permissions, same(DraftPermissions.readOnly));
    // M-PM21: reportLocale's SetComponentCommand run without the lift
    // (PermissionDeniedError: components).
    c.reportLocale(const Locale('tr'));
    final d = c.document;
    expect(d.components.get<PageComponent>(d.rootHandle)!.decimalSeparator,
        DecimalSeparator.comma);
    expect(c.document.commands.canUndo, isFalse, reason: 'no undo step');
    expect(c.document.commands.permissions, same(DraftPermissions.readOnly));
  });

  test(
      'S-PD a widget-side commit under readOnly answers false and changes '
      'nothing (execute: every refusal is false)', () {
    final c = make();
    final line = drawLine(c, a, b);
    c.permissions = PlanPermissions.readOnly;
    expect(c.document.commands.permissions, same(DraftPermissions.readOnly),
        reason: 'premise: the engine refuses structure');
    final state = c.document.commands.stateId;
    final depth = c.document.commands.undoDepth;
    final text = DraftDocumentCodec.encodeToString(c.document);
    // M-SPD: execute's `on PermissionDeniedError` catch dropped (the
    // refusal escapes to the widget).
    expect(c.execute(RemoveEntityCommand(line)), isFalse);
    expect(linesOf(c.document), contains(line));
    expect(c.document.commands.stateId, state);
    expect(c.document.commands.undoDepth, depth);
    expect(DraftDocumentCodec.encodeToString(c.document), text);
  });
}
