# Task 5 report — exportPagePdf (spec D4; T-4, T-5, T-6, T-8, T-9 for the PDF)

**Commits** (on `94653f6`, not pushed):
- `d3063ab` fix(render): PdfDrawSink text follow-ups (Task 4 review) — "4b"
- `c134c14` feat(render): exportPagePdf
- `72827ed` test(render): exportPagePdf measures each text under its own style (added after OWN-ex-style survived against `c134c14`)

## 4b: the Task 4 review's findings

| Finding | What changed | Pinned by |
|---|---|---|
| 1 (R-13-14) | `PdfDrawSink.measurer` is typed `TextMeasurer`; the `flutter_text_measurer.dart` import is gone. | `pdf_draw_sink_text_test.dart` "any TextMeasurer: a MetricModelMeasurer's 0.55 em per glyph…" (direct call, `MetricModelMeasurer(advanceRatio: 0.55)`, advance == 605). Mutant OWN-fresh. |
| 2 | Direct-call test with `_PerStyleMeasurer` (width from `style.name`: Standard 0.55, Label 0.35) and a second record "Label"; the fixture's "WC" now uses its own text style record (`labelWcStyle`, "Label", family `Arial`); `export_fixture_test.dart` checks it. | OWN-style |
| 3 | Reader test: `/FontFile2` as a direct dictionary, and as a reference to a number → `fontFile == null`. | OWN-rd-ff |
| 4 | The reader's `utf16` (and the bfrange base) throws `FormatException` unless the hex is a non-empty multiple of 4; test for bfchar `<1F600>`, bfrange `<1F600>`, bfrange array `[<00E>]`, plus a well-formed surrogate pair `<D83DDE00>` reading as U+1F600. | OWN-utf16 |
| 5 | `text()` throws `StateError` unless `_font.isCidFont`, **before** `_pushTransform`/`_fillState`. Testable: `PdfDocument(simpleTrueTypeFonts: true)` builds such a font. The test asserts the throw and that the content after it is exactly `cm J j M RG w gs m l S` (no `q`, `cm`, `rg` or `gs` left behind), and that the same call on a default document draws. | OWN-cid, OWN-cid-late |

**For the results note (finding 4):** pdf 3.13.1 writes a malformed `/ToUnicode` destination for a code point above U+FFFF: `<1F600>` (five hex digits, `unicode_cmap.dart`, `toRadixString(16).padLeft(4)`), not the UTF-16BE surrogate pair `<D83DDE00>`. A viewer's copy/search of such a character is wrong; the floor planner's labels are BMP. The reader now refuses it rather than truncating.

Note on the empty-page rule (R-13-9): a stream that only has the page set-up is dropped by the package (`altered` is set by painting ops only), which is why the CID-guard test strokes a line after the refused text.

## Task 5: `lib/src/export/page_export.dart`

`exportPagePdf({document, page, fontBytes, omitOwners = const {}, @visibleForTesting compress = true})`, exported from `jet_cad_2d_flutter.dart`:
`pageCamera(page, 72/25.4)`; `PdfDocument(compress:)`; `PdfPage(pageFormat: PdfPageFormat(camera.size.width, camera.size.height))`; `SpatialIndex(document)` disposed in `finally`; `PdfDrawSink(pixelsPerPaperMm: camera.pixelsPerPaperMm, fontBytes, measurer: document.textMeasurer, textStyleOf: document.textStyleOf)`; `DraftPainter(resolver: DocumentStyleResolver(document, foreground: 0x000000), minTextCapPixels: 0.0, omitOwners:)`; `paint(sink, camera.camera, camera.size)`; bytes from `pdf.write(PdfStream)` (no `save()`, no isolate). It names no `VerticesDrawSink`, `TileCache`, `DraftCanvas`, `fitToPage`.

**Plan deviation (inside spec D4, ruling R-13-14):** no own `FlutterTextMeasurer` on the PDF path; the sink measures with `document.textMeasurer`, the instance the painter laid the box out with.

