# Task 1 review fixes: report

Implementer of the fixes for findings 2, 3 and 5 of `task-1-review.md`. Branch
`claude/exciting-pasteur-9m22jv`, HEAD `e1ddf4e`. **Nothing committed**; the changes are
in the working tree. Every mutant was reverted: the source files with
`git show HEAD:path > path` plus `git diff --quiet`, and the guard test (not at HEAD)
from a scratch copy plus `cmp`. No `analysis_options.yaml`, `pubspec.yaml` or
`pubspec.lock` was changed. The real-pubspec mutants ran with `flutter test --no-pub`,
so nothing was resolved.

## Files changed

```
 apps/dev_harness_2d/lib/gpu_arm.dart               |   6 +-
 apps/dev_harness_2d/lib/main.dart                  |   5 +-
 .../jet_cad_2d_flutter/lib/src/gpu/frame_info.dart |   3 +-
 .../lib/src/gpu/geometry_collector.dart            |   2 +-
 .../test/gpu/draft_canvas_registry_test.dart       |  14 +
 .../test/invariants/no_gpu_dependency_test.dart    | 354 ++++++++++++++++++---
 .../test/support/recording_frame_painter.dart      |  17 +-
 7 files changed, 356 insertions(+), 45 deletions(-)
```

## Finding 2: the upload's arguments

- **`test/support/recording_frame_painter.dart`.** `FakeResidentGpu.upload` now records
  `lastCollection`, `lastViewport`, `lastMeasurer` and `lastTextStyleOf`. Those are all
  four of the arguments it takes.
- **`test/gpu/draft_canvas_registry_test.dart`, "an available GPU registered…".** The
  test now asserts:
  - `gpu.lastCollection` is `same(s.resident!.collection)`;
  - `gpu.lastViewport == kCanvas`;
  - `gpu.lastMeasurer` is `same(measurer)`;
  - `gpu.lastTextStyleOf == doc.textStyleOf`. This uses equality, not `same`, because
    each tear-off is a new object. Tear-offs of one method on one receiver compare
    equal.
- **The fixture is not degenerate.**
  - `kCanvas` is `Size(400, 300)`, not `Size.zero` or a default.
  - The test asserts `doc.textMeasurer` is `same(measurer)`. That pins the expected
    measurer to the instance the test built, which `DraftCanvas` borrows from the
    document.

| Mutant in `lib/src/draft_canvas.dart` (the upload call) | Result | Killed by |
|---|---|---|
| `residentGpu!.upload(collection, Size.zero, …)` | **red**: `Expected: Size(400.0, 300.0)` / `Actual: Size(0.0, 0.0)`; `+232 -1` over `test/gpu/` | registry test "an available GPU registered…" |
| `measurer: FlutterTextMeasurer()` | **red**: `Expected: same instance as <Instance of 'FlutterTextMeasurer'>`; `+232 -1` | same test |
| `textStyleOf: (h) => widget.document.textStyleOf(h)` | **red**: `Expected: <Closure … from Function 'textStyleOf'>` / `Actual: <Closure: (int) => TextStyleRecord>`; `+232 -1` | same test |

The reviewer's two surviving mutants (`Size.zero` and a fresh measurer) now go red.

## Finding 3: the S7 guard (`test/invariants/no_gpu_dependency_test.dart`)

**Why not `package:yaml`.** It is in the root `pubspec.lock` only as
`dependency: transitive`, and core's dev_dependencies are just `flutter_test` and
`lints`. `depend_on_referenced_packages` is in `lints/core.yaml`, so importing `yaml`
would mean adding a dev_dependency to this host-facing package's pubspec. That pubspec
is the one this guard and Task 2's lock check police. Adding it would also change the
lock, and could set off `pub get` rewriting `analysis_options.yaml`. The brief's
condition, "can already reach it", is not met, so I kept the reading hand-rolled and
added no dependency.

**The key matcher.** `forbiddenDependencyKeys` is now
`dependencyKeys(pubspec).where(kForbiddenPackages.contains)`. The new
`dependencyKeys` returns every key directly under `dependencies`, `dev_dependencies`
or `dependency_overrides`. It reads these shapes:
- **Any indent.** A block section's key indent is whatever indent its first key line
  uses. A deeper line belongs to a dependency's own value, and indent 0 ends the
  section.
- **Quoted keys.** A double-quoted or single-quoted key, with escapes, is unquoted. This
  includes the section's own name, as in `"dependencies":`.
- **Flow maps.** A value starting with `{` is a flow map. Its lines are gathered until
  its brackets balance, so it can span lines. Only the top level's keys are read: plain,
  quoted, or bare (`{a, b}`, a null value, which pub reads as "any"). Nested maps and
  lists are not read.
- **Comments.** These are stripped first: a `#` at the start of a line or after
  whitespace, outside a quoted scalar. An apostrophe inside a plain scalar (`it's`)
  does not open a quote.
