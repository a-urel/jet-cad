# Floor planner app skeleton (sub-project 01) — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A real product application, `apps/floor_planner`, that opens a
resizable window on macOS and a page in a browser, shows a hand-written
floor plan on a `DraftCanvas`, and pans and zooms correctly with a trackpad
and a mouse — through a reusable `CameraGestureDetector` in
`jet_cad_2d_flutter` whose platform difference is an injected policy value,
with every rule under a named mutant.

**Architecture:** `CameraController` grows constructor bounds and a clamp
that lands on the bound under `Tolerance` and never notifies at rest.
`GesturePolicy` is a value with one behavioural field (`mouseWheel`), two
constants (`wheelZooms`, `wheelPans`), a pure `forBrowser` and the one
`kIsWeb` line in `forPlatform`, with browser detection behind a conditional
import of `dart:ui_web`. `CameraGestureDetector` is a `StatefulWidget` over a
`Listener` that pans by `localPanDelta`, zooms by the cumulative `scale`
ratio about the gesture anchor, routes scroll signals modifier → `kind` →
policy, applies `PointerScaleEvent.scale` raw, and pans on the middle button
only. `DraftCanvas` and the harness are untouched.

**Tech Stack:** Dart, Flutter **3.47.2** (the installed SDK; see the spec's
evidence header), `flutter_test`, `vector_math`, `jet_cad_2d`,
`jet_cad_2d_flutter`. No new dependency in either package.

**Spec:** [docs/superpowers/specs/2026-09-21-floor-planner-app-skeleton-design.md](../specs/2026-09-21-floor-planner-app-skeleton-design.md),
**revision 2**. Read it whole before Task 1 — the decisions D1–D8, the
gesture table in D3, the invariants, the mutant list and the exit gate. This
plan argues from it and departs from it in exactly one place, Ruling 01-1
below. The review that produced revision 2 is
[docs/superpowers/notes/2026-09-21-app-skeleton-spec-review-r1.md](../notes/2026-09-21-app-skeleton-spec-review-r1.md);
read its B1 and B2 before Tasks 2 and 4.

**Roadmap input:** [roadmap/01-app-skeleton.md](../../../roadmap/01-app-skeleton.md).
Two of its line pointers are stale (spec, finding 1); do not chase them.

**Branch:** `plan-01/app-skeleton`, cut from `main` at `c1d617d` or later,
in its own worktree (`superpowers:using-git-worktrees`). The ledger lives at
`.superpowers/sdd/2026-09-21-floor-planner-app-skeleton/` while the plan is
in flight and is archived to `docs/superpowers/ledgers/` on merge.

---

## Rulings made here rather than left to an implementer

- **Ruling 01-1 — the app's `analysis_options.yaml` is committed once, at
  scaffold, and never again.** The spec's architecture block says
  "generated and NOT committed". The harness's own file is tracked
  (`git ls-files apps/dev_harness_2d/analysis_options.yaml` prints it), and
  what `CLAUDE.md`'s "never commit `analysis_options.yaml`" has always meant
  in this repo is *never commit the rewrite `flutter pub get` makes to a
  tracked one*. A file that is never tracked would leave `flutter analyze` on
  the app running with no lint set and `git status` never clean. Task 6
  commits the generated file; every later task checks `git status` and
  restores it with `git checkout --` if `pub get` touched it. Task 10 amends
  the spec's one line to say so.
- **Ruling 01-2 — the first fit happens at the real viewport, once.** The
  spec says the app "shows the startup plan"; it does not say who fits the
  camera. `PlannerShell` constructs the camera fitted to a nominal 1440×900,
  and `PlannerView` re-fits it once, on its first layout, to the size it
  actually got. A `bool _fitted` guards it. Nothing else in 01 zooms to fit.
- **Ruling 01-3 — the bound decisions use `Tolerance.standard`.** The spec
  says `Tolerance`; it does not say which. `Tolerance.standard` (linear
  `1e-9`) is absolute, and a scale between `0.001` and `100` sits where
  `1e-9` is many ulps wide and far below anything a gesture produces. Not a
  constructor parameter (YAGNI); a `static const` in `camera_controller.dart`.
- **Ruling 01-4 — a `PointerPanZoomUpdate` whose `scale` equals the running
  value does not call `zoomAt`.** A two-finger scroll reports `scale == 1.0`
  on every update; calling `zoomAt(anchor, 1.0)` would build a new transform
  and notify for nothing. The check is exact `==` on a stored event field
  (spec invariant 6).

## Global Constraints

Copied from `CLAUDE.md` and the spec; this plan's additions marked.

- **The frame path allocates nothing per entity in steady state, and O(1)
  per flush.** `paint_allocation_test.dart` stays green. **This plan adds:**
  the gesture handlers allocate at most one `Offset` per event and nothing
  per entity; they never touch the document.
- **Draw order is ascending handle value.** The startup document is built
  by `AddEntityCommand`s in source order; nothing here sorts or reorders.
- **Geometric decisions use `Tolerance`; stored value comparisons are exact
  `==`.** The clamp's two decisions (past a bound; already at a bound) use
  `Tolerance.standard`. `scale == 1.0`, `scale != _gestureZoom`, policy
  fields, `event.kind == PointerDeviceKind.trackpad`, `buttons & panButtons`
  are stored values: exact.
- **Never commit a rewrite of `analysis_options.yaml`** (Ruling 01-1).
  `git status --short` before every commit; `git checkout --` any
  `analysis_options.yaml` that `pub get` rewrote.
- **Never synthesize test output.** Run the command, paste what it printed,
  including the exit code.
- **Before firing a mutation, back the file up with `cp`, and restore from
  that copy.** Never `git checkout --` a file to revert a mutation.
- **Prefix every test command with `CI=true`** — otherwise Dart's analytics
  phone-home blocks the runner for minutes at roughly zero CPU.
- Code, comments and commit messages in English.
- **`apps/dev_harness_2d` is untouched** (spec invariant 1). Its test count
  is measured at the branch point in Task 1 and written into the ledger.
- **`packages/jet_cad_2d` is untouched.** `Tolerance`, `Aabb2`,
  `Transform2`, `AddEntityCommand`, `EntityRecord`, `GeometryPayload` are
  read, never edited.
- **`DraftCanvas` gains no parameter and no gesture handling** (spec
  invariant 2). `draft_canvas.dart` is not in this plan's diff.
- **`CameraController` with no bounds behaves byte-for-byte as today**
  (spec invariant 3): the harness's `pointer_zoom_test.dart` and
  `camera_controller_test.dart`'s existing tests stay green unedited.
- **`kIsWeb` appears exactly once in new code** (`GesturePolicy.forPlatform`)
  **and `dart:ui_web` exactly once** (`gesture_policy_platform_web.dart`).
  `grep -rn "kIsWeb\|dart:ui_web" packages/jet_cad_2d_flutter/lib apps/floor_planner/lib`
  is the check, run in Task 9.
- **Every widget fixture starts from a non-identity camera over an
  off-origin document, and every zoom focus is off the viewport centre.**
  The fixture below (`fitOffOrigin`) is the only camera the gesture tests
  construct; a test that builds its own must say why.
- **Signs, as the spec states them:** desktop pan by `+localPanDelta`; a
  scroll signal pans by `-scrollDelta`; wheel zoom `scrollDelta.dy < 0` →
  `wheelZoomStep`, else `1 / wheelZoomStep`.
- **Every task ends green.** The eleven gate commands (spec, criterion 11):

  ```sh
  cd packages/jet_cad_2d         && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
  cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
  cd apps/dev_harness_2d         && CI=true flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
  cd apps/floor_planner          && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build macos --debug && flutter build web
  ```

  Tasks 1–5 run the `jet_cad_2d_flutter` line. Tasks 6–8 add the
  `floor_planner` line. Tasks 9 and 10 run all four lines.

## File structure

| file | responsibility |
|---|---|
| `packages/jet_cad_2d_flutter/lib/src/camera_controller.dart` | **modify** — `minScale`, `maxScale`, the clamp, the at-bound early return |
| `packages/jet_cad_2d_flutter/lib/src/gesture_policy.dart` | **create** — `ScrollAction`, `GesturePolicy`, `wheelZooms`, `wheelPans`, `forBrowser`, `forPlatform` |
| `packages/jet_cad_2d_flutter/lib/src/gesture_policy_platform_stub.dart` | **create** — `isFirefoxBrowser() => false` |
| `packages/jet_cad_2d_flutter/lib/src/gesture_policy_platform_web.dart` | **create** — `dart:ui_web` `browser.isFirefox` |
| `packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart` | **create** — the widget |
| `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` | **modify** — two exports |
| `packages/jet_cad_2d_flutter/test/camera_controller_test.dart` | **modify** — the bounds group |
| `packages/jet_cad_2d_flutter/test/gesture_policy_test.dart` | **create** |
| `packages/jet_cad_2d_flutter/test/support/gesture_fixture.dart` | **create** — `fitOffOrigin`, `pumpDetector`, `screenOf`, `worldUnder` |
| `packages/jet_cad_2d_flutter/test/camera_gesture_trackpad_test.dart` | **create** — Task 3's desktop pan/zoom tests |
| `packages/jet_cad_2d_flutter/test/camera_gesture_signal_test.dart` | **create** — Task 4's scroll, scale and modifier tests |
| `packages/jet_cad_2d_flutter/test/camera_gesture_button_test.dart` | **create** — Task 5's drag tests and the cross-policy test |
| `pubspec.yaml` | **modify** — `apps/floor_planner` in `workspace:` |
| `apps/floor_planner/` | **create** — `flutter create`, then the edits in Task 6 |
| `apps/floor_planner/lib/main.dart` | **create** — `FloorPlannerApp`, `PlannerShell`, the chrome slots |
| `apps/floor_planner/lib/startup_plan.dart` | **create** — `startupPlan(measurer)`, `kMinScale`, `kMaxScale` |
| `apps/floor_planner/lib/planner_view.dart` | **create** — `PlannerView`: `CameraGestureDetector(DraftCanvas(...))` |
| `apps/floor_planner/test/startup_plan_test.dart` | **create** |
| `apps/floor_planner/test/planner_shell_test.dart` | **create** |
| `apps/floor_planner/macos/Runner/Base.lproj/MainMenu.xib` | **modify** — `contentRect` 1440×900 |
| `.vscode/launch.json` | **modify** — one entry for the product app |
| `docs/superpowers/notes/plan-01-mutation-log.md` | **create** |
| `docs/superpowers/notes/2026-09-21-plan-01-results.md` | **create** |
| `docs/superpowers/specs/2026-09-21-floor-planner-app-skeleton-design.md` | **modify** — D4's constants check recorded; Ruling 01-1's one line |
| `roadmap/00-README.md`, `roadmap/01-app-skeleton.md`, `STATUS.md` | **modify** — plan and execution recorded |

Paths under `lib/` and `test/` in Tasks 1–5 are relative to
`packages/jet_cad_2d_flutter/`; in Tasks 7–8 to `apps/floor_planner/`.

---

### Task 1: The branch point, and `CameraController`'s bounds

**Files:**
- Modify: `lib/src/camera_controller.dart:37-64`
- Test: `test/camera_controller_test.dart` (append a group)

**Interfaces:**
- Consumes: `ValueNotifier`, `ViewportTransform.scale`, `Transform2`,
  `Tolerance.standard` from `jet_cad_2d`.
- Produces: `CameraController(super.initial, {double minScale = 0.0, double
  maxScale = double.infinity})`, fields `minScale`, `maxScale`; `zoomAt`
  lands on a bound within `Tolerance.standard` and returns without
  assigning when already at the bound it is pushed against. Tasks 3–5 and 8
  rely on `panBy(Offset)` and `zoomAt(Offset, double)` keeping their
  signatures.

- [ ] **Step 1: Record the branch point**

```sh
git worktree add ../jet-cad-plan-01 -b plan-01/app-skeleton main
cd ../jet-cad-plan-01/apps/dev_harness_2d && CI=true flutter test --concurrency=1 2>&1 | tail -3
```

Write the printed `+N` count into
`.superpowers/sdd/2026-09-21-floor-planner-app-skeleton/progress.md` as
"harness at branch point: N tests" with the commit hash. Spec criterion 10
is read against this number and no other. (STATUS says 82; the roadmap says
72; neither is assumed.)

