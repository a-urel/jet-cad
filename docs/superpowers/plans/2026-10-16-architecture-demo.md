# The architecture demo (3b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `apps/architecture_demo`, a macOS and web app that runs the
architecture kit inside the plan library, with the old floor planner's
document flows, and nothing from the old packages.

**Architecture:** One `PlanController` over `[architectureKit]` for the
app's life, under one `PlanEditor`. A `DocumentHost` runs the file flows
(New, Open sample, Open, Save, Save As, the export write, exit) over the
controller's `newPlan`/`load`/`save`/`markSaved`/`dirty`; a
`DocumentSession` keeps only the file name, the location, the untitled
name and `busy`. The file layer (`document_files*`, `exit_guard*`) and the
app's words are copied from `apps/floor_planner` and stay domain-free.

**Tech Stack:** Flutter (macOS, web), `jet_cad_2d_plan`,
`jet_cad_2d_kit_architecture`, `file_selector`, `web`, `pdf`.

**Spec:** [docs/superpowers/specs/2026-10-16-architecture-demo-design.md](../specs/2026-10-16-architecture-demo-design.md)
(decisions 1-10, B1-B7), with its companion
[audit](../specs/2026-10-16-architecture-demo-test-audit.md) (one row per
old test case: PORT, COVERED, SPLIT, DROPPED). Read both.

## Global Constraints

- The app never names `jet_cad_floor_plan` or `jet_cad_restaurant_symbols`
  (pubspec, `lib/`, `test/`); N1 enforces it.
- `apps/floor_planner`, `packages/jet_cad_floor_plan`,
  `packages/jet_cad_restaurant_symbols` and the engine packages
  (`jet_cad`, `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_gpu`) are not
  touched. `jet_cad_2d_plan` is touched only by Task 1 and by a
  library-gap fix task the controller adds under decision 10.
- One `PlanController` for the app's life; New/Open sample/Open replace
  the plan inside it.
