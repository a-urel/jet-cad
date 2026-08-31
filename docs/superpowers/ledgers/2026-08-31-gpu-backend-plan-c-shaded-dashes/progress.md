# SDD ledger — plan: docs/superpowers/plans/2026-08-31-gpu-backend-plan-c-shaded-dashes.md

Branch: `plan-c/shaded-dashes`, cut from `main` at `d52d2a9`.
Spec: `docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md` (revision 4).
Twelve tasks. Subagent-driven, per the human's choice.

## Pre-flight scan

### Task pairs that share a file or an interface

| pair | shared | one produces | the other consumes | finding |
|---|---|---|---|---|
| T1 → T5 | `geometry_collector.dart` | `shadesDashes => true`, empty `beginDash`/`endDash` | the real bracket state | **CONFLICT** — see Ruling P1 |
| T1 → T2 | `DrawSink` | the three members | the painter's branch | clean |
| T2 → T5 | the painter's route | brackets to a shading sink | the collector must understand them | **CONFLICT** — ordering, Ruling P1 |
| T4 → T5/T6 | `instance_record.dart` | 16 floats, `_writeDash` | dash values written | clean |
| T4 → T8 | `kInstanceVertexLayout` vs the shader bundle | `kind_half`, `dash` | the GLSL attribute list | **CONFLICT** — Ruling P2 |
| T7 → T8 | the uniform block | `buildFrameInfo` writes float 18 | `float dash_scale` in FrameInfo | clean — a written float no shader reads is inert |
| T8 → T9 | `expandInstances` signature | `{required double dashScale}` | `gpu_comparison.dart`'s call | **CONFLICT** — Ruling P3 |
| T9 → T10 | `measurePaintedAgreement` | the two-route helper | the pixel differential | clean |
| T3 → T10/T11/T12 | `shadedDashFixture` | handles 900–916 | the gates | clean; T11 adds 903, and says so |
| T5 → T6 | `_suppressJoins`, `_pending*` | polyline path | arc path | clean — T6 sets `_suppressJoins = false` explicitly |
| T6 → T10 | the arc phase law | per-chord factor and phase | the declarative oracle | clean |

### Task self-consistency

| task | its tests against its code | finding |
|---|---|---|
| T1 | six sinks, three members each | **the "every non-shading sink" test lists only two** — Ruling P4 |
| T2 | three call sites, three tests | clean; placeholders are marked as the file's own scaffolding |
| T3 | the fixture's own guard test | clean; Step 4 makes Ruling C5 evidence rather than assertion |
| T4 | `writePoint` takes no dash args but the test asserts the slots read 0 | **Ruling P5** |
| T5 | the `else` branch trap in `_runTo` | clean — the plan flags it explicitly at the site |
| T6 | `%`/`*` precedence in the phase line | clean — the plan flags it and requires parentheses |
| T7 | `dashScaleFor` extracted so the third test has a seam | clean |
| T8 | expander mirrors the shader statement for statement | clean |
| T9 | "without dash varyings, nothing changes" written first | clean |
| T10 | `expectInstanceMatches`, `primitiveRuns`, `isSorted` are undefined | **Ruling P6** |
| T11 | fourteen mutants, two declared survivors before firing | clean |
| T12 | device run, results, STATUS | clean |

### Rulings, made before Task 1

**Ruling P1: execute the tasks in the order 1, 4, 5, 6, 2, 3, 7, 8, 9, 10, 11, 12
— Task 2 moves after Task 6.** As the plan numbers them, Task 2 makes the
painter hand the collector undashed geometry three tasks before Task 5 teaches
the collector what to do with it. `apps/dev_harness_2d/lib/gpu_arm.dart` paints
a real document into a `GeometryCollector`, so in that window arm C would draw
every dashed entity **solid** — a silent behavioural regression no gate in this
repo can see. Reordering closes the window entirely: the collector understands
the bracket before the painter emits one. Task 2's own tests use
`RecordingDrawSink(shadesDashes: true)` and do not touch the collector, so it
loses nothing by moving. Task 3 stays after Task 2 because its guard test paints
through a shading sink. **Cost if wrong:** none identified; the dependency
graph is strictly better satisfied by this order. Task numbers keep their plan
identities so `task-brief` extracts the right text.

