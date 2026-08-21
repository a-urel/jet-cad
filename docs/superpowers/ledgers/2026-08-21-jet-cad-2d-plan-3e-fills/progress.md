# SDD ledger — plan: docs/superpowers/plans/2026-08-21-jet-cad-2d-plan-3e-fills.md

Spec (binding): docs/superpowers/specs/2026-08-21-jet-cad-2d-plan-3e-design.md — read, reachable.
Branch: `main`, with the human's explicit consent ("main'den devam"). No worktree.
Start commit: 3201cc5

## Pre-flight scan

### Shared files — one row per pair of tasks touching the same file

| file | tasks | produces vs consumes | finding |
|---|---|---|---|
| `entity_store.dart` | T1 | — | single owner |
| `triangulate.dart` | T2 | T4 consumes `triangulateSimplePolygon` | consistent |
| `fill_index.dart` | T3, T5 | T5 adds `dropTriangles`; T3's Produces block lists it | consistent |
| `command.dart` | T3 | `CommandTarget.fills`; `DraftDocument` supplies it in T3 | consistent |
| `draft_document.dart` | T3, T9 | T3 adds `fills`; T9 touches the `extents` call site | disjoint edits |
| `commands.dart` | T4, T5, T6 | T4 produces `triangulationFor` + both region commands; T5 and T6 consume | consistent, strictly sequential |
| `extents.dart` | T1, T9 | T1 writes an inert `fill` case; T9 replaces it | **row A below** |
| `spatial_index.dart` | T1, T9, T10 | T1 inert cases; T9 call sites; T10 final comments | **row B below** |
| `container_index.dart` | T9, T10 | T9 call site; T10 comment blocks only | consistent |
| `reference_query.dart` | T1, T10 | T1 inert cases; T10 replaces with reasoning | consistent |
| `draw_sink.dart` / `canvas_draw_sink.dart` | T11 | T12–T15 consume the two ops | consistent |
| `vertices_draw_sink.dart` | T12, T15 | T15 edits only if the seam rule fires | sequential, conditional |
| `draft_painter.dart` | T1, T13 | T1 inert; T13 replaces | consistent |
| `reference_walk.dart` | T1, T13 | T1 inert; T13 replaces | **row D below** |
| `region_command_test.dart` | T4, T5, T6 | each appends | consistent |
| rig files | T16 | consumes T13's counters | **row C below** |
| `test/support/spy_canvas.dart` | — | T11's tests need `lastPaintStyle`, `drawPathCount` | **row E below** |

### Self-consistency — one row per task

T1 ✓ · T2 ✓ · T3 ✓ · T4 ✓ · T5 ✓ · T6 ✓ (refuses >1 fill per boundary; nothing in this plan can create that state) · T7 ✓ · T8 ✓ · T9 ✓ · T10 ✓ · T11 **row E** · T12 ✓ · T13 **rows C, F** · T14 ✓ · T15 ✓ · T16 **row C** · T17 ✓

### Findings and rulings

**Row A — a fill's box is `Aabb2.empty()` between T1 and T9.** Checked every
test between them: T4, T5, T6, T7 and T8 build no `SpatialIndex` over a
document containing a fill, so nothing reads the empty box. No action.

**Row B — T1's `case EntityKind.fill: break;` inside `_considerLeaf` is
unreachable.** `_considerLeaf` returns on `pointCount == 0` before the switch.
Ruling: this is unreachable *by design* and is required for exhaustiveness —
it must not be removed. Carried verbatim into T1's and T10's reviewer
constraints so a reviewer does not flag it as dead code. Cost if wrong: a
reviewer round arguing a comment.

**Row C — `painter.fillCount` is consumed by T16 and produced by no task.**
T13 produces only `skippedFillCount`. Ruling: **T13 produces both
`fillCount` and `skippedFillCount`**, both reset per frame like
`dashSpanCount`, alongside the existing `skippedTextCount` precedent at
`draft_painter.dart:135`. Carried into T13's dispatch. Cost if wrong: one
counter nobody reads.

**Row D — T13 mandates that `reference_walk` NOT share a helper with the
painter.** This is deliberate duplication of a logic block, which the review
rubric treats as a defect. Ruling: the duplication **stands** — the oracle
exists to disagree with the painter, and a shared helper would have it share
the assumption it is testing. Precedent: Plan 3c Ruling 28, same argument for
the paragraph flip. Carried into T13's reviewer constraints. Cost if wrong:
a duplicated ~30-line walk.

**Row E — T11's tests name `SpyCanvas.lastPaintStyle` and `.drawPathCount`,
which do not exist.** Verified: `test/support/spy_canvas.dart` is a bare
`noSuchMethod` recorder. Ruling: extending `SpyCanvas` with those two
recordings is **in scope for T11**, and `test/support/spy_canvas.dart` is
added to its file list. Cost if wrong: nothing — it is test-only support.

**Row F — T13's circle branch reads `boundaryPayload.scalars[0]` unguarded.**
A malformed document with a scalar-less circle would throw on the frame path.
Ruling: guard it — an empty `scalars` counts a skip like any other
unresolvable fill, never throws. The frame path does not raise on bad data;
that is what `skippedFillCount` and `validate()` are for. Cost if wrong: one
extra branch.

## Task log

Task 1: dispatched (sonnet, BASE 3201cc5) — EntityKind.fill + the exhaustive switches.
  Controller decisions carried into the dispatch: row B (the unreachable
  `_considerLeaf` case stays, with its reason), and "find the switch sites by
  compiling, not by grepping — trust the compiler over the brief's list".
Task 1: implementer DONE — commit 0ee9797, 7 files, +72/-1.
  Reported: engine 722 pass, widgets 242 pass / 1 skip, both analyze+format clean,
  MUTANT T1a (insert rather than append) killed.
  Note — plan text corrected by the compiler: the plan says "four `switch` sites
  in `lib/` plus one in the oracle". Actual is SIX in `lib/` and TWO in the
  oracle. My count came from `grep -rln`, which counts FILES, not switches; the
  dispatch's "trust the compiler over the brief" instruction is what caught it.
  No downstream task depends on the number, but Tasks 9, 10 and 13 replace those
  cases and must use the compiler's list too.
  Note — provenance: the implementer reported the task's diff already present
  uncommitted at its start. Controller check: `git status --porcelain` was empty
  at 3201cc5 immediately before dispatch, and the reflog shows no intervening
  write. Recorded unexplained rather than accepted or dismissed; the implementer
  states it re-derived and re-verified every claim independently.
Task 1: review clean — spec ✅, quality approved, no findings.
  Reviewer independently reproduced both suites, the enum-append check (via
  `git show 3201cc5:` on the pre-task file) and MUTANT T1a, and confirmed by
  repo-wide grep that eight is the true switch-site count.
Task 1: complete (commits 3201cc5..0ee9797, review clean)
Task 2: dispatched (sonnet, BASE 0ee9797) — the ear-clipping triangulator.
Task 2: implementer DONE_WITH_CONCERNS — commit 4a78bc6.
  Reported: engine 729 pass, widgets 242 pass / 1 skip, both analyze+format clean.
  Mutations: T2a KILLED (only by the clockwise fixture, as predicted), T2b KILLED,
  T2d KILLED, T2c SURVIVED with an equivalence argument.

