// Spec 2a P4 "The kit set": validateKitSet refuses a set with one
// ArgumentError (KitSetError) that lists every problem with its code, in
// load order; a sound set is held in load order.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show ParametricCatalog;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/test_kit.dart';

/// The codes [kits] are refused with, in order; empty when accepted.
List<KitProblemCode> codesOf(List<PlanKit> kits) {
  try {
    validateKitSet(kits);
  } on KitSetError catch (e) {
    return [for (final p in e.problems) p.code];
  }
  return const [];
}

KitSetError errorOf(List<PlanKit> kits) {
  try {
    validateKitSet(kits);
  } on KitSetError catch (e) {
    return e;
  }
  fail('the set was accepted');
}

void main() {
  test('KS1 a sound set is held in load order: kits, types, tools, lookups',
      () {
    final slab = testKit();
    final disc = discKit();
    final set = validateKitSet([slab, disc]);
    // M-KS1: the kits sorted by id ('disc' before 'test').
    expect([for (final k in set.kits) k.id], ['test', 'disc']);
    expect([for (final t in set.types) t.id], ['test.slab', 'disc.round']);
    expect([for (final t in set.tools) t.id], ['test.slab']);
    expect(set.kitOf('disc'), same(disc));
    expect(set.kitOf('plan'), isNull);
    expect(set.typeOf('disc.round'), same(disc.types.single));
    expect(set.typeOf('test.reader'), isNull);
    expect(validateKitSet(const []).kits, isEmpty);
  });

  test('KS2 two kits with one id: duplicateKit, once, naming the id', () {
    final e = errorOf([testKit(), testKit(version: '2.0.0')]);
    // M-KS2: the duplicate-kit check removed.
    expect([for (final p in e.problems) p.code], [KitProblemCode.duplicateKit]);
    expect(e.problems.single.message, contains('"test"'));
  });

  test('KS3 the reserved ids plan and jetcad', () {
    // M-KS3: reservedKitIds = {'plan'}.
    expect(
        codesOf([
          const PlanKit(id: 'plan', version: '1.0.0'),
          const PlanKit(id: 'jetcad', version: '1.0.0'),
        ]),
        [KitProblemCode.reservedKitId, KitProblemCode.reservedKitId]);
  });

  test("KS4 a type id another kit already gave: duplicateType, once", () {
    final e = errorOf([
      testKit(),
      PlanKit(id: 'ex', version: '1.0.0', types: [slabType()]),
    ]);
    final codes = [for (final p in e.problems) p.code];
    // M-KS4: the cross-kit type check removed.
    expect(codes.where((c) => c == KitProblemCode.duplicateType), hasLength(1));
    // The kit's own validate() finds the type outside its id (Task 4).
    expect(codes, contains(KitProblemCode.typeOutsideKit));
    final duplicate = e.problems
        .singleWhere((p) => p.code == KitProblemCode.duplicateType)
        .message;
    expect(duplicate,
        allOf(contains('test.slab'), contains('"ex"'), contains('"test"')));
  });

  test("KS5 a tool id another kit already gave: duplicateTool, once", () {
    final codes = codesOf([
      testKit(),
      PlanKit(id: 'ex', version: '1.0.0', tools: [slabTool()]),
    ]);
    // M-KS5: the cross-kit tool check removed.
    expect(codes.where((c) => c == KitProblemCode.duplicateTool), hasLength(1));
    expect(codes, contains(KitProblemCode.toolOutsideKit));
  });

  test('KS6 a duplicate inside one kit is reported once, by its validate()',
      () {
    final codes = codesOf([
      PlanKit(
          id: 'test',
          version: '1.0.0',
          types: [slabType(), slabType()],
          names: testWords),
    ]);
    // M-KS6: the cross-kit check also counts an earlier occurrence in the
    // same kit (`typeKits.containsKey(type.id)` in place of `first !=
    // kit.id`): two duplicateType.
    expect(codes.where((c) => c == KitProblemCode.duplicateType), hasLength(1));
  });

  test('KS7 a type that both contributes and reads places: typePlaceConflict',
      () {
    // Premise: the engine itself refuses this type.
    expect(
        () => ParametricCatalog().register<ReaderComponent>(
            readerTypeId, ReaderComponent.fromJson, const ReaderType()),
        throwsArgumentError);
    final e = errorOf([conflictKit()]);
    // M-KS7: the conflict check removed.
    expect([for (final p in e.problems) p.code],
        [KitProblemCode.typePlaceConflict]);
    expect(e.problems.single.message, contains('test.reader'));
  });

  test("KS8 each kit's own validate() problems, prefixed by its id", () {
    final e = errorOf([testKit(version: ' ')]);
    // M-KS8: the kits' validate() not called.
    expect([for (final p in e.problems) p.code], [KitProblemCode.emptyVersion]);
    expect(e.problems.single.message, startsWith('test: '));
  });

  test('KS9 every problem in one ArgumentError, in load order, one line each',
      () {
    final e = errorOf([
      const PlanKit(id: 'plan', version: '1.0.0'),
      testKit(),
      testKit(version: '2.0.0'),
      conflictKit(),
    ]);
    // M-KS9: throw at the first problem found.
    expect([
      for (final p in e.problems) p.code
    ], [
      KitProblemCode.reservedKitId,
      KitProblemCode.duplicateKit,
      KitProblemCode.duplicateKit,
      KitProblemCode.typePlaceConflict,
    ]);
    expect(e, isA<ArgumentError>());
    expect(e.name, 'kits');
    final lines = (e.message as String).split('\n').skip(1).toList();
    expect(lines, [for (final p in e.problems) '  $p']);
  });
}
