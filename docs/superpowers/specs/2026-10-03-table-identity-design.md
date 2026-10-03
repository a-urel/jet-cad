# Table identity (14a) — design

**Date:** 2026-10-03. **Status:** design, **revision 1**, for the human's
approval. **Sub-project:** 14 (restaurant embedding), slice **14a**.
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
  (`layer_commands.dart:378-420`).
- **F-5. An instance-owned ATTRIB is a root-index leaf**, its coordinates
  instance-local, transformed by the instance's composed transform
  (`container_index.dart:209-225`). It is drawn in the **root** leaf
  stream with `StyleContext.documentRoot` (`draft_painter.dart:385-394`),
  **not** through the instance's style context (:436-437): its own `layer`
  decides its visibility and lock, and a BYBLOCK colour resolves against
  the document root, as the default instance's lines do.
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
  :232-236), so **a width factor of −1 reflects the glyphs**; nothing in
  the engine refuses a negative one (no validation names `widthFactor`).
  Centre/middle justification carries the reference point through the
  same linear map (:238-252), so a reflected, centred label stays centred
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
  number is **1 to 9 ASCII digits** (`^[0-9]{1,9}$`; leading zeros allowed,
  `"07"` reads 7), written without leading zeros; `"1"` when there is
  none. Other numbers (`"B4"`, a ten-digit one) are kept and not counted.
  Nine digits keep every value exact on the web (below 2^53).
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
  as the default instance's lines do); **layer: the instance's layer**
  (F-5: the label's own layer decides whether it draws and whether it is
  locked), kept in step by T12. Height:
  `min(200, 0.4 × min(w, h))` mm, where `w × h` is the local bounding box of
  the definition's **first leaf** (the served top, 14s S4): 200 for every
  table top of 500 mm and more, 152 for a Ø 380 bar stool, 160 for the
  400-deep bar ledge.
- **T9. Delete cascade (render package; umbrella D3).** `_deleteSelection`
  removes, before an instance's `RemoveNodeCommand` and in the same
  compound, a `RemoveEntityCommand` for **every entity the instance owns**,
  ascending by handle; `_groupCascade` does the same for each instance it
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
  One function, `tableLabelStamp(Transform2) → (rotation, widthFactor)`,
  is the only place this is computed; the placer (T13) and the system
  (T12) both call it.
- **T11. Pick (render package; umbrella D3).** `resolveHit` maps a leaf
  whose owner is an `InstanceNode` to the **root-level node above it**:
  the topmost group when there is one (today's rule), else the root-level
  instance. A click on a table's number therefore selects the table;
  the number cannot be selected, dragged or deleted alone. The band is
  unchanged (F-8).

### The table system

- **T12. `TableLabelSystem`**, in the planner package, keeps every
  table's label **upright** and **on the instance's layer**, inside the
  edit that changes the instance:
  - **Install by stacking (F-1).** `install()` reads the slot's current
    expander `previous` (the parametric system's, or null) and takes the
    slot with its own tear-off, which calls `previous` first and wraps the
    result. `dispose()` puts `previous` back **only if** the slot still
    holds its own tear-off. The shell installs it **after** the parametric
    system and disposes it **before** (last in, first out). The engine's
    one-slot contract is kept: one owner at a time, released only by its
    owner.
  - **The wrapper** returns the command unchanged when no definition in
    the document carries a `SeatingComponent` (the parametric system's
    cheap path); otherwise a `TableLabelEdit(inner)` that applies `inner`,
    then, for each handle in `inner`'s `touched` that is a table (T1) with
    a label, compares the label's stored rotation and width factor with
    `tableLabelStamp(instance.transform)`, and its layer with the
    instance's, by **exact `==`** (stored values), and applies a
    `SetEntityGeometryCommand` and/or `SetEntityLayerCommand.restore` for
    each that differs. Its inverse is
    `CompoundCommand([...stampInverses.reversed, innerInverse])`; its
    `touched` is `inner`'s plus the labels it wrote; its `capability` is
    raised to `geometry` when it wrote any (F-2's rule).
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
  placement transform. An unservable entry adds no label. Redo replays the
  same number (the handles and the number are fixed when the command is
  built, 09 F-8). The placement's undo removes both.

### The Table section

- **T14.** When the selection is **exactly one table**, the Selection panel
  shows a **Table** section (title `Table`, key `table-section`) above the
  layer picker:
  - **Number** (`table-number`): a text field; Enter or focus loss commits
    the trimmed value. Unchanged: nothing. Invalid (T4) or used by another
    live table (T6): refused, an error line under the field (`Number 4 is
    already used` / `1 to 8 characters`), the field keeps the typed value
    until Escape or a valid commit; nothing is executed. Valid: **one**
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
  `TransformNodeCommand(instance, R(±90° about base) · transform)`, labelled
  `Rotate`, one undo step; the table system (T12) stamps the label upright
  in the same step. The new linear part is computed with **exact** quarter
  turns (cosine and sine in {0, ±1}, as `placementTransform` does), so four
  turns return the stored transform byte for byte. Left is
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
  owned by its instance, on its layer, anchored at its base point.
- After **any** `execute` in the design mode, every labelled table's label
  is upright (T10) and on the instance's layer; undo and redo return
  label and instance together (one step).
- A translation of a table writes no label (14c's moves).
- No orphaned entity after any delete: `validate` reports no
  `entity.owner_missing` (umbrella M-14j).
- A click anywhere on a table's lines **or its number** selects the
  table's instance key.
- The engine package is untouched; the two allocation invariant tests are
  untouched and green (nothing here is on the frame path: the label is an
  ordinary text leaf, already measured by
  `text_paint_allocation_test.dart`).
- No golden PNG changes (no test document carries a table label).

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
  label.
- **M-14a-11:** the system replaces the parametric expander instead of
  stacking — with both installed, a wall edit still regenerates and a
  table rotation still stamps; disposing in the shell's order leaves the
  slot null; disposing the parametric system first leaves the table
  system's tear-off in place (no release of a slot it does not hold).
- **M-14a-12:** the label's layer not synced — moving a table to a hidden
  layer hides its number (the rendering filter rejects the label); back,
  it shows.
- **M-14a-13:** an unservable symbol numbered — a planter places with no
  label, and a placement after it still takes the next number.
- **M-14a-14:** the height rule — a bar stool's label height is 152, a
  Ø 600 high table's 200.
- **M-14a-15:** the rotate button turns about the world origin or the
  oriented box's centre instead of the base point — a mirrored,
  off-origin table's base point stays at the same world point after
  `table-rotate-right`; four presses restore the transform exactly
  (`==`), and each press is one undo step with the label upright.
- **Render check:** a mirrored, 37°-rotated table drawn through
  `DraftPainter` into a recording sink hands `DrawSink.text` a transform
  whose linear part is a positive multiple of the identity (within
  `Tolerance`), on the canvas sink and the PDF sink alike.

## Risks

- **A negative width factor is new to every consumer.** The canvas and PDF
  sinks take the composed affine transform (F-7), so the render check
  above proves both; a future DXF writer must map it to the ATTRIB's
  "backward" generation flag (DXF forbids a negative width factor). Noted
  for the DXF slice.
- **Behaviour change for instance-owned leaves** (T9, T11): the render
  package's existing tests that build ATTRIBs (`omit_owners_test`,
  `frame_accounting_test`, the rig) do not select or delete them; the
  plan runs the whole render suite and records any change.
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
