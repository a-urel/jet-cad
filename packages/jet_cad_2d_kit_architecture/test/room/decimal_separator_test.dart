// Spec Q0 (the plan's decimal separator) T2: a page's separator reaches
// the stored texts.
//
// - M-Q0-a (`Q0-S1`): switching the page to `comma` rewrites the room's
//   area TEXT and the dimension's value TEXT in one history entry (the two
//   `pageKey`s, F-3); Undo restores the encoding byte for byte, Redo the
//   commas.
//
// The fixture follows the spec's fixture rule: a page at cm and 1:20, its
// origin off zero; a room off the origin, turned, whose area has a nonzero
// fraction (12.37 m²); a dimension off the origin in a turned group of its
// own, whose length has a nonzero fraction (345.7 cm); `comma` against
// `point`.
// Ported from jet_cad_floor_plan/test/decimal_separator_test.dart (Q0-S1,
// Q0-S2; Q0-E1 to Q0-E3b run in jet_cad_2d_integration) for the
// architecture kit (3a Task 27, Appendix A D-32); assertions unchanged.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension.dart';

import '../support/dimension_fixture.dart';

/// A box of four 200 mm centred walls, centrelines (0, 0)-(4,050, 3,413):
/// inner faces x 100..3,950, y 100..3,313, 3,850 × 3,213 = 12,370,050 mm²,
/// 12.37005 m² (0.00495 from the tie 12.375).
const List<W> q0Walls = [
  W(0, 0, 4050, 0, 200),
  W(4050, 0, 4050, 3413, 200),
  W(4050, 3413, 0, 3413, 200),
  W(0, 3413, 0, 0, 200),
];

/// The fixture's page: cm at 1:20, its origin off zero, grid snap off (so a
/// tool click resolves to its raw point), the separator `point`.
final PageComponent q0Page = PageComponent(
    originX: -4180.5,
    originY: 2645.25,
    scaleDenominator: 20,
    displayUnit: DisplayUnit.centimeters,
    snapToGrid: false);

/// The fixture: [q0Walls] at the corpus far origin turned 23° ([corpus]),
/// [q0Page], a room `Kitchen` seeded at plan (1,500.25, 1,700.75), and an
/// aligned dimension in a root group of its own at plan (600.5, 4,400.25)
/// turned a further 0.4 rad, from local (−120.5, 40.25) to (3,336.8,
/// 40.25): 3,457.3 mm, 3,457 tenths of a cm (0.2 from the half), 345.7.
/// The dimension sits above the box (plan y 4,400 > 3,413 + 100).
({Plan plan, Handle room, Handle dim}) q0Plan(
    {TextMeasurer measurer = const InsertionPointMeasurer()}) {
  final plan = buildPlan(q0Walls, place: corpus, measurer: measurer);
  attachPage(plan.doc, q0Page);
  final room = addRoom(plan.doc, plan.at(1500.25, 1700.75), 'Kitchen');
  final dim = addDimension(
      plan.doc, const FixedEnd(-120.5, 40.25), const FixedEnd(3336.8, 40.25),
      offset: 300.25,
      at: corpus.m
          .multiply(Transform2.translation(600.5, 4400.25))
          .multiply(Transform2.rotation(0.4)));
  return (plan: plan, room: room, dim: dim);
}

/// [doc]'s page with separator [s], one command, as the Page panel's `_set`
/// makes it.
DraftCommand separatorTo(DraftDocument doc, DecimalSeparator s) =>
    SetComponentCommand<PageComponent>(
        doc.rootHandle, pageOf(doc).copyWith(decimalSeparator: s));

void main() {
  test(
      'Q0-S1 a switch to comma rewrites the area and the dimension value in '
      'one undo step; Undo restores the bytes, Redo the commas', () {
    final f = q0Plan();
    final doc = f.plan.doc;
    // Premises: the fixture is what it says, and prints with a point.
    final g = doc.tree.accumulatedTransform(f.dim);
    expect(g.b, isNot(0), reason: 'premise: the dimension group is turned');
    expect(pageOf(doc).decimalSeparator, DecimalSeparator.point);
    expect(labelStrings(doc, f.room), ['Kitchen', '12.37 m²']);
    expect(dimText(doc, f.dim), '345.7');
    expect(driftOf(doc), isEmpty);
    final before = enc(doc);
    final depth = doc.commands.undoDepth;
    final roomKids = kids(doc, f.room), dimKids = kids(doc, f.dim);

    doc.commands.execute(separatorTo(doc, DecimalSeparator.comma));
    expect(doc.commands.undoDepth, depth + 1, reason: 'one history entry');
    expect(labelStrings(doc, f.room), ['Kitchen', '12,37 m²']);
    expect(dimText(doc, f.dim), '345,7');
    expect(kids(doc, f.room), roomKids, reason: 'rewritten in place');
    expect(kids(doc, f.dim), dimKids, reason: 'rewritten in place');
    expect(driftOf(doc), isEmpty);
    final after = enc(doc);

    doc.commands.undo();
    expect(enc(doc), before, reason: 'Undo restores the bytes');
    expect(labelStrings(doc, f.room), ['Kitchen', '12.37 m²']);
    expect(dimText(doc, f.dim), '345.7');

    doc.commands.redo();
    expect(labelStrings(doc, f.room), ['Kitchen', '12,37 m²']);
    expect(dimText(doc, f.dim), '345,7');
    expect(enc(doc), after, reason: 'Redo gives the comma bytes again');
    expect(driftOf(doc), isEmpty);
  });

  test(
      'Q0-S2 at feet-and-inches the stored area prints the page\'s comma '
      '(F-1: formatArea swaps in every unit; the final review\'s F-3)', () {
    final f = q0Plan();
    final doc = f.plan.doc;
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle,
        pageOf(doc).copyWith(
            displayUnit: DisplayUnit.feetInches,
            decimalSeparator: DecimalSeparator.comma)));
    expect(labelStrings(doc, f.room), ['Kitchen', '133,15 ft²']);
    doc.commands.undo();
    expect(labelStrings(doc, f.room), ['Kitchen', '12.37 m²']);
  });
}
