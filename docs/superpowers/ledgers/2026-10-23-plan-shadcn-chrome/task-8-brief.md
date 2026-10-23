### Task 8: The library's own symbol gallery

**Files:**
- Create: `lib/src/panels/gallery_grid.dart` (the shadcn gallery body)
- Modify: `lib/src/panels/plan_symbol_gallery.dart` (stop using `SymbolGallery`/`GalleryCategory`/`GallerySymbol`)
- Test: `test/panels/plan_symbol_gallery_test.dart`, `test/editor/{plan_editor,editor_layout}_test.dart`, `test/host/host_kit_test.dart`, `test/example_test.dart`, integration `test/l10n/{leak,determinism}_test.dart`, `apps/architecture_demo/test/library_gaps_test.dart`, `tool/screenshots/test/plan_scenes_test.dart`; new `test/panels/gallery_grid_test.dart`

**Interfaces:**
- Produces: `class PlanGalleryGrid extends StatefulWidget` (internal) —
  `PlanGalleryGrid({required List<PlanGalleryGroup> groups, required String? selectedId, required bool enabled, required ValueChanged<String> onSelect, required SymbolThumbnails thumbnails})`;
  `PlanGalleryGroup(String id, String name, List<PlanGalleryCell> cells)`;
  `PlanGalleryCell(String id, String label, Object thumbnailKey, DraftDocument Function() thumbnailDocument)`.
  Headers keyed `symbol-group-<id>`, cells `symbol-cell-<id>`.

- [ ] **Step 1: Write failing tests** (`gallery_grid_test.dart`):
  `GG1 a header tap collapses and expands its group; collapse survives a
  rebuild with new groups of the same ids`;
  `GG2 cells are built lazily: with 500 symbols only the visible cells
  build` (count builds);
  `GG3 thumbnails come from the given SymbolThumbnails (the controller's)
  and no other cache is created`;
  `GG4 the selected cell exposes selected semantics; enabled:false → taps
  ignored`;
  `GG5 the search field is a PlanTextField; the loading state shows a
  progress indicator from the scope's colours; no-match shows today's
  words`.
  Read the renderer's `packages/jet_cad_2d_flutter/lib/src/symbol_gallery.dart` for the behaviour to keep (do not modify it).
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** and wire into `PlanSymbolGallery` (public signature unchanged).
- [ ] **Step 4: Run; ruling** R-GAL (`SymbolGallery`/`GalleryCategory` finders → `PlanGalleryGrid`/`PlanGalleryGroup`, same keys).
- [ ] **Step 5: Mutation** M-GG1 collapse state keyed by index instead of id → GG1 red. Revert.
- [ ] **Step 6: Gates (plan, integration, architecture_demo, tool/screenshots `flutter test`); commit** `feat(plan): the library's own shadcn symbol gallery`.

