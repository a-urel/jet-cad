// Appendix A D-30 (spec 3a C3.4, C6): the separator's type is not exported
// (today's exportOmitOwners, jet_cad_floor_plan/lib/src/export/
// export_bytes.dart:28-29), so plan.png and plan.pdf leave every separator
// out, through the real kit. 2a's X-3 pins the plumbing over a test kit
// (jet_cad_2d_plan/test/export/registry_test.dart:78-115); the PDF is read
// back as the app's export test read it (apps/floor_planner/test/export/
// export_flow_test.dart:115-127; export_flat.dart:198-210's toPdf and
// pdfDistanceToSegment, copied here over the page's own origin and scale).
import 'dart:io' show zlib;
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/export_testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ExportDpi, exportPagePdf, exportPagePng;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/editor_rig.dart';
import 'separator_plans.dart';

/// World [p] in the PDF's points, under [page] (its origin is the sheet's
/// lower-left corner).
Vector2 toPdf(PageComponent page, Vector2 p) {
  final k = 72 / 25.4 / page.scaleDenominator;
  return Vector2((p.x - page.originX) * k, (p.y - page.originY) * k);
}

/// The distance from [p] to the segment [a]-[b], in pt.
double pdfDistanceToSegment(PdfXY p, Vector2 a, Vector2 b) {
  final ab = b - a;
  final t =
      (((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / ab.length2).clamp(0.0, 1.0);
  final q = a + ab * t;
  return math.sqrt(math.pow(p.x - q.x, 2) + math.pow(p.y - q.y, 2));
}

/// The plan: a wall, and well clear of it a separator in a turned,
/// mirrored group, on a new plan's sheet.
PlanController exportPlan() {
  final c =
      PlanController(kits: [architectureKit], build: buildWallAndSeparator);
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets(
      'SP-export-png plan.png leaves the separator out: its bytes are the '
      'page drawn without it', (tester) async {
    final c = exportPlan();
    final doc = c.document;
    final seps = liveOf<SeparatorParams>(c, ArchitectureTypes.separator);
    expect(seps, hasLength(1), reason: 'premise');
    final page = doc.components.get<PageComponent>(doc.rootHandle)!;
    final without = (await tester.runAsync(() => exportPagePng(
        document: doc,
        page: page,
        dpi: ExportDpi.d96,
        omitOwners: seps.toSet())))!;
    final whole = (await tester.runAsync(
        () => exportPagePng(document: doc, page: page, dpi: ExportDpi.d96)))!;
    expect(without, isNot(whole),
        reason: 'premise: the separator is on the sheet');
    final got = (await tester.runAsync(() =>
        c.export('plan.png', const PlanExportChoice(dpi: PlanExportDpi.d96))))!;
    // M-SP-1 (exported) and M-SP-10 (omittedOf answering nothing).
    expect(got.bytes, without);
  });

  testWidgets(
      'SP-export-pdf plan.pdf leaves the separator out: no path vertex '
      'within 1 pt of it, where the page exported with nothing omitted has '
      'one; the wall is drawn', (tester) async {
    final c = exportPlan();
    final doc = c.document;
    final sep = liveOf<SeparatorParams>(c, ArchitectureTypes.separator).single;
    final page = doc.components.get<PageComponent>(doc.rootHandle)!;
    final (s, e) = separatorEnds(doc, sep);
    final a = toPdf(page, s), b = toPdf(page, e);
    bool onSeparator(PdfContent content) => [
          for (final p in content.paths)
            for (final sub in p.subpaths)
              for (final v in sub.vertices)
                if (pdfDistanceToSegment(v, a, b) < 1.0) v,
        ].isNotEmpty;

    final font = (await tester.runAsync(() => rootBundle
        .load('packages/jet_cad_2d_plan/lib/fonts/Roboto-Regular.ttf')))!;
    final all = (await tester.runAsync(() => exportPagePdf(
        document: doc, page: page, fontBytes: font.buffer.asUint8List())))!;
    expect(onSeparator(PdfContent.parse(all, inflate: zlib.decode)), isTrue,
        reason: 'premise: exported with nothing omitted, the separator '
            'plots where the check looks');

    final got = (await tester
        .runAsync(() => c.export('plan.pdf', PlanExportChoice.initial)))!;
    final content = PdfContent.parse(got.bytes, inflate: zlib.decode);
    // M-SP-1 and M-SP-10.
    expect(onSeparator(content), isFalse, reason: 'no path at the separator');
    expect(content.paths, isNotEmpty, reason: 'the wall is drawn');
  });
}
