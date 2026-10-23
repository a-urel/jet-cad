// The panel parts of jet_cad_floor_plan's l10n tests that Task 9 sent here
// (2a Task 18); assertions unchanged:
// - NN1 from test/l10n/numbered_names_test.dart (spec 14d L7, M-14d-k);
// - PW1 and PW2 from test/l10n/panel_words_test.dart (spec 14d L12, L15),
//   the Page panel and layer parts: the Wall section's words, fields and
//   edits go with the wall to sub-project 3, the zoom read-out to Task 20's
//   bar test;
// - SE2 from test/l10n/stale_error_test.dart (review 14d-1 F-3), renamed
//   SE2L (Task 17's selection_panel_test.dart holds an SE2); SE1 (a table
//   number) is 2b's.
import 'dart:async' show StreamSubscription;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/src/chrome/text_field.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/l10n/localizations.dart';
import 'package:jet_cad_2d_plan/src/l10n/strings_de.dart';
import 'package:jet_cad_2d_plan/src/l10n/strings_tr.dart';
import 'package:jet_cad_2d_plan/src/panels/layer_picker.dart';
import 'package:jet_cad_2d_plan/src/panels/plan_layer_panel.dart';
import 'package:jet_cad_2d_plan/src/panels/plan_page_panel.dart';

import '../support/layer_plan.dart';
import '../support/mark_kit.dart';

DraftDocument withLayers(List<String> names) {
  final doc = DraftDocument.empty();
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  for (final name in names) {
    doc.tables.layers.add(LayerRecord(
      handle: doc.handleSeed.next(),
      name: name,
      color: const IndexedColor(2),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: true,
      locked: false,
    ));
  }
  return doc;
}

/// The picker alone, shown while the selection is not empty and rebuilt on
/// every selection and document change, as `PlanPropertyPanel` mounts it
/// (copied from layer_page_controller_test.dart).
class PickerHost extends StatefulWidget {
  const PickerHost(this.controller, {super.key});

  final PlanController controller;

  @override
  State<PickerHost> createState() => _PickerHostState();
}

class _PickerHostState extends State<PickerHost> {
  late final StreamSubscription<DocChange> _changes;

  @override
  void initState() {
    super.initState();
    widget.controller.selection.addListener(_refresh);
    _changes =
        widget.controller.document.commands.changes.listen((_) => _refresh());
  }

  @override
  void dispose() {
    _changes.cancel();
    widget.controller.selection.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.controller.selection.isEmpty
      ? const SizedBox.shrink()
      : LayerPicker(controller: widget.controller);
}

/// P-6's layers with a mark on `A` (in place of the source's wall) and the
/// page at 1:12.5.
LayerPlan wallPlan() => layerPlan(more: (doc, a, b, c) {
      final page = doc.components.get<PageComponent>(doc.rootHandle)!;
      doc.commands.execute(SetComponentCommand<PageComponent>(
          doc.rootHandle, page.copyWith(scaleDenominator: 12.5)));
      return [addMark(doc, a, at: placed(-1830.5, 640.25, 0.4))];
    });

/// The Layer panel, the Page panel and the layer picker over [c], in
/// [locale].
Widget app(PlanController c, Locale locale) => MaterialApp(
    locale: locale,
    supportedLocales: planSupportedLocales,
    localizationsDelegates: planLocalizationsDelegates,
    home: Scaffold(
        body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
                width: 280,
                child: SingleChildScrollView(
                    child: Column(children: [
                  PlanLayerPanel(controller: c),
                  PlanPagePanel(controller: c),
                  PickerHost(c),
                ]))))));

String fieldText(WidgetTester tester, String key) =>
    tester.widget<PlanTextField>(find.byKey(Key(key))).controller.text;

/// [wallPlan] pumped in [locale], its mark selected (the source selected
/// the wall).
Future<PlanController> pumpWall(WidgetTester tester, Locale locale) async {
  final fx = wallPlan();
  final c = fx.controller;
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app(c, locale));
  await tester.pump();
  c.selection.replace([SelectionKey.root(fx.marks.last)]);
  await tester.pump();
  await tester.pump();
  return c;
}

