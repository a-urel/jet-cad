# SDD ledger — plan: docs/superpowers/plans/2026-09-23-drawing-tools.md

**Spec:** docs/superpowers/specs/2026-09-23-drawing-tools-design.md
(revision 2, approved by the human on 2026-09-23 with "Proceed").

**Plan:** approved, and the human chose subagent-driven execution. The
branch is `plan-05/drawing-tools`, cut from `main` at `7dac3b5` in the
worktree `.claude/worktrees/quizzical-jemison-7537de`.

**The plan's Rulings 05-1…05-15 stand as written.**

## Rulings
- **Ruling P-1: this session's worktree hosts the branch.** The plan names
  `.claude/worktrees/plan-05-drawing-tools`.
  - Why: this session's file writes are confined to its own worktree
    (the PreToolUse hook refused writes elsewhere), so subagents could not
    write into a second one.
  - Cost if wrong: none. The branch and its history are identical.
- **Ruling P-2: the ledger is archived, not deleted.** The skill's "delete
  the workspace" becomes the repo convention: archive to
  `docs/superpowers/ledgers/2026-09-23-drawing-tools/` as the branch's
  last commit. Cost if wrong: none.
- **Ruling P-3: the models.**
  - Implementers on sonnet: the plan carries complete code.
  - Task reviewers on sonnet for Tasks 1–2 (pure engine), and on opus for
    Tasks 3–8 (interaction, focus and key routing).
  - The final review on opus.
  - Cost if wrong: a missed defect surfaces at the final review.
- **Ruling P-4: Tasks 9–11 are dispatched too.** Task 9 (mutation firing)
  and Task 10 (greps) go to one sonnet implementer each. Task 11's docs
  go to sonnet, and I verify the counts myself. Cost if wrong: none.

## Pre-flight scan

| pair / task | produces → consumes | finding |
|---|---|---|
| T1 → T2 | drafting.dart → SweepTracker appended; T2 adds `import 'dart:math'` | same file, sequential; no conflict |
| T1 → T3..T8 | addDrafted, addDraftedRegion, the payload builders, the predicates, textHeightMm, kDraftFillColor | names match in every Consumes block |
| T2 → T5 | SweepTracker.begin/track/sweepTo/start → ArcTool | match |
| T3 → T4,T5,T6 | PlacementTool API (acceptingSelf, band, bandPaint, commitShape, hovered, clearShape, isPending, hoverPoint, hoverVisible), draw_fixture | match; the fixture's `KeyEventResult` import is used by `keyDown`'s return type |
| T3 ↔ T4 | placement_tool_test B4 (M-05m unit) vs T7 A4 | complementary; no conflict |
| T4 → T7 | PolylineTool/RectangleTool({fill}) → the shell's `_fill` | match |
| T6 → T7 | TextTool.pending, controller, commitText, cancelText → TextEntryOverlay | match |
| T7 → T8 | the app files touched are disjoint (startup_plan vs main/planner_view) | no conflict |
| T7 A-tests ↔ T8 | A-tests use their own drawDoc, not startupPlan | independent of T8's count change |
| T9 | mutation edits name the functions from T1–T8 | consistent with the plan's code; M-05m names B4 and A4 |
| T10, T11 | greps, docs | T11 archives the ledger last |

**Per-task self-consistency:**
- **T1:** E1–E10 against `drafting.dart` code. E9 asserts that the
  bow-tie's triangulation is empty; its code relies on
  `triangulationFor`. Consistent.
- **T2:** S1–S6 and the differential against `SweepTracker`. The
  arithmetic was checked by hand while planning. Consistent.
- **T3:** B1–B9 and L1–L6 against PlacementTool/LineTool. L2 relies on
  selfSnap after one segment; L3 on refusal before. Consistent.
- **T4:** PL1–PL9 (the plan text also has PL9, beyond the file table's
  PL1–PL8), R1–R5, OV1–OV2. PL7's geometry was fixed while planning.
  Consistent.
- **T5:** C1–C3 and AR1–AR6. AR6 has a documented fallback.
- **T6:** TX1–TX7. Consistent.
- **T7:** A1–A12, and the shell code. A7 uses `text-entry-box`, which the
  overlay code provides. Consistent.
