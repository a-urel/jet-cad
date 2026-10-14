# Task 18 report: PlanLayerPanel, PlanPagePanel and the layer picker

Status: DONE_WITH_CONCERNS (one design addition beyond the brief, listed under Deviations 6; nothing open)

Commits (BASE d510d4ea):
- `7b566fae` feat(plan): PlanLayerPanel, PlanPagePanel and the layer picker
- `7c0156a3` test(plan): name the panels' locale test LP-L

## Implemented

- `lib/src/panels/layer_row.dart`: a port of `layer_row.dart`, with `required PlanController controller`; the rename field sits in `PlanShortcutGuard(controller: …)`.
- `lib/src/panels/plan_layer_panel.dart`: `kLayerListVisibleRows`, `layersInPanelOrder` and `nextLayerName` ported; `PlanLayerPanel({required PlanController controller})` and `PlanLayerPanelState` (`isOpen`, `selected`).
  - It listens to the controller and rebinds `commands.changes`, `tables.changes` and the page notifier when the document is swapped.
  - `_allowed` is `permissions.editLayers` and the document's `Capability.structure`.
  - Every commit goes through `controller.execute`, and only `StateError` is caught here.
  - ACI 7's swatch uses `foregroundFor(displayPaperFor(page, PlanTheme canvasBackground ?? scheme.surface, brightness))`, the same derivation the shell and the canvas use.
  - It calls `PlanLocaleScope.push`.
- `lib/src/panels/layer_picker.dart`:
  - Ported: `layerOfKey`, `layerPickerBlocked`, `layerMoveCommand` and `LayerPicker({required PlanController controller})`.
  - "Is a live object" comes from E1: `controller.catalog.typeIdOf(document, h) != null`.
  - `_lockedOrUnderLock` walks the owner chain. A locked key (or a key under a lock) is reported as `lockedNoLayer`, checked before the plain-group rule.
  - `_choose` re-checks `permissions.changeLayer`, then the source's rules without the lock (a lock is refused at commit), then `controller.execute`.
- `lib/src/panels/plan_page_panel.dart`: `PlanPagePanel({required PlanController controller})` and `PlanPagePanelState.resyncScale()`.
  - It follows the controller's page notifier across swaps and registers `resyncScale` with `registerSettle` (withdrawn on dispose and on a controller swap).
  - `_editable` is `permissions.editPage`. `_set` goes through `controller.execute`.
  - The decimal-separator control is ported with the build body. It calls `PlanLocaleScope.push`. It wraps itself in `PlanShortcutGuard` (see Deviations 6).
- `PlanStrings.lockedNoLayer` in en, de and tr, with the brief's exact strings.
- `plan_property_panel.dart`: the slot `propertyPanelLayerField` is now initialised with `(context, controller) => LayerPicker(controller: controller)`, and `layer_picker.dart` is imported. Nothing else in the file changed.
- The barrel exports `PlanLayerPanel` and `PlanPagePanel`.
- Test support:
  - `test/support/mark_kit.dart`, verbatim from the brief.
  - `test/support/layer_plan.dart`: the brief's code plus `addRegionOn`, `addSymbolOn`, `layerOf` and `objectLayerOf`, copied from the source.
- Tests:
  - New: `layer_page_controller_test.dart` (LP-1 … LP-8, plus LP-L).
  - Ported: `layer_panel_test.dart` (25), `layer_picker_test.dart` (11), `page_panel_test.dart` (7), `page_panel_theme_test.dart` (premise + D6a in both themes), `selection_page_test.dart` (SE13, SE15, SE16), `page_scale_field_test.dart` (A9, A14, A15, A18, A19, A23-A26), `l10n/layer_page_words_test.dart` (NN1, PW1, PW2, SE2L).
  - Added to existing files: LP-W in `value_words_test.dart`, and CP1's `layer-picker` assertion in `colour_row_test.dart` (at the source's place: after "box A", before the swatches).
