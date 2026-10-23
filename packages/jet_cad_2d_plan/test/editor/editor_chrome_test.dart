// The editor's chrome in shadcn (spec "The component mapping", ED1-ED6):
// the bar's and the palette's parts, the tabs, the derived surface, the
// layouts, the selected semantics and large text.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/chrome/icon_button.dart';
import 'package:jet_cad_2d_plan/src/chrome/segmented.dart';
import 'package:jet_cad_2d_plan/src/chrome/shad_scope.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../support/editor_host.dart'
    show editorPlanJson, embeddingCamera, slowSymbolsKit;
import '../support/mark_kit.dart';

Finder k(String key) => find.byKey(Key(key));

const _primary = Color(0xFF123456);

Future<PlanController> pump(WidgetTester tester, double w, double h,
    {Widget Function(Widget editor)? wrap,
    double textScale = 1,
    PlanEditorLayout? layout}) async {
  final c = PlanController(
      kits: [markKit(), slowSymbolsKit()], json: editorPlanJson());
  addTearDown(c.dispose);
  await tester.binding.setSurfaceSize(Size(w, h));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final editor = PlanEditor(controller: c, gallery: true, layout: layout);
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
          textScaler: textScale == 1
              ? TextScaler.noScaling
              : TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(body: wrap == null ? editor : wrap(editor)),
  ));
  await tester.pump();
  await tester.pump();
  c.camera.value = embeddingCamera();
  await tester.pump();
  return c;
}

Widget hostShad(Widget editor) => ShadTheme(
      data: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadSlateColorScheme.light(primary: _primary),
      ),
      child: editor,
    );

/// Whether a `DecoratedBox` under [of] paints [colour].
bool paints(WidgetTester tester, Finder of, Color colour) => tester
    .widgetList<DecoratedBox>(
        find.descendant(of: of, matching: find.byType(DecoratedBox)))
    .any((d) => (d.decoration as dynamic).color == colour);

void main() {
  testWidgets(
      'ED1 under a host ShadTheme the bar\'s Undo is a PlanIconButton and the '
      'palette\'s selected tool button is drawn in the theme\'s secondary',
      (tester) async {
    await pump(tester, 800, 900, wrap: hostShad);
    expect(tester.widget(k('toolbar-undo')), isA<PlanIconButton>());
    final theme = ShadTheme.of(tester.element(k('toolbar-undo')));
    expect(theme.colorScheme.primary, _primary);
    expect(k('tool-plan.select'), findsOneWidget);
    expect(tester.widget(k('tool-plan.select')), isA<PlanIconButton>());
    expect(paints(tester, k('tool-plan.select'), theme.colorScheme.secondary),
        isTrue);
    expect(paints(tester, k('tool-plan.line'), theme.colorScheme.secondary),
        isFalse);
  });

  testWidgets(
      'ED2 the Tools/Symbols switch is a PlanSegmented whose segments keep '
      'today\'s keys', (tester) async {
    await pump(tester, 1440, 900);
    expect(tester.widget(k('left-tabs')), isA<PlanSegmented<dynamic>>());
    expect(k('tab-tools'), findsOneWidget);
    expect(k('tab-symbols'), findsOneWidget);
    expect(
        tester.widgetList<ShadButton>(find.descendant(
            of: k('left-tabs'), matching: find.byType(ShadButton))),
        hasLength(2));
    await tester.tap(k('tab-symbols'));
    await tester.pump();
    expect(k('tool-plan.line'), findsNothing);
  });

  testWidgets(
      'ED3 under a bare MaterialApp the bar\'s surface is the derived '
      'background', (tester) async {
    await pump(tester, 1440, 900);
    final derived = planShadThemeOf(tester.element(k('chrome-top')));
    final bar = tester.widget<Container>(k('chrome-top'));
    expect((bar.decoration as BoxDecoration?)?.color ?? bar.color,
        derived.colorScheme.background);
    expect(derived.colorScheme.background,
        Theme.of(tester.element(k('chrome-top'))).colorScheme.surface);
  });

  testWidgets(
      'ED4 desktop, tablet and phone layouts keep their columns and '
      'drawers', (tester) async {
    await pump(tester, 1440, 900);
    expect(k('chrome-left'), findsOneWidget);
    expect(k('chrome-right'), findsOneWidget);
    await pump(tester, 800, 900);
    expect(k('chrome-tool-strip'), findsOneWidget);
    expect(k('chrome-symbols-button'), findsOneWidget);
    expect(k('chrome-right-button'), findsOneWidget);
    await tester.tap(k('chrome-right-button'));
    await tester.pump();
    expect(k('chrome-right-drawer').hitTestable(), findsOneWidget);
    await pump(tester, 375, 812);
    expect(k('chrome-left'), findsNothing);
    expect(k('chrome-left-button'), findsOneWidget);
    await tester.tap(k('chrome-left-button'));
    await tester.pump();
    expect(k('chrome-left-drawer').hitTestable(), findsOneWidget);
  });

  testWidgets('ED5 the palette\'s selected tool exposes selected semantics',
      (tester) async {
    final handle = tester.ensureSemantics();
    for (final width in [1440.0, 800.0]) {
      await pump(tester, width, 900);
      final node = tester.getSemantics(k('tool-plan.select'));
      expect(node.flagsCollection.isSelected, Tristate.isTrue,
          reason: '$width');
      final other = tester.getSemantics(k('tool-plan.line'));
      expect(other.flagsCollection.isSelected, Tristate.isFalse);
    }
    handle.dispose();
  });

  for (final scale in [1.5, 2.0]) {
    for (final width in [375.0, 800.0, 1280.0]) {
      testWidgets('ED6 text x$scale at $width: no overflow', (tester) async {
        await pump(tester, width, 900, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
