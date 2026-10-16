# Review 1: docs/superpowers/specs/2026-10-15-architecture-kit-design.md (revision 1)

Reviewer: independent, read-only, at `565b233b` (worktree `feat/architecture-kit`).
Paths: `kit/` = packages/jet_cad_2d_kit, `plan/` = packages/jet_cad_2d_plan,
`old/` = packages/jet_cad_floor_plan, `eng/` = packages/jet_cad_2d.

Counts: Blocking 2, Important 12, Minor 14.

---

## Blocking

### B1. C1.3 runs `prepare` after `load` and import: this reverses a pinned rule of today (R-3, byte identity)

- **Where:** C1.3 ("runs outside history on `newPlan`, after `load` and after an import"). The same wording is in Appendix D-28.
- **Problem:** today, Open deliberately does **not** add the DASHED record. Adding it changes the document outside history and breaks byte identity.
  - A foreign file without the record draws its separators continuous.
  - That ruling has a test and a named mutation. As written, C1.3 *is* that mutation: M-12a-18, "Open calls `ensureDashedLinetype`".
  - 3b ports DO3 under A12 ("ported tests keep assertions"), and DO3 goes red.
  - Worse, the controller takes `_savedState` after `_open`. A load that a prepare modifies therefore reads clean (`dirty == false`) while `save()` writes different bytes.
- **Evidence:**
  - docs/superpowers/specs/2026-09-30-document-lifecycle-design.md:465-469 (D8), :719-720 (S-20), :843-844 (M-12a-18), :893 (R-3).
  - apps/floor_planner/test/document_open_test.dart:217-247: DO3, "a file without the DASHED record opens without one and saves back".
  - old/lib/src/new_document.dart:4-5: "An opened file does neither ... gets no DASHED record".
  - plan/lib/src/controller/plan_controller.dart:671-686 (`load` → `_replace`) and :1601 (`_savedState` taken after `_open`).
- **Fix:**
  - `prepare` runs only on documents the plan library makes. That is the constructor without `json` (plan_controller.dart:286-288) and `newPlan`. It runs before the save point is taken, and before `clearHistory` or the unsettled baseline.
  - A loaded or imported plan is never changed. Record today's fallback: a plan without the record draws separators continuous.
  - If the author still wants it on load, the change of R-3 needs the human's word and a ruling for DO3 in 3b.

### B2. C3.7's input document cannot be obtained, and 3a's own C6 rows depend on it

- **Where:** C3.7: "It fills a document it is given, empty and already set up by the plan library (its measurer, its tables, every loaded kit's `prepare`) ... It regenerates through a `ParametricSystem` over the kit's own six types, installed for the build and disposed after it". It also says "how the demo hands the document to its controller is 3b's".
- **Problem:**
  - **No public source for that document.** The plan library exports no API that yields an empty, set-up document. `newPlanDocument` and the controller's `_register` are internal. A kit's `prepare` is run by nothing a host can call.
  - **The controller's own document cannot be used.** It already has the plan's `ParametricSystem` installed, so installing the kit's own throws `StateError('the dispatcher already has an expander')`. Even without that, the sample's commands would land in the controller's undo history, which is not today's behaviour: `startupPlan` clears history (old/lib/src/startup_plan.dart, `system.dispose(); doc.commands.clearHistory();`).
  - **3a cannot defer this to 3b.** 3a's own rows depend on the sample flat in a controller:
    - C6's fixture "the sample flat through C3.7";
    - D-23;
    - D-24's DT1, LK2 and OV-H;
    - `planner_grips_test` A1-A4;
    - the paint invariant "over the sample flat".
  - **Importing plan internals is not a way out.** An integration package importing `package:jet_cad_2d_plan/src/...` trips `implementation_imports` (in `package:lints/recommended.yaml`, which plan/analysis_options.yaml includes), so the exit gate's "analyse green" fails.
  - This is a missing plan-library seam, exactly what decision 4 (contract first) said C1 settles.
