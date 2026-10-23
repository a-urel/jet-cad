### Task 6: The property panel

**Files:**
- Modify: `lib/src/panels/plan_property_panel.dart`, `symbol_section.dart`, `unit_section.dart` (if they read Material)
- Test: `test/panels/property_panel_test.dart`, `selection_*_test.dart`, `symbol_section_test.dart`, `unit_section_test.dart`, `object_view_panel_test.dart`, integration `test/{room,opening,dimension,panels}/*`; new `test/panels/property_chrome_test.dart`

- [ ] **Step 1: Write failing tests** (`property_chrome_test.dart`):
  `PP1 a numeric property field is a PlanTextField with today's key, label
  and suffix`;
  `PP2 a field locked by permissions while focused stays focused,
  selectable, uneditable; unlocked again it edits` (the spec's read-only
  case on the real panel);
  `PP3 a choice property whose write is refused shows the model's value
  after the pick`; `PP4 undo after a choice change shows the old choice`;
  `PP5 read-only displays (value, text, symbol metadata, capacity) are
  PlanReadOnlyField with today's labels`;
  `PP6 a boolean property is a PlanSwitchRow`;
  `PP7 at 375 px in the phone drawer a PlanSelect's popover lies fully
  inside the screen`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Migrate** (`TextField` →
  `PlanTextField` keeping `readOnly: !editable`, focus node, commit and
  hand-back callbacks; `DropdownButton` → `PlanSelect`; `InputDecorator` →
  `PlanReadOnlyField`; `SwitchListTile` → `PlanSwitchRow`; buttons →
  `ShadButton` variants; headings from the shadcn text theme).
- [ ] **Step 4: Run; rulings** (`TextField → PlanTextField` with
  `decoration.labelText/errorText/suffixText → label/errorText/suffix`;
  `DropdownButton → PlanSelect` with `.value`; `InputDecorator →
  PlanReadOnlyField`).
- [ ] **Step 5: Mutation** M-PP3: `PlanSelect` forwards without reset in this panel only (bypass the part) → PP3 red. Revert.
- [ ] **Step 6: Gates; commit** `feat(plan): the property panel in shadcn`.

