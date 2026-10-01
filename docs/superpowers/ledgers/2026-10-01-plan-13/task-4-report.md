# Task 4 report — PdfDrawSink text (spec D3 "text", T-5 at the sink)

**Commit:** `94653f6` feat(render): PdfDrawSink text (on `d61d567`, not pushed).

## Files
- `lib/src/export/pdf_draw_sink.dart`
  - Constructor gains `required Uint8List fontBytes`, `required FlutterTextMeasurer measurer`, `required TextStyleRecord Function(Handle) textStyleOf`.
  - One `PdfTtfFont` from the bytes, `late final` (built on the first `text`; a page with no text embeds no font).
  - `text()`: empty string returns; `_pushTransform()` (residual pushed as any primitive); `_fillState(resolved)` (`rg` + `gs`, alpha 255 included); `drawString(font, kNominalTextPixels, text, 0, 0, scale: w_flutter / w_pdf)` which writes `BT /F Tf Tz 0 0 Td [<hex>] TJ ET`. No extra flip.
  - `w_flutter = measurer.measure(text:, style: textStyleOf(style)).advanceWidth`.
  - `w_pdf = Σ (font.glyphMetrics(rune).advanceWidth * 1000.0).toInt() / 1000 · size` over `text.runes`: exactly the expression `PdfTtfFont._buildType0` writes into `/W` (pdf 3.13.1 `ttffont.dart:163-169`; the CID for each rune is its index in the subset cmap, whose width entry is `glyphMetrics(cmap[i])`, i.e. the same rune).
  - Tz is always written: if `w_pdf <= 0` or the ratio is not finite / negative, scale 1.0 (Tz 100), so no Tz from an earlier run is relied on.
