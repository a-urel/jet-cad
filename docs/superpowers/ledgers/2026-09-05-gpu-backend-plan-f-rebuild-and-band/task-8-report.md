# Task 8 report — the harness: arm D, the trigger phases, the band exit, and the allocation probe

Commit: `635e3e7` — `feat(harness): arm D on DraftCanvas, the ten trigger rebuilds, the band exit, and a VM-service allocation probe`
Branch: `plan-f/rebuild-and-band` (worktree `.worktrees/plan-f-rebuild-and-band`), on top of `ed94773`.

No device run in this task, as instructed. Nothing in `packages/jet_cad_2d_flutter/lib`,
`packages/jet_cad_2d`, the sinks or the shaders was touched.

---

## What was implemented, per file

### `apps/dev_harness_2d/pubspec.yaml`
`vm_service: ^15.2.0` under `dependencies:` (a harness dependency only). `flutter pub get`
rewrote `packages/jet_cad/analysis_options.yaml`; reverted with `git checkout --` before
anything was staged, and it does not appear in the commit.

`pubspec.lock` at the workspace root is **not tracked** (`git ls-files pubspec.lock` is
empty), so it was not staged — the brief's own parenthetical covers this case.

### `apps/dev_harness_2d/lib/main.dart`
`kBackend`'s inline switch replaced with the brief's `parseBackend(String)` function plus a
`kBackend` that calls it. `residentGpu` is now an accepted value; a typo still throws.

### `apps/dev_harness_2d/lib/allocation_probe.dart` (new)
`AllocationProbe` verbatim from the brief: `connect()` (`Service.getInfo()`, falling back to
`controlWebServer(enable: true)`, then a ws connect and one proving RPC), `reset()` (two RPCs,
`gc` then `reset`), `read()` (`instancesAccumulated` per class, filtered to
`kProbedLibraryPrefixes`), `dispose()`. One addition: a doc comment on `read()` recording the
"at most once per reset" trap that `packages/jet_cad_2d/test/invariants/vm_allocation_meter.dart`
documents as its failure mode 3 (a second read against the same epoch reads near-zero). The
rig calls `read()` exactly once per `reset()`.

### `apps/dev_harness_2d/lib/gpu_arm.dart`
- imports: `dart:typed_data`, `package:jet_cad_2d/testing.dart` (that is where
  `kDefaultOriginX`/`kOriginY`/`kFloorWidth`/`kFloorHeight` live — `generate_document.dart`,
  re-exported by `testing.dart`, which is what `main.dart` already imports for them),
  `allocation_probe.dart`.
- `GpuSpikeArm.widget`, label `D residentGpu (DraftCanvas)`; enum doc "three arms" → "four arms".
- `kAllocFixed = 40`, `kAllocPerPatch = 24`, with the brief's rationale comment.
- `GpuSpikeState`: `widgetKey`, `dprOverride`, `widgetRebuilder`, `backendOf(arm)`;
  `dprOverride.dispose()` in `dispose()`; the `Offstage` + `MediaQuery` + `DraftCanvas`
  subtree after arm C's `Positioned.fill`.
- `fireDocumentTrigger(doc, name, {required Handle probe})` — the six document-side triggers
  and an `ArgumentError` default.
- `runGpuSpike`: `baseDpr`; `setArm` waits for arm D's first landing and refuses a fallback;
  `phase` gained `frameCount` and reads `state.backendOf(a)`; the per-repeat gpu/patch report
  lines now also fire for arm D; `rebuildPhase(repeat)` (the ten triggers) called at the end
  of every repeat; the 40-frame `bandexit` phase; the allocation phase. `GSPIKE done` is still
  the last line.

### `.vscode/launch.json`
The two entries from the brief, after the `DRAW_TEXT=false` one. Validated as JSON after
stripping `//` comments.

### `apps/dev_harness_2d/test/gpu_widget_arm_test.dart` (new)
The brief's four tests.

---

## Adaptations of brief snippets, and why

1. **`main.dart` doc-comment placement.** The brief said "keeping the doc comment above it".
   Placed literally, the existing `kBackend` block comment would have landed on
   `parseBackend` while `kBackend` — which three other doc comments in the file cross-reference
   as `[kBackend]` — lost its own. The `String.fromEnvironment` rationale now documents
   `parseBackend` (it is a statement about the parse) and `kBackend` carries a two-line doc
   naming the four values and pointing at `parseBackend`. No text was deleted.