Ruling: the plan's Step-3 triangulator code is DEFECTIVE and the implementer's
  correction stands. — The brief's own bow-tie fixture fails against the brief's
  own code: in a 4-point bow tie the two crossing edges are never tested as a
  diagonal, so the "no ear found -> not simple" path never fires, an ear is found,
  and a self-intersecting loop returns two triangles. The spec requires it to
  return none ("Refused, and reported... yields no triangles and the fill is not
  drawn"). The implementer verified this in isolation BEFORE editing, then added
  an upfront proper-crossing check. Complexity is unchanged: O(n^2) was already
  the stated cost. The spec is the binding authority and the plan is its argument;
  here the argument was wrong. — Cost if wrong: an O(n^2) pass over boundaries at
  edit time, which the design already budgets for and which no frame path runs.

Ruling: T2c is accepted as an EQUIVALENT mutant, not a coverage gap. — Changing
  the in-loop `return Int32List(0)` to `break` cannot change any execution,
  because the post-loop `if (index.length != 3) return Int32List(0);`
  unconditionally re-catches every state `!clipped` can reach. The in-loop return
  is therefore defensive, not load-bearing. Recorded rather than counted as a kill.
  — Cost if wrong: one unreachable early return; the reviewer is asked to check
  the equivalence argument rather than take it.

Note: Task 17's results note must record the plan-text defect above. The plan
  document is not amended mid-flight; git history and this ledger carry it.
Task 2: review — spec ✅, quality approved with 1 Important + 1 Minor.
  Reviewer independently reconstructed the brief's Step-3 code and confirmed it
  returns two triangles for the bow tie, upholding the controller's ruling. It
  also re-ran T2a/T2b/T2d (all KILLED), checked the T2c equivalence argument
  algebraically and by re-running it (holds), and mutated the new crossing check
  away as its own sanity probe (KILLED by the bow tie — the fix is load-bearing).
  It further probed for FALSE refusals: concave star, collinear-injected concave,
  notch/slit — all triangulate correctly.

  Important (enters the fix loop): a duplicate INTERIOR point is wrongly refused.
  `loop([0,0, 10,0, 10,0, 10,10, 0,10])` returns empty instead of area 100.
  Inherited from the brief's `_isEar` (`>= 0` containment treats a coincident
  point as on the boundary of every candidate ear, so the clipper stalls), NOT
  from the departure. The brief's own contract says "at least three DISTINCT
  points", so duplicates were meant to be tolerated.

Task 2: minor (resolved by the controller, not deferred): the reviewer flagged
  the report citing a brief instruction to keep exact comparisons that does not
  exist in the brief. It exists in the CONTROLLER'S DISPATCH, which the reviewer
  cannot see. The mis-attribution is real; the mandate is real too.
  Sub-issue kept open for the final review: the implementer extended that
  instruction to `_segmentsCross`, a function the dispatch never mentioned.
  CLAUDE.md says geometric DECISIONS use `Tolerance` and crossing is a geometric
  decision, but exact sign predicates are the standard answer for orientation
  because a tolerant predicate can be self-inconsistent. Not raised as a finding;
  recorded so the final whole-branch review can settle it.
Task 2: fix round 1/5 dispatched — the duplicate-interior-point refusal.
  Two constraints put on the fix: the returned indices must stay indices into the
  ORIGINAL `coords` (a later task hands the sink the untouched array and indexes
  straight into it, so a dedupe-into-a-new-array fix is silently wrong and every
  area-only assertion still passes); and the store's CLOSING duplicate, which is
  how closedness is recorded, must not be collapsed into the same rule.
  Implementer returned DONE — commit f1d18d7, engine 731 pass, new mutant T2e
  (drop the dedupe) KILLED by both new fixtures. Scoped re-review dispatched over
  4a78bc6..f1d18d7.
Task 2: fix round 1/5 (1 addressed, 0 open — duplicate-interior-point refusal;
  commits 4a78bc6..f1d18d7). Re-reviewer verified BOTH constraints by reading the
  code, not the tests: `_dedupeConsecutive` filters the index list and never
  builds a coordinate array, and the closing duplicate is still dropped by
  `count - 1` before the dedupe sees it. T2e re-run independently, both new
  fixtures red. No new breakage. Report misattribution also corrected.
Task 2: complete (commits 0ee9797..f1d18d7, review clean)

Task 3: dispatched (sonnet, BASE f1d18d7) — FillIndex.
  Controller finding carried into the dispatch: the plan's file list for Task 3
  is INCOMPLETE. `CommandTarget` is implemented by two test fakes as well as by
  `DraftDocument` — `FakeTarget` in test/document/command_test.dart:7 and
  `TestTarget` in test/document/commands_test.dart:7 — and adding
  `FillIndex get fills` breaks both. Neither is in the plan's Modify list.
  Ruling: updating both fakes is in scope for Task 3. — Cost if wrong: nothing;
  they are test-only doubles and the alternative is a task that cannot compile.
Task 3: implementer STALLED (watchdog, no progress 600s) right before committing.
  Controller recovery check: HEAD still f1d18d7, work intact and uncommitted on
  disk — 5 modified + 2 new files, matching the task's scope including both
  CommandTarget fakes. No report file had been written.
  Resumed the same agent with the disk state pasted back to it and an explicit
  instruction to RE-RUN every mutation rather than write transcripts from memory:
  a transcript that cannot be pasted from a real run is a synthesized one, and
  this repository treats that as invalidating the task.
Task 3: STALLED A SECOND TIME on the same watchdog, again just before the
  mutation runs. Controller changed the approach rather than resuming a third
  time — the skill forbids forcing the same agent to retry without a change.
  Controller verification before re-dispatch: `dart test
  test/document/fill_index_test.dart` runs in ~2s and passes 6/6 INCLUDING the
  purge test, so the code is sound and the stall is in the agent's loop, not the
  work. Re-dispatched FRESH, scoped to verification + mutations + report +
  commit, with two changes aimed at the stall: every mutation runs against the
  NARROW test file (~2s) instead of a full suite, and the full suites run exactly
  once each at the end. Exact line anchors for T3a/T3b/T3c supplied so the agent
  spends no turns deriving them.
Task 3: STALLED A THIRD TIME. Root cause found, and it was never the agents.

  ROOT CAUSE: **Flutter auto-updated 3.47.0 -> 3.47.1 mid-session**, which
  triggered a full Dart SDK re-download
  (`curl --continue-at - ... dart-sdk-darwin-arm64.zip`, ~10 minutes). EVERY
  `flutter` invocation blocked on that download, so every agent that reached
  `flutter analyze` or `flutter test` sat with no stream output until the
  600s watchdog fired. Three stalls, one cause, and it was environmental.
  Diagnosed by `ps aux` rather than by re-reading agent transcripts: a hung
  `bash flutter analyze` (PID 98472) and the curl (PID 95300) were both visible,
  and the curl completed during a 20s observation window.

  Controller verification after the download finished:
    flutter --version -> 3.47.1, framework 6655482ec0, engine 5d53178869
    flutter analyze   -> No issues found (1.2s)
    flutter test      -> 242 pass, 1 skip
    flutter test --tags golden -> 23 pass

  **The upgrade broke nothing, including the goldens.** That matters more than
  it looks: STATUS.md's Ruling 22 pins `flutter_test`'s Ahem metrics exactly
  (ascent 75.0 / descent 25.0 / advance 200.0 at nominal) precisely so a Flutter
  upgrade that moves the test font fails loudly. The tripwire held.

  Note for Task 17: the results note must record that Plan 3e was measured on
  Flutter 3.47.1, not 3.47.0 as the plan header states, and that the change
  happened mid-plan between Tasks 2 and 3.
Task 3: STALLED A FOURTH TIME, and this one exposed a defect in the controller's
  own instructions: `trap ... EXIT` only holds WITHIN one shell invocation, so an
  agent that mutates in one Bash call and tests in the next has the file restored
  before the test runs — the mutation measures nothing. The agent diagnosed it
  itself. Task 2 survived this only because that agent happened to put mutate +
  test + restore in one call.

Ruling: the CONTROLLER completed Task 3's verification, mutations, report and
  commit. — Four implementer runs died without reaching verification, three on an
  environmental cause outside any agent's control. Continuing to re-dispatch was
  spending 10-minute watchdog cycles to no end. The independent task review still
  gates the task, so the thing the loop exists to protect — an outside pair of
  eyes on the diff — is intact; what was skipped is only WHO ran the commands,
  and the report says so in its first paragraph. — Cost if wrong: the task's
  verification was not produced by a party independent of the plan's author, so
  the reviewer must re-run rather than corroborate. It has been told to.

