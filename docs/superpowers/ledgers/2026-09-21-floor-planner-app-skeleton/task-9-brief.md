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

