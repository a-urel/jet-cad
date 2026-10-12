// Plan colours spec PC-3a: colour and transparency are the planner's
// columns, as the layer is (12b D2): a matched child whose stored colour or
// transparency differs from what its object generates (exact ==) is
// restamped in the same edit; one that does not plans nothing.
//
// Fixture: a Dye in a group turned 0.4 rad, 4,000.5 mm off the origin.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

final Transform2 at =
    Transform2.translation(4000.5, -2500.25).multiply(Transform2.rotation(0.4));

// Teal and purple, as the floor plan's palette has them; a hand literal.
const int teal = 0x01000000 | 0x00897B; // encodeColor(TrueColor(0x00897B))
const int purple = 0x01000000 | 0x8E24AA;

EntityRecord rec(DraftDocument d, Handle h) =>
    d.entities.read(d.entities.slotOf(h)!);

/// Every style command inside [c], compounds and replays opened.
Iterable<SetEntityStyleCommand> styleCommands(DraftCommand c) sync* {
  if (c is SetEntityStyleCommand) yield c;
  if (c is CompoundCommand) {
    for (final k in c.children) {
      yield* styleCommands(k);
    }
  } else if (c is ParametricReplay) {
    yield* styleCommands(c.replay);
  }
}

/// The style commands [command] plans on [doc]'s copy: a `ParametricEdit`
/// builds its plan in `apply`, so it is applied on a reload outside the
/// dispatcher and its inverse read (a `SetEntityStyleCommand`'s inverse is
/// one too), as `object_layer_test.dart`'s `planOnCopy` does.
List<SetEntityStyleCommand> plannedStyles(
    DraftDocument doc, DraftCommand Function(DraftDocument copy) command) {
  final copy = reload(enc(doc));
  final edit = copy.commands.expander!(command(copy)) as ParametricEdit;
  final inverse = edit.apply(copy).inverse as ParametricReplay;
  return styleCommands(inverse.replay).toList();
}

void main() {
  setUp(generateCalls.clear);

  test('ST0 premise: the hand literals are encodeColor of the true colours',
      () {
    expect(encodeColor(const TrueColor(0x00897B)), teal);
    expect(encodeColor(const TrueColor(0x8E24AA)), purple);
  });

  test(
      'ST1 a recolour restamps the matched fill, boundary and LINE in place: '
      'same handles, same payloads; undo and redo restore each record', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, at, const Dye(-120.5, teal, 204)));
    final children = kids(doc, hA);
    expect(children, hasLength(3), reason: 'fill, boundary, LINE');
    final before = {for (final k in children) k: rec(doc, k)};
    final bytes = canon(doc);

    doc.commands
        .execute(SetComponentCommand<Dye>(hA, const Dye(-120.5, purple, 153)));
    expect(kids(doc, hA), children, reason: 'every child matched');
    for (final k in children) {
      expect(
          rec(doc, k),
          before[k]!
              .copyWith(color: const TrueColor(0x8E24AA), transparency: 153),
          reason: '${k.toHex()}: colour and transparency only');
    }

    doc.commands.undo();
    expect(canon(doc), bytes);
    doc.commands.redo();
    for (final k in children) {
      expect(rec(doc, k).color, const TrueColor(0x8E24AA));
      expect(rec(doc, k).transparency, 153);
    }
  });

  test(
      'ST2 the guard: an edit that leaves the style alone plans no style '
      'command (a move of the Dye; an edit of another object)', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, at, const Dye(-120.5, teal, 204)));
    doc.commands.execute(create(doc, hB, atB, const ClipRect(400, 900)));
    expect(
        plannedStyles(doc,
            (_) => SetComponentCommand<Dye>(hA, const Dye(75.25, teal, 204))),
        isEmpty,
        reason: 'a move plans none');
    expect(
        plannedStyles(
            doc,
            (_) =>
                SetComponentCommand<ClipRect>(hB, const ClipRect(410.5, 900))),
        isEmpty,
        reason: 'another object plans none');
    expect(
        plannedStyles(
            doc,
            (_) =>
                SetComponentCommand<Dye>(hA, const Dye(-120.5, purple, 204))),
        hasLength(3),
        reason: 'premise: a recolour plans one per child');
    expect(ParametricSystem(doc, catalog).drift(), isEmpty);
  });

  test('ST3 a transparency change alone is stamped; so is a colour alone', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, at, const Dye(-120.5, teal, 204)));
    doc.commands
        .execute(SetComponentCommand<Dye>(hA, const Dye(-120.5, teal, 51)));
    for (final k in kids(doc, hA)) {
      expect(rec(doc, k).transparency, 51);
      expect(rec(doc, k).color, const TrueColor(0x00897B));
    }
    doc.commands
        .execute(SetComponentCommand<Dye>(hA, const Dye(-120.5, purple, 51)));
    for (final k in kids(doc, hA)) {
      expect(rec(doc, k).transparency, 51);
      expect(rec(doc, k).color, const TrueColor(0x8E24AA));
    }
  });

  test(
      'ST4 SetEntityStyleCommand: sets both, its inverse restores both, its '
      'capabilities are a property edit, a missing entity throws', () {
    final doc = DraftDocument.empty();
    final h = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
        record: draftRecord(h, doc.rootHandle, EntityKind.line,
            layer: ReservedHandles.layerZero),
        payload: linePayload(Vector2(0.5, 0.5), Vector2(10.5, 3.25))));
    final cmd =
        SetEntityStyleCommand.restore(h, const TrueColor(0x00897B), 204);
    expect(cmd.capability, Capability.geometry);
    expect(cmd.capabilities, {Capability.components});
    doc.commands.execute(cmd);
    expect(rec(doc, h).color, const TrueColor(0x00897B));
    expect(rec(doc, h).transparency, 204);
    doc.commands.undo();
    expect(rec(doc, h).color, const ByLayerColor());
    expect(rec(doc, h).transparency, kByLayer);
    expect(
        () => doc.commands.execute(SetEntityStyleCommand.restore(
            const Handle(0xFFFF), const ByLayerColor(), kByLayer)),
        throwsStateError);
  });
}
