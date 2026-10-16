# Pre-flight log, Tasks 7-12

Checked against the worktree at `c6bcce3e` (packages/jet_cad_floor_plan, jet_cad_2d_plan, jet_cad_2d_kit, jet_cad_2d, jet_cad_2d_flutter, tool/ci, .github/workflows/ci.yml) and the earlier tasks' parts (2, 3, 4, 5, 6) where a task consumes them. No repository file touched; no state-changing git command.

## Task 7 (grip refusals; frozen references locked)

| Check | Result | Fix (before → after) |
|---|---|---|
| `guard.dart` citations: GuardedGrips doc `:481-484`, class `:485-557`, GuardedTool `:253`, `_failed` `:301-321`, FailureBoundary `:585`, `_freeze` `:617-620` | all as claimed | — |
| `locks.dart`: `addBroken` `:125-129`, `objects` doc, `_first` `:289-309`, `_isRefusal` `:313-320` | as claimed; `_isRefusal` excludes ArgumentError, so an ArgumentError drop goes through `recoverRefused` (one `_probeAll`, no diagnostic when nothing breaks) then rethrows: GR-drop-refuse's "no diagnostic" holds | — |
| `plan_controller.dart`: `execute` `:797-817`, `_guardTool` `:837-846`, `typeOf` `:848-851`, `_open`'s boundary `:1523-1530`, `_buildService` `:1708-1720`; `planSelectToolId`, `kits.typeOf`, `catalog` in scope | as claimed | — |
| `service_session.dart` constructor and boundary `:61-99` | as claimed; new named param is optional, existing test call sites compile | — |
| Engine: `snapshotOf` (`component.dart:162`) returns `(String, Component)` pairs; `PermissionDeniedError` const ctor (`command.dart:72`); `DraftCommand` abstract members (`capability`, `label`, `apply`) for `_Refusing` | match the test code | — |
| A frozen referrer's partner: frozen objects are in no survey, so deleting the partner does not cascade (`parametric_system.dart:681-693`): FL-delete's M-FL-1 comment ("the partner goes") is right | ok | — |
| `box_kit.dart` (`SquareParams.partner`, `SquareType.references`, `cascade`), `tool_events.dart` (`useTestCamera`, `eventAt`), `c.locked`, `c.frozen`, `c.deleteSelection`, `undoDepth`, `diagnostics`, `activeTool` | exist with the signatures used | — |
| Snap at the drag points (aperture 10 px / 0.25 px/mm = 40 mm; every point ≥ 150 mm from the square's lines; grid snap off) | no snap interferes | — |
| `grip_refusal_test.dart` imports: `package:flutter/material.dart show Icons` is never used (the scene's kit has no tool) → `unused_import`, an **error** in the plan's `analysis_options.yaml` | **fixed** | `import 'package:flutter/material.dart' show Icons;` line → removed |
| L-11 mutation comment lines `:397, :404, :406-407, :423` | as claimed | — |
| Commit list covers every created/modified file; Commit before Mutation; mutations name a test that goes red | ok | — |
| `docs/kits.md` §10.8 row text; 2a spec `## Amendments` (made by Task 2); doc snippets test exists | ok | — |
| Risk (not fixed, runtime): `_freeze` now also locks a frozen object's referents; `throwing_kit.dart`'s type has `references` (orphan policy, `refs`). Step 5 runs `test/kits/` and Step 8 the whole package, so any existing case that freezes a referrer and then edits its referent shows there | noted | — |

## Task 8 (plan-library pins)

| Check | Result | Fix |
|---|---|---|
| `plan_shortcuts.dart:62-107`; KB-14 `:417-440`; `selectGates.idleKeys` (`plan_select_gates.dart:90`); `isDisposed` | as claimed; the remount order (new state's initState before the old one's dispose at finalizeTree) holds for a key change and for the `Column` re-parent in PN-remount | — |
| PN-remount walk-through with the new `_speakers` Expando (keys(1) → keys(2) → both → one → none) | expectations false/false/true/false/true all follow; KB-14 still passes | — |
| M-PN-2's stated red point ("after `both(second: false)`") | wrong: it goes red already after `keys(2)` (the old state's `_leave` finds the new one and, mutated, reopens the keys) | **fixed**: red point → "already after `keys(2)` … the `both(second: false)` check would go red the same way" |
| `attachment_registry.dart:27-44, 97-116`; M-PN-kind compiles (`final kind` assigned after the catch) | as claimed | — |
| `move_resolver.dart`: `n.parent != doc.rootHandle` `:56`, `isOrthonormal(t)` `:61`, two `_last = null`, one `_boxes.clear()` | as claimed (pre-Task 1 file; Task 1 removes the local `isOrthonormal` only) | — |
| PN-MV-nested/node/live against `Scene`, `entry`, `delta`, `boxOfDefinition`, `footprintOf` (`Aabb2.raw(left, front, right, back)`), `placeSymbol` (`symbol_placer.dart:169-219`, reuses the leaf-equal definition) | consistent; each mutation reaches its assertion | — |
| PN-open: `_reportUnofferedKinds` at `:1550` and `:2280`; libraries load once (`:366`); `attachmentKindUnoffered` is not plan-scoped, deduplicated by (kit, subject, code) | the new `test-edge` key is reported only by `_open` | — |
| SE8 source `seating_test.dart:18-33, 53-61, 132-150`; authoring API (`Catalog`, `CatalogSymbol(unit:, base:)`, `CatalogUnit`, `CatalogPolyline`); `registerKitComponents`; `UnitKinds.table`; `decodeString(registerComponents:)`; M-PN-SE8 target `symbol_placer.dart:131-134` | as claimed; assertions otherwise unchanged | — |
| SE8's component rename called "a ruling for the controller to confirm" | ruling R-P16 already settles it | **fixed**: sentence → "The component's rename is C7 class 1 by ruling R-P16 …" |
| D-45 coverage vs `task-14-review.md:51-66` | the review also named the missing-definition arm (`move_resolver.dart:57`); spec C1.12 lists only the four branches the task pins, so not owed | — |

## Task 9 (the scaffold)

| Check | Result | Fix |
|---|---|---|
| Today's words `strings_en.dart:61, 76-97, 190-250, 304-308, 416, 422-437`, `strings_de.dart` (420, 426-441), `strings_tr.dart` (414, 420-435) | every English, German and Turkish word in the task matches its source byte for byte (checked by reading each line); 55 ids, de/tr lists in en's order with 24 property and 17 text words each | — |
| `separator.dart:122-133` (`kDashedLinetypeRecord`), `:135-143` doc, `:144-149` (`ensureDashedLinetype`); `ReservedHandles.dashedLinetype == Handle(6)`; `LinetypeRecord ==`; `TableSection` `contains`/`[]`/`byName` | as claimed | — |
| Conformance with Task 3's text rule: German/Turkish words equal to English: only `Position`, `Name`, `Horizontal` and `{value}` | `architectureSameAsEnglish` covers them; but the plan decision called the `{value}` entry "harmless while conformance holds no `text:` word" — stale (Task 3 does hold them) | **fixed**: that sentence → "listed too, for `de` and `tr`: Task 3's conformance holds every English `text:` word … `wordUntranslated` included" |
| `PlanKit` (`plan_kit.dart:16-140`: `propertyIds`, `validate`), `conformance` (`:36-46`), `encodeLibrary` (`builder.dart:114`), `geometrySnapshot`/`encodeSnapshot` (`snapshot.dart:13, :82`), empty catalog builds (B7) | as claimed | — |
| Plan API: `kits.kits`, `missingKits`, `permissions` (`:2027`), `dirty`, `canUndo`, `save`, `load`, `newPlan(decimalSeparator:)`, `camera` (`:394`), `typeOf`; status key `status-text` (`plan_editor.dart:594-595`); `toolSelect` `Select`/`Seç`; palette keys `tool-<id>` | as claimed | — |
| Flutter layer: `InteractionLayer.tools` (`:90`), `Tool`, `ViewportTransform` exported; `ParametricType` const ctor and its 3 abstract members (`Inert`); `ParametricCatalog.register`/`registerComponents`; `Aabb2.empty()` | as claimed | — |
| CI: matrix entry indentation, `:49`, `:179`; SC16 `scripts_test.dart:333-347`, SC20b `:437-447` (SC20c relies on the integration entry not being last: it sits before `jet_cad_floor_plan`); `check_kit_deps.dart` picks packages by name, prints `N package(s) checked`; M-SC-deps message format `'$name: $path imports $dep'` | as claimed | — |
| Kit pubspec description length (155 chars, within pub's 60-180); LICENSE copy; CHANGELOG mentions 0.1.0; no `pubspec.lock` is committed | ok | — |
| Global "the kit names no `jet_cad_2d_plan` in any Dart file": `example/main.dart`'s comment named "(package jet_cad_2d_plan)" (the check parses directives only, but the constraint reads "names") | **fixed** | "(package jet_cad_2d_plan)" → "(the plan library's package)" |
| Test/mutation pairing: SC-ids, SC-words, SC-text, SC-conformance, SC-live, SC-example, SC-smoke, SC-prepare, SC20c; M-SC-1 … M-SC-deps each hit a named test | ok | — |
| Placeholders: de.dart / tr.dart are given as ordered word lists in prose, not code | deterministic (same 55 ids in en.dart's order); left as written | — |

## Task 10 (the box)

| Check | Result | Fix |
|---|---|---|
| `box.dart:1-124` (`componentTypeId` at `:10`, `BoxType` const, M-BX-4's `if (inside == null) continue;`), `box_tool.dart:1-47` | as claimed | — |
| `box_test.dart:1-91` (BT1-BT6; `:39` the id line, `:62` the catalog line, `installParametric` at `:48, :57, :69`) | as claimed; only BT1's id assertion changes (C7 class 1) | — |
| `planner_box_test.dart` (`:12-36` helpers, BX2 `:54-66`, BX3 `:71-78`, BX4 `:84-111` with `:100`, BX5 `:119-137`, BX6 `:143-149`); `box_rig.dart` (`boxKids` `:77-80`, `boxes` `:84-85`) | as claimed | — |
| PlanEditor parity: `chrome-right` (`plan_editor.dart:957`), meta+Z undo chords (`chords.dart:11`), `V` = plan.select, grid-snap-on precedent (`selection_panel_test.dart:38-43`) | as claimed | — |
| `PlanType` (`grips`, `hasColour`, `hasSection`, `exported`, `registerInto`), `PlanTool` (`letter`, `needs`, `settings`, `create`), `LengthProperty` bind/`_finite`/`_inRange`, `commitField` throwing what `write` throws | match BX-props/BX-kit | — |
| Imports of every new file; commit list; mutations M-BX-1..6 | ok | — |

## Task 11 (wall geometry, bands, parameters)

| Check | Result | Fix |
|---|---|---|
| `wall.dart:1-286`: imports `:4-6`, `:75`, place hooks `:172-189`, generate doc `:191-199`, `:203`, `_cut` `:215-239`, `diagnose` `:240-286`; no other reference to the deleted imports' names | as claimed | — |
| `wall_geometry.dart:1-623` (imports `:10-13`); `opening_geometry.dart` adapters `:600-616`, `:698-727` (today's `isLiveObject`/`liveObjectsOf` at `:714, :720`) | as claimed; the new `live(h) == ArchitectureTypes.wall` is the same naming rule as `typeIdOf` | — |
| `wall_bands.dart:1-177` (imports `:5-10`, class doc `:15-16`, `:26`, `:148-153`, dispose `:170-176`) | as claimed | — |
| Kit fixture: `wall_fixture.dart:1-301` (imports `:5-9`, `:171-176`, `:276-282`, `:295-298`) | as claimed | — |
| Ported tests: WP 5 (`:19-20` ids), WG 21, WB 2 (`WallBands()` at `:25, :76`, `doc` in scope), WR 13 (imports `:5, :8, :11`; WR9's `:497-501`, the only users of those imports); 44 with WL1-3 | counts and lines as claimed; `°` counts 15 and 12 | — |
| WL1-WL3: offsets sign convention (`(0, -t)` for right) puts `inBand` inside each band; stray on a nested group is no live object; `pumpEventQueue` from flutter_test; `PlanServices.shared` | consistent; each M-WL mutation reaches an assertion | — |

## Task 12 (wall type, grips, tool, settings)

| Check | Result | Fix |
|---|---|---|
| `wall_grips.dart:1-203` (imports `:5-9`, bullet `:27-33`, `:41`, `:51`, `:65`, `:69-128`, `:151-152`, `:158-159`, `_moved` `:198`) | as claimed | — |
| `wall_tool.dart:1-278` (`:4-5`, `:13-15`, `:67-75`, `:86-89`, `:212-216`, `:240-245`, `:263-264`) | as claimed | — |
| `wall_tool_test.dart`: WT1-WT9 `:213-546`, WT10-13 `:548-664`, WT14 `:666-702`, RF2 `:703-731`, WT15-18/20 `:733-859`, WT19 `:861-917`; `isPending` lines and `settings.value` lines as listed; `classify` lines `:142-143, :303, :342-343, :365-366, :544-545` | as claimed (21 cases) | — |
| `wall_grips_test.dart`: gripDoc `:36-56`, helpers `:58-131`, constants/addL `:134-153`, EG1-EG6 `:221-580`, the provider tails `:270-272, :334-371, :411-421, :549-579`, EG6 strays `:487-520` | as claimed | — |
| Plan library: settings keys `setting-<id>` and choice items `setting-<id>-<enum name>` (`plan_property_panel.dart:700-745`, `ChoiceProperty.segmentOf`), Enter hands focus back (`:683-685`), no tool cancel on canvas focus loss, `osnap-text`/`osnap off`, `'Select — 1 selected'`, `activeSelection`, `@internal grips` (`GripCache.grips`, `GripRef.key/grip/object`), `kPlanMaxScale == 100` (WT19's 100 px/mm is at the bound, not clamped), `PlanToolSettings.fieldsOf`, `ChoiceProperty` | as claimed | — |
| `TextInputAction`, `Offset` reach the tests through `flutter_test`'s exports (`test_text_input.dart:17`, `test_pointer.dart:16`) | ok | — |
| EG1's shell part calls today's file-local `globalOf(tester, view, <Vector2>)` (`:257`, `:262`); the rename rule "`tester, view,` → `tester, ctrl,`" would call the rig's `globalOf(tester, c, double x, double y)` with a Vector2: a compile error | **fixed** | added bullet: `globalOf(tester, view, <Vector2>)` → `globalAt(tester, ctrl, <Vector2>)` |
| Integration `wall_tool_test.dart` imports: A12-shell keeps the source's `package:flutter/gestures.dart` and `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart`, whose names were used only by the dropped harness and `directRig` → `unused_import` (an error) | **fixed** | added an exact import list and the list of top-level helpers copied vs taken from the rig/`wall_shell.dart`/the kit |
| Integration `wall_paint_test.dart` imports: A12-shell adds `package:jet_cad_2d_plan`, which WP5 never names → `unused_import` | **fixed** | "imports as A12-shell plus …" → "imports as A12-shell, **less** `jet_cad_2d_plan` …, plus …" (with flutter_test, jet_cad_2d, vector_math named) |
| Integration `wall_fixture.dart`: "the header below replaces the imports `:5-9`" while the header itself carries the three `dart:` imports of `:1-3` → duplicate imports | **fixed** | → "replaces the source's whole import block `:1-9` …; the appended `wall_shell.dart:8-51` part brings no import of its own" |
| WT-bands: the third click (`plan(1500, 70)`) continued the chain from A's end, so the "new wall" ran along A's own centreline (collinear stem; its commit may be refused, and the assertion then reads A's own end, passing vacuously) | **fixed** | `tool.cancel(ctx)` ends the chain; a new chain's first click at `plan(1500, 70)` (in A's band) and second at `plan(1500, 1500)`; premise `walls(doc)` has 2; the new wall's `start` on A's centreline (test name updated). M-WT-4 still reds on the generation check |
| WT3-k/WT9-k replay vs the shell (grid points, band joins, tick ends, settings sequence) | consistent with `classify`'s rules (`wall_geometry.dart:196-243`); M-WT-11, M-WT-12 reach them | — |
| WG-refuse-short: refused point (object snap or grid both resolve onto the start, length ≤ `wallJoin.linear`), accepted grid points away from any snap, `undoDepth`, diagnostics count; R-P15/R-P17 | consistent | — |
| Kit test files' imports (wall_tool_test, wall_grips_test, wall_joint_kinds_test, wall_plan_test) | every name resolves; none unused | — |
| Commit list (16 paths); Commit before Mutation; M-WT-1..12, M-WG-1/2 each name a red test | ok | — |
| Rulings R12-1, R12-2, R12-3 (assertion lines moved or reached through the UI) | already listed in `reconcile-log.md` "Rulings the writers made" for the controller | — |

## Blocking issues not fixed

None. Non-blocking risks to watch at execution (runtime only, no evidence of failure): Task 7's wider lock set against the existing frozen-object tests (the full plan gate runs them); Task 12's R12-1 path (panel text field and dropdown mid-chain, `pumpAndSettle`) and WP5's capture boundary choice (`find.ancestor(...).last`), both of which the integration gate exercises.

## Edits made: 11

- task-07.md: 1 (unused `Icons` import removed)
- task-08.md: 2 (M-PN-2 red point; SE8 rename cites R-P16)
- task-09.md: 2 (stale conformance sentence; example comment no longer names the plan package)
- task-10.md: 0
- task-11.md: 0
- task-12.md: 6 (EG1 `globalAt`; wall_tool_test imports and helpers; WP5 imports; integration fixture import block; WT-bands title and body)
