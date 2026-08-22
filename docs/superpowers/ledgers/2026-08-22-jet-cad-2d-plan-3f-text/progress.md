# SDD ledger — plan: docs/superpowers/plans/2026-08-22-jet-cad-2d-plan-3f-text.md

Spec: docs/superpowers/specs/2026-08-22-jet-cad-2d-plan-3f-text-design.md (reachable, binding).
Branch: `main`, worked directly, no worktree. The human gave explicit consent
for this arrangement, same as Plan 3e.
Plan head at start: 2db538d.

## Pre-flight scan

### Shared files — one row per task pair

| file | tasks | what one produces / the other consumes | finding |
|---|---|---|---|
| `flutter_text_measurer.dart` | T2, T8 | T2 writes the class; T8 edits only `kMetricsCacheLimit`'s doc comment | clean |
| `measurement_rig.dart` | T3, T8 | T3 changes `printTextCounters`' signature; T8 adds `culledText=` to its first print | clean — T8 adds a field, not a parameter |
| `draft_canvas.dart` | T4, T5 | T4 edits `_attach`'s measurer resolution and `dispose`; T5 edits the ctor, `_attach`'s painter construction and `didUpdateWidget` | clean — both touch `_attach`, sequentially |
| `draft_canvas_test.dart` | T4, T5, T6 | T4 adds 3 docs + 2 tests; T5 adds the prop-update test; T6 may add `minTextCapPixels: 0` | clean — additive |
| `main.dart` | T4, T8 | T4 hoists the measurer and edits `dispose`; T8 adds the `LOD` define and forwards it at the `DraftCanvas(...)` call | clean — disjoint regions |
| `paint_microbench_test.dart` | T3, T6, T8 | T3 collapses two measurers to one; T6 records its margin; T8 extends it to loop thresholds | **FLAGGED** — see Ruling 1 |
| `text_lod_test.dart` | T5, T6 | T5 creates it; T6 appends the differential test | clean |
| `STATUS.md` | T1, T9 | T1 adds an in-flight section; T9 replaces it with the finished account | clean |
| `fixtures.dart` | T6 only | — | clean |
| `draft_painter.dart` | T5 only | — | clean |

### Interfaces — producer against consumer

| produced by | name | consumed by | finding |
|---|---|---|---|
| T2 | `paragraphEvictionCount`, `metricsEvictionCount`, `liveMetricsCount` | T3, T8, T9 | names match exactly |
| T2 | `paragraphLimit`, `metricsLimit` ctor params | T2's own test, T8's ladder | match |
| T4 | `harnessMeasurer` | T4 only | match |
| T5 | `kMinTextCapPixels`, `minTextCapPixels`, `culledTextCount` | T6, T7, T8, T9 | match; exported via the barrel's `export 'src/draft_painter.dart'` |
| T6 | `referenceWalk(..., {minTextCapPixels})`, `paintToRecording`, `referenceToRecording` | T6's own test, T9 row 9 | match |

### Per-task self-consistency

| task | its tests against its code | finding |
|---|---|---|
| T1 | docs only | clean |
| T2 | tests use `paragraphLimit`/`metricsLimit`/`paragraphEvictionCount`, all defined in the same task | clean, but **Step 5 knowingly leaves `flutter analyze` red** — see Ruling 2 |
| T3 | no new tests; verification is analyze + the tagged rig run | clean |
| T4 | the two new widget tests use `FlutterTextMeasurer` and `_roboto`, both introduced in the same step | clean |
| T5 | six tests against the constant, the parameter and the counter it adds | **two import defects found and fixed pre-flight** — see Ruling 3 |
| T6 | the differential test against the fixture and the threaded parameter | clean; the fixture's three heights are derived, not measured, and the step requires the implementer to print and report them |
| T7 | goldens | clean |
| T8 | measurement only | clean |
| T9 | the gate | clean |

### Global-constraint check

No task mandates anything the review rubric treats as a defect. No task asserts
nothing. No task duplicates a logic block verbatim. **No task touches
`packages/jet_cad_2d`**, which the plan's File Structure section requires and
which the scan confirms task by task. No task amends `CLAUDE.md`.

## Rulings

Ruling 1: `paint_microbench_test.dart` is edited by T3, T6 and T8, and the
order is load-bearing — T3 collapses the two measurers to one, T8 later wraps
the same body in a threshold loop. T8's dispatch will carry an explicit line
saying the single-measurer collapse is T3's deliverable and must survive.
— Why: three tasks in one file is the shape that produces a silent revert, and
the collapse is the task whose loss would be least visible (the rig still runs
and still prints plausible numbers).
— Costs if wrong: T8 reintroduces a second measurer, the ladder measures a
wiring that does not exist, and the whole-branch review has to catch it.

Ruling 2: T2 deliberately ends with `flutter analyze` failing on
`paint_microbench_test.dart`'s `evictionCount`, which T3 owns. This is the one
place the plan breaks "every task ends green", it is stated in T2 Step 5, and
it stands.
— Why: merging T2 and T3 would put a cache rewrite and a rig rewrite behind one
reviewer's gate, and T3 also has to rewrite a comment that states this plan's
own falsified premise — judgment work that deserves its own review.
— Costs if wrong: a reviewer flags T2 for a red analyze; the ledger and the
brief both say why, so the cost is one paragraph of adjudication.

Ruling 3: the plan's Task 5 test file was missing `import 'dart:typed_data'`
(it uses `Float64List`) and imported `vector_math_64.dart` without
`hide Aabb2`, which collides with the `Aabb2` `jet_cad_2d` exports. Fixed in
the plan at 2db538d before Task 1 was dispatched, matching what
`text_paint_test.dart:1-6` and `draft_canvas_test.dart:1-8` already do.
— Why: both are compile errors, and an implementer transcribing the plan
verbatim would have burned a round on them.
— Costs if wrong: none — the fix reproduces two existing files' import blocks.

## Progress


