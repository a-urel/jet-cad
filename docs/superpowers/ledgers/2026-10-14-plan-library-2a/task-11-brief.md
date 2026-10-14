### Task 11: The failure boundary (spec P4 "The failure boundary")

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/kits/guard.dart`, `packages/jet_cad_2d_plan/lib/src/kits/section_boundary.dart`
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/diagnostics_log.dart` (Task 8's minimal log, replaced by the full one), `packages/jet_cad_2d_plan/lib/src/kits/locks.dart` (the expander's two hooks and the retry), `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` and `packages/jet_cad_2d_plan/lib/src/controller/session.dart` (Task 8 keeps the per-document build and teardown in `DocumentSession`) (registration, the log, the per-document boundary, tools, grips, `execute`, `save`, five new members), `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (export `KitHookFailure`)
- Test: `packages/jet_cad_2d_plan/test/kits/guarded_type_test.dart`, `test/kits/failure_flow_test.dart`, `test/kits/guarded_tool_test.dart`, `test/kits/guard_boundaries_test.dart`

(Paths below are under `packages/jet_cad_2d_plan/`.)

**Interfaces:**
- Consumes:
  - Engine: `ParametricType<T>` and its thirteen members (`jet_cad_2d/lib/src/parametric/parametric_system.dart:25-176`); `ParametricCatalog.register` (`:495-503`, which reads `contributesPlace` and `readsPlaces`), `typeIds`, `typeIdOf` (E1); `ParametricSystem.drift()` (`:595-610`), `diagnostics()`, `probe(Handle)` (E2: runs every hook an edit can call, `null` for a healthy, frozen or non-object handle, mutates nothing), `isFrozen` (E2); `PartialMutationError` (E3: `regeneration.dart` three sites and `CompoundCommand.apply`); E4's `Diagnostic(code: 'component.unreadable', handles: [h], message: '<typeId>: <error>')` from `decodePlan` (Task 7 passes `keepUnreadableComponents: true`); `DanglingReferenceError` (`parametric_system.dart:353`), which E2 raises for a `cascade` referrer of a frozen object (a refusal, not a kit failure); `CommandDispatcher.notifyLoaded` (`undo.dart:261-266`).
  - Flutter layer: `Tool` (`tool.dart:116-150`), `ToolContext`, `ToolController.activate`, `ObjectGripProvider`.
  - Contract: `TypeGuard`, `PlanType.registerInto(catalog, {TypeGuard? guard})`, `PlanTool.create`, `PlanType.gripsFor`, `AttachmentProvider`, `AttachmentQuery`, `Attachment`, `KitDiagnostic`, `KitDiagnosticCode`, `kitOfKey`.
  - Task 7: `decodePlan(String text, {required void Function(ComponentRegistry) register, required List<Diagnostic> diagnostics})`, `PlanFormatException`, `PlanFormatCode.damagedUnsavable`.
  - Task 9: `PlanStrings.of(context).sectionFailed`.
  - Task 10: `LockExpander`, `_LockCheck`, `LockSet`, `LockedGrips`, `PlanLocked`, `PlanController.lockBroken`.
  - Task 8: see "Assumed from earlier tasks".
- Produces:
  - Exported from the barrel: `final class KitHookFailure implements Exception` — `const KitHookFailure(String kitId, String typeId, String hook, Object error)`, fields `kitId`, `typeId`, `hook`, `error`.
  - On `PlanController` (public): `ValueListenable<bool> get damaged` (a `ValueNotifier<bool>` behind it; Task 20's bar listens); `ValueNotifier<bool> get lockHint` (set when an edit is refused by a lock; Task 15's canvas shows and clears it); `bool isToolDisabled(String toolId)` (its factory threw; Task 16's palette greys it); `bool execute(DraftCommand command)` — the guarded commit path of every widget and panel (Tasks 17, 18; controller ruling R-b): `true` when applied; `false` when refused, the refusal caught here: `PlanLocked` (after setting `lockHint`), `DanglingReferenceError`, `ArgumentError`, and a `KitHookFailure` that the retry did not cure (one diagnostic). `StateError` (`PartialMutationError` included, after the damage is handled) passes through to the caller.
  - Internal (`lib/src/kits/guard.dart`): `final class GuardedType<T extends Component> implements ParametricType<T>` (`const GuardedType(String kitId, String typeId, ParametricType<T> inner)`); `final class PlanTypeGuard implements TypeGuard` (`const PlanTypeGuard()`); `final class DiagnosticsLog` (Task 8's, completed in place in `lib/src/controller/diagnostics_log.dart`, controller ruling R-j, re-exported by `guard.dart`: still a `ValueListenable<List<KitDiagnostic>>` with Task 8's `report`, `reportAll` and `clearPlanScoped`, plus `ValueListenable<List<KitDiagnostic>> get entries` (itself), `bool add(KitDiagnostic)`, `bool addAfterFrame(KitDiagnostic)`; deduplicated by kit id, subject and code); `final class GuardedTool extends Tool` (`GuardedTool({required Tool inner, required String kitId, required String toolId, required DiagnosticsLog log, required ValueNotifier<bool> lockHint, required VoidCallback onFailed})`, `Tool get inner`); `T? guardFactory<T extends Object>(String kitId, String subject, T Function() create, DiagnosticsLog log)`; `final class GuardedGrips implements ObjectGripProvider` (`GuardedGrips(ObjectGripProvider inner, {required String? Function(DraftDocument, Handle) typeIdOf, required DiagnosticsLog log})`); `Attachment? guardAttachment(String kitId, AttachmentProvider provider, AttachmentQuery query, void Function(KitDiagnostic) report)` (Task 14's registry calls it with its `report`, the controller's `_diagnostics.add`); `final class FailureBoundary` (`recover`, `probeType`, `probeLoaded`, `reportUnreadable`, `partialMutation`).
  - Internal (`lib/src/kits/section_boundary.dart`): `class KitSectionBoundary extends StatelessWidget` — `const KitSectionBoundary({Key? key, required String kitId, required String typeId, required DiagnosticsLog log, required Widget? Function(BuildContext) builder})` (Task 17 wraps every `PlanType.sectionFor` call in it).
  - On `LockExpander` (Task 10's): `bool Function(KitHookFailure)? onHookFailure`, `void Function(PartialMutationError)? onPartialMutation`.

Plan decision (where the retry lives): a tool commits through `ToolContext.execute`, which calls `document.commands.execute` directly (`tool.dart:109`), and a host may do the same; so the controller cannot see every command. The one place every `execute` passes is the expander slot, and Task 10's lock wrapper already holds it. So the wrapper catches a `KitHookFailure` from the parametric edit it applies, asks the failure boundary to recover (diagnostic, probe that type's objects with `ParametricSystem.probe`, freeze and lock every one that fails, which clears the history), and, when something was frozen, re-expands the **original** command through the parametric expander (a `ParametricEdit` applies once, `parametric_system.dart:733-736`) and applies it once more, inside the same `execute`: one undo step, recorded after `apply` returns (`undo.dart:195-196`). A second failure propagates: the command is refused. When the probe froze nothing, the retry would repeat the same failure, so it is skipped. The engine has rolled the failed edit back before rethrowing (`regeneration.dart:1011-1014`, `:1033-1045`), so the probe and the retry start from the state before the edit.

Plan decision (the load-time check): after a load, the boundary runs `ParametricSystem.drift()` once (the engine's guarded dry run over every live object: `reach`, `references`, the plan, `dissolves` and `generate`; it mutates nothing, `parametric_system.dart:577-610`); only when it throws a `KitHookFailure` does it probe that type's objects one by one, freeze the failing ones, and run `drift()` again. Each round freezes at least one object or stops, so it ends; a healthy plan pays one dry run (probing every object would be O(n²): each probe surveys).

Plan decision (`DanglingReferenceError`): E2 refuses an edit of a `cascade` referrer of a frozen object with `DanglingReferenceError`. It is a refusal, not a kit failure: `GuardedTool` treats it like `PlanLocked` (the hint, the gesture cancelled, no diagnostic), and `execute` catches it and answers false (controller ruling R-b).

Plan decision (generic tools): every armed tool is wrapped, generic or a kit's (spec P4). A kit tool's own throw is a diagnostic, its cancel and `plan.select` (spec table: "a tool's event"); a generic tool's own throw is rethrown unchanged, today's behaviour (`select_tool.dart:546-550`), because it is not a kit's. A `KitHookFailure` that reaches a generic tool (the retry failed during its commit) is the kit's: a diagnostic, cancel, `plan.select`.

Plan decision (painting, sections): a failure while painting, or while building a section, must not notify listeners mid-frame, so those diagnostics go through `DiagnosticsLog.addAfterFrame` (deduplicated at once, published after the frame), and a failed paint cancels the tool after the frame (spec table).

Plan decision (allocation): `GuardedType` sits on the parametric hot path (spec Risks). Each member is a `try` around one delegating call: no closure, no collection, no boxing in the happy path. The engine's `query_allocation_test.dart` stays green (Task 21's gate); no allocation meter is added here, because the plan library's test process would need the VM-service meter whose noise floor in `_Closure` and `Context` (documented in `jet_cad_floor_plan/test/invariants/vm_allocation_meter.dart`) cannot resolve a per-call budget.

Plan decision (getters at registration): `ParametricCatalog.register` reads `contributesPlace` and `readsPlaces` (`parametric_system.dart:497-501`); through the guard, a throwing getter there surfaces as a `KitHookFailure` out of the controller's constructor, beside the kit-set validation errors. It is a construction error, not a runtime one (F-G12, F-G13 pin the attribution).

- [ ] **Step 1: Write the failing tests.** Create `test/kits/guarded_type_test.dart`:

```dart
// Spec P4 "The failure boundary": every ParametricType hook is called
// through a guarding adapter that rethrows what the hook throws as
// KitHookFailure(kitId, typeId, hook, error); the engine rolls the edit
// back and rethrows it unchanged. One test per hook, each on the engine
// alone (a ParametricSystem over the box and ring kits' guarded types), so
// the attribution is the adapter's. The named mutant of each is that
// hook's guard removed (the delegate called bare): the raw HookBoom then
// escapes instead.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/kits/guard.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/box_kit.dart';

/// A document with a page and a system over the guarded square and disc.
({DraftDocument doc, ParametricSystem system, ParametricCatalog catalog})
    harness(Switches sw) {
  final d = DraftDocument.empty();
  PageComponent.register(d.components);
  d.commands.execute(SetComponentCommand<PageComponent>(
      d.rootHandle, PageComponent(scaleDenominator: 50)));
  final catalog = ParametricCatalog()
    ..register<SquareParams>(SquareParams.id, SquareParams.fromJson,
        GuardedType<SquareParams>('box', SquareParams.id, SquareType(sw)))
    ..register<DiscParams>(DiscParams.id, DiscParams.fromJson,
        GuardedType<DiscParams>('ring', DiscParams.id, DiscType(sw)));
  final system = ParametricSystem(d, catalog)..install();
  return (doc: d, system: system, catalog: catalog);
}

Matcher failed(String kitId, String typeId, String hook) =>
    isA<KitHookFailure>()
        .having((f) => f.kitId, 'kitId', kitId)
        .having((f) => f.typeId, 'typeId', typeId)
        .having((f) => f.hook, 'hook', hook)
        .having((f) => f.error, 'error',
            isA<HookBoom>().having((b) => b.hook, 'hook', hook));

