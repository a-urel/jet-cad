# 01 — App skeleton

**Status:** not started
**Depends on:** nothing
**Blocks:** everything
**Size:** S

---

## What this delivers

A real product application — `apps/floor_planner` — that opens a window,
shows a `DraftDocument` on a `DraftCanvas`, and pans and zooms smoothly with a
trackpad and a mouse. Empty slots for chrome (left panel, right panel, top
bar) that later sub-projects fill. Nothing else.

## Why it exists

Every later sub-project needs somewhere to land. Today the only thing that
hosts a canvas is `apps/dev_harness_2d`, which is a **measurement instrument**
— it drives its own frames, pins its own window size, and exists so device
figures are reproducible. Growing the product inside it would destroy the
instrument and the product at once.

The second half of this sub-project is a **lift, not an invention**: the
harness already contains correct, hard-won trackpad gesture handling. It is in
the wrong package. It moves into `jet_cad_2d_flutter` where it can be tested
by the widget suite.

## What already exists

- `DraftCanvas` — `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart:90`.
  Takes `document`, `index`, `camera`, `pixelsPerPaperMm`, `lineweightScale`,
  `drawText`, `minTextCapPixels`, `backend`, `tiles`, `tileDevicePixels`.
  **It has no gesture handling of any kind.**
- `CameraController` —
  `packages/jet_cad_2d_flutter/lib/src/camera_controller.dart:37`. A
  `ValueNotifier<ViewportTransform>` with `panBy(Offset screenDelta)` at `:40`
  and `zoomAt(Offset screenFocus, double factor)` at `:55`.
- **The gesture code to lift** — `apps/dev_harness_2d/lib/main.dart:1272-1303`.
  A `Listener` handling `onPointerMove`, `onPointerSignal`,
  `onPointerPanZoomStart` and `onPointerPanZoomUpdate`. The comment at `:1213`
  records the cumulative-delta finding; read it before touching this.
- `DraftDocument.empty(measurer: ...)`, `FlutterTextMeasurer`, `SpatialIndex`,
  `StyleResolver` — the wiring `DraftCanvas` needs. `DraftCanvasState`
  throws a message containing the exact construction snippet if the measurer is
  missing (`draft_canvas.dart:248-258`).
- `generate_document.dart` in `packages/jet_cad_2d/lib/testing.dart` and
  `apps/dev_harness_2d/lib/seam_corpus.dart` — sample content to open with.

## What does not exist

- Any product application.
- Any reusable gesture widget. The harness's copy is application code, tested
  only by the harness's 72 tests, and is not exported from any package.
- Any document lifecycle — new / open / close. (File I/O is 12; this
  sub-project may hard-code a generated document.)

## Decisions already made

1. **A new app, `apps/floor_planner`,** as a workspace member of the root
   pubspec beside `dev_harness_2d`. The harness is not touched.
2. **Gesture handling lifts into `packages/jet_cad_2d_flutter`** as a widget —
   working name `CameraGestureDetector` — wrapping or composing with
   `DraftCanvas`. Rationale: it is render-layer behaviour, it needs the widget
   suite's mutation coverage, and every future host of a canvas wants it.
   Whether `DraftCanvas` gains it internally or it stays a separate wrapper is
   an open question below.
3. **Tiles off.** `DraftCanvas(tiles: false)`. See the scale note in the
   standing context. Turning them on is a measured decision, not a default.
4. **Desktop first.** macOS is the machine the repo is measured on.

## Open questions — answer these in the spec

- Does `DraftCanvas` gain gestures internally, or does a separate
  `CameraGestureDetector` wrap it? A separate widget keeps `DraftCanvas` a pure
  view and lets a caller opt out; internal handling is fewer moving parts. The
  harness must keep working either way — it drives the camera directly and
  must not receive gestures during a measurement.
- Zoom limits. Minimum and maximum scale, and what happens at the clamp.
  `zoomAt` "ignores a non-positive or non-finite factor" (`main.dart:1300`) but
  has no range clamp. `flutter_diagram_editor` (MIT) defaults to
  `0.2-5.0`; a CAD tool normally wants a far wider range than a diagram
  editor, so treat that as a lower bound on ambition rather than as the
  answer.
- Mouse-wheel zoom step size, and whether it is multiplicative per notch.
- Does middle-drag pan, as in most CAD tools, in addition to the current
  any-button drag?
- What document does the app open at startup, before 12 exists?
- Window size and whether it is restorable. The harness deliberately pins its
  window and sets `isRestorable = false`
  (`apps/dev_harness_2d/macos/Runner/MainFlutterWindow.swift`); a product wants
  the opposite. Do not copy that file wholesale.

## Exit criteria sketch

- The app builds and runs on macOS and shows a non-empty drawing.
- A widget test drives a `PointerPanZoomStart` / `PointerPanZoomUpdate`
  sequence and asserts the camera moved by the expected amount — from a
  **non-identity** starting transform.
