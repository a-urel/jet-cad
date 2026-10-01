# Task 4 review: PdfDrawSink text (spec D3 "text", T-5 at the sink)

**Scope**
- Reviewer: independent.
- Commit: `94653f6` (range `d61d567..94653f6`), reviewed in the detached worktree `.claude/worktrees/plan-13-review` at `94653f6`.
- Nothing was committed or staged. `git status --short` at the end shows only `packages/jet_cad/analysis_options.yaml` (pub get).
- Mutant runner: `scratchpad/r4/mut.py`. It backs the file up to `scratchpad/r4/`, makes one exact replacement (aborting on a wrong match count), runs the named test file in the foreground, copies the file back and diffs it. Every run printed `RESTORED diff=0`.
- I wrote one temporary test, `test/zz_review_t4_test.dart`. It was moved to `scratchpad/r4/` afterwards and is not in the tree.

## 1. `text()` against spec D3 (`lib/src/export/pdf_draw_sink.dart:279-309`)

| D3 point | Verdict |
|---|---|
| Residual pushed as for any primitive | **Yes.** `_pushTransform()` writes `q` and `cm` on first use. The direct test asserts the sequence `cm J j M q cm … BT Tf Tz Td TJ ET Q`. |
| Size `kNominalTextPixels` | **Yes.** `drawString(font, kNominalTextPixels, …)` writes `/Fn 100 Tf`. |
| `Tz = 100·w_flutter/w_pdf` | **Yes.** `scale: ratio` is written by `setFont` as `PdfNum(scale*100) Tz` (`graphics.dart:530-533`). |
| Fill colour and `gs` | **Yes.** `_fillState(resolved)` writes `rg` and `gs`, with alpha 255 included. |
| `0 0 Td`, `[<hex>] TJ`, `ET` | **Yes.** This is `drawString` (`graphics.dart:603-631`). The package writes no `Tc`, `Tw`, `Ts` or `Tr` because those arguments are null and the mode is fill. |
| No extra flip | **Correct**, see "Upright" below. |
| One `PdfTtfFont` | **Yes.** It is `late final` (`:88`), so it is built on the first text and a page with no text embeds no font. I accept that (report item 3). |

**w_pdf against what the package writes in `/W`** (pdf 3.13.1 `obj/ttffont.dart`)
- `putText` (`:184-204`) gives each `rune` of `text.runes` a CID, its index in `unicodeCMap.cmap`.
- `_buildType0` (`:162-169`) writes the width of CID `i` as `(glyphMetrics(cmap[i]).advanceWidth * 1000.0).toInt()`.
- The sink sums `(font.glyphMetrics(rune).advanceWidth * 1000.0).toInt()` over `text.runes`. That is the same function, on the same rune, with the same truncation, so the sink and `/W` cannot drift.
- `glyphMetrics` applies the `useBidi` and `useArabic` zero-width diacritic rules (`:97-105`). Because both sides call it, those rules hold on both sides as well.

**Edge cases.** Under `compress: false` and `compress: true`, my temporary test compared the reader's advance (from `/W`, times `Tz/100`) with the measured width. Real lines:

```
REVIEW compress=false ... string=true Tz=206.76692 advance=1100.0000144000003 measured=1100.0      ('Yatak Odası')
REVIEW compress=false ... string=true Tz=186.56716 advance=199.99999552000003 measured=200.0       ('éä', combining marks)
REVIEW compress=false ... string=false Tz=235.47881 advance=300.00000394000006 measured=300.0      ('A\u{1F600}B', surrogate pair, glyph missing)
REVIEW compress=false ... string=true Tz=235.47881 advance=300.00000394000006 measured=300.0       ('A中B', glyph missing in Roboto)
REVIEW compress=false ... string=true Tz=190.83969 advance=199.99999511999997 measured=200.0       ('ﬁx', ligature code point)
REVIEW compress=false ... string=true Tz=150.55706 advance=499.99999626000005 measured=500.0       ('WC WC', repeated CIDs)
(the same six lines with compress=true)
```

- **Surrogate pairs.** Both the sink and `putText` iterate over `runes`, so the advance is right.
  - The `/ToUnicode` the package writes for a code point above U+FFFF is malformed. It writes `<0002> <1F600>`: five hex digits, not UTF-16BE surrogates (`unicode_cmap.dart`, `toRadixString(16).padLeft(4)`).
  - The reader then silently truncates that entry: `Expected: 'A😀B'  Actual: 'AὠB'`. See finding 4.
