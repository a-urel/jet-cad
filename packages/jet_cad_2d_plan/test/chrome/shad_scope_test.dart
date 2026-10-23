// The shadcn scope (spec "The scope (G2, G3)"): what `PlanShadScope`
// provides under a bare Material host, under a host's own ShadTheme, and
// what it installs below either.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/chrome/shad_scope.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../support/service_fixtures.dart' show embeddingPlanJson, fxKit;

// Distinct, non-default colours: no field equals another or a library
// default, so a mapping that reads the wrong token shows.
const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF204080),
  onPrimary: Color(0xFFF0F0FF),
  secondary: Color(0xFF608020),
  onSecondary: Color(0xFFFFFFF0),
  error: Color(0xFFA02020),
  onError: Color(0xFFFFFFFF),
  surface: Color(0xFFFAF0E6),
  onSurface: Color(0xFF1A2B3C),
  // Distinct, so a mapping that swaps border and input goes red.
  outline: Color(0xFF707880),
  outlineVariant: Color(0xFFC8CCD4),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF9FB4FF),
  onPrimary: Color(0xFF001040),
  secondary: Color(0xFFB4D07A),
  onSecondary: Color(0xFF102000),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  surface: Color(0xFF121A24),
  onSurface: Color(0xFFE3EAF2),
);

ShadThemeData? _seen;
TextStyle? _style;
IconThemeData? _icon;

/// Records what a descendant of the scope reads.
final Widget _probe = Builder(builder: (context) {
  _seen = ShadTheme.maybeOf(context);
  _style = DefaultTextStyle.of(context).style;
  _icon = IconTheme.of(context);
  return const SizedBox();
});

