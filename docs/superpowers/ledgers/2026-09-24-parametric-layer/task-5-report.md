# Task 5 report: `PlacementTool.commit` checks a capability set

## Implementation

`packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart:217-226`:

```dart
  /// Ruling 05-3: the permission check runs before [build], so a denied
  /// shape allocates no handle. [needs] is every capability the built
  /// command will need (spec 06 D13, Ruling 06-10); 05's shapes need
  /// geometry alone. Returns whether the command ran.
  bool commit(ToolContext ctx, DraftCommand Function() build,
      {Set<Capability> needs = const {Capability.geometry}}) {
    final permissions = ctx.document.commands.permissions;
    if (!needs.every(permissions.allows)) return false;
    ctx.execute(build());
    return true;
  }
```

Exactly the brief's Step 3 code. `commitShape` (unchanged) still calls `commit`
positionally, so it keeps the default `{Capability.geometry}` and every
existing draw-tool call site is untouched.

## Deviations from the brief's literal test text

The brief's test template used `testWidgets` with `await drawRig(tester)` and
fields `rig.doc` / `rig.ctx`. The real fixture
(`packages/jet_cad_2d_flutter/test/support/draw_fixture.dart`) has no such
API:

- The rig is built from two plain functions: `drawScene()` (returns a
  `DrawScene` with a `document` field, no `tester` involved) and
  `drawRig(document, tool, {flipY, objectSnap})` (returns a `DrawRig`).
- `DrawRig`'s fields are `document` and `context`, not `doc`/`ctx`.
- Every existing draw-tool test in this directory (e.g.
  `rectangle_tool_test.dart`) uses plain `test(...)`, not `testWidgets`, with
  this exact `drawScene()` / `drawRig(...)` pairing — so I followed that
  convention instead of inventing an async widget-test shape the fixture
  doesn't support.

