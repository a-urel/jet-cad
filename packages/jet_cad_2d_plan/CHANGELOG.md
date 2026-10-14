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
