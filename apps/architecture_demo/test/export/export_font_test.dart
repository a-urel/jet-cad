// Ported from apps/floor_planner/test/export/export_font_test.dart (audit
// docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md, section
// "export/export_font_test.dart"): EF9 SPLIT, EF11, EF12 PORT, EF1, EF2,
// EF10 COVERED, EF3 DROPPED; EF4-EF8 are not 3b (ported in the plan library).
//
// COVERED, checked (each opened and read), in packages/jet_cad_2d_plan/test:
//   EF1, EF2  fonts/plan_assets_test.dart:55 (W-F1: the font and the licence
//             are the vendored ones byte for byte)
//   EF10      export/export_font_test.dart:38 (EF4, the bundled font through
//             rootBundle) and export/page_flows_test.dart:441 (PF13, the
//             controller's default fonts); the app gives the controller no
//             font, so the default is what runs (EF9-open below exports in it)
// DROPPED: EF3 -- the app owns no font copy or README; the plan package's
//   `assets/fonts/README.md` records the digest.
//
// Decided: premise impossible (the app has no font injection): EF9's "the
// app hands its cache to the host" is gone; its intent is that the font
// survives a document swap, which holds because one `PlanController` is
// kept across New and Open (the cache is the controller's).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart' show PlanExportChoice;

import '../support/app_rig.dart';
import '../support/export_rig.dart';

void main() {
  group('T-12 the app and its font', () {
    testWidgets(
        'EF9-open one PlanController is kept across New and Open, so the '
        'export font it holds survives a document swap: an export after each '
        'embeds the font', (tester) async {
      final rig = await pumpFlat(tester);
      final controller = rig.controller;

      Future<void> exportsInTheFont() async {
        final export = await tester.runAsync(() =>
            controller.export('plan.pdf', PlanExportChoice.initial, name: 'x'));
        final content = parsePdf(export!.bytes);
        expect(content.textRuns, isNotEmpty, reason: 'premise: has text');
        for (final run in content.textRuns) {
          expect(run.fontInfo.fontFile, '/FontFile2',
              reason: 'the bundled font is embedded');
        }
      }

      await exportsInTheFont();
      await rig.host.newFlow();
      await tester.pump();
      expect(rig.controller, same(controller), reason: 'after New');
      // A new plan has no labels; the sample is the plan with text.
      await rig.host.openSampleFlow();
      await tester.pump();
      expect(rig.controller, same(controller), reason: 'after Open sample');
      await exportsInTheFont();
      rig.files.scriptOpen(
          name: 'again.jetplan', bytes: sampleBytes(), location: '/p/a');
      await rig.host.openFlow();
      await tester.pump();
      expect(rig.controller, same(controller), reason: 'after Open');
      await exportsInTheFont();
    });
  });

  group('main', () {
    // No test runs `main()` (it calls `runApp`), so the lines that make the
    // font and the licence appear in the running app are pinned by source,
    // as the old app pinned them.
    String mainBody() {
      final source = File('lib/main.dart').readAsStringSync();
      final start = source.indexOf('main() async {');
      expect(start, isNonNegative, reason: 'premise: main() is found');
      final end = source.indexOf('\n}', start);
      expect(end, greaterThan(start), reason: 'premise: its body ends');
      // Comments do not run: a commented-out call is no call.
      return source
          .substring(start, end)
          .replaceAll(RegExp(r'//[^\n]*'), '')
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
    }

    test(
        'EF11 main() initialises the binding, awaits the plan font, '
        'registers the licence, then runs the app', () {
      final body = mainBody();
      final binding =
          body.indexOf('WidgetsFlutterBinding.ensureInitialized();');
      final font = body.indexOf('await ensurePlanFonts();');
      final licence = body.indexOf('registerFontLicences();');
      final run = body.indexOf('runApp(');
      expect(binding, isNonNegative, reason: 'the binding is initialised');
      expect(font, isNonNegative, reason: 'the font is registered, awaited');
      expect(licence, isNonNegative, reason: 'the licence is registered');
      expect(run, isNonNegative, reason: 'premise: main() runs the app');
      expect(binding, lessThan(font));
      expect(font, lessThan(licence));
      expect(licence, lessThan(run), reason: 'before the app runs');
    });

    test(
        'EF12 the pubspec declares the bare family Roboto from the plan '
        'package\'s font (on the web the engine fetches another Roboto when '
        'the manifest has none)', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
          RegExp(
                  r'^\s*fonts:\s*\n\s*-\s*family:\s*Roboto\s*\n\s*fonts:\s*\n'
                  r'\s*-\s*asset:\s*packages/jet_cad_2d_plan/fonts/'
                  r'Roboto-Regular\.ttf\s*$',
                  multiLine: true)
              .hasMatch(pubspec),
          isTrue);
      // The path resolves under the package's lib/.
      expect(
          File('../../packages/jet_cad_2d_plan/lib/fonts/Roboto-Regular.ttf')
              .existsSync(),
          isTrue);
    });
  });
}
