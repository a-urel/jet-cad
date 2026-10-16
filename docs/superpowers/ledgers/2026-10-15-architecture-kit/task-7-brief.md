### Task 7: Grip refusals; a frozen object's references locked (spec C1.8, C1.10)

**Files:**
- Create (`packages/jet_cad_2d_plan/`): `test/kits/grip_refusal_test.dart`, `test/kits/frozen_references_test.dart`
- Modify (`packages/jet_cad_2d_plan/`): `lib/src/kits/guard.dart` (`GuardedGrips.drag`/`preview`, `GuardedTool.refusal`, `FailureBoundary.referencesOf`), `lib/src/controller/plan_controller.dart` (`execute` over a new `_refusal`, `_guardTool`, `_referencesOf`, the two boundaries' wiring), `lib/src/service/service_session.dart` (`referencesOf` passed to its boundary), `lib/src/kits/locks.dart` (docs only), `test/kits/locks_test.dart` (L-11's mutation comments only)
- Modify: `docs/kits.md` (§10.8), `docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md` (two lines in Task 2's `## Amendments` section)

**Interfaces:**
- Consumes:
  - Plan library today: `GuardedGrips` (`kits/guard.dart:485-560`), `GuardedTool` and `_failed` (`:253-321`), `FailureBoundary` and `_freeze` (`:585-621`), `LockSet.addBroken` (`kits/locks.dart:125-129`), `_LockCheck._first` and `_isRefusal` (`:289-320`), `PlanController.execute` (`controller/plan_controller.dart:793-817`), `_guardTool` (`:837-845`), `typeOf` (`:848-851`), `_open`'s boundary (`:1523-1530`), `_buildService` (`:1708-1720`), `ServiceSession`'s boundary (`service/service_session.dart:92-99`); the box kit (`test/support/box_kit.dart`: `Switches`, `SquareParams` with `partner`, `SquareType`, `boxKit`, `addObject`, `kids`, `canon`, `atSquare`, `nearSquare`), `test/support/tool_events.dart` (`useTestCamera`, `eventAt`).
  - Flutter layer (unchanged): `SelectTool.onPointerUp` executes the drop through `ctx.execute` and rethrows (`select_tool.dart:528-548`); `ToolContext.execute` is `document.commands.execute` (`tool.dart:108`); `GripDrag.command` asks the provider's `drag` at the drop's point (`grip_drag.dart:295-318`).
  - Engine: `ComponentRegistry.snapshotOf` (`document/component.dart:162`), `PermissionDeniedError` (`document/command.dart:72`), `RemoveEntityCommand`, `RemoveNodeCommand`.
- Produces: no new public name (Shared interfaces: "Task 7 (C1.8, C1.10): no new public names; LockSet locks the live references of frozen objects"). Internal: `GuardedTool({..., bool Function(Object error)? refusal})`, `FailureBoundary({..., Set<Handle> Function(DraftDocument document, Handle object)? referencesOf})`, `ServiceSession({..., Set<Handle> Function(DraftDocument document, Handle object)? referencesOf})`.

**Appendix A rows closed:** D-43, both items: `GuardedTool._failed`'s rethrow for a `plan.select` grip drop is retired (C1.8 (2), GR-drop-refuse), and the `_first` catch-all's probe is ruled (below). No old test file.

Plan decisions:
- **C1.8 (1), during the drag.** `GuardedGrips.drag` and `preview` catch `ArgumentError` (subclasses included, `RangeError`) before the catch-all: no move for that event (`drag` null, `preview` empty), the group not added to `_failed`, nothing reported. `gripsOf` and `movable` keep 2a's rule, as the spec names only the drag. Anything else `drag` or `preview` throws keeps 2a's rule (F-B1, `guard_boundaries_test.dart:78-117`, stays green).
- **C1.8 (2), at the drop: how "through `controller.execute`" is done.** `SelectTool` (jet_cad_2d_flutter, untouchable, A12) executes its one command through `ToolContext.execute`, which is `document.commands.execute` (`tool.dart:108`, a `final class` with no seam), and rethrows. So the plan library cannot route the drop through `PlanController.execute` itself; it gives the drop the same answer: `execute`'s refusal rule becomes one private function, `_refusal(Object error)` (the hint for `PlanLocked`; `DanglingReferenceError`, `PermissionDeniedError`, `ArgumentError`; a `KitHookFailure` reported once), which `execute` uses and which `_guardTool` gives to `plan.select`'s `GuardedTool` as its `refusal`. `GuardedTool._failed` asks it after its own `PlanLocked`/`DanglingReferenceError` branch (unchanged, so the hint is set as today for those) and before the rest: a refusal cancels the gesture, no exception, no `onFailed`. A `StateError` (`NonLiveWriteError` on an uncovered handle, `PartialMutationError`, any other) is not a refusal: `plan.select` rethrows it, as today (F-T4 stays green). Every other tool has no `refusal`, so its behaviour is unchanged (F-T1 to F-T3). This is the same outcome the spec asks for; see the interface problem below.
- **The ruling on `_first`'s catch-all (D-43's second item).** `_LockCheck._first` (`locks.dart:289-309`) sends any error that is neither a `KitHookFailure` nor a refusal (`_isRefusal`) to `onRefusedEdit` (`FailureBoundary.recoverRefused`), which probes every live kit object once (`_probeAll`, O(objects) `system.probe` calls). **Ruling: kept as it is.** The path is an error path (the engine's planner refusing a `generate`'s output, 2a final review I2); C1.8 (1)'s refused points never reach it (the guard answers null before any command exists); a drop whose command fails on an `ArgumentError` reaches it once, which is its purpose (a broken object found and frozen, the drop retried); and GR-drop-refuse pins that a drop no probe cures costs that one probe and then cancels quietly, with no diagnostic. Its cost is recorded, not changed: one probe of every live kit object per such failed edit.
- **C1.10, where the lock is taken.** Every freeze goes through `FailureBoundary._freeze` (`recover`, `recoverRefused`, `probeLoaded`, `reportUnreadable`), which adds the objects to the frozen set and calls `lock` (the controller's `lockBroken`, or `_lockFromCopy` in service). It now locks, with the frozen objects, the objects each one references, read by a callback the controller gives (`referencesOf`): the frozen object's type (`kits.typeOf(catalog.typeIdOf(d, h))`, which answers a frozen object's id), called on its component as stored (`snapshotOf(h).components`, the pair whose type id is the type's, so the call keeps the type's own `T`), keeping each referent the catalog names (a live object). A `references` that throws gives no referent: its type already failed and the object is frozen for it, with its diagnostic. An unreadable component (E4) is kept raw, names no type and gives none. `lockBroken` itself (an `@internal` test seam that locks without freezing) is unchanged: a locked object that is not frozen stays in every survey, so an edit of its referent already regenerates it and meets the lock.
- **What a locked referent refuses.** As any lock (2a P4): every edit that touches it, a delete included, on commit (`PlanLocked`, the hint) and up front (no grips, the gates shut). So an edit of another object whose regeneration would change the referent (a wall joined to a frozen door's host) is refused as well: it would change what the frozen object was drawn against. The referents are in `locked` (they join the lock set's broken roots); they are not frozen: they regenerate, and `liveTypeIdOf` (Task 6) still answers them.
- **Review Focus 3's "the drop commits that state".** The plan library's half is GR-drag-refuse: a refused point mid-drag gives no preview for that event and keeps the grips, the drop at an accepted point commits that point in one undo step, and a drop **at** a refused point commits nothing (the provider's `drag` is asked at the drop's point and refuses it, `grip_drag.dart:310-313`), with no exception and no diagnostic. "The last accepted state" at a refused drop is the kit's own to keep: see the interface problem.
- **The CHANGELOG** is written in Task 29.

- [ ] **Step 1: Precondition.** Task 6 is committed. Run `git status --short` (nothing under `packages/`) and `cd packages/jet_cad_2d_plan && flutter test test/kits/` (expected `All tests passed!`).

- [ ] **Step 2: The failing grip tests.** Create `packages/jet_cad_2d_plan/test/kits/grip_refusal_test.dart`:

```dart
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
        linePayload(t.transformPoint(Vector2(h, -h)),
            t.transformPoint(Vector2(h, h)))
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
/// square selected, the test camera.
({PlanController c, Handle square, _SideGrips grips}) scene() {
  final grips = _SideGrips();
  final c = PlanController(kits: [
    PlanKit(
      id: 'box',
      version: '1.4.0',
      types: [
        PlanType<SquareParams>(
            id: SquareParams.id,
            fromJson: SquareParams.fromJson,
            parametric: SquareType(Switches()),
            grips: (services) => grips),
      ],
      names: const KitNames({
        'en': {'type:box.square': 'Square'},
      }),
    ),
  ]);
  addTearDown(c.dispose);
  final d = c.document;
  final page = d.components.get<PageComponent>(d.rootHandle)!;
  expect(
      c.execute(SetComponentCommand<PageComponent>(
          d.rootHandle, page.copyWith(snapToGrid: false))),
      isTrue);
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
/// at the last, to the active tool.
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
      'exception, the grips still drag (Review Focus 3)', () {
    final s = scene();
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
    // M-GR-1a again: the drop's refusal fails the grips, with a diagnostic.
    expect(() => dragThrough(c, [at(1500), at(300)]), returnsNormally);
    expect(canon(c.document), committed);
    expect(c.document.commands.undoDepth, depth + 1);
    expect(c.diagnostics.value, isEmpty);
    expect(c.lockHint.value, isFalse);

    dragThrough(c, [at(1500), at(900.5)]);
    expect(sideOf(c, s.square), closeTo(900.5, 1e-6),
        reason: 'the grips still drag');
    expect(c.document.commands.undoDepth, depth + 2);
  });

  test(
      "GR-drop-refuse plan.select's drop refused as execute refuses it (an "
      'ArgumentError no probe cures, a PermissionDeniedError): the drag '
      'cancelled, no exception, nothing changed, no diagnostic; a '
      'StateError still goes on', () {
    for (final refusal in <Object>[
      ArgumentError.value(950.5, 'side', 'refused at the drop'),
      const PermissionDeniedError(Capability.components, 'Refusing'),
    ]) {
      final s = scene();
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
    final s = scene();
    s.grips.drop = (group, next) => _Refusing(StateError('not a refusal'));
    // M-GR-2c: `_refusal` answering true for every error.
    expect(() => dragThrough(s.c, [at(1200), at(1500)]), throwsStateError);
  });
}
```

  Run `cd packages/jet_cad_2d_plan && flutter test test/kits/grip_refusal_test.dart`. Expected: GR-1 fails (`Expected: empty Actual: [hookFailed [box box.square]: grips.drag: ...]`); GR-drag-refuse fails (the side stays 1200, or a diagnostic); GR-drop-refuse fails (`Invalid argument(s) (side): refused at the drop` thrown by `dragThrough`). The StateError half passes already (today's rule).

- [ ] **Step 3: The failing lock tests.** Create `packages/jet_cad_2d_plan/test/kits/frozen_references_test.dart`:

```dart
// Spec 3a C1.10 (Task 7), decision 6: a frozen object's live referents are
// locked with it. A frozen square references a healthy square (its
// cascade partner, as a frozen opening references its host wall): the
// partner can be neither edited nor deleted, up front or on commit, with
// PlanLocked's hint; a square nothing frozen references still edits and
// deletes. Squares off the origin, turned.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/box_kit.dart';

/// A host square, a poisoned square referencing it, and a third square;
/// the poisoned one frozen by one refused move (its reach throws); the
/// hint cleared.
({PlanController c, Handle host, Handle referrer, Handle other, String before})
    frozenReferrer() {
  final sw = Switches();
  final c = PlanController(kits: [boxKit(sw)]);
  addTearDown(c.dispose);
  final d = c.document;
  final host = addObject(
      d, nearSquare(2600.5, -900.25, 0.4), const SquareParams(side: 900));
  final referrer = addObject(
      d, atSquare, SquareParams(side: 1200, poisoned: true, partner: host));
  final other = addObject(
      d, nearSquare(-3100.75, 1800.5, -0.6), const SquareParams(side: 700));
  sw.failing.add('reach');
  expect(
      c.execute(TransformNodeCommand(referrer, nearSquare(100.5, 50.25, 0))),
      isFalse);
  expect(c.frozen, {referrer}, reason: 'fixture: the referrer is frozen');
  c.lockHint.value = false;
  return (
    c: c,
    host: host,
    referrer: referrer,
    other: other,
    before: canon(d)
  );
}

/// The select tool's delete of the group [h]: its leaves, then the group
/// (`select_tool.dart:787-792`, `_groupCascade`).
DraftCommand deleteOf(DraftDocument d, Handle h) => CompoundCommand([
      for (final k in kids(d, h)) RemoveEntityCommand(k),
      RemoveNodeCommand(h),
    ], label: 'Delete');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      "FL-edit a frozen square's partner cannot be edited: false, the "
      'hint, nothing changed; a square nothing frozen references edits', () {
    final s = frozenReferrer();
    final c = s.c;
    // M-FL-1: `FailureBoundary._freeze` locking the frozen objects alone.
    expect(c.locked.value, {s.referrer, s.host});
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            s.host, const SquareParams(side: 640.5))),
        isFalse);
    expect(c.lockHint.value, isTrue);
    c.lockHint.value = false;
    expect(
        c.execute(
            TransformNodeCommand(s.host, nearSquare(2900.5, -700.25, 0.1))),
        isFalse);
    expect(c.lockHint.value, isTrue);
    expect(canon(c.document), s.before);
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            s.other, const SquareParams(side: 640.5))),
        isTrue,
        reason: 'positive control');
  });

  test(
      "FL-delete a frozen square's partner cannot be deleted: the gates "
      'refuse it, and its delete command is refused as locked; a square '
      'nothing frozen references is deleted by the same command', () {
    final s = frozenReferrer();
    final c = s.c;
    final d = c.document;
    c.selection.replace([SelectionKey.root(s.host)]);
    // M-FL-1 again: the gates are open and the partner goes, leaving the
    // frozen square referencing a dead handle.
    expect(c.deleteSelection(), isFalse);
    expect(c.execute(deleteOf(d, s.host)), isFalse);
    expect(c.lockHint.value, isTrue);
    expect(canon(d), s.before);
    expect(d.tree[s.host], isNotNull);
    expect(c.execute(deleteOf(d, s.other)), isTrue, reason: 'positive control');
    expect(d.tree[s.other], isNull);
  });
}
```

  Run `cd packages/jet_cad_2d_plan && flutter test test/kits/frozen_references_test.dart`. Expected: FL-edit fails at `c.locked.value` (`Actual: {<referrer>}`); FL-delete fails at `deleteSelection()` (`true`).

- [ ] **Step 4: The guard.** `packages/jet_cad_2d_plan/lib/src/kits/guard.dart`:
  1. `GuardedGrips`' doc (`:481-484`) becomes:

```dart
/// The grip provider behind the boundary. An `ArgumentError` from `drag`
/// or `preview` is the kit refusing that point (spec 3a C1.8): no move for
/// that event (null, no preview), nothing reported, the grips kept.
/// Anything else a call throws is reported (once per type, through
/// [typeIdOf]) and that object has no grips, no drag and does not move
/// until the document is replaced (a drag in flight is refused: its
/// `drag` answers null), 2a's rule.
```

  2. In `drag`, between `return _inner.drag(d, group, grip, world);`'s `}` and `catch (error) {`, add `on ArgumentError { return null; }`, so the body reads:

```dart
    try {
      return _inner.drag(d, group, grip, world);
    } on ArgumentError {
      // Spec 3a C1.8 (1): the kit refuses this point; the grips stay.
      return null;
    } catch (error) {
      _fail(d, group, 'drag', error);
      return null;
    }
```

  and in `preview` likewise:

```dart
    try {
      return _inner.preview(d, group, grip, world);
    } on ArgumentError {
      // Spec 3a C1.8 (1): the kit refuses this point; the grips stay.
      return const [];
    } catch (error) {
      _fail(d, group, 'preview', error);
      return const [];
    }
```

  3. `GuardedTool`: its doc's bullet list gains, after the `KitHookFailure` bullet: `/// - Given [refusal] (plan.select's, spec 3a C1.8), an error the controller's `execute` refuses is a refusal: the gesture is cancelled, with no exception and no diagnostic beyond the one `execute` would report.`; the constructor gains `this.refusal,` after `required this.onFailed,`; after `final VoidCallback onFailed;` add:

```dart

  /// What the controller's `execute` refuses (spec 3a C1.8 (2)): given to
  /// plan.select only, whose drop is executed by the Flutter layer's
  /// `SelectTool` and would otherwise escape it. Null for every other tool.
  final bool Function(Object error)? refusal;
```

  and `_failed` gains, right after the `PlanLocked`/`DanglingReferenceError` branch's closing `}`:

```dart
    // Spec 3a C1.8 (2): a drop refused as `execute` refuses an edit cancels
    // the drag; a StateError is no refusal and goes on below, as today.
    final refused = refusal;
    if (refused != null && refused(error)) {
      _cancelInner(ctx);
      return;
    }
```

  4. `FailureBoundary`: the constructor gains `this.referencesOf,` after `required this.damage,`; after `final void Function(PartialMutationError error) damage;` add:

```dart

  /// The objects a frozen object references (spec 3a C1.10), locked with
  /// it: the controller reads the object's type's `references`. Null: none.
  final Set<Handle> Function(DraftDocument document, Handle object)?
      referencesOf;
```

  and `_freeze` becomes:

```dart
  void _freeze(Set<Handle> objects) {
    frozen.addAll(objects);
    // Spec 3a C1.10 (decision 6): a frozen object is in no survey, so an
    // edit of a live object it references would regenerate that one without
    // it (a wall uncut beside a frozen door), and its delete would not
    // cascade to it: what it references is locked with it.
    final references = referencesOf;
    lock({
      ...objects,
      if (references != null)
        for (final object in objects) ...references(document, object),
    });
  }
```

- [ ] **Step 5: The controller and the service copy.**
  1. `lib/src/controller/plan_controller.dart`, `execute` (`:793-817`): its doc's sentence "The refusal caught here: ..." stays; append to the doc `/// The rule is [_refusal]'s, which plan.select's drop shares (spec 3a C1.8).`; its body becomes:

```dart
  bool execute(DraftCommand command) {
    if (_service != null) return false;
    _pendingDefinitions.clear();
    try {
      document.commands.execute(command);
      return true;
    } catch (error) {
      if (_refusal(error)) return false;
      rethrow;
    }
  }

  /// Whether [error], thrown by an edit of the design, is a refusal: what
  /// [execute] answers false for, and what cancels plan.select's drop
  /// (spec 3a C1.8). [PlanLocked] ([lockHint] set), `DanglingReferenceError`,
  /// `PermissionDeniedError`, `ArgumentError`, and a [KitHookFailure] the
  /// retry did not cure (one diagnostic). Anything else, a `StateError`
  /// (`PartialMutationError` included) above all, is the caller's.
  bool _refusal(Object error) {
    switch (error) {
      case PlanLocked():
        lockHint.value = true;
        return true;
      case DanglingReferenceError() ||
            PermissionDeniedError() ||
            ArgumentError():
        return true;
      case final KitHookFailure failure:
        _reportFailure(failure);
        return true;
    }
    return false;
  }
```

  2. `_guardTool` (`:837-845`) gains, after `lockHint: lockHint,`:

```dart
      // Spec 3a C1.8 (2): plan.select's drop is refused as execute refuses.
      refusal: toolId == planSelectToolId ? _refusal : null,
```

  3. After `typeOf` (`:848-851`) add:

```dart

  /// The live objects [object] references in [d] (spec 3a C1.10): its
  /// type's `references`, called on its component as stored (the pair of
  /// its snapshot whose type id is the type's, so the call keeps the
  /// type's own `T`), each one a loaded kit's object in [d]. Empty when no
  /// loaded type names [object] (a missing kit's, an unreadable one's), and
  /// when `references` throws: the type already failed, and the object is
  /// frozen for it, with its diagnostic.
  Set<Handle> _referencesOf(DraftDocument d, Handle object) {
    final typeId = catalog.typeIdOf(d, object);
    final type = typeId == null ? null : kits.typeOf(typeId);
    if (type == null) return const {};
    for (final (id, component) in d.components.snapshotOf(object).components) {
      if (id != typeId) continue;
      try {
        return {
          for (final h in type.parametric.references(component))
            if (catalog.typeIdOf(d, h) != null) h,
        };
      } catch (_) {
        return const {};
      }
    }
    return const {};
  }
```

  4. `_open`'s `session.boundary = FailureBoundary(...)` gains `referencesOf: _referencesOf,` after `damage: _damage,`; `_buildService`'s `ServiceSession(...)` gains `referencesOf: _referencesOf,` after `damage: _damageCopy,`.
  5. `lib/src/service/service_session.dart`: the constructor's named parameters gain `Set<Handle> Function(DraftDocument document, Handle object)? referencesOf,` after `bool Function()? moves,`; its `FailureBoundary(...)` gains `referencesOf: referencesOf,` after `damage: (error) => damage(this, error),`.
  6. `lib/src/kits/locks.dart`: `LockSet.objects`' doc becomes `/// The locked objects: a missing kit's, an unknown type's, a broken one's, and the live objects a frozen one references (spec 3a C1.10). The guarded definitions are not listed.`; `addBroken`'s doc becomes `/// Adds [objects] (broken, Task 11, or referenced by a frozen object, spec 3a C1.10) and refreshes what they contain.`
  7. `test/kits/locks_test.dart`, L-11's mutation comments only (assertions untouched): `:397` `// M-L11a: \`on PlanLocked\` dropped:` → `// M-L11a: \`_refusal\`'s PlanLocked case dropped:`; `:404` → `// M-L11b: ArgumentError dropped from \`_refusal\`'s refusal case.`; `:406-407` → `// M-L11c: \`_refusal\` answering true for a StateError (or for anything): a StateError is the caller's.` (split over lines as now); `:423` → `// M-L11d: DanglingReferenceError dropped from \`_refusal\`'s refusal case:` (the rest of that comment unchanged).

  Run `cd packages/jet_cad_2d_plan && dart format . && flutter analyze && flutter test test/kits/ test/controller/plan_controller_test.dart`. Expected: `No issues found!`, `All tests passed!` (F-B1, F-T1 to F-T6, FW-1 to FW-3, L-11 among them).

- [ ] **Step 6: Docs and the amendment lines.**
  1. `docs/kits.md` §10.8's row `` | grips, an attachment provider | none for that object; no attachment | `` becomes `` | grips, an attachment provider | an `ArgumentError` from a grip's `drag` or `preview` refuses that point (no move, nothing reported); anything else: no grips for that object; no attachment | ``; after the table's paragraph on missing kits add: `A frozen object's live referents (an opening's host wall) are locked with it: they cannot be edited or deleted while it is frozen.`
  2. `docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md`, Task 2's `## Amendments` section: append

```markdown
- **P4, the failure boundary's grips row** (3a C1.8): an `ArgumentError`
  from a kit grip's `drag` or `preview` refuses that point only (no move
  for that event, no diagnostic, the grips kept); anything else keeps the
  row. plan.select's drop is refused as `execute` refuses an edit (its
  `false`: the drag cancelled, no exception); a `StateError` goes on.
- **P4, the lock set** (3a C1.10, decision 6): the live objects a frozen
  object references are locked with it, so they can be neither edited nor
  deleted, up front or on commit (`PlanLocked`, the hint).
```

  Run `cd packages/jet_cad_2d_kit && flutter test test/invariants/doc_snippets_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 7: Format.** `cd packages/jet_cad_2d_plan && dart format .`.

- [ ] **Step 8: The gates.** From the repository root:
  - `cd packages/jet_cad_2d_plan && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0.
  - `cd packages/jet_cad_2d_kit && flutter test test/invariants/doc_snippets_test.dart` — `All tests passed!` (`docs/kits.md` changed).
  - `git status --short`: only this task's files.

- [ ] **Step 9: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/kits/guard.dart packages/jet_cad_2d_plan/lib/src/kits/locks.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/src/service/service_session.dart packages/jet_cad_2d_plan/test/kits/grip_refusal_test.dart packages/jet_cad_2d_plan/test/kits/frozen_references_test.dart packages/jet_cad_2d_plan/test/kits/locks_test.dart docs/kits.md docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md
git commit -m "$(cat <<'EOF'
feat(plan): grip refusals; a frozen object's referents locked (spec 3a C1.8, C1.10)

An ArgumentError from a kit grip's drag or preview refuses that point only:
no move, no diagnostic, the grips kept. plan.select's drop is refused as
execute refuses an edit, one shared rule, so a refused drop cancels the
drag instead of escaping it; a StateError still goes on. A frozen object's
live referents are locked with it. Ruled: the _first catch-all's probe
stays (one probe of the live kit objects per edit failing on no hook).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 10: Mutation check** (committed files only; after each: run the named test, see it red, quote the red line, `git checkout -- <file>`, `git diff --quiet -- <file>` exits 0). Run `cd packages/jet_cad_2d_plan && flutter test test/kits/grip_refusal_test.dart` or `test/kits/frozen_references_test.dart`.
  - M-GR-1a `guard.dart`: delete `GuardedGrips.drag`'s `on ArgumentError { ... }` clause → GR-1 red (a `hookFailed` after `drag`); GR-drag-refuse red (a diagnostic, and the last drag does not commit).
  - M-GR-1b `guard.dart`: delete `GuardedGrips.preview`'s `on ArgumentError { ... }` clause → GR-1 red (a `hookFailed` after `preview`); GR-drag-refuse red (the side stays 1200).
  - M-GR-2a `plan_controller.dart`: delete `refusal: toolId == planSelectToolId ? _refusal : null,` from `_guardTool` → GR-drop-refuse red (`ArgumentError` thrown).
  - M-GR-2b `guard.dart`: delete the `final refused = refusal; if (...) { ... }` block from `_failed` → GR-drop-refuse red.
  - M-GR-2c `plan_controller.dart`: add `default: return true;` as `_refusal`'s last case (and delete its `return false;`) → GR-drop-refuse red (no `StateError`); L-11 red too (M-L11c).
  - M-L11a `plan_controller.dart`: delete `_refusal`'s `case PlanLocked(): ...` → `locks_test.dart` L-11 red.
  - M-L11b `plan_controller.dart`: delete `|| ArgumentError()` from `_refusal` → L-11 red.
  - M-L11d `plan_controller.dart`: delete `DanglingReferenceError() ||` from `_refusal` → L-11 red.
  - M-FL-1 `guard.dart`: in `_freeze`, `lock({...})` → `lock(objects)` → FL-edit red (`{referrer}`), FL-delete red (`deleteSelection()` true).
  - M-FL-2 `plan_controller.dart`: delete `referencesOf: _referencesOf,` from `_open`'s `FailureBoundary(...)` → FL-edit and FL-delete red.
  - M-FL-3 `plan_controller.dart`: in `_referencesOf`, `if (id != typeId) continue;` → `if (id == typeId) continue;` → FL-edit red (no referent).

  Quote each red line.

#### Interface problem

1. **C1.8 (2) "plan.select executes the drop command through `controller.execute`" cannot be done literally.** The drop is executed by `SelectTool.onPointerUp` (`packages/jet_cad_2d_flutter/lib/src/select_tool.dart:528-548`) through `ctx.execute(command)`, and `ToolContext` is a `final class` whose `execute` is `document.commands.execute(command)` (`packages/jet_cad_2d_flutter/lib/src/tool.dart:82-109`); jet_cad_2d_flutter may not change (Global Constraints, A12). **Proposed fix (taken in this task, no public name):** `execute`'s refusal rule becomes one function, `_refusal`, used by `execute` and given to plan.select's `GuardedTool` as `refusal`; the drop then gets exactly `execute`'s answer (a refusal cancels the drag, a `StateError` goes on). The 3a spec's C1.8 wording may want "is refused as `controller.execute` refuses it" in its next revision.
2. **(Resolved by rulings R-P15 and R-P17: a drop at a refused point commits nothing; the preview there is empty, today's.)** **Review Focus 3's "the drop commits that state" (the last accepted one) is not the plan library's to give.** At the drop, `GripDrag.command` asks the provider's `drag` at the drop's own point (`packages/jet_cad_2d_flutter/lib/src/grip_drag.dart:303-313`); a point the kit refuses there gives no command, so the plan commits nothing (GR-drag-refuse). Today's wall grips do the same: `WallGrips.drag` answers null for a wall no longer than `wallJoin.linear` (`packages/jet_cad_floor_plan/lib/src/parametric/wall_grips.dart:60-63, 198`), so today's drop at a too-short point commits nothing either. **Proposed fix:** Review Focus 3's expectation reads "a refused event shows no preview and reports nothing; a drop at an accepted point commits it in one undo step; a drop at a refused point commits nothing; the grips stay usable" unless Task 12's oracle (today's `wall_grips_test`) shows otherwise; if the human wants "the last accepted state" at a refused drop, that is the kit's wall grips keeping it (a kit-side behaviour change, against A12), to be ruled before Task 12.

---

