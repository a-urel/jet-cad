### Task 9: The device run, criterion 11, the results note, and the resume point

**Files:**
- Create: `docs/superpowers/notes/2026-09-04-plan-e-results.md`
- Modify: `STATUS.md`

- [ ] **Step 1: Two runs, macOS profile, Low Power Mode OFF, and say so**

```sh
cd apps/dev_harness_2d
flutter run -d macos --profile --dart-define=RUN_GPU_SPIKE=true \
  --dart-define=ENTITIES=10000 --dart-define=SPIKE_DEFS=20 \
  --dart-define=SPIKE_INSTANCES=150 --dart-define=SPIKE_FRAMES=30 \
  --dart-define=SPIKE_REPEATS=3 --dart-define=SPIKE_FILLS=true \
  --dart-define=SPIKE_TEXT=true
# then the same with --dart-define=DRAW_TEXT=false
```

Record from the first run: `textOps`, `patches`, `subBuffer`, `patchTargets`,
`classify` ms, and per phase `patches rendered / clipped / offscreen`. From
both: arm C's build and raster p50 per phase, per repeat; the **median of
three** per phase; the **difference** between the runs, build and raster
summed, per phase. **Criterion 11 is the hold and pan phases' difference ≤
0.5 ms.** Zoom is reported beside it. If `patches` is `0`, the run measures
nothing — stop and fix `_addPatchedLabels` before recording a number.

- [ ] **Step 2: Criterion 6 and criterion 7's share**

`buffer + subBuffer` against 8 MB (Plan D measured 6.51 MB without text);
`classify` ms against the 16.67 ms rebuild budget (Plan C's rebuild is
already a recorded MISS at 115 ms; this adds to that number and is recorded
as its share, not as a pass).

- [ ] **Step 3: Look at the window, and write down what you saw**

Plan E's five checks:

1. labels are **drawn**, right way up, at the size and place arm A draws them;
2. a `ROOM n` label's crossing stroke is visible **over** its glyphs — and
   the same stroke is **not** drawn over the empty space beside the glyphs
   any differently from arm A;
3. panning keeps the patched stroke over the label with no lag and no seam
   at the label's box edge;
4. zooming in to 2× and out to 0.5× keeps the label sharp (it is a paragraph,
   not a bitmap) and the stroke over it at every step;
5. `DRAW_TEXT=false` shows the same drawing with no labels and no patches.

Plan B's four, Plan C's five and Plan D's five remain formally OWED (STATUS
"Resume here"); one run can discharge all nineteen, and the note lists each
as discharged or still owed, per what was actually seen.

- [ ] **Step 4: The results note**

`docs/superpowers/notes/2026-09-04-plan-e-results.md`, following Plan D's:
the criterion table with PASS/MISS and the number beside each, the mutation
summary, what the plan's own premises measured false, the device-run
conditions, the two-run difference table for criterion 11.

- [ ] **Step 5: STATUS.md**

Plan E's state, the resume point, the nineteen window checks in whatever
state Step 3 left them, and the sentence that Plan F is next (rebuild
triggers, the band, `DraftCanvas`'s `residentGpu` path — which now has a
`paint` to call).