Future<void> typeInto(WidgetTester tester, String key, String text) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump();
}

/// P-6's layers and a layer `Bar` beside them.
(PlanController, Handle) withBar() {
  late final Handle bar;
  final fx = layerPlan(more: (doc, a, b, c) {
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    bar = doc.handleSeed.next();
    doc.commands.execute(AddLayerCommand(LayerRecord(
        handle: bar,
        name: 'Bar',
        color: const IndexedColor(5),
        linetype: zero.linetype,
        lineweight: zero.lineweight,
        transparency: zero.transparency,
        visible: true,
        locked: false)));
    return const [];
  });
  return (fx.controller, bar);
}

Future<ValueNotifier<Locale>> pumpLayers(
    WidgetTester tester, PlanController c) async {
  final locale = ValueNotifier(const Locale('de'));
  addTearDown(locale.dispose);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ValueListenableBuilder<Locale>(
      valueListenable: locale,
      builder: (_, l, __) => MaterialApp(
          locale: l,
          supportedLocales: planSupportedLocales,
          localizationsDelegates: planLocalizationsDelegates,
          home: Scaffold(
              body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                      width: 280, child: PlanLayerPanel(controller: c)))))));
  await tester.pump();
  return locale;
}

String? errorOf(WidgetTester tester, String key) =>
    tester.widget<PlanTextField>(find.byKey(Key(key))).errorText;

void main() {
  test('NN1 a layer\'s N is counted over every language (M-14d-k)', () {
    final doc = withLayers(['Layer 1', 'katman 2', 'Ebene 4', 'Layer 05']);
    expect(nextLayerName(doc, const PlanStringsDe()), 'Ebene 3');
    expect(nextLayerName(doc, const PlanStringsTr()), 'Katman 3');
    expect(nextLayerName(doc), 'Layer 3');
    final full = withLayers(['Layer 1', 'Ebene 2', 'Katman 3']);
    expect(nextLayerName(full, const PlanStringsTr()), 'Katman 4');
  });

  testWidgets(
      'PW1 in Turkish the Wall section, the Page panel and the layers speak '
      'Turkish; numbers show and read with a comma (L12, L15, M-14d-f)',
      (tester) async {
    await pumpWall(tester, const Locale('tr'));
    for (final w in ['Sayfa', 'Ölçek', 'Izgara', 'Katmanlar', 'Katman']) {
      expect(find.text(w), findsWidgets, reason: w);
    }
    expect(fieldText(tester, 'page-scale'), '12,5');
  });

  testWidgets(
      'PW2 in German the Page panel reads a comma; a switch to English while '
      'mounted shows the fields again with a point (M-14d-s)', (tester) async {
    final c = await pumpWall(tester, const Locale('de'));
    expect(find.text('Maßstab'), findsOneWidget);
    await typeInto(tester, 'page-scale', '20,5');
    final page =
        c.document.components.get<PageComponent>(c.document.rootHandle)!;
    expect(page.scaleDenominator, 20.5);
    expect(fieldText(tester, 'page-scale'), '20,5');

    await tester.pumpWidget(app(c, const Locale('en')));
    await tester.pump();
    expect(fieldText(tester, 'page-scale'), '20.5');
  });

  testWidgets(
      'SE2L a layer name already used, refused in German, reads in English '
      'after the switch', (tester) async {
    final (c, bar) = withBar();
    final locale = await pumpLayers(tester, c);
    final hex = bar.toHex();
    await tester.tap(find.byKey(Key('layer-name-$hex')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(Key('layer-name-$hex')));
    await tester.pump();
    await tester.pump();
    final field = 'layer-name-field-$hex';
    expect(find.byKey(Key(field)), findsOneWidget,
        reason: 'premise: the rename is open');
    await tester.enterText(find.byKey(Key(field)), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(errorOf(tester, field), 'Eine Ebene namens 0 gibt es bereits.',
        reason: 'premise: refused in German');
    locale.value = const Locale('en');
    await tester.pump();
    await tester.pump();
    expect(errorOf(tester, field), 'A layer named 0 already exists.');
    await tester.pump(const Duration(seconds: 1));
  });
}