Task 3: TWO controller mutation attempts discarded before the real one, both
  recorded in task-3-mutations.md because both produced confident wrong answers:
  (1) the stalled agent had left the TEST file half-mutated, so every run failed
  to LOAD and all three mutants read KILLED with nothing measured; (2) the guard
  added to catch that matched `dart test`'s own `loading test/...` PROGRESS line,
  so all three then read INVALID. A verdict is now KILLED only when the suite ran
  and a NAMED test failed, and the transcript prints that test's name.

Task 3: implementer work complete — commit a21188d.
  Engine 737 pass, analyze+format clean. Flutter verified at 3.47.1: 242 pass,
  23 goldens, analyze clean.
  Mutations: T3a KILLED, T3b KILLED, T3c KILLED, and the KEYING mutant KILLED by
  `the index survives a purge because handles do` and by nothing else — five
  tests still pass under geomIndex keying, so the purge test genuinely exercises
  slot renumbering and the handle decision is evidenced, not asserted.

Task 3: review ATTEMPTED TWICE AND FAILED BOTH TIMES — once on the 600s stream
  watchdog, once on an API error ("the response stopped arriving"). No hung
  processes on the machine either time; the second failure was not environmental
  in any way the controller can see or fix.

Task 3: **committed but NOT independently reviewed.** commits f1d18d7..a21188d.
  This is a gap, and it is stated rather than papered over. Every other task in
  this plan has an independent review; this one has none, and its verification
  was run by the controller — the same party that wrote the plan — because four
  implementer runs died before reaching verification. So Task 3 currently rests
  on a single party's word, which is exactly the arrangement this workflow
  exists to prevent.
  The controller did NOT self-review it. A review by the author of both the plan
  and the verification would be theatre, and recording a verdict nobody
  independent reached would be worse than recording the gap.
  **Whoever picks this up: Task 3's review is owed.** The package is ready at
  `review-f1d18d7..a21188d.diff` and the brief and report are beside it.

State at stop: HEAD a21188d, working tree clean, engine 737 pass + analyze clean,
  Flutter 3.47.1 verified earlier at 242 pass / 23 goldens / analyze clean.
  Tasks 1 and 2 complete with clean independent reviews. Tasks 4-17 not started.

Task 3: review CLEAN on the third attempt — spec ✅, quality approved, no
  findings. The reviewer re-ran T3a/T3b/T3c and reproduced the KEYING mutant with
  its OWN construction rather than the report's, and got the same single named
  failure: `the index survives a purge because handles do`, Expected [0,1,2] /
  Actual null. It also confirmed by project-wide grep that `CommandTarget` has
  exactly three implementers and both fakes hold a real `FillIndex`, and that no
  production code outside fill_index.dart references `.fills.` yet.
Task 3: complete (commits f1d18d7..a21188d, review clean)

**THE STALLS ARE SOLVED, and the reviewer found it, not the controller.**
  `dart test` was sitting for minutes at ~0% CPU on an established TCP connection
  to `*.bc.googleusercontent.com` — **Dart's analytics phone-home**, not the
  Flutter SDK re-download. That download explained the first three stalls; this
  explains the rest, including the ones with no hung process visible.
  Fix: **`CI=true`**. Controller verified: `CI=true dart test` runs 737 tests in
  3.9s wall clock. `dart --disable-analytics` has also been set, so the phone-home
  is off globally now.
  **Every remaining dispatch must prefix test commands with `CI=true`.** Six agent
  failures on one task came out of this; the cost of not carrying it forward is
  the same six repeated on each of Tasks 4-17.

Task 4: dispatched (sonnet, BASE a21188d) — AddRegionCommand + RemoveRegionCommand
  + triangulationFor.
Task 4: implementer DONE — commit ce09943. Engine 743 pass (737 + 6 new),
  widgets 242 pass, both analyze+format clean. All four mutants KILLED, each with
  a named failing test: T4a (boundary allocated first), T4b (ordering re-check
  dropped), T4c (putTriangles skipped), T4d (nearly-closed loop accepted — killed
  by the open-boundary fixture, which is the one that had to do it). No concerns;
  the brief's code matched Tasks 1-3's real APIs with no adaptation.
  Run took 216s with `CI=true` against multiple 600s stalls before it. The fix
  holds.
Task 4: review CLEAN — spec ✅, quality approved, no findings.
  Reviewer re-ran the suite and T4d itself (mutation + test + restore in one
  shell call), got the same named failure, and confirmed the file byte-identical
  after restore. It also did two things beyond the ask: compared the closedness
  test byte-for-byte against `SpatialIndex`'s own at spatial_index.dart:916-917
  rather than trusting the comment's claim, and traced the all-or-nothing
  contract STRUCTURALLY — showing from the store code that `GeometryStore.add`
  and `EntityStore.add` cannot throw once the pre-checks pass, so the contract is
  true by construction rather than merely untested-against.
  It also confirmed the null/empty distinction the controller asked about is
  honoured at every call site: null -> throw, empty -> link without a triangle
  entry, which is what lets the painter skip and count.
Task 4: complete (commits a21188d..ce09943, review clean)
Task 5: implementer DONE — commit 3f6e7ba. Engine 748 pass, widgets 242 pass /
  1 skip, both analyze+format clean. T5a/T5b/T5c KILLED; T5d SURVIVED with an
  equivalence argument, even after landing the two-edit/two-undo test the
  controller prescribed.

Ruling: the plan's Task 5 Step-1 test is DEFECTIVE and the implementer's
  adaptation stands. — The brief writes `final result = doc.commands.execute(...)`
  and asserts on `result.touched`, but `CommandDispatcher.execute` is `void`
  (undo.dart:102). Controller verified. The implementer captured the `touched`
  set through the existing `onAfterMutate` callback (undo.dart:80) instead, which
  is the codebase's own seam for observing a mutation. — Cost if wrong: the
  touched-set assertion observes the change event rather than a return value;
  same property, one indirection further out.

Ruling: T5d is accepted as EQUIVALENT **given today's `GeometryStore.replace`**,
  and `read` stays in the inverse anyway. — Controller verified
  geometry_store.dart:135-141: `replace` assigns a **freshly constructed**
  `GeometryPayload` with fresh `Float64List`s rather than mutating the existing
  one, so a payload obtained by `peek` and held by an inverse is never written
  through; it is merely displaced in the map. `remove` does the same. So the
  aliasing hazard has no reachable path today and no test can kill T5d.
  **But `peek`'s own doc comment (geometry_store.dart:120-129) asserts that
  hazard as live** — "an inverse payload sharing the store's buffer would let a
  later edit rewrite undo history". That comment is describing a danger the
  store's current implementation happens to prevent. Keeping `read` is still
  right, because `replace`'s per-edit `Float64List.fromList` is an obvious place
  for a future optimisation to mutate in place, and that change would make the
  hazard real with nothing failing. — Cost if wrong: one defensive copy per edit,
  off the frame path.
Task 5: review — spec ✅, quality approved, 1 Minor.
  Reviewer re-ran T5a (KILLED, named test `editing a boundary re-triangulates and
  touches its fills`, Expected contains <18> / Actual Set:[19]) and T5d (SURVIVED)
  itself, each mutation+test+restore in one shell call. It did the BROAD trace the
  controller asked for rather than checking `replace` alone: every write to
  `_payloads` — add:101, replace:137, remove:148 assign freshly constructed
  payloads, purge:169 only relocates references — plus a repo-wide grep for
  `.coords[`/`.scalars[` writes outside the store. The equivalence claim holds.
  It also confirmed the `onAfterMutate` adaptation observes the SAME value:
  undo.dart:114 builds the change from the same `CommandResult` that `apply`
  returned, synchronously inside `execute`, so `change.touched` IS
  `result.touched` and not a different signal.
  Bonus verification: `entities.replace` is never called, so handle/slot/geomIndex
  preservation is structural rather than merely asserted.

Task 5: minor (deferred): `GeometryStore.peek`'s doc comment
  (geometry_store.dart:120-129) states the aliasing hazard as live — "an inverse
  payload sharing the store's buffer would let a later edit rewrite undo history".
  Every write path replaces rather than mutates, so that hazard is unreachable
  today; the comment describes a danger the implementation forecloses.
  Documentation precision, not a defect. Point the final whole-branch review at
  this line.