**Ruling P2: the vertex layout stays in Task 4, and the resident GPU path is
knowingly inconsistent from Task 4 until Task 8.** The record's float order
changes in Task 4 and the shader bundle's attribute list only in Task 8, so
pipeline creation would fail on a device in between. Moving the layout to Task 8
would not fix it — the *record* is what changed — and would break the property
`kInstanceVertexLayout`'s own doc comment claims, that its offsets move in
lockstep with `InstanceFieldOffset`. **So: no device run, and no `flutter run`
of the harness's GPU arm, between Task 4 and Task 8.** `flutter test` cannot
reach the pipeline and is unaffected. **Cost if wrong:** somebody runs the
harness in that window, sees a blank or garbled arm C, and debugs a
known-broken intermediate.

**Ruling P3: Task 8 owns the `measureResidentAgreement` signature change, not
Task 9.** Task 8 changes `expandInstances` to require `dashScale`, which breaks
`gpu_comparison.dart` — its only caller — and a task that ends with a
non-compiling suite is not a completed task. Task 8 therefore adds
`{required double dashScale}` to `measureResidentAgreement` and threads it;
Task 9 consumes that signature and adds `measurePaintedAgreement` beside it.
**Cost if wrong:** one parameter is added a task earlier than the plan's prose
says, in the file the plan already assigns to both tasks.

**Ruling P4: Task 1's "every non-shading sink" test must check every one of
them or be renamed.** As written it constructs only `NullDrawSink` and
`RecordingDrawSink` — the two with no-argument constructors — while
`CanvasDrawSink`, `VerticesDrawSink` and `TextKeySink` need arguments. A test
whose name claims more than it checks is this repo's named failure mode. The
implementer builds all five (the two Flutter sinks need a `Canvas` over a
`PictureRecorder`, which `test/support/spy_canvas.dart` already provides) or
narrows the name to what it covers. **Cost if wrong:** a sink could ship
declaring `shadesDashes => false` while silently accepting `beginDash`.

**Ruling P5: `writePoint` writes zeros into the four dash slots explicitly.**
It takes no dash arguments by design — a `point()` is never dashed, since the
painter returns before `_patternFor` is ever called for one — but the test
asserting the slots read 0 is only meaningful if the function writes them.
`Float32List` zero-initialises and `_instances` never recycles an index, so
this is belt-and-braces rather than a live defect; it costs four stores per
point and makes an assertion that would otherwise be testing the allocator
into one that tests the writer. **Cost if wrong:** four redundant stores per
point instance.

**Ruling P6: Task 10's undefined helpers are the implementer's to write, and
`isSorted` is not a `matcher` matcher.** `expectInstanceMatches`,
`primitiveRuns` and `drawnRunCount` are named in the plan without bodies, which
is deliberate — they are test scaffolding whose shape depends on the oracle.
But `isSorted` does not exist in `package:matcher`; the implementer writes an
explicit pairwise comparison rather than reaching for a matcher that is not
there. **Cost if wrong:** a compile error the implementer hits in its first
run.

---

## Task log

### Task 1 — the dash seam on `DrawSink`

**Pre-flight miss, recorded because the scan should have caught it.** `DrawOp`
is `sealed`, so adding `BeginDashOp`/`EndDashOp` broke exhaustive switches in
`test/support/differential.dart` and `test/support/vertices_differential.dart`.
The scan's "task pairs that share a file" table had no row for either file
because the plan's file list does not name them — the dependency runs through
Dart's exhaustiveness checking, not through an import. Repaired by the
implementer with commented `break` arms.

**Carried to Task 5:** those two `break` arms are silent no-ops. Nothing emits
the ops today, so they are correct now; the moment a shading sink routes real
dash geometry through either oracle, a `break` makes the comparison *skip* that
geometry instead of failing loudly. Task 5's dispatch must carry this pointer.

Task 1: complete (commits d52d2a9..436a416, review clean — Spec ✅, quality
approved, zero findings at any severity). Ruling P4 honoured by the preferred
route: all five non-shading sinks constructed, test name widened to match.
Suites: `jet_cad_2d_flutter` 484 pass / 1 pre-existing skip; harness 72 pass.

### Task 4 — the record grows to sixteen floats and reorders

**A plan inaccuracy, found by running it.** Task 4 Step 6 predicted that
`instance_expander_test.dart`, `collector_differential_test.dart` and
`resident_pixel_differential_test.dart` would all fail on the widening. **None
of them did** — they read record fields through `InstanceFieldOffset` by name,
so the reorder moved them in lockstep. The reviewer verified the explanation
independently rather than accepting it. The plan's prose overstated the blast
radius; no code effect.

