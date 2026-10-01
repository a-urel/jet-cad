# Task 11a report — end to end, owed sweep tests, sweep, results note, spec amendment, roadmap

## Commit 1: `2153621` test(app): export and print end to end (on ff85f02). Not pushed.
Files:
- `apps/floor_planner/test/export/export_end_to_end_test.dart` (new, 1 test E2E): FloorPlannerApp with FakeDocumentFiles, FakePagePrinter and the vendored Roboto through `fontCache()`; toolbar Open sample; premises (>= 500 entities, page A4 landscape 297 x 210 effective, origin not at 0); Save (Save As to /p/sample); toolbar Export -> PDF: `sample.pdf`, kind pdf, MediaBox [0 0 841.89 595.28], paths and text runs present, every run /Type0 over /CIDFontType2 with /FontFile2 and a /ToUnicode string, font read once from the cache; Export -> PNG 150: `sample.png`, kind png, 1754 x 1240; toolbar Print: one call, name `sample`, format 297 x 210 mm in pt, printed operator list == the exported PDF's, MediaBox equal; busy false; document identical and not dirty; Save in place: bytes == the first Save's; no unscripted call.
- `apps/floor_planner/test/export/export_font_test.dart`: EF11 (Task 7 review finding 1): reads lib/main.dart, the body of `void main() {` contains `registerFontLicences();` before `runApp(`.
- `apps/floor_planner/test/document_files_sources_test.dart` (new, DS1-DS2, Task 8 review finding 1, from the reviewer's prototype scratchpad/r8): io has `acceptedTypeGroups: saveTypeGroupsFor(kind)` and exactly one `kJetplanTypeGroup`; web has `fileNameFor(await askName(suggestedName), kind)` and `BlobPropertyBag(type: kind.mimeType)`, no `application/`, no `jetplanFileName`.

App gate at 2153621 (real tails):
```
03:50 +934: All tests passed!
No issues found! (ran in 1.7s)
Formatted 165 files (0 changed) in 0.80 seconds.
fmt=0
```
(930 at ff85f02 + E2E + EF11 + DS1 + DS2 = 934.)

## Commit 2: `4ede95c` test(app): EF11 ignores a commented-out licence registration
The first EF11 (in 2153621) let mutant H survive: `// registerFontLicences();` still contains the searched text (`00:01 +11: All tests passed!`). EF11 now strips `//` and `/* */` comments from main()'s body before searching. Analyze `No issues found! (ran in 1.8s)`, format `Formatted 165 files (0 changed)`, fmt=0.

## Mutants (scratch e11; mut.sh: cp backup, one python replace asserted count==1, `flutter test <file> --timeout 120s` foreground, cp back, diff -> restored=0 for every one)
| id | file | mutation | test | result (real line) |
|---|---|---|---|---|
| H (first EF11) | apps/floor_planner/lib/main.dart:42 | `// registerFontLicences();` | export_font_test.dart | **survived** `00:01 +11: All tests passed!` -> test fixed in 4ede95c |
| H2 | main.dart:42 | `// registerFontLicences();` | EF11 | red `Expected: a non-negative value  Actual: <-1>` |
| H3 | main.dart:42-43 | call moved after `runApp(...)` | EF11 | red `Expected: a value less than <16>  Actual: <51>` |
| H4 | main.dart:42 | `/* registerFontLicences(); */` | EF11 | red `Expected: a non-negative value  Actual: <-1>` |
| M-8iocall | lib/document_files_io.dart:44 | `saveTypeGroupsFor(FileKind.jetplan)` | DS1 | red `Expected: contains 'acceptedTypeGroups: saveTypeGroupsFor(kind)'` |
| M-8webname (= spec M-13ac at the web call site) | lib/document_files_web.dart:56 | `fileNameFor(..., FileKind.jetplan)` | DS2 | red `Expected: contains 'fileNameFor(await askName(suggestedName), kind)'` |
| M-8webmime | lib/document_files_web.dart:68 | `BlobPropertyBag(type: 'application/json')` | DS2 | red `Expected: contains 'BlobPropertyBag(type: kind.mimeType)'` |
| E1 | lib/document_host.dart exportFlow | after the dialog, `SetComponentCommand<PageComponent>` toggling gridVisible | E2E | red `Expected: false  Actual: <true>` (dirty) |
| E2 | lib/document_host.dart printFlow | the same before the print | E2E | red `Expected: false  Actual: <true>` (dirty) |
| E1b | exportFlow | toggle gridVisible + `_session.markSaved(stateId)` (hides dirty) | E2E | **survived** `00:02 +1: All tests passed!` — equivalent: Export runs twice (PDF, PNG), the toggle undoes itself, the bytes are equal. Replaced by E1c/E2c |
| E1c | exportFlow | `originX + 1` + markSaved | E2E | red: print vs export operator lists, `Which: at location [5] is '1 0 0 1 272.52283 541.87087 cm' instead of '1 0 0 1 272.63622` |
| E2c | printFlow, after the print | `originX + 1` + markSaved | E2E | red on the byte check: `Which: at location [176442] is <54> instead of <53>` / `Save after the exports is byte-identical to Save before` |
| E3 | lib/export/export_flow.dart:76 | printPageFormat from raw `widthMm`/`heightMm` | E2E | red `Expected: a numeric value within <1e-9> of <841.8897637795277>  Actual: <595.2755905511812>` |
| E4 (M-13s) | packages/jet_cad_2d_flutter/lib/src/export/page_export.dart:112 | width `.floor()` | E2E | red `Expected: (int, int):<(1754, 1240)>  Actual: (int, int):<(1753, 1240)>` |
| E5 | page_export.dart:45 | PdfPageFormat(height, width) | E2E | red `Expected: a numeric value within <0.001> of <841.8897637795277>  Actual: <595.27559>` |

Not fired: a font-embedding mutant at the app level (the app passes bytes; the font's kind is the render sink's, pinned by T-5); the PNG dpi at the flow (150 is the default, so E2E cannot see it; EX3 kills it, mutant K of Task 9).

## Sweep (real output, at 4ede95c)
- Engine byte-unchanged: `git diff --stat a0a1920 HEAD -- packages/jet_cad_2d | wc -l` -> `0`.
- Allocation invariant files unedited since a0a1920: `git diff --stat a0a1920 HEAD -- .../query_allocation_test.dart .../paint_allocation_test.dart` -> 0 lines.
- No analysis_options.yaml committed: `git diff --name-only a0a1920 HEAD | grep -c analysis_options` -> `0` (the working tree's `packages/jet_cad/analysis_options.yaml` is pub get's rewrite, unstaged).
- Golden directory: `git diff --stat a0a1920 HEAD -- packages/jet_cad_2d_flutter/test/golden/` -> 0 lines.
- `flutter test --tags golden` (render): `00:32 +28 -7: Some tests failed.`; the 7 are text ladder rungs 1-5 and text lod ladder rungs 1-2 (RenderBackend.canvas): exactly the standing 7.
- T-11: `grep -cE "VerticesDrawSink|TileCache|DraftCanvas" page_export.dart` -> `0`; `CanvasDrawSink(`/`PdfDrawSink(` lines -> `2`; `export_sources_test.dart` -> `00:00 +2: All tests passed!`.
- dev_harness_2d `flutter pub get` + `flutter analyze`: `No issues found! (ran in 1.3s)`.

## Gates (real tails)
- Engine: `00:15 +1121 -2: Some tests failed.` (both in test/testing/generate_document_test.dart, standing); `dart analyze` `No issues found!`; format `Formatted 160 files (0 changed)`, fmt=0.
- Render: `00:56 +1154 ~1 -7: Some tests failed.` (5 text_ladder + 2 text_lod_ladder, standing); analyze `No issues found! (ran in 1.7s)`; format `Formatted 200 files (0 changed)`, fmt=0.
- App (at 4ede95c, re-run after the EF11 fix): `03:51 +934: All tests passed!`; analyze `No issues found! (ran in 2.3s)`; `Formatted 165 files (0 changed)`, fmt=0.
- Web: `CI=true flutter build web --release` -> `✓ Built build/web`, `build exit=0` (re-run to capture the status: the first run's exit 2 came from a following `ls` of a path that does not exist, not from the build).

## Commit 3: `76559cc` docs: plan 13 results
- `docs/superpowers/notes/2026-10-01-plan-13-results.md` (new, the 09b form): what it delivers; task/commit/review table; what execution found (R-13-1..24); gates of record (engine, render, golden tag, invariants, T-11, app 934, web, harness); dependency licences (verified again from the pub cache and pubspec.lock: pdf 3.13.1 Apache-2.0, barcode 2.2.9 Apache-2.0, bidi 2.0.13 MIT, qr 3.0.2 BSD-3, printing 5.15.1 Apache-2.0, pdf_widget_wrapper 1.0.4 Apache-2.0) and the font (sha256 79e85140…16d95, 171,676 B; licence cfc7749b…3d30); the mutant table M-13a..ad + notable own mutants with equivalents recorded; found-not-fixed; risks seen; the human's look L-1..L-7 amended (web: nearly identical text, no start-up font fetch; macOS: drawing text changes, chrome keeps the system font; L-6 web paper from the PDF) plus new items (plan -> plan.pdf/plan.png in the macOS panel; ~656 px window; Flutter >= 3.44.0). Nothing marked done for the human. The final-review section is left as "to come".
- Spec: "## Amended at execution (Plan 13)" appended (R-4/3.44.0; document.textMeasurer R-13-14; hooks R-13-17 D4/I-3; empty page R-13-9/16 and ExtGState wording; reader location R-13-2; differential.dart R-13-5/6; 32d488f R-13-4; basePoint R-13-1/R-13-3; mutants M-13k/y/ad R-13-8, M-13c forms, M-13p R-13-18, M-13x R-13-15, M-13q/r, M-13ac, E2; F-11/R-7/L-1 web R-13-22; io extension R-13-21; DC12b/c R-13-23/24; app's direct pdf dependency). Earlier sections untouched.
- `roadmap/13-export-and-print.md` status line (executed, not merged; merge and look pending — the human's; spec/plan/results links; the old line kept as "Before Plan 13 ran"); `roadmap/00-README.md` row 13 and the summary sentence. STATUS.md not touched.

## Spec / plan notes and decisions (this task)
- The first EF11 searched raw text and let a commented-out call pass (mutant H survived it); fixed by stripping comments (4ede95c). DS1/DS2 search raw text too; a commented-out duplicate of a call line would pass them, but each named survivor (a one-line edit) is red.
- E1b (an involutive mutation in exportFlow) is equivalent end to end because Export runs twice; E1c/E2c are the non-involutive forms.
- The E2E test does not repeat the separator check: in the sample the separator's ends touch wall faces, so a "no vertex within 1 pt" check would be confounded (EX1/PR1 already pin it on the flat).
- The plan's Task 11 also lists the final whole-branch review and the ledger archive; both are outside 11a (per the brief). The results note says the final review is still to come.
- Task 10b's re-review was running in parallel; the note records 10b as "re-review ran in parallel with Task 11" with no verdict.
- `git diff --name-only a0a1920` (working tree) shows `packages/jet_cad/analysis_options.yaml` because pub get rewrote it; against `HEAD` the count is 0. Never staged.
