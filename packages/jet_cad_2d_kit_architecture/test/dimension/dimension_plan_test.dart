// 3a Task 21, spec C3.6, C1.1, C1.5: the dimension as a plan type. Its five
// fields over the object (the value as drawn, memoised by the history
// state; the kind, gated by reshape; the axes line in the words' language
// with their decimal separator, omitted when not turned; the two end
// lines in words), and its grips over the plan's services: F3 and the live
// types are the services' (spec C1.5: a frozen wall attaches nothing).
// Today's section: jet_cad_floor_plan/lib/src/selection_panel.dart:846-976.
// Every fixture is C2's L at the corpus far origin, each wall in its own
// turned group, on a 1:50 mm page.
import 'dart:math' as math;
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension.dart';
import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension_plan.dart';
import 'package:jet_cad_2d_kit_architecture/src/words/words.dart'
    show architectureNames;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/dimension_fixture.dart';

const l = WallSide.left, r = WallSide.right;

/// The kit's words in [language], with [separator] as the UI's decimal
/// separator.
KitWords wordsIn(String language, {String separator = '.'}) =>
    KitNamesWords(architectureNames, () => Locale(language),
        decimalSeparator: () => separator);

/// [h]'s fields as the plan's panel binds them (spec C1.1).
List<PropertyField> fieldsOf(DraftDocument doc, Handle h, KitWords words) =>
    dimensionPlanType.fieldsOf(doc, h, words);

PropertyField fieldOf(List<PropertyField> fields, String id) =>
    fields.singleWhere((f) => f.spec.id == id);

/// C2's L at the corpus far origin in own groups, on a 1:50 mm page.
Plan lPlan() {
  final plan = buildPlan(c2Walls, place: corpusGroups);
  attachPage(plan.doc, mmPage);
  return plan;
}

/// The placement turned [deg] further: a dimension group's transform.
Transform2 turned(double deg) =>
    corpusGroups.m.multiply(Transform2.rotation(deg * math.pi / 180));

