# Task 10 review: App, Print… (spec D9, T-10 print half)

Reviewer: independent. Range `91b13ee..3057e13` (`6a726a9` feat(app): Print…, `3057e13` test(app): PR8). The review
ran in the detached worktree `.claude/worktrees/plan-13-review2` at `3057e13`, after a workspace `flutter pub get`.
Commit 9b (`7f81838`, plan-13 worktree) is out of scope. It is mentioned only where it bears on a finding.
`git status` after the review shows only the pub-get `packages/jet_cad/analysis_options.yaml`. Every mutant ended
with `restored=0`.

## 1. Dependencies

- **New vs 91b13ee.** I extracted `git archive 91b13ee` into scratch and ran `flutter pub get --offline` there,
  then diffed the two root `pubspec.lock` files. The only differences are two added transitive entries:
  `pdf_widget_wrapper 1.0.4` (sha256 c930860d…) and `printing 5.15.1` (sha256 0f72f29f…). No other package
  changed version. The report's "exactly two" is confirmed. Lock files are untracked (`git ls-files` lists no
  `pubspec.lock`).
- **Licences.** Both pub-cache `LICENSE` files read "Apache License Version 2.0, January 2004". Both have sha256
  `cc4d4de0…d7d1e34e2`, the same file.
- **printing 5.15.1 pubspec.** `sdk: ">=3.12.0 <4.0.0"`, `flutter: ">=3.41.0"`. Its deps are flutter,
  flutter_web_plugins, http, image, meta, `pdf ^3.13.0`, pdf_widget_wrapper, plugin_platform_interface and web.
  All except pdf_widget_wrapper were already resolved.
- **App pubspec.** `flutter: ">=3.44.0"` (was `>=3.38.0`) and `sdk: ^3.5.0` unchanged. The comment cites R-4,
  P-7 and R-13-7.
- **`pdf: ^3.13.1` as a direct dependency.** This is justified. `PdfPageFormat` appears in the `PagePrinter`
  signature that the spec and plan fix. It is imported in `page_printer.dart` and `export_flow.dart`. Without a
  direct dependency, `depend_on_referenced_packages` fires. The bound matches the render package's, and nothing
  new resolves (lock diff above).
- **Web NOTICES.** `CI=true flutter build web --release` gave `✓ Built build/web`. `build/web/assets/NOTICES`
  lines 1467-1469 are `pdf`, `pdf_widget_wrapper`, `printing` under the Apache 2.0 text (with `barcode`).
- **CDN at runtime.** The web print does not fetch anything from a CDN.
  - `printing_web.dart` does hold a pdf.js loader: `_pdfJsCdnPath = 'https://unpkg.com/pdfjs-dist'`, version
    6.2.108, loaded by a dynamic `import()` in `_initPlugin()`.
  - `_initPlugin()` is called only from `info()` (line 112) and `raster()` (line 304). The app calls neither.
  - Web `layoutPdf` (lines 121-233) calls `onLayout`, wraps the bytes in a `Blob` (`application/pdf`), loads it
    into a hidden iframe and calls `contentWindow.print()`. Off desktop Chrome/Safari/Firefox it falls back to
    `_getPdf` (a download).
  - In the release `main.dart.js`, `unpkg`, `pdfjs` and `pdf.min.mjs` occur 0 times, so the loader is
    tree-shaken. `__net_nfet_printing` occurs 7 times (the iframe path). The only `gstatic` hits are Flutter's
    own CanvasKit base URL, which was already there.
  - `PdfGoogleFonts` (`fonts.gstatic.com` URLs) is not reachable: the app imports `show Printing`.
  - Note for L-6: on the web, `layoutPdf` ignores `name` and `format`. Paper and orientation come from the
    browser's PDF viewer, which reads the MediaBox (correct per PR1/PR2).

## 2. Entitlements

Both `DebugProfile.entitlements` and `Release.entitlements` gain exactly `<key>com.apple.security.print</key><true/>`
(+2 lines each). Nothing else changed.

## 3. Code

- `PrintingPagePrinter.print` (`lib/export/page_printer.dart:26-30`) calls
  `Printing.layoutPdf(onLayout: (_) async => pdf, name: name, format: format, dynamicLayout: false)`, as in D9.
- `printPageFormat` (`lib/export/export_flow.dart:75-76`) is
  `PdfPageFormat(effectiveWidthMm*72/25.4, effectiveHeightMm*72/25.4)`, which uses the **effective** size.
