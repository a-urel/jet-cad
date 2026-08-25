# Plan 3h — the pan frame's fallback walk

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `TileCache`'s live fallback walk the uncovered strip instead of the whole viewport, behind an instrument that can prove the narrowing is correct.

**Architecture:** `TileCache.paintFrame` clips to the uncovered union and then hands `DraftPainter` the full viewport, so every fallback tessellates the whole frame and throws most of it away. A pure `stripFor(uncovered, viewport)` computes a padded, viewport-clamped rectangle; the fallback translates the canvas to it, offsets the camera by the same amount, and passes its size. A new sweep instrument renders partly-baked frames against live ones and proves, per sample, that it exercised a fallback with a strictly interior edge.

**Tech Stack:** Dart, Flutter, `flutter_test`, `flutter drive --profile -d macos`.

**Spec:** [docs/superpowers/specs/2026-08-25-jet-cad-2d-plan-3h-pan-frame-design.md](../specs/2026-08-25-jet-cad-2d-plan-3h-pan-frame-design.md) at `c4ff51e`.

## Global Constraints

- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three of them in this workspace. Check `git status` after any pub operation.
- **Never synthesize test output.** Reviewers verify claims independently; a fabricated transcript invalidates the task.
- **Never `git checkout` a file to revert a mutation.** Copy the file aside, mutate, restore from the copy. Sanctioned exception: `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`, which `flutter drive` rewrites every run.
- **Prefix every test command with `CI=true`** — otherwise Dart's analytics phone-home blocks the runner for minutes at ~0% CPU.
- **The frame path allocates nothing per entity in steady state, and O(1) per flush.**
- **Draw order is ascending handle value**, stable across undo, save, load and purge.
- **Geometric *decisions* use `Tolerance`; *stored value* comparisons are exact `==`.**
- `unused_import` is an **ERROR** in `packages/jet_cad_2d_flutter`.
- **`package:jet_cad_2d` is pure Dart** — no Flutter, no `dart:ui`, ever. **This plan does not touch it.**
- **No pre-existing golden PNG may be regenerated.**
- Code, comments and commit messages in English.
- **This plan may not amend `CLAUDE.md`.**
- **This plan adds no mutable field to `TileCache`.** It already carries two documented test-only mutable fields (`:319`, `:333`) and the bar recorded in Plan 3g is that a third triggers revisiting the design. A **read-only getter** is permitted; `tilesHolding` is the precedent.
- Every task ends green:
  ```sh
  cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
  cd apps/dev_harness_2d && flutter analyze && dart format --output=none --set-exit-if-changed .
  ```

---

## File Structure

| file | responsibility |
|---|---|
| `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` | `stripFor`, the narrowed fallback, `debugLastStrip` |
| `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart` | `fillingGrid` — the first fixture that fills the viewport |
| `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart` | `FallbackSample`, `measureFallbackAgreement` |
| `packages/jet_cad_2d_flutter/test/tile_fallback_test.dart` | criteria 1, 1b, 2, 2b, 2c |
| `packages/jet_cad_2d_flutter/test/tile_cache_test.dart` | `stripFor`'s unit tests (criterion M1) |
| `apps/dev_harness_2d/lib/main.dart` | `_doubleDefine`, `kPanStep` |
| `apps/dev_harness_2d/lib/measurement_rig.dart` | `PAN_STEP` at the tile phase only |
| `STATUS.md` | G3 → 3i, vertex buffer → 3j |
| `docs/superpowers/notes/2026-08-25-plan-3h-results.md` | results of record |
| `docs/superpowers/notes/plan-3h-mutation-log.md` | M1–M4 |

---

### Task 1: The baseline, and the map the next session reads

**Files:**
- Modify: `STATUS.md`
- Create: `docs/superpowers/notes/2026-08-25-plan-3h-results.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the three baseline `tile pan` p95 figures Task 7's criterion 3 divides by.

**Why this is first.** Criterion 3 is a ratio of baseline to narrowed on **one machine**. Quoting the spike's 43.13 ms across machines and days would make it a cross-session comparison, which is the weakness the ratio exists to avoid. And `STATUS.md` still tells every session that Plan 3g's G3 is this plan's job; `CLAUDE.md` instructs every session to read `STATUS.md` first, so a stale line there outlives any note.

- [ ] **Step 1: Confirm Low Power Mode is off**

```sh
pmset -g | grep -i lowpower
```

Expected: `lowpowermode         0`. If it reads `1`, stop and tell the controller — every timing in this plan would be contaminated and `STATUS.md` records a uniform ~24% skew from it.

- [ ] **Step 2: Record the baseline, three runs**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d
for i in 1 2 3; do
  caffeinate -dimsu flutter drive --profile -d macos \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/frame_timing_test.dart \
    --dart-define=ENTITIES=500000 --dart-define=TILES=on \
    > /tmp/3h_baseline_$i.log 2>&1
  echo "run$i exit=$?"
done
grep -A4 "tile pan" /tmp/3h_baseline_*.log | grep "total "
```

`caffeinate` is not optional: a run that sleeps mid-phase hangs at 0% CPU and its `pumpFrame` never returns.

Expected: three `total  p50=... p95=...` lines. The spike measured p95 ≈ 43.13 ms; anything within a factor of two of that is a usable baseline. If a run reports `DriverError: ... Service has disappeared`, discard it and re-run — R4b at 500,000 entities sits on the driver's timeout and loses a run occasionally.

- [ ] **Step 3: Write the results note's baseline section**

Create `docs/superpowers/notes/2026-08-25-plan-3h-results.md`:

```markdown
# Plan 3h results

**Spec:** [2026-08-25-jet-cad-2d-plan-3h-pan-frame-design.md](../specs/2026-08-25-jet-cad-2d-plan-3h-pan-frame-design.md)

## Baseline, recorded before any change

Machine: macOS, `flutter drive --profile -d macos`, Low Power Mode `0`.
Commit: <the SHA this task started from>.

| run | `tile pan` p95 |
|---|---|
| 1 | <ms> |
| 2 | <ms> |
| 3 | <ms> |

Median: **<ms>**. Criterion 3 divides this by the narrowed arm's median.
```

