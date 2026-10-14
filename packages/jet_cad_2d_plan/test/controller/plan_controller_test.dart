// Spec 2a P2 "PlanController": the plan (newPlan, load, save, dirty,
// markSaved), undo and redo, tools by id, deleteSelection, the settle, and
// the manifest's report. C3-C6 are jet_cad_floor_plan's controller_test.dart
// C8, C9, C11 and C12 (design half), assertions unchanged; a slab of the
// test kit stands in for a table.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';

/// A design edit: a line (controller_test.dart's drawLine).
void drawLine(PlanController c) =>
    addLine(c.document, Vector2(-500, 700), Vector2(1800, 2400));

List<double> parts(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

Transform2 transformOf(DraftDocument d, Handle h) =>
    (d.tree[h]! as GroupNode).transform;

void main() {
  testWidgets(
      'C1 a new plan: the default page off the origin, millimetres, clean, '
      'no history, select armed, nothing missing', (tester) async {
    final c = controllerFor(kits: [testKit()]);
    final d = c.document;
    final page = d.components.get<PageComponent>(d.rootHandle)!;
    expect(page.originX, -7425);
    expect(page.originY, -5250);
    expect(page.scaleDenominator, 50);
    // M-C1a: the units not set.
    expect(d.header.units, DrawingUnits.millimeters);
    // M-C1b: the history not cleared.
    expect(d.commands.canUndo, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
    expect(c.activeTool.value, 'plan.select');
    expect(c.missingKits, isEmpty);
    expect(c.symbolsState.value, PlanSymbolsState.ready);
    expect(c.diagnostics.value, isEmpty);
    expect(manifestOf(d), isNull, reason: 'a new plan has none until saved');
    await tester.pump();
  });

  testWidgets(
      'C2 a bad kit set or a bad plan throws before anything is built; a bad '
      'json at construction is a FormatException (C12, review F-5)',
      (tester) async {
    expect(() => PlanController(kits: [testKit(), testKit()]),
        throwsA(isA<KitSetError>()));
    // M-C2: the factory opens an empty plan when the json does not decode.
    expect(() => PlanController(kits: [testKit()], json: '{"entities": 7}'),
        throwsFormatException);
    expect(
        () => PlanController(kits: [testKit()], json: 'not json'),
        throwsA(isA<PlanFormatException>()
            .having((e) => e.code, 'code', PlanFormatCode.notJson)));
  });

  testWidgets(
      'C3 a bad plan changes nothing: broken structure, unknown schema, no '
      'manifest (C8, M-14b2-8)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    final slab = slabsOf(c.document).first;
    final moved = parts(transformOf(c.document, slab));
    final document = c.document;
    final good = jsonDecode(slabPlanText()) as Map<String, Object?>;
    final broken = jsonEncode({...good, 'entities': 7});
    final future = jsonEncode({...good, 'schemaVersion': 9999});
    // M-C3: a load that does not decode opens an empty plan.
    for (final bad in [broken, future, '{}']) {
      expect(() => c.load(bad), throwsFormatException, reason: bad);
    }
    expect(c.document, same(document));
    expect(parts(transformOf(c.document, slab)), moved);
    await tester.pump();
  });

  testWidgets(
      'C4 markSaved marks the state the last save encoded (C9, '
      'M-14b2-14)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    drawLine(c);
    c.save();
    drawLine(c); // lands while the host writes
    // M-C4: markSaved takes the current state.
    c.markSaved();
    await tester.pump();
    expect(c.dirty.value, isTrue);
    c.save();
    c.markSaved();
    await tester.pump();
    expect(c.dirty.value, isFalse);
  });

  testWidgets('C5 newPlan is empty and clean; load of a plan is clean (C11)',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    drawLine(c);
    await tester.pump();
    expect(c.dirty.value, isTrue);
    // M-C5: the save point not moved by a swap.
    c.newPlan();
    await tester.pump();
    expect(slabsOf(c.document), isEmpty);
    expect(c.dirty.value, isFalse);
    c.load(slabPlanText());
    expect(slabsOf(c.document), hasLength(2));
    await tester.pump();
  });

  testWidgets("C6 a load forgets the last save's state (C12, review m31)",
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    drawLine(c);
    drawLine(c);
    drawLine(c);
    c.save(); // state 3 of the old plan
    c.load(slabPlanText());
    drawLine(c);
    // M-C6: the encoded state kept across a load.
    c.markSaved(); // the new plan's current state
    await tester.pump();
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      'C7 a load reports the kits it names that are not loaded and a newer '
      'kit; a save keeps the missing entry; a new plan clears both',
      (tester) async {
    final json = jsonDecode(slabPlanText()) as Map<String, Object?>;
    final components = json['components']! as Map<String, Object?>;
    (components['jetcad.manifest']!
        as Map<String, Object?>)['${json['root']}'] = {
      'format': 1,
      'kits': {'gone': '3.1.0', 'test': '9.0.0'},
    };
    final c = controllerFor(
        kits: [testKit(version: '1.2.0')], json: jsonEncode(json));
    // M-C7a: the manifest not checked at a load.
    expect(c.missingKits, {'gone'});
    expect([
      for (final d in c.diagnostics.value) (d.kitId, d.code)
    ], [
      ('gone', KitDiagnosticCode.kitMissing),
      ('test', KitDiagnosticCode.kitNewer),
    ]);
    final saved = jsonDecode(c.save()) as Map<String, Object?>;
    expect(
        ((saved['components']! as Map<String, Object?>)['jetcad.manifest']!
            as Map<String, Object?>)['${saved['root']}'],
        {
          'format': 1,
          'kits': {'gone': '3.1.0', 'test': '1.2.0'},
        });
    c.newPlan();
    expect(c.missingKits, isEmpty);
    // M-C7b: the plan's diagnostics kept across a swap.
    expect(c.diagnostics.value, isEmpty);
    await tester.pump();
  });

  testWidgets(
      'C8 undo and redo act on the plan, and do nothing while a tool is '
      'part-way through a shape', (tester) async {
    final c = controllerFor(kits: [testKit()]);
    drawLine(c);
    expect(c.selectTool('test.slab'), isTrue);
    final tool = c.toolFor('test.slab')!;
    tool.onPointerDown(pointerAt(Vector2(1250, -730)), c.toolContext);
    expect(tool.isMidShape, isTrue, reason: 'premise');
    final state = c.document.commands.stateId;
    // M-C8: the mid-shape check removed from undo (and redo).
    c.undo();
    expect(c.document.commands.stateId, state);
    c.redo();
    expect(c.document.commands.stateId, state);
    tool.cancel(c.toolContext);
    c.undo();
    expect(c.document.commands.canUndo, isFalse);
    c.redo();
    expect(c.document.commands.canUndo, isTrue);
    await tester.pump();
    expect(c.canUndo.value, isTrue);
    expect(c.canRedo.value, isFalse);
  });

  testWidgets(
      'C9 selectTool by id: a kit tool clears the selection; select; an '
      'unknown id; a drawing tool refused while geometry is denied',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    c.selection.replace([SelectionKey.root(slabsOf(c.document).first)]);
    expect(c.selectTool('test.slab'), isTrue);
    expect(c.activeTool.value, 'test.slab');
    // M-C9a: a drawing tool keeps the selection.
    expect(c.selection.isEmpty, isTrue);
    expect(c.selectTool('nope.tool'), isFalse);
    expect(c.activeTool.value, 'test.slab');
    expect(c.selectTool('plan.select'), isTrue);
    expect(c.activeTool.value, 'plan.select');
    c.document.commands.permissions = DraftPermissions.runtime;
    // M-C9b: the geometry check removed.
    expect(c.selectTool('test.slab'), isFalse);
    expect(c.activeTool.value, 'plan.select');
    await tester.pump();
  });

  testWidgets(
      'C10 deleteSelection: false with nothing selected and while a shape is '
      'part-way; otherwise one undo step', (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    expect(c.deleteSelection(), isFalse);
    final slab = slabsOf(c.document).first;
    c.selection.replace([SelectionKey.root(slab)]);
    final depth = c.document.commands.undoDepth;
    expect(c.deleteSelection(), isTrue);
    expect(c.document.tree[slab], isNull);
    expect(leavesOf(c.document, slab), isEmpty);
    expect(c.document.commands.undoDepth, depth + 1);
    c.undo();
    expect(c.document.tree[slab], isNotNull);
    expect(c.selectTool('test.slab'), isTrue);
    c
        .toolFor('test.slab')!
        .onPointerDown(pointerAt(Vector2(1250, -730)), c.toolContext);
    c.selection.replace([SelectionKey.root(slab)]);
    // M-C10: the mid-shape check removed from deleteSelection.
    expect(c.deleteSelection(), isFalse);
    expect(c.document.tree[slab], isNotNull);
    await tester.pump();
  });

  testWidgets(
      'C11 pending input is settled before save, markSaved, undo, redo, '
      'deleteSelection, newPlan and load; a withdrawn settle is not called',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    final calls = <String>[];
    var phase = '';
    final withdraw = c.registerSettle(() => calls.add(phase));
    final runs = <(String, void Function())>[
      ('save', () => c.save()),
      ('markSaved', c.markSaved),
      ('undo', c.undo),
      ('redo', c.redo),
      ('delete', () => c.deleteSelection()),
      ('newPlan', () => c.newPlan()),
      ('load', () => c.load(slabPlanText())),
    ];
    for (final (name, run) in runs) {
      phase = name;
      run();
    }
    // M-C11: load does not settle.
    expect(calls,
        ['save', 'markSaved', 'undo', 'redo', 'delete', 'newPlan', 'load']);
    withdraw();
    c.save();
    expect(calls, hasLength(7));
    await tester.pump();
  });

  testWidgets(
      "C14 load reports the manifest's missing kit and keeps the engine's "
      'diagnostics; a refused load leaves both as they were (Task 7 review)',
      (tester) async {
    final json = jsonDecode(slabPlanText()) as Map<String, Object?>;
    final components = json['components']! as Map<String, Object?>;
    (components['jetcad.manifest']!
        as Map<String, Object?>)['${json['root']}'] = {
      'format': 1,
      'kits': {'gone': '3.1.0', 'test': '1.2.0'},
    };
    final slabs = components[slabTypeId]! as Map<String, Object?>;
    final damaged = slabs.keys.first;
    (slabs[damaged]! as Map<String, Object?>)['width'] = -1;
    final c = controllerFor(kits: [testKit()]);
    c.load(jsonEncode(json));
    expect(c.missingKits, {'gone'});
    // Task 11 (spec P4, E4): the unreadable slab is its kit's diagnostic
    // too, after the manifest's.
    expect([
      for (final d in c.diagnostics.value) (d.kitId, d.code)
    ], [
      ('gone', KitDiagnosticCode.kitMissing),
      ('test', KitDiagnosticCode.componentUnreadable),
    ]);
    expect(c.loadDiagnostics.single.code, 'component.unreadable');
    expect(
        c.loadDiagnostics.single.handles, [Handle.checked(int.parse(damaged))]);
    final diagnostics = c.diagnostics.value;
    final kept = c.loadDiagnostics;
    final document = c.document;
    final good = jsonDecode(slabPlanText()) as Map<String, Object?>;
    // M-C14a: load clears the plan's diagnostics before it decodes.
    // M-C14b: load forgets the engine's diagnostics before it decodes.
    for (final bad in [
      'not json',
      '{}',
      jsonEncode({...good, 'entities': 7})
    ]) {
      expect(() => c.load(bad), throwsFormatException, reason: bad);
    }
    expect(c.document, same(document));
    expect(c.diagnostics.value, same(diagnostics));
    expect(c.loadDiagnostics, same(kept));
    expect(c.missingKits, {'gone'});
    await tester.pump();
  });

  testWidgets('C13 the exporters and importers given are kept, in order',
      (tester) async {
    final c = controllerFor(kits: [testKit()]);
    expect(c.exporters, isEmpty);
    expect(c.importers, isEmpty);
    final exporters = [_Exporter('acme.dxf'), _Exporter('acme.svg')];
    final importers = [_Importer('acme.dxf')];
    final d = PlanController(
        kits: [testKit()], exporters: exporters, importers: importers);
    addTearDown(d.dispose);
    // M-C13: the lists not stored (`const []`).
    expect([for (final e in d.exporters) e.id], ['acme.dxf', 'acme.svg']);
    expect(d.importers.single, same(importers.single));
    exporters.clear();
    expect(d.exporters, hasLength(2), reason: 'copied');
  });
}

final class _Exporter implements PlanExporter {
  _Exporter(this.id);

  @override
  final String id;

  @override
  String get extension => 'dxf';

  @override
  String get mimeType => 'application/dxf';

  @override
  Future<Uint8List> export(PlanExportRequest request) async => Uint8List(0);
}

final class _Importer implements PlanImporter {
  _Importer(this.id);

  @override
  final String id;

  @override
  List<String> get extensions => const ['dxf'];

  @override
  Future<String> import(Uint8List bytes) async => '{}';
}