2. **`setArm`: the "no GPU frame" guard runs for arm D on its *cold* switch only.**
   The brief's `painted=0` check reads `state.backendOf(a)?.frames` "for both `gpu` and
   `widget`" on every switch. Arm C survives that because its widget is absent from the tree
   while another arm is live, so each switch constructs a fresh element and render object,
   which always paints. Arm D is behind an `Offstage` (deliberately — its rebuilder lives in
   `DraftCanvasState` and a come-and-go widget would re-upload the collection on every
   switch), and `RenderOffstage` reuses the child repaint boundary's retained layer when the
   child does not need paint. `rebuildPhase` and both trailing phases call
   `setArm(GpuSpikeArm.widget)` when D is *already* the live arm and the camera has not
   moved; there the canvas legitimately paints nothing, and an unconditional guard would
   throw and kill the run. The guard therefore runs when `a == gpu`, or on D's first switch —
   which is the case it exists to catch ("it is not in the paint path at all"). The warm case
   is still visible: D now emits the per-phase `gpu submits=` line.

3. **`setArm`: two extra `pumpFrame()`s, and the COLD line printed only once.**
   `pumpFrame()` completes at end-of-frame, i.e. after the post-frame callback that *starts*
   the rebuild; the landing itself happens later, in the awaited upload. So the brief's wait
   loop exits before any frame has painted through the new backend, and the guard in (2)
   would read `frames == before`. Two more pumps after the landing fix that. The
   `first rebuild landed after N frame(s)` line is also gated on the cold switch — on a warm
   switch the loop exits at once and the line would have printed `after 0 frame(s)` with
   stale micros every repeat. The `uploadFailed` refusal is left unconditional.

4. **`fireDocumentTrigger`'s `probe` handle is allocated per sweep, not per run.**
   The brief allocates it once in `runGpuSpike`. `AddEntityCommand.apply` throws
   `DuplicateHandleError` for a handle the document already carries
   (`packages/jet_cad_2d/lib/src/document/commands.dart`), and the sweep leaves its line
   behind: `CommandRedone` puts it back, and neither `DocumentLoaded` nor `DocumentPurged`
   removes it. With `SPIKE_REPEATS=3` the second repeat's `CommandApplied` would have thrown.
   `final probe = state.widget.document.handleSeed.next();` now lives at the top of
   `rebuildPhase`, so each sweep adds one distinct line (three lines total at three repeats).
   The signature and the test are unchanged.

5. **A settle loop before the allocation probe arms.** The band-exit phase leaves the
   collection at 2.04x the fit scale. The allocation phase's own `camera.value = baseCamera`
   is then a *band exit in the other direction* (1/2.04 = 0.49, under `kBandLowerScale` =
   0.5), so it schedules a full document walk. Measured inside the probe's 30-frame window
   that one-off collection would swamp the per-frame figure and the line would read MISS for
   a reason unrelated to the frame path. The phase now pumps until
   `!rebuilder.inFlight && rebuilder.pending == null` (bounded at 300) plus two quiet frames,
   before `probe.reset()`.

6. **`test/gpu_widget_arm_test.dart`: `seen.clear()` before the `tables` fire.**
   The brief's test as written fails. `fire()` clears `seen` at its *start*, so after
   `fire('DocumentPurged')` the list still holds that `DocumentPurged`; the later
   `expect(seen, isEmpty, reason: 'a table edit emits no DocChange (spec)')` was reading the
   previous trigger's change, not the table edit's absence. Observed failure:
   `Expected: empty / Actual: [Instance of 'DocumentPurged']`. One `seen.clear()` with a
   comment was added before the `tables` fire; the assertion now means what it says.

7. **`test/gpu_widget_arm_test.dart`: `import 'dart:async';` dropped.** `flutter analyze`
   reported `unnecessary_import` (info), and this workspace treats infos as failures. Nothing
   in the test needs it after the `Future` come from `flutter_test`'s re-export.

8. **Two doc comments in `GpuPhaseReport` corrected for drift** — `submits` and
   `patchesRendered` said "arm C" / "zero on every arm but `gpu`", which stopped being true
   the moment arm D reports through the same fields.

---

## TDD evidence

**Red** (`flutter test --concurrency=1 test/gpu_widget_arm_test.dart`, after Step 1 only):

