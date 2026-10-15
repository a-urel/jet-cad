// Spec 3a C3.3, C1.1, C1.7: the opening's PlanType. Its section title by
// kind; its fields over the object (the width strict by kind, the position
// within its host wall's centreline, [0, L], the flips a door's), each
// gated by reshape; its place in the kit. Today's selection panel's Opening
// section is the oracle (jet_cad_floor_plan/lib/src/selection_panel.dart:
// 405-433, 754-758, 1035-1059, 1332-1371).
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/src/box/box.dart';
import 'package:jet_cad_2d_kit_architecture/src/ids.dart';
import 'package:jet_cad_2d_kit_architecture/src/kit.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening_plan.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';

import '../support/opening_fixture.dart';
import '../support/wall_fixture.dart';

const hA = Handle(1000), hBox = Handle(1500);
const hD = Handle(4000), hW = Handle(4100), hG = Handle(4200);
const hQ = Handle(4300), hR = Handle(4400);

/// A (4,000 long in its own space, 200 centred) in a group turned 0.6 rad
/// and scaled 1.25 at the far origin, so its world length (5,000) is not
/// its local one. On it: a door D (hinge end, swing right) in its own
/// turned group, a window W and a gap G. A box, and Q, a window the box
/// hosts. R, a window hosted by D after D was given a `WallParams` straight
/// into the store, as a file brings one in: a group carrying two
/// registered types is the later registration's object, an opening
/// (fix/live-object-rule), so R's host is no wall.
DraftDocument planDoc() {
  final doc = wallDoc();
  doc.commands.execute(addWallLocal(
      doc,
      hA,
      const WallParams(0, 0, 4000, 0, 200, Justification.centre),
      Transform2.translation(ox + 300.5, oy - 700.25)
          .multiply(Transform2.rotation(0.6))
          .multiply(Transform2.scale(1.25, 1.25))));
  doc.commands.execute(addOpening(
      doc,
      hD,
      const OpeningParams(hA, 1500, 900, OpeningKind.door,
          hinge: HingeEnd.end, swing: SwingSide.right),
      at: Transform2.translation(ox + 120, oy - 80)
          .multiply(Transform2.rotation(0.9))));
  doc.commands.execute(addOpening(
      doc, hW, const OpeningParams(hA, 3000, 800, OpeningKind.window)));
  doc.commands.execute(
      addOpening(doc, hG, const OpeningParams(hA, 600, 700, OpeningKind.gap)));
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: hBox,
        parent: doc.rootHandle,
        transform: groupAt(hBox.value),
        children: const [])),
    SetComponentCommand<BoxParams>(hBox, const BoxParams(1200, 800)),
  ], label: 'Add box'));
  doc.commands.execute(addOpening(
      doc, hQ, const OpeningParams(hBox, 300, 600, OpeningKind.window)));
  doc.components.attach<WallParams>(
      hD, const WallParams(0, 0, 3000, 0, 150, Justification.centre));
  doc.commands.execute(addOpening(
      doc, hR, const OpeningParams(hD, 500, 600, OpeningKind.window)));
  return doc;
}

/// The panel's words (English, no kit words: the fields read none).
final KitWords words = KitNamesWords(KitNames.empty, () => const Locale('en'));

PropertyField fieldOf(DraftDocument doc, Handle h, String id) =>
    openingPlanType.fieldsOf(doc, h, words).firstWhere((f) => f.spec.id == id);

/// What committing [input] through [h]'s field [id] would store.
OpeningParams committed(
        DraftDocument doc, Handle h, String id, Object? input) =>
    (openingPlanType.commitField(doc, h, fieldOf(doc, h, id), input, words)
            as SetComponentCommand<OpeningParams>)
        .value!;

OpeningParams stored(DraftDocument doc, Handle h) =>
    doc.components.get<OpeningParams>(h)!;

