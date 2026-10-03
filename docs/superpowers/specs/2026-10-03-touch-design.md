# Touch (14t) — design

**Date:** 2026-10-03. **Status:** design, **revision 2**: revision 1
(`9611727`) reviewed independently, "Ready with fixes" (R-1 to R-13);
[Revision 2](#revision-2) is binding where it differs. **Sub-project:** 14 (restaurant embedding), slice
**14t**.
**Umbrella:** [2026-10-03-restaurant-embedding-design.md](2026-10-03-restaurant-embedding-design.md)
(revision 3, approved): D17, decision 9, F-11 and R-7 are this spec's
input. **Spike:** [2026-10-03-touch-spike.md](../notes/2026-10-03-touch-spike.md)
(TS-1..TS-10). **14c's results** recorded the second-finger defect this
slice owns (review F-10).
**Approval:** as 14b-2's and 14c's — the human asked not to be asked
unless needed ("Devam et", 2026-10-03); the umbrella's D17 is approved;
this spec details it.
**Branch:** `claude/exciting-pasteur-9m22jv`; facts at `387c401`.
**Size:** M. **Packages touched:** `jet_cad_2d_flutter` (render:
`camera_gesture_detector.dart`, `interaction_layer.dart`, `tool.dart`,
`grip_cache.dart`, `select_tool.dart`), `jet_cad_floor_plan` (the long
press in `table_select_tool.dart`). Engine: untouched.

## What it delivers

On a touch screen, in both modes: **two fingers pinch to zoom** about
their midpoint and **pan by moving together**; a finger that turns out to
be the first of a pinch **never acts** as a tap, a drag or a drawing
point; once two fingers are down the gesture is the camera's **until
every finger lifts**; a second finger during a one-finger drag **cancels
the drag** (nothing is executed) and pinches. Taps hit **finger-sized
targets** (24 px pick and grip radius, 18 px slop) while a mouse keeps
today's 6 px / 7 px / 4 px. A lifted finger leaves no hover highlight or
snap marker. The selection mode's long press stays 500 ms from contact.
Mouse, trackpad and stylus behave exactly as today.

## Facts established (at `387c401`, with the spike)

- **F-1.** Touch arrives as one pointer per finger, `kind: touch`,
  `buttons: 1` while down; no pan-zoom events (TS-1, TS-2).
- **F-2.** The web engine sends a `pointer: 0` touch hover after every
  touch up and cancel (TS-3); `InteractionLayer` routes every hover to the
  active tool as a move with `buttons: 0` (`interaction_layer.dart:175-178`,
  TS-10).
- **F-3.** `InteractionLayer` follows one pointer and promotes a primary
  move on an unclaimed pointer to a down (`:149-158`), so after a pinch's
  first finger lifts, the second becomes the tool's (TS-6).
- **F-4.** `CameraGestureDetector` and `InteractionLayer` are both
  opaque `Listener`s over the same box, the camera's the parent
  (`planner_view.dart:192-195`); a `Listener` sees every pointer that hits
  it, and the inner one is dispatched first. Neither joins the gesture
  arena.
- **F-5.** `PlacementTool.onPointerDown` places a point
  (`draw/placement_tool.dart:148-165`), phase `idle` always; its `cancel`
  drops the pending shape. `SelectTool`, `TableSelectTool` and
  `SymbolPlaceTool` act on the up or past their slop, and their `cancel`
  executes nothing (TS-8).
- **F-6.** `pickRadiusWorld` is `kPickRadiusPixels / scale` (6 px), set
  by the layer per event (`interaction_layer.dart:110-125`); grips hit
  within `kGripHitPixels` = 7 px (`grip_cache.dart:19, 281-319`);
  `SelectTool` starts a band or a move past `kBandSlopPixels` = 4 px
  (`select_tool.dart:26, 160`); `TableSelectTool` uses `kTouchSlop`
  (18 px) for every kind and starts its long-press `Timer` on the routed
  down (14c R-7).
- **F-7.** `CameraController.zoomAt` clamps to `minScale` / `maxScale` and
  ignores a non-finite or non-positive factor; `panBy` adds a screen
  delta (`camera_controller.dart:60-100`).

## Decisions

### T1 — What a finger is

A **touch pointer** is one whose `kind` is `PointerDeviceKind.touch`.
Mouse, trackpad, stylus, inverted stylus and unknown are **precise**
pointers and keep today's behaviour in full (a stylus is a pen, not a
fingertip; a stylus never joins a pinch).

