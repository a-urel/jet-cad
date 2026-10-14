# Task 15 review: PlanCanvas, the shortcut guard, the paint-allocation invariant

Range 29aaea73..a6958db4 (539b0676, 8106dab0, a6958db4). Reviewed from the review package in one pass, plus the focused checks named below.

### Spec Compliance

- ✅ Spec compliant. Every file in the brief's list has its hunk (19 files: 5 lib files new, barrel, plan_controller.dart, 9 ported tests + plan_canvas_test, CV-alloc, fixture). The one extra file, `lib/src/l10n/locale_scope.dart` (+ `PlanController.isDisposed`), is the carried Task 9 item (the locale push skips a disposed controller), pinned by CV-8 (M-CV-8). Not scope creep.
  - P2: `PlanCanvas` takes only `controller` + `rulers/grid/snapping/autofocus` (plan_canvas.dart:94-108); one-canvas debug assert after the frame (:211-236), CV-2 covers two controllers, one canvas, a replaced canvas, and two canvases of one controller; first-frame fit (`fitOnStart: _fitOnStartFor(document)`, :349), CV-1 and CV-3.
  - P4: lock hint, `Key('plan-lock-hint')`, `PlanStrings.lockedHint`, `IgnorePointer`, `Alignment(0, 0.9)`, timer `kLockHintDuration` (:303-311, :359-380); CV-4.
  - R-k: `camera_bounds.dart` reused, not re-ported (plan_canvas_view.dart imports `../controller/camera_bounds.dart`).
  - R-l: `chords.dart`, `plan_shortcut_guard.dart` (`PlanShortcutGuard`, `PlanTextKeys`, `planLetterKeys`, `letterKey`) land here; CV-10 pins the guard through the text entry with a host `CallbackShortcuts` above the canvas, plus a positive control (L reaches the host once the entry closes).
  - Carried: grip drag whose `drag` answers null ends cleanly: CV-9 (positive control commits 900; refused drag: no exception, no undo step, size unchanged by exact `==`, `dragKind == null`, exactly one `(boom, hookFailed)` diagnostic).
  - No change under `packages/jet_cad_2d_flutter`, `jet_cad_2d` or `jet_cad_floor_plan`: checked with `git diff --stat 29aaea73 a6958db4 -- <those paths>` (empty). No `analysis_options.yaml` in the file list.
- Port fidelity, checked by diffing each committed file against its source:
  - `plan_canvas_view.dart` vs `floor_plan/lib/src/planner_view.dart`: only the Step 10 adaptations (rename, `@internal`, `controller` param + field, `TextEntryOverlay(controller:)`, doc words).
  - `text_entry_overlay.dart` vs source: only Step 9's adaptations.
  - `plan_shortcut_guard.dart` vs `shortcut_guard.dart`: the new guard per the brief; `PlanTextKeys`/`_TypingActivator` copied with the rename.
  - `chords.dart` vs `shell_commands.dart:1-61`: header and imports only.
  - `canvas_fixture.dart` vs `palette_fixture.dart`: exactly adaptations 1-5.
- Ported assertions: I extracted every `expect(...)` (whitespace-normalised) from the 8 ported test files and checked each against the source file. Every one that differs is a mechanical rename: `view.` → `c.`/`tester.widget<PlanCanvasView>`, `f.doc` → `f.c.document`, `cameraController` → `camera`, `PlannerView` → `PlanCanvasView`. None was weakened. The extra pumps (A20, A21, the palette `paper()` helper) are fixture changes, as the constraints allow. The sections that were dropped (theme `paperPaletteFor`, invariant 4, the export, the `ServiceView` expectation, D6a, TD1) match the brief's "Not ported" lists.
- ⚠️ Cannot verify from diff:
  - the reported gate run (`+445: All tests passed!`, analyze clean, format exit 0);
  - every mutation red line in the report's table.
  
  I did not re-run them. The controller should spot-check M-CV-alloc-1/-2 and M-CV-2b.

### CV-alloc judgement (CLAUDE.md non-negotiable)

It is adequate, and as strong as the Flutter layer's model allows. The Flutter test (`jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`) reduces "O(1) per flush" to capacity that holds still plus one reused `Paint`. CV-alloc keeps both on the same 4,000-entity corpus. It adds what the plan library can actually break: identity of `DraftCanvasState`, `painter` and `vertices` across a forced `PlanCanvas` rebuild on every frame, with the camera alternating between two poses one pixel apart.

I checked that "same painter" covers every re-attach trigger. `DraftCanvas.didUpdateWidget` (`jet_cad_2d_flutter/lib/src/draft_canvas.dart:442-459`) detaches and re-attaches on any change of document, index, camera or resolver, so `identical(state.painter, painter)` catches each of them.

The premises guard against a vacuous run: 50 selected roots, `totalFlushCount > 0`, `frameTriangleCount > 1000`. The 8106dab0 reorder, with identity checks before the flush premise, is a real improvement in mutant attribution and changes no assertion.