void main() {
  test(
      'OT-title (spec 3a C3.3) an opening\'s section is titled by its '
      'kind, with its tool\'s word', () {
    final doc = planDoc();
    expect([
      for (final h in [hD, hW, hG]) openingPlanType.titleWordOf(doc, h)
    ], [
      'tool:architecture.door',
      'tool:architecture.window',
      'tool:architecture.gap',
    ]);
  });

  test(
      'OT-fields (spec 3a C3.3, R14-3) width, position, flip hinge, flip '
      'swing, in that order, each under its property word and gated by '
      'reshape; width and position read the stored values', () {
    final doc = planDoc();
    final fields = openingPlanType.fieldsOf(doc, hD, words);
    expect([for (final f in fields) f.spec.id],
        ['width', 'position', 'flip-hinge', 'flip-swing']);
    expect([
      for (final f in fields) f.wordId
    ], [
      'property:architecture.opening.width',
      'property:architecture.opening.position',
      'property:architecture.opening.flip-hinge',
      'property:architecture.opening.flip-swing',
    ]);
    expect([for (final f in fields) f.spec.gate],
        List.filled(4, PlanGate.reshape));
    expect([fields[0].value, fields[1].value], [900.0, 1500.0]);
  });

  test(
      'OT-width (spec 08 D6, 3a C3.3) the width is strict by kind: a gap\'s '
      'above 4 × wallJoin.linear, any other\'s above wallJoin.linear; not '
      'finite or not positive is refused', () {
    final doc = planDoc();
    expect(() => committed(doc, hG, 'width', 0.000004), throwsArgumentError);
    expect(committed(doc, hG, 'width', 0.000005).width, 0.000005);
    expect(() => committed(doc, hD, 'width', 0.000001), throwsArgumentError);
    expect(committed(doc, hD, 'width', 0.0000011).width, 0.0000011);
    for (final bad in [0.0, -40.0, double.nan, double.infinity]) {
      expect(() => committed(doc, hW, 'width', bad), throwsArgumentError,
          reason: '$bad');
    }
    expect(committed(doc, hW, 'width', 850.5),
        stored(doc, hW).copyWith(width: 850.5));
  });

  test(
      'OT-range (spec 3a C1.1, R14-1, R14-2) the position lies in [0, L], '
      'L the host\'s centreline length in its own space, both ends '
      'included; a host that is no wall refuses every position: a box, '
      'and an opening\'s group carrying WallParams', () {
    final doc = planDoc();
    final p = doc.components.get<WallParams>(hA)!;
    final l = (p.end - p.start).length;
    expect(l, 4000, reason: 'premise: L local');
    final m = doc.tree.accumulatedTransform(hA);
    expect((m.transformPoint(p.end) - m.transformPoint(p.start)).length,
        closeTo(5000, 1e-6),
        reason: 'premise: the world length differs');
    for (final v in [0.0, 1234.5, l]) {
      expect(committed(doc, hD, 'position', v),
          stored(doc, hD).copyWith(position: v),
          reason: '$v');
    }
    for (final v in [-1e-9, nextUp(l), 4500.0]) {
      expect(() => committed(doc, hD, 'position', v), throwsArgumentError,
          reason: '$v');
    }
    expect(testCatalog().typeIdOf(doc, hD), ArchitectureTypes.opening,
        reason: 'premise: D carries WallParams and is an opening');
    for (final h in [hQ, hR]) {
      for (final v in [0.0, 10.0, 300.0]) {
        expect(() => committed(doc, h, 'position', v), throwsArgumentError,
            reason: '$h at $v');
      }
    }
  });

  test(
      'OT-flip (spec 3a C1.7, 08 D16) the flips are a door\'s: shown for a '
      'door, hidden for a window and a gap; each turns its own field only', () {
    final doc = planDoc();
    expect([
      for (final h in [hD, hW, hG])
        for (final id in ['flip-hinge', 'flip-swing'])
          fieldOf(doc, h, id).visible
    ], [
      true,
      true,
      false,
      false,
      false,
      false
    ]);
    expect([
      for (final id in ['width', 'position']) fieldOf(doc, hW, id).visible
    ], [
      true,
      true
    ]);
    final d0 = stored(doc, hD);
    expect(committed(doc, hD, 'flip-hinge', null),
        d0.copyWith(hinge: HingeEnd.start));
    expect(committed(doc, hD, 'flip-swing', null),
        d0.copyWith(swing: SwingSide.left));
    doc.commands.execute(SetComponentCommand<OpeningParams>(
        hD, d0.copyWith(hinge: HingeEnd.start, swing: SwingSide.left)));
    expect(committed(doc, hD, 'flip-hinge', null).hinge, HingeEnd.end);
    expect(committed(doc, hD, 'flip-swing', null).swing, SwingSide.right);
  });

  test(
      'OT-kit (spec 3a C2) the kit carries the opening type right after '
      'the wall\'s, in today\'s registration order, and validates', () {
    final ids = [for (final t in architectureKit.types) t.id];
    expect(ids.indexOf(ArchitectureTypes.opening),
        ids.indexOf(ArchitectureTypes.wall) + 1);
    expect(architectureKit.validate(), isEmpty);
  });
}
