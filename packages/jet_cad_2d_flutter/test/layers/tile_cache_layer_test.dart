// Spec 12b D1 (R-8) and Testing (render): a tile-cached canvas redraws after
// a layer move and after its undo. A move to another layer changes pixels
// (visibility, ByLayer colour) while it is a property edit for permissions,
// so the two move commands report `capability: geometry` and the tile cache,
// which skips a `components` change (spec 04 D13), drops the tiles the moved
// thing was baked into and those it reaches. M-LP-19: either move command
// reporting `components` leaves its old tiles blitting, and this goes red.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/tile_fixture.dart';
import '../support/tile_harness.dart';

const Handle _a = Handle(0x900), _b = Handle(0x901), _c = Handle(0x902);
const Handle _line = Handle(1001), _far = Handle(1002);
const Handle _definition = Handle(210), _definitionLine = Handle(1003);
const Handle _instance = Handle(300);

/// At `tileCamera` the world→screen map is `x -> 1.4x - 37`,
/// `y -> 323 - 1.4y`, and a tile is 32 logical pixels. P-6's layers: `A`
/// (ACI 1), `B` (ACI 5, locked), `C` (ACI 3, hidden). On `A`, a root line
/// in the lower left (tile columns 0-2) and an instance, turned and moved,
/// whose definition line is on layer 0 (so it follows `A`); on `B`, a far
/// line in the upper right (columns 7-10), which no edit here touches.
DraftDocument layeredTiles(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  for (final (handle, name, aci, visible, locked) in const [
    (_a, 'A', 1, true, false),
    (_b, 'B', 5, true, true),
    (_c, 'C', 3, false, false),
  ]) {
    doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: handle,
      name: name,
      color: IndexedColor(aci),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: visible,
      locked: locked,
    )));
  }
  addLine(doc, doc.rootHandle, _line, 40, 40, 90, 70);
  addLine(doc, doc.rootHandle, _far, 200, 150, 260, 190);
  addDefinition(doc, _definition, 'PLATE');
  addLine(doc, _definition, _definitionLine, 0, 0, 40, 20);
  addInstance(doc, doc.rootHandle, _instance, _definition,
      Transform2.translation(60, 120).multiply(Transform2.rotation(0.3)));
  doc.commands
    ..execute(SetEntityLayerCommand(_line, _a))
    ..execute(SetEntityLayerCommand(_far, _b))
    ..execute(SetInstanceLayerCommand(_instance, _a))
    ..clearHistory();
  return doc;
}

/// The tiles a fresh cache bakes [handle] into over [document] as it stands
/// now: measured, not derived, as `tile_invalidation_test.dart`'s oracle is.
/// The canvas's own settle may cut tiles from a band whose shared record
/// names more than each tile reaches, so its set can be larger; it must not
/// be smaller.
Set<TileKey> reachedBy(DraftDocument document, Handle handle) {
  final oracle = TileRig(
      tileDevicePixels: 64, tilesBakedPerFrame: 1000, document: document);
  try {
    oracle.paintOnce();
    return oracle.cache.tilesHolding(handle).toSet();
  } finally {
    oracle.dispose();
  }
}

Future<void> afterCommand(WidgetTester t, TiledHarness h) async {
  await t.idle(); // the DocChange broadcast is asynchronous
  await t.pump();
  await settle(t, h);
}

void main() {
  for (final (what, subject) in const [
    ('a root line', _line),
    ('an instance', _instance),
  ]) {
    testWidgets(
        'moving $what to the hidden layer drops its tiles, which rebake '
        'without it; its undo rebakes them with it (M-LP-19)', (t) async {
      final h = await pumpTiled(t, document: layeredTiles);
      await settle(t, h);
      final before = h.cache.tilesHolding(subject).toSet();
      final far = h.cache.tilesHolding(_far).toSet();
      expect(before, isNotEmpty, reason: 'the subject must be baked');
      expect(far, isNotEmpty);
      expect(far.intersection(before), isEmpty,
          reason: 'fixture guard: the far side is genuinely far');

      h.document.commands.execute(subject == _instance
          ? SetInstanceLayerCommand(subject, _c)
          : SetEntityLayerCommand(subject, _c));
      await afterCommand(t, h);
      expect(h.cache.tilesHolding(subject), isEmpty,
          reason: 'a tile baked before the move still blits it');
      for (final key in far) {
        expect(h.cache.holds(key), isTrue, reason: 'far side, $key');
      }

      h.document.commands.undo();
      await afterCommand(t, h);
      // Each tile the subject reaches was rebaked without it while it was
      // hidden; the undo must drop and rebake every one of them.
      final reached = reachedBy(h.document, subject);
      expect(reached, isNotEmpty);
      expect(before, containsAll(reached));
      expect(h.cache.tilesHolding(subject).toSet(), containsAll(reached),
          reason: 'the undo must rebake the tiles it reaches');
    });
  }

  testWidgets(
      'moving a line between two visible layers drops its tiles (a ByLayer '
      'colour change is a pixel change) and keeps the far side', (t) async {
    final h = await pumpTiled(t, document: layeredTiles);
    await settle(t, h);
    final before = h.cache.tilesHolding(_line).toSet();
    final far = h.cache.tilesHolding(_far).toSet();
    expect(before, isNotEmpty);
    final invalidations = h.cache.invalidationCount;

    h.document.commands.execute(SetEntityLayerCommand(_line, _b));
    await t.idle();
    // Dropped by the change itself, before any frame rebakes them.
    for (final key in before) {
      expect(h.cache.holds(key), isFalse, reason: 'old tile, $key');
    }
    expect(h.cache.invalidationCount,
        greaterThanOrEqualTo(invalidations + before.length));
    for (final key in far) {
      expect(h.cache.holds(key), isTrue, reason: 'far side, $key');
    }
    await t.pump();
    await settle(t, h);
    final reached = reachedBy(h.document, _line);
    expect(reached, isNotEmpty);
    expect(h.cache.tilesHolding(_line).toSet(), containsAll(reached),
        reason: 'the same tiles, rebaked in B\'s colour');
  });
}
