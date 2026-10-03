# Restaurant embedding (14) — design

**Date:** 2026-10-03. **Status:** design, **revision 1**, not yet reviewed,
**not approved**. Nothing below may be planned or implemented until the
human approves a revision.
**Sub-project:** new, `14` — the first consumer of the floor planner: a
restaurant (point-of-sale) application written in Flutter that embeds the
planner in two modes, **design** and **selection**.
**Size:** L, three slices, three plans (14a, 14b, 14c), proposed below.
**Branch:** `claude/exciting-pasteur-9m22jv`, cut from `main` at `4d6b78f`.
**Depends on:** 09 (symbols: the tables are placed instances), 12a (the
session, the save point), 12b (layers, `DraftPermissions` presets).

**Inputs read:** `CLAUDE.md`; `STATUS.md` (head); `roadmap/00-README.md`;
`roadmap/12-app-shell.md`;
`docs/superpowers/specs/2026-07-27-jet-cad-2d-architecture-design.md`
(the designer/viewer split, lines 9-12, and the runtime permissions,
lines 902-910); `packages/jet_cad_2d/lib/src/document/{command,node}.dart`;
`lib/src/index/{query_filter,spatial_index}.dart`;
`packages/jet_cad_2d_flutter/lib/src/{selection,select_tool,
selection_overlay,draft_canvas,tool}.dart`;
`apps/floor_planner/pubspec.yaml`, `lib/{main,document_host}.dart`,
`lib/symbols/{symbol_component,symbol_placer,symbol_library_loader,
furniture_catalog}.dart`, `lib/export/export_font.dart`.

## Why now

The human, 2026-10-03: *"Bu projenin ilk kullanımı bir restoran yazılımı
içinde olacak. Tasarım ve seçim için iki ayrı mod olmalı. Restoran yazılımı
içinde kullanmak için yapmamız gereken neler kaldı? Onları tamamlamamız
gerek ilk olarak."* — the first use is inside a restaurant application,
with separate design and selection modes; what is missing for that comes
first, before the remaining 12 slices, DXF, or the found items.

This is not a new direction. The engine's founding spec names exactly two
consumers: a WYSIWYG **designer** and *"a lightweight **viewer** for runtime
use (a point-of-sale app showing a restaurant floor plan, selecting a
table, acting on it)"*; `DraftPermissions.runtime` (`command.dart:56`) was
written for it. What exists today is the designer only, and only as an
application.

## Decisions the human made on 2026-10-03

1. **The host is a Flutter application.** The planner is embedded as a Dart
   package dependency — no iframe, no web view, no JS bridge.
2. **The selection mode lets staff:** select **one** table, select
   **several** tables, see each table's **status as a colour** supplied by
   the host, and **move** tables.
3. **A table's number (its identity) is assigned in the design mode**, by
   whoever draws the plan; the point-of-sale application refers to tables
   by that identity.

## What exists, and what is missing