- **Evidence:**
  - plan/lib/jet_cad_2d_plan.dart: the export list has no `newPlanDocument`, no registration and no prepare runner. `encodePlan`/`decodePlan` are exported; `load(String)` is the only document entry.
  - eng/lib/src/parametric/parametric_system.dart:718-722 (`install` throws when an expander exists).
  - plan/lib/src/controller/new_plan.dart:23-33 (internal).
  - plan/lib/src/controller/plan_controller.dart:279-293 (the registration is private to the controller).
- **Fix:** add a C1 amendment (C1.9) that gives a host a plan-library-made blank document and a way to open a built one. For example:
  - `PlanController.newPlan({void Function(DraftDocument document)? build})`: the document is made, registered and prepared; `build` runs on it before the plan's system is installed; then history is cleared and the save point is set.
  - Or an exported `PlanController.blankDocument()` paired with `adopt(DraftDocument)`.

  Then state C3.7 against that API, pin it in the plan library's test kits, and keep 3b's part to the demo's UI only.

---

## Important

### I1. C1.2 replaces the status line where today appends to it; ported assertions fail

- **Where:** C1.2: "`PlanEditor`'s status line shows the active tool's notice when it is non-null, else today's label."
- **Problem:** today's line is the label, then the selection count when there is one, then ` — <notice>`.
  - Ported tests assert the composite string, for example `'Room — Already a room: Room 1'` and `'Dimension — 4.69'`. Under C1.2 they would read only the notice, so A12 fails.
- **Evidence:**
  - old/lib/src/planner_shell.dart:989-1011 (`return notice == null ? line : '$line — $notice'`).
  - old/test/room_tool_test.dart:281, 755, 762, 768.
  - old/test/dimension_tool_test.dart:1358 (TL5).
  - plan/lib/src/editor/plan_editor.dart:514-519.
- **Fix:** "the status line is today's label, then ` — n selected` when the selection is not empty, then ` — <notice>` when the active tool's notice is non-null."

### I2. C1.2: the guard decorator hides `ToolNotice`, and the notice string goes stale on a language change

- **Where:** C1.2.
- **Problem, the guard:** every kit tool reaches the plan as a `GuardedTool`, which extends `Tool` and wraps `inner`.
  - `activeTool is ToolNotice` is therefore always false.
  - "Reading it is guarded" does not say who forwards the listenable, or how a throwing `notice` getter or `.value` is reported.
- **Problem, the language:** today's room notice is a `RoomOccupied` value. It is put into words at status-line time with the current strings, so a language switch re-words it at once. C1.2's `String` "already in the UI language" freezes the old language until the next hover.
- **Problem, hosts without `PlanEditor`:** a host that composes `PlanCanvas` and panels itself gets no notice. The controller has no listenable for it.
- **Evidence:**
  - plan/lib/src/kits/guard.dart:253-276 (`GuardedTool extends Tool`, `inner`, `_forward`).
  - old/lib/src/planner_shell.dart:1007-1010 (`roomOccupied(occupied.name)` at read time).
  - old/lib/src/parametric/room_tool.dart:131, 184.
- **Fix:**
  - Specify that `GuardedTool` exposes `ValueListenable<String?>? get notice`: the inner's when it is a `ToolNotice`, read through the guard (a throw is one `hookFailed`, then null).
  - Add `PlanController.toolNotice` (a listenable) so the line is not `PlanEditor`-only.
  - Require the tool to rebuild its notice when `services.words.locale` changes, or make the notice a word id plus args that the editor fills at read time.

### I3. C1.1 and C1.7: how the object and `visible` reach a bound field is unspecified, and settings have no object at all

- **Where:** C1.1 (`TextDisplay.read(T, PlanObject)`, `LengthProperty.range(T, PlanObject)`) and C1.7 (`PropertySpec.visible: bool Function(T)?`).
- **Problem:**
  - **No path for the object.** The plan library uses specs only through `bind(Object? value, {wordId, onCommit})` and `PlanType.fieldsOf(CommandTarget, Handle)`, and neither carries an object.
  - **Tool settings have no object.** `PlanToolSettings.fieldsOf(value, store, toolId:)` has no handle. A `range` or a `TextDisplay` in a tool's settings, such as the opening tools' width, has no `PlanObject` to receive.
  - **`visible` cannot be read where the panel holds specs.** It takes a `T`, and the contract's own covariance note says such a member throws `TypeError` when read through `PropertySpec<Object?>`, which is how the panel holds specs.
  - **The panel switch.** `_row` and `_textOf` switch exhaustively over the sealed `PropertySpec`, so `TextDisplay` needs a field value type (a `String`?) and a row.