Task 5: complete (commits ce09943..3f6e7ba, review clean, 1 minor deferred)
Task 6: dispatched (sonnet, BASE 3f6e7ba) — RemoveEntityCommand cascades to fills.
Task 6: implementer DONE — commit 66f40ed. Engine 750 pass (748 + 2 new),
  widgets 242 pass / 1 skip, both analyze+format clean. All three KILLED:
  T6a (cascade branch disabled) caught by the cascade test; T6b (cascade kept,
  `dropBoundary` dropped) caught by `entryCount` exactly as the dispatch
  predicted — the entities still vanish, so a liveness-only test would have
  stayed green; T6c (fill removal forgets `unlink`) caught by `fillsOf` still
  returning [18]. No concerns.
Task 6: review CLEAN — spec ✅, quality approved, no findings.
  Reviewer re-ran the full 750-test suite and T6b itself (KILLED at the
  `entryCount` assertion, Expected <0> / Actual <1>), and verified the restore
  rather than trusting it. It settled the removal-ORDER question the dispatch
  raised: the cascade removes fill-then-boundary while `RemoveRegionCommand`
  removes boundary-then-fill, and the asymmetry is NOT a defect —
  `invalidateDerived()` and the changes stream fire once, after `apply()` returns
  (undo.dart:105-113), so no observer can see an intermediate state inside one
  `apply` whatever the statement order. The spec's reasoning is about composing
  two commands, not statements. It also traced the inverse chain: undo runs
  `AddRegionCommand`, whose own inverse is `RemoveRegionCommand`, so redo takes
  that path rather than the cascade.
Task 6: complete (commits 3f6e7ba..66f40ed, review clean)

Task 7: dispatched (sonnet, BASE 66f40ed) — codec schema 5 + the load-time rebuild.
  Controller finding carried into the dispatch: the plan's Task 7 test code names
  `JsonCodec.save` and `JsonCodec.load`, and NEITHER EXISTS. The real API is
  `JsonCodec.encode(doc)` / `JsonCodec.decode(json, {diagnostics})`, plus
  `encodeToString` / `decodeString` (json_codec.dart:35, 84, 91, 143).
  Ruling: the implementer uses the real names. — Cost if wrong: none; the plan's
  names were never compilable.
  Also carried: `test/codec/schema_v3_fixture_test.dart` pins a hand-written
  v3 document and must keep passing across the bump, and `json_codec.dart:103`
  is the check that makes bumping meaningful — it rejects `version >
  kSchemaVersion`, which is what stops a v4 build choking inside
  `EntityKind.values.byName` on `kind: "fill"`.
Task 7: implementer DONE — commit 8c2f29e. Engine 753 pass, widgets 242 pass /
  1 skip, both analyze+format clean. T7a (drop `_rebuildFills`) KILLED by
  `load leaves the fill index populated, not empty`; T7b (kSchemaVersion left at
  4) KILLED by `the schema version is 5, and a v6 document is refused`.
  `schema_v3_fixture_test.dart` still passes unmodified.

  Controller dispatch error, corrected by the implementer: the class is
  `DraftDocumentCodec` (json_codec.dart:22), not `JsonCodec` as the dispatch
  said. The plan had `save`/`load`; the dispatch fixed the method names and got
  the class name wrong. Both are now right in the code.

Ruling: the two re-baselined FNV-1a fingerprints in
  `test/testing/generate_document_test.dart` are ACCEPTED, and the acceptance is
  measured rather than argued. — The implementer re-baselined them because
  `kSchemaVersion` is the first thing every serialisation writes. Re-baselining a
  golden is the classic way to bury a real regression, so the controller probed
  it: with `kSchemaVersion` forced back to 4 and nothing else changed, a throwaway
  test asserting the OLD constants (-4223683079839955300 and
  -1538364231202837705) **passes**. The serialisation therefore changed in exactly
  one place — the version number — and in no other. The file also carries the same
  precedent from Plan 3c Task 1, and the fingerprint's own doc comment says it is
  "not a hash for security -- a change detector" for generator determinism, not a
  frozen format. — Cost if wrong: a format change would ride in unnoticed behind
  a version bump; the probe above is what rules that out, and the reviewer is
  asked to reproduce it.
Task 7: review CLEAN — spec ✅, quality approved, no findings.
  Reviewer REPRODUCED the fingerprint probe itself (kSchemaVersion forced to 4,
  old constants asserted, both passed) rather than taking the controller's, and
  confirmed the round-trip test is blind: under the T7a mutant
  `a document with a region round-trips byte-identically` still PASSED while
  `load leaves the fill index populated, not empty` failed with Expected [18] /
  Actual []. It also verified by reading that a circle's empty triangulation is
  excluded from the cache and that a fill with a missing or unfillable boundary
  is linked without triangles rather than dropped.
Task 7: complete (commits 66f40ed..8c2f29e, review clean)

Task 8: dispatched (sonnet, BASE 8c2f29e) — validate() learns five fill codes.
  Controller findings carried into the dispatch:
  - The plan writes `GroupNode(handle: group, parent: doc.rootHandle)`. That does
    not compile: `GroupNode` also requires `transform` and `children`
    (node.dart:78-85). Ruling: the implementer supplies `Transform2.identity` and
    `const []`. Cost if wrong: none; the plan's call was never compilable.
  - The plan's test code calls `JsonCodec.save`. The class is
    `DraftDocumentCodec` and the method is `encodeToString` / `encode`.
  - `test/document/validate_test.dart` already exists; the new tests append to it.
Task 8: implementer DONE — commit b861230. Engine 758 pass (validate_test 17/17,
  5 new), widgets 242 pass / 1 skip, both analyze+format clean.
  All FIVE deletions killed exactly ONE named test each and no others, which is
  the isolation property this task lives on:
    fillBoundaryMissing      -> `a fill naming nothing is reported`
    fillBoundaryNotFillable  -> `a fill on a text entity is reported as not fillable`
    fillBoundaryNotClosed    -> `a fill on an open polyline is reported as not closed`
    fillBoundaryForeignOwner -> `a fill in a different owner than its boundary is reported`
    fillDrawOrderInverted    -> `an inverted pair is reported and nothing is changed`
  Two judgment calls the implementer flagged: numbered the new block 7 (the brief
  said 6, but 1-6 are taken) and gated `fillBoundaryNotClosed` to polyline
  boundaries, matching the brief's own snippet. Both look right; the reviewer is
  asked to confirm the second, since a circle must never be reported as "not
  closed".
Task 8: review — spec ✅, quality approved with 1 Important.
  Reviewer confirmed the circle gate is right (`fillBoundaryNotClosed` is gated
  on `kind == EntityKind.polyline` at validate.dart:253, so a circle can never be
  reported unclosed while still reaching the foreign-owner and draw-order checks),
  and verified STRUCTURALLY that the no-mutation test can actually see a mutation:
  `encodeToString` writes each `EntityRecord.handle` explicitly inside an
  ascending-slot-order list, so a renumbering OR a reordering changes the string.
  It re-ran two of the five deletions itself and confirmed each killed only its
  own test.

  Important (enters the fix loop): the fixtures are NOT single-fault.
  `rawFill` allocates the fill's handle AFTER the boundary's, so
  `fill.value > boundary.value` in the not-fillable, not-closed and foreign-owner
  fixtures, and `fillDrawOrderInverted` fires alongside each one. The kill matrix
  stayed clean only because every assertion uses `contains(...)` rather than an
  exact match. The "one fixture per code" property the task is built on is
  violated in substance; the isolation is incidental, not real.
