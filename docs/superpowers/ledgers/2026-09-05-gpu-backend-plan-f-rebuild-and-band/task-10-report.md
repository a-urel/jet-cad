# Task 10 report — the device run, the results note, open question 3, the resume point

**Status: DONE_WITH_CONCERNS.** Everything the brief asks for is done and
committed. The concerns are results, not omissions: criterion 5 came back
UNEVALUABLE (diagnosed, one-file fix, outside this task's file list), five
criteria are measured MISSes, and the window is OWED because no human looked.

**Commit:** `10eaae7` — `docs: Plan F's results -- the band measured, the
triggers timed, and what the window still owes`, on `plan-f/rebuild-and-band`,
base `a1ef1fe`. Working tree clean after the commit.

---

## 1. Run conditions

- **Low Power Mode OFF**, recorded verbatim: `pmset -g | grep -i lowpower` →
  `  lowpowermode         0`
- `flutter devices` listed
  `macOS (desktop) • macos • darwin-arm64 • macOS 26.5.1 25F80 darwin-arm64`
- Tree: worktree `.worktrees/plan-f-rebuild-and-band`, branch
  `plan-f/rebuild-and-band` at `a1ef1fe`.
- Renderer: `Using the Impeller rendering backend (MetalSDF)` (raw log line 20);
  window `1400x900` (line 21).
- Command: exactly the brief's, `SPIKE_FRAMES=30` (kept at 30 per Task 8 —
  at 60 the zoom phase reaches 3.28× and a band rebuild lands inside the
  measured phase).
- **One run. No retry, no failure.** Transcript ends
  `GSPIKE done: 36 phase reports above.` (line 180). **No `GSPIKE RUN FAILED`,
  no `StateError` from any phase, and `textsDropped` appears nowhere** — the
  grep is empty, so the harness's own defect signal did not fire.
- `flutter run` was backgrounded, polled for the `GSPIKE done` marker under a
  20-minute cap, then killed with
  `pkill -f "flutter.*run.*macos"; pkill -f dev_harness_2d`. **`pgrep -fl
  dev_harness_2d` returns no match** and neither does the `flutter run` pattern
  — nothing left running.
- Step 2 re-run: `flutter test test/gpu/band_sweep_test.dart
  test/gpu/zoom_defect_test.dart` → **9 of 9 green**, rows copied to
  `band-and-zoom.log`.

Raw logs committed at `docs/superpowers/notes/2026-09-05-plan-f-raw/` —
`gspike-run.log` (181 lines) and `band-and-zoom.log` (106 lines). **Every
figure in the note cites a line of one of these two files**; nothing was
synthesized, and every median in the note was independently re-derived from the
log by script before the note was committed (all matched).

---

## 2. The exit-gate table as recorded

