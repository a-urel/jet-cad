# The document lifecycle (12a) — implementation plan

> **For agentic workers:** executed task by task, subagent-driven: a fresh
> implementer per task and an independent reviewer per task, then a final
> whole-branch review. Steps use checkbox (`- [ ]`) syntax.

**Goal:** the floor planner becomes a document application. It opens on an
empty document; New, Open, Open sample, Save and Save As work on macOS
(native panels, write in place) and on web (file picker, download); the
document is swapped at runtime; dirty state follows the undo position
against a save point; replacing or closing a dirty document asks; Undo and
Redo get buttons and Redo gets its shortcuts; one command table feeds a
toolbar and the shortcuts.

**Spec:** [docs/superpowers/specs/2026-09-30-document-lifecycle-design.md](../specs/2026-09-30-document-lifecycle-design.md),
**revision 4** (`2be9233`), with its Revision 2, 3 and 4 sections. Read it
whole before Task 1. It has 14 decisions (D1–D14), 10 rulings (R-1–R-10),
**32 named mutants** (M-12a-1 … M-12a-31, with M-12a-7b), and no open
question. It was reviewed independently three times (S-1–S-28, T-1–T-13,
U-1–U-8; the reviews are `.superpowers/sdd/spec-12a-review*.md` in the spec
worktree, copied into this plan's ledger). **The human approved it on
2026-09-30** ("onaylıyorum, planı yaz"). The human's decisions 1–9 are at
the top of the spec.

**Architecture:**
- **Engine** (`packages/jet_cad_2d`): `UndoStack` becomes transitions over
  `(command, returnsTo)` entries and `CommandDispatcher.stateId` appears
  (D3). Task 1; frozen after it.
- **Render layer** (`packages/jet_cad_2d_flutter`): `Tool.isMidShape`
  (D6), Task 2; frozen after it.
- **App** (`apps/floor_planner`): the set-up helper and the default page
  (D4), `registerAppComponents` (D8), `DocumentFiles` and its three
  implementations (D9), the host and the swap (D2, D5, D8), the command
  table, toolbar and shortcuts (D6, D7), the settle (D2), the replace and
  exit flows (D10, D11), the platform edits (D12).

**Tech stack:** Dart, Flutter 3.47.2 (`/root/flutter`); `package:test`,
`flutter_test`. **New dependencies:** `file_selector: ^1.1.0` and `web`
(already transitive) in the app only. **No `cross_file`** (R-6).

## Rulings made here rather than left to an implementer

- **P-1 (branch).** `plan-12a/document-lifecycle`, cut from
  `spec-12a/document-lifecycle` at the commit that adds this plan; worktree
  `.claude/worktrees/plan-12a`. Reviews in detached worktrees
  (`.claude/worktrees/plan-12a-review`). Merge is the human's (`--no-ff`).
  Push: the human authorized "gerektiğinde commit ve push et" on
  2026-09-30; reviewed commits are pushed to `origin/plan-12a/...`; `main`
  only after the human's merge.
- **P-2 (engine API change).** `UndoStack`'s public primitives (`push`,
  `takeUndo`, `pushRedo`, `takeRedo`, `pushUndoOnly`) are **removed**, not
  deprecated: nothing outside `CommandDispatcher` calls them (spec D3,
  verified by the first review). If a test of the engine calls them, it
  moves to the transitions.