Replace every `<...>` with a measured figure. **Do not copy the spike's numbers** — the point of this task is that these came off this machine.

- [ ] **Step 4: Renumber the roadmap in `STATUS.md`**

`STATUS.md` currently carries, inside the Plan 3g block, a line assigning G3 to this plan, and a "Resume here" item 3 about the vertex buffer. Find them:

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad
grep -n "It is Plan 3h\|G3" STATUS.md
```

Edit so that:
- the G3 line reads that **Plan 3g assigned G3 to 3h and it now belongs to Plan 3i**, with one clause saying why: the 2026-08-25 high-water measurement showed memory is not a consequence of the pan frame, so the pan frame can be finished without settling zoom;
- the vertex buffer is named as **Plan 3j**;
- Plan 3h is described as **the fallback walk and its instrument, nothing else**.

Do not restructure the file. Three edits, each a sentence or two.

- [ ] **Step 5: Verify nothing else changed**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad && git status --porcelain
```

Expected: exactly `M STATUS.md` and `?? docs/superpowers/notes/2026-08-25-plan-3h-results.md`. **If `analysis_options.yaml` appears, do not stage it.**

- [ ] **Step 6: Commit**

```sh
git add STATUS.md docs/superpowers/notes/2026-08-25-plan-3h-results.md
git commit -m "docs: Plan 3h's baseline, and G3 moves to 3i

Criterion 3 is a ratio on one machine, so the baseline is measured here
rather than quoted from the spike across machines and days.

STATUS.md still told every session that Plan 3g's G3 belongs to this plan.
The 2026-08-25 high-water measurement showed memory is not a consequence of
the pan frame, which is what licenses finishing the pan frame without zoom.
G3 is Plan 3i and the vertex buffer is Plan 3j."
```

---

### Task 2: `fillingGrid`, the first fixture that fills the viewport

**Files:**
- Modify: `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`
- Modify: `packages/jet_cad_2d_flutter/test/tile_cache_test.dart` (one test)

**Interfaces:**
- Consumes: `tileCamera()`, `kTileViewport`, `kTileDpr`, `addLine` from `test/support/fixtures.dart`.
- Produces: `DraftDocument fillingGrid(FlutterTextMeasurer measurer)`.

**Why.** Three attempts to catch a crippled query failed, and all three failed for one reason: **a loss is only visible where the uncovered union's boundary is interior to the drawing.** `crossingGrid` spans world x 10..200, which at `tileCamera`'s scale of 1.4 is screen **-23..243** inside a 400 px viewport (`sx = 1.4x - 37`). The drawing does not fill the frame, so a strip entering from any edge lands outside it.

The visible world box at `tileCamera` is x ∈ [26.4, 312.1], y ∈ [16.4, 230.7]. A grid spanning world **20..320 by 10..240** strictly contains it on all four edges.

- [ ] **Step 1: Write the failing test**

In `packages/jet_cad_2d_flutter/test/tile_cache_test.dart`, add inside `main()`:

```dart
  test('fillingGrid covers every edge of the viewport', () async {
    // The property three earlier fixtures lacked, asserted rather than
    // assumed: ink within one tile of all four viewport edges. Without it a
    // strip entering from an edge lands outside the drawing and no crippled
    // query can lose anything -- which is exactly what `crossingGrid`,
    // a pan, and a zoom-then-pan each demonstrated.
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: fillingGrid(measurer));
    addTearDown(rig.dispose);

    final pixels = await captureLiveFrame(rig);
    final width = (kTileViewport.width * kTileDpr).round();
    final height = (kTileViewport.height * kTileDpr).round();
    // 64 device pixels: one tile at this rig's size.
    const band = 64;

    bool inkIn(int x0, int y0, int x1, int y1) {
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          if (pixels[(y * width + x) * 4 + 3] != 0) return true;
        }
      }
      return false;
    }

    expect(inkIn(0, 0, band, height), isTrue, reason: 'left edge');
    expect(inkIn(width - band, 0, width, height), isTrue, reason: 'right edge');
    expect(inkIn(0, 0, width, band), isTrue, reason: 'top edge');
    expect(inkIn(0, height - band, width, height), isTrue, reason: 'bottom');
  });
```

- [ ] **Step 2: Run it and watch it fail**

```sh
cd /Users/ahmeturel/Projects/oss/jet_cad_2d_flutter 2>/dev/null || cd /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter
CI=true flutter test test/tile_cache_test.dart --plain-name "fillingGrid covers"
```

Expected: a **compile error**, `The function 'fillingGrid' isn't defined`. That is the correct first failure.

- [ ] **Step 3: Write the fixture**

Append to `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`:

```dart
/// A grid that fills [kTileViewport] at [tileCamera], which no other fixture
/// here does.
///
/// **This is the property that makes a crippled query detectable, and its
/// absence is why three earlier arrangements could not detect one.** A loss in
/// the live fallback is only visible where the uncovered union's boundary is
/// *interior to the drawing*: a strip entering across empty canvas has no ink
/// to lose. [crossingGrid] spans world x 10..200, which at this camera's 1.4
/// is screen -23..243 inside a 400 px viewport -- off the left edge and short
/// of the right -- so a pan in any direction brings in empty space.
///
/// The visible world box here is x in [26.4, 312.1] and y in [16.4, 230.7];
/// 20..320 by 10..240 strictly contains it on all four edges.
///
/// Lines rather than a fill, and axis-aligned rather than diagonal: this
/// fixture carries the arm that must agree **exactly**, so it must not import
/// the near-axis slope disagreement [nearAxisDiagonals] measures.
DraftDocument fillingGrid(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  var handle = 1000;
  // 16 units apart: half a tile's 32 logical pixels at this camera's 1.4 is
  // 22.9 world units, so no tile-sized strip anywhere in the frame can be
  // empty of ink.
  for (var t = 10.0; t <= 240.0; t += 16.0) {
    addLine(doc, doc.rootHandle, Handle(handle++), 20, t, 320, t);
  }
  for (var t = 20.0; t <= 320.0; t += 16.0) {
    addLine(doc, doc.rootHandle, Handle(handle++), t, 10, t, 240);
  }
  return doc;
}
```

