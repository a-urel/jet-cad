# Task 15 report — the results note and the exit gate

Worktree: `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike`
Branch: `spike/vertices-sink`
Commit: `2f6223e` — `docs: Plan 3d results and exit gate`
Tree: clean after the commit.

**Status: DONE_WITH_CONCERNS.** Seven criteria pass on runs I made and pasted.
Criterion 7 is measured and left open for the human, exactly as the brief
directs. `CLAUDE.md` untouched. `superpowers:finishing-a-development-branch`
NOT run; nothing merged, pushed or deleted.

---

## Step 1 — the exit gate, criterion by criterion

Everything below was run by me on this tree at `4a16b41` (the code state; the
only later commit is my own docs commit). Every transcript is real output.

### Criterion 1 — both suites green, analyze and format clean — **PASS**

```
$ cd packages/jet_cad_2d && dart test
00:02 +720: All tests passed!
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
$ dart format --output=none --set-exit-if-changed .
Formatted 105 files (0 changed) in 0.13 seconds.
exit=0

$ cd packages/jet_cad_2d_flutter && flutter test
00:02 +238 ~1: All tests passed!
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
$ dart format --output=none --set-exit-if-changed .
Formatted 44 files (0 changed) in 0.06 seconds.
exit=0

$ cd apps/dev_harness_2d && flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 0.9s)
$ dart format --output=none --set-exit-if-changed lib integration_test
Formatted 3 files (0 changed) in 0.01 seconds.
exit=0
```

238 passing / 1 skipped, as the controller said. Re-run after my docs commit,
identical.

**I checked what the skip actually is** rather than repeating the phrase
"1 pre-existing skip". It is a *suite-level* skip, not a test-level one:
`test/rig/paint_microbench_test.dart`, skipped by the `rig` tag in
`dart_test.yaml` ("run explicitly: flutter test --tags rig --run-skipped").
Found by re-running with `--reporter json` and reading the `skipped` flag back
to its suite path. The note and `STATUS.md` say this rather than leaving a
reader to assume a Plan 3d test is skipped.

Also verified `git status --short` is empty after every `flutter test` — no
`analysis_options.yaml` rewrite got picked up.

### Criterion 2 — every mutant in the design's table killed — **PASS, one qualification**

`docs/superpowers/notes/plan-3d-mutation-log.md` exists, 41 mutants accounted
for. The design's table is 14 rows (spec lines 447-460: `J1`-`J9`, `V1`, `P1`,
`B1`, `B2`, `A1`). The log's category table:

```
| Named in the design document (`J1`-`J9`, `B1`, `B2`, `A1`, `V1`, `P1`) | 14 | 13 killed outright, 1 (`A1`) survived and was closed |
| **Total accounted for** | **41** | **34 killed, 1 control, 2 unreachable, 2 cited, 2 not reproducible** |
```

All 14 named are killed. **Qualification, taken from the log's own text rather
than smoothed over:** `B1`'s tabled fixture ("a test that overrides the backend
and reads it back from both the widget and the rig") does not exist, and `B1`'s
literal mutation has no line to invert. The log says at line 155 that Task 15's
exit-gate reader should treat `B1` as "killed via an equivalent mutation, not as
the tabled mutation run literally." The note repeats that verbatim in substance.

### Criterion 3 — sink against sink on point/polyline/circle/arc/text — **PASS**

```
$ cd packages/jet_cad_2d_flutter && flutter test test/sink_comparison_test.dart
00:00 +0: the two backends draw the same drawing
00:00 +1: the two backends agree on the ops the painter cannot emit
00:00 +2: anisotropic stroke width diverges, and vertices is right
00:00 +3: a sub-pixel stroke is where the two backends stop agreeing
00:00 +4: a full-sweep ARC leaves an unjoined seam. This is a defect
00:00 +5: All tests passed!
```

