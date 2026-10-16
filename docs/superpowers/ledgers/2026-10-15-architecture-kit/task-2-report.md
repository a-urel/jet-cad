# Task 2 report: object views for properties and sections; hidden fields (spec 3a C1.1, C1.7)

**Status:** DONE_WITH_CONCERNS. Two deviations from the brief, both small local fixes, are described below: one test assertion now measures from a different anchor, and one mutation's text did not compile as written.

**Commit:** `31c2b976 feat(kit): object views for properties and sections; hidden fields (spec 3a C1.1, C1.7)`. The parent is `d742f063` (Task 1). The commit holds the 20 files the brief's Step 9 lists, staged by explicit path. No `analysis_options.yaml` was touched, and the tree was clean after the commit and after every mutation.

## What was built

### Contract (`packages/jet_cad_2d_kit`)
- **`lib/src/model/plan_words.dart` (new):** the pure `PlanWords`, with `word` and `maybe` (ruling R-P7). `model.dart` exports it after `manifest_component.dart`.
- **`lib/src/kit/plan_services.dart`:** `KitWords implements PlanWords`. Only `locale` stays declared on `KitWords`. `KitNamesWords` is unchanged.
- **`lib/src/model/kit_problem.dart`:** adds `settingsNeedObject` after `unitKindWord`.
- **`lib/src/kit/properties.dart`:** taken from the brief. The new parts:
  - `PlanObject` and `DocumentPlanObject`. `world` is a `late final`, computed on first read from `accumulatedTransform`.
  - `PropertySpec.visible`, and the `@internal needsObject` getter.
  - `bind(..., PlanObject? object)` on every kind.
  - `LengthProperty.range`: inclusive, read at the commit; a null range refuses every value.
  - `TextDisplay`, and `PropertyField.visible` (false when `visible` says no, or when a `TextDisplay` reads null).
  - `_noObject`: binding an object-reading spec without an object is an `ArgumentError` named `object`.
- **Diff check on `properties.dart`:** I compared it with `git diff`. Every change is a member this task names, plus doc lines that mention them. One doc line changed beyond those members: the `ValueDisplay` class comment now reads "A read-only number of the owner." instead of "A read-only number: a room's area, a dimension's value." That is the brief's text, which moves the room-area example over to `TextDisplay`.
- **`lib/src/kit/plan_type.dart`:**
  - `PropertySectionBuilder<T>` is now `(BuildContext, PlanSection<T>)`, and `PlanSection<T>` is `@immutable`.
  - `fieldsOf(DraftDocument, Handle, PlanWords)` binds every spec to one `DocumentPlanObject`.
  - `commitField(DraftDocument, Handle, PropertyField, Object?, PlanWords)` binds again to the document's current object.
  - `sectionFor(..., KitWords words, PlanServices services)`.
  - `titleWordOf`, `colourOf` and `recolour` keep `CommandTarget`.
- **`lib/src/kit/plan_kit.dart`:** `validate` checks each tool's settings with `spec.needsObject` and reports `settingsNeedObject`. The doc line is added.
- **Tests:**
  - New file `test/kit/object_view_test.dart`, taken verbatim from the brief and then `dart format`ted.
  - `plan_type_test.dart`: PT10 uses the new builder form and passes `FakeServices()`. PT3 to PT6 pass the words: 11 `fieldsOf` calls and 8 `commitField` calls, with one file-level `words`.
  - `example_code_test.dart`: its calls pass the words, and it gains the `Locale` and `jet_cad_2d_kit` imports.
  - `plan_type_fixtures.dart` is unchanged.

### Plan library (`packages/jet_cad_2d_plan`)
- **`lib/src/panels/plan_property_panel.dart`:**
  - `_fieldsOrNull` and `_write` pass `c.servicesOf(kitOfKey(typeId)).words`.
  - `_textOf` and `_parse` gain a `TextDisplay()` case.
  - `_row` has a `TextDisplay` case: an `InputDecorator` around `Text(field.value as String? ?? '')`.
  - New `_shows`: a field takes no row when `visible` is false, nor when it is an object's `ActionProperty` whose gate the permissions refuse.
  - `_settingsSection` and `_objectSection` call `if (_shows(t, field))`.
  - `sectionFor` receives `c.servicesOf(kit)`.
