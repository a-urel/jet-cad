# Plan 09c-2 results — the Symbol section and the wall-aware move

**Branch:** `claude/exciting-pasteur-9m22jv`, restarted from `main` at
`f2c4875` (09c-1 merged at `cf463d8`). **Spec:**
[2026-10-02-wall-aware-symbols-design.md](../specs/2026-10-02-wall-aware-symbols-design.md),
revision 5 with its spot check (V-1..V-9): D7, D8 and every revision-5
amendment. **Plan:**
[2026-10-04-symbol-section.md](../plans/2026-10-04-symbol-section.md).
**Approval:** revision 4 by the human ("yaz", 2026-10-02); revision 5 and
this plan on the human's "Devam et, 09c-2'yi başlat" (2026-10-04), while
travelling, on their word not to be asked unless needed. **Not merged.**

With one symbol selected, the Selection panel shows a **Symbol** section
above the Table section: its name, its size `W × D`, a **Rotation** field
in degrees (the turn composes about the insertion point; a quarter turn is
exact), a **Mirror** button (about the box's centre `x`, the footprint
kept) and, when the symbol has a size family and is not a table, a **Size
menu** whose choice swaps the definition in one `Change size` step, the
back-left corner kept. A table shows the section too, its Rotation and
Mirror in the design mode only (V-1), and its number stays upright. A
symbol tagged `against-wall`, dragged alone by its body with Shift up and
object snap on, attaches to a wall face as a placement does, anchored on
its plain-moved back-centre; the hourglass marks the face point. Without
the resolver, or when it answers null, a move is today's bit for bit.

## Commits

| Task | Commits | Review |
|---|---|---|
| Spec rev 5, spot check, plan | `70cf5f6`, `8c3761e`, `8a3c8c0` | rev 5: spot check "Ready with amendments" (V-1..V-9), applied |
| 1 `SetInstanceDefinitionCommand` (engine) and the render caches | `20fa092` | the joint review |
| 2 The render seam: `MoveResolver`, `GripDrag.moveToTransform`, the `nearest` glyph | `8430412` | the joint review |
| 3 The Symbol section | `af1825e` | the joint review |
| 4 The wall-aware move | `7015c52` | the joint review |
| 5 End to end; the catalog pins; the review's fixes | `3f5d88c`, `d0e4519`, `266e609` | — |

**Process, stated plainly:** unlike 09c-1, these tasks were implemented
by the controller itself, not by a fresh implementer each, and had no
per-task reviewer; each task's mutants were fired by the controller
against its own tests. One independent code review covered Tasks 1–4
together (below). **The joint review** (a fresh reviewer, a scratch clone, on `7015c52`):
no blocking finding; the production code matched D7 and D8 on every
point it checked. Three should-fix findings, all surviving mutants:
**M-09c-bf** (the Size menu's servable guard: SW5's family was all
tables, so V-4's member filter hid the menu either way), **M-09c-y**'s
box-centre and origin variants (SS2's bed has its base point at its box's
centre; SW6 checked degrees only), and **M-09c-ao**'s grip half (every
resolver test had `grips: null`). Seven nits: the loader swap untested,
the no-op's translation half untested in the render layer, a literal
orthonormal test beside `isOrthonormal`, re-picking the checked size
re-copying an older or edited definition, the Rotation commit reading the
live selection rather than its pinned target, an unsigned keyboard on a
phone, and the section order unasserted. All are applied in `266e609`
(tests SW5, SW6, SW7–SW9, SS10, SS11, MR3, MR9, SW1; code: `isOrthonormal`,
the display step named, a same-key size change is nothing, the pinned
target, `signed: true`), each with its mutant red. The reviewer's last
nit, the grid glyph while attached, is an equivalent mutant (below).

## Gates (Linux container, Flutter 3.47.6 / Dart 3.13.5)

| Package | Result |
|---|---|
| engine `packages/jet_cad_2d` | **1,241 passed** + 2 standing (`generate_document_test`, as before); analyze, format clean |
| render `packages/jet_cad_2d_flutter` | **1,239 passed** + 1 skip + 7 standing (the text ladders, as before); analyze, format clean |
| planner `packages/jet_cad_floor_plan` | **1,164 passed**; analyze, format clean |
| restaurant symbols | **94 passed**; analyze, format clean |
| app `apps/floor_planner` | **201 passed**; analyze, format clean |
| demo `apps/restaurant_demo` | **17 passed**; analyze, format clean |
| `apps/dev_harness_2d` | analyze clean (V-8) |
| web builds | `apps/floor_planner` and `apps/restaurant_demo`: `✓ Built build/web` |

Against 09c-1's merge: engine +4 (ID1–ID4), render +10 (IC1, MR1–MR9),
planner +26, restaurant +3 (SC1–SC3), app +1 (WE3). The two allocation
invariant tests and the goldens are untouched.

