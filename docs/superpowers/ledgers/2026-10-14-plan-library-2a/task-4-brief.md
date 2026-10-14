### Task 4: Contract — `PlanType`, `PlanTool`, `PlanServices`, `KitWords`, `TypeGuard`, attachment, diagnostics, `PlanKit` growth (spec P1, P3 attachment, P4 codes)

**Files:**
- Create: `packages/jet_cad_2d_kit/lib/src/kit/plan_type.dart`, `lib/src/kit/plan_tool.dart`, `lib/src/kit/plan_services.dart`, `lib/src/kit/attachment.dart`, `lib/src/kit/kit_diagnostic.dart`
- Modify: `packages/jet_cad_2d_kit/pubspec.yaml` (`jet_cad_2d_flutter: ^0.7.2`), `lib/src/kit/plan_kit.dart` (rewritten), `lib/src/model/kit_problem.dart` (seven codes), `lib/src/model/kit_ids.dart` (`isCodeId`), `lib/jet_cad_2d_kit.dart` (five exports), `CHANGELOG.md` (one bullet)
- Test: `packages/jet_cad_2d_kit/test/kit/plan_type_test.dart`, `test/kit/plan_tool_test.dart`, `test/kit/plan_services_test.dart`, `test/kit/attachment_test.dart`, `test/kit/kit_diagnostic_test.dart`, `test/support/plan_type_fixtures.dart`, `test/support/tool_fixtures.dart`; modify `test/kit/plan_kit_test.dart`, `test/model/kit_ids_test.dart`

(All paths below are under `packages/jet_cad_2d_kit/` unless they start at the repository root.)

**Interfaces:**
- Consumes:
  - Task 3: `PropertySpec<T>.bind`, `PropertyField`, `ChoiceProperty.segmentOf`, `ColourTarget<T>`, `test/support/code_fixtures.dart` (`Slab`, `Post`, `Finish`, `slabSpecs()`, `postSpecs()`).
  - Engine (`package:jet_cad_2d/jet_cad_2d.dart`): `ParametricType<T>` (`lib/src/parametric/parametric_system.dart:25-161`; `contributesPlace`, `readsPlaces`), `ParametricCatalog.register<T>` (`:495-502`, refuses a type that both contributes and reads places), `names<T>`/`objectsOf<T>` (`:529-543`, `T` matched exactly by its registration), `ParametricSystem(document, catalog)` + `install()` (`:548-571`), `ComponentFactory<T>` (`lib/src/document/component.dart:21`), `ComponentRegistry.get<T>` (`:151`, null when `T` is unregistered), `SetComponentCommand<T>` (`lib/src/document/commands.dart:634-663`), `CommandTarget` (`command.dart:88`), `DraftCommand`, `Capability` (`command.dart:25-37`), `Handle`, `Aabb2`, `Transform2` (no `operator ==`, `transform2.dart:124-133`), `Generated` (`parametric_system.dart:222`).
  - Flutter layer (`package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart`, 0.7.2): `Tool` (`lib/src/tool.dart:115`), `ObjectGripProvider` (`lib/src/grip_cache.dart:33-54`), `CameraController` (`lib/src/camera_controller.dart:44`); engine `SpatialIndex` (`jet_cad_2d/lib/src/index/spatial_index.dart:161`).
  - Existing: `PlanKit` (`lib/src/kit/plan_kit.dart:10-74`), `KitNames.word` (`lib/src/model/kit_names.dart:34-35`, locale then English), `KitProblemCode` (`lib/src/model/kit_problem.dart:7-29`, 19 values), `kitOfKey`/`isKitId` (`lib/src/model/kit_ids.dart`).