So the actual test (`packages/jet_cad_2d_flutter/test/draw/commit_needs_test.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/draw_fixture.dart';

class _Probe extends RectangleTool {
  int builds = 0;
  bool run(ToolContext ctx, Set<Capability> needs) => commit(ctx, () {
        builds++;
        return CompoundCommand(const [], label: 'never');
      }, needs: needs);
}

void main() {
  test('CN1 a denied member of needs stops the build (M-06u)', () {
    final s = drawScene();
    final probe = _Probe();
    final rig = drawRig(s.document, probe, objectSnap: false);
    s.document.commands.permissions = const DraftPermissions(
        transform: true, components: true, geometry: true, structure: false);
    expect(probe.run(rig.context, {Capability.structure, Capability.geometry}),
        isFalse);
    expect(probe.builds, 0);
  });

  test('CN2 the default is geometry alone, as in 05', () {
    final s = drawScene();
    final probe = _Probe();
    final rig = drawRig(s.document, probe, objectSnap: false);
    s.document.commands.permissions = const DraftPermissions(
        transform: true, components: true, geometry: false, structure: true);
    expect(probe.run(rig.context, const {Capability.geometry}), isFalse);
    expect(probe.builds, 0);
  });
}
```

Imports: the top-level barrel `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart`
(exports both `RectangleTool` and `ToolContext`), plus `jet_cad_2d` for
`Capability`/`DraftPermissions`/`CompoundCommand`. Both are used by name, so
`unused_import` does not fire.

## RED evidence (before implementing)

With only the test file added (no `needs` parameter yet):

```
$ CI=true flutter test test/draw/commit_needs_test.dart
...
test/draw/commit_needs_test.dart:12:10: Error: No named parameter with the name 'needs'.
      }, needs: needs);
         ^^^^^
00:00 +0 -1: Some tests failed.
```

Compile failure, as the brief's Step 2 predicts — `needs` does not exist on
`commit` yet.

## GREEN evidence (after implementing)

```
$ CI=true flutter test test/draw/commit_needs_test.dart
...
00:00 +0: CN1 a denied member of needs stops the build (M-06u)
00:00 +1: CN2 the default is geometry alone, as in 05
00:00 +2: All tests passed!
```

## Mutant kill check (M-06u): does CN1 actually fail if `commit` ignores `needs`?

Verified empirically, not just by reasoning. I temporarily replaced the body
with the pre-task (05) version — `if (!ctx.document.commands.permissions
.allows(Capability.geometry)) return false;`, ignoring `needs` — and reran:

```
$ CI=true flutter test test/draw/commit_needs_test.dart
00:00 +0: CN1 a denied member of needs stops the build (M-06u)
00:00 +0 -1: CN1 a denied member of needs stops the build (M-06u) [E]
  Invalid argument (children): must not be empty: _ImmutableList len:0
  package:jet_cad_2d/src/document/commands.dart 752:7             new CompoundCommand
  test/draw/commit_needs_test.dart 11:16                          _Probe.run.<fn>
  package:jet_cad_2d_flutter/src/draw/placement_tool.dart 226:22  PlacementTool.commit
  test/draw/commit_needs_test.dart 9:55                           _Probe.run
  test/draw/commit_needs_test.dart 22:18                          main.<fn>

00:00 +0 -1: CN2 the default is geometry alone, as in 05
00:00 +1 -1: Some tests failed.
```

Why it fails: CN1's fixture grants `geometry: true` but denies `structure:
false`, and calls `run` with `needs = {structure, geometry}`. The mutant
checks only `Capability.geometry` (true), so it calls `build()` — the probe's
builder runs, increments `builds`, and constructs
`CompoundCommand(const [], ...)`, which throws `ArgumentError` inside the
test body (surfacing as the `[E]` failure above) before either `expect` can
even be reached. CN1 therefore genuinely goes red under M-06u.

CN2 is deliberately a weaker/independent check (the *default* value stays
`{Capability.geometry}`): under the same mutant it happens to still return
`false` correctly (mutant checks exactly `Capability.geometry`, which is
denied), so CN2 alone would not have caught M-06u — confirming CN1, not CN2,
is the mutant-killing test, as the brief intends.

I then restored the real implementation from a `cp` backup and diffed to
confirm the restore was byte-for-byte the intended code (see Self-review).
Reran the full two-test suite afterward — both green again (see GREEN
evidence above, captured after the restore).

## Gate summary

Render line only, per the brief (Task 5 does not touch the engine barrel):

```
$ CI=true flutter test
...
00:17 +925 ~1 -5: Some tests failed.
Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
$ echo $?
1
```

Exit code 1, and the failures are exactly the five standing
`text_ladder_golden_test.dart` rungs (1-5, `RenderBackend.canvas`) named in
the global constraints as the standing exception — nothing else failed.
Passed count: 925 (923 branch-point baseline + the 2 new CN tests) + 1 skip +
the 5 standing golden failures = 931 total, matching the expected arithmetic.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.8s)
$ echo $?
0

$ dart format --output=none --set-exit-if-changed .
Formatted 176 files (0 changed) in 0.35 seconds.
$ echo $?
0
```

`dart format` was run non-gate-mode on the two touched files before the gate
check and made no changes (already compliant):
`dart format lib/src/draw/placement_tool.dart test/draw/commit_needs_test.dart`
→ "Formatted 2 files (0 changed)".

## Files

- Modified: `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`
  (lines 217-226)
- Added: `packages/jet_cad_2d_flutter/test/draw/commit_needs_test.dart`

## Self-review

- `git status --short` before staging showed only these two files — no
  `analysis_options.yaml` picked up by `flutter pub get`.
- Confirmed no other call site of `commit` needed updating: `commitShape`
  calls `commit(ctx, () { ... })` with no `needs:` argument, so it keeps the
  default `{Capability.geometry}` and every existing 05 draw-tool test
  (line, rectangle, circle, arc, polyline, text) is unaffected — verified by
  the full render-line run reporting the same 923-baseline pass count plus
  only my 2 new tests as additions, no regressions.
- During the mutant-kill check I edited `placement_tool.dart` in place via a
  Python script, first copying it to `/tmp/placement_tool.dart.bak_verify`.
  After the check I restored via `cp` from that backup and ran `diff` between
  the backup and the restored file, confirming zero difference, before
  deleting the backup. The working tree was never left in the mutant state.
  `git status --short` immediately after the restore (pre-stage) showed the
  same two files as before the excursion, confirming no stray content
  survived.
- Commit trailer matches exactly: `Co-Authored-By: Claude Opus 5.5
  <noreply@anthropic.com>`.
- Never switched branches, pushed, or merged; stayed on
  `plan-06/parametric-layer` throughout.

## Concerns

- None outstanding. The one open question was purely mechanical (fixture API
  names/shape), resolved by reading `draw_fixture.dart` and an existing
  sibling test (`rectangle_tool_test.dart`) directly, as instructed, rather
  than guessing.
