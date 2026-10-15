// Spec 3a C1.8 (Task 7), Review Focus 3's contract half: a kit grip fails
// in two places. During the drag, an ArgumentError from the kit's `drag` or
// `preview` is that point refused: no move for that event, nothing
// reported, the grips kept (anything else keeps 2a's rule, F-B1). At the
// drop, plan.select's command is refused as the controller's execute
// refuses an edit: the drag cancelled, no exception; a StateError still
// goes on (F-T4). The square sits off the origin, turned 30 degrees, on a
// 1:50 page without grid snap; the camera is turned, flipped, 0.25 px/mm.
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/kits/guard.dart'
    show DiagnosticsLog, GuardedGrips;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/box_kit.dart';
import '../support/tool_events.dart';

/// The shortest side the square's grip accepts.
const double kShortest = 400;

/// The square's one stretch grip, at the middle of its right edge: a drag
/// sets the side to twice the drop's distance along the square's own x
/// axis. A side below [kShortest] is refused with an ArgumentError, in
/// `drag` and in `preview` alike, as a wall-end grip refuses a wall too
/// short to join. [drop], when set, replaces the command `drag` answers.
final class _SideGrips implements ObjectGripProvider {
  DraftCommand Function(Handle group, SquareParams next)? drop;
  int refusals = 0;

  static Transform2 _toWorld(DraftDocument d, Handle group) =>
      (d.tree[group]! as GroupNode).transform;

  SquareParams _next(DraftDocument d, Handle group, Vector2 world) {
    final p = d.components.get<SquareParams>(group)!;
    final side = 2 * _toWorld(d, group).invert().transformPoint(world).x;
    if (side < kShortest) {
      refusals++;
      throw ArgumentError.value(side, 'side', 'is below $kShortest');
    }
    return p.copyWith(side: side);
  }

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    final p = d.components.get<SquareParams>(group);
    if (p == null) return const [];
    final g = _toWorld(d, group).transformPoint(Vector2(p.side / 2, 0));
    return [Grip(GripRole.stretch, 0, g.x, g.y)];
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    final next = _next(d, group, world);
    return drop?.call(group, next) ??
        SetComponentCommand<SquareParams>(group, next);
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    final h = _next(d, group, world).side / 2;
    final t = _toWorld(d, group);
    return [
      (
        EntityKind.line,
        linePayload(
            t.transformPoint(Vector2(h, -h)), t.transformPoint(Vector2(h, h)))
      ),
    ];
  }

  @override
  bool movable(DraftDocument d, Handle group) => true;
}

/// A command whose `apply` throws [error] before it touches anything.
final class _Refusing extends DraftCommand {
  _Refusing(this.error);
  final Object error;
  @override
  Capability get capability => Capability.components;
  @override
  String get label => 'Refusing';
  @override
  CommandResult apply(CommandTarget target) => throw error;
}

/// An inner grip provider throwing [error] from every call while it is
/// set.
final class _Throwing implements ObjectGripProvider {
  _Throwing(this.error);
  Object? error;

  void _maybe() {
    final e = error;
    if (e != null) throw e;
  }

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    _maybe();
    return const [Grip(GripRole.stretch, 0, 7010, 3020)];
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    _maybe();
    return TransformNodeCommand(
        group, Transform2.translation(world.x, world.y));
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    _maybe();
    return [(EntityKind.line, linePayload(Vector2(7010, 3020), world))];
  }

  @override
  bool movable(DraftDocument d, Handle group) => true;
}