- [ ] **Step 4: Run it and watch it pass**

```sh
CI=true flutter test test/tile_cache_test.dart --plain-name "fillingGrid covers"
```

Expected: `+1: All tests passed!`

- [ ] **Step 5: Prove the test is not vacuous**

Copy the fixture file aside, change `fillingGrid`'s horizontal loop bound from `240.0` to `120.0`, re-run, confirm the **bottom edge** assertion fails, then restore from the copy:

```sh
cp test/support/tile_fixture.dart /tmp/tile_fixture.orig
# edit: 240.0 -> 120.0 in fillingGrid's first loop
CI=true flutter test test/tile_cache_test.dart --plain-name "fillingGrid covers"
cp /tmp/tile_fixture.orig test/support/tile_fixture.dart
```

Expected while mutated: `bottom` fails. **`git checkout` is forbidden for this; restore from the copy.**

- [ ] **Step 6: Full suite, analyze, format, commit**

```sh
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add test/support/tile_fixture.dart test/tile_cache_test.dart
git commit -m "test: fillingGrid, the first fixture that fills the viewport

Three arrangements failed to detect a deliberately crippled fallback query and
all three failed for one reason: a loss is only visible where the uncovered
union's boundary is interior to the drawing. crossingGrid is screen -23..243
in a 400 px viewport, so a strip entering from any edge lands outside it.

The edge assertions are proved non-vacuous by shortening the fixture and
watching the bottom edge fail."
```

---

### Task 3: The fallback sweep, gating today's code

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` (one read-only getter)
- Modify: `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`
- Create: `packages/jet_cad_2d_flutter/test/tile_fallback_test.dart`

**Interfaces:**
- Consumes: `fillingGrid`, `TileRig`, `InkReport`, `nearAxisDiagonals`.
- Produces:
  - `Rect? TileCache.debugLastStrip` — the rectangle the **shipped** `paintFrame` handed the fallback on its most recent frame, or `null` if no fallback ran.
  - `Future<InkReport> measureFallbackAgreement(TileRig rig)` — one sample.
  - `Future<List<InkReport>> sweepFallbackAgreement({required DraftDocument Function(FlutterTextMeasurer) of, required List<Offset> offsets})`.

**Why the getter is read from the shipped path.** Plan 3g's rig computed its own bake geometry in `_probeBake` instead of calling `_bake`, so its overdraw column described a reimplementation rather than the shipped code. A test that recomputed the strip from the grid would repeat that exactly. **This getter is read-only, so it is not the third mutable field the global constraints refuse.**

**Why each sample gets its own cache.** A sweep that pans one rig across offsets inherits tiles from the previous offset and quietly becomes a warm-tile comparison — which is one of the three failures Task 2's fixture exists to fix.

**Why `bakeCount == 1` is not enough.** `uncovered` is a **bounding rectangle** (`tile_cache.dart:742-744` accumulates with `expandToInclude`), so a diagonal pan's L-shaped uncovered set can bound to the whole viewport. After clamping there is no interior boundary at all, and a crippled query stays pixel-correct while both counters read exactly what a naive rule demands. Every sample must therefore prove `strip != viewport`.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d_flutter/test/tile_fallback_test.dart`:

```dart
// Criteria 1, 1b, 2, 2b and 2c: the live fallback, which no pixel gate in this
// repository has ever executed.
//
// **Every pixel comparison in `tile_cache_test.dart` runs at
// `tilesBakedPerFrame: 1000`**, where the first frame bakes the whole visible
// set, `uncovered` is null, and `paintFrame`'s fallback never runs at all. The
// two restricted-budget tests that do reach it assert counters. So the one
// composition this cache produces that nothing checked the pixels of is the
// frame that is part blit and part live walk -- which is also the frame where
// the two paths meet along a seam.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'support/tile_comparison.dart';
import 'support/tile_fixture.dart';

// **No `jet_cad_2d_flutter` import here**, and it is not an oversight: this
// file names no symbol from it, and `unused_import` is an **error** in this
// package rather than a warning. Add one only when a symbol needs it.

/// Offsets that are not multiples of the tile's **logical** size.
///
/// A tile is `tileDevicePixels / devicePixelRatio` logical pixels -- 32 at this
/// rig's 64 device pixels and [kTileDpr] of 2, not 64. An offset on that
/// lattice would put the strip boundary exactly on a tile edge at every
/// sample and the sweep would measure one arrangement N times.
///
/// Each is a single-axis pan. A diagonal pan brings in a row *and* a column,
/// and `uncovered` is a bounding rectangle, so the union bounds to the whole
/// viewport and the sample has no interior edge to lose anything across.
const List<Offset> kFallbackOffsets = <Offset>[
  Offset(37, 0),
  Offset(53, 0),
  Offset(71, 0),
  Offset(0, 37),
  Offset(0, 53),
  Offset(0, 71),
  Offset(-41, 0),
  Offset(0, -41),
];

void main() {
  test('criterion 2 and 2c: a partly baked frame equals the live frame',
      () async {
    final reports = await sweepFallbackAgreement(
        of: fillingGrid, offsets: kFallbackOffsets);

    expect(reports, hasLength(kFallbackOffsets.length));
    for (var i = 0; i < reports.length; i++) {
      final report = reports[i];
      expect(report.strayPixels, 0, reason: '${kFallbackOffsets[i]}: $report');
      expect(report.uncoveredPixels, 0,
          reason: '${kFallbackOffsets[i]}: $report');
      expect(report.differingPixels, 0,
          reason: '${kFallbackOffsets[i]}: $report');
    }
  });

  test('criterion 2b: the near-axis arm stays inside the tiled path\'s bound',
      () async {
    // The reference is not invented here: `tile_cache_test.dart` gates the
    // tiled path on this same fixture at `differingPixels <= 60` against a
    // measured 36 of 10342 ink, 0.348%. The fallback arm is held to the same
    // number, so an increase is a tripwire rather than a silent record.
    final reports = await sweepFallbackAgreement(
        of: nearAxisDiagonals, offsets: kFallbackOffsets, minimumInk: 200);

    for (var i = 0; i < reports.length; i++) {
      final report = reports[i];
      expect(report.differingPixels, lessThanOrEqualTo(60),
          reason: '${kFallbackOffsets[i]}: $report');
      expect(report.differingPixels / report.liveInk, lessThan(0.01),
          reason: '${kFallbackOffsets[i]}: $report');
    }
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```sh
CI=true flutter test test/tile_fallback_test.dart
```

Expected: a compile error, `The function 'sweepFallbackAgreement' isn't defined`.