Task 8: fix round 1/5 dispatched.
Task 8: fix round 1/5 — the fix agent applied the fixture change and STALLED on
  the watchdog before running the matrix (eighth stall on this plan). Work intact
  on disk; controller ran the matrix and committed as 023e724.
  Fix: the three affected fixtures now allocate the fill's handle BEFORE the
  boundary's — the order AddRegionCommand.allocate uses — and all five assertions
  moved from `contains(...)` to exact list equality. validate.dart untouched.
  Matrix re-run WITH the omitted half: each deletion fails its own test AND
  exactly 1 fill test in total, all five. validate.dart byte-identical after
  every restore.

  Controller harness error, recorded: the first matrix attempt used a shell array
  indexed from 0 in ZSH, where arrays are 1-based. The first iteration deleted a
  block chosen by an empty name and every later verdict shifted by one — five
  plausible results, all wrong. **Third time on this plan that the measuring
  harness, not the code under test, produced a confident wrong answer** (after
  the half-mutated test file reading as four kills, and the guard matching
  `dart test`'s own progress line). Scoped re-review dispatched over
  b861230..023e724.
Task 8: fix round 1/5 (1 addressed, 0 open — single-fault fixtures;
  commits b861230..023e724). Re-reviewer ran two deletions itself, each failing
  exactly one named test with no other fill test breaking, and checked the part
  that mattered most: that the fixtures were NOT weakened to make the fix easy —
  the foreign-owner boundary is still owned by `group` with the fill at the root,
  the not-closed polyline still has first != last, and the not-fillable boundary
  is still a text entity. `validate.dart` untouched. No new breakage.
Task 8: complete (commits 8c2f29e..023e724, review clean)

=== ENGINE PHASE COMPLETE — Tasks 1-8 ===
  Model, commands, codec and validation all landed with independent reviews.
  Engine 758 tests, widgets 242 + 1 skip, analyze and format clean on both.
  Commits 3201cc5..023e724.

Task 9: dispatched (sonnet, BASE 023e724) — entityBounds and every call site.
Task 9: implementer DONE_WITH_CONCERNS — commit c7434ab. Engine 762 pass,
  widgets 242 pass, both analyze+format clean, both allocation gates green.
  All 20 call sites accounted for: 5 resolved (draft_document `read`,
  container_index `peek`, spatial_index `peek`, reference_walk `peek`,
  reference_query:210 `peek`), 15 argued unreachable-by-a-fill by construction.
  T9a (fill always empty) KILLED by 3 named tests. T9b at the spatial_index
  reconcile site KILLED with exactly the through-index test red and 23 others
  green — the property the task exists for.

  THREE SURVIVORS, self-reported rather than smoothed over:
  (a) T9b at `container_index` build and at `draft_document.extents` — no fixture
      reads an UNEDITED fill's box, so the resolution can be deleted at either
      site with nothing failing. This is exactly the silent-call-site failure the
      task was built to prevent, and it is real. -> fix round 1.
  (b) T9b at the `reference_query` oracle — survives because no fill exists in
      the differential corpus yet. That corpus gains one in Task 10; deferred
      there rather than fixed here.
  (c) T9c (peek -> read in the reconcile hot path) leaves BOTH correctness and
      the allocation gate green, because `query_allocation_test` never mutates
      inside its measured window, so `_reconcileEntity` is not exercised by it.
      A real gap in what that gate covers, not in this task's code. Recorded for
      Task 16, which owns the allocation gate's corpus.

Ruling: the brief's `index.boxOfLeaf(slot) ?? index.dirty.boxOf(slot)` snippet
  names the wrong receiver and the implementer's correction stands. — `boxOfLeaf`
  is a `ContainerIndex` member (container_index.dart:758); `SpatialIndex` reaches
  it through a container, which is why its own code reads
  `index.boxOfLeaf(...)` where `index` is already a `ContainerIndex`. The
  implementer used `index.rootIndex.boxOfLeaf(...)`. Fifth plan defect of the
  same kind: an API written from memory instead of looked up.
  — Cost if wrong: none; the snippet never compiled.
Task 9: fix round 1/5 dispatched — cover the two uncovered production call sites.
Task 9: fix round 1/5 — commit bd78f9b, engine 764 pass, widgets 242 pass, both
  analyze+format clean, allocation gate green. Both previously-surviving sites
  now KILLED: `container_index` build by a new "fresh index resolves a fill
  without any edit" test (Infinity vs 0.0, 11 others green), and
  `draft_document.extents` by "doc.extents finds a fill's boundary by handle"
  (-1.0 vs 10.0, 12 others green).

Ruling: the CONTROLLER's own fix guidance was WRONG and the implementer's
  correction stands. — I told it to "give the document something else too,
  positioned so that a fill contributing an empty box changes the result". The
  implementer verified empirically that no such fixture can work: a plain
  `region(doc)` pair provably cannot catch either mutation, because
  `AddRegionCommand` forces the same owner, the fill's RESOLVED box is
  bit-identical to the boundary's own, and `Aabb2.union` no-ops on empty — so
  the boundary's own leaf always supplies the identical contribution no matter
  how many other entities are present. The answer is not a bigger fixture but a
  DECOUPLED one: an unedited fresh-index read, and an unplaced-definition
  boundary for the extents test, so the fill's contribution is the only thing
  that can produce the asserted value. — Cost if wrong: none; the alternative
  fixture was measured not to work before either was written.
Task 9: review — spec ✅, quality approved, 1 Minor.
  Reviewer checked the 20-site table AGAINST THE TREE rather than reading it,
  re-grepped the count, and spot-checked 4 of the 15 "unreachable" claims with
  the line that makes each unreachable. It VERIFIED the impossibility claim —
  `AddRegionCommand.allocate` always passes one `owner` to both halves, the fill
  case recurses to a bit-identical box, and `Aabb2.union` (aabb2.dart:61) no-ops
  on empty, so nothing built through the command layer can observe the
  difference. It re-ran two mutations, each killing exactly its own named test.
  On the realism question it split the two fixtures: the `container_index` one
  uses a realistic `region(doc)` and is fine; the `doc.extents` one uses an
  unplaced definition with a mismatched owner, a document `AddRegionCommand`
  cannot produce and `validate.dart:263` would flag — but it pins the right thing
  anyway, because `_boundsOfContainer`'s handle resolution never consults owner
  matching; that is `validate()`-level policy, orthogonal to the mechanism.
  Both deferrals confirmed with evidence: `query_allocation_test.dart` contains
  zero `SetEntityGeometryCommand` calls, so `_reconcileEntity` really is outside
  its measured window (Task 16), and `corpus.dart` contains zero fill fixtures,
  so the oracle deferral lands in Task 10.

Task 9: minor (deferred): `draft_document.dart:266-267`'s comment justifies
  `read` over `peek` by saying the box is "unioned into a result the memo keeps",
  when what is memoized is the derived `Aabb2`, not the payload. The real reason
  — matching the pre-existing `.read()` at that site — is stated correctly in the
  report but imprecisely in the comment. Point the final review at this line.
Task 9: complete (commits 023e724..bd78f9b, review clean, 1 minor deferred)

Task 10: dispatched (sonnet, BASE bd78f9b) — the index stays silent about fills.
Task 10: implementer DONE_WITH_CONCERNS — commit a02c5a4. Engine 771 pass,
  widgets 242 pass / 1 skip, both analyze+format clean.
  No behavioural code changed in the index: comments only in spatial_index and
  container_index, the reasoning enriched in reference_query's two fill cases, a
  `_regionFill()` fixture added to the differential corpus, and two pick/snap
  tests pinning the behaviour. T10a (oracle produces a fill hit the index does
  not) KILLED by `regionFill pick` — which also closes Task 9's deferred oracle
  survivor, since that corpus now contains a fill.

  T10b is the interesting one and the implementer did not smooth it over. The
  brief's own corner-query test does NOT kill a `snapCentreOfLeaf`-only mutation,
  for two independent reasons it found and measured: `_considerSnapCentre`
  carries a SECOND kind guard that masks a single-function mutation, and even
  past that guard the boundary's real endpoint candidate at the corner outranks a
  spurious centre candidate by kind priority. It added an interior-point query —
  where no real feature is nearby — and had to mutate BOTH guards together to get
  a kill. Recorded as defence in depth rather than as a coverage gap.

  Two concerns raised for the reviewer: (1) that redundant guard makes a
  `snapCentreOfLeaf`-only mutation behaviourally equivalent, flagged not
  remediated; (2) `_regionFill()` carries a second room through a rotated and
  scaled instance, beyond the brief's minimum, deliberately — an
  identity-transform-only fixture is this repository's named dominant failure
  mode, so the controller reads that as the right call rather than scope creep.

  Controller note for the reviewer: the report says the suite "was 770" before
  this task. It was 764 at bd78f9b. The corpus is parameterised over the
  differential, so a new corpus document adds cases — plausible, but the
  accounting should be checked rather than assumed.
Task 10: review CLEAN — spec ✅, quality approved, no findings.
  Reviewer verified BOTH withdrawal facts by code trace, including the instance
  case the controller asked about: fill and boundary share one owner (enforced at
  commands.dart:491-493), so `effectiveRoot` ties by construction and the handle
  comparison decides — the boundary wins through an instance exactly as at the
  root. It reproduced T10b by hand: the single-guard mutation really survives
  (24 snap tests green), the double mutation kills exactly
  `a fill manufactures no snap candidate of its own, even away from every real
  vertex` while the corner-of-room test stays green.
  On the redundant guard it answered something the controller's question did not
  contain: `_considerSnapCentre`'s kind check PREDATES `EntityKind.fill` and
  defends a different invariant — a tree slot whose entity kind changed since the
  last rebuild. It blocks fills incidentally. Neither guard should be removed;
  they cover different failure modes.
  Count verified properly: the suite was run at BOTH bd78f9b and a02c5a4 with the
  JSON reporter and diffed per-test-NAME, giving exactly +7 with no pre-existing
  test's count moving. The report's "770 before" is confirmed wrong; the delta is
  honest.
Task 10: complete (commits bd78f9b..a02c5a4, review clean)

=== RENDER PHASE BEGINS — Tasks 11-13 ===

Ruling: pre-flight row E is WITHDRAWN. SpyCanvas needs no change. — I ruled at
  pre-flight that extending `SpyCanvas` with `lastPaintStyle`/`drawPathCount` was
  in scope for Task 11, because the plan's tests named those members and the file
  looked like a bare `noSuchMethod` recorder. Reading it properly: it already
  snapshots `paintingStyle` per call and exposes `named(String)`, so the tests
  express the same assertions as `spy.named('drawPath')` and `.paintingStyle`
  with no new API. Its doc comment also states the exact hazard Task 11's paint-
  restoration test is about: the sink reuses one `Paint`, so the style is
  captured at call time. — Cost if wrong: none; withdrawing an unnecessary edit.
Task 11: dispatched (sonnet, BASE a02c5a4) — DrawSink.fillPolygon and fillCircle.
Task 11: implementer DONE_WITH_CONCERNS — commit a9891a9. Widgets 253 pass /
  1 skip (was 242), engine 771 pass untouched, both analyze+format clean.
  T11a (paint left on fill) KILLED by `leaves its paint on stroke afterwards`;
  T11b (triangles dropped from `==`) KILLED by `different triangulation ... is a
  different op`; T11c (unclosed path) KILLED by a test the implementer added
  itself, which the brief did not ask for.

Ruling: the brief's `_popTransform()` calls are a DEFECT and the implementer's
  removal stands. — Controller verified: there is no `_popTransform`.
  `_pushTransform` is idempotent (`if (_transformPushed) return;`,
  canvas_draw_sink.dart:99-106) and `endResidual` restores once
  (:109-116). The convention is push-once-per-residual, not push/pop per op.
  Sixth plan defect of the same kind — an API written from memory. — Cost if
  wrong: none; the snippet never compiled.

Note carried to TASK 12, and it must be loud there: `VerticesDrawSink.fillPolygon`
  and `.fillCircle` currently call `_flushBeforeUnbatchable()` and forward to the
  `CanvasDrawSink` fallback (vertices_draw_sink.dart:719-729), with a
  `TODO(Task 12)`. That was the right minimal move to keep the tree compiling,
  but it is a state that FAILS SILENTLY if Task 12 forgets it: the drawing stays
  correct and every test passes; the only casualty is batching — one
  `drawVertices` flush per fill, which is the entire performance argument this
  plan rests on. Nothing before Task 16's measurement would notice.
  Also discovered: `DrawSink` has three implementers/switches the plan's file
  list never mentioned — `VerticesDrawSink`, `TextKeySink`
  (test/rig/rig_support.dart) and the switch in test/support/vertices_differential.dart.
Task 11: review CLEAN — spec ✅, quality approved, no findings.
  Reviewer confirmed T11a's test asserts on the POLYLINE DRAWN AFTER the fill,
  not on the fill's own call or a field read — the only shape that catches a
  missing paint restore. Re-ran T11a and T11b itself. Checked FillCircleOp's
  ==/hashCode are field-identical to CircleOp's, so no field skew. Found five
  DrawSink implementers where the controller asked it to look for a fourth, and a
  sixth switch site at large_coordinate_test.dart:58 whose pre-existing wildcard
  already excluded TextOp, so fills fall in by the same convention.
  On the controller's judgement question — is the TODO enough of a tripwire —
  it answered with a precedent rather than an opinion: the
  `_flushBeforeUnbatchable()` + forward-to-fallback pattern is byte-for-byte how
  `text` is already handled in this sink, an accepted shape for deferred work
  rather than an invented shortcut; and a hard tripwire would mean building Task
  12's assertion machinery inside Task 11. It named the residual risk honestly:
  real but procedural, not a Task 11 code defect.
Task 11: complete (commits a02c5a4..a9891a9, review clean)

Task 12: dispatched (sonnet, BASE a9891a9) — VerticesDrawSink fills.
  THE TRIPWIRE IS THIS TASK'S TO REMOVE. `fillPolygon`/`fillCircle` at
  vertices_draw_sink.dart:719-729 currently flush and forward to the fallback.
  Leaving that in place keeps every test green and every drawing correct while
  destroying batching — one drawVertices flush per fill. Task 12 replaces it and
  proves the replacement with `frameTriangleCount`.
Task 12: review CLEAN — spec ✅, quality approved, no findings.
  Reviewer did all three checks the controller asked for, and all three held:
  (1) it RE-INTRODUCED the fallback forwarding and watched
  `a fill batches with strokes into one flush, not one call each` go red
  (Expected <1> Actual <2>) — the batching proof has teeth, not decoration;
  (2) it confirmed BOTH halves of T12a — the hairline test fails with the exact
  fade (0xFF3366CC -> 0xCC3366CC) while the non-hairline test stays green, so the
  kill is hairline-specific rather than incidental; (3) it read both `_flattenSteps`
  call sites and confirmed the extraction is a pure mechanical lift with the same
  theta, ceil and clamp — no flattened circle in the drawing moved.
  It also verified `_emitTriangle` writes straight into pre-reserved arrays with
  no intermediate list, ran paint_allocation_test directly, and confirmed the
  empty-triangle guard with its own named test.
Task 12: complete (commits a9891a9..8b587cd, review clean)

Task 13: dispatched (sonnet, BASE 8b587cd) — the painter draws fills.
  THREE PRE-FLIGHT RULINGS LAND HERE, all carried into the dispatch:
  - row C: the painter produces BOTH `fillCount` and `skippedFillCount`, both
    reset per frame. Task 16's rig consumes `fillCount`, which no task produced.
  - row D: `reference_walk` must NOT share a helper with the painter. The
    duplication is deliberate — the oracle exists to disagree, and a shared
    helper would have it share the assumption it is testing. Plan 3c Ruling 28 is
    the precedent. A reviewer will otherwise flag it as duplication.
  - row F: the circle branch must guard `scalars.isEmpty` and count a skip rather
    than throw. The frame path does not raise on bad data; that is what
    `skippedFillCount` and `validate()` are for.
Task 13: implementer DONE_WITH_CONCERNS — commit 6c29d65. Widgets 265 pass
  (was 260), engine 771 pass, both analyze+format clean, paint_allocation gate
  green. Five mutants, all KILLED with named tests: T13a (fill deferred to end of
  frame) by `a region draws the fill before its boundary`; T13b (empty
  triangulation handed to a sink) and T13c (skip never counted) by
  `an unfillable boundary is skipped and counted, not handed to a sink`; T13d
  (counter never reset) by `skippedFillCount is per frame, not a running total`;
  T13e (circle triangulated instead of fanned) by `a circle boundary draws a
  fillCircle, never a triangulated polygon`.

  All THREE pre-flight rulings verified landed by the controller:
    row C — `fillCount` (draft_painter.dart:134) and `skippedFillCount` (:144),
            both reset at :258-259 beside the existing per-frame counters.
    row F — the `scalars.isEmpty` guard is at :622, so a scalar-less circle
            counts a skip instead of throwing on the frame path.
    row D — `reference_walk.dart` carries its own 40 lines with its own
            fillPolygon/fillCircle calls; no shared helper. T13f was deliberately
            not applied, since the duplication is the ruling.

Ruling: the brief's `expectPainterSupersetOfReference(doc)` has the WRONG
  signature and the implementer's correction stands. — The real helper takes
  three arguments; the implementer used the existing
  `paintToRecording(doc), referenceToRecording(doc), kViewport` call shape
  already used elsewhere in that suite. Seventh plan defect of the same kind, an
  API written from memory. — Cost if wrong: none; the snippet never compiled.
  Also: `paintOnce`/`paintAgain`/`region` do not exist in the Flutter test tree,
  so local equivalents were defined in `fill_render_test.dart` rather than
  editing shared `fixtures.dart`. That matches the plan's own "Shared test
  vocabulary" instruction to copy them per file.
Task 13: review CLEAN — spec ✅, quality approved, no findings.
  Reviewer confirmed by READING the painter, not by trusting a test, that no sink
  is ever handed empty triangles: both branches skip, count and return before any
  `sink.fill*` call (draft_painter.dart:645-648, 664-668). It re-ran T13b and
  T13d itself, each mutation+test+restore in one shell call with a byte-identical
  restore, and got the Ruling-44 running-total signature on T13d (Expected 1 /
  Actual 2).
  On the controller's independence question it gave a structural answer rather
  than an impression: `reference_walk`'s fill case reads the boundary payload
  captured earlier in `_leaf`, builds its OWN local `Float64List(count*2)` rather
  than reusing a shared scratch buffer, and rebases with `ox`/`oy` rather than a
  matrix multiply — a different code path from the painter's matrix-based
  `toScreen`, so a bug in one is not reproduced by construction in the other. The
  comment at reference_walk.dart:278-282 cites Plan 3c Ruling 28.
Task 13: complete (commits 8b587cd..6c29d65, review clean)

=== RENDER PHASE COMPLETE — Tasks 11-13. A fill now reaches the screen. ===
  Commits 3201cc5..6c29d65. Engine 771, widgets 265 + 1 skip, all green.

=== MEASUREMENT PHASE BEGINS — Tasks 14-17 ===
Task 14: dispatched (sonnet, BASE 6c29d65) — goldens on both backends and the
  opaque agreement floor.
Task 14: implementer DONE_WITH_CONCERNS — commit a78a4ab. Widgets 272 pass / 1
  skip (was 265), goldens 29 pass (was 23 — six new, 3 rungs x 2 backends),
  engine 771, all analyze+format clean. Six new PNGs and NO pre-existing PNG
  regenerated, verified by the controller from the commit's file list.
  Opaque agreement: canvasInkPixels 377,858 against the 4,000 non-vacuity floor;
  strayVerticesPixels 0 and uncoveredCanvasPixels 0 — 0.00% each against a 1%
  ceiling. An exact match, not a tolerated one.
  T14b (winding normalisation dropped) KILLED on BOTH backends at all 3 rungs,
  because it empties the triangulation and the painter skips upstream of both
  sinks. T14c (fill through `_coveredArgb`) KILLED on vertices only, all 3 rungs.

Ruling: the controller's "T14a must red BOTH backends" instruction was WRONG,
  and the implementer was right to flag it rather than report a pass.
  — `CanvasDrawSink.fillPolygon` takes `triangles` in its signature and NEVER
  READS IT (verified: the identifier appears only at canvas_draw_sink.dart:173,
  the parameter list). That is the spec's own design — "CanvasDrawSink ignores
  `triangles`; `Canvas` resolves concavity itself" — so a triangulation-only
  mutant cannot reach the canvas backend through any fixture. My instruction
  contradicted the design it was meant to enforce. Eighth defect in the plan or
  its dispatches, same root: written from memory rather than from the file.
  The consequence is better than the instruction: **the canvas backend is the
  oracle for fills**, precisely because it never consults the triangulation. A
  bad triangulation surfaces as a canvas-vs-vertices disagreement, which is what
  the agreement row measures — and that row is 0.00%.
  — Cost if wrong: a triangulation mutant is pinned by one backend and the
  agreement row rather than by two goldens. The reviewer is asked to test that.
Task 14: review — spec ✅, quality approved with 1 Important.
  Reviewer verified both non-optional guards fire (devicePixelRatio at
  fill_ladder_golden_test.dart:313, non-vacuity at :343), confirmed no
  pre-existing PNG was regenerated, and OPENED the PNGs itself: L-notch unfilled,
  CW square solid, circle round, hairline square fully opaque, fills distinct
  from black boundaries, both backends matching. Re-ran T14b and confirmed the
  MECHANISM the controller claimed rather than the outcome.

  It answered the controller's open question with a measurement. Applying T14a to
  an L-shape and running `measureAgreement` moves `strayVerticesPixels` 0 ->
  44,521 against canvasInkPixels 552,977 = **8.05%**, eight times the declared 1%
  ceiling. So "the canvas backend is the oracle, and the agreement row is where a
  bad triangulation surfaces" is mechanically correct.

  Important (enters the fix loop): **it is not wired in.** The committed
  `fillComparisonDoc()` (sink_comparison.dart:449-485) carries only a CONVEX
  pentagon and a circle, and on a convex polygon fan-from-vertex-0 equals
  ear-clipping — so the committed `the two sinks agree on an opaque fill` test
  PASSES under T14a. The one property goldens provably cannot catch is caught by
  nothing in this task's own deliverable. Mitigating, and the reviewer found it:
  `packages/jet_cad_2d/test/geometry/triangulate_test.dart:30` kills T14a at the
  geometry layer, so the repo is not blind — but the safety net this task's
  report gestures at is not attached to this task's test.
  Reviewer flagged that it did not independently re-run T14c or the exact
  agreement numbers.
Task 14: fix round 1/5 dispatched — put a concave boundary in the agreement row.
Task 14: fix round 1/5 (1 addressed, 0 open — concave boundary in the agreement
  row; commits a78a4ab..15d97b2). Re-reviewer reproduced T14a exactly
  (Expected <=1741 / Actual 7744) and checked BOTH dead ends the implementer
  recorded. Dead end 1, geometrically: the fixture's vertex 0 is (-500,120) and
  the chord to vertex 3 (-260,0) passes through the excised notch, so a fan
  pivoted at vertex 0 genuinely leaves the polygon — AND the ring is already CCW
  (shoelace +43200), so winding normalisation never remaps which stored point is
  "vertex 0". The fixture works for the reason recorded, not by accident. Dead
  end 2: sink_comparison_test.dart:65-66 still declares `greaterThan(4000)` and
  `~/100`, unwidened. Convex pentagon and circle both still present. No golden
  PNG touched. No new breakage.
  Two dead ends worth keeping for whoever writes the next fixture: a fan from a
  reflex vertex INSIDE the visibility kernel produces zero error, so "concave" is
  not sufficient — the pivot must be outside the kernel; and the first attempt
  measured 0.98%, UNDER the 1% ceiling, which the implementer fixed by scaling
  the fixture 3x rather than by relaxing the threshold.
Task 14: complete (commits 6c29d65..15d97b2, review clean)

Task 15: dispatched (sonnet, BASE 15d97b2) — the translucent seam, measured
  against the real engine. The plan's most critical step: the repository's own
  TriangleRasterizer cannot see this artefact at all.
Task 15: review — spec ✅, quality approved with 1 Important, then fixed.
  MEASUREMENT OF RECORD: `SEAM interior=656204 over8=0 fraction=0.000% worst=0`.
  The declared rule DID NOT FIRE. Translucent fills batch; no production code
  changed by this task.
  The reviewer settled WHY the zero happened, with its own probe: two translucent
  triangles sharing a diagonal edge through `drawVertices` render BYTE-IDENTICAL
  with `isAntiAlias` true and false (maxDelta=0), and identical to a single-path
  fill, while a `drawPath` edge shows a real ramp (255,255,255 -> 204,216,242 ->
  153,178,229). **flutter_test's software Skia does not antialias `drawVertices`
  at all**, so mode 2's predicted mechanism — partial coverage feeding a double
  blend — has nothing to exploit in this instrument. The zero is a property of
  the instrument, not evidence the artefact is absent on hardware.
  Important, now fixed: the report claimed step 3 proved this was "not an
  instrument blind spot". It did not. Step 3's forced seam (each triangle emitted
  twice) is FULL double coverage over the whole interior and would trip red in a
  rasteriser with no antialiasing at all. It proves gross double-draws are
  caught, not the partial-coverage mechanism. **That instruction came from the
  controller's dispatch and was insufficient as a sensitivity proof.**