- `dirty` is `controller.dirty`; the session computes none.
- Dart language floor of the app: `sdk: ^3.5.0`, `flutter: ">=3.44.0"` (the
  old app's bounds and their comment).
- macOS bundle id `dev.jetcad.architectureDemo`, product name
  `architecture_demo`; the web title `jet-cad`.
- File extension `.jetplan`; `FileKind` jetplan, pdf, png.
- Busy (decision 5): the app's own flows plus the export dialog and the
  print job, through wrappers; while busy the file callbacks return
  without acting; `PlanPermissions` is never toggled.
- Error titles (decision 6): the app's failed export write is
  `exportFailed`; `onPageFlowError` is `pageFlowFailed` ("The page could
  not be exported or printed").
- Porting rules (3a): never weaken a ported assertion; never skip; a case
  whose premise is impossible splits into "<id>-open" and its intent,
  with the comment `// Decided: premise impossible (<why>)`. Every ported
  file starts with a header naming its old file and audit section.
- Every new test, and every behaviour change, names a mutation that turns
  it red; the implementer runs it on committed code, reverts it with
  `git checkout --`, and shows `git diff --quiet` passing.
- Never synthesize test output. Code, comments and commits in English.
  Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  (implementer subagents use their own model name).
- `analysis_options.yaml` is never committed, except the new app's own
  copy, once, in Task 2.
- Every task ends green: the app's `flutter test`, `flutter analyze`,
  `dart format --output=none --set-exit-if-changed .`; a task that touches
  `jet_cad_2d_plan` runs its gates too (`flutter test --enable-vmservice`).
- Reviews run on Sonnet (decision 2).

## Review Focus

1. **An edit that lands while a Save's write is pending** must stay dirty
   after the write: the save point is the state `save()` encoded, not the
   state at `markSaved()`. Task 4 pins it (SV-edit-during-write).
2. **A failed open of an old-format or garbage file** changes nothing: the
   plan, its name, its dirty flag and its undo history stay. Task 4 pins it
   (OP-garbage).
3. **The exit request while the export dialog is up** cancels, with no
   second dialog. Task 6 pins it (N6-exit).
4. **A locale switch on an untitled plan** renames it in the tab title in
   the same frame as the editor's words, and leaves a named file's name.
   Task 5 pins it (N5).
5. **Cmd/Ctrl+S inside a dialog's route on web** is consumed, never the
   browser's Save Page. Task 2 pins it (CH-consume).

---

## File structure

```
apps/architecture_demo/
  pubspec.yaml                 Task 2
  analysis_options.yaml        Task 2 (committed once)
  macos/, web/                 Task 2 (copied from floor_planner, renamed)
  lib/
    main.dart                  Task 2 (app shell), Task 4 (host wiring)
    app_strings.dart           Task 3
    document_files.dart        Task 3 (copied)
    document_files_io.dart     Task 3 (copied)
    document_files_web.dart    Task 3 (copied)
    document_files_stub.dart   Task 3 (copied)
    exit_guard.dart            Task 3 (copied)
    exit_guard_web.dart        Task 3 (copied)
    exit_guard_stub.dart       Task 3 (copied)
    document_session.dart      Task 4
    document_host.dart         Task 4 (flows), Task 5 (exit, title), Task 6 (export, print)
    busy_wrappers.dart         Task 6
  test/
    support/app_fakes.dart     Task 3 (files, exit guard), Task 6 (printer)
    support/app_rig.dart       Task 4
    boundary_test.dart         Task 2 (N1)
    app_shell_test.dart        Task 2
    ...ported files            Tasks 3-7
packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart   Task 1
```

---

### Task 1: The library exports the export dialog and the file chords

The app's busy wrapper (decision 5) must call the library's own export
dialog, and its consume-only chord layer (Review Focus 5) must name the
same chords the editor binds. Both exist in `jet_cad_2d_plan` but are not
exported.

**Files:**
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart`
- Modify: `packages/jet_cad_2d_plan/test/barrel_test.dart`
- Modify: `packages/jet_cad_2d_plan/CHANGELOG.md` (the unreleased 0.1.0
  section: one line)

**Interfaces:**
- Produces: public `showPlanExportDialog(BuildContext, PlanExportAnswer,
  List<PlanExporter>) → Future<PlanExportAnswer?>` (matches
  `PlanExportDialog`) and `kFileChords` (`List<SingleActivator>`: New,
  Open, Save, Save As, Export, Print, each in its Ctrl and Meta form).

- [ ] **Step 1: Read `barrel_test.dart`** to see how it pins the barrel's
  names (a list of names, or a compile-time use of each).

- [ ] **Step 2: Add the two names to the test** in that file's style, e.g.

```dart
test('the barrel exports the export dialog and the file chords', () {
  const PlanExportDialog dialog = showPlanExportDialog;
  expect(dialog, isNotNull);
  expect(kFileChords, isNotEmpty);
});
```

- [ ] **Step 3: Run it red:** `cd packages/jet_cad_2d_plan && flutter test test/barrel_test.dart` → compile error, undefined names.

- [ ] **Step 4: Export them:**

```dart
export 'src/export/export_dialog.dart'
    show PlanExportDialog, showPlanExportDialog;
export 'src/shortcuts/chords.dart' show kFileChords;
```

(replace the existing `export 'src/export/export_dialog.dart' show
PlanExportDialog;` line; keep the file's sort order).

- [ ] **Step 5:** If `kFileChords`' doc comment does not say what it holds,
  add one line. Run the package gates: `flutter test --enable-vmservice`,
  `flutter analyze`, `dart format --output=none --set-exit-if-changed .`.
  Mutation: drop `showPlanExportDialog` from the show list → the test
  fails to compile.

- [ ] **Step 6: Commit** `feat(plan): export showPlanExportDialog and kFileChords for hosts`.

---

### Task 2: The app's scaffold, the boundary and the chord layer

**Files:**
- Create: `apps/architecture_demo/pubspec.yaml`, `analysis_options.yaml`,
  `lib/main.dart`, `test/boundary_test.dart`, `test/app_shell_test.dart`
- Create: `apps/architecture_demo/macos/**`, `web/**` copied from
  `apps/floor_planner` (not `build/`), renamed
- Modify: root `pubspec.yaml` (`workspace:` gains
  `apps/architecture_demo` after `apps/floor_planner`)

**Interfaces:**
- Produces: `ArchitectureDemoApp` (StatefulWidget) with test seams
  `{DocumentFiles? files, ExitGuard? exitGuard, PagePrinter printer =
  const PrintingPagePrinter()}` — Task 2 creates it with only `printer`;
  Tasks 3-4 add the other two. Its state exposes
  `@visibleForTesting PlanController get controller`.
- Produces: `const Color kAppSeed = Color(0xFF2266CC);`

- [ ] **Step 1: Copy the runners.** `cp -R apps/floor_planner/macos apps/floor_planner/web apps/architecture_demo/` (no `build/`). In `macos/Runner/Configs/AppInfo.xcconfig` set `PRODUCT_NAME = architecture_demo`, `PRODUCT_BUNDLE_IDENTIFIER = dev.jetcad.architectureDemo`; replace `floor_planner` in `Runner.xcscheme`, `project.pbxproj` (`floor_planner.app` → `architecture_demo.app`), `web/index.html` and `web/manifest.json` (names and descriptions: "jet-cad architecture demo"). `grep -rn "floor_planner\|floorPlanner" apps/architecture_demo` must print nothing. Keep `MainFlutterWindow.swift`'s close-button routing (the exit request, Task 5).

- [ ] **Step 2: pubspec.**

```yaml
name: architecture_demo
description: >-
  The architecture kit's demo: the plan library's editor over the
  architecture kit, with the document flows (new, open sample, open, save,
  save as, export, print, exit) on macOS and the web.
publish_to: none
version: 0.0.1
resolution: workspace

environment:
  # The old floor_planner's bounds, for its reasons: printing 5.15 needs
  # Flutter 3.41 and pdf 3.13 needs Dart 3.12 (Flutter 3.44); the sdk
  # bound sets the language version, kept at 3.5 so the formatter's style
  # matches the copied files.
  sdk: ^3.5.0
  flutter: ">=3.44.0"

dependencies:
  file_selector: ^1.1.0
  flutter:
    sdk: flutter
  jet_cad_2d_kit_architecture: ^0.1.0
  jet_cad_2d_plan: ^0.1.0
  # The print wrapper names PdfPageFormat (PagePrinter's signature).
  pdf: ^3.13.1
  web: ^1.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

Check the two package versions in their pubspecs and use those. If the
old app declared a font family in `flutter: fonts:` for a reason that
still holds (the web engine fetching Roboto), check whether
`jet_cad_2d_plan` ships its font and `ensurePlanFonts` registers it; add
the family from `packages/jet_cad_2d_plan/...` only if the library's
README or its example app does the same. Write which in the report.

- [ ] **Step 3: analysis_options.yaml:** copy the old app's. Commit it once
  in this task (the one exception).

- [ ] **Step 4: N1, the boundary test (red first).**

```dart
// N1 (spec B6): the app names neither old package.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _banned = ['jet_cad_floor_plan', 'jet_cad_restaurant_symbols'];

void main() {
  test('N1 the pubspec and every Dart file name no old package', () {
    final files = <File>[
      File('pubspec.yaml'),
      for (final dir in ['lib', 'test'])
        ...Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
    ];
    final hits = <String>[];
    for (final f in files) {
      if (f.path.endsWith('boundary_test.dart')) continue;
      final text = f.readAsStringSync();
      for (final name in _banned) {
        if (text.contains(name)) hits.add('${f.path}: $name');
      }
    }
    expect(files.length, greaterThan(2), reason: 'the walk found the files');
    expect(hits, isEmpty);
  });
}
```

Mutation M-N1: add `// jet_cad_floor_plan` to `lib/main.dart` → red.

- [ ] **Step 5: main.dart, the shell.** The app owns one controller and
  shows one editor; no host flows yet.

```dart
import 'package:flutter/material.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

/// The app's theme seed, light and dark alike (the old app's).
const Color kAppSeed = Color(0xFF2266CC);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ensurePlanFonts();
  } catch (error, stack) {
    // A failed registration is reported, not fatal: the app still starts.
    FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'architecture_demo',
        context: ErrorDescription('while registering the plan font')));
  }
  registerFontLicences();
  runApp(const ArchitectureDemoApp());
}

class ArchitectureDemoApp extends StatefulWidget {
  const ArchitectureDemoApp(
      {super.key, this.printer = const PrintingPagePrinter()});

  /// Where Print hands the page's PDF: the platform's dialog unless a test
  /// gives a fake.
  final PagePrinter printer;

  @override
  State<ArchitectureDemoApp> createState() => ArchitectureDemoAppState();
}

class ArchitectureDemoAppState extends State<ArchitectureDemoApp> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  /// The app's one controller: New, Open sample and Open replace the plan
  /// inside it, so the editor, its panels and its caches stay.
  late final PlanController _controller =
      PlanController(kits: [architectureKit], symbols: PlanSymbolLoader());

  @visibleForTesting
  PlanController get controller => _controller;

  /// Marks a file chord handled, and does nothing.
  static void _consume() {}

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: _navigator,
        title: 'jet-cad',
        debugShowCheckedModeBanner: false,
        supportedLocales: planSupportedLocales,
        localizationsDelegates: planLocalizationsDelegates,
        theme: ThemeData(colorSchemeSeed: kAppSeed),
        darkTheme:
            ThemeData(colorSchemeSeed: kAppSeed, brightness: Brightness.dark),
        themeMode: ThemeMode.system,
        // The file chords once more above the Navigator, consume-only: a
        // dialog's route is outside the editor's focus chain, and on the
        // web an unhandled Cmd/Ctrl+S opens the browser's Save Page. The
        // editor's own bindings run the commands when the home route has
        // the focus.
        builder: (context, child) => CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            for (final chord in kFileChords) chord: _consume,
          },
          child: child!,
        ),
        home: Scaffold(
            body: PlanEditor(controller: _controller, printer: widget.printer)),
      );
}
```

Check `PlanSymbolLoader`'s ownership: if the controller disposes a loader
it was given, keep it; if not, the app disposes it after the controller.
Read `PlanController.dispose` and say which in the report.

- [ ] **Step 6: app_shell_test.dart.**
  - AS1: the app pumps; one `PlanEditor`; the Symbols tab exists (the
    kit's furniture); `controller.dirty.value` is false. Mutation: build
    the controller with `kits: []` (the Symbols tab disappears).
  - CH-consume (Review Focus 5): open a dialog over the home route
    (`showDialog` with a `TextField`), send Meta+S and Control+S; the key
    event result is handled (`tester.sendKeyEvent` returns true) and the
    controller's `save` is not reached (nothing written; there is no host
    yet, so assert no exception and the dialog still up). Mutation: drop
    the `builder:` layer → the key is not handled.
  - AS-dispose: unmount the app (pump `SizedBox()`); no "used after
    dispose" error. Mutation: dispose the controller in `deactivate`.

- [ ] **Step 7:** `flutter pub get` at the repo root (it rewrites three
  `analysis_options.yaml`; never stage those), then the app's gates, then
  `flutter build macos --debug` and `flutter build web` once (paste their
  last lines into the report).

- [ ] **Step 8: Commit** `feat(demo): scaffold apps/architecture_demo on the plan library and the architecture kit`.

---

### Task 3: The file layer and the app's words

**Files:**
- Create (copy from `apps/floor_planner/lib`): `document_files.dart`,
  `document_files_io.dart`, `document_files_web.dart`,
  `document_files_stub.dart`, `exit_guard.dart`, `exit_guard_web.dart`,
  `exit_guard_stub.dart`, `app_strings.dart`
- Create: `test/support/app_fakes.dart` (the old tests' in-memory
  `DocumentFiles` and `ExitGuard` fakes, moved from wherever the old tests
  define them: `apps/floor_planner/test/support/` and file-local helpers)
- Create (port): `test/document_files_test.dart`,
  `test/document_files_kind_test.dart`,
  `test/document_files_sources_test.dart`, `test/app_words_test.dart`

**Interfaces:**
- Produces (unchanged from the old app): `DocumentFiles`, `FileKind`
  (`jetplan`, `pdf`, `png`; `.extension`, `.label`, `.mimeType`),
  `kJetplanExtension`, `DocumentNamePrompt`, `FileTypeLabel`,
  `englishFileTypeLabel`, `createDocumentFiles({required DocumentNamePrompt
  askName, required FileTypeLabel typeLabel})`, `ExitGuard`,
  `createExitGuard()`, `AppStrings.of(context)`.
- `AppStrings` changes: drop `printFailed`; add `String get pageFlowFailed`
  — en "The page could not be exported or printed", de "Die Seite konnte
  nicht exportiert oder gedruckt werden", tr "Sayfa dışa aktarılamadı ya da
  yazdırılamadı". Every other word is the old app's.
- `AppStrings`' localization delegate (if the old app had one) is added to
  `MaterialApp.localizationsDelegates` in `main.dart` beside
  `planLocalizationsDelegates`.

- [ ] **Step 1:** Copy the files. Replace each `jet_cad_floor_plan` import
  with what the file actually uses: `FloorPlanStrings.cancel` →
  `PlanStrings.of(context)`'s cancel word if it has one (grep
  `packages/jet_cad_2d_plan/lib/src/l10n/strings.dart`), else an
  `AppStrings.cancel` word (en Cancel, de Abbrechen, tr İptal). N1 stays
  green.

- [ ] **Step 2: Port the four test files** per the audit's sections
  "document_files_test.dart", "document_files_kind_test.dart",
  "document_files_sources_test.dart", "app_words_test.dart": every row is
  PORT. Copy each case; change only imports and the app type
  (`FloorPlannerApp` → `ArchitectureDemoApp`). An `app_words_test` case
  that reads `printFailed` reads `pageFlowFailed` and its three words
  above; it keeps every other assertion (the de/tr words differ from en,
  no word empty, the file type labels).

- [ ] **Step 3: New case AW-pageflow:** `pageFlowFailed` in en/de/tr equals
  the three strings above. Mutation: the de word returns the en one.

- [ ] **Step 4:** Gates. Run each ported file once against a deliberate
  break of the code it covers (for example `FileKind.png.extension`
  returning `'jpg'`) and list the mutations and their red tests in the
  report. Revert each.

- [ ] **Step 5: Commit** `feat(demo): the file layer and the app's words, ported with their tests`.

---

### Task 4: The session and the document flows

**Files:**
- Create: `lib/document_session.dart`, `lib/document_host.dart`
- Modify: `lib/main.dart` (the app owns the session and the files; home is
  the host)
- Create: `test/support/app_rig.dart`
- Create (port): `test/document_commands_test.dart`,
  `test/document_host_test.dart`, `test/document_open_test.dart`,
  `test/document_replace_test.dart`, `test/document_save_test.dart`,
  `test/document_separator_test.dart`, `test/document_settle_test.dart`
- Create: `test/document_sample_test.dart` (N2, N4, SV-edit-during-write,
  OP-garbage)

**Interfaces:**
- Consumes: Task 3's files and words; Task 1's names.
- Produces:
  - `const String kUntitledName = 'Untitled';`
  - `String documentTitle(String name, {required bool dirty})` →
    `'${dirty ? '• ' : ''}$name — jet-cad'`
  - `String documentNameOf(String fileName)` (the old one)
  - `class DocumentSession extends ChangeNotifier` with `fileName`,
    `location`, `name`, `untitledName`, `setUntitledName(String) → bool`,
    `nameChanged()`, `busy` (`ValueNotifier<bool>`),
    `named(String? fileName, Object? location)` (one notification)
  - `enum SaveChoice { save, discard, cancel }`
  - `class DocumentHost extends StatefulWidget` with `{required
    PlanController controller, required DocumentSession session, required
    DocumentFiles files, ExitGuard? exitGuard, PagePrinter printer}`;
    `DocumentHostState` with public flows `newFlow()`, `openSampleFlow()`,
    `openFlow()`, `saveStep() → Future<bool>`, `saveAsStep() →
    Future<bool>` (the tests call them, as today)
  - `ArchitectureDemoApp({DocumentFiles? files, createFiles =
    createDocumentFiles, ExitGuard? exitGuard, PagePrinter printer})`

- [ ] **Step 1: DocumentSession.**

```dart
/// What the app knows about the plan's file, beside the controller: its
/// name and location, the untitled name in the app's language, and whether
/// a flow runs. Dirty is the controller's (`PlanController.dirty`).
///
/// Notifies when the name or the location changes; [busy] notifies for
/// itself.
class DocumentSession extends ChangeNotifier {
  String? _fileName;
  Object? _location;
  String _untitledName = kUntitledName;

  /// Whether a flow is running. Set by the outermost flow only.
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  /// The file's name, with its extension; null while untitled.
  String? get fileName => _fileName;

  /// Where a Save writes, as the files object returned it; opaque here.
  Object? get location => _location;

  /// [untitledName], or [fileName] without `.jetplan`.
  String get name =>
      _fileName == null ? _untitledName : documentNameOf(_fileName!);

  String get untitledName => _untitledName;

  /// Sets [untitledName] without notifying (the host sets it during a
  /// build); true when the shown [name] changed, and the host then calls
  /// [nameChanged] after the frame.
  bool setUntitledName(String next) {
    if (next == _untitledName) return false;
    _untitledName = next;
    return _fileName == null;
  }

  void nameChanged() => notifyListeners();

  /// The plan is now the file [fileName] at [location] (untitled when
  /// null). One notification.
  void named(String? fileName, Object? location) {
    _fileName = fileName;
    _location = location;
    notifyListeners();
  }

  @override
  void dispose() {
    busy.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 2: DocumentHost, the flows.** Port the old
  `DocumentHostState` (`apps/floor_planner/lib/document_host.dart:263-698`)
  with these changes, and nothing else:
  - No `_settle` registry: `controller.save()` and `controller.load()`
    settle pending input themselves; `newFlow`/`openSampleFlow` call
    `controller.settlePendingInput()` first if it is public (grep), else
    rely on `newPlan` settling (read its body and say which).
  - `_mayDiscard()` loops on `controller.dirty.value` after the settle.
    Read the controller: if `dirty` updates synchronously on a command
    (`_refreshFlags` in the commit path), that is the old
    `differsFromSave`; if it follows the async change stream, add a
    synchronous read and say which in the report.
  - New: `controller.newPlan()`; then `session.named(null, null)`.
  - Open sample: `controller.newPlan(build: buildSampleFlat)`; then
    `session.named(null, null)`.
  - Open: after `_mayDiscard`, `files.open()`; on a file, `utf8.decode`
    then `controller.load(text)`; a throw from either (a
    `PlanFormatException`, a `FormatException`, anything) shows
    `couldNotOpen(name)` and changes nothing; on success
    `session.named(file.name, file.location)`.
  - Save / Save As: `final text = controller.save();` (a throw shows
    `couldNotSave`), `utf8.encode`, the old location logic, then on a
    successful write `controller.markSaved()` and
    `session.named(fileName, location)`. The old
    `identical(_session.document, …)` guard has no counterpart: the busy
    flag keeps New/Open from running during the write (decision 5); say so
    in a comment.
  - `build`: `PlanEditor(controller: …, onNew: _idle(newFlow), onOpen:
    _idle(openFlow), onSave: _idle(saveStep), onSaveAs: _idle(saveAsStep),
    printer: widget.printer, exportName: session.name, bar: PlanEditorBar(
    leading: [_DocumentTitle(...), _OpenSampleButton(...)]))` inside a
    `ListenableBuilder` over the session. `_idle(f)` returns a
    `PlanFileCallback` that does nothing while `session.busy.value`.
  - `_DocumentTitle` shows `session.name` and `•` while
    `controller.dirty`, in a `ConstrainedBox(maxWidth: 240)` with
    `TextOverflow.ellipsis`, key `document-name`. `_OpenSampleButton` is
    an `IconButton(key: Key('toolbar-open-sample'), icon:
    Icons.home_work_outlined, tooltip: words.openSample, onPressed:
    _idle(openSampleFlow))`.
  - The Save-changes dialog and the name prompt: copied unchanged (keys
    kept).

- [ ] **Step 3: main.dart** gains the session, the files (the old
  `_askName`, `_typeLabel`), `files`/`createFiles`/`exitGuard` seams, the
  `MaterialApp` rebuilt from `Listenable.merge([session,
  controller.dirty])` with `onGenerateTitle: (_) =>
  documentTitle(session.name, dirty: controller.dirty.value)`, and `home:
  DocumentHost(...)`.

- [ ] **Step 4: app_rig.dart.** One helper set for every app test (R-P14:
  no copies elsewhere): `pumpApp(tester, {FakeFiles? files, FakeExitGuard?
  guard, PagePrinter? printer}) → AppRig` with `rig.host`
  (`DocumentHostState`), `rig.controller`, `rig.session`, `rig.files`,
  `rig.editOnce()` (one undoable edit through the controller's command
  path, e.g. a wall drawn by the wall tool with pointer events, or a page
  property set through the property panel; choose one that makes `dirty`
  true and say which), `rig.tapKey(String key)`.

- [ ] **Step 5: Port the seven document test files** per their audit
  sections. PORT rows: copy, change imports, `FloorPlannerApp` →
  `pumpApp`, `session.document` reads → `controller` reads,
  `session.dirty` → `controller.dirty`. SPLIT rows: write both halves as
  the audit describes them, the intent half citing its covering test in a
  comment. COVERED rows: no app test; open the named test and confirm it
  still exists and asserts the intent; list each in the report as
  "COVERED, checked: <file>:<line>". DROPPED rows: a one-line comment in
  the ported file's header naming the case and the audit's reason.

- [ ] **Step 6: The new cases**, in `document_sample_test.dart`:
  - **N2:** on a fresh app, tap `toolbar-open-sample`; the plan has walls,
    rooms and furniture (count live objects by type id through
    `ArchitectureTypes`), `dirty` false, undo not available. Then
    `rig.editOnce()`; `dirty` true; `host.newFlow()` shows the
    `replace-dialog`. Mutations: M-N2a open the sample with
    `newPlan()` then a manual build that leaves an undo step (undo
    becomes available → red); M-N2b `_mayDiscard` returns true without
    asking (no dialog → red).
  - **N4:** open the sample, Save As into the fake files as `flat.jetplan`,
    New, Open `flat.jetplan`: `controller.save()` of the reopened plan
    equals the saved text, the title reads `flat — jet-cad`, `dirty` false.
    Mutation M-N4: the write takes `controller.save()` of a fresh
    `newPlan` (the texts differ → red).
  - **SV-edit-during-write (Review Focus 1):** a fake write that waits on
    a `Completer`; during it, `rig.editOnce()`; complete; `dirty` is true.
    Mutation: `markSaved` before the write's await is replaced by reading
    the state after it (call `controller.save()` again after the write,
    then `markSaved`) → `dirty` false → red.
  - **OP-garbage (Review Focus 2):** with an edited, named plan, open a
    fake file of bytes `{"not": "a plan"}`: the error dialog
    `document-error` shows `couldNotOpen`, and after OK the plan's text,
    its name, `dirty` (true) and undo availability are unchanged.
    Mutation: name the session before `load` (the name changes → red).

- [ ] **Step 7:** Gates; N1 still green. The report lists every audit row
  of the seven files with its outcome, and every mutation run.

- [ ] **Step 8: Commit** in two or three logical commits:
  `feat(demo): the document session and host over PlanController`,
  `test(demo): the document flows' tests, ported`, `test(demo): N2, N4,
  save during a write, a failed open`.

---

### Task 5: The exit, the title and the language

**Files:**
- Modify: `lib/document_host.dart` (exit listener, exit guard, untitled
  name)
- Create (port): `test/document_exit_test.dart`
- Create: `test/document_title_test.dart` (N3, N5)

**Interfaces:**
- Consumes: Task 4's host, session, rig.
- Produces: `DocumentHostState` arms the `ExitGuard` exactly while
  `controller.dirty`; answers the app's exit request
  (`AppLifecycleListener.onExitRequested`) as the old
  `_onExitRequested` does.

- [ ] **Step 1:** Port the old `_onExitRequested`, `_armExitGuard`, the
  `AppLifecycleListener` and the `didChangeDependencies` untitled-name
  update (`document_host.dart:424-440, 649-679`), with `dirty` read from
  the controller and `_settlePendingInput()` removed (the controller's
  `save()` and `dirty` read settle; if the exit must settle a typed value
  before reading `dirty`, call the controller's public settle, as Task 4
  found).

- [ ] **Step 2: Port `document_exit_test.dart`** (8 PORT rows).

- [ ] **Step 3: N3, the title:** the `MaterialApp`'s title (read
  `tester.widget<Title>(find.byType(Title)).title`) is `Untitled — jet-cad`;
  after `rig.editOnce()` `• Untitled — jet-cad`; after a Save As
  `flat.jetplan`, `flat — jet-cad`; after an edit and an undo back to the
  save point, `flat — jet-cad`. Mutation M-N3: the title reads a session
  flag set only in `saveStep` (the undo case stays dotted → red).

- [ ] **Step 4: N5, the language (Review Focus 4):** pump with locale en;
  switch the `MaterialApp`'s locale to tr (through
  `tester.platformDispatcher.localesTestValue` and a pump, or the rig's
  locale seam): the title becomes `Adsız — jet-cad` within that pump
  sequence (one frame plus the post-frame callback), and an editor word
  (any `PlanStrings` label on screen) is Turkish in the same pump. Then
  name the plan by a Save As and switch to de: the title keeps the file's
  name. Mutation M-N5: `setUntitledName` called in `initState` only
  (title stays `Untitled` → red).

- [ ] **Step 5:** Gates. **Commit** `feat(demo): the exit request, the exit guard and the untitled name`, then `test(demo): exit, title and language`.

---

### Task 6: Export and print

**Files:**
- Create: `lib/busy_wrappers.dart`
- Modify: `lib/document_host.dart` (`onExport`, `onExportDialog`,
  `printer`, `onPageFlowError`)
- Modify: `test/support/app_fakes.dart` (the recording printer, from the
  old tests)
- Create (port): `test/export/export_flow_test.dart`,
  `test/export/print_flow_test.dart`,
  `test/export/export_end_to_end_test.dart`,
  `test/export/export_font_test.dart` (EF1, EF2, EF9-EF12 per the audit)
- Create: `test/export/busy_test.dart` (N6)

**Interfaces:**
- Consumes: Task 1's `showPlanExportDialog`; Task 4's session.
- Produces:

```dart
/// The export dialog with the session busy while it is up (spec decision
/// 5): the library's own dialog, so the app sees the export in flight.
PlanExportDialog busyExportDialog(ValueNotifier<bool> busy,
        {PlanExportDialog dialog = showPlanExportDialog}) =>
    (context, initial, exporters) async {
      final outer = busy.value;
      busy.value = true;
      try {
        return await dialog(context, initial, exporters);
      } finally {
        if (!outer) busy.value = false;
      }
    };

/// [inner] with the session busy while the platform's print job runs.
final class BusyPagePrinter implements PagePrinter {
  BusyPagePrinter(this.busy, this.inner);

  final ValueNotifier<bool> busy;
  final PagePrinter inner;

  @override
  Future<void> print(Uint8List pdf, String name, PdfPageFormat format) async {
    final outer = busy.value;
    busy.value = true;
    try {
      await inner.print(pdf, name, format);
    } finally {
      if (!outer) busy.value = false;
    }
  }
}
```

- [ ] **Step 1: The host's export write.** `onExport: (export) =>
  unawaited(_exportFlow(export))`; `_exportFlow` runs as a flow (busy),
  takes the kind from `export.name`'s extension (`pdf` → `FileKind.pdf`,
  `png` → `FileKind.png`; any other extension is an `ArgumentError` shown
  as `exportFailed`, since the library's built-ins make only pdf and
  png), asks `files.saveLocation(export.name,
  kind: kind)`, writes `export.bytes`; a throw shows `exportFailed`. A
  cancel writes nothing.

- [ ] **Step 2: Wire the wrappers and the error:** `onExportDialog:
  busyExportDialog(session.busy)`, `printer:
  BusyPagePrinter(session.busy, widget.printer)` (made once in
  `initState`, not per build), `onPageFlowError: (e) =>
  unawaited(_showError((w) => w.pageFlowFailed, e))`.

- [ ] **Step 3: Port the four export files** per their audit sections
  (PORT, SPLIT, COVERED, DROPPED as in Task 4 step 5). The SPLIT halves
  that assert "disabled while a flow runs" become "the callback does
  nothing while busy" (decision 5); their intent halves cite PF7.

- [ ] **Step 4: N6 (and Review Focus 3):**
  - N6-dialog: open the export dialog through the bar's Export button;
    while it is up, `session.busy` is true, `host.newFlow()` called
    through the editor's New button does nothing (no `replace-dialog`, the
    plan unchanged); dismiss; busy false.
  - N6-print: a fake printer that waits on a `Completer`; Print; while
    pending, Cmd+S does nothing (nothing written); complete; busy false.
  - N6-exit: while the export dialog is up, the exit request answers
    `AppExitResponse.cancel` with no second dialog.
  - Mutations: M-N6a pass the library's dialog directly (no wrapper) →
    N6-dialog red; M-N6b pass `widget.printer` directly → N6-print red.

- [ ] **Step 5:** Gates. **Commit** `feat(demo): export writes, print and the busy wrappers`, then `test(demo): export and print, ported; N6`.

---

### Task 7: Symbols and layers through the app; the library gaps

**Files:**
- Create (port): `test/symbols/symbol_library_loader_test.dart` (only
  its PORT/SPLIT rows; the audit says 0 PORT, 1 SPLIT),
  `test/symbols/symbol_shell_test.dart` (SS1-SS15 rows),
  `test/symbols/symbol_palette_end_to_end_test.dart`,
  `test/symbols/symbol_section_end_to_end_test.dart`,
  `test/layers/layers_end_to_end_test.dart`
- Create: `packages/jet_cad_2d_integration/test/layers/layer_picker_types_test.dart`
  (the layer picker's SPLIT row: the six architecture types alone enable
  the picker and show their layer — the audit puts it in the integration
  package)
- Create: `test/library_gaps_test.dart` (decision 10)

**Interfaces:**
- Consumes: Task 4's rig.

- [ ] **Step 1: Port the symbol and layer files** per their audit
  sections, as in Task 4 step 5. SS7 splits per decision 7: SS7-open pins
  that after New `controller.armedSymbol` is still the armed furniture
  symbol (today's library behaviour); SS7 (intent) pins that the active
  tool is Select and the gallery shows no armed cell. Mutation for SS7:
  reset the active tool to the symbol tool after `newPlan` in a scratch
  edit of the host (the intent half reds).

- [ ] **Step 2: Library gaps** (decision 10), one case each, through the
  app (`pumpApp`), each with a mutation in the library code it pins (run,
  revert):
  - LG1 file buttons gated mid-shape: press with the wall tool, before
    release the Save button does nothing (nothing written) and Cmd+S does
    nothing. Mutation: drop `_idleFlag` from the file buttons' enabled.
  - LG2 the Meta variants: Meta+S, Meta+O, Meta+N, Meta+Shift+S, Meta+P run
    the same flows as their Control forms. Mutation: drop the meta half
    of `_chord`.
  - LG3 redo chords: Meta/Control+Shift+Z and Control+Y redo. Mutation:
    drop one.
  - LG4 tab and cell focus in the Symbols gallery: Tab moves from the
    search field to the first cell; switching tabs does not change the
    active tool. Mutation: the tab switch arms Select.
  - LG5 the gallery's search text survives a tab switch and a New.
    Mutation: the editor rebuilds the gallery with a fresh query on
    `newPlan`.
  - LG6 Export and Print follow the page: with the page detached (the page
    panel's off switch) they are disabled; undo makes them enabled; redo
    disabled. Mutation: the flags read once at build.

  If an LG case is red on today's library (not a mutation), stop: report
  it as DONE_WITH_CONCERNS with the failing output; the controller adds a
  library fix task (decision 10) before this task closes.

- [ ] **Step 3: Library-side gaps** in `packages/jet_cad_2d_plan/test`:
  `PrintingPagePrinter` hands `Printing.layoutPdf` the name and format
  (old PR8, through the `printing` package's platform mock if it has one;
  if none, record in the report that PR8 stays DROPPED with this reason
  and add it to the audit row), and Escape in `PlanExportDialog` pops
  null. Mutations as above.

- [ ] **Step 4:** Gates for the app, `jet_cad_2d_plan` and
  `jet_cad_2d_integration`. **Commit** `test(demo): symbols and layers through the app`, `test(demo,plan): the library gaps pinned`.

---

### Task 8: The exit gate

**Files:**
- Create: `docs/superpowers/notes/2026-10-16-architecture-demo-results.md`
- Modify: `docs/superpowers/specs/2026-10-13-kit-architecture-design.md`
  (Amendments: one line, spec 3b's "Amendments to other specs" first
  bullet), `docs/superpowers/specs/2026-10-15-architecture-kit-design.md`
  (Amendments: one line, the second bullet)
- Modify: `docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md`
  (a "Closed" column or a closing section: each row's outcome and where)
- Modify: `STATUS.md`

- [ ] **Step 1: Audit closure.** For every row of the audit, its outcome:
  ported (file:test), split (both names), covered (checked file:line),
  dropped (reason). A script or a grep over the test files, not memory.
  Any open row is a defect: fix it before the gate.

- [ ] **Step 2: The gates,** each run fresh, last lines transcribed into
  the results note: the app's test/analyze/format; `jet_cad_2d_plan`
  (`--enable-vmservice`), `jet_cad_2d_integration` (`--enable-vmservice`);
  `flutter build macos` and `flutter build web` in the app;
  `git diff --stat main -- packages/jet_cad packages/jet_cad_2d
  packages/jet_cad_2d_flutter packages/jet_cad_2d_gpu
  packages/jet_cad_floor_plan packages/jet_cad_restaurant_symbols
  apps/floor_planner` prints nothing; the `jet_cad_2d_plan` dry-run with 0
  warnings (Task 1 touched it).

- [ ] **Step 3: The smoke run (controller, not a subagent):** `flutter run
  -d macos` from `apps/architecture_demo`; Open sample; draw a wall; Save
  As into the scratchpad; New; Open the saved file; screenshot the
  reopened plan (computer-use or `screencapture`), saved to
  `docs/superpowers/notes/2026-10-16-architecture-demo-smoke.png`; the
  console's last lines transcribed. Then the same on web (`flutter run -d
  chrome` or `flutter build web` served locally) as far as Open sample and
  an Export → PNG download.

- [ ] **Step 4:** The results note (gates, smoke, audit totals by outcome,
  library-gap findings, rulings); the amendment lines; STATUS (3b done on
  the branch, the resume line); commit `docs: 3b results, amendments and STATUS`.

- [ ] **Step 5 (controller):** the whole-branch Sonnet review, its one fix
  wave and re-review, the ledger archived onto the branch, then tell the
  human the demo runs on the new packages, and offer the merge menu.