- [ ] **Step 3: Add the read-only getter to `TileCache`**

In `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`, beside `tilesHolding`, add the field and getter:

```dart
  /// The rectangle the fallback walked on the most recent frame, or `null` if
  /// no fallback ran. Test-only, and **read-only**.
  ///
  /// Read from the shipped `paintFrame` rather than recomputed by a test, and
  /// that is the whole point of it. Plan 3g's rig reimplemented the bake
  /// geometry in `_probeBake` instead of calling `_bake`, so its overdraw
  /// column described the reimplementation and not the code that ships. A
  /// sweep that derived this rectangle from [TileGrid] would repeat that.
  ///
  /// **A getter, not a mutable field.** `TileCache` already carries two
  /// mutable test-only fields and the standing bar is that a third triggers
  /// revisiting the design; `tilesHolding` is the precedent for reading state
  /// out without adding a way to write it.
  Rect? get debugLastStrip => _lastStrip;

  Rect? _lastStrip;
```

Then in `paintFrame`, set it. Two sites, and **both are required**:

- immediately after `_frameSerial++`, add `_lastStrip = null;` — so a frame that runs no fallback reports `null` rather than the previous frame's rectangle;
- in the fallback branch, immediately before `_drawInto(...)`, add `_lastStrip = <the rectangle passed>;`. In today's code that rectangle is the whole viewport, so write `_lastStrip = Offset.zero & viewport;`.

- [ ] **Step 4: Write the sweep instrument**

Append to `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`:

```dart
/// One fallback sample: a frame that is part blit and part live walk, compared
/// against the live frame at the same camera.
///
/// **Each sample owns its cache.** A sweep that panned one rig across offsets
/// would inherit tiles from the previous offset and become a warm-tile
/// comparison -- one of the three arrangements that failed to detect a
/// crippled query before this instrument existed.
Future<InkReport> measureFallbackAgreement(
  DraftDocument Function(FlutterTextMeasurer) of,
  FlutterTextMeasurer measurer,
  Offset pan, {
  int minimumInk = 500,
}) async {
  final rig = TileRig(
      tileDevicePixels: 64,
      tilesBakedPerFrame: 1000,
      document: of(measurer));
  try {
    // Cover the viewport, so the strip that enters next has blitted tiles on
    // its interior side.
    rig.paintOnce();
    rig.cache.resetCounters();
    // One tile a frame, so the entering band stays uncovered and the fallback
    // owes it.
    rig.cache.bakeBudgetDevicePixels = 64 * 64;
    rig.panBy(pan.dx, pan.dy);

    final report = await measureTiledAgreement(rig);

    // Anti-vacuity, and every clause of it was earned by an arrangement that
    // passed while proving nothing.
    expect(rig.cache.liveDrawCount, greaterThan(0),
        reason: 'pan $pan ran no fallback: $report');
    expect(rig.cache.blitCount, greaterThan(0),
        reason: 'pan $pan blitted nothing, so nothing was partly baked');
    final strip = rig.cache.debugLastStrip;
    expect(strip, isNotNull, reason: 'pan $pan recorded no strip');
    // The clause `bakeCount`/`liveDrawCount` cannot supply: `uncovered` is a
    // bounding rectangle, so an L-shaped uncovered set bounds to the whole
    // viewport and leaves no interior edge for a crippled query to lose ink
    // across.
    expect(strip != Offset.zero & kTileViewport, isTrue,
        reason: 'pan $pan left no interior strip edge: strip=$strip');
    expect(report.liveInk, greaterThan(minimumInk), reason: '$report');
    expect(report.tiledInk, greaterThan(minimumInk), reason: '$report');
    return report;
  } finally {
    rig.dispose();
  }
}

/// [measureFallbackAgreement] over a set of pan offsets, each independent.
Future<List<InkReport>> sweepFallbackAgreement({
  required DraftDocument Function(FlutterTextMeasurer) of,
  required List<Offset> offsets,
  int minimumInk = 500,
}) async {
  final reports = <InkReport>[];
  for (final offset in offsets) {
    final measurer = FlutterTextMeasurer();
    try {
      reports.add(await measureFallbackAgreement(of, measurer, offset,
          minimumInk: minimumInk));
    } finally {
      measurer.clear();
    }
  }
  return reports;
}
```

Add `import 'package:jet_cad_2d/jet_cad_2d.dart';` to that file if `DraftDocument` is not already in scope.

- [ ] **Step 5: Run it and watch it pass on today's code**

```sh
CI=true flutter test test/tile_fallback_test.dart
```

Expected: **both tests pass.** Today's fallback walks the whole viewport, which is wasteful and correct — the instrument is being installed against known-good behaviour so that Task 5's change is what moves it.

**If criterion 2c's `strip != viewport` assertion fails for some offset**, that offset produced an uncovered union bounding to the whole frame. Replace that offset with a smaller single-axis one and record the substitution in the task report; do not weaken the assertion.

- [ ] **Step 6: Full suite, analyze, format, commit**

