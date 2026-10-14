# Task 7 report

Status: DONE. Commit 1a2c645e "feat(plan): the unit label system, the placed number, rotation (2b S2)" (one commit; I amended my own unpushed commit once to add a bare-document assertion, see "Finding").

## Implemented
- lib/src/units/unit_label_system.dart: restampedUnitLabel, UnitLabelSystem, UnitLabelEdit (ported; UnitComponent check, root rule, unitLabelOf from Task 6).
- lib/src/units/unit_rotate.dart: rotateUnitCommand.
- symbol_placer.dart: placeSymbol(units:), instance handle allocated before the label's.
- plan_symbol_tool.dart: units; plan_controller.dart passes session.units.current; session.dart: parametric -> labels -> lock, dispose in reverse.
- Tests: unit_label_stack_test (UL-stack, UL-place-number, UL-assigned, UL-seat + new UL-turn-row), unit_label_system_test (LS1-7, LS6b, TL3, TD10), unit_placement_test (TP1-7), unit_data_delete_test (TD7-TD9), unit_rotate_test (TS9, TS10). Assertions unchanged; TP7 changed subject as brief says (finding P-2); `rig` in the label-system test builds plan(catalog: boxKit catalog) so SquareParams is registered (LS3).

## Evidence
- Process note: I wrote the implementation before running the stack test, so there is no RED transcript; the named mutations below are the red evidence.
- GREEN stack test: "00:00 +4: All tests passed!" (before UL-turn-row); full package gate: "+817: All tests passed!", `flutter analyze`: "No issues found!", `dart format --set-exit-if-changed`: exit 0. Re-run after the amend of test/units test/symbols test/tools test/panels: green, analyze clean, format 0. No standing failures hit.
- Non-ASCII: oracle literals (ğ, ä, ş, °) preserved as literal characters in the ported tests (same as oracle).

## Mutations (each reverted; `git diff --quiet` exit 0 every time)
- M-UL-stack (session.dart swap install and dispose): UL-stack "Expected: false Actual: <true>".
- M-UL-number (placer instanceToWorld identity): UL-place-number red "Actual: [0.0, 1.0, 1.0, 0.0]" -- ONLY after the finding below.
- M-UL-tool (drop units: in tool): UL-place-number "Expected: ['14'] Actual: []".
- M-UL-assigned: UL-assigned "Expected: empty Actual: [(int, String):(54, 13)]".
- M-UL-root: UL-seat "within <1e-12> of <-0.35> Actual: <0.0>".
- M-LS-stamp: LS1 "Expected: Capability.geometry Actual: Capability.transform".
- M-LS-cheap: LS6 "Expected: not <Instance of 'UnitLabelEdit'>".
- M-TD10 (drop r.inverse.apply): TD10 red (plan JSON differs, transform turned).
- M-TP-number: TP2 "Expected: ['1','2','3'] Actual: ['1','1','1']".
- M-TS9: TS9 "within <1e-9> of <-2300.5> Actual: <-1177.86...>".
- M-UL-turn (test/support/test_kit.dart row label `instanceToWorld: toWorld.multiply(seat)` -> `seat`; test_kit.dart is committed): UL-turn-row red.

## Finding (brief's M-UL-number is masked)
With the label system installed (the controller always does), the placement's touched set contains the new instance, so UnitLabelEdit restamps the label upright regardless of what the placer wrote. M-UL-number left UL-place-number GREEN as briefed. Fix: UL-place-number now also places on a bare plan() (no label system) and asserts the label upright; M-UL-number is now red there. TP1 (ported) also pins the placer's own stamp.

## Open point (rows turned)
Previously no test turned a row group. Added UL-turn-row: TransformNodeCommand turning rowA 37 degrees about an off-row pivot through the controller; every seat label upright for group*seat, rotation scalar differs from before, undo restores payloads byte-equal. Behaviour is correct: the row's regeneration restamps (the label system does not touch generated units). Named mutation M-UL-turn above. rotateUnitCommand returns null for a GroupNode, so the row test uses TransformNodeCommand.

## Concerns
None blocking. Commit trailer is "Claude Opus 5.5" per implementer instructions.
