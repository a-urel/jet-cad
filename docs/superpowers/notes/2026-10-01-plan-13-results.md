# Plan 13 results — export and print

**Branch:** `plan-13/export-and-print`, cut from `spec-13/export-and-print`
at `7c3847b` (the spec branch was cut from `main` at `a0a1920`). **Spec:**
[2026-10-01-export-and-print-design.md](../specs/2026-10-01-export-and-print-design.md),
revision 3 (`5b81c1c`), approved by the human on 2026-10-01 ("onaylıyorum,
planı yaz", recorded at `7c3847b`), amended at execution (its closing
section). **Plan:**
[2026-10-01-export-and-print.md](../plans/2026-10-01-export-and-print.md)
(`7fab442`). **Ledger:** [`ledgers/2026-10-01-plan-13/`](../ledgers/2026-10-01-plan-13/)
(`progress.md` carries every ruling R-13-1 .. R-13-24 with its cost-if-wrong;
the directory is created by a later commit, which archives the ledger, so
the link resolves only after that commit).

13 gets the drawing out of the app. `Export…` (Cmd/Ctrl+E) opens a small
dialog (PDF | PNG; 96 / 150 / 300 dpi for a PNG), then the platform's save:
a **vector PDF** of the page (its paper size and orientation, true scale,
lineweights in millimetres, text in an embedded Roboto, selectable) or a
**PNG** at the chosen dpi with a white ground and a `pHYs` chunk.
`Print…` (Cmd/Ctrl+P) hands the same PDF to the system print dialog (macOS)
or the browser's (web). Only the drawing plots: no grid, sheet edge, page
breaks, selection or room separators. The screen's own text now draws in the
bundled Roboto 2.137. The engine is untouched; the render package gains
`pageCamera`, `PdfDrawSink`, `exportPagePdf` / `exportPagePng`, `omitOwners`
and a test-side PDF reader (`package:jet_cad_2d_flutter/export_testing.dart`);
the app gains the font, `FileKind`, the two commands and the `PagePrinter`
seam.

Every task had a fresh implementer and an independent reviewer who re-ran
the gates and re-fired mutants. **The final whole-branch review** (on
`76559cc`, in a detached worktree) re-ran every gate (all as recorded
below), found no blocking or important defect and no cross-task defect,
and re-fired 24 mutants on the tip (22 named: M-13a, b, c, d, f, g, i, j,
l, m, n, p on both outputs, q, s, u, v, w, x, aa, ab, ac; the revert of
`32d488f`; the removed hook restore), **all red**. Verdict: "Ready with
fixes" — four documentation findings, applied in the commit that adds this
paragraph (`final-review.md` in the ledger).

