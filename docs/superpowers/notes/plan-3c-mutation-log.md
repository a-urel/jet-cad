# Plan 3c mutation log

**Verdict: fifty-three mutants accounted for. Fifty-two killed, one not
applicable, none argued equivalent.** Thirty-three were run inside tasks 10, 11
and 12, each recorded in the plan's ledger with its killer and its observed
failure, and are summarised here rather than re-run. Twenty are the spec's own
mutant table, run in this task; **four of those survived the suite the spec
names as their killer**, and each was closed with a new test that was then
confirmed to kill it.

The twenty-first row of the spec's table — *use group 73 as ATTRIB
justification* — has no site: Plan 3c ships no DXF codec, only the JSON one.
DXF group numbers appear in this codebase solely inside doc comments
(`text_geometry.dart` names the 73/74 order to explain the bit layout), so
there is nothing to mutate. It is recorded as **not applicable**, not as
equivalent.

**Baseline before this task:** `jet_cad_2d` 717 tests, `jet_cad_2d_flutter` 152
passed / 1 skipped (including 13 goldens), both green.
**After:** `jet_cad_2d` **720**, `jet_cad_2d_flutter` **152** passed / 1
skipped, both green; `dart analyze` and `dart format` clean in both packages and
in `apps/dev_harness_2d`.

**How each mutant was applied and reverted.** A Python runner copies each
target file to a temp directory, applies the edit, runs the suite, and restores
from the copy in a `finally` block. **`git checkout --` was deliberately not
used.** Task 10 of this plan reverted a mutation with
`git checkout packages/jet_cad_2d_flutter/lib/src/draft_painter.dart` and
silently destroyed every uncommitted change in that file — a full task's work —
because `git checkout` restores HEAD, not the pre-mutation state. `git status
--short` was confirmed empty after every batch.

**Two-stage running.** Each mutant was first run against the narrowest suite
that should catch it — usually the single test file the spec's table names. Only
if that stayed green was it widened to both full suites. That is what makes a
survivor a *measured* survivor, and it is also what exposed the four rows below
where the spec's predicted killer was not the actual one.

---

## Part 1: run inside tasks 10–12, recorded, not re-run

Each was applied and reverted inside its own task, with the observed failure
text written into
`.superpowers/sdd/2026-08-17-jet-cad-2d-plan-3c-text/progress.md`.

| Task | Mutants | Survived first run | Closed with |
|---|---|---|---|
| 10 — the painter draws text | 17 | 3 | a blank-text fixture, and a `TITLE` style fixture plus a differential run on it |
| 11 — the attribute-ladder goldens | 7 | 0 | — |
| 12 — rigs and counters | 9 | 3 | three new tests (see below) |

Task 10's three survivors were one hole seen twice: **no blank text entity
anywhere in the corpus** (`labelFraction` *replaces* blanks rather than adding
them), and **no text entity on a non-STANDARD style anywhere**, which is the
Task 4/5 hole reopening one plan later in two new call sites.

Task 12's three survivors were all silently-dead *measurement* machinery, and
none of the three would have errored: a dropped `DraftCanvas.drawText` forward
prints a text-off row identical to text-on; a `resetCounters` that also cleared
the cache prints one new layout per visible string and makes a working cache
read as a failing gate; a `TextKeySink` missing the colour axis under-reports
the very number the exit gate's feasibility rests on.

---

## Part 2: the spec's mutant table, run in this task

