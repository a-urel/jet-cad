# Export and print, sub-project 13 — implementation plan

> **For agentic workers:** executed task by task, subagent-driven: a fresh
> implementer per task and an independent reviewer per task, then a final
> whole-branch review. Steps use checkbox (`- [ ]`) syntax.

**Goal:** `Export…` writes the page as a vector PDF (embedded Roboto, true
scale, true lineweights) or as a PNG at 96 / 150 / 300 dpi; `Print…` hands
the same PDF to the system print dialog. Only the drawing plots; room
separators do not.

**Spec:** [docs/superpowers/specs/2026-10-01-export-and-print-design.md](../specs/2026-10-01-export-and-print-design.md),
**revision 3** (`5b81c1c`, approval recorded at `7c3847b`). Read it whole
before Task 1. It has 11 decisions (D1–D11), 16 facts (F-1–F-16), 13 test
groups (T-1–T-13, T-3b), 30 named mutants (M-13a … M-13ad), 9 risks (R-1–R-9),
7 look items (L-1–L-7) and no open question. It was reviewed independently
twice (W-1–W-20, S-1–S-7). **The human approved it on 2026-10-01**
("onaylıyorum, planı yaz"); the human's decisions 1–12 are at its top.

**Architecture:**
- **Engine** (`packages/jet_cad_2d`): **untouched.**
- **Render layer** (`packages/jet_cad_2d_flutter`): `lib/src/export/
  page_camera.dart` (Task 1), `omitOwners` in `draft_painter.dart` and
  `reference_walk.dart` (Task 2), `lib/src/export/pdf_draw_sink.dart` and the
  content reader (Tasks 3–4), `lib/src/export/page_export.dart` (Tasks 5–6).
  Frozen after Task 6.
- **App** (`apps/floor_planner`): the font (Task 7), `FileKind` (Task 8),
  `lib/export/export_dialog.dart` + `export_flow.dart` and the commands
  (Task 9), printing (Task 10).

**Tech stack:** Dart, Flutter 3.47.2 at `/root/flutter` (if missing,
reinstall the same version from `storage.googleapis.com/flutter_infra_release/
releases/stable/linux/flutter_linux_3.47.2-stable.tar.xz`). **New
dependencies:** `pdf` in the render package (Task 3), `printing` in the app
(Task 10); licences recorded in the task report and the results note.

## Rulings made here rather than left to an implementer

- **P-1 (branch).** `plan-13/export-and-print`, cut from
  `spec-13/export-and-print` at `7c3847b`; worktree `.claude/worktrees/
  plan-13`. Reviews in a detached worktree (`.claude/worktrees/
  plan-13-review`). Reviewed commits are pushed to
  `origin/plan-13/export-and-print`. Merge is the human's, `--no-ff`, from the
  main checkout. The proxy refuses remote branch deletion: name merged
  branches for the human.
- **P-2 (the content reader).** One reader of PDF bytes serves the render
  tests and the app tests, so it lives in the render package's `lib/`, as
  `lib/src/export/testing/pdf_content.dart`, exported by a **separate**
  library `package:jet_cad_2d_flutter/export_testing.dart` that nothing in
  `lib/` imports. It takes the PDF bytes and an `inflate` callback (tests pass
  `zlib.decode` from `dart:io`), finds the page's content stream, tokenises
  it, composes `q`/`Q`/`cm`, and exposes paths (points in page space,
  closed or not, stroke/fill, the width in device units, the colour, the
  ExtGState's `CA`/`ca`), text runs (font, size, `Tz`, the text matrix in
  page space, the CIDs, the string via `/ToUnicode`, the advance from `/W`),
  the page's `MediaBox`, and the raw operator list. It is an instrument:
  **it gets its own tests** (Task 3) on hand-written content streams, so a
  reader bug cannot make a sink test pass.
- **P-3 (the fixture, the testing bar).** One builder, `test/support/
  export_fixture.dart` in the render package, makes spec Testing's fixture
  (page A4 landscape 1:50, origin (3000, −1500), background 0xFF303030;
  every listed entity; the outer group with its own line and its own
  instance, the nested group, the separator-like group). The render package
  does not know `SeparatorParams`: the fixture's "separator" is a childless
  group with one dashed polyline, the shape F-8 describes, and the app tests
  (Tasks 9–10) use a real separator. Nothing sits at the origin, no
  transform is the identity, no style equals its default.