| Need | Today | Gap |
|---|---|---|
| Embed in another Flutter app | `apps/floor_planner` is an application: its own `main()`, `MaterialApp`, file dialogs, exit guard; assets loaded as `assets/...` from the root bundle (`symbol_library_loader.dart:14`, `export_font.dart:9`) | A **package** with a public widget API; the host owns storage; assets keyed `packages/<name>/...` |
| Two modes | One mode, the full editor; `DraftPermissions` reaches no UI except the layer controls (roadmap 12, open) | A **mode** switch: design (today's editor) and selection |
| Table identity | A table is an `InstanceNode` of a definition carrying a `SymbolComponent` (`dining.table.*`); the instance has no number, no seat count | A per-instance **table component** (number, seats), edited in design mode, shown on the plan, unique per plan |
| Select only tables | `SelectTool._pick` picks the topmost pickable thing (`select_tool.dart:107`) — walls, rooms, dimensions alike | A pick that **only** resolves table instances, and never loses a table under a wall line |
| Status colours | An instance can carry its own colour (`node.dart:157`), but that is document state: undoable, dirtying, saved | A **non-document** status layer: host-driven, never undone, never saved, never dirties |
| Move tables at runtime | `DraftPermissions.runtime` exists; the shell ignores permissions | Selection mode runs under `runtime`; moves are commands; the host is told the layout changed |
| Touch | Camera gestures exist (`CameraGestureDetector`) | Tap to select, drag to move, pinch/pan, fit to view, hit targets sized for a finger |

## Proposed slices

Each slice is its own plan, executed and merged before the next is
planned. **14a → 14b → 14c**; 14b can start on a stub of 14a's component if
the human wants them in parallel (not proposed).

### 14a — Table identity (design mode)

- **D1. `TableComponent`** on a table **instance's** handle (not the
  definition's: the definition is shared by every table of that shape):
  `number` (a non-empty string, trimmed; `"12"`, `"B4"`, `"Teras-3"`),
  `seats` (an int ≥ 1, defaulting from the symbol's definition, e.g. 4 for
  `dining.table.square.four`). Immutable, value-equal, fixed-key `toJson`,
  registered like `SymbolComponent`. **Not** parametric: it generates
  nothing (see D3).
- **D2. Which instances are tables:** an instance whose definition's
  `SymbolComponent.tags` contains `table` (the furniture catalog already tags
  every dining table so; `furniture_catalog.dart:182-226`). Placing one gives
  it the next free number (`max numeric number + 1`, `"1"` on an empty plan)
  inside the placement's `CompoundCommand` — one undo step, as today.
  **Open (Q1):** a chair placed alone is not a table; a user-drawn
  rectangle cannot become a table in v1.
- **D3. The number is drawn** on the plan, centred on the table, as text the
  painter already knows how to draw. **Open (Q2):** an ATTRIB entity owned by
  the instance (`node.dart:148-151`: the DXF-faithful route; draws, plots and
  exports today) versus an overlay text drawn by the shell (never in the
  file, never in a PDF). Proposed: **ATTRIB**, so the number is on the
  printed plan too; kept in step with `TableComponent.number` by the same
  command that edits it.
- **D4. Editing:** the Selection section shows a **Table** group for a single
  selected table: Number and Seats fields, each commit one command, one undo
  step (roadmap 12's M-12c). A number already used by another table is
  **refused** at the field (the field shows why), never silently renamed.
- **D5. Uniqueness is checked again on load** and on paste/duplicate: a
  duplicate number (a hand-edited file, a copy) is reported as a
  diagnostic, and selection mode reports both tables under that number
  (the host decides); nothing renumbers on its own.
- **D6. Schema:** a new component type is additive; the codec already
  preserves unknown components (`component.dart:66`). **Open (Q3):** whether
  this needs a schema bump (12b's rule was: bump when an older build would
  misread, not merely ignore).

### 14b — The embeddable package and the two modes

- **D7. A new package, `packages/jet_cad_floor_plan`**, holding what is
  today `apps/floor_planner/lib/` minus the application frame (`main()`,
  `FloorPlannerApp`, the exit guard, the file dialogs). `apps/floor_planner`
  becomes a thin application over it, behaviour unchanged, its tests moved
  with the code they test. Assets move to the package and are loaded as
  `packages/jet_cad_floor_plan/...` (a host app's root bundle has no
  `assets/library/furniture.jetlib`).
- **D8. The public API is small and is the package's only barrel export:**
  - `FloorPlanController` — owns one document: `load(String json)`,
    `String save()`, `bool get dirty`, `markSaved()`, `undo()/redo()`,
    `mode` (a `ValueNotifier<FloorPlanMode>`), `selectedTables`
    (`ValueListenable<Set<String>>`, by table number), `select(Set<String>)`,
    `setTableStatus(Map<String, TableStatus>)`, `fitToView()`,
    `List<TableInfo> get tables` (number, seats, shape key).
  - `FloorPlanView({controller, onTableTap, onSelectionChanged,
    onLayoutChanged})` — one widget for both modes, so switching mode keeps
    the camera and never reloads the document.
  - `enum FloorPlanMode { design, selection }`.
  - `TableStatus` — a colour and an optional short caption (D13).
  Everything else stays `src/` and private. The API is the contract the
  restaurant application codes against; widening it later is cheap,
  narrowing it is not.
- **D9. Storage is the host's.** The package never opens a file dialog in
  either mode: `load`/`save` move a string; the host keeps it (its database,
  its server). File menu items (New/Open/Save) do not appear when embedded;
  Export… and Print… stay in design mode (they hand bytes to the host
  through a callback, or to `printing` as today — **Open (Q4)**).
- **D10. Design mode** is today's editor inside the host's layout: tool
  palette, symbol palette, Selection, Page and Layers sections, Undo/Redo,
  under `DraftPermissions.all`.
- **D11. Selection mode** shows the canvas only — no palettes, no panels, no
  grips except the move drag (D14), no rulers. Commands run under
  `DraftPermissions.runtime`; **the UI does not rely on the dispatcher
  refusing** (roadmap 12's M-12a): no affordance that would need
  `geometry` or `structure` exists in this mode.
- **D12. Switching mode** clears the selection, cancels any tool part-way,
  and keeps the camera and the undo history. **Open (Q5):** may selection
  mode undo a design edit (one shared history) — proposed: **no**; entering
  selection mode is a history barrier, and selection mode's own undo only
  reaches its own moves.

### 14c — Selection mode behaviour

- **D13. Status colours are not document state.** `setTableStatus` stores a
  `Map<String, TableStatus>` in the controller; a new overlay painter fills
  each listed table's outline in its status colour (under the drawing's
  lines, so the table stays legible) and draws the caption under the number.
  It never issues a command: no undo step, no dirty flag, not saved, not
  exported. A number in the map with no table is ignored (the host may be
  ahead of the plan); a table missing from the map draws plain. Repaint is
  driven by the controller's notifier and must be proven to reach the frame
  (roadmap 12 trap: `shouldRepaint` is false on the drawing's painter; the
  status layer is its own `CustomPaint`, like `SelectionOverlayPainter`).
  The fill paths come from the existing `OutlineCache` shape, built at
  status-change rate, never per frame: **the frame path stays
  allocation-free** (the two invariant tests stay green and untouched).
- **D14. Picking tables only.** A tap resolves to the **topmost table
  instance** under the finger within the pick radius, ignoring everything
  else — a wall line or a room label over a table does not hide it. Proposed
  mechanism: `SpatialIndex.forEachInstanceInRect` over the pick rectangle,
  keeping instances that carry a `TableComponent`, then the existing narrow
  pick restricted to those candidates; ascending-handle draw order decides
  "topmost" (the repo's draw-order non-negotiable). **Open (Q6):** whether a
  tap inside a table's outline but between its lines counts (proposed: yes —
  a finger aims at the table's area, not its strokes; hit = inside the
  instance's outline polygon).
- **D15. Single and multiple selection.** A tap on a table selects it alone;
  a tap on empty floor clears. Multiple selection: **Open (Q7)** — proposed:
  the host chooses per call site with `FloorPlanView.multiSelect`
  (`false`: tap replaces; `true`: tap toggles), because "merge tables" and
  "open table" are different screens in a POS. A rubber band does not exist
  in selection mode.
- **D16. Moving tables.** Dragging a **selected** table moves the whole
  selection (it is the 03 move drag, snapping off), one undo step per drag,
  through a command `runtime` allows (`transform`). Rotation is **Open
  (Q8)**, proposed: not in v1. A drag that starts on an unselected table
  selects it first, then moves it alone. On release `onLayoutChanged`
  fires; the host decides whether to `save()` and persist it for every
  terminal. **Open (Q9):** whether moves in selection mode are meant to be
  permanent (the next shift sees them) or for this service only (the host
  reloads the designed plan) — the package supports both; the host's
  default is a product decision.
- **D17. Touch.** Pinch to zoom, two-finger pan, one-finger pan on empty
  floor (in selection mode one finger on empty floor pans; it does not
  draw a band). The pick radius in selection mode is a finger's (proposed
  8 mm on screen, against the mouse's few pixels). `fitToView()` frames the
  tables' extents with a margin.
- **D18. Callbacks carry table numbers, never handles.** Handles are an
  internal identity; the host stores numbers (decision 3).

## A demonstration host

**D19.** `apps/restaurant_demo`: a minimal Flutter app that depends on the
package, keeps the plan in memory, has a Design / Service toggle, a fake
order list that sets statuses (free, occupied, bill requested, reserved),
and prints the callbacks. It is the exit gate's integration surface and
the restaurant team's example to copy. It is not a product.

## Exit criteria sketch (per slice; each plan sharpens its own)

- 14a: placing a table numbers it; editing the number and seats is one undo
  step each; a duplicate is refused; the number draws, plots and exports;
  save → load round-trip is byte-identical.
- 14b: `apps/floor_planner` behaves as before (its tests green after the
  move, the furniture asset and the font load from the package);
  `apps/restaurant_demo` embeds the view; in selection mode no command
  needing `geometry` or `structure` reaches the dispatcher (asserted by a
  dispatcher spy, not by catching `PermissionDeniedError`).
- 14c: a tap on a table under a wall selects the table; statuses colour
  the right tables, change without a command, and leave `dirty` false;
  a move is one undo step and fires `onLayoutChanged` once; the allocation
  invariants are green.

## Named mutants to fire

- **M-14a:** number a new table `count + 1` instead of `max + 1` — a plan
  with tables 1 and 3 must not get a second 3.
- **M-14b:** put `TableComponent` on the definition instead of the instance —
  two tables of the same shape must keep different numbers.
- **M-14c:** let selection mode pick the topmost **anything** — the
  table-under-a-wall test must go red.
- **M-14d:** apply a status by setting `InstanceNode.color` — the `dirty`
  and undo-depth assertions must go red.
- **M-14e:** fire `onSelectionChanged` with handles, or with numbers from a
  stale document after `load` — the reload test must go red.
- **M-14f:** skip the history barrier of D12 — selection mode's Undo must
  not undo a wall.
- **M-14g:** a status fixture where every table is at the origin with the
  identity transform must not be the only fixture (the repo's degenerate-
  fixture rule): statuses are tested on rotated, mirrored, translated
  tables.

## Open questions for the human

- **Q1.** Can something other than a library dining table be a table
  (a bar stool, a user-drawn shape)? Proposed: library tables only in v1.
- **Q2.** Is the number printed on the PDF plan (ATTRIB), or only on screen?
- **Q3.** Schema bump for the new component? (A reviewer's call, recorded.)
- **Q4.** In the embedded design mode, do Export/Print stay, or does the
  host own all output?
- **Q5.** One undo history across both modes, or a barrier at the switch?
- **Q6.** Does a tap inside a table's area (between its lines) select it?
- **Q7.** How does staff select several tables on a touch screen — a mode
  the host turns on, or a long-press?
- **Q8.** Rotate tables in selection mode?
- **Q9.** Are selection-mode moves permanent or per service?
- **Q10.** Several dining areas (salon, garden, terrace): one plan per area
  (the host keeps several documents and shows tabs) — proposed — or several
  areas in one plan?
- **Q11.** Package name: `jet_cad_floor_plan` (proposed).

## Not in scope

DXF, the remaining 12 slices (menu bar, recent files, autosave), Plan G
(`residentGpu` on web: the product runs on the `vertices` sink), table
merging as a document concept (a POS-side grouping, not geometry),
reservations or any time-based state (the host's), multi-user live sync
between terminals (the host persists and reloads).
