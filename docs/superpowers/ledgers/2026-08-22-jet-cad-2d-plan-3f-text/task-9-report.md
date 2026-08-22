# Task 9 report — mutation testing, the results note, and the exit gate

## Commits

| SHA | subject |
|---|---|
| `645b027` | test: close gate row 7, and kill the mutant that survived its own suite |
| `2c6bdaa` | test: run exit-gate row 10 at corpus scale, and record that it has no teeth |
| `8f45e82` | docs: Plan 3f's mutation log — fifteen mutants, one restatement |
| `d113d2d` | docs: Plan 3f results — 11 of 13, and the two that miss |
| `6efd7fa` | docs: STATUS.md carries Plan 3f's finished account |

Committed incrementally as each piece was verified, per the brief.

## Conditions

```
$ pmset -g | grep lowpowermode
 lowpowermode         0
```

Read **before** this task's first timed run.

```
$ flutter --version
Flutter 3.47.1 • channel stable
Framework • revision 6655482ec0 (3 days ago) • 2026-08-19 10:07:23 -0700
Engine • hash 11d79658c444477b06513d32b52c8c4ccb7276b0 (revision 5d53178869)
Tools • Dart 3.13.1 • DevTools 2.60.0
```

## Step 1 — the fifteen mutants

Full transcripts, diffs and verdicts are in
`docs/superpowers/notes/plan-3f-mutation-log.md`. Every mutation, its test and
its restore ran in **one shell call**. The mutation was applied by a helper
that refuses to write unless its anchor matches **exactly once**, so a
mutation that silently missed its site cannot be reported as applied. No
mutation was reverted with `git checkout`; `git diff --stat <target>` was read
after every restore and was empty in all seventeen runs.

**14 killed, 1 restatement.** Plus the one mutation the spec records as
unmeasurable, which is logged with its reason and is not one of the fifteen.

Three findings worth surfacing here rather than only in the log:

**Mutant 7 survived.** `metricsLimit` defaulted to `kParagraphCacheLimit`
passed the whole suite — `EXIT=0`, `00:03 +297 ~1: All tests passed!`. Every
test in `flutter_text_measurer_test.dart` constructs the measurer with **both**
bounds given explicitly, so the defaults themselves were never exercised by
anything that could fail. At rig scale the mutant is glaring and unasserted:
`liveMetrics=512 metricsEvictions=608634` against the shipped
`liveMetrics=4020 metricsEvictions=0`. Recorded as a survivor first, then
killed by a test written for it in `645b027` — with the behavioural assertions
placed before the constant check, so the kill is an observation rather than a
restatement of the mutation. The finding is about the suite's shape: a file
that always passes every bound explicitly cannot see a wrong default, and the
same hole would hide a wrong `paragraphLimit`.

**Mutant 3's named killer does not fire.** The spec expected row 5
(`culledTextCount` at the working-set camera). Fired at rig scale, row 5 wants
0 and gets 0 — passing — because every string in the corpus is at least 80
world units tall, so a cull on raw height culls nothing anywhere
(`LOD MARGIN: smallest drawn cap height 79.9980 px ... culled: 0` on **both**
cameras). The rig row that does catch it is **row 4**: 414 shipped, 0 mutated.
Three unit/golden tests redden as well. The spec's expected killer is corrected
in the log rather than reported as having fired.

**Mutant 10 is the restatement.** Re-fired first-hand rather than taken from
Task 5's report. Row 6's test — `doc.extents is bit-identical whichever
threshold the painter runs at` — **passed**. `entityBounds` has no channel to a
painter's `minTextCapPixels`, so it recomputes identically on both reads and
two identical wrong answers compare equal. Criterion 6 is **structurally
guaranteed rather than testable**. Recorded as a restatement beside its row,
never as a silent kill and never as a failure. The mutation is caught
incidentally by three other tests (four, after `645b027`).

## Step 3 — the thirteen criteria

**11 pass, 2 miss, 0 unevaluable.** Every number is in
`docs/superpowers/notes/2026-08-22-plan-3f-results.md`.

**Rows 1 and 2 MISS, and were left missing.** 3,876 new layouts and 3,876
paragraph evictions on a repeat frame at the whole-drawing camera, against a
threshold of 0 and a baseline of 4,140. Verbatim from the rig:

```
      newLayouts=3876 newParagraphEvictions=3876
      cache: layouts=224808 paragraphEvictions=224296 metricsEvictions=0 liveParagraphs=512 liveMetrics=4020
```

Neither remedy was taken. `kMinTextCapPixels` was **not** raised — 6.0 makes
both rows comply and would be a threshold chosen because a gate needed it,
where 3.0 was chosen from a readability argument. Ruling 4's single permitted
`kParagraphCacheLimit` raise is **now available** (the measured
distinct-visible-key count it requires exists: 3,876) and is **written up as an
option with its cost and left unspent** — it is the human's decision. Both the
results note, `STATUS.md`'s Resume-here section and the Ruling 4 entry itself
now say so.

