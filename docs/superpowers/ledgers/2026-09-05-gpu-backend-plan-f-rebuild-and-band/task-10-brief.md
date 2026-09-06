### Task 10: The device run, criteria 2, 5, 7, 8, 9, 12, the results note, the spec's third question, and the resume point

**Files:**
- Create: `docs/superpowers/notes/2026-09-05-plan-f-results.md`
- Create: `docs/superpowers/notes/2026-09-05-plan-f-raw/` (the run logs)
- Modify: `docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md` (open question 3)
- Modify: `STATUS.md`

- [ ] **Step 1: The run, macOS profile, Low Power Mode OFF, and say so**

```sh
cd apps/dev_harness_2d
flutter run -d macos --profile --dart-define=RUN_GPU_SPIKE=true \
  --dart-define=ENTITIES=10000 --dart-define=SPIKE_DEFS=20 \
  --dart-define=SPIKE_INSTANCES=150 --dart-define=SPIKE_FRAMES=30 \
  --dart-define=SPIKE_REPEATS=3 --dart-define=SPIKE_FILLS=true \
  --dart-define=SPIKE_TEXT=true 2>&1 | tee /tmp/plan-f-run.log
```

Copy the log to `docs/superpowers/notes/2026-09-05-plan-f-raw/gspike-run.log`.
Record from it:

- **Criterion 8, arm D** (the widget path): build and raster p50 per phase
  per repeat; the median of three per phase, against `≤ 1.2` build and
  `≤ 2.0` raster; arm C's beside it, and the C-to-D difference per phase.
  Criterion 9's p95 raster on D against `≤ 3.0`.
- **Criterion 7, per trigger**: the ten `GSPIKE D rebuild` lines per repeat;
  the median of three of `total` per trigger against **16.67 ms**, with
  `walk`, `classify`, `upload` beside it. The first `setArm(widget)` line is
  the **cold** figure, reported and not gated. `classify` against Plan E's
  27.4 ms.
- **Criterion 6 at a rebuilt scale**: the `band out` line's `instances` and
  `buffer` against 8 MB, beside the fit-scale figure.
- **Criterion 9's stale interval**: the `bandexit` line's `staleFrames` and
  `rebuilds landed`, without a threshold, with the phase's build/raster max.
- **Criterion 5**: the `GSPIKE alloc` verdict line and the fifteen class
  lines above it. `UNEVALUABLE` is recorded as such with the error text.
- `textsDropped`, if printed, is a defect.

If any arm throws its `StateError`, the run is not a run; fix and repeat.

- [ ] **Step 2: Criterion 2 and criterion 12 from the suite**

Run `flutter test test/gpu/band_sweep_test.dart test/gpu/zoom_defect_test.dart`
once more and copy the printed `BAND`, `ZOOM-OUT` and `ZOOM-IN` lines into
the raw folder as `band-and-zoom.log`. The reported band is the intersection
of the three `run=` lines; the constants' final values are whatever Task 7
left in `text_patches.dart`.

- [ ] **Step 3: Look at the window, and write down what you saw**

Run the `2d: main view -- BACKEND=residentGpu` launch entry and, separately,
the Plan F spike entry. Plan F's four checks:

1. **Arm D draws the same picture as arm C** — watch the switch between the
   two in the spike; nothing moves, nothing appears, nothing vanishes.
2. **The probe line** — during arm D's `CommandApplied` rebuild a heavy
   diagonal appears across the floor's centre; it is gone after
   `CommandUndone`, back after `CommandRedone`, and still there after
   `DocumentLoaded` and `DocumentPurged`.
3. **A band exit sharpens without a blank** — in the main view, zoom in
   past 2× in one gesture: the picture stays drawn on every frame, and
   within a few frames the arcs and dashes re-tessellate at the new scale.
   No white frame, no flicker.
4. **A pan reveals no empty edge** — in the main view, at a working zoom
   (4×–8×), pan the drawing off where it was fitted and keep going; the
   spec's *"33 logical pixels into the first pan"* defect would show as a
   hard edge past which nothing is drawn.

Record each as seen / not seen / could not judge, exactly as answered. Plan
E's fifth check (`DRAW_TEXT=false`) stays OWED unless it is looked at again
here; if it is, record it under Plan E's heading in the results note with a
pointer from Plan E's note, as the 2026-09-05 discharge did.

