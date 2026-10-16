# 3a plan: task scopes (the controller's assignment to plan writers)

Worktree: /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit (all repo paths below are relative to it).
Scratch dir (this file's dir): /private/tmp/claude-501/-Users-ahmeturel-Projects-oss-jet-cad/ca29d59e-d5c8-4cfe-abd5-973c37552f1a/scratchpad/sp3/plan
Research (verify, do not trust): ../inventory.md (the contract and today's code, file:line), ../deferrals.md (Appendix A's D-rows and every old test file's port status), ../review-1.md (the spec review: many file:line facts about today's behaviour).

## How to write

Each body you write goes to `plan-parts/task-NN.md` (NN two digits) in the scratch dir and starts with `### Task N: <title> (spec <sections>)`. Follow the house style of the 2b plan `docs/superpowers/plans/2026-10-14-plan-library-2b.md` (read its Task 3 and Task 10 as examples): **Files**, **Interfaces** (Consumes / Produces, exact signatures from the 3a plan's "Shared interfaces"), **Appendix A rows closed** (the D-rows and old test files this task closes), then checkbox steps: failing test(s) with full code, the run command with the expected failure, implementation with full code for NEW code, the run command expecting pass, format, the task's gates (Global Constraints), Commit (explicit paths, message ending with the Co-Authored-By line), then the Mutation step (each named mutation: the exact edit, the test that goes red, `git checkout -- <file>`, `git diff --quiet -- <file>`).

**Ported code** (from `packages/jet_cad_floor_plan`, `apps/floor_planner`): give the exact source file(s) and line ranges, the destination path, and the exact list of adaptations (ids `floor_planner.<type>` → `ArchitectureTypes.<type>`; global-catalog reads (`isLiveObject`, `parametricCatalog`, `live_objects.dart`) → a `LiveTypeOf`; `FloorPlanStrings` → `KitWords` and the word ids of the plan's table; shell fields → `PlanServices.shared` accessors; `SymbolBox`/`placementTransform` imports → `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`), with code for every changed region. Do not paste hundreds of unchanged lines; do say "copy lines a-b unchanged".

**Ported tests:** list each source test file and the test names ported, state "assertions unchanged" (or name the spec C7 class of change that applies, with the exact rewritten line), and give the adaptation of fixtures and imports. **Place each case by spec C7's rule**: in the kit (`packages/jet_cad_2d_kit_architecture/test/...`) when every name it uses is the kit's, the contract's (`FakePlanServices` for tools and grips), the engine's or the Flutter layer's; in `packages/jet_cad_2d_integration/test/...` when it uses a plan-library name. A file that pumps `PlannerShell`, `SelectionPanel` or `PlannerView` today maps its cases to `PlanEditor`/`PlanCanvas`/`PlanPropertyPanel` in the integration package over `architectureController()`. Say for every file which cases go where. Before porting a test, check `packages/jet_cad_2d_plan/test/` and `packages/jet_cad_2d_kit/test/` so you never port a test 2a or 2b already ported.

**New tests** get an id (the task's prefix below) and the mutation that turns them red. Fixtures are not degenerate (walls off origin, not axis-aligned; a turned and mirrored group; a page not at 1:1).

**Interfaces.** Every NEW public or cross-task symbol must match the 3a plan's "Shared interfaces" exactly (`docs/superpowers/plans/2026-10-15-architecture-kit.md`). If one cannot work, do not silently change it: write `#### Interface problem` at the end of your task body with the evidence (file:line) and your proposed fix. A name you need that no shared interface gives and that another task must use: list it under `#### New shared name` with its exact signature.

**Read first:** CLAUDE.md; the 3a spec `docs/superpowers/specs/2026-10-15-architecture-kit-design.md` (binding; cite its sections); the 3a plan skeleton (header, Global Constraints, Review Focus, File structure, Shared interfaces); then the research files. Verify every claim about existing code by reading it; cite file:line. Today's code in `packages/jet_cad_floor_plan` is the oracle.

Do not edit any repository file. Write only your part files. Return a 5-line summary: tasks written, test-id prefixes used, any `#### Interface problem` or `#### New shared name` raised.

---

## Writer 1: Tasks 1-4 (the contract, part 1)

### Task 1: The symbol box family moves into the contract (spec C1.4) — ids SB-
- Move `SymbolBox`, `isOrthonormal`, `boxOfLeaves`, `boxOfEntry`, `servedTopOfEntry`, `boxOfDefinition`, `footprintOf` (`jet_cad_2d_plan/lib/src/symbols/symbol_box.dart`) and `placementTransform` (`symbol_placer.dart:59`) into `jet_cad_2d_kit/lib/src/model/symbol_box.dart`, unchanged; export from both barrels; check that every dependency they have is pure Dart and the contract's (if `placementTransform` drags plan-internal types, report an interface problem). Update every import in the plan library; delete `move_resolver.dart:18`'s and `symbol_section.dart:137`'s copies of `isOrthonormal`; fix the stale `WallFaces` doc comment (`symbol_box.dart:153`). The purity test of the contract (find it: `test/invariants/purity_test.dart`) must stay green.
- Move the test groups of these functions from the plan's `test/symbols/symbol_box_test.dart` (and the placer's for `placementTransform`) to the contract's tests, assertions unchanged; leave the rest.
- Appendix A: D-09, D-10.
- 2a spec amendment line? No: this is the contract spec's line (spec "Amendments to other specs"): add it to `docs/superpowers/specs/2026-10-13-kit-contract-design.md`'s Amendments section (create the section if it has none).

### Task 2: Object views for properties and sections; hidden fields (spec C1.1, C1.7) — ids PO-
- `PlanObject`, `DocumentPlanObject`, `PropertySpec.visible`, `bind(..., object:)`, `LengthProperty.range`, `TextDisplay`, `PropertyField.visible`; `PlanType.fieldsOf/commitField/sectionFor` over `DraftDocument` passing a `DocumentPlanObject`; `PlanSection` and the new `PropertySectionBuilder`; `PlanKit.validate` refuses a `TextDisplay` or a `range` in a tool's settings (`KitProblemCode.settingsNeedObject`); `visible` evaluated inside `bind` (guarded by the panel's existing boundary); an `ActionProperty` whose gate the host refuses is hidden (C1.7).
- The plan's panel (`panels/plan_property_panel.dart`): the `TextDisplay` row (read-only text, like `ValueDisplay`'s), hidden fields take no room, every exhaustive switch over `PropertySpec` gains the new kind; `section_boundary.dart` passes the services.
- Tests over the plan's test kits (`packages/jet_cad_2d_plan/test/support/`): a test type with a `TextDisplay` reading a child's text, a `range` from another object, a `visible` flag and an `ActionProperty` behind a refused gate. Review Focus 4: `PO-range` (a value past the range is refused, the field shows the stored value, no command, no diagnostic; a null range refuses every value).
- Amendment lines: 2a spec P3 (property specs and the section builder), contract spec (surface).

### Task 3: Words with parameters (spec C1.6) — ids KW-
- `KitText`, `fillText`, `placeholdersOf`; `KitWords.text` and `decimalSeparator`; `KitNamesWords(..., decimalSeparator:)`; the plan's `KitWords` (`controller/services.dart`) fill `decimalSeparator` from the current `PlanStrings`; `PlanKit.validate` and `validateHostWords` accept `text:<kit>.<id>`; the conformance test (`authoring/conformance.dart`) checks each locale's `text:` word has English's placeholder set (`KitProblemCode.placeholderMismatch`); `numberedNameIndex` in the contract, and the plan's `l10n/numbered_names.dart` rewritten over it (its existing tests stay green unchanged).
- Amendment lines: contract spec K4 (the namespace and placeholders), 2a spec P5 if it names the namespaces (check).

### Task 4: Tool notices (spec C1.2) — ids TN-
- `ToolNotice`; `GuardedTool.notice` forwarding (guarded: a throwing getter or `.value` → one `hookFailed`, then null); `PlanController.toolNotice` and `textOf`; `PlanEditor`'s status line keeps today's composition (label, ` — n selected`, ` — notice`), the notice put into words at read time. Tests with a test-kit tool implementing `ToolNotice`. Review Focus 2: `TN-relocale` (a language switch re-words a shown notice at once). Today's composition: `jet_cad_floor_plan/lib/src/planner_shell.dart:989-1011`.
- Appendix A: D-27's contract part.
- Amendment line: 2a spec P2 (the status line).

## Writer 2: Tasks 5-8 (the contract, part 2)

### Task 5: `prepare` and `build` (spec C1.3, C1.9) — ids PB-
- `PlanKit.prepare`; it runs on the constructor's plan without `json` and on `newPlan`, for every loaded kit in load order, outside history, before `clearHistory`, the save point and the unsettled baseline; never on `load` or an import; a throw → `hookFailed`, the plan opens. `PlanBuild`, `PlanController(build:)`, `newPlan(build:)`: the document made, prepared, the plan's parametric system installed, `build` run with the all-kits `KitWords`, then the history cleared and the save point taken (the built plan is clean and has nothing to undo); a throwing `build` leaves the empty plan with a `hookFailed`.
- Review Focus 1's plan half: `PB3-prepare-load` (a test kit's `prepare` adds a record on `newPlan`; a loaded file without it opens without it and `save()` gives back the same text; `dirty` stays false).
- D-28's generic half: `jet_cad_floor_plan/test/new_document_test.dart`'s page, unit, page-only and catalog-only lines: check the plan's `test/controller/new_plan*`/`plan_controller*` tests for twins; port the ones without a twin here (assertions unchanged). The DASHED lines go to Task 16.
- Amendment lines: 2a spec P4 (new plan, prepare; the controller's build).

### Task 6: Live objects as a kit sees them; the kit authors' test double (spec C1.5, C1.11) — ids LS-
- `PlanServices.liveTypeIdOf` (the plan's `KitServices`: null for a frozen object, one of a missing kit, anything else); `package:jet_cad_2d_kit/testing.dart` with `FakePlanServices` exactly as in "Shared interfaces"; every existing test-local fake of `PlanServices` in the kit and plan tests that breaks gains the member (replace with `FakePlanServices` where it is a drop-in).
- Review Focus 5's contract half: `LS-frozen` (a frozen wall-like test object: `liveTypeIdOf` null while the catalog's `typeIdOf` still answers its id).
- D-40: record in the task that `isLocked`, `allows` and a settings listenable are not added (spec C1.5).
- Amendment line: contract spec (surface).

### Task 7: Grip refusals; a frozen object's references locked (spec C1.8, C1.10) — ids GR-, FL-
- C1.8 (1): `GuardedGrips.drag`/`preview` (`kits/guard.dart:485-560`): an `ArgumentError` from the kit → no move for that event, the grips not marked failed, no diagnostic; anything else keeps 2a's rule. (2): `plan.select` executes the drop through `controller.execute`; `false` cancels the drag without an exception; `StateError` subclasses keep today's handling; retire `GuardedTool._failed`'s rethrow for grip drops (`guard.dart:301-321`). Record the `_first` catch-all's probe cost as a ruling in the task (D-43). Review Focus 3's contract half: `GR-drag-refuse`.
- C1.10: the lock set (`kits/locks.dart`) gains the live objects every frozen object references; an edit or delete → `PlanLocked` with the lock hint. Tests: `FL-edit`, `FL-delete` (a frozen test referrer's host).
- Amendment lines: 2a spec P4 (the grips row; the lock set).

### Task 8: Plan-library pins carried in (spec C1.12, C7's SE8) — ids PN-
- D-44: `PlanShortcuts(shortcuts: false)` remounted on the same controller does not reopen `idleKeys` (read `test/shortcuts/plan_shortcuts_test.dart:425-440` first).
- D-45: the attachment registry's provider kind read inside the guard and its guarded dispose; the move resolver's branches (a scaled instance, a non-symbol, a node reset, the definition box against the entry box); `_open`'s unoffered-kind report. Read `docs/superpowers/ledgers/2026-10-14-plan-library-2a/task-14-review.md:51-66` and `progress.md:125,174` for the exact items.
- SE8 (`jet_cad_floor_plan/test/symbols/seating_test.dart`'s placement-copies-the-definition-with-its-unit case): if 2b's placement tests already pin it, say which and close it; else port it over the plan's test unit kit.
- Each pin with a mutation.

## Writer 3: Tasks 9, 10 and 17 (the scaffold, the box, the separator's tool)

### Task 9: The scaffold (spec C2, C6) — ids SC-
- `packages/jet_cad_2d_kit_architecture`: pubspec (0.1.0, dependencies per Global Constraints, `flutter: assets:` for the furniture asset path once Task 23 adds it — declare it here only if a placeholder asset is needed; prefer Task 23), `analysis_options.yaml` (copied, committed once), LICENSE (as the plan's), README.md (a short stub; sub-project 4 writes the real one), CHANGELOG.md, the barrel, `src/kit.dart` (`architectureKit` with id `architecture`, version `0.1.0`, `names`, `prepare: ensureDashedLinetype`; types and tools empty, each type task adds its own), `src/ids.dart`, `src/live.dart`, `src/separator_linetype.dart` (today's `kDashedLinetypeRecord` and `ensureDashedLinetype`, `jet_cad_floor_plan/lib/src/parametric/separator.dart:120-149`, ported), the words (`src/words/`: every id of the plan's word table in English, German and Turkish, taken from today's `l10n/strings_{en,de,tr}.dart` (find the files); the `text:` templates with `{name}` placeholders; the choice words as separate ids), `example/main.dart` (a `PlanEditor` over `PlanController(kits: [architectureKit])`? NO: the example may not import the plan library (kit_deps): the example shows the kit's descriptor and `buildSampleFlat` over a bare engine document — decide what is lawful and useful, D-18) and its test.
- `packages/jet_cad_2d_integration`: pubspec (`publish_to: none`), `analysis_options.yaml` (committed once), README.md (what the package is, spec C6), `lib/jet_cad_2d_integration.dart` with `architectureController` and `planEditorApp` (`sampleFlatController` arrives in Task 25), a smoke test.
- Workspace: root `pubspec.yaml` members; `.github/workflows/ci.yml` jobs for both packages (read the plan library's job: `:45`, `:179`); `tool/ci/check_kit_deps.dart` sees the new kit (it finds kits by name: prove it with its output); `tool/ci` tests if a list of packages is pinned there.
- Tests: SC-conformance (the kit's words pass `PlanKit.validate` and the conformance check's locale completeness over the empty catalog until Task 23), SC-prepare (a new plan of `architectureController()` holds DASHED at handle 6; a loaded file without it does not — this is the kit half of Review Focus 1, the plan half is Task 5's).

### Task 10: The box (spec C3.1) — ids BX-
- Port `jet_cad_floor_plan/lib/src/parametric/box.dart`, `box_tool.dart` into `lib/src/box/`; `box_plan.dart` with `boxPlanType` (properties width, height: lengths with strict `> 0` in `write`) and `boxPlanTool` (letter B); add them to `architectureKit`.
- Port `test/box_test.dart` (kit) and `test/planner_box_test.dart` (integration, over `architectureController()`).
- Note: the plan's test kits already carry a `box.box` type ported from today's box (`packages/jet_cad_2d_plan/test/support/panel_kits.dart`); do not touch it.

### Task 17: The separator's grips, tool and plan type (spec C3.4) — ids SP-
- Depends on Task 16 (separator params and type, `RoomInputs`). Port `separator_grips.dart`, `separator_tool.dart` into `lib/src/separator/`; `separator_plan.dart`: `separatorPlanType` (`exported: false`; the type from Task 16), `separatorPlanTool` (letter S, band-trims through `roomInputsOf`), grips. Add to `architectureKit`. Port `test/separator_tool_test.dart`.
- D-28's DASHED lines (`new_document_test` ND1-ND3's "holds DASHED at handle 6") and "with registerAppComponents: a live page and live walls" (integration). Review Focus 1's kit half: `SP-dashed-open` (a file without the record: separators draw continuous, the file saves back byte-identical).
- D-30: the separator omitted from PDF and PNG export (integration, through the plan's export of a plan with a separator; read 2a Task 19's `unexported:` plumbing tests first).

## Writer 4: Tasks 11, 12 (the wall)

### Task 11: Wall geometry, bands and parameters (spec C3.2) — ids WL-
- Port `wall.dart` (params, `Justification`, `wallJoin`, `kWallMaxThickness`, `mitreLimit`, `kWallColor`, `WallType`), `wall_geometry.dart`, `wall_bands.dart` into `lib/src/wall/`; `wallBandsOf(PlanServices)`; `WallBands` keeps today's invalidation (the `changes` stream and explicit `invalidate()`, spec C2); its "live wall" test through a `LiveTypeOf`.
- Port `test/wall_params_test.dart`, `wall_geometry_test.dart`, `wall_bands_test.dart`, `wall_regen_test.dart` (each case by C7's rule; `wall_regen` runs through the engine's `ParametricSystem` over a catalog of the kit's wall type: kit).

### Task 12: The wall type, grips, tool and settings (spec C3.2) — ids WT-
- Port `wall_grips.dart`, `wall_tool.dart` (with `WallSettings`); `wall_plan.dart`: `wallPlanType` (properties thickness (strict `isWallThickness` in `write`), justification (choice left/centre/right)), grips, `wallPlanTool` (letter W, settings thickness and justification; the panel edits the tool's settings while it is active; the tool consults no lock or layer, today's). Add to `architectureKit`.
- Port `test/wall_grips_test.dart`, `wall_paint_test.dart`, `wall_tool_test.dart` (kit cases over `FakePlanServices`, the cases that pump the shell → integration).
- Review Focus 3's kit half: `WG-refuse-short` (a wall-end grip dragged below the join tolerance: the drag keeps the last accepted state; the drop commits it in one undo step), through the plan's `plan.select` in the integration package.

## Writer 5: Tasks 13-15 (the opening)

### Task 13: Opening geometry and cuts (spec C3.3) — ids OG-
- Port `opening.dart` (params, `OpeningKind`, `HingeEnd`, `SwingSide`, `OpeningType`, `isOpeningWidth`), `opening_geometry.dart` into `lib/src/opening/`; the wall's `generate` reads its openings as referrers (check where today's wall cut lives: `opening_geometry.dart:645-650`).
- Port `test/opening_params_test.dart`, `opening_geometry_test.dart`, `opening_cut_test.dart`, `opening_kink_test.dart`, `opening_obstacle_test.dart`, `opening_cost_test.dart`, `opening_symbol_test.dart` (C7's rule per case).

### Task 14: The opening type, grips and properties (spec C3.3, C1.10) — ids OT-
- Port `opening_grips.dart`; `opening_plan.dart`: `openingPlanType` (title by kind → `tool:architecture.{door,window,gap}`; width (strict `isOpeningWidth` in `write`), position (`range`: `[0, L]` from the host wall's centreline length through the `PlanObject`; null for a non-wall host), Flip hinge, Flip swing (`ActionProperty`, `visible` for doors, gate `reshape`)); grips (one slide grip, not moved or rotated). Add to `architectureKit`.
- Port `test/opening_object_test.dart`, `opening_grips_test.dart`, `opening_paint_test.dart`, `opening_end_drag_test.dart`, `opening_panel_test.dart` (panel cases → integration).
- Review Focus 4's kit half: `OT-panel-range` (integration: the position typed past the host's length shows the stored value; a non-wall host refuses every position).
- C1.10 for openings: `OT-frozen-host` (integration: a frozen opening's host wall cannot be edited or deleted; `PlanLocked`).

### Task 15: The opening tools (spec C3.3) — ids OL-
- Port `opening_tool.dart` (`OpeningSettings`, `OpeningTool(kind)`, `isUsableHost` reading the layer record, the live wall through `liveTypeIdOf`); `doorPlanTool` (D), `windowPlanTool` (N), `gapPlanTool` (G), each with its width setting; no keys (today's). Add to `architectureKit`.
- Port `test/opening_tool_test.dart` (kit cases over `FakePlanServices`; shell cases → integration).

## Writer 6: Tasks 16, 18, 19 (room tracing and the separator's parameters, the room)

### Task 16: Room tracing, inputs and label; the separator's parameters (spec C3.4, C3.5) — ids RR-
- Room tracing reads walls and separators by place, and the separator's tool and grips read `RoomInputs`: so the separator's parameters and type come here, its tool and grips in Task 17.
- Port `separator.dart` (`SeparatorParams`, `SeparatorType`: contributes places, drawn DASHED at lineweight 35 on `ReservedHandles.dashedLinetype`; `kDashedLinetypeRecord` already lives in the kit's `separator_linetype.dart`, Task 9) into `lib/src/separator/`; port `test/separator_test.dart` (kit).
- Port `room_trace.dart`, `room_inputs.dart` (`roomInputsOf(PlanServices)`; keeps today's invalidation), `room_label.dart` (`formatArea`) into `lib/src/room/`; "live" through a `LiveTypeOf`.
- Port `test/room_trace_test.dart`, `room_inputs_test.dart`, `room_label_test.dart`, `room_tie_test.dart`, `room_cost_test.dart`, `room_localise_test.dart` (C7's rule per case).

### Task 18: The room type, grips, properties and colour (spec C3.5) — ids RM-
- Port `room.dart` (params, tint constants, `RoomType`), `room_grips.dart`; `room_plan.dart`: `roomPlanType` (name `TextProperty` trimmed, empty refused; area `TextDisplay` as drawn, '—' without a TEXT child, memoised by `stateId`; `ColourTarget` over the room's palette name), grips (label grip, back to automatic in the aperture). Add to `architectureKit`.
- Port `test/room_object_test.dart`, `room_grips_test.dart`, `room_paint_test.dart`, `room_color_test.dart`, `room_tint_test.dart`, `room_diagnostics_test.dart`, `room_dissolve_test.dart`, `room_follow_test.dart`, `room_panel_test.dart` (panel cases → integration).
- D-31.

### Task 19: The room tool and its notice (spec C3.5, C1.2) — ids RT-
- Port `room_tool.dart` (`RoomOccupied`, `RoomTool`): implements `ToolNotice` with `KitText('text:architecture.room-occupied', {'name': ...})`; names a new room with `numberedNameIndex` over the kit's merged words' `text:architecture.room-name` patterns per locale; `roomPlanTool` (letter M). Add to `architectureKit`.
- Port `test/room_tool_test.dart` (kit cases; shell cases with the status line → integration, the composed string `'Room — Already a room: Room 1'` kept).
- Review Focus 2's kit half: `RT-notice-locale` (integration: a language switch re-words the notice). Review Focus 5's kit half: `RT-frozen-wall` (integration: the Room tool's preview and the room it creates both ignore a frozen wall).

## Writer 7: Tasks 20-22 (the dimension)

### Task 20: Dimension geometry and attachment (spec C3.6) — ids DG-
- Port `dimension_geometry.dart` (`WallSide`, `DimKind`, `DimEnd`, `AttachedEnd`, `FixedEnd`, constants, `layoutDimension`, `formatDimension`), `dimension_attach.dart` (`attachCandidates`, `decideEnd`; candidates through the index, live walls through a `LiveTypeOf`) into `lib/src/dimension/`.
- Port `test/dimension_params_test.dart`, `dimension_format_test.dart`, `dimension_layout_test.dart`, `dimension_attach_test.dart`, `dimension_attach_points_test.dart`, `dimension_follow_test.dart`, `dimension_rotate_test.dart`, `dimension_fuzz_test.dart` (C7's rule per case).

### Task 21: The dimension type, grips and properties (spec C3.6, C1.1) — ids DM-
- Port `dimension.dart`, `dimension_grips.dart`; `dimension_plan.dart`: `dimensionPlanType` (value `TextDisplay`, '—' without a TEXT child; kind choice; axes `TextDisplay` over `world`, degrees with `KitWords.decimalSeparator`, null when not turned; End 1, End 2 `TextDisplay` with `text:architecture.end-on-wall`/`end-start`/`end-end`/face words or `end-fixed`). Add to `architectureKit`.
- Port `test/dimension_object_test.dart`, `dimension_grips_test.dart`, `dimension_paint_test.dart`, `dimension_panel_test.dart` (panel cases → integration).

### Task 22: The dimension tool and its notice (spec C3.6, C1.2) — ids DT-
- Port `dimension_tool.dart` (`kAttachRingPixels`, `DimensionTool`, its Shift key): implements `ToolNotice` with the would-be value (`text:architecture.dimension-value`, the page's separator, today's); `dimensionPlanTool` (letter I). Add to `architectureKit`.
- Port `test/dimension_tool_test.dart` (TL5's composed `'Dimension — 4.69'` kept), `dimension_shell_test.dart` (integration).

## Writer 8: Tasks 23-25 (furniture, the provider, the sample)

### Task 23: The furniture library (spec C4) — ids FU-
- Rewrite `jet_cad_floor_plan/lib/src/symbols/furniture_catalog.dart` (41 symbols) in the authoring language (`jet_cad_2d_kit/lib/src/authoring/{catalog,shapes}.dart`); names (`furniture_names.dart`) en/de/tr; keys `architecture.<today's key>@1`, `armchair` → `architecture.armchair.single`; `attachTo: ['wall-face']` on exactly D9's set (30; `furniture_library_test.dart:352-358`); the six `family` fields; dining tables plain (no unit); categories `category:architecture/<cat>`. `tool/generate_furniture_library.dart` (writes the `.jetlib` and the snapshot), the committed asset and snapshot, `furnitureSource` (`bundledLibrary` over `kFurnitureAsset`), added to `architectureKit.symbols`; the pubspec's `flutter: assets:`.
- Port `test/symbols/furniture_library_test.dart` (C7: ids, tags to fields; the pre-09c fixture tests and the "14 new symbols … == 27" test not ported; the seating group dropped, decision 7), `package_assets_test.dart` PA2, PA3 (the kit's asset from a package-key bundle). The conformance test over the real catalog (D-47).

### Task 24: The wall-face provider (spec C5) — ids WF-
- Port `jet_cad_floor_plan/lib/src/symbols/wall_attach.dart` into `lib/src/attach/` (`wall_attach.dart`: `FaceSide`, `FaceRun`, `faceRunsOf`, `faceRunsAmong`, `attachToWall`; `wall_faces.dart`: `WallFaces`, `wallFacesOf`, compares `document.commands.stateId` besides today's bands generation (D-06); `wall_face_provider.dart`: `wallFaceProvider` implementing `AttachmentProvider` kind `wall-face` over `AttachmentQuery`, today's capture and keep distances (D-07), `mayRotate: false` rule (D-08), a wall on a hidden or locked layer offers no face). Add to `architectureKit.attachments`.
- Port `test/symbols/wall_faces_test.dart` (kit) and the kit-placeable cases of `wall_attach_test.dart`/`wall_attach_property_test.dart` if any (spec Appendix A: they call `placeSymbol` → integration, Task 28; say so).

### Task 25: The sample flat (spec C3.7) — ids SF-
- Port `startup_plan.dart` as `buildSampleFlat(DraftDocument, KitWords)` (without `prepareDocument`, its own system and `clearHistory`); room names via `text:architecture.sample-*`; the page with `words.decimalSeparator`; eight furniture fills stay fills.
- Port `test/startup_plan_test.dart` (14) in the kit: the test makes a document with a `ParametricSystem` over the kit's six types and runs `buildSampleFlat`; any case asserting history or the shell → integration over `sampleFlatController()` (added to the integration library here).

## Writer 9: Tasks 26-29 (integration rows and the gate)

### Task 26: Integration: the canvas, tools, layers and shell rows (spec C6, Appendix A) — ids IT-
- D-22 (TD1 Room tool), D-23 (`planner_shell_test`'s three sample-flat cases), D-26 (the palette's eight rows and letters W D N G M S I B; `palette_draw_test.dart:242`), D-29 (`layers/tools_layer_test` 10, `opening_host_layer_test` 6, `attach_layer_test` 2; apps/floor_planner `layers/layer_picker_test.dart:352-401`), D-33 (`delete_components_test` 3), D-34's `intersection_snap_test`, `planner_grips_test` A1-A4, `editor_panels_test`'s architecture remainder (T5-f, the Wall-tool settings case, "a table, a wall, a room and a dimension each selectable", R-3, R-4), `keyboard_focus_test`'s wall cases ("Wall tool chosen by the host", DS2, DS5, R-3 RP5), D-48 (each of the nine closed lists proven through the kit's hooks: say which test proves each).

### Task 27: Integration: panels and words (spec C6, Appendix A) — ids IP-
- D-20 (`selection_panel_test` WS1-WS11; `selection_page_test` SE13, SE15, SE16's Wall assertions restored), D-21 (CP2; CP1's separator line), D-24 (DT1, LK2, OV-H, PW1/PW2's Wall section words, NN3, VW3, NS3's room label), D-32 (`decimal_separator_test` 6), D-39, D-46 (titles by `title`, `ValueDisplay`/`TextDisplay`, `ActionProperty` exercised through the real kit).

### Task 28: Integration: the wall attachment end to end, R-16, the allocation invariant (spec C5, C6, Appendix A) — ids IA-
- D-01's integration parts (`wall_attach_test` 23, `wall_attach_property_test` 2, `symbol_move_test` 6), D-02 (`symbol_place_tool_test.dart:1368-1740`, 15), D-03 (`host/against_wall_rotate_test` 3), D-04 (WE1; SS16, SS17), D-05 (the north-wall mirror case, O13a, O13b), D-12 (`symbol_search_test.dart:82-164, 191-267`), D-13 (`symbol_box_test.dart:321-339, 391-410`), D-14 (`symbol_end_to_end_test` 2).
- R-16: D-35 (TF1, TF7), D-36 (TF3 back to `hasLength(6)`), D-37 (EX2, EX3, EX5, the premises' `R`), D-38 (the zone fixture's room named `7`; CZ1): carried as full copies of those tests in the integration package (the plan's own tests stay domain-free).
- The paint-allocation invariant over `sampleFlatController()` (port the plan's `canvas_paint_allocation_test` harness shape; `--enable-vmservice`).

### Task 29: The exit gate (spec "Exit gate") — no ids
- Every package's gate (Global Constraints), the dry-runs of `jet_cad_2d_kit`, `jet_cad_2d_plan`, `jet_cad_2d_kit_architecture` (0 warnings), `tool/ci` checks, `check_kit_deps`.
- The CHANGELOGs (contract, plan, kit); the kit's and the integration package's READMEs as stubs; the results note `docs/superpowers/notes/2026-10-15-architecture-kit-results.md` (ported tests table per old file, rulings, mutations, Appendix A closure table); STATUS.md; check that every amendment line of the spec's "Amendments to other specs" was written (umbrella's A13/A11 line too — write it here if no earlier task did).
- The plan's "Appendix A coverage" table is the checklist: every row closed.

---

## Planning rulings (added while writing; binding on every writer)

- **R-P1 (public libraries only).** `jet_cad_2d_integration` imports only public libraries (`implementation_imports`). So C7's rule reads: a ported case runs **in the kit** when it uses kit internals, the contract, the engine or the Flutter layer — and a plan-library *internal* helper it needs (e.g. `placeSymbol`, `symbol_placer.dart:169`) is reproduced as a **test-local fixture in the kit** (`test/support/place_entry.dart`: `placeEntry(doc, entry, {at, quarterTurns, mirrored, transform})`, `copyOfEntry`; a fixture change, A12). A case runs **in the integration package** only when it needs the plan library's public widgets or controller (`PlanCanvas`, `PlanEditor`, `PlanPropertyPanel`, `PlanController`, the public tools) and no kit internal. A case needing both a plan widget and a kit internal is rewritten to reach the kit internal through public behaviour (a ruling in the task) or split.
- **R-P2.** `furnitureSource` joins `architectureKit.symbols` in Task 24 with the provider (else `attachmentKindUnoffered` fires).
- **R-P3.** Kit test support shared across tasks: `test/support/place_entry.dart` (Task 23 creates it), `test/support/wall_attach_fixture.dart` (Task 24). Kit-internal readers with today's signatures plus a `LiveTypeOf` parameter: `faceRunsOf(doc, wall, LiveTypeOf live, {accept})`, `WallFaces(bands, live, {accept})`.
- **R-P4.** `PlanObject` gains `KitWords get words`; `DocumentPlanObject(document, handle, words)`; `PlanType.fieldsOf(document, group, words)` and `commitField(document, group, field, input, words)`. (Writer 7: `TextDisplay.read` needs the decimal separator and `text:` words.)
- **R-P5.** Dimension cases on the sample flat (`dimension_paint_test` RR1-RR3, `dimension_shell_test` SL1, SL2, TL9) are Task 26's.
- **R-P6.** The kit's test catalog: `test/support/wall_fixture.dart` (Task 11) gives `testCatalog()` and `installParametric(doc)` registering the kit's raw types in today's order; each type task appends its line. `wallsInDocument` (Task 13) gains `{required LiveTypeOf live}`. The kit pubspec lists `vector_math`; the integration pubspec lists `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_kit`, `vector_math` directly (Task 9).
- **R-P7.** A pure `PlanWords` (contract model: `word`, `maybe`, `text`, `decimalSeparator`); `KitWords implements PlanWords` adds `locale`. `PlanObject.words` is a `PlanWords`, so `properties.dart` stays pure (2a's P9 unchanged).
- **R-P8 (the wall/opening/room split).** Today's `wall.dart`/`wall_grips.dart` use `opening_geometry.dart` and `room_inputs.dart`. Split: Task 11's `WallType.generate` has **no opening cut** and **no place hooks** (`contributesPlace`/`placeBox`/`placeInput`); `wallsInView` and `wallsInDocument(doc, host, LiveTypeOf live, {moved})` live in `wall_geometry.dart` (Task 11). Task 12's `WallGrips({required LiveTypeOf live})` has no 08 D13 `_keptPut`/`_seated`. Task 13 adds the wall's cut; Task 14 adds `_keptPut` and `_seated`; Task 16 adds the wall's place hooks. Wall tests whose cases need openings or rooms move to the task that adds the code they need (say so in both tasks).
- **R-P9.** Integration test files that read `@internal` members of the plan library's public classes (`selection`, `grips`, `toolContext`, `servicesOf`, `toolFor`, `frozen`, `fill`) start with `// ignore_for_file: invalid_use_of_internal_member` (precedent: `apps/restaurant_demo/test`). A Global Constraint.
- **R-P10.** Sample-flat cases are Task 26's in the integration package over `sampleFlatController()`: besides R-P5, `room_cost_test` LZ3 and `room_paint_test`'s six cases.
- **R-P11.** The kit's pubspec lists `meta` and `vector_math` besides the Global Constraints' list.
- **R-P12.** `FakePlanServices.settingsOf` reads the map it was given at each call (no copy), so a test can change a tool's settings between events.
- **R-P13 (kit test catalog).** One file, `packages/jet_cad_2d_kit_architecture/test/support/catalog.dart`, created by Task 10 with `ParametricCatalog testCatalog()` and `ParametricSystem installParametric(DraftDocument doc)`; each type task appends its registration in today's order (`jet_cad_floor_plan/lib/src/parametric/catalog.dart:27-39`). Domain fixtures (`wall_fixture.dart`, `room_fixture.dart`, `opening_fixture.dart`) import and re-export it; no other names (`architectureCatalog`, `installArchitecture`) are used.
- **R-P14 (integration test support).** One shared rig, `packages/jet_cad_2d_integration/test/support/editor_rig.dart` (Task 9/10: `pumpEditor`, `globalOf`, `status`, `press`, `activeTool`, `pagePlanJson`, `kitCatalog`, `liveOf`); domain support files (`opening_support.dart`, `room_plans.dart`, ...) import it and add only domain fixtures, never a second copy of a rig helper. The reconcile pass merges duplicates.
- **R-P15 (Review Focus 3, corrected to today's).** A grip drag at a refused point: the preview keeps the last accepted state, nothing is reported; a **drop at the refused point commits nothing** (today: `GripDrag.command` asks the provider at the drop point, `grip_drag.dart:303-313`; wall grips return null there, `wall_grips.dart:60-63, 198`); the grips stay usable. C1.8(2) is done through one private refusal rule shared by `execute` and `plan.select`'s `GuardedTool` (Task 7), since `ToolContext.execute` is the Flutter layer's.
- **R-P16.** 2b's renames (`SeatingComponent` → `UnitComponent(kind: table, capacity: n)`, table → unit) count as C7 class 1 (ids). Task 5 does not port ND2 (the plan library has no page-less set-up).
- **R-P17.** R-P15 corrected: at a refused point today's preview is empty (`wall_grips.dart:137-138`, `grip_drag.dart:262-263`), not the last accepted state. `wallsInDocument(doc, host, LiveTypeOf live, {moved})` takes `live` positionally (R-P6's named form struck). The kit test helper for a live reader is `liveOf(doc, {frozen})` in `wall_fixture.dart`; Task 16's `liveIn` is replaced by it.
- **R-P18.** R-16 (spec C6): the table halves of TF1/TF3/TF7, EX2/EX3/EX5 and CZ1 stay in the plan's 2b tests (they use plan internals); the integration package carries their room lines over public routes (Task 28). Spec C6's "full copies" is amended by this ruling.
- **R-P19.** R14-1 accepted: the opening's position range decides "is the host a wall" by the engine's naming rule over a catalog the kit builds lazily from its own raw type registrations (a kit-internal list in `lib/src/`, not from `architectureKit`, so no import cycle). EG8-k/EG9-k/EG10-k's test-local grip dispatch follows DM-R1/R14-7 (a fixture standing in for the plan's dispatch).
