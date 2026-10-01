# Plan 13 final whole-branch review: export and print

Range: `a0a1920..76559cc` on `plan-13/export-and-print`, 31 commits. Worktree:
`.claude/worktrees/plan-13-review`, detached at `76559cc`. `flutter pub get` was
run first. `git status` shows only ` M packages/jet_cad/analysis_options.yaml`,
the pub get rewrite, which was never staged.

Read: CLAUDE.md; the spec (whole, including "Amended at execution (Plan 13)");
the plan; the results note; progress.md; every task-N-report.md and
task-N-review.md (1-10, with re-reviews 3b, 5b, 6b, 9b, 10b); task-11a-report.md.

Scratch: `scratchpad/gates/` (gate logs), `scratchpad/rf/` (mutant driver
`mut.py`, backups, one log per mutant and test file, `batch{1,2,3}.out`).

## Verdict: **Ready with fixes** (documentation only)

No blocking or important code defect. Every gate is at its expected number.
Every non-negotiable holds. All 26 re-fired mutant runs (24 mutants) are red,
and every file was restored with `diff` exit 0. The fixes are to the results
note and the spec amendment, plus one stale doc comment. They belong in the
same docs commit as this review's record and the ledger archive.

## 1. Gates (re-run by me, `CI=true`, Flutter at `/root/flutter`, at `76559cc`)

| gate | real tail | expected |
|---|---|---|
| engine `dart test` | `00:19 +1121 -2: Some tests failed.`: both in `test/testing/generate_document_test.dart` ("both text fractions default to zero…", "the default document is the one Plan 2 measured…") | 1121 + 2 standing ✓ |
| engine `dart analyze` | `No issues found!` | ✓ |
| engine format | `Formatted 160 files (0 changed) in 0.75 seconds.` | ✓ |
| render `flutter test` | `01:05 +1154 ~1 -7: Some tests failed.`: the 7 are text ladder rungs 1-5 and text lod ladder rungs 1-2 (`RenderBackend.canvas`) | 1154 + 1 skip + 7 ✓ |
| render `flutter test --tags golden` | `00:35 +28 -7: Some tests failed.`: exactly the same 7 | exactly the 7 ✓ |
| render `flutter analyze` | `No issues found! (ran in 5.0s)` | ✓ |
| render format | `Formatted 200 files (0 changed) in 0.75 seconds.` | ✓ |
| app `flutter test` | `04:12 +934: All tests passed!` | 934 ✓ |
| app `flutter analyze` | `No issues found! (ran in 2.4s)` | ✓ |
| app format | `Formatted 165 files (0 changed) in 1.03 seconds.` | ✓ |
| app `flutter build web --release` | `✓ Built build/web`, exit 0 | ✓ |
| `dev_harness_2d` `flutter analyze` | `No issues found! (ran in 1.8s)` | ✓ |

Both allocation invariant tests ran green inside these suites:
`query_allocation_test.dart` in the engine and `paint_allocation_test.dart` in
render. Neither appears among the failures.

## 2. Non-negotiables

- **Engine byte-unchanged:** `git diff --quiet a0a1920..HEAD -- packages/jet_cad_2d` exits 0. ✓
- **Allocation invariant tests unedited, no `analysis_options.yaml`, no golden PNG:**
  `git diff --name-only a0a1920..HEAD | grep -E 'analysis_options|\.png$|invariants'`
  prints nothing. ✓
- **Draw order (unplanned `32d488f`):** only the `accumulated:` transform of a
  root-stream instance changed (`draft_painter.dart:434-436`). Instances are
  still drained in ascending handle order before each higher-handled leaf
  (`:387-389`), and the remainder is drained after the stream. The omit check
  (`:390`, `:482`) runs after the instance drain, so a skipped leaf does not
  reorder anything. Ascending handle order is preserved. ✓
  - `transformOfInstance` (`container_index.dart:581`) is a linear `indexOf`
    over the root index's handles. It allocates nothing when found, and only a
    grouped instance pays for it (found-not-fixed, as recorded).
  - The app places every symbol instance with `parent: doc.rootHandle`
    (`symbol_placer.dart:124-126`), so the fix cannot show in the app today.
    The note's "Today the app places every instance at the root" is correct.
