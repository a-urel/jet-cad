### Task 5: `prepare` and `build` (spec C1.3, C1.9)

**Files:**
- Create (`packages/jet_cad_2d_kit/`): `lib/src/kit/plan_build.dart`, `test/kit/plan_build_test.dart`
- Modify (`packages/jet_cad_2d_kit/`): `lib/jet_cad_2d_kit.dart` (one export), `lib/src/kit/plan_kit.dart` (`prepare`)
- Create (`packages/jet_cad_2d_plan/`): `test/controller/prepare_build_test.dart`, `test/controller/new_plan_test.dart`
- Modify (`packages/jet_cad_2d_plan/`): `lib/src/controller/plan_controller.dart` (the factory, the private constructor, `newPlan`, `_replace`, `_open`; new `_prepare`, `_buildWords`, `_runBuild`), `lib/src/controller/new_plan.dart` (its header comment), `test/support/throwing_kit.dart` (the `prepare` hook)
- Modify: `docs/kits.md` (§10.1, §10.8), `docs/superpowers/specs/2026-10-13-kit-contract-design.md` (one line in Task 1's 3a section), `docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md` (two lines in Task 2's `## Amendments` section)

**Interfaces:**
- Consumes:
  - Task 3: `KitNamesWords(KitNames names, Locale Function() locale, {String Function()? decimalSeparator})`, `KitWords.text`, `KitWords.decimalSeparator` (shared interfaces, "The contract"); the plan's kit words read `() => planStrings.decimalSeparator` (Task 3 Step 5).
  - Engine: `DraftDocument`, `CommandDispatcher.clearHistory`/`canUndo`/`undo`, `LinetypeRecord`, `DashPattern`, `ReservedHandles.dashedLinetype` (`document/style.dart:121`), `PageComponent`, `DraftDocumentCodec`, `sheetWorldRect` (`document/page_geometry.dart:7`), `ParametricCatalog.objectsOf`.
  - Plan library today: `PlanController` (`controller/plan_controller.dart:253-367`, `newPlan` `:692-710`, `_open` `:1481-1551`, `_replace` `:1571-1609`, `_unrestricted` `:1820-1828`, `planStrings` `:606-607`, `_hostWords` `:480`, `_diagnostics` `:546`), `newPlanDocument` (`controller/new_plan.dart:23-33`), the test harness (`planDocument`, `installSystem`, `planText`, `catalogOf`, `registerPlanComponents`, `slabPlanText`, `slabsOf`, `leavesOf`, `test/support/harness.dart`), the test kit (`testKit`, `SlabComponent`, `addObject`, `test/support/test_kit.dart`), `ThrowingKit` (`test/support/throwing_kit.dart`).
- Produces (Shared interfaces, exact):

```dart
// jet_cad_2d_kit, lib/src/kit/plan_build.dart (exported by jet_cad_2d_kit.dart)
typedef PlanBuild = void Function(DraftDocument document, KitWords words);
// jet_cad_2d_kit, lib/src/kit/plan_kit.dart: PlanKit gains
final void Function(DraftDocument document)? prepare;   // constructor: this.prepare (named, last)
// jet_cad_2d_plan, PlanController
factory PlanController({/* existing */, PlanBuild? build}); // build ignored with json
void newPlan({String? decimalSeparator, PlanBuild? build});
// build's KitWords: every loaded kit's names, host words first, the controller's locale.
```

**Appendix A rows closed:** D-28, its generic half: `jet_cad_floor_plan/test/new_document_test.dart` ND1's empty, history, millimetre and page lines, ND3's page, unit and byte lines, ND4's "with the page's registration alone" and "with the catalog's registration alone" (ported here, `test/controller/new_plan_test.dart`). D-28's other parts are owned elsewhere: ND1's and ND3's DASHED lines and ND4's "with registerAppComponents: a live page and live walls" need the architecture kit (Task 17, per its scope; Task 9's SC-prepare pins the record on a new plan); ND2 is not ported (plan decision below). The spec's C1.3 and C1.9 land here; Review Focus 1's plan half is PB3-prepare-load.

