# Review — `docs/superpowers/specs/2026-09-21-floor-planner-app-skeleton-design.md`

Three reviewers: Claude (Fable 5.1), Codex (gpt-5.5, `codex exec --sandbox read-only`), Copilot CLI (`copilot -p`). Every finding below was re-verified by Claude against `main@a713589` and the installed SDK (Flutter **3.47.2**, at `/opt/homebrew/Caskroom/flutter/3.27.3/flutter`). Findings the CLIs raised that did not survive verification are listed at the end. Repo untouched by all three (`git status` and a `diff` of the spec against a pre-review copy confirm).

Verdict: **not ready to plan from.** Two blockers go to the spec's central web argument and to its own load-bearing mutant; the rest are majors a plan would otherwise have to invent answers for.

## Blockers

**B1. "On web a trackpad scroll and a wheel notch are the same event and cannot be distinguished" is false as stated.** (Codex; verified)
The engine classifies every browser `wheel` event as mouse or trackpad with a delta heuristic (`pointer_binding.dart:678-735`, `_isTrackpadEvent`, `_isAcceleratedMouseWheelDelta`) and emits the `PointerScrollEvent` with `kind: PointerDeviceKind.trackpad` or `.mouse` (`:735-740`). Flutter's own `InteractiveViewer` branches on exactly that (`interactive_viewer.dart:884-891`: trackpad scroll pans, wheel scales). The heuristic is explicitly non-standard and returns `false` on Firefox. So the honest statement is: *distinguishable on Chromium/WebKit by a heuristic, never on Firefox*. The spec's D2 rationale, the platform table, the "mirror image of `fc05076`" framing, and the human's decision ("web-native: bare scroll pans") were all made on the wrong premise. The decision may still stand as a product choice (Figma/Miro do it), but it must be re-taken with the real options on the table: (a) web-native, ignore `kind`; (b) CAD-native on web via `kind`, degrading to (a) on Firefox. Either way the web policy needs tests for both `kind` values.

**B2. M-01e is equivalent under the gate it is supposed to die under.** (Copilot and Codex, independently; verified)
M-01e mutates `GesturePolicy.forPlatform()` to return `desktop` unconditionally. But D2 says tests inject `GesturePolicy.desktop`/`.web` explicitly, so the suite never calls `forPlatform()`; and under VM `flutter test` `kIsWeb` is a compile-time `false` (`foundation/constants.dart:83`) so even a test that did call it sees the same answer as the mutant. The spec's own sentence — "if it survives, D2 bought nothing" — is therefore true and unfixable as written. Fix: mutate the seam that *is* under test (the widget ignoring its injected policy), and either add a `flutter test --platform chrome` gate for a one-line `forPlatform()` test or declare M-01e equivalent with the argument written down.

## Major

**M1. Exact `==` on the clamped scale cannot hold.** (Claude and Copilot; verified)
Invariant 6 and criterion 8 call the clamp comparison "stored value: exact". `ViewportTransform.scale` is `sqrt(|det|)` of a matrix (`transform2.dart:87`), and the clamp lands there via `zoomAt(focus, bound / scale)`: a three-matrix product, a determinant, a square root. That is a derived float and will miss the bound by ulps. Either rebuild the matrix *from* the bound (store it) or give criterion 8 a tolerance. As written the bound tests are red on day one or pass by luck.

**M2. "No notification of any kind" at the bound is untested and currently false.** (Codex; verified)
`ViewportTransform` has no `==` override (identity equality, `viewport_transform.dart:14-15`); `CameraController` is a `ValueNotifier`, which notifies whenever the new value `!=` the old. A clamped zoom with adjusted factor 1.0 still constructs a new `ViewportTransform` and repaints. Add an early return when the adjusted factor is exactly 1.0 and a listener-count test for a repeated out-of-range zoom at each bound.

**M3. `PointerPanZoomUpdateEvent` already has `panDelta`/`localPanDelta`.** (Claude and Codex; verified, `events.dart:2315-2317`)
Finding 1's "pan now needs the same running-value subtraction that zoom already has" and the `_gesturePan` state in Architecture are wrong; only `scale` lacks a delta. Use `localPanDelta`, drop `_gesturePan`, rephrase M-01a as "read `localPan` where `localPanDelta` is meant" (still fires).

**M4. Web scroll-to-pan has no sign rule, and the differential test cannot catch a shared sign error.** (all three)
D3 says a bare web scroll "pans", never which way. Desktop `pan` is finger motion; wheel `scrollDelta` is content-scroll (opposite sign); Figma/Miro convention is `panBy(-scrollDelta)`. The differential asserts only that the two policies agree, so both wrong together stays green — and, as Copilot notes, feeding equal numbers to both arms only proves `panBy` is linear. Write the mapping into D3 and add an absolute-direction assertion for the web arm.