- **Evidence:**
  - kit/lib/src/kit/properties.dart:36-40 (covariance), :66-67 (`bind`), :326-347 (`PropertyField` has no `visible`).
  - kit/lib/src/kit/plan_type.dart:88-95.
  - kit/lib/src/kit/plan_tool.dart:26-32.
  - plan/lib/src/panels/plan_property_panel.dart:331-363 and :704-760.
- **Fix:** specify the following.
  - `bind(value, {wordId, onCommit, PlanObject? object})`.
  - `PlanType.fieldsOf` builds the `PlanObject` from (document, handle, `tree.accumulatedTransform`).
  - Settings bind with `object: null`. `validate` refuses a `TextDisplay`, or a spec with `range`, in a tool's settings.
  - `PropertyField` gains `bool visible` and the display's `String?`.
  - `visible` is evaluated inside `bind`, under the guard.

### I4. A kit cannot format numbers in the UI language

- **Where:** C1.1 (the axes line), C1.2 (the Dimension notice), C3.6, C3.7 ("the language's decimal separator").
- **Problem:**
  - Today's axes line prints its degrees with the UI language's separator.
  - The Dimension tool's notice, the room area and the dimension value follow the page's separator (Q0).
  - `KitWords` offers `word`, `maybe` and `locale` only. A kit cannot learn the separator of a host's own language class (`PlanStrings` subclasses), nor reuse the panel's `formatPanelNumber`. Each kit would hard-code en→`.`, de/tr→`,`, which is wrong for a host language.
- **Evidence:**
  - old/lib/src/selection_panel.dart:907-916 (`replaceAll('.', _strings.decimalSeparator)`).
  - old/test/decimal_separator_test.dart (Q0-E1..E3b).
  - kit/lib/src/kit/plan_services.dart:18-28.
  - plan/lib/src/l10n/number_text.dart (`formatPanelNumber`, plan-internal).
- **Fix:** add `KitWords.decimalSeparator`, or a `String number(double, {int decimals})` on `KitWords`, filled by the plan from the reported `PlanStrings`. Name it in C1.6.

### I5. C1.6 `text:` is refused for host words, and the template scheme cannot express `endOnWall`

- **Where:** C1.6, C2 "Words", Facts ("four of them with parameters").
- **Problem:**
  - **Host words.** `validateHostWords` refuses every namespace but the six, and the `PlanController` constructor throws `ArgumentError` on the first problem. So a host can never translate the architecture kit's messages into its own language. C1.6 changes only `PlanKit.validate`.
  - **`endOnWall`.** Its signature is `endOnWall(String wall, bool atStart, String side)`. Each language chooses its own word for start or end from a bool, and `{name}` substitution cannot choose a word.
  - **A fifth parameterised word.** `sampleBedroom(int n)` takes a parameter too.
  - **Words with no namespace.** `endFixed`, `leftFace`, `centreline`, `rightFace` and the sample room names are not tool, type or property words. They need `text:` as well, so C2's "for the four with parameters" is too narrow.
- **Evidence:**
  - kit/lib/src/kit/host_words.dart:17-41.
  - plan/lib/src/controller/plan_controller.dart:265-268.
  - old/lib/src/l10n/strings_en.dart:307-308 (`${atStart ? 'start' : 'end'}`), :437 (`sampleBedroom(int n)`).
- **Fix:**
  - `validateHostWords` accepts `text:<kit>.<id>`.
  - Specify that a choice is two text ids (`text:architecture.end.start` and `...end.end`) passed as an argument.
  - List every `text:` id the kit ships, sampleBedroom's `{n}` included.
  - Record the namespace as an amendment to the contract spec's K4 as well (kit-contract-design.md:182-190), not only to 2a/2b.