- **Tests:**
  - New `test/support/object_kit.dart` and `test/panels/object_view_panel_test.dart`, both from the brief. One assertion in the panel test is changed; see Deviation 1.
  - `panel_kits.dart` (the disc's section) and `test_kit.dart` (`slabSection`) use the new builder.
  - `throwing_kit.dart` adds three hooks (`display`, `range`, `visible`), the `shown` and `span` specs, `grow`'s `visible`, and two words.
  - `covariance_test.dart`: three calls pass the words. Its assertions are unchanged.
- **Unexpected callers:** none. `flutter analyze` after Step 4 found errors only in the panel and in `covariance_test.dart:33,40,43`, as the brief predicted.

### Docs
- **`docs/kits.md`:**
  - §10.2's `section` row is replaced.
  - In the §10.3 table, the `LengthProperty` row now lists `range`, and a `TextDisplay` row follows the `ValueDisplay` row.
  - The first bullet gains `visible(T)`, and a new bullet about `PlanObject` and `settingsNeedObject` follows it.
  - `doc_snippets_test.dart` result: `00:00 +3: All tests passed!`.
- **`2026-10-14-plan-library-design-mode-design.md`:** a new `## Amendments` section before `## Risks`.
- **`2026-10-13-kit-contract-design.md`:** a second bullet in the "Amendments from sub-project 3a" section.

## TDD evidence

**Step 1 precondition, at d742f063:**
- Kit `test/kit/`: `00:01 +81: All tests passed!`
- Plan `test/panels/property_panel_test.dart`: `00:03 +14: All tests passed!`

**RED, kit** (`flutter test test/kit/object_view_test.dart` before Step 3; it failed to compile). Excerpt:
```
test/kit/object_view_test.dart:38:38: Error: Type 'PlanObject' not found.
test/kit/object_view_test.dart:57:11: Error: No named parameter with the name 'range'.
test/kit/object_view_test.dart:58:7: Error: Method not found: 'TextDisplay'.
test/kit/object_view_test.dart:113:24: Error: Method not found: 'DocumentPlanObject'.
test/kit/object_view_test.dart:124:20: Error: The getter 'visible' isn't defined for the type 'PropertyField'.
test/kit/object_view_test.dart:245:7: Error: 'PlanSection' isn't a type.
test/kit/object_view_test.dart:315:27: Error: Member not found: 'settingsNeedObject'.
test/kit/object_view_test.dart:351:32: Error: The getter 'needsObject' isn't defined for the type 'PropertySpec<Object>'.
```

**GREEN, kit** (`dart format . && flutter test test/kit/`): `00:01 +91: All tests passed!`. That is 81 plus the 10 PO tests.

**Step 4 analyze** (plan, after the support kits changed). Exactly the predicted errors:
```
error • 3 positional arguments expected by 'fieldsOf', but 2 found ... plan_property_panel.dart:336:68
error • ... isn't exhaustively matched ... 'TextDisplay<Object?>()' ... plan_property_panel.dart:385:5 / :430:5 / :705:5
error • 5 positional arguments expected by 'commitField', but 4 found ... plan_property_panel.dart:546:60
error • 6 positional arguments expected by 'sectionFor', but 5 found ... plan_property_panel.dart:842:38
error • ... 'fieldsOf' ... test/controller/covariance_test.dart:33:45 ; 'commitField' ... :40:67 ; 'fieldsOf' ... :43:34
```

**RED, plan** (`flutter test test/panels/object_view_panel_test.dart` before Step 6; it failed to compile in the panel):
```
lib/src/panels/plan_property_panel.dart:336:49: Error: Too few positional arguments: 3 required, 2 given.
lib/src/panels/plan_property_panel.dart:546:27: Error: Too few positional arguments: 5 required, 4 given.
lib/src/panels/plan_property_panel.dart:836:48: Error: Too few positional arguments: 6 required, 5 given.
lib/src/panels/plan_property_panel.dart:385:19: Error: The type 'PropertySpec<Object?>' is not exhaustively matched by the switch cases since it doesn't match 'TextDisplay<Object?>()'.
(and :430:19, :705:19)
```

**First GREEN attempt, plan:** 7 of 8 passed. PO-hidden failed with `Expected: a value less than or equal to <440.0>  Actual: <460.0>`; see Deviation 1. After the fix: `00:02 +8: All tests passed!`.

**Step 6 run:** `flutter analyze` gave `No issues found!`. `flutter test test/panels/ test/kits/ test/controller/covariance_test.dart` gave `00:13 +258: All tests passed!`. No existing test counts `boom.block`'s rows or fields.

## Gates (Step 8, after `dart format .`)
- `jet_cad_2d_kit`:
  - `flutter test`: `00:05 +378: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 3.4s)`
  - `dart format --output=none --set-exit-if-changed .`: `Formatted 80 files (0 changed)`, exit 0.
- `jet_cad_2d_plan`:
  - `flutter test --enable-vmservice`: `02:00 +1503: All tests passed!`, exit 0.
  - `flutter analyze`: `No issues found! (ran in 3.4s)`
  - Format gate: `Formatted 288 files (0 changed)`, exit 0.
- `dart run tool/ci/check_kit_deps.dart`: `kit dependencies: 1 package(s) checked, none names the plan library or another kit`, exit 0.
- `git status --short` before the commit: exactly the 20 files of Step 9.

## Mutations (run on the committed files)

Each mutation was applied, its test run and seen red, then reverted with `git checkout -- <file>`. `git diff --quiet -- <file>` exited 0 after every revert.

| Mutation | File | Red test(s) and the quoted line |
|---|---|---|
| M-PO-world | properties.dart | PO-object: `Expected: a numeric value within <1e-9> of <280.0>  Actual: <-120.5>  Which: differs by <400.5>` |
| M-PO-null | properties.dart | kit PO-display: `Expected: false  Actual: <true>`. Plan PO-panel-display: `Expected: no matching candidates  Actual: _KeyWidgetFinder:<Found 1 widget with key [<'property-turn'>]` |
| M-PO-no-object | properties.dart | PO-display-no-object: `Expected: throws <Instance of 'ArgumentError'> with \`name\`: 'object' ... Which: threw _TypeError:<Null check operator used on a null value>` |
| M-PO-range | properties.dart | kit PO-range: `Which: returned Slab:<Slab(599.0 x 640.25, Bar top, teal)>`. Kit PO-fields: `Which: returned <Instance of 'SetComponentCommand<Slab>'>`. Plan PO-range: `Expected: <1250>  Actual: <3200.5>`. Plan PO-G-range also red: `Expected: <400>  Actual: <640.0>` |
| M-PO-range-null | properties.dart | kit PO-range: `Which: returned Slab:<Slab(300.0 x 640.25, Bar top, teal)>`. Plan PO-range (the stray bead): `Expected: <40>  Actual: <0.0>` |
| M-PO-visible | properties.dart | PO-visible: `Expected: false  Actual: <true>`. PO-hidden: `Found 1 widget with key [<'property-flip'>]`, where none was expected. PO-G-visible also red: `Found 0 widgets with key [<'kit-section-failed'>]` |
| M-PO-fields | plan_type.dart | PO-fields: `Invalid argument (object): reads the object it is shown for: bind it to one: "property:test.slab.width"`. PO-words also red. |
| M-PO-section | plan_type.dart | kit PO-section: `Expected: exactly one matching candidate  Actual: _TextWidgetFinder:<Found 0 widgets with text "Slab 4100": []>` |
| M-PO-words | plan_type.dart | PO-words: `Expected: 'Platte'  Actual: 'type:test.slab'` |
| M-PO-object-words | properties.dart | PO-object: `Expected: true  Actual: <false>` (the `identical(o.words, words)` check). PO-words and kit PO-section also red. |
| M-PO-pure | properties.dart | `test/invariants/purity_test.dart`: `P9 the property specs and the colour target reach no Flutter [E]  Expected: empty  Actual: [` |
| M-PO-validate | plan_kit.dart | PO-validate and PO-validate-cov: `Expected: [KitProblemCode:KitProblemCode.settingsNeedObject]  Actual: []` |
| M-PO-cov | plan_kit.dart | PO-validate-cov and PO-validate: `type '(Slab, PlanObject) => (double, double)?' is not a subtype of type '((Object, PlanObject) => (double, double)?)?'`. See Deviation 2. |
| M-PO-panel-words | plan_property_panel.dart | PO-panel-display: `Expected: 'Rail'  Actual: 'type:view.rail'` |
| M-PO-panel-row | plan_property_panel.dart | PO-panel-display: `Expected: 'R-7'  Actual: ''`. PO-G-display and PO-G-visible also red at their premise: `Expected: '400 mm at 18'  Actual: ''` |
| M-PO-hidden | plan_property_panel.dart | PO-panel-display: `Found 1 widget with key [<'property-turn'>]`. PO-hidden: `Found 1 widget with key [<'property-flip'>]` |
| M-PO-gate-hidden | plan_property_panel.dart | PO-gate-hidden: `Expected: no matching candidates  Actual: _KeyWidgetFinder:<Found 1 widget with key [<'property-flip'>]` |
| M-PO-services | plan_property_panel.dart | plan PO-section: `Expected: 'Rail 18'  Actual: 'type:view.rail 18'` |
| M-PO-G-display | properties.dart (lazy `value` via a closure on `_BoundField`) | PO-G-display: `Expected: null  Actual: BoomFailure:<BoomFailure(display)>` (`takeException`). PO-panel-display also red. |
| M-PO-G-visible | properties.dart (lazy `visible` getter, owner kept) | PO-G-visible: `Expected: null  Actual: BoomFailure:<BoomFailure(visible)>` |
| M-PO-G-range | properties.dart (`final allowed = range?.call(owner, object!);` read in `bind`) | PO-G-range: `Bad state: No element` from `textOf(tester, 'property-span')` at `object_view_panel_test.dart:231`. The section was replaced by the failed box, so the span field is gone. |
| Extra, mine (checks Deviation 1) | plan_property_panel.dart: a hidden object row replaced by `const SizedBox(height: 56)` | PO-hidden: `Expected: a value less than or equal to <64.0>  Actual: <112.0>`. The room assertion is live on its own, beyond `findsNothing`. |

## Deviations (with evidence)

1. **The PO-hidden assertion measures from the Position row** (`test/panels/object_view_panel_test.dart`).
   - **The brief's assertion:** it compared Door's absolute `dy` before and after the change: `lessThanOrEqualTo(withFlip - flipHeight)`. It failed against correct code with `Expected: <= 440.0  Actual: 460.0`.
   - **Diagnosis:**
     - In the harness, `pumpDesign` puts the panel in `SizedBox(width: 280, child: SingleChildScrollView(child: right))` inside a `Row`. A `Row` centres its children vertically by default (`design_harness.dart`, the `if (right != null)` branch).
     - The scroll view has no scroll range (`offset: 0.0, range: 0.0..0.0`). Its rect went from `Rect.fromLTRB(1160.0, 344.0, 1440.0, 596.0)` to `Rect.fromLTRB(1160.0, 372.0, 1440.0, 568.0)`: the panel lost 56 px of height and moved down 28 px.
     - Rows before: position 376, flip 440..488 (48 px button inside an 8 px top padding), door 488.
     - Rows after: position 404, door 460.
     - Measured from Position, Door moved up by exactly the Flip row's full 56 px (112 → 56). The code is right; the brief's absolute measurement is affected by the centring.
   - **Fix:** `doorBelowPosition()` = Door's `dy` minus Position's `dy`. The assertion is now `lessThanOrEqualTo(withFlip - flipHeight)` on that difference. A three-line comment explains why.
   - **Effect on the test:** the assertion's meaning ("takes no room", "moves up by its height") is unchanged. M-PO-hidden still turns it red, and the extra mutation above shows the room check is red on its own.

2. **M-PO-cov's text needs a type argument to compile.**
   - **The problem:** written as given, `spec is LengthProperty && spec.range != null` does not compile: `plan_kit.dart:134:68: Error: The getter 'range' isn't defined for the type 'PropertySpec<Object>'`. Raw `LengthProperty` means `LengthProperty<dynamic>`, which is not a subtype of `PropertySpec<Object>`, so Dart does not promote `spec`.
   - **What I ran:** `spec is TextDisplay || (spec is LengthProperty<Object> && spec.range != null)`. This is the read the mutation intends, through the supertype, and it gives the intended runtime `TypeError`. This only affects the mutation; no committed code changed.

## Concerns
- None blocking.
- `_shows` hides a gated `ActionProperty` only for an object target, as the brief specifies. A tool's settings action whose gate is refused still shows as read-only (2a's rule).