## Tests: `test/export/export_pdf_test.dart` (20), all through `exportPagePdf`
Fixture document measured by an Ahem `FlutterTextMeasurer` unless stated. Expected positions are computed from the page's numbers alone: world `(x, y)` → `((x − 3000)/den · u, (y + 1500)/den · u)` in PDF page space (y up), never through `pageCamera`.

- **T-4** (a group per scale, 1:50 and 1:100, each with a test-local lineweight-0 line added by command):
  MediaBox `[0 0 297u 210u]`; the two stroked paths starting at the instance's (200, 100) image have `w × sqrt|det CTM|` == `0.70 · 72/25.4` (1.98425…) within `pdfWidthTolerance`; the 0.35 mm line (0x1565C0) == 0.99213…; the lineweight-0 line writes `0 w`.
- **T-5**: runs `['Yatak Odası', 'WC']`; the instance's first point found at its independent position (two strokes: line and polyline); each run's origin == its insertion point's page position within `2·5e-6 + 1e-9` (real errors: −7.9e-8/3.1e-6 and −3.9e-7/−3.1e-7 pt).
- **T-6**: ACI 7 line `RG` operands `[0, 0, 0]` with `page.background == 0xFF303030`; the instance's strokes `[1, 0, 0]` and its point marker (a filled square centred on the point's image within `3·5e-6`) fills red; the 0x1E88E5 fill `ca` == 128/255 (0.50196…), the next path has `CA` = `ca` = 1 and a `gs`.
- **T-8 (PDF)**: with `{separatorGroup}` no path lies on the separator's page segment (every vertex within 0.01 pt); without the set, at least one does.
- **T-9**: `DraftDocumentCodec.encodeToString` and `commands.stateId` (≠ 0) equal before/after.
- **Measurer pins**: a `MetricModelMeasurer(0.55)` fixture → each run's advance == runes · 55; a `_PerStyleMeasurer` fixture → "Yatak Odası" 605, "WC" (Label) 70.
- **compress: true** smoke: bytes start `%PDF-`, read back with `zlib.decode`, operator list equal to the `compress: false` export's, both strings present.

Position bound for "path starts at": worst-case 5-decimal rule per written number (residual entries × |operand|, operands × linear part, H) with the residual recovered as `CTM × [1 0 0 −1 0 H]`.

## Gates (real tails)
Render, `CI=true flutter test`:
- after 4b (`d3063ab`): `00:56 +1104 ~1 -7: Some tests failed.` (1099 + 2 reader + 3 sink)
- after `c134c14`: `00:54 +1123 ~1 -7: Some tests failed.` (+19)
- after `72827ed`: `00:59 +1124 ~1 -7: Some tests failed.` (+1)
- the 7 `[E]` (deduplicated) are exactly text ladder rung 1–5 and text lod ladder rung 1–2 (RenderBackend.canvas); both allocation invariant files ran green inside the suite.
- `flutter analyze`: `No issues found! (ran in 1.8s)`; `dart format --output=none --set-exit-if-changed .`: `Formatted 198 files (0 changed)`, exit=0.
- `git diff --stat 94653f6..HEAD -- packages/jet_cad_2d apps packages/jet_cad_2d_flutter/test/golden packages/jet_cad_2d_flutter/test/invariants` prints nothing. Changed files: only render-package `lib/jet_cad_2d_flutter.dart`, `lib/src/export/{page_export,pdf_draw_sink,testing/pdf_content}.dart`, `test/export/{export_pdf,pdf_content,pdf_draw_sink_text}_test.dart`, `test/support/export_fixture{,_test}.dart`.

Engine and app: **not re-run, unchanged** (no pubspec touched; the app does not reference `exportPagePdf`/`PdfDrawSink` yet; engine diff empty). `analysis_options.yaml` left unstaged.

