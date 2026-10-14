// Spec P4 "Locks" with E2 as amended in the final review (finding I1): a
// broken object is frozen and locked, and a write of its own type's
// component, which the engine refuses with a NonLiveWriteError before any
// lock check could run, is the lock's refusal (PlanLocked) on every path
// that commits: the host's execute, a kit tool, a kit grip drag through
// plan.select. Never a thrown StateError, never a kit's hookFailed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/box_kit.dart';
import '../support/tool_events.dart';

/// A kit tool that, on release, executes [command] through the dispatcher,
/// as a kit tool commits.
final class _WriteTool extends Tool {
  _WriteTool(this.command);
  final DraftCommand Function() command;
  @override
  String get name => 'write';
  @override
  ToolPhase get phase => ToolPhase.idle;
  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) =>
      ctx.document.commands.execute(command());
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

/// One grip at each square's origin; its drag writes a new square onto
/// [target] (a neighbour's parameters, as a wall-endpoint grip will).
final class _NeighbourGrips implements ObjectGripProvider {
  _NeighbourGrips(this.target);
  final Handle Function() target;

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    final o =
        (d.tree[group]! as GroupNode).transform.transformPoint(Vector2.zero());
    return [Grip(GripRole.stretch, 0, o.x, o.y)];
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      SetComponentCommand<SquareParams>(
          target(), const SquareParams(side: 1350.5, poisoned: true));

  @override
  List<(EntityKind, GeometryPayload)> preview(
          DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      const [];

  @override
  bool movable(DraftDocument d, Handle group) => true;
}

/// The `box` kit with [grips] on its square, and the `poke` kit, whose
/// tool writes [write].
List<PlanKit> kits(Switches sw,
        {ObjectGripProvider Function(PlanServices)? grips,
        DraftCommand Function()? write}) =>
    [
      PlanKit(
        id: 'box',
        version: '1.4.0',
        types: [
          PlanType<SquareParams>(
              id: SquareParams.id,
              fromJson: SquareParams.fromJson,
              parametric: SquareType(sw),
              grips: grips),
        ],
        names: const KitNames({
          'en': {'type:box.square': 'Square'},
        }),
      ),
      PlanKit(
        id: 'poke',
        version: '0.3.0',
        tools: [
          PlanTool(
              id: 'poke.write',
              icon: Icons.edit,
              create: (services) => _WriteTool(write ?? () => throw 'unset')),
        ],
        names: const KitNames({
          'en': {'tool:poke.write': 'Write'},
        }),
      ),
    ];

/// A broken square (its reach throws) frozen and locked by one refused
/// move, beside a healthy one; the hint cleared.
({PlanController c, Handle broken, Handle healthy, String before}) frozenScene(
    Switches sw, PlanController c) {
  final d = c.document;
  final broken =
      addObject(d, atSquare, const SquareParams(side: 1200, poisoned: true));
  final healthy =
      addObject(d, nearSquare(4000, -500, 0.25), const SquareParams(side: 500));
  sw.failing.add('reach');
  expect(c.execute(TransformNodeCommand(broken, nearSquare(100.5, 50.25, 0))),
      isFalse);
  // Fixture: the square is frozen and locked, one diagnostic.
  expect(c.frozen, {broken});
  expect(c.locked.value, {broken});
  expect(hookFailures(c), [('box', SquareParams.id)]);
  c.lockHint.value = false;
  return (c: c, broken: broken, healthy: healthy, before: canon(d));
}

List<(String, String?)> hookFailures(PlanController c) => [
      for (final d in c.diagnostics.value)
        if (d.code == KitDiagnosticCode.hookFailed) (d.kitId, d.subject),
    ];

const SquareParams rewritten = SquareParams(side: 1350.5, poisoned: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'FW-1 the host executes a write of a frozen square\'s own component: '
      'false, the lock hint, nothing changed, no new diagnostic', () {
    final sw = Switches();
    final c = PlanController(kits: kits(sw));
    addTearDown(c.dispose);
    final s = frozenScene(sw, c);
    // M-FW-1: `_LockCheck.apply` without its `on NonLiveWriteError`
    // mapping: execute throws the engine's StateError.
    expect(c.execute(SetComponentCommand<SquareParams>(s.broken, rewritten)),
        isFalse);
    expect(c.lockHint.value, isTrue);
    expect(canon(c.document), s.before);
    expect(hookFailures(c), [('box', SquareParams.id)]);
    // Positive control: the healthy square's own write lands.
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            s.healthy, const SquareParams(side: 640.5))),
        isTrue);
  });

  test(
      'FW-2 a kit tool commits the same write: refused as locked, the hint, '
      'no hookFailed of the tool, and the tool stays armed', () {
    final sw = Switches();
    late Handle target;
    final c = PlanController(
        kits: kits(sw,
            write: () => SetComponentCommand<SquareParams>(target, rewritten)));
    addTearDown(c.dispose);
    final s = frozenScene(sw, c);
    target = s.broken;
    useTestCamera(c);
    expect(c.selectTool('poke.write'), isTrue);
    final tools = c.toolController;
    // M-FW-1 again: the StateError is the tool's own failure, a hookFailed
    // of poke.write, and plan.select is armed.
    expect(
        () => tools.active
            .onPointerUp(eventAt(c, Vector2(6050.5, 2880.25)), tools.context),
        returnsNormally);
    expect(c.lockHint.value, isTrue);
    expect(hookFailures(c), [('box', SquareParams.id)]);
    expect(c.activeTool.value, 'poke.write');
    expect(canon(c.document), s.before);
  });

  test(
      'FW-3 a kit grip drag through plan.select writes onto a frozen '
      'neighbour: refused as locked, the hint, no exception', () {
    final sw = Switches();
    late Handle target;
    final c = PlanController(
        kits: kits(sw, grips: (services) => _NeighbourGrips(() => target)));
    addTearDown(c.dispose);
    final s = frozenScene(sw, c);
    target = s.broken;
    useTestCamera(c);
    expect(c.activeTool.value, 'plan.select');
    c.selection.replace([SelectionKey.root(s.healthy)]);
    final grip = nearSquare(4000, -500, 0.25).transformPoint(Vector2.zero());
    // M-FW-1 again: plan.select, a generic tool, rethrows the engine's
    // StateError from the release.
    expect(() => dragFrom(c, grip, grip + Vector2(310.5, -220.25)),
        returnsNormally);
    expect(c.lockHint.value, isTrue);
    expect(canon(c.document), s.before);
    expect(hookFailures(c), [('box', SquareParams.id)]);
  });
}