- **Glyphs missing from the font.** `glyphMetrics` returns zero and `/W` writes 0, so the two sides agree. Tz stretches the glyphs that are present over Flutter's advance, which includes the fallback font's width. This is consistent with R-3 (one font), so I record it as info only.
- **Kerning and ligatures.** The package writes no kerning numbers, and the reader models none. Flutter's advance includes kerning and shaping, and `Tz` absorbs the difference uniformly. That is the intended design.
- **Combining marks.** They take the width in their hmtx entry on both sides.
- **One assumption is not guarded: the CID path** (finding 5). `_useType0` is `font.unicode && !settings.simpleTrueTypeFonts` (`ttffont.dart:55`).
  - A `PdfDocument(simpleTrueTypeFonts: true)`, or a font whose sfnt tag is not `0x00010000` (OTF/CFF), takes `_buildTrueType`.
  - That path writes `/Widths` by byte code 32..255, and `w_pdf` per rune no longer matches it.
  - D4's export builds a default `PdfDocument` and D7 ships a TTF, so this is not reachable today.

**Upright.**
- `pageSetUp = [1 0 0 −1 0 H]`, so `det = −1`.
- Every painter text residual maps glyph space (y up) to screen (y down) through the camera's flip, so `det(residual) < 0`. The fixture test asserts this for both runs.
- The composite therefore has `det > 0`: orientation is preserved, and glyph "up" lands on page "up". An extra flip would make the determinant negative, which mirrors and inverts the text.
- The direction test expects `(r.c, −r.d)` for text-space (0,1). That is `pageSetUp · residual · (0,1)`, written in page space as S-3 requires. M-13m turns it red with an angle of π.

**Tz fallback.**
- If `pdfAdvance <= 0` or the ratio is NaN, infinite or negative, the sink writes `Tz 100`.
- `ratio == 0` (w_flutter 0, e.g. an `InsertionPointMeasurer` document) writes `Tz 0`. That is legal, and it goes with a residual that is singular anyway.
- `Tz` is always written. I agree that the "state in full" rule should cover it (report item 2).

## 2. The reader's new text capabilities (`lib/src/export/testing/pdf_content.dart`)

**Tf and Tz moved into `PdfContentState`, saved by `q` and restored by `Q`.**
- This is correct per ISO 32000-1 8.4.1: text state parameters are part of the graphics state.
- The old interpreter fields were a real reader bug.

**`PdfContentFontInfo`.**
- `/Subtype` and `/Encoding` come from the font. For `/Type0` it follows DescendantFonts[0] to that font's `/FontDescriptor`, then to `/FontFile`, `/FontFile2` or `/FontFile3`.
- The test is independent: hand-written objects cover a Type0 with FontFile2, a Type0 with nothing embedded, and a simple TrueType.

| id | mutation | test | result (real lines) |
|---|---|---|---|
| RD-tstate (re-fired) | `copy()` drops `fontSize` and `horizontalScale` | RT | RED "q saves Tf and Tz and Q restores them…": `Expected: [10, 80] Actual: [0.0, 100.0]`. `00:00 +23 -1` |
| RD-desc (re-fired) | descriptor read from `font`, not the descendant | RT | RED "font info follows a Type0 font…": `Actual: ['/Type0', '/Identity-H', '/CIDFontType2', null]`. `00:00 +23 -1` |
| RD-pm vs T (re-fired) | `pageMatrix => ctm.times(textMatrix)` | T | survives, `00:00 +15: All tests passed!` (see below) |
| OWN-rd-k (mine) | the advance ignores Tz (`final k = size;`) | RT | RED: the two-byte-CID test (`Expected … 17.6 Actual: <22.0>`) and the q/Q test (`Expected … <4> Actual: <5.0>`). `00:00 +22 -2` |
| OWN-rd-vec (mine) | `applyToVector` transposed | RT | RED "Tm sets the text matrix…": `Expected: [0, 2] Actual: [0.0, -1.0]`. `00:00 +23 -1`. Task 3's RD-transpose gap is closed for vectors. |
| OWN-rd-ff (mine) | `fontFile` set when the key is present, not only when it resolves to a stream (`descriptor?[key] != null`) | RT | **survives**, `00:00 +24: All tests passed!`. Finding 3. |

