// Spec P2 (the widgets take only the controller; `editLayers`,
// `editPage` and `changeLayer`; documents swapped inside the controller)
// and P4 (a locked object's layer change refused up front and at commit):
// the Layer and Page panels and the layer picker over a PlanController.
import 'dart:async' show StreamSubscription;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/src/chrome/select.dart';
import 'package:jet_cad_2d_plan/src/chrome/rows.dart';
import 'package:jet_cad_2d_plan/src/chrome/pick.dart';
import 'package:jet_cad_2d_plan/src/chrome/text_field.dart';
import 'package:jet_cad_2d_plan/src/chrome/menu_button.dart';
import 'package:jet_cad_2d_plan/src/chrome/icon_button.dart';
import 'package:jet_cad_2d_plan/src/controller/permissions.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/l10n/localizations.dart';
import 'package:jet_cad_2d_plan/src/l10n/strings_en.dart';
import 'package:jet_cad_2d_plan/src/panels/layer_picker.dart';
import 'package:jet_cad_2d_plan/src/panels/plan_layer_panel.dart';
import 'package:jet_cad_2d_plan/src/panels/plan_page_panel.dart';

import '../support/layer_plan.dart';
import '../support/mark_kit.dart';

const _en = PlanStringsEn();

Finder byKey(String k) => find.byKey(Key(k));

String hx(Handle h) => h.toHex();

bool enabled(WidgetTester tester, String key) =>
    tester.widget<PlanIconButton>(byKey(key)).onPressed != null;

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// [c]'s Layer and Page panels in a 280-wide right column.
Future<void> pumpPanels(WidgetTester tester, PlanController c) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 280,
          child: SingleChildScrollView(
            child: Column(children: [
              PlanLayerPanel(controller: c),
              PlanPagePanel(controller: c),
            ]),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

/// The picker alone, shown while the selection is not empty and rebuilt on
/// every selection and document change, as `PlanPropertyPanel` mounts it.
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

Future<void> pumpPicker(WidgetTester tester, PlanController c) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 280, child: PickerHost(c))))));
  await tester.pump();
}

Future<void> openPicker(WidgetTester tester) async {
  await tester.tap(byKey('layer-picker'));
  await tester.pumpAndSettle();
}

String pickerTooltip(WidgetTester tester) =>
    tester.widget<PlanMenuButton<Handle>>(byKey('layer-picker')).label;

bool pickerEnabled(WidgetTester tester) =>
    tester.widget<PlanMenuButton<Handle>>(byKey('layer-picker')).enabled;