- **P-4 (async).** Pixel reads and `Picture.toImage` run under
  `tester.runAsync`; the PDF path uses `write(PdfStream)` and needs none.
- **P-5 (fonts in tests).** Render tests measure with flutter_test's default
  (Ahem) unless a test says otherwise (spec T-5). A test that wants real
  Roboto loads the vendored file with `FontLoader('Roboto')`, as
  `text_ladder_golden_test.dart` does.
- **P-6 (container restarts).** Every agent commits as soon as its gates are
  green, writes its report early and appends to it, and runs mutants in the
  foreground in small batches; a mutant's backup is restored by `cp` and
  checked by `diff`.
- **P-7 (dependency bounds, spec R-4).** Only the `flutter:` bounds move
  (render package in Task 3, app in Task 10); no `sdk:` bound moves.
  `dev_harness_2d` depends on the render package: its `flutter pub get` and
  analyze must stay green (checked in Task 3 and Task 11).
- **P-8 (mutant tables).** As in 09a and 09b: the results note's mutant table
  is compiled from task reports and reviews; the final review re-fires a
  sample across tasks on the tip.

## Global constraints

- CLAUDE.md's non-negotiables. The frame path changes by one `isNotEmpty`
  per leaf (Task 2, spec D6); the two allocation invariant tests stay
  **unedited** and green.
- `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
- Never `git checkout --` a `.dart` file; mutants by `cp` backup, mutate,
  run the named test file, `cp` back, `diff` exit 0.
- Never commit `analysis_options.yaml` (`flutter pub get` rewrites three of
  them; stage files by explicit path). `pubspec.lock` files are committed
  where they already are tracked, and only those.
- **No golden PNG regenerated**; never pass `--update-goldens`.
- Never synthesize output. Code, comments, commit messages in English.
- `lib/src/export/page_export.dart` names neither `VerticesDrawSink`,
  `TileCache` nor `DraftCanvas` (spec D10, T-11).
- Commit trailers:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01M4zdYkH7yTFAU2aCUA8bdQ
  ```
- Scratch prefix for each agent: a per-agent directory under
  `/tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/`,
  named in its brief.

## Gates (every task)

