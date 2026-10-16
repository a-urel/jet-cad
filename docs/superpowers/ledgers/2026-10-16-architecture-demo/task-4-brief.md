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