**RD-pm: accepted.**
- The sink always writes `0 0 Td` inside a fresh `BT`, so `Tm` is the identity and `I × CTM = CTM × I`. No sink test can use a non-identity `Tm`, so the mutant is equivalent for every sink test by construction.
- It is killed by the reader's own Tm test, which uses a quarter-turn CTM and a stretched, translated Tm. That is what P-2 requires.

## 3. T-5 per spec (`test/export/pdf_draw_sink_text_test.dart`)

**Fixture group.** All ops are replayed from the Ahem-measured fixture at the page camera with `minTextCapPixels: 0`.
- "Yatak Odası" and "WC" are both recorded and both round-trip through `/ToUnicode`.
- Size is 100. There is one font resource.
- The font is Type0 / Identity-H / CIDFontType2 / FontFile2.
- The advance from `/W` times Tz/100 equals the measured width within `5e-6/Tz · advance`, and `|Tz−100| > 20`.
- The origin is `pageSetUp · residual · (0,0)` within `pdfTolerance`.
- The direction check is in page space as in S-3: `(0,1)` goes to `(r.c, −r.d)` and `(1,0)` to `(r.a, −r.b)`, with an angle bound derived from the entries' rounding.
- The fill RGB and `ca` are checked, and a `gs` must be present.

**Direct-call group.**
- The residual is `translate·scale(0.12,−0.12)·rotate(30°)·scale(1.5,0.75)`. The test asserts it is mirrored and not symmetric.
- The group checks the operator sequence, `0 0 Td`, the string and size, the origin, both directions, the advance, and the colour with `ca 0.50196`.
- It is the only route that sees a transposed residual (OWN-transpose below), because the fixture's text residuals are diagonal.

**Spec conformance.** All T-5 items at the sink are present. The "box's baseline origin" end to end is Task 5's.

## 4. Mutants (sink `lib/src/export/pdf_draw_sink.dart`, test T = `test/export/pdf_draw_sink_text_test.dart`)

| id | mutation | result (real lines) |
|---|---|---|
| M-13l | `scale: null` | RED ×3: fixture advance (`Expected: a value greater than <20> Actual: <0.0>`), direct sequence (`Actual: ['BT', 'Tf', 'Td', 'TJ', 'ET', 'Q']`), direct advance (`Actual: <532.0>`). `00:00 +12 -3` |
| M-13m | `_g.setTransform(_set(1, 0, 0, -1, 0, 0));` before the font | RED ×2: fixture and direct direction (`Actual: <3.141592653589793>` / `<3.1415799514181226>`). `00:00 +13 -2` |
| OWN-transpose | `_set(r.a, r.c, r.b, r.d, r.e, r.f)` | RED: direct direction only (`Actual: <0.3334876888825793>`). `00:00 +14 -1` |
| OWN-tzinv (mine) | `ratio = pdfAdvance / flutterAdvance` | RED ×2: `Actual: <257.2945648>` vs 1100. `00:00 +13 -2` |
| OWN-fill-from-stroke (mine) | `_strokeState(resolved)` instead of `_fillState` | RED ×2: `within <0.000005> of <0.2156…> Actual: <0.0>`. `00:00 +13 -2` |
| OWN-no-gs (mine) | `rg` only, no `gs` | RED ×2: `Expected: non-empty Actual: []` and `of <0.50196…> Actual: <1.0>`. `00:00 +13 -2` |
| OWN-round (mine) | `.round()` instead of `.toInt()` in `w_pdf` | RED ×2: `Actual: <1097.9362268>` vs 1100. `00:00 +13 -2` |
| OWN-style (mine) | measure with `textStyleOf(ReservedHandles.standardTextStyle)`, not the entity's style | **survives**, `00:00 +15: All tests passed!`. Finding 2. |

## 5. Design question for Task 5: which measurer gives `w_flutter`

