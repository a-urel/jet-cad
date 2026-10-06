// Spec 14d I-3, M-14d-g (revision 2, V-9): a document's bytes never depend
// on the UI language. From a loaded plan, the same edits made through the
// UI in English and in Turkish -- a table placed from the palette, turned
// through the Rotation field, renumbered through the Number field -- encode
// to the same bytes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/l10n/localizations.dart';

import 'panel_words_test.dart' show wallPlan;

Future<void> commit(WidgetTester tester, String key, String text) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump();
}

/// [json] edited through the UI in [locale]; the design's encoding.
Future<String> editedIn(WidgetTester tester, String json, Locale locale) async {
  final c = FloorPlanController(json: json);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  await tester.pumpWidget(MaterialApp(
      locale: locale,
      supportedLocales: floorPlanSupportedLocales,
      localizationsDelegates: floorPlanLocalizationsDelegates,
      home: Scaffold(body: FloorPlanView(controller: c))));
  await tester.pump();
  await tester.tap(find.byKey(const Key('tab-symbols')));
  await tester.pump();
  await tester.runAsync(() async {
    while (!c.symbols.state.toString().contains('Ready')) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
  await tester.pump();
  await tester
      .tap(find.byKey(const Key('symbol-cell-dining.table.square.two@2')));
  await tester.pump();
  final canvas = tester.getRect(find.byType(InteractionLayer));
  await tester.tapAt(canvas.center + const Offset(37, -23));
  await tester.pump();
  await tester.pump();
  final placed = c.activeDocument.tree.nodes.whereType<InstanceNode>();
  expect(placed, hasLength(1), reason: 'premise: one table placed');
  c.activeSelection.replace([SelectionKey.root(placed.single.handle)]);
  await tester.pump();
  await commit(tester, 'symbol-rotation', '30');
  await commit(tester, 'table-number', '7');
  final out = c.designJson();
  await tester.pumpWidget(const SizedBox());
  c.dispose();
  return out;
}

void main() {
  testWidgets(
      'DT1 the same UI edits in English and in Turkish encode the same '
      '(I-3, M-14d-g)', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (json, _) = wallPlan();
    final en = await editedIn(tester, json, const Locale('en'));
    final tr = await editedIn(tester, json, const Locale('tr'));
    expect(en, contains('"7"'), reason: 'premise: renumbered');
    expect(en, contains('Square dining table, 2 seats'),
        reason: 'premise: the copy keeps the library\'s English name');
    expect(tr, en);
  });
}