- `printFlow` (`lib/document_host.dart:566-579`) does, in order:
  - `_flow` (busy over the whole span, including the error dialog and the awaited printer);
  - `_settlePendingInput()`;
  - reads the page, and returns if there is none or the host is unmounted;
  - inside the try: one `exportPdfBytes(document, page, fontBytes: await _exportFont.bytes)`, which is
    `exportPagePdf` with `exportOmitOwners(document)`, the same helper and font cache as Export → PDF;
  - `await widget.printer.print(bytes, _session.name, printPageFormat(page))`. The name falls back to
    `Untitled` (`document_host.dart:99-100`);
  - on any throw, `_showError('Print failed', e)`.

  A font read failure therefore also shows "Print failed", which is consistent with Export.
- The command (`document_host.dart:318-324`) is `ShellCommand('print', 'Print…', Icons.print_outlined,
  kPrintChords)` after Export. `kPageCommandIds` already held `'print'`, and `kPrintChords` is in `kFileChords`
  (R-8). The printer is injected through `FloorPlannerApp.printer` → `DocumentHost.printer`, defaulting to
  `const PrintingPagePrinter()`.
- **Export unchanged.** `exportBytes`'s PDF arm now goes through `exportPdfBytes`. The font is still read only in
  the PDF arm, after `saveLocation`. The PNG arm computes `exportOmitOwners` itself, so it behaves the same.
  `export_flow_test.dart`'s `main()` differs from 91b13ee only by `distanceToSegment` → `pdfDistanceToSegment`
  and `_leaf` → `addLeaf` (diff of the bodies). It has 13 `testWidgets` before and after, and all pass in the
  full suite.

## 4. Tests (`test/export/print_flow_test.dart`, 9 cases)

PR1 to PR8 cover T-10's print half:

| test | what it checks |
|---|---|
| PR1 | One call, name, format, MediaBox, operator lists equal to an independently computed `exportPagePdf`, and no separator path, with the premise that an un-omitted export does have one |
| PR2 | An A3 portrait page (non-A4) |
| PR3 | A throwing printer shows "Print failed", and busy holds while the error is up |
| PR4 | No page: the button, Ctrl+P and the direct flow all do nothing |
| PR5 | Disabled while busy |
| PR6 | Cmd+P and Ctrl+P each print once |
| PR7 | Order, label, icon, chords, and toolbar position |
| PR8 | `PrintingPagePrinter` at the method channel |

- Operator lists are compared, never bytes (R-1).
- The fixture is the non-degenerate flat from Task 9: page origin (3000, -1500) at 1:50, rotated and mirrored
  instance with overrides, a real separator, and the camera at 400 % and panned off.
- PR1's landscape A4 also kills the raw-size mutant, because `widthMm` 210 and `heightMm` 297 swap under
  landscape. PR2 alone would not, since a portrait page's effective size equals its raw size. Together they are
  fine.
- **PR8.** It drives printing 5.15.1's private protocol on `net.nfet.printing`: `printPdf` arguments, then
  `onLayout`, then `onCompleted`. This couples the test to a package internal, and a printing minor upgrade
  allowed by `^5.15.1` could change it. If that happens the test fails loudly, it does not pass silently. It is
  the only test of the production adapter and it kills `dynamicLayout: true`, a dropped `format`, and empty
  bytes (I re-fired the dropped `format`, below). **Acceptable**, with the fragility recorded (finding 4).

## 5. Edits to existing tests

`git diff --stat 91b13ee..3057e13 -- apps/floor_planner/test` lists five files:

- `document_commands_test.dart` (23 lines);
- `export_flow_test.dart` (helpers moved out, `main()` unchanged as shown above);
- three new files: `print_flow_test.dart`, `support/export_flat.dart`, `support/fake_page_printer.dart`.

**DC12c** (range 704..656, previously 664..616) is legitimate. I widened the loop to 655 and it went red with
`A RenderFlex overflowed by 1.00 pixels on the right.` (restored=0). So 656 px is the real floor, exactly 40 px
(one button) above Task 9's 616.

**DC12b** (room name `the living room by the bay` → `the big living room`) is legitimate. With the old name
restored at the tip, it goes red on `Expected: false  Actual: <true>`, which is the "the bar has room: the notice
is whole" check. The ninth button costs the status slot 40 px. The test's premises still hold with the new name:
the notice needs more than half the shared width and is cut once the long name arrives. The user-visible
consequence (a long status line is cut about 40 px sooner) is recorded in R-13-24.

## 6. Mutants (reviewer-fired)

Each mutant: cp backup to `scratchpad/r10`, one edit, `flutter test <file> --timeout 120s` in the foreground,
cp back, `diff` exit 0, `restored=0` every time.