**The facts**
- The painter lays the box out with `document.textMeasurer.measure(text:, style: record)` (`draft_painter.dart:982`). `record = document.textStyleOf(styleHandle)` (`:960`).
- `TextMeasurer` is a one-method interface: `TextMetrics measure({required String text, required TextStyleRecord style})` (`packages/jet_cad_2d/lib/src/document/text_metrics.dart:49-51`).
- In the app, every document carries a `FlutterTextMeasurer`. The host and the session own it (`apps/floor_planner/lib/document_host.dart:57-88`, `:367-403`; `main.dart:239-241`; `new_document.dart:19`).
- `DraftCanvas` requires one and hands that same instance to its sink (`draft_canvas.dart:309-320`, `_requireMeasurer`).
- `PdfDrawSink` calls only `measurer.measure(...)` (`pdf_draw_sink.dart:286`). It never calls `paragraphFor`.

**Recommendation (the cleanest rule):**
- **Type the sink's field as the interface.**
  - In `pdf_draw_sink.dart:57,79`, change `required this.measurer` with `final FlutterTextMeasurer measurer` to `final TextMeasurer measurer` (from `package:jet_cad_2d`), and drop the `flutter_text_measurer.dart` import.
- **`exportPagePdf` passes the document's own measurer and resolver.** It builds no measurer of its own:
  ```dart
  PdfDrawSink(document: pdf, page: pdfPage, pixelsPerPaperMm: 72 / 25.4,
      fontBytes: fontBytes, measurer: document.textMeasurer,
      textStyleOf: document.textStyleOf)
  ```
  `w_flutter` is then, by construction, the exact call the painter made: same instance, same record, and a metrics-cache hit.
- **Drop plan Task 5's "its own `FlutterTextMeasurer` cleared in `finally`".**
  - Spec D4 does not ask for it; only D5, the PNG path, does, because `CanvasDrawSink` needs `paragraphFor`.
  - Record this in the Task 5 report as a plan deviation inside the spec's bounds (D3: "`w_flutter` is the advance the painter laid the box out with").
  - A metrics-cache hit or fill is not document state. Codec bytes and `stateId` stay equal, so T-9 holds.
- **Task 5 test that pins this rule.**
  - Build one export fixture document with a `MetricModelMeasurer(advanceRatio: 0.55)` as its `textMeasurer`. Its residual is regular, unlike `InsertionPointMeasurer`'s.
  - Assert that the run's advance (`/W` times `Tz/100`) equals `document.textMeasurer.measure(...)`.
  - Named mutant: `exportPagePdf` passes a fresh `FlutterTextMeasurer()`. Under Ahem that gives 1.0 em per glyph against 0.55, so the test goes red.
  - With the field typed `FlutterTextMeasurer`, that mutant would be equivalent under flutter_test whenever the document's measurer is also a `FlutterTextMeasurer`.
- **If the field must stay `FlutterTextMeasurer`** (I do not recommend it), `exportPagePdf` should refuse a document whose measurer is not one, exactly as `DraftCanvas._requireMeasurer` does (`ArgumentError.value(measurer, 'document.textMeasurer', …)`), and pass that instance.

## 6. Object streams and cross-reference streams (implementer's point 3)

**What pdf 3.13.1 writes**
- `PdfDocument` defaults to `version: PdfVersion.pdf_1_5` (`document.dart:77`).
- Under `pdf_1_5`, `PdfXrefTable.output` calls `_outputCompressed` (`format/xref.dart:167-174`), which writes a **cross-reference stream** (`/Type /XRef`, `:339-411`). This happens whatever `compress` is.
- **It never writes object streams.**
  - `PdfCrossRefEntryType.compressed` is never constructed.
  - `_compressedRef` writes type 1 (in use) or 0 (free) only (`xref.dart:61-75`).
  - `grep -rn ObjStm` over the package's `lib/` is empty.
- Every object is a plain `N 0 obj … endobj`, and `/Length` is direct.

**What the reader needs**
- The reader's sequential scan sees everything. It also parses the XRef stream object harmlessly, as one more object.
- I verified this empirically with `compress: true`: the bytes start `%PDF-1.5`, contain `/XRef`, and contain no `/ObjStm`. The reader read every run's string (BMP) and advance correctly (lines in §1).
- **The reader needs nothing more for Tasks 9-10.** A future package version that emits `/ObjStm` would make it throw "expected one /Page" rather than read wrong, so that failure would be loud.

## 7. Gates and scope

