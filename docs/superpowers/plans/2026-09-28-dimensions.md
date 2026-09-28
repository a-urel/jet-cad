# Dimensions (sub-project 11) — implementation plan

> **For agentic workers:** executed task by task, subagent-driven: a fresh
> implementer per task and an independent reviewer per task, then a final
> whole-branch review. Steps use checkbox (`- [ ]`) syntax.

**Goal:** associative dimensions in the floor planner. A dimension is its
own parametric object. It stores:
- two ends, each either a wall end point it follows (a wall's start or end,
  on its left face, its centreline or its right face, corners included) or
  a fixed point;
- a kind (aligned, horizontal, vertical);
- a signed offset.

It generates a dimension line, two extension lines, two architectural
slashes and its value in the page's unit. It regenerates in the same undo
step whenever anything it measures moves. Its extension lines are drawn,
but they never take a click, a hover, a band's membership or a snap.

**What ships:**
- the Dimension tool (**I**): three clicks, and Shift for linear by the
  side dragged to; while F3 is on, an end attaches by position;
- the six attach points per wall, computed from 07's drawn joint geometry;
- grips: the offset, and the two ends (attach, detach, re-attach);
- a Dimension section in the Selection panel: the value, Aligned |
  Horizontal | Vertical, "Axes turned", and the two end lines;
- diagnostics: `dimension.degenerate` and `dimension.broken`;
- the sample plan's five dimensions;
- in the engine, one generic flag: `EntityFlags.unpickable`. Picking and
  snapping skip it, and the renderer still draws it.

**Architecture:**
- **The engine** (decision 25, D19) gains one small generic change:
  - a not-pickable entity bit (`1 << 1`);
  - `QueryFilter.excludeUnpickable` and a `QueryFilter.snapping()` preset;
  - `snapInto`'s default filter becomes `snapping()`.

  It touches four `lib` files and nothing else in `packages/`. It lands
  first (Task 1) and is frozen after it.
- **The render layer:** no change (decision 20). Its one named mutant,
  M-11b-cam, is fired and restored (Task 15).
- **The app** (`apps/floor_planner/lib/parametric/`):
  - `dimension_geometry.dart`, pure Dart: the value types, the attach
    points, the measuring direction, the layout, the placement function,
    `readable`, the format, the tolerances and the paper constants;
  - `dimension_attach.dart`, pure Dart: the candidates, the line test, the
    opening hosts, and decision 19's choice;
  - `dimension.dart`: the parameters, the type and the generate counter;
  - `dimension_tool.dart` and `dimension_grips.dart`;
  - `wall_geometry.dart` gains `drawnCapsOf`;
  - small edits to the catalog, the object grips, the Selection panel,
    the shell, the shortcut guard and the sample plan.

**Tech stack:** Dart, Flutter 3.47.2 (`/root/flutter/version`);
`package:test`, `flutter_test`, `vector_math`. No new dependency.

**Spec:** [docs/superpowers/specs/2026-09-28-dimensions-design.md](../specs/2026-09-28-dimensions-design.md),
**revision 4** (`1fca97a`), with its Revision 2, 3 and 4 sections. Read it
whole before Task 1. It has:
- 19 decisions, D1–D19;
- **75 named mutants**:
  - the roadmap's seven (M-11a–e as carried or redefined, M-11d2 and
    M-11b-cam);
  - eighteen carried from the spike;
  - fifty new;
- 66 test identifiers and 16 exit criteria;
- no open question.

The spec was reviewed independently twice:
- `11-spec-review.md`: S-1 to S-12, revision 1;
- `11-spec-review-r2.md`: S-13 to S-16, revision 3.

Every finding was applied, or answered by the human (decisions 22–25).
**The human's decisions** 1–25 are in the brainstorm record
(`11-brainstorm-decisions.md` in the session scratchpad; the ledger copies
it). Later decisions supersede earlier ones where they say so:
- 22 supersedes 19's timing;
- 24 and 25 supersede revision 2's R-35;
- 25 supersedes D1's "no engine change".

**Evidence:** [the spike findings](../notes/2026-09-28-dimensions-spike-findings.md)
and its renders in [2026-09-28-dimensions-spike/](../notes/2026-09-28-dimensions-spike/).
The spike is on branch `spike/11-dimensions`: head `675f997`, code at
`383dc57`. Read any of it with `git show spike/11-dimensions:<path>`.
**Port from it; never merge the branch.** It is the reference
implementation of:
- `apps/floor_planner/lib/parametric/dimension_geometry.dart`:
  - `wallEndPoint`, `wallEndPoints`;
  - `roundHalfUp`, `formatDimension`, `_fraction`;
  - `readable`, `layoutDimension`;
- `apps/floor_planner/lib/parametric/dimension.dart`:
  - `DimEnd`, `AttachedEnd`, `FixedEnd`;
  - `DimensionParams`, `DimensionType.generate`, `endPointInView`;
  - `attachMatches`, `attachAt`;
- `apps/floor_planner/test/spike_dims/`:
  - `support.dart`: `groupFor`, `worldWalls`, `othersOf`,
    `addDimension`, `fixedAt`, `dimText`, `dimLines`, `dimTextGeometry`,
    `allWorldWalls`, `oracleEnd`;
  - `corner_test.dart` (Q1), `drift_test.dart` (Q2), `snap_test.dart`
    (Q3), `rotate_test.dart` (Q4), `engine_test.dart` (Q5),
    `render_test.dart` (Q6).

Two more references, in the session scratchpad and never committed. They
are read-only and **may be gone**; nothing depends on them:
- the spec's lineweight sweeps;
- the spec's flush-opening probe.

Both are under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/spec11-spike-tree/apps/floor_planner/test/spike_dims/`:
`spec11_lw_test.dart`, `spec11_lw_dpr1_test.dart`,
`spec11_lw_cap3_test.dart` and `spec11_flush_probe_test.dart`.

**Where this plan and the spec differ from the spike, the plan and the
spec win.** Never port these spike shortcuts:

| The spike | This plan |
|---|---|
| `capsOf` alone | `drawnCapsOf`, R-5 |
| `attachAt`'s face-first, lowest-handle order | decision 19's parallel measure first, R-17 |
| the snapped wall's rect query alone | the opening hosts and the line test, S-13 |
| `offset >= 0` | the sign bit, R-2, with the between band, R-7 |
| `==` on the offset | `compareTo`, D2 |
| `kDimLineweight = 30` | 25, D7 |
| unflagged extension lines | `EntityFlags.unpickable`, D19 |
| `kDimOffsetPaperMm` | none, R-10 |
| `debugDimensionReadsPlaces`, `readsPlaces`, `readBox` | not adopted, D5 |
| `kHalfTolerance`, `kVerticalTolerance`, `kAttachTolerance` | the named `Tolerance`s `dimFormat` and `dimAttach` |
| a computed `h1` for aligned | `h1 = 0` by definition, D6 |
| the Bath diagonal from E2/0/left, its fixed end on P5/1/right | E1/1/left to the basin, D17 |

**Roadmap input:** [roadmap/11-dimensions.md](../../../roadmap/11-dimensions.md).

**Inputs read for this plan:**
- `CLAUDE.md`, `STATUS.md`;
- the spec (revision 4), both spec reviews, the brainstorm's decisions
  1–25;
- the spike note and the spike's code and tests;
- Plan 10 ([2026-09-26-rooms.md](2026-09-26-rooms.md)) and its archived
  ledger:
  - [progress.md](../ledgers/2026-09-26-rooms/progress.md);
  - `standing-brief.md` and `standing-review.md`;
  - `task14b-brief.md`;
- the tree at `1fca97a`. Its code is `main` at `9774a55`; the spec
  branch adds documents only.

**Branch:** `plan-11/dimensions`, cut from `spec-11/dimensions` at the
commit that lands this plan. **Never push**: the human authorises every
push.
- **While in flight,** the ledger lives at
  `.superpowers/sdd/2026-09-28-dimensions/` (git-ignored).
- **As the branch's last commit,** it is archived to
  `docs/superpowers/ledgers/2026-09-28-dimensions/`. Nothing is appended
  after the archive.

**The base for every diff in this plan is `9774a55`.** It is `main`,
`origin/main` and the spec branch's cut point (checked on 2026-09-28:
`git rev-parse main origin/main` both answer `9774a55`).

**Branch-point counts (Linux container)**, as STATUS records them for
`main` at 10's merge:
- engine `+1037 -2`;
- render layer `+940 ~1 -7`;
- harness `+82`;
- app `+348`.

The ledger's first entry re-measures all four on `plan-11/dimensions`
before Task 1.

**Amended at execution:** nothing yet. Task 17 adds an "Amended at
execution (Plan 11)" paragraph after each task and after the mutant
assignment, in 10's form.

---

## Rulings made here rather than left to an implementer

Each ruling says what the plan does, why, and what it costs if wrong.
Rulings marked **(spec amended)** are written into the spec in Task 17.

- **Ruling 11-1 — test identifiers and test files.** All 66 of the spec's
  identifiers are kept, each in exactly one task (the Self-review's
  table). The files are the ones the spec's Files section names.
  - **`SL1` and `TL9`** go in a new file,
    `apps/floor_planner/test/dimension_shell_test.dart`. The spec names
    no file for them, and both run through the shell on the sample plan.
    **(spec amended)**
  - **`DL5` and `DF3`** land in Task 7, in the format and layout files
    Tasks 5 and 6 create. They need the object's diagnostics and
    placements.
  - **The plan's own clauses**, each named where it lands, each for a
    named mutant:
    - `AM2`: a degenerate wall, and C11's scaled variant through the
      index;
    - `AM6`'s through-the-tool clause runs in `TL6` (Ruling 11-7);
    - `TL8`: a hover on a centreline, and a commit's search count;
    - `SP5`: the dimensions' handles above every room child's;
    - `PN3`: −0.04° shows no line.
  - **Test files not edited:** 07's, 08's and 10's app test files. There
    are three exceptions:
    - `startup_plan_test.dart`: `SP1`, `SP5`, `SP8`, `SP9`;
    - a shell or paint test that the controller rules on (Ruling 11-14);
    - the engine test files D19 names:
      - `query_filter_test.dart`;
      - `snap_test.dart`;
      - `json_codec_test.dart`;
      - `attributes_test.dart`;
      - `support/clients.dart`;
      - `snap_centre_index_test.dart` (its reason string only).

    Task 16 checks this with a diff.

  **Cost:** none.
- **Ruling 11-2 — the value types live in the pure file.** **(spec
  amended, D1's Files)**
  - **`dimension_geometry.dart` holds:**
    - the types `WallSide`, `DimKind`, `DimEnd`, `AttachedEnd` and
      `FixedEnd`, with their JSON;
    - the tolerances `dimAttach` and `dimFormat`;
    - the five paper constants, `kDimLineweight` and `kDimTextAttrs`;
    - the functions:
      - `wallEndPoint`, `wallEndPoints`, `measuringDirection`;
      - `offsetFor`, `readable`, `layoutDimension` (with `DimLayout`);
      - `roundHalfUp`, `formatDimension`.
  - **`dimension.dart` holds:**
    - `DimensionParams`, `DimensionType` and `debugDimensionGenerates`;
    - `export 'dimension_geometry.dart';`, so callers import one file.
  - **Why:** D1 puts `WallSide`, `DimEnd`, `DimKind` and the paper
    constants in `dimension.dart`. But the pure functions D1 puts in
    `dimension_geometry.dart` and `dimension_attach.dart` take them.
    `dimension.dart` imports `package:flutter/foundation.dart` for
    `@visibleForTesting`, as `room.dart` does. A pure file importing it
    would depend on Flutter transitively. The app's pure files import only
    pure files today: `wall_geometry.dart` → `wall.dart`, and
    `room_inputs.dart` → `separator.dart`. Task 16's grep checks the
    imports transitively.
  - **The pure files' counters** (`debugLineTestPasses`) are plain
    top-level `int`s with a doc comment saying they are for tests. This
    follows 10's `debugTracedSegments` (10's Task 10 ruling: no
    `package:meta` dependency).

  **Cost:** none.
- **Ruling 11-3 — one layout, one measuring direction, one placement
  function.** One function each, in `dimension_geometry.dart`:
  - `measuringDirection(kind, p0, p1, m)` (D6's `u`);
  - `layoutDimension(p0, p1, kind, m, offset, page)`, all of D6–D8 in
    world;
  - `offsetFor(q, p0, p1, kind, m)` (D6's placement function).

  **Every caller uses them:**
  - `generate`;
  - the tool's preview and its third click;
  - the grips' preview and the offset grip;
  - `decideEnd`;
  - `DZ1`'s oracle.

  **Single sites:** each of these mutants lives in exactly one of the
  three functions:
  - M-11axisworld (`measuringDirection`);
  - M-11a (the value), M-11offsetp0, M-11scale, M-11textbelow,
    M-11slash, M-11extpage (`layoutDimension`);
  - M-11flip, M-11fliptol (`readable`, which `layoutDimension` calls);
  - M-11sign, M-11between (`offsetFor`).

  `TL3` and `GE2` re-fire M-11sign and M-11between at those one sites.
  The layout's `offset` argument is the **stored local** value, and it
  multiplies by `m.scaleMagnitude` once, inside. The paper constants
  multiply by `page.scaleDenominator` in one place.

  **What the shared layout means for `DZ1`:** its oracle is differential
  for the closure (which dimensions rebuild, from which walls). It is not
  differential for the layout; the hand-worked `DL1`–`DL5` pin that (D5).

  **Cost:** none.
- **Ruling 11-4 — the attach API.** In `dimension_attach.dart`:
  - `List<AttachedEnd> attachCandidates(DraftDocument doc, SpatialIndex
    index, Vector2 q, {required bool objectSnap, required double
    thickest})`:
    - empty when `objectSnap` is false;
    - otherwise D10's two rect queries, then the line test, then the six
      points among `wallsInDocument(doc, W)`'s walls;
    - ascending by wall handle, then `k`, then side.
  - `double thickestWall(DraftDocument doc)`: `T`, the largest **world**
    thickness of a live wall. Each wall's thickness counts times its
    group's `scaleMagnitude`, so a scaled group (file only) is covered.
    It is 0 with no live wall.
  - **What counts as live:** "a live wall" and "a live opening" are
    root-level `GroupNode`s carrying the component, as `_isLiveGroup`
    (`opening_geometry.dart:700`) tests. 08's final review m5 found a
    cache that kept non-live components.
  - **The local-frame line test** runs when the wall's group is not a
    rigid motion: `(m.scaleMagnitude − 1).abs() > dimAttach.angular`.
    A rotation's rounding leaves `scaleMagnitude` within about 1e-16 of
    1, far inside that band; a file's scaled group is far outside it.

  **Cost:** none.
- **Ruling 11-5 — `decideEnd` computes `u` itself.**
  `AttachedEnd? decideEnd(DraftDocument doc, List<AttachedEnd>
  candidates, {required DimKind kind, required Vector2 at, required
  Vector2 other, required Transform2 m})`.
  - It returns null for no candidates.
  - It computes `u = measuringDirection(kind, at, other, m)`, then applies
    D10's steps 1–4.
  - Each wall's direction `d_W` is its world start → end, through the
    document.
  - **Why:** M-11lineardir then has one site, not one per caller (the
    tool and the grips). M-11nearest ("the nearest candidate") needs the
    point being decided, `at`.

  **Cost:** none.
- **Ruling 11-6 — M-11snaponly's site is the tool, and `AM4` does not
  kill it.** **(spec amended: its killer is `TL6`)**
  - **Why `AM4` cannot:** decision 23 makes `attachCandidates` see only
    the resolved point. "An object snap won" is not in its inputs. A grid
    point on a corner is also a stored vertex there, so re-snapping
    inside the attach code finds the vertex either way.
  - **Why the grips cannot:** `ObjectGripProvider.drag` receives only the
    point (`grip_cache.dart:37`).
  - **The one site that can see it:** the tool's `hoverKind`. The mutant
    gates the tool's candidate search on `hoverKind != null`, and `TL6`'s
    grid row (F3 on, a grid point on a corner) kills it.
  - **What `AM4` keeps:** the attach-level half of decision 23, and it
    kills M-11snapoff.

  **Cost:** one killer fewer than the spec lists.
- **Ruling 11-7 — `AM6`'s tool clause runs in Task 9.** `AM6`'s last
  clause says "S/0/left attaches through the door's own jamb snap
  (`snapInto` at the jamb corner, then the tool's click)". The tool lands
  in Task 9, after `AM6`'s Task 4.
  - In **Task 4**, `AM6` calls `snapInto` at the jamb corner and then
    `attachCandidates` on the snapped point, which is what the tool's
    click does.
  - In **Task 9**, `TL6` repeats the case through the tool's pointer
    events.

  **Cost:** none.
- **Ruling 11-8 — caches and the asynchronous change stream.**
  - `doc.changes` is an asynchronous broadcast stream.
    `onAfterMutate`, the synchronous hook, belongs to the spatial index
    (`undo.dart:56-78`: one slot). So an app cache hears an edit a
    microtask late. 10's `RoomInputs` needed `invalidate()` for this
    (10's Task 9 m-3).
  - **The rule for 11:**
    - the tool's hover memo (attach candidates per distinct resolved
      point) and its cached `T` are keyed by a **generation**;
    - the generation is bumped on each `doc.changes` event, at the tool's
      own commit, and on `activate`;
    - **every click and every grip drop gathers afresh** against the
      document as it is then, and never reads a memo. D10 already says
      "the candidates are gathered at the commit, against the document as
      it is then".
  - **Widget tests** pump twice after an `undo()`, because the `DocChange`
    is asynchronous (10's `RN2` finding).

  **Cost:** a commit pays two fresh searches (`TL8` asserts the count).
- **Ruling 11-9 — the placements of the tool's world-axis cases.**
  - **The problem:** the tool places every dimension's group at the
    identity, so its horizontal and vertical measure along **world** x
    and y. The spec's corpus placements are turned 23°. Mapping `TL2`'s
    and `TL3`'s clicks through them turns the pair against the world
    axes and changes every hand value.
  - **The rule:** `TL2` and `TL3` run at the origin and at a new
    placement, `corpusAxis`: the corpus far origin (4,500,000, 1,200,000)
    **unturned**, declared in `dimension_fixture.dart`.
  - **Everything else about the tool** runs at the origin and at
    `corpusGroups`, as the spec asks: attachment, preview, notice and
    cost.

  **Cost:** none; the far origin is kept.
- **Ruling 11-10 — `AP3`'s bound at +1e9 mm.**
  - The spec gives 1e-9 mm "at the far origin in own groups" and asks for
    all six placements.
  - The spike measured the stored-versus-computed gap at +1e9 mm, turned,
    own groups, at 4.3e-7 mm (`Q3a`).
  - So `AP3` asserts:
    - 1e-9 mm at the origin and at both corpus placements;
    - `dimAttach.linear` (1e-5 mm) at the three +1e9 mm placements.
  - It prints the worst gap at each placement.

  **Cost:** none.
- **Ruling 11-11 — `DO2` starts from 1:50 in millimetres.**
  **(spec amended)**
  - The spec's `DO2` reads "a page change 1:50 m → 1:100 ft-in … undo
    restores `4000`". A metres page prints `4.00` (D9).
  - The spike's `Q5a`, which `DO2` quotes, attaches a **millimetres**
    page (`engine_test.dart:21-22`), though its comment says "1:50 m".
  - So `DO2` goes from 1:50 mm (`4000`, height 125) to 1:100 ft-in
    (`13'-1 1/2"`, 250), and undo restores `4000` and 125. Its no-page
    clause reads `4.00` (1:50 m, `PageComponent()`'s defaults).

  **Cost:** none.
- **Ruling 11-12 — `DD2`'s non-finite values from a file.**
  **(spec amended)**
  - **This plan's run** (`dart run` of a scratch file,
    `plan11-probe/plan11-json.dart`):
    - `jsonDecode('{"x": 1e999, "y": -1e999}')` gives `Infinity
      -Infinity`;
    - `jsonDecode('{"x": NaN}')` throws `FormatException`;
    - `jsonEncode({'x': double.infinity})` throws
      `JsonUnsupportedObjectError`.
  - So a file can carry an **infinite** coordinate or offset (`1e999`),
    and it can never carry a NaN.
  - **The rule:** `DD2`'s file cases use `1e999` and `-1e999`. Its NaN
    point and NaN offset go through a `SetComponentCommand`, as 10's
    `DG` tests set NaN labels (`room_diagnostics_test.dart:115-118`).
  - A loaded document holding an infinite value cannot be saved again by
    the codec (`json_codec.dart:86`, `jsonEncode`). That holds for every
    component, not dimensions alone. `DD2` does not save it; the
    results note records it as found.

  **Cost:** none.
- **Ruling 11-13 — the sample plan is measured, then pinned** (10-20's
  precedent).
  - Task 14's first step builds D17's plan and runs a printing probe,
    never committed.
  - The spec's figures are **expectations, not truths**:
    - 611 entities;
    - the five dimensions' ends, kinds and offsets;
    - the values in every unit;
    - the text heights and the references;
    - empty `drift()` and `diagnostics()`.
  - A measured difference is **investigated and reported to the
    controller before any literal is pinned**.

  **Cost:** none.
