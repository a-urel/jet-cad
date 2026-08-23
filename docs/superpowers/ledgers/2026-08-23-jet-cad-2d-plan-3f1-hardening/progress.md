# SDD ledger — plan: docs/superpowers/plans/2026-08-23-jet-cad-2d-plan-3f1-hardening.md

Spec: docs/superpowers/specs/2026-08-23-jet-cad-2d-plan-3f1-hardening-design.md
Base: c078677 (main, clean tree, no worktree — human's explicit consent)
Models: implementers sonnet; task reviewers sonnet; final whole-branch review opus.

## Preflight scan

### Task pairs sharing a file or interface

| pair | shared surface | produces vs consumes | finding |
|---|---|---|---|
| 1→2 | `node.dart` → `style_resolver.dart` | T1 produces `.lineweight/.transparency/.linetype`; T2 consumes | agrees |
| 1→3 | `node.dart` → `style_resolver.dart` | T1 produces `.linetypeScale`; T3 consumes | agrees |
| 1→4 | `test/codec/instance_style_codec_test.dart` | T1 creates; T4 appends a group | agrees (T4 modifies, does not create) |
| 2→3 | `contextFor`'s `linetypeScale:` line | T2 writes `inherited.linetypeScale`; T3 replaces with the product | agrees — T3 names the exact line |
| 2→3 | `test/document/instance_style_test.dart` | T2 creates + defines `resolveThrough`/`addInstance`/`addByBlockLine`/`addDefinition`; T3 appends and reuses all four | agrees |
| 2→4 | BYBLOCK arms | T4's expected v5 values depend on T2's BYBLOCK → inherited | agrees |
| 3→4 | `linetypeScale` | T4 asserts `2.0` (entity 2.0 × default 1.0) | **non-discriminating for T3** — see finding F3 |
| 5→6 | `unitCamera()` | T5 defines; T6 defines an identical copy | **verbatim duplication** — see finding F1 |
| 5→6 | `test/invariants/` | both create files, no shared symbol | agrees |
| 5→7 | none | — | no interaction |
| 6→7 | `test/invariants/` | both create files | agrees |
| 7→1..6 | `pubspec.yaml`, meter | independent of Sections 1 and 2 | agrees |
| 8→all | notes + STATUS | consumes reports and transcripts | agrees |

### Per-task self-consistency

| task | own text vs own text | finding |
|---|---|---|
| 1 | test asserts `kSchemaVersion == 6`, Step 5 sets it; step order test→fail→fields→json→schema→run | agrees |
| 2 | Step 2 claims **"eight tests, all FAIL"** | **WRONG — two pass pre-change.** See finding F2 |
| 3 | Step 2 states the `1.0` guard test passes already and why | agrees, and honest |
| 4 | Step 2 states the whole group passes on first run as a regression guard | agrees, and honest |
| 5 | `SpatialIndex.dispose`, `Aabb2.isEmpty`, `addText`, `kViewport` all real | agrees |
| 6 | second paint builds `Canvas(PictureRecorder())` and never ends the recording | **contradicts the plan's own dispose rule** — see finding F4 |
| 7 | Step 7b uses `git checkout -- pubspec.yaml` | permitted, but collides with a global constraint's wording — see finding F5 |
| 8 | consumes only what Tasks 1–7 produce | agrees |

### Rulings

**Ruling F1 — `unitCamera()` stays duplicated across the two invariant files.**
Why: they are meant to be read alone, a four-line camera helper is not worth a
third support file, and the plan states the duplication with its reason. A
reviewer flagging it gets this ruling, not a fix round.
Cost if wrong: one helper drifts from the other and two invariant files
silently measure at different scales. Mitigated because each file asserts
`culledTextCount` explicitly, so a drifted camera fails rather than misreads.

**Ruling F2 — Task 2 Step 2's expectation is corrected to six FAIL, two PASS.**
Why: the two `kLineweightDefault` tests expect the inherited `25`, and
pre-change `contextFor` already returns `25` because it ignores the instance
entirely. They are regression guards for a capability that does not yet exist,
not red-green drivers; M9 is what proves they discriminate. Carried into the
Task 2 dispatch.
Cost if wrong: an implementer trusts a false "all fail" and edits a correct
test to make it fail. This ruling prevents exactly that.

**Ruling F3 — Task 4's `linetypeScale` row is kept although it does not
discriminate Task 3.** Why: it is a migration assertion (the INSERT default is
the identity), not a proof of the multiplication; Task 3's own
`2.0 × 4.0 × 8.0 = 64.0` carries that. Removing it would leave the v5 fixture
silent about a field it must preserve.
Cost if wrong: nothing — a redundant true assertion.

**Ruling F4 — Task 6's second paint must dispose its recording.**
Why: the plan's own rule is that a test leaving a `Picture` alive is the
"moved the leak" shape Plan 3f was written against, and the second paint in
`a repeated frame is a repeated frame` builds a recorder it never ends.
Corrected in the Task 6 dispatch: bind the recorder to a local and call
`recorder.endRecording().dispose()` after the second paint.
Cost if wrong: a leaked display list per test run — small, but it is the exact
defect class this plan exists to close.

**Ruling F5 — Task 7 Step 7b's `git checkout -- pubspec.yaml` is permitted.**
Why: the global constraint forbids `git checkout` as a way to revert a
*mutation* during mutation testing, because it silently discards unrelated
work. Step 7b reverts a whole file to its committed state as part of an
announced full revert, which is the ordinary use. The plan already says so.
Cost if wrong: none here — the file has no uncommitted work at that point,
and Step 4 has already committed nothing else to it.

## Progress

### Task 1 — plan defect found by the implementer's stop-gate

Task 1 Step 6 said "the pre-existing suite is unchanged and green — if any
pre-existing test moves, stop". Three moved. The implementer stopped and
reported rather than adjusting them, which is the gate working.

**Ruling T1-A — the three moved tests are authorised for re-baseline; the
plan's Step 6 expectation was wrong, not the code.**

Verified in the tree, not taken from the report:
- `test/codec/json_codec_test.dart:484-488` pins `expect(kSchemaVersion, 5)`
  by literal. Plan 3e wrote it when *it* bumped 4 -> 5; it breaks by
  construction on every bump. Its sibling at `:90-95` already expresses the
  same claim version-agnostically as `kSchemaVersion + 1`.
- `test/testing/generate_document_test.dart:56-59` and `:233-236` are FNV
  fingerprints over the serialised corpus. Their own comments record **two**
  prior re-baselines for this exact cause: Plan 3c Task 1 (four text keys
  changed the serialisation) and Plan 3e Task 7 (`kSchemaVersion` moved 4 -> 5,
  "the first thing every serialisation writes").

The discriminator, because `:225-228` explicitly warns that a moved fingerprint
is normally *the bug this test exists to catch*: a fingerprint that moves
because the **serialisation shape** changed is benign; one that moves because
the **RNG draw order** changed is the defect. This diff does not touch
`lib/src/testing/generate_document.dart`, and the structural sibling tests
stayed green — both would have moved under an RNG shift. The implementer must
state both facts in the report as the evidence, not assert the conclusion.

Cost if wrong: a real generator regression is re-baselined away and Plan 2's
corpus silently changes. Mitigated by the two-fact evidence requirement and by
the structural tests, which this ruling does not permit touching.

**Ruling T1-B — `json_codec_test.dart:486`'s `throwsA(anything)` is tightened
to `isA<SchemaVersionError>()` against version 7, not merely re-pointed at 6.**
Why: at `kSchemaVersion == 6`, `decode({'schemaVersion': 6})` no longer fails
the version check — it fails deeper, on a null cast for the missing `'header'`
key — so `throwsA(anything)` would have stayed green **for the wrong reason**.
The bump exposes a latent weakness in a test about refusal.
Cost if wrong: none — a strictly stronger assertion of the same claim.

Task 1: complete (commits c078677..25b9873, review clean — spec ✅, quality
approved, no ⚠️ items). Reviewer independently re-ran the three affected test
files and corroborated the mutation transcripts; it noted the M10 transcript
prints `Expected: <3> / Actual: <2>` rather than `Handle(3)`/`Handle(2)`,
which is right because `Handle` is an extension type erased to `int` — a
detail a fabricated transcript would likely have got wrong.

### Task 2 — second plan defect, from a wrong premise of mine

**Ruling T2-A — the `addLayer` helper removes before adding; the plan's fixture
premise was wrong.** `DraftDocument.empty()` seeds a layer-0 record at
`lib/src/document/tables.dart:509-516` (`color: IndexedColor(7)`,
`linetype: continuousLinetype`, `lineweight: kLineweightDefault`,
`transparency: 0`). I wrote the fixture believing layer 0 had no record —
my check had grepped only `draft_document.dart`, and the seeding lives in
`tables.dart`. Adding a layer-0 record therefore threw `DuplicateHandleError`
and the three BYLAYER tests errored rather than asserting, in both directions,
so Step 4's "eight PASS" was unreachable as written.

The implementer's fix — `doc.tables.layers.remove(handle)` before `.add(...)`
in the shared helper — follows the precedent at
`test/index/query_filter_test.dart:381-390`, which I verified. Authorised.

Worth recording because it changes what the test proves: the seeded layer 0
would have discriminated M6 anyway (its `-3` lineweight routes through the
`concrete()` guard to `inherited`'s 25, against layer L's 191; its
`transparency: 0` gives alpha 255 against 167; its `continuousLinetype`
against `Handle(71)`). The override makes that discrimination **chosen rather
than accidental**, which is the point of the anti-degenerate rule.

Cost if wrong: an unconditional remove-before-add in a shared test helper can
mask a genuine duplicate-handle defect in a future test that meant to add a
new layer. Flagged to the reviewer rather than pre-judged.

Task 2: complete (commits 25b9873..7f7aa76, review clean — spec ✅, quality
approved). Reviewer independently reproduced M6 against the working tree and
got the exact reported wrong values (lineweight 191→13, transparency 167→246,
linetype 71→70), and confirmed layer 0 and layer STRUCT differ on all three
properties so M6 cannot coincidentally survive on any of them.

Task 2: minor (deferred): `addLayer`'s unconditional remove-before-add in
`test/document/instance_style_test.dart` silently overwrites a pre-existing
layer rather than failing, so a future test in that file that meant to add a
*new* layer would not fail fast on an accidental duplicate. Reviewer's narrower
suggestions: guard the remove with `if (handle == ReservedHandles.layerZero)`,
or add an explicit `replaceLayer` beside `addLayer`. Scoped to one test file.
Carried to the final whole-branch review for triage.

Task 2: ⚠️ resolved by controller — the reviewer could not verify the
789-test full-suite / analyze / format run because I instructed it not to
re-run them. Not a gap: Task 3 edits the same file and re-runs the same suite
as its own gate, which re-confirms it one task later.

Task 3: complete (commits 7f7aa76..a5bcf98, review clean — spec ✅, quality
approved, no ⚠️ items). Reviewer independently reproduced M4 (reddened to
exactly 2.0), re-derived M5's 8.0 from the traversal order, ran
`git status --short .../test/golden` itself and got empty, and confirmed the
FNV fingerprint file is untouched by this diff. First task in the plan whose
change could move a drawing; 35 goldens unmoved, no PNG regenerated.

Task 4: complete (commits a5bcf98..03bc025, review clean — spec ✅, quality
approved, no ⚠️ items). Reviewer independently reproduced M10 and got the exact
claimed transcript (`Expected: <4> Actual: <71>`), hand-traced the resolver to
confirm all four expected values are correct literals rather than tautologies,
and confirmed the fixture strips exactly the four keys `InstanceNode.toJson`
gained — no more, no less.

Task 4: minor plan inaccuracy (no action): the plan's Task 1 code block carries
`import 'dart:typed_data';` in the codec test file, but Task 1's own tests do
not use `Float64List`, so its implementer correctly omitted it; Task 4 added it
when the derived fixture made it necessary. Self-correcting, recorded so the
same line in the plan is not read as a Task 1 defect later.

**Section 1 complete.** Criteria 1-11 are carried by Tasks 1-4. Engine suite
793, Flutter 299, 35 goldens unmoved across the whole section.

### Task 5 — my own spec/plan claim is false, and it is now committed in a comment

**Controller-found finding (Important), before the review was dispatched.**

`test/invariants/text_cache_invariants_test.dart:13-15` states, in present
tense: "**no test in that file ever pushed past 512 distinct metrics keys**".
That is copied from the plan, which copied it from the spec, which I wrote.
It is false as of Plan 3f's own remedy commit `645b027`.

`test/flutter_text_measurer_test.dart:209-237`, "the default metrics bound is
not the paragraph bound", constructs a **bare** `FlutterTextMeasurer()`, sweeps
`kParagraphCacheLimit + 1` distinct strings through `measure()`, and asserts
`metricsEvictionCount == 0` and `liveMetricsCount == 513`. That is exactly the
"bare **and** past the bound" shape the spec claimed was missing. My spec
described the file as it stood *before* 3f's remedy landed, in the present
tense, and three rounds of review did not catch it because none of them was
pointed at that sentence.

**What the new file actually adds, stated correctly:** 3f's remedy exercises
`measure()` only — it asserts `liveParagraphCount == 0` explicitly and never
calls `paragraphFor`, never runs a painter, and pins `paragraphLimit` only by
restating the constant. The new invariant drives a real paint through
`CanvasDrawSink`, fills **both** maps, and pins the paragraph eviction
arithmetic (600 keys → 512 live, 88 evicted) behaviourally. Non-redundant, but
a narrower contribution than the comment claims.

**Ruling T5-A — this enters the fix loop as an Important finding.** The code is
correct; the justification is false. A comment that justifies a decision with a
claim that is not true is the defect Plan 3f's Task 6 hit and recorded, and
this repository's methodology rests on written evidence being trustworthy.
Cost if wrong: none — correcting a comment cannot break a test.

Carried to Task 8: the results note must state the corrected diagnosis, and
must not repeat the spec's present-tense claim.

Task 5: also authorised, both reported by the implementer and verified by me —
(a) `rig_support.dart` gets `export` only, not `import + export`: it never
references `TextKeySink`, and `unused_import` is an ERROR in this package;
(b) the `vector_math_64` import was dropped from the new test file for the same
reason. Both were plan errors, both self-correcting.

Task 5: M12 reddens **two** tests under the full suite, not one as my dispatch
predicted — 3f's remedy test (metrics side) and the new invariant (paragraph
side). Better evidence than expected, and the implementer reported it honestly
rather than trimming it to match my phrasing.