/// Runs [edit] on [d]: it must throw [matcher], leave the document as it
/// was and record nothing.
void expectRefused(DraftDocument d, void Function() edit, Matcher matcher) {
  final before = canon(d);
  final depth = d.commands.undoDepth;
  final state = d.commands.stateId;
  expect(edit, throwsA(matcher));
  expect(canon(d), before, reason: 'rolled back');
  expect(d.commands.undoDepth, depth);
  expect(d.commands.stateId, state);
}

DraftCommand resize(Handle h, SquareParams p, double side) =>
    SetComponentCommand<SquareParams>(h, p.copyWith(side: side));

void main() {
  const poisoned = SquareParams(side: 1200, poisoned: true);

  test('F-G1 reach', () {
    final sw = Switches();
    final h = harness(sw);
    addObject(h.doc, atSquare, poisoned);
    sw.failing.add('reach');
    // M-F-G1: GuardedType.reach → `inner.reach(params, toWorld)` bare.
    expectRefused(
        h.doc,
        () => addLine(h.doc, Vector2(-500.5, 900.25), Vector2(300.75, 1200.5)),
        failed('box', SquareParams.id, 'reach'));
  });

  test('F-G2 references', () {
    final sw = Switches();
    final h = harness(sw);
    addObject(h.doc, atSquare, poisoned);
    sw.failing.add('references');
    // M-F-G2: GuardedType.references bare.
    expectRefused(
        h.doc,
        () => addLine(h.doc, Vector2(-500.5, 900.25), Vector2(300.75, 1200.5)),
        failed('box', SquareParams.id, 'references'));
  });

  test('F-G3 generate', () {
    final sw = Switches();
    final h = harness(sw);
    final s = addObject(h.doc, atSquare, poisoned);
    sw.failing.add('generate');
    // M-F-G3: GuardedType.generate bare.
    expectRefused(h.doc, () => h.doc.commands.execute(resize(s, poisoned, 900)),
        failed('box', SquareParams.id, 'generate'));
  });

  test('F-G4 dissolves', () {
    final sw = Switches();
    final h = harness(sw);
    final s = addObject(h.doc, atSquare, poisoned);
    sw.failing.add('dissolves');
    // M-F-G4: GuardedType.dissolves bare.
    expectRefused(h.doc, () => h.doc.commands.execute(resize(s, poisoned, 900)),
        failed('box', SquareParams.id, 'dissolves'));
  });

  test('F-G5 diagnose', () {
    final sw = Switches();
    final h = harness(sw);
    addObject(h.doc, atSquare, poisoned);
    sw.failing.add('diagnose');
    // M-F-G5: GuardedType.diagnose bare.
    expect(() => h.system.diagnostics(),
        throwsA(failed('box', SquareParams.id, 'diagnose')));
  });

  test('F-G6 editCapability', () {
    final sw = Switches();
    final h = harness(sw);
    final s = addObject(h.doc, atSquare, const SquareParams(side: 1200));
    sw.failing.add('editCapability');
    // M-F-G6: GuardedType.editCapability bare.
    expectRefused(
        h.doc,
        () => h.doc.commands
            .execute(resize(s, const SquareParams(side: 1200), 900)),
        failed('box', SquareParams.id, 'editCapability'));
  });

  test('F-G7 referencePolicy', () {
    final sw = Switches();
    final h = harness(sw);
    final disc = addObject(
        h.doc, nearSquare(2000, 0, 0), const DiscParams(radius: 400));
    final p = SquareParams(side: 1200, partner: disc);
    final s = addObject(h.doc, atSquare, p);
    sw.failing.add('referencePolicy');
    // M-F-G7: GuardedType.referencePolicy bare.
    expectRefused(h.doc, () => h.doc.commands.execute(resize(s, p, 900)),
        failed('box', SquareParams.id, 'referencePolicy'));
  });

  test('F-G8 pageKey', () {
    final sw = Switches();
    final h = harness(sw);
    addObject(h.doc, atSquare, const SquareParams(side: 1200));
    final root = h.doc.rootHandle;
    final page = h.doc.components.get<PageComponent>(root)!;
    sw.failing.add('pageKey');
    // M-F-G8: GuardedType.pageKey bare.
    expectRefused(
        h.doc,
        () => h.doc.commands.execute(SetComponentCommand<PageComponent>(
            root, page.copyWith(scaleDenominator: 75))),
        failed('box', SquareParams.id, 'pageKey'));
  });

  test(
      'F-G9 placeBox, asked by another kit\'s generate: the failure names '
      'the square, not the disc that asked', () {
    final sw = Switches();
    final h = harness(sw);
    addObject(h.doc, atSquare, poisoned);
    final disc = addObject(
        h.doc, nearSquare(300, 200, 0), const DiscParams(radius: 700));
    sw.failing.add('placeBox');
    // M-F-G9a: GuardedType.placeBox bare. M-F-G9b: the
    // `on KitHookFailure { rethrow; }` clause removed from
    // GuardedType.generate: the disc's guard rewraps the square's failure
    // as ring.disc's `generate`.
    expectRefused(
        h.doc,
        () => h.doc.commands.execute(SetComponentCommand<DiscParams>(
            disc, const DiscParams(radius: 850))),
        failed('box', SquareParams.id, 'placeBox'));
  });

  test('F-G10 placeInput', () {
    final sw = Switches();
    final h = harness(sw);
    final s = addObject(h.doc, atSquare, poisoned);
    addObject(h.doc, nearSquare(300, 200, 0), const DiscParams(radius: 700));
    sw.failing.add('placeInput');
    // M-F-G10: GuardedType.placeInput bare.
    expectRefused(h.doc, () => h.doc.commands.execute(resize(s, poisoned, 900)),
        failed('box', SquareParams.id, 'placeInput'));
  });

  test('F-G11 readBox', () {
    final sw = Switches();
    final h = harness(sw);
    const p = SquareParams(side: 1200);
    final s = addObject(h.doc, atSquare, p);
    addObject(h.doc, nearSquare(300, 200, 0),
        const DiscParams(radius: 700, poisoned: true));
    sw.failing.add('readBox');
    // M-F-G11: GuardedType.readBox bare.
    expectRefused(h.doc, () => h.doc.commands.execute(resize(s, p, 900)),
        failed('ring', DiscParams.id, 'readBox'));
  });

  test('F-G12 contributesPlace, read by register', () {
    final sw = Switches()..failing.add('contributesPlace');
    // M-F-G12: GuardedType.contributesPlace bare.
    expect(
        () => ParametricCatalog().register<SquareParams>(
            SquareParams.id,
            SquareParams.fromJson,
            GuardedType<SquareParams>('box', SquareParams.id, SquareType(sw))),
        throwsA(failed('box', SquareParams.id, 'contributesPlace')));
  });

  test('F-G13 readsPlaces, read by register', () {
    final sw = Switches()..failing.add('readsPlaces');
    // M-F-G13: GuardedType.readsPlaces bare.
    expect(
        () => ParametricCatalog().register<SquareParams>(
            SquareParams.id,
            SquareParams.fromJson,
            GuardedType<SquareParams>('box', SquareParams.id, SquareType(sw))),
        throwsA(failed('box', SquareParams.id, 'readsPlaces')));
  });

  test(
      'F-G14 the plan\'s TypeGuard through PlanType.registerInto keeps T and '
      'the kit\'s id; a healthy edit is unchanged by the guard', () {
    final sw = Switches();
    final d = DraftDocument.empty();
    final catalog = ParametricCatalog();
    boxKit(sw).types.single.registerInto(catalog, guard: const PlanTypeGuard());
    ParametricSystem(d, catalog).install();
    final s = addObject(d, atSquare, poisoned);
    expect(catalog.names<SquareParams>(d, s), isTrue,
        reason: 'registered as SquareParams, not Component');
    expect(kids(d, s), hasLength(4));
    sw.failing.add('reach');
    // M-F-G14: PlanTypeGuard.wrap returning `type` unwrapped.
    expect(
        () => addLine(d, Vector2(-500.5, 900.25), Vector2(300.75, 1200.5)),
        throwsA(failed('box', SquareParams.id, 'reach')));
  });
}
```

  Create `test/kits/failure_flow_test.dart`:

```dart
// Spec P4 "The failure boundary", through the controller: a hook that
// fails during an edit is caught at the expander, that type's objects are
// probed (E2), the failing ones frozen and locked, the history cleared,
// and the edit run once more; a second failure refuses it with one
// diagnostic. A load probes once. A component its factory cannot read is
// kept raw, locked and frozen (E4). A rollback that throws damages the
// plan (E3), and saving a damaged plan first reads it back.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/kits/guard.dart' show GuardedTool;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/box_kit.dart';

/// [owner]'s entities' scalars (a circle's radius), in handle order.
List<double> scalarsOf(DraftDocument d, Handle owner) => [
      for (final k in kids(d, owner))
        ...d.geometry
            .read(d.entities.geomIndexAt(d.entities.slotOf(k)!))
            .scalars,
    ];

List<KitDiagnostic> diagnosticsOf(PlanController c, KitDiagnosticCode code) =>
    [
      for (final d in c.diagnostics.value)
        if (d.code == code) d
    ];

/// Applies [inner], then hands back an inverse that throws: a command
/// whose rollback fails.
final class _Sabotage extends DraftCommand {
  _Sabotage(this.inner);
  final DraftCommand inner;
  @override
  Capability get capability => inner.capability;
  @override
  Set<Capability> get capabilities => inner.capabilities;
  @override
  String get label => 'Sabotage';
  @override
  CommandResult apply(CommandTarget target) {
    final r = inner.apply(target);
    return CommandResult(inverse: _Throwing(), touched: r.touched);
  }
}

