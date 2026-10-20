// Spec P5 "Theme" through PlanEditor (host embedding API spec T-1, T-2,
// S-5, S-11, T-3): the editor resolves the ambient PlanTheme with its own
// `theme:` over it, field by field, validated. Ported, assertions
// unchanged, from jet_cad_floor_plan/test/host/floor_plan_theme_test.dart:
// "validation (S-5), through the view" (the width cases; the opacity, bar,
// margin, radius, padding and font cases are 2b's fields), "resolution
// (T-2, S-11)" (the design mode: P-6, M-H30, the ambient switch; "a bare
// PlannerShell reads the ambient extension" and R-4 are a PlanCanvas alone,
// which reads PlanTheme.of with no scope above), "T1-c: the scope notifies
// by value" (through PlanEditor(theme:), a dependent in the bar's leading
// slot in place of a table overlay) and "FloorPlanTheme through the barrel
// alone". S-12 is ED-7 (plan_editor_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart' as barrel;
import 'package:jet_cad_2d_plan/src/canvas/plan_canvas.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor_bar.dart';
import 'package:jet_cad_2d_plan/src/panels/plan_layer_panel.dart';
import 'package:jet_cad_2d_plan/src/theme/plan_theme.dart';

import '../support/editor_host.dart';
import '../support/mark_kit.dart';

const Color seed = Color(0xFF2266CC);
final ThemeData lightTheme = ThemeData(colorSchemeSeed: seed);
final ThemeData darkTheme =
    ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark);

/// A full theme, every field off today's value.
const PlanTheme fullA = PlanTheme(
  selectionOnLight: Color(0xFFD81B60),
  selectionOnDark: Color(0xFFFFD54F),
  selectionWidth: 4,
  canvasBackground: Color(0xFF263238),
);

/// A second full theme, every field different from [fullA]'s and today's.
const PlanTheme fullB = PlanTheme(
  selectionOnLight: Color(0xFF5E35B1),
  selectionOnDark: Color(0xFFC0CA33),
  selectionWidth: 2.5,
  canvasBackground: Color(0xFFEFEBE9),
);

ThemeData lightWith(PlanTheme t) => lightTheme.copyWith(extensions: [t]);
ThemeData darkWith(PlanTheme t) => darkTheme.copyWith(extensions: [t]);

/// The theme resolved inside the editor (its Layers section reads it).
PlanTheme? resolvedIn(WidgetTester tester) =>
    PlanThemeScope.of(tester.element(find.byType(PlanLayerPanel)));

/// Pumps [view] at 1440 x 900 under [theme] (zero theme animation) and
/// lets the first frames land.
Future<void> pumpUnder(WidgetTester tester, Widget view,
    {ThemeData? theme,
    ThemeData? dark,
    ThemeMode mode = ThemeMode.light}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      theme: theme ?? lightTheme,
      darkTheme: dark ?? darkTheme,
      themeMode: mode,
      themeAnimationDuration: Duration.zero,
      home: Scaffold(body: view)));
  await tester.pump();
}

/// A dependent of the resolved theme: logs each dependency change.
class ThemeReader extends StatefulWidget {
  const ThemeReader({super.key, required this.log});
  final List<PlanTheme?> log;
  @override
  State<ThemeReader> createState() => _ThemeReaderState();
}

class _ThemeReaderState extends State<ThemeReader> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.log.add(PlanThemeScope.of(context));
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}

PlanController plan() => editorController(json: editorPlanJson());

