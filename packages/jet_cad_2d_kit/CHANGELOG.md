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
