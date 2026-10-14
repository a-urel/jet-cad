# Task 6 review: jet_cad_2d_plan scaffold, validateKitSet/KitSet, test kits, harness, CI (06ee312e..aeb5e610)

### Spec Compliance

- ✅ Spec compliant.
  - Package scaffold: `packages/jet_cad_2d_plan/pubspec.yaml` (diff 455-493): 0.8.0, `resolution: workspace`, `sdk: ^3.6.0`, `flutter: ">=3.44.0"`. Deps are flutter, jet_cad_2d ^0.7.2, jet_cad_2d_flutter ^0.7.2, jet_cad_2d_kit ^0.1.0, meta, vector_math. There is no `jet_cad_floor_plan` and no `jet_cad_restaurant_symbols`.
  - `analysis_options.yaml` is new and belongs to this package (diff 301-325). No existing `analysis_options.yaml` is in the diff's file list (diff 8-21).
  - Root `pubspec.yaml` workspace entry sits right after `jet_cad_2d_kit` (diff 2108-2132).
  - CI: one entry in the `package` matrix (`ci.yml` +45-46) and one in the `publishable` matrix (`ci.yml` +176). Those are the only 3 lines added.
  - Spec P4 "The kit set": `kit_set.dart` (diff 337-454) collects every problem before it throws one `KitSetError extends ArgumentError` (name `kits`, one `  <code>: <message>` line per problem; `KitProblem.toString` is `'${code.name}: $message'`, `kit_problem.dart:56`). It covers:
    - reserved `plan`/`jetcad`;
    - a duplicate kit, plus duplicate type and tool ids across kits;
    - a type or tool outside its kit, through `kit.validate()` (prefixed by the kit id; KS4/KS5 assert `typeOutsideKit`/`toolOutsideKit`);
    - `typePlaceConflict`, read from the descriptor's `contributesPlace && readsPlaces`;
    - each kit's `validate()`.
  - Letters and `attachTo` kinds are not checked, as the spec requires.
  - Fidelity to the brief: I ran a token-level diff (comments normalised, trailing commas dropped) of every committed file against the brief's code blocks.
    - `kit_set.dart`, `harness.dart` and `kit_set_test.dart` match exactly.
    - `test_kit.dart` differs only by `hide Tolerance` on the material import.
    - `throwing_kit.dart` differs by `hide Tolerance` and the dropped `foundation.dart show listEquals` import.
    - These match the report's deviations 1-2. Deviation 3 (an unused import dropped from `test_kits_test.dart`) and deviation 4 (TK5 added) are visible in diff 649-748.
  - Test kit per spec "Tests" (`test_kit.dart`):
    - all eight property kinds (Length ×2, Angle, Number, Choice, Toggle, Text, ValueDisplay, Action);
    - a gate (`PlanGate.rotate` on angle);
    - a title hook (`slabTitle`), a colour target, grips (`SlabGrips`) and an escape-hatch section (`slabSection`);
    - a tool with settings (`slabTool`, `PlanToolSettings<SlabSettings>`) and a `test-edge` provider (`TestEdge`);
    - words in `en` and `tr` only, pinned by TK1 `{'en','tr'}` with key parity.
  - Throwing kit: every name in `boomHooks` has a `check(...)` call site. I checked them one by one against the 33 names:
    - all 13 overridable members of `ParametricType` (`parametric_system.dart:26-148`): `reach`, `references`, `pageKey`, `dissolves`, `generate`, `diagnose`, `placeBox`, `placeInput` and `readBox` are hooked; the rest are flags;
    - `fromJson` on all three types; the five grip hooks; the tool factory and its 7 event/paint hooks;
    - the provider factory and `attach`; `read`/`write`/`apply`; `section`/`sectionWidget`; `colourRead`/`colourWrite`; `title`.
  - That covers every row of spec P4's failure-boundary table.
  - Every behaviour test (KS1-KS9) names its mutation. TK1-TK5 are fixture sanity. The report gives a red line for each of M-KS1..M-KS9.
- ⚠️ Cannot verify from diff:
  - (a) That `PlanController(kits:)` actually calls `validateKitSet` (the spec puts the throw on the controller). That lands in Task 8.
  - (b) The runtime behaviour of `SlabTool`, `BoomTool`, `SlabGrips.drag/preview`, `TestEdge` hysteresis, `pointerAt` and `pumpApp`. They compile and analyze, but this task's tests never drive them; the report says so too. Task 8/11/14 is their first real check, and the controller should make sure those tasks drive each one.
  - (c) The publish dry run (`Package has 0 warnings.`), the `tool/ci` SC16 run, and the `check_kit_deps` result. I accept these from the report's quoted output; I did not re-run them.

### Strengths

- `validateKitSet` follows every plan decision exactly:
  - In-kit duplicates are left to `validate()` (`putIfAbsent` + `first != kit.id`), so nothing is reported twice. KS6 pins this, and M-KS6 is a well-chosen off-by-scope mutant.
  - A type repeated under a duplicate kit id is covered by `duplicateKit` alone. KS2 asserts exactly `[duplicateKit]`.
  - The conflict check reads the untyped flags, so a `PlanType<Component>` read cannot trip covariance.