```
Compilation failed ... test/gpu_widget_arm_test.dart:20:24: Error: Member not found: 'widget'.
    expect(GpuSpikeArm.widget.label, contains('DraftCanvas'));
test/gpu_widget_arm_test.dart:32:7: Error: Method not found: 'fireDocumentTrigger'.
test/gpu_widget_arm_test.dart:44:5: Error: Method not found: 'fireDocumentTrigger'.
test/gpu_widget_arm_test.dart:48:18: Error: Method not found: 'fireDocumentTrigger'.
test/gpu_widget_arm_test.dart:57:12: Error: Undefined name 'kAllocPerPatch'.
test/gpu_widget_arm_test.dart:58:12: Error: Undefined name 'kAllocFixed'.
00:00 +0 -1: Some tests failed.
```

(`parseBackend` already resolved — Step 1 landed before the test was written, as the brief
orders it.)

**Red again, for a real defect** — after Step 5, with the brief's test verbatim:

```
00:00 +2 -1: fireDocumentTrigger emits the DocChange its name says [E]
  Expected: empty
    Actual: [Instance of 'DocumentPurged']
  a table edit emits no DocChange (spec)
  test/gpu_widget_arm_test.dart 45:5  main.<fn>
```

That is adaptation 6 above.

**Green:**

```
00:00 +0: BACKEND parses residentGpu, and still refuses a typo
00:00 +1: four arms, four distinct labels, and D names the widget
00:00 +2: fireDocumentTrigger emits the DocChange its name says
00:00 +3: the allocation budget is the enumerated exception set, generously
00:00 +4: All tests passed!
```

**Mutations run against the new test** (both applied to `gpu_arm.dart`, both reverted; the
file was restored from a byte copy and the suite re-run green afterwards):

| Mutation | Result |
| --- | --- |
| `case 'CommandRedone': doc.commands.undo();` | RED — `Expected: Type:<CommandRedone> / Actual: Type:<CommandUndone>` |
| `case 'tables':` short-circuited before `layers.remove`/`add` | RED — `Expected: a value greater than <13> / Actual: <13>` |

The `tables` mutation is the one that matters: it is exactly the fixture that would otherwise
pass by accident, because the trigger's effect is a revision counter and not a `DocChange`.

The other two tests are compile-time/structural (`parseBackend`, the four arms and the two
budget constants) and go red by construction on any change to the values they name.

---

## The nine gates

Run from the worktree; each exit code is the command's own (`$?` immediately after).

```
$ cd apps/dev_harness_2d && flutter test --concurrency=1
00:15 +81: All tests passed!
GATE1 flutter test EXIT=0

$ cd apps/dev_harness_2d && flutter analyze
No issues found! (ran in 1.3s)
GATE2 flutter analyze EXIT=0

$ cd apps/dev_harness_2d && dart format --output=none --set-exit-if-changed .
Formatted 22 files (0 changed) in 0.03 seconds.
GATE3 dart format EXIT=0

$ cd packages/jet_cad_2d_flutter && flutter test
00:11 +664 ~1: All tests passed!
GATE4 flutter test EXIT=0

$ cd packages/jet_cad_2d_flutter && flutter analyze
No issues found! (ran in 1.2s)
GATE5 flutter analyze EXIT=0

$ cd packages/jet_cad_2d_flutter && dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.16 seconds.
GATE6 dart format EXIT=0

$ cd packages/jet_cad_2d && dart test
00:02 +798: All tests passed!
GATE7 dart test EXIT=0

$ cd packages/jet_cad_2d && dart analyze
No issues found!
GATE8 dart analyze EXIT=0

$ cd packages/jet_cad_2d && dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.14 seconds.
GATE9 dart format EXIT=0
```

`git status --short` before the commit — no `analysis_options.yaml`:

```
 M .vscode/launch.json
 M apps/dev_harness_2d/lib/gpu_arm.dart
 M apps/dev_harness_2d/lib/main.dart
 M apps/dev_harness_2d/pubspec.yaml
?? apps/dev_harness_2d/lib/allocation_probe.dart
?? apps/dev_harness_2d/test/gpu_widget_arm_test.dart
```

The harness suite went from 77 to 81 tests; the existing ones (`spike_text_test.dart`,
`zoom_arm_wiring_test.dart`, …) were checked for anything enumerating `GpuSpikeArm` or
hard-coding `3` — `grep -rn 'GpuSpikeArm' test/` returns nothing, and all 81 pass.

