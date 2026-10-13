# Task 5 report

## TDD
RED: `cd tool/ci && dart test test/host_lock_test.dart test/scripts_test.dart` printed
`test/host_lock_test.dart:175:14: Error: Method not found: 'notFromCommit'.` (and `lockEntryFields`),
`00:00 +0 -1: loading test/host_lock_test.dart [E]`, and SC21 (the --ref case) failed
(`00:02 +13 -1: ... SC21 --ref ...`; the unknown flag exits 2).
GREEN: `dart test` -> `00:04 +76: All tests passed!`

## Mutants (backup copy in scratchpad host_lock.bak, restored, cmp clean each time)
- M-LK1 (drop `f['source'] != 'git' ||`): with the brief's tests ALONE, all stayed green (`+19: All tests passed!`):
  a hosted entry has no resolved-ref, so the ref clause catches it. Added HL-C3b (green entry, `source: git` -> `source: path`,
  ref kept). With it: `HL-C3b the right ref under another source: named [E]`, `Some tests failed`.
- M-LK2 (drop `|| f['resolved-ref'] != ref`): `HL-C2 another ref: each of the four named [E]`.

## Gate (tool/ci)
`dart test` -> +76 All tests passed; `dart analyze --fatal-infos ...` -> No issues found; `dart format ... --set-exit-if-changed` -> 0 changed, exit 0.

## Files
tool/ci/lib/host_lock.dart, check_host_lock.dart, test/host_lock_test.dart, test/scripts_test.dart.

## Deviations
1. Brief's SC16 name is taken (existing "SC16 every live package is in the CI matrix"); mine is SC21. Used the file's `dartRun` helper.
2. Added HL-C3b (see M-LK1).
3. Header comment/usage reworded per brief; no Dart construct needed changing (pattern `case ... when` compiles on 3.13.5).

## Self-review
`--ref` with the shape `<lock> --ref <sha>` only; `a b` still exit 2 (SC13). Success line unchanged when clean. Forbidden messages print before not-from-commit ones.

## Concerns
None beyond the brief's M-LK1 premise being wrong for HL-C3. Task 6 should know SC21 exists.