## Mutants
Runner `scratchpad/e5/mut.py` (cp backup, exact replacement(s) with match-count check, the named test file in the foreground, cp back, diff). Every run printed `RESTORED diff=0`. Logs in `scratchpad/e5/<id>.log`.
E = `lib/src/export/page_export.dart`, ET = `test/export/export_pdf_test.dart`, Sink = `lib/src/export/pdf_draw_sink.dart`, ST = `test/export/pdf_draw_sink_text_test.dart`, R = `lib/src/export/testing/pdf_content.dart`, RT = `test/export/pdf_content_test.dart`.

| id | where / mutation | red tests | real output |
|---|---|---|---|
| OWN-fresh (4b, two edits: import + call) | Sink `text`: `FlutterTextMeasurer().measure(...)` | ST MetricModel test (`within <0.0000277…> of <605> Actual: <1100.0000144…>`), ST per-style test | `00:00 +16 -2: Some tests failed.` |
| OWN-style (4b) | Sink: `textStyleOf(ReservedHandles.standardTextStyle)` | ST per-style (`of <70> Actual: <110.00000063>`) | `00:00 +17 -1: Some tests failed.` |
| OWN-rd-ff (4b) | R: `descriptor?[key] != null` | RT "names a program only when the key resolves to a stream" (`Expected: ['/CIDFontType2', null] Actual: ['/CIDFontType2', '/FontFile2']`) | `00:00 +25 -1: Some tests failed.` |
| OWN-utf16 (4b, two edits: no throw + old `i + 3 <` loop) | R `utf16Units` | RT "/ToUnicode destination … throws" (`Expected: throws <Instance of 'FormatException'> Actual: <Closure: () => PdfContent>`) | `00:00 +25 -1: Some tests failed.` |
| OWN-cid (4b) | Sink: `if (false)` for the CID guard | ST simple-TrueType test (`Expected: throws <Instance of 'StateError'>`) | `00:00 +17 -1: Some tests failed.` |
| OWN-cid-late (4b) | Sink: `_pushTransform()` before the guard | ST same test (`Actual: ['cm', 'J', 'j', 'M', 'q', 'cm', 'Q', 'RG', …]`) | `00:00 +17 -1: Some tests failed.` |
| M-13b | E: `pixelsPerPaperMm: 1.0` | ET T-4 0.70 and 0.35 at 1:50 and 1:100 (`of <1.98425…> Actual: <0.7>`, `of <0.99212…> Actual: <0.35>`) | `00:00 +15 -4: Some tests failed.` |
| M-13c | E: `camera.pixelsPerPaperMm * (50 / page.scaleDenominator)` (width follows the camera's scale, right at 1:50) | ET T-4 **at 1:100 only** (`Actual: <0.99213>`, `Actual: <0.49606>`) | `00:00 +17 -2: Some tests failed.` |
| M-13c-k | E: `camera.pixelsPerPaperMm * camera.camera.scale` | ET T-4 at both scales (`Actual: <0.11249>`, `<0.05625>`) | `00:00 +15 -4: Some tests failed.` |
| M-13d (two edits: import + call) | E: paints with `fitToPage(page, camera.size)` | ET T-5 instance position (`length of <2> Actual: []`), T-5 baseline origin (`of <85.03937…> Actual: <101.83465>`), T-4 instance width ×2 (finder empty), T-6 ACI 7 and instance red, T-8 without the set | `00:00 +12 -7: Some tests failed.` |
| M-13n | E: `DocumentStyleResolver(document)` (white foreground) | ET T-6 ACI 7 (`Expected: [0, 0, 0] Actual: [1.0, 1.0, 1.0]`) | `00:00 +18 -1: Some tests failed.` |
| M-13o | Sink `_alpha`: `const opacity = 1.0;` | ET T-6 0x80 fill (`of <0.50196…> Actual: <1.0>`) | `00:00 +18 -1: Some tests failed.` |
| M-13p | E: `minTextCapPixels: 0.0` removed (default 3) | ET T-5 labels (`Expected: ['Yatak Odası', 'WC'] Actual: ['Yatak Odası']`), T-5 origin, MetricModel pin, compress smoke | `00:00 +15 -4: Some tests failed.` |
| M-13x | E: `document.commands.execute(SetComponentCommand<PageComponent>(document.rootHandle, page))` before painting | ET T-9 (`Expected: <23> Actual: <24>`) | `00:00 +18 -1: Some tests failed.` |
| OWN-ex-measurer (two edits) | E: `measurer: FlutterTextMeasurer()` | ET MetricModel pin (`of <605.0000000000001> Actual: <1100.0000144…>`) | `00:00 +18 -1: Some tests failed.` |
| OWN-ex-omit | E: `omitOwners:` not passed to the painter | ET T-8 omitted (`Expected: empty Actual: [`) | `00:00 +18 -1: Some tests failed.` |
| OWN-ex-format | E: `PdfPageFormat(height, width)` | ET MediaBox (`of <841.889…> Actual: <595.27559>`) and 8 more | `00:00 +10 -9: Some tests failed.` |
| OWN-ex-style | E: `textStyleOf: (_) => document.textStyleOf(standardTextStyle)` | **survived** at `c134c14` (`00:00 +19: All tests passed!`); after `72827ed`: ET per-style (`of <70> Actual: <110.00000063>`) | `00:00 +19 -1: Some tests failed.` |
| OWN-ex-dispose | E: `index.dispose()` commented out | **survives** (`00:00 +19: All tests passed!`): disposal is not observable from the output; not pinned. | |

## What the spec / plan got wrong or left open
1. **Plan Task 5's "its own `FlutterTextMeasurer` cleared in `finally`"** is dropped for the PDF path (R-13-14, the Task 4 review): the sink measures with `document.textMeasurer`. Spec D4 never asked for an own measurer; D5's PNG keeps its own (CanvasDrawSink needs `paragraphFor`).
2. **M-13c as written** ("multiply the stroke width by the camera's scale") is red at both scales, not "at 1:100". The form that only 1:100 sees is a width that follows the camera's scale normalised to be right at 1:50 (M-13c above); I fired both.
3. **M-13x**: the engine has no `AttachComponentCommand`; I used `SetComponentCommand<PageComponent>` of the same page (codec unchanged, `stateId` 23 → 24), so T-9's `stateId` half is what kills it.
4. **T-4's "lineweight 0"**: the fixture has no lineweight-0 entity; the test adds one per scale group by command (fixture unchanged, P-3's fixture still non-degenerate).
5. **Spec T-5 "the box's baseline origin"**: with the fixture's default `packTextAttrs()` the baseline origin is the insertion point; the test checks the run origin against the insertion point's page position.
6. `SpatialIndex` disposal is unobservable (OWN-ex-dispose survives); recorded, not pinned.
7. The empty-content rule (R-13-9) also covers a page whose only ops are set-up/state: the package drops a content stream that painted nothing.

