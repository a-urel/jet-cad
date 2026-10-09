# Host embedding API, Slice 1: results

**Asked by the human:** *"Monépro entegrasyonuna geç. Önce beyin
fırtınası. Temel nokta, başka bir uygulamaya gömecek esnekliğe sahip
olması…"* (2026-10-08), then *"onaylıyorum, spec'i yaz"* and *"evet,
Dilim 1 ile devam et"* (2026-10-09).

**Spec:** [2026-10-09-host-embedding-api-design.md](../specs/2026-10-09-host-embedding-api-design.md),
revision 3, as amended during the slice (P-4, G-3, G-5, G-6, H-8, F-8;
the amendments are listed in its Review section). Revision 1 was
reviewed independently (*Approve with fixes*, V-1 to V-22).

**Plan:** [2026-10-09-embedding-slice-1.md](../plans/2026-10-09-embedding-slice-1.md).

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `85905bd`
(release 0.3.0). **Not merged:** the merge is the human's word.

**Process.** Each of Tasks 1–4 had a fresh implementer, then an
independent reviewer in its own clone, then its fixes. Task 5 (the demo,
the guide, the probe, CI) was delegated by the controller and gated by
it. An independent review of the whole range closes the slice.

## What a host gets

- **A table's detail:** `controller.tableDetails` lists
  `FloorPlanTableDetail` per table of the plan the mode shows: centre,
  size, rotation, mirror, the four corners (world millimetres, y up),
  layer, lock; `data` is empty until Slice 2. `FloorPlanTable` is
  unchanged (P-1). `tableAt(canvasPoint, kind:)` answers which table is
  under a point, with a finger's reach for touch.
- **The camera:** `controller.camera` is a public
  `ValueListenable<FloorPlanCamera>` (`scale`, `worldToCanvas`,
  `canvasToWorld`, `visibleWorld`); `canvasRect`, `worldToGlobal`,
  `globalToWorld` for an overlay outside the view.
- **Commands and bounds:** `panBy`, `zoomBy`, `centerOn` (queued like a
  fit before a view shows); `FloorPlanController(minScale:, maxScale:)`,
  `minScale` at least 1e-6; every fit clamps to the bounds. A camera
  epoch makes the last request win. A `panBy`/`zoomBy` before a plan's
  first frame does not cancel that plan's own fit; `centerOn` places the
  camera beforehand. `FloorPlanView(userCamera: false)` locks the user's
  pan and zoom.
