### Task 7: The page panel, the layer panel and their rows

**Files:**
- Modify: `lib/src/panels/plan_page_panel.dart`, `plan_layer_panel.dart`, `layer_row.dart`, `layer_picker.dart`, `colour_row.dart`
- Test: `test/panels/{page_panel,page_panel_theme,page_scale_field,orientation_row,layer_panel,layer_picker,layer_page_controller,colour_row,hover_removal}_test.dart`, `test/l10n/layer_page_words_test.dart`, integration `test/{layers,panels}/*`; new `test/panels/layer_page_chrome_test.dart`

- [ ] **Step 1: Write failing tests** (`layer_page_chrome_test.dart`):
  `LP1 clicking the page panel's scale field then a Selection panel field
  does not commit the scale` (today's documented rule, `plan_page_panel.dart:154`);
  `LP2 the layer row's menu opens on a click on desktop, its entries
  follow a permission change while open`;
  `LP3 the layer picker marks the current layer`;
  `LP4 a blocked colour swatch's semantics label is the colour's name and
  its tooltip the blocked reason`;
  `LP5 PlanLayerPanel's swatch ink still follows Theme.of(context)'s
  surface/brightness when a ShadTheme of the other brightness is above
  it` (canvas-owned read);
  `LP6 the custom paper size shows as today's choice label and refusing a
  size keeps the model's`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Migrate** (`SegmentedButton` ×2
  → `PlanSegmented`; `DropdownButton` ×3 → `PlanSelect` with the custom
  size as an explicit option or placeholder, recorded; `CheckboxListTile`
  ×3 → `PlanCheckRow`; `ListTile`; `PopupMenuButton` → `PlanMenuButton`;
  `InkWell` rows → `PlanListRow`; `Scrollbar` kept, themed; `Tooltip` →
  parts; `colour_row`'s `Tooltip`/`Semantics`/`InkWell` → a focusable
  swatch keeping its `Semantics` and key `color-swatch-<key>`).
- [ ] **Step 4: Run; rulings** (`PopupMenuButton → PlanMenuButton`,
  `CheckboxListTile → PlanCheckRow`, `page_panel_theme_test`'s token reads
  → the shadcn surface, `byTooltip` → semantics label with
  `tester.ensureSemantics()`).
- [ ] **Step 5: Mutations** M-LP1 the scale field drops `groupId` (bypass) → LP1 red; M-LP5 `_foreground` reads `ShadTheme` → LP5 red. Revert.
- [ ] **Step 6: Gates; commit** `feat(plan): the page and layer panels in shadcn`.