```sh
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add lib/src/tile_cache.dart test/support/tile_comparison.dart test/tile_fallback_test.dart
git commit -m "test: a sweep that executes the live fallback, which no pixel gate ever has

Every pixel comparison in this suite runs at a budget that covers the viewport,
so paintFrame's fallback has never run under one. The two restricted-budget
tests that reach it assert counters.

Each sample owns its cache, so the sweep cannot decay into a warm-tile
comparison, and each asserts a strictly interior strip edge -- because
uncovered is a bounding rectangle and an L-shaped uncovered set bounds to the
whole viewport, where a crippled query loses nothing.

The strip is read from the shipped paintFrame through a read-only getter, never
recomputed from the grid: Plan 3g's rig reimplemented its bake geometry and its
overdraw column described the reimplementation."
```

---

### Task 4: `stripFor`, the arithmetic half

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Modify: `packages/jet_cad_2d_flutter/test/tile_cache_test.dart`

**Interfaces:**
- Produces: `Rect stripFor(Rect uncovered, Size viewport)` — top-level, public, in `tile_cache.dart`.

**Why a pure function.** It converts the clamp from a device observation into a unit assertion. Mutant **M1** — drop the clamp — has no other witness: the fallback's pixels are identical either way and only its cost and the vertex buffer's high-water mark move.

- [ ] **Step 1: Write the failing tests**

In `packages/jet_cad_2d_flutter/test/tile_cache_test.dart`, add inside `main()`:

```dart
  group('stripFor', () {
    const viewport = Size(400, 300);

    test('pads an interior rect on every side', () {
      // kTileSlack is 32.0. An interior rect keeps the whole pad, because a
      // stroke whose centreline is outside the strip still inks pixels inside
      // it -- the reason `_bake` pads its own query.
      expect(stripFor(const Rect.fromLTRB(100, 80, 200, 180), viewport),
          const Rect.fromLTRB(68, 48, 232, 212));
    });

    test('clamps to the viewport rather than growing past it', () {
      // The mutant this exists for. A union that already spans the frame,
      // padded, would ask for 464 x 364 where the untiled path asks for
      // 400 x 300 -- a third more area than the baseline the narrowing is
      // meant to undercut, measured as the vertex buffer doubling to 384 MiB.
      expect(stripFor(Offset.zero & viewport, viewport), Offset.zero & viewport);
    });

    test('clamps one edge at a time', () {
      // A band entering from the left: clamped on the left, padded on the
      // right. Asserting the whole rect rather than one edge, so a mutation
      // that clamped all four sides unconditionally is also caught.
      expect(stripFor(const Rect.fromLTRB(0, 0, 40, 300), viewport),
          const Rect.fromLTRB(0, 0, 72, 300));
    });

    test('a strip touching the bottom-right clamps there and pads inward', () {
      expect(stripFor(const Rect.fromLTRB(360, 260, 400, 300), viewport),
          const Rect.fromLTRB(328, 228, 400, 300));
    });
  });
```

- [ ] **Step 2: Run them and watch them fail**

```sh
CI=true flutter test test/tile_cache_test.dart --plain-name "stripFor"
```

Expected: a compile error, `The function 'stripFor' isn't defined`.

- [ ] **Step 3: Write the function**

Add to `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`, top level, near `kTileSlack`. Add `import 'dart:math' as math;` if it is not already imported.

```dart
/// The rectangle the live fallback walks: [uncovered] grown by [kTileSlack] on
/// every side, then clamped to [viewport].
///
/// **The pad**, for `_bake`'s reason: a stroke whose centreline is outside the
/// rectangle still inks pixels inside it, and the painter's index query is a
/// rect intersection on entity bounds. `_bake` states the rule at its own call
/// site -- "The query is padded; the clip is not." Plan 3g's F1 is what an
/// unpadded query cost, at six of forty-one swept zoom factors.
///
/// **The clamp**, and it was found by measuring rather than by reasoning.
/// `uncovered` is a *bounding rectangle* (`paintFrame` accumulates it with
/// `expandToInclude`), so an L-shaped uncovered set bounds to the whole frame;
/// padding that asks for 464 x 364 logical pixels where the untiled path asks
/// for 400 x 300. An unclamped arm doubled the vertex buffer's high-water mark
/// from 192.00 MiB to 384.00 on a run whose every other counter matched.
/// **The pad belongs on interior edges; on the viewport's own edge the
/// full-frame walk is the ceiling.**
///
/// Pure, so the clamp has a unit witness. Nothing else in this plan can see
/// it: the fallback's pixels are identical clamped or not, and only its cost
/// moves.
Rect stripFor(Rect uncovered, Size viewport) => Rect.fromLTRB(
      math.max(0.0, uncovered.left - kTileSlack),
      math.max(0.0, uncovered.top - kTileSlack),
      math.min(viewport.width, uncovered.right + kTileSlack),
      math.min(viewport.height, uncovered.bottom + kTileSlack),
    );
```

- [ ] **Step 4: Run them and watch them pass**

```sh
CI=true flutter test test/tile_cache_test.dart --plain-name "stripFor"
```

Expected: `+4: All tests passed!`

- [ ] **Step 5: Fire mutant M1**

```sh
cp lib/src/tile_cache.dart /tmp/tile_cache.m1
```

Edit `stripFor` to drop the clamp — replace the two `math.min(...)` arguments with `uncovered.right + kTileSlack` and `uncovered.bottom + kTileSlack`, and the two `math.max(...)` with `uncovered.left - kTileSlack` and `uncovered.top - kTileSlack`. Run:

```sh
CI=true flutter test test/tile_cache_test.dart --plain-name "stripFor"
```

Expected: **three of the four tests fail** — every one except `pads an interior rect`. Record the exact failure output for the mutation log. Restore:

```sh
cp /tmp/tile_cache.m1 lib/src/tile_cache.dart
CI=true flutter test test/tile_cache_test.dart --plain-name "stripFor"
```