Task 5: fix round 1/5 (2 addressed, 0 open — false header claim narrowed to
what the file genuinely adds; fixtures.dart citation corrected 184→183;
commits a5ff5db..e39f295). Re-review confirmed comment-only: no executable
line, import, test name, assertion or literal changed.

Task 5: complete (commits 03bc025..e39f295, review clean after one fix round).

Task 6: complete (commits e39f295..b1e9ec1, review clean — spec ✅, quality
approved, no ⚠️ items). Reviewer live-reran all three mutants and reproduced
the exact Expected/Actual values and pass/fail pattern; verified in source that
`VerticesDrawSink` has exactly three `_fallback?.` sites and that none of
`CanvasDrawSink`'s seven `_canvasCalls++` sites is in a residual method, which
is what gives the third identity teeth; confirmed the sanctioned `unitCamera()`
duplicate is byte-identical to Task 5's copy rather than drifted; confirmed
both recorders are ended and disposed, including the one the controller
correction added.

**Section 2 complete.** Criteria 12-16 carried by Tasks 5-6. Flutter suite 304
passed / 1 skipped (rig).

### Task 7 — the probe is RED, the stop clause fired, Section 3 is dropped

No commit. The tree is byte-identical to `b1e9ec1`: the file move, the three
import re-points, the `testing.dart` export and the `vm_service` promotion were
all reverted, the probe file deleted, and both suites re-verified green (engine
793, Flutter 304 passed / 1 skipped).

