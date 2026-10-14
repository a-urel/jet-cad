### Task 10: Locks (spec P4 "Locks: a missing kit, a broken object")

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/kits/locks.dart`
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` and `packages/jet_cad_2d_plan/lib/src/controller/session.dart` (Task 8 keeps the per-document build and teardown in `DocumentSession`: `session.dart` gains `locks`, `lockExpander`, `lockGates` and the constructor's `kitLoaded`, `locked`; `plan_controller.dart` gains `locked`, `isLocked`, `lockBroken`), `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (export `PlanLocked`)
- Test: `packages/jet_cad_2d_plan/test/support/box_kit.dart` (fixture, reused by Task 11), `packages/jet_cad_2d_plan/test/kits/locks_test.dart`

(Paths below are under `packages/jet_cad_2d_plan/`.)

**Interfaces:**
- Consumes:
  - Engine: `CommandDispatcher.expander`, `execute`, `clearHistory` (`jet_cad_2d/lib/src/document/undo.dart:151`, `:187-203`, `:277`); `DraftCommand`, `CommandResult` (`command.dart:115-137`); `DocumentTree.nodes`, `definitions`, `operator []`, `Node.parent`, `InstanceNode.definition`; `EntityStore.liveSlots`, `slotOf`, `ownerAt`, `handleAt`; `ComponentRegistry.unknownOf` (`component.dart:247`); `PartialMutationError` (E3, Task 1).
  - Flutter layer: `ObjectGripProvider` (`grip_cache.dart:33-56`), `GripCache(document, selection, outlines, {objects, gates})` (`:194-212`), `GripCache.gatesChanged` (`:308`), `SelectGates` (`select_gates.dart:22-62`), `SelectTool({moveResolver, gates})` (`select_tool.dart:57`), `SelectionController.keys`, `SelectionKey.target`, `.chain`.
  - Contract: `SymbolComponent`, `isKitId`, `kitOfKey`, `PlanKit`, `PlanType`, `PlanTool`, `KitNames`, `ManifestComponent`.
  - Task 8: see "Assumed from earlier tasks".
- Produces:
  - Exported from the barrel: `final class PlanLocked implements Exception` — `const PlanLocked()`.
  - On `PlanController` (public): `ValueListenable<Set<Handle>> get locked` (the locked objects: a missing kit's, an unknown type's, a broken one's; never the root); `bool isLocked(Handle handle)` (the handle is a locked object, inside one, or inside a locked symbol's definition: Task 17's panel and Task 18's pickers read it).
  - On `PlanController` (`@internal`, Task 11): `void lockBroken(Set<Handle> objects)` (adds them, clears the undo history, refreshes `locked`, the undo listenables and the grip cache's gates).
  - Internal (`lib/src/kits/locks.dart`): `final class LockSet` (`LockSet.scan(DraftDocument, bool Function(String kitId) loaded)`, `Set<Handle> get objects`, `bool get isEmpty`, `bool isLockedObject(Handle)`, `bool covers(CommandTarget, Handle)`, `void addBroken(CommandTarget, Iterable<Handle>)`); `final class LockExpander` (`LockExpander(DraftDocument document, LockSet locks)`, `install()`, `dispose()`); `final class LockedGrips implements ObjectGripProvider` (`LockedGrips(LockSet locks, ObjectGripProvider? inner)`); `base class LockGates extends SelectGates` (`LockGates({required SelectionController selection, required ValueListenable<Set<Handle>> locked})`, `bool get selectionLocked`, `dispose()`; Task 12's `PlanSelectGates` extends it).

Plan decision (which objects are locked; spec P4 "Which objects are locked"):
- A node (not the root) that carries an **unknown** component whose type id is kit-namespaced: it contains a `.`, its first segment is a kit id (`isKitId`, `jet_cad_2d_kit/lib/src/model/kit_ids.dart:13`) and is neither `jetcad` nor `plan`. The engine keeps such a component raw (`component.dart:304-311`, `unknownOf` at `:247`). This covers the spec's "component type id under a missing kit's id", and also a type a **loaded** kit does not have (a plan saved by a newer version of the kit, spec R6) and a component E4 kept raw because its factory threw. Locking those too is the conservative reading of A9: what no loaded code can regenerate stays as saved. `jet_cad.object_layer` (`object_layer.dart:17`) is not kit-namespaced (`jet_cad` is no kit id), so it never locks.
- A definition whose `SymbolComponent` key's kit is not loaded (the component is on a definition's handle, `symbol_component.dart:1-2`), or that carries an unknown kit-namespaced component, and every `InstanceNode` of such a definition (spec: "every placed symbol whose key is under a missing kit's id"). The definitions are guarded too (an edit inside one would change every instance) but are not reported in `locked` (the spec reports objects).
- The objects Task 11 finds broken, through `lockBroken`.

Plan decision (how a lock is checked on commit; spec P4 "How a lock is enforced"): the wrapper applies the command, then tests every handle of `result.touched` with `LockSet.covers`: the handle is a locked object or definition, or one of its container chain is (an entity's `owner`, `entity_store.dart:342`; a node's `parent`, `node.dart:24`, which for a node inside a definition is the definition's handle, `tree.dart:165-175`), **or** it was inside one when the lock set was last refreshed (a closure of every node and entity under a locked object, computed when the set changes). The closure is what catches a removal: after `RemoveEntityCommand` applies, the removed handle has no owner left to walk (`commands.dart:124-155`). On a hit the wrapper applies `result.inverse` and throws `PlanLocked`; if that inverse throws, the target is partially mutated and the wrapper throws `PartialMutationError` (E3's type, which Task 11's flow handles). This is the engine's own apply-check-rollback (`regeneration.dart:968-1046`), stacked on the expander slot the way `TableLabelSystem` stacks (`jet_cad_floor_plan/lib/src/tables/table_label_system.dart:27-48`). With nothing locked the expander returns the parametric system's command unwrapped (no allocation, no walk).

Plan decision (a frozen object's children): E2 makes a frozen object a plain group whose children the engine lets a command edit directly (Task 2's semantics, in the Shared interfaces). The lock covers them: `lockBroken` refreshes the closure, and the walk reaches the frozen group from any of its children (L-3, L-8).

Plan decision (the up-front layer and Task 12): the grip provider is wrapped in `LockedGrips` (no grips, not movable, no drag, no preview for a covered group). The select gates are `LockGates` (a `base class`); Task 12's `PlanSelectGates` extends it, adding the permissions, so the lock rule exists once (a selected key's target or a handle of its chain in the set: L-10 here, Task 12's PM-9, PM-10); L-6 reads the gates through `controller.grips.gates`, so it stays green after Task 12. `deleteSelection` refuses through the same gates (Task 8's `deleteSelection` is the select tool's own, `select_tool.dart:744-753`, as Task 12 also states).

Plan decision (undo; spec P4 "Undo and a lock"): `undo` and `redo` skip the expander (`undo.dart:144-151`), so a mid-session lock clears the history: `lockBroken` calls `commands.clearHistory()` (`undo.dart:277`), which emits no change event, so it also refreshes Task 8's `canUndo`/`canRedo` notifiers itself. A missing kit's objects are locked at load, when the history is empty.

- [ ] **Step 1: The fixture.** Create `test/support/box_kit.dart` (Task 11 reuses it):

```dart
// Two small kits for the lock and failure-boundary tests (2a Tasks 10, 11):
// `box` (a square that contributes places, a stamp tool) and `ring` (a disc
// that reads places). Every hook of both types can be made to throw through
// one shared [Switches]: a per-object hook throws for an object whose
// params are `poisoned`, a type-level hook (a getter, `pageKey`, a factory)
// throws for every call. The scene sits off the origin, turned.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyEvent;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// What a switched hook throws.
final class HookBoom implements Exception {
  const HookBoom(this.hook);
  final String hook;
  @override
  String toString() => 'HookBoom($hook)';
}

/// The hooks made to throw, by name: `reach`, `references`, `generate`,
/// `diagnose`, `dissolves`, `placeBox`, `placeInput`, `readBox` (per object,
/// for a poisoned one); `editCapability`, `referencePolicy`, `pageKey`,
/// `contributesPlace`, `readsPlaces`, `create` (type level); `fromJson` (a
/// poisoned component's factory).
final class Switches {
  final Set<String> failing = {};

  void check(String hook, [bool poisoned = true]) {
    if (poisoned && failing.contains(hook)) throw HookBoom(hook);
  }
}

@immutable
final class SquareParams implements Component {
  const SquareParams({required this.side, this.poisoned = false, this.partner});

  static const String id = 'box.square';

  final double side;
  final bool poisoned;

  /// An object this square references (a `cascade` referrer of it).
  final Handle? partner;

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() =>
      {'partner': partner?.value, 'poisoned': poisoned, 'side': side};

  static SquareParams fromJson(Map<String, Object?> json) => SquareParams(
      side: (json['side']! as num).toDouble(),
      poisoned: json['poisoned']! as bool,
      partner: json['partner'] == null ? null : Handle(json['partner']! as int));

  SquareParams copyWith({double? side, bool? poisoned}) => SquareParams(
      side: side ?? this.side,
      poisoned: poisoned ?? this.poisoned,
      partner: partner);

  @override
  bool operator ==(Object other) =>
      other is SquareParams &&
      other.side == side &&
      other.poisoned == poisoned &&
      other.partner == partner;

  @override
  int get hashCode => Object.hash(side, poisoned, partner);
}

@immutable
final class DiscParams implements Component {
  const DiscParams({required this.radius, this.poisoned = false});

  static const String id = 'ring.disc';

  final double radius;
  final bool poisoned;

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() => {'poisoned': poisoned, 'radius': radius};

  static DiscParams fromJson(Map<String, Object?> json) => DiscParams(
      radius: (json['radius']! as num).toDouble(),
      poisoned: json['poisoned']! as bool);

  @override
  bool operator ==(Object other) =>
      other is DiscParams && other.radius == radius && other.poisoned == poisoned;

  @override
  int get hashCode => Object.hash(radius, poisoned);
}

/// A centred square of side [side] mapped by [toWorld], boxed.
Aabb2 squareBox(double side, Transform2 toWorld) {
  final h = side / 2;
  return Aabb2.fromPoints([
    for (final (x, y) in [(-h, -h), (h, -h), (h, h), (-h, h)])
      toWorld.transformPoint(Vector2(x, y)),
  ]);
}

/// A disc of [radius] at [toWorld]'s origin, boxed (the transforms here are
/// rigid).
Aabb2 discBox(double radius, Transform2 toWorld) {
  final c = toWorld.transformPoint(Vector2.zero());
  return Aabb2.fromPoints(
      [c - Vector2(radius, radius), c + Vector2(radius, radius)]);
}

final class SquareType extends ParametricType<SquareParams> {
  SquareType(this.sw);
  final Switches sw;

  bool _poisoned(ParametricView v, Handle h) =>
      v.paramsOf<SquareParams>(h)?.poisoned ?? false;

  @override
  Capability get editCapability {
    sw.check('editCapability');
    return Capability.geometry;
  }

  @override
  Aabb2 reach(SquareParams params, Transform2 toWorld) {
    sw.check('reach', params.poisoned);
    return squareBox(params.side, toWorld);
  }

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<SquareParams>(self)!;
    sw.check('generate', p.poisoned);
    final h = p.side / 2;
    final c = [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)];
    return [
      for (var i = 0; i < 4; i++)
        Generated(EntityKind.line, linePayload(c[i], c[(i + 1) % 4])),
    ];
  }

  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) {
    sw.check('diagnose', _poisoned(view, self));
    return const [];
  }

  @override
  Iterable<Handle> references(SquareParams params) {
    sw.check('references', params.poisoned);
    final p = params.partner;
    return p == null ? const [] : [p];
  }

  @override
  ReferencePolicy get referencePolicy {
    sw.check('referencePolicy');
    return ReferencePolicy.cascade;
  }

  @override
  Object? pageKey(PageComponent? page) {
    sw.check('pageKey');
    return null;
  }

  @override
  bool dissolves(ParametricView view, Handle self) {
    sw.check('dissolves', _poisoned(view, self));
    return false;
  }

  @override
  bool get contributesPlace {
    sw.check('contributesPlace');
    return true;
  }

  @override
  Aabb2? placeBox(ParametricView view, Handle self) {
    final p = view.paramsOf<SquareParams>(self)!;
    sw.check('placeBox', p.poisoned);
    return squareBox(p.side, view.toWorld(self));
  }

  @override
  Object placeInput(ParametricView view, Handle self) {
    final p = view.paramsOf<SquareParams>(self)!;
    sw.check('placeInput', p.poisoned);
    final t = view.toWorld(self);
    return (p.side, t.a, t.b, t.c, t.d, t.e, t.f);
  }

  @override
  bool get readsPlaces {
    sw.check('readsPlaces');
    return false;
  }
}

final class DiscType extends ParametricType<DiscParams> {
  DiscType(this.sw);
  final Switches sw;

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(DiscParams params, Transform2 toWorld) {
    sw.check('reach', params.poisoned);
    return discBox(params.radius, toWorld);
  }

  /// A circle; it reads the squares placed over it (a place reader).
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<DiscParams>(self)!;
    sw.check('generate', p.poisoned);
    view.placedIn(discBox(p.radius, view.toWorld(self)));
    return [
      Generated(EntityKind.circle, circlePayload(Vector2.zero(), p.radius)),
    ];
  }

  @override
  bool get readsPlaces => true;

  @override
  Aabb2 readBox(DiscParams params, Transform2 toWorld, Aabb2 stored) {
    sw.check('readBox', params.poisoned);
    return discBox(params.radius, toWorld);
  }
}

/// A tool that does nothing; only its factory is switched.
final class StampTool extends Tool {
  @override
  String get name => 'stamp';
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

/// The `box` kit: the square, the stamp tool. [types] false leaves the
/// square out (a loaded kit that lacks a type the plan has).
PlanKit boxKit(Switches sw, {bool types = true}) => PlanKit(
      id: 'box',
      version: '1.4.0',
      types: [
        if (types)
          PlanType<SquareParams>(
              id: SquareParams.id,
              fromJson: (json) {
                final p = SquareParams.fromJson(json);
                sw.check('fromJson', p.poisoned);
                return p;
              },
              parametric: SquareType(sw)),
      ],
      tools: [
        PlanTool(
            id: 'box.stamp',
            icon: Icons.crop_square,
            create: (services) {
              sw.check('create');
              return StampTool();
            }),
      ],
      names: KitNames({
        'en': {
          if (types) 'type:box.square': 'Square',
          'tool:box.stamp': 'Stamp',
        },
      }),
    );

/// The `ring` kit: the disc.
PlanKit ringKit(Switches sw) => PlanKit(
      id: 'ring',
      version: '2.0.1',
      types: [
        PlanType<DiscParams>(
            id: DiscParams.id,
            fromJson: DiscParams.fromJson,
            parametric: DiscType(sw)),
      ],
      names: const KitNames({
        'en': {'type:ring.disc': 'Disc'},
      }),
    );

/// The square's placement: off the origin, turned by 30 degrees.
final Transform2 atSquare = Transform2.translation(7010, 3020)
    .multiply(Transform2.rotation(math.pi / 6));

/// A placement relative to [atSquare].
Transform2 nearSquare(double x, double y, double turn) => atSquare
    .multiply(Transform2.translation(x, y))
    .multiply(Transform2.rotation(turn));

/// Adds a root-level group carrying [params] at [at]; its handle.
Handle addObject<T extends Component>(DraftDocument d, Transform2 at, T params) {
  final h = d.handleSeed.next();
  d.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h, parent: d.rootHandle, transform: at, children: const [])),
    SetComponentCommand<T>(h, params),
  ], label: 'Add object'));
  return h;
}

/// A placed symbol of the `box` kit: a definition keyed `box.lamp.round`
/// holding one circle, and one instance of it at [at].
({Handle definition, Handle instance, Handle circle}) addLamp(
    DraftDocument d, Transform2 at) {
  final def = d.handleSeed.next();
  final circle = d.handleSeed.next();
  final instance = d.handleSeed.next();
  d.commands.execute(CompoundCommand([
    AddDefinitionCommand(Definition(
        handle: def,
        name: 'box.lamp.round@1',
        basePoint: Vector2.zero(),
        children: const [])),
    SetComponentCommand<SymbolComponent>(
        def,
        SymbolComponent(
            key: 'box.lamp.round',
            version: 1,
            name: 'Round lamp',
            category: 'Lighting',
            tags: const ['lamp'])),
    AddEntityCommand(
        record: draftRecord(circle, def, EntityKind.circle,
            layer: ReservedHandles.layerZero),
        payload: circlePayload(Vector2(12.5, -7.25), 150)),
    AddNodeCommand(InstanceNode(
        handle: instance,
        parent: d.rootHandle,
        transform: at,
        definition: def,
        layer: ReservedHandles.layerZero)),
  ], label: 'Place lamp'));
  return (definition: def, instance: instance, circle: circle);
}

/// Adds a root-level line; its handle.
Handle addLine(DraftDocument d, Vector2 a, Vector2 b) {
  final command = addDrafted(d, EntityKind.line, linePayload(a, b),
      layer: ReservedHandles.layerZero);
  d.commands.execute(command);
  return command.record.handle;
}

/// [owner]'s entities, ascending.
List<Handle> kids(DraftDocument d, Handle owner) => [
      for (final slot in d.entities.liveSlots)
        if (d.entities.ownerAt(slot) == owner) d.entities.handleAt(slot),
    ]..sort((a, b) => a.value.compareTo(b.value));

/// [owner]'s entities' coordinates, in handle order.
List<List<double>> coordsOf(DraftDocument d, Handle owner) => [
      for (final k in kids(d, owner))
        d.geometry
            .read(d.entities.geomIndexAt(d.entities.slotOf(k)!))
            .coords
            .toList(),
    ];

/// [d]'s encoding with the entities sorted by handle: slot order is
/// history, not state (as `jet_cad_2d/test/parametric/support/fixture.dart`
/// compares documents).
String canon(DraftDocument d) {
  final j = DraftDocumentCodec.encode(d);
  j['entities'] = List<Map<String, Object?>>.from(j['entities']! as List)
    ..sort((a, b) => ((a['record']! as Map)['handle']! as int)
        .compareTo((b['record']! as Map)['handle']! as int));
  return jsonEncode(j);
}

/// The engine JSON of [typeId]'s components in the plan text [json], as
/// text: the bytes a save writes for that type.
String componentsText(String json, String typeId) =>
    jsonEncode(((jsonDecode(json) as Map)['components']! as Map)[typeId]);
```

- [ ] **Step 2: Write the failing tests.** Create `test/kits/locks_test.dart`:

```dart
// Spec P4 "Locks: a missing kit, a broken object" (A9): which objects are
// locked, what they keep (they draw as saved, their components round-trip
// byte for byte, Review Focus 1) and what they lose: grips, gates, delete,
// and every change on commit, the lock check stacked on the expander after
// the parametric system (apply, check `touched` and the containers,
// roll back, throw PlanLocked). A mid-session lock clears the history.
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/kits/locks.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/box_kit.dart';

/// A plan saved with the box kit: a square [square] (side 1200) and a
/// placed lamp, and a plain line; the text and the handles.
({String json, Handle square, ({Handle definition, Handle instance, Handle circle}) lamp, Handle line})
    boxPlan() {
  final a = PlanController(kits: [boxKit(Switches())]);
  final square =
      addObject(a.document, atSquare, const SquareParams(side: 1200));
  final lamp = addLamp(a.document, nearSquare(2400, 300, 0.4));
  final line = addLine(a.document, Vector2(-3100.5, 4200.25),
      Vector2(-1700.75, 5100.5));
  final json = a.save();
  a.dispose();
  return (json: json, square: square, lamp: lamp, line: line);
}

/// A grip provider that gives every group one grip and moves it anywhere.
final class _AllGrips implements ObjectGripProvider {
  int calls = 0;
  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    calls++;
    return const [Grip(GripRole.stretch, 0, 7010, 3020)];
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    calls++;
    return TransformNodeCommand(group, Transform2.translation(world.x, world.y));
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    calls++;
    return [(EntityKind.line, linePayload(Vector2.zero(), world))];
  }

  @override
  bool movable(DraftDocument d, Handle group) {
    calls++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'L-1 (Review Focus 1) a plan naming a kit the host did not load opens; '
      'the kit\'s objects keep their drawing and are locked; saving keeps '
      'the manifest entry and the components byte for byte', () {
    final plan = boxPlan();
    final sw = Switches();
    final source = PlanController(kits: [boxKit(sw)], json: plan.json);
    final drawn = coordsOf(source.document, plan.square);
    source.dispose();
    expect(drawn, hasLength(4), reason: 'premise: the square generated');

    final b = PlanController(kits: const [], json: plan.json);
    addTearDown(b.dispose);
    expect(b.missingKits, contains('box'));
    // M-L1a: `LockSet.scan` skipping unknown components leaves the square
    // out; M-L1b: skipping the symbol definitions leaves the lamp out.
    expect(b.locked.value, {plan.square, plan.lamp.instance});
    expect(coordsOf(b.document, plan.square), drawn,
        reason: 'it draws as saved');

    final saved = b.save();
    expect(componentsText(saved, SquareParams.id),
        componentsText(plan.json, SquareParams.id));
    expect(componentsText(saved, SymbolComponent.componentTypeId),
        componentsText(plan.json, SymbolComponent.componentTypeId));
    final again = PlanController(kits: [boxKit(sw)], json: saved);
    addTearDown(again.dispose);
    final root = again.document.rootHandle;
    expect(again.document.components.get<ManifestComponent>(root)!.kits['box'],
        '1.4.0',
        reason: 'the missing kit\'s entry kept as read');
    expect(again.locked.value, isEmpty,
        reason: 'with its kit loaded, nothing is locked');

    b.newPlan();
    // M-L1c: `_open` keeping the previous lock set's objects.
    expect(b.locked.value, isEmpty, reason: 'a new document, a new lock set');
  });

  test(
      'L-2 a forged command on a locked object is refused: PlanLocked, the '
      'document and the history unchanged', () {
    final plan = boxPlan();
    final b = PlanController(kits: const [], json: plan.json);
    addTearDown(b.dispose);
    final d = b.document;
    // An allowed edit first, so the history has something to keep.
    d.commands.execute(SetEntityGeometryCommand(plan.line,
        linePayload(Vector2(-3000.25, 4100.5), Vector2(-1600.5, 5000.75))));
    final depth = d.commands.undoDepth;
    final state = d.commands.stateId;
    final before = canon(d);
    for (final forged in <DraftCommand>[
      TransformNodeCommand(plan.square, nearSquare(310.5, -120.25, 0.2)),
      TransformNodeCommand(plan.lamp.instance, atSquare),
    ]) {
      // M-L2a: `_LockCheck.apply` returning `result` before its check loop
      // throws nothing.
      expect(() => d.commands.execute(forged), throwsA(isA<PlanLocked>()),
          reason: forged.label);
      // M-L2b: the check without `result.inverse.apply(target)` leaves the
      // document changed.
      expect(canon(d), before, reason: forged.label);
      expect(d.commands.undoDepth, depth, reason: forged.label);
      expect(d.commands.stateId, state, reason: forged.label);
      expect(d.commands.canRedo, isFalse, reason: forged.label);
    }
  });

  test(
      'L-3 a child edit is refused through its containers: an entity of the '
      'locked group, a new entity added into it, one removed from it, an '
      'entity of the locked symbol\'s definition; a plain edit passes', () {
    final plan = boxPlan();
    final b = PlanController(kits: const [], json: plan.json);
    addTearDown(b.dispose);
    final d = b.document;
    final child = kids(d, plan.square).first;
    final added = d.handleSeed.next();
    final before = canon(d);
    // M-L3a: `covers` testing the handle alone (no closure, no walk).
    expect(
        () => d.commands.execute(SetEntityGeometryCommand(
            child, linePayload(Vector2(1, 2), Vector2(3, 4)))),
        throwsA(isA<PlanLocked>()));
    expect(
        () => d.commands.execute(AddEntityCommand(
            record: draftRecord(added, plan.square,
                EntityKind.line,
                layer: ReservedHandles.layerZero),
            payload: linePayload(Vector2(5, 6), Vector2(7, 8)))),
        throwsA(isA<PlanLocked>()),
        reason: 'added into a locked group: the walk finds its owner');
    // M-L3b: `_refresh` leaving the closure empty: after the removal the
    // entity has no owner to walk to.
    expect(() => d.commands.execute(RemoveEntityCommand(child)),
        throwsA(isA<PlanLocked>()));
    expect(
        () => d.commands.execute(SetEntityGeometryCommand(
            plan.lamp.circle, circlePayload(Vector2(1, 1), 99))),
        throwsA(isA<PlanLocked>()),
        reason: 'inside the locked symbol\'s definition');
    expect(canon(d), before);

    d.commands.execute(SetEntityGeometryCommand(plan.line,
        linePayload(Vector2(-2000.5, 3000.25), Vector2(-900.75, 3900.5))));
    expect(d.commands.undoDepth, 1, reason: 'a plain line edits');
  });

  test(
      'L-4 an object of a type its loaded kit does not have is locked too; '
      'the kit is not missing', () {
    final plan = boxPlan();
    final b = PlanController(
        kits: [boxKit(Switches(), types: false)], json: plan.json);
    addTearDown(b.dispose);
    expect(b.missingKits, isNot(contains('box')));
    // M-L4: the scan skipping a component whose kit is loaded.
    expect(b.locked.value, {plan.square});
    expect(
        () => b.document.commands.execute(
            TransformNodeCommand(plan.square, atSquare)),
        throwsA(isA<PlanLocked>()));
  });

  test(
      'L-5 the grip decorator gives a covered group nothing: no grips, no '
      'drag, no preview, not movable; an unlocked group is the inner\'s', () {
    final plan = boxPlan();
    final b = PlanController(kits: const [], json: plan.json);
    addTearDown(b.dispose);
    final d = b.document;
    final locks = LockSet.scan(d, (_) => false);
    final inner = _AllGrips();
    final grips = LockedGrips(locks, inner);
    final world = Vector2(7100.5, 3100.25);
    const grip = Grip(GripRole.stretch, 0, 7010, 3020);
    // M-L5a/b/c/d: each member's `if (_locks.covers(d, group))` dropped.
    expect(grips.gripsOf(d, plan.square), isEmpty);
    expect(grips.drag(d, plan.square, grip, world), isNull);
    expect(grips.preview(d, plan.square, grip, world), isEmpty);
    expect(grips.movable(d, plan.square), isFalse);
    expect(inner.calls, 0, reason: 'the inner is never asked for a lock');
    final free = addObject(d, nearSquare(-5200, 800, 0.1),
        const SquareParams(side: 300));
    expect(grips.gripsOf(d, free), hasLength(1));
    expect(grips.movable(d, free), isTrue);
    expect(LockedGrips(locks, null).movable(d, free), isTrue,
        reason: 'no inner: an unlocked group moves, as with no provider');
    expect(LockedGrips(locks, null).gripsOf(d, free), isEmpty);
  });

  test(
      'L-6 through the controller: a locked selection shuts every gate, has '
      'no grips and cannot be deleted; a plain selection is open', () {
    final plan = boxPlan();
    final b = PlanController(kits: const [], json: plan.json);
    addTearDown(b.dispose);
    final d = b.document;
    Map<String, bool> open() {
      final g = b.grips.gates!;
      return {
        'move': g.move,
        'rotate': g.rotate,
        'reshape': g.reshape,
        'delete': g.delete,
      };
    }

    b.selection.replace([SelectionKey.root(plan.square)]);
    // M-L6a-d: `LockGates.move` (rotate, reshape, delete) without
    // `&& !_selectionLocked`.
    expect(open().values, everyElement(isFalse));
    // M-L6e: the session handing Task 8's dispatch to the GripCache
    // instead of `LockedGrips(locks, dispatch)`.
    expect(b.grips.objects!.movable(d, plan.square), isFalse);
    expect(b.grips.objects!.gripsOf(d, plan.square), isEmpty);
    // M-L6f: the `plan.select` tool built without `gates:` deletes the
    // locked square (`deleteSelection` is the select tool's, gated by
    // `delete`, select_tool.dart:744-753).
    expect(b.deleteSelection(), isFalse);
    expect(d.tree[plan.square], isNotNull);

    b.selection.replace([SelectionKey.root(plan.line)]);
    expect(open().values, everyElement(isTrue));
    expect(b.deleteSelection(), isTrue);
    expect(d.entities.slotOf(plan.line), isNull, reason: 'the line deleted');
  });

  test(
      'L-7 isLocked: a locked object, its children, a locked symbol\'s '
      'instance, definition and contents; not a plain line, not the root', () {
    final plan = boxPlan();
    final b = PlanController(kits: const [], json: plan.json);
    addTearDown(b.dispose);
    final d = b.document;
    // M-L7: `isLocked` as `locked.value.contains(handle)` misses children
    // and the definition.
    for (final h in [
      plan.square,
      ...kids(d, plan.square),
      plan.lamp.instance,
      plan.lamp.definition,
      plan.lamp.circle,
    ]) {
      expect(b.isLocked(h), isTrue, reason: h.toHex());
    }
    expect(b.isLocked(plan.line), isFalse);
    expect(b.isLocked(d.rootHandle), isFalse);
  });

  test(
      'L-8 an object locked mid-session: the history is cleared, so undo '
      'cannot reach it; its edits and its children\'s are refused', () {
    final b = PlanController(kits: [boxKit(Switches())]);
    addTearDown(b.dispose);
    final d = b.document;
    final square = addObject(d, atSquare, const SquareParams(side: 900));
    d.commands.execute(SetComponentCommand<SquareParams>(
        square, const SquareParams(side: 1350.5)));
    expect(b.canUndo.value, isTrue, reason: 'premise');
    final before = canon(d);

    b.lockBroken({square});
    // M-L8: `lockBroken` without `commands.clearHistory()`.
    expect(d.commands.canUndo, isFalse);
    expect(b.canUndo.value, isFalse, reason: 'the listenable follows');
    b.undo();
    expect(canon(d), before);
    expect(b.locked.value, {square});
    expect(
        () => d.commands.execute(SetComponentCommand<SquareParams>(
            square, const SquareParams(side: 2000))),
        throwsA(isA<PlanLocked>()));
    expect(
        () => d.commands.execute(SetEntityGeometryCommand(
            kids(d, square).first, linePayload(Vector2(0, 0), Vector2(9, 9)))),
        throwsA(isA<PlanLocked>()),
        reason: 'a frozen object\'s children are covered (E2: a plain group)');
    expect(canon(d), before);
  });

  test(
      'L-9 the lock expander stacks on the parametric one: with a lock set, '
      'a parametric edit still regenerates; dispose puts the slot back', () {
    final d = DraftDocument.empty();
    final catalog = ParametricCatalog()
      ..register<SquareParams>(
          SquareParams.id, SquareParams.fromJson, SquareType(Switches()));
    final system = ParametricSystem(d, catalog)..install();
    final parametricSlot = d.commands.expander;
    final locks = LockSet.scan(d, (_) => true);
    final fence = d.handleSeed.next();
    d.commands.execute(AddNodeCommand(GroupNode(
        handle: fence,
        parent: d.rootHandle,
        transform: nearSquare(-9000, 0, 0),
        children: const [])));
    locks.addBroken(d, {fence});
    final expander = LockExpander(d, locks)..install();
    // M-L9: `_expand` using `command` in place of `_previous?.call(command)`
    // adds the square with no children.
    final square = addObject(d, atSquare, const SquareParams(side: 640));
    expect(kids(d, square), hasLength(4));
    expander.dispose();
    expect(d.commands.expander, parametricSlot);
    system.dispose();
    expect(d.commands.expander, isNull);
  });

  test('L-10 LockGates: a key whose target or chain is locked shuts the gates',
      () {
    final d = DraftDocument.empty();
    final selection = SelectionController(d);
    final locked = ValueNotifier<Set<Handle>>(const {});
    final gates = LockGates(selection: selection, locked: locked);
    addTearDown(() {
      gates.dispose();
      selection.dispose();
      locked.dispose();
    });
    final a = addLine(d, Vector2(10.5, 20.25), Vector2(400.75, 90.5));
    selection.replace([SelectionKey.root(a)]);
    expect(gates.selectionLocked, isFalse);
    // M-L10: `locked.addListener(_recompute)` dropped: the lock arriving
    // after the selection is missed.
    locked.value = {a};
    expect(gates.selectionLocked, isTrue);
    expect([gates.move, gates.rotate, gates.reshape, gates.delete],
        everyElement(isFalse));
    expect(gates.bandAccepts(d, SelectionKey.root(a)), isTrue,
        reason: 'a locked object is still selectable as a whole');
    locked.value = const {};
    expect(gates.move, isTrue);
  });
}

```

- [ ] **Step 3: Run them to see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/kits/locks_test.dart`. Expected: compilation errors (`Error when reading 'lib/src/kits/locks.dart'`, `Undefined name 'PlanLocked'`, `The getter 'locked' isn't defined for the type 'PlanController'`).

- [ ] **Step 4: The lock.** Create `lib/src/kits/locks.dart`:

```dart
// Spec P4 "Locks: a missing kit, a broken object" (umbrella A9). A locked
// object draws as saved and can be selected as a whole; it loses every
// change. Two layers: up front (no grips, the gates shut, no delete, no
// panel section) and on commit, where the lock is an expander stacked after
// the parametric system's (as jet_cad_floor_plan's TableLabelSystem
// stacks): it applies the command, checks every touched handle and its
// containers, and on a hit applies the inverse and throws [PlanLocked].
// A command names no handles before it applies (command.dart:122-137), so
// a check before apply cannot work.
import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The refusal of a command that would change a locked object. A refusal,
/// not a kit diagnostic: the canvas shows a short hint.
final class PlanLocked implements Exception {
  const PlanLocked();

  @override
  String toString() => 'PlanLocked: the edit would change a locked object';
}

/// The locked objects of one document, and what they contain.
final class LockSet {
  LockSet._(this._missing, this._definitions, CommandTarget target) {
    _refresh(target);
  }

  /// Scans [document] once (spec P4 "Which objects are locked"):
  /// - a node other than the root that carries an unknown component whose
  ///   type id is kit-namespaced (a kit id, then a dot; not `jetcad`, not
  ///   `plan`), whatever [loaded] says: no loaded code knows the type;
  /// - a definition whose [SymbolComponent] key's kit is not [loaded], or
  ///   that carries such an unknown component, and every instance of it.
  factory LockSet.scan(
      DraftDocument document, bool Function(String kitId) loaded) {
    bool unknown(Handle h) {
      final kit = _unknownKit(document, h);
      return kit != null && _locksUnknown(kit, loaded);
    }

    final definitions = <Handle>{};
    for (final def in document.tree.definitions) {
      final symbol = document.components.get<SymbolComponent>(def.handle);
      if (unknown(def.handle) ||
          (symbol != null && !loaded(kitOfKey(symbol.key)))) {
        definitions.add(def.handle);
      }
    }
    final missing = <Handle>{};
    for (final node in document.tree.nodes) {
      if (node.handle == document.rootHandle) continue;
      if (unknown(node.handle) ||
          (node is InstanceNode && definitions.contains(node.definition))) {
        missing.add(node.handle);
      }
    }
    return LockSet._(missing, definitions, document);
  }

  /// The kit id of an unknown, kit-namespaced component on [h] (a kit id,
  /// then a dot; not `jetcad`, not `plan`), or null.
  static String? _unknownKit(DraftDocument d, Handle h) {
    for (final payload in d.components.unknownOf(h)) {
      final typeId = payload['typeId'];
      if (typeId is! String) continue;
      final dot = typeId.indexOf('.');
      if (dot <= 0) continue;
      final kit = typeId.substring(0, dot);
      if (isKitId(kit) && kit != 'jetcad' && kit != 'plan') return kit;
    }
    return null;
  }

  /// Whether an unknown component of [kit] locks its holder: always (plan
  /// decision), whether or not [kit] is loaded, since no loaded code knows
  /// the type.
  static bool _locksUnknown(String kit, bool Function(String) loaded) => true;

  /// Past this many containers a chain is taken as no lock's (the tree
  /// refuses cycles; this only bounds a malformed one).
  static const int _maxDepth = 4096;

  final Set<Handle> _missing;
  final Set<Handle> _definitions;
  final Set<Handle> _broken = {};

  /// [_missing], [_broken] and [_definitions]: the containers a lock
  /// starts from.
  final Set<Handle> _roots = {};

  /// Every node and entity under a root when the set last changed.
  final Set<Handle> _closure = {};

  /// The locked objects: a missing kit's, an unknown type's, a broken one's.
  /// The guarded definitions are not listed.
  Set<Handle> get objects => Set.unmodifiable({..._missing, ..._broken});

  bool get isEmpty => _roots.isEmpty;

  /// Whether [h] itself is a locked object.
  bool isLockedObject(Handle h) => _missing.contains(h) || _broken.contains(h);

  /// Whether [h] is locked: a locked object or guarded definition, inside
  /// one now (its containers, walked in [target]), or inside one when the
  /// set last changed (a handle a command just removed has no container
  /// left to walk).
  bool covers(CommandTarget target, Handle h) =>
      _closure.contains(h) || _walk(target, h);

  /// Adds [objects], broken (Task 11), and refreshes what they contain.
  void addBroken(CommandTarget target, Iterable<Handle> objects) {
    _broken.addAll(objects);
    _refresh(target);
  }

  void _refresh(CommandTarget t) {
    _roots
      ..clear()
      ..addAll(_missing)
      ..addAll(_broken)
      ..addAll(_definitions);
    _closure.clear();
    if (_roots.isEmpty) return;
    for (final node in t.tree.nodes) {
      if (_walk(t, node.handle)) _closure.add(node.handle);
    }
    for (final slot in t.entities.liveSlots) {
      final h = t.entities.handleAt(slot);
      if (_walk(t, h)) _closure.add(h);
    }
  }

  /// [start] or one of its containers (an entity's owner, a node's parent,
  /// up to the root or a definition) is a root.
  bool _walk(CommandTarget t, Handle start) {
    if (_roots.isEmpty) return false;
    var current = start;
    for (var depth = 0; depth < _maxDepth; depth++) {
      if (_roots.contains(current)) return true;
      final slot = t.entities.slotOf(current);
      final Handle up;
      if (slot != null) {
        up = t.entities.ownerAt(slot);
      } else {
        final node = t.tree[current];
        if (node == null) return false;
        up = node.parent;
      }
      if (up.isNone || up == current) return false;
      current = up;
    }
    return false;
  }
}

/// Stacks on the dispatcher's one expander slot (spec 06 D2), after the
/// parametric system: [install] keeps the expander it found and wraps what
/// that one returns; [dispose] puts it back. **Last in, first out**: the
/// controller installs this after `ParametricSystem.install` and disposes
/// it before `ParametricSystem.dispose`; [dispose] asserts that the slot
/// still holds its own.
final class LockExpander {
  LockExpander(this.document, this.locks);

  final DraftDocument document;
  final LockSet locks;
  DraftCommand Function(DraftCommand command)? _previous;
  bool _installed = false;

  void install() {
    if (_installed) throw StateError('the lock expander is installed already');
    _previous = document.commands.expander;
    document.commands.expander = _expand;
    _installed = true;
  }

  /// Puts the expander [install] found back, only if the slot still holds
  /// this one's own tear-off.
  void dispose() {
    if (!_installed) return;
    _installed = false;
    final mine = document.commands.expander == _expand;
    if (mine) document.commands.expander = _previous;
    _previous = null;
    assert(mine, 'LockExpander disposed out of order (spec P4)');
  }

  /// The previous expander's command for [command], or [command].
  DraftCommand expandInner(DraftCommand command) =>
      _previous?.call(command) ?? command;

  DraftCommand _expand(DraftCommand command) {
    final inner = expandInner(command);
    if (locks.isEmpty) return inner;
    return _LockCheck(this, command, inner);
  }
}

/// One edit and its lock check: [_applied] applies, then each touched
/// handle is tested; a hit undoes the edit and throws [PlanLocked]. Created
/// by [LockExpander], once per `execute`.
final class _LockCheck extends DraftCommand {
  _LockCheck(this._expander, this.original, this._applied);

  final LockExpander _expander;

  /// The command the caller executed, before any expansion.
  final DraftCommand original;

  /// The expanded command this check applies.
  DraftCommand _applied;

  @override
  String get label => _applied.label;

  @override
  Set<Capability> get capabilities => _applied.capabilities;

  /// Read by the dispatcher after [apply]: the applied command's own.
  @override
  Capability get capability => _applied.capability;

  @override
  CommandResult apply(CommandTarget target) =>
      _check(target, _applied.apply(target));

  CommandResult _check(CommandTarget target, CommandResult result) {
    final locks = _expander.locks;
    for (final h in result.touched) {
      if (!locks.covers(target, h)) continue;
      try {
        result.inverse.apply(target);
      } catch (rollbackError) {
        throw PartialMutationError('"$label": it touched a locked object, '
            'and undoing it then threw ($rollbackError); the target is '
            'partially mutated and nothing was recorded in history');
      }
      throw const PlanLocked();
    }
    return result;
  }
}

/// The grip provider a lock leaves: a covered group has no grips, no drag,
/// no preview and does not move; anything else is [inner]'s (no grips and
/// movable with no inner, as with no provider, `grip_cache.dart:61-66`).
final class LockedGrips implements ObjectGripProvider {
  LockedGrips(this._locks, this._inner);

  final LockSet _locks;
  final ObjectGripProvider? _inner;

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    if (_locks.covers(d, group)) return const [];
    return _inner?.gripsOf(d, group) ?? const [];
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    if (_locks.covers(d, group)) return null;
    return _inner?.drag(d, group, grip, world);
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    if (_locks.covers(d, group)) return const [];
    return _inner?.preview(d, group, grip, world) ?? const [];
  }

  @override
  bool movable(DraftDocument d, Handle group) {
    if (_locks.covers(d, group)) return false;
    return _inner?.movable(d, group) ?? true;
  }
}

/// The select gates a lock shuts (spec P4 "Up front"): move, rotate,
/// reshape and delete refuse while a selected key's target, or a handle of
/// its chain, is in [locked]; a locked object stays selectable. The answer
/// is a cached `bool`, recomputed when the selection or the locked set
/// notifies, so the getters allocate nothing (`select_gates.dart:14-21`).
/// Task 12's `PlanSelectGates` extends it with the permissions (one lock
/// rule, not two).
base class LockGates extends SelectGates {
  LockGates({
    required SelectionController selection,
    required ValueListenable<Set<Handle>> locked,
  })  : _selection = selection,
        _locked = locked {
    _selection.addListener(_recompute);
    _locked.addListener(_recompute);
    _recompute();
  }

  final SelectionController _selection;
  final ValueListenable<Set<Handle>> _locked;
  bool _selectionLocked = false;

  /// Whether a selected key's target, or a handle of its chain, is locked.
  bool get selectionLocked => _selectionLocked;

  void _recompute() {
    final locked = _locked.value;
    var hit = false;
    if (locked.isNotEmpty) {
      for (final key in _selection.keys) {
        if (locked.contains(key.target)) {
          hit = true;
          break;
        }
        final chain = key.chain;
        for (var i = 0; i < chain.length && !hit; i++) {
          hit = locked.contains(Handle(chain[i]));
        }
        if (hit) break;
      }
    }
    _selectionLocked = hit;
  }

  @override
  bool get move => !_selectionLocked;

  @override
  bool get rotate => !_selectionLocked;

  @override
  bool get reshape => !_selectionLocked;

  @override
  bool get delete => !_selectionLocked;

  void dispose() {
    _selection.removeListener(_recompute);
    _locked.removeListener(_recompute);
  }
}
```

  In `lib/jet_cad_2d_plan.dart` add `export 'src/kits/locks.dart' show PlanLocked;` (sorted with the other exports).

- [ ] **Step 5: Wire it into the session and the controller.** The lock set, the expander and the gates are per-document: they live in Task 8's `DocumentSession` (`lib/src/controller/session.dart`), are built in its constructor and disposed by it (Shared interfaces). Only the `locked` notifier is the controller's.
  1. In `lib/src/controller/session.dart`, import `package:flutter/foundation.dart' show ValueListenable` and `'../kits/locks.dart'`. The constructor gains two named parameters, and its body becomes, in this order (the lock set is scanned first because it only reads the document and the grip cache needs it; the system still installs last and the expander stacks after it, spec P2 "It owns"):

```dart
  DocumentSession(
      {required this.document,
      required this.measurer,
      required ParametricCatalog catalog,
      required CameraController camera,
      required SnapSettings snap,
      required bool Function(String kitId) kitLoaded,
      required ValueListenable<Set<Handle>> locked})
      : page = PageNotifier(document),
        index = SpatialIndex(document),
        dispatch = GripDispatch(catalog) {
    locks = LockSet.scan(document, kitLoaded);
    // planner_shell.dart:625-671, the order load-bearing: the selection
    // prunes a dead key before the outline cache walks it; the gates
    // listen to the selection before the outline and grip caches do; the
    // grip cache rebuilds after the outlines.
    selection = SelectionController(document);
    lockGates = LockGates(selection: selection, locked: locked);
    outlines = OutlineCache(document, selection);
    grips = GripCache(document, selection, outlines,
        objects: LockedGrips(locks, dispatch), gates: lockGates);
    toolContext = ToolContext(
        document: document,
        index: index,
        camera: camera,
        selection: selection,
        page: page,
        snap: snap,
        grips: grips);
    select = SelectTool(gates: lockGates);
    tools = ToolController(initial: select, context: toolContext);
    _entries.add((id: planSelectToolId, tool: select, kit: false));
    // :1050-1057: the document arrives built; the system installs last,
    // and the lock expander stacks after it.
    parametric = ParametricSystem(document, catalog, isFrozen: frozen.contains)
      ..install();
    lockExpander = LockExpander(document, locks)..install();
  }
```

     The field `final SelectTool select = SelectTool();` becomes `late final SelectTool select;`, and the session gains:

```dart
  /// The document's lock set, expander and select gates (spec P4).
  late final LockSet locks;
  late final LockExpander lockExpander;
  late final LockGates lockGates;
```

     In `dispose()`, right after `page.dispose();` and before `parametric.dispose();`: `lockGates.dispose(); lockExpander.dispose();` (the session is the only owner: nothing in the controller disposes them).
  2. In `lib/src/controller/plan_controller.dart` (Task 8), import `../kits/locks.dart`, and add the controller-lifetime members:

```dart
  /// The locked objects of the current document (spec P4).
  final ValueNotifier<Set<Handle>> _locked = ValueNotifier(const {});

  /// The locked objects: a missing kit's, an unknown type's, a broken
  /// one's. Never the root.
  ValueListenable<Set<Handle>> get locked => _locked;

  /// Whether [handle] is locked: a locked object, inside one, or inside a
  /// locked symbol's definition. The property panel shows no section for
  /// it; the pickers refuse it.
  bool isLocked(Handle handle) => _session.locks.covers(document, handle);

  /// Locks [objects] in the middle of a session (spec P4: a type's code
  /// failed, Task 11): adds them to the lock set, clears the undo history
  /// so no earlier edit can be undone onto them, and tells the listeners.
  @internal
  void lockBroken(Set<Handle> objects) {
    if (objects.isEmpty) return;
    _session.locks.addBroken(document, objects);
    document.commands.clearHistory();
    _locked.value = _session.locks.objects;
    // clearHistory emits no change: refresh the undo listenables here.
    _refreshFlags();
    grips.gatesChanged();
    notifyListeners();
  }
```

  (`_refreshFlags()` is Task 8's: it sets `dirty`, `canUndo` and `canRedo` from `document.commands`.)
  3. In Task 8's `_open`, the `DocumentSession(...)` call gains `kitLoaded: (kitId) => kits.kitOf(kitId) != null, locked: _locked` (`kits` is Task 8's `final KitSet kits`), and right after `_session = session;` add `_locked.value = session.locks.objects;`. In the controller's `dispose`, after the last session is disposed: `_locked.dispose();`.

- [ ] **Step 6: Run the tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/kits/locks_test.dart`. Expected: `All tests passed!`. Then the whole package: `flutter test`. Expected: `All tests passed!` (Task 8's controller tests unchanged: with nothing locked the expander returns the parametric command unwrapped).

- [ ] **Step 7: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0. If `flutter analyze` reports an import of this task's new files as unnecessary or unused (Flutter's libraries re-export parts of one another), delete that import line; change nothing else to quiet it. From the root, `git status --short`: only this task's files.

- [ ] **Step 8: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/kits/locks.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/src/controller/session.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/test/support/box_kit.dart packages/jet_cad_2d_plan/test/kits/locks_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): locks for a missing kit's objects and broken ones (2a P4)

A plan that names a kit the host did not load opens with that kit's
objects drawn as saved and locked: no grips, shut select gates, no
delete, and every command touching them or their contents is applied,
checked and rolled back with PlanLocked, by an expander stacked after
the parametric one. Saving keeps their components byte for byte. A
mid-session lock clears the undo history.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 9: Mutation check** (committed files only; after each: run `cd packages/jet_cad_2d_plan && flutter test test/kits/locks_test.dart`, see the named test red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0):
  - M-L1a `lib/src/kits/locks.dart`: in `LockSet.scan`, `unknown`'s body → `return false;` → L-1 red (the square missing from `locked`).
  - M-L1b `locks.dart`: in the definition loop, `(symbol != null && !loaded(kitOfKey(symbol.key)))` → `false` → L-1 red (the lamp missing).
  - M-L1c `plan_controller.dart`: in `_open`, guard `_locked.value = session.locks.objects;` with `if (!_locksMade) { ...; _locksMade = true; }` (a new `bool _locksMade = false;` field) → L-1 red at `b.newPlan()`.
  - M-L2a `locks.dart`: `_check`'s first line → `return result;` → L-2 red (no `PlanLocked`).
  - M-L2b `locks.dart`: delete `result.inverse.apply(target);` (and its `try`/`catch`, keeping `throw const PlanLocked();`) → L-2 red (the encoding differs).
  - M-L3a `locks.dart`: `covers` → `_roots.contains(h)` → L-3 red (the child edit passes).
  - M-L3b `locks.dart`: in `_refresh`, delete both `for` loops → L-3 red at `RemoveEntityCommand` only.
  - M-L4 `locks.dart`: `_locksUnknown`'s body → `!loaded(kit)` (lock only a missing kit's) → L-4 red, L-1 still green.
  - M-L5a-d `locks.dart`: in `LockedGrips`, delete the `if (_locks.covers(d, group)) ...;` line of `gripsOf` (a), `drag` (b), `preview` (c), `movable` (d), one at a time → L-5 red each.
  - M-L6a-d `locks.dart`: `LockGates.move` (a), `rotate` (b), `reshape` (c), `delete` (d) → `true`, one at a time → L-6 and L-10 red each.
  - M-L6e `session.dart`: `objects: LockedGrips(locks, dispatch)` → `objects: dispatch` → L-6 red (`movable` true).
  - M-L6f `session.dart`: `select = SelectTool(gates: lockGates);` → `select = SelectTool();` (the `GripCache`'s gates kept) → L-6 red (the square deleted).
  - M-L7 `plan_controller.dart`: `isLocked` → `_session.locks.isLockedObject(handle)` → L-7 red.
  - M-L8 `plan_controller.dart`: delete `document.commands.clearHistory();` in `lockBroken` → L-8 red.
  - M-L9 `locks.dart`: `expandInner` → `command` → L-9 red (no children).
  - M-L10 `locks.dart`: delete `_locked.addListener(_recompute);` → L-10 red.

  Quote each red line.

#### Assumed from earlier tasks

Each name below is used as written; where an earlier task named it otherwise, the implementer uses that task's name and reports the difference.
- Task 8 keeps per-document state in a `DocumentSession` (`lib/src/controller/session.dart`): its constructor builds the views and installs the system (`DocumentSession(...)`, `select`, `_entries`, `dispose()`), and `_open` makes one per document; the old session is disposed one frame after a swap (`_drop`). This task's `locks`, `lockExpander`, `lockGates` are session members (Step 5).
- Task 8 (`lib/src/controller/plan_controller.dart`): `PlanController({required List<PlanKit> kits, String? json, ...})`; `DraftDocument get document`; `String save()`; `void newPlan({String? decimalSeparator})`; `void undo()`; `ValueListenable<bool> get canUndo` (and `canRedo`), refreshed by a private method or inline assignments after each document change; `bool deleteSelection()`; `Set<String> get missingKits` (the manifest's kit ids the kit set does not load; `contains` is all the tests use); `@internal` accessors `SelectionController get selection` and `GripCache get grips` (the names Tasks 12 and 15 also assume); one per-document build shared by the constructor, `load`, `newPlan` and `import` (which installs the `ParametricSystem`, makes the `SelectionController`, the `OutlineCache`, the `GripCache` with Task 8's dispatching `ObjectGripProvider`, and the `plan.select` `SelectTool`), and one per-document teardown; the validated `KitSet` as `final KitSet kits`; the controller is a `ChangeNotifier`; documents carry `registerKitComponents`' types, so `SymbolComponent` is registered.
- Task 7: a plan saved by `save()` names its used kits in `jetcad.manifest` (the square's type id and the lamp's symbol key are under `box`); loading keeps a missing kit's entry and writes it back as read; handles survive `save()` and `PlanController(json:)`.
- Task 6: `KitSet.kitOf(String id)`; `validateKitSet` accepts `boxKit`, `boxKit(types: false)` and `ringKit` (ids under their kits, English words for every `type:` and `tool:` id).
- Task 4: `PlanType<T>({required String id, required ComponentFactory<T> fromJson, required ParametricType<T> parametric, ...})` and `PlanTool({required String id, required IconData icon, required Tool Function(PlanServices) create, ...})`, as in the Shared interfaces; `PlanKit({..., List<PlanType<Component>> types, List<PlanTool> tools, KitNames names})`.
- Task 1 (E3): `PartialMutationError(String message)` exported from `package:jet_cad_2d/jet_cad_2d.dart`.
- Task 2 (E2): a frozen object is a plain group whose children a command may edit (the lock covers them, L-8).

---