- Render (`CI=true flutter test` at `94653f6`): `00:58 +1099 ~1 -7: Some tests failed.`
  - The 7 deduplicated `[E]` failures are text ladder rungs 1-5 and text lod ladder rungs 1-2 (RenderBackend.canvas). That is the standing set.
- `flutter analyze`: `No issues found! (ran in 1.9s)`.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 196 files (0 changed)`, exit 0.
- Scope: `git diff --name-only d61d567..94653f6` lists only six files:
  - `packages/jet_cad_2d_flutter/lib/src/export/{pdf_draw_sink.dart, testing/pdf_content.dart}`;
  - `test/export/{pdf_content_test, pdf_draw_sink_test, pdf_draw_sink_text_test}.dart`;
  - `test/support/export_font.dart`.
- `git diff --stat d61d567..94653f6 -- packages/jet_cad_2d apps packages/jet_cad_2d_flutter/test/golden packages/jet_cad_2d_flutter/test/invariants` is empty. The engine, the app, the goldens and both allocation invariant tests are unchanged.

## Verdict: **Approved with notes**

The sink is right on every D3 point. `w_pdf` reproduces the package's `/W` exactly, by the same function and the same truncation. T-5 at the sink is complete. Every named and own mutant is red except the two noted below. None of the findings blocks Task 4; finding 1 should be adopted by Task 5.

## Findings

1. **Medium (carried to Task 5): `w_flutter` must come from the document's measurer.**
   - Where: `pdf_draw_sink.dart:57,79,286` and plan Task 5.
   - Problem: the sink measures with whatever `FlutterTextMeasurer` it is handed, while the painter laid the box out with `document.textMeasurer` (`draft_painter.dart:982`). The two agree only by convention.
   - Fix: type the field as `TextMeasurer`. Have `exportPagePdf` pass `document.textMeasurer` and `document.textStyleOf`, and drop the plan's own measurer for the PDF path. Pin it with a `MetricModelMeasurer` document and the "fresh `FlutterTextMeasurer`" mutant (§5).
2. **Low: the style passed to the measurer is untested.**
   - Where: `pdf_draw_sink.dart:286`; `test/support/export_fixture.dart:365`.
   - Problem: OWN-style survives. Every text in T-5 uses `standardTextStyle`, which is a default style, against P-3's "no style equals its default". Under flutter_test every `fontFamily` measures as Ahem anyway.
   - Fix: once finding 1 types the field `TextMeasurer`, add a direct-call test with a small fake measurer whose advance depends on `style.handle`, and a text under a non-standard style handle.
3. **Low: the reader's "embedded as a stream" check is untested.**
   - Where: `pdf_content.dart:923` and the test at `pdf_content_test.dart:260`.
   - Problem: OWN-rd-ff survives.
   - Fix: add a descriptor whose `/FontFile2` resolves to a non-stream (e.g. `<< >>` or a number), and expect `fontFile == null`.
4. **Low: the reader silently truncates a malformed `/ToUnicode` destination.**
   - Where: `pdf_content.dart:1115-1120` (`utf16`).
   - Problem: a destination hex string whose length is not a multiple of 4 has its tail dropped. The package writes exactly that for code points above U+FFFF (`<1F600>`), and the reader returned `'AὠB'` for `'A😀B'`.
   - Fix: throw `FormatException` on `h.length % 4 != 0`, to keep the reader strict. The package's own `/ToUnicode` defect for astral code points is upstream; the floor planner's labels are BMP. Record it in the results note.
5. **Info: the CID path is not guarded.**
   - Where: `pdf_draw_sink.dart:88-89,302-309`.
   - Problem: `w_pdf` assumes the `/Type0` path. A `PdfDocument(simpleTrueTypeFonts: true)` or a non-TrueType-outline font writes `/Widths` by byte code, and Tz would then be wrong without anything noticing.
   - Fix: on the first text, throw `StateError`/`ArgumentError` unless `_font.isCidFont` (public in 3.13.1, `ttffont.dart:62`). That costs one line and turns a silent mismatch into a loud one.
6. **Info: missing glyphs get `/W` 0.**
   - Where: no code location; this is behaviour.
   - Problem: Tz stretches the glyphs that are present over Flutter's advance, which includes fallback-font glyphs. This follows from R-3 (one font).
   - Fix: none needed. Mention it in the results note.