Task 15: fix round 1/5 (1 addressed, 0 open; commits c7d548e..4221006).
  The implementer took the better half of the option offered: it put the probe in
  a COMMITTED TEST, `test/drawvertices_antialiasing_test.dart`, not just the
  report — "a report is read once and archived; a test runs on every future
  change, and if Skia ever starts antialiasing `drawVertices` this goes red
  before anyone trusts fill_seam_test's stale zero". Re-reviewer verified the
  edge is genuinely diagonal (slope 0.6), that the contrast assertion is present
  so an all-flat result cannot mean "no slanted edge was drawn", and that probe 1
  compares two live renders rather than constants.
Task 15: minor (deferred): probe 2 hardcodes `_fullCoverage = [153,178,229,255]`
  as an exact equality. It is plain Porter-Duff arithmetic rather than an
  AA-specific detail, so low risk, but it is the more fragile of the two probes.
Task 15: complete (commits 15d97b2..4221006, review clean, 1 minor deferred)

**FOR TASK 17's RESULTS NOTE, verbatim from the amended report:** the rule did
  not fire and fills batch (settled), and the mode-2 question is OPEN on
  Impeller/GPU because the declared instrument provably cannot answer it.
  "Do not write 'no seam was found.'"

Task 16: dispatched (sonnet, BASE 4221006) — the rig grows fills. Device runs.
Task 16: review CLEAN — spec ✅, quality approved, 1 Minor.
  Reviewer verified the FILLS define throws on an unrecognised value, that
  fillCount/skippedFillCount have real skip conditions rather than being
  decorative, that AddRegionCommand triangulates eagerly at write time and the
  codec re-triangulates at load so the load-cost row measures what the spec
  means, and — the check that mattered — that R2's ACTUAL script constants
  (measurement_rig.dart:194-199) match what the report's corridor derivation
  claims, so the justification is not fabricated. It re-ran the load-cost test
  itself: 66ms against the report's 68ms. All 12 device timing lines carry
  [CONTAMINATED] and no timing conclusion is drawn from them.
