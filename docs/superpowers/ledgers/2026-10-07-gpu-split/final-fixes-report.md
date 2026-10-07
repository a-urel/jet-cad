# Final review fixes: F-1, F-2 (MU1), F-4, F-5

Implementer report. I worked in `/home/user/jet-cad` on
`claude/exciting-pasteur-9m22jv`, starting from `02bd3c7`. During my run the
controller committed `de0315e` (F-3, F-6, F-7); I touched none of its files.
Nothing is committed. Flutter 3.47.6, `CI=true`. Every output below comes from
a command I ran.

## Changes per finding

### F-1. The asset key, checked off a device
- `packages/jet_cad_2d_gpu/lib/src/resident_geometry.dart`: the private
  `_bundlePath` is now `@visibleForTesting static const String bundleAssetKey`.
  Its value is unchanged, and the doc comment says why it is visible. The
  loader (`loadShaderLibraryAsync`) and the missing-entry-point `StateError`
  both use it. `dart format` rewrapped the `StateError` line.
- New `packages/jet_cad_2d_gpu/test/bundle_asset_key_test.dart`. It reads
  `pubspec.yaml` line by line, without `package:yaml`, using two helpers:
  `pubspecName` for the top-level `name:`, and `flutterAssets` for the
  top-level `flutter:` section's `assets:` list. It asserts three things:
  - the key starts with `packages/<name>/`;
  - the rest of the key is one of the declared assets;
  - `File(rest).existsSync()`.

  Two anti-vacuity checks: the name reads `jet_cad_2d_gpu`, and the asset list
  is not empty. Two fixture tests check the reader itself: only the top-level
  `flutter:` section's assets count, and a pubspec with no assets reads empty.
  4 tests.
- No pubspec, lock or `analysis_options.yaml` was changed.

### F-2. MU1 (`upload` returning null)
- `packages/jet_cad_2d_gpu/test/install_test.dart`, test "upload returns
  null, not a throw, where the GPU factory throws": the throwing factory now
  counts its calls. The test asserts `0` probes after install and `1` after
  `upload`. `ResidentGeometry.create`'s first statement is `gpuAvailable()`,
  so a consulted factory proves that `upload` reached
  `uploadResidentCollection` and `create`.
- **MU1b (`Size.zero` forwarded) still survives. A fake cannot observe it.**
  - The viewport becomes only `maxPatchWidth`/`maxPatchHeight`. Their single
    use is `resident_geometry.dart:305` (`patchTargetSizeFor`), inside
    `_upload`.
  - `_upload` reaches that line only after two device steps:
    - `gpu.loadShaderLibraryAsync(bundleAssetKey)`: native
      `ShaderLibrary.fromAsset`;
    - `gpu.gpuContext`.
  - Neither step has a seam. `GpuContext` and `ShaderLibrary` are
    `NativeFieldWrapperClass` types that no test can construct; the facade's
    own doc says so. `debugSetGpuFactory`'s factory only answers the
    availability probe. Its result is discarded and never reaches `_upload`.
  - With `debugSetGpuAvailable(true)` the call gets as far as the native
    shader load and is reported there, before the viewport is read.
  - Closest check: `uploadResidentCollection`'s ceiling arithmetic could be
    moved into a pure function and tested. But that would still not see
    `install.dart` forwarding `Size.zero`, unless production code gained an
    uploader-injection seam just for this. I did not add one. MU1b stays a
    device-only check.
- The results note's M-G4 rewording (F-2's main ask) is in `docs/`, which is
  the controller's to edit.

### F-4. S7's red cases spell out the names
`packages/jet_cad_2d_flutter/test/invariants/no_gpu_dependency_test.dart`:
- `main()` now opens with `const names = <String>['flutter_scene', 'flutter_gpu', 'jet_cad_2d_gpu'];`,
  with a comment giving the same reason as `sections`.
- The key matcher's per-shape tests loop over `names`, each name in turn under
  each section, with the name in the `reason:`.
- The URI matcher builds one test per name from `names`.
- The production helpers still read `kForbiddenPackages`. The test count is
  unchanged.

### F-5. "Read once, at attach" is pinned
The code comment at `draft_canvas.dart:336-337` and `ResidentGpu.available`'s
doc ("Read once per `DraftCanvas` attachment") both say what should happen,
and the spec's S4 agrees. The canvas keeps the instance it read at attach.
Nothing is ambiguous.

New test in `packages/jet_cad_2d_flutter/test/gpu/draft_canvas_registry_test.dart`:
"the GPU is read once, at attach: cleared afterwards, a rebuild still uploads
through the attached one".
1. It registers `FakeResidentGpu()`, mounts, and lands. Then `landed == 1`
   and `uploads == 1`.
2. It calls `registerResidentGpu(null)`.
3. It adds a line to the document (`addLine`), which triggers a
   document-change rebuild, then lands and pumps.
4. It asserts all of:
   - `takeException()` is null;
   - `uploadFailed` is false;
   - `lastTrigger == RebuildTrigger.document`;
   - `landed == 2`;
   - `gpu.uploads == 2`;
   - the backend is the fake's second painter;
   - the resolved backend is still `residentGpu`;
   - no fallback report.