## Files changed

| File | Change |
| --- | --- |
| `apps/dev_harness_2d/pubspec.yaml` | + `vm_service: ^15.2.0` |
| `apps/dev_harness_2d/lib/main.dart` | `parseBackend` extracted, `residentGpu` accepted |
| `apps/dev_harness_2d/lib/allocation_probe.dart` | new — `AllocationProbe`, `kProbedLibraryPrefixes` |
| `apps/dev_harness_2d/lib/gpu_arm.dart` | arm D, budgets, `fireDocumentTrigger`, three new phases (+346/−17) |
| `apps/dev_harness_2d/test/gpu_widget_arm_test.dart` | new — four tests |
| `.vscode/launch.json` | two Plan F entries |

---

## Self-review findings

- **Verified against the real API surfaces, not assumed:** `ResidentRebuilder`'s
  `backend`/`collection`/`landed`/`pending`/`inFlight`/`uploadFailed`/`bandStaleFrames`/
  `last*Micros`/`lastTrigger`; `ResidentCollection.instanceCount`/`patches`/`byteLength`;
  `DraftCanvasState.resident`; `kBandLowerScale = 0.5`, `kBandUpperScale = 2.0`
  (`text_patches.dart`) — so the brief's "1.02^36 = 2.04 leaves the band" is right, and 40
  frames is enough; `doc.changes` is a **broadcast** controller, so the test's own listener
  does not compete with `DraftCanvas`'s; `IndexedColor.aci`; `TableSection.remove`/`add` each
  call `onMutated`, so `mutationRevision` moves by 2 per `tables` fire.
- **The dpr trigger really reaches the rebuilder:** `_DraftCustomPainter.shouldRepaint`
  returns true when `devicePixelRatio` changes on a resident canvas, which is what turns the
  `MediaQuery` override into a painted frame and therefore a `noteFrame` with a new dpr.
- **The tables trigger really reaches it too:** `_repaint` merges the table listenable, so a
  layer edit schedules the frame whose `noteFrame` sees the new revision.
- `kAllocFixed`/`kAllocPerPatch` are exactly the brief's values and sit inside the test's
  ranges with room on both sides.
- `GSPIKE done` is still the last `gpuReport` call in the file; the report overlay keys off
  it and still appears.
- Arm C (`GpuArmView`, `GpuSpikeState.backend`, `_buildResidentGeometry`) is untouched —
  `git diff` on that region is empty except for the two `GpuPhaseReport` doc-comment
  corrections and `state.backend` → `state.backendOf(a)` inside `phase`, which returns
  `backend` unchanged for `GpuSpikeArm.gpu`.

---

## Concerns — what Task 10's device run must know