Task 16: minor (deferred): the placement corridor is coupled to today's exact
  pan/zoom script constants. If `runR2Rig`'s script changes, coverage could
  silently degrade again; the `linkCount` guard catches total absence of fills,
  not under-coverage in the scripted window. Flagged by the implementer itself.
Task 16: complete (commits 4221006..f0ea51e, review clean, 1 minor deferred)

Task 17: dispatched (sonnet, BASE f0ea51e) — mutation log, exit gate, results
  note, STATUS.md. The last task.
Task 17: review — spec ✅, quality approved with 1 Important + 1 Minor, both
  fixed in round 1 (commits 8560ba2..3940ea2).
  Important: the allocation-gate blind spot was recorded in the mutation log and
  the results note but NOT in STATUS.md's Plan 3f section — the place CLAUDE.md
  sends a 3f implementer first. A record that is not where it will be read is not
  a record. Fixed as trap 5, written out standalone at STATUS.md:729-743, stating
  the hazard, why it bites and what it costs, in the shape traps 1-4 use.
  Divergence 5 was checked and deliberately NOT moved — the re-reviewer verified
  by reading that it appears at STATUS.md:360, :403 and :~684, all before the
  Plan 3f section starts at :692.
  Minor: mutation-count footnote — 56 counts verification RUNS; 55 distinct
  mutations, the keying mutant verified twice at different call-site surfaces.
  CLAUDE.md confirmed untouched across the WHOLE plan range, not just the commit.
