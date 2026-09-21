# Plan 01's mutation log — Task 9

Sixteen mutations (M-01a..M-01q, M-01h struck by spec) fired one at a time
against the `CameraController` / `GesturePolicy` / `CameraGestureDetector`
tree on `plan-01/app-skeleton`, plus one spec-declared-equivalent mutation
(E-01e′), each from a `cp <file> /tmp/mut.bak` backup made immediately before
editing by hand and restored the same way afterward. No mutation was ever
reverted with `git checkout --`. `git status --short` was clean after every
restore — this log is the only file this task's commit carries.

All commands below ran from `packages/jet_cad_2d_flutter`, against the
witness file(s) named per row (never the whole suite, except E-01e′'s
declared-equivalent run and the final gates), with `CI=true`.

Files mutated: `lib/src/camera_gesture_detector.dart` (`cgd`: M-01a, M-01b,
M-01c, M-01d, M-01e, M-01f, M-01g, M-01i, M-01m, M-01n, M-01p),
`lib/src/camera_controller.dart` (`cc`: M-01j, M-01k, M-01l, M-01o),
`lib/src/gesture_policy.dart` (`gp`: M-01q, E-01e′).

One mutation, **M-01b, SURVIVED** its named witness on the first shot: the
witness sent the same `scale: 1.5` three times, and the widget's exact-
equality coalescing guard (`if (scale == _gestureZoom) return;`, Ruling
01-4) meant only the first update ever reached `zoomAt`, where the running
denominator is always `1.0` by construction — a degenerate fixture, in the
sense `CLAUDE.md` warns about, not a defect in `zoomAt`'s caller. Fix round
1 (controller's ruling) changed the *test*, not the widget: the pinch
witness now ramps the cumulative `scale` through three different values
(`1.2`, `1.5`, `2.0`), which a rising real pinch would report, and asserts
the ramp's landing ratio (`2.0`) rather than the repeated value's own
product (`3.6`). M-01b was re-fired against the fixed test and is now
KILLED — see its section below for both runs. `ScrollAction` in the brief's
table is `ScrollSignalAction` throughout (Task 4 rename); the M-01e edit is
`policy.mouseWheel` → `GesturePolicy.wheelZooms.mouseWheel`.

---

## M-01a — pan by cumulative `pan`, not the per-event delta

**File:** `lib/src/camera_gesture_detector.dart`, `_onPanZoomUpdate`

**Diff applied:**

```diff
-    final delta = event.localPanDelta;
+    final delta = event.localPan;
```

**Command:** `CI=true flutter test test/camera_gesture_trackpad_test.dart`

**Verbatim output (head — the first failure, and it fires first):**

```
00:00 +0: PointerPanZoom under wheelZooms two-finger scroll pans by the delta and does not zoom
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: a numeric value within <1e-9> of <0>
  Actual: <-600.0>
   Which:  differs by <600.0>
...
This was caught by the test expectation on the following line:
  .../test/camera_gesture_trackpad_test.dart line 34
The test description was:
  two-finger scroll pans by the delta and does not zoom
════════════════════════════════════════════════════════════════════════════════════════════════════
```

**Verbatim output (tail):**

```
00:00 +2 -6: PointerPanZoom under wheelPans a drifting pinch pans by the delta and zooms by the ratio
00:00 +2 -6: PointerPanZoom under wheelPans a second gesture starts from a clean running scale
00:00 +3 -6: PointerPanZoom under wheelPans a two-finger scroll does not notify for its unchanged scale
00:00 +4 -6: Some tests failed.

Failing tests:
  .../test/camera_gesture_trackpad_test.dart: PointerPanZoom under wheelPans a drifting pinch pans by the delta and zooms by the ratio
  .../test/camera_gesture_trackpad_test.dart: PointerPanZoom under wheelPans pinch zooms by the cumulative ratio about the anchor
  .../test/camera_gesture_trackpad_test.dart: PointerPanZoom under wheelPans two-finger scroll pans by the delta and does not zoom
  .../test/camera_gesture_trackpad_test.dart: PointerPanZoom under wheelZooms a drifting pinch pans by the delta and zooms by the ratio
  ... and 2 more
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/camera_gesture_detector.dart` — `git status --short` clean.

**Verdict: KILLED**, decisively (10 of 10 cases across both policies fail),
but on a different assertion than the brief predicted. The brief's row
expects the *dy* assertion (line 35, `closeTo(-120, ...)`, tripled to -240)
to catch it. In fact the *dx* assertion one line above (line 34,
`closeTo(0, ...)`) catches it first, with `Actual: -600.0`: `PointerEvent`'s
`localPan` getter is `PointerEvent.transformPosition(transform, pan)` — a
full affine position transform, including the widget's translation — not a
delta transform. Reading it where a per-event delta is wanted drags in the
detector's own local-origin offset (`-200` three times), which shows up as a
large, wrong *dx* before the tripled-*dy* effect the brief anticipated is
ever reached. Confirmed kill either way; recorded as observed rather than
as predicted, per this task's "never synthesize" rule.

---

## M-01b — drop the running division

**File:** `lib/src/camera_gesture_detector.dart`, `_onPanZoomUpdate`

**Diff applied:**

```diff
-    camera.zoomAt(_gestureAnchor, scale / _gestureZoom);
+    camera.zoomAt(_gestureAnchor, scale);
```

**Command:** `CI=true flutter test test/camera_gesture_trackpad_test.dart`

**Verbatim output (in full — GREEN, not the predicted red):**

```
00:00 +0: PointerPanZoom under wheelZooms two-finger scroll pans by the delta and does not zoom
00:00 +1: PointerPanZoom under wheelZooms pinch zooms by the cumulative ratio about the anchor
00:00 +2: PointerPanZoom under wheelZooms a drifting pinch pans by the delta and zooms by the ratio
00:00 +3: PointerPanZoom under wheelZooms a second gesture starts from a clean running scale
00:00 +4: PointerPanZoom under wheelZooms a two-finger scroll does not notify for its unchanged scale
00:00 +5: PointerPanZoom under wheelPans two-finger scroll pans by the delta and does not zoom
00:00 +6: PointerPanZoom under wheelPans pinch zooms by the cumulative ratio about the anchor
00:00 +7: PointerPanZoom under wheelPans a drifting pinch pans by the delta and zooms by the ratio
00:00 +8: PointerPanZoom under wheelPans a second gesture starts from a clean running scale
00:00 +9: PointerPanZoom under wheelPans a two-finger scroll does not notify for its unchanged scale
00:00 +10: All tests passed!
EXIT=0
```

**Restore:** `cp /tmp/mut.bak lib/src/camera_gesture_detector.dart` — `git status --short` clean.

**Verdict (first shot): SURVIVED — a plan defect, reported here, not fixed
yet.** See "Re-fired after the fixture fix" below for the fix and the kill.

`_onPanZoomUpdate` guards every application with
`if (scale == _gestureZoom) return;` right before the mutated line, and
`_gestureZoom` is reset to exactly `1.0` in `_onPanZoomStart` at the top of
every gesture. Walking the named witness, "pinch zooms by the cumulative
ratio about the anchor" (three `panZoomUpdate` calls, each reporting
`scale: 1.5`, matching the real trackpad API where `scale` is cumulative
since the gesture began):

