// Spec P5 "Theme": PlanTheme, the generic part of jet_cad_floor_plan's
// FloorPlanTheme, its value semantics, copyWith, merge and lerp, and its
// resolution below a PlanThemeScope: the ambient extension with the view's
// set fields over it, validated, provided by an inherited widget compared
// by ==. Ported from floor_plan_theme_test.dart (host embedding API spec
// Slice 3, T-1, T-2, S-3 to S-5, S-11, T-3) over the four fields that move;
// the statuses, groups, focus veil, table colour and service bar are 2b's.
//
// The themes are not the default shape: colours that are no palette's and
// no other theme's, widths that are not today's.
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show PaperPalette;
import 'package:jet_cad_2d_plan/src/theme/plan_theme.dart';

const Color seed = Color(0xFF2266CC);
final ThemeData lightTheme = ThemeData(colorSchemeSeed: seed);
final ThemeData darkTheme =
    ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark);
const int white = 0xFFFFFFFF;
const int blueprint = 0xFF1F3A5F;

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

typedef Field = ({
  String name,
  Object? Function(PlanTheme t) get,
  PlanTheme Function(PlanTheme t, Object v) set,
  Object? Function(Object a, Object b, double t) lerp,
});

Object? _color(Object a, Object b, double t) =>
    Color.lerp(a as Color, b as Color, t);
Object? _double(Object a, Object b, double t) =>
    lerpDouble(a as double, b as double, t);

/// The four fields, in declaration order.
final List<Field> fields = [
  (
    name: 'selectionOnLight',
    get: (t) => t.selectionOnLight,
    set: (t, v) => t.copyWith(selectionOnLight: v as Color),
    lerp: _color,
  ),
  (
    name: 'selectionOnDark',
    get: (t) => t.selectionOnDark,
    set: (t, v) => t.copyWith(selectionOnDark: v as Color),
    lerp: _color,
  ),
  (
    name: 'selectionWidth',
    get: (t) => t.selectionWidth,
    set: (t, v) => t.copyWith(selectionWidth: v as double),
    lerp: _double,
  ),
  (
    name: 'canvasBackground',
    get: (t) => t.canvasBackground,
    set: (t, v) => t.copyWith(canvasBackground: v as Color),
    lerp: _color,
  ),
];

PlanTheme only(Field field, PlanTheme source) =>
    field.set(const PlanTheme(), field.get(source)!);

void expectField(Object? a, Object? b, String reason) {
  if (a is double && b is double) {
    expect(a, closeTo(b, 1e-12), reason: reason);
  } else {
    expect(a, b, reason: reason);
  }
}

ThemeData lightWith(PlanTheme t) => lightTheme.copyWith(extensions: [t]);
ThemeData darkWith(PlanTheme t) => darkTheme.copyWith(extensions: [t]);

/// A valid theme whose width sits near the edge of its range.
const PlanTheme edgeA = PlanTheme(selectionWidth: 3);

/// [edgeA]'s partner: the width different.
const PlanTheme edgeB = PlanTheme(selectionWidth: 0.5);

/// The resolved theme a widget under a PlanThemeScope over [view] reads,
/// under [theme] (or the light theme), [dark] and [mode], zero animation.
PlanTheme? seen;

Widget scopeApp(
        {PlanTheme? view,
        ThemeData? theme,
        ThemeData? dark,
        ThemeMode mode = ThemeMode.light,
        bool scope = true,
        Key? key}) =>
    MaterialApp(
        key: key,
        theme: theme ?? lightTheme,
        darkTheme: dark ?? darkTheme,
        themeMode: mode,
        themeAnimationDuration: Duration.zero,
        home: scope
            ? PlanThemeScope(view: view, child: const _Probe())
            : const _Probe());

