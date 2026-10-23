# Task 1 report

Status: DONE_WITH_CONCERNS. Commit 8fe41293661cec43272ae0b199fe7ec4de17de54
(`build(plan): shadcn_ui ^0.57.1 and the API boundary check`).

## Changes
- packages/jet_cad_2d_plan/pubspec.yaml: + shadcn_ui ^0.57.1, + lucide_icons_flutter ^3.1.25. SDK floors NOT raised (see concern 1).
- apps/dev_harness/pubspec.yaml: shadcn_ui ^0.55.0 -> ^0.57.1. No lib/ change needed (flutter analyze clean, tests green). Floors not raised.
- tool/ci/lib/api_boundary.dart (apiBoundaryProblems, resolveBarrel), tool/ci/check_api_boundary.dart, tool/ci/test/api_boundary_test.dart (AB1-AB6).
- .github/workflows/ci.yml: analyze + format lists, and a step beside check_guide.
- Resolved (root pubspec.lock): shadcn_ui 0.57.3, lucide_icons_flutter 3.1.25. No dependency_overrides.

## Commands and real last lines
- tool/ci: `dart test` -> `01:01 +120: All tests passed!`; `dart analyze --fatal-infos <ci list + check_api_boundary.dart>` -> `No issues found!`; `dart format --output=none --set-exit-if-changed <ci list>` -> `Formatted 26 files (0 changed)`.
- Red first: with lib/api_boundary.dart moved away, `dart test test/api_boundary_test.dart` -> `Some tests failed. ... test/api_boundary_test.dart: loading test/api_boundary_test.dart` (no function). Then restored. (Implementation and tests were written together; the red was demonstrated afterwards.)
- After implementing: `00:59 +5 ... 01:09 +6: All tests passed!` for the file.
- `dart run tool/ci/check_api_boundary.dart` -> `jet_cad_2d_plan: no exported type mentions shadcn_ui or lucide_icons_flutter`, exit 0.
- Mutation M-AB: added `import 'package:shadcn_ui/shadcn_ui.dart' show ShadThemeData;` and `final ShadThemeData? shad = null;` to PlanEditor. CLI: `jet_cad_2d_plan: PlanEditor.shad: type ShadThemeData (package shadcn_ui)`, exit 1. AB6: `Actual: ['PlanEditor.shad: type ShadThemeData (package shadcn_ui)']` ... `test/api_boundary_test.dart: AB6 the real jet_cad_2d_plan barrel is clean`. Reverted with `git checkout packages/jet_cad_2d_plan/lib`.
- packages/jet_cad_2d_plan: `flutter test` -> `02:46 +1631 ~7: All tests passed!`; `flutter analyze` -> `No issues found!`; format `Formatted 324 files (0 changed)`.
- apps/dev_harness: `flutter analyze` -> `No issues found!`; `flutter test` -> `+10: All tests passed!`; format 0 changed.
- packages/jet_cad_2d_integration: `flutter test` -> `02:09 +240: All tests passed!`.
- Host probe, `tool/ci/host_probe.sh file://$PWD <HEAD>`: pub get ok, lock check ok (`81 packages, none of flutter_scene, ...`), `flutter analyze` ok, `flutter build web` ok, then `host probe: a build hook ran (.dart_tool/hooks_runner exists)`, exit 1. See concern 2.

## Concerns
1. The brief's `environment.sdk: ^3.11.0` for jet_cad_2d_plan was tried and NOT kept. Raising the package's language version to 3.11 switches `dart format` to the tall style (`dart format --set-exit-if-changed`: 306 of 324 files would change, including canvas/, move_resolver.dart, service_tool.dart which the alignment-guides branch owns) and adds 63 analyzer infos (45 unnecessary_underscores, 18 use_null_aware_elements). Tests passed at 3.11. With the floors left at ^3.6.0 / flutter >=3.44.0 (and dev_harness ^3.5.0), `flutter pub get` resolves shadcn_ui 0.57.3 against the local SDK and everything is green. Decision needed: keep floors (current) vs raise them with a separate repo-wide reformat + lint pass task. Publishing note: a published plan 0.9.x with sdk ^3.6.0 depending on shadcn_ui (needs >=3.11) resolves only on hosts with SDK >=3.11 (pub reports it as a solver error for older hosts).
2. Host probe red, caused by shadcn_ui itself: shadcn_ui -> universal_image -> extended_image_library -> path_provider -> path_provider_foundation -> objective_c. objective_c is a native-assets hook package, so `.dart_tool/hooks_runner/objective_c` exists after the web build and `tool/ci/host_probe.sh`'s "a build hook ran" check fails. No flutter_scene / GPU package is in the lock (that check passed). I did not change the script (it is a guard policy decision): options are to narrow the check to hooks other than objective_c, or accept. Also the probe's pubspec.yaml.in has `sdk: ^3.6.0`, which resolved fine in the probe.
3. AB5-style coverage: types the library does not export are not walked (by design in the brief). Supertypes are checked via allSupertypes of every exported type.
4. `flutter pub get` rewrote no analysis_options.yaml that is staged; git status was checked before commit and only intended files were committed.

## Fix round 1
Commit 9efdfe4e16987c1d902cbcdd8e4b84729eaf421c (`ci: the host probe allows objective_c's build hook`). Floors unchanged (ruling 1).
- tool/ci/host_probe.sh: the hook check now loops over .dart_tool/hooks_runner/* and hooks_runner/shared/* (Flutter's layout: <pkg> and shared/<pkg>), failing with `host probe: a build hook ran (<name>)` for every entry whose basename is not exactly objective_c (the `shared` directory itself is skipped). Header comment updated per the ruling. Success message ("no GPU renderer, no build hook") kept, as scripts_test asserts it.
- tool/ci/test/scripts_test.dart SC15: the hook-ran test now creates hooks_runner/flutter_scene and expects `a build hook ran (flutter_scene)`; new tests: objective_c in both layouts is allowed (exit 0), `shared/objective_c_x` is refused and named.
- Gates: shellcheck host_probe.sh -> no output, exit 0; tool/ci `dart test` -> `01:14 +122: All tests passed!`; analyze -> `No issues found!`; format -> `Formatted 26 files (0 changed)`.
- Probe at the committed HEAD: `host probe: no GPU renderer, no build hook; build/web is  46M` / `exit 0`.
- Mutation (allowed name `objective` instead of `objective_c`): the script's post-build block run in the real probe dir -> `host probe: a build hook ran (objective_c)` (printed for both layouts), `exit 1`; `dart test test/scripts_test.dart -n SC15` -> `Failing tests: test/scripts_test.dart: SC15 host_probe.sh after the build objective_c's hook, in both layouts, is allowed`. Reverted with git checkout (clean tree). The mutation was run on the post-build block against the existing probe build, not a full re-run of the 4-minute probe.
