// The page panel, the layer panel and their rows in shadcn (plan 2026-10-23,
// Task 7): the rules the Material controls kept and the new parts must keep.
//
// LP1 the scale field's tap group; LP2 the layer row's menu; LP3 the layer
// picker's marked entry; LP4 a blocked colour swatch's name and reason; LP5
// the canvas-owned swatch ink; LP6 the custom paper size.
import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show SelectionKey, displayPaperFor;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/chrome/icon_button.dart' show PlanTooltip;
import 'package:jet_cad_2d_plan/src/chrome/pick.dart';
import 'package:jet_cad_2d_plan/src/chrome/select.dart';
import 'package:jet_cad_2d_plan/src/chrome/text_field.dart';
import 'package:jet_cad_2d_plan/src/panels/colour_row.dart';
import 'package:jet_cad_2d_plan/src/panels/layer_picker.dart';
import 'package:jet_cad_2d_plan/src/panels/layer_row.dart' show kLayerColours;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;
import 'package:shadcn_ui/shadcn_ui.dart'
    show
        ShadContextMenuItem,
        ShadMouseAreaSurface,
        ShadMouseCursorProvider,
        ShadSlateColorScheme,
        ShadTheme,
        ShadThemeData;

import '../support/design_harness.dart';
import '../support/layer_plan.dart';
import '../support/panel_kits.dart';

const _en = PlanStringsEn();

Finder byKey(String k) => find.byKey(Key(k));

Future<void> clickAt(WidgetTester tester, Finder f) async {
  await tester.tapAt(tester.getCenter(f), kind: PointerDeviceKind.mouse);
  await tester.pump();
}

PageComponent pageOf(DraftDocument doc) =>
    doc.components.get<PageComponent>(doc.rootHandle)!;