### T2 — Pinch and two-finger pan (`CameraGestureDetector`)

- The detector keeps the **live touch pointers** in the order they went
  down, each with its latest local position (down, move; removed on up
  and cancel).
- **The pair** is the two earliest live touches. When the pair forms or
  changes (a pair finger lifts with a third still down), its **baseline**
  is taken: focal `F = (p1 + p2) / 2`, span `S = |p1 − p2|`. A change of
  pair never moves the camera.
- On a move of a pair finger: with the new focal `F'` and span `S'`,
  `camera.panBy(F' − F)`, then, when `S ≥ kPinchMinSpan` and
  `S' ≥ kPinchMinSpan` (8 px), `camera.zoomAt(F', S' / S)`; then
  `F ← F'`, `S ← S'`. Pan before zoom, zoom about the new focal: the world
  point under the old midpoint stays under the fingers' midpoint. The
  ratio is per event; the product over a gesture is `S_end / S_start`
  (no cumulative factor is ever applied twice).
- A third finger's move, and a lone finger's, does nothing here.
- Clamping is the controller's (F-7). Both modes, every tool.

### T3 — Touch sessions (`InteractionLayer`)

A **touch session** runs from a touch down while no touch is down until
no touch is down again. It is **single** while one finger has been down
in it, **multi** from the moment a second touch goes down, and stays
multi until it ends.

- **Hold-back.** The first finger's down is **not routed at once**. It is
  held until the first of:
  1. **its up**: the held down is routed, then the up (a tap);
  2. **a move past `kTouchSlop`** from the down: the held down is routed,
     then that move (a drag); moves within the slop while held are not
     routed;
  3. **`kTouchHoldBack` = `kPressTimeout` (100 ms)** with the finger down:
     the held down is routed (a press, e.g. a long press).
  A routed held down carries the down's own position, buttons and
  modifiers, and `held`, the time it was held (T5).
- **A second finger** makes the session multi. A finger still held is
  **dropped**: the tool never sees it. A routed finger is **released**:
  the layer stops following it and, when the tool's `phase` is not
  `idle`, calls `tool.cancel(ctx)`. In a multi session **no touch event
  reaches the tool** — downs, moves, ups, cancels — until the session
  ends.
- **No promotion for touch.** The move-to-down promotion (F-3) applies
  to precise pointers only.
- **Touch hovers are not routed** (F-2): a hover of `kind: touch` reaches
  no tool.
- **Cancel.** A held finger's cancel drops it; a routed finger's cancel
  cancels the tool, as today.
- **The hold-back timer** is cancelled when the held finger is routed or
  dropped, when the session ends, and on the layer's deactivate and
  dispose (a held down never reaches a tool after the layer leaves).
- Precise pointers are routed exactly as today, hold-back never applies
  to them, and a precise pointer never starts or joins a touch session.

### T4 — Finger-sized targets

- `ToolPointerEvent` gains **`kind`** (`PointerDeviceKind`, an optional
  constructor parameter defaulting to `mouse`, so every existing call
  site compiles) and **`held`** (`Duration`, default zero).
- The layer sets `kind` and computes `pickRadiusWorld` from
  **`kTouchPickRadiusPixels` = 24** for a touch pointer (a 48 px target)
  and `kPickRadiusPixels` = 6 otherwise.
- `GripCache.hitTest` and `hitsRotationGrip` take an optional radius in
  pixels (default `kGripHitPixels`); `SelectTool` passes
  **`kTouchGripHitPixels` = 24** for a touch press.
- `SelectTool`'s band and move slop is **`kTouchSlop`** for a touch press,
  `kBandSlopPixels` otherwise; the press's kind is the down's.
- The snap aperture (`kSnapAperturePixels`) is unchanged (see "Not in
  scope").

### T5 — The long press from contact

`TableSelectTool` starts its long-press timer for
`kLongPressTimeout − e.held` (never negative): a touch press routed after
the hold-back still toggles 500 ms after the finger touched. A held down
is routed early only by an up or a slop crossing, and neither can become
a long press, so `held` is `kTouchHoldBack` whenever a long press is
possible.

### T6 — What follows in the two modes

- **Selection mode:** a second finger during a table drag cancels it —
  no `Move`, no `onLayoutChanged` — and pinches (umbrella D17's proposed
  rule). One finger on the floor still pans (14c). A tap on a table by
  touch is a tap after the hold-back.
- **Design mode:** a pinch never places a drawing point, never starts a
  band or a move, never selects. One finger on empty floor is a band (as
  a mouse drag); two fingers pan and zoom.

## Not in scope

- A long press in the design mode, and multi-select by touch there (the
  band works); a two-finger rotation of the view (the camera does not
  rotate); fling and double-tap zoom; a larger snap aperture for touch;
  a stylus's hover; a mouse and a finger at once (the existing one-pointer
  guard holds); contact size (TS-5).
