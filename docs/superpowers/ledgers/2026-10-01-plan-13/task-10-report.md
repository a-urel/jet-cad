# Task 10 report — App: Print… (spec D9, T-10 print half)

Commit: `6a726a9` feat(app): Print… (on 91b13ee). Not pushed.

## Files
- `apps/floor_planner/pubspec.yaml`: `printing: ^5.15.1` (resolves 5.15.1); **`pdf: ^3.13.1` as a direct dependency** (see misses); `flutter: ">=3.44.0"` (was 3.38.0) with its comment; `sdk:` unchanged (^3.5.0).
- `apps/floor_planner/macos/Runner/{DebugProfile,Release}.entitlements`: `com.apple.security.print` = true.
- `apps/floor_planner/lib/export/page_printer.dart` (new): `abstract interface class PagePrinter { Future<void> print(Uint8List pdf, String name, PdfPageFormat format); }`, `PrintingPagePrinter` -> `Printing.layoutPdf(onLayout: (_) async => pdf, name:, format:, dynamicLayout: false)`.
- `apps/floor_planner/lib/export/export_flow.dart`: `exportPdfBytes(document, page, fontBytes:)` (exportPagePdf with `exportOmitOwners`), now also Export → PDF's path; `printPageFormat(page)` = `PdfPageFormat(effW*72/25.4, effH*72/25.4)`.
- `apps/floor_planner/lib/document_host.dart`: `DocumentHost.printer` (default `const PrintingPagePrinter()`); `ShellCommand('print', 'Print…', Icons.print_outlined, kPrintChords)` after Export; `printFlow()` (busy, settle, page or return, one export, `printer.print(bytes, session name, printPageFormat(page))`, throw -> `_showError('Print failed', e)`).
- `apps/floor_planner/lib/main.dart`: `FloorPlannerApp.printer` (default `PrintingPagePrinter`) handed to the host. `kPageCommandIds` already had 'print' (Task 9), so `_fileEnabled` gates it on the page unchanged.
- `apps/floor_planner/lib/shell_commands.dart`: doc comment only.
- `apps/floor_planner/test/support/export_flat.dart` (new): Task 9's flow document and helpers moved out of export_flow_test.dart (fixtureBytes gains an optional `page:`; `_leaf` -> `addLeaf`; `distanceToSegment` -> `pdfDistanceToSegment`, the engine exports a `distanceToSegment`); pumpFlat gains `printer:`.
- `apps/floor_planner/test/support/fake_page_printer.dart` (new): records bytes, name, format; `failNext`.
- `apps/floor_planner/test/export/export_flow_test.dart`: imports the support file; tests unchanged (16 pass).
- `apps/floor_planner/test/export/print_flow_test.dart` (new, 8 tests).
- `apps/floor_planner/test/document_commands_test.dart`: DC12c floor 616 -> 656 (range 704..656); DC12b room name shortened (see misses).

Second commit: `3057e13` test(app): the production printer at printing's platform channel (PR8; test only, print_flow_test.dart).