- [ ] **Step 6: Full suite, analyze, format, commit**

```sh
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add lib/src/tile_cache.dart test/tile_cache_test.dart
git commit -m "feat: stripFor, the fallback walk's padded and clamped rectangle

Pure, because the clamp has no other witness: the fallback's pixels are
identical clamped or not and only its cost moves. Mutant M1 -- drop the clamp
-- reddens three of the four cases.

The clamp was found by measuring. uncovered is a bounding rectangle built with
expandToInclude, so an L-shaped uncovered set bounds to the whole frame, and
padding that asks for 464 x 364 where the untiled path asks for 400 x 300. An
unclamped arm doubled the vertex buffer to 384 MiB with every other counter
unchanged."
```

---

### Task 5: The narrowing

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Modify: `packages/jet_cad_2d_flutter/test/tile_fallback_test.dart` (criterion 1 and 1b records)

**Interfaces:**
- Consumes: `stripFor`, `debugLastStrip`, the Task 3 sweep.
- Produces: a `paintFrame` whose fallback walks the strip.

**The change.** In `paintFrame`'s fallback branch, replace

```dart
    canvas.save();
    canvas.clipRect(uncovered, doAntiAlias: false);
    _lastStrip = Offset.zero & viewport;
    _drawInto(
        canvas, viewport, quantised, painter, sink, vertices, origin, null);
    canvas.restore();
    _liveDraws++;
```

with

```dart
    canvas.save();
    // **The clip is unchanged, and that is a decision.** `_bake` states the
    // rule for itself -- "The query is padded; the clip is not." Drop this
    // line and the pad becomes overdraw onto tiles already blitted: the pixels
    // stay correct, so the sweep still reads zero, and the cost this whole
    // change exists to remove comes back silently.
    canvas.clipRect(uncovered, doAntiAlias: false);
    // **Walk the union, not the viewport.** The clip above only discards
    // drawing; the walk below is what costs. `DraftPainter.paint` derives its
    // index query from `camera.visibleWorld(viewport)`, so handing it the full
    // viewport tessellates the whole frame and throws most of it away -- which
    // is what every fallback did before this line, and why the frame's excess
    // read as a full live walk.
    final strip = stripFor(uncovered, viewport);
    _lastStrip = strip;
    canvas.translate(strip.left, strip.top);
    final q = quantised.worldToScreenMatrix;
    _drawInto(
        canvas,
        Size(strip.width, strip.height),
        ViewportTransform(
            worldToScreenMatrix: Transform2(
                q.a, q.b, q.c, q.d, q.e - strip.left, q.f - strip.top)),
        painter,
        sink,
        vertices,
        origin,
        null);
    canvas.restore();
    _liveDraws++;
```

The camera offset and the canvas translate cancel: a world point mapping to screen `s` under `quantised` maps to `s - strip.topLeft` under the offset camera, and the translate puts it back. This is `_bake`'s own technique, which already does exactly this for a tile.

- [ ] **Step 1: Apply the change**

Make the edit above.

- [ ] **Step 2: Run the sweep — it must stay green**

```sh
CI=true flutter test test/tile_fallback_test.dart
```

Expected: both tests pass. The narrowing is not supposed to move a pixel.

**If criterion 2 fails**, the camera arithmetic is wrong — check the sign of `q.e - strip.left` against `_bake`'s `bake.e + pad` with its `into.translate(-pad, -pad)`. **If criterion 2b fails**, read the numbers before changing anything: the strip's translate reintroduces the `Float32` / `Float64` asymmetry behind Plan 3g's gap G5, and a bound slightly above 60 is a G5 finding, not a narrowing defect. Report it; do not raise the bound.

- [ ] **Step 3: Fire mutant M3 — criterion 1**

```sh
cp lib/src/tile_cache.dart /tmp/tile_cache.m3
```

In `stripFor`, replace `kTileSlack` with `-20.0` at all four call sites — a query 20 logical pixels **inside** the strip. Run:

```sh
CI=true flutter test test/tile_fallback_test.dart --plain-name "criterion 2 and 2c"
```

Expected: **RED**, with non-zero `uncoveredPixels`. Record the exact numbers. Restore from `/tmp/tile_cache.m3` and confirm green.

**If it stays green, stop and report.** Criterion 1 is the gate that makes every other pixel claim in this plan mean something; a green M3 means the sweep is measuring nothing and the offsets or the fixture need work before anything else proceeds.

- [ ] **Step 4: Fire mutant M2 — criterion 1b**

```sh
cp lib/src/tile_cache.dart /tmp/tile_cache.m2
```

In `stripFor`, replace `kTileSlack` with `0.0` at all four call sites. Run the same test.

**Two outcomes, both acceptable, and the plan pre-commits to each:**

- **RED** — criterion 1b passes. Record the numbers.
- **GREEN** — M2 survives. This is the spec's anticipated gap **H5**, and it is not a failure of this task. `pad = 0` does not delete geometry the way M3's shrink does: the query is a rect intersection on entity bounds, so dropping the pad loses only entities lying wholly outside the strip whose **half stroke width** bleeds into it, and F1 appeared at only six of forty-one swept zoom factors. **Record H5 in the task report with the measured zeros**, keep the pad on `_bake`'s argument, and proceed. Do not invent a fixture to force a kill.

Restore from `/tmp/tile_cache.m2` either way and confirm green.

- [ ] **Step 5: Full suite, analyze, format**

```sh
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

Expected: the same pass count as before this task plus nothing new — the narrowing changes no test's outcome.

- [ ] **Step 6: Commit**

```sh
git add lib/src/tile_cache.dart test/tile_fallback_test.dart
git commit -m "perf: the live fallback walks the uncovered strip, not the viewport

paintFrame clipped to the uncovered union and handed DraftPainter the whole
viewport, and the painter derives its index query from exactly that, so every
fallback tessellated the entire frame and the clip discarded most of it.

The clip is deliberately unchanged: _bake states the rule at its own call site,
and dropping it turns the pad into overdraw onto tiles already blitted, which
the sweep reads as zero because the pixels stay correct.

