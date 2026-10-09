# Slice 1, Task 5 — the demo, the guide, the probe, CI, the CHANGELOG: report

**Commits** on `claude/exciting-pasteur-9m22jv` (parent `89e29b2`), not pushed:

| SHA | What |
|---|---|
| `e7b1c78` | feat(demo): the Salon's table badges and Centre on table 7 |
| `65fefab` | docs: the host guide's "Your own widgets on the tables" and its probe |
| `ae3a566` | ci: the 0.3.0 host probe analysed against the commit under test (invariant 1) |
| `d2bd37f` | docs: the CHANGELOG's Unreleased section gains Slice 1 |
| `59eb206` | fix(demo): each table badge is its own semantics node (found by the smoke check) |

Not done here (the plan's Task 5 lists them, the brief did not): the results note, STATUS, the roadmap's row 14. `input_claim.dart` and the overlay were not touched.

## 1. Demo (`apps/restaurant_demo`)

- `lib/main.dart`: `kBadgeAreas = {'Salon'}`, `kBadgeDetailScale = 0.025`, `kBadgeLayout` (`anchor: Alignment.bottomCenter`, one breakpoint). `Area.offersBadges` / `Area.badges` (off by default, kept per area). In the Salon's service, below the zones: a "Badges" `SwitchListTile` (`Key('badges')`) and a "Centre on table 7" button (`Key('center-7')`). `FloorPlanView(tableOverlayBuilder: a.badges ? tableBadge : null, tableOverlayLayout: kBadgeLayout)`.
- `tableBadge`: guests/seats and minutes, framed in the effective status's colour, outlined (2 px, primary) when `selected`, `Opacity(0.35)` when not `focused`, a 12 px dot at `detailLevel == 0`. Each badge is a `Semantics(container: true, label: 'Table N')` (59eb206).
- **Figures** (`DemoHomeState.badgeFigures`, static): made up but fixed by number, seats and status. Free / no status: none. Ordered: 5 + k % 10 min. Eating: 20 + 3k % 25. Bill: 45 + 7k % 30. Guests: 1 + k % seats. They take **no extra draw from the random source**, because D13 replays `math.Random(seed)`, so the badges are deterministic whenever the statuses are.
- **Minutes counter:** a `ValueNotifier<int> minutes` ticked by `Timer.periodic(1 min)` (cancelled in `dispose`), read through a `ValueListenableBuilder` inside the badge. A tick rebuilds only the counters, never the overlays (the guide's "live data is yours").
- `centerOnSeven`: table 7's `center` from `tableDetails`, then `centerOn(center)`; the zoom is kept.
- `lib/demo_strings.dart`: `badges`, `centerOnTable(n)`, `minutes(m)`:
  - en: Badges / Centre on table 7 / 41 min
  - de: Tischanzeigen / Auf Tisch 7 zentrieren / 41 Min.
  - tr: Rozetler / Ortala: masa 7 / 41 dk (worded to avoid the Turkish case suffix on a number)
  - Owed: a native read.
- `test/badges_test.dart` (new; existing demo tests unedited): DB1–DB8 on the sample plans (fitted camera ≈ 0.0484 px/mm, not the identity):
  - **DB1:** off by default; one badge per numbered table with geometry (11). Figures worked by hand (7 Eating 4/4 41 min, 2 Bill 3/4 59 min, 10 Ordered 1/1 5 min, 5 free 0/6). A one-minute tick moves the minutes with 0 builder calls. A status change rebuilds that badge. Switched off, none.
  - **DB2:** each badge's bottom centre equals its table's screen-box bottom centre, computed through the public `worldToGlobal` over `corners`, within 1e-6 px. Checked before and after `panBy` + `zoomBy`, with 0 builds. Below the breakpoint come dots, one build per table. A tap on a badge selects its table.
  - **DB3:** fading under zone B (opacity 0.35 against 1); the selection outline.
  - **DB4:** after Centre on 7, `camera.worldToCanvas(7.center)` is the canvas's centre within 1e-6, the scale is kept, `globalToWorld(canvasRect.center)` gives 7, and `tableAt(middle) == '7'`.
  - **DB5:** no badges in the Teras or the design mode; the switch is kept per area.
  - **DB6:** de/tr strings.
  - **DB7:** the figures.
  - **DB8:** one semantics node per badge.

**Mutants.** Each was applied, seen red and restored from a copy (runner `scratchpad/t5/mut.py`, `restored: True` each time):

| Mutant | Killer | Red line |
|---|---|---|
| D-M1 anchor `center` | DB2 | `Expected: … of <483.4090909090909>` / `Actual: <459.3454545454545>` |
| D-M2 no fading | DB3 | `Expected: <0.35>` / `Actual: <1.0>` |
| D-M3 `centerOn` at (x, −y) | DB4 | `Expected: … of <450.0>` / `Actual: <392.4472727272728>` |
| D-M4 no dot | DB2 | `Expected: empty` / `Actual: ['1', … '11']` |
| D-M5 builder ignores the switch | DB1, DB5 | `Expected: empty` / `Actual: ['1', … '11']` |
| D-M6 minutes not live | DB1 | `Expected: '42 min'` / `Actual: '41 min'` |
| D-M7 no breakpoint | DB1, DB2, DB3 | `Expected: ['1', … '11']` / `Actual: []` |
| D-M8 badge not a semantics container | DB8 | `Expected: _DebugSize:<Size(60.5, 22.0)>` / `Actual: Size:<Size(1300.0, 900.0)>` |

## 2. Host guide (`docs/host-guide.md`)

- **§ 4:**
  - The view's block gains `tableOverlayBuilder: tableBadge` and a `FloorPlanOverlayLayout(anchor: bottomCenter, detailBreakpoints: [0.05])`. The block has to stay contiguous with the probe's single `FloorPlanView` call, so the new lines go inside it.
  - A pointer to the new section.
  - **"One `FloorPlanView` per controller at a time"**: a second one throws a `StateError` (Task 2 review R-5).
  - The camera sentence: `camera`, `panBy`/`zoomBy`/`centerOn`, `minScale`/`maxScale`, *unreleased on `main`*.
- **New `### Your own widgets on the tables`**, at the end of § 7 (after Zones) and marked *Unreleased on `main`.*. It covers:
  - the detail and the decomposition;
  - the camera and the canvas (a read-out block);
  - `canvasRect`, `worldToGlobal` and `globalToWorld` (the `openMenuAt` block): first report after the first fit, per mode, scaled or turned ancestors not accounted for;
  - the commands (`showTable` and zoom-button blocks), the bounds and the 1e-6 floor, fits clamped, requests against commands, **the first-fit rule** (place the camera with `centerOn`), and `userCamera`;
  - `tableAt` (the `tableUnder` block);
  - the builder (the `tableBadge` block), the `FloorPlanTableOverlay` fields and **when it runs**;
  - placement (`natural`/`box`, `anchor` as `Align`, `maxNaturalSize`, `hideBelowScale`, `tableOverlayModes`);
  - detail levels and the view's `ArgumentError`;
  - pointers, with a gesture-by-gesture table for `interactive: true`, plus the coordinator's **R-4** sentence (the wheel over a badge goes to the plan through `PointerSignalResolver`, wins over an outer scrollable there, and on the web the browser does not scroll the page; off the badges, as before);
  - lifetime and remounts (switching `interactive` included);
  - the look (above the veil and chips, fade with `focused`, G-9's fill and caption);
  - the cost.
- `check_guide`: `docs/host-guide.md: all 22 code blocks are in the host probe`.

## 3. Host probe (`tool/ci/host_probe/lib/main.dart`)

- **What changed:** every new block is in the probe verbatim: `tableBadge` with `guestsAt`, `showTable`, `openMenuAt`, `tableUnder`, a `zoomBy` button, a camera read-out, and the view's overlay arguments. They are wired to app-bar actions.
- **Mutant:** in the probe, `showTable`'s `0.1` was changed to `0.2`. `check_guide` then printed `docs/host-guide.md: not in the host probe: dart: /// Brings table [number] to the middle of the view, close enough to read.` and exited 1. The file was restored from a copy and `cmp` confirmed it. `check_guide` was green again.

## 4. CI, invariant 1

- **`tool/ci/old_host_probe.sh <tag>` (new):**
  - It needs a probe that `host_probe.sh` has resolved; without a `pubspec.lock` it exits 2.
  - It copies the probe's `main.dart` aside and sets a `trap` that restores it on any exit.
  - It writes `git show <tag>:tool/ci/host_probe/lib/main.dart` into the probe, runs `flutter analyze`, and prints the verdict line.
- **`.github/workflows/ci.yml`, host-probe job:** the checkout now has `with: fetch-depth: 0`, so `v0.3.0` is in the clone. After the probe step there is a new step, `The 0.3.0 host probe against this commit`, which runs `tool/ci/old_host_probe.sh v0.3.0`.
- **`tool/ci/test/scripts_test.dart`:**
  - **SC18** pins the job's `fetch-depth: 0` and the step's place after `host_probe.sh`.
  - **SC19** runs the script with bash in a scratch repository: a tag, then a later commit, with a stand-in `flutter` that records what it analysed. It checks three cases: no lock gives exit 2 with nothing touched; the tag's `main.dart` is the one analysed and this commit's is back on success; the same on failure, with exit 1.
- **Mutants:**

| Mutant | Killer | Red line |
|---|---|---|
| C-M1 no fetch-depth | SC18 | `Expected: contains '      - uses: actions/checkout@v5\n'` |
| C-M2 step removed | SC18 | `Expected: a value greater than <791>` / `Actual: <-1>` |
| C-M3 no restore trap | SC19 ×2 | `Expected: 'void main() {} // this commit\n'` / `Actual: 'void main() {} // as v0.3.0 had it\n'` |
| C-M4 `HEAD:` instead of the tag | SC19 | `Expected: 'void main() {} // as v0.3.0 had it\n'` / `Actual: 'void main() {} // this commit\n'` |

  C-M4 first survived, because the tag was HEAD in the fixture. SC19 now adds a later commit.
- **Run locally at `ae3a566…` (full SHA `ae3a56600294bc3780500f9b5996ba76c7d67387`)** by `file:///home/user/jet-cad`, after `rm -rf ~/.pub-cache/git/cache/jet-cad-* ~/.pub-cache/git/jet-cad-*`:
  ```
  + jet_cad_floor_plan 0.3.0 from git ../../.. at ae3a56 in packages/jet_cad_floor_plan
  /home/user/jet-cad/tool/ci/host_probe/pubspec.lock: 40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
  Analyzing host_probe...
  No issues found! (ran in 4.9s)
  ✓ Built build/web
  host probe: no GPU renderer, no build hook; build/web is 42M
  host_probe exit 0
  ```
  ```
  $ tool/ci/old_host_probe.sh v0.3.0
  Analyzing host_probe...
  No issues found! (ran in 4.9s)
  old host probe: v0.3.0's main.dart analyses against ae3a56600294bc3780500f9b5996ba76c7d67387
  old_host_probe exit 0
  ```
  `git status` was clean afterwards, so the probe's `main.dart` was restored. Later commits did not touch the guide or the probe.

## 5. CHANGELOG

*Unreleased* lists:
- what does not change: schema 8, no signature change, the 0.3.0 probe analysed in CI;
- the new API:
  - the detail, `tableDetails` and `tableAt`;
  - `FloorPlanCamera`, `camera`, `canvasRect`, `worldToGlobal` and `globalToWorld`;
  - `panBy`, `zoomBy`, `centerOn`, `minScale`/`maxScale` with the 1e-6 floor, and the first-fit rule;
  - the builder, `FloorPlanTableOverlay`, `FloorPlanOverlayLayout`, `FloorPlanOverlaySize`, `tableOverlayModes` and interactive overlays;
  - `userCamera`;
  - `InputClaim`/`RenderInputClaim` in `jet_cad_2d_flutter`;
- "changes a host may notice": fits clamped; `@internal camera` → `cameraController`; implementers of `FloorPlanController`;
- one view per controller;
- known limits.

## 6. Gates (real tails)

`PATH=/root/sdk/flutter/bin:$PATH CI=true`, tree `d2bd37f` (script `scratchpad/t5/gates.sh`):
```
### packages/jet_cad_floor_plan :: flutter test
test-exit 0
04:37 +1510: All tests passed!
### packages/jet_cad_floor_plan :: flutter analyze
No issues found! (ran in 4.8s)
### packages/jet_cad_floor_plan :: format
Formatted 250 files (0 changed) in 1.46 seconds.
format-exit 0
### apps/restaurant_demo :: flutter test
test-exit 0
00:25 +46: All tests passed!
### apps/restaurant_demo :: flutter analyze
No issues found! (ran in 4.2s)
### apps/restaurant_demo :: format
Formatted 5 files (0 changed) in 0.07 seconds.
format-exit 0
### apps/floor_planner :: flutter test
test-exit 0
01:36 +212: All tests passed!
### apps/floor_planner :: flutter analyze
No issues found! (ran in 4.2s)
### apps/floor_planner :: format
Formatted 47 files (0 changed) in 0.23 seconds.
format-exit 0
### tool/ci :: dart test
test-exit 0
00:07 +62: All tests passed!
### tool/ci :: analyze
No issues found!
### tool/ci :: format
Formatted 11 files (0 changed) in 0.04 seconds.
format-exit 0
### check_guide
docs/host-guide.md: all 22 code blocks are in the host probe
check-exit 0
### packages/jet_cad_2d :: dart test --file-reporter json:<s>/e.json
engine test-exit 1
packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly
compare-exit 0
### packages/jet_cad_2d_flutter :: flutter test --file-reporter json:<s>/r.json
render test-exit 1
packages/jet_cad_2d_flutter: 1372 tests; the standing failures and skips, exactly
compare-exit 0
### git status
```

After `59eb206`, a demo-only change, the demo was re-gated:
- test: `00:25 +47: All tests passed!`
- analyze: `No issues found! (ran in 4.6s)`
- format: `Formatted 5 files (0 changed) in 0.07 seconds.`, exit 0

**Web builds** (`rm -rf build; flutter build web`):

| App | Tree | Result | `build/web` | `main.dart.js` | flutter_scene assets |
|---|---|---|---|---|---|
| `apps/floor_planner` | `d2bd37f` | `✓ Built build/web` | 42M | 3,587,061 B | none |
| `apps/restaurant_demo` | `d2bd37f` | `✓ Built build/web` | 42M | 3,724,045 B | none |
| `apps/restaurant_demo` | `59eb206`, rebuilt | `✓ Built build/web` | 42M | 3,724,155 B | none |

No `analysis_options.yaml` was touched or committed.

## 7. Web smoke check

**Setup:** headless Chromium 1194 through Playwright 1.56.1. Viewport 1600×1000, `locale: 'en-US'`, `ignoreHTTPSErrors: true`. Semantics were enabled by clicking `flt-semantics-placeholder`. The demo's `build/web` at `59eb206` was served by `python3 -m http.server`.

**Script:** `scratchpad/t5/smoke.js`, with output in `scratchpad/t5/smoke.log`. It drives the UI through semantics nodes and real mouse events. Output:
```
badges before the switch: 0
Badges switch: [{"label":"Badges","role":"switch","checked":"false",...}]
badges after the switch: 11 {"1":"2/4 52 min","2":"0/4","3":"4/4 29 min","4":"5/6 9 min","5":"6/6 35 min","6":"3/4 57 min","7":"0/4","8":"1/1 13 min","9":"1/1 22 min","10":"0/1","11":"1/1 6 min"}
pan by (200, -100): 11 badges compared, worst deviation of a badge's move from the drag 0.000 px
zoom about (650, 550): factor 1.100 (from table 7); 11 badges, worst deviation of a badge's bottom centre from that scaling 0.001 px; badge size kept: true
tap on badge 1 at its table -> ["Salon: tapped 1","Salon: selected {1}"]
after Centre on table 7: badge 7's bottom centre at (649.994, 595.220)
tap at the canvas centre (650, 550) -> ["Salon: tapped 7","Salon: selected {7}"]
console errors: []
```

**What was seen:**
- Badges on in the Salon's service.
- A mouse pan moved every badge by exactly the drag.
- A wheel zoom scaled every badge's anchor about the cursor, and the badges kept their size.
- A tap on a table at its badge selected it, because the badges are not interactive.
- Centre on table 7 put table 7 at the canvas's centre: a tap there is table 7's.
- No console error.

**Screenshots** (`/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/s1-smoke/`): `1-badges-on.png`, `2-panned.png`, `3-zoomed.png`, `4-tapped.png`, `5-centred-on-7.png`, `6-centre-tapped.png`, and `7-perf-117-badges.png` (from §8).

**The first run found a defect.** The badges' texts merged into the canvas's one semantics node, so there was no node per badge. Fixed in `59eb206` (DB8, D-M8).

## 8. Overlay cost (R-2), and the hover sweep (Task 4 review R-5)

**Harness.** These temporary files were not committed and were removed afterwards. Copies are in `scratchpad/t5/perf/`.
- `lib/perf_main.dart` runs the demo over a generated Salon of **117 numbered bar stools**: 13 × 9 at 1.1 m, all on the page, so all 117 badges are on the canvas at the fit (`7-perf-117-badges.png`).
- `?harness=1` runs a bare `FloorPlanView` of the same plan instead, with 40×20 `GestureDetector`/`MouseRegion` badges: `interactive=1`, `interactive=0`, or `badges=0`.
- Built with `flutter build web -t lib/perf_main.dart -o scratchpad/t5/web-perf` (canvaskit renderer).

**Machine.** 4 cores. Headless Chromium falls back to **software WebGL (SwiftShader)**, as its console says. All absolute numbers are therefore pessimistic, and only the comparisons mean something. Tablet and terminal numbers are still owed.

**Pan.** Script `scratchpad/t5/perf.js pan`, logs in `perf-pan.log`.
- **Method:** the Salon in Service, Random statuses, then the badges switched on or left off. One warm-up drag, then 3 measured drags per page load. Each drag starts on the floor and is 4 sweeps of 60 mouse moves of 8 px, one every 16 ms. The measure is the `requestAnimationFrame` intervals during the drag. Two page loads per condition, interleaved off, on, on, off.

| Load | Frames | Mean | p50 | p95 | max | intervals > 20 ms |
|---|---|---|---|---|---|---|
| badges off, round 1 | 2300 | 21.1 ms | 16.7 | 33.4 | 50.1 | 608 (26 %) |
| badges off, round 2 | 2259 | 21.9 ms | 16.7 | 33.4 | 133.3 | 677 (30 %) |
| **117 badges on**, round 1 | 2321 | 27.7 ms | 16.7 | 50.1 | 150 | 719 (31 %) |
| **117 badges on**, round 2 | 2324 | 27.7 ms | 16.7 | 50.1 | 83.3 | 721 (31 %) |

So 117 natural badges on screen cost about 6–7 ms more per frame on average in this software-rendered browser: about 36 fps against 46 fps, with p95 at 50 ms against 33 ms. The median frame stays at 16.7 ms.

**Hover sweep (R-5).** Script `perf.js hover`, logs in `perf-hover.log`.
- **Method:** synthetic mouse `pointermove`s with no button, dispatched synchronously on `flutter-view` in 20 rows × 520 points across the whole canvas, through the 117 badges. Each row was timed with `performance.now()`. 4 passes per load; the first (warm-up) pass is dropped; 3 loads per condition.
- **Premise:** these synthetic events reach the framework. A synthetic `pointerdown` + `pointerup` at table 40 logged `["Salon: tapped 40","Salon: selected {40}"]`.

| Condition | Mean time per hover event, per load |
|---|---|
| `interactive: true` (117 claims, hit-tested per hover) | 0.09, 0.09, 0.09 ms (p95 0.14–0.17) |
| `interactive: false` (IgnorePointer) | 0.05, 0.05, 0.06 ms (p95 0.08–0.11) |
| no builder | 0.06, 0.05, 0.06 ms (p95 0.08–0.10) |

So interactive overlays add about 0.03–0.04 ms per mouse move with 117 overlays, which is negligible against a 16 ms frame.

**CanvasKit.** It is fetched from gstatic by default, and through this sandbox's proxy the fetch failed on some loads. The hover and premise runs therefore routed it to the build's own `canvaskit/` copy (same build). The pan runs loaded it from the CDN.

## Findings

- **F-1, a status caption under a badge.** With `anchor: bottomCenter`, the demo's badge covers the planner's status caption ("Bill") on rect tables (`3-zoomed.png`). This is G-9 as documented: a host that shows the status in its widget should set a colour without a caption. The demo keeps both so the badge shows over the planner's status colour. Worth a look in the owner's review.
- **F-2, bar stools crowd.** The bar stools' badges overlap at the fit (the stools are 0.8 m apart). The dot breakpoint does not help there; a host would hide badges for stools or raise `hideBelowScale`.
- **F-3, the pan cost.** With 117 badges the cost is visible in software rendering (≈ +6.6 ms per frame on average). Each overlay is its own `RepaintBoundary`, so CanvasKit composites 117 picture layers per frame. On real devices with GPU rasterisation it should be smaller, but it is unmeasured; a terminal and tablet run is owed.
- **F-4, a guide claim not verified here.** The guide's sentence that, on the web, "the browser does not scroll the page" over a badge comes from the Task 4 review (R-4) as given; this task did not verify it in a browser.
- **F-5, the § 4 view block.** It now carries the overlay lines, because `check_guide` matches each block contiguously and the probe has one `FloorPlanView` call.
- **F-6, the plan's other Task 5 items.** The results note, STATUS and the roadmap's row 14 are not done; the brief did not ask for them.