**The cause is named, not left as "connect() returned null".** `connect()`
swallows its reason by design (`catch (_) { return null; }`), which would have
left Plan 3g with an unverified sentence — the exact defect class this plan
exists to remove. One scoped diagnostic, run without the swallowing catch and
committing nothing:

```
serverUri: null
isolateId: isolates/5126513748590131
```

`dart:developer`'s `Service.controlWebServer(enable: true)` returns an info
object whose `serverUri` is null under `flutter_tester`, while
`Service.getIsolateId(Isolate.current)` resolves normally. The isolate is
registered with the service protocol; the **HTTP server component never
starts**. That is a platform fact about the test runner, not a connection
problem — so there is no URI to fix and no retry that would help.

**Ruling T7-A — one diagnostic pass was authorised after the stop clause
fired, and it did not reopen the verdict.** The stop clause forbids negotiating
the threshold or retrying for a green; it does not forbid making the recorded
finding specific. Section 3 stayed dropped throughout, and the diagnostic
committed nothing.
Cost if wrong: one extra agent turn. The alternative was handing 3g "it does
not work, cause unknown".

**Explicitly unexplored, recorded so nobody reads this as exhaustive:** whether
a flag-based route exists (`flutter test --start-paused`, or an
`--enable-vmservice`-style option) was **not** tried. What was tested is the
mechanism `AllocationMeter` actually relies on — starting the service at
runtime from inside the isolate with no launch flag — and that is what does not
work. A flag-based route, if one exists, would need a debugger to attach and so
would not serve an always-on gate anyway.