void main() {
  testWidgets(
      'LP-1 a load swaps the document under the Layer panel: the new rows '
      'show, the old document loses the panel\'s listener, the selected row '
      'is dropped, and a control acts on the new document', (tester) async {
    final first = layerPlan();
    final second = layerPlan(objects: true);
    final c = first.controller;
    final old = c.document;
    final base = old.tables.debugListenerCount;
    await pumpPanels(tester, c);
    expect(old.tables.debugListenerCount, base + 1, reason: 'premise');
    await tester.tap(byKey('layer-row-${hx(first.c)}'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
        tester.state<PlanLayerPanelState>(find.byType(PlanLayerPanel)).selected,
        first.c,
        reason: 'premise: a row is selected');

    // The two plans' layers share their handles (one seed sequence), so a
    // panel left on the old document would keep the selected row: the
    // listener count and the dropped selection tell the two apart.
    final json = second.controller.save();
    c.load(json);
    await settle(tester);
    final now = c.document;
    expect(identical(now, old), isFalse, reason: 'premise: swapped');
    // M-LP-1: `_onController` rebuilds without `_bind()`.
    expect(old.tables.debugListenerCount, base,
        reason: 'the old document lost the panel');
    expect(
        tester.state<PlanLayerPanelState>(find.byType(PlanLayerPanel)).selected,
        isNull);
    final lock = 'layer-lock-${hx(second.a)}';
    expect(byKey(lock), findsOneWidget);
    await tester.tap(byKey(lock));
    await settle(tester);
    expect(now.tables.layers[second.a]!.locked, isTrue);
    expect(now.commands.undoDepth, 1);
  });

  testWidgets(
      'LP-2 editLayers off at runtime disables + and every row control with '
      'the neutral reason; a colour menu opened before picks nothing; on '
      'again enables them', (tester) async {
    final fx = layerPlan();
    final c = fx.controller;
    await pumpPanels(tester, c);
    final a = hx(fx.a);
    // The colour menu opened while editing is allowed.
    await tester.tap(byKey('layer-colour-$a'));
    await tester.pumpAndSettle();
    final before = DraftDocumentCodec.encodeToString(c.document);

    c.permissions = PlanPermissions.full.copyWith(editLayers: false);
    await tester.pump();
    final item = byKey('layer-colour-item-4');
    expect(item, findsWidgets, reason: 'the menu is still open');
    await tester.tap(item.last);
    await tester.pumpAndSettle();
    // M-LP-2: `_allowed` ignores `permissions.editLayers`.
    expect(DraftDocumentCodec.encodeToString(c.document), before);
    expect(c.document.commands.undoDepth, 0);
    for (final key in [
      'layers-add',
      'layer-eye-$a',
      'layer-lock-$a',
      'layer-current-$a',
    ]) {
      expect(enabled(tester, key), isFalse, reason: key);
    }
    expect(tester.widget<PlanMenuButton<int>>(byKey('layer-colour-$a')).enabled,
        isFalse);
    expect(tester.widget<PlanIconButton>(byKey('layers-delete')).label,
        _en.layersLocked);
    expect(byKey('layers-list'), findsOneWidget, reason: 'the list is shown');

    c.permissions = PlanPermissions.full;
    await tester.pump();
    expect(enabled(tester, 'layers-add'), isTrue);
    expect(enabled(tester, 'layer-eye-$a'), isTrue);
  });

  testWidgets(
      'LP-3 a load swaps the document under the Page panel: it shows the new '
      'page\'s scale and unit and edits the new document', (tester) async {
    final first = layerPlan();
    final c = first.controller;
    // A second plan at 1:20 in cm, built on its own controller.
    final other = layerPlan().controller;
    final root = other.document.rootHandle;
    final page = other.document.components.get<PageComponent>(root)!;
    other.document.commands.execute(SetComponentCommand<PageComponent>(
        root,
        page.copyWith(
            scaleDenominator: 20, displayUnit: DisplayUnit.centimeters)));
    final json = other.save();
    await pumpPanels(tester, c);
    expect(tester.widget<PlanTextField>(byKey('page-scale')).controller.text,
        isNot('20'),
        reason: 'premise');

    c.load(json);
    await settle(tester);
    // M-LP-3: `_onController` does not rebind the page notifier.
    expect(tester.widget<PlanTextField>(byKey('page-scale')).controller.text,
        '20');
    expect(tester.widget<PlanSelect<DisplayUnit>>(byKey('page-unit')).value,
        DisplayUnit.centimeters);
    await tester.tap(byKey('page-grid'));
    await tester.pump();
    expect(c.document.commands.undoDepth, 1, reason: 'the new document');
  });

  testWidgets(
      'LP-4 editPage off at runtime disables every page control and a tap '
      'writes nothing; on again enables them', (tester) async {
    final fx = layerPlan();
    final c = fx.controller;
    await pumpPanels(tester, c);
    c.permissions = PlanPermissions.full.copyWith(editPage: false);
    await tester.pump();
    bool presetEnabled() =>
        tester.widget<PlanSelect<SheetSize>>(byKey('page-preset')).enabled;
    // M-LP-4: `_editable` ignores `permissions.editPage`.
    expect(presetEnabled(), isFalse);
    expect(tester.widget<PlanTextField>(byKey('page-scale')).enabled, isFalse);
    expect(tester.widget<PlanCheckRow>(byKey('page-grid')).onChanged, isNull);
    expect(
        tester.widget<PlanSwatchButton>(byKey('page-swatch-3')).onTap, isNull);
    final before = DraftDocumentCodec.encodeToString(c.document);
    await tester.tap(byKey('page-grid'));
    await tester.tap(byKey('page-swatch-3'));
    await tester.pump();
    expect(DraftDocumentCodec.encodeToString(c.document), before);
    expect(enabled(tester, 'layers-add'), isTrue,
        reason: 'editLayers is another flag');

    c.permissions = PlanPermissions.full;
    await tester.pump();
    expect(presetEnabled(), isTrue);
  });

  testWidgets(
      'LP-5 the controller\'s settle re-syncs a typed, unsubmitted scale: '
      'the field shows the page\'s scale and nothing is written',
      (tester) async {
    final fx = layerPlan();
    final c = fx.controller;
    await pumpPanels(tester, c);
    final shown =
        tester.widget<PlanTextField>(byKey('page-scale')).controller.text;
    await tester.enterText(byKey('page-scale'), '77');
    await tester.pump();
    expect(
        tester.widget<PlanTextField>(byKey('page-scale')).controller.text, '77',
        reason: 'premise: typed, not submitted');

    c.settlePendingInput();
    await tester.pump();
    // M-LP-5: the panel registers no settler.
    expect(tester.widget<PlanTextField>(byKey('page-scale')).controller.text,
        shown);
    expect(c.document.commands.undoDepth, 0);
  });

  testWidgets(
      'LP-6 a missing kit\'s object in the selection: the picker is disabled '
      'with the lock\'s reason, ahead of the plain group\'s', (tester) async {
    // The marks are saved by a plan that has the kit, then opened without
    // it: they are locked (spec P4) and their type is not in the catalog.
    final fx = layerPlan(objects: true, kits: const []);
    final c = fx.controller;
    final line = addLineOn(c.document, fx.a, 1250.5, 3400.25, 4100.75, 3650.5);
    final mark = fx.marks[0];
    expect(c.isLocked(mark), isTrue, reason: 'premise: a missing kit');
    expect(c.catalog.typeIdOf(c.document, mark), isNull,
        reason: 'premise: no type for it');
    await pumpPicker(tester, c);
    c.selection.replace([SelectionKey.root(line), SelectionKey.root(mark)]);
    await tester.pump();
    expect(pickerEnabled(tester), isFalse);
    // M-LP-6: drop the lock test from `layerPickerBlocked`; the reason
    // becomes the plain group's.
    expect(pickerTooltip(tester), _en.lockedNoLayer);
    c.selection.replace([SelectionKey.root(line)]);
    await tester.pump();
    expect(pickerEnabled(tester), isTrue, reason: 'the line alone moves');
  });

  testWidgets(
      'LP-7 an object locked after the picker\'s menu opened: the choice is '
      'refused at commit by the lock, caught, and nothing changes',
      (tester) async {
    final fx = layerPlan(objects: true);
    final c = fx.controller;
    final mark = fx.marks[0];
    expect(c.catalog.typeIdOf(c.document, mark), MarkCross.componentTypeId,
        reason: 'premise: a live object of the kit');
    await pumpPicker(tester, c);
    c.selection.replace([SelectionKey.root(mark)]);
    await tester.pump();
    await openPicker(tester);
    c.lockBroken({mark});
    final before = DraftDocumentCodec.encodeToString(c.document);
    await tester
        .tap(byKey('layer-picker-item-${hx(ReservedHandles.layerZero)}'));
    await tester.pumpAndSettle();
    // M-LP-7: `LayerPicker._choose` calling `document.commands.execute`
    // in place of `controller.execute`.
    expect(tester.takeException(), isNull);
    expect(DraftDocumentCodec.encodeToString(c.document), before);
    expect(objectLayerOf(c.document, mark), fx.a);
    // M-LP-7b: `PlanController.execute`'s `on PlanLocked` clause does not
    // raise the canvas's lock hint.
    expect(c.lockHint.value, isTrue, reason: 'the refusal is shown');
  });

  testWidgets(
      'LP-8 changeLayer off while the picker\'s menu is open: the choice '
      'does nothing', (tester) async {
    final fx = layerPlan(objects: true);
    final c = fx.controller;
    final line = addLineOn(c.document, fx.a, 1250.5, 3400.25, 4100.75, 3650.5);
    c.document.commands.clearHistory();
    await pumpPicker(tester, c);
    c.selection.replace([SelectionKey.root(line)]);
    await tester.pump();
    await openPicker(tester);
    c.permissions = PlanPermissions.full.copyWith(changeLayer: false);
    await tester.pump();
    await tester
        .tap(byKey('layer-picker-item-${hx(ReservedHandles.layerZero)}'));
    await tester.pumpAndSettle();
    // M-LP-8: drop the `changeLayer` test from `_choose`.
    expect(c.document.commands.undoDepth, 0);
    expect(layerOf(c.document, line), fx.a);
  });

  testWidgets(
      'LP-L each panel alone reports the app\'s locale to its controller '
      '(spec P5: every widget pushes it)', (tester) async {
    for (final (name, panel) in <(String, Widget Function(PlanController))>[
      ('layers', (c) => PlanLayerPanel(controller: c)),
      ('page', (c) => PlanPagePanel(controller: c)),
    ]) {
      final c = layerPlan().controller;
      expect(c.locale.value, const Locale('en'), reason: 'premise: $name');
      await tester.pumpWidget(MaterialApp(
          locale: const Locale('de'),
          supportedLocales: planSupportedLocales,
          localizationsDelegates: planLocalizationsDelegates,
          home: Scaffold(body: SizedBox(width: 280, child: panel(c)))));
      await tester.pump();
      // M-LP-La, M-LP-Lb: the panel's `didChangeDependencies` without
      // `PlanLocaleScope.push`.
      expect(c.locale.value, const Locale('de'), reason: name);
    }
  });
}