Task 17: complete (commits f0ea51e..3940ea2, review clean)

=== ALL SEVENTEEN TASKS COMPLETE, each with an independent review ===
  Range 3201cc5..3940ea2. Engine 771, widgets 276 + 1 skip, goldens 29,
  all analyzers and formatters clean on all three packages.
  Fix rounds needed: Tasks 2, 8, 9, 14, 15, 17 — six of seventeen, one round each.

Final whole-branch review: dispatched on the most capable model over
  e487afb..3940ea2 (everything unpushed: the revised spec, the plan, all
  seventeen tasks).

=== FINAL WHOLE-BRANCH REVIEW: NOT READY ===
  One Critical, two Important, all reproduced by running code. Everything else
  green; no analysis_options.yaml or project.pbxproj in the branch diff; all
  five production `entityBounds` callers consistent and no sixth site exists.

  CRITICAL — `AddEntityCommand` (commands.dart:29-60) has no `EntityKind.fill`
  branch, yet `RemoveEntityCommand` (commands.dart:94-102) returns it as the
  inverse of removing a fill ALONE. Undo restores the entity and not
  `FillIndex._boundaryOfFill`. `validate()` cannot see it — it re-derives from
  the payload and never audits the index — and the codec repairs it only across
  save/load, so the corruption is invisible and in-session.
  Reproduced: `fillsOf(boundary)` returns [] while the fill is live, so a later
  `SetEntityGeometryCommand` skips the triangulation refresh and the STALE
  triangulation is drawn against the NEW points. Editing a hexagon to a triangle
  produced indices 4 and 5 against a 4-point loop; `reference_walk`'s buffer is
  `Float64List(count*2)` exactly, so the sink indexes out of range, and
  `skippedFillCount` stays 0 — the painter believes it drew a fill.
  Also: `RemoveEntityCommand(boundary)` then takes the no-dependents branch, so
  the boundary goes and the fill is left orphaned — the exact state the cascade
  exists to prevent. And `touched` omits the fill, so the index never re-derives
  its box.
  WHY SEVENTEEN REVIEWS MISSED IT: every fill-removal fixture in
  region_command_test.dart removes the BOUNDARY. Removing the fill alone and
  undoing is untested. The degenerate fixture, one level up.

  IMPORTANT — a malformed loaded document can be made permanently un-undoable.
  `RemoveEntityCommand` builds `AddRegionCommand` as its inverse without
  re-checking that command's three preconditions, and `_rebuildFills`
  deliberately links a fill to a missing/unfillable/foreign-owner/inverted
  boundary. Observed: both entities gone, `canUndo == true`, and undo throws
  `Bad state: 13 is not a fillable boundary` forever.

  IMPORTANT — the oracle is independent on ROUTING but not on TRIANGULATION.
  `reference_walk.dart:233` reads the same `doc.fills.trianglesFor(boundary)`
  the painter reads at draft_painter.dart:641. In the repro above both sinks
  emitted the SAME out-of-range index list, so the differential row can never
  catch a stale or wrong triangulation. Ruling 28 holds for the residual/rebase
  route and is not reopened; the carve-out is what is unrecorded.

  MINOR (new) — a fill outlives its boundary's visibility: neither `_drawFill`
  nor the oracle consults `EntityFlags.invisible`. Both backends agree, so no
  divergence fires. Spec is silent. Recorded, not fixed.

  All four deferred minors triaged as RIDES. The two open gate criteria were
  judged honest: refusing to score the 16.67 ms row is right rather than
  over-cautious, and the seam section cannot be misread as proving absence.

Final fix wave: ONE dispatch, all three findings.