- Carried rule (Task 10 cannot-verify): a layer change of a locked object is refused.
  - Up front: LP-6, a missing kit's mark, disabled with `lockedNoLayer`.
  - At commit: LP-7, `lockBroken` after the menu opened; nothing changes, no exception, the lock hint is raised.
- Kit hooks: the picker calls only `catalog.typeIdOf`. It reads components (`_naming`) and calls no kit code. The layer move's regeneration runs through Task 11's guarded types; `execute` answers false for a `KitHookFailure`.

## TDD evidence

RED, before any production code (Step 2):
```
test/panels/layer_page_controller_test.dart:14:8: Error: Error when reading 'lib/src/panels/layer_picker.dart': No such file or directory
test/panels/layer_page_controller_test.dart:15:8: Error: Error when reading 'lib/src/panels/plan_layer_panel.dart': No such file or directory
test/panels/layer_page_controller_test.dart:16:8: Error: Error when reading 'lib/src/panels/plan_page_panel.dart': No such file or directory
test/panels/layer_page_controller_test.dart:47:15: Error: Method not found: 'PlanLayerPanel'.
```
RED for the ported tests (Step 3). Each of the 8 new files failed to load (`loading … [E]`). Two runtime failures:
```
test/l10n/layer_page_words_test.dart:187:12: Error: Method not found: 'nextLayerName'.
CP1: Expected: exactly one matching candidate
  Actual: _KeyWidgetFinder:<Found 0 widgets with key [<'layer-picker'>]: []>   (colour_row_test.dart line 185)
test/l10n/value_words_test.dart:78:27: Error: The getter 'lockedNoLayer' isn't defined for the type 'PlanStrings'.
```
GREEN:
- `flutter test test/panels/layer_page_controller_test.dart` → `00:01 +8: All tests passed!`
- Then `flutter test test/panels test/l10n` → `00:08 +168: All tests passed!`.
- Between those two runs:
  - A9-A26 and SE15 were red, with the A9 failure at line 46: `Expected: false Actual: <true>`. The page panel had no guard (Deviations 6), and the later page_scale tests cascaded from A9.
  - SE15 was red on a missed tap (Deviations 4).

## Mutations

Every mutation ran on a committed file. Each was reverted with `git checkout -- <file>`, and `git diff --quiet -- <file>` printed `clean 0` every time.