Note: TodoWrite is unavailable in this session, so this ledger is the only
progress record. Same situation as Plan 3c — keep appending to it.

Task 1: implementer DONE_WITH_CONCERNS (commit 5d4ef7a). Concern was an
observation, not a correctness claim: the brief's Step 5 verification grep
predicts three surviving lines and returns four. Controller verified
independently — the fourth is the wrapped continuation of the note the brief
itself mandates, and the filter is line-based, so the matching phrase sits on
the previous physical line. Content correct: the three prose lines at :623,
:634 and :636 are untouched. Trap files unstaged; only STATUS.md committed.
Task 1: minor (deferred): the plan's Task 1 Step 5 grep filter is line-based
and cannot match a phrase that wraps. Harmless here; noted so the final
whole-branch review can triage whether any other verification step in this
plan has the same shape.
Task 1: review dispatched (review-2db538d..5d4ef7a.diff).
Task 1: review clean — spec compliant, quality approved, no findings. Reviewer
independently agreed the Step 5 grep undercount is a defect in the brief's
verification command, not in the implementation. Two "cannot verify from diff"
items resolved by the controller: the pre-edit grep is cross-checkable only
against removed lines and matches where checkable (and the controller verified
the post-state directly); whether the new section splices cleanly for Task 9 is
that task's business and is carried into its dispatch.
Task 1: complete (commits 2db538d..5d4ef7a, review clean)
Task 2: implementer DONE (commit 71d75bd, 2 files, +274/-127). Measurer suite
11/11; widget suite 281 passed (277 before, 4 new tests); flutter analyze fails
with 4 errors in test/rig/paint_microbench_test.dart on the removed
evictionCount, which is Ruling 2 working as intended and is Task 3's. Trap
files confirmed unstaged.
Task 2: review dispatched on the most capable model (review-5d4ef7a..71d75bd.diff)
— native-paragraph disposal, lookup-path allocation, and whether the assert
that replaced a disposal branch is genuinely unreachable are the three things
worth a strong reviewer here.
Task 2: review — spec compliant. Reviewer traced every disposal route and
confirmed the assert is genuinely unreachable (the fresh key is value-equal to
the probe that just missed, and nothing between the miss and the insert
inserts). Lookup path allocates nothing on a hit; measure() returns the stored
instance. Transcripts judged genuine on a detail hard to fake: Step 2's error
line numbers sit one above the committed file's because dart format later
reflowed a `test(` call, and only the lines below the reflow shift.
Task 2: fix round 1/5 opened — 1 Important + 1 Minor bundled.
  Important: probe.dispose() is untested. Commenting it out leaves all 11 green,
  because the test named for it asserts only the two entry counts. Highest-
  frequency disposal site in the class and invisible to the Dart heap.
  Minor (bundled, not loop-extending): clear()'s dispose loop is equally
  untested. Bundled because the round is already open, it is the same file and
  the same shape, and a separate round for it would cost more than the fix.