- **T8:** SP1–SP2. It expects 509 live entities (Ruling 05-12).

**Ruling P-5: the plan's file table lists PL1–PL8, but Task 4 has
PL1–PL9.** PL9 is M-05l's test. The task text governs. Cost if wrong:
none.

## Progress
- **Ruling P-6: a commit trailer names the model that actually wrote the
  commit.** The plan's `grep -c "Opus 5.5"` check becomes `grep -c
  "Co-Authored-By: Claude"`.
  - Why: attribution must be truthful. This is Plan 03's Ruling T2-a.
  - Where it came from: Task 1's reviewer raised it as a Minor.
  - Cost if wrong: none.
- Task 1: complete (commits 7dac3b5..607bb82, review clean; one Minor, the
  trailer, ruled by P-6). Engine 904.
- Task 2: complete (commits 607bb82..b7663b7, review clean). Engine 911.
  The differential: `SWEEP differential: checked 500, skipped 0`.
- Task 2: minor (deferred): S5's out-and-back half no longer discriminates
  M-05z, because the float residue is 4.4e-16 > 0. M-05z stays killed by
  S5's no-travel half, and by AR4 in Task 5.
- **Ruling T3-a: fix both of Task 3's Important findings.** They are
  plan-mandated, in B6 and L5.
  - Why: the spec binds Review Focus 3 (the hover after a pan) and the
    Tolerance decision, and the reviewer showed each test cannot fail
    under a named mutant.
  - Cost if wrong: two test-only edits.
- **Task 3: minors (deferred):**
  - The byte-identity checks in B4 and B9 are equivalent for LineTool.
    M-05l is killed by PL9 in Task 4.
  - Escape after committed segments is untested.
  - Nothing tests `PlacementTool.dispose`'s detach, Ruling 05-13 (a
    pressed move), or the primary-button guard.
  - L6 checks only part of the band's bounds, and not its stroke width.
- Task 3: fix round 1/5 (2 addressed, 0 open: the B6/B7 hover exactness
  and L5's Tolerance fixture; commits a5ed921..beb892a).
- Task 3: complete (commits b7663b7..beb892a, review clean). Render layer
  873 + 1 skip + the five goldens.
- Task 4: complete (commits beb892a..0ae93ae, review clean). Render layer
  892. R2's coordinates were moved off a 20 mm grid tie (7010 → 7009); the
  reviewer accepted it.
- **Task 4: minors (deferred):**
  - PL8 kills the plan's form of M-05w, but not the "selfSnap on the
    resolved point" form. The fix is `first = anchor + 13px` with the
    click at `anchor + 5px`.
  - Degeneracy is tested only at exact 0 (R2, PL7, engine E10), so a
    Tolerance → `== 0` mutant survives.
  - R2's comment points to the git-ignored report.
  - `payloadOf` and `ofKind` are duplicated across the draw tests.
  - RectangleTool's `orthoBase` override is indistinguishable from the
    default.
- **Ruling T5-a: AR5 is replaced by an arc degenerate-radius test.** The
  review found AR5 cannot fail (plan-mandated): the fill notifier is never
  passed to ArcTool.
  - "The arc ignores Fill" holds by construction, because ArcTool takes no
    fill.
  - The new AR5 kills a real mutant: dropping `isDegenerateRadius` in
    ArcTool.
  - Cost if wrong: exit criterion 9's "arc ignores Fill" loses its test
    witness and is argued from the constructor instead.
- **Task 5: minors (deferred):**
  - C3 tests only r == 0 exactly.
  - The circle and arc rubber bands are never painted in a test.
  - The report's transcript and mutant descriptions are loose.
- Task 5: fix round 1/5 (2 addressed, 0 open: AR5 replaced, and the report
  count reconciled; commits 9247856..26722a5).
- Task 5: complete (commits 0ae93ae..26722a5, review clean). Render layer
  903.
- Task 6: complete (commits 26722a5..a07ca51, review clean). Render layer
  911.
- **Task 6: minors (deferred):**
  - `cancelText` is untested at the tool level. Task 7's A6 Escape flow
    covers it end to end.
  - The camera-listener detach after an external `commitText` is
    unpinned.
  - TX4 does not check the commit position.
  - TX6 does not check the string's content.
  - TX7's `orthoBase` override is equivalent to the default.
  - TX2–TX7 run with flipY true only.
- **Ruling T7-a: spec D3 wins over the plan's Review Focus 2.** Every
  key-down mid-shape is swallowed, so a tool shortcut does not switch tools
  mid-polyline.
  - How switching works mid-shape: Escape first, or the palette.
    ToolController.activate cancels byte-identically.
  - A10 tests that pressing L mid-polyline is ignored, and that a palette
    switch is byte-identical.
  - Why: the spec is binding, and Review Focus 2 was the plan's own
    addition, contradicting D3 and B5.
  - Cost if wrong: a user must press Escape before a tool letter
    mid-shape. The look (criterion 14) will judge it.
- **Ruling T7-b: D9's "any other loss of focus cancels" means a loss of
  focus inside the app.**
  - While the app is not resumed, the field ignores its blur, and the
    focus manager restores it on resume with the text intact.
  - Why: a window switch otherwise cancelled the text and left focus on the
    root scope, so every shell shortcut was dead. The reviewer reproduced
    it with a probe.
  - Cost if wrong: typed text survives a window switch, which a user would
    likely expect anyway.
- **Ruling T7-c: Escape joins the guard's map.** D9 names "Escape … as the
  shell binds them", and the shell binds Escape. Without it, Escape in
  page-scale dropped a pending shape. Cost if wrong: none.
- **Task 7: minors (deferred):**
  - A12 does not cover Fill/F under runtime permissions.
  - A8 covers only L A T F V, and A9 only meta+Z, not ctrl+Z.
  - A7 pans but never zooms.
  - The palette highlight is untested, and A6 does not check the committed
    string.
  - The guard's letters duplicate `_entries`.
- Task 7: fix round 1/5 (3 addressed, 0 open: the lifecycle guard with
  A13/A15, the Escape guard with A14, and A10; commits b06e908..1445f9e).
  The round was interrupted once by an API rate limit and resumed; the
  uncommitted edits were verified as mutant-free.
- Task 7: complete (commits a07ca51..1445f9e, review clean). App 41, which
  is 26 + A1–A15.
- **Ruling T7-d: the view's root is a `Flow`, not the spec's `Stack`.**
  - Why: the implementer found that a `Stack` raises "markNeedsBuild()
    called during build" on teardown with text pending. Paint and hit
    order are the same. The reviewer confirmed it.
  - The spec's D9 wording needs an "amended at execution" note in Task 11.
  - Cost if wrong: none.
- Task 8: complete (commits 1445f9e..c4fcac4, review clean). App 43.
  Live count 509.
- **Ruling T9-a: PL8's fixture changes in Task 9.** The first vertex moves
  to anchor+13px and the close click to anchor+5px.
  - Why: the extra mutant M-05w′ (selfSnap applied to the resolved point)
    survived PL8, as the Task 4 reviewer predicted. The spec permits no
    designed survivor, and the fix is test-only.
  - Cost if wrong: none.
- Task 9: fix round 1/5 (Ruling T9-a: PL8's fixture; M-05w′ is killed;
  commits 6d98d72..5c55000).
- Task 9: complete (commits c4fcac4..5c55000). 27 fired, 27 killed.
  - The reviewer's one Important finding is the trailer text, which is
    already ruled by P-6 (truthful attribution). The plan's
    `grep "Opus 5.5"` gate is superseded by `grep -c "Co-Authored-By:
    Claude"`.