- Update 1: `scale == 1.5`, `_gestureZoom == 1.0` (just reset) → not equal,
  proceeds. Original: `1.5 / 1.0 == 1.5`. Mutant: `1.5` directly. **Same
  number**, because the denominator on the very first application of any
  gesture is always `1.0` by construction. `_gestureZoom` is then set to
  `1.5` either way.
- Updates 2 and 3: `scale == 1.5 == _gestureZoom` → the early-return guard
  fires and neither the original division nor the mutant's raw value is ever
  reached.

So across all three updates the observable result — one application of
factor `1.5` — is bit-for-bit identical under the mutation. The same holds
for every other test in this file: "a drifting pinch..." and "a second
gesture starts from a clean running scale" each also only ever apply a
*single*, first-in-gesture, non-repeated `scale` value, so `_gestureZoom` is
always `1.0` at the one moment the division would matter. **No test in this
witness file ever sends two *different*, non-`1.0` cumulative `scale` values
within one continuous gesture** (which is the only shape of input that would
expose `scale / _gestureZoom` bypassed as raw `scale`, e.g. 1.5 then 2.0
would give a real ratio of ~1.333 under the original code and 2.0 under the
mutant). This is not a coincidental miss on a secondary witness (Plan F's
M-F5 pattern) — it is the *only* named witness for this row, and it cannot
distinguish the mutation as currently written. Reported per this task's
charter: no test or production change was made to chase it.

### Re-fired after the fixture fix

**Controller's ruling:** the pinch witness was a degenerate fixture (repeats
the same cumulative `scale`, and the widget's own exact-equality coalescing
guard, Ruling 01-4, only ever lets the first update reach `zoomAt`). Fix the
test, not the widget: a real pinch reports a *rising* cumulative scale.

**Test diff applied** (`test/camera_gesture_trackpad_test.dart`, inside the
per-policy `group`, in `'pinch zooms by the cumulative ratio about the
anchor'`):

```diff
       // Pinch: `scale` is cumulative and has no per-event delta, so each
       // update applies scale / running (spec, M-01b). Three updates
-      // reporting 1.5 zoom by 1.5, not 1.5^3. The anchor is where the
-      // gesture started, not the viewport centre.
+      // A rising ramp of cumulative values (1.2, 1.5, 2.0) lands the
+      // gesture on 2.0, not on the product 3.6 a mutant that dropped the
+      // running division would reach. The anchor is where the gesture
+      // started, not the viewport centre.
       testWidgets('pinch zooms by the cumulative ratio about the anchor',
           (tester) async {
         final camera = fitOffOrigin();
         await pumpDetector(tester, camera, policy);
         final scaleBefore = camera.value.scale;
         final under =
             camera.value.screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));

         final p = TestPointer(1, PointerDeviceKind.trackpad);
         await tester.sendEventToBinding(p.panZoomStart(globalFocus()));
-        for (var i = 0; i < 3; i++) {
-          await tester
-              .sendEventToBinding(p.panZoomUpdate(globalFocus(), scale: 1.5));
-        }
+        // A real pinch reports a rising cumulative scale. With the running
+        // division each update applies only its increment (1.2, then 1.25,
+        // then 1.333…) and the gesture lands on 2.0; applying the raw value
+        // compounds to 1.2 × 1.5 × 2.0 = 3.6 (M-01b).
+        for (final cumulative in const [1.2, 1.5, 2.0]) {
+          await tester.sendEventToBinding(
+              p.panZoomUpdate(globalFocus(), scale: cumulative));
+        }
         await tester.sendEventToBinding(p.panZoomEnd());
         await tester.pump();

-        expect(camera.value.scale / scaleBefore, closeTo(1.5, 1e-9));
+        expect(camera.value.scale / scaleBefore, closeTo(2.0, 1e-9));
```

**GREEN on the fixed test, unmutated code** —
`CI=true flutter test test/camera_gesture_trackpad_test.dart`:

```
00:00 +0: PointerPanZoom under wheelZooms two-finger scroll pans by the delta and does not zoom
00:00 +1: PointerPanZoom under wheelZooms pinch zooms by the cumulative ratio about the anchor
00:00 +2: PointerPanZoom under wheelZooms a drifting pinch pans by the delta and zooms by the ratio
00:00 +3: PointerPanZoom under wheelZooms a second gesture starts from a clean running scale
00:00 +4: PointerPanZoom under wheelZooms a two-finger scroll does not notify for its unchanged scale
00:00 +5: PointerPanZoom under wheelPans two-finger scroll pans by the delta and does not zoom
00:00 +6: PointerPanZoom under wheelPans pinch zooms by the cumulative ratio about the anchor
00:00 +7: PointerPanZoom under wheelPans a drifting pinch pans by the delta and zooms by the ratio
00:00 +8: PointerPanZoom under wheelPans a second gesture starts from a clean running scale
00:00 +9: PointerPanZoom under wheelPans a two-finger scroll does not notify for its unchanged scale
00:00 +10: All tests passed!
EXIT=0
```

**Re-fire command:** `cp lib/src/camera_gesture_detector.dart /tmp/mut.bak`,
then the same M-01b edit (`camera.zoomAt(_gestureAnchor, scale /
_gestureZoom);` → `camera.zoomAt(_gestureAnchor, scale);`), then
`CI=true flutter test test/camera_gesture_trackpad_test.dart`:

**Verbatim output (tail — RED, now):**

```
00:00 +1 -1: PointerPanZoom under wheelZooms pinch zooms by the cumulative ratio about the anchor [E]
  Test failed. See exception logs above.
  The test description was: pinch zooms by the cumulative ratio about the anchor
  
00:00 +1 -1: PointerPanZoom under wheelZooms a drifting pinch pans by the delta and zooms by the ratio
00:00 +2 -1: PointerPanZoom under wheelZooms a second gesture starts from a clean running scale
00:00 +3 -1: PointerPanZoom under wheelZooms a two-finger scroll does not notify for its unchanged scale
00:00 +4 -1: PointerPanZoom under wheelPans two-finger scroll pans by the delta and does not zoom
00:00 +5 -1: PointerPanZoom under wheelPans pinch zooms by the cumulative ratio about the anchor
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: a numeric value within <1e-9> of <2.0>
  Actual: <3.6>
   Which:  differs by <1.6>
...
This was caught by the test expectation on the following line:
  .../test/camera_gesture_trackpad_test.dart line 68
The test description was:
  pinch zooms by the cumulative ratio about the anchor
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +5 -2: PointerPanZoom under wheelPans pinch zooms by the cumulative ratio about the anchor [E]
  Test failed. See exception logs above.
  The test description was: pinch zooms by the cumulative ratio about the anchor
  
00:00 +5 -2: PointerPanZoom under wheelPans a drifting pinch pans by the delta and zooms by the ratio
00:00 +6 -2: PointerPanZoom under wheelPans a second gesture starts from a clean running scale
00:00 +7 -2: PointerPanZoom under wheelPans a two-finger scroll does not notify for its unchanged scale
00:00 +8 -2: Some tests failed.

Failing tests:
  .../test/camera_gesture_trackpad_test.dart: PointerPanZoom under wheelPans pinch zooms by the cumulative ratio about the anchor
  .../test/camera_gesture_trackpad_test.dart: PointerPanZoom under wheelZooms pinch zooms by the cumulative ratio about the anchor
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/camera_gesture_detector.dart` — `git status --short` clean (apart from the intended test-fixture edit).

