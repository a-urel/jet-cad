# Sub-project 3 (architecture kit): deferrals carried in, and the test-port coverage of `jet_cad_floor_plan`

Read-only research, 2026-10-15, on `main` at `7e65905b`. Paths are relative to the repo root unless absolute.
`docs/superpowers` is written `dsp`. "2aR" is `dsp/notes/2026-10-14-plan-library-2a-results.md`, "2bR" is
`dsp/notes/2026-10-14-plan-library-2b-results.md`, "L2a"/"L2b" are `dsp/ledgers/2026-10-14-plan-library-2a|2b/`.
Old tests are `packages/jet_cad_floor_plan/test/<file>`; test counts are `test(`/`testWidgets(` lines in the file
(a loop-generated case counts once).

Kinds used in List 1:
- **PT** ported test not yet ported (whole file or named cases)
- **TL** test lines removed from a port, to be restored
- **SEAM** contract field/seam/signature a later sub-project was told to expect or to decide
- **BEH** behaviour or parity bar
- **DOC** doc, comment or stale-text clean-up

Caveat on method: the notes name ports by test id, not always by every case. Where I say "no note names it" I
searched `dsp/notes`, `dsp/ledgers` (2a, 2b, kit-contract), `dsp/plans/2026-10-1[34]-*` and the `// Ported from`
headers in `packages/jet_cad_2d_plan/test` and `packages/jet_cad_2d_kit/test`. An id-scan (old test id looked up
as a word in the new tests) is used only as a hint, because renamed ids give false "missing"; hints are marked.

---------------------------------------------------------------------------------------------------------------

# LIST 1: everything carried to sub-project 3

## 1A. The wall attachment and the wall-face provider (A5: "the 09c tests are ported with it")

