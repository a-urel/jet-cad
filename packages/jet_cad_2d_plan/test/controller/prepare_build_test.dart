// Spec 3a C1.3, C1.9 (Task 5): a kit's prepare runs on the documents the
// plan library makes (the constructor's plan without json, and newPlan),
// in kit load order, outside history, before the save point; never on a
// loaded plan (Review Focus 1, the plan's half). A host's build fills a
// new plan over the plan's own system, unrestricted, and the plan opens
// clean, still unsettled; a failing prepare or build is one hookFailed
// and the plan opens. Slabs off the origin, turned; a prepare sets the
// page to 1:100.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';
import '../support/throwing_kit.dart';

/// What a `prep` kit's prepare adds: a linetype on the handle the engine
/// keeps for an application's (`ReservedHandles.dashedLinetype`).
const LinetypeRecord prepRecord = LinetypeRecord(
  handle: ReservedHandles.dashedLinetype,
  name: 'PREPPED',
  description: 'Prepared __ __',
  pattern: DashPattern(dashes: [300, -150], totalLength: 450),
);

/// A kit with no type whose prepare adds [prepRecord] when it is not there
/// (idempotent), and logs `prep` in [log].
PlanKit prepKit({List<String>? log}) => PlanKit(
      id: 'prep',
      version: '1.0.0',
      prepare: (document) {
        log?.add('prep');
        final linetypes = document.tables.linetypes;
        if (!linetypes.contains(prepRecord.handle)) linetypes.add(prepRecord);
      },
    );

/// A kit whose prepare logs whether [prepRecord] is there already.
PlanKit lateKit(List<String> log) => PlanKit(
      id: 'late',
      version: '1.0.0',
      prepare: (document) => log
          .add('late:${document.tables.linetypes.contains(prepRecord.handle)}'),
    );

bool prepared(DraftDocument d) =>
    d.tables.linetypes[prepRecord.handle] == prepRecord;

/// A build that records its words and adds one slab, 1800 x 900, turned
/// 0.4 rad at (-2600, 1400), by command.
PlanBuild slabBuild(List<KitWords> seen) => (document, words) {
      seen.add(words);
      addObject<SlabComponent>(
          document, SlabComponent(width: 1800, height: 900, angle: 0.4),
          at: Vector2(-2600, 1400));
    };