- [ ] **Step 4: The results note**

`docs/superpowers/notes/2026-09-05-plan-f-results.md`, following Plan E's:
what the plan's own premises measured false; the `flutter test` measurements
(the band rows, the zoom rows, the classify comparison); the device-run
conditions; the criterion-7 table per trigger; the criterion-8 C-versus-D
table; the allocation table; the window; the mutation summary; the exit
gate table with PASS / MISS / UNEVALUABLE / OWED and the number beside each.
**Open question 3's answer** (Ruling F1) gets its own short section.

- [ ] **Step 5: The spec's third question**

In the spec's **Open questions**, strike question 3 the way question 1 is
struck:

```markdown
3. ~~**The reference scale**, and the band that follows from it (criterion 2).~~
   **Answered by Plan F** (Ruling F1): the reference scale is the live
   camera's scale at the moment of the rebuild -- no constant -- and the
   band is the measured run recorded in
   [2026-09-05-plan-f-results.md](../notes/2026-09-05-plan-f-results.md).
```

- [ ] **Step 6: STATUS.md**

Plan F's state under a new `## Plan F` section in the shape of Plan E's; the
resume point rewritten: the exit gate's count, criteria 2, 5, 7, 8, 9, 12
with their numbers, the window checks in whatever state Step 3 left them,
Plan E's fifth check still OWED or discharged, and the sentence that **Plan G
(web) is next**, inheriting: the web rebuild cost (spec open question 4),
Skwasm (question 5), the web timing instrument (question 2), and whatever
criterion 7 or criterion 5 left as a MISS here.