M3 -- a query shrunk 20 logical pixels -- reddens the sweep, which is what
makes every other pixel claim here mean anything."
```

---

### Task 6: `PAN_STEP`

**Files:**
- Modify: `apps/dev_harness_2d/lib/main.dart`
- Modify: `apps/dev_harness_2d/lib/measurement_rig.dart`

**Interfaces:**
- Produces: `double kPanStep` in `main.dart`, forwarded to `runTilePhases`.

**Four properties, each a defect if omitted:**

1. **A magnitude, not a component.** The rig's step is `Offset(-7, -3)`, magnitude `sqrt(58)` = 7.615773. `PAN_STEP` scales that vector, preserving direction, so every arm meets the tile lattice at the angle every prior number was taken at.
2. **Unset means no scaling at all.** `7.6 / sqrt(58)` is 0.99793, so passing the rounded figure would rescale the historical step and make the arm incomparable with every row already recorded at it.
3. **The tile phase only** (`measurement_rig.dart:523`), never R2's own pan (`:357`). Taking both would make every prior plan's R2 row incomparable.
4. **A throwing parse.** `main.dart` already has `_intDefine` for exactly this reason; a magnitude needs its `double` sibling.

- [ ] **Step 1: Add `_doubleDefine` and `kPanStep`**

In `apps/dev_harness_2d/lib/main.dart`, beside `_intDefine`, add:

```dart
/// [_intDefine]'s sibling, for a define that is not an integer.
///
/// Same rule and the same reason: a silent default writes one run into the
/// table under a heading the command line claimed and the run did not use.
double _doubleDefine(String name, String raw, double fallback,
    {double? minimum}) {
  if (raw.isEmpty) return fallback;
  final value = double.tryParse(raw);
  if (value == null || !value.isFinite) {
    throw ArgumentError.value(raw, name, 'not a finite number');
  }
  if (minimum != null && value < minimum) {
    throw ArgumentError.value(raw, name, 'below $minimum');
  }
  return value;
}

/// The tile-pan phase's speed, in logical pixels per frame.
///
/// **A magnitude along the rig's existing direction, and unset means no
/// scaling at all.** The historical step is `Offset(-7, -3)`, magnitude
/// `sqrt(58)` = 7.615773; `PAN_STEP=7.6` would scale it by 0.99793 and make
/// the arm incomparable with every row already recorded at it. `NaN` is the
/// sentinel for unset because zero is a legal magnitude to ask about.
///
/// It reaches the **tile phase only**. R2's own pan keeps `Offset(-7, -3)`
/// unconditionally, or every prior plan's R2 row becomes incomparable.
final double kPanStep = _doubleDefine(
    'PAN_STEP', const String.fromEnvironment('PAN_STEP'), double.nan,
    minimum: 0);
```

- [ ] **Step 2: Thread it to the tile phase**

In `measurement_rig.dart`, add `required double panStep,` to `runTilePhases`' parameters, and replace the tile-pan call:

```dart
  // `PAN_STEP` unset leaves the historical step untouched -- see `kPanStep`.
  const historical = Offset(-7, -3);
  final magnitude = historical.distance;
  final step = panStep.isNaN
      ? historical
      : Offset(historical.dx * panStep / magnitude,
          historical.dy * panStep / magnitude);
  print('  tile pan step: dx=${step.dx.toStringAsFixed(4)} '
      'dy=${step.dy.toStringAsFixed(4)} '
      'magnitude=${step.distance.toStringAsFixed(4)}');
  await phase('tile pan', 120, step);
```

`:357`'s `camera.panBy(const Offset(-7, -3))` is **not touched**.

In `runR2Rig`, add `panStep: panStep,` to the `runTilePhases(...)` call and `required double panStep,` to `runR2Rig`'s own parameters; pass `kPanStep` from `main.dart`'s call site.

- [ ] **Step 3: Verify the default changes nothing**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d
flutter analyze && dart format --output=none --set-exit-if-changed .
caffeinate -dimsu flutter drive --profile -d macos \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart \
  --dart-define=ENTITIES=50000 --dart-define=TILES=on 2>&1 | grep "tile pan step"
```

Expected: `dx=-7.0000 dy=-3.0000 magnitude=7.6158`. **Any other value means the default rescaled the historical step** and step 1's `isNaN` sentinel is wrong.

- [ ] **Step 4: Verify a bad value throws**

```sh
caffeinate -dimsu flutter drive --profile -d macos \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart \
  --dart-define=ENTITIES=50000 --dart-define=TILES=on \
  --dart-define=PAN_STEP=30px 2>&1 | tail -5
```

Expected: an `ArgumentError` naming `PAN_STEP`. A run that silently proceeds at 7.6 is the exact failure `_intDefine`'s doc comment was written against.

- [ ] **Step 5: Commit**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad
git status --porcelain   # project.pbxproj may appear; do NOT stage it
git add apps/dev_harness_2d/lib/main.dart apps/dev_harness_2d/lib/measurement_rig.dart
git commit -m "feat(rig): PAN_STEP, a magnitude along the rig's existing direction

Criteria 4 and 5 read a band of pan speeds, and the band has to meet the tile
lattice at one angle: an axis-aligned fast pan would measure a different
interaction than the diagonal one every prior number was taken on.

