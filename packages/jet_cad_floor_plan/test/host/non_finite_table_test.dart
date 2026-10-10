// O-11 (host embedding API spec, Open items): the embedding fixture's table
// `9`, scaled (1e306, 1e-306), has no finite corner. Selecting it in the
// design view used to trip `Canvas.drawLine`'s NaN assertion in the
// selection overlay's rotation grip; a PDF of a plan holding it (Export →
// PDF and Print both write `exportPdfBytes`) tripped the pdf package's
// `!value.isNaN` through its label's residual. The render package skips
// what is not finite (`non_finite_selection_test.dart`, the PDF sink's
// O-11 tests); these run the whole planner on the whole fixture.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/export_testing.dart';
import 'package:jet_cad_floor_plan/src/export/export_bytes.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';

import 'embedding_fixture.dart';

/// The bundled font, read from the package's own file.
final fontBytes = File('lib/fonts/Roboto-Regular.ttf').readAsBytesSync();

/// The content stream of the PDF Export and Print write for [json]'s plan.
Future<List<String>> pdfOperators(String json) async {
  final c = FloorPlanController(json: json);
  addTearDown(c.dispose);
  final doc = c.activeDocument;
  final bytes =
      await exportPdfBytes(doc, exportPageOf(doc)!, fontBytes: fontBytes);
  final content = PdfContent.parse(bytes, inflate: zlib.decode);
  return [for (final o in content.operators) o.toString()];
}

void main() {
  testWidgets(
      'NT1 table 9 selected in the design view, alone and beside table 1, '
      'paints without an assertion', (tester) async {
    final c = FloorPlanController(json: embeddingPlanJson());
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: FloorPlanView(controller: c))));
    await tester.pump();
    await tester.pump();

    c.select({'9'});
    await tester.pump();
    expect(c.selectedTables.value, {'9'});

    c.select({'9', '1'});
    await tester.pump();
    expect(c.selectedTables.value, {'9', '1'});
  });

  test(
      'NT2 the PDF of the whole fixture is the PDF of the fixture without '
      'table 9, operator for operator', () async {
    final whole = await pdfOperators(embeddingPlanJson());
    final finite = await pdfOperators(
        embeddingPlanJson(tables: embeddingTables.where((t) => t.finite)));
    expect(finite.where((o) => o.endsWith(' TJ')), isNotEmpty,
        reason: 'premise: the other tables\' labels are written');
    expect(whole, finite);
  });
}