| Id | Mutation | Test | Red line |
|---|---|---|---|
| M-LP-1 | `_onController` without `if (!identical(_bound, …)) _bind();` | LP-1 | `Expected: <0> Actual: <1>` (old document's listener count, line 149) |
| M-LP-2 | `_allowed` = structure only | LP-2 | the encoding differs: `"color":1` vs `"color":4` (line 182) |
| M-LP-3 | page `_onController` without the `_bindPage()` line | LP-3 | `Expected: '20' Actual: '50'` (line 231) |
| M-LP-4 | `_editable => true` | LP-4 | `Expected: false Actual: <true>` (line 254) |
| M-LP-5 | `initState` without `registerSettle(resyncScale)` | LP-5 | `Expected: '50' Actual: '77'` (line 289) |
| M-LP-6 | the `_lockedOrUnderLock` loop deleted | LP-6 | `Expected: 'Locked objects cannot change layer' Actual: 'A plain group has no layer: it cannot be moved'` (line 312) |
| M-LP-7 | `_choose`: `controller.document.commands.execute` | LP-7 | `The following PlanLocked was thrown running a test`; `Expected: true Actual: <false>` |
| M-LP-7b | `execute`'s `on PlanLocked` without `lockHint.value = true;` | LP-7 | `Expected: true Actual: <false>` (line 343) |
| M-LP-8 | `_choose` without the `changeLayer` check | LP-8 | `Expected: <0> Actual: <1>` (line 363) |
| M-LP-slot | the slot's initializer deleted | CP1 | `Found 0 widgets with key [<'layer-picker'>]` (line 185) |
| M-LP-9 | `_isObject` returns false | "every registered parametric type … alone" | `Expected: true Actual: <false>` (line 449, `pickerEnabled`) |
| M-LP-W | tr `lockedNoLayer` returns the English text | LP-W | `Expected: an object with length of <3>` |
| M-LP-10 | `layer_row.dart` `_field()`'s guard swapped for `KeyedSubtree` | "no shell shortcut fires while typing" | `Expected: <0> Actual: <13>` (line 642) |
| M-LP-11 (added) | `plan_page_panel.dart` build's guard swapped for `KeyedSubtree` | A9 and A14 | A9: `Expected: false Actual: <true>` (line 46); A14: `Expected: 'Polyline' Actual: 'Select'` (line 69) |
| M-LP-La (added) | layer panel `didChangeDependencies` without `PlanLocaleScope.push` | LP-L | `Expected: Locale:<de> Actual: Locale:<en>` (reason `layers`) |
| M-LP-Lb (added) | page panel `didChangeDependencies` without `PlanLocaleScope.push` | LP-L | `Expected: Locale:<de> Actual: Locale:<en>` (reason `page`) |

## Gates (packages/jet_cad_2d_plan, after 7c0156a3)

```
flutter test        -> 00:18 +602: All tests passed!
flutter analyze     -> No issues found! (ran in 4.1s)
dart format --output=none --set-exit-if-changed .  -> Formatted 147 files (0 changed); format exit 0
git status --short  -> (empty; no analysis_options.yaml rewritten)
```

## Files

Created:
- `packages/jet_cad_2d_plan/lib/src/panels/layer_row.dart`
- `packages/jet_cad_2d_plan/lib/src/panels/plan_layer_panel.dart`
- `packages/jet_cad_2d_plan/lib/src/panels/layer_picker.dart`
- `packages/jet_cad_2d_plan/lib/src/panels/plan_page_panel.dart`
- `packages/jet_cad_2d_plan/test/support/mark_kit.dart`
- `packages/jet_cad_2d_plan/test/support/layer_plan.dart`
- `packages/jet_cad_2d_plan/test/panels/layer_page_controller_test.dart`
- `packages/jet_cad_2d_plan/test/panels/layer_panel_test.dart`
- `packages/jet_cad_2d_plan/test/panels/layer_picker_test.dart`
- `packages/jet_cad_2d_plan/test/panels/page_panel_test.dart`
- `packages/jet_cad_2d_plan/test/panels/page_panel_theme_test.dart`
- `packages/jet_cad_2d_plan/test/panels/selection_page_test.dart`
- `packages/jet_cad_2d_plan/test/panels/page_scale_field_test.dart`
- `packages/jet_cad_2d_plan/test/l10n/layer_page_words_test.dart`

Modified:
- `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart`
- `packages/jet_cad_2d_plan/lib/src/l10n/strings.dart`, `strings_en.dart`, `strings_de.dart`, `strings_tr.dart`
- `packages/jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart`
- `packages/jet_cad_2d_plan/test/l10n/value_words_test.dart`
- `packages/jet_cad_2d_plan/test/panels/colour_row_test.dart`

## Deviations from the brief

1. **`layer_plan.dart` `addSymbolOn`: the local `at` is renamed `p`.** With the brief's substitution, the source's `final at = l.at(x, y);` becomes `final at = at(x, y);`. That refers to itself and does not compile.
2. **layer_panel_test S-6 builds its file with `layerPlan(more: …)`**, running the two restore commands on layerPlan's scratch document. The brief said a bare scratch `PlanController(kits: const [])`. This version keeps `pumpPanel(tester, LayerPlan fx)` as the brief specifies, and it keeps the layers of the source's `layerDoc()`. The save and load round trip is the same, and the assertions are unchanged.
3. **layer_picker_test fixtures:**
   - The calls to `layerMoveCommand` pass the required `isObject:` argument from the brief's new signature, through `isParametricObject(c, h) = c.catalog.typeIdOf(c.document, h) != null`.
   - `PickerDoc` is a factory that captures `more`'s handles.
   - `addLayerD` is factored out because both fixtures add `D`.
   - The test name "every registered parametric type (box, wall, …)" now reads "(the mark kit's one type, on four layers)".
   - The assertions are unchanged.
4. **selection_page_test sets a 1440 x 1080 window after `pumpDesign`.** At 1440 x 900 the scale field's centre is at y 928, so `tester.tap(pageScale())` missed. The test printed: `derived an Offset (Offset(1300.0, 928.0)) that would not hit test`. SE15 depends on that tap landing with no frame in between, so scrolling first was not an option. The canvas only grows downward, and the camera's world points are unchanged. Following Task 17's adaptation of SE11-SE14, W/'Wall' becomes B/'Box'.
5. **page_scale_field_test uses Task 16's `pumpDesign(right: PlanPagePanel(controller: c))`** instead of the brief's bare `Row` with an outer `PlanShortcutGuard`. The tests read `status(tester)` (the design harness's status line), and the brief also asks for "the same adaptations Task 16's palette_draw_test.dart makes".
6. **`PlanPagePanel` wraps itself in `PlanShortcutGuard`** (not in the brief).
   - Spec P2 says "Text fields keep their keys".
   - `PlanPropertyPanel` and `LayerRow` already guard their own fields.
   - Without the guard, a host that places the page panel next to `PlanShortcuts` loses letters, Cmd+Z and Escape typed in the scale field: A9 and A14 were red.
   - M-LP-11 pins the guard.
7. **`layer_row.dart`: a doc comment reference changed from `[ShellShortcutGuard]` to `[PlanShortcutGuard]`**, so the reference is not dangling.
8. **`layerMoveCommand`'s doc comment is the source's full comment (`:88-104`)**, with "a live parametric object ([isObject])". The brief's short comment pointed at a line range in another package.
9. **layer_page_words_test fixtures:**
   - The brief gave no place for PW's mark. It sits at the source wall's start, (-1830.5, 640.25), turned 0.4.
   - The panels' column is in a `SingleChildScrollView`.
   - SE2L's pump is named `pumpLayers`.
   - PW1 and PW2 keep their source names, which still mention the Wall section; the header comment says what moved.
10. **Added: LP-L ("each panel alone reports the app's locale to its controller")** with M-LP-La and M-LP-Lb. The brief's M-LP-9 already names the `isObject` mutation, so the new test got its own id (commit 2).
11. Mechanical: the source range for `build` (`layer_panel.dart:233-352`) leaves out the `Widget build(BuildContext context) {` line and the class's closing brace. Both were added.

## Self-review

- **Every commit goes through `controller.execute`**: the layer panel's `_execute`, the page panel's `_set`, and the picker's `_choose`. None calls `document.commands.execute` (M-LP-7 pins the picker), and none catches what `execute` already answers false for.
- **`PlanLocaleScope.push`**: both public panels call it in `didChangeDependencies` and again when given another controller (LP-L).
- **Internal widgets**: `LayerPicker` and `LayerRow` push nothing themselves, as with Task 17's `ColourRow`; the public widget that hosts them does.
- **Ported assertions are unchanged.** The tests not ported, each with its reason given in its file header:
  - layer_panel "in the app" (Task 20);
  - layer_picker "in the app" (Task 17 and sub-project 3);
  - "a move the document refuses" (Task 11; LP-7 covers the picker's catch);
  - PW's wall parts and zoom read-out (sub-project 3, Task 20);
  - SE1 (2b);
  - A16 and A27 (Task 20).

## Concerns

- **Deviations 6 adds a guard to `PlanPagePanel` that the brief did not ask for.** The controller should confirm it. Removing it would leave a host's page panel without the text-field rule unless the host adds its own guard.
- **`_add` in the layer panel (ported) still selects the new handle and opens its rename field when `execute` answered false.** Because of `build`'s `layers.contains` check, the stale handle has no effect. The behaviour is unchanged from the source.
- **Test count**: 602 (+77 over Task 17).