```sh
export PATH=/root/flutter/bin:$PATH
(cd packages/jet_cad_2d         && CI=true dart test ; CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd packages/jet_cad_2d_flutter && CI=true flutter test ; CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd apps/floor_planner          && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
```
Plus `CI=true flutter build web --release` in the app from Task 3 on (a new
dependency of the render package reaches the app's web build).
Branch point (`main` `a0a1920`): engine 1,121 + 2 standing
(`test/testing/generate_document_test.dart`); render 1,001 + 1 skip + 7
standing (the golden text ladders, Linux only: spec F-10, T-13); app 885.
A task that touches only one package may state the others unchanged rather
than re-run them (say so in the report), except that any task touching
`pubspec.yaml` re-runs every gate.

## File structure

| File | Task |
|---|---|
| `packages/jet_cad_2d_flutter/lib/src/export/page_camera.dart` (new), `lib/jet_cad_2d_flutter.dart`; `test/export/page_camera_test.dart`, `test/support/export_fixture.dart` (new) | 1 |
| `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`, `lib/src/reference_walk.dart`; `test/export/omit_owners_test.dart` (new) | 2 |
| `packages/jet_cad_2d_flutter/pubspec.yaml` (`pdf`, `flutter:` bound); `lib/src/export/pdf_draw_sink.dart`, `lib/src/export/testing/pdf_content.dart`, `lib/export_testing.dart` (new); `test/export/pdf_content_test.dart`, `test/export/pdf_draw_sink_test.dart` (new) | 3 |
| `lib/src/export/pdf_draw_sink.dart` (text); `test/export/pdf_draw_sink_text_test.dart` (new) | 4 |
| `lib/src/export/page_export.dart` (new, PDF half), `lib/jet_cad_2d_flutter.dart`; `test/export/export_pdf_test.dart` (new) | 5 |
| `lib/src/export/page_export.dart` (PNG half); `test/export/export_png_test.dart`, `test/export/export_sources_test.dart` (new) | 6 |
| `apps/floor_planner/assets/fonts/{Roboto-Regular.ttf,Roboto_LICENSE.txt,README.md}` (new), `pubspec.yaml` (font, assets), `lib/export/export_font.dart` (new), `lib/main.dart` (licence); `test/export/export_font_test.dart` (new) | 7 |
| `apps/floor_planner/lib/document_files{,_io,_web,_stub}.dart`, `test/support/fake_document_files.dart`; `test/document_files_kind_test.dart` (new) | 8 |
| `apps/floor_planner/lib/export/{export_dialog,export_flow}.dart` (new), `lib/document_host.dart`, `lib/main.dart`, `lib/shell_commands.dart`; `test/export/export_flow_test.dart` (new) | 9 |
| `apps/floor_planner/pubspec.yaml` (`printing`, `flutter:` bound), `lib/export/page_printer.dart` (new), `export_flow.dart`, `document_host.dart`, `macos/Runner/{DebugProfile,Release}.entitlements`; `test/export/print_flow_test.dart` (new) | 10 |
| `apps/floor_planner/test/export/export_end_to_end_test.dart` (new); `docs/superpowers/notes/2026-10-01-plan-13-results.md` (new); the spec's "Amended at execution"; `roadmap/13-export-and-print.md`, `roadmap/00-README.md`; the ledger archive | 11 |

---

### Task 1: Render — the page camera and the fixture (spec D2, T-1)

- [ ] `class PageCamera { final ViewportTransform camera; final Size size;
  final double pixelsPerPaperMm; }` and `PageCamera pageCamera(PageComponent
  page, double unitsPerPaperMm)`: spec D2 exactly — `k = u / den`, `x' =
  (x − S.minX)·k`, `y' = (S.maxY − y)·k`, size `(effW·u, effH·u)` unrounded,
  `pixelsPerPaperMm = u`. Reads the page only. Throws `ArgumentError` for a
  non-finite or non-positive `u`.
- [ ] `test/support/export_fixture.dart` (P-3): a builder returning the
  document, the page, and the handles a test needs by name (`instance`,
  `separatorGroup`, `outerGroup`, `outerGroupLine`, `outerGroupInstance`,
  `nestedGroup`, `nestedLine`, `aci7Line`, `outsideLine`, `labelBig`,
  `labelWc`, `pointInInstance`, `arc`, `circle`, `fill`, `dashed`,
  `closedPolyline`). The dashed line needs the DASHED linetype record: copy
  its values into the fixture (the render package does not import the app).
- [ ] T-1: the four sheet corners map to `(0,0)`, `(W,0)`, `(W,H)`, `(0,H)`
  within `Tolerance` for A4 landscape at 1:50 with the fixture's origin, A4
  portrait at 1:100, A3 landscape at 1:20; a 1,000 mm world segment along x
  and along y is `1000/den·u` long; the size is unrounded at `u = 150/25.4`;
  a world point above the sheet's top maps to a negative y.
- [ ] Mutants: **M-13f** (`originX`/`originY` ignored), **M-13g** (no y flip).
- [ ] Export from the library; render gate; others unchanged. Commit
  `feat(render): the page camera for export`.

### Task 2: Render — `omitOwners` (spec D6, T-2)

- [ ] `DraftPainter({…, Set<Handle> omitOwners = const {}})`, `final`; in
  the root leaf stream and in a container's leaves, before anything is
  resolved: `if (omitOwners.isNotEmpty && omitOwners.contains(
  document.entities.ownerAt(slot))) continue/return`. `debugOnVisit` is not
  called for a skipped leaf.
- [ ] `referenceWalk(…, {…, Set<Handle> omitOwners = const {}})`: at a node
  `h` in the set, skip `leaves[h]` and still recurse into `h`'s child nodes
  (spec D6's own route).
- [ ] T-2 on the fixture at the page camera (`pageCamera(page, 72/25.4)`),
  both with `omitOwners = {separatorGroup, outerGroup}` and
  `minTextCapPixels: 0`, into `RecordingDrawSink`, compared with
  `test/support/sink_comparison.dart`: equal; the lists contain ops for the
  instance's leaves, both labels, `nestedLine`, `outerGroupInstance`'s
  leaves; contain none at `separatorGroup`'s or `outerGroupLine`'s points
  nor `outsideLine`'s. Also: with the default (empty) set both draw the
  separator and `outerGroupLine`. Use `debugHandle` on `BeginResidualOp`
  where it identifies a leaf, otherwise compare points.
- [ ] Confirm the existing differential and allocation tests are green and
  **unedited** (`git diff --stat` on both invariant files empty).
- [ ] Mutants: **M-13q** (the painter ignores the set), **M-13r** (the
  leaf's own handle tested instead of its owner), **M-13aa** (the walk skips
  the subtree). Each must turn T-2 red; for M-13q and M-13r say which
  assertion fired (the comparison or the content check).
- [ ] Render gate. Commit `feat(render): omitOwners in the painter and the
  reference walk`.

### Task 3: Render — `PdfDrawSink` geometry and the content reader (spec D3 without text, T-3, T-3b)

- [ ] `pubspec.yaml`: `pdf:` at the newest version this workspace resolves
  (expected `^3.13.1`); raise `flutter:` to the bound it needs (P-7). Run
  `flutter pub get` at the workspace root; stage only the pubspec (and the
  lock file if tracked). Record `pdf` and each **new** transitive package
  with its licence (read each package's `LICENSE` in the pub cache) in the
  report. `apps/dev_harness_2d`: `flutter analyze` green.
- [ ] The reader (P-2) and its tests on hand-written uncompressed content
  streams: `q`/`Q` nesting restores the CTM; `cm` composes in PDF order
  (`cm` premultiplies the CTM); `re`; `h`; numbers like `.5`, `-0.25`, `3`;
  `TJ` arrays of hex strings with kerning numbers; a FlateDecode stream
  through the callback. Each reader test is named for the reader bug it
  catches.
- [ ] `PdfDrawSink({required PdfDocument document, required PdfPage page,
  required double pixelsPerPaperMm, …text parameters reserved for Task 4})`
  per spec D3: page set-up (`cm [1 0 0 −1 0 H]`, `J 0`, `j 0`, `4 M`) once
  on the first op or at construction; residuals deferred, `q … Q` only if
  pushed; stroke width `lw/100·u / residual.scaleMagnitude`, `0 w` at 0;
  polyline, circle (four 90° cubics), arc (signed sweep, ≤ 90° per cubic,
  handle `4/3·tan(θ/4)`), fills (`f`), point (residual applied by hand,
  axis-aligned square of side `lw/100·u`, nothing at 0); **state in full per
  primitive** (colour, width, `gs` with an ExtGState per alpha, alpha 255
  included); `shadesDashes` false, `beginDash`/`endDash` throw; `text`
  throws `UnimplementedError` until Task 4.
- [ ] T-3: the fixture painted at the page camera into a
  `RecordingDrawSink`, the ops replayed into a `PdfDrawSink` on a
  `PdfDocument(compress: false)`, the bytes read back: each path's points
  match the op's points through the op's residual and the page set-up,
  within the spec's bound (write `pdfTolerance(x, y, ctm)` in the test
  support, the 5-decimal rule); a sampled point on each arc cubic lies on its
  circle within that bound plus `2.7e-4·r`; the −110° arc's midpoint is on
  the sweep's side; the point marker is an axis-aligned square in device
  space with side `lw·u`. **T-3b**: direct calls — `closed: true` writes
  `h` before `S`, `false` does not; an opaque stroke after a 0x80 fill is
  under `CA`/`ca` 1; a stroke after a residual's `Q` writes its colour and
  width again; `beginDash` throws.
- [ ] Mutants: **M-13h** (no page set-up flip), **M-13i** (residual
  ignored), **M-13j** (`|sweep|`), **M-13k** (no `h`), **M-13y** (no `gs`
  for an opaque op), **M-13z** (state cached across `Q`), **M-13ad**
  (point under `cm`), and at the sink level **M-13b** (`u` dropped from the
  width; the width assertion of T-3) — Task 5 kills it again end to end.
- [ ] All gates (pubspec moved) incl. web build and `dev_harness_2d`
  analyze. Commit `feat(render): PdfDrawSink geometry`.

### Task 4: Render — `PdfDrawSink` text (spec D3 "text", T-5 at the sink)

- [ ] The sink takes `required Uint8List fontBytes`, `required
  FlutterTextMeasurer measurer`, `required TextStyleRecord Function(Handle)
  textStyleOf` (as `CanvasDrawSink`); one `PdfTtfFont` from the bytes.
  `text(text, style, resolved)`: under the residual (pushed as for any
  primitive), `BT`, the font at `kNominalTextPixels`, `Tz = 100 ·
  w_flutter / w_pdf` with `w_pdf` from the font's widths **as the package
  writes them** (integer thousandths of an em; compute it the way
  `ttffont.dart` truncates), fill colour and `gs` as any primitive, `0 0 Td`,
  the string, `ET`. No extra flip.
- [ ] T-5 at the sink (Ahem measurer, P-5; the vendored Roboto bytes read by
  `File` from `test/golden/fonts/`): ops recorded from the fixture replayed;
  the reader's text runs: size `kNominalTextPixels`; `/Type0` over
  `CIDFontType2` with `FontFile2`; advance-from-`/W` · `Tz/100` equals the
  measured width within the bound; the run's origin in page space is the
  residual's image of glyph `(0,0)` through the page set-up; **direction**:
  the page-space image of text-space `(0,1)` equals `pageSetUp · residual ·
  (0,1)` as a direction (spec T-5, S-3); "Yatak Odası" through
  `/ToUnicode`; "WC" present (the ops were recorded with
  `minTextCapPixels: 0`).
- [ ] Mutants: **M-13l** (`Tz` omitted), **M-13m** (an extra y flip).
- [ ] Render gate. Commit `feat(render): PdfDrawSink text`.

### Task 5: Render — `exportPagePdf` (spec D4, T-4, T-5, T-6, T-8, T-9 for the PDF)

- [ ] `Future<Uint8List> exportPagePdf({required DraftDocument document,
  required PageComponent page, required Uint8List fontBytes, Set<Handle>
  omitOwners = const {}, @visibleForTesting bool compress = true})` per spec
  D4: `pageCamera(page, 72/25.4)`, `PdfPageFormat(size)`, a
  `SpatialIndex` disposed in `finally`, `DocumentStyleResolver(document,
  foreground: 0x000000)`, `DraftPainter(minTextCapPixels: 0.0,
  omitOwners:)`, a `PdfDrawSink`, its own `FlutterTextMeasurer` cleared in
  `finally`; the bytes from `write(PdfStream)`. Export it.
- [ ] Tests, all through `exportPagePdf(compress: false)` (spec "Route per
  test"): **T-4** the instance's 0.70 mm override is `1.98425…` pt and a
  0.35 mm line `0.99213…` pt (width × CTM scale) at 1:50 **and** with the
  page set to 1:100; lineweight 0 writes `0 w`; MediaBox is the page in pt.
  **T-5** "WC" present; a known leaf's first point (the instance's) at its
  expected page-space position. **T-6** the ACI 7 line strokes `0 0 0 RG`
  on the dark page; the instance's leaves red; the 0x80 fill under `ca`
  0.50196…, the next opaque op under 1. **T-8 (PDF)** with `omitOwners =
  {separatorGroup}`: no path at its points. **T-9** codec bytes and
  `commands.stateId` equal before and after.
- [ ] Mutants: **M-13b** (end to end), **M-13c** (width × camera scale; red
  at 1:100), **M-13d** (`fitToPage(page, size)` instead of `pageCamera`;
  T-5's position), **M-13n** (default white foreground), **M-13o** (alpha
  ignored), **M-13p** (`minTextCapPixels` default), **M-13x** (the export
  dispatches a command, e.g. `AttachComponentCommand` of the same page).
- [ ] Render gate. Commit `feat(render): exportPagePdf`.

### Task 6: Render — `exportPagePng` (spec D5, D10, T-7, T-8, T-9 for the PNG, T-11)

- [ ] `enum ExportDpi { d96, d150, d300 }` with `int get value`;
  `Future<Uint8List> exportPagePng({required DraftDocument document, required
  PageComponent page, ExportDpi dpi = ExportDpi.d150, Set<Handle> omitOwners
  = const {}})` per spec D5: size `round(effW/25.4·dpi)` ×
  `round(effH/25.4·dpi)`; camera at `u = dpi/25.4`; white ground; a
  `CanvasDrawSink(pixelsPerPaperMm: u, measurer: own, textStyleOf:
  document.textStyleOf)`; resolver and painter as Task 5; `toImage`,
  `toByteData(png)`; exactly one `pHYs` (pixels per metre `round(dpi /
  0.0254)`, unit 1, CRC-32 computed in Dart) inserted after `IHDR`; image,
  picture, index disposed and measurer cleared in `finally`.
- [ ] Tests (under `tester.runAsync`): **T-7** sizes for A4 and A3, portrait
  and landscape, at each dpi (A4 landscape 150 → 1754 × 1240); one `pHYs`
  before the first `IDAT` with the expected value; at 300 dpi a horizontal
  0.50 mm line (add one to a test-local document) dark on its expected row,
  white at ± (width/2 + 2) px; an oblique line, sampled away from text, has
  intermediate-coverage pixels; corners white and opaque; "WC"'s box has
  dark pixels. **T-8 (PNG)**: every pixel in the separator's segment band
  white with it omitted, some dark without. **T-9** codec bytes and
  `stateId` unchanged. **T-11** `test/export/export_sources_test.dart`
  reads `lib/src/export/page_export.dart`: no `VerticesDrawSink`,
  `TileCache`, `DraftCanvas`; has `CanvasDrawSink` and `PdfDrawSink`.
- [ ] Mutants: **M-13a** (`VerticesDrawSink` + `flush`; T-11 and the
  coverage check — report both), **M-13e** (a `TileCache` built in the
  export; T-11), **M-13s** (`floor`), **M-13t** (`dpi / 0.254`), **M-13u**
  (no white ground), **M-13p** again on the PNG.
- [ ] Render gate incl. `flutter test --tags golden`: exactly the 7
  standing failures, `git diff --stat -- test/golden/` empty. Commit
  `feat(render): exportPagePng`. **The render layer is frozen after this
  task** (a later need is a reviewed follow-up, not an edit in an app task).

### Task 7: App — the font (spec D7, T-12)

- [ ] Copy `packages/jet_cad_2d_flutter/test/golden/fonts/Roboto-Regular.ttf`
  and `Roboto_LICENSE.txt` byte-identical to `apps/floor_planner/assets/
  fonts/` (`cp`, then `cmp`); a `README.md` there: source (that file, from
  Flutter 3.27.3's `material_fonts`), SHA-256 `79e851404657dac2106b3d22ad256d
  47824a9a5765458edb72c9102a45816d95`, Apache 2.0, "copied unmodified,
  2026-10-01, plan 13 Task 7".
- [ ] `pubspec.yaml`: `fonts:` family `Roboto` → the asset; `assets:` lists
  the licence file. `lib/export/export_font.dart`: `Future<Uint8List>
  loadExportFont([AssetBundle? bundle])` (`rootBundle` by default), cached per
  app by `FloorPlannerApp`. `main()` registers the licence with
  `LicenseRegistry.addLicense` (read through `rootBundle`).
- [ ] T-12: the app's copy equals the vendored file byte for byte (`File`),
  its SHA-256 is the recorded one (compute with `package:crypto` only if it
  is already a direct dependency; otherwise compare bytes and record the
  digest in the README verified by `sha256sum` in the report); the licence
  files are equal; `loadExportFont()` in a `testWidgets` returns those bytes;
  the licence is registered (read `LicenseRegistry.licenses`).
- [ ] Mutant: the licence registration removed (its test red).
- [ ] App gate + web build. Commit `feat(app): bundle Roboto for the screen
  and the PDF`.

### Task 8: App — `FileKind` (spec D8 "DocumentFiles", M-13ac)

- [ ] `enum FileKind { jetplan, pdf, png }` with `extension`, `typeGroup`
  (`XTypeGroup(label:, extensions:)`) and `mimeType`
  (`application/json`, `application/pdf`, `image/png`); `String?
  fileNameFor(String? typed, FileKind kind)` generalising `jetplanFileName`
  (which stays as `fileNameFor(typed, FileKind.jetplan)`).
- [ ] `DocumentFiles.saveLocation(String suggestedName, {FileKind kind =
  FileKind.jetplan})` and `write(Object location, String name, Uint8List
  bytes, {FileKind kind = FileKind.jetplan})`; io: the kind's type group in
  `getSaveLocation`, an appended extension when the chosen path lacks it
  (as for `.jetplan` today, if the io side does that — follow its current
  rule); web: `fileNameFor` and the kind's MIME type; stub accordingly. The
  fake records `kind` per call.
- [ ] Tests: `fileNameFor` per kind (`plan` → `plan.pdf`, `plan.png`,
  `plan.jetplan`; `plan.png` as PNG unchanged; blank → null); the existing
  file-flow tests unchanged and green (the defaults).
- [ ] Mutant: **M-13ac** (the web path appends `.jetplan` for every kind —
  mutate `fileNameFor` to ignore `kind`).
- [ ] App gate + web build. Commit `feat(app): file kinds for export`.

### Task 9: App — `Export…` (spec D8, T-10 for export)

- [ ] `export_dialog.dart`: `Future<ExportChoice?> showExportDialog(
  BuildContext, ExportChoice initial)`; `ExportChoice(format: pdf|png, dpi:
  ExportDpi)`; `SegmentedButton`s; Export / Cancel; Esc cancels. Keys:
  `export-format-pdf`, `export-format-png`, `export-dpi-96|150|300`,
  `export-ok`, `export-cancel`.
- [ ] `export_flow.dart` and the host: `ShellCommand(id: 'export', label:
  'Export…', icon: Icons.ios_share_outlined, shortcuts: kExportChords)`
  after Save As, a flow under busy after `_settlePendingInput`; it reads the
  page from the document's root (`PageComponent`), returns if none; dialog
  (initial = the host's last choice this session); `saveLocation('<name>.pdf'
  | '.png', kind:)`; `exportPagePdf` / `exportPagePng` with `omitOwners:
  liveObjectsOf<SeparatorParams>(doc).toSet()` and the cached font bytes;
  `write(…, kind:)`; a throw → `_showError('Export failed', e)`.
- [ ] `shell_commands.dart`: `kExportChords` (Cmd/Ctrl+E) and
  `kPrintChords` (Cmd/Ctrl+P, used in Task 10) join `kFileChords`. The
  shell (`main.dart`) wraps `export` (and `print`, Task 10) with a
  `DerivedFlag` over its `PageNotifier` (`page != null`) in addition to idle.
- [ ] T-10 (export half), a pumped host with a fake `DocumentFiles`, a
  document with a page (fixture origin and scale), a **real separator**
  and an instance, the camera **zoomed to 400 % and panned off the sheet**;
  PNG flows under `tester.runAsync`: PDF writes `<name>.pdf`, `kind: pdf`,
  whose content (P-2 reader, `zlib.decode`) has the instance's first point
  at its page-camera position and no path at the separator; PNG at 300 dpi
  writes `<name>.png` of A4's 300-dpi size; Cancel in the dialog, or a null
  `saveLocation`, writes nothing; disabled with no page and while busy;
  Cmd/Ctrl+E opens the dialog; with the dialog open Ctrl+P is consumed (no
  print, the key handled); a throwing write shows the error dialog.
- [ ] Mutants: **M-13d** at the flow (the shell's camera handed in some way
  is not expressible — record that; instead mutate the flow to export with
  `PageComponent()` default page rather than the document's: T-10 red),
  **M-13w** (enabled without a page), the separator set left empty
  (T-10's separator check).
- [ ] App gate + web build. Commit `feat(app): Export…`.

### Task 10: App — `Print…` (spec D9, T-10 for print)

- [ ] `pubspec.yaml`: `printing:` at the newest version this workspace
  resolves (expected `^5.15.1`); raise the app's `flutter:` bound to its
  requirement (P-7); licences of `printing` and new transitive packages in
  the report. Both entitlement files gain `com.apple.security.print` =
  `true`.
- [ ] `page_printer.dart`: `abstract interface class PagePrinter { Future<void>
  print(Uint8List pdf, String name, PdfPageFormat format); }`; the
  production `PrintingPagePrinter` calls `Printing.layoutPdf(onLayout: (_)
  async => pdf, name:, format:, dynamicLayout: false)`. Injected through
  `FloorPlannerApp` / `DocumentHost` like `files`.
- [ ] `ShellCommand(id: 'print', label: 'Print…', icon:
  Icons.print_outlined, shortcuts: kPrintChords)` after Export, enabled as
  Export; the flow exports **once** (same `omitOwners`, same font) and hands
  those bytes, the document's name and `PdfPageFormat(effW·72/25.4,
  effH·72/25.4)` to the printer; a throw → `_showError('Print failed', e)`.
- [ ] T-10 (print half): the fake printer receives bytes whose content
  stream equals an `exportPagePdf` of the same document (via the reader,
  operator lists equal) and the page's size in pt; no separator path; called
  once; Cmd/Ctrl+P invokes it; disabled with no page and while busy.
- [ ] Mutants: **M-13v** (print exports with an empty `omitOwners`),
  **M-13ab** (no `format` — model it as passing `PdfPageFormat.standard`),
  print enabled without a page.
- [ ] All gates (pubspec moved) incl. web build and `dev_harness_2d`
  analyze. Commit `feat(app): Print…`.

### Task 11: End to end, sweep, results, the ledger (spec Exit gate)

- [ ] `export_end_to_end_test.dart`: `FloorPlannerApp` with fake files and
  printer, Open sample, export PDF and PNG (150) and print; the PDF's
  MediaBox is the sample's page in pt, it has text runs, its font is
  embedded; the PNG's size is the page's at 150 dpi; Save after the exports
  is byte-identical to Save before them (the document untouched through the
  flows).
- [ ] P-8: the mutant table compiled from task reports and reviews; the
  final review re-fires a sample on the tip.
- [ ] The two allocation invariant tests unedited (empty diff); no
  `analysis_options.yaml`; the golden directory's diff empty and the golden
  tag at exactly the 7 standing failures (T-13); greps: `page_export.dart`
  (T-11), the engine's diff empty.
- [ ] `docs/superpowers/notes/2026-10-01-plan-13-results.md` (09b form):
  gates, the mutant table, the dependency licences, the risks seen, found-
  not-fixed, and **the human's look list** L-1–L-7 copied from the spec
  (nothing marked done for them), plus R-4's toolchain note; "Amended at
  execution (Plan 13)" in the spec; roadmap 13 and 00 status.
- [ ] The final whole-branch review (separate detached worktree), its fixes,
  then the ledger archive to `docs/superpowers/ledgers/2026-10-01-plan-13/`
  with a README row, as the branch's last commit.
- [ ] All gates + web. Commits `test(app): export and print end to end`,
  `docs: plan 13 results`, `docs: archive the plan 13 ledger`.

## Mutant ownership

| Task | Mutants |
|---|---|
| 1 | M-13f, M-13g |
| 2 | M-13q, M-13r, M-13aa |
| 3 | M-13b (sink), M-13h, M-13i, M-13j, M-13k, M-13y, M-13z, M-13ad |
| 4 | M-13l, M-13m |
| 5 | M-13b, M-13c, M-13d, M-13n, M-13o, M-13p, M-13x |
| 6 | M-13a, M-13e, M-13p (PNG), M-13s, M-13t, M-13u |
| 8 | M-13ac |
| 9 | M-13w, the flow's page and separator set |
| 10 | M-13v, M-13ab |

## Exit gate (13)

- Engine byte-unchanged and green (1,121 + 2 standing); render green except
  the 7 standing golden failures (no new failure, no golden PNG changed);
  app green; `flutter build web --release` builds; `dev_harness_2d` analyze
  green; the two allocation invariant tests unedited and green.
- Every named mutant fired red (any equivalent one recorded by experiment),
  re-fired by the reviewer; the final review's sample on the tip.
- Dependency licences recorded.
- **The human's look on macOS and web**, L-1–L-7 of the spec; never marked
  done for the human. The human's macOS Flutter must meet the new bound
  (R-4).
- Merge on the human's word, `--no-ff`, from the main checkout; STATUS
  through a small docs branch merged `--no-ff`; `main` pushed; worktrees and
  local branches removed; merged remote branches named for the human.