- [ ] **Step 2: Write the failing bounds tests**

Append inside `main()` of `test/camera_controller_test.dart`, after the
existing `CameraController` group:

```dart
  group('CameraController bounds', () {
    // Off-origin world, non-identity fit: 100 x 50 into 800 x 600 gives a
    // scale of 0.95 * min(8, 12) = 7.6. A fixture at scale 1.0 could not
    // tell "clamp the factor" from "clamp the result" (spec, M-01l).
    CameraController bounded({double minScale = 0.5, double maxScale = 12.0}) =>
        CameraController(
          ViewportTransform.fit(
              Aabb2(Vector2(1000, 2000), Vector2(1100, 2050)),
              const Size(800, 600)),
          minScale: minScale,
          maxScale: maxScale,
        );
    const focus = Offset(130, 470);
    const tol = Tolerance.standard;

    test('defaults are unbounded, so an unbounded caller is unchanged', () {
      final camera = CameraController(ViewportTransform.fit(
          Aabb2(Vector2(0, 0), Vector2(100, 100)), const Size(800, 600)));
      expect(camera.minScale, 0.0);
      expect(camera.maxScale, double.infinity);
      final before = camera.value.scale;
      camera.zoomAt(focus, 1e6);
      expect(camera.value.scale, closeTo(before * 1e6, before * 1e6 * 1e-12));
    });

    test('an oversized zoom in lands on maxScale, not past it', () {
      final camera = bounded();
      expect(camera.value.scale, closeTo(7.6, 1e-9), reason: 'fixture');
      final under = camera.value.screenToWorld(Vector2(focus.dx, focus.dy));
      camera.zoomAt(focus, 10.0);
      expect(tol.eq(camera.value.scale, 12.0), isTrue,
          reason: 'landed on the bound: ${camera.value.scale}');
      final after = camera.value.screenToWorld(Vector2(focus.dx, focus.dy));
      expect(after.x, closeTo(under.x, 1e-9));
      expect(after.y, closeTo(under.y, 1e-9),
          reason: 'the clamp still zooms about the focus');
    });

    test('an oversized zoom out lands on minScale', () {
      final camera = bounded();
      camera.zoomAt(focus, 0.01);
      expect(tol.eq(camera.value.scale, 0.5), isTrue,
          reason: 'landed on the bound: ${camera.value.scale}');
    });

    test('a zoom that stays inside the bounds is not clamped', () {
      final camera = bounded();
      camera.zoomAt(focus, 1.5);
      expect(camera.value.scale, closeTo(7.6 * 1.5, 1e-9));
    });

    test('at a bound, pushing further does not notify', () {
      final camera = bounded();
      camera.zoomAt(focus, 10.0);
      var notifications = 0;
      camera.addListener(() => notifications++);
      camera.zoomAt(focus, 10.0);
      camera.zoomAt(focus, 1.0001);
      expect(notifications, 0, reason: 'at rest on maxScale');

      camera.zoomAt(focus, 0.001);
      expect(notifications, 1, reason: 'zooming back out is a real change');
      notifications = 0;
      camera.zoomAt(focus, 0.5);
      expect(notifications, 0, reason: 'at rest on minScale');
    });

    test('zoomAt still ignores a singular factor with bounds set', () {
      final camera = bounded();
      final before = camera.value.worldToScreenMatrix;
      for (final f in [0.0, -1.0, double.nan, double.infinity]) {
        camera.zoomAt(focus, f);
      }
      expect(camera.value.worldToScreenMatrix, same(before));
    });
  });
```

`Tolerance`, `Aabb2` and `Vector2` are already imported by this file.

- [ ] **Step 3: Run to verify it fails**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_controller_test.dart`
Expected: compile error — `minScale` is not a named parameter of
`CameraController`.

- [ ] **Step 4: Implement the bounds**

Replace the `CameraController` class in `lib/src/camera_controller.dart`
(from `/// The camera.` to the end of the file) with:

```dart
/// The camera. A `ValueNotifier` so a change repaints inside a
/// `RepaintBoundary` without rebuilding the widget tree.
///
/// [minScale] and [maxScale] bound [ViewportTransform.scale] — the geometric
/// mean of the axis scales, the number stroke widths divide by. They default
/// to unbounded so a caller that passes nothing (the measurement harness) is
/// unaffected. The clamp lives here, not in a gesture widget, because a
/// keyboard zoom, a zoom-to-fit and a zoom-to-selection all pass through
/// [zoomAt] and a clamp in a widget guards only one of them.
class CameraController extends ValueNotifier<ViewportTransform> {
  CameraController(
    super.initial, {
    this.minScale = 0.0,
    this.maxScale = double.infinity,
  })  : assert(minScale >= 0.0),
        assert(maxScale > minScale);

  final double minScale;
  final double maxScale;

  /// The bound decisions compare a *derived* scale — `sqrt(|det|)` after a
  /// three-matrix product — against a bound, so they are geometric decisions
  /// and use a tolerance, not `==` (spec invariant 6).
  static const Tolerance _tolerance = Tolerance.standard;

  void panBy(Offset screenDelta) {
    final m = value.worldToScreenMatrix;
    value = ViewportTransform(
      worldToScreenMatrix: Transform2(
          m.a, m.b, m.c, m.d, m.e + screenDelta.dx, m.f + screenDelta.dy),
    );
  }

  /// Scales about a screen point, keeping the world point under it fixed.
  ///
  /// A factor that is not finite and positive is ignored rather than applied:
  /// it would make the matrix singular, and `invert()` in the
  /// [ViewportTransform] constructor would throw there, taking the gesture and
  /// the frame with it. Holding the camera still is the only meaning a
  /// zero-scale zoom could have.
  ///
  /// A result past a bound **lands on the bound**: the factor is reduced so
  /// the resulting scale is the bound, and the zoom still happens about
  /// [screenFocus]. Rejecting the gesture instead would make the view stick
  /// and jump. A gesture that pushes against a bound the camera already rests
  /// on returns before assigning, so nothing is notified and nothing repaints.
  void zoomAt(Offset screenFocus, double factor) {
    if (!factor.isFinite || factor <= 0) return;
    final current = value.scale;
    var f = factor;
    if (f > 1.0) {
      if (_tolerance.compare(current, maxScale) >= 0) return;
      if (_tolerance.compare(current * f, maxScale) > 0) f = maxScale / current;
    } else if (f < 1.0) {
      if (_tolerance.compare(current, minScale) <= 0) return;
      if (_tolerance.compare(current * f, minScale) < 0) f = minScale / current;
    }
    final m = value.worldToScreenMatrix;
    // The argument of `multiply` is applied first, so this scales in screen
    // space *after* the camera. Reversed, it would scale in world space and
    // the point under the cursor would drift.
    final about = Transform2.translation(screenFocus.dx, screenFocus.dy)
        .multiply(Transform2.scale(f, f))
        .multiply(Transform2.translation(-screenFocus.dx, -screenFocus.dy));
    value = ViewportTransform(worldToScreenMatrix: about.multiply(m));
  }
}
```

With `minScale == 0.0`, `compare(current, 0.0) <= 0` is false for every
positive scale and `compare(current * f, 0.0) < 0` is false for every
positive product, so the unbounded path is the old code line for line.

- [ ] **Step 5: Run to verify it passes, and that nothing else moved**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_controller_test.dart
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && CI=true flutter test --concurrency=1 2>&1 | tail -3
```

Expected: all PASS; the harness prints the Step 1 count.

- [ ] **Step 6: Commit**

```sh
git status --short   # no analysis_options.yaml
git add packages/jet_cad_2d_flutter/lib/src/camera_controller.dart packages/jet_cad_2d_flutter/test/camera_controller_test.dart
git commit -m "feat(camera): minScale/maxScale bounds that land on the bound and rest silently"
```

---

### Task 2: `GesturePolicy`, with the browser question behind a conditional import

**Files:**
- Create: `lib/src/gesture_policy.dart`
- Create: `lib/src/gesture_policy_platform_stub.dart`
- Create: `lib/src/gesture_policy_platform_web.dart`
- Modify: `lib/jet_cad_2d_flutter.dart` (one export)
- Test: `test/gesture_policy_test.dart`

**Interfaces:**
- Consumes: `kIsWeb` (`package:flutter/foundation.dart`),
  `kMiddleMouseButton` (`package:flutter/gestures.dart`), `dart:ui_web`'s
  `browser.isFirefox` on web.
- Produces: `enum ScrollAction { pan, zoom }`; `GesturePolicy({required
  ScrollAction mouseWheel, double wheelZoomStep = 1.1, int panButtons =
  kMiddleMouseButton})`; `GesturePolicy.wheelZooms`, `GesturePolicy.wheelPans`;
  `static GesturePolicy forBrowser({required bool firefox})`; `factory
  GesturePolicy.forPlatform()`; top-level `bool isFirefoxBrowser()` (not
  exported from the barrel). Tasks 3–5 read `policy.mouseWheel`,
  `policy.wheelZoomStep`, `policy.panButtons`; Task 8 calls `forPlatform()`.

- [ ] **Step 1: Write the failing tests**

`test/gesture_policy_test.dart`:

```dart
import 'package:flutter/gestures.dart' show kMiddleMouseButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