## Mutants

Each mutant was an exact single-occurrence replacement, done by a script on a
scratch copy. After each run the file was restored with `cp` from that copy,
and `cmp` confirmed the restore ("restored ok" every time). The pubspec (MU3)
and the bundle renames were restored the same way and `cmp`-checked.

| # | Mutant | Run | Result | Killed by |
|---|---|---|---|---|
| MU1 | `install.dart` `upload` → `Future.value(null);` | gpu `test/install_test.dart` | **red** `+5 -1` | install_test "upload returns null, not a throw, where the GPU factory throws" (`probes` 0, expected 1) |
| MU1b | `upload` forwards `Size.zero` | gpu `install_test.dart`, then the full gpu suite | **survived** `+6`, then `+20` | none; device-only (see F-2) |
| MU2 | key prefix → `packages/jet_cad_2d_flutter/…` | gpu `bundle_asset_key_test.dart` | **red** `+3 -1` | "the key is packages/<the pubspec name>/<a declared asset>, and that asset is on disk" |
| MU2b | key path typo'd (`assets/shader/…`) | same | **red** `+3 -1` | same test (`contains(asset)`) |
| MU3 | `flutter:\n  assets:\n    - assets/shaders/cad.shaderbundle` dropped from the gpu pubspec | same | **red** `+2 -2` | "the pubspec reading finds the name and the declared assets", and the key test |
| rename-a | `cad.shaderbundle` → `cad_renamed.shaderbundle` on disk only | same | **red**, exit 1, before any test runs: `Error detected in pubspec.yaml: No file or variants found for asset: assets/shaders/cad.shaderbundle.` / `Error: Failed to build asset bundle` | `flutter test`'s asset bundling (fails closed) |
| rename-b | the file and its pubspec declaration renamed, the key left | same | **red** `+3 -1` | the key test (`contains(asset)`) |
| reader | `if (!inFlutter) continue;` removed from the test's `flutterAssets` | same | **red** `+3 -1` | "the pubspec reading reads only the top-level flutter: assets: list" |
| MU8 | `'flutter_gpu'` dropped from `kForbiddenPackages` | render `no_gpu_dependency_test.dart` | **red** `+8 -12` (all 11 key-matcher shapes, plus "the URI matcher is red on flutter_gpu …") | the key-matcher shape tests and the URI-matcher `flutter_gpu` test |
| MU13 | uploader closure → `registeredResidentGpu!.upload(` | render registry, fallback and resident tests | **red** `+17 -1`: "Null check operator used on a null value", then the fallback report | registry test "the GPU is read once, at attach …" |

About the `File(asset).existsSync()` line: rename-a shows that `flutter test`
already refuses to build when a declared asset is missing, so this expectation
is never the first to fail under `flutter test`. The test's comment says so. I
kept the line because it states the third fact, and it is the only check a
runner that does not bundle assets would make.

## Gates (after all reverts)

**`packages/jet_cad_2d_gpu`**
```
$ flutter test --file-reporter json:$S/gpu.json
00:01 +20: All tests passed!
test-exit=0
$ dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d_gpu --root packages/jet_cad_2d_gpu $S/gpu.json   # from the root
packages/jet_cad_2d_gpu: 20 tests; the standing failures and skips, exactly
expect-exit=0
$ flutter analyze
No issues found! (ran in 6.9s)
analyze-exit=0
$ dart format --output=none --set-exit-if-changed .
Formatted 10 files (0 changed) in 0.03 seconds.
format-exit=0
```
The count goes from 16 to 20, from the 4 tests in `bundle_asset_key_test.dart`.

**`packages/jet_cad_2d_flutter`**
```
$ flutter test --file-reporter json:$S/render.json
01:25 +1355 ~1 -7: Some tests failed.
test-exit=1
$ dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d_flutter --root packages/jet_cad_2d_flutter $S/render.json   # from the root
packages/jet_cad_2d_flutter: 1363 tests; the standing failures and skips, exactly
expect-exit=0
$ flutter analyze
No issues found! (ran in 6.4s)
analyze-exit=0
$ dart format --output=none --set-exit-if-changed .
Formatted 221 files (0 changed) in 0.78 seconds.
format-exit=0
```
The standing 7 failures (the text-ladder goldens) and 1 skip are unchanged.
The count goes from 1362 to 1363, from the one new registry test. S7 keeps
its test count.

**`apps/dev_harness_2d`** (it consumes `jet_cad_2d_gpu`, whose `lib/` I touched)
```
$ flutter analyze
No issues found! (ran in 4.6s)
analyze-exit=0
$ flutter test
00:36 +82: All tests passed!
test-exit=0
```

**`git status --short`** (HEAD is now the controller's `de0315e`)
```
 M packages/jet_cad_2d_flutter/test/gpu/draft_canvas_registry_test.dart
 M packages/jet_cad_2d_flutter/test/invariants/no_gpu_dependency_test.dart
 M packages/jet_cad_2d_gpu/lib/src/resident_geometry.dart
 M packages/jet_cad_2d_gpu/test/install_test.dart
?? packages/jet_cad_2d_gpu/test/bundle_asset_key_test.dart
```
`$S` is my session scratchpad.