/// A controller over the square with [_SideGrips], grid snap off, the
/// square selected, the test camera. Async: the tool reads the page through
/// a notifier fed by the document's (asynchronous) change stream, so the
/// page edit is settled before any drag. Given [sw], the square's hooks
/// are switched by it and the `ring` kit's disc is loaded too.
Future<({PlanController c, Handle square, _SideGrips grips})> scene(
    [Switches? sw]) async {
  final grips = _SideGrips();
  final c = PlanController(kits: [
    PlanKit(
      id: 'box',
      version: '1.4.0',
      types: [
        PlanType<SquareParams>(
            id: SquareParams.id,
            fromJson: SquareParams.fromJson,
            parametric: SquareType(sw ?? Switches()),
            grips: (services) => grips),
      ],
      names: const KitNames({
        'en': {'type:box.square': 'Square'},
      }),
    ),
    if (sw != null) ringKit(sw),
  ]);
  addTearDown(c.dispose);
  final d = c.document;
  final page = d.components.get<PageComponent>(d.rootHandle)!;
  expect(
      c.execute(SetComponentCommand<PageComponent>(
          d.rootHandle, page.copyWith(snapToGrid: false))),
      isTrue);
  await settleHistory();
  expect(c.page.value!.snapToGrid, isFalse, reason: 'fixture: no grid snap');
  final square = addObject(d, atSquare, const SquareParams(side: 1200));
  useTestCamera(c);
  c.selection.replace([SelectionKey.root(square)]);
  return (c: c, square: square, grips: grips);
}

/// The world point of the grip of a square of [side] at [atSquare].
Vector2 at(double side) => atSquare.transformPoint(Vector2(side / 2, 0));

double sideOf(PlanController c, Handle h) =>
    c.document.components.get<SquareParams>(h)!.side;