- Produces (exported from `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` only):
  - `typedef PropertySectionBuilder<T> = Widget Function(BuildContext, T value, void Function(T) commit, KitWords words)`.
  - `abstract interface class TypeGuard { ParametricType<T> wrap<T extends Component>(String kitId, String typeId, ParametricType<T> type); }`.
  - `final class PlanType<T extends Component>`: `const PlanType({required String id, required ComponentFactory<T> fromJson, required ParametricType<T> parametric, ObjectGripProvider Function(PlanServices)? grips, List<PropertySpec<T>> properties = const [], PropertySectionBuilder<T>? section, String Function(T)? title, ColourTarget<T>? colour, bool exported = true})`; public `id`, `fromJson`, `parametric`, `grips`, `properties`, `exported` (each safe to read through `PlanType<Component>`: `T` only in covariant positions); `bool get hasColour`, `bool get hasSection`; `void registerInto(ParametricCatalog catalog, {TypeGuard? guard})`; `List<PropertyField> fieldsOf(CommandTarget target, Handle group)`; `String titleWordOf(CommandTarget target, Handle group)`; `String? colourOf(CommandTarget target, Handle group)`; `DraftCommand? recolour(CommandTarget target, Handle group, String? swatch)`; `DraftCommand commitField(CommandTarget target, Handle group, PropertyField field, Object? input)`; `Widget? sectionFor(BuildContext context, CommandTarget target, Handle group, void Function(DraftCommand) execute, KitWords words)`; `ObjectGripProvider? gripsFor(PlanServices services)`.
  - `final class PlanToolSettings<S extends Object>`: `const PlanToolSettings({required S initial, required List<PropertySpec<S>> specs})`; `List<PropertyField> fieldsOf(Object value, void Function(Object) store, {required String toolId})` (controller ruling R-e).
  - `final class PlanTool`: `const PlanTool({required String id, required IconData icon, String? letter, Set<Capability> needs = const {}, PlanToolSettings<Object>? settings, required Tool Function(PlanServices) create})`.
  - `abstract interface class KitWords { String word(String wordId); String? maybe(String wordId); Locale get locale; }`; `final class KitNamesWords implements KitWords { KitNamesWords(KitNames names, Locale Function() locale); final KitNames names; }`.
  - `abstract interface class Disposable { void dispose(); }` (the controller's ruling).
  - `abstract interface class PlanServices { DraftDocument get document; SpatialIndex get index; CameraController get camera; bool get objectSnap; AttachmentRegistry get attachments; KitWords get words; S settingsOf<S extends Object>(String toolId); T shared<T extends Object>(T Function(PlanServices) create); }`.
  - `abstract interface class AttachmentProvider { String get kind; Attachment? attach(AttachmentQuery query); }`; `final class AttachmentQuery({required Aabb2 footprint, required Transform2 current, required Vector2 pointer, required double capture, required double edgeCapture, required bool mirrored, required bool mayRotate, Set<Handle> exclude = const {}, Attachment? keep})`; `final class Attachment({required Transform2 transform, required Vector2 marker, required Object token})`; `abstract interface class AttachmentRegistry { Attachment? attach(List<String> kinds, AttachmentQuery query); Set<String> get kinds; }`.
  - `enum KitDiagnosticCode { hookFailed, rollbackFailed, damagedUnsavable, componentUnreadable, letterTaken, attachmentKindUnoffered, libraryUnreadable, libraryKitMismatch, symbolDuplicate, kitMissing, kitNewer }`; `final class KitDiagnostic { const KitDiagnostic({required String kitId, String? subject, required KitDiagnosticCode code, required String message, Object? error}); }`, equal by kit, subject, code and message.
  - `PlanKit` gains `List<PlanType<Component>> types`, `List<PlanTool> tools`, `List<AttachmentProvider Function(PlanServices)> attachments` (all `const []` by default; the constructor stays `const`) and `List<String> get propertyIds`.
  - `KitProblemCode` gains `duplicateKit, duplicateType, duplicateTool, reservedKitId, typeOutsideKit, toolOutsideKit, typePlaceConflict`, appended after `localeUndeclared` (no exhaustive `switch` over it exists in the repository: `grep -rn KitProblemCode --include='*.dart' packages tool apps` outside tests shows only `plan_kit.dart`, `conformance.dart` and `kit_problem.dart`).
  - `bool isCodeId(String id)` (exported with the model, so both barrels carry it; Task 5's `conformance` uses it).

Plan decision: **`PlanType` keeps every member whose type takes `T` contravariantly private** (`section`, `title`, `colour`, through a `const` initializer list). Read through `PlanType<Component>`, such a member fails the VM's covariance check (spec P1). The members left public (`fromJson`, `parametric`, `grips`, `properties`) only return `T`, so reading them is safe: Task 6 reads `type.parametric.contributesPlace`/`readsPlaces` for `typePlaceConflict`, and `PlanKit.propertyIds` reads `properties`. Every `T`-typed use goes through the erased operations, which run inside the class over its real `T`.
Plan decision: **`registerInto` calls `catalog.register<T>` with the class's `T`,** through `guard.wrap<T>(kitOfKey(id), id, parametric)` when a guard is given. PT1 pins `T` by `catalog.objectsOf<Slab>`, which matches the registration's type argument exactly (`parametric_system.dart:521-525`).
Plan decision: **`commitField` binds the field's spec again to the object's current value** (found by `identical(spec, field.spec)` among this type's own specs), so a field read before another edit never writes back what that edit changed (the panel pins a field on focus, Task 17). A field of another type, a display, or a handle without a `T` is an `ArgumentError`; the spec's own refusals pass through unchanged. The result is one `SetComponentCommand<T>`.
Plan decision: `recolour` answers null when the type has no colour target, the handle no `T`, or the swatch is already the one asked (stored-value `==`), so the colour row's compound never holds a no-op.
Plan decision: `titleWordOf` answers the type's `title(value)` word id, or `type:<id>` when it has no hook or the handle no `T`.
Plan decision: `KitNamesWords.word` falls back locale → English → the word id itself (a missing word is visible, never blank); `maybe` answers null instead of the id. The locale is read from the callback on every call, so a language change shows at once (spec P5).
Plan decision: **`AttachmentQuery` and `Attachment` are identity-equal.** `Transform2` has no `operator ==` by design (`transform2.dart:124-126`), and a provider compares `keep.token`, its own object. Both copy their `Vector2`s and `exclude` (unmodifiable), and refuse with `ArgumentError` a capture or edge capture that is negative or not finite, a non-finite pointer, marker or transform.
Plan decision: **`PlanKit.validate` checks the code side within the kit**: a type or tool id that is not `isCodeId` with this kit's id first (`typeOutsideKit`, `toolOutsideKit`), an id given twice (`duplicateType`, `duplicateTool`), and English for every word id the code side needs: `type:<id>`, `tool:<id>`, `property:<owner>.<spec>` for each type's and tool settings' spec, and `property:<owner>.<spec>.<segment>` for each choice value (`missingEnglish`, one problem per word id, even when a locale's word also needs it). The words of an id refused as outside or repeated are not required. Kit-set problems (duplicates across kits, reserved ids, `typePlaceConflict`) are Task 6's. A property id repeated within one type is not reported (no code for it; the field list then shows two fields with the same word).
Plan decision: the `missingEnglish` message becomes `"<word id>" has no English word` (it named the locale before); K6 asserts only that it contains the word id, and still holds.
Plan decision: `propertyIds` is public: Task 5's `conformance` takes it as `propertyIds:` (R3), and a kit cannot list its choice values' segments without `ChoiceProperty.segmentOf`.

- [ ] **Step 1: The dependency.** In `pubspec.yaml`, add under `dependencies:`, after `jet_cad_2d: ^0.7.2`:

```yaml
  jet_cad_2d_flutter: ^0.7.2
```

Run: `cd packages/jet_cad_2d_kit && flutter pub get`, then `git status --short` from the repository root. Expected: ` M packages/jet_cad_2d_kit/pubspec.yaml` and nothing you must stage besides it. An `analysis_options.yaml` that `pub get` rewrote is restored with `git checkout -- <that file>` and is never staged. Then: `flutter test test/invariants/purity_test.dart` (P1 green: `authoring.dart` and `lib/src/model/` reach no Flutter, so the new dependency does not reach them), and from the repository root `dart run tool/ci/check_kit_deps.dart`. Expected: `kit dependencies: <n> package(s) checked, none names the plan library or another kit` (quote it); the contract may depend on the Flutter layer (umbrella A1; `tool/ci/lib/kit_deps.dart:1-12` forbids only the plan library and kits).

- [ ] **Step 2: The fixtures.** Create `test/support/plan_type_fixtures.dart`:

```dart
// Fixtures for PlanType and PlanKit (spec 2a P1): engine types for the slab
// and the post of code_fixtures.dart, their PlanTypes, and a document with
// one live object of each, in rotated groups off the origin.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ObjectGripProvider;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import 'code_fixtures.dart';

/// An engine type that generates nothing and logs every object it is asked
/// to generate.
final class LoggingType<T extends Component> extends ParametricType<T> {
  LoggingType();

  final List<Handle> generated = [];

  @override
  Capability get editCapability => Capability.components;

  @override
  Aabb2 reach(T params, Transform2 toWorld) => Aabb2.empty();

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    generated.add(self);
    return const [];
  }
}

String? slabSwatch(Slab s) => s.swatch;

Slab slabRecolour(Slab s, String? swatch) =>
    s.copyWith(swatch: swatch, clearSwatch: swatch == null);

String? postSwatch(Post p) => p.swatch;

Post postRecolour(Post p, String? swatch) =>
    Post(width: p.width, shape: p.shape, swatch: swatch);

/// The slab type: every property kind, a title hook, a colour target, an
/// optional section and grips.
PlanType<Slab> slabType({
  ParametricType<Slab>? engine,
  PropertySectionBuilder<Slab>? section,
  ObjectGripProvider Function(PlanServices)? grips,
}) =>
    PlanType<Slab>(
      id: Slab.id,
      fromJson: Slab.fromJson,
      parametric: engine ?? LoggingType<Slab>(),
      properties: slabSpecs(),
      title: (s) => s.raised ? 'type:test.slab.raised' : 'type:test.slab',
      colour: const ColourTarget<Slab>(read: slabSwatch, write: slabRecolour),
      section: section,
      grips: grips,
    );

/// The post type: a colour target, no title, no section, not exported.
PlanType<Post> postType({ParametricType<Post>? engine}) => PlanType<Post>(
      id: Post.id,
      fromJson: Post.fromJson,
      parametric: engine ?? LoggingType<Post>(),
      properties: postSpecs(),
      colour: const ColourTarget<Post>(read: postSwatch, write: postRecolour),
      exported: false,
    );

const Handle hSlab = Handle(4100);
const Handle hPost = Handle(4200);
const Handle hBare = Handle(4300);

final Transform2 slabAt = Transform2.translation(2150.5, -730.25)
    .multiply(Transform2.rotation(math.pi / 7));
final Transform2 postAt =
    Transform2.translation(-1840.75, 960.5).multiply(Transform2.rotation(-0.4));

DraftCommand addObject<T extends Component>(
        DraftDocument doc, Handle h, Transform2 at, T value) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: at,
          children: const [])),
      SetComponentCommand<T>(h, value),
    ], label: 'Add object');

/// A document whose catalog holds [types] (registered through
/// `registerInto`, with [guard] when given), a slab at [hSlab], a post at
/// [hPost] and a plain group at [hBare]. The caller disposes the document.
({DraftDocument doc, ParametricCatalog catalog}) objectDocument(
    List<PlanType<Component>> types,
    {TypeGuard? guard,
    Slab slab = const Slab(),
    Post post = const Post()}) {
  final catalog = ParametricCatalog();
  for (final type in types) {
    type.registerInto(catalog, guard: guard);
  }
  final doc = DraftDocument.empty();
  ParametricSystem(doc, catalog).install();
  doc.commands
    ..execute(addObject(doc, hSlab, slabAt, slab))
    ..execute(addObject(doc, hPost, postAt, post))
    ..execute(AddNodeCommand(GroupNode(
        handle: hBare,
        parent: doc.rootHandle,
        transform: Transform2.translation(400.5, 300.25),
        children: const [])))
    ..clearHistory();
  return (doc: doc, catalog: catalog);
}
```

Create `test/support/tool_fixtures.dart`:

```dart
// Fixtures for PlanTool and its settings (spec 2a P1, P3): two settings
// types, so a list of tools holds settings of two different `S`.
import 'package:flutter/widgets.dart' show IconData;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:meta/meta.dart';

import 'code_fixtures.dart';

@immutable
final class SlabSettings {
  const SlabSettings({this.width = 900.5, this.finish = Finish.oiled});

  final double width;
  final Finish finish;

  @override
  bool operator ==(Object other) =>
      other is SlabSettings && other.width == width && other.finish == finish;

  @override
  int get hashCode => Object.hash(width, finish);

  @override
  String toString() => 'SlabSettings($width, ${finish.name})';
}

@immutable
final class PostSettings {
  const PostSettings({this.round = false});

  final bool round;

  @override
  bool operator ==(Object other) =>
      other is PostSettings && other.round == round;

  @override
  int get hashCode => round.hashCode;
}

PlanTool slabTool({String id = 'test.slab'}) => PlanTool(
      id: id,
      icon: const IconData(0xe1b1),
      letter: 'S',
      needs: const {Capability.structure, Capability.geometry},
      settings: PlanToolSettings<SlabSettings>(
        initial: const SlabSettings(),
        specs: [
          LengthProperty<SlabSettings>(
            id: 'width',
            read: (s) => s.width,
            write: (s, v) => SlabSettings(width: v, finish: s.finish),
            min: 300,
          ),
          ChoiceProperty<SlabSettings, Finish>(
            id: 'finish',
            values: const [Finish.oiled, Finish.raw],
            read: (s) => s.finish,
            write: (s, v) => SlabSettings(width: s.width, finish: v),
          ),
        ],
      ),
      create: (services) => throw UnimplementedError('not armed in tests'),
    );

PlanTool postTool({String id = 'test.post'}) => PlanTool(
      id: id,
      icon: const IconData(0xe1b2),
      settings: PlanToolSettings<PostSettings>(
        initial: const PostSettings(),
        specs: [
          ToggleProperty<PostSettings>(
            id: 'round',
            read: (s) => s.round,
            write: (s, v) => PostSettings(round: v),
          ),
        ],
      ),
      create: (services) => throw UnimplementedError('not armed in tests'),
    );
```

- [ ] **Step 3: Write the failing tests.** Create `test/kit/plan_type_test.dart`:

```dart
// Spec 2a P1, P3: PlanType's erased operations. Two types of different
// component types `T` (a slab and a post) are held as PlanType<Component>,
// as the plan library holds them, and registered, edited, recoloured and
// shown under the VM's runtime checks (Review Focus 3).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ObjectGripProvider;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/code_fixtures.dart';
import '../support/plan_type_fixtures.dart';

/// Records what it is asked to wrap and swaps in [replacements] by type id.
final class RecordingGuard implements TypeGuard {
  RecordingGuard([this.replacements = const {}]);

  final Map<String, ParametricType<Component>> replacements;
  final List<(String, String, Type)> calls = [];

  @override
  ParametricType<T> wrap<T extends Component>(
      String kitId, String typeId, ParametricType<T> type) {
    calls.add((kitId, typeId, T));
    final replacement = replacements[typeId];
    return replacement == null ? type : replacement as ParametricType<T>;
  }
}

final class FakeServices implements PlanServices {
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final class FakeGrips implements ObjectGripProvider {
  FakeGrips(this.services);

  final PlanServices services;

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) => const [];

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      null;

  @override
  List<(EntityKind, GeometryPayload)> preview(
          DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      const [];

  @override
  bool movable(DraftDocument d, Handle group) => true;
}

void main() {
  test('PT1 registerInto keeps each type\'s T', () {
    final List<PlanType<Component>> types = [slabType(), postType()];
    final (:doc, :catalog) = objectDocument(types);
    addTearDown(doc.dispose);
    // M-PT1: `catalog.register<Component>(id, fromJson, type)` in
    // registerInto (T inferred as Component): neither is found.
    expect(catalog.objectsOf<Slab>(doc), [hSlab]);
    expect(catalog.objectsOf<Post>(doc), [hPost]);
    expect(catalog.objectsOf<Component>(doc), isEmpty);
  });

  test('PT2 the guard wraps each type with its kit, its id and its T', () {
    final replacement = LoggingType<Slab>();
    final original = LoggingType<Slab>();
    final guard = RecordingGuard({Slab.id: replacement});
    final (:doc, catalog: _) =
        objectDocument([slabType(engine: original), postType()], guard: guard);
    addTearDown(doc.dispose);
    expect(guard.calls, [('test', Slab.id, Slab), ('test', Post.id, Post)]);
    // M-PT2: ignore the guard; the original type is regenerated instead.
    expect(replacement.generated, [hSlab]);
    expect(original.generated, isEmpty);
  });

  test('PT3 fieldsOf binds every spec to the object, under its word', () {
    final List<PlanType<Component>> types = [slabType(), postType()];
    final (:doc, catalog: _) = objectDocument(types,
        slab: const Slab(width: 980.5, label: 'Pass'),
        post: const Post(width: 210.25, shape: 'square'));
    addTearDown(doc.dispose);
    final slabFields = types[0].fieldsOf(doc, hSlab);
    // M-PT3: build the word from the spec id only.
    expect([
      for (final f in slabFields) f.wordId
    ], [
      'property:test.slab.width',
      'property:test.slab.turn',
      'property:test.slab.grade',
      'property:test.slab.finish',
      'property:test.slab.raised',
      'property:test.slab.label',
      'property:test.slab.area',
      'property:test.slab.flip',
    ]);
    expect(slabFields[0].value, 980.5);
    expect(slabFields[5].value, 'Pass');
    final postFields = types[1].fieldsOf(doc, hPost);
    expect([for (final f in postFields) f.value], [210.25, 'square']);
    expect(postFields[0].enabled, isFalse);
    // Not this type's object, or no object at all.
    expect(types[0].fieldsOf(doc, hPost), isEmpty);
    expect(types[0].fieldsOf(doc, hBare), isEmpty);
  });

  test('PT4 commitField is one SetComponentCommand<T>, one undo step', () {
    final List<PlanType<Component>> types = [slabType(), postType()];
    final (:doc, catalog: _) = objectDocument(types);
    addTearDown(doc.dispose);
    final width = types[0].fieldsOf(doc, hSlab).first;
    final command = types[0].commitField(doc, hSlab, width, 2400.75);
    // M-PT4: `SetComponentCommand<Component>`: the store keyed by Slab
    // keeps the old value.
    expect(command, isA<SetComponentCommand<Slab>>());
    doc.commands.execute(command);
    expect(doc.components.get<Slab>(hSlab), const Slab(width: 2400.75));
    final shape = types[1].fieldsOf(doc, hPost)[1];
    doc.commands.execute(types[1].commitField(doc, hPost, shape, 'square'));
    expect(doc.components.get<Post>(hPost), const Post(shape: 'square'));
    doc.commands.undo();
    expect(doc.components.get<Post>(hPost), const Post());
    expect(doc.components.get<Slab>(hSlab), const Slab(width: 2400.75));
  });

  test('PT5 commitField binds again to the current value', () {
    final type = slabType();
    final (:doc, catalog: _) = objectDocument([type, postType()]);
    addTearDown(doc.dispose);
    final width = type.fieldsOf(doc, hSlab).first;
    // Another edit lands between reading the field and committing it.
    doc.commands.execute(
        type.commitField(doc, hSlab, type.fieldsOf(doc, hSlab)[5], 'Pass'));
    doc.commands.execute(type.commitField(doc, hSlab, width, 2400.75));
    // M-PT5: commit through `field.commit` (the stale value): the label
    // goes back to 'Bar top'.
    expect(doc.components.get<Slab>(hSlab),
        const Slab(width: 2400.75, label: 'Pass'));
  });

  test('PT6 commitField refuses a foreign field, a display, a missing T', () {
    final List<PlanType<Component>> types = [slabType(), postType()];
    final (:doc, catalog: _) = objectDocument(types);
    addTearDown(doc.dispose);
    final postWidth = types[1].fieldsOf(doc, hPost).first;
    expect(postWidth.spec.id, 'width');
    // M-PT6: match the spec by id: the post's width commits the slab's.
    expect(() => types[0].commitField(doc, hSlab, postWidth, 600),
        throwsArgumentError);
    final area = types[0].fieldsOf(doc, hSlab)[6];
    expect(
        () => types[0].commitField(doc, hSlab, area, 1), throwsArgumentError);
    final width = types[0].fieldsOf(doc, hSlab).first;
    expect(() => types[0].commitField(doc, hBare, width, 600),
        throwsArgumentError);
    // Out of range: the field's own refusal, nothing executed.
    expect(
        () => types[0].commitField(doc, hSlab, width, 10), throwsArgumentError);
    expect(doc.commands.canUndo, isFalse);
  });

  test('PT7 colourOf and recolour over two types, one compound command', () {
    final List<PlanType<Component>> types = [slabType(), postType()];
    final (:doc, catalog: _) =
        objectDocument(types, post: const Post(swatch: 'teal'));
    addTearDown(doc.dispose);
    expect([types[0].colourOf(doc, hSlab), types[1].colourOf(doc, hPost)],
        ['teal', 'teal']);
    final commands = [
      types[0].recolour(doc, hSlab, 'ochre')!,
      types[1].recolour(doc, hPost, 'ochre')!,
    ];
    doc.commands.execute(CompoundCommand(commands, label: 'Recolour'));
    expect([types[0].colourOf(doc, hSlab), types[1].colourOf(doc, hPost)],
        ['ochre', 'ochre']);
    // M-PT7: drop the unchanged check: a no-op command comes back.
    expect(types[0].recolour(doc, hSlab, 'ochre'), isNull);
    doc.commands.execute(types[0].recolour(doc, hSlab, null)!);
    expect(types[0].colourOf(doc, hSlab), isNull);
    // No T on the handle.
    expect(types[0].recolour(doc, hBare, 'ochre'), isNull);
    expect(types[0].colourOf(doc, hPost), isNull);
  });

  test('PT8 a type without a colour target or a section', () {
    final bare = PlanType<Post>(
        id: 'test.bare',
        fromJson: Post.fromJson,
        parametric: LoggingType<Post>());
    final (:doc, catalog: _) = objectDocument([slabType(), bare]);
    addTearDown(doc.dispose);
    expect(bare.hasColour, isFalse);
    expect(bare.hasSection, isFalse);
    expect(bare.exported, isTrue);
    expect(bare.properties, isEmpty);
    expect(bare.colourOf(doc, hPost), isNull);
    expect(bare.recolour(doc, hPost, 'ochre'), isNull);
    expect(slabType().hasColour, isTrue);
    expect(postType().exported, isFalse);
  });

  test('PT9 titleWordOf: type:<id>, or what the title hook names', () {
    final List<PlanType<Component>> types = [slabType(), postType()];
    final (:doc, catalog: _) = objectDocument(types);
    addTearDown(doc.dispose);
    // M-PT9: ignore the title hook.
    expect(types[0].titleWordOf(doc, hSlab), 'type:test.slab.raised');
    doc.commands
        .execute(SetComponentCommand<Slab>(hSlab, const Slab(raised: false)));
    expect(types[0].titleWordOf(doc, hSlab), 'type:test.slab');
    expect(types[1].titleWordOf(doc, hPost), 'type:test.post');
    expect(types[0].titleWordOf(doc, hBare), 'type:test.slab');
  });

  testWidgets('PT10 sectionFor builds the section and commits a T',
      (tester) async {
    void Function(Slab)? commit;
    final type = slabType(section: (context, value, c, words) {
      commit = c;
      return Text('${words.word('type:test.slab')}: ${value.label}',
          textDirection: TextDirection.ltr);
    });
    final List<PlanType<Component>> types = [type, postType()];
    final (:doc, catalog: _) = objectDocument(types);
    addTearDown(doc.dispose);
    final words = KitNamesWords(
        const KitNames({
          'tr': {'type:test.slab': 'Tezgâh'},
        }),
        () => const Locale('tr'));
    final executed = <DraftCommand>[];
    Widget? post;
    await tester.pumpWidget(Builder(builder: (context) {
      post = types[1].sectionFor(context, doc, hPost, executed.add, words);
      return types[0].sectionFor(context, doc, hSlab, executed.add, words)!;
    }));
    expect(find.text('Tezgâh: Bar top'), findsOneWidget);
    expect(post, isNull);
    commit!(const Slab(label: 'Pass'));
    // M-PT10: hand execute a SetComponentCommand<Component>.
    expect(executed.single, isA<SetComponentCommand<Slab>>());
    doc.commands.execute(executed.single);
    expect(doc.components.get<Slab>(hSlab), const Slab(label: 'Pass'));
  });

  test('PT11 gripsFor makes the provider over the given services', () {
    final services = FakeServices();
    final type = slabType(grips: FakeGrips.new);
    final List<PlanType<Component>> types = [type, postType()];
    // M-PT11: `gripsFor` returns null.
    final grips = types[0].gripsFor(services);
    expect(grips, isA<FakeGrips>());
    expect(identical((grips! as FakeGrips).services, services), isTrue);
    expect(types[1].gripsFor(services), isNull);
  });
}
```

Create `test/kit/plan_tool_test.dart`:

```dart
// Spec 2a P1, P3: PlanTool and its settings. Two tools whose settings are of
// different types `S` are held in one list and edited through their erased
// fields, under the VM's runtime checks (Review Focus 3).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;

import '../support/code_fixtures.dart';
import '../support/tool_fixtures.dart';

void main() {
  test('PT12 a tool settings field: its word, its value, its store', () {
    final tool = slabTool();
    final stored = <Object>[];
    final fields = tool.settings!
        .fieldsOf(tool.settings!.initial, stored.add, toolId: tool.id);
    expect([for (final f in fields) f.wordId],
        ['property:test.slab.width', 'property:test.slab.finish']);
    expect([for (final f in fields) f.value], [900.5, Finish.oiled]);
    final next = fields[0].commit!(1200.25);
    expect(next, const SlabSettings(width: 1200.25));
    // M-PT12: drop `onCommit: store`: nothing is stored.
    expect(stored, [const SlabSettings(width: 1200.25)]);
    expect(() => fields[1].commit!(Finish.waxed), throwsArgumentError);
    expect(() => fields[0].commit!(299), throwsArgumentError);
    expect(stored, hasLength(1));
    expect(
        () => tool.settings!
            .fieldsOf(const PostSettings(), stored.add, toolId: tool.id),
        throwsArgumentError);
  });

  test('PT13 two settings types in one list of tools', () {
    // Review Focus 3, a positive control: the settings are reached only
    // through the erased PlanToolSettings<Object> and PropertyField.
    final tools = [slabTool(), postTool()];
    final values = <String, Object>{
      for (final t in tools) t.id: t.settings!.initial,
    };
    for (final tool in tools) {
      final fields = tool.settings!.fieldsOf(
          values[tool.id]!, (v) => values[tool.id] = v,
          toolId: tool.id);
      final first = fields.first;
      first.commit!(first.value is bool ? true : 1500.0);
    }
    expect(values, {
      'test.slab': const SlabSettings(width: 1500),
      'test.post': const PostSettings(round: true),
    });
    expect(tools[0].letter, 'S');
    expect(tools[0].needs, {Capability.structure, Capability.geometry});
    expect(tools[1].letter, isNull);
    expect(tools[1].needs, isEmpty);
    expect('${tools[0]}', 'PlanTool(test.slab)');
  });
}
```

Create `test/kit/plan_services_test.dart`:

```dart
// Spec 2a P5: a kit's words at the plan's locale, read live.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

/// A kit's shared cache, written against the barrel alone.
final class Bands implements Disposable {
  int disposed = 0;

  @override
  void dispose() => disposed++;
}

const KitNames names = KitNames({
  'en': {'type:test.slab': 'Slab', 'tool:test.slab': 'Slab'},
  'tr': {'type:test.slab': 'Tezgâh'},
});

void main() {
  test('PT19 the locale, then English, then the id or null', () {
    var locale = const Locale('tr', 'TR');
    final words = KitNamesWords(names, () => locale);
    expect(words.word('type:test.slab'), 'Tezgâh');
    expect(words.word('tool:test.slab'), 'Slab');
    // M-PT19a: `word` answers '' for a missing word.
    expect(words.word('property:test.slab.width'), 'property:test.slab.width');
    expect(words.maybe('property:test.slab.width'), isNull);
    expect(words.maybe('tool:test.slab'), 'Slab');
    // M-PT19b: read the locale once, in the constructor.
    locale = const Locale('de');
    expect(words.locale, const Locale('de'));
    expect(words.word('type:test.slab'), 'Slab');
    expect(identical(words.names, names), isTrue);
  });

  test('PT24 Disposable is exported for kits to implement', () {
    // A premise of the export list, exempt from the mutation rule: without
    // the export this file does not compile.
    final Disposable bands = Bands()..dispose();
    expect((bands as Bands).disposed, 1);
  });
}
```

Create `test/kit/attachment_test.dart`:

```dart
// Spec 2a P3: the attachment value types. A query and an answer never change
// after they are made, and refuse what no provider can use.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

final Transform2 turned =
    Transform2.translation(1520.5, -640.25).multiply(Transform2.rotation(0.6));

AttachmentQuery query({
  Vector2? pointer,
  double capture = 120.5,
  double edgeCapture = 40.25,
  Set<Handle> exclude = const {Handle(5100)},
  Attachment? keep,
}) =>
    AttachmentQuery(
      footprint: const Aabb2.raw(-450.5, -300.25, 450.5, 300.25),
      current: turned,
      pointer: pointer ?? Vector2(1610.75, -580.5),
      capture: capture,
      edgeCapture: edgeCapture,
      mirrored: true,
      mayRotate: false,
      exclude: exclude,
      keep: keep,
    );

Matcher refusedOn(String name) =>
    throwsA(isA<ArgumentError>().having((e) => e.name, 'name', name));

void main() {
  test('PT20 a query copies its pointer and its exclusions', () {
    final pointer = Vector2(1610.75, -580.5);
    final exclude = {const Handle(5100)};
    final q = query(pointer: pointer, exclude: exclude);
    pointer.x = 0;
    exclude.add(const Handle(5200));
    // M-PT20a: keep the caller's vector. M-PT20b: keep the caller's set.
    expect(q.pointer, Vector2(1610.75, -580.5));
    expect(q.exclude, {const Handle(5100)});
    expect(() => q.exclude.add(const Handle(5300)), throwsUnsupportedError);
    expect(q.mirrored, isTrue);
    expect(q.mayRotate, isFalse);
    expect(q.keep, isNull);
  });

  test('PT21 a query refuses a capture it cannot use', () {
    // M-PT21a: drop the capture check. M-PT21b: drop the pointer check.
    expect(() => query(capture: -0.5), refusedOn('capture'));
    expect(() => query(capture: double.nan), refusedOn('capture'));
    expect(() => query(edgeCapture: double.infinity), refusedOn('edgeCapture'));
    expect(() => query(pointer: Vector2(double.nan, 2)), refusedOn('pointer'));
    expect(query(capture: 0, edgeCapture: 0).capture, 0);
  });

  test('PT22 an answer copies its marker and refuses non-finite values', () {
    final marker = Vector2(1702.5, -515.25);
    final a = Attachment(transform: turned, marker: marker, token: 'run 3');
    marker.y = 0;
    // M-PT22a: keep the caller's vector.
    expect(a.marker, Vector2(1702.5, -515.25));
    expect(a.token, 'run 3');
    expect(query(keep: a).keep, same(a));
    // M-PT22b: drop the marker check. M-PT22c: drop the transform check.
    expect(
        () => Attachment(
            transform: turned, marker: Vector2(double.infinity, 1), token: 1),
        refusedOn('marker'));
    expect(
        () => Attachment(
            transform: Transform2(1, 0, 0, 1, double.nan, 0),
            marker: Vector2(1, 1),
            token: 1),
        refusedOn('transform'));
  });
}
```

Create `test/kit/kit_diagnostic_test.dart`:

```dart
// Spec 2a P4: a kit diagnostic is equal by kit, subject, code and message.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

const KitDiagnostic failed = KitDiagnostic(
  kitId: 'test',
  subject: 'test.slab',
  code: KitDiagnosticCode.hookFailed,
  message: 'reach threw',
  error: 'boom',
);

void main() {
  test('PT23 equality sees kit, subject, code and message, not the error', () {
    expect(
        failed,
        const KitDiagnostic(
            kitId: 'test',
            subject: 'test.slab',
            code: KitDiagnosticCode.hookFailed,
            message: 'reach threw',
            error: 'another'));
    expect(
        failed.hashCode,
        const KitDiagnostic(
                kitId: 'test',
                subject: 'test.slab',
                code: KitDiagnosticCode.hookFailed,
                message: 'reach threw')
            .hashCode);
    expect(
        failed,
        isNot(const KitDiagnostic(
            kitId: 'other',
            subject: 'test.slab',
            code: KitDiagnosticCode.hookFailed,
            message: 'reach threw')));
    // M-PT23: drop the subject from ==.
    expect(
        failed,
        isNot(const KitDiagnostic(
            kitId: 'test',
            subject: 'test.post',
            code: KitDiagnosticCode.hookFailed,
            message: 'reach threw')));
    expect(
        failed,
        isNot(const KitDiagnostic(
            kitId: 'test',
            subject: 'test.slab',
            code: KitDiagnosticCode.componentUnreadable,
            message: 'reach threw')));
    expect(
        failed,
        isNot(const KitDiagnostic(
            kitId: 'test',
            subject: 'test.slab',
            code: KitDiagnosticCode.hookFailed,
            message: 'generate threw')));
    expect('$failed', 'hookFailed [test test.slab]: reach threw');
    expect(
        '${const KitDiagnostic(kitId: 'cafe', code: KitDiagnosticCode.kitMissing, message: 'not loaded')}',
        'kitMissing [cafe]: not loaded');
  });
}
```

In `test/kit/plan_kit_test.dart`, grow K1 and add the code-side group (K2-K6 are unchanged):

```diff
--- a/packages/jet_cad_2d_kit/test/kit/plan_kit_test.dart
+++ b/packages/jet_cad_2d_kit/test/kit/plan_kit_test.dart
@@ -1,7 +1,12 @@
 // Spec K5: the PlanKit descriptor's symbol part and its validation.
 import 'package:flutter_test/flutter_test.dart';
+import 'package:jet_cad_2d/jet_cad_2d.dart' show Component;
 import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
 
+import '../support/code_fixtures.dart';
+import '../support/plan_type_fixtures.dart';
+import '../support/tool_fixtures.dart';
+
 List<KitProblemCode> codes(PlanKit kit) =>
     [for (final p in kit.validate()) p.code];
 
@@ -9,6 +14,10 @@ void main() {
   test('K1 a const descriptor with its defaults', () {
     const kit = PlanKit(id: 'sample', version: '0.1.0');
     expect(kit.symbols, isEmpty);
+    expect(kit.types, isEmpty);
+    expect(kit.tools, isEmpty);
+    expect(kit.attachments, isEmpty);
+    expect(kit.propertyIds, isEmpty);
     expect(identical(kit.names, KitNames.empty), isTrue);
     expect(kit.validate(), isEmpty);
   });
@@ -94,4 +103,131 @@ void main() {
     expect(codes(kit), [KitProblemCode.missingEnglish]);
     expect(kit.validate().single.message, contains('tool:sample.wall'));
   });
+
+  group('the code side (spec 2a P1)', () {
+    /// Every word the code kit needs, in English, and some in Turkish.
+    const Map<String, String> english = {
+      'type:test.slab': 'Slab',
+      'type:test.slab.raised': 'Raised slab',
+      'type:test.post': 'Post',
+      'tool:test.slab': 'Slab',
+      'tool:test.post': 'Post',
+      'property:test.slab.width': 'Width',
+      'property:test.slab.turn': 'Turn',
+      'property:test.slab.grade': 'Grade',
+      'property:test.slab.finish': 'Finish',
+      'property:test.slab.finish.oiled': 'Oiled',
+      'property:test.slab.finish.waxed': 'Waxed',
+      'property:test.slab.finish.raw': 'Raw',
+      'property:test.slab.raised': 'Raised',
+      'property:test.slab.label': 'Label',
+      'property:test.slab.area': 'Area',
+      'property:test.slab.flip': 'Flip',
+      'property:test.post.width': 'Width',
+      'property:test.post.shape': 'Shape',
+      'property:test.post.shape.round': 'Round',
+      'property:test.post.shape.square': 'Square',
+      'property:test.post.round': 'Round',
+    };
+
+    PlanKit codeKit({
+      List<PlanType<Component>>? types,
+      List<PlanTool>? tools,
+      Map<String, String> en = english,
+      Map<String, String> tr = const {'type:test.slab': 'Tezgâh'},
+    }) =>
+        PlanKit(
+          id: 'test',
+          version: '0.2.0',
+          types: types ?? [slabType(), postType()],
+          tools: tools ?? [slabTool(), postTool()],
+          names: KitNames({'en': en, 'tr': tr}),
+        );
+
+    test('PT14 a sound code kit validates; its property ids', () {
+      // A positive control for PT15-PT18, and the id list pinned.
+      final kit = codeKit();
+      expect(kit.validate(), isEmpty);
+      // M-PT14: leave a choice's values out of propertyIds (PT17 too).
+      expect(kit.propertyIds, [
+        'test.slab.width',
+        'test.slab.turn',
+        'test.slab.grade',
+        'test.slab.finish',
+        'test.slab.finish.oiled',
+        'test.slab.finish.waxed',
+        'test.slab.finish.raw',
+        'test.slab.raised',
+        'test.slab.label',
+        'test.slab.area',
+        'test.slab.flip',
+        'test.post.width',
+        'test.post.shape',
+        'test.post.shape.round',
+        'test.post.shape.square',
+        'test.slab.width',
+        'test.slab.finish',
+        'test.slab.finish.oiled',
+        'test.slab.finish.raw',
+        'test.post.round',
+      ]);
+    });
+
+    test('PT15 a type or tool id that is not <kit>.<name>', () {
+      for (final id in [
+        'other.slab',
+        'slab',
+        'test.',
+        'test.Slab',
+        'test..slab',
+      ]) {
+        final type = PlanType<Slab>(
+            id: id, fromJson: Slab.fromJson, parametric: LoggingType<Slab>());
+        // M-PT15a: drop the id check. M-PT15b: test `kitOfKey` only
+        // ('test.', 'test.Slab' and 'test..slab' pass).
+        final typeProblems = codeKit(types: [type]).validate();
+        expect([
+          for (final p in typeProblems) p.code
+        ], [
+          KitProblemCode.typeOutsideKit
+        ], reason: id);
+        expect(typeProblems.single.message, contains('"$id"'));
+        expect(codes(codeKit(types: const [], tools: [slabTool(id: id)])),
+            [KitProblemCode.toolOutsideKit],
+            reason: id);
+      }
+    });
+
+    test('PT16 a type or tool id given twice', () {
+      // M-PT16: drop the `seen.add` check.
+      expect(codes(codeKit(types: [slabType(), postType(), slabType()])),
+          [KitProblemCode.duplicateType]);
+      expect(codes(codeKit(tools: [postTool(), slabTool(), postTool()])),
+          [KitProblemCode.duplicateTool]);
+    });
+
+    test('PT17 every word a type, tool or property needs has English', () {
+      for (final wordId in [
+        'type:test.post',
+        'tool:test.slab',
+        'property:test.slab.width',
+        'property:test.slab.finish.waxed',
+        'property:test.post.round',
+      ]) {
+        final kit = codeKit(en: {...english}..remove(wordId));
+        // M-PT17a: drop the declared type and tool words. M-PT17b: drop the
+        // property ids from the needed words.
+        expect(codes(kit), [KitProblemCode.missingEnglish], reason: wordId);
+        expect(kit.validate().single.message, contains('"$wordId"'));
+      }
+    });
+
+    test('PT18 a word missing from English is one problem, not two', () {
+      // The Turkish 'type:test.slab' and the declared type both need the
+      // same English word. M-PT18: report the words loop's need and the
+      // declared one separately.
+      final kit = codeKit(en: {...english}..remove('type:test.slab'));
+      expect(codes(kit), [KitProblemCode.missingEnglish]);
+    });
+  });
 }
```

In `test/model/kit_ids_test.dart`, add I5 at the end of `main`:

```diff
--- a/packages/jet_cad_2d_kit/test/model/kit_ids_test.dart
+++ b/packages/jet_cad_2d_kit/test/model/kit_ids_test.dart
@@ -74,4 +74,29 @@ void main() {
     expect(kitOfKey('architecture.wall'), 'architecture');
     expect(kitOfKey('wall'), 'wall');
   });
+
+  test('I5 a type or tool id is a kit id, then one or more segments', () {
+    for (final id in [
+      'test.slab',
+      'architecture.wall',
+      'restaurant.booth.corner',
+      'a1.b-2',
+    ]) {
+      expect(isCodeId(id), isTrue, reason: id);
+    }
+    for (final id in [
+      'test', // M-I5a: `*` in place of `+` after the kit id
+      'Test.slab',
+      'test.Slab',
+      '2test.slab',
+      'my-kit.slab', // M-I5b: `[a-z0-9-]` for the kit id's characters
+      'test..slab',
+      'test.slab.',
+      'test.-slab',
+      'test.slab_x',
+      'test.slab\n',
+    ]) {
+      expect(isCodeId(id), isFalse, reason: id);
+    }
+  });
 }
```

- [ ] **Step 4: Run them to see them fail.** Run: `cd packages/jet_cad_2d_kit && flutter test test/kit test/model/kit_ids_test.dart`. Expected: the new files and `plan_kit_test.dart` fail to compile (the errors name undefined `PlanType`, `PlanTool`, `KitNamesWords`, `AttachmentQuery`, `KitDiagnostic`, `isCodeId`, and `PlanKit`'s missing `types` parameter); `properties_test.dart` and `sources_test.dart` still pass. Quote one error line per file.

- [ ] **Step 5: The ids and the codes.** Apply to `lib/src/model/kit_ids.dart` and `lib/src/model/kit_problem.dart`:

```diff
--- a/packages/jet_cad_2d_kit/lib/src/model/kit_ids.dart
+++ b/packages/jet_cad_2d_kit/lib/src/model/kit_ids.dart
@@ -6,6 +6,7 @@ final RegExp _kitId = RegExp(r'^[a-z][a-z0-9]*$');
 final RegExp _kind = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
 final RegExp _key =
     RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*(\.[a-z0-9]+(-[a-z0-9]+)*){2,}$');
+final RegExp _codeId = RegExp(r'^[a-z][a-z0-9]*(\.[a-z0-9]+(-[a-z0-9]+)*)+$');
 
 /// Whether [id] is a kit id: a lower-case letter, then lower-case letters
 /// and digits. No dot and no hyphen: it is the first segment of every key,
@@ -20,6 +21,11 @@ bool isKind(String kind) => _kind.hasMatch(kind);
 /// segments, each lower-case letters and digits joined by single hyphens.
 bool isSymbolKey(String key) => _key.hasMatch(key) && isKitId(kitOfKey(key));
 
+/// Whether [id] is a type id or a tool id (spec 2a P1): a kit id, then one
+/// or more dot-separated segments of lower-case letters and digits joined by
+/// single hyphens. `architecture.wall`, `restaurant.booth.corner`.
+bool isCodeId(String id) => _codeId.hasMatch(id);
+
 /// The first dot-separated segment of [id] (a key, a type id or a tool id):
 /// its kit. [id] itself when it holds no dot.
 String kitOfKey(String id) {
--- a/packages/jet_cad_2d_kit/lib/src/model/kit_problem.dart
+++ b/packages/jet_cad_2d_kit/lib/src/model/kit_problem.dart
@@ -1,5 +1,5 @@
-// One problem of a kit (spec K5's PlanKit.validate, K7's conformance): a
-// code tests can assert and a message a person can act on.
+// One problem of a kit (spec K5's PlanKit.validate, K7's conformance, 2a's
+// kit set): a code tests can assert and a message a person can act on.
 //
 // Pure Dart: no Flutter, no dart:io.
 import 'package:meta/meta.dart';
@@ -26,6 +26,16 @@ enum KitProblemCode {
   wordUntranslated,
   wordOrphan,
   localeUndeclared,
+  // The code side and the kit set (spec 2a P4, contract R4): PlanKit.validate
+  // and conformance report the type and tool ones, the plan library's
+  // kit-set validation the others.
+  duplicateKit,
+  duplicateType,
+  duplicateTool,
+  reservedKitId,
+  typeOutsideKit,
+  toolOutsideKit,
+  typePlaceConflict,
 }
 
 @immutable
```

- [ ] **Step 6: Diagnostics, attachment, services.** Create `lib/src/kit/kit_diagnostic.dart` (pure Dart):

```dart
// A kit's runtime diagnostic (spec 2a P4): what the plan library reports
// when a kit's code fails, a kit is missing or newer, a letter is taken or a
// symbol library cannot be used. Unlike a KitProblem, never a refusal: the
// plan goes on.
//
// Pure Dart: no Flutter, no dart:io.
import 'package:meta/meta.dart';

enum KitDiagnosticCode {
  /// A kit's hook threw: a type's, a tool's, a grip provider's, an
  /// attachment provider's or a section's.
  hookFailed,

  /// A rolled-back edit could not be rolled back; the plan is damaged.
  rollbackFailed,

  /// A damaged plan does not encode and decode; it cannot be saved.
  damagedUnsavable,

  /// A component's `fromJson` threw on load; it is kept raw and its object
  /// is locked.
  componentUnreadable,

  /// A tool's letter is already taken, or is F; the tool has none.
  letterTaken,

  /// A symbol attaches to a kind no loaded kit's provider offers.
  attachmentKindUnoffered,

  /// A symbol library cannot be read or decoded; it is skipped.
  libraryUnreadable,

  /// A symbol library holds another kit's id; it is refused.
  libraryKitMismatch,

  /// A `key@N` an earlier kit already gave; the later one is dropped.
  symbolDuplicate,

  /// The plan names a kit the host did not load; its objects are locked.
  kitMissing,

  /// The plan was saved by a newer version of a loaded kit.
  kitNewer,
}

/// One diagnostic: the kit it concerns, the type, tool, library or object it
/// names ([subject], null for the kit itself), its [code], a message a
/// person can act on, and the [error] caught, if any.
///
/// Equal by kit, subject, code and message; the error is not compared.
@immutable
final class KitDiagnostic {
  const KitDiagnostic({
    required this.kitId,
    this.subject,
    required this.code,
    required this.message,
    this.error,
  });

  final String kitId;
  final String? subject;
  final KitDiagnosticCode code;
  final String message;
  final Object? error;

  @override
  bool operator ==(Object other) =>
      other is KitDiagnostic &&
      other.kitId == kitId &&
      other.subject == subject &&
      other.code == code &&
      other.message == message;

  @override
  int get hashCode => Object.hash(kitId, subject, code, message);

  @override
  String toString() =>
      '${code.name} [$kitId${subject == null ? '' : ' $subject'}]: $message';
}
```

Create `lib/src/kit/attachment.dart`:

```dart
// Attachment (spec 2a P3, umbrella A5): a kit's provider offers where a
// symbol may attach (a wall's face, a room's corner); the plan library asks
// every provider of the kinds a symbol's `attachTo` names and keeps the
// answer whose marker is nearest the pointer.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A kit's attachment provider: one target [kind], made once per document
/// from the kit's `attachments` factories.
abstract interface class AttachmentProvider {
  /// A target kind (K2's kind pattern): `wall-face`.
  String get kind;

  /// Where the symbol in [query] attaches, or null for nowhere near. Must
  /// not mutate the document.
  Attachment? attach(AttachmentQuery query);
}

/// What a provider is asked: the symbol, where it is, where the pointer is.
///
/// [pointer] and [exclude] are copied: the query never changes after it is
/// made.
@immutable
final class AttachmentQuery {
  /// Throws [ArgumentError] for a capture or an edge capture that is
  /// negative or not finite, and for a pointer that is not finite.
  AttachmentQuery({
    required this.footprint,
    required this.current,
    required Vector2 pointer,
    required this.capture,
    required this.edgeCapture,
    required this.mirrored,
    required this.mayRotate,
    Set<Handle> exclude = const {},
    this.keep,
  })  : pointer = Vector2.copy(pointer),
        exclude = Set.unmodifiable(exclude) {
    _checkDistance(capture, 'capture');
    _checkDistance(edgeCapture, 'edgeCapture');
    if (!pointer.x.isFinite || !pointer.y.isFinite) {
      throw ArgumentError.value(pointer, 'pointer', 'is not finite');
    }
  }

  /// The symbol's box in its own frame.
  final Aabb2 footprint;

  /// The symbol's transform now (while placing: the ghost's).
  final Transform2 current;

  /// The raw world point under the pointer.
  final Vector2 pointer;

  /// World distances: how far from a target the pointer may be, and how
  /// near an end of a target the symbol may slide.
  final double capture;
  final double edgeCapture;

  /// Whether the symbol is mirrored now.
  final bool mirrored;

  /// False (the `rotate` permission is off): offer only targets the
  /// symbol's current turn already fits.
  final bool mayRotate;

  /// Objects not to attach to: the one being moved.
  final Set<Handle> exclude;

  /// The previous answer, for hysteresis; null at first.
  final Attachment? keep;
}

/// Where a symbol attaches: its new [transform], the world point the plan
/// library draws its marker at, and the provider's own [token] (a face run),
/// which it reads back from [AttachmentQuery.keep].
///
/// [marker] is copied.
@immutable
final class Attachment {
  /// Throws [ArgumentError] for a transform or a marker that is not finite.
  Attachment({
    required this.transform,
    required Vector2 marker,
    required this.token,
  }) : marker = Vector2.copy(marker) {
    final t = transform;
    if (![t.a, t.b, t.c, t.d, t.e, t.f].every((v) => v.isFinite)) {
      throw ArgumentError.value(transform, 'transform', 'is not finite');
    }
    if (!marker.x.isFinite || !marker.y.isFinite) {
      throw ArgumentError.value(marker, 'marker', 'is not finite');
    }
  }

  final Transform2 transform;
  final Vector2 marker;
  final Object token;
}

/// The plan library's registry over every loaded kit's providers.
abstract interface class AttachmentRegistry {
  /// The answer of the providers of [kinds] nearest the pointer, or null.
  Attachment? attach(List<String> kinds, AttachmentQuery query);

  /// The kinds some provider offers.
  Set<String> get kinds;
}

void _checkDistance(double v, String name) {
  if (!v.isFinite || v < 0) {
    throw ArgumentError.value(v, name, 'must be finite and not negative');
  }
}
```

Create `lib/src/kit/plan_services.dart`:

```dart
// The live view a kit's tools, grip providers and attachment providers get
// of one plan (spec 2a P1): one per kit per controller, implemented by the
// plan library. And a kit's words at the plan's locale.
import 'dart:ui' show Locale;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show CameraController;

import '../model/kit_names.dart';
import 'attachment.dart';

/// A kit's words at the plan's current locale (spec 2a P5).
abstract interface class KitWords {
  /// The word [wordId] in the locale, else in English, else [wordId] itself
  /// (a missing word shows its id, never nothing).
  String word(String wordId);

  /// The word [wordId] in the locale, else in English, else null.
  String? maybe(String wordId);

  /// The locale the words are in now.
  Locale get locale;
}

/// [KitWords] over a kit's [names], at the locale [locale] answers each
/// time it is read: a change of the plan's language shows at once.
final class KitNamesWords implements KitWords {
  KitNamesWords(this.names, Locale Function() locale) : _locale = locale;

  final KitNames names;
  final Locale Function() _locale;

  @override
  Locale get locale => _locale();

  @override
  String? maybe(String wordId) => names.word(locale.languageCode, wordId);

  @override
  String word(String wordId) => maybe(wordId) ?? wordId;
}

/// What a kit's `shared` object implements to be released with its
/// document (spec 2a P1, lifetimes).
abstract interface class Disposable {
  void dispose();
}

/// One plan, as a kit's code sees it. Every member reads the current
/// document: a kit's factories run once per document (spec 2a P1,
/// lifetimes), so what they keep never outlives it.
abstract interface class PlanServices {
  /// The current document.
  DraftDocument get document;

  /// Its spatial index.
  SpatialIndex get index;

  /// The camera, for apertures in world units.
  CameraController get camera;

  /// The effective object-snap flag: F3 and the editor's snapping option.
  bool get objectSnap;

  /// Every loaded kit's attachment providers.
  AttachmentRegistry get attachments;

  /// This kit's words at the plan's locale.
  KitWords get words;

  /// The current settings of the tool [toolId] (one of this kit's tools
  /// with settings). Throws [ArgumentError] for another id or an `S` the
  /// settings are not.
  S settingsOf<S extends Object>(String toolId);

  /// This kit's one [T] for the current document: [create] runs on the
  /// first call, later calls return the same instance. A [T] that is a
  /// [Disposable] is disposed with its document. Keyed by (kit, `T`), so two
  /// kits asking for the same type get one each.
  T shared<T extends Object>(T Function(PlanServices) create);
}
```

- [ ] **Step 7: The type and the tool.** Create `lib/src/kit/plan_type.dart`:

```dart
// A kit's parametric type (spec 2a P1): the engine's ParametricType and its
// component factory, wrapped with the type's property specs, colour target,
// grips, title and escape-hatch section.
//
// Covariance: the plan library holds every type as PlanType<Component>. A
// member whose type takes a `T` would fail the VM's covariance check when
// read through that static type, and `catalog.register` would infer
// `T = Component`. So those members are private, and the plan library calls
// only the erased operations below, which run over the class's own `T`, as
// the engine's own registration does.
import 'package:flutter/widgets.dart' show BuildContext, Widget;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ObjectGripProvider;
import 'package:meta/meta.dart';

import '../model/kit_ids.dart';
import 'colour.dart';
import 'plan_services.dart';
import 'properties.dart';

/// A type's escape hatch (umbrella A4): its own panel section over [value],
/// committing a changed copy through [commit], one undo step.
typedef PropertySectionBuilder<T> = Widget Function(
    BuildContext context, T value, void Function(T) commit, KitWords words);

/// Wraps a kit's engine type at the contract's boundary (spec 2a P4, the
/// failure boundary). Implemented by the plan library; [wrap] keeps `T`.
abstract interface class TypeGuard {
  ParametricType<T> wrap<T extends Component>(
      String kitId, String typeId, ParametricType<T> type);
}

@immutable
final class PlanType<T extends Component> {
  const PlanType({
    required this.id,
    required this.fromJson,
    required this.parametric,
    this.grips,
    this.properties = const [],
    PropertySectionBuilder<T>? section,
    String Function(T)? title,
    ColourTarget<T>? colour,
    this.exported = true,
  })  : _section = section,
        _title = title,
        _colour = colour;

  /// `<kit id>.<type>`, equal to the component's codec type id: the
  /// manifest finds the plan's kits by it.
  final String id;

  final ComponentFactory<T> fromJson;
  final ParametricType<T> parametric;

  /// Made once per document (spec 2a P1, lifetimes).
  final ObjectGripProvider Function(PlanServices)? grips;

  /// The panel's fields, in order. Safe to list through
  /// `PlanType<Component>`; use them through [fieldsOf].
  final List<PropertySpec<T>> properties;

  /// False leaves the type's objects out of every export.
  final bool exported;

  final PropertySectionBuilder<T>? _section;
  final String Function(T)? _title;
  final ColourTarget<T>? _colour;

  bool get hasColour => _colour != null;
  bool get hasSection => _section != null;

  /// Registers this type into [catalog] under [id], with `T` kept: through
  /// [guard]'s wrapper when one is given (the plan library's).
  void registerInto(ParametricCatalog catalog, {TypeGuard? guard}) {
    final type = guard == null
        ? parametric
        : guard.wrap<T>(kitOfKey(id), id, parametric);
    catalog.register<T>(id, fromJson, type);
  }

  /// The fields of [group]'s `T`, bound to its current value, each under
  /// `property:<id>.<spec id>`; empty when [group] carries no `T`.
  List<PropertyField> fieldsOf(CommandTarget target, Handle group) {
    final value = target.components.get<T>(group);
    if (value == null) return const [];
    return [
      for (final spec in properties)
        spec.bind(value, wordId: 'property:$id.${spec.id}'),
    ];
  }

  /// The word id of [group]'s section title: `type:<id>`, unless the
  /// type's `title` names another for its current value.
  String titleWordOf(CommandTarget target, Handle group) {
    final value = target.components.get<T>(group);
    final title = _title;
    if (value == null || title == null) return 'type:$id';
    return title(value);
  }

  /// [group]'s swatch; null without a colour target, a `T`, or a swatch.
  String? colourOf(CommandTarget target, Handle group) {
    final value = target.components.get<T>(group);
    final colour = _colour;
    if (value == null || colour == null) return null;
    return colour.read(value);
  }

  /// The one command that gives [group] [swatch] (null clears it); null
  /// without a colour target or a `T`, or when the swatch is already it.
  DraftCommand? recolour(CommandTarget target, Handle group, String? swatch) {
    final value = target.components.get<T>(group);
    final colour = _colour;
    if (value == null || colour == null) return null;
    final next = colour.write(value, swatch);
    if (next == value) return null;
    return SetComponentCommand<T>(group, next);
  }

  /// The one command that commits [input] through [field], one of this
  /// type's fields: bound again to [group]'s current value, so a field
  /// read before another edit never writes back what that edit changed.
  ///
  /// Throws [ArgumentError] when [field] is not one of this type's specs,
  /// [group] carries no `T` or the field is a display, and what the
  /// field's commit throws (spec 2a P3: out of range, disabled).
  DraftCommand commitField(
      CommandTarget target, Handle group, PropertyField field, Object? input) {
    final spec = properties.firstWhere((s) => identical(s, field.spec),
        orElse: () => throw ArgumentError.value(
            field.wordId, 'field', 'is not a field of $id'));
    final value = target.components.get<T>(group);
    if (value == null) {
      throw ArgumentError.value(group, 'group', 'carries no $id');
    }
    final commit = spec.bind(value, wordId: field.wordId).commit;
    if (commit == null) {
      throw ArgumentError.value(field.wordId, 'field', 'is read-only');
    }
    return SetComponentCommand<T>(group, commit(input) as T);
  }

  /// [group]'s escape-hatch section, or null without one or a `T`. Its
  /// commit hands [execute] one `SetComponentCommand<T>`.
  Widget? sectionFor(BuildContext context, CommandTarget target, Handle group,
      void Function(DraftCommand) execute, KitWords words) {
    final value = target.components.get<T>(group);
    final section = _section;
    if (value == null || section == null) return null;
    return section(context, value,
        (next) => execute(SetComponentCommand<T>(group, next)), words);
  }

  /// This type's grip provider over [services], or null without one.
  ObjectGripProvider? gripsFor(PlanServices services) => grips?.call(services);

  @override
  String toString() => 'PlanType($id)';
}
```

Create `lib/src/kit/plan_tool.dart`:

```dart
// A kit's tool (spec 2a P1): a palette entry whose `create` makes the
// Flutter layer's Tool over a plan's services, with optional settings the
// property panel edits while the tool is active (spec 2a P3).
import 'package:flutter/widgets.dart' show IconData;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show Tool;
import 'package:meta/meta.dart';

import 'plan_services.dart';
import 'properties.dart';

/// A tool's settings: one value of `S` per tool and controller, starting at
/// [initial], edited through [specs], read by the tool through
/// `PlanServices.settingsOf`.
@immutable
final class PlanToolSettings<S extends Object> {
  const PlanToolSettings({required this.initial, required this.specs});

  final S initial;
  final List<PropertySpec<S>> specs;

  /// The fields of [value], an `S`, each under
  /// `property:<toolId>.<spec id>`; a field's commit hands the changed
  /// settings to [store] and returns them. Binding throws [ArgumentError]
  /// when [value] is not an `S`.
  List<PropertyField> fieldsOf(Object value, void Function(Object) store,
          {required String toolId}) =>
      [
        for (final spec in specs)
          spec.bind(value,
              wordId: 'property:$toolId.${spec.id}', onCommit: store),
      ];
}

@immutable
final class PlanTool {
  const PlanTool({
    required this.id,
    required this.icon,
    this.letter,
    this.needs = const {},
    this.settings,
    required this.create,
  });

  /// `<kit id>.<tool>`; its word is `tool:<id>`.
  final String id;

  final IconData icon;

  /// A suggested shortcut letter; the plan library gives it unless an
  /// earlier tool took it (spec 2a P2, the keyboard).
  final String? letter;

  /// What the tool's commits need; empty for a tool that only reads. The
  /// palette disables a tool whose needs the document's permissions deny.
  final Set<Capability> needs;

  final PlanToolSettings<Object>? settings;

  /// Made once per document (spec 2a P1, lifetimes).
  final Tool Function(PlanServices) create;

  @override
  String toString() => 'PlanTool($id)';
}
```

- [ ] **Step 8: The descriptor.** Replace `lib/src/kit/plan_kit.dart` with:

```dart
// A kit's descriptor (spec K5, grown by spec 2a P1): its symbols, its
// parametric types, its tools, its attachment providers and its words.
import 'package:jet_cad_2d/jet_cad_2d.dart' show Component;
import 'package:meta/meta.dart';

import '../model/kit_ids.dart';
import '../model/kit_names.dart';
import '../model/kit_problem.dart';
import 'attachment.dart';
import 'plan_services.dart';
import 'plan_tool.dart';
import 'plan_type.dart';
import 'properties.dart';
import 'symbol_library_source.dart';

@immutable
final class PlanKit {
  const PlanKit({
    required this.id,
    required this.version,
    this.symbols = const [],
    this.types = const [],
    this.tools = const [],
    this.attachments = const [],
    this.names = KitNames.empty,
  });

  /// A kit id (K2): the first segment of the kit's keys, type and tool ids.
  final String id;

  /// The kit package's version, for the plan manifest.
  final String version;

  final List<SymbolLibrarySource> symbols;
  final List<PlanType<Component>> types;
  final List<PlanTool> tools;

  /// Made once per document (spec 2a P1, lifetimes).
  final List<AttachmentProvider Function(PlanServices)> attachments;

  final KitNames names;

  /// Every property word id of the kit without its `property:` prefix, in
  /// declaration order: `<type id>.<spec id>` for each type's specs,
  /// `<tool id>.<spec id>` for each tool's settings, and for a choice also
  /// `<owner id>.<spec id>.<value>` per value. Pass it to `conformance`.
  List<String> get propertyIds => [
        for (final type in types) ..._specIds(type.id, type.properties),
        for (final tool in tools)
          if (tool.settings case final settings?)
            ..._specIds(tool.id, settings.specs),
      ];

  /// The descriptor's problems: a bad id, an empty version, a word under
  /// another kit's id or in no known namespace; a type or tool id that is not
  /// `<this kit's id>.<name>` or is repeated; a word with no stored English
  /// missing from English, for every word a type, tool or property needs.
  /// Empty when sound. Problems across kits are the plan library's.
  List<KitProblem> validate() {
    final problems = <KitProblem>[];
    if (!isKitId(id)) {
      problems.add(KitProblem(
          KitProblemCode.badKitId,
          '"$id" is not a kit id: a lower-case letter, then lower-case '
          'letters and digits'));
    }
    if (version.trim().isEmpty) {
      problems.add(KitProblem(
          KitProblemCode.emptyVersion, 'the kit "$id" has no version'));
    }
    // Word ids under this kit that need an English word, in order.
    final needEnglish = <String>{};
    for (final MapEntry(key: locale, value: words) in names.words.entries) {
      for (final wordId in words.keys) {
        final colon = wordId.indexOf(':');
        final namespace = colon < 0 ? '' : wordId.substring(0, colon);
        final rest = wordId.substring(colon + 1);
        var foreign = false;
        switch (namespace) {
          case 'category':
            final slash = rest.indexOf('/');
            foreign = slash < 0 || rest.substring(0, slash) != id;
          case 'symbol' || 'tool' || 'type' || 'property':
            foreign = !rest.contains('.') || kitOfKey(rest) != id;
            if (!foreign && namespace != 'symbol') needEnglish.add(wordId);
          default:
            problems.add(KitProblem(KitProblemCode.unknownWordId,
                '$locale: "$wordId" is in no known namespace'));
        }
        if (foreign) {
          problems.add(KitProblem(KitProblemCode.foreignWordId,
              '$locale: "$wordId" is not under the kit "$id"'));
        }
      }
    }
    bool declared(String what, String declaredId, Set<String> seen,
        KitProblemCode outside, KitProblemCode twice) {
      if (!isCodeId(declaredId) || kitOfKey(declaredId) != id) {
        problems.add(KitProblem(outside,
            'the $what "$declaredId" is not "$id.<name>" (lower-case segments)'));
        return false;
      }
      if (!seen.add(declaredId)) {
        problems.add(KitProblem(twice, 'the $what "$declaredId" is repeated'));
        return false;
      }
      needEnglish.add('$what:$declaredId');
      return true;
    }

    final typeIds = <String>{};
    for (final type in types) {
      if (declared('type', type.id, typeIds, KitProblemCode.typeOutsideKit,
          KitProblemCode.duplicateType)) {
        for (final p in _specIds(type.id, type.properties)) {
          needEnglish.add('property:$p');
        }
      }
    }
    final toolIds = <String>{};
    for (final tool in tools) {
      if (declared('tool', tool.id, toolIds, KitProblemCode.toolOutsideKit,
              KitProblemCode.duplicateTool) &&
          tool.settings != null) {
        for (final p in _specIds(tool.id, tool.settings!.specs)) {
          needEnglish.add('property:$p');
        }
      }
    }
    final english = names.words[KitNames.english] ?? const <String, String>{};
    for (final wordId in needEnglish) {
      if (!english.containsKey(wordId)) {
        problems.add(KitProblem(
            KitProblemCode.missingEnglish, '"$wordId" has no English word'));
      }
    }
    return problems;
  }
}

List<String> _specIds(String owner, List<PropertySpec<Object?>> specs) => [
      for (final spec in specs) ...[
        '$owner.${spec.id}',
        if (spec case ChoiceProperty(:final values))
          for (final v in values)
            '$owner.${spec.id}.${ChoiceProperty.segmentOf(v)}',
      ],
    ];
```

- [ ] **Step 9: The exports.** Apply to `lib/jet_cad_2d_kit.dart`:

```diff
--- a/packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart
+++ b/packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart
@@ -1,14 +1,22 @@
 /// The kit contract of jet_cad_2d plans: the components a plan stores, the
-/// `.jetlib` symbol library format, a kit's words, its symbol sources and
+/// `.jetlib` symbol library format, a kit's words, its symbol sources, its
+/// code side (parametric types, tools, property specs, colour targets,
+/// attachment providers, the services a plan gives them, diagnostics) and
 /// its `PlanKit` descriptor.
 ///
-/// A Flutter library: it reads bundled assets. The model it exports is pure
-/// Dart and is shared with `package:jet_cad_2d_kit/authoring.dart`.
+/// A Flutter library: it reads bundled assets and builds on the Flutter
+/// layer's tools and grips. The model it exports is pure Dart and is shared
+/// with `package:jet_cad_2d_kit/authoring.dart`.
 library;
 
+export 'src/kit/attachment.dart';
 export 'src/kit/bundled_library.dart';
 export 'src/kit/colour.dart';
+export 'src/kit/kit_diagnostic.dart';
 export 'src/kit/plan_kit.dart';
+export 'src/kit/plan_services.dart';
+export 'src/kit/plan_tool.dart';
+export 'src/kit/plan_type.dart';
 export 'src/kit/properties.dart';
 export 'src/kit/symbol_library_source.dart';
 export 'src/model/model.dart';
```

- [ ] **Step 10: Run the tests.** Run: `cd packages/jet_cad_2d_kit && flutter test test/kit test/model test/invariants`. Expected: `All tests passed!`.

- [ ] **Step 11: The CHANGELOG.** Append to the `## 0.1.0` list of `CHANGELOG.md`:

```markdown
- The code side: `PlanType`, `PropertySectionBuilder`, `TypeGuard`,
  `PlanTool`, `PlanToolSettings`, `PlanServices`, `KitWords`,
  `KitNamesWords`, `Disposable`, the attachment types and `KitDiagnostic`.
  `PlanKit` gains `types`, `tools`, `attachments` and `propertyIds`, and
  `validate` checks them; seven `KitProblemCode`s for the code side and the
  kit set; `isCodeId`. The contract depends on `jet_cad_2d_flutter`.
```

- [ ] **Step 12: The gate.** Run, one at a time: `cd packages/jet_cad_2d_kit && dart format .`, then `flutter test`, `flutter analyze`, `dart format --output=none --set-exit-if-changed .`; from the repository root, `dart run tool/ci/check_kit_deps.dart`. All exit 0; quote `flutter test`'s last line. Then `git status --short`: only this task's files (no `analysis_options.yaml`).

- [ ] **Step 13: Commit.**

```bash
git add packages/jet_cad_2d_kit/pubspec.yaml packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart packages/jet_cad_2d_kit/lib/src/kit/plan_type.dart packages/jet_cad_2d_kit/lib/src/kit/plan_tool.dart packages/jet_cad_2d_kit/lib/src/kit/plan_services.dart packages/jet_cad_2d_kit/lib/src/kit/attachment.dart packages/jet_cad_2d_kit/lib/src/kit/kit_diagnostic.dart packages/jet_cad_2d_kit/lib/src/kit/plan_kit.dart packages/jet_cad_2d_kit/lib/src/model/kit_ids.dart packages/jet_cad_2d_kit/lib/src/model/kit_problem.dart packages/jet_cad_2d_kit/CHANGELOG.md packages/jet_cad_2d_kit/test/support/plan_type_fixtures.dart packages/jet_cad_2d_kit/test/support/tool_fixtures.dart packages/jet_cad_2d_kit/test/kit/plan_type_test.dart packages/jet_cad_2d_kit/test/kit/plan_tool_test.dart packages/jet_cad_2d_kit/test/kit/plan_services_test.dart packages/jet_cad_2d_kit/test/kit/attachment_test.dart packages/jet_cad_2d_kit/test/kit/kit_diagnostic_test.dart packages/jet_cad_2d_kit/test/kit/plan_kit_test.dart packages/jet_cad_2d_kit/test/model/kit_ids_test.dart
git commit -m "$(cat <<'EOF'
feat(kit): the contract's code side, PlanType to PlanKit (2a P1, P3, P4)

PlanType wraps a kit's ParametricType and component factory with its
property specs, colour target, grips, title and section, and offers only
erased operations over its own T, so two kits' types of different T
register, edit, recolour and show fields together. PlanTool, its
settings, PlanServices, KitWords over KitNames, TypeGuard, Disposable,
the attachment value types and KitDiagnostic complete the code side.
PlanKit gains types, tools and attachments and validates their ids and
English words; KitProblemCode gains the seven code-side and kit-set codes.
The contract now depends on jet_cad_2d_flutter.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 14: Mutation check.** On the committed files only, as in Task 3 (apply, run the named test from `packages/jet_cad_2d_kit`, see it red and quote the failing line, `git checkout -- <file>`, `git diff --quiet -- <file>`). Every one below was seen red against this code before the task was written. PT8, PT13, PT14's `validate()` line and PT24 are positive controls or premises, exempt. M-PT1 goes red inside the fixture (`UnregisteredComponentError(Slab)`: the slab's store is keyed by `Component`), which is the defect itself.

- **M-PT1** (`lib/src/kit/plan_type.dart`). Replace

  ```dart
  catalog.register<T>(id, fromJson, type);
  ```

  with

  ```dart
  catalog.register<Component>(id, fromJson, type);
  ```

  Run `flutter test test/kit/plan_type_test.dart --plain-name 'PT1 '`: red.

- **M-PT2** (`lib/src/kit/plan_type.dart`). Replace

  ```dart
      final type = guard == null
          ? parametric
          : guard.wrap<T>(kitOfKey(id), id, parametric);
  ```

  with

  ```dart
      guard?.wrap<T>(kitOfKey(id), id, parametric);
      final type = parametric;
  ```

  Run `flutter test test/kit/plan_type_test.dart --plain-name 'PT2 '`: red.

- **M-PT3** (`lib/src/kit/plan_type.dart`). Replace

  ```dart
  wordId: 'property:$id.${spec.id}'
  ```

  with

  ```dart
  wordId: 'property:${spec.id}'
  ```

  Run `flutter test test/kit/plan_type_test.dart --plain-name 'PT3 '`: red.

- **M-PT4** (`lib/src/kit/plan_type.dart`). Replace

  ```dart
  return SetComponentCommand<T>(group, commit(input) as T);
  ```

  with

  ```dart
  return SetComponentCommand<Component>(group, commit(input)! as Component);
  ```

  Run `flutter test test/kit/plan_type_test.dart --plain-name 'PT4 '`: red.

- **M-PT5** (`lib/src/kit/plan_type.dart`). Replace

  ```dart
  final commit = spec.bind(value, wordId: field.wordId).commit;
  ```

  with

  ```dart
  final commit = field.commit;
  ```

  Run `flutter test test/kit/plan_type_test.dart --plain-name 'PT5 '`: red.

- **M-PT6** (`lib/src/kit/plan_type.dart`). Replace

  ```dart
  identical(s, field.spec)
  ```

  with

  ```dart
  s.id == field.spec.id
  ```

  Run `flutter test test/kit/plan_type_test.dart --plain-name 'PT6 '`: red.

- **M-PT7** (`lib/src/kit/plan_type.dart`). Replace

  ```dart
  if (next == value) return null;
  ```

  with

  ```dart
  // (nothing: the text is deleted)
  ```

  Run `flutter test test/kit/plan_type_test.dart --plain-name 'PT7 '`: red.

- **M-PT9** (`lib/src/kit/plan_type.dart`). Replace

  ```dart
  return title(value);
  ```

  with

  ```dart
  return 'type:$id';
  ```

  Run `flutter test test/kit/plan_type_test.dart --plain-name 'PT9 '`: red.

- **M-PT10** (`lib/src/kit/plan_type.dart`). Replace

  ```dart
  execute(SetComponentCommand<T>(group, next))
  ```

  with

  ```dart
  execute(SetComponentCommand<Component>(group, next))
  ```

  Run `flutter test test/kit/plan_type_test.dart --plain-name 'PT10 '`: red.

- **M-PT11** (`lib/src/kit/plan_type.dart`). Replace

  ```dart
  => grips?.call(services);
  ```

  with

  ```dart
  => null;
  ```

  Run `flutter test test/kit/plan_type_test.dart --plain-name 'PT11 '`: red.

- **M-PT12** (`lib/src/kit/plan_tool.dart`). Replace

  ```dart
  wordId: 'property:$toolId.${spec.id}', onCommit: store),
  ```

  with

  ```dart
  wordId: 'property:$toolId.${spec.id}'),
  ```

  Run `flutter test test/kit/plan_tool_test.dart --plain-name 'PT12 '`: red.

- **M-PT14** (`lib/src/kit/plan_kit.dart`). Replace

  ```dart
          if (spec case ChoiceProperty(:final values))
            for (final v in values)
              '$owner.${spec.id}.${ChoiceProperty.segmentOf(v)}',
  ```

  with

  ```dart
  // (nothing: the text is deleted)
  ```

  Run `flutter test test/kit/plan_kit_test.dart --plain-name 'PT14 '`: red.

- **M-PT15a** (`lib/src/kit/plan_kit.dart`). Replace

  ```dart
  if (!isCodeId(declaredId) || kitOfKey(declaredId) != id) {
  ```

  with

  ```dart
  if (false) {
  ```

  Run `flutter test test/kit/plan_kit_test.dart --plain-name 'PT15 '`: red.

- **M-PT15b** (`lib/src/kit/plan_kit.dart`). Replace

  ```dart
  if (!isCodeId(declaredId) || kitOfKey(declaredId) != id) {
  ```

  with

  ```dart
  if (kitOfKey(declaredId) != id) {
  ```

  Run `flutter test test/kit/plan_kit_test.dart --plain-name 'PT15 '`: red.

- **M-PT16** (`lib/src/kit/plan_kit.dart`). Replace

  ```dart
  if (!seen.add(declaredId)) {
  ```

  with

  ```dart
  if (false) {
  ```

  Run `flutter test test/kit/plan_kit_test.dart --plain-name 'PT16 '`: red.

- **M-PT17a** (`lib/src/kit/plan_kit.dart`). Replace

  ```dart
        needEnglish.add('$what:$declaredId');
  ```

  with

  ```dart
  // (nothing: the text is deleted)
  ```

  Run `flutter test test/kit/plan_kit_test.dart --plain-name 'PT17 '`: red.

- **M-PT17b** (`lib/src/kit/plan_kit.dart`). Replace

  ```dart
          for (final p in _specIds(type.id, type.properties)) {
            needEnglish.add('property:$p');
          }
  ```

  with

  ```dart
  // (nothing: the text is deleted)
  ```

  Run `flutter test test/kit/plan_kit_test.dart --plain-name 'PT17 '`: red.

- **M-PT18** (`lib/src/kit/plan_kit.dart`). Replace

  ```dart
  final needEnglish = <String>{};
  ```

  with

  ```dart
  final needEnglish = <String>[];
  ```

  Run `flutter test test/kit/plan_kit_test.dart --plain-name 'PT18 '`: red.

- **M-PT19a** (`lib/src/kit/plan_services.dart`). Replace

  ```dart
  String word(String wordId) => maybe(wordId) ?? wordId;
  ```

  with

  ```dart
  String word(String wordId) => maybe(wordId) ?? '';
  ```

  Run `flutter test test/kit/plan_services_test.dart --plain-name 'PT19 '`: red.

- **M-PT19b** (`lib/src/kit/plan_services.dart`). Replace

  ```dart
    Locale get locale => _locale();
  ```

  with

  ```dart
    late final Locale locale = _locale();
  ```

  Run `flutter test test/kit/plan_services_test.dart --plain-name 'PT19 '`: red.

- **M-PT20a** (`lib/src/kit/attachment.dart`). Replace

  ```dart
    })  : pointer = Vector2.copy(pointer),
  ```

  with

  ```dart
    })  : pointer = pointer,
  ```

  Run `flutter test test/kit/attachment_test.dart --plain-name 'PT20 '`: red.

- **M-PT20b** (`lib/src/kit/attachment.dart`). Replace

  ```dart
  exclude = Set.unmodifiable(exclude) {
  ```

  with

  ```dart
  exclude = exclude {
  ```

  Run `flutter test test/kit/attachment_test.dart --plain-name 'PT20 '`: red.

- **M-PT21a** (`lib/src/kit/attachment.dart`). Replace

  ```dart
      _checkDistance(capture, 'capture');
  ```

  with

  ```dart
  // (nothing: the text is deleted)
  ```

  Run `flutter test test/kit/attachment_test.dart --plain-name 'PT21 '`: red.

- **M-PT21b** (`lib/src/kit/attachment.dart`). Replace

  ```dart
      if (!pointer.x.isFinite || !pointer.y.isFinite) {
  ```

  with

  ```dart
      if (false) {
  ```

  Run `flutter test test/kit/attachment_test.dart --plain-name 'PT21 '`: red.

- **M-PT22a** (`lib/src/kit/attachment.dart`). Replace

  ```dart
    }) : marker = Vector2.copy(marker) {
  ```

  with

  ```dart
    }) : marker = marker {
  ```

  Run `flutter test test/kit/attachment_test.dart --plain-name 'PT22 '`: red.

- **M-PT22b** (`lib/src/kit/attachment.dart`). Replace

  ```dart
      if (!marker.x.isFinite || !marker.y.isFinite) {
  ```

  with

  ```dart
      if (false) {
  ```

  Run `flutter test test/kit/attachment_test.dart --plain-name 'PT22 '`: red.

- **M-PT22c** (`lib/src/kit/attachment.dart`). Replace

  ```dart
      if (![t.a, t.b, t.c, t.d, t.e, t.f].every((v) => v.isFinite)) {
  ```

  with

  ```dart
      if (false) {
  ```

  Run `flutter test test/kit/attachment_test.dart --plain-name 'PT22 '`: red.

- **M-PT23** (`lib/src/kit/kit_diagnostic.dart`). Replace

  ```dart
        other.subject == subject &&
  ```

  with

  ```dart
  // (nothing: the text is deleted)
  ```

  Run `flutter test test/kit/kit_diagnostic_test.dart --plain-name 'PT23 '`: red.

- **M-I5a** (`lib/src/model/kit_ids.dart`). Replace

  ```dart
  (\.[a-z0-9]+(-[a-z0-9]+)*)+$');
  ```

  with

  ```dart
  (\.[a-z0-9]+(-[a-z0-9]+)*)*$');
  ```

  Run `flutter test test/model/kit_ids_test.dart --plain-name 'I5 '`: red.

- **M-I5b** (`lib/src/model/kit_ids.dart`). Replace

  ```dart
  _codeId = RegExp(r'^[a-z][a-z0-9]*(
  ```

  with

  ```dart
  _codeId = RegExp(r'^[a-z][a-z0-9-]*(
  ```

  Run `flutter test test/model/kit_ids_test.dart --plain-name 'I5 '`: red.

#### Interface problem

Resolved by controller ruling R-e (`PlanToolSettings.fieldsOf(value, store, {required String toolId})`); the additions this task makes (`PropertySpec.bind`, `ChoiceProperty.segmentOf`, `PlanType`'s public fields, `PlanKit.propertyIds`, `isCodeId`, `KitNamesWords.names`, `AttachmentQuery`'s required `mirrored`/`mayRotate`) and `Disposable` (R-d) are listed in the Shared interfaces.

---

