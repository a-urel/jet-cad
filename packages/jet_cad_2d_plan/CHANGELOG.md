## 0.8.0 (unreleased)

The plan library of jet_cad_2d, in design mode (sub-project 2a).

- `PlanController`: one plan and every system over it; `newPlan`, `load`,
  `save`, `dirty`, `markSaved`; undo and redo (waiting while a tool is
  part-way through a shape); tools by id; `deleteSelection`; the camera;
  a `Stream<PlanChange>`; diagnostics; `missingKits`, `locked`, `damaged`.
- Kits: the kit set validated as a whole; the plan manifest
  (`jetcad.manifest`) written and checked; a missing kit's objects opened,
  drawn, locked and saved unchanged; a kit hook that fails contained by the
  guarding adapter, its objects frozen and locked.
- `PlanPermissions` (`full`, `readOnly`, per-tool and per-action flags),
  enforced at the select gates, the palette, the panels and the bar.
- Symbol libraries loaded asynchronously by `PlanSymbolLoader`, shareable
  across controllers; the gallery.
- Attachment of symbols through the kits' providers; `plan.symbol`.
- Export and import registries: `plan.pdf` and `plan.png` built in, a
  host's own beside them; printing.
- The widgets: `PlanCanvas`, `PlanToolPalette`, `PlanSymbolGallery`,
  `PlanPropertyPanel`, `PlanLayerPanel`, `PlanPagePanel`, `PlanShortcuts`,
  and `PlanEditor` with `PlanEditorBar`.
- Words in English, German and Turkish; `PlanTheme`; the bundled Roboto.

The service mode (sub-project 2b).

- Units: a placed symbol instance whose definition carries `jetcad.unit`,
  or one a kit's parametric type generates (a seat in a row); identified
  by its label (the `UNIT` attribute), numbered on placement when the
  unit is `numbered`; `units`, `unitDetails`, `unitAt`, `select`,
  `fitToUnits`, `labelWarnings`, `unitChanges`; host data and colour
  (`setUnitData`, `setUnitColour`, `setUnitLabel` and their plural forms).
- `PlanMode` and `setMode`: the service mode works on a copy of the design
  with its own systems, lock and failure boundary; `undo`, `redo`,
  `export`, `print` act on the active document.
- Service state by label: `unitStatuses`, `unitGroups`, `groupStatuses`,
  `unitFocus`, `selectedUnits`, `selectedGroup`, `mergeCandidate`; the
  service record `jet_cad.service` (`serviceJson`, `restoreService`,
  `resetService`, `serviceEdited`, `serviceChanges`).
- `PlanServiceView` with `PlanServiceBar`, the events (`onUnitTap`,
  `onUnitDoubleTap`, `onUnitContextMenu`, `onGroupTap`, `onUnitHover`,
  `onUnitsMoved`, `onFloorTap`, `onMergeRequested`, `onSplitRequested`,
  `onLayoutChanged`), unit overlays (`PlanUnitOverlay`,
  `PlanOverlayLayout`); `PlanEditor` shows it in service and keeps the
  plan in place across a switch.
- `PlanPermissions`: `relabel`, `selectUnitsOnly`, `serviceMove`,
  `serviceMerge`, the `unitsOnly` profile. `PlanTheme`: the service and
  colour fields. Words for units and the service mode in English, German
  and Turkish; a host's own words (`PlanController(words:)`).
- In design, a generated unit stands for its object: a click on a seat
  selects its row. A window band over a row of seats alone selects
  nothing (a known limit).
- Unit types: `PlanUnit`, `PlanUnitDetail`, the `PlanUnitChange` events
  (`PlanUnitAdded`, `PlanUnitChanged`, `PlanUnitRemoved`,
  `PlanUnitsReplaced`), `UnitLabelProblem`, and the label warnings
  (`UnitLabelWarning`, `UnitProblem`, `Unlabelled`, `DuplicateLabel`,
  `BadLabel`); `UnitStatus`, `UnitGroup` and `ServiceRestore`;
  `PlanServiceAction`, `PlanLongPress`, `PlanFloorDrag`, `PlanOverlaySize`
  and `PlanUnitOverlayBuilder`.
- The camera for a host: `cameraValue` (a `PlanCamera` per pan, zoom and
  fit), `worldToGlobal` and `globalToWorld`.
- The unit colours in output: `export` and `print` take
  `unitColourOpacity` (default `kUnitColourOpacity`, 0.35), and
  `PlanExportRequest.unitColourOpacity` carries it to every exporter. All
  three refuse an opacity not finite or outside [0, 1] (`ArgumentError`).
- The unit section in `PlanPropertyPanel` (the label, its duplicate
  warning, the capacity, a quarter turn either way);
  `PlanEditor(unitInspectorBuilder:)` builds a host's inspector under the
  panel for one selected placed unit.
- `isUnitSymbol`, the gallery filter for the `unitsOnly` profile.
- `PlanController.symbolsState` is now typed `SymbolsState`, moved to
  `jet_cad_2d_kit` and re-exported here; 2a's `PlanSymbolsState` is removed.
- While the plan is in service the design document is read-only: a
  `PlanCanvas` or a kit tool still mounted cannot edit it. Leaving service
  gives it the permissions' engine permissions again.
- Sub-project 3a: a kit tool's notice on the status line, put into words
  when read (`PlanController.toolNotice`, `textOf`).
- Sub-project 3a: a plan built in code (`PlanController(build:)`,
  `newPlan(build:)`) and every kit's `prepare` run on a plan the library
  makes, never on one it loads or imports.
- Sub-project 3a: the property panel's `TextDisplay` row, hidden fields
  and the object view.
- Sub-project 3a: the words' decimal separator from the UI language.
- Sub-project 3a: numbered names over the contract's `numberedNameIndex`.
- Sub-project 3a: a grip refusal during a drag (`ArgumentError`) gives no
  move and no diagnostic, and plan.select's drop is refused by the rule
  `execute` uses (no edit, no exception; a `StateError` still escapes).
- Sub-project 3a: a frozen object's live references locked.
- Sub-project 3a: a choice row hands the focus back to the canvas once a
  choice is made.
- Sub-project 3a: `PlanShortcuts` remounted on the same controller: the
  last one mounted speaks for its keys.
- Sub-project 3a: the symbol box family now the contract's.