**I verified the fixture actually carries all five primitives** rather than
trusting the test name — read `comparisonFixture()` in
`test/support/sink_comparison.dart`: a point marker, an oblique-corner polyline,
a past-the-limit (160°) polyline, an open arc, a text entity, and a circle under
a rotated + non-uniformly-scaled residual. `assertNoIdentityTransforms(doc)`
runs first.

**Tolerance justified by measurement:** `kInkAlphaFloor = 0xC0` and a 3×3
one-pixel dilation in `_nearInk`, with the reasons in the source. Measured 0
stray / 0 uncovered at that tolerance; the tolerance was not widened to get
there.

### Criterion 4 — goldens on both backends for all 14 fixtures — **PASS**

```
$ flutter test --tags golden
00:01 +23: All tests passed!
$ ls test/golden/*.png | wc -l          -> 14
$ ls test/golden/vertices/*.png | wc -l -> 14
```

23 test cases, 28 PNGs. **I checked the arithmetic** (23 ≠ 28) by enumerating
test names via `--reporter json`: 20 ladder cases (5 rungs × 2 files × 2
backends), one `paper-space stroke width at three zoom levels` covering the 3
stroke-width fixtures on both backends, one `an anisotropic instance draws exact
per-axis widths`, and one non-golden `the anisotropic instance really took the
bypass`. All 14 fixtures are covered on both backends.

### Criterion 5 — 10,000 entities under 16.67 ms — **PASS**

Computed from Task 12's three raw transcripts (vertices, 10k, R2):

| run | build p50 | raster p50 |
|---|---|---|
| 1 | 5.81 | 6.63 |
| 2 | 5.67 | 6.68 |
| 3 | 5.71 | 6.75 |
| median | **5.71** | **6.68** |
| spread | 0.14 | 0.12 |

Both medians under 16.67, and so is every individual p50 (worst: 5.81 / 6.75).
Canvas at the same corpus is 12.35 / 44.32.

**Recorded honestly in the note:** vertices raster **p95 is 22.10-22.36 ms**, so
the criterion passing on medians is not a claim that every frame fits the budget.

### Criterion 6 — 50k and 500k, raster p50 better by more than the spread — **PASS at both**

Criterion's own rule: intervals `[min, max]` must not overlap, vertices lower.

**50,000:** canvas raster p50 66.95 / 66.94 / 66.85 → median 66.94, interval
[66.85, 66.95], spread 0.10. Vertices 8.63 / 8.53 / 8.22 → median 8.53, interval
[8.22, 8.63], spread 0.41. Disjoint. **Gap 66.85 − 8.63 = 58.22 ms** against a
combined spread of 0.51.

**500,000:** canvas 507.05 / 508.90 / 508.00 → median 508.00, [507.05, 508.90],
spread 1.85. Vertices 22.04 / 21.20 / 21.64 → median 21.64, [21.20, 22.04],
spread 0.84. Disjoint. **Gap 507.05 − 22.04 = 485.01 ms** against 2.69.

**No tie at 500,000, so the design's crossover fallback does not fire and there
is no crossover number to hand 3f.** The note says so explicitly rather than
leaving the fallback clause unaddressed.

### Criterion 7 — the allocation invariant on the paint path — **MEASURED, NOT CLOSED**

```
$ flutter test test/invariants/
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:00 +2: All tests passed!
```

`query_allocation_test.dart` is green inside the engine `720/720`.

The invariant exists, covers the paint path, and passes. The residue is measured
and bounded: **3 objects per flush, nothing per entity, `3 × (textOps + 1)` per
frame**. The criterion's remaining clause — "written into `CLAUDE.md`" — is not
satisfied and this plan may not satisfy it. `CLAUDE.md` is byte-untouched;
`git show --stat HEAD` confirms it is not in the commit.

The note states both outcomes: approved → passes, 8/8; refused → **fails**, and
that is the plan's result rather than a delay, quoting the design's own risk
line.

### Criterion 8 — web rows and the stated default — **PASS**

