# Task 17 report — mutation re-run, the exit gate, and the results note

## What was done

**Step 1 — re-ran every mutation from Tasks 1–15 on today's merged code
(`f0ea51e`).** 51 mutations, each inside one shell call: `cp` backup, apply
(`perl`/`sed`/a small `python3` string-replace script for context-exact
edits), run the narrowest test file that should catch it, `cp` the backup
back, verify `git diff --stat` empty. **Never `git checkout`.**

Result: 47 re-confirmed KILLED exactly as their own task reported, 2
re-confirmed SURVIVED as proven equivalent mutants (T2c, T5d — the same
arguments their own reports gave still hold on today's code), 1 re-confirmed
SURVIVED as a documented allocation-gate blind spot (T9c). **One finding not
in any task's own report:** the T9b oracle-variant mutation at
`reference_query.dart:210`, which Task 9's own report recorded as SURVIVED
("no current corpus fixture puts a fill through this oracle"), is **now
KILLED** — Task 10's `_regionFill()` corpus fixture, added one task later for
an unrelated reason, closed that exact gap.

The Task 3 keying mutant needed to be **re-derived, not merely re-run**: at
Task 3's own time `FillIndex` had two callers (its own test file); today it
has six production call sites across both packages plus test call sites in
three more files, all needing to compile together for the mutation to run at
all. Re-derived and killed — and it now also breaks two unrelated pre-existing
tests (undo/redo), since `geomIndex` is not stable across those either, only
across `purge()`.

**Step 2 — the five cross-task mutants.** Three needed purpose-built probes
(not committed) because their named fixture properties are materially
different from anything an existing test checks:

1. Key the cache by `geomIndex` — KILLED (see Step 1 above; same mutant).
2. Drop dependent fills from `SetEntityGeometry`'s `touched` — KILLED, via a
   real `forEachInRect` cull probe (stronger than Task 5's own index-box read).
3. `AddRegionCommand` as two composed commands — KILLED by construction: an
   `onAfterMutate` observer sees a boundary-less fill under two separate
   `AddEntityCommand.execute()` calls, never under the real atomic command.
4. Populate the cache lazily on first draw — **SURVIVED, a genuine
   documented gap.** `debugCapacityVertices` (the allocation gate's mechanism)
   only sees the sink's own buffer, not a general-heap `Int32List` a lazy
   triangulation would allocate. Task 16's own doc comment claims this gate
   would catch such a miss; it does not. `T4c` (materialised at command time)
   is what actually proves eager population, not this gate.
5. Let the codec skip `_rebuildFills` — KILLED, but by the gate's
   `skippedFillCount == 0` assertion, not its allocation assertion, after a
   real encode/decode round trip with the mutation applied.

Full transcripts and reasoning:
[`docs/superpowers/notes/plan-3e-mutation-log.md`](../../../docs/superpowers/notes/plan-3e-mutation-log.md).

**Step 3 — the whole gate**, re-run fresh on the final, fully-restored tree:

```
packages/jet_cad_2d:       771 tests pass; analyze clean; format clean;
                            allocation invariants 5/5 pass;
                            benchmark: snap-at-dirty-threshold FAILS (Plan 2 carry, expected)
packages/jet_cad_2d_flutter: 276 pass + 1 pre-existing skip; golden 29 pass;
                            analyze clean; format clean
apps/dev_harness_2d:        analyze clean
```

`git status --porcelain` clean throughout; no `analysis_options.yaml`, no
`project.pbxproj` touched.

**Step 4 — the results note**, every failable criterion with its number:
[`docs/superpowers/notes/2026-08-22-plan-3e-results.md`](../../../docs/superpowers/notes/2026-08-22-plan-3e-results.md).
6 of 9 PASS outright, 1 recorded MEASURED/UNEVALUABLE (the contaminated
10k-under-16.67ms row), 1 recorded PARTLY SETTLED (the translucent seam —
routing rule settled, mode-2 mechanism left explicitly open on Impeller/GPU,
per Task 15's own instruction not to write "no seam was found"), the mutation
log itself PASS. **No criterion failed.** `pmset -g | grep lowpowermode`
read `1` (on) — stated in the note, and it was already `1` when Task 16 took
its device rows.

The nine plan defects and the four deferred minors are both triaged in the
note, in their own sections.

**Step 5 — `STATUS.md`** updated: TL;DR, the suite table (now 771/276+1/29,
34 PNGs, 17 fixtures), the Plan 3e roadmap section rewritten from "planned"
to "done" with the exit gate and the four cross-cutting facts, "Resume here"
repointed at Plan 3f, and "What Plan 3d leaves open" item 5 updated to say
permitted divergence 5 is live but still has no fixture. Commit **ranges**
throughout, never counts.

**Step 6 — committed** `docs/superpowers/notes/` and `STATUS.md` at `8560ba2`.

## `CLAUDE.md`

**Not touched.** Every non-negotiable this plan measured against — the
allocation invariant, draw order, the `Tolerance`/`==` split — still
describes this work. No criterion needed the rule amended to pass.

## What I did not do

**Did not archive `.superpowers/sdd/2026-08-21-jet-cad-2d-plan-3e-fills/` to
`docs/superpowers/ledgers/`.** The brief's numbered steps (1–6) don't include
this, only its general notes-for-executor section mentions it as owed since
this plan had no worktree. Left as a follow-up, and said so explicitly in
`STATUS.md`'s TL;DR ("is to be archived").

**Did not re-take any device timing.** Criterion 2's contamination can only
be closed by re-running Task 16's `flutter drive` sweep with Low Power Mode
confirmed off, which is out of this task's scope (it re-runs mutations and
writes the note, not device timings) and was called out as a `flutter drive`
run already taken and recorded, not to be repeated.

## Concerns for the reviewer

1. The five cross-task mutant probes (Step 2) are not committed anywhere —
   they existed only for the duration of one shell call each. The mutation
   log's transcripts are the only record of how they were built and what they
   showed; a reviewer who wants to re-run one will need to reconstruct it
   from the log's description, not from a file in the tree.
2. Cross-task mutant #4's SURVIVED verdict is a real, load-bearing finding —
   it contradicts what Task 16's own report implies the allocation gate
   proves. I did not go further and build a genuine VM-allocation-profile
   mechanism for the Flutter-side suite to close it in this task; that is
   recorded as an open item for 3f in the results note instead.
3. I judged "drawing unchanged, byte for byte" (criterion 8's stated
   threshold) as satisfied by the purge test's exact `Int32List` equality
   check, since nothing in this plan's briefs specifies a golden or byte
   comparison after a purge specifically. Flagging in case a stricter reading
   was intended.

## Fix round 1 (review feedback addressed)

**Important — trap 5 added to `STATUS.md`'s Plan 3f section, written out, not
linked.** The allocation-gate blind spot (cross-task mutant #4) is now the
fifth trap in "Plan 3f — the definition/tile picture cache," in the same
shape as traps 1–4: what the hazard is, why `debugCapacityVertices` cannot
see it (buffer-only, warm-up hides a first-draw allocation), and what it
would cost 3f (a lazily-populated `Picture` cache passing the gate silently).

**Divergence 5 — checked, not moved.** It already sits in "Resume here,"
immediately beside the sentence naming Plan 3f as the next plan, plus the
Plan 3e section and "What Plan 3d leaves open" item 5. A reader following
`CLAUDE.md`'s "read STATUS.md first" reaches it before reaching Plan 3f
either way. Left as is.

**Minor — mutation-log footnote added**, stating plainly that "56" counts
verification runs, not 56 distinct mutations: cross-task #1 is the same
mutation as Task 3's own keying row, re-verified at a larger surface, not a
second independent mutant. No renumbering.

Full gate re-run green: engine 771, widgets 276+1 skip, golden 29, all three
packages analyze/format clean. `CLAUDE.md` diff empty. `git status
--porcelain` showed only the two intended files before staging.
