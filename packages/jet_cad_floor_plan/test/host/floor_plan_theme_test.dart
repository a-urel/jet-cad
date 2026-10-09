// Host embedding API spec, Slice 3, T-1 and T-2 (plan Task 1):
// `FloorPlanTheme`, its value semantics, `copyWith`, `merge` and `lerp`, and
// its resolution below `FloorPlanView` (S-11): the ambient extension with
// the view's set fields over it, validated (S-5), provided to both modes
// by an inherited widget compared by `==` (T-3), so a theme change rebuilds
// no host overlay (G-5). Nothing is drawn from it yet (Tasks 2 and 3).
//
// The themes are not the default shape: colours that are no palette's and
// no other theme's, widths and sizes that are not today's, an asymmetric
// padding, opacities that are not 0, 1 or 0.6; the plan is the embedding
// fixture (tables turned, mirrored and scaled 40 m off the origin) under
// its panned camera.
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart' as host;
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_theme.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/host/service_view.dart';
import 'package:jet_cad_floor_plan/src/host/table_overlay.dart';
import 'package:jet_cad_floor_plan/src/planner_shell.dart';

import '../support/palette_fixture.dart' show darkTheme, lightTheme;
import 'embedding_fixture.dart';

/// A full theme, every field off today's value.
const FloorPlanTheme fullA = FloorPlanTheme(
  statusCaptionStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
  statusFillOpacity: 0.5,
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
const FloorPlanTheme fullB = FloorPlanTheme(
  statusCaptionStyle: TextStyle(
      fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF7CB342)),
  statusFillOpacity: 0.8,
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
  Object? Function(FloorPlanTheme t) get,
  FloorPlanTheme Function(FloorPlanTheme t, Object v) set,
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

/// The sixteen fields, in declaration order.
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

/// A theme with [field] alone set, to [source]'s value.
FloorPlanTheme only(Field field, FloorPlanTheme source) =>
    field.set(const FloorPlanTheme(), field.get(source)!);

/// [a] equals [b], a double within 1e-12.
void expectField(Object? a, Object? b, String reason) {
  if (a is double && b is double) {
    expect(a, closeTo(b, 1e-12), reason: reason);
  } else {
    expect(a, b, reason: reason);
  }
}

/// A controller over the embedding fixture (a page around its tables) in
/// [mode].
FloorPlanController controllerIn(FloorPlanMode mode) {
  final c = FloorPlanController(json: embeddingPlanJson());
  addTearDown(c.dispose);
  c.setMode(mode);
  return c;
}

/// The resolved theme as an element under [mode]'s view reads it.
FloorPlanTheme? resolvedIn(WidgetTester tester, FloorPlanMode mode) =>
    FloorPlanThemeScope.of(tester.element(find
        .byType(mode == FloorPlanMode.selection ? ServiceView : PlannerShell)));

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

ThemeData lightWith(FloorPlanTheme t) => lightTheme.copyWith(extensions: [t]);
ThemeData darkWith(FloorPlanTheme t) => darkTheme.copyWith(extensions: [t]);

/// A valid theme with its doubles at or near the edges of their ranges
/// (S-5), the styles' colours set: an overshoot past [edgeB] or back past
/// it leaves the range unless `lerp` clamps (R-1).
const FloorPlanTheme edgeA = FloorPlanTheme(
  statusCaptionStyle: TextStyle(fontSize: 1, color: Color(0xFF7CB342)),
  statusFillOpacity: 0.8,
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
const FloorPlanTheme edgeB = FloorPlanTheme(
  statusCaptionStyle: TextStyle(fontSize: 14, color: Color(0xFFD81B60)),
  statusFillOpacity: 1,
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
void expectWithinEnds(
    FloorPlanTheme l, FloorPlanTheme a, FloorPlanTheme b, String reason) {
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

/// A host widget that depends on the resolved theme: it counts its
/// dependency changes and its builds.
class ThemeReader extends StatefulWidget {
  const ThemeReader({super.key, required this.log});

  final List<FloorPlanTheme?> log;

  @override
  State<ThemeReader> createState() => _ThemeReaderState();
}

class _ThemeReaderState extends State<ThemeReader> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.log.add(FloorPlanThemeScope.of(context));
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}

void main() {
  test('the field table names the sixteen fields of a full theme', () {
    expect(fields, hasLength(16));
    for (final f in fields) {
      expect(f.get(fullA), isNotNull, reason: f.name);
      expect(f.get(fullB), isNotNull, reason: f.name);
      expect(f.get(fullA) == f.get(fullB), isFalse, reason: f.name);
      expect(f.get(const FloorPlanTheme()), isNull, reason: f.name);
      expect(fullA.toString(), contains('${f.name}: '), reason: f.name);
    }
  });

  group('merge (T-2, S-3)', () {
    test(
        'a view setting one field over an ambient setting all sixteen: that '
        'field the view\'s, the fifteen others the ambient\'s', () {
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

    test('a null view is the ambient itself; an empty view keeps it', () {
      expect(identical(fullA.merge(null), fullA), isTrue);
      expect(fullA.merge(const FloorPlanTheme()), fullA);
      expect(const FloorPlanTheme().merge(fullA), fullA);
    });

    test(
        'T1-a: the text styles merge property by property: an ambient size '
        'and a view weight give both', () {
      const ambient = FloorPlanTheme(
          statusCaptionStyle: TextStyle(fontSize: 14),
          groupChipTextStyle:
              TextStyle(fontSize: 13, color: Color(0xFF3949AB)));
      const view = FloorPlanTheme(
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
              .merge(const FloorPlanTheme(
                  statusCaptionStyle: TextStyle(fontSize: 9)))
              .statusCaptionStyle!
              .fontSize,
          9);
    });
  });

  group('lerp (S-4)', () {
    test('two full themes at 0, 0.25, 0.5 and 1: each field its type\'s lerp',
        () {
      for (final t in [0.0, 0.25, 0.5, 1.0]) {
        final l = fullA.lerp(fullB, t);
        for (final f in fields) {
          expectField(f.get(l), f.lerp(f.get(fullA)!, f.get(fullB)!, t),
              '${f.name} at $t');
        }
      }
      // Every field is its end at 0 and 1; the styles too, as each has a
      // colour on one side only and switches whole (R-3).
      for (final f in fields) {
        expect(f.get(fullA.lerp(fullB, 0)), f.get(fullA), reason: f.name);
        expect(f.get(fullA.lerp(fullB, 1)), f.get(fullB), reason: f.name);
      }
      expect(fullA.lerp(fullB, 0.25) == fullA, isFalse);
    });

    test(
        'R-1: two valid themes at t -0.2 and 1.2, both ways: every double, '
        'padding side and font size within its ends, the theme valid', () {
      for (final t in [-0.2, 1.2]) {
        for (final (a, b) in [(edgeA, edgeB), (edgeB, edgeA)]) {
          final l = a.lerp(b, t);
          final reason = '${a == edgeA ? 'A to B' : 'B to A'} at $t';
          expectWithinEnds(l, a, b, reason);
          expect(() => validateFloorPlanTheme(l), returnsNormally,
              reason: reason);
        }
      }
      // An overshoot stops at the end it passes.
      expect(edgeA.lerp(edgeB, 1.2).statusFillOpacity, 1.0);
      expect(edgeB.lerp(edgeA, 1.2).groupChipPadding, EdgeInsets.zero);
      expect(edgeA.lerp(edgeB, -0.2).statusCaptionStyle!.fontSize, 1.0);
    });

    test(
        'R-2: a theme lerped with an equal one is that theme at every t '
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
        'R-3: a style whose colour is null on exactly one side switches '
        'whole at 0.5, never fading from transparent; with a colour on both '
        'sides or neither it lerps', () {
      const ink = TextStyle(fontSize: 14);
      const white = TextStyle(fontSize: 14, color: Color(0xFFFFFFFF));
      const red = TextStyle(fontSize: 10, color: Color(0xFFFF0000));
      for (final f in fields.where((f) => f.get(fullA) is TextStyle)) {
        FloorPlanTheme only(TextStyle s) => f.set(const FloorPlanTheme(), s);
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
        'T1-b: a field null on one side switches at 0.5 and never fades '
        '(no groupFrameColor to 0xFF00897B: null at 0.25, opaque at 0.75)', () {
      const to = FloorPlanTheme(groupFrameColor: Color(0xFF00897B));
      expect(const FloorPlanTheme().lerp(to, 0.25).groupFrameColor, isNull);
      final at75 = const FloorPlanTheme().lerp(to, 0.75).groupFrameColor!;
      expect(at75, const Color(0xFF00897B));
      expect(at75.a, 1.0);
      for (final t in [0.0, 0.25, 0.49]) {
        expect(const FloorPlanTheme().lerp(fullB, t), const FloorPlanTheme(),
            reason: 'at $t');
        expect(fullA.lerp(const FloorPlanTheme(), t), fullA, reason: 'at $t');
      }
      for (final t in [0.5, 0.75, 1.0]) {
        expect(const FloorPlanTheme().lerp(fullB, t), fullB, reason: 'at $t');
        expect(fullA.lerp(const FloorPlanTheme(), t), const FloorPlanTheme(),
            reason: 'at $t');
      }
    });

    test('lerp(null, t) is the theme itself', () {
      for (final t in [0.0, 0.3, 1.0]) {
        expect(identical(fullA.lerp(null, t), fullA), isTrue);
      }
    });

    test(
        'through ThemeData.lerp: a light ThemeData with the extension and a '
        'dark one without carry the first\'s unchanged; both with it, '
        'lerped', () {
      for (final t in [0.25, 0.75]) {
        expect(
            identical(
                ThemeData.lerp(lightWith(fullA), darkTheme, t)
                    .extension<FloorPlanTheme>(),
                fullA),
            isTrue,
            reason: 'at $t');
        expect(
            ThemeData.lerp(lightWith(fullA), darkWith(fullB), t)
                .extension<FloorPlanTheme>(),
            fullA.lerp(fullB, t),
            reason: 'at $t');
      }
    });
  });

  group('copyWith, ==, hashCode, toString', () {
    test('each field changed alone makes != and a different hash', () {
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
        // From empty: one field set is not the empty theme.
        expect(only(f, fullA) == const FloorPlanTheme(), isFalse,
            reason: f.name);
        expect(
            only(f, fullA).hashCode == const FloorPlanTheme().hashCode, isFalse,
            reason: f.name);
      }
    });

    test('toString names the set fields only', () {
      expect(const FloorPlanTheme().toString(), 'FloorPlanTheme()');
      expect(const FloorPlanTheme(selectionWidth: 4).toString(),
          'FloorPlanTheme(selectionWidth: 4.0)');
      expect(
          const FloorPlanTheme(
                  groupFrameMargin: 300,
                  groupChipPadding: EdgeInsets.fromLTRB(7, 3, 9, 4))
              .toString(),
          'FloorPlanTheme(groupFrameMargin: 300.0, groupChipPadding: '
          'EdgeInsets(7.0, 3.0, 9.0, 4.0))');
      expect(fullA.type, FloorPlanTheme);
    });
  });

  group('validation (S-5), through the view', () {
    testWidgets(
        'opacities, widths, the bar, the margin, radius, padding and font '
        'sizes: accepted and refused, naming the field; an ambient theme '
        'out of range is refused the same way', (tester) async {
      final c = controllerIn(FloorPlanMode.selection);
      Future<Object?> pumpWith(
          {FloorPlanTheme? view, FloorPlanTheme? ambient}) async {
        await pumpUnder(tester, FloorPlanView(controller: c, theme: view),
            theme: ambient == null ? lightTheme : lightWith(ambient));
        return tester.takeException();
      }

      final accepted = <(String, FloorPlanTheme)>[
        for (final v in [0.0, 1.0, 0.35]) ...[
          ('statusFillOpacity', FloorPlanTheme(statusFillOpacity: v)),
          ('focusVeilOpacity', FloorPlanTheme(focusVeilOpacity: v)),
        ],
        ('selectionWidth', const FloorPlanTheme(selectionWidth: 0.5)),
        ('groupFrameWidth', const FloorPlanTheme(groupFrameWidth: 0.5)),
        ('serviceBarHeight', const FloorPlanTheme(serviceBarHeight: 0.5)),
        ('groupFrameMargin', const FloorPlanTheme(groupFrameMargin: 0)),
        ('groupChipRadius', const FloorPlanTheme(groupChipRadius: 0)),
        (
          'groupChipPadding',
          const FloorPlanTheme(groupChipPadding: EdgeInsets.zero)
        ),
        (
          'statusCaptionStyle',
          const FloorPlanTheme(statusCaptionStyle: TextStyle(fontSize: 0.5))
        ),
        (
          'groupChipTextStyle',
          const FloorPlanTheme(groupChipTextStyle: TextStyle(fontSize: 0.5))
        ),
        ('all', fullA),
      ];
      final refused = <(String, FloorPlanTheme)>[
        for (final v in [-0.01, 1.01, double.nan, double.infinity]) ...[
          ('statusFillOpacity', FloorPlanTheme(statusFillOpacity: v)),
          ('focusVeilOpacity', FloorPlanTheme(focusVeilOpacity: v)),
        ],
        for (final v in [0.0, -1.0, double.infinity, double.nan]) ...[
          ('selectionWidth', FloorPlanTheme(selectionWidth: v)),
          ('groupFrameWidth', FloorPlanTheme(groupFrameWidth: v)),
          ('serviceBarHeight', FloorPlanTheme(serviceBarHeight: v)),
          (
            'statusCaptionStyle',
            FloorPlanTheme(statusCaptionStyle: TextStyle(fontSize: v))
          ),
          (
            'groupChipTextStyle',
            FloorPlanTheme(groupChipTextStyle: TextStyle(fontSize: v))
          ),
        ],
        for (final v in [-1.0, double.infinity, double.nan]) ...[
          ('groupFrameMargin', FloorPlanTheme(groupFrameMargin: v)),
          ('groupChipRadius', FloorPlanTheme(groupChipRadius: v)),
          (
            'groupChipPadding',
            FloorPlanTheme(groupChipPadding: EdgeInsets.fromLTRB(v, 0, 0, 0))
          ),
          (
            'groupChipPadding',
            FloorPlanTheme(groupChipPadding: EdgeInsets.fromLTRB(0, v, 0, 0))
          ),
          (
            'groupChipPadding',
            FloorPlanTheme(groupChipPadding: EdgeInsets.fromLTRB(0, 0, v, 0))
          ),
          (
            'groupChipPadding',
            FloorPlanTheme(groupChipPadding: EdgeInsets.fromLTRB(0, 0, 0, v))
          ),
        ],
      ];
      for (final (name, theme) in accepted) {
        expect(await pumpWith(view: theme), isNull, reason: '$name: $theme');
        expect(find.byType(ServiceView), findsOneWidget,
            reason: '$name: $theme');
        expect(resolvedIn(tester, FloorPlanMode.selection), theme);
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
      expect(refused, hasLength(4 * 2 + 4 * 5 + 3 * 6));
    });
  });

  group('resolution (T-2, S-11), in both modes', () {
    for (final mode in FloorPlanMode.values) {
      testWidgets(
          'P-6 (${mode.name}): no theme anywhere resolves to null; ambient '
          'only is the ambient itself; view only the view itself',
          (tester) async {
        final c = controllerIn(mode);
        await pumpUnder(tester, FloorPlanView(controller: c));
        expect(resolvedIn(tester, mode), isNull);

        await pumpUnder(tester, FloorPlanView(controller: c),
            theme: lightWith(fullA));
        expect(identical(resolvedIn(tester, mode), fullA), isTrue);

        await pumpUnder(tester, FloorPlanView(controller: c, theme: fullB));
        expect(identical(resolvedIn(tester, mode), fullB), isTrue);
      });

      testWidgets(
          'M-H30 (${mode.name}): one field in the ambient theme and another '
          'in the view\'s resolve to both; one field in both takes the '
          'view\'s', (tester) async {
        final c = controllerIn(mode);
        await pumpUnder(
            tester,
            FloorPlanView(
                controller: c,
                theme:
                    const FloorPlanTheme(selectionOnLight: Color(0xFFD81B60))),
            theme: lightWith(
                const FloorPlanTheme(groupFrameColor: Color(0xFF00897B))));
        expect(
            resolvedIn(tester, mode),
            const FloorPlanTheme(
                groupFrameColor: Color(0xFF00897B),
                selectionOnLight: Color(0xFFD81B60)));

        await pumpUnder(
            tester,
            FloorPlanView(
                controller: c, theme: const FloorPlanTheme(selectionWidth: 5)),
            theme: lightWith(const FloorPlanTheme(
                selectionWidth: 3, groupFrameColor: Color(0xFF00897B))));
        expect(
            resolvedIn(tester, mode),
            const FloorPlanTheme(
                selectionWidth: 5, groupFrameColor: Color(0xFF00897B)));
      });

      testWidgets(
          'an ambient switch (light with A to dark with B, zero animation) '
          'reaches the ${mode.name} mode after one pump', (tester) async {
        final c = controllerIn(mode);
        final view = FloorPlanView(controller: c);
        await pumpUnder(tester, view,
            theme: lightWith(fullA), dark: darkWith(fullB));
        expect(resolvedIn(tester, mode), fullA);
        await pumpUnder(tester, view,
            theme: lightWith(fullA),
            dark: darkWith(fullB),
            mode: ThemeMode.dark);
        expect(resolvedIn(tester, mode), fullB);
      });
    }

    testWidgets('a bare PlannerShell reads the ambient extension',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: lightWith(fullA),
          themeAnimationDuration: Duration.zero,
          home: const PlannerShell()));
      await tester.pump();
      expect(
          identical(resolvedIn(tester, FloorPlanMode.design), fullA), isTrue);
      await tester.pumpWidget(const MaterialApp(
          themeAnimationDuration: Duration.zero, home: PlannerShell()));
      await tester.pump();
      expect(resolvedIn(tester, FloorPlanMode.design), isNull);
    });

    testWidgets(
        'R-4: a bare PlannerShell refuses an ambient theme out of range, '
        'naming the field', (tester) async {
      for (final (bad, name) in [
        (const FloorPlanTheme(selectionWidth: -3), 'selectionWidth'),
        (
          const FloorPlanTheme(focusVeilOpacity: double.nan),
          'focusVeilOpacity'
        ),
      ]) {
        await tester.pumpWidget(MaterialApp(
            key: UniqueKey(),
            theme: lightWith(fullA.merge(bad)),
            themeAnimationDuration: Duration.zero,
            home: const PlannerShell()));
        expect(tester.takeException(),
            isA<ArgumentError>().having((e) => e.name, 'name', name),
            reason: name);
      }
      // In range: accepted.
      await tester.pumpWidget(MaterialApp(
          key: UniqueKey(),
          theme: lightWith(fullA),
          themeAnimationDuration: Duration.zero,
          home: const PlannerShell()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(resolvedIn(tester, FloorPlanMode.design), fullA);
    });
  });

  group('T1-c: the scope notifies by value', () {
    test('updateShouldNotify: false for equal themes, true for different', () {
      final a1 = fullA.copyWith();
      final a2 = fullA.copyWith();
      expect(identical(a1, a2), isFalse);
      InheritedFloorPlanTheme scope(FloorPlanTheme? t) =>
          InheritedFloorPlanTheme(theme: t, child: const SizedBox());
      expect(scope(a1).updateShouldNotify(scope(a2)), isFalse);
      expect(scope(null).updateShouldNotify(scope(null)), isFalse);
      expect(scope(fullA).updateShouldNotify(scope(fullB)), isTrue);
      expect(scope(fullA).updateShouldNotify(scope(null)), isTrue);
      expect(scope(null).updateShouldNotify(scope(fullA)), isTrue);
    });

    testWidgets(
        'a host rebuild with an equal, non-identical view theme notifies no '
        'dependent; a different one does', (tester) async {
      final c = controllerIn(FloorPlanMode.selection);
      final log = <FloorPlanTheme?>[];
      Widget? reader(BuildContext context, FloorPlanTableOverlay table) =>
          table.detail.table.number == '1' ? ThemeReader(log: log) : null;
      FloorPlanView viewWith(FloorPlanTheme theme) => FloorPlanView(
          controller: c, theme: theme, tableOverlayBuilder: reader);
      await pumpUnder(tester, viewWith(fullA.copyWith()));
      c.cameraController.value = embeddingCamera();
      await tester.pump();
      expect(find.byType(ThemeReader), findsOneWidget);
      expect(log, [fullA]);

      await pumpUnder(tester, viewWith(fullA.copyWith()));
      expect(log, [fullA], reason: 'an equal theme notifies nobody');

      await pumpUnder(tester, viewWith(fullB.copyWith()));
      expect(log, [fullA, fullB]);
    });
  });

  /// A badge per overlaid table, counting the builder's calls.
  Widget? Function(BuildContext, FloorPlanTableOverlay) counting(
          List<int> calls) =>
      (context, table) {
        calls[0]++;
        return const SizedBox(width: 20, height: 10);
      };

  const viewTheme = FloorPlanTheme(selectionWidth: 4.5);
  const other = FloorPlanTheme(selectionWidth: 5, statusFillOpacity: 0.25);

  testWidgets(
      'G-5, H-8: an ambient switch (light with A to dark with another) calls '
      'the overlay builder 0 times', (tester) async {
    final c = controllerIn(FloorPlanMode.selection);
    final calls = [0];
    // One view widget throughout: the host never rebuilds it.
    final view = FloorPlanView(
        controller: c, tableOverlayBuilder: counting(calls), theme: viewTheme);
    await pumpUnder(tester, view,
        theme: lightWith(fullA), dark: darkWith(other));
    c.cameraController.value = embeddingCamera();
    await tester.pump();
    expect(calls[0], 7, reason: 'the fixture\'s seven overlaid tables');
    expect(resolvedIn(tester, FloorPlanMode.selection), fullA.merge(viewTheme));
    await pumpUnder(tester, view,
        theme: lightWith(fullA), dark: darkWith(other), mode: ThemeMode.dark);
    expect(resolvedIn(tester, FloorPlanMode.selection), other.merge(viewTheme));
    expect(calls[0], 7, reason: 'an ambient switch builds no overlay');
  });

  testWidgets(
      'G-5, H-8: a scope-only change (the host\'s Theme around an unchanged '
      'view) calls the overlay builder 0 times; a host rebuild of the view '
      'calls it for every table', (tester) async {
    final c = controllerIn(FloorPlanMode.selection);
    final calls = [0];
    final local = ValueNotifier<ThemeData>(lightWith(fullA));
    addTearDown(local.dispose);
    Widget hostOf(FloorPlanView view) => ValueListenableBuilder<ThemeData>(
        valueListenable: local,
        builder: (context, data, child) => Theme(data: data, child: child!),
        child: view);
    final view = FloorPlanView(
        controller: c, tableOverlayBuilder: counting(calls), theme: viewTheme);
    await pumpUnder(tester, hostOf(view));
    c.cameraController.value = embeddingCamera();
    await tester.pump();
    expect(calls[0], 7);
    expect(resolvedIn(tester, FloorPlanMode.selection), fullA.merge(viewTheme));
    local.value = darkWith(other);
    await tester.pump();
    expect(resolvedIn(tester, FloorPlanMode.selection), other.merge(viewTheme));
    expect(calls[0], 7, reason: 'a scope-only change builds no overlay');

    // The counter counts: a host rebuild of the view builds every overlay
    // again (G-5).
    await pumpUnder(
        tester,
        hostOf(FloorPlanView(
            controller: c,
            tableOverlayBuilder: counting(calls),
            theme: viewTheme)));
    expect(calls[0], 14);
  });

  testWidgets(
      'R-1: an AnimatedTheme with Curves.easeOutBack between two valid '
      'themes, both ways: no exception on any frame, every value within its '
      'ends', (tester) async {
    final c = controllerIn(FloorPlanMode.selection);
    final view = FloorPlanView(controller: c);
    Widget hostOf(ThemeData data) => AnimatedTheme(
        data: data,
        curve: Curves.easeOutBack,
        duration: const Duration(milliseconds: 200),
        child: view);
    await pumpUnder(tester, hostOf(lightWith(edgeA)));
    expect(resolvedIn(tester, FloorPlanMode.selection), edgeA);
    for (final (from, to, data) in [
      (edgeA, edgeB, darkWith(edgeB)),
      (edgeB, edgeA, lightWith(edgeA)),
    ]) {
      await pumpUnder(tester, hostOf(data));
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        final reason = '${from == edgeA ? 'A to B' : 'B to A'}, frame $i';
        expect(tester.takeException(), isNull, reason: reason);
        expectWithinEnds(
            resolvedIn(tester, FloorPlanMode.selection)!, from, to, reason);
      }
      expect(resolvedIn(tester, FloorPlanMode.selection), to);
    }
  });

  testWidgets(
      'R-2: an animated switch between ThemeData carrying equal themes '
      'notifies no dependent; one carrying different themes does',
      (tester) async {
    final c = controllerIn(FloorPlanMode.selection);
    final log = <FloorPlanTheme?>[];
    Widget? reader(BuildContext context, FloorPlanTableOverlay table) =>
        table.detail.table.number == '1' ? ThemeReader(log: log) : null;
    final view = FloorPlanView(controller: c, tableOverlayBuilder: reader);
    Widget hostOf(ThemeData data) => AnimatedTheme(
        data: data, duration: const Duration(milliseconds: 200), child: view);
    await pumpUnder(tester, hostOf(lightWith(fullA)));
    c.cameraController.value = embeddingCamera();
    await tester.pump();
    expect(find.byType(ThemeReader), findsOneWidget);
    expect(log, [fullA]);

    await pumpUnder(tester, hostOf(darkWith(fullA.copyWith())));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(Theme.of(tester.element(find.byType(ServiceView))).brightness,
        Brightness.dark,
        reason: 'the switch ran');
    expect(log, [fullA], reason: 'an equal theme notifies nobody');

    // The reader counts: a different theme notifies it.
    await pumpUnder(tester, hostOf(lightWith(fullB)));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(log.length, greaterThan(1));
    expect(log.last, fullB);
  });

  testWidgets(
      'S-12: the export dialog opened from the service bar under a local '
      'Theme reads that Theme\'s ColorScheme and extension; the view\'s '
      'theme does not reach it', (tester) async {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF18181B),
      onPrimary: Color(0xFFFAFAFA),
      secondary: Color(0xFFF4F4F5),
      onSecondary: Color(0xFF18181B),
      error: Color(0xFFEF4444),
      onError: Color(0xFFFAFAFA),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF09090B),
      surfaceContainerHigh: Color(0xFFE4E4E7),
    );
    const ambient = FloorPlanTheme(groupFrameColor: Color(0xFF00897B));
    final c = controllerIn(FloorPlanMode.selection);
    await pumpUnder(
        tester,
        Theme(
            data: ThemeData(colorScheme: scheme, extensions: const [ambient]),
            child:
                FloorPlanView(controller: c, onExport: (_) {}, theme: fullB)));
    expect(resolvedIn(tester, FloorPlanMode.selection), ambient.merge(fullB));
    await tester.tap(find.byKey(const Key('service-export')));
    await tester.pump();
    await tester.pump();
    final dialog = find.byKey(const Key('export-dialog'));
    expect(dialog, findsOneWidget);
    final inDialog = tester.element(dialog);
    expect(Theme.of(inDialog).colorScheme, scheme);
    expect(
        tester
            .widget<Material>(find
                .descendant(of: dialog, matching: find.byType(Material))
                .first)
            .color,
        scheme.surfaceContainerHigh);
    expect(FloorPlanThemeScope.of(inDialog), ambient,
        reason: 'the view\'s theme is no InheritedTheme');
    await tester.tap(find.byKey(const Key('export-cancel')));
    await tester.pump();
    await tester.pump();
  });

  testWidgets(
      'FloorPlanTheme through the barrel alone: in ThemeData(extensions:) '
      'and FloorPlanView(theme:)', (tester) async {
    final c = host.FloorPlanController(json: embeddingPlanJson());
    addTearDown(c.dispose);
    c.setMode(host.FloorPlanMode.selection);
    const host.FloorPlanTheme ambient = host.FloorPlanTheme(
        statusCaptionStyle: TextStyle(fontSize: 14),
        groupChipPadding: EdgeInsets.fromLTRB(7, 3, 9, 4));
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: const [ambient]),
        home: host.FloorPlanView(
            controller: c,
            theme: const host.FloorPlanTheme(
                statusCaptionStyle: TextStyle(fontWeight: FontWeight.bold),
                selectionWidth: 3))));
    await tester.pump();
    expect(
        resolvedIn(tester, FloorPlanMode.selection),
        const host.FloorPlanTheme(
            statusCaptionStyle:
                TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            groupChipPadding: EdgeInsets.fromLTRB(7, 3, 9, 4),
            selectionWidth: 3));
  });
}