Web rows measured (Task 13, 12 blocks). `defaultRenderBackend()` reads
`=> RenderBackend.vertices;`, unconditional, and its doc comment carries both
tables plus the commensurability caveat. The justifying number is the
**17.3×-17.5× within-platform build ratio**, not the 56-60× raster figure.

---

## Step 2/3 — what the note says

`docs/superpowers/notes/2026-08-21-plan-3d-results.md`, 835 lines. Named for
2026-08-21 because that is when the Phase C sweeps ran; the note dates the runs
from the branch's own commit timestamps rather than guessing (Phase A device run
2026-08-20 before `3351232`; Phase C desktop and web 2026-08-21 between
`c678ec3` 06:08 and `25bed0d` 08:26, +0300).

It carries, in order: a verdict table of all eight criteria with the deciding
number for each; **a "what failed" section directly under it**; machine, OS,
Flutter 3.47.0 / Dart 3.13.0, engine hash `59d54a2b...` (revision `5f77625673`),
Chrome 151.0.7922.170, M3 Pro / 36 GB / macOS 26.5.1; Low Power Mode; the eight
criteria worked through with transcripts; the allocation question; the
measurements; the divergences; the coverage gaps; reproducibility; and what 3d
owes 3e and 3f.

**Everything the brief listed as a correction is in it:**

- The **web default flip** is stated as the design's own stated consequence.
- **The headline is not what justifies the flip.** Build µs/leaf 3.22 web vs
  3.43 macOS; the 1.40 ms vs 6.68 ms raster on 34% more geometry is called out
  as not a credible GPU measurement, `rasterDuration` almost certainly ending at
  command submission. **The two tables are kept separate** with the different
  drawings named (1664/37,376 vs 2111/50,120).
- **The web rows are not re-takeable** from what was committed, said plainly,
  with the four artifacts committed and each one described. **I found and stated
  something the brief did not**: `main.dart.pre-diag` is the `cp` restore point,
  **not** the run-time file — it carries the session's diagnostic prints but not
  the `runZoned` + `dart:html` capture. I verified this by diffing it against
  the committed `main.dart` and grepping it for `runZoned` / `dart:html` /
  `localStorage` (no hits). The note says the exact run-time `main.dart` is not
  preserved and points at the Task 13 report excerpt.
- **Task 10's void rationale is not repeated.** The note gives the correct
  reason instead — `CanvasDrawSink` is the fallback, `canvasCalls=19`/`24`.
- **The seam and point-shape frame-path gap**, with `draft_painter.dart:425-429`,
  `:498`, `:566`, `:588`, `:619`, and the "unobservable, not unreachable"
  distinction.
- **96.00 MiB** peak buffer, with the 10k and 50k rows beside it.
- **The ratio is not linear in entities** — a table showing 10× entities against
  2.13× leaves and 3.03× dashSpans.
- **R4a/R4b control is not demonstrated**, with the grep pattern named as the
  cause.
- **The sub-pixel divergence is exercised nowhere else**, with all four fixture
  distances to the floor.
- **The 2π `ARC`** characterised: `half·√(2/R)` ≈ 0.45 px at half 2 / R 40, under
  the dilation, no DXF reader, corpus capped below 2π.

Beyond the brief's list, the note also records: the median-mixes-runs convention
with a concrete example from each platform; web `frames` not matching within a
pair; the `runZoned` wrapper and the uncleared `localStorage`; the Task 13
transcripts being reflowed rather than verbatim; the text-ladder blank-golden
cause and its negative control; the two dpr regimes in the golden suite; R4a's
unexplained backend-dependent `command` time; the two unreachable `_emitJoin`
branches; `draft_canvas.dart:192` being untested; and a four-item list of the
"assertion narrower than the mutant's name" shape this plan hit in Tasks 2, 4, 9
and 11.

**Numbers I derived rather than copied** (all from Task 12/13 raw transcripts,
which the note cites as the source): every `[min, max]` interval and spread,
the two criterion-6 gaps, the µs/leaf and µs/call figures, the 6.63/7.85/23.48
raster ratios, the 17.3×/17.5× build ratios, the 34% geometry difference, and
the 2.13×/3.03×/2.96× growth factors.