### I6. C1.5's named users are new behaviour, and `isLocked` collides with the controller's `isLocked`

- **Where:** C1.5's table (`isLocked`: "a wall tool neither joins nor snaps to a locked wall"; `allows`: "an opening tool's flip keys respect `mirror`") and C3.3 ("a host is a live wall on a visible, unlocked layer ... now through `typeIdOf` and `isLocked`").
- **Problem:**
  - **The wall tool.** Today it consults no lock and no layer rule: neither `wall_tool.dart` nor `wall_bands.dart` passes an `accept`.
  - **The opening tools.** They have no keys at all. The only architecture `onKey` is the Dimension tool's Shift handling.
  - So both users add behaviour while Purpose says "unchanged in behaviour" (A12), and C3 never lists them.
  - **Two meanings of "locked".** `isLocked` as defined ("a locked layer or a lock") differs from `PlanController.isLocked`, which covers the lock set only. The plan writer must guess which one the opening host rule and the provider (C5) call.
  - **Visibility is missing.** The opening host rule needs layer visibility too, and no member gives it. Today the kit reads the layer record itself.
- **Evidence:**
  - old/lib/src/parametric/wall_tool.dart and wall_bands.dart:68-100 (accept only from the opening tools).
  - old/lib/src/parametric/opening_tool.dart:447-450 (`isUsableHost` reads `tables.layers[objectLayer]`.visible/.locked).
  - grep `onKey` old/lib/src/parametric: dimension_tool.dart:193 only.
  - plan/lib/src/controller/plan_controller.dart:729-732.
- **Fix:**
  - Either drop `allows` and the wall-tool lock rule from 3a, or list them in C3 as behaviour changes with the human's word and new tests with mutations.
  - Define `isLocked` as the plan's lock set only, under a name that does not shadow the controller's, for example `isPlanLocked`.
  - The layer rule stays the kit's, read from the document as `isUsableHost` reads it today.

### I7. C1.8 does not say which failure path it changes, and a blanket `StateError` refusal swallows engine errors

- **Where:** C1.8.
- **Problem:** a kit grip can fail in two places.
  1. **Its `drag` or `preview` call.** Today `GuardedGrips` catches everything and blacks out the object's grips for the document's life. That is 2a's P4 row "grips: That object has none".
  2. **Executing the drop command.** `SelectTool` executes one command on pointer-up and rethrows; `GuardedTool._failed` rethrows a non-kit error for `plan.select`. This is the D-43 item C1.8 claims to retire.

  The spec's wording does not fit either path cleanly:
  - "The drag keeps its last accepted state" has no meaning at pointer-up, where the drag is already over.
  - Treating every `StateError` as a silent refusal at execute time would swallow `NonLiveWriteError` (a `StateError`, which should become `PlanLocked` plus `lockHint`, per 2a final-review I1) and `PartialMutationError` (a `StateError` the controller deliberately passes to its caller).
