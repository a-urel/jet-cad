# Task 9 review — App: Export… (commits 1e26b85, 91b13ee; range f181afc..91b13ee)

Reviewer: independent, detached worktree `.claude/worktrees/plan-13-review2` at 91b13ee.
Read: CLAUDE.md; spec 13 D8, D9 (enabled), D11, T-10, I-1..I-5, L-7, R-8; plan 13 Task 9; common.md;
progress.md R-13-17/-20/-21/-23; task-9-brief.md, task-9-report.md; spec 12a D6.
Scratch: `scratchpad/r9/` (mutant backups, logs, the probe test `zz_review_probe_test.dart`).

## Gates (run by the reviewer at 91b13ee)

- App `CI=true flutter test`: `04:13 +917: All tests passed!` (901 + 16, as reported)
- `CI=true flutter analyze`: `No issues found! (ran in 2.6s)`
- `CI=true dart format --output=none --set-exit-if-changed .`: `Formatted 159 files (0 changed)`, `fmt=0`
- `CI=true flutter build web --release`: `✓ Built build/web`
- Engine and render unchanged: `git diff --stat f181afc 91b13ee -- packages/` prints nothing. `git status`
  shows only ` M packages/jet_cad/analysis_options.yaml` (pub get; not committed).

## 1. Flow against D8

`document_host.dart:523-543`. `_flow` (busy for the whole span, the dialog included), then `_settlePendingInput()`,
then the page read from the document root (`exportPageOf`, `export_flow.dart:19-22`); with no page it returns
with no effect. Then dialog -> `saveLocation('<name>.pdf|png', kind:)` -> `exportBytes` -> `write(..., kind:)`.
A cancel in the dialog or a null `saveLocation` returns before `write`. Any throw from saveLocation, export or
write shows `_showError('Export failed', e)`, awaited, so busy stays set while the error is up (EX8).
`_lastExport` is a field of `DocumentHostState` (`home:` of the MaterialApp, which outlives document swaps),
held in memory only and not persisted. Correct.

The async gap: `document` and `page` are captured once, before the dialog. While busy, nothing can swap the
document: New, Open and Open sample are idle-gated flows, and `_onExitRequested` cancels while busy. So
`document` is still `_session.document` at export time, and the bytes are the current document's. The
document's **content** is read when `exportBytes` runs (after `saveLocation`), but the **page** was read
before the dialog. Spec 12a D6 keeps the canvas live while busy, but the Export dialog and the web name prompt
are modal Flutter routes, and the macOS save panel is window-modal. So in practice the page cannot change in
the gap. See finding 4. No `identical(_session.document, …)` check is needed because Export writes nothing back
to the session (no save point, no name).

## 2. Enabled

`main.dart:550-556`: for ids in `kPageCommandIds` (`shell_commands.dart:61`), a `DerivedFlag` over
`[c.enabled, ..._idleSources, _page]` computing `enabled && _idle && _page.value != null`. `_idle` includes
busy. `PageNotifier` refreshes on any command or undo/redo that touches the root. The reviewer's probe P2
(attach a page through `SetComponentCommand`, then undo and redo) passes on clean code: Export goes enabled,
disabled, enabled. **No committed test covers it:** mutant R5 (drop `_page` from the sources) survives the
task's test file. See finding 2.

## 3. Shortcuts

`kExportChords` (Meta/Ctrl+E) and `kPrintChords` (Meta/Ctrl+P) are in `kFileChords`
(`shell_commands.dart:50-57`), which is consumed above the Navigator (`main.dart:156-158`). EX12 shows Cmd/Ctrl+P
and +E handled with the dialog open (mutant D is red). Conflict check: no other binding uses `keyE`
(the grep of `apps/floor_planner/lib` and `packages/jet_cad_2d_flutter/lib` finds only `shell_commands.dart:31`).
There is no E tool letter. Bare P is the Polyline letter, and `SingleActivator` matches modifiers exactly, so
Ctrl+P does not clash with it. Until Task 10, Ctrl+P on the home route bubbles to the consume-only binding and
does nothing. Browser side: Chrome's Ctrl+E (omnibox search) and Ctrl+P can both be prevented, and they are
consumed because the key is handled. L-7 is the human's check.

## 4. DC12c / R-13-23

A legitimate consequence of the 8th toolbar button, not a regression of the layout logic. Verified
independently: widening DC12c's loop to 615 px makes it fail with
`A RenderFlex overflowed by 1.00 pixels on the right.` / `615 px` (test restored, `restored=0`). A floor of
616 px (656 after Task 10) is acceptable for a desktop/web planner. The 800 px test surface and any realistic
desktop window are wider. No macOS minimum window size is set, so a deliberately narrowed window would overflow
(as at 576 before). See finding 5.

## 5. Tests