**M5. "ctrl / cmd + scroll zooms" on web is three different code paths, and the spec names none.** (all three; verified `pointer_binding.dart:766-780`)
The engine emits `PointerScaleEvent` for DOM `ctrlKey` — *except on macOS when the physical Control key is down* (`ignoreCtrlKey`), where it emits a plain `PointerScrollEvent`; it never reads `metaKey`. So: (a) Windows/Linux browsers and every pinch → `PointerScaleEvent`; (b) macOS browser + real ctrl → `PointerScrollEvent` + `HardwareKeyboard.isControlPressed`; (c) cmd anywhere → `PointerScrollEvent` + `HardwareKeyboard.isMetaPressed`. `PointerScrollEvent` carries no modifier fields and `TestPointer.scroll` cannot attach any, so the (b)/(c) tests need `sendKeyDownEvent` first. M-01f only reaches (b)/(c). Spell all three out or drop cmd.

**M6. `PointerScaleEvent.scale` is `exp(-deltaY/200)` per event, not cumulative, and a mouse notch through it is ~1.65×.** (Claude and Copilot; verified `:786`)
A Windows-Chrome wheel notch is `deltaY ≈ 100`, so ctrl+wheel zooms 1.65× per notch against the desktop wheel's 1.1×; and the value is per-event, so the desktop `factor / _gestureZoom` pattern must not be applied to it. `wheelZoomStep` is dead on the web policy. Decide raw-vs-normalised and say which path is cumulative.

**M7. The new app has no gate, no workspace entry, no web scaffold.** (all three)
Criterion 11 says "six gate commands" (the two packages); criterion 10 covers the harness. `apps/floor_planner` gets no analyze/format/test/build command, is not in the root `pubspec.yaml` workspace (`pubspec.yaml:5-10`, roadmap decision 1 requires it), and criterion 2 needs a `web/` scaffold. Plan F's gate was nine commands; this one should list every command explicitly.

**M8. "Default 1440×900" and "no custom Swift" conflict unless the XIB is named.** (Codex; verified)
The generated `MainFlutterWindow.swift` uses `self.frame` from the XIB, and the template XIB's `contentRect` is 800×600 (`MainMenu.xib:335`). 1440×900 means editing `MainMenu.xib`, which is not Swift but is not "the generated files untouched" either. Say so.

## Minor

**m1. Evidence-of-record version mislabelled.** (all three) Spec says "Flutter 3.27.3" — that is the cask directory. `bin/cache/flutter.version.json` says 3.47.2, and the cited line numbers match 3.47.2. Fix the label.

**m2. `honoursPanZoomEvents = false` is a non-behaviour.** (Claude) The engine never emits `PointerPanZoom*` on web, so ignoring them there is invisible to users and only hurts if the engine ever adds them. Handle under both policies and drop M-01h, or write down why a deliberately dead arm is wanted.

**m3. D3 desktop "ctrl/cmd + scroll → zoom" is ambiguous.** (Claude and Copilot) A modified trackpad scroll on desktop is still `PointerPanZoomUpdate`; a modified wheel is already zoom. Say which is meant, or drop the row.

**m4. Drifting pinch.** (Claude) A `PointerPanZoomUpdate` with both `panDelta ≠ 0` and `scale ≠ 1` — the table splits these; say "apply both", as the harness does.

**m5. `flutter build web` has never been attempted against `jet_cad_2d_flutter`.** (Claude) It compiles for web only because `flutter_scene`'s shim conditionally exports a WebGL2 backend (`flutter_scene-0.23.0/lib/src/gpu/gpu.dart`). Criterion 2 is the first attempt; say so, so a failure is not read as a regression.

**m6. D5 disagrees with itself:** "a few hundred entities" vs "at the target scale (500–5,000)". (Claude)

**m7. Closing paragraph is stale against the working tree.** (Codex) Uncommitted `STATUS.md:890-897` already records the web decision; the spec still describes STATUS as saying "conditional".

## Nit

- Middle-button drag on web: Chromium starts autoscroll on middle-click unless `mousedown` default is prevented; unverified whether the engine does. Add to criterion 12's browser list. (Claude)
- Engine `preventDefault()`s every wheel event unless a widget explicitly allows platform default (`pointer_binding.dart:875-877`), so criterion 12's "ctrl+scroll does not zoom the page" is already given for a full-page app. (Claude)

## Raised by a CLI, checked, not upheld

- Codex: "Windows/Linux desktop behaviour asserted but unverified." Verified true by Claude: Windows sends pan/zoom via DirectManipulation (`flutter_windows_view.cc:318-332`), Linux via `GDK_SOURCE_TOUCHPAD` (`fl_scrolling_manager.cc:112-137`). The table row is correct; the deferral stands.
- Copilot: "cmd is never read at all" as a blocker. Engine-true, but the widget reads `HardwareKeyboard`; folded into M5 as a specification gap, not an impossibility.

## Verified true, no action

Harness refs 1146-1157 / 1201-1233 / 1203 / 1214 / 1228; roadmap refs :40 :42 :109 :112 :130 :137 :139; `events.dart:2085/2094`; `deltaMode` normalisation `:742-760`; both wheel branches `change: hover`; `PointerPanZoom*` absent from `pointer_binding.dart`; `debugSetGpuAvailable` is the barrel's one `show`; `ViewportTransform.scale` is `scaleMagnitude`; `resolveBackend` at `render_backend.dart:74`; `TestPointer.scale()` and `panZoomStart()` exist.