- **Ruling 11-14 — the shell's and the sample plan's existing tests**
  (10-22's precedent). The sample plan gains 30 entities and five
  dimensions drawn over the rooms. Some existing tests could change their
  answer:
  - a 07, 08 or 10 test in `planner_shell_test.dart`,
    `planner_draw_test.dart`, `room_paint_test.dart` or
    `opening_paint_test.dart` (a pick, a count, a pixel);
  - `planner_draw_test.dart`'s `A1` failing to reach the new palette
    entry.

  The implementer reports it with the failing line, and the controller
  rules on the fix. Nothing is edited to make it pass before that.

  **Cost:** none.
- **Ruling 11-15 — pixel tests capture at the view's device pixel ratio.**
  This is R-31, with 10-28's rules.
  - **Every capture is matched.** Either:
    - set `tester.view.devicePixelRatio = 1.0` and capture with
      `toImage(pixelRatio: 1.0)` (D7's set-up 2); or
    - keep ratio 3 and capture with `toImage(pixelRatio: 3.0)` (set-up
      3).
  - **Never copy 10's `room_paint_test.dart` capture.** It is
    `boundary.toImage()` at ratio 1 under the test view's ratio 3, D7's
    set-up 1, whose drop-outs are the capture's own.
  - The camera is framed with a fractional translation (10-28), and each
    sample takes the brightest (or darkest) of a 3×3 neighbourhood.
  - `RR2` records set-up 1 as the caveat D7 names.

  **Cost:** none.
- **Ruling 11-16 — M-11b-cam's site.** `DraftPainter._drawText`
  (`packages/jet_cad_2d_flutter/lib/src/draft_painter.dart:919`):
  - **The edit:** compose into the text's residual a uniform scale
    about its insertion point. Choose the scale so that the on-screen cap
    height no longer depends on the camera's scale: it is fixed at its
    0.15 px/mm size at every zoom (the roadmap's "text scaled with the
    camera").
  - **First,** the implementer confirms that the app's view reaches
    `_drawText` (`planner_view.dart`'s painter and sink) and names the
    line.
  - **Fired** with a `cp` backup, run against `RR1`, restored with `cp`,
    then `diff` exit 0 and `git diff --quiet --
    packages/jet_cad_2d_flutter` exit 0.

  **Cost:** none.
- **Ruling 11-17 — the Linux container** (10-25's precedent).
  - This plan runs in a Linux x86_64 container. `flutter build macos
    --release`, the gate lines on macOS and the look (gate 16) are **the
    human's, recorded as owed**.
  - **Standing Linux failures, and only these:**
    - the engine's two hash tests in
      `test/testing/generate_document_test.dart`;
    - the render layer's five `text_ladder` rungs (1–5) and two
      Linux-only `text_lod_ladder` rungs (1–2), plus its one skip.

    No task fixes them or counts them. Any other failure is real.
  - The engine and render gate lines use `;` after the test command:
    - the standing failures make the test command exit 1;
    - `analyze` and `format` must still run;
    - the summary line and the failing tests' names are read and pasted.

  **Cost:** a real `text_lod` regression could hide here; the human's
  macOS gate still checks it.
- **Ruling 11-18 — carried items, multi-site mutants, the log, scratch
  files** (10-26, and 10's Task 19 audit).
  - **Carried items.** A reviewer's minor deferred to a later task is
    copied **verbatim** into that task's brief by the controller. The
    task's report names each one and its disposition.
  - **Multi-site and multi-form mutants** are fired at each site, in each
    form, and the log names each:
    - M-11negzero: two forms, `==` on the offset, and `toJson` writing
      `offset.abs()`;
    - M-11colour: the lines' colour and the text's colour;
    - M-11fallback: both steps of `drawnCapsOf` removed together;
    - M-11closure and M-11text: in the frozen engine;
    - M-11b-cam and M-11runtime: in the frozen render layer.

    Before declaring any other mutant single-site, grep for a second copy
    of its rule.
  - **The log's words:**
    - "equivalent" needs a reason **and** a probe run pasted beside it;
    - a survivor that costs only time is "accepted (cost)", not
      "equivalent";
    - a reviewer's edit not kept is "N/A".

    10's audit reclassified three "equivalents" as killable (`progress.md`
    Task 19).
  - **Scratch files** go under the scratchpad's `plan11/` directory,
    each named with a prefix unique to its author: `t6-` for Task 6's
    implementer, `rv6-` for its reviewer, `fr-` for a final-review fix.
    10's ledger records a shared script overwritten by another agent
    mid-round.

  **Cost:** none.
- **Ruling 11-19 — a finding beyond the spec.** 10 added Tasks 14b and 14c
  in flight. Its reviewers found product defects outside the diff by
  fuzzing: a doubled edge, and a slit's return edge. So:
  - **What the finder does:** an implementer or reviewer who finds a
    product defect the spec does not cover reports it with a reproduction
    and stops that line of work. Nobody fixes it silently.
  - **When it changes product behaviour** beyond the spec, it goes to the
    human before any code (10's decision 29).
  - **A task added in flight** is lettered (for example Task 8b). Its
    brief is the controller's, it amends the spec itself, and it owns
    `X<N>b-` mutants.
  - **What is not a finding:** D18's known limits, which are recorded,
    accepted and not re-raised:
    - collisions;
    - the side change of near-vertical text;
    - extension lines on faces;
    - no along-face or crossing points;
    - drafted geometry not followed;
    - the between band;
    - which wall a corner is stored on;
    - the regeneration fan-out;
    - the half-up tolerance both ways;
    - 07's wide node cluster;
    - mirrored groups.

  **Cost:** none.
- **Ruling 11-20 — the packages are frozen after Task 1.**
  - From Task 2 on, `git diff --stat <Task 1's last commit> -- packages/`
    is empty at every commit.
  - Mutants are the one exception. These are fired with a `cp` backup
    and restored, then checked with `diff` and `git diff --quiet`:
    - the engine's M-11text (Task 7) and M-11closure (Task 8);
    - the render layer's M-11runtime (Task 11, Ruling 11-25), M-11b-cam
      (Task 15) and Task 15's `X15-bandIgnoresFlag`.
  - A needed engine or render change is a finding, reported before it is
    made.

  **Cost:** none.
- **Ruling 11-21 — the hover's cost is measured before review.**
  - 10's Room tool re-traced on every exterior hover: 9.9 ms per move at
    600 walls. Its reviewer found it, and a fix round followed (10's
    Task 15).
  - So the Task 10 implementer runs `TL8` and reads its printed time
    **before** handing the task to review.
  - Over D12's budget of 1 ms per move, they report the figure and where
    the time goes, and the controller rules. The budget is printed, not
    asserted.
  - `TL8` asserts the counters:
    - one attach search per distinct resolved point;
    - no line-test pass inside a band;
    - exactly two fresh searches at a commit, one per end.

  **Cost:** none.
- **Ruling 11-22 — `TL8`'s and `AM5`'s 600 walls.**
  - `gridWalls(rows, cols)` (`room_cost_test.dart:26`) is **copied** into
    `dimension_fixture.dart` as `dimGridWalls`, with a comment naming its
    source. A test file is never imported from another (10's Task 14
    m-r1).
  - `TL8` adds one 900 mm door on the wall its hover path crosses.

  **Cost:** a few duplicated lines.
- **Ruling 11-23 — `AM4`'s and `TL6`'s grid.**
  - **The page:** `gridStepMm: 500` and `snapToGrid: true`, with its
    origin at the corner's **world** point. So the corner is a grid node
    at every placement, turned or not (the grid is laid from the page's
    origin, `snapToGrid(point, step, page)`).
  - **The camera:** 0.052 px/mm, so the 10 px aperture is 10 / 0.052 =
    192.3 mm.
  - **The raw pointer:** (−170, −170) mm from the corner, outside the
    plan, measured in the placement's frame (the placement's rotation
    applied, so the offset follows a turned plan). It is 240.4 mm away,
    beyond the aperture, and rounds to the corner on the 500 mm grid.
  - **Premises asserted:**
    - `resolveDragPoint` gives `objectKind` null and `grid` true;
    - its point equals the corner **exactly**;
    - no snap point of the plan lies within the aperture of the raw
      point (`snapInto` there finds nothing).
  - **At a turned placement** the premises are re-asserted: turned 23°,
    the offset is about (−90, −223) mm in world, still within 250 mm of
    the corner on both axes.

  **Cost:** none.
- **Ruling 11-24 — `SP8`'s click.**
  - `startup_plan_test.dart` has no shell. `SP8`'s "a click on each
    dimension's line selects it" is `SpatialIndex.pickInto` with
    `QueryFilter.picking()`, at a quarter of the way along each
    dimension line, with the select tool's pick radius. It asserts that
    the root-level group owning the hit is that dimension.
  - `SL1` makes the same click through the real select tool.

  **Cost:** none.
- **Ruling 11-25 — M-11runtime's site is the render layer.**
  **(spec amended)**
  - **Why there is no app site:** "the grips hit without `components`
    and `geometry`" cannot be written in `DimensionGrips`. The only gates
    are the render layer's:
    - `GripCache.hitTest` returns −1 for every grip while
      `leafGripsLive` (`grip_cache.dart:273-274`, `geometry` allowed) is
      false;
    - `GripDrag` checks an object grip's `components` and `geometry`
      (`grip_drag.dart:209-222`);
    - `DraftPermissions.runtime` allows `components` and denies
      `geometry` (`command.dart:57-58`).
  - **The site:** `leafGripsLive` returns true. It is fired with a `cp`
    backup in `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`,
    run against `GE4`, and restored, as M-11b-cam is (Ruling 11-20).
  - **What `GE4` needs:** a real `GripCache` and its `hitTest`, so the
    gate is on the path.

  **Cost:** none.

## Global constraints

- **Never push.** The human authorises every push, branch by branch.
- **Never commit `analysis_options.yaml`.**
  - `flutter pub get` rewrites three of them.
  - Run `git status --short` before every commit, and **stage only your
    own files, by path**. Never `git add -A` or `git add .`.
  - Restore a dirtied `analysis_options.yaml` with `git checkout --` on
    the yaml only.
- **Never synthesize output.**
  - Paste what ran: the summary line and the exit code.
  - A reviewer re-runs what you claim, and a fabricated transcript
    invalidates the task.
  - Quote numbers only from the spec, the spike note, the reviews, or a
    run you made.
- **Mutants.**
  1. `cp` the file to a backup under the scratchpad's `plan11/`
     directory, with your prefix.
  2. Mutate, and run the named tests.
  3. `cp` the backup back.
  4. `diff` the backup against the file (exit 0).
  5. `git diff --quiet -- <file>` (exit 0).

  **Never `git checkout --` a `.dart` file.** Take one backup per file per
  mutant: 08's Task 7 took a second backup of an already-mutated file and
  had to discard its runs.
- **`CI=true` on every command** of a gate line and of a mutant run.
  Flutter and Dart are at `/root/flutter/bin` (`export
  PATH=/root/flutter/bin:$PATH`).
- **A unique scratch prefix per agent** (Ruling 11-18). Scratch files live
  under
  `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/plan11/`.
  Never overwrite another agent's file there.
- **Pure Dart.**
  - Nothing under `packages/jet_cad_2d` imports Flutter or `dart:ui`.
  - Nor do these app files, **transitively** (Ruling 11-2):
    - `dimension_geometry.dart` and `dimension_attach.dart`;
    - `wall_geometry.dart` and `opening_geometry.dart`;
    - `room_trace.dart`, `room_label.dart` and `room_inputs.dart`.
- **The frame path allocates nothing per entity in steady state, and O(1)
  per flush.**
  - `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` and
    `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`
    stay green **and unedited**.
  - The engine's new filter test is one bool when `rendering()` asks
    (D19).
  - These run on edits, pointer moves and selection changes, never per
    frame:
    - attach searches;
    - layouts;
    - previews and rings;
    - the panel's value lookup.
  - The preview and the rings are painted from cached geometry.
- **Draw order is ascending handle value,** stable across undo, save, load
  and purge.
  - A dimension's six children are reserved in generation order: line <
    extension a < extension b < slash a < slash b < text.
  - They keep their handles for its life, a zero dimension included
    (R-9).
- **Geometric decisions use `Tolerance`** (`dimAttach`, `dimFormat`,
  `wallJoin`). **Stored values are compared with exact `==`**:
  - the ends, the kind, the page, a TEXT's string;
  - the offset, by `compareTo(other) == 0` (D2).

  No `Tolerance.standard` in any dimension file.
- **World is root space.** Never read or write the root's transform.
- **English** in code, comments and commits. **Every commit ends with both
  lines, exactly:**

  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
  ```
- **The packages are frozen except D19's files.**
  - **Task 1** changes, in `packages/jet_cad_2d`:
    - `lib/src/document/style.dart`;
    - `lib/src/index/query_filter.dart`;
    - `lib/src/index/spatial_index.dart`;
    - `lib/src/parametric/parametric_system.dart` (a comment only);
    - the test files Ruling 11-1 names.
  - **Nothing else, ever**, in `packages/jet_cad_2d` or
    `packages/jet_cad_2d_flutter` (Ruling 11-20).
- **`dart format`** every file you touch before the gate. In the app,
  `unused_import` is a warning, and `flutter analyze` still fails on it
  (08's Task 3 finding).
- **Fixtures are off the identity.** The spec's Testing section, restated.
  - **The placements** (`room_fixture.dart:69-89`, re-exported by
    `dimension_fixture.dart`):
    1. the origin;
    2. the corpus far origin (4,500,000, 1,200,000) turned 23°;
    3. the same with **every wall in its own rotated, translated group**
       (`corpusGroups`);
    4. +1e9 mm on both axes turned 23°;
    5. the same unturned;
    6. the same turned, in own groups (`km1000Groups`).

    Plus `corpusAxis`, for Ruling 11-9 only.
  - **Which placements each test takes:**
    - **all six:** `AP1`, `AP3`, `AM6`, `DL1`, `DF3`, `DR1`;
    - **origin, corpusGroups and km1000Groups:** `AM1`, `DN1`;
    - **at least origin and corpusGroups:** every other relational test;
    - **the sample plan's own placement** (off-origin, not symmetric):
      `SP*`, `SL1`, `TL9` and the renders.
  - **The dimension's own group is placed as well:** at the placement
    (`place.m`), and, in `DR*`, `GE1`, `PN3`, `AM3` and `DL4`, turned
    further. So a hand value in the group's local frame holds at every
    placement.
  - **The feature's degenerate fixture:** a horizontal dimension along a
    free, centre-justified wall at the origin, centre to centre, in a
    group at the identity. It may appear only as a recorded control
    (Task 16), never as the test that kills a mutant.
  - **The other required properties,** each carried by at least one
    relational test:
    - a non-axis pair, (0, 0)–(3000, 1200) (`DL1`, `DR1`, `GE5`), and the
      sample's diagonal (`SP8`);
    - every joint kind C1–C11 (`AP1`, `AP2`);
    - `k = 1` and both face sides in every relational test's ends;
    - left- and right-justified walls, and mixed thicknesses from 60 to
      400 (`AP1`'s C4, `AM3`);
    - a ft-in page at 1:100 (`DL3`, `DO2`, `SP9`);
    - a negative offset and a `-0.0` offset (`DL2`, `DP1`, `DO3`);
    - F3 off (`AM4`, `TL6`, `GE3`);
    - openings in the measured walls (`AM1`, `AM6`, `SP*`);
    - a rotated dimension group (30°, 37°), and one rotated, translated
      and **scaled** group (`DR5`, file only).
- **Oracles, not counts alone.**
  - Expected values are **hand arithmetic written in the test**, next to
    the assertion, never read from the code under test (the roadmap's
    M-11a trap).
  - The all-walls oracle is `DZ1`'s differential check of the closure.
  - `drift()` is empty after every edit of every relational test (D5's
    argument, checked).
- **Stored values under test are fractional** where a stored value is
  written: a fixed end's coordinates, an offset. 08's Task 7 found that
  all-integer values let a rounding mutant survive a round trip. The
  spec's own figures (`DL3`'s 600, `TL2`'s clicks) are kept where the
  spec gives them.
- **Premises are asserted.** A fixture that relies on a geometric fact
  asserts that fact first, so it cannot silently become degenerate:
  - C9's step-1 fallback;
  - C11's local-only fallback;
  - `AM6`'s unstored points;
  - `AM4`'s grid resolution;
  - `TL9`'s `rendering()` snap;
  - a click with no object in the aperture.

  **An aperture is 10 px ÷ the camera's px/mm, stated in the test**
  (10's `TT5` put "30 px" outside a 10 px aperture).
- **A named test that cannot kill its named mutant is a finding.** Report
  it; fix the fixture, never the mutant; re-fire.
- **A plan number found wrong** (a coordinate, an aperture, a count) is
  reported in the task's "plan wrong" list and corrected in the test with
  its arithmetic. It is never adjusted silently. 10's ledger records such
  corrections in Tasks 2, 3, 4, 5, 7, 11, 15 and 16.
- **Carried items** (Ruling 11-18): every deferred minor reaches the task
  it was deferred to.
- **Every task ends green.** The gate lines, run from the repository root
  in the Linux container:

  ```sh
  export PATH=/root/flutter/bin:$PATH
  (cd packages/jet_cad_2d         && CI=true dart test ; CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .)
  (cd packages/jet_cad_2d_flutter && CI=true flutter test ; CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
  (cd apps/dev_harness_2d         && CI=true flutter test --concurrency=1 && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
  (cd apps/floor_planner          && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed . && CI=true flutter build web --release)
  ```

  Call them **[engine]**, **[render]**, **[harness]** and **[app]**. Each
  task's "Ends green" block writes out the lines it runs.
  - **Standing failures:** only those of Ruling 11-17, engine `-2` and
    render `~1 -7`. Anything else is real.
  - **Every task** runs [engine], [render] and [app]: CLAUDE.md's two
    lines plus the floor planner's.
  - **Tasks 1, 16 and 17** also run [harness]: the snap default reaches
    every tool.
  - **Tasks 2–17** also show `git diff --stat <Task 1's last commit> --
    packages/` empty (Ruling 11-20).

## Review Focus

Inputs a person will hit that no exit criterion names. Each has a test.

1. **Pressing I, clicking a wall corner, then the same corner again:** the
   second click is ignored and the tool waits for the second point. It is
   also ignored 5 µm away from the first. Task 9, `TL4`.
2. **Holding Shift at the second click, then releasing it before the
   third:**
   - at the second click Shift is ortho;
   - at the third, released, the dimension is aligned;
   - pressing Shift again with no pointer move turns the preview linear.

   Tasks 9 and 10, `TL2`, `TL5`.
3. **Sliding a door flush against a T and dimensioning to the stem's
   corner the door's jamb snaps to:** the end attaches. Tasks 4 and 9,
   `AM6`, `TL6`.
4. **Deleting a wall that carries three dimensions, then cmd+Z:** the
   three go in one step and come back with their handles and texts. Tasks
   8 and 15, `DN3`, `SL1`.
5. **Switching the page to ft-in at 1:100:**
   - every dimension reads ft-in and its text doubles, in one undo step;
   - switching the paper to Blueprint regenerates nothing and the ink
     turns light.

   Tasks 7, 14 and 15, `DO2`, `SP9`, `RR3`.
6. **Rotating one horizontal dimension alone with the rotation grip:** its
   value changes and the panel says "Axes turned 30.0°". Rotating it
   together with its walls changes nothing. Tasks 12, 13 and 15, `PN3`,
   `DR3`, `DR4`, `SL1`.
7. **Clicking a wall face exactly under an extension line:** the wall is
   selected. Hovering at the extension line's end with the Line tool
   snaps to nothing there. Task 15, `SL1`, `TL9`.
8. **Typing I into the room's Name field:** the letter types and no tool
   switches. Task 9, `TL7`.
9. **Pressing Enter with two points placed:** nothing happens. Esc drops
   the points; Esc again returns to Select. Task 9, `TL4`.

---

## File structure

| file | responsibility | task |
|---|---|---|
| `packages/jet_cad_2d/lib/src/document/style.dart` | **modify**: `EntityFlags.unpickable = 1 << 1` | 1 |
| `packages/jet_cad_2d/lib/src/index/query_filter.dart` | **modify**: `excludeUnpickable`, `QueryFilter.snapping()`, `isPassthrough`, the test in `acceptsEntity`, the class comment's four callers | 1 |
| `packages/jet_cad_2d/lib/src/index/spatial_index.dart` | **modify**: `snapInto`'s default filter and its doc comment | 1 |
| `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart` | **modify**: `Generated`'s class comment only (196-204) | 1 |
| `packages/jet_cad_2d/lib/jet_cad_2d.dart` | **unchanged**: it exports `style.dart`, `query_filter.dart` and `spatial_index.dart` whole (lines 30, 55, 58) | — |
| `packages/jet_cad_2d/test/index/query_filter_test.dart` | **modify**: the presets test becomes four; `QF1` | 1 |
| `packages/jet_cad_2d/test/index/snap_test.dart` | **modify**: `QF2` | 1 |
| `packages/jet_cad_2d/test/codec/json_codec_test.dart` | **modify**: `QF3` | 1 |
| `packages/jet_cad_2d/test/parametric/attributes_test.dart` | **modify**: `QF4` | 1 |
| `packages/jet_cad_2d/test/parametric/support/clients.dart` | **modify**: `Whisker`, registered in `testCatalog()` | 1 |
| `packages/jet_cad_2d/test/index/snap_centre_index_test.dart` | **modify**: the reason string at 521-525 only | 1 |
| `apps/floor_planner/lib/parametric/wall_geometry.dart` | **modify**: `drawnCapsOf` (new function; nothing existing edited) | 2 |
| `apps/floor_planner/lib/parametric/dimension_geometry.dart` | **create**, pure Dart (Ruling 11-2): `WallSide`, `dimAttach`, `dimFormat`, `wallEndPoint(s)` (2); `DimKind`, `DimEnd`/`AttachedEnd`/`FixedEnd` with `==`, `measuringDirection` (3); `roundHalfUp`, `formatDimension` (5); the ends' JSON, the paper constants, `kDimLineweight`, `kDimTextAttrs`, `offsetFor`, `readable`, `DimLayout`, `layoutDimension` (6) | 2, 3, 5, 6 |
| `apps/floor_planner/lib/parametric/dimension_attach.dart` | **create**, pure Dart: `decideEnd` (3); `attachCandidates`, `thickestWall`, the line test, `debugLineTestPasses` (4) | 3, 4 |
| `apps/floor_planner/lib/parametric/dimension.dart` | **create**: `DimensionParams`, `DimensionType` (reach, references, page key, generate), `debugDimensionGenerates`, the export (6); `diagnose` (7) | 6, 7 |
| `apps/floor_planner/lib/parametric/catalog.dart` | **modify**: register `DimensionParams` | 6 |
| `apps/floor_planner/lib/parametric/dimension_tool.dart` | **create**: `DimensionTool` — clicks, Shift, kind, offset, commit (9); preview, rings, notice, memo, `debugAttachSearches` (10) | 9, 10 |
| `apps/floor_planner/lib/parametric/dimension_grips.dart` | **create**: `DimensionGrips` | 11 |
| `apps/floor_planner/lib/parametric/object_grips.dart` | **modify**: the `DimensionParams` arm; an optional `SpatialIndex? index` | 11 |
| `apps/floor_planner/lib/selection_panel.dart` | **modify**: the Dimension section | 12 |
| `apps/floor_planner/lib/main.dart` | **modify**: the tool, its palette entry after S and its key I (9); the notice in the status line (10); the grips' index (11) | 9, 10, 11 |
| `apps/floor_planner/lib/shortcut_guard.dart` | **modify**: I in `kShellLetterKeys` | 9 |
| `apps/floor_planner/lib/startup_plan.dart` | **modify**: D17's five dimensions | 14 |
| `apps/floor_planner/test/support/dimension_fixture.dart` | **create** over `room_fixture.dart`: `groupFor`, `worldWalls`, `othersOf`, `corpusAxis`, the C1–C11 walls (2); `bruteCandidates` (3); the flush-door fixtures (4); `addDimension`, `fixedAt`, `dimText`, `dimLines`, `dimTextGeometry`, `mmPage` (6); `oracleEnd`, `oracleFailures` (8); `dimGridWalls` (10) | 2–10 |
| `apps/floor_planner/test/dimension_attach_points_test.dart` | **create**: `AP1`–`AP3` | 2 |
| `apps/floor_planner/test/dimension_attach_test.dart` | **create**: `AM3` (3); `AM1`, `AM2`, `AM4`–`AM6` (4) | 3, 4 |
| `apps/floor_planner/test/dimension_format_test.dart` | **create**: `DF1`, `DF2` (5); `DF3` (7) | 5, 7 |
| `apps/floor_planner/test/dimension_params_test.dart` | **create**: `DP1` | 6 |
| `apps/floor_planner/test/dimension_layout_test.dart` | **create**: `DL1`–`DL4` (6); `DL5` (7) | 6, 7 |
| `apps/floor_planner/test/dimension_object_test.dart` | **create**: `DO1`–`DO5`, `DD1`, `DD2` | 7 |
| `apps/floor_planner/test/dimension_follow_test.dart` | **create**: `DN1`–`DN4` | 8 |
| `apps/floor_planner/test/dimension_fuzz_test.dart` | **create**: `DZ1` | 8 |
| `apps/floor_planner/test/dimension_tool_test.dart` | **create**: `TL1`–`TL4`, `TL6`, `TL7` (9); `TL5`, `TL8` (10) | 9, 10 |
| `apps/floor_planner/test/dimension_grips_test.dart` | **create**: `GE1`–`GE5` | 11 |
| `apps/floor_planner/test/dimension_panel_test.dart` | **create**: `PN1`–`PN5` | 12 |
| `apps/floor_planner/test/dimension_rotate_test.dart` | **create**: `DR1`–`DR5` | 13 |
| `apps/floor_planner/test/startup_plan_test.dart` | **modify**: `SP1`'s count, `SP5` extended, `SP8`, `SP9` new | 14 |
| `apps/floor_planner/test/dimension_shell_test.dart` | **create** (Ruling 11-1): `SL1`, `TL9` | 15 |
| `apps/floor_planner/test/dimension_paint_test.dart` | **create**: `RR1`–`RR3` | 15 |
| `docs/superpowers/notes/plan-11-mutation-log.md` | **create** | 16 |
| `docs/superpowers/notes/2026-09-28-plan-11-results.md` | **create** | 17 |
| the spec, this plan, `roadmap/11-dimensions.md`, `roadmap/12-app-shell.md`, `roadmap/13-export-and-print.md`, `roadmap/00-README.md`, `STATUS.md` | **modify** | 17 |

**Seams, read from the tree at `1fca97a`.** Line numbers drift as tasks
land; the names do not.

- **Engine:**
  - `EntityFlags` (`document/style.dart:129-132`, `invisible` at 131);
  - `QueryFilter` (`index/query_filter.dart:13-36`), its presets (17-29)
    and `isPassthrough` (35);
  - `FilterEvaluator.acceptsEntity` (69-84; the `invisible` read at 76);
  - `snapInto`'s doc comment and signature
    (`index/spatial_index.dart:1446-1467`);
  - `_considerIntersections` (1530);
  - `resolveDragPoint` (`index/drag_snap.dart:39`), `DragPoint` (17),
    `kSnapAperturePixels` (14), `dragGridStepMm` (98);
  - `CommandDispatcher.onAfterMutate` (`document/undo.dart:56-78`);
  - `Generated`'s class comment (`parametric/parametric_system.dart:196-204`);
  - the flags column (`store/entity_store.dart:265`), written at 419 and
    in JSON at 145 and 173;
  - `testCatalog()` (`test/parametric/support/clients.dart:1242`),
    `Swatch` (640);
  - the presets test (`test/index/query_filter_test.dart:59`);
  - the reason string (`test/index/snap_centre_index_test.dart:521-525`).
- **The regeneration** (mutant sites only, frozen):
  - `_closure` (`parametric/regeneration.dart:385-401`) for M-11closure;
  - the TEXT match in `_plan` (10's M-10f site) for M-11text.
- **Render layer** (read-only; the M-11b-cam site):
  - `PlacementTool` (`draw/placement_tool.dart:34`): `orthoBase` (84),
    `_resolve` (105), `onPointerMove` (131), `onPointerDown` (141),
    `onKey` (170), `commit` (229), `hoverKind`, `markerPoint`;
  - `DraftPainter._drawText` (`draft_painter.dart:919`);
  - `ObjectGripProvider` (`grip_cache.dart:29-51`), `GripCache.rotatable`
    (254), `isMovable` (263);
  - `GripDrag` calling `provider.drag` (`grip_drag.dart:286`);
  - the select tool's `_pick` (`select_tool.dart:107-109`), its bands
    (452-453, 474) and `_everyLeafIn` (498);
  - the stroke width rule (`vertices_draw_sink.dart:559-566`).
- **App:**
  - `wallJoin` (`wall.dart:19`);
  - `capsOf` (`wall_geometry.dart:491-506`), `localOutlineOf` (468-485),
    `isSimpleCcw`, `simplifyRing`;
  - `wallsInView` (`opening_geometry.dart:603-615`), `openingsInView`
    (646-652), `_isLiveGroup` (700), `wallsInDocument` (716-732);
  - `ObjectGrips` (`object_grips.dart:30`, `_of` 61);
  - `kShellLetterKeys` (`shortcut_guard.dart:5-21`);
  - `main.dart`:
    - `_index` (64), the tools (103-136), `_entries` (137; S at 209);
    - `GripCache` and `ObjectGrips` (257-266);
    - `_status` (277-279), `_statusLine` (321-326);
  - the Wall section's `SegmentedButton` (`selection_panel.dart:676`), the
    Room section (733-739);
  - `startup_plan.dart`:
    - the walls (74-90), the basin's `circleRegion` (168), the column
      (177);
    - the page (189-195), the rooms (196-202), `system.dispose()` (207);
  - `room_fixture.dart`:
    - the placements (69-89), `buildPlan` (118);
    - `sampleWalls` (360), `sampleOpenings` (378), `samplePlan` (417);
    - `attachPage` (553), `pageOf` (615), `deleteObject` (663);
  - `gridWalls` (`room_cost_test.dart:26`);
  - 07's `WR13` and its sweep (`wall_regen_test.dart:688`, 735);
  - `SP1`'s 581 (`startup_plan_test.dart:147`), `SP5` (379).

---
### Task 1: Engine — a not-pickable entity flag (spec D19; decisions 24, 25)

**Spec:** D19 (R-36, R-37), D1's engine bullet, D7's flags line, gate 13;
the Revision 3 and 4 tables (S-16's wording).
**Files:**
- `packages/jet_cad_2d/lib/src/`:
  - `document/style.dart`;
  - `index/query_filter.dart`;
  - `index/spatial_index.dart`;
  - `parametric/parametric_system.dart` (a comment only);
- `packages/jet_cad_2d/test/`:
  - `index/query_filter_test.dart`;
  - `index/snap_test.dart`;
  - `codec/json_codec_test.dart`;
  - `parametric/attributes_test.dart`;
  - `parametric/support/clients.dart`;
  - `index/snap_centre_index_test.dart` (the reason string only).

**Port from:** nothing. The spike changed no engine code
(`git diff f81c585 383dc57 --stat -- packages` is empty). 10's spike had a
different `unpickable` mechanism, which is not ported.

- [ ] **Step 1 — the bit.** In `EntityFlags` (`style.dart:129-132`),
  beside `invisible`: `static const int unpickable = 1 << 1;`. Its doc
  comment says:
  - drawn, but never picked, band-selected or snapped to (spec 11 D19);
  - not a DXF code, so a DXF export strips it (roadmap 13);
  - bit 0 is `invisible`, and the column is a `Uint8List`
    (`entity_store.dart:265`).
- [ ] **Step 2 — the filter** (`query_filter.dart`).
  - The constructor gains a named parameter:
    `const QueryFilter({required this.visibleOnly, required
    this.excludeLocked, this.excludeUnpickable = false})`. Existing
    callers compile unchanged.
  - `all()` and `rendering()` set `excludeUnpickable` false, and
    `picking()` sets it true.
  - **A new preset:** `const QueryFilter.snapping()` has `visibleOnly`
    true, `excludeLocked` false and `excludeUnpickable` true.
  - `isPassthrough` is `!visibleOnly && !excludeLocked &&
    !excludeUnpickable`.
  - The class comment's "three callers" becomes four: select all,
    rendering, picking and snapping.
- [ ] **Step 3 — the test** in `FilterEvaluator.acceptsEntity`.
  - **Where:** after the `isPassthrough` return, and **before** the
    `layerAt` read:

    ```dart
    if (filter.excludeUnpickable &&
        document.entities.flagsAt(slot) & EntityFlags.unpickable != 0) {
      return false;
    }
    ```
  - **Its comment** says:
    - it costs one bool test when the filter does not ask (`rendering()`,
      every frame);
    - it costs one column read when the filter asks;
    - it allocates nothing and looks up no map.
  - `acceptsNode` is unchanged: the flag belongs to an entity, not to a
    node.
- [ ] **Step 4 — `snapInto`'s default.**
  - The default becomes `{QueryFilter filter = const
    QueryFilter.snapping()}` (`spatial_index.dart:1463`).
  - **Its doc comment** (1446-1458) is rewritten to say:
    - it defaults to `snapping()`: what `rendering()` accepts, minus
      not-pickable entities;
    - hidden geometry is still refused, for the reason the old comment
      gives;
    - locked geometry still snaps ("how you draw relative to a locked
      reference");
    - a not-pickable entity never snaps (spec 11 D19, R-37).

  The paragraph about `QueryFilter.picking` stays, reworded to the four
  presets.
- [ ] **Step 5 — the parametric layer's comment**
  (`parametric_system.dart:196-204`).
  - **Replace:** "There is no 'unpickable' flag (spec 10 R-10): a fill
    whose boundary is invisible is not picked already."
  - **With:** `EntityFlags.unpickable` exists (spec 11 D19) for a drawn
    line that must not be picked or snapped. A fill whose boundary is
    invisible needs neither it nor anything else to stay out of picks.
    Like every attribute, it is written on add only.
- [ ] **Step 6 — the reason string** (`snap_centre_index_test.dart:521-525`)
  says "snapInto defaults to `QueryFilter.snapping()`, which refuses
  hidden layers as `rendering()` does, matching what `pickInto` already
  did". The test's expectations are unchanged (S-16).
- [ ] **Step 7 — `Whisker`**, a test client in `clients.dart`, registered
  in `testCatalog()`.
  - The name avoids every existing client name in `test/parametric/`.
  - **Parameters:** `(x, y, length)`. **Reach:** its segment's box.
  - **`generate`** makes two LINEs from `(x, y)`. The first, along local
    x, has `flags: EntityFlags.unpickable`. The second, along local y,
    has flags 0.
  - It counts its calls in `generateCalls`, like the others.
  - `editCapability` is `geometry`.
- [ ] **Step 8 — tests.** Every fixture is off the origin at fractional
  coordinates, and the snap and pick fixtures also sit in a group turned
  0.4 rad (`atA`/`onA` in `support/fixture.dart`, as 10's `TX1`).
  - **The presets test** (`query_filter_test.dart:59`) is renamed `'the
    four presets differ in exactly the documented way'`. It checks
    `snapping()`'s three fields and each preset's `excludeUnpickable` and
    `isPassthrough`.
  - `test('QF1 an entity carrying EntityFlags.unpickable passes all() and '
    'rendering() and fails picking() and snapping(); an invisible one '
    'still fails every preset but all(); a filter asking only for the '
    'flag is no passthrough and rejects it', …)`:
    - **The bits first:** `EntityFlags.unpickable == 2` and
      `EntityFlags.unpickable & EntityFlags.invisible == 0`.
    - **The entities:** flags 0, 1, 2 and 3.
    - **On a locked visible layer:** `snapping()` accepts flags 0 and
      rejects flags 2, and `picking()` rejects both.
    - **A custom filter** `QueryFilter(visibleOnly: false, excludeLocked:
      false, excludeUnpickable: true)`:
      - `isPassthrough` is false;
      - it rejects flags 2 and flags 3, and accepts flags 1 (invisible
        but pickable).
  - `test('QF2 snapInto by default gives no endpoint, midpoint or '
    'intersection snap on a not-pickable LINE; a LINE beside it still '
    'snaps; pickInto with picking() skips it for the LINE behind it', …)`:
    - **Endpoint and midpoint.** Two root-level LINEs, a flagged one and a
      plain one 40 mm apart, parallel, with the aperture covering only
      the flagged one:
      - no snap by default;
      - with an explicit `rendering()` filter, the flagged endpoint snaps
        (premise);
      - at the plain one, an endpoint snap.
    - **Intersection.** Two crossing root-level LINEs, one flagged: no
      intersection snap at the crossing by default; `rendering()` finds
      it (premise).
    - **The pick.** The flagged LINE lies on top of a plain one (higher
      handle, the same segment). `pickInto` with `picking()` returns the
      plain one's handle; with `rendering()`, the flagged one (premise).
  - `test('QF3 save, load and save of a document holding not-pickable '
    'entities is byte-identical, and the bits come back', …)`:
    - **The document:** LINEs with flags 2 and 3 (`draftRecord` then
      `copyWith(flags:)`).
    - **After** `encodeToString` → load → `encodeToString`: the strings
      are equal and `flagsAt` returns 2 and 3.
    - **No schema change:** the schema version is still 6
      (`json_codec_test.dart:512`).
  - `test('QF4 a generated child added with EntityFlags.unpickable carries '
    'it, and keeps it across a match', …)` (`attributes_test.dart`):
    - **The setup:** a `Whisker` at `onA(1234.5, -310.25, 0.4)`.
    - **On add:** the first child's flags are 2 and the second's 0.
    - **A `SetComponentCommand<Whisker>`** moving it and changing its
      length:
      - both payloads are rewritten;
      - both flags are unchanged, and the handles are unchanged;
      - `drift()` is empty.
    - **Undo and redo** are exact (`canon`).
- [ ] **Step 9 — mutants.**

  | mutant | edit | must turn red |
  |---|---|---|
  | M-11pickflag | `picking()` sets `excludeUnpickable: false` | `QF1` |
  | M-11snapflag | `snapInto`'s default back to `QueryFilter.rendering()` | `QF2` |
  | M-11flagdraws | `rendering()` sets `excludeUnpickable: true` | `QF1` |

  **Extras:**
  - `X1-passthrough` (`isPassthrough` ignores `excludeUnpickable`) → `QF1`
    (the custom filter);
  - `X1-bit` (`unpickable = 1 << 0`) → `QF1`;
  - `X1-underVisible` (the flag test moved inside `if
    (filter.visibleOnly)`) → `QF1` (the custom filter);
  - `X1-lockedSnap` (`snapping()` sets `excludeLocked: true`) → `QF1` (the
    locked layer), and the existing locked-snap tests if any go red too:
    list them.
- [ ] **Step 10 — the frame path and the diff.** Run the two invariants
  on their own and paste each summary line:

  ```sh
  (cd packages/jet_cad_2d         && CI=true dart test test/invariants/query_allocation_test.dart)
  (cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/paint_allocation_test.dart)
  CI=true git diff 9774a55 -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants | wc -l   # 0
  CI=true git diff 9774a55 --stat -- packages/jet_cad_2d/lib                                                             # the four files only
  CI=true git diff 9774a55 -- packages/jet_cad_2d_flutter | wc -l                                                        # 0
  ```
- [ ] **Step 11 — ends green** (engine, render, harness, app):

  ```sh
  export PATH=/root/flutter/bin:$PATH
  (cd packages/jet_cad_2d         && CI=true dart test ; CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .)
  (cd packages/jet_cad_2d_flutter && CI=true flutter test ; CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
  (cd apps/dev_harness_2d         && CI=true flutter test --concurrency=1 && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
  (cd apps/floor_planner          && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed . && CI=true flutter build web --release)
  ```

  Commit `feat(engine): a not-pickable entity flag, skipped by picking and snapping (11 D19)`.
  **The packages are frozen from this commit** (Ruling 11-20).

### Task 2: The wall attach points (spec D4)

**Spec:** D4 (R-4, R-5; S-2, S-5, S-16), D1's pure-file rule; 07 D2, D6;
Ruling 10-8.
**Files:**
- `wall_geometry.dart` (`drawnCapsOf`);
- `dimension_geometry.dart` (create);
- `test/support/dimension_fixture.dart` (create);
- `test/dimension_attach_points_test.dart` (create).

**Port from:** the spike's `dimension_geometry.dart` (`WallSide`,
`wallEndPoint`, `wallEndPoints`), its `support.dart` (`groupFor`,
`worldWalls`, `othersOf`) and its `corner_test.dart` (the Q1 table and
the worst-error print). The spike reads `capsOf`; this task reads
`drawnCapsOf`.

- [ ] **Step 1 — `drawnCapsOf(WorldWall w, List<WorldWall> others)`** in
  `wall_geometry.dart`, beside `capsOf`. It returns `({List<Vector2>
  endCap, List<Vector2> startCap, bool fellBack})?`, null for a degenerate
  wall. It has two steps (D4):
  1. `capsOf(w, others)`. When `fellBack` is true, return it.
  2. Take `simplifyRing([...endCap, ...startCap])` through
     `w.toWorld.invert()`. When that image is not `isSimpleCcw`:
     - return the caps of `WorldWall(w.handle, w.params,
       Transform2.identity())` among no walls, each point mapped through
       `w.toWorld`;
     - with `fellBack` true.

  **Its doc comment** says:
  - step 2 is exactly `localOutlineOf`'s decision (468-485), so the
    attach point is always the drawn corner, at any similarity (S-5);
  - step 1 stays for the reverse rounding edge (S-2);
  - `localOutlineOf` is not edited, and 07's, 08's and 10's stored
    children stay bit for bit.
- [ ] **Step 2 — `dimension_geometry.dart`**, pure Dart (Ruling 11-2).
  - **Its header** says what it holds and that it imports no Flutter.
  - `enum WallSide { left, centre, right }`, looking from the wall's
    start to its end.
  - **The two tolerances**, declared as `wallJoin` is:
    - `const Tolerance dimAttach = Tolerance(linear: 1e-5, angular:
      1e-9);` (D10);
    - `const Tolerance dimFormat = Tolerance(linear: 1e-6, angular:
      1e-9);` (D8, D9).
  - **`Vector2 wallEndPoint(WorldWall w, List<WorldWall> others, int k,
    WallSide side)`:**
    - centre, or a degenerate wall: `w.endpoint(k)`;
    - otherwise `drawnCapsOf(w, others)!`:
      - left is `startCap.first` at `k = 0` and `endCap.last` at `k = 1`;
      - right is `startCap.last` at `k = 0` and `endCap.first` at `k =
        1`.

    The doc comment gives D4's outgoing-side reason.
  - **`List<(int, WallSide, Vector2)> wallEndPoints(...)`:** all six, in
    `(k, side)` order.
- [ ] **Step 3 — `dimension_fixture.dart`**, which exports
  `room_fixture.dart`. It holds:
  - `groupFor`, `worldWalls` and `othersOf`, ported;
  - `const corpusAxis = Placement('corpus far origin, 0 deg', 4500000,
    1200000, 0);` (Ruling 11-9);
  - the D4 table's walls as named constants (`c1Walls` … `c10Walls`);
  - `c11` (07's `WR13`: A 200 right-justified into the hub, B 200
    left-justified out of it at 178°, both at the identity, turned 133°
    about the hub at the far origin), ported from
    `wall_regen_test.dart:688-730`;
  - a `scaledGroups` variant that wraps a plan's wall groups in a 1.5
    scale (file only).
- [ ] **Step 4 — tests** (`dimension_attach_points_test.dart`).
  - `test('AP1 every wall end point of C1-C10 equals its hand value to '
    '1e-6 mm, k = 1 and both faces included, at $place', …)`, at all six
    placements:
    - **The table:** D4's. The arithmetic is in a comment beside each
      row: a wall's left normal, its face offsets, and the corner as the
      meeting of two face lines.
    - **C4** runs all 3 × 3 justifications of A and B, with the formula
      `(4000 − l_B, l_A)` and `(4000 − r_B, r_A)`.
    - **C9:** A falls back to `(0, ±100)` and `(100, ±100)`; B keeps
      `(0, 100)` and `(200, −100)`; C keeps `(100, 100)` and
      `(−100, −100)`.
    - **C10:** `t = 0`, and length 0; every side is the centreline end.
    - **C7:** the corners on the bisectors at 100 / sin 60° = 115.470.
    - **Worst error:** each placement prints its worst error. The spike
      printed 4.97e-14 mm at the origin and 3.77e-7 mm at +1e9 mm, own
      groups.
    - **Ruled points:** at each L, `A/1/left` equals `B/0/left` bitwise
      (07 computes a wedge corner once).
  - `test('AP2 under 07\'s local-ring fallback the face points are the '
    'stored free rectangle\'s corners, at any similarity; drawnCapsOf '
    'falls back exactly when localOutlineOf does', …)`:
    - **C11's premises:**
      - A's world outline is simple, and its local image is not;
      - the real system reports `wall.fallback` for A;
      - C9's A falls back in step 1 (`capsOf(...).fellBack` is true), so
        M-11fallback's site is reached.
    - **C11's points:** A's four face points equal its stored free
      rectangle's corners (`localOutlineOf(...).ring` mapped through A's
      transform) within `dimAttach.linear`. Each differs from `capsOf`'s
      joined corner by more than 1 mm.
    - **The same at scale 1.5:** C11 with the wall groups scaled 1.5
      (file only). The points are still the stored rectangle's corners
      (S-5).
    - **`fellBack` agreement:** `drawnCapsOf`'s `fellBack` equals
      `localOutlineOf`'s:
      - on every AP1 fixture at six placements;
      - on 07's `WR13` sweep: acute Ls of 2, 3, 4.5 and 5°, the
        justification pairs `(right, left)`, `(left, right)` and `(right,
        right)`, turned 17, 133, 211.5 and 299° (`wall_regen_test.dart:735-743`).
  - `test('AP3 every face point of a wall with no flush opening is a vertex '
    'of its stored ring, in world', …)`, at all six placements:
    - **The fixtures:** AP1's C1–C9 through the real system, walls
      generated.
    - **The check:** each face point lies within the bound of some stored
      ring vertex of that wall, taken to world through the wall's group.
    - **The bound** (Ruling 11-10): 1e-9 mm at the origin and both corpus
      placements, `dimAttach.linear` at the +1e9 mm placements, the worst
      printed.
- [ ] **Step 5 — mutants.**

  | mutant | edit | must turn red |
  |---|---|---|
  | M-11nbrs | `wallEndPoint` reads `drawnCapsOf(w, const [])` | `AP1` |
  | M-11swap | the `k = 1` swap dropped: left always `first`, right always `last` | `AP1` |
  | M-11swapjust | left and right swapped for right-justified walls | `AP1` (C4) |
  | M-11fallback | both steps of `drawnCapsOf` removed: the joined caps always (S-2) | `AP1` (C9: A/0/left (100, 100) for (0, 100)) |
  | M-11centremid | centre = the cap's midpoint | `AP1` (C4, C5, C5c) |
  | M-11localring | step 2 removed: `capsOf` alone | `AP2` |
  | M-11vertex | a face point from its cap's second point | `AP3`, `AP1` |
  | M-11d | `wallEndPoint` ignores `k` (always the start) | `AP1` (every `k = 1` row) |
  | M-11d2 | `wallEndPoint` ignores `side` (always the centreline end) | `AP1` |

  **Extras:**
  - `X2-step1only` (step 1 alone removed). Fire it **expecting green**
    and log it equivalent. Its reason is the spec's (D4, the review's run:
    0 of 258 points differ); paste the green line.
  - `X2-worldFree` (step 2's free caps computed in world, revision 1's
    form) → `AP2` (the scaled variant).
  - `X2-degenerate` (a degenerate wall's faces taken from caps) → `AP1`
    (C10).
- [ ] **Step 6 — ends green** (engine, render, app); packages unchanged
  since Task 1.

  ```sh
  export PATH=/root/flutter/bin:$PATH
  (cd packages/jet_cad_2d         && CI=true dart test ; CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .)
  (cd packages/jet_cad_2d_flutter && CI=true flutter test ; CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
  (cd apps/floor_planner          && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed . && CI=true flutter build web --release)
  CI=true git diff --stat <Task 1's last commit> -- packages/   # empty
  ```

  Commit `feat(app): the six wall attach points, from 07's drawn caps (11 D4)`.

### Task 3: Decision 19's choice of a shared wall end point (spec D10's choice, D6's direction)

**Spec:** D10's "The choice among candidates" and "When it is decided"
(R-17; decisions 19, 22); D6's measuring direction (R-8); decision 17.
**Files:**
- `dimension_geometry.dart`: `DimKind`, the `DimEnd` types (value
  equality only; JSON in Task 6), `measuringDirection`;
- `dimension_attach.dart` (create): `decideEnd`;
- `dimension_fixture.dart`: `bruteCandidates`;
- `test/dimension_attach_test.dart` (create).

**Port from:** the spike's `DimEnd`, `AttachedEnd` and `FixedEnd` (without
JSON), and `attachAt`'s tie-break order for step 4 only. Step 4 is face
before centre, then the lower `k`, then left before right. The spike's
lowest-handle-first order is decision 19's step 3, after the parallel
measure.

- [ ] **Step 1 — the value types** (`dimension_geometry.dart`):
  - `enum DimKind { aligned, horizontal, vertical }`;
  - `sealed class DimEnd`, `final class AttachedEnd(Handle wall, int k,
    WallSide side)` and `final class FixedEnd(double x, double y)`;
  - exact `==` and `hashCode` on each, and a `toString` of the form
    `1A/1/left` or `(x, y)`.
- [ ] **Step 2 — `Vector2 measuringDirection(DimKind kind, Vector2 p0,
  Vector2 p1, Transform2 m)`** (D6):
  - **aligned:** `(p1 − p0) / |p1 − p0|` when `|p1 − p0| >
    wallJoin.linear`; otherwise `m.transformDirection((1, 0))`,
    normalised (R-8);
  - **horizontal:** `m.transformDirection((1, 0))`, normalised;
  - **vertical:** `m.transformDirection((0, 1))`, normalised.
- [ ] **Step 3 — `decideEnd`** (Ruling 11-5), in `dimension_attach.dart`
  (pure; imports `dimension_geometry.dart`, `wall.dart`, `jet_cad_2d` and
  `vector_math` only).
  - It computes `u = measuringDirection(kind, at, other, m)`.
  - **For each candidate's wall W** (a live wall of `doc`):
    - `d_W` is its world direction, start to end;
    - `σ_W = |u.x · d_W.y − u.y · d_W.x|`;
    - a degenerate wall (length ≤ `wallJoin.linear`) takes `σ_W = 1`.
  - **The steps:**
    1. keep `σ_W ≤ min σ + dimAttach.angular`;
    2. then the lowest wall handle;
    3. then face before centre, the lower `k`, left before right.
  - **Its doc comment** says decision 22's timing belongs to the callers:
    - the tool at the commit;
    - an end grip at the drop, for the dropped end;
    - never a kind switch, a wall edit or a move.
- [ ] **Step 4 — `bruteCandidates(DraftDocument doc, Vector2 q)`** in the
  fixture: every live wall's six points among every other live wall,
  within `dimAttach.linear` of `q`, Euclidean, ascending. It is the
  brute-force oracle for Tasks 3 and 4.
- [ ] **Step 5 — tests** (`dimension_attach_test.dart`), at the origin and
  `corpusGroups`. `m` is the placement's own transform (the dimension's
  group at the placement), so "horizontal" runs along A there too and the
  hand values hold (the Global constraints). The candidates come from
  `bruteCandidates`, and each set's contents are asserted as a premise.
  - `test('AM3 a shared corner is stored on the wall the committed kind '
    'runs along, then on the lowest handle, then face before centre, k, '
    'left before right', …)`:
    - **The L.** The **vertical wall B has the lower handle**: it is added
      first, `B (4000,0)→(4000,3000)`, then `A (0,0)→(4000,0)`, both 200.
      - At the inner corner (3900, 100), with `other` = A/0/left (0, 100):
        aligned or horizontal gives **A/1/left**.
      - Vertical, with `other` = (3900, 3000), gives **B/0/left**.
    - **The outer corner** (4100, −100) to (3000, 3000):
      - aligned gives **B/0/right**: `u` = (−1,100, 3,100) / 3,289.4, so
        `σ_B` = 1,100 / 3,289.4 = 0.334 and `σ_A` = 3,100 / 3,289.4 =
        0.942;
      - horizontal gives **A/1/right**: `σ_A` 0, `σ_B` 1.

      This is decision 22's case; the arithmetic is in the comment.
    - **Two collinear walls end to end,** `A (0,0)→(4000,0)` and `C
      (4000,0)→(8000,0)`, 200 each, horizontal: both are parallel, so the
      lower handle wins.
    - **A left-justified free end** (A left-justified, 200): `(k, right)`
      and `(k, centre)` coincide, and **right** is stored.
    - **A degenerate wall** (length 0) at a corner has `σ = 1`: it loses
      to the wall along `u`. Among degenerate walls alone, the lowest
      handle, then `(0, left)`.
- [ ] **Step 6 — mutants.**

  | mutant | edit | must turn red |
  |---|---|---|
  | M-11nearest | the candidate nearest `at` first, ties to the lowest handle (S-10) | `AM3` (the L: the corner is bitwise one point, so the tie goes to B) |
  | M-11parallel | the parallel step skipped: the lowest handle first | `AM3` |
  | M-11lineardir | `u = (other − at)` normalised whatever the kind | `AM3` (the outer corner, horizontal) |
  | M-11centrefirst | centre before face | `AM3` (the left-justified end) |

  **Extras:**
  - `X3-degenerateZero` (a degenerate wall takes `σ = 0`) → `AM3`;
  - `X3-kHigh` (the higher `k` first) → `AM3` (the degenerate wall's six
    coincident points);
  - `X3-exactMin` (the band dropped: `σ == min σ` exactly) → `AM3` at
    `corpusGroups` (the collinear walls' `σ` differ by rounding there).
    If it stays green, log it equivalent with the two `σ` values printed.
- [ ] **Step 7 — ends green** (engine, render, app); packages unchanged
  since Task 1. The same lines as Task 2's Step 6.

  Commit `feat(app): decision 19's choice of a shared wall end point (11 D10, decision 22)`.

### Task 4: The attach candidates (spec D10)

**Spec:** D10's identification and candidates (R-16; decision 23; S-13),
its costs and its "What else a snap can land on".
**Files:**
- `dimension_attach.dart`: `attachCandidates`, `thickestWall`, the line
  test, `debugLineTestPasses`;
- `dimension_fixture.dart`: the flush-door fixtures;
- `test/dimension_attach_test.dart`: `AM1`, `AM2`, `AM4`, `AM5`, `AM6`.

**Port from:** the spike's `attachMatches` (the six points within the
tolerance) and its `snap_test.dart` (`Q3a`'s snap loop, `Q3b`, `Q3d`,
`Q3g`). The spec's flush probe, if still in the scratchpad, shows `AM6`'s
premise (the header's scratchpad references).

- [ ] **Step 1 — `thickestWall(doc)`** (Ruling 11-4): the largest
  `thickness × scaleMagnitude` over live walls, 0 when there is none. One
  pass.
- [ ] **Step 2 — the line test** (D10, Ruling 11-4), for a live wall `W`
  with world start `s`, left normal `n` and offsets `{lOff, 0, rOff}`
  (`WorldWall.offsets`). `W` passes when **any** of these holds:
  - `|(q − s) · n − o| ≤ dimAttach.linear` for some `o`;
  - the wall's group is not rigid, and the same test passes in its local
    frame with `WallParams`' offsets;
  - the wall is degenerate, and `q` lies within `dimAttach.linear` of an
    endpoint.

  It reads `WallParams` and the transform only, no payload, and builds no
  `WorldWall` before it passes. A pass increments the top-level
  `debugLineTestPasses` (Ruling 11-2).
- [ ] **Step 3 — `attachCandidates`** (Ruling 11-4):
  1. `objectSnap` false → `const []`.
  2. `index.forEachInRect(q ± dimAttach.linear, QueryFilter.rendering(),
     …)`: each hit's root-level owner that is a live wall joins the
     candidate walls.
  3. `index.forEachInRect(q ± (dimAttach.linear + thickest), rendering(),
     …)`: each hit's root-level owner that is a live opening adds its
     `OpeningParams.host` when the host is a live wall.
  4. For each candidate wall, ascending by handle, that passes the line
     test: `wallsInDocument(doc, W)`, then its six points. Every `(W, k,
     side)` whose point lies within `dimAttach.linear` of `q`
     (Euclidean) joins the result.

  **Its doc comment** says:
  - why the hosts are gathered (S-13: `_pieces` drops a flush end's
    pieces);
  - why the box is grown by `T` (only the swing face's corner is inside
    a door's own box);
  - that every attach point lies on one of the three lines.
- [ ] **Step 4 — fixtures.** In `dimension_fixture.dart`:
  - **`flushT(place, {c, swing})`:** spike C5, `C (0,0)→(6000,0)` 200
    and `S (2500,0)→(2500,3000)` 100, with a 900 mm door on S at `c`
    (450, which `placeCut` clamps to C's face, or 550), swinging left or
    right;
  - **`flushFree(place, {swing})`:** `A (0,0)→(4000,0)` 200 with the same
    door at `c = 450`.
- [ ] **Step 5 — tests.**
  - `test('AM1 every one of the sample plan\'s 60 wall end points, snapped '
    'through snapInto from 5 mm away, has the brute-force candidate set '
    'and decision 19\'s end, at $place', …)`, at the origin,
    `corpusGroups` and `km1000Groups`:
    - **The fixture:** `samplePlan`, ten walls with the column and
      fifteen openings (S-9).
    - **For each point:**
      1. the raw point lies 5 mm away, along (3, 4) / 5 taken through the
         placement's rotation;
      2. `snapInto(raw, 50, kDragSnapMask, …)`, the spike's aperture;
      3. `attachCandidates` at the snapped point (`objectSnap: true`,
         `thickest: thickestWall(doc)`) equals `bruteCandidates` at that
         point;
      4. `decideEnd` on it, for horizontal and for vertical (`m =
         place.m`), equals decision 19's rule **restated in the test**
         over the brute-force set: a loop, not a call to `decideEnd`.
    - **Printed:** the snap kinds, and the worst `|snapped − computed|`
      (the spike: 4.3e-7 mm at +1e9 mm).
  - `test('AM2 a jamb is fixed, a Y lobe vertex finds both walls\' points, '
    'a T butt corner is the stem\'s, an X crossing gives no snap and no '
    'candidate; a degenerate wall and a scaled wall group are found', …)`,
    at the origin and `corpusGroups`. The candidates are always taken
    through the index, never from the snap's owner:
    - **the front door's jamb** (18000, 8250) on `samplePlan`: empty;
    - **C7's lobe vertex** (−115.470, 0): {B/0/left, C/0/right};
    - **C5's butt corner** (2450, 100): {S/0/left} only;
    - **C6's crossing** (1900, 100):
      - `snapInto` there finds nothing (premise);
      - `attachCandidates` at the raw point is empty;
    - **C10's degenerate wall** (plan-added): its centreline end is a
      candidate, all three sides;
    - **C11 scaled 1.5** (plan-added): A's four face points, the stored
      rectangle's corners, are candidates. That is the local-frame line
      test.
  - `test('AM4 decision 23: a grid point on the sample\'s outer corner '
    'attaches with F3 on and stays fixed with F3 off, at $place', …)`, at
    the origin and `corpusGroups`, on `samplePlan`, with Ruling 11-23's
    page and camera:
    - **The premises** of Ruling 11-23, asserted.
    - **F3 on:** `attachCandidates` at the resolved point is {E1/0/right,
      E4/1/right}, and `decideEnd` horizontal gives **E1/0/right**.
    - **F3 off:** `resolveDragPoint(objectSnap: false)` gives the same
      grid point, and `attachCandidates(objectSnap: false)` is empty.
  - `test('AM5 the attach search per click among 600 walls, printed', …)`:
    - **The fixture:** `dimGridWalls` (Ruling 11-22) at the origin; the
      clicks are at a grid corner.
    - **Printed:** the median of five runs, in µs (JIT).
    - **Asserted:** the candidate set is not empty (premise). The
      duration is not asserted.
  - `test('AM6 a door flush with a wall end leaves none of the end\'s three '
    'points stored, and each still attaches by position, and through the '
    'jamb\'s snap, at $place', …)`, at all six placements, for `flushT`
    at `c` 450 and 550 and both swings, and `flushFree` with both
    swings:
    - **Premise:** none of the end's three points is a vertex of the
      wall's stored children (its ring pieces and centreline pieces).
      This is the review's run.
    - **For each of the three points:** `attachCandidates` equals
      `bruteCandidates` and contains `S/0/side` (or `A/0/side`).
    - **The jamb:**
      - `snapInto` 5 mm off the swing face's jamb corner snaps there, and
        the hit's owner is the door (premise);
      - `attachCandidates` at the snapped point contains the swing face's
        point.
    - Ruling 11-7: `TL6` repeats this through the tool.
- [ ] **Step 6 — mutants.**

  | mutant | edit | must turn red |
  |---|---|---|
  | M-11attachtol | `dimAttach.linear` 1e-9 | `AM1` (+1e9 mm) |
  | M-11snapoff | the `objectSnap` gate removed | `AM4` |
  | M-11prefilter | the line test omits the centreline (S-13) | `AM1` (every centre point), `AM6` (S/0/centre) |
  | M-11openinghost | no opening-host query | `AM6` |
  | M-11hostbox | the host query's box `q ± dimAttach.linear`, not `+ T` | `AM6` (S/0/centre and the far face's corner) |
  | M-11reachcull | candidate walls by `WallType.reach` containing `q`, not by stored boxes | `AM1` (the outer corners lie outside every wall's reach) |
  | M-11ownerring | candidate walls from the owner of `snapInto(q, dimAttach.linear, …)`'s hit only (the spike's (A)) | `AM2` (the Y lobe vertex) |

  **Extras:**
  - `X4-noLocal` (the local-frame test omitted) → `AM2` (scaled C11);
  - `X4-degenerateLine` (a degenerate wall never passes) → `AM2` (C10);
  - `X4-thickestStored` (`T` without the group's scale) → a scaled
    `flushFree` clause in `AM6` if it goes green. Fire it; add the clause
    only if it survives, and report which.
- [ ] **Step 7 — ends green** (engine, render, app); packages unchanged.
  The same lines as Task 2's Step 6.

  Commit `feat(app): attach candidates through the index, with opening hosts and a line test (11 D10)`.

### Task 5: The value's format (spec D9)

**Spec:** D9 (R-13, R-14, R-15, R-32; S-4), decision 7.
**Files:** `dimension_geometry.dart` (`roundHalfUp`, `formatDimension`),
`test/dimension_format_test.dart` (create).
**Port from:** the spike's `roundHalfUp`, `formatDimension` and
`_fraction`, and its `engine_test.dart` (`Q5b`, `Q5c`). The half test
reads `dimFormat.linear`, not `kHalfTolerance`.

- [ ] **Step 1 — `int roundHalfUp(double mm, double quantumMm)`** (R-13):
  - `x = mm / quantumMm`, `n = x.floorToDouble()`;
  - if `|mm − (n + 0.5) · quantumMm| ≤ dimFormat.linear`, the result is
    `n + 1`;
  - otherwise `x.round()`.
- [ ] **Step 2 — `String formatDimension(double mm, DisplayUnit unit)`**
  (D9's table).
  - **The quanta:** mm 1, cm 1, m 10, inches 25.4 / 8 and ft-in 25.4 /
    4.
  - **The text:**
    - cm always has one decimal;
    - m always has two;
    - inches are `W` or `W N/D`, reduced, with no mark;
    - ft-in is `F'-I"` or `F'-I N/D"`, reduced.
  - **Rounding** happens on the total, before it is split.
  - The magnitude is formatted.
- [ ] **Step 3 — tests** (`dimension_format_test.dart`). Every input is in
  millimetres, with its arithmetic in a comment.
  - `test('DF1 every unit at its plan precision, half-up: cm keeps its '
    'trailing zero, fractions are reduced, only feet-inches carries marks, '
    'and a carry reaches the next foot', …)`:
    - **The spike's `Q5b` rows**, among them `3450`, `3451` (3450.5),
      `345.0`, `345.6`, `3.45`, `1.01` (1005), `136 3/8`, `136 1/2`,
      `11'-4 1/4"`, `12'-0"`, `0 1/4` (3/16") and `0'-0 1/2"` (3/8");
    - **the carry:** 143 7/8" (3,654.425 mm) → `12'-0"`, never `11'-12"`;
    - **D17's every-unit table**, all 25 strings, with the spec's hand
      arithmetic in the comments.
  - `test('DF2 half-up is decided within dimFormat.linear of the half: '
    'Q5c\'s rows round up; 3450.5 − 0.9e-6 rounds up and 3450.5 − 2e-6 does '
    'not; the review\'s imperial near-miss prints 9\'-0"', …)`:
    - **`Q5c`'s six rows** through `roundHalfUp`, each also through
      `formatDimension` in its unit. The far-origin row computes its
      length from far-origin doubles, as the spike did.
    - `3450.5 − 0.9e-6` → `3451`; `3450.5 − 2e-6` → `3450` (mm).
    - **The recorded over-rounding (R-32):** the pair (0, 0)–(2124,
      1731) in ft-in is `math.sqrt(2124 * 2124 + 1731 * 1731)` =
      2,740.02499988595 mm and prints `9'-0"`, where exact half-up would
      give `8'-11 3/4"`.
- [ ] **Step 4 — mutants.**

  | mutant | edit | must turn red |
  |---|---|---|
  | M-11e | truncate (`floor`) instead of half-up | `DF1`, `DF2` |
  | M-11halfnaive | `x.round()` only, no tolerance | `DF1`, `DF2` |
  | M-11cmzero | cm drops a trailing zero | `DF1` |
  | M-11reduce | fractions not reduced | `DF1` |
  | M-11marks | feet-inches without `'` and `"` | `DF1` |

  **Extras:**
  - `X5-splitFirst` (feet and inches rounded separately) → `DF1` (the
    carry);
  - `X5-tolWide` (`dimFormat.linear` 1e-5) → `DF2` (3450.5 − 2e-6).
- [ ] **Step 5 — ends green** (engine, render, app); packages unchanged.
  The same lines as Task 2's Step 6.

  Commit `feat(app): dimension values at plan precision, half-up within a tolerance (11 D9)`.

### Task 6: The parameters, the type and the layout (spec D2, D3, D6, D7's geometry, D8)

**Spec:** D2 (R-1, R-2, R-3), D3, D6 (R-6, R-7, R-8), D7's children and
mapping (R-9, R-10), D8 (R-11, R-12); decisions 5, 6, 8, 17, 18.
**Files:**
- `dimension_geometry.dart`:
  - the ends' JSON;
  - the paper constants, `kDimLineweight = 25` and `kDimTextAttrs`;
  - `offsetFor`, `readable`, `DimLayout` and `layoutDimension`;
- `dimension.dart` (create): `DimensionParams`, `DimensionType`,
  `debugDimensionGenerates`, and the export (Ruling 11-2);
- `catalog.dart`;
- `dimension_fixture.dart`: `addDimension`, `fixedAt`, `dimText`,
  `dimLines`, `dimTextGeometry`, `mmPage`;
- tests: `dimension_params_test.dart`, `dimension_layout_test.dart`.

**Port from:** the spike's `dimension.dart` (`DimEnd` JSON,
`DimensionParams`, `DimensionType.generate`, `endPointInView`), its
`layoutDimension` and `readable`, its `support.dart` helpers, its
`rotate_test.dart` (`Q4d`) and its `engine_test.dart` (`Q5e`, `Q5f`).
**Not** its `offset >= 0` side, its computed aligned `h1`, its `==` on the
offset, its lineweight 30, its unflagged extension lines, its
`readsPlaces`/`readBox`, or `kDimOffsetPaperMm`.

- [ ] **Step 1 — the ends' JSON** (D2):
  - an attached end is `{"wall": <handle int>, "k": 0|1, "side":
    "left"|"centre"|"right"}`;
  - a fixed end is `{"point": [x, y]}`;
  - `DimEnd.fromJson` reads either;
  - an unknown `side` name throws, as 07's justification does;
  - any `k` int is accepted (R-3).
- [ ] **Step 2 — `DimensionParams(a, b, kind, offset)`,**
  `componentTypeId = 'floor_planner.dimension'`.
  - `toJson` writes every key, in the order `a`, `b`, `kind` (by name),
    `offset`.
  - `fromJson` reads them; an unknown `kind` name throws.
  - `==` compares the ends and the kind with `==`, and the offset with
    **`compareTo(other.offset) == 0`** (D2).
  - `hashCode` is consistent with `==`: equal values hash alike, and the
    two zeros may collide.
  - `copyWith`.
- [ ] **Step 3 — the paper constants** (R-10), in paper mm:
  - `kDimTextPaperMm = 2.5`;
  - `kDimTextGapPaperMm = 1.0`;
  - `kDimSlashPaperMm = 3.0`;
  - `kDimExtGapPaperMm = 1.5`;
  - `kDimExtOvershootPaperMm = 2.0`.

  Also `const int kDimLineweight = 25;` (D7), and `final int
  kDimTextAttrs = packTextAttrs(h: TextJustifyH.centre, v:
  TextJustifyV.bottom);`.
- [ ] **Step 4 — `double offsetFor(Vector2 q, Vector2 p0, Vector2 p1,
  DimKind kind, Transform2 m)`** (D6, R-7), in local units:
  - **Setup:** `u = measuringDirection(...)` and `n = (−u.y, u.x)`;
  - **the heights:** `h1 = 0` for aligned, and `(p1 − p0) · n` for
    linear; `hi` and `lo` are their max and min;
  - `hq = (q − p0) · n`, and `s = m.scaleMagnitude`;
  - **the result:**
    - `hq ≥ hi` → `(hq − hi) / s`;
    - `hq ≤ lo` → `−((lo − hq) / s)`;
    - otherwise `+0.0` when `hi − hq ≤ hq − lo`, else `-0.0`.
- [ ] **Step 5 — `Vector2 readable(Vector2 u)`** (R-11): it reverses `u`
  when `u.x < −dimFormat.angular`, or when `|u.x| ≤ dimFormat.angular` and
  `u.y < 0`.
- [ ] **Step 6 — `DimLayout layoutDimension(Vector2 p0, Vector2 p1,
  DimKind kind, Transform2 m, double offset, PageComponent page)`,** all in
  world and computed relative to `p0` (D6–D8).
  - **Direction:** `u`, `n`; the value (aligned `|p1 − p0|`, linear
    `|(p1 − p0) · u|`); `h0 = 0`, and `h1` as in Step 4.
  - **The line's height:** `o = offset · m.scaleMagnitude`; `c = hi + o`
    when `offset`'s sign bit is clear, `lo + o` when it is set.
  - **The line:** `Q0 = p0 + n (c − h0)` and `Q1 = p1 + n (c − h1)`.
  - **The extension lines:** `σ = offset.isNegative ? −1 : 1`, and `g`,
    `v`, the slash and the text sizes are the paper constants ×
    `page.scaleDenominator`. Each extension line runs from `P + σ n ·
    min(g, |c − h|)` to `Q + σ n · v`.
  - **The slashes:** `ur = readable(u)`, `nr = (−ur.y, ur.x)`, `t =
    normalize(ur + nr) · (slash / 2)`, and each slash is `Q ∓ t`.
  - **The text:** at `(Q0 + Q1) / 2 + nr · textGap`; its world angle is
    `atan2(ur.y, ur.x)` and its height the text constant ×
    `scaleDenominator`.
  - **The string:** `formatDimension(value, page.displayUnit)`.
  - `DimLayout` is a record of all of these, plus `value`, `u` and `n`.
- [ ] **Step 7 — `DimensionType`** (D3):
  - **The basics:**
    - `editCapability` is `geometry`;
    - `reach` is `Aabb2.empty()`;
    - `references` are the attached ends' walls, in `a`, `b` order,
      deduplicated;
    - `referencePolicy` is the default (`cascade`);
    - `pageKey(page)` is `(p.displayUnit, p.scaleDenominator)` of `page
      ?? PageComponent()`.
  - **`generate`:**
    1. `debugDimensionGenerates++`.
    2. **The ends in world:**
       - attached: `wallsInView(view, wall)` then `wallEndPoint` among
         its walls;
       - fixed: `view.toWorld(self).transformPoint`.
    3. **A broken dimension** generates nothing (D7): an attached end
       whose wall is not a live wall, a `k` outside {0, 1}, a
       non-finite fixed coordinate or a non-finite offset. Its diagnostic
       is Task 7's.
    4. **The layout,** with `view.page ?? PageComponent()`.
    5. **The six children,** each point stored as `toLocal(P0) +
       toLocal.transformDirection(w − P0)`, with `toLocal =
       toWorld.invert()`:
       - five `Generated(EntityKind.line, …, lineweight:
         kDimLineweight)`, the two extension lines with `flags:
         EntityFlags.unpickable`;
       - one `Generated.text(payload, string, textAttrs: kDimTextAttrs)`,
         its scalars `[height / s, angle − atan2(M.b, M.a) + 0.0, 1, 0]`.
  - **`diagnose`** returns `const []` until Task 7 (10-15's precedent).
  - `catalog.dart` registers it.
- [ ] **Step 8 — fixture helpers,** ported:
  - `addDimension(doc, a, b, {kind, offset, at})`: one compound, and the
    handle allocated inside the build;
  - `fixedAt(world, [at])`;
  - `dimText`, `dimLines` (world), `dimTextGeometry` (world point, world
    height, world angle);
  - `mmPage`.
- [ ] **Step 9 — tests.**
  - `test('DP1 DimensionParams round-trips with its keys in order and both '
    'end shapes; == is exact and tells -0.0 from +0.0, kept through save, '
    'load and save; references are deduplicated', …)`
    (`dimension_params_test.dart`), at the origin and `corpusGroups`:
    - **Values:** fractional fixed coordinates (1234.5, −310.25) and a
      fractional offset −617.375.
    - **JSON:** the key order `a, b, kind, offset`, and the two end
      shapes' exact maps. An unknown kind or side throws; `k = 2` is
      accepted.
    - **`==`:** `-0.0` against `+0.0` is not equal, while `(-0.0 ==
      0.0)` is true in Dart (asserted as the premise). A NaN offset
      equals itself.
    - **Save → load → save** of a document holding a `-0.0` dimension:
      byte-identical, and the loaded offset `isNegative`.
    - **`references`:**
      - both ends on one wall → one handle;
      - attached and fixed → one;
      - two walls → two, in `a`, `b` order;
      - fixed and fixed → none.
  - `test('DL1 an aligned dimension on the non-axis pair (0, 0)-(3000, '
    '1200) reads 3231, a horizontal one 3000 and a vertical one 1200, at '
    '$place', …)` (`dimension_layout_test.dart`), at all six placements:
    - **The fixture:** fixed ends in the dimension's own group at the
      placement, an mm page, offset 500.25.
    - **The values:** √(3000² + 1200²) = √10,440,000 = 3,231.1, and the
      three strings.
    - **The line, in the group's local frame by hand:**
      - horizontal: at y 1,200 + 500.25;
      - vertical: at x −500.25, since `n` = (−1, 0) and `h1` =
        (3000, 1200) · (−1, 0) = −3000.

      So `hi` = 0 and `c` = 0 + 500.25 along `n`.
  - `test('DL2 the offset runs from the outermost measured point on the '
    'line\'s side; offsetFor follows the pointer outside the band and '
    'sticks to the nearer extreme inside it, its side the sign bit', …)`,
    at the origin and `corpusGroups`:
    - **`Q4d`:** a horizontal dimension from A/0/right (0, −100) to a
      fixed (5000, −2000), offset −500:
      - the line at −2500: 2400 below A/0/right and 500 below the fixed
        point;
      - A thickened to 4400 (right face y −2200): the line at −2700,
        500 below the face and 700 below the fixed point.
    - **`offsetFor`,** horizontal on (0, 0)–(3000, 1200), with `q` at y:
      - 2000 → `+800`;
      - −300 → `-300`;
      - 900 → `+0.0` (the line at 1,200);
      - 400 → `-0.0` (the line at 0).

      The zeros are asserted with `isNegative`. Each result is stored by
      a command, and the generated line's height is checked.
  - `test('DL3 the children by hand at 1:50 and 1:100, and a pair drawn '
    'right to left reads upright with its text above the line', …)`, at
    the origin and `corpusGroups`, in the group's local frame:
    - **The fixture:** fixed (0, 0) and (4000, 0), horizontal, offset 600,
      an mm page.
    - **At 1:50:**
      - the line (0, 600)–(4000, 600);
      - the extension lines (0, 75)–(0, 700) and (4000, 75)–(4000, 700);
      - the slashes (∓53.033, 600 ∓ 53.033) about each end, 75 / √2;
      - the text at (2000, 650), height 125, rotation 0, `4000`.
    - **At 1:100:** the gap 150, the overshoot 200, the slash ±106.066,
      the text at (2000, 700), height 250.
    - **Right to left, aligned:** (4000, 0) → (0, 0), offset 600:
      - `u` = (−1, 0), `n` = (0, −1): the line at y −600;
      - `readable` flips `u`: `ur` = (1, 0) and `nr` = (0, 1), so the text
        is at (2000, −550), angle 0.
  - `test('DL4 readable reverses a direction that would read from the top '
    'or the left, reads exactly vertical upwards, and a vertical dimension '
    'in a group turned −90° reads +90°', …)`:
    - **`Q5e`'s table** of directions, ported;
    - **`Q5f`:** fixed (0, 0) and (2000, 0) in a group turned −90° at the
      corpus far origin; `u` = (6.1e-17, −1), and the text angle is +90°.
- [ ] **Step 10 — mutants.**

  | mutant | edit | must turn red |
  |---|---|---|
  | M-11negzero | form 1: the offset compared with `==`; form 2: `toJson` writes `offset.abs()` | `DP1` (both forms) |
  | M-11a | aligned computed as the projection on the group's local x | `DL1` (3000 for 3231) |
  | M-11offsetp0 | the offset from `h0` (the first point), not the outermost | `DL2` |
  | M-11sign | the side taken as `offset < 0` | `DL2` (y 400: the line at 1200, not 0) |
  | M-11between | the between band always goes to `+0.0` | `DL2` |
  | M-11fliptol | `readable` with no tolerance at vertical | `DL4` |
  | M-11flip | `readable` never flips | `DL3` (right to left), `DL4` |
  | M-11textbelow | the text at `− nr · gap` | `DL3` |
  | M-11slash | the slash along `ur − nr` | `DL3` |
  | M-11extpage | the gap and the overshoot not × `scaleDenominator` | `DL3` (1:100) |

  **Extras:**
  - `X6-dedup` (`references` not deduplicated) → `DP1`;
  - `X6-worldStore` (children stored in world, not local) → `DL3` at
    `corpusGroups`;
  - `X6-groupAngle` (the group's rotation not subtracted) → `DL3` at
    `corpusGroups`;
  - `X6-gapNoMin` (the extension line starts at `g` even when `|c − h| <
    g`) → `DL2` (the `+0.0` line, whose extension at P1 must be zero
    length).
- [ ] **Step 11 — ends green** (engine, render, app); packages unchanged.
  The same lines as Task 2's Step 6.

  Commit `feat(app): the dimension object: parameters, type and layout (11 D2, D3, D6–D8)`.

### Task 7: The records, the page, save and load, and diagnostics (spec D7's attributes, D3's page key, D9 through the object, D15, D16)

**Spec:** D7 (the record attributes, R-9), D3's page key, D8's height, D9
(`DF3`), D15 (R-29), D16; Rulings 11-11, 11-12.
**Files:** `dimension.dart` (`diagnose`); tests:
- `dimension_object_test.dart` (create);
- `dimension_format_test.dart` (`DF3`);
- `dimension_layout_test.dart` (`DL5`).

**Port from:** the spike's `engine_test.dart` (`Q5a`, `Q5d`) and its
`drift_test.dart` (`Q2c`, `Q2d`); 10's `room_diagnostics_test.dart` for
the file cases (`staleFile`) and NaN by command.

- [ ] **Step 1 — `diagnose`** (D15), each code at most once per dimension:
  - **`dimension.degenerate`,** a warning: D6's value ≤
    `wallJoin.linear`, with the message `"<handle> measures zero"`.
  - **`dimension.broken`,** an error, for any of:
    - an attached end that names a live object which is not a wall;
    - a `k` outside {0, 1};
    - a non-finite fixed coordinate;
    - a non-finite offset.
  - **A dead handle** is the engine's `parametric.dangling` and is not
    repeated.
- [ ] **Step 2 — tests.**
  - `test('DO1 a dimension\'s children are five LINEs and one TEXT in '
    'handle order; only the two extension lines carry '
    'EntityFlags.unpickable; lineweight 25, ByLayer, layer 0, bottom-centre '
    'text', …)`, at `corpusGroups`:
    - **The fixture:** a turned dimension group, with A/0/left → A/1/left
      and an offset of 600.5.
    - **The records:**
      - the kinds `[line × 5, text]` in ascending handles;
      - the flags `[0, 2, 2, 0, 0, 0]`;
      - lineweight 25 on each LINE;
      - `ByLayerColor` and the ByLayer linetype on all six;
      - layer 0;
      - the TEXT's `textAttrs` equal `kDimTextAttrs`;
      - every other attribute is `draftRecord`'s default.
  - `test('DO2 a page change rewrites every dimension in one undo step with '
    'the same child handles; a paper colour or grid change generates '
    'none; no page reads as 1:50 m', …)`, at the origin and `corpusGroups`
    (Ruling 11-11):
    - **The fixture:** `Q5a`, `A (0,0)→(4000,0)` 200, A/0/left →
      A/1/left, offset 600; the line at y 700, the text at (2000, 750).
    - **1:50 mm** (`4000`, height 125) → **1:100 ft-in in one
      `SetComponentCommand<PageComponent>`:**
      - `13'-1 1/2"` (4000 / 25.4 = 157.48", 629.92 quarters → 630 =
        157.5");
      - height 250, the same six handles;
      - `undoDepth` +1 and `drift()` empty;
      - undo restores `4000` and 125, and redo the ft-in.
    - **A paper colour change and a grid step change** each leave
      `debugDimensionGenerates` unchanged.
    - **No page attached:** `4.00` (1:50 m).
  - `test('DO3 save, load and save is byte-identical, with references '
    'intact, drift() empty after the load, and a -0.0 offset kept', …)`,
    at the origin and `corpusGroups`:
    - **The fixture:** an L with three dimensions:
      - attached to attached;
      - attached to a fixed fractional point, in a turned group;
      - a `-0.0` offset.
    - **After the reload:**
      - `drift()` is empty;
      - the loaded offset `isNegative`;
      - **the references are intact:** a thickness edit of a referenced
        wall rebuilds its dimensions, whose texts change as the hand
        arithmetic says.
  - `test('DO4 the same state plus the same edit gives the same bytes', …)`:
    two documents built alike, the same wall-thickness edit, equal
    `encodeToString`.
  - `test('DO5 a dimension keeps its six child handles across twenty '
    'regenerations, undo and redo, a zero value included', …)`:
    - **The twenty edits:** wall moves, fractional offsets, a kind
      switch, a page change, and one edit that makes the value zero and
      one that restores it.
    - **After each:** the same `kids` list.
    - **Then** undo all and redo all.
  - `test('DF3 a half through the object rounds up at all six placements: a '
    'free wall 3450.5 long face to face, and a half between two computed '
    'corners', …)` (`dimension_format_test.dart`):
    - **`Q5d`:** `A (0,0)→(3450.5,0)` 200, A/0/left → A/1/left, mm page
      → `3451`.
    - **The two-corner half:** `A (0,0)→(3550.5,0)` and B north from A's
      end, both 200. A/0/left (0, 100) → A/1/left (3,450.5, 100), since
      3,550.5 − 100 = 3,450.5 → `3451`.
    - **Printed:** the measured value and its distance from the half, per
      placement (the far-origin margin, S-4).
  - `test('DL5 a coincident aligned pair and a vertical pair measured '
    'horizontally still draw six children, read 0, and report '
    'dimension.degenerate', …)` (`dimension_layout_test.dart`):
    - **Coincident:** fixed (1234.5, −310.25) twice, aligned. The six
      children lay out along the group's local x (R-8); the text `0`.
    - **A vertical pair measured horizontally:** fixed (0, 0) and (0,
      3000), horizontal. The six children, the collapsed lines zero
      length, `0`.
  - `test('DD1 dimension.degenerate is one warning while the value is '
    'within wallJoin.linear of zero, and clears when it grows', …)`, at the
    origin and `corpusGroups`:
    - **Made zero by a wall edit:** a horizontal A/0/left → A/1/left, and
      A's end moved to make A vertical.
    - **Made zero by a rotation:** the same dimension's group turned 90°
      alone (decision 17: the axis turns, the ends stay).
    - **Each time:** one warning with its message, and `drift()` empty.
      It clears when undone.
  - `test('DD2 dimension.broken from a file (a live box as the wall, k = 2, '
    'an infinite point, an infinite offset) and from a command (a NaN point, '
    'a NaN offset): each an error, childless; a dead wall handle is '
    'parametric.dangling only', …)` (Ruling 11-12):
    - **The file cases** edit the encoded JSON, `1e999` and `-1e999`, and
      load it.
    - **The NaN cases** use `SetComponentCommand<DimensionParams>`.
    - **Each:** `kids` is empty, and one `dimension.broken`.
    - **A dead handle:** `parametric.dangling`, and no `dimension.broken`.
- [ ] **Step 3 — mutants.**

  | mutant | edit | must turn red |
  |---|---|---|
  | M-11b | the text height not × `scaleDenominator` (the paper half) | `DO2` |
  | M-11page | `pageKey` returns null | `DO2` |
  | M-11text | **engine** (`regeneration.dart`, the TEXT match, 10's M-10f site): a matched TEXT's string never rewritten. `cp` backup and restore (Ruling 11-20) | `DO2` |
  | M-11lw | `kDimLineweight = 30` (decision 20's fallback) | `DO1` |
  | M-11colour | the lines and the text generated in `TrueColor(0x000000)`: two sites, the LINEs and the TEXT, each fired | `DO1` |
  | M-11extflag | the extension lines with flags 0 | `DO1` |
  | M-11stable | a zero dimension skips its zero-length LINEs | `DL5` |
  | M-11degenerate | `dimension.degenerate` never reported | `DD1` |
  | M-11broken | a broken end generates from a fallback point (`k` clamped to 1, a non-finite value read as 0) | `DD2` |

  **Extras:**
  - `X7-degenerateError` (severity error) → `DD1`;
  - `X7-brokenWarn` (severity warning) → `DD2`;
  - `X7-danglingTwice` (`dimension.broken` also for a dead handle) →
    `DD2`;
  - `X7-noDefaultPage` (no page → an empty string) → `DO2`.
- [ ] **Step 4 — ends green** (engine, render, app); packages unchanged
  (the M-11text fire restored and diffed). The same lines as Task 2's
  Step 6.

  Commit `feat(app): dimension records, page key, save and load, diagnostics (11 D3, D7, D15, D16)`.

### Task 8: The closure and the drift fuzz (spec D5)

**Spec:** D5 (the invariant, the argument, the cost bound, the fuzz and
its oracle; S-6, S-9), D3's cascade, D16; the Differential check.
**Files:**
- `dimension_fixture.dart`: `oracleEnd`, `oracleFailures`;
- tests: `dimension_follow_test.dart`, `dimension_fuzz_test.dart`
  (create).

**Port from:** the spike's `drift_test.dart` (`Q2a`, `Q2b`, `Q2c`, `Q2e`,
the oracle and the fuzz driver) and its `support.dart` (`oracleEnd`,
`allWorldWalls`). Not option (b).

- [ ] **Step 1 — the oracle** (D5).
  - `oracleEnd` reads an attached end among **every** live wall of the
    document (`wallsInDocument`'s walls, not the view's neighbours), and
    a fixed end through its group.
  - `oracleFailures(doc)` re-lays every live dimension out with
    `layoutDimension` (Ruling 11-3) and compares:
    - the TEXT string exactly;
    - every stored child's world points within 1e-6 mm, the text
      insertion included;
    - the height and rotation within 1e-9.
- [ ] **Step 2 — tests** (`dimension_follow_test.dart`). After every edit,
  `drift()` is empty and `oracleFailures` is empty.
  - `test('DN1 a neighbour\'s edit moves a referenced wall\'s corner and '
    'rebuilds the dimension once, at $place', …)`, at the origin,
    `corpusGroups` and `km1000Groups` (`Q2a`):
    - **The L:** A/0/left → A/1/left, which references A only: `3900`.
    - **B 200 → 300:** A's parameters are `==` unchanged, the reading is
      `3850`, and `debugDimensionGenerates` +1.
    - **C joined at A's start:** `3750`. **C deleted:** `3850`.
  - `test('DN2 the T: the through wall thickened moves the stem\'s corner; '
    'the through wall moved off the stem squares it', …)`, at the origin
    and `corpusGroups` (`Q2b`): `2900` → `2800` → `3000`.
  - `test('DN3 deleting a referenced wall deletes its dimensions in the '
    'same step; the other wall\'s dimension rebuilds; undo restores every '
    'handle and owner', …)`, at the origin and `corpusGroups` (`Q2c`):
    - the second dimension, on B only, reads `3100` → `3000`;
    - `undoDepth` +1;
    - undo restores the canonical bytes (`canon`, nodes sorted) and every
      entity's handle and owner.
  - `test('DN4 an edit away from a dimension\'s walls generates nothing for '
    'it; an offset change regenerates exactly the dimensions on its walls; '
    'the door-slide and partition counts are printed', …)`:
    - **Away:** a wall that is neither referenced nor a neighbour of one
      is edited: the delta is 0.
    - **An offset change** of one dimension that references A only: the
      delta equals the number of live dimensions referencing A, itself
      included.
    - **Printed, not asserted** (S-6): the deltas for a door slid along a
      wall carrying N = 1, 10 and 50 dimensions, and for a thickness
      change of a partition T-joined to it.
- [ ] **Step 3 — `DZ1`** (`dimension_fuzz_test.dart`):
  `test('DZ1 300 seeded edits keep every dimension equal to the all-walls '
  'oracle, with neighbour-only rebuilds; a reload agrees', …)`.
  - **The setup:**
    - `sampleWalls()`, nine walls and no column (S-9), at
      `corpusGroups`, with an mm page;
    - fourteen dimensions from `Random(11)`: random wall end points, a
      fifth of the ends fixed, all three kinds, a third of the groups
      rotated.
  - **The 300 edits,** from D5's list:
    - a thickness, a justification;
    - an end moved ±400 mm;
    - a wall's group moved and turned;
    - a wall added at a wall end, a wall deleted;
    - undo;
    - a dimension's group moved or turned;
    - a kind switched, an offset set;
    - an end re-attached to a random wall end point, or made fixed;
    - a page change (unit and scale).
  - **After each:** `drift()` and `oracleFailures` are empty.
    `neighbourOnly` counts the edits where a dimension's text changed
    although it references none of the edited walls.
  - **Asserted:** `neighbourOnly > 0`. The spike's run counted 10.
  - **Printed:** `(edits, failures, generates, neighbourOnly)`. The
    spike's narrower mix printed `(edits: 300, failures: [], generates:
    1466, neighbourOnly: 10, …)`; this run's figures will differ.
  - **The reload:** after the run, the saved bytes are loaded into a
    fresh document and system (the Differential check). `drift()` is
    empty, and every dimension's children compare equal by payload
    bytes.
  - **Timing:** if it exceeds the runner's default timeout, give it an
    explicit `timeout:` and record the runtime.
- [ ] **Step 4 — mutants.**

  | mutant | edit | must turn red |
  |---|---|---|
  | M-11closure | **engine** (`regeneration.dart` `_closure`): referrers of the seeds only (08's brief rule). `cp` backup and restore | `DN1`, `DN2`, `DZ1` |
  | M-11refs | `references` returns nothing | `DN1`, `DN3` |
  | M-11c | the value memoised by handle, never recomputed | `DN1`, `DN2`, `DZ1` |

  **Re-fire here:** M-11nbrs → `DN1` (its second killer).
  **Extras:**
  - `X8-noOracle`: run `DZ1` with `oracleFailures` disabled under
    M-11closure, and record whether `drift()` alone catches it. This is
    a control for the oracle's worth, never committed.
- [ ] **Step 5 — ends green** (engine, render, app); packages unchanged
  (M-11closure restored and diffed). The same lines as Task 2's Step 6.

  Commit `test(app): dimensions follow their walls' neighbours; a seeded drift fuzz (11 D5)`.

### Task 9: The Dimension tool — clicks, kinds, the offset, the commit (spec D12)

**Spec:** D12 (R-20, R-21, R-22, R-23, R-25, R-33; S-8), D10's timing
(decision 22) and fixed points (decision 23), decisions 9 and 10; 05 D3,
D4, D5.
**Files:**
- `dimension_tool.dart` (create);
- `main.dart`: the tool, its palette entry, key I;
- `shortcut_guard.dart`: I;
- `test/dimension_tool_test.dart` (create).

**Port from:** nothing in the spike. The shapes to follow are 10's
`SeparatorTool` (two clicks, not chained) and its tests, and
`wall_tool_test.dart`'s rig (a real `ToolContext`).

- [ ] **Step 1 — `DimensionTool extends PlacementTool`,** `name =>
  'Dimension'`.
  - **Shift** (S-8): `onPointerMove` and `onPointerDown` store
    `e.shift`, and `onKey` stores the Shift key's down and up. Each does
    so **before** calling `super`.
  - **`orthoBase`** returns null once two points are placed (R-20).
  - **`accept(point, ctx)`:**
    - **Click 1** stores `P0`.
    - **Click 2** stores `P1`, unless the pair is degenerate (R-23), in
      which case the click is ignored and the tool keeps waiting. It is
      degenerate when:
      - `|P1 − P0| ≤ wallJoin.linear`; or
      - the two points' fresh `attachCandidates` sets share an
        `AttachedEnd` (Ruling 11-8).
    - **Click 3** commits.
  - **The kind** (R-21):
    - without Shift, aligned;
    - with Shift, the drag-side rule. `e_x` and `e_y` are how far `q`
      lies outside the two points' x and y spans. `e_y > e_x` gives
      horizontal and `e_x > e_y` vertical. On a tie, horizontal when
      `|dx| ≥ |dy|`, else vertical. If the chosen kind measures ≤
      `wallJoin.linear`, the other kind is used.
    - The comparisons are exact.
  - **The ends** (D10, decision 22): at the commit, `attachCandidates`
    for `P0` and `P1` afresh (`objectSnap: ctx.snap?.objectSnap ?? true`,
    `thickest: thickestWall(doc)`). Then `decideEnd` with the committed
    kind, `at` the end's point, `other` the other's, and `m` the identity.
    With no candidate, `FixedEnd(P)`.
  - **The offset:** `offsetFor(q, P0, P1, kind, identity)`.
  - **The commit:** `commit(ctx, () => CompoundCommand([AddNodeCommand(a
    group at the identity), SetComponentCommand<DimensionParams>(…)]),
    needs: {structure, components, geometry})`.
    - The handle is allocated **inside** the build (08's Task 10: never
      predicted).
    - `ArgumentError`, `StateError` and `DanglingReferenceError` are
      caught, and nothing is placed.
    - Then the points are cleared; the tool is not chained (R-25).
  - **Enter** keeps `finish`'s default no-op (R-33). **Esc** and undo
    while pending are `PlacementTool`'s.
- [ ] **Step 2 — the shell.**
  - `main.dart` gains `late final DimensionTool _dimension =
    DimensionTool();` and a palette entry: `tool-dimension`, label
    `Dimension`, shortcut `I`, `LogicalKeyboardKey.keyI`, `drawing:
    true`, placed after `tool-separator`.
  - `kShellLetterKeys` gains `LogicalKeyboardKey.keyI` (decision 10).
- [ ] **Step 3 — tests.**
  - **The rig:** the tool with a real `ToolContext`, as
    `wall_tool_test.dart` builds it, and the plans from
    `dimension_fixture.dart`. `TL4` and `TL7` run through the shell.
  - **Premises:** every click states its aperture (10 px ÷ the camera's
    px/mm). Every free click asserts `hoverKind == null`, and `grid`
    false when no page is attached.
  - `test('TL1 three clicks place one dimension in one undo step; ends on '
    'wall end points attach, others are fixed; the tool then waits for a '
    'new first click', …)`, at the origin and `corpusGroups`, on
    `samplePlan`:
    - **The Hall's corners:** clicks 5 mm off E1/0/left (12,250, 8,250)
      and P1/0/left (16,940, 8,250), in the placement's frame, at 0.3
      px/mm (a 33.3 mm aperture). The third click is 900 mm up in the
      placement's frame, without Shift (aligned: along E1's face, so
      `σ_E1` is 0 at every placement).
    - **What lands:**
      - one new root-level group at the identity;
      - `undoDepth` +1, and one undo removes the group and its component;
      - `a == AttachedEnd(E1, 0, left)` and `b == AttachedEnd(P1, 0,
        left)`.
    - **A fixed end:** a third dimension from the Hall corner to a
      mid-room point with no object in the aperture. That end is
      `FixedEnd` at the raw world point.
    - **Not chained:** after the commit, `points` is empty and the tool
      is still active.
  - `test('TL2 with Shift the third click is linear by the side dragged to, '
    'without it aligned; Shift at the second click is ortho, at the third '
    'it is not', …)`, at the origin and `corpusAxis` (Ruling 11-9). An
    empty document, F3 on, no page. The points are added to the
    placement's translation:
    - **With `P0` (0, 0) and `P1` (3000, 1200):**
      - `q` (1500, 2000): above → horizontal;
      - (3500, 600): right → vertical;
      - (3600, 2000): `e_x` 600 < `e_y` 800 → horizontal;
      - (3900, 1500): `e_x` 900 > `e_y` 300 → vertical;
      - (1500, 600): a tie inside, `|dx|` 3000 ≥ `|dy|` 1200 →
        horizontal;
      - the same `q` without Shift → aligned.
    - **A vertical pair,** (0, 0) and (0, 3000), dragged to (0, 3600):
      horizontal would measure 0, so **vertical**.
    - **Ortho at the third click is off:** raw third (1500, 1400) with
      Shift commits horizontal with the line at y 1,400, offset `+200`.
      An ortho-pinned (1500, 1200) would have given 1,200.
    - **Ortho at the second click is on:** from `P0` (0, 0), a raw
      (3000, 1250) with Shift stores `P1` (3000, 0).
  - `test('TL3 the third click\'s offset runs from the outermost point, '
    'sticks to the nearer extreme inside the band, and keeps its side in '
    'the sign bit', …)`, at the origin and `corpusAxis`:
    - **The fixture:** horizontal over (0, 0) and (3000, 1200), Shift
      held, the third click at x 1500.
    - **The results** by the third click's y:
      - 2000 → `+800`;
      - −300 → `-300`;
      - 900 → `+0.0`;
      - 400 → `-0.0`, with `isNegative` asserted.
  - `test('TL4 Esc drops one or two pending points and places nothing, and '
    'Esc again returns to Select; a second click on the first point, or on '
    'the same wall end point 5 µm away, is ignored; Enter with points '
    'pending does nothing', …)`, through the shell:
    - **Esc:** after one point and after two, nothing is placed; a
      further Esc makes the active tool `Select`.
    - **The same point:** a second click exactly on `P0` leaves one point
      pending.
    - **The same wall end point:** a second click at the corner + (5e-6,
      0) mm is ignored, since 5e-6 > `wallJoin.linear` but both points'
      candidates hold the corner. Asserted as a premise:
      `attachCandidates` at both points share the corner.
    - **Enter** with one point and with two leaves the points and the
      document unchanged.
  - `test('TL6 decision 23 through the tool: with F3 on a grid point on a '
    'corner attaches and a flush door\'s jamb snap attaches the stem\'s '
    'corner; with F3 off every end is fixed', …)`, at the origin and
    `corpusGroups`:
    - **The grid:** Ruling 11-23's page and camera on `samplePlan`.
      - **F3 on:** the pointer resolves to the corner by the grid
        (`hoverKind` null, a premise); the committed horizontal dimension
        stores **E1/0/right**.
      - **F3 off:** the same clicks store `FixedEnd` at the corner.
    - **The jamb** (Ruling 11-7), at 0.3 px/mm: `flushT(c: 450, swing:
      left)`, with the first click 5 mm off the jamb corner.
      - The hover snaps there (`hoverKind` endpoint, a premise), and the
        committed end is **S/0/left**.
      - With F3 off it is fixed.
  - `test('TL7 I activates the Dimension tool from the canvas and the '
    'palette; typing I into a panel text field switches nothing', …)`,
    through the shell:
    - key I → the status line's tool is `Dimension`;
    - a tap on `tool-dimension` activates it too;
    - select the Hall room, focus its Name field, and type `I`: the field
      holds the `I`, and the active tool is unchanged.
- [ ] **Step 4 — mutants.**

  | mutant | edit | must turn red |
  |---|---|---|
  | M-11shift | the third click ignores Shift (always aligned) | `TL2` |
  | M-11dragside | horizontal and vertical swapped in the drag-side rule | `TL2` |
  | M-11zerokind | the zero-measuring linear kind is committed | `TL2` (the vertical pair) |
  | M-11ortho3 | `orthoBase` stays `points.last` at the third click | `TL2` (the line at 1,200) |
  | M-11degeneratepair | a second click on the first point is accepted | `TL4` |
  | M-11twosteps | the node and the component committed as two commands | `TL1` (two undo steps) |
  | M-11key | I missing from `kShellLetterKeys` | `TL7` (the field) |
  | M-11snaponly | the tool gathers candidates only when `hoverKind != null` (Ruling 11-6) | `TL6` (the grid row) |

  **Re-fire here:** M-11snapoff → `TL6` (its second killer); M-11sign and
  M-11between → `TL3` (Ruling 11-3's one site).
  **Extras:**
  - `X9-chained` (the tool starts the next dimension at `P1`) → `TL1`;
  - `X9-tieVertical` (a tie goes to vertical) → `TL2`;
  - `X9-predict` (the handle predicted before the build) → `TL1`, in a
    document whose handle seed another edit raised in between;
  - `X9-memoCommit` (the commit reads a candidate memo instead of
    gathering afresh) → a `TL1` clause: a wall moved by a command between
    the second click's hover and the commit, and the end still attaches
    at the new corner.
- [ ] **Step 5 — ends green** (engine, render, app); packages unchanged.
  The same lines as Task 2's Step 6.

  Commit `feat(app): the Dimension tool on I: three clicks, Shift for linear (11 D12)`.

### Task 10: The Dimension tool — preview, attach rings, status notice, hover cost (spec D12's preview and costs)

**Spec:** D12's preview (R-24), its notice (S-8) and its costs (S-13's
`TL8`); D10's line test; 10 D19's notice pattern; Rulings 11-8, 11-21,
11-22.
**Files:**
- `dimension_tool.dart`: the preview, the rings, `notice`, the memo,
  `debugAttachSearches`;
- `main.dart`: the status line;
- `dimension_fixture.dart`: `dimGridWalls`;
- `test/dimension_tool_test.dart`: `TL5`, `TL8`.

- [ ] **Step 1 — the preview** (R-24).
  - **After click 1:** the rubber band from `P0` to the resolved hover
    point, as the Line tool draws it.
  - **After click 2:** the would-be dimension's five lines, in world,
    from `layoutDimension` for the kind Shift selects now (Ruling 11-3),
    with `offsetFor` of the hover point.
  - They are rebuilt only when the resolved point or Shift changes, into
    cached payloads. `paintRubberBand` draws only from the cache.
  - `@visibleForTesting int debugPreviewBuilds` counts the rebuilds.
- [ ] **Step 2 — the rings.**
  - A 4 px radius circle in `kPreviewColor` at each placed or hovered
    point whose candidates are not empty, only while F3 is on.
  - **The memo** (Ruling 11-8): the hover's candidates, keyed by the
    resolved point (exact `==`) and a generation. The generation is
    bumped on each `doc.changes` event, at the tool's commit and on
    `activate`. The subscription is cancelled on `deactivate`.
  - `@visibleForTesting int debugAttachSearches` counts
    `attachCandidates` calls from the tool, for hovers and clicks.
- [ ] **Step 3 — `ValueListenable<String?> notice`.**
  - While two points are placed: `formatDimension(value,
    unit)` of the would-be dimension, in `ctx.page?.value ??
    PageComponent()`'s unit, exactly what the TEXT will read.
  - Otherwise null. It is set to null at the commit, on Esc and on
    `deactivate`.
- [ ] **Step 4 — the status line.**
  - `main.dart`'s `_status` merges `_dimension.notice`.
  - `_statusLine` appends ` — <notice>` from whichever of the Room
    tool's and the Dimension tool's notices is not null. Only the active
    tool sets one, and both clear on deactivation.
- [ ] **Step 5 — `dimGridWalls`** (Ruling 11-22), and a 600-wall fixture
  with one 900 mm door on the wall the `TL8` path crosses.
- [ ] **Step 6 — tests.**
  - `test('TL5 the preview\'s five lines equal the committed children in '
    'world; the status line reads Dimension — 4.69 over the Hall\'s '
    'corners and clears after the commit and on deactivation; attach rings '
    'mark only attaching points', …)`, at the origin and `corpusGroups`:
    - **The preview against the result.** On `samplePlan` with a 1:50 m
      page, for aligned, horizontal (Shift) and vertical (Shift, dragged
      right), after click 2 and one hover: the cached preview lines and
      the committed children, in world, agree within 1e-9 mm.
    - **The status line,** through the shell: after the Hall's two
      corners and a hover without Shift, the `status-text` reads
      `Dimension — 4.69`, since 16,940 −
      12,250 = 4,690 → `4.69`, and `notice.value == '4.69'`. It is null
      after the commit, and after a switch to Select mid-dimension.
    - **The rings,** through `paintOverlay` into a spy canvas, as 10's
      `TT6`:
      - one circle each at an attaching placed point and at an attaching
        hover;
      - none over a mid-face hover;
      - none at all with F3 off.
    - **No rebuild on repaint:** `debugPreviewBuilds` is unchanged across
      ten repaints with no pointer move.
    - **Shift alone** re-resolves and rebuilds the preview once
      (Review Focus 2).
  - `test('TL8 hovering among 600 walls searches once per distinct resolved '
    'point, passes no line test between a centreline and its faces or past '
    'a door, passes one on a face line and one on a centreline, and a '
    'commit searches afresh once per end; the time per move is printed', …)`,
    at the origin, F3 on, 0.3 px/mm:
    - **The path in the band:** 50 hovers along one wall a quarter of its
      thickness in from a face, crossing into the door's cut, all at
      points with no object in the aperture. `debugLineTestPasses` is
      unchanged (0 passes). `debugAttachSearches` grows by the number of
      **distinct** resolved points, and a repeated point adds 0.
    - **On the lines:** one hover exactly on the face line passes
      (`debugLineTestPasses` +1). One hover exactly on the centreline
      passes (+1), which is plan-added for M-11prefilter.
    - **After a document change:** a command moves a far wall, the test
      pumps, and the same point searches again.
    - **A commit:** exactly 2 fresh searches (Ruling 11-8).
    - **Printed:** the median time per move over the path, and D12's
      budget of 1 ms. Not asserted (Ruling 11-21).
- [ ] **Step 7 — measure before review** (Ruling 11-21): paste `TL8`'s
  printed line into the report. If it is over 1 ms, stop and report where
  the time goes.
- [ ] **Step 8 — mutants.**

  | mutant | edit | must turn red |
  |---|---|---|
  | M-11notice | the tool sets no notice | `TL5` |

  **Re-fire here:** M-11prefilter → `TL8` (the centreline hover).
  **Extras:**
  - `X10-memoForever` (the generation never bumped) → `TL8` (after the
    change);
  - `X10-noMemo` (every hover searches) → `TL8`;
  - `X10-ringsF3off` (rings with F3 off) → `TL5`;
  - `X10-previewPerPaint` (the preview recomputed in `paintRubberBand`)
    → `TL5` (`debugPreviewBuilds`);
  - `X10-noticeNoClear` (the notice kept after the commit) → `TL5`.
- [ ] **Step 9 — ends green** (engine, render, app); packages unchanged.
  The same lines as Task 2's Step 6.

  Commit `feat(app): the Dimension tool's preview, attach rings and status value (11 D12)`.

### Task 11: The grips (spec D13)

**Spec:** D13 (R-26, R-34), D10's timing for a drop (decision 22), D11's
`movable` (R-19); 07 OG5; 08's Ruling 08-15 (the resolved point); Ruling
11-25.
**Files:**
- `dimension_grips.dart` (create);
- `object_grips.dart`;
- `main.dart`: `index: _index`;
- `test/dimension_grips_test.dart` (create).

**Port from:** nothing in the spike. The shape to follow is 10's
`SeparatorGrips` and `room_grips_test.dart`.

- [ ] **Step 1 — `DimensionGrips({required SpatialIndex index, required
  bool Function() objectSnap})`.**
  - **`gripsOf`:**
    - none for a broken dimension;
    - otherwise three `GripRole.stretch` grips, in world:
      - ordinal 0 at `(Q0 + Q1) / 2`;
      - ordinal 1 at `P0`;
      - ordinal 2 at `P1`.
  - **`drag(d, group, grip, q)`,** with `q` the point the select tool
    resolved:
    - **ordinal 0:** `offsetFor(q, P0, P1, currentKind, M)`. It returns
      null when that `compareTo`s equal to the stored offset, and one
      `SetComponentCommand<DimensionParams>` otherwise.
    - **ordinals 1 and 2:** `attachCandidates(d, index, q, objectSnap:
      objectSnap(), thickest: thickestWall(d))`, afresh (Ruling 11-8).
      - Then `decideEnd(kind: currentKind, at: q, other: the other end's
        current world point, m: M)`, or `FixedEnd(M.invert() · q)` when
        there are no candidates.
      - The other end and the offset are kept.
      - It returns null when the new end equals the stored one, or when
        the result is degenerate: the two points within
        `wallJoin.linear`, or the new end equals the other end.
  - **`preview`:** the five would-be lines, in world, from
    `layoutDimension` with the would-be parameters, computed once per
    pointer move. No ring (R-34).
  - **`movable`:** true (R-19).
- [ ] **Step 2 — `ObjectGrips`.**
  - An optional `SpatialIndex? index`. When it is given, `DimensionParams`
    dispatches to `DimensionGrips(index: index, objectSnap: objectSnap ??
    _snapOn)`.
  - The class comment lists the arm, and `movable` stays the provider's
    answer (08's F2).
  - The shell passes `index: _index`.
- [ ] **Step 3 — tests** (`dimension_grips_test.dart`), at the origin and
  `corpusGroups` unless stated. `GE4`'s runtime clause goes through a real
  `GripCache` (Ruling 11-25).
  - `test('GE1 a dimension has three grips, at its line\'s midpoint and its '
    'two measured points, in world, under a turned group', …)`:
    - **The fixture:** a fixed-fixed horizontal at (1234.5, −310.25) and
      (4234.5, 889.75), in a group turned 30° at the placement, offset
      500.5.
    - **The grips** at the hand values, taken through the group. Also an
      attached-fixed dimension.
  - `test('GE2 the offset grip stores offsetFor of the drop with the current '
    'kind: outermost, between band, sign bit; one undo step; a drop that '
    'changes nothing returns null', …)`:
    - **The fixture:** horizontal over (0, 0) and (3000, 1200), in a
      group turned 30°. The drops are at the local y values of `DL2`,
      taken to world: `+800`, `-300`, `+0.0` and `-0.0`.
    - **Each:** `undoDepth` +1, and the kind unchanged.
    - **A drop on the line itself:** null.
  - `test('GE3 an end grip attaches a fixed end, detaches an attached one, '
    'moves one to another wall\'s point, and never re-decides the other '
    'end', …)`:
    - **Attach:** a fixed end dropped on a corner, F3 on.
    - **Detach:** an attached end dropped mid-room (no candidate), and
      one dropped on the same corner with F3 off. Both are `FixedEnd` at
      the local drop point.
    - **Move:** an attached end moved to another wall's corner.
    - **The other end** (`AM3`'s L, B with the lower handle):
      1. a horizontal dimension from A/0/left to the inner corner, stored
         **A/1/left**;
      2. its kind switched to vertical by the command the panel issues (a
         `SetComponentCommand` with the kind only; the panel is Task 12);
      3. its **other** end dragged to (0, 1500).

      The corner end is still **A/1/left**.
  - `test('GE4 a degenerate drop returns null; under runtime permissions no '
    'grip is hit and no drag lands; a broken dimension has no grips', …)`:
    - **Degenerate:** an end dropped on the other end's point, and on the
      other end's wall end point: null.
    - **Runtime:** `DraftPermissions.runtime`. `GripCache.hitTest` at each
      grip's screen position is −1, and `GripDrag`'s command is null.
    - **Broken:** a `k = 2` dimension has `gripsOf` empty.
  - `test('GE5 the preview equals the committed lines on a horizontal '
    'dimension over the non-axis pair, for an offset drag and an end drag', …)`
    (S-15):
    - **The fixture:** horizontal over (0, 0)–(3000, 1200), fixed ends.
    - **Each drag:** its `preview` lines, and the lines generated after
      executing `drag`'s command, agree in world within 1e-9 mm.
- [ ] **Step 4 — mutants.**

  | mutant | edit | must turn red |
  |---|---|---|
  | M-11otherend | an end drop re-decides the other end too (`decideEnd` on it with the new kind) | `GE3` |
  | M-11gripoffset | the offset grip stores the drop's height from `P0` (`hq / s`) | `GE2` |
  | M-11gripplace | the offset grip at `Q0` | `GE1` |
  | M-11runtime | **render layer** (Ruling 11-25): `GripCache.leafGripsLive` returns true. `cp` backup and restore | `GE4` |
  | M-11previewkind | the grip preview laid out as aligned whatever the kind | `GE5` |

  **Re-fire here:** M-11sign and M-11between → `GE2`.
  **Extras:**
  - `X11-noNull` (a no-change offset drop returns a command) → `GE2`
    (`undoDepth`);
  - `X11-fixedWorld` (the detached end stored at the world `q`, not
    local) → `GE3` (the turned group);
  - `X11-snapAlwaysOn` (`objectSnap: true` passed whatever F3 says) →
    `GE3` (F3 off);
  - `X11-movableFalse` is M-11movable, fired in Task 15.
- [ ] **Step 5 — ends green** (engine, render, app); packages unchanged
  (M-11runtime restored and diffed). The same lines as Task 2's Step 6.

  Commit `feat(app): dimension grips: the offset and the two ends (11 D13)`.

### Task 12: The Dimension section (spec D14)

**Spec:** D14 (R-18, R-27, R-28; S-8), D11's axes line; 07 `WS8`; 10 D21's
exactly-one rule and R-25's pattern.
**Files:** `selection_panel.dart`, `test/dimension_panel_test.dart`
(create).

- [ ] **Step 1 — the section.** It shows when **exactly one** selected
  key is a root-level group carrying `DimensionParams`. Its title keys
  `dimension-section`.
  - **Value** (`dimension-value`): the TEXT child's stored string, or `—`
    for a broken dimension. It is looked up per document change and
    cached by handle, as 10's Area.
  - **The kind:** a `SegmentedButton<DimKind>` (`dimension-kind`, with
    segments `dimension-aligned`, `dimension-horizontal` and
    `dimension-vertical`), like the Wall section's (676).
    - A click on another kind is one `SetComponentCommand` with only
      `kind` changed (R-27).
    - A click on the current kind issues nothing.
    - A refused edit (`ArgumentError`, `StateError`) is caught, and the
      switch shows the model's kind.
  - **The axes line** (`dimension-axes`), for a linear kind only:
    - `angle` is `atan2(M.b, M.a)` in degrees, normalised to (−180,
      180];
    - it is shown when `angle.abs() >= 0.05`, testing the number, not
      the string (S-8);
    - it reads `Axes turned ${angle.toStringAsFixed(1)}°`.
  - **The end lines** (`dimension-end-1`, `dimension-end-2`) (R-28):
    - an attached end reads `Wall ${wall.toHex()}, ${k == 0 ? 'start' :
      'end'}, ${left face | centreline | right face}`;
    - a fixed end reads `Fixed`.
  - **Read-only** unless `components` and `geometry` are both allowed.
- [ ] **Step 2 — tests** (`dimension_panel_test.dart`), through the
  shell, at `corpusGroups` unless stated.
  - `test('PN1 the Dimension section shows for exactly one dimension, its '
    'value as its text reads', …)`:
    - **Shown for one:** with `dimension-value` equal to the TEXT's
      string (a fractional value in mm, `3451`);
    - **hidden** for none, two dimensions, a dimension and a wall, and a
      wall;
    - **a broken dimension** shows `—`.
  - `test('PN2 a kind click is one undo step that keeps the ends and the '
    'offset; switching back restores the children bit for bit; the '
    'current kind issues nothing', …)`:
    - **The fixture:** aligned over the non-axis pair, offset −617.375.
    - **Clicks:** Horizontal, then Aligned.
    - **Each:** `undoDepth` +1, and the ends and the offset `==` the
      stored ones.
    - **After the round trip:** the children's payload bytes equal the
      first.
    - **A click on Aligned while aligned:** `undoDepth` unchanged.
  - `test('PN3 a linear dimension turned shows Axes turned by the rounded '
    'angle; aligned and unturned show none; 0.04° and −0.04° show none, '
    '0.06° shows 0.1°', …)`:
    - **Turns** of 30° (`Axes turned 30.0°`) and −30° (`Axes turned
      -30.0°`);
    - **none:** aligned at 30°, and horizontal at 0°;
    - **the rounding edges** (S-8): 0.04° shows none; −0.04° shows none
      (its printed string would be `-0.0`, plan-added); 0.06° shows
      `Axes turned 0.1°`.
  - `test('PN4 the end lines read Wall <hex>, start or end, left face, '
    'centreline or right face, or Fixed', …)`:
    - `AttachedEnd(h, 1, right)` reads `Wall ${h.toHex()}, end, right
      face`, for `h` with a hex letter (1A or higher);
    - `AttachedEnd(h, 0, centre)` reads `…, start, centreline`;
    - a fixed end reads `Fixed`.
  - `test('PN5 under runtime permissions the switch is read-only; a refused '
    'edit leaves the switch on the model\'s kind', …)`:
    - **Runtime:** a click issues nothing.
    - **A refusal:** the group is removed under the panel, so the click's
      command throws `StateError`. It is caught, and the switch reads the
      stored kind.
- [ ] **Step 3 — mutants.**

  | mutant | edit | must turn red |
  |---|---|---|
  | M-11kindoffset | a kind switch also sets the offset to `0.0` | `PN2` |
  | M-11sectionmulti | the section shown for two selected dimensions | `PN1` |
  | M-11axesline | the axes line never shown | `PN3` |
  | M-11endlabel | the end lines print `k` swapped (start for end) | `PN4` |
  | M-11panelrw | the switch enabled under runtime | `PN5` |

  **Extras:**
  - `X12-stringTest` (the threshold on `toStringAsFixed(1) != '0.0'`) →
    `PN3` (−0.04°);
  - `X12-sameKind` (a click on the current kind issues a command) →
    `PN2`;
  - `X12-staleValue` (the value cache never dropped) → `PN1`, after a wall
    edit.
- [ ] **Step 4 — ends green** (engine, render, app); packages unchanged.
  The same lines as Task 2's Step 6.

  Commit `feat(app): the Dimension section: value, kind switch, axes, ends (11 D14)`.

### Task 13: Move and rotate; the linear axes (spec D11)

**Spec:** D11 (R-19; decisions 12, 17), D6's offset × scale; the spike's
`Q4`.
**Files:** `test/dimension_rotate_test.dart` (create). Code only if a test
finds a defect; that is a finding (Ruling 11-19).
**Port from:** the spike's `rotate_test.dart` (`Q4a`, `Q4b`, `Q4c`,
`Q4e`).

- [ ] **Step 1 — tests.** Each move and turn is a `TransformNodeCommand`
  on the groups, composed as the select tool composes it: `t ·
  node.transform`, one compound for several groups.
  - `test('DR1 a fixed-fixed pair turned 30° keeps 3000 horizontal and 3231 '
    'aligned, its line at the placement\'s angle plus 30°, at $place', …)`,
    at all six placements (`Q4a`):
    - **The fixture:** (0, 0) and (3000, 1200) in the dimension's group at
      the placement, turned 30° about a far pivot.
    - **The result:** `3000` and `3231`, and the line's world angle is
      the placement's plus 30°, within 1e-9.
  - `test('DR2 an attached end stays with its wall while a fixed end moves '
    'and turns with the group', …)` (`Q4b`):
    - **The fixture:** A/1/left (4000, 100) and a fixed (4000, 3100):
      `3000`.
    - **Moved (700, 0):** `3081`, since √(700² + 3000²) = 3,080.58.
    - **Then turned 37° about (0, 0):** `5617`. The fixed end goes to
      (4700 c − 3100 s, 4700 s + 3100 c) = (1,887.96, 5,304.30), and
      √(2,112.04² + 5,204.30²) = 5,616.53.
    - **The attached end** is within 1e-6 of (4000, 100).
  - `test('DR3 walls and dimensions turned together keep every value', …)`
    (`Q4c`):
    - **The values:** a horizontal `4100`, a vertical `3100` and an
      aligned `3764` (√(2900² + 2400²) = 3,764.3).
    - **Turned 30° together in one compound:** unchanged, and the
      horizontal line is still 800 from A/0/right.
  - `test('DR4 a both-ends-attached linear dimension turned alone turns its '
    'axis: 4000 reads 3464', …)` (`Q4e`): 4000 cos 30° = 3,464.1.
  - `test('DR5 under a turned, translated group scaled 1.5 the world offset '
    'is 1.5 times the stored one and the text is 125 world mm tall', …)`,
    at the corpus far origin:
    - **The group** is built by hand (file only): turned 30°, translated,
      scaled 1.5.
    - **The offset:** the line's world distance from its outermost point
      is 1.5 × 600.5.
    - **The text:** `dimTextGeometry`'s world height is 125 within 1e-9,
      since the stored height is 125 / 1.5.
- [ ] **Step 2 — mutants.**

  | mutant | edit | must turn red |
  |---|---|---|
  | M-11axisworld | `measuringDirection`'s linear axes in world (`(1, 0)`, `(0, 1)`), not `m`'s | `DR1`, `DR3`, `DR4` |
  | M-11fixedworld | a fixed end read without the group transform | `DR2` |
  | M-11attachedmoves | an attached end moved by the group transform | `DR2`, `DR4` |
  | M-11scale | the offset not multiplied by `m.scaleMagnitude` | `DR5` |

  **Re-fire here:** M-11axisworld and M-11fixedworld → `DZ1` (their
  further killer).
  **Extras:**
  - `X13-heightNoScale` (the stored text height not ÷ `s`) → `DR5`.
- [ ] **Step 3 — ends green** (engine, render, app); packages unchanged.
  The same lines as Task 2's Step 6.

  Commit `test(app): dimensions under move and rotate; linear axes are the group's (11 D11)`.

### Task 14: The sample plan (spec D17)

**Spec:** D17 (R-30), decision 15; Rulings 11-13, 11-14, 11-24.
**Files:** `startup_plan.dart`, `test/startup_plan_test.dart`.

- [ ] **Step 1 — the plan** (D17), in `startup_plan.dart`, **after the
  rooms and before `system.dispose()`**:
  - Keep P5's handle, which line 90 drops today.
  - Add a builder method `dimension(DimEnd a, DimEnd b, DimKind kind,
    double offset)`: one compound, a group at the identity, the handle
    allocated inside the build.
  - The five dimensions, in D17's order:

    | dimension | a | b | kind | offset |
    |---|---|---|---|---|
    | the overall width | E1/0/right | E1/1/right | horizontal | −500 |
    | the overall depth | E2/0/right | E2/1/right | vertical | −300 |
    | the Hall | E1/0/left | P1/0/left | horizontal | +900 |
    | the Kitchen | P1/0/right | P5/0/left | horizontal | +900 |
    | the Bath diagonal | E1/1/left | `FixedEnd(x0 + 10300, y0 + 1200)`, the basin's centre (22,300, 9,200) | aligned | `+0.0` |

  - Update the file's header comment.
- [ ] **Step 2 — measure first** (Ruling 11-13). A **temporary printing
  probe**, never committed, prints:
  - `liveCount`;
  - each dimension's stored ends, kind and offset;
  - its TEXT string and world height;
  - its line's world endpoints;
  - its references;
  - `drift()` and `diagnostics()`.

  Paste it into the ledger. Compare it with D17's expectations:
  - 611 entities (581 + 5 × 6);
  - `14.00`, `9.00`, `4.69`, `4.38` and `3.58`;
  - the lines at y 7,500, x 26,300, y 9,150 and y 9,150;
  - heights 125;
  - the references E1; E2; E1 and P1; P1 and P5; E1;
  - both lists empty.

  **If any figure differs, stop and report it with its cause before
  pinning anything.**
- [ ] **Step 3 — tests** (`startup_plan_test.dart`).
  - **`SP1`'s literal** is the measured count, with a comment deriving
    it: 581 + 5 × 6 = 611.
  - **`SP5` extended:**
    - the five dimensions' `DimensionParams`, compared exactly: ends,
      kinds, and offsets (with `compareTo`);
    - `drift()` and `diagnostics()` empty;
    - **plan-added:** every dimension child's handle is above every room
      child's (added after the rooms: draw order).
  - `test('SP8 the five dimensions read D17\'s values at 1:50 m with text '
    '125 high, reference the walls listed, and a click on each line '
    'selects it', …)`:
    - **The values,** with D17's arithmetic in comments: 26,000 − 12,000
      = 14,000; 17,000 − 8,000 = 9,000; 16,940 − 12,250 = 4,690; 21,440 −
      17,060 = 4,380; and √(3,450² + 950²) = √12,805,000 = 3,578.4.
    - **The heights** are 125, and `references` are as listed.
    - **The click:** Ruling 11-24's pick, at a quarter along each line,
      hits a child of that dimension.
  - `test('SP9 the page switched to 1:100 ft-in in one command reads D17\'s '
    'ft-in column at height 250; one undo step; undo restores the metres', …)`:
    - `45'-11 1/4"`, `29'-6 1/4"`, `15'-4 3/4"`, `14'-4 1/2"` and
      `11'-9"`;
    - heights 250, and `undoDepth` +1;
    - undo restores the 1:50 m strings and 125.
- [ ] **Step 4 — the other tests** (Ruling 11-14). Run the whole app
  suite. Any 07, 08 or 10 test that changes its answer because of the
  dimensions is reported with its failing line, **not edited**, until the
  controller rules.
- [ ] **Step 5 — mutants.** None owned (the Mutant assignment's note).
  **Re-fire here:** M-11a → `SP8` (the diagonal reads `3.45` projected on
  x); M-11d and M-11d2 → `SP8` (E1/1/right and every face end).
  **Extras:**
  - `X14-diagonalOnE2` (the diagonal stored on E2/0/left, as the spike
    did) → `SP5`;
  - `X14-beforeRooms` (the dimensions added before the rooms) → `SP5`
    (the handle order);
  - `X14-offsetsSpike` (the spike's 1,200 mm overall offsets) → `SP5`.
- [ ] **Step 6 — ends green** (engine, render, app); packages unchanged.
  The same lines as Task 2's Step 6.

  Commit `feat(app): the sample plan's five dimensions (11 D17)`.

### Task 15: Through the shell — the select tool, the extension-line snap, the renders (spec D19 in the shell, D7's lineweight, D8's height, D11's movability)

**Spec:** D19 (decisions 24, 25), D18's extension-line limit, D11 (R-19),
D7 (R-31; decision 20), D8, `SL1`, `TL9` (S-14), `RR1`–`RR3` (S-11);
Rulings 11-15, 11-16.
**Files:** `test/dimension_shell_test.dart` and
`test/dimension_paint_test.dart` (create).
**Port from:** the spike's `render_test.dart` (its shell capture and the
`R2`, `R2c` probes), with Ruling 11-15's matched capture instead of its
own. The spec's lineweight sweep tests in the scratchpad, if present, show
`RR2`'s frames.

- [ ] **Step 1 — `dimension_shell_test.dart`,** the shell with the
  startup plan.
  - `testWidgets('SL1 through the select tool on the sample plan: a click '
    'on a dimension line selects it; a click on E4\'s face under the '
    'Hall\'s extension line selects E4; a window band around the Hall\'s '
    'line, slashes and text selects it; dimensions move and turn by their '
    'fixed ends only; deleting E1 deletes three dimensions in one step', …)`.
    Each clause is a fresh shell:
    - **Clicks:**
      - on the Hall's line at (14,000, 9,150): the Hall dimension is
        selected;
      - on E4's inner face at (12,250, 8,800), under the Hall's extension
        line: **E4** is selected (decisions 24, 25).
    - **A window band** from (12,050, 9,000) to (17,100, 9,500) takes the
      Hall's line, slashes and text wholly, and cuts its extension lines,
      which reach down to y 8,325. It selects the Hall dimension and
      nothing else. The band's corners are checked against the Hall's
      children by coordinates first (premise).
    - **A body drag of the diagonal:**
      - the fixed end moves by the drag;
      - the attached end stays at E1/1/left;
      - the value is re-read by hand;
      - one undo step.
    - **The Hall selected alone** shows a rotation grip
      (`GripCache.rotatable`).
    - **The walls and their dimensions** (E1–E4, P1, P5 and the five)
      dragged together: every value is unchanged.
    - **Deletion:**
      - one dimension deleted: one step;
      - E1 deleted: the width, Hall and diagonal dimensions go in the
        same step; undo restores them with their handles and strings.
  - `testWidgets('TL9 at 0.3 px/mm with the grid snap off, a hover 5 mm off '
    'the Hall\'s extension line\'s far end gets no object snap and '
    'resolves to the raw point', …)` (S-14):
    - **The setup:** the camera pinned at 0.3 px/mm (a 33.3 mm aperture),
      `snapToGrid: false`, and the Line tool (any `PlacementTool`)
      active.
    - **The hover** at (12,253, 9,254), 5 mm from the far end (12,250,
      9,250): `hoverKind` is null and `hoverPoint` equals the raw point.
    - **Premise:** `index.snapInto(raw, 33.3, kDragSnapMask, …, filter:
      const QueryFilter.rendering())` snaps to (12,250, 9,250).
- [ ] **Step 2 — `dimension_paint_test.dart`,** the shell in `flutter_test`
  with `RenderRepaintBoundary.toImage` at the view's device pixel ratio
  (Ruling 11-15).
  - `testWidgets('RR1 the dimension text is the same world height at 0.15 '
    'and 0.3 px/mm and doubles at 1:100; a slash inks; the extension line '
    'inks from its gap', …)`:
    - **The text:** the Hall's text ink extent above its line, in world
      mm:
      - at 0.15 and 0.3 px/mm at 1:50: 50 to 228.6 mm above the line,
        within two device pixels (the spike's `R2`: 55..230 and 49..227);
      - at 1:100: 100 to 457.1 mm.
    - **A probe on a slash** is ink.
    - **The extension line** is ink from 75 mm (150 at 1:100) below the
      corner to its end, and paper within its gap.
  - `testWidgets('RR2 D7\'s sweep: at 0.25 mm, captured at the view\'s '
    'device pixel ratio, no frame loses an axis-aligned dimension line at '
    '0.052, 0.15 and 0.3 px/mm', …)`:
    - **The sweep:** D7's set-ups 2 and 3, the camera translated by
      k/32 px (k = 0…31) along each axis.
    - **The probes:** the width, depth and Hall lines visible at each
      zoom.
    - **Printed** in D7's form: `lineweight 25 at … (dpr …): frames per
      probe {…}, frames with the line lost {}`. **Asserted:** every lost
      set is empty.
    - **A measurement of record** (S-10): it owns no mutant.
  - `testWidgets('RR3 on Blueprint paper the dimension ink is the '
    'foreground', …)`: with the paper switched to Blueprint, samples on
    the Hall's line and text read the light foreground, not the dark.
- [ ] **Step 3 — mutants.**

  | mutant | edit | must turn red |
  |---|---|---|
  | M-11movable | `DimensionGrips.movable` false | `SL1` (the body drag, the rotation grip) |
  | M-11b-cam | **render layer** (Ruling 11-16): the text's on-screen height fixed at its 0.15 px/mm size. `cp` backup and restore | `RR1` (0.3 px/mm) |

  **Re-fire here:**
  - M-11pickflag → `SL1` (the E4 click selects the dimension; the band);
  - M-11extflag → `SL1`;
  - M-11snapflag → `TL9`;
  - M-11flagdraws → `RR1` (the extension line's ink);
  - M-11b → `RR1` (1:100);
  - M-11colour → `RR3`.

  **Extras:**
  - `X15-bandIgnoresFlag` (the band's `_everyLeafIn` asked with
    `rendering()`): a render-layer site; fire and restore → `SL1` (the
    band).
- [ ] **Step 4 — ends green** (engine, render, app); packages unchanged
  (M-11b-cam and `X15-bandIgnoresFlag` restored and diffed). The same
  lines as Task 2's Step 6.

  Commit `test(app): dimensions through the shell: picks, bands, snaps, renders (11 D7, D8, D11, D19)`.

### Task 16: Mutation testing, invariants and greps

**Part A — the mutants.** Fire every mutant in the spec's table, **75**.
- **The procedure:** the Global constraints' own. Each mutant is run
  against its **full** killer list: the Mutant assignment's right-hand
  column, after Rulings 11-6 and 11-25.
- **The log:** `docs/superpowers/notes/plan-11-mutation-log.md`, in 10's
  format:
  - the mutant and its site (file:line);
  - the edit;
  - the command;
  - the red line, pasted;
  - the restore lines: `diff` exit 0, and `git diff --quiet` exit 0.
- **The command forms:**
  - engine: `(cd packages/jet_cad_2d && CI=true dart test test/index/query_filter_test.dart --plain-name 'QF1')`;
  - app: `(cd apps/floor_planner && CI=true flutter test test/dimension_attach_points_test.dart --plain-name 'AP1')`;
  - engine and render sites against app tests: the app command, with the
    package file mutated (M-11closure, M-11text, M-11b-cam,
    M-11runtime).
- **Where each was first fired:** Tasks 1–15, in each task's table. This
  task **re-fires every one at HEAD**. 10's M-10hover had gone green
  after a later task's cache (10's Task 19), so a kill recorded in an
  earlier task is not trusted until it is re-fired.
- **Multi-site and multi-form mutants** (Ruling 11-18): M-11negzero (two
  forms), M-11colour (two sites), M-11fallback (both steps). Grep for a
  second copy of every other rule before declaring it single-site.
- **Controls:**
  - **The degenerate fixture** is run in a throwaway test that is never
    committed: a horizontal dimension along a free, centred wall at the
    origin, centre to centre, in a group at the identity. Run it under
    M-11a, M-11axisworld, M-11d, M-11d2, M-11swap, M-11attachedmoves and
    M-11fixedworld. Record its green or red lines as the spec's control.
  - **`X2-step1only`** is recorded equivalent with the spec's reason
    (D4, S-2).
- **The tasks' extras** (`X1-…` to `X15-…`) are logged too, from the
  ledger. The ones already fired and pasted are copied, not re-fired.
- **A survivor is a finding:** fix the fixture, never the mutant; re-fire;
  log both runs. "Equivalent" needs a reason and a pasted probe; a
  cost-only survivor is "accepted (cost)" (Ruling 11-18).

**Part B — invariants and greps**, run from the repository root with
`BASE=9774a55` and `T1=<Task 1's last commit>`. On the final tree each
must print what its comment says:

```sh
BASE=9774a55
grep -rnE "^\s*(import|export)\s+.(package:flutter|dart:ui)" packages/jet_cad_2d/lib apps/floor_planner/lib/parametric/dimension_geometry.dart apps/floor_planner/lib/parametric/dimension_attach.dart apps/floor_planner/lib/parametric/wall_geometry.dart apps/floor_planner/lib/parametric/opening_geometry.dart apps/floor_planner/lib/parametric/room_trace.dart apps/floor_planner/lib/parametric/room_label.dart apps/floor_planner/lib/parametric/room_inputs.dart ; echo "exit $?"   # no match, exit 1
grep -nE "^\s*(import|export)\s" apps/floor_planner/lib/parametric/dimension_geometry.dart apps/floor_planner/lib/parametric/dimension_attach.dart   # only dart:, package:jet_cad_2d, package:vector_math and app files that pass the grep above, or import only such files (wall.dart, wall_geometry.dart, opening.dart, opening_geometry.dart, dimension_geometry.dart): read each (Ruling 11-2)
git diff "$BASE" -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants | wc -l   # 0
git diff "$BASE" --stat -- packages/jet_cad_2d/lib                 # style.dart, query_filter.dart, spatial_index.dart, parametric_system.dart only
git diff "$BASE" --stat -- packages/jet_cad_2d/test                # query_filter_test, snap_test, json_codec_test, attributes_test, snap_centre_index_test, support/clients.dart only
git diff "$BASE" -- packages/jet_cad_2d_flutter | wc -l            # 0
git diff "$T1" --stat -- packages/ | wc -l                         # 0
grep -n "EntityFlags.unpickable\|excludeUnpickable" packages/jet_cad_2d/lib -r   # the declaration, the filter's field and presets, the test in acceptsEntity, snapping()
grep -rn "EntityFlags.unpickable" apps/floor_planner/lib            # dimension.dart's extension lines only
grep -rn "Tolerance.standard" apps/floor_planner/lib/parametric/dimension*.dart ; echo "exit $?"   # no match, exit 1
grep -rn "TrueColor" apps/floor_planner/lib/parametric/dimension*.dart ; echo "exit $?"            # no match, exit 1: ByLayer (D7)
grep -rnE "debugDimensionReadsPlaces|readsPlaces|readBox|kDimOffsetPaperMm|kHalfTolerance|kVerticalTolerance|kAttachTolerance|attachMatches|attachAt\b" apps/floor_planner/lib/parametric/dimension*.dart ; echo "exit $?"   # no match, exit 1: the spike's dropped names (rooms keep theirs)
grep -rn "spike_dims\|SPIKE 11" apps packages ; echo "exit $?"     # no match, exit 1
grep -rnE "debugDimensionGenerates\s*(\+\+|\+=|=)" apps/floor_planner/lib   # the declaration and one increment
git diff "$BASE" --stat -- apps/floor_planner/test/wall_*_test.dart apps/floor_planner/test/opening_*_test.dart apps/floor_planner/test/room_*_test.dart apps/floor_planner/test/separator*_test.dart apps/floor_planner/test/support/wall_fixture.dart apps/floor_planner/test/support/opening_fixture.dart apps/floor_planner/test/support/room_fixture.dart apps/floor_planner/test/selection_panel_test.dart apps/floor_planner/test/page_panel_test.dart apps/floor_planner/test/box_test.dart apps/floor_planner/test/planner_box_test.dart apps/floor_planner/test/planner_grips_test.dart | wc -l   # 0, or exactly the edits the controller ruled on (Ruling 11-14)
git diff "$BASE" --stat -- apps/floor_planner/test/planner_shell_test.dart apps/floor_planner/test/planner_draw_test.dart   # empty, or exactly the ruled edits
git rev-list --count "$BASE"..HEAD                                                                                        # N
git log --format=%B "$BASE"..HEAD | grep -c '^Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>$'                  # N
git log --format=%B "$BASE"..HEAD | grep -c '^Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv$' # N
git log --name-only --format= "$BASE"..HEAD | grep -c 'analysis_options.yaml'                                            # 0
```

`N` counts the spec's and the plan's commits too: `9774a55..1fca97a` is
five commits, each carrying both trailers (checked when this plan was
written: 5, 5 and 5). The `Tolerance.standard` and
`TrueColor` greps exit 2 ("No such file") until Tasks 2 and 6 create the
files; the import grep's pattern is checked for a hit on a scratch file
importing `package:flutter/widgets.dart`, as a positive control.

**Also confirm by reading:**
- `lib/jet_cad_2d.dart` exports `EntityFlags.unpickable` and
  `QueryFilter.snapping()` through its whole-file exports (30, 55);
- both allocation invariants pass in the gates;
- every task's ledger entry carries its deferred minors (Ruling 11-18).

Paste each output into the ledger. Commit the log only (`docs(plan-11):
mutation log`). A grep that finds a defect is fixed, with a test, in its
own commit.

- [ ] **Ends green** (all four):

  ```sh
  export PATH=/root/flutter/bin:$PATH
  (cd packages/jet_cad_2d         && CI=true dart test ; CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .)
  (cd packages/jet_cad_2d_flutter && CI=true flutter test ; CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
  (cd apps/dev_harness_2d         && CI=true flutter test --concurrency=1 && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
  (cd apps/floor_planner          && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed . && CI=true flutter build web --release)
  ```

### Task 17: Gates, results, amendments, STATUS

- [ ] Run all four gate lines and paste them with their exit codes, plus
  the printed figures:
  - `AP1`'s worst errors and `AP3`'s worst gaps;
  - `AM1`'s snap kinds and worst gap, and `AM5`'s median;
  - `DF3`'s margins;
  - `DN4`'s counts, and `DZ1`'s `(edits, failures, generates,
    neighbourOnly)`;
  - `TL8`'s time per move;
  - `RR2`'s lines;
  - Task 14's probe (the ledger's copy).

  ```sh
  export PATH=/root/flutter/bin:$PATH
  (cd packages/jet_cad_2d         && CI=true dart test ; CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .)
  (cd packages/jet_cad_2d_flutter && CI=true flutter test ; CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
  (cd apps/dev_harness_2d         && CI=true flutter test --concurrency=1 && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
  (cd apps/floor_planner          && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed . && CI=true flutter build web --release)
  ```
- [ ] Write `docs/superpowers/notes/2026-09-28-plan-11-results.md` in 10's
  shape:
  - what was measured, and the gate transcripts;
  - the mutation tally;
  - the exit-gate table below, filled in;
  - debt, known limits, rulings and spec amendments;
  - the **found** items (Ruling 11-12: a loaded infinite value cannot be
    saved again);
  - the **owed** items: `flutter build macos --release`, the macOS run of
    the gate lines, and criterion 16's look. The look is a checklist of
    ☐ seen, ☐ not seen, ☐ could not judge, per item and platform.
    **Nothing is ticked on the human's behalf.**
- [ ] **Spec amendments,** each an "**Amended at execution (Plan 11)**"
  paragraph under the section it makes precise or departs from. They
  rewrite nothing above them.
  - Rulings **11-1** (Files: `dimension_shell_test.dart`) and **11-2**
    (D1's Files: the value types in the pure file);
  - Ruling **11-6** (M-11snaponly's killer and site);
  - Ruling **11-10** (`AP3`'s bound);
  - Ruling **11-11** (`DO2`'s page);
  - Ruling **11-12** (`DD2`'s file cases);
  - Ruling **11-25** (M-11runtime's site);
  - gate 13's precision: the four `lib` files, and D19's test files;
  - the header's "Amended at execution" line;
  - any ruling made in flight.
- [ ] **The roadmap** (spec, Files):
  - `roadmap/12-app-shell.md` gains two lines under its open questions,
    "**A dimension style table**" and "**A layer for dimensions**", in
    the spec's words;
  - `roadmap/13-export-and-print.md` gains, under "Decisions already
    made": "**The not-pickable bit is not DXF** (11 D19): a DXF export
    writes group code 60 from `EntityFlags.invisible` only and strips
    `EntityFlags.unpickable`";
  - `roadmap/11-dimensions.md`'s status and `roadmap/00-README.md`'s
    table: executed, **not merged**.
- [ ] **`STATUS.md`:** executed, **not merged**. Its debt list gains D7's
  finding on 10's R-17 follow-up: the axis-aligned drop-out was measured
  with a capture below the view's device pixel ratio, so it is
  re-measured with a matched capture before the render layer changes.
- [ ] Commit `docs(plan-11): results, amendments, STATUS`. The final
  whole-branch review follows. The ledger archive is the branch's last
  commit, after it.

---

## Mutant assignment

Each of the spec's **75** mutants belongs to **exactly one** task, where it
is first fired. Task 16 re-fires all of them at HEAD against every killer
listed here.

| task | mutants (first fired against) | the full killer list (Task 16) |
|---|---|---|
| 1 | M-11pickflag (`QF1`), M-11snapflag (`QF2`), M-11flagdraws (`QF1`) | M-11pickflag: `QF1`, `SL1`; M-11snapflag: `QF2`, `TL9`; M-11flagdraws: `QF1`, `RR1` |
| 2 | M-11nbrs, M-11swap, M-11swapjust, M-11fallback, M-11centremid, M-11d, M-11d2 (`AP1`); M-11localring (`AP2`); M-11vertex (`AP3`) | M-11nbrs: `AP1`, `DN1`; M-11swap: `AP1`; M-11swapjust: `AP1`; M-11fallback: `AP1`; M-11centremid: `AP1`; M-11localring: `AP2`; M-11vertex: `AP3`, `AP1`; M-11d: `AP1`, `SP8`; M-11d2: `AP1`, `SP8` |
| 3 | M-11nearest, M-11parallel, M-11lineardir, M-11centrefirst (`AM3`) | M-11nearest: `AM1`, `AM3`; M-11parallel: `AM3`; M-11lineardir: `AM3`; M-11centrefirst: `AM3` |
| 4 | M-11attachtol (`AM1`), M-11snapoff (`AM4`), M-11prefilter (`AM1`, `AM6`), M-11openinghost (`AM6`), M-11hostbox (`AM6`), M-11reachcull (`AM1`), M-11ownerring (`AM2`) | M-11attachtol: `AM1`; M-11snapoff: `AM4`, `TL6`; M-11prefilter: `AM1`, `AM6`, `TL8`; M-11openinghost: `AM6`; M-11hostbox: `AM6`; M-11reachcull: `AM1`; M-11ownerring: `AM2` |
| 5 | M-11e, M-11halfnaive (`DF1`, `DF2`); M-11cmzero, M-11reduce, M-11marks (`DF1`) | M-11e: `DF1`–`DF3`; M-11halfnaive: `DF1`, `DF2`, `DF3`; M-11cmzero: `DF1`; M-11reduce: `DF1`; M-11marks: `DF1` |
| 6 | M-11negzero (`DP1`), M-11a (`DL1`), M-11offsetp0, M-11sign, M-11between (`DL2`), M-11fliptol (`DL4`), M-11flip (`DL3`, `DL4`), M-11textbelow, M-11slash, M-11extpage (`DL3`) | M-11negzero: `DP1`, `DO3`; M-11a: `DL1`, `SP8`, `DZ1`; M-11offsetp0: `DL2`; M-11sign: `DL2`, `TL3`, `GE2`; M-11between: `DL2`, `TL3`, `GE2`; M-11fliptol: `DL4`; M-11flip: `DL3`, `DL4`; M-11textbelow: `DL3`; M-11slash: `DL3`; M-11extpage: `DL3` |
| 7 | M-11b, M-11page, M-11text (`DO2`); M-11lw, M-11colour, M-11extflag (`DO1`); M-11stable (`DL5`); M-11degenerate (`DD1`); M-11broken (`DD2`) | M-11b: `DO2`, `RR1`; M-11page: `DO2`; M-11text: `DO2`, `DN1`; M-11lw: `DO1`; M-11colour: `RR3`, `DO1`; M-11extflag: `DO1`, `SL1`; M-11stable: `DL5`; M-11degenerate: `DD1`; M-11broken: `DD2` |
| 8 | M-11closure (`DN1`, `DN2`, `DZ1`), M-11refs (`DN1`, `DN3`), M-11c (`DN1`, `DN2`, `DZ1`) | M-11closure: `DN1`, `DN2`, `DZ1`; M-11refs: `DN1`, `DN3`; M-11c: `DN1`, `DN2`, `DZ1` |
| 9 | M-11shift, M-11dragside, M-11zerokind, M-11ortho3 (`TL2`); M-11degeneratepair (`TL4`); M-11twosteps (`TL1`); M-11key (`TL7`); M-11snaponly (`TL6`) | M-11shift: `TL2`; M-11dragside: `TL2`; M-11zerokind: `TL2`; M-11ortho3: `TL2`; M-11degeneratepair: `TL4`; M-11twosteps: `TL1`; M-11key: `TL7`; M-11snaponly: `TL6` (Ruling 11-6) |
| 10 | M-11notice (`TL5`) | M-11notice: `TL5` |
| 11 | M-11otherend (`GE3`), M-11gripoffset (`GE2`), M-11gripplace (`GE1`), M-11runtime (`GE4`), M-11previewkind (`GE5`) | M-11otherend: `GE3`; M-11gripoffset: `GE2`; M-11gripplace: `GE1`; M-11runtime: `GE4` (Ruling 11-25); M-11previewkind: `GE5` |
| 12 | M-11kindoffset (`PN2`), M-11sectionmulti (`PN1`), M-11axesline (`PN3`), M-11endlabel (`PN4`), M-11panelrw (`PN5`) | one killer each, as listed |
| 13 | M-11axisworld (`DR1`, `DR3`, `DR4`), M-11fixedworld (`DR2`), M-11attachedmoves (`DR2`, `DR4`), M-11scale (`DR5`) | M-11axisworld: `DR1`, `DR3`, `DR4`, `DZ1`; M-11fixedworld: `DR2`, `DZ1`; M-11attachedmoves: `DR2`, `DR4`; M-11scale: `DR5` |
| 15 | M-11movable (`SL1`), M-11b-cam (`RR1`) | M-11movable: `SL1`; M-11b-cam: `RR1` |

**The total** is 3 + 9 + 4 + 7 + 5 + 10 + 9 + 3 + 8 + 1 + 5 + 5 + 4 + 2 =
**75**, the spec's count:
- **the roadmap's seven:** M-11a (6), M-11b (7), M-11b-cam (15), M-11c
  (8), M-11d (2), M-11d2 (2), M-11e (5);
- **the spike's eighteen:**
  - M-11nbrs, M-11swap, M-11swapjust, M-11fallback, M-11centremid (2);
  - M-11closure, M-11refs (8), M-11text (7);
  - M-11nearest (3), M-11attachtol (4);
  - M-11axisworld, M-11fixedworld, M-11attachedmoves (13);
  - M-11offsetp0, M-11fliptol (6);
  - M-11halfnaive (5);
  - M-11page, M-11lw (7);
- **the fifty new ones.**

Checked name by name against the spec's three tables by a script over the
spec's rows and this table (`plan11-` scratch): **no spec mutant is left
unassigned, and none is assigned twice.**

**Two tasks own no spec mutant:**
- **Task 14** re-fires M-11a, M-11d and M-11d2 at `SP8`: the sample plan
  is their second killer, and its code is data;
- **Task 16** re-fires everything.

**Two killer lists differ from the spec's, by ruling:**
- M-11snaponly: `TL6` only (Ruling 11-6);
- M-11prefilter: `TL8` is added (its centreline hover).

M-11runtime's site is in the render layer (Ruling 11-25). The retired
spike switch (`debugDimensionReadsPlaces`) is not fired.

## Exit gate

The spec's sixteen criteria, and where each is witnessed:

| # | criterion | witness | state |
|---|---|---|---|
| 1 | the four gate lines with `CI=true` on the human's macOS machine; `flutter build macos --release` and `flutter build web --release` | Linux half: Task 17's four lines (only the standing failures) and the web build. **The macOS half: OWED by the human, never simulated** | OWED |
| 2 | every attach point equals its hand value to 1e-6 mm at every placement; the local-ring fallback's points are the drawn corners | `AP1`, `AP2`, `AP3` | |
| 3 | an aligned dimension on a non-axis pair reads the true distance, a linear one its component, at every placement | `DL1`, `DR1`, `SP8` | |
| 4 | editing a measured wall or its neighbour updates every dimension on it in one undo step; undo and redo exact; `drift()` empty; `DZ1` green with neighbour-only rebuilds | `DN1`, `DN2`, `DN4`, `DZ1`, `DO5` | |
| 5 | deleting a referenced wall deletes its dimensions in the same step; undo restores them with their handles | `DN3`, `SL1` | |
| 6 | values format per unit, half-up at an exact half despite binary floating point; `345.0`, reduced fractions, `'` and `"` in feet-inches only | `DF1`, `DF2`, `DF3` | |
| 7 | the text is 2.5 paper mm at two camera scales and two page scales, centred above its line, readable from the bottom or the right, upward at exactly vertical | `RR1`, `DL3`, `DL4`, `DO2` | |
| 8 | a page change regenerates every dimension in one step; a paper change regenerates none | `DO2`, `SP9` | |
| 9 | save → load → save byte-identical; references intact; `drift()` empty after load | `DO3`, `DP1`, `QF3`, `DZ1` (the reload) | |
| 10 | linear axes are the group's: rotating a plan keeps every value, a linear dimension rotated alone turns its axis, and the panel says so | `DR1`–`DR4`, `PN3` | |
| 11 | the tool (I), its grips and its section behave as D10–D14 say, decisions 19, 22 and 23 included | `TL1`–`TL8`, `GE1`–`GE5`, `PN1`–`PN5`, `AM1`–`AM6` | |
| 12 | the dimension lines are 0.25 mm, and `RR2`, captured at the view's device pixel ratio, shows no drop-out at the look's zooms | `DO1`, `RR2` | |
| 13 | the engine and render suites green, `QF1`–`QF4` among them; `packages/` differs from `9774a55` only in D19's four engine files (and their tests); the render layer's diff empty; the allocation invariants pass unedited | Task 1's Step 10, Task 16's greps, the gates | |
| 14 | the sample plan is D17's: five dimensions with their values, 611 entities, `drift()` and `diagnostics()` empty | `SP1`, `SP5`, `SP8`, `SP9` | |
| 15 | every named mutant killed and logged in `plan-11-mutation-log.md` (M-11b-cam fired in the render layer and restored; M-11fallback as redefined); `roadmap/12` carries its two lines and `roadmap/13` its one | Task 16's log; Task 17's roadmap edits | |
| 16 | **the human's look**, on macOS, in Chrome and in Firefox (the spec's list: the tool's clicks, preview, Shift, rings and status value; the five sample dimensions at 1:50 and 1:100 on White and Blueprint; 0.25 mm beside the walls; the slashes, the text's size and side; wall moves, joints breaking, deletion, undo; rotating the plan and one linear dimension alone; the grips and a grid drop on a corner; the section; the accepted collisions; a click on a face under an extension line and on a dimension line) | **OWED by the human, never simulated** | OWED |

## Self-review

- **Every decision maps to a task:**

  | decision | task |
  |---|---|
  | D1 | 1 (engine files), 2–7 (the app files), 16 (greps) |
  | D2 | 3 (the end types), 6 (params, JSON, `==`) |
  | D3 | 6 (reach, references, page key), 7 (`DO2`), 8 (cascade, `DN3`) |
  | D4 | 2 |
  | D5 | 8 |
  | D6 | 3 (`measuringDirection`), 6 (the value, heights, offset, `offsetFor`), 13 (the scale) |
  | D7 | 6 (the children's geometry), 7 (the records, `DO1`), 15 (`RR2`) |
  | D8 | 6 (`readable`, placement), 7 (height, `DO2`), 15 (`RR1`) |
  | D9 | 5, 7 (`DF3`) |
  | D10 | 3 (the choice), 4 (the candidates), 9 (at the commit), 11 (at a drop) |
  | D11 | 11 (`movable`), 12 (the axes line), 13, 15 (`SL1`) |
  | D12 | 9, 10 |
  | D13 | 11 |
  | D14 | 12 |
  | D15 | 7 |
  | D16 | 7 (`DO3`–`DO5`), 8 (`DN3`) |
  | D17 | 14 |
  | D18 | known limits: Ruling 11-19; `SL1` (the extension line's click) |
  | D19 | 1 (engine), 6 (the flag on add), 7 (`DO1`), 15 (`SL1`, `TL9`, `RR1`) |

  Decisions 1–25 reach the tasks through the D-sections that cite them:
  - 19's timing is superseded by 22 (Tasks 9 and 11);
  - 23 is in Tasks 4 and 9;
  - 24 and 25 are in Tasks 1, 6, 7 and 15.
- **Every one of the spec's tests has a home.**

  | tests | task |
  |---|---|
  | `QF1`–`QF4` | 1 |
  | `AP1`–`AP3` | 2 |
  | `AM3` | 3 |
  | `AM1`, `AM2`, `AM4`, `AM5`, `AM6` | 4 |
  | `DF1`, `DF2` | 5 |
  | `DP1`, `DL1`–`DL4` | 6 |
  | `DO1`–`DO5`, `DF3`, `DL5`, `DD1`, `DD2` | 7 |
  | `DN1`–`DN4`, `DZ1` | 8 |
  | `TL1`–`TL4`, `TL6`, `TL7` | 9 |
  | `TL5`, `TL8` | 10 |
  | `GE1`–`GE5` | 11 |
  | `PN1`–`PN5` | 12 |
  | `DR1`–`DR5` | 13 |
  | `SP1`, `SP5`, `SP8`, `SP9` | 14 |
  | `SL1`, `TL9`, `RR1`–`RR3` | 15 |

  That is 66 of 66. The Differential check is `DZ1`'s oracle and reload,
  `TL5`, `GE5`, and "`drift()` empty after every edit", required of
  every relational test. The recorded measurements (S-10) are `RR2`,
  `AM5`, `TL8`'s time and `DN4`'s counts; the carried gate pins are
  `DO4`, `DO5` and `SP1`.
- **Every mutant has one task and a named killer** (the table above),
  checked name by name against the spec's three mutant tables: 75 of 75.
- **The engine change against the frame path:**
  - `acceptsEntity` gains one bool test for `rendering()`, allocates
    nothing, and looks up no map;
  - the allocation invariants are run on their own in Task 1 and in
    every gate, unedited;
  - the render layer is unchanged, checked by a diff in Tasks 1, 16 and
    17.
- **10's ledger, applied:**
  - **tasks added in flight** (14b, 14c): Ruling 11-19. The fuzz and the
    brute-force oracles land early (Tasks 2–4 and 8), where 10 found
    defects late;
  - **the hover's cost** found by a reviewer (10's Task 15): Ruling
    11-21, `TL8`'s counters, and the time read before review;
  - **caches and the asynchronous `DocChange`** (10's Task 9 m-3, and
    `RN2`'s two pumps): Ruling 11-8;
  - **a click rebuilding its inputs three times** (10's results): `TL8`
    asserts two searches per commit;
  - **degenerate fixtures found by reviewers** (10's rv13-otherLocal, a
    room at the identity): every relational test places the
    **dimension's own group** off the identity (the Global constraints);
  - **the plan's own numbers wrong** (10's `TT5`'s 30 px, `SD4`'s
    premise, X4-order, X11-canonical): every aperture is stated as
    arithmetic, every premise asserted, and a wrong plan number is
    reported, not adjusted silently;
  - **the audit's reclassified "equivalents"** (10's Task 19): Ruling
    11-18's log words, and every mutant re-fired at HEAD;
  - **a kill lost to a later change** (10's M-10hover): Task 16 re-fires
    everything;
  - **scratch files overwritten, carried minors dropped:** Ruling 11-18
    (unique prefixes, the verbatim carry);
  - **whole-pixel captures** (10-28) and **captures below the view's
    ratio** (D7): Ruling 11-15;
  - **a cache holding non-live components** (08 m5): Ruling 11-4's live
    rule;
  - **a handle predicted** (08's Task 10): `X9-predict`;
  - **a test file imported from another** (10's Task 14 m-r1): Ruling
    11-22.
- **What the spec left open and this plan rules:**
  - 11-1: the files for `SL1` and `TL9`;
  - 11-2: where the value types live;
  - 11-3: one layout;
  - 11-4: the attach API, `T` in world, the rigidity test;
  - 11-5: `decideEnd`'s inputs;
  - 11-7: `AM6`'s tool clause;
  - 11-8: the caches;
  - 11-9: the tool's world-axis placements;
  - 11-16 and 11-25: the render-layer mutant sites;
  - 11-21: the hover's budget handling;
  - 11-22 and 11-23: the fixtures;
  - 11-24: `SP8`'s click.
- **What the spec states that the plan could not follow as written,**
  each ruled:
  - 11-6: M-11snaponly cannot be killed by `AM4`;
  - 11-10: `AP3`'s 1e-9 mm cannot hold at +1e9 mm;
  - 11-11: `DO2`'s "1:50 m … restores `4000`";
  - 11-12: a NaN cannot come from a file;
  - 11-25: M-11runtime has no app site.