The fixture is not degenerate. The page is A4 landscape 1:50 at (3000, -1500) with a dark background. There is
a real separator (`addSeparator`, in a group turned 0.1 rad and translated), and the premises assert one live
separator with a dashed polyline. The instance is at (7000, 5600), turned 30 degrees and scaled (1.5, -0.75),
with red and 0.70 mm overrides. The label uses Turkish letters. The file is opened through the app's Open flow.
The camera is at 400 % (premise on the zoom text) and translated about 60 m / 90 m off the sheet. The PDF is
parsed by `PdfContent.parse(..., inflate: zlib.decode)`. The expected position (`toPdf`) is computed
independently of `pageCamera`: (world - origin) · 72/25.4/50. EX2 queries `viewOf(tester).index`, which is the
shell's own `SpatialIndex` (`main.dart:263`, passed to `PlannerView.index`), not a fresh one, and mutant F turns
it red. One aside: `Definition.basePoint (120, 45)` is never read by the engine or the renderer, so it adds no
coverage (finding 6).

## 6. Mutants (reviewer-fired; cp backup, one edit, `test/export/export_flow_test.dart` in the foreground unless noted, cp back, `diff` exit 0 -> `restored=0` for every one)

| id | file | mutation | result | real output |
|---|---|---|---|---|
| A | lib/document_host.dart:526 | `exportPageOf(document) == null ? null : PageComponent()` | red EX1 | `Expected: an object with length of <1>` / `Actual: []`; `00:08 +15 -1: Some tests failed.` |
| B (M-13w) | lib/main.dart:554 | `&& _page.value != null` dropped | red EX9 | `Expected: false  Actual: <true>`; `00:06 +8 -1: T-10 enabled EX9 … [E]` |
| C | lib/export/export_flow.dart:27 | omit set `<Handle>{}` | red EX1 | `Expected: empty  Actual: [` |
| D | lib/shell_commands.dart:55 | `...kExportChords,` removed from kFileChords | red EX12 Cmd and Ctrl | `Expected: true  Actual: <false>`; `00:08 +14 -2: Some tests failed.` |
| F | lib/document_host.dart:536 | `SpatialIndex(document).dispose();` before `exportBytes` | red EX2 | `Expected: [25]  Actual: []` |
| I | lib/document_host.dart:539 | `write` without `kind:` | red EX1, EX3 | `Expected: FileKind:<FileKind.pdf>  Actual: FileKind:<FileKind.jetplan>` (and `.png`) |
| K | lib/export/export_flow.dart:57 | PNG `dpi:` dropped | red EX3 | `Expected: (int, int):<(3508, 2480)>  Actual: (int, int):<(1754, 1240)>` |
| N2 | lib/document_host.dart:526 | `exportPageOf(document) ?? PageComponent()` | red EX9 | `Expected: no matching candidates  Actual: _KeyWidgetFinder:<Found 1 widget with key [<'export-dialog'>]` |
| R1 (own) | lib/document_host.dart:524-526 | the page read **before** the settle | survives (equivalent) | `00:08 +16: All tests passed!`. The settle cannot change the root's page: an unsubmitted scale is re-synced, never committed (`main.dart:626-632`). |
| R2 (own) | lib/document_host.dart:524 | `_settlePendingInput();` removed | **survives** the task's file; red on the reviewer's probe P1 | `00:07 +16: All tests passed!`; probe: `Expected: contains 'Mutfak'  Actual: ['Yatak Odası']` |
| R3 (own) | lib/document_host.dart:256,528,530 | last choice per document (`Expando<ExportChoice>` keyed by the document) | red EX4 | `Expected: Set:[ExportFormat:ExportFormat.png]  Actual: Set:[ExportFormat:ExportFormat.pdf]` |
| R4 (own) | lib/document_host.dart:535,539 | `if (place == null) return;` removed, write with `place?.location ?? '?'` | red EX4, EX7 | `00:07 +5 -2: T-10 cancel and failure EX7 a cancelled save writes nothing [E]` (`Expected: empty  Actual: [`) |
| R5 (own) | lib/main.dart:553 | `_page` dropped from the DerivedFlag's sources | **survives** the task's file; red on probe P2 | `00:08 +16: All tests passed!`; probe: `Expected: true  Actual: <false>` (`00:03 +1 -1: P2 … [E]`) |
| R6 (own) | lib/document_host.dart:523 | busy starts only after the dialog (dialog outside `_flow`) | **survives** the task's file; red on probe P3 | `00:08 +16: All tests passed!`; probe: `Expected: true  Actual: <false>` (`P3 busy while the Export dialog is up [E]`) |

The probe file (`scratchpad/r9/zz_review_probe_test.dart`, 3 tests) passes on clean code (`00:03 +3: All tests
passed!`). It was removed from the worktree afterwards, and `git status` is clean except for the pub-get
analysis_options.yaml.

## Verdict: Approved with notes

The flow, the gating and the chords are correct against D8. Every named mutant the brief and report list is red
when re-fired. The fixture is non-degenerate, and EX2 checks the shell's own index. Three behaviours of the flow
(settle, page-driven enablement, busy over the dialog) are correct but not pinned by any test. Each can be pinned
with a small test, already prototyped in the reviewer's probe.

## Findings

