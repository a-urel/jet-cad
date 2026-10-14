// Spec P5 "Theme": PlanTheme, the generic part of jet_cad_floor_plan's
// FloorPlanTheme, its value semantics, copyWith, merge and lerp, and its
// resolution below a PlanThemeScope: the ambient extension with the view's
// set fields over it, validated, provided by an inherited widget compared
// by ==. Ported from floor_plan_theme_test.dart (host embedding API spec
// Slice 3, T-1, T-2, S-3 to S-5, S-11, T-3) over the four fields that move;
// 2b (Task 15) takes back the source's seventeen fields: the statuses,
// groups, focus veil, unit colour and service bar, their merge, lerp,
// overshoot and validation; assertions unchanged.
//
// The themes are not the default shape: colours that are no palette's and
// no other theme's, widths and sizes that are not today's, an asymmetric
// padding, opacities that are not 0, 1 or 0.6.
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
  statusCaptionStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
  statusFillOpacity: 0.5,
  unitColourOpacity: 0.25,
  groupFrameColor: Color(0xFF00897B),
  groupFrameWidth: 3,
  groupFrameMargin: 300,
  groupChipColor: Color(0xFF3949AB),
  groupChipTextStyle: TextStyle(fontSize: 13),
  groupChipRadius: 8,
  groupChipPadding: EdgeInsets.fromLTRB(7, 3, 9, 4),
  selectionOnLight: Color(0xFFD81B60),
  selectionOnDark: Color(0xFFFFD54F),
  selectionWidth: 4,
  focusVeilColor: Color(0xFF6D4C41),
  focusVeilOpacity: 0.35,
  canvasBackground: Color(0xFF263238),
  serviceBarHeight: 60,
);

/// A second full theme, every field different from [fullA]'s and today's.
const PlanTheme fullB = PlanTheme(
  statusCaptionStyle: TextStyle(
      fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF7CB342)),
  statusFillOpacity: 0.8,
  unitColourOpacity: 0.6,
  groupFrameColor: Color(0xFF8E24AA),
  groupFrameWidth: 1.5,
  groupFrameMargin: 220,
  groupChipColor: Color(0xFFF4511E),
  groupChipTextStyle: TextStyle(
      fontSize: 10, fontWeight: FontWeight.w300, color: Color(0xFF00ACC1)),
  groupChipRadius: 2.5,
  groupChipPadding: EdgeInsets.fromLTRB(1, 6, 2, 5),
  selectionOnLight: Color(0xFF5E35B1),
  selectionOnDark: Color(0xFFC0CA33),
  selectionWidth: 2.5,
  focusVeilColor: Color(0xFF546E7A),
  focusVeilOpacity: 0.15,
  canvasBackground: Color(0xFFEFEBE9),
  serviceBarHeight: 52,
);

/// One field of the theme: its name, its read, its `copyWith`, and the
/// per-type interpolation `lerp` must apply when both sides are set.
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

/// A style's lerp (R-2, R-3): an equal style is itself; a `color` null on
/// exactly one side (the automatic ink) switches the whole style at 0.5;
/// else [TextStyle.lerp] (whose `fontSize` the theme clamps between its
/// ends, a no-op for `t` in [0, 1]).
Object? _style(Object a, Object b, double t) {
  final (x, y) = (a as TextStyle, b as TextStyle);
  if (x == y) return x;
  if ((x.color == null) != (y.color == null)) return t < 0.5 ? x : y;
  return TextStyle.lerp(x, y, t);
}

Object? _insets(Object a, Object b, double t) =>
    EdgeInsets.lerp(a as EdgeInsets, b as EdgeInsets, t);

