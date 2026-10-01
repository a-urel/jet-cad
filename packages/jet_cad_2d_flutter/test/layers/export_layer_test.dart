// Spec 12b D6 and Testing (render): a page export omits a hidden layer. The
// export builds its own `SpatialIndex` (`page_export.dart`'s
// `_withExportIndex`) and so the same rendering filter as the screen; no
// export code reads layers. Through the real `exportPagePdf`, read back by
// the content reader. The export fixture's own entities stay on layer 0,
// which stays visible; P-6's layers are added and three things moved:
// - the root line to `C`, then `C` hidden by a command (after an export
//   that plotted it);
// - the nested group's line (two turned groups down) to `C` too;
// - the outer group's instance to `C`: its definition leaf follows it;
// - the separator line to `B` (locked: still plots) and the instance on
//   `A` (visible: plots).
import 'dart:io' show zlib;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/export_testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/export_fixture.dart';
import '../support/export_font.dart';

const double _u = 72 / 25.4;

void main() {
  final fontBytes = exportFontBytes();

  Future<PdfContent> export(ExportFixture f) async => PdfContent.parse(
      await exportPagePdf(
        document: f.document,
        page: f.page,
        fontBytes: fontBytes,
        compress: false,
      ),
      inflate: zlib.decode);

  /// A world point to PDF page space at the fixture's 1:50 (y up from the
  /// sheet's lower-left corner), from the page's numbers alone.
  PdfXY toPage(Vector2 w) => (
        x: (w.x - kExportOriginX) / 50 * _u,
        y: (w.y - kExportOriginY) / 50 * _u,
      );

  /// Whether some stroked path starts at the start point of [leaf], a line
  /// whose owner's accumulated transform places it.
  bool plotted(PdfContent c, ExportFixture f, Handle leaf) {
    final doc = f.document;
    final slot = doc.entities.slotOf(leaf)!;
    final owner = doc.entities.ownerAt(slot);
    final placement = owner == doc.rootHandle
        ? Transform2.identity()
        : doc.tree.accumulatedTransform(owner);
    final coords = doc.geometry.peek(doc.entities.geomIndexAt(slot)).coords;
    final at = toPage(placement.transformPoint(Vector2(coords[0], coords[1])));
    return c.paths.any((p) =>
        p.strokes &&
        (p.subpaths.first.start.x - at.x).abs() < 1e-3 &&
        (p.subpaths.first.start.y - at.y).abs() < 1e-3);
  }

  test(
      'a hidden layer does not plot: its root line, its nested-group line '
      'and its instance\'s leaf are gone; locked B and visible A still plot',
      () async {
    final f = exportFixture(measurer: FlutterTextMeasurer());
    final doc = f.document;
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    Handle add(String name, int aci, {bool locked = false}) {
      final handle = doc.handleSeed.next();
      doc.commands.execute(AddLayerCommand(LayerRecord(
        handle: handle,
        name: name,
        color: IndexedColor(aci),
        linetype: zero.linetype,
        lineweight: zero.lineweight,
        transparency: zero.transparency,
        locked: locked,
      )));
      return handle;
    }

    final a = add('A', 1), b = add('B', 5, locked: true), c = add('C', 3);
    doc.commands
      ..execute(SetEntityLayerCommand(f.line, c))
      ..execute(SetEntityLayerCommand(f.nestedLine, c))
      ..execute(SetInstanceLayerCommand(f.outerGroupInstance, c))
      ..execute(SetEntityLayerCommand(f.outerGroupLine, b))
      ..execute(SetInstanceLayerCommand(f.instance, a));
    for (final g in [f.nestedGroup, f.outerGroup]) {
      expect(doc.tree[g]!.transform.isIdentity, isFalse);
    }

    // C visible: everything plots, so the probe can see each one.
    final shown = await export(f);
    for (final h in [f.line, f.nestedLine, f.outerGroupLine]) {
      expect(plotted(shown, f, h), isTrue, reason: 'control ${h.toHex()}');
    }

    doc.commands.execute(
        SetLayerCommand(doc.tables.layers[c]!.copyWith(visible: false)));
    final hidden = await export(f);
    for (final h in [f.line, f.nestedLine]) {
      expect(plotted(hidden, f, h), isFalse, reason: 'on C: ${h.toHex()}');
    }
    expect(plotted(hidden, f, f.outerGroupLine), isTrue,
        reason: 'B is locked, not hidden');
    // The instance on C took its one definition line with it, and nothing
    // else left the page: the instance on A and everything on 0 still plot.
    expect(shown.paths.length - hidden.paths.length, 3,
        reason: 'the root line, the nested line and the instance\'s leaf');
    expect(hidden.paths.where((p) => p.strokes).length,
        shown.paths.where((p) => p.strokes).length - 3);
  });
}