- **Tolerance vs exact `==`:**
  - The lib code makes no geometric decision by `==`.
  - `pageCamera` validates `u` with `isFinite`/`<= 0`.
  - `PdfDrawSink.arc` returns on `sweep == 0` (a stored value) and uses the
    `-1e-9` guard only for segment counting.
  - `_widthFor` checks `residualScale == 0`, a division guard.
  - `fileNameFor` uses an exact suffix comparison (ruled R-13-21).
  - The tests use derived bounds (`pdf_tolerance.dart`). ✓
- **English:** code, comments and commit messages are English. The only
  non-English text is Turkish test data ("Yatak Odası", "Mutfak") and the
  quoted approval "onaylıyorum, planı yaz" in docs. ✓
- **Trailers:** all 31 commits carry both `Co-Authored-By: Claude Opus 5.5
  <noreply@anthropic.com>` and the `Claude-Session:` line (checked per commit). ✓
- **Freeze points hold:**
  - `git diff --stat d538aa2..HEAD -- packages/jet_cad_2d_flutter/lib` is empty.
  - `git diff --stat 3057e13..HEAD -- apps/floor_planner/lib` is empty.

## 3. Whole-branch coherence

Code read: `lib/src/export/{page_camera,page_export,pdf_draw_sink}.dart`, the
painter and reference-walk diffs, `apps/floor_planner/lib/export/*`,
`document_files{,_io,_web}.dart`, and the `document_host.dart`, `main.dart`,
`shell_commands.dart` and pubspec/entitlement diffs.

- **Mutation hooks (R-13-17).**
  - `grep -rn "onAfterMutate\|onBeforeMutate"` over `packages` and `apps`
    (lib code) finds only these:
    - the dispatcher (`undo.dart`);
    - `SpatialIndex`, which installs the hooks at `:167,:173` and conditionally
      nulls them at `:3066-3076`;
    - `_withExportIndex`.
  - Every lib `SpatialIndex(` is one of:
    - the shell's long-lived index (`main.dart:270`);
    - the dev-harness rigs (their own documents);
    - `symbol_thumbnails.dart:120` (a document it builds itself);
    - the export.
  - So the export is the only one-shot index over a live document. Its save and
    restore wrap a synchronous body, so no edit can land between the capture
    and the restore.
  - Re-fired below (NO-RESTORE). It is red in the PDF test, the PNG test and
    the app's EX2.
- **Export and Print sharing state.**
  - They share only the `ExportFontCache` (one future, intentionally) and the
    `exportOmitOwners`/`exportPdfBytes` helpers.
  - `_lastExport` is Export's alone. Print has no dialog and reads no choice.
  - Both run under `_flow` (busy), so they cannot overlap.
- **Font cache lifetime.**
  - `_FloorPlannerAppState._exportFont` is above the `MaterialApp`, and it is
    passed to `DocumentHost.exportFont`. The host is `home:` and survives
    document swaps, and its `late final` takes the app's cache.
  - A failed read is dropped (`identical(_bytes, next)` guard), so the next
    export retries.
  - A bare host makes its own cache (EX14).
  - The cache is never read on the PNG path (`exportBytes` awaits
    `fontBytes()` only for a PDF).
- **When `omitOwners` is computed.**
  - In `exportBytes` and `exportPdfBytes`, at the moment of the export: after
    the settle, the dialog and `saveLocation` for Export, and after the font
    for Print.
  - That is what D6 asks ("at the moment of export").
  - The page itself is read once after the settle and before the dialog. This
    is Task 9's accepted info-finding 4: modal routes and busy make the gap
    unobservable.
- **Web vs io file kinds, end to end.**
  - The host calls `saveLocation('<name>.<ext>', kind:)` and `write(…, kind:)`.
  - io offers `saveTypeGroupsFor(kind)` and returns the panel's path
    unchanged, as Save does.
  - Web runs `fileNameFor(askName(…), kind)` and builds a blob of
    `kind.mimeType`.
  - Export never writes `place.name` or `place.location` back into the session,
    so a later Save still targets the document's own file. This is correct, and
    E2E pins it with the byte-identical second Save.
  - The suggested name follows Save As's convention (`_session.name` +
    extension).