- KS7 first runs a premise check that the engine itself refuses `ReaderType` (`ParametricCatalog().register` throws). That ties the descriptor check to the real engine rule.
- KS9 pins the whole message format: line by line `'  $p'`, `name == 'kits'`, and `isA<ArgumentError>`. It also pins load order across reserved, duplicate and conflict problems.
- The fixtures avoid the degenerate cases: the slab is turned 0.4 rad, groups sit off the origin (TK5: (2500, -1300), (-900, 700)), and TK5 uses a non-default separator.
- TK5 is a good addition. It is the only runtime proof of `planDocument`, `installSystem`, `addObject`, `leavesOf`, `coordsOf` and `addLine`, and it covers all three kits generating, the throwing kit included.
- The kits are real, not stubs:
  - The `SlabGrips` drag math is consistent with the grip position: the grip is at local `(cos a, sin a)·w/2`, and the drag computes `w = 2·(local·axis)`.
  - The `TestEdge` mirror check uses the contract's convention (a mirror negates `a`).
  - `KitLog` serials are per product kind.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

None.

#### Minor (Nice to Have)

1. **`test_kit.dart` (KitLog doc, brief line 188-189):** the doc gives the order as "`tool+1`, `cache+1`, `grips+1`". `SlabTool`'s initializer list runs `cache = services.shared<SlabCache>(...)` before `serial = log?.created('tool')`, so a first tool logs `cache+1` and then `tool+1`.
   - Risk: a later lifecycle test (Task 8) written from the doc will fail.
   - Fix: correct the doc example, or swap the initializer order.
2. **`test_kit.dart` `TestEdge.attach` (brief line 635-636):** the edge uses `edgeCapture` as its hysteresis radius while `keep` is its own token. The contract documents `edgeCapture` as "how near an end of a target the symbol may slide" (`attachment.dart:55-59`; in floor_plan it is the edge-snap aperture). A host passing `edgeCapture < capture` gets anti-hysteresis.
   - It is a fixture, so the choice is arbitrary.
   - Suggested fix: name the hysteresis honestly, e.g. a `keepReach` multiplier on `capture`. At minimum, Task 14 must not read the fixture as defining `edgeCapture`'s meaning.
3. **`throwing_kit.dart`, hook coverage (plan-mandated list):** the throwing kit covers every row of the spec's failure table. Some kit code the plan library will call cannot be made to throw:
   - `Tool`'s getters `isMidShape`, `cursor`, `touchPress`, `selectionPreviewTransform`, `name` and `phase` (`tool.dart`); `isMidShape` is read on `load`, Review Focus 4);
   - `dispose` on tools, grips, providers and caches;
   - the `enabled` predicates of properties;
   - `read` on any kind but `NumberProperty`;
   - tool-settings specs (`boom.tool` has no settings).

   If Task 11's guard decorates these, it has no instrument to prove them. Task 11 may add hooks, since the files are append-only for later tasks.
4. **`throwing_kit.dart` `BoomTool`:** `paintOverlay` and `paintWorldOverlay` share the hook name `toolPaint`, so a test cannot fail one without the other. This is acceptable for "guard removed" mutants: whichever overlay is unguarded throws. It does blur which path a failure came from.
5. **Spec "Tests":** the spec places "a second type that both contributes and reads places" in the test kit. It lives in a separate `conflictKit()` (id `test`, type `test.reader`).
   - This follows the brief, and it is necessary: `testKit` must load.
   - It is a deliberate plan-level reshaping, not a defect. Record it in the results note.
6. **`kit_set_test.dart` KS5/KS7:**
   - KS5 does not check the `duplicateTool` message (only the code count). KS4 does check the `duplicateType` message.
   - KS7 checks only that the conflict message contains `test.reader`, not the `<kit id>: ` prefix.
   - A mutation that drops either message's ids would survive. This is coverage breadth only.
7. **Report concern 2 (page units "meters"):** this is not a defect. `jet_cad_floor_plan/lib/src/new_document.dart:25-43` documents the default page as "A4 landscape at 1:50 in metres", and `planDocument` matches `newDocument` minus the DASHED record. The plan defers the DASHED record to sub-project 3 (plan line 10304). The concern can be closed.

Checks run (named risks):
- whether `boomHooks` covers every `ParametricType` member (grep of `parametric_system.dart:26-148`);
- the `Tool` interface members (`jet_cad_2d_flutter/lib/src/tool.dart`);
- the `AttachmentQuery` field semantics (`jet_cad_2d_kit/lib/src/kit/attachment.dart`);
- the `KitProblem.toString` format behind KS9's line assertion (`kit_problem.dart:56`);
- whether `planDocument` matches floor_plan's new document (`new_document.dart`);
- whether any other workflow or `tool/ci` list names `jet_cad_2d_kit` and so would need the new package too (only `ci.yml`, both entries added).

### Assessment

**Task quality:** Approved

**Reasoning:** The kit-set validation is correct, complete against spec P4, and every rule is pinned by a test that a named mutation turns red. The test-kit, throwing-kit and harness API matches the brief byte for byte, apart from the two justified import fixes. The kits are real implementations, and TK5 proves the harness end to end. The remaining items are doc and fixture-semantics polish, plus hook-coverage additions that Task 11 can make.