## Task 5b — the Task 5 review's findings 1, 2 and 4

**Commit:** `8fe438b` fix(render): export leaves the document's mutation hooks as it found them (Task 5 review), on `72827ed`, not pushed.

**Finding 1 (high).** There is no detached or read-only index. `SpatialIndex(this.document)` always runs `rebuildAll()` and then assigns `document.commands.onAfterMutate = _onChange` and `onBeforeMutate = _guardMutation` (`spatial_index.dart:161-174`). It has no other constructor or flag. `symbol_thumbnails.dart:120`, the only other one-shot user, is safe only because its document is private. So I used save and restore, with no engine edit. `page_export.dart` now has a private helper:

```dart
void _withExportIndex(DraftDocument document, void Function(SpatialIndex index) body)
```

- It captures both hooks.
- Inside `try`, it builds the index, runs `body`, and disposes the index in an inner `finally`.
- An outer `finally` restores both hooks, after `dispose()`, on a throw as well.
- `body` is synchronous by type, so no edit can come between the capture and the restore. The doc comment says so.
- **For Task 6:** `exportPagePng` should paint inside `_withExportIndex(document, (index) { … })` the same way. It must keep `toImage` (async) **outside** the body, after the picture is recorded, as the PDF path keeps `pdf.write` outside.