- **PNG and PDF agree on what plots.**
  - Both use `DraftPainter(minTextCapPixels: 0.0, omitOwners: same set)`,
    `DocumentStyleResolver(foreground: 0x000000)` and the page camera.
  - Neither sink shades dashes, and both skip a lineweight-0 point.
  - The differences are recorded ones: R-9 (dash collapse judged in pt vs px)
    and R-13-19 (the PNG measures paragraphs with its own `FlutterTextMeasurer`).
  - Re-firing M-13q against `export_pdf_test.dart` shows the painter's omit
    reaches the PDF's T-8 directly (see finding 3).
- **Toolchain.**
  - Both `flutter:` bounds are `>=3.44.0`. The `sdk:` bounds are unchanged.
  - `dev_harness_2d` analyzes clean.
  - The licences match the pub cache: pdf 3.13.1, barcode 2.2.9, printing
    5.15.1 and pdf_widget_wrapper 1.0.4 are Apache-2.0; bidi 2.0.13 is MIT;
    qr 3.0.2 is BSD-3. The versions match the workspace `pubspec.lock`.
  - The font and licence SHA-256 values match the note: `79e85140…16d95` and
    `cfc7749b…3d30`. Sizes are 171,676 B and 11,358 B. The app copies equal the
    vendored ones.

No cross-task defect was found.

## 4. Mutants re-fired on the tip (P-8)

Method: `scratchpad/rf/mut.py`.
1. Back up the file to `scratchpad/rf/`.
2. Apply each edit by exact-string replace, asserting the count is 1.
3. Run `flutter test <file> --timeout 120s` in the foreground, `CI=true`.
4. Copy the backup back and run `diff`.

`diff` exited 0 for every mutant. After the last one, `git status` shows only
the pub-get `analysis_options.yaml`. Line numbers are those of the tip.

