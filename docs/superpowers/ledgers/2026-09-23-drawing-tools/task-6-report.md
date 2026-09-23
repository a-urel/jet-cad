# Task 6 report: TextTool

## What I implemented

- `packages/jet_cad_2d_flutter/lib/src/draw/text_tool.dart`: `TextPlacement`
  (immutable point + heightMm) and `TextTool extends PlacementTool`, exactly
  as the brief's code block specifies. No deviation from the brief's code —
  it compiled and passed as given.
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`: added
  `export 'src/draw/text_tool.dart';` after the `rectangle_tool.dart` export.
- `packages/jet_cad_2d_flutter/test/draw/text_tool_test.dart`: TX1 (run for
  both `flipY` values) through TX7, copied from the brief verbatim.

## TDD evidence

**RED** — `cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/text_tool_test.dart`
before `lib/src/draw/text_tool.dart` existed:

```
test/draw/text_tool_test.dart:7:8: Error: Error when reading 'lib/src/draw/text_tool.dart': No such file or directory
import 'package:jet_cad_2d_flutter/src/draw/text_tool.dart';
       ^
test/draw/text_tool_test.dart:27:20: Error: Method not found: 'TextTool'.
      final tool = TextTool();
                   ^^^^^^^^
[... same for lines 42, 64, 77, 92, 110, 121 ...]
00:00 +0 -1: loading .../test/draw/text_tool_test.dart [E]
  Failed to load ".../test/draw/text_tool_test.dart": Compilation failed ...
00:00 +0 -1: Some tests failed.
```

This is the expected failure: the file and class did not exist yet.

**GREEN** — after writing `text_tool.dart` and the barrel export, same
command:

```
00:00 +0: TX1 flipY true: a click sets pending at the exact point, 2.5 paper mm at 1:20, and dispatches nothing (M-05j)
00:00 +1: TX1 flipY false: a click sets pending at the exact point, 2.5 paper mm at 1:20, and dispatches nothing (M-05j)
00:00 +2: TX2 commitText commits one text with the string and height
00:00 +3: TX3 an empty string cancels, byte-identical
00:00 +4: TX4 a canvas click while pending commits the controller text and starts nothing new (M-05y)
00:00 +5: TX5 Escape and a tool switch each cancel, byte-identical
00:00 +6: TX6 Enter with the canvas focused commits the controller text
00:00 +7: TX7 a shift click takes no ortho
00:00 +8: All tests passed!
```

8 tests, all passing (TX1 runs twice for `flipY`, TX2–TX7 once each = 8).

## Gate line

```
cd packages/jet_cad_2d_flutter && CI=true flutter test
```

Tail:

```
00:12 +911 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

911 passed = 903 (branch-point count handed to me in the dispatch) + 8 new
TX tests. 1 skip, 5 failures — exactly the standing
`text_ladder_golden_test.dart` exception named in the dispatch and in
`implementer-common.md`. No other failures. Exit code 1, as expected for
this standing exception (`flutter test ; flutter analyze` per the gate
line's own `;`).

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.6s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 175 files (0 changed) in 0.34 seconds.
exit=0
```

`dart format` was also run explicitly on the three touched files before the
gate line (it reflowed the test file's two multi-line `test(...)` calls;
the implementation file needed no change).

`git status --short` before every command and before the commit showed no
`analysis_options.yaml` rewrite — nothing to `checkout --`.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/draw/text_tool.dart` (new)
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (one export line)
- `packages/jet_cad_2d_flutter/test/draw/text_tool_test.dart` (new)

Commit: `a07ca51` "feat(draw): the text tool owns its text and commits on a
canvas click", trailer `Co-Authored-By: Claude Sonnet 5
<noreply@anthropic.com>` — the model that actually wrote this commit (the
brief's example trailer said "Opus 5.5"; the session's own attribution
instructions, which take precedence, name the actual model). Verified with
`git log -1 --format=%B | grep -c "Sonnet 5"` → `1`.

## Self-review

Diff read in full after commit. Findings:

- **Completeness.** All interfaces the brief's task lists (`TextPlacement`,
  `TextTool.controller`, `.pending`, `.commitText`, `.cancelText`) are
  present and exported transitively through the barrel (the brief only asked
  for one export, of `text_tool.dart` itself; `TextPlacement` and `TextTool`
  are both public members of that file, so no separate export was needed).
- **Names.** Match the brief and the sibling tools' conventions
  (`line_tool.dart`, `circle_tool.dart`, etc.) — no renames.
- **YAGNI.** No extra members added beyond the brief's code block. I did not
  add a `toString`, equality, or any convenience constructor `TextPlacement`
  doesn't need.
- **Pristine output.** No stray prints, no commented-out code, no TODOs.
- **Mutant coverage,** checked against the spec's named-mutants table
  (section "Named mutants") for the ones this task's tests are supposed to
  catch:
  - **M-05j** (`textHeightMm` uses a fixed 50 instead of computing from
    `scaleDenominator`): TX1 asserts `placed.heightMm == 50.0` under the
    1:20 fixture via the real `textHeightMm(ctx.page?.value)` call in
    `accept`; a mutant hard-coding a wrong constant, or skipping the page
    scale, would be caught since 50.0 is `2.5 × 20` and not a value that
    falls out of an unrelated hard-code by accident in this fixture.
  - **M-05t** (`commitText` sets width-factor/oblique override bits): TX2
    asserts `r.textAttrs == 0` and `p.scalars == [50, 0, 1, 0]` — a mutant
    setting override bits in `textAttrs` or writing non-padding values into
    scalars 2/3 goes red.
  - **M-05y** (a canvas click while pending cancels instead of committing):
    TX4 types into `controller`, clicks the canvas a second time, and
    asserts the text entity now holds `'Bath'` and `pending` is null,
    `controller.text` is empty — a mutant that calls `cancelText` instead
    of `commitText` on the second click goes red immediately (no text
    entity would exist).
  - **M-05l**-equivalent for this tool (Escape mid-shape commits instead of
    cancelling): TX5 asserts the document snapshot is byte-identical after
    Escape with `controller.text` non-empty — a mutant that commits on
    Escape goes red.
  - I did not find a mutant in the table that TX3, TX6 or TX7 alone are
    named to catch, but each still pins a real behaviour (empty-string
    cancel, Enter-commits, and D9's "no ortho" via `orthoBase == null`)
    that the brief's code could regress without one of the other six
    catching it — e.g. TX7 is the only place `orthoBase`'s override is
    exercised at all.

No deviations from the brief's code were needed; it compiled and passed
verbatim.

## Concerns

None. The implementation matches spec 05 D9 and the brief exactly, the
render-layer gate is green modulo the pre-existing standing exception, and
`flutter analyze` reports no issues.
