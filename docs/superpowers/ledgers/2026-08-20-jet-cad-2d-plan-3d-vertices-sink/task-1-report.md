# Task 1 report — `RenderBackend`, one resolution point

**Executed inline by the controller.** The dispatched implementer subagent was
rejected by the human mid-flight; it had already written the `lib/` changes to
the worktree before the rejection landed. The controller verified that diff
hunk-by-hunk against the brief, established the RED evidence the aborted
dispatch never recorded, finished the task and committed it.

## What was implemented

Exactly the brief's nine steps.

- `lib/src/render_backend.dart` (new): `enum RenderBackend { canvas, vertices }`
  and `RenderBackend defaultRenderBackend() => kIsWeb ? canvas : vertices`.
- `lib/src/draft_canvas.dart`: `bool useVertices` → `RenderBackend? backend`;
  `late RenderBackend resolvedBackend` on the state, assigned once in
  `_attach`; `widget.backend != oldWidget.backend` added to
  `didUpdateWidget`'s condition.
- `lib/jet_cad_2d_flutter.dart`: `export 'src/render_backend.dart';` in
  alphabetical position.
- `lib/src/vertices_draw_sink.dart`: comment only — the stale "Points, circles,
  arcs and text still go to CanvasDrawSink" bullet replaced, and the
  authoritative-backend bullet added.
- `test/render_backend_test.dart` (new): the brief's five tests verbatim.

## Beyond the brief, and why

1. **`draft_canvas.dart:220` still referenced the deleted parameter** —
   `/// Spike, null in every default build. See `DraftCanvas.useVertices`.` on
   `_DraftCustomPainter.vertices`. A dangling doc reference to a symbol the
   same commit deletes. Replaced with a pointer to `DraftCanvas.backend`.
   The brief's step 4 lists the constructor and the state field but not this
   third site.

2. **The two golden ladders now name the canvas backend.** Flipping the
   platform default to `vertices` turned the golden suite red: `dash_ladder`
   and `text_ladder` build a `DraftCanvas` without naming a backend, so they
   began rendering through `VerticesDrawSink` under software Skia — 10
   failures at 0.8-0.9% pixel diff. `stroke_width_golden_test.dart` was
   unaffected because it drives `CanvasDrawSink` directly.

   Fixed by passing `backend: RenderBackend.canvas` at both sites. This is a
   strict subset of Task 10, which says the existing 14 PNGs "keep their
   fixtures and their assertions and become the **canvas** backend's suite".
   The alternative — declaring the golden suite out of gate until Task 10 —
   would leave the repository's regression net down for nine tasks.

## TDD evidence

**RED.** The implementation existed on disk before the controller took over,
so RED was established by backing the four files up, restoring the 548fa8e
versions, running the test, and restoring from the backup in the same script
(`trap restore EXIT`; no `git checkout`, per the global constraint).

```
$ cd packages/jet_cad_2d_flutter && flutter test test/render_backend_test.dart
00:00 +0: loading .../test/render_backend_test.dart
test/render_backend_test.dart:9:6: Error: Type 'RenderBackend' not found.
    {RenderBackend? backend}) async {
     ^^^^^^^^^^^^^
test/render_backend_test.dart:27:11: Error: No named parameter with the name 'backend'.
          backend: backend),
          ^^^^^^^
lib/src/draft_canvas.dart:55:9: Context: Found this candidate, but the arguments don't match.
  const DraftCanvas({
        ^^^^^^^^^^^
test/render_backend_test.dart:37:12: Error: Method not found: 'defaultRenderBackend'.
    expect(defaultRenderBackend(),
           ^^^^^^^^^^^^^^^^^^^^
RESTORED
```

This is the brief's predicted failure: `Undefined name 'defaultRenderBackend'`
and `No named parameter with the name 'backend'`.

**GREEN.**

```
$ flutter test test/render_backend_test.dart
00:00 +5: All tests passed!
```

## Full gate

```
$ cd packages/jet_cad_2d && dart test
00:03 +720: All tests passed!
$ dart analyze
No issues found!
$ dart format --output=none --set-exit-if-changed .
Formatted 105 files (0 changed) in 0.19 seconds.

$ cd ../jet_cad_2d_flutter && flutter test
00:02 +185 ~1: All tests passed!
$ flutter analyze
No issues found! (ran in 1.0s)
$ dart format --output=none --set-exit-if-changed .
Formatted 37 files (0 changed) in 0.07 seconds.
```

185 = the previous 180 plus this task's 5. One skip (`~1`) is pre-existing.

`apps/dev_harness_2d` is red — it still passes `useVertices:` — and is out of
gate until Task 7 repairs it, per the controller's pre-flight ruling.

## Files changed

- Created: `packages/jet_cad_2d_flutter/lib/src/render_backend.dart`
- Created: `packages/jet_cad_2d_flutter/test/render_backend_test.dart`
- Modified: `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart`
- Modified: `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`
- Modified: `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`
- Modified: `packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart`
- Modified: `packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart`

Commit: `2a7b762`.

## Concerns

- The class comment's first "What this is not" bullet still reads **"No joins
  and no caps"**, which stays true until Task 4 lands and false the moment it
  does. Task 4 must revise it.
- `resolvedBackend` is `late` and non-final, assigned in `_attach`, matching
  `sink` and `painter` beside it. A read before `initState` throws rather than
  returning a wrong backend, which is the failure mode worth having.