- [ ] **Step 6: All gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git commit -m "docs: Plan E's results, criterion 11's first number, and what the window showed"
```

---

## Exit gate

Pre-committed. Thresholds are not moved to make a criterion pass; a miss is
recorded as a miss with its number.

1. **Composited differential, text corpus:** per-channel ≤ 2 on ≥ 99.5% of
   the union, ≤ 8 on the rest, at all four band scales `0.5, 0.8, 1.25, 2.0`,
   with `referenceInk > 5000` and `patchCount ≥ 1` on every row.
2. **The order gate:** with no patches the same corpus disagrees on > 200
   pixels by more than 8 and falls below 99.5%; with patches it passes.
3. **Exactly the covered labels are patches:** `patchCount == 2` on the
   fixture (COVERED, GRAZED), never 4.
4. **`skippedOps == 0`** on every collector built with a measurer, on every
   corpus in the suite.
5. **Criterion 11:** hold + pan text-pass difference ≤ 0.5 ms p50, arm C,
   median of three; `patches ≥ 8` on the corpus; the patch count, the text-op
   count, `classify` ms, `subBuffer` and `patchTargets` MB all in the note.
6. **Criterion 6:** `buffer + subBuffer ≤ 8 MB` at 10,000 entities with
   fills and text, measured.
7. **All fourteen mutations fire**, each with pasted output; survivors
   declared with a reason.
8. **No shader or bundle change** in the branch's diff (`git diff --stat
   main..HEAD -- packages/jet_cad_2d_flutter/shaders
   packages/jet_cad_2d_flutter/assets` is empty).
9. **A human looks at the window** and reports Plan E's five checks — and
   the fourteen still owed.
10. Every gate green in `packages/jet_cad_2d_flutter`, `packages/jet_cad_2d`
    and `apps/dev_harness_2d`.

---

## Self-review

**Spec coverage.** Revision 5's text section: the resident text list is Task
1 (six floats flat, string, style, `resolved.argb`, instance index, the
four-corner padded box — Ruling E9 corrects the pad's scale and the spec);
classification, per-kind reach, the miter bound, the band floor, the
sub-buffer as a by-product, "candidate not ink" — Task 2; the per-frame
arrangement — main pass, patch passes anchored at the target's origin with a
region-sized `FrameInfo`, the compositor's `saveLayer` in the outer frame,
one paragraph helper with the baseline flip, `srcATop` — Tasks 4 and 6; "no
GPU resource allocated per frame", the target sized at the ceiling and
reused, the named per-patch exception — Task 6 and Global Constraints; the
cost statement — Task 7's `classify` ms and criterion 11's two-run
difference; criterion 11 as rewritten — Ruling E10, Task 7, Task 9; the
corpus's six text items — Task 3 (five) and Task 5 (the four scales); the
seven text mutations in the spec's list — M-E1..M-E7; the budget row — Task
6's `byteLength` and Task 9. **Not covered, deliberately:** the band's real
value and the watermark rebuild (Plan F, Ruling E3), `DraftCanvas`'s
`residentGpu` path (Plan F, Ruling E7), web (Plan G — but `asImage()`'s
ordering on web is handled in Task 6 so Plan G inherits no trap), an
allocation instrument for the frame path (spec invariant 1's "new mechanism",
which the spec assigns to the plan that wires the widget — Plan F).

**Placeholder scan.** No "TBD", no "handle edge cases", no "similar to Task
N". Three steps name work whose exact shape depends on what the package
actually exposes rather than on a decision, and each names the fallback:
Task 3's record/instance accessors (`slotOf` + `*At` getters), Task 3's
`lineweightOverride` (rebuild the document if there is no modify command),
Task 5's white-ground question (draw white on both arms). Task 6's
`asImage()` placement is decided (after `submit()`), with the reason.

**Type consistency.** `ResidentTextRecord` has the fourteen fields of the
restatement in every task that constructs one (Tasks 1, 2, 4). `TextPatch`
is `(textIndex, instances, instanceCount)` in Tasks 2, 5, 6, 7.
`classifyTextPatches(data, count, texts, {devicePixelRatio, bandLowerScale})`
is called with that shape in Tasks 2, 5, 7. `patchRegionFor(t, m, w, h,
{maxWidth, maxHeight})` in Tasks 4, 5, 6. `PatchImage(textIndex, image, src,
dst, layerBounds)` in Tasks 4, 5, 6. `TextCompositor.paint(canvas, {main,
viewport, collectionToLogical, texts, patches})` in Tasks 4, 5, 6.
`ResidentGeometry.create(instances, count, {texts, patches, devicePixelRatio,
maxPatchWidth, maxPatchHeight})` in Tasks 6, 7. `GpuDrawBackend(geometry,
collectionCamera, {measurer, textStyleOf})` and `paint(canvas, camera,
viewport, dpr)` in Tasks 6, 7. `ResolvedStyle` spells four named arguments
in every literal. `TextStyleRecord` is spelled as `canvas_draw_sink_test.dart`
spells it.
