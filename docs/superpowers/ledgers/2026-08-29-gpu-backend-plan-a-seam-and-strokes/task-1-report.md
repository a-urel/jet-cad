# Task 1 Report: The facade, and a fallback that is testable

## What I implemented

Exactly what the brief specified, verbatim:

1. **`packages/jet_cad_2d_flutter/pubspec.yaml`** — added `flutter_scene: ^0.23.0`
   under `dependencies:`, with the brief's comment explaining why the
   dependency exists (the internal `flutter_gpu` shim, not the scene graph).
2. **`packages/jet_cad_2d_flutter/lib/src/gpu/gpu_facade.dart`** (new) — the
   only file in the package allowed to import a GPU package. Re-exports
   `package:flutter_scene/src/gpu/gpu.dart`, defines
   `typedef GpuContextFactory = gpu.GpuContext Function()`,
   `void debugSetGpuFactory(GpuContextFactory? f)` (the test seam — clears the
   cached answer on every call), and `bool gpuAvailable()` (probes once,
   caches the result, catches any exception from the probe or the injected
   factory and returns `false`).
3. **`packages/jet_cad_2d_flutter/test/gpu/gpu_facade_test.dart`** (new) — the
   two tests from the brief: the un-injected path answers rather than throws;
   an injected throwing factory makes the backend unavailable and the probe
   fires exactly once (proving the cache, not just the answer).

`flutter pub get` resolved `flutter_scene: ^0.23.0` with no version conflict.

## What I tested and the results

Ran the full package gate from the brief's Step 6, after the RED/GREEN cycle
below:

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:06 +416 ~1: All tests passed!
```

(416 passed, the one `~1` skip marker is pre-existing in the suite, unrelated
to this task — it appears identically across multiple test files in the run.)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 75 files (0 changed) in 0.11 seconds.
exit: 0
```

`git status --short` before committing showed only the intended files: no
`analysis_options.yaml` in any package was rewritten in the final state (an
earlier `flutter pub get` did touch `packages/jet_cad/analysis_options.yaml`;
it was reverted with `git checkout --` before the test/analyze/format run and
never reappeared).

## TDD Evidence

**RED** — command: `cd packages/jet_cad_2d_flutter && flutter test test/gpu/gpu_facade_test.dart`, run before `lib/src/gpu/gpu_facade.dart` existed:

```
test/gpu/gpu_facade_test.dart:2:8: Error: Error when reading 'lib/src/gpu/gpu_facade.dart': No such file or directory
import 'package:jet_cad_2d_flutter/src/gpu/gpu_facade.dart';
       ^
test/gpu/gpu_facade_test.dart:5:18: Error: Method not found: 'debugSetGpuFactory'.
...
test/gpu/gpu_facade_test.dart:10:18: Error: Method not found: 'gpuAvailable'.
...
00:00 +0 -1: Some tests failed.
```

This matches the brief's expected failure exactly (`Couldn't resolve` /
`Method not found` for the facade's exports) — the test file was written
before the implementation existed, so this is a genuine compile-time RED, not
a fabricated one.

**GREEN** — same command, after writing `lib/src/gpu/gpu_facade.dart`:

```
00:00 +0: loading .../test/gpu/gpu_facade_test.dart
00:00 +0: reports the platform context when no factory is injected
00:00 +1: a factory that throws makes the backend unavailable, once
00:00 +2: All tests passed!
```

Both tests pass. The second test's `calls == 1` assertion is the one that
actually exercises the cache — a naive re-probing implementation would have
made `calls == 2` and failed there.

## Files changed

- `packages/jet_cad_2d_flutter/pubspec.yaml` (modified — dependency added)
- `packages/jet_cad_2d_flutter/lib/src/gpu/gpu_facade.dart` (new)
- `packages/jet_cad_2d_flutter/test/gpu/gpu_facade_test.dart` (new)

Commit: `65a0797` — "feat(gpu): the facade, and a GPU probe a test can fail on demand"

## Self-review findings

- The implementation and test files were transcribed from the brief verbatim
  (the brief gives exact code for both), so there is no drift between the
  brief's intent and what landed.
- Checked the reference spike (`apps/dev_harness_2d/lib/gpu_arm.dart`) to
  confirm the shim import path (`package:flutter_scene/src/gpu/gpu.dart`) and
  the `// ignore: implementation_imports` pattern are consistent with known
  working usage on this branch — they match exactly.
- Confirmed `gpu_facade.dart` is the *only* file in
  `packages/jet_cad_2d_flutter` that imports a `flutter_scene`/GPU package
  (grep for `flutter_scene` and `flutter_gpu` across `lib/` and `test/` turns
  up only this file and its re-export).
- Confirmed no other file in the package references `gpuAvailable` or
  `debugSetGpuFactory` yet — this task deliberately draws no consumer; later
  tasks sit behind this facade.
- `pubspec.lock` is gitignored (`*.lock` in `.gitignore`), so no lockfile
  churn to worry about.
- Ran `git status --short` immediately before staging and immediately after
  committing; both times the working tree contained only the three intended
  files (before) and was fully clean (after) — no `analysis_options.yaml`
  slipped into the commit.

## Issues or concerns

None. `flutter pub get` resolved `flutter_scene: ^0.23.0` without any version
conflict, so the plan's fallback ambiguity-resolution clause did not need to
be invoked. Nothing draws yet, as intended — this task is the seam only.
