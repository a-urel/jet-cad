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
  here, and a reviewer may want it decided in the dark-theme spec.

Co-Authored-By: DeepSeek V4.1 Flash Free <noreply@opencode.ai>