**One measurement gap I found and recorded:** Task 13 never read Low Power Mode.
Task 12 read `0` before and after its sweep; the web sweep has no reading. The
note says so and does not claim one.

---

## Step 4 — `STATUS.md`

- Header: last-updated 2026-08-21; "verified against" now names the branch,
  worktree and `4a16b41` instead of `main`/no-worktrees.
- TL;DR: leads with Plan 3d finished and in flight, gate 7-of-8 with one
  criterion open. Plan 3c's own record kept but scoped to 3c.
- **Stale counts fixed:** widgets **152 → 238 passing + 1 skipped**; goldens
  **13 → 23 pass, 28 PNGs**; harness row now also names the web run. Engine 720
  re-verified unchanged. The skip is identified by file and cause.
- **The spike section is replaced** by "Plan 3d — the vertices sink is the
  default everywhere": what 3d added over the spike, both results-note links,
  the gate verdict, the desktop and web headline rows, the flip and the number
  that justifies it, the open `CLAUDE.md` question with both outcomes, and the
  costs and gaps.
- Branch/worktree map: adds the worktree row and **a warning that the
  git-ignored ledger must be archived to `docs/superpowers/ledgers/` on merge or
  it dies with the worktree**.
- "Resume here": no longer says "Nothing is in flight". It leads with the
  `CLAUDE.md` decision, quotes the proposed wording, states approve/refuse
  consequences, then the finish-the-branch and archive steps. Adds "What Plan 3d
  leaves open", five items.

**One change beyond the brief, flagged because it is a judgement call.** The
roadmap section was headed "Roadmap after 3c" and contained **"### Plan 3d —
fills"** and "### Plan 3e — the definition/tile picture cache" — a direct
collision, because the vertices sink took the `3d` slot. Two different "Plan 3d"s
in one status file is exactly the kind of thing that costs a later session a
wrong premise. I renumbered them to 3e/3f (matching the design document's own
"What 3d owes the plans after it") and added an explicit note saying they moved
and that older notes use the old numbers. I also folded the relevant 3d handoffs
into each: the flush contract for 3e, and the no-crossover / 96 MiB / calls-not-
entities points for 3f. **If the controller wants the roadmap left alone, this
is the change to revert** — it is confined to lines under "## Roadmap after 3d".

---

## Step 5 — commit

One commit, `2f6223e`. `superpowers:finishing-a-development-branch` **not run**.
Nothing merged, pushed or deleted.

```
 .gitignore                                         |   5 +
 STATUS.md                                          | 212 ++++--
 docs/superpowers/notes/2026-08-21-plan-3d-results.md            | 835 +++++
 docs/superpowers/notes/2026-08-21-plan-3d-web-raw/cdp_poll_generic.py |  46 +
 docs/superpowers/notes/2026-08-21-plan-3d-web-raw/main.dart.pre-diag  | 318 +
 docs/superpowers/notes/2026-08-21-plan-3d-web-raw/run_web_r2.sh |  62 +
 docs/superpowers/notes/2026-08-21-plan-3d-web-raw/web_rows.log  | 210 +
 7 files changed, 1634 insertions(+), 54 deletions(-)
```

**`.gitignore` needed one line and here is why.** The first commit attempt
silently dropped `web_rows.log` — the single most important artifact, the source
of every web figure — because the repo ignores `*.log`. `git check-ignore -v`
confirmed `.gitignore:4`. I added a narrow negation under the file's existing
"Exceptions to above rules" block:

```
# Raw measurement captures published beside a results note. `*.log` above is
# for build noise; these are the evidence a published row is checkable from.
!docs/superpowers/notes/**/*.log
```

Rather than renaming the file, so the note's reference and the artifact's real
name stay the same. **A reviewer should confirm this is wanted** — it is a
repo-wide config file, even though the rule is one path prefix wide. Renaming
`web_rows.log` to `.txt` is the alternative.