| mutant | file:line | mutation | test | real output |
|---|---|---|---|---|
| M-13a | page_export.dart:123,138,8 | PNG paints through `VerticesDrawSink(…, fallback: CanvasDrawSink(…))` + `flush()` + import | export_sources_test / export_png_test | `00:00 +1 -1` "page_export.dart names no VerticesDrawSink…" `Expected: false Actual: <true>` / `00:06 +24 -1` oblique line "intermediate coverage" `Actual: <0>` |
| M-13b | page_export.dart:51 | PDF `pixelsPerPaperMm: 1.0` | export_pdf_test | `00:00 +19 -4: Some tests failed.` T-4 ×4, `…of <1.984251968503937> Actual: <0.7>` |
| M-13c (raw) | page_export.dart:51 | `camera.pixelsPerPaperMm * camera.camera.scale` | export_pdf_test | `00:00 +19 -4` T-4 at 1:50 and 1:100, `Actual: <0.11249>` |
| M-13d | page_export.dart:64,9 | `paint(sink, fitToPage(page, camera.size), …)` + import | export_pdf_test | `00:00 +15 -8` T-5 instance position `Expected: an object with length of <2> Actual: []`, baseline origin, T-4 instance ×2, T-6 ×2 |
| M-13f | page_camera.dart:48 | `sheetWorldRect(page.copyWith(originX: 0, originY: 0))` | page_camera_test | `00:00 +8 -7: Some tests failed.` corners ×3, above-sheet ×3, instance origin |
| M-13g | page_camera.dart:56 | `-k` → `k` (one-line form) | page_camera_test | `00:00 +5 -10: Some tests failed.` |
| M-13i | pdf_draw_sink.dart:137 | `_pushTransform` never pushes (`\|\| true`) | pdf_draw_sink_test | `00:00 +11 -5` `Expected: <= 0.0000068… Actual: <294.3496…>` |
| M-13j | pdf_draw_sink.dart:223 | `theta = s.abs() / n` | pdf_draw_sink_test | `00:00 +14 -2` −110° arc (T-3 and T-3b), `Actual: <49.806006179164>` |
| M-13l | pdf_draw_sink.dart:304 | `scale: null` | pdf_draw_sink_text_test | `00:00 +13 -5` `Expected: a value greater than <20> Actual: <0.0>` |
| M-13m | pdf_draw_sink.dart:298 | extra `setTransform(1 0 0 −1 0 0)` before `drawString` | pdf_draw_sink_text_test | `00:00 +16 -2` direction, `Actual: <3.141592653589793>` |
| M-13n | page_export.dart:61 | PDF `DocumentStyleResolver(document)` | export_pdf_test | `00:00 +21 -2` `Expected: [0, 0, 0] Actual: [1.0, 1.0, 1.0]` |
| M-13p | page_export.dart:62 | PDF `minTextCapPixels: 0.0` removed | export_pdf_test | `00:00 +18 -5` `Expected: ['Yatak Odası', 'WC'] Actual: ['Yatak Odası']` |
| M-13p (PNG) | page_export.dart:133 | PNG `minTextCapPixels: 0.0` removed | export_png_test | `00:06 +24 -1` "WC" … dark pixels, `Actual: <0>` |
| M-13q | draft_painter.dart:404 | `omitOwners.isNotEmpty &&` → `false &&` | omit_owners_test / export_pdf_test | `00:00 +10 -9: Some tests failed.` / `00:00 +22 -1` "T-8 (PDF): … no path lies on its segment" `Expected: empty Actual: [` |
| M-13s | page_export.dart:112 | width `.floor()` | export_png_test | `00:07 +15 -10` `Expected: [794, 1123] Actual: [793, 1123]` |
| M-13u | page_export.dart:120 | no `drawPaint` white ground | export_png_test | `00:07 +21 -4` `Expected: [255, 255, 255, 255] Actual: [0, 0, 0, 0]` |
| M-13v | document_host.dart:572 | Print exports via `exportPagePdf(…, omitOwners: const {})` | print_flow_test | `00:08 +9 -2` PR1, PR2 (operator lists) |
| M-13w | main.dart:561 | `&& _page.value != null` dropped | export_flow_test | `00:10 +16 -2` EX9, EX9b `Expected: false Actual: <true>` |
| M-13x | page_export.dart:41 | `SetComponentCommand<PageComponent>(root, page)` executed first | export_pdf_test | `00:00 +22 -1` T-9 `Expected: <23> Actual: <24>` |
| M-13aa | reference_walk.dart:98 | the walk skips the omitted node's child nodes | omit_owners_test | `00:00 +17 -2` comparison and "reference draws every leaf not owned by an omitted node" |
| M-13ab | export_flow.dart:75 | `printPageFormat` → `PdfPageFormat.standard` | print_flow_test | `00:07 +9 -2` `…of <841.8897637795277> Actual: <595.275590551181>` |
| M-13ac | document_files.dart:103 | suffix from `FileKind.jetplan` | document_files_kind_test | `00:00 +5 -1` FK1 `Expected: 'plan.pdf' Actual: 'plan.jetplan'` |
| 32d488f revert | draft_painter.dart:434 | `accumulated: node.transform` | grouped_root_instance_test / omit_owners_test | `00:00 +0 -1` `Actual: <488.06321745861294>` / `00:00 +11 -8` (incl. the default-set comparison) |
| hook restore removed | page_export.dart:238 | the `finally`'s `..onAfterMutate = …; ..onBeforeMutate = …` deleted | export_pdf_test / export_png_test / app export_flow_test | `00:00 +22 -1` `Expected: <Closure: … '_onChange@…'> Actual: <null>` / `00:07 +24 -1` same / `00:10 +17 -1` EX2 `Expected: [25] Actual: []` |

All 24 are red. The counts differ slightly from the task-time records (for
example M-13l is now 5 tests, not 3) because later commits added tests (4b,
5b, 6b, 9b). Each difference is in the killing direction.

## 5. The results note, the spec amendment, the roadmap

Checked against the ledger and found accurate:
- **Numbers:** app 934 = 885 + 10 + 6 + 16 + 9 + 2 + 2 + 4; render 1001 + 153 = 1154.
- **Gate tails and SHAs:** they match the commits and the reports.
- **Licences:** they match the pub cache.
- **Mutant table:** it matches the reports and reviews.
- **Found-not-fixed:** it carries:
  - the grouped-instance lookup;
  - the latent `CanvasDrawSink` issue (R-13-10);
  - the astral `/ToUnicode`;
  - R-13-19;
  - web print ignoring name and format;
  - the PR8 coupling;
  - the 656 px floor;
  - `clear()`;
  - the JIT frame name;
  - licence idempotence.
