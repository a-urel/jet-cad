// Spec 3a C1.6: the words the plan gives a kit carry the UI language's
// decimal separator, live, from the PlanStrings the widgets report (a
// host's own class included); and a host may word a kit's texts.
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/test_kit.dart';

/// English words with a comma: a host's own language class (NS7's case).
final class CommaEnglish extends PlanStringsEn {
  const CommaEnglish();

  @override
  String get decimalSeparator => ',';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'KW-plan-separator a kit\'s words read the reported language\'s '
      'separator at each call: English ".", Turkish ",", a host\'s own '
      'class its own (M-KW-plan-separator)', () {
    final c = PlanController(kits: [testKit()]);
    addTearDown(c.dispose);
    final words = c.servicesOf('test').words;
    // M-KW-plan-separator: the plan builds KitNamesWords without it ('.').
    expect(words.decimalSeparator, '.');
    c.reportLocale(const Locale('tr'));
    expect(words.decimalSeparator, ',');
    c.reportLocale(const Locale('de'));
    expect(words.decimalSeparator, ',');
    c.reportLocale(const Locale('en'), strings: const CommaEnglish());
    expect(words.decimalSeparator, ',');
    c.reportLocale(const Locale('en'));
    expect(words.decimalSeparator, '.');
  });

  test(
      'KW-plan-host a host\'s text word is accepted and read before the '
      'kit\'s, in the locale (M-KW-host)', () {
    final c = PlanController(
        kits: [testKit()],
        words: const KitNames({
          'en': {'text:test.busy': 'Taken by {name}'},
          'tr': {'text:test.busy': '{name} tarafından alındı'},
        }));
    addTearDown(c.dispose);
    final words = c.servicesOf('test').words;
    expect(words.text('text:test.busy', {'name': 'Slab 1'}), 'Taken by Slab 1');
    c.reportLocale(const Locale('tr'));
    expect(words.text('text:test.busy', {'name': 'Slab 1'}),
        'Slab 1 tarafından alındı');
  });
}
