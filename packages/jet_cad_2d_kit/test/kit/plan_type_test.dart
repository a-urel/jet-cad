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