void main() {
  group('validation (S-5), through the view', () {
    testWidgets(
        'the width: accepted and refused, naming the field; an ambient '
        'theme out of range is refused the same way', (tester) async {
      final c = plan();
      Future<Object?> pumpWith({PlanTheme? view, PlanTheme? ambient}) async {
        await pumpUnder(tester, PlanEditor(controller: c, theme: view),
            theme: ambient == null ? lightTheme : lightWith(ambient));
        return tester.takeException();
      }

      final accepted = <(String, PlanTheme)>[
        ('selectionWidth', const PlanTheme(selectionWidth: 0.5)),
        ('all', fullA),
      ];
      final refused = <(String, PlanTheme)>[
        for (final v in [0.0, -1.0, double.infinity, double.nan])
          ('selectionWidth', PlanTheme(selectionWidth: v)),
      ];
      for (final (name, theme) in accepted) {
        expect(await pumpWith(view: theme), isNull, reason: '$name: $theme');
        expect(find.byType(PlanEditor), findsOneWidget,
            reason: '$name: $theme');
        expect(resolvedIn(tester), theme);
        expect(await pumpWith(ambient: theme), isNull,
            reason: 'ambient $name: $theme');
      }
      for (final (name, theme) in refused) {
        for (final ambient in [false, true]) {
          final e = ambient
              ? await pumpWith(ambient: theme)
              : await pumpWith(view: theme);
          expect(e, isA<ArgumentError>().having((e) => e.name, 'name', name),
              reason: '${ambient ? 'ambient ' : ''}$name: $theme');
        }
      }
      // The constructor itself never throws: each refused theme was built.
      expect(refused, hasLength(4));
    });
  });

  group('resolution (T-2, S-11)', () {
    testWidgets(
        'P-6: no theme anywhere resolves to null; ambient only is the '
        'ambient itself; view only the view itself', (tester) async {
      final c = plan();
      await pumpUnder(tester, PlanEditor(controller: c));
      expect(resolvedIn(tester), isNull);

      await pumpUnder(tester, PlanEditor(controller: c),
          theme: lightWith(fullA));
      expect(identical(resolvedIn(tester), fullA), isTrue);

      await pumpUnder(tester, PlanEditor(controller: c, theme: fullB));
      expect(identical(resolvedIn(tester), fullB), isTrue);
    });

    testWidgets(
        'M-H30: one field in the ambient theme and another in the view\'s '
        'resolve to both; one field in both takes the view\'s', (tester) async {
      final c = plan();
      await pumpUnder(
          tester,
          PlanEditor(
              controller: c,
              theme: const PlanTheme(selectionOnLight: Color(0xFFD81B60))),
          theme:
              lightWith(const PlanTheme(canvasBackground: Color(0xFF00897B))));
      expect(
          resolvedIn(tester),
          const PlanTheme(
              canvasBackground: Color(0xFF00897B),
              selectionOnLight: Color(0xFFD81B60)));

      await pumpUnder(tester,
          PlanEditor(controller: c, theme: const PlanTheme(selectionWidth: 5)),
          theme: lightWith(const PlanTheme(
              selectionWidth: 3, canvasBackground: Color(0xFF00897B))));
      expect(
          resolvedIn(tester),
          const PlanTheme(
              selectionWidth: 5, canvasBackground: Color(0xFF00897B)));
    });

    testWidgets(
        'an ambient switch (light with A to dark with B, zero animation) '
        'reaches the editor after one pump', (tester) async {
      final c = plan();
      final view = PlanEditor(controller: c);
      await pumpUnder(tester, view,
          theme: lightWith(fullA), dark: darkWith(fullB));
      expect(resolvedIn(tester), fullA);
      await pumpUnder(tester, view,
          theme: lightWith(fullA), dark: darkWith(fullB), mode: ThemeMode.dark);
      expect(resolvedIn(tester), fullB);
    });

    testWidgets('a bare PlanCanvas reads the ambient extension',
        (tester) async {
      final c = plan();
      await tester.pumpWidget(MaterialApp(
          theme: lightWith(fullA),
          themeAnimationDuration: Duration.zero,
          home: PlanCanvas(controller: c)));
      await tester.pump();
      expect(
          identical(PlanThemeScope.of(tester.element(find.byType(PlanCanvas))),
              fullA),
          isTrue);
      await tester.pumpWidget(MaterialApp(
          themeAnimationDuration: Duration.zero,
          home: PlanCanvas(controller: c)));
      await tester.pump();
      expect(
          PlanThemeScope.of(tester.element(find.byType(PlanCanvas))), isNull);
    });

    testWidgets(
        'R-4: a bare PlanCanvas refuses an ambient theme out of range, '
        'naming the field', (tester) async {
      // A controller per app: each bare canvas is a host's own (the source's
      // bare shells each had a document of their own).
      for (final (bad, name) in [
        (const PlanTheme(selectionWidth: -3), 'selectionWidth'),
      ]) {
        await tester.pumpWidget(MaterialApp(
            key: UniqueKey(),
            theme: lightWith(fullA.merge(bad)),
            themeAnimationDuration: Duration.zero,
            home: PlanCanvas(controller: plan())));
        expect(tester.takeException(),
            isA<ArgumentError>().having((e) => e.name, 'name', name),
            reason: name);
      }
      // In range: accepted.
      await tester.pumpWidget(MaterialApp(
          key: UniqueKey(),
          theme: lightWith(fullA),
          themeAnimationDuration: Duration.zero,
          home: PlanCanvas(controller: plan())));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(PlanThemeScope.of(tester.element(find.byType(PlanCanvas))), fullA);
    });
  });

  group('T1-c: the scope notifies by value', () {
    testWidgets(
        'a host rebuild with an equal, non-identical view theme notifies no '
        'dependent; a different one does', (tester) async {
      final c = plan();
      final log = <PlanTheme?>[];
      final reader = ThemeReader(log: log);
      PlanEditor viewWith(PlanTheme theme) => PlanEditor(
          controller: c, theme: theme, bar: PlanEditorBar(leading: [reader]));
      await pumpUnder(tester, viewWith(fullA.copyWith()));
      expect(find.byType(ThemeReader), findsOneWidget);
      expect(log, [fullA]);

      await pumpUnder(tester, viewWith(fullA.copyWith()));
      expect(log, [fullA], reason: 'an equal theme notifies nobody');

      await pumpUnder(tester, viewWith(fullB.copyWith()));
      expect(log, [fullA, fullB]);
    });
  });

  testWidgets(
      'PlanTheme through the barrel alone: in ThemeData(extensions:) and '
      'PlanEditor(theme:)', (tester) async {
    final c = barrel.PlanController(kits: [markKit()], json: editorPlanJson());
    addTearDown(c.dispose);
    const barrel.PlanTheme ambient = barrel.PlanTheme(
        canvasBackground: Color(0xFF263238),
        selectionOnLight: Color(0xFF5E35B1));
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: const [ambient]),
        home: barrel.PlanEditor(
            controller: c,
            // Desktop chrome at a sub-desktop test surface (POS-host D4).
            layout: barrel.PlanEditorLayout.desktop,
            theme: const barrel.PlanTheme(
                selectionOnLight: Color(0xFFD81B60), selectionWidth: 3))));
    await tester.pump();
    expect(
        resolvedIn(tester),
        const barrel.PlanTheme(
            canvasBackground: Color(0xFF263238),
            selectionOnLight: Color(0xFFD81B60),
            selectionWidth: 3));
  });
}
