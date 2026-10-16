# Task 6 report: liveTypeIdOf and FakePlanServices (spec 3a C1.5, C1.11)

Status: DONE. Commit `690e36e0 feat(kit): liveTypeIdOf and FakePlanServices (spec 3a C1.5, C1.11)` on feat/architecture-kit (parent c91c046a).

## Implementation summary
- `jet_cad_2d_kit/lib/src/kit/plan_services.dart`: `PlanServices` gains `String? liveTypeIdOf(Handle handle)` with the brief's doc comment, after `symbolsState`.
- `jet_cad_2d_kit/lib/testing.dart` (new public library) exports `lib/src/testing/fake_plan_services.dart` (new): `FakePlanServices` exactly as the brief's code (real `SpatialIndex(document)`, `CameraController` at `Transform2(scale,0,0,-scale,0,0)`, `KitNamesWords(names, () => locale, decimalSeparator: ...)`, `settingsOf` reading the given map live with ArgumentError refusals, `shared` one per T with re-entry StateError and reverse-order disposal, `symbolDefinition` null, `symbolsState` ready, `liveTypeIdOf` = frozen ? null : catalog?.typeIdOf). `dispose()` releases shared Disposables (last made first), the index, the camera and the ValueNotifier; idempotent. Imports only flutter/foundation, jet_cad_2d, jet_cad_2d_flutter and the kit's own sources (check_kit_deps green).
- `jet_cad_2d_plan/lib/src/controller/services.dart`: `ServicesHost` gains `ParametricCatalog get catalog`; `KitServices.liveTypeIdOf` = null when in `session.frozen`, else `_host.catalog.typeIdOf(session.document, handle)`.
- `jet_cad_2d_plan/lib/src/controller/plan_controller.dart`: `_Host.catalog => _c.catalog`.
- Docs: `docs/kits.md` §10.6 table row + paragraph on `FakePlanServices`; contract spec 3a amendments bullet (D-40: isLocked, allows, settings listenable not added).

## Step 1 precondition
`git status --short` clean. `grep -rn -E "implements (PlanServices|ServicesHost)" packages/` →
KitServices (services.dart:33), _Host (plan_controller.dart:203), and the five noSuchMethod fakes
(kit test/kit/plan_type_test.dart:34 `FakeServices`, kit test/kit/object_view_test.dart:18 `_Services`,
plan test/tools/plan_symbol_tool_test.dart:347, test/tools/move_resolver_test.dart:19,
test/attach/attachment_registry_test.dart:15). No other implementer; each contains `noSuchMethod`, all compile unchanged.

## TDD evidence
RED (kit): `cd packages/jet_cad_2d_kit && flutter test test/testing/fake_plan_services_test.dart`
```
test/testing/fake_plan_services_test.dart:11:8: Error: Error when reading 'lib/testing.dart': No such file or directory
test/testing/fake_plan_services_test.dart:59:15: Error: Method not found: 'FakePlanServices'.
```
First GREEN attempt failed 4 tests (LS-fake-2,3,4,6) with `UnregisteredComponentError(Slab): call registry.register first` at `test/support/plan_type_fixtures.dart 106:7 objectDocument` (see Deviation 1). After the fix: `00:00 +6: All tests passed!`

RED (plan): `flutter analyze` → `error • Missing concrete implementation of 'PlanServices.liveTypeIdOf'. ... • lib/src/controller/services.dart:33:13`; `flutter test test/controller/live_type_test.dart` → `lib/src/controller/services.dart:33:13: Error: The non-abstract class 'KitServices' is missing implementations for these members:`
GREEN (plan): `00:00 +1: All tests passed!`

Doc snippets: `flutter test test/invariants/doc_snippets_test.dart` → `00:00 +3: All tests passed!`

## Gates (run before commit)
- jet_cad_2d_kit: `flutter test` → `00:06 +400: All tests passed!`; `flutter analyze` → `No issues found!`; `dart format --output=none --set-exit-if-changed .` → exit 0.
- jet_cad_2d_plan: `flutter test --enable-vmservice` → `02:06 +1531: All tests passed!`; `flutter analyze` → `No issues found!`; format → exit 0.
- `dart run tool/ci/check_kit_deps.dart` → `kit dependencies: 1 package(s) checked, none names the plan library or another kit`, exit 0.
- `dart pub publish --dry-run` (kit, after commit) → `Package has 0 warnings.`
- `git status --short` after commit and after mutations: empty.

