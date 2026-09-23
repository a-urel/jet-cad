# SDD ledger — plan: docs/superpowers/plans/2026-09-23-grips-and-transform.md

Spec: docs/superpowers/specs/2026-09-23-grips-and-transform-design.md (revision 2, approved by the human 2026-09-23).
Branch plan-03/grips-and-transform, worktree .claude/worktrees/plan-03-grips-and-transform, cut from main at e376ced.
The plan's own Rulings 03-1..03-21 stand as written (drafted by an Opus subagent, checked by the controller against the spec: the eight spec-vs-code corrections verified).

## Pre-flight scan

| pair / task | produces → consumes | finding |
|---|---|---|
| T1 → T2 | grips.dart (Grip, leafGrips, reshapeLeaf) → rigidTransformLeaf appended to same file | same file, sequential; no conflict |
| T1,T2 → T4 | Grip/GripRole/leafGrips → GripCache | interface names match in plan text |
| T1,T2 → T6 | reshapeLeaf, rigidTransformLeaf → GripDrag | match |
| T3 → T6,T7 | resolveDragPoint, DragPoint, dragGridStepMm → GripDrag/SelectTool | match |
| T4 → T5,T7,T8,T9 | GripCache, grip_fixture (T4 version) → ToolContext.grips, overlay, shell | T7 rewrites grip_fixture: T4's tests must keep compiling against the rewrite — carry to T7 dispatch |
| T5 → T6,T7,T8 | Tool.cursor/selectionPreviewTransform/paintWorldOverlay, ToolContext fields, SnapSettings → consumers | match |
| T7 ↔ T8 | select_tool.dart: T7 drags; T8 adds guide/marker/reshape preview | same file, sequential; no conflict |
| T9 | shell owns caches; PlannerView signature changes | touches only app files |
| T10 | mutation firing; no surviving code change | cp-backed; restore + diff |
| T11,T12 | gates, docs | T12 archives ledger as last commit (repo convention overrides the skill's rm -rf) |

Per-task self-consistency: checked at interface level (Consumes/Produces blocks); deeper test↔code consistency left to the per-task review loop.

Ruling: the skill's "delete the workspace at the end" is replaced by the repo convention: archive the ledger to docs/superpowers/ledgers/2026-09-23-grips-and-transform/ as the branch's last commit — the repo's ledgers README requires it — cost if wrong: none.
Ruling: implementers on sonnet (the plan carries complete code), task reviewers on sonnet for engine Tasks 1–3 and opus for Tasks 4–9 (interaction and overlay subtleties), final review on opus — cost if wrong: a missed defect surfaces at the final review.

## Progress

### Task 1 — branch point (Step 1)

`flutter pub get` at the worktree root; one `analysis_options.yaml`
(`packages/jet_cad/analysis_options.yaml`) was rewritten and restored with
`git checkout --`. The four gate lines at the branch point (HEAD `e376ced`):

- `packages/jet_cad_2d`: `CI=true dart test` → `+862: All tests passed!`; `dart analyze` → `No issues found!`; `dart format --output=none --set-exit-if-changed .` → `Formatted 125 files (0 changed)`.
- `packages/jet_cad_2d_flutter`: `CI=true flutter test` → `+797 ~1 -5: Some tests failed.` with the five failing tests all `test/golden/text_ladder_golden_test.dart` (rungs 1-5, `RenderBackend.canvas`) — the documented standing exception; `flutter analyze` → `No issues found!`; `dart format` → `Formatted 148 files (0 changed)`.
- `apps/dev_harness_2d`: `CI=true flutter test --concurrency=1` → `+82: All tests passed!`; `flutter analyze` → `No issues found!`; `dart format` → `Formatted 22 files (0 changed)`.
- `apps/floor_planner`: `CI=true flutter test` → `+21: All tests passed!`; `flutter analyze` → `No issues found!`; `dart format` → `Formatted 7 files (0 changed)`; `flutter build macos --release` → built `floor_planner.app` (51.0MB); `flutter build web --release` → `✓ Built build/web`.

These match the Plan 04 merge counts named in the brief (862 / 797 + 1 skip
+ five goldens / 82 / 21 with both builds) exactly.

Task 1: minor (deferred): grips.dart:363,374 pointCount==0 guards on circle/arc untested (YAGNI or fixture)
Task 1: minor (deferred): grips.dart:441-450 radius-or-null sequence duplicated between circle and arc radius
Task 1: minor (deferred): _degenerateSweep near-2π branch (grips.dart:498) has no dedicated test — Task 10 must fire a mutant against it or add the test
Task 1: minor (deferred): barrel export order not alphabetical (brief-mandated placement)
Task 1: ⚠️ trailer verified by controller (git log -1 abd0d28: Opus 5.5 trailer present); branch-point gate counts recorded above by implementer.
Task 1: complete (commits e376ced..abd0d28, review clean)
Ruling T2-a: a commit's Co-Authored-By trailer names the model that actually wrote it (Sonnet-written commits say Sonnet), replacing the plan's fixed Opus 5.5 trailer and its grep check — attribution must be truthful; abd0d28 (Task 1, Sonnet-written, Opus 5.5 trailer) is left as is rather than rewriting history — cost if wrong: trailer inconsistency in the log only.
Task 2: Important (plan-mandated) trailer text — covered by Ruling T2-a (truthful per-model trailer); no fix dispatched.
Task 2: minor (deferred): rigidTransformLeaf arc/text branches discard transformedBy's scalars copy (one throwaway Float64List per call, release-rate only)
Task 2: minor (deferred): arc branch `scalars.length >= 2` guard is unreachable (arcs always carry 3 scalars) — brief-inherited
Task 2: complete (commits abd0d28..2612233, review clean)
Task 3: ⚠️ trailer verified by controller (7258df6: Sonnet 5 trailer, per Ruling T2-a).
Task 3: minor (deferred): DragPoint reuse reset (drag_snap.dart objectKind/grid reset at call start) has no test reusing one DragPoint across calls — Task 10 should fire a mutant or add the reuse test
Task 3: debt (out of scope): PageComponent.copyWith(gridStepMm: <int>) throws (page_component.dart:168-170 `as double?`) — pre-existing Plan 04 bug; offered to the human as a separate fix task.
Task 3: complete (commits 2612233..7258df6, review clean)
Task 4: minor (deferred → Task 10): GripCache hover-skip (grip_cache.dart:160 early return) unguarded — add C8 (select line, hot=1, change hover, expect hot==1) + a named mutant in Task 10
Task 4: minor (deferred → Task 10): hitTest nearest-wins (`d < bestDistance`) unguarded — add a two-grips-within-7px probe + mutant in Task 10; the ordinal clause is an equivalent mutant (strict improvement, ascending ordinals) — log it as equivalent
Task 4: minor (deferred): C2 overclaims M-03ah (compares against worldBoundsOf, mutated alike); O1 kills M-03ah — fix the mutant-table row in Task 10
Task 4: minor (deferred): O1 maxY reason text inaccurate; C6 title says "nearest"
Task 4: minor (deferred): root-owner filter (grip_cache.dart:176) untested — defensive, resolveHit only yields root keys
Task 4: minor (deferred → Task 9): GripCache must be constructed after OutlineCache (Ruling 03-19) — check the shell wiring order in Task 9
Task 4: minor (deferred): selection.keys.toSet() and worldBoundsOf per-vertex allocations at event/rebuild rate (not frame path)
Task 4: complete (commits 7258df6..70bdde1, review clean)
Task 5: minor (deferred → Task 10): cursor ListenableBuilder mutant reasoned, not fired — Task 10 fires it
Task 5: complete (commits 70bdde1..8ea39b3, review clean)
Task 6: minor (deferred → Task 10): read→peek in GripDrag._capture is an equivalent mutant today (GeometryStore.replace swaps objects) — log as equivalent if listed
Task 6: minor (deferred): M-03t "gone" assertion lacks an isNotNull re-assert after the instA undo (grip_drag_test)
Task 6: minor (deferred): M-03p test's undoDepth==0 assertion is vacuous at GripDrag level (tool-level test owns invariant 1)
Task 6: minor (deferred): GripDrag.capabilities (from capture type) vs member capabilities — two sources of truth
Task 6: minor (deferred): leaf-capture sequence duplicated between reshape and _capture
Task 6: complete (commits 8ea39b3..2f2bab3, review clean)
Task 7: review — Needs fixes: I1 camera-listener leak unguarded (T14 post-release check cannot fail; leak accumulates listeners per drag); I2 centre-grip base test degenerate (press on the grip's exact pixel).
Ruling T7-a: the two plan-mandated Important test gaps are fixed in this task (the plan text is the cause; the spec's testing bar outranks it) — cost if wrong: none, tests only.
Ruling T7-b: minors M1 (layer didUpdateWidget/activate untested) and M3 (stale press-time grip index/box can RangeError after an undo inside the slop) enter this fix round too — M3 is a reachable crash, M1 is the only guard for the layer fix's reparent path — cost if wrong: a few extra test lines.
Task 7: minor (deferred): Ruling 03-6's 3b refuse-before-toggle untested (shift-press unselected leaf under runtime) — Task 10 mutant
Task 7: minor (deferred): SelectTool.onPointerExit still cancels a live drag (only the layer's capture guard prevents it) — document or drop in final wave
Task 7: minor (deferred): M-03s fixture page origin (7000,3000) sits on the absolute lattice — an origin-ignoring grid passes T5
Task 7: minor (deferred): _endDrag resets cursor to defer until the next hover
Task 7: minor (deferred → Task 9): shell tests should remove the planner mid-drag (same deactivate assert class)
Task 7: minor (deferred → Task 10/12): M-03ab row now names ValueListenableBuilder; D5 amendment (ValueListenableBuilder mirror) in Task 12; correct Ruling 03-7's cost sentence
Task 7: fix round 1/5 (4 addressed, 0 open — listener-leak kill, centre-grip base kill, layer didUpdateWidget/activate tests, stale press grip/box guard; commits 433fe9c..b7de33a). Re-reviewer fired each mutant itself and restored; tree verified clean by controller.
Task 7: minor (deferred): stale-body click release still uses press-time _downKey (02 behaviour)
Task 7: complete (commits 2f2bab3..b7de33a, review clean after 1 fix round)
Task 8: minor (deferred → Task 10): Ruling 03-10 buffer rule untested — add a two-frame test on ONE painter (300 grips → reselect 10 → paint twice: args length == 2*count, identical buffer) + mutants (per-frame alloc; `<` capacity-grow which leaves stale grips drawn)
Task 8: minor (deferred → Task 10): reshape preview arc/circle branches of _reshapePath untested (y-flip/origin subtlety)
Task 8: minor (deferred): preview cross allocates 4 Offsets per selected point per frame (02's pattern, brief-mandated)
Task 8: minor (deferred): snap marker insertion/intersection/grid geometry only partly asserted; rotation-grip stem/radius, guide 1.0 and marker 1.5 strokes unasserted
Task 8: ⚠️ overlay repaint must include GripCache in production — carry to Task 9
Task 8: complete (commits b7de33a..f6810fb, review clean)
Task 9: minor (deferred): initialCamera seam and no-page ViewportTransform.fit fallback never exercised by a test (main.dart:51-53, 86-91)
Task 9: minor (deferred): shell builds an unused FlutterTextMeasurer when a document is injected
Task 9: minor (deferred): report prose miscounts (834 vs pasted +846) — only app files changed, verified by controller
Task 9: complete (commits f6810fb..32fa2cd, review clean)
Task 10: reviewer independently re-fired M-03a, M-03i, M-03u, M-03bf, M-03n — all reproduced the logged failures; tree clean.
Task 10: minor (deferred → Task 12): mutation log prose says "26+1+23+10 = 61" (is 60) and "10 killed, each behind a new test" (7 new tests; bc, bd already guarded) — fix the two sentences in Task 12
Task 10: complete (commits 32fa2cd..061fd85, review clean) — tally 62 exercised: 60 killed, 1 designed survivor (M-03e), 1 equivalent (M-03ai ordinal clause)
Ruling T11-a: Task 11 ran the two allocation invariants and the greps but not the four gate lines its brief lists; not re-dispatched — Task 12 runs all four gate lines (with both release builds) on the final tree, which subsumes Task 11's run — cost if wrong: none, the final-tree run is the stronger evidence.
Task 11: complete (commits 061fd85..7879e36, review clean; the two extra grep hits independently confirmed as a comment and a construction)
Ruling T12-a: Task 12 does Steps 1–4 only; Step 5's ledger archive runs after the final whole-branch review and its fix wave, so the archive stays the branch's last commit before the merge — cost if wrong: none.
Task 12: Important (out of the brief's scope, self-disclosed) STATUS.md "Branch and worktree map" (~1246-1251) says "No worktrees. Nothing is in flight." — carried into the final fix wave with the final review's findings (one fix dispatch).
Task 12: minor (deferred): note's residual-magnitude derivations are reasoning, not pasted output — label them as derived
Task 12: complete (commits 7879e36..136af89, review clean for Steps 1–4; archive deferred per T12-a)
Final review (Opus, HEAD 136af89): With fixes — I1 grip draw positions / rotation disc / circle reshape preview unguarded (3 surviving mutants); I2 STATUS branch map + fix-branch references wrong (3 worktrees; fix/page-copywith-num 8385753 and fix/root-transform-identity 776f201 committed by other sessions, not merged); minors: grip-to-grip hover repaint unguarded, shift mid-drag not re-resolved, grips.dart θ=0 comment, mutation tally line, stale barrel-order debt line.
Ruling F-a: one fix wave carries the final review's full list plus Task 12's Important (STATUS map) and the reviewer's fix-before-merge triage; the shift-mid-drag minor (A5) is fixed rather than deferred because it is a small, user-visible interaction bug in this plan's own feature — cost if wrong: a small extra production diff, covered by a named mutant.
Ruling F-b: the two other-session fix branches are recorded in STATUS, not merged or touched by this plan; their merge order relative to this branch is the human's decision — cost if wrong: a doc conflict at merge time, resolved by whichever merges second.
Final fix wave: commits 136af89..fe432ba (722904b tests M-03bh/bi/bj; 0cac4f4 shift mid-drag re-target M-03bl + M-03bk test + onPointerExit doc; 509b9f3 grips.dart θ=0 comment; fe432ba docs: STATUS branch map, fix-branch references, Plan 04 merged line, tally 68 = 65 killed + 1 designed survivor + 2 equivalent). Gates green on 509b9f3: engine 890, render 854 + 1 skip + 5 goldens, harness 82, app 26, both builds.
Final fix wave re-review (Opus): all A1–A7 and B1–B6 ADDRESSED; no new Critical/Important. Minor doc slip "seven"→"six" (mutation log line 8) fixed by the controller in the archive commit.
Ruling F-c: the controller made the one-word "seven"→"six" correction itself in the archive commit instead of a second fix dispatch — a verified one-word doc slip, no code — cost if wrong: none.
Parked — b/c-transposition blindness under the reflecting test cameras (gripCamera and the app test camera): real but latent (no product camera makes b != c; fit/pan/zoom keep b == c), rated Minor by the re-review; P2 now also runs flipY:false; the other six projection sites offered to the human as a follow-up task — Ruling: park, not a merge blocker — cost if wrong: a future non-reflecting camera could hide a b/c swap until that follow-up lands.
Parked — A5 edge: with both shift keys held, releasing one turns ortho off until the next pointer move (self-correcting) — Minor.
Parked — fix/root-transform-identity (776f201) conflicts with this branch in STATUS.md only (merge-tree dry run); whichever merges second re-runs the full four-line gate on the merged tree.
Ledger archived to docs/superpowers/ledgers/2026-09-23-grips-and-transform/ as the branch's last commit before the merge (Ruling T12-a). Exit gate 15 of 16; criterion 16 (the human's look) OWED.