Plan decisions:
- **Where `prepare` runs.** In the constructor body, before `_open`, when the factory made the document (`json == null`), and in `newPlan`, between `newPlanDocument` and `_replace`. Never inside `_open`, which `load` (and so an import: `PlanPageFlows(load: load)`, `plan_controller.dart:336`) also runs: a loaded plan is never changed (spec C1.3, today's R-3). The prepares run with no parametric system installed and the engine's default permissions (`DraftDocument.empty`), then the history is cleared once after the last: "outside history" holds even for a prepare that executes a command (PB5).
- **A failing prepare.** Caught per kit; one `KitDiagnostic(kitId: <kit id>, subject: 'prepare', code: hookFailed, message: 'prepare: <error>')`; the later kits still run and the plan opens. `hookFailed` is not plan-scoped (`diagnostics_log.dart:14-20`), so `_open`'s `clearPlanScoped` keeps it; a second newPlan with the same failure is deduplicated by the log (one per kit, subject and code), as every other hook's.
- **Where `build` runs.** Inside `_open`, right after `session.runKitFactories(...)`: the session's constructor has installed the parametric system, the unit label system and the lock expander (`session.dart:100-110`), the failure boundary is wired, and the kits' factories have run; the history listener (`session.history`), the change tracker (`_tracker.attach`) and the save point come after it. So the built objects regenerate through the plan's own system, a kit hook failure inside the build goes through the boundary as any edit's, no `PlanChange` is reported for the build's steps (the tracker's baseline is the built plan; listeners hear `PlanReplaced` from `_replace` only), and the dry run (`probeLoaded`) checks the built plan. `_replace` takes `_savedState` and `_unsettled` after `_open`, so the built plan is clean and, made with no locale reported, still unsettled (PB11).
- **A build is the host's construction, not an edit.** It runs under `_unrestricted` (the engine's permissions lifted, as the controller's own settle in `reportLocale` is, `:2203`), so a read-only controller can still be built (PB10). Then `clearHistory()`.
- **A failing build leaves the empty plan.** On a throw, every step still in the history is undone (unrestricted), then the history is cleared, and one `KitDiagnostic(kitId: 'plan', subject: 'build', code: hookFailed, message: 'build: <error>')` is reported (`'plan'` is the plan library's own kit id in the log, as `damagedUnsavable`'s, `:630`). A step that a mid-build lock cleared from the history (a kit's hook failed inside the build and the boundary froze an object) is not undone: the built objects before it stay, locked or not, and the diagnostics say why. A build adds objects by command, as the spec says; it has no other way to change the document that this undo would miss but the tables, which a build has no reason to touch.
- **The build's words.** One `KitNamesWords` for the controller's life over every loaded kit's names folded onto the host's (`_hostWords.merge(k1.names).merge(k2.names)...`: the host's word wins, then the earlier kit's, `KitNames.merge`'s rule), at `_locale` (English until a widget reports one) and with `planStrings.decimalSeparator` as its separator (Task 3's rule for the kits' words).
- **ND2 is not ported.** Its premise is `prepareDocument` (`jet_cad_floor_plan/lib/src/new_document.dart:18-24`), a set-up that adds no page; the plan library has no such step (`newPlanDocument` registers, sets millimetres and attaches the page in one function, `new_plan.dart:23-33`), so its `pageOf(doc), isNull` line has nothing to run on. Its registration and unit lines are ND1's and C1's (`plan_controller_test.dart:29-51`) over `newPlanDocument`. This is a ruling for the controller to confirm (A14: a test not ported needs a reason): "ND2 not ported, premise absent in the plan library".
- **ND4's fixture.** Today's sample flat (ten walls) is the architecture kit's; the generic cases run on two test-kit slabs off the origin, turned, under a page that is not the new plan's (origin `(-3100.5, 820.25)`, 1:100). The fixture's own count premise follows it (`hasLength(2)` slabs for `hasLength(10)` walls); `liveObjectsOf<WallParams>` becomes the test kit catalog's `objectsOf<SlabComponent>` (the engine's live-object rule both read); every other assertion is unchanged.
- **The CHANGELOGs** are written in Task 29 (Global Constraints; the gate task carries them).

- [ ] **Step 1: Precondition.** Tasks 1-4 are committed. Run `git status --short` (expected: nothing under `packages/`), `cd packages/jet_cad_2d_kit && flutter analyze` and `cd packages/jet_cad_2d_plan && flutter analyze` (each `No issues found!`). Check that Task 3's `KitNamesWords` takes `decimalSeparator:` (`grep -n "decimalSeparator" packages/jet_cad_2d_kit/lib/src/kit/plan_services.dart`); if it does not, stop and report it.

- [ ] **Step 2: The contract's failing test.** Create `packages/jet_cad_2d_kit/test/kit/plan_build_test.dart`:

```dart
// Spec 3a C1.3, C1.9 (Task 5): a kit's document preparation and a host's
// build are declared by the contract; the plan library runs them.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show DraftDocument;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

void main() {
  test(
      'PB0 PlanKit carries its prepare, null by default; PlanBuild is the '
      "contract's", () {
    // A premise of the declarations, exempt from the mutation rule: without
    // the field or the export this file does not compile.
    final calls = <DraftDocument>[];
    final void Function(DraftDocument) prepare = calls.add;
    final kit = PlanKit(id: 'sample', version: '0.1.0', prepare: prepare);
    expect(kit.prepare, same(prepare));
    expect(const PlanKit(id: 'sample', version: '0.1.0').prepare, isNull);
    expect(kit.validate(), isEmpty, reason: 'prepare needs no word');
    final PlanBuild build = (document, words) {};
    expect(build, isA<void Function(DraftDocument, KitWords)>());
  });
}
```

  Run `cd packages/jet_cad_2d_kit && flutter test test/kit/plan_build_test.dart`. Expected: compilation errors, `No named parameter with the name 'prepare'` and `Undefined name 'PlanBuild'` (or `Type 'PlanBuild' not found`).

- [ ] **Step 3: The contract.**
  1. Create `packages/jet_cad_2d_kit/lib/src/kit/plan_build.dart`:

```dart
// Spec 3a C1.9: a plan a host builds in code.
import 'package:jet_cad_2d/jet_cad_2d.dart' show DraftDocument;

import 'plan_services.dart' show KitWords;

/// Fills a new plan in code (spec 3a C1.9), given to
/// `PlanController(build:)` or `newPlan(build:)`. [document] is the plan
/// library's: set up, prepared by every loaded kit (`PlanKit.prepare`), its
/// parametric system installed. The build adds objects by command; the plan
/// library then clears the history and takes the save point, so the built
/// plan opens clean, with nothing to undo. [words] are every loaded kit's,
/// the host's first, in the controller's locale. A build that throws leaves
/// the empty plan and is reported.
typedef PlanBuild = void Function(DraftDocument document, KitWords words);
```

  2. `lib/src/kit/plan_kit.dart`: the import `import 'package:jet_cad_2d/jet_cad_2d.dart' show Component;` becomes `show Component, DraftDocument;`; the constructor gains `this.prepare,` after `this.names = KitNames.empty,`; after `final KitNames names;` add:

```dart

  /// Prepares a document the plan library makes (spec 3a C1.3): the
  /// constructor's plan without json and every `newPlan`, never a loaded or
  /// imported one, so a plan without what it adds is never changed. Called
  /// once per new document, in kit load order, before any parametric system
  /// is installed; the history is cleared after it. It must be idempotent.
  /// A throw is a `hookFailed` diagnostic and the plan opens. The
  /// separator's DASHED linetype record is its first user.
  final void Function(DraftDocument document)? prepare;
```

  3. `lib/jet_cad_2d_kit.dart`: add `export 'src/kit/plan_build.dart';` before `export 'src/kit/plan_kit.dart';`.

  Run `cd packages/jet_cad_2d_kit && dart format . && flutter test test/kit/plan_build_test.dart test/kit/plan_kit_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 4: The plan's failing tests.** Create `packages/jet_cad_2d_plan/test/controller/prepare_build_test.dart`:

```dart
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
      prepare: (document) => log.add(
          'late:${document.tables.linetypes.contains(prepRecord.handle)}'),
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
    final c = PlanController(kits: [prepKit(log: log), testKit(), lateKit(log)]);
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
    expect(
        c.document.tables.linetypes.contains(ReservedHandles.dashedLinetype),
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
    expect(d.components.get<PageComponent>(d.rootHandle)!.scaleDenominator,
        100);
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
```

  Check the non-ASCII literal: `grep -n "Döşeme" packages/jet_cad_2d_plan/test/controller/prepare_build_test.dart` shows the word, not an escape. Run `cd packages/jet_cad_2d_plan && flutter test test/controller/prepare_build_test.dart`. Expected: compilation errors (`No named parameter with the name 'build'` for `PlanController` and `newPlan`, and the throwing kit's `'prepare'` is no hook yet only at run time).

- [ ] **Step 5: The throwing kit gains `prepare`.** `packages/jet_cad_2d_plan/test/support/throwing_kit.dart`:
  - `boomHooks` gains, as its last entries (after the line Task 2 added): `// The kit's document preparation (spec 3a C1.3).` and `'prepare',`;
  - `late final PlanKit kit = PlanKit(` gains, after `version: '0.3.0',`: `prepare: (document) => check('prepare'),`.

  TK3 (`test/kits/test_kits_test.dart:31-42`) iterates `boomHooks`, so it covers the new name; F-10's expected diagnostics (`guarded_swap_test.dart:42-46`) do not name it, and `prepare` is not failing there.

- [ ] **Step 6: The plan library.** `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (the line numbers are at `c6bcce3e`; Tasks 3 and 4 add lines to this file, so find each place by the code quoted):
  1. The factory's doc gains, after the paragraph on [words]:

```dart
  ///
  /// The empty plan is prepared by every kit (`PlanKit.prepare`, spec 3a
  /// C1.3); a loaded one never is. [build] (spec 3a C1.9) then fills it
  /// over the plan's own system, and it opens clean, with nothing to undo;
  /// [build] is ignored with [json].
```

  2. The factory's parameter list gains `PlanBuild? build,` after `KitNames words = KitNames.empty,`; its `return PlanController._(...)` gains `made: json == null,` and `build: json == null ? build : null,` after `unsettled: json == null,`.
  3. The private constructor's named parameters gain `required bool made, required PlanBuild? build,` after `required bool unsettled,`. In its body, `_open(document, measurer, loadDiagnostics);` (`:360`) becomes:

```dart
    // Spec 3a C1.3: only a document the plan library made is prepared.
    if (made) _prepare(document);
    _open(document, measurer, loadDiagnostics, build: build);
```

  4. `newPlan` (`:688-710`): its doc gains `/// Every kit prepares it (spec 3a C1.3); [build] fills it (C1.9).`; its signature becomes `void newPlan({String? decimalSeparator, PlanBuild? build}) {`; its last two statements (`final measurer = FlutterTextMeasurer();` and the `_replace(newPlanDocument(...), measurer, unsettled: ...)` call, `:704-709`) become:

```dart
    final measurer = FlutterTextMeasurer();
    final made = newPlanDocument(measurer,
        register: _registerComponents, decimalSeparator: separator);
    _prepare(made);
    _replace(made, measurer,
        unsettled: given == null && reported == null, build: build);
```

  5. Right after `newPlan`, add:

```dart
  /// Every loaded kit's `prepare` on [document], a document the plan
  /// library made (spec 3a C1.3): in load order, with no system installed,
  /// then the history cleared, so the plan is prepared outside history. A
  /// prepare that throws is a `hookFailed` diagnostic of its kit (subject
  /// `prepare`); the later kits still run, and the plan opens. Never on a
  /// loaded or imported plan: Open adds nothing (today's R-3).
  void _prepare(DraftDocument document) {
    for (final kit in kits.kits) {
      final prepare = kit.prepare;
      if (prepare == null) continue;
      try {
        prepare(document);
      } catch (error) {
        _diagnostics.add(KitDiagnostic(
            kitId: kit.id,
            subject: 'prepare',
            code: KitDiagnosticCode.hookFailed,
            message: 'prepare: $error',
            error: error));
      }
    }
    document.commands.clearHistory();
  }

  /// A [PlanBuild]'s words (spec 3a C1.9): every loaded kit's, the host's
  /// first (spec 2b S4), then each kit's in load order; at the controller's
  /// locale, read live, with the UI language's separator.
  late final KitWords _buildWords = KitNamesWords(
      kits.kits.fold<KitNames>(
          _hostWords, (names, kit) => names.merge(kit.names)),
      () => _locale.value,
      decimalSeparator: () => planStrings.decimalSeparator);

  /// [build] run on [document] over the plan's own system (spec 3a C1.9),
  /// unrestricted (the host's construction, not an edit), then the history
  /// cleared: the built plan opens with nothing to undo. A build that
  /// throws leaves the empty plan: every step still in the history is
  /// undone, and it is one `hookFailed` (kit `plan`, subject `build`).
  void _runBuild(DraftDocument document, PlanBuild build) {
    final commands = document.commands;
    try {
      _unrestricted(commands, () => build(document, _buildWords));
    } catch (error) {
      _unrestricted(commands, () {
        while (commands.canUndo) {
          commands.undo();
        }
      });
      _diagnostics.add(KitDiagnostic(
          kitId: 'plan',
          subject: 'build',
          code: KitDiagnosticCode.hookFailed,
          message: 'build: $error',
          error: error));
    }
    commands.clearHistory();
  }
```

  6. `_open`'s signature becomes `void _open(DraftDocument document, FlutterTextMeasurer measurer, List<Diagnostic> loadDiagnostics, {PlanBuild? build}) {`; after `session.runKitFactories(kits, _services, _disabledTools);` (`:1538`) add:

```dart
    // Spec 3a C1.9: the host's build, over this session's system, before
    // the views listen, the change tracker takes its baseline and the save
    // point is taken.
    if (build != null) _runBuild(document, build);
```

  7. `_replace`'s named parameters gain `PlanBuild? build`; its `_open(document, measurer, loadDiagnostics);` becomes `_open(document, measurer, loadDiagnostics, build: build);`. Its doc's step 3 gains `, prepared and built when the plan library made it` after `the factories run over the new document`.
  8. `packages/jet_cad_2d_plan/lib/src/controller/new_plan.dart`'s header comment, lines 3-5, becomes `// Ported from jet_cad_floor_plan's new_document.dart, without its DASHED` / `// linetype: a kit adds what its types draw with in its own prepare (spec` / `// 3a C1.3), and with the registration passed in (the kits').`.

  Run `cd packages/jet_cad_2d_plan && dart format . && flutter test test/controller/prepare_build_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 7: The ported `new_document_test` lines.** Create `packages/jet_cad_2d_plan/test/controller/new_plan_test.dart`. Source: `packages/jet_cad_floor_plan/test/new_document_test.dart`. Ported: ND1 (`:21-47`) without its DASHED lines (`:35-38`), ND3 (`:64-80`) without its DASHED line (`:77-78`), ND4's setUp (`:83-96`) and its cases "with the page's registration alone" (`:105-111`) and "with the catalog's registration alone" (`:113-121`). Adaptations: `newDocument(measurer)` → `newPlanDocument(measurer, register: register)` (the test kit's registration, as the controller's `_register`); `registerAppComponents` → `register`; the sample (`startupPlan`) → two slabs on a 1:100 page (plan decision); `liveObjectsOf<WallParams>` → `catalog.objectsOf<SlabComponent>`; "live walls" → "live slab" in the case names. Assertions unchanged otherwise. Not ported: ND2 (plan decision); ND1's and ND3's DASHED lines and ND4's first case (Task 17).

```dart
// D-28's generic half (spec 3a C1.3, Appendix A): jet_cad_floor_plan's
// test/new_document_test.dart ND1, ND3 and two ND4 cases, ported over the
// plan library's newPlanDocument and the test kit's registration (the
// controller's), assertions unchanged. Not here: ND1's and ND3's DASHED
// lines and ND4's "with registerAppComponents: a live page and live
// walls", which need the architecture kit (Task 17); ND2, whose premise (a
// set-up adding no page, new_document.dart:18-24) the plan library does not
// have (new_plan.dart:23-33). The sample is two slabs off the origin,
// turned, on a 1:100 page whose origin is not the new plan's.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show FlutterTextMeasurer;
import 'package:jet_cad_2d_plan/src/controller/new_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';

void main() {
  late FlutterTextMeasurer measurer;
  setUp(() {
    measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
  });

  final catalog = catalogOf([testKit()]);
  void register(ComponentRegistry r) => registerPlanComponents(r, catalog);

  PageComponent? pageOf(DraftDocument d) =>
      d.components.get<PageComponent>(d.rootHandle);

  test(
      'ND1 the new document is empty, has no history, is in millimetres, '
      'and its page is the fixed literal (spec 12a D4, T-11)', () {
    final doc = newPlanDocument(measurer, register: register);

    expect(doc.entities.liveCount, 0);
    expect(doc.commands.undoDepth, 0);
    expect(doc.commands.canUndo, isFalse);
    expect(doc.commands.canRedo, isFalse);
    // The header's own default is unitless; the set-up changes it.
    expect(DraftDocument.empty(measurer: measurer).header.units,
        isNot(DrawingUnits.millimeters));
    expect(doc.header.units, DrawingUnits.millimeters);

    // The literal, written out here, not read from `defaultPlanPage`.
    expect(pageOf(doc), PageComponent(originX: -7425, originY: -5250));
    // And what the literal means: the A4 landscape sheet at 1:50, 14,850 x
    // 10,500 world mm, centred on the world origin.
    final sheet = sheetWorldRect(pageOf(doc)!);
    expect([sheet.minX, sheet.minY, sheet.maxX, sheet.maxY],
        [-7425.0, -5250.0, 7425.0, 5250.0]);
  });

  test(
      "ND3 the new document encodes, and decodes with the plan's "
      'registration to the same page, units and bytes (spec 12a D4, D8)', () {
    final doc = newPlanDocument(measurer, register: register);
    final saved = DraftDocumentCodec.encodeToString(doc);

    final loaded = DraftDocumentCodec.decodeString(saved,
        measurer: measurer, registerComponents: register);

    expect(pageOf(loaded), PageComponent(originX: -7425, originY: -5250));
    expect(pageOf(loaded), pageOf(doc));
    expect(loaded.components.unknownOf(loaded.rootHandle), isEmpty);
    expect(loaded.header.units, DrawingUnits.millimeters);
    expect(DraftDocumentCodec.encodeToString(loaded), saved);
  });

  group("ND4 the sample's bytes, decoded (spec 12a D8, S-1)", () {
    late DraftDocument sample;
    late String bytes;
    late List<Handle> sampleSlabs;
    setUp(() {
      sample = planDocument([testKit()], measurer: measurer);
      sample.commands.execute(SetComponentCommand<PageComponent>(
          sample.rootHandle,
          PageComponent(
              originX: -3100.5, originY: 820.25, scaleDenominator: 100)));
      installSystem(sample, [testKit()]);
      addObject<SlabComponent>(sample,
          SlabComponent(width: 1800, height: 900, angle: 0.4),
          at: Vector2(-2600, 1400));
      addObject<SlabComponent>(
          sample, SlabComponent(width: 1200, height: 700, angle: -1.1),
          at: Vector2(2300, 1400));
      bytes = DraftDocumentCodec.encodeToString(sample);
      sampleSlabs = catalog.objectsOf<SlabComponent>(sample);
      // The sample's page is off the world origin: not the new document's
      // page.
      expect(pageOf(sample), isNotNull);
      expect(
          pageOf(sample), isNot(PageComponent(originX: -7425, originY: -5250)));
      expect(sampleSlabs, hasLength(2));
    });

    test("with the page's registration alone: no live slab", () {
      final loaded = DraftDocumentCodec.decodeString(bytes,
          measurer: measurer, registerComponents: PageComponent.register);
      expect(pageOf(loaded), pageOf(sample));
      expect(catalog.objectsOf<SlabComponent>(loaded), isEmpty);
      expect(loaded.components.unknownOf(sampleSlabs.first), isNotEmpty);
    });

    test("with the catalog's registration alone: no live page", () {
      final loaded = DraftDocumentCodec.decodeString(bytes,
          measurer: measurer, registerComponents: catalog.registerComponents);
      expect(catalog.objectsOf<SlabComponent>(loaded), sampleSlabs);
      expect(loaded.components.isRegistered<PageComponent>(), isFalse);
      expect(pageOf(loaded), isNull);
      expect(loaded.components.unknownOf(loaded.rootHandle), isNotEmpty);
    });
  });
}
```

  Run `cd packages/jet_cad_2d_plan && dart format . && flutter test test/controller/new_plan_test.dart`. Expected: `All tests passed!` (ported tests of behaviour that exists: they pass on first run; their mutations are in Step 12).

- [ ] **Step 8: Docs and the amendment lines.**
  1. `docs/kits.md` §10.1, the paragraph after the snippet: append `A kit's prepare (a void Function(DraftDocument)) sets up each plan the plan library makes, the empty plan of a new controller and every newPlan, before any edit and outside history: the records its types draw with (the separator's DASHED linetype). A loaded or imported plan is never prepared, so a file is saved back as it was read. A host may fill a new plan in code with a PlanBuild (PlanController(build:), newPlan(build:)).` (prose, no ```dart block). §10.8's table gains a last row `` | a kit's `prepare` | the plan opens without what it would have added | ``.
  2. `docs/superpowers/specs/2026-10-13-kit-contract-design.md`, the section `## Amendments from sub-project 3a (2026-10-15)` (Task 1's): append

```markdown
- **Preparing and building a plan** (3a C1.3, C1.9): `PlanKit.prepare`
  (`void Function(DraftDocument)?`) prepares every document the plan
  library makes, never a loaded one; `PlanBuild` (`void
  Function(DraftDocument, KitWords)`) is a host's build of a new plan.
```

  3. `docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md`, the section `## Amendments` (Task 2's): append

```markdown
- **P4, a new plan and the kit's `prepare`** (3a C1.3): the constructor's
  plan without json and `newPlan` are prepared by every loaded kit, in
  load order, before any system is installed, then the history is
  cleared, before the save point and the unsettled baseline; a load or an
  import never is. A prepare that throws is a `hookFailed`, and the plan
  opens.
- **P2, the controller's `build`** (3a C1.9): `PlanController(build:)`
  (ignored with `json`) and `newPlan(build:)` run a `PlanBuild` on the new
  plan once its system is installed, unrestricted, then clear the history,
  so the built plan opens clean and still unsettled; its words are every
  loaded kit's, the host's first. A build that throws leaves the empty
  plan and is a `hookFailed` of the kit `plan`.
```

  Run `cd packages/jet_cad_2d_kit && flutter test test/invariants/doc_snippets_test.dart`. Expected: `All tests passed!` (no ```dart block changed).

- [ ] **Step 9: Format.** `cd packages/jet_cad_2d_kit && dart format .` and `cd packages/jet_cad_2d_plan && dart format .`.

- [ ] **Step 10: The gates.** From the repository root:
  - `cd packages/jet_cad_2d_kit && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0.
  - `cd packages/jet_cad_2d_plan && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .` — the same.
  - `dart run tool/ci/check_kit_deps.dart` — exit 0.
  - `git status --short`: only this task's files (no `analysis_options.yaml`; restore one `flutter pub get` rewrote with `git checkout -- <file>`).

- [ ] **Step 11: Commit.**

```bash
git add packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart packages/jet_cad_2d_kit/lib/src/kit/plan_build.dart packages/jet_cad_2d_kit/lib/src/kit/plan_kit.dart packages/jet_cad_2d_kit/test/kit/plan_build_test.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/src/controller/new_plan.dart packages/jet_cad_2d_plan/test/support/throwing_kit.dart packages/jet_cad_2d_plan/test/controller/prepare_build_test.dart packages/jet_cad_2d_plan/test/controller/new_plan_test.dart docs/kits.md docs/superpowers/specs/2026-10-13-kit-contract-design.md docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md
git commit -m "$(cat <<'EOF'
feat(plan): kits prepare new plans; a host builds one (spec 3a C1.3, C1.9)

PlanKit gains prepare, run on every document the plan library makes (the
constructor's plan without json and newPlan), in load order, outside
history, before the save point; a loaded or imported plan is never
prepared. PlanBuild fills a new plan in code over the plan's own system,
unrestricted, and the plan opens clean and still unsettled; a failing
prepare or build is one hookFailed and the plan opens. new_document_test's
generic lines are ported over newPlanDocument.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 12: Mutation check** (committed files only; after each: run the named test, see it red, quote the red line, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). Plan tests run with `cd packages/jet_cad_2d_plan && flutter test test/controller/prepare_build_test.dart` (or the file named).
  - M-PB-1 `plan_controller.dart`: delete `if (made) _prepare(document);` → PB1 red (`prepared` false).
  - M-PB-2 `plan_controller.dart`: delete `_prepare(made);` in `newPlan` → PB1 red after the newPlan; PB3 red (`a new plan is prepared`).
  - M-PB-3 `plan_controller.dart`: in `_prepare`, `for (final kit in kits.kits)` → `for (final kit in kits.kits.reversed)` → PB2 red (`['late:false', 'prep']`).
  - M-PB-4 `plan_controller.dart`: add `_prepare(document);` as the first statement of `_open` → PB3-prepare-load red (`prepared` true after the constructor's load, and `save()` differs).
  - M-PB-5 `plan_controller.dart`: in `_prepare`, replace the `try { prepare(document); } catch (error) { ... }` with `prepare(document);` → PB4 red (the constructor throws `BoomFailure(prepare)`).
  - M-PB-6 `plan_controller.dart`: delete `document.commands.clearHistory();` at the end of `_prepare` → PB5 red (`canUndo` true).
  - M-PB-7 `plan_controller.dart`: move `if (build != null) _runBuild(document, build);` from after `session.runKitFactories(...)` to the first statement of `_open` → PB6 red (`leavesOf` empty).
  - M-PB-8 `plan_controller.dart`: delete `commands.clearHistory();` at the end of `_runBuild` → PB6 red (`canUndo` true).
  - M-PB-9 `plan_controller.dart`: `_buildWords`' names → `kits.kits.fold<KitNames>(KitNames.empty, (names, kit) => names.merge(kit.names)).merge(_hostWords)` → PB6 red (`'Slab'`, not `'Plate'`).
  - M-PB-10 `plan_controller.dart`: the factory's `build: json == null ? build : null,` → `build: build,` and the constructor's `if (made) _prepare(document);` unchanged → PB7 red (`built` 1).
  - M-PB-11 `plan_controller.dart`: `newPlan`'s `_replace(made, measurer, unsettled: ..., build: build);` → drop `build: build` → PB8 red (no slab).
  - M-PB-12 `plan_controller.dart`: `_buildWords`' `() => _locale.value` → `() => const Locale('en')` → PB8 red (`Locale('en')`).
  - M-PB-13 `plan_controller.dart`: in `_runBuild`'s catch, delete the `_unrestricted(commands, () { while ... })` statement → PB9 red (one slab).
  - M-PB-14 `plan_controller.dart`: in `_runBuild`, replace the `try`/`catch` with its `try` body alone → PB9 red (the constructor throws `StateError`).
  - M-PB-15 `plan_controller.dart`: `_unrestricted(commands, () => build(document, _buildWords));` → `build(document, _buildWords);` → PB10 red (no slab; a `('plan', 'build')` diagnostic).
  - M-PB-16 `plan_controller.dart`: delete the `if (build != null) _runBuild(document, build);` line from `_open`, and add `if (build != null) _runBuild(document, build);` to the private constructor's body after `if (unsettled) _unsettled = ...;` → PB11 red (the separator stays `point`; `dirty` true).
  - M-ND-1 `new_plan.dart`: delete `doc.header.units = DrawingUnits.millimeters;` → `new_plan_test.dart` ND1 red (and C1, `plan_controller_test.dart`).
  - M-ND-2 `new_plan.dart`: `originX: -7425` → `originX: -7425.5` in `defaultPlanPage` → ND1 and ND3 red.
  - M-ND-3 `new_plan.dart`: delete `doc.commands.clearHistory();` → ND1 red (`undoDepth` 1).

  Quote each red line.

#### Assumed from earlier tasks

- Task 3: `KitNamesWords(names, locale, {decimalSeparator})`, `KitWords.text` and `decimalSeparator`; the plan's kit words pass `() => planStrings.decimalSeparator`.
- Task 1 created the contract spec's `## Amendments from sub-project 3a (2026-10-15)` section; Task 2 the 2a spec's `## Amendments` section and the `boomHooks` line this task appends after.

---

