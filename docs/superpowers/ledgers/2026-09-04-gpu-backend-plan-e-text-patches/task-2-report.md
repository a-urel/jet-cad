# Task 2 report — The classification: which labels are covered, and by what

## Summary

Implemented `TextPatch` and `classifyTextPatches` in
`packages/jet_cad_2d_flutter/lib/src/gpu/text_patches.dart`, exactly as
specified in the brief's Step 3, appended to the existing file (which already
held the four constants and `boundTransformedBox` from Task 1). Also:

- Fixed the two Task 1 review findings, both doc-comment rewording in
  `text_patches.dart`:
  1. `kBandLowerScale`/`kBandUpperScale`'s doc no longer claims "every
     function in this file" takes them as parameters — reworded to name the
     classification functions specifically (`classifyTextPatches`, and Task
     4's region/size functions).
  2. `boundTransformedBox`'s doc no longer claims a frame-path caller exists
     today — reworded to say a frame-path caller (`labelBoundsLogical`,
     `patchRegionFor`) arrives in Task 4.
- Added the brief's pinning line to `test/gpu/instance_record_test.dart`: a
  new test `'x0..y2 are contiguous at offsets 2..7'` asserting
  `[InstanceFieldOffset.x0, y0, x1, y1, x2, y2] == [2, 3, 4, 5, 6, 7]`, since
  `classifyTextPatches`'s `_reaches` helper relies on that contiguity via
  `InstanceFieldOffset.x0 + p * 2`.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/gpu/text_patches.dart` (modified —
  appended `TextPatch`, `classifyTextPatches`, `_reaches`; added
  `instance_record.dart`/`resident_text.dart` imports; reworded two doc
  comments)
- `packages/jet_cad_2d_flutter/test/gpu/text_patches_test.dart` (new — the
  eleven tests from the brief's Step 1, verbatim)
- `packages/jet_cad_2d_flutter/test/gpu/instance_record_test.dart` (modified
  — added the one pinning test)

## TDD evidence

### RED — Step 2, before implementation

Command:
```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/text_patches_test.dart
```
Output (tail):
```
  test/gpu/text_patches_test.dart:112:9: Error: Method not found: 'classifyTextPatches'.
          classifyTextPatches(n.data, n.count, texts,
          ^^^^^^^^^^^^^^^^^^^
  ...
00:00 +0 -1: Some tests failed.

Failing tests:
  .../test/gpu/text_patches_test.dart: loading .../test/gpu/text_patches_test.dart
```
Confirmed: compile error, `TextPatch`/`classifyTextPatches` undefined, as expected.

### GREEN — Step 4, after implementation

Command:
```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/text_patches_test.dart test/gpu/instance_record_test.dart
```
Output (tail):
```
00:00 +21: .../text_patches_test.dart: patches come back in ascending text index, one per covered label
00:00 +20: .../text_patches_test.dart: a dashed stroke is a candidate over its whole segment, gaps included
00:00 +22: .../instance_record_test.dart: a point is never dashed
00:00 +23: .../instance_record_test.dart: a fill record carries three corners, no width and no dash
00:00 +24: .../instance_record_test.dart: the four kind tags are distinct and ordered for a < dispatch
00:00 +25: All tests passed!
```
(25 = 11 tests in text_patches_test.dart + 14 in instance_record_test.dart, all passing.)

## Gate commands, output, exit codes

```sh
cd packages/jet_cad_2d_flutter && flutter test
```
Tail:
```
00:10 +588 ~1: All tests passed!
```
Exit code: `0`. (588 passed, 1 skipped — the skip is pre-existing, unrelated to this task.)

```sh
cd packages/jet_cad_2d_flutter && flutter analyze
```
Output:
```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
```
Exit code: `0`.

```sh
cd packages/jet_cad_2d_flutter && dart format --output=none --set-exit-if-changed .
```
First run printed `Changed test/gpu/instance_record_test.dart` and
`Changed test/gpu/text_patches_test.dart` (exit 1) — the two new/edited test
files needed reformatting (list literal line-wrapping, method chaining).
Ran `dart format .` to apply, then re-ran the check:
```
Formatted 96 files (0 changed) in 0.14 seconds.
```
Exit code: `0`.

## git status before commit

```
 M packages/jet_cad_2d_flutter/lib/src/gpu/text_patches.dart
 M packages/jet_cad_2d_flutter/test/gpu/instance_record_test.dart
?? packages/jet_cad_2d_flutter/test/gpu/text_patches_test.dart
```
No `analysis_options.yaml` shown modified — nothing to check out.

## Commit

```
be31724 feat(gpu): classify which labels later geometry reaches
```
3 files changed, 386 insertions(+), 3 deletions(-).

## Self-review

- **Completeness:** All eleven tests from the brief's Step 1 are present
  verbatim. `TextPatch` and `classifyTextPatches` (plus the private
  `_reaches` helper) match the brief's Step 3 code exactly. The
  `instance_record_test.dart` pinning line is added. Both Task 1 doc-comment
  review findings are fixed.
- **Quality:** Doc comments preserved/extended in the file's existing long,
  reasoned style. `classifyTextPatches` reuses a `hits` list across labels
  rather than allocating one per label — appropriate since this runs at
  rebuild (not the frame path, which has the actual allocation invariant).
- **Discipline:** Nothing beyond the brief was touched. No changes outside
  `text_patches.dart`, the new test file, and the one pinning line in
  `instance_record_test.dart`.
- **Testing:** Tests were confirmed RED before implementation (compile
  error) and GREEN after. Full package suite (588 tests), analyzer, and
  formatter are all clean. No synthesized output — every command above was
  actually run and its output pasted.

## Concerns

None. The implementation is a direct, literal transcription of the brief's
Step 3 code plus the two documented amendments; no ambiguity was
encountered.