final class _Throwing extends DraftCommand {
  @override
  Capability get capability => Capability.components;
  @override
  String get label => 'Throwing';
  @override
  CommandResult apply(CommandTarget target) =>
      throw StateError('this inverse refuses');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'F-1 (spec Tests) an object whose reach throws: one edit of it is '
      'refused, the object is frozen and locked; then a plain line is drawn '
      'and edited, and the other square still regenerates', () {
    final sw = Switches();
    final c = PlanController(kits: [boxKit(sw)]);
    addTearDown(c.dispose);
    final d = c.document;
    final broken = addObject(d, atSquare, const SquareParams(side: 1200, poisoned: true));
    final other = addObject(d, nearSquare(4000, -500, 0.25), const SquareParams(side: 500));
    final drawn = coordsOf(d, broken);
    sw.failing.add('reach');

    // M-F1a: `FailureBoundary.recover` returning false at once: the move
    // is refused by the failure, not by the lock, so nothing is locked and
    // no hint is shown. `execute` catches the retry's PlanLocked and
    // answers false (controller ruling R-b).
    expect(c.execute(TransformNodeCommand(broken, nearSquare(100.5, 50.25, 0))),
        isFalse);
    // M-F1c: `execute`'s `on PlanLocked` clause without
    // `lockHint.value = true;`.
    expect(c.lockHint.value, isTrue);
    expect(c.locked.value, {broken});
    final failures = diagnosticsOf(c, KitDiagnosticCode.hookFailed);
    expect(failures, hasLength(1));
    expect((failures.single.kitId, failures.single.subject), ('box', SquareParams.id));

    // M-F1b: `_freeze` without `frozen.addAll(objects)`: the object is
    // locked but still surveyed, and every edit fails on its reach.
    final line = d.handleSeed.next();
    expect(
        c.execute(AddEntityCommand(
            record: draftRecord(line, d.rootHandle, EntityKind.line,
                layer: ReservedHandles.layerZero),
            payload: linePayload(Vector2(-3100.5, 4200.25), Vector2(-1700.75, 5100.5)))),
        isTrue);
    expect(
        c.execute(SetEntityGeometryCommand(
            line, linePayload(Vector2(-3000.25, 4100.5), Vector2(-1600.5, 5000.75)))),
        isTrue);
    final otherBefore = coordsOf(d, other);
    expect(c.execute(SetComponentCommand<SquareParams>(other, const SquareParams(side: 650.5))), isTrue);
    expect(coordsOf(d, other), isNot(otherBefore), reason: 'regenerated');
    expect(kids(d, other), hasLength(4));
    expect(coordsOf(d, broken), drawn, reason: 'the broken one keeps its geometry');
    expect(diagnosticsOf(c, KitDiagnosticCode.hookFailed), hasLength(1));
  });

  test(
      'F-2 (Review Focus 2) a broken square beside a working disc of another '
      'kit: the disc\'s edit is not refused; afterwards both kits\' working '
      'objects regenerate and the broken one keeps its geometry', () {
    final sw = Switches();
    final c = PlanController(kits: [boxKit(sw), ringKit(sw)]);
    addTearDown(c.dispose);
    final d = c.document;
    final broken = addObject(d, atSquare, const SquareParams(side: 1200, poisoned: true));
    final disc = addObject(d, nearSquare(300, 200, 0), const DiscParams(radius: 700));
    final square = addObject(d, nearSquare(5200, 900, -0.4), const SquareParams(side: 400));
    final drawn = coordsOf(d, broken);
    sw.failing.add('placeBox');

    // M-F2: the controller not setting `LockExpander.onHookFailure` (no
    // recovery): the disc's edit is refused.
    expect(c.execute(SetComponentCommand<DiscParams>(disc, const DiscParams(radius: 850.5))), isTrue);
    expect(scalarsOf(d, disc), [850.5]);
    expect(c.locked.value, {broken});
    expect(c.execute(SetComponentCommand<DiscParams>(disc, const DiscParams(radius: 910.25))), isTrue);
    expect(scalarsOf(d, disc), [910.25]);
    final before = coordsOf(d, square);
    expect(c.execute(SetComponentCommand<SquareParams>(square, const SquareParams(side: 720.5))), isTrue);
    expect(coordsOf(d, square), isNot(before));
    expect(coordsOf(d, broken), drawn);
    expect(diagnosticsOf(c, KitDiagnosticCode.hookFailed), hasLength(1));
    expect(c.canUndo.value, isTrue, reason: 'the edits after the lock undo');
  });

  test(
      'F-3 a failure no object explains (the edit\'s own new value) is '
      'refused: no throw, the document and history unchanged, one '
      'diagnostic however often it recurs', () {
    final sw = Switches();
    final c = PlanController(kits: [boxKit(sw)]);
    addTearDown(c.dispose);
    final d = c.document;
    const p = SquareParams(side: 1200);
    final s = addObject(d, atSquare, p);
    sw.failing.add('reach');
    final before = canon(d);
    final depth = d.commands.undoDepth;
    final poisonIt = SetComponentCommand<SquareParams>(s, p.copyWith(poisoned: true));
    // M-F3a: `execute` rethrowing a KitHookFailure instead of answering
    // false.
    expect(c.execute(poisonIt), isFalse);
    expect(c.execute(poisonIt), isFalse);
    expect(canon(d), before);
    expect(d.commands.undoDepth, depth);
    expect(c.locked.value, isEmpty, reason: 'nothing to blame, nothing frozen');
    // M-F3b: `DiagnosticsLog.add` without its `_seen` check.
    expect(diagnosticsOf(c, KitDiagnosticCode.hookFailed), hasLength(1));
  });

  test(
      'F-4 a plan whose object is already broken: the load\'s dry run finds '
      'it, so it is frozen and locked before the first edit', () {
    final sw = Switches();
    final a = PlanController(kits: [boxKit(sw)]);
    final broken = addObject(a.document, atSquare, const SquareParams(side: 1200, poisoned: true));
    final other = addObject(a.document, nearSquare(4000, -500, 0.25), const SquareParams(side: 500));
    final json = a.save();
    final drawn = coordsOf(a.document, broken);
    a.dispose();
    sw.failing.add('generate');

    final c = PlanController(kits: [boxKit(sw)], json: json);
    addTearDown(c.dispose);
    // M-F4: the per-document build without `boundary.probeLoaded()`.
    expect(c.locked.value, {broken});
    expect(diagnosticsOf(c, KitDiagnosticCode.hookFailed), hasLength(1));
    expect(c.execute(SetComponentCommand<SquareParams>(other, const SquareParams(side: 640.5))), isTrue);
    expect(coordsOf(c.document, broken), drawn);
  });

  test(
      'F-5 (E4) a component its factory cannot read: the plan opens, the '
      'object is locked, one diagnostic names it, and saving writes the '
      'component back as read', () {
    final sw = Switches();
    final a = PlanController(kits: [boxKit(sw)]);
    final broken = addObject(a.document, atSquare, const SquareParams(side: 1200, poisoned: true));
    addObject(a.document, nearSquare(4000, -500, 0.25), const SquareParams(side: 500));
    final json = a.save();
    a.dispose();
    sw.failing.add('fromJson');

    final c = PlanController(kits: [boxKit(sw)], json: json);
    addTearDown(c.dispose);
    // M-F5: the per-document build without `boundary.reportUnreadable(...)`.
    final unreadable = diagnosticsOf(c, KitDiagnosticCode.componentUnreadable);
    expect(unreadable, hasLength(1));
    expect((unreadable.single.kitId, unreadable.single.subject), ('box', SquareParams.id));
    expect(c.locked.value, {broken});
    expect(componentsText(c.save(), SquareParams.id), componentsText(json, SquareParams.id));
  });

  test(
      'F-6 (E3) a rollback that throws: the plan is damaged, the history '
      'cleared, a diagnostic reported; a damaged plan that reads back saves',
      () {
    final sw = Switches();
    final c = PlanController(kits: [boxKit(sw)]);
    addTearDown(c.dispose);
    final d = c.document;
    final s = addObject(d, atSquare, const SquareParams(side: 1200));
    addLine(d, Vector2(-3100.5, 4200.25), Vector2(-1700.75, 5100.5));
    expect(c.canUndo.value, isTrue, reason: 'premise');
    sw.failing.add('reach');
    // The edit's after-survey fails on the new value, and the inverse the
    // engine then applies throws: E3's PartialMutationError.
    expect(
        () => c.execute(_Sabotage(SetComponentCommand<SquareParams>(
            s, const SquareParams(side: 1300, poisoned: true)))),
        throwsA(isA<PartialMutationError>()));
    // M-F6a: the controller not setting `LockExpander.onPartialMutation`.
    expect(c.damaged.value, isTrue);
    // M-F6b: the damage handler without `commands.notifyLoaded()`.
    expect(d.commands.canUndo, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(diagnosticsOf(c, KitDiagnosticCode.rollbackFailed), hasLength(1));
    sw.failing.clear();
    expect(c.save(), contains('"jetcad.manifest"'), reason: 'it reads back, so it saves');
    c.newPlan();
    expect(c.damaged.value, isFalse, reason: 'a new document is not damaged');
  });

  test(
      'F-7 a damaged plan that does not read back is not saved: '
      'PlanFormatException(damagedUnsavable) and a diagnostic', () {
    final sw = Switches();
    final c = PlanController(kits: [boxKit(sw)]);
    addTearDown(c.dispose);
    final d = c.document;
    final s = addObject(d, atSquare, const SquareParams(side: 1200));
    sw.failing.add('reach');
    expect(
        () => c.execute(_Sabotage(SetComponentCommand<SquareParams>(
            s, const SquareParams(side: double.nan, poisoned: true)))),
        throwsA(isA<PartialMutationError>()));
    expect(d.components.get<SquareParams>(s)!.side.isNaN, isTrue,
        reason: 'premise: the partial mutation left a value no JSON holds');
    // M-F7: `save` without its damaged check (Task 8's body alone) throws
    // the encoder's JsonUnsupportedObjectError instead.
    expect(
        c.save,
        throwsA(isA<PlanFormatException>()
            .having((e) => e.code, 'code', PlanFormatCode.damagedUnsavable)));
    expect(diagnosticsOf(c, KitDiagnosticCode.damagedUnsavable), hasLength(1));
  });

  test(
      'F-8 a tool whose factory throws is disabled: one diagnostic, and '
      'selecting it leaves plan.select armed', () {
    final sw = Switches()..failing.add('create');
    // M-F8: the controller calling `PlanTool.create` bare: the constructor
    // throws HookBoom.
    final c = PlanController(kits: [boxKit(sw)]);
    addTearDown(c.dispose);
    expect(c.isToolDisabled('box.stamp'), isTrue);
    expect(c.isToolDisabled('plan.select'), isFalse);
    final failures = diagnosticsOf(c, KitDiagnosticCode.hookFailed);
    expect((failures.single.kitId, failures.single.subject), ('box', 'box.stamp'));
    c.selectTool('box.stamp');
    expect(c.activeTool.value, 'plan.select');
    // A healthy kit's tool arms, wrapped.
    sw.failing.clear();
    c.newPlan();
    expect(c.isToolDisabled('box.stamp'), isFalse, reason: 'the factories run again per document');
    c.selectTool('box.stamp');
    expect(c.activeTool.value, 'box.stamp');
    expect(c.toolController.active, isA<GuardedTool>());
  });

  test(
      'F-9 execute answers false for a refused edit (controller ruling R-b): '
      'an ArgumentError and a DanglingReferenceError are caught, nothing '
      'changes, no lock hint', () {
    final sw = Switches();
    final c = PlanController(kits: [boxKit(sw)]);
    addTearDown(c.dispose);
    final d = c.document;
    final s = addObject(d, atSquare, const SquareParams(side: 1200));
    final before = canon(d);
    final depth = d.commands.undoDepth;
    // M-F9a: `execute` without its `on ArgumentError` clause.
    expect(c.execute(_Refusing(ArgumentError('out of range'))), isFalse);
    // M-F9b: `execute` without its `on DanglingReferenceError` clause.
    expect(c.execute(_Refusing(DanglingReferenceError(s, s))), isFalse);
    expect(canon(d), before);
    expect(d.commands.undoDepth, depth);
    expect(c.lockHint.value, isFalse, reason: 'no lock refused it');
  });
}

/// A command that refuses: [apply] throws [error] before it touches
/// anything.
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
```

  Create `test/kits/guarded_tool_test.dart`:

```dart
// Spec P4 "The failure boundary", the tool rows: every armed tool is wrapped
// in a guarding Tool decorator. A kit tool's event that throws is a
// diagnostic, a cancel and plan.select; a refusal (PlanLocked, or E2's
// DanglingReferenceError) only cancels the gesture and shows the hint; a
// paint that throws is skipped and the tool cancelled after the frame; a
// generic tool's own error is rethrown as today. The decorator forwards
// what it does not guard.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/kits/guard.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A tool whose members throw [errors] by name; it counts its cancels and
/// paints, and reports [midShape] and [toolPhase].
final class _Inner extends Tool {
  final Map<String, Object> errors = {};
  int cancels = 0;
  int paints = 0;
  bool midShape = true;
  ToolPhase toolPhase = ToolPhase.dragging;

  void _maybe(String member) {
    final e = errors[member];
    if (e != null) throw e;
  }

  void ping() => notifyListeners();

  @override
  String get name => 'inner';
  @override
  ToolPhase get phase {
    _maybe('phase');
    return toolPhase;
  }

