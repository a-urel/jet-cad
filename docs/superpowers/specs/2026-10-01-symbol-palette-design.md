# The symbol palette (09b) — design

**Date:** 2026-10-01. **Status:** design, **revision 1**, awaiting its
independent review and the human's approval.
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
  `onPointerExit`, a cancel to `tool.cancel`. No code reads
  `PointerDeviceKind`: touch has no hover, so no ghost before the press.
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
  (`style_resolver.dart:28`). The shell does it at `main.dart:206-208`; a
  thumbnail must pass it explicitly.
- **F-9.** The app has **no dark theme** (`ThemeData(colorSchemeSeed: …)`
  only); the 09 spec's "light and dark" look item is void.
- **F-10.** The app has no use of `rootBundle`; the asset is declared and
  read with `File` in tests only. `FloorPlannerApp` is above the keyed
  `DocumentHost` shell (`document_host.dart:518-527`); the shell is rebuilt
  per document.
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
  `symbol_library_state.dart` (D2), `symbol_place_tool.dart` (Flutter, D6),
  `symbol_ghost.dart` (the ghost path, pure `dart:ui`, D6),
  `symbol_panel.dart` (the Symbols tab, D7); `main.dart` gains the tabs and
  the wiring (D8); `tool_palette.dart` is untouched.
- Pure files (`symbol_search.dart`, `symbol_library_state.dart`'s state
  type) import no Flutter.

### D2 — Loading the library

