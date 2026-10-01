# The symbol palette, slice 09b — implementation plan

> **For agentic workers:** executed task by task, subagent-driven: a fresh
> implementer per task and an independent reviewer per task, then a final
> whole-branch review. Steps use checkbox (`- [ ]`) syntax.

**Goal:** the left panel gains a **Symbols** tab (search box, collapsible
categories, a two-column grid of thumbnails painted by `DraftPainter`); a
click arms a placement tool whose ghost draws the symbol's real lines; press,
drag, release places at the release point, snapping; `R`, `Shift+R`, `M`,
`Esc`; one undo step per placement. The library is loaded once per app from
the bundled asset.

**Spec:** [docs/superpowers/specs/2026-10-01-symbol-palette-design.md](../specs/2026-10-01-symbol-palette-design.md),
**revision 3** (`121d944`). Read it whole before Task 1, and the 09 spec it
supersedes in part ([2026-09-30-symbol-library-design.md](../specs/2026-09-30-symbol-library-design.md),
D8–D12 and its "Amended at execution (Plan 09a)"). The 09b spec has 11
decisions (D1–D11), 6 rulings (R-1–R-6), 17 facts (F-1–F-17), 31 named
mutants (M-09k, M-09l, M-09m, M-09s, M-09w, M-09x, M-09y, M-09z, M-09b1 …
M-09b23) and no open question. It was reviewed independently twice (W-1–W-12,
S-1–S-5). **The human approved it on 2026-10-01** ("onaylıyorum, planı
yaz"). The human's decisions 1–4 are at its top.

**Architecture:**
- **Engine** (`packages/jet_cad_2d`): **untouched.**
- **Render layer** (`packages/jet_cad_2d_flutter`): `SymbolThumbnails` (Task 3)
  and `SymbolGallery` (Task 4), exported; frozen after Task 4.
- **App** (`apps/floor_planner`): `lib/symbols/symbol_search.dart` (Task 1),
  `symbol_library_state.dart` + `symbol_library_loader.dart` and the
  app/host wiring (Task 2), `symbol_ghost.dart` (Task 5),
  `symbol_place_tool.dart` (Tasks 6–7), `symbol_panel.dart` (Task 8),
  `main.dart` tabs and wiring (Task 9).

**Tech stack:** Dart, Flutter 3.47.2 at `/root/flutter` (installed in this
container by the 09a session; if it is missing, reinstall the same version
from `storage.googleapis.com/flutter_infra_release/releases/stable/linux/
flutter_linux_3.47.2-stable.tar.xz`). **No new dependency.**

## Rulings made here rather than left to an implementer

- **P-1 (branch).** `plan-09b/symbol-palette`, cut from
  `spec-09b/symbol-palette` at the commit that adds this plan; worktree
  `.claude/worktrees/plan-09b`. Reviews in a detached worktree
  (`.claude/worktrees/plan-09b-review`). Merge is the human's, `--no-ff`, from
  the main checkout. Reviewed commits are pushed to
  `origin/plan-09b/symbol-palette`. The proxy refuses remote branch deletion:
  name merged branches for the human.
- **P-2 (one shared test fixture).** `apps/floor_planner/test/support/
  symbol_fixtures.dart` (09a) is reused; a library loaded from the real asset
  by `File` in tests. The shell tests pump the host with an injected
  `SymbolLibraryLoader(read: …)` and `SymbolThumbnails`.
- **P-3 (fixtures, the testing bar).** Every fixture avoids the degenerate
  cases: a symbol whose `basePoint` is off the origin (every library symbol
  is), placements rotated **and** mirrored, a pointer and a camera **far
  from the origin** (so the rebase origin is not zero), a camera scale ≠ 1, a
  snap fixture whose snapped point differs from the raw one. A test is owed a
  named mutant that turns it red; the implementer fires it, the reviewer
  fires it again.
- **P-4 (async pixels).** Any test that reads image pixels runs under
  `tester.runAsync` (spec F-15).
- **P-5 (container restarts).** The container has restarted three times in
  09a. Every agent commits as soon as its gates are green, writes its report
  early and appends to it, and runs mutants in the foreground in small
  batches; a mutant's backup is restored by `cp` and checked by `diff`.

## Global constraints

- CLAUDE.md's non-negotiables. The frame path is untouched (the ghost is an
  overlay; thumbnails paint scratch documents off the frame path); the two
  allocation invariant tests stay **unedited** and green.
