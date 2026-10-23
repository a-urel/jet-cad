### Task 5: The editor, its bar and the tool palette

**Files:**
- Modify: `lib/src/editor/plan_editor.dart`, `plan_tool_palette.dart`, `editor_layout.dart`
- Test: the existing `test/editor/*`, `test/shortcuts/plan_shortcuts_test.dart`, integration `test/editor/*`, `test/phone/phone_design_test.dart`; new `test/editor/editor_chrome_test.dart`

**Interfaces:**
- Consumes: Tasks 2–3.

- [ ] **Step 1: Write failing tests** (`editor_chrome_test.dart`):
  `ED1 under a host ShadTheme (primary 0xFF123456) the bar's Undo is a
  PlanIconButton and the palette's selected tool button's background is
  the ShadTheme's secondary`;
  `ED2 the Tools/Symbols switch is a PlanSegmented whose segments keep
  today's keys`;
  `ED3 under a bare MaterialApp the bar's surface is the derived
  background`;
  `ED4 desktop, tablet (800) and phone (375) layouts still build with
  their docked columns and drawers` (the layout keys `editor_layout_test`
  uses);
  `ED5 the palette's selected tool exposes selected semantics`;
  `ED6 at TextScaler.linear(1.5) and 2.0, widths 375, 800 and 1280: no
  overflow error in the editor` (`tester.takeException()` is null).
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Migrate:** every `IconButton` → `PlanIconButton`, the
  `SegmentedButton` → `PlanSegmented`, `Tooltip` → the part's tooltip,
  `ListTile`/`CheckboxListTile` → `PlanListRow`/`PlanCheckRow`, `Divider` →
  `ShadSeparator.horizontal`, surfaces from `ShadTheme.of(context)`,
  `Icons.*` → `LucideIcons.*` (record each pair in the icon ruling's
  table). `Scaffold` may stay (record the choice). Keys move onto the parts.
- [ ] **Step 4: Run** the package and integration suites; rewrite failing
  finders under rulings (`IconButton → PlanIconButton`, `SegmentedButton →
  PlanSegmented`, `Tooltip → PlanIconButton.tooltip/semantics`, `ListTile →
  PlanListRow`, icons). Each rewritten finder anchors on the same key.
- [ ] **Step 5: Mutation** M-ED1: the palette reads `Theme.of(context).colorScheme.secondaryContainer` for the selected tool → ED1 red. Revert.
- [ ] **Step 6: Gates (plan, integration, tool/ci); commit** `feat(plan): the editor's chrome in shadcn`.