- `lib/src/export/testing/pdf_content.dart` (reader)
  - **Text state moved into the graphics state**: `Tf` (resource, size) and `Tz` now live in `PdfContentState`, saved by `q` and restored by `Q` (ISO 32000-1 8.4.1/9.3.1). Before, they were interpreter fields that leaked past `Q` — a real reader bug (a viewer restores Tz at Q).
  - New `PdfContentFontInfo` on each run (`fontInfo`): `subtype`, `encoding`, `descendantSubtype` (Type0 → DescendantFonts[0]), `fontFile` (which of `/FontFile`, `/FontFile2`, `/FontFile3` the descriptor holds **as a stream**; for Type0 the descendant's descriptor).
  - Already present from Task 3 and used here: TJ hex CIDs, `/W` (incl. the package's `[0 N 0 R]` form), `/DW`, `/ToUnicode` bfchar/bfrange, Tf, Tz, Td, Tm, `pageMatrix = Tm × CTM`.
- `test/export/pdf_content_test.dart`: +3 reader tests (Q restores Tf/Tz; Tm and `Tm × CTM` under a rotated CTM incl. direction vectors; font info Type0→descendant descriptor→FontFile2, a Type0 with nothing embedded, a simple TrueType).
- `test/export/pdf_draw_sink_text_test.dart` (new, 15 tests): T-5 on the fixture (8) and a direct call (7).
- `test/export/pdf_draw_sink_test.dart`: Task 3's `_render` passes the new constructor arguments (vendored Roboto, `FlutterTextMeasurer()`, `DraftDocument.empty().textStyleOf`); the T-3b "text throws UnimplementedError" assertion removed (test renamed "beginDash and endDash throw; shadesDashes is false"); T-3 still skips TextOps (comment updated: its default measurer gives text a singular residual; T-5 covers text).
- `test/support/export_font.dart` (new): `exportFontBytes()` reads `test/golden/fonts/Roboto-Regular.ttf` by `File`.

## T-5 as built
**Fixture** (`exportFixture(measurer: FlutterTextMeasurer())`, Ahem under flutter_test, P-5), painted at `pageCamera(page, 72/25.4)`, `minTextCapPixels: 0`, `DocumentStyleResolver(foreground: 0x000000)`, into `RecordingDrawSink()`; **all** ops replayed (text included) into a `PdfDrawSink` on `PdfDocument(compress: false)` with the same measurer and `f.document.textStyleOf`; bytes via `write(PdfStream)`.
- two runs, in order, strings via `/ToUnicode` == `'Yatak Odası'`, `'WC'` (both recorded: asserted);
- every text residual has det < 0 (regular, not the singular one Task 3 saw);
- `Tf` size == `kNominalTextPixels` (100), one font resource;
- `fontInfo` == `/Type0`, `/Identity-H`, `/CIDFontType2`, `/FontFile2`;
- advance from `/W` · Tz/100 == measured width within `5e-6 / Tz · advance` (only Tz is rounded; /W integers and size 100 are exact), and `|Tz − 100| > 20`. Real values: "Yatak Odası" Tz 206.76692, advance 1100.0000144 vs measured 1100.0; "WC" Tz 130.12362, 200.0000039 vs 200.0;
- origin == `pageSetUp · residual · (0,0)` within `pdfTolerance(0, 0, residual, pageHeight: H)`;
- **direction** (spec T-5/S-3): the page image of text-space (0,1) under the parsed `Tm × CTM` has the direction of `(r.c, −r.d)` = `pageSetUp · residual · (0,1)`; likewise (1,0) → `(r.a, −r.b)`. Angle bound = `hypot(δc, δd) / |v|` from the entries' actual rounding;
- fill colour == resolved RGB (0x37474F), `ca` == alpha, a `gs` written.

**Direct call** under `translate(300,200)·scale(0.12,−0.12)·rotate(30°)·scale(1.5,0.75)` (asserted det < 0, |b| > 0.01, |b − c| > 0.01), style `0x801E88E5`:
operator sequence `cm J j M q cm … BT Tf Tz Td TJ ET Q` with `0 0 Td`; string and size; origin; both directions; advance == measured; colour and `ca` 0.50196.

## Gates (real tails)
Render (`CI=true flutter test`, at the commit's tree):
```
00:53 +1099 ~1 -7: Some tests failed.
```
- 1,081 + 3 (reader) + 15 (T-5) = 1,099. The 7 `[E]` (deduplicated) are exactly text ladder rung 1-5 and text lod ladder rung 1-2 (RenderBackend.canvas).
- `flutter analyze`: `No issues found! (ran in 1.6s)`.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 196 files (0 changed)`, exit 0.
- Both allocation invariant tests ran green inside the suite; `git diff --stat d61d567..HEAD -- packages/jet_cad_2d apps packages/jet_cad_2d_flutter/test/golden packages/jet_cad_2d_flutter/test/invariants` prints nothing.

Engine and app: **not re-run, unchanged** — this task touches only the render package (no pubspec). The app does not use `PdfDrawSink` (`grep -rn "PdfDrawSink\|export_testing" apps packages/jet_cad_2d` is empty), so no public signature it uses changed. `analysis_options.yaml` (rewritten by pub get) left unstaged.

## Mutants
Runner `scratchpad/e4/mut.py` (cp backup, one exact replacement with a match-count check, the named test file in the foreground, cp back, diff). Every run printed `RESTORED diff=0`.
Sink = `lib/src/export/pdf_draw_sink.dart`, T = `test/export/pdf_draw_sink_text_test.dart`, reader R = `lib/src/export/testing/pdf_content.dart`, RT = `test/export/pdf_content_test.dart`.

| id | where | mutation | red tests | real output |
|---|---|---|---|---|
| M-13l | sink `text`, `drawString(... scale:)` | `scale: null` (no Tz, 100) | fixture advance (`Expected: a value greater than <20> Actual: <0.0>`), direct q…Q sequence (`Actual: ['BT', 'Tf', 'Td', 'TJ', 'ET', 'Q']`), direct advance (`within <0.0000271...> of <1100.0> Actual: <532.0>`) | `00:00 +12 -3: Some tests failed.` |
| M-13m | sink `text`, before `drawString` | `_g.setTransform(_set(1, 0, 0, -1, 0, 0));` (extra y flip) | fixture direction, direct direction (`Expected: ... <= <0.0000231...> Actual: <3.141592653589793>`) | `00:00 +13 -2: Some tests failed.` |
| OWN-trunc | sink `_pdfTextAdvance` | widths not truncated (`double`, no `.toInt()`) | fixture advance, direct advance (`within <0.0000276...> of <1100.0> Actual: <1098.4232196>`) | `00:00 +13 -2: Some tests failed.` |
| OWN-size | sink `drawString` size | `kNominalTextPixels * 0.5` | Tf size (`Expected: <100.0> Actual: <50.0>`), fixture advance (`Actual: <550.0000072...>`), direct size, direct advance | `00:00 +11 -4: Some tests failed.` |
| OWN-fill | sink `text` | `_fillState(resolved)` removed | fixture colour (`within <0.000005> of <0.2156...> Actual: <0.0>`), direct colour | `00:00 +13 -2: Some tests failed.` |
| OWN-push | sink `text` | `_pushTransform()` removed (residual ignored) | fixture origin (`Actual: <85.039...>`), fixture direction (`Actual: <3.14159...>`), direct q…Q, origin, direction | `00:00 +10 -5: Some tests failed.` |
| OWN-transpose | sink `_pushTransform` | residual written transposed `_set(r.a, r.c, r.b, ...)` | **direct direction only** (`Expected: ... <= <0.0000254...> Actual: <0.3334876888825793>`) — the fixture's text residuals are diagonal | `00:00 +14 -1: Some tests failed.` |
| RD-tstate | R `PdfContentState.copy` | `fontSize`/`horizontalScale` not copied (q does not save text state) | RT "q saves Tf and Tz and Q restores them" (`Expected: [10, 80] Actual: [0.0, 100.0]`) | `00:00 +23 -1: Some tests failed.` |
| RD-pm | R `PdfContentText.pageMatrix` | `ctm.times(textMatrix)` | RT "Tm sets the text matrix ... Tm × CTM" and the old Td test (`Expected: [4, 94] Actual: [4.0, 106.0]`) | `00:00 +22 -2: Some tests failed.` |
| RD-pm vs T | same | same | **survives** T: `00:00 +15: All tests passed!` — equivalent there by experiment: the sink always writes `0 0 Td` (Tm = identity), and `I × CTM = CTM × I`. Killed by the reader's own test, as P-2 requires. | |
| RD-desc | R `_fontInfo` | descriptor read from the Type0 dict, not the descendant | RT font-info test (`Actual: ['/Type0', '/Identity-H', '/CIDFontType2', null]`); also red in T "the font is a /Type0 over a CIDFontType2 with a FontFile2" (`00:00 +14 -1`) | `00:00 +23 -1: Some tests failed.` |

## What the spec / plan got wrong or left open
1. **The painter measures with `document.textMeasurer`, not with the sink's measurer.** `DraftPainter._drawText` (`draft_painter.dart:982`) lays the box out with `document.textMeasurer.measure`. `PdfDrawSink.text` measures with the `measurer` it is given. They agree only if the caller passes a measurer that measures as the document's does. In T-5 they are the same instance. **For Task 5:** spec D4 says the export uses "its own `FlutterTextMeasurer`"; that is consistent only if the document's measurer is also a `FlutterTextMeasurer` in the same font environment (true in the app). If a document carries an `InsertionPointMeasurer` (render-test default), the box residual is singular and nothing sensible can be drawn — Task 5's fixture must use a `FlutterTextMeasurer` as the document's measurer (as here), or pass `document.textMeasurer` when it is one.
2. **Tz is written even at 100** (spec D3 lists Tz unconditionally; I keep that literal and use 1.0 as the fallback ratio), so the "state in full" rule covers the text state too.
3. **The font is built lazily** (on the first `text`), not at construction: "one `PdfTtfFont` from the bytes" holds, and a page with no text does not embed an unused font object. Invalid bytes therefore throw at the first text, not at construction.
4. **Compressed PDFs (Task 10's T-10 reads `compress: true` output).** Not checked here; the reader handles FlateDecode content streams (Task 3), but whether the package then puts objects in object streams (which the sequential scan would not see) is for Task 9/10 to confirm.
5. Spec T-5 says "the run, mapped through the CTM, starts at the box's baseline origin": at the sink this is `pageSetUp · residual · (0,0)`, since glyph space's origin is the baseline origin (as the canvas sink's flip about `alphabeticBaseline` implies). Task 5 checks it end to end.

## Decisions
- `w_pdf` reproduced from `PdfTtfFont.glyphMetrics(rune)` with the package's own `(x * 1000.0).toInt()`, not by reading the font tables a second way, so the sink and `/W` cannot drift.
- An empty string draws nothing (the painter never sends one; it skips empty text before the sink).
- `exportFontBytes()` lives in `test/support/` so Task 5 and later can share it.
