# Task 5 report: the object inspector

Status: DONE. Commit: feat(plan): the object inspector (HEAD of feat/pos-host after 6a1fba07).

Files: lib/src/editor/object_inspector.dart (new), plan_editor.dart (objectInspectorBuilder, mounted under PlanPropertyPanel, before the unit inspector slot's successors / PlanLayerPanel, Key('object-inspector'), only while propertyPanel), CHANGELOG, test/editor/object_inspector_test.dart (OI1-OI6).

Gates (jet_cad_2d_plan): dart format 0 changed; flutter analyze "No issues found!"; flutter test --enable-vmservice "+1606: All tests passed!" (unit_inspector_test unedited).

Mutations (each run on committed code, reverted with git checkout, diff clean):
- unitsElsewhere forced false (units go to the new builder even when the old one is given): OI3 red.
- drop the `c.isLocked(h)` check: OI4 red (kit-locked planter, kit "fx" missing).
- cache the first detail in build instead of reading fresh: OI6 red.

Decisions:
- Locked: `isLocked` (kit lock: missing/frozen kit) shows nothing, same predicate as PlanPropertyPanel. An object on a locked LAYER is not isLocked; the property panel shows it, so this does too (OI4 asserts that).
- Unit routing: with unitInspectorBuilder given, a unit shows nothing in the object inspector, even when UnitInspector itself shows nothing (unlabelled/duplicate label).
- No fields added to PlanObjectDetail; a unit's section is read by the host from controller.unitDetails (documented on the builder).
- Relay: copy of UnitInspector's (FrameSafeRelay + revision listener), detail read fresh at each build via objectDetailOf, so a deleted object builds nothing (OI5: builder never saw a stale ref).
- OI2 uses the rail test type (view.rail, title "Rail") as the kit-type object, not a real room.

Concerns: none.
