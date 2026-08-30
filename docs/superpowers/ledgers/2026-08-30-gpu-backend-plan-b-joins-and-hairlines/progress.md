# SDD ledger — plan: docs/superpowers/plans/2026-08-30-gpu-backend-plan-b-joins-and-hairlines.md

Spec (binding authority): docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md (revision 4).
Predecessor ledger: docs/superpowers/ledgers/2026-08-29-gpu-backend-plan-a-seam-and-strokes/progress.md
Branch: plan-b/joins-and-hairlines, cut from main at 5c94e11 (the plan's own commit).
Mode: subagent-driven development. Human chose both on 2026-08-30.

=== PRE-FLIGHT CONFLICT SCAN ===

Shared-file pairs. One row per pair of tasks that touch one file or interface.

| file / interface | tasks | what one produces vs what the other consumes | finding |
|---|---|---|---|
| lib/src/gpu/instance_record.dart | 2 only | -- | clean |
| lib/src/gpu/resident_geometry.dart | 2 only | -- | clean |
| lib/src/gpu/gpu_draw_backend.dart | 2 only (setCullMode) | -- | clean |
| lib/src/gpu/geometry_collector.dart | 3, 4, 5, 6 | 3 adds _coveredArgb; 4 adds the run machine and rewrites polyline; 5 adds _flatten calling 4's machine; 6 adds point() using 3's _coveredArgb | ORDER-DEPENDENT, and the plan's order (3 -> 4 -> 5 -> 6) is the only one that works: 4 consumes 3's _coveredArgb, 5 consumes 4's _beginRun/_runTo/_endRun, 6 consumes 3's. No task may be reordered. Carried into every dispatch. |
| test/gpu/geometry_collector_test.dart | 3, 4, 5, 6 | each appends tests | clean -- append-only, no task rewrites another's assertions |
| test/gpu/collector_differential_test.dart | 2, 4, 5, 6, 9 | Plan A's oracle rebuilds PolylineOps only and asserts instanceCount == segment count, with HARDCODED slot indices o+1..o+9 | **CONFLICT — see Ruling B5.** Four tasks break this file and the plan only assigns it to 9. |
| test/support/instance_expander.dart | 8 creates, 10 mutates | 10 mutates and restores | clean |
| test/gpu/resident_pixel_differential_test.dart | 9 creates, 10 extends (the 3x arm) | 10 adds a scaled arm | clean |
| shaders/*, assets/shaders/cad.shaderbundle | 7 only | 8 transcribes 7's output but does not edit it | clean; 8's dispatch must carry "read cad_stroke.vert, transcribe it, do not improve it" |
| ResidentGeometry.kCornerVertices | 2 writes, 8 reads | 8 reads it live rather than restating | clean, and deliberately so |
| apps/dev_harness_2d | 1, 11 | 1 moves the arm; 11 runs it | clean |
| STATUS.md, docs/superpowers/notes | 10, 11 | 10 writes the mutation log, 11 the results note and STATUS | clean |

Self-consistency, one row per task: does the task's own text agree with itself?

| task | tests specified vs code specified | files created vs files later touched | finding |
|---|---|---|---|
| 1 | no new tests; the gate is the existing harness suite unchanged | creates gpu_arm.dart, later untouched | clean |
| 2 | 4 record tests + 3 corner tests against the code shown | renames StrokeFieldOffset and kStrokeVertexLayout; every later reference in the plan uses the new names | clean |
| 3 | 3 tests; the code adds _coveredArgb and hoists argb in polyline | -- | clean |
| 4 | 5 tests; the code adds the run machine and rewrites polyline and _emit | Step 6 says the suite "may now show the differential test failing" and to mark DONE_WITH_CONCERNS -- while the Global Constraints say every task ends green | **SELF-CONTRADICTION — see Ruling B5.** |
| 5 | 4 tests; _flatten mirrors the reference | uses VerticesDrawSink.kFlattenTolerance / kMaxFlattenSegments in the TEST, its own copies in lib | verified both constants are public (vertices_draw_sink.dart:139,146) -- clean |
| 6 | 3 tests; point() and the skippedOps sentence | asserts skippedOps == 3 for fill/fillCircle/text | clean |
| 7 | no Dart tests by construction; the gate is 8, 9 and 11 | rebuilds the bundle | clean, and the plan says so in as many words |
| 8 | 7 tests, all hand-derived | creates the expander as a DELIBERATE SECOND COPY of the shader | **PLAN-MANDATED RUBRIC DEFECT — see Ruling B6.** |
| 9 | 2 tests plus 4 mutations; creates the comparison helper | Step 1 says to verify TriangleRasterizer's signature before writing the code | clean, and the risk is stated in the plan's own self-review |
| 10 | fires M-B9 and M-B10, collects the rest | M-B10 may be unkillable at the identity transform; the step says to add a 3x arm and re-fire | clean -- the branch is pre-committed rather than discovered |
| 11 | scores 11 criteria | -- | clean |

=== RULINGS MADE BEFORE EXECUTION ===

Ruling B5: `test/gpu/collector_differential_test.dart` is updated by EVERY task that changes
  what the collector emits or where a field sits -- Task 2 (the record grows to 12 floats, so the
  hardcoded o+1..o+9 indices are wrong from that task onward), Task 4 (joins appear between
  segments), Task 5 (circle 701 and arc 703 in `differentialFixture` stop being skipped) and
  Task 6 (point 840 stops being skipped). NOT all at once in Task 9.
  Why: the plan assigns the whole repair to Task 9 and tells Task 4 to report DONE_WITH_CONCERNS
  on a red suite. That contradicts the Global Constraint that every task ends green, and it would
  leave Tasks 5, 6, 7 and 8 all running against a knowingly red suite -- at which point a NEW
  failure in any of them is invisible.
  Verified rather than assumed: `differentialFixture` (test/support/fixtures.dart:58-100) contains
  EntityKind.circle (701), EntityKind.arc (703) and EntityKind.point (840), all of which the
  Plan A collector counts as skippedOps and Plan B draws. Confirmed by reading the fixture.
  Task 2 additionally replaces the hardcoded slot indices with `InstanceFieldOffset.*` so no later
  task has to chase literals.
  Task 9 keeps ONLY the alpha/hairline extension the Plan A ledger's Task 3 ruling deferred to it.
  Cost if wrong: four tasks each carry a small extra edit to one test file instead of one task
  carrying a large one. If I have misjudged, the cost is that the oracle is touched more often than
  necessary -- visible in four diffs and reversible, where a suite red across five consecutive
  tasks is not.

Ruling B6: Task 8's `test/support/instance_expander.dart` is a DELIBERATE second copy of
  `shaders/cad_stroke.vert`, and reviewers are told this UP FRONT so they do not spend a round
  rediscovering it.
  Per the reviewer rubric, plan-mandated duplication of a logic block is still a finding and must
  be reported as Important, labeled plan-mandated -- the plan does not grade its own work. It is
  pre-empted here rather than suppressed: the reviewer should report it, and this ruling is the
  answer already on the record.
  Why the duplication is taken anyway: `flutter test` has no GPU, so every line of the vertex
  shader is otherwise unreachable by this package's suite -- including the miter arithmetic, which
  is the single most error-prone thing this plan adds. The alternative is shipping fifty statements
  gated only by a device run, which is how Plan A shipped four defects in its own sample code. The
  duplication's failure mode (the two copies drift) is one file diff away and is named in both
  files' doc comments; the alternative's failure mode is silent.
  Cost if wrong: a divergence between the Dart copy and the GLSL passes `flutter test` and fails on
  a device. Task 11's device run is the backstop, and Task 7 Step 4's bundle decode plus the paired
  doc comments are what make the diff findable.

Ruling B7: Task 4's Step 6 instruction to mark DONE_WITH_CONCERNS on a red differential is
  SUPERSEDED by Ruling B5. Task 4's dispatch carries the corrected instruction: extend the oracle
  for joins within the task, and end green like every other task.
  Cost if wrong: none identified -- this is the mechanical consequence of B5.

=== TASK LOG ===
Task 1: dispatched (sonnet), BASE 5c94e11. Pure refactor, STATUS.md-mandated.
Task 1: implementer DONE — commit 0615eb0 "refactor(harness): the GPU arm moves out of main.dart
  into its own file". 550 insertions to gpu_arm.dart, 558 deletions from main.dart. Harness 72/72
  before AND after (exit=0); jet_cad_2d_flutter 439 pass; analyze and format clean both packages.
  Disclosed three changes beyond the raw move: a dead `kIsWeb` import removed, an
  `ignore_for_file: avoid_print` added to the new file, and `_pumpFrame` -> `pumpFrame`.
Task 1: review dispatched (sonnet), diff 5c94e11..0615eb0.
Task 1: review — APPROVED, one Important, two Minor. The reviewer did the thing that makes this
  verdict worth having: it EXTRACTED the deleted block (diff 756-1292, 537 lines) and the moved
  body (diff 31-567, 537 lines) and diffed them directly, confirming byte-for-byte that the only
  differences are the six disclosed rename sites. It also reconciled the 12-line stat gap
  arithmetically to the line. All three of the implementer's claims verified independently.
  IMPORTANT 1: gpu_arm.dart:28 imports main.dart while main.dart:594 imports gpu_arm.dart -- a
    cycle. Neither widget_arm.dart nor widget_arm_rig.dart imports main.dart at all;
    widget_arm_rig.dart:223-226 keeps its own local _pumpFrame instead. The brief's Step 3 gave two
    instructions pulling opposite ways ("match the sibling's import direction" vs "rename rather
    than duplicate") and the implementer read the second as licence for the back-import.
  MINOR 2: the report's Step 4 arithmetic says the new header is 3 lines; it is 13. The conclusion
    ("this is a move") survives independent re-derivation, but the cited numbers do not.
  MINOR 3: the report says gpu_arm.dart's ignore comment is worded "the same way" as its sibling's.
    Same convention, different wording.
Task 1: Ruling: I am opening a fix round for Important 1 even though the task is APPROVED, and
  folding Minor 2 in because the report is the record.
  Why: this task's ENTIRE deliverable is architectural consistency with the sibling arms. A
  back-import means gpu_arm.dart still cannot be read or compiled without the 1097-line main.dart it
  was split out of -- which is most of what Plan A's whole-branch review was complaining about. A
  refactor that leaves the thing it was refactoring to fix is not done, and "worth a fast
  follow-up" is how a follow-up never happens. The fix the reviewer names is small and uses
  machinery that already exists: measurement_rig.dart is ALREADY imported by both gpu_arm.dart and
  widget_arm_rig.dart, so pumpFrame belongs there and neither arm needs main.dart afterwards.
  Minor 3 is left: same convention, different wording, and per-file rationale is the better shape.
  Cost if wrong: one small round on an already-approved task. Nothing downstream waits on Task 1 --
  Task 2 touches packages/jet_cad_2d_flutter and never opens the harness.
Task 1: fix round 1/5 dispatched — resuming the original implementer (a56dbdef421d5ed9e).
  FIX_BASE 0615eb0.
Task 1: fix round 1/5 — commit 35e6c90. pumpFrame moved to measurement_rig.dart; gpu_arm.dart's
  `import 'main.dart'` gone; widget_arm_rig.dart's local _pumpFrame deleted as a duplicate.
  Harness 72/72, widget package 439, analyze and format clean, exit codes pasted.
Task 1: scoped re-review dispatched (sonnet), diff 0615eb0..35e6c90. Told to verify the two
  pumpFrame bodies are BEHAVIOURALLY identical rather than similar, and to say plainly whether a
  green suite is evidence for the deletion at all.
Task 1: re-review — FIX APPROVED. Both bodies quoted side by side and confirmed identical
  (scheduleFrame(); return endOfFrame; -- same statements, same order, no async/await difference),
  so the conditional deletion met its stated threshold. Import graph independently re-derived as a
  strict DAG: main -> gpu_arm -> measurement_rig, and measurement_rig imports neither.
  ONE REPORT DEFECT, recorded because this repository treats a wrong claim about which evidence is
  load-bearing as the guarded-against failure: the report justified "no test exercises the widget
  arm" by citing Step 1's grep, which searched GPU-arm symbols ONLY and says nothing about the
  widget arm. The claim is TRUE -- the re-reviewer checked all 8 harness test files itself and
  none reference the widget arm -- but the cited evidence did not support it.
  CONSEQUENCE, stated rather than smoothed over: because no test exercises the widget arm, the
  72/72 green suite is NOT evidence that deleting its _pumpFrame was safe. The deletion is correct
  on a line-by-line reading and is gated by nothing. Carried forward as a known unverified change.
Task 1: NOT reopening a round for the citation error. The claim was independently verified true by
  the re-reviewer, so a round would change a sentence in a report and no code.
  Cost if wrong: a report sentence stays wrong in the archived ledger, next to the correction.
Task 1: complete (commits 0615eb0..35e6c90, approved after 1 fix round)
Task 2: dispatched (sonnet), BASE 35e6c90. Carries Ruling B5 (the differential oracle's slot
  indices) and the fact that differentialFixture already contains circle 701, arc 703, point 840.
Task 2: implementer DONE — commit 24923f9 "feat(gpu): the instance record carries three kinds and
  twelve floats". 446 passed / 1 pre-existing skip (exit=0), analyze and format clean (exit=0).
  FOUND A REAL DEFECT THE BRIEF DID NOT NAME: geometry_collector_test.dart carried the same stale
  slot-5 reads as the differential test -- three assertions that had been reading halfWidth and
  would now be reading the always-zero x2. Confirmed red before the fix, green after.
Task 2: review dispatched (sonnet), diff 35e6c90..24923f9. Attention lens: the three copies of the
  layout agreeing, the join weights actually disambiguating the two shared-diagonal corners, and
  Ruling B5's (a)/(b) classification.
Task 2: review — APPROVED, zero Critical, zero Important, one Minor.
  Reviewer verified the thing that mattered most and could not be verified any other way: vertices
  2 and 3 both carry corner == (1,-1) and carry weights B and A respectively; vertices 1 and 4 both
  carry corner == (0,1) and carry weights A and M. The collision join_weight exists to resolve IS
  resolved. Had any pair matched on both, the join geometry would have been unbuildable and no test
  in this package could have seen it.
  Also confirmed: every offsetInBytes derives as InstanceFieldOffset.<field> * 4 rather than being
  restated; no StrokeFieldOffset or kStrokeVertexLayout survives anywhere; the barrel's two changed
  lines are a doc comment, not an export (gpu_facade.dart and instance_record.dart stay unexported);
  setCullMode(CullMode.none) sits between setPrimitiveType and the vertex binds and nothing else in
  that file moved; all ten differential assertions classified (a) correctly, none weakened.
  MINOR 1: instance_record.dart's new InstanceFieldOffset doc claims
    "test/gpu/expander_differential_test.dart compares its output against the reference sink, so a
    drift between this file and the expander goes red in flutter test". Neither that test nor the
    expander exists yet, and the plan's own Task 8 names the file instance_expander_test.dart, not
    expander_differential_test.dart. MY DEFECT, transcribed verbatim from my own plan text.
Task 2: Ruling: the Minor is NOT fixed in a Task 2 round; it is carried into TASK 8's dispatch as a
  required edit, to land in the same commit that makes the claim true.
  Why: this repository names "a doc comment claiming a safety net that does not exist" as a failure
  mode by name, so the sentence must not survive to the merge -- but fixing it now would write a
  second wrong sentence (the file still would not exist) and cost a round on an approved task.
  Correcting it in the commit that creates the expander makes the claim true and the citation right
  in one edit.
  Cost if wrong: the wrong filename sits in a doc comment for six tasks. It is on the ledger and in
  Task 8's dispatch, so the way it gets missed is both of those being ignored.
Task 2: complete (commit 24923f9, review clean, no fix round)
Task 3: dispatched (sonnet), BASE 24923f9.
Task 3: implementer DONE — commit 5d5ba07. 449 passed (446 -> 449), analyze and format clean,
  exit codes pasted. M-B1 fired and red on exactly the sub-pixel test; file restored from a cp
  backup and verified by sha256, not git checkout --.
  THREE DEFECTS IN MY OWN PLAN'S SAMPLE CODE, all found by running it rather than reading it --
  the third plan in a row where that is the pattern:
  (1) ResolvedStyle's constructor requires four named arguments; my test literals passed two.
  (2) kLogicalPixelsPerMm needed the barrel import, not the direct one my brief named.
  (3) Step 6 told the implementer to fix a doc calling VerticesDrawSink.kMinStrokeDevicePixels "a
      private implementation detail". THAT DOC WAS ALREADY CORRECT AT BASE -- Plan A's own Task 8
      fix round had already repaired it, and I transcribed the finding from Plan A's ledger without
      checking whether it was still open. The implementer correctly did nothing and said so.
Task 3: review — APPROVED, zero Critical, zero Important, one Minor.
  Reviewer read VerticesDrawSink._coveredArgb (a named focused check outside the diff) and compared
  it line for line: same three-way guard, same (deviceWidth * 2).clamp(0,1), same .round(), same bit
  assembly. Confirmed the fade reaches colour only -- the sub-pixel test asserts halfWidth stays at
  the floor WHILE alpha falls, which is the double-count check. Confirmed no fill routes through
  _coveredArgb. Independently confirmed defect (3) above by reading the doc at BASE.
  MINOR: the zero-lineweight test proves the branch's EFFECT (full alpha) but not that the
  `deviceWidth <= 0` branch ran -- it passed before the implementation too. It still kills a
  narrower mutation (<= 0 weakened to < 0), and M-B1 covers "was _coveredArgb invoked at all", so
  it earns its place. Left; no round.
Task 3: complete (commit 5d5ba07, review clean, no fix round)
Task 4: dispatched (sonnet), BASE 5d5ba07. Carries Rulings B5 and B7 -- the differential oracle
  learns joins IN THIS TASK and the task ends green, superseding the brief's own Step 6.
Task 4: implementer DONE — commit 7296ad2. 454 passed (449 -> 454), analyze/format clean, exit 0.
  Reported: the brief's five test snippets again omitted ResolvedStyle's required linetype/
  linetypeScale (same defect as Task 3, in a different code block of mine); two PRE-EXISTING tests
  in the same file broke because a 3-point polyline now legitimately emits an interior join, and
  were extended rather than weakened; and M-B3 AS I WROTE IT IS AMBIGUOUS -- "delete the
  `if (_runSegments >= 2)` block" can mean the guard or the whole statement, and deleting only the
  guard leaves the suite GREEN.
Task 4: review dispatched (OPUS, not the session default -- this is the plan's central logic task
  and a defect here is a silently reordered picture that no timing or count test would see).
  Attention lens: emission order on three shapes, the seam's bookkeeping after a skipped closing
  step, the repeated-vertex skip, and CIRCULARITY of the rewritten oracle.
Task 4: review — NEEDS FIXES. Two Important, three Minor. The code is right; the GATE is not.
  The reviewer traced emission order by hand on all three shapes and confirmed equivalence with
  _beginRun/_runTo/_endRun, including the two subtle ones: the repeated-vertex skip returns BEFORE
  the _runBack/_runPrev writes so the point-before-previous does not advance (the points-side
  equivalent of the reference "keeps the previous direction"), and the seam's three points are
  correct even when the closing step is skipped because the run already ended where it began.
  IT ALSO SETTLED M-B3 WITH A PROOF RATHER THAN A SHRUG, and this is the most valuable line in the
  review: _runHasDirection implies at least one accepted segment, so reaching the guard with
  _runSegments == 1 needs the closing step to skip -- but the accepted opening segment's
  displacement is the exact negation of the closing one, and sqrt(dx*dx+dy*dy) is symmetric, so if
  the closing step skips the opening one must have too, contradicting _runHasDirection. There is no
  floating-point escape. Deleting the guard alone CANNOT change any output on any input.
  M-B3's guard-only arm is therefore an EQUIVALENT MUTATION, not a coverage gap. The reference's
  own "defensive, not currently reachable-false" comment is correct, and Task 10's log must record
  this derivation rather than list M-B3 as a survivor.
  IMPORTANT 1: the differential oracle is a TRANSCRIPTION of GeometryCollector, by its own doc, and
    structurally -- the locals are the collector's private field names minus the underscore, the
    statement order inside its runTo is line-for-line the collector's, and it copies the sqrt guard
    verbatim. The REFERENCE stores directions, not points; an oracle derived from
    vertices_draw_sink.dart would not look like this. What survives: points, residual and style
    still come from the RecordingDrawSink op stream, so a collector-only mutation still goes red.
    What is lost: the gate no longer attests the instance list is what the reference's RULE
    requires -- only that the collector still does what it did the day the oracle was typed.
    Compounding it, M-B2 and M-B3 were fired only against geometry_collector_test.dart; the one
    cheap piece of evidence against circularity -- M-B2 red in the DIFFERENTIAL test -- was never
    taken.
  IMPORTANT 2: a named, plausible defect survives EVERY test in the diff. Capturing the incoming
    neighbour BEFORE the closing _runTo instead of reading _runBack after it is byte-identical
    whenever the closing step moves, and diverges only when the point list's last point already
    equals its first -- where the seam's incoming direction becomes zero-length and the shader
    normalises it into a NaN. No unit test drives that shape and differentialFixture has no closed
    polylines at all.
  MINOR 3: the report says both pre-existing tests were extended "to check the interior join's kind
    explicitly". True of one; the other gained no kind assertion. Neither lost power, so the claim
    stands and the wording does not.
  MINOR 4: a comment says "writeStroke never touches those slots" -- it writes 0 to both explicitly.
  MINOR 5: _kindAt copies the whole buffer per call, against the data getter's own doc warning.
    Brief-specified and test-only. LEFT.
Task 4: Ruling: fix round for both Importants and Minors 3 and 4. Minor 5 deferred.
  Why Important 1 is not arguable: this project's entire correctness story is differential, and an
  oracle that shares the implementation's bookkeeping shares its bugs. The reviewer's remediation
  needs no third state machine -- dedupe the transformed points with the reference's own predicate,
  then generate [S0, J1, S1, J2, S2, ...] declaratively. A rule stated as a rule cannot share a
  bookkeeping bug with code that has bookkeeping.
  Cost if wrong: one round on a task whose production code the reviewer already validated by hand.
Task 4: fix round 1/5 dispatched — resuming the original implementer (a500813e609eb9268).
  FIX_BASE 7296ad2.
Task 4: fix round 1/5 — commit 469dc5c "test(gpu): a declarative join oracle, and the seam's
  before/after defect". 455 passed, analyze/format clean, exit 0. Test files only; production
  geometry_collector.dart untouched, mutated only transiently and restored from cp backups with
  matching md5.
  THE IMPLEMENTER CAUGHT AN ERROR IN MY OWN REMEDIATION FORMULA, and it was load-bearing. I wrote
  "a join at p[i] for every interior i in 1..n-2, then the closing stroke, then the seam". That
  OMITS the ordinary join at p[n-1], which the closing _runTo emits before its own segment.
  Implemented literally it predicts 2 joins for a closed triangle where an already-passing test
  pins 3. I derived the correct sequence myself before accepting it:
    S(p0,p1), J(p1; p0,p2), S(p1,p2), J(p2; p1,p0), S(p2,p0), J(p0; p2,p1)  -- 6 instances, 3 joins.
  Third-order catch: the reviewer's remediation, relayed by me, corrected by the implementer.
Task 4: scoped re-review dispatched (OPUS), diff 7296ad2..469dc5c. Told to derive the closed-triangle
  and M-B11 sequences ITSELF before reading the implementer's account, because an oracle that is
  DIFFERENTLY wrong is worse than the transcription it replaced -- it looks independent while
  catching nothing.
Task 4: re-review — FIX APPROVED. The arithmetic is CORRECT, derived independently and matching.
  Finding 1 ADDRESSED: _expectedInstancesFor carries no run state at all -- two generates, a dedupe
    whose only carried value is the list built so far, and an index-driven loop. No hasDirection,
    no prev/back/second, no segment counter. The one retained predicate is the REFERENCE's
    zero-length test, a documented deliberate copy, not control flow.
    M-B2 fired against the DIFFERENTIAL test and went red at collector_differential_test.dart:131
    "instance 4 must be a join". The re-reviewer confirmed that assertion exists at that exact line,
    that its reason string interpolates to that exact text, and that index 4 is where the swap first
    diverges given the fixture's 14 instances. The oracle discriminates.
  Finding 2 ADDRESSED: M-B11 red at geometry_collector_test.dart:403, x1 expected 30 got 0.0, and
    ONLY that test red -- which is what the trace predicts, since for any closed run whose closing
    step actually moves, before and after are the same point.
  Both Minors addressed. Re-reviewer ran the two touched files itself: 17/17, exit 0.
  NIT (deferred): the oracle's `closed && n >= 3` guard is narrower than the collector's
    `_runSegments >= 2`. A closed run deduping to exactly two distinct points emits four instances
    from the collector and one from the oracle. Unreachable today -- the fixture's only polyline is
    open -- and it fails LOUD (an instance-count mismatch), not silent, so it is a false-alarm risk
    rather than blindness. Deferred, and Task 5 makes it less reachable still.
  COVERAGE NOTE CARRIED TO TASK 5: because differentialFixture has no closed polyline, the entire
    closed limb of the declarative rule -- the arithmetic this whole round turned on -- is gated
    only by unit tests and never by the differential gate. TASK 5 CLOSES THIS: circle 701 is a
    closed run, so teaching the oracle circles puts the closed limb under the differential gate for
    the first time. Carried into Task 5's dispatch as the reason that work matters.
Task 4: complete (commits 7296ad2..469dc5c, approved after 1 fix round)
Task 5: dispatched (sonnet), BASE 469dc5c.
Task 5: EXECUTED INLINE BY THE CONTROLLER, not by a subagent. The dispatched implementer
  (a77a685831a0c8d65) was killed three times by the machine sleeping, and on the fourth resume
  stalled 50 minutes on a flutter test that never returned (2 tool uses in 685 s). It had already
  written the four Step-1 tests and the _flatten implementation, both of which survived on disk.
  I verified those against VerticesDrawSink._flatten myself before building on them rather than
  inheriting them -- all three properties (local-space walk, scaleMagnitude for the COUNT only,
  the closed run's one-sample-short rule) confirmed by reading both.
  Ruling: taking the task over rather than resuming a fifth time. The sleep/resume cycle was
  spending the whole window on context re-reads with zero file progress, and my own context
  survives an interruption where a subagent's does not.
  Cost if wrong: this task loses the implementer/controller independence the process is built on.
  Paid for deliberately by dispatching the REVIEW on opus and telling the reviewer, in as many
  words, that the author and the dispatcher are the same and its usual trust assumption is void.
Task 5: commits c9d7f73 (implementation), c73758e (oracle), 6b8ed76 (format), 733660f (fix round).
  460 passed, analyze clean, format clean, exit 0 on all three.
  THE FIRST GATE RUN FAILED, on the trap this plan names by name: "Formatted 85 files (2 changed)"
  reads like a status line and IS the failure, FORMAT_EXIT=1. It caught my own two edits.
  ANTI-VACUITY CHECK I NEARLY SKIPPED: the extended oracle passed on its FIRST run, and my earlier
  "confirm it red" attempt had executed from the repo root and died on "Failed to load ... Does not
  exist". So no red state had ever been established and a green run proved nothing. Disabling both
  new branches gives expected 14 against actual 182 -- circle 701 and arc 703 contribute 168 of the
  182 instances. Restored by cp, md5 121c3c5fa93bee8eb33a9ede3758b522 matching, zero residue.
  M-B4 (flatten in collection space) killed by BOTH gates: ellipse x-extent 34.40 against a
  required 60, and the differential diverging at instance 3 by 13.48. Restored by cp,
  md5 91c1059396fdfb199bfa9276701bab9d matching, git diff empty.
Task 5: review dispatched (OPUS), diff 469dc5c..6b8ed76, WITH THE INDEPENDENCE PROBLEM STATED IN
  THE PROMPT: "the person who wrote most of this code is also the person who wrote the report and
  dispatched you; the usual independence does not exist here."
Task 5: review — APPROVED, zero Critical, one Important, five Minor.
  It cleared the claim that most warranted distrust: _flattenedLocalPoints reads
  VerticesDrawSink's LIVE public constants while GeometryCollector keeps its own copies, so drift
  in either arm goes red -- genuinely derived, not retyped. _expectedInstancesFor untouched, no
  bookkeeping added back.
  It verified the 14 independently by counting the fixture (two placements of the 4-point polyline
  702 at 5 instances each, two placements of line 700 via node 520, root line 800, grouped line
  811 = 14), and noted the M-B4 transcript is MORE credible than my brief's prediction: I predicted
  "both extents 60", the run recorded 34.40, and 34.40 is the arithmetically correct consequence
  (deviceRadius = 10*sqrt(3) = 17.32, 2*17.32*0.9866). A fabricated transcript would have echoed
  the brief.
  It CONFIRMED circle 701 closes Task 4's coverage note, and went further than I had: 701 sits in
  definition `inner` under node 520's rotation(0.53)*scale(1.4, 2.1), reaching the collector through
  draft_painter.dart:568's chain -- so this is the first time the differential gate exercises
  b != 0 / c != 0 AT ALL. Every PolylineOp in the fixture goes through _emitScreenSpace and carries
  a pure translation.
  It also named a mutation my unit tests alone would have missed and the new oracle catches:
  `sweep / (steps - 1)` leaves instanceCount at 2*steps and moves both ellipse extents INSIDE the
  old closeTo(..., 0.5) windows. Only the differential extension kills it.
  IMPORTANT 1: `sweep.abs() / steps` survives EVERY gate in this plan. Fixture arc 703 sweeps +1.9
    and both unit tests used 2*pi and pi/2, so no negative sweep exists anywhere in the corpus.
    draft_painter.dart:816-825 passes the scalar through unnormalised, so a clockwise arc is
    representable and would draw mirrored across its start ray. Mitigating: the REFERENCE arm has
    the same corpus gap, so it is not a regression -- but arc() is this task's own op.
  MINORS: skippedOps' doc still said circle and arc "stop counting in Task 5" (this is Task 5); the
    differential test still said b and c are always 0 on every fixture (this commit made that
    false); the ellipse window's 0.5 was 80% consumed by the polygon's own sagitta; the test named
    "a zero or NEGATIVE radius" never passed a negative radius, leaving the `r <= 0` guard
    deletable; and the ellipse loop re-read the data getter ~190 times against that getter's own
    doc warning.
Task 5: fix round 1/1 — all six addressed in commit 733660f. M-B12 (sweep.abs()) fired red:
  expected -50, actual 50.0, exactly the fourth-quadrant endpoint the new test pins.
  Both stale docs corrected, and the differential test's comment now RECORDS the general-affine
  coverage rather than denying it -- understating that would have hidden the most interesting
  thing this task did.
Task 5: complete (commits 469dc5c..733660f, approved with one fix round)
Task 6: dispatched (sonnet), BASE 733660f.
Task 6: implementer DONE — commit c0062c3. 463 passed (460 -> 463), analyze/format clean, exit 0.
  Found the ResolvedStyle four-argument defect in my sample code again -- the fourth task running.
Task 6: review — APPROVED, zero Critical, zero Important, two Minor.
  The reviewer checked every claim against SOURCE rather than against the report's prose:
  writePoint's zeroing (instance_record.dart:160-163) against _ExpectedInstance.point's four zeroed
  fields; Transform2's actual field semantics before accepting the (19, 9) arithmetic; _coveredArgb's
  threshold math to prove the hairline test's lessThan(0xFF) is not vacuous (deviceWidth 0.189
  against a floor of 1.0, alpha fading to ~96/255); PointOp's pre-existing definition; and that
  fixture handle 840 really is EntityKind.point, so Ruling B5's premise was real rather than assumed.
  It answered the planted concern in my dispatch directly. I warned that a writeStroke from
  (x-half, y) to (x+half, y) renders IDENTICALLY to a kKindPoint at the identity transform, so a
  test checking only rendered extents would survive M-B8. It is caught on two independent axes:
  the kind tag AND the zeroed slot layout -- under the mutation x1 becomes px+half, nonzero for any
  width above zero, so either assertion alone kills it.
  MINOR: a nested ternary in a reason string (pre-existing file pattern); and the fixture's point 840
    carries the default lineweight 25, so _coveredArgb is a no-op for it on this fixture -- meaning
    "position under a non-zero off-diagonal residual" and "fading" are never JOINTLY exercised for a
    point. Each is independently covered and the file's own doc explains why fading is excluded from
    this gate. Both left.
Task 6: complete (commit c0062c3, review clean, no fix round)
Task 7: dispatched (sonnet), BASE c0062c3. The shader. NOTHING in flutter test reaches this file --
  the gate is Task 8's expander, Task 9's pixel differential and Task 11's device run.
Task 7: implementer DONE — commit d7499db. impellerc reflection succeeded FIRST TRY, no attribute
  needed touching. Bundle 12584 -> 30072 bytes. 463 passed, analyze/format clean, exit 0.
  Reported no defect in my sample GLSL this time -- the first task in this plan where that is true.
Task 7: review dispatched (OPUS) with the defining fact stated up front: NOTHING in flutter test
  reaches this file, so the reviewer's reading IS the gate. Told to treat the green suite as no
  evidence whatsoever about the shader, and to work a 90-degree turn by hand.
Task 7: review — APPROVED, zero Critical, zero Important, seven Minor.
  The reviewer re-derived _emitJoin term by term and worked the 90-degree left turn by hand: s = -h,
  n0 = (0,-h), n1 = (h,0), cos_half = 0.7071, reach = h*sqrt(2), m at the outer corner. Correct.
  ITS MOST VALUABLE FINDING IS THE ONE IT DID *NOT* RAISE, and it said so explicitly: to_pixels
  returns y-UP NDC while VerticesDrawSink works in y-DOWN canvas space, which looks like a sign
  error. It proved the construction is EQUIVARIANT under T(x,y) = (x,-y): cross flips, so s flips,
  so n0' = T(n0), a' = T(a), b' = T(b), and dot and cos_half are reflection-invariant so m' = T(m).
  The wedge is the reference's wedge pushed through the same reflection the mvp applies to the whole
  picture. A less careful reviewer would have filed a false Critical here.
  It also proved kMinMiterCosine is BIT-exact across arms (-7/8 is exactly representable in float32,
  so the GLSL literal and the narrowed Dart double are the same bits and the boundary case takes the
  same branch), that the bevel's m = a gives triangle 1 two bit-identical vertices against
  kCornerVertices' actual weight rows (exactly zero area, not approximately), and that the point
  square is exactly 2*half on both axes against the reference's _emitQuad.
  It recomputed the bundle's SHA-256 and byte size itself and matched the report, so the decode
  output describes the artifact actually committed.
  BOTH "inert" GUARDS RE-DERIVED RATHER THAN ACCEPTED: half_width > 0.0 is unreachable because
  half_width == 0 makes n0 = n1 = (0,0) exactly and sum_len > 0.0 already fails; the in_len/out_len
  disjunct cannot fire on any input _emitJoin can receive because _runTo returns before calling it.
  MINOR 1 (FIXED, commit f67bda5): the frag comment claimed VerticesDrawSink has "no antialiasing
    path at all" and "the word does not appear in the file". It appears at :78-79 -- "Anti-aliasing
    comes from MSAA, not from a coverage shader". The conclusion holds (no COVERAGE-SHADER path, and
    MSAA cancels between arms) but the cited evidence was false, which this codebase names as the
    guarded-against failure. Corrected. REBUILDING AFTER THE EDIT GAVE THE IDENTICAL SHA-256,
    0a7b07b44cdf2cffacb789a5aa8912fbbf6d084b2c980cd3c5a6c08d666cadcf -- proof a GLSL comment cannot
    move the artifact.
  CARRIED TO TASK 8 (Minor 4): the in_len/out_len guard is a real, bounded arm-to-arm divergence,
    not only defensive. The sink computes in double from device-space points; the shader re-projects
    collection space in float32, so at extreme zoom-out the shader can collapse where the sink
    emits. TASK 8'S DART RUNS IN DOUBLE AND WILL TAKE THE OTHER BRANCH ON THE SAME INPUT. The guard
    must be transcribed VERBATIM regardless.
  CARRIED TO TASK 8/11 (Minor 5): the blend px = w.x*v + w.y*a + w.z*b + w.w*m poisons ALL SIX
    vertices if m is non-finite, because 0.0 * Inf is NaN -- including triangle 0, which in the
    reference does not depend on m at all. Unreachable today (dot >= -0.875 bounds reach <= 4*half),
    but Task 8 transcribes the same blend and Task 9 would see both arms produce the same NaN and
    report agreement. Only a device run would show a corner eating its own bevel.
  CARRIED TO TASK 9 (Minor 3): if a collector ever wrote a join's p1 as the immediate RAW
    predecessor rather than the last MOVING point, the shader takes the collapse branch and draws
    nothing where the sink draws a full join -- the guard turns a wrong-input bug into silent
    absence. Task 4 got this right and has a unit test, but TASK 9'S FIXTURE NEEDS A POLYLINE WITH A
    REPEATED INTERIOR POINT or the miss reaches Task 11 unexamined.
  CARRIED TO TASK 11 (Minor 6): to_pixels drops the perspective divide -- correct for every affine
    2D camera this backend builds, inherited from Plan A, and Task 8 will copy it so Task 9 agrees.
    It is the one line a non-affine mvp would break silently past every gate in the plan.
  MINOR 7: Step 4's substring count proves ES 100 is present and correctly separates it from the
    openglDesktop #version 120 stage -- the trap Plan A fell into -- but does not prove
    CadStrokeVertex specifically carries an ES 100 stage. 2 versus 2 against two entry points makes
    the inference reasonable. If Task 11 hits a GLES loader failure, decode the flatbuffer's stage
    table per entry point rather than recounting.
Task 7: complete (commits d7499db..f67bda5, approved, one Minor fixed inline)
Task 8: dispatched (sonnet), BASE f67bda5. Carries Minors 4 and 5 as binding constraints.
Task 8: implementer DONE — commit fffefc5. 7/7 new, 470 full suite, analyze/format clean.
  TWO DEFECTS IN MY SAMPLE CODE, the second genuinely subtle:
  (1) `library;` placed after the imports; Dart requires it first.
  (2) the colour test compared an Int32List entry against 0xFF112233 directly. Int32List is SIGNED,
      so that value reads back as -15654349 and the assertion could never pass. Fixed with
      .toUnsigned(32), matching this codebase's existing convention.
Task 8: review dispatched (OPUS) with Ruling B6 stated up front so the reviewer would not spend the
  round re-litigating whether the duplication should exist, and would spend it on FIDELITY instead.
Task 8: review — NEEDS FIXES. Two Important, seven Minor. The transcription itself is FAITHFUL:
  the reviewer read all three branches statement by statement against the GLSL and found no
  divergence -- every guard, sign and order of operations survives, including the three-way || in
  the shader's order, `m = a` as the default, and the division before the multiply in the reach.
  It re-derived the 90-degree miter independently (m = (104, -4)) and matched.
  It verified M-B6's transcript NUMERICALLY rather than trusting it: hairpin gives cosHalf 0.005,
  reach 800, m.x = 900.02 -- matching the reported 900.02001953125 to the digit. "This transcript
  was produced by running the mutation, not written."
  IMPORTANT 1: the doc citation I routed to Task 8 landed HALF-TRUE. I sent them to fix a filename
    and they fixed the filename while leaving the claim -- "compares its output against the
    reference sink" -- false. instance_expander_test.dart makes no such comparison. Same failure the
    edit existed to remove, at the second attempt.
  IMPORTANT 2: every fixture transform was diagonal and translation-free (six identities, one
    scale(5,5)), so b, c, e, f were zero everywhere and BOTH a transposed to_pixels and one that
    drops the translation passed all seven tests. The degenerate fixture CLAUDE.md names, in the one
    function where a drift moves every coordinate.
  PROMOTED MINOR: no test read cad_stroke.vert, so changing its -0.875 to -0.9 or `kind < 1.5` to
    `kind < 2.5` left all 470 tests green -- making the shader's own claim that
    "instance_expander.dart asserts the two agree" a mirror of a mirror. The .vert is a plain file a
    test can read; I promoted this because it converts the most renumber-prone constants from a
    human diff into a red test for about ten lines.
Task 8: fix round 1/5 — commit f01ee5a. 9/9 expander, 472 full suite, analyze/format clean.
Task 8: scoped re-review — FIX APPROVED. The re-reviewer derived the new fixture's expected
  positions itself before comparing: t = Transform2(2, 0.5, -1, 3, 10, 10), all of b/c/e/f non-zero
  AND b != c (0.5 against -1), which is what keeps the transpose mutation live. Vertex 0 lands at
  (10.970143, 6.119433) and the test asserts exactly that.
  It then predicted both mutations' outputs from the fixture's numbers rather than trusting the
  transcripts: M-B13 (transpose) drives toY at B to -90 instead of 60, giving vertex 0 px 8.211146
  -- the transcript reads 8.211145401000977. M-B14 (drop translation) shifts vertex 0 by exactly
  10.0, the dropped e -- the transcript reads 0.9701424837112427 against an unmutated 10.970142.
  Both consistent to the digit.
  It verified the three GLSL regexes against the shader's CURRENT text (lines 47, 57, 72), confirmed
  they tolerate reformatting via \s* and would fail on a changed literal, and confirmed the doc
  citation is now true by checking resident_pixel_differential_test.dart genuinely does not exist.
  It also confirmed the 36-line stat in instance_expander.dart is comment growth only -- no `px =`,
  `toX =` or `toY =` line was touched.
Task 8: complete (commits fffefc5..f01ee5a, approved after 1 fix round)
Task 9: dispatched (sonnet), BASE f01ee5a. The pixel differential -- what every task before it was
  building toward. Carries Task 7's Minor 3 (the fixture needs a repeated interior point).
Task 9: implementer DONE_WITH_CONCERNS — commits 60d5569, 5596437. Reported differing: 0 with four
  honest concerns rather than a clean claim.
Task 9: review (OPUS) — NEEDS FIXES. Two Important, both invalidating the headline result.
  CONFIRMED BY RE-DERIVATION FIRST: the transform arrangement is a DERIVATION, not a tuning -- both
  arms land on centreline*dpr +/- logicalHalf*dpr by construction, and the brief's backwards sample
  leaves the fingerprint residentInk/referenceInk ~= dpr. The 444-line change to
  collector_differential_test.dart is a MOVE (blocks diffed stripped of whitespace, body found
  verbatim inside _checkAgainstOracle), with _referenceCoveredArgb a strengthening. And differing: 0
  is the PREDICTED result: both arms flatten with the same step formula off the same quantity, and
  the join arithmetic is equivariant under a positive uniform scale, so they must land on the same
  points.
  IMPORTANT 1: THE GATE COULD NOT FAIL ON ANY DEFECT THE PLAN NAMED. Budget is 1% of ink = 81
    pixels; the corpus's ENTIRE join contribution is 26 pixels, per the implementer's own M-B7
    probe. Deleting _emitJoin outright passes green. The repeated-interior-point polyline the Task 7
    review demanded is worth ~2.2 px -- in the corpus in letter, invisible to the gate. Both
    mutations reported as killed died on a RESIDENT-ARM SELF-CONSISTENCY PROBE that never touches
    referenceInk or differing. The differential proper had ZERO demonstrated kills.
  IMPORTANT 2: M-B8's "structural bit-identity" was WRONG, and I had accepted it from the
    implementer's summary. `half` is a DEVICE quantity written into a COLLECTION-space record --
    the exact rationale kKindPoint exists for, stated in the collector's own doc -- so under
    scale(2) the mutated dot is a 7.56 x 3.78 rectangle where both correct arms draw a 3.78 x 3.78
    square: 32 inked pixels against 16, differing = 16, sitting under the 81 budget. It survived on
    THRESHOLD SLACK, and a green run with nothing printing differing was read as bit-identity.
  SEAM FIXTURE VINDICATED: r=90 -> r=8 was not a fixture tuned until a test passed. At r=90 the
    notch is 0.27 px^2, provably invisible to a pixel-centre rasterizer, so the original fixture was
    genuinely INCAPABLE. The reviewer computed r=8's notch at 14.09 against the probe's 14.0.
Task 9: fix round 1/1 — commit 70d0841. lessThan(4) added ALONGSIDE the unchanged 1% criterion with
  its ulp reasoning; a differing assertion added on the r=8 circle; the seam test's differential
  assertion reordered AHEAD of its self-consistency probe so expect's first-failure semantics
  surface the right one. All four now redden the DIFFERENTIAL: M-B3' 14, M-B8 16, M-B7 26, M-B15 26
  (178 on the seam). Only M-B1' survives, structurally -- a coverage-only rasterizer cannot see an
  alpha-only change; gate of record is Task 3's record-level test.
Task 9: scoped re-review (OPUS) — FIX APPROVED. It derived M-B8's 32-against-16 from source and got
  differing = 16 exactly; it verified the transcripts cite lines 141 and 211, which ARE the two
  lessThan(4) assertions in the committed file -- independent corroboration the transcripts were
  produced against this version; and it showed M-B7 and M-B15's identical 26 is FORCED rather than
  coincidental, since both satisfy differing == referenceInk - residentInk, so the resident set is a
  pure subset of the reference's.
  ITS BEST FINDING IS A STRUCTURAL BLIND SPOT, PROVED RATHER THAN SUSPECTED: a wrong-side join wedge
  is wholly invented geometry at every corner and moves ZERO pixels, because it lands inside the
  union of the adjacent segment quads. So this instrument cannot see ANY defect that adds triangles
  within the existing footprint -- a join on both sides, a duplicated instance, a quad overshooting
  its neighbour, a miter tip over-reaching inward. sink_comparison.dart carries a
  strayVerticesPixels notion for exactly this class; this file had no analogue.
  THREE COMMENT INACCURACIES, one the same species this round was convened to fix: the new bound's
  own justification claimed it sits "two orders of magnitude below every named-mutation kill" when
  4 against the smallest kill of 14 is 3.5x. Also "half-open inside test" (the rasterizer is closed
  on all three edges) and a notch figure quoting a pixel COUNT as an area.
Task 9: Ruling: I fixed all four inline rather than opening a second round. They are comment-only,
  no assertion moves, and the blind spot needed recording in gpu_comparison.dart's own doc, where
  the next plan will read it, rather than in a ledger it will not open.
  Cost if wrong: the doc says slightly more than the review demanded; every assertion is untouched.
  Gate after the corrections: 60 gpu tests pass, analyze clean, format clean, exit 0 on all three.
Task 9: complete (commits 60d5569..70d0841 plus the doc corrections, approved after 1 fix round)
Task 10: dispatched (sonnet), BASE 230ac7b. Collect every mutation into one document of record,
  fire the two nobody had fired, and write the survivors up as derivations rather than shrugs.
Task 10: implementer DONE — commit f8e3d8e, docs/superpowers/notes/plan-b-mutation-log.md.
  TALLY: 18 firings across 15 named mutants, 16 killed, 1 survivor, 1 EQUIVALENT.
  M-B9 (sort the buffer by kind) fired for the first time and died on both record-level kind
  sequences and the differential's own walk-order assertion.
  M-B10 (joins as collector geometry at the collection width) fired for the first time and died
  DIRECTLY on the pixel differential -- differing 95 and 552 against bounds of 81 and 4.
  It handled my conditional instruction better than I wrote it. I said "if M-B10 is unkillable at
  the identity transform, add a 3x arm and re-fire". The implementer found the PREMISE FALSE --
  collectionToDevice.scaleMagnitude is 2.0 at the suite's dpr, not 1.0 -- so the mutation dies
  without any new arm. It then ran a throwaway probe at dpr 1.0 confirming differing: 0 there,
  declined the conditional work rather than performing it for its own sake, and recorded the
  dpr-dependence as a caveat. Doing the conditional work anyway would have added an arm nothing
  needed and implied a gap that does not exist.
  THE THREE WRITE-UPS THAT CARRY THE VALUE:
  - M-B3's guard-only arm recorded as EQUIVALENT, not as a survivor, with the symmetry proof.
  - M-B1' recorded as a structural survivor with its gate of record named.
  - The instrument's blind spot recorded as a bounding statement on what every kill in the table
    means, not as a mutation.
Task 11: dispatched (sonnet), BASE f8e3d8e. THE DEVICE RUN WAS DONE BY ME, NOT THE SUBAGENT --
  bounded to 10 minutes with a pkill backstop, because flutter run never exits on its own and two
  earlier attempts in this session stayed attached for 11.5 hours. It finished cleanly in 44s:
  27 phase reports, three repeats, "Application finished". Log at /tmp/t11-gspike.log.
  Ruling: I ran it myself rather than dispatching it. A subagent holding an unbounded flutter run
  is the exact failure that cost this session two 11-hour hangs, and the subagent cannot kill what
  it is blocked on. Cost if wrong: the numbers are mine rather than an implementer's, so I told the
  implementer to recompute every figure from the log and not to take mine -- which it did.
Task 11: implementer DONE — commits 72b938a (harness note + debugCollinearJoins), 47347bf (results
  note + STATUS.md). GATE: 10 OF 11.
  Buffer PASSES at 4.99 MB / 109,068 instances against 8 MB. Reconciles exactly: 109068 * 12 * 4 =
  5,235,264 B = 4.9926 MiB.
  Rebuild MISSES: walk 5.7 ms, total 79.6 ms against 16.67 ms. Recorded as a miss with its number,
  the cold-pipeline hypothesis stated AS a hypothesis, and "no warm rebuild was measured" on the
  gaps list. The walk being 5.7 ms against Plan A's 14.7 ms while emitting MORE instances is
  recorded as unexplained rather than given an invented cause.
  Criterion 11 UNMET in those words: the run happened, no human looked at the window.
  It also found a DEVICE-RUN TRANSCRIPT THAT MISDESCRIBED WHAT IT MEASURED -- the harness note
  still said "draws only strokes ... No joins, no caps" after Plan B shipped joins, points, circles
  and arcs. Corrected.
  And it corrected MY brief: I said Task 10 added a 3x arm to the pixel differential. It did not --
  that was conditional on M-B10 surviving, which it did not. Stated precisely rather than repeated.
=== FINAL WHOLE-BRANCH REVIEW (OPUS), 5c94e11..47347bf, 22 commits, 23 files, +4961/-908 ===
Verdict: READY AFTER FOUR NAMED FIXES. Zero Critical. Reviewed in six passes, and it re-ran the
  suite itself at HEAD: 477 pass, analyze and format clean.
  ITS HEADLINE FINDING IS THE BEST SINGLE CATCH OF THIS PLAN, and it is the shape only a
  whole-branch view produces: `_coveredArgb`'s `lineweightScale` factor sits at the IDENTITY in
  every instrument on the branch, so deleting that one factor passes the record differential, the
  pixel differential AND all fifteen named mutants. `_halfWidthFor` takes the same four inputs and
  IS pinned at scale 2; `_coveredArgb` had no equivalent. Compounding it, the differential's own
  `_referenceCoveredArgb` did not model lineweightScale at all, so adding a scaled fixture without
  fixing the oracle first would have made the oracle agree with the MUTANT and disagree with
  correct code. The generalisation it drew is worth carrying into Plan C: when a function's
  arguments are audited, audit them ONE AT A TIME against every fixture, not as a set.
  I2: the `data` getter's doc still did Plan A's 10-float arithmetic -- 2.3 MB where its own
    parenthetical evaluates to 2.74 MiB and resident_geometry_test.dart:23 asserts 2874000, and
    where this plan's measured corpus makes the real figure 5.23 MB. A 2.3x understatement on the
    doc whose whole purpose is warning a future paint() call site off the getter.
  I3: instance_record.dart still said resident_pixel_differential_test.dart is "not written yet"
    and "will compare" -- written by Task 8's fix round, WHICH WAS OPENED SPECIFICALLY TO REMOVE A
    DOC CLAIMING A SAFETY NET THAT DID NOT EXIST. It replaced one false claim with a
    true-at-the-time forward reference and nobody came back after Task 9 created the file. Third
    instance of this species on the branch.
  I4: THIS LEDGER STOPPED AT TASK 9. No Task 10 or Task 11 lines, though both reports existed, and
    commit 72b938a added PRODUCTION CODE (debugCollinearJoins) in the scoring phase with no review
    record. Since the ledger is archived on merge and never appended to afterwards, that would have
    shipped as the permanent record of a plan whose last two tasks left no trace. Fixed by the
    entries above, written before the archive.
  M5 folded in: draw(6) was the only unlinked number in an otherwise fully derived chain.
Final fix wave: commit 4101cae, 8 files, +222/-28. 479 passed, analyze and format clean, exit 0.
  M-B16 (delete lineweightScale from _coveredArgb only) fired: invisible to
  geometry_collector_test.dart AND to the pixel differential, killed only by the new oracle-aware
  test. Restored by cp, md5 690b9f918f55df1da84060b1441c9a83. Appended to the mutation log.