- [ ] **Step 7: All gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add docs/superpowers/notes/2026-09-05-plan-f-results.md docs/superpowers/notes/2026-09-05-plan-f-raw docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md STATUS.md
git commit -m "docs: Plan F's results -- the band measured, the triggers timed, and what the window showed"
```

---

## Exit gate

Pre-committed. Thresholds are not moved to make a criterion pass; a miss is
recorded as a miss with its number.

1. **Criterion 1 at the band's edges**, both corpora, both collection scales:
   `band_sweep_test.dart` green at `kBandLowerScale`, `1.0`,
   `kBandUpperScale` with `referenceInk > 5000`.
2. **Criterion 2:** the reported band (the intersection of the three printed
   runs) is in the note; `hi / lo ≥ 2` is PASS, below it is the design
   failure the spec names, recorded as one. The constants' final values are
   recorded with the row that set them, or "unchanged".
3. **The five triggers**, GPU-free: each of `CommandApplied`, `CommandUndone`,
   `CommandRedone`, `DocumentLoaded`, `DocumentPurged`, a table edit, a
   `devicePixelRatio` change and a band exit causes **exactly one** rebuild;
   a pan and a resize cause none (`draft_canvas_resident_test.dart`).
4. **Criterion 7:** median-of-three `total` ≤ **16.67 ms** for every one of
   the ten trigger rows on arm D, warm; the cold first rebuild reported
   beside. `classify` reported against 27.4 ms.
5. **Criterion 5:** the probe's `perFrame ≤ kAllocFixed + kAllocPerPatch × P`
   on arm D's pan phase, with the fifteen class lines; or UNEVALUABLE with
   the VM service's refusal quoted.
6. **Criterion 8 on the widget path:** arm D `≤ 1.2` build / `≤ 2.0` raster
   p50, median of three, on the criterion-8 corpus (fills and text); the
   C-to-D difference per phase reported.
7. **Criterion 9:** arm D p95 raster `≤ 3.0` on hold, pan, zoom; the
   band-exit `staleFrames` reported without a threshold.
8. **Criterion 10:** `draft_canvas_fallback_test.dart` green — both fallbacks,
   one report, no throw, no retry.
9. **Criterion 12:** `zoom_defect_test.dart` green — tiled `uncovered > 0`
   during the zoom-out gesture and one frame after, tiled `differing > 0` on
   the zoom-in settle's first frame, resident `uncovered == 0` and agreement
   `≥ 0.995` at every frame of both.
10. **Criterion 6 at a rebuilt scale:** `buffer` at the `band out` (2.5×)
    rebuild reported against 8 MB.
11. **All fourteen mutations fire**, each with pasted output; E-F1 recorded
    as equivalent with its green run.
12. **No shader or bundle change** (`git diff --stat main..HEAD --
    packages/jet_cad_2d_flutter/shaders packages/jet_cad_2d_flutter/assets`
    is empty).
13. **A human looks at the window** and reports Plan F's four checks — and
    Plan E's fifth, if looked at.
14. Every gate green in `packages/jet_cad_2d_flutter`, `packages/jet_cad_2d`
    and `apps/dev_harness_2d`.

---

## Self-review

**Spec coverage.** The trigger table: `DocChange` rows — Task 3 (`onChange`,
every subclass); the table revision — Tasks 2 and 3 (Ruling F4); the
`devicePixelRatio` — Tasks 2 and 3 (Ruling F12); the watermark exit — Tasks 2,
3, 7 (Ruling F1, F6). *"Collection covers the whole document"* — Task 1
(Ruling F2), with the pan-needs-no-trigger and resize-needs-no-trigger claims
as Task 3's two non-trigger assertions. *"A rebuild never runs on the frame
path … lands after settle"* — Ruling F3, Task 2's first test and M-F7;
*"that staleness is measured by criterion 9"* — `bandStaleFrames`, Task 8's
band-exit phase. The fallback sentence and criterion 10 — Ruling F5, Task 4.
Invariant 1's *"new mechanism"* and criterion 5 — Ruling F8, Task 8. Criterion
2 — Task 7 and Ruling F6. Criterion 7 — Task 8's trigger phase and Task 5's
grid. Criterion 12 — Task 7 and Ruling F13. Criterion 8 and 9 on the widget
path — Task 8's arm D. The five spec mutations — M-F1..M-F5; the declared
equivalent — E-F1. Open question 3 — Ruling F1, Task 10. **Not covered,
deliberately:** web (Plan G — criterion 13, open questions 2, 4, 5); R6-2
(parked, Ruling F10); the spec's "reference scale is a parameter" wording,
which Ruling F1 answers rather than implements.

**Placeholder scan.** No "TBD", no "handle edge cases", no "similar to Task
N". Two steps name a fallback for something the repository decides rather
than the plan: Task 7's `TileRig.dispose` (tear down the measurer and index
directly if the rig has none) and Task 8's `pubspec.lock` (skip it if
ignored). Task 7's Step 4 names all three outcomes of the band measurement
and what each changes.

**Type consistency.** `ResidentCollection.collect({document, painter, live,
devicePixelRatio, pixelsPerPaperMm, lineweightScale, measurer, textStyleOf,
bandLowerScale})` is called with that shape in Tasks 1, 2. `ResidentRebuilder({document,
painter, uploader, pixelsPerPaperMm, lineweightScale, measurer, textStyleOf,
bandLowerScale, bandUpperScale})` in Tasks 2, 3. `noteFrame(camera, viewport,
dpr, tablesRevision)` in Tasks 2, 3. `ResidentUploader = Future<ResidentFramePainter?>
Function(ResidentCollection, Size)` in Tasks 2, 3, 4 (`FakeUploader.call`
matches it). `RebuildTrigger.{initial, document, tables, devicePixelRatio,
band}` in Tasks 2, 3, 8. `collectionFrameFor(live, extents, {margin})` in
Tasks 1, 7. `classifyTextPatches(data, count, texts, {devicePixelRatio,
bandLowerScale, stats})` in Tasks 1 (without `stats`), 5. `patchRegionFor(t,
m, w, h, {maxWidth, maxHeight, scratch, out})` in Task 6 both sites.
`buildFrameInfo(m, w, h, {dashScale, out})` in Task 6 both sites.
`CompositedAgreement(union, withinTwo, overEight, referenceInk, patchCount,
uncovered)` in Task 7 both sites. `measureCompositedAgreement(doc,
{collectionCamera, collectionViewport, liveCamera, size, devicePixelRatio,
pixelsPerPaperMm, measurer, mutatePatches, minTextCapPixels})` in Task 7 both
sites. `fireDocumentTrigger(doc, name, {probe})` in Task 8 both sites.
`zoomedAbout(base, centre, s)` in Tasks 2, 3, 7. `DraftCanvas.debugResidentFallbackReports`
/ `debugResetResidentFallbackReport()` in Tasks 3, 4.