**What Plan 3g now knows before it starts:** its cache-miss allocation risk
cannot be gated by a frame-path allocation profile in `jet_cad_2d_flutter`.
It needs a command-time assertion — the mechanism that actually proved fills
eager in Plan 3e, after the allocation gate stayed green through the mutation
that should have broken it.

### Task 7 — correction: the cause is a launch flag, and my own entry above was wrong

The task review over-read nothing of its own and found what both the report and
**this ledger** got wrong. Recorded here rather than by editing the entry above,
because the wrong reasoning is part of the record.

**What the diagnostic actually measured:** two facts only — `serverUri` came
back `null`, and `getIsolateId` returned a real id. The report then chose one
branch of its own honest disjunction ("the web server never started / never
reported a URI") with no evidence separating them, and my ledger entry above
repeated that choice and went further, asserting "no retry would help".
`getIsolateId` is an in-process lookup and does not depend on the HTTP layer,
so it never distinguished the two cases either.

**What the reviewer found, by looking at the process rather than the API:**

```
flutter_tester --disable-vm-service --enable-checked-mode ...
```

`flutter test` launches `flutter_tester` with **`--disable-vm-service`**. The
server never starts because it is switched off at launch — a flag, not a
platform limitation of the runner.

**Ruling T7-B — the verdict stands, the reasoning is replaced, and one
implication is withdrawn.**
- Stands: Section 3 is dropped; the meter's mechanism (start the service at
  runtime from inside the isolate, no launch flag) cannot work under `flutter
  test`, because the flag closes the door before any in-isolate call runs.