Gate re-run after the commit: engine 720, widgets 238 ~1, three packages
analyze/format clean, `git status --short` empty.

---

## Files changed

| File | Change |
|---|---|
| `docs/superpowers/notes/2026-08-21-plan-3d-results.md` | new, 835 lines — the plan's published output |
| `docs/superpowers/notes/2026-08-21-plan-3d-web-raw/web_rows.log` | new — the raw web captures |
| `docs/superpowers/notes/2026-08-21-plan-3d-web-raw/run_web_r2.sh` | new — the driver script |
| `docs/superpowers/notes/2026-08-21-plan-3d-web-raw/cdp_poll_generic.py` | new — the CDP retrieval |
| `docs/superpowers/notes/2026-08-21-plan-3d-web-raw/main.dart.pre-diag` | new — the `cp` restore point (NOT the run-time file) |
| `STATUS.md` | +158 / −54 |
| `.gitignore` | +5, one negation so the `.log` artifact is committable |

No `lib/`, no test, no `CLAUDE.md`, no `analysis_options.yaml`.

---

## Concerns

1. **Criterion 7 is genuinely open and the branch should not merge on this
   note's strength until it is answered.** This is the handoff, not a
   formality. Both outcomes are written; the controller surfaces the question.
2. **The `.gitignore` negation** (above) — a repo-wide file changed to make one
   artifact committable. Flagged for the reviewer to accept or replace with a
   rename.
3. **The roadmap renumbering** (above) — beyond the brief's literal scope, done
   because the file otherwise contains two different "Plan 3d"s. Confined and
   revertible.
4. **`main.dart.pre-diag` is not the file that produced the web rows**, contrary
   to how Task 13's report describes the artifact set ("the diagnostic
   `main.dart`"). The `runZoned` + localStorage capture exists only as the
   excerpt in the Task 13 report. Committing the artifacts improves the record
   but **does not make the web rows reproducible**, and the note says so.
5. **The web sweep has no Low Power Mode reading.** Unlikely to matter — same
   machine, ~2 h after a post-run `0` — but it is not a reading.
