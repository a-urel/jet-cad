### Task 6: The responsive design-mode layout

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/editor/editor_layout.dart` (`PlanEditorLayout`, `PlanLayoutBreakpoints`, the drawer host)
- Modify: `packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart` (`_editor`, `_topBar`, `_leftPanel`)
- Test: `packages/jet_cad_2d_plan/test/editor/editor_layout_test.dart`

**Interfaces:**
- Produces:
  - `enum PlanEditorLayout { phone, tablet, desktop }`.
  - `final class PlanLayoutBreakpoints { const PlanLayoutBreakpoints({this.tablet = 600, this.desktop = 1000}); PlanEditorLayout layoutFor(double width); }`.
  - `PlanEditor({..., PlanLayoutBreakpoints breakpoints = const PlanLayoutBreakpoints(), PlanEditorLayout? layout})` — `layout` forces one.
  - Keys for tests and hosts: `Key('chrome-left-button')`, `Key('chrome-right-button')`,
    `Key('chrome-left-drawer')`, `Key('chrome-right-drawer')`, `Key('chrome-tool-strip')`.
  - Desktop: today's tree, byte-for-byte the same widgets and keys.
  - Phone (D1): no docked columns; the bar's first item the left button, its
    last the right button; the left drawer holds `_leftPanel`, the right
    drawer the right column's content (property panel, inspectors, layers,
    page). Tablet (D2): `chrome-tool-strip` docked left, icons only, a
    symbols icon at its foot opening the gallery as the left drawer; the
    right button as on the phone.
  - D5: one drawer at a time; a tap on the canvas, the same button again,
    or Escape closes it; opening never moves the camera. Drawers keep their
    panels' state (`maintainState`).

- [ ] **Step 1: Write the failing tests** (sizes via `tester.binding.setSurfaceSize`, reset in tearDown) —
  `EL1 1440 x 900: chrome-left/right present, no buttons, no drawers` (desktop as today);
  `EL2 375 x 812: no docked columns; both buttons in chrome-top; left button opens the tools drawer, right button the properties drawer`;
  `EL3 800 x 1280: chrome-tool-strip present, the symbols icon opens the gallery drawer, the right button opens properties`;
  `EL4 one drawer at a time; canvas tap, the button again, Escape each close it; the camera transform unchanged by opening`;
  `EL5 breakpoints (tablet: 700) and layout: PlanEditorLayout.phone both obeyed`;
  `EL6 a drawer open on the phone, the surface resized to 1440 x 900 and back: no exception, no drawer left open, the selection kept` (Review Focus 2);
  `EL7 the phone bar at 320 px wide does not overflow` (no RenderFlex overflow error).
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement**; CHANGELOG line.
- [ ] **Step 4: Gates**; every existing `test/editor/*` and `test/panels/*` test passes unedited. Mutation: swap the breakpoint comparison (`<` → `<=` at 1000 with a 1000-wide surface test in EL5) → red.
- [ ] **Step 5: Commit** `feat(plan): PlanEditor on phones and tablets`.

---
## Global Constraints

- CLAUDE.md non-negotiables: no per-entity allocation on the frame path
  (`query_allocation_test.dart`, `paint_allocation_test.dart` stay green);
  draw order by handle; geometric decisions use `Tolerance`, stored values
  exact `==`; never commit `analysis_options.yaml`; never synthesize output;
  English code, comments and commits; commit trailer
  `Co-Authored-By: <model> <noreply@...>` as AGENTS.md says.
- Kit isolation: `dart run tool/ci/check_kit_deps.dart` green; the plan
  library names no kit type id.
- The host never receives a `Handle` (umbrella D18): every new public API
  names objects by `PlanObjectRef`.
- No host vocabulary in any API ("POS", "table id", "monepro").
- 0.8.x compatibility: `unitInspectorBuilder`, `setUnitData`,
  `setUnitsData`, `PlanUnitDetail.data`, `unitChanges` keep their behaviour;
  a plan saved by 0.8.1 opens with its unit data intact.
- Desktop unchanged: at ≥ 1000 logical px wide every existing test under
  `packages/jet_cad_2d_plan/test/editor/` passes **without edits**.
- Host data limits are today's: `unitDataProblem` (32 keys, key
  `^[a-z0-9_.-]{1,64}$`, value ≤ 1024, no control code units).
- Breakpoints (D4): phone `< 600`, tablet `600 ≤ w < 1000`, desktop `≥ 1000`
  logical px of the editor's own width.
- Versions are not bumped; each touched package's CHANGELOG gets its lines
  under `## Unreleased`. Publishing is the human's.