| # | Item | Source | Kind |
|---|------|--------|------|
| D-01 | `symbols/wall_attach_test.dart` (23: WA1-WA18, WK0-WK4), `symbols/wall_faces_test.dart` (9: WF1-WF9), `symbols/wall_attach_property_test.dart` (2: WP1-WP2), `symbols/symbol_move_test.dart` (6: MV1-MV6): "move with the wall-face provider to sub-project 3". 40 tests. | umbrella `dsp/specs/2026-10-13-kit-architecture-design.md:270-272` (A5 parity bar: capture distance, ghost on the face, marker, `M` mirror while attached, face side under a mirrored group); 2a spec `dsp/specs/2026-10-14-plan-library-design-mode-design.md:471-472`; L2a `task-14-brief.md:49`; `dsp/plans/2026-10-14-plan-library-2a.md:22107` | PT |
| D-02 | `symbols/symbol_place_tool_test.dart:1368-~1740`, the group "the wall attachment (spec 09c D6)", 15 tests (16 px capture vs snap aperture, untagged does not attach, F3 off, `M`/`R` while attached, marker at the nearest glyph, zoom brings face into capture, re-arm, W-5 unit after unit snaps along the face, refused-by-permissions allocates nothing, Blueprint ghost `0xFFC857`, marker Paint is a field). 2a ported the other ranges. | L2a `task-14-brief.md:49`; plan header `packages/jet_cad_2d_plan/test/tools/plan_symbol_tool_test.dart:6` | PT |
| D-03 | `host/against_wall_rotate_test.dart` (3 tests): "not ported, sub-project 3 (walls); the plan's Task 7 Step 8 says so". | 2bR:348; `dsp/plans/2026-10-14-plan-library-2b.md:7218` | PT |
| D-04 | `apps/floor_planner/test/symbols/wall_attach_end_to_end_test.dart` (WE1, WE2) and `symbol_shell_test.dart` SS16 (a base unit attaches to a 30 degree face, a second snaps to its side) and SS17 (a wall on a hidden/locked layer hosts nothing: the shell hands the faces the openings' host rule). **No note, ledger or plan mentions any apps/floor_planner symbol test**; they belong to this item by subject. WE2 ("a plan saved before 09c ... byte-identical") has a dead premise under decision 9 (no old plans). | found by search; no source names them | PT |
| D-05 | `host/editor_tools_review_test.dart`: "a symbol against the north wall: M under full, then mirror false: it attaches as an unmirrored one does" (permission `mirror`/`rotate` against attachment, `mayRotate`), plus O13a (dimension end grip dropped on a wall corner, `snapping: false`) and O13b (window slide grip 15 mm short of its end, `snapping: false`). 2a Task 20 ported only RV6, RV8, RV9, O23 and R-2 of this file. | L2a `task-20-brief.md:532` (the port list); no note names these three | PT |
| D-06 | Band invalidation after a placement (`symbol_place_tool.dart:500` today) is "the wall-face provider's business": a caching provider must read `document.commands.stateId`. | L2a `task-14-brief.md:38`; `plan_symbol_tool_test.dart` header | BEH |
| D-07 | Do not copy the test kit's inverted hysteresis (`TestEdge`: kept reach 10 px smaller than first reach 16 px, so an attached ghost lets go sooner than it attaches and oscillates). AT-20 pins it as the test kit's. "Record it for sub-project 3 so no real provider copies the convention." | L2a `task-14-review.md:64`; `task-14-report.md:126`; `plan_symbol_tool_test.dart:1514` | BEH |
| D-08 | The provider fits `AttachmentProvider` (`kind` `'wall-face'`, `attach(AttachmentQuery)`, `Attachment{transform,marker,token}`); `AttachmentQuery` has `footprint,current,pointer,capture,edgeCapture,mirrored,mayRotate,exclude,keep`. Under `rotate:false` a symbol attaches only to a face its back already faces and keeps its turn. Kit `jet_cad_2d_kit/lib/src/kit/attachment.dart:12` already documents `wall-face`. | 2a spec P3 (`...design-mode-design.md:431-470`) and its Facts (`:114-117`); 2a final review "sub-project 3 readiness" (L2a `final-review.md:234-238`) | SEAM |
| D-09 | `rotatedTo` in `packages/jet_cad_2d_plan/lib/src/panels/symbol_section.dart` calls a local `_isOrthonormal` copied from `wall_attach.dart:402-407`; de-duplicate when the provider lands. | L2a `task-17-brief.md:879`; code comment `symbol_section.dart:136` | DOC |
| D-10 | Stale doc comment still names `WallFaces`: `packages/jet_cad_2d_plan/lib/src/symbols/symbol_box.dart:153` ("document change belongs to the caller (`WallFaces`, spec D3, D4)"). The 2a re-review said "fix in passing"; it was not. | L2a `final-review.md:224` ("Fix the stale `WallFaces` doc in symbol_box.dart:134 in passing"; the line is now :153); `task-14-review.md:68`; grep today | DOC |

## 1B. The furniture library (the architecture kit's symbols)

| # | Item | Source | Kind |
|---|------|--------|------|
| D-11 | `symbols/furniture_library_test.dart` (34 tests: committed bytes = built, 41 symbols in 6 categories, keys once in catalog order, D9 against-wall set exactly, families exactly, "behaviour tags come last", every family member shares depth/front/back (W-16), D9 boxes, base point on box centre x, 14 symbols with names, 27 pre-09c fixture, 14s dining tables v2, chairs 450x450 tucked 100 mm, round table four chairs, quarter turns, 100-4000 mm). The tag-based tests ("against-wall set", "tags come last") must be re-asked as `attachTo`/`family` fields: the **"assertions unchanged" rule cannot hold literally**; needs a ruling. The "27 pre-09c fixture" tests have a dead premise (decision 9). | umbrella A12 and Facts; 2a Task 13 brief (L2a `task-13-brief.md:57`: "the asset moves with the furniture kit, sub-project 3") | PT |
| D-12 | `symbols/symbol_search_test.dart:82-164, 191-267` (12 tests pin the furniture asset's 41 symbols by name, tag, category); 2a ported only 4 + new GM tests over a fixture library. | L2a `task-13-brief.md:57`; 2aR:239 | PT |
| D-13 | `symbols/symbol_box_test.dart:321-339, 391-410` (3 tests pin the furniture asset's literal boxes; the 2a port uses 3 fixture keys for 4 asset keys). Also `symbol_ghost_test.dart` fixture was changed because "that asset moves with its kit". | L2a `task-14-brief.md:49`; headers `symbols/symbol_box_test.dart:4`, `symbol_ghost_test.dart:8` | PT |
| D-14 | `symbols/symbol_end_to_end_test.dart` (2 tests): a real furniture symbol (`bed.double`) rotated, mirrored, far from origin, through placer, painter, pick, snap, extents, validate, codec; and the Select tool moving/rotating a placed instance. No note names it. | found by search | PT |
| D-15 | `package_assets_test.dart` PA2 (furniture library loads from a bundle holding only the package key) and PA3 (a bundle with only the app's old key fails). 2a ported PA1, PA5, PA6, PA8. PA4 (export font from a package-key bundle) is named nowhere. | 2aR:233 (FR1; PA1,PA5,PA6,PA8) | PT |
| D-16 | Restaurant side that needs the furniture library: `jet_cad_restaurant_symbols/test/restaurant_library_test.dart` RL15 (furniture + restaurant libraries merge without a clash), `symbol_section_catalog_test.dart` SC1-SC2 (both libraries: no servable entry has a size family; every against-wall entry's base point on its box's centre x), `symbol_names_test.dart` SNL (furniture row). | found by search | PT (SP4 consumes) |
| D-17 | **The furniture library carries servable tables.** `symbols/seating_test.dart` SE8-SE10b (placement copies seats with the definition; a v1 dining table gets a servable v2 copy beside it; a hand-edited copy without seats is not reused) and SE11 (the furniture library's dining tables are v2 and servable) are named by neither 2a, 2b nor SP1 (SP1 ported SE1-SE7 to the kit validator and `unit_component_test`). The architecture kit's catalog must build `UnitComponent`s for its dining tables (service mode reads them) and the v2 history matters. | kit-contract `task-4-brief.md:25` (rule map: SE6, SE7 only); `unit_component_test.dart:1-2` (SE1-SE3 only) | PT + SEAM |
| D-18 | `example_test.dart` (1): the old example is the planner over the furniture library from the package asset. 2a replaced it with its own example (ED-8, `jet_cad_2d_plan/test/example_test.dart`); the architecture kit needs its own example and README snippet checks. | L2a `task-20-brief.md:12,389` | DOC |

## 1C. Wall, opening, separator, room, dimension, box (the six types)

| # | Item | Source | Kind |
|---|------|--------|------|
| D-19 | All unported by design: `wall_*` (7 files, 73 tests), `opening_*` (13 files, 85), `room_*` (16 files, 100), `dimension_*` (14 files, 73), `separator_test` + `separator_tool_test` (10), `box_test` + `planner_box_test` (12). 54 files, 353 tests; no note names any of them as a file because they "go with the type". Umbrella A12: "the wall geometry, opening cuts, room tracing, dimension attachment ... move into the new packages with their tests". | umbrella `:364-380` (A12), `:388-406` (A13) | PT |
| D-20 | `selection_panel_test.dart` WS1-WS11 (the Wall section: shows for exactly one wall, thickness commit/revert, mitre regeneration, justification change moves both walls, runtime read-only, tool settings, pinned target, denied components, max thickness one ulp). 2a ported the SE cases over a test **box** kit and changed the asserted word `'Wall'` to `'Box'`, W to B (SE11, SE12, SE13, SE15, SE16). | L2a `task-17-brief.md:44, :1846`; `progress.md:149` (ruling); `task-18-review.md:52` | PT + TL |
| D-21 | `colors/color_picker_test.dart` CP2 (tap teal with two rooms, a wall, a separator selected: one undo step, both rooms teal, wall and separator untouched; tint pixels). CP1's "a separator alone" and "While the Wall tool's settings show" were replaced by `disc.draw` stand-ins. | L2a `task-17-brief.md:44, :1850`; header `panels/colour_row_test.dart:14` | PT + TL |
| D-22 | `touch_tools_test.dart` TD1 (the Room tool: a held, moved finger joined by a second commits nothing and zooms; a tap places one room). 2a ported TD2 with a polyline. | L2a `task-15-brief.md:999`; header `canvas/touch_tools_test.dart:6` | PT |
| D-23 | `planner_shell_test.dart` cases on the sample flat: "a click on a wall selects it in the running shell", "cmd+Z undoes a Delete through the command log" (deletes a wall), "ctrl+Z after deleting two walls brings both back in one step". | L2a `task-15-brief.md:1001` | PT |
| D-24 | l10n cases: `determinism_test.dart` DT1 (same UI edits in English and Turkish encode the same bytes; rooms, tables, dimensions); `leak_test.dart` LK2 (every sample-plan object selected in Turkish, size menu open); `overflow_test.dart` OV-H (each root object of the sample plan selected; right panel never overflows); `panel_words_test.dart` PW1/PW2's Wall section words and edits ('Duvar', 'Kalinlik', wall-thickness, 'Dicke'); `numbered_names_test.dart` NN3 (the sample plan names its rooms in its language, `roomName`); `value_words_test.dart` VW3's "Room notice in each language"; `new_plan_separator_test.dart` NS3's room-label assertion. | L2a `task-9-brief.md:64-66, :226`; `task-8-brief.md:46`; `task-18-brief.md:671`; headers `l10n/numbered_names_test.dart:4`, `l10n/layer_page_words_test.dart:6`, `editor/editor_separator_test.dart:8` | PT |
| D-25 | The architecture kit's words: the strings 2a's Task 9 listed as "sub-project 3 (its words become `KitNames` words under `type:`/`tool:`/`property:` ids)": `roomOccupied`, `toolBox`, `toolWall`, `toolDoor`, `toolWindow`, `toolGap`, `toolRoom`, `toolSeparator`, `toolDimension`, `width`, `height`, `thickness`, `justifyLeft/Centre/Right`, `position`, `flipHinge`, `flipSwing`, `area`, `value`, `aligned`, `horizontal`, `vertical`, `end1`, `end2`, `endFixed`, `leftFace`, `centreline`, `rightFace`, `axesTurned`, `endOnWall`, `roomName`, `sampleHall/Kitchen/Bath/Living/Dining/Bedroom`. German and Turkish must be complete (A16 conformance). | L2a `task-9-brief.md:52` | SEAM |
| D-26 | Palette rows of the planner's box, wall, door, window, gap, room, separator and dimension "leave with" the tools: `planner_draw_test` A12b keeps the generic seven rows only. The tools' letters (today W, D, N, G, M, S, I, C ... see `editor_tools_test` M-H41 list "L, P, R, B, W, D, N, G, M, S, I, C, A, T") must be requested as kit letters; load-time letter conflicts go to the later tool with a diagnostic (A3). `EC1` ("the palette's sixteen tools in its order, then symbol") is the closed list that dies; its replacement test is the kit tool list. | L2a `task-16-brief.md:1161`; `palette_draw_test.dart:242`; umbrella A3 (`:242`) | BEH |
| D-27 | The status line's room and dimension notices (`planner_shell.dart:1007-1011`) were "not ported ... sub-project 3". | L2a `task-20-brief.md:39` | BEH |
| D-28 | The separator's `DASHED` linetype: `new_plan.dart` ports `new_document.dart` "without its DASHED linetype (the separator's, sub-project 3)". Old `new_document_test` ND1 asserts "holds DASHED at handle 6"; ND2/ND3 too; the kit must add the record (and the "new plan" registration hook already takes `register`). The test file `new_document_test.dart` (6 tests) is named by no note; its page/units lines have no twin either. | `packages/jet_cad_2d_plan/lib/src/controller/new_plan.dart:3-4`; `dsp/plans/2026-10-14-plan-library-2a.md:10304`; L2a `task-6-review.md:88` | BEH + PT |
| D-29 | Layer rules for live objects: `layers/tools_layer_test.dart` (10: each tool commits its object on the effective current layer in one undo step), `layers/opening_host_layer_test.dart` (6: only a wall on a visible, unlocked layer hosts a new opening; `isUsableHost` reads `ObjectLayer`), `layers/attach_layer_test.dart` (2: a dimension attaches only to what is drawn). `layer_picker_test` "in the app: below the Selection section's type section for a wall" (apps/floor_planner `layers/layer_picker_test.dart:352-401`) was not ported. In the new design "live object" comes from the catalog (E1); the kit has to prove these three through the registered types. | umbrella Facts (`isParametricObject`, `layers/layer_picker.dart:23-29`); L2a `task-18-brief.md:656` | PT |
| D-30 | Export: `exportOmitOwners` (today every live separator) becomes `PlanType(exported: false)` (`jet_cad_2d_kit/lib/src/kit/plan_type.dart:67`; used `plan_controller.dart:340`). The separator kit type must set it; no test pins "the separators omitted" for PDF and PNG except old `export/*` app tests and 2a Task 19's `unexported:` plumbing. | umbrella Facts `:100`; `export_bytes.dart:28-29` | SEAM |
| D-31 | Colour targets: `pickedColors`/`recolorCommand` (today rooms and tables) become `PlanType(colour: ColourTarget)`. The room is the only architecture type with a colour; `room_color_test` (9) and `room_tint_test` (1) are in D-19. 2a built the contract with a box-kit stand-in and `PlanSwatch` in the contract. | L2a `task-9-brief.md:54` (palette lives in the contract); `jet_cad_2d_plan/test/panels/colour_row_test.dart:14` | SEAM |
| D-32 | Decimal separator: `decimal_separator_test.dart` (6: Q0-S1 a switch to comma rewrites the area and the dimension value in one undo step; Q0-S2 feet-and-inches area; Q0-E1/E2/E3/E3b panel rows and the Dimension tool's status notice follow the page). 2a ported only the generic separator (`locale_separator_test`, `document_separator_test`). | found by search; no note names it | PT |
| D-33 | `delete_components_test.dart` (3: P-1 a table with data plus a wall deleted together leaves no component entry; P-2 a wall alone removes `WallParams` and `ObjectLayer`; P-3 a wall hosting a door takes the door, the 08 D4 cascade). The engine feature (node components on delete) is generic, the fixtures are walls. | found by search | PT |
| D-34 | `startup_plan_test.dart` (14) and `intersection_snap_test.dart` (1): the sample flat (9 walls, 7 doors, 8 windows, a column, a separator, 5 dimensions, 8 furniture fills, 611 entities) and the phantom-intersection snap on its moved partition. 2b's editor fixtures replaced the flat with root-level lines "(sub-project 3's walls and rooms)". The demo app's startup plan belongs here. | `unit_editor_fixture.dart:9`; L2b `task-8-brief.md:265, :276`; `dsp/plans/2026-10-14-plan-library-2b.md:7546` | PT |

## 1D. R-16: the room and tint lines removed from 2b ports (restore when rooms land)

| # | Item | Source | Kind |
|---|------|--------|------|
| D-35 | `service/table_fill_test.dart` TF1 and TF7: the teal room R, its tint (`tintSample`, `tintAlpha`) and TF7's channelDistance line comparing against the tint. | 2bR:322, :789-790, :840-841; `unit_fill_test.dart:2-6, :202`; L2b `progress.md:69, :244`; L2b `task-15-brief.md:44, :961-962` | TL |
| D-36 | **TF3's fill count is `hasLength(5)` ('A, B, C, U and K') and must return to 6** when the room R returns. | `packages/jet_cad_2d_plan/test/service/paint/unit_fill_test.dart:535`; 2bR:789-790, :836-837 | TL |
| D-37 | `colors/table_color_export_test.dart` EX2 and EX3 tint lines, EX5's room line, and the premises' key list (now `['A','B','C','N','U','K','H','M']`, was with `R`). | 2bR:323, :841; `unit_colour_export_test.dart:2-3, :164-166`; L2b `task-15-brief.md:967` | TL |
| D-38 | The zone fixture's walled room named `7` (and "the TEXT and the room name" look-alike premise, `hasLength(2)`); `host/zone_fixture.dart` -> `test/support/unit_zone_fixture.dart:7, :67`. Related and **unported without a note**: `controller_test.dart` CZ1 ("table ` 7 ` by 7, not the TEXT or the room named 7"), CZ2-CZ6 (see list 2, hint). | 2bR:325, :704; `unit_zone_fixture.dart:7` | TL |
| D-39 | 2a's earlier room/tint rows: color_picker CP2 (D-21), `selection_panel` WS (D-20), the room cases ported "over the box kit's colour target". | L2a `task-17-brief.md:44` | TL |

## 1E. Contract seams 2a's final review said the architecture kit will need (all still open)

| # | Item | Source | Kind |
|---|------|--------|------|
| D-40 | `PlanServices` lacks `isLocked(Handle)` (a wall tool neither joins nor snaps to a locked wall), `allows(PlanGate)` (an opening tool's flip/turn keys respect `mirror`/`rotate` as `plan.symbol` does) and a `Listenable` for the tool's own settings (a ghost re-renders on a panel change). Verified: `packages/jet_cad_2d_kit/lib/src/kit/plan_services.dart` has none (`document, index, camera, objectSnap, attachments, words, symbolDefinition, symbolsState`). "Adding them now avoids churn"; not done by the final fix wave. | L2a `final-review.md:232-249` "Recommendations (sub-project 3 readiness)" item 2 (:243-247) | SEAM |
| D-41 | `PropertySectionBuilder<T>` receives no handle and no services (`plan_type.dart:24-25`: `(BuildContext, T value, void Function(T) commit, KitWords)`); a wall section listing its openings, or a room section reading neighbours, "cannot be written". Suggested `PlanSectionContext {Handle object; PlanServices services;}`. "The spec fixes today's signature, so this is the human's call." Unresolved. | L2a `final-review.md:248` (item 3) | SEAM |
| D-42 | Dependency floors `jet_cad_2d: ^0.7.2` in the kit's and the plan's pubspecs predate E1-E5; "the wave raises them", make sure before any publish. | L2a `final-review.md:249` (item 4); 2bR ("dependency floors stay ^0.7.2 in this branch; the wave raises them", Global l.25 of the 2a/2b plans) | DOC |
| D-43 | Wall joins and wall-endpoint grips edit a neighbour's parameters: I1 (a write on a frozen object) and I2 (planner-refused `generate` output blocks the object and its neighbours) were fixed in the final fix wave, but two related items were **parked for the grips**: `GuardedTool._failed` rethrows an `ArgumentError` the probe could not cure out of a `plan.select` grip drag ("noted for sub-project 3's grips"), and the plan-level `_first` catch-all that runs `_probeAll` on any plain error (costs a probe on a rare path). | L2a `progress.md:182`; `final-rereview.md:143`; `final-review.md:83, :105` | SEAM |
| D-44 | Remounting `PlanShortcuts(shortcuts:false)` on the same controller could reopen `idleKeys` ("deferred to 2b/sub-project 3 where views are swapped"). 2b audit marked it UNCLEAR; `plan_shortcuts_test.dart:425-440` (M-KB-14a/b) pins the controller swap, not a same-controller remount. | L2a `progress.md:180`; L2b `audit-2a-deferrals.md` row 50 | SEAM |
| D-45 | The ruling "the other minors stay deferred ... if wrong: a deferred minor surfaces in sub-project 3": 2a's deferred minors (Task 14: registry's provider-kind-in-try and guarded dispose untested, move-resolver branches without mutants (scaled instance, non-symbol, node reset, MV-4 cannot tell definition box from entry box), `_open`'s unoffered-kind report unpinned). | L2a `progress.md:125, :174`; `task-14-review.md:51-66` (items 2, 3, 5) | SEAM |
| D-46 | Section titles: a type's section is titled `type:<id>` unless its `title(T)` hook returns another word id ("an opening titled by its kind"); `ValueDisplay<T>` with `unit` `length|area|angle|none` for a room's area and a dimension's value; `ActionProperty` for a door's Flip hinge. The 2a panel was built against the box stand-in and never exercised these. | 2a spec P3 `:384-410` | SEAM |
| D-47 | A16 conformance for a kit with `ComponentRegistry` names: `jetcad.*` reserved; type ids `architecture.wall|opening|separator|room|dimension|box` (today `floor_planner.*`); tool ids `architecture.<tool>`; keys `architecture.<kind>.<variant>@N`. | umbrella A7 (`:290`), A16 (`:427-447`) | BEH |
| D-48 | Closed lists that must be derived from kits (umbrella Facts, nine of them): `isParametricObject`, `ObjectGrips._of`, `FloorPlanTool` enum, palette `_entries` and letters, `kShellLetterKeys`, per-tool strings, the Selection panel's per-type sections, `pickedColors`, `exportOmitOwners`, the room inputs (`parametric/room_inputs.dart:96-148, :296-314`). Each is a kit-supplied hook now; the kit tests are their regression net. | umbrella `:84-100` | SEAM |

## 1F. Demo app and parity touching sub-project 3

| # | Item | Source | Kind |
|---|------|--------|------|
| D-49 | **`apps/architecture_demo` replacing `apps/floor_planner` is assigned to different sub-projects in different places.** The umbrella's A13 puts "the demos" in sub-project 4; A11 says the demo is renamed from `apps/floor_planner`. STATUS.md:454-456 says the human wants to be told when `apps/architecture_demo` runs on the new packages "(the end of sub-project 3)". Your brief for sub-project 3 includes it. Settle which spec owns it and the app's 88 document/export tests (list 2, apps). | umbrella `:347-362, :388-406`; STATUS.md:454-456; `dsp/ledgers/2026-10-13-kit-contract/progress.md:85` | BEH |
| D-50 | Host-API differences the 2b note carries to sub-project 4 (no SP3 content): `userCamera` on the design canvas; the deliberate differences list. Included only so SP3's spec does not claim them. | 2bR:715-738, :791 | BEH |

---------------------------------------------------------------------------------------------------------------

# LIST 2: test-port coverage of `packages/jet_cad_floor_plan/test` (165 files, 1674 test cases)

Status: PORTED (a note, ledger or port header names the destination), PARTLY (named in part, the remainder says where),
NOT PORTED (a note says so, with a reason), NOT MENTIONED (no note, ledger, plan or header names the file).
Class (only for files not fully ported): ARCH architecture-domain, REST restaurant/service-domain (SP4),
PARITY host-guide/parity/app (SP4), OTHER. "Tests" is the file's case count; for PARTLY the Note names what is left.

## 2A. All 165 files, in path order

| File | Tests | Status | Class | Left for SP3 (cases) | Where / note |
|---|---|---|---|---|---|
| `box_test.dart` | 6 | NOT MENTIONED | ARCH | 6 | no note, ledger or port header names it |
| `canvas_ui_test.dart` | 3 | PORTED | - |  | canvas/canvas_ui_test.dart, panels/page_panel_theme_test.dart |
| `colors/color_picker_test.dart` | 14 | PARTLY | ARCH | 1 | CP1,CP3-CP6b over the box kit -> panels/colour_row_test.dart; CP7-CP12 (2b) -> same; LEFT: CP2 (tint pixels, room); CP1 lost its separator line |
| `colors/table_color_export_test.dart` | 8 | PARTLY | ARCH | 3 | -> export/unit_colour_export_test.dart (8); LEFT: R-16 EX2, EX3, EX5 room/tint lines, premise key list "R" |
| `dark_canvas_test.dart` | 5 | PORTED | - |  | canvas/dark_canvas_test.dart |
| `decimal_separator_test.dart` | 6 | NOT MENTIONED | ARCH | 6 | room area and dimension value echoes of the page separator (Q0-S1..E3b) |
| `delete_components_test.dart` | 3 | NOT MENTIONED | ARCH | 3 | P-1..P-3 all use walls, doors (cascade) beside a table; the engine feature is generic, the fixture is not |
| `dimension_attach_points_test.dart` | 3 | NOT MENTIONED | ARCH | 3 | no note, ledger or port header names it; dimension type |
| `dimension_attach_test.dart` | 9 | NOT MENTIONED | ARCH | 9 | no note, ledger or port header names it; dimension type |
| `dimension_follow_test.dart` | 4 | NOT MENTIONED | ARCH | 4 | no note, ledger or port header names it; dimension type |
| `dimension_format_test.dart` | 4 | NOT MENTIONED | ARCH | 4 | no note, ledger or port header names it; dimension type |
| `dimension_fuzz_test.dart` | 1 | NOT MENTIONED | ARCH | 1 | no note, ledger or port header names it; dimension type |
| `dimension_grips_test.dart` | 6 | NOT MENTIONED | ARCH | 6 | no note, ledger or port header names it; dimension type |
| `dimension_layout_test.dart` | 6 | NOT MENTIONED | ARCH | 6 | no note, ledger or port header names it; dimension type |
| `dimension_object_test.dart` | 11 | NOT MENTIONED | ARCH | 11 | no note, ledger or port header names it; dimension type |
| `dimension_paint_test.dart` | 3 | NOT MENTIONED | ARCH | 3 | no note, ledger or port header names it; dimension type |
| `dimension_panel_test.dart` | 6 | NOT MENTIONED | ARCH | 6 | no note, ledger or port header names it; dimension type |
| `dimension_params_test.dart` | 1 | NOT MENTIONED | ARCH | 1 | no note, ledger or port header names it; dimension type |
| `dimension_rotate_test.dart` | 5 | NOT MENTIONED | ARCH | 5 | no note, ledger or port header names it; dimension type |
| `dimension_shell_test.dart` | 3 | NOT MENTIONED | ARCH | 3 | no note, ledger or port header names it; dimension type |
| `dimension_tool_test.dart` | 11 | NOT MENTIONED | ARCH | 11 | no note, ledger or port header names it; dimension type |
| `example_test.dart` | 1 | NOT PORTED | ARCH | 1 | old example (planner + furniture asset) replaced by the new 2a example_test.dart (ED-8); the architecture kit needs its own example |
| `fonts_register_test.dart` | 1 | PORTED | - |  | fonts/fonts_register_test.dart |
| `host/against_wall_rotate_test.dart` | 3 | NOT PORTED | ARCH | 3 | 2b results note l.348: "sub-project 3 (walls)" |
| `host/band_view_test.dart` | 8 | PORTED | - |  | -> service/view/band_view_test.dart |
| `host/barrel_test.dart` | 7 | PORTED | - |  | -> barrel_test.dart (2a) with 2b halves |
| `host/bars_test.dart` | 39 | PORTED | - |  | -> editor_bar_test, service_bar_test, editor_modes_test, plan_service_view_test |
| `host/camera_test.dart` | 24 | PARTLY | PARITY |  | CM4-CM6,CM15 -> controller/camera_test.dart; table half -> unit_camera_test; fit -> canvas_camera_test; id-scan finds no twin for CM8-CM14,CM16,CR1-CR6,UC1,UC2 (15 tests); no note rules on them |
| `host/chrome_change_test.dart` | 11 | PORTED | - |  | F-2,F-3 -> editor_modes_test.dart (16); F-1 ported in the 2b follow-ups (7f86f1ef) |
| `host/controller_test.dart` | 39 | PARTLY | PARITY |  | C1-C20,CF1-CF5,CD1 ported (2a+2b); id-scan finds no twin for CZ1-CZ6 (fit to tables; CZ1 premise has "the room named 7"), CV1-CV3 (visibility/unplaced), CS1-CS4 (schema versions: dropped by A8/decision 9?); no note rules |
| `host/design_changes_test.dart` | 19 | PORTED | - |  | -> controller/plan_change_test, unit_changes_test |
| `host/editor_capabilities_test.dart` | 11 | PORTED | - |  | redesigned as controller/permissions_test.dart (EC1 "sixteen tools" is the closed list that dies) |
| `host/editor_panels_test.dart` | 19 | PARTLY | ARCH | 5 | generic + table parts -> editor/editor_options_test.dart; LEFT: T5-f (wall thickness read-only, justification disabled, door flips absent), the Wall-tool settings case, "a table, a wall, a room and a dimension each selectable ... sections read-only", R-3 changeLayer/reshape wall thickness, R-4 Door tool width (5 tests; 2b results l.304, task-20-brief:530, task-10-report:71) |
| `host/editor_select_test.dart` | 17 | PORTED | - |  | -> editor/units_only_select_test.dart (13); the wall of the fixture is a root-level line; M-H43c, gatesChanged, R-1 third case "2a ground" (task-8-brief 2b:1132) |
| `host/editor_tools_review_test.dart` | 20 | PARTLY | ARCH | 3 | RV6,RV8,RV9,O23,R-2 (2a Task 20), RV1-RV3 and the table cases (2b); LEFT, named in no note: "a symbol against the north wall: M under full, then mirror false", O13a (dimension end grip, snapping false), O13b (window slide grip, snapping false) |
| `host/editor_tools_test.dart` | 19 | PARTLY | OTHER |  | T4-e,T4-j,T4-f,T4-g,K3 -> editor_options_test (2a Task 20 brief:531), table cases 2b; M-H47 "W, one click (a wall part-way)" substituted by a polyline; no note lists T4-h/T4-c/T4-d/T4-i |
| `host/floor_plan_theme_test.dart` | 27 | PORTED | - |  | -> theme/plan_theme_test, theme_service_mode_test, editor_theme_test |
| `host/host_text_keys_test.dart` | 5 | PORTED | - |  | -> shortcuts/host_text_keys_test, service_keys_test |
| `host/inspector_test.dart` | 6 | PORTED | - |  | -> editor/unit_inspector_test.dart (2b) |
| `host/keyboard_focus_test.dart` | 18 | PARTLY | ARCH | 4 | service cases + T6-c,RP1,RP12 -> service_keys_test / plan_shortcuts_test; wall-bearing cases ("Wall tool chosen by the host", DS2 wall selected, DS5 wall part-way, R-3 RP5) have no note |
| `host/new_plan_separator_test.dart` | 10 | PARTLY | ARCH | 1 | NS1-NS10 ported; LEFT: NS3 room-label assertion (task-8-brief:46, editor_separator_test.dart:8) |
| `host/non_finite_table_test.dart` | 2 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `host/page_flows_test.dart` | 24 | PORTED | PARITY |  | PF2-PF24 (2a Task 19); PF5,PF6 -> editor_bar_test; PF1 (export choice through the barrel) id not found |
| `host/seams_test.dart` | 3 | NOT PORTED | OTHER |  | SM1-SM3 (host selection handed in, fit requests, framing): 2b results says "2a's", 2a never mentions it; no ruling by either |
| `host/service_layout_test.dart` | 11 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `host/status_caption_test.dart` | 4 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `host/table_color_test.dart` | 9 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `host/table_data_test.dart` | 12 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `host/table_detail_test.dart` | 17 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `host/table_fit_test.dart` | 4 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `host/table_groups_context_test.dart` | 2 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `host/table_groups_controller_test.dart` | 16 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `host/table_groups_gesture_test.dart` | 14 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `host/table_groups_look_test.dart` | 8 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `host/table_groups_toolbar_test.dart` | 7 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `host/table_overlay_test.dart` | 33 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `host/theme_canvas_test.dart` | 14 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `host/theme_service_test.dart` | 13 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `host/view_events_test.dart` | 18 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `host/view_palette_test.dart` | 4 | PORTED | - |  | -> canvas/view_palette_test.dart (final fix wave; had no ruling) |
| `host/view_replace_test.dart` | 3 | NOT PORTED | - |  | VR1-VR3: ruling R-11a (sessions own the systems) |
| `host/view_test.dart` | 49 | PORTED | - |  | -> editor_service_view_test (48), editor_view_test (2a) |
| `hover_removal_test.dart` | 2 | PORTED | - |  | panels/hover_removal_test.dart (HR1 2a, HR2 2b) |
| `intersection_snap_test.dart` | 1 | NOT MENTIONED | ARCH | 1 | phantom intersection snap on the moved wall group of the sample plan |
| `invariants/band_allocation_test.dart` | 1 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `invariants/pick_allocation_test.dart` | 3 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `invariants/theme_colours_test.dart` | 3 | PORTED | - |  | -> invariants/theme_colours_test.dart (2a) |
| `l10n/determinism_test.dart` | 1 | NOT PORTED | ARCH | 1 | DT1 (rooms, tables, dimensions): 2a Task 9 brief:65 "-> sub-project 3" |
| `l10n/l10n_test.dart` | 9 | PORTED | - |  | -> l10n/l10n_test.dart |
| `l10n/leak_test.dart` | 2 | PARTLY | ARCH | 1 | LK1 -> editor/editor_words_test.dart; LEFT: LK2 (every sample-plan object selected in Turkish) |
| `l10n/numbered_names_test.dart` | 3 | PARTLY | ARCH | 1 | NN1,NN2 -> layer_page_words_test.dart, numbered_names_test.dart; LEFT: NN3 (sample plan names its rooms in its language; roomName) |
| `l10n/overflow_test.dart` | 2 | PARTLY | ARCH | 1 | OV-$code design parts -> editor_words_test.dart; LEFT: OV-H (each root object of the sample plan selected; panel never overflows) |
| `l10n/panel_words_test.dart` | 2 | PARTLY | ARCH | 2 | PW1/PW2 Page panel and layers -> l10n/layer_page_words_test.dart; LEFT: the Wall section words/fields/edits (Duvar, Kalinlik, wall-thickness, Dicke) |
| `l10n/shell_words_test.dart` | 2 | PORTED | - |  | -> editor_words_test.dart (2a) + service halves (2b) |
| `l10n/stale_error_test.dart` | 2 | PORTED | - |  | -> l10n/stale_error_test.dart |
| `l10n/symbol_words_test.dart` | 4 | PORTED | - |  | -> symbols/gallery_model_test.dart (SN3 Task 17, SN4 GM-9) |
| `l10n/value_words_test.dart` | 4 | PARTLY | ARCH | 1 | VW1 + VW2-VW4 unit halves ported; LEFT: VW3 "the Room notice in each language" |
| `layers/attach_layer_test.dart` | 2 | NOT MENTIONED | ARCH | 2 | layer rules for live objects (dimension attach, opening host, tool creation layer) |
| `layers/opening_host_layer_test.dart` | 6 | NOT MENTIONED | ARCH | 6 | layer rules for live objects (dimension attach, opening host, tool creation layer) |
| `layers/tools_layer_test.dart` | 10 | NOT MENTIONED | ARCH | 10 | layer rules for live objects (dimension attach, opening host, tool creation layer) |
| `new_document_test.dart` | 6 | NOT MENTIONED | ARCH | 6 | ND1-ND3: empty doc, mm, DASHED at handle 6 (the separator linetype), page literal; new_plan.dart:3-4 dropped DASHED for SP3; the page/units lines are generic |
| `opening_cost_test.dart` | 1 | NOT MENTIONED | ARCH | 1 | no note, ledger or port header names it; opening type |
| `opening_cut_test.dart` | 6 | NOT MENTIONED | ARCH | 6 | no note, ledger or port header names it; opening type |
| `opening_end_drag_test.dart` | 10 | NOT MENTIONED | ARCH | 10 | no note, ledger or port header names it; opening type |
| `opening_geometry_test.dart` | 9 | NOT MENTIONED | ARCH | 9 | no note, ledger or port header names it; opening type |
| `opening_grips_test.dart` | 10 | NOT MENTIONED | ARCH | 10 | no note, ledger or port header names it; opening type |
| `opening_kink_test.dart` | 7 | NOT MENTIONED | ARCH | 7 | no note, ledger or port header names it; opening type |
| `opening_object_test.dart` | 5 | NOT MENTIONED | ARCH | 5 | no note, ledger or port header names it; opening type |
| `opening_obstacle_test.dart` | 8 | NOT MENTIONED | ARCH | 8 | no note, ledger or port header names it; opening type |
| `opening_paint_test.dart` | 1 | NOT MENTIONED | ARCH | 1 | no note, ledger or port header names it; opening type |
| `opening_panel_test.dart` | 5 | NOT MENTIONED | ARCH | 5 | no note, ledger or port header names it; opening type |
| `opening_params_test.dart` | 1 | NOT MENTIONED | ARCH | 1 | no note, ledger or port header names it; opening type |
| `opening_symbol_test.dart` | 4 | NOT MENTIONED | ARCH | 4 | no note, ledger or port header names it; opening type |
| `opening_tool_test.dart` | 18 | NOT MENTIONED | ARCH | 18 | no note, ledger or port header names it; opening type |
| `package_assets_test.dart` | 7 | PARTLY | ARCH | 2 | PA1,PA5,PA6,PA8 -> fonts/plan_assets_test.dart (2a Task 9); LEFT: PA2,PA3 (furniture library from a package-key bundle: ARCH), PA4 (export font from a package-key bundle: OTHER) |
| `page_panel_test.dart` | 7 | PORTED | - |  | panels/page_panel_test.dart |
| `planner_box_test.dart` | 6 | NOT MENTIONED | ARCH | 6 | no note, ledger or port header names it |
| `planner_draw_test.dart` | 28 | PORTED | - |  | canvas_draw / palette_draw / page_scale_field / editor_view tests; A12b trimmed to the generic 7 rows (box, wall, door, window, gap, room, separator, dimension rows leave: palette_draw_test.dart:242) |
| `planner_grips_test.dart` | 5 | NOT MENTIONED | OTHER |  | A1-A4 stretch/F3/cmd+Z mid-drag through the shell on the sample plan; generic behaviour, no destination |
| `planner_palette_test.dart` | 7 | PORTED | - |  | canvas/canvas_palette_test.dart (9) |
| `planner_shell_test.dart` | 13 | PARTLY | ARCH | 3 | 4 canvas cases -> canvas/canvas_layout_test.dart; bar/status cases -> editor_view_test (2a Task 20); LEFT: click selects a wall, cmd+Z undoes a Delete (wall), ctrl+Z after deleting two walls (sample flat) |
| `room_color_test.dart` | 9 | NOT MENTIONED | ARCH | 9 | no note, ledger or port header names it; room type |
| `room_cost_test.dart` | 3 | NOT MENTIONED | ARCH | 3 | no note, ledger or port header names it; room type |
| `room_diagnostics_test.dart` | 4 | NOT MENTIONED | ARCH | 4 | no note, ledger or port header names it; room type |
| `room_dissolve_test.dart` | 9 | NOT MENTIONED | ARCH | 9 | no note, ledger or port header names it; room type |
| `room_follow_test.dart` | 9 | NOT MENTIONED | ARCH | 9 | no note, ledger or port header names it; room type |
| `room_grips_test.dart` | 8 | NOT MENTIONED | ARCH | 8 | no note, ledger or port header names it; room type |
| `room_inputs_test.dart` | 3 | NOT MENTIONED | ARCH | 3 | no note, ledger or port header names it; room type |
| `room_label_test.dart` | 4 | NOT MENTIONED | ARCH | 4 | no note, ledger or port header names it; room type |
| `room_localise_test.dart` | 3 | NOT MENTIONED | ARCH | 3 | no note, ledger or port header names it; room type |
| `room_object_test.dart` | 10 | NOT MENTIONED | ARCH | 10 | no note, ledger or port header names it; room type |
| `room_paint_test.dart` | 6 | NOT MENTIONED | ARCH | 6 | no note, ledger or port header names it; room type |
| `room_panel_test.dart` | 8 | NOT MENTIONED | ARCH | 8 | no note, ledger or port header names it; room type |
| `room_tie_test.dart` | 3 | NOT MENTIONED | ARCH | 3 | no note, ledger or port header names it; room type |
| `room_tint_test.dart` | 1 | NOT MENTIONED | ARCH | 1 | no note, ledger or port header names it; room type |
| `room_tool_test.dart` | 12 | NOT MENTIONED | ARCH | 12 | no note, ledger or port header names it; room type |
| `room_trace_test.dart` | 8 | NOT MENTIONED | ARCH | 8 | no note, ledger or port header names it; room type |
| `selection_panel_test.dart` | 30 | PARTLY | ARCH | 11 | SE1-SE18 over the box stand-in -> panels/selection_panel_test.dart, selection_page_test.dart; LEFT: WS1-WS11 (Wall section, 11 tests; WS7 Box variant ported) |
| `separator_test.dart` | 4 | NOT MENTIONED | ARCH | 4 | no note, ledger or port header names it |
| `separator_tool_test.dart` | 6 | NOT MENTIONED | ARCH | 6 | no note, ledger or port header names it |
| `service/service_events_test.dart` | 16 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `service/service_options_test.dart` | 6 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `service/table_band_test.dart` | 17 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `service/table_fill_test.dart` | 12 | PARTLY | ARCH | 2 | -> service/paint/unit_fill_test.dart (11) and unit_fill_view_test (2); LEFT: R-16 room and tint lines in TF1, TF7; TF3 count 5 -> 6 |
| `service/table_focus_painter_test.dart` | 8 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `service/table_group_painter_test.dart` | 15 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `service/table_groups_test.dart` | 15 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `service/table_picker_test.dart` | 15 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `service/table_select_tool_test.dart` | 17 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `service/table_status_painter_test.dart` | 12 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `service/table_theme_painter_test.dart` | 25 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `startup_plan_test.dart` | 14 | NOT MENTIONED | ARCH | 14 | the sample flat (9 walls, 7 doors, 8 windows, rooms, dimensions, furniture); 2b fixtures replaced it with root-level lines (unit_editor_fixture.dart:9) |
| `symbols/furniture_library_test.dart` | 34 | NOT MENTIONED | ARCH | 34 | 41 symbols, committed bytes = built, D9 against-wall set and families (tags: must become attachTo/family), 14s dining tables v2 servable |
| `symbols/seating_test.dart` | 12 | PARTLY | ARCH | 5 | SE1-SE3 -> kit unit_component_test; SE4-SE7 -> kit validator rules (V1d, V10a); LEFT, named nowhere: SE8-SE10b (placement copies seats with the definition, v1->v2 dining table copy), SE11 (furniture dining tables v2 servable) |
| `symbols/symbol_box_test.dart` | 22 | PARTLY | ARCH | 3 | -> symbols/symbol_box_test.dart (3 fixture keys for 4 asset keys); LEFT: :321-339 and :391-410 (3 tests pinning the furniture asset literal boxes; 2a Task 14 brief:49) |
| `symbols/symbol_component_test.dart` | 13 | PARTLY | OTHER |  | SC1-SC6 -> kit model/symbol_component_test.dart; SC7-SC12 (typed save/load, kept-raw, registerAppComponents, diagnostics/regeneration, purge, definition removal) not named by SP1 port header |
| `symbols/symbol_end_to_end_test.dart` | 2 | NOT MENTIONED | ARCH | 2 | a real furniture symbol (bed.double) through placer, painter, pick, snap, extents, codec; never named |
| `symbols/symbol_ghost_test.dart` | 13 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `symbols/symbol_library_test.dart` | 26 | PORTED | - |  | -> kit model/symbol_library_test.dart by the rule map (kit-contract task-4-brief:25); L5 inverted, R03d replaced by structured family |
| `symbols/symbol_move_test.dart` | 6 | NOT MENTIONED | ARCH | 6 | MV1-MV6 move-along-the-face (09c D8); 2a Task 14 brief: moves with the wall-face provider |
| `symbols/symbol_panel_test.dart` | 18 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `symbols/symbol_place_tool_test.dart` | 54 | PARTLY | ARCH | 15 | ranges 78-99,184-222,225-366,435-1366,1738-1804 -> tools/plan_symbol_tool_test.dart; LEFT: 1368-1740 the group "the wall attachment (spec 09c D6)" (15 tests) |
| `symbols/symbol_placer_test.dart` | 33 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `symbols/symbol_search_test.dart` | 16 | PARTLY | ARCH | 12 | -> symbols/gallery_model_test.dart (4 + new GM tests); LEFT: :82-164, :191-267 (12 tests pinning the 41-symbol asset; 2a Task 13 brief:57); "mixed-case tag" retired (F-1) |
| `symbols/symbol_section_test.dart` | 20 | PARTLY | - |  | -> panels/symbol_section_test.dart (+2b table halves SW1,SW4,SW6,SW9); SS9 -> Task 13; SW7 no counterpart; LEFT in 2a: nothing arch except _isOrthonormal copy |
| `symbols/symbol_sources_test.dart` | 5 | PORTED | - |  | LS1 -> kit merge_test.dart; LS2,LS3 replaced by S-4,S-2; LS5 gone (2a Task 13 brief:57) |
| `symbols/wall_attach_property_test.dart` | 2 | NOT MENTIONED | ARCH | 2 | WP1-WP2; same |
| `symbols/wall_attach_test.dart` | 23 | NOT MENTIONED | ARCH | 23 | WA1-WA18, WK0-WK4; 2a Task 14 brief: moves with the wall-face provider |
| `symbols/wall_faces_test.dart` | 9 | NOT MENTIONED | ARCH | 9 | WF1-WF9; same |
| `tables/table_data_test.dart` | 12 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `tables/table_index_test.dart` | 7 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `tables/table_label_system_test.dart` | 8 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `tables/table_label_test.dart` | 7 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `tables/table_numbers_test.dart` | 8 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `tables/table_placement_test.dart` | 7 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `tables/table_section_test.dart` | 11 | PORTED | - |  | ported in 2a/2b (see their port tables) |
| `touch_tools_test.dart` | 2 | PARTLY | ARCH | 1 | TD2 -> canvas/touch_tools_test.dart; LEFT: TD1 (Room tool, M-14t-17) |
| `wall_bands_test.dart` | 2 | NOT MENTIONED | ARCH | 2 | no note, ledger or port header names it; wall type |
| `wall_geometry_test.dart` | 21 | NOT MENTIONED | ARCH | 21 | no note, ledger or port header names it; wall type |
| `wall_grips_test.dart` | 10 | NOT MENTIONED | ARCH | 10 | no note, ledger or port header names it; wall type |
| `wall_paint_test.dart` | 1 | NOT MENTIONED | ARCH | 1 | no note, ledger or port header names it; wall type |
| `wall_params_test.dart` | 5 | NOT MENTIONED | ARCH | 5 | no note, ledger or port header names it; wall type |
| `wall_regen_test.dart` | 13 | NOT MENTIONED | ARCH | 13 | no note, ledger or port header names it; wall type |
| `wall_tool_test.dart` | 21 | NOT MENTIONED | ARCH | 21 | no note, ledger or port header names it; wall type |
| `widget_theme_test.dart` | 7 | NOT MENTIONED | OTHER |  | M-DT-15..18: symbol-cell thumbnails, page swatches, layer swatch, whole-shell theme follow, ServiceView status; no destination named anywhere |
## 2B. `apps/floor_planner/test` (24 files, 203 tests)

`document_separator_test.dart` is the app's own and is not the plan library's `l10n/document_separator_test.dart` (ported from `host/new_plan_separator_test.dart`); the notes' hits on that basename are the plan's file.

| File | Tests | Status | Class | Note |
|---|---|---|---|---|
| `apps/floor_planner/test/app_words_test.dart` | 4 | NOT MENTIONED | PARITY | the app's document/export lifecycle; no note, ledger or plan cites it |
| `apps/floor_planner/test/document_commands_test.dart` | 16 | NOT MENTIONED | PARITY | the app's document/export lifecycle; no note, ledger or plan cites it |
| `apps/floor_planner/test/document_exit_test.dart` | 8 | NOT MENTIONED | PARITY | the app's document/export lifecycle; no note, ledger or plan cites it |
| `apps/floor_planner/test/document_files_kind_test.dart` | 7 | NOT MENTIONED | PARITY | the app's document/export lifecycle; no note, ledger or plan cites it |
| `apps/floor_planner/test/document_files_sources_test.dart` | 3 | NOT MENTIONED | PARITY | the app's document/export lifecycle; no note, ledger or plan cites it |
| `apps/floor_planner/test/document_files_test.dart` | 8 | NOT MENTIONED | PARITY | the app's document/export lifecycle; no note, ledger or plan cites it |
| `apps/floor_planner/test/document_host_test.dart` | 7 | NOT MENTIONED | PARITY | the app's document/export lifecycle; no note, ledger or plan cites it |
| `apps/floor_planner/test/document_open_test.dart` | 6 | NOT MENTIONED | PARITY | the app's document/export lifecycle; no note, ledger or plan cites it |
| `apps/floor_planner/test/document_replace_test.dart` | 11 | NOT MENTIONED | PARITY | the app's document/export lifecycle; no note, ledger or plan cites it |
| `apps/floor_planner/test/document_save_test.dart` | 7 | NOT MENTIONED | PARITY | the app's document/export lifecycle; no note, ledger or plan cites it |
| `apps/floor_planner/test/document_separator_test.dart` | 3 | NOT MENTIONED | PARITY | the app's document/export lifecycle; no note, ledger or plan cites it |
| `apps/floor_planner/test/document_settle_test.dart` | 8 | NOT MENTIONED | PARITY | the app's document/export lifecycle; no note, ledger or plan cites it |
| `apps/floor_planner/test/export/export_end_to_end_test.dart` | 1 | NOT MENTIONED | PARITY | the app's document/export lifecycle; no note, ledger or plan cites it |
| `apps/floor_planner/test/export/export_flow_test.dart` | 16 | NOT MENTIONED | PARITY | the app's document/export lifecycle; no note, ledger or plan cites it |
| `apps/floor_planner/test/export/export_font_test.dart` | 12 | PARTLY | PARITY | EF4,EF5,EF7,EF8 -> plan test/export/export_font_test.dart; EF1-EF3, EF9-EF12 are the app's (main(), pubspec), EF6 -> Task 9 |
| `apps/floor_planner/test/export/print_flow_test.dart` | 10 | NOT MENTIONED | PARITY | the app's document/export lifecycle; no note, ledger or plan cites it |
| `apps/floor_planner/test/layers/layer_panel_test.dart` | 26 | PORTED | - | -> plan test/panels/layer_panel_test.dart (25 of 26; 2aR:247) |
| `apps/floor_planner/test/layers/layer_picker_test.dart` | 13 | PARTLY | ARCH | -> panels/layer_picker_test.dart (11 of 13); LEFT: "in the app: below the Selection section's type section for a wall" (:352-401, wall + door tools: ARCH); "a move the document refuses is caught" retired (F-* tests, LP-7) |
| `apps/floor_planner/test/layers/layers_end_to_end_test.dart` | 1 | NOT MENTIONED | PARITY | end to end through the app |
| `apps/floor_planner/test/symbols/symbol_library_loader_test.dart` | 15 | NOT MENTIONED | PARITY | SL1-SL12 (SL9b/SL9c: the app reads furniture then restaurant, over both libraries); 2a built PlanSymbolLoader with new S- tests, never citing this file |
| `apps/floor_planner/test/symbols/symbol_palette_end_to_end_test.dart` | 1 | NOT MENTIONED | PARITY | end to end through the app |
| `apps/floor_planner/test/symbols/symbol_section_end_to_end_test.dart` | 1 | NOT MENTIONED | PARITY | end to end through the app |
| `apps/floor_planner/test/symbols/symbol_shell_test.dart` | 17 | NOT MENTIONED | ARCH | SS1-SS15 shell/tabs/gallery/loader/cache ownership (generic or app); SS16, SS17 wall-attach and opening-host rule in the shell (ARCH); 2a ported the package's symbol_panel_test, not this file |
| `apps/floor_planner/test/symbols/wall_attach_end_to_end_test.dart` | 2 | NOT MENTIONED | ARCH | WE1 (L of 100/240 mm walls at 30 degrees, double bed from the Symbols tab), WE2 (pre-09c plan byte-identical: dead premise, decision 9) |

## 2C. `packages/jet_cad_restaurant_symbols/test` (3 files, 28 tests) and `apps/restaurant_demo/test`

| File | Tests | Status | Class | Note |
|---|---|---|---|---|
| `restaurant_library_test.dart` | 23 | NOT MENTIONED by 2a/2b (SP4's kit) | REST (SP4) | RL1-RL15; RL15 merges the **furniture** and restaurant libraries (needs D-11 first) |
| `symbol_section_catalog_test.dart` | 3 | NOT MENTIONED | REST + ARCH | loops over `[furniture(), restaurant()]`: SC1 (no servable entry has a size family), SC2 (against-wall base point on box centre x), SC3 (corner booth turned 37 then mirrored); the furniture half is SP3's (D-16) |
| `symbol_names_test.dart` | 2 | NOT MENTIONED | REST + ARCH | `SNL` loops furniture and restaurant (de/tr names, none empty, none shared); imports `jet_cad_floor_plan/src/symbols/furniture_names.dart`; the furniture row is SP3's; SP1's conformance test (A16) is the new home of the rule |
| `apps/restaurant_demo/test/*` (badges, demo, events, host_chrome, look, sample_plans: 6 files) | not counted | NOT MENTIONED | REST/PARITY (SP4) | uses the host barrel, furniture and restaurant sources, two sample plans |

## 2D. Hints from an id-scan (old test id looked up as a word in `jet_cad_2d_plan/test` and `jet_cad_2d_kit/test`)

False "missing" is expected where a port renamed its ids (`table_picker` TP7b-TP14 became TPK*, so that one is a rename). These are **not** cleared by any note and not obviously renamed; the 2b lesson says check them:

- `host/camera_test.dart`: CM8-CM14, CM16, CR1-CR6, UC1, UC2 (15 of 24). Notes name CM4-CM6, CM15 (2a) and the table half (5, 2b). Classes: PARITY (host guide section 4, camera). Possibly covered by 2a's `C-cam1`/`CM*` new tests under other names.
- `host/controller_test.dart`: CZ1-CZ6 (frame the tables; CZ1 premise holds "the room named 7"), CV1-CV3 (visibility/unplaced tables recipe), CS1-CS4 (schema versions 8/10/11 and the layout format). CS* are probably retired by decision 9 and the manifest (A8), but no note says so. 2bR:344-345 lists the source files left "without a 2b destination" and does not name `controller_test`; its row says 10 ported "of 21 in the file" for C2, C10, C14, C16-C20, CF3, CF4 only.
- `host/page_flows_test.dart` PF1 (the export choice through the barrel alone).
- `host/editor_tools_test.dart` T4-h, T4-i (partly), T4-c, T4-d; `host/editor_capabilities_test.dart` EC1, EC3, EC4, EC6, EC7, PC8 (the profile type was redesigned, `permissions_test.dart`); `host/editor_panels_test.dart` T5-f, T5-h x2.
- `symbols/symbol_component_test.dart` SC2-SC5, SC9-SC12 (SC1-SC6 are claimed by SP1 as "SC1-SC6" under other ids; SC7-SC12 are the codec/purge/diagnostics cases).
- `l10n/symbol_words_test.dart` SN3, SN4 (briefs say ported: SN3 Task 17, SN4 as GM-9).

---------------------------------------------------------------------------------------------------------------

# SUMMARY

## Counts, `packages/jet_cad_floor_plan/test` (165 files, 1674 cases)

| Class | Files | Cases in those files | Cases left for SP3 |
|---|---|---|---|
| PORTED (named in a note, header or ledger) | 65 | 789 | 0 |
| ARCH, NOT MENTIONED anywhere | 68 | 477 | 477 |
| ARCH, NOT PORTED (a note says so) | 3 | 5 | 5 (`against_wall_rotate`, `determinism` DT1, `example_test`) |
| ARCH, PARTLY ported | 20 | 270 | about 77 named cases + 5 files of removed lines (R-16 etc.) |
| PARITY (SP4), PARTLY or hint | 2 + 1 | 87 | 28 hints (camera 15, controller 13) |
| OTHER, nobody owns | 5 | 47 | `planner_grips` 5, `widget_theme` 7, `seams` 3 (NOT PORTED), part of `editor_tools`, `symbol_component` SC7-SC12 |
| Other statuses, no SP3 content | 2 | 23 | `symbol_section_test` PARTLY (2b table halves, SW7 no counterpart), `view_replace_test` NOT PORTED (R-11a) |
| REST (SP4) | 0 in this package | | 28 in `jet_cad_restaurant_symbols` |

Architecture-domain breakdown of the 68 + 3 files with nothing ported: wall 7 files / 73 cases, opening 13 / 85, room 16 / 100, dimension 14 / 73, separator 2 / 10, box 2 / 12, shell and layer-rule files 12 / 53 (`planner_grips` excluded: OTHER), furniture and wall-attach 6 / 76, `against_wall_rotate` 1 / 3.
Total architecture-domain cases still to land in SP3: about 559 of 1674 (33 percent), plus the R-16 lines.

`apps/floor_planner/test` (24 files, 203 cases): 1 PORTED (26 cases), 1 PARTLY ARCH (13), 1 PARTLY PARITY (12), 2 NOT MENTIONED ARCH (19: wall-attach e2e, symbol shell), 19 NOT MENTIONED PARITY/app (133). `jet_cad_restaurant_symbols/test`: 28 cases, SP4.

## List 1 counts

50 items; kind tags (an item may carry two): PT 23, TL 7, SEAM 12, BEH 8, DOC 4.

## Top surprises (a spec author would likely miss)

1. **R-16's `hasLength(5)` is a placeholder**: `unit_fill_test.dart:535` must go back to 6, and the zone fixture's walled room `7` and `controller_test` CZ1's "not the TEXT or the room named 7" depend on rooms (D-36, D-38).
2. **The furniture library contains servable tables.** `seating_test` SE8-SE11 (seat copy on placement, v1 to v2 dining table copy, furniture dining tables v2 and servable) are named by no sub-project. The architecture kit's catalog must emit `UnitComponent`s, or restaurant service mode loses the dining tables (D-17).
3. **Tag-based furniture tests cannot keep "assertions unchanged"**: `against-wall` and `family:` tags became structured `attachTo`/`family` (A5, SP1 K2). The D9 against-wall set test, "behaviour tags come last", and the pre-09c fixture tests need a ruling before the port (D-11).
4. **Two contract gaps flagged for SP3 by the 2a final review are still open** (`PlanServices.isLocked/allows/settings Listenable`; `PropertySectionBuilder` without a handle). The six types are written against the contract as it stands; changing the typedef later breaks every kit (D-40, D-41).
5. **The apps' symbol tests were never in any port list.** `wall_attach_end_to_end` WE1/WE2 and `symbol_shell_test` SS16/SS17 (wall faces and opening host rule at the shell level) belong with the provider, and WE2's premise is dead (D-04).
6. **`layers/*_test.dart` (18 cases)**, `decimal_separator_test` (6), `delete_components_test` (3), `startup_plan_test` (14), `new_document_test` (6: DASHED at handle 6) and `intersection_snap_test` are architecture-domain but sit in no brief because they are not named after a type (D-28, D-29, D-32..D-34).
7. **Generic tests nobody owns**: `widget_theme_test` (7), `planner_grips_test` (5), `seams_test` (3, 2b says "2a's", 2a never mentions it), SC7-SC12 of `symbol_component_test`.
8. **Demo ownership conflict**: your brief and STATUS.md:454-456 put `apps/architecture_demo` at the end of SP3; the umbrella's A13 puts "the demos" in SP4. The app also carries 133 untouched cases (document lifecycle, export and print flows) that exercise the new packages' file and export callbacks (D-49).
9. **Palette letters and closed lists**: the box, wall, door, window, gap, room, separator and dimension rows were dropped from `A12b`; the shell letter guard now derives from kits. W is the Wall tool's letter and was replaced by B in ported SE11-SE16; nothing re-asserts W until SP3.
10. **Separator exports nothing** (`exportOmitOwners`): the kit must set `exported: false` for `architecture.separator`; I found no ported test pins it for both PDF and PNG (D-30).
11. **Camera and controller tests with no twin** (CM8-CM14, CM16, CR1-CR6, UC1/UC2, CZ1-CZ6, CV1-CV3, CS1-CS4) are unmentioned by any note: either dropped silently or renamed. They are SP4 parity rows and should be ruled before they repeat the "X is 2b's" failure.
12. **Dependency floors** (`jet_cad_2d: ^0.7.2`) still predate E1-E5 in the kit and plan pubspecs; the architecture kit's pubspec must not copy the stale floor (D-42).

## Could not determine

- Whether each id-scan hint in 2D is a rename or a real gap (needs a test-by-test read).
- Exact per-case remainders for the PARTLY files where no note lists the cases (`keyboard_focus` wall cases, `editor_tools` T4-h/c/d, `symbol_component` SC7-SC12, `seating` placement).
- The plan-level destinations of `new_document_test` ND1-ND3 page and units lines (generic) and `widget_theme_test` (generic).