1. **Medium — settle before the export is untested** (`document_host.dart:524`; test gap in
   `test/export/export_flow_test.dart`). Mutant R2 (no settle) survives. In the app, an open text entry would
   then lose its focus to the dialog and be cancelled. The typed label is silently dropped from both the export
   and the document. Fix: add a test like probe P1. Put the camera on the sheet (`aimCamera`), open the Text
   tool, type `Mutfak` without Enter, press Cmd+E and then Export. Assert the PDF's text runs contain `Mutfak`.
   Optionally also assert the document has the text.
2. **Low — page attach/remove by undo/redo is untested for Export's flag** (`main.dart:553`). Mutant R5 (`_page`
   not a source) survives. Fix: add a test like probe P2. Start from the pageless flat, `attachPage(...)`, then
   check enabled; `undo()`, then check disabled; `redo()`, then check enabled. Note that the change stream needs
   `pump()`, `pump(100 ms)`, `pump()` before the button reflects it. Task 10 inherits the same flag for Print.
3. **Low — busy over the dialog is untested** (`document_host.dart:523`). Mutant R6 (dialog outside `_flow`)
   survives. With R6, an app-exit request while the dialog is up would not be cancelled (12a S-17). Fix: one
   line in EX5 after `openDialog`: `expect(sessionOf(tester).busy.value, isTrue)`.
4. **Info — the page is read before the dialog, the content after `saveLocation`**
   (`document_host.dart:525-537`). The two cannot differ in practice: the dialog and prompts are modal, and no
   swap is possible while busy. If wanted, re-read `exportPageOf(_session.document)` right before `exportBytes`
   (returning when null) so that page and content come from one synchronous moment. Mutant R1 (page before
   settle) is equivalent and needs no test.
5. **Info — DC12c's floor is 616 px (656 after Task 10)** (`test/document_commands_test.dart:988-1002`).
   Verified at 615 px: overflow by 1.00 px. Acceptable. Consider a macOS minimum window width at or above the
   floor in a later plan, or add "narrow the window to about 650 px" to the human's look list. Keep R-13-23 as
   recorded.
6. **Info — the fixture's `basePoint (120, 45)`** (`test/export/export_flow_test.dart:77`) is not read by the
   engine or the renderer (`Definition.basePoint` is unused outside `node.dart`), so it adds no coverage. The
   report should not count it among the non-degenerate traits. If a later plan makes instances honour
   basePoint, EX1's `toPdf(instanceTransform…)` will need it.

## Re-review (9b)

Commit `7f81838` (on 3057e13, after Task 10), checked out detached in `.claude/worktrees/plan-13-review`;
`flutter pub get` run first.

- **Test-only:** `git show --stat 7f81838`: `.../test/export/export_flow_test.dart | 85 +++++++++++++++++++++-`,
  `1 file changed, 82 insertions(+), 3 deletions(-)`. `git diff --stat 3057e13 7f81838 -- packages apps/floor_planner/lib`
  prints nothing. `git status`: only the pub-get ` M packages/jet_cad/analysis_options.yaml`.
- **The new tests:**
  - **EX2b (finding 1):** Text tool on the sheet, `Mutfak` typed without Enter. A premise checks that it is not in the
    codec string. Then Cmd+E (handled) and Export. Asserts that the PDF's text runs equal
    `['Yatak Odası', 'Mutfak']` (unordered) and that the codec string contains `Mutfak`.
  - **EX9b (finding 2):** from the pageless flat, `attachPage(doc, flatPage())`, then undo and redo. After each
    step it pumps three times and checks Export **and** Print. The undo step has a premise of
    `exportPageOf(doc) == null`.
  - **EX5 (finding 3):** asserts `busy` true while the dialog is up.
- **Mutants re-fired by the reviewer** (cp backup, one edit, `test/export/export_flow_test.dart` with
  `--timeout 120s`, cp back, `restored=0` each):

| id | mutation | result | real output |
|---|---|---|---|
| R2 | `_settlePendingInput();` removed from `exportFlow` (document_host.dart:539) | red EX2b | `Expected: equals ['Yatak Odası', 'Mutfak'] unordered  Actual: ['Yatak Odası']`; `00:14 +17 -1: Some tests failed.` |
| R5 | `_page` dropped from the page commands' DerivedFlag sources (main.dart:560) | red EX9b | `Expected: (bool, bool):<(true, true)>  Actual: (bool, bool):<(false, false)>`; `00:13 +17 -1` |
| R6 | settle, page and dialog outside `_flow` (scratchpad/r9/R6.py) | red EX5 | `Expected: true  Actual: <false>`; `EX5 busy while the dialog is up; … [E]`; `00:12 +17 -1` |

- **Gates at 7f81838:**
  - App `CI=true flutter test --timeout 120s`: `05:29 +928: All tests passed!` (928, as reported). It includes all of
    Task 9's earlier tests EX1..EX14, now on Task 10's `test/support/export_flat.dart` helpers: 18 tests in the
    file, all green.
  - `flutter analyze`: `No issues found! (ran in 5.1s)`.
  - Format: `Formatted 163 files (0 changed)`, `fmt=0`.
  - No lib/ change, so no web build was needed.

Findings 1-3 are closed. Findings 4-6 are info and remain open (no action required).

**Verdict (9b): Approved.** Task 9 as a whole (1e26b85, 91b13ee, 7f81838): **Approved.**
