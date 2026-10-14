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