Unset means no scaling at all, not PAN_STEP=7.6 -- 7.6 / sqrt(58) is 0.99793
and would rescale the historical step. It reaches the tile phase only; R2's
own pan is untouched, or every prior plan's R2 row becomes incomparable. The
parse throws, for _intDefine's reason."
```

---

### Task 7: The device measurement, and mutant M4

**Files:**
- Modify: `docs/superpowers/notes/2026-08-25-plan-3h-results.md`

**Interfaces:**
- Consumes: Task 1's baseline, Task 6's `PAN_STEP`.
- Produces: criteria 3, 3b, 4, 5, 6, 7, 8 and M4's ruling.

- [ ] **Step 1: Three runs of the narrowed arm**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d
pmset -g | grep -i lowpower   # must read 0
for i in 1 2 3; do
  caffeinate -dimsu flutter drive --profile -d macos \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/frame_timing_test.dart \
    --dart-define=ENTITIES=500000 --dart-define=TILES=on \
    > /tmp/3h_narrowed_$i.log 2>&1
done
grep -A4 "tile pan" /tmp/3h_narrowed_*.log | grep "total "
grep "tile hold" -A4 /tmp/3h_narrowed_*.log | grep "total "
grep "capacityMiB" /tmp/3h_narrowed_*.log | tail -3
grep "tileBytes" /tmp/3h_narrowed_*.log | tail -3
```

Record: `tile pan` p95 x3 (criterion 3b), `tile hold` p50 and p95 x3 (criterion 6), `capacityMiB` (criterion 8, expected **192.00**), peak `tileBytes` (criterion 7, ≤ 96 MiB).

- [ ] **Step 2: Criterion 3, the ratio**

Compute `median(baseline p95) / median(narrowed p95)`. **Gate: ≥ 2.4.** The spike measured 2.59.

If it lands below 2.4, **do not adjust the threshold.** Report the number, and check first that both arms ran at the same `ENTITIES`, the same `TILES`, and with Low Power Mode off.

- [ ] **Step 3: Criteria 4 and 5, recorded**

```sh
for s in 30 60; do
  caffeinate -dimsu flutter drive --profile -d macos \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/frame_timing_test.dart \
    --dart-define=ENTITIES=500000 --dart-define=TILES=on \
    --dart-define=PAN_STEP=$s > /tmp/3h_step$s.log 2>&1
  echo "== $s =="; grep "tile pan step" /tmp/3h_step$s.log
  grep -A4 "tile pan" /tmp/3h_step$s.log | grep "total "
done
```

**These are recorded, not gates.** Also record `liveDraws` and `bakes` from each, since a faster pan changes the composition and the p95 alone does not say how.

- [ ] **Step 4: Fire mutant M4**

M4 is the original defect: **narrow the clip, not the query.**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter
cp lib/src/tile_cache.dart /tmp/tile_cache.m4
```

In `paintFrame`'s fallback branch, keep `canvas.clipRect(uncovered, ...)` and `_lastStrip = strip;`, but revert the walk to the viewport: drop the `canvas.translate`, and pass `viewport` and `quantised` to `_drawInto` as the code did before Task 5. Then:

```sh
CI=true flutter test test/tile_fallback_test.dart   # must stay GREEN -- M4's pixels are correct
cd /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d
caffeinate -dimsu flutter drive --profile -d macos \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart \
  --dart-define=ENTITIES=500000 --dart-define=TILES=on > /tmp/3h_m4.log 2>&1
grep -A4 "tile pan" /tmp/3h_m4.log | grep "total "
```

Expected: the sweep stays green — **M4 has no unit witness, and confirming that is part of firing it** — and `tile pan` p95 returns to roughly the baseline, so the ratio against Task 1's baseline reads ≈ 1.0 and M4 dies on criterion 3.

Restore from `/tmp/tile_cache.m4` and re-run one narrowed device run to confirm the tree is back.

- [ ] **Step 5: Write the results note**

Fill in the note created in Task 1 with every figure above, one section per criterion, each stating **PASS**, **MISS** or **RECORDED**. State criterion 3b's absolute figures beside the 16.67 ms budget and say plainly whether the plan lands under it — the spike's median was 16.66 with one run at 17.40, and this is the number the spec deliberately declined to gate.

Include the M4 section: the sweep's green result, the device ratio, and the sentence that matters — **an absolute threshold could not have witnessed M4, because correct code fails 16.67 too.**

- [ ] **Step 6: Commit**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad
git add docs/superpowers/notes/2026-08-25-plan-3h-results.md
git commit -m "docs: Plan 3h's device measurements and M4's ruling"
```

---

### Task 8: Close the plan

**Files:**
- Create: `docs/superpowers/notes/plan-3h-mutation-log.md`
- Modify: `STATUS.md`
- Modify: `docs/superpowers/notes/2026-08-25-plan-3h-results.md`

- [ ] **Step 1: Write the mutation log**

Create `docs/superpowers/notes/plan-3h-mutation-log.md` with one section per mutant — M1, M2, M3, M4 — each carrying: the edit as a diff, **the layer it was fired in**, the verbatim output, and the ruling. Plan 3g's most expensive error was firing a mutant on device only while reasoning that the widget suite passed "by construction", so **every section states which suites were actually run under it.**

If M2 survived, its section records gap **H5** with the measured zeros, and says that D2's pad rests on `_bake`'s argument and F1's history rather than on a gate of this plan's own.

- [ ] **Step 2: Run every suite on the final tree**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter && CI=true flutter test && CI=true flutter test --tags golden && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && flutter analyze && dart format --output=none --set-exit-if-changed .
```

**Run them; do not read them off an earlier report.** Record the counts. No pre-existing golden PNG may have been regenerated — `git status` must show no `.png` modified.

- [ ] **Step 3: Update `STATUS.md`**

Add a Plan 3h section carrying: the exit gate as *n* of the criteria table, criterion 3's ratio, criterion 3b's absolute figures against 16.67 ms stated as a near-miss rather than smoothed, the mutants and where each died, and gaps H1–H5. Update the suite-count table and the `Verified against` line to the final commit. Rewrite "Resume here" to lead with Plan 3h and name **3i (zoom, G3, level-of-detail geometry)** and **3j (the 192 MiB vertex buffer, whose figure sits on a doubling boundary with no headroom)** as what comes next.

- [ ] **Step 4: Commit**

```sh
git add -A docs/superpowers/notes STATUS.md
git status --porcelain    # analysis_options.yaml must not be staged
git commit -m "docs: Plan 3h closes -- the fallback walk, its instrument, and four mutants"
```