**What the reorder actually broke, which the plan did not name.**
`test/gpu/geometry_collector_test.dart` held three literal `sublist(1, 5)`
slices into a record. A field reorder moves those **silently** — no compile
error, no type error, just different numbers. Repaired by repointing them at
`InstanceFieldOffset.x0`. The reviewer then grepped `lib/`, `test/` and
`apps/dev_harness_2d/` for every remaining literal offset, slice and
`kFloatsPerInstance` arithmetic and found no survivor.

Task 4: minor (deferred): `'a dashed stroke carries its element extent and its
phase'` passes `dashFracStart: 0.0` and never asserts it. Covered at a non-zero
value in `resident_geometry_test.dart`; an incomplete assertion list, not a
coverage gap.

Task 4: fix round 1/5 dispatched — Important: the `'a point is never dashed'`
test allocates a zero `Float32List` and asserts zeros, so deleting
`writePoint`'s `_writeDash` call leaves it green. **The one test written to
prove Ruling P5 does not prove it** — it tests `Float32List`'s
zero-initialisation. This is the degenerate fixture `CLAUDE.md` names, landed
in the task whose ruling exists to prevent it.

Task 4: fix round 1/5 (1 addressed, 0 open — the point-is-never-dashed test now
pre-fills all four dash slots with a plausible dashed record and asserts them
back to zero; mutation fired and killed, `Expected: <0.0> Actual: <18.0>`,
reverted from a `cp` backup as the constraint requires; commits 6e176f6..13c92ca).

Task 4: complete (commits 436a416..13c92ca, review clean).

### Task 5 — the collector shades a dashed polyline

**A plan defect, found by `flutter analyze`.** Task 5 Step 3's sample code
declares a `_dashCycle` field that none of the plan's own steps ever read.
The implementer deleted it rather than suppressing `unused_field`, which is
the right call — `beginDash` uses its own local `cycle`.

Task 5: fix round 1/5 dispatched — two Important findings, both the same
shape: the production code is right and no test can kill a one-line mutation
of it.

1. **Every dash fixture has an honest `totalLength`**, so mutating the cycle
   guard to `pattern.totalLength` passes all ten new tests and the whole
   suite. `dasher.dart` says twice that nothing enforces the declared total
   agreeing with its entries. **The plan deferred the dishonest-pattern
   fixture to Task 11, for M-C1 — that was too late**, and the review caught
   it four tasks early. It moves into Task 5.
2. **The only scaled-residual test uses an isotropic `scale(3, 3)` on one
   axis-aligned segment**, where the per-segment `collectionLen/localLen`
   factor and `_residual.scaleMagnitude` coincide. `scaleMagnitude` is a
   getter already used elsewhere in this same file, so that mutation is a
   plausible edit and it survives. Fixed with an anisotropic `scale(2, 5)`
   over a polyline with one segment along each axis, asserting the 2:5
   **ratio** rather than two magic numbers.

Both fixes require a demonstrated mutation kill, reverted from a `cp` backup.

**Ruling P7: the DISHONEST linetype moves from Task 11 into Task 5's test
fixtures.** Plan Task 11 adds it to `shadedDashFixture` so M-C1 can be fired;
this review shows the same gap exists six tasks earlier, in the collector's
own unit tests, where the guard actually lives. Task 11 keeps its fixture
addition for the corpus-level mutation. **Cost if wrong:** one dishonest
pattern is declared in two places, which is the cheap direction of that
trade.

Task 5: fix round 1/5 (2 addressed, 0 open — a dishonest-`totalLength` fixture
and an anisotropic `scale(2, 5)` polyline with one segment on each axis,
asserting the 2:5 **ratio** rather than magnitudes; both mutations fired and
killed with arithmetically consistent transcripts, 36.0 vs 198.0 and 2.5 vs
1.0, reverted from `cp` backups; commits ad37551..d78cfb4).

Task 5: complete (commits 13c92ca..d78cfb4, review clean). Suite 504 pass /
1 pre-existing skip; `geometry_collector_test.dart` 38 tests.

### Task 6 — the collector shades a dashed circle and arc

