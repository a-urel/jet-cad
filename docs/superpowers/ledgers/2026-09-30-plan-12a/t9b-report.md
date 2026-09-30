# Task 9b report: the narrow-window floor and DC12b's premise (plan 12a)

**Commit:** `da20206` `fix(app): the top bar lays out down to the old narrow-window floor`, on `2d57d22`, with both trailers. Not pushed.

**Files:** only `apps/floor_planner/lib/main.dart` (+24/−8 with the import) and `apps/floor_planner/test/document_commands_test.dart`.
- `git diff --stat 2d57d22 HEAD -- packages/` is empty, so the engine and render packages are untouched.
- There is no `docs/`, `roadmap/` or `STATUS.md` edit.
- `analysis_options.yaml` is not committed. `packages/jet_cad/analysis_options.yaml` is left modified in the tree; that is the known `pub get` rewrite.

## m-1: the fix (`main.dart:696-729`)

- **What moved:** the fixed `SizedBox(width: 16)` before OSNAP is now inside the shared `Expanded`'s `LayoutBuilder`, as its last child.
- **What the builder computes:** with `free` = the `Expanded`'s width:
  - `tail = min(16, free)` is the gap before OSNAP;
  - `shared = free - tail` is what the name and the status share;
  - `gap = min(16, shared)` is the gap after the name;
  - the name's cap is `min(shared / 2, shared - gap)`.
- **Ordinary widths:** when `shared >= 32`, this is exactly Task 9's layout. The cap is `shared / 2`, both gaps are 16 px, and the status takes the rest. So DC12 and DC12b pass unchanged: `status.left - name.right == 16`, and the name width is `closeTo(shared / 2)`, where `shared = status.right - name.left`.
- **Narrow widths:** when `shared < 32`, the cap gives way to the gap. Below that, both gaps shrink to 0, so nothing inside the `Expanded` can overflow.
- **Why not the reviewer's `max(0, (W - 16) / 2)`:** it would move the name off the exact half at 1440 px (by 8 px), and DC12b asserts that half.
- The gap between the toolbar and the name stays a fixed 16 px, as it was in `5998504`.

## Measured first overflow

A temporary probe steps the width down by 1 px at 600 px high, from 700 px. It was deleted and never committed. The fixture is DC12c's: a titled, dirty document with a long name and a long Room notice.

| Tree | First overflow |
|---|---|
| Task 9 layout (`2d57d22`) | **623 px** (0.5 px) |
| Final tree | **575 px** (1.00 px, lays out at 576 px) |

- **Where the final tree overflows:** in the `chrome-top` row itself. At 575 px, `zoom-text.right` is 564, beyond the 563 px inner edge, and the name and the status are 0 wide.
- **Why 576 px is the floor:** it is padding + toolbar + gap + OSNAP + gap + zoom, with nothing left over.
- **The `5998504` bar on the same fixture:** mutant E below is red at 591 px, and 592–624 px are green. The review's 590 px came from 2 px steps.
- **Result:** 575 px is below the 590 px floor.

## DC12c (`document_commands_test.dart:987`)

- **Fixture:** helper `longNameAndStatus` (`:154`). It is built at 1440 × 900: Open of a titled long name, a long room name, then the Room tool hovering the room to get the notice.
- **Loop:** the surface then steps from **624 px down to 576 px**, 1 px at a time, at 600 px high. The range covers the old 590/591 px floor and ends at the floor I measured.
- **At each width it asserts:**
  - `takeException()` is null (`:1003`);
  - both texts are still up (premise);
  - `name.right <= status.left`;
  - the bar is that wide (premise);
  - OSNAP and the zoom have width > 0 and end inside the bar.
- **Why a loop and not one width:** a single width cannot catch every mutant (C2 is visible only between 592 and 624 px).

## m-2: DC12b's premise (`:961`)

- **Now:** it reads `paragraph(status).getMaxIntrinsicWidth(double.infinity)`, with a comment that the paragraph's size is its `Expanded` slot's.
- **On the final tree it holds:** intrinsic 698.25 > `shared / 2` = 424 (shared 848, slot 746.5). I got these numbers from a temporary print mutant, H, which was restored.

## Mutants

Each mutant was applied by `cp` to a backup `scratchpad/p12t9b-<name>-<file>.bak` and then a mutation. The script is `scratchpad/p12t9b-sweep.py` and the results are in `p12t9b-sweep.out` and `p12t9b-<name>.log`.
- Each run: `CI=true flutter test test/document_commands_test.dart --plain-name DC12` (DC12, DC12b, DC12c).
- Each file was restored by `cp` in a `finally`. **Every restore printed `diff=0`.**
- At the end, `lib/main.dart` was identical to the fixed snapshot. The test file differs from its snapshot only by the 2-line DC12c comment, which I corrected (591, not 590) after the sweep. Line numbers did not change.

| Mutant | Mutation | Result | Red at |
|---|---|---|---|
| A (brief a) | `main.dart` = the `2d57d22` copy (Task 9 layout) | +2 −1 | **DC12c :1003** at 623 px (overflowed by 0.5) |
| B (brief b) | fixed OSNAP gap restored alone (`tail = 0.0`, `const SizedBox(width: 16)` before OSNAP) | +2 −1 | **DC12c :1003** at 591 px (1.00). Fits at 592, so it is also red at 590. |
| C (brief c) | uncapped half restored alone (`maxWidth: constraints.maxWidth / 2`) | +1 −2 | **DC12b :973** (name 432 vs `shared / 2` 424); **DC12c :1003** at 624 px (8.0) |
| C2 (own) | the half without the gap clamp (`maxWidth: shared / 2`) | +2 −1 | **DC12c :1003** at 623 px (0.5). Visible only while 0 < shared < 32 (592–624 px), not at 590 or 576. This is why DC12c steps. |
| D (own) | fixed gap after the name (`const SizedBox(width: 16)`) | +2 −1 | **DC12c :1003** at 607 px (1.00) |
| E (review "old layout") | the `5998504` bar block (`Flexible` name, `Flexible` status, `Spacer`) | +1 −2 | **DC12b :956** (the notice is cut; was :923 before the helper moved it); DC12c :1003 at 591 px |
| F (review "halves") | `Flexible` name + `Expanded` status, 16 px before OSNAP | +1 −2 | **DC12b :956**; DC12c :1003 at 607 px |
| G (m-2) | DC12b fixture room name `'den'` | +2 −1 | **DC12b :961**, the premise: 370.5 is not > 424 |
| G2 (m-2 contrast) | `'den'` with the old `size.width` premise | +2 −1 | DC12b **:976** (status not cut after the long name). The old premise line passed on `'den'`: it was tautological. |
| H (probe) | print the premise's numbers | +3 | green (numbers above) |

## Gates (app package, final tree)

| Gate | Result |
|---|---|
| `CI=true flutter test` | `+596: All tests passed!` (595 + DC12c), exit 0 |
| `flutter analyze` | `No issues found!`, exit 0 |
| `dart format --output=none --set-exit-if-changed .` | `Formatted 127 files (0 changed)`, exit 0 |
| `flutter build web --release` | `✓ Built build/web`, exit 0 |

The engine and render packages were not re-run; their tree is untouched (see the empty `git diff --stat` above).