## Dependencies and licences (pub cache LICENSE files)
Lock diff against the pre-task resolution (the same as f181afc's: no pubspec changed between f181afc and 91b13ee) adds exactly two packages:
| package | version | licence | evidence |
|---|---|---|---|
| printing | 5.15.1 | Apache 2.0 | `/root/.pub-cache/hosted/pub.dev/printing-5.15.1/LICENSE` "Apache License Version 2.0, January 2004", sha256 cc4d4de0…34e2 |
| pdf_widget_wrapper | 1.0.4 | Apache 2.0 | `…/pdf_widget_wrapper-1.0.4/LICENSE`, same text (same sha256 cc4d4de0…34e2) |
printing's other dependencies (pdf, http, image, meta, plugin_platform_interface, web, flutter_web_plugins) were already resolved before this task (pdf via the render package since Task 3); no new http dependency arrived. `pdf` became a direct dependency of the app (already resolved, 3.13.1, Apache 2.0, recorded in Task 3). The web build's `assets/NOTICES` lists `pdf`, `pdf_widget_wrapper` and `printing`. printing 5.15.1 declares `sdk >=3.12.0`, `flutter >=3.41.0`; the app's bound is >=3.44.0 for pdf's Dart 3.12 (R-13-7).

## Tests (print_flow_test.dart, 8 cases + Cmd/Ctrl = 9)
PR1 toolbar Print: printer called once, name `flat`, format 297 x 210 mm in pt (1e-9), font read once from the app's cache, nothing saved, busy cleared; printed content stream (reader, `zlib.decode`) operator list == an `exportPagePdf` computed in the test (its own separator set, vendored font), MediaBox equal and = format; premise: an un-omitted export differs and has a path at the separator; printed has none. PR2 A3 portrait page (297 x 420): format and MediaBox, operator lists equal. PR3 throwing printer -> "Print failed" with its text, busy while up. PR4 no page: button disabled, Ctrl+P and the flow itself print nothing. PR5 disabled while a held Save As runs (button, Cmd+P), enabled after. PR6 Cmd+P / Ctrl+P print once. PR7 order export, print; label, icon, chords; button right of Export. PR8 `PrintingPagePrinter` driven through printing's method channel `net.nfet.printing` (printPdf -> onLayout -> onCompleted): name, width/height, `dynamic: false`, onLayout (asked for A4 portrait) returns the given bytes, completes only after onCompleted.

## Gates (real tails, tip 6a726a9; PR8 commit 3057e13 re-ran the app's print test, analyze and format)
- Engine `CI=true dart test`: `00:18 +1121 -2: Some tests failed.` (the 2 standing generate_document_test failures); `dart analyze`: `No issues found!`; format: `Formatted 160 files (0 changed)`, exit 0.
- Render `CI=true flutter test`: `01:01 +1154 ~1 -7: Some tests failed.` (the 7 standing text-ladder goldens, unchanged count); analyze `No issues found! (ran in 3.6s)`; format `Formatted 200 files (0 changed)`, exit 0.
- App `CI=true flutter test`: `03:28 +925: All tests passed!` (917 + 8 at 6a726a9; PR8 adds 1 -> 926: `00:06 +9: All tests passed!` for the file); analyze `No issues found! (ran in 2.1s)`; format `Formatted 163 files (0 changed)`, exit 0.
- `CI=true flutter build web --release`: `✓ Built build/web`.
- dev_harness_2d `flutter pub get` + `flutter analyze`: `No issues found! (ran in 2.3s)`.
- Allocation invariant tests untouched; `packages/jet_cad/analysis_options.yaml` not staged; lock files untracked.

## Mutants (cp backup, one edit, test/export/print_flow_test.dart in the foreground, cp back, diff exit 0 -> restored=0 each)
| id | file | mutation | red | real output |
|---|---|---|---|---|
| V (M-13v) | lib/document_host.dart printFlow | prints a second `exportPagePdf(..., omitOwners: const {})` | PR1, PR2 | `Expected: [ Actual: [` (operator lists) `00:07 +7 -2` |
| AB (M-13ab) | lib/export/export_flow.dart printPageFormat | returns `PdfPageFormat.standard` | PR1, PR2 | `Expected: a numeric value within <1e-9> of <841.8897637795277>  Actual: <595.275590551181>` |
| W (print enabled without a page) | lib/shell_commands.dart | `kPageCommandIds = {'export'}` | PR4 | `Expected: false  Actual: <true>` |
| T (printer twice) | lib/document_host.dart | a second `printer.print(...)` | PR1, PR2, PR6 x2 | `Expected: an object with length of <1>  Actual: [Instance of 'PrintCall', Instance of 'PrintCall']` |
| E2 (exports twice, prints once) | lib/document_host.dart | an extra `await exportPdfBytes(...)` discarded | **survived** | `00:06 +9: All tests passed!` — equivalent by observation: the export is pure (T-9), the font cached; only time differs. No seam counts exports. |
| O1 (own) | export_flow.dart | `widthMm`/`heightMm` instead of effective | PR1 | `Actual: <595.2755905511812>` |
| O2 (own) | document_host.dart | name `'Document'` | PR1, PR6 | `Expected: 'flat'  Actual: 'Document'` |
| O3 (own) | document_host.dart | title `'Export failed'` | PR3 | `Expected: 'Print failed'  Actual: 'Export failed'` |
| O4 (own) | document_host.dart | `exportPageOf(document) ?? PageComponent()` | PR4 | `Expected: empty  Actual: [Instance of 'PrintCall']` |
| O5 (own) | lib/main.dart | app does not hand `printer` to the host | PR1 | `Expected: an object with length of <1>  Actual: []` (first run on the whole file hung on a later test with the real channel; killed, restored, re-fired on PR1 with `--timeout 60s`) |
| O6 (own) | lib/export/page_printer.dart | `dynamicLayout: true` | PR8 | `Expected: false  Actual: <true>` |
| O7 (own) | page_printer.dart | `format:` dropped | PR8 | `Expected: <1190.5>  Actual: <595.275590551181>` |
| O8 (own) | page_printer.dart | onLayout returns `Uint8List(0)` | PR8 | `Expected: [  Actual: []` |

## Plan / spec misses and decisions
- **`pdf` as a direct app dependency.** `PdfPageFormat` (in the PagePrinter signature the plan fixes) is not re-exported by `package:printing/printing.dart`, and importing `package:pdf` without depending on it trips `depend_on_referenced_packages`. Added `pdf: ^3.13.1` (the render package's bound; nothing new resolves). The brief said "printing only" in effect; this is the closest thing.
- **DC12c floor 616 -> 656 px** (measured: 704..656 pass, 655 overflows by 1.00 px), as R-13-23 predicted.
- **DC12b also moved (not predicted).** At 1440 x 900 the room notice 'Room — Already a room: the living room by the bay' (698.25 px intrinsic) no longer fits the status slot (666.5 px, 40 px less than with eight buttons); the room name is now 'the big living room', which fits and still needs more than half the shared width. A layout consequence for the human's look: a longer status line is cut ~40 px sooner on a wide window.
- Task 9's helpers moved to `test/support/export_flat.dart` (export_flow_test.dart edited: imports and `_leaf` -> `addLeaf`); a parallel Task 9 review fix touching that file may conflict textually.
- The flow is ordered as Export: settle, page, then font read and export inside the try (a font read failure shows "Print failed").
- E2 survives as equivalent (recorded above). PR8 relies on printing 5.15.1's private channel protocol; a printing upgrade may need it adjusted.
- The web's print goes through printing's web implementation (browser print of the PDF); L-6 is the human's.

## Task 10b (review findings 1 and 2)

Commit: `ff85f02` test(app): Print settles first and is busy over the print dialog (Task 10 review), on 7f81838. Test only: `test/export/print_flow_test.dart`, `test/support/fake_page_printer.dart`. Not pushed. (An earlier local `769c317` was amended into ff85f02 after the first PR10 let the timeout mutant through; see below.)

- `FakePagePrinter` gains `hold` (bool) and `held` (one `Completer<void>` per call, awaited after recording), as its comment promised.
- PR9 (finding 1): Text tool on the sheet at (9000, 2000), 'Mutfak' typed without Enter (premise: not in the codec output), Cmd+P handled; the printed `textRuns` are `{'Yatak Odası', 'Mutfak'}` and the document now contains 'Mutfak'.
- PR10 (finding 2): with `hold`, tap Print; premise one held call; the test pumps 30 s (the dialog stays up); busy true, Print/Save/Export disabled, Cmd+P prints nothing more; complete the call; busy false, all three enabled.

Mutants (scratch e10b, cp backup, one edit, print_flow_test.dart with `--timeout 120s`, cp back, diff exit 0):
| id | mutation (lib/document_host.dart printFlow) | red | real output |
|---|---|---|---|
| B10s | `_settlePendingInput();` removed | PR9 | `Expected: equals ['Yatak Odası', 'Mutfak'] unordered  Actual: ['Yatak Odası']`, `00:07 +10 -1` |
| B10a | print not awaited (`unawaited(...catchError(_showError))`) | PR3, PR10 | `Expected: true  Actual: <false>`, `00:07 +9 -2` |
| B10z | `.timeout(Duration.zero, onTimeout: () {})` on the print | first PR10 (no time passing): **survived** `00:05 +11: All tests passed!` — the zero timer had not yet had a pump to fire before the busy checks. PR10 now pumps 30 s with the dialog held; re-fired (B10z2): red PR10 `Expected: true  Actual: <false>`, `00:06 +10 -1` |
All restored=0.

Gates at ff85f02: app `CI=true flutter test` `03:13 +930: All tests passed!` (this commit adds PR9 and PR10; the base 7f81838 was not run separately here); `flutter analyze` `No issues found! (ran in 2.0s)`; `dart format` `Formatted 163 files (0 changed)`, exit 0. lib/ and packages untouched (test-only), so engine, render and web build are unchanged and not re-run.
