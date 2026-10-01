# Task 9 report — App: Export… (spec D8, T-10 export half)

Commits: `1e26b85` feat(app): Export… (on f181afc); `91b13ee` fix(app): Export dialog relies on its route for Escape; EX9 does not wait on a wrong dialog. Not pushed.

## Files
- `apps/floor_planner/lib/export/export_dialog.dart` (new): `ExportFormat {pdf, png}`, `ExportChoice(format, dpi)` (`initial` = PDF, 150), `showExportDialog(context, initial)`; SegmentedButtons (PNG shows the dpi row), Export / Cancel; Escape cancels through the dismissible route (the explicit binding of 1e26b85 was dead, mutant J, removed in 91b13ee). Keys: `export-dialog`, `export-format`, `export-format-pdf|png`, `export-dpi`, `export-dpi-96|150|300`, `export-ok`, `export-cancel`.
- `apps/floor_planner/lib/export/export_flow.dart` (new): `exportPageOf(doc)` (root PageComponent or null), `exportOmitOwners(doc)` = `liveObjectsOf<SeparatorParams>(doc).toSet()`, `exportFileKind`, `exportFileName`, `exportBytes(doc, page, choice, fontBytes:)` (PDF via `exportPagePdf`, compress default; PNG via `exportPagePng(dpi:)`). Pure helpers; Task 10's print can reuse them.
- `apps/floor_planner/lib/document_host.dart`: `ShellCommand(id: 'export', label: 'Export…', icon: Icons.ios_share_outlined, shortcuts: kExportChords)` after Save As; `exportFlow()` (busy, settle, page from the document or return, dialog on `_lastExport`, `saveLocation('<name>.pdf|png', kind:)`, export, `write(..., kind:)`, any throw -> `_showError('Export failed', e)`); `_exportFont = widget.exportFont ?? ExportFontCache()` (a bare host works); `_lastExport` in host state (survives a document swap).
- `apps/floor_planner/lib/shell_commands.dart`: `kExportChords` (Cmd/Ctrl+E), `kPrintChords` (Cmd/Ctrl+P), both in `kFileChords`; `kPageCommandIds = {'export', 'print'}`.
- `apps/floor_planner/lib/main.dart`: `_fileEnabled` gives a command whose id is in `kPageCommandIds` a `DerivedFlag` over `[c.enabled, ..._idleSources, _page]` computing `c.enabled.value && _idle && _page.value != null`.
- `apps/floor_planner/test/export/export_flow_test.dart` (new, 16 tests EX1-EX14 incl. Cmd/Ctrl variants).
- `apps/floor_planner/test/document_commands_test.dart`: DC12c's measured top-bar floor moved 576 -> 616 px (range 624..576 -> 664..616). See "plan misses".