/// The seventeen fields, in declaration order.
final List<Field> fields = [
  (
    name: 'statusCaptionStyle',
    get: (t) => t.statusCaptionStyle,
    set: (t, v) => t.copyWith(statusCaptionStyle: v as TextStyle),
    lerp: _style,
  ),
  (
    name: 'statusFillOpacity',
    get: (t) => t.statusFillOpacity,
    set: (t, v) => t.copyWith(statusFillOpacity: v as double),
    lerp: _double,
  ),
  (
    name: 'unitColourOpacity',
    get: (t) => t.unitColourOpacity,
    set: (t, v) => t.copyWith(unitColourOpacity: v as double),
    lerp: _double,
  ),
  (
    name: 'groupFrameColor',
    get: (t) => t.groupFrameColor,
    set: (t, v) => t.copyWith(groupFrameColor: v as Color),
    lerp: _color,
  ),
  (
    name: 'groupFrameWidth',
    get: (t) => t.groupFrameWidth,
    set: (t, v) => t.copyWith(groupFrameWidth: v as double),
    lerp: _double,
  ),
  (
    name: 'groupFrameMargin',
    get: (t) => t.groupFrameMargin,
    set: (t, v) => t.copyWith(groupFrameMargin: v as double),
    lerp: _double,
  ),
  (
    name: 'groupChipColor',
    get: (t) => t.groupChipColor,
    set: (t, v) => t.copyWith(groupChipColor: v as Color),
    lerp: _color,
  ),
  (
    name: 'groupChipTextStyle',
    get: (t) => t.groupChipTextStyle,
    set: (t, v) => t.copyWith(groupChipTextStyle: v as TextStyle),
    lerp: _style,
  ),
  (
    name: 'groupChipRadius',
    get: (t) => t.groupChipRadius,
    set: (t, v) => t.copyWith(groupChipRadius: v as double),
    lerp: _double,
  ),
  (
    name: 'groupChipPadding',
    get: (t) => t.groupChipPadding,
    set: (t, v) => t.copyWith(groupChipPadding: v as EdgeInsets),
    lerp: _insets,
  ),
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
    name: 'focusVeilColor',
    get: (t) => t.focusVeilColor,
    set: (t, v) => t.copyWith(focusVeilColor: v as Color),
    lerp: _color,
  ),
  (
    name: 'focusVeilOpacity',
    get: (t) => t.focusVeilOpacity,
    set: (t, v) => t.copyWith(focusVeilOpacity: v as double),
    lerp: _double,
  ),
  (
    name: 'canvasBackground',
    get: (t) => t.canvasBackground,
    set: (t, v) => t.copyWith(canvasBackground: v as Color),
    lerp: _color,
  ),
  (
    name: 'serviceBarHeight',
    get: (t) => t.serviceBarHeight,
    set: (t, v) => t.copyWith(serviceBarHeight: v as double),
    lerp: _double,
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

/// A valid theme with its doubles at or near the edges of their ranges
/// (S-5), the styles' colours set: an overshoot past [edgeB] or back past
/// it leaves the range unless `lerp` clamps (R-1).
const PlanTheme edgeA = PlanTheme(
  statusCaptionStyle: TextStyle(fontSize: 1, color: Color(0xFF7CB342)),
  statusFillOpacity: 0.8,
  unitColourOpacity: 0,
  groupFrameWidth: 0.5,
  groupFrameMargin: 0,
  groupChipTextStyle: TextStyle(fontSize: 16, color: Color(0xFF00ACC1)),
  groupChipRadius: 0,
  groupChipPadding: EdgeInsets.zero,
  selectionWidth: 3,
  focusVeilOpacity: 0,
  serviceBarHeight: 1,
);

/// [edgeA]'s partner: every double and each padding side different.
const PlanTheme edgeB = PlanTheme(
  statusCaptionStyle: TextStyle(fontSize: 14, color: Color(0xFFD81B60)),
  statusFillOpacity: 1,
  unitColourOpacity: 0.6,
  groupFrameWidth: 3,
  groupFrameMargin: 150,
  groupChipTextStyle: TextStyle(fontSize: 0.5, color: Color(0xFF3949AB)),
  groupChipRadius: 4,
  groupChipPadding: EdgeInsets.fromLTRB(7, 3, 9, 4),
  selectionWidth: 0.5,
  focusVeilOpacity: 0.3,
  serviceBarHeight: 60,
);

/// Every double of [l] (each double field, each padding side, each
/// style's `fontSize`) lies between its values in [a] and [b] (R-1).
void expectWithinEnds(PlanTheme l, PlanTheme a, PlanTheme b, String reason) {
  void within(double? v, double? x, double? y, String name) {
    if (x == null || y == null) return;
    expect(v, isNotNull, reason: '$reason: $name');
    expect(v, inInclusiveRange(x < y ? x : y, x < y ? y : x),
        reason: '$reason: $name');
  }

  for (final f in fields) {
    switch ((f.get(l), f.get(a), f.get(b))) {
      case (final double? v, final double x, final double y):
        within(v, x, y, f.name);
      case (final EdgeInsets? v, final EdgeInsets x, final EdgeInsets y):
        within(v?.left, x.left, y.left, '${f.name}.left');
        within(v?.top, x.top, y.top, '${f.name}.top');
        within(v?.right, x.right, y.right, '${f.name}.right');
        within(v?.bottom, x.bottom, y.bottom, '${f.name}.bottom');
      case (final TextStyle? v, final TextStyle x, final TextStyle y):
        within(v?.fontSize, x.fontSize, y.fontSize, '${f.name}.fontSize');
    }
  }
}

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

  test('TH0 the field table names the seventeen fields of a full theme', () {
    expect(fields, hasLength(17));
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
        'TH1 a view setting one field over an ambient setting all '
        'seventeen: that field the view\'s, the sixteen others the '
        'ambient\'s', () {
      // M-TH1: `merge` taking `this.canvasBackground ?? other...` (the
      // ambient over the view) goes red for canvasBackground; M-TH-merge:
      // `unitColourOpacity: unitColourOpacity` (the view's dropped) goes
      // red for unitColourOpacity.
      for (final f in fields) {
        final merged = fullB.merge(only(f, fullA));
        for (final g in fields) {
          final Object? want;
          if (!identical(g, f)) {
            want = g.get(fullB);
          } else if (g.get(fullA) case final TextStyle style) {
            // S-3: the view's style over the ambient's, property by
            // property.
            want = (g.get(fullB)! as TextStyle).merge(style);
          } else {
            want = g.get(fullA);
          }
          expect(g.get(merged), want, reason: '${f.name} set: ${g.name}');
        }
      }
    });

    test('TH2 a null view is the ambient itself; an empty view keeps it', () {
      expect(identical(fullA.merge(null), fullA), isTrue);
      expect(fullA.merge(const PlanTheme()), fullA);
      expect(const PlanTheme().merge(fullA), fullA);
    });

    test(
        'TH19 T1-a: the text styles merge property by property: an ambient size '
        'and a view weight give both', () {
      const ambient = PlanTheme(
          statusCaptionStyle: TextStyle(fontSize: 14),
          groupChipTextStyle:
              TextStyle(fontSize: 13, color: Color(0xFF3949AB)));
      const view = PlanTheme(
          statusCaptionStyle: TextStyle(fontWeight: FontWeight.bold),
          groupChipTextStyle: TextStyle(fontStyle: FontStyle.italic));
      final m = ambient.merge(view);
      expect(m.statusCaptionStyle!.fontSize, 14);
      expect(m.statusCaptionStyle!.fontWeight, FontWeight.bold);
      expect(m.groupChipTextStyle!.fontSize, 13);
      expect(m.groupChipTextStyle!.color, const Color(0xFF3949AB));
      expect(m.groupChipTextStyle!.fontStyle, FontStyle.italic);
      // The view's property wins where both set it.
      expect(
          ambient
              .merge(
                  const PlanTheme(statusCaptionStyle: TextStyle(fontSize: 9)))
              .statusCaptionStyle!
              .fontSize,
          9);
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
        'TH4 R-1: two valid themes at t -0.2 and 1.2, both ways: every '
        'double, padding side and font size within its ends, the theme '
        'valid', () {
      // M-TH4: `_lerpBetween` returning `lerpDouble(a, b, t)!` unclamped;
      // M-TH4b: `_lerpInsets` returning `EdgeInsets.lerp(a, b, t)!`
      // unclamped goes red on the padding.
      for (final t in [-0.2, 1.2]) {
        for (final (a, b) in [(edgeA, edgeB), (edgeB, edgeA)]) {
          final l = a.lerp(b, t);
          final reason = '${a == edgeA ? 'A to B' : 'B to A'} at $t';
          expect(l.selectionWidth, inInclusiveRange(0.5, 3.0), reason: reason);
          expectWithinEnds(l, a, b, reason);
          expect(() => validatePlanTheme(l), returnsNormally, reason: reason);
        }
      }
      expect(edgeA.lerp(edgeB, 1.2).selectionWidth, 0.5);
      expect(edgeB.lerp(edgeA, 1.2).selectionWidth, 3.0);
      // An overshoot stops at the end it passes.
      expect(edgeA.lerp(edgeB, 1.2).statusFillOpacity, 1.0);
      expect(edgeB.lerp(edgeA, 1.2).unitColourOpacity, 0.0);
      expect(edgeB.lerp(edgeA, 1.2).groupChipPadding, EdgeInsets.zero);
      expect(edgeA.lerp(edgeB, -0.2).statusCaptionStyle!.fontSize, 1.0);
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
        'TH20 R-3: a style whose colour is null on exactly one side switches '
        'whole at 0.5, never fading from transparent; with a colour on both '
        'sides or neither it lerps', () {
      const ink = TextStyle(fontSize: 14);
      const white = TextStyle(fontSize: 14, color: Color(0xFFFFFFFF));
      const red = TextStyle(fontSize: 10, color: Color(0xFFFF0000));
      for (final f in fields.where((f) => f.get(fullA) is TextStyle)) {
        PlanTheme only(TextStyle s) => f.set(const PlanTheme(), s);
        TextStyle at(TextStyle a, TextStyle b, double t) =>
            f.get(only(a).lerp(only(b), t))! as TextStyle;
        for (final t in [0.1, 0.25, 0.49]) {
          expect(at(ink, white, t), ink, reason: '${f.name} at $t');
          expect(at(ink, white, t).color, isNull, reason: '${f.name} at $t');
          expect(at(white, ink, t), white, reason: '${f.name} at $t');
        }
        for (final t in [0.5, 0.75, 0.9]) {
          expect(at(ink, white, t), white, reason: '${f.name} at $t');
          expect(at(ink, white, t).color!.a, 1.0, reason: '${f.name} at $t');
          expect(at(white, ink, t), ink, reason: '${f.name} at $t');
        }
        // A colour on both sides: interpolated, size too.
        expect(
            at(red, white, 0.5).color, Color.lerp(red.color, white.color, 0.5));
        expect(at(red, white, 0.5).fontSize, 12);
        // Neither: the size interpolated.
        expect(at(ink, const TextStyle(fontSize: 10), 0.5).fontSize, 12);
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
      expect(
          const PlanTheme(
                  groupFrameMargin: 300,
                  groupChipPadding: EdgeInsets.fromLTRB(7, 3, 9, 4))
              .toString(),
          'PlanTheme(groupFrameMargin: 300.0, groupChipPadding: '
          'EdgeInsets(7.0, 3.0, 9.0, 4.0))');
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

    testWidgets(
        'TH21 opacities, widths, the bar, the margin, radius, padding and '
        'font sizes: accepted and refused, naming the field; an ambient '
        'theme out of range is refused the same way', (tester) async {
      // M-TH-valid: `validatePlanTheme` without its
      // `opacity(theme.unitColourOpacity, ...)` call accepts the refused
      // unit colour opacities.
      Future<Object?> pumpWith({PlanTheme? view, PlanTheme? ambient}) async {
        await tester.pumpWidget(scopeApp(
            key: UniqueKey(),
            view: view,
            theme: ambient == null ? lightTheme : lightWith(ambient)));
        return tester.takeException();
      }

      final accepted = <(String, PlanTheme)>[
        for (final v in [0.0, 1.0, 0.35]) ...[
          ('statusFillOpacity', PlanTheme(statusFillOpacity: v)),
          ('unitColourOpacity', PlanTheme(unitColourOpacity: v)),
          ('focusVeilOpacity', PlanTheme(focusVeilOpacity: v)),
        ],
        ('selectionWidth', const PlanTheme(selectionWidth: 0.5)),
        ('groupFrameWidth', const PlanTheme(groupFrameWidth: 0.5)),
        ('serviceBarHeight', const PlanTheme(serviceBarHeight: 0.5)),
        ('groupFrameMargin', const PlanTheme(groupFrameMargin: 0)),
        ('groupChipRadius', const PlanTheme(groupChipRadius: 0)),
        (
          'groupChipPadding',
          const PlanTheme(groupChipPadding: EdgeInsets.zero)
        ),
        (
          'statusCaptionStyle',
          const PlanTheme(statusCaptionStyle: TextStyle(fontSize: 0.5))
        ),
        (
          'groupChipTextStyle',
          const PlanTheme(groupChipTextStyle: TextStyle(fontSize: 0.5))
        ),
        ('all', fullA),
      ];
      final refused = <(String, PlanTheme)>[
        for (final v in [-0.01, 1.01, double.nan, double.infinity]) ...[
          ('statusFillOpacity', PlanTheme(statusFillOpacity: v)),
          ('unitColourOpacity', PlanTheme(unitColourOpacity: v)),
          ('focusVeilOpacity', PlanTheme(focusVeilOpacity: v)),
        ],
        for (final v in [0.0, -1.0, double.infinity, double.nan]) ...[
          ('selectionWidth', PlanTheme(selectionWidth: v)),
          ('groupFrameWidth', PlanTheme(groupFrameWidth: v)),
          ('serviceBarHeight', PlanTheme(serviceBarHeight: v)),
          (
            'statusCaptionStyle',
            PlanTheme(statusCaptionStyle: TextStyle(fontSize: v))
          ),
          (
            'groupChipTextStyle',
            PlanTheme(groupChipTextStyle: TextStyle(fontSize: v))
          ),
        ],
        for (final v in [-1.0, double.infinity, double.nan]) ...[
          ('groupFrameMargin', PlanTheme(groupFrameMargin: v)),
          ('groupChipRadius', PlanTheme(groupChipRadius: v)),
          (
            'groupChipPadding',
            PlanTheme(groupChipPadding: EdgeInsets.fromLTRB(v, 0, 0, 0))
          ),
          (
            'groupChipPadding',
            PlanTheme(groupChipPadding: EdgeInsets.fromLTRB(0, v, 0, 0))
          ),
          (
            'groupChipPadding',
            PlanTheme(groupChipPadding: EdgeInsets.fromLTRB(0, 0, v, 0))
          ),
          (
            'groupChipPadding',
            PlanTheme(groupChipPadding: EdgeInsets.fromLTRB(0, 0, 0, v))
          ),
        ],
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
      // The constructor itself never throws: each refused theme was built.
      expect(refused, hasLength(4 * 3 + 4 * 5 + 3 * 6));
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