**Verdict (re-fired): KILLED.** Both policies now fail with `Actual: 3.6`
where `2.0` is expected — the ramp's compounded product under the mutant
(`1.2 × 1.5 × 2.0`) versus the ramp's landing ratio (`2.0`) under the running
division. M-01b is closed.

---

## M-01c — zoom about the widget centre, not the pointer

**File:** `lib/src/camera_gesture_detector.dart`, `_onSignal`, the
`ScrollSignalAction.zoom` case

**Diff applied:**

```diff
-        camera.zoomAt(
-            event.localPosition,
-            event.scrollDelta.dy < 0
+        camera.zoomAt(
+            const Offset(200, 150),
+            event.scrollDelta.dy < 0
                 ? policy.wheelZoomStep
                 : 1 / policy.wheelZoomStep);
```

**Command:** `CI=true flutter test test/camera_gesture_signal_test.dart`

**Verbatim output (the named witness's failure):**

```
00:00 +0: mouse-kind scroll, no modifier wheelZooms: zooms 1.1 per notch up about the pointer
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: a numeric value within <1e-9> of <1015.7894736842106>
  Actual: <1018.8995215311006>
   Which:  differs by <3.1100478468899837>
...
This was caught by the test expectation on the following line:
  .../test/camera_gesture_signal_test.dart line 47
The test description was:
  wheelZooms: zooms 1.1 per notch up about the pointer
════════════════════════════════════════════════════════════════════════════════════════════════════
```

**Verbatim output (tail):**

```
00:00 +6 -5: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelZooms
00:00 +7 -5: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelPans
00:00 +8 -5: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) a scale below 1 zooms out
00:00 +9 -5: Some tests failed.

Failing tests:
  .../test/camera_gesture_signal_test.dart: modifier held Control Left + mouse scroll zooms about the pointer under wheelPans
  .../test/camera_gesture_signal_test.dart: modifier held Control Left + mouse scroll zooms about the pointer under wheelZooms
  .../test/camera_gesture_signal_test.dart: modifier held Meta Left + mouse scroll zooms about the pointer under wheelPans
  .../test/camera_gesture_signal_test.dart: modifier held Meta Left + mouse scroll zooms about the pointer under wheelZooms
  .../test/camera_gesture_signal_test.dart: mouse-kind scroll, no modifier wheelZooms: zooms 1.1 per notch up about the pointer
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/camera_gesture_detector.dart` — `git status --short` clean.

**Verdict: KILLED**, exactly as ruled: `still.x` (`1018.9`) misses `under.x`
(`1015.8`) because the zoom is now anchored at the widget centre `(200,150)`
instead of the off-centre pointer `kLocalFocus = (70, 230)`.

---

## M-01d — no pan/zoom handler at all

**File:** `lib/src/camera_gesture_detector.dart`, `build`

**Diff applied:**

```diff
         onPointerPanZoomStart: _onPanZoomStart,
-        onPointerPanZoomUpdate: _onPanZoomUpdate,
         onPointerSignal: _onSignal,
```

**Command:** `CI=true flutter test test/camera_gesture_trackpad_test.dart`

**Verbatim output (tail):**

```
00:00 +0 -9: PointerPanZoom under wheelPans a second gesture starts from a clean running scale [E]
  Test failed. See exception logs above.
  The test description was: a second gesture starts from a clean running scale
  
00:00 +0 -9: PointerPanZoom under wheelPans a two-finger scroll does not notify for its unchanged scale
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: <1>
  Actual: <0>
one pan, no zoomAt(anchor, 1.0)
...
This was caught by the test expectation on the following line:
  .../test/camera_gesture_trackpad_test.dart line 134
The test description was:
  a two-finger scroll does not notify for its unchanged scale
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +0 -10: PointerPanZoom under wheelPans a two-finger scroll does not notify for its unchanged scale [E]
  Test failed. See exception logs above.
  The test description was: a two-finger scroll does not notify for its unchanged scale
  
00:00 +0 -10: Some tests failed.

Failing tests:
  .../test/camera_gesture_trackpad_test.dart: PointerPanZoom under wheelPans a drifting pinch pans by the delta and zooms by the ratio
  .../test/camera_gesture_trackpad_test.dart: PointerPanZoom under wheelPans a second gesture starts from a clean running scale
  .../test/camera_gesture_trackpad_test.dart: PointerPanZoom under wheelPans a two-finger scroll does not notify for its unchanged scale
  .../test/camera_gesture_trackpad_test.dart: PointerPanZoom under wheelPans pinch zooms by the cumulative ratio about the anchor
  ... and 6 more
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/camera_gesture_detector.dart` — `git status --short` clean.

**Verdict: KILLED**, totally: `+0 -10` — all 10 trackpad tests fail, the
camera never moves under any of them (`localPanDelta`/`scale` never reach the
camera with no `onPointerPanZoomUpdate` wired).

---

## M-01e — ignore the injected policy in the mouse-wheel arm

**File:** `lib/src/camera_gesture_detector.dart`, `_onSignal`

**Diff applied:**

```diff
     final action = keyboard.isControlPressed || keyboard.isMetaPressed
         ? ScrollSignalAction.zoom
         : event.kind == PointerDeviceKind.trackpad
             ? ScrollSignalAction.pan
-            : policy.mouseWheel;
+            : GesturePolicy.wheelZooms.mouseWheel;
```

**Command:** `CI=true flutter test test/camera_gesture_signal_test.dart`

**Verbatim output (tail):**

```
00:00 +2: mouse-kind scroll, no modifier wheelPans: pans by -scrollDelta and does not zoom
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: a numeric value within <1e-9> of <-120>
  Actual: <3.818181818182893>
   Which:  differs by <123.8181818181829>
scroll down: the content moves up
...
This was caught by the test expectation on the following line:
  .../test/camera_gesture_signal_test.dart line 72
The test description was:
  wheelPans: pans by -scrollDelta and does not zoom
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +2 -1: mouse-kind scroll, no modifier wheelPans: pans by -scrollDelta and does not zoom [E]
  Test failed. See exception logs above.
  The test description was: wheelPans: pans by -scrollDelta and does not zoom
  
00:00 +3 -1: trackpad-kind scroll (a Chromium/WebKit browser trackpad) pans by -scrollDelta under wheelZooms
00:00 +4 -1: trackpad-kind scroll (a Chromium/WebKit browser trackpad) pans by -scrollDelta under wheelPans
00:00 +5 -1: modifier held Control Left + mouse scroll zooms about the pointer under wheelZooms
00:00 +6 -1: modifier held Control Left + mouse scroll zooms about the pointer under wheelPans
00:00 +7 -1: modifier held Meta Left + mouse scroll zooms about the pointer under wheelZooms
00:00 +8 -1: modifier held Meta Left + mouse scroll zooms about the pointer under wheelPans
00:00 +9 -1: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelZooms
00:00 +10 -1: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelPans
00:00 +11 -1: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) a scale below 1 zooms out
00:00 +12 -1: Some tests failed.

Failing tests:
  .../test/camera_gesture_signal_test.dart: mouse-kind scroll, no modifier wheelPans: pans by -scrollDelta and does not zoom
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/camera_gesture_detector.dart` — `git status --short` clean.

**Verdict: KILLED**, exactly by the named witness: under `wheelPans`, a
mouse-kind scroll now zooms (via `GesturePolicy.wheelZooms.mouseWheel`)
instead of panning, so `after.dy - before.dy` reads `3.82` (a small zoom
artefact on the off-anchor probe point) instead of the expected pan of
`-120`.

---

## M-01f — ignore the ctrl/cmd modifier

**File:** `lib/src/camera_gesture_detector.dart`, `_onSignal`

**Diff applied:**

```diff
-    final action = keyboard.isControlPressed || keyboard.isMetaPressed
-        ? ScrollSignalAction.zoom
-        : event.kind == PointerDeviceKind.trackpad
+    final action = event.kind == PointerDeviceKind.trackpad
             ? ScrollSignalAction.pan
             : policy.mouseWheel;
```

**Command:** `CI=true flutter test test/camera_gesture_signal_test.dart`

**Verbatim output (tail):**

```
00:00 +6 -1: modifier held Control Left + mouse scroll zooms about the pointer under wheelPans [E]
  Test failed. See exception logs above.
  The test description was: Control Left + mouse scroll zooms about the pointer under wheelPans
  
00:00 +6 -1: modifier held Meta Left + mouse scroll zooms about the pointer under wheelZooms
00:00 +7 -1: modifier held Meta Left + mouse scroll zooms about the pointer under wheelPans
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: a numeric value within <1e-9> of <1.1>
  Actual: <1.0>
   Which:  differs by <0.10000000000000009>
...
This was caught by the test expectation on the following line:
  .../test/camera_gesture_signal_test.dart line 129
The test description was:
  Meta Left + mouse scroll zooms about the pointer under wheelPans
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +7 -2: modifier held Meta Left + mouse scroll zooms about the pointer under wheelPans [E]
  Test failed. See exception logs above.
  The test description was: Meta Left + mouse scroll zooms about the pointer under wheelPans
  
00:00 +7 -2: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelZooms
00:00 +8 -2: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelPans
00:00 +9 -2: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) a scale below 1 zooms out
00:00 +10 -2: Some tests failed.

Failing tests:
  .../test/camera_gesture_signal_test.dart: modifier held Control Left + mouse scroll zooms about the pointer under wheelPans
  .../test/camera_gesture_signal_test.dart: modifier held Meta Left + mouse scroll zooms about the pointer under wheelPans
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/camera_gesture_detector.dart` — `git status --short` clean.

**Verdict: KILLED**, exactly by the ruled witness: under `wheelPans`, holding
ctrl or cmd no longer forces a zoom (the modifier is never read), so the
scale ratio reads `1.0` where `1.1` is expected. (`wheelZooms` cases stay
green because `policy.mouseWheel` there already means zoom, coincidentally
matching — the row's own "under wheelPans" qualifier is exactly this.)

---

## M-01g — no `PointerScaleEvent` branch

**File:** `lib/src/camera_gesture_detector.dart`, `_onSignal`

**Diff applied:**

```diff
-    if (event is PointerScaleEvent) {
-      camera.zoomAt(event.localPosition, event.scale);
-      return;
-    }
     if (event is! PointerScrollEvent) return;
```

**Command:** `CI=true flutter test test/camera_gesture_signal_test.dart`

**Verbatim output (tail):**

```
00:00 +9 -2: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelPans [E]
  Test failed. See exception logs above.
  The test description was: zooms by the event scale about the pointer, compounding, under wheelPans
  
00:00 +9 -2: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) a scale below 1 zooms out
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: a numeric value within <1e-9> of <0.6065306597126334>
  Actual: <1.0>
   Which:  differs by <0.3934693402873666>
...
This was caught by the test expectation on the following line:
  .../test/camera_gesture_signal_test.dart line 171
The test description was:
  a scale below 1 zooms out
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +9 -3: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) a scale below 1 zooms out [E]
  Test failed. See exception logs above.
  The test description was: a scale below 1 zooms out
  
00:00 +9 -3: Some tests failed.

Failing tests:
  .../test/camera_gesture_signal_test.dart: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) a scale below 1 zooms out
  .../test/camera_gesture_signal_test.dart: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelPans
  .../test/camera_gesture_signal_test.dart: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelZooms
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/camera_gesture_detector.dart` — `git status --short` clean.

**Verdict: KILLED**, exactly as ruled: `camera.value.scale / scaleBefore`
reads `1.0` (no-op) where `1.728` (`1.2^3`) is expected — `PointerScaleEvent`
now falls through `if (event is! PointerScrollEvent) return;` and is
silently ignored.

---

## M-01i — pan on any button, not just the policy's

**File:** `lib/src/camera_gesture_detector.dart`, `_onMove`

**Diff applied:**

```diff
-    if (event.buttons & widget.policy.panButtons != 0) {
+    if (event.buttons != 0) {
```

**Command:** `CI=true flutter test test/camera_gesture_button_test.dart`

**Verbatim output (tail):**

```
00:00 +2 -3: left-button drag moves nothing under wheelPans [E]
  Test failed. See exception logs above.
  The test description was: left-button drag moves nothing under wheelPans
  
00:00 +2 -3: right-button drag moves nothing under wheelPans
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: same instance as Transform2:<Transform2(3.8, 0.0, 0.0, -3.8, -3790.0, 7845.0)>
  Actual: Transform2:<Transform2(3.8, 0.0, 0.0, -3.8, -3757.0, 7824.0)>
...
This was caught by the test expectation on the following line:
  .../test/camera_gesture_button_test.dart line 53
The test description was:
  right-button drag moves nothing under wheelPans
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +2 -4: right-button drag moves nothing under wheelPans [E]
  Test failed. See exception logs above.
  The test description was: right-button drag moves nothing under wheelPans
  
00:00 +2 -4: the three pan arms move the camera identically
00:00 +3 -4: Some tests failed.

Failing tests:
  .../test/camera_gesture_button_test.dart: left-button drag moves nothing under wheelPans
  .../test/camera_gesture_button_test.dart: left-button drag moves nothing under wheelZooms
  .../test/camera_gesture_button_test.dart: right-button drag moves nothing under wheelPans
  .../test/camera_gesture_button_test.dart: right-button drag moves nothing under wheelZooms
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/camera_gesture_detector.dart` — `git status --short` clean.

**Verdict: KILLED**, exactly as ruled: left- and right-button drags now move
the camera under both policies — `worldToScreenMatrix` is no longer `same`
as the unmoved fixture.

---

## M-01j — reject instead of landing on the bound

**File:** `lib/src/camera_controller.dart`, `zoomAt`

**Diff applied:**

```diff
     if (f > 1.0) {
       if (_tolerance.compare(current, maxScale) >= 0) return;
-      if (_tolerance.compare(current * f, maxScale) > 0) f = maxScale / current;
+      if (_tolerance.compare(current * f, maxScale) > 0) return;
     } else if (f < 1.0) {
       if (_tolerance.compare(current, minScale) <= 0) return;
-      if (_tolerance.compare(current * f, minScale) < 0) f = minScale / current;
+      if (_tolerance.compare(current * f, minScale) < 0) return;
     }
```

**Command:** `CI=true flutter test test/camera_controller_test.dart`

**Verbatim output (tail):**

```
00:00 +12: CameraController bounds an oversized zoom in lands on maxScale, not past it
00:00 +12 -1: CameraController bounds an oversized zoom in lands on maxScale, not past it [E]
  Expected: true
    Actual: <false>
  landed on the bound: 7.6
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/camera_controller_test.dart 178:7              main.<fn>.<fn>
  
00:00 +12 -1: CameraController bounds an oversized zoom out lands on minScale
00:00 +12 -2: CameraController bounds an oversized zoom out lands on minScale [E]
  Expected: true
    Actual: <false>
  landed on the bound: 7.6
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/camera_controller_test.dart 189:7              main.<fn>.<fn>
  
00:00 +12 -2: CameraController bounds a zoom that stays inside the bounds is not clamped
00:00 +13 -2: CameraController bounds at a bound, pushing further does not notify
00:00 +13 -3: CameraController bounds at a bound, pushing further does not notify [E]
  Expected: <0>
    Actual: <1>
  at rest on maxScale
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/camera_controller_test.dart 206:7              main.<fn>.<fn>
  
00:00 +13 -3: CameraController bounds zoomAt still ignores a singular factor with bounds set
00:00 +14 -3: Some tests failed.

Failing tests:
  .../test/camera_controller_test.dart: CameraController bounds an oversized zoom in lands on maxScale, not past it
  .../test/camera_controller_test.dart: CameraController bounds an oversized zoom out lands on minScale
  .../test/camera_controller_test.dart: CameraController bounds at a bound, pushing further does not notify
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/camera_controller.dart` — `git status --short` clean.

**Verdict: KILLED**, exactly as ruled: the fixture's scale stays at `7.6`
(the un-clamped starting scale) instead of landing on `12.0` — the gesture
is rejected outright instead of landing on the bound.

---

## M-01k — swap `maxScale` and `minScale` in the four comparisons

**File:** `lib/src/camera_controller.dart`, `zoomAt`

**Diff applied:**

```diff
     if (f > 1.0) {
-      if (_tolerance.compare(current, maxScale) >= 0) return;
-      if (_tolerance.compare(current * f, maxScale) > 0) f = maxScale / current;
+      if (_tolerance.compare(current, minScale) >= 0) return;
+      if (_tolerance.compare(current * f, minScale) > 0) f = minScale / current;
     } else if (f < 1.0) {
-      if (_tolerance.compare(current, minScale) <= 0) return;
-      if (_tolerance.compare(current * f, minScale) < 0) f = minScale / current;
+      if (_tolerance.compare(current, maxScale) <= 0) return;
+      if (_tolerance.compare(current * f, maxScale) < 0) f = maxScale / current;
     }
```

**Command:** `CI=true flutter test test/camera_controller_test.dart`

**Verbatim output (tail):**

```
00:00 +10 -2: CameraController bounds defaults are unbounded, so an unbounded caller is unchanged [E]
  Expected: a numeric value within <0.000005699999999999999> of <5699999.999999999>
    Actual: <5.699999999999999>
     Which:  differs by <5699994.299999999>
  
00:00 +10 -3: CameraController bounds an oversized zoom in lands on maxScale, not past it [E]
  Expected: true
    Actual: <false>
  landed on the bound: 7.6
  
00:00 +10 -4: CameraController bounds an oversized zoom out lands on minScale [E]
  Expected: true
    Actual: <false>
  landed on the bound: 7.6
  
00:00 +10 -5: CameraController bounds a zoom that stays inside the bounds is not clamped [E]
  Expected: a numeric value within <1e-9> of <11.399999999999999>
    Actual: <7.6>
     Which:  differs by <3.799999999999999>
  
00:00 +10 -6: CameraController bounds at a bound, pushing further does not notify [E]
  Expected: <1>
    Actual: <0>
  zooming back out is a real change
  
00:00 +11 -6: Some tests failed.

Failing tests:
  .../test/camera_controller_test.dart: CameraController bounds a zoom that stays inside the bounds is not clamped
  .../test/camera_controller_test.dart: CameraController bounds an oversized zoom in lands on maxScale, not past it
  .../test/camera_controller_test.dart: CameraController bounds an oversized zoom out lands on minScale
  .../test/camera_controller_test.dart: CameraController bounds at a bound, pushing further does not notify
  ... and 2 more
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/camera_controller.dart` — `git status --short` clean.

**Verdict: KILLED**, exactly as ruled: `f > 1.0` now compares against
`minScale` (`0.5`), so `compare(current=7.6, minScale=0.5) >= 0` is
immediately true and the zoom-in returns at once — the scale stays `7.6`
where `12.0` is expected.

---

## M-01l — clamp the factor, not the resulting scale

**File:** `lib/src/camera_controller.dart`, `zoomAt`

**Diff applied:**

```diff
     if (f > 1.0) {
       if (_tolerance.compare(current, maxScale) >= 0) return;
-      if (_tolerance.compare(current * f, maxScale) > 0) f = maxScale / current;
+      if (_tolerance.compare(current * f, maxScale) > 0) f = f.clamp(minScale, maxScale);
     } else if (f < 1.0) {
       if (_tolerance.compare(current, minScale) <= 0) return;
-      if (_tolerance.compare(current * f, minScale) < 0) f = minScale / current;
+      if (_tolerance.compare(current * f, minScale) < 0) f = f.clamp(minScale, maxScale);
     }
```

**Command:** `CI=true flutter test test/camera_controller_test.dart`

**Verbatim output (tail):**

```
00:00 +12: CameraController bounds an oversized zoom in lands on maxScale, not past it
00:00 +12 -1: CameraController bounds an oversized zoom in lands on maxScale, not past it [E]
  Expected: true
    Actual: <false>
  landed on the bound: 76.0
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/camera_controller_test.dart 178:7              main.<fn>.<fn>
  
00:00 +12 -1: CameraController bounds an oversized zoom out lands on minScale
00:00 +12 -2: CameraController bounds an oversized zoom out lands on minScale [E]
  Expected: true
    Actual: <false>
  landed on the bound: 3.8
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/camera_controller_test.dart 189:7              main.<fn>.<fn>
  
00:00 +12 -2: CameraController bounds a zoom that stays inside the bounds is not clamped
00:00 +13 -2: CameraController bounds at a bound, pushing further does not notify
00:00 +13 -3: CameraController bounds at a bound, pushing further does not notify [E]
  Expected: <0>
    Actual: <1>
  at rest on minScale
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/camera_controller_test.dart 212:7              main.<fn>.<fn>
  
00:00 +13 -3: CameraController bounds zoomAt still ignores a singular factor with bounds set
00:00 +14 -3: Some tests failed.

Failing tests:
  .../test/camera_controller_test.dart: CameraController bounds an oversized zoom in lands on maxScale, not past it
  .../test/camera_controller_test.dart: CameraController bounds an oversized zoom out lands on minScale
  .../test/camera_controller_test.dart: CameraController bounds at a bound, pushing further does not notify
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/camera_controller.dart` — `git status --short` clean.

**Verdict: KILLED**, exactly as ruled: `f = 10.0` already sits inside
`[0.5, 12.0]`, so `f.clamp(...)` is a no-op and the resulting scale is
`7.6 * 10 == 76.0`, not the bound `12.0`. This is the fixture the file's own
comment calls out — a fixture at scale `1.0` could not distinguish "clamp
the factor" from "clamp the result".

---

## M-01m — flip the scroll-pan sign

**File:** `lib/src/camera_gesture_detector.dart`, `_onSignal`, the
`ScrollSignalAction.pan` case

**Diff applied:**

```diff
-        camera.panBy(-event.scrollDelta);
+        camera.panBy(event.scrollDelta);
```

**Command:** `CI=true flutter test test/camera_gesture_signal_test.dart`

**Verbatim output (tail):**

```
00:00 +2 -2: trackpad-kind scroll (a Chromium/WebKit browser trackpad) pans by -scrollDelta under wheelZooms [E]
  Test failed. See exception logs above.
  The test description was: pans by -scrollDelta under wheelZooms
  
00:00 +2 -2: trackpad-kind scroll (a Chromium/WebKit browser trackpad) pans by -scrollDelta under wheelPans
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: a numeric value within <1e-9> of <-30>
  Actual: <30.0>
   Which:  differs by <60.0>
...
This was caught by the test expectation on the following line:
  .../test/camera_gesture_signal_test.dart line 95
The test description was:
  pans by -scrollDelta under wheelPans
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +2 -3: trackpad-kind scroll (a Chromium/WebKit browser trackpad) pans by -scrollDelta under wheelPans [E]
  Test failed. See exception logs above.
  The test description was: pans by -scrollDelta under wheelPans
  
00:00 +2 -3: modifier held Control Left + mouse scroll zooms about the pointer under wheelZooms
00:00 +3 -3: modifier held Control Left + mouse scroll zooms about the pointer under wheelPans
00:00 +4 -3: modifier held Meta Left + mouse scroll zooms about the pointer under wheelZooms
00:00 +5 -3: modifier held Meta Left + mouse scroll zooms about the pointer under wheelPans
00:00 +6 -3: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelZooms
00:00 +7 -3: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelPans
00:00 +8 -3: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) a scale below 1 zooms out
00:00 +9 -3: Some tests failed.

Failing tests:
  .../test/camera_gesture_signal_test.dart: mouse-kind scroll, no modifier wheelPans: pans by -scrollDelta and does not zoom
  .../test/camera_gesture_signal_test.dart: trackpad-kind scroll (a Chromium/WebKit browser trackpad) pans by -scrollDelta under wheelPans
  .../test/camera_gesture_signal_test.dart: trackpad-kind scroll (a Chromium/WebKit browser trackpad) pans by -scrollDelta under wheelZooms
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/camera_gesture_detector.dart` — `git status --short` clean.

**Verdict: KILLED**, exactly as ruled: the trackpad-kind scroll now pans by
`+30` where `-30` is expected (the mouse-kind `wheelPans` case, also
failing, is the `+120`/`-120` pair the row names).

---

## M-01n — divide the per-event scale event by the running trackpad value

**File:** `lib/src/camera_gesture_detector.dart`, `_onSignal`, the
`PointerScaleEvent` branch

**Diff applied:**

```diff
-      camera.zoomAt(event.localPosition, event.scale);
-      return;
+      camera.zoomAt(event.localPosition, event.scale / _gestureZoom);
+      _gestureZoom = event.scale;
+      return;
```

**Command:** `CI=true flutter test test/camera_gesture_signal_test.dart`

**Verbatim output (tail):**

```
00:00 +9 -1: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelZooms [E]
  Test failed. See exception logs above.
  The test description was: zooms by the event scale about the pointer, compounding, under wheelZooms
  
00:00 +9 -1: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelPans
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: a numeric value within <1e-9> of <1.728>
  Actual: <1.2>
   Which:  differs by <0.528>
...
This was caught by the test expectation on the following line:
  .../test/camera_gesture_signal_test.dart line 157
The test description was:
  zooms by the event scale about the pointer, compounding, under wheelPans
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +9 -2: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelPans [E]
  Test failed. See exception logs above.
  The test description was: zooms by the event scale about the pointer, compounding, under wheelPans
  
00:00 +9 -2: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) a scale below 1 zooms out
00:00 +10 -2: Some tests failed.

Failing tests:
  .../test/camera_gesture_signal_test.dart: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelPans
  .../test/camera_gesture_signal_test.dart: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelZooms
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/camera_gesture_detector.dart` — `git status --short` clean.

**Verdict: KILLED**, exactly as ruled: three raw `1.2` events compound to
`1.728` under the correct (undivided) code; under the mutation the second
and third events divide by the *previous* event's own value
(`1.2 / 1.2 == 1.0`), so only the first application (`1.2 / 1.0`) ever moves
the scale — the ratio reads `1.2` where `1.728` is expected.

---

## M-01o — no at-bound early return

**File:** `lib/src/camera_controller.dart`, `zoomAt`

**Diff applied:**

```diff
     if (f > 1.0) {
-      if (_tolerance.compare(current, maxScale) >= 0) return;
       if (_tolerance.compare(current * f, maxScale) > 0) f = maxScale / current;
     } else if (f < 1.0) {
-      if (_tolerance.compare(current, minScale) <= 0) return;
       if (_tolerance.compare(current * f, minScale) < 0) f = minScale / current;
     }
```

**Command:** `CI=true flutter test test/camera_controller_test.dart`

**Verbatim output (tail):**

```
00:00 +14: CameraController bounds a zoom that stays inside the bounds is not clamped
00:00 +15: CameraController bounds at a bound, pushing further does not notify
00:00 +15 -1: CameraController bounds at a bound, pushing further does not notify [E]
  Expected: <0>
    Actual: <2>
  at rest on maxScale
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/camera_controller_test.dart 206:7              main.<fn>.<fn>
  
00:00 +15 -1: CameraController bounds zoomAt still ignores a singular factor with bounds set
00:00 +16 -1: Some tests failed.

Failing tests:
  .../test/camera_controller_test.dart: CameraController bounds at a bound, pushing further does not notify
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/camera_controller.dart` — `git status --short` clean.

**Verdict: KILLED**, exactly as ruled: with the at-bound guard gone, pushing
further from `maxScale` still reassigns `value` (even though the resulting
scale is unchanged) and `ValueNotifier` notifies unconditionally on
assignment — `notifications` reads `2` where `0` is expected.

---

## M-01p — ignore the pointer `kind`

**File:** `lib/src/camera_gesture_detector.dart`, `_onSignal`

**Diff applied:**

```diff
     final action = keyboard.isControlPressed || keyboard.isMetaPressed
         ? ScrollSignalAction.zoom
-        : event.kind == PointerDeviceKind.trackpad
-            ? ScrollSignalAction.pan
-            : policy.mouseWheel;
+        : policy.mouseWheel;
```

**Command:** `CI=true flutter test test/camera_gesture_signal_test.dart`

**Verbatim output (tail):**

```
00:00 +3: trackpad-kind scroll (a Chromium/WebKit browser trackpad) pans by -scrollDelta under wheelZooms
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: a numeric value within <1e-9> of <-30>
  Actual: <-4.9090909090914465>
   Which:  differs by <25.090909090908553>
...
This was caught by the test expectation on the following line:
  .../test/camera_gesture_signal_test.dart line 95
The test description was:
  pans by -scrollDelta under wheelZooms
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +3 -1: trackpad-kind scroll (a Chromium/WebKit browser trackpad) pans by -scrollDelta under wheelZooms [E]
  Test failed. See exception logs above.
  The test description was: pans by -scrollDelta under wheelZooms
  
00:00 +3 -1: trackpad-kind scroll (a Chromium/WebKit browser trackpad) pans by -scrollDelta under wheelPans
00:00 +4 -1: modifier held Control Left + mouse scroll zooms about the pointer under wheelZooms
00:00 +5 -1: modifier held Control Left + mouse scroll zooms about the pointer under wheelPans
00:00 +6 -1: modifier held Meta Left + mouse scroll zooms about the pointer under wheelZooms
00:00 +7 -1: modifier held Meta Left + mouse scroll zooms about the pointer under wheelPans
00:00 +8 -1: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelZooms
00:00 +9 -1: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelPans
00:00 +10 -1: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) a scale below 1 zooms out
00:00 +11 -1: Some tests failed.

Failing tests:
  .../test/camera_gesture_signal_test.dart: trackpad-kind scroll (a Chromium/WebKit browser trackpad) pans by -scrollDelta under wheelZooms
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/camera_gesture_detector.dart` — `git status --short` clean.

**Verdict: KILLED**, exactly as ruled: under `wheelZooms`, a trackpad-kind
scroll now zooms (`policy.mouseWheel == zoom`) instead of panning
unconditionally — `after.dx - before.dx` reads `-4.9` (a zoom artefact) where
the pan `-30` is expected.

---

## M-01q — `forBrowser` ignores Firefox

**File:** `lib/src/gesture_policy.dart`, `forBrowser`

**Diff applied:**

```diff
   static GesturePolicy forBrowser({required bool firefox}) =>
-      firefox ? wheelPans : wheelZooms;
+      wheelZooms;
```

**Command:** `CI=true flutter test test/gesture_policy_test.dart`

**Verbatim output (in full):**

```
00:00 +0: loading .../test/gesture_policy_test.dart
00:00 +0: wheelZooms: a mouse-kind scroll zooms, 1.1 per notch, middle drag
00:00 +1: wheelPans: a mouse-kind scroll pans; the rest is the same
00:00 +2: forBrowser: Firefox gets wheelPans, every other engine wheelZooms
00:00 +2 -1: forBrowser: Firefox gets wheelPans, every other engine wheelZooms [E]
  Expected: same instance as <Instance of 'GesturePolicy'>
    Actual: <Instance of 'GesturePolicy'>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gesture_policy_test.dart 24:5                  main.<fn>
  
00:00 +2 -1: forPlatform on the VM is wheelZooms
00:00 +3 -1: Some tests failed.

Failing tests:
  .../test/gesture_policy_test.dart: forBrowser: Firefox gets wheelPans, every other engine wheelZooms
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/gesture_policy.dart` — `git status --short` clean.

**Verdict: KILLED**, exactly as ruled: `GesturePolicy.forBrowser(firefox: true)`
no longer returns `same(GesturePolicy.wheelPans)`.

---

## M-01r — no `dy == 0` guard on the zoom arm

Added by the final review (whole-branch, post-Task-10 fix wave), not the
original sixteen: a horizontal-only wheel notch (a tilt wheel, or a
horizontal mouse scroll) reports `scrollDelta.dy == 0`, and the zoom arm's
`dy < 0 ? wheelZoomStep : 1 / wheelZoomStep` took the `else` branch for it,
zooming out on a signal with no zoom direction. Fixed with a guard, witnessed
in `camera_gesture_signal_test.dart`'s `'mouse-kind scroll, no modifier'`
group.

**File:** `lib/src/camera_gesture_detector.dart`, `_onSignal`,
`ScrollSignalAction.zoom` case

**Diff applied:**

```diff
       case ScrollSignalAction.zoom:
-        // A horizontal-only signal has no zoom direction; it is not an
-        // unmarked zoom-out.
-        if (event.scrollDelta.dy == 0) return;
         // Scroll up is negative dy on every platform Flutter reports.
         camera.zoomAt(
```

**Command:** `CI=true flutter test test/camera_gesture_signal_test.dart`

**Verbatim output (tail):**

```
  Actual: Transform2:<Transform2(3.454545454545454, 0.0, 0.0, -3.454545454545454,
-3439.090909090909, 7152.727272727273)>

When the exception was thrown, this was the stack:
#4      main.<anonymous closure>.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-01-app-skeleton/packages/jet_cad_2d_flutter/test/camera_gesture_signal_test.dart:86:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-01-app-skeleton/packages/jet_cad_2d_flutter/test/camera_gesture_signal_test.dart line 86
The test description was:
  wheelZooms: a horizontal-only notch does nothing
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +3 -1: mouse-kind scroll, no modifier wheelZooms: a horizontal-only notch does nothing [E]
  Test failed. See exception logs above.
  The test description was: wheelZooms: a horizontal-only notch does nothing
  
00:00 +3 -1: trackpad-kind scroll (a Chromium/WebKit browser trackpad) pans by -scrollDelta under wheelZooms
00:00 +4 -1: trackpad-kind scroll (a Chromium/WebKit browser trackpad) pans by -scrollDelta under wheelPans
00:00 +5 -1: modifier held Control Left + mouse scroll zooms about the pointer under wheelZooms
00:00 +6 -1: modifier held Control Left + mouse scroll zooms about the pointer under wheelPans
00:00 +7 -1: modifier held Meta Left + mouse scroll zooms about the pointer under wheelZooms
00:00 +8 -1: modifier held Meta Left + mouse scroll zooms about the pointer under wheelPans
00:00 +9 -1: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelZooms
00:00 +10 -1: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelPans
00:00 +11 -1: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) a scale below 1 zooms out
00:00 +12 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-01-app-skeleton/packages/jet_cad_2d_flutter/test/camera_gesture_signal_test.dart: mouse-kind scroll, no modifier wheelZooms: a horizontal-only notch does nothing
```

**Restore:** `cp /tmp/mut.bak lib/src/camera_gesture_detector.dart` — `git status --short` clean apart from the intended `camera_gesture_detector.dart` and `camera_gesture_signal_test.dart` changes.

**Verdict: KILLED** — without the guard, `camera.value.worldToScreenMatrix`
is no longer `same` as before the horizontal-only notch: the mutant zooms out
by `1 / wheelZoomStep` on a signal that carries no zoom direction.

---

## E-01e′ — `forPlatform` ignores `kIsWeb` (declared EQUIVALENT, spec D2)

**File:** `lib/src/gesture_policy.dart`, `forPlatform`

**Diff applied:**

```diff
-  factory GesturePolicy.forPlatform() =>
-      kIsWeb ? forBrowser(firefox: isFirefoxBrowser()) : wheelZooms;
+  factory GesturePolicy.forPlatform() => wheelZooms;
```

**Command:** `CI=true flutter test` (the whole package suite, as the row specifies)

**Verbatim output (tail — GREEN as declared, only the five pre-existing golden failures, unrelated to gestures):**

```
00:09 +697 ~1 -5: /Users/.../packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:09 +702 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
EXIT=1
```

(`EXIT=1` is the five known golden-drift failures, out of scope per
`CLAUDE.md`; every `camera_gesture_*` and `camera_controller_test.dart` and
`gesture_policy_test.dart` case in the same run passed, including
`camera_gesture_signal_test.dart`'s `wheelZooms`/`wheelPans` groups.)

**Restore:** `cp /tmp/mut.bak lib/src/gesture_policy.dart` — `git status --short` clean.

**Verdict: EQUIVALENT (declared, spec D2).** `kIsWeb` is a compile-time
constant that is `false` on every platform `flutter test` runs on (the VM);
`GesturePolicy.forPlatform()` therefore always evaluates its `else` arm,
`wheelZooms`, both before and after this mutation. The suite never calls
`GesturePolicy.forPlatform()` expecting the web arm — every widget test
injects a `GesturePolicy` explicitly (`wheelZooms` or `wheelPans`) via
`pumpDetector`, and `gesture_policy_test.dart`'s own
`'forPlatform on the VM is wheelZooms'` test asserts exactly the branch this
mutation leaves untouched. The web arm (`forBrowser(firefox: isFirefoxBrowser())`)
is covered instead by the browser-based criterion this plan's spec assigns
to manual verification in Chrome/Safari and Firefox, not by `flutter test`.
Fired and its green run recorded, not skipped, per the same "recorded rather
than deleted" rule Plan F's E-F1 and M-F10 follow.

---

## The two greps (spec invariant 5)

```
$ grep -rn "kIsWeb" packages/jet_cad_2d_flutter/lib apps/floor_planner/lib
packages/jet_cad_2d_flutter/lib/src/gesture_policy.dart:1:import 'package:flutter/foundation.dart' show immutable, kIsWeb;
packages/jet_cad_2d_flutter/lib/src/gesture_policy.dart:11:/// rather than a `kIsWeb` it reads.
packages/jet_cad_2d_flutter/lib/src/gesture_policy.dart:13:/// `kIsWeb` is a compile-time constant: a widget that branched on it inline
packages/jet_cad_2d_flutter/lib/src/gesture_policy.dart:64:  /// **The only place `kIsWeb` appears in this package's gesture code.**
packages/jet_cad_2d_flutter/lib/src/gesture_policy.dart:68:      kIsWeb ? forBrowser(firefox: isFirefoxBrowser()) : wheelZooms;

$ grep -rn "dart:ui_web" packages/jet_cad_2d_flutter/lib apps/floor_planner/lib
packages/jet_cad_2d_flutter/lib/src/gesture_policy.dart:65:  /// `isFirefoxBrowser` comes from a conditional import: `dart:ui_web` on
packages/jet_cad_2d_flutter/lib/src/gesture_policy_platform_web.dart:1:import 'dart:ui_web' as ui_web;
packages/jet_cad_2d_flutter/lib/src/gesture_policy_platform_web.dart:3:/// **The only `dart:ui_web` import in this package.**
```

Both greps touch exactly **one file** each — `gesture_policy.dart` for
`kIsWeb`, `gesture_policy_platform_web.dart` for the `dart:ui_web` import —
which is the invariant's substance (the platform branch exists at exactly
one point). The multiple lines per file are the doc comments quoting the
same identifier in prose (including `gesture_policy.dart`'s own comment
*naming* `gesture_policy_platform_web.dart`'s import), not additional
call sites; the only executable uses are the `import` and the ternary at
`gesture_policy.dart:1,68` and the `import 'dart:ui_web'` at
`gesture_policy_platform_web.dart:1`.

---

## Summary

**Seventeen named mutations (M-01a..M-01q, M-01h struck, plus M-01r added by
the final review) fired: 17 killed, 0 survived. M-01b survived on the first
shot (degenerate fixture: the witness repeated the same cumulative `scale`,
and the widget's own exact-equality coalescing guard let only the first
update reach `zoomAt`), and was killed after a fixture fix in its own commit
(round 1) that ramps the pinch witness through three different cumulative
values. One spec-declared-equivalent mutation (E-01e′) fired and its green
run recorded.**

| id | verdict |
|---|---|
| M-01a | KILLED — dx off by 600 at the prior assertion (line 34), not the dy the brief named (line 35); both would catch it |
| M-01b | KILLED (after fixture fix, round 1) — SURVIVED on the first shot (degenerate fixture: repeated `scale: 1.5` never exercised the running division); re-fired against the ramped witness, `Actual: 3.6` where `2.0` is expected |
| M-01c | KILLED — `still.x` (1018.9) off `under.x` (1015.8) |
| M-01d | KILLED — all 10 trackpad tests fail; camera unmoved |
| M-01e | KILLED — `wheelPans` mouse scroll zooms (dy 3.82) instead of panning (-120) |
| M-01f | KILLED — under `wheelPans`, modifier ignored: scale 1.0 where 1.1 |
| M-01g | KILLED — scale ratio 1.0 where 1.728; `PointerScaleEvent` silently dropped |
| M-01i | KILLED — left/right-button drags move the camera; matrix not `same` |
| M-01j | KILLED — scale stays 7.6 (rejected) where 12.0 (landed) is expected |
| M-01k | KILLED — zoom-in returns at once: scale stays 7.6 |
| M-01l | KILLED — scale reaches 76.0 (factor unclamped) where 12.0 is expected |
| M-01m | KILLED — trackpad-kind pan sign flipped: +30 where -30 |
| M-01n | KILLED — compounding scale reads 1.2 where 1.728 |
| M-01o | KILLED — notifications 2 where 0 at rest on a bound |
| M-01p | KILLED — trackpad-kind scroll zooms under wheelZooms instead of panning |
| M-01q | KILLED — `forBrowser(firefox: true)` no longer `same(wheelPans)` |
| M-01r | KILLED — matrix not `same`: a horizontal-only notch (`dy == 0`) zoomed out |
| E-01e′ | EQUIVALENT (spec-declared, D2) — fired, green run recorded; only the five pre-existing golden failures survive the run |

### M-01b, resolved in round 1

See the M-01b section above for the complete trace: why the original
witness could not observe the mutation (a degenerate fixture — repeated,
non-rising cumulative `scale`, and the coalescing guard from Ruling 01-4),
the fixture fix (a rising ramp of cumulative values), and the re-fire that
now kills it (`Actual: 3.6` where `2.0` is expected). The fixture fix landed
in its own commit, separate from this log's update, per the controller's
instructions.
