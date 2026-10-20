### Task 10b: A double tap ends a chain (the human's decision, 2026-10-20)

**Why:** on a phone there is no Enter key; today a wall chain ends only by picking another tool (Task 8's finding). The human decided: a double tap ends it.

**Behaviour:** with a chain tool active (the architecture kit's Wall tool at least; every tool that Enter finishes today, if the finishing path is shared), a touch double tap on the canvas ends the chain exactly as Enter does today: the segments drawn so far are kept, the tool returns to its first-point state, no extra segment is added at the double-tap point (the double tap's two taps must not each add a point first — or, if the first tap already added a point by the time the second arrives, that point is the chain's last and the result equals Enter after that point; pick the rule that equals what a user expects and pin it in the test). A mouse double click: the same, unless that conflicts with an existing desktop behaviour (then touch only — say which).

**Where:** find how Enter finishes a chain today (PlanShortcuts / the tool's key handling / the Wall tool in packages/jet_cad_2d_kit_architecture/lib/src/wall/wall_tool.dart) and route the double tap to the same path, preferably in the plan library's canvas (generic for every chain tool) rather than in one tool. If it needs the engine packages (jet_cad_2d_flutter's gesture or tool layer), STOP and report NEEDS_CONTEXT.

**Tests:**
- `DT1 phone, touch: Wall tool, tap A, tap B, tap C, double tap → two walls A-B and B-C (or three if the rule keeps the double-tap point — as pinned), the tool back to its first-point state, a new tap starts a new chain`.
- `DT2 a single tap after a pause does not end the chain` (no false double tap).
- `DT3 Enter still ends the chain as before` (desktop unchanged).
- PH1 (packages/jet_cad_2d_integration/test/phone/phone_design_test.dart) ends its wall chain by a double tap instead of picking another tool, assertions kept.
- A mutation that turns DT1 red.

**Docs:** docs/host-guide.md §14 — replace "a chain ends by picking another tool" with the double tap (the probe needs no change unless a dart block changes). CHANGELOG lines under "## Unreleased" in each touched package.

**Gates:** every touched package (plan and integration with --enable-vmservice), check_guide, check_kit_deps.
