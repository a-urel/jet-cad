# The symbol palette (09b) — design

**Date:** 2026-10-01. **Status:** design, **revision 3**. Revision 1 (`b6c2591`) was reviewed
independently: "Ready with amendments", 0 blocking, 5 major, 6 minor, 1 nit
(W-1 to W-12), each applied below; see [Revision 2](#revision-2). Its
spot check: "Ready with amendments" (S-1 to S-5, small), applied in
[Revision 3](#revision-3). Awaiting the human's approval.
**Sub-project:** `roadmap/09-symbol-library.md`, slice **09b** (09a, the
core, is merged at `b4e7cdd`). **Size:** M: one render-layer widget pair,
one app tool, one app panel, one pure function.
**Branch:** `spec-09b/symbol-palette`, cut from `main` at `75dc2e0`.
**Depends on:** 09a (merged), 12a. **Supersedes** the 09b-scoped decisions of
the [09 spec](2026-09-30-symbol-library-design.md) (D8 to D12, R-4): where
they differ, this spec wins and says so (D11 "Changes to the 09 spec").
**Brainstormed with the human on 2026-10-01**, on `main`, after a survey of
the app's left panel, tool lifecycle, focus handling and painter (the facts
below are from `main` at `75dc2e0`).

**Inputs read:** `CLAUDE.md`; `STATUS.md`; the 09 spec (whole) and its
"Amended at execution (Plan 09a)"; the 09a results note, "Owed to 09b";
`apps/floor_planner/lib/{main,tool_palette,panel_focus,shortcut_guard,
document_host}.dart`, `lib/symbols/*.dart`;
`packages/jet_cad_2d_flutter/lib/src/{tool,draft_painter,draw/placement_tool,
interaction_layer,tile_cache}.dart`; `packages/jet_cad_2d/lib/src/index/
drag_snap.dart`, `document/style_resolver.dart`.

## Decisions the human made on 2026-10-01

(The 09 spec's decisions 1 to 12 stand: static symbols, key + version
identity, select-then-click, free-standing instances, the gallery widget in
`jet_cad_2d_flutter`.) New:

1. **Two tabs in the left panel, "Araçlar | Semboller"** (shown in English as
   *Tools | Symbols*, the app's own language): the tool list is the first
   tab, unchanged; the gallery is the second and uses the panel's height.
2. **A two-column grid, the name under the thumbnail**, in collapsible
   category groups.
3. **The ghost draws the symbol's real lines** (an overlay), not only its
   bounds: orientation and mirror are visible before the click.
4. **`R` rotates and `M` mirrors while the placement tool is armed**, as the
   09 spec's D11 said; the cost (R and M do not choose Rectangle or Room
   until `Esc`) stands.

## What this delivers

- A **Symbols** tab: a search box, then the library's categories as
  collapsible groups of thumbnails; typing filters; a click arms the
  placement tool.
- The **placement tool**: a ghost of the symbol's real outline follows the
  pointer (snapping like the drawing tools); press, drag, release places it
  at the release point; `R`, `Shift+R`, `M`, `Esc`; one undo step per
  placement; it stays armed.
- The library loaded once per app from the bundled asset, with loading and
  failure states.

## Non-goals

- Drag-and-drop from the gallery; the user's own libraries; recent or
  favourite symbols; a free rotation angle (the Select tool's grip turns a
  placed instance); selecting the placed instance; dark theme (the app has
  none: `main.dart:91`); keyboard navigation inside the grid beyond what
  Flutter's focus gives a button.

## Facts established (verified on `main`)

- **F-1.** The left panel is `Container(key 'chrome-left', width: 240, …,
  child: ToolPalette)` (`main.dart:750-761`), outside `ShellShortcutGuard`
  (only `chrome-right` is, `:784`); `ToolPalette` is under `ExcludeFocus`.
- **F-2.** The shell owns its tools as `late final` singletons
  (`main.dart:237-268`); per-tool state is a `ValueNotifier` given at
  construction (`OpeningTool(k, _openingSettings[k]!, …)`). `_activate`
  (`:545-550`) refuses a non-Select tool while geometry is denied, clears the
  selection, then `_tools.activate`. Escape is bound to `_escape` (`:553`),
  which activates Select; an idle tool returning `ignored` lets it through.
- **F-3.** Taken letters: V L P R B W D N G M S I C A T F. `R` is Rectangle,
  `M` is Room. A shell letter must be in `kShellLetterKeys`
  (`shortcut_guard.dart:7-24`); a tool-consumed key need not.
- **F-4.** Panel text fields use `PanelFieldFocusNode` (`panel_focus.dart`):
  Enter and tap-outside call `handBack()`, which returns focus to the canvas
  (plain `unfocus()` must not be used, `panel_focus.dart:25-31`);
  `ShellShortcutGuard` maps the letters, undo/redo chords and **Escape** to
  `DoNothingAndStopPropagationTextIntent`, so Escape reaches no panel field
  today. `_settlePendingInput` (`main.dart:530-536`) hands focus back.
- **F-5.** Snap for a tool: `resolveDragPoint({raw, orthoBase, index,
  apertureWorld, objectSnap, page, gridStepMm, scratch, out})`
  (`drag_snap.dart:39`), `kSnapAperturePixels` = 10 px over `camera.scale`;
  `PlacementTool` shows the pattern (`placement_tool.dart:117-136`).
- **F-6.** `InteractionLayer` delivers a primary down to `onPointerDown`, a
  hover (no buttons, no active pointer) to `onPointerMove`, exit to
  `onPointerExit`, a cancel to `tool.cancel`. Neither the layer nor any tool
  reads `PointerDeviceKind` (only `text_entry_overlay.dart:100` and
  `camera_gesture_detector.dart:95` do): touch has no hover, so no ghost
  before the press. **The layer keeps `_activePointer` until the up**
  (`interaction_layer.dart:138-166`): a tool that cancels a press still
  receives that press's moves and up.
- **F-7.** `DraftPainter(document:, index: SpatialIndex(doc), resolver:
  DocumentStyleResolver(doc, foreground:))` paints into any `DrawSink`
  without a widget tree (`draft_painter.dart:329`); the golden test
  `stroke_width_golden_test.dart:202-230` is the recipe (`PictureRecorder`,
  `Canvas`, `VerticesDrawSink`, `paint`, `flush`). `Picture.toImageSync` is
  used only inside `TileCache` (private); `Picture.toImage` (async) is the
  portable one. The vertices sink is the default on web.
- **F-8.** `DocumentStyleResolver.foreground` defaults to white; BYBLOCK
  leaves under a default-style instance resolve to ACI 7, which is that
  foreground; `foregroundFor(bg)` picks black on a light background
  (`style_resolver.dart:28`). The shell does it at `main.dart:197-204`; a
  thumbnail must pass it explicitly.
- **F-9.** The app has **no dark theme** (`ThemeData(colorSchemeSeed: …)`
  only); the 09 spec's "light and dark" look item is void.
- **F-10.** The app has no use of `rootBundle`; the asset is declared and
  read with `File` in tests only. `FloorPlannerApp` is above the keyed
  `DocumentHost` shell (`document_host.dart:518-527`); the shell is rebuilt
  per document.
- **F-12.** **Key routing:** `InteractionLayer`'s `Focus(focusNode: _focus,
  autofocus: true, onKeyEvent: → _tool.onKey)` holds the primary focus
  (`interaction_layer.dart:225-228`); the shell's `CallbackShortcuts`
  (`main.dart:656-674`) is an ancestor and sees only what bubbles. A
  `handled` R or M never reaches the Rectangle or Room binding
  (`main.dart:467-471` says so for Z).
- **F-13.** **Escape in a guarded field** has a precedent: the text entry
  nests `ShellShortcutGuard › CallbackShortcuts(Escape) › TextField`
  (`text_entry_overlay.dart:135-139`); the nearer binding wins.
- **F-14.** `paintWorldOverlay` paints in `world − origin` (`tool.dart:101-104`,
  Ruling 03-3); a world matrix flips y, and world angles go into
  `Path.addArc` unchanged (`outline_cache.dart:283-289`,
  `select_tool.dart:822`); a preview composes its matrix in doubles into a reused
  `Float64List(16)` (`selection_overlay.dart:211-223`, which composes `M ∘ T ∘
  translate(+origin)` for an already rebased path: the same technique, a
  different composition).
  The snap marker is screen-space (`paintOverlay`,
  `placement_tool.dart:280-290`).
- **F-15.** Under `testWidgets`, `Picture.toImage` and `toByteData` complete
  through engine callbacks that a pumped test never delivers: a pixel test
  needs `tester.runAsync` (`stroke_width_golden_test.dart:234-241`).
- **F-16.** The dispatcher refuses a denied command by itself
  (`undo.dart:191`): a test of the tool's own permission check must look at
  the handle seed and the absence of a throw, not at "nothing placed".
- **F-17.** 24 test files pump a bare `PlannerShell`.
- **F-11.** `placeSymbol(...)` allocates its handles when called and returns
  an unexecuted `CompoundCommand` reporting `{structure, geometry,
  components}` (09a); `PlacementTool.commit(ctx, build, {needs})` checks
  permissions before `build` (Ruling 05-3).

## Decisions

### D1 — Where the pieces live

- **Render layer** (`packages/jet_cad_2d_flutter`): `src/symbol_gallery.dart`
  (the widget) and `src/symbol_thumbnails.dart` (the cache), exported. They
  know no `SymbolEntry`, no `SymbolComponent`, no `DocumentHost`.
- **App** (`apps/floor_planner/lib/symbols/`): `symbol_search.dart` (pure),
  `symbol_library_state.dart` (the pure state type, D2),
  `symbol_library_loader.dart` (Flutter: the `ChangeNotifier` over
  `rootBundle`, D2), `symbol_place_tool.dart` (Flutter, D6),
  `symbol_ghost.dart` (the ghost path, pure `dart:ui`, D6),
  `symbol_panel.dart` (the Symbols tab, D7); `main.dart` gains the tabs and
  the wiring (D8); `tool_palette.dart` is untouched.
- Pure files (`symbol_search.dart`, `symbol_library_state.dart`) import no
  Flutter.

### D2 — Loading the library

A `SymbolLibraryLoader extends ChangeNotifier`, created once by
`FloorPlannerApp` (above the document host), holding a
`SymbolLibraryState`: `loading`, `ready(SymbolLibrary)` or
`failed(Object error)`. `SymbolLibraryLoader({Future<Uint8List> Function()?
read})`: the default `read` is `rootBundle.load('assets/library/
furniture.jetlib')`; tests pass a `read` that returns the file's bytes, corrupt
bytes or throws. `load()` runs `read` then `SymbolLibrary.decode`; `retry()`
runs it again after a failure. **`FloorPlannerApp` owns it**: it takes an
optional loader (tests inject one), creates the default one otherwise, calls
`load()` in `initState` in both cases, and disposes the loader only if it
created it. It is passed through `DocumentHost` to `PlannerShell` as an
optional `symbols` parameter. **A bare `PlannerShell()` (24 test files pump
one, F-17) has no `symbols`: no tabs, the panel is exactly today's.** `SymbolLibraryError`, a missing asset and any
other throw all end in `failed`.

### D3 — Search (the 09 spec's D8, unchanged)

`searchSymbols(List<SymbolEntry>, String query)` (pure): the query is split
on white space and lower-cased; a symbol matches when **every** term is a
substring of its name, any tag or its category (case-insensitive); an empty
query matches all. Groups keep the library's category order and symbol
order; an empty group is not shown. No fuzzy match. An empty result shows a
"No symbols match" line with the query and a Clear button.

### D4 — The gallery widget (render layer)

`SymbolGallery({categories: List<GalleryCategory>, selectedId, enabled,
onSelect(String id), thumbnails: SymbolThumbnails, foreground, cellColor})`.
`GalleryCategory{name, symbols}`, `GallerySymbol{id, label, thumbnailKey
(a value), thumbnailDocument (a builder returning a DraftDocument)}`; the
bounds come from the built document's `extents`. **The app's id is
`"$key@$version"`** (the library allows one key at two versions,
`symbol_library.dart:134`), so cell keys and the highlight are unambiguous. It holds **no text field and no search state**: the app filters
and passes the result.

- A scrollable column: per category a header (name, a chevron, the count;
  tap collapses; the collapsed set is widget state, not persisted) and a
  two-column grid of cells.
- A cell: the thumbnail, the label under it on one line (ellipsis), a
  tooltip with the full label, a highlight when `selectedId == id`, and
  ink on tap (`Material` + `InkWell`, like the palette tiles). `enabled ==
  false` greys the cells and ignores taps.
- **A cell never takes focus** (`ExcludeFocus`, Ruling 05-6): the canvas
  keeps it, so the shell's shortcuts keep working after a click.
- Cell keys: `symbol-cell-<id>`; header keys `symbol-group-<name>`.
- **A displayed image is a clone**: each cell takes `image.clone()` from the
  cache's image and disposes its own clone when it is disposed or its image
  changes, so the cache may dispose an evicted image under a live
  `RawImage` safely.

### D5 — Thumbnails

`SymbolThumbnails({maxEntries = 64})`: `Future<ui.Image> imageFor(
{key, DraftDocument Function() document, logicalSize, devicePixelRatio,
foreground})`. **Owner:** the app, beside the loader (`FloorPlannerApp`,
R-4's logic: it must outlive the per-document shell), passed down with
`symbols`; disposed with it.

- Painted through `DraftPainter` (`DraftPainter(document, SpatialIndex,
  DocumentStyleResolver(document, foreground))`, a `VerticesDrawSink(
  pixelsPerPaperMm: kLogicalPixelsPerMm, canvas:, devicePixelRatio:)` with
  no `fallback` (only text needs one, `vertices_draw_sink.dart:735`), then
  `flush`) into a `PictureRecorder` whose canvas is first scaled by the DPR;
  then `Picture.toImage(round(w·dpr), round(h·dpr))` (async, the portable
  call on web; F-7). The camera is `ViewportTransform.fit(document.extents
  padded by 8%, logicalSize)`. The scratch `SpatialIndex` is disposed after
  the paint; the scratch document is dropped. **No second render path.**
- The document is the **placer's own output**: the app's builder
  (`thumbnailDocument`) makes `prepareDocument(measurer)` (so
  `registerAppComponents` has run and `SetComponentCommand<SymbolComponent>`
  is accepted, `new_document.dart:18`) and executes `placeSymbol`
  at `at = basePoint`, no turn, not mirrored (an identity transform), so a
  thumbnail is what a placement makes.
- **The foreground is passed explicitly** (`foregroundFor(cellColor
  .toARGB32())`, F-8), so BYBLOCK leaves are dark on the light cell.
- An in-memory LRU of 64, keyed by `(thumbnailKey, logicalSize,
  devicePixelRatio, foreground)`; the cache stores the `Future` (a repeated
  build never repaints, a pending one is shared); evicted and disposed
  entries call `Image.dispose()` once their future has completed; `dispose()`
  of the cache disposes all. Nothing persists. A key change invalidates; no
  other trigger exists, because the library is immutable in a session.
- A failed paint shows an empty cell with the label (never throws into the
  tree).
- **Tests that read pixels run under `tester.runAsync`** (F-15).

### D6 — The placement tool

`SymbolPlaceTool(ValueNotifier<SymbolEntry?> armed) extends Tool`, owned by
the shell like the opening tools (F-2); `armed.value == null` means idle and
the tool is inert (every pointer event ignored, the cursor deferred).

- **Pointer:** a hover (mouse) moves the ghost; a press starts a placement
  and shows the ghost at the press (touch has no hover, F-6); a move while
  pressed follows; **release places at the release point**. Pointer cancel and
  `Esc` mid-press cancel the press and place nothing: **the tool marks the
  press cancelled, ignores that pointer's remaining moves, and its up places
  nothing** (F-6: the layer still delivers them); the next press starts a
  new placement. A secondary button does
  nothing. After a placement the tool stays armed with the same rotation and
  mirror; the placed instance is not selected.
- **Snap:** `resolveDragPoint` with the tool's own `SnapResult`/`DragPoint`
  scratch (F-5): object snap per F3 at `kSnapAperturePixels / scale`, else
  grid snap, else the raw point. The snapped point is `at`.
- **Keys:** `R` rotates **one quarter turn counter-clockwise** (the positive
  `quarterTurns` of `placementTransform`), `Shift+R` clockwise, `M` toggles the
  mirror; they work idle-armed and mid-press (the ghost updates). **Only
  without Ctrl, Meta or Alt** (`_hasModifier`, `placement_tool.dart:214-217`):
  Cmd/Ctrl+R (a browser reload) and Ctrl+M pass through untouched. **One step
  per key-down**; a key repeat is consumed with no effect. While a
  press is down every other key is swallowed except F and F3, which bubble
  (the drawing tools' rule, `placement_tool.dart:196-215`); armed and not
  pressed, every key except R and M returns `ignored`, so the shell's
  letters, undo and `Esc` work. `Esc` (not pressed) reaches the shell's
  `_escape`, which activates Select. **R and M are consumed while armed**
  (decision 4); that is D8's documented cost.
- **The ghost** (`symbol_ghost.dart`): `ghostPath(SymbolEntry)` builds a
  `ui.Path` **in the symbol's local frame** from the entry's leaves (arc
  payload: coords `[cx, cy]`, scalars `[r, start, sweep]`): a line a segment,
  an open or closed polyline (`isClosedPolyline`) its segments, a circle
  `addOval`, an arc `addArc` with the world start and sweep unchanged (F-14).
  It is built once per entry and cached. `paintWorldOverlay(canvas, origin,
  scale)` does `canvas.save()`, `canvas.transform(_m)`, where `_m` is the
  tool's reused `Float64List(16)` holding `translate(−origin) ∘
  placementTransform(at, basePoint, turns, mirrored)` **composed in doubles**
  (F-14's technique), draws the cached path at `kPreviewColor` with stroke
  `kPreviewStrokePixels / scale` (the placement is rigid, so the stroke stays
  that wide), then **a cross at `basePoint` in local coordinates** (which
  `_m` maps to `at − origin`), half-size `k / scale`, and `restore()`. **No
  `Path`, `Transform2` or matrix is allocated per paint:** `P =
  placementTransform(...)` is computed only when `at`, the turns or the mirror
  change, and stored with its linear part already written into `_m` (`_m`
  starts as the identity: `[0]`, `[5]`, `[10]`, `[15]` = 1); a paint writes
  only `_m[12] = P.e − origin.x` and `_m[13] = P.f − origin.y`. The snap marker
  is screen-space and is drawn in `paintOverlay` (`drawSnapMarker`, as
  `placement_tool.dart:280-290`). The ghost hides on pointer exit and on
  `cancel` (as `PlacementTool`'s hover state does).
- **The tool listens to `armed`**: tapping another cell while the tool is
  already active hits `ToolController.activate`'s early return
  (`tool.dart:120`), so the tool itself resets its press, rebuilds nothing
  but its cached path lookup, and notifies so the overlay repaints. It
  removes that listener in its `dispose`. It is an overlay: nothing is added to the document and
  `DraftPainter`'s frame path is untouched (the allocation invariant tests
  stay unedited and green).
- **Commit:** the tool checks `needs = {structure, geometry, components}`
  against `ctx.document.commands.permissions` **before** it calls `placeSymbol`
  (Ruling 05-3: a refused placement allocates no handle), then
  `ctx.execute(command)`. One placement is one undo step (09a).
- **`isMidShape`** is true while a press is down (F-2 of 12a): the shell's
  commands are disabled mid-press; the tool notifies on every change.
- **Why `Tool`, not `PlacementTool`** (click by click): this one places on
  release; the name is taken (09 spec D11).

### D7 — The Symbols tab (`symbol_panel.dart`)

- A column: the **search field** (key `symbol-search`; a hint "Search
  symbols"; a clear button while non-empty), then the gallery filling the rest.
- **The field's focus follows the page panel's pattern** (F-4): a
  `PanelFieldFocusNode` (so `_settlePendingInput` hands focus back), the
  field wrapped in `ShellShortcutGuard` (typing `r` or `w` never fires a
  tool), Enter and tap-outside call `handBack()`, and **`Esc` hands focus
  back too**: because the guard turns Escape into
  `DoNothingAndStopPropagationTextIntent` (F-4), the field handles it
  itself with a `CallbackShortcuts(Escape)` inside the guard that calls
  `handBack()`, the text entry's own pattern (F-13).
- **While loading** the tab shows a progress indicator and "Loading
  symbols…"; **on failure** the error's message and a Retry button (key
  `symbol-retry`) calling `retry()`; **ready** shows the field and gallery.
- The gallery's `selectedId` is the armed entry's id (`"$key@$version"`, D4)
  while the placement tool
  is the active tool and null otherwise (the panel listens to the
  `ToolController`); `enabled` is `permissions.allows` for all three
  capabilities of D6.

### D8 — The panel, the tabs and the wiring (`main.dart`)

- `chrome-left` keeps its 240 px and gains a tab strip: **Tools** (key
  `tab-tools`, the default) and **Symbols** (key `tab-symbols`), a
  `SegmentedButton`-style control inside the panel (not a `TabBar`, so no
  `DefaultTabController`), **wrapped in `ExcludeFocus`** (its segments are
  focusable buttons; Ruling 05-6); the active tab is shell state, not
  persisted. The tab strip is rendered only when `symbols != null` (D2).
- A cell tap sets `armed.value = entry` and calls `_activate(_symbolTool)`
  (F-2: it refuses while geometry is denied and clears the selection; the
  shell's own refusal, not the tool's, is the first gate). Switching tabs
  changes no tool. Choosing any other tool (palette, letter) leaves `armed` as
  it is; the highlight follows the active tool, not `armed`.
- `_symbolTool` is owned and disposed by the shell (it is outside `_entries`:
  its own `dispose`). A tool never calls the 12a settle: pending input in a
  panel field is settled by the canvas press's focus change, as for every
  tool.
- A document swap rebuilds the shell, so the tool and `armed` start fresh
  (the armed symbol does not survive a swap; plan verifies).

### D9 — Keys, focus and shortcuts, summarised

`kShellLetterKeys` is unchanged (R and M are shell letters already; the tool
consumes them through `onKey`, which runs before the shell's shortcuts: the
plan proves the order by a test that presses `R` armed and sees a quarter turn
and not the Rectangle tool). The search field's guard is the existing
`ShellShortcutGuard`. No new shell letter.

### D10 — Known limits

- R and M are consumed while the placement tool is armed (decision 4).
- The ghost draws the symbol's leaves with no style (one preview colour), not
  the instance's resolved style.
- Touch has no hover: the ghost appears on press.
- Thumbnails are generated lazily per cell on first build; a very fast scroll
  of 27 symbols is the worst case and is **not measured** in 09b (no test, no
  exit-gate item); the human's look covers it.
- The app has one (light) theme (F-9).
- A found definition is reused even if its leaves were edited (the 09 spec's
  D14); the tool inherits it.

### D11 — Changes to the 09 spec

D9 (the gallery takes the **filtered** categories and holds no text field;
the app owns the field), D11 (the ghost draws real lines, so R-4 is
reversed; R and M, `Esc`, snap and permissions as written there), D12 (tabs,
not a stacked list) and the 09 spec's "light and dark" look item (the app
has no dark theme) are superseded here. The 09 spec gets an
"Amended at execution (Plan 09b)" note at execution, rewriting nothing.

## Architecture

### Files

| File | Change |
|---|---|
| `packages/jet_cad_2d_flutter/lib/src/symbol_gallery.dart`, `symbol_thumbnails.dart` (new), `jet_cad_2d_flutter.dart` | D4, D5 |
| `apps/floor_planner/lib/symbols/{symbol_search,symbol_library_state,symbol_library_loader,symbol_place_tool,symbol_ghost,symbol_panel}.dart` (new) | D2, D3, D6, D7 |
| `apps/floor_planner/lib/main.dart` | D2 (the loader and the thumbnail cache in `FloorPlannerApp`), D8 (tabs, tool, wiring) |
| `apps/floor_planner/lib/document_host.dart` | passes `symbols` to the shell |
| `apps/floor_planner/test/**` (new) | below |
| `docs/superpowers/specs/2026-09-30-symbol-library-design.md` | an amendment note at execution |

### Invariants

- Frame path untouched; the two allocation invariant tests unedited and green.
- Draw order, `Tolerance` and `==` rules as 09a: the ghost is not geometry.
- A refused placement allocates no handle; a placement is one undo step; the
  tool leaves no state in the document.
- A bare `PlannerShell()` behaves exactly as today.

## Testing

Every fixture avoids the degenerate cases: a symbol whose `basePoint` is off
the origin, a rotated and mirrored ghost and placement, a pointer far from the
origin, a camera at a non-unit scale. A test is owed a named mutant.

- **Search (D3):** name, tag and category each alone; two terms both required;
  case; empty; order preserved; empty group hidden.
- **Library state (D2):** loading → ready; a missing asset, a corrupt asset
  and a `SymbolLibraryError` → failed; `retry()` after a failure reaches ready;
  a bare shell has no tabs.
- **Thumbnails (D5),** pixel tests under `tester.runAsync` (F-15): two symbols
  give different pixels; the image is `round(w·dpr) × round(h·dpr)`; the same key twice
  paints once; a version change, a pixel size, a DPR and a foreground change
  each give a new image; eviction disposes (a fake count); the foreground makes
  a BYBLOCK leaf dark on a light cell (read a pixel); a failed paint does not
  throw.
- **Gallery (D4):** a category collapses and expands; a tap calls `onSelect`
  with the id; `enabled: false` ignores taps; the selected cell is highlighted;
  a cell takes no focus (the canvas keeps it).
- **Ghost (D6):** the composed matrix maps the base point to `at − origin`
  and the local +x to the independently computed direction for a rotated,
  mirrored placement far from the origin (doubles, exact quarter turns); the
  local path's bounds equal the leaves' local bounds within a float32-scale
  tolerance (`Path.getBounds` is float32 and may return an arc's control
  points: arcs are checked through `PathMetric` endpoints); the path is cached
  (identity) and no `Path` is built per paint.
- **Tool (D6):** release places at the snapped release point, not the press;
  a press-drag-release with no hover (touch) places; `R`, `Shift+R`, `M` change
  the placed transform (read the instance's transform); `Esc` mid-press then
  the release places nothing (the release is sent); pointer cancel places
  nothing; Cmd+R and Ctrl+M are not consumed; a key repeat changes nothing;
  a snap fixture whose snapped point differs from the raw one places at the
  snapped point, at a non-unit camera scale; the ghost hides on exit;
  tapping a second cell while armed re-arms (the overlay repaints); `isMidShape` is true between press
  and release; stays armed; one undo per placement; a denied `components` (and
  `structure`, `geometry`) leaves the `handleSeed` unchanged and throws
  nothing (F-16: "nothing placed" alone is no signal); a second placement reuses the definition.
- **Panel and shell (D7, D8, D9):** the tabs appear only with `symbols`;
  tapping a cell arms the tool, clears the selection and activates it through
  `_activate`; the gallery is disabled when any of the three capabilities is
  denied; typing `r`/`w`/`m` in the
  search field fires no tool and filters; Enter, tap-outside and `Esc` hand
  focus back to the canvas; with the tool armed, `R` rotates and `W` still
  chooses Wall; `Esc` returns to Select and clears the highlight; Retry works;
  the tab choice changes no tool.
- **End to end:** the shell with the real asset: open the Symbols tab, search
  "bed", tap the double bed, press at a point far from the origin, press `R`,
  release: the instance exists at the snapped point with a quarter turn; save
  → load byte-identical.

## Named mutants

| Id | Mutation | Red test |
|---|---|---|
| M-09k | thumbnail key ignores the version | version change repaints |
| M-09x | thumbnail key ignores pixel size, DPR or foreground (each) | one case each |
| M-09y | thumbnail foreground not passed (white on light) | the pixel is dark |
| M-09z | evicted images not disposed | the dispose count |
| M-09l | search ignores tags | tag alone finds a symbol |
| M-09s | search `every` becomes `any`; search ignores the category | two terms; category alone |
| M-09m | `isMidShape` stays false during a press | mid-press commands disabled |
| M-09w | the tool skips `components` (or `structure`, `geometry`) in `needs` | the seed moves or the dispatcher throws (F-16) |
| M-09b1 | the tool places at the press point | release at a different point |
| M-09b2 | the tool allocates before the permission check | `handleSeed` unchanged on refusal |
| M-09b3 | `R` rotates the wrong way, `Shift+R` ignored, `M` does not mirror (each) | transform reads |
| M-09b4 | the ghost's matrix omits the placement transform (or the mirror) | the matrix maps the base point to `at − origin` and local +x to the rotated or mirrored direction |
| M-09b5 | `Esc` mid-press still places | nothing placed |
| M-09b6 | the cell tap does not go through `_activate` (selection kept) | selection cleared |
| M-09b7 | the search field has no `ShellShortcutGuard` | typing `r` does not choose Rectangle |
| M-09b8 | `Esc` in the field does not hand focus back | the canvas has focus |
| M-09b9 | the highlight stays after another tool is chosen | highlight clears |
| M-09b10 | a failed load shows no Retry (or Retry does nothing) | retry reaches ready |
| M-09b11 | the tab strip shows without `symbols` | a bare shell has no tabs |
| M-09b12 | the gallery cell takes focus | the canvas keeps focus |
| M-09b13 | the ghost path rebuilt every paint | cached identity |
| M-09b14 | the ghost ignores the rebase origin | the matrix maps the base point to `at − origin` (camera far from the origin) |
| M-09b15 | the image size ignores the DPR | image dimensions |
| M-09b16 | the tool places at the raw point (snap bypassed) | snapped ≠ raw fixture |
| M-09b17 | the aperture is not divided by the camera scale | non-unit scale fixture |
| M-09b18 | the ghost stays after pointer exit or cancel | ghost hidden |
| M-09b19 | the tool does not listen to `armed` | a second cell re-arms |
| M-09b20 | R/M consumed with Ctrl/Meta | Cmd+R passes through |
| M-09b21 | a key repeat rotates again | repeat changes nothing |
| M-09b22 | the gallery's `enabled` ignores `components` | denied `components` disables the cells |
| M-09b23 | a cell disposes the cache's image instead of its clone | the cache's image still usable after a cell disposes |

## Exit gate

- Engine, render layer, app: the standing gates green with `CI=true` (engine
  2 and render 7 + 1 skip standing failures unchanged, app all green);
  `flutter build web --release` builds; the two allocation invariant tests
  unedited and green; every named mutant fired red (the equivalent ones
  recorded), the reviewer re-fired.
- **The human's look (never marked done for them), macOS and web (Chrome,
  Firefox), light theme only:** the Symbols tab's look (the grid, the group
  headers, the thumbnails sharp on a Retina display); category collapse; the
  search box takes focus, typing fires no shortcut, `Enter`, a click outside
  and `Esc` return focus to the canvas; clicking a cell arms the tool and the
  cell highlights; the ghost follows the pointer, shows the symbol's lines in
  the right orientation, snaps; press-drag-release places (and on a touch
  screen or a simulated touch); `R`, `Shift+R`, `M`, `Esc`; two placements
  then undo twice and redo; switching to the Tools tab and back; saving and
  reopening a plan with symbols; a plan saved with an older symbol version
  opens and its symbols stay.

## Spec rulings

- **R-1 (D4):** the gallery holds no text field and no search state, over a
  gallery that owns the search: the field needs the app's `PanelFieldFocusNode`
  and the shell's guard, which the render layer cannot import (09 spec V-7).
- **R-2 (D5):** async `Picture.toImage` with a cached `Future`, over
  `toImageSync`: the latter is exercised only inside the private tile cache and
  its web support is unverified. Cost if wrong: a cell shows blank for a frame.
- **R-3 (D6):** the ghost draws the symbol's leaves through a cached `ui.Path`
  in an overlay, over a bounds box: orientation and mirror must be visible
  (the human's decision 3). Cost if wrong: one more file; no document path
  changes.
- **R-4 (D2):** the loader sits above the document host, over the shell:
  the shell is rebuilt per document and must not reload the asset.
- **R-5 (D8):** a segmented control inside the panel under `ExcludeFocus`,
  over `TabBar`: no `DefaultTabController`, and the canvas keeps the focus.
- **R-6 (D9):** the tool consumes R and M through `onKey` and no new shell
  letter is added.

## Revision 2

Applies the independent review of revision 1 (W-1 to W-12), all inside the
human's decisions. It confirmed the key routing (F-12: the armed tool's
`onKey` runs before the shell's shortcuts) and the Escape precedent (F-13).
W-1 the ghost paints a cached local path under a reused double-composed
matrix with the rebase origin, the snap marker in `paintOverlay` (D6, F-14,
M-09b14); W-2 pixel tests under `runAsync`, the DPR and `pixelsPerPaperMm`
specified (D5, F-15, M-09b15); W-3 the thumbnail document is
`prepareDocument`, bounds from `extents`, the scratch index disposed, the
cache owned by the app, cells hold clones (D4, D5, M-09b23); W-4 a cancelled
press ignores its remaining moves and up (D6, F-6); W-5 R/M only without
modifiers, one step per key-down, R counter-clockwise (D6, M-09b20, M-09b21);
W-6 M-09w and M-09b6 re-signalled (F-16, M-09b22); W-7 float32 tolerance and
`PathMetric` for arcs; W-8 the tab strip under `ExcludeFocus` (D8, R-5); W-9
cell ids `key@version` (D4); W-10 the state type and the loader split, the
`read` seam, ownership (D1, D2); W-11 four mutants added (M-09b16 to
M-09b19); W-12 citations and wording (F-6, F-8, F-17, D6, D8, D10).

## Revision 3

Applies the spot check of revision 2 ("Ready with amendments", S-1 to S-5):
S-1 the highlight uses the `key@version` id (D7); S-2 the ghost's cross is
drawn at the local base point (D6); S-3 the placement matrix is computed on
change and a paint writes only the translation, `_m` starts as the identity
(D6); S-4 F-14's precedent reworded as the same technique; S-5 M-09b4
re-targeted to the matrix test. Also the `runAsync` citation corrected and
the tool's `armed` listener removed in `dispose`.