| Task | Commits | Review |
|---|---|---|
| 1 The page camera and the fixture (D2, T-1) | `c96bb9b`; `749e8b1` (1b, test-only, landed first in Task 2) | Approved with notes (the outside line lay inside the sheet at 1:100 -> 1b) |
| 2 `omitOwners` (D6, T-2) | `32d488f` (**unplanned screen fix**), `257876e`, `64bb01c`; `ff0d853` (2b, test-only, landed first in Task 3) | Approved with notes (the grouped-root-instance bug real and fixed; container-site `debugOnVisit` and attribute-leaf mutants survived -> 2b; a linear lookup per frame found-not-fixed) |
| 3 `PdfDrawSink` geometry and the reader (D3, T-3, T-3b) | `babfcc1`; `d61d567` (3b, test-only) | Needs fixes, test-only (no path under a rotated or mirrored `cm`: a transposed residual in the sink and in the reader both passed) -> 3b Approved |
| 4 `PdfDrawSink` text (D3 "text", T-5 at the sink) | `94653f6`; `d3063ab` (4b, landed first in Task 5) | Approved with notes (`w_flutter` must come from `document.textMeasurer`; per-style measuring and the reader's stream check unpinned; the reader truncated a malformed `/ToUnicode` -> 4b) |
| 5 `exportPagePdf` (D4; T-4, T-5, T-6, T-8, T-9) | `c134c14`, `72827ed`; `8fe438b` (5b) | **Needs fixes, high:** an export's `SpatialIndex` took and then nulled the dispatcher's mutation hooks, unhooking the app's screen index (demonstrated) -> 5b (save and restore both hooks) Approved |
| 6 `exportPagePng` (D5, D10; T-7, T-8, T-9, T-11) | `ca163b9`; `d538aa2` (6b, test-only) | Approved with notes (stroke width pinned from above only; the existing-`pHYs` branch untested -> 6b Approved). **Render layer frozen at `d538aa2`.** |
| 7 The font (D7, T-12) | `f625d80` | Approved with notes (licence verified; mutant H, the registration call in `main()`, survived -> a source test owed, landed in Task 11) |
| 8 `FileKind` (D8) | `f181afc` | Approved with notes (the io and web files' use of the kind unpinned, three survivors -> a source test owed, landed in Task 11) |
| 9 `Export…` (D8, T-10) | `1e26b85`, `91b13ee`; `7f81838` (9b, test-only) | Approved with notes (the settle, the page-driven flag and busy over the dialog unpinned -> 9b Approved) |
| 10 `Print…` (D9, T-10) | `6a726a9`, `3057e13`; `ff85f02` (10b, test-only) | Approved with notes (Print's settle and busy over a successful print unpinned -> 10b Approved) |
| 11a End to end, the owed sweep tests, this note | `2153621`, `4ede95c` (test-only); `76559cc` (docs) | The final whole-branch review: Ready with fixes (docs only) -> applied |

No render `lib/` file changed after `d538aa2`; no app `lib/` file changed
after `3057e13` (Tasks 9b, 10b and 11a are test-only). The engine is
byte-unchanged (`git diff --stat a0a1920 HEAD -- packages/jet_cad_2d` is
empty, checked when this note was written).

## What the execution found that the spec did not

Each ruling is in the ledger with its cost-if-wrong; the spec's
"Amended at execution (Plan 13)" lists every deviation.

- **R-13-4, the unplanned screen fix `32d488f`.** A root-level instance
  inside a group was drawn without the group's transform: groups fold into
  the root index, and the painter used the instance's own transform while
  culling, picking, snapping and the outlines used the composed one. T-2
  (the outer group's instance must draw) could not pass without it. The
  reviewer reproduced the bug at `c96bb9b` (a leaf 488 px off on a screen
  camera), confirmed the fix allocation-free and golden-neutral, and showed
  the root-parent branch is an optimisation only (FIX-always equivalent).
  **Screen-visible:** an instance in a user group moves to where everything
  else already put it.
- **R-13-7, the toolchain:** `pdf` 3.13 needs Dart 3.12, first shipped in
  Flutter 3.44.0; the render package and the app say `flutter: ">=3.44.0"`
  (spec R-4 said 3.41). **The human's macOS Flutter must be 3.44.0 or
  newer.** No `sdk:` bound moved.
- **R-13-14:** `PdfDrawSink` measures with `document.textMeasurer` (typed
  `TextMeasurer`), the instance the painter laid each box out with, so `Tz`
  stretches the PDF string to exactly the painter's box. The PNG keeps its
  own `FlutterTextMeasurer` (R-13-19, below).
- **R-13-17, the high finding of Task 5:** an export builds a
  `SpatialIndex`, which takes the dispatcher's single mutation hooks and
  nulls them on `dispose()`; the app's screen index then stopped hearing
  edits. Both exports now paint inside `_withExportIndex` (save both hooks,
  synchronous body, dispose, restore in `finally`). Pinned in the render
  tests and end to end (EX2: an edit after an export reaches the screen's
  index).
- **R-13-9 / R-13-16:** the `pdf` package drops a content stream that only
  sets state; an empty page has no `/Contents`.
- **R-13-12:** the font is embedded on the first text (a page without text
  embeds none). `text()` throws unless the font is on the CID path (4b).
- **R-13-13 / Task 4 review:** `pdf` 3.13.1 writes a cross-reference
  stream but never object streams, so the reader's sequential scan reads
  `compress: true` output (EX1 and E2E do).
- **R-13-5 / R-13-6:** T-2 compares through `differential.dart`
  (`sink_comparison.dart` compares backends by pixels), recording the
  painter with `shadesDashes: true`.
- **R-13-8, R-13-15, R-13-18:** see the mutant table (T-3b's three, M-13c's
  two forms, M-13x via `SetComponentCommand`, M-13p's PNG half at 150 dpi).
- **R-13-19:** the PNG measures with its own `FlutterTextMeasurer`; it
  agrees with the painter's box in the app (two Flutter measurers over one
  font set measured identically, 1100.0 / 70.0), and only a non-Flutter
  document measurer, which cannot reach the app's export, would misplace a
  centred or right-aligned label.
- **R-13-20:** `ExportFontCache` is created by `FloorPlannerApp`, handed to
  `DocumentHost.exportFont`; a bare host makes its own (EX14). A failed font
  read is not held.
- **R-13-21:** the io save adds no extension (the macOS panel does, and the
  sandbox grants exactly its URL); matching is case-sensitive.
- **R-13-22:** spec F-11 / R-7 were wrong for the web: the web engine
  already fetched Roboto from Google when none was bundled. The look on the
  web changes little; start-up no longer fetches a font.
- **R-13-23 / R-13-24, layout:** the Export and Print buttons (40 px each)
  raise 12a's narrowest overflow-free top bar from 576 to 656 px (DC12c,
  verified: 655 px overflows by 1.00 px), and the status line's slot is
  40 px narrower (DC12b's room name shortened). The app depends on `pdf`
  directly (`PdfPageFormat`).
- **R-13-1 / R-13-3:** `Definition.basePoint` is never read by the renderer
  or the engine, so the fixture's non-origin base point is not a coverage
  trait; the fixture's separator keeps the real separator's ByLayer style.
- **Task 11a, the end-to-end test** (`export_end_to_end_test.dart`): on the
  **sample the app ships** (Open sample from the toolbar; its page is A4
  landscape at 1:50 centred on the plan, not at the origin): Save, Export
  PDF, Export PNG at 150 dpi, Print, Save. The PDF's `MediaBox` is
  841.89 × 595.28 pt, it has text runs, each a `/Type0` over a
  `/CIDFontType2` with a `/FontFile2` and a `/ToUnicode` string; the PNG is
  1754 × 1240; the printer gets the export's operator list and the page in
  pt; the document stays clean; **the second Save is byte-identical to the
  first**.
- **Task 11a, the owed sweep tests:** EF11 reads `lib/main.dart` and
  asserts `main()` calls `registerFontLicences()` before `runApp(`, comments
  stripped (its first form let a commented-out call pass: fixed in
  `4ede95c`); `document_files_sources_test.dart` (DS1-DS2, the Task 8
  reviewer's prototype) pins `saveTypeGroupsFor(kind)` and a single
  `kJetplanTypeGroup` in io, and `fileNameFor(…, kind)`,
  `BlobPropertyBag(type: kind.mimeType)`, no `application/` literal and no
  `jetplanFileName` in web.
- **The environment.** Flutter 3.47.2 (Dart 3.13.2) at `/root/flutter`.
  `flutter pub get` rewrites `packages/jet_cad/analysis_options.yaml`; it
  was never staged. `pubspec.lock` is untracked in this workspace.

## Gates of record (Linux container, `CI=true`)

Branch point `a0a1920`: engine 1,121 + 2 standing; render 1,001 + 1 skip + 7
standing; app 885.

- **engine** `00:15 +1121 -2: Some tests failed.` (both in
  `test/testing/generate_document_test.dart`, standing); `dart analyze`
  `No issues found!`; `Formatted 160 files (0 changed)`. Byte-unchanged:
  `git diff --stat a0a1920 HEAD -- packages/jet_cad_2d` is empty. (Task 11a,
  at `4ede95c`.)
- **render** `00:56 +1154 ~1 -7: Some tests failed.`: 1,001 + 153 new, 1
  skip, and the 7 standing Linux golden failures (text_ladder rungs 1-5,
  text_lod_ladder rungs 1-2, `RenderBackend.canvas`); `flutter analyze`
  `No issues found!`; `Formatted 200 files (0 changed)`. `flutter test --tags
  golden`: `00:32 +28 -7: Some tests failed.`, the same 7 and no other.
  `git diff --stat a0a1920 HEAD -- packages/jet_cad_2d_flutter/test/golden/`
  is empty: **no golden PNG regenerated** (T-13). (Task 11a, at `4ede95c`.)
- **The two allocation invariant tests** are unedited: `git diff --stat
  a0a1920 HEAD` over `packages/jet_cad_2d/test/invariants/query_allocation_test.dart`
  and `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`
  is empty; they run green inside the engine and render suites.
- **T-11:** `page_export.dart` names no `VerticesDrawSink`, `TileCache` or
  `DraftCanvas` (grep count 0) and names `CanvasDrawSink(` and
  `PdfDrawSink(`; `export_sources_test.dart` `00:00 +2: All tests passed!`.
- **app** 934: 885 + 10 (Task 7) + 6 (8) + 16 (9) + 9 (10, PR8 included)
  + 2 (9b) + 2 (10b) + 4 (11a: E2E, EF11, DS1, DS2) = 934; the run of record
  is in the Task 11a report; `flutter analyze` `No issues found!`;
  `Formatted 165 files (0 changed)`.
- **web** `CI=true flutter build web --release`: `✓ Built build/web`, exit 0
  (Task 11a, at `4ede95c`). The build ships the font and its licence
  (`assets/fonts/`), `FontManifest.json` names the `Roboto` family, and
  `NOTICES` lists `pdf`, `pdf_widget_wrapper`, `printing` (Task 7 and 10
  reviews).
- **dev_harness_2d** `flutter pub get` + `flutter analyze`: `No issues
  found!` (Task 11a).
- `analysis_options.yaml` is not in `git diff --name-only a0a1920 HEAD`.

## Dependencies and licences

Resolved versions from the workspace `pubspec.lock`; licence text read from
each package's `LICENSE` in the pub cache (Tasks 3 and 10, re-read in Task 11a).

| Package | Version | Licence | Brought by |
|---|---|---|---|
| `pdf` | 3.13.1 | Apache 2.0 | the render package (Task 3); a direct app dependency too (Task 10, `PdfPageFormat`) |
| `barcode` | 2.2.9 | Apache 2.0 | `pdf` |
| `bidi` | 2.0.13 | MIT (Copyright (c) 2020 Mahdi K. Fard) | `pdf` |
| `qr` | 3.0.2 | BSD 3-clause ("Copyright 2014, the Dart QR project authors") | `barcode` |
| `printing` | 5.15.1 | Apache 2.0 | the app (Task 10) |
| `pdf_widget_wrapper` | 1.0.4 | Apache 2.0 | `printing` |

`pdf`'s and `printing`'s other dependencies (archive, crypto, image, http,
meta, path_parsing, vector_math, xml, plugin_platform_interface, web,
flutter_web_plugins) were already resolved before plan 13. The web print
fetches nothing from a CDN: `printing`'s pdf.js loader is reached only by
`info()` / `raster()`, which the app does not call, and is absent from the
release `main.dart.js` (Task 10 review).

**The font.** Roboto Regular 2.137, Apache 2.0, the repository's vendored
`packages/jet_cad_2d_flutter/test/golden/fonts/Roboto-Regular.ttf` (from
Flutter 3.27.3's `material_fonts`), copied byte-identical to
`apps/floor_planner/assets/fonts/Roboto-Regular.ttf`: 171,676 bytes,
SHA-256 `79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95`;
its `Roboto_LICENSE.txt` copied unmodified (11,358 bytes, SHA-256
`cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`),
shipped as an asset in every build and registered with `LicenseRegistry`
under `Roboto` by `main()` (pinned by EF6 and EF11). Unmodified, no NOTICE
file: Apache 2.0 s.4(a) is met by the shipped text.

## Mutants

The P-8 rule (as in 09a and 09b): this table is compiled from each task's
report and independent review, both of which fired real runs at the task
commit (cp backup, one edit, the named test file in the foreground, cp back,
`diff` exit 0 every time); the final whole-branch review re-fires a sample
on the tip. Spec M-13a .. M-13ad first, then the notable own mutants.

| Id | Mutation | Red test | Task |
|---|---|---|---|
| M-13a | `exportPagePng` paints through `VerticesDrawSink` | T-11 `export_sources_test` "names no VerticesDrawSink…"; T-7 the oblique line's coverage only ("every pixel is either the ink or white") | 6, 6 review |
| M-13b | stroke width without `u` | sink: T-3 widths (`Actual: <0.35>`), circle, arc, point, T-3b ×2; export: T-4 0.70 and 0.35 mm at 1:50 and 1:100 | 3; 5 |
| M-13c | width times the camera's scale | raw form: T-4 at both scales (`Actual: <0.11249>`); normalised form (right at 1:50): T-4 **at 1:100 only** (R-13-15) | 5 |
| M-13d | `exportPagePdf` paints at `fitToPage(page, size)` | T-5 instance position and baseline origin, T-4 instance widths, T-6, T-8 (×7); at the flow (the page replaced by `PageComponent()`): EX1 | 5; 9 |
| M-13e | `TileCache` built on the PNG path | T-11 | 6 |
| M-13f | `pageCamera` ignores the origin | T-1 corners ×3, above-sheet ×3, the instance origin | 1 |
| M-13g | `pageCamera` without the y flip (one- and two-line forms) | T-1 corners, 1,000 mm segments, above-sheet, instance origin (×10) | 1 |
| M-13h | no page set-up `cm` | T-3 set-up, paths, circle, arc, point; T-3b point | 3 |
| M-13i | residual ignored | T-3 paths, circle, arc; T-3b after-`Q` | 3 |
| M-13j | arc with `|sweep|` | T-3 the −110° arc | 3 |
| M-13k | closed polyline without `h` | **T-3b only** (R-13-8) | 3 |
| M-13l | `Tz` omitted | T-5 advance (fixture and direct), the direct operator sequence | 4 |
| M-13m | text with an extra y flip | T-5 direction (fixture and direct, `Actual: <3.14159…>`) | 4 |
| M-13n | white foreground | T-6 ACI 7 (`Actual: [1.0, 1.0, 1.0]`) | 5 |
| M-13o | alpha ignored | T-6 the 0x80 fill (`Actual: <1.0>`) | 5 |
| M-13p | `minTextCapPixels` left at the default | PDF: T-5 labels (`Actual: ['Yatak Odası']`) and four more; PNG: T-7 "WC" **at 150 dpi** (R-13-18) | 5; 6 |
| M-13q | the painter ignores `omitOwners` | T-2 comparison, content, exact difference, `debugOnVisit`, container route | 2 |
| M-13r | the owner test on the leaf's handle | T-2, the same six tests | 2 |
| M-13s | PNG size by `floor` | T-7 all 12 sizes (`[1753, 1240]`); end to end: E2E | 6; 11a |
| M-13t | `pHYs` from dpi / 0.254 | T-7 the three `pHYs` tests | 6 |
| M-13u | no white ground | T-7 line, oblique, corners, T-8 | 6 |
| M-13v | print exports again with an empty set | T-10 PR1, PR2 (operator lists) | 10 |
| M-13w | export enabled without a page | T-10 EX9; Print's own (`kPageCommandIds = {'export'}`): PR4 | 9; 10 |
| M-13x | the export runs a command (`SetComponentCommand<PageComponent>`, R-13-15) | T-9 (`stateId` 23 → 24); in the app's flows (11a E1, E2: dirty; E2c with the dirty flag hidden: the byte-identical Save) | 5; 11a |
| M-13y | no `gs` for an opaque op | **T-3b only** (R-13-8) | 3 |
| M-13z | state cached across `Q` | T-3 paths (the instance's second primitive drawn black), T-3b after-`Q` | 3 |
| M-13aa | the walk skips the omitted node's subtree | T-2 comparison and the nested group's line | 2 |
| M-13ab | print without `format` (`PdfPageFormat.standard`) | T-10 PR1, PR2; at the adapter (`format:` dropped): PR8 | 10 |
| M-13ac | the web save names every kind `.jetplan` | at `fileNameFor`: FK1; at the web call site (M-8webname): DS2 | 8; 11a |
| M-13ad | the point marker drawn under `cm` | **T-3b only**, the rotated, mirrored point (R-13-8) | 3 |

Notable own mutants, all red unless marked:

| Id | Mutation | Red test | Task |
|---|---|---|---|
| FIX-rev | the painter's pre-`32d488f` `node.transform` for a grouped root instance | `grouped_root_instance_test` (`Actual: <488.06…>` px off), T-2 | 2, 2 review |
| FIX-always | every root instance takes the index lookup | **equivalent by experiment** (the root-parent branch is an optimisation) | 2 review |
| R-visit-cont, R-attrib | `debugOnVisit` before the container skip; the walk's attribute site ignores the set | the 2b container-route and attribute tests (both survived at Task 2) | 2b |
| OWN-5, RD-transpose | the residual written transposed (sink); the reader's `apply` transposed | the 3b rotated, mirrored T-3b test; the reader's non-symmetric `cm` test (both survived at Task 3) | 3b |
| OWN-3 / OWN-7 | the first vertex shifted 5e-4 / 2e-5 pt | T-3 at the tightened, per-number rounding bound (OWN-3 survived at Task 3) | 3b |
| RD-pm vs T | `pageMatrix = CTM × Tm` | **equivalent for every sink test** (the sink always writes `0 0 Td`, Tm = I); red in the reader's own test | 4 |
| OWN-fresh, OWN-style | the sink measures with a fresh `FlutterTextMeasurer`; with the standard style | the MetricModel and per-style measurer pins (OWN-style survived at Task 4) | 4b |
| OWN-ex-style | `exportPagePdf` measures every text under the standard style | the per-style pin (survived at `c134c14`, fixed in `72827ed`) | 5 |
| B-norestore, B-normalonly | the hooks not restored; restored on a normal return only | the screen-index hook tests (normal, throwing) | 5b |
| B-nodispose, B-restorefirst | `dispose()` dropped; restore also before `dispose()` | **equivalent by experiment** once the restore exists | 5b |
| REV-a4 | the PDF format hard-coded A4 landscape | the A3 portrait test (survived at Task 5) | 5b |
| H-png-bypass | the PNG builds its own index without `_withExportIndex` | the PNG screen-index hook test | 6 |
| R-ppmmHalf | the PNG stroke width halved | the horizontal line from below (survived at Task 6) | 6b |
| OWN-clear / R-noClear | `measurer.clear()` dropped on the PNG path | **survives, accepted**: unobservable without a seam (memory waits for the finalizers) | 6 |
| H | `registerFontLicences()` commented out of `main()` | survived Task 7 and the first EF11; red by EF11 since `4ede95c` (also moved after `runApp`, and block-commented) | 7; 11a |
| M-8webname, M-8webmime, M-8iocall | the web name / MIME type / the io type group fixed to `jetplan` | DS2, DS2, DS1 (all three survived at Task 8) | 11a |
| J / J2 | the dialog's explicit Escape binding removed / `barrierDismissible: false` | J **survived** (dead code, removed in `91b13ee`); J2 red EX6 | 9 |
| R1 | the page read before the settle | **equivalent** (the settle cannot change the root's page) | 9 review |
| R2, R5, R6 | Export without the settle; the page flag without `_page`; the dialog outside `_flow` | EX2b, EX9b, EX5 (all survived at Task 9) | 9b |
| R10b, R10d | Print without the settle; the print not awaited (`timeout(Duration.zero)`) | PR9, PR10 (both survived at Task 10; B10z first survived PR10's first form) | 10b |
| E2 | Print exports twice, prints once | **equivalent by observation** (the export is pure, the font cached) | 10 |
| E1b | the export toggles `gridVisible` and hides the dirty flag | **equivalent** in E2E (two exports toggle it back); E2c is the non-involutive form, red on the byte-identical Save | 11a |
| E3, E5 | the print format / the PDF format from raw or swapped sizes | E2E (`Actual: <595.27…>`) | 11a |

Notes on the table. M-13f and M-13g were fired against T-1 only (the plan's
route: Task 1 owns them); T-3 replays ops recorded at the real camera.
M-13q / M-13r were fired against T-2 in Task 2; on the tip M-13q is also
red on T-8 for the PDF (`export_pdf_test`, "no path lies on its segment",
final review). T-8's omission in each output is also pinned by the
exports' own "set not passed" mutants (Task 5 OWN-ex-omit,
Task 6 OWN-omit, Task 9 C). A first M-13f/M-13g firing in the Task 1 review
used a broken script; the file was restored from a checked backup and both
re-fired (Task 1 review, process note).

## Found, not fixed

- **A stale doc comment** (`apps/floor_planner/lib/main.dart:228-229`,
  final review finding 4): `fileCommands`' comment lists the commands up to
  Export and says the page gates Export's; Print is gated on the page too.
  Comment-only; left as is because the app's `lib/` is frozen after
  `3057e13` (a reviewed follow-up can fix it).
- **A grouped root instance does a linear lookup per frame** (`32d488f`,
  `container_index.dart` `_instanceHandles.indexOf`): O(root instances) per
  grouped instance, allocation-free by reading; no measurement covers it
  (the allocation corpus has no instance under a group). Today the app
  places every instance at the root.
- **`CanvasDrawSink`, latent** (Task 3 review, R-13-10): `_pushTransform`
  outside a residual would leave an unmatched `save`, and a `point` after
  another primitive in the same residual would be transformed twice.
  Neither is reachable from `DraftPainter` today; each fix needs a
  direct-call test.
- **`pdf` 3.13.1 writes a malformed `/ToUnicode` for code points above
  U+FFFF** (`<1F600>`, five hex digits, not a surrogate pair): copy and
  search of such a character is wrong in a viewer. The floor planner's
  labels are BMP; the reader now refuses it rather than truncating.
- **The PNG text measurer** (R-13-19): identical to the painter's in the
  app; a non-Flutter document measurer would misplace a centred or
  right-aligned label (up to 3.5 / 7.1 cap heights in the review's example).
  Unreachable from the app.
- **The web print ignores `name` and `format`** (`printing` 5.15.1's web
  `layoutPdf`: a blob in a hidden iframe, `print()`); the paper comes from
  the PDF's `MediaBox`. A download fallback off desktop Chrome, Safari and
  Firefox.
- **PR8 is tied to `printing`'s private channel protocol** (`net.nfet.printing`):
  the only test of the production adapter; a `printing` upgrade turns it
  red, not silently green. Re-check it on any bump.
- **The toolbar's floor is 656 px and the status slot 40 px narrower**
  (R-13-23, R-13-24): no macOS minimum window width is set, so a window
  narrowed below 656 px overflows the top bar; a long status line is cut
  about 40 px sooner.
- Missing glyphs get `/W` 0 and `Tz` stretches the present ones over
  Flutter's advance (R-3, one font).
- `measurer.clear()` on the PNG path is unobservable (OWN-clear).
- The PNG T-9 throwing test finds the painter by a JIT frame name
  (`'DraftPainter.'` in `StackTrace.current`); it asserts the error type, so
  a non-throw is red, not vacuous.
- `registerFontLicences()` is not idempotent in one isolate (only `main()`
  calls it), and the app has no licence page yet: the registered entry has
  no viewer.

## Risks seen

- **R-1** held: two exports differ in `/ID`; every comparison reads content
  streams (PR1, E2E).
- **R-4** became R-13-7: the floor is Flutter 3.44.0, not 3.41.
- **R-6** (A3 at 300 dpi, 3508 × 4961) was not exercised on a WebGL GPU;
  the size is pinned by T-7 under flutter_test only.
- **R-7** was smaller than feared on the web (R-13-22); on macOS the
  drawing's text changes, the chrome keeps the system font.
- **R-9** (dashes judged in output units) is unchanged: the PDF (pt) and a
  PNG (px) can cut a fine pattern differently.
- A new one: **an export used to unhook the screen index** (R-13-17). Fixed;
  any future one-shot `SpatialIndex` over a live document must use the same
  save-and-restore, since the engine has no detached index.

## The human's look

Copied from the spec's Exit gate (L-1 .. L-7) and **amended by the
rulings**. **Nothing is marked done for the human.** macOS (sandboxed
build) and web (Chrome, Firefox). **The macOS Flutter must be 3.44.0 or
newer** (R-13-7) to build at all.

- **L-1.** Text on screen draws in Roboto (room labels, dimensions, symbol
  names in the gallery) and reads correctly, Turkish letters included.
  **On macOS** the drawing's text changes to Roboto; the app's chrome (menus,
  panels, buttons) keeps the system font. **On the web** expect nearly
  identical text (the web engine already used a Roboto it fetched), and **no
  font fetched from Google at start-up** (the browser's network panel).
- **L-2.** Export → PDF, opened in Preview / the browser: the page is the
  sheet's size and orientation; the drawing sits where it sits on the sheet
  on screen; a wall or dimension measured with a ruler on a 100 % print
  agrees with the scale.
- **L-3.** Lines are sharp at any zoom in the PDF viewer; thick and thin
  lines read as on screen; text is selectable and reads correctly.
- **L-4.** No grid, no sheet edge, no room separators in the PDF or PNG.
- **L-5.** Export → PNG at each DPI opens at the expected size; the ground
  is white.
- **L-6.** Print… opens the macOS print dialog (sandboxed build) and the
  browser's on the web, with the right paper and orientation; printed at
  100 %, the scale holds. On the web the dialog's paper comes from the PDF
  itself (the document name is not passed).
- **L-7.** Cmd+E / Cmd+P on macOS, Ctrl+E / Ctrl+P on the web (the
  browser's own print must not open instead), and the dialog's Esc.
- **New (R-13-21):** in the macOS Export panel, type `plan` with no
  extension: the file saved is `plan.pdf` (or `plan.png` for a PNG).
- **New (R-13-23, R-13-24):** narrow the window to about 656 px: the top
  bar must not overflow (below that it does); the status line is cut sooner
  than before the two new buttons.