| # | gate | verdict |
|---|---|---|
| 1 | Criterion 1 at the band's edges | **PASS as amended by Ruling F6-b** — suite green. The literal pre-committed form is **false** and is recorded as such in the note: `curves@fit` fails at 0.5 and 2.0, and the `referenceInk > 5000` floor moved to 1,000 where the fixture (1,873 px) calibrated it. Row 2 is where that fact is scored |
| 2 | Criterion 2: band `hi/lo ≥ 2` | **MISS — the design failure the spec names.** `[1.0, 1.0]` = **1.00×**. Constants unchanged at 0.5/2.0 |
| 3 | Ten triggers cause exactly one rebuild; pan and resize none | **PASS** |
| 4 | Criterion 7: all ten ≤ 16.67 ms | **MISS — 6 of 10 over.** Worst 22.64 ms |
| 5 | Criterion 5: allocation probe | **UNEVALUABLE** with the refusal quoted |
| 6 | Criterion 8: arm D ≤ 1.2 build / ≤ 2.0 raster | **MISS — 5 of 6 cells over** |
| 7 | Criterion 9: arm D p95 raster ≤ 3.0 | **MISS on all three phases**; `staleFrames = 1` reported |
| 8 | Criterion 10: both fallbacks | **PASS** |
| 9 | Criterion 12: both zoom defects | **PASS as amended by Ruling F13-a** |
| 10 | Criterion 6 at a rebuilt scale | **MISS — 9.57 MB vs 8 MB**; PASS at fit (6.79 MB) |
| 11 | Fourteen mutations fire | **PASS** — 14 killed + M-F10′, 2 equivalent, zero true survivors |
| 12 | No shader or bundle change | **PASS** — `git diff --stat main..HEAD -- packages/jet_cad_2d_flutter/shaders packages/jet_cad_2d_flutter/assets` is **0 bytes** |
| 13 | A human looks at the window | **OWED — not looked at by a human in this session** (all four; Plan E's fifth also still owed) |
| 14 | Every gate green, three packages | **PASS** — nine commands, all exit 0 |

**7 of 14 PASS. 5 MISS, 1 UNEVALUABLE, 1 OWED. No threshold was moved.**

---

## 3. Every MISS / UNEVALUABLE / OWED with its number

**Criterion 2 — MISS, band `[1.0, 1.0]` = 1.00× against ≥ 2×.** Per-corpus
runs: straight control `[0.25, 4.0]` = 16.00×, text-lod `[0.35, 1.0]` = 2.86×,
curves `[1.0, 1.0]` = 1.00×. Printed line: `BAND reported: [1.0, 1.0] = 1.00x`.
Decomposed per Ruling F6-a; the text row proven by one changed argument — at
ratio 1.4, cull on `uncovered=153` FAIL vs cull off `agreement=1.00000` PASS on
the same fixture.

**Criterion 7 — MISS, 6 of 10** (medians of three, vs 16.67 ms):
`CommandApplied` **22.64**, `band out` **22.10**, `CommandUndone` **19.39**,
`DocumentPurged` **19.08**, `CommandRedone` **18.66**, tables **16.70** (over by
0.03). Passing: `DocumentLoaded` 15.55, `devicePixelRatio` 16.41, dpr back
16.09, `band back` 16.20. Cold first rebuild **25.3 ms**, reported not gated.
`classify` **6.7 ms** against Plan E's 27.4 — **4.1× faster**, 164% → 40% of
budget.

**Criterion 8 — MISS, 5 of 6 cells.** Arm D medians: hold 0.09/3.57, pan
2.23/2.95, zoom 2.17/2.91 (build/raster) vs ≤1.2/≤2.0. Only hold build passes.
**C-to-D difference: +0.01/+0.08 hold, +0.02/+0.17 pan, +0.17/+0.37 zoom** —
every miss inherited from arm C, none introduced by the widget path.

**Criterion 9 — MISS on all three.** Arm D p95 raster medians **6.57 / 4.75 /
7.36** vs ≤ 3.0; arm C misses too (5.98 / 4.05 / 3.60). Band exit:
`exitStep=36 landedAtStep=37 staleFrames=1 submits=-1 lastTrigger=band`, phase
max build 8.44, raster 11.49, n=38. **`staleFrames = 1`** — one frame painted
out of band before the landing.

**Criterion 6 — MISS at a rebuilt scale: 9.57 MB against 8 MB**, 1.57 MB over,
at 153,215–153,217 instances (2.5× fit, +43% over fit's 106,853). **PASS at
fit: 6.79 MB**, 1.21 MB margin. `patchTargets` 1.77 MB reported separately.

**Criterion 5 — UNEVALUABLE**, verbatim:

```
GSPIKE alloc: UNEVALUABLE -- SocketException: Connection failed (OS Error: Operation not permitted, errno = 1), address = 127.0.0.1, port = 63309
```

**None of the fifteen `GSPIKE alloc | N/frame | <lib> <class>` lines printed** —
the probe never reached a profile read. The VM service itself was up: the same
port appears in the run's own banner at line 29. `errno = 1` (`EPERM`) on a
loopback connect from a `.app` bundle is the macOS App Sandbox refusing the app
an **outbound** connection. Recorded per Ruling F8's pre-committed outcome,
never faked.

**Criterion 13 (the window) — OWED, four checks, none looked at.** Recorded
exactly as instructed: "OWED — not looked at by a human in this session" for
each of Plan F's four; Plan E's fifth stays OWED. Nothing is recorded as seen.

---

## 4. The gate commands, with output and exit codes

All nine run in the worktree after the device run.

```
$ cd packages/jet_cad_2d_flutter && flutter test
00:09 +664 ~1: All tests passed!
exit=0
$ flutter analyze
No issues found! (ran in 1.2s)
exit=0
$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.17 seconds.
exit=0

$ cd ../jet_cad_2d && dart test
00:02 +798: All tests passed!
exit=0
$ dart analyze
No issues found!
exit=0
$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.14 seconds.
exit=0

$ cd ../../apps/dev_harness_2d && flutter test --concurrency=1
00:16 +82: All tests passed!
exit=0
$ flutter analyze
No issues found! (ran in 0.8s)
exit=0
$ dart format --output=none --set-exit-if-changed .
Formatted 22 files (0 changed) in 0.04 seconds.
exit=0
```

`git status --short` before staging showed only the four intended paths.
**No `analysis_options.yaml` was rewritten or staged** — checked explicitly.

---

## 5. Files changed

- **Created** `docs/superpowers/notes/2026-09-05-plan-f-results.md` (710 lines)
  — Plan E's shape: the six premises measured false; the `flutter test`
  measurements (band rows, zoom rows, the classify comparison); the device-run
  conditions; the criterion-7 table per trigger; the criterion-8 C-vs-D table;
  criterion 9; criterion 6; the allocation section (UNEVALUABLE); the window
  (OWED); open question 3 in its own section; the mutation summary; the
  fourteen-row exit gate; every ruling with its cost; what Plan G inherits.
- **Created** `docs/superpowers/notes/2026-09-05-plan-f-raw/gspike-run.log`
  and `band-and-zoom.log`.
- **Modified** `docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md`
  — open question 3 struck exactly as Step 5 shows.
- **Modified** `STATUS.md` — new `## Plan F` section in Plan E's shape (state:
  implemented, NOT merged; gate 7 of 14; criteria with numbers; window OWED);
  header block updated; `Resume here` rewritten (Plan F leads, awaiting the
  human's look and the merge decision); the "Plan F is next" sentence struck
  and replaced with **Plan G (web) is next** and its inheritance list; Plan E's
  inherited-levers list annotated with what became of each.

**Nothing under `packages/**` or `apps/**` was edited**, as instructed.

---

## 6. Concerns

1. **Criterion 5 was never evaluated, and the fix is one file I was told not to
   touch.** The App Sandbox diagnosis is strong (EPERM on loopback connect from
   a bundled app, service reachable from outside) but it is a diagnosis, not a
   verified fix — I did not test adding
   `com.apple.security.network.client` to
   `apps/dev_harness_2d/macos/Runner/*.entitlements`, because that is an
   `apps/**` edit. **Invariant 1's "new mechanism" still has no device
   measurement**, and Ruling F10's parked R6-2 has no new evidence either way.
   Worth one cheap follow-up before Plan G rather than at the end of it.
2. **Gate row 1's literal form is not what the suite asserts.** Ruling F6-b
   changed both the ratios exercised and the anti-vacuity floor. I scored it
   "PASS as amended" and stated plainly in the note and this report that the
   unamended assertion is false — but a reader who checks only the gate table's
   verdict column could take it for an unqualified pass. The qualification is
   in the cell.
3. **`submits=-1` on the band-exit line** is a counter-identity artifact: the
   harness subtracts `backendOf(widget).frames` across a landing that installs
   a *new* `GpuDrawBackend` whose counter restarts at zero. The 38 frames were
   drawn (`n=38` on the raster stats). Recorded as a harness reporting minor,
   not a defect — but it is a line someone will misread later.
4. **I corrected a number in Plan E's record without editing Plan E's note.**
   `ResidentGeometry.byteLength` already includes the patch sub-buffers, so
   Plan E's "6.79 + 0.27 = 7.06 MB" double-counted; the figure is 6.79 MB.
   Verified arithmetically (106,852 × 16 × 4 = 6.52 MB, exactly Plan E's
   `patches=0` control reading, and 6.79 − 6.52 = 0.27). The verdict does not
   change and the margin is wider than recorded. The correction lives in this
   plan's note and in STATUS; Plan E's own note still carries 7.06.
5. **The single biggest criterion-7 lever is not where the plan looked.** The
   plan optimised `classify` (correctly — 4.1× on the device). But `walk` is
   now dominant, and **1.5–2.8 ms of every *edit*-triggered rebuild is a
   `document.extents` recomputation that no printed counter attributes** — the
   gap between `total` and `walk + classify + upload` is 1.49–2.77 ms on
   exactly the four rows whose trigger mutates the document and ≤ 0.02 ms on
   the six that do not, and `draft_document.dart:153` is
   `_extentsCache ??= _computeExtents()`. Mechanically confirmed, not inferred.
6. **The window is the gate that most needs a human and got no one.** Check 3
   (a band exit sharpens without a blank) has a measured companion —
   `staleFrames = 1`, no blank frame in 38 — and check 2 has one (the probe
   line changes the instance count by exactly one, all three repeats). Neither
   is the check. The picture was not seen, and I recorded no check as seen.

---

# Fix round 1 of 5 — Ruling F8-a: criterion 5 measured

**Commit:** `98285d3` — `docs: criterion 5 measured -- the harness may open its
own VM service`, on top of `10eaae7`. Working tree clean.

**Outcome: criterion 5 moved from UNEVALUABLE to a measured MISS. The exit-gate
count is unchanged at 7 of 14** — six measured MISSes now instead of five plus
one UNEVALUABLE, one OWED, nothing UNEVALUABLE.

## 1. The entitlement diff

The diagnosis in §6 of the original report is confirmed: `DebugProfile`
carried `com.apple.security.network.server` but not `network.client`.

```diff
--- a/apps/dev_harness_2d/macos/Runner/DebugProfile.entitlements
+++ b/apps/dev_harness_2d/macos/Runner/DebugProfile.entitlements
@@ -6,6 +6,8 @@
 	<true/>
 	<key>com.apple.security.cs.allow-jit</key>
 	<true/>
+	<key>com.apple.security.network.client</key>
+	<true/>
 	<key>com.apple.security.network.server</key>
 	<true/>
 </dict>
--- a/apps/dev_harness_2d/macos/Runner/Release.entitlements
+++ b/apps/dev_harness_2d/macos/Runner/Release.entitlements
@@ -4,5 +4,7 @@
 <dict>
 	<key>com.apple.security.app-sandbox</key>
 	<true/>
+	<key>com.apple.security.network.client</key>
+	<true/>
 </dict>
 </plist>
```

Two lines each, key ordering and tab indentation preserved, **nothing else
under `apps/`**. `git status` confirmed only these two files plus the four
document paths.

## 2. Run 2's conditions

Identical command, identical defines, `SPIKE_FRAMES=30`. Low Power Mode still
`lowpowermode         0`; macOS listed by `flutter devices`; Impeller/MetalSDF;
window `1400x900`. Backgrounded, polled for `GSPIKE done` under a bounded cap,
killed with `pkill -f "flutter.*run.*macos"; pkill -f dev_harness_2d`, and
**both `pgrep -fl dev_harness_2d` and `pgrep -fl "flutter.*run.*macos"` returned
exit 1 (no match)**.

**Run 2 completed: `GSPIKE done: 36 phase reports above.`** Greps for
`textsDropped`, `GSPIKE RUN FAILED`, `StateError` and `UNEVALUABLE` are **all
empty**. Copied to `docs/superpowers/notes/2026-09-05-plan-f-raw/gspike-run2.log`
(195 lines); run 1 renamed to `gspike-run1.log` via `git mv`.

**Run 2 is the run of record for every criterion.** Every median in the note was
re-derived from it by script, and the note's criterion-7 and criterion-8 tables
were then checked cell-by-cell against that script (all matched; the two
apparent mismatches the checker flagged were a backtick in the row label and a
Unicode minus sign, both verified by hand).

## 3. The allocation lines, verbatim

```
GSPIKE alloc | 694.0/frame | dart:typed_data _Float64List
GSPIKE alloc | 300.9/frame | dart:typed_data _Int64List
GSPIKE alloc | 288.9/frame | dart:ui Rect
GSPIKE alloc | 108.9/frame | dart:typed_data _Uint32List
GSPIKE alloc | 95.6/frame | dart:ui _Image
GSPIKE alloc | 95.6/frame | dart:ui Image
GSPIKE alloc | 94.6/frame | package:jet_cad_2d_flutter/src/gpu/text_compositor.dart PatchImage
GSPIKE alloc | 91.1/frame | dart:typed_data _Float32List
GSPIKE alloc | 89.9/frame | package:flutter_gpu/gpu.dart BufferView
GSPIKE alloc | 88.0/frame | package:flutter_gpu/gpu.dart RenderPass
GSPIKE alloc | 88.0/frame | package:flutter_gpu/gpu.dart RenderTarget
GSPIKE alloc | 88.0/frame | package:flutter_gpu/gpu.dart ColorAttachment
GSPIKE alloc | 88.0/frame | package:flutter_gpu/gpu.dart CommandBuffer
GSPIKE alloc | 11.0/frame | package:jet_cad_2d_flutter/src/gpu/resident_text.dart ResidentTextRecord
GSPIKE alloc | 10.2/frame | dart:typed_data _Int32List
GSPIKE alloc: arm=D residentGpu (DraftCanvas) perFrame=2333.2 patches=90 (the LAST frame's patchesRendered, not a sum) budget=2200 (kAllocFixed=40 + kAllocPerPatch=24 x P) -> MISS | frames=30 classes=142 total=69997 -- read the per-class lines above before believing a MISS: the sum includes the rig's own per-frame ViewportTransform (camera.panBy) and dart:ui compositing objects, which are not the resident frame path
```

**Criterion 5: MISS as printed** — `perFrame = 2333.2` vs `budget = 2200`
(`40 + 24 × 90`), over by 133.2/frame or 6.1%. Two findings sit under it:

- **The resident frame path's own per-patch cost is half its allowance.** Ten of
  the fifteen classes are the per-patch objects the spec's revision-5 exception
  enumerates by name, each at ≈88–96/frame (one per patch at `P = 90`). They sum
  to **1,107.7/frame = 12.3 per patch against the 24 allowed**. The overage is
  entirely in the five non-per-patch classes (1,125.0/frame between them, led by
  `_Float64List` at 694.0).
- **The window was not walk-free, so the printed total is contaminated upward.**
  `ResidentTextRecord` is constructed at exactly **one** site in the package —
  `geometry_collector.dart:758`, inside `drawText` — so it can only be allocated
  during a collection walk. At 11.0/frame × 30 frames that is **≈330 records ≈
  2 × the corpus's 165 labels**: about two document walks landed inside the
  probe's window despite Task 8's settle loop being written to exclude them
  (it waits for `pending == null && !inFlight && inBand(camera)` across two
  consecutive quiet frames, capped at 300). A walk allocates far more than its
  text records, which is the likely home of the `_Float64List`/`_Int64List` bulk.

**Recorded as MISS with the number, threshold not moved, verdict not
re-scored** — with the contamination named and the fix handed to Plan G (assert
`rebuilder.rebuilds` is unchanged across the probe's 30 frames and throw if not).

**R6-2 now has its number** (Ruling F10 kept it parked): `dart:ui Image` 95.6 +
`_Image` 95.6 per frame, one handle per patch, never disposed.

## 4. What else run 2 moved

Run 2 changed several timing figures, and the note now carries run 2's
throughout. The comparison between the two runs is itself reported, because it
is a free variance estimate:

- **Criterion 7: still 6 of 10 over, but a different six.** Worst is now
  `CommandApplied` **26.93 ms** (was 22.64). `tables` read 16.70 (MISS) in run 1
  and **16.11 (PASS)** in run 2; `DocumentLoaded` read 15.55 (PASS) and
  **16.84 (MISS)**. Both sit within ±0.7 ms of the threshold. The four clear
  misses are stable across both runs. `classify` **6.3 ms** vs Plan E's 27.4
  (4.3×).
- **The `document.extents` finding got stronger.** The gap between `total` and
  `walk + classify + upload` is ≤ 0.02 ms on all six non-mutating rows in all
  three repeats, and **1.43–9.64 ms** on the four mutating ones — reaching
  **8.97 and 9.64 ms** on `CommandApplied`, more than a third of that row's whole
  rebuild.
- **Criterion 8: still 5 of 6 over**; D medians hold 0.04/3.37, pan 2.60/3.32,
  zoom 2.34/3.16. The C-to-D difference is now **≤ +0.20 ms at p50**, and
  **−0.01 on hold build** (arm D fractionally faster than the control).
- **Criterion 9: still MISS on all three**; p95 8.73 / 7.25 / 7.46 (arm C 5.26 /
  4.05 / 7.27). The p50-to-p95 gap on both arms says these are tail misses.
- **Criteria 2, 6 and 12 are unchanged**, to the pixel and the megabyte:
  band `[1.0, 1.0]`, `band out` 9.57 MB at 153,215 instances, fit 6.79 MB,
  `staleFrames = 1` with `exitStep=36 landedAtStep=37` in both runs.

## 5. The gate commands, with output and exit codes

Re-run after the entitlement change. **All nine exit 0.**

```
$ cd packages/jet_cad_2d_flutter && flutter test
00:08 +664 ~1: All tests passed!
exit=0
$ flutter analyze
No issues found! (ran in 1.4s)
exit=0
$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.16 seconds.
exit=0

$ cd ../jet_cad_2d && dart test
00:02 +798: All tests passed!
exit=0
$ dart analyze
No issues found!
exit=0
$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.14 seconds.
exit=0

$ cd ../../apps/dev_harness_2d && flutter test --concurrency=1
00:15 +82: All tests passed!
exit=0
$ flutter analyze
No issues found! (ran in 0.8s)
exit=0
$ dart format --output=none --set-exit-if-changed .
Formatted 22 files (0 changed) in 0.04 seconds.
exit=0
```

`git status --short` before staging showed only the six intended paths.
**No `analysis_options.yaml`** — checked explicitly.

## 6. Files changed in this round

- `apps/dev_harness_2d/macos/Runner/DebugProfile.entitlements`, `Release.entitlements` — two lines each (Ruling F8-a).
- `docs/superpowers/notes/2026-09-05-plan-f-raw/gspike-run2.log` — new, the run of record.
- `docs/superpowers/notes/2026-09-05-plan-f-raw/gspike-run.log` → `gspike-run1.log` — renamed (`git mv`).
- `docs/superpowers/notes/2026-09-05-plan-f-results.md` — device-run section rewritten against run 2 ("Two runs, and why"); criteria 7, 8, 9, 6 tables re-derived; criterion 5 rewritten as MEASURED/MISS with the fifteen lines and the decomposition; premise 6's R6-2 aside corrected; gate rows 4, 5, 6, 7 and the count updated; Ruling F8-a added to the rulings list; "What Plan G inherits" updated.
- `STATUS.md` — Plan F table rows for criteria 5, 7, 8, 9 and the rebuild breakdown; the gate-count sentence; the entitlement note; the resume lead's criterion-5 bullet; Plan G's inheritance list; R6-2's number.

## 7. Concerns after this round

1. **Criterion 5's MISS is not trustworthy in either direction until the probe
   window is walk-free.** The 6.1% overage is smaller than the contamination
   two document walks would contribute, so the printed verdict may well flip to
   PASS on a clean read. I recorded the MISS as printed rather than re-scoring
   it, but nobody should act on the number as it stands. This is the one item I
   would put ahead of web work in Plan G.
2. **The settle loop is more careful than it looks and still let walks in.** Its
   own comments anticipate exactly this failure mode (they explain why `inBand`
   is in the condition and why two *consecutive* quiet pumps are needed), so the
   leak is not the obvious one. Worth a real diagnosis rather than another
   guard: this is a real app with a real vsync, and frames are drawn during the
   `await`s on `AllocationProbe.connect()` and `reset()` that the manual
   `pumpFrame` loop does not control.
3. **Two criterion-7 rows are inside the noise band.** Reporting "6 of 10" is
   correct for both runs, but which six is not stable. The note says so.
4. Concerns 2–6 from the original report stand unchanged, except that the
   criterion-5 half of concern 1 is now discharged.

---

# Fix round 2 — review findings (3 Important, 4 minors)

**Commit:** `2b0dd0e` — `docs: STATUS carries the run of record's numbers, and
the harness does not claim to see a blank frame`, on top of `98285d3`. Working
tree clean. **All three Important addressed, all four minors taken, plus two
instances of Important 3 the review did not list.**

## Important

**1. `STATUS.md` — run 1's 38-frame band-exit window.** Run 2 (the run of
record) prints `n=37`. Fixed. Swept the whole repo for `38 frames` and `n=38`:
**zero remaining** in either document.

**2. `STATUS.md` — the Plan-E-inheritance paragraph's stale classify figures.**
It carried "6.7 ms on the device, 4.1× faster, 40% of the budget" — run 1's
numbers — while STATUS's own Plan F table and the note both carried run 2's.
Now **6.3 ms, 4.3×, 38%**. Swept for `4.1×`, `6.7 ms on the device` and `40% of
the budget`: **zero remaining**.

**3. "No blank frame in the band-exit window" is an inference the harness cannot
support.** The review is right, and this is the finding worth the most. The
band-exit phase records `staleFrames`, `exitStep`, `landedAtStep` and build /
raster timing samples. **Nothing in the harness reads a pixel.** "No blank
frame" is therefore a claim no transcript backs — the same class of defect as a
synthesized number, and precisely the kind this project's no-synthesis rule
exists to catch.

I did not just drop the clause; I replaced it with what the run does and does
not measure, at **all four** sites — the review named two, and the same
unmeasured claim appeared at two more:

| site | before | after |
|---|---|---|
| `STATUS.md` window check 3 (named) | "no blank frame in the band-exit window's 38 frames" | states `staleFrames = 1` over 37 frames, then "**It does not measure blankness**: the harness reads frame timings and a stale count, never ink. Whether that one frame was blank is exactly what the eye is for." |
| note, "What the transcripts do support" (named) | "no blank frame in the band-exit window's 37 frames" | "**the harness records frame timings, a stale count and instance counts — it never samples ink, so nothing in either transcript can say whether a frame was blank or whether an edge went undrawn.** That is precisely what checks 3 and 4 ask a human to look at." |
| note, criterion 9's band-exit section (**not named — found in the sweep**) | "leaving the band costs one stale frame, not a blank one" | "**What is measured is the interval** … **What is not measured is what that frame looked like.** … The spec's stronger claim — that a band exit sharpens without a blank — is window check 3, and it is OWED." |
| `STATUS.md` Plan F table, criterion 9 row (**not named — found in the sweep**) | "Leaving the band costs one stale frame, not a blank one — the design's intent, measured" | "**Leaving the band costs exactly one stale frame** … What that frame *looked like* is not measured … That is window check 3, still OWED" |

## Minors, all taken

**(a) The fit-scale buffer is 6.78–6.79 MB, not 6.79.** Corrected in the note's
criterion-6 table, its gate row 10, and STATUS's criterion-6 row (margin now
"≥ 1.21 MB"). **I checked the mechanism rather than hand-waving it**: the two
`devicePixelRatio` rows print 6.78 at the *same* `instances=106853` and the
*same* `patches=90` as the 6.79 rows, so the difference is neither the main
buffer nor the patch count — it is how many instances fall inside the patch
boxes, which `classifyTextPatches` sizes in **device** pixels and the dpr
trigger therefore changes. At 64 bytes an instance, 0.01 MB is ~164 instances;
at two decimal places the true difference is under a few hundred. That is what
the note now says. (My first draft said the dpr "moves the text cull by a label
or two" — false, `patches=90` is identical in both — and was corrected before
commit.)

**(b) The decomposition's two BAND lines are now verbatim.** They had been
reformatted into a shortened form. Replaced with `band-and-zoom.log` lines 37
and 41 exactly as printed, `CompositedAgreement(...)` and all, with the line
numbers cited.

**(c) The gate summary now says which passes are qualified**: "7 of 14 PASS —
two of them PASS *as amended*, rows 1 and 9 (Rulings F6-b and F13-a); the other
five are unqualified." Added to STATUS's gate sentence too.

**(d) `conditions.log` added**, at
`docs/superpowers/notes/2026-09-05-plan-f-raw/conditions.log`, holding
`pmset -g | grep -i lowpower` → ` lowpowermode         0` and the full
`flutter devices` output. **Its provenance is stated in the file itself, in a
header, because it is not the original transcript**: both commands were run and
read before each device run but were not captured to a file at the time, so
this is an explicitly-labelled re-run made afterwards on the same machine the
same day. Nothing was synthesized.

It also records, rather than smooths over, the one way the re-run differs from
the originals: `flutter devices` now reports **3** connected devices where both
runs saw **2** — an iPhone finished pairing in between. It is irrelevant to a
`-d macos` run, nothing in the note depends on the count, and the line the note
actually quotes is byte-identical in both. Both documents' raw-log pointers and
the note's files-touched list now name `conditions.log` with that caveat.

## The gate commands, with output and exit codes

**All nine exit 0.** (The note's pasted gate block was re-synced to this run's
wall times.)

```
$ cd packages/jet_cad_2d_flutter && flutter test
00:08 +664 ~1: All tests passed!
exit=0
$ flutter analyze
No issues found! (ran in 1.3s)
exit=0
$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.16 seconds.
exit=0

$ cd ../jet_cad_2d && dart test
00:02 +798: All tests passed!
exit=0
$ dart analyze
No issues found!
exit=0
$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.15 seconds.
exit=0

$ cd ../../apps/dev_harness_2d && flutter test --concurrency=1
00:14 +82: All tests passed!
exit=0
$ flutter analyze
No issues found! (ran in 0.8s)
exit=0
$ dart format --output=none --set-exit-if-changed .
Formatted 22 files (0 changed) in 0.04 seconds.
exit=0
```

`git status --short` before staging showed only the three intended paths.
**No `analysis_options.yaml`.**

## Files changed in this round

- `STATUS.md` — the 37-frame correction; the classify figures; two blankness
  claims; the buffer range; the gate-count qualifier; the `conditions.log`
  pointer.
- `docs/superpowers/notes/2026-09-05-plan-f-results.md` — two blankness claims;
  the buffer range with its verified mechanism; verbatim BAND lines; the gate
  summary qualifier; the raw-logs pointer and files-touched list.
- `docs/superpowers/notes/2026-09-05-plan-f-raw/conditions.log` — new.

**Nothing under `packages/**` was touched, and nothing further under `apps/**`**
(Ruling F8-a's two entitlement files landed in the previous commit).

## Concerns after this round

The exit gate is unchanged at **7 of 14** — this round moved no verdict, only
figures and one class of unsupported claim. Concerns 1–3 from fix round 1 stand:

1. **Criterion 5's MISS is still not trustworthy in either direction** until the
   probe window is walk-free (`ResidentTextRecord` at 11.0/frame ≈ 2 collection
   walks inside the window; the 6.1% overage is smaller than that contamination
   would contribute). Ahead of web work in Plan G.
2. **The settle loop's leak needs a diagnosis, not another guard** — its own
   comments already anticipate the obvious failure mode; real vsync frames are
   drawn during the `await`s on `connect()` and `reset()` that the manual pump
   loop does not control.
3. **Two criterion-7 rows sit inside the noise band** (`tables`,
   `DocumentLoaded`, each within ±0.7 ms of the line, swapping sides between the
   runs). "6 of 10" holds in both runs; which six does not.
4. **New, from Important 3:** the four blankness claims all came from me writing
   the *design's intent* where the *measurement* belonged. They are fixed, but
   it is worth the reviewer of any later plan knowing this harness measures
   timings, counts and instance totals only — **no criterion in Plan F is backed
   by a pixel read on the device.** Criteria 2 and 12's pixel evidence is
   `flutter test`'s Skia rasterisation, not the GPU. The window checks are the
   only thing that looks at what the GPU actually drew, and all five are OWED.