| id | file | mutation | result | real output |
|---|---|---|---|---|
| M-13v | lib/document_host.dart:572 | print exports with `exportPagePdf(..., omitOwners: const {})` | red PR1, PR2 | `Expected: [ / Actual: [` (operator lists); `00:08 +7 -2: Some tests failed.` |
| M-13ab | lib/export/export_flow.dart:75 | `printPageFormat` returns `PdfPageFormat.standard` | red PR1, PR2 | `Expected: a numeric value within <1e-9> of <841.8897637795277>  Actual: <595.275590551181>`; `00:08 +7 -2` |
| W | lib/shell_commands.dart:61 | `kPageCommandIds = {'export'}` | red PR4 | `Expected: false  Actual: <true>`; `00:06 +8 -1` |
| T | lib/document_host.dart:574 | `printer.print` called twice | red PR1, PR2, PR6 Cmd, PR6 Ctrl | `Expected: an object with length of <1>  Actual: [Instance of 'PrintCall', Instance of 'PrintCall']`; `00:10 +5 -4` |
| R10a (own) | lib/export/export_flow.dart:76 | `widthMm`/`heightMm` instead of effective | red PR1 | `Actual: <595.2755905511812>`; `00:06 +8 -1` |
| R10b (own) | lib/document_host.dart:567 | `_settlePendingInput();` removed from printFlow | **survives** | `00:05 +9: All tests passed!` |
| R10c (own) | lib/document_host.dart:574 | print not awaited (`unawaited(...catchError(_showError))`) | red PR3 only | `Expected: true  Actual: <false>` "busy while the error is up"; `00:07 +8 -1` |
| R10d (own) | lib/document_host.dart:574 | `.timeout(Duration.zero, onTimeout: () {})` on the print: does not wait for a successful dialog | **survives** | `00:05 +9: All tests passed!` |
| E2 | lib/document_host.dart:572 | an extra discarded `exportPdfBytes` | survives | `00:06 +9: All tests passed!` |
| O7 (re-fire) | lib/export/page_printer.dart:29 | `format:` dropped | red PR8 | `Expected: <1190.5>  Actual: <595.275590551181>` |

**E2's "equivalent".** I agree it is equivalent by observation. `exportPagePdf` is pure (T-9: codec bytes and
`stateId` unchanged), and the font comes from the cache (PR1 asserts `fontLoads == 1`). The second export changes
nothing a user or the printer sees, only time. Killing it would need an export counter seam, which costs more
than it is worth.

**R10a** is the "raw instead of effective size" mutant from the brief. The other suggested own mutant, "the page
read before the settle", is equivalent here for the reason Task 9's review gave (R1). The settle cannot change
the root's page. I fired the stronger form instead: settle removed (R10b), which **survives**.

## 7. Gates (real tails, at 3057e13)

| gate | result |
|---|---|
| App `CI=true flutter test` | `05:40 +926: All tests passed!` (925 at 6a726a9 + PR8 = **926**, as the report says) |
| App `flutter analyze` | `No issues found! (ran in 6.5s)` |
| App `dart format --set-exit-if-changed` | `Formatted 163 files (0 changed)`, exit 0 |
| App `CI=true flutter build web --release` | `✓ Built build/web` |
| Engine `CI=true dart test` | `00:30 +1121 -2: Some tests failed.` (the 2 standing) |
| Render `CI=true flutter test` | `01:38 +1154 ~1 -7: Some tests failed.` (the 7 standing goldens, unchanged) |
| `dev_harness_2d` `flutter analyze` | `No issues found! (ran in 2.3s)` |
| `git diff 91b13ee..3057e13 -- packages` | 0 lines (engine and render unchanged) |

## Verdict: Approved with notes

D9 is implemented as specified: the flow, the seam, the production adapter, the entitlements and the bounds.
Exactly two Apache-2.0 packages are new. The web build fetches nothing from a CDN for print. Every named mutant
is red, and E2 is a fair equivalent. The DC12b and DC12c edits are forced by the ninth button and verified. Two
behaviours of the flow are correct but not pinned by a test.

## Findings

1. **Medium: Print's settle is untested** (`apps/floor_planner/lib/document_host.dart:567`; test gap in
   `test/export/print_flow_test.dart`). R10b (no settle) survives. This is the same gap as Task 9's finding 1. The
   9b commit (`7f81838`) pins Export's settle only. In the app, a label typed without Enter would be dropped from
   the print. Fix: add a PR test like 9b's settle test for Export: open the Text tool on the sheet, type a word
   without Enter, press Cmd+P, and assert the printed content's `textRuns` contain it.
