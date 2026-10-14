// Spec P5 "Words": the widgets push the app's locale into
// controller.locale, and a kit's KitWords read it live, so a kit's words
// follow a change of language while mounted; English stands in for a
// language the kit lacks. A new plan takes the pushed language's decimal
// separator (today's rule, spec Q0 N1).
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/l10n/locale_scope.dart';

/// The services the probe tool's factory was given, per test.
PlanServices? captured;

/// A tool that does nothing: only its factory matters here.
class _IdleTool extends Tool {
  @override
  String get name => 'probe';
  @override
  ToolPhase get phase => ToolPhase.idle;
  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerExit(ToolContext ctx) {}
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;
  @override
  void cancel(ToolContext ctx) {}
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {}
}

/// A kit with one tool, English and Turkish words, no German.
PlanKit probeKit() => PlanKit(
      id: 'wkit',
      version: '1.0.0',
      tools: [
        PlanTool(
            id: 'wkit.probe',
            icon: Icons.circle_outlined,
            create: (services) {
              captured = services;
              return _IdleTool();
            }),
      ],
      names: const KitNames({
        'en': {'tool:wkit.probe': 'Probe'},
        'tr': {'tool:wkit.probe': 'Sonda'},
      }),
    );

/// A widget of the plan library's shape: it pushes the locale from
/// didChangeDependencies, as every widget of Tasks 13 and 15-20 does.
class _Pusher extends StatefulWidget {
  const _Pusher({required this.controller});
  final PlanController controller;
  @override
  State<_Pusher> createState() => _PusherState();
}

class _PusherState extends State<_Pusher> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlanLocaleScope.push(context, widget.controller);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

Widget appIn(Locale locale, PlanController c) => MaterialApp(
    locale: locale,
    supportedLocales: planSupportedLocales,
    localizationsDelegates: planLocalizationsDelegates,
    home: _Pusher(controller: c));

void main() {
  setUp(() => captured = null);

  testWidgets(
      'W-L1 the app\'s locale reaches controller.locale and a kit\'s words '
      'follow it while mounted; a language the kit lacks reads English',
      (tester) async {
    final c = PlanController(kits: [probeKit()]);
    addTearDown(c.dispose);
    c.selectTool('wkit.probe');
    expect(captured, isNotNull, reason: 'premise: the tool\'s factory ran');
    final words = captured!.words;

    await tester.pumpWidget(appIn(const Locale('tr'), c));
    // M-W-L1a: `push` writing nothing (its body removed) leaves 'en'.
    expect(c.locale.value, const Locale('tr'));
    // M-W-L1b: Task 8's services built with the locale read once
    // (`final l = locale.value; KitNamesWords(names, () => l)`) keep the
    // construction's English here.
    expect(words.word('tool:wkit.probe'), 'Sonda');
    expect(words.locale, const Locale('tr'));

    await tester.pumpWidget(appIn(const Locale('de'), c));
    expect(c.locale.value, const Locale('de'));
    expect(words.word('tool:wkit.probe'), 'Probe',
        reason: 'no German word: the English one');

    await tester.pumpWidget(appIn(const Locale('tr'), c));
    expect(words.word('tool:wkit.probe'), 'Sonda', reason: 'back again, live');
  });

  testWidgets(
      'W-L4 a change of language while mounted reaches the listeners after '
      'the build, never inside it', (tester) async {
    final c = PlanController(kits: [probeKit()]);
    addTearDown(c.dispose);
    await tester.pumpWidget(appIn(const Locale('en'), c));
    final phases = <SchedulerPhase>[];
    c.locale.addListener(
        () => phases.add(SchedulerBinding.instance.schedulerPhase));
    await tester.pumpWidget(appIn(const Locale('tr'), c));
    // M-W-L4: `push` calling `controller.reportLocale(…)` at once
    // notifies inside the frame's build (persistentCallbacks).
    expect(phases, [SchedulerPhase.postFrameCallbacks]);
    expect(c.locale.value, const Locale('tr'));
    await tester.pumpWidget(appIn(const Locale('tr'), c));
    expect(phases, hasLength(1), reason: 'an unchanged locale writes nothing');
  });

  testWidgets('W-L2 with no Localizations above, the pushed locale is English',
      (tester) async {
    final c = PlanController(kits: [probeKit()]);
    addTearDown(c.dispose);
    c.reportLocale(const Locale('tr'));
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr, child: _Pusher(controller: c)));
    // M-W-L2: `push` returning early when `maybeLocaleOf` is null keeps
    // 'tr'.
    expect(c.locale.value, const Locale('en'));
  });

  test(
      'W-L3 a new plan takes the separator of the locale\'s built-in '
      'language: a comma for German and Turkish, a point otherwise', () {
    final c = PlanController(kits: const []);
    addTearDown(c.dispose);
    DecimalSeparator separatorAfterNewPlanIn(Locale locale) {
      c.reportLocale(locale);
      c.newPlan();
      final d = c.document;
      return d.components.get<PageComponent>(d.rootHandle)!.decimalSeparator;
    }

    // M-W-L3: `documentSeparatorFor` answering `point` always turns the
    // first two red.
    expect(separatorAfterNewPlanIn(const Locale('de')), DecimalSeparator.comma);
    expect(separatorAfterNewPlanIn(const Locale('tr')), DecimalSeparator.comma);
    expect(separatorAfterNewPlanIn(const Locale('fr')), DecimalSeparator.point);
    expect(separatorAfterNewPlanIn(const Locale('en')), DecimalSeparator.point);
    // An explicit separator wins over the locale.
    c.reportLocale(const Locale('de'));
    c.newPlan(decimalSeparator: '.');
    final d = c.document;
    expect(d.components.get<PageComponent>(d.rootHandle)!.decimalSeparator,
        DecimalSeparator.point);
  });
}