class _Probe extends StatelessWidget {
  const _Probe();
  @override
  Widget build(BuildContext context) {
    seen = PlanTheme.of(context);
    return const SizedBox();
  }
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

void main() {
  setUp(() => seen = null);

  test('TH0 the field table names the four fields of a full theme', () {
    expect(fields, hasLength(4));
    for (final f in fields) {
      expect(f.get(fullA), isNotNull, reason: f.name);
      expect(f.get(fullB), isNotNull, reason: f.name);
      expect(f.get(fullA) == f.get(fullB), isFalse, reason: f.name);
      expect(f.get(const PlanTheme()), isNull, reason: f.name);
      expect(fullA.toString(), contains('${f.name}: '), reason: f.name);
    }
  });

  group('merge (T-2)', () {
    test(
        'TH1 a view setting one field over an ambient setting all four: '
        'that field the view\'s, the three others the ambient\'s', () {
      // M-TH1: `merge` taking `this.canvasBackground ?? other...` (the
      // ambient over the view) goes red for canvasBackground.
      for (final f in fields) {
        final merged = fullB.merge(only(f, fullA));
        for (final g in fields) {
          final want = identical(g, f) ? g.get(fullA) : g.get(fullB);
          expect(g.get(merged), want, reason: '${f.name} set: ${g.name}');
        }
      }
    });

    test('TH2 a null view is the ambient itself; an empty view keeps it', () {
      expect(identical(fullA.merge(null), fullA), isTrue);
      expect(fullA.merge(const PlanTheme()), fullA);
      expect(const PlanTheme().merge(fullA), fullA);
    });
  });

  group('lerp (S-4)', () {
    test(
        'TH3 two full themes at 0, 0.25, 0.5 and 1: each field its type\'s '
        'lerp', () {
      // M-TH3: `selectionWidth` lerped with `t` and `1 - t` swapped.
      for (final t in [0.0, 0.25, 0.5, 1.0]) {
        final l = fullA.lerp(fullB, t);
        for (final f in fields) {
          expectField(f.get(l), f.lerp(f.get(fullA)!, f.get(fullB)!, t),
              '${f.name} at $t');
        }
      }
      for (final f in fields) {
        expect(f.get(fullA.lerp(fullB, 0)), f.get(fullA), reason: f.name);
        expect(f.get(fullA.lerp(fullB, 1)), f.get(fullB), reason: f.name);
      }
      expect(fullA.lerp(fullB, 0.25) == fullA, isFalse);
    });

    test(
        'TH4 R-1: two valid themes at t -0.2 and 1.2, both ways: the width '
        'within its ends, the theme valid', () {
      // M-TH4: `_lerpBetween` returning `lerpDouble(a, b, t)!` unclamped.
      for (final t in [-0.2, 1.2]) {
        for (final (a, b) in [(edgeA, edgeB), (edgeB, edgeA)]) {
          final l = a.lerp(b, t);
          final reason = '${a == edgeA ? 'A to B' : 'B to A'} at $t';
          expect(l.selectionWidth, inInclusiveRange(0.5, 3.0), reason: reason);
          expect(() => validatePlanTheme(l), returnsNormally, reason: reason);
        }
      }
      expect(edgeA.lerp(edgeB, 1.2).selectionWidth, 0.5);
      expect(edgeB.lerp(edgeA, 1.2).selectionWidth, 3.0);
    });

    test(
        'TH5 R-2: a theme lerped with an equal one is that theme at every t '
        '(itself when equal); a field equal on both sides stays exactly '
        'equal', () {
      for (var i = 1; i < 100; i++) {
        final t = i / 100;
        expect(fullA.lerp(fullA, t), fullA, reason: 'at $t');
        expect(identical(fullA.lerp(fullA.copyWith(), t), fullA), isTrue,
            reason: 'at $t');
        final l = fullA.lerp(fullA.copyWith(selectionWidth: 5), t);
        expect(l.selectionWidth, closeTo(4 + t, 1e-12), reason: 'at $t');
        for (final f in fields.where((f) => f.name != 'selectionWidth')) {
          expect(f.get(l) == f.get(fullA), isTrue, reason: '${f.name} at $t');
        }
      }
    });

    test(
        'TH6 T1-b: a field null on one side switches at 0.5 and never fades '
        '(no selectionOnLight to 0xFF00897B: null at 0.25, opaque at 0.75)',
        () {
      // M-TH6: `_lerp` lerping toward a null side as transparent
      // (`Color.lerp(a, null, t)`) makes 0.75 translucent.
      const to = PlanTheme(selectionOnLight: Color(0xFF00897B));
      expect(const PlanTheme().lerp(to, 0.25).selectionOnLight, isNull);
      final at75 = const PlanTheme().lerp(to, 0.75).selectionOnLight!;
      expect(at75, const Color(0xFF00897B));
      expect(at75.a, 1.0);
      for (final t in [0.0, 0.25, 0.49]) {
        expect(const PlanTheme().lerp(fullB, t), const PlanTheme(),
            reason: 'at $t');
        expect(fullA.lerp(const PlanTheme(), t), fullA, reason: 'at $t');
      }
      for (final t in [0.5, 0.75, 1.0]) {
        expect(const PlanTheme().lerp(fullB, t), fullB, reason: 'at $t');
        expect(fullA.lerp(const PlanTheme(), t), const PlanTheme(),
            reason: 'at $t');
      }
    });

    test('TH7 lerp(null, t) is the theme itself', () {
      for (final t in [0.0, 0.3, 1.0]) {
        expect(identical(fullA.lerp(null, t), fullA), isTrue);
      }
    });

    test(
        'TH8 through ThemeData.lerp: a light ThemeData with the extension and '
        'a dark one without carry the first\'s unchanged; both with it, '
        'lerped', () {
      for (final t in [0.25, 0.75]) {
        expect(
            identical(
                ThemeData.lerp(lightWith(fullA), darkTheme, t)
                    .extension<PlanTheme>(),
                fullA),
            isTrue,
            reason: 'at $t');
        expect(
            ThemeData.lerp(lightWith(fullA), darkWith(fullB), t)
                .extension<PlanTheme>(),
            fullA.lerp(fullB, t),
            reason: 'at $t');
      }
    });
  });

  group('copyWith, ==, hashCode, toString', () {
    test('TH9 each field changed alone makes != and a different hash', () {
      // M-TH9: `==` without `other.canvasBackground == canvasBackground`.
      expect(fullA, fullA.copyWith());
      expect(identical(fullA, fullA.copyWith()), isFalse);
      expect(fullA.copyWith().hashCode, fullA.hashCode);
      for (final f in fields) {
        final changed = f.set(fullA, f.get(fullB)!);
        expect(f.get(changed), f.get(fullB), reason: f.name);
        for (final g in fields) {
          if (!identical(g, f)) {
            expect(g.get(changed), g.get(fullA),
                reason: '${f.name}: ${g.name}');
          }
        }
        expect(changed == fullA, isFalse, reason: f.name);
        expect(changed.hashCode == fullA.hashCode, isFalse, reason: f.name);
        expect(only(f, fullA) == const PlanTheme(), isFalse, reason: f.name);
        expect(only(f, fullA).hashCode == const PlanTheme().hashCode, isFalse,
            reason: f.name);
      }
    });

    test('TH10 toString names the set fields only, in declaration order', () {
      expect(const PlanTheme().toString(), 'PlanTheme()');
      expect(const PlanTheme(selectionWidth: 4).toString(),
          'PlanTheme(selectionWidth: 4.0)');
      const canvas = Color(0xFF263238);
      expect(
          const PlanTheme(canvasBackground: canvas, selectionWidth: 4)
              .toString(),
          'PlanTheme(selectionWidth: 4.0, canvasBackground: $canvas)');
      expect(fullA.type, PlanTheme);
    });
  });

  group('validation (S-5), through the scope', () {
    testWidgets(
        'TH11 the width: accepted and refused, naming the field; an ambient '
        'theme out of range is refused the same way', (tester) async {
      // M-TH11: `validatePlanTheme` without its `positive(selectionWidth)`
      // call accepts every refused theme.
      Future<Object?> pumpWith({PlanTheme? view, PlanTheme? ambient}) async {
        await tester.pumpWidget(scopeApp(
            key: UniqueKey(),
            view: view,
            theme: ambient == null ? lightTheme : lightWith(ambient)));
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
        expect(seen, theme, reason: '$name: $theme');
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
      expect(refused, hasLength(4));
    });
  });

  group('resolution (T-2, S-11)', () {
    testWidgets(
        'TH12 P-6: no theme anywhere resolves to null; ambient '
        'only is the ambient itself; view only the view itself',
        (tester) async {
      // M-TH12: `PlanThemeScope.build` merging `view.merge(ambient)` (the
      // ambient over the view) breaks the identity of the view-only case
      // only when an ambient exists, so TH13 catches it; here, a scope that
      // drops the view (`InheritedPlanTheme(theme: ambient, ...)`) goes red.
      await tester.pumpWidget(scopeApp());
      expect(seen, isNull);

      await tester.pumpWidget(scopeApp(theme: lightWith(fullA)));
      expect(identical(seen, fullA), isTrue);

      await tester.pumpWidget(scopeApp(view: fullB));
      expect(identical(seen, fullB), isTrue);
    });

    testWidgets(
        'TH13 M-H30: one field in the ambient theme and another in the '
        'view\'s resolve to both; one field in both takes the view\'s',
        (tester) async {
      await tester.pumpWidget(scopeApp(
          view: const PlanTheme(selectionOnLight: Color(0xFFD81B60)),
          theme:
              lightWith(const PlanTheme(canvasBackground: Color(0xFF00897B)))));
      expect(
          seen,
          const PlanTheme(
              canvasBackground: Color(0xFF00897B),
              selectionOnLight: Color(0xFFD81B60)));

      await tester.pumpWidget(scopeApp(
          view: const PlanTheme(selectionWidth: 5),
          theme: lightWith(const PlanTheme(
              selectionWidth: 3, canvasBackground: Color(0xFF00897B)))));
      expect(
          seen,
          const PlanTheme(
              selectionWidth: 5, canvasBackground: Color(0xFF00897B)));
    });

    testWidgets(
        'TH14 an ambient switch (light with A to dark with B, zero '
        'animation) reaches the scope after one pump', (tester) async {
      await tester
          .pumpWidget(scopeApp(theme: lightWith(fullA), dark: darkWith(fullB)));
      expect(seen, fullA);
      await tester.pumpWidget(scopeApp(
          theme: lightWith(fullA),
          dark: darkWith(fullB),
          mode: ThemeMode.dark));
      await tester.pump();
      expect(seen, fullB);
    });

    testWidgets(
        'TH15 with no scope above, the ambient extension, validated: in '
        'range read, out of range refused naming the field (R-4)',
        (tester) async {
      // M-TH15: `PlanThemeScope.of` returning the ambient without
      // `validatePlanTheme` lets the bad width through.
      await tester.pumpWidget(scopeApp(scope: false, theme: lightWith(fullA)));
      expect(identical(seen, fullA), isTrue);
      await tester.pumpWidget(scopeApp(scope: false, key: UniqueKey()));
      expect(seen, isNull);

      await tester.pumpWidget(scopeApp(
          scope: false,
          key: UniqueKey(),
          theme: lightWith(fullA.merge(const PlanTheme(selectionWidth: -3)))));
      expect(tester.takeException(),
          isA<ArgumentError>().having((e) => e.name, 'name', 'selectionWidth'));
    });
  });

  group('T1-c: the scope notifies by value', () {
    test('TH16 updateShouldNotify: false for equal themes, true for different',
        () {
      // M-TH16: `updateShouldNotify` returning `!identical(theme, old.theme)`.
      final a1 = fullA.copyWith();
      final a2 = fullA.copyWith();
      expect(identical(a1, a2), isFalse);
      InheritedPlanTheme scope(PlanTheme? t) =>
          InheritedPlanTheme(theme: t, child: const SizedBox());
      expect(scope(a1).updateShouldNotify(scope(a2)), isFalse);
      expect(scope(null).updateShouldNotify(scope(null)), isFalse);
      expect(scope(fullA).updateShouldNotify(scope(fullB)), isTrue);
      expect(scope(fullA).updateShouldNotify(scope(null)), isTrue);
      expect(scope(null).updateShouldNotify(scope(fullA)), isTrue);
    });

    testWidgets(
        'TH17 a host rebuild with an equal, non-identical view theme notifies '
        'no dependent; a different one does', (tester) async {
      final log = <PlanTheme?>[];
      final reader = ThemeReader(log: log);
      Widget app(PlanTheme view) => MaterialApp(
          theme: lightTheme,
          themeAnimationDuration: Duration.zero,
          home: PlanThemeScope(view: view, child: reader));
      await tester.pumpWidget(app(fullA.copyWith()));
      expect(log, [fullA]);
      await tester.pumpWidget(app(fullA.copyWith()));
      expect(log, [fullA], reason: 'an equal theme notifies nobody');
      await tester.pumpWidget(app(fullB.copyWith()));
      expect(log, [fullA, fullB]);
    });
  });

  test(
      'TH18 planPaperPaletteFor: today\'s const sets with no colour for the '
      'set', () {
    const onLight = Color(0xFFD81B60);
    const onDark = Color(0xFFFFD54F);
    expect(identical(planPaperPaletteFor(white, null), PaperPalette.light),
        isTrue);
    expect(identical(planPaperPaletteFor(blueprint, null), PaperPalette.dark),
        isTrue);
    const lightOnly = PlanTheme(selectionOnLight: onLight);
    const darkOnly = PlanTheme(selectionOnDark: onDark);
    expect(
        identical(planPaperPaletteFor(blueprint, lightOnly), PaperPalette.dark),
        isTrue);
    expect(identical(planPaperPaletteFor(white, darkOnly), PaperPalette.light),
        isTrue);
    // M-TH18: the two colours swapped (`selectionOnLight` for the dark set).
    expect(planPaperPaletteFor(white, lightOnly),
        PaperPalette.light.withSelection(onLight));
    expect(planPaperPaletteFor(blueprint, darkOnly),
        PaperPalette.dark.withSelection(onDark));
    expect(
        identical(
            planPaperPaletteFor(white, const PlanTheme(selectionWidth: 4)),
            PaperPalette.light),
        isTrue);
  });
}