- `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
- Never `git checkout --` a `.dart` file; mutants by `cp` backup, mutate one
  line, run the named test file, `cp` back, `diff` exit 0.
- Never commit `analysis_options.yaml` (`flutter pub get` rewrites
  `packages/jet_cad/analysis_options.yaml`; stage files by explicit path).
- Never synthesize output. Code, comments, commit messages in English.
- Pure files stay pure: `symbol_search.dart` and `symbol_library_state.dart`
  import no Flutter; `rootBundle` only in `symbol_library_loader.dart`.
- Commit trailers:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01M4zdYkH7yTFAU2aCUA8bdQ
  ```
- Scratch prefix for each agent: a per-agent directory under
  `/tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/`,
  named in its brief.

## Gates (every task)

```sh
export PATH=/root/flutter/bin:$PATH
(cd packages/jet_cad_2d         && CI=true dart test ; CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd packages/jet_cad_2d_flutter && CI=true flutter test ; CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd apps/floor_planner          && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
```
Plus `CI=true flutter build web --release` in the app from Task 2 on.
Branch point (`main` `75dc2e0`): engine 1,121 + 2 standing
(`test/testing/generate_document_test.dart`); render 974 + 1 skip + 7
standing (text ladders); app 790. A task that touches only one package may
state the others unchanged rather than re-run them (say so in the report).

## File structure

| File | Task |
|---|---|
| `apps/floor_planner/lib/symbols/symbol_search.dart`, `test/symbols/symbol_search_test.dart` (new) | 1 |
| `apps/floor_planner/lib/symbols/symbol_library_state.dart`, `symbol_library_loader.dart` (new); `main.dart` (`FloorPlannerApp` owns the loader and the thumbnail cache), `document_host.dart` (passes `symbols`); `test/symbols/symbol_library_loader_test.dart` (new) | 2 |
| `packages/jet_cad_2d_flutter/lib/src/symbol_thumbnails.dart` (new), `lib/jet_cad_2d_flutter.dart`; `test/symbol_thumbnails_test.dart` (new) | 3 |
| `packages/jet_cad_2d_flutter/lib/src/symbol_gallery.dart` (new), `lib/jet_cad_2d_flutter.dart`; `test/symbol_gallery_test.dart` (new) | 4 |
| `apps/floor_planner/lib/symbols/symbol_ghost.dart`, `test/symbols/symbol_ghost_test.dart` (new) | 5 |
| `apps/floor_planner/lib/symbols/symbol_place_tool.dart`, `test/symbols/symbol_place_tool_test.dart` (new) | 6, 7 |
| `apps/floor_planner/lib/symbols/symbol_panel.dart`, `test/symbols/symbol_panel_test.dart` (new) | 8 |
| `apps/floor_planner/lib/main.dart`; `test/symbols/symbol_shell_test.dart` (new) | 9 |
| `apps/floor_planner/test/symbols/symbol_palette_end_to_end_test.dart` (new); `docs/superpowers/notes/2026-10-01-plan-09b-results.md` (new); spec amendments (09b and 09); `roadmap/09-symbol-library.md`, `roadmap/00-README.md`; the ledger archive | 10 |

---

### Task 1: App — search (spec D3)

- [ ] `List<({String category, List<SymbolEntry> symbols})> searchSymbols(
  List<SymbolEntry> entries, String query)` (pure): split on white space,
  lower-case; a symbol matches when **every** term is a substring of its name,
  any tag or its category (case-insensitive); an empty or blank query matches
  all; groups in the library's category order (first appearance), symbols in
  library order; empty groups omitted.
- [ ] Tests on the real asset (read by `File`, decoded by
  `SymbolLibrary.decode`) and on a two-symbol fixture: name alone, tag alone,
  category alone each find a symbol (choose terms that hit only one field);
  two terms both required (a term pair where each term alone matches but the
  pair matches fewer); upper case in the query; blank query; order preserved;
  an empty group hidden.