**A real defect in the plan's own sample code, found by running it.** Task 6
Step 3 sets `_suppressJoins = true` immediately before `_endRun` to suppress
the seam join on a dashed closed run, and the plan's prose asserts this is
safe because "`_emit` does not consult `_suppressJoins` at all". That is true
of `_emit` and irrelevant: **`_endRun` calls `_runTo`**, and `_runTo` honours
the flag, so the plan's code also suppressed the **interior** join at the
closing chord's start vertex. Measured by the implementer at **27 joins where
28 were required**, on a 29-chord dashed circle.

Fixed with a `suppressSeam` parameter on `_endRun`, independent of
`_suppressJoins`; `_flatten` no longer touches `_suppressJoins` at all. The
reviewer verified the polyline path is unchanged (a dashed polyline still
emits zero joins, a solid closed run still gets its seam) and that the
witness is exact — `joinCount(dashed) == joinCount(solid) - 1`, so reverting
`suppressSeam: _dashActive` to `false` turns it red.

**This is the fourth defect in my own plan's sample code across three tasks**
(`_dashCycle` dead field, the overstated Task 4 blast radius, the deferred
dishonest fixture, this one). Every one was found by running the code, none
by reading it — the same finding Plan A's results note recorded about its own
plan.

Task 6: complete (commits d78cfb4..41b705d, review clean — Spec ✅, quality
approved, zero findings at any severity). Suite 510 pass / 1 pre-existing
skip; `geometry_collector_test.dart` 44 tests. Both mutation kills
independently re-derived by the reviewer, including the chord advance
`2·40·sin(0.1) = 7.986673`.

### Task 2 — the painter routes undashed geometry to a shading sink

Executed sixth, per Ruling P1. **A fifth plan inaccuracy:** the brief's sample
test calls `worldOf(doc)`, which exists nowhere in the repo — the controller
introduced it while correcting a different error in the same line. Read as
`doc.extents`, the idiom four other camera constructions in that file already
use; the reviewer confirmed it gives the extents the test's placement math
assumes.

**The residual-bracket risk was real and was checked rather than assumed.**
The three new branches take early returns out of methods that carry different
`beginResidual`/`endResidual` responsibilities: `_emitScreenSpace` opens *and*
closes its own bracket per branch, while `_emit`'s single call site is
bracketed by its **caller**. A branch that returned without its matching
`endResidual` would corrupt the residual stack for every entity drawn
afterwards, and the damage would surface somewhere else entirely. Both shapes
verified correct by reading.

Task 2: complete (commits 41b705d..d615798, review clean — Spec ✅, quality
approved, zero findings). Suite 513 pass / 1 skip; harness 72 pass. Kill
demonstrated: dropping `* toScreen.scaleMagnitude` from `_dashScale` reddens
the bracket test, `Expected 2.0, Actual 1.0`.

### Task 3 — `shadedDashFixture()`, and Ruling C5 turned into evidence

**Ruling C5 is now evidenced rather than asserted, and the first attempt to
evidence it was itself degenerate — caught by the implementer, not by a
reviewer.** Step 4 required temporarily adding a dashed entity to
`differentialFixture` to prove that a dashed entity there reddens
`test/differential_test.dart`. The first probe was a dashed line of length
**9.43** against a pattern whose first drawn run is **12** units — so it drew
as one continuous span, indistinguishable from a solid line, and only one test
failed while the named gate passed. Re-run at length ≈216.5: four tests fail,
including exactly the predicted "the painter draws a superset of the reference
walk, in order". **The probe fell into the same degenerate-fixture trap the
step exists to guard against**, and the report says so in those terms.

The reviewer re-derived the fixture's numbers independently rather than
reading them: corner turns of 130.0°, 3.00° and 67.0°; the 915/910 crossing at
t = 0.8703; the anisotropy at |Δ| ≈ 0.936 against a 0.05 bar; and the 16.54
repeat count reconciled to the `scaleMagnitude` approximation
(`_dashScale`'s `sqrt(|det|)` ≈ 1.081 against a pure-local-x segment's full
1.8, ratio 1.406 = 16.54/11.76).

Task 3: minor (deferred): the report's prose says "1 of 9" and "4 of 9"
`differential_test.dart` cases; the file has 10, and its own pasted `+6 -4`
tally confirms 10. The load-bearing transcript is correct; the denominator in
the prose is off by one.