**Two rows pass without being able to fail, and both say so.** Row 6 is
structurally guaranteed (above). Row 10 at **corpus** scale is
non-discriminating: `doc.extents` is not the 4,020-key sweep the design
document justified it with — `_computeExtents` caches bounds per *definition*,
so 20,000 instances over 200 definitions measure **12** distinct strings — and
the row passes under both mutations it exists to catch, because LRU drops the
oldest entries while the working-set camera's 18 keys are the newest with 512
slots. The discriminating form is the unit-scale test, which mutants 6 and 12
both redden.

## Two things landed that the brief did not list, and why

**`645b027` — two tests.** Row 7 (picking a text entity at both thresholds)
had **no test at all**, so it could only have been asserted rather than run;
it now has one, and it is not vacuous — the pick is asserted to land, and
mutant 10 reddens it through that guard. And mutant 7 survived, which the plan
explicitly answers with "either add the test that kills it or record it as a
gap."

**`2c6bdaa` — row 10's corpus-scale procedure, in the rig.** It had no in-tree
form, so running it meant either a patch applied and thrown away — the exact
cost Task 8 was reviewed for — or landing it. It sits inside the rig test, so
it costs the ordinary suite nothing, and its comment records that it does not
discriminate on this corpus rather than letting a passing row read as
evidence.

## Step 4 — the full green gate

| command | result |
|---|---|
| `packages/jet_cad_2d` — `CI=true dart test` | `00:02 +777: All tests passed!` |
| `packages/jet_cad_2d` — `dart analyze` | `No issues found!` |
| `packages/jet_cad_2d` — `dart format --set-exit-if-changed` | `Formatted 110 files (0 changed)` |
| `packages/jet_cad_2d_flutter` — `CI=true flutter test` | `00:03 +299 ~1: All tests passed!` |
| `packages/jet_cad_2d_flutter` — `CI=true flutter test --tags golden` | `00:02 +35: All tests passed!` |
| `packages/jet_cad_2d_flutter` — `flutter analyze` | `No issues found! (ran in 0.7s)` |
| `packages/jet_cad_2d_flutter` — `dart format --set-exit-if-changed` | `Formatted 51 files (0 changed)` |
| `apps/dev_harness_2d` — `flutter analyze` | `No issues found! (ran in 0.8s)` |
| `apps/dev_harness_2d` — `dart format --set-exit-if-changed` | `Formatted 4 files (0 changed)` |
| `packages/jet_cad_2d` — `dart run benchmark/query_throughput.dart` | `GATE: PASS -- every gated row is under its threshold.` |

`snap at dirty threshold`, Plan 2's carried failure, **passed** on this run
(p50 0.552 ms, p95 0.680 ms against < 1.0 ms). It is a timing row on a shared
machine; recorded as passing today, not declared fixed.

## Steps 5 and 6

`docs/superpowers/notes/2026-08-22-plan-3f-results.md` — every criterion with
its measured number and verdict, the threshold ladder (re-run from the
committed tree for this note and reproducing Task 8's table byte-for-byte),
Task 6's per-site margin table, the measured distinct-key count, Low Power
Mode, the exact Flutter and framework versions, and an explicit section on
what this plan did **not** close: permitted divergence 5, the unmeasurable
metrics-lookup allocation, the step-function shape of the corpus's text
pressure, plus the two non-falsifiable rows and mutant 7's exposed hole.

`STATUS.md` — the in-flight Plan 3f section replaced with the finished
account; suite table **re-run**, not read off this plan; roadmap item 4
("whole-drawing thrash → text LOD") rewritten as **attempted, measured and not
closed** rather than ticked off; Ruling 4 annotated with the count that makes
its raise available; Plan 3g's inheritance written out including the
unresolved question of whether a cached picture may contain text at all.

## Constraints observed

No `analysis_options.yaml`, `Podfile` or `Runner.xcodeproj/project.pbxproj`
staged or committed — the three pre-existing `apps/dev_harness` artefacts are
untouched and are the only entries in `git status --short`. No golden PNG
regenerated. No `CLAUDE.md` amendment. `packages/jet_cad_2d` touched only
transiently, for mutant 10, and restored from a copy. No subagents dispatched.
No test output synthesised: every transcript in the log and the note comes
from a run whose command is printed above it.

## Concerns for a reviewer

1. **The three new/changed test files are the part to check hardest.** They
   were added on a judgement call about scope; a reviewer who thinks row 7
   should have been recorded as unevaluable instead should say so.
2. **The rig still asserts almost nothing.** Rows 1–5 and corpus-scale row 10
   are prints. Mutant 7 survived precisely because a glaring 608,634 metrics
   evictions printed and passed. Turning the rig's degeneracy guard into a set
   of real assertions is a candidate follow-up and was out of scope here.
3. **The 3.0005 / 3.0006 px discrepancy** at
   `paint_microbench_test.dart:313` is still unreconciled, deliberately —
   fifth significant digit, inside the bisection's own tolerance, and it
   belongs to Task 6's narrative.
4. **The ledger is not archived.** `.superpowers/sdd/2026-08-22-jet-cad-2d-plan-3f-text/`
   still needs copying to `docs/superpowers/ledgers/` before it is cleared;
   `STATUS.md` says so in two places.

## Final fix wave

Applied directly on `main`, per the whole-branch review's findings (no
Critical; this closed the Important/Minor/must-fix items).

