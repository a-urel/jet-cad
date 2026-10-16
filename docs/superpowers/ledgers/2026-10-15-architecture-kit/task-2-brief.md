### Task 2: Object views for properties and sections; hidden fields (spec C1.1, C1.7)

**Files:**
- Modify (`packages/jet_cad_2d_kit/`): `lib/src/kit/properties.dart` (`PlanObject`, `DocumentPlanObject`, `visible`, `bind(object:)`, `LengthProperty.range`, `TextDisplay`, `PropertyField.visible`), `lib/src/kit/plan_type.dart` (`PlanSection`, the builder, `fieldsOf`/`commitField`/`sectionFor` over `DraftDocument`), `lib/src/kit/plan_kit.dart` (`settingsNeedObject`), `lib/src/model/kit_problem.dart` (one code), `lib/src/model/model.dart` (one export), `lib/src/kit/plan_services.dart` (`KitWords implements PlanWords`); tests `test/kit/plan_type_test.dart` (PT10's builder; PT3-PT6's calls take the words), `test/kit/example_code_test.dart` (its calls take the words); `test/support/plan_type_fixtures.dart` is unchanged (Step 3.5)
- Create (`packages/jet_cad_2d_kit/`): `lib/src/model/plan_words.dart` (`PlanWords`, ruling R-P7), `test/kit/object_view_test.dart`
- Modify (`packages/jet_cad_2d_plan/`): `lib/src/panels/plan_property_panel.dart`; test `test/controller/covariance_test.dart` (its calls take the words); test support `test/support/panel_kits.dart` (the disc's section), `test/support/test_kit.dart` (the slab's section), `test/support/throwing_kit.dart` (three hooks)
- Create (`packages/jet_cad_2d_plan/`): `test/support/object_kit.dart`, `test/panels/object_view_panel_test.dart`
- Modify: `docs/kits.md` (§10.2's `section` row, §10.3's table), `docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md` (a new `## Amendments` section), `docs/superpowers/specs/2026-10-13-kit-contract-design.md` (one line in Task 1's section)

**Interfaces:**
- Consumes:
  - Task 1: nothing (independent).
  - Engine: `DraftDocument`, `Handle`, `Transform2`, `DocumentTree.accumulatedTransform` (`jet_cad_2d/lib/src/document/tree.dart:299`), `EntityStore.liveSlots`/`ownerAt`/`kindAt`/`textAt` (`store/entity_store.dart:341-352`), `Generated.text` (`parametric/parametric_system.dart:305`), `textPayload` (`document/drafting.dart:131`).
  - Contract today: `PropertySpec` and its kinds (`properties.dart:41-321`), `_BoundField` (`:349-389`), `PlanType.fieldsOf`/`commitField`/`sectionFor` (`plan_type.dart:88-157`), `PlanKit.validate` (`plan_kit.dart:60-139`), `KitProblemCode` (`model/kit_problem.dart:7-43`).
  - Plan library today: the panel's `_fieldsOrNull` (`plan_property_panel.dart:330-357`), `_textOf` (`:383-404`), `_parse` (`:408-445`), `_row` (`:704-763`), `_settingsSection` (`:793-803`), `_objectSection` (`:817-845`); `PlanController.servicesOf` (`plan_controller.dart:2141`).
- Produces (Shared interfaces, exact):

```dart
// lib/src/kit/properties.dart
abstract interface class PlanObject {
  DraftDocument get document;
  Handle get handle;
  Transform2 get world; // document.tree.accumulatedTransform(handle)
  PlanWords get words;  // the owning kit's words at the plan's locale (rulings R-P4, R-P7)
}
final class DocumentPlanObject implements PlanObject {
  DocumentPlanObject(this.document, this.handle, this.words); // PlanWords words; world computed on first read
}
// lib/src/model/plan_words.dart (ruling R-P7; pure Dart, exported by both libraries)
abstract interface class PlanWords {
  String word(String wordId);
  String? maybe(String wordId);
  // Task 3 adds: String text(String id, [Map<String, Object> args = const {}]); String get decimalSeparator;
}
// lib/src/kit/plan_services.dart
abstract interface class KitWords implements PlanWords { Locale get locale; } // word and maybe now inherited
sealed class PropertySpec<T> {
  final bool Function(T)? visible;                // every kind's constructor takes it
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit, PlanObject? object});
}
final class LengthProperty<T> extends PropertySpec<T> {
  final (double, double)? Function(T value, PlanObject object)? range; // null result refuses every value
}
final class TextDisplay<T> extends PropertySpec<T> {
  TextDisplay({required String id, required String? Function(T value, PlanObject object) read,
      bool Function(T)? enabled, bool Function(T)? visible, PlanGate? gate});
}
abstract interface class PropertyField {
  bool get visible; // spec.visible(owner), and false for a TextDisplay reading null
}
// lib/src/kit/plan_type.dart
typedef PropertySectionBuilder<T> = Widget Function(BuildContext context, PlanSection<T> section);
@immutable final class PlanSection<T> {
  const PlanSection({required this.value, required this.commit, required this.words,
      required this.object, required this.services});
  final T value; final void Function(T next) commit; final KitWords words;
  final PlanObject object; final PlanServices services;
}
List<PropertyField> fieldsOf(DraftDocument document, Handle group, PlanWords words);
DraftCommand commitField(DraftDocument document, Handle group, PropertyField field, Object? input,
    PlanWords words); // a KitWords is passed
Widget? sectionFor(BuildContext context, DraftDocument document, Handle group,
    void Function(DraftCommand) execute, KitWords words, PlanServices services);
// lib/src/model/kit_problem.dart
enum KitProblemCode { /* existing */ settingsNeedObject }  // Task 3 adds placeholderMismatch after it
```

  Also (contract-internal, not a shared name; see the plan decision): `@internal bool get needsObject` on `PropertySpec`.

**Appendix A rows closed:** D-41 (`PropertySectionBuilder` without handle or services: the builder takes a `PlanSection` with the object and the services). D-46's contract half (the `TextDisplay` kind and `ActionProperty` exercised through a test kit's type; the real kit's half is Task 27). Old test files: none.

Plan decisions:
- **The object carries its kit's words (binding rulings R-P4, R-P7).** `PlanObject.words` is the owning kit's words at the plan's locale: the dimension's axes line needs the UI separator and its End lines are `text:` words (Task 21), which `TextDisplay.read(T, PlanObject)` could not reach otherwise. It is typed `PlanWords`, a pure interface in the model (`lib/src/model/plan_words.dart`), because `KitWords` lives in `plan_services.dart`, which imports `dart:ui` and Flutter (`:5-7`): `properties.dart` imports only `plan_words.dart`, so the 2a purity test P9 (`test/invariants/purity_test.dart:36-43`) stays as it is, and P1 walks the new model file. `KitWords` becomes `KitWords implements PlanWords` (its `word` and `maybe` move up; `locale` stays), so every `KitWords` is passed where a `PlanWords` is taken. In this task `PlanWords` holds `word` and `maybe`; Task 3 adds `text` and `decimalSeparator` to it. `fieldsOf` and `commitField` take the words to build the object; `sectionFor` builds it with the `words` it already receives; the panel passes the kit's services' words (`c.servicesOf(kit).words`, what it passes to `sectionFor` today) to all three.
- **Why `needsObject`.** `PlanKit.validate` must refuse a `TextDisplay` or a `range` in a tool's settings, but the settings' specs are held as `PropertySpec<Object>`, and reading `range` (a member typed over `T`) through that type throws a `TypeError` (the covariance note, `properties.dart:36-40`). A getter declared on the spec reads its own `range` with its own `T`, so it is safe. It is marked `@internal` (`package:meta`, already a dependency and on the purity allow-list): only the contract's `validate` calls it, so it is no shared name. PO-validate's covariance case pins why it exists (M-PO-cov).
- **Binding without an object.** A `TextDisplay`, or a `LengthProperty` with a `range`, bound with `object: null` is an `ArgumentError` naming the word. `validate` keeps such a spec out of every tool's settings, and the plan library refuses an invalid kit (`validateKitSet`, `kits/kit_set.dart:80-82`), so the panel never reaches it.
- **When each hook runs (A9).** `visible` and a `TextDisplay`'s `read` run inside `bind`, so the panel's existing boundary around binding (`_fieldsOrNull`, `plan_property_panel.dart:337-341`) catches them: a throw is the "section failed" box and one `hookFailed`. A `range` runs at the commit, with the constant `min`/`max` (as the old panel's `_valueOk` checked the position at commit, `jet_cad_floor_plan/lib/src/selection_panel.dart:425-433`), so the panel's `_guarded` (`:497-525`) catches it: an `ArgumentError` (out of range, or a null range) is a silent refusal; any other throw is one `hookFailed`.
- **A range is inclusive**, as `min`/`max` are and as today's position check is (`value >= 0 && value <= l`, `selection_panel.dart:432`). Strict bounds (wall thickness, opening width) stay in `write` (spec C1.1).
- **Hidden rows.** A field whose `visible` is false takes no row, in the object's section and in a tool's settings. An `ActionProperty` whose `gate` the permissions refuse takes no row either, in an object's section (C1.7; today S-11). The other kinds keep 2a's rule: a refused gate is read-only. No test kit has a gated action today (grep: `slab.flip`, `box.swap` and `boom.grow` carry no gate), so no existing test sees the change.
- **`section_boundary.dart` is unchanged.** It calls a closure (`KitSectionBoundary.builder`); the panel's closure now passes the services (`c.servicesOf(kit)`) to `sectionFor`.
- **The test kit.** The plan's existing kits keep their field lists (many tests count on them); the object views get their own kit, `view` (`test/support/object_kit.dart`): `view.rail`, a rail whose generated TEXT child carries its label, with a `TextDisplay` of that child and one of its world turn; `view.bead`, which sits on a host rail, with a position `range` read from the host's component, a `door` toggle and a `flip` action `visible` for doors and gated by `reshape`. The throwing kit gains the three new hooks (`display`, `range`, `visible`) on `boom.block`, for the failure boundary (spec C2).
- **CHANGELOG:** Task 29.

- [ ] **Step 1: Precondition.** Task 1 is committed (`git log --oneline -1` names it). Run `cd packages/jet_cad_2d_kit && flutter test test/kit/` and `cd packages/jet_cad_2d_plan && flutter test test/panels/property_panel_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 2: The failing contract tests.** Create `packages/jet_cad_2d_kit/test/kit/object_view_test.dart`:

```dart
// Spec 3a C1.1, C1.7: the object a property or a section is shown for
// (PlanObject), the read-only text line (TextDisplay), a length's range
// read from the object, hidden fields (visible), the section's context
// (PlanSection), and PlanKit.validate's refusal of an object-reading spec
// in a tool's settings. Every object sits in a turned group off the
// origin; one sits in a nested group, so its own transform is not its
// world.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../support/code_fixtures.dart';
import '../support/plan_type_fixtures.dart';

final class _Services implements PlanServices {
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Matcher refusedOn(String name) =>
    throwsA(isA<ArgumentError>().having((e) => e.name, 'name', name));

/// The kit's words, in German.
final KitWords words = KitNamesWords(
    const KitNames({
      'en': {'type:test.slab': 'Slab'},
      'de': {'type:test.slab': 'Platte'},
    }),
    () => const Locale('de'));

/// The post's width read from the document through the object: the range
/// a slab's width may take beside it. Null when the document holds no post
/// at [hPost].
(double, double)? besidePost(Slab s, PlanObject o) {
  final post = o.document.components.get<Post>(hPost);
  return post == null ? null : (post.width, post.width * 4);
}

/// The slab's world turn in whole degrees, or null when it is not turned.
String? turnOf(Slab s, PlanObject o) {
  final w = o.world;
  final degrees = math.atan2(w.b, w.a) * 180 / math.pi;
  return degrees.abs() < 1e-9 ? null : '${degrees.round()}°';
}

List<PropertySpec<Slab>> viewSpecs() => [
      LengthProperty<Slab>(
          id: 'width',
          read: (s) => s.width,
          write: (s, v) => s.copyWith(width: v),
          min: 300,
          max: 4800,
          range: besidePost),
      TextDisplay<Slab>(id: 'turn', read: turnOf),
      TextDisplay<Slab>(
          id: 'owner', read: (s, o) => '${o.handle.value}: ${s.label}'),
      // R-P4: the kit's words through the object, as the dimension's End
      // lines read theirs (Task 3 adds the separator's case, PO-words-separator).
      TextDisplay<Slab>(
          id: 'named', read: (s, o) => o.words.word('type:test.slab')),
      ActionProperty<Slab>(
          id: 'flip',
          apply: (s) => s.copyWith(flipped: !s.flipped),
          visible: (s) => s.raised,
          gate: PlanGate.reshape),
    ];

PlanType<Slab> viewType({PropertySectionBuilder<Slab>? section}) =>
    PlanType<Slab>(
        id: Slab.id,
        fromJson: Slab.fromJson,
        parametric: LoggingType<Slab>(),
        properties: viewSpecs(),
        section: section);

void main() {
  group('PlanObject', () {
    test(
        'PO-object the document, the handle, and the world: the accumulated '
        'transform of a nested group, read once', () {
      final (:doc, catalog: _) = objectDocument([slabType(), postType()]);
      addTearDown(doc.dispose);
      const inner = Handle(4310);
      final local = Transform2.translation(-120.5, 75.25)
          .multiply(Transform2.rotation(0.3));
      doc.commands.execute(AddNodeCommand(GroupNode(
          handle: inner, parent: hBare, transform: local, children: const [])));
      final o = DocumentPlanObject(doc, inner, words);
      expect(identical(o.document, doc), isTrue);
      expect(o.handle, inner);
      // M-PO-object-words: DocumentPlanObject keeps no words of its own.
      expect(identical(o.words, words), isTrue);
      // M-PO-world: `world` reads the node's own transform: `local`, not
      // translation(400.5, 300.25) · local.
      final want =
          Transform2.translation(400.5, 300.25).multiply(local).toJson();
      for (var i = 0; i < 6; i++) {
        expect(o.world.toJson()[i], closeTo(want[i], 1e-9), reason: '$i');
      }
      expect(identical(o.world, o.world), isTrue, reason: 'computed once');
    });
  });

  group('the bound field', () {
    // A post 600 wide: a slab beside it may be 600 to 2400.
    final (:doc, catalog: _) = objectDocument([slabType(), postType()],
        post: const Post(width: 600));
    tearDownAll(doc.dispose);
    final slabObject = DocumentPlanObject(doc, hSlab, words);
    PropertyField bound(String id, {Slab owner = const Slab()}) =>
        viewSpecs().firstWhere((s) => s.id == id).bind(owner,
            wordId: 'property:test.slab.$id', object: slabObject);

    test(
        'PO-display a text display: its value is what read gives for the '
        'value and the object; no commit; a null read hides it', () {
      final owner = bound('owner');
      expect(owner.value, '${hSlab.value}: Bar top');
      expect(owner.commit, isNull);
      expect(owner.visible, isTrue);
      // slabAt is turned π/7 (25.7°).
      final turn = bound('turn');
      expect(turn.value, '26°');
      expect(turn.visible, isTrue);
      // An unturned object: the line is omitted. M-PO-null: a null read
      // leaves the field visible.
      final bare = viewSpecs()
          .firstWhere((s) => s.id == 'turn')
          .bind(const Slab(),
              wordId: 'w', object: DocumentPlanObject(doc, hBare, words));
      expect(bare.value, isNull);
      expect(bare.visible, isFalse);
    });

    test('PO-display-no-object a text display bound without an object', () {
      final spec = viewSpecs().firstWhere((s) => s.id == 'owner');
      // M-PO-no-object: `read(owner, object!)` (a TypeError, not a refusal).
      expect(() => spec.bind(const Slab(), wordId: 'property:test.slab.owner'),
          refusedOn('object'));
      final ranged = viewSpecs().firstWhere((s) => s.id == 'width');
      expect(() => ranged.bind(const Slab(), wordId: 'property:test.slab.width'),
          refusedOn('object'));
    });

    test(
        'PO-range the range read from the object, inclusive, with the '
        'constant bounds; a null range refuses every value', () {
      expect(doc.components.get<Post>(hPost)!.width, 600,
          reason: 'premise: the post given');
      final f = bound('width');
      expect(f.commit!(600), const Slab().copyWith(width: 600));
      expect(f.commit!(2400), const Slab().copyWith(width: 2400));
      expect(f.commit!(1875.5), const Slab().copyWith(width: 1875.5));
      // M-PO-range: drop the range check (599 and 2400.5 pass min/max).
      expect(() => f.commit!(599), refusedOn('width'));
      expect(() => f.commit!(2400.5), refusedOn('width'));
      // The constant max still holds inside a wider range.
      expect(() => f.commit!(4800.5), refusedOn('width'));
      // A document with no post: the range is null, every value refused.
      // M-PO-range-null: a null range read as "unbounded".
      final (doc: lone, catalog: _) =
          objectDocument([slabType(), postType()], post: const Post(width: 600));
      addTearDown(lone.dispose);
      lone.commands.execute(RemoveNodeCommand(hPost));
      expect(lone.components.get<Post>(hPost), isNull,
          reason: 'premise: the post is gone with its node');
      final none = viewSpecs().firstWhere((s) => s.id == 'width').bind(
          const Slab(),
          wordId: 'property:test.slab.width',
          object: DocumentPlanObject(lone, hSlab, words));
      for (final v in [300.0, 600.0, 1250.5, 4800.0]) {
        expect(() => none.commit!(v), refusedOn('width'), reason: '$v');
      }
    });

    test(
        'PO-visible visible over the value: a raised slab shows its flip, a '
        'flat one hides it; a spec without it is visible', () {
      // M-PO-visible: `_BoundField` ignores the spec's visible.
      expect(bound('flip').visible, isTrue);
      expect(bound('flip', owner: const Slab(raised: false)).visible, isFalse);
      expect(bound('width').visible, isTrue);
      // Every kind takes it.
      final settings = LengthProperty<Slab>(
          id: 'depth',
          read: (s) => s.depth,
          write: (s, v) => s,
          visible: (s) => !s.raised);
      expect(settings.bind(const Slab(), wordId: 'w').visible, isFalse);
      expect(settings.bind(const Slab(raised: false), wordId: 'w').visible,
          isTrue);
    });
  });

  group('PlanType over the object', () {
    test(
        'PO-fields fieldsOf binds every spec to the object it was asked for, '
        'and commitField checks the range against the document now', () {
      final List<PlanType<Component>> types = [viewType(), postType()];
      final (:doc, catalog: _) =
          objectDocument(types, post: const Post(width: 600));
      addTearDown(doc.dispose);
      final fields = types[0].fieldsOf(doc, hSlab, words);
      // M-PO-fields: fieldsOf binds without the object (an ArgumentError).
      expect(fields.singleWhere((f) => f.spec.id == 'owner').value,
          '${hSlab.value}: Bar top');
      final width = fields.singleWhere((f) => f.spec.id == 'width');
      doc.commands.execute(types[0].commitField(doc, hSlab, width, 2400, words));
      expect(doc.components.get<Slab>(hSlab)!.width, 2400);
      // The post narrows: the same field, committed again, meets the new
      // range (commitField binds again, to the object, now).
      doc.commands.execute(SetComponentCommand<Post>(
          hPost, const Post(width: 400, shape: 'round')));
      expect(() => types[0].commitField(doc, hSlab, width, 1800, words),
          refusedOn('width'));
      doc.commands.execute(types[0].commitField(doc, hSlab, width, 1600, words));
      expect(doc.components.get<Slab>(hSlab)!.width, 1600);
    });

    test(
        'PO-words a text display reads the kit\'s words through the object, '
        'in their locale (rulings R-P4, R-P7; M-PO-words)', () {
      final List<PlanType<Component>> types = [viewType(), postType()];
      final (:doc, catalog: _) =
          objectDocument(types, post: const Post(width: 600));
      addTearDown(doc.dispose);
      // M-PO-words: fieldsOf builds the object over
      // `KitNamesWords(KitNames.empty, () => const Locale('en'))` instead of
      // the words given ('type:test.slab').
      expect(
          types[0]
              .fieldsOf(doc, hSlab, words)
              .singleWhere((f) => f.spec.id == 'named')
              .value,
          'Platte');
    });

    testWidgets(
        'PO-section the section gets the value, the commit, the words, the '
        'object and the services', (tester) async {
      PlanSection<Slab>? seen;
      final type = viewType(section: (context, section) {
        seen = section;
        return Text(
            '${section.words.word('type:test.slab')} '
            '${section.object.handle.value}',
            textDirection: TextDirection.ltr);
      });
      final List<PlanType<Component>> types = [type, postType()];
      final (:doc, catalog: _) = objectDocument(types);
      addTearDown(doc.dispose);
      final words = KitNamesWords(
          const KitNames({
            'en': {'type:test.slab': 'Slab'},
          }),
          () => const Locale('en'));
      final services = _Services();
      final executed = <DraftCommand>[];
      await tester.pumpWidget(Builder(
          builder: (context) => types[0]
              .sectionFor(context, doc, hSlab, executed.add, words, services)!));
      expect(find.text('Slab ${hSlab.value}'), findsOneWidget);
      // M-PO-section: the object of the document's root.
      expect(seen!.object.handle, hSlab);
      final world = seen!.object.world.toJson(), want = slabAt.toJson();
      for (var i = 0; i < 6; i++) {
        expect(world[i], closeTo(want[i], 1e-9), reason: '$i');
      }
      expect(identical(seen!.services, services), isTrue);
      expect(identical(seen!.words, words), isTrue);
      expect(identical(seen!.object.words, words), isTrue);
      expect(seen!.value, const Slab());
      seen!.commit(const Slab(label: 'Pass'));
      expect(executed.single, isA<SetComponentCommand<Slab>>());
    });
  });

  group('PlanKit.validate', () {
    PlanKit kitWith(List<PropertySpec<Slab>> settings) => PlanKit(
          id: 'test',
          version: '1.0.0',
          types: [viewType()],
          tools: [
            PlanTool(
                id: 'test.draw',
                icon: const IconData(0xe000),
                settings: PlanToolSettings<Slab>(
                    initial: const Slab(), specs: settings),
                create: (_) => throw UnimplementedError()),
          ],
          names: KitNames({
            'en': {
              'type:test.slab': 'Slab',
              'tool:test.draw': 'Draw',
              for (final id in ['width', 'turn', 'owner', 'named', 'flip'])
                'property:test.slab.$id': id,
              for (final s in settings) 'property:test.draw.${s.id}': s.id,
            },
          }),
        );

    test(
        'PO-validate a tool\'s settings may hold neither a text display nor '
        'a ranged length; a type may, and a plain length or a visible rule '
        'in settings is sound', () {
      // M-PO-validate: drop the check (no problem reported).
      final display = kitWith([
        TextDisplay<Slab>(id: 'note', read: (s, o) => s.label),
      ]).validate();
      expect([for (final p in display) p.code],
          [KitProblemCode.settingsNeedObject]);
      expect(display.single.message, contains('"test.draw"'));
      expect(display.single.message, contains('"note"'));
      final ranged = kitWith([
        LengthProperty<Slab>(
            id: 'reach',
            read: (s) => s.width,
            write: (s, v) => s.copyWith(width: v),
            range: besidePost),
      ]).validate();
      expect([for (final p in ranged) p.code],
          [KitProblemCode.settingsNeedObject]);
      // A type's specs read an object: sound.
      expect(
          kitWith([
            LengthProperty<Slab>(
                id: 'reach',
                read: (s) => s.width,
                write: (s, v) => s.copyWith(width: v),
                visible: (s) => s.raised),
          ]).validate(),
          isEmpty);
    });

    test(
        'PO-validate-cov the check reads settings of another T through '
        'PropertySpec<Object> without a TypeError (M-PO-cov)', () {
      // M-PO-cov: validate reading `spec is LengthProperty && spec.range !=
      // null` instead of `needsObject` throws a TypeError here.
      final List<PropertySpec<Object>> held = [
        LengthProperty<Slab>(
            id: 'reach',
            read: (s) => s.width,
            write: (s, v) => s,
            range: besidePost),
      ];
      expect(() => held.single.needsObject, returnsNormally);
      expect(
          [for (final p in kitWith(held.cast<PropertySpec<Slab>>()).validate()) p.code],
          [KitProblemCode.settingsNeedObject]);
    });
  });
}
```

  Note: `Post` is `code_fixtures.dart`'s (`const Post({this.width = 180.75, this.shape = 'round', this.swatch})`, `:113-114`); the tests give it a width of 600 through `objectDocument(post:)` (`plan_type_fixtures.dart:98-101`). `RemoveNodeCommand` (`jet_cad_2d/lib/src/document/commands.dart:461`) removes the node with its components. `held.single.needsObject` calls an `@internal` member from a test of the same package, which the analyzer allows.

  Edit `packages/jet_cad_2d_kit/test/kit/plan_type_test.dart` PT10 (a 2a test, not a ported one; its fixture follows the builder's new form, its assertions do not change): `slabType(section: (context, value, c, words) {` → `slabType(section: (context, section) {`, and in the builder `commit = c;` → `commit = section.commit;`, `words.word(` → `section.words.word(`, `${value.label}` → `${section.value.label}`; both `sectionFor(context, doc, hPost, executed.add, words)` and `sectionFor(context, doc, hSlab, executed.add, words)` gain `, FakeServices()` as a last argument.

  R-P4's callers (fixture calls only, assertions unchanged): in `test/kit/plan_type_test.dart` PT3-PT6 (`:84-166`) and `test/kit/example_code_test.dart` (`:37-41`), every `fieldsOf(doc, h)` → `fieldsOf(doc, h, words)` and every `commitField(doc, h, field, input)` → `commitField(doc, h, field, input, words)`, with one file-level `final KitWords words = KitNamesWords(KitNames.empty, () => const Locale('en'));` (`example_code_test.dart` gains `import 'package:flutter/widgets.dart' show Locale;` and `import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';` if it lacks them).

  Run `cd packages/jet_cad_2d_kit && flutter test test/kit/object_view_test.dart`. Expected: compilation fails (`The named parameter 'range' isn't defined`, `Method not found: 'TextDisplay'`, `Undefined name 'PlanSection'`, ...).

- [ ] **Step 3: The contract.**
  0. Ruling R-P7: create `lib/src/model/plan_words.dart`:

```dart
// The words a property or a section reads through its object (spec 3a
// C1.1, rulings R-P4, R-P7): pure, so the property specs stay free of
// Flutter. KitWords (the plan's view, with its locale) implements it.
//
// Pure Dart: no Flutter, no dart:io.

/// A kit's words at the plan's current locale, as a property reads them.
abstract interface class PlanWords {
  /// The word [wordId] in the locale, else in English, else [wordId] itself
  /// (a missing word shows its id, never nothing).
  String word(String wordId);

  /// The word [wordId] in the locale, else in English, else null.
  String? maybe(String wordId);
}
```

     `lib/src/model/model.dart`: add `export 'plan_words.dart';` after `export 'manifest_component.dart';`. `lib/src/kit/plan_services.dart`: add `import '../model/plan_words.dart';` after the `kit_names.dart` import, and `KitWords` (`:17-28`) becomes:

```dart
/// A kit's words at the plan's current locale (spec 2a P5): the pure
/// [PlanWords] and the locale they are in.
abstract interface class KitWords implements PlanWords {
  /// The locale the words are in now.
  Locale get locale;
}
```

     (`KitNamesWords` keeps its `@override`s of `word` and `maybe`; they now override `PlanWords`'.)
  1. `lib/src/model/kit_problem.dart`: after `unitKindWord,` add:

```dart

  // Spec 3a C1.1: PlanKit.validate, a tool's settings holding a spec that
  // reads an object (a TextDisplay, a LengthProperty with a range).
  settingsNeedObject,
```

  2. `lib/src/kit/properties.dart` — the whole file becomes:

```dart
// Property specs (spec 2a P3, umbrella A4): the fields a kit's type or a
// tool's settings show in the plan library's property panel, as data. Each
// spec reads one value of its owner `T` and writes a changed copy. A spec
// may read the object it is shown for (spec 3a C1.1: a text display, a
// length's range) and may be hidden (C1.7).
//
// Free of Flutter: nothing here draws. The panel (the plan library) turns a
// spec into a widget through the erased PropertyField. The object's words
// are the pure PlanWords (3a rulings R-P4, R-P7).
import 'package:jet_cad_2d/jet_cad_2d.dart'
    show DraftDocument, Handle, Transform2;
import 'package:meta/meta.dart' show internal;

import '../model/plan_words.dart';

/// A PlanPermissions flag a field needs (spec 2a P2, P3). A field whose gate
/// is off is shown read-only; an action whose gate is off is not shown
/// (spec 3a C1.7).
enum PlanGate {
  move,
  rotate,
  mirror,
  reshape,
  delete,
  changeLayer,
  recolor,
  editLayers,
  editPage,

  /// A unit's label (spec 2b S4; today's `renumber`).
  relabel,
}

/// How a [ValueDisplay] prints its number: a length in mm, an area in mm²,
/// an angle in radians, or a plain number.
enum ValueUnit { length, area, angle, none }

/// The object a property or a section is shown for (spec 3a C1.1), read
/// only: what a spec needs beyond its owner, such as a child's text,
/// another object's component, or the world transform.
abstract interface class PlanObject {
  /// The document the object lives in.
  DraftDocument get document;

  /// The object's group.
  Handle get handle;

  /// Its world transform: `document.tree.accumulatedTransform(handle)`.
  Transform2 get world;

  /// The owning kit's words at the plan's locale (rulings R-P4, R-P7): a
  /// type's or a `text:` word, the UI language's decimal separator.
  PlanWords get words;
}

/// A [PlanObject] over [document] and [handle], with [words]; [world] is
/// computed on its first read.
final class DocumentPlanObject implements PlanObject {
  DocumentPlanObject(this.document, this.handle, this.words);

  @override
  final DraftDocument document;

  @override
  final Handle handle;

  @override
  final PlanWords words;

  @override
  late final Transform2 world = document.tree.accumulatedTransform(handle);
}

final RegExp _specId = RegExp(r'^[a-z][a-z0-9-]*$');

/// One field of an owner `T`: a type's component or a tool's settings.
///
/// Its word is `property:<owner id>.<id>` (a choice's values:
/// `property:<owner id>.<id>.<value>`).
///
/// **Covariance.** The plan library holds specs of many `T`s at once. A
/// member whose type takes a `T` ([enabled], [visible], a kind's `read`,
/// `write` and `range`) throws a `TypeError` when it is read through a
/// supertype such as `PropertySpec<Object?>`. Only [id], [gate], a kind's
/// bounds and [bind] are safe there; [bind] is how the plan library uses a
/// spec.
sealed class PropertySpec<T> {
  PropertySpec._(this.id, this.enabled, this.gate, this.visible) {
    if (!_specId.hasMatch(id)) {
      throw ArgumentError.value(id, 'id',
          'must be a lower-case letter, then lower-case letters, digits and hyphens');
    }
  }

  /// Unique within its owner's specs.
  final String id;

  /// False greys the field out and its commit throws [StateError]. Null:
  /// always enabled.
  final bool Function(T)? enabled;

  /// The permission the field needs, or null for none.
  final PlanGate? gate;

  /// False hides the field: it takes no room in the panel (spec 3a C1.7).
  /// Evaluated when the spec is bound, so a throw is the binding's. Null:
  /// always visible.
  final bool Function(T)? visible;

  /// Whether binding needs the object (a [TextDisplay], a
  /// [LengthProperty] with a `range`): a tool's settings, which have none,
  /// may not hold such a spec (`PlanKit.validate`). Safe through a
  /// supertype: it reads the spec's own members with its own `T`.
  @internal
  bool get needsObject => false;

  /// This spec bound to [value], an owner `T`, under [wordId], for
  /// [object] (a type's field; null for a tool's settings): the erased form
  /// the plan library uses (spec 2a P1, erased operations). A kit never
  /// calls it.
  ///
  /// The field's `commit` returns the changed owner and, when it is not
  /// null, passes it to [onCommit] first. Throws [ArgumentError] when
  /// [value] is not a `T`, and when the spec needs an object ([needsObject])
  /// and [object] is null.
  PropertyField bind(Object? value,
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object});
}

/// A length in millimetres, within [min] and [max] (inclusive; null:
/// unbounded) and, with a [range], within what it gives for the value and
/// the object at the commit (inclusive too; spec 3a C1.1).
final class LengthProperty<T> extends PropertySpec<T> {
  LengthProperty({
    required String id,
    required this.read,
    required this.write,
    this.min,
    this.max,
    this.range,
    bool Function(T)? enabled,
    bool Function(T)? visible,
    PlanGate? gate,
  }) : super._(id, enabled, gate, visible) {
    _checkBounds(min, max);
  }

  final double Function(T) read;
  final T Function(T, double) write;
  final double? min;
  final double? max;

  /// The bounds the object allows, read at each commit: an opening's
  /// position along its host wall. A null result refuses every value.
  final (double, double)? Function(T value, PlanObject object)? range;

  @override
  bool get needsObject => range != null;

  @override
  PropertyField bind(Object? value,
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
    final owner = _owner<T>(value);
    final range = this.range;
    if (range != null && object == null) _noObject(wordId);
    return _BoundField<T>(this, owner, wordId, read(owner), (input) {
      final v = _inRange(_finite(input, id), min, max, id);
      if (range != null) {
        final allowed = range(owner, object!);
        if (allowed == null) {
          throw ArgumentError.value(v, id, 'has no range for this object');
        }
        _inRange(v, allowed.$1, allowed.$2, id);
      }
      return write(owner, v);
    }, onCommit);
  }
}

/// An angle, stored in radians. The field's value and its commit's input
/// are radians; the panel shows and parses degrees (spec 2a Task 17).
final class AngleProperty<T> extends PropertySpec<T> {
  AngleProperty({
    required String id,
    required this.read,
    required this.write,
    bool Function(T)? enabled,
    bool Function(T)? visible,
    PlanGate? gate,
  }) : super._(id, enabled, gate, visible);

  final double Function(T) read;
  final T Function(T, double) write;

  @override
  PropertyField bind(Object? value,
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner),
        (input) => write(owner, _finite(input, id)), onCommit);
  }
}

/// A plain number within [min] and [max], rounded on commit to [decimals]
/// places (0 to 10), so what is stored is what the panel shows.
final class NumberProperty<T> extends PropertySpec<T> {
  NumberProperty({
    required String id,
    required this.read,
    required this.write,
    this.min,
    this.max,
    this.decimals = 0,
    bool Function(T)? enabled,
    bool Function(T)? visible,
    PlanGate? gate,
  }) : super._(id, enabled, gate, visible) {
    _checkBounds(min, max);
    if (decimals < 0 || decimals > 10) {
      throw ArgumentError.value(decimals, 'decimals', 'must be 0 to 10');
    }
  }

  final double Function(T) read;
  final T Function(T, double) write;
  final double? min;
  final double? max;
  final int decimals;

  @override
  PropertyField bind(Object? value,
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner), (input) {
      final rounded =
          double.parse(_finite(input, id).toStringAsFixed(decimals));
      return write(owner, _inRange(rounded, min, max, id));
    }, onCommit);
  }
}

/// One of [values], compared with `==`. A value's word segment is
/// [segmentOf] it: an enum's name, else its `toString`. A segment is not
/// empty, given once, and holds no `.` or `:`, the separators of the word
/// id `property:<owner>.<spec>.<value>`; a value whose segment would is an
/// [ArgumentError] when the spec is made.
final class ChoiceProperty<T, V> extends PropertySpec<T> {
  ChoiceProperty({
    required String id,
    required List<V> values,
    required this.read,
    required this.write,
    bool Function(T)? enabled,
    bool Function(T)? visible,
    PlanGate? gate,
  })  : values = List.unmodifiable(values),
        super._(id, enabled, gate, visible) {
    if (this.values.isEmpty) {
      throw ArgumentError.value(values, 'values', 'must not be empty');
    }
    final seen = <String>{};
    for (final v in this.values) {
      final segment = segmentOf(v);
      if (segment.isEmpty || !seen.add(segment)) {
        throw ArgumentError.value(
            v, 'values', 'gives the word segment "$segment" twice or empty');
      }
      if (segment.contains('.') || segment.contains(':')) {
        throw ArgumentError.value(v, 'values',
            'gives the word segment "$segment", which holds "." or ":"');
      }
    }
  }

  /// The word segment of [value]: an enum's name, else `'$value'`.
  static String segmentOf(Object? value) =>
      value is Enum ? value.name : '$value';

  final List<V> values;
  final V Function(T) read;
  final T Function(T, V) write;

  @override
  PropertyField bind(Object? value,
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner), (input) {
      if (input is! V || !values.contains(input)) {
        throw ArgumentError.value(input, id, 'is not one of $values');
      }
      return write(owner, input);
    }, onCommit);
  }
}

/// A yes or no.
final class ToggleProperty<T> extends PropertySpec<T> {
  ToggleProperty({
    required String id,
    required this.read,
    required this.write,
    bool Function(T)? enabled,
    bool Function(T)? visible,
    PlanGate? gate,
  }) : super._(id, enabled, gate, visible);

  final bool Function(T) read;
  final T Function(T, bool) write;

  @override
  PropertyField bind(Object? value,
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner), (input) {
      if (input is! bool) {
        throw ArgumentError.value(input, id, 'is not a bool');
      }
      return write(owner, input);
    }, onCommit);
  }
}

/// A text of at most [maxLength] code points (null: any length).
final class TextProperty<T> extends PropertySpec<T> {
  TextProperty({
    required String id,
    required this.read,
    required this.write,
    this.maxLength,
    bool Function(T)? enabled,
    bool Function(T)? visible,
    PlanGate? gate,
  }) : super._(id, enabled, gate, visible) {
    final m = maxLength;
    if (m != null && m < 1) {
      throw ArgumentError.value(m, 'maxLength', 'must be at least 1');
    }
  }

  final String Function(T) read;
  final T Function(T, String) write;
  final int? maxLength;

  @override
  PropertyField bind(Object? value,
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner), (input) {
      if (input is! String) {
        throw ArgumentError.value(input, id, 'is not a String');
      }
      final m = maxLength;
      if (m != null && input.runes.length > m) {
        throw ArgumentError.value(input, id, 'is longer than $m');
      }
      return write(owner, input);
    }, onCommit);
  }
}

/// A read-only number of the owner. Its field's commit is null.
final class ValueDisplay<T> extends PropertySpec<T> {
  ValueDisplay({
    required String id,
    required this.read,
    required this.unit,
    bool Function(T)? enabled,
    bool Function(T)? visible,
    PlanGate? gate,
  }) : super._(id, enabled, gate, visible);

  final double Function(T) read;
  final ValueUnit unit;

  @override
  PropertyField bind(Object? value,
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner), null, onCommit);
  }
}

/// A read-only line of text read from the object (spec 3a C1.1): a room's
/// area and a dimension's value as drawn, a dimension's axes and ends. Its
/// field's value is the `String` and its commit is null; a null read omits
/// the line (the field is not visible). Bound to an object only: a tool's
/// settings may not hold one (`PlanKit.validate`).
final class TextDisplay<T> extends PropertySpec<T> {
  TextDisplay({
    required String id,
    required this.read,
    bool Function(T)? enabled,
    bool Function(T)? visible,
    PlanGate? gate,
  }) : super._(id, enabled, gate, visible);

  final String? Function(T value, PlanObject object) read;

  @override
  bool get needsObject => true;

  @override
  PropertyField bind(Object? value,
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
    final owner = _owner<T>(value);
    if (object == null) _noObject(wordId);
    final text = read(owner, object);
    return _BoundField<T>(this, owner, wordId, text, null, onCommit,
        shown: text != null);
  }
}

/// A button: a door's Flip hinge. Its field's value is null and its commit
/// ignores its input and returns [apply] of the owner.
final class ActionProperty<T> extends PropertySpec<T> {
  ActionProperty({
    required String id,
    required this.apply,
    bool Function(T)? enabled,
    bool Function(T)? visible,
    PlanGate? gate,
  }) : super._(id, enabled, gate, visible);

  final T Function(T) apply;

  @override
  PropertyField bind(Object? value,
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(
        this, owner, wordId, null, (_) => apply(owner), onCommit);
  }
}

/// A spec bound to one owner value: one object's component or one tool's
/// settings (spec 2a P3). Erased: the plan library holds fields of many
/// owner types in one list and never sees a `T`.
abstract interface class PropertyField {
  /// For [PropertySpec.id], [PropertySpec.gate], the kind (a type test) and
  /// a kind's bounds or values only: see [PropertySpec]'s covariance note.
  PropertySpec<Object?> get spec;

  /// `property:<owner id>.<spec id>`.
  String get wordId;

  /// The spec's `enabled` of the bound owner; true when it has none.
  bool get enabled;

  /// The spec's `visible` of the bound owner (true when it has none), and
  /// false for a [TextDisplay] whose read gave null (spec 3a C1.7).
  bool get visible;

  /// The bound owner's value: a `double` for a length (mm), an angle
  /// (radians), a number and a value display; the value for a choice; a
  /// `bool`; a `String` for a text and a text display (null for a display
  /// that reads nothing); null for an action.
  Object? get value;

  /// Null for a [ValueDisplay] and a [TextDisplay]. Otherwise: the owner
  /// changed by [input] (an action ignores it). Throws [ArgumentError] for
  /// an input of the wrong type, not finite, out of range (a length's
  /// `range` included), not among a choice's values or too long, and
  /// [StateError] while the field is not [enabled].
  Object? Function(Object? input)? get commit;
}

final class _BoundField<T> implements PropertyField {
  factory _BoundField(
      PropertySpec<T> spec,
      T owner,
      String wordId,
      Object? value,
      T Function(Object? input)? change,
      void Function(T next)? onCommit,
      {bool shown = true}) {
    final enabled = spec.enabled?.call(owner) ?? true;
    final visible = shown && (spec.visible?.call(owner) ?? true);
    return _BoundField._(
        spec,
        wordId,
        value,
        enabled,
        visible,
        change == null
            ? null
            : (input) {
                if (!enabled) throw StateError('$wordId is not enabled');
                final next = change(input);
                onCommit?.call(next);
                return next;
              });
  }

  _BoundField._(this.spec, this.wordId, this.value, this.enabled,
      this.visible, this.commit);

  @override
  final PropertySpec<T> spec;

  @override
  final String wordId;

  @override
  final Object? value;

  @override
  final bool enabled;

  @override
  final bool visible;

  @override
  final Object? Function(Object? input)? commit;
}

T _owner<T>(Object? value) {
  if (value is T) return value;
  throw ArgumentError.value(value, 'value', 'is not a $T');
}

Never _noObject(String wordId) => throw ArgumentError.value(
    wordId, 'object', 'reads the object it is shown for: bind it to one');

double _finite(Object? input, String id) {
  if (input is num && input.isFinite) return input.toDouble();
  throw ArgumentError.value(input, id, 'is not a finite number');
}

double _inRange(double v, double? min, double? max, String id) {
  if ((min != null && v < min) || (max != null && v > max)) {
    throw ArgumentError.value(
        v, id, 'is outside [${min ?? '-∞'}, ${max ?? '∞'}]');
  }
  return v;
}

void _checkBounds(double? min, double? max) {
  if (min != null && !min.isFinite) {
    throw ArgumentError.value(min, 'min', 'is not finite');
  }
  if (max != null && !max.isFinite) {
    throw ArgumentError.value(max, 'max', 'is not finite');
  }
  if (min != null && max != null && min > max) {
    throw ArgumentError.value(min, 'min', 'is above max ($max)');
  }
}
```

  Only the members named in this task change; every other line is today's (compare with `git diff` and say so in the report). In `LengthProperty.bind`, `object!` is safe: a non-null `range` with a null `object` threw above. In `TextDisplay.bind` the promotion of `object` after `_noObject` (a `Never`) needs no `!`.

  3. `lib/src/kit/plan_type.dart`:
     - add `import '../model/plan_words.dart';` after `import '../model/kit_ids.dart';` (`:17`): `fieldsOf` and `commitField` name `PlanWords`, which neither `plan_services.dart` nor `properties.dart` re-exports;
     - the typedef (`:22-25`) becomes the builder and its context:

```dart
/// A type's escape hatch (umbrella A4): its own panel section over
/// [PlanSection.value], committing a changed copy through
/// [PlanSection.commit], one undo step. One context, so a later field joins
/// it without breaking a kit (spec 3a C1.1).
typedef PropertySectionBuilder<T> = Widget Function(
    BuildContext context, PlanSection<T> section);

/// What a section is built over (spec 3a C1.1): the object's component, the
/// one commit, the kit's words, the object, and the kit's services.
@immutable
final class PlanSection<T> {
  const PlanSection({
    required this.value,
    required this.commit,
    required this.words,
    required this.object,
    required this.services,
  });

  final T value;

  /// Hands the plan one `SetComponentCommand<T>` of [next].
  final void Function(T next) commit;
  final KitWords words;
  final PlanObject object;
  final PlanServices services;
}
```

     - `fieldsOf` (`:86-95`):

```dart
  /// The fields of [group]'s `T`, bound to its current value and to the
  /// object (spec 3a C1.1) with the kit's [words] (ruling R-P4), each under
  /// `property:<id>.<spec id>`; empty when [group] carries no `T`.
  List<PropertyField> fieldsOf(
      DraftDocument document, Handle group, PlanWords words) {
    final value = document.components.get<T>(group);
    if (value == null) return const [];
    final object = DocumentPlanObject(document, group, words);
    return [
      for (final spec in properties)
        spec.bind(value, wordId: 'property:$id.${spec.id}', object: object),
    ];
  }
```

     - `commitField` (`:132-146`): the parameter `CommandTarget target` → `DraftDocument document`, and a last parameter `PlanWords words` after `Object? input`; `target.components` → `document.components`; `spec.bind(value, wordId: field.wordId).commit` → `spec.bind(value, wordId: field.wordId, object: DocumentPlanObject(document, group, words)).commit`; its doc gains `/// The object is the document's now, so a range is checked against it.` after the first paragraph.
     - `sectionFor` (`:148-157`):

```dart
  /// [group]'s escape-hatch section, or null without one or a `T`. Its
  /// commit hands [execute] one `SetComponentCommand<T>`; [words] and
  /// [services] are the type's kit's.
  Widget? sectionFor(BuildContext context, DraftDocument document,
      Handle group, void Function(DraftCommand) execute, KitWords words,
      PlanServices services) {
    final value = document.components.get<T>(group);
    final section = _section;
    if (value == null || section == null) return null;
    return section(
        context,
        PlanSection<T>(
            value: value,
            commit: (next) => execute(SetComponentCommand<T>(group, next)),
            words: words,
            object: DocumentPlanObject(document, group, words),
            services: services));
  }
```

     `titleWordOf`, `colourOf` and `recolour` keep `CommandTarget` (Shared interfaces narrow only these three).
  4. `lib/src/kit/plan_kit.dart`, in `validate`'s tools loop (`:121-130`), after the `declared(...)` block, inside the `for (final tool in tools)` body:

```dart
      // Spec 3a C1.1: a tool's settings are bound with no object.
      for (final spec in tool.settings?.specs ?? const <PropertySpec<Object>>[]) {
        if (spec.needsObject) {
          problems.add(KitProblem(
              KitProblemCode.settingsNeedObject,
              'the tool "${tool.id}"\'s setting "${spec.id}" reads the object '
              'it is shown for (a TextDisplay or a range): a tool\'s '
              'settings have none'));
        }
      }
```

     The method's doc gains `/// A tool's setting that reads an object (spec 3a C1.1).` in its list of problems.
  5. `test/support/plan_type_fixtures.dart`: no code change (its `section:` parameter is typed by the typedef).

  Run `cd packages/jet_cad_2d_kit && dart format . && flutter test test/kit/`. Expected: `All tests passed!`.

- [ ] **Step 4: The plan library's test kits follow** (fixtures only; no assertion changes).
  1. `test/support/panel_kits.dart` `:462-468`, the disc's section:

```dart
  section: (context, section) {
    final value = section.value;
    if (value.radius > 5000) throw StateError('a disc over 5 m');
    return OutlinedButton(
        key: const Key('disc-grow'),
        onPressed: () => section.commit(value.withRadius(value.radius * 2)),
        child: Text(section.words.word('property:disc.disc.grow')));
  },
```

  2. `test/support/test_kit.dart` `:426-432`, the slab's section:

```dart
/// The escape hatch: one button that widens the slab by 250 mm.
Widget slabSection(BuildContext context, PlanSection<SlabComponent> section) =>
    TextButton(
        key: const Key('test-slab-widen'),
        onPressed: () => section
            .commit(section.value.copyWith(width: section.value.width + 250)),
        child: Text(section.words.word('property:test.slab.widen')));
```

  3. `test/support/throwing_kit.dart`: `boomHooks`' line `'read', 'write', 'apply', 'section', 'sectionWidget', 'colourRead',` gains, on a line after `'colourWrite', 'title',`: `// Spec 3a C1.1, C1.7: a text display's read, a length's range, a spec's visible.` and `'display', 'range', 'visible',`. `boom.block`'s `section:` becomes `section: (context, section) {` (body unchanged). Its `properties` gain, after the `size` `NumberProperty`:

```dart
          TextDisplay<BlockComponent>(
              id: 'shown',
              read: (b, o) {
                check('display');
                return '${b.size.round()} mm at ${o.handle.value}';
              }),
          LengthProperty<BlockComponent>(
              id: 'span',
              read: (b) => b.size,
              write: (b, v) => b.copyWith(size: v),
              min: 10,
              max: 10000,
              range: (b, o) {
                check('range');
                return (10, 10000);
              }),
```

     and the `grow` `ActionProperty` gains `visible: (b) { check('visible'); return true; },`. Its words gain `'property:boom.block.shown': 'Shown',` and `'property:boom.block.span': 'Span',`.

  Run `cd packages/jet_cad_2d_plan && flutter analyze`. Expected: errors only in `lib/src/panels/plan_property_panel.dart` (the switches are not exhaustive over `TextDisplay`; `sectionFor` takes one more argument; `fieldsOf` and `commitField` take the words) and in `test/controller/covariance_test.dart` (`:33`, `:40`, `:43`): there `fieldsOf(d, object)` → `fieldsOf(d, object, c.servicesOf(type.id.split('.').first).words)` and `commitField(d, object, field, 2345.5)` → `commitField(d, object, field, 2345.5, c.servicesOf(type.id.split('.').first).words)` (fixture calls; assertions unchanged). Any error elsewhere is a caller this plan did not find: fix it the same way and list it in the report.

- [ ] **Step 5: The plan's object kit and the failing panel tests.**
  1. Create `packages/jet_cad_2d_plan/test/support/object_kit.dart`:

```dart
// The object-view kit (3a Task 2, spec C1.1, C1.7): kit "view". A rail
// (view.rail) is a line along its group's x axis, of [length], with its
// label drawn as a TEXT child; its fields read that child's text and its
// world turn. A bead (view.bead) sits on a host rail: its position's range
// is read from the host's component, and its Flip shows for a door only,
// behind reshape. Placed off the origin in turned groups (CLAUDE.md).
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Tolerance;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

@immutable
final class RailComponent implements Component {
  const RailComponent(this.length, {this.label = ''});

  static const String componentTypeId = 'view.rail';

  final double length;
  final String label;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'label': label, 'length': length};

  static RailComponent fromJson(Map<String, Object?> json) => RailComponent(
      (json['length']! as num).toDouble(),
      label: json['label']! as String);

  @override
  bool operator ==(Object other) =>
      other is RailComponent && other.length == length && other.label == label;

  @override
  int get hashCode => Object.hash(length, label);
}

final class RailType extends ParametricType<RailComponent> {
  const RailType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(RailComponent p, Transform2 toWorld) => Aabb2.fromPoints([
        toWorld.transformPoint(Vector2(0, -200)),
        toWorld.transformPoint(Vector2(p.length, 200)),
        toWorld.transformPoint(Vector2(0, 200)),
        toWorld.transformPoint(Vector2(p.length, -200)),
      ]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<RailComponent>(self)!;
    return [
      Generated(EntityKind.line, linePayload(Vector2.zero(), Vector2(p.length, 0))),
      if (p.label.isNotEmpty)
        Generated.text(textPayload(Vector2(p.length / 2, 150), 120), p.label),
    ];
  }
}

/// The text of [o]'s first TEXT child, as drawn, or null without one.
String? childText(PlanObject o) {
  final entities = o.document.entities;
  for (final slot in entities.liveSlots) {
    if (entities.ownerAt(slot) == o.handle &&
        entities.kindAt(slot) == EntityKind.text) {
      return entities.textAt(slot);
    }
  }
  return null;
}

/// [o]'s world turn in degrees, one decimal, or null when it is not turned.
String? turnText(PlanObject o) {
  final w = o.world;
  final degrees = math.atan2(w.b, w.a) * 180 / math.pi;
  return degrees.abs() < 1e-9 ? null : '${degrees.toStringAsFixed(1)}°';
}

@immutable
final class BeadComponent implements Component {
  const BeadComponent(this.host, this.position,
      {this.door = true, this.flipped = false});

  static const String componentTypeId = 'view.bead';

  final Handle host;
  final double position;
  final bool door;
  final bool flipped;

  @override
  String get typeId => componentTypeId;

  BeadComponent copyWith({double? position, bool? door, bool? flipped}) =>
      BeadComponent(host, position ?? this.position,
          door: door ?? this.door, flipped: flipped ?? this.flipped);

  @override
  Map<String, Object?> toJson() => {
        'door': door,
        'flipped': flipped,
        'host': host.value,
        'position': position,
      };

  static BeadComponent fromJson(Map<String, Object?> json) => BeadComponent(
      Handle(json['host']! as int), (json['position']! as num).toDouble(),
      door: json['door']! as bool, flipped: json['flipped']! as bool);

  @override
  bool operator ==(Object other) =>
      other is BeadComponent &&
      other.host == host &&
      other.position == position &&
      other.door == door &&
      other.flipped == flipped;

  @override
  int get hashCode => Object.hash(host, position, door, flipped);
}

final class BeadType extends ParametricType<BeadComponent> {
  const BeadType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(BeadComponent p, Transform2 toWorld) => Aabb2.fromPoints([
        toWorld.transformPoint(Vector2(-60, -60)),
        toWorld.transformPoint(Vector2(60, 60)),
      ]);

  @override
  List<Generated> generate(ParametricView view, Handle self) =>
      [Generated(EntityKind.circle, circlePayload(Vector2.zero(), 50))];
}

/// The host rail's length bounds a bead's position; a host that is no
/// rail gives none (every position refused, today's opening on a non-wall).
(double, double)? hostRange(BeadComponent b, PlanObject o) {
  final rail = o.document.components.get<RailComponent>(b.host);
  return rail == null ? null : (0, rail.length);
}

final PlanType<RailComponent> railType = PlanType<RailComponent>(
  id: RailComponent.componentTypeId,
  fromJson: RailComponent.fromJson,
  parametric: const RailType(),
  properties: [
    LengthProperty<RailComponent>(
        id: 'length',
        read: (r) => r.length,
        write: (r, v) => RailComponent(v, label: r.label),
        min: 100),
    TextProperty<RailComponent>(
        id: 'label',
        read: (r) => r.label,
        write: (r, v) => RailComponent(r.length, label: v)),
    TextDisplay<RailComponent>(
        id: 'drawn', read: (r, o) => childText(o) ?? '—'),
    TextDisplay<RailComponent>(id: 'turn', read: (r, o) => turnText(o)),
    // R-P4: the kit's own words through the object.
    TextDisplay<RailComponent>(
        id: 'named', read: (r, o) => o.words.word('type:view.rail')),
  ],
  section: (context, section) => Text(
      '${section.services.words.word('type:view.rail')} '
      '${section.object.handle.value}',
      key: const Key('view-rail-section')),
);

final PlanType<BeadComponent> beadType = PlanType<BeadComponent>(
  id: BeadComponent.componentTypeId,
  fromJson: BeadComponent.fromJson,
  parametric: const BeadType(),
  properties: [
    LengthProperty<BeadComponent>(
        id: 'position',
        read: (b) => b.position,
        write: (b, v) => b.copyWith(position: v),
        range: hostRange),
    ActionProperty<BeadComponent>(
        id: 'flip',
        apply: (b) => b.copyWith(flipped: !b.flipped),
        visible: (b) => b.door,
        gate: PlanGate.reshape),
    ToggleProperty<BeadComponent>(
        id: 'door', read: (b) => b.door, write: (b, v) => b.copyWith(door: v)),
  ],
);

final PlanKit objectKit = PlanKit(
  id: 'view',
  version: '1.0.0',
  types: [railType, beadType],
  names: const KitNames({
    'en': {
      'type:view.rail': 'Rail',
      'type:view.bead': 'Bead',
      'property:view.rail.length': 'Length',
      'property:view.rail.label': 'Label',
      'property:view.rail.drawn': 'Drawn',
      'property:view.rail.turn': 'Turn',
      'property:view.rail.named': 'Named',
      'property:view.bead.position': 'Position',
      'property:view.bead.flip': 'Flip',
      'property:view.bead.door': 'Door',
    },
  }),
);

/// [component] in a root-level group at [at] turned [turn], on the drawing
/// layer: one step; its handle.
Handle addTurned<T extends Component>(
    DraftDocument d, T component, Vector2 at, double turn) {
  final h = d.handleSeed.next();
  d.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h,
        parent: d.rootHandle,
        transform:
            Transform2.translation(at.x, at.y).multiply(Transform2.rotation(turn)),
        children: const [])),
    SetComponentCommand<T>(h, component),
    SetComponentCommand<ObjectLayer>(h, ObjectLayer(drawingLayer(d))),
  ], label: 'Add ${component.typeId}'));
  return h;
}
```

  2. Create `packages/jet_cad_2d_plan/test/panels/object_view_panel_test.dart`:

```dart
// Spec 3a C1.1, C1.7, Review Focus 4 (the plan half): the property panel
// over the object-view kit. A text display reads the object (a child's
// text as drawn, the world turn) and omits its line when it reads nothing;
// a position's range comes from the host's component, a value outside it
// is refused with no command and no diagnostic, and a host that is no rail
// refuses every value; a hidden field takes no room; an action whose gate
// is refused is not shown; the section gets the object and the kit's
// services; and the new hooks are at the failure boundary.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/design_harness.dart';
import '../support/object_kit.dart';
import '../support/panel_kits.dart' show boxController, boxKit;
import '../support/test_kit.dart' show addObject;
import '../support/throwing_kit.dart';

Finder byKey(String k) => find.byKey(Key(k));

String textOf(WidgetTester tester, String key) =>
    tester.widget<TextField>(byKey(key)).controller!.text;

String shown(WidgetTester tester, String key) =>
    tester.widget<Text>(byKey(key)).data!;

Future<void> select(WidgetTester tester, PlanController c, Handle h) async {
  c.selection.replace([SelectionKey.root(h)]);
  await tester.pump();
}

Future<void> enterAndSubmit(
    WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await tester.pump();
  await tester.enterText(byKey(key), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

List<KitDiagnostic> hookFailures(PlanController c) => [
      for (final d in c.diagnostics.value)
        if (d.code == KitDiagnosticCode.hookFailed) d
    ];

/// A 1:20 page (boxController's) with the box kit and the object kit; a
/// rail of 3200 labelled `R-7`, turned 0.7 rad at (7010, 3020), a bead on
/// it at 1250, a second rail unturned and unlabelled, and a bead whose
/// host is that bead (no rail).
({PlanController c, Handle rail, Handle bead, Handle flat, Handle stray})
    plan() {
  final c = boxController(kits: [boxKit, objectKit]);
  final d = c.document;
  final rail = addTurned(
      d, const RailComponent(3200, label: 'R-7'), Vector2(7010, 3020), 0.7);
  final bead =
      addTurned(d, BeadComponent(rail, 1250), Vector2(7400, 3300), -0.4);
  final flat =
      addTurned(d, const RailComponent(1800), Vector2(7600, 2900), 0);
  final stray =
      addTurned(d, BeadComponent(bead, 40), Vector2(7700, 3100), 0.25);
  d.commands.clearHistory();
  return (c: c, rail: rail, bead: bead, flat: flat, stray: stray);
}

Future<void> panel(WidgetTester tester, PlanController c) =>
    pumpDesign(tester, c, right: PlanPropertyPanel(controller: c));

void main() {
  testWidgets(
      'PO-panel-display a text display shows what it reads from the object: '
      'the TEXT child as drawn, the world turn; a rail without a label shows '
      '— and an unturned one has no Turn line (M-PO-null, M-PO-panel-row)',
      (tester) async {
    final p = plan();
    await panel(tester, p.c);
    await select(tester, p.c, p.rail);
    expect(shown(tester, 'property-drawn'), 'R-7');
    expect(shown(tester, 'property-turn'), '40.1°');
    // R-P4: the object's words are its own kit's (M-PO-panel-words).
    expect(shown(tester, 'property-named'), 'Rail');
    // Edited: the TEXT child regenerates and the line follows.
    await enterAndSubmit(tester, 'property-label', 'R-8');
    expect(shown(tester, 'property-drawn'), 'R-8');
    await select(tester, p.c, p.flat);
    expect(shown(tester, 'property-drawn'), '—');
    expect(byKey('property-turn'), findsNothing);
  });

  testWidgets(
      'PO-range (Review Focus 4) a position past the host\'s length is '
      'refused: the field shows the stored value, no command, no '
      'diagnostic; the ends themselves are allowed; a host that is no rail '
      'refuses every value (M-PO-range, M-PO-range-null)', (tester) async {
    final p = plan();
    final c = p.c;
    await panel(tester, c);
    await select(tester, c, p.bead);
    BeadComponent bead() => c.document.components.get<BeadComponent>(p.bead)!;
    final depth = c.document.commands.undoDepth;
    await enterAndSubmit(tester, 'property-position', '3200.5');
    expect(bead().position, 1250);
    expect(textOf(tester, 'property-position'), '1250');
    expect(c.document.commands.undoDepth, depth);
    expect(hookFailures(c), isEmpty);
    await enterAndSubmit(tester, 'property-position', '3200');
    expect(bead().position, 3200);
    await enterAndSubmit(tester, 'property-position', '0');
    expect(bead().position, 0);
    expect(c.document.commands.undoDepth, depth + 2);
    // The stray bead's host is a bead: every value is refused, 0 included.
    await select(tester, c, p.stray);
    final strayDepth = c.document.commands.undoDepth;
    for (final v in ['0', '40.5', '20']) {
      await enterAndSubmit(tester, 'property-position', v);
      expect(c.document.components.get<BeadComponent>(p.stray)!.position, 40,
          reason: v);
      expect(textOf(tester, 'property-position'), '40', reason: v);
    }
    expect(c.document.commands.undoDepth, strayDepth);
    expect(hookFailures(c), isEmpty);
  });

  testWidgets(
      'PO-hidden a field whose visible says no takes no row and no room: a '
      'door\'s Flip shows, a window\'s does not, and the Door row moves up '
      'by its height (M-PO-hidden)', (tester) async {
    final p = plan();
    final c = p.c;
    await panel(tester, c);
    await select(tester, c, p.bead);
    expect(byKey('property-flip'), findsOneWidget);
    final withFlip = tester.getTopLeft(byKey('property-door')).dy;
    final flipHeight = tester.getSize(byKey('property-flip')).height;
    await tester.tap(byKey('property-door'));
    await tester.pumpAndSettle();
    expect(c.document.components.get<BeadComponent>(p.bead)!.door, isFalse,
        reason: 'premise: the bead is a window now');
    expect(byKey('property-flip'), findsNothing);
    expect(tester.getTopLeft(byKey('property-door')).dy,
        lessThanOrEqualTo(withFlip - flipHeight));
  });

  testWidgets(
      'PO-gate-hidden an action whose gate the permissions refuse is not '
      'shown (today\'s S-11), where a gated field is read-only '
      '(M-PO-gate-hidden)', (tester) async {
    final p = plan();
    final c = p.c;
    await panel(tester, c);
    c.permissions = PlanPermissions.full.copyWith(reshape: false);
    await tester.pump();
    await select(tester, c, p.bead);
    expect(c.document.components.get<BeadComponent>(p.bead)!.door, isTrue,
        reason: 'premise: visible says yes');
    expect(byKey('property-flip'), findsNothing);
    expect(byKey('property-door'), findsOneWidget);
    c.permissions = PlanPermissions.full;
    await tester.pump();
    expect(byKey('property-flip'), findsOneWidget);
    await tester.tap(byKey('property-flip'));
    await tester.pumpAndSettle();
    expect(c.document.components.get<BeadComponent>(p.bead)!.flipped, isTrue);
  });

  testWidgets(
      'PO-section the section is built over the object and its own kit\'s '
      'services (M-PO-services)', (tester) async {
    final p = plan();
    await panel(tester, p.c);
    await select(tester, p.c, p.rail);
    expect(shown(tester, 'view-rail-section'), 'Rail ${p.rail.value}');
  });

  group('the failure boundary (spec C2: the new hooks)', () {
    ({PlanController c, ThrowingKit boom, Handle block}) boomPlan() {
      final boom = ThrowingKit();
      final c = boxController(kits: [boxKit, boom.kit]);
      final block = addObject<BlockComponent>(
          c.document, const BlockComponent(size: 400, swatch: 'purple'),
          at: Vector2(7500, 3200));
      return (c: c, boom: boom, block: block);
    }

    List<String> boomFailures(PlanController c) => [
          for (final d in hookFailures(c))
            if (d.kitId == 'boom') '${d.subject}: ${(d.error! as BoomFailure).hook}',
        ];

    for (final hook in ['display', 'visible']) {
      testWidgets(
          'PO-G-$hook a $hook hook that throws while the section binds: the '
          '"section failed" box, one diagnostic, no exception (M-PO-G-$hook)',
          (tester) async {
        final b = boomPlan();
        await panel(tester, b.c);
        await select(tester, b.c, b.block);
        expect(shown(tester, 'property-shown'), '400 mm at ${b.block.value}',
            reason: 'premise: the display reads');
        b.boom.failing.add(hook);
        b.c.selection.replace(const []);
        await tester.pump();
        await select(tester, b.c, b.block);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(byKey('kit-section-failed'), findsOneWidget);
        expect(boomFailures(b.c), ['boom.block: $hook']);
      });
    }

    testWidgets(
        'PO-G-range a range that throws at the commit: one diagnostic, '
        'nothing stored, the section stays (M-PO-G-range)', (tester) async {
      final b = boomPlan();
      await panel(tester, b.c);
      await select(tester, b.c, b.block);
      b.boom.failing.add('range');
      await enterAndSubmit(tester, 'property-span', '640');
      expect(tester.takeException(), isNull);
      expect(b.c.document.components.get<BlockComponent>(b.block)!.size, 400);
      expect(textOf(tester, 'property-span'), '400');
      expect(byKey('kit-section-failed'), findsNothing);
      expect(boomFailures(b.c), ['boom.block: range']);
    });
  });
}
```

  Run `cd packages/jet_cad_2d_plan && flutter test test/panels/object_view_panel_test.dart`. Expected: compilation fails in `plan_property_panel.dart` (the `TextDisplay` case missing from the switches, `sectionFor`'s new argument).

- [ ] **Step 6: The panel.** `packages/jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart` (the line numbers are at `c6bcce3e`; Task 1 deletes its `symbol_box.dart` import, `:32`, so each place below is one line higher: find it by the code quoted):
  0. R-P4: `_fieldsOrNull`'s `planTypeOf(c, typeId)!.fieldsOf(c.document, handle)` (`:337`) → `planTypeOf(c, typeId)!.fieldsOf(c.document, handle, c.servicesOf(kitOfKey(typeId)).words)`, and `_write`'s `.commitField(c.document, handle, field, input)` (`:547`) → `.commitField(c.document, handle, field, input, c.servicesOf(kitOfKey(typeId)).words)`: the kit's words, the same `_objectSection` passes to `sectionFor`.
  1. `_textOf` (`:399-402`) and `_parse` (`:440-444`): the last `case` becomes `case ChoiceProperty() || ToggleProperty() || ValueDisplay() || TextDisplay() || ActionProperty():` (formatted as today, one kind per line).
  2. `_row`, after the `ValueDisplay` case (`:750-755`):

```dart
      case TextDisplay():
        // Spec 3a C1.1: a read-only line, the text as the kit read it.
        return InputDecorator(
          decoration:
              InputDecoration(labelText: label, border: InputBorder.none),
          child: Text(field.value as String? ?? '', key: key),
        );
```

  3. After `_row`, a new method:

```dart
  /// Whether [field] of [t] takes a row (spec 3a C1.7): not when its
  /// `visible` says no (a text display that read nothing included), nor an
  /// object's action whose gate the permissions refuse (today's S-11: a
  /// button the capabilities refuse is not shown). A hidden field takes no
  /// room.
  bool _shows(_Target t, PropertyField field) {
    if (!field.visible) return false;
    final gate = field.spec.gate;
    return !(t is _ObjectTarget &&
        field.spec is ActionProperty &&
        gate != null &&
        !_c.permissions.allows(gate));
  }
```

  4. `_settingsSection` (`:801`): `for (final field in fields) _row(t, _Scope.tool, field, kit),` → `for (final field in fields) if (_shows(t, field)) _row(t, _Scope.tool, field, kit),`. `_objectSection` (`:832`): the same with `_Scope.object`.
  5. `_objectSection`'s `sectionFor` call (`:837-842`) gains the services as its last argument: `c.servicesOf(kit).words, c.servicesOf(kit)),` (the call's `words` argument is unchanged).

  Run `cd packages/jet_cad_2d_plan && dart format . && flutter analyze && flutter test test/panels/ test/kits/ test/controller/covariance_test.dart`. Expected: `No issues found!`, `All tests passed!`. If an existing test counts `boom.block`'s rows or fields, that is a finding: stop and report it.

- [ ] **Step 7: Docs and the amendment lines.**
  1. `docs/kits.md` §10.2's `section` row (`:355`) becomes `` | `section` | the escape hatch: `(context, section) => Widget`, for what specs cannot say; `section` (a `PlanSection`) holds the `value`, `commit` (one undo step), the kit's `words`, the `object` (document, handle, world) and the kit's `services` | ``. §10.3's table gains, after the `ValueDisplay` row, `` | `TextDisplay` | `read(value, object)` → a `String`, or null to omit the line | read-only: a room's area as drawn | `` and its `LengthProperty` row reads `` `read`, `write`, `min`, `max`, `range(value, object)` (inclusive; null refuses every value) ``. The first bullet after the table gains `, an optional visible(T) that hides the field (a hidden field takes no room; an action whose gate is refused is hidden too)` after `greys the field out`, and a new bullet: `- A TextDisplay and a range read the object a field is shown for (PlanObject: document, handle, world, the kit's words); a tool's settings have none, so PlanKit.validate refuses them there (settingsNeedObject).` Run `cd packages/jet_cad_2d_kit && flutter test test/invariants/doc_snippets_test.dart` (no ```dart block changed: expected `All tests passed!`).
  2. `docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md`: insert before `## Risks`:

```markdown
## Amendments

From the 3a spec
([2026-10-15-architecture-kit-design.md](2026-10-15-architecture-kit-design.md),
"Amendments to other specs"), each written by the task that lands it.

- **P3, property specs and the section builder** (3a C1.1, C1.7): a spec
  is bound with the object it is shown for (`PlanObject`: document,
  handle, world and the kit's words; none for a tool's settings); `TextDisplay` is a read-only
  line read from the object, omitted when it reads nothing;
  `LengthProperty.range` bounds a length by the object, inclusive, a null
  range refusing every value; every spec takes `visible`, evaluated when
  it is bound, and a hidden field takes no room; an action whose gate the
  permissions refuse is hidden, not read-only. The escape hatch is
  `(context, PlanSection<T>)`, the section holding the value, the commit,
  the words, the object and the kit's services. `PlanKit.validate` refuses
  a `TextDisplay` or a `range` in a tool's settings (`settingsNeedObject`).
```

  3. `docs/superpowers/specs/2026-10-13-kit-contract-design.md`, the section Task 1 made, a second bullet:

```markdown
- **Object views and hidden fields** (3a C1.1, C1.7): the surface gains
  `PlanObject`, `DocumentPlanObject`, `TextDisplay`,
  `LengthProperty.range`, `PropertySpec.visible`,
  `PropertyField.visible`, `PlanSection` (the escape hatch's one context)
  and `KitProblemCode.settingsNeedObject`; `PlanType.fieldsOf`,
  `commitField` and `sectionFor` take a `DraftDocument`, and `fieldsOf`
  and `commitField` the kit's words, which the object carries
  (`PlanObject.words`, a `PlanWords`: the pure interface `KitWords` now
  implements, exported by both libraries).
```

- [ ] **Step 8: The gates.** From the repository root:
  - `cd packages/jet_cad_2d_kit && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0.
  - `cd packages/jet_cad_2d_plan && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .` — the same.
  - `dart run tool/ci/check_kit_deps.dart` — exit 0.
  - `git status --short`: only this task's files.

- [ ] **Step 9: Commit.**

```bash
git add packages/jet_cad_2d_kit/lib/src/kit/properties.dart packages/jet_cad_2d_kit/lib/src/kit/plan_type.dart packages/jet_cad_2d_kit/lib/src/kit/plan_kit.dart packages/jet_cad_2d_kit/lib/src/model/kit_problem.dart packages/jet_cad_2d_kit/test/kit/object_view_test.dart packages/jet_cad_2d_kit/test/kit/plan_type_test.dart packages/jet_cad_2d_kit/test/kit/example_code_test.dart packages/jet_cad_2d_kit/lib/src/model/plan_words.dart packages/jet_cad_2d_kit/lib/src/model/model.dart packages/jet_cad_2d_kit/lib/src/kit/plan_services.dart packages/jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart packages/jet_cad_2d_plan/test/controller/covariance_test.dart packages/jet_cad_2d_plan/test/support/object_kit.dart packages/jet_cad_2d_plan/test/support/panel_kits.dart packages/jet_cad_2d_plan/test/support/test_kit.dart packages/jet_cad_2d_plan/test/support/throwing_kit.dart packages/jet_cad_2d_plan/test/panels/object_view_panel_test.dart docs/kits.md docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md docs/superpowers/specs/2026-10-13-kit-contract-design.md
git commit -m "$(cat <<'EOF'
feat(kit): object views for properties and sections; hidden fields (spec 3a C1.1, C1.7)

A property spec is bound with the object it is shown for, its kit's
words included: TextDisplay
reads a line from it (omitted when it reads nothing), a length's range
is read from it at the commit, and every spec takes visible. The escape
hatch takes one PlanSection with the object and the kit's services.
PlanKit.validate refuses an object-reading spec in a tool's settings.
The panel shows the text line, gives a hidden field no room and hides an
action whose gate is refused; the throwing kit covers the new hooks.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 10: Mutation check** (committed files only; after each: run the named test, see it red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). Kit: `cd packages/jet_cad_2d_kit && flutter test test/kit/object_view_test.dart`; plan: `cd packages/jet_cad_2d_plan && flutter test test/panels/object_view_panel_test.dart`.
  - M-PO-world `jet_cad_2d_kit/lib/src/kit/properties.dart`: `document.tree.accumulatedTransform(handle)` → `(document.tree[handle]! as GroupNode).transform` (and add `GroupNode` to the `show` list) → PO-object red.
  - M-PO-null `properties.dart`: in `TextDisplay.bind`, `shown: text != null` → `shown: true` → PO-display and PO-panel-display red.
  - M-PO-no-object `properties.dart`: delete `if (object == null) _noObject(wordId);` from `TextDisplay.bind` and write `read(owner, object!)` → PO-display-no-object red (a `TypeError`, not an `ArgumentError` named `object`).
  - M-PO-range `properties.dart`: delete the `if (range != null) { ... }` block from `LengthProperty.bind`'s commit → PO-range (kit) and PO-range (plan) red.
  - M-PO-range-null `properties.dart`: `if (allowed == null) { throw ... }` → `if (allowed == null) return write(owner, v);` → PO-range (kit) and PO-range (plan, the stray bead) red.
  - M-PO-visible `properties.dart`: in `_BoundField`'s factory, `final visible = shown && (spec.visible?.call(owner) ?? true);` → `final visible = shown;` → PO-visible and PO-hidden red.
  - M-PO-fields `jet_cad_2d_kit/lib/src/kit/plan_type.dart`: in `fieldsOf`, drop `, object: object` → PO-fields red (the display throws `ArgumentError` named `object`).
  - M-PO-section `plan_type.dart`: in `sectionFor`, `DocumentPlanObject(document, group, words)` → `DocumentPlanObject(document, document.rootHandle, words)` → PO-section (kit) red.
  - M-PO-words `plan_type.dart`: in `fieldsOf`, `DocumentPlanObject(document, group, words)` → `DocumentPlanObject(document, group, KitNamesWords(KitNames.empty, () => const Locale('en')))` (with `import 'dart:ui' show Locale;` and the model import) → PO-words red (`'type:test.slab'`, not `'Platte'`).
  - M-PO-object-words `properties.dart`: `DocumentPlanObject`'s `words` field → a getter `PlanWords get words => _NoWords();` with a file-private `final class _NoWords implements PlanWords` answering every `word` with its id and every `maybe` with null (the constructor's parameter kept, unused: `DocumentPlanObject(this.document, this.handle, PlanWords _)`) → PO-object red.
  - M-PO-pure `jet_cad_2d_kit/lib/src/kit/properties.dart`: `import '../model/plan_words.dart';` → `import 'plan_services.dart' show KitWords;` with `PlanWords` → `KitWords` in the file → `test/invariants/purity_test.dart` P9 red (the reason for R-P7).
  - M-PO-panel-words `jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart`: in `_fieldsOrNull`, `c.servicesOf(kitOfKey(typeId)).words` → `c.servicesOf(c.kits.kits.first.id).words` (the box kit's) → PO-panel-display red (`'type:view.rail'`, not `'Rail'`).
  - M-PO-validate `jet_cad_2d_kit/lib/src/kit/plan_kit.dart`: delete the settings loop added in Step 3.4 → PO-validate red.
  - M-PO-cov `plan_kit.dart`: `if (spec.needsObject) {` → `if (spec is TextDisplay || (spec is LengthProperty && spec.range != null)) {` → PO-validate-cov red (a `TypeError`).
  - M-PO-panel-row `jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart`: the `TextDisplay` row's `field.value as String? ?? ''` → `''` → PO-panel-display red.
  - M-PO-hidden `plan_property_panel.dart`: in `_shows`, delete `if (!field.visible) return false;` → PO-hidden and PO-panel-display (the Turn line) red.
  - M-PO-gate-hidden `plan_property_panel.dart`: `_shows` returns after the visible check (`return true;` in place of the gate expression) → PO-gate-hidden red (the button shows, disabled).
  - M-PO-services `plan_property_panel.dart`: the `sectionFor` call's last argument `c.servicesOf(kit)` → `c.servicesOf(c.kits.kits.first.id)` (the box kit's) → PO-section (plan) red (`type:view.rail` is not the box kit's word).
  - M-PO-G-display `properties.dart`: make the display lazy: in `TextDisplay.bind`, bind `value` to null with `shown: true` and give `_BoundField` the read as a closure evaluated in its `value` getter (outside `bind`) → PO-G-display red (the build throws: `takeException` is not null).
  - M-PO-G-visible `properties.dart`: make `visible` lazy (a getter on `_BoundField` calling `spec.visible?.call(owner)`, the owner kept) → PO-G-visible red.
  - M-PO-G-range `properties.dart`: evaluate the range in `LengthProperty.bind`, before the field is made (`final allowed = range?.call(owner, object!);`) and check against it at the commit → PO-G-range red (the section is replaced by the failed box when `range` throws).

  Quote each red line.

#### Interface problem

Resolved by ruling R-P7: `PlanObject.words` is the pure `PlanWords` (`lib/src/model/plan_words.dart`), which `KitWords` implements, so `properties.dart` stays free of Flutter and the 2a purity test P9 is unchanged (M-PO-pure pins why).

---