6. **I did not re-run any device or web measurement.** Every timing in the note
   is taken from Task 12's and Task 13's transcripts, both of which were
   independently re-checked by their reviewers (Task 12's reviewer recomputed
   all 10 medians by hand; Task 13's traced all 12 figures to real captures).
   Every derived figure in the note is arithmetic I did on those transcripts,
   and the note names the task each raw number comes from.
7. **Criterion 5 passes on medians while raster p95 is 22.10-22.36 ms.** The
   criterion is written on medians and passes cleanly, but "10,000 entities is
   inside the frame budget" is a statement about p50, not about every frame.

---

# Fix round 1 — four accuracy corrections after review

All four addressed. Gate re-run green. One commit, amending nothing; the
original `2f6223e` stands and this lands on top.

## 1 (Important) — the committed raw log held 10 of 12 blocks — **FIXED by recovery**

**Confirmed the reviewer's finding and found it is slightly worse than
described.** I enumerated the file's blocks by their own figures rather than
their headers:

```
$ awk '/^=== [0-9]/{hdr=$0} /^  build /{b=$0} /^  raster /{r=$0} /backend=/{print hdr; ...}' web_rows.log
```

Ten blocks. Missing: **10,000 vertices run 1** (6.80 / 1.40) and **10,000 canvas
run 1** (122.20 / 79.20).

**The extra finding: the file's ten headers are mis-ordinalled.** The block
headed `10000 canvas run 1 (already captured above, repeating cleanly)` carries
the Task 13 report's **run 2** figures (117.10 / 79.30), and `10000 canvas
run 2` carries the report's **run 3** (117.80 / 79.60). Appending a block headed
"run 1" without saying this would have produced an apparent duplicate and a
reader concluding the file had two run 1s.

**What I did.** Recovered both, as the review preferred over re-captioning.

- **Prepended a `### PROVENANCE` banner** to `web_rows.log`: twelve runs exist,
  ten are captures, two are appended reconstructions, and the ten captured
  headers' ordinals do not match the report's — trust the figures, not the
  header. It states that nothing published depends on the ordering, only on the
  set of three per cell.
- **Appended a `### RECOVERED BLOCKS` section** carrying both runs in the file's
  own block shape, each headed `(RECONSTRUCTED from the Task 13 report)`.

**Marked honestly, because they cannot be verbatim.** The Task 13 report's own
"Corrections" section says its transcripts are **reflowed, not verbatim** —
condensed onto fewer lines, with the `text:` and `paragraphs:` lines dropped. So
the recovered blocks carry `frames`, build p50/p95/max, raster p50/p95/max,
`screenSpaceLeafCount`, `dashSpans`, `collapsed`, `canvasCalls`, `backend`, and
(vertices) `triangles` / `drawVerticesCalls` — and the three fields that did not
survive are written `<not recovered>` rather than filled in from the
neighbouring blocks. Every 10k block shows `lineweightScale=1`, `textOps=19`,
`skippedText=0`, `newLayouts=0`, `newEvictions=0`, `live=512`, so I could have
guessed them correctly; guessing them would have made a reconstruction look like
a capture, which is the thing this whole fix exists to prevent.

**The section also names the stake:** canvas run 1's `build p50=122.20ms` is the
upper endpoint of the published interval `[117.10, 122.20]`. It does not move the
median (117.80); it does set the published spread of 5.10 ms.

**In the note**, the `web_rows.log` caption no longer says "the source of every
figure in the web table". It now says ten of twelve blocks, names the two that
are reconstructions, and points at the file's own marking. A new paragraph under
the artifact table states which published figure rests on a reconstructed number
and that the ten headers' ordinals do not match the report's.

Backup taken with `cp` to the scratchpad before editing, per the no-`git
checkout` rule.

## 2 (Important) — the renumbering claim was false in its own file — **FIXED**

Both stale references corrected:

- `:220` "makes a picture cache (Plan 3e) worth building" → **Plan 3f**, with
  "called 3e before the vertices sink took the 3d slot" so a reader following an
  older note is not confused.
- `:342` "Whole-drawing thrash → 3e's text LOD" → "the picture cache's text LOD
  (**Plan 3f**)".

**Then I swept the file as instructed** and found **a third** the review did not
list: `:527`, inside Plan 3c's own gate description — "say what it implies for
3d and 3e". Under 3c's numbering those were fills and the cache; both have moved.
Rewritten to "fills and the picture cache (**3e and 3f** under the current
numbering; 3c's own plan text called them 3d and 3e)" — naming them rather than
silently renumbering someone else's quoted plan text.

Final sweep of every `3d` / `3e` / `3f` in the file: 34 occurrences, all now
meaning the current numbering. The renumbering banner was tightened to say which
places were swept, and its "read older notes by name, not by number" caveat now
explicitly covers plan documents as well as notes.

## 3 (Minor) — commit counts and shas — **FIXED, recounted from `git log`**

```
$ git log --oneline 548fa8e..HEAD | wc -l      -> 24
$ git rev-parse --short main                   -> bb67137
$ git log --oneline main..HEAD | wc -l         -> 32
$ git log --oneline bb67137..548fa8e | wc -l   -> 8
```

So: 8 spike-and-spec commits, then 24 Plan 3d commits, 32 off `main`. `main` is
`bb67137`, not `33bdafb`. All three corrected, with the 8 + 24 = 32 breakdown
written out so the next reader does not have to re-derive it.

**A fourth staleness I found while recounting, and did not ignore.** The file
said "`main` is **29 commits ahead of `origin/main`**. **Nothing has been
pushed.**" That is now false:

```
$ git rev-parse --short origin/main      -> bb67137
$ git rev-list --count origin/main..main -> 0
```

`origin/main` and `main` are the same commit. I did not claim someone pushed —
the ref is local and could equally be a fetch artefact. The file now records what
the refs say, says it is "as of this worktree's refs", and tells the reader to
`git fetch` before acting on it. The "do not push unless explicitly asked"
instruction is untouched.

The results note's own `548fa8e..4a16b41` = 23 is correct as written (it names
the range excluding Task 15's own commit) and was left alone.

## 4 (Minor) — `canvasCalls` without a platform — **FIXED**

The criterion-4 paragraph now reads `canvasCalls=19` (10k) and `24` (50k) **on
web**, and says the desktop control table two sections earlier shows 18 and 23,
the difference being the viewport rather than a behaviour change. The apparent
self-contradiction is gone.

## Gate, re-run after all four fixes

```
$ cd packages/jet_cad_2d && dart test && dart analyze && dart format ...
00:02 +720: All tests passed!
No issues found!
Formatted 105 files (0 changed) in 0.13 seconds.

$ cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format ...
00:02 +238 ~1: All tests passed!
No issues found! (ran in 0.7s)
Formatted 44 files (0 changed) in 0.05 seconds.

$ cd apps/dev_harness_2d && flutter analyze && dart format ... lib integration_test
No issues found! (ran in 0.8s)
Formatted 3 files (0 changed) in 0.01 seconds.
```

`git status --short` before committing showed only the three intended files; no
`analysis_options.yaml`.

## Files changed in the fix round

| File | Change |
|---|---|
| `docs/superpowers/notes/2026-08-21-plan-3d-web-raw/web_rows.log` | +53: provenance banner, two recovered blocks with `<not recovered>` fields |
| `docs/superpowers/notes/2026-08-21-plan-3d-results.md` | caption corrected, recovery paragraph added, `canvasCalls` platform named |
| `STATUS.md` | three renumbering fixes, commit counts, `main` and `origin/main` shas |

No `lib/`, no test, no `CLAUDE.md`, no `analysis_options.yaml`.

## Remaining concerns after the fix round

The seven concerns in the original report stand, with two changes:

- **Concern 4 is narrower now.** The web artifacts are still not a recipe — the
  run-time `main.dart` is still unpreserved — but the *figures* are now all
  present in the repository, two of them as marked reconstructions. Nothing
  published rests on a file that dies with the worktree.
- **New, small:** two figures in `web_rows.log` are reconstructions, not
  captures, and one of them (`122.20`) is a published interval endpoint. It is
  labelled in three places (the file's banner, the recovered section, and the
  note). No median moves.

Still not run: `superpowers:finishing-a-development-branch`. Nothing merged,
pushed or deleted.

---

# Fix round 2 — the self-falsifying count

One finding. The ruling is right and my fix-round-1 numbers were wrong the
moment the commit carrying them landed: I computed 24 and 32 with `HEAD` at
`2f6223e`, then `787a914` landed inside both ranges. Writing 25 and 33 would
have made them 26 and 34. **The defect is the shape of the claim, not the
digit**, and it had already bitten twice.

## What I did — ranges everywhere, no bare counts

Both sites take the same treatment, and I took the second of the two offered
routes (ranges, no maintenance) rather than pinning to a named commit, because
a range keeps working after the next commit instead of merely staying true
about an older one.

**`STATUS.md:64-65`** — was "**24 commits**, `548fa8e..HEAD`, on top of 8
spike-and-spec commits, so **32 off `main`**":

> the plan is `548fa8e..HEAD`, sitting on the spike and spec commits at
> `bb67137..548fa8e`, so the whole branch is `main..HEAD`

**`STATUS.md:171`** (worktree table) — was "**32 commits off `main`** (8
spike/spec + 24 plan)":