- **P-3 (where the host's state lives).** A `DocumentSession`
  (`ChangeNotifier`, `document_host.dart`) owns the document, its measurer,
  name, location, save point, dirty notifier and busy flag. The stateful
  `FloorPlannerApp` owns the session and rebuilds `MaterialApp` (its
  `onGenerateTitle`) from a `ListenableBuilder` over it (spec D5, U-4);
  `DocumentHost` (in `home`) runs the flows, shows the dialogs and builds
  the keyed shell. Tests pump `FloorPlannerApp(files: fake, …)`.
- **P-4 (the seam's names).** `PlannerShell({Key? key, DraftDocument?
  document, List<ShellCommand> fileCommands = const [], ValueListenable<bool>?
  busy, String? documentName, ValueListenable<bool>? dirty, SnapSettings?
  snap, ShellSettleRegistrar? onSettle, Size? initialCamera…})`. A bare
  `PlannerShell(document: doc)` behaves as today plus Undo/Redo buttons and
  Redo's chords; a bare `PlannerShell()` builds **an empty document** (spec
  D4) through the helper — tests that relied on the flat pass
  `startupPlan(m)` (Task 5 migrates them). `onSettle` hands the host a
  `void Function()` that runs the shell's synchronous settle (spec D2).
- **P-5 (FakeDocumentFiles).** `test/support/fake_document_files.dart`:
  scripted `open` results (bytes, cancel, throw), `saveLocation` results,
  recorded writes, and `holdWrites` (each `write` returns a `Completer`'s
  future the test completes).
- **P-6 (fixtures).** Per spec's Testing preamble: every "did not change"
  test starts dirty with history from real tools, off-origin, shape ended;
  Redo fixtures have a redo stack; pointer-path toolbar tests on macOS with
  a mouse (`debugDefaultTargetPlatformOverride`, reset in `tearDown`).

## Global constraints

- CLAUDE.md's non-negotiables. Frame path untouched (nothing here runs per
  frame; the allocation tests stay green).
- `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
- Never `git checkout --` a `.dart` file; mutants by `cp` backup, mutate,
  run, `cp` back, `diff` exit 0. Each agent's scratch prefix under
  `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/`
  is named in its brief.
