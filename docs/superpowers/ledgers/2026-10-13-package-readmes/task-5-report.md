# Task 5 report: check_screenshots.dart

Status: DONE. Commit: see `git log -1` on feat/package-readmes ("feat(ci): check_screenshots, ...").

## TDD
- RED: `dart test test/screenshots_test.dart` before lib existed: `Failed to load ... Error when reading 'lib/screenshots.dart': No such file or directory`.
- GREEN: SS1-SS13 `+13: All tests passed!`. Whole `tool/ci`: `+90: All tests passed!`.

## Mutations (copy aside, restore, cmp; all restored identical)
- M-SS-a `maxEntries = 11`: SS2 red (`+12 -1`, failing: SS2 an eleventh entry).
- M-SS-b `description.length < 9`: SS3 red (`+12 -1`).
- M-SS-c base `main/packages/$package/` instead of the tag: SS9 red (also SS3, SS11 red: their good READMEs no longer match the base).

## Command over the real packages (expected red until Task 8, ruling R3)
```
jet_cad_2d_flutter: no screenshots: entry
jet_cad_floor_plan: no screenshots: entry
exit=1
```

## Gate
`dart test` +90 pass; `dart analyze --fatal-infos lib test check_screenshots.dart` no issues; `dart format ... --set-exit-if-changed` exit 0 (after `dart format` of my three files); `dart run tool/ci/check_guide.dart`: all 56 code blocks are in the host probe.

## Files
tool/ci/pubspec.yaml (yaml ^3.1.3), tool/ci/lib/screenshots.dart, tool/ci/check_screenshots.dart, tool/ci/test/screenshots_test.dart, .github/workflows/ci.yml (analyze list, format list, new step).

## Self-review / concerns
- The brief's code was used verbatim except `dart format` whitespace rewrapping (lib and test). Mutations were run on the pre-format file; the logic is identical.
- No test/impl string mismatch found; no brief expectation altered.
- `flutter pub get` touched no analysis_options.yaml (git status clean of it); no pubspec.lock appeared.
- CI step runs red until Task 8 adds screenshots: entries and README images.
