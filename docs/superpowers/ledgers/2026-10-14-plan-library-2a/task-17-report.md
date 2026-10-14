# Task 17 report: PlanPropertyPanel

Status: DONE_WITH_CONCERNS (all gates green, every named mutation red; concerns below are fixture-level and one surviving-then-fixed mutant).

Commits (on feat/plan-library-2a, BASE 9a76ce37):
- `667f40c8` feat(plan): PlanPropertyPanel (P2, P3)
- `9658faf4` test(plan): P-5 reads the settings before the click (M-P-5a survived the brief's P-5; see Mutations)

## Implemented

- `lib/src/panels/plan_property_panel.dart`: `PlanPropertyPanel` (exported) and the `@internal` slot `propertyPanelLayerField` (left null; Task 18 fills it; R-g: no layer field here). Sections top to bottom: the active tool's settings (titled `tool:<id>`, key `settings-<tool id>`, fields `setting-<id>`), the one selected object's section (title from `titleWordOf`, key `section-<type id>`, fields `property-<id>`, escape hatch behind Task 11's `KitSectionBoundary`) or the generic symbol section, the colour row (hidden while a tool's settings show), the layer slot. A locked object (`isLocked`) shows no section and is out of the colour row. Eight kinds: length (mm), angle (degrees shown to 1e-6°, stored radians), number (shown at `decimals`), text (maxLength refused at commit), toggle (`SwitchListTile`), choice (`DropdownButton`, items `property:<owner>.<id>.<segment>`), value display (`mm`, `m²`, `°`, plain), action (`OutlinedButton`). Numbers via `formatPanelNumber`/`parsePanelNumber` (the language's separator, R-i). Field rules ported: PanelFieldFocusNode (Task 13's `panel_focus.dart`, R-f), pin at focus gain, commit on blur and Enter, hand back to the canvas, revert what does not parse or is refused, never reload a focused field, shown text committed again writes nothing, settings keystrokes reach the store at once. Gates: spec `enabled`, spec `gate` via `PlanPermissions.allows`, engine `components` + the type's `editCapability`; settings always editable. Every commit through `PlanController.execute` (R-b); pre-execute refusals (`ArgumentError`, `StateError`) revert, anything else is one `hookFailed` diagnostic. `registerSettle(_settle)` hands a focused field's focus back so its commit lands in the old plan before `load`/`newPlan`; after a swap every field forgets its pinned/loaded target. Selection through `FrameSafeRelay`. `PlanLocaleScope.push` in `didChangeDependencies` and on a controller change. Wrapped in `PlanShortcutGuard`.
- `lib/src/panels/symbol_section.dart`: port of `symbols/symbol_section.dart` adapted to the kit model (UnitComponent, `SymbolComponent.family`, entries list), `_isOrthonormal` copied, plus `shownRotation`, `degreesShown`, `symbolEntriesOf`.
- `lib/src/panels/colour_row.dart`: `colourTargets` (skips locked objects), `pickedColours`, `recolourCommand`, `colourRowBlocked`, `swatchColor`, `ColourRow` (today's swatches, marks, tooltips, semantics; `PlanSwatch`).
- `lib/src/panels/frame_safe_relay.dart`, `lib/src/panels/kit_lookup.dart`, barrel export `PlanPropertyPanel`.
- Tests: `test/support/panel_kits.dart` (box kit, disc kit), `test/panels/property_panel_test.dart` (P-1..P-7, P-lock-recolour, P-two-types, P-swap-pending), ported `selection_panel_test.dart`, `colour_row_test.dart`, `symbol_section_test.dart`, `hover_removal_test.dart`.

Carried items:
- Recolour of a locked object refused (Task 10 cannot-verify): new test **P-lock-recolour** — a locked box beside a free one: the row recolours the free one only, one step; `c.execute(boxType.recolour(doc, locked, 'purple'))` answers false, sets `lockHint`, the locked box keeps its colour. Pinned by M-P-6b and M-P-lock-exec.
- Mirror respects `PlanPermissions.mirror` (Task 12 carry): new test **P-mirror** in `symbol_section_test.dart` (hidden while off, back when on, Rotation stays editable). Pinned by M-P-mirror.
- Review Focus 3 = P-two-types; Review Focus 4 = P-swap-pending.

## TDD evidence

RED (Step 3), `flutter test test/panels/property_panel_test.dart`:
```
test/panels/property_panel_test.dart:52:38: Error: Method not found: 'PlanPropertyPanel'.
  await pumpDesign(tester, c, right: PlanPropertyPanel(controller: c));
00:00 +0 -1: Some tests failed.
```
GREEN (Step 10): `00:02 +10: All tests passed!` (ten: the brief's nine plus P-lock-recolour).
Ported (Step 12), `flutter test test/panels`: `00:04 +72: All tests passed!` (includes Task 13's gallery tests).
First ported runs were red on fixtures, not assertions (fixed as listed under Deviations): SE4/SE11/SE12/SE14 `Actual: ['120', '69.99999999999955']`; CP1 `Expected: null Actual: 'teal'` (line 205); CP6b `Expected: <4279931780> Actual: <4278225275>`; symbol panel tests `SymbolLibraryError (rule 9): definition 1B (test.bed.table@1) is a unit in the size family`.

## Mutations (each on committed files, reverted with `git checkout -- <file>`, then `git diff --quiet -- <file>` printed `reverted clean`)

| id | file / change | test | red line |
|---|---|---|---|
| M-P-1a | panel `_parse`: `degrees * math.pi / 180` -> `degrees` | P-1 | `Expected: <0.7853981633974483> Actual: <45.0>` (line 77) |
| M-P-1b | panel `_commit` unchanged-text check and both `_write` equal-value checks removed | P-1 | `Expected: <7> Actual: <12>` (line 96) |
| M-P-1c | panel `_commit`: `_show(f);` deleted | P-1 | `Expected: <7> Actual: <8>` (line 96; red one assertion earlier than the brief predicted) |
| M-P-2 | panel: gate line deleted | P-2 | `Expected: true Actual: <false>` (line 113) |
| M-P-3 | panel object `_editable`: `!field.enabled ||` deleted | P-3 | `Expected: true Actual: <false>` (line 129) |
| M-P-4 | panel: `type.titleWordOf(doc, t.handle)` -> `'type:${t.typeId}'` | P-4 | `Expected: 'Solid box' Actual: 'Box'` (line 144) |
| M-P-5a | panel `_onChanged` body -> `{}` | P-5 | **survived** the brief's P-5 (`+1: All tests passed!`); after 9658faf4: `Expected: <Instance of 'DiscToolSettings'> Actual: <Instance of 'DiscToolSettings'>` (line 167) |
| M-P-5b | panel tool `_write`: `field.commit!(input);` deleted | P-5 | `Expected: <250> Actual: <400.0>` (line 171) |
| M-P-6a | panel `_objectTarget`: `|| _c.isLocked(h)` deleted | P-6 | `Expected: no matching candidates Actual: ... 'section-box.box'` (line 190) |
| M-P-6b | colour_row: `if (!c.isLocked(h))` deleted | P-6, P-lock-recolour | P-6 `... 'color-picker'` (line 191); P-lock-recolour `Expected: 'teal' Actual: <null>` (line 209) |
| M-P-lock-exec (new) | plan_controller `execute`: the `on PlanLocked` catch deleted | P-lock-recolour | `The following PlanLocked was thrown running a test` |
| M-P-7 | panel: `KitSectionBoundary(...)` -> inline `type.sectionFor(...) ?? const SizedBox.shrink()` | P-7 | `Expected: null Actual: StateError:<Bad state: a disc over 5 m>` (line 233) |
| M-P-two | panel: `commitField` -> `SetComponentCommand<Component>(handle, field.commit!(input)! as Component)` | P-two-types | `Expected: <150> Actual: <120.0>` (line 249) |
| M-P-swap | panel: `_releaseSettle = c.registerSettle(_settle);` deleted | P-swap-pending | `Expected: <150> Actual: <120.0>` (line 288) |
| M-07p | panel: `f.pinned ??= _targetOf(f)` -> `f.pinned = null`, `_commit`'s `f.pinned` -> `_targetOf(f)` | WS7 (Box) | `Expected: [150, 70.0] Actual: [120.0, 70.0]` (line 294) |
| M-F3 | panel: `onTapOutside` `handBack()` -> `unfocus()` | SE11 | `Expected: same instance as FocusNode ... (InteractionLayer) Actual: FocusScopeNode ...` (line 395) |
| M-PC9-a | colour_row: `edits.isEmpty ? null : ...` -> always `CompoundCommand` | CP3 | red by `ArgumentError: Invalid argument (children): must not be empty` thrown from `new CompoundCommand` on the second tap (the engine refuses an empty compound; not the "second step" the brief predicted) |
| M-PC9-b | colour_row: `recolor` line deleted | CP4 | `Expected: ... {"colour":"teal" ... Actual: ... {"colour":null ...` (line 307) |
| M-HR1 | panel `_bindDocument`: relay -> `_c.selection.addListener(_sync)` (the removal left as is: `_selection` stays null) | HR1 | `Expected: null Actual: FlutterError:<setState() or markNeedsBuild() called during build.` (line 44) |
| M-09c-x | symbol_section: `atan2(-t.c, t.d)` -> `atan2(t.b, t.a)` | SS1 | `Expected: a numeric value within <1e-9> of <30> Actual: <209.99999999999997>` |
| M-09c-bi | symbol_section: `e.unit != null ||` deleted | SS7 | `Actual: ['test.bed.1400', 'test.bed.table', 'test.bed.1600', 'test.bed.1800']` |
| M-P-mirror (new) | panel: `if (p.mirror) ...[` -> `if (true) ...[` | P-mirror | `Expected: no matching candidates Actual: ... 'symbol-mirror'` (line 564) |

## Gates (packages/jet_cad_2d_plan, after 9658faf4)

```
dart format .                      -> Formatted 133 files (0 changed)
flutter test                       -> 00:13 +525: All tests passed!
flutter analyze                    -> No issues found! (ran in 2.8s)
dart format --output=none --set-exit-if-changed .  -> Formatted 133 files (0 changed); format exit 0
git status --short                 -> clean
```
No other package touched; no analysis_options.yaml staged.

## Files

- `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (export)
- `packages/jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart`, `symbol_section.dart`, `colour_row.dart`, `frame_safe_relay.dart`, `kit_lookup.dart`
- `packages/jet_cad_2d_plan/test/support/panel_kits.dart`
- `packages/jet_cad_2d_plan/test/panels/property_panel_test.dart`, `selection_panel_test.dart`, `colour_row_test.dart`, `symbol_section_test.dart`, `hover_removal_test.dart`

## Deviations from the brief

1. `panel_kits.dart` imports `package:flutter/material.dart` `hide Tolerance` (Material's physics `Tolerance` clashes with the engine's, which `BoxType` uses; test_kit.dart does the same), `flutter_test` `show addTearDown`, and only the barrel for `ensureManifest` (the barrel exports `plan_file.dart`; a second import would be unnecessary).
2. P-5 gained one assertion (9658faf4): `c.toolSettings.valueOf('disc.draw') == DiscToolSettings(radius: 250)` right after the keystrokes. Reason: in this composition the canvas tap's `onTapOutside` hands the focus back on pointer down and the focus-loss commit lands before the tool accepts on pointer up, so the brief's P-5 passed with `_onChanged` emptied (M-P-5a survived). Strengthened, not weakened.
3. New tests beyond the brief, for the carried items: P-lock-recolour (property_panel_test) and P-mirror (symbol_section_test), with the new mutations M-P-lock-exec and M-P-mirror.
4. `selection_panel_test.dart`: the fixture's page snaps to its grid (`copyWith(snapToGrid: true)`, history cleared). Reason: in the design composition the canvas sits elsewhere than in today's shell and, under the rotated camera, BX4's first box drew 120 x 69.99999999999955 (SE4, SE11, SE12, SE14 read `'69.99999999999955'` for today's `'70'`); the grid gives the clicks today's exact corners. Assertions unchanged. The helper `panelTitle` names today's `find.descendant(of: selection-panel, matching: find.text('Box'))` with the new key.
5. `colour_row_test.dart`:
   - CP1: two pumps after each `paint` in the mark checks ("both teal", "teal and purple"). Reason: a box's colour draws nothing (a room's tint did), so no frame is due when the async document-change event reaches the panel; one pump read the stale row (`Expected: null Actual: 'teal'`). Escape (PlanShortcuts' key, absent from the brief's Rig) became `c.selectTool('plan.select')`, as W became `selectTool('disc.draw')`. Reasons that named the wall now name the line/box.
   - Rig: the tree is keyed with a fresh `GlobalKey` per pump (today's capture key did this), else the second rig of CP6b animated the theme from light (`Expected: <4279931780> Actual: <4278225275>`). No camera or capture: no pixel test is ported (CP2 is sub-project 3's).
   - Boxes carry non-default fields (labels, count, finish); the line sits off the origin.
6. `symbol_section_test.dart`:
   - `test.corner` -> `test.corner.seat`: K2 symbol keys need a kit id and two or more segments.
   - K2 library rule 9 refuses a unit in a size family, so the library has `test.bed.table` and the tables without a family; `familyEntries` puts `test.bed.table` back in the beds' family by hand (a `SymbolEntry` with a family-carrying `SymbolComponent`), and `entry(key)` and the family tests read it. SS7/SW5 assertions unchanged.
   - Model fields: `.key`/`.version` read as `.symbol.key`/`.symbol.version` (the kit's `SymbolEntry`), values unchanged.
   - Waiting for the library: a few pumps until `symbolsState` leaves loading (the gallery tests' pattern), not `tester.runAsync`; SW3's gate completes and the same wait follows.
   - SW4 without its table half: each dropped `select [table]` is an empty selection, so the permission changes are read by a rebuild (`SelectionController.replace` with the same keys does not notify).
   - SW1, SW4 lose their table halves as the brief says; SW6, SW7, SW9, SS9 not ported (brief).
7. `hover_removal_test.dart`: as the brief; the line is added before the pump.
8. M-HR1: only the bind line changed (no matching removal edit needed to compile; `_selection` stays null).
9. Panel code otherwise as the brief, compiled unchanged; `kit_lookup.dart`, `frame_safe_relay.dart`, `colour_row.dart` verbatim in intent.

## Self-review

- R-b: every widget commit goes through `c.execute` (fields, actions, choice, toggle, section, rotate, mirror, change size, colour row). Settings commits go through the store (no command), as specified.
- R-f: `PanelFieldFocusNode` imported from Task 13's `panel_focus.dart`; nothing duplicated.
- R-g: only the `@internal` slot; no layer picker.
- R-i: `formatPanelNumber`/`parsePanelNumber` with `PlanStrings.of(context)`.
- Covariance: the panel only reads `spec.id`, `spec.gate`, kind type tests, `NumberProperty.decimals`/`min`, `ChoiceProperty.values`, and uses `bind` via `fieldsOf`/`commitField`; P-two-types exercises two `T`s with no `TypeError`.
- Frame path: no change to the canvas path.

## Concerns

1. After a test fails, the teardown runs the controller's `dispose` before the tree unmounts, and the canvas's deactivation cancels a disposed kit tool: `A DiagnosticsLog was used after being disposed` cascades into the following tests' output (seen only while the fixture was wrong; passing tests are clean). Harness ordering, not this task's code; it makes red runs noisy.
2. The panel rebuilds from the document's async change stream (as today's panel did). A change that draws nothing schedules no frame by itself, so a test needs a second pump (CP1). In an app the `setState` schedules the frame; no user-visible lag beyond one frame.
3. Rule 9 makes the panel's servable guard in the Size menu (`isServableInstance` before `familyMembers`) unreachable through a loaded library; SW5's panel half no longer pins it (it was not among the brief's named mutations).
4. M-PC9-a and M-P-1c are red, but on other lines/reasons than the brief predicted (an engine `ArgumentError` for an empty compound; the undo-depth line before the refused-label line).
5. `ColourRow` (internal, built inside the panel) does not call `PlanLocaleScope.push` itself; the panel does.

## Fix round 1 (review task-17-review.md; controller ruling on kit hooks)

Commit: `d510d4ea` fix(plan): panel kit hooks at the boundary; Size menu rule pinned.

### Changes

1. **Important 1 (SW5 could not pin M-09c-bf).** `symbol_section.dart` gains `sizeMenuMembers(entries, doc, instance)`: the entry's family, or nothing for no entry or a servable instance. `_symbolSection` calls it. New model test **SS12** runs over the hand-built `familyEntries`, where `test.bed.table` is servable and its entry names the beds' family. A bed gets its three members; the servable instance gets none. SW5's title no longer claims M-09c-bf: it says K2 rule 9 leaves the loaded library's tables without a family, so SS12 pins it. SW5's assertions are unchanged.
2. **Important 2 (ruling: guard the panel's kit hooks).**
   - `plan_property_panel.dart`:
     - `_bound` goes through `_fieldsOrNull`. It wraps the type's `fieldsOf` (spec `read`/`enabled`) and the tool settings' `fieldsOf` in a try. A throw returns null and logs one `hookFailed` (kit id, type or tool id) via `diagnosticsLog.addAfterFrame`, which is safe in a build and deduplicated.
     - The title hook goes through `_titleWordOf`, guarded the same way.
     - When the title or the fields fail, `_objectSection` and `_settingsSection` return only the "section failed" box. It is keyed `kit-section-failed` and uses Task 11's look and the `sectionFailed` word.
     - Listener and focus paths (`_load`, `_commit`, `_parse`, `_editable`) read the guarded `_bound`, so they never throw.
   - `colour_row.dart`:
     - `pickedColours` reads through `_colourOf`. A read that throws lists a name equal to no swatch, so it marks nothing, plus one diagnostic after the frame.
     - In `recolourCommand`, a `write` that throws becomes a `KitHookFailure` (hook `colour write`).
     - `ColourRow._choose` catches it: the recolour is refused whole, nothing is executed, and one diagnostic is logged the way `execute` logs a hook failure.
     - Deviation from the ruling's wording: the refusal happens before `execute`, because the write runs while the command is built. So no `execute(...) == false` is observable. The effect is the same: nothing changes, no step is recorded, one diagnostic is logged.
   - Tool-settings binding is guarded too (`_fieldsOrNull` tool case), but no fixture has throwing settings, so that branch is unpinned.

### Covering tests (`packages/jet_cad_2d_plan/test/panels/property_panel_test.dart`, throwing kit's `boom.block` beside a box, no change to throwing_kit.dart needed)

- **P-G1**: `read` throws. The section is replaced by the box. The diagnostic list is `['boom.block: read']`. A later document change throws nothing. The box still edits (width 150). After the hook heals, the block's section is back (`property-size` '400').
- **P-G2**: `title` throws. The section is replaced, with one diagnostic `['boom.block: title']`, and the box's section still shows.
- **P-G3 (read)**: `colourRead` throws. The row stays, purple is no longer marked (premise: it was marked before), and one diagnostic is logged. A tap on teal still recolours the block in one step.
- **P-G3 (write)**: `colourWrite` throws. A tap on teal with the box and the block selected changes nothing: no step, the box keeps no colour, the block stays purple, and one diagnostic `['boom.block: colourWrite']` is logged. The box alone then recolours.
- **SS12** (`symbol_section_test.dart`).

### Commands and output (packages/jet_cad_2d_plan, after d510d4ea)

```
flutter test test/panels/property_panel_test.dart  -> 00:03 +14: All tests passed!
flutter test test/panels/symbol_section_test.dart  -> 00:01 +18: All tests passed!
dart format .                                      -> Formatted 133 files (0 changed)
flutter test                                       -> 00:14 +530: All tests passed!
flutter analyze                                    -> No issues found! (ran in 3.4s)
dart format --output=none --set-exit-if-changed .  -> format exit 0
git status --short                                 -> clean
```

### Mutations (on committed d510d4ea; each reverted with `git checkout --`, `git diff --quiet` -> `reverted clean`)

| id | change | test | red line |
|---|---|---|---|
| M-09c-bf | symbol_section `sizeMenuMembers`: `entry == null || isServableInstance(doc, instance)` -> `entry == null` | SS12 | `Expected: empty Actual: [` |
| M-P-G1 | panel `_fieldsOrNull` object case: try/catch removed | P-G1 | `Expected: null Actual: BoomFailure:<BoomFailure(read)>` (line 346) |
| M-P-G2 | panel `_titleWordOf`: try/catch removed | P-G2 | `Expected: null Actual: BoomFailure:<BoomFailure(title)>` (line 379) |
| M-P-G3r | colour_row `_colourOf`: try/catch removed | P-G3 (read) | `Expected: null Actual: BoomFailure:<BoomFailure(colourRead)>` (line 402) |
| M-P-G3w | colour_row `recolourCommand`: the write's try/catch removed | P-G3 (write) | `Expected: null Actual: BoomFailure:<BoomFailure(colourWrite)>` (line 424) |
| M-P-G3w' | colour_row `_choose`: the `on KitHookFailure` catch removed | P-G3 (write) | `Expected: null Actual: KitHookFailure:<KitHookFailure: boom.block.colour write threw BoomFailure(colourWrite)>` (line 424) |

### Not addressed (review minors, left for the controller)

- Minor 1: the last block of P-swap-pending.
- Minor 2: `_guarded` cannot tell a spec refusal from a kit's own ArgumentError or StateError.
- Minor 4: a NumberProperty value that rounds back to the stored value still records a no-op step.
- Minor 5: titles of the ported tests' dropped table halves (SW5's title was fixed).
- Minor 6: P-lock-recolour's title names only M-P-6b.
- Minor 7: ColourRow's push.
- The `parametric.editCapability` getters the panel and the row read are still raw. They are not in the ruling's list.
