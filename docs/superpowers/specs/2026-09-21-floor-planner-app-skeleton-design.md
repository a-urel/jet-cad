# The floor planner app skeleton — design

**Date:** 2026-09-21. **Status:** design, **revision 2**, not yet a plan.
Revision 1 was reviewed the same day by three independent reviewers (Claude,
Codex, Copilot CLI); every finding was re-verified against the SDK and the
repo and is recorded in
[2026-09-21-app-skeleton-spec-review-r1.md](../notes/2026-09-21-app-skeleton-spec-review-r1.md).
Revision 2 applies all of them. B1 reopened the web scroll decision; **the
human re-decided it on 2026-09-21 (option c, below)** and revision 2 carries
the new answer.
**Sub-project:** `roadmap/01-app-skeleton.md`. **Size:** S — but see
[What this brainstorm changed](#what-this-brainstorm-changed-and-why-01-is-no-longer-purely-a-lift).
**Brainstormed with the human on 2026-09-21**, on `main` at `a713589`.
**Depends on:** nothing. **Blocks:** everything.

**Evidence of record for the findings below:** the installed Flutter SDK,
**3.47.2** (`bin/cache/flutter.version.json`, framework `d3b14c8`, engine
`a804b26`; it lives under a cask directory still named `3.27.3`, which revision
1 misread as the version). Files cited by line:
`packages/flutter/lib/src/gestures/events.dart` (`PointerScaleEvent` at
2094, *"Pinching-to-zoom in the browser"* at 2085; `PointerPanZoomUpdateEvent`
at 2293 with `panDelta`/`localPanDelta` at 2315-2317) and
`engine/src/flutter/lib/web_ui/lib/src/engine/pointer_binding.dart`
(`_isTrackpadEvent` 678-735, wheel conversion 730-810, `preventDefault`
875-877). Read 2026-09-21.

---

## What this brainstorm changed, and why 01 is no longer purely a lift

The roadmap file calls the second half of this sub-project *"a lift, not an
invention"* — the harness's trackpad handling moves into
`jet_cad_2d_flutter`. Two things found during the brainstorm make that
false, and both must be in the plan before a line is written.

### 1. The harness zooms on two-finger scroll; the exit criteria want it to pan

`apps/dev_harness_2d/lib/main.dart:1228` converts a two-finger scroll's
`localPan.dy` into a **scale** factor:

```dart
final factor = event.scale * math.exp(event.localPan.dy / -200.0);
```

The roadmap's own exit criteria sketch (`01-app-skeleton.md:108-109`) asks for
a test asserting that two-finger scroll **panned and did not zoom**. These
contradict. **The human chose pan** on 2026-09-21: the product's two-finger
scroll pans, pinch zooms.

So the `exp(pan.dy / -200)` conversion does **not** move into the package. It
stays in the harness, whose measurement arms depend on it, and the product
grows a different rule in its place. What does lift, unchanged and for the
reason the harness's own comment gives, is the **cumulative-since-start**
handling of `scale`: `scale` on `PointerPanZoomUpdateEvent` is cumulative and
has no per-event counterpart, so the running-value division stays. **Pan does
not need it**: the same event carries `panDelta` and `localPanDelta`
(`events.dart:2315-2317`), computed by the engine from its own running state.
The widget pans by `localPanDelta` and holds no running pan value. (Revision 1
said pan needed the same subtraction; the review corrected it.)

**Two pointers in the roadmap file are stale and the plan should not chase
them.** `01-app-skeleton.md:40` puts the gesture code at `main.dart:1272-1303`; it
is at **`1201-1233`**. `01-app-skeleton.md:42` and `:137` put the
cumulative-since-start comment at `main.dart:1213`; it is at
**`1146-1152`**, on the `_gestureZoom` field. Both moved and neither claim is
wrong about the content — only about where to find it.

**Consequence:** the harness is not touched, and its suite must pass
unchanged. The plan records the harness's test count **at the branch point**
rather than asserting one — `roadmap/01-app-skeleton.md:112` says 72,
`STATUS.md`'s Plan F gate records `dev_harness_2d 82`. Neither number is
assumed; the branch point is measured and the number written down.

### 2. Web is a target, and web never sends a pan/zoom event

> **Revised after review finding B1.** Revision 1 said *"a two-finger
> trackpad scroll and a mouse-wheel notch are the same event and cannot be
> distinguished"*. **False as stated.** The engine classifies every browser
> `wheel` event as mouse or trackpad with a delta heuristic
> (`pointer_binding.dart:678-735`: on Firefox always mouse; otherwise
> "accelerated" deltas mean mouse, deltas divisible by 120 mean mouse unless
> the previous event was a trackpad within 50 ms) and emits the
> `PointerScrollEvent` with `kind: PointerDeviceKind.trackpad` or `.mouse`
> (`:735-740`). Flutter's own `InteractiveViewer` branches on that
> (`interactive_viewer.dart:884-891`: trackpad scroll pans, wheel scales).
> The true statement: *distinguishable on Chromium and WebKit by a heuristic
> that calls itself non-standard; never on Firefox.* The decision below was
> re-taken on that basis.

The human confirmed on 2026-09-21 that **the product targets web**. That makes
the rule above implementable there only through the engine's heuristic, and
the reason is in the engine, not in this repo.

Flutter web's `pointer_binding.dart` converts a browser `wheel` event into
exactly two things and never into a third:

- `PointerSignalKind.scale` when the ctrl key is held — surfacing in Dart as
  **`PointerScaleEvent`**, whose own doc comment is *"Pinching-to-zoom in the
  browser is an example of an event that would create a
  [PointerScaleEvent]"*;
- `PointerSignalKind.scroll` otherwise — surfacing as
  **`PointerScrollEvent`**.

Both carry `change: ui.PointerChange.hover`. **`PointerPanZoomStart/Update/End`
are never emitted on web at all.** And the engine normalises `deltaMode`
(`domDeltaLine`, `domDeltaPage`, `domDeltaPixel`) into pixels *before* the
event reaches Dart, so the one signal a browser gives for telling a trackpad
from a wheel is gone by the time any of this repo's code could read it.

**Therefore, on web, a two-finger trackpad scroll and a mouse-wheel notch
arrive as the same event type, told apart only by the `kind` heuristic above
and not at all on Firefox.**

This inverts the macOS trap the roadmap file warns about
(`01-app-skeleton.md:128-131`, the `fc05076` defect: a macOS trackpad sends
**709** `PointerPanZoomUpdateEvent`s and **zero** pointer signals). The two
traps are mirror images, and a suite built for either platform alone leaves
the other dead:

| | trackpad scroll | trackpad pinch | mouse wheel |
|---|---|---|---|
| **macOS / Windows / Linux** | `PointerPanZoomUpdate`, `scale == 1.0`, motion in `pan` | `PointerPanZoomUpdate`, motion in `scale` | `PointerScrollEvent` |
| **Web** | `PointerScrollEvent`, `kind: trackpad` on Chromium/WebKit by heuristic, `kind: mouse` on Firefox | `PointerScaleEvent` (browser-synthesised ctrl+wheel) | `PointerScrollEvent`, `kind: mouse` — *same type as trackpad scroll* |

**The human's decision, re-taken 2026-09-21 after the review — option (c):**
CAD-native wherever the trackpad can be told from the wheel, web-native where
it cannot. Concretely: **a trackpad scroll pans and a mouse wheel zooms on
desktop and on Chromium/WebKit browsers; on Firefox, where every wheel event
is `kind: mouse`, a bare scroll pans** (Figma's rule) because zooming on it
would take pan-by-scroll away from every Firefox trackpad user. The options
weighed: (a) web-native everywhere, ignoring `kind`; (b) CAD-native
everywhere, which on Firefox makes a trackpad scroll zoom; (c) this. The
misclassification risk in the heuristic is accepted as the engine's own,
recorded, and covered by criterion 12's look in both browser families.

**One consequence worth stating: the desktop policy and the Chromium/WebKit
policy are the same value.** On desktop the trackpad never arrives as a scroll
signal at all, so "mouse-kind scroll zooms, trackpad-kind scroll pans" is
exactly the desktop rule too. The policy therefore collapses to one field —
what a bare mouse-kind scroll means — and the only platform that sets it
differently is Firefox. `GesturePolicy.web` from revision 1 no longer exists.

---

## What this delivers

`apps/floor_planner` — a real product application that opens a resizable
window, shows a floor-plan document on a `DraftCanvas`, and pans and zooms
smoothly with a trackpad and a mouse on macOS and on web. Empty slots for
chrome that later sub-projects fill. A reusable `CameraGestureDetector` in
`jet_cad_2d_flutter`, covered by the widget suite on **both** platform
policies from one test runner.

## Non-goals

- Selection, hover, grips, tools, rubber band — 02 and 03.
- Grid, rulers, paper, page breaks — 04.
- File open/save, menus, panels with content in them — 12.
- Any parametric behaviour — 06 onward.
- Rotation. The camera is pan and zoom only; `ViewportTransform` supports a
  general affine and `visibleWorld` already transforms all four corners for
  it, but nothing in this sub-project produces a rotated camera.
- Touch. The pointer kinds handled are trackpad, mouse and (on web) their
  browser equivalents. A touchscreen is out of scope here.
- Turning the tile cache on, or choosing `RenderBackend.residentGpu`. See the
  decision below — web settles it.

---

## Decisions

### D1 — A separate `CameraGestureDetector`, not gestures inside `DraftCanvas`

`DraftCanvas` stays a pure view. The gesture widget wraps it.

The deciding argument is not "fewer moving parts" either way, it is the
harness: `apps/dev_harness_2d` drives the camera directly and **must not
receive gestures during a measurement**. With a separate widget that opt-out
is free — the harness simply does not use it, and its existing `Listener`
keeps working. With gestures inside `DraftCanvas` the opt-out has to be
written as a flag, tested, and kept correct forever, and the "pure view"
guarantee is gone for no gain.

It also matches the roadmap's working name and gets the widget into
`jet_cad_2d_flutter` where the widget suite's mutation coverage reaches it.

### D2 — The platform difference is an **injected policy value**, never `kIsWeb` at the branch point

This is the load-bearing testability decision and it follows directly from
`CLAUDE.md`'s testing bar.

`kIsWeb` is a compile-time constant. If the widget branches on it inline, a
`flutter test` run on macOS **can never execute the web branch**, no mutation
planted there can go red, and every web behaviour in this spec would ship with
an instrument that cannot fail — precisely the failure mode this repository
has caught repeatedly.

So the widget takes a `GesturePolicy` value. The application passes
`GesturePolicy.forPlatform()`, which is the only place `kIsWeb` appears. Tests
pass `GesturePolicy.wheelZooms` or `GesturePolicy.wheelPans` explicitly and exercise
both arms on one runner.

There is house precedent for exactly this shape: `debugSetGpuAvailable`
(Ruling F14) exists so a `DraftCanvas` widget test can take the `residentGpu`
path without a GPU, and it is the one name the barrel's `show` clause admits
from `gpu_facade.dart`. A policy value is the same move, made at design time
rather than retrofitted.

```dart
enum ScrollSignalAction { pan, zoom }

@immutable
class GesturePolicy {
  const GesturePolicy({
    required this.mouseWheel,
    this.wheelZoomStep = 1.1,
    this.panButtons = kMiddleMouseButton,
  });

  /// What a `PointerScrollEvent` of `kind: mouse` (or any kind other than
  /// trackpad) with no modifier means. A trackpad-kind scroll signal pans
  /// under every policy; it is not a field.
  final ScrollSignalAction mouseWheel;

  /// Multiplicative step per wheel notch on the `PointerScrollEvent` zoom
  /// path. A `PointerScaleEvent` carries its own factor and ignores this.
  final double wheelZoomStep;
  final int panButtons;

  /// Desktop embedders and Chromium/WebKit browsers: the wheel zooms.
  static const wheelZooms = GesturePolicy(mouseWheel: ScrollSignalAction.zoom);

  /// Firefox: every wheel event is `kind: mouse`, so the wheel pans.
  static const wheelPans = GesturePolicy(mouseWheel: ScrollSignalAction.pan);

  /// Pure, VM-testable: the browser question, answered.
  static GesturePolicy forBrowser({required bool firefox}) =>
      firefox ? wheelPans : wheelZooms;

  /// The only place `kIsWeb` appears. `isFirefoxBrowser()` comes from a
  /// conditional import: `dart:ui_web`'s `browser.isFirefox` on web, `false`
  /// elsewhere.
  factory GesturePolicy.forPlatform() =>
      kIsWeb ? forBrowser(firefox: isFirefoxBrowser()) : wheelZooms;
}
```

Named `ScrollSignalAction`, not `ScrollAction`: Flutter's `widgets.dart`
exports a class of that name and a consumer importing both could not name
the enum (execution ruling, Task 4).

**Why `dart:ui_web` and not a user-agent string.** The heuristic that tags a
scroll event `kind: trackpad` gives up on Firefox by asking
`ui_web.browser.browserEngine == BrowserEngine.firefox`
(`pointer_binding.dart:689`). `forPlatform()` asks the *same object the same
question*, so the policy and the heuristic cannot disagree about which
browser they are in. `dart:ui_web` exists only on web, so it lives behind a
conditional import (`gesture_policy_platform_web.dart` /
`gesture_policy_platform_stub.dart`), the same shape `flutter_scene`'s GPU
shim uses. `forBrowser` is the pure half and is tested on the VM; the
`kIsWeb` line and the import are the impure half and are not.

**`PointerPanZoom*` is handled under both policies.** Revision 1 had a
`honoursPanZoomEvents` flag that made the web policy ignore them, so a test
could pin "the arm a browser never delivers". The review struck it: the engine
never emits those events on web, so ignoring them there is invisible to a
user and only hurts if a future engine adds them. A flag that encodes an
engine quirk as a product rule is not a policy. (Mutant M-01h went with it.)

**`forPlatform()` is not under the VM test gate, and no mutant pretends it
is.** `kIsWeb` is a compile-time constant; on a macOS `flutter test` run it is
`false`, and the widget suite injects policies explicitly and never calls
`forPlatform()`. Revision 1's M-01e mutated `forPlatform()` and could not die
there. The load-bearing seams are the widget honouring the *injected* policy
(M-01e) and `forBrowser` answering the browser question (M-01q).
`forPlatform()`'s one line and the conditional import are covered by
criterion 12's look in Chrome/Safari *and* Firefox, and that is written down
as the argument.

### D3 — The gesture table

| Input | Desktop, and Chromium/WebKit browsers (`wheelZooms`) | Firefox (`wheelPans`) |
|---|---|---|
| Two-finger trackpad scroll | **pan** — desktop: by `localPanDelta` (`PointerPanZoomUpdate`); browser: by `-scrollDelta` (`PointerScrollEvent`, `kind: trackpad`) | **pan** by `-scrollDelta` (`PointerScrollEvent`, `kind: mouse` — Firefox cannot tag it) |
| Trackpad pinch | **zoom** — desktop: about the gesture anchor (cumulative `scale`, running division); browser: about the pointer by `event.scale` (`PointerScaleEvent`, per-event, raw) | **zoom** about the pointer by `event.scale` (`PointerScaleEvent`) |
| Pinch that drifts (`localPanDelta ≠ 0` and `scale ≠ 1` in one event) | desktop: **both** — pan by the delta, zoom by the ratio about the anchor, as the harness does; browser: n/a, never one event | n/a |
| Mouse wheel, no modifier (`kind: mouse`) | **zoom** about the pointer, 1.1× per notch | **pan** by `-scrollDelta` — same event as a trackpad scroll here |
| ctrl + wheel | desktop: zoom (the bare-wheel row; ctrl is not read); browser: **zoom** — three paths, see below | **zoom** — same three paths |
| cmd + wheel | desktop: zoom (the bare-wheel row); browser: **zoom** about the pointer, 1.1× per notch, `HardwareKeyboard.isMetaPressed` | **zoom**, same |
| Middle-button drag | **pan** | **pan** |
| Left-button drag | **nothing** | **nothing** |

**The scroll-signal rule, in order.** For a `PointerScrollEvent`: a modifier
held (`HardwareKeyboard` ctrl or meta) → zoom by `wheelZoomStep`; else
`kind == PointerDeviceKind.trackpad` → pan by `-scrollDelta`; else →
`policy.mouseWheel`. The `kind` test is not policy: a trackpad-kind scroll
pans under every policy, and only Firefox never produces one. A
`PointerScaleEvent` zooms and a `PointerPanZoom*` sequence pans-and-zooms
under every policy.

**A scroll signal with `dy == 0` has no zoom direction.** A tilt wheel or a
horizontal mouse scroll reports it; on the zoom arm it does nothing (it is
not an unmarked zoom-out), on the pan arm it pans by `-dx` like any other.
Found by the final review; mutant M-01r.

**Misclassification is the engine's, accepted and named.** The heuristic can
tag a trackpad flick `mouse` (a delta that happens to be a multiple of 120
with no trackpad event in the last 50 ms) or an accelerated wheel `trackpad`;
under `wheelZooms` the first zooms and the second pans, each the opposite of
the hand's intent for one event. `InteractiveViewer` lives with the same
thing. It is not worked around here, and criterion 12 looks for it.

**Signs, stated.** `PointerPanZoomUpdateEvent.localPanDelta` is finger motion:
the content follows the fingers, so the camera pans by `+localPanDelta`.
`PointerScrollEvent.scrollDelta` is content-scroll: positive `dy` means "scroll
down", the content moves up, so the camera pans by `-scrollDelta`. That is the
Figma/Miro convention and it is what makes the two arms agree in the
cross-policy test below. A test asserts the absolute direction of each arm, not
only their agreement (M-01m).

**"ctrl + wheel zooms" on web is three code paths, not one**
(`pointer_binding.dart:766-780`). The engine emits a `PointerScaleEvent` when
the DOM event has `ctrlKey` — which is what every browser synthesises for a
trackpad pinch, and what a real ctrl+wheel produces on Windows and Linux —
**except on macOS when the physical Control key is down** (`ignoreCtrlKey`, so
a real ctrl+wheel is not mistaken for a pinch), where it emits a plain
`PointerScrollEvent`. It never reads `metaKey`. `PointerScrollEvent` carries
no modifier fields. So the widget's web rule is: `PointerScaleEvent` → zoom
by `event.scale`; `PointerScrollEvent` with `HardwareKeyboard.instance`
reporting ctrl or meta pressed → zoom by `wheelZoomStep` per notch; otherwise
→ the `kind`-then-policy rule above. The modifier tests hold the key down with `sendKeyDownEvent` before
sending the scroll, because `TestPointer.scroll` cannot attach one.

**`PointerScaleEvent.scale` is per-event and applied raw.** The engine
computes it as `exp(-deltaY / 200)` from each DOM event on its own
(`pointer_binding.dart:786`) — the same formula the harness uses for a
desktop trackpad, which is why Flutter chose it. It is **not** cumulative, so
the desktop `factor / _gestureZoom` division must not be applied to it; a
mutant does exactly that (M-01n). Consequence, recorded not smoothed: a
mouse-wheel notch on a Windows or Linux browser is `deltaY ≈ 100`, so
ctrl+wheel there zooms **≈1.65× per notch**, against the desktop wheel's 1.1×.
The spec accepts the browser's own mapping rather than normalising it;
criterion 12's browser look includes that notch, and if it is judged too
coarse the fix is a policy field, not a change to this rule.

**The left button does nothing, deliberately.** The harness pans on
`event.buttons != 0` (`main.dart:1203`) — any button drags the view. In the
product the left button belongs to 02: selection, and the rubber band. Leaving
it free now means 02 does not have to remove a behaviour users already learned,
and it is cheaper to test the absence than to unpick the presence later. It is
a named mutant below for exactly that reason.

Wheel zoom stays **multiplicative at 1.1 and 1/1.1 per notch**, about
`event.localPosition`, which is the harness's rule and is correct
(`main.dart:1207-1208`: scroll up is negative `dy` on every platform Flutter
reports).

### D4 — Zoom limits live on `CameraController`, as constructor bounds

The clamp belongs where every caller passes through, not in the gesture
widget: a keyboard zoom, a zoom-to-fit and a future zoom-to-selection must all
obey it, and a clamp in the widget guards only the one path.

But `CameraController` is shared with the harness, and the harness's
measurement arms must not change behaviour. So the bounds are **constructor
parameters defaulting to unbounded**:

```dart
CameraController(
  super.initial, {
  this.minScale = 0.0,
  this.maxScale = double.infinity,
});
```

The harness constructs it as it does today and is byte-for-byte unaffected.
The product constructs it with limits.

**The clamp is applied to the resulting scale, and the factor is adjusted to
land on the bound** — not "reject the gesture when the result would be out of
range". Rejecting makes the view stick and jump; landing on the bound makes it
come smoothly to rest. At the bound the gesture continues to be consumed and
the camera does not move.

**"Does not move" means no notification either, and it is tested.**
`ViewportTransform` has identity equality and `CameraController` is a
`ValueNotifier`, so assigning a freshly built transform notifies and repaints
even when nothing changed. The clamp therefore returns early — no assignment —
when the camera is already at the bound the gesture pushes against. A test
counts listener calls across a repeated out-of-range zoom at each bound and
expects zero after the first landing (M-01o).

`ViewportTransform.scale` — the geometric mean of the axis scales,
`worldToScreenMatrix.scaleMagnitude`, which is `sqrt(|det|)`
(`transform2.dart:87`) — is the quantity clamped. That is the same number
stroke widths divide by, so the bound has a meaning a user can see.

**It is a derived value, so the comparisons around it are geometric decisions
and use `Tolerance`, not `==`.** Revision 1 called the clamp an exact
stored-value comparison. It is not: the landing goes through
`zoomAt(focus, bound / scale)` — a three-matrix product, a determinant and a
square root — and comes back off the bound by ulps. Two decisions, both under
`Tolerance`: *is the requested result past a bound* (compare
`scale * factor` against the bound) and *is the camera already at the bound*
(the early-return test above). Criterion 8 asserts the landing within
`Tolerance`, and M-01l is what keeps "within tolerance" from becoming "roughly
there": a fixture starting off the identity lands somewhere else entirely under
that mutant, far outside any tolerance.

**Range: `0.001` to `100`** logical pixels per world unit, a CAD range roughly
two decades wider each way than `flutter_diagram_editor`'s `0.2–5.0`, which the
roadmap correctly calls a lower bound on ambition rather than an answer. **The
plan must sanity-check both constants against the startup document's actual
units before freezing them** and record the check; a number chosen in a spec
and never looked at through the window is exactly the kind of constant this
repo has been burned by.

The check was done 2026-09-21 in `startup_plan_test.dart`: at a 1440×900
viewport the startup document fits at **0.095 px/mm**, with **95.0×**
headroom out to `kMinScale = 0.001` and **1052.6×** headroom in to
`kMaxScale = 100.0`. Both constants are unchanged.

`zoomAt`'s existing guard — a non-finite or non-positive factor is ignored
rather than applied, because it would make the matrix singular and `invert()`
would throw inside the frame — stays, and the clamp is layered after it.

### D5 — Startup document: a small hand-written floor plan

Between 500 and 1,000 entities, a fixed room layout, in the product app (not
in `testing.dart`, not `seam_corpus.dart`). It is at the low end of the target
scale (500–5,000),
it is eye-checkable — a human can see whether the walls closed — and when 04
and 07 land it is the comparison ground for whether the parametric version
draws the same thing.

`generate_document.dart` is synthetic and does not look like a floor plan;
`seam_corpus.dart` is the harness's corpus, written to stress render seams,
and depending on it from the product would couple the product to the
instrument. An empty document contradicts the "shows a non-empty drawing" exit
criterion and leaves nothing on screen until 05.

**The document is off-origin and not axis-symmetric.** A fixture centred on the
origin is the degenerate fixture this repo's testing bar names, and the startup
document is the fixture a human will eyeball every single session.

### D6 — Tiles off, `backend` unset — and web settles it

`DraftCanvas(tiles: false)` with `backend` at its default
(`RenderBackend.vertices`). The roadmap's scale note already recommended this:
a floor plan is 500–5,000 entities, the repo's own figures put a
10,000-entity frame at 9.5 ms with `DASHED=0` and the vertices sink at
5.71 ms build / 6.68 ms raster, and Plan 3i's blurry-zoom behaviour is a
500,000-entity problem.

**Web removes the remaining question.** `RenderBackend.residentGpu` does not
run on web — `resolveBackend` routes it back to `vertices` where Flutter GPU
is absent, and `flutter_gpu` cannot compile there at all. A product that must
run on web cannot have it as a default on any platform without shipping two
different renderers, and the open question the roadmap left for this
sub-project's brainstorm ("choosing it is a question for this sub-project, with
a number attached") is therefore **closed: not here, and not by this
sub-project.** No number is owed.

Turning tiles on remains a measured decision for a later sub-project, never a
default.

**`jet_cad_2d_flutter` has never been built for web.** It compiles there only
because `flutter_scene`'s internal shim conditionally exports a WebGL2 backend
in place of `flutter_gpu` (`flutter_scene-0.23.0/lib/src/gpu/gpu.dart`, and
the note in `gpu_facade.dart`). Criterion 2 is the first attempt in this
repository's history; a failure there is a finding about the package, not a
regression by this sub-project, and is recorded as such.

### D7 — Window: an ordinary product window, restorable

Resizable, default 1440×900, `isRestorable` left at its default so macOS
remembers size and position. **No custom Swift.** The generated
`MainFlutterWindow.swift` is not edited — it takes its frame from the nib
(`self.frame`), and the generated `MainMenu.xib` gives that frame
`contentRect` 800×600 (template `MainMenu.xib:335`). **The 1440×900 default
is therefore one edit to `MainMenu.xib`'s `contentRect`**, which is the
generated file's own knob for exactly this. The harness's Swift copy is not
consulted for anything: it pins the window and sets `isRestorable = false` so
measurements are comparable, which is right for an instrument and wrong for a
product (`01-app-skeleton.md:139-142`).

### D8 — Desktop first in execution order, web in the same plan

macOS is the machine the repo is measured on and is where the plan runs. But
the web arm is **not deferred to a later sub-project**: the policy seam (D2)
means both arms are written and tested together, and a `flutter build web`
that succeeds plus a human's look in a browser are exit criteria here. What
*is* deferred is any web performance work.

---

## Architecture

```
pubspec.yaml                             + apps/floor_planner in `workspace:`

apps/floor_planner
  pubspec.yaml           resolution: workspace; depends on jet_cad_2d,
                         jet_cad_2d_flutter, vector_math — the harness's shape
  lib/main.dart          window, theme, the empty chrome slots
  lib/startup_plan.dart  D5's hand-written document
  lib/planner_view.dart  CameraGestureDetector( DraftCanvas( ... ) )
  macos/                 generated; MainMenu.xib contentRect → 1440×900 (D7)
  web/                   generated, untouched (criterion 2)
  test/                  the startup document's off-origin / non-empty test
  analysis_options.yaml  generated, committed once at scaffold, never a rewrite (plan Ruling 01-1)

packages/jet_cad_2d_flutter
  lib/src/camera_gesture_detector.dart          the widget          (new, exported)
  lib/src/gesture_policy.dart                   the policy value    (new, exported)
  lib/src/gesture_policy_platform_stub.dart     isFirefoxBrowser() => false   (new, not exported)
  lib/src/gesture_policy_platform_web.dart      dart:ui_web browser.isFirefox (new, not exported)
  lib/src/camera_controller.dart                + minScale/maxScale (changed)
```

`gesture_policy.dart` imports the stub with
`if (dart.library.js_interop) 'gesture_policy_platform_web.dart'`; the web
file is the only file in the package that imports `dart:ui_web`, and the
analyzer on macOS sees the stub.

The empty chrome slots are a left panel, a right panel and a top bar, laid out
and sized but holding nothing. They exist so that 04, 05 and 12 add to a
layout rather than invent one, and so the window a human looks at in this
sub-project is the shape of the window they will look at in 12.

`CameraGestureDetector` is a `StatefulWidget` over a `Listener` — not a
`GestureDetector`. The harness's comment chain is the reason and it is
inherited wholesale: the events this needs (`onPointerSignal`,
`onPointerPanZoomStart/Update`) are `Listener`'s, and the arena a
`GestureDetector` joins would have to be fought for nothing. Its state is the
running `_gestureZoom` cumulative scale and the gesture anchor, and it holds
nothing else — pan uses the event's own `localPanDelta` and needs no state.

---

## Invariants

1. **The harness is not edited.** Not one file under `apps/dev_harness_2d`.
   Its suite passes at the branch-point count, which is recorded, not assumed.
2. **`DraftCanvas` gains no gesture handling** and no new parameter.
3. **`CameraController`'s existing behaviour is unchanged for a caller that
   passes no bounds.** The harness is that caller.
4. **The frame path still allocates nothing per entity in steady state.** A
   gesture is not the frame path, but it drives it every frame of a pan, and
   `paint_allocation_test.dart` stays green.
5. **`kIsWeb` appears exactly once** in the new code, inside
   `GesturePolicy.forPlatform()`, and **`dart:ui_web` appears exactly once**,
   in `gesture_policy_platform_web.dart`. Grep is the check for both.
6. Geometric **decisions** use `Tolerance`; stored value comparisons are exact
   `==`. The clamp's two decisions compare a *derived* scale (`sqrt(|det|)`)
   against a bound and therefore use `Tolerance` (D4). Policy fields,
   `scale == 1.0` on a synthetic event, and the mutant assertions on event
   fields are stored values: exact.

---

## Testing

Every fixture starts from a **non-identity** camera, with the document
**off-origin**, and every zoom focus **off the viewport centre**. The roadmap
names M-01c as the mutant a centred fixture cannot kill; the same degeneracy
would hide most of the list below, so it is an invariant of the suite, not a
note on one test.

### Named mutants

The four from the roadmap, carried unchanged:

- **M-01a** — in the pan/zoom update handler, pan by `event.localPan` (the
  cumulative value) where `event.localPanDelta` is meant. A three-update
  desktop scroll test goes red: the camera moves by the running sum's sum,
  not the sum.
- **M-01b** — replace `factor / _gestureZoom` with `factor`. The pinch test —
  which ramps the cumulative scale 1.2 → 1.5 → 2.0 and expects 2.0 — goes red
  at 3.6. *(A constant-scale fixture cannot kill this one: the widget skips
  an update whose scale equals the running value, so only the first of three
  identical updates ever reaches `zoomAt`. Found by the mutant surviving on
  its first shot.)*
- **M-01c** — zoom about the viewport centre instead of `event.localPosition`.
  The wheel test goes red. Requires an off-centre focus.
- **M-01d** — drop `onPointerPanZoomUpdate` entirely, keeping
  `onPointerSignal`. Every desktop trackpad test goes red. *(This is the
  `fc05076` defect made into a mutant: a suite built only on
  `PointerScrollEvent` would stay green here while the macOS trackpad is
  dead.)*

New, and all of them exist because of the two findings above:

- **M-01e** — in the widget, read `GesturePolicy.wheelZooms` where
  `widget.policy` is meant. The Firefox wheel-pans test goes red. *This is the
  mutant that proves the policy seam is load-bearing rather than decorative;
  if it survives, D2 bought nothing.* (Revision 1 mutated `forPlatform()`
  instead; under a VM `flutter test` that mutant is equivalent, because
  `kIsWeb` is compile-time `false` and the suite never calls it. Declared
  equivalent, argument in D2.)
- **M-01f** — ignore `HardwareKeyboard` ctrl/meta on a web `PointerScrollEvent`.
  The web modified-scroll zoom test goes red (it holds the key with
  `sendKeyDownEvent` first). *(This is the macOS-browser real-ctrl path and
  the cmd path; the Windows/Linux ctrl path is M-01g's event.)*
- **M-01g** — delete the `PointerScaleEvent` branch. The web pinch test goes
  red. *(The mirror of M-01d: this is the event a macOS trackpad never sends
  and a browser pinch always does.)*
- **M-01h** — *struck in revision 2* with the `honoursPanZoomEvents` flag
  (D2).
- **M-01i** — pan on `buttons != 0` instead of the middle button. The
  "left-button drag moves nothing" test goes red. *(This is the harness's
  actual line; the mutant is the harness's behaviour, which makes it a real
  regression risk rather than a hypothetical one.)*
- **M-01j** — clamp by rejecting an out-of-range gesture instead of landing on
  the bound. The test asserting the camera arrives at `maxScale` (within
  `Tolerance`) from a single large-factor zoom goes red.
- **M-01k** — swap `minScale` and `maxScale` in the clamp. Both bound tests go
  red.
- **M-01l** — apply the clamp to the factor rather than to the resulting
  scale. A zoom from a non-identity camera that should land on the bound lands
  somewhere else; the bound test goes red. *(A fixture starting at scale 1.0
  cannot tell these two apart — the anti-vacuity clause above is what gives
  this mutant somewhere to die.)*
- **M-01m** — negate the web scroll-pan delta (`+scrollDelta` for
  `-scrollDelta`). The absolute-direction web pan test goes red. *(The
  cross-policy test alone cannot see this if the desktop arm is flipped too;
  this is why direction is asserted per arm.)*
- **M-01n** — apply the desktop `factor / _gestureZoom` division to
  `PointerScaleEvent.scale`. A test sending three consecutive scale events of
  1.2 expects 1.728× and goes red.
- **M-01o** — remove the at-bound early return in the clamp. The
  listener-count test at each bound goes red.
- **M-01p** — drop the `kind == trackpad` test in the scroll-signal rule
  (treat every scroll signal as mouse-kind). Under `wheelZooms`, the
  trackpad-kind scroll pans test goes red. *(This is option (c)'s own
  load-bearing line: without it the Chromium/WebKit trackpad zooms, which is
  option (b).)*
- **M-01q** — make `GesturePolicy.forBrowser` return `wheelZooms` for
  `firefox: true`. The pure `forBrowser` test goes red. *(The half of
  `forPlatform()` the VM can reach.)*
- **M-01r** — delete the `dy == 0` guard on the zoom arm. The
  horizontal-notch test goes red.

### Cross-policy consistency, and what it cannot see

Under the stated sign rules a desktop `localPanDelta` of `d` (a
`PointerPanZoomUpdate`) and a browser `scrollDelta` of `-d` (a trackpad-kind
`PointerScrollEvent` under `wheelZooms`, and a mouse-kind one under
`wheelPans`) mean the same thing, so a test drives all three from the same
non-identity camera and asserts the cameras end equal. It catches the arms
disagreeing. **It cannot catch both arms being wrong the same way** — feeding matched numbers to both proves only that
`panBy` is linear — which is why each arm also has an absolute-direction
assertion (M-01m), and why this is not called a differential: the two arms are
not a reference and an implementation, they are two implementations.

---

## Exit gate

| # | Criterion |
|---|---|
| 1 | `apps/floor_planner` builds and runs on macOS and shows the startup plan, non-empty, off-origin. |
| 2 | `flutter build web` succeeds for the same app — the first web build of `jet_cad_2d_flutter` ever attempted (D6). |
| 3 | Desktop trackpad: two-finger scroll pans and does **not** zoom (`scale` exactly 1.0, motion in `pan`), from a non-identity transform. |
| 4 | Desktop trackpad: pinch zooms about the gesture anchor, cumulative handling correct. |
| 5 | Desktop mouse wheel: zooms 1.1× per notch about the pointer, not the viewport centre. |
| 6 | Scroll signals: under `wheelZooms` a `kind: trackpad` scroll pans by `-scrollDelta` and a `kind: mouse` scroll zooms about the pointer; under `wheelPans` both pan; direction asserted per arm; a `PointerScrollEvent` with `HardwareKeyboard` ctrl or meta held zooms about the pointer by `wheelZoomStep` under both; a `PointerScaleEvent` zooms by its own per-event `scale`, three in a row compounding; `forBrowser(firefox: true)` is `wheelPans` and `firefox: false` is `wheelZooms`. |
| 7 | Middle-button drag pans on both policies; left-button drag moves nothing on either. |
| 8 | The camera comes to rest on `minScale` and on `maxScale` within `Tolerance` and does not move past, from a single oversized zoom in each direction; a second oversized zoom at each bound notifies no listener. |
| 9 | Every mutant M-01a … M-01q (M-01h struck) fires and dies, or is declared equivalent **with the argument written down**. |
| 10 | The harness's suite passes at its recorded branch-point count, with no file under `apps/dev_harness_2d` edited. |
| 11 | All **eleven** gate commands exit 0 (`CI=true` prefixed), listed below, and no `analysis_options.yaml` is in the diff. |
| 12 | **A human looks at the running window** — macOS: a trackpad pan does not drift or stick, a pinch stays under the fingers, the wheel zooms under the cursor, the bounds come to rest without a jump, and a scroll with a modifier held still pans. Browser, **in Chrome or Safari and again in Firefox**: the same four, plus: a two-finger scroll pans and a wheel notch zooms in Chrome/Safari while both pan in Firefox; ctrl+scroll does not zoom the page (the engine `preventDefault`s every wheel event a widget does not release, `pointer_binding.dart:875-877`, so this is a check that the app is full-page, not a thing the widget does); a middle-button drag does not start Chromium's autoscroll; a mouse-wheel notch with ctrl held is judged for coarseness (D3, ≈1.65×). |

**The eleven gate commands.** Revision 1 said "six" and left the new app
outside every gate.

```sh
cd packages/jet_cad_2d         && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd apps/dev_harness_2d         && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
cd apps/floor_planner          && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build macos --debug && flutter build web
```

Eleven counts the app's two builds as one command each: eleven exits, one line
per package or app. Criterion 10's harness count is read off the third line.

Criterion 12 is not a formality. This repository's own record is that the
`fc05076` trackpad defect, the device-pixel-ratio fold and the device
half-width all survived entire measurement campaigns and were caught by
looking at the picture. A gesture layer is the part of this program that can
only be judged that way.

---

## Open questions

**The review reopened one question — the web scroll rule (B1) — and the
human re-decided it the same day: option (c), see finding 2.** Struck.

All six of the roadmap file's open questions are answered above and are
**struck**: D1 (gesture widget shape), D4 (zoom limits and clamp behaviour),
D3 (wheel step, multiplicative per notch), D3 (middle-drag pan, and the left
button deliberately free), D5 (startup document), D7 (window size and
restoration). D6 additionally closes the `residentGpu` question the roadmap
left open for this brainstorm, and closes it without owing a number.

Two remain open, and neither blocks the plan:

- ~~STRUCK~~ — **The exact clamp constants.** `0.001` and `100` are chosen
  against a CAD range in the abstract. They are checked against the startup
  document's units during execution and the check is recorded (D4). checked;
  see the results note.
- **Windows and Linux.** Both are desktop embedders and take
  `GesturePolicy.wheelZooms`, so nothing in the design is specific to macOS. But
  neither is built or looked at in this sub-project, and a trackpad on
  Windows is not a trackpad on macOS. Deferred, explicitly.

## What this changes outside 01

**Plan G (web) moves onto the render line's critical path.** `STATUS.md`'s
"Resume here" used to record the coupling as conditional — *"Plan G matters
only if the product targets web"* — and since 2026-09-21 records that the
product targets web and that Plan G is on the critical path
(`STATUS.md:890-897`, same-day edit). Plan G is the seventh of the
GPU-resident spec's seven plans, it is unwritten, and its web arm has never
been run. It does not block 01, because D6 puts the product on the `vertices`
sink, which is the default on web already. It does block ever shipping
`residentGpu` anywhere.
