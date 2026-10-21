# Task 3 report: host data on any object

Status: DONE (with concerns below).

Commits: 3eeb0ae9 feat(plan): host data on any object; then "test(plan): OD5 pins the up-front lock refusal (no lock hint)".

## What
- lib/src/objects/object_ref.dart: PlanObjectRef (value-equal by handle; `PlanObjectRef.of(handle)` and `.handle` are @internal).
- lib/src/objects/object_detail.dart: PlanObjectKind {unit, symbol, type}, PlanObjectDetail.
- PlanController: objectDetails, objectDetailOf, setObjectData, setObjectsData (storage = the UnitData component `jetcad.unit_data` on the root node; one "Object data" step).
- Barrel exports the three types; barrel_test ED-9 updated deliberately (added the three names). CHANGELOG: created `## Unreleased` at top.
- Fixture test/fixtures/plan_0_8_1_unit_data.json (+README.md) generated BEFORE the production change by a throwaway test (deleted) on the unchanged library.

## Decisions
- Root object = root-level node: a placed unit instance (non-generated), a root group of a registered kit type, or a root symbol instance. Classification order: unit, type, symbol.
- Plain groups (grouping feature) are not objects (objectDetailOf null, setObjectData false). Generated units are not listed on their own (their object stands for them; setUnitData still reaches them by label).
- label: unit label (UnitInfo.text, null if unlabelled); type: titleWordOf resolved through the kit's words in the controller locale (null if no word / hook throws); symbol: null. symbolKey = SymbolComponent.key of the definition (units and symbols).
- Ref identity = handle only (survives save/load, also across controllers). OD7 holds because the new plan has no such object; a handle that exists in a later loaded plan resolves to that plan's object (inherent to persisted-handle refs).
- objectDetailOf answers for any root object (data empty if none); objectDetails lists only those carrying non-empty data, ascending handle (sorted, O(root children), not a frame path).
- objectDetailOf reads the active document (service copy too); writes are design-only.
- Lock refusal done up front (`locks.covers`) so a host call never raises lockHint; locked layer allowed.

## Tests (test/objects/object_data_test.dart) OD1-OD8
OD1-OD7 as briefed (OD1 also checks the "Object data" label; OD2 uses a kit type "Rail" titled via kit words; OD4 reads the fixture); OD8 plain group / root are no object. Fixtures: off-origin, a unit turned 30 deg, a unit on a locked layer mirrored+turned 120, a mirrored turned planter symbol, a rail turned 0.7 rad.

## Gates (real last lines)
- `flutter test --enable-vmservice` (jet_cad_2d_plan): `01:57 +1588: ... All tests passed!`
- `flutter analyze`: `No issues found! (ran in 3.6s)`
- `dart format --output=none --set-exit-if-changed .`: `Formatted 311 files (0 changed)`
- check_kit_deps.dart ran (last line of its output not captured in the chained command; no failure shown, exit 0 for the chain). Kit not touched.
- git status clean of analysis_options.yaml changes.

## Mutations (on committed code, reverted, `git diff --quiet` passed)
- M1 skip `locks.covers` in setObjectsData: initially survived (engine's guard also returns false); added `lockHint` assertion to OD5, now OD5 red.
- M2 sort descending -> OD2 red. M3 units not classified -> red (OD1-OD4 region). M4 type label null -> OD2 red. M6 drop unknown-ref check -> OD7/OD8 red. M7 drop `_requireDesign` -> OD6 red. M8 types not objects -> OD2/OD8 red.
- M5 drop the controller's own `unitDataProblem` check: survives, equivalent mutant (the UnitData constructor throws the same ArgumentError). Kept as the shared message path.

## Concerns
- `objectDetails` lists only objects with data, so a host cannot discover a ref for an object with no data except via the Task 5 inspector (selection); intended by the brief, flagging for Task 5.
- Refs are handle-only: a stale ref used after loading a different plan could name an unrelated object whose handle collides.

## Fix round 1
PlanObjectRef / PlanObjectDetail.ref docs and the CHANGELOG line now state: valid for the plan it was read from (and that plan saved and loaded again); deleted -> null/false; after newPlan or a load of another plan, drop and re-read refs (the controller cannot tell old from new with the same handle). No code or test change. analyze: clean; format: 0 changed.