- [ ] Mutants: **M-09l** (tags ignored), **M-09s** (`every` → `any`; the
  category ignored). Record red test and real output.
- [ ] App gate; engine and render unchanged. Commit `feat(app): symbol search`.

### Task 2: App — the library loader and its wiring (spec D2, R-4)

- [ ] `symbol_library_state.dart` (pure): `sealed class SymbolLibraryState`
  with `SymbolLibraryLoading`, `SymbolLibraryReady(SymbolLibrary)`,
  `SymbolLibraryFailed(Object error)`.
- [ ] `symbol_library_loader.dart`: `SymbolLibraryLoader extends
  ChangeNotifier` with `({Future<Uint8List> Function()? read})` (default:
  `rootBundle.load('assets/library/furniture.jetlib')` → bytes), `state`,
  `load()`, `retry()` (only from failed), notifies on every state change; any
  throw (missing asset, corrupt bytes, `SymbolLibraryError`) → failed. A
  `load()` after dispose is a no-op.
- [ ] `FloorPlannerApp` takes optional `symbols` (a loader) and `thumbnails`
  (`SymbolThumbnails`, Task 3 — until Task 3 lands, the parameter is the
  loader only; Task 3 adds the cache parameter here); it creates defaults,
  calls `load()` in `initState`, disposes only what it created.
  `DocumentHost` passes `symbols` to `PlannerShell(symbols: …)`; the shell
  stores it and does nothing with it yet (Task 9 uses it). A bare
  `PlannerShell()` and a bare `FloorPlannerApp(files: …)` behave as today.