A `SymbolLibraryLoader extends ChangeNotifier`, created once by
`FloorPlannerApp` (above the document host), holding a
`SymbolLibraryState`: `loading`, `ready(SymbolLibrary)` or
`failed(Object error)`. `load()` reads `rootBundle.load('assets/library/
furniture.jetlib')` and runs `SymbolLibrary.decode`; `retry()` runs it again
after a failure. It starts loading in its constructor path
(`FloorPlannerApp.initState`), is injected as an optional constructor
argument (tests pass a ready one or a fake), and is passed down to
`PlannerShell` as an optional `symbols` parameter. **A bare
`PlannerShell()` (about ten test files pump one) has no `symbols`: no tabs,
the panel is exactly today's.** `SymbolLibraryError`, a missing asset and any
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
(a value), thumbnailDocument (a builder returning a DraftDocument), bounds
(Aabb2)}`. It holds **no text field and no search state**: the app filters
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

### D5 — Thumbnails

`SymbolThumbnails({maxEntries = 64})`: `Future<ui.Image> imageFor(
{key, document, bounds, pixelSize, devicePixelRatio, foreground})`.

- Painted through `DraftPainter` (`DraftPainter(document, SpatialIndex,
  DocumentStyleResolver(document, foreground))`, a `VerticesDrawSink`,
  `flush`) into a `PictureRecorder`, then `Picture.toImage` (async, the
  portable call on web; F-7). The camera is `ViewportTransform.fit(bounds
  padded by 8%, pixelSize)`. **No second render path.**
- The document is the **placer's own output**: the app's builder
  (`thumbnailDocument`) makes an empty document and executes `placeSymbol`
  at `at = basePoint`, no turn, not mirrored (an identity transform), so a
  thumbnail is what a placement makes.
- **The foreground is passed explicitly** (`foregroundFor(cellColor
  .toARGB32())`, F-8), so BYBLOCK leaves are dark on the light cell.
- An in-memory LRU of 64, keyed by `(thumbnailKey, pixelSize,
  devicePixelRatio, foreground)`; the cache stores the `Future` (a repeated
  build never repaints, a pending one is shared); evicted and disposed
  entries call `Image.dispose()` once their future has completed; `dispose()`
  of the cache disposes all. Nothing persists. A key change invalidates; no
  other trigger exists, because the library is immutable in a session.
- A failed paint shows an empty cell with the label (never throws into the
  tree).

### D6 — The placement tool

`SymbolPlaceTool(ValueNotifier<SymbolEntry?> armed) extends Tool`, owned by
the shell like the opening tools (F-2); `armed.value == null` means idle and
the tool is inert (every pointer event ignored, the cursor deferred).

- **Pointer:** a hover (mouse) moves the ghost; a press starts a placement
  and shows the ghost at the press (touch has no hover, F-6); a move while
  pressed follows; **release places at the release point**. Pointer cancel and
  `Esc` mid-press cancel the press and place nothing. A secondary button does
  nothing. After a placement the tool stays armed with the same rotation and
  mirror; the placed instance is not selected.
- **Snap:** `resolveDragPoint` with the tool's own `SnapResult`/`DragPoint`
  scratch (F-5): object snap per F3 at `kSnapAperturePixels / scale`, else
  grid snap, else the raw point. The snapped point is `at`.
- **Keys:** `R` rotates one quarter turn, `Shift+R` the other way, `M`
  mirrors; they work idle-armed and mid-press (the ghost updates). While a
  press is down every other key is swallowed except F and F3, which bubble
  (the drawing tools' rule, `placement_tool.dart:196-215`); armed and not
  pressed, every key except R and M returns `ignored`, so the shell's
  letters, undo and `Esc` work. `Esc` (not pressed) reaches the shell's
  `_escape`, which activates Select. **R and M are consumed while armed**
  (decision 4); that is D8's documented cost.
- **The ghost** (`symbol_ghost.dart`): `ghostPath(SymbolEntry, Transform2)`
  builds a `ui.Path` from the entry's leaves: a line a segment, an open or
  closed polyline (`isClosedPolyline`) its segments, a circle `addOval`, an
  arc `addArc` with the entry's start and sweep **in the symbol's local
  frame**, then `Path.transform` by `placementTransform(at, basePoint,
  turns, mirrored)` as a `Matrix4` (a mirrored arc is correct under a
  reflection, F-6 of the 09 spec). The base path per entry is built once and
  cached; `paintWorldOverlay` draws it at `kPreviewColor`, stroke
  `kPreviewStrokePixels / scale`, plus the snap marker (`drawSnapMarker`) and
  a cross at `at`. It is an overlay: nothing is added to the document and
  `DraftPainter`'s frame path is untouched (the allocation invariant tests
  stay unedited and green).
- **Commit:** the tool checks `needs = {structure, geometry, components}`
  against `ctx.document.permissions` **before** it calls `placeSymbol`
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
  itself with an `Actions`/`Shortcuts` entry inside the guard that calls
  `handBack()`.
- **While loading** the tab shows a progress indicator and "Loading
  symbols…"; **on failure** the error's message and a Retry button (key
  `symbol-retry`) calling `retry()`; **ready** shows the field and gallery.
- The gallery's `selectedId` is the armed entry's key while the placement tool
  is the active tool and null otherwise (the panel listens to the
  `ToolController`); `enabled` is `permissions.allows` for all three
  capabilities of D6.

### D8 — The panel, the tabs and the wiring (`main.dart`)

- `chrome-left` keeps its 240 px and gains a tab strip: **Tools** (key
  `tab-tools`, the default) and **Symbols** (key `tab-symbols`), a
  `SegmentedButton`-style control inside the panel (not a `TabBar`, so no
  `DefaultTabController` and no focus node); the active tab is shell state,
  not persisted. The tab strip is rendered only when `symbols != null` (D2).
- A cell tap sets `armed.value = entry` and calls `_activate(_symbolTool)`
  (F-2: it refuses while geometry is denied and clears the selection; the
  shell's own refusal, not the tool's, is the first gate). Switching tabs
  changes no tool. Choosing any other tool (palette, letter) leaves `armed` as
  it is; the highlight follows the active tool, not `armed`.
- `_symbolTool` is owned and disposed by the shell (it is outside `_entries`:
  its own `dispose`). The 12a settle (`_settlePendingInput`) runs before any
  flow as for every tool.
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
  of 27 symbols is the worst case and is not measured (the plan measures one
  frame of the first build).
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
| `apps/floor_planner/lib/symbols/{symbol_search,symbol_library_state,symbol_place_tool,symbol_ghost,symbol_panel}.dart` (new) | D2, D3, D6, D7 |
| `apps/floor_planner/lib/main.dart` | D2 (the loader in `FloorPlannerApp`), D8 (tabs, tool, wiring) |
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
- **Thumbnails (D5):** two symbols give different pixels; the same key twice
  paints once; a version change, a pixel size, a DPR and a foreground change
  each give a new image; eviction disposes (a fake count); the foreground makes
  a BYBLOCK leaf dark on a light cell (read a pixel); a failed paint does not
  throw.
- **Gallery (D4):** a category collapses and expands; a tap calls `onSelect`
  with the id; `enabled: false` ignores taps; the selected cell is highlighted;
  a cell takes no focus (the canvas keeps it).
- **Ghost (D6):** `ghostPath` bounds equal the independently computed
  transformed bounds for a rotated, mirrored, off-origin placement; a mirrored
  arc's bounds are correct; the path is cached (identity).
- **Tool (D6):** release places at the snapped release point, not the press;
  a press-drag-release with no hover (touch) places; `R`, `Shift+R`, `M` change
  the placed transform (read the instance's transform); `Esc` mid-press places
  nothing; pointer cancel places nothing; `isMidShape` is true between press
  and release; stays armed; one undo per placement; a denied `components` (and
  `structure`, `geometry`) places nothing and allocates no handle
  (`handleSeed` unchanged); a second placement reuses the definition.
- **Panel and shell (D7, D8, D9):** the tabs appear only with `symbols`;
  tapping a cell arms the tool, clears the selection and activates it through
  `_activate` (refused while geometry is denied); typing `r`/`w`/`m` in the
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
| M-09w | the tool skips `components` (or `structure`, `geometry`) in `needs` | a denied capability places nothing |
| M-09b1 | the tool places at the press point | release at a different point |
| M-09b2 | the tool allocates before the permission check | `handleSeed` unchanged on refusal |
| M-09b3 | `R` rotates the wrong way, `Shift+R` ignored, `M` does not mirror (each) | transform reads |
| M-09b4 | the ghost path omits the placement transform (or the mirror) | ghost bounds |
| M-09b5 | `Esc` mid-press still places | nothing placed |
| M-09b6 | the cell tap does not go through `_activate` (selection kept) | selection cleared, geometry-denied refusal |
| M-09b7 | the search field has no `ShellShortcutGuard` | typing `r` does not choose Rectangle |
| M-09b8 | `Esc` in the field does not hand focus back | the canvas has focus |
| M-09b9 | the highlight stays after another tool is chosen | highlight clears |
| M-09b10 | a failed load shows no Retry (or Retry does nothing) | retry reaches ready |
| M-09b11 | the tab strip shows without `symbols` | a bare shell has no tabs |
| M-09b12 | the gallery cell takes focus | the canvas keeps focus |
| M-09b13 | the ghost path rebuilt every paint | cached identity |

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
- **R-5 (D8):** a segmented control inside the panel, over `TabBar`: no
  `DefaultTabController`, no extra focus node.
- **R-6 (D9):** the tool consumes R and M through `onKey` and no new shell
  letter is added.