Task 2: minor (deferred): the report ran analyze only in jet_cad_2d_flutter, so
it named four red call sites when there are nine — measurement_rig.dart:156,158,
218 and frame_timing_test.dart:265,323 are also red. Leaving them was correct
(the plan assigns all nine to Task 3); under-reporting them was not. Carried
into Task 3's dispatch so it does not treat paint_microbench_test.dart as the
whole job.
Task 2: fix round 1/5 (2 addressed, 0 open; commits 71d75bd..6ee5ecc). Both
mutants seen red at the named test and line, then restored by backup copy.
Re-reviewer confirmed the ordering that mattered: debugLastProbe is assigned
after probe.dispose(), so the field holds a handle the code has actually
released — captured before disposal it would have passed with the disposal
deleted, which is the same defect one line lower.
Task 2: complete (commits 5d4ef7a..6ee5ecc, review clean)
Task 3: implementer DONE (commit 08b7785, 3 files, +42/-35). Both analyze runs
clean — jet_cad_2d_flutter and dev_harness_2d, which is the pair Task 2's report
got wrong. Rig "text paint at 50000"/500000 passes and prints the split
counters; widget suite 281 pass / 1 pre-existing skip; format clean.
Task 3: review dispatched (review-6ee5ecc..08b7785.diff). The comment rewrite is
the judgment half and is weighted first: it has to record that the file changed
because the design changed, and be explicit enough that Tasks 6 and 8 cannot
silently reintroduce the second measurer.
Task 3: review clean — spec compliant, quality approved. Reviewer checked the
rewritten comment against flutter_text_measurer.dart rather than taking its
wording on trust, and confirmed it records the design change rather than
deleting the old claim.
Task 3: minor (deferred): the microbench comment is descriptive ("that wiring is
gone") rather than prescriptive; it does not say "do not add a second measurer
here". Ruling 1 already carries the protection into Tasks 6 and 8 dispatches,
so this is belt-and-braces, not a gap.
Task 3: early data point worth keeping — the rig now prints
paragraphEvictions=194068, metricsEvictions=0. Both land where the design
predicts: the paragraph map is 512 against ~4,140 keys, which is 3c's
per-frame thrash; the metrics map is 8192 against ~4,020 distinct
(text, styleHandle) pairs, so it never evicts. First evidence that
kMetricsCacheLimit's derived value holds for this corpus. Task 8 still owes the
measured distinct-key count.
Task 3: complete (commits 6ee5ecc..08b7785, review clean)
Task 4: implementer DONE_WITH_CONCERNS in substance (returned DONE, two concerns
worth recording). Commit cc26039, 8 files, +143/-24. Engine 777/777; widget
283/283 + 1 pre-existing skip (281 before, 2 new tests); goldens 29/29 with no
PNG regenerated; both analyze runs clean; trap files unstaged.
  Concern A, and it is the interesting one: the brief predicted both new tests
  would fail at baseline. Only the refusal test did. The split-view disposal test
  PASSED VACUOUSLY before the fix, because pre-fix the widget's measurer and the
  document's were different objects, so the test read something dispose() never
  touched. The implementer found this by stashing and restoring the widget fix
  to get a genuine baseline, and said so rather than reporting a clean red. That
  is the right instinct; whether the test is a real regression test *now* is the
  question, and it is weighted second in the review dispatch.
  Concern B: the brief enumerated eight call sites; there is a ninth —
  differentialFixture() reached from draft_canvas_test.dart's setUp(). Fixed by
  giving that fixture an optional measurer parameter with the default unchanged,
  NOT by softening the guard, which is what the dispatch told it to do if the
  choice arose.
Task 4: review dispatched on the most capable model (review-08b7785..cc26039.diff).
Task 4: review — spec compliant, quality approved, three Minors. Reviewer traced
disposal at every touched site and confirmed one owner each, including that the
addTearDown calls inside helper functions are legal because all three helpers are
invoked only from testWidgets bodies. Confirmed the split-view test is a real
regression test now even though it was not red-first: re-adding clear() to
DraftCanvasState.dispose() makes liveParagraphCount read 0 against 1. Confirmed
the ninth site's unchanged default costs nothing, because differentialFixture()
contains no text entity at all, so TextMetrics.zero is never consulted there.
Task 4: Ruling — the reviewer's Minor 2 is promoted to Important and enters the
fix loop. Its content: nothing pins the identity of the borrowed measurer, so
re-introducing a private FlutterTextMeasurer() for the sink passes every test in
the suite. That is not a small gap — it is this plan's central defect returning
silently, the same shape as Task 2's untested probe.dispose(), which the
reviewer there called Important. A gate that cannot see the thing it gates is
not a gate.
— Why: one line of test against a defect the whole plan exists to prevent.
— Costs if wrong: one extra fix round on a task that was otherwise clean.
Task 4: fix round 1/5 opened — 1 promoted Important + 2 Minors bundled.
Task 4: fix round 1/5 (3 addressed, 0 open; commits cc26039..4cd23da). The
promoted Important is genuinely pinned: identical(), read off a live pumped
DraftCanvasState's sink, inside a testWidgets body, and seen red under the
mutation it targets. The implementer improved on the prescription by extracting
_requireMeasurer() so both _attach() and didUpdateWidget guard before any
teardown, which is a cleaner shape than the hoist I asked for.
Task 4: complete (commits 08b7785..4cd23da, review clean)
Task 5: Ruling — the plan's Task 5 test file imports 'support/fixtures.dart'
and uses nothing from it (RecordingDrawSink comes from the package barrel via
lib/src/draw_sink.dart). packages/jet_cad_2d_flutter/analysis_options.yaml sets
`unused_import: error`, so that import would fail analyze as an error, not a
warning. Task 5 omits the import; Task 6 adds it back when it adds the test that
uses kViewport, paintToRecording, referenceToRecording and
textLodDifferentialDocument.
— Why: the alternative — making Task 5 use fixtures' kViewport instead of
const Size(400, 300) — looks tidier and is wrong: kViewport is Size(800, 600),
which doubles the fit scale and breaks every threshold number the test is built
on.
— Costs if wrong: Task 6 forgets to add the import back and its own test fails
to resolve, which is a compile error caught immediately, not a silent pass.
Task 5: implementer DONE_WITH_CONCERNS (commit c9a0b97). New text_lod_test 6/6;
goldens 29/29 with no PNG moved; analyze clean; trap files unstaged. Controller
re-ran the widget suite rather than trusting the summary, because the report's
"288/289 pass" and its concern 1 could not both be true: the real state is
289 pass, 1 skip, 1 FAIL.
Task 5: Ruling — the widget suite ends this task RED on text_paint_test.dart's
"the reference walk and the painter agree with text on" (14,039 ops from the
walk against 1,258 from the painter). The painter now culls; the reference walk
has no level-of-detail notion until Task 6 gives it one. This is the second
deliberate red-tree handoff in the plan and the first I did not rule in advance,
so I am ruling it now: it stands, and Task 6 must close it as its FIRST
deliverable, before anything else in that task.
— Why: adding the cull to the oracle is Task 6's whole point, and merging it
into Task 5 would put the painter mechanism and the independently-derived
oracle behind one reviewer's gate — which is exactly the pair that must not be
reviewed together, since the oracle exists to disagree with the painter.
— Costs if wrong: the tree is red across one task boundary. If Task 6 fails to
close it, the failure is loud and immediate rather than silent.
Task 5: plan defect found by the implementer, and it is mine. Two of the brief's
six fixtures had arithmetic that ignored ViewportTransform.fit's built-in 0.95
margin, which broke the boundary test and the never-measured assertion. The plan
carries that exact warning — but only in Task 6's text, not Task 5's. Corrected
in place by the implementer; the resolve-cull-measure ordering was untouched.
Task 5: review dispatched on the most capable model.
Task 5: review — spec NOT compliant, one Critical, two Minors.
  Critical: the cull-before-measure ordering, which is the entire mechanism, is
  untested. The reviewer moved the cull after measure() and all six tests still
  passed. Cause: SpatialIndex(doc) warms the metrics cache for the fixture's
  string during construction, so the painter's measure() is a cache hit and
  layoutCount never moves. The instrument consumed the thing it measures before
  measuring it — the third time this session that a harness, not the code, gave
  a confident wrong answer. One-line fix: m.clear() before the baseline capture.
  Minor 1 (bundled): test 6 asserts nothing about this task — it builds no
  painter and never touches the threshold, so no mutation of this task's code
  can redden it. It is also not the spec's criterion 6, which requires extents
  compared across two thresholds.
  Minor 2 (deferred, reporting accuracy): the Step 2 transcript predates the two
  fixture corrections, so its line numbers map to a pre-correction file. The
  output is genuine and internally coherent; the report implies the final file
  was what was run.
Task 5: the first ruling is confirmed empirically, with numbers the next task
needs. LOD off: painter 14,039 items, reference 14,039, differential clean. LOD
on: 13,923 items, culledTextCount 116, text ops 25 against the reference's 141
(141 - 116 = 25), and NON-TEXT OPS IDENTICAL either way (13,898 = 13,898). The
red differential is culling alone; there is no second disagreement hiding under
it. The implementer's report misread the matcher's cursor (1,258) as the
painter's op count — carry the real numbers into Task 6.
Task 5: the second ruling is confirmed. fit gives exactly 0.38 px/unit
(0.95 x min(400/1000, 300/750)) and chain.scaleMagnitude equals view.scale
exactly here, so the boundary fixture's product is exactly 3.0 — the < versus <=
distinction is genuinely pinned, and test 4 was seen red under <=.
Task 5: fix round 1/5 opened — 1 Critical + 1 Minor bundled.
Task 5: fix round 1 completed in two sends (commits c9a0b97..727cd74). The
second send was because the round was not finished: test 6's named killer was
named but not fired, and this repo's rule is that a named killer is not one
until it has been seen to fire.
Task 5: RESULT worth carrying to the mutation log — mutant 10 ("apply LOD inside
entityBounds") HAS NO SITE for the criterion it was written against. Fired for
real (extents.dart copied aside, mutated, restored by copy, engine suite 777/777
after). It does not redden test 6, because entityBounds has no channel to a
painter's minTextCapPixels: both reads recompute identically regardless of which
painter ran, and two identical wrong answers still compare equal. The mutation
reddened three other tests in the file instead, via the spatial index dropping
the collapsed-bbox entity from its query window.
  What this means for the spec: criterion 6 (extents bit-identical at two
  thresholds) is STRUCTURALLY GUARANTEED rather than testable. Test 6 is a guard
  against a future design mistake — someone threading the threshold into the
  extents path — not evidence about today's code. The implementer corrected the
  test's comment to say so rather than defending the unfired claim. Same class as
  Plan 3e's "two spec mutants have no site, and that is the design working";
  Task 9 records it as a restatement beside its row, never as a silent kill.
Task 5: fix round 1/5 (2 addressed, 0 open; commits c9a0b97..727cd74, two sends).
Re-reviewer confirmed m.clear() sits before the baseline capture and empties the
exact maps measure() consults, that only test 1 reddens under the cull-after-
measure mutation with layoutCount 1->2, and that the corrected test 6 comment
states what the test cannot do rather than overclaiming. No engine leftovers.
Task 5: complete (commits 4cd23da..727cd74, review clean)
Task 6: Ruling — the plan's Task 6 fixture arithmetic has the same defect Task 5's
did, and I am correcting it in the dispatch rather than letting it cost a round.
The plan states "about 0.05 px per world unit" for 16,000 units into kViewport's
800; ViewportTransform.fit applies a 0.95 margin, so it is 0.0475. On-screen cap
height is therefore h x 0.35 x 0.0475 = h x 0.016625, and the plan's three
heights (40, 172, 800) give 0.67 / 2.86 / 13.3 px — which puts EDGE BELOW the
3.0 threshold instead of just above it, so the fixture would not straddle at all.
3.0 falls at h ~= 180.5 before any extents growth from the text boxes themselves.
— Why: the exact number cannot be computed from here, because the text entities
may push doc.extents past the root line and move the fit again. The dispatch
carries the corrected arithmetic AND repeats the plan's own instruction to print
the three measured cap heights and move the heights, never the threshold.
— Costs if wrong: the implementer prints the real numbers and adjusts, which is
what the step already requires; the correction saves a round rather than
deciding anything.
Task 6: implementer DONE (commit 666afac, 6 files, +294/-21). Widget suite green
again — 291 pass, 1 skip, 0 fail — so the deliberate red from Task 5 is closed.
Engine 777; goldens 29 with no PNG moved; analyze clean; rig passes both text
rows; trap files unstaged.
  Deviation 1, and it is a finding against MY plan: the briefed three-label
  fixture had a surviving mutation. A walk using camera.scale instead of
  chain.scaleMagnitude culls the same single label, so the fixture could not tell
  the two rules apart — the degenerate-fixture class this repo names as dominant,
  in the very task written to catch it. A fourth label, NEAR at 2.826 px, now
  separates them.
  Deviation 2: the briefed op-for-op comparison cannot pass on any fixture
  containing a line, because a line takes the screen-space bypass while text
  keeps the full residual. Replaced by a comparison through flatten.
  Deviation 3: minTextCapPixels had to be optional-POSITIONAL on both recording
  helpers — Dart forbids mixing an optional-positional camera with a named
  parameter.
  Deviation 4: three sites sat within 2% of being silently emptied
  (text_paint_test.dart corpus rows 3.059 px, its two non-vacuity guards, and
  draft_painter_root_test.dart 3.008 px); all pinned at 0.0 explicitly. The rig
  was LEFT on the shipped threshold at 3.0006 px — 0.02% clear — on the argument
  that it must measure what production paints, and instead gained a printed
  culledText and a StateError on an emptied camera.
Task 6: review dispatched on the most capable model. Deviation 4's rig decision
is weighted hardest: 0.02% means any corpus change flips it, so the question is
whether the StateError makes a flip loud rather than silent, and whether it
fires on the right condition.
Task 6: review — spec compliant, quality approved, 1 Important + 2 Minors.
  Reviewer verified the oracle really does derive its own cull
  (reference_walk.dart:181 against draft_painter.dart:869, no shared decision
  helper, no counter read) and reproduced deviation 1's mutation: camera.scale
  reddens the new test only because NEAR exists — 2.826 px through the chain
  against 8.075 px through the camera, the only one of the four labels that
  changes side. With the briefed three the mutant stays green. My plan's fixture
  was degenerate and this task caught it.
  Also confirmed: the flatten comparison is stricter than a length check
  (DrawnItem.matches compares kind including the text string, ResolvedStyle,
  closed, and three transformed points at 1e-6); the optional-positional
  parameter cannot take a camera by mistake because the types differ; the
  single-measurer collapse survives; the residue after the fix is zero, not
  smaller, because expectPainterSupersetOfReference requires every reference op
  to match.
  Important: two transcripts in the report are not the output of the command
  printed above them. The reviewer applied the mutation and got
  "Expected: <5> Actual: <3>"; the report shows "<4>/<3>", which is the other
  mutation's output pasted twice. A second block is labelled with a command that
  yields +16 and shows +22. Both mutations do kill, so nothing is false in
  substance — but "never synthesize test output" is a non-negotiable, and its
  reason is exactly what happened here: the claim only held up because a
  reviewer re-ran it.
  Minor 1 (bundled): the rig's guard fires on textOps == 0, an emptied camera,
  which is the right condition — but at a 0.02% margin the realistic failure is
  drift, not emptying, and drift stays silent.
  Minor 2 (deferred): differential_test.dart:63 was in the brief's modify list
  and is correctly unchanged (its fixture carries no text and the defaults
  match), but the deviation was not called out among the four.
Task 6: two "cannot verify from diff" items resolved by the controller — the
margin table's numbers came from instrumentation removed before the commit, so
they are unverifiable, but the three thin sites are pinned at 0.0 regardless and
the decisions stand without them; and the 5-minute rig transcript was not re-run,
which is proportionate.
Task 6: fix round 1/5 opened — 1 Important + 1 Minor bundled.
Task 6: fix round 1 landed (commit 65fc380 on 666afac). Both mispasted blocks
re-run and replaced, with a new section saying explicitly that the originals were
left in place so the correction is visible rather than silently swapped. All
three mutation transcripts now come from one code state.
  Finding B's answer is better than what was asked for. Rather than add a double
  field to DraftPainter — a per-entity write on the frame path, against the first
  non-negotiable, to serve a rig print — smallestDrawnCapPixels recovers the
  number from OUTSIDE via public API: the cull is cap < threshold, so the largest
  threshold that keeps every label is the smallest survivor. Bracket then bisect
  with query-only paints, ~15 paints, nothing added to the frame. It also
  cross-checks the earlier instrumented figure by an independent route —
  bisection 3.0005 px against instrumentation 3.0006 px — which retires the
  reviewer's "cannot verify from diff" on the margin table for the row that
  mattered.
  The number it surfaced is the point: 500k whole-drawing sits at 3.0000 px,
  margin 1.0000x. One rounding from moving, and invisible before this.
Task 6: scoped re-review dispatched.
Task 6: fix round 1/5 (2 addressed, 0 open; commits 666afac..65fc380). The
re-reviewer verified the bisection properly rather than accepting it: a label
survives iff threshold <= cap under the strict <, so the largest threshold
keeping every label is exactly the minimum surviving cap and is ACHIEVED, not
approached; the bracket starts from a known-good value and terminates on a
relative tolerance rather than an iteration count; the helper paints throwaway
probes into a NullDrawSink outside every timed block; and 3.0005 / 3.0006 are two
independently implemented measurements.
Task 6: fix round 2/5 opened — one comment, and I am spending a round on it
deliberately. paint_microbench_test.dart:66-67 claims a per-entity write would
breach this package's first non-negotiable. It would not:
draft_painter.dart:275 declares `double _arcCx = 0, _arcCy = 0, _arcR = 0;`,
written per dashed arc and per dashed circle on the same hot path, a few lines
from the comment stating that constraint. A double field assignment is not an
allocation and this codebase relies on that.
— Why a round rather than a deferred minor: the false claim is in the tree, it is
about the project's FIRST non-negotiable, and Task 3 of this very plan existed
almost entirely to repair a comment that had gone false. A future reader would be
steered away from a legitimate technique. The decision it justifies is correct
and is being kept; only the justification changes.
— Costs if wrong: one cheap round and one small re-review on a comment.
Task 6: fix round 2/5 (1 addressed, 0 open; commits 65fc380..d7d4c04). Comment
only; suite identical at 291/1/0. The re-reviewer verified all three cited line
numbers against draft_painter.dart rather than trusting the comment, and checked
the opposite failure too — that the correction did not swing into implying the
field would have been better. It reads as a preference, decided on API-surface
grounds, which is what it is.
Task 6: complete (commits 727cd74..d7d4c04, review clean, 2 fix rounds)
Task 7: first dispatch died mid-exploration — the machine slept, not a task
failure. Tree verified clean: HEAD still d7d4c04, no golden file written, no
staged change. Re-dispatched fresh on the same brief; nothing to recover.
Task 7: second dispatch also died, differently — agent stream stalled with no
progress for 600s. Tree verified clean again (HEAD d7d4c04, no lod file, nothing
staged), and no hung test process: the only dart processes running are the IDE's
language servers and MCP daemons on a DIFFERENT Flutter (3.27.3, not the project's
3.47.1), all at 0% CPU.
  Before spending a third agent I ran the golden command by hand: 29 pass in 4.5
  seconds. The command is sound, so both failures are agent infrastructure — one
  sleep, one stream stall — not the task. Third dispatch sent, same brief, with a
  note telling it to commit as soon as work is verified rather than saving it all
  for the end, so a third infrastructure death costs less.
Task 7: third dispatch landed (commit 383e15c), golden suite 35/35. But the
report's one concern is a real defect, not an intended property, and the
controller confirmed it before dispatching any review — a correctness concern is
closed before review, not after.
  Evidence. md5: the three canvas PNGs all differ; the three VERTICES PNGs are
  byte-identical (fa615b021d6cab1b6942c772c4fabaed x3). Control: the existing
  vertices/text_ladder_1..5.png are all different from each other and ~6119
  bytes, so the vertices backend draws text perfectly well. Visual: canvas rung 1
  shows the large text block, the small one and three anchor ticks; vertices rung
  1 shows ONLY the three ticks — no text at all, 4345 bytes.
  So the vertices half of this ladder pins nothing: three identical images across
  three thresholds, because there is no text in any of them for the threshold to
  act on. The report's explanation — "text bypasses the triangle buffer entirely"
  — is disproven by the control.
Task 7: sent back to the implementer before review, as a correctness concern.
Task 7: CONTROLLER WAS WRONG, and the record should say so. I inferred from the
five existing vertices/text_ladder PNGs differing that text renders under the
vertices backend, and therefore that this ladder's three identical vertices PNGs
were a defect. The implementer traced the mechanism and made a checkable
counter-claim; I opened vertices/text_ladder_1.png myself and it is ONE RED
VERTICAL RULE and nothing else — no glyphs anywhere. The vertices golden path
rasterises drawVertices submissions through TriangleRasterizer and never sees
drawParagraph, so no vertices golden in this suite has ever carried text. The
five differ because each text_ladder rung is a DIFFERENT FIXTURE with different
anchor geometry, not because any of them draws a glyph.
  My inference was the same shape as the error I was accusing the report of:
  a plausible mechanism applied to the wrong case.
Task 7: Ruling — the three byte-identical vertices PNGs stay, all three.
— Why: they cannot pin the threshold and the traced comment now says so
explicitly, but they keep this ladder structurally identical to every other
ladder in the suite and they carry the same guard the other vertices goldens do
— that flushing before an unbatchable op does not corrupt the batch and the
picture reaching the rasteriser is never empty. Redundant golden bytes are cheap;
a ladder shaped differently from its neighbours for reasons a reader has to
reconstruct is not. The threshold itself is pinned by the three canvas PNGs.
— Costs if wrong: three redundant 4KB files, and a reviewer asking why — which
the comment now answers in full.
Task 7: the third dispatch stalled again mid-verification, this time after doing
the work. Its edit is uncommitted and confirmed COMMENT-ONLY (34 insertions,
9 deletions, zero non-comment lines); the PNGs are untouched and correct.
Resuming the same agent to verify and commit rather than committing from the
controller, which would skip review.
Task 7: review clean — spec compliant, quality approved, no findings. The
reviewer traced the mechanism itself rather than accepting my ruling: confirmed
VerticesDrawSink.text flushes then calls _fallback.text unconditionally, that
CanvasDrawSink.text draws via canvas.drawParagraph on the real Canvas, and that
the vertices observer is attached to drawVertices submissions only — so no branch
lets text reach the triangle buffer. It opened vertices/text_ladder_1.png and
_3.png and found no glyphs, and confirmed the three canvas PNGs differ and show
what each rung claims. Comment judged to leave the truth plainly.
Task 7: complete (commits d7d4c04..85ed531, review clean, 3 infrastructure
restarts and 1 correctness round before review)
Task 8: implementer DONE (commits 4a66f13, d069067). Low Power Mode read 0
before every timed run. Both flutter drive runs passed; project.pbxproj reverted,
not committed.
Task 8: THE RESULT THAT MATTERS, and it fires the plan's stop clause.
  Working-set camera: flat at every threshold 0.0-10.0 — 18 layouts, 0 culled,
  18 live paragraphs, smallest surviving cap height 53.67 px, five times the
  widest threshold tried. Gate rows 3 and 5 pass comfortably.
  Whole-drawing camera at the shipped 3.0: 3,876 distinct paragraph keys needed
  in ONE frame against a 512-entry cache, and the report claims 3,876 new layouts
  on every repeated identical frame — zero cache hits. Baseline was 4,140, so LOD
  bought about 6%, not the whole thing.
  => Gate rows 1 and 2 (whole-drawing repeat frame: zero new layouts, zero
  paragraph evictions) MISS at the shipped threshold. They clear at 6.0
  (liveParagraphs 94, evictions 0).
  The step is a BAND, 3.0 to 6.0, not the single point the plan predicted. Cause:
  the corpus's mirroredFraction/nonUniformFraction placement transforms give
  per-instance scaleMagnitude spread even at one fixed logical height. Reported
  rather than smoothed, which is what the brief asked for.
Task 8: Ruling — Task 9 records the miss and does NOT tune. Raising
kMinTextCapPixels to 6.0 would close the gate, and that is precisely what the
plan forbids: 3.0 was chosen from a readability argument (below three pixels a
glyph cannot resolve two strokes), 6.0 would be chosen because a row needs it.
Ruling 4's one permitted raise of kParagraphCacheLimit is now MEASURABLE for the
first time — 3,876 distinct keys — but spending it is a decision about holding
3,876 native paragraphs, and it belongs to the human with the number in front of
them, not to me inside a gate run.
— Costs if wrong: the exit gate closes with two criteria recorded as MISSED
instead of PASSED, which is a true statement about the code either way.
Task 8: review dispatched on the most capable model, weighted on three things —
whether "3,876 on every repeat frame" is genuinely a repeat-frame measurement
rather than a cold paint (that distinction alone decides whether two rows fail),
whether a ladder produced by a temporary loop that was then reverted is
reproducible from the tree, and whether device runs that measured culledText=0
on both arms are a wiring check or worthless.
Task 8: review — spec compliant, quality approved, 3 Importants, all of which
must land before the results note is written.
  CORRECTION TO MY OWN EARLIER LEDGER ENTRY AND TO WHAT I TOLD THE HUMAN:
  "3,876 distinct paragraph keys" is wrong. 3,876 is the LAYOUT count (misses).
  The reviewer read the column properly: at threshold 0.0 the table shows 4,140
  layouts against 4,928 draws, so layouts sits reliably on neither side of the
  distinct-key count. The committed rig already prints
  "DISTINCT CACHE KEYS: n (limit 512)" at paint_microbench_test.dart:395-399 and
  that line was never quoted. So the number Ruling 4 would need to be spent
  against is still unmeasured, and the choice I put in front of the human was
  framed on a figure that does not mean what I said it means.
  The gate miss itself is unaffected: liveParagraphs=512 saturated with
  paragraphEvictions=3364 proves more than 512 distinct keys in the frame, so a
  repeat frame cannot be zero-layout under LRU whatever the exact count is.
  Important 1: the distinct-key misreading above.
  Important 2: the device runs do not verify the wiring they claim. LOD=true and
  LOD=false produce byte-identical output, so nothing in either transcript
  distinguishes the branches and the define reaching DraftPainter is unconfirmed.
  They are a legitimate negative control — they show the working-set camera is
  untouched and the check costs nothing measurable — and the report says so
  plainly, but one printed field earns the wiring claim.
  Important 3: the ladder is not regenerable from the tree. The revert itself
  verifies (the test file is byte-identical to 85ed531, nothing untracked); what
  is lost is the loop. This repo has paid for this before — an earlier plan's
  headline web rows are recorded as "not reproducible from what was committed."
  Also owed: the whole-drawing repeat-frame transcript line. The reviewer traced
  the path and confirmed it IS structurally a repeat-frame measurement and IS
  reproducible from the committed tree with the plain rig command — the report
  simply never pastes the line, and that one line is what makes two gate rows
  fail.
Task 8: fix round 1/5 opened — 3 Importants plus the missing transcript line.
Task 8: fix round 1 partially landed (commit ad3d6d1, 3 files, +116/-4) — the
true distinct-key measurement, the ladder loop landed in-tree so the table is
regenerable, and the threshold printed in device transcripts. The device re-run
was still outstanding when the agent's turn ended.
Task 8: controller intervention. The agent ended its turn waiting on a background
device run it had started, which it could never be notified about. That run was
hung, not slow — 0% CPU for fifteen minutes against a normal drive of about five.
Killed it and reverted apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj,
which the drive had rewritten; that file is this repository's single sanctioned
git checkout. Nothing else in the tree moved.
Task 8: Ruling — the device re-run gets one more attempt with a bounded wait, and
if it hangs again it is recorded as attempted-and-hung rather than retried.
— Why: no failable criterion in this plan is a timing, on purpose, so the device
pass buys exactly one thing — transcripts where the two arms visibly differ in the
threshold they were handed. The widget-level rig already exercises both thresholds
on a camera where the cull actually fires, so the wiring claim has a second
source. A third attempt would cost more than the evidence is worth.
— Costs if wrong: the results note carries a device row marked attempted-and-hung
instead of a measured one, on a row that gates nothing.
Task 8: fix round 1/5 (4 addressed, 0 open; commits d069067..ad3d6d1). The
re-reviewer verified the thing that mattered most: distinctKeys and layouts are
two independent readings — the first from a query-only TextKeySink pass, the
second from a separately constructed measurer and sink — neither derived from the
other. They coincide at 3,876, which is precisely when a misread column looks
right, so measuring them apart is what makes the number usable.
  => THE NUMBER RULING 4 NEEDS NOW EXISTS: 3,876 distinct visible paragraph keys
  at the whole-drawing camera on the 50,000-entity corpus, against a 512 limit.
  My earlier correction stands as a correction — 3,876 had not been established
  as the distinct count when I first relayed it — and the value happens to match.
Task 8: controller verified the suite count independently rather than accepting
291 -> 297 as unexplained. 297 total, 262 with goldens excluded, so 35 golden
tests run in the plain suite as well: the six are exactly Task 7's golden ladder.
No loose end.
Task 8: fix round 2/5 opened — one comment. The ladder loop reintroduces a second
FlutterTextMeasurer into the file whose own comment records that two measurers was
the bug this plan removed. The code is right — a ladder row needs a cold cache,
and sharing the outer measurer would make every row after the first a warm
reading — but nothing says so, and Ruling 1 exists because a second measurer in
this file once made a rig report plausible numbers for a wiring that did not
exist. A future reader either believes the other comment and is confused, or
"fixes" it and silently converts thirteen of fourteen rows to warm readings.
Task 8: fix round 2/5 (1 addressed, 0 open; commits ad3d6d1..1dc76d4). Comment
only. The re-reviewer checked the cross-link in BOTH directions and confirmed the
target comment exists and is on topic rather than dangling, and that the
consequence of sharing is stated as a mechanism a maintainer can act on.
Task 8: minor (deferred): task-8-report.md's tail never records fix round 2 or
commit 1dc76d4. The ledger carries it, and this workspace is archived rather than
deleted in this repo, so the gap is in the archived paper trail. Not worth a
third round; flagged for the final whole-branch review to triage.
Task 8: complete (commits 85ed531..1dc76d4, review clean, 2 fix rounds)
Task 9: implementer DONE (commits 645b027, 2c6bdaa, 8f45e82, d113d2d, 6efd7fa).
Gate 11 of 13 pass, 2 miss, 0 unevaluable. Mutants: 14 killed, 1 restatement,
1 logged unmeasurable. Rows 1 and 2 left missing at 3,876 against a bar of zero;
kMinTextCapPixels untouched at 3.0 and Ruling 4's raise written up as the human's
option with its cost and left unspent.
Task 9: four self-reported weaknesses, all volunteered rather than found, and two
of them land on MY spec rather than on the implementation.
  1. Mutant 7 survived its own suite: every measurer test passed both cache
  bounds explicitly, so the DEFAULTS were never exercised. Killed only after a
  new test was added. The same hole would hide a wrong paragraphLimit default and
  was not audited for elsewhere — I have asked the reviewer to do that audit.
  2. Criterion 10 is toothless at corpus scale, and it is the row I wrote to gate
  the whole cache split. doc.extents measures 12 distinct strings, not the 4,020
  the spec assumed, so the row passes under both mutations it exists to catch.
  The criterion is not wrong; the place it measures is. Its teeth are in a
  unit-scale test, which the reviewer is checking.
  3. Three test changes the brief did not list — row 7 had no test at all, mutant
  7 needed a killer, row 10 had no in-tree procedure. Scope call to adjudicate.
  4. The rig asserts almost nothing: 608,634 metrics evictions printed and
  passed. Flagged as a follow-up rather than fixed.
  Also: Plan 3f's ledger is not yet archived to docs/superpowers/ledgers/.
Task 9: review dispatched on the most capable model, with an explicit instruction
to spot-check at least two mutation transcripts by re-running them — this plan
already had one report whose pasted blocks did not come from the commands above
them, caught only because a reviewer re-ran the mutation.
Task 9: review clean — spec compliant, quality approved. The reviewer re-fired
two mutants itself and both reproduced byte-for-byte (mutant 7's failure line and
mutant 6's five reddened tests), and cross-checked the ladder's internal
arithmetic: evictions equal distinctKeys - 512 at every threshold up to 3.0, and
the warm repeat frame's 3,876 equals 3,364 + 512. Nothing pasted.
  It confirmed all four self-reported weaknesses are accurate rather than
  understated, and performed the audit I asked for: it mutated paragraphLimit's
  default and found only a restatement test fails, so that default is indeed
  still behaviourally unexercised.
  It also judged the three unbriefed test additions the right call — row 7 had no
  runnable form, so the alternative was recording a hole, and the added test is
  non-vacuous by construction.
Task 9: minor (deferred to the final review): reference_walk.dart:36's
minTextCapPixels default survives being set to 0.0 against the whole suite,
shadowed by fixtures.dart:183's own default — the same untested-default pattern
as mutant 7, low consequence.
Task 9: minor (deferred to the final review): the "turn the rig's prints into
assertions" follow-up lives only in the task report. The ledger archives that,
but it is not in the results note or STATUS.md, so it will not survive as a
visible action item. One line in the note's "did not close" list fixes it.
Task 9: minor (deferred to the final review): STATUS.md's header says "Verified
against main at d113d2d" and HEAD is 6efd7fa — unavoidable for the commit that
writes it, but the suite table is one commit stale.
Task 9: complete (commits 1dc76d4..6efd7fa, review clean)

ALL NINE TASKS COMPLETE. Proceeding to the final whole-branch review.
FINAL WHOLE-BRANCH REVIEW: no Critical. The cross-task shape that cost Plan 3e a
Critical after seventeen clean per-task reviews is not present here. Verified
across boundaries and independently green: engine 777, widget 299 + 1 skip,
analyze and format clean on all three packages.
  Confirmed: exactly one production measurer construction in the whole diff
  (harnessMeasurer, main.dart:156, released at :456); DraftCanvas constructs none;
  the two cull rules at draft_painter.dart:869 and reference_walk.dart:181 are
  independently computed and both strict <, with no drift after nine tasks; both
  culls precede their measure() and the reviewer FIRED that ordering itself —
  moving the painter's cull after measure() reddens text_lod_test.dart:85; the
  seventeen-site sweep held, with the five thin sites at 1.002x-1.08x pinned
  explicitly at 0.0 and sink_comparison.dart at 9.7x correctly left on the
  default; kMinTextCapPixels 3.0 and kParagraphCacheLimit 512 both untouched; no
  trap file, no CLAUDE.md change, no engine change, no regenerated PNG.
  IMPORTANT: paint_microbench_test.dart has three FlutterTextMeasurer
  constructions (:174, :255, :620) and ZERO clear() or addTearDown in the file.
  Two are new in this plan. The :620 one is inside the ladder loop — 7 thresholds
  x 2 cameras x 2 corpus sizes, each iteration leaving up to 512 live native
  paragraphs nothing releases. Test-only and reclaimed at process exit, but it is
  exactly the "moved the leak rather than fixing it" shape the spec's own
  unqualified ruling was written against, and it is the one place the Task 4
  ownership sweep could not have covered because these sites did not exist yet.
  Triage of the eight deferred minors: six left (brief-verification or
  archived-paper-trail accuracy, tree correct in each case); reference_walk.dart's
  untested default left after the reviewer fired it and confirmed low consequence;
  the rig-prints-into-assertions follow-up FIXED BEFORE MERGE, because it exists
  only in a git-ignored task report and would not survive as an action item.
  Also to correct while committing: the results note and STATUS.md both say the
  untested-default shape "was not audited elsewhere" — it was, and there are three
  instances. And STATUS.md's header names one commit older than HEAD.
  On criterion 10: labelling judged adequate — flagged in four places, each
  naming both mutations it fails to catch, and its unit-scale form genuinely
  reddens under mutants 6 and 12. 11-of-13 stands as "held by the unit fixture".
FINAL FIX WAVE dispatched: one agent, the complete findings list, then exactly
one scoped re-review.
FINAL FIX WAVE: all five findings ADDRESSED (commits 6efd7fa..bce35c7). The
re-reviewer checked the one thing that decided whether finding 1 actually worked:
the ladder loop uses per-iteration paragraphs.clear() inside the loop body, NOT
addTearDown — which accumulates per test and would have left the peak population
unchanged while looking fixed. The two ordinary sites use addTearDown correctly.
  Constants verified in source rather than from the report: kMinTextCapPixels 3.0
  at draft_painter.dart:40, kParagraphCacheLimit 512 at
  flutter_text_measurer.dart:11. Ruling 4's raise unspent. The results note still
  reads MISS plainly for rows 1 and 2 and the Ruling 4 section is unsoftened.
  Both suites re-run directly by the reviewer: 299 + 1 skip, and 777. Match.
FINAL: minor (deferred, recorded not fixed): the ladder loop's per-iteration
clear() has no try/finally, so an exception mid-iteration would skip it. Not part
of any finding, raised unprompted by the re-reviewer, and harmless in a
tag-gated rig — recorded so it is not rediscovered.
PLAN COMPLETE. Archiving this ledger to docs/superpowers/ledgers/ before the
workspace is removed — that ordering is the lesson Plan 3e recorded, and doing it
the other way round loses the record.
