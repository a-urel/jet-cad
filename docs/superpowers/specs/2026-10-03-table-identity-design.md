# Table identity (14a) — design

**Date:** 2026-10-03. **Status:** design, **revision 2**: revision 1
(`fcf03ba`) reviewed independently, "Ready with fixes" (R-1 to R-13),
each applied ([Revision 2](#revision-2)). The human ruled on Q-1 to Q-4
and said to continue on this branch ("bu branch'te devam edebiliriz",
2026-10-03; [rulings](#the-humans-rulings-2026-10-03)); revision 2 changes
no product decision, only how they are built. **Sub-project:** 14 (restaurant embedding), slice **14a**.
**Umbrella:** [2026-10-03-restaurant-embedding-design.md](2026-10-03-restaurant-embedding-design.md)
(revision 3, approved), whose 14a decisions D1–D5 are this spec's input
and are **amended here** where marked (A-1, A-2), for the human to rule.
**Branch:** `claude/exciting-pasteur-9m22jv`; facts verified at `100696f`.
**Size:** M. **Packages touched:** `jet_cad_floor_plan` (most),
`jet_cad_2d_flutter` (the delete cascade and the pick mapping). The engine,
`jet_cad_2d`, is **untouched**.

**Inputs read:** the umbrella spec; `CLAUDE.md`; `STATUS.md` (head);
`packages/jet_cad_2d/lib/src/document/{undo,commands,layer_commands,
text_geometry,node,draft_document}.dart`, `index/{container_index,
spatial_index,convenience_queries}.dart`,
`parametric/parametric_system.dart`, `store/entity_store.dart`;
`packages/jet_cad_2d_flutter/lib/src/{selection,select_tool,grip_drag,
draft_painter}.dart`; `packages/jet_cad_floor_plan/lib/src/{planner_shell,
selection_panel}.dart`, `symbols/{symbol_placer,symbol_place_tool,
seating_component}.dart`, `layers/layer_picker.dart`,
`parametric/catalog.dart`.

## What it delivers

In the design mode, **every servable symbol placed becomes a numbered
table**: the next free number is given on placement, drawn upright at the
table's centre on the screen, in the PDF and on paper, and editable in a
**Table** section of the Selection panel. Deleting a table deletes its
number; clicking the number selects the table; rotating or mirroring a
table keeps its number readable. The number is what the restaurant
application (14b-2, 14c) will address a table by.

Not here: the host API (14b-2), the selection mode and status colours
(14c), touch (14t).

## Facts established (at `100696f`)

- **F-1. One expander slot, already taken.** `CommandDispatcher.expander`
  is a single slot that wraps every `execute` (never `undo`/`redo`), with
  the contract "a pure wrapper … One slot, one owner: whoever takes it
  releases it only if it is still their own tear-off"
  (`undo.dart:144-151`, used at :190). `ParametricSystem.install` throws
  when the slot is not empty, and `dispose` releases it only if it still
  holds its own tear-off (`parametric_system.dart:553-565`). The shell
  installs the parametric system at `planner_shell.dart:561` and disposes it
  at :604.
- **F-2. A derived edit adds no authority of its own.** `ParametricEdit`'s
  `capabilities` are the inner command's plus each type's declared
  `editCapability` (`parametric_system.dart:706-707`); its `capability` is
  raised to `geometry` after `apply` when the plan changed geometry, so the
  index does not skip it (:709-715). Its inverse is a concrete replay, so
  undo and redo never regenerate (:736-760).
- **F-3. A table's transform changes in three places.** Placement
  (`placeSymbol`, `symbol_placer.dart:68-156`: quarter turns and a mirror,
  through `placementTransform`, :42-57); the move grip (a pure translation,
  `grip_drag.dart:229-230`, applied as `t.multiply(node.transform)`, :311);
  the rotate grip (**any angle**, `grip_drag.dart:248-265`, the same
  `TransformNodeCommand`, :311). The Selection panel has no transform field
  (`selection_panel.dart:779-913`). No command mirrors an existing
  instance.
- **F-4. A layer move of an instance** is `SetInstanceLayerCommand`
  (`layer_picker.dart:148`); `SetEntityLayerCommand` has a user form
  (refuses a missing layer) and a `.restore` form (writes exactly), and
  declares `capabilities: {components}` with `capability: geometry`
  (`layer_commands.dart:385-420`; `SetInstanceLayerCommand` at :424).
- **F-5. An instance-owned ATTRIB is a root-index leaf**, its coordinates
  instance-local, transformed by the instance's composed transform
  (`container_index.dart:209-225`). It is drawn in the **root** leaf
  stream with `StyleContext.documentRoot` (`draft_painter.dart:385-394`),
  **not** through the instance's style context (:436-437), so a BYBLOCK
  colour resolves against the document root, as the default instance's
  lines do. Its **layer**, when it is layer 0, is its owning instance's
  for rendering, picking, snapping and the band (`query_filter.dart:74-80,
  113-129`, spec 12b S-2), and the layer picker maps an ATTRIB key to its
  instance (`layer_picker.dart:41-45, 73`). An ATTRIB on its own non-zero
  layer is 12b's recorded limitation (the picker and the selection prune
  disagree; `notes/2026-10-01-plan-12b-results.md:324-327`, "No app path
  makes such an ATTRIB").
- **F-6. Instance-local space is definition space.** `placementTransform`
  ends with `translation(-basePoint)` (`symbol_placer.dart:51`); a symbol's
  base point is its served top's centre for every servable symbol of both
  catalogs (14s V-6; `furniture_library_test.dart:260-275`,
  `restaurant_library_test.dart`). A label anchored at the base point sits
  at the top's centre whatever the instance's transform.
- **F-7. Text orientation is two payload scalars.** A text or ATTRIB
  payload's `scalars[1]` is its rotation; `scalars[2]` its width factor,
  read only when `textAttrs` bit 8 is set (`text_geometry.dart:171-198`).
  The width factor multiplies the glyph x axis (`la = widthFactor * scale`,
  :246), so **a width factor of −1 reflects the glyphs**; nothing in
  the engine refuses a negative one (no validation names `widthFactor`).
  Centre/middle justification carries the reference point through the
  same linear map (:251-266), so a reflected, centred label stays centred
  on its anchor.
- **F-8. The pick returns an instance-owned ATTRIB as itself.**
  `resolveHit` maps a hit with no chain to its owner's topmost group or,
  failing that, to **the entity** (`selection.dart:49-64`); an ATTRIB owned
  by a root-level instance has no group above it, so a click on a table's
  number would select the number alone, and Delete would delete it. The
  band already skips such a leaf (`_topmostGroup` is null,
  `select_tool.dart:460-466`) and adds the instance through
  `forEachInstanceInBand` (:474-475).
- **F-9. Delete removes an instance's node only.** `_deleteSelection`
  emits `RemoveNodeCommand` for an instance key (`select_tool.dart:638-640`)
  and for an instance inside a deleted group (`_groupCascade`, :687-690);
  an entity the instance owns is orphaned and `validate` reports
  `entity.owner_missing` (umbrella F-7).
- **F-10. Edits of a text's string** are `SetEntityTextCommand`
  (`commands.dart:235-262`, capability `geometry`, text and tag together);
  of its payload, `SetEntityGeometryCommand` (:549-, `geometry`).
- **F-11. Owner scans are O(entities).** `attributesOf(instance)` scans every
  live slot (`convenience_queries.dart:104-122`, "Do not call this per
  frame"); `DraftDocument.leavesByOwner()` buckets every slot once.
- **F-12. The standard text style** is `ReservedHandles.standardTextStyle`,
  family `Roboto`, with a fallback record when a file lacks it
  (`draft_document.dart:138-145`).
- **F-13. A placed table can already be rotated, by mouse only.** A
  selection shows a rotation grip; dragging it rotates about the oriented
  box's centre (`select_tool.dart:270-286`), with `Shift` rounding to 15°
  (`grip_drag.dart:13, 261`). The keyboard has no rotate for a placed
  object: `R` and `Shift+R` turn only the symbol **being placed**
  (`symbol_place_tool.dart:212-218`); otherwise `R` arms the Rectangle tool
  and `M` the Room tool (`planner_shell.dart:250-256, 292-298`). On touch,
  a small grip is hard to hit (umbrella F-11).
- **F-14. Dragging a selected number throws today.** A move drag of an
  ATTRIB key calls `rigidTransformLeaf` (`grip_drag.dart:303-305`), which
  throws for an attrib (`grips.dart:258-261`, "an attrib is never
  root-level"). T11 removes the way to get such a key.
- **F-15. Palette thumbnails are placements.** `symbolThumbnailDocument`
  builds each thumbnail with `placeSymbol` at the base point
  (`symbol_panel.dart:40-44`), drawn by a `DraftPainter` with text on
  (`jet_cad_2d_flutter/lib/src/symbol_thumbnails.dart:127`).
- **F-16. The camera flips y.** A view's world-to-screen linear part is
  `(s, 0, 0, −s)` (`viewport_transform.dart:39-46`); the page camera
  likewise. A correct upright label reaches `DrawSink.text` with a linear
  part `k ×` the camera's, not a multiple of the identity.
- **F-17. A negative width factor is safe on every consumer.** Each takes a
  general affine map: the pick box (`spatial_index.dart:1185-1200`), the
  band (`band_predicates.dart:30-35`), the GPU text box
  (`geometry_collector.dart:751`), the canvas (`canvas_draw_sink.dart:218`),
  the PDF (`pdf_draw_sink.dart:117-160`, a `cm` matrix); the cull uses
  `height × sqrt|det|` (`draft_painter.dart:973`); the measurer ignores the
  per-entity width factor. And the composed glyph-to-world map of a stamped
  label is upright, so none sees a mirror (the review checked T10
  numerically at 0, 37, 90, 180, −123 and 270°, mirrored and not).

## Decisions

### What a table is

- **T1. A table** is an `InstanceNode` that is **live** (in the tree),
  **root-level** (`parent == root`), and whose definition carries a
  `SeatingComponent` (14s S1). Its **seats** are the definition's. A
  servable instance inside a group is **not** a table in v1 (umbrella D14;
  diagnostic `table.nested`).
- **T2. A table's number is its label** (amends D1, **A-1**): the text of
  the **ATTRIB owned by the instance with tag `TABLE`**. There is no
  `TableComponent`. One place holds the number, so the drawn number, the
  saved number and the number the host addresses cannot disagree; a
  deleted table takes its number with it by the cascade (T9), so the
  umbrella's "dead component" rule (D2b) and M-14k have nothing left to
  guard; and a DXF consumer (later) reads it as the INSERT's attribute,
  which is what the engine's ATTRIB was written for (`node.dart:148-152`).
  A table with no `TABLE` ATTRIB is **unnumbered** (diagnostic
  `table.unnumbered`); one with several uses the lowest handle's
  (diagnostic `table.extra_label`).
- **T3. Seats are not edited per table in v1** (amends D1, **A-2**): the
  Selection panel shows them read-only. A per-table override is open
  question **Q-1**.

### Numbers

- **T4. A number** is a string, **trimmed**, **non-empty**, at most **8**
  UTF-16 code units, with no control character (no line break). Two
  numbers are equal by exact `==` after trimming: case-sensitive, no
  Turkish case folding (umbrella D2a). `"B4"`, `"Bahçe 3"`, `"07"` are
  valid.
- **T5. The next number** is `max + 1` over the **live tables** whose
  number is **1 to 8 ASCII digits** (`^[0-9]{1,8}$`; leading zeros allowed,
  `"07"` reads 7), written without leading zeros; `"1"` when there is
  none. Other numbers (`"B4"`) are kept and not counted. When `max + 1`
  would have 9 digits (T4's limit), the next number is the **smallest
  unused positive integer** instead, so placement never makes a
  duplicate or an invalid number.
- **T6. Uniqueness.** A number used by another live table is **refused at
  the field** (T11), never renamed. Duplicates can still arrive by loading
  a file (there is no paste or duplicate command, umbrella D5): each is a
  `table.duplicate_number` warning naming every instance that carries it,
  and the Table section shows it.
- **T7. Numbers are per plan** (umbrella decision 12: one plan per dining
  area). Uniqueness across a restaurant's plans is the host's concern
  (14b-2 exposes the tables); open question **Q-2**.

### The label

- **T8. The label record.** An `EntityKind.attrib` owned by the instance:
  tag `TABLE`; text the number; style `ReservedHandles.standardTextStyle`;
  `textAttrs = packTextAttrs(h: centre, v: middle,
  overrideWidthFactor: true)`; anchor (`coords`) the definition's **base
  point** (F-6); `scalars = [height, rotation, widthFactor]` (T10); colour
  BYBLOCK, lineweight, transparency and linetype BYBLOCK (F-5: they resolve
  as the default instance's lines do); **layer: layer 0**
  (`ReservedHandles.layerZero`), so it follows its instance's layer for
  drawing, picking, lock and the layer picker with no copy to keep in step
  (F-5). Height:
  `min(200, 0.4 × min(w, h))` mm, where `w × h` is the local bounding box of
  the definition's **first leaf** (the served top, 14s S4): 200 for every
  table top of 500 mm and more, 152 for a Ø 380 bar stool, 160 for the
  400-deep bar ledge.
- **T9. Delete cascade (render package; umbrella D3).** `_deleteSelection`
  removes, before an instance's `RemoveNodeCommand` and in the same
  compound, a `RemoveEntityCommand` for **every entity the instance owns**,
  ascending by handle, read from the lazily built `byOwner` map; the rule
  is `_groupCascade`'s for leaves (`select_tool.dart:670-682`): a fill
  whose boundary is removed is skipped, and every owned handle (and its
  boundary's fills) joins the key's `names` and is skipped when `named`
  already holds it, so a selection holding a label key and its instance
  key (possible only in a file opened before T11 ran, or by a host)
  removes each once. `_groupCascade` does the same for each instance it
  removes. Undo restores the node, then its entities (the compound's
  reversed inverse). General: right for any instance-owned leaf, not only
  a table's. The permission preflight covers the whole list as today.
- **T10. Upright (umbrella D3).** For an instance whose transform's linear
  part has columns `(a, b)` and `(c, d)`, `φ = atan2(b, a)` and
  `det = a·d − b·c`:
  - `det > 0`: rotation `−φ`, width factor `+1`;
  - `det < 0`: rotation `φ + π`, width factor `−1` (F-7);
  - rotation normalised to `(−π, π]`, and `0.0` stored for `−0.0`.

  Then the label's **world** linear map is a positive multiple of the
  identity (within `Tolerance`): it reads left to right, unmirrored, along
  world +x, for every rotation and mirror. A non-rigid instance transform
  (scale or shear) is out of scope: the app never makes one; the label
  then follows the rule above and may be scaled.
  `Transform2.multiply` applies its argument first, so the world map is
  `L · R(rot) · diag(wf, 1) · s`; both cases give `s · I` (F-17).
  One function, `tableLabelStamp(Transform2) → (rotation, widthFactor)`,
  is the only place this is computed; the placer (T13) and the system
  (T12) both call it.
- **T11. Pick (render package; umbrella D3).** `resolveHit` maps a leaf
  whose owner is an `InstanceNode` to the **root-level node above it**:
  the topmost group when there is one (today's rule), else the root-level
  instance. A click on a table's number therefore selects the table;
  the number cannot be selected, dragged or deleted alone, and a drag that
  starts on the number moves the table (today it throws, F-14). The band
  is unchanged (F-8).

### The table system

- **T12. `TableLabelSystem`**, in the planner package, keeps every
  table's label **upright**, inside the edit that changes the instance:
  - **Install by stacking (F-1).** `install()` reads the slot's current
    expander `previous` (the parametric system's, or null) and takes the
    slot with its own tear-off, which calls `previous` first and wraps the
    result. `dispose()` puts `previous` back **only if** the slot still
    holds its own tear-off. The shell installs it **after** the parametric
    system and disposes it **before**: last in, first out is a stated
    **precondition**, checked by a debug `assert` in `dispose` (the slot
    holds its own tear-off). Out of order, the table system would put the
    disposed parametric system's tear-off back, and a later
    `ParametricSystem.install` would throw. The engine's one-slot contract
    is kept: one owner at a time, released only by its owner;
    `apps/floor_planner/test/document_host_test.dart:215, 228` already pins
    an empty slot after the shell's dispose.
  - **The wrapper** returns the command unchanged when no definition in
    the document carries a `SeatingComponent` (the parametric system's
    cheap path); otherwise a `TableLabelEdit(inner)` that applies `inner`,
    then, for each handle in `inner`'s `touched` that is a table (T1) with
    a label, compares the label's stored rotation and width factor with
    `tableLabelStamp(instance.transform)` by **exact `==`** (stored
    values), and applies a `SetEntityGeometryCommand` for each that
    differs. `touched` reliably names the instance: `TransformNodeCommand`
    touches its node (`commands.dart:322`), a compound the union, a
    `ParametricEdit` a superset of its inner's (`regeneration.dart:1006,
    1033`). With no stamp, the result is `inner`'s own. With stamps, the
    inverse is a **replay with `inner`'s authority**,
    `ParametricReplay(CompoundCommand([...stampInverses.reversed,
    innerInverse], label: inner.label), inner.capabilities)` (exported by
    the engine), so undo and redo need exactly what the edit needed, not
    the stamp's `geometry`; `touched` is `inner`'s plus the labels written;
    `capability` is raised to `geometry` (F-2's rule); `label` is
    `inner.label`. All or nothing: a stamp that throws applies the stamps
    already written's inverses and `inner`'s inverse, then rethrows.
  - **Authority:** `capabilities` are `inner`'s; the stamp adds none (F-2:
    derived data inside the edit that causes it). A **translation never
    stamps** (its linear part is unchanged, F-3), which 14c relies on: a
    service move under `runtime` writes no label geometry. Asserted
    (M-14a-9).
  - **Cost:** the touched handles are checked against the document's node
    map; a label is found by scanning the instance's owned entities only
    when a touched handle is a table (O(entities), at command rate, never
    per frame; F-11).
- **T13. Placement numbers the table.** `placeSymbol` with a servable entry
  adds, in its `CompoundCommand` after the `AddNodeCommand`, the label
  (T8) with the **next number** (T5), stamped by `tableLabelStamp` for the
  placement transform. An unservable entry adds no label. `placeSymbol`
  gains `bool numbered = true`; the palette's thumbnails pass `false`
  (F-15), so a servable thumbnail shows no "1". Redo replays the
  same number (the handles and the number are fixed when the command is
  built, 09 F-8). The placement's undo removes both.

### The Table section

- **T14.** When the selection is **exactly one table**, the Selection panel
  shows a **Table** section (title `Table`, key `table-section`) above the
  layer picker:
  - **Number** (`table-number`): a text field, the panel's existing field
    machinery (`selection_panel.dart:472-503`, the room name the
    precedent, :296-299); Enter or focus loss commits the trimmed value.
    Unchanged: nothing. Invalid (T4) or used by another live table (T6):
    refused, nothing executed, the field **reverts** to the table's number
    as the other fields do, and an error line under it (`Number 4 is
    already used` / `1 to 8 characters`) stays until the next edit of the
    field or a selection change. Valid: **one**
    command — `SetEntityTextCommand(label, number, 'TABLE')` when the table
    has a label, else an `AddEntityCommand` of a new label (T8) — one undo
    step.
  - **Seats** (`table-seats`): read-only, the definition's.
  - **Rotate** (T16): two buttons, `Rotate 90° left` (`table-rotate-left`)
    and `Rotate 90° right` (`table-rotate-right`).
  - A `table.duplicate_number` on this table: a warning line
    (`Number 4 is used by 2 tables`).
  - Typing in the field triggers no tool shortcut (the existing
    `panel_focus` guard), as the other sections' fields.
  - **Enabled** when the permissions allow it: the Number field needs
    `geometry` (`SetEntityTextCommand`, `AddEntityCommand`); the rotate
    buttons need `transform` and are shown in the design mode only (Q-4).
  - The panel rebuilds on hover notifications (`selection_panel.dart:158`):
    `tablesOf` and `tableDiagnostics` are cached per document change, as
    `_areaRoom` is (:511-521), never computed per build.
- **T15. `tablesOf(DraftDocument)`** (planner package,
  `tables/table_index.dart`): the live tables ascending by instance
  handle, each `(instance, label?, number?, seats, symbolKey)`, and
  `tableDiagnostics(DraftDocument)`: `table.duplicate_number` (warning),
  `table.unnumbered` (warning), `table.extra_label` (warning),
  `table.nested` (info). One pass over nodes and entities; at document-
  change rate, never per frame. 14b-2's controller caches it per change.
- **T16. Rotating a placed table** (the human, 2026-10-03: *"bence
  masalar yerleştirildikten sonra da döndürülebilsin"*). In the design
  mode, besides the rotation grip (F-13), the Table section's buttons turn
  the selected table **90°** about its **base point** (its top's centre,
  F-6, so the table turns in place and its number does not move): one
  `TransformNodeCommand(instance, R(±90° about base) · transform)` inside a
  `CompoundCommand` labelled `Rotate` (`TransformNodeCommand.label` is
  `'Move'`, `commands.dart:295`, as the grip drag wraps it,
  `grip_drag.dart:324-328`), one undo step; the table system (T12) stamps
  the label upright in the same step. The new **linear part** is computed
  with exact quarter turns (cosine and sine in {0, ±1}; a turn only swaps
  and negates entries) and `−0.0` stored as `0.0` (as `placementTransform`,
  `symbol_placer.dart:53-55`), so four turns return the linear part
  **exactly**. The translation is computed so the base point's world
  position is unchanged; it is exact for a placement-made table at integer
  coordinates and within `Tolerance` otherwise (a general translation does
  not survive four turns bit for bit). Left is
  counter-clockwise on the screen. No keyboard shortcut (`R` is the
  Rectangle tool's, F-13). Rotation in the **selection** mode stays out
  (umbrella decision 10) unless the human rules otherwise (Q-4).

## Files

- `packages/jet_cad_floor_plan/lib/src/tables/` (new):
  `table_label.dart` (tag, record builder, height rule, `tableLabelStamp`),
  `table_numbers.dart` (validation, `nextTableNumber`),
  `table_index.dart` (T15), `table_label_system.dart` (T12).
- `lib/src/symbols/symbol_placer.dart` (T13),
  `lib/src/planner_shell.dart` (install after the parametric system,
  dispose before), `lib/src/selection_panel.dart` (T14),
  `lib/editor.dart` (exports).
- `packages/jet_cad_2d_flutter/lib/src/select_tool.dart` (T9),
  `selection.dart` (T11).
- Tests: `packages/jet_cad_floor_plan/test/tables/{table_label_test,
  table_numbers_test,table_index_test,table_label_system_test}.dart`,
  `test/symbols/seating_test.dart` (placement adds the label),
  `test/selection_panel_table_test.dart`;
  `packages/jet_cad_2d_flutter/test/{select_tool_delete_test,
  selection_test}.dart` (new cases).
- No asset changes; **no schema bump** (an ATTRIB is a known kind; no new
  component). Both libraries (`furniture.jetlib`, `restaurant.jetlib`) are
  unchanged: labels belong to instances, which a library has none of.

## Invariants

- Every table placed through the palette has exactly one `TABLE` label,
  owned by its instance, on layer 0, anchored at its base point.
- After **any** `execute` in the design mode, every labelled table's label
  is upright (T10); undo and redo return label and instance together (one
  step), needing no capability the edit did not.
- A translation of a table writes no label (14c's moves).
- No orphaned entity after any delete: `validate` reports no
  `entity.owner_missing` (umbrella M-14j).
- A click anywhere on a table's lines **or its number** selects the
  table's instance key.
- The engine package is untouched; the two allocation invariant tests are
  untouched and green (nothing here is on the frame path: the label is an
  ordinary text leaf, already measured by
  `text_paint_allocation_test.dart`).
- No golden PNG changes (no test document carries a table label); the
  palette's thumbnails are unchanged (T13's `numbered: false`).

## Testing and named mutants

Fixtures are **off the origin, rotated by a non-quarter angle (37°) and
mirrored**, on a non-default layer (the degenerate-fixture rule); every
expected number and count is written out by hand.

- **M-14a-1 (umbrella M-14a):** next number `count + 1` — live tables
  `"1"` and `"3"` give `"4"`, not `"3"`. And the Q-2 ruling: the only table renamed
  `101` at the field, the next placement is `"102"`.
- **M-14a-2:** a deleted table counted — tables 1–5, delete 5, place: the
  new one is `"5"`; and the deleted number is accepted at the field.
- **M-14a-3:** non-numeric or long numbers counted — tables `"07"`, `"B9"`,
  `"1234567890"`: next `"8"`.
- **M-14a-4:** the field's uniqueness check counts the table itself —
  committing a table's own number (or `" 4 "` for `"4"`) is accepted as
  unchanged; `"b4"` beside `"B4"` is accepted (case-sensitive).
- **M-14a-5 (umbrella M-14j):** delete without the cascade — `validate`
  reports `entity.owner_missing`; also for a table inside a deleted group;
  undo restores the label with its text.
- **M-14a-6:** `resolveHit` returns the ATTRIB — a pick on the number's
  glyph box (not on any table line) yields the instance key; Delete then
  removes table and label.
- **M-14a-7 (umbrella M-14i):** the stamp ignores the mirror (width factor
  always `+1`) — a mirrored placement's label world map has a negative
  determinant.
- **M-14a-8:** the stamp ignores rotation — after a 37° rotate-grip
  command, the label's world x axis is not world +x.
- **M-14a-9:** a translation stamps — a moved table's label payload is
  byte-equal before and after, and the edit's inverse holds no
  `SetEntityGeometryCommand`.
- **M-14a-10:** the stamp as a separate command — `undoDepth` after a
  rotate is one more than before, not two; one undo restores instance and
  label, and one redo re-applies both.
- **M-14a-11:** the system replaces the parametric expander instead of
  stacking — with both installed, a wall edit still regenerates and a
  table rotation still stamps; disposing in the shell's order leaves the
  slot null (both orders asserted: out of order trips the debug assert).
- **M-14a-12:** the label written on the current layer instead of layer 0
  — place a table on layer A, move it to a hidden layer B: its number
  must hide (the rendering filter rejects the label); back on A, it
  shows. A label left on A stays visible under the mutant.
- **M-14a-13:** an unservable symbol numbered — a planter places with no
  label, and a placement after it still takes the next number.
- **M-14a-14:** the height rule — a bar stool's label height is 152, a
  Ø 600 high table's 200.
- **M-14a-15:** the rotate button turns about the world origin or the
  oriented box's centre instead of the base point — a mirrored,
  off-origin table (placed, integer coordinates) keeps its base point at
  the same world point after `table-rotate-right`; four presses restore
  its transform exactly (`==`); on a 37°-rotated table, the linear part
  exactly and the translation within `Tolerance`. Each press is one undo
  step labelled `Rotate`, with the label upright.
- **M-14a-16 (umbrella M-14b):** the label on the definition, or shared
  through it — two placements of one symbol, off the origin, keep
  different numbers, and renaming one leaves the other.
- **M-14a-17:** thumbnails numbered — a servable symbol's thumbnail
  document holds no ATTRIB.
- **M-14a-18:** next number past 8 digits — the only table `"99999999"`
  and table `"1"`: the next is `"2"`, not `"100000000"`.
- **M-14a-19:** the cascade not de-duplicated — a delete of a selection
  holding both a label key (built by hand) and its instance key succeeds
  in one step.
- **M-14a-20:** the stamp's inverse with the stamp's authority — under a
  permission set allowing `transform` only, a rotation executed there
  undoes and redoes.
- **Render check:** a mirrored, 37°-rotated table drawn through
  `DraftPainter` into a recording sink hands `DrawSink.text` a transform
  whose linear part is `k ×` the camera's linear part with `k > 0` (F-16),
  within `Tolerance`, on the screen camera and the page camera alike.

## Risks

- **A negative width factor in a file.** Every consumer here takes the
  composed affine map (F-17); a future DXF writer must map it to the
  ATTRIB's "backward" generation flag (DXF forbids a negative width
  factor). Noted for the DXF slice.
- **Behaviour change for instance-owned leaves** (T9, T11): the render
  package's existing tests that build ATTRIBs (`omit_owners_test`,
  `frame_accounting_test`, the rig) do not select or delete them; the
  plan runs the whole render suite and records any change.
- **Existing planner tests that place servable symbols**
  (`test/symbols/furniture_library_test.dart:392-419`, `seating_test.dart`)
  now get a label; they should pass. The plan runs the planner, the
  restaurant and the `apps/floor_planner` suites too.
- **Stacking on the expander slot** relies on the shell's install and
  dispose order (T12); a host that builds its own shell in 14b-2 goes
  through the controller, which owns both.
- **Labels on very small tops**: a 2-character number at 152 mm on a
  Ø 380 stool is about 170 mm wide, inside the seat; three or more
  characters overflow the stool. Accepted (bar stools are usually numbered
  1–2 digits).

## Open questions for the human

- **Q-1.** Should a table's seat count be editable per table (a 4-seat
  table set for 5)? Proposed: **no** in v1; the seat count is the symbol's.
- **Q-2.** Numbers across dining areas: each plan numbers from 1 by itself
  (proposed), or should a plan start from a number the host gives (for
  example, the terrace from 101)? Proposed: per plan from 1; a host start
  number can come with 14b-2's API if wanted.
- **Q-3.** The label's size rule (200 mm, smaller on small tops) and the
  8-character limit: acceptable?
- **Q-4.** Rotating after placement (T16): in the **design** mode only
  (proposed; the umbrella's decision 10), or also in the **selection**
  mode during service?

## The human's rulings (2026-10-03)

*"1) bu sürümde olmayabilir. 2) önerin uygun ama manuel değiştirilebilmeli.
3) uygun. 4) sadece tasarım modunda. bu branch'te devam edebiliriz."*

- **Q-1 closed:** no per-table seat count in v1 (T3 stands).
- **Q-2 closed:** each plan numbers from 1 by itself, and **every number
  can be changed by hand** (T14's Number field); because the next number
  is `max + 1` over the live numeric numbers (T5), a plan whose first
  table is renamed `101` continues `102`, `103`, … — a starting number
  needs no setting of its own.
- **Q-3 closed:** the size rule and the 8-character limit stand (T4, T8).
- **Q-4 closed:** rotating a placed table is a **design-mode** action only
  (T16); the selection mode does not rotate (umbrella decision 10).
- The work continues on `claude/exciting-pasteur-9m22jv`.

## Revision 2

Applied from the independent review of revision 1 (`fcf03ba`), "Ready with
fixes"; the review confirmed A-1 and A-2 sound, every fact in substance,
T10 numerically, the negative width factor on every consumer, and the
stacking shape.

- R-1: the label on layer 0 (T8), the layer sync dropped from T12, F-5
  corrected, M-14a-12 redefined.
- R-2: T16's exactness is the linear part's; the translation within
  `Tolerance` (exact for a placement-made fixture); `−0.0` cleaned;
  M-14a-15 restated.
- R-3: F-15; `placeSymbol(numbered:)`, thumbnails unnumbered; M-14a-17.
- R-4: F-16; the render check compares with the camera's linear part.
- R-5: T12's inverse is a replay with `inner`'s authority; the compound
  only with stamps, labelled; all or nothing; M-14a-20.
- R-6: T9's cascade de-duplicated through `names`/`named`, fills skipped by
  `_groupCascade`'s rule, from `byOwner`; M-14a-19.
- R-7: T14 reverts like the other fields; the error line's life; the
  enable conditions; the cache per document change.
- R-8: T5 counts up to 8 digits; past that, the smallest unused integer;
  M-14a-18.
- R-9: LIFO dispose a precondition with a debug assert; M-14a-11 both
  orders; the app test that pins the empty slot cited.
- R-10: citations in F-4 and F-7 corrected.
- R-11: F-14; T11's drag on the number.
- R-12: M-14a-16 (umbrella M-14b); M-14a-10 covers redo; T16's `Rotate`
  compound.
- R-13: the risk narrowed (F-17); the planner, restaurant and app suites
  named.