- `fitToView` framing the live tables (D17's last clause): 14b-2 fits the
  page, the host-facing decision stands.
- A point placed by a finger held still past the hold-back, then joined
  by a second finger, stays placed (Backspace or Undo removes it): the
  drawing tool's phase is `idle`, so it is not cancelled (F-5).

## Files

- Render, changed: `lib/src/camera_gesture_detector.dart` (T2),
  `lib/src/interaction_layer.dart` (T3, T4), `lib/src/tool.dart`
  (`kind`, `held`), `lib/src/grip_cache.dart` (the radius parameter),
  `lib/src/select_tool.dart` (slop and grip radius by kind); the
  constants exported where their siblings are.
- Render, new tests: `test/camera_gesture_touch_test.dart`,
  `test/interaction_layer_touch_test.dart`; `test/select_tool_test.dart`
  gains touch cases.
- Planner: `lib/src/service/table_select_tool.dart` (T5); tests in
  `test/service/table_select_tool_test.dart` and `test/host/view_test.dart`
  (a pinch during a table drag, through the widgets).
- `apps/restaurant_demo`: no change; the exit smoke drives it with CDP
  touches in Chromium.

## Invariants

- Mouse, trackpad, stylus and signal behaviour is unchanged: every
  existing render, planner and app test passes unedited, except call
  sites that must name the new optional parameters (none expected).
- The frame path is untouched; the two allocation invariant tests and the
  goldens are untouched.
- In a multi session the tool receives nothing; a held finger the tool
  never saw is never followed by an up or a move for it.
- No command is executed by a pinch.

## Testing and named mutants

Fixtures: a camera at 0.1 px/mm, y up, translated off the origin; the
pinch off the view's centre, its fingers moving asymmetrically (one still,
one moving diagonally), with nonzero modifiers absent. Touch input through
`tester.createGesture(kind: PointerDeviceKind.touch)` with distinct
pointer ids, under fake time.

- **M-14t-1:** the zoom anchored on the first finger, not the midpoint —
  the world point under the initial midpoint ends under the final one.
- **M-14t-2:** the cumulative span ratio applied per event — a pinch from
  span 100 to 200 in four moves zooms by exactly 2.
- **M-14t-3:** no pan from the focal's motion — two fingers moving
  together by (30, −20) pan by (30, −20) and do not zoom.
- **M-14t-4:** the pair not re-based when a pair finger lifts with a third
  down — the camera does not jump at the lift.
- **M-14t-5:** no hold-back — a pinch in a drawing tool places no point; a
  recording tool sees no event at all.
- **M-14t-6:** a tap lost or misplaced — a touch tap reaches the tool as
  a down at the down's position, then an up.
- **M-14t-7:** a second finger does not cancel — a table drag joined by a
  second finger executes nothing and reports no layout change.
- **M-14t-8:** the session ends at the first lift (14c F-10) — after a
  pinch, the remaining finger's moves reach no tool.
- **M-14t-9:** touch promotion kept — idem, by the promotion path.
- **M-14t-10:** a touch hover routed — no hover reaches the tool after a
  touch tap; a mouse hover still does.
- **M-14t-11:** the pick radius not by kind — a touch tap 20 px from a
  line picks it; a mouse click 20 px away does not.
- **M-14t-12:** the select slop not by kind — a touch tap that jitters
  10 px selects (a click); a mouse press moved 10 px bands.
- **M-14t-13:** the grip radius not by kind — a touch press 20 px from a
  grip takes the grip; a mouse press does not.
- **M-14t-14:** the hold-back timer outliving the layer — a held finger,
  then the layer removed: the tool receives nothing.
- **M-14t-15:** the long press not measured from contact — a touch long
  press toggles at 500 ms, not 600.
- **M-14t-16:** the hold-back applied to a mouse — a mouse press reaches
  the tool at once.

## Risks

