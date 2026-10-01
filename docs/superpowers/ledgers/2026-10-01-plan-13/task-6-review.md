# Task 6 review: exportPagePng (commit ca163b9, range 8fe438b..ca163b9)

**Reviewer:** an independent reviewer.

**Worktree:** the detached `plan-13-review` worktree, at `ca163b9`.

**Scratch:** `scratchpad/r6/t6_*`, which holds:
- the mutant runner `t6_mut.py` and its logs `t6_<id>.log`;
- the decoder `t6_png_check.py`;
- the exported PNGs `t6_*.png`.

**Clean-up.** Every mutated file was restored from its `.bak` and `diff` exited 0. The two temporary test files were deleted. `git status` shows only the standing `packages/jet_cad/analysis_options.yaml` change. Nothing was staged or committed.

## 1. `exportPagePng` against spec D5

The function is `page_export.dart:104-154`.

- **Size.** The image is `(effW/25.4*dpi).round()` × `(effH/25.4*dpi).round()`, matching D5.
- **Camera.** It is `pageCamera(page, dotsPerInch / 25.4)`. The scale is unrounded, and the size passed to the painter is `camera.size`, also unrounded.
- **Ground.** `drawPaint` in `0xFFFFFFFF` runs on the fresh canvas, before `_withExportIndex`. The decoded alpha over sampled rows of every exported file is only `{255}`.
- **`pixelsPerPaperMm: u` is the right unit.**
  - `CanvasDrawSink._widthFor` computes `lw/100 · pixelsPerPaperMm / residualScale` in the units of the canvas it draws on.
  - The canvas here is a `PictureRecorder` canvas that `toImage(width, height)` rasterises 1:1. One canvas unit is one image pixel, with no DPR.
  - On screen, `DraftCanvas` passes `kLogicalPixelsPerMm` because its canvas units are logical pixels. Here they are image pixels, so `u = dpi/25.4` is correct.
  - So 0.50 mm at 300 dpi is 5.906 px.
  - The tests pin that width only from above; see finding 1.
- **Resolver and painter.**
  - The resolver is `DocumentStyleResolver(document, foreground: 0x000000)`.
  - The painter is `DraftPainter(minTextCapPixels: 0.0, omitOwners:)`.
- **Index and paint order.** The paint runs inside `_withExportIndex` (R-13-17). `toImage` and `toByteData` run after it returns, outside the synchronous body.
- **Disposal.**
  - `endRecording` is in an inner `finally`, so the picture exists even when the paint throws.
  - The outer `finally` disposes the image and the picture, then calls `measurer.clear()`.
  - The clear comes after rasterisation, so the recorded paragraphs are alive while `toImage` runs. That order is correct.
- **`pHYs` (`_withPhys`).**
  - The chunk is 21 bytes, laid out as: length 9; type `pHYs`; x ppm and y ppm, each a big-endian u32; unit byte 1.
  - The CRC is a table-driven CRC-32 with polynomial `0xEDB88320`, over bytes 4..17, which is the type plus the data. It is written big-endian.
  - It is inserted directly after the `IHDR` chunk, so it lands before every `IDAT`.
  - **The drop branch** (`:182`) skips any later `pHYs`. By reading, it is correct: the walk index still advances through `chunkEnd`. No input reaches it today; see finding 3.
- **Independent decode of real exports.**
  - A temporary test, since deleted, wrote real `exportPagePng` output to scratch: the fixture at 96, 150 and 300 dpi, and A3 portrait at 300 dpi.
  - `t6_png_check.py`, written in Python with `struct` and `zlib` and none of the code under review, did the following:
    - walked every chunk;
    - checked every CRC with `zlib.crc32`;
    - checked that the chunk walk ends exactly at EOF;
    - inflated the concatenated `IDAT`s;
    - checked the raw length against `h·(4w+1)`;
    - undid every filter (0 to 4).
  - Real output:

```
t6_fixture_96.png ['IHDR', 'pHYs', 'sBIT', 'sRGB', 'IDAT..IEND'] (1123, 794, 8, 6, 0) allcrc True pHYs (3780, 3780, 1) corners (255, 255, 255, 255) (255, 255, 255, 255) alpha set (sampled rows) [255]
t6_fixture_150.png ['IHDR', 'pHYs', 'sBIT', 'sRGB', 'IDAT..IEND'] (1754, 1240, 8, 6, 0) allcrc True pHYs (5906, 5906, 1) corners (255, 255, 255, 255) (255, 255, 255, 255) alpha set (sampled rows) [255]
t6_fixture_300.png ['IHDR', 'pHYs', 'sBIT', 'sRGB', 'IDAT..IEND'] (3508, 2480, 8, 6, 0) allcrc True pHYs (11811, 11811, 1) corners (255, 255, 255, 255) (255, 255, 255, 255) alpha set (sampled rows) [255]
t6_a3p_300.png ['IHDR', 'pHYs', 'sBIT', 'sRGB', 'IDAT..IEND'] (3508, 4961, 8, 6, 0) allcrc True pHYs (11811, 11811, 1) corners (255, 255, 255, 255) (255, 255, 255, 255) alpha set (sampled rows) [255]
```

  - `file` also reports `t6_fixture_150.png: PNG image data, 1754 x 1240, 8-bit/color RGBA, non-interlaced`. PIL and pngcheck are not installed.
  - The engine writes `sBIT` and `sRGB` after the inserted `pHYs`. The PNG ordering rules put no constraint between `pHYs` and those two chunks; all three only have to precede `IDAT`.
  - **No corruption was found.**

## 2. The tests

- **Route.** Every pixel test and every size test goes through `exportPagePng` under `tester.runAsync`. The decode runs under it too, through the engine's codec.
- **Non-A4-landscape pages.**
  - The size matrix covers A4 and A3, in both orientations, at all three dpi, against literal sizes.
  - One pixel test uses A3 portrait at 1:100 with origin (3000, −1500).
- **Pixel expectations are computed independently.** `toPixel` uses the page's numbers and not `pageCamera`. I re-derived row 2421.26 and half-width 2.953 px by hand.
- **The oblique AA check** samples at world x 5500, 6500 and 7500, so y is 1100 to 1900, ±6 px (about ±25 world units).
  - The nearest text is "Yatak Odası", with its baseline at y 3500 and cap 250, which is far away.
  - Under M-13a the partial count drops to exactly 0. That proves nothing else, text or other entities, feeds the partial count.
- **T-8 band.**
  - It covers every pixel centre within `lw/2·u + 1.5` px of the transformed segment, for `along` in [0, length]. That is more than 500 pixels.
  - The "some dark without the set" half proves the band really lies on the drawn separator. A misplaced band would have no dark pixel.
  - Butt caps, so excluding the ends is right.
- **T-9 PNG hook tests.**
  - The throw happens inside the paint, gated by stack trace on `DraftPainter.`.
  - The test asserts that the caught error is `_Boom`.
  - Both hooks are checked after a normal export and after a throwing one.
  - An edit afterwards is seen by the screen index.
  - The no-index case is covered.

## 3. Mutants (all run by me, foreground, file restored, `diff=0`)