1. **If the probe refuses**, the line is
   `GSPIKE alloc: UNEVALUABLE -- the VM service refused: <error>` and no number is printed.
   The two expected refusals are (a) `Service.getInfo()` and `controlWebServer` both giving
   no URI — that is a run without a VM service at all, so check it really is
   `flutter run --profile` (VS Code's `flutterMode: profile` serves one) and not
   `flutter build`/`flutter test`; (b) the ws connect or the first `getAllocationProfile`
   throwing — a sandboxed loopback socket. Report the line verbatim; do not substitute a
   number from anywhere else.
2. **The probe's figure is a whole-library sum, and it has a noise floor.** The reference
   meter's own notes record 20–70 MB of unrelated churn when summing *every* class; this
   probe narrows to five library prefixes, which is much better but not zero. The per-class
   top-15 lines are printed above the verdict precisely so a MISS can be read as "which
   class", not just "too many". A MISS whose top line is a `dart:ui` or `flutter_gpu` object
   at ~1/frame is the enumerated exception set; a MISS whose top line scales with instance
   count is the real finding.
3. **The trigger sweep mutates the shared document, and repeats 2 and 3 measure a slightly
   different corpus than repeat 1.** Each sweep adds one line entity (the probe line) and
   flips layer 0's colour between ACI 1 and 2. Geometry cost is unchanged to within one
   entity in ~110,000; arm C's buffer was collected once at startup and does not show the
   added line at all. This is the brief's design ("run once per repeat"), noted so the
   repeat-to-repeat spread is not read as session drift.
4. **`SPIKE_FRAMES` must stay at 30 for the launch config.** The arm loop's zoom phase is
   `frames` steps of 1.02; at 30 that is 1.81x, inside the band, so arm D's zoom phase
   measures the *no-rebuild* gesture path, which is what criterion 8 wants. At the default of
   60 it reaches 3.28x and a band rebuild lands inside the measured zoom phase. The Plan F
   launch entry pins 30; a hand-typed run must too.
5. **`bandexit`'s `staleFrames` is only meaningful because it is zeroed immediately before
   the phase.** `phase()` resets the camera to base and pumps a baseline first, all in band,
   so nothing is counted before step 36. If the number comes back 0, that means the rebuild
   landed on the same frame the band was left — worth double-checking against
   `rebuilds landed=` on the same line rather than being read as "no exit happened".
6. **The `no rebuild landed in N frames` StateError from `rebuildPhase` aborts the whole
   run** and prints no `GSPIKE done`. If it fires on `devicePixelRatio`, suspect a platform
   where `MediaQuery.copyWith(devicePixelRatio:)` does not reach the canvas; if on `tables`,
   suspect the revision plumbing; if on `band out`, suspect the band bounds. The name is in
   the message.
7. **Arm D's "no GPU frame" guard is cold-switch-only** (adaptation 2). If arm D silently
   stops painting *mid-run*, the guard will not catch it — the signal is
   `gpu submits=0 of 30 frames` on D's pan or zoom line while arm C's reads 30. Worth an
   explicit look when reading the transcript.
8. Nothing here has run on a GPU. Every claim in this report is about `flutter test`,
   `analyze` and `format`; the four new phases have never executed, by design.

---

# Fix round 1 — review findings addressed

Commit: `9914f6b` — `fix(harness): the alloc probe settles the band, the band exit waits for its landing, and the verdict says what it sums`
Base: `635e3e7`. Files touched: `apps/dev_harness_2d/lib/gpu_arm.dart`,
`apps/dev_harness_2d/test/gpu_widget_arm_test.dart`. Nothing else.

## Finding 1 — the alloc settle loop exited in the gap before the mark

**The finding is right, and the mechanism is exactly as stated.** The old loop watched
`pending == null && !inFlight`. A rebuild that lands mid-loop calls `notifyListeners()`, which
is merged into `_repaint`; it is the *next* frame's `noteFrame` that reads the ratio (0.49
after `band back`) and calls `markDirty(band)`. Between the landing and that next frame both
flags are clear, so the loop exited there and the walk ran inside a "quiet" pump, with the
upload still in flight when `probe.reset()` ran.

**What changed** (`gpu_arm.dart`, the Criterion 5 block):

```dart
final settling = state.widgetRebuilder!;
var pumps = 0;
var quiet = 0;
while (quiet < 2) {
  if (pumps >= 300) {
    throw StateError('GSPIKE ${GpuSpikeArm.widget.label} | alloc: the '
        'rebuilder did not go quiet in $pumps frames (pending='
        '${settling.pending?.name} inFlight=${settling.inFlight} '
        'inBand=${settling.inBand(state.camera.value)}). The probe would '
        'have measured a document walk, not a frame.');
  }
  await pumpFrame();
  pumps++;
  final busy = settling.pending != null ||
      settling.inFlight ||
      !settling.inBand(state.camera.value);
  quiet = busy ? 0 : quiet + 1;
}
```

`!inBand(state.camera.value)` is now in the condition, so the loop cannot exit while the live
camera is outside the collection's band — nothing can mark `band` from a camera that is inside
it, which closes the gap the finding names. The two quiet pumps are *inside* the loop's exit
condition rather than appended after it: `quiet` resets to 0 on any busy pump, so the loop
exits only after two consecutive pumps that changed nothing. Bounded at 300 pumps with a throw
that names all three flags. Two comment blocks in the code state both reasons, so the next
reader does not re-derive them.

The throw is deliberately **outside** the probe's `try` (below): a rig that cannot reach a
quiet frame has not measured anything, and that is a run-level defect, not an UNEVALUABLE
reading.

## Finding 2 — the band-exit phase now waits for its landing (Ruling F9-a)

