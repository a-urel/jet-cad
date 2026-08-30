### Task 11: The device run, the budget, and the exit gate

**Files:**
- Create: `docs/superpowers/notes/2026-08-30-plan-b-results.md`
- Modify: `STATUS.md`

**Interfaces:**
- Consumes: everything.
- Produces: the results note of record and the scored exit gate.

- [ ] **Step 1: Run the harness on a device**

```bash
cd apps/dev_harness_2d
flutter run -d macos --profile \
  --dart-define=RUN_GPU_SPIKE=true \
  --dart-define=ENTITIES=10000 \
  --dart-define=SPIKE_DEFS=20 \
  --dart-define=SPIKE_INSTANCES=150 \
  --dart-define=SPIKE_FRAMES=30 \
  --dart-define=SPIKE_REPEATS=3
```

**Read macOS Low Power Mode before starting and record its state**, per the
standing rule in `STATUS.md` — every `flutter drive` note in this repo that
omitted it is contaminated.

**Look at the window.** Plan 3h's session established looking at the running
window as this project's third instrument, and it is the only one that found
any of that session's four defects. Specifically: are corners filled? Is the
circle notched at its start angle? Is the dot square? Does anything thicken as
you zoom in?

Record what you saw in the note, including "I could not tell" where that is the
honest answer.

- [ ] **Step 2: Price the buffer**

The harness prints `buffer=<N> MB`. Plan A measured 2.06 MB at 59,875
strokes-only segments. Record the new figure and the instance count, and state
the ratio. **The spec's budget is ≤ 8 MB for all kinds plus the resident text
list.** If joins push it past 8 MB, that is a **miss**, recorded with its
number — the threshold is pre-committed and does not move.

Also record how many of the joins were collinear degenerates (Ruling B4's
stated cost). If the harness does not count them, add a counter to
`GeometryCollector` behind a `debug` prefix and say that you did.

- [ ] **Step 3: Score the exit gate**

Pre-committed. A miss is recorded as a miss with its number.

1. **The resident arm draws the reference drawing**: differing pixels below 1%
   of reference ink on Task 9's corpus, with reference ink above the vacuity
   floor. Coverage-only — the per-channel half of spec criterion 1 is not
   measured by this instrument and the note says so.
2. **Emission order holds within an entity**: join before segment, seam last,
   asserted on an open run, a closed run and a flattened circle.
3. **The seam join is load-bearing**: the closed circle inks more than the
   equivalent open arc.
4. **Half-width is invariant under the transform**: the expander's 5x test,
   and the same corpus compared at 3x in Task 10 Step 2.
5. **A sub-pixel stroke fades and keeps its pixel**; a stroke at or above one
   device pixel does not fade; a zero lineweight keeps full alpha.
6. **`point()` is its own kind** and is a square at every scale.
7. **`skippedOps` counts exactly `fillPolygon`, `fillCircle` and `text`.**
8. **Resident geometry ≤ 8 MB** at 10,000 entities.
9. **The bundle carries an OpenGL ES 100 stage**, verified by decode rather
   than by `strings`.
10. **All ten pre-committed mutants are accounted for**: each killed with a
    transcript, or surviving with a derivation.
11. **The device run happened and the window was looked at**, with what was
    seen written down.

- [ ] **Step 4: Write the results note**

`docs/superpowers/notes/2026-08-30-plan-b-results.md`. It must carry:

- the gate, scored, criterion by criterion, misses included;
- the buffer figure, the instance count and the collinear-join count;
- **Ruling B2's consequence stated plainly**: caps are butt caps, Plan B emits
  no cap geometry, and spec criterion 8's "caps" term is therefore satisfied
  vacuously;
- **Ruling B3's consequence**: the resident arm is hard-edged, and the spec's
  budget discussion assumed antialiasing would be consuming headroom by now;
- what was **not** measured: no GPU comparison in the suite (the pixel
  differential is a CPU rasterisation of both arms), no per-channel colour
  comparison, no web run, no text, no fills, no dashes;
- the new shader bundle's SHA-256.

- [ ] **Step 5: Update `STATUS.md`**

Header, TL;DR, the branch map and "Resume here". State commit ranges, **never a
commit count** — `STATUS.md` says why, and says it was wrong twice in one task
for exactly that reason.

- [ ] **Step 6: Final gate and commit**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
cd ../jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
cd ../../apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
cd ../.. && git status --short
git add docs STATUS.md
git commit -m "docs: Plan B's results, its gate, and where the project stands"
```

`git status --short` must show no `analysis_options.yaml`. If it does,
`git checkout --` all three before committing.

---

## Self-review

**Spec coverage.** Of the spec's fourteen mutations, this plan closes four —
the seam join, `_coveredArgb` on strokes, `point()` as its own kind, and joins
as collector geometry — plus the buffer-partition mutation reduced to this
plan's single buffer (M-B9). It establishes the instrument spec criterion 1
needs and prices the spec's 8 MB budget for the first time with joins in it.
Criteria 6-9, 11, 12 and 13 remain later plans'; criteria 3, 4 and 10 were
Plan A's and are untouched here.

**Placeholders.** None. Every code step carries the code. Two steps
deliberately end in a judgement rather than a value — Task 9 Step 4's first
failure and Task 10 Step 2's M-B10 — and both state what to report in each
case rather than what number to reach.

**Type consistency.** `StrokeFieldOffset` becomes `InstanceFieldOffset` in
Task 2 and every later reference uses the new name.
`kStrokeVertexLayout` becomes `kInstanceVertexLayout` in the same task.
`kFloatsPerInstance` is 12 from Task 2 on; `kFloatsPerCorner` is new and is 6.
`writeStroke`'s signature is unchanged; `writeJoin` and `writePoint` are new.
`GeometryCollector` gains `_coveredArgb`, `_beginRun`, `_runTo`, `_endRun`,
`_emitJoin`, `_flatten`, `_flattenSteps`, `kFlattenTolerance` and
`kMaxFlattenSegments`. `expandInstances` returns `ExpandedTriangles`;
`measureResidentAgreement` returns `ResidentAgreement`.

**Known risk, stated rather than discovered.** Task 9's
`measureResidentAgreement` assumes `TriangleRasterizer.observe` takes
`(Float32List positions, Int32List colors)` and that `inked(x, y)` is a
boolean coverage test. Both are read from the file's current signatures. Step 1
of that task exists to check them before the code is written, and the step says
in as many words to follow the file over this plan's sample.