- **Evidence:**
  - plan/lib/src/kits/guard.dart:301-321 (`_failed`), :485-560 (`GuardedGrips`).
  - packages/jet_cad_2d_flutter/lib/src/select_tool.dart:534-550.
  - eng/lib/src/parametric/parametric_system.dart:428 (`NonLiveWriteError extends StateError`).
  - eng/lib/src/core/partial_mutation_error.dart:13.
  - plan/lib/src/controller/plan_controller.dart:790-800 (execute's doc).
  - docs/superpowers/ledgers/2026-10-14-plan-library-2a/final-rereview.md:137-143.
- **Fix:** split C1.8 in two.
  - (a) In `GuardedGrips.drag` and `preview`, an `ArgumentError` from the kit gives `null` or `[]` for that move, without marking the group failed and without a diagnostic.
  - (b) At execute, `plan.select` routes the drop through `controller.execute`. Its `false` (all refusals, `PlanLocked` included) cancels the drag without an exception; `StateError` subclasses keep today's handling.
  - Amend 2a P4's "grips" row accordingly, and name the mutation for each half.

### I8. C3.3: the frozen-opening acceptance is the author's, and its consequences go beyond "regenerates uncut"

- **Where:** C3.3's "A frozen opening (E2) ...", and Risks.
- **Problem:** the human did not approve this. Apart from the uncut wall drawn through the door's frozen leaf:
  - Frozen objects are in no survey, so deleting the host's wall does not cascade to the frozen opening. It is left referencing a dead handle.
  - Once the kit is fixed and the plan reloaded, that object is an `opening.orphan`.
  - Editing the host also rewrites geometry that the frozen object's drawing assumed.

  "Accepted and pinned" settles a visible defect without the human's word, where A14 needs that word.
- **Evidence:**
  - eng/lib/src/parametric/parametric_system.dart:680-697 (frozen: in no survey; a referrer sees no live object; cascade).
  - old/lib/src/parametric/opening.dart:107-123 (`references: [host]`, default `cascade`).
- **Fix:** put the choice to the human, with the cheap alternative named. For example, the lock check refuses an edit or delete of a wall that a frozen object references (lockHint, `PlanLocked`), pinned by a test. Or freeze the host with its frozen referrer. List the delete-cascade case in the pinned test either way.

### I9. C4 states the wrong against-the-wall count, so it would under-attach

- **Where:** Facts ("27 against the wall") and C4 ("the 27 symbols tagged `against-wall` carry `attachTo: ['wall-face']`").
- **Problem:** the committed asset has **30** symbols tagged `against-wall`:
  - kitchen.base ×4, sink, hob, fridge, dishwasher, washer;
  - bed.double ×3, bed.single ×3, nightstand, wardrobe ×3;
  - sofa.two, sofa.three, tv.unit;
  - bath ×4;
  - office.desk ×3, office.bookshelf.

  27 is the count of the pre-09c symbols. A plan writer following C4 literally drops three.
- **Evidence:**
  - old/assets/library/furniture.jetlib (counted: 30 entries whose tags hold `against-wall`; 11 without).
  - old/test/symbols/furniture_library_test.dart:352-358 (the D9 set), :427-440 (the 27 pre-09c).
- **Fix:** "the 30 symbols tagged `against-wall` (D9's list, `furniture_library_test` :352)". Better, name the rule "exactly D9's set" rather than a number.

### I10. Appendix A gives rows owners that cannot run there

Each item below is a wrong owner, with the evidence that rules it out:

- **D-45 → "3a C5".** These are plan-library tests:
  - the attachment registry's provider kind and guarded dispose;
  - `PlanMoveResolver`'s branches (plan/lib/src/tools/move_resolver.dart);
  - `_open`'s unoffered-kind report.

  C5 is the kit, and `kit_deps.dart:118-120` forbids the kit from naming `jet_cad_2d_plan`. Owner: C1 (plan-library tests).
- **D-01 `symbol_move_test` → "kit".** It tests the move resolver driven by `SelectTool`, now the plan's `PlanMoveResolver`. Owner: C6.
- **D-01 `wall_attach_test` and `wall_attach_property_test` → "kit".** Both call `placeSymbol` (old/test/symbols/wall_attach_test.dart:119; wall_attach_property_test.dart:243), the plan's placer, while C1.4 moves only `placementTransform`. Either rule a fixture change (instances built by hand) in C7 or put them in C6.
- **D-13 → "C4 (kit; C1.4 puts the box in the contract)".** The three cases use `boxOfEntry` and `placeSymbol` (old/test/symbols/symbol_box_test.dart:320-339, 391-410). C1.4 does not move `boxOfEntry` or `boxOfLeaves`. Move them too, or assign C6.
- **D-44 → "3a C1 (a pin test in the plan library)".** No C1 section carries it. Add C1.x or say where.
- **A.2, files of the six types "all 3a C3 in the kit".** These 14 files pump `PlannerShell`, `SelectionPanel` or `PlannerView` in some cases:
  - dimension_paint (3/3), dimension_tool (11/5);
  - opening_grips (10/7), opening_kink (7/7), opening_paint, opening_symbol, opening_tool (18/4);
  - room_grips (8/7), room_paint, room_tool (12/5);
  - separator_tool;
  - wall_grips (10/7), wall_paint, wall_tool (21/8).

  The list marks only the `_panel`, `_shell` and `planner_box` files C6.
  - The kit's own tool and grip tests need a `PlanServices` implementation. None is shared: only test-local fakes exist (kit/test/kit/plan_type_test.dart, plan/test/tools/*), and all of them break when C1.5 adds members.
  - Fix: list these files' C6 cases, and name the kit's test double (a contract `testing` library or kit test/support).

### I11. Appendix A and C7 miss rows

The rows below are missing:

- **`furniture_library_test`'s group 'seating (spec 14 S1-S3)'.** Its first two cases assert the five servable seat counts and die with decision 3 (old/test/symbols/furniture_library_test.dart:605-628). C7 drops only SE10, SE10b and SE11 "on the human's word". A14 allows "dropped" only with that word: ask, or list them as dropped with it.
- **'the 14 new symbols carry their names; the old keys stay'.** It asserts `entries.length - newNames.length == 27`, the pre-09c premise (:421-431). It is not in C7's premise-impossible list.
- **`selection_page_test` SE13, SE15, SE16.** They were ported with W→B and 'Wall'→'Box' (plan/test/panels/selection_page_test.dart:1-6). D-20 carries only WS1-WS11, so the source's Wall assertions are never restored.
- **`new_document_test`'s three registration cases.** "with registerAppComponents: a live page and live walls", plus the page-only and catalog-only cases (old/test/new_document_test.dart:98-113). D-28 names only ND1-ND3.

### I12. C1.6: moving `numbered_names` into the contract needs a new signature, which the spec does not give

- **Where:** C1.6, last bullet.
- **Problem:** today's function is typed over `PlanStrings` and counts over the plan's three built-in classes plus the current one. The contract cannot name `PlanStrings` (A1), and the kit counts over its `KitNames` locales, host words included.
  - "Moves ... unchanged" is impossible.
  - The plan writer must invent the shared form: patterns per locale, fold, and which locales count.
- **Evidence:**
  - plan/lib/src/l10n/numbered_names.dart:15-31.
  - old/lib/src/parametric/room_tool.dart:382-392.
- **Fix:** give the signature, for example `int? numberedNameIndex(String name, Iterable<String Function(int n)> patterns, {String Function(String) fold})`. State that the room tool passes one pattern per locale of its merged names, and the plan's layer panel one per built-in `PlanStrings` plus the current one.

---

## Minor

### M1. C1.4's move list is incomplete, and one citation is off

- **Problem:**
  - A third, public `isOrthonormal` copy exists in `plan/lib/src/tools/move_resolver.dart:18`, alongside the `symbol_section.dart:137` one.
  - `boxOfDefinition` depends on `boxOfLeaves`.
  - The plan's `symbol_box_test` also covers `boxOfEntry` and `servedTopOfEntry`, so "their tests move with them" splits files.
  - The citation `symbol_box.dart:18, 154, 170` points at `footprintOf` (170), which the text does not name.
- **Fix:** list every moved name (SymbolBox, boxOfLeaves, boxOfDefinition, footprintOf, placementTransform, isOrthonormal). Delete both plan copies. Say which test groups move.

### M2. A citation points at the call, not the definition

- **Problem:** C1.3 cites `ensureDashedLinetype` at `new_document.dart:22`. That line is the call; the definition is `old/lib/src/parametric/separator.dart:144-149`.

### M3. C1.3 does not name the constructor's plan, nor the order against the save point

- **Problem:** the controller's initial plan comes from plan_controller.dart:286-293 (`newPlanDocument`, or `decodePlan` of `json`). C1.3 does not say `prepare` runs there, nor that it runs before `_savedState` and `_unsettled` are taken.

### M4. How the shared caches go stale is unspecified

- **Problem:** today `WallBands` and `RoomInputs` invalidate on the `doc.changes` stream, which is asynchronous, plus explicit `invalidate()` calls from tools (old/lib/src/parametric/wall_bands.dart:22-46, 138-142; room_inputs.dart:210-239). C2 says only "a caching provider reads `stateId`".
- **Fix:** say whether all three caches key on `commands.stateId`, dropping the subscriptions and explicit invalidations, or keep today's. Mixing the two reads stale data within one task.

### M5. `PlanServices.typeIdOf` collides with the catalog's `typeIdOf`

- **Problem:** `ParametricCatalog.typeIdOf` answers a frozen object's type id (eng/lib/src/parametric/parametric_system.dart:672-675), and the plan calls it in its panels, gates and colour row. C1.5's `typeIdOf` answers null for a frozen object.
- **Fix:** rename it (`liveTypeIdOf`) or document the difference on both.

### M6. Labels the reader cannot resolve

- **Problem:** G1-G9 are defined nowhere in the spec; they come from the research inventory. "2a's D-41/D-43/D-06" names labels that do not exist in the 2a spec (grep: 0 hits); they are this spec's Appendix A numbers.
- **Fix:** define G1-G9 in C1, and write "Appendix A's D-41".

### M7. The VM-service flag is inconsistent

- **Problem:** Tests says the integration package runs the paint invariant over the sample flat. C6 says "with `--enable-vmservice` if it gains an allocation test". The exit gate lists `--enable-vmservice` only for `jet_cad_2d_plan`.
- **Fix:** make it unconditional for `jet_cad_2d_integration`.

### M8. C3.7 is loose on furniture and the decimal separator

- **Problem:**
  - "and furniture": today's sample furniture is hand-drawn fills, not library symbols (old/lib/src/startup_plan.dart header; the 8 furniture fills that `startup_plan_test` counts).
  - "the language's decimal separator": `KitWords` carries none (I4).
- **Fix:** say the fills stay fills. Say the sample's page takes its separator from the given document's existing page.

### M9. Amendment lines are missing for the umbrella and the contract spec

- **Problem:** decision 1 moves `apps/architecture_demo` from A13's sub-project 4 to 3b and touches A11, but the spec records amendments only in 2a/2b. C1.4 and C1.6 change K-spec ground: the contract's surface and K4's namespaces.
- **Fix:** add amendment lines to the umbrella and the contract spec too.

### M10. C6's shared fixtures cannot reuse the plan's test harnesses

- **Problem:** `design_harness`, `canvas_fixture` and `panel_kits` live under plan/test/support and are not importable from another package.
- **Fix:** say the integration package's `lib/` rebuilds what it needs, over the public API only.

### M11. Strict bounds and the non-wall host case are not stated

- **Problem:**
  - `isWallThickness` and `isOpeningWidth` are strict lower bounds (`> wallJoin.linear`, `> 4·wallJoin.linear`: old/lib/src/parametric/wall.dart:47-48, opening.dart:268-270). `LengthProperty.min` is inclusive.
  - Today an opening whose host is not a wall refuses every position (old/lib/src/selection_panel.dart:428-433). `range` has no "refuse all" form.
- **Fix:** say the writes throw for the strict bounds. Say what `range` returns for a non-wall host (null means refuse all, say), rather than a throw, which is `hookFailed`.

### M12. `TextDisplay`'s "null hides the line" changes today's '—'

- **Problem:** today the area and value lines show '—' when there is no TEXT child; only the axes line is omitted (old/lib/src/selection_panel.dart:948, 1385; old/test/dimension_panel_test.dart:171 asserts '—').
  - Today's `_areaOf` and `_valueOf` are memoised per document change (:825-868). The panel binds every field on each `_fieldOf`, so an O(entities) scan per bind repeats per field per rebuild.
- **Fix:** have the kit return '—' for the value and the area. Ask the kit to memoise by `stateId`.

### M13. `text:` and words: the C2 "about 45" count does not match its listed namespaces

- **Problem:** about 38 of the "about 45" are string members. The rest are property-spec words the kit must add (kind, axes, end-1, end-2, name). C2 lists only `tool:`, `type:` and `property:`, plus `text:` for four.
- **Fix:** an exact id table in the plan, or in this spec.

### M14. Facts calls the dining tables "carrying `jetcad.seating@2`"

- **Problem:** the tables are at version 2 and carry a `jetcad.seating` component. The component itself has no version 2.
- **Fix:** reword.