- **The host's widgets on the tables:** `FloorPlanView(tableOverlayBuilder:,
  tableOverlayLayout:, tableOverlayModes:)`. The builder runs per table
  when that table's `FloorPlanTableOverlay` (detail, selected, focused,
  effective status, detail level) changes, and for every table when the
  host rebuilds the view; **never on pan or zoom**. Placement: an anchor
  on the table's screen box, `natural` (own size) or `box` (sized to the
  table), `hideBelowScale`, `detailBreakpoints`. With `interactive: true`
  a badge takes its own pointers (no table tap, selection, drag, menu or
  pinch finger there) through `InputClaim`, a new `jet_cad_2d_flutter`
  marker; pan and zoom still start anywhere off a badge.
- **CI:** v0.3.0's host probe is analysed against every commit
  (invariant 1), so a 0.3.0 host keeps compiling.
- **The demo:** the Salon's "Badges" switch (guests/seats, minutes, a dot
  at low zoom, faded outside the focus) and *Centre on table 7*.
- **The guide:** "Your own widgets on the tables", one view per
  controller. **The schema is unchanged** (8).

## The tasks

| Task | Commit | Review | Fixes |
|---|---|---|---|
| 1, a table's detail and `tableAt` (G-1, G-4) | `85918c4` | **Approved with fixes**: no code defect; the caches' document check and the (−π, π] normalisation unpinned; an inexact 90° fixture | `6c742b4`: TD11–TD13, an exact mirrored 90°, a stylus line, comments, spec F-8 |
| 2, the public camera (G-2, G-3) | `03c6d66` | **Approved with fixes**: R-1 (decided: an early `panBy` no longer cancels a plan's own fit), a zero-size mount, the first `canvasRect` before the fit, the per-mode rect, a `minScale` floor | `adaa2bc`: the first-fit rule, the due epoch, the rect after the fit and per mode, `minScale ≥ 1e-6`, CM12–CM15, CR3–CR5 |
| 3, the overlay layer (G-5–G-7, H-8) | `b420493` | **Approved with fixes**: R-1 (decided: every host rebuild runs the builder, tear-offs included), R-2 (accepted: one paint `Offset` per shown overlay), paint position, detach, semantics and box-cull unpinned | `31db289`: TO19–TO27, the box-cache reuse, spec P-4/G-5/G-6/H-8 |
| 4, interactive overlays (G-5's pointers) | `89e29b2` | **Approved with fixes**: a cancel ending a claim and nested claims unpinned; a placement sentence | `84ee8e9`: IC10 (a cancel ends a claim), a nested claim, baseline-relative counts, the placement sentence |
| 5, demo, guide, probe, CI, CHANGELOG | `e7b1c78`, `65fefab`, `ae3a566`, `d2bd37f`, `59eb206` | gated by the controller | `59eb206`: each badge its own semantics node (found by the smoke check) |
| the range `85905bd..56be3fa` | — | **Independent review: Approve with fixes**; no defect where the tasks meet; the v0.3.0 and tip camera behaviour identical over 120 cases | `98c0c1d`: F-1 (an early `centerOn` takes the page fit's scale), F-2–F-4 tests, F-5 (a kiosk block in the guide and probe), F-8 (the errors in the CHANGELOG and guide); F-6, F-7 in this note and STATUS |

Per-task reports, reviews and fixes are in
`.superpowers/sdd/2026-10-09-host-embedding-api/` (git-ignored); they are
archived to `docs/superpowers/ledgers/` on merge.

## Named mutants

Every named mutant of the plan went red, each with its killer recorded
in the task's report: Task 1's eight (M-H1–M-H4, M-H13–M-H15,
M-H19b(tableAt)), Task 2's six (M-H5, M-H6, M-H6b, M-H7,
M-H19b(canvasRect), M-H19b(userCamera)), Task 3's eight (M-H8–M-H12,
M-H18, M-H19, M-H19b(design default)), Task 4's two (M-H16, M-H17), Task
5's probe mutant (`check_guide` exits 1). The reviews ran 60 mutants of
their own; every survivor is now red or recorded as equivalent (Task 3's
O10, a listener leak with no behaviour; O16) in the reviews.

## Gates (at `98c0c1d`; render and engine at `84ee8e9`, untouched after)

| Package | Result |
|---|---|
| engine `packages/jet_cad_2d` | 1255 tests; the standing failures and skips, exactly. Untouched. |
| render `packages/jet_cad_2d_flutter` | 1374 tests (1363 at `85905bd`); the standing failures and skips, exactly. Analyze and format clean. Both allocation invariants green. |
| planner `packages/jet_cad_floor_plan` | **1514 passed** (1437 at `v0.3.0`). Analyze and format clean. |
| demo `apps/restaurant_demo` | **47 passed** (39). |
| app `apps/floor_planner` | **212 passed**. |
| `tool/ci` | **62 passed**; `check_guide`: all 23 code blocks are in the host probe. |
| web builds | both 42M from a clean `build/`, no `flutter_scene` assets. |
| host probe | exit 0 at `98c0c1d` by `file://`; v0.3.0's probe analyses against `56be3fa` (`old_host_probe.sh`), and in CI. |
| CI on GitHub | green on every pushed commit through `56be3fa`. |

**Smoke check** (Chromium, Playwright, on the demo's web build): 11
badges after the switch; a 200 × −100 px pan moved every badge by exactly
the drag; a wheel zoom scaled their places about the cursor and kept
their size; a tap on a badge's table selected it; *Centre on table 7*
then a tap at the canvas centre reported table 7; no console error.

**The overlays' cost** (R-2 of the spec; software WebGL, 4 cores, so only
the comparison means something): 117 badged tables, panning, average
frame interval 21.1–21.9 ms without badges, 27.7 ms with them (median
16.7 ms both; p95 33.4 → 50.1 ms). A mouse sweep over interactive badges:
about 0.09 ms per move against 0.05–0.06 ms without.

## Found, not fixed

- **Two `FloorPlanView`s on one controller throw** (`StateError`); this
  predates the slice and is now in the guide.
- **`canvasRect` assumes no scaled or rotated ancestor.**
- **Over an interactive badge the wheel zooms the plan** (Flutter's signal
  resolver), so it beats an outer host scrollable there; in the guide.
- **Bottom-anchored badges cover the planner's caption** on rectangular
  tables; the guide says to set a colour without a caption when the badge
  carries the status.
- **117 badges add about 6.6 ms a frame** in software rendering; a real
  device is unmeasured.

## Owed

- **To the human:** a look on a tablet and a terminal (the badges, pan and
  zoom smoothness, interactive badges by touch); the German and Turkish
  read of the demo's new strings.
- **Known gap from the final review:** the canvas's own `Flow` already
  clips the overlays, so the overlay layer's `ClipRect` is a second
  guard today (F-2); TO33 pins both.
- **To Monépro:** spec 103 B.1 can name `controller.camera` and
  `tableOverlayBuilder` (Q-Z1 is answered); Q-H3, the overlay sizes and
  detail levels phase 2 wants.
- **The merge**, on the human's word. Unreleased: CHANGELOG *Unreleased*.
