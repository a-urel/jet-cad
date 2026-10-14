// Spec Q0 N1 (M-Q0-e): a new plan takes the separator of the language
// class, not of its language code, and a host's own class settles the
// controller's empty plan by its separator (controller ruling on NS7:
// PlanLocaleScope.push reports PlanStrings.of(context) with the locale).
// Ported from jet_cad_floor_plan's new_plan_separator_test.dart NS7a and
// NS7 (2a Task 9); the view is a widget that pushes the locale as every
// widget of the plan library does.
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/l10n/document_separator.dart';
import 'package:jet_cad_2d_plan/src/l10n/locale_scope.dart';

/// A host's own language (the final review's F-1): English words, French
/// numbers, so only the class -- not a built-in language of its locale --
/// can give `,`.
class _Fr extends PlanStringsEn {
  const _Fr();
  @override
  String get languageCode => 'fr';
  @override
  String get decimalSeparator => ',';
}

class _FrDelegate extends LocalizationsDelegate<PlanStrings> {
  const _FrDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<PlanStrings> load(Locale locale) => SynchronousFuture(const _Fr());
  @override
  bool shouldReload(_FrDelegate old) => false;
}

/// A widget of the plan library's shape: it pushes the locale from
/// didChangeDependencies.
class _Shows extends StatefulWidget {
  const _Shows({required this.controller});
  final PlanController controller;
  @override
  State<_Shows> createState() => _ShowsState();
}

class _ShowsState extends State<_Shows> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlanLocaleScope.push(context, widget.controller);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  test(
      'NS7a documentSeparatorFor reads the class\'s separator, not its '
      'language code', () {
    expect(documentSeparatorFor(const _Fr()), DecimalSeparator.comma);
    expect(documentSeparatorFor(const PlanStringsEn()), DecimalSeparator.point);
  });

  testWidgets(
      'NS7 a host\'s own language class settles the empty plan by its '
      'separator (V-5): French, which no built-in language covers, gives '
      'comma', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = PlanController(kits: const []);
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: [
          const _FrDelegate(),
          ...planLocalizationsDelegates
              .where((d) => d != PlanLocalizations.delegate),
        ],
        home: Scaffold(body: _Shows(controller: c))));
    await tester.pump();
    expect(PlanStrings.forLocale(const Locale('fr')).decimalSeparator, '.',
        reason: 'premise: the built-in language for fr would give point');
    expect(
        c.document.components
            .get<PageComponent>(c.document.rootHandle)!
            .decimalSeparator,
        DecimalSeparator.comma);
    expect(c.document.commands.undoDepth, 0);
    expect(c.dirty.value, isFalse);
  });
}