The brief's fixed 40-step `phase()` call is gone. Replaced by a named local
`bandExitPhase()`, and the timing capture was **factored out of `phase()`** rather than
duplicated: a new local `capture(arm, name, body)` arms the `FrameTimingLog`, establishes the
baseline, runs `body` (which pumps every measured frame through the log itself and returns how
many it pumped), drains, applies the native backlog refusal, and returns
`({build, raster, unalignedExcess})`. `phase()` is now a thin caller of it with a fixed loop;
its `frameCount` parameter is deleted, since nothing needs it any more. One copy of the
backlog rule, so the two phases cannot drift apart on it.

`bandExitPhase()`:

- `setArm(widget)`, camera to base, two pumps, `r.bandStaleFrames = 0`, `landedBefore`,
  `framesAtStart`.
- Steps `camera.zoomAt(centre, 1.02)` **one step per pumped frame**, through the log, capped
  at 200. `exitStep` is recorded as the first step whose `!r.inBand(state.camera.value)` is
  true, **checked after the zoom and before the pump** — so it names the first frame *drawn*
  out of band, the same frame `noteFrame` counts into `bandStaleFrames`.
- Breaks the moment `r.landed != landedBefore`, recording `landedAtStep` and
  `staleFrames = r.bandStaleFrames` at that instant (before the drain frames, which would keep
  counting).
- Throws `GSPIKE D residentGpu (DraftCanvas) | bandexit | no rebuild landed within 200 steps
  (exitStep=N) ...` if the loop hits the cap.
- Prints three lines: `... | bandexit | build  <stats>`, `... | bandexit | raster <stats>`
  (over all stepped frames), and
  `... | bandexit | exitStep=N landedAtStep=M staleFrames=S submits=K lastTrigger=band
  (criterion 9: the stale interval after a mid-gesture band exit, reported without a
  threshold)`.
- Not appended to `reports`; its doc comment says why (a variable-length window beside three
  fixed-length ones would misread as a fourth row of the per-repeat table).

`submits` is the `backendOf(widget).frames` delta across the phase, the same figure and the
same convention `phase()` uses (drain frames included in both).

## Finding 3 — the alloc verdict says what it sums

```
GSPIKE alloc: arm=D residentGpu (DraftCanvas) perFrame=... patches=N (the LAST frame's
patchesRendered, not a sum) budget=B (kAllocFixed=40 + kAllocPerPatch=24 x P) -> PASS|MISS |
frames=30 classes=C total=T -- read the per-class lines above before believing a MISS: the sum
includes the rig's own per-frame ViewportTransform (camera.panBy) and dart:ui compositing
objects, which are not the resident frame path
```

The `GSPIKE alloc:` and `GSPIKE alloc |` keys are unchanged, so a grep written against them
still works; the arm is named inside the line instead (see minor (c)).

## Minors — all five taken

**(a)** `rebuildPhase` now checks `r.uploadFailed` **before** the landing count and throws
naming the upload failure. This is load-bearing, not cosmetic: `rebuildNow` increments
`landed` even when the uploader returned null
(`packages/jet_cad_2d_flutter/lib/src/gpu/resident_rebuilder.dart` — `_uploadFailed = true`
sits *above* `landed++`), so a failed upload reads as a perfectly ordinary landed rebuild and
the old code would have blamed whichever trigger came next. The comment in the code records
that ordering.

**(b)** Both `var frames = 0` locals renamed to `waited` (in `setArm` and in `rebuildPhase`),
along with every interpolation of them — they shadowed `runGpuSpike`'s own `frames` parameter.

**(c)** `GSPIKE D rebuild | ...`, `GSPIKE D | bandexit | ...` and the two `bandexit`/`alloc`
throws now interpolate `GpuSpikeArm.widget.label` (`D residentGpu (DraftCanvas)`). The alloc
summary keeps its `GSPIKE alloc:` key and names the arm as `arm=<label>` instead, so minor (d)'s
literal `GSPIKE alloc: UNEVALUABLE -- $error` string is still exactly that.

**(d)** `connect()`, `reset()`, the 30 pan frames, `read()` and `dispose()` are now inside one
`try`; any throw prints `GSPIKE alloc: UNEVALUABLE -- $error` and the run continues to
`GSPIKE done`. The comment states the reason: those are all RPCs over the same socket.

**(e)** New test, `test/gpu_widget_arm_test.dart`:
`a sweep needs its own probe handle: the second CommandApplied under the first one throws`.
It fires the **full six-trigger document sweep** under one handle (not merely two adds in a
row), then asserts the second `CommandApplied` under that same handle throws
`DuplicateHandleError` (exact type name confirmed at
`packages/jet_cad_2d/lib/src/store/entity_store.dart:15`, exported from `jet_cad_2d.dart:52`),
and that one under a fresh `doc.handleSeed.next()` `returnsNormally`. That is the witness for
the per-sweep-handle adaptation.