Draw order: untouched. The view is a faithful port and the painter is the Flutter layer's.

### Strengths

- The ports are faithful line for line (verified by diff, not by reading).
- The one-canvas check is deduplicated to one check per controller per frame (`_Shown.checkScheduled`). That fixes a real "Multiple exceptions (2)" problem the brief's version would have had, and M-CV-2a still bites at the renamed site.
- The resolver is rebuilt only when its key changes, on every path: didChangeDependencies, `_onPage`, `_rebind`. A17 and CV-alloc both pin this.
- The tests carry positive controls: CV-9's healthy drag, CV-10's L reaching the host after Escape, CV-1's premise that the nominal camera is not the fit.
- The extra mutants (M-CV-5g, M-CV-10a/b/c) close gaps the brief left.
- The deviations are reported honestly, each with a reason.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

1. **plan_canvas.dart:157-165, :180-196, :303-311: a lock hint that is already `true` when a canvas binds to the controller never clears, and the next refusal cannot clear it either.**
   - Cause: `_onHint` runs only on a change notification, and the canvas is the only code that ever writes `lockHint = false` (I grepped `lib/` for `lockHint`; the only writers of `true` are `plan_controller.dart:479`, `:812` and `guard.dart:292`). So the timer starts only when a canvas *hears* false → true.
   - Reachable paths:
     - a host calls `c.execute(...)` on a locked object before the canvas mounts, or while none is mounted;
     - a refusal lands within 2 s before the canvas is re-created. A responsive layout that swaps Row for Column, or a route pop and push, does this: `dispose` cancels the timer and the new state's `initState` starts none;
     - `didUpdateWidget` swaps controllers while the old one's hint is showing (`_hintTimer?.cancel()` at :188 strands the old controller's `true`).
   - Effect: the banner then shows permanently. A later `PlanLocked` refusal writes `true` over `true`, which notifies nothing, so no timer ever starts again.
   - Fix: call `_onHint()` after `_c.lockHint.addListener(_onHint)` in `initState` and in the controller-swap branch of `didUpdateWidget`. Pin it with a CV-4 variant: set `lockHint` true before pumping the canvas, then expect it cleared after `kLockHintDuration`. Mutant: delete the new call.

#### Minor (Nice to Have)

1. **plan_canvas.dart:304-311: a second refusal while the hint shows does not restart the 2 s.** `ValueNotifier` does not notify on an equal value, so the hint clears 2 s after the *first* refusal. The implementer raised this as Concern 1. It matches the brief's wording, but a refusal at 1.9 s gets a 0.1 s hint. Fixing it needs a counter or an event stream on the controller, which is outside this task.
2. **plan_canvas.dart:195: on a controller swap, the old controller keeps the `snappingAllowed` value this canvas wrote.** With `snapping: false`, the old controller's tools stay snap-less after it leaves the canvas.
3. **CV-1 (plan_canvas_test.dart, `pageFit`): "inside the zoom bounds" is asserted only through `clampCameraScale` on both sides.** If the clamp is an identity for this 1:20 fixture at 1200x700, dropping the clamp in the view would stay green. Either add a premise that the clamp changed nothing or bound something, or drop the claim from the test name.
4. **CV-alloc's header claims rebuilds from "a controller notification, a theme, a parent's build", but only a parent-style `markNeedsBuild` is exercised.** A theme toggle frame (didChangeDependencies → `_nextResolver` returns null) would make the claim tested. The current coverage is otherwise sufficient.
5. **plan_canvas.dart:342: `planPaperPaletteFor(paper, _theme)` runs per build.** With a themed selection colour this returns a fresh `withSelection` palette each build. That is O(1) per build, not per entity, but it can make the overlay repaint on every PlanCanvas rebuild if its `shouldRepaint` compares by identity. Caching it alongside the resolver key would be cleaner.
6. **plan_shortcut_guard.dart (`letterKey`): no `assert` that `letter` is a single `'A'..'Z'`.** A kit letter in lower case (Task 16) would silently map to the wrong key id.
7. **Leftover "shell" wording:**
   - `PlanTextKeys` doc: "[PlanShortcutGuard] does for the shell's keys";
   - `plan_canvas_view.dart`: "the shell's nominal fit" (reported in deviation 8).
8. **plan_canvas.dart:320: `_rebind()` from `build` has side effects (listener moves).** It is brief-mandated, and it is idempotent because `_document` is updated, but it is fragile if `build` is ever made to run speculatively.

### Assessment

**Task quality:** Needs fixes

**Reasoning:** The ports, tests and invariant are faithful and well-built, and CV-alloc measures the right composition property against the Flutter layer's model. The lock-hint timer, though, starts only on an observed false → true edge, so an ordinary remount or a pre-mount refusal leaves the P4 hint stuck on permanently. The fix is a one-line call plus one test.
