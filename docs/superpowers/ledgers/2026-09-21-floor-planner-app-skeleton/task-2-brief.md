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

