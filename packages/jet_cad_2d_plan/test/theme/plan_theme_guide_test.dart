// The guide fields of PlanTheme (alignment guides spec, "The look"): value
// semantics, validation and the palette the canvas draws with. Colours are
// no palette's; widths are not the default 1.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show PaperPalette;
import 'package:jet_cad_2d_plan/src/theme/plan_theme.dart';

const _a = Color(0xFF2E7D32);
const _b = Color(0xFF6A1B9A);
const _c = Color(0xFFEF6C00);
const _d = Color(0xFF00838F);

const int _white = 0xFFFFFFFF;
const int _blueprint = 0xFF1F3A5F;

Future<Object?> _pump(WidgetTester tester, PlanTheme view) async {
  await tester.pumpWidget(
      MaterialApp(home: PlanThemeScope(view: view, child: const SizedBox())));
  return tester.takeException();
}

void main() {
  test('copyWith(guideOnDark) keeps guideOnLight and guideWidth', () {
    const t = PlanTheme(guideOnLight: _a, guideOnDark: _b, guideWidth: 3);
    final u = t.copyWith(guideOnDark: _c);
    expect(u.guideOnDark, _c);
    expect(u.guideOnLight, _a);
    expect(u.guideWidth, 3);
  });

  test('merge keeps other\'s non-null guide fields', () {
    const base = PlanTheme(guideOnLight: _a, guideOnDark: _b, guideWidth: 3);
    const over = PlanTheme(guideOnDark: _c);
    final m = base.merge(over);
    expect(m.guideOnLight, _a);
    expect(m.guideOnDark, _c);
    expect(m.guideWidth, 3);
    final n = base.merge(const PlanTheme(guideOnLight: _d, guideWidth: 5));
    expect(n.guideOnLight, _d);
    expect(n.guideOnDark, _b);
    expect(n.guideWidth, 5);
  });

  test('lerp at 0.5 gives Color.lerp and the midway width', () {
    const x = PlanTheme(guideOnLight: _a, guideOnDark: _b, guideWidth: 2);
    const y = PlanTheme(guideOnLight: _c, guideOnDark: _d, guideWidth: 6);
    final m = x.lerp(y, 0.5);
    expect(m.guideOnLight, Color.lerp(_a, _c, 0.5));
    expect(m.guideOnDark, Color.lerp(_b, _d, 0.5));
    expect(m.guideWidth, 4);
  });

  test('== and hashCode distinguish every guide field', () {
    const base = PlanTheme(guideOnLight: _a, guideOnDark: _b, guideWidth: 1);
    expect(base,
        const PlanTheme(guideOnLight: _a, guideOnDark: _b, guideWidth: 1));
    expect(
        base.hashCode,
        const PlanTheme(guideOnLight: _a, guideOnDark: _b, guideWidth: 1)
            .hashCode);
    expect(
        base ==
            const PlanTheme(guideOnLight: _a, guideOnDark: _b, guideWidth: 2),
        isFalse);
    expect(
        base ==
            const PlanTheme(guideOnLight: _c, guideOnDark: _b, guideWidth: 1),
        isFalse);
    expect(
        base ==
            const PlanTheme(guideOnLight: _a, guideOnDark: _c, guideWidth: 1),
        isFalse);
  });

  test('toString names the set guide fields', () {
    expect(const PlanTheme(guideWidth: 2).toString(),
        'PlanTheme(guideWidth: 2.0)');
  });

  testWidgets('the scope refuses a guideWidth that is not above 0',
      (tester) async {
    for (final v in [0.0, -1.0, double.infinity, double.nan]) {
      final e = await _pump(tester, PlanTheme(guideWidth: v));
      expect(
          e, isA<ArgumentError>().having((e) => e.name, 'name', 'guideWidth'),
          reason: '$v');
    }
    expect(await _pump(tester, const PlanTheme(guideWidth: 0.5)), isNull);
  });

  test('planPaperPaletteFor gives each paper its own guide colour', () {
    const theme =
        PlanTheme(guideOnDark: _b, guideOnLight: _a, selectionOnDark: _c);
    final dark = planPaperPaletteFor(_blueprint, theme);
    expect(dark.guide, _b);
    expect(dark.selection, PaperPalette.dark.withSelection(_c).selection);
    final light = planPaperPaletteFor(_white, theme);
    expect(light.guide, _a);
    expect(light.selection, PaperPalette.light.selection);
  });

  test('a dark guide colour alone leaves the selection unchanged', () {
    final p = planPaperPaletteFor(_blueprint, const PlanTheme(guideOnDark: _b));
    expect(p.guide, _b);
    expect(p.selection, PaperPalette.dark.selection);
  });

  test('no theme, or no guide and no selection colour, is the const set', () {
    expect(identical(planPaperPaletteFor(_white, null), PaperPalette.light),
        isTrue);
    expect(identical(planPaperPaletteFor(_blueprint, null), PaperPalette.dark),
        isTrue);
    expect(
        identical(planPaperPaletteFor(_white, const PlanTheme(guideOnDark: _b)),
            PaperPalette.light),
        isTrue);
    expect(
        identical(
            planPaperPaletteFor(_blueprint, const PlanTheme(guideOnLight: _a)),
            PaperPalette.dark),
        isTrue);
  });
}