> `main..HEAD` off `main` — spike and spec at `bb67137..548fa8e`, the plan at
> `548fa8e..HEAD`; not merged, not pushed

**And a standing note under the table, so the count does not grow back.** This
is the part that actually fixes the recurrence rather than the instance:

> **This file states commit ranges and never a commit count, on purpose.** A
> count is falsified by the next commit — including the commit that writes the
> count, which is how the figure here was wrong twice in one task. A range with
> named endpoints is true forever. If you want the number, ask git:
>
> ```sh
> git -C .claude/worktrees/vertices-spike rev-list --count main..HEAD
> git -C .claude/worktrees/vertices-spike rev-list --count origin/main..main   # 0 at the time of writing
> ```

The `origin/main` claim was rewritten the same way: the `0` is now presented as
a command with its answer at time of writing, plus "a `git fetch` can move it,
so re-run the command rather than trusting the parenthetical", instead of a
bare assertion.

I dropped the `8` for the spike/spec commits too. Both its endpoints are named
and immutable, so it could never have gone stale — but leaving one count in a
file that says it holds none would make a reader work out which counts are safe,
and that is the reasoning that reintroduces the bad ones.

## The sweep for other self-falsifying figures

```
$ grep -nE "[0-9]+ commits|commits ahead|commits behind" STATUS.md
(no bare commit counts remain)
```