- **Look list:**
  - L-1 to L-7 are copied and amended per R-13-22 (web L-1), R-13-7
    (Flutter ≥ 3.44) and the Task 10 review (L-6 web paper).
  - It adds R-13-21 (the panel appends `.pdf`/`.png`) and R-13-23/24
    (656 px, status slot).
  - **Nothing is marked done for the human.**
- **Spec amendment:** it covers R-13-1 to 9, 12, 14 to 19 and 21 to 24.
  - R-13-10 (found-not-fixed) and R-13-13 (a check, reported in the note) need
    no spec change.
  - R-13-11 is subsumed by R-13-14.
  - R-13-20 is missing (finding 2).
- **Roadmap:** `13-export-and-print.md` reads "EXECUTED … NOT MERGED", with
  merge and look pending as the human's, and keeps the old line.
  `00-README.md` row 13 and the summary sentence agree. Correct.

## Findings

1. **Minor (fix before the archive commit). The note omits Task 10b's
   re-review verdict.**
   - Where: `docs/superpowers/notes/2026-10-01-plan-13-results.md:45`.
   - Problem: the row says "its re-review ran in parallel with Task 11". The
     verdict is **Approved**: `task-10-review.md`, "Re-review (10b)",
     "Verdict (10b): Approved". There R10b is red on PR9, R10c on PR3 and PR10,
     and R10d on PR10, with gates at `ff85f02` reading `03:45 +930`.
   - Fix: replace the parenthetical with "-> 10b Approved".
   - Also update lines 29-32 ("The final whole-branch review is still to
     come") to record this review: Ready with fixes, the 24-mutant sample above,
     and the gate tails above.
   - Also update the 11a row (`:46`) to name it.
2. **Minor. The spec amendment does not carry R-13-20.**
   - Where: `docs/superpowers/specs/2026-10-01-export-and-print-design.md`,
     "Amended at execution".
   - Problem: D7 says "The flows read the bytes once per app with
     `rootBundle.load`". Execution made this an `ExportFontCache` owned by
     `FloorPlannerApp` and passed to `DocumentHost.exportFont`. A bare host
     makes its own cache, and a failed read is not held. The licence
     registration in `main()` is now pinned by the source test EF11, not "by
     review only" as R-13-20 first said.
   - The section claims to list "every deviation".
   - Fix: add one bullet (D7, R-13-20, `f625d80`, `1e26b85`, EF11 `4ede95c`).
     Optionally append "superseded by EF11 (4ede95c)" to R-13-20 in
     progress.md before archiving.
3. **Minor. The note and the amendment understate M-13q.**
   - Where: results note `:232` and `:277-279`; spec amendment "M-13q / M-13r
     were fired against T-2; T-8's omission is pinned by the export's own 'set
     not passed' mutants".
   - Fact: on the tip, M-13q is red on T-8 directly
     (`export_pdf_test.dart`: `00:00 +22 -1`, "T-8 (PDF): the separator with
     the separator's group omitted, no path lies on its segment",
     `Expected: empty Actual: [`). This is what the spec's table claims
     (T-2, T-8).
   - Fix: add "and T-8 (PDF), re-fired in the final review" to the M-13q row.
     Keep the sentence about the set-not-passed mutants.
4. **Nit. A doc comment is stale.**
   - Where: `apps/floor_planner/lib/main.dart:228-229`.
   - Problem: `PlannerShell.fileCommands` lists "New, Open, Open sample, Save,
     Save As, Export" and says "its page to Export's". Print is missing,
     although `kPageCommandIds` gates both.
   - Fix: "…Save As, Export, Print … and its page to Export's and Print's
     (`kPageCommandIds`)".
   - This is a lib edit after the `3057e13` freeze, comment only. Either land
     it as a reviewed one-line follow-up, or leave it and record it. It must
     not be bundled silently into a docs commit.

No other finding. The ledger archive (plan Task 11's last commit) remains to do.