List<(String, String?, KitDiagnosticCode)> problemsOf(PlanController c) =>
    [for (final d in c.diagnostics.value) (d.kitId, d.subject, d.code)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      "PB1 the constructor's plan and newPlan's are prepared: the record "
      'is there, nothing to undo, clean, no diagnostic', (tester) async {
    final c = PlanController(kits: [testKit(), prepKit()]);
    addTearDown(c.dispose);
    // M-PB-1: the constructor without `_prepare`.
    expect(prepared(c.document), isTrue);
    expect(c.document.commands.canUndo, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
    expect(c.diagnostics.value, isEmpty);
    final first = c.document;
    c.newPlan();
    await tester.pump();
    expect(identical(c.document, first), isFalse, reason: 'premise');
    // M-PB-2: newPlan without `_prepare`.
    expect(prepared(c.document), isTrue);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      "PB2 every kit's prepare runs once per new document, in load order",
      (tester) async {
    final log = <String>[];
    final c =
        PlanController(kits: [prepKit(log: log), testKit(), lateKit(log)]);
    addTearDown(c.dispose);
    // M-PB-3: `_prepare` over `kits.kits.reversed`: late runs first and
    // sees no record.
    expect(log, ['prep', 'late:true']);
    c.newPlan();
    await tester.pump();
    expect(log, ['prep', 'late:true', 'prep', 'late:true']);
  });

  testWidgets(
      'PB3-prepare-load a file without the record opens without it, by the '
      'constructor and by load, saves back byte for byte and stays clean; '
      "newPlan adds it (Review Focus 1, the plan's half)", (tester) async {
    final text = planText([testKit(), prepKit()], (d) {
      addObject<SlabComponent>(
          d, SlabComponent(width: 1200, height: 700, angle: -1.1),
          at: Vector2(2300, 1400));
    });
    expect(text, isNot(contains('PREPPED')), reason: 'premise: no record');
    final c = PlanController(kits: [testKit(), prepKit()], json: text);
    addTearDown(c.dispose);
    // M-PB-4: `_prepare(document)` as the first statement of `_open`, so
    // every document is prepared, a loaded one too.
    expect(prepared(c.document), isFalse);
    expect(c.document.tables.linetypes.contains(ReservedHandles.dashedLinetype),
        isFalse);
    expect(c.dirty.value, isFalse);
    expect(c.save(), text);
    c.newPlan();
    await tester.pump();
    expect(prepared(c.document), isTrue, reason: 'a new plan is prepared');
    c.load(text);
    await tester.pump();
    expect(prepared(c.document), isFalse);
    expect(c.dirty.value, isFalse);
    expect(c.save(), text);
  });

  test(
      'PB4 a prepare that throws is one hookFailed of its kit; the later '
      'kits are still prepared and the plan opens', () {
    final boom = ThrowingKit(failing: ['prepare']);
    // M-PB-5: `_prepare` calling `prepare` bare: the constructor throws
    // BoomFailure.
    final c = PlanController(kits: [boom.kit, prepKit()]);
    addTearDown(c.dispose);
    expect(problemsOf(c), [('boom', 'prepare', KitDiagnosticCode.hookFailed)]);
    expect(prepared(c.document), isTrue);
    expect(c.document.components.get<PageComponent>(c.document.rootHandle),
        isNotNull);
    expect(c.dirty.value, isFalse);
  });

  test(
      'PB5 a prepare that executes a command leaves nothing to undo: the '
      "history is cleared after the last kit's", () {
    final c = PlanController(kits: [
      PlanKit(
          id: 'scale',
          version: '1.0.0',
          prepare: (d) {
            final page = d.components.get<PageComponent>(d.rootHandle)!;
            d.commands.execute(SetComponentCommand<PageComponent>(
                d.rootHandle, page.copyWith(scaleDenominator: 100)));
          }),
    ]);
    addTearDown(c.dispose);
    final d = c.document;
    expect(
        d.components.get<PageComponent>(d.rootHandle)!.scaleDenominator, 100);
    // M-PB-6: `_prepare` without its `clearHistory()`.
    expect(d.commands.canUndo, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
  });

  test(
      "PB6 a build fills the constructor's plan over the plan's system, "
      "after the prepares, with every kit's words, the host's first: clean, "
      'nothing to undo', () {
    final seen = <KitWords>[];
    var preparedFirst = false;
    final c = PlanController(
        kits: [testKit(), prepKit()],
        words: const KitNames({
          'en': {'tool:test.slab': 'Plate'},
        }),
        build: (document, words) {
          preparedFirst = prepared(document);
          slabBuild(seen)(document, words);
        });
    addTearDown(c.dispose);
    final slab = slabsOf(c.document).single;
    // M-PB-7: `_runBuild` called as the first statement of `_open`, before
    // the session installs the system: the slab has no outline.
    expect(leavesOf(c.document, slab), hasLength(1));
    expect(preparedFirst, isTrue);
    // M-PB-8: `_runBuild` without its `clearHistory()`.
    expect(c.document.commands.canUndo, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
    expect(c.diagnostics.value, isEmpty);
    final words = seen.single;
    // M-PB-9: the build's names folded with the host's last
    // (`kits.kits.fold(KitNames.empty, ...).merge(_hostWords)`).
    expect(words.word('tool:test.slab'), 'Plate');
    expect(words.word('property:test.slab.width'), 'Width');
    expect(words.locale, const Locale('en'));
  });

  test("PB7 a build is ignored with json: the loaded plan is the file's", () {
    var built = 0;
    final text = slabPlanText();
    final c = PlanController(
        kits: [testKit()], json: text, build: (document, words) => built++);
    addTearDown(c.dispose);
    // M-PB-10: the factory passing `build` on with json.
    expect(built, 0);
    expect(c.save(), text);
  });

  testWidgets(
      'PB8 newPlan(build:) fills the new plan, clean, in the locale last '
      'reported; newPlan() without one is empty', (tester) async {
    final seen = <KitWords>[];
    final c = PlanController(kits: [testKit()]);
    addTearDown(c.dispose);
    c.reportLocale(const Locale('tr'));
    // M-PB-11: newPlan not passing `build` on to `_replace`.
    c.newPlan(build: slabBuild(seen));
    await tester.pump();
    expect(slabsOf(c.document), hasLength(1));
    expect(c.dirty.value, isFalse);
    expect(c.canUndo.value, isFalse);
    // M-PB-12: the build's words at English whatever the locale
    // (`() => const Locale('en')`).
    expect(seen.single.locale, const Locale('tr'));
    expect(seen.single.word('tool:test.slab'), 'Döşeme');
    c.newPlan();
    await tester.pump();
    expect(slabsOf(c.document), isEmpty);
  });

  test(
      'PB9 a build that throws leaves the empty plan: its steps undone, one '
      'hookFailed of the plan, clean, nothing to undo or redo', () {
    final c = PlanController(
        kits: [testKit()],
        build: (document, words) {
          slabBuild([])(document, words);
          throw StateError('the build broke');
        });
    addTearDown(c.dispose);
    final d = c.document;
    // M-PB-13: `_runBuild` without its undo loop: the slab stays.
    expect(slabsOf(d), isEmpty);
    expect(d.entities.liveCount, 0);
    expect(d.components.get<PageComponent>(d.rootHandle), isNotNull,
        reason: "the page is the new plan's, not the build's");
    // M-PB-14: `_runBuild` without its catch: the constructor throws.
    expect(problemsOf(c), [('plan', 'build', KitDiagnosticCode.hookFailed)]);
    expect(c.canUndo.value, isFalse);
    expect(c.canRedo.value, isFalse);
    expect(c.dirty.value, isFalse);
  });

  test(
      "PB10 a build is the host's construction, not an edit: it fills a "
      'read-only plan', () {
    final c = PlanController(
        kits: [testKit()],
        permissions: PlanPermissions.readOnly,
        build: slabBuild([]));
    addTearDown(c.dispose);
    // M-PB-15: `_runBuild` calling `build` without `_unrestricted`: the
    // engine refuses the slab (PermissionDeniedError), the plan is empty
    // and the build is reported.
    expect(slabsOf(c.document), hasLength(1));
    expect(c.diagnostics.value, isEmpty);
    expect(c.dirty.value, isFalse);
  });

  test(
      'PB11 a built plan made with no locale is still unsettled: the first '
      'locale reported gives it its separator, as if made so', () {
    final c = PlanController(kits: [testKit()], build: slabBuild([]));
    addTearDown(c.dispose);
    final d = c.document;
    PageComponent page() => d.components.get<PageComponent>(d.rootHandle)!;
    expect(page().decimalSeparator, DecimalSeparator.point, reason: 'premise');
    c.reportLocale(const Locale('tr'));
    // M-PB-16: the build run after the save point and the unsettled
    // baseline (its call moved from `_open` to the constructor body, after
    // `_unsettled` is set): the plan is not settled, and it is dirty.
    expect(page().decimalSeparator, DecimalSeparator.comma);
    expect(d.commands.canUndo, isFalse);
    expect(c.dirty.value, isFalse);
  });
}