Task 3: minor (deferred): `fixtures_test.dart`'s repeat-count guard measures
entity **910** (local path 360) while entity **911**, the dashed circle
(circumference ≈408), is the longest dashed entity. Harmless at 16.54 against
a bar of 4, but a future edit that shrinks only 910 would leave the guard
believing it enforces a whole-document property it no longer checks.
**Flag to the final review.**

Task 3: complete (commits d615798..da56c05, review clean — Spec ✅, quality
approved). Suite 514 pass / 1 skip. `differentialFixture` byte-identical.

### Task 7 — the live scale in the uniform block

**Ruling P8: `render` must call `dashScaleFor`, reversing a constraint I put in
the dispatch myself.** I told the implementer not to introduce a second
composed transform per frame; it complied, reading `collectionToLogical
.scaleMagnitude` inline and leaving `dashScaleFor` as a tested-but-unused
twin. **That is the wrong trade and the fault is the dispatch's, not the
implementer's.** `render` is unreachable from `flutter test` — which is the
entire reason the seam was extracted — so writing the expression twice means
the *tested* copy is not the *shipping* copy, and the device-space mutation
this task exists to prevent becomes a small edit at the uncovered site. The
cost I was guarding against is not a violation: the invariant is "nothing per
entity in steady state, and **O(1) per flush**", `render` already performs two
compositions, and Plan A measured three objects per flush as the accepted
norm. **Cost if wrong:** one `Transform2` allocation per frame, against a
witness for the line that actually ships.

Task 7: complete (commits da56c05..a30d0bc, review clean — Spec ✅, quality
approved, zero findings). The reviewer independently agreed Ruling P8's
reversal was correct and that a third `Transform2` composition per frame is
O(1) per flush, inside the non-negotiable. Suite 517 pass / 1 skip. Kill
re-fired against the shipping shape: device-space composition gives 12.0
where 6.0 is expected, at `dpr` 2. The distinguishing test asserts **both**
that the wrong formula agrees at `dpr == 1` (naming its own vacuity) and that
it diverges at `dpr == 2`.

### Task 8 — the shaders, and the Dart that stands in for them

Bundle regenerated, SHA-256
`a2cd5552de49b79cb3a7edb06375c4fcf0caf0c9889a4362c13d2aa3cd9ba419`. The
controller independently confirmed the bundle carries exactly **eight**
distinct attribute names, each appearing twice (16 occurrences) — `corner`,
`join_weight`, `kind_half`, `p0`, `p1`, `p2`, `color`, `dash`. Ruling C6's ES
100 floor holds; there is no ninth.

**Shader/expander parity was checked line by line, not asserted.** The reviewer
walked every new statement in `cad_stroke.vert` against its counterpart in
`test/support/instance_expander.dart` — sentinel default, `period`, the
collapse test, `along`, the collapse override, the varying assembly — and
found no drift. **Both compute `along` from the raw attributes**
(`corner.x * length(p1 - p0)` / `c.x * sqrt(rawDx² + rawDy²)`), never from the
`to_pixels`-transformed points. That is the plan's central claim and the one
place where the expander being wrong would be worse than the shader being
wrong, since the suite would then be green about the wrong thing.

**A brief omission the implementer had to fix to compile:** seven pre-existing
non-dash `expandInstances(...)` calls in `instance_expander_test.dart` needed
`dashScale: 1.0` once the parameter became required. Not in the step list.

Task 8: minor (deferred): the `'a point instance is never dashed'` expander
test is redundant against `'a solid instance signals solid with a negative
fracStart'`. The dash branch is gated entirely on `period == 0` and never on
`kind`, so no mutation kills the first that the second does not.
**This is the plan's redundancy — the test was mandated verbatim by the
brief** — so it is not the implementer's to drop mid-task. **Flag to the final
review.**

Task 8: fix round 1/5 dispatched — Important: the third
`measureResidentAgreement` call site passes `dashScale: 1.0` as a bare
literal where its two neighbours each explain the invariant. The value is 1.0
*because* both arms run at the collection camera, and an unexplained literal
reads like a placeholder.

Task 8: fix round 1/5 (1 addressed, 0 open — the third `dashScale: 1.0` site
now carries the same explanation as its neighbours, comment-only diff;
commits a6cd72c..8361cb6).

Task 8: complete (commits a30d0bc..8361cb6, review clean). Suite 523 pass.
Both mutation kills demonstrated: a device-space `along` and a deleted
collapse branch.

### Task 9 — the fragment stage gets an instrument