/// A primary press at [points]' first, a move to each later one, a release
/// at the last, to the active tool. The caller settles the change stream
/// first ([settleHistory]): the tool's page and grips follow the document
/// through it.
void dragThrough(PlanController c, List<Vector2> points) {
  final tools = c.toolController;
  tools.active.onPointerMove(eventAt(c, points.first), tools.context);
  tools.active.onPointerDown(
      eventAt(c, points.first, buttons: kPrimaryButton), tools.context);
  for (final p in points.skip(1)) {
    tools.active
        .onPointerMove(eventAt(c, p, buttons: kPrimaryButton), tools.context);
  }
  tools.active.onPointerUp(eventAt(c, points.last), tools.context);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      "GR-1 an ArgumentError from a kit's drag or preview is that point "
      'refused: null or no preview, nothing reported, the object keeps its '
      'grips; a StateError keeps 2a\'s rule', () {
    final d = DraftDocument.empty();
    final log = DiagnosticsLog();
    addTearDown(log.dispose);
    final inner = _Throwing(ArgumentError('too short'));
    final grips = GuardedGrips(inner,
        typeIdOf: (doc, group) => SquareParams.id, log: log);
    const group = Handle(4321);
    const grip = Grip(GripRole.stretch, 0, 7010, 3020);
    final world = Vector2(7100.5, 3100.25);
    expect(grips.drag(d, group, grip, world), isNull);
    // M-GR-1a: `GuardedGrips.drag` without its `on ArgumentError`.
    expect(log.entries.value, isEmpty);
    expect(grips.preview(d, group, grip, world), isEmpty);
    // M-GR-1b: `GuardedGrips.preview` without its `on ArgumentError`.
    expect(log.entries.value, isEmpty);
    inner.error = null;
    expect(grips.gripsOf(d, group), hasLength(1), reason: 'not failed');
    expect(grips.drag(d, group, grip, world), isNotNull);
    expect(grips.preview(d, group, grip, world), hasLength(1));
    // A StateError: 2a's rule (F-B1), the object has no grips from then on.
    inner.error = StateError('broken');
    expect(grips.drag(d, group, grip, world), isNull);
    inner.error = null;
    expect(grips.gripsOf(d, group), isEmpty);
    expect(log.entries.value, hasLength(1));
  });

  test(
      'GR-drag-refuse a grip drag through plan.select passing a refused '
      'point: the drop at an accepted point commits it in one undo step; a '
      'drop at a refused point commits nothing; no diagnostic, no '
      'exception, the grips still drag (Review Focus 3)', () async {
    final s = await scene();
    final c = s.c;
    final depth = c.document.commands.undoDepth;
    // M-GR-1b again: the refused preview fails the square's grips, and the
    // drop commits nothing (and reports a hookFailed).
    expect(
        () => dragThrough(c, [at(1200), at(300), at(1500)]), returnsNormally);
    expect(s.grips.refusals, greaterThan(0),
        reason: 'premise: a point was refused mid-drag');
    expect(sideOf(c, s.square), closeTo(1500, 1e-6));
    expect(c.document.commands.undoDepth, depth + 1);
    expect(c.diagnostics.value, isEmpty);

    final committed = canon(c.document);
    // The grips follow the commit through the change stream.
    await settleHistory();
    // M-GR-1a again: the drop's refusal fails the grips, with a diagnostic.
    expect(() => dragThrough(c, [at(1500), at(300)]), returnsNormally);
    expect(canon(c.document), committed);
    expect(c.document.commands.undoDepth, depth + 1);
    expect(c.diagnostics.value, isEmpty);
    expect(c.lockHint.value, isFalse);

    await settleHistory();
    dragThrough(c, [at(1500), at(900.5)]);
    expect(sideOf(c, s.square), closeTo(900.5, 1e-6),
        reason: 'the grips still drag');
    expect(c.document.commands.undoDepth, depth + 2);
  });

  test(
      "GR-drop-refuse plan.select's drop refused as execute refuses it (an "
      'ArgumentError no probe cures, a PermissionDeniedError): the drag '
      'cancelled, no exception, nothing changed, no diagnostic; a '
      'StateError still goes on', () async {
    for (final refusal in <Object>[
      ArgumentError.value(950.5, 'side', 'refused at the drop'),
      const PermissionDeniedError(Capability.components, 'Refusing'),
    ]) {
      final s = await scene();
      final c = s.c;
      s.grips.drop = (group, next) => _Refusing(refusal);
      final before = canon(c.document);
      final depth = c.document.commands.undoDepth;
      // M-GR-2a: `_guardTool` without `refusal:`; M-GR-2b: `_failed`
      // without its refusal branch: plan.select rethrows the drop's error.
      expect(() => dragThrough(c, [at(1200), at(1500)]), returnsNormally,
          reason: '$refusal');
      expect(canon(c.document), before, reason: '$refusal');
      expect(c.document.commands.undoDepth, depth, reason: '$refusal');
      expect(c.diagnostics.value, isEmpty, reason: '$refusal');
      expect(c.activeTool.value, 'plan.select', reason: '$refusal');
    }
    final s = await scene();
    s.grips.drop = (group, next) => _Refusing(StateError('not a refusal'));
    // M-GR-2c: `_refusal` answering true for every error.
    expect(() => dragThrough(s.c, [at(1200), at(1500)]), throwsStateError);
  });

  test(
      "GR-drop-hook a kit hook failing at plan.select's drop, the retry "
      'failing on a second type: the drag cancelled, no exception, nothing '
      'changed, each failing type reported once, plan.select still armed',
      () async {
    final sw = Switches();
    final s = await scene(sw);
    final c = s.c;
    final d = c.document;
    // A broken square and a broken disc (a place reader), both off the
    // origin and turned: the drop's edit fails on the square, which is
    // frozen; its retry fails on the disc.
    final poisoned = addObject(d, nearSquare(-2600.5, 1900.25, -0.7),
        const SquareParams(side: 800, poisoned: true));
    final disc = addObject(d, nearSquare(3100.75, -1500.5, 0.5),
        const DiscParams(radius: 400, poisoned: true));
    expect(poisoned.value < disc.value, isTrue,
        reason: 'premise: the square is surveyed first');
    await settleHistory();
    final before = canon(d);
    sw.failing.add('reach');
    expect(() => dragThrough(c, [at(1200), at(1500)]), returnsNormally);
    expect(c.frozen, {poisoned},
        reason: 'premise: the first type froze; the second failed again');
    expect(canon(d), before);
    expect(sideOf(c, s.square), 1200);
    // M-GR-3: `_refusal`'s KitHookFailure case without `_reportFailure`:
    // the retry's failure (the disc's) goes unreported.
    expect([
      for (final f in c.diagnostics.value) (f.kitId, f.subject, f.code)
    ], [
      ('box', SquareParams.id, KitDiagnosticCode.hookFailed),
      ('ring', DiscParams.id, KitDiagnosticCode.hookFailed),
    ]);
    expect(c.activeTool.value, 'plan.select');
    expect(c.lockHint.value, isFalse);
  });
}