`exportPagePdf`'s doc now says the codec bytes, the `stateId` and the dispatcher's hooks are unchanged. **Spec amendment for Task 11:** D4 and I-3 should name the hooks.

**Tests** (`export_pdf_test.dart`, +3):
- **"T-9: the dispatcher's mutation hooks are left as found / with a screen index…"**
  - A "screen" `SpatialIndex(f.document)` is built first, and its hooks are non-null.
  - Both hooks are `==` after a normal export.
  - Both hooks are `==` after an export with 64 bytes of `7` as the font, which throws inside the paint.
  - The screen index's `forEachInRect` over an empty probe region counts 0 before a line is added by command, and 1 after.
- **"…with no index on the document"**: the hooks are null before, after a normal export and after a throwing export.
- **Finding 2:** an export with the page set (by `SetComponentCommand`, in the test) to A3 portrait at 1:100, origin (3000, −1500).
  - The MediaBox is `[0 0 297u 420u]`.
  - The ACI 7 line's single black stroke is at the independently computed `((3600−3000)/100·u, (300+1500)/100·u)`.
- **Finding 4:** `_render`'s unused `simpleTrueTypeFonts` parameter is removed from `pdf_draw_sink_text_test.dart`. The CID test keeps its own document.

**Gates** (real tails):
- `CI=true flutter test` (render): `00:55 +1127 ~1 -7: Some tests failed.` That is 1124 + 3. The 7 `[E]` are exactly text ladder rungs 1–5 and text lod ladder rungs 1–2 (RenderBackend.canvas).
- `flutter analyze`: `No issues found! (ran in 1.5s)`.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 198 files (0 changed)`, exit=0.
- The engine, app, goldens and invariant files are untouched (the commit changes only `page_export.dart`, `export_pdf_test.dart` and `pdf_draw_sink_text_test.dart`).

**Mutants** (runner `scratchpad/e5/mut.py`, test `export_pdf_test.dart`; every run printed `RESTORED diff=0`):

| id | mutation | result |
|---|---|---|
| B-norestore | outer `finally` restores nothing | RED: screen-index test, `Expected: <Closure: (DocChange) => void from Function '_onChange@…'> Actual: <null>`. `00:00 +22 -1: Some tests failed.` |
| B-normalonly | restore only after a normal return (no outer `try/finally`) | RED on the **throwing** case: same `Actual: <null>`, reason `throwing export`. `00:00 +22 -1: Some tests failed.` |
| B-nodispose (= OWN-ex-dispose) | `index.dispose()` commented out | **survives**, `00:00 +23: All tests passed!`. It is equivalent by experiment once the restore exists: the restore overwrites the dead index's hooks. Only its own maps are left, unreachable and collected by the GC, as the review predicted. |
| B-restorefirst | restore also before `dispose()` in the inner `finally` | **survives**, `00:00 +23: All tests passed!`. Equivalent: `dispose()` nulls only hooks that are still its own, and the outer `finally` restores again anyway. |
| B-a4 (= REV-a4) | `pageFormat: PdfPageFormat.a4.landscape` | RED: A3 test, `Expected: a numeric value within <0.000005> of <1190.5511811023623> Actual: <595.27559>`. `00:00 +22 -1: Some tests failed.` |

This corrects item 6 above: "index not disposed" was observable through the hooks before 5b, as the review showed. After 5b it is equivalent by the experiment recorded above.