Widget _material(ThemeData theme, Widget child) =>
    MaterialApp(theme: theme, home: child);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUp(() {
    _seen = null;
    _style = null;
    _icon = null;
  });

  testWidgets(
      'SC1 under a bare MaterialApp a scope provides a ShadTheme whose '
      "background is the ColorScheme's surface and foreground its onSurface",
      (tester) async {
    await tester.pumpWidget(_material(
        ThemeData(colorScheme: _lightScheme), PlanShadScope(child: _probe)));
    final s = _seen!.colorScheme;
    expect(s.background, _lightScheme.surface);
    expect(s.foreground, _lightScheme.onSurface);
    expect(s.primary, _lightScheme.primary);
    expect(s.primaryForeground, _lightScheme.onPrimary);
    expect(s.destructive, _lightScheme.error);
    expect(s.destructiveForeground, _lightScheme.onError);
    expect(s.border, _lightScheme.outlineVariant);
    expect(s.input, _lightScheme.outline);
    expect(s.ring, _lightScheme.primary);
    expect(s.muted, _lightScheme.surfaceContainerHighest);
    expect(s.mutedForeground, _lightScheme.onSurfaceVariant);
    expect(s.accent, _lightScheme.surfaceContainerHigh);
    expect(s.card, _lightScheme.surfaceContainerLow);
    expect(s.popover, _lightScheme.surfaceContainerLow);
    expect(s.secondary, _lightScheme.secondaryContainer);
    expect(s.secondaryForeground, _lightScheme.onSecondaryContainer);
  });

  testWidgets(
      'SC10 the derived theme fills an unchecked checkbox and an off switch '
      "with the scheme's outlineVariant, not shadcn's default input "
      '(the outline, a dark fill on a Material scheme)', (tester) async {
    await tester.pumpWidget(_material(
        ThemeData(colorScheme: _lightScheme), PlanShadScope(child: _probe)));
    final t = _seen!;
    expect(_lightScheme.outlineVariant, isNot(_lightScheme.outline),
        reason: 'premise');
    expect(t.checkboxTheme.uncheckedColor, _lightScheme.outlineVariant);
    expect(t.switchTheme.uncheckedTrackColor, _lightScheme.outlineVariant);
  });

  testWidgets(
      "SC2 under an ancestor ShadTheme the scope's descendants read that "
      "ShadTheme's colours", (tester) async {
    const host = Color(0xFF123456);
    final data = ShadThemeData(
      brightness: Brightness.light,
      colorScheme: const ShadSlateColorScheme.light(primary: host),
    );
    await tester.pumpWidget(_material(ThemeData(colorScheme: _lightScheme),
        ShadTheme(data: data, child: PlanShadScope(child: _probe))));
    expect(_seen!.colorScheme.primary, host);
    expect(_seen, same(data));
    // Not the Material scheme's.
    expect(_seen!.colorScheme.background, isNot(_lightScheme.surface));
  });

  testWidgets('SC3 dark ThemeData -> derived brightness dark', (tester) async {
    await tester.pumpWidget(_material(
        ThemeData(colorScheme: _darkScheme), PlanShadScope(child: _probe)));
    expect(_seen!.brightness, Brightness.dark);
    expect(_seen!.colorScheme.background, _darkScheme.surface);
    await tester.pumpWidget(_material(
        ThemeData(colorScheme: _lightScheme), PlanShadScope(child: _probe)));
    // MaterialApp animates a theme change.
    await tester.pumpAndSettle();
    expect(_seen!.brightness, Brightness.light);
  });

  testWidgets(
      "SC4 a plain Text below the scope takes the ShadTheme's font family "
      'and foreground', (tester) async {
    final data = ShadThemeData(
      brightness: Brightness.light,
      colorScheme:
          const ShadSlateColorScheme.light(foreground: Color(0xFF445566)),
      textTheme: ShadTextTheme(family: 'ScopeTestFont'),
    );
    await tester.pumpWidget(_material(
        ThemeData(colorScheme: _lightScheme),
        ShadTheme(
            data: data,
            child: const PlanShadScope(child: Text('plain', key: Key('t'))))));
    final rich = tester.widget<RichText>(find.descendant(
        of: find.byKey(const Key('t')), matching: find.byType(RichText)));
    expect(rich.text.style?.fontFamily, 'ScopeTestFont');
    expect(rich.text.style?.color, const Color(0xFF445566));
  });

  testWidgets('SC5 an Icon below the scope takes the foreground',
      (tester) async {
    await tester.pumpWidget(_material(
        ThemeData(colorScheme: _lightScheme), PlanShadScope(child: _probe)));
    expect(_icon!.color, _lightScheme.onSurface);
    expect(_icon!.size, 16);
    expect(_style!.color, _lightScheme.onSurface);
  });

  testWidgets(
      'SC6 switching the ancestor ShadTheme light->dark rebuilds '
      'descendants with the dark colours, no exception', (tester) async {
    Widget host(Brightness b) => _material(
        ThemeData(colorScheme: _lightScheme),
        ShadTheme(
            data: ShadThemeData(
                brightness: b,
                colorScheme: b == Brightness.dark
                    ? const ShadSlateColorScheme.dark()
                    : const ShadSlateColorScheme.light()),
            child: PlanShadScope(child: _probe)));
    await tester.pumpWidget(host(Brightness.light));
    final light = _seen!.colorScheme.background;
    final lightText = _style!.color;
    await tester.pumpWidget(host(Brightness.dark));
    expect(tester.takeException(), isNull);
    expect(_seen!.brightness, Brightness.dark);
    expect(_seen!.colorScheme.background,
        const ShadSlateColorScheme.dark().background);
    expect(_seen!.colorScheme.background, isNot(light));
    expect(_style!.color, const ShadSlateColorScheme.dark().foreground);
    expect(_style!.color, isNot(lightText));
    expect(_icon!.color, const ShadSlateColorScheme.dark().foreground);
  });

  testWidgets(
      'SC7 a useMaterial3:false ThemeData and a ColorScheme built with only '
      'the required fields derive readable pairs', (tester) async {
    for (final theme in [
      ThemeData(useMaterial3: false, colorScheme: _lightScheme),
      ThemeData(useMaterial3: false, colorScheme: _darkScheme),
      ThemeData(useMaterial3: false),
      ThemeData(colorScheme: _lightScheme),
      ThemeData(colorScheme: _darkScheme),
    ]) {
      final s = planShadThemeFrom(theme).colorScheme;
      expect(_contrast(s.foreground, s.background), greaterThanOrEqualTo(4.5),
          reason: 'foreground on background');
      expect(
          _contrast(s.primaryForeground, s.primary), greaterThanOrEqualTo(4.5),
          reason: 'primaryForeground on primary');
    }
    await tester.pumpWidget(_material(
        ThemeData(useMaterial3: false), PlanShadScope(child: _probe)));
    expect(_seen, isNotNull);
  });

  testWidgets(
      'SC8 the derived data is computed once for one ThemeData across two '
      'rebuilds', (tester) async {
    final theme = ThemeData(colorScheme: _lightScheme);
    final before = debugPlanShadDerivations;
    await tester.pumpWidget(_material(theme, PlanShadScope(child: _probe)));
    final first = _seen;
    expect(debugPlanShadDerivations, before + 1);
    await tester.pumpWidget(_material(
        theme, PlanShadScope(key: const Key('again'), child: _probe)));
    await tester.pumpWidget(_material(
        theme, PlanShadScope(key: const Key('and again'), child: _probe)));
    expect(debugPlanShadDerivations, before + 1);
    expect(_seen, same(first));
    // A different ThemeData derives again.
    planShadThemeFrom(ThemeData(colorScheme: _darkScheme));
    expect(debugPlanShadDerivations, before + 2);
  });

  testWidgets('SC9 data given: the scope provides it over an ancestor',
      (tester) async {
    final mine = ShadThemeData(
      brightness: Brightness.light,
      colorScheme: const ShadSlateColorScheme.light(primary: Color(0xFF654321)),
    );
    final theirs = ShadThemeData(
      brightness: Brightness.light,
      colorScheme: const ShadSlateColorScheme.light(primary: Color(0xFF123456)),
    );
    await tester.pumpWidget(_material(
        ThemeData(colorScheme: _lightScheme),
        ShadTheme(
            data: theirs, child: PlanShadScope(data: mine, child: _probe))));
    expect(_seen!.colorScheme.primary, const Color(0xFF654321));
  });

  testWidgets(
      'SC10 the derived scope provides the mouse surface and cursor shadcn '
      'components need; the host scope-less pass-through does not duplicate',
      (tester) async {
    await tester.pumpWidget(_material(
        ThemeData(colorScheme: _lightScheme), PlanShadScope(child: _probe)));
    expect(find.byType(ShadMouseAreaSurface), findsOneWidget);
    expect(find.byType(ShadMouseCursorProvider), findsOneWidget);
    await tester.pumpWidget(_material(
        ThemeData(colorScheme: _lightScheme),
        ShadTheme(
            data: ShadThemeData(brightness: Brightness.light),
            child: PlanShadScope(child: _probe))));
    expect(find.byType(ShadMouseAreaSurface), findsNothing);
  });

  group('SC11 every public widget root mounts a scope', () {
    Future<void> mount(
        WidgetTester tester, Type root, Widget Function(PlanController) w,
        {bool service = false}) async {
      final c = PlanController(kits: [fxKit()], json: embeddingPlanJson());
      addTearDown(c.dispose);
      if (service) c.setMode(PlanMode.service);
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: w(c))));
      await tester.pump();
      await tester.pump();
      expect(
          find.descendant(
              of: find.byType(root), matching: find.byType(PlanShadScope)),
          findsWidgets);
    }

    testWidgets('PlanEditor',
        (t) => mount(t, PlanEditor, (c) => PlanEditor(controller: c)));
    testWidgets(
        'PlanToolPalette',
        (t) =>
            mount(t, PlanToolPalette, (c) => PlanToolPalette(controller: c)));
    testWidgets(
        'PlanSymbolGallery',
        (t) => mount(
            t, PlanSymbolGallery, (c) => PlanSymbolGallery(controller: c)));
    testWidgets(
        'PlanPropertyPanel',
        (t) => mount(
            t, PlanPropertyPanel, (c) => PlanPropertyPanel(controller: c)));
    testWidgets('PlanLayerPanel',
        (t) => mount(t, PlanLayerPanel, (c) => PlanLayerPanel(controller: c)));
    testWidgets('PlanPagePanel',
        (t) => mount(t, PlanPagePanel, (c) => PlanPagePanel(controller: c)));
    testWidgets(
        'PlanServiceView',
        (t) => mount(t, PlanServiceView, (c) => PlanServiceView(controller: c),
            service: true));
  });
}
