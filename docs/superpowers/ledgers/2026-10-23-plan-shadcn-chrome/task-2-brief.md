### Task 2: The scope

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/chrome/shad_scope.dart`, `lib/src/chrome/host_slot.dart`
- Modify: the root `build` of `PlanEditor`, `PlanToolPalette`,
  `PlanSymbolGallery`, `PlanPropertyPanel`, `PlanLayerPanel`,
  `PlanPagePanel`, `PlanServiceView` (wrap in `PlanShadScope`); wrap every
  host slot in `PlanHostSlot` (editor bar and service bar `leading` /
  `trailing`, `inspectorBuilder`/`unitInspectorBuilder` output,
  `contextualPanels`, the service view's side panel, `unitOverlayBuilder`
  output)
- Test: `packages/jet_cad_2d_plan/test/chrome/shad_scope_test.dart`, `test/chrome/host_slot_test.dart`

**Interfaces:**
- Produces:
  - `ShadThemeData planShadThemeFrom(ThemeData theme)` — the spec's
    mapping table, brightness from `theme.brightness`, text theme family
    from `theme.textTheme.bodyMedium?.fontFamily`.
  - `ShadThemeData planShadThemeOf(BuildContext context)` — the ancestor
    `ShadTheme`'s data, else `planShadThemeFrom(Theme.of(context))`
    (memoised per `ThemeData` identity).
  - `class PlanShadScope extends StatelessWidget { const PlanShadScope({super.key, required Widget child, ShadThemeData? data}); }`
    — `data` given (routes) → provides it; else ancestor `ShadTheme` →
    passes through; else provides the derived data plus
    `ShadMouseAreaSurface` and `ShadMouseCursorProvider` (check
    `shadcn_ui-0.57.1/lib/src/app.dart`). In every case installs
    `DefaultTextStyle` (`theme.textTheme.p` with `colorScheme.foreground`)
    and `IconTheme` (`colorScheme.foreground`, size 16).
  - `class PlanHostSlot extends StatelessWidget { const PlanHostSlot({super.key, required Widget child}); }`
    — `Material(type: MaterialType.transparency, child: child)`.

- [ ] **Step 1: Write failing tests** (`shad_scope_test.dart`):
  `SC1 under a bare MaterialApp a scope provides a ShadTheme whose
  background is the ColorScheme's surface and foreground its onSurface`
  (use a hand-built scheme with distinct, non-default colours);
  `SC2 under an ancestor ShadTheme the scope's descendants read that
  ShadTheme's colours` (distinct primary `0xFF123456`);
  `SC3 dark ThemeData → derived brightness dark`;
  `SC4 a plain Text below the scope takes the ShadTheme's font family and
  foreground` (host ShadTheme with family `'ScopeTestFont'`);
  `SC5 an Icon below the scope takes the foreground`;
  `SC6 switching the ancestor ShadTheme light→dark rebuilds descendants
  with the dark colours, no exception`;
  `SC7 a useMaterial3:false ThemeData and a ColorScheme built with only
  the required fields derive a theme where foreground/background and
  primaryForeground/primary contrast ratio ≥ 4.5`;
  `SC8 the derived data is computed once for one ThemeData across two
  rebuilds` (count through a test hook `@visibleForTesting int debugPlanShadDerivations`).
  `host_slot_test.dart`: `HS1 a Material TextField and an InkWell in each
  host slot of PlanEditor and of a standalone PlanServiceView build under
  a bare MaterialApp and respond to a tap` (one case per slot listed in
  Files).
- [ ] **Step 2: Run** `flutter test test/chrome` → FAIL.
- [ ] **Step 3: Implement** both files and the wrapping.
- [ ] **Step 4: Run** `flutter test test/chrome` → PASS; the whole suite → green (a failure from `DefaultTextStyle` alone is a ruling "default text style", recorded, not an assertion change).
- [ ] **Step 5: Mutations** M-SC1 the scope always derives (SC2 red);
  M-SC2 never derives (SC1 red: no ShadTheme); M-SC3 no `DefaultTextStyle`
  (SC4 red); M-HS drop `PlanHostSlot`'s `Material` (HS1 red). Revert each.
- [ ] **Step 6: Gates; commit** `feat(plan): the shadcn scope and host slots`.