- **Task 9: minors (deferred):**
  - Most log `result:` lines are condensed rather than verbatim runner
    blocks. The values cross-checked were genuine.
  - The log's trailing "Fix round 1" section duplicates the M-05w and
    M-05w′ entries.
- **Ruling T10-a: Task 10's review is the controller re-running its
  checks.** The deliverable is command transcripts, not code.
  - Reproduced: both diffs 0; one `Path()` (the band field); one
    `handleSeed` hit (startup_plan `_Pen`, pre-existing); 14 of 14
    trailers; the 3 pure-Dart hits are pre-existing doc comments.
  - Cost if wrong: none.
- Task 10: complete (commits 5c55000..3957d52, controller-verified).
- **Ruling T11-a: Task 11 runs in two parts.** Steps 1–4 (results, spec
  amendments, STATUS, roadmap) come before the final review. The ledger
  archive comes after the final review and its fix wave, as the branch's
  last commit, as Plan 03 did.
- Task 11 (steps 1–4): complete (commit 3957d52..d45b5d7, docs; not separately reviewed — the final review covers it).

## Final review (7dac3b5..d45b5d7, opus): "With fixes"; Critical none

- **Ruling F-1: fix Important 1.**
  - The problem: the opaque furniture fills hide four door leaves and
    swings (counter, bed 2, sofa). That breaks D14's "doors keep their
    look".
  - The fix: move the colliding pieces clear of the swings, and add an
    SP3 with a named mutant.
  - Cost if wrong: the sample plan layout changes slightly.