- **No device measured.** The spike is Chromium's CDP emulation; iOS and
  Android embedders deliver the same framework pointer events, but the
  look and feel (latency, a finger's jitter, the 100 ms hold-back) is owed
  to the human on a tablet.
- **100 ms on every touch press** before a tool sees it. Flutter's own tap
  recognisers wait for the up; a drag is routed as soon as it leaves the
  slop, so a drag does not feel it.
- **The render package changes** behind four tools' backs; the
  "unchanged for precise pointers" invariant is pinned by the existing
  suites passing unedited.

## Revision 2

The independent review of revision 1 ("Ready with fixes") prototyped T3
and T4 and ran the suites against them. Its findings, and what this
revision decides:

- **R-1 → T3a, the touch press mode (critical).** Revision 1 let a
  finger held past 100 ms reach any tool, and a drawing tool's down
  **executes**: `RoomTool` and `OpeningTool` commit on a single down
  (`room_tool.dart:174-215`, `opening_tool.dart:236-250`), the last down of
  a line, rectangle, circle or arc commits the shape, `TextTool` opens an
  entry; the "Backspace or Undo" escape does not exist (no drawing tool
  handles Backspace, Undo is disabled mid-shape, `planner_shell.dart:429-438`).
  F-5 and TS-8 are corrected accordingly. **Decision:** `Tool` gains
  **`touchPress`**, a `TouchPress` with two values, default **`lift`**:
  - **`press`** — the hold-back of T3 as written (up, slop, timeout).
    Opted into by the tools whose down executes nothing and whose `cancel`
    executes nothing: `SelectTool`, `TableSelectTool`, `SymbolPlaceTool`.
  - **`lift`** — every other tool, every `PlacementTool` included. A held
    finger is **never routed on a timeout**. Its moves past the slop are
    routed as **hovers** (`onPointerMove` with `buttons: 0`, the finger's
    position), so a drawing tool shows its snap marker and rubber band
    while the finger aims; its **up is routed as a down then an up at the
    up's position** (the point goes where the finger lifts). A second
    finger drops the held finger: the tool saw at most hovers.
  So **no tool executes a command because of a pinch**, in either mode.
  New mutant **M-14t-17**: `RoomTool`, a finger held 150 ms and moved,
  then joined by a second finger: `undoDepth` stays 0 and no room exists.
- **R-2 → the invariant on existing tests.** `flutter_test`'s `tap`,
  `tapAt`, `press`, `longPress`, `createGesture` and `startGesture`
  default to **`PointerDeviceKind.touch`** (new fact **F-8**): every
  existing canvas tap now runs through the hold-back. The invariant
  becomes: existing tests pass unedited **except** those whose taps are
  mouse clicks by intent and depend on a mouse-sized target; each such
  test gains `kind: PointerDeviceKind.mouse`, listed by name in the plan
  and in the results note. The review's prototype found seven, six of
  which pass again under R-3's two-stage pick.
- **R-3 → T4a, a two-stage touch pick.** `pickInto` returns the
  **topmost** entity within the radius (`spatial_index.dart:775`), not the
  nearest; a 48 px circle would pick a later-drawn neighbour over the line
  under the finger. **Decision:** `pickRadiusWorld` stays the precise
  radius (6 px) for every kind; `ToolPointerEvent` gains
  **`reachRadiusWorld`** — `kTouchPickRadiusPixels` (24 px) over the scale
  for a touch event, equal to `pickRadiusWorld` otherwise. `SelectTool`
  picks at `pickRadiusWorld`, and only on a miss at `reachRadiusWorld`.
  New mutant **M-14t-18**: a touch tap exactly on an earlier-drawn line,
  a later-drawn line 15 px away, picks the line under the finger.
- **R-4 → T4b, grips by distance on touch.** The rotation grip sits
  `kRotationGripOffset` = 24 px above the box's top centre and is tested
  first (`select_tool.dart:135-136`), so a 24 px reach would turn every
  press on a top-centre grip into a rotation. **Decision:** for a touch
  press the rotation grip and the grips compete **by screen distance**,
  each within 24 px; the nearest wins and a tie goes to the grip.
  `GripCache` gains the distance queries it needs (its `hitTest` and
  `hitsRotationGrip` keep their precise behaviour by default). New mutant
  **M-14t-19**: a touch press on a horizontal line's centre grip moves
  the grip, it does not rotate.
- **R-5, R-6, R-7 → the tests.** M-14t-7 also asserts that after the
  second finger the tool is `idle`, its preview null, and a tap after the
  pinch selects (the "no cancel" mutant leaves the tool stuck).
  M-14t-8 lifts one finger of a pinch, puts a new finger down and taps:
  the tool sees nothing, and the camera pairs the remaining finger with
  the new one. M-14t-12 holds the finger past `kTouchHoldBack` before it
  jitters. M-14t-6 lifts at least 10 px from the down (press mode: the
  down at the down's position; lift mode: at the up's). M-14t-2 uses
  `closeTo`; M-14t-3 a tolerance; M-14t-5 and -6 pump 200 ms after the
  gesture so a leaked timer shows.
- **R-8 → further mutants.** **M-14t-20** cancel on every multi start
  whatever the phase (two polyline points placed, a pinch: the shape is
  still pending); **-21** the `kPinchMinSpan` guard removed (fingers 2 px
  apart moving to 20 px do not zoom); **-22** the multi flag never reset
  (a tap after a pinch reaches the tool); **-23** the timer not cancelled
  on the up (tap, pump 200 ms: exactly one down); **-24** a held finger's
  cancel routed to the tool; **-25** a stylus taken as touch (a stylus
  press is routed at once; a stylus and a finger do not pinch).
- **R-9 → T3's open cases, closed.**
  (a) A held finger **claims `_activePointer`**: no precise pointer is
  routed while a finger is held or a session runs.
  (b) `deactivate` clears the **whole** session (held finger, live
  touches, multi flag, timer). A held finger is dropped when `tools`
  changes (`didUpdateWidget`) and when the active tool changes.
  (c) Focus is requested when a finger is **routed**, never at a physical
  down, so a pinch does not move focus. On the web a pinch's first finger
  outside an open text entry ends it through its tap-outside region —
  accepted, recorded.
  (d) A routed held down's `world` and radii come from the camera **at
  routing time**, at the down's screen position.
  (e) The hold-back's slop is **strictly greater than `kTouchSlop`**,
  Euclidean from the down — `TableSelectTool`'s own test (`<=` returns).
  (f) **`held` is dropped.** `TableSelectTool` starts its timer for
  `kLongPressTimeout − kTouchHoldBack` on a touch press: in press mode a
  touch down that can become a long press is always routed by the
  timeout.
- **R-10 → no stale markers.** When a touch session ends, and when it
  becomes multi, the layer calls the tool's **`onPointerExit`** (touch has
  no hover): the drawing tools' snap marker and `SymbolPlaceTool`'s ghost
  are hidden. `RulerFrame`'s pointer marker follows **precise pointers
  only**; a touch event clears it.