| id | mutation (page_export.dart) | test file | result (real tail) |
|---|---|---|---|
| M-13a (T-11) | `VerticesDrawSink(canvas:, pixelsPerPaperMm:, fallback: CanvasDrawSink(...))` + `sink.flush()` + import | export_sources_test | red: "names no VerticesDrawSink…" `Expected: false Actual: <true>` |
| M-13a (AA) | same | export_png_test | `00:05 +23 -1: Some tests failed.` Only the oblique coverage test failed: `Actual: <0>`, reason "every pixel is either the ink or white: no anti-aliasing" |
| M-13e | `TileCache().dispose();` before the paint + import | export_sources_test | red, `Expected: false Actual: <true>` |
| M-13s | `.floor()` for width and height | export_png_test | `00:06 +10 -14`: all 12 size tests (including A4 landscape 150), the A3 line test and the corners test |
| M-13t | `dpi / 0.254` | export_png_test | `00:06 +21 -3`: all three pHYs tests, e.g. `is <1181> instead of <11811>` |
| M-13u | no `drawPaint` | export_png_test | `00:06 +20 -4`: horizontal line, oblique, corners, T-8 |
| M-13p (PNG) | `minTextCapPixels: 0.0` removed | export_png_test | `00:06 +23 -1`: "WC" test, reason `no dark pixel in "WC"'s box at 150 dpi` |
| H-png | the PNG path inlines `SpatialIndex(document)` + `dispose()` instead of `_withExportIndex` | export_png_test | `00:05 +23 -1`: screen-index hook test, `Actual: <null>` |
| R-ppmm96 (own) | `pixelsPerPaperMm: 96 / 25.4` (the screen's value) | export_png_test | `00:06 +23 -1`: oblique test, but only via `full > 0` (reason **"the columns cross the line"**). The horizontal-line test **stays green** |
| R-ppmmHalf (own) | `pixelsPerPaperMm: u / 2` | export_png_test | **survives**, `00:06 +24: All tests passed!` (finding 1) |
| R-ppmmTwice (own) | `pixelsPerPaperMm: u * 2` | export_png_test | `00:06 +23 -1`: the horizontal-line test |
| R-ppmTrunc (own) | `(dpi * 39.37).toInt()` | export_png_test | `00:05 +22 -2`: 96 (`3779 instead of 3780`) and 150 (`5905 instead of 5906`). 300 is identical: 11811.0 truncates and rounds to 11811. Observable at 96 and 150, not at 300 |
| R-groundAfter (own) | white `drawPaint` after the paint, inside the recording | export_png_test | `00:05 +20 -4`: "WC", horizontal, oblique, T-8 |
| R-camRound (own) | `pageCamera(page, (dpi/25.4).roundToDouble())` | export_png_test | `00:05 +20 -4`: "WC", horizontal, oblique, T-8 |
| R-noDrop | drop branch `:182` removed | export_png_test | survives, `+24: All tests passed!` (finding 3) |
| R-noClear | `measurer.clear()` removed | export_png_test | survives, `+24: All tests passed!` (accepted, section 4) |

The implementer's mutant claims are reproduced, with the same red tests and tallies.

## 4. R-13-19 and the `measurer.clear()` survivor

**R-13-19: accepted.**
- The painter lays boxes out with `document.textMeasurer`, and the PNG draws paragraphs from its own `FlutterTextMeasurer`.
- Every document that reaches the app's export has a `FlutterTextMeasurer`:
  - `DraftCanvas._requireMeasurer` throws otherwise (`draft_canvas.dart:309-320`);
  - `floor_planner/lib/new_document.dart:19` builds one.
- Two instances in one process resolve the same family and lay out identically.
- The mismatch exists only for headless or non-Flutter measurers. The report sizes it honestly: up to about 3.5 cap heights for centred text.
- Using the document's own measurer instead would let the export's `clear()` wipe the screen's paragraph cache, which is worse. D5 asks for the export's own measurer.
- Record it in the results note, as R-13-19 says.

**The `clear()` survivor: accepted.**
- The measurer is local, so `clear()` only releases native paragraph memory early instead of at finalisation.
- No output or document state depends on it.
- Pinning it would need an injection seam that D5 does not have.
- It is in place and ordered correctly, after `toImage`.

## 5. Gates (real tails, render package at ca163b9)

- `CI=true flutter test --tags golden`: `00:30 +28 -7: Some tests failed.`
  - The deduplicated `[E]` set is exactly text ladder rungs 1–5 and text lod ladder rungs 1–2, all `RenderBackend.canvas`. That is the standing 7.
- `git diff --stat 7fab442 -- packages/jet_cad_2d_flutter/test/golden/` printed 0 lines, and `git status` on that directory is empty.
- `CI=true flutter test`: `00:54 +1153 ~1 -7: Some tests failed.` That is 1153 passed, 1 skip, and the same 7 standing failures.
- `CI=true flutter analyze`: `No issues found! (ran in 1.5s)`.
- `CI=true dart format --output=none --set-exit-if-changed .`: `fmt_exit=0`.
- **Scope.**
  - `git diff --stat 8fe438b..ca163b9 -- packages/jet_cad_2d apps packages/jet_cad_2d_flutter/test/golden <both invariant tests>` printed 0 lines.
  - The commit touches only `page_export.dart`, `export_png_test.dart` and `export_sources_test.dart`.
  - The trailers are correct, and `analysis_options.yaml` is not committed.

## Verdict: **Approved with notes**

## Findings

1. **Low: the PNG's stroke width is pinned from above only.**
   - **Where:** `test/export/export_png_test.dart:180-191`.
   - **What survives:** `pixelsPerPaperMm: u / 2` survives the whole file. The screen value `96/25.4` is caught only incidentally, by the oblique test's `full > 0` guard.
   - **Why:** the horizontal-line test checks ink on the centre row and white at ±(w/2+2). A 1.9 px or 2.95 px stroke still fully covers row 2421.
   - **Fix (test only):** in the same loop, also expect exact ink at rows `(row - halfWidth + 1).floor()` (2419) and `(row + halfWidth - 1).floor()` (2423).
   - **Verified** with a temporary copy of the test file, since deleted:
     - at ca163b9 the check passes (`00:01 +1: All tests passed!`);
     - under `u / 2` it goes red: `Expected: [93, 64, 55, 255] Actual: [214, 207, 205, 255]`, reason `R6 inner row 2419`.
   - **Timing:** the render layer freezes after this task, so land it now as a test-only commit, or record it as an accepted gap.
2. **Info: M-13p's 300 dpi half (R-13-18) is confirmed.**
   - "WC"'s cap is 5.9 px at 300 dpi, above `kMinTextCapPixels = 3.0` (`draft_painter.dart:40`).
   - The 150 dpi check is the one that bites.
   - Amend T-7 at Task 11, as ruled.
3. **Info: the "drop an existing pHYs" branch is unexercised.**
   - **Where:** `lib/src/export/page_export.dart:182`.
   - **What survives:** R-noDrop.
   - **Status:** it is correct by reading, and the engine emits no `pHYs` today.
   - **Optional fix:** make `_withPhys` `@visibleForTesting` and feed it a PNG that already carries a `pHYs`, then assert there is exactly one with the new value. Otherwise, record the branch as untested.
4. **Info: the throwing measurer depends on JIT frame names.**
   - **Where:** `test/export/export_png_test.dart:419`.
   - **What it does:** `_ArmedMeasurer` matches `'DraftPainter.'` in `StackTrace.current`. That is fine under `flutter test` (JIT), and the test asserts the error is `_Boom`, so a silent non-throw would go red rather than pass vacuously.
   - **No action.**

## Re-review (6b): commit d538aa2 on ca163b9

**Worktree:** the detached `plan-13-review` worktree, at `d538aa2`.

**Mutants.** They were run with the same cp-backed runner, `scratchpad/r6/t6_mut.py`, and logged to `t6_B-*.log`. Every run printed `RESTORED diff=0`. Afterwards `git diff --quiet d538aa2 -- packages/jet_cad_2d_flutter` reported the tree clean.

**Scope.**
- `git diff --name-only ca163b9..d538aa2` lists only `lib/src/export/page_export.dart` and `test/export/export_png_test.dart`.
- The lib change is the rename only: `_withPhys(png, pixelsPerMetre:)` becomes `@visibleForTesting withPhysChunk(Uint8List png, int dpi)`, which computes `round(dpi / 0.0254)` itself.
- `exportPagePng` still returns through it (`page_export.dart:145`).
- The engine, the app, the goldens and both invariant tests are still unchanged vs 8fe438b (`git diff --stat` printed 0 lines).
- The trailers are correct.

**Finding 1 (stroke width from below): closed.**
- The horizontal-line test now expects exact ink at rows 2419 and 2423 at all three columns.
- `pixelsPerPaperMm: camera.pixelsPerPaperMm / 2` is now red. The real output was `00:06 +24 -1: Some tests failed.` The failing test was the A3 horizontal-line test, with `Actual: [214, 207, 205, 255]` and reason `inside the stroke, row 2419 at x 2125`.

**Finding 3 (the drop branch): closed.**
- A new test reassembles a real 96 dpi export with a foreign `pHYs` (1234 px/m, unit 0) after IHDR and valid CRCs, then calls `withPhysChunk(input, 300)`. It checks:
  - exactly one `pHYs`, at index 1, holding `[11811, 11811, 1]`;
  - every CRC, bit by bit;
  - that the data of every chunk other than `pHYs` is unchanged.
- Removing `if (typeAt(at) == 'pHYs') continue;` is now red. The real output was `00:06 +24 -1: Some tests failed.` The failing test was "withPhysChunk replaces a pHYs already in the PNG…", with `Actual: WhereIterable<String>:['pHYs', 'pHYs']`.

**Regression check: M-13t after the refactor.** `(dpi / 0.254).round()` inside `withPhysChunk` is red: `00:07 +21 -4: Some tests failed.` That is the 3 T-7 pHYs tests plus the new withPhysChunk test.

**T-11.** `page_export.dart` still names no `VerticesDrawSink`, `TileCache` or `DraftCanvas` (grep: no hits). `export_png_test.dart` + `export_sources_test.dart`: `00:05 +27: All tests passed!`

**Gates (render package, d538aa2):**

| Gate | Result |
|---|---|
| `CI=true flutter test` | `00:57 +1154 ~1 -7: Some tests failed.` The 7 deduplicated `[E]` are exactly text ladder rungs 1–5 and text lod ladder rungs 1–2 (RenderBackend.canvas) |
| `CI=true flutter analyze` | `No issues found! (ran in 1.9s)` |
| `CI=true dart format --output=none --set-exit-if-changed .` | `fmt_exit=0` |

**Note (info, no action).** `withPhysChunk` is now reachable through the barrel's whole-file `export 'src/export/page_export.dart';`. `@visibleForTesting` makes the analyzer flag any use outside tests, so the public surface is guarded. A `hide withPhysChunk` on the barrel would be an option, but it is not required.

### Verdict (6b): **Approved**

Findings 1 and 3 of the Task 6 review are closed. Findings 2 and 4 stand as recorded, both informational: the 300 dpi M-13p amendment is due at Task 11 per R-13-18.
