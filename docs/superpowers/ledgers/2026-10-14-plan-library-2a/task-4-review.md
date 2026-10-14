# Task 4 review (560554a2..eb369f81)

### Spec Compliance

- ✅ Spec compliant. Every file in the brief's Files list has its hunk (20 files, all under `packages/jet_cad_2d_kit/`; `git diff --name-only` filtered for anything outside the package printed nothing).
  - Check run: I pulled the 13 whole-file code blocks out of the brief (5 lib files, plan_kit.dart, 5 test files, 2 fixtures) and compared each with the file at eb369f81, ignoring whitespace. All 13 are identical. The implementer's "transcribed verbatim, only `dart format` reflow" is true.
  - The modify-type hunks match the brief's diffs line for line: `kit_ids.dart` (`_codeId`, `isCodeId`), `kit_problem.dart` (the seven codes after `localeUndeclared`), `plan_kit_test.dart` (K1 grown, PT14-PT18), `kit_ids_test.dart` (I5), `pubspec.yaml` (`jet_cad_2d_flutter: ^0.7.2` after `jet_cad_2d`), and the barrel (five exports plus the doc).
  - Shared interfaces:
    - Every public name and signature matches the global-constraints block: `PlanType` constructor and its erased operations, `TypeGuard.wrap<T>`, `PlanToolSettings.fieldsOf(..., {required String toolId})`, `PlanTool`, `KitWords`, `Disposable`, `PlanServices` (all 8 members), `AttachmentProvider`, `AttachmentRegistry`, `KitDiagnosticCode` (11 values, in order), `KitDiagnostic`, and PlanKit's `types`/`tools`/`attachments`/`propertyIds`.
    - `AttachmentQuery`'s `mirrored` and `mayRotate` are required (diff 120-121), as the Task 4 additions line asks.
  - Spec P1 covariance (diff 652-690):
    - `section`, `title` and `colour` are private, set through the const initializer list.
    - The public `fromJson` (`ComponentFactory<T>` = `T Function(...)`), `parametric`, `properties` and `grips` hold `T` only in covariant positions.
    - `registerInto` calls `catalog.register<T>` (diff 698), and PT1 pins it with `objectsOf<Slab>`/`<Post>`/`<Component>`.
  - Spec P1, `shared` keyed by kit and type: the contract only documents it (`plan_services.dart`, diff 535-539, "Keyed by (kit, `T`)"). The implementation is Task 8's.
  - Spec P4 codes: all seven are present (diff 852-858).
  - Purity:
    - `authoring.dart` exports only `src/authoring/*` and `src/model/model.dart` (checked at eb369f81).
    - The model files gained no imports.
    - `kit_diagnostic.dart` imports only `meta`.
  - Kit independence: the pubspec gains only `jet_cad_2d_flutter`, and neither `jet_cad_2d_plan` nor any kit is named.
  - Commit: the trailer is `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - Mutations: the report lists 30 named mutations, the same set as the brief's 30 `M-` entries (counted).
- ⚠️ Cannot verify from diff:
  - **Reserved kit ids `plan` and `jetcad`.** `PlanKit.validate` does not report `reservedKitId`. This is deliberate (the brief says kit-set problems are Task 6's, and spec line 501 lists reserved ids as kit-set errors). The controller should confirm that Task 6's `validateKitSet` reports it.
  - **`shared` keyed by (kit id, type).** This is a doc contract here. Check it in Task 8.
  - **Test output and mutations.** The quoted output (`+297`, analyze clean, `check_kit_deps`) and the 30 red runs are the implementer's claims. I did not re-run them, per the review rules.

### Strengths

- The covariance design does what spec P1 requires:
  - Every operation that is typed by `T` runs inside the class over its own `T` (`fieldsOf`, `commitField`, `recolour`, `sectionFor` and `registerInto`, diff 694-772).
  - PT1/PT4/PT10 pin `T` through the VM: `isA<SetComponentCommand<Slab>>`, and the store is keyed by `Slab`.
- `commitField` binds the field again by `identical(spec, field.spec)` (diff 749-760). It closes the stale-field hazard the panel will hit (PT5), and refuses a field of another type, which matching by id would have accepted (PT6, M-PT6).
- `validate` collects the needed words in one insertion-ordered set (diff 370, 389, 411, 420, 430). A word that both a locale and a declaration need is reported once (PT18), and the words of an id that was refused are not required.
- The fixtures follow the testing bar:
  - Objects sit off the origin in rotated groups (`slabAt`, `postAt`) with values that are not defaults (980.5, 2400.75, `'teal'`).
  - Two different `T`s and two different `S`s are held through the erased static types.
- `AttachmentQuery` copies `exclude` into an unmodifiable set and copies its `Vector2` (pinned by PT20).

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

None.

#### Minor (Nice to Have)

1. **`lib/src/kit/attachment.dart:110-125, 166-173`: the immutability claim is not true.**
   - The doc says "the query never changes after it is made", and both classes are `@immutable`. But `pointer` and `marker` are public mutable `Vector2`s.
   - Copying protects against the caller's own vector, not against a reader: `query.pointer.sub(x)` (vector_math's in-place style) changes the query.
   - Why it matters: `AttachmentRegistry.attach` hands one query to every provider of every kit. One kit's provider could then change what another kit's provider sees, which crosses the kit isolation that P4 draws.
   - Fix options:
     - make the fields private behind getters that return a copy (an allocation per read, off the frame path);
     - or weaken the doc to "callers must not mutate";
     - or have Task 14's registry give each provider its own copy.
2. **`lib/src/kit/plan_kit.dart:424-433` and `:342-347`: the settings-less tool path is never run.**
   - Every `PlanTool` in the tests has settings (`test/support/tool_fixtures.dart:42,67`, the only constructions), so `validate` and `propertyIds` never see `settings == null`, the constructor's default.
   - A mutation that drops `&& tool.settings != null` (leaving `tool.settings!`) stays green, although it would throw on any real read-only tool.
   - This is the degenerate-fixture trap in CLAUDE.md. Fix: add one tool without settings to `codeKit`'s default list.
3. **`lib/src/kit/plan_type.dart:747-761`: no test commits a field whose enabled state has since changed.**
   - `commitField` binds again, so a field read while disabled and committed after it was enabled should succeed, and the reverse should be refused.
   - PT6 covers only the out-of-range refusal. A mutation that keeps the old field's enabled state is not caught here.
   - The binding itself is Task 3's and is tested there, so this is coverage depth, not a defect.
4. **`lib/src/kit/plan_kit.dart:338-347`: `propertyIds` can hold duplicates, and its doc does not say so.**
   - When a tool and a type share an id (the natural `test.slab` type with a `test.slab` tool), the same id appears twice. PT14 pins `'test.slab.width'` and `'test.slab.finish'` twice.
   - Task 5's `conformance` takes this list. Either dedupe it, or document "may repeat when a tool and a type share an id", so Task 5 does not count or report twice.
5. **`lib/src/kit/plan_type.dart:678-680`: the warning on `properties` is too soft.**
   - The doc says the list is "safe to list" through `PlanType<Component>`. It does not say that reading a spec's function-typed members through that view (`enabled`, `ChoiceProperty.read`/`write`) fails the VM's covariance check.
   - A stronger sentence would keep Task 6 and later readers on `id`, `gate`, `values` and `segmentOf`.
6. **`lib/src/kit/plan_kit.dart:426-430`: a small inconsistency.**
   - `validate` uses `tool.settings != null` and then `tool.settings!`, while `propertyIds` (diff 345) uses `if (tool.settings case final settings?)`.
   - The same pattern in both places would read better and remove the `!`.

### Assessment

**Task quality:** Approved

**Reasoning:**
- The diff is a faithful, verbatim transcription of a brief whose design meets spec P1's covariance rule, P3's attachment types and P4's codes.
- Every behaviour test names a mutation, and the fixtures avoid the identity and origin traps.
- The remaining items are a documentation claim the code does not keep (attachment immutability) and two coverage gaps (a tool without settings, a field whose enabled state changes). None of them blocks this task.