- **R-11 → the selection mode's reach; `fitToView`.** `TablePicker.pick`
  takes the reach: on a miss by containment, a **touch** tap picks the
  table whose top is **nearest within `reachRadiusWorld`** (distance to
  the top's boundary, in world units through the instance's transform;
  the higher handle on a tie). A mouse keeps containment only. New mutant
  **M-14t-26**: a touch tap 15 px outside a small table selects it, a
  mouse click there does not; a touch tap between two tables picks the
  nearer. **`fitToView` framing the live tables** (D17's last clause):
  **withdrawn** as an umbrella amendment (A-1): 14b-2 fits the page, which
  holds every table of a plan drawn on its sheet; listed for the human's
  look.
- **R-12 → T2's details.** The product of the ratios is
  `S_end / S_start` only while both spans exceed the minimum and the
  camera is not clamped. A pan of zero and a ratio of exactly 1 are
  skipped (Ruling 01-4). Each event may notify the camera twice (a pan,
  then a zoom); accepted.
- **R-13:** confirmed — the new `ToolPointerEvent` fields are optional,
  every `GripCache` call site keeps its default, only `PlacementTool`
  and its subclasses report `idle` on a down.
- **Facts amended.** F-3 cites `interaction_layer.dart:152-158`; the
  inner `Listener` (the layer) is dispatched before the outer (the
  camera) (`proxy_box.dart:186-188`, `gestures/binding.dart:506`): on a
  second finger the layer cancels the tool before the camera takes the
  pair's baseline. T2 and T3 keep their own lists of live touches; they
  agree because both cover the same box.
- **Files, added:** `jet_cad_2d_flutter/lib/src/ruler_frame.dart`;
  `jet_cad_floor_plan/lib/src/service/table_picker.dart`; the tests that
  gain `kind: mouse`.

