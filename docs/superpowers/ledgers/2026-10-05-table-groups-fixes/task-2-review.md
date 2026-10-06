# Task 2 review: the chip outside the frame (X3)

Reviewer: independent. Commit under review `7a96dc5` on `d8d06ed`. Review worktree: `.worktrees/tgf-review`, detached at `7a96dc5`; `CI=true flutter pub get` run first. Its only effect was to rewrite `packages/jet_cad/analysis_options.yaml`, which I ignored and did not commit. Scratch files: `scratchpad/tgf-review2/`.

## Verdict: Approved

No blocking, major or minor findings. Two notes are at the end.

## 1. The implementation against spec X3 and plan Task 2

- **Painter** (`table_group_painter.dart:425`): the translate is now `translate(sx - p.width / 2, sy - (p.height + kGroupChipPaddingY))`.
  - The prebuilt rect (`:323-328`) is `RRect.fromLTRBR(-padX, -padY, w + padX, h + padY, r)`. Its bottom on screen is `sy - h - padY + h + padY = sy`, so it lies exactly on the anchor. Its top is `sy - h - 2·padY`, matching X3's `[sy - p.height - 2·padY, sy]`.
  - Horizontally the rect is still centred: `sx - w/2 + (-padX + w + padX)/2 = sx`.
  - Only a constant changed. There is no new object, field or closure on the frame path, the `debugAllocations` and `debugRebuilds` sites are untouched, and the allocation invariant tests are unedited (the diff stat under `**/invariants/**` is empty).
- **The anchor is unchanged:** `((minX + maxX) / 2, maxY + kGroupFrameMarginMm)` over the hull (`:339-343`), which is the bounds' top line at their centre x, as X3 says.
- **Docs.** The `_Group` anchor doc (`:172-174`) and the class doc (`:196-199`) are updated, and a comment sits at the translate. The class doc's "translates to each chip's anchor" is still accurate.
- **Parent spec.** The X3 bullet is appended after Task 1's F-1 bullet and before R-C5-2. The R-C5-1 retirement and the F-1 "closed" text from Task 1 are intact (checked in `2026-10-04-table-groups-design.md:636-659`). The bullet marks G3's placement superseded, states the translate, notes that a slanted frame floats a little, and says the hiding rule and the per-frame recipe are unchanged. This matches X3.
- **Scope.** Changed files: the painter, the two tests and the parent spec.
  - `git diff d8d06ed..7a96dc5 --stat -- packages/jet_cad_2d packages/jet_cad_2d_flutter` is empty.
  - No `analysis_options.yaml` is committed.
  - Groups are not touched by the document, and the no-groups path is unchanged (`list.isEmpty` returns early, as before).

## 2. Existing-test changes: only TG-V2 and TG-L7, both per X3

I read the whole diff. No other existing test is edited. The hunks in `table_groups_look_test.dart` outside TG-V2 are all things X3 asks for, so they are allowed:
- the header comment;
- the new `kChairRowsUp` const;
- `lookController`'s doc;
- table 20's placement.

**TG-L7**
- The expectation is now `dy == sy - (p.height + kGroupChipPaddingY)`, within 1e-6, as X3 requires.
- The scale loop is now `[0.04, 0.06, 0.11]`, which adds X3's 0.04.
- The `dx`, `RRect`, paint and hiding assertions are byte-identical.
- The title was also reworded (R-C2-1, below).

**TG-V2**
- **Table 20.** It moved up by `kChairRowsUp / pxPerMm` = 8 px = 64 mm, with its chair's bottom line at `kAnchorY + 64` world. This is X3's "move table 20 up by a whole number of pixels (8 px = 64 mm)".
- **Premises.** All are asserted, not argued:
  - the chip's bottom is at `kAnchorRow + 0.5` (the anchor row centre);
  - the chair row is `o.dy + kAnchorRow - kChairRowsUp`;
  - the four inset corners of the sampled pixel are inside the shifted `RRect`, so a rounded corner cannot pass;
  - the row lies strictly between `chip.top` and `chip.bottom`;
  - the reference pixel `ax - 22` is clear of the chip.
- **Colour expectation:** unchanged.
- **Soundness.** The `RRect` is shifted by the layer origin `o` plus the recorded translate, the same composition the painter performs. The chair line runs ±225 mm (±28 px) about `kAnchorX`. The sampled `sx` is checked to be within that span, and so is `ax - 22`. The new clear-of-chip premise closes a real hole: without it, the non-white "chair line is drawn" premise could be met by the chip's own purple.
- Dropping `final p = spy.paragraphs.single` loses only a "one paragraph" check. `rrects.single` and `translations.single` still pin one chip.

## 3. Gates (re-run by me, Flutter at `/home/user/flutter`, `CI=true`, sequential)

| Package | test | analyze | format |
|---|---|---|---|
| packages/jet_cad_floor_plan | `06:15 +1283: All tests passed!` | No issues found! | 208 files (0 changed) |
| apps/floor_planner | `02:38 +201: All tests passed!` | No issues found! | 44 files (0 changed) |
| apps/restaurant_demo | `00:27 +28: All tests passed!` | No issues found! | 3 files (0 changed) |

The counts match the implementer's: +1283, +201 and +28. The render package diff since `d8d06ed` is empty, so it is not re-run here; the plan re-runs it at the exit.