- Never commit `analysis_options.yaml`. Never synthesize output.
- Pure-Dart files stay pure (Ruling 11-2's grep): `dart:io` only in
  `document_files_io.dart`, `package:web` only in `*_web.dart`, behind
  conditional imports; `flutter build web --release` proves the web side,
  `flutter analyze` both.
- Commit trailers:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
  ```

## Gates (every task)

```sh
export PATH=/root/flutter/bin:$PATH
(cd packages/jet_cad_2d         && CI=true dart test ; CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd packages/jet_cad_2d_flutter && CI=true flutter test ; CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd apps/floor_planner          && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
```
Plus `CI=true flutter build web --release` in the app from Task 4 on.
Branch point (`main` `cac7765`): engine 1,095 + 2 standing
(`test/testing/generate_document_test.dart`); render 940 + 1 skip + 7
standing (`text_ladder` 1–5, `text_lod_ladder` 1–2); app 514.

## File structure

| File | Task |
|---|---|
| `packages/jet_cad_2d/lib/src/document/undo.dart` | 1 |
| `packages/jet_cad_2d/test/document/undo_state_test.dart` (new) | 1 |
| `packages/jet_cad_2d_flutter/lib/src/tool.dart`, `draw/placement_tool.dart`, `draw/text_tool.dart` | 2 |
| `packages/jet_cad_2d_flutter/test/…/mid_shape_test.dart` (new) | 2 |
| `apps/floor_planner/lib/new_document.dart` (new), `startup_plan.dart`, `parametric/catalog.dart` | 3 |
| `apps/floor_planner/lib/document_files.dart`, `document_files_io.dart`, `document_files_web.dart`, `document_files_stub.dart` (new); `pubspec.yaml`; `macos/Runner/*.entitlements` | 4 |
| `apps/floor_planner/test/support/fake_document_files.dart` (new) | 4 |
| `apps/floor_planner/lib/document_host.dart` (new), `main.dart` | 5, 6, 7, 8 |
| `apps/floor_planner/lib/shell_commands.dart`, `document_toolbar.dart` (new), `shortcut_guard.dart` | 6 |
| `apps/floor_planner/lib/text_entry_overlay.dart`, `page_panel.dart`, `selection_panel.dart` (settle hooks only) | 7 |
| `apps/floor_planner/lib/exit_guard.dart`, `exit_guard_web.dart`, `exit_guard_stub.dart` (new); `macos/Runner/MainFlutterWindow.swift` | 8 |
| `apps/floor_planner/test/document_*_test.dart` (new), `planner_shell_test.dart` (migrated) | 3–8 |
| `docs/superpowers/notes/2026-09-30-plan-12a-results.md` (new), spec amendments, `STATUS.md`, `roadmap/12-app-shell.md` | 9 |

---

### Task 1: Engine — the state identity (spec D3)

**Files:** `undo.dart`; new `test/document/undo_state_test.dart`.

- [ ] `UndoStack` entries become `({DraftCommand command, int returnsTo})`;
  add `int _state = 0`, `int _next = 0`, `int get state => _state`.
- [ ] Transitions (spec D3): `recordExecute(inverse)` (push
  `(inverse, _state)`, `_state = ++_next`, evict the oldest past `limit`,
  clear redo); `DraftCommand beginUndo()` (top entry's command, not
  popped); `commitUndo(DraftCommand redoInverse)` (pop; push
  `(redoInverse, _state)` on redo; `_state = popped.returnsTo`);
  `abortUndo()` (no change — kept as an explicit call so the dispatcher's
  shape stays take → apply → commit/abort); symmetric `beginRedo`,
  `commitRedo(undoInverse)` (does not clear redo, no eviction needed:
  `undo + redo ≤ limit` holds), `abortRedo`. `clear()` keeps `_state`.
- [ ] Remove `push`, `takeUndo`, `pushRedo`, `takeRedo`, `pushUndoOnly`
  (P-2). Rewrite `CommandDispatcher.execute/undo/redo` on the transitions;
  behaviour otherwise identical (same `DocChange`s, same order, same
  failure semantics: a throwing replay restores exactly).
- [ ] `CommandDispatcher.stateId => _history.state`, dartdoc per spec D3
  (opaque, equality within one dispatcher only, never reused, not moved by
  table edits, purge or the handle seed).
- [ ] Tests (non-degenerate: real `DraftDocument`, commands on entities off
  the origin): execute/undo/redo return ids exactly; edit, undo `==`
  pre-edit id; edit, undo, new edit never returns to the undone id (walk a
  long sequence and assert no id repeats except by undo/redo); eviction at
  `undoLimit: 3` never returns to an evicted state (undo to the bottom,
  compare against every id seen); **failed undo then undo** (edit A→B,
  `permissions = readOnly`, undo throws, id B, `permissions = all`, undo,
  id `==` A); the same for redo; `clearHistory`, `notifyLoaded`,
  `notifyPurged` keep the id; `undoDepth`, `canUndo`, `canRedo` unchanged
  in meaning (the existing undo tests stay green untouched).
- [ ] Mutants: **M-12a-5** (id from the top entry's identity), **M-12a-6**
  (id recomputed from depth; and eviction keeps a reachable id — both
  readings), **M-12a-14** (abort stamps the current id; redo variant too).
  Record red test and line.
- [ ] Gates (engine; render and app unchanged in count). Commit
  `feat(engine): the dispatcher numbers the states it moves between`.

### Task 2: Render layer — `Tool.isMidShape` (spec D6, U-1)

**Files:** `tool.dart` (base: `bool get isMidShape => false;`, dartdoc:
"part-way through a shape; the shell disables its commands"),
`placement_tool.dart` (`isMidShape => isPending`), `text_tool.dart`
(`isMidShape => false`, with a comment: its pending state is the open
entry, which the shell's flows commit — spec 12a D2). A notification
already fires on every pending change (review 3 checked `onPointerDown`,
Enter, `cancel`, `activate`); verify, do not add.
- [ ] Tests: each placement tool used by the app (Line, Polyline,
  Rectangle, Circle, Arc here; the app's Wall, Separator, Dimension, Box in
  Task 6) is mid-shape after its first click and not after Escape; Text is
  not mid-shape with an entry open; Select is never.
- [ ] Mutant: `TextTool.isMidShape => isPending` → red here (the app-level
  M-12a-28 is Task 7's).
- [ ] Gates; commit `feat(render): Tool.isMidShape`.

### Task 3: App — the set-up helper, the default page, the registration (spec D4, D8 register)

**Files:** new `new_document.dart`; `startup_plan.dart`;
`parametric/catalog.dart`.

- [ ] `registerAppComponents(ComponentRegistry r)` in `catalog.dart`:
  `PageComponent.register(r)` then `parametricCatalog.registerComponents(r)`.
  Dartdoc: call once per registry (a second `PageComponent.register` wipes
  a live page).
- [ ] `DraftDocument prepareDocument(TextMeasurer m)`: `DraftDocument.empty(
  measurer: m)`, `registerAppComponents(doc.components)`, `header.units =
  millimeters`, `ensureDashedLinetype(doc)`.
- [ ] `const kDefaultPage = PageComponent(originX: -7425, originY: -5250)`
  (or a function if the constructor is not const) and `DraftDocument
  newDocument(TextMeasurer m)`: `prepareDocument`, attach `kDefaultPage`
  through `execute`, `clearHistory()`.
- [ ] `startupPlan(m)` starts from `prepareDocument(m)` (its content and
  page unchanged: `startup_plan_test` stays green untouched, and its bytes
  are unchanged — assert by comparing `encodeToString` before/after in the
  task's report, not a new test). Its first-line comment corrected (D4).
- [ ] Tests (`test/new_document_test.dart`): the new document is empty of
  entities, `undoDepth == 0`, units millimetres, handle 6 holds DASHED,
  the page `==` the literal (M-12a-27 target), `encodeToString` succeeds
  and decodes back (with `registerAppComponents`) to an equal page; a
  decode of the sample's bytes with `registerAppComponents` has a live
  page and live walls, and with only one of the two registrations misses
  the other (the helper's contract; the host-level M-12a-7/7b tests are
  Task 5's).
- [ ] Mutant M-12a-27 (origin from the portrait size) red.
- [ ] Gates; commit `feat(app): the empty document and one registration`.

### Task 4: App — `DocumentFiles` (spec D9, D12 entitlements)

**Files:** `document_files.dart` (interface + conditional export of the
platform implementation: `document_files_stub.dart` default,
`document_files_io.dart` if `dart.library.io`, `document_files_web.dart`
if `dart.library.js_interop`); `pubspec.yaml`; the two entitlements files;
`test/support/fake_document_files.dart`.

- [ ] Interface per spec D9 (`open`, `saveLocation`, `write`,
  `writesInPlace`). Result records: `({String name, Uint8List bytes,
  Object? location})` and `({String name, Object location})`.
- [ ] macOS (`_io`): `openFile(acceptedTypeGroups: [jetplan])` →
  `readAsBytes`, name = base name, location = path; `getSaveLocation(
  acceptedTypeGroups: [jetplan], suggestedName: …)` → path **unchanged**
  (S-16); `write` = `File(path).writeAsBytes(bytes, flush: true)`;
  `writesInPlace` true.
- [ ] web (`_web`): constructed with the host's name prompt
  (`Future<String?> Function(String suggested)`, T-12); `open` through
  `file_selector` `openFile` (location null); `saveLocation` = prompt,
  empty/null → cancel, append `.jetplan` if missing; `write` = `Blob` →
  `URL.createObjectURL` → `HTMLAnchorElement(download: name).click()` →
  `URL.revokeObjectURL`; `writesInPlace` false.
- [ ] `pubspec.yaml`: `file_selector: ^1.1.0`, `web` (the version range
  `file_selector_web` already resolves). `flutter pub get`; commit the
  pubspec only (the lock is git-ignored — confirm; never
  `analysis_options.yaml`).
- [ ] Entitlements: `com.apple.security.files.user-selected.read-write`
  true in `Release.entitlements` and `DebugProfile.entitlements`.
- [ ] The fake (P-5), with its own small unit test.
- [ ] No test of the real implementations beyond analyze and the web
  build (they are thin; the human's look covers them). Gates **plus
  `flutter build web --release`**. Commit `feat(app): DocumentFiles for
  macOS and web`.

### Task 5: App — the session, the host, the swap, Open and Save (spec D2, D5, D8, D13)

The largest task. **Files:** new `document_host.dart`; `main.dart`;
`test/planner_shell_test.dart` (migrated); new
`test/document_host_test.dart`, `test/document_open_test.dart`,
`test/document_save_test.dart`.

- [ ] `DocumentSession` (P-3): document, measurer, name (`Untitled`),
  location, `savedState`, `ValueNotifier<bool> dirty`, `ValueNotifier<bool>
  busy`, the change subscription (cancelled and re-made per document,
  S-23), `replace(doc, measurer, {name, location})` (one notify; resets
  save point, name, location; schedules post-frame disposal of the old
  document and clearing of the old measurer, S-11, S-24), `markSaved(int
  id)` (recomputes dirty at once, T-13).
- [ ] `FloorPlannerApp` stateful: owns the session and the
  `DocumentFiles` (injectable: `FloorPlannerApp({DocumentFiles? files})`),
  `MaterialApp(onGenerateTitle: …)` rebuilt from a `ListenableBuilder`
  (U-4); `home: DocumentHost(session, files)`.
- [ ] `DocumentHost` builds `PlannerShell(key: ObjectKey(session.document),
  document: …, snap: hostSnap, documentName, dirty, busy, fileCommands,
  onSettle)`. The shell stops creating the document from `startupPlan`
  (a bare shell builds `newDocument`, P-4), stops owning and clearing a
  measurer, takes `SnapSettings` from outside when given and **does not
  dispose a passed one** (S-11).
- [ ] Flows (plain async methods here; Task 6 wraps them in the command
  table with busy; each flow in this task already sets busy in a
  `try/finally`, outermost only, T-8): `newFlow`, `openSampleFlow`,
  `openFlow` (pick → `utf8.decode` → `decodeString(…, measurer: fresh,
  registerComponents: registerAppComponents, diagnostics: list)` → swap;
  `catch (e)` any object → error dialog naming the file and
  `e.toString()`, clear the fresh measurer, nothing else changes, S-12),
  `saveStep`/`saveAsStep` returning `bool` (settle hook call — a no-op
  until Task 7 — then **capture `stateId` and encode in one synchronous
  block** (S-2), then `saveLocation` if needed, then `write`; success →
  `markSaved(captured)`, name/location updated; failure → error dialog,
  save point untouched; cancel → false). The replace dialog (D10) is
  Task 8's; here New/Open/Open sample replace unconditionally (Task 8
  inserts the dialog in front).
- [ ] Migrate `planner_shell_test.dart` (S-10): the flat assertions pump
  `PlannerShell(document: startupPlan(m))` (or the app + Open sample with
  the fake); a new case asserts the empty launch. Every other existing
  test file stays green untouched (bare shells keep their behaviour).
- [ ] Tests (spec's Testing, the parts owned here): launch (empty,
  untitled, clean, the literal page live: `PageNotifier.value`, zoom text
  `1:50 · …`, page panel shown); **round trips** (sample → Save As → Open →
  Save, bytes `==`, first bytes `== utf8.encode(encodeToString(sample))`
  computed in the test, S-9; from New with a wall and a room drawn far off
  the origin and the wall's group rotated through the rotation grip, T-10;
  a no-DASHED file, S-20); page after Open (S-1); catalog after Open (walls
  live, grips); **Open failures** from dirty with history (not UTF-8, not
  JSON, `[]`, `{"schemaVersion": 1}`, scale 0, a refused schema version,
  cancel — same document object, same depth, still dirty; six dialogs);
  **dirty** (edit/undo/redo/save/branch-cut), repeated **after an Open**;
  **encoded state** (write held, edit meanwhile → dirty, bytes pre-edit;
  also `writesInPlace: false`); failed and cancelled saves from dirty
  (still dirty; then a save writes: busy cleared); web-style Save on a
  titled document writes without a prompt; **swap hygiene** (old document
  `commands.isDisposed`, `expander`, `onAfterMutate`, `onBeforeMutate`
  null, `tables.debugListenerCount == 0`; new shell: empty selection,
  Select active, snap kept, F3 twice toggles).
- [ ] Mutants: M-12a-1, 2 (the save-then-exit half is Task 8's), 3, 4, 7,
  7b, 8, 13, 16, 17, 18, 19, 20, 21. Record each.
- [ ] Gates + web build. Commit `feat(app): the document session, Open and
  Save`.

### Task 6: App — the command table, the toolbar, the shortcuts (spec D6, D7)

**Files:** new `shell_commands.dart`, `document_toolbar.dart`; `main.dart`
(top bar, `CallbackShortcuts` from the table, Undo/Redo commands, the
above-Navigator consume-only binding in `MaterialApp.builder`);
`shortcut_guard.dart`; new `test/document_commands_test.dart`.

- [ ] `ShellCommand` per spec D6. The table: the host's five file
  commands (wrapping Task 5's flows; `enabled` = idle), the shell's Undo
  and Redo (`enabled` = idle and `canUndo`/`canRedo`; `run` = settle →
  re-read `canUndo`/`canRedo` → return if false (U-2) → dispatcher).
  **Idle** = not busy and not `tools.active.isMidShape` (listen to the
  `ToolController` and the busy notifier).
- [ ] Shortcuts: Meta and Ctrl variants of every chord everywhere, Ctrl+Y;
  the callbacks check `enabled` and do nothing when false (the binding
  stays, so the key is consumed, S-26). The existing meta/ctrl+Z bindings
  (`main.dart:398-399`) are replaced by the table's.
- [ ] Above the Navigator: a consume-only `CallbackShortcuts` for the file
  chords in `MaterialApp.builder` (U-3, R-10) — marks handled, runs
  nothing.
- [ ] `ShellShortcutGuard`: add Meta+Shift+Z, Ctrl+Shift+Z, Ctrl+Y.
- [ ] Toolbar (D7): `ExcludeFocus` + `TextFieldTapRegion` (the latter is
  Task 7's reason; add it here), seven `IconButton`s keyed
  `toolbar-<id>`, tooltips with `⌘`/`Ctrl` by `defaultTargetPlatform`, a
  gap before Undo; then the name with `•` (`Flexible`, ellipsis, tooltip
  `Edited` when dirty); the status line `Flexible` with ellipsis; OSNAP and
  zoom as now. A bare shell shows Undo/Redo only.
- [ ] Tests: buttons' enabled states (fresh, after edit, after undo);
  taps and chords (incl. Ctrl+Y) undo/redo one step; **mid-shape** (the
  app's Wall chain with a wall down: all buttons disabled, a tap on Undo
  leaves `undoDepth`; Escape → enabled) and the app tools' `isMidShape`
  (Wall, Separator, Dimension, Box after one click; Door/Window/Gap/Room
  never); **disabled means no call** (two edits, one undo, shape ended,
  write held: Cmd+Z, Cmd+Shift+Z, taps on Undo/Redo change nothing; second
  Cmd+S no second write); **text fields** (redo stack, panel field
  focused, each of the three redo chords: nothing changes); **above the
  dialogs** (a dialog up — use the Task 8 error dialog or any `showDialog`
  from the host — and the page panel's sheet dropdown open: Cmd+S handled,
  no write); **redo after settle** (lands fully in Task 7; here the
  re-read with a stubbed settle); tab title follows dirty; no overflow at
  800 × 600 with a long file name.
- [ ] Mutants: M-12a-9, 12, 15, 23, 24, 29 (with Task 7's settle if
  needed; else record in Task 7), 30, 31. Record each.
- [ ] Gates + web build. Commit `feat(app): the command table, toolbar and
  shortcuts`.

### Task 7: App — settling pending input (spec D2's settle, T-1, T-4, U-1)

**Files:** `main.dart` (the shell's `settlePendingInput`, registered with
the host through `onSettle`); `text_entry_overlay.dart` (expose the
controller's text to the settle or let the shell call the Text tool's
`finish(ctx)` directly — the shell owns `_text` and the `ToolContext`);
`page_panel.dart` (a re-sync hook: `_syncScale` reachable from the settle);
`selection_panel.dart` only if a hand-back hook is missing; new
`test/document_settle_test.dart`.

- [ ] `settlePendingInput()` (synchronous, never in a build): if the Text
  tool's entry is open, `finish(ctx)`; if a `PanelFieldFocusNode` has
  focus, `handBack()`; the page panel's scale re-syncs to the stored
  value; then `FocusManager.instance.applyFocusChangesIfNeeded()` (T-4).
  Every flow of Tasks 5, 6, 8 calls it first (Task 5 left the hook).
- [ ] Tests: selected wall off-origin, thickness typed without Enter,
  Cmd+S → bytes carry it, commit is its own step, clean after (S-19);
  text entry typed, Cmd+S → bytes contain the text, clean after; **the
  same through `toolbar-save` on macOS with a mouse** (T-1); unsubmitted
  page scale, Cmd+S → the field shows the stored scale after; redo after a
  settle (U-2: two edits, one undo, wall selected, thickness typed, tap
  Redo → committed, `canRedo` false, no `CommandRedone`); Undo with a
  typed value → the value is committed then undone (R-9).
- [ ] Mutants: M-12a-11 (no settle; and settle without
  `applyFocusChangesIfNeeded`), M-12a-22 (toolbar outside the tap region),
  M-12a-28 (`TextTool.isMidShape => isPending`: the toolbar Save is
  disabled), M-12a-29 if not recorded in Task 6.
- [ ] Gates. Commit `feat(app): flows settle pending input first`.

### Task 8: App — replacing and closing a dirty document (spec D10, D11, D12 Swift)

**Files:** `document_host.dart`; new `exit_guard.dart`,
`exit_guard_web.dart`, `exit_guard_stub.dart`;
`macos/Runner/MainFlutterWindow.swift`; new
`test/document_replace_test.dart`, `test/document_exit_test.dart`.

- [ ] The Save / Don't Save / Cancel dialog (default Save, Escape Cancel,
  keys `replace-save`, `replace-discard`, `replace-cancel`), in front of
  New, Open (before the picker) and Open sample when dirty after the
  settle; Save runs `saveStep` inside the outer busy span; success but
  dirty again (an edit during the held write) → ask again (T-8).
- [ ] `AppLifecycleListener(onExitRequested:)` owned by the host,
  disposed with it. Order (T-7): busy → cancel; settle; clean → exit; else
  the dialog (Save → exit if saved and still clean, else ask again or
  cancel on cancel/failure; Don't Save → exit; Cancel → cancel). A pending
  shape does not block (U-7).
- [ ] `ExitGuard` (`set armed(bool)`), armed exactly while dirty, re-bound
  per document; web: `beforeunload` listener calling `preventDefault()`
  and setting `returnValue`, removed when disarmed or disposed; stub: no-op.
  The host takes an injectable guard (a fake in tests).
- [ ] `MainFlutterWindow.swift`: `@objc func windowShouldClose(_ sender:
  NSWindow) -> Bool { NSApp.terminate(nil); return false }` with a comment
  citing spec 12a D11. Not buildable here; the human's look.
- [ ] Tests: replace flows (dirty + New → dialog; Cancel keeps all; Don't
  Save replaces; Save + cancelled save dialog keeps all, dirty; Save +
  success writes then replaces; clean → no dialog; Open: dialog before the
  picker); nested flows (dirty → New → Save with write held → Cmd+O,
  Cmd+S, buttons do nothing; complete → replaced; with an edit during the
  hold → asked again); exit through `tester.binding.handleRequestAppExit()`
  (clean → exit, no dialog; save then exit → exit, no dialog; dirty →
  Cancel/Don't Save/Save ok/Save fails; busy → cancel, no second dialog;
  clean but a panel value typed → the dialog appears); the exit guard
  armed exactly while dirty, across a swap.
- [ ] Mutants: M-12a-2 (the exit half), M-12a-10, 25, 26. Record each.
- [ ] Gates + web build. Commit `feat(app): ask before replacing or
  closing a dirty document`.

### Task 9: Mutation sweep, greps, results, amendments, STATUS

- [ ] Re-fire every named mutant (the 32) on the final tree; the
  assignment table below says where each was first fired. Any survivor is
  a finding: fix the test (not the mutant), re-fire, record.
- [ ] Greps: `dart:io` only in `document_files_io.dart`; `package:web`
  only in `*_web.dart`; no `cross_file`; `UndoStack`'s removed primitives
  nowhere; `startupPlan(` only in `new_document`/`startup_plan`/Open
  sample/tests; `parametricCatalog.registerComponents` only inside
  `registerAppComponents` and existing test decodes; no
  `Future.delayed(Duration.zero)` in `lib/`.
- [ ] Results note `docs/superpowers/notes/2026-09-30-plan-12a-results.md`:
  per task the commits, the reviews, the mutant table with red test and
  line, the gates, the found items, the human's look (macOS and web lines
  from the spec's exit gate).
- [ ] Spec amendments ("Amended at execution (Plan 12a)") where execution
  made the spec precise; spec 02's history note for P-2's API change; spec
  10 D3's "12's file-open path decides" answered (R-3).
- [ ] `roadmap/12-app-shell.md`: 12a done, what remains for later slices.
- [ ] STATUS: top and Resume here (executed, not merged). Gates of record.
- [ ] Commit `docs: plan 12a results, amendments, STATUS`; then the final
  whole-branch review; then the ledger archive as the branch's last commit.

## Mutant assignment

| Mutant | Task |
|---|---|
| M-12a-5, 6, 14 | 1 |
| (render: `TextTool.isMidShape => isPending`) | 2 |
| M-12a-27 | 3 |
| M-12a-1, 2 (save), 3, 4, 7, 7b, 8, 13, 16, 17, 18, 19, 20, 21 | 5 |
| M-12a-9, 12, 15, 23, 24, 30, 31 | 6 |
| M-12a-11, 22, 28, 29 | 7 |
| M-12a-2 (exit), 10, 25, 26 | 8 |
| all 32, re-fired | 9 |

## Exit gate

The spec's exit gate, plus: every task Approved by an independent
reviewer; the final whole-branch review Approved; the results note and
STATUS written; the ledger archived; engine, render and app gates green
(standing failures only), the web build green; the human's look on macOS
and on web recorded as pending in STATUS (the human's, not ticked here).

## Self-review

- Every spec decision has a task: D1 (5, 6), D2 (5, 7), D3 (1), D4 (3),
  D5 (5, 6), D6 (2, 6), D7 (6), D8 (3, 5), D9 (4), D10 (8), D11 (8),
  D12 (4, 8), D13 (5), D14 (9, recorded).
- Every named mutant has a task (table). The spec's Testing section's
  tests are each in a task's list.
- Risky seams: Task 5's keyed swap (hygiene test), Task 1's API change
  (P-2), Task 7's focus timing (T-4's synchronous settle), Task 8's native
  edit (human's look).