void main() {
  testWidgets(
      'LP1 clicking the page panel\'s scale field then a Selection panel '
      'field does not commit the scale', (tester) async {
    final c = boxController();
    final b = addBox(c, Vector2(7010, 3020), const BoxParams(120, 70));
    await pumpDesign(tester, c,
        right: Column(children: [
          PlanPropertyPanel(controller: c),
          PlanPagePanel(controller: c),
        ]));
    await tester.binding.setSurfaceSize(const Size(1440, 1080));
    await tester.pump();
    addTearDown(() => tester.binding.setSurfaceSize(null));
    c.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    final depth = c.document.commands.undoDepth;
    final scale = byKey('page-scale');
    final shown = tester.widget<PlanTextField>(scale).controller.text;

    await tester.tap(scale);
    await tester.pump();
    await tester.enterText(scale, '75');
    await tester.pump();
    expect(tester.widget<PlanTextField>(scale).focusNode!.hasFocus, isTrue,
        reason: 'premise: the scale field has the focus');

    await clickAt(tester, byKey('property-width'));
    expect(
        tester
            .widget<PlanTextField>(byKey('property-width'))
            .focusNode!
            .hasFocus,
        isTrue,
        reason: 'the click took the focus to the other field');
    // M-LP1: the scale field drops groupId (bypass) -> the click is outside:
    // the focus is handed back and the field shows the page's scale again.
    expect(tester.widget<PlanTextField>(scale).controller.text, '75',
        reason: 'another text field is not outside the scale field');
    expect(tester.widget<PlanTextField>(scale).controller.text, isNot(shown));
    expect(pageOf(c.document).scaleDenominator, isNot(75));
    expect(c.document.commands.undoDepth, depth, reason: 'nothing committed');
  });

  group('LP2 the layer row\'s menu', () {
    Future<LayerPlan> pumpRow(WidgetTester tester) async {
      final fx = layerPlan();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                      width: 280,
                      child: PlanLayerPanel(controller: fx.controller))))));
      await tester.pump();
      return fx;
    }

    testWidgets(
        'opens on a click on desktop, its entries follow a permission change '
        'while it is open', (tester) async {
      final fx = await pumpRow(tester);
      final c = fx.controller;
      final doc = c.document;
      final button = byKey('layer-colour-${fx.a.toHex()}');
      expect(byKey('layer-colour-item-3'), findsNothing,
          reason: 'premise: closed');

      await clickAt(tester, button);
      await tester.pumpAndSettle();
      for (final aci in kLayerColours) {
        expect(byKey('layer-colour-item-$aci'), findsOneWidget,
            reason: 'entry $aci');
      }
      bool itemEnabled() => tester
          .widget<ShadContextMenuItem>(byKey('layer-colour-item-3'))
          .enabled;
      expect(itemEnabled(), isTrue);

      c.permissions = PlanPermissions.full.copyWith(editLayers: false);
      await tester.pumpAndSettle();
      expect(byKey('layer-colour-item-3'), findsOneWidget,
          reason: 'the menu is still open');
      expect(itemEnabled(), isFalse, reason: 'the entry follows the flag');
      await tester.tap(byKey('layer-colour-item-3'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(doc.commands.undoDepth, 0, reason: 'a disabled entry picks none');
      expect(doc.tables.layers[fx.a]!.color, const IndexedColor(1));

      c.permissions = PlanPermissions.full;
      await tester.pumpAndSettle();
      if (byKey('layer-colour-item-3').evaluate().isEmpty) {
        await clickAt(tester, button);
        await tester.pumpAndSettle();
      }
      expect(itemEnabled(), isTrue);
      await tester.tap(byKey('layer-colour-item-3'));
      await tester.pumpAndSettle();
      expect(doc.tables.layers[fx.a]!.color, const IndexedColor(3));
      expect(doc.commands.undoDepth, 1);
    });

    testWidgets('Enter on the focused button opens it and Escape closes it',
        (tester) async {
      final fx = await pumpRow(tester);
      final button = byKey('layer-colour-${fx.a.toHex()}');
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(byKey('layer-colour-item-3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(byKey('layer-colour-item-3'), findsNothing);
      // The focus is back on the row's trigger: Enter opens it again.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(byKey('layer-colour-item-3'), findsOneWidget);
    });
  });

  group('LP3 the layer picker', () {
    testWidgets('marks the current layer and no other, none for a mix',
        (tester) async {
      final fx = layerPlan(objects: true);
      final c = fx.controller;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                      width: 280,
                      child: ListenableBuilder(
                          listenable: c.selection,
                          builder: (context, _) => c.selection.isEmpty
                              ? const SizedBox.shrink()
                              : LayerPicker(controller: c)))))));
      Finder checkIn(Handle layer) => find.descendant(
          of: byKey('layer-picker-item-${layer.toHex()}'),
          matching: find.byIcon(LucideIcons.check));
      Future<void> open() async {
        await tester.tap(byKey('layer-picker'));
        await tester.pumpAndSettle();
      }

      // The mark on A.
      c.selection.replace([SelectionKey.root(fx.marks[0])]);
      await tester.pump();
      await open();
      expect(checkIn(fx.a), findsOneWidget, reason: 'A is marked');
      expect(checkIn(fx.b), findsNothing);
      expect(checkIn(fx.c), findsNothing);
      expect(checkIn(ReservedHandles.layerZero), findsNothing);
      final handle = tester.ensureSemantics();
      expect(
          tester
              .getSemantics(find.descendant(
                  of: byKey('layer-picker-item-${fx.a.toHex()}'),
                  matching: find.text('A')))
              .flagsCollection
              .isSelected,
          Tristate.isTrue);
      handle.dispose();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // The marks on A and on B: mixed, nothing is marked.
      c.selection.replace([for (final m in fx.marks) SelectionKey.root(m)]);
      await tester.pump();
      await open();
      for (final l in [fx.a, fx.b, fx.c, ReservedHandles.layerZero]) {
        expect(checkIn(l), findsNothing, reason: 'mixed: ${l.toHex()}');
      }
    });
  });

  testWidgets(
      'LP4 a blocked colour swatch\'s semantics label is the colour\'s name '
      'and its tooltip the blocked reason', (tester) async {
    final c = boxController();
    final b = addBox(c, Vector2(7010, 3020), const BoxParams(120, 70));
    c.permissions = PlanPermissions.full.copyWith(recolor: false);
    c.selection.replace([SelectionKey.root(b)]);
    final handle = tester.ensureSemantics();
    Future<void> pumpRow() async {
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: ColourRow(controller: c))));
      await tester.pump();
    }

    await pumpRow();
    final teal = byKey('color-swatch-teal');
    final node = tester.getSemantics(teal);
    expect(node.label, _en.colorName(PlanSwatch.teal));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);
    expect(
        tester
            .widget<PlanTooltip>(
                find.descendant(of: teal, matching: find.byType(PlanTooltip)))
            .message,
        _en.colorRefused);
    // Not focusable while blocked; focusable and Enter-activated when not.
    c.permissions = PlanPermissions.full;
    await pumpRow();
    final ok = tester.getSemantics(teal);
    expect(ok.flagsCollection.isEnabled, Tristate.isTrue);
    expect(ok.label, _en.colorName(PlanSwatch.teal));
    expect(
        tester
            .widget<PlanTooltip>(
                find.descendant(of: teal, matching: find.byType(PlanTooltip)))
            .message,
        _en.colorName(PlanSwatch.teal));
    handle.dispose();
  });

  testWidgets('a swatch takes the focus and Enter and Space pick it',
      (tester) async {
    var picked = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: PlanSwatchButton(
                    key: const Key('s'),
                    onTap: () => picked++,
                    child: const SizedBox.square(dimension: 24))))));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(picked, 2);
    await tester.tap(byKey('s'));
    expect(picked, 3);
  });

  testWidgets(
      'LP5 PlanLayerPanel\'s swatch ink still follows Theme.of(context)\'s '
      'surface/brightness when a ShadTheme of the other brightness is above '
      'it', (tester) async {
    final fx = layerPlan();
    final layers = fx.doc.tables.layers;
    // Layer 0 is ACI 7: the paper's ink.
    expect(layers[ReservedHandles.layerZero]!.color, const IndexedColor(7));
    final light = ThemeData(brightness: Brightness.light);
    final dark = ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadSlateColorScheme.dark());
    int inkOn(ThemeData theme) => foregroundFor(displayPaperFor(
        page: fx.controller.page.value?.background,
        surface: theme.colorScheme.surface.toARGB32(),
        brightness: theme.brightness));
    final fromMaterial = inkOn(light);
    final fromShad = foregroundFor(displayPaperFor(
        page: fx.controller.page.value?.background,
        surface: dark.colorScheme.background.toARGB32(),
        brightness: dark.brightness));
    expect(fromMaterial, isNot(fromShad), reason: 'premise: they disagree');

    await tester.pumpWidget(MaterialApp(
        theme: light,
        home: ShadTheme(
            data: dark,
            child: ShadMouseAreaSurface(
                child: ShadMouseCursorProvider(
                    child: Scaffold(
                        body: SizedBox(
                            width: 280,
                            child: PlanLayerPanel(
                                controller: fx.controller))))))));
    await tester.pump();
    final swatch = tester
        .widgetList<Container>(find.descendant(
            of: byKey('layer-colour-${ReservedHandles.layerZero.toHex()}'),
            matching: find.byType(Container)))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color)
        .whereType<Color>()
        .single;
    // M-LP5: `_foreground` reads ShadTheme -> the dark theme's ink.
    expect(swatch, Color(0xFF000000 | fromMaterial));
  });

  group('LP6 the custom paper size', () {
    testWidgets(
        'shows as today\'s choice label; refusing a size keeps the model\'s',
        (tester) async {
      final c = PlanController(kits: const []);
      addTearDown(c.dispose);
      final doc = c.document;
      doc.commands.execute(SetComponentCommand<PageComponent>(
          doc.rootHandle, PageComponent(widthMm: 200, heightMm: 300)));
      doc.commands.clearHistory();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body:
                  SizedBox(width: 280, child: PlanPagePanel(controller: c)))));
      await tester.pump();
      final preset = byKey('page-preset');
      expect(tester.widget<PlanSelect<SheetSize>>(preset).value, isNull);
      expect(find.descendant(of: preset, matching: find.text(_en.customSize)),
          findsOneWidget);

      Future<void> pickLetter() async {
        await tester.tap(preset);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Letter').last);
        await tester.pumpAndSettle();
      }

      // Refused: the document's permissions turn components away.
      doc.commands.permissions = const DraftPermissions(
          transform: true, components: false, geometry: true, structure: true);
      await pickLetter();
      expect(doc.commands.undoDepth, 0);
      expect(pageOf(doc).widthMm, 200);
      expect(find.descendant(of: preset, matching: find.text('Letter')),
          findsNothing,
          reason: 'the select shows the model\'s size, not the pick');
      expect(find.descendant(of: preset, matching: find.text(_en.customSize)),
          findsOneWidget);

      doc.commands.permissions = DraftPermissions.all;
      await pickLetter();
      expect(pageOf(doc).preset, SheetSize.letter);
      expect(find.descendant(of: preset, matching: find.text('Letter')),
          findsOneWidget);
    });
  });
}
