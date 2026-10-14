### Task 1: Engine seams E1, E3, E4 (spec E1, E3, E4)

**Files:**
- Create: `packages/jet_cad_2d/lib/src/core/partial_mutation_error.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart` (one export), `lib/src/parametric/parametric_system.dart` (E1; the E3 import), `lib/src/parametric/regeneration.dart` (E3, three sites), `lib/src/document/commands.dart` (E3, the fourth site), `lib/src/document/component.dart` (E4), `lib/src/codec/json_codec.dart` (E4 plumbing), `packages/jet_cad_2d/CHANGELOG.md`
- Test: `packages/jet_cad_2d/test/parametric/catalog_queries_test.dart`, `test/parametric/partial_mutation_test.dart`, `test/codec/unreadable_component_test.dart`

(All paths below are under `packages/jet_cad_2d/` unless they start at the repository root.)

**Interfaces:**
- Consumes (existing engine code, read before editing):
  - `_naming(CommandTarget, List<_Registration<Component>>, Handle)`, the engine's one object rule (`lib/src/parametric/regeneration.dart:18-26`), which `ParametricCatalog.names` already reads (`parametric_system.dart:529-530`).
  - `ParametricCatalog._types` (`parametric_system.dart:489`), `_Registration.typeId` (`:778`).
  - `ComponentRegistry.loadJson` (`lib/src/document/component.dart:295-314`), `attachUnknown` (`:231-232`), `toJson` (`:254-287`).
  - `DraftDocumentCodec.decode` / `decodeString` (`lib/src/codec/json_codec.dart:93-167`; the `loadJson` call at `:133-134`).
  - The four "partially mutated" throws: `commands.dart:1006-1008` (`CompoundCommand.apply`), `regeneration.dart:735-737` (`_undoInner`), `:793-795` (`_cascade`), `:1040-1042` (`_run`'s apply loop). `grep -rn "partially" packages/jet_cad_2d/lib` lists exactly these four throws plus two doc comments (`commands.dart:955`, `regeneration.dart:757`).
  - Test support: `test/parametric/support/clients.dart` (`ClipRect`, `SoftRect`, `Trip`, `RectType`, `TripType`, `Post`, `Pin`), `test/parametric/support/fixture.dart` (`paramDoc`, `create`, `kids`, `hA`, `atA`, `parked`).
- Produces (exported from `package:jet_cad_2d/jet_cad_2d.dart`):
  - E1: `Iterable<String> ParametricCatalog.typeIds` (registration order, each type id once); `String? ParametricCatalog.typeIdOf(CommandTarget target, Handle group)` (null: not a live parametric object).
  - E3: `final class PartialMutationError extends StateError { PartialMutationError(String message); }`, thrown at all four sites above with the message each threw before.
  - E4: `void ComponentRegistry.loadJson(Map<String, Object?> json, {List<Diagnostic>? diagnostics})`: with a list, a throwing factory keeps the payload raw (`attachUnknown`, its `typeId` included) and adds `Diagnostic(severity: DiagnosticSeverity.error, code: 'component.unreadable', handles: [h], message: '<typeId>: <error>')`; with none, the factory's error propagates as today.
  - E4 plumbing, **as controller ruling R-c decides**: `DraftDocumentCodec.decode(…, bool keepUnreadableComponents = false)` and the same parameter on `decodeString`. Only when it is true does the codec hand `loadJson` a list (`diagnostics ?? <Diagnostic>[]`). Task 7's `decodePlan` must pass `keepUnreadableComponents: true`.

Plan decision: `typeIds` lists each type id once, where it was first registered. `register` accepts the same type twice (`names` documents it, `parametric_system.dart:524-525`); a listing with a repeated id would make every consumer deduplicate.
Plan decision: `typeIdOf` is `_naming(target, _types, group)?.typeId`, the same rule `names`, `objectsOf` and the survey read. A group whose component `loadJson` kept raw (E4) carries no registered component, so it answers null.
Plan decision: E3 covers all four sites, `CompoundCommand.apply` included. A kit command that is a plain `CompoundCommand` reaches the dispatcher unwrapped when the document holds no parametric object (`parametric_system.dart:685-688`), and its failed rollback leaves the document in the same unknown state. The controller (Task 11) must see one type for all of them.
Plan decision: E4 catches every throw, an `Error` too. A factory's mistyped or missing field is a `TypeError` (`(j['width']! as num)`), the commonest way a component becomes unreadable.
Plan decision: `ComponentRegistry.toJson` writes unknown payloads first and registered values second. Before E4, a registered type id never reached `_unknown` through `loadJson`, so the two branches never collided on one handle. After E4 they can: a payload kept raw, then a value of the same type attached to that handle. Today's order (`component.dart:257-280`, registered first) lets the stale raw payload overwrite the new value on save. Among unknown payloads, the last still wins, as `restore` documents (`:213-214`).

- [ ] **Step 1: Write the E1 test.** Create `test/parametric/catalog_queries_test.dart`:

```dart
// Spec 2a E1: the catalog lists its type ids and names the type of a
// group's live object by the engine's own rule. No parametric system is
// installed: nothing regenerates, so each component lands where it is put,
// nested and on an entity included. Every group is off the origin at a
// rotation.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';

final Transform2 at = Transform2.translation(7010, 3020)
    .multiply(Transform2.rotation(math.pi / 6));

/// SoftRect, ClipRect, Trip, then ClipRect again: not sorted, and one type
/// id registered twice.
ParametricCatalog e1Catalog() => ParametricCatalog()
  ..register<SoftRect>(SoftRect.id, SoftRect.fromJson,
      const RectType<SoftRect>(Capability.components))
  ..register<ClipRect>(ClipRect.id, ClipRect.fromJson,
      const RectType<ClipRect>(Capability.geometry))
  ..register<Trip>(Trip.id, Trip.fromJson, const TripType())
  ..register<ClipRect>(ClipRect.id, ClipRect.fromJson,
      const RectType<ClipRect>(Capability.geometry));

Handle addGroup(DraftDocument doc, Handle parent, Transform2 transform) {
  final h = doc.handleSeed.next();
  doc.commands.execute(AddNodeCommand(GroupNode(
      handle: h, parent: parent, transform: transform, children: const [])));
  return h;
}

void main() {
  test('E1-typeIds the type ids, in registration order, each once', () {
    // M-E1a: sorted, clipRect comes first.
    // M-E1b: one entry per registration, clipRect is listed twice.
    expect(e1Catalog().typeIds.toList(), [SoftRect.id, ClipRect.id, Trip.id]);
    expect(ParametricCatalog().typeIds, isEmpty);
  });

  test(
      "E1-typeIdOf names a live object's type by the engine rule, and null "
      'for anything that is not one', () {
    final catalog = e1Catalog();
    final doc = DraftDocument.empty();
    catalog.registerComponents(doc.components);

    final soft = addGroup(doc, doc.rootHandle, at);
    doc.commands.execute(
        SetComponentCommand<SoftRect>(soft, const SoftRect(400, 900)));
    final trip = addGroup(doc, doc.rootHandle,
        at.multiply(Transform2.translation(-1800, 650)));
    doc.commands.execute(SetComponentCommand<Trip>(trip, const Trip(310, 95)));
    // Two registered types on one root-level group: the later registered
    // (ClipRect, registered again last) names it.
    final both = addGroup(
        doc,
        doc.rootHandle,
        at
            .multiply(Transform2.translation(2500, -300))
            .multiply(Transform2.rotation(0.7)));
    doc.commands
        .execute(SetComponentCommand<SoftRect>(both, const SoftRect(300, 200)));
    doc.commands
        .execute(SetComponentCommand<ClipRect>(both, const ClipRect(700, 650)));
    final nested = addGroup(doc, soft,
        Transform2.translation(120, 80).multiply(Transform2.rotation(0.4)));
    doc.commands
        .execute(SetComponentCommand<ClipRect>(nested, const ClipRect(50, 60)));
    final layered = addGroup(doc, doc.rootHandle,
        at.multiply(Transform2.translation(-900, 1400)));
    doc.commands.execute(SetComponentCommand<ObjectLayer>(
        layered, const ObjectLayer(ReservedHandles.layerZero)));
    final add = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(7010.5, 3020.25), Vector2(7133.1, 3071.9)),
        layer: ReservedHandles.layerZero);
    doc.commands.execute(add);
    final line = add.record.handle;
    doc.commands
        .execute(SetComponentCommand<ClipRect>(line, const ClipRect(90, 40)));
    final gone = addGroup(doc, doc.rootHandle,
        at.multiply(Transform2.translation(4000, 900)));
    doc.commands
        .execute(SetComponentCommand<ClipRect>(gone, const ClipRect(80, 70)));
    doc.commands.execute(RemoveNodeCommand(gone));

    expect(catalog.typeIdOf(doc, soft), SoftRect.id);
    expect(catalog.typeIdOf(doc, trip), Trip.id);
    // M-E1c: the first registration found, without the root-level rule,
    // answers softRect here.
    expect(catalog.typeIdOf(doc, both), ClipRect.id);
    // M-E1c, M-E1d: without the root-level rule, the nested group and the
    // entity answer clipRect.
    expect(catalog.typeIdOf(doc, nested), isNull);
    expect(catalog.typeIdOf(doc, line), isNull);
    expect(catalog.typeIdOf(doc, layered), isNull,
        reason: 'ObjectLayer is a component, not a parametric type');
    expect(catalog.typeIdOf(doc, gone), isNull);
    expect(catalog.typeIdOf(doc, doc.rootHandle), isNull);
    expect(catalog.typeIdOf(doc, const Handle(987654)), isNull);
  });
}
```

- [ ] **Step 2: Write the E3 test.** Create `test/parametric/partial_mutation_test.dart`:

```dart
// Spec 2a E3: every failed rollback throws PartialMutationError, a
// StateError carrying the message it always had. Each case makes one
// rollback throw on purpose. [_TripTarget] is the document as a command
// target whose invalidateDerived throws once a set number of further calls
// have passed: every command calls it exactly once, after it has mutated.
// [_Arm] sets that number right after the triggering edit applies, so the
// surveys and the edit run as usual up to the chosen command. A
// ParametricEdit is applied to the tripping target directly, as
// regeneration_test's P9 applies one.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

final class _Tripped implements Exception {
  const _Tripped();
  @override
  String toString() => 'tripped';
}

/// [doc] as a command target whose [invalidateDerived] throws once
/// [allowed] further calls have passed; null never trips.
final class _TripTarget implements CommandTarget {
  _TripTarget(this.doc);

  final DraftDocument doc;
  int? allowed;

  @override
  EntityStore get entities => doc.entities;
  @override
  GeometryStore get geometry => doc.geometry;
  @override
  DocumentTree get tree => doc.tree;
  @override
  DocumentTables get tables => doc.tables;
  @override
  ComponentRegistry get components => doc.components;
  @override
  HandleSeed get handleSeed => doc.handleSeed;
  @override
  DocumentHeader get header => doc.header;
  @override
  FillIndex get fills => doc.fills;

  @override
  void invalidateDerived() {
    doc.invalidateDerived();
    final left = allowed;
    if (left == null) return;
    if (left == 0) throw const _Tripped();
    allowed = left - 1;
  }
}

/// [inner], then [target] armed to trip after [allow] further calls. Its
/// inverse is [inner]'s, so undoing it calls invalidateDerived once.
final class _Arm extends DraftCommand {
  _Arm(this.inner, this.target, this.allow);

  final DraftCommand inner;
  final _TripTarget target;
  final int allow;

  @override
  Capability get capability => inner.capability;
  @override
  Set<Capability> get capabilities => inner.capabilities;
  @override
  String get label => 'Armed edit';

  @override
  CommandResult apply(CommandTarget t) {
    final result = inner.apply(t);
    target.allowed = allow;
    return result;
  }
}

const Handle hPin = Handle(3000);
final Transform2 pinAt =
    Transform2.translation(8400, 1900).multiply(Transform2.rotation(-1.05));

/// A [PartialMutationError] from the site whose message contains [site].
Matcher partial(String site) => throwsA(isA<PartialMutationError>()
    .having((e) => e.message, 'message', contains(site))
    .having((e) => e.message, 'message', contains('partially mutated')));

/// The select tool's delete of one object: its children, then its node.
DraftCommand deleteObject(DraftDocument doc, Handle g) => CompoundCommand([
      for (final k in kids(doc, g)) RemoveEntityCommand(k),
      RemoveNodeCommand(g),
    ], label: 'Delete');

void main() {
  test('E3-compound a compound whose rollback throws', () {
    final doc = DraftDocument.empty();
    final trip = _TripTarget(doc)..allowed = 1;
    final first = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(7010.5, 3020.25), Vector2(7133.1, 3071.9)),
        layer: ReservedHandles.layerZero);
    final second = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(-410.75, 8800.5), Vector2(-388.25, 9012)),
        layer: ReservedHandles.layerZero);
    // M-E3a: CompoundCommand.apply throws a plain StateError.
    expect(
        () => CompoundCommand([first, second], label: 'Two lines').apply(trip),
        partial('child 1 threw'));
  });

  test('E3-undo a parametric edit whose undo of the edit throws', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, parked, const ClipRect(2000, 1000)));
    final trip = _TripTarget(doc);
    // allow 0: the first regeneration command trips, then the undo of the
    // edit trips too.
    final edit = doc.commands.expander!(_Arm(
        SetComponentCommand<ClipRect>(hA, const ClipRect(3100, 450)),
        trip,
        0));
    // M-E3b: _undoInner throws a plain StateError.
    expect(() => edit.apply(trip), partial('undoing the edit then threw'));
  });

  test('E3-cascade a parametric edit whose reference cascade rollback throws',
      () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, const Post(2000, 1000)));
    doc.commands.execute(create(doc, hPin, pinAt, const Pin(hA, 450)));
    expect(kids(doc, hPin), hasLength(1),
        reason: "fixture: the pin copies A's bottom edge, so the cascade "
            'removes a child and then the node');
    final trip = _TripTarget(doc);
    // allow 1: the cascade's first removal lands, its second trips, and the
    // rollback of the first trips.
    final edit = doc.commands.expander!(_Arm(deleteObject(doc, hA), trip, 1));
    // M-E3c: _cascade's rollback throws a plain StateError.
    expect(() => edit.apply(trip), partial('the reference cascade threw'));
  });

  test('E3-regeneration a parametric edit whose regeneration rollback throws',
      () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, parked, const ClipRect(2000, 1000)));
    expect(kids(doc, hA), hasLength(4),
        reason: 'fixture: all four edges change, so the plan has four '
            'commands');
    final trip = _TripTarget(doc);
    // allow 1: the first regeneration command lands, the second trips, and
    // the rollback of the first trips.
    final edit = doc.commands.expander!(_Arm(
        SetComponentCommand<ClipRect>(hA, const ClipRect(3100, 450)),
        trip,
        1));
    // M-E3d: _run's apply loop throws a plain StateError.
    expect(() => edit.apply(trip), partial('regeneration threw'));
  });
}
```

- [ ] **Step 3: Write the E4 test.** Create `test/codec/unreadable_component_test.dart`:

```dart
// Spec 2a E4: a component whose registered factory throws is kept raw, as
// an unknown type is, and reported with its handle, when the caller asks
// for that. Otherwise the load fails as it always did. Groups sit off the
// origin at rotations; the spars have non-round sizes.
import 'dart:convert';
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

/// Refuses a non-positive width with ArgumentError, and reads its fields
/// with casts, so a missing field is a TypeError.
final class Spar implements Component {
  Spar(this.width, this.depth) {
    if (width <= 0) {
      throw ArgumentError.value(width, 'width', 'must be positive');
    }
  }

  static const String id = 'test.spar';

  final double width;
  final double depth;

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() => {'width': width, 'depth': depth};

  static Spar fromJson(Map<String, Object?> j) =>
      Spar((j['width']! as num).toDouble(), (j['depth']! as num).toDouble());

  @override
  bool operator ==(Object other) =>
      other is Spar && other.width == width && other.depth == depth;

  @override
  int get hashCode => Object.hash(width, depth);
}

void registerSpar(ComponentRegistry registry) =>
    registry.register<Spar>(Spar.id, Spar.fromJson);

const Handle h1 = Handle(4100);
const Handle h2 = Handle(4200);
const Handle h3 = Handle(4300);

/// Three spars as a registry writes them; [replaced] is written in place of
/// the payload of each handle it names.
Map<String, Object?> sparsJson(
        [Map<Handle, Map<String, Object?>> replaced = const {}]) =>
    {
      Spar.id: {
        for (final (h, s) in [
          (h1, Spar(2400.5, 120)),
          (h2, Spar(900.25, 80)),
          (h3, Spar(1750, 95.5)),
        ])
          '${h.value}': replaced[h] ?? s.toJson(),
      },
    };

/// Two spars on two root-level groups, each at its own rotated placement,
/// encoded by the codec, with the second spar's payload replaced by
/// [unreadable]. The text is the codec's own, so a save can be compared
/// byte for byte.
({String text, Handle readable, Handle unreadable}) savedWithUnreadable(
    Map<String, Object?> unreadable) {
  final doc = DraftDocument.empty();
  registerSpar(doc.components);
  final groups = <Handle>[];
  for (final (i, spar) in [Spar(2400.5, 120), Spar(900.25, 80)].indexed) {
    final g = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: g,
        parent: doc.rootHandle,
        transform: Transform2.translation(7010.0 + 2600 * i, 3020.0 - 450 * i)
            .multiply(Transform2.rotation(math.pi / 6 + i)),
        children: const [])));
    doc.commands.execute(SetComponentCommand<Spar>(g, spar));
    groups.add(g);
  }
  final json = DraftDocumentCodec.encode(doc);
  final spars = (json['components']! as Map<String, Object?>)[Spar.id]!
      as Map<String, Object?>;
  spars['${groups[1].value}'] = unreadable;
  return (text: jsonEncode(json), readable: groups[0], unreadable: groups[1]);
}

void main() {
  test(
      'E4-1 with a list, a throwing factory keeps the payload raw and '
      'reports its handle', () {
    final registry = ComponentRegistry()..register<Spar>(Spar.id, Spar.fromJson);
    final diagnostics = <Diagnostic>[];
    final json = sparsJson({
      h2: {'width': -5.0, 'depth': 80.0},
    });
    registry.loadJson(json, diagnostics: diagnostics);

    expect(registry.get<Spar>(h1), Spar(2400.5, 120));
    expect(registry.get<Spar>(h3), Spar(1750, 95.5));
    expect(registry.get<Spar>(h2), isNull);
    // M-E4a: the catch keeps nothing raw.
    expect(registry.unknownOf(h2), [
      {'typeId': Spar.id, 'width': -5.0, 'depth': 80.0},
    ]);
    // M-E4b: nothing reported. M-E4c: no handle. M-E4d: no type id.
    expect(diagnostics, hasLength(1));
    final d = diagnostics.single;
    expect(d.severity, DiagnosticSeverity.error);
    expect(d.code, 'component.unreadable');
    expect(d.handles, [h2]);
    expect(d.message, startsWith('test.spar: '));
    expect(d.message, contains('must be positive'));
    // Written back unchanged, byte for byte.
    expect(jsonEncode(registry.toJson()), jsonEncode(json));
  });

  test('E4-2 an Error thrown by the factory counts too', () {
    final registry = ComponentRegistry()..register<Spar>(Spar.id, Spar.fromJson);
    final diagnostics = <Diagnostic>[];
    // No width: `j['width']!` throws a TypeError, not an Exception.
    // M-E4e: `on Exception catch` lets it end the load.
    registry.loadJson(
        sparsJson({
          h3: {'depth': 95.5},
        }),
        diagnostics: diagnostics);
    expect(registry.get<Spar>(h1), Spar(2400.5, 120));
    expect(registry.unknownOf(h3), [
      {'typeId': Spar.id, 'depth': 95.5},
    ]);
    expect([for (final d in diagnostics) d.handles], [
      [h3],
    ]);
  });

  test("E4-3 with no list, the factory's error propagates as before", () {
    final registry = ComponentRegistry()..register<Spar>(Spar.id, Spar.fromJson);
    // M-E4f: the factory is caught whether or not a list was given.
    expect(
        () => registry.loadJson(sparsJson({
              h2: {'width': -5.0, 'depth': 80.0},
            })),
        throwsArgumentError);
  });

  test('E4-4 a value attached to that handle later is the one written', () {
    final registry = ComponentRegistry()..register<Spar>(Spar.id, Spar.fromJson);
    registry.loadJson(
        sparsJson({
          h2: {'width': -5.0, 'depth': 80.0},
        }),
        diagnostics: <Diagnostic>[]);
    registry.attach(h2, Spar(950.5, 80));
    // M-E4g: registered values written first, so the raw payload
    // overwrites the new value.
    expect((registry.toJson()[Spar.id]! as Map<String, Object?>)['4200'],
        {'width': 950.5, 'depth': 80.0});
  });

  test(
      'E4-5 the codec keeps an unreadable component when asked, and a save '
      'writes it back byte for byte', () {
    final saved = savedWithUnreadable({'width': -5.0, 'depth': 80.0});
    final diagnostics = <Diagnostic>[];
    // M-E4h: the codec hands loadJson no list; the decode throws.
    final loaded = DraftDocumentCodec.decodeString(saved.text,
        diagnostics: diagnostics,
        keepUnreadableComponents: true,
        registerComponents: registerSpar);
    expect(loaded.components.get<Spar>(saved.readable), Spar(2400.5, 120));
    expect(loaded.components.get<Spar>(saved.unreadable), isNull);
    expect([for (final d in diagnostics) (d.code, d.severity)],
        [('component.unreadable', DiagnosticSeverity.error)]);
    expect(diagnostics.single.handles, [saved.unreadable]);
    expect(DraftDocumentCodec.encodeToString(loaded), saved.text);

    // With no list, it is kept all the same. M-E4j: the codec hands on the
    // caller's null.
    final quiet = DraftDocumentCodec.decodeString(saved.text,
        keepUnreadableComponents: true, registerComponents: registerSpar);
    expect(DraftDocumentCodec.encodeToString(quiet), saved.text);
  });

  test('E4-6 without the flag, the codec fails on it as before', () {
    final saved = savedWithUnreadable({'width': -5.0, 'depth': 80.0});
    // M-E4i: the codec hands on its list whatever the flag; a symbol
    // library with a bad component would then decode (jet_cad_2d_kit's
    // SymbolLibrary.decode relies on this throw).
    expect(
        () => DraftDocumentCodec.decodeString(saved.text,
            diagnostics: <Diagnostic>[], registerComponents: registerSpar),
        throwsArgumentError);
    expect(
        () => DraftDocumentCodec.decodeString(saved.text,
            registerComponents: registerSpar),
        throwsArgumentError);
  });
}
```

- [ ] **Step 4: Run the tests and see them fail.** Run: `cd packages/jet_cad_2d && dart test test/parametric/catalog_queries_test.dart test/parametric/partial_mutation_test.dart test/codec/unreadable_component_test.dart`. Expected: each of the three files fails to compile. The errors name the undefined `typeIds` and `typeIdOf`, `PartialMutationError`, the `diagnostics` parameter of `loadJson`, and `keepUnreadableComponents`. Quote the first error line of each file.

- [ ] **Step 5: E3, the type.** Create `lib/src/core/partial_mutation_error.dart`:

```dart
/// A command threw, and undoing what it had already applied threw too, so
/// the target is partially mutated and nothing was recorded in history
/// (spec 2a E3).
///
/// Thrown by `CompoundCommand.apply` and by a `ParametricEdit` (when undoing
/// the triggering edit fails, when the reference cascade's rollback fails,
/// and when the regeneration's rollback fails), in place of the plain
/// [StateError] they threw before. The message is unchanged. It is still a
/// [StateError], so every caller that catches one catches it as before. A
/// caller that must react to an unknown document state tests for this type
/// instead of matching the message: it rebuilds what it derived from the
/// document and stops trusting its history.
final class PartialMutationError extends StateError {
  PartialMutationError(super.message);
}
```

In `lib/jet_cad_2d.dart`, add between `export 'src/core/list_equality.dart';` and `export 'src/core/tolerance.dart';`:

```dart
export 'src/core/partial_mutation_error.dart';
```

- [ ] **Step 6: E3, the four sites.**
  - `lib/src/document/commands.dart`:
    - Add `import '../core/partial_mutation_error.dart';` after `import '../core/handle.dart';` (`:3`).
    - In `CompoundCommand.apply`, `:1006`: `throw StateError('"$label": child ${inverses.length} threw ($error) '` becomes `throw PartialMutationError('"$label": child ${inverses.length} threw ($error) '`. The two continuation lines stay.
    - The class comment, `:953`: "a [StateError] naming both failures replaces the original error" becomes "a [PartialMutationError] (a [StateError]) naming both failures replaces the original error".
  - `lib/src/parametric/parametric_system.dart`: add `import '../core/partial_mutation_error.dart';` after `import '../core/handle.dart';` (`:5`). `regeneration.dart` is a `part` of this library and takes its imports from here.
  - `lib/src/parametric/regeneration.dart`:
    - `:735` in `_undoInner`: `throw StateError('"$label": $cause, and undoing the edit then threw '` becomes `throw PartialMutationError('"$label": $cause, and undoing the edit then threw '`.
    - `:793` in `_cascade`: `throw StateError('"$label": the reference cascade threw ($error) and '` becomes `throw PartialMutationError('"$label": the reference cascade threw ($error) and '`.
    - `:1040` in `_run`: `throw StateError('"${edit.label}": regeneration threw ($error) and '` becomes `throw PartialMutationError('"${edit.label}": regeneration threw ($error) and '`.
    - `_undoInner`'s comment (`:729-730`) gains a second sentence: `/// That failure is a [PartialMutationError] (spec 2a E3).`
    - `_cascade`'s comment, `:757-758`: "a failed rollback throws 06's "partially mutated" `StateError` and undoes nothing more" becomes "a failed rollback throws 06's "partially mutated" error, a [PartialMutationError] since spec 2a E3, and undoes nothing more".
    - The other `StateError`s in this file are refusals and stay plain: `_written`'s (`:955`), `_ownBoundaryOf`'s (`:514`), `RemoveEntityCommand`'s through the plan. So do the comment at `:1019-1027` and the by-hand apply loop it explains.

- [ ] **Step 7: E1.** In `lib/src/parametric/parametric_system.dart`, add to `ParametricCatalog` after `objectsOf` (`:540-543`):

```dart
  /// The type id of every registration, in registration order, each once
  /// (spec 2a E1): a type id registered again keeps the place of its first
  /// registration. A fresh iterable each call; reads the catalog only.
  Iterable<String> get typeIds => {for (final t in _types) t.typeId};

  /// The type id of the registration that names [group]'s object in
  /// [target], by the engine's own rule (the one [names] reads: a
  /// root-level `GroupNode`, named by the last registered type whose
  /// component it carries), or null when [group] is not a live parametric
  /// object: a nested or deleted group, an entity, the root, a handle that
  /// names nothing, or a group carrying no registered component. A
  /// component `ComponentRegistry.loadJson` kept raw is not a registered
  /// one (spec 2a E4).
  ///
  /// Spec 2a E1: a host dispatches grips, panels and layer pickers by this
  /// instead of re-spelling the rule. Cost: O(registered types), like
  /// [names]; no client code runs.
  String? typeIdOf(CommandTarget target, Handle group) =>
      _naming(target, _types, group)?.typeId;
```

- [ ] **Step 8: E4, the registry.** In `lib/src/document/component.dart`:
  - Add `import '../core/diagnostic.dart';` before `import '../core/handle.dart';` (`:3`).
  - Replace `loadJson` (`:295-314`) with:

```dart
  /// Replaces every component here with those of [json], in the shape
  /// [toJson] writes. A type id with no factory is kept raw
  /// ([attachUnknown]), so a later save writes it back unchanged.
  ///
  /// A registered factory that throws (spec 2a E4):
  /// - with no [diagnostics], its error propagates and the load stops, as
  ///   it always has;
  /// - with [diagnostics], the payload is kept raw exactly as an unknown
  ///   type's is, so the handle carries no value of the type and a save
  ///   writes the payload back unchanged. One [Diagnostic] is added:
  ///   severity error, code `component.unreadable`, the handle, and the
  ///   message `'<typeId>: <error>'`. Every throw counts, an [Error] too: a
  ///   factory's missing or mistyped field is a `TypeError`.
  ///
  /// A value of the type attached to that handle later is the one [toJson]
  /// writes; the raw payload stays in [unknownOf] until the handle's node
  /// is removed.
  void loadJson(Map<String, Object?> json, {List<Diagnostic>? diagnostics}) {
    clear();
    for (final typeId in json.keys.toList()..sort()) {
      final perHandle = (json[typeId]! as Map).cast<String, Object?>();
      final handleKeys = perHandle.keys.toList()
        ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      final factory = _factories[typeId];
      for (final key in handleKeys) {
        final handle = Handle.checked(int.parse(key));
        final payload = (perHandle[key]! as Map).cast<String, Object?>();
        if (factory == null) {
          // Unknown to this build: keep it exactly as read, including the
          // typeId, so it can be written back untouched.
          attachUnknown(handle, {'typeId': typeId, ...payload});
          continue;
        }
        if (diagnostics == null) {
          _stores[_typeOf[typeId]!]!.set(handle, factory(payload));
          continue;
        }
        final Component component;
        try {
          component = factory(payload);
        } catch (error) {
          // Spec 2a E4: unreadable by this build, so kept as an unknown
          // type is, and reported.
          attachUnknown(handle, {'typeId': typeId, ...payload});
          diagnostics.add(Diagnostic(
            severity: DiagnosticSeverity.error,
            code: 'component.unreadable',
            message: '$typeId: $error',
            handles: [handle],
          ));
          continue;
        }
        _stores[_typeOf[typeId]!]!.set(handle, component);
      }
    }
  }
```

  - In `toJson` (`:254-287`), move the unknown-payload block (`:265-280`, from `final unknownHandles = ...` to the end of its loop) above the registered block (`:257-263`). Put this comment over the moved block:

```dart
    // Unknown payloads first, registered values second. On the one handle
    // where the two share a type id (a payload `loadJson` kept raw because
    // its factory threw, spec 2a E4, then a value of that type attached),
    // the registered value is the one written. Among unknown payloads of one
    // type id on one handle, the last still wins (see [restore]).
```

  The rest of `toJson` is unchanged: the type ids and the handles are still sorted, so the bytes differ only on such a collision.

- [ ] **Step 9: E4, the codec.** In `lib/src/codec/json_codec.dart`:
  - In `decode`'s parameter list (`:93-100`), add `bool keepUnreadableComponents = false,` after `List<Diagnostic>? diagnostics,`. Add the same to `decodeString` (`:152-159`) and pass it on in its call, `keepUnreadableComponents: keepUnreadableComponents,`.
  - Replace the components load (`:133-134`) with:

```dart
    // Spec 2a E4: only a caller that asks gets an unreadable component kept
    // raw. A symbol library's decode relies on the factory's throw.
    doc.components.loadJson(
        (json['components']! as Map).cast<String, Object?>(),
        diagnostics:
            keepUnreadableComponents ? (diagnostics ?? <Diagnostic>[]) : null);
```

  - `decode`'s doc comment (`:88-92`) becomes:

```dart
  /// [diagnostics], when supplied, receives every diagnostic import produces:
  /// [DocumentTree.repairCycles]'s reports of a dropped definition-cycle back
  /// edge and, with [keepUnreadableComponents], one `component.unreadable`
  /// per component kept raw. The repair itself always happens; passing no
  /// list only means the caller is not told what was dropped, so a caller that
  /// needs to surface data loss to a user must pass one.
  ///
  /// [keepUnreadableComponents] (spec 2a E4): when true, a component whose
  /// registered factory throws is kept raw and reported instead of failing
  /// the decode (see `ComponentRegistry.loadJson`). Off by default: a caller
  /// that must refuse such a document, a symbol library, still gets the
  /// factory's error.
```

- [ ] **Step 10: The CHANGELOG.** In `CHANGELOG.md`, insert between `# Changelog` and `## 0.7.2`:

```markdown
## Unreleased

- `ParametricCatalog.typeIds` and `ParametricCatalog.typeIdOf(target,
  group)`: the registered type ids in registration order, and the type id
  that names a group's live object by the engine's own rule (null when it
  is none).
- `PartialMutationError`, a `StateError` with the same message, is what a
  failed rollback now throws: `CompoundCommand.apply`, and a
  `ParametricEdit` undoing its edit, its reference cascade or its
  regeneration. A caller catching `StateError` is unaffected.
- `ComponentRegistry.loadJson(json, diagnostics: list)` and
  `DraftDocumentCodec.decode(…, keepUnreadableComponents: true)`: a
  component whose factory throws is kept raw, as an unknown type is, and
  reported as a `component.unreadable` diagnostic naming its handle,
  instead of failing the load. Off by default. A value of the type
  attached to that handle later is the one a save writes.
```

- [ ] **Step 11: Run the new tests.** Run: `cd packages/jet_cad_2d && dart test test/parametric/catalog_queries_test.dart test/parametric/partial_mutation_test.dart test/codec/unreadable_component_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 12: The engine's gate.** Run, one at a time:
  - `cd packages/jet_cad_2d && dart format .`
  - `cd packages/jet_cad_2d && dart test`. Expected: the only failures are the `packages/jet_cad_2d` lines of `tool/ci/standing_failures.txt`, which fail on clean `main` on this machine as well. The existing rollback test (`test/document/compound_command_test.dart`, "a rollback inverse that throws surfaces both failures…", matching `isA<StateError>()`) stays green.
  - `cd packages/jet_cad_2d && dart analyze`. Expected: `No issues found!`.
  - `cd packages/jet_cad_2d && dart format --output=none --set-exit-if-changed .`. Expected: exit 0.

- [ ] **Step 13: The engine's dependents, unchanged.** Every package that decodes documents or runs the parametric system must still pass with no change to its code or tests. This is where E4's opt-in is checked against `SymbolLibrary.decode`'s rules. Run, one at a time:
  - `cd packages/jet_cad_2d_kit && flutter test`
  - `cd packages/jet_cad_2d_flutter && flutter test`
  - `cd packages/jet_cad_2d_gpu && flutter test`
  - `cd packages/jet_cad_floor_plan && flutter test`
  - `cd packages/jet_cad_restaurant_symbols && flutter test`

  Expected for each: the same result as on clean `main`. The only failures are the lines `tool/ci/standing_failures.txt` lists for that package. When in doubt, run the same command in a checkout of `main` and compare. `git status --short` shows only this task's files: a `flutter test` can rewrite an `analysis_options.yaml`, so leave any such file unstaged.

- [ ] **Step 14: Commit.**

```bash
git add packages/jet_cad_2d/lib/src/core/partial_mutation_error.dart packages/jet_cad_2d/lib/jet_cad_2d.dart packages/jet_cad_2d/lib/src/document/commands.dart packages/jet_cad_2d/lib/src/parametric/parametric_system.dart packages/jet_cad_2d/lib/src/parametric/regeneration.dart packages/jet_cad_2d/lib/src/document/component.dart packages/jet_cad_2d/lib/src/codec/json_codec.dart packages/jet_cad_2d/CHANGELOG.md packages/jet_cad_2d/test/parametric/catalog_queries_test.dart packages/jet_cad_2d/test/parametric/partial_mutation_test.dart packages/jet_cad_2d/test/codec/unreadable_component_test.dart
git commit -m "$(cat <<'EOF'
feat(engine): catalog type queries, PartialMutationError, unreadable components (2a E1, E3, E4)

ParametricCatalog lists its type ids in registration order and names the
type of a group's live object by the engine's own rule. A failed rollback
throws PartialMutationError, a StateError with the same message, at all
four sites. With keepUnreadableComponents, the codec keeps a component
whose factory throws raw, as an unknown type is, and reports it with its
handle; without it, decoding fails as before.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 15: Mutation check.** Run these on the committed files only. For each mutation: apply the edit, run the named test with `cd packages/jet_cad_2d && dart test <file> --name '<id>'`, see it red and quote the failing expectation line. Then `git checkout -- <file>`, then `git diff --quiet -- <file>`, which must exit 0.
  - M-E1a (`parametric_system.dart`): `typeIds => {for (final t in _types) t.typeId}.toList()..sort();` → `E1-typeIds` red.
  - M-E1b (`parametric_system.dart`): `typeIds => [for (final t in _types) t.typeId];` → `E1-typeIds` red.
  - M-E1c (`parametric_system.dart`): `typeIdOf`'s body becomes `{ for (final t in _types) { if (t.has(target, group)) return t.typeId; } return null; }` → `E1-typeIdOf` red.
  - M-E1d (`parametric_system.dart`): `typeIdOf`'s body becomes `{ for (var i = _types.length - 1; i >= 0; i--) { if (_types[i].has(target, group)) return _types[i].typeId; } return null; }` → `E1-typeIdOf` red (the nested group and the entity).
  - M-E3a (`commands.dart`): `throw PartialMutationError(` back to `throw StateError(` at the compound site → `E3-compound` red.
  - M-E3b (`regeneration.dart`): the same edit in `_undoInner` → `E3-undo` red.
  - M-E3c (`regeneration.dart`): the same edit in `_cascade` → `E3-cascade` red.
  - M-E3d (`regeneration.dart`): the same edit in `_run`'s apply loop → `E3-regeneration` red.
  - M-E4a (`component.dart`): delete `attachUnknown(handle, {'typeId': typeId, ...payload});` inside the `catch` → `E4-1` red.
  - M-E4b (`component.dart`): delete the `diagnostics.add(...)` statement → `E4-1` red.
  - M-E4c (`component.dart`): `handles: [handle],` becomes `handles: const [],` → `E4-1` red.
  - M-E4d (`component.dart`): `message: '$typeId: $error',` becomes `message: '$error',` → `E4-1` red.
  - M-E4e (`component.dart`): `} catch (error) {` becomes `} on Exception catch (error) {` → `E4-2` red.
  - M-E4f (`component.dart`): delete the `if (diagnostics == null) { … continue; }` block, and write `diagnostics?.add(` for `diagnostics.add(` → `E4-3` red.
  - M-E4g (`component.dart`): move the registered block back above the unknown block in `toJson` → `E4-4` red.
  - M-E4h (`json_codec.dart`): `diagnostics: keepUnreadableComponents ? (diagnostics ?? <Diagnostic>[]) : null` becomes `diagnostics: null` → `E4-5` red.
  - M-E4i (`json_codec.dart`): the same expression becomes `diagnostics: diagnostics` → `E4-6` red.
  - M-E4j (`json_codec.dart`): the same expression becomes `diagnostics: keepUnreadableComponents ? diagnostics : null` → `E4-5` red (the second decode).

#### Interface problem

Resolved by controller ruling R-c (`keepUnreadableComponents`, opt-in; Task 7's `decodePlan` passes true).

---

