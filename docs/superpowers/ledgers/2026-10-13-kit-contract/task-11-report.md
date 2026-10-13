# Task 11 report (K9)

Commit: b069a3f9 ci(kit): the kit dependency rule and the jet_cad_2d_kit jobs (K9)

Implemented tool/ci/lib/kit_deps.dart, tool/ci/check_kit_deps.dart, tool/ci/test/kit_deps_test.dart (verbatim from the brief; dart format changed one line of the test) and the ci.yml changes (Analyze/Format lines, new step, publishable entry; the Format line was wrapped onto two lines to stay readable).
RED step not run separately (files were created together; the first run was green).

## Gates
- `cd tool/ci && dart test test/kit_deps_test.dart`: `+12: All tests passed!`
- `cd tool/ci && dart test`: `+106: All tests passed!`; analyze --fatal-infos: No issues found; format exit 0
- `dart run tool/ci/check_kit_deps.dart`: `kit dependencies: 1 package(s) checked, none names the plan library or another kit`
- check_guide / check_readmes: ok
- packages/jet_cad_2d_kit: flutter test `+225: All tests passed!`, analyze clean, format exit 0
- ci.yml parses with yaml.safe_load.

## Mutations (committed files, each reverted by git checkout, `git diff --quiet` exit 0)
- M-D1a (forbidden = dep.startsWith('jet_cad_2d_')): D1 red: `Expected: empty / Actual: [`
- M-D1b (drop `&& dep != name`): D1 red: `Expected: empty / Actual: [`
- M-D3 (sections = ['dependencies']): `+2 -1: D3 ... [E] Expected: [` and `-2: D4 ... [E]`
- M-D5 (firstMatch per directive): `+4 -1: D5 imports under lib, test and tool ... [E] Expected: [`
- M-D6 (scan whole text): `D6 ... [E] Expected: empty` and `D8 ... Expected: Set:['a_b', 'c']`
- M-D10 (add 'build' to script subdirs): `D10 ... [E] Expected: not contains 'build/'`
