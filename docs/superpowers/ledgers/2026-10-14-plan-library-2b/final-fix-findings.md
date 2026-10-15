# Final fix wave — findings (from final-review.md; controller rulings applied)

Full review: final-review.md (same folder). Fix every item below in one wave. Each code/test change gets a named mutation turned red (quoted), reverted, `git diff --quiet` exit 0. Ported tests keep their assertions (A12).

## Important

**I-1. In service, a mounted PlanCanvas still edits the design.** `lib/src/canvas/plan_canvas.dart` never reads the mode; only `PlanController.execute` is refused in service. The design's tools write through `ToolContext.execute` (jet_cad_2d_flutter tool.dart:108) and the design's engine permissions stay as they are in service. A host that keeps a PlanCanvas mounted (PlanServiceView shows nothing in design, inviting both mounted) lets staff move/delete design objects in service: `dirty` moves (spec: "dirty never moves in service") and the record's `from` values go wrong.
Controller ruling: while `_service != null` the design document's engine permissions are read-only (DraftPermissions read-only form, as 2a's readOnly derives); restored to `permissions.draft` on leaving service (setMode(design), and when load/newPlan in service replace the copy — keep the rule "read-only exactly while a copy exists"). The `permissions` setter writes `value.draft` to the design only in design mode (in service it is applied on leaving). Test (new, e.g. SM-design-readonly): a PlanCanvas over the controller mounted in service; a drag on a design object (or the tool's execute) → `save()` bytes and `dirty` unchanged; after setMode(design) the same drag edits. Also: the permissions setter in service does not re-open the design. Mutations: (a) skip the read-only switch on entering service; (b) the setter writes `value.draft` in service.

**I-2. The ledger's own fix-wave items.**
- Port `packages/jet_cad_floor_plan/test/host/view_palette_test.dart`'s service-mode palette tests (M-DT-10 for ServiceView, M-DT-11 in each mode) into the plan library (PlanServiceView / PlanEditor in service; FloorPlanMode.selection → PlanMode.service), assertions unchanged, each with its mutation.
- docs/superpowers/notes/2026-10-14-plan-library-2b-results.md (~lines 363-368, 772-773): the view_palette gap is no longer "open" — say it was ported in the final fix wave (name the tests); add the final fix wave to the note (what changed, its tests and mutations, the gate re-run).
- STATUS.md: the In-flight 2a paragraph's "A14 awaits the human's word" (~:429) → settled by spec decision 9; "Resume here" points at the results note's "Spec gaps" section and states: 2b complete on its branch after the final review and fix wave, not merged, not pushed; next: the human's word on merge; F-1 (chrome_change_test.dart, design-only, a 2a gap) open for the human.
- packages/jet_cad_2d/CHANGELOG.md: remove the stray blank line before the E5 bullets in `## Unreleased`.

**I-3. No test pins that restoreService moves revision / notifies.** `plan_controller.dart` ~:1915 (`_revision.value++` in restoreService) and the `notifyListeners()` calls in restoreService and resetService. The notify is what moves PlanServiceView onto the new copy. Fix: extend SR-C14 (or a new SR-restore-revision) with a restore step (revision +1, one listener call; reset: one listener call), and a view test that restores then taps (as SV-7 does for reset). Mutations: delete `_revision.value++` in restoreService; delete `notifyListeners()` in restoreService.

**I-4. No test pins the drag's `roots.isEmpty ||` spend.** `service_tool.dart` ~:413. Under M-ST-empty (delete `roots.isEmpty ||`) a drag from an unselected seat replaces the selection with the seat, its outline rides the preview, nothing executes. Fix: a test (service_tool_units_test.dart): table selected, drag from unselected seat A3 → selection unchanged ({table}), no Move step (copy undo depth unchanged), neither onLayoutChanged nor onUnitsMoved fires; mutation M-ST-empty red.

## Cheap folds (Minor, ruled into this wave)
- M-2: a test asks `unitAt` about a seat (finds it); mutation `placedOnly: true` at the controller's unitAt picker (~:1025) red.
- M-3: pin setUnitsLabel's `|| locks.covers(...)` clause (~:1386): a placed unit covered by the lock set (kits: const []) → setUnitLabel false, no step, and no lockHint raised; mutation: delete the clause.
- T8: run once the mutation dropping `old.selectUnitsOnly != value.selectUnitsOnly ||` in the permissions setter against units_only_select_test.dart; quote it (if it survives, add the pin).
- T12: SS-relabel gains the premise `statusOf(table) == bill` before the relabel.
- T14: RB16-hall gains a premise that the band covers at least one seat.
- M-7: CHANGELOGs complete: the plan library's lists cameraValue/PlanCamera, worldToGlobal/globalToWorld, the unitColourOpacity arguments, unitInspectorBuilder, isUnitSymbol, the SymbolsState type change (and anything else public the barrel gained in 2b — check `lib/jet_cad_2d_plan.dart` against the CHANGELOG); the kit's lists the kUnitLabel* constants. Unreleased sections only; no version change.

## Not in this wave (ruled can-wait; do not touch)
M-1 (mixed-drag seat outline preview), M-4, M-5, M-6, M-8, M-9 and the other deferred minors.

## Gates after the wave
Every touched package's gates (plan library: `flutter test --enable-vmservice`, analyze, format; kit: test/analyze/format + `dart run tool/ci/check_kit_deps.dart`; engine: CHANGELOG-only → `dart analyze` and format suffice), `dart pub publish --dry-run` 0 warnings for jet_cad_2d, jet_cad_2d_kit, jet_cad_2d_plan. Never push, tag, merge or publish.