**Commits**

| SHA | subject |
|---|---|
| `486c1b7` | test: teardown for every FlutterTextMeasurer in the rig and its unit test |
| `bce35c7` | docs: the rig's follow-up gets a permanent home, and the default audit is named |

**Finding 1 (Important).** `test/rig/paint_microbench_test.dart` had three
`FlutterTextMeasurer` constructions with no `clear()`/`addTearDown` (two new in
this plan). The two ordinary test-body sites now take `addTearDown(measurer.clear)`,
matching the file's existing idiom. The third sits inside the threshold-ladder
loop (up to fourteen iterations per test); `addTearDown` only fires once per
test, so it would let every iteration's live paragraphs pile up together. That
one is `paragraphs.clear()` at the end of each loop iteration instead, with a
comment saying why.

**Finding 2 (Minor).** `test/flutter_text_measurer_test.dart` — all twelve
`FlutterTextMeasurer` construction sites now take `addTearDown(m.clear)` (one,
previously an inline `FlutterTextMeasurer().measure(...)` expression with no
reference to clear, was given a name first). Reran green, 12/12.

**Finding 3 (must-fix).** "Turn the rig's prints into assertions" — previously
only in this git-ignored report — is now item 7 of
`docs/superpowers/notes/2026-08-22-plan-3f-results.md`'s "what this plan did
not close" list, with the mutant-7/608,634-metrics-evictions evidence.

**Finding 4.** The "not audited elsewhere" claim (results note item 6 and the
matching `STATUS.md` sentence) was false — it was audited. Both now name the
three known instances: `metricsLimit`'s default (mutant 7), `paragraphLimit`'s
default (reddens only a restatement test), and `reference_walk.dart:36`'s
`minTextCapPixels` default (a caller's own default shadows it; `0.0` there
leaves the suite green).

**Finding 5.** `STATUS.md`'s header and suite-table SHA brought current to
`486c1b7` — the commit the verification suites below actually ran against.

**What did not change.** `kMinTextCapPixels` stays `3.0`, `kParagraphCacheLimit`
stays `512`. Ruling 4's permitted raise stays unspent. No `analysis_options.yaml`,
`Podfile` or `Runner.xcodeproj/project.pbxproj` staged. No golden PNG
regenerated. `CLAUDE.md` unamended. `packages/jet_cad_2d` untouched. No
subagents dispatched.

**Verification, real output**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
...
00:03 +299 ~1: All tests passed!
```

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test --tags rig --run-skipped \
    test/rig/paint_microbench_test.dart --plain-name "text paint at 50000"
...
01:48 +1: text paint at 500000
=== 500000 entities, with text ===
  ...
04:18 +2: All tests passed!
```
(The `--plain-name` filter matches both `text paint at 50000` and
`text paint at 500000` by substring; both ran and both passed, exercising the
teardown change at the two ordinary sites. `LADDER` was left unset for this
run — matching how the file has always been exercised outside a deliberate
ladder run — so the ladder loop itself did not iterate and its
`paragraphs.clear()` line was not runtime-exercised here; `flutter analyze`
confirms it compiles, and `clear()`'s own behaviour is covered directly by
`flutter_text_measurer_test.dart`'s "clear empties both maps".)

```
$ cd packages/jet_cad_2d_flutter && flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)

$ cd packages/jet_cad_2d_flutter && dart format --output=none --set-exit-if-changed .
Formatted 51 files (0 changed) in 0.07 seconds.
```

```
$ cd packages/jet_cad_2d && CI=true dart test
...
00:02 +777: All tests passed!

$ cd packages/jet_cad_2d && dart analyze
No issues found!

$ cd packages/jet_cad_2d && dart format --output=none --set-exit-if-changed .
Formatted 110 files (0 changed) in 0.14 seconds.
```

```
$ cd apps/dev_harness_2d && flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 0.8s)

$ cd apps/dev_harness_2d && dart format --output=none --set-exit-if-changed .
Formatted 4 files (0 changed) in 0.03 seconds.
```

`git status --short` after both commits shows only the three pre-existing
`apps/dev_harness` files.

**Concerns for a reviewer.** None outstanding from this wave. The one earlier
process note: the rig run legitimately takes several minutes at 50,000+500,000
entities and auto-backgrounds past the tool's 120s foreground limit — that is
expected, not a hang, and its own output confirmed the teardown change did not
break the rig (exit code 0, both corpus sizes passed).