| # | Mutant | Site | Narrow suite | Killed by | Observed |
|---|---|---|---|---|---|
| S1 | drop `widthFactor` from the local transform | `text_geometry.dart` | `text_geometry_test.dart` | `the width factor scales the already-sheared glyph, not the other way` | `Expected: within 1e-9 of 1.7676357120549897 / Actual: 0.8838178560274949` |
| S2 | read an unset override bit as "overridden" | `text_geometry.dart` | `text_geometry_test.dart` | `an unset override bit reads the style, not the scalar`, and four more | `Expected: <2.0> / Actual: <0.25>` |
| S3 | swap the oblique shear and the width-factor scale | `text_geometry.dart` | `text_geometry_test.dart` | `the width factor scales the already-sheared glyph, not the other way` | `Expected: within 1e-9 of 1.7676357120549897 / Actual: 0.8838178560274949` |
| S4 | ignore `fixedHeight` | `text_geometry.dart` | `text_geometry_test.dart` | `a style fixed height overrides the entity height` | `Expected: <50.0> / Actual: <200.0>` |
| S5 | map height to em size instead of dividing by the cap-height ratio | `text_geometry.dart` | `text_geometry_test.dart` | `height scales by cap height, not by the em size`, and four more | `Expected: within 1e-9 of 3.0 / Actual: 2.1` |
| S6 | treat 72=1 (centre) as 72=0 (left) | `text_geometry.dart` | `text_geometry_test.dart` + `extents_test.dart` | `centre justification offsets by half the advance width` | `Expected: within 1e-9 of -157.14285714285714 / Actual: 0.0` |
| S7 | honour the vertical code when 72=4 | `text_geometry.dart` | `text_geometry_test.dart` | `72=4 (middle) ignores the vertical code` | `Expected: within 1e-9 of 0.0 / Actual: -228.57142857142858` |
| S8 | swap vertical top and baseline | `text_geometry.dart` | `text_geometry_test.dart` | `top justification offsets by the ascent and bottom by the descent` | `Expected: within 1e-9 of -228.57142857142858 / Actual: 0.0` |
| **S9** | flip the sign of rotation | `text_geometry.dart` | **survived** → new test | `rotation turns counter-clockwise, and by how much` | `Expected: within 1e-9 of 1.112623835167573 / Actual: -1.112623835167573` |
| S10 | use group 73 as ATTRIB justification | — | — | **not applicable: no DXF codec exists** | — |
| S11 | drop `textStyle` from the paragraph cache key | `flutter_text_measurer.dart` | `flutter_text_measurer_test.dart` | `TextKeySink keys the same triple this cache does` | `Expected: <4> / Actual: <3>` |
| S12 | drop `argb` from the paragraph cache key | `flutter_text_measurer.dart` | `flutter_text_measurer_test.dart` + the golden | `the same string in two colours is two entries, not one`, **and** `text ladder rung 1` | `Expected: <2> / Actual: <1>` |
| S13 | lay the paragraph out at the effective em size | `flutter_text_measurer.dart` | `flutter_text_measurer_test.dart` | `a repeat request lays out nothing and allocates no metrics` | `Expected: <1> / Actual: <2>` |
| **S14** | allocate a fresh `TextMetrics` on a cache hit | `text_metrics.dart` | **survived** → watch list widened | `pickInto does not allocate in steady state, three instances deep` | `Expected: less than <0.5> / Actual: <55.533>` |
| S15 | read `scalars[1..3]` without the defensive default | `text_scalars.dart` | `schema_v3_fixture_test.dart` | `a version-3 document loads under the version-4 build` | `RangeError (length): Invalid value: Only valid value is 0: 1` |
| **S16** | skip the index-dirty notification in `SetEntityTextCommand` | `commands.dart` | **survived** → new test | `editing a text dirties one leaf; it does not rebuild the index` | `Expected: <1> / Actual: <2>` |
| S17 | counter-transform mirrored text | `draft_painter.dart` | `text_paint_test.dart` + the golden | `text inside a mirrored instance is drawn mirrored, not corrected`, **and** rungs 1–5 | `Expected: a value less than <0> / Actual: <1.6350823574063282>` |
| S18 | return `HitKind.vertex` for a text pick | `spatial_index.dart` | `pick_test.dart` | `a pointer inside a text box hits it as a fill`, and four more | `Expected: HitKind.fill / Actual: HitKind.vertex` |
| S19 | the index rebuild hard-codes `text: ''` | `spatial_index.dart` | `text_overlay_test.dart` | `an edited text has the same box in the overlay as after a rebuild` | `Expected: within 1e-9 of 3985.714285714286 / Actual: 1000.0` |
| S20 | skip `Paragraph.dispose()` on eviction | `flutter_text_measurer.dart` | `flutter_text_measurer_test.dart` | `eviction disposes the paragraph` | `Expected: true / Actual: <false>` |
| **S21** | swap the measurer mid-life without rebuilding the index | `draft_document.dart` | **survived** → new test | `doc.extents is computed through the document's own measurer` | `Expected: within 1e-9 of 8957.142857142857 / Actual: 2985.714285714286` |

### Two mutants that had to be restated to be runnable

**S13** as the spec writes it — "lay the paragraph out at the effective em
size" — has no site. `FlutterTextMeasurer._buildEntry` is handed no size at
all; `fontSize` is `kNominalTextPixels`, a constant, and the entity's height
never reaches the layout call. That is the design's central claim working, not
an oversight, and it means the literal mutant cannot be written. What was run
instead is the nearest reachable mutant with the same **observable** —
`final hit = _cache[_probe];` replaced by `final _Entry? hit = null;`, so
layout never reuses, which is precisely what a size-dependent layout would
produce. The spec says no golden or arithmetic test can see this one, and that
is true: it is caught by the layout-count assertion and by nothing else.