  @override
  bool get isMidShape {
    _maybe('isMidShape');
    return midShape;
  }

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) => _maybe('onPointerDown');
  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) => _maybe('onPointerMove');
  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) => _maybe('onPointerUp');
  @override
  void onPointerExit(ToolContext ctx) => _maybe('onPointerExit');
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    _maybe('onKey');
    return KeyEventResult.handled;
  }

  @override
  void cancel(ToolContext ctx) => cancels++;
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {
    paints++;
    _maybe('paintOverlay');
  }
}

final class _Rig {
  _Rig({this.kitId = 'box', this.toolId = 'box.stamp'}) {
    final d = DraftDocument.empty();
    index = SpatialIndex(d);
    selection = SelectionController(d);
    ctx = ToolContext(
        document: d,
        index: index,
        camera: CameraController(ViewportTransform(
            worldToScreenMatrix: Transform2(0.125, 0, 0, -0.125, 400, 300))),
        selection: selection);
    tool = GuardedTool(
        inner: inner,
        kitId: kitId,
        toolId: toolId,
        log: log,
        lockHint: hint,
        onFailed: () => failed++);
  }

  final String kitId;
  final String toolId;
  final _Inner inner = _Inner();
  final DiagnosticsLog log = DiagnosticsLog();
  final ValueNotifier<bool> hint = ValueNotifier(false);
  late final SpatialIndex index;
  late final SelectionController selection;
  late final ToolContext ctx;
  late final GuardedTool tool;
  int failed = 0;

  void dispose() {
    tool.dispose();
    index.dispose();
    selection.dispose();
    hint.dispose();
    log.dispose();
  }
}

final ToolPointerEvent down = ToolPointerEvent(
    screen: const Offset(410.5, 290.25),
    world: Vector2(84.0, 78.0),
    pointer: 1,
    buttons: 1,
    shift: false,
    control: false,
    meta: false,
    alt: false,
    pickRadiusWorld: 48);

const KeyDownEvent keyR = KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.keyR,
    logicalKey: LogicalKeyboardKey.keyR,
    timeStamp: Duration.zero);

/// Each event member, called on [t] with [ctx].
final Map<String, void Function(Tool t, ToolContext ctx)> events = {
  'onPointerDown': (t, ctx) => t.onPointerDown(down, ctx),
  'onPointerMove': (t, ctx) => t.onPointerMove(down, ctx),
  'onPointerUp': (t, ctx) => t.onPointerUp(down, ctx),
  'onPointerExit': (t, ctx) => t.onPointerExit(ctx),
  'onKey': (t, ctx) => t.onKey(keyR, ctx),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'F-T1 a kit tool\'s event that throws: no exception, one diagnostic '
      'naming the tool, the tool cancelled, plan.select asked for', () {
    for (final MapEntry(key: member, value: call) in events.entries) {
      final r = _Rig();
      r.inner.errors[member] = StateError('boom in $member');
      // M-F-T1-<member>: that member's `try` removed in GuardedTool.
      expect(() => call(r.tool, r.ctx), returnsNormally, reason: member);
      final d = r.log.entries.value;
      expect(d, hasLength(1), reason: member);
      expect((d.single.kitId, d.single.subject, d.single.code),
          ('box', 'box.stamp', KitDiagnosticCode.hookFailed),
          reason: member);
      expect(r.inner.cancels, 1, reason: member);
      expect(r.failed, 1, reason: member);
      expect(r.hint.value, isFalse, reason: member);
      r.dispose();
    }
  });

  test(
      'F-T2 a refusal (PlanLocked, or E2\'s DanglingReferenceError) shows '
      'the hint and cancels the gesture: no diagnostic, the tool stays', () {
    for (final refusal in <Object>[
      const PlanLocked(),
      const DanglingReferenceError(Handle(4101), Handle(4102)),
    ]) {
      final r = _Rig();
      r.inner.errors['onPointerUp'] = refusal;
      // M-F-T2: the refusal branch of `_failed` removed: the refusal is
      // then a kit failure (a diagnostic, plan.select).
      r.tool.onPointerUp(down, r.ctx);
      expect(r.hint.value, isTrue, reason: '$refusal');
      expect(r.inner.cancels, 1, reason: '$refusal');
      expect(r.failed, 0, reason: '$refusal');
      expect(r.log.entries.value, isEmpty, reason: '$refusal');
      r.dispose();
    }
  });

  test(
      'F-T3 a KitHookFailure reaching a generic tool is the kit\'s: the '
      'diagnostic names the failing type, the tool is cancelled', () {
    final r = _Rig(kitId: 'plan', toolId: 'plan.line');
    r.inner.errors['onPointerUp'] =
        const KitHookFailure('ring', 'ring.disc', 'generate', HookError());
    r.tool.onPointerUp(down, r.ctx);
    final d = r.log.entries.value.single;
    // M-F-T3: the KitHookFailure attributed to the tool (kitId, toolId).
    expect((d.kitId, d.subject), ('ring', 'ring.disc'));
    expect(r.inner.cancels, 1);
    expect(r.failed, 1);
    r.dispose();
  });

  test('F-T4 a generic tool\'s own error is rethrown, as today', () {
    final r = _Rig(kitId: 'plan', toolId: 'plan.select');
    r.inner.errors['onPointerUp'] = StateError('a refused edit');
    // M-F-T4: `_failed` treating every tool as a kit's swallows it.
    expect(() => r.tool.onPointerUp(down, r.ctx), throwsStateError);
    expect(r.failed, 0);
    expect(r.log.entries.value, isEmpty);
    r.dispose();
  });

  testWidgets(
      'F-T5 a kit tool\'s paint that throws is skipped; the tool is '
      'cancelled after the frame, and not painted again', (tester) async {
    final r = _Rig();
    addTearDown(r.dispose);
    r.inner.errors['paintOverlay'] = StateError('paint');
    final canvas = Canvas(ui.PictureRecorder());
    final camera = ViewportTransform(
        worldToScreenMatrix: Transform2(0.125, 0, 0, -0.125, 400, 300));
    r.tool.paintOverlay(canvas, camera, const Size(800, 600), PaperPalette.light);
    // M-F-T5: `onFailed` called at once instead of after the frame.
    expect(r.failed, 0, reason: 'not inside the paint');
    r.tool.paintOverlay(canvas, camera, const Size(800, 600), PaperPalette.light);
    expect(r.inner.paints, 1, reason: 'a broken overlay is skipped');
    await tester.pump();
    expect(r.failed, 1);
    expect(r.log.entries.value, hasLength(1));
    r.tool.cancel(r.ctx);
    r.inner.errors.clear();
    r.tool.paintOverlay(canvas, camera, const Size(800, 600), PaperPalette.light);
    expect(r.inner.paints, 2, reason: 'a cancel clears the broken flag');
  });

  test(
      'F-T6 the decorator forwards phase, isMidShape and notifications; a '
      'kit getter that throws answers the safe default with a diagnostic',
      () async {
    final r = _Rig();
    // M-F-T6a: `isMidShape` answering false without asking the inner.
    expect(r.tool.isMidShape, isTrue);
    expect(r.tool.phase, ToolPhase.dragging);
    var heard = 0;
    r.tool.addListener(() => heard++);
    // M-F-T6b: the constructor without `inner.addListener(_forward)`.
    r.inner.ping();
    expect(heard, 1);
    r.inner.errors['isMidShape'] = StateError('mid');
    expect(r.tool.isMidShape, isFalse);
    r.inner.errors['phase'] = StateError('phase');
    expect(r.tool.phase, ToolPhase.idle);
    expect(identical(r.tool.inner, r.inner), isTrue);
    r.dispose();
    // M-F-T6c: `dispose` without `inner.dispose()`.
    expect(() => r.inner.addListener(() {}), throwsFlutterError,
        reason: 'the decorator owns and disposes its tool');
  });
}

/// A neutral error value for a constructed KitHookFailure.
final class HookError implements Exception {
  const HookError();
}
```

  Create `test/kits/guard_boundaries_test.dart`:

```dart
// Spec P4 "The failure boundary", the remaining rows: grips (that object
// has none, a drag in flight refused), an attachment provider (taken as no
// attachment), a section builder (a small box in its place; a widget it
// returned that fails shows Flutter's ErrorWidget in its place only), and
// the log (once per kit, subject and code; never notifying mid-frame).
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/kits/guard.dart';
import 'package:jet_cad_2d_plan/src/kits/section_boundary.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

final class _Grips implements ObjectGripProvider {
  final Set<String> failing = {};
  int calls = 0;
  void _maybe(String m) {
    calls++;
    if (failing.contains(m)) throw StateError(m);
  }

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    _maybe('gripsOf');
    return const [Grip(GripRole.stretch, 0, 7010, 3020)];
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    _maybe('drag');
    return TransformNodeCommand(group, Transform2.translation(world.x, world.y));
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    _maybe('preview');
    return [(EntityKind.line, linePayload(Vector2.zero(), world))];
  }

  @override
  bool movable(DraftDocument d, Handle group) {
    _maybe('movable');
    return true;
  }
}

final class _Edge implements AttachmentProvider {
  _Edge(this.fails);
  final bool fails;
  int calls = 0;
  @override
  String get kind => 'test-edge';
  @override
  Attachment? attach(AttachmentQuery query) {
    calls++;
    if (fails) throw StateError('edge');
    return null;
  }
}

