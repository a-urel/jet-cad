# Openings — design

**Date:** 2026-09-25. **Status:** design, **revision 1**. Not reviewed: the
human skipped the spec review, as for 07 (decision 14). **Amended the same
day by the controller's ruling on open question 1** (R1: a gap's threshold
line replaces its jamb lines; D10, D11, D12, the tests and the mutant
table). The other thirteen open questions were accepted as written.
**Sub-project:** `roadmap/08-openings.md`. **Size:** M.
**Branch:** `spec-08/openings`, cut from `main` at `357bea6`; this revision
is written on top of `11f26bc` (the spike's findings note).
**Depends on:** 06 (merged at `a6837d0`), the parametric layer, and 07
(merged at `63c3878`, fixed by `fix/post-07` at `1ae83f9`), walls.
**Blocks:** 10 (rooms and area). 09 (the symbol library) becomes a later,
soft dependency (D1).
**Brainstormed with the human on 2026-09-25**, on `main` at `357bea6`,
followed by a throwaway spike whose findings are the evidence for most
decisions below:
[2026-09-25-openings-spike-findings.md](../notes/2026-09-25-openings-spike-findings.md)
(branch `spike/08-openings`, head `634fa7c`, never merged). Its renders are
in [2026-09-25-openings-spike/](../notes/2026-09-25-openings-spike/).

**Inputs read for this revision:** `CLAUDE.md`; `STATUS.md`;
`roadmap/08-openings.md` and `roadmap/00-README.md`; the brainstorm's
decision record (below); the spike note and the spike's code
(`packages/jet_cad_2d/lib/src/parametric/*`,
`apps/floor_planner/lib/parametric/{opening,wall,wall_geometry,catalog}.dart`,
`apps/floor_planner/test/spike_openings/*`); spec 06
([2026-09-24-parametric-layer-design.md](2026-09-24-parametric-layer-design.md));
spec 07 ([2026-09-24-walls-design.md](2026-09-24-walls-design.md)); the
Plan 07 results note
([2026-09-24-plan-07-results.md](../notes/2026-09-24-plan-07-results.md));
the fix/post-07 note
([2026-09-25-fix-post-07.md](../notes/2026-09-25-fix-post-07.md)).

**Decisions the human made on 2026-09-25**, numbered as in the brainstorm
record (1–14 before the spike, 15–19 after it), and the controller's
technical rulings R1–R4 (R1 as amended by the controller on 2026-09-25, on
this spec's open question 1):

| # | Question | Answer | Here |
|---|---|---|---|
| 1 | Where the symbol comes from | **Generated** by the opening's own regeneration; 09 stays a later, soft dependency | D1, D10 |
| 2 | How an opening reaches its wall | **Explicit engine references:** a `ParametricType` declares the handles its parameters reference; the closure adds referrers and referents. The opening is its own object | D2, D3 |
| 3 | How the wall is cut | **Split the band** into pieces between its openings, a 1-D split along the straight wall; openings stay clear of the corner caps; the wall's child count varies | D7, D9 |
| 4 | An opening that does not fit | **Keep the stored position; draw clamped** into the straight part; if nothing is wide enough, the wall is uncut and only the symbol shows; `diagnostics()` names it. No edit refused, nothing lost | D8, D11, D17 |
| 5 | Host deleted | **Cascade in the engine, generically,** in the same edit (one undo step), whatever deleted the host | D4 |
| 6 | Overlapping openings in one wall | **Allowed;** the wall cuts the union; both symbols drawn; `diagnostics()` names it | D8, D17 |
| 7 | Types in v1 | **Single-leaf door** (width, hinge end, swing side), **window** (width), **plain gap** (width); all carry host and position. No sill or head height | D6 |
| 8 | Tools | **One per type:** Door **D**, Window **N**, Gap **G**; width in the Selection panel's tool-settings; hover preview; one click on a wall places it centred at the click; a door's swing side is the clicked side, its hinge the nearer end | D14 |
| 9 | Editing | **Selection panel** (width, position; door: flip hinge, flip swing) **and one slide grip** at the centre, clamped to the wall; select-tool move and rotate **not offered** | D16 |
| 10 | Snapping | The existing object snap (F3) and grid, **projected onto the wall's centreline**, plus that wall's straight-part ends and the other openings' edges | D15 |
| 11 | The sample plan | **Rebuilt with 07 walls and 08 openings** at the same places; its tests carried over | D18 |
| 12 | Rotate about a chosen base point | **Its own follow-up branch** after 08, extending 03; not here | Non-goals |
| 13 | Symbol colour | **ByLayer on layer 0** (follows the paper since fix/post-07); walls stay concrete black | D10 |
| 14 | Process | Spike first (throwaway); spec review skipped, like 07 | this header |
| 15 | Position | **Distance from the wall's start;** a wall **end** dragged by its grip rewrites its openings' positions in the same edit so they stay put; they move only when the wall moves or rotates as a whole | D6, D13 |
| 16 | The centreline across a doorway | **Split with the band:** one open polyline per piece | D9 |
| 17 | The no-fit symbol | **Drawn just outside the wall's face,** never over the band; `diagnostics()` names it | D11 |
| 18 | Obstacles | Another wall's **T butt or crossing** inside the straight part **splits it into stretches;** an opening clamps into the stretch nearest its position; if none is wide enough it is no-fit | D7, D8 |
| 19 | What a deleted referent does to its referrers | **A policy per type:** `cascade` (openings) or `orphan` (kept, regenerated, reported; for 10's rooms) | D4 |
| R1 | Gap selectability | **Amended** (controller, 2026-09-25, spec open question 1). Was: two jamb lines. Now: a gap generates **one threshold line** (ByLayer, layer 0) along the host's centreline inside the gap, **inset from each jamb**, so it never touches a piece; a no-fit gap draws it outside the left face like a no-fit window. Doors and windows need no extra child | D10, D11, D12 |
| R2 | Overlap reporting | `opening.overlap` **once per pair, by the lower handle** | D17 |
| R3 | M-08a | **Structural:** a parameter-type swap fired on a scratch copy against the far-move test | Mutant table |
| R4 | Debt from the spike | A bare `RemoveNodeCommand` of a wall's node leaves its leaves with a dead owner (06, pre-existing); paste/import must remap stored handles; the references map costs O(n) per survey and is **measured** | D2, Non-goals |

**Where this spec had to interpret a decision,** it says so in the decision
and again in [Open questions](#open-questions). Nothing above is silently
changed.

**Evidence of record.** Every claim about what exists was read from the
tree at `11f26bc` on 2026-09-25 (`main` at `357bea6` plus one note), or from
the spike branch at `634fa7c` where marked. Each item gives its file and
line.

- **06's planner** (`packages/jet_cad_2d/lib/src/parametric/regeneration.dart`):
  - `_survey` (74-98) collects the live objects, one `reach` per object,
    the children and the set G; neighbours are computed on demand and
    memoised (`neighboursOf`, 51-71), counting `debugOverlapTests` (22);
  - `_closure` (103-108) is **spatial only**: the seeds and their
    neighbours before and after, one hop;
  - `_run` (285-376): survey, `inner`, the D6 guard `_refused` (255-270),
    then — inside one `try` — the after-survey, `lost`, the D8 `cleanup`,
    the seeds and `_plan`; then the hand-rolled apply loop and the
    `ParametricReplay` inverse;
  - `_plan` (166-242) matches regions through their fills, then plain
    children by `(kind, ordinal)`; added children get reserved handles above
    the seed; surplus children are removed from the end of each kind's
    ascending list.
- **`ParametricType`** (`parametric_system.dart:22-42`) has `editCapability`,
  `reach`, `generate`, `diagnose`; **`ParametricView`** (100-114) offers
  `paramsOf`, `toWorld`, `neighbours`. `diagnostics()` (206-231) reports
  `parametric.misplaced` and each object's `diagnose`. The fast path
  (`_expand`, 233-243) skips the wrapper when no parametric component
  exists and the command sets none.
- **The engine's `validate()`** (`packages/jet_cad_2d/lib/src/document/validate.dart:42`)
  reports structural problems only; it does not know which component types
  are parametric (06 D5), so it cannot know what a component references.
- **Walls** (`apps/floor_planner/lib/parametric/`):
  - `wallJoin = Tolerance(linear: 1e-6, angular: 1e-9)` (`wall.dart:17`),
    `mitreLimit = 4` (30), `kWallColor = TrueColor(0x000000)` (41);
  - `WallType.generate` (183-196): one region and one centreline;
  - `classify` (`wall_geometry.dart:188`) and `cap` (255): a `Tee` cap
    meets the through wall's near face, or squares at the stem's own point
    past the mitre limit (262-277);
  - `WallGrips` (`wall_grips.dart`): two `stretch` grips; `drag` returns one
    `CompoundCommand` of `SetComponentCommand<WallParams>` for the dragged
    end and every end within `wallJoin.linear` of it.
- **The render layer** (`packages/jet_cad_2d_flutter/lib/src/`):
  - `ObjectGripProvider` (`grip_cache.dart:29-43`): `gripsOf`, `drag`,
    `preview`; `GripCache` holds **one** optional provider (178) and asks
    it for every selected root-level group (294-326); `rotatable` is
    `_box != null` (225);
  - `GripDrag.move` and `GripDrag.rotate` (`grip_drag.dart:63-81`) capture
    every selected node and write `TransformNodeCommand(t · node.transform)`
    (305); a press on a selected body starts a move
    (`select_tool.dart:215-222`);
  - pick ties go to the **greater** handle, the later drawn
    (`packages/jet_cad_2d/lib/src/index/spatial_index.dart:63-70`).
- **The app:**
  - tool keys V L P R B W C A T and F, F3, cmd/ctrl+Z are taken
    (`main.dart:116-175, 297-310`; `shortcut_guard.dart:5-15`); **D, N and
    G are free**;
  - the grip cache is built with `objects: WallGrips()` (`main.dart:193`);
  - `installParametric(_document)` runs in `initState` after
    `startupPlan`, which "builds its document with no parametric object"
    (`main.dart:263-265`);
  - the startup plan (`startup_plan.dart`) draws walls as double lines,
    seven doors as two jambs + a leaf + a quarter arc and eight windows as
    three lines, all in concrete colours; its tests (`startup_plan_test.dart`)
    pin 509 entities (`SP1`), furniture fills over finishes (`SP2`), door
    leaves and swings clear of furniture (`SP3`), 900 mm doorway approaches
    (`SP4`) and "no parametric object" (`SP5`);
  - Selection panel fields use `PanelFieldFocusNode.handBack` on Enter and
    on a tap outside (`panel_focus.dart`, fix/post-07 F3).
- **The spike** (`spike/08-openings` at `634fa7c`): `ParametricType.references`
  (`parametric_system.dart` +12), the survey's `references`/`referrers`,
  the two-hop closure and `_cascade` (`regeneration.dart` +114 −12);
  `opening.dart` (301 lines); `capsOf` (`wall_geometry.dart` +19).

## What this delivers

1. **Doors, windows and gaps hosted in walls.** An opening is its own
   parametric object that stores its host wall's handle and a position
   along the host's centreline. It cuts the host's band and centreline, and
   draws its symbol: a leaf and a quarter swing for a door, three lines for
   a window, an inset threshold line for a gap. It moves with its wall, is deleted
   with it, and stays out of the wall's corners and out of other walls'
   T butts and crossings.
2. **Three tools:** Door (**D**), Window (**N**) and Gap (**G**). One click
   on a wall places one opening.
3. **An Opening section in the Selection panel** (width, position, and for
   a door flip hinge and flip swing) **and a slide grip.**
4. **Wall end grips that keep openings put** in the world.
5. **The sample plan rebuilt** with 07 walls and 08 openings at the places
   its double lines and loose symbols occupy today.
6. **Engine changes to 06's mechanism:** explicit **references** between
   parametric objects, a closure that follows them, and a **per-type
   policy** for a deleted referent (cascade or orphan), all generic.

## Non-goals

- **Rotate about a chosen base point** (decision 12). It is a general
  transform feature extending 03 and gets its own branch after 08.
- **Library symbols** (09). The symbol is generated (D1). Swapping in
  library symbols needs the planner to generate `InstanceNode`s, which it
  cannot (spike, "Consequences for 09").
- **Rooms** (10). Rooms must derive from the **uncut** faces and
  centrelines, or they leak through doorways; 10 uses the `orphan` policy
  (D4) and is a referrer.
- **Sill and head heights, double doors, sliding doors, opening
  colours or layers.** None in v1. A later field arrives as an optional
  JSON key with a default.
- **Openings in curved walls** (07 has none) and **openings inside
  definitions or instances** (06 D5: parametric objects are root-level).
- **Handle remapping on paste, import, block explode or file merge**
  (R4). No such path exists in the app today; any future one must remap
  `OpeningParams.host` through `ParametricType.references` or a sibling
  hook. Recorded, not built.
- **The pre-existing bare-`RemoveNodeCommand` debt** (R4, spike finding
  3): a bare `RemoveNodeCommand` of a wall's node leaves the wall's own
  generated leaves with a dead owner. 06 D6 allows a node removal, and only
  the select tool's compound removes the leaves. 08's cascade removes a
  **referrer's** leaves itself (D4), so it is stricter for referrers than 06
  is for the deleted object. Fixing 06's side is out of scope.
- **A per-object draw pass** (06 D12's question). D12 keeps "a symbol never
  overlaps its host's pieces" instead.
- **Moving an opening onto another wall.** No tool or grip changes an
  opening's host. A `SetComponentCommand` can (D5 governs it); the UI does
  not offer it.

## Decisions

### D1 — Where openings live, and where the symbol comes from

- **The opening type is application code,** like 06's Box and 07's Wall,
  in `apps/floor_planner/lib/parametric/`. What the engine gains is
  generic: references and a delete policy (D2–D5). Nothing in the engine
  knows what an opening is.
- **The symbol is generated** by the opening's own `generate` (decision 1).
  Every door looks the same; that is accepted for v1. 09 does not block 08,
  and 08 does not block 09.
- **Files:**
  - `opening.dart`: `OpeningParams`, `OpeningKind`, `HingeEnd`,
    `SwingSide`, `OpeningType`;
  - `opening_geometry.dart`: pure functions, **no Flutter import** — the
    host frame, obstacles, stretches, cuts, pieces, symbols;
  - `opening_tool.dart` (one class, three instances), `opening_grips.dart`
    (the slide grip), `object_grips.dart` (the composite provider, D16);
  - `wall.dart`, `wall_geometry.dart`, `wall_grips.dart`: amended (D9, D13);
  - `catalog.dart`: registers `OpeningParams` with `OpeningType`.
- **Why an opening is its own object** (decision 2), not a list inside
  `WallParams`: it selects, deletes and diagnoses as one thing, its symbol
  lives in its own group, and a door is one object (the human's look on
  2026-09-24: an arc rotated without its leaf).

**Pinned by:** nothing directly: D1 is a layout. `opening_geometry.dart`'s
pure-Dart rule is checked by the invariants' import grep (07's Task 10 grep,
extended).

### D2 — References in the engine

- **`ParametricType<T>` gains:**

  ```dart
  /// The objects [params] reference (an opening: its host). An edit of a
  /// referent regenerates its referrers, and an edit of a referrer
  /// regenerates its referents (D3). Default: none.
  Iterable<Handle> references(T params) => const [];

  /// What happens to a live object of this type when an object it
  /// references stops being a live object (D4). Default: cascade.
  ReferencePolicy get referencePolicy => ReferencePolicy.cascade;
  ```

  `enum ReferencePolicy { cascade, orphan }` is exported with it.
- **The survey** gains two maps, built in **one pass** over the live
  objects in ascending order:
  - `references`: object → its **live** referents, ascending, deduplicated,
    self excluded. A referenced handle that is not a live parametric object
    (a deleted wall, a plain group, a leaf) is left out here; D5 decides
    what that means;
  - `referrers`: referent → its live referrers, ascending (the pass walks
    in ascending order, so the lists come out sorted).
  Both are unmodifiable, like the neighbour memo.
- **`ParametricView.referrers(Handle h)`**: ascending handles of the live
  objects whose `references` name `h`. A wall lists its openings through
  it. It reads the survey the view was built over: the after-survey in an
  edit, a full survey in `drift()` and `diagnostics()`.
- **Cost: O(n) per survey, twice per edit** — one `references` call per
  live object, including for an edit that touches no object (a plain line
  drawn among walls). 07 D10 made neighbours free for such an edit;
  references are not (spike finding 8, R4). **Measured and pinned:**
  - `@visibleForTesting int debugReferenceCalls`, counted per `references`
    call, never reset by the library;
  - `RC1`: a root line drawn among 300 walls and 300 openings performs
    **exactly 2 × 600** `references` calls and **0** overlap tests;
  - `RC2`: 06's NC4 method (JIT, median of five, printed, not asserted) for
    a line draw and a wall move at 100, 300 and 600 walls, each wall with
    one opening, recorded in the results note next to 07's NC4 figures.
- **Why a declared method, not a scan of components for handle-typed
  fields:** components are opaque to the engine (`component.dart:12`), and
  the type is the only place that knows which of its values are handles.

**Costs:** one `references` call per object per survey, O(n), twice per
edit. **Pinned by:** `RF1`, `RC1` (M-08n); the view's `referrers` by `OR1`,
`OR3`.

### D3 — The closure follows references, with one extra hop

06 D4 step 6's closure was the seeds and their spatial neighbours before and
after. It becomes (spike, "The rules that survived", rule 1):

```
core    = seeds
        ∪ neighbours_before(seeds) ∪ neighbours_after(seeds)
        ∪ references_before(seeds) ∪ references_after(seeds)
closure = core ∪ referrers_before(core) ∪ referrers_after(core)
```

restricted to live objects after the edit and sorted ascending, as before.
Neighbours are still asked for the seeds only (07 D10); references and
referrers are map lookups.

- **Why the referent direction** (`references(seeds)`): the wall's
  geometry depends on its openings, so editing a door must regenerate its
  wall. This is the roadmap's "dependency edge points the wrong way" (its
  decision 3). Without it: M-08d (spike: `drift()` is `[1300]`, the wall,
  right after the door is added).
- **Why the referrer direction:** an opening's reach is empty (D10), so no
  spatial relation brings it into a moved wall's closure. A wall moved
  60 m leaves its openings stale without it (M-08r2, spike Q1a: `[4000,
  4100]`).
- **Why referrers of the whole core, not of the seeds only.** A referrer
  reads more than its referent's parameters: it reads the referent's
  **joints**, which read the referent's spatial neighbours. The spike's
  counterexample (Q1d): wall A 200 centre runs into a node that B 115 left
  runs out of, at 67°; a door in A is stored at 2,700 so that it is drawn
  clamped against A's mitre. Swinging B's far end changes A's mitre, so A's
  straight span, so where the door is drawn. The door is neither B's
  referrer nor B's referent; it is two hops from B. With referrers of the
  seeds only (M-08t): `drift()` is `[4000]`, the door.
- **Why this is closed for 08's types.** A door reads its own parameters,
  its host's, and its host's wall neighbours' (joints and obstacles, D7). A
  wall reads its own, its wall neighbours' and its openings'. Any change to
  any of these seeds an object whose one-hop core holds the door's host, and
  the door is that host's referrer. **The other direction needs nothing
  more:** B never reads A's openings, so editing A's door never needs B
  (spike Q1e: `drift()` empty, B's children byte for byte unchanged). The
  obstacle rule (D7) reads only the host's own neighbours, so it adds no
  hop.
- **Cost of the rule** is a larger closure for a wall edit (every
  neighbour's openings regenerate). A floor plan's walls carry a handful of
  openings each; it is not measured separately (RC2 covers the edit).
- **A future type** that reads further than one referent's neighbours needs
  its own argument. 10's rooms read their walls' joints: the same two-hop
  shape, covered by this rule only if rooms are referrers of their walls.

**Costs:** a larger closure for a wall edit (its neighbours' openings).
**Pinned by:** `RF2`–`RF5`, `OR1`, `OR3`, `OR4`; M-08d, M-08r, M-08r2,
M-08t.

### D4 — A referent that stops being an object: cascade or orphan

**When it applies.** An object X **stops being a live object** in an edit
when it was one before `inner` applied and is not one after: its node was
removed (the select tool's delete, a bare `RemoveNodeCommand`), its
component was detached, or its group stopped being root-level (06 D5).

> **Interpretation.** Decision 5 says "deleted". The spike cascaded only
> on a removed node. This spec cascades on every way of stopping being an
> object, so that an opening never survives a host that turned into a
> plain group and draws nothing. No UI path detaches a wall's component or
> re-parents it; only a hand-built command does. See Open question 6.

**The policy is the referrer's type's** (`ParametricType.referencePolicy`,
decision 19):

- **`cascade`** (openings): each live referrer, before the edit, of an
  object that stopped being one is **deleted in the same edit**, as the
  select tool deletes a group: its leaves (a fill whose boundary goes too is
  skipped, since the boundary's removal takes it), then its node.
  Transitively: a referrer so deleted is itself an object that stopped
  being one, and its own cascade-policy referrers follow, until none is
  left. Doomed objects are processed in ascending handle order per round.
- **`orphan`** (none in 08; 10's rooms): the referrer is **kept.** It is in
  the closure by D3 (a referrer, before the edit, of a seed), so it
  **regenerates in the same edit**. Its `generate` sees `paramsOf(host) ==
  null` and decides what to draw. After the edit its `references` still
  name the dead handle, which the survey leaves out (D2), so it is nobody's
  referrer through it. `diagnostics()` reports it (`parametric.orphan`,
  D17).

**Where the cascade runs in `_run`** (spike rule 2): **after 06 D6's guard,
before the after-survey.** The new order of 06 D4's steps:

1. `before = _survey(…)` — now with references and referrers;
2. `r0 = inner.apply(t)`;
3. the D6 guard on `r0.touched`, unchanged; a refusal undoes `r0` and
   throws `GeneratedGeometryError`;
4. **the cascade.** It computes the doomed set from `before.referrers` and
   the tree, applies its removals **one command at a time**, as `_run`'s
   regeneration loop does (so a child's refusal and a failed rollback stay
   apart, the 06 debt comment's reason), and repeats until nothing more is
   doomed. It returns `r`: `r0` extended by the removals, whose inverse is
   `Compound([cascade inverses, reversed…, r0.inverse])` and whose
   `touched` is the union. A failure undoes what the cascade applied, then
   `r0`, and rethrows; a failed rollback throws 06's "partially mutated"
   `StateError` and undoes nothing more;
5. inside 06's `try`: the after-survey, `lost`, the D8 `cleanup`, the
   seeds, **D5's dangling-reference check**, the closure (D3) and `_plan`.
   Any failure here applies `r.inverse`, **which includes the cascade's**,
   so a refused plan leaves the document byte for byte as it was;
6. the apply loop and the `ParametricReplay` inverse, unchanged.

**Why there and not later** (spike rule 2):
- The after-survey never sees a doomed referrer, so the plan never
  generates it.
- `lost` picks each cascaded referrer up by itself (its node is gone), so
  06 D8's cleanup detaches its component, and it seeds the closure like any
  deleted object. Nothing in steps 5–6 is new code for the cascade.
- Without the cascade (M-08f0) the orphaned door is still in the closure as
  a before-referrer of the deleted wall; its `generate` finds no host and
  returns nothing, so the planner strips its children and leaves a
  **childless group** (06's ghost): `Expected: null Actual:
  GroupNode(FA0, 0 children)`.
- A cascade executed as its own command after the edit (M-08f) is two undo
  steps: spike Q2a, `Expected: <5> Actual: <6>`.

**Undo, redo and handles.** Undo replays the concrete inverse (06 D4): it
restores the wall's node, component and children, and each cascaded
opening's node, component and children, **with the same child handles**
(spike Q2a: all four objects' child handles equal after undo, after redo,
and after undo then `purge()`). The root's child order is compared
normalised, 06's convention (`RemoveNodeCommand`'s inverse re-links at the
end).

**Permissions.** The cascade is derived geometry and inherits the
triggering edit's authority (06 D7). A delete needs `structure` and
`geometry`, which already cover removing nodes and entities; runtime denies
both, so a runtime delete is refused at `_require` before anything runs.

**Costs:** the cascade is new code inside `_run`'s rollback path, and every
failure path must now undo it too. **Pinned by:** `CS1`–`CS5`, `OR5`, `OR6`;
M-08f, M-08f0, M-08f2, M-08v.

### D5 — Dangling references: refused on edit, reported on load

A **dangling reference** is a handle an object's `references` name that is
not a live parametric object.

- **An edit cannot create one for a `cascade` object.** After the
  after-survey, every **seed** that is a live `cascade`-policy object must
  have every referenced handle live in `after`; otherwise the edit is
  refused: `r.inverse` is applied (cascade included) and
  `DanglingReferenceError(object, referent)` is thrown. It propagates like
  `GeneratedGeometryError`; the dispatcher pushes nothing and emits nothing.
  This is what a `SetComponentCommand<OpeningParams>` naming a line, a
  plain group or a deleted handle as host meets. The UI never builds one.
  **Only seeds are checked**, so an unrelated edit never trips over a bad
  object elsewhere. `orphan` objects are never refused: dangling is their
  normal state after a delete.

  > **Interpretation.** The decisions do not mention this refusal. It is
  > the backstop that makes decision 5's promise ("an opening never
  > outlives its host") hold for every edit, the way 06 D6 is a backstop the
  > UI never meets. See Open question 7.

- **On load, geometry is trusted** (06 D10). A file whose opening names a
  missing host loads unchanged; nothing repairs it.
  - **`validate()` cannot report it:** the engine's validator does not know
    which component types are parametric, let alone which of their values
    are handles (06 D5).
  - **`ParametricSystem.diagnostics()` reports it:** `parametric.dangling`
    (severity `error`) for a `cascade` object, one per referenced handle
    that is not a live object, naming the object and the handle;
    `parametric.orphan` (severity `warning`) for an `orphan` object in the
    same state (D17).
  - `drift()` names such an opening: regenerated, it would draw nothing.
  - Such an opening is regenerated only if an edit seeds it, and that edit
    is refused (above), except its deletion. It stays selectable through
    its loaded children, so the user can delete it.
- **A host that is a live object of another type** (a box) is not
  dangling to the engine. The opening draws nothing and `opening.orphan`
  reports it (D17). Only a hand-built command or a file produces it.

**Costs:** one more refusal type a caller may meet. **Pinned by:** `DR1`,
`DR2`, `OS4`; M-08l, M-08y.

### D6 — `OpeningParams`

- **Fields:**
  - `host` — the host wall's `Handle`;
  - `position` — double, mm, **the distance along the host's centreline
    from the host's `start` to the opening's centre**, measured in the
    host's group-local space (where `WallParams` stores its endpoints);
  - `width` — double, mm, the opening's extent along the centreline;
  - `kind` — `OpeningKind.door`, `.window` or `.gap`, fixed at creation;
  - `hinge` — `HingeEnd.start` or `.end`: which jamb a door hangs on, seen
    along the host from start to end;
  - `swing` — `SwingSide.left` or `.right`: which face of the host a door's
    leaf swings out of, looking from start to end (07 D2's convention for
    left and right).
- **`typeId`:** `floor_planner.opening`.
- **`toJson` key order:** `host`, `position`, `width`, `kind`, `hinge`,
  `swing`. `host` is the handle's integer value; enums are their names.
  **All six keys are always written,** for every kind, as the spike did:
  one shape, one round-trip path. A window's or gap's `hinge` and `swing`
  are written by the tools as `start` and `left` and never read by its
  `generate`.
- **Value-equal, exact `==`** on every field (stored values, CLAUDE.md).
- **Why the centre, not the start edge** (the roadmap left it open): a
  width edit keeps the opening where it is, symmetrically, which is what a
  user changing 800 to 900 expects; the tools place the opening centred at
  the click (decision 8) and the slide grip sits at the centre
  (decision 9), so all three read and write the same number. The cost is a
  `± w/2` at each use. **M-08b needs a non-central fixture either way**
  (a centred opening in a symmetric wall hides the wrong end, spike Q3d1).
- **Why the start** (decision 15): it is 07's own frame (`start`, `d`), so
  the opening and its wall compute the cut from the same numbers. The cost —
  the start grip moving doors (spike finding 4) — is paid by D13.
- **Validation ranges:**
  - **width** must exceed `wallJoin.linear` in the tools and the panel,
    and `4 × wallJoin.linear` for a gap (D10's inset);
  - **position** must be finite and within `[0, L]` (`L` the host's
    centreline length) in the panel; the tools and the slide grip only
    produce values in that range;
  - **`fromJson` accepts anything** well-typed, like 07's `WallParams`. A
    stored position outside the wall (after the wall was shortened, D13) is
    legal: it is drawn clamped (D8).
- **A degenerate opening** — width ≤ `wallJoin.linear`, or a non-finite
  position or width, from a file only — cuts nothing and generates
  nothing; `diagnose` reports `opening.degenerate` (D17). It is a
  childless group, 06's ghost, and cannot be picked. Recorded, like 07's
  degenerate wall; no UI path produces it.
- **`editCapability = geometry`,** as the wall and the box.

**Pinned by:** `OP1` (round trip, `==`, key order); the position's meaning
by `OG1`, `OR1` (M-08b, M-08a); the width by `OG1` (M-08c).

### D7 — The host frame: straight span, obstacles, stretches

Everything in D7–D9 is computed **in the host's group-local space**, where
07 stores the outline, by **one function** called by the wall and by each of
its openings, so both get the same bits (spike: `hostFrame`).

- **The frame.** `s = start`, `d = (end − start)/|end − start|`, `n` the
  left normal, `L = |end − start|`, and 07 D2's face offsets `(lOff, rOff)`
  for the justification. `u` is the distance from `s` along `d`.
- **The straight span `[uS, uE]`** (spike rule 3): `uS` is the largest `u`
  of any **start-cap** vertex and `uE` the smallest `u` of any **end-cap**
  vertex. The caps are 07's own — `capsOf`, which is 07's `outline` with its
  two caps kept apart: the mitre, the lobe walk, the T butt, the clamp feet,
  and 07's local-space fallback (07 final review I1; when the local ring is
  not simple and anticlockwise, both caps are the free caps computed in
  local space). Between `uS` and `uE` both faces are plain offsets,
  whatever the joint. A degenerate host (07 D2) has no frame.
- **Obstacles** (decision 18; spike finding 2). Among the host's **wall
  neighbours** (`view.neighbours(host)` carrying `WallParams`), an
  obstacle is an interval `[o₁, o₂]` of `u`:
  - **a T:** a neighbour B with an end that lies within `wallJoin.linear`
    of the host's centreline, strictly inside it (07 D4.1's
    `_strictlyInside`, with the host as the through wall). The interval is
    the `u`-range of `cap(End(B, k), Tee(host))`'s points — 07's own T
    cap, on the host's near face — **together with** the points where B's
    two faces cross the host's near face. When the mitre limit clamps the
    T, 07 squares B at its own endpoint inside the host's body, and B's
    band then runs through the host's band from that end until its faces
    leave the near face: the interval covers that whole footprint, not
    only the square end. It is judged against the host only, whichever
    wall 07 picks as B's through wall when several centrelines pass there;

    > **Amended at execution (controller, 2026-09-25, Task 3 review S1).**
    > Revision 1 took only the u-range of the cap's points; for a clamped
    > T that is B's square end (≈20 mm on HF3's 10° fixture) while B's
    > band crosses 1,192 mm of the host's band, so a door could be placed
    > under B. The face crossings with the near face close the gap; the
    > unclamped T is unchanged (its cap points already lie on the near
    > face).
  - **a crossing (X):** a neighbour B whose centreline crosses the host's
    centreline strictly inside both (07 D4's X). The interval is the
    `u`-range of the four points where B's two faces cross the host's two
    faces. Parallel faces cross nowhere and make no obstacle.
  - **Not obstacles:** a neighbour's free end that pokes into the host's
    band without lying on its centreline (07 does not join it either), and
    two collinear overlapping walls (07 Ruling 07-4). Recorded.
- **Stretches:** the straight span minus the union of the obstacle
  intervals, as a sorted list of disjoint intervals. A stretch no longer
  than `wallJoin.linear` is dropped.
- **Why this adds no hop to D3:** obstacles read the host's own
  neighbours' parameters, and the T cap of B at the host depends on B and
  the host only (`cap`'s `Tee` case, `wall_geometry.dart:262-277`). A
  change to B seeds B; the host is B's neighbour, in the core; the host's
  openings are its referrers.
- **Tolerance:** "an end lies on the centreline" and "a stretch is too
  short" are geometric decisions and use `wallJoin` (07 D7). Subtracting
  and merging the obstacle intervals compares computed values exactly;
  only the final "too short" test uses `wallJoin`.

**Costs:** the host's joints and obstacles are computed once for the wall
and once per opening in the same plan (Open question 13). **Pinned by:**
`OG2` (M-08s), `OG3` (M-08o), `OG4` (M-08x).

### D8 — Where an opening cuts: clamp, no-fit, overlap

For an opening with stored centre `c` and width `w` on a host frame:

1. **Candidates:** the stretches at least `w` long (`w ≤ b − a`).
2. **No-fit:** no candidate — the opening **cuts nothing**. It keeps its
   stored position and draws its symbol outside the band (D11).
3. **The chosen stretch** `[a, b]` is the candidate **nearest `c`**: the
   distance from `c` to the interval, 0 when `c` is inside it. Ties go to
   the lower `a`.
4. **The cut** is `[x, x + w]` with `x = clamp(c − w/2, a, b − w)`. The
   stored position is never changed by drawing; only the drawing moves.
   When `x ≠ c − w/2` the opening is **clamped** (D17). The comparison is
   exact: the clamp returns its argument unchanged when it is inside, so
   an unclamped opening compares equal bit for bit.

> **Interpretation.** Decision 18 says "clamps into the stretch nearest its
> position; if none is wide enough it is no-fit". Read literally, the
> nearest stretch could be too narrow while a farther one fits. This spec
> reads it as "the nearest **among the stretches wide enough**", so an
> opening is no-fit only when nothing on the wall can hold it. See Open
> question 3.

- **Merging (decision 6):** the fitting cuts of one wall are sorted by
  start; a cut that starts within `wallJoin.linear` of the previous merged
  cut's end joins it (the union), so two overlapping or touching openings
  make one gap and no sliver piece. Both symbols are drawn. Two cuts in
  different stretches never merge: an obstacle lies between them.
- **Overlap** (for D17): two fitting cuts of the same host overlap when
  each starts more than `wallJoin.linear` before the other ends. Touching
  is not overlap.
- **The degenerate width** (≤ `wallJoin.linear`) never fits (D6).

**Costs:** an opening can be drawn far from its stored position when a
narrow stretch holds it; `opening.clamped` says so. **Pinned by:** `OG2`,
`OG5` (M-08w), `OG6` (M-08m), `OG7`, `OG9`.

### D9 — The wall's pieces and its split centreline (amends 07 D3)

- **A wall with no fitting cut takes 07's path unchanged:** one region and
  one centreline, 07's outline. Every 07 test stays as it is.
- **A wall with merged cuts `[a₀, b₀] … [aₙ, bₙ]`** generates, in this
  order:
  1. **n + 2 regions, one per piece,** anticlockwise like 07's ring, start
     piece first (spike rule 3; `R(u)`, `L(u)` are the right and left face
     points at `u`):
     - start piece: `[R(a₀), L(a₀)] + start cap`;
     - middle piece i: `[R(aᵢ₊₁), L(aᵢ₊₁), L(bᵢ), R(bᵢ)]`;
     - end piece: `end cap + [L(bₙ), R(bₙ)]`;
     - a piece no longer than `wallJoin.linear` along the centreline is
       **dropped** (an opening clamped against a square cap);
  2. **one open two-point centreline polyline per kept piece** (decision
     16), in the same order: the start piece's from `u = 0` to `a₀`, a
     middle piece's from `bᵢ` to `aᵢ₊₁`, the end piece's from `bₙ` to `L`.
     A dropped piece has no centreline either.
  All `kWallColor`, as 07.
- **The cap-vertex snap** (spike rule 3, "What failed first"): a cut
  clamped onto the span lands on a cap's face vertex, and the face point
  recomputed there differs by about 1e-10; the near duplicate made 07's
  triangulation check refuse the region, so the **edit threw
  `ArgumentError` and was rolled back** (spike, with the snap removed:
  66 of 1,244 random openings refused, 5.3%). **Rule:** within
  `wallJoin.linear` along `u` of a cap's face vertex, that vertex is the
  piece's corner and the recomputed point is left out. 0 refused after.
- **Every stored piece is simple, anticlockwise and triangulable** — 07
  D6's invariant, now per piece. `simplifyRing` still guards each ring.
- **The jambs are the pieces' own edges.** No opening generates a jamb
  child.
- **Why split the centreline** (spike finding 1): 07 D3 generates it in
  `kWallColor`, invisible inside the band, but in a doorway it is a black
  line across the opening on every paper (`r1_l_and_t.png`,
  `r2_blueprint_wall.png`), and it makes a click in the doorway pick the
  wall (spike Q6: `1303 (edge) -> 1300`). Split, the doorway is clean and a
  click in it picks nothing, or the opening's own children.
- **What the split centreline still gives:** picking and snapping on the
  wall's solid parts (07 D3). Each piece's centreline has endpoints at the
  cut edges, so endpoint snap offers every opening's edges on the
  centreline for free. The Wall tool's band joining and `WallGrips` read
  `WallParams`, never the centreline entity (07 D11), so they are
  unaffected.
- **Child counts and handles (amends 07 D3 and D9).** 07's "exactly three
  children, fixed at creation" holds only for an uncut wall. A cut wall's
  child count is `3 × pieces`. The planner matches regions through their
  fills by ordinal (07 D8) and centreline pieces as the non-boundary
  polylines by ordinal (06 D4 step 7): the i-th piece in `u` order is
  rewritten in place into the i-th existing region or polyline in
  ascending handle order. **An added piece takes a fresh, higher handle;
  a removed one is the highest-handle surplus.** So a wall's piece handles
  are history-dependent but deterministic: the same state plus the same
  edit gives the same bytes (06 D11). D12 says why nothing visible depends
  on them.

**Costs:** 07's fixed handles for a cut wall (D12 pays it). **Pinned by:**
`OG1` (M-08e), `OG8` (M-08k), `OG9` (M-08snap), `OR6`; 07's own tests for
the uncut path.

### D10 — The opening's symbols, space and colour

- **Per kind,** on the cut `[x₁, x₂] = [x, x + w]` of D8 (for a no-fit
  opening, D11 moves them):
  - **Door** (two children, a LINE then an ARC): the hinge `H` is the
    jamb corner on the **swing-side face** at `x₁` (hinge `start`) or `x₂`
    (hinge `end`). The **leaf** runs from `H` perpendicular to the wall,
    away from the band, as long as the width. The **swing** is a quarter
    arc about `H`, radius the width, from the leaf's tip to the shut jamb
    (the other jamb's point on the same face), a sweep of +π/2, its start
    angle chosen so the sweep is anticlockwise.
  - **Window** (three LINEs): the left face, the midline
    (`(lOff + rOff)/2`) and the right face, each from `x₁` to `x₂`, in that
    order.
  - **Gap** (one LINE, R1 as amended): a **threshold line** on the host's
    centreline (offset 0), from `x₁ + m` to `x₂ − m`, with the **inset**
    `m = min(t/4, w/4)` (`t` the host's thickness, `w` the width). It makes
    a gap selectable and deletable, which the spike's childless gap was not
    (spike Q6: `miss`, 06's ghost), and it lies where D9 leaves nothing
    else: a click in the doorway picks the gap.
    - **Why `t/4`:** the inset scales with the wall, so the line reads as a
      threshold, clearly apart from the jamb strokes at any zoom where the
      wall itself reads: 30 mm for a 120 mm partition and 62.5 mm for a
      250 mm wall, 0.6 mm and 1.25 mm on paper at 1:50.
    - **Why capped at `w/4`:** the line keeps at least half the gap's
      width, `w − 2m ≥ w/2 > 0`, however narrow the gap or thick the wall.
    - **Why it clears `wallJoin.linear`:** `m > wallJoin.linear` whenever
      both `t` and `w` exceed `4 × wallJoin.linear` (4e-6 mm). For a gap,
      the tools and the panel therefore require `w > 4 × wallJoin.linear`
      (D6's minimum, raised for this kind only); a wall that thin is not
      drawable (07 requires `t > wallJoin.linear`; nothing draws one below
      4e-6 mm). A loaded file below either bound still gets a line of
      positive length; it may lie within `wallJoin.linear` of a piece.
      Recorded.
    - For a left- or right-justified host the centreline is one of the
      face lines (07 D2); inside the gap there is no piece on it, so the
      rule holds there too.
- **Child counts are fixed by kind** and never change for an object's life
  (`kind` is fixed at creation). So an opening's children keep their
  handles across every regeneration, no-fit included.
- **Space (spike Q5).** The opening is its own root-level group **at the
  identity**, like a wall. The symbol is computed in the host's local
  space and taken **host-local → world → own local**:
  `toWorld(self)⁻¹ · toWorld(host)`. That survives the host in a rotated
  group (spike Q1a) and a transform on the opening's own group (Q5a). A
  group transform carrying the host's frame would need the planner to
  write node transforms, which it cannot.
- **Colour:** **ByLayer on layer 0** (decision 13), `Generated`'s default:
  black on White, Ivory and Grey paper, white on Blueprint (fix/post-07).
  Walls stay `kWallColor`, concrete black. The planner writes a colour only
  when it adds a child (07 D8's amendment); ByLayer needs no migration.
- **`reach` is `Aabb2.empty()`** (spike: "The opening's reach"). An opening
  overlaps nothing, so it is never anybody's spatial neighbour and has none;
  **references alone** bring it into a closure (D3). A host-derived reach is
  impossible anyway: `reach` sees only its own parameters. What this means
  elsewhere:
  - **picking** is unaffected: it goes through the spatial index over the
    opening's children, never through `reach`; a door picks by its leaf or
    its arc (spike Q6: `5003 (edge) -> 5000`), a window by its lines, a gap
    by its threshold line, whatever the wall's piece handles are (D12);
  - **neighbour tests** still count an empty reach once per pair in
    `debugOverlapTests` (07 D10's `n` includes openings); none passes.

**Costs:** a gap's threshold line is a drawing convention, not a physical
element; a user who wants jamb marks gets none. **Pinned by:** `OG10`, `OR1`
(M-08h), `OR7` (M-08g), `OR8` (M-08j, M-08j2).

### D11 — The no-fit symbol (decision 17)

A no-fit opening (D8 step 2) draws its symbol over its **stored** interval
`[c − w/2, c + w/2]`, unclamped, but **never over the band**:

- **Door:** its symbol already lies outside the band on the swing side —
  the leaf and the arc touch the swing-side face only at the hinge and the
  shut jamb. It is drawn as D10 says, over the stored interval.
- **Window and gap:** their lines lie across the band, so they are drawn
  **translated by the wall's thickness `t` along the left normal**, so they
  lie in the band's image placed against its left face, outside the band:
  the window's three lines at offsets `lOff`, `lOff + t/2` and `lOff + t`
  (from the left face outwards); a gap's threshold line at offset
  `lOff + t/2`, the image's midline, where the no-fit window draws its
  midline, over the stored interval inset by D10's `m` at each end.
  (Translating the centreline by `t` would not do: for a left-justified
  wall it would land on the left face itself.)

> **Interpretation.** Decision 17 says "just outside the wall's face" and
> not which face. A door has an obvious side (its swing); a window and a
> gap do not, so this spec picks the **left** face, a fixed rule a test can
> pin. See Open question 9.

- **Why** (spike Q4): a no-fit symbol drawn over the uncut band is covered
  or not depending on history — `r3_blueprint_nofit.png`: the white
  midline shows across one piece and not the other. Outside the band, the
  host's draw order is invisible again (D12).
- **The wall is uncut:** 07's three children, 07's outline.

**Pinned by:** `OG7` (M-08u).

### D12 — Draw order (amends 06 D12 and 07 D9)

- **Ascending handle value, unchanged.** No per-object draw pass.
- **07's argument is gone:** "walls never add children after creation" (07
  D3, D9) is false for a cut wall (D9). A piece added later takes a handle
  above older symbols (spike R2: wall children `[1301, 1302, 1303, 5001,
  5002, 5101, 5102]`, door D1's leaf and arc `[5003, 5004]`: the new end
  piece `5101/5102` is drawn above D1, which is hinged on its corner).
- **The rule that replaces it: a symbol never overlaps its host's
  pieces.** It holds by construction:
  - a fitting door's leaf and arc lie outside the band on the swing side
    and touch it at two points on the face;
  - a fitting window's lines lie inside the gap rectangle and touch the
    pieces at their jamb edges' points only;
  - a fitting gap's threshold line lies inside the gap, `m` from each
    jamb (D10), and touches nothing;
  - a no-fit symbol lies outside the band (D11);
  - centreline pieces are `kWallColor` inside the band.

  So the order between a symbol and its host's pieces is invisible, except
  for a stroke's width at a touching point. The spike rendered it at 8 px/mm
  on Blueprint (white symbol, black wall): nothing covered
  (`r2_blueprint_hinge.png`).
- **No exception.** Revision 1 had one: R1's original two jamb lines
  coincided with the pieces' jamb edges, so a piece added later beside a
  gap covered its jamb on Blueprint and won a click on it (pick ties go to
  the greater handle). The controller amended R1 (2026-09-25, this spec's
  open question 1): the inset threshold line (D10) shares no point with a
  piece, so the pieces' handle history is invisible for every opening.
- **Other walls' bands are not covered by the rule.** A door near an acute
  corner can swing into the other wall's band, and a no-fit symbol can lie
  over a neighbour's band. Whichever is drawn later shows. Visible on
  Blueprint only. Recorded, not changed.

**Costs:** a symbol that could not keep off its host's pieces would need
a per-object draw pass; none of 08's does. **Pinned by:** `RD1`; `OR8`
(M-08j2) for the gap after a later piece is added beside it.

### D13 — Where an opening goes when its host changes

- **A whole-wall move or rotate** (03's group gesture,
  `TransformNodeCommand` on the wall's group) **keeps the stored
  positions.** The openings move with the wall in the same undo step,
  through D3's referrer direction. This is roadmap decision 2's point: the
  opening is placed along the host, so it follows for free.
- **A Wall-section edit** (thickness, justification) keeps the positions.
  The cuts and symbols regenerate.
- **An end grip drag rewrites positions** (decision 15), in the same
  `CompoundCommand` `WallGrips.drag` already returns (07 D11), so it is one
  undo step. **For every wall in that compound** — the dragged wall and
  each joined wall whose end follows it — and each of its openings (every
  live object carrying `OpeningParams` with that wall as host, read from the
  document's component store):
  - **if only the end moved** (the stored `start` is unchanged, exact
    `==`): the position is **kept**; no command is added;
  - **if only the start moved:** the new position is
    `p′ = L′ − (L − p)` — the distance from the **end, which did not move,**
    is kept; one `SetComponentCommand<OpeningParams>` is added, after the
    wall's own;
  - **if both moved** (reachable only for a wall shorter than its join
    tolerance, which 07 refuses to create): the position is kept.

  For a drag along the wall's line, every opening stays put in the world
  (to rounding: `EG1` asserts 1e-6 mm at the far origin). For a drag that
  swings the wall, an opening keeps its distance from the unmoved end and
  swings with the wall about it.

> **Interpretation.** Decision 15 says "stay put in world". An opening must
> stay on its wall, so when the wall swings, staying put exactly is
> impossible. Keeping the distance from the end that did not move keeps
> every opening's order, spacing and distance from the unmoved corner, and
> it is exact for the common case: lengthening or shortening a wall along
> its line. Projecting each old centre onto the new line was rejected: it
> scales every distance by the cosine of the swing and can push openings
> together. See Open question 4.

- **A shortened wall** keeps the stored positions. An opening now past the
  wall's straight part is drawn clamped, or no-fit, and diagnosed (decision
  4). Nothing is refused, nothing is lost: lengthening the wall again
  restores the drawing.
- **The drag preview** still draws only the moved centrelines (07 D11);
  openings regenerate on release.

**Costs:** `WallGrips` must read the document's openings, O(openings), once
per release. **Pinned by:** `EG1` (M-08p), `EG2`, `EG3` (M-08p2), `EG4`.

### D14 — The tools: Door (D), Window (N), Gap (G)

- **One `OpeningTool` class, three instances** (decision 8), each a
  `PlacementTool` whose **first click commits**. The tool stays active
  after a placement, so a run of doors is a run of clicks; Esc returns to
  the select tool (05 D5). D, N and G join `kShellLetterKeys` and the
  palette.
- **The host** is the wall whose **band** contains the **raw** pointer
  (between its faces, within its length), the band test 07's Wall tool
  uses (07 D11's amendment). Several bands: the lowest handle, as 07. The
  band cache is shared with the Wall tool (factored out of
  `wall_tool.dart`); a hover scan allocates nothing in steady state and
  scans nothing when no wall is near (07 `WT12`'s bar). No wall under the
  pointer: no preview, and a click does nothing.
- **The position** is `u` of the resolved point (D15) projected onto the
  host's centreline, in the host's local space. **What is stored** is the
  centre of the cut the opening would get there (D8): the projected `u`
  when it fits where it is, the clamped centre when it had to move into a
  stretch, the projected `u` itself when it is no-fit.

> **Interpretation.** "Placed centred at the click" (decision 8) is kept
> for every click where the opening fits. Where it does not, storing the
> projected click would create an opening that is `opening.clamped` from
> birth. Storing where it is drawn keeps a fresh placement undiagnosed.
> The same rule applies to the slide grip (D16). See Open question 5.

- **Door hinge and swing on placement:**
  - **swing side** = the side of the host band's **midline** the **raw**
    click lies on: `left` when `(p − s)·n − (lOff + rOff)/2 ≥ 0` in local
    space, `right` otherwise (a click exactly on the midline swings
    left). On a centre-justified wall the midline is the centreline.

> **Amended at planning (controller, 2026-09-25, plan finding 2).**
> Revision 1 used the side of the host's **centreline**. On a left- or
> right-justified wall the centreline is a face (07 D2), so the whole band
> lies on one side of it and every click gave the same swing. The
> midline realises decision 8 ("the clicked side of the wall") on every
> justification.
  - **hinge** = the jamb **nearer the host's nearer end**: `start` when
    the stored centre is at most `L/2`, `end` otherwise. The door then
    opens towards the nearby corner, against the wall.

> **Interpretation.** Decision 8 says "hinge = the nearer end". The click
> is at the centre, so "nearer" cannot be measured from the click to a
> jamb. This spec reads it as the host wall's nearer end. See Open
> question 2.

- **Width** comes from the tool's own `OpeningSettings` (one per kind,
  owned by the shell): **900** for a door, **1200** for a window, **900**
  for a gap, edited in the Selection panel's tool mode (D16). A window's
  and a gap's hinge and swing are written as `start` and `left`.
- **The commit** is `Compound([AddNodeCommand(group at the identity),
  SetComponentCommand<OpeningParams>(…)])` through `commit(ctx, …, needs:
  {structure, components, geometry})`: one undo step, in which the host
  regenerates (D3).
- **Hover preview:** the would-be symbol and the would-be cut's two jamb
  lines (a preview only, never generated), in
  world, computed on each pointer move from the shared frame function and
  painted from the cached payloads. Nothing is computed per frame, so the
  frame path gains no allocation.
- **Refused commits.** An `ArgumentError` or `StateError` from `execute`
  (a malformed host from a file) is caught, and nothing is placed, as 07's
  tool does.

**Costs:** a band cache shared by four tools. **Pinned by:** `OT1`, `OT2`
(M-08z, M-08z2, M-08z3), `OT4`.

### D15 — Snapping

- **The point a tool or the slide grip resolves** goes through the
  existing chain first: object snap (F3) and the grid, exactly as the
  drawing tools resolve a click (05 D4) and the select tool resolves a drag
  (`resolveDragPoint`). The result is then **projected onto the host's
  centreline** (D14, D16).
- **Edge snaps on the host** (decision 10), gated on object snap (F3):
  the candidates are the host's **stretch ends** (the straight span's ends
  and every obstacle's edges, D7) and the **drawn edges of the host's other
  openings** (their cuts, D8). When one of the placed opening's edges,
  `u ± w/2`, lies within the snap aperture (`kSnapAperturePixels /
  camera.scale`, in world) of a candidate, the centre moves so that edge
  coincides with it. The nearest candidate wins; ties go to the lower `u`.
- **Precedence:** an edge snap wins outright over the projected chain,
  like 05 D4's self-snap (for a tool it is the `selfSnap` hook, evaluated on
  the raw point). Rationale: lining a door up with a jamb or a corner is
  the common intent, and the chain's own candidates are still there when
  no edge is near.
- **The slide grip** needs the aperture in world. `ObjectGripProvider.drag`
  receives only a world point, so the shell gives the composite provider a
  callback that returns the current world aperture. No render-layer change.
- **The preview's snap marker** is drawn at the resolved, projected point,
  not at the raw one (07's debt `m5` is not repeated).

**Pinned by:** `OT3` (M-08sn), `SG1`.

### D16 — Editing: the Opening section, the slide grip, no move or rotate

**The Opening section** in the Selection panel.
- Shows when **exactly one** selected key is a root-level group carrying
  `OpeningParams`, or when the Door, Window or Gap tool is active. In tool
  mode it edits **that tool's** `OpeningSettings` (width only), even when an
  opening is selected (07 D11's amendment for the Wall section).
- **Fields and controls:**
  - **Width** (mm; must exceed `wallJoin.linear`, or `4 × wallJoin.linear`
    for a gap (D6); otherwise or unparseable, the field reverts);
  - **Position** (mm, from the wall's start to the centre; finite and in
    `[0, L]`, else it reverts). Not shown in tool mode;
  - **Flip hinge** and **Flip swing**, for a door only; each is one
    `SetComponentCommand<OpeningParams>` toggling `hinge` or `swing`.
- Each commit is one `SetComponentCommand<OpeningParams>`, one undo step.
  The fields show **stored** values: a clamped opening shows the position it
  stores, not where it is drawn.
- **The conventions of 07 and fix/post-07, all of them:**
  - each field is a `PanelFieldFocusNode`; Enter and a tap outside call
    `handBack()`, which walks the focus history back past every panel
    field in either panel;
  - each field commits on its own focus loss;
  - **the commit target is pinned at focus gain** and re-pinned after a
    commit; a pinned target that is no longer a live opening discards the
    typed text (07 `WS7`);
  - in tool mode the Width field **writes each valid keystroke** into the
    tool's settings (07 `WS6`), so a width typed and then a canvas click
    without Enter places with the typed width;
  - **a refused edit reverts the field:** an `ArgumentError`, a
    `StateError` or a `DanglingReferenceError` from `execute` is caught, the
    field shows the model's value and re-pins (07 `WS9`);
  - a reload never writes into a focused field (06 D13's F1);
  - read-only unless both `components` and `geometry` are allowed (07
    `WS8`); the flip controls are disabled with them;
  - `shortcut_guard.dart` covers D, N and G, so typing them in a field does
    not switch tools;
  - the flip controls take focus the way the Wall section's Justification
    toggle does.

**The slide grip.**
- `OpeningGrips.gripsOf` returns **one `stretch` grip** at the **drawn**
  centre of the opening on the host's centreline, in world: the cut's
  centre, or the stored centre for a no-fit opening.
- `drag` resolves the point (D15: chain, projection, edge snaps), then
  writes `SetComponentCommand<OpeningParams>` with the **clamped** centre
  the opening would be drawn at (D8; D14's interpretation). "Clamped to the
  wall" (decision 9) is that clamp: a drag never stores a position the
  opening is not drawn at, unless the opening is no-fit everywhere, when
  the projection is clamped to `[0, L]`. One undo step. A drag that changes
  nothing returns null.
- `preview` draws the would-be cut's two jamb lines, in world (a preview
  only; no opening generates jamb lines).
- It needs `components` and `geometry` (07 `OG5`): under runtime it is not
  hit.

**The composite provider.** `GripCache` holds one `ObjectGripProvider`
(`main.dart:193`). `ObjectGrips` (app) implements it and dispatches by the
group's component: `WallParams` → `WallGrips`, `OpeningParams` →
`OpeningGrips`, anything else → no grips and no drag.

**No select-tool move or rotate for an opening** (decision 9). A move
would be undone by the next regeneration anyway: the symbol is computed from
the host (spike Q5a: the door's group moved by (700, 300), `leaf start
moved 0.0 mm; wall pieces equal: true`, and the move is in history).
- **The seam (render layer):** `ObjectGripProvider` gains
  `bool movable(DraftDocument d, Handle group)`: false when the select tool
  must not move or rotate that group. `WallGrips` answers true, the
  composite answers false for an opening. A test fake answers true.
- `GripDrag.move` and `GripDrag.rotate` take the provider and **skip** a
  root-level group it calls immovable, as they skip a fill (03 D4). A
  selection of openings only has nothing to capture, so the drag never
  starts and the press stays a click (03 Ruling 03-6's path). A mixed
  selection moves the rest: a wall selected with its door moves, and the
  door follows through regeneration.
- `GripCache.rotatable` also needs at least one movable key, so the
  rotation grip is not drawn for openings alone, and the select tool shows
  no move cursor over them.
- **If a transform reaches an opening anyway** (a hand-built
  `TransformNodeCommand`, a future tool), the engine accepts it. The group
  transform changes, the symbol is regenerated so its world position is
  unchanged (D10's space rule, `OR7`), and the edit is one undo step with
  nothing visible. Recorded, not refused: 06 has no per-type veto on a node
  transform, and adding one is not worth it for an edit the UI never
  issues.

> **Interpretation.** Decision 9 says move and rotate are "not offered".
> Skipping openings in a mixed selection, rather than refusing the whole
> move, follows 03 D4's treatment of fills. See Open question 11.

**Delete** is unchanged: the select tool's delete of an opening removes its
children and node, 06 D8 detaches its component, and its host regenerates
whole in the same step (spike Q2b). Deleting a wall takes its openings (D4).

**Costs:** one render-layer interface method and a composite in the app.
**Pinned by:** `SG1`, `SG2` (M-08i), `OS1`–`OS4` (M-08pin), `OR7`.

### D17 — Diagnostics

`OpeningType.diagnose` reports, each at most once per opening, severity
`warning` unless stated:

- **`opening.nofit`** — no stretch is wide enough (D8). Handles: the
  opening.
- **`opening.clamped`** — drawn off its stored position (D8). Handles: the
  opening, then every obstacle wall whose interval overlaps the
  **unclamped** interval, ascending. The message says whether a corner
  (the straight span) or a wall (an obstacle) moved it.
- **`opening.overlap`** — two fitting cuts of one host overlap (D8).
  **Once per pair, by the lower handle** (R2): the lower-handle opening
  reports one entry per higher-handle opening it overlaps, handles `[lower,
  higher]`. The spike reported twice per pair (finding 6: 926 entries in
  its random run).
- **`opening.orphan`** — the host is a live object that is not a wall
  (D5). Handles: the opening, the host.
- **`opening.degenerate`**, severity `error` — D6's degenerate opening.

The engine's `ParametricSystem.diagnostics()` adds, for every live object,
before the types' own reports:
- **`parametric.dangling`**, severity `error` — a `cascade` object with a
  referenced handle that is not a live object (D5: only a file produces
  one);
- **`parametric.orphan`**, severity `warning` — an `orphan` object in the
  same state (D4).

One entry per object per referenced handle, in ascending handle order.
`WallType.diagnose` (07 D12) is unchanged.

**Obstacles have no code of their own.** Under decision 18 an obstacle is
not a fault; it moves an opening, which `opening.clamped` names with the
wall responsible, or leaves it no-fit.

**Pinned by:** `OG2`, `OG3`, `OG5`, `OG6` (M-08q, M-08q2), `OG7`, `DR2`,
`CS3`.

### D18 — The sample plan, rebuilt

The startup flat keeps its rooms, finishes and furniture; its walls,
doors and windows become 07 walls and 08 openings **at the same places**
(decision 11). Coordinates are relative to `x0 = kPlanOriginX = 12000`,
`y0 = kPlanOriginY = 8000`, `x1 = x0 + 14000`, `y1 = y0 + 9000`.

**Walls,** each in its own root-level group at the identity,
centre-justified, `kWallColor`:

| Wall | Thickness | start → end | L |
|---|---|---|---|
| E1 (south) | 250 | `(x0+125, y0+125) → (x1−125, y0+125)` | 13,750 |
| E2 (east) | 250 | `(x1−125, y0+125) → (x1−125, y1−125)` | 8,750 |
| E3 (north) | 250 | `(x1−125, y1−125) → (x0+125, y1−125)` | 13,750 |
| E4 (west) | 250 | `(x0+125, y1−125) → (x0+125, y0+125)` | 8,750 |
| P1 | 120 | `(x0+5000, y0+125) → (x0+5000, y1−125)` | 8,750 |
| P2 | 120 | `(x0+125, y0+5000) → (x0+5000, y0+5000)` | 4,875 |
| P3 | 120 | `(x0+5000, y0+3500) → (x1−125, y0+3500)` | 8,875 |
| P4 | 120 | `(x0+2600, y0+5000) → (x0+2600, y1−125)` | 3,875 |
| P5 | 120 | `(x0+9500, y0+125) → (x0+9500, y0+3500)` | 3,375 |

E1–E4 run anticlockwise, as the Wall tool draws a closed room, and mitre at
the four corners; their outer faces are today's outer rectangle and their
inner faces today's inner one. Every partition ends on another wall's
centreline, strictly inside it, so each end is a T and butts that wall's
near face, where today's double lines end. **E3 and E4 run against the
axes on purpose:** their positions are measured from their east and north
ends, so the sample plan itself is not M-08b's degenerate fixture.

**Doors** (hinge and swing from today's `door(…)` calls: the hinge on the
lower jamb of a vertical wall and the left jamb of a horizontal one; the
leaf direction gives the side):

| Today's centre | Width | Host | Position | Hinge | Swing |
|---|---|---|---|---|---|
| `(x0+5000, y0+6000)`, leaf −x | 900 | P1 | 5,875 | start | left |
| `(x0+5000, y0+1500)`, leaf +x | 900 | P1 | 1,375 | start | right |
| `(x0+2600, y0+7800)`, leaf +x | 800 | P4 | 2,800 | start | right |
| `(x0+1200, y0+5000)`, leaf −y | 800 | P2 | 1,075 | start | right |
| `(x0+7000, y0+3500)`, leaf +y | 800 | P3 | 2,000 | start | left |
| `(x0+11500, y0+3500)`, leaf +y | 700 | P3 | 6,500 | start | left |
| `(x0+6500, y0+125)`, leaf +y (front) | 1000 | E1 | 6,375 | start | left |

**Windows:**

| Today's centre | Width | Host | Position |
|---|---|---|---|
| `(x0+1300, y1−125)` | 1200 | E3 | 12,575 |
| `(x0+3900, y1−125)` | 1200 | E3 | 9,975 |
| `(x0+7200, y1−125)` | 1200 | E3 | 6,675 |
| `(x0+10800, y1−125)` | 1200 | E3 | 3,075 |
| `(x1−125, y0+1800)` | 1200 | E2 | 1,675 |
| `(x1−125, y0+6200)` | 1800 | E2 | 6,075 |
| `(x0+125, y0+2200)` | 1000 | E4 | 6,675 |
| `(x0+125, y0+6600)` | 1400 | E4 | 2,275 |

Worked by hand for this spec: every opening fits its stretch, none is
clamped, none overlaps, none covers an obstacle (for instance E3's
obstacles are P4's butt at `u ∈ [11215, 11335]` and P1's at
`[8815, 8935]`; its westmost window cuts `[11975, 13175]` within the
straight span `[125, 13625]`). **The plan's `SP5` replacement checks it:
`diagnostics()` is empty.**

**How it is built.** `startupPlan` installs a `ParametricSystem` over its
own document (`installParametric`), adds the walls, then the openings,
then the finishes and the furniture, each through `execute`, then
**disposes** its system, sets the page and clears the history. The shell
then installs its own system over the finished document, which trusts its
geometry as it would a loaded file (06 D10). `main.dart`'s comment at
`initState` changes accordingly. Build order puts the walls' first
children below the finishes and the furniture; the finishes stop at the
faces and do not overlap a band.

**The sample plan's tests, carried over:**
- **the entity count** stays in 500–1,000. The exact figure is re-derived
  by the plan and pinned (`SP1`'s literal). By this spec's count it is
  **549**: 509 − 70 (the 8 + 10 wall lines, 28 door entities and 24 window
  lines removed) + 110 (72 wall children: 3 per piece over 24 pieces; 14
  door children; 24 window children). The plan confirms or corrects it by
  running the test, never by assuming this number;
- **extents** are the outer rectangle, exactly (the exterior walls' outer
  mitre corners);
- **off-origin and not axis-symmetric**, and the page tests, unchanged;
- `SP1` (eight furniture regions) and `SP2` (furniture fills over finish
  lines) are **re-scoped to the furniture's root-owned regions**: wall
  pieces are regions too, and they are built before the finishes;
- `SP3` (no door leaf or swing under a furniture fill) and `SP4` (every
  doorway clear of furniture for 900 mm on both sides) **are carried over
  unchanged in intent.** The hinge now sits on the swing-side face instead
  of the centreline, which moves every approach zone by half the wall's
  thickness. Worked by hand: the tightest `SP4` margins become 40 mm (the
  hall/living door against bed 2; the kitchen/living door against the
  sofa), down from 100 mm each. The tests decide;
- **`SP5` is replaced:** nine walls, seven doors (the table's parameters,
  compared exactly), eight windows, no gap, no box; `drift()` and
  `diagnostics()` empty;
- **new:** save → load → save of the startup plan is byte-identical.

The **colours** change with it: walls are `kWallColor` (black) rather than
0x202020 at lineweight 50, and door and window symbols are ByLayer rather
than 0x2266CC. On Blueprint they turn white with the rest of the drafting
(fix/post-07). The debt "the startup plan's colours stay dark on
Blueprint" shrinks to the finishes and the furniture.

**Costs:** the exact entity count and the furniture tests' margins shrink by
up to 60 mm. **Pinned by:** D18's carried-over tests and the replaced `SP5`.

### D19 — Load, save, determinism

- **What a file stores:** each opening's root-level group node (at the
  identity), its `OpeningParams` component — **the host's handle is stored
  inside the component**, as an integer — and its generated children; each
  wall's pieces. No schema change: components, groups and entities already
  persist, and unknown components are kept verbatim (06 D10).
- **06 D10 and D11 hold unchanged:** on load geometry is trusted; load →
  save is byte-identical; the typed component comes back equal; `drift()`
  is empty after load; the same state plus the same edit gives the same
  bytes; undo then redo restores the post-edit state (canonical form).
- **The host relationship survives** because handles in a file are
  stable, and nothing on the load path renumbers them. Paste and import,
  which would, do not exist (Non-goals).
- **Platform:** as 07 D13, no test pins a literal hash of trig-dependent
  output; byte comparisons are between two documents built in the same
  run.

**Pinned by:** `OR2`, and the startup plan's byte-identity test (D18).

## What the roadmap and 07 asked 08 to decide

| Asked | Answer |
|---|---|
| Roadmap: where does the symbol come from? | Generated (D1, D10). 09 is a later, soft dependency; the roadmap order 08 → 10 → 09 stands |
| Roadmap: `OpeningComponent`'s fields | D6: host, position (to the centre), width, kind, hinge, swing. No sill or head height |
| Roadmap: host wall deleted | Cascade, in the engine, one undo step (D4); a per-type policy so 10 can orphan instead |
| Roadmap: host shortened past the opening | Keep the stored position; draw clamped; no-fit if nothing fits; diagnose (D8, D13) |
| Roadmap: an opening at or across a junction | Never cut there: the cut stays in the straight span, and out of other walls' T butts and crossings (D7, D8) |
| Roadmap: overlapping openings | Allowed; the union is cut; both symbols; diagnosed once per pair (D8, D17) |
| Roadmap: does dragging snap? | Object snap and grid projected onto the centreline, plus stretch ends and other openings' edges (D15) |
| Roadmap: does an opening cut a poché fill? | Yes, as a 1-D split of the band into pieces (D9). No polygon boolean: straight walls and perpendicular cuts make it trimming again |
| Roadmap: a door is one object | Yes: its leaf and swing are one group's children (D10). The sample plan's doors become openings (D18) |
| Roadmap: rotate about a chosen point | Its own branch after 08 (Non-goals) |
| Roadmap decisions 1–3 | Kept: an opening is a parametric object referencing its host (D2, D6); its position is along the host (D6); the dependency edge opening → wall is explicit, through references (D3) |
| 07: a neighbour's fill can cover a cut near a joint | Cuts never enter the caps (the straight span, D7) or another wall's T butt or crossing (obstacles, D7) |
| 07: the fixed-three-children draw-order argument breaks if regions split | It does; D12 replaces it with "a symbol never overlaps its host's pieces" |
| 07: rooms should derive from faces and centrelines | Restated for 10: from the **uncut** faces and centrelines (Non-goals) |
| 06: draw order of added children (D12) | D12: accepted, and invisible for every symbol, fitting or no-fit (R1 as amended: the gap's inset threshold line) |

## Architecture

### Files

- **Engine, `packages/jet_cad_2d`:**
  - `lib/src/parametric/parametric_system.dart`: `ParametricType.references`,
    `ReferencePolicy` and `referencePolicy`, `ParametricView.referrers`,
    `DanglingReferenceError`, `parametric.dangling` and
    `parametric.orphan` in `diagnostics()`, `_Registration.referencesOf`;
  - `lib/src/parametric/regeneration.dart`: the survey's `references` and
    `referrers` and `debugReferenceCalls` (D2), `_closure` (D3), `_cascade`
    and its place in `_run` (D4), the dangling check (D5);
  - `lib/jet_cad_2d.dart`: exports `ReferencePolicy`,
    `DanglingReferenceError`;
  - `test/parametric/`: `references_test.dart`, `cascade_test.dart`,
    `reference_cost_test.dart`, with **test-only clients**: a host type, a
    `cascade` referrer and an `orphan` referrer (the orphan policy has no
    product client in 08), and the two-hop shape.
- **Render layer, `packages/jet_cad_2d_flutter`:** `ObjectGripProvider.movable`;
  `GripCache.rotatable`; `GripDrag.move` and `GripDrag.rotate` skipping
  immovable groups; the select tool passing the provider (D16).
- **App, `apps/floor_planner`:** D1's files; `wall.dart` (pieces, split
  centreline), `wall_geometry.dart` (`capsOf`), `wall_grips.dart` (D13);
  the band cache shared by the Wall and opening tools; `selection_panel.dart`
  (the Opening section); `main.dart` (three tools, keys, settings, the
  composite provider and its aperture callback); `shortcut_guard.dart`
  (D, N, G); `tool_palette.dart`; `startup_plan.dart` (D18); tests.

### Amendments to 06 and 07

| Section | Amended by | What changes |
|---|---|---|
| 06 D3 (`ParametricType`, `ParametricView`) | D2 | `references`, `referencePolicy`, `referrers` |
| 06 D4 steps 1–6 (`_run`) | D3, D4, D5 | the survey's maps; the cascade after the guard; the dangling check; the closure rule |
| 06 D6 (the guard) | — | unchanged; the cascade runs after it |
| 06 D8 (delete) | D4 | a deleted object's `cascade` referrers go with it, in the same edit; D8's detach then covers them too |
| 06 D10 (`diagnostics()`) | D5, D17 | `parametric.dangling`, `parametric.orphan` |
| 06 D12 (draw order) | D12 | "a symbol never overlaps its host's pieces" |
| 07 D3 (three children) | D9 | only for an uncut wall |
| 07 D9 (draw order) | D12 | its argument is replaced |
| 07 D11 (end grips) | D13, D16 | openings' positions in the drag's compound; the composite provider; `movable` |

### Invariants

- **The frame path allocates nothing new.** Regeneration, grips, the panel
  and the tools' previews run on edits and gestures; previews are computed
  per pointer move, never per frame. `query_allocation_test.dart` and
  `paint_allocation_test.dart` stay green, unchanged.
- **Draw order is ascending handle value** (D12). An opening's children
  keep their handles for its life.
- **Decisions use `wallJoin`; stored values use `==`** (D6, D7, D8).
- **Every stored piece triangulates** (D9).
- **An edit never leaves a seeded `cascade` object with a dangling
  reference** (D5).
- **No query walk is open during a regeneration** (06, unchanged).
- **`packages/jet_cad_2d` stays pure Dart;** `opening_geometry.dart` and
  `wall_geometry.dart` import no Flutter.

## Testing

CLAUDE.md's bar: a test lands only if a named mutant turns it red. **A
centred opening in a free, symmetric, axis-aligned wall at the origin is
this feature's degenerate fixture** (the roadmap's trap): the wrong end, a
one-sided cut, a dropped transform and a swapped hinge all survive it
(spike: M-08b survives Q3d1, M-08e survives Q3d2). It may appear only as a
recorded control, never as the test that kills a mutant.

**Required fixture properties,** each carried by at least one relational
test:
- the whole plan at the **far origin** (≈ 4,500,000, 1,200,000);
- every wall in its **own rotated group** (06's M-06o lesson), and at least
  one opening's own group at a **non-identity** transform (M-08g);
- the host **non-axis-aligned**;
- openings at **non-central** positions;
- at least one wall carrying **two openings**, and one carrying two that
  **overlap**;
- **asymmetric thickness** (07's 200 against 115) and **justification
  mixes** (all nine pairs of an L);
- a **T obstacle** and an **X obstacle** inside a straight part;
- an opening **clamped** at a mitre, one clamped against a square cap
  (its piece dropped), and one **no-fit**;
- doors in **all four hinge × swing combinations**;
- the **two-hop** shape (spike Q1d: the 67° L, A 200 centre, B 115 left,
  the door in A clamped at A's mitre).

**Oracles, not counts alone** (spike, "The oracle"):
- **cut coordinates** against an independent frame written out from the
  stored parameters and the group transforms, without the geometry
  library (the spike's `oracleFrame`);
- **tiling:** 20,000 points uniform in the uncut band's box grown by 50 mm;
  every point inside the uncut band is in exactly one piece **xor** in one
  gap rectangle; nothing outside the band is in a piece or a gap; no point
  is in two pieces. Five counters (`overlap`, `hole`, `pieceInGap`,
  `pieceOutside`, `gapOutside`), all zero;
- **the uncut band is differential:** what 07 **stores** for the same wall
  in a twin document (saved, reloaded, every opening deleted), not 07's
  `outline` recomputed in world (the spike oracle's own first failure, at
  trial 38);
- expected gaps from an **independent clamp** against an oracle span read
  off the uncut band's vertices and oracle obstacle intervals.

### Tests by area

Identifiers are this spec's; the plan may renumber, keeping the mutants'
kills.

- **Engine (test-only clients):**
  - `RF1` the survey's maps: ascending, unmodifiable, non-objects left out;
  - `RF2` editing a referrer regenerates its referent;
  - `RF3` moving a referent far (reaches disjoint before and after)
    regenerates its referrer;
  - `RF4` the two-hop shape: a neighbour of the referent changes, the
    referrer regenerates;
  - `RF5` editing a referrer leaves the referent's other neighbours byte
    for byte unchanged (spike Q1e);
  - `CS1` deleting a referent cascades its `cascade` referrers: one undo
    step; undo, redo, undo then `purge()` restore state and child handles;
  - `CS2` a transitive cascade (a referrer of a referrer);
  - `CS3` an `orphan` referrer is kept, regenerated in the same edit, and
    reported `parametric.orphan`;
  - `CS4` a bare `RemoveNodeCommand` of a referent: the referrers' leaves
    and nodes are removed; the referent's own leaves stay (the recorded 06
    debt, asserted as is);
  - `CS5` a client whose `generate` throws after a cascade: the edit is
    refused and the bytes, the referrers and the undo depth are unchanged;
  - `DR1` a `SetComponentCommand` naming a non-object as a `cascade`
    object's referent is refused with `DanglingReferenceError`; bytes and
    history unchanged; the same for an `orphan` object is accepted;
  - `DR2` a file with a dangling reference loads unchanged;
    `diagnostics()` reports `parametric.dangling`; `drift()` names it;
  - `RC1`, `RC2` (D2).
- **Opening geometry and regeneration (app):**
  - `OP1` `OpeningParams`: key order, round trip, exact `==`;
  - `OG1` one cut, both faces, by coordinates, on a non-axis-aligned wall
    in a rotated group at the far origin, non-central, against the oracle;
  - `OG2` the 67° L, 200 against 115, nine justification pairs: two
    openings in A (one clamped at the mitre), one in B; tiling oracle;
    `opening.clamped` names exactly the clamped one (spike Q3a);
  - `OG3` a T obstacle: a door stored over the stem's butt is drawn in the
    nearest wide-enough stretch; `opening.clamped` names the door and the
    stem;
  - `OG4` an X obstacle, likewise;
  - `OG5` the nearest stretch too narrow, a farther one wide enough: the
    farther one is chosen; with neither wide enough, no-fit;
  - `OG6` two overlapping openings: one merged gap, both symbols, one
    `opening.overlap` from the lower handle naming both;
  - `OG7` no-fit: the wall is uncut (07's three children, equal to the
    twin's); the window's lines and the gap's threshold line lie outside
    the band on the left, the door's on its swing side;
  - `OG8` the split centreline: one polyline per piece, none enters a gap;
    a pick in the doorway misses the wall;
  - `OG9` the random property run (spike Q3f's generator plus T and X
    obstacles, every wall in its own rotated group at the far origin):
    0 tiling violations, 0 refused edits; counts of clamped, no-fit and
    overlap printed;
  - `OG10` door symbols in the four hinge × swing combinations against the
    oracle;
  - `OR1` the host moved far (spike Q1a): door and window follow exactly,
    three pieces tile, one undo step, undo and redo exact, `drift()` empty;
  - `OR2` save → load → save byte-identical; typed component equal;
    `drift()` empty; the same two edits on the original and its reload give
    the same bytes;
  - `OR3` editing the door regenerates its wall;
  - `OR4` the two-hop app fixture (spike Q1d);
  - `OR5` deleting a wall with a door, a window and a joined neighbour
    (spike Q2a): one step, handles restored;
  - `OR6` deleting only the door makes the wall whole again (07's three
    children);
  - `OR7` the opening's own group at a rotated, translated transform: the
    symbol is on the oracle; a `TransformNodeCommand` on it leaves the
    world symbol unchanged and is one undo step;
  - `OR8` a gap: one ByLayer threshold line on the centreline, `m` from
    each jamb by coordinates (a 250 mm wall and a gap narrower than `t`, so
    both arms of `min(t/4, w/4)` are exercised); a click on it selects the
    gap; then a second opening is added on the host's start side, so a
    piece with a fresh handle is added (D9), and the click still selects
    the gap; a band selection selects it;
  - `RD1` a render on Blueprint (the spike's R2 method: the shell rendered
    in `flutter_test`): a fitting door hinged on a piece added later is not
    covered.
- **Grips, tools, panel (app):**
  - `EG1` the start dragged along the line: every opening stays put in the
    world within 1e-6 mm, one undo step, joined walls' openings included;
  - `EG2` the end dragged: stored positions unchanged, exactly;
  - `EG3` a swing of the start: positions are `L′ − (L − p)`;
  - `EG4` a whole-wall move and rotate: stored positions unchanged, symbols
    moved;
  - `SG1` the slide grip: at the drawn centre; a drag projects, snaps and
    stores the clamped centre; one undo step; not hit under runtime;
  - `SG2` a body drag on a selected opening starts nothing; no rotation
    grip for openings alone; a wall selected with its door moves both;
  - `OT1` D, N and G each place one opening in one click and one undo
    step, centred at the projected click, with the tool's width;
  - `OT2` a door's swing side is the clicked side; its hinge is the
    nearer end's jamb, on a non-central fixture on both halves of the wall;
  - `OT3` edge snaps: a door's edge snaps to a stretch end and to another
    opening's edge; with F3 off, it does not;
  - `OT4` no wall under the pointer: no preview, no commit; the hover scan
    allocates nothing in steady state;
  - `OS1` the Opening section: shows for one opening, hides otherwise;
    width and position commit one step each; invalid values revert; flips
    for a door only; read-only under runtime; D, N, G in a field do not
    switch tools; Esc works after Enter;
  - `OS2` the pinned target: select opening A, focus Width, select B
    without focus, blur: A changes, B does not;
  - `OS3` tool mode: the Width field edits the active tool's settings,
    keystroke by keystroke;
  - `OS4` a refused edit (a malformed loaded host) reverts the field.
- **The sample plan:** D18's tests.

### Named mutants

Each is fired with a `cp` backup, restored with `cp`, then `diff` against
the backup and `git diff --quiet` (never `git checkout`), and logged in
`plan-08-mutation-log.md`.

| Mutant | What it breaks | Must be killed by |
|---|---|---|
| M-08a | **Structural (R3):** `OpeningParams` stores the opening's **world centre** `(x, y)` instead of a distance along the host; `generate` projects it onto the host. Fired **on a scratch copy** of the tree as a parameter-type swap (fields, JSON, tool, panel adapted just enough to compile), not a one-line edit | `OR1`: the host moved far, the door stays behind |
| M-08b | position measured from the wrong end (`L − p`) | `OG1`, `OG2`, `OR1`, `OG9` (non-central). Survives a centred fixture, recorded as the control |
| M-08c | the cut at the centre with zero width | `OG1` and every geometry test |
| M-08d | the referent direction dropped from the closure: an opening's edit dirties only the opening | `RF2`, `OR3`: the wall's pieces stale, `drift()` names the wall |
| M-08e | only one face cut (the right face carried across the gap) | `OG1`, `OG2`, `OG9`. Survives a probe that inspects one face only, recorded |
| M-08f | the cascade executed as a separate command after the edit | `CS1`, `OR5`: undo depth +2 |
| M-08r | references dropped from the closure entirely (06's closure) | `RF2`, `RF3`, `OR1`, `OR3` |
| M-08r2 | the referrer direction dropped | `RF3`, `OR1`, `OR4` |
| M-08t | referrers of the seeds only (the spike brief's rule) | `RF4`, `OR4` |
| M-08f0 | no cascade | `CS1`, `OR5`: a childless ghost group |
| M-08f2 | the cascade's inverse not folded into `r` | `CS1`'s undo (the door does not come back), `CS5` (the rollback leaves the door deleted) |
| M-08g | the symbol ignores its own group transform | `OR7` |
| M-08h | the symbol ignores the host's transform | `OG1`, `OR1`, `OR7` |
| M-08s | clamp into `[0, L]`, not the straight span | `OG2`, `OG9` |
| M-08snap | the cap-vertex snap removed | `OG9`: refused edits > 0 (spike: 66 of 1,244) |
| M-08p | the end grip does not rewrite openings' positions | `EG1` |
| M-08p2 | the anchored end reversed: positions rewritten when the end moves, kept when the start moves | `EG1`, `EG2` |
| M-08k | the centreline not split (one centreline across the gap) | `OG8` |
| M-08u | the no-fit window and gap drawn over the band (not translated) | `OG7`, on the window and on the gap |
| M-08o | T obstacles ignored | `OG3` |
| M-08x | crossings ignored | `OG4` |
| M-08w | the nearest stretch chosen without regard to width | `OG5` |
| M-08m | cuts not merged (each opening cut separately) | `OG6`: the tiling oracle's `overlap` > 0, or a refused region |
| M-08q | overlap reported by each opening (twice per pair) | `OG6`: two entries |
| M-08q2 | overlap reported by the higher handle | `OG6`: the reporter and the handle order |
| M-08v | the policy ignored: every referrer cascades | `CS3` |
| M-08l | the dangling-reference refusal removed | `DR1` |
| M-08y | `parametric.dangling` not reported | `DR2` |
| M-08n | `referrers` built by a scan over every object per referent (O(n²)) | `RC1`: the `references` call count exceeds 2n |
| M-08j | the gap generates no line (R1 as amended) | `OR8`: the gap cannot be picked |
| M-08j2 | the threshold line not inset (`m = 0`: jamb to jamb, touching the pieces) | `OR8`: the endpoints' coordinates, and the click after a later piece picks the wall |
| M-08i | `movable` ignored: an opening is captured by move and rotate | `SG2` |
| M-08z | the door's swing side from the opposite side of the click | `OT2` |
| M-08z2 | the hinge on the farther end's jamb | `OT2` |
| M-08z3 | the swing side from the centreline, not the band's midline (D14 amendment) | `OT2`, right-justified case |
| M-08sn | edge snaps removed | `OT3` |
| M-08pin | the Opening section's target read at focus loss | `OS2` |

### Differential check

- **`drift()` is empty** after every edit in every relational test.
- **A full regeneration from scratch agrees with the incremental one** on a
  plan of at least twenty walls with openings of every kind, T and X
  obstacles, a clamped and a no-fit opening, and an overlapping pair.
- **The tiling oracle's uncut band** is 07's stored outline of the twin
  document (above), so an error shared by the pieces and a recomputed band
  cannot hide.
- **The property run** (`OG9`): thousands of random walls and openings at
  the far origin, every stored piece triangulates, zero tiling violations.

## Exit gate

1. The four gate lines are green with `CI=true` **on the human's macOS
   machine** (engine, render layer with only its standing failures,
   harness, app), and `flutter build macos --release` and
   `flutter build web --release` are `✓ Built`. The Linux container's run
   is recorded as the Linux half; **the macOS half is owed by the human and
   is never simulated.**
2. An opening cuts **both** faces of its host at the documented position
   and width, verified by coordinates on a non-axis-aligned wall in a
   rotated group at the far origin, at a non-central position.
3. Moving or rotating the host moves its openings with it, in **one** undo
   step; undo and redo restore it exactly; a far move is included.
4. An end drag keeps openings put along the wall (D13), in one undo step;
   a whole-wall move keeps stored positions.
5. Deleting the host deletes its openings (the `cascade` policy) in
   **one** undo step, whatever deleted it; undo restores every child
   handle; the `orphan` policy keeps and regenerates its referrer (test
   client).
6. Save → load → save is byte-identical with the host relationship intact;
   `drift()` is empty after load; a dangling reference is reported, not
   repaired.
7. Two openings in one wall both cut correctly; overlapping ones cut their
   union and are reported once per pair.
8. Clamping, obstacles and no-fit behave as D7, D8 and D11 say, and are
   diagnosed as D17 says, and only those cases are.
9. Every stored piece triangulates: the property run refuses nothing and
   finds no tiling violation.
10. The closure regenerates the two-hop case (`drift()` empty).
11. The references survey is O(n), measured and pinned by its counter
    (D2).
12. The allocation invariants pass unchanged.
13. Draw order stays ascending; an opening's children keep their handles;
    a fitting symbol is not covered by its host's pieces (`RD1`).
14. The tools, the slide grip, the Opening section (pinned target, tool
    mode, focus hand-back) and the absence of move and rotate for openings
    behave as D14–D16 say.
15. The sample plan is rebuilt as D18 says; its carried-over tests pass;
    `drift()` and `diagnostics()` are empty.
16. Every named mutant is killed, M-08a as a structural fire on a scratch
    copy, all logged in `plan-08-mutation-log.md`.
17. **The human's look — owed by the human, never simulated:** on macOS,
    in Chrome and in Firefox: the three tools and their previews; doors,
    windows and gaps cutting walls at L, T and X; moving, end-dragging and
    deleting a wall with openings, and undo; the slide grip; the Opening
    section including tool mode and the pinned target; the sample plan on
    White and on Blueprint.

## Open questions

None blocks writing the plan. Question 1 is resolved; the other thirteen
were accepted as written by the controller on 2026-09-25. Each is a place where this spec interpreted
a decision or found a consequence the decisions did not settle; each has a
default above that the plan follows unless the human or the controller
rules otherwise.

1. **Resolved (controller, 2026-09-25).** R1's gap jamb lines coincided
   with the pieces' jamb edges, so a later piece covered one on Blueprint
   and won a click on it. R1 is amended: one threshold line on the
   centreline, inset from each jamb (D10), outside the left face when
   no-fit (D11). D12 now has no exception.
2. **"Hinge = the nearer end"** (decision 8) is read as the jamb nearer the
   host wall's nearer end (D14), because the click is at the opening's
   centre. The alternative, the jamb nearer the click, is undefined for a
   centred click.
3. **"The stretch nearest its position"** (decision 18) is read as the
   nearest stretch **wide enough** (D8). The literal reading makes an
   opening no-fit whenever the nearest stretch is too narrow, even if the
   wall has room elsewhere.
4. **"Stay put in world" on an end drag** (decision 15) is exact for a drag
   along the wall's line; when the drag swings the wall, openings keep
   their distance from the end that did not move (D13). Projection onto
   the new line was considered and rejected there.
5. **What the tools and the slide grip store** (D14, D16): the centre of the
   cut the opening gets, so a placement or a slide never creates a
   clamped opening. "Centred at the click" holds wherever the opening fits.
6. **The cascade triggers when a referent stops being a live object** (D4),
   not only when its node is removed (the spike). Detaching a wall's
   component or re-parenting its group also deletes its openings. No UI
   path does either.
7. **The dangling-reference refusal** (D5) is new: an edit that leaves a
   seeded `cascade` object referencing a non-object is refused. The
   decisions did not ask for it; it is the backstop that keeps decision 5's
   promise for hand-built commands.
8. **Obstacles** (D7) are a neighbour's T butt (07's own T cap interval
   against the host) and a crossing (its four face crossings). A free end
   poking into the band off the centreline, and collinear overlapping walls,
   are not obstacles, as 07 does not join them either.
9. **The no-fit symbol's side** (D11): a door draws on its swing side; a
   window and a gap draw against the host's **left** face, a fixed choice.
10. **Symbols over other walls' bands** (D12): a door near an acute corner
    can swing into the neighbouring wall's band, and a no-fit symbol can lie
    over a neighbour. Draw order decides what shows there, visibly only on
    Blueprint. Accepted.
11. **A mixed selection** (D16): openings are skipped by move and rotate,
    the rest moves, and a door selected with its wall follows the wall.
    The alternative, refusing the whole move, was not chosen.
12. **The JSON shape** (D6): all six keys for every kind, so a window and a
    gap carry an unused `hinge` and `swing`. A door-only shape would need a
    second read path; not worth it in v1.
13. **Each opening recomputes its host's joints and obstacles** (spike
    finding 7): once for the wall and once per opening in the same plan.
    Not memoised; RC2's wall-move timing includes it. A per-survey memo on
    `ParametricView` is the fix if a plan with many openings per wall is
    slow.
14. **A degenerate opening from a file** (D6) is a childless ghost and
    cannot be picked; only `diagnostics()` names it. As with 07's
    degenerate wall, no UI path makes one.