**S21** likewise. `DraftDocument.textMeasurer` is `final` — by explicit design,
and its doc comment says why: a reassignable field would let a caller change
what `entityBounds` returns while `_extentsCache` kept serving a box computed
with the previous measurer. So "swap the measurer mid-life" cannot be spelled.
The reachable mutant with the same observable is *the extents walk ignoring the
field it is given*: `measurer: textMeasurer` replaced by
`measurer: MetricModelMeasurer()`. It survived, which is the finding below.

### The four the spec mispredicted

These are the rows worth reading. In each, the spec's table names a killer, and
the killer did not fire.

**S9 — flip the sign of rotation.** The spec says the killer is an arithmetic
expectation. `text_geometry_test.dart` has a test named *rotation is not
symmetric about its sign* which asserts `plus.b == -minus.b` — a property that
holds just as well when **both** are negated. The whole of the engine's text
geometry file walked past a global sign flip; it was caught two packages away
by `pick_test.dart`'s oriented-box test and by golden rung 3. The arithmetic
expectation the spec asked for now exists and pins `t.b == sin(0.4) * 200/70`,
sign included.

**S14 — a fresh `TextMetrics` on a cache hit.** The spec names
`query_allocation_test` — this project's standing allocation gate — and that
file stayed **green**. Its pick-path watch list was `{Vector2, _Record}`, and a
per-candidate `TextMetrics` was invisible to it *for exactly the reason the file
already documents about `_Record`*: "records are cheap to write and exactly the
kind of object that gets built inside a helper without anyone thinking of it as
an allocation". The same sentence was true of `TextMetrics` one plan later.
With `TextMetrics` added to the watch list the gate reads **55.533 instances
per call against a budget of 0.5** — the harness was blind to fifty-five
allocations per pick.

**S16 — drop the dirty notification from `SetEntityTextCommand`.** It survived
both full suites, and it is **not** a wrong-answer defect: `_reconcile` treats
an empty `touched` set as "cannot pin down what changed" and falls back to
`rebuildAll()`, so the overlay-equals-rebuild test the spec names still passes —
the box comes out right by the most expensive route available. It is a **cost**
defect: a full index rebuild on every keystroke, on the path an editing session
spends all its time in. The new test asserts the route (`rebuildCount` does not
move, and the leaf lands in the dirty overlay) rather than the answer.

**S21 — the extents walk ignoring the document's measurer.** It survived
because every text case in `extents_test.dart` calls `entityBounds` with an
explicit measurer argument. Those prove the *function* reads its parameter and
prove nothing whatever about the *field*. The spec calls for a
measurer-dependence test and there was none. The new one builds the same
document under `MetricModelMeasurer(advanceRatio: 0.30)` and
`MetricModelMeasurer(advanceRatio: 0.90)` and asserts the extents widths stand
in exactly that ratio — two measurers differing only in their **ratios**, not in
their kind, because a fixture whose second measurer were `InsertionPointMeasurer`
would pass against a mutant that hard-codes any real model.

### What the four have in common

Three of the four survivors are the same failure the rest of this plan kept
finding: **a test that names the right property against a fixture that cannot
tell right from wrong.** S9's fixture is symmetric under the mutation. S21's
fixture passes the answer in as an argument. S14's harness watches a list that
the new object is not on. Only S16 is different, and it is different in a way
worth naming: it is the one mutant in the table whose defect is invisible to
*any* assertion about output, because the output is correct.

---

## Reproducing

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-3c

# baseline
(cd packages/jet_cad_2d        && dart test)      # 720 pass
(cd packages/jet_cad_2d_flutter && flutter test)  # 152 pass, 1 skip

# the four that needed new tests, narrowest suite each
(cd packages/jet_cad_2d && dart test \
  test/document/text_geometry_test.dart \
  test/invariants/query_allocation_test.dart \
  test/index/text_overlay_test.dart \
  test/document/extents_test.dart)

# the goldens that kill S12 and S17
(cd packages/jet_cad_2d_flutter && flutter test --tags golden)
```

The runner used for the mutants themselves is
`scratchpad/mutate13.py` (session-local, not committed). Its shape is the part
worth keeping:

```python
shutil.copy(path, backup)          # NOT `git checkout` -- see the header above
try:
    apply_edit(path)
    narrow = run(narrowest_suite)  # the file the spec's table names
    if not narrow.failed:
        run(full_engine_suite)     # widen only after the narrow one is green
        run(full_widget_suite)
finally:
    shutil.copy(backup, path)
```

Every mutant above is a one- or two-expression edit; the exact `old` → `new`
strings live in that script, and the site column here names the file for each.
