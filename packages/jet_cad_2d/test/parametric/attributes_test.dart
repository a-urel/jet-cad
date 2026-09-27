// The record attributes a client sets on add (spec 10 D13): written into
// each record when the child is added, and never rewritten on a match.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

EntityRecord recordOf(DraftDocument doc, Handle h) =>
    doc.entities.read(doc.entities.slotOf(h)!);

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

List<String> drift(DraftDocument doc) => [
      for (final d in ParametricSystem(doc, catalog).drift()) d.toString(),
    ];

/// Every attribute of [r] a client could set or `draftRecord` defaults,
/// field by field: everything but the handle, the owner, the kind and the
/// geometry slot.
Map<String, Object?> attrsOf(EntityRecord r) => {
      'layer': r.layer,
      'linetype': r.linetype,
      'linetypeScale': r.linetypeScale,
      'color': r.color,
      'lineweight': r.lineweight,
      'transparency': r.transparency,
      'flags': r.flags,
      'text': r.text,
      'tag': r.tag,
      'textStyle': r.textStyle,
      'textAttrs': r.textAttrs,
    };

/// The expected attributes, written out: `draftRecord`'s defaults (layer
/// 0, ByLayer linetype at scale 1, ByLayer colour, lineweight and
/// transparency, flags 0, no string or tag, the Standard style, textAttrs
/// 0), with the named ones replaced. Literals, not read from the code under
/// test.
Map<String, Object?> expected({
  Handle linetype = const Handle(2),
  int lineweight = -1,
  int transparency = -1,
  int flags = 0,
  String text = '',
  int textAttrs = 0,
}) =>
    {
      'layer': const Handle(1),
      'linetype': linetype,
      'linetypeScale': 1.0,
      'color': const ByLayerColor(),
      'lineweight': lineweight,
      'transparency': transparency,
      'flags': flags,
      'text': text,
      'tag': '',
      'textStyle': const Handle(5),
      'textAttrs': textAttrs,
    };

