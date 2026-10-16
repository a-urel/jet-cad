// Spec P5: the export dialog lists the registry; the resolution is asked
// for an image format only; OK answers the choice, Cancel null.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/src/export/builtin_exporters.dart';
import 'package:jet_cad_2d_plan/src/export/export_dialog.dart';
import 'package:jet_cad_2d_plan/src/export/registries.dart';

import '../support/recording_exporters.dart';

Finder byKey(String k) => find.byKey(Key(k));

void main() {
  testWidgets(
      'X-9 the dialog lists every exporter by its extension, asks the '
      'resolution only for an image format, answers the choice on OK and '
      'null on Cancel', (tester) async {
    final exporters = <PlanExporter>[
      const PlanPdfExporter(),
      const PlanPngExporter(),
      RecordingExporter('acme.json', 'json', 'application/json'),
    ];
    PlanExportAnswer? got;
    var done = false;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                key: const Key('open'),
                onPressed: () async {
                  got = await showPlanExportDialog(
                      context, PlanExportAnswer.initial, exporters);
                  done = true;
                },
                child: const Text('open')))));
    await tester.tap(byKey('open'));
    await tester.pumpAndSettle();
    for (final e in exporters) {
      expect(byKey('export-format-${e.id}'), findsOneWidget, reason: e.id);
    }
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('JSON'), findsOneWidget);
    expect(byKey('export-dpi'), findsNothing, reason: 'a PDF has none');
    await tester.tap(byKey('export-format-plan.png'));
    await tester.pump();
    expect(byKey('export-dpi'), findsOneWidget);
    await tester.tap(byKey('export-dpi-300'));
    await tester.pump();
    await tester.tap(byKey('export-format-acme.json'));
    await tester.pump();
    // M-X-9: the resolution row shown for every exporter.
    expect(byKey('export-dpi'), findsNothing);
    await tester.tap(byKey('export-ok'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(
        got,
        const PlanExportAnswer(
            exporter: 'acme.json',
            choice: PlanExportChoice(dpi: PlanExportDpi.d300)));

    done = false;
    await tester.tap(byKey('open'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<SegmentedButton<String>>(byKey('export-format')).selected,
        {'plan.pdf'},
        reason: 'the initial answer it was given');
    await tester.tap(byKey('export-cancel'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(got, isNull);
  });

  testWidgets(
      'X-9b Escape closes the dialog and answers null, as Cancel does '
      '(3b Task 7; the old PlanExportDialog Escape)', (tester) async {
    final exporters = <PlanExporter>[
      const PlanPdfExporter(),
      const PlanPngExporter(),
    ];
    PlanExportAnswer? got = const PlanExportAnswer(
        exporter: 'unset', choice: PlanExportChoice.initial);
    var done = false;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                key: const Key('open'),
                onPressed: () async {
                  got = await showPlanExportDialog(
                      context, PlanExportAnswer.initial, exporters);
                  done = true;
                },
                child: const Text('open')))));
    await tester.tap(byKey('open'));
    await tester.pumpAndSettle();
    // A choice made before Escape must not leak into the answer.
    await tester.tap(byKey('export-format-plan.png'));
    await tester.pump();
    expect(byKey('export-dialog'), findsOneWidget, reason: 'premise: up');
    expect(done, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(byKey('export-dialog'), findsNothing);
    expect(done, isTrue);
    expect(got, isNull);
  });
}
