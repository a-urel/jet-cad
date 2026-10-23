# Task 6 report: the property panel

Files: lib/src/panels/plan_property_panel.dart (migrated), lib/src/chrome/select.dart (PlanOption.key, PlanSelect.expanded/focusNode, Esc returns focus to the trigger), new test/panels/property_chrome_test.dart (PP1-PP7), test/chrome/parts_test.dart (+1), rulings in rulings.md (R-TextField, R-DropdownButton, R-OutlinedButton, R-SizeMenu, R-FRAME, R-allow, R-parts).

Red (before migration): PP1/PP2: `type 'TextField' is not a subtype of type 'PlanTextField' in type cast`; PP4: `Found 0 widgets with type "ShadSelect<Object?>" descending from ... 'property-finish'`; PP5-PP7 red likewise (types).

Mutations:
- M-PP3 (PlanSelect never resets to the model's value; both _syncToModel calls removed): PP3 `00:01 +2 -1: PP3 ... [E]` (Found 0 widgets with text "Matte" descending from 'property-finish'), PP4 red too. Reverted.
- M-PS-esc (no requestFocus on popover close): parts_test `PlanSelect a PlanSelect closed by Escape gives the focus to its focusNode ... Expected: true Actual: false`; P-choice-focus red (`Expected: same instance as PanelFieldFocusNode ... Actual: InteractionLayer`). Reverted.
- M-PS-expanded (stretch -> start): parts_test `Expected: <280> Actual: <112.0>`, SW3 red. Reverted.

Icon pairs: Icons.flip -> LucideIcons.flipHorizontal; Icons.rotate_left -> LucideIcons.rotateCcw; Icons.rotate_right -> LucideIcons.rotateCw.

Choices: headings use planShadThemeOf(context).textTheme.small; error text destructive; the duplicate-label warning (was colorScheme.tertiary) uses mutedForeground (shadcn has no warning colour); ActionProperty/Mirror/rotate -> ShadButton.outline (width: infinity; labels Flexible+ellipsis so the narrow rotate pair does not overflow); the switch row sits in an Align so the PlanSwitchRow is its own tap target (taps at its centre still hit); the root Material (key property-panel) is kept for host sections.

Gates: plan `+1706 ~7: All other tests passed!`, analyze clean, format 0 changed; integration `+240: All tests passed!`, analyze clean; restaurant_demo `+112: All tests passed!`; architecture_demo `+176: All tests passed!`; tool/ci `+122: All tests passed!`; check_api_boundary clean.