void main() {
  setUp(generateCalls.clear);

  test(
      'AT1 each record attribute is written on add and none is '
      'rewritten on a match; a region\'s boundary flags stand apart from its '
      'fill\'s', () async {
    // Premises on the literals used below: the reserved handles and the
    // flag bit are what `expected` spells out.
    expect(ReservedHandles.layerZero, const Handle(1));
    expect(ReservedHandles.byLayerLinetype, const Handle(2));
    expect(ReservedHandles.continuousLinetype, const Handle(4));
    expect(ReservedHandles.standardTextStyle, const Handle(5));
    expect(kByLayer, -1);
    expect(EntityFlags.invisible, 1);

    final doc = paramDoc();
    // A at atA, turned and off the origin; fractional stored positions.
    const s0 = Swatch(125.5, -40.25, 229, 35);
    doc.commands.execute(create(doc, hA, atA, s0));

    // Handles run fill < boundary < LINE < TEXT < TEXT (draw order).
    final created = kids(doc, hA);
    expect(created, hasLength(5));
    final [fill, boundary, line, text1, text2] = created;
    expect([
      for (final k in created) recordOf(doc, k).kind
    ], [
      EntityKind.fill,
      EntityKind.polyline,
      EntityKind.line,
      EntityKind.text,
      EntityKind.text,
    ]);
    expect(payloadOf(doc, fill).scalars, [boundary.value.toDouble()],
        reason: 'the fill names the boundary below it');

    // Premise: the swatch sits off the origin in world, on A's turned frame.
    final m = doc.tree.accumulatedTransform(hA);
    final corner = m.transformPoint(Vector2(125.5, -40.25));
    final want = atA.transformPoint(Vector2(125.5, -40.25));
    expect(corner.x, closeTo(want.x, 1e-9));
    expect(corner.y, closeTo(want.y, 1e-9));
    expect(corner.length, greaterThan(1000));
    expect(atA.transformDirection(Vector2(1, 0)).y, isNot(closeTo(0, 1e-3)));

    // Each attribute on add, every other one draftRecord's default.
    expect(attrsOf(recordOf(doc, fill)), expected(transparency: 229),
        reason: 'the fill: transparency 229, flags 0');
    expect(attrsOf(recordOf(doc, boundary)),
        expected(transparency: 229, flags: EntityFlags.invisible),
        reason: 'the boundary: transparency 229, flags invisible');
    expect(
        attrsOf(recordOf(doc, line)),
        expected(
            transparency: 229,
            flags: EntityFlags.invisible,
            linetype: const Handle(4),
            lineweight: 35),
        reason: 'the LINE');
    expect(attrsOf(recordOf(doc, text1)),
        expected(text: 'Oak', textAttrs: 0x21, flags: EntityFlags.invisible),
        reason: 'the first TEXT: centre (1) | middle (2) << 4, invisible');
    expect(
        attrsOf(recordOf(doc, text2)), expected(text: 'Ash', textAttrs: 0x32),
        reason: 'the second TEXT: right (2) | top (3) << 4');
    expect(payloadOf(doc, boundary), swatchLoop(s0));
    expect(payloadOf(doc, line), swatchLine(s0));
    expect(payloadOf(doc, text1), swatchFirstText(s0));
    expect(payloadOf(doc, text2), swatchSecondText(s0));
    expect(drift(doc), isEmpty);

    // boundaryFlags unset: the boundary takes the fill's flags (here
    // `invisible`, so a default of 0 would show).
    const inherit = Swatch(-60.75, 30.5, 229, 35, inherit: true);
    doc.commands.execute(create(doc, hB, onA(1500.5, 800.25, -0.35), inherit));
    final [fillB, boundaryB, ..._] = kids(doc, hB);
    expect(recordOf(doc, fillB).kind, EntityKind.fill);
    expect(recordOf(doc, boundaryB).kind, EntityKind.polyline);
    expect(attrsOf(recordOf(doc, fillB)),
        expected(transparency: 229, flags: EntityFlags.invisible));
    expect(attrsOf(recordOf(doc, boundaryB)),
        expected(transparency: 229, flags: EntityFlags.invisible),
        reason: 'boundaryFlags defaults to flags');
    expect(drift(doc), isEmpty);

    // A match: moved, alpha 229 -> 100, weight 35 -> 50. Every payload is
    // rewritten; every record stays exactly as added, field by field
    // (geometry slots included: a rewrite replaces in place).
    final records = {for (final k in created) k: recordOf(doc, k)};
    final beforeMatch = canon(doc);
    final depth = doc.commands.undoDepth;
    const s1 = Swatch(-210.75, 95.5, 100, 50);
    doc.commands.execute(SetComponentCommand<Swatch>(hA, s1));
    expect(kids(doc, hA), created, reason: 'every child matched in place');
    for (final k in created) {
      expect(recordOf(doc, k), records[k], reason: '${k.toHex()} as added');
    }
    expect(payloadOf(doc, boundary), swatchLoop(s1));
    expect(payloadOf(doc, line), swatchLine(s1));
    expect(payloadOf(doc, text1), swatchFirstText(s1));
    expect(payloadOf(doc, text2), swatchSecondText(s1));
    expect(payloadOf(doc, boundary), isNot(swatchLoop(s0)));
    expect(doc.commands.undoDepth, depth + 1);
    expect(drift(doc), isEmpty);

    // Only the second TEXT's string changes: the second TEXT is rewritten,
    // the first is untouched (the i-th generated TEXT matches the i-th
    // existing one); nothing else of either record moves.
    const s2 = Swatch(-210.75, 95.5, 100, 50, second: 'Elm');
    doc.commands.execute(SetComponentCommand<Swatch>(hA, s2));
    expect(kids(doc, hA), created);
    expect(recordOf(doc, text1), records[text1]);
    expect(recordOf(doc, text2), records[text2]!.copyWith(text: 'Elm'));
    for (final k in [fill, boundary, line]) {
      expect(recordOf(doc, k), records[k]);
    }
    expect(drift(doc), isEmpty);

    doc.commands.undo();
    doc.commands.undo();
    expect(canon(doc), beforeMatch);
    expect(drift(doc), isEmpty);
    doc.commands.redo();
    doc.commands.redo();
    expect(recordOf(doc, text2).text, 'Elm');
    expect(drift(doc), isEmpty);

    // A caller's geometry edit of the generated LINE is still refused (06
    // D6): the bytes and the history are unchanged.
    final bytes = enc(doc);
    final depth2 = doc.commands.undoDepth;
    expect(
        () => doc.commands.execute(SetEntityGeometryCommand(
            line, linePayload(Vector2(0.5, 0.5), Vector2(10.5, 10.5)))),
        throwsA(isA<GeneratedGeometryError>()
            .having((e) => e.handle, 'handle', line)));
    expect(enc(doc), bytes);
    expect(doc.commands.undoDepth, depth2);

    // Save, load, save: byte-identical, the attributes kept, no drift.
    final loaded = reload(bytes);
    expect(enc(loaded), bytes);
    for (final k in created) {
      expect(attrsOf(recordOf(loaded, k)), attrsOf(recordOf(doc, k)));
    }
    expect(drift(loaded), isEmpty);
  });
}
