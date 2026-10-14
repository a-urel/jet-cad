// Spec K5: the PlanKit descriptor's symbol part and its validation.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show Component;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../support/code_fixtures.dart';
import '../support/plan_type_fixtures.dart';
import '../support/tool_fixtures.dart';

List<KitProblemCode> codes(PlanKit kit) =>
    [for (final p in kit.validate()) p.code];

void main() {
  test('K1 a const descriptor with its defaults', () {
    const kit = PlanKit(id: 'sample', version: '0.1.0');
    expect(kit.symbols, isEmpty);
    expect(kit.types, isEmpty);
    expect(kit.tools, isEmpty);
    expect(kit.attachments, isEmpty);
    expect(kit.propertyIds, isEmpty);
    expect(identical(kit.names, KitNames.empty), isTrue);
    expect(kit.validate(), isEmpty);
  });

  test('K2 a sound kit validates: own words, categories, English present', () {
    const kit = PlanKit(
      id: 'sample',
      version: '0.3.1',
      names: KitNames({
        'en': {
          'tool:sample.wall': 'Wall',
          'type:sample.wall': 'Wall',
          'property:sample.wall.height': 'Height',
        },
        'tr': {
          'symbol:sample.table.round': 'Yuvarlak masa',
          'category:sample/Tables': 'Masalar',
          'tool:sample.wall': 'Duvar',
          'property:sample.wall.height': 'Yükseklik',
        },
      }),
    );
    expect(kit.validate(), isEmpty);
  });

  test('K3 a bad id and an empty version', () {
    // M-K3a: drop the id check. M-K3b: test `version.isEmpty` only.
    expect(codes(const PlanKit(id: 'Sample', version: '0.1.0')),
        [KitProblemCode.badKitId]);
    expect(codes(const PlanKit(id: 'my-kit', version: '0.1.0')),
        [KitProblemCode.badKitId]);
    expect(codes(const PlanKit(id: 'sample', version: ' ')),
        [KitProblemCode.emptyVersion]);
  });

  test("K4 a word id under another kit's id, in every namespace", () {
    for (final id in [
      'symbol:other.table.round',
      'tool:other.wall',
      'type:other.wall',
      'property:other.wall.height',
      'tool:wall', // no kit segment at all
      // The kit's own id with no name. M-K4c: drop `!rest.contains('.')`.
      'tool:sample',
      'category:other/Tables', // M-K4b: categories exempt from the check
      'category:Tables', // no kit at all
    ]) {
      final kit = PlanKit(
          id: 'sample',
          version: '0.1.0',
          names: KitNames({
            'en': {id: 'x'},
          }));
      // M-K4: check the symbol namespace only.
      expect(codes(kit), [KitProblemCode.foreignWordId], reason: id);
      expect(kit.validate().single.message, contains(id));
    }
  });

  test('K5 a word id in no known namespace', () {
    const kit = PlanKit(
        id: 'sample',
        version: '0.1.0',
        names: KitNames({
          'tr': {'label:sample.x': 'x', 'sample.table.round': 'y'},
        }));
    expect(codes(kit),
        [KitProblemCode.unknownWordId, KitProblemCode.unknownWordId]);
  });

  test('K6 a tool, type or property word without English', () {
    const kit = PlanKit(
        id: 'sample',
        version: '0.1.0',
        names: KitNames({
          'tr': {
            'tool:sample.wall': 'Duvar',
            'symbol:sample.table.round': 'Yuvarlak masa',
            'category:sample/Tables': 'Masalar',
          },
        }));
    // M-K6: drop the English check; a symbol or category word needs none.
    expect(codes(kit), [KitProblemCode.missingEnglish]);
    expect(kit.validate().single.message, contains('tool:sample.wall'));
  });

  group('the code side (spec 2a P1)', () {
    /// Every word the code kit needs, in English, and some in Turkish.
    const Map<String, String> english = {
      'type:test.slab': 'Slab',
      'type:test.slab.raised': 'Raised slab',
      'type:test.post': 'Post',
      'tool:test.slab': 'Slab',
      'tool:test.post': 'Post',
      'property:test.slab.width': 'Width',
      'property:test.slab.turn': 'Turn',
      'property:test.slab.grade': 'Grade',
      'property:test.slab.finish': 'Finish',
      'property:test.slab.finish.oiled': 'Oiled',
      'property:test.slab.finish.waxed': 'Waxed',
      'property:test.slab.finish.raw': 'Raw',
      'property:test.slab.raised': 'Raised',
      'property:test.slab.label': 'Label',
      'property:test.slab.area': 'Area',
      'property:test.slab.flip': 'Flip',
      'property:test.post.width': 'Width',
      'property:test.post.shape': 'Shape',
      'property:test.post.shape.round': 'Round',
      'property:test.post.shape.square': 'Square',
      'property:test.post.round': 'Round',
    };

    PlanKit codeKit({
      List<PlanType<Component>>? types,
      List<PlanTool>? tools,
      Map<String, String> en = english,
      Map<String, String> tr = const {'type:test.slab': 'Tezgâh'},
    }) =>
        PlanKit(
          id: 'test',
          version: '0.2.0',
          types: types ?? [slabType(), postType()],
          tools: tools ?? [slabTool(), postTool()],
          names: KitNames({'en': en, 'tr': tr}),
        );

    test('PT14 a sound code kit validates; its property ids', () {
      // A positive control for PT15-PT18, and the id list pinned.
      final kit = codeKit();
      expect(kit.validate(), isEmpty);
      // M-PT14: leave a choice's values out of propertyIds (PT17 too).
      expect(kit.propertyIds, [
        'test.slab.width',
        'test.slab.turn',
        'test.slab.grade',
        'test.slab.finish',
        'test.slab.finish.oiled',
        'test.slab.finish.waxed',
        'test.slab.finish.raw',
        'test.slab.raised',
        'test.slab.label',
        'test.slab.area',
        'test.slab.flip',
        'test.post.width',
        'test.post.shape',
        'test.post.shape.round',
        'test.post.shape.square',
        'test.slab.width',
        'test.slab.finish',
        'test.slab.finish.oiled',
        'test.slab.finish.raw',
        'test.post.round',
      ]);
    });

    test('PT15 a type or tool id that is not <kit>.<name>', () {
      for (final id in [
        'other.slab',
        'slab',
        'test.',
        'test.Slab',
        'test..slab',
      ]) {
        final type = PlanType<Slab>(
            id: id, fromJson: Slab.fromJson, parametric: LoggingType<Slab>());
        // M-PT15a: drop the id check. M-PT15b: test `kitOfKey` only
        // ('test.', 'test.Slab' and 'test..slab' pass).
        final typeProblems = codeKit(types: [type]).validate();
        expect([
          for (final p in typeProblems) p.code
        ], [
          KitProblemCode.typeOutsideKit
        ], reason: id);
        expect(typeProblems.single.message, contains('"$id"'));
        expect(codes(codeKit(types: const [], tools: [slabTool(id: id)])),
            [KitProblemCode.toolOutsideKit],
            reason: id);
      }
    });

    test('PT16 a type or tool id given twice', () {
      // M-PT16: drop the `seen.add` check.
      expect(codes(codeKit(types: [slabType(), postType(), slabType()])),
          [KitProblemCode.duplicateType]);
      expect(codes(codeKit(tools: [postTool(), slabTool(), postTool()])),
          [KitProblemCode.duplicateTool]);
    });

    test('PT17 every word a type, tool or property needs has English', () {
      for (final wordId in [
        'type:test.post',
        'tool:test.slab',
        'property:test.slab.width',
        'property:test.slab.finish.waxed',
        'property:test.post.round',
      ]) {
        final kit = codeKit(en: {...english}..remove(wordId));
        // M-PT17a: drop the declared type and tool words. M-PT17b: drop the
        // property ids from the needed words.
        expect(codes(kit), [KitProblemCode.missingEnglish], reason: wordId);
        expect(kit.validate().single.message, contains('"$wordId"'));
      }
    });

    test('PT18 a word missing from English is one problem, not two', () {
      // The Turkish 'type:test.slab' and the declared type both need the
      // same English word. M-PT18: report the words loop's need and the
      // declared one separately.
      final kit = codeKit(en: {...english}..remove('type:test.slab'));
      expect(codes(kit), [KitProblemCode.missingEnglish]);
    });
  });
}