## 4. Mutants (re-fired by me)

Method: `scratchpad/tgf-review2/mut.sh`. It backs up the file, applies a Python exact-string replace, runs `flutter test test/service/table_group_painter_test.dart test/host/table_groups_look_test.dart` (M-TG-22: the look test only), `cp`s the backup back and `diff`s it. Every run printed `RESTORED OK`. `git status` afterwards shows only the pub-rewritten `analysis_options.yaml`.

| Mutant | Change | Result | Red tests, first failure |
|---|---|---|---|
| M-TGF-8 chip still centred | `:425` `sy - p.height / 2` | **red** `+15 -3` | TG-L7 (`342.597…` vs `350.097…`, 7.5); TG-L11 `group 0 at 0.04 px/mm: the chip ends on or above the anchor (M-TGF-8)`; TG-V2 premise `300.5` vs `308.0` |
| M-TGF-9 chip floating | `:425` `… - 2` | **red** `+15 -3` | TG-L7 (differs by 2.0); TG-L11 `the chip rests on the anchor (M-TGF-9)`; TG-V2 premise `298.5` |
| M-TG-22 chips in the underlay | `service_view.dart` chips' `CustomPaint` moved into the underlay `Stack` after the status layer, `overlay:` removed | **red** `+4 -2` | TG-V1; TG-V2 on its **colour** expectation `the chip: 0x000000, want 0x7a3fd1`, `Actual: <209>`. Every premise held, so the new sample still kills it. |
| own A: chip horizontally off-centre | `:425` `sx - rrect.width / 2` (off by padX = 5 px) | **red** `+16 -2` | TG-L7 dx (differs by 5.0); TG-L11 centring (differs by 5.0) |
| own B: anchor x from the hull's top vertex, not the bounds' centre | `_rebuild` tracks the x of the hull's max-y vertex, passes it as `anchorX` | **red** `+16 -2` | TG-L7 (differs by only 0.229 px in its fixture); TG-L11 (differs by **102 px**, G3's slanted pair) |
| own C: draw-order sort removed | `:350` sort commented out | **red** `+16 -2` | TG-L5 (pre-existing); TG-L11 `group 0 at 0.04 px/mm … (M-TGF-9)`, `375.597…` vs `276.0`. The anchors pair with the wrong chips. |
| own D: rect top on the anchor (chip hangs into the frame) | `:425` `sy + kGroupChipPaddingY` | **red** `+15 -3` | TG-L7; TG-L11 (M-TGF-8); TG-V2 premise |

No mutant survives.

**TG-L11's pairing assumption.** Chips are paired with anchors by draw order: G7 (lowest handle 12) first, then G3 (lowest handle 3, then 20, then the duplicate 3).
- This matches the painter's sort: `out.sort` by `_Group.order = members.first.handle.value`, and `visibleMembers` is ascending by handle (`table_groups.dart:92-93`).
- It also matches `groupedPlan`'s handle order: 12, 3, 7, 20, 9, then the duplicate 3, placed in that order.
- The map is given G3 first, so the test does not depend on map order. Own C shows that a broken order makes TG-L11 red rather than passing by accident.

## 5. Degenerate fixtures

TG-L11's fixtures are all non-trivial:
- the off-origin, non-unit camera (y flipped; the rotation-free camera is X3's stated assumption, F-7);
- turned and mirrored tables;
- a file-duplicate number contributing to the frame;
- a hidden member that is excluded;
- two groups given in non-draw order;
- an independently computed anchor (`cornersOf`, not the painter's hull).

TG-L7 has the same camera and tables. TG-V2 uses the turned and mirrored members and a non-zero camera offset.

A locked member is not exercised in the X3 tests. That is acceptable: X3 changes no visibility or lock rule, and a locked visible member is in the frame exactly like an unlocked one (`visibleMembers`).

## 6. Rulings

- **R-C2-1, TG-L7's title reworded: accepted.** The old title stated the superseded placement, so keeping it would make the test lie. The behavioural change is exactly X3's (the expectation, plus 0.04), and the title has no effect on behaviour.
- **R-C2-2, M-TGF-8/9 at 0.125 in a new TG-L11: accepted.** Spec M-TGF-8/9 asks for 0.04 and 0.125 within 1e-6. TG-L7's loop gained only the spec's 0.04, which keeps the deliberate change minimal. TG-L11 adds what TG-L7 lacks: 0.125, two groups (it pins the per-group pairing and the draw order) and the explicit "no own member below the chip's bottom" check. Own B shows the value: in TG-L7's fixture the top-vertex mutant moves the chip by 0.23 px, while TG-L11 moves it by 102 px.
- **R-C2-3, TG-V2's extra "reference pixel clear of the chip" premise: accepted.** It is a premise only and closes a vacuous pass. The colour expectation is unchanged.

## Notes (no action required)

1. **TG-L11's per-corner check is algebraically implied by the bottom-equals-anchor check** (the anchor is the corners' max y plus the margin), so it adds no kill on its own. It states X3's "covers no member of its own group" directly, so it is worth keeping.
2. **Under M-TGF-8/9-style mutants, TG-V2 goes red on its first premise, not on pixels.** That is intended: the pixel expectation belongs to M-TG-22, which leaves every premise holding and fails on the colour (verified above).
