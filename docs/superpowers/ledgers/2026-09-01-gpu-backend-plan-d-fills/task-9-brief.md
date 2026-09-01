### Task 9: The device run, the results note, and everything that says what this backend does

**Files:**
- Modify: `apps/dev_harness_2d/lib/gpu_arm.dart`
- Create: `docs/superpowers/notes/2026-09-01-plan-d-results.md`
- Modify: `STATUS.md`

- [ ] **Step 1: The harness corpus grows fills**

The spike arm draws strokes only. Add filled regions in the same proportion
the spec's corpus implies, so the window shows a drawing with rooms in it and
the buffer measurement includes them. Keep the existing
`--dart-define` knobs; add `SPIKE_FILLS` with a default that leaves today's
numbers reproducible when it is zero.

- [ ] **Step 2: Measure the buffer**

At 10,000 entities, report: instance count by kind, total bytes, and the
figure against the **8 MB** budget. Plan C measured 6.41 MB at 105,076
instances; the delta this plan adds is the deliverable of this step. **If it
exceeds 8 MB, record a miss with its number** — the threshold does not move.

- [ ] **Step 3: Run the harness on macOS, in profile, with Low Power Mode OFF**

```sh
cd apps/dev_harness_2d
flutter run -d macos --profile --dart-define=RUN_GPU_SPIKE=true \
  --dart-define=ENTITIES=10000 --dart-define=SPIKE_DEFS=20 \
  --dart-define=SPIKE_INSTANCES=150 --dart-define=SPIKE_FRAMES=30 \
  --dart-define=SPIKE_REPEATS=3
```

**Confirm Low Power Mode is off before the run and say so in the note.** Plan
C's device run was contaminated by it and every timing in that note carries
the caveat.

- [ ] **Step 4: Look at the window, and write down what you saw**

Plan D's five checks:

1. a filled region is **filled**, not outlined and hollow;
2. the higher-handle stroke crossing it is **visible over** the fill, not
   hidden under it;
3. a filled circle's fill reaches exactly to its own boundary stroke at every
   zoom — no rim of background between them, no fill spilling past;
4. a fill on a hairline layer is **not faded**;
5. a translucent fill shows what is under it.

**Plan B's four and Plan C's five are still owed** and one run discharges all
fourteen. List them in the note as discharged or still owed, per what was
actually seen.

- [ ] **Step 5: Write the results note**

`docs/superpowers/notes/2026-09-01-plan-d-results.md`, following Plan C's
note: the criterion table with PASS/MISS per row and the measured number
beside each, the mutation summary, what the plan's own premises measured
false, and the device-run conditions. **A miss is recorded as a miss.**

- [ ] **Step 6: Rewrite STATUS.md's head**

Plan D's state, the resume point, and the criterion-11 debt in whatever state
Step 4 left it.

- [ ] **Step 7: Both gates and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git commit -m "docs: Plan D's results, and what the window showed"
```

---

## Exit gate

Pre-committed. Thresholds are not moved to make a criterion pass; a miss is
recorded as a miss with its number.

1. **Record-level differential:** for the fill corpus, the collector's
   instance stream and `VerticesDrawSink`'s triangle stream agree instance for
   instance on `kind`, `argb` and all three points. **Exact, not a budget.**
2. **Pixel differential, colour:** per-channel difference ≤ 2 on ≥ 99.5% of
   the union, ≤ 8 on the rest, on the fill corpus and on Plan B's stroke
   corpus both.
3. **Anti-vacuity:** `referenceInk > 5000` on every measured corpus, and the
   colour instrument's own control arm (`debugTintResident`) reads below the
   gate.
4. **Spec criterion 4:** a kind-sorted buffer changes more than 200 pixels
   against the walk-ordered one, and the resident arm matches the reference in
   walk order and **fails to** under the permutation.
5. **`skippedOps` counts text alone** on the fill corpus.
6. **Resident geometry ≤ 8 MB** at 10,000 entities with fills, measured.
7. **All twelve mutations fire**, each with pasted output; survivors declared
   with a reason.
8. **A human looks at the window** and reports Plan D's five checks — and
   Plan B's four and Plan C's five, still owed.
9. Every gate green in `packages/jet_cad_2d_flutter`, `packages/jet_cad_2d`
   and `apps/dev_harness_2d`.

---

## Self-review

**Spec coverage.** The spec's "Fills" section is Tasks 2, 3 and 5;
`fillPolygon` pre-triangulated (Task 2), `fillCircle` fanned at its outline's
step count (Task 3). "One buffer, one kind tag, one draw call" is Ruling D1
and Task 7. The `_coveredArgb` exclusion is Ruling D3, Tasks 2, 3 and M-D1/2.
Criterion 4 is Task 7. Criterion 1's per-channel clause is Task 6 — the spec
requirement no plan had gated. Criterion 6's 8 MB is Task 9. **Not covered by
this plan, deliberately:** text (Plan E), the rebuild triggers and the
watermark (Plan F), web (Plan G), and the `DraftCanvas` widget path, which
still renders `residentGpu` as `vertices` and needs Plan F's triggers.

**Placeholder scan.** No "TBD", no "handle edge cases", no "similar to Task
N". Two steps name work whose exact shape depends on a measurement rather than
on a decision — Task 9's harness fill proportion and Task 4's fallback to
`putTriangles` if `AddRegionCommand` does not materialise a triangulation —
and both state the test that decides it.

**Type consistency.** `writeFill` is declared once (Task 1) and called with
the same six coordinates and one `argb` in Tasks 2 and 3. `kKindFill` is `3`
everywhere. `measureResidentColor` and `ResidentColorAgreement` are declared
in Task 6 and used with the same signature in Task 7. `ResolvedStyle` carries
all four required named arguments in every literal in this document.
