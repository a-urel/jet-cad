# P7 — the status caption lands on a chair: a library fix

Worktree `.claude/worktrees/fix-caption`, branch `fix/status-caption` from local
`main`. Report of record for P7 (`docs/superpowers/notes/2026-10-17-4b-opencode-prompts.md`,
lines 187-201).

## The bug and whose it is

In `apps/restaurant_demo` (Service mode, Salon) table 2's status caption
("Bill") is drawn over the table's lower chair
(`docs/superpowers/notes/2026-10-16-restaurant-kit-pos.png`).

**It is a library issue, not a demo issue.** The placement lives entirely in
the plan library's `UnitStatusPainter`
(`packages/jet_cad_2d_plan/lib/src/service/paint/unit_status_painter.dart`).
The demo only supplies the status colour and the caption text
(`apps/restaurant_demo/lib/statuses.dart`: `statusFor`/`kStatuses`, the
`'Bill'` status `UnitStatus(color: 0x99E53935, caption: 'Bill')`). The demo
never computes a caption position, so there is nothing for it to fix.

The root cause: the painter put the caption's screen top at

```dart
final below = math.max(_captionSize, f.half * scale + kStatusCaptionGap);
```

i.e. below the unit's *label*, which sits at the base point — the centre of
the table top, inside the symbol. The 11 px `_captionSize` floor clears the
number with room to spare only for a label; on a table whose lower chair
reaches below the top, 11 px was not enough and the caption landed on the
chair. Any table whose symbol extends far below its base point (chairs, a
bench, a turned asymmetric top) shows the same.

## The fix

`_Fill` now also carries the unit's symbol box, `u.box` (definition space,
the chairs among its leaves). At paint time the caption's `below` is clamped
so the caption's screen top is at or below the box's greatest screen y plus
`kStatusCaptionGap`:

```dart
var below = math.max(_captionSize, f.half * scale + kStatusCaptionGap);
final box = f.box;
if (!box.isEmpty) {
  final y00 = b * box.minX + d * box.minY + g;
  final y10 = b * box.maxX + d * box.minY + g;
  final y01 = b * box.minX + d * box.maxY + g;
  final y11 = b * box.maxX + d * box.maxY + g;
  final bottom = math.max(math.max(y00, y10), math.max(y01, y11));
  below = math.max(below, bottom - sy + kStatusCaptionGap);
}
```

The box is a parallelogram under the instance transform composed with the
camera, so its greatest screen y is always a corner: only four
`b*x + d*y + g` reads, in doubles, no allocation. The caption stays below the
label when the box is above it, and clears the chairs whatever the rotation,
mirror or zoom. A steady frame still allocates nothing (the allocation bars
in `unit_status_painter_test.dart` and `paint_allocation_test.dart` gate
this).

## The regression test, red before and green after

SP13, `packages/jet_cad_2d_plan/test/service/paint/unit_status_painter_test.dart`:
`tableSymbol()` (a 1200 x 800 top with a 450 x 450 chair above and below it)
at the identity and turned a quarter, the caption's top asserted at or below
the box's bottom in screen pixels, with a premise that the chairs reach below
the number so the fixture is not degenerate.

Before the fix (the mutation run below, `turns=0`):

```
  Expected: a value greater than or equal to <374.999999>
    Actual: <312.0>
     Which: is not a value greater than or equal to <374.999999>
  turns=0: the caption at 312.0 clears the box bottom 375.0
```

After the fix: SP1-SP13 pass. The test file also rewrote SP8 to the rule
(the exact `below`, `max(11, 100 x scale + 2, boxBottom - anchor + 2)`, at
0.1, 0.5 and 0.07 px/mm, plus a premise that the box, not the 11 px floor,
decides). SP8 exposed a latent staleness in its own fixture: it captured the
`InstanceNode` before the `TransformNodeCommand`, so an exact expectation now
reads the turned transform it re-fetches after the command.

## The mutation

Revert the library fix (`git show HEAD:packages/jet_cad_2d_plan/lib/src/service/paint/unit_status_painter.dart > …`),
leaving every test in place. SP13 and SP8 both turn red:

```
Failing tests:
  .../unit_status_painter_test.dart: SP13 P7: the caption clears the unit's own box, so it never lands on the chairs, at the identity and turned a quarter
  .../unit_status_painter_test.dart: SP8 P7 the caption sits centred below the unit's box, clear of it at any zoom; a table smaller than its caption has none (S7, review F-4, F-5)
```

Restoring the fix returns the file to green.

## Ripple in the caption's other tests (all honest)

The caption moved off the fill onto the paper, so five tests that assumed it
sat inside the top were updated:

- `unit_theme_painter_test.dart` `captionGlyphs` now takes the `paper`, and
  its premise is "the caption's box is the paper" instead of "inside the
  fill". The two white-ink cases (M-H33's dark fill, T3-c at
  `statusFillOpacity 1`) are read on Blueprint, where a white ink is visible
  rather than vanishing into the White paper it now sits on — the ink rule is
  unchanged and, an opaque fill over any paper, still white.
- The font-size test moved to a new fixture, `raisedTable` (a table whose box
  sits entirely above its base point), so the box clamp leaves room and the
  resolved font size is what places the caption: `dy = 300 + 11` and
  `300 + 14`. On the old fixture the clamp would have dominated and the
  difference would have been 0.
- `unit_fill_test.dart` `captioned` now asserts the caption is on the
  number's x and at or below the unit box's bottom (computed through the
  unit's transform), not "within 40 px below the number".
- `apps/restaurant_demo/test/look_test.dart` (DL1/DL2) counted the caption's
  ink inside `screenBox(c, '2')`; it now counts in `captionBand`, the same
  box grown 40 px downward. The caption is below the box now, and the test's
  80 px difference is unchanged.

## Ink: a reasoned caveat, not a new rule

`docs/superpowers/notes/2026-10-04-dark-theme-results.md` ("The caption and
the number") already recorded the position bug ("At the default fit (about
0.04 px/mm) the caption's 11 px floor puts it on the chair and edge outlines
below the top (pre-existing, 14c)") and the ink caveat ("Untested
combination. That off-fill caption is inked for the status composite, not for
the bare paper it then lies on. ... This is not seen; it is reasoned."). P7
fixes the position; it leaves the ink as reasoned.

D6c (`docs/superpowers/specs/2026-10-04-dark-theme-design.md`) derives the
caption's ink from the status colour over the paper, i.e. from the *fill* —
the spec's premise was that the caption sits on the fill. P7 puts it on the
paper. The fill-based rule is kept: it is what `status_caption_test.dart`
exercises (the "smoke on White->Ivory flips the caption" case), the demo's
statuses take the same ink on both papers, and only a host whose status fill
is dark on a white paper would see a caption that contrasts with the fill but
not with the paper. Changing it to a paper-based ink is a larger look change
than P7 and is left as an open question.

## Commits

- `42ccbafa` `test(restaurant_demo): read the caption's ink below the unit's box`
- `c7fde491` `fix(plan): a status caption clears the unit's box, so it never lands on a chair`

(Two commits, both individually green: the demo band counts the caption
inside or below the box, so it passes with and without the fix.)

## Commands, with their real last lines

`packages/jet_cad_2d_plan`:

- `flutter analyze` — `No issues found! (ran in 3.3s)`
- `dart format --output=none --set-exit-if-changed .` — `Formatted 308 files (0 changed) in 0.75 seconds.`
- `flutter test` — `01:50 +1573 ~7: All tests passed!` (7 standing skips, unrelated)

`apps/restaurant_demo`:

- `flutter analyze` — `No issues found! (ran in 3.5s)`
- `dart format --output=none --set-exit-if-changed .` — `Formatted 38 files (0 changed) in 0.07 seconds.`
- `flutter test` — `00:22 +102: All tests passed!`

`tool/ci`:

- `dart test` — `00:44 +114: All tests passed!`

Mutation (fix reverted, tests kept):

- `flutter test test/service/paint/unit_status_painter_test.dart --plain-name "SP13"` — red at `312.0` against `375.0` (above).

## What I could not do and open questions

- I did not run the GPU/`jet_cad_2d_gpu` suite or `jet_cad_2d`/`jet_cad_2d_flutter`:
  no file in them changed. `tool/ci` (the cross-repo gate) is green.
- The demo's own rendered screenshot was not re-diffed against
  `2026-10-16-restaurant-kit-pos.png`; the change is covered by DL1/DL2's
  caption-ink count and by the plan package's pixel-free position tests.
- Open: whether D6c's ink should become paper-based now that the caption sits
  on the paper (see the caveat above). It is a deliberate, reasoned choice
  here, and a reviewer may want it decided in the dark-theme spec. —
  **Resolved** by the ink amendment below.

Co-Authored-By: DeepSeek V4.1 Flash Free <noreply@opencode.ai>

---

# P7's ink amendment — the caption's ink is the paper's

Follow-up to P7, same worktree and branch. P7 put the caption on the paper
but kept D6c's fill-based ink: a dark status on White drew a white caption
on white paper (invisible), a light status on a dark paper a dark caption on
dark paper. This decides the open question above.

## The decision

The caption takes the plan's on-paper rule, the one ACI 7 and every label
take: `foregroundFor(paper)`, mapped to `kStatusCaptionOnLight` /
`kStatusCaptionOnDark` as D6c's conversion already did. The status colour no
longer enters. Not invented: `plan_canvas.dart` derives the drafting's ink
with `foregroundFor(paper)`, and `PaperPalette.forPaper` switches the
overlays on exactly `foregroundFor`.

`statusCaptionInk` now takes the paper (`int paper`). The old fill-based
rule survives, correctly, as the new `chipInk(fill, paper)` for the group
chip, whose text lies on the chip, not on the paper (S-6); `over` stays,
`chipInk`'s and the tests'. The painter's rebuild key is unchanged: `paper`
was already in its repaint merge and its rebuild condition (F-16), so a
paper change still repaints and rebuilds, and the caption cache still keys
on the ink the paper picks.

## Tests

- M-H33 (`unit_theme_painter_test.dart`) — (1): a dark fill 0xFF1B1B1B on
  White takes the paper's dark ink, `0x202020`; the light fill on White the
  same. No longer read on Blueprint.
- T3-c (same file) — (2): a light fill on Blueprint takes the light ink,
  `0xFFFFFFFF`, at `statusFillOpacity` 0.3 and 1.0 (the drawn colour's
  opacity moves nothing); 0xFF303030 on White is dark at 0.2 and 1.0. The
  fill-based premises are kept, labelled as what the old rule would have
  done.
- K12 (same file): assertion kept; its premise relabelled (the fill's own
  ink happens to agree over Blueprint).
- SP11 (`unit_status_painter_test.dart`): the paper's rule — White and Ivory
  dark, Blueprint white, the alpha byte unread — with the chip's fill-based
  ink beside it.
- `status_caption_test.dart`: the premise is the paper's; the review-5 test
  is re-derived — White to Ivory keeps the dark caption (both light papers),
  the smoke fill no longer flips it, and the page change still reaches the
  painter, now asserted by `debugRebuilds` rising.

## The mutation

M-P7-ink-from-the-fill: in `unit_status_painter.dart` `paint`,
`statusCaptionInk(paperArgb)` -> `statusCaptionInk(over(drawn, paperArgb))`
(the ink from the fill again). It reddens (1):

```
  Expected: '0x202020'
    Actual: '0xffffff'
  M-H33(null caption colour), amended by P7: ... the dark fill 0xFF1B1B1B on White is visible in today's dark 0x202020
```

T3-c (`Expected: '0xffffff' Actual: '0x202020'`) and the status view's
review-5 test fall with it: `00:01 +26 -3: Some tests failed.` Reverted; the
three files are green again.

## Commits

- `b1edd9ba` `fix(plan): the status caption's ink is the paper's, not the fill's`
- `fbae5fda` `docs: D6c amended by P7 — the caption's ink is the paper's`

Both individually green.

## Commands, with their real last lines

`packages/jet_cad_2d_plan`:

- `flutter analyze` — `No issues found! (ran in 4.0s)`
- `dart format --output=none --set-exit-if-changed .` — `Formatted 308 files (0 changed) in 0.78 seconds.`
- `flutter test --enable-vmservice` — `02:11 +1580: All tests passed!`
- mutation, `flutter test test/service/paint/unit_theme_painter_test.dart test/service/view/status_caption_test.dart` — `00:01 +26 -3: Some tests failed.` (above); reverted, the three caption files — `00:00 +42: All tests passed!`

`apps/restaurant_demo`:

- `flutter analyze` — `No issues found! (ran in 3.9s)`
- `dart format --output=none --set-exit-if-changed .` — `Formatted 38 files (0 changed) in 0.07 seconds.`
- `flutter test` — `00:22 +102: All tests passed!`

`packages/jet_cad_2d_flutter` (touched: the two caption constants' doc
comments):

- `flutter analyze` — `No issues found! (ran in 4.3s)`
- `dart format --output=none --set-exit-if-changed .` — `Formatted 234 files (0 changed) in 0.50 seconds.`
- `flutter test` — `00:20 +1453 ~1 -5`: the 5 are `text_ladder_golden_test.dart`'s, exactly `tool/ci/standing_failures.txt`'s macOS text-metric goldens; nothing else red.

`tool/ci`:

- `dart test` — `00:41 +114: All tests passed!`

## What I could not do and open questions

- `packages/jet_cad_2d` and `jet_cad_2d_gpu` were not run: no file in them
  changed.
- `jet_cad_2d_flutter`'s 5 failures are the standing golden ones listed in
  `tool/ci/standing_failures.txt` (macOS text metrics), not this change; the
  diff there is two doc comments.
- Open: none. D6c is amended in the spec; the CHANGELOG carries the change
  under `## Unreleased` (the 0.8.1 bump is not this task's).

Co-Authored-By: DeepSeek V4.1 Flash Free <noreply@opencode.ai>
