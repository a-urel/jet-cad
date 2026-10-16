### Task 8: The demo's bars, export, layout and events

**Files:** the demo's own service bar (`PlanServiceBar(leading: [area
name])`, key `bar-area`), export/print (`showPlanExportDialog` +
`controller.export`/`print`, busy through `pageFlowBusy`), save / revert /
restore layout (decision 14), the events log; port the remaining rows of
`demo_test`, all of `events_test`, `badges_test`, `host_chrome_test`,
`look_test`.

- [ ] Port per the audit; new: **EX-area** (Review Focus 5; mutation:
  export reads the current area at write time instead of at start).
- [ ] Gates; commits as Task 7.