Checked every other numeric claim in the file for the same property — is it
changed by the act of editing the file?

- **Suite counts (720, 238 ~1, 23 goldens, 28 PNGs)** — not affected by a docs
  commit. Left as counts, which is correct for them.
- **`main` at `bb67137`** — a sha, not a count, and commits on this branch do not
  move `main`. Correct form already; left alone.
- **Measurement figures, MiB, ratios** — properties of runs, not of the repo.
- **"Verified against: … at `4a16b41`"** — this one *was* quietly decaying: it
  named a commit that is no longer the tip, implying the suites had not been run
  since. Rewritten to say what is actually true and stays true: "**`4a16b41` is
  the last commit touching `lib/` or `test/`**; everything after it is docs-only,
  and the three-package gate was re-run green on each." Found by the sweep, not
  by the review.

## The results note

`**Commit range:** 548fa8e..4a16b41 (Task 15's own commit lands on top)` had the
milder version of the same bug — immutable endpoints, so not falsifiable, but
"commit" singular is now three. Rewritten to name the range and say Task 15's
docs commits land on top, with the reason stated so the next editor does not
replace it with a count.

## A process note, because it nearly cost more than the finding

**The bash cwd reset to the main repository between calls**, and my first grep
this round ran against `/Users/ahmeturel/Projects/oss/jet-cad/STATUS.md` instead
of the worktree's — which is why it reported the *old* text at lines 108 and 213
and could not find the results note at all. It was a read-only grep, so nothing
was written to the wrong tree. Verified immediately:

```
$ git -C /Users/ahmeturel/Projects/oss/jet-cad status --short
(empty)
$ git -C /Users/ahmeturel/Projects/oss/jet-cad log --oneline -1
bb67137 measure: separate dash-span cost from drawn-leaf cost
```

Main is clean and untouched at `bb67137`; both commits are on the branch. Every
command after that point uses an absolute worktree path or `git -C`. Flagging it
because the brief warned this exact confusion has already damaged this project
once, and a silent near-miss is worth the same paragraph as a hit.

## Gate, re-run after the fix

```
$ cd packages/jet_cad_2d && dart test && dart analyze && dart format ...
00:02 +720: All tests passed!
No issues found!
Formatted 105 files (0 changed) in 0.13 seconds.

$ cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format ...
00:02 +238 ~1: All tests passed!
No issues found! (ran in 0.9s)
Formatted 44 files (0 changed) in 0.05 seconds.

$ cd apps/dev_harness_2d && flutter analyze && dart format ... lib integration_test
No issues found! (ran in 0.8s)
Formatted 3 files (0 changed) in 0.01 seconds.
```

Two files changed: `STATUS.md`, and the results note's commit-range line. No
`lib/`, no test, no `CLAUDE.md`, no `analysis_options.yaml`.

Still not run: `superpowers:finishing-a-development-branch`. Nothing merged,
pushed or deleted.
