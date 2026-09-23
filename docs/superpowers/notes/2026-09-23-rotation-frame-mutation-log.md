# Rotation frame — mutation log

Branch `fix/rotation-frame`, cut from local `main` at `27b99dc`. A finding from
the human's look: the rotation grip returned to screen-up after every rotate,
and a second rotate pivoted about the re-wrapped world box's centre. The fix
(spec 03 D6, "Amended after the look") gives `GripCache` an oriented frame
carried through the select tool's own move and rotate commits.

Every mutant was fired by a scratch script: `cp` the file to a backup, apply
one exact-string replacement, run `grip_cache_test.dart`,
`select_tool_drag_test.dart` and `selection_overlay_grips_test.dart` with
`CI=true`, `cp` the backup back. `git diff --stat` after the run showed only
the branch's own changes, and the three files re-ran green.

| ID | Mutation | Killed by |
|---|---|---|
| M-RFa | the select tool never calls `carry` (the pre-fix behaviour) | `select_tool_drag_test.dart`: two rotations equal one of their sum; the grip rides the frame; the fold-back test |
| M-RFb | `pivot` is the box centre without `frame` applied | a move carries the rotated frame along, and the pivot with it (a pure rotation fixes its own pivot, so the differential cannot see it) |
| M-RFc | the identity-frame placement is used for every frame (grip always screen-up) | the grip rides the frame; the overlay's rotate-drag test |
| M-RFd | the top edge is always local `maxY` | the grip rides the frame (`flipY: false`); the overlay's rotate-drag test |
| M-RFe | `m.b`/`m.c` transposed in the composed matrix | the grip rides the frame (`flipY: false`); the overlay tests, including M-03bi's |
| M-RFf | `frame.multiply(T)` instead of `T.multiply(frame)` | a move carries the rotated frame along |
| M-RFg | the pending carry is not cleared once consumed | undo, a reshape and a new selection fold the frame back |
| M-RFh | a pure-translation frame is kept, not folded back | a move of an unrotated selection keeps the world box |
| M-RFi | the overlay ignores the preview's `T` | the overlay's rotate-drag test |
| M-RFj | the stem drawn to the disc's bottom, screen-down | the overlay's rotate-drag test |
| M-RFk | a carry pending across a selection change is applied | `grip_cache_test.dart`: a pending carry is dropped on a selection change |
| M-RFl | the identity-linear path projects through the camera alone, ignoring the frame's translation | `grip_cache_test.dart`: an unrotated frame places the grip as D6 does |
| M-RFm | the stem ends past the disc's centre (sign) | the overlay's rotate-drag test; the grip rides the frame |
| M-RFn | `hitsRotationGrip` ignores the frame | two rotations equal one of their sum; the grip rides the frame; the throwing-command test |
| M-RFo | `rotationGripOf` composes `frame · T` instead of `T · frame` for the preview | `selection_overlay_grips_test.dart`: a move of a rotated selection draws the grip through `T · frame` |
| M-RFp | the overlay drops a move's preview (a translation) and draws the grip at rest | the same |
| M-RFq | `dropCarry` does nothing | a carry whose command throws is dropped: the next undo still folds back |
| M-RFr | the select tool reads `T` before the up's `_follow` (Ruling 03-13) | a move carries the rotated frame along, and the pivot with it (the up lands away from the last move) |

18 of 18 killed. Every row was re-fired on the final tree after the review
round below.

**Equivalent, removed:** the carry's `_box == null` guard. A selection with
no box cannot rotate, and its move folds back through the identity-linear
check, so the guard changed nothing. The review found it survived; it was
deleted rather than kept.

The differential compares a triangle rotated by θ₁ then θ₂ with one rotated by
θ₁ + θ₂, for (0.5, 0.5), (−0.9, 0.4) and (1.2, 1.5). The triangle has no
symmetry, so a re-wrapped world box's centre moves under a rotation. Its first
draft sent both drags in one synchronous stack. The `DocChange` reaches the
caches a microtask later, so the second press saw the unrotated cache, and the
test passed on the pre-fix code. It now awaits a microtask between the two
drags, as a user's second press always does.

## Review

One Opus reviewer on the full diff: **Ready with fixes**, 0 blocking, 3
important, 7 minor. All ten were addressed on this branch:
- **I1:** the overlay's `T · frame` order, and a move preview, were
  untested; two mutants survived the full suite. M-RFo and M-RFp now die.
- **I2:** a carry whose `execute` threw lingered, and the next undo applied
  it. The reviewer reproduced this with a throwing `onBeforeMutate`. It is
  fixed by `dropCarry` and pinned by M-RFq.
- **I3:** the spec placed the rotated-camera step at the end of the first
  rotate. It happens on the first frame of the drag. The spec text is
  corrected. No shipped gesture rotates the camera.
- **M1:** one `Transform2` was allocated per frame. The preview is now
  composed inline in `rotationGripOf`.
- **M2, M5, M6, M7:** spec text. The superseded pivot sentence, why the
  identity test is exact, `box`'s new meaning, and the leaf grips staying
  put during a drag.
- **M3:** M-RFr.
- **M4:** the equivalent guard above.