## Covering test output

New test, green (all five in the file):

```
00:00 +0: BACKEND parses residentGpu, and still refuses a typo
00:00 +1: four arms, four distinct labels, and D names the widget
00:00 +2: fireDocumentTrigger emits the DocChange its name says
00:00 +3: a sweep needs its own probe handle: the second CommandApplied under the first one throws
00:00 +4: the allocation budget is the enumerated exception set, generously
00:00 +5: All tests passed!
```

Mutation proving the new test has teeth — `fireDocumentTrigger`'s `CommandApplied` case changed
from `handle: probe` to `handle: doc.handleSeed.next()`, i.e. the defect the adaptation exists
to avoid, inverted:

```
00:00 +3 -1: a sweep needs its own probe handle: the second CommandApplied under the first one throws [E]
  Expected: throws <Instance of 'DuplicateHandleError'>
    Actual: <Closure: () => void>
00:00 +4 -1: Some tests failed.
```

Reverted from a byte copy (`grep -c MUTATION lib/gpu_arm.dart` → `0`) and re-run green before
the gates.

Findings 1 and 2 are device-run behaviour and are **not** covered by a `flutter test` — the
settle loop and the band-exit loop both need a live `ResidentRebuilder` with a real uploader,
which `flutter_tester` has no GPU for. They are covered by construction and by reading, and by
Task 10's transcript: the `exitStep`/`landedAtStep`/`staleFrames` triple and the settle
throw's three-flag message are both self-describing if either is wrong.

## The nine gates

```
$ cd /Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/apps/dev_harness_2d && flutter test --concurrency=1
00:16 +82: All tests passed!
GATE1 harness flutter test EXIT=0

$ cd /Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/apps/dev_harness_2d && flutter analyze
No issues found! (ran in 1.1s)
GATE2 harness flutter analyze EXIT=0

$ cd /Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/apps/dev_harness_2d && dart format --output=none --set-exit-if-changed .
Formatted 22 files (0 changed) in 0.04 seconds.
GATE3 harness dart format EXIT=0

$ cd /Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/packages/jet_cad_2d_flutter && flutter test
00:09 +664 ~1: All tests passed!
GATE4 flutter test EXIT=0

$ cd /Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/packages/jet_cad_2d_flutter && flutter analyze
No issues found! (ran in 1.2s)
GATE5 flutter analyze EXIT=0

$ cd /Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/packages/jet_cad_2d_flutter && dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.16 seconds.
GATE6 dart format EXIT=0

$ cd /Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/packages/jet_cad_2d && dart test
00:02 +798: All tests passed!
GATE7 dart test EXIT=0

$ cd /Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/packages/jet_cad_2d && dart analyze
No issues found!
GATE8 dart analyze EXIT=0

$ cd /Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/packages/jet_cad_2d && dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.14 seconds.
GATE9 dart format EXIT=0
```

`git status --short` before the commit — no `analysis_options.yaml`:

```
 M apps/dev_harness_2d/lib/gpu_arm.dart
 M apps/dev_harness_2d/test/gpu_widget_arm_test.dart
```

Harness suite: 81 → 82 tests.

## Concerns after this round

- **Superseded from the first round:** concern 4 ("`SPIKE_FRAMES` must stay at 30") no longer
  applies to the band-exit phase, which now sets its own step count. It still applies to the
  *arm loop's* zoom phase, where 60 steps would reach 3.28x and land a band rebuild inside a
  measured window. The launch entry pins 30.
- **New, for Task 10:** if the run dies with
  `GSPIKE D residentGpu (DraftCanvas) | alloc: the rebuilder did not go quiet in 300 frames`,
  the three flags in the message say which of the three conditions never cleared —
  `inBand=false` with both flags clear means the collection and the camera disagree with no
  rebuild scheduled, which would be a Task 2/3 defect, not a harness one.
- `exitStep` is expected around 36 and `landedAtStep` a small number of frames after it;
  `staleFrames` should be roughly `landedAtStep - exitStep + 1`. A `staleFrames` far larger
  than that difference means frames were drawn out of band before `exitStep`, i.e. the phase
  did not start in band.