AttachmentQuery query() => AttachmentQuery(
    footprint: Aabb2.fromPoints([Vector2(-300, -200), Vector2(300, 200)]),
    current: Transform2.translation(7010, 3020),
    pointer: Vector2(7100.5, 3050.25),
    capture: 120,
    edgeCapture: 60,
    mirrored: false,
    mayRotate: true,
    exclude: const {});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'F-B1 a grip provider that throws: that object has no grips from then '
      'on, a drag is refused, it does not move; one diagnostic for its type',
      () {
    final d = DraftDocument.empty();
    final log = DiagnosticsLog();
    addTearDown(log.dispose);
    final inner = _Grips()..failing.add('gripsOf');
    final grips = GuardedGrips(inner,
        typeIdOf: (doc, group) => 'box.square', log: log);
    const group = Handle(4321);
    const grip = Grip(GripRole.stretch, 0, 7010, 3020);
    final world = Vector2(7100.5, 3100.25);
    // M-F-B1a: GuardedGrips.gripsOf calling the inner bare.
    expect(grips.gripsOf(d, group), isEmpty);
    final d1 = log.entries.value.single;
    expect((d1.kitId, d1.subject, d1.code),
        ('box', 'box.square', KitDiagnosticCode.hookFailed));
    inner.failing.clear();
    final calls = inner.calls;
    // M-F-B1b: the `_failed` set not consulted: the object gets grips again.
    expect(grips.gripsOf(d, group), isEmpty);
    expect(grips.drag(d, group, grip, world), isNull);
    expect(grips.preview(d, group, grip, world), isEmpty);
    expect(grips.movable(d, group), isFalse);
    expect(inner.calls, calls, reason: 'the failed object is not asked again');
    // Another object: the inner's; its own failures one at a time.
    const other = Handle(4322);
    expect(grips.gripsOf(d, other), hasLength(1));
    for (final m in ['drag', 'preview', 'movable']) {
      final g = GuardedGrips(_Grips()..failing.add(m),
          typeIdOf: (doc, group) => 'box.square', log: log);
      // M-F-B1c/d/e: `drag`, `preview`, `movable` each calling the inner
      // bare.
      expect(() => g.drag(d, other, grip, world), returnsNormally, reason: m);
      expect(() => g.preview(d, other, grip, world), returnsNormally,
          reason: m);
      expect(() => g.movable(d, other), returnsNormally, reason: m);
    }
  });

  test(
      'F-B2 an attachment provider that throws is taken as no attachment, '
      'with one diagnostic naming its kit and kind', () {
    final log = DiagnosticsLog();
    addTearDown(log.dispose);
    final healthy = _Edge(false);
    expect(guardAttachment('box', healthy, query(), log.add), isNull);
    expect(healthy.calls, 1);
    expect(log.entries.value, isEmpty);
    // M-F-B2: guardAttachment calling `provider.attach` bare.
    expect(guardAttachment('box', _Edge(true), query(), log.add), isNull);
    final d = log.entries.value.single;
    expect((d.kitId, d.subject, d.code),
        ('box', 'test-edge', KitDiagnosticCode.hookFailed));
  });

  testWidgets(
      'F-B3 a section builder that throws shows the small box in its place; '
      'a widget it returned that fails shows ErrorWidget there only; the '
      'diagnostic is published after the frame', (tester) async {
    final log = DiagnosticsLog();
    addTearDown(log.dispose);
    final phases = <SchedulerPhase>[];
    log.entries
        .addListener(() => phases.add(SchedulerBinding.instance.schedulerPhase));
    Widget panel(Widget? Function(BuildContext) builder) => MaterialApp(
        home: Scaffold(
            body: Column(children: [
          const Text('beside'),
          KitSectionBoundary(
              kitId: 'box', typeId: 'box.square', log: log, builder: builder),
        ])));

    // M-F-B3a: KitSectionBoundary.build calling `builder` bare.
    await tester.pumpWidget(panel((_) => throw StateError('section')));
    expect(find.byKey(const Key('kit-section-failed')), findsOneWidget);
    expect(find.text('This section could not be shown'), findsOneWidget);
    expect(find.text('beside'), findsOneWidget);
    expect(log.entries.value.single.subject, 'box.square');
    // M-F-B3b: `addAfterFrame` notifying at once (inside the build).
    expect(phases, isNot(contains(SchedulerPhase.persistentCallbacks)));

    await tester.pumpWidget(panel((_) => const _Exploding()));
    expect(tester.takeException(), isA<StateError>());
    expect(find.byType(ErrorWidget), findsOneWidget);
    expect(find.text('beside'), findsOneWidget, reason: 'the plan stays usable');
  });

  test(
      'F-B4 the log keeps one diagnostic per kit, subject and code, in '
      'arrival order', () {
    final log = DiagnosticsLog();
    addTearDown(log.dispose);
    KitDiagnostic d(String kit, String? subject, KitDiagnosticCode code) =>
        KitDiagnostic(kitId: kit, subject: subject, code: code, message: 'm');
    expect(log.add(d('box', 'box.square', KitDiagnosticCode.hookFailed)), isTrue);
    // M-F-B4: the dedupe key without `code`.
    expect(log.add(d('box', 'box.square', KitDiagnosticCode.componentUnreadable)),
        isTrue);
    expect(log.add(d('ring', 'box.square', KitDiagnosticCode.hookFailed)), isTrue);
    expect(log.add(d('box', null, KitDiagnosticCode.hookFailed)), isTrue);
    expect(log.add(d('box', 'box.square', KitDiagnosticCode.hookFailed)), isFalse);
    expect([for (final e in log.entries.value) (e.kitId, e.subject, e.code)], [
      ('box', 'box.square', KitDiagnosticCode.hookFailed),
      ('box', 'box.square', KitDiagnosticCode.componentUnreadable),
      ('ring', 'box.square', KitDiagnosticCode.hookFailed),
      ('box', null, KitDiagnosticCode.hookFailed),
    ]);
  });
}

class _Exploding extends StatelessWidget {
  const _Exploding();
  @override
  Widget build(BuildContext context) => throw StateError('child build');
}
```

- [ ] **Step 2: Run them to see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/kits`. Expected: compilation errors (`Error when reading 'lib/src/kits/guard.dart'`, `Undefined name 'KitHookFailure'`, `The method 'execute' isn't defined for the type 'PlanController'`). `test/kits/locks_test.dart` (Task 10) is unaffected.

- [ ] **Step 3: The guard.** Create `lib/src/kits/guard.dart`:

```dart
// Spec P4 "The failure boundary" (umbrella A9): every kit hook is called at
// the contract's boundary. A kit's ParametricType is wrapped in
// [GuardedType], which rethrows what a hook throws as [KitHookFailure];
// its tools in [GuardedTool]; its grips, attachment providers, factories
// and sections in guarded calls. [FailureBoundary] is the controller's
// flow after a failed edit: probe the type's objects (E2), freeze and lock
// the failing ones, retry once; and the load's check. [DiagnosticsLog]
// keeps one diagnostic per kit, subject and code.
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show KeyEvent;
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../controller/diagnostics_log.dart';
import 'locks.dart' show PlanLocked;

export '../controller/diagnostics_log.dart' show DiagnosticsLog;

/// A kit's [ParametricType] hook threw [error]: [hook] of [typeId], in
/// [kitId]. The engine rolls the edit back and rethrows it unchanged.
final class KitHookFailure implements Exception {
  const KitHookFailure(this.kitId, this.typeId, this.hook, this.error);

  final String kitId;
  final String typeId;
  final String hook;
  final Object error;

  @override
  String toString() => 'KitHookFailure: $typeId.$hook threw $error';
}

/// [inner] with every member called at the boundary: what it throws is
/// rethrown as a [KitHookFailure] naming [kitId], [typeId] and the member
/// (a [KitHookFailure] from a nested call, another type's hook asked
/// through the view, keeps its own attribution). `implements`, not
/// `extends`: a member the engine adds later is a compile error here, never
/// a silently unguarded default. One `try` around one call per member: no
/// allocation in the happy path.
final class GuardedType<T extends Component> implements ParametricType<T> {
  const GuardedType(this.kitId, this.typeId, this.inner);

  final String kitId;
  final String typeId;
  final ParametricType<T> inner;

  Never _fail(String hook, Object error, StackTrace stack) =>
      Error.throwWithStackTrace(
          KitHookFailure(kitId, typeId, hook, error), stack);

  @override
  Capability get editCapability {
    try {
      return inner.editCapability;
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('editCapability', e, s);
    }
  }

  @override
  Aabb2 reach(T params, Transform2 toWorld) {
    try {
      return inner.reach(params, toWorld);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('reach', e, s);
    }
  }

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    try {
      return inner.generate(view, self);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('generate', e, s);
    }
  }

  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) {
    try {
      return inner.diagnose(view, self);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('diagnose', e, s);
    }
  }

  @override
  Iterable<Handle> references(T params) {
    try {
      return inner.references(params);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('references', e, s);
    }
  }

  @override
  ReferencePolicy get referencePolicy {
    try {
      return inner.referencePolicy;
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('referencePolicy', e, s);
    }
  }

  @override
  Object? pageKey(PageComponent? page) {
    try {
      return inner.pageKey(page);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('pageKey', e, s);
    }
  }

  @override
  bool dissolves(ParametricView view, Handle self) {
    try {
      return inner.dissolves(view, self);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('dissolves', e, s);
    }
  }

  @override
  bool get contributesPlace {
    try {
      return inner.contributesPlace;
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('contributesPlace', e, s);
    }
  }

  @override
  Aabb2? placeBox(ParametricView view, Handle self) {
    try {
      return inner.placeBox(view, self);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('placeBox', e, s);
    }
  }

  @override
  Object placeInput(ParametricView view, Handle self) {
    try {
      return inner.placeInput(view, self);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('placeInput', e, s);
    }
  }

  @override
  bool get readsPlaces {
    try {
      return inner.readsPlaces;
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('readsPlaces', e, s);
    }
  }

  @override
  Aabb2 readBox(T params, Transform2 toWorld, Aabb2 stored) {
    try {
      return inner.readBox(params, toWorld, stored);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('readBox', e, s);
    }
  }
}

/// The plan library's [TypeGuard]: `PlanType.registerInto(catalog, guard:)`
/// wraps the kit's type in a [GuardedType] of the same `T`.
final class PlanTypeGuard implements TypeGuard {
  const PlanTypeGuard();

  @override
  ParametricType<T> wrap<T extends Component>(
          String kitId, String typeId, ParametricType<T> type) =>
      GuardedType<T>(kitId, typeId, type);
}

/// [create]'s product, or null when it throws: the failure is reported as
/// [subject]'s (a tool id, a type id), and the caller disables what the
/// factory would have made (spec table: "a tool's factory: the tool is
/// disabled").
T? guardFactory<T extends Object>(
    String kitId, String subject, T Function() create, DiagnosticsLog log) {
  try {
    return create();
  } catch (error) {
    log.add(KitDiagnostic(
        kitId: kitId,
        subject: subject,
        code: KitDiagnosticCode.hookFailed,
        message: 'factory: $error',
        error: error));
    return null;
  }
}

/// Every armed tool, generic or a kit's, behind the boundary (spec P4).
///
/// - [PlanLocked] and `DanglingReferenceError` (E2's refusal of a frozen
///   object's `cascade` referrer) are refusals: the hint is set and the
///   inner's gesture cancelled; no diagnostic.
/// - A [KitHookFailure] is its kit's: a diagnostic, the inner cancelled,
///   [onFailed] (the controller arms `plan.select`).
/// - Anything else a kit tool throws is a diagnostic of [toolId], the
///   inner cancelled, [onFailed]; a generic tool's (kit id `plan`) is
///   rethrown unchanged, as today (`select_tool.dart:546-550`).
/// - A paint that throws is skipped, reported after the frame, and the tool
///   is given to [onFailed] after the frame; it paints nothing until it is
///   cancelled.
///
/// Owns [inner]: [dispose] disposes it.
final class GuardedTool extends Tool {
  GuardedTool({
    required this.inner,
    required this.kitId,
    required this.toolId,
    required this.log,
    required this.lockHint,
    required this.onFailed,
  }) {
    inner.addListener(_forward);
  }

  final Tool inner;
  final String kitId;
  final String toolId;
  final DiagnosticsLog log;
  final ValueNotifier<bool> lockHint;
  final VoidCallback onFailed;

  bool _broken = false;

  bool get _isKit => kitId != 'plan';

  void _forward() => notifyListeners();

  KitDiagnostic _diagnostic(Object error) => KitDiagnostic(
      kitId: kitId,
      subject: toolId,
      code: KitDiagnosticCode.hookFailed,
      message: '$error',
      error: error);

  /// A getter's failure: a generic tool's is rethrown; a kit's is reported
  /// after the frame (a getter may be read in a build or a paint).
  void _getterFailed(Object error, StackTrace stack) {
    if (!_isKit) Error.throwWithStackTrace(error, stack);
    log.addAfterFrame(_diagnostic(error));
  }

  void _cancelInner(ToolContext ctx) {
    try {
      inner.cancel(ctx);
    } catch (error, stack) {
      if (!_isKit) Error.throwWithStackTrace(error, stack);
      log.add(_diagnostic(error));
    }
  }

  void _failed(Object error, StackTrace stack, ToolContext ctx) {
    if (error is PlanLocked || error is DanglingReferenceError) {
      lockHint.value = true;
      _cancelInner(ctx);
      return;
    }
    if (error is KitHookFailure) {
      log.add(KitDiagnostic(
          kitId: error.kitId,
          subject: error.typeId,
          code: KitDiagnosticCode.hookFailed,
          message: '${error.hook}: ${error.error}',
          error: error.error));
    } else if (_isKit) {
      log.add(_diagnostic(error));
    } else {
      Error.throwWithStackTrace(error, stack);
    }
    _cancelInner(ctx);
    onFailed();
  }

  void _paintFailed(Object error, StackTrace stack) {
    if (!_isKit) Error.throwWithStackTrace(error, stack);
    _broken = true;
    log.addAfterFrame(_diagnostic(error));
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => onFailed())
      ..ensureVisualUpdate();
  }

  @override
  String get name {
    try {
      return inner.name;
    } catch (e, s) {
      _getterFailed(e, s);
      return toolId;
    }
  }

  @override
  ToolPhase get phase {
    try {
      return inner.phase;
    } catch (e, s) {
      _getterFailed(e, s);
      return ToolPhase.idle;
    }
  }

  @override
  TouchPress get touchPress {
    try {
      return inner.touchPress;
    } catch (e, s) {
      _getterFailed(e, s);
      return TouchPress.lift;
    }
  }

  @override
  bool get isMidShape {
    try {
      return inner.isMidShape;
    } catch (e, s) {
      _getterFailed(e, s);
      return false;
    }
  }

  @override
  MouseCursor get cursor {
    try {
      return inner.cursor;
    } catch (e, s) {
      _getterFailed(e, s);
      return MouseCursor.defer;
    }
  }

  @override
  Transform2? get selectionPreviewTransform {
    try {
      return inner.selectionPreviewTransform;
    } catch (e, s) {
      _getterFailed(e, s);
      return null;
    }
  }

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    try {
      inner.onPointerDown(e, ctx);
    } catch (error, stack) {
      _failed(error, stack, ctx);
    }
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    try {
      inner.onPointerMove(e, ctx);
    } catch (error, stack) {
      _failed(error, stack, ctx);
    }
  }

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {
    try {
      inner.onPointerUp(e, ctx);
    } catch (error, stack) {
      _failed(error, stack, ctx);
    }
  }

  @override
  void onPointerExit(ToolContext ctx) {
    try {
      inner.onPointerExit(ctx);
    } catch (error, stack) {
      _failed(error, stack, ctx);
    }
  }

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    try {
      return inner.onKey(event, ctx);
    } catch (error, stack) {
      _failed(error, stack, ctx);
      return KeyEventResult.ignored;
    }
  }

  @override
  void cancel(ToolContext ctx) {
    _broken = false;
    _cancelInner(ctx);
  }

  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {
    if (_broken) return;
    try {
      inner.paintOverlay(canvas, camera, viewport, paper);
    } catch (error, stack) {
      _paintFailed(error, stack);
    }
  }

  @override
  void paintWorldOverlay(
      Canvas canvas, Vector2 origin, double scale, PaperPalette paper) {
    if (_broken) return;
    try {
      inner.paintWorldOverlay(canvas, origin, scale, paper);
    } catch (error, stack) {
      _paintFailed(error, stack);
    }
  }

  @override
  void dispose() {
    inner.removeListener(_forward);
    inner.dispose();
    super.dispose();
  }
}

/// The grip provider behind the boundary: a call that throws is reported
/// (once per type, through [typeIdOf]) and that object has no grips, no
/// drag and does not move until the document is replaced (a drag in flight
/// is refused: its `drag` answers null).
final class GuardedGrips implements ObjectGripProvider {
  GuardedGrips(this._inner,
      {required String? Function(DraftDocument, Handle) typeIdOf,
      required DiagnosticsLog log})
      : _typeIdOf = typeIdOf,
        _log = log;

  final ObjectGripProvider _inner;
  final String? Function(DraftDocument, Handle) _typeIdOf;
  final DiagnosticsLog _log;
  final Set<Handle> _failed = {};

  void _fail(DraftDocument d, Handle group, String member, Object error) {
    _failed.add(group);
    String typeId;
    try {
      typeId = _typeIdOf(d, group) ?? 'plan';
    } catch (_) {
      typeId = 'plan';
    }
    _log.add(KitDiagnostic(
        kitId: kitOfKey(typeId),
        subject: typeId,
        code: KitDiagnosticCode.hookFailed,
        message: 'grips.$member: $error',
        error: error));
  }

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    if (_failed.contains(group)) return const [];
    try {
      return _inner.gripsOf(d, group);
    } catch (error) {
      _fail(d, group, 'gripsOf', error);
      return const [];
    }
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    if (_failed.contains(group)) return null;
    try {
      return _inner.drag(d, group, grip, world);
    } catch (error) {
      _fail(d, group, 'drag', error);
      return null;
    }
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    if (_failed.contains(group)) return const [];
    try {
      return _inner.preview(d, group, grip, world);
    } catch (error) {
      _fail(d, group, 'preview', error);
      return const [];
    }
  }

  @override
  bool movable(DraftDocument d, Handle group) {
    if (_failed.contains(group)) return false;
    try {
      return _inner.movable(d, group);
    } catch (error) {
      _fail(d, group, 'movable', error);
      return false;
    }
  }
}

/// [provider]'s answer to [query], or null when it throws (spec table: an
/// attachment provider's failure is taken as no attachment), reported
/// under [kitId] and the provider's kind.
Attachment? guardAttachment(String kitId, AttachmentProvider provider,
    AttachmentQuery query, void Function(KitDiagnostic) report) {
  try {
    return provider.attach(query);
  } catch (error) {
    String kind;
    try {
      kind = provider.kind;
    } catch (_) {
      kind = 'attachment';
    }
    report(KitDiagnostic(
        kitId: kitId,
        subject: kind,
        code: KitDiagnosticCode.hookFailed,
        message: 'attach: $error',
        error: error));
    return null;
  }
}

/// The controller's flow after a kit's hook failed (spec P4), for one
/// document.
final class FailureBoundary {
  FailureBoundary({
    required this.document,
    required this.catalog,
    required this.system,
    required this.frozen,
    required this.log,
    required this.lock,
    required this.damage,
  });

  final DraftDocument document;
  final ParametricCatalog catalog;
  final ParametricSystem system;

  /// The set the system's `isFrozen` reads.
  final Set<Handle> frozen;
  final DiagnosticsLog log;

  /// The controller's `lockBroken`: locks and clears the history.
  final void Function(Set<Handle> objects) lock;

  /// The controller's damage handler (E3).
  final void Function(PartialMutationError error) damage;

  void _report(KitHookFailure f) => log.add(KitDiagnostic(
      kitId: f.kitId,
      subject: f.typeId,
      code: KitDiagnosticCode.hookFailed,
      message: '${f.hook}: ${f.error}',
      error: f.error));

  void _freeze(Set<Handle> objects) {
    frozen.addAll(objects);
    lock(objects);
  }

  /// [failure] reported; that type's objects probed, and the failing ones
  /// frozen and locked. True when one was: the edit is worth one retry.
  bool recover(KitHookFailure failure) {
    _report(failure);
    final broken = probeType(failure.typeId);
    if (broken.isEmpty) return false;
    _freeze(broken);
    return true;
  }

  /// The live, unfrozen root-level objects of [typeId] whose probe (E2)
  /// fails, ascending by the tree's order.
  Set<Handle> probeType(String typeId) {
    final broken = <Handle>{};
    final root = document.rootHandle;
    for (final node in document.tree.nodes) {
      if (node is! GroupNode || node.parent != root) continue;
      final h = node.handle;
      if (frozen.contains(h) || catalog.typeIdOf(document, h) != typeId) {
        continue;
      }
      if (system.probe(h) != null) broken.add(h);
    }
    return broken;
  }

  /// After a load: one dry run of the whole plan; while it fails on a kit's
  /// hook, that type's failing objects are frozen and locked and it runs
  /// again. Ends when it passes, when nothing more can be frozen, or on an
  /// error that is no kit's (the engine's own reports cover that).
  void probeLoaded() {
    while (true) {
      try {
        system.drift();
        return;
      } on KitHookFailure catch (failure) {
        _report(failure);
        final broken = probeType(failure.typeId);
        if (broken.isEmpty) return;
        _freeze(broken);
      } catch (_) {
        return;
      }
    }
  }

  /// E4: each `component.unreadable` diagnostic of the load is reported as
  /// its kit's `componentUnreadable`, and its handles frozen and locked.
  void reportUnreadable(List<Diagnostic> loadDiagnostics) {
    final unreadable = <Handle>{};
    final registered = catalog.typeIds.toSet();
    for (final d in loadDiagnostics) {
      if (d.code != 'component.unreadable') continue;
      for (final h in d.handles) {
        final typeId = _typeOf(h, d.message, registered);
        log.add(KitDiagnostic(
            kitId: kitOfKey(typeId),
            subject: typeId,
            code: KitDiagnosticCode.componentUnreadable,
            message: d.message));
        unreadable.add(h);
      }
    }
    if (unreadable.isNotEmpty) _freeze(unreadable);
  }

  /// The registered type whose payload [h] kept raw, else the message's
  /// `<typeId>:` prefix (E4's message shape).
  String _typeOf(Handle h, String message, Set<String> registered) {
    for (final payload in document.components.unknownOf(h)) {
      final typeId = payload['typeId'];
      if (typeId is String && registered.contains(typeId)) return typeId;
    }
    final colon = message.indexOf(':');
    return colon > 0 ? message.substring(0, colon) : message;
  }

  /// E3: a rollback threw. Reported, then the controller rebuilds through
  /// `notifyLoaded` and marks the plan damaged.
  void partialMutation(PartialMutationError error) {
    log.add(KitDiagnostic(
        kitId: 'plan',
        code: KitDiagnosticCode.rollbackFailed,
        message: error.message,
        error: error));
    damage(error);
  }
}
```

  Create `lib/src/kits/section_boundary.dart`:

```dart
// Spec P4 "The failure boundary", the section row: a kit's section builder
// that throws leaves a small "section failed" box in its place; a widget
// it returned that fails while building shows Flutter's ErrorWidget in its
// place only, and the plan stays usable. The diagnostic is published after
// the frame (a build must not notify).
import 'package:flutter/material.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../l10n/strings.dart';
import 'guard.dart';

/// Builds a kit's property section through [builder], behind the boundary.
class KitSectionBoundary extends StatelessWidget {
  const KitSectionBoundary({
    super.key,
    required this.kitId,
    required this.typeId,
    required this.log,
    required this.builder,
  });

  final String kitId;
  final String typeId;
  final DiagnosticsLog log;

  /// Calls the type's section (`PlanType.sectionFor`); null for none.
  final Widget? Function(BuildContext context) builder;

  @override
  Widget build(BuildContext context) {
    final Widget? section;
    try {
      section = builder(context);
    } catch (error) {
      log.addAfterFrame(KitDiagnostic(
          kitId: kitId,
          subject: typeId,
          code: KitDiagnosticCode.hookFailed,
          message: 'section: $error',
          error: error));
      final scheme = Theme.of(context).colorScheme;
      return Container(
        key: const Key('kit-section-failed'),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.error),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(PlanStrings.of(context).sectionFailed,
            style: TextStyle(color: scheme.error)),
      );
    }
    return section ?? const SizedBox.shrink();
  }
}
```

  Replace the whole of `lib/src/controller/diagnostics_log.dart` (Task 8's minimal log; controller ruling R-j: completed in place, every member Task 8's callers use kept: the `ValueListenable` itself, `planScoped`, `report`, `reportAll`, `clearPlanScoped`) with:

```dart
// Spec P4 "Diagnostics": the controller's kit diagnostics, one per kit id,
// subject and code, in arrival order, as a listenable list. The plan's own
// (a missing kit, a newer kit, a component that does not read, a failed
// rollback, an unsavable plan) are cleared when the plan is replaced; the
// kit set's stay. Task 8 made the minimal log; Task 11 makes it the
// boundary's: deduplicated, and safe to add to from a build or a paint.
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

final class DiagnosticsLog extends ChangeNotifier
    implements ValueListenable<List<KitDiagnostic>> {
  /// The codes that belong to one plan.
  static const Set<KitDiagnosticCode> planScoped = {
    KitDiagnosticCode.kitMissing,
    KitDiagnosticCode.kitNewer,
    KitDiagnosticCode.componentUnreadable,
    KitDiagnosticCode.rollbackFailed,
    KitDiagnosticCode.damagedUnsavable,
  };

  List<KitDiagnostic> _value = const [];
  final Set<(String, String?, KitDiagnosticCode)> _seen = {};
  List<KitDiagnostic>? _pending;
  bool _disposed = false;

  @override
  List<KitDiagnostic> get value => _value;

  /// The log itself, as the boundary's callers name it.
  ValueListenable<List<KitDiagnostic>> get entries => this;

  List<KitDiagnostic> get _current => _pending ?? _value;

  bool _isNew(KitDiagnostic d) => _seen.add((d.kitId, d.subject, d.code));

  void _publish(List<KitDiagnostic> next) {
    _pending = null;
    _value = List.unmodifiable(next);
    notifyListeners();
  }

  /// Adds [diagnostic] and tells the listeners now; false (and nothing
  /// changes) when its kit, subject and code are already in the log. Not
  /// for a build or a paint: use [addAfterFrame] there.
  bool add(KitDiagnostic diagnostic) {
    if (!_isNew(diagnostic)) return false;
    _publish([..._current, diagnostic]);
    return true;
  }

  /// Task 8's name for [add].
  void report(KitDiagnostic diagnostic) => add(diagnostic);

  /// Adds each new one of [diagnostics], then tells the listeners once.
  void reportAll(Iterable<KitDiagnostic> diagnostics) {
    final next = [..._current];
    for (final d in diagnostics) {
      if (_isNew(d)) next.add(d);
    }
    if (next.length == _current.length) return;
    _publish(next);
  }

  /// Adds [diagnostic] at once (a second one of the same kit, subject and
  /// code is refused at once), and tells the listeners after the current
  /// frame: for a failure inside a build or a paint.
  bool addAfterFrame(KitDiagnostic diagnostic) {
    if (!_isNew(diagnostic)) return false;
    final first = _pending == null;
    _pending = List<KitDiagnostic>.unmodifiable([..._current, diagnostic]);
    if (first) {
      SchedulerBinding.instance
        ..addPostFrameCallback((_) {
          final next = _pending;
          if (next != null && !_disposed) _publish(next);
        })
        ..ensureVisualUpdate();
    }
    return true;
  }

  /// Drops the [planScoped] diagnostics: the plan they spoke of is gone, so
  /// the next plan may report them again.
  void clearPlanScoped() {
    final current = _current;
    final kept = [
      for (final d in current)
        if (!planScoped.contains(d.code)) d,
    ];
    _seen.removeWhere((key) => planScoped.contains(key.$3));
    if (kept.length == current.length) return;
    _publish(kept);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
```

  `PlanController.diagnostics` keeps returning the log itself (Task 8), and every `report`/`reportAll`/`clearPlanScoped` call of Task 8 compiles unchanged.

  In `lib/jet_cad_2d_plan.dart` add `export 'src/kits/guard.dart' show KitHookFailure;`.

- [ ] **Step 4: The retry in the lock wrapper.** In `lib/src/kits/locks.dart` (Task 10):
  1. Add `import 'guard.dart' show KitHookFailure;`.
  2. In `LockExpander`, add the two hooks and make `_expand` wrap whenever one is set:

```dart
  /// Called when the applied command threw a [KitHookFailure]: true when
  /// it froze something, so the edit is worth one retry (Task 11).
  bool Function(KitHookFailure failure)? onHookFailure;

  /// Called when the applied command left the target partially mutated
  /// (E3), before the error goes on to the caller (Task 11).
  void Function(PartialMutationError error)? onPartialMutation;

  DraftCommand _expand(DraftCommand command) {
    final inner = expandInner(command);
    if (locks.isEmpty && onHookFailure == null && onPartialMutation == null) {
      return inner;
    }
    return _LockCheck(this, command, inner);
  }
```

     (replacing Task 10's `_expand`).
  3. Replace `_LockCheck.apply` with:

```dart
  @override
  CommandResult apply(CommandTarget target) {
    try {
      return _check(target, _first(target));
    } on PartialMutationError catch (error) {
      _expander.onPartialMutation?.call(error);
      rethrow;
    }
  }

  /// [_applied] applied; on a kit's hook failure that the boundary
  /// recovers from (it froze the failing objects), [original] expanded
  /// afresh (a ParametricEdit applies once) and applied once more. A second
  /// failure goes on: the command is refused.
  CommandResult _first(CommandTarget target) {
    try {
      return _applied.apply(target);
    } on KitHookFailure catch (failure) {
      final recover = _expander.onHookFailure;
      if (recover == null || !recover(failure)) rethrow;
      _applied = _expander.expandInner(original);
      return _applied.apply(target);
    }
  }
```

- [ ] **Step 5: Wire the session and the controller.** In `lib/src/controller/plan_controller.dart` (Task 8), import `../kits/guard.dart` and `../file/plan_file.dart` (if not already), then (item 4 also edits `session.dart`):
  1. **The log.** The controller keeps Task 8's log field `_diagnostics` (`@internal diagnosticsLog`), now the class of Step 3; `diagnostics` returns it as before, and `dispose` calls its `dispose()` as before.
  2. **Registration.** Where Task 8 registers each kit type, `planType.registerInto(catalog)` becomes `planType.registerInto(catalog, guard: const PlanTypeGuard())`.
  3. **New controller-lifetime members:**

```dart
  /// Set when an edit is refused because it would change a locked object;
  /// the canvas shows a short hint and clears it (Task 15).
  final ValueNotifier<bool> lockHint = ValueNotifier(false);

  final ValueNotifier<bool> _damaged = ValueNotifier(false);

  /// Whether a rollback threw in this document (E3): the plan was rebuilt
  /// from what it holds, and saving reads it back first. Listenable: the
  /// editor's bar shows a warning while it holds (Task 20).
  ValueListenable<bool> get damaged => _damaged;

  final Set<String> _disabledTools = {};

  /// Whether [toolId]'s factory threw for the current document.
  bool isToolDisabled(String toolId) => _disabledTools.contains(toolId);

  /// Executes [command] on the current document: the commit path of every
  /// widget and panel (controller ruling R-b; no widget calls
  /// `document.commands.execute`). True when it applied; false when it was
  /// refused, the refusal caught here: [PlanLocked] (and [lockHint] set),
  /// `DanglingReferenceError` (E2's refusal of a frozen object's
  /// referrer), `ArgumentError`, and a kit's hook failure the retry did not
  /// cure (one diagnostic). `StateError` (`PartialMutationError` included,
  /// after the damage is handled) goes on to the caller.
  bool execute(DraftCommand command) {
    try {
      document.commands.execute(command);
      return true;
    } on PlanLocked {
      lockHint.value = true;
      return false;
    } on DanglingReferenceError {
      return false;
    } on ArgumentError {
      return false;
    } on KitHookFailure catch (failure) {
      _diagnostics.add(KitDiagnostic(
          kitId: failure.kitId,
          subject: failure.typeId,
          code: KitDiagnosticCode.hookFailed,
          message: '${failure.hook}: ${failure.error}',
          error: failure.error));
      return false;
    }
  }

  void _damage(PartialMutationError error) {
    _damaged.value = true;
    document.commands.notifyLoaded();
    _session.locks.addBroken(document, const []);
    _refreshFlags();
    notifyListeners();
  }
```

     `lockHint.dispose()` and `_damaged.dispose()` in `dispose`.
  4. **The per-document build.** It lives in Task 8's `DocumentSession` (`lib/src/controller/session.dart`, import `../kits/guard.dart` and `diagnostics_log.dart`) and its `_open`; the session owns what it builds (Shared interfaces).
     - Task 8's frozen set is `DocumentSession.frozen`, a fresh set per document already passed as `isFrozen: frozen.contains`: nothing to add.
     - The session's constructor gains `required DiagnosticsLog log` and `required Tool Function(String kitId, String toolId, Tool tool) guard`, kept in `final DiagnosticsLog _log;` and `final Tool Function(String, String, Tool) _guard;`. In its body, the `GripCache`'s `objects` becomes `LockedGrips(locks, GuardedGrips(dispatch, typeIdOf: catalog.typeIdOf, log: log))`, and the two lines that make the tool controller and register select become (every tool in the map is guarded, the plan's own under kit id `'plan'`):

```dart
    final guardedSelect = guard('plan', planSelectToolId, select);
    _entries.add((id: planSelectToolId, tool: guardedSelect, kit: false));
    tools = ToolController(initial: guardedSelect, context: toolContext);
```

     - `addTool(String id, Tool tool)` stores `_guard('plan', id, tool)`.
     - `runKitFactories(KitSet kits, Map<String, PlanServices> services, Set<String> disabled)`: each kit tool is `guardFactory(kit.id, tool.id, () => tool.create(s), _log)`; a null result adds `tool.id` to `disabled` and leaves the tool out of the map (`selectTool` of a missing id leaves `plan.select` armed, F-8); otherwise the map gets `_guard(kit.id, tool.id, made)`. Each `PlanType.gripsFor(s)` is called through `guardFactory(kitOfKey(type.id), type.id, () => type.gripsFor(s), _log)` (a null result: that type has no grips).
     - A field `late final FailureBoundary boundary;` (set once by `_open`, below; the boundary holds no resource, it goes with its session).
     - Disposal: the session's `dispose()` disposes the map's tools, as Task 8 wrote it; each `GuardedTool` disposes its inner, so `select` (the inner of the select entry) is disposed exactly once and nothing else disposes a tool.
     - In `plan_controller.dart`, add

```dart
  /// The decorator every tool of a document's map wears (spec P4).
  Tool _guardTool(String kitId, String toolId, Tool tool) => GuardedTool(
      inner: tool,
      kitId: kitId,
      toolId: toolId,
      log: _diagnostics,
      lockHint: lockHint,
      onFailed: () => selectTool(planSelectToolId));
```

       and in Task 8's `_open`: first `_damaged.value = false; _disabledTools.clear();`; the `DocumentSession(...)` call gains `log: _diagnostics, guard: _guardTool`; `session.runKitFactories(kits, _services)` becomes `session.runKitFactories(kits, _services, _disabledTools)`; right after Task 10's `_locked.value = session.locks.objects;`:

```dart
    session.boundary = FailureBoundary(
        document: document,
        catalog: catalog,
        system: session.parametric,
        frozen: session.frozen,
        log: _diagnostics,
        lock: lockBroken,
        damage: _damage);
    session.lockExpander
      ..onHookFailure = session.boundary.recover
      ..onPartialMutation = session.boundary.partialMutation;
```

     - At the end of `_open` (the grips, gates and kit products made, `_session` set, so `lockBroken` can refresh them): `session.boundary.reportUnreadable(_loadDiagnostics); session.boundary.probeLoaded();` (`_loadDiagnostics` is the list Task 8's `_open` keeps from `decodePlan`; empty for `newPlan`).
     - In Task 8's `_replace`, `old.tools.activate(old.select);` becomes `old.tools.activate(old.toolById(planSelectToolId)!);` (the guarded entry, the one the tool controller knows).
  5. **Saving a damaged plan.** Rename Task 8's `save()` to `String _saveUnchecked()` and add:

```dart
  /// The design document's text (spec P2). A damaged plan (E3) is first
  /// read back; if it does not encode or does not decode, nothing is
  /// returned: PlanFormatException(damagedUnsavable), and a diagnostic.
  String save() {
    if (!_damaged.value) return _saveUnchecked();
    final String text;
    try {
      text = _saveUnchecked();
      decodePlan(text, register: _registerComponents, diagnostics: <Diagnostic>[])
          .dispose();
    } catch (error) {
      _diagnostics.add(KitDiagnostic(
          kitId: 'plan',
          code: KitDiagnosticCode.damagedUnsavable,
          message: '$error',
          error: error));
      throw PlanFormatException(PlanFormatCode.damagedUnsavable,
          'the damaged plan does not read back: $error');
    }
    return text;
  }
```

- [ ] **Step 6: Run the tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/kits`. Expected: `All tests passed!`. Then `flutter test` for the whole package: `All tests passed!` (Task 8's and Task 10's tests unchanged: a healthy kit's hooks pass straight through the guard).

- [ ] **Step 7: The engine's allocation invariant.** Run: `cd packages/jet_cad_2d && dart test test/invariants/query_allocation_test.dart`. Expected: `All tests passed!` (the engine's catalog does not hold the guard here; this checks nothing of the engine changed under this task).

- [ ] **Step 8: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0. If `flutter analyze` reports an import of this task's new files as unnecessary or unused (Flutter's libraries re-export parts of one another), delete that import line; change nothing else to quiet it. From the root, `git status --short`: only this task's files.

- [ ] **Step 9: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/controller/diagnostics_log.dart packages/jet_cad_2d_plan/lib/src/kits/guard.dart packages/jet_cad_2d_plan/lib/src/kits/section_boundary.dart packages/jet_cad_2d_plan/lib/src/kits/locks.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/src/controller/session.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/test/kits/guarded_type_test.dart packages/jet_cad_2d_plan/test/kits/failure_flow_test.dart packages/jet_cad_2d_plan/test/kits/guarded_tool_test.dart packages/jet_cad_2d_plan/test/kits/guard_boundaries_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): the failure boundary around every kit hook (2a P4)

Each kit type runs behind a guarding adapter that names the kit, the
type and the hook of whatever it throws. A failed edit probes that
type's objects, freezes and locks the broken ones, clears the history
and runs once more, so one broken object blocks one edit at most; a load
runs one dry pass first. Tools, grips, attachment providers, factories
and sections fail into diagnostics, a damaged plan saves only what reads
back, and the log keeps one entry per kit, subject and code.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 10: Mutation check** (committed files only; after each: run the named test file with `cd packages/jet_cad_2d_plan && flutter test <file>`, see the named test red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0):
  - M-F-G1 … M-F-G13, `lib/src/kits/guard.dart`: in `GuardedType`, the named member's body (`try … catch`) → `return inner.<member>(…);` (a getter: `return inner.<getter>;`), one member at a time: `reach` (G1), `references` (G2), `generate` (G3), `dissolves` (G4), `diagnose` (G5), `editCapability` (G6), `referencePolicy` (G7), `pageKey` (G8), `placeBox` (G9a), `placeInput` (G10), `readBox` (G11), `contributesPlace` (G12), `readsPlaces` (G13) → that F-G test red (`test/kits/guarded_type_test.dart`).
  - M-F-G9b `guard.dart`: delete `on KitHookFailure { rethrow; }` from `GuardedType.generate` → F-G9 red (attributed to `ring.disc` `generate`).
  - M-F-G14 `guard.dart`: `PlanTypeGuard.wrap` → `=> type;` → F-G14 red.
  - M-F1a `guard.dart`: `recover`'s body → `return false;` → F-1 red (`test/kits/failure_flow_test.dart`).
  - M-F1b `guard.dart`: in `_freeze`, delete `frozen.addAll(objects);` → F-1 red.
  - M-F2 `plan_controller.dart`: in `_open`, delete `..onHookFailure = session.boundary.recover` → F-2 red.
  - M-F3a `plan_controller.dart`: in `execute`, the `KitHookFailure` clause's `return false;` → `rethrow;` → F-3 red.
  - M-F1c `plan_controller.dart`: in `execute`'s `on PlanLocked` clause, delete `lockHint.value = true;` → F-1 red.
  - M-F9a `plan_controller.dart`: delete `execute`'s `on ArgumentError { return false; }` clause → F-9 red (the error reaches the test).
  - M-F9b `plan_controller.dart`: delete `execute`'s `on DanglingReferenceError { return false; }` clause → F-9 red.
  - M-F3b `lib/src/controller/diagnostics_log.dart`: `_isNew`'s body → `true` → F-3 and F-B4 red.
  - M-F4 `plan_controller.dart`: delete `session.boundary.probeLoaded();` → F-4 red.
  - M-F5 `plan_controller.dart`: delete `session.boundary.reportUnreadable(...);` → F-5 red.
  - M-F6a `plan_controller.dart`: delete `..onPartialMutation = session.boundary.partialMutation` → F-6 red.
  - M-F6b `plan_controller.dart`: delete `document.commands.notifyLoaded();` in `_damage` → F-6 red.
  - M-F7 `plan_controller.dart`: `save`'s first line → `return _saveUnchecked();` → F-7 red.
  - M-F8 `session.dart`: in `runKitFactories`, the kit tool made with `tool.create(s)` bare (no `guardFactory`) → F-8 red.
  - M-F-T1-onPointerDown … M-F-T1-onKey `guard.dart`: in `GuardedTool`, that member's body → the bare inner call → F-T1 red (`test/kits/guarded_tool_test.dart`), one member at a time.
  - M-F-T2 `guard.dart`: delete the `if (error is PlanLocked || error is DanglingReferenceError) {…}` block → F-T2 red.
  - M-F-T3 `guard.dart`: delete the `if (error is KitHookFailure) {…} else` head, keeping `if (_isKit) … else rethrow` → F-T3 red.
  - M-F-T4 `guard.dart`: `_isKit` → `true` → F-T4 red.
  - M-F-T5 `guard.dart`: in `_paintFailed`, `..addPostFrameCallback((_) => onFailed())` → call `onFailed();` directly → F-T5 red.
  - M-F-T6a `guard.dart`: `isMidShape` → `false` → F-T6 red; M-F-T6b: delete `inner.addListener(_forward);` → F-T6 red; M-F-T6c: delete `inner.dispose();` → F-T6 red.
  - M-F-B1a `guard.dart`: `GuardedGrips.gripsOf` → `return _inner.gripsOf(d, group);` → F-B1 red (`test/kits/guard_boundaries_test.dart`); M-F-B1b: delete its `if (_failed.contains(group)) return const [];` → F-B1 red; M-F-B1c/d/e: `drag`, `preview`, `movable` each → the bare inner call → F-B1 red.
  - M-F-B2 `guard.dart`: `guardAttachment` → `return provider.attach(query);` → F-B2 red.
  - M-F-B3a `section_boundary.dart`: `build` → `return builder(context) ?? const SizedBox.shrink();` → F-B3 red; M-F-B3b `diagnostics_log.dart`: `addAfterFrame`'s body → `return add(diagnostic);` → F-B3 red.
  - M-F-B4 `diagnostics_log.dart`: the `_seen` key `(d.kitId, d.subject, d.code)` → `(d.kitId, d.subject, KitDiagnosticCode.hookFailed)` → F-B4 red.

  Quote each red line.

#### Assumed from earlier tasks

Each name below is used as written; where an earlier task named it otherwise, the implementer uses that task's name and reports the difference.
- Task 8 keeps per-document state in a `DocumentSession` (`lib/src/controller/session.dart`); the old session is disposed one frame after a swap (`_drop`). Task 10's `locks`, `lockExpander`, `lockGates` are session members; this task's `boundary` is one too (Step 5); `frozen` is Task 8's.
- Task 8 (`lib/src/controller/plan_controller.dart`): everything Task 10 assumed, plus `ValueListenable<List<KitDiagnostic>> get diagnostics` over a private log with `add(KitDiagnostic)`; `bool selectTool(String id)` (a missing or disabled id leaves `plan.select` armed); `ValueListenable<String> get activeTool` (the active tool's id); `@internal ToolController get toolController` (Tasks 12 and 15 assume it too); an id → `Tool` map filled per document from the generic tools and each kit's `PlanTool.create(services)`, disposed per document; each `PlanType.gripsFor(services)` called per document into one dispatching `ObjectGripProvider`; the `ParametricCatalog` in a field `catalog` (Task 18 assumes `ParametricCatalog get catalog`); a per-document frozen set passed as `isFrozen`; the load path calling Task 7's `decodePlan` with a `List<Diagnostic>` it keeps until the build ends; one registration function (engine built-ins, `registerKitComponents`, each `PlanType.registerInto`) handed to `decodePlan(register:)`.
- Task 7: `decodePlan(String text, {required void Function(ComponentRegistry) register, required List<Diagnostic> diagnostics}) → DraftDocument` (passing `keepUnreadableComponents: true` to the codec, E4); `PlanFormatException(PlanFormatCode code, String message)` with `PlanFormatCode get code`.
- Task 4: `KitDiagnostic` exposes `kitId`, `subject`, `code`, `message`, `error` as fields; `PlanType.registerInto(catalog, guard:)` calls `guard.wrap<T>(kitOfKey(id), id, parametric)`; `PlanKit.types` is a `List<PlanType<Component>>` (F-G14 reads `.single`); `AttachmentQuery({required Aabb2 footprint, required Transform2 current, required Vector2 pointer, required double capture, required double edgeCapture, required bool mirrored, required bool mayRotate, Set<Handle> exclude = const {}, Attachment? keep})` (the field list of spec P3, named).
- Task 2 (E2): `ParametricSystem.probe(Handle)` runs every hook an edit can call (reach, references, pageKey, the place hooks, readBox, dissolves, a dry `generate`, diagnose), so F-2's `placeBox` failure is found by the probe; `drift()` calls the type hooks through the system's own view.
- Task 1 (E3, E4): `PartialMutationError` from `_undoInner` (`regeneration.dart:730-738`), which F-6 and F-7 reach; E4's diagnostic shape.
- Task 9: `PlanStrings.sectionFailed` in `lib/src/l10n/strings.dart` (English "This section could not be shown").
- Task 10: `LockExpander.expandInner`, `_LockCheck(expander, original, applied)` with `_check`, `LockSet.addBroken`, `LockedGrips`, `PlanController.lockBroken`, `canon`, `addObject`, `addLine`, `kids`, `coordsOf`, `componentsText`, `atSquare`, `nearSquare`, `Switches`, `HookBoom`, `SquareParams`, `DiscParams`, `SquareType`, `boxKit`, `ringKit` (`test/support/box_kit.dart`).

#### Interface problem

Resolved by controller ruling R-b: `PlanController.execute(DraftCommand) -> bool` catches `PlanLocked` (setting `lockHint`), `DanglingReferenceError`, `ArgumentError` and `KitHookFailure` and answers false (Step 5, F-1, F-9); Tasks 17 and 18 commit through it and catch none of these.

---