void main() {
  test(
      'DM-fields five fields in order under property:architecture.dimension, '
      'the kind gated by reshape; the value as drawn; no axes line for '
      'aligned; the end lines in words (M-DM1, M-DM2)', () {
    final plan = lPlan();
    final doc = plan.doc;
    final [a, _] = plan.walls;
    // DO3's d1: A/0/right (0, −100) → A/1/right, the outer mitre (4100,
    // −100), aligned, offset −612.25: 4100.
    final d = addDimension(doc, AttachedEnd(a, 0, r), AttachedEnd(a, 1, r),
        offset: -612.25, at: corpusGroups.m);
    final fields = fieldsOf(doc, d, wordsIn('en'));
    const ids = ['value', 'kind', 'axes', 'end-1', 'end-2'];
    expect([for (final f in fields) f.spec.id], ids);
    expect([for (final f in fields) f.wordId],
        [for (final id in ids) 'property:architecture.dimension.$id']);
    expect(fieldOf(fields, 'kind').spec.gate, PlanGate.reshape);
    expect(fieldOf(fields, 'value').spec.gate, isNull);
    expect(fieldOf(fields, 'value').value, '4100');
    expect(fieldOf(fields, 'value').commit, isNull, reason: 'read-only');
    expect(fieldOf(fields, 'kind').value, DimKind.aligned);
    expect(fieldOf(fields, 'axes').visible, isFalse,
        reason: 'aligned: no axes line');
    expect(
        fieldOf(fields, 'end-1').value, 'Wall ${a.toHex()}, start, right face');
    expect(
        fieldOf(fields, 'end-2').value, 'Wall ${a.toHex()}, end, right face');

    // The kind's commit: only the kind changes (R-27), one command.
    final p0 = doc.components.get<DimensionParams>(d)!;
    final command = dimensionPlanType.commitField(
        doc, d, fieldOf(fields, 'kind'), DimKind.horizontal, wordsIn('en'));
    doc.commands.execute(command);
    expect(doc.components.get<DimensionParams>(d),
        p0.copyWith(kind: DimKind.horizontal));
  });

  test(
      'DM-value the value as drawn, read once per history state; a wall '
      'edit re-reads it; a broken dimension reads — (M-DM3, M-DM4)', () {
    final plan = lPlan();
    final doc = plan.doc;
    final [a, _] = plan.walls;
    // PN1's dimension: A/0/left (0, 100) to the plan point (3450.6, 100):
    // 3450.6 mm, which reads 3451.
    final d = addDimension(doc, AttachedEnd(a, 0, l),
        fixedAt(plan.at(3450.6, 100), corpusGroups.m),
        kind: DimKind.aligned, offset: 400.25, at: corpusGroups.m);
    final broken = addDimension(doc, AttachedEnd(a, 2, l),
        fixedAt(plan.at(3450.6, 100), corpusGroups.m),
        kind: DimKind.aligned, offset: 400.25, at: corpusGroups.m);
    final words = wordsIn('en');
    String? value(Handle h) =>
        fieldOf(fieldsOf(doc, h, words), 'value').value as String?;

    expect(value(d), '3451');
    final scans = debugDimensionValueScans;
    expect(value(d), '3451');
    expect(value(d), '3451');
    expect(debugDimensionValueScans, scans, reason: 'one state: no rescan');

    // A moved 500.25 along the plan's −x (its joint with B broken): A/0/left
    // is (−500.25, 100), the value 3950.85, which reads 3951 (PN1).
    final t = corpusGroups.m.transformDirection(Vector2(-500.25, 0));
    doc.commands.execute(TransformNodeCommand(
        a, Transform2.translation(t.x, t.y).multiply(doc.tree[a]!.transform)));
    expect(dimText(doc, d), '3951', reason: 'premise: regenerated');
    expect(value(d), '3951', reason: 'a new state is read');
    expect(debugDimensionValueScans, scans + 1);

    expect(kids(doc, broken), isEmpty, reason: 'premise: broken (D15)');
    expect(value(broken), '—');
  });

  test(
      'DM-axes the axes line in the words\' language with their decimal '
      'separator; the end lines in Turkish (M-DM5, M-DM6)', () {
    final plan = lPlan();
    final doc = plan.doc;
    final [a, _] = plan.walls;
    // Horizontal in a group turned 30° past the placement's 23°: the world
    // rotation is 53°, which reads 53.0.
    final d = addDimension(
        doc, AttachedEnd(a, 1, r), const FixedEnd(1000.25, 1500.5),
        kind: DimKind.horizontal, offset: 300.5, at: turned(30));
    expect(fieldOf(fieldsOf(doc, d, wordsIn('en')), 'axes').value,
        'Axes turned 53.0°');
    expect(
        fieldOf(fieldsOf(doc, d, wordsIn('de', separator: ',')), 'axes').value,
        'Achsen um 53,0° gedreht');
    final tr = fieldsOf(doc, d, wordsIn('tr', separator: ','));
    expect(fieldOf(tr, 'axes').value, 'Eksenler 53,0° döndürülmüş');
    expect(fieldOf(tr, 'axes').visible, isTrue);
    expect(fieldOf(tr, 'end-1').value, 'Duvar ${a.toHex()}, bitiş, sağ yüzey');
    expect(fieldOf(tr, 'end-2').value, 'Sabit');
  });

  test(
      'DM-grips the type\'s grips read the plan\'s services: F3 off fixes the '
      'dropped end; a frozen wall attaches nothing (M-DM7, M-DM8)', () {
    final plan = lPlan();
    final doc = plan.doc;
    final [a, _] = plan.walls;
    final g = turned(30);
    FakePlanServices services(
        {bool objectSnap = true, Set<Handle> frozen = const {}}) {
      final s = FakePlanServices(
          document: doc,
          catalog: testCatalog(),
          objectSnap: objectSnap,
          frozen: frozen);
      addTearDown(s.dispose);
      return s;
    }

    // A fresh fixed-fixed dimension; its grip at a dropped on A's free
    // start's left corner (0, 100), A/0/left alone (GE3's premise).
    DimEnd dropA(FakePlanServices s) {
      final d = addDimension(doc, fixedAt(plan.at(500.25, 1500.5), g),
          fixedAt(plan.at(2500.75, 2200.25), g),
          kind: DimKind.aligned, offset: 250.5, at: g);
      final grips = dimensionPlanType.gripsFor(s)!;
      final grip = grips.gripsOf(doc, d)[1];
      doc.commands.execute(grips.drag(doc, d, grip, plan.at(0, 100))!);
      return doc.components.get<DimensionParams>(d)!.a;
    }

    expect(dropA(services()), AttachedEnd(a, 0, l), reason: 'control');
    expect(dropA(services(objectSnap: false)), isA<FixedEnd>(),
        reason: 'F3 off');
    expect(dropA(services(frozen: {a})), isA<FixedEnd>(),
        reason: 'A frozen: no wall end point');
  });

  test(
      'DM-freeze a wall frozen during a grip drag, with no document change: '
      'the very next preview reads the live walls as they are then, not the '
      'per-drag memo of points laid out before (FREEZE RULE, M-DM11)', () {
    List<double> flat(List<(EntityKind, GeometryPayload)> p) =>
        [for (final (_, pl) in p) ...pl.coords];

    // Each drag on its own L, its own services and its own memo: B is
    // frozen between two previews of one drag, the first of which made
    // the memo with B live. The dimension's b is A/1/right: the L's outer
    // mitre (4100, −100) while B is live, A's free end's right corner
    // (4000, −100) once B is frozen.
    for (final (ordinal, x, y, why) in [
      // The offset grip: the line and its extension at b move with b's
      // point, which the memo holds as the dimension stood.
      (0, 1700.5, 900.25, 'the offset grip'),
      // a's grip on the outer mitre: while B is live, A/1/right is there,
      // the most parallel to the group's x (A at 23°, B at 113°, the
      // group at 53°), and equal to b, so the drop is refused and the
      // preview empty. Once B is frozen, A/1/right is (4000, −100) and
      // nothing attaches there: a fixed at the mitre, 100 from b.
      (1, 4100.0, -100.0, 'a\'s grip on the outer mitre'),
    ]) {
      final plan = lPlan();
      final doc = plan.doc;
      final [a, b] = plan.walls;
      final g = turned(30);
      final frozen = <Handle>{};
      final s = FakePlanServices(
          document: doc, catalog: testCatalog(), frozen: frozen);
      addTearDown(s.dispose);
      final d = addDimension(
          doc, fixedAt(plan.at(1200.5, 2600.25), g), AttachedEnd(a, 1, r),
          kind: DimKind.horizontal, offset: -180.25, at: g);
      final grips = dimensionPlanType.gripsFor(s)!;
      final grip = grips.gripsOf(doc, d)[ordinal];
      final q = plan.at(x, y);
      final depth = doc.commands.undoDepth;

      final before = flat(grips.preview(doc, d, grip, q));
      frozen.add(b);
      final after = flat(grips.preview(doc, d, grip, q));
      final fresh =
          flat(dimensionPlanType.gripsFor(s)!.preview(doc, d, grip, q));
      expect(fresh, hasLength(20), reason: '$why: B frozen, five lines');
      expect(fresh, isNot(before), reason: '$why: premise: the freeze shows');
      expect(after, fresh, reason: '$why: the next preview, B frozen');
      expect(doc.commands.undoDepth, depth, reason: '$why: no document change');

      // The drop gathers afresh: b keeps its reference, a is fixed.
      final command = grips.drag(doc, d, grip, q);
      expect(command, isNotNull, reason: '$why: a drop');
      doc.commands.execute(command!);
      expect(doc.components.get<DimensionParams>(d)!.b, AttachedEnd(a, 1, r),
          reason: '$why: b kept');
    }
  });
}
