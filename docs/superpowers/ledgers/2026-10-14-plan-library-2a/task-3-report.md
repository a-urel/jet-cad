# Task 3 report

Status: DONE. Commit 560554a2 (BASE 7ba09b31), trailer "Co-Authored-By: Claude Opus 5.5" per dispatch-common.

## Implemented
properties.dart (PlanGate, ValueUnit, sealed PropertySpec + 8 kinds, PropertyField, _BoundField), colour.dart (ColourTarget), two barrel exports, P9 purity test, properties_test.dart (PS1-PS18), code_fixtures.dart, CHANGELOG bullet. Code transcribed verbatim from the brief (extracted by line range, not retyped).

## TDD
RED (lib files moved aside, tests + P9 added): `lib/jet_cad_2d_kit.dart:10:1: Error: Error when reading 'lib/src/kit/colour.dart': No such file or directory`; `test/kit/properties_test.dart:17:1: Error: Type 'PropertyField' not found.`; `Method not found: 'LengthProperty'`.
GREEN: `flutter test test/kit/properties_test.dart test/invariants` -> `+30: All tests passed!` (PS1-18, P1-P9, DOC).

## Mutations (committed files; each reverted by git checkout, `git diff --quiet` exit 0 confirmed in every case; every pattern matched exactly once)
All 25 red (rc=1), failing evidence:
- M-PS1 "Expected: throws ArgumentError with name: 'id' / Actual: Closure => PropertySpec<Slab>"
- M-PS2a/b name 'min' not thrown; M-PS3 'decimals'; M-PS4a/b 'values'; M-PS5 'maxLength'
- M-PS6a/c name 'width' not thrown; M-PS6b red in PS6 (exclusive-min makes the inclusive 300 commit refuse)
- M-PS7, M-PS8a, M-PS13: Expected Slab(...) / Actual Slab(...) differ in value
- M-PS8b red in PS8 (9.04 refused)
- M-PS9 "threw _TypeError: type 'String' is not a subtype of type 'Finish' in type cast"; M-PS10 same for bool
- M-PS11 'label' not thrown; M-PS12 "Expected: null / Actual: Closure (Object?) => Slab"
- M-PS14 "Expected: throws StateError"; M-PS15a "Expected: empty / Actual: [Slab...]"; M-PS15b "Expected: [Slab(2400.75...)] / Actual: []"
- M-PS16 "Expected: throws ArgumentError with name: 'value'" (TypeError instead)
- M-PS17 "type '(Slab) => double' is not a subtype of type '(Object?) => double'"
- M-P9 "Expected: empty / Actual: ['lib/src/kit/colour.dart: package:flutter/foundation.dart']"

## Gates (packages/jet_cad_2d_kit)
- dart format .: 0 changed; `dart format --output=none --set-exit-if-changed .` exit 0
- flutter test: `+272: All tests passed!`
- flutter analyze: `No issues found!`
- git status: only this task's 7 files; no analysis_options.yaml touched.

## Files
packages/jet_cad_2d_kit/{lib/src/kit/properties.dart, lib/src/kit/colour.dart, lib/jet_cad_2d_kit.dart, test/kit/properties_test.dart, test/support/code_fixtures.dart, test/invariants/purity_test.dart, CHANGELOG.md}

## Deviations from the brief
None. The brief's code compiled and passed unchanged.

## Self-review
authoring.dart unchanged; the two new files import only meta (colour) / nothing (properties). Fixtures are off defaults.

## Concerns
None blocking. The mutation script lived in the session scratchpad, not the repo.