- Replaced: the cause is `--disable-vm-service`, evidenced by the process line,
  not "the HTTP component never comes up" inferred from a null field.
- **Withdrawn:** my "no retry would help". A flag-driven cause means a
  flag-based route (`flutter test --start-paused`, or anything that stops
  passing `--disable-vm-service`) is *plausible* and was never tried. Plan 3g
  should be told it is plausible-but-unexplored, not impossible. It still would
  not serve an always-on gate, since the flag is passed by `flutter test`
  itself and not by anything this repository controls per-test.

Cost if wrong: 3g writes off a mechanism that a flag could have given it. The
withdrawal is what prevents that.

**Third instance of one pattern in this plan** — a stated cause stronger than
the evidence behind it. Mine in the spec (defect 4's diagnosis, caught by the
Task 5 review), mine again here, and the Task 7 report's. Each time it was
caught by someone *running* something rather than reading. Carried to Task 8:
the results note should name this as the plan's own recurring failure mode.

Task 7: fix round 1/5 dispatched — correct the report's causal claim.

Task 7: fix round 1/5 (1 addressed, 0 open — the report now separates the two
measured facts from the conclusion, names `--disable-vm-service` with a
first-hand process line as its evidence, withdraws "no retry would help" as
plausible-but-unexplored, and keeps the superseded reasoning visible rather
than rewriting it away). No commit; report-only.

Task 7: complete (no commit — probe RED, stop clause fired, Section 3 dropped,
tree verified byte-identical to b1e9ec1 by both the reviewer and the
re-reviewer).

Environment note for the results note: `flutter --version` is **3.47.1**,
framework `6655482ec0`. The `3.27.3` in the `flutter_tester` process path is a
stale Homebrew cask directory name, not the running version — do not record it
as one.

Task 8: complete (commits b1e9ec1..490ae8e, review clean — spec ✅, quality
approved, no ⚠️ items). Reviewer ran both suites first-hand (793 / 304+1),
checked four mutation transcripts verbatim against the task reports including
Task 7's process line, and confirmed STATUS.md's pre-task baseline really was
two commits stale, validating the scope expansion.

