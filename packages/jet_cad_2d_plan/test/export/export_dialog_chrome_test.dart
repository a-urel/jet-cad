// The export dialog's chrome (spec "The export dialog"): showPlanExportDialog
// is public and may be called from a bare MaterialApp, so it resolves the
// shadcn theme and the words at the call site and pushes its own route.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart'
    show planLocalizationsDelegates;
import 'package:jet_cad_2d_plan/src/chrome/shad_scope.dart';
import 'package:jet_cad_2d_plan/src/export/builtin_exporters.dart';
import 'package:jet_cad_2d_plan/src/export/export_dialog.dart';
import 'package:jet_cad_2d_plan/src/export/registries.dart';
import 'package:jet_cad_2d_plan/src/l10n/strings_en.dart';
import 'package:jet_cad_2d_plan/src/l10n/strings_tr.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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

const _localScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF7A1F5C),
  onPrimary: Color(0xFFFFF0FA),
  secondary: Color(0xFF1F7A5C),
  onSecondary: Color(0xFFF0FFFA),
  error: Color(0xFFB00020),
  onError: Color(0xFFFFFFFF),
  surface: Color(0xFFE6F0FA),
  onSurface: Color(0xFF301030),
);

final _exporters = <PlanExporter>[
  const PlanPdfExporter(),
  const PlanPngExporter(),
];

PlanExportAnswer? _got;
bool _done = false;

Widget _opener({String keyName = 'open'}) => Builder(
    builder: (context) => TextButton(
        key: Key(keyName),
        onPressed: () async {
          _got = await showPlanExportDialog(
              context, PlanExportAnswer.initial, _exporters);
          _done = true;
        },
        child: const Text('open')));

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

ShadThemeData _dialogTheme(WidgetTester tester) =>
    ShadTheme.of(tester.element(find.byKey(const Key('export-dialog'))));

void main() {
  setUp(() {
    _got = const PlanExportAnswer(
        exporter: 'unset', choice: PlanExportChoice.initial);
    _done = false;
  });

  for (final dark in [false, true]) {
    testWidgets(
        'EX1 called directly under a bare MaterialApp (no editor) '
        'opens, ${dark ? 'dark' : 'light'}', (tester) async {
      final scheme = dark ? _darkScheme : _lightScheme;
      await tester.pumpWidget(
          MaterialApp(theme: ThemeData(colorScheme: scheme), home: _opener()));
      await _open(tester);
      expect(find.byKey(const Key('export-dialog')), findsOneWidget);
      expect(find.byType(ShadDialog), findsOneWidget);
      expect(_dialogTheme(tester).brightness,
          dark ? Brightness.dark : Brightness.light);
      expect(_dialogTheme(tester).colorScheme.primary, scheme.primary);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      "EX2 called from inside a local Theme with a distinct ColorScheme, the "
      "dialog's card is that scheme's derived card colour", (tester) async {
    final local = ThemeData(colorScheme: _localScheme);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(colorScheme: _lightScheme),
        home: Theme(data: local, child: _opener())));
    await _open(tester);
    final expected = planShadThemeFrom(local).colorScheme.card;
    expect(
        expected,
        isNot(planShadThemeFrom(ThemeData(colorScheme: _lightScheme))
            .colorScheme
            .card),
        reason: 'premise: the local card differs from the app card');
    expect(_dialogTheme(tester).colorScheme.card, expected);
    final painted = find.descendant(
        of: find.byKey(const Key('export-dialog')),
        matching: find.byWidgetPredicate((w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == expected));
    expect(painted, findsWidgets, reason: 'the card is painted in it');
  });

  testWidgets('EX3 called under a host ShadTheme, the dialog uses it',
      (tester) async {
    const host = Color(0xFFC0391B);
    final data = ShadThemeData(
      brightness: Brightness.light,
      colorScheme: const ShadSlateColorScheme.light(primary: host),
    );
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(colorScheme: _lightScheme),
        builder: (context, child) => ShadTheme(data: data, child: child!),
        home: _opener()));
    await _open(tester);
    expect(_dialogTheme(tester).colorScheme.primary, host);
    expect(_dialogTheme(tester).colorScheme.card, data.colorScheme.card);
  });

  testWidgets(
      "EX4 the dialog's words come from the caller's PlanStrings "
      '(Turkish)', (tester) async {
    const tr = PlanStringsTr();
    const en = PlanStringsEn();
    expect(tr.exportTitle, isNot(en.exportTitle), reason: 'premise');
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: const [Locale('en'), Locale('tr')],
        localizationsDelegates: const [
          ...planLocalizationsDelegates,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: _opener()));
    await _open(tester);
    expect(tr.exportAction, tr.exportTitle, reason: 'premise: one word');
    expect(find.text(tr.exportTitle), findsNWidgets(2),
        reason: 'the title and the primary button');
    expect(find.text(tr.cancel), findsOneWidget);
    expect(find.text(en.exportTitle), findsNothing);
  });

  testWidgets(
      'EX5 Escape and the barrier dismiss it with null; the primary '
      'button returns the answer', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _opener()));
    await _open(tester);
    await tester.tap(find.byKey(const Key('export-format-plan.png')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('export-dialog')), findsNothing);
    expect(_done, isTrue);
    expect(_got, isNull);

    _done = false;
    await _open(tester);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('export-dialog')), findsNothing);
    expect(_done, isTrue);
    expect(_got, isNull);

    _done = false;
    await _open(tester);
    await tester.tap(find.byKey(const Key('export-format-plan.png')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('export-ok')));
    await tester.pumpAndSettle();
    expect(_done, isTrue);
    expect(_got?.exporter, 'plan.png');
  });
}