**Ruling P9: my dispatch's claim about the centroid test was false, and the
gap it hid is being closed rather than argued away.** I told the implementer
that the centroid test — a triangle carrying `t = 0, 1, 2`, asserting `1.0` at
its centroid — was "the only thing standing between a rotated barycentric
correspondence and a silently wrong instrument." **At the centroid every
barycentric weight is exactly 1/3, so the interpolated value is invariant
under every permutation of the correspondence, for any `t` values at all.**
The implementer proved this and substituted a positional-correspondence
mutation for the demonstration, which was the right call.

The test is not wrong for its own stated purpose (catching "took a single
vertex's value"); my dispatch's description of it was. But the gap is real:
nothing in the suite distinguished a correct correspondence from a rotated
one, and a rotation reads a plausible number at every pixel and the right one
only along the medians — a dash pattern subtly out of phase across every
triangle, the kind of defect that survives to a device run. **Closed by an
off-centroid sample with asymmetric weights, plus the rotation mutation fired
against it.** If it proves indistinguishable, it is recorded as a proved
equivalent mutation instead. **Cost if wrong:** one extra test on an
instrument every pixel gate in the package runs through.

**A workflow deviation, corrected:** the implementer left the work uncommitted
"for independent review". Every task in this plan commits its own changes —
the review runs on a diff between two SHAs.

Task 9: minor (deferred): the mutation named for `'without dash varyings,
nothing changes'` ("default `hasDash` to `ta != null` alone") is not a real
kill for it — `dash` is omitted in that fixture so `ta` is null either way and
`hasDash` stays false. The test does pin the property; only the named mutation
is wrong.

Task 9: fix round 1/5 dispatched — Important: the committed comment claiming
the `w0↔w1` transposition is unkillable by the off-centroid test is **false,
and was never fired**. The reviewer re-derived the barycentrics at the test's
own sample point `(3.5, 2.5)` — `w0=22.5, w1=10.5, w2=21, sum=54` — and showed
the correct value is `66/54 = 1.2222` (fract 0.2222, inside `[0, 0.5)`, inked)
against the transposed `42/54 = 0.7778` (fract 0.7778, outside, not inked), so
the mutation flips the assertion and reddens the test.

**The implementer's algebra was right and its conclusion did not follow.** The
identity `correct − tb = −(swap − tb)` is true — the two values are equidistant
from `tb` — but equidistance only defeats a window **symmetric around `tb`**,
and the shipped window `[0, 0.5)` is anchored *at* `tb`'s fract value rather
than centred on it.

**The part that matters for this repository: the claim was reasoned, not
run.** The report's "confirmed with a live mutation" refers to the *positional*
mutation; the transposition was derived to be unkillable and then written into
a committed comment as fact. This project's mutation log distinguishes killed,
declared survivor and proved equivalent — "argued, never fired" is the category
it exists to prevent, and it nearly landed in a document of record.

Task 9: fix round 1/5 (1 addressed, 0 open — the transposition was fired live,
reddens the test exactly as the reviewer's arithmetic predicted, `fract`
0.7778 outside `[0, 0.5)`; the comment now describes the run and explains why
the equidistance identity does not survive `fract`'s wraparound against a
window anchored at `tb` rather than centred on it; the original wrong
reasoning is kept and marked superseded; commits 8ad90fe..cc8bda7).

Task 9: complete (commits 8361cb6..cc8bda7, review clean). Suite 528 pass;
`triangle_rasterizer_test.dart` 17 tests.

### Task 10 — the gates

**Environmental: the machine slept mid-run and killed the implementer after 26
minutes and 73 tool uses, with nothing committed.** The same fault cost Plan B
four subagents. Salvaged from the tree: the `debugDisableDashTest` flag on
`TriangleRasterizer` and its threading through `measurePaintedAgreement`, both
clean and both kept. Not written: `dash_differential_test.dart`, the report.

**Ruling P10: long implementer runs commit in stages, and write their reports
incrementally.** Resumed the same agent — its context was intact — with the
task split into five self-standing commits (control-arm plumbing, the
declarative oracle and its differential, emission order, the pixel
differential and its control, the four-scale dash-count test), each keeping the
suite green, and the report appended as each lands. **Cost if wrong:** more
commits than the plan's step list implies, against a run that currently loses
everything to a lid closing. Plan B reached the same arrangement after the
same fault.

**The machine slept a second time, at the exact moment the implementer wrote
"All green. Committing stage 1."** The controller re-ran the gates on the
implementer's working tree — `flutter test` 528 pass / 1 pre-existing skip,
`flutter analyze` clean, `dart format` 0 changed, exit 0 — and landed stage 1
itself at `1b418f9`, then resumed the agent from stage 2. Committing the
verified work rather than asking a twice-killed run to redo it is the cheaper
half of Ruling P10.

**A sixth plan inaccuracy, caught in stage 1.**
`resident_pixel_differential_test.dart` carried the comment "Task 9 gives this
file a real dashed arm", which came from my own Task 8 brief. Task 9's report
says the opposite — it is Task 10's job. Corrected to point at
`dash_differential_test.dart` rather than leave a false claim in a file
nothing else would touch again.


Task 10: complete (commits cc8bda7..ac3cb57, five staged stages). Stages 2-5
were taken over inline by the controller after the machine slept three times
and killed the implementer with nothing committed on the third. Suite 539
pass / 1 pre-existing skip.

**Ruling P11: the pixel gate is stated exactly where it can be and measured
where it cannot.** The whole-corpus differential failed at 146/2938 (5%)
against a 1% criterion. Splitting by entity showed **all 146 pixels come from
the two curve entities and straight geometry differs by ZERO**. So the gate
is `differing == 0` on straight geometry -- a budget there would have accepted
a real defect -- and curves are reported with a self-declaring 25% tripwire.
**Cost if wrong:** criterion 1 is scored SPLIT rather than PASS, which is a
miss recorded as a miss.

**Ruling P12: the plan's premise is corrected in the record rather than
defended.** Plan C's "what is wrong today" claims a frozen buffer shows eight
dashes at 4x zoom where the reference draws thirty-two. Measurement says the
reference draws eight too -- dash patterns are anchored in world space. What
baking froze was the collapse decision. **Cost if wrong:** every document of
record on this branch leads with a correction to its own plan, which is the
cheap direction of that trade.

### Task 11 — mutation testing

Task 11: complete (commit 49d61e2). **Fourteen pre-committed mutations fired,
thirteen killed, one survivor (M-C11, pre-declared).** Two further mutations
fired against instruments rather than code. **M-C3 and M-C7 had only been
*derived* as killable in Task 6's review; they were fired here rather than
counted**, and the log draws that line explicitly because this branch had one
incident of a claim being reasoned and then committed as fact. **M-C5, a
pre-declared likely survivor, died** -- the plan's estimate of the error's
size was right and its estimate of what the arc phase test would tolerate was
not.

### Task 12 — the device run, the results note, STATUS.md

Task 12: complete (commits 64518a8..83810b3). Device run on macOS profile,
three interleaved repeats, raw log archived beside the results note.
**Instances 105,076, down from Plan B's 109,068, while the record grew 12 ->
16 floats; buffer 6.41 MB against 8 MB, PASS.** Gesture criteria all pass
with `discard` live. **Rebuild MISSES at 115.0 ms against 16.67**, the same
shape as Plan B's 79.6 ms with the same untestable cold-pipeline hypothesis.
**macOS Low Power Mode was ON and every timing is contaminated** -- stated
because Plan 3b's note is compromised for omitting it.

**A third stale GSPIKE claim was found by running the harness**: the runtime
note string still printed "Dash spans are baked at the collection camera".
The file's header comment had been corrected but not the string the
transcript actually carries.

### Final whole-branch review

Dispatched on the most capable model. **It found a live rendering defect the
entire branch had missed**: a dashed circle's closing chord carried the
previous chord's phase, because `_flatten`'s loop stops at `steps - 1` for a
closed sweep and `_endRun` then drew the closing chord with stale pending
values. Measured at a per-chord advance of 11.3302 for every chord except the
last, which advanced 0.0 -- a ~37%-of-a-cycle jump on every dashed circle.
**No test stood over it**: the running-phase test uses an *open* arc, where
`_endRun` returns early.

It also found **`style.linetypeScale` deletable from all five of its sites**
with the suite still green -- the exact shape of the `lineweightScale` defect
that survived every instrument in Plan B. The fixture already carried the
affordance (`shadedDashFixture({linetypeScale})`) and no caller passed it.

One fix wave, five staged commits `83810b3..f703239`, one scoped re-review:
**all six findings ADDRESSED, no new breakage.** Suite 540 pass, harness 72.
