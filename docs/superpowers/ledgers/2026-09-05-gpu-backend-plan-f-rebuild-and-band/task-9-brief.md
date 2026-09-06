### Task 9: Mutation testing

**Files:**
- Create: `docs/superpowers/notes/plan-f-mutation-log.md`

**Interfaces:**
- Consumes: every test file this plan created. No production code changes
  land in this task; a mutation that survives is a plan defect, ledgered
  and fixed in its own commit before the log records the kill.

- [ ] **Step 1: The procedure, for every row**

```sh
cp <file> /tmp/mut.bak            # never `git checkout --` to restore
# apply the edit below, by hand
cd packages/jet_cad_2d_flutter && flutter test <witness file> 2>&1 | tail -40
cp /tmp/mut.bak <file>
git status --short                # must be clean before the next row
```

Paste the red run's last lines (the failing `expect` and its `reason`) into
the log, verbatim, with the exit code.

- [ ] **Step 2: The rows**

| id | spec mutation / plan mutation | file, edit | witness | expected red line |
|---|---|---|---|---|
| M-F1 | *ignore the table revision counter* | `resident_rebuilder.dart`: delete the `tablesRevision != c.tablesRevision` branch | `resident_rebuilder_test.dart`, `draft_canvas_resident_test.dart` | `pending` null where `tables` expected; `landed` 1 where 2 |
| M-F2 | *ignore the `devicePixelRatio` trigger* | `resident_rebuilder.dart`: delete the `dpr != c.devicePixelRatio` branch | same two files | `pending` null; `collection.devicePixelRatio` 1.0 where 2.0 |
| M-F3 | *read the watermark band against the reference scale instead of the live scale* | `resident_rebuilder.dart`, `inBand`: `final ratio = c.collectionCamera.scale / c.collectionCamera.scale;` | `resident_rebuilder_test.dart` (band), `draft_canvas_resident_test.dart` (band) | `pending` null where `band` expected |
| M-F4 | *leave the resident text list stale across a rebuild* | `resident_rebuilder.dart`, `rebuildNow`: after `collect`, `final next = ResidentCollection(...)` copy with `texts: _collection?.texts ?? next.texts` (spell all eleven fields) | `resident_rebuilder_test.dart` (edited label) | `texts` still contains `'COVERED'`, lacks `'EDITED'` |
| M-F5 | *cull collection to the live viewport → panning reveals empty buffer* | `collection_frame.dart`: `return CollectionFrame(live, const Size(800, 600));` as the first line | `resident_collection_test.dart`, `zoom_defect_test.dart` (resident zoom-out), `band_sweep_test.dart` | `instanceCount` smaller at the corner; `uncovered` nonzero at a zoom-out step |
| M-F6 | plan: coalescing | `resident_rebuilder.dart`, `markDirty`: remove the `_inFlightTrigger != null \|\| _scheduled` early return | `resident_rebuilder_test.dart` (three marks) | `rebuilds` 4 where 2 |
| M-F7 | plan: the rebuild is off the frame path | `resident_rebuilder.dart`, `noteFrame`: replace `markDirty(RebuildTrigger.initial)` with a direct `unawaited(rebuildNow(camera, viewport, dpr, RebuildTrigger.initial))` | `resident_rebuilder_test.dart` (first frame) | `rebuilds` 1 where 0 before the pump |
| M-F8 | criterion 10: once | `draft_canvas.dart`, `_reportResidentFallback`: delete `if (_residentFallbackReported) return;` | `draft_canvas_fallback_test.dart` | `reports` length 2 where 1 |
| M-F9 | plan: the grid's overflow list | `text_patches.dart`, `classifyTextPatches`: delete the `for (final i in overflow)` loop | `classify_grid_test.dart` (generated corpus) | a patch's `instanceCount` differs from the brute force |
| M-F10 | plan: the grid's cell range | `text_patches.dart`, `cellX`/`cellY`: `.floor()` → `.round()` | `classify_grid_test.dart` (generated corpus) | a patch's sub-buffer differs from the brute force |
| M-F11 | plan: viewport rejection | `text_compositor.dart`: invert the four-way `\|\|` test (`!(...)`) | `text_compositor_viewport_test.dart`, `text_order_test.dart` | `drawParagraph` count 2 → wrong two; composited agreement below 0.995 |
| M-F12 | plan: the region pool is written | `text_patches.dart`, `patchRegionFor`: `if (out == null) return PatchRegion(...)` → always `return PatchRegion(x0, y0, w, h);` | `text_patches_test.dart` (`out`) | `identical(onScreen, out)` false |
| M-F13 | plan: a mark during flight | `resident_rebuilder.dart`, `_run`: delete the trailing `if (!_disposed && _pending != null && !_uploadFailed) _schedule();` | `resident_rebuilder_test.dart` (in flight) | `rebuilds` 2 where 3 |
| M-F14 | plan: the frame's uniform block | `gpu_draw_backend.dart`, `buildFrameInfo`: ignore `out` (`final data = ByteData(80);`) | `frame_info_test.dart` (`out`) | `identical(written, out)` false |
| E-F1 | *rebuild only when `touched` is non-empty* — **declared equivalent** | `draft_canvas.dart`, `onChange`: `if (change.touched.isNotEmpty \|\| change is DocumentLoaded \|\| change is DocumentPurged) resident?.markDirty(...)` | `draft_canvas_resident_test.dart` (every DocChange) | **stays green**, and the log says why: `spatial_index.dart:2283-2287` — an empty `touched` on a command is *"defensive, not currently reachable"*, and load and purge are routed on type |

Fire E-F1 too, and record the green run: an equivalent mutation is recorded,
not skipped (spec, *"Removed as equivalent, and recorded rather than
deleted"*).

- [ ] **Step 3: The log**

`docs/superpowers/notes/plan-f-mutation-log.md`, in `plan-e-mutation-log.md`'s
shape: one section per row with the edit as a diff hunk, the command, the
pasted tail, the restore, and a summary table (`fired / killed / survived /
equivalent`). A survivor is a plan defect: fix the test or the code in its
own commit, re-fire, and log both runs.

- [ ] **Step 4: Gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add docs/superpowers/notes/plan-f-mutation-log.md
git commit -m "test(gpu): Plan F mutation log -- fourteen fired, one declared equivalent"
```

---