**Criteria: 16 PASS / 1 MISS / 0 UNEVALUABLE. Mutants: 17 killed, 0 survivors.**

Task 8: minor (deferred, spec-side): the spec's Named-mutants table maps M10 to
criteria "9, 11"; the observed second kill is criterion 10's absent-tolerant
sub-test, not criterion 11's golden claim. The results note maps it correctly
and is internally consistent, so this is a latent typo in the binding document
rather than anything Task 8 introduced. Carried to the final whole-branch
review for triage — it matters because the spec is what a later plan reads.

**All eight tasks complete.** Dispatching the final whole-branch review over
c078677..490ae8e.

## Final whole-branch review — 0 Critical, 3 Important, 5 Minor

Reviewer ran both suites, fired its own mutants, painted a real document to
prove the model change reaches a drawing (`lw=211 alpha=118 linetype=42
linetypeScale=16.0`), wrote an exhaustive five-route `kLineweightDefault` test
(all resolve to 25), and measured `contextFor`'s new closure under the VM
allocation profiler (noise floor). Method stated, so the clean half is worth
something.

**Ruling FR-1 (Important 1) — FIX. The mutation log and results note mislabel
which side of the cache M12 exercises, and my own Task 5 fix-round wording
carries the same error.** Measured by the reviewer: M12 fails at
`text_cache_invariants_test.dart:127`, `expect(measurer.liveMetricsCount, 600)`
— the **metrics** assertion, the same side as the pre-existing sibling test.
**M13 is the only mutant that discriminates the new file's unique
contribution**, at `:132`. The log calls that the "paragraph side" while
quoting a metrics counter in the same clause, and the header comment I dictated
in Task 5's fix round says mutant 7 "reddens both files, each from its own side
of the cache" — also false.

**This is the fourth instance of this plan's recurring failure mode, and the
second and third are mine.** It occurred inside the artifact that names the
failure mode. Cost if unfixed: a 3g author concludes that firing Plan 3f's
survivor proves the paragraph half is gated. It does not — M13 does.

**Ruling FR-2 (Important 2) — FIX, and it is more than the typo the ledger
called it.** The spec maps M10 to criteria "9, 11", but **criterion 11 has no
mutant that could redden it at all**: no golden test deserialises, so a
`fromJson`-default mutation cannot move a PNG. Criterion 11's real verification
is `git status --short test/golden` — a measurement, the same shape as
criterion 17, which the spec already carves out. The spec's own sentence
"sixteen of them are claims a test makes, and each of those has at least one
named mutant" is therefore false. Remap M10 → 9, 10 and carve criterion 11 out
beside 17.

**Ruling FR-3 (Important 3) — RECORD, do not fix.** An INSERT's own ATTRIBs do
not see the style the INSERT imposes: `container_index.dart:207-224` folds an
instance's leaves into the *enclosing* container, so they draw under the
enclosing context. `reference_walk.dart:88-99` mirrors it, which is why the
differential suite is structurally blind. Verified by probe, not inferred.
**Not a regression** — already true for `color` and `layer`, the two fields
`InstanceNode` had. But this branch quadruples the affected surface, and in DXF
an ATTRIB is a sub-entity of the INSERT, so BYBLOCK on it should resolve
against the INSERT. Fixing it changes `container_index`, `reference_walk` and
the oracle's blindness together — its own plan's worth of blast radius.
Cost if wrong: 3g inherits a stated gap instead of a silent one, which is the
cheaper error.

**Ruling FR-4 (Minor 5) — keep the `TextKeySink` move, correct its
justification.** The spec claimed "one definition, four readers"; the count was
wrong (it counted the declaration as a reader) and neither new invariant file
imports it. The move is currently **inert**: both real readers still reach it
through `rig_support.dart`'s re-export. Keeping it costs nothing and leaves the
class better placed; the misleading justification is what gets fixed.

**Minors 4, 6, 7, 8 — FIX, all in the same wave** (test-count derivation
contradicting STATUS.md's 777; `addLayer`'s remove guarded to layer 0; the
BYLAYER fixture's missing `addDefinition(Handle(210))`; "fifty-four" vs
"Fifty-three" inconsistent inside my own spec).

Dispatching ONE fix wave for FR-1, FR-2, FR-4 and minors 4, 6, 7, 8, plus
recording FR-3.