## Decisions
- Order: dialog -> saveLocation -> export -> write (the plan's order; the export is not computed if the save is cancelled). A throw from saveLocation also shows "Export failed".
- The last choice is stored when the dialog returns a choice, even if the save is then cancelled.
- The font cache is read only for a PDF.
- The test fixture document: built with `prepareDocument` + `installParametric` + a real separator (`addSeparator` from room_fixture, in a turned group), a definition (basePoint (120,45)) with two BYBLOCK lines, an instance at translation (7000,5600), 30 deg, scale (1.5,-0.75), red, 0.70 mm; a "Yatak Odası" label so the PDF embeds the font; page A4 landscape 1:50 at (3000,-1500), background 0xFF303030. Saved by the codec and opened through the app's Open flow (`flat.jetplan`). The screen camera is then set to 400 % (premise asserted on the zoom text, `1:50 · 400%`) and panned ~60 m / 90 m off the sheet.
- R-13-13 checked: compress:true output from the app flow parses with the P-2 reader (`zlib.decode`); EX1 and EX14 do so.

## Tests (export_flow_test.dart, 16 cases)
EX1 PDF flow: `flat.pdf`, kind pdf, location; font read once from the injected cache (vendored file via `File`); reader parses compress:true output with `zlib.decode`; MediaBox A4 landscape in pt; text run "Yatak Odası"; the instance's line starts at its page-camera position within 1e-2 pt, strokes red, device width 0.70 mm in pt; no vertex of any path within 1 pt of the real separator's segment (premises: one live separator, its generated dashed polyline). EX2 edit after export reaches the shell's SpatialIndex (forEachInRect finds the new line). EX3 PNG 300 dpi (runAsync polling): `flat.png`, kind png, 3508 x 2480, busy cleared. EX4 last choice (PNG 96) survives a cancelled save and a document swap; first is PDF/150. EX5 Cancel, EX6 Escape, EX7 null saveLocation write nothing. EX8 throwing write -> "Export failed" dialog, busy while up. EX9 no page: button disabled, Ctrl+E nothing, the flow called directly ends without a dialog. EX10 disabled while a held Save As runs (button and Cmd+E). EX11 Cmd+E / Ctrl+E open the dialog. EX12 with the dialog open Cmd/Ctrl+P and +E are handled, no exception, still one dialog, nothing asked or written. EX13 names/kinds. EX14 a bare DocumentHost (no exportFont) exports a PDF with the bundled font via rootBundle, named `Untitled.pdf`.

## Gates (real tails, tip 91b13ee)
App `CI=true flutter test`: `03:09 +917: All tests passed!` (901 + 16 new)
`CI=true flutter analyze`: `No issues found! (ran in 2.2s)`
`dart format --output=none --set-exit-if-changed .`: `Formatted 159 files (0 changed)`, exit 0
`CI=true flutter build web --release`: `✓ Built build/web`
Engine and render: unchanged (`git diff --stat f181afc HEAD -- packages/` empty), not re-run. Allocation invariant tests untouched. `packages/jet_cad/analysis_options.yaml` (pub get) not staged.

## Mutants (cp backup, one edit, test/export/export_flow_test.dart in the foreground, cp back, diff exit 0 -> `restored=0` for each)
| id | file | mutation | red | real output |
|---|---|---|---|---|
| A (M-13d at the flow) | lib/document_host.dart exportFlow | page = `PageComponent()` (default) instead of the document's | EX1 | `Expected: an object with length of <1>  Actual: []` (the instance start) |
| B (M-13w) | lib/main.dart _fileEnabled | `&& _page.value != null` dropped | EX9 | `00:07 +8 -1: T-10 enabled EX9 disabled with no page ... [E]` |
| C | lib/export/export_flow.dart | omit set `<Handle>{}` | EX1 | `Expected: empty  Actual: [` (vertices on the separator) |
| D | lib/shell_commands.dart | kExportChords out of kFileChords | EX12 Cmd and Ctrl | `Expected: true  Actual: <false>` |
| E | lib/shell_commands.dart | kPrintChords out of kFileChords | EX12 Cmd and Ctrl | `Expected: true  Actual: <false>` |
| F (I-3 / R-13-17) | lib/document_host.dart exportFlow | `SpatialIndex(document).dispose();` before the export, hooks not restored | EX2 | `Expected: [25]  Actual: []` |
| G | lib/document_host.dart | given cache ignored (`ExportFontCache()`) | EX1 | `Expected: <1>  Actual: <0>` (fontLoads) |
| H | lib/document_host.dart | `_lastExport = choice;` removed | EX4 | `Expected: Set:[ExportFormat.png]  Actual: Set:[ExportFormat.pdf]` |
| I | lib/document_host.dart | write without `kind:` | EX1, EX3 | `Expected: FileKind.pdf  Actual: FileKind.jetplan` |
| K | lib/export/export_flow.dart | PNG dpi ignored (default 150) | EX3 | `Expected: (3508, 2480)  Actual: (1754, 1240)` |
| L | lib/document_host.dart | error title 'Could not save' | EX8 | `Expected: 'Export failed'  Actual: 'Could not save'` |
| M | lib/document_host.dart | no fallback cache (`widget.exportFont!`) | EX14 | `Found 1 widget with key [<'document-error'>]` |
| N | lib/document_host.dart | `exportPageOf(document) ?? PageComponent()` | EX9 | first fired against 1e26b85's EX9: red only by the 10-minute timeout (`10:05 +8 -1: ... EX9 ... [E]`) since EX9 awaited the flow; EX9 fixed in 91b13ee, re-fired as N2: `Expected: no matching candidates  Actual: ... [<'export-dialog'>]`, `00:06 +8 -1` |
| J | lib/export/export_dialog.dart (1e26b85) | explicit Escape binding removed | **survived** | `00:08 +16: All tests passed!` — the dismissible route pops on Escape by itself; binding removed in 91b13ee |
| J2 | lib/export/export_dialog.dart (91b13ee) | `barrierDismissible: false` | EX6 | `Expected: no matching candidates  Actual: ... [<'export-dialog'>]` |

## Plan / spec misses and notes
- **DC12c (plan 12a's top-bar floor test) had to move.** It pins the narrowest width at which the top bar does not overflow (576 px with seven buttons). The Export button is 40 px wide (measured: at 615 px the bar overflowed by 1.00 px, as 575 did before), so the floor is now 616 px and the range 664..616. The plan's file list for Task 9 did not name `test/document_commands_test.dart`. **Task 10's Print button will move it again by 40 px (to 656).**
- M-13d "at the flow" is expressible only as the flow passing a page other than the document's (A); handing in the screen camera is impossible by the API (as the plan says).
- The flow re-reads the page in the host (`exportPageOf`), and the shell's flag gates the button/chord; both are tested separately (B and N).
- `kPrintChords` is in kFileChords now but bound to no command until Task 10: Cmd/Ctrl+P is consumed above the Navigator and does nothing yet at the shell (the shell does not bind it).
- EX1's point tolerance is 1e-2 pt (not the derived 5-decimal bound): this test is about the flow's page and camera, the precision is T-3/T-5's; any wrong page or camera moves the point by metres.
- The screen camera at 400 % is set after the open (PlannerView's initial fit has already run); the zoom text `1:50 · 400%` is asserted as a premise.

## Task 9b (review follow-up, test-only)
Commit: `7f81838` test(app): Export settles first, follows the page, is busy over its dialog (Task 9 review), on 3057e13. Not pushed. Only `apps/floor_planner/test/export/export_flow_test.dart` changed (helpers from Task 10's `test/support/export_flat.dart`).
- Finding 1: **EX2b**: aim the camera at (9000, 2000) on the sheet, T, click, type `Mutfak` without Enter (premise: not in the codec string), Cmd+E (handled), Export. Then the PDF's text runs are `['Yatak Odası', 'Mutfak']` (unordered) and the document's codec string contains `Mutfak`.
- Finding 2: **EX9b**: start from the pageless flat (Export and Print disabled), then `attachPage(doc, flatPage())`, undo, redo. After each step it runs pump(), pump(100 ms), pump() and checks both buttons: (true, true), then (false, false), then (true, true).
- Finding 3: **EX5** asserts `busy` is true while the dialog is up.

Gates (real tails): app `CI=true flutter test`: `05:46 +928: All tests passed!`; `flutter analyze`: `No issues found! (ran in 2.8s)`; format `Formatted 163 files (0 changed)`, fmt=0. lib/ untouched, so no web build was needed (none run). Engine and render unchanged.

Mutants (scratch e9b; cp backup, edit, run the file, cp back, diff exit 0):
| id | mutation | red | real output |
|---|---|---|---|
| R2 | `_settlePendingInput();` removed from exportFlow | EX2b | `Expected: equals ['Yatak Odası', 'Mutfak'] unordered  Actual: ['Yatak Odası']`; restored=0 |
| R5 | `_page` dropped from the page commands' DerivedFlag sources (main.dart) | EX9b | `Expected: (bool, bool):<(true, true)>  Actual: (bool, bool):<(false, false)>`; restored=0 |
| R6 | the reviewer's R6.py: settle, page and dialog outside `_flow` | EX5 | `Expected: true  Actual: <false>`, `EX5 busy while the dialog is up ... [E]`; restored=0 |
Findings 4-6 (info) were not acted on. Note on finding 6: the fixture's basePoint (120, 45) is not read by the engine or the renderer, so it is not a coverage trait.