## Mutation results (committed code; each reverted with `git checkout -- <file>`, `git diff --quiet -- <file>` exit 0)
| Mutation | Test | Red line |
|---|---|---|
| M-LS-1 delete frozen check (services.dart) | LS-frozen | `Expected: null` / `Actual: 'box.square'` |
| M-LS-fake-1a index over DraftDocument.empty() | LS-fake-1 | `Expected: true` / `Actual: <false>` (identical(s.index.document, doc)) |
| M-LS-fake-1b no y flip | LS-fake-1 | `Expected: Vector2:<[1000.0,500.0]>` / `Actual: Vector2:<[1000.0,-500.0]>` |
| M-LS-fake-1c objectSnap always true | LS-fake-1 | `Expected: false` / `Actual: <true>` |
| M-LS-fake-2a locale fixed to en | LS-fake-2 | `Expected: Locale:<tr>` / `Actual: Locale:<en>` |
| M-LS-fake-2b separator not passed | LS-fake-2 | `Expected: ','` / `Actual: '.'` |
| M-LS-fake-3 `return _settings[toolId] as S;` | LS-fake-3 | `Expected: throws <Instance of 'ArgumentError'>` / `Which: threw _TypeError:<type 'double' is not a subtype of type 'String' in type cast>` |
| M-LS-fake-3b `Map.of(settings)` | LS-fake-3 | `Expected: <980.25>` / `Actual: <1250.5>` |
| M-LS-fake-4a delete `_shared[T] = made;` | LS-fake-4 | `Expected: true` / `Actual: <false>` |
| M-LS-fake-4b `_made` not reversed | LS-fake-4 | `Expected: ['faces', 'bands']` / `Actual: ['bands', 'faces']` |
| M-LS-fake-4c delete dispose loop | LS-fake-4 | `Expected: ['faces', 'bands']` / `Actual: []` |
| M-LS-fake-5 frozen set not consulted | LS-fake-5 | `Expected: null` / `Actual: 'test.post'` |
| M-LS-fake-6 registry ignored | LS-fake-6 | `Expected: true` / `Actual: <false>` |
| X-reentry (extra) `_making.add(T);` without the throw | LS-fake-4 | `Expected: throws <Instance of 'StateError'>` / `Which: returned Duration:<0:00:00.000000>` |
| X-after-dispose (extra) delete the `_disposed` throw | LS-fake-4 | `Expected: throws <Instance of 'StateError'>` / `Which: returned <Instance of '_Bands'>` |

M-LS-fake-2b's pattern: `dart format` broke the initializer across lines, so the deleted text is `,\n            decimalSeparator: () => decimalSeparator` (same intended mutation).

## Files changed
- packages/jet_cad_2d_kit/lib/testing.dart (new)
- packages/jet_cad_2d_kit/lib/src/testing/fake_plan_services.dart (new)
- packages/jet_cad_2d_kit/lib/src/kit/plan_services.dart
- packages/jet_cad_2d_kit/test/testing/fake_plan_services_test.dart (new)
- packages/jet_cad_2d_plan/lib/src/controller/services.dart
- packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart
- packages/jet_cad_2d_plan/test/controller/live_type_test.dart (new)
- docs/kits.md
- docs/superpowers/specs/2026-10-13-kit-contract-design.md

## Deviations
1. Brief defect: LS-fake-2, -3, -4, -6 called `objectDocument(const [])`, but the fixture always adds a `Slab` and a `Post` (`plan_type_fixtures.dart:106-107`), so with no types registered it throws `UnregisteredComponentError(Slab)`. Fixed to `objectDocument([slabType(), postType()])` (the same call LS-fake-1 and -5 use). No assertion changed; mutation strength unchanged (all four tests went red under their mutations); the fixture is now the turned, off-origin slab/post document throughout.
2. docs/kits.md paragraph: the brief's prose given inside a single code span; I wrapped the identifiers (`package:jet_cad_2d_kit/testing.dart`, `FakePlanServices`, `PlanServices`, `KitNames`) in backticks, matching the file's style. Words unchanged.
3. M-LS-fake-2b pattern adjusted for the formatter's line break (see above).

## Concerns
- `FakePlanServices.dispose` releasing the index, camera and `_symbolsState` has no red mutation (no test observes a disposed SpatialIndex/CameraController/ValueNotifier); the brief names none. The shared-object part of dispose is covered (4b, 4c).
- `settingsOf`'s separate `value == null` branch is message-only: without it a null value still fails `is! S` and throws ArgumentError, so no test can tell them apart (equivalent mutant except for the message).
- `_Host.catalog` has no dedicated mutation; LS-frozen's live answers (`healthy` → 'box.square') would go null if it returned a different empty catalog, so it is covered indirectly.
