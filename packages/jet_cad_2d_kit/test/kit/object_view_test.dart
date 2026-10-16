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
    final (:doc, catalog: _) =
        objectDocument([slabType(), postType()], post: const Post(width: 600));
    tearDownAll(doc.dispose);
    final slabObject = DocumentPlanObject(doc, hSlab, words);
    PropertyField bound(String id, {Slab owner = const Slab()}) => viewSpecs()
        .firstWhere((s) => s.id == id)
        .bind(owner, wordId: 'property:test.slab.$id', object: slabObject);

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
      final bare = viewSpecs().firstWhere((s) => s.id == 'turn').bind(
          const Slab(),
          wordId: 'w',
          object: DocumentPlanObject(doc, hBare, words));
      expect(bare.value, isNull);
      expect(bare.visible, isFalse);
    });

    test('PO-display-no-object a text display bound without an object', () {
      final spec = viewSpecs().firstWhere((s) => s.id == 'owner');
      // M-PO-no-object: `read(owner, object!)` (a TypeError, not a refusal).
      expect(() => spec.bind(const Slab(), wordId: 'property:test.slab.owner'),
          refusedOn('object'));
      final ranged = viewSpecs().firstWhere((s) => s.id == 'width');
      expect(
          () => ranged.bind(const Slab(), wordId: 'property:test.slab.width'),
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
      final (doc: lone, catalog: _) = objectDocument([slabType(), postType()],
          post: const Post(width: 600));
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
      doc.commands
          .execute(types[0].commitField(doc, hSlab, width, 2400, words));
      expect(doc.components.get<Slab>(hSlab)!.width, 2400);
      // The post narrows: the same field, committed again, meets the new
      // range (commitField binds again, to the object, now).
      doc.commands.execute(SetComponentCommand<Post>(
          hPost, const Post(width: 400, shape: 'round')));
      expect(() => types[0].commitField(doc, hSlab, width, 1800, words),
          refusedOn('width'));
      doc.commands
          .execute(types[0].commitField(doc, hSlab, width, 1600, words));
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
          builder: (context) => types[0].sectionFor(
              context, doc, hSlab, executed.add, words, services)!));
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
      // M-PO-cov: validate reading `spec is LengthProperty<Object> &&
      // spec.range != null` instead of `needsObject` throws a TypeError
      // here.
      final List<PropertySpec<Object>> held = [
        LengthProperty<Slab>(
            id: 'reach',
            read: (s) => s.width,
            write: (s, v) => s,
            range: besidePost),
      ];
      expect(() => held.single.needsObject, returnsNormally);
      expect([
        for (final p in kitWith(held.cast<PropertySpec<Slab>>()).validate())
          p.code
      ], [
        KitProblemCode.settingsNeedObject
      ]);
    });
  });
}
