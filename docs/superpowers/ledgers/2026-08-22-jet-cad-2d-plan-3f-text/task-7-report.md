# Task 7 report: the LOD golden ladder

## Design

One document, one word ("LOD") at three world heights, one fixed camera. Only
`DraftCanvas.minTextCapPixels` changes between the three rungs — not the
framing. World box `kWorld = Aabb2((0,0), (200,150))` matches the golden
viewport's 4:3 aspect exactly, so `ViewportTransform.fit`'s scale is
`0.95 * min(400/200, 300/150) = 0.95 * 2.0 = 1.9` on both axes, with no
letterboxing. No instance transform sits between the entities and the camera,
so `chain.scaleMagnitude` in `DraftPainter._drawText` is exactly `1.9`.

## Computed and measured on-screen cap heights

`on-screen cap height = world height * 1.9`:

| string | world height | computed cap height | vs. 3.0 threshold |
|---|---|---|---|
| small  | 1.0  | 1.9 px  | 37% below — culled at default |
| middle | 1.8  | 3.42 px | 14% above — drawn at default, "near the boundary" |
| large  | 20.0 | 38.0 px | far above — drawn at default with room to spare |

Verified empirically, not just by arithmetic: the three canvas PNGs show
exactly this pattern (see below), and rung 3's threshold (`50.0`, chosen above
the largest, 38.0) culls all three, confirming the ordering independently of
the formula.

## The three thresholds per rung

- Rung 1: default (`kMinTextCapPixels` = 3.0) — small culled, middle and large
  drawn.
- Rung 2: `0.0` — the control arm, cull disabled, all three drawn.
- Rung 3: `50.0` — above every string's cap height (38.0 max) — none drawn.

## What I saw in each of the six PNGs

- **text_lod_ladder_1.png** (canvas, default threshold): a large blue "LOD"
  block near the top, a barely-visible green sliver at the middle anchor (the
  middle string, drawn at ~3.4 px), and a bare black tick with no text at the
  bottom (the small string, culled). Matches "large + middle shown, small
  not."
- **text_lod_ladder_2.png** (canvas, 0.0): same large blue block and green
  sliver, plus a new small red sliver at the bottom tick where rung 1 showed
  none — the small string, now drawn because the cull is disabled. All three
  strings present.
- **text_lod_ladder_3.png** (canvas, 50.0): only the three black anchor
  ticks, evenly spaced down the left side; no colour, no text anywhere. None
  drawn.
- **vertices/text_lod_ladder_1.png**, **_2.png**, **_3.png**: all three are
  visually identical — three black anchor ticks and nothing else, at every
  threshold. This is expected and documented in the file: text is handed to a
  paragraph on the real canvas by both `CanvasDrawSink` and
  `VerticesDrawSink`'s fallback, and never reaches the triangle buffer
  `TriangleRasterizer` observes, so the LOD threshold has nothing to act on in
  this backend. The ticks (ordinary polylines) do reach the triangle buffer,
  so all three vertices goldens ink something — satisfying the suite's
  standing "never inks nothing" assertion — while carrying no information
  about the threshold itself; that information lives entirely in the three
  canvas PNGs.

## Golden suite run

Generation:
```
CI=true flutter test --tags golden --update-goldens test/golden/text_lod_ladder_golden_test.dart
...
00:00 +6: All tests passed!
```

Full suite, no `--update-goldens`, after generation and again after `dart format`:
```
CI=true flutter test --tags golden
...
00:02 +35: All tests passed!
```
35 = the previously-confirmed 29 plus this task's 6 new tests (3 rungs x 2
backends).

## flutter analyze

```
CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)
```

`dart format --output=none --set-exit-if-changed test/golden/text_lod_ladder_golden_test.dart`
flagged one formatting issue on first pass (a wrapped `CameraController(...)`
call); ran `dart format` on the file and reconfirmed both `--set-exit-if-changed`
and the full golden suite green afterward.

## git status

```
$ git status --porcelain
 M apps/dev_harness/analysis_options.yaml
 M apps/dev_harness/macos/Podfile
 M apps/dev_harness/macos/Runner.xcodeproj/project.pbxproj
?? packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_1.png
?? packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_2.png
?? packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_3.png
?? packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart
?? packages/jet_cad_2d_flutter/test/golden/vertices/text_lod_ladder_1.png
?? packages/jet_cad_2d_flutter/test/golden/vertices/text_lod_ladder_2.png
?? packages/jet_cad_2d_flutter/test/golden/vertices/text_lod_ladder_3.png
```

Exactly the six new PNGs plus the new test file as untracked; no existing PNG
modified. The three modified files at the top (`analysis_options.yaml`,
`Podfile`, `Runner.xcodeproj/project.pbxproj`) predate this task, are excluded
per the plan's global constraints, and were not touched or staged.

## Commit

`git add packages/jet_cad_2d_flutter/test/golden` then committed as
`test: a golden ladder for the text level-of-detail threshold`.

## Addendum: the coordinator's pre-review correctness concern

The coordinator flagged the three identical `vertices/text_lod_ladder_*.png`
goldens as a possible defect, on the theory that `text_ladder_golden_test.dart`'s
vertices goldens *do* show text (citing that its five PNGs differ from each
other and are ~6,119 bytes, and that `VerticesDrawSink` delegates text to a
fallback `CanvasDrawSink`), and asked me to find out whether the cause was my
harness or a real product defect, and not to delete the vertices rungs
either way.

**Investigation.** Three checks, in order:

1. **Diffed the two `_rung` functions line by line** (`diff` on the
   `Future<void> _rung(...)` bodies of `text_ladder_golden_test.dart` and
   `text_lod_ladder_golden_test.dart`). The only differences are the
   intentional ones — threading `minTextCapPixels` through and the golden
   file names. Pump order, `markNeedsPaint`, observer attachment and the
   `devicePixelRatio` assertion are identical. This rules out "my test does
   something differently."

2. **Opened `vertices/text_ladder_1.png` and `vertices/text_ladder_3.png` by
   eye** — the pre-existing, already-accepted goldens the coordinator cited
   as the working control. Rung 1 (fixture: one red anchor rule plus four
   rows of "JUSTIFY") shows exactly one red vertical line and nothing else.
   Rung 3 (fixture: four anchor crosses plus four "ROTATE" strings at
   different rotations) shows exactly four black/red crosses and nothing
   else. Neither carries any glyph of "JUSTIFY" or "ROTATE". This directly
   contradicts "the vertices backend draws text ... which is why that ladder
   works" — the pre-existing ladder's five vertices PNGs differ from each
   other because each rung is a *different fixture* with different anchor
   geometry (a rule vs. four crosses vs. two rules, at different positions),
   not because any of them carries text. `text_ladder_golden_test.dart`'s own
   doc comment already says this in so many words ("carries the rung's
   anchor rule or crosses and none of its glyphs ... text goes to
   `CanvasDrawSink` as a paragraph and never reaches the triangle buffer").

3. **Traced the code**, rather than trusting either doc comment:
   `VerticesDrawSink.text` (`lib/src/vertices_draw_sink.dart:717-721`) calls
   `_flushBeforeUnbatchable()` then `_fallback?.text(...)`. `_fallback` is
   the plain `CanvasDrawSink` the vertices backend already owns — wired up in
   `DraftCanvas._attach` (`lib/src/draft_canvas.dart`, the
   `VerticesDrawSink(..., fallback: sink)` call). `CanvasDrawSink.text`
   (`lib/src/canvas_draw_sink.dart:204-224`) draws with
   `canvas.drawParagraph(paragraph, Offset.zero)` — a direct call on the real
   `dart:ui.Canvas`. The test's `observer` is attached to
   `VerticesDrawSink`'s own vertex buffer flush (the `positions`/`colors`
   arrays behind `canvas.drawVertices`), a completely different call. No
   frame, on any rung of any text ladder in this suite, has ever routed text
   through that buffer.

**Conclusion, stated plainly: neither of the coordinator's two hypotheses
holds.** It is not "something my test does differently" (ruled out by the
line diff) and it is not "a real defect in the vertices text path for this
fixture's shape" (ruled out — the code path is fixture-independent, and the
pre-existing, already-shipped `text_ladder_golden_test.dart` exhibits the
identical limitation in its own goldens, which the project accepted when
those PNGs were generated). The original "text bypasses the triangle buffer"
explanation in this file's header and `_rung` doc comment was correct, not
disproven. The coordinator reviewed this evidence directly (opened
`vertices/text_ladder_1.png` independently, saw the same single red rule, no
glyphs) and ruled: **all three vertices rungs stay**, on the same grounds —
they cannot pin the threshold, the comment must say so plainly, and they
still carry this suite's standard vertices-golden guarantee (flushing before
an unbatchable op does not corrupt the batch; the picture reaching the
rasterizer is never empty).

**What changed as a result.** Per the ruling, the "text bypasses the triangle
buffer" sentence was not deleted or reversed — it was *replaced with the
traced version*: the `_rung` doc comment in
`text_lod_ladder_golden_test.dart` now cites the exact call chain
(`VerticesDrawSink.text` -> `_fallback.text` -> `CanvasDrawSink.text` ->
`canvas.drawParagraph`, with file references) and the independent
confirmation from opening `text_ladder_golden_test.dart`'s own PNGs, rather
than asserting the conclusion on its own authority. No PNG was regenerated;
no test code changed — this was a comment-only edit (34 insertions, 9
deletions, zero non-comment lines), committed separately as `85ed531`
("docs: trace why the LOD ladder's vertices goldens carry no text").

**Six PNGs, looked at again after the investigation (unchanged from the first
pass, since nothing about the rendering changed — only the explanatory
comment did):**

- `text_lod_ladder_1.png` (canvas, default 3.0): large blue "LOD" block, a
  faint green sliver at the middle anchor, a bare black tick at the bottom
  with no text. Small culled, middle and large drawn.
- `text_lod_ladder_2.png` (canvas, 0.0): same large block and green sliver,
  plus a small red sliver now visible at the bottom tick. All three drawn.
- `text_lod_ladder_3.png` (canvas, 50.0): three bare black ticks, no colour,
  no text. None drawn.
- `vertices/text_lod_ladder_1.png`, `_2.png`, `_3.png`: three black anchor
  ticks, nothing else, identical to each other at the byte level (confirmed
  by the earlier checksum: `fa615b021d6cab1b6942c772c4fabaed` for all three).
  This is now understood and documented as a necessary consequence of
  holding the fixture and camera fixed across rungs while text — the only
  thing that could differ — never reaches this backend's rasterizer, not as
  an accidental degeneracy.

**Final verification, this pass:**

```
$ CI=true flutter test --tags golden
...
00:01 +35: All tests passed!
```

```
$ CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 51 files (0 changed) in 0.06 seconds.
```

```
$ git status --porcelain
 M apps/dev_harness/analysis_options.yaml
 M apps/dev_harness/macos/Podfile
 M apps/dev_harness/macos/Runner.xcodeproj/project.pbxproj
```

No `.png` anywhere shows as modified; the three pre-existing `apps/dev_harness`
files remain unstaged, exactly as before this task began. The comment-only
change is committed as `85ed531`, on top of `383e15c` (the original six-PNG
commit).
