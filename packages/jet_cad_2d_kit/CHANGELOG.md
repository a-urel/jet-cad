## 0.1.0

- The kit contract's symbol side: the plan components (`jetcad.symbol`
  with attachment kinds and a size family, `jetcad.unit`, `jetcad.manifest`,
  `jetcad.library`) and `registerKitComponents`.
- The `.jetlib` library format: `SymbolLibrary.decode` and its fifteen
  rules, `SymbolLibrary.merge`.
- `KitNames`, `SymbolLibrarySource`, `bundledLibrary`, `PlanKit`.
- The authoring toolkit (pure Dart): the catalog language,
  `encodeLibrary`, the shared shape helpers, the geometry snapshot and the
  conformance test.
- Property specs (`LengthProperty`, `AngleProperty`, `NumberProperty`,
  `ChoiceProperty`, `ToggleProperty`, `TextProperty`, `ValueDisplay`,
  `ActionProperty`), their erased binding `PropertyField`, `PlanGate`,
  `ValueUnit` and `ColourTarget`.
- The code side: `PlanType`, `PropertySectionBuilder`, `TypeGuard`,
  `PlanTool`, `PlanToolSettings`, `PlanServices`, `KitWords`,
  `KitNamesWords`, `Disposable`, the attachment types and `KitDiagnostic`.
  `PlanKit` gains `types`, `tools`, `attachments` and `propertyIds`, and
  `validate` checks them; seven `KitProblemCode`s for the code side and the
  kit set; `isCodeId`. The contract depends on `jet_cad_2d_flutter`.
- `retired` on `jetcad.symbol` and `CatalogSymbol`, written only when true;
  `conformance` takes `typeIds`, `toolIds` and `propertyIds`; rule 11
  refuses a unit outline by its width, 2·area/perimeter, not by its area.
- `PlanSwatch`, the plan's eight-colour palette, and `planSwatchNamed`:
  kits name a swatch without depending on the plan library.
- Sub-project 2b: `PlanServices.symbolDefinition` (`SymbolDefinitionRef`)
  and `symbolsState`; `SymbolsState`, moved from the plan library; a unit's
  label (`kUnitLabelTag`, `unitLabelHeight`, `unitLabelStamp`,
  `unitLabelPayload`, `unitLabelAttrib`, which builds a generated unit's
  label as an E5 `GeneratedAttrib`, and the label's constants
  `kUnitLabelMaxHeight`, `kUnitLabelTopShare` and `kUnitLabelTextAttrs`); `PlanGate.relabel`; the `unit:` word
  namespace and `validateHostWords`; `KitProblemCode.unitKindWord`, which
  conformance reports for a unit kind the contract does not name without
  an English word. `UnitLabelling.assigned`: the label comes from a kit's
  type, the property panel or the host.
