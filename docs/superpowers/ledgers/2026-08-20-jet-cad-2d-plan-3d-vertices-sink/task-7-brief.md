### Task 7: The harness picks a backend

`useVertices` is gone, so the harness no longer compiles. It gets the control
Phase C needs: a backend, not a sink toggle.

**Files:**
- Modify: `apps/dev_harness_2d/lib/main.dart`
- Modify: `apps/dev_harness_2d/integration_test/frame_timing_test.dart`

**Interfaces:**
- Consumes: `RenderBackend`, `defaultRenderBackend`, `DraftCanvasState.resolvedBackend`.
- Produces: `kBackend`, and a `backend=` field in every rig's printed block.

- [ ] **Step 1: Replace the define**

In `apps/dev_harness_2d/lib/main.dart`, delete `kVertices` and add:

```dart
/// Which sink the harness draws through: `canvas`, `vertices`, or unset for
/// the platform's own choice.
///
/// **A `String.fromEnvironment`, and it stays one.** Plan 3c lost a full device
/// run to `bool.fromEnvironment('TEXT')` reading `--dart-define=TEXT=1` as
/// false while printing entirely plausible numbers; the only thing that caught
/// it was a line printing `corpus=on/off`. A string has no such hazard, and an
/// unrecognised value throws at startup rather than falling back to something
/// that looks fine.
final RenderBackend? kBackend = switch (
    const String.fromEnvironment('BACKEND', defaultValue: '')) {
  '' => null,
  'canvas' => RenderBackend.canvas,
  'vertices' => RenderBackend.vertices,
  final other => throw StateError(
      'BACKEND must be canvas, vertices or unset; got "$other"'),
};
```

and pass it: `backend: kBackend` where `useVertices: kVertices` was.

- [ ] **Step 2: Report what was resolved, not what was asked**

In `apps/dev_harness_2d/integration_test/frame_timing_test.dart`, extend the
`boot` record and the `onReady` signature to carry
`RenderBackend resolvedBackend` from `DraftCanvasState.resolvedBackend`, and
replace `printVerticesCounters`:

```dart
/// The backend actually used, and the vertices counters when it was that one.
///
/// The resolved value and not the define: a run that asked for `vertices` and
/// silently got `canvas` would otherwise report canvas numbers under a
/// vertices heading, which is the shape of the mistake Plan 3c's `TEXT` define
/// made.
void printBackend(RenderBackend backend, VerticesDrawSink? vertices) {
  if (vertices == null) {
    print('  backend=${backend.name}');
    return;
  }
  print('  backend=${backend.name} '
      'triangles=${vertices.frameTriangleCount} '
      'drawVerticesCalls=${vertices.totalFlushCount}');
}
```

Call it in all three rigs where `printVerticesCounters` was called.

- [ ] **Step 3: Analyze and format**

```sh
cd apps/dev_harness_2d && flutter analyze && dart format --output=none --set-exit-if-changed lib integration_test
```

Expected: no issues.

- [ ] **Step 4: Prove the define is wired, on a device**

Two runs, and the printed `backend=` must differ between them. This is the
step that would have caught Plan 3c's `TEXT` bug.

```sh
cd apps/dev_harness_2d
for B in canvas vertices; do
  echo "### $B"
  flutter drive --driver=test_driver/integration_test.dart \
    --target=integration_test/frame_timing_test.dart --profile -d macos \
    --dart-define=TEXT=true --dart-define=ENTITIES=10000 \
    --dart-define=RIG=pan --dart-define=BACKEND=$B 2>&1 \
    | grep -E "R2 |build |raster |backend="
done
cd /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike
git checkout -- apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj
```

Expected: `backend=canvas` in the first block and `backend=vertices` in the
second. **If both read the same, stop** — the define is not wired and every
number Phase C would produce is worthless.

- [ ] **Step 5: Run every gate green, then commit**

```sh
cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && flutter analyze && dart format --output=none --set-exit-if-changed lib integration_test
```

```bash
git add apps/dev_harness_2d
git commit -m "feat: the harness selects a backend rather than toggling a sink

BACKEND=canvas|vertices, unset for the platform default. A String define and
not a bool one: Plan 3c lost a device run to bool.fromEnvironment reading
TEXT=1 as false while printing plausible numbers, and an unrecognised value
here throws at startup instead.

Every rig prints the *resolved* backend, so a run that asked for one and got
the other cannot report the wrong numbers under the right heading."
```

---

# Phase B — the apparatus