void main() {
  test('wheelZooms: a mouse-kind scroll zooms, 1.1 per notch, middle drag',
      () {
    const p = GesturePolicy.wheelZooms;
    expect(p.mouseWheel, ScrollAction.zoom);
    expect(p.wheelZoomStep, 1.1);
    expect(p.panButtons, kMiddleMouseButton);
  });

  test('wheelPans: a mouse-kind scroll pans; the rest is the same', () {
    const p = GesturePolicy.wheelPans;
    expect(p.mouseWheel, ScrollAction.pan);
    expect(p.wheelZoomStep, GesturePolicy.wheelZooms.wheelZoomStep);
    expect(p.panButtons, GesturePolicy.wheelZooms.panButtons);
  });

  // The half of `forPlatform()` the VM can reach (spec, M-01q). The other
  // half -- `kIsWeb` and the `dart:ui_web` import -- is compile-time and is
  // covered by criterion 12's look in Chrome/Safari and in Firefox.
  test('forBrowser: Firefox gets wheelPans, every other engine wheelZooms',
      () {
    expect(GesturePolicy.forBrowser(firefox: true), same(GesturePolicy.wheelPans));
    expect(
        GesturePolicy.forBrowser(firefox: false), same(GesturePolicy.wheelZooms));
  });

  test('forPlatform on the VM is wheelZooms', () {
    expect(GesturePolicy.forPlatform(), same(GesturePolicy.wheelZooms));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/gesture_policy_test.dart`
Expected: compile error — `GesturePolicy` undefined.

- [ ] **Step 3: The two platform files**

`lib/src/gesture_policy_platform_stub.dart`:

```dart
/// Everywhere that is not a browser. See `gesture_policy.dart`.
bool isFirefoxBrowser() => false;
```

`lib/src/gesture_policy_platform_web.dart`:

```dart
import 'dart:ui_web' as ui_web;

/// **The only `dart:ui_web` import in this package.**
///
/// The engine's wheel heuristic gives up on Firefox by asking
/// `ui_web.browser.browserEngine == BrowserEngine.firefox`
/// (`engine/src/flutter/lib/web_ui/lib/src/engine/pointer_binding.dart:689`).
/// Asking the same object the same question is what keeps the policy and
/// the heuristic from disagreeing about which browser they are in; a
/// user-agent string parsed here could.
bool isFirefoxBrowser() => ui_web.browser.isFirefox;
```

- [ ] **Step 4: The policy**

`lib/src/gesture_policy.dart`:

```dart
import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:flutter/gestures.dart' show kMiddleMouseButton;

import 'gesture_policy_platform_stub.dart'
    if (dart.library.js_interop) 'gesture_policy_platform_web.dart';

/// What a bare scroll signal does to the camera.
enum ScrollAction { pan, zoom }

/// The per-platform half of camera gestures, as a value the widget is given
/// rather than a `kIsWeb` it reads.
///
/// `kIsWeb` is a compile-time constant: a widget that branched on it inline
/// could never run its web arm under a `flutter test` on macOS, and no
/// mutation planted there could go red. So the widget takes one of these,
/// tests pass [wheelZooms] and [wheelPans] explicitly, and [forPlatform] is
/// the one place the constant appears.
///
/// There is exactly one behavioural field. A `PointerPanZoom*` sequence
/// (desktop trackpads) pans and zooms under every policy; a
/// `PointerScaleEvent` (browser pinch, ctrl+wheel on Windows and Linux
/// browsers) zooms under every policy; a `PointerScrollEvent` of
/// `kind: trackpad` (Chromium and WebKit browsers, by the engine's
/// heuristic) pans under every policy. Only a `kind: mouse` scroll signal
/// with no modifier is a question, and [mouseWheel] answers it.
@immutable
class GesturePolicy {
  const GesturePolicy({
    required this.mouseWheel,
    this.wheelZoomStep = 1.1,
    this.panButtons = kMiddleMouseButton,
  });

  /// What a `PointerScrollEvent` of any kind other than trackpad, with no
  /// modifier held, means.
  final ScrollAction mouseWheel;

  /// Multiplicative step per wheel notch on the `PointerScrollEvent` zoom
  /// path. A `PointerScaleEvent` carries its own factor and ignores this.
  final double wheelZoomStep;

  /// The `PointerEvent.buttons` mask a drag must intersect to pan.
  final int panButtons;

  /// Desktop embedders and Chromium/WebKit browsers: the wheel zooms.
  ///
  /// On desktop the trackpad never arrives as a scroll signal (it is a
  /// `PointerPanZoom*` sequence), so a scroll signal is a wheel. In a
  /// Chromium or WebKit browser the engine tags a trackpad scroll
  /// `kind: trackpad` and the widget pans it before this field is consulted.
  static const wheelZooms = GesturePolicy(mouseWheel: ScrollAction.zoom);

  /// Firefox: every wheel event is `kind: mouse` because the engine's
  /// heuristic cannot tell a trackpad there, so the wheel pans -- zooming on
  /// it would take pan-by-scroll away from every Firefox trackpad user.
  static const wheelPans = GesturePolicy(mouseWheel: ScrollAction.pan);

  /// The browser question, answered. Pure, and tested on the VM.
  static GesturePolicy forBrowser({required bool firefox}) =>
      firefox ? wheelPans : wheelZooms;

  /// The policy for the platform this code is running on.
  ///
  /// **The only place `kIsWeb` appears in this package's gesture code.**
  /// `isFirefoxBrowser` comes from a conditional import: `dart:ui_web` on
  /// web, `false` elsewhere.
  factory GesturePolicy.forPlatform() =>
      kIsWeb ? forBrowser(firefox: isFirefoxBrowser()) : wheelZooms;
}
```

Add to `lib/jet_cad_2d_flutter.dart`, after `export 'src/flutter_text_measurer.dart';`:

```dart
export 'src/gesture_policy.dart';
```

The two platform files are not exported; `isFirefoxBrowser` is reachable
only through `forPlatform()`.

- [ ] **Step 5: Run to verify it passes**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/gesture_policy_test.dart
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

If `flutter analyze` reports `dart:ui_web` as unresolvable in
`gesture_policy_platform_web.dart`, that is a plan defect to ledger with the
exact message; the fix is to add `// ignore_for_file: ...` **only** if the
diagnostic names an ignorable code, and otherwise to stop and record it.
`packages/flutter` itself imports `dart:ui_web` behind the same conditional
shape and is analyzed, so the expectation is a clean run.

- [ ] **Step 6: Commit**

```sh
git status --short
git add packages/jet_cad_2d_flutter/lib/src/gesture_policy.dart packages/jet_cad_2d_flutter/lib/src/gesture_policy_platform_stub.dart packages/jet_cad_2d_flutter/lib/src/gesture_policy_platform_web.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/gesture_policy_test.dart
git commit -m "feat(gestures): GesturePolicy -- one field, two values, the browser question behind dart:ui_web"
```

---

### Task 3: `CameraGestureDetector` — the desktop trackpad path

**Files:**
- Create: `lib/src/camera_gesture_detector.dart`
- Modify: `lib/jet_cad_2d_flutter.dart` (one export)
- Create: `test/support/gesture_fixture.dart`
- Test: `test/camera_gesture_trackpad_test.dart`

**Interfaces:**
- Consumes: `CameraController.panBy`/`zoomAt` (Task 1), `GesturePolicy`
  (Task 2), `Listener`, `PointerPanZoomStartEvent`/`UpdateEvent`.
- Produces: `CameraGestureDetector({Key? key, required CameraController
  camera, required GesturePolicy policy, required Widget child})`. This task
  wires `onPointerPanZoomStart`/`Update` only; Task 4 adds `onPointerSignal`
  and Task 5 adds `onPointerMove`, each into the same `Listener`. The fixture
  file's `fitOffOrigin()`, `pumpDetector(tester, camera, policy)`,
  `screenOf(camera, world)`, `kWorldProbe` are used by Tasks 4 and 5.

- [ ] **Step 1: The fixture**

`test/support/gesture_fixture.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// The widget's size under test; the box is centred, so its top-left in
/// the 800 x 600 test surface is (200, 150).
const Size kDetectorSize = Size(400, 300);
const Offset kDetectorTopLeft = Offset(200, 150);

/// A world point inside the fitted view, off the view centre.
final Vector2 kWorldProbe = Vector2(1030, 2015);

/// A focus **off the viewport centre** (spec: M-01c cannot die at the
/// centre), in the detector's local coordinates.
const Offset kLocalFocus = Offset(70, 230);

/// Off-origin world (1000..1100 x 2000..2050) fitted into 400 x 300 with the
/// 5% margin: scale 0.95 * min(4, 6) = 3.8. Never the identity.
CameraController fitOffOrigin({double minScale = 0.0, double maxScale = double.infinity}) =>
    CameraController(
      ViewportTransform.fit(
          Aabb2(Vector2(1000, 2000), Vector2(1100, 2050)), kDetectorSize),
      minScale: minScale,
      maxScale: maxScale,
    );

/// Pumps a [CameraGestureDetector] over an inert child. The child is not a
/// `DraftCanvas`: these tests are about where the camera goes, and a canvas
/// would only add a document to keep paintable.
Future<void> pumpDetector(
    WidgetTester tester, CameraController camera, GesturePolicy policy) async {
  await tester.pumpWidget(Center(
    child: SizedBox(
      width: kDetectorSize.width,
      height: kDetectorSize.height,
      child: CameraGestureDetector(
        camera: camera,
        policy: policy,
        child: const ColoredBox(color: Color(0xFFFFFFFF)),
      ),
    ),
  ));
}

/// Where [world] is on the detector's surface, as an [Offset].
Offset screenOf(CameraController camera, Vector2 world) {
  final p = camera.value.worldToScreen(world);
  return Offset(p.x, p.y);
}

/// [kLocalFocus] in the test surface's global coordinates.
Offset globalFocus() => kDetectorTopLeft + kLocalFocus;
```

- [ ] **Step 2: Write the failing trackpad tests**

`test/camera_gesture_trackpad_test.dart`:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/gesture_fixture.dart';

void main() {
  for (final policy in [GesturePolicy.wheelZooms, GesturePolicy.wheelPans]) {
    group('PointerPanZoom under ${policy == GesturePolicy.wheelZooms ? 'wheelZooms' : 'wheelPans'}',
        () {
      // Two-finger scroll: `scale` stays exactly 1.0, motion is in `pan`.
      // `pan` is cumulative since the gesture began; the widget must use the
      // per-event `localPanDelta` (spec, M-01a), so three updates that
      // report 40, 80, 120 move the camera by 120, not 240.
      testWidgets('two-finger scroll pans by the delta and does not zoom',
          (tester) async {
        final camera = fitOffOrigin();
        await pumpDetector(tester, camera, policy);
        final before = screenOf(camera, kWorldProbe);
        final scaleBefore = camera.value.scale;

        final p = TestPointer(1, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(p.panZoomStart(globalFocus()));
        for (final dy in const [-40.0, -80.0, -120.0]) {
          await tester.sendEventToBinding(
              p.panZoomUpdate(globalFocus(), pan: Offset(0, dy)));
        }
        await tester.sendEventToBinding(p.panZoomEnd());
        await tester.pump();

        final after = screenOf(camera, kWorldProbe);
        expect(after.dx - before.dx, closeTo(0, 1e-9));
        expect(after.dy - before.dy, closeTo(-120, 1e-9),
            reason: 'content follows the fingers: +localPanDelta');
        expect(camera.value.scale, scaleBefore,
            reason: 'scale == 1.0 on every update: no zoom at all');
      });

      // Pinch: `scale` is cumulative and has no per-event delta, so each
      // update applies scale / running (spec, M-01b). Three updates
      // reporting 1.5 zoom by 1.5, not 1.5^3. The anchor is where the
      // gesture started, not the viewport centre.
      testWidgets('pinch zooms by the cumulative ratio about the anchor',
          (tester) async {
        final camera = fitOffOrigin();
        await pumpDetector(tester, camera, policy);
        final scaleBefore = camera.value.scale;
        final under = camera.value
            .screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));

        final p = TestPointer(1, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(p.panZoomStart(globalFocus()));
        for (var i = 0; i < 3; i++) {
          await tester.sendEventToBinding(
              p.panZoomUpdate(globalFocus(), scale: 1.5));
        }
        await tester.sendEventToBinding(p.panZoomEnd());
        await tester.pump();

        expect(camera.value.scale / scaleBefore, closeTo(1.5, 1e-9));
        final still = camera.value
            .screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));
        expect(still.x, closeTo(under.x, 1e-9));
        expect(still.y, closeTo(under.y, 1e-9),
            reason: 'the world point under the anchor did not move');
      });

      // macOS mixes them: a pinch that drifts reports both on one event.
      testWidgets('a drifting pinch pans by the delta and zooms by the ratio',
          (tester) async {
        final camera = fitOffOrigin();
        await pumpDetector(tester, camera, policy);
        final scaleBefore = camera.value.scale;

        final p = TestPointer(1, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(p.panZoomStart(globalFocus()));
        await tester.sendEventToBinding(p.panZoomUpdate(globalFocus(),
            pan: const Offset(25, -10), scale: 2.0));
        await tester.sendEventToBinding(p.panZoomEnd());
        await tester.pump();

        expect(camera.value.scale / scaleBefore, closeTo(2.0, 1e-9));
        // The pan is applied first, then the zoom about the (unmoved)
        // anchor. So the world point that sits under the anchor afterwards
        // is the one that was one pan-delta *behind* it before the gesture.
        final expected = fitOffOrigin()
            .value
            .screenToWorld(Vector2(kLocalFocus.dx - 25, kLocalFocus.dy + 10));
        final underAnchor = camera.value
            .screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));
        expect(underAnchor.x, closeTo(expected.x, 1e-9));
        expect(underAnchor.y, closeTo(expected.y, 1e-9));
      });

      testWidgets('a second gesture starts from a clean running scale',
          (tester) async {
        final camera = fitOffOrigin();
        await pumpDetector(tester, camera, policy);

        final first = TestPointer(1, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(first.panZoomStart(globalFocus()));
        await tester.sendEventToBinding(
            first.panZoomUpdate(globalFocus(), scale: 2.0));
        await tester.sendEventToBinding(first.panZoomEnd());
        await tester.pump();
        final between = camera.value.scale;

        final second = TestPointer(2, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(second.panZoomStart(globalFocus()));
        await tester.sendEventToBinding(
            second.panZoomUpdate(globalFocus(), scale: 2.0));
        await tester.sendEventToBinding(second.panZoomEnd());
        await tester.pump();

        expect(camera.value.scale / between, closeTo(2.0, 1e-9));
      });

      testWidgets('a two-finger scroll does not notify for its unchanged scale',
          (tester) async {
        final camera = fitOffOrigin();
        await pumpDetector(tester, camera, policy);
        var notifications = 0;
        camera.addListener(() => notifications++);

        final p = TestPointer(1, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(p.panZoomStart(globalFocus()));
        await tester.sendEventToBinding(
            p.panZoomUpdate(globalFocus(), pan: const Offset(0, -40)));
        await tester.sendEventToBinding(p.panZoomEnd());
        await tester.pump();

        expect(notifications, 1, reason: 'one pan, no zoomAt(anchor, 1.0)');
      });
    });
  }
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_gesture_trackpad_test.dart`
Expected: compile error — `CameraGestureDetector` undefined.

- [ ] **Step 4: The widget, trackpad path only**

`lib/src/camera_gesture_detector.dart`:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'camera_controller.dart';
import 'gesture_policy.dart';

/// Pans and zooms a [CameraController] from pointer input, wrapping the
/// view it drives.
///
/// A `Listener`, not a `GestureDetector`: the events this needs
/// (`onPointerSignal`, `onPointerPanZoomStart/Update`) are `Listener`'s, and
/// the arena a `GestureDetector` joins would have to be fought for nothing.
/// It is a separate widget rather than a `DraftCanvas` feature so a host that
/// drives the camera itself -- the measurement harness -- simply does not
/// use it.
///
/// Which input does what is the spec's D3 table. The desktop trackpad arrives
/// as a `PointerPanZoom*` sequence whose `pan` and `scale` are **cumulative
/// since the gesture began**; `localPanDelta` is the engine's own per-event
/// pan, and `scale` is divided by the running value so three updates of a
/// steady pinch to 1.5 zoom by 1.5, not 1.5^3. The anchor is held where the
/// gesture began, not under the drifting pointer.
class CameraGestureDetector extends StatefulWidget {
  const CameraGestureDetector({
    super.key,
    required this.camera,
    required this.policy,
    required this.child,
  });

  final CameraController camera;
  final GesturePolicy policy;
  final Widget child;

  @override
  State<CameraGestureDetector> createState() => _CameraGestureDetectorState();
}

class _CameraGestureDetectorState extends State<CameraGestureDetector> {
  /// The cumulative `scale` already applied from the gesture in progress.
  ///
  /// Reset when a gesture starts rather than when one ends: a start event is
  /// guaranteed to precede every update, an end event is not guaranteed to
  /// arrive at all.
  double _gestureZoom = 1.0;

  /// Where the trackpad gesture began, in this widget's coordinates.
  Offset _gestureAnchor = Offset.zero;

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    _gestureZoom = 1.0;
    _gestureAnchor = event.localPosition;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final camera = widget.camera;
    final delta = event.localPanDelta;
    if (delta != Offset.zero) camera.panBy(delta);
    final scale = event.scale;
    // `zoomAt` ignores a non-positive or non-finite factor, but the running
    // value must not be poisoned by one either.
    if (!scale.isFinite || scale <= 0) return;
    // A two-finger scroll reports scale == 1.0 on every update; zooming by
    // 1.0 would build a transform and notify for nothing (Ruling 01-4).
    if (scale == _gestureZoom) return;
    camera.zoomAt(_gestureAnchor, scale / _gestureZoom);
    _gestureZoom = scale;
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerPanZoomStart: _onPanZoomStart,
        onPointerPanZoomUpdate: _onPanZoomUpdate,
        child: widget.child,
      );
}
```

Add to `lib/jet_cad_2d_flutter.dart`, before `export 'src/canvas_draw_sink.dart';`:

```dart
export 'src/camera_gesture_detector.dart';
```

- [ ] **Step 5: Run to verify it passes**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_gesture_trackpad_test.dart
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

Expected: PASS, both policies, ten tests.

- [ ] **Step 6: Commit**

```sh
git status --short
git add packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/support/gesture_fixture.dart packages/jet_cad_2d_flutter/test/camera_gesture_trackpad_test.dart
git commit -m "feat(gestures): CameraGestureDetector -- the desktop trackpad path, pan by delta, zoom by ratio"
```

---

### Task 4: Scroll signals — modifier, then `kind`, then policy; and `PointerScaleEvent`

**Files:**
- Modify: `lib/src/camera_gesture_detector.dart` (add `onPointerSignal`)
- Test: `test/camera_gesture_signal_test.dart`

**Interfaces:**
- Consumes: Task 3's widget and fixture; `HardwareKeyboard.instance`;
  `PointerScrollEvent`, `PointerScaleEvent`.
- Produces: the scroll-signal rule of spec D3, in order: modifier held →
  zoom by `wheelZoomStep`; `kind == trackpad` → pan by `-scrollDelta`; else
  `policy.mouseWheel`. `PointerScaleEvent` → `zoomAt(localPosition,
  event.scale)`, raw.

- [ ] **Step 1: Write the failing signal tests**

`test/camera_gesture_signal_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/gesture_fixture.dart';

/// One wheel notch, the way a mouse reports it: scroll down is +dy.
const Offset kNotchDown = Offset(0, 120);
const Offset kNotchUp = Offset(0, -120);

Future<void> sendScroll(WidgetTester tester, PointerDeviceKind kind,
    Offset delta) async {
  final p = TestPointer(1, kind);
  await tester.sendEventToBinding(p.hover(globalFocus()));
  await tester.sendEventToBinding(p.scroll(delta));
  await tester.pump();
}

Future<void> sendScale(WidgetTester tester, double scale) async {
  final p = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(p.hover(globalFocus()));
  await tester.sendEventToBinding(p.scale(scale));
  await tester.pump();
}

void main() {
  group('mouse-kind scroll, no modifier', () {
    // Spec M-01c: about the pointer, not the viewport centre. The focus is
    // off centre and the assertion is that the world point under it stays.
    testWidgets('wheelZooms: zooms 1.1 per notch up about the pointer',
        (tester) async {
      final camera = fitOffOrigin();
      await pumpDetector(tester, camera, GesturePolicy.wheelZooms);
      final scaleBefore = camera.value.scale;
      final under =
          camera.value.screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));

      await sendScroll(tester, PointerDeviceKind.mouse, kNotchUp);

      expect(camera.value.scale / scaleBefore, closeTo(1.1, 1e-9));
      final still =
          camera.value.screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));
      expect(still.x, closeTo(under.x, 1e-9));
      expect(still.y, closeTo(under.y, 1e-9));
    });

    testWidgets('wheelZooms: a notch down zooms out by 1/1.1', (tester) async {
      final camera = fitOffOrigin();
      await pumpDetector(tester, camera, GesturePolicy.wheelZooms);
      final scaleBefore = camera.value.scale;
      await sendScroll(tester, PointerDeviceKind.mouse, kNotchDown);
      expect(camera.value.scale / scaleBefore, closeTo(1 / 1.1, 1e-9));
    });

    // Spec M-01e: the widget honours the *injected* policy. Under
    // wheelPans a mouse-kind scroll pans by -scrollDelta -- scroll down,
    // content moves up (spec M-01m: absolute direction, not just agreement).
    testWidgets('wheelPans: pans by -scrollDelta and does not zoom',
        (tester) async {
      final camera = fitOffOrigin();
      await pumpDetector(tester, camera, GesturePolicy.wheelPans);
      final before = screenOf(camera, kWorldProbe);
      final scaleBefore = camera.value.scale;

      await sendScroll(tester, PointerDeviceKind.mouse, kNotchDown);

      final after = screenOf(camera, kWorldProbe);
      expect(after.dy - before.dy, closeTo(-120, 1e-9),
          reason: 'scroll down: the content moves up');
      expect(after.dx - before.dx, closeTo(0, 1e-9));
      expect(camera.value.scale, scaleBefore);
    });
  });

  group('trackpad-kind scroll (a Chromium/WebKit browser trackpad)', () {
    // Spec M-01p: the `kind` test is not policy. Under wheelZooms a
    // trackpad-kind scroll still pans.
    for (final policy in [GesturePolicy.wheelZooms, GesturePolicy.wheelPans]) {
      testWidgets(
          'pans by -scrollDelta under ${policy == GesturePolicy.wheelZooms ? 'wheelZooms' : 'wheelPans'}',
          (tester) async {
        final camera = fitOffOrigin();
        await pumpDetector(tester, camera, policy);
        final before = screenOf(camera, kWorldProbe);
        final scaleBefore = camera.value.scale;

        await sendScroll(
            tester, PointerDeviceKind.trackpad, const Offset(30, 50));

        final after = screenOf(camera, kWorldProbe);
        expect(after.dx - before.dx, closeTo(-30, 1e-9));
        expect(after.dy - before.dy, closeTo(-50, 1e-9));
        expect(camera.value.scale, scaleBefore);
      });
    }
  });

  group('modifier held', () {
    // Spec M-01f. `PointerScrollEvent` carries no modifier; the widget reads
    // `HardwareKeyboard.instance`, and the test holds the key down first.
    for (final key in [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.metaLeft,
    ]) {
      for (final policy in [
        GesturePolicy.wheelZooms,
        GesturePolicy.wheelPans,
      ]) {
        testWidgets(
            '${key.keyLabel} + mouse scroll zooms about the pointer under '
            '${policy == GesturePolicy.wheelZooms ? 'wheelZooms' : 'wheelPans'}',
            (tester) async {
          final camera = fitOffOrigin();
          await pumpDetector(tester, camera, policy);
          final scaleBefore = camera.value.scale;
          final under = camera.value
              .screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));

          await tester.sendKeyDownEvent(key);
          await sendScroll(tester, PointerDeviceKind.mouse, kNotchUp);
          await tester.sendKeyUpEvent(key);

          // Under wheelPans this is the arm that kills M-01f: with the
          // modifier ignored the scroll pans and the scale stays 1.0.
          expect(camera.value.scale / scaleBefore, closeTo(1.1, 1e-9));
          final still = camera.value
              .screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));
          expect(still.x, closeTo(under.x, 1e-9));
          expect(still.y, closeTo(under.y, 1e-9));
        });
      }
    }
  });

  group('PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux)', () {
    // Spec M-01g and M-01n: the branch exists, and the factor is applied
    // raw -- it is per-event, so three of 1.2 compound to 1.728.
    for (final policy in [GesturePolicy.wheelZooms, GesturePolicy.wheelPans]) {
      testWidgets(
          'zooms by the event scale about the pointer, compounding, under '
          '${policy == GesturePolicy.wheelZooms ? 'wheelZooms' : 'wheelPans'}',
          (tester) async {
        final camera = fitOffOrigin();
        await pumpDetector(tester, camera, policy);
        final scaleBefore = camera.value.scale;
        final under = camera.value
            .screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));

        for (var i = 0; i < 3; i++) {
          await sendScale(tester, 1.2);
        }

        expect(camera.value.scale / scaleBefore,
            closeTo(math.pow(1.2, 3).toDouble(), 1e-9));
        final still = camera.value
            .screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));
        expect(still.x, closeTo(under.x, 1e-9));
        expect(still.y, closeTo(under.y, 1e-9));
      });
    }

    testWidgets('a scale below 1 zooms out', (tester) async {
      final camera = fitOffOrigin();
      await pumpDetector(tester, camera, GesturePolicy.wheelZooms);
      final scaleBefore = camera.value.scale;
      await sendScale(tester, math.exp(-100 / 200));
      expect(camera.value.scale / scaleBefore, closeTo(math.exp(-0.5), 1e-9));
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_gesture_signal_test.dart`
Expected: FAIL — every scroll and scale test finds the camera unmoved
(`closeTo(1.1)` against `1.0`; `-120` against `0`).

- [ ] **Step 3: Add the signal handler**

In `lib/src/camera_gesture_detector.dart`, add `import 'package:flutter/services.dart' show HardwareKeyboard;`
and, in the state class, before `build`:

```dart
  /// The scroll-signal rule, in the spec's order: a modifier held zooms; a
  /// trackpad-kind scroll pans; otherwise the policy decides.
  ///
  /// `PointerScrollEvent` carries no modifier fields, so the keyboard state
  /// is read from [HardwareKeyboard]. On a macOS browser a real ctrl+wheel
  /// reaches here as a plain scroll signal (the engine reserves the DOM
  /// `ctrlKey` for a synthesised pinch when the physical key is up); on a
  /// Windows or Linux browser it arrives as a [PointerScaleEvent] instead.
  /// Cmd+wheel is a plain scroll signal everywhere.
  ///
  /// A [PointerScaleEvent]'s `scale` is per-event -- the engine computes
  /// `exp(-deltaY / 200)` from each DOM event on its own -- so it is applied
  /// raw and **not** divided by the running trackpad value.
  void _onSignal(PointerSignalEvent event) {
    final camera = widget.camera;
    if (event is PointerScaleEvent) {
      camera.zoomAt(event.localPosition, event.scale);
      return;
    }
    if (event is! PointerScrollEvent) return;
    final policy = widget.policy;
    final keyboard = HardwareKeyboard.instance;
    final action = keyboard.isControlPressed || keyboard.isMetaPressed
        ? ScrollAction.zoom
        : event.kind == PointerDeviceKind.trackpad
            ? ScrollAction.pan
            : policy.mouseWheel;
    switch (action) {
      case ScrollAction.zoom:
        // Scroll up is negative dy on every platform Flutter reports.
        camera.zoomAt(
            event.localPosition,
            event.scrollDelta.dy < 0
                ? policy.wheelZoomStep
                : 1 / policy.wheelZoomStep);
      case ScrollAction.pan:
        // `scrollDelta` is content-scroll: positive dy is "scroll down", the
        // content moves up, so the camera pans by the negation.
        camera.panBy(-event.scrollDelta);
    }
  }
```

and in `build`, add `onPointerSignal: _onSignal,` to the `Listener`.

- [ ] **Step 4: Run to verify it passes**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_gesture_signal_test.dart
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

If `sendKeyDownEvent` does not make `HardwareKeyboard.instance.isControlPressed`
true in this SDK, the diagnostic is the modifier test failing with the
camera panned, not zoomed; ledger it and switch the test to
`simulateKeyDownEvent` from `flutter_test`'s `test_keyboard` (same key
argument) — do not weaken the assertion.

- [ ] **Step 5: Commit**

```sh
git status --short
git add packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/test/camera_gesture_signal_test.dart
git commit -m "feat(gestures): scroll signals -- modifier, then kind, then policy; PointerScaleEvent raw"
```

---

### Task 5: Buttons, the cross-policy consistency test, and the allocation invariant

**Files:**
- Modify: `lib/src/camera_gesture_detector.dart` (add `onPointerMove`)
- Test: `test/camera_gesture_button_test.dart`

**Interfaces:**
- Consumes: Tasks 3–4; `policy.panButtons`; `PointerMoveEvent.buttons`,
  `.delta`.
- Produces: middle-button drag pans by `event.delta`; any other button does
  nothing (spec M-01i). The widget is complete after this task.

- [ ] **Step 1: Write the failing button tests**

`test/camera_gesture_button_test.dart`:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/gesture_fixture.dart';

Future<void> drag(WidgetTester tester, int buttons, Offset by) async {
  final g = await tester.createGesture(
      kind: PointerDeviceKind.mouse, buttons: buttons);
  await g.down(globalFocus());
  await g.moveBy(by);
  await g.up();
  await tester.pump();
}

void main() {
  for (final policy in [GesturePolicy.wheelZooms, GesturePolicy.wheelPans]) {
    final name = policy == GesturePolicy.wheelZooms ? 'wheelZooms' : 'wheelPans';

    testWidgets('middle-button drag pans by the pointer delta under $name',
        (tester) async {
      final camera = fitOffOrigin();
      await pumpDetector(tester, camera, policy);
      final before = screenOf(camera, kWorldProbe);
      final scaleBefore = camera.value.scale;

      await drag(tester, kMiddleMouseButton, const Offset(33, -21));

      final after = screenOf(camera, kWorldProbe);
      expect(after.dx - before.dx, closeTo(33, 1e-9));
      expect(after.dy - before.dy, closeTo(-21, 1e-9));
      expect(camera.value.scale, scaleBefore);
    });

    // Spec, D3: the left button belongs to sub-project 02 (selection, the
    // rubber band). The harness pans on any button (M-01i is that line).
    testWidgets('left-button drag moves nothing under $name', (tester) async {
      final camera = fitOffOrigin();
      await pumpDetector(tester, camera, policy);
      final before = camera.value.worldToScreenMatrix;

      await drag(tester, kPrimaryButton, const Offset(33, -21));

      expect(camera.value.worldToScreenMatrix, same(before));
    });

    testWidgets('right-button drag moves nothing under $name', (tester) async {
      final camera = fitOffOrigin();
      await pumpDetector(tester, camera, policy);
      final before = camera.value.worldToScreenMatrix;
      await drag(tester, kSecondaryMouseButton, const Offset(33, -21));
      expect(camera.value.worldToScreenMatrix, same(before));
    });
  }

  // Spec, "Cross-policy consistency": a desktop `localPanDelta` of d, a
  // trackpad-kind scroll of -d under wheelZooms and a mouse-kind scroll of
  // -d under wheelPans mean the same thing. This catches the arms
  // disagreeing; the absolute-direction assertions in the signal and
  // trackpad tests are what catch all three being wrong together.
  testWidgets('the three pan arms move the camera identically',
      (tester) async {
    const d = Offset(37, -29);

    final desktop = fitOffOrigin();
    await pumpDetector(tester, desktop, GesturePolicy.wheelZooms);
    final tp = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(tp.panZoomStart(globalFocus()));
    await tester.sendEventToBinding(tp.panZoomUpdate(globalFocus(), pan: d));
    await tester.sendEventToBinding(tp.panZoomEnd());
    await tester.pump();

    final chromium = fitOffOrigin();
    await pumpDetector(tester, chromium, GesturePolicy.wheelZooms);
    final cp = TestPointer(2, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(cp.hover(globalFocus()));
    await tester.sendEventToBinding(cp.scroll(-d));
    await tester.pump();

    final firefox = fitOffOrigin();
    await pumpDetector(tester, firefox, GesturePolicy.wheelPans);
    final fp = TestPointer(3, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(fp.hover(globalFocus()));
    await tester.sendEventToBinding(fp.scroll(-d));
    await tester.pump();

    for (final camera in [chromium, firefox]) {
      final a = camera.value.worldToScreenMatrix;
      final b = desktop.value.worldToScreenMatrix;
      expect(a.a, b.a);
      expect(a.d, b.d);
      expect(a.e, closeTo(b.e, 1e-9));
      expect(a.f, closeTo(b.f, 1e-9));
    }
    expect(desktop.value.worldToScreenMatrix.e,
        isNot(fitOffOrigin().value.worldToScreenMatrix.e),
        reason: 'and they all actually moved');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_gesture_button_test.dart`
Expected: the middle-button tests FAIL (camera unmoved); the others pass
vacuously — which is why the middle-button tests exist beside them.

- [ ] **Step 3: Add the move handler**

In the state class:

```dart
  /// A drag with a pan button held pans by the pointer's own delta. Any
  /// other button does nothing here: the left button belongs to selection
  /// (sub-project 02), and leaving it free now is cheaper than unpicking a
  /// learned behaviour later.
  void _onMove(PointerMoveEvent event) {
    if (event.buttons & widget.policy.panButtons != 0) {
      widget.camera.panBy(event.delta);
    }
  }
```

and `onPointerMove: _onMove,` in the `Listener`.

- [ ] **Step 4: Run everything, including the allocation invariant**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_gesture_button_test.dart
CI=true flutter test test/invariants/paint_allocation_test.dart
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

Expected: PASS. The allocation test does not exercise the widget (the
widget is not on the frame path), and it is run here to record that it
did not move.

- [ ] **Step 5: Commit**

```sh
git status --short
git add packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/test/camera_gesture_button_test.dart
git commit -m "feat(gestures): middle-button drag pans, other buttons do nothing; the three pan arms agree"
```

---

### Task 6: `apps/floor_planner` — the scaffold, the workspace, the window

**Files:**
- Create: `apps/floor_planner/` (via `flutter create`)
- Modify: `pubspec.yaml` (root; `workspace:`)
- Modify: `apps/floor_planner/pubspec.yaml`
- Modify: `apps/floor_planner/macos/Runner/Base.lproj/MainMenu.xib`
- Modify: `.vscode/launch.json`

**Interfaces:**
- Produces: a workspace member that builds for macOS and web with the
  generated counter app still in `lib/main.dart` (Task 8 replaces it).
  Tasks 7–8 depend on the pubspec's dependencies.

- [ ] **Step 1: Create**

```sh
cd apps && flutter create --org dev.jetcad --project-name floor_planner --platforms macos,web floor_planner
cd floor_planner && rm -f README.md test/widget_test.dart && ls
```

- [ ] **Step 2: The pubspec**

Replace `apps/floor_planner/pubspec.yaml` with:

```yaml
name: floor_planner
description: >-
  The floor planner product application. Hosts a DraftCanvas behind a
  CameraGestureDetector, with empty chrome slots that later sub-projects
  fill. Not an instrument: the measurement harness is apps/dev_harness_2d.
publish_to: none
version: 0.0.1
resolution: workspace

environment:
  sdk: ^3.5.0
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter
  jet_cad_2d:
    path: ../../packages/jet_cad_2d
  jet_cad_2d_flutter:
    path: ../../packages/jet_cad_2d_flutter
  vector_math: ^2.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

If `flutter create` pinned a different `flutter_lints` major, keep the
generated one. Add to the root `pubspec.yaml`'s `workspace:` list, after
`- apps/dev_harness_2d`:

```yaml
  - apps/floor_planner
```

Then `cd /path/to/worktree && flutter pub get`, and
`git status --short` — restore any rewritten `analysis_options.yaml` under
`packages/` or `apps/dev_harness_2d` with `git checkout --`. The app's own
generated `analysis_options.yaml` stays as generated (Ruling 01-1).

- [ ] **Step 3: The window (spec D7)**

In `apps/floor_planner/macos/Runner/Base.lproj/MainMenu.xib` there is one
line `<rect key="contentRect" x="335" y="390" width="800" height="600"/>`.
Change it to:

```xml
            <rect key="contentRect" x="335" y="390" width="1440" height="900"/>
```

`MainFlutterWindow.swift` is **not** edited; it reads this frame from the
nib. `isRestorable` is left at its default. Confirm with
`git diff --stat -- apps/floor_planner/macos` that the xib is the only
change under `macos/` besides generation.

- [ ] **Step 4: Build both targets as generated**

```sh
cd apps/floor_planner && flutter build macos --debug 2>&1 | tail -3 && flutter build web 2>&1 | tail -3
```

Expected: both `✓ Built`. **This is the first web build of
`jet_cad_2d_flutter` in this repository's history** (spec D6) — the counter
app does not yet import it, so the real test is Task 8's; if *this* build
fails, the failure is the scaffold's, not the package's.

- [ ] **Step 5: The launch entry**

In `.vscode/launch.json`, append to `configurations` (after the last
existing entry):

```json
        {
            // The product application, sub-project 01. Not an instrument:
            // nothing here is measured, and F5 should keep landing on the
            // harness entries above it.
            "name": "floor_planner: macOS",
            "cwd": "apps/floor_planner",
            "program": "lib/main.dart",
            "request": "launch",
            "type": "dart",
            "deviceId": "macos"
        }
```

- [ ] **Step 6: Commit**

```sh
git status --short
git add pubspec.yaml apps/floor_planner .vscode/launch.json
git commit -m "build(floor_planner): scaffold the product app as a workspace member, 1440x900 window"
```

The generated `apps/floor_planner/analysis_options.yaml` is in this commit
and in no later one (Ruling 01-1).

---

### Task 7: The startup document (spec D5), and the clamp constants checked against it (D4)

**Files:**
- Create: `apps/floor_planner/lib/startup_plan.dart`
- Test: `apps/floor_planner/test/startup_plan_test.dart`

**Interfaces:**
- Consumes: `DraftDocument.empty(measurer:)`, `AddEntityCommand`,
  `EntityRecord`, `GeometryPayload`, `EntityKind`, `ReservedHandles`,
  `kByLayer`, `TrueColor`, `ByLayerColor` from `jet_cad_2d`;
  `FlutterTextMeasurer` from `jet_cad_2d_flutter`.
- Produces: `DraftDocument startupPlan(FlutterTextMeasurer measurer)`;
  `const double kMinScale = 0.001;`, `const double kMaxScale = 100.0;`,
  `const double kPlanOriginX`, `kPlanOriginY`. Task 8 uses all four.

- [ ] **Step 1: Write the failing test**

`apps/floor_planner/test/startup_plan_test.dart`:

```dart
import 'dart:ui' show Size;

import 'package:floor_planner/startup_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

void main() {
  late FlutterTextMeasurer measurer;
  setUp(() {
    measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
  });

  test('is at the target scale: between 500 and 1,000 entities', () {
    final doc = startupPlan(measurer);
    expect(doc.entities.liveCount, inInclusiveRange(500, 1000));
  });

  // The degenerate fixture this repository names: a drawing centred on the
  // origin. The extents must not contain (0, 0) and must not be symmetric
  // about either axis.
  test('is off-origin and not axis-symmetric', () {
    final doc = startupPlan(measurer);
    final e = doc.extents;
    expect(e.minX > 0 || e.maxX < 0, isTrue, reason: 'x span excludes 0');
    expect(e.minY > 0 || e.maxY < 0, isTrue, reason: 'y span excludes 0');
    expect(e.minX, isNot(-e.maxX));
    expect(e.minY, isNot(-e.maxY));
    expect(e.maxX - e.minX, isNot(e.maxY - e.minY),
        reason: 'not square either');
  });

  test('the outer walls close: the extents are the outer rectangle', () {
    final doc = startupPlan(measurer);
    final e = doc.extents;
    expect(e.minX, kPlanOriginX);
    expect(e.minY, kPlanOriginY);
    expect(e.maxX, kPlanOriginX + kPlanWidth);
    expect(e.maxY, kPlanOriginY + kPlanHeight);
  });

  // Spec D4's owed check: the constants against the document's own units.
  // At 1440 x 900 the fit scale is 0.95 * min(1440 / 14000, 900 / 9000) --
  // 0.095 px/mm -- so kMinScale allows ~95x further out and kMaxScale
  // ~1000x further in. Both decades are needed by a CAD user; neither is
  // absurd. The numbers are printed so the results note can quote them.
  test('the clamp constants bracket the fitted scale by decades', () {
    final doc = startupPlan(measurer);
    final fit = ViewportTransform.fit(doc.extents, const Size(1440, 900));
    // ignore: avoid_print
    print('STARTUP fit scale ${fit.scale} px/mm; '
        'min ${kMinScale} (${fit.scale / kMinScale}x out), '
        'max ${kMaxScale} (${kMaxScale / fit.scale}x in)');
    expect(fit.scale / kMinScale, greaterThan(10));
    expect(kMaxScale / fit.scale, greaterThan(100));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart`
Expected: compile error — `startupPlan` undefined.

- [ ] **Step 3: The document**

`apps/floor_planner/lib/startup_plan.dart`:

```dart
// The document the app opens before sub-project 12 gives it a file.
//
// A hand-written flat, in millimetres: two bedrooms, a living room, a
// kitchen, a bathroom and a hall, with doors, windows, a few pieces of
// furniture and the floor finishes drawn in -- the finishes are what carry
// the count into the target scale (500-5,000 entities) while every line
// stays something a person can check by eye: do the walls close, does the
// door swing into the room, is the tile grid square.
//
// **Off-origin and not axis-symmetric, by construction.** A drawing centred
// on (0, 0) is the degenerate fixture this repository keeps rediscovering,
// and this is the fixture a human looks at every session.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// Zoom bounds for the product camera, in logical pixels per world unit
/// (millimetre). Spec D4; checked against this document in
/// `startup_plan_test.dart`.
const double kMinScale = 0.001;
const double kMaxScale = 100.0;

/// The flat's outer wall corner, and its outer size.
const double kPlanOriginX = 12000.0;
const double kPlanOriginY = 8000.0;
const double kPlanWidth = 14000.0;
const double kPlanHeight = 9000.0;

const double _wall = 250.0; // exterior wall thickness
const double _partition = 120.0; // interior wall thickness

const DraftColor _wallColor = TrueColor(0x202020);
const DraftColor _openingColor = TrueColor(0x2266CC);
const DraftColor _furnitureColor = TrueColor(0x8A6D3B);
const DraftColor _finishColor = TrueColor(0xBBBBBB);

/// Builds the startup flat over [measurer]. `DraftCanvas` refuses a document
/// whose measurer is not a `FlutterTextMeasurer`, so the caller supplies the
/// one the app owns.
DraftDocument startupPlan(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  final p = _Pen(doc);

  // --- Exterior walls: two rectangles, outer and inner face. ---
  const x0 = kPlanOriginX, y0 = kPlanOriginY;
  const x1 = kPlanOriginX + kPlanWidth, y1 = kPlanOriginY + kPlanHeight;
  p.rect(x0, y0, x1, y1, lineweight: 50, color: _wallColor);
  p.rect(x0 + _wall, y0 + _wall, x1 - _wall, y1 - _wall,
      lineweight: 50, color: _wallColor);

  // --- Interior partitions (double lines), room by room. ---
  // Vertical: hall/living split at x = 5000 from the origin, full height.
  p.doubleV(x0 + 5000, y0 + _wall, y1 - _wall);
  // Horizontal: bedrooms above y = 5000 on the left; kitchen/bath on the
  // right below y = 3500.
  p.doubleH(y0 + 5000, x0 + _wall, x0 + 5000);
  p.doubleH(y0 + 3500, x0 + 5000, x1 - _wall);
  // Bedroom split at x = 2600, from y = 5000 up.
  p.doubleV(x0 + 2600, y0 + 5000, y1 - _wall);
  // Kitchen/bath split at x = 9500, from the bottom to y = 3500.
  p.doubleV(x0 + 9500, y0 + _wall, y0 + 3500);

  // --- Doors: an opening (two jamb lines), a leaf, and a quarter-arc swing.
  p.door(x: x0 + 5000, y: y0 + 6000, width: 900, vertical: true, swingRight: false);
  p.door(x: x0 + 5000, y: y0 + 1500, width: 900, vertical: true, swingRight: true);
  p.door(x: x0 + 2600, y: y0 + 7800, width: 800, vertical: true, swingRight: true);
  p.door(x: x0 + 1200, y: y0 + 5000, width: 800, vertical: false, swingRight: false);
  p.door(x: x0 + 7000, y: y0 + 3500, width: 800, vertical: false, swingRight: true);
  p.door(x: x0 + 11500, y: y0 + 3500, width: 700, vertical: false, swingRight: true);
  // The front door, in the bottom exterior wall. Openings are placed on the
  // wall's centreline so nothing they draw crosses the outer face: the
  // extents stay the outer rectangle (`startup_plan_test.dart`).
  p.door(x: x0 + 6500, y: y0 + _wall / 2, width: 1000, vertical: false,
      swingRight: true, thickness: _wall);

  // --- Windows: three parallel lines across the exterior wall. ---
  for (final wx in const [1300.0, 3900.0, 7200.0, 10800.0]) {
    p.window(x: x0 + wx, y: y1 - _wall / 2, width: 1200, vertical: false);
  }
  p.window(x: x1 - _wall / 2, y: y0 + 1800, width: 1200, vertical: true);
  p.window(x: x1 - _wall / 2, y: y0 + 6200, width: 1800, vertical: true);
  p.window(x: x0 + _wall / 2, y: y0 + 2200, width: 1000, vertical: true);
  p.window(x: x0 + _wall / 2, y: y0 + 6600, width: 1400, vertical: true);

  // --- Furniture: rectangles, one L. ---
  p.rect(x0 + 400, y0 + 6600, x0 + 2200, y0 + 8600, lineweight: 25, color: _furnitureColor); // bed
  p.rect(x0 + 2900, y0 + 6800, x0 + 4500, y0 + 8600, lineweight: 25, color: _furnitureColor); // bed
  p.rect(x0 + 6000, y0 + 4200, x0 + 9000, y0 + 5100, lineweight: 25, color: _furnitureColor); // sofa
  p.rect(x0 + 6400, y0 + 5600, x0 + 8600, y0 + 6800, lineweight: 25, color: _furnitureColor); // table
  p.rect(x0 + 5400, y0 + 400, x0 + 6000, y0 + 3100, lineweight: 25, color: _furnitureColor); // counter
  p.rect(x0 + 5400, y0 + 400, x0 + 9100, y0 + 1000, lineweight: 25, color: _furnitureColor); // counter L
  p.rect(x0 + 12200, y0 + 400, x0 + 13500, y0 + 2000, lineweight: 25, color: _furnitureColor); // bath
  p.circle(x0 + 7600, y0 + 6200, 350, lineweight: 25, color: _furnitureColor); // lamp
  p.circle(x0 + 10300, y0 + 1200, 220, lineweight: 25, color: _furnitureColor); // basin

  // --- Floor finishes: what carries the count. ---
  // Kitchen tiles, 200 mm, both ways: x 5000+p..9500-p, y wall..3500-p.
  p.grid(x0 + 5000 + _partition, y0 + _wall, x0 + 9500 - _partition,
      y0 + 3500 - _partition,
      pitch: 200, both: true);
  // Bathroom mosaic, 150 mm, both ways.
  p.grid(x0 + 9500 + _partition, y0 + _wall, x1 - _wall, y0 + 3500 - _partition,
      pitch: 150, both: true);
  // Living room parquet: 150 mm strips running in x, with staggered joints
  // every 900 mm.
  p.parquet(x0 + 5000 + _partition, y0 + 3500 + _partition, x1 - _wall,
      y1 - _wall,
      strip: 150, plank: 900);

  return doc;
}

/// The one way entities enter this document: `AddEntityCommand`, in source
/// order, so draw order (ascending handle) is reading order.
class _Pen {
  _Pen(this.doc);
  final DraftDocument doc;

  void _add(EntityKind kind, List<double> coords, List<double> scalars,
      {required int lineweight, required DraftColor color}) {
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: doc.handleSeed.next(),
        owner: doc.rootHandle,
        kind: kind,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: color,
        lineweight: lineweight,
        transparency: kByLayer,
        flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars),
      ),
    ));
  }

  void line(double ax, double ay, double bx, double by,
          {int lineweight = 25, DraftColor color = _wallColor}) =>
      _add(EntityKind.line, [ax, ay, bx, by], const [],
          lineweight: lineweight, color: color);

  void rect(double ax, double ay, double bx, double by,
      {required int lineweight, required DraftColor color}) {
    line(ax, ay, bx, ay, lineweight: lineweight, color: color);
    line(bx, ay, bx, by, lineweight: lineweight, color: color);
    line(bx, by, ax, by, lineweight: lineweight, color: color);
    line(ax, by, ax, ay, lineweight: lineweight, color: color);
  }

  void circle(double cx, double cy, double r,
          {required int lineweight, required DraftColor color}) =>
      _add(EntityKind.circle, [cx, cy], [r],
          lineweight: lineweight, color: color);

  void arc(double cx, double cy, double r, double start, double sweep,
          {required int lineweight, required DraftColor color}) =>
      _add(EntityKind.arc, [cx, cy], [r, start, sweep],
          lineweight: lineweight, color: color);

  void doubleV(double x, double ya, double yb) {
    line(x - _partition / 2, ya, x - _partition / 2, yb, lineweight: 35);
    line(x + _partition / 2, ya, x + _partition / 2, yb, lineweight: 35);
  }

  void doubleH(double y, double xa, double xb) {
    line(xa, y - _partition / 2, xb, y - _partition / 2, lineweight: 35);
    line(xa, y + _partition / 2, xb, y + _partition / 2, lineweight: 35);
  }

  /// A door centred on a wall at ([x], [y]): two jambs across the wall, the
  /// leaf perpendicular to it, and a quarter-circle swing.
  void door({
    required double x,
    required double y,
    required double width,
    required bool vertical,
    required bool swingRight,
    double thickness = _partition,
  }) {
    final h = thickness / 2, w = width / 2;
    if (vertical) {
      line(x - h, y - w, x + h, y - w, lineweight: 18, color: _openingColor);
      line(x - h, y + w, x + h, y + w, lineweight: 18, color: _openingColor);
      // Hinge at the lower jamb; the leaf lies along +x or -x, and the
      // swing is the quarter turn from the leaf up to the wall.
      final dir = swingRight ? 1.0 : -1.0;
      line(x, y - w, x + dir * width, y - w, lineweight: 18, color: _openingColor);
      arc(x, y - w, width, swingRight ? 0.0 : math.pi / 2, math.pi / 2,
          lineweight: 18, color: _openingColor);
    } else {
      line(x - w, y - h, x - w, y + h, lineweight: 18, color: _openingColor);
      line(x + w, y - h, x + w, y + h, lineweight: 18, color: _openingColor);
      // Hinge at the left jamb; the leaf lies along +y or -y.
      final dir = swingRight ? 1.0 : -1.0;
      line(x - w, y, x - w, y + dir * width, lineweight: 18, color: _openingColor);
      arc(x - w, y, width, swingRight ? 0.0 : -math.pi / 2, math.pi / 2,
          lineweight: 18, color: _openingColor);
    }
  }

  /// A window centred on an exterior wall: three lines across the opening.
  void window({
    required double x,
    required double y,
    required double width,
    required bool vertical,
  }) {
    final w = width / 2;
    for (final t in const [-_wall / 2, 0.0, _wall / 2]) {
      if (vertical) {
        line(x + t, y - w, x + t, y + w, lineweight: 18, color: _openingColor);
      } else {
        line(x - w, y + t, x + w, y + t, lineweight: 18, color: _openingColor);
      }
    }
  }

  /// Hairline tile joints inside a rectangle.
  void grid(double ax, double ay, double bx, double by,
      {required double pitch, required bool both}) {
    for (var x = ax + pitch; x < bx; x += pitch) {
      line(x, ay, x, by, lineweight: 0, color: _finishColor);
    }
    if (!both) return;
    for (var y = ay + pitch; y < by; y += pitch) {
      line(ax, y, bx, y, lineweight: 0, color: _finishColor);
    }
  }

  /// Parquet: strips along x, plank joints staggered by half a plank on
  /// alternate rows.
  void parquet(double ax, double ay, double bx, double by,
      {required double strip, required double plank}) {
    var row = 0;
    for (var y = ay + strip; y < by; y += strip, row++) {
      line(ax, y, bx, y, lineweight: 0, color: _finishColor);
      final offset = row.isOdd ? plank / 2 : 0.0;
      for (var x = ax + offset + plank; x < bx; x += plank) {
        line(x, y - strip, x, y, lineweight: 0, color: _finishColor);
      }
    }
  }
}
```

The arc payload is `[radius, startAngle, sweepAngle]`, radians,
counter-clockwise for a positive sweep, y up (`primitives.dart:65-67`,
`extents.dart:55-61` bounds the true arc, not its circle). If a swing draws
on the wrong side in Task 10's look, flip `swingRight` at the call site,
not the convention.

- [ ] **Step 4: Run to verify it passes, and read the count**

Run: `cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart`
Expected: PASS, and the `STARTUP fit scale …` line printed. If `liveCount`
is under 500, halve the kitchen pitch (300 → 150) — a change to the
layout, recorded in the ledger with the new count. If over 1,000, double
the bathroom pitch.

- [ ] **Step 5: Commit**

```sh
git status --short   # apps/floor_planner/analysis_options.yaml must not be modified
git add apps/floor_planner/lib/startup_plan.dart apps/floor_planner/test/startup_plan_test.dart
git commit -m "feat(floor_planner): the hand-written startup flat, off-origin, with the clamp constants checked"
```

---

### Task 8: The app — shell, view, chrome slots, and the first web build of the package

**Files:**
- Create: `apps/floor_planner/lib/main.dart` (replace the generated one)
- Create: `apps/floor_planner/lib/planner_view.dart`
- Test: `apps/floor_planner/test/planner_shell_test.dart`

**Interfaces:**
- Consumes: `startupPlan`, `kMinScale`, `kMaxScale` (Task 7);
  `CameraGestureDetector`, `GesturePolicy.forPlatform()`, `DraftCanvas`,
  `CameraController`, `ViewportTransform.fit`, `SpatialIndex`,
  `FlutterTextMeasurer`.
- Produces: `FloorPlannerApp`, `PlannerShell`, `PlannerView({required
  document, required index, required camera, required policy})`.

- [ ] **Step 1: Write the failing shell test**

`apps/floor_planner/test/planner_shell_test.dart`:

```dart
import 'package:floor_planner/main.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

void main() {
  testWidgets('the shell shows a canvas over a non-empty, off-origin plan',
      (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();

    expect(find.byType(DraftCanvas), findsOneWidget);
    expect(find.byType(CameraGestureDetector), findsOneWidget);
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    expect(view.document.entities.liveCount, greaterThanOrEqualTo(500));
    expect(view.document.extents.minX, greaterThan(0));
    expect(view.camera.minScale, kMinScale);
    expect(view.camera.maxScale, kMaxScale);
  });

  // Ruling 01-2: fitted once to the size the view actually got, so the plan
  // is fully visible and the camera is not the nominal 1440 x 900 fit.
  testWidgets('the camera is fitted to the real viewport on first layout',
      (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final size = tester.getSize(find.byType(DraftCanvas));
    final expected = ViewportTransform.fit(view.document.extents, size);
    expect(view.camera.value.scale, closeTo(expected.scale, 1e-9));
    expect(view.camera.value.worldToScreenMatrix.e,
        closeTo(expected.worldToScreenMatrix.e, 1e-6));
  });

  testWidgets('the three chrome slots are laid out and empty', (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();
    for (final key in const [
      Key('chrome-top'),
      Key('chrome-left'),
      Key('chrome-right')
    ]) {
      expect(find.byKey(key), findsOneWidget);
      expect(tester.getSize(find.byKey(key)).width, greaterThan(0));
    }
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd apps/floor_planner && CI=true flutter test test/planner_shell_test.dart`
Expected: compile error — `FloorPlannerApp` undefined (the generated
`main.dart` has `MyApp`).

- [ ] **Step 3: The view**

`apps/floor_planner/lib/planner_view.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// The drawing area: a [CameraGestureDetector] over a [DraftCanvas].
///
/// Tiles off, `backend` unset (spec D6): a floor plan is 500-5,000
/// entities, and the resident backend cannot run on web, which this product
/// targets. Neither is a default a later sub-project may flip without a
/// measurement.
class PlannerView extends StatefulWidget {
  const PlannerView({
    super.key,
    required this.document,
    required this.index,
    required this.camera,
    required this.policy,
  });

  final DraftDocument document;
  final SpatialIndex index;
  final CameraController camera;
  final GesturePolicy policy;

  @override
  State<PlannerView> createState() => _PlannerViewState();
}

class _PlannerViewState extends State<PlannerView> {
  /// Ruling 01-2: the camera is fitted once, to the size the view really
  /// got, before the canvas under it has listened to anything.
  bool _fitted = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (!_fitted && constraints.biggest.width > 0 &&
              constraints.biggest.height > 0) {
            _fitted = true;
            widget.camera.value = ViewportTransform.fit(
                widget.document.extents, constraints.biggest);
          }
          return CameraGestureDetector(
            camera: widget.camera,
            policy: widget.policy,
            child: DraftCanvas(
              document: widget.document,
              index: widget.index,
              camera: widget.camera,
              tiles: false,
            ),
          );
        },
      );
}
```

- [ ] **Step 4: The app and the shell**

`apps/floor_planner/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'planner_view.dart';
import 'startup_plan.dart';

void main() => runApp(const FloorPlannerApp());

class FloorPlannerApp extends StatelessWidget {
  const FloorPlannerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Floor planner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF2266CC)),
        home: const PlannerShell(),
      );
}

/// Owns the document, the index and the camera for the window's lifetime,
/// and lays out the chrome slots -- a top bar, a left panel and a right
/// panel, sized and empty -- so sub-projects 04, 05 and 12 add to a layout
/// rather than invent one.
class PlannerShell extends StatefulWidget {
  const PlannerShell({super.key});

  @override
  State<PlannerShell> createState() => _PlannerShellState();
}

class _PlannerShellState extends State<PlannerShell> {
  final FlutterTextMeasurer _measurer = FlutterTextMeasurer();
  late final DraftDocument _document = startupPlan(_measurer);
  late final SpatialIndex _index = SpatialIndex(_document);
  // Fitted to the nominal window; PlannerView re-fits once at the real size.
  late final CameraController _camera = CameraController(
    ViewportTransform.fit(_document.extents, const Size(1440, 900)),
    minScale: kMinScale,
    maxScale: kMaxScale,
  );
  final GesturePolicy _policy = GesturePolicy.forPlatform();

  @override
  void dispose() {
    _camera.dispose();
    _index.dispose();
    _measurer.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          Container(
            key: const Key('chrome-top'),
            height: 44,
            color: scheme.surfaceContainer,
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  key: const Key('chrome-left'),
                  width: 240,
                  color: scheme.surfaceContainerLow,
                ),
                Expanded(
                  child: ColoredBox(
                    color: scheme.surface,
                    child: PlannerView(
                      document: _document,
                      index: _index,
                      camera: _camera,
                      policy: _policy,
                    ),
                  ),
                ),
                Container(
                  key: const Key('chrome-right'),
                  width: 280,
                  color: scheme.surfaceContainerLow,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run the app's line, including both builds**

```sh
cd apps/floor_planner && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
flutter build macos --debug 2>&1 | tail -3
flutter build web 2>&1 | tail -20
```

Expected: tests PASS, analyze clean, both builds `✓ Built`. **The web build
is spec criterion 2 and the first time `jet_cad_2d_flutter` has been
compiled for web.** If it fails inside the package (a `dart:ffi` or
`dart:io` reach that the `flutter_scene` shim does not cover, or
`gesture_policy_platform_web.dart`), that is a finding about the package:
paste the first error verbatim into the ledger, stop, and report it as the
task's result. Do not patch the package inside this task.

- [ ] **Step 6: Run it, once, and look**

`cd apps/floor_planner && flutter run -d macos` — the window opens at
1440×900, the flat is visible, nothing else is checked here (Task 10 is the
look). Quit.

- [ ] **Step 7: Commit**

```sh
git status --short
git add apps/floor_planner/lib apps/floor_planner/test
git commit -m "feat(floor_planner): the shell, the view, three empty chrome slots; builds for macOS and web"
```

---

### Task 9: Mutation testing, and the two greps

**Files:**
- Create: `docs/superpowers/notes/plan-01-mutation-log.md`

**Interfaces:**
- Consumes: every test file this plan created. No production change lands
  here; a survivor is a plan defect, fixed in its own commit before the log
  records the kill.

- [ ] **Step 1: The procedure, for every row**

```sh
cp <file> /tmp/mut.bak            # never `git checkout --` to restore
# apply the edit below, by hand
cd packages/jet_cad_2d_flutter && CI=true flutter test <witness file> 2>&1 | tail -40
cp /tmp/mut.bak <file>
git status --short                # clean before the next row
```

Paste the red run's last lines (the failing `expect` and its `reason`)
verbatim, with the exit code.

- [ ] **Step 2: The rows** (`cgd` = `lib/src/camera_gesture_detector.dart`,
  `cc` = `lib/src/camera_controller.dart`, `gp` = `lib/src/gesture_policy.dart`)

| id | spec mutant | file, edit | witness | expected red |
|---|---|---|---|---|
| M-01a | pan by cumulative `pan` | `cgd`: `event.localPanDelta` → `event.localPan` | `camera_gesture_trackpad_test.dart` | `-240` where `-120` |
| M-01b | drop the running division | `cgd`: `scale / _gestureZoom` → `scale` | trackpad test | `3.375` where `1.5` |
| M-01c | zoom about the centre | `cgd`, `_onSignal` zoom arm: `event.localPosition` → `const Offset(200, 150)` | `camera_gesture_signal_test.dart` | `still.x` off `under.x` |
| M-01d | no pan/zoom handler | `cgd`: delete `onPointerPanZoomUpdate: _onPanZoomUpdate,` | trackpad test | every trackpad test: camera unmoved |
| M-01e | ignore the injected policy | `cgd`: `policy.mouseWheel` → `GesturePolicy.wheelZooms.mouseWheel` | signal test (`wheelPans: pans`) | scale `1/1.1` where unchanged; `dy` `0` where `-120` |
| M-01f | ignore modifiers | `cgd`: delete `keyboard.isControlPressed \|\| keyboard.isMetaPressed ? ScrollAction.zoom :` | signal test (modifier group) | under `wheelPans`: `1.0` where `1.1` |
| M-01g | no `PointerScaleEvent` branch | `cgd`: delete the `if (event is PointerScaleEvent) {...}` block | signal test (scale group) | `1.0` where `1.728` |
| M-01i | pan on any button | `cgd`: `event.buttons & widget.policy.panButtons != 0` → `event.buttons != 0` | `camera_gesture_button_test.dart` | left-button: matrix not `same` |
| M-01j | reject instead of landing | `cc`: `f = maxScale / current` → `return` (both bounds) | `camera_controller_test.dart` | `7.6` where `12.0` |
| M-01k | swap the bounds | `cc`: exchange `maxScale` and `minScale` in the four comparisons | camera test | zoom-in returns at once: `7.6` |
| M-01l | clamp the factor | `cc`: replace the two `f = bound / current` with `f = f.clamp(minScale, maxScale)` | camera test | `76.0` where `12.0` |
| M-01m | flip the scroll-pan sign | `cgd`: `camera.panBy(-event.scrollDelta)` → `camera.panBy(event.scrollDelta)` | signal test (`wheelPans`, trackpad-kind) | `+120` where `-120` |
| M-01n | divide the scale event | `cgd`: `camera.zoomAt(event.localPosition, event.scale)` → `camera.zoomAt(event.localPosition, event.scale / _gestureZoom); _gestureZoom = event.scale;` | signal test (scale group) | `1.2` where `1.728` |
| M-01o | no at-bound early return | `cc`: delete both `if (_tolerance.compare(current, …) …) return;` lines | camera test (`does not notify`) | `notifications` `2` where `0` |
| M-01p | ignore `kind` | `cgd`: delete `event.kind == PointerDeviceKind.trackpad ? ScrollAction.pan :` | signal test (trackpad-kind, `wheelZooms`) | scale `1/1.1` where unchanged |
| M-01q | `forBrowser` ignores Firefox | `gp`: `firefox ? wheelPans : wheelZooms` → `wheelZooms` | `gesture_policy_test.dart` | `same(wheelPans)` fails |
| E-01e′ | *revision 1's M-01e*, **declared equivalent** | `gp`: `forPlatform` → `wheelZooms` unconditionally | whole `flutter test` | **stays green**; the log says why (spec D2: `kIsWeb` is compile-time `false` on the VM and the suite injects policies) |

M-01h is struck (spec). Fire E-01e′ too and record the green run: an
equivalent mutant is recorded, not skipped.

- [ ] **Step 3: The two greps (spec invariant 5)**

```sh
grep -rn "kIsWeb" packages/jet_cad_2d_flutter/lib apps/floor_planner/lib
grep -rn "dart:ui_web" packages/jet_cad_2d_flutter/lib apps/floor_planner/lib
```

Expected: exactly one line each — `gesture_policy.dart` and
`gesture_policy_platform_web.dart`. Paste both into the log.

- [ ] **Step 4: The log**

`docs/superpowers/notes/plan-01-mutation-log.md`, in
`plan-f-mutation-log.md`'s shape: one section per row with the edit as a
diff hunk, the command, the pasted tail, the restore, and a summary table
(`fired / killed / survived / equivalent`).

- [ ] **Step 5: All four gate lines, commit**

```sh
cd packages/jet_cad_2d         && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd apps/dev_harness_2d         && CI=true flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
cd apps/floor_planner          && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build macos --debug && flutter build web
git status --short
git add docs/superpowers/notes/plan-01-mutation-log.md
git commit -m "test(gestures): Plan 01 mutation log -- sixteen fired, one declared equivalent"
```

---

### Task 10: The look, the results note, the spec's owed lines, and the resume point

**Files:**
- Create: `docs/superpowers/notes/2026-09-21-plan-01-results.md`
- Modify: `docs/superpowers/specs/2026-09-21-floor-planner-app-skeleton-design.md` (D4's check; Ruling 01-1's line)
- Modify: `roadmap/00-README.md` (the table row), `roadmap/01-app-skeleton.md` (status line), `STATUS.md`

- [ ] **Step 1: macOS — run it and look (spec criterion 12)**

`cd apps/floor_planner && flutter run -d macos --profile`. Report each as
**seen / not seen / could not judge**, in those words:

1. A two-finger scroll pans; the drawing follows the fingers with no drift
   and no stick, and does not change size.
2. A pinch zooms and the point between the fingers stays put.
3. A mouse-wheel notch zooms under the cursor, not about the window centre
   (put the cursor near a corner).
4. Zoom in past the maximum and out past the minimum: the view comes to
   rest without a jump and does not creep.
5. A two-finger scroll with cmd held still pans (D3, desktop row).
6. A middle-button drag pans; a left-button drag does nothing.
7. The walls close; every door swings into a room; the tile grids are
   square.

- [ ] **Step 2: Browser — Chrome or Safari, then Firefox**

```sh
cd apps/floor_planner && flutter run -d chrome --release
```

then open the same build in Firefox (`flutter build web` and serve
`build/web` with `python3 -m http.server 8080` from that directory). In
**each**, report:

1. Chrome/Safari: a two-finger trackpad scroll pans and a mouse-wheel notch
   zooms. Firefox: both pan.
2. A trackpad pinch zooms about the pointer (both).
3. ctrl+wheel zooms and does **not** zoom the page (both). On a Mac browser,
   real ctrl+wheel goes through the `HardwareKeyboard` path; note which
   machine and browser the look was on.
4. A ctrl+wheel *notch* with a mouse: how coarse it is (spec D3, ≈1.65× on
   Windows/Linux browsers; on macOS it is the 1.1× path). Judged, not
   measured.
5. A middle-button drag pans and does not start the browser's autoscroll.
6. The bounds come to rest without a jump.

The heuristic's misclassification, if seen (a flick that zooms once, a
notch that pans once), is recorded as seen, with the browser.

- [ ] **Step 3: The results note**

`docs/superpowers/notes/2026-09-21-plan-01-results.md`: the branch-point
harness count and the final one; the `STARTUP fit scale` line and the two
clamp ratios (D4's check, now done); the web build's outcome (first ever for
the package) with the command's last lines; the look, macOS and both
browser families, item by item; the mutation summary; the exit-gate table
below with PASS / MISS / OWED per row and the number beside each.

- [ ] **Step 4: The spec's owed lines**

In the spec: under D4, after *"The plan must sanity-check both constants…"*,
add one paragraph stating the fit scale at 1440×900 and the two ratios from
`startup_plan_test.dart`, and "checked 2026-MM-DD, unchanged" or the new
values. In the Architecture block, change
`analysis_options.yaml  generated and NOT committed (CLAUDE.md)` to
`analysis_options.yaml  generated, committed once at scaffold, never a rewrite (plan Ruling 01-1)`.
In Open questions, strike "The exact clamp constants" with a pointer to the
results note.

- [ ] **Step 5: Roadmap and STATUS**

`roadmap/00-README.md`: the 01 row gets the plan link and, on merge,
"executed". `roadmap/01-app-skeleton.md`: `**Status:** not started` →
`**Status:** spec 2026-09-21 (rev 2), plan 2026-09-21, executed on
plan-01/app-skeleton`. `STATUS.md`: a Plan 01 section in the shape of Plan
F's — what it delivers, the gate table, what was not looked at — and the
"Resume here" paragraph updated to say 01 has a plan and where it stands.

- [ ] **Step 6: Commit, then hand off**

```sh
git status --short
git add docs/superpowers/notes/2026-09-21-plan-01-results.md docs/superpowers/specs/2026-09-21-floor-planner-app-skeleton-design.md roadmap/00-README.md roadmap/01-app-skeleton.md STATUS.md
git commit -m "docs: Plan 01 results -- the look on macOS and in two browser families, the gate, the resume point"
```

Then `superpowers:finishing-a-development-branch`: the ledger under
`.superpowers/sdd/2026-09-21-floor-planner-app-skeleton/` is archived to
`docs/superpowers/ledgers/2026-09-21-floor-planner-app-skeleton/` in its own
commit before the merge, and the merge is `--no-ff`.

---

## Exit gate

Pre-committed from the spec; a miss is recorded as a miss.

1. `apps/floor_planner` builds and runs on macOS and shows the startup
   plan, non-empty, off-origin (`planner_shell_test.dart`, Task 10 step 1).
2. `flutter build web` succeeds (Task 8 step 5, pasted).
3. Desktop trackpad two-finger scroll pans and does not zoom, from a
   non-identity transform (`camera_gesture_trackpad_test.dart`).
4. Pinch zooms about the anchor, cumulative handling correct (same file).
5. Mouse wheel zooms 1.1× per notch about the pointer
   (`camera_gesture_signal_test.dart`).
6. Scroll signals: trackpad-kind pans under `wheelZooms`; mouse-kind zooms
   under `wheelZooms` and pans under `wheelPans`; direction asserted;
   modifier + scroll zooms under both; `PointerScaleEvent` compounds;
   `forBrowser` answers both ways (signal test, `gesture_policy_test.dart`).
7. Middle-button drag pans on both policies; left does nothing on either
   (`camera_gesture_button_test.dart`).
8. The camera rests on `minScale` and `maxScale` within `Tolerance` from
   one oversized zoom each way, and a second push notifies no listener
   (`camera_controller_test.dart`).
9. All sixteen mutants M-01a…M-01q (M-01h struck) fired and killed, E-01e′
   fired and recorded equivalent, with pasted output.
10. The harness passes at its branch-point count; `git diff --stat
    main..HEAD -- apps/dev_harness_2d` is empty.
11. All eleven gate commands exit 0; no `analysis_options.yaml` rewrite in
    any commit after Task 6's.
12. A human looked, on macOS and in both browser families, and each item
    is recorded seen / not seen / could not judge.

## Self-review

**Spec coverage.** D1 — Task 3 (a separate widget; `draft_canvas.dart`
untouched, checked by the file list). D2 — Task 2 (the value, `forBrowser`,
`forPlatform`, the conditional import) and Task 9's greps and E-01e′. D3 —
Tasks 3, 4, 5, row by row: trackpad scroll and pinch and drift (3), mouse
wheel and ctrl/cmd and `kind` and `PointerScaleEvent` (4), middle and left
(5); the sign rules are in Task 4's handler and asserted absolutely. D4 —
Task 1 (bounds, `Tolerance`, the early return) and Task 7's constants
check, recorded in Task 10. D5 — Task 7. D6 — Task 8's `PlannerView`
(`tiles: false`, `backend` unset) and step 5's first web build. D7 — Task
6 step 3. D8 — Task 8 builds web in the same plan; Task 10 looks in two
browser families. Invariants 1–6 — Global Constraints, Task 1 step 5, Task
5 step 4, Task 9 step 3. Every mutant in the spec's list has a row in Task
9; M-01h is struck there as in the spec. The cross-policy test — Task 5.
**Not covered, deliberately:** Windows and Linux (spec, open questions);
web performance (spec D8); touch (spec non-goals).

**Placeholder scan.** No "TBD", no "handle edge cases", no "similar to Task
N". Three steps name a fallback the repository decides: Task 2 step 5
(`dart:ui_web` under `flutter analyze`), Task 4 step 4 (`sendKeyDownEvent`
vs `simulateKeyDownEvent`), Task 7 step 4 (the count outside 500–1,000),
each with the exact action.

**Type consistency.** `CameraController(initial, {minScale, maxScale})` —
Tasks 1, 3 (fixture), 8. `GesturePolicy({mouseWheel, wheelZoomStep,
panButtons})`, `wheelZooms`, `wheelPans`, `forBrowser({firefox})`,
`forPlatform()` — Tasks 2, 3, 4, 5, 8, 9. `CameraGestureDetector({camera,
policy, child})` — Tasks 3, 8. `ScrollAction.{pan, zoom}` — Tasks 2, 4.
`isFirefoxBrowser()` — Task 2 both files. `fitOffOrigin({minScale,
maxScale})`, `pumpDetector(tester, camera, policy)`, `screenOf(camera,
world)`, `globalFocus()`, `kLocalFocus`, `kWorldProbe`, `kDetectorSize` —
Tasks 3, 4, 5. `startupPlan(measurer)`, `kMinScale`, `kMaxScale`,
`kPlanOriginX/Y`, `kPlanWidth/Height` — Tasks 7, 8. `PlannerView({document,
index, camera, policy})` — Task 8 both files.
