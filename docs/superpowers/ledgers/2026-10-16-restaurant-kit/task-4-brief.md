### Task 4: O1 drag snap, O2 orientation row

**Files:** `packages/jet_cad_2d_plan/lib/src/tools/` (the select tool's
drag snap), `lib/src/panels/plan_page_panel.dart`; tests beside the
existing select-drag and page-panel tests.

- [ ] **O1:** a test drags a unit (and a plain line) with `plan.select`
  by a small offset near its own old edge midpoint: the result is the
  pointer's offset (grid aside), not the old midpoint. If red on today's
  code, exclude the dragged objects from the snap candidates (find where
  the move resolver gathers candidates); if green, the item closes with
  the test as its pin and the report says the defect was not real.
  Mutation for the fix: include the dragged objects again.
- [ ] **O2:** the orientation row's labels lay out on one line each at
  the panel's width at 1440×900 and at its narrowest (measure the
  `Text`'s `RenderParagraph` line count or `didExceedMaxLines`); fix by
  the row's layout (e.g. `FittedBox`/smaller padding/an icon+label
  layout), not by changing the words. en/de/tr. Mutation: restore the
  old layout.
- [ ] Gates (plan, integration). Commit `fix(plan): a dragged unit does not snap to itself; the orientation row fits`.