**Smoke (Chromium, tr-TR, the floor planner's web build at `266e609`):**
a wall drawn with the Wall tool; the double bed placed from the Symbols
tab lands flush on its lower face. Selected, the right panel shows the
Symbol section (Double bed, 1600 × 2000, Rotation 0, Mirror, the Size
menu). Dragged by its side 200 px along and 15 px off the wall, the
preview stays flush with the hourglass on the face, and the release
commits it there. The Size menu lists 1400, 1600 and 1800 × 2000; 1800
keeps the left side and grows to the right, flush. Rotation 45 turns it
in place about its centre (the base point); Mirror is a step (a double
bed looks the same mirrored); three ⌃Z restore the 1600 bed at its moved
place. No page or console error.

## Mutants fired

All red unless listed under *Survive*.

- **Task 1:** **M-09c-w** (undo keeps the new definition: engine and
  render red), **M-09c-bc** (no `invalidateDerived`: engine red, through
  the extents test ID2).
- **Task 2:** **M-09c-aa** (the preview is `T'` itself, not the delta),
  **-ad** (the commit is `delta · T`), **-ae** (a no-op at the press
  point), **-ao** (Shift ignored), **-av** (`moveTo` keeps `T'`), **-aw**
  (a camera change does not ask again), **-ax** (asked with two keys),
  **-z** (asked when Shift added a key); own: the marker kind ignored, the
  `nearest` glyph removed (V-2), `singleNode` for any capture count.
- **Task 3:** **M-09c-u** (the size change anchors the base point), **-v**
  (always copies), **-x** (`atan2(b, a)`), **-y** (the turn pivots on the
  origin), **-al** (the mirror dropped; the scale dropped), **-be** (the
  size with geometry denied; the rotation needs geometry), **-bg** (a
  table's Rotation under `runtime`), **-bh** (Mirror about the base point;
  about the origin; and, in `d0e4519`, about the origin and the box's left
  side on the real corner booth), **-bi** (a servable member listed); own:
  no loader listener (V-3), no leaf-order assert (R5-7), the family not
  sorted, not memoised, a quarter turn inexact, the re-commit tolerance
  removed.
- **The review's fixes:** M-09c-bf (SW5), M-09c-y's box-centre and
  origin pivots (SS10, SW6), M-09c-ao's grip half (MR9), the no-op's
  translation half (MR3), the loader swap (SW7), an unsigned keyboard
  (SW8), the commit reading the live selection (SW9), the own key
  re-copied (SS11), `isOrthonormal` never true (SS3).
- **Task 4:** **M-09c-am** (a scaled instance attaches), **-an** (anchored
  on the insertion point), **-az** (F3 ignored), **-ab** (its own instance
  a neighbour); own: the tag ignored, the mirror dropped, the marker not
  the face point.
- **Task 5 (WE3):** the shell's `SelectTool` built without the resolver;
  the panel built without the loader (V-3).

**Survive, recorded:**
- **`SetInstanceDefinitionCommand` with `touched: {}`**: equivalent; an
  empty set means "the whole document" to every listener, a superset of
  `{handle}`.
- **`grid: !_attached && …` in `_paintGuide`**: equivalent; while
  attached the marker's kind is `nearest`, and `drawSnapMarker` draws the
  grid's `+` only when no kind is given.

M-09c-bf, which the controller first judged masked, is not: a servable member of a
non-servable family (`test.bed.table` among the beds) shows it; SW5 now
kills it (the joint review's finding).

## Amended at execution

- **Undo does not rewind the handle seed.** WE3's "undo four restores the
  bytes" holds for every key but `handleSeed`: the Change size copy
  allocated five handles, and handles are never reissued (plan 2's rule).
  The test compares the rest and pins the seed.
- **The Rotation field rounds what it shows** to 1e-6 and shows 360 as 0;
  committing the shown value again is nothing (a turn within one display
  step is a no-op), so a bed at 29.999999999999996° re-typed as 30 makes
  no step.
- **The Rotation field's display step is named**
  (`kRotationStepsPerDegree`, a million per degree): the field's rounding
  and the Rotate step's "nothing to do" share it. It is a property of the
  field's text, not a geometric tolerance, so it is not `Tolerance`; the
  orthonormal test at a quarter turn goes through `isOrthonormal`
  (`Tolerance.standard.linear`).
- **The planner's ghost** draws its marker through the render layer's
  `drawSnapMarker(nearest)` (R5-5); its own `drawNearestMarker` is gone.
- **R5-3's and V-6's catalog pins** run in the restaurant package, which
  sees both libraries: 30 servable entries (the restaurant's 25 and the
  furniture library's five dining tables), none with a family; every
  against-wall entry's base point on its box's centre `x`.

## Found, not fixed

- **No upgrade by re-picking.** An instance drawn from an older version of
  its entry keeps it: re-picking its checked size is nothing (the
  review's nit 7). Upgrading a placed symbol is not in 09c.
- **M-09c-ao's grip half is reachable only through a provider's centre
  grip** (an instance has no grips): MR9 builds one; the planner's
  objects give a symbol none.
- **No device was measured** for the Rotation field's signed keyboard.

## For the human

- **Look owed (macOS and web):** select a bed against a wall; drag it
  along the wall and to another wall (the hourglass shows the face point;
  Shift or F3 off moves it freely); in the Symbol section type a rotation,
  press Mirror, pick another size from the menu; undo each. Select a
  table: Rotation 37, then Mirror: the number stays upright; in Service
  the two rows are read-only and there is no Size menu.
- **Merge:** on the human's word.