- **Not read:** explicit `? key` entries, anchors and aliases. The doc comment says so,
  and names Task 2's lock check as the backstop.

**The URI matcher.** It now matches only **import and export directives**. A
directive is a line that starts, after whitespace, with `import` or `export`, and it
runs to its `;`, across line breaks. Only within that span are `'package:<name>/'` or
`"package:<name>/"` URIs counted, and `//` lines inside it are skipped. A `package:`
URI in a string literal no longer counts. So rewording `draft_canvas.dart:349`'s
fallback text to `package:jet_cad_2d_gpu/jet_cad_2d_gpu.dart` stays green. I checked
this by applying that exact reword to the real file and running the guard: `+20: All
tests passed!`, then restored.

**The fixtures.**
- **`_shapes`: eleven red shapes.** Each runs for every forbidden name and every
  section. The sections are spelled out in the test, not read from
  `_dependencySections` (see K6 below).
  - block, two-space indent;
  - block, four-space indent;
  - block, one-space indent;
  - block, comments before the first key (one at column 0, one at another indent);
  - block, double-quoted key;
  - block, single-quoted key (`'name' : …`);
  - block, quoted section;
  - flow map;
  - flow map, quoted key with a map value;
  - flow map across lines;
  - flow map, bare key.
- **A new green look-alike test that covers every shape.** It holds:
  - `my_flutter_scene_tools` and quoted `"flutter_scene_extras"` / `'my_flutter_gpu'`
    in a four-space block;
  - a nested `flutter_scene:` under a dependency;
  - a flow map with a nested `{path: ../other, flutter_scene: nested}` and a list
    `[flutter_gpu]`;
  - a multi-line flow map with a `path: ../flutter_scene` value;
  - `# {flutter_scene: …}` comments;
  - `executables:` and `flutter:` sections naming `flutter_scene`.

  The test also asserts `dependencyKeys` returns exactly the nine look-alike keys, so it
  is green because they were read and refused, not because nothing was read.
- **Anti-vacuity on the real pubspec.** `dependencyKeys` must contain `jet_cad_2d`,
  `meta`, `pdf` and `flutter_test`.
- **URI matcher, red.** A directive whose keyword and URI sit on separate lines
  (`import\n    'package:$name/x.dart'\n    show Y;`), for each name.
- **URI matcher, green.** A `package:` URI in string literals: the current fallback
  wording, the reworded one with `/jet_cad_2d_gpu.dart`, and
  `Uri.parse('package:flutter_scene/x.dart')`.

### Mutants of the check

Each was applied to the test's own check, then restored from the scratch copy and
checked with `cmp`.

| Mutant | Result | Killed by |
|---|---|---|
| K1: key indent fixed at 2 (`keyIndent = 2`) | **red**, 3 tests | shapes "four-space indent", "one-space indent"; green "every shape" test |
| K2: quoted keys not read (`if (false)` in `_leadingKey`) | **red**, 5 tests | "double-quoted key", "single-quoted key", "quoted section", "flow map, quoted key with a map value"; green "every shape" |
| K3: flow maps ignored (no `keys.addAll(_flowMapKeys(…))`) | **red**, 5 tests | "flow map", "flow map, quoted key…", "flow map across lines", "flow map, bare key"; green "every shape" |
| K4: bare flow key ignored | **red**, 2 tests | "flow map, bare key"; green "every shape" |
| K5: comments not stripped | **red**, 1 test | "block, comments before the first key" |
| K6: `dependency_overrides` dropped from `_dependencySections` | **first run: only the green anti-vacuity test went red**, because the red fixtures iterated the same list. I fixed this by spelling out the sections in the test. **Re-run: red, 12 tests**: all eleven shapes and the green "every shape" test | all shape tests |
| K7: substring match instead of a whole key | **red**, 2 tests | both green look-alike tests |
| K8: flow-map commas split at any depth (nested keys read as top level) | **first run: survived.** No nested flow value had a comma, so the mutant was equivalent on those fixtures. I added `path: ../other,` to the nested map. **Re-run: red, 1 test** | green "every shape" test |
| U1: the old URI matcher (any quoted `package:` URI on a non-`//` line) | **red**, 1 test | URI "is green on a package: URI in a string literal" |
| U2: a directive read only to the end of its first line (`[^;\n]*`) | **red**, 3 tests | "is red on $name by import, export and conditional import" (conditional and split-line fixtures), for each name |

### The real-file mutants, re-run against the new matchers

Run with `--no-pub`, and restored from HEAD.