- [ ] Tests: ready from the real asset bytes; failed from a missing asset (the
  `read` throws), from corrupt bytes, from a library that the loader refuses
  (hand-built JSON from `symbol_fixtures.dart`); `retry()` after a failure with
  a `read` that then succeeds reaches ready; notifications counted; the
  default `read` loads the real asset through `rootBundle` in a
  `testWidgets` (the asset is declared, 09a) — if it cannot, record why and
  test the default through `DefaultAssetBundle`; the host passes `symbols` to
  the shell (find the shell's widget and read its field).
- [ ] Mutants: **M-09b10** (`retry` does nothing), a failure swallowed as
  loading, the host not passing `symbols`.
- [ ] Gates incl. `flutter build web --release`. Commit `feat(app): load the
  symbol library once per app`.

### Task 3: Render — thumbnails (spec D5, R-2)

- [ ] `SymbolThumbnails({int maxEntries = 64})`: `Future<ui.Image> imageFor(
  {required Object key, required DraftDocument Function() document,
  required Size logicalSize, required double devicePixelRatio, required int
  foreground})`, an LRU keyed by `(key, logicalSize, devicePixelRatio,
  foreground)` storing the `Future`; evicted and disposed entries call
  `image.dispose()` once completed; `dispose()`.
- [ ] Paint: build the document; `SpatialIndex(doc)`;
  `DraftPainter(document:, index:, resolver: DocumentStyleResolver(doc,
  foreground: foreground))`; a `PictureRecorder` canvas scaled by the DPR;
  `VerticesDrawSink(pixelsPerPaperMm: kLogicalPixelsPerMm, canvas:,
  devicePixelRatio:)`; `ViewportTransform.fit(doc.extents padded 8%,
  logicalSize)`; `paint`, `flush`, `endRecording`; `picture.toImage(round(w ·
  dpr), round(h · dpr))`; dispose the picture and the index. A throw completes
  the future with an error (the gallery shows an empty cell).
- [ ] Tests (pixels under `tester.runAsync`, P-4), on two small documents
  built in the test with leaves off the origin (render package: no app
  import): two documents give different pixels; image size is `round(w·dpr)
  × round(h·dpr)` at a DPR of 2; the same key twice paints once (count builder
  calls); a different key, logical size, DPR and foreground each paint anew;
  eviction past `maxEntries: 2` disposes the oldest (`debugDisposed` true);
  `dispose()` disposes all; a black foreground makes a BYBLOCK leaf's pixel
  dark on a light background (read the pixel at a leaf's projected point); a
  builder that throws completes with an error and does not throw
  synchronously.
- [ ] Mutants: **M-09k** (the key's object part ignored), **M-09x** (size,
  DPR, foreground each ignored), **M-09y** (foreground not passed to the
  resolver), **M-09z** (eviction does not dispose), **M-09b15** (image size
  ignores the DPR).
- [ ] Export; render gate; app unchanged (it does not use it yet). Commit
  `feat(render): symbol thumbnails`.

### Task 4: Render — the gallery widget (spec D4, R-1)

- [ ] `GalleryCategory`, `GallerySymbol{id, label, thumbnailKey,
  thumbnailDocument}`, `SymbolGallery({categories, selectedId, enabled,
  onSelect, thumbnails, foreground, cellColor})` per D4: a scrollable column,
  per category a header (`symbol-group-<name>`: name, count, chevron; tap
  toggles; collapsed set in widget state) and a two-column grid of cells
  (`symbol-cell-<id>`): thumbnail via `thumbnails.imageFor` (a
  `FutureBuilder`-like state that takes `image.clone()` and disposes its clone
  on dispose or change), label one line ellipsis, `Tooltip` with the full
  label, highlight when selected, `Material` + `InkWell`; disabled greys and
  ignores taps; the whole widget under `ExcludeFocus`.
- [ ] Tests (a fake `SymbolThumbnails` subclass or the real one with tiny
  documents): collapse and expand; tap calls `onSelect(id)`; disabled ignores;
  the selected cell is highlighted (read a decoration/colour or a semantic
  flag you add); a cell takes no focus (a focused `FocusNode` elsewhere keeps
  focus after a tap); a disposed cell disposes its clone and the cache's image
  stays usable; an image error shows the label and no exception.
- [ ] Mutants: **M-09b12** (cell takes focus: remove `ExcludeFocus`),
  **M-09b23** (a cell disposes the cache's image instead of its clone), the
  highlight ignoring `selectedId`, disabled taps still calling `onSelect`.
- [ ] Export; render gate. Commit `feat(render): the symbol gallery`.

### Task 5: App — the ghost (spec D6 "The ghost", F-14)

- [ ] `symbol_ghost.dart`: `ui.Path ghostPathFor(SymbolEntry)` (cached per
  entry in an `Expando` or a map owned by the caller) in the local frame:
  line, polyline (closed via `isClosedPolyline`), circle (`addOval`), arc
  (`addArc` with world start and sweep, scalars `[r, start, sweep]`).
  `void writeGhostMatrix(Float64List m, Transform2 p, Vector2 origin)`
  writes the linear part of `p` and `m[12] = p.e − origin.x`, `m[13] = p.f −
  origin.y` into an identity-initialised `m`; a `GhostMatrix` holder that
  computes `p` only when `at`, turns or mirror change.
- [ ] Tests (P-3: a real library entry with `basePoint` off the origin; at
  far from the origin; origin far from zero; quarter turns 0–3, mirrored and
  not): `m` maps the local base point to `at − origin` and local +x to the
  independently computed direction (doubles, exact for quarter turns); the
  local path's bounds equal the leaves' local bounds within a float32-scale
  tolerance; an arc's endpoints via `PathMetric` equal the arc's computed
  endpoints; the path is the same object on a second call; `p` is not
  recomputed when only the origin changes (count).
- [ ] Mutants: **M-09b4** (the matrix omits the placement transform; omits
  the mirror), **M-09b13** (path rebuilt per call), **M-09b14** (the origin not
  subtracted), an arc's sweep sign flipped.
- [ ] App gate. Commit `feat(app): the symbol ghost`.

### Task 6: App — the placement tool: pointer, snap, ghost (spec D6)

- [ ] `SymbolPlaceTool(ValueNotifier<SymbolEntry?> armed) extends Tool`;
  inert while `armed.value == null`. Hover moves the ghost; press shows it at
  the press; moves follow; **release places at the snapped release point**;
  pointer cancel cancels; a secondary button does nothing; the ghost hides on
  exit and on `cancel`; `isMidShape` true between press and release, notifying
  on change; it listens to `armed` (re-arm repaints, resets the press) and
  removes the listener in `dispose`. Snap: `resolveDragPoint` with its own
  `SnapResult`/`DragPoint`, aperture `kSnapAperturePixels / camera.scale`,
  grid from `dragGridStepMm`. `paintWorldOverlay` per D6 (Task 5's path and
  matrix, the cross at the local base point, half-size `k/scale`);
  `paintOverlay` draws the snap marker. Placing here calls the commit of
  Task 7 — for this task, a minimal commit (`ctx.execute(placeSymbol(…))`)
  is enough; Task 7 adds permissions and keys.
- [ ] Tests (a `ToolContext` over a real document from `prepareDocument`, a
  real `SpatialIndex`, a camera at scale ≠ 1 far from the origin; drive the
  tool's methods directly with `ToolPointerEvent`s): release places at the
  release point, not the press (M-09b1); touch path (press-move-release with
  no hover) places; a snap fixture (a line endpoint within the aperture of
  the raw release point but more than 10 world units away) places at the
  endpoint (M-09b16, M-09b17); `isMidShape` between press and release
  (M-09m); pointer cancel then up places nothing; exit hides the ghost
  (M-09b18); stays armed; one undo per placement; a second placement reuses
  the definition; re-arming notifies (M-09b19).
- [ ] App gate. Commit `feat(app): the symbol placement tool`.

### Task 7: App — the tool's keys and permissions (spec D6)

- [ ] `onKey`: `R` +1 quarter turn (counter-clockwise), `Shift+R` −1, `M`
  toggles the mirror, only with no Ctrl/Meta/Alt, one step per key-down
  (repeat consumed with no effect), armed idle and mid-press; mid-press `Esc`
  cancels the press and its remaining moves and up place nothing; mid-press
  every other key swallowed except F and F3; armed and not pressed, every key
  but R/M `ignored`.
- [ ] Commit path: check `{structure, geometry, components}` against
  `ctx.document.commands.permissions` **before** `placeSymbol`; a refusal
  allocates nothing and throws nothing.
- [ ] Tests: R, Shift+R, M change the placed instance's transform (read it,
  compare to `placementTransform` computed independently); `Esc` mid-press
  then the release places nothing (M-09b5); Cmd+R, Ctrl+R, Ctrl+M are
  `ignored` (M-09b20); a repeat changes nothing (M-09b21); F and F3 bubble
  mid-press; W is `ignored` armed idle; each denied capability leaves
  `handleSeed` unchanged and throws nothing (M-09w, M-09b2).
- [ ] Mutants: **M-09b3** (R wrong way; Shift+R ignored; M no mirror, each),
  **M-09b5**, **M-09b20**, **M-09b21**, **M-09w**, **M-09b2**.
- [ ] App gate. Commit `feat(app): the placement tool's keys and permissions`.

### Task 8: App — the Symbols tab (spec D7)

- [ ] `SymbolPanel({loader, thumbnails, tools: ToolController, tool:
  SymbolPlaceTool, armed, permissions, searchFocus: PanelFieldFocusNode,
  onSelect})`: loading (progress + "Loading symbols…"), failed (message +
  `symbol-retry`), ready (the field `symbol-search` with hint and clear
  button, then `SymbolGallery` over `searchSymbols(entries, query)` mapped to
  `GallerySymbol{id: "$key@$version", label: name, thumbnailKey: id,
  thumbnailDocument: () => placeSymbol into prepareDocument at basePoint}`).
  The field: `ShellShortcutGuard › CallbackShortcuts(Escape → handBack) ›
  TextField(focusNode: searchFocus, onEditingComplete: handBack,
  onTapOutside: handBack)`. `selectedId` is the armed id while the tool is
  active (listen to `tools`); `enabled` needs all three capabilities;
  `foreground: foregroundFor(cellColor)`; an empty result shows "No symbols
  match" with the query and a Clear button.
- [ ] Tests (pumped standalone inside a minimal host with a canvas `Focus`):
  typing `bed` filters; typing `r`, `w`, `m` fires no shortcut (a
  `CallbackShortcuts` ancestor counting R/W/M stays at zero) (M-09b7); Enter,
  tap-outside and Esc return focus to the canvas focus node (M-09b8); Retry
  reaches ready (M-09b10 again at the panel); the highlight follows the active
  tool (M-09b9); a denied `components` disables the cells (M-09b22); the
  thumbnail document is the placer's output (its single instance has the
  identity transform and the definition carries the component).
- [ ] App gate. Commit `feat(app): the Symbols tab`.

### Task 9: App — the shell's tabs and wiring (spec D8, D9, R-5)

- [ ] `PlannerShell(symbols: …, thumbnails: …)`: when `symbols != null`,
  `chrome-left` (240 px) gets an `ExcludeFocus`-wrapped segmented control
  (`tab-tools` default, `tab-symbols`), Tools = today's `ToolPalette`,
  Symbols = `SymbolPanel`; the active tab is shell state. The shell owns
  `_armed` and `_symbolTool` (disposed in the shell's `dispose`, outside
  `_entries`). A cell tap sets `_armed.value` and calls `_activate(
  _symbolTool)`. `FloorPlannerApp` passes the cache it owns.
- [ ] Tests (pump the host with injected loader and cache, P-2): a bare shell
  has no tabs (M-09b11); the tabs switch content and no tool; a cell tap arms
  the tool, clears an existing selection (M-09b6) and makes it the active tool;
  with the tool armed, `R` rotates the next placement and `W` chooses Wall;
  `Esc` returns to Select and the highlight clears; the tab strip and cells
  take no focus (the canvas keeps it); a document swap (New through the host)
  leaves no armed tool; the 12a mid-shape rule: during a press the toolbar's
  Save is disabled.
- [ ] Mutants: **M-09b6**, **M-09b9** (shell level), **M-09b11**, the tab
  strip without `ExcludeFocus`.
- [ ] Gates incl. web build. Commit `feat(app): the Symbols tab in the shell`.

### Task 10: End to end, sweep, results, the ledger (spec Exit gate)

- [ ] `symbol_palette_end_to_end_test.dart`: the host with the real asset
  (injected `read` from `File`), real cache: open Symbols, search "bed", tap
  `bed.double`, press far from the origin at a camera scale ≠ 1, press `R`,
  move, release: the instance exists at the snapped release point with one
  quarter turn; undo removes it; redo restores it; Save As (fake files) →
  Open → Save byte-identical.
- [ ] The P-8 rule of 09a applies: compile the mutant table from task reports
  and reviews; the final whole-branch review re-fires a sample across tasks.
- [ ] The two allocation invariant tests unedited (empty diff); no
  `analysis_options.yaml` in the diff; greps for purity.
- [ ] `docs/superpowers/notes/2026-10-01-plan-09b-results.md` (12a/09a form),
  with **the human's look list** copied from the spec's Exit gate (nothing
  marked done for them); "Amended at execution (Plan 09b)" sections closing
  the 09b spec and a short note in the 09 spec; roadmap status.
- [ ] The final whole-branch review (separate detached worktree), its fixes,
  then the ledger archive to `docs/superpowers/ledgers/2026-10-01-plan-09b/`
  with a README row, as the branch's last commit.
- [ ] Gates (all three + web). Commits `test(app): the symbol palette end to
  end`, `docs: plan 09b results`, `docs: archive the plan 09b ledger`.

## Exit gate (09b)

- Engine, render layer, app: standing gates green with `CI=true`; engine 2
  and render 7 + 1 skip standing failures unchanged; `flutter build web
  --release` builds; the two allocation invariant tests unedited and green.
- Every named mutant fired red (any equivalent one recorded by experiment),
  re-fired by the reviewer; the final review's sample on the tip.
- **The human's look on macOS and web (Chrome, Firefox), light theme**, per
  the spec's Exit gate; never marked done for the human.
- Merge on the human's word, `--no-ff`, from the main checkout; STATUS through
  a small docs branch merged `--no-ff`; `main` pushed; worktrees and local
  branches removed; merged remote branches named for the human.