- A widget test drives two-finger scroll (`scale` exactly 1.0, motion in
  `pan`) and asserts the camera **panned** and did **not** zoom.
- A widget test drives a mouse wheel `PointerScrollEvent` and asserts zoom
  about the pointer position, not about the viewport centre.
- The harness's 72 tests still pass unchanged.

## Named mutants to fire

- **M-01a:** in the pan-zoom update handler, treat `event.pan` as a delta
  rather than as cumulative-since-start. The cumulative test must go red.
- **M-01b:** replace `factor / _gestureZoom` with `factor`. The pinch test must
  go red.
- **M-01c:** zoom about the viewport centre instead of `event.localPosition`.
  The wheel test must go red — **this is the mutant a fixture centred on the
  viewport cannot kill**, so place the zoom focus off centre.
- **M-01d:** drop the `onPointerPanZoomUpdate` handler entirely, keeping
  `onPointerSignal`. Everything must still go red — see the trap below.

## Traps

- **A macOS trackpad never sends `onPointerSignal`.** Only a real mouse wheel
  reaches it. This was a live defect fixed at `fc05076`: instrumenting every
  pointer callback and driving the trackpad logged **709
  `PointerPanZoomUpdateEvent`s and zero pointer signals**. A test suite built
  only on `PointerScrollEvent` will pass while the trackpad is dead.
- **Two-finger scroll reports its motion as `pan` with `scale` exactly 1.0.**
  Handling `scale` alone fixes pinch and leaves scrolling dead.
- **`pan` and `scale` on `PointerPanZoomUpdateEvent` are cumulative since
  gesture start, not per-event deltas.** The harness comment at
  `main.dart:1213` says so; the code divides by the running value for exactly
  this reason.
- Do not copy the harness's `MainFlutterWindow.swift`. It pins the window to a
  fixed size and disables state restoration so that measurements are
  comparable — correct for an instrument, wrong for a product.

---

## Standing context — read before touching anything

**Repo:** `/Users/ahmeturel/Projects/oss/jet-cad`, Dart/Flutter workspace,
branch `main`. **Read `STATUS.md` first**, then `CLAUDE.md`. The full roadmap
context, the target and the dependency graph are in `roadmap/00-README.md`.

**The target:** a **parametric** floor planner. Walls have thickness and clean
up at their corners, openings cut the walls that host them, rooms follow the
walls that enclose them. Chosen by the human on 2026-08-29 over the
stencil-diagram alternative.

**This file is an input to `superpowers:brainstorming`, not a plan.** Read it,
brainstorm, write a spec into `docs/superpowers/specs/`, write a plan into
`docs/superpowers/plans/`, then execute it task by task with
`superpowers:subagent-driven-development`.

**Packages:**

- `packages/jet_cad_2d` — the pure-Dart engine. **No Flutter, no `dart:ui`,
  ever.**
- `packages/jet_cad_2d_flutter` — the Flutter render layer. Here
  `unused_import` and `unused_element` are **errors**.
- `apps/dev_harness_2d` — the measurement harness. An instrument, not a
  product; do not grow the product inside it.

**Non-negotiables (`CLAUDE.md`):**

- The frame path allocates **nothing per entity** in steady state, O(1) per
  flush. Gated by `query_allocation_test.dart` and `paint_allocation_test.dart`.
- **Draw order is ascending handle value**, stable across undo, save, load and
  purge.
- Geometric **decisions** use `Tolerance`; **stored value** comparisons are
  exact `==`.
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three
  of them in this workspace.
- **Never synthesize test output.**
- Code, comments and commit messages in English.

**Every task ends green:**

```sh
cd packages/jet_cad_2d          && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter  && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

**Prefix test commands with `CI=true`** — otherwise Dart's analytics
phone-home blocks the runner for minutes at roughly zero CPU.

**Never `git checkout` a file to revert a mutation.** Copy aside with `cp`,
mutate, restore from the copy, `diff` to verify.

**The testing bar.** Defects here surface through **mutation and differential
testing**, not through reading. The dominant failure mode is the **degenerate
fixture** — a test that passes because every fixture sits at the identity
transform, the origin, or a default attribute. A new test is worth landing only
if a **named mutation** makes it go red. This repository has repeatedly caught
instruments that could not fail; assume yours is one until a mutant proves
otherwise.

**Scale note.** A floor plan is 500–5,000 entities, not 500,000. The repo's own
figures: a 10,000-entity frame is 9.5 ms at `DASHED=0`, and the vertices sink
draws 10,000 entities in 5.71 ms build / 6.68 ms raster. **Default the tile
cache off** (`DraftCanvas(tiles: false)`) and turn it on only if a measurement
demands it. Plan 3i's blurry-zoom behaviour is a 500,000-entity problem.