- **Ruling F-2: fix Important 2.** F3 (object snap) and F (Fill), with no
  modifiers, return `ignored` mid-shape, so they reach the shell. The spec
  gets a D3 amendment.
  - Why: D3's reason is that undo and redo never land on a half-placed
    shape. F3 and F never touch the document. Without this, F3 (the only
    object-snap toggle) is unusable mid-polyline.
  - Cost if wrong: two keys act mid-shape. This is reversible and flagged
    to the human.
- **Ruling F-3: fold Minor 3 into the wave.** `cancel` hides the stale hover
  marker, a one-liner with a test. Cost if wrong: none.
- **Ruling F-4: Minor 4 is debt.** A pointer cancel drops the whole pending
  shape through 02's frozen API. Cost if wrong: none.
- **Ruling F-5: Minor 5 goes to the look.** The text field can clip near
  the canvas edges; it is added to criterion 14's list. Cost if wrong: a
  cosmetic clip.
- **Ruling F-6: fix Minors 6 and 7.** The doc slips get fixed, and the
  flipY coverage gets a Deviations entry. Cost if wrong: none.
- **Resolved in the deferred minors:** Task 4's PL8 note (by T9-a). Task 4's
  "degeneracy only at zero" is mostly out of date: E10 covers the segment
  and radius checks, and only `isDegenerateRectangle` lacks a
  near-tolerance case.
- Final fix wave (commits d45b5d7..f8b4269). The scoped re-review (opus)
  found F-1, F-2, F-3 and F-6 addressed. Controller run: render 913, app
  45.
- **Ruling F-7: the stale counts are fixed in the closing docs commit.**
  STATUS and the results note stated Task 10's counts (render 911, app 43,
  27/27, five amendments, ten look items).
  - The closing commit records the gate at the final code tree: engine 911,
    render 913 + 1 skip + the five goldens, harness 82, app 45, both
    builds, mutants 30/30, six amendments, thirteen look items.
  - Why: docs only, and part of finishing. Cost if wrong: none.
- **Ruling F-8: the counter's new top leg sits across the kitchen/living
  doorway.** Parked as debt, and added to the look list.
  - Why: it is not a leaf or swing overlap, so SP3 is clean. It is a
    sample-plan layout judgment, and the skill allows no second code wave.
  - The suggested fix, for a fix branch if the look agrees: a south leg at
    x 7200..9100, y 400..1000, plus the east leg at x 8500..9100 up to
    y 3100.
  - Cost if wrong: the sample plan shows a doorway opening onto a counter
    until then.
- **Ruling F-9: the untested modifier guard is parked as debt.** A mutant
  dropping `&& !_hasModifier()` in PlacementTool.onKey survives. Cmd+F or
  Ctrl+F mid-shape would then reach the browser's find on the web.
  - Why: the code is correct as written; only a test is missing.
  - Cost if wrong: a later regression of the guard would go unnoticed.
- **Ruling F-10: the out-of-scope observations are recorded, not fixed.**
  - Escape mid-shape now also hides the marker until the next move (a
    side effect of F-3).
  - SP3 samples 5 points per door shape.
  - Cost if wrong: cosmetic.