2. **Low: busy over a successful print dialog is not pinned, and the fake's doc comment promises a `hold` it does
   not have** (`apps/floor_planner/test/support/fake_page_printer.dart:1-3`; `lib/document_host.dart:574`). R10d
   (do not wait for the printer) survives. R10c is caught only through the error path (PR3). On macOS,
   `layoutPdf` completes when the dialog closes, so with R10d Save/Open/Print would be live while the system
   dialog is up. Fix: give `FakePagePrinter` a `hold` (a `Completer` per call) and add a test that taps Print
   with hold set, asserts `busy` is true and Print and Save are disabled, then completes the call and asserts
   busy is false. Or drop the stale sentence from the comment and record the gap.
3. **Info: the web print ignores `name` and `format`** (printing 5.15.1 `printing_web.dart:121-233`: blob,
   hidden iframe, `print()`, with a download fallback off desktop Chrome/Safari/Firefox). Paper comes from the
   PDF's MediaBox through the browser's viewer. L-6 on the web checks exactly this. The pdf.js CDN loader is not
   reached (`info()` and `raster()` only) and is absent from the release `main.dart.js`. Nothing to fix. Worth a
   line in the results note.
4. **Info: PR8 couples to printing's private channel protocol** (`test/export/print_flow_test.dart:252-308`).
   Acceptable: it is the only check of the production adapter, and a printing upgrade would turn it red, not
   pass it silently. Keep the comment that names the version. Re-check it when printing is bumped.
5. **Info: DC12b and DC12c moved** (`test/document_commands_test.dart:932-936, 991-1010`). Both were verified as
   forced: 655 px overflows by 1.00 px, and the old room name is cut at the tip. The narrower status slot belongs
   in the human's look list, as R-13-24 says.

## Re-review (10b): `ff85f02` on `7f81838`

Worktree: `plan-13-review2`, detached at `ff85f02`. `git status` shows only the pub-get
`packages/jet_cad/analysis_options.yaml`.

**Test only.** `git show --stat ff85f02` changes two files:

- `test/export/print_flow_test.dart` (+65)
- `test/support/fake_page_printer.dart` (+16 -2)

`git diff --stat 3057e13 ff85f02 -- apps/floor_planner/lib packages` is empty.

**The fake's hold is sound.**

- `hold` and `held` are instance fields, and every test builds its own `FakePagePrinter`, so nothing is shared across
  tests.
- A held call records itself first, then awaits a completer that the test owns. PR10 completes it before it ends.
- The `failNext` path throws before the hold, so PR3 is unaffected.
- The doc comment now matches the code.

**PR9 (finding 1).** The test aims at (9000, 2000) on the sheet, opens the Text tool and types 'Mutfak' without
Enter. Its premise is that the codec output does not yet contain 'Mutfak'. After Cmd+P, the printed `textRuns` are
{label, 'Mutfak'} and the document contains 'Mutfak'.

**PR10 (finding 2).** With `hold` set, the test taps Print and checks that exactly one call is held. It then pumps
30 s and asserts:

- busy is true;
- Print, Save and Export are all disabled;
- Cmd+P does not start a second print.

It then completes the held call and asserts that busy clears and all three buttons are enabled again.

### Mutants

Fired on `lib/document_host.dart` printFlow. Method for each: cp backup, one edit, `flutter test
test/export/print_flow_test.dart --timeout 120s` in the foreground, cp back, `diff` exit 0. Every one ended
`restored=0`.

| id | mutation | result | real output |
|---|---|---|---|
| R10b | `_settlePendingInput();` removed | red PR9 | `Expected: equals ['Yatak Odası', 'Mutfak'] unordered  Actual: ['Yatak Odası']`; `00:06 +10 -1: Some tests failed.` |
| R10c | print not awaited (`unawaited(...catchError(_showError))`) | red PR3, PR10 | `Expected: true  Actual: <false>`; `00:06 +9 -2: Some tests failed.` |
| R10d | `.timeout(Duration.zero, onTimeout: () {})` on the print | red PR10 | `Expected: true  Actual: <false>`; `00:06 +10 -1: Some tests failed.` |

### Gates at ff85f02

| gate | result |
|---|---|
| App `CI=true flutter test` | `03:45 +930: All tests passed!`, matching the implementer's 930 |
| App `flutter analyze` | `No issues found! (ran in 2.7s)` |
| App `dart format --set-exit-if-changed` | `Formatted 163 files (0 changed)`, exit 0 |

The commit changes no lib file and no package, so the engine, render and web-build results above still stand.

### Verdict (10b): Approved

Findings 1 and 2 are closed. Findings 3 to 5 were informational and need nothing.