| Mutant | Result |
|---|---|
| M-G1a: `flutter_scene: ^0.23.0` under `dependencies:` | **red**: `Actual: ['flutter_scene']` |
| M-G1a′: `"flutter_scene": ^0.23.0` (quoted) under `dependencies:` | **red**: `Actual: ['flutter_scene']` |
| M-G1a″: `dev_dependencies:` rewritten as a flow map containing `jet_cad_2d_gpu: {path: ../jet_cad_2d_gpu}` | **red**: `Actual: ['jet_cad_2d_gpu']` |
| M-G1b: `import 'package:jet_cad_2d_gpu/jet_cad_2d_gpu.dart';` in `lib/src/gpu/resident_gpu.dart` | **red**: `Actual: ['lib/src/gpu/resident_gpu.dart: package:jet_cad_2d_gpu/']` |
| Probe, not a mutant: `draft_canvas.dart`'s fallback reworded to `'package:jet_cad_2d_gpu/jet_cad_2d_gpu.dart first)…'` | **green**, as intended: `+20: All tests passed!` |

## Finding 5: stale comments

- `jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart:141`: `buildFrameInfo` is cited
  as being in `frame_info.dart`, where it is defined at `:98.`
- `jet_cad_2d_flutter/lib/src/gpu/frame_info.dart:26`: now reads "the doc comment in
  `resident_geometry.dart`, now in package `jet_cad_2d_gpu`".
- `apps/dev_harness_2d/lib/gpu_arm.dart:385` (now `:387`): now reads "the doc comment in
  `resident_geometry.dart`, package `jet_cad_2d_gpu` since the GPU split".
- Found by grep:
  - `apps/dev_harness_2d/lib/gpu_arm.dart:29-30` said `ResidentGeometry.create` and
    `GpuDrawBackend` were "all from `package:jet_cad_2d_flutter`". It now names
    `jet_cad_2d_flutter` for the collector and `jet_cad_2d_gpu` for the other two.
  - `apps/dev_harness_2d/lib/main.dart:615-616` said "Prices `jet_cad_2d_flutter`'s
    real GPU-resident backend -- `GeometryCollector`, `ResidentGeometry.create`,
    `GpuDrawBackend`". It now gives each its package.
  - `jet_cad_2d_flutter/test/support/recording_frame_painter.dart:9` now says
    "`jet_cad_2d_gpu`'s `resident_geometry.dart`".
- I grepped `packages/`, `apps/` and `tool/` (excluding `*.md`) for `gpu_facade`,
  `resident_geometry`, `gpu_draw_backend` and `resident_upload`. Every other hit is
  inside `jet_cad_2d_gpu` itself, so a local reference is correct. The two exceptions
  are `resident_layout_test.dart:4-8`, which already names the new path, and the
  barrel's `export` lines.
- Core comments that only name the symbols (`ResidentGeometry.create`,
  `GpuDrawBackend.render`, and so on) make no claim about location. I left them alone.
- Nothing under `docs/` was touched.

## Gates

All gates ran after every revert, in `/home/user/jet-cad`.

**`packages/jet_cad_2d_flutter`**, the CI invocation:
`flutter test --file-reporter json:<file>`, then `dart run tool/ci/expect_failures.dart`:

```
$ flutter test --file-reporter "json:$S/core-tests.json"      # exit 1 (expected: standing failures)
02:53 +1354 ~1 -7: Some tests failed.
$ dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d_flutter --root packages/jet_cad_2d_flutter "$S/core-tests.json"
packages/jet_cad_2d_flutter: 1362 tests; the standing failures and skips, exactly
exit 0
$ flutter analyze
No issues found! (ran in 9.1s)
$ dart format --output=none --set-exit-if-changed .
Formatted 221 files (0 changed) in 1.36 seconds.
format exit 0
```

The count is 1362 (+10 over the review's 1352). The guard file went from 10 tests to
20 (11 shape tests replace the 3 per-name key tests, plus one new green key test and one
new green URI test). The standing set is unchanged: 7 failures and 1 skip.

**`packages/jet_cad_2d_gpu`** (untouched):

```
$ flutter test
00:01 +16: All tests passed!
$ flutter analyze
No issues found! (ran in 7.3s)
$ dart format --output=none --set-exit-if-changed .
Formatted 9 files (0 changed) in 0.06 seconds.
format exit 0
```

**`apps/dev_harness_2d`** (comments touched):

```
$ flutter analyze
No issues found! (ran in 9.3s)
$ dart format --output=none --set-exit-if-changed .
Formatted 22 files (0 changed) in 0.16 seconds.
format exit 0
```

**`git status --short`:**

```
 M apps/dev_harness_2d/lib/gpu_arm.dart
 M apps/dev_harness_2d/lib/main.dart
 M packages/jet_cad_2d_flutter/lib/src/gpu/frame_info.dart
 M packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart
 M packages/jet_cad_2d_flutter/test/gpu/draft_canvas_registry_test.dart
 M packages/jet_cad_2d_flutter/test/invariants/no_gpu_dependency_test.dart
 M packages/jet_cad_2d_flutter/test/support/recording_frame_painter.dart
```

`flutter`'s "running as root" banner lines are left out of the outputs above. Everything
else is verbatim.
