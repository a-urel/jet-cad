# Sub-project 3 (jet_cad_2d_kit_architecture + apps/architecture_demo): design-input inventory

Read-only research at `main` = `7e65905b` (2b follow-ups merged at `de6abda9`; not pushed).
Paths are relative to the repo root unless noted. Line counts are `wc -l`; test counts are
`test(`/`testWidgets(` lines (tests built in loops count once).

Sources read: umbrella spec `docs/superpowers/specs/2026-10-13-kit-architecture-design.md`
(A1-A17), contract spec `2026-10-13-kit-contract-design.md` (R1-R7), 2a spec
`2026-10-14-plan-library-design-mode-design.md` (P1-P7, E1-E4, Risks), 2b spec
`2026-10-14-plan-library-service-mode-design.md` (S1-S5, E5, Risks), the 2a and 2b results
notes, the 2b task-15 report (R-16), `packages/jet_cad_2d_kit/lib`, `packages/jet_cad_2d_plan/lib`
and `test/support`, `packages/jet_cad_floor_plan/lib` and `test`, `apps/*`, `tool/ci/lib/kit_deps.dart`.

---

## 1. The contract a kit must fill

### 1.1 `jet_cad_2d_kit` (contract, 3,245 lib lines)

Barrels: `lib/jet_cad_2d_kit.dart` (Flutter; exports `src/kit/*` + `src/model/model.dart`),
`lib/authoring.dart` (pure Dart; `src/authoring/*` + model).

**`PlanKit`** — `packages/jet_cad_2d_kit/lib/src/kit/plan_kit.dart:16-140`
```dart
const PlanKit({required String id, required String version,
  List<SymbolLibrarySource> symbols = const [], List<PlanType<Component>> types = const [],
  List<PlanTool> tools = const [],
  List<AttachmentProvider Function(PlanServices)> attachments = const [],
  KitNames names = KitNames.empty});                                     // :18-26
List<String> get propertyIds;   // '<type id>.<spec id>', tools' settings, choice values  :47-52
List<KitProblem> validate();    // ids, version, word namespaces, missing English          :60-139
```
No other fields: **no document-setup hook, no per-edit system (2b S2 closed `PlanKit.systems`),
no export/import contribution, no theme, no sample**.

**`PlanType<T extends Component>`** — `src/kit/plan_type.dart:34-164`
```dart
const PlanType({required String id, required ComponentFactory<T> fromJson,
  required ParametricType<T> parametric,
  ObjectGripProvider Function(PlanServices)? grips,
  List<PropertySpec<T>> properties = const [],
  PropertySectionBuilder<T>? section, String Function(T)? title,
  ColourTarget<T>? colour, bool exported = true});                        // :36-48
// erased operations the plan calls (T kept inside):
void registerInto(ParametricCatalog catalog, {TypeGuard? guard});        // :79
List<PropertyField> fieldsOf(CommandTarget target, Handle group);        // :88
String titleWordOf(CommandTarget target, Handle group);                  // :99  ('type:<id>' or title(T))
String? colourOf(CommandTarget target, Handle group);                    // :107
DraftCommand? recolour(CommandTarget, Handle, String? swatch);           // :116 (SetComponentCommand<T>)
DraftCommand commitField(CommandTarget, Handle, PropertyField, Object?); // :132
Widget? sectionFor(BuildContext, CommandTarget, Handle, void Function(DraftCommand), KitWords); // :150
ObjectGripProvider? gripsFor(PlanServices services);                     // :160
typedef PropertySectionBuilder<T> = Widget Function(
    BuildContext context, T value, void Function(T) commit, KitWords words);   // :24-25
abstract interface class TypeGuard { ParametricType<T> wrap<T>(kitId, typeId, type); } // :29-32
```
- Wraps the engine's `ParametricType<T>` (`packages/jet_cad_2d/lib/src/parametric/parametric_system.dart:26-195`:
  `editCapability`, `reach`, `generate`, **`instances` (E5, :59)**, `diagnose`, `references`,
  `referencePolicy`, `pageKey`, `dissolves`, `contributesPlace`/`placeBox`/`placeInput`,
  `readsPlaces`/`readBox`). E5 additions: `GeneratedInstance` :384, `GeneratedAttrib` :366.
- Display name = word `type:<id>`; a `title(T)` hook returns another word id (an opening by kind).
- **Note:** `sectionFor` has the document and handle but hands the kit's builder only `value`
  (`plan_type.dart:155`): the builder cannot read the object's handle, world transform,
  children or other objects.

**`PlanTool` / `PlanToolSettings`** — `src/kit/plan_tool.dart`
```dart
const PlanToolSettings({required S initial, required List<PropertySpec<S>> specs});   // :16-33
List<PropertyField> fieldsOf(Object value, void Function(Object) store, {required String toolId});
const PlanTool({required String id, required IconData icon, String? letter,
  Set<Capability> needs = const {}, PlanToolSettings<Object>? settings,
  required Tool Function(PlanServices) create});                                       // :36-62
```
Word `tool:<id>` is the label and the status-line text. **No notice/status channel, no cursor,
no hint text.**

**`PlanServices`** — `src/kit/plan_services.dart:86-130` (impl. `jet_cad_2d_plan/lib/src/controller/services.dart:34-109`)
```dart
DraftDocument get document; SpatialIndex get index; CameraController get camera;
bool get objectSnap; AttachmentRegistry get attachments; KitWords get words;
S settingsOf<S extends Object>(String toolId);                 // own tools only; pull, no listenable
T shared<T extends Object>(T Function(PlanServices) create);   // per (kit, T), per document; Disposable disposed
SymbolDefinitionRef? symbolDefinition(String key);             // 2b S2
ValueListenable<SymbolsState> get symbolsState;                // 2b S2
```
Also `KitWords` (:18-28: `word`, `maybe`, `locale`), `KitNamesWords` (:32-46), `Disposable` (:50-52),
`SymbolDefinitionRef` (:57-81: `handle`, `add`, `basePoint`, `top`).
**Absent:** the catalog / `typeIdOf`, the frozen or locked set, the page, the theme, the
plan's decimal separator (kit reads `PageComponent` from the document), a notice sink.

**Property specs** — `src/kit/properties.dart` (419 lines, pure Dart)
- `enum PlanGate { move, rotate, mirror, reshape, delete, changeLayer, recolor, editLayers, editPage, relabel }` :10-22
- `enum ValueUnit { length, area, angle, none }` :27
- `sealed class PropertySpec<T> { id; bool Function(T)? enabled; PlanGate? gate; bind(...) }` :41-68
- `LengthProperty<T>(id, read: double Function(T), write: T Function(T,double), min, max)` :72 (mm; min/max **constants**)
- `AngleProperty<T>(read, write)` :106 (radians stored, degrees shown)
- `NumberProperty<T>(read, write, min, max, decimals)` :129
- `ChoiceProperty<T,V>(values, read, write)` :169 (word `property:<owner>.<id>.<segment>`; rendered as a `DropdownButton`, `plan_property_panel.dart:728-744`)
- `ToggleProperty<T>(read, write)` :218
- `TextProperty<T>(read, write, maxLength)` :244
- `ValueDisplay<T>(read: double Function(T), unit)` :282 (read-only number **from T only**)
- `ActionProperty<T>(apply: T Function(T))` :304 (a button)
- `abstract interface class PropertyField` :326 (erased, bound field: `spec`, `wordId`, `value`, `enabled`, `commit`)
- Escape hatch: `PlanType.section` (above).
- Refusals: a `write`/`apply` that throws `ArgumentError` or `StateError` is a silent refusal (field
  shows the stored value); anything else is a `hookFailed` diagnostic
  (`jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart:497-525`). So per-value validation that
  needs only `T` (e.g. `isOpeningWidth(kind, w)`, a non-empty room name) is expressible inside `write`.
- `enabled` greys a field; `gate` off shows it read-only. **No `visible`.**
- Multiple selection: not in scope (only the colour row spans a selection).

**Colour** — `src/kit/colour.dart:12-17` `ColourTarget<T>({required String? Function(T) read, required T Function(T, String?) write})`;
`src/kit/swatch.dart:16` `enum PlanSwatch {red, orange, yellow, green, teal, blue, purple, grey}` (`rgb`), `planSwatchNamed` :34.
Used by the panel's colour row (`panels/colour_row.dart:31-71`) over every selected object of a type with a target, plus units.

**Attachment** — `src/kit/attachment.dart`
```dart
abstract interface class AttachmentProvider { String get kind; Attachment? attach(AttachmentQuery q); } // :11-18
AttachmentQuery({required Aabb2 footprint, required Transform2 current, required Vector2 pointer,
  required double capture, required double edgeCapture, required bool mirrored,
  required bool mayRotate, Set<Handle> exclude = const {}, Attachment? keep});        // :27-76
Attachment({required Transform2 transform, required Vector2 marker, required Object token}); // :84-103
abstract interface class AttachmentRegistry { Attachment? attach(List<String> kinds, AttachmentQuery q); Set<String> get kinds; } // :106-112
```
Plan side: `PlanAttachmentRegistry` (`jet_cad_2d_plan/lib/src/attach/attachment_registry.dart:17`,
nearest marker wins, a throwing provider = no attachment + diagnostic). Callers: `plan.symbol`
(`tools/plan_symbol_tool.dart:254-264`, pointer = raw point, `current` = the free ghost, capture
`kAttachPixels`=16 px /scale, edge `kSnapAperturePixels`/scale) and `plan.select`'s move resolver
(`tools/move_resolver.dart:70-80`, pointer = moved back-centre, `exclude: {node}`, `keep: _last`).
A symbol declares kinds in `SymbolComponent.attachTo` (`src/model/symbol_component.dart:99`) and its size
family in `family` (:102); `retired` :106. Load-time diagnostic `attachmentKindUnoffered`.

**`KitNames`** — `src/model/kit_names.dart:15-53`: `Map<locale, Map<wordId, String>>`, fallback English,
`merge`. Namespaces (`PlanKit.validate`, `plan_kit.dart:80-93`): `symbol:`, `category:<kit>/<cat>`,
`tool:`, `type:`, `property:`, `unit:<kit>/<kind>`; **anything else is `unknownWordId`**. Words are
flat strings: no placeholders, no plurals. Host words: `PlanController(words:)`, checked by
`validateHostWords` (`src/kit/host_words.dart:17`).

**Symbol sources** — `src/kit/symbol_library_source.dart:8-20` `SymbolLibrarySource({label, read: Future<Uint8List> Function()})`;
`src/kit/bundled_library.dart:11` `bundledLibrary(assetKey, {bundle})`. Format and validator
`src/model/symbol_library.dart` (481 lines, K3 rules 1-15). Key rule `src/model/kit_ids.dart`:
`isSymbolKey` = kit id + **two or more** dot segments.

**Conformance** — `src/authoring/conformance.dart:36-46`
```dart
List<KitProblem> conformance({required Catalog catalog, required Uint8List committedLibrary,
  required String committedSnapshot, required KitNames names, required List<String> locales,
  Map<String, Set<String>> sameAsEnglish = const {}, Iterable<String> typeIds = const [],
  Iterable<String> toolIds = const [], Iterable<String> propertyIds = const []});
```
Authoring: `Catalog`/`CatalogSymbol`/`CatalogShape` (`authoring/catalog.dart`), `encodeLibrary`/
`buildLibraryDocument` (`authoring/builder.dart:31,114`), shape helpers `rect`, `inset`, `poly`,
`chairAt`, `chairsAround`, `stoolAt`, `stoolsAround` (`authoring/shapes.dart`), snapshot
(`authoring/snapshot.dart`).

**Diagnostics** — `src/kit/kit_diagnostic.dart:9-81` `KitDiagnosticCode {hookFailed, rollbackFailed,
damagedUnsavable, componentUnreadable, letterTaken, attachmentKindUnoffered, libraryUnreadable,
libraryKitMismatch, symbolDuplicate, kitMissing, kitNewer}`, `KitDiagnostic(kitId, subject, code,
message, error)`. `src/model/kit_problem.dart:7-43` `KitProblemCode` (… `duplicateType`,
`typeOutsideKit`, `typePlaceConflict`, `unitKindWord`). The engine's own `Diagnostic`s from
`ParametricType.diagnose` (room.shared, room.broken, room.tint, separator.degenerate …) are **not
surfaced by the plan library** (only `system.drift()` in `kits/guard.dart:681`); today's planner
does not surface them in the UI either (tests call `system.diagnostics()`).

**Units (2b)** — `src/model/unit_component.dart:14-92` (`UnitLabelling`, `UnitKinds`, `UnitComponent`),
`src/kit/unit_label.dart:85` `unitLabelAttrib(...)`, `kUnitLabelTag`.

### 1.2 What the plan library derives from kits (today's closed lists)

| Today's closed list (umbrella Facts) | 2a/2b replacement | Where |
|---|---|---|
| `parametricCatalog` six registrations | every kit's `PlanType.registerInto(catalog, guard: PlanTypeGuard())` | `controller/plan_controller.dart:279-281` |
| `isParametricObject` (layer picker) | `catalog.typeIdOf(doc, h) != null` (E1) | `panels/layer_picker.dart:176` |
| `ObjectGrips._of` if-chain | one `GripDispatch` by `typeIdOf`, wrapped by `GuardedGrips`/`LockedGrips` | `controller/grip_dispatch.dart:24`, `controller/session.dart:67` |
| `FloorPlanTool` enum, palette `_entries`, `kShellLetterKeys`, per-tool strings | `PlanTool` ids, letters in load order, `tool:<id>` words | `shortcuts/tool_letters.dart`, `editor/plan_tool_palette.dart` |
| Selection panel per-type sections | `PlanType.properties` + `title` + `section` | `panels/plan_property_panel.dart:815-845` |
| `pickedColors` (rooms, tables) | `ColourTarget` + unit colour | `panels/colour_row.dart:31-71` |
| `exportOmitOwners` (separators) | `PlanType.exported == false` → `PlanExportRequest.omitted` | `controller/plan_controller.dart:338-344` |
| Room inputs (which types trace rooms) | nothing in the plan: kit-internal (`shared` cache) | — |
| Wall attach (`WallFaces`, `againstWallTag`) | `AttachmentProvider` kinds + `attachTo` | `attach/attachment_registry.dart` |

Also derived: select gates map a key under a parametric/locked group to the object
(`tools/plan_select_gates.dart:23-41`), locks of missing kits (`kits/locks.dart:45`), the failure
boundary (`kits/guard.dart`: `GuardedType` :42, `GuardedTool` :253, `GuardedGrips` :485,
`FailureBoundary` :585), kit-set validation (`kits/kit_set.dart:67`), the manifest (`file/manifest.dart`).
**No hook for:** document preparation (linetypes), tool notices, painting under/over the drafting
on a kit's behalf (only units get the underlay `export/unit_colour_underlay.dart`).

### 1.3 Test kits under `packages/jet_cad_2d_plan/test/support` (no kit draws walls)

| File | Kit(s) | Exercises |
|---|---|---|
| `test_kit.dart` (1,182) | `test` (`test.slab`: all eight spec kinds, a gate, a title hook, a colour target, grips, a section; `test.slab` tool with settings; `test-edge` provider; en+tr words); `unitKit()` adds a library (numbered table, assigned seat, booth), `test.row` generating seats through **E5 `instances`** and `symbolDefinition`; `discKit` (covariance), `conflictKit` (place conflict) | everything in P1-P3 and 2b S1/S2 |
| `panel_kits.dart` (556) | `box` (`box.box` = **today's demo box** ported, B, every field kind) and `disc` (section that throws, tool D with settings) | property panel (2a Task 17) |
| `mark_kit.dart` | `mark.cross` (`exported: false` variant) | panels, export omission |
| `box_kit.dart` (433) | `box` (contributes places) and `ring` (reads places), switchable throws | locks, failure boundary |
| `throwing_kit.dart` (527) | `boom.block/post/zone` | every guard |
| `stamp_kit.dart` | `stamp`, `late` (tools only) | letters, palette |
| `attach_fixtures.dart` | providers that answer, throw, are `Disposable` | registry plumbing only ("the geometry of a real provider (a wall face) is a kit's (sub-project 3)") |
| `unit_fixtures.dart` | `fx` (keys `fx.*`) | units |

Hooks **only exercised by test kits** so far (no real kit uses them yet): `PlanType.section`,
`title`, `colour`, `exported:false`, `ValueDisplay`, `ActionProperty`, `ChoiceProperty`,
`PlanToolSettings`/`settingsOf`, `shared`/`Disposable`, `attachments`/`AttachmentProvider`,
`symbolDefinition`, `instances` (E5), `PlanGate` on specs. `jet_cad_2d_plan/example/main.dart`
is a `PlanEditor` with **no kit**.

---

## 2. Today's architecture-domain code (`packages/jet_cad_floor_plan`, 32,152 lib lines, 165 test files)

Type ids today `floor_planner.box|wall|opening|separator|room|dimension`
(`lib/src/parametric/catalog.dart:27-39`); target ids `architecture.<type>`.

### 2.1 Per type

| Type | Lib files (lines) | Parameters | Tool, letter | Grips (`ObjectGrips._of`, `object_grips.dart:80-86`) | Selection-panel section (`selection_panel.dart`) |
|---|---|---|---|---|---|
| **Box** | `box.dart` 124, `box_tool.dart` 47 (171) | `BoxParams(width, height)`; generate subtracts overlapping boxes (`view.neighbours`) | Box, **B** | none | Title "Box"; width, height (finite > 0) :1300-1303 |
| **Wall** | `wall.dart` 286, `wall_geometry.dart` 623, `wall_bands.dart` 177, `wall_grips.dart` 203, `wall_tool.dart` 278 (1,567) | `WallParams(sx, sy, ex, ey, thickness, justification{left,centre,right})`; `contributesPlace`; joins through `neighbours`; cut by openings via `view.referrers` (`opening_geometry.dart:645-650`) | Wall, **W**; settings `WallSettings(thickness, justification)` (shell `ValueNotifier`, read per event) | `WallGrips`: 2 stretch grips; a drag moves joined walls' ends too (`_endsAt` :158) | Thickness (`isWallThickness`), Justification `SegmentedButton`; edits tool settings while the Wall tool is active :1304-1331 |
| **Opening** | `opening.dart` 270, `opening_geometry.dart` 756, `opening_grips.dart` 182, `opening_tool.dart` 450 (1,658) | `OpeningParams(host: Handle, position, width, kind{door,window,gap}, hinge{start,end}, swing{left,right})`; `references` → [host] | Door **D**, Window **N**, Gap **G** (one `OpeningTool(kind)` each, own `OpeningSettings(width)`); host = wall under pointer that `isUsableHost` (visible, unlocked layer) | `OpeningGrips`: 1 slide grip, edge snap with F3 at aperture; `movable` false (not moved or rotated) | Title by kind; width (`isOpeningWidth(kind, w)`), position (∈ [0, L], **L = host wall's centreline length**); Flip hinge / Flip swing buttons, **door only, hidden without `reshape`** :1332-1371 |
| **Separator** | `separator.dart` 149, `separator_grips.dart` 113, `separator_tool.dart` 138 (400) | `SeparatorParams(sx, sy, ex, ey)`; `contributesPlace`; drawn DASHED, lineweight 35 on `ReservedHandles.dashedLinetype` (`separator.dart:91-147`, `ensureDashedLinetype`) | Separator, **S** (band-trims through `RoomInputs`) | `SeparatorGrips(inputs, objectSnap)`: 2 ends, band-trim | none |
| **Room** | `room.dart` 470, `room_trace.dart` 1,111, `room_inputs.dart` 483, `room_label.dart` 179, `room_grips.dart` 176, `room_tool.dart` 443 (2,862) | `RoomParams(seedX, seedY, name, label?: (dx,dy), color?: palette name)`; `readsPlaces`/`readBox`; `pageKey` (unit, scale, decimal separator); dissolves; generates a **tint fill** (palette hue at `kRoomColorTransparency`, else ACI 7 at 229) + name and area TEXT | Room, **M**; `RoomTool(roomInputs, strings:)` names a new room `roomName(n)` (numbered names) and has a **`notice`** (room occupied) joined to the shell's status line (`planner_shell.dart:672-684, 989-1011`) | `RoomGrips(aperture)`: label grip; returns to auto within the aperture; not moved/rotated | Name (text, trimmed, empty refused); **Area: the area TEXT child's string as drawn** (`_areaOf`, :833-847) :1373-1386 |
| **Dimension** | `dimension.dart` 304, `dimension_geometry.dart` 494, `dimension_attach.dart` 297, `dimension_grips.dart` 269, `dimension_tool.dart` 574 (1,938) | `DimensionParams(a: DimEnd, b: DimEnd, kind{aligned,horizontal,vertical}, offset)`; `DimEnd` = `FixedEnd` or `AttachedEnd(wall, k, side{left,centre,right})`; `references` → attached walls; `pageKey` | Dimension, **I**; **`notice`** (the would-be value) on the status line | `DimensionGrips(index, objectSnap)`: offset + 2 ends; an end re-attaches through the index while F3 is on | **Value: TEXT child as drawn** (`_valueOf`); kind `SegmentedButton`; **axes line** from the group's world rotation (`_axesOf`, needs `tree.accumulatedTransform(dim)`); End 1/End 2 lines `endOnWall(hex, atStart, side)` / `Fixed` :935-1000 |

Shared shell glue (`planner_shell.dart` 1,841): `_bands = WallBands()` shared by Wall and the
three opening tools and `WallFaces`; `_roomInputs = RoomInputs(_document)` shared by Room,
Separator tools and separator grips; `ObjectGrips(edgeAperture, labelAperture, roomInputs, index, objectSnap)`.
`live_objects.dart` (29) and `catalog.dart` (66) answer "is this a live `T`" over the **global**
`parametricCatalog` and are imported by the pure geometry files (`wall_bands`, `room_inputs`,
`opening_geometry.wallsInDocument`, `room_tool`).

Other per-type rules:
- **Room inputs**: `room_inputs.dart:96-148, :296-314` (walls and separators by place; the openings
  of a wall via `wallsInView`).
- **Colour** (`colors/color_picker.dart:17-57`): `pickedColors` = rooms first, then tables;
  `recolorCommand` one 'Colour' step. Room tint re-tones on the dark canvas like every colour.
- **Export omit** (`export/export_bytes.dart:28-29`): every live separator.
- **Layers** (`layers/layer_picker.dart:23-29`): `isParametricObject` lists all six. Tools commit
  with `ObjectLayer(drawingLayer(document))` (engine `layer_commands.dart:105`); a hidden or locked
  wall hosts no opening (`isUsableHost`); a dimension attaches only to drawn walls.
- **Editability** today: `_editable` (`selection_panel.dart:362-378`) = host capability (`reshape`,
  tools always) + document permissions `components` + the type's `editCapability`.
- **New document**: `new_document.dart:16-22` adds the DASHED linetype record (handle 6) for separators.

### 2.2 l10n (`lib/src/l10n/strings.dart` 421, en 438, de 442, tr 436)
Architecture words: `toolBox/Wall/Door/Window/Gap/Room/Separator/Dimension` (:76-97), `width`,
`height`, `thickness`, `justifyLeft/Centre/Right`, `position`, `flipHinge`, `flipSwing`, `name`,
`area`, `value`, `aligned`, `horizontal`, `vertical`, `end1`, `end2`, `endFixed`, `leftFace`,
`centreline`, `rightFace`, **parameterised**: `roomOccupied(String name)` :59, `axesTurned(String degrees)`,
`endOnWall(String wall, bool atStart, String side)` :308, `roomName(int n)` :399 (e.g. tr `'Oda $n'`),
`sampleHall/Kitchen/Bath/Living/Dining`, `sampleBedroom(int n)`. ≈45 word ids × 3 locales.

### 2.3 Wall attach (09c)
- `symbols/wall_attach.dart` (550, pure Dart): `FaceSide`, `FaceRun` :37, `faceRunsOf` :63,
  `faceRunsAmong` :96, `FaceNeighbour` :206, `WallAttachment` :211, **`attachToWall(runs, SymbolBox box, p, capture, {mirrored, neighbours, edgeCapture, exclude, keep})`** :257 (D4: face pick, hold check, rotation, centre, edge snap to run ends and to neighbours, clamp; F-7 `keep`), `isOrthonormal` :402, `WallFaces(bands, accept:)` :420 (cache per document + bands generation; **neighbours = every root instance with a `SymbolComponent` and a box, via `boxOfDefinition`**).
  Imports `symbol_box.dart` (`SymbolBox`, `boxOfDefinition`) and `symbol_placer.dart`
  (`placementTransform`) — both now live in **`jet_cad_2d_plan/lib/src/symbols/`** (`symbol_box.dart:18,154,170`, `symbol_placer.dart:59`), not in the contract.
- `symbols/symbol_move.dart` (62): `SymbolMoveResolver(faces, library, canRotate)` → now the plan's `move_resolver.dart`.
- Tag `against-wall` → `attachTo: ['wall-face']`; tag `family:<id>` → `family`.
- Tests: `symbols/wall_faces_test` 9, `wall_attach_test` 23 (1,103 lines), `wall_attach_property_test` 2,
  `symbol_move_test` 6, `host/against_wall_rotate_test` 3 (F-7), `layers/attach_layer_test` 2,
  wall parts of `symbol_place_tool_test`, `apps/floor_planner/test/symbols/wall_attach_end_to_end_test` 2;
  fixture `test/support/wall_attach_fixture.dart` 163.

### 2.4 Furniture catalog and library
- Lives in **`jet_cad_floor_plan`** (not in `jet_cad_restaurant_symbols`): `lib/src/symbols/furniture_catalog.dart`
  (675, `FurnitureSymbol`/`FurnitureShape`, private `_chair`, `_diningSet`, `_rect`, `_inset`),
  `furniture_names.dart` (113, de/tr names), `build_library.dart` (87), generator
  `tool/generate_furniture_library.dart` (18), asset `assets/library/furniture.jetlib` (65 KB),
  source `furnitureSymbolSource` (`lib/symbol_sources.dart`).
- **41 symbols**, 6 categories (`Dining Room`, `Kitchen`, `Bed Room`, `Living Room`, `Bathroom`,
  `Office`), 6 families (`kitchen-base` ×4, `bed-double` ×3, `bed-single` ×3, `wardrobe` ×3,
  `sofa` ×2, `desk` ×3), 27 carry `against-wall`.
- **Five dining tables at `@2` carry `jetcad.seating`** (servable: `dining.table.square.two/four`,
  `rect.four/six`, `round`).
- Keys that break K2 under `architecture.` (need ≥2 segments after the kit): `armchair`; borderline
  renames to decide for `table.coffee`, `tv.unit`, `dining.chair`, `dining.bench`, `bed.double`, `office.desk`
  (they pass as `architecture.x.y` but some are size-family members whose siblings carry a size segment).
- `jet_cad_restaurant_symbols` (2,238 lines incl. tests) imports `jet_cad_floor_plan/symbols.dart`
  for its catalog types; it has no `against-wall` symbol. It is sub-project 4's.
- Tests: `symbols/furniture_library_test` 34, `symbol_box_test` (the asset's literal boxes "stay with that
  asset's kit (sub-project 3)"), `symbol_ghost_test` (the asset's entries), `package_assets_test` 7.

### 2.5 The algorithms (A12: move with their tests)
- **Opening cuts**: `opening_geometry.dart` (756): host frame, obstacles, stretches, stored centre,
  edge snaps; the wall's generate reads its openings as referrers. Tests `opening_cut/kink/obstacle/end_drag/geometry/cost`.
- **Room tracing**: `room_trace.dart` (1,111: faces, holes, `Tint` steps 1-3, pole of inaccessibility),
  `room_inputs.dart` (place sources, memoised per view), `room_label.dart`. Tests `room_trace/follow/tie/dissolve/tint/localise/cost/diagnostics`.
- **Dimension attachment**: `dimension_attach.dart` (297: candidates through the index, `decideEnd`),
  `dimension_geometry.dart` (494). Tests `dimension_attach(_points)/follow/rotate/fuzz/layout/format`.

### 2.6 Test inventory (`packages/jet_cad_floor_plan/test`)
| Group | Files | Lines | Tests |
|---|---|---|---|
| box | 1 | 91 | 6 |
| wall | 7 | 3,592 | 73 |
| opening | 13 | 6,707 | 85 |
| separator | 2 | 688 | 10 |
| room | 16 | 9,702 | 100 |
| dimension | 14 | 8,455 | 73 |
| wall attach + furniture (above) | 7 | ~3,750 | ~79 |
| layers (`tools_layer` 10, `attach_layer` 2, `opening_host_layer` 6) | 3 | 598 | 18 |
| shell rows (`planner_draw` arch rows, `planner_grips` 5, `planner_box` 6, `planner_shell` arch rows, `startup_plan` 14, `intersection_snap` 1, `decimal_separator` 6, `delete_components` 3, `selection_panel` WS*) | ~9 | ~3,000 | ~50 |
| support fixtures (`wall` 301, `room` 758, `opening` 960, `dimension` 522, `wall_attach` 163, `wall_shell` 51, `layer` 303, `box_rig` 96) | 8 | 3,154 | — |

Plus the rows 2a/2b explicitly left to sub-project 3 (grep "sub-project 3" in `jet_cad_2d_plan/test`, 20 hits):
`selection_panel_test` WS* (wall), `selection_page_test` (W key → B stand-in), `layer_picker_test` (Wall and Door tools),
`palette_draw_test` (the eight arch tool rows, :241-242), `touch_tools_test` TD1 (Room tool),
`colour_row_test` CP2 (room tint pixels), `editor_separator_test` NS3 (room label),
`numbered_names_test` NN3 (sample rooms), `editor_options_test` V-5's wall/room/dimension parts,
`plan_symbol_tool_test` (wall attachment), `symbol_box_test`/`symbol_ghost_test` (furniture boxes),
`unit_zone_fixture` (the walled room named `7`), `unit_editor_fixture` (startup flat walls),
**R-16**: `unit_fill_test` TF1/TF7 room and tint lines, **TF3's `hasLength(5)` returns to 6**,
`unit_colour_export_test` EX2/EX3/EX5 tint lines and the premises' key list with `R`;
`host/against_wall_rotate_test` (not ported in 2b).

---

## 3. The gaps

Legend: **OK** = the 2a/2b contract expresses it as is; **KIT** = kit-internal work only;
**CHANGE** = a contract or plan-library change (amend the 2a/2b spec before 0.1.0, per both
specs' Risks: "A field they need goes into this spec as an amendment").

### 3.1 Contract / plan-library changes needed

| # | Today's behaviour | Status | Why, and what is missing |
|---|---|---|---|
| G1 | Room **Area** "as drawn" and Dimension **Value** "as drawn" (`selection_panel.dart:833-870`) | **CHANGE** | `ValueDisplay.read(T)` sees only the component. The area is not in `RoomParams` (it comes from tracing among other objects); the value is the generated TEXT child. Needs a display that reads the object (document + handle), e.g. `TextDisplay<T>(read: String? Function(T, PlanObject))` or a `PlanObject` (document, handle, world transform) argument on `read`. |
| G2 | Dimension **axes** line (group world rotation) and **End** lines (`endOnWall`) | **CHANGE** | Needs the handle/transform (G1) **and** a string display; the escape hatch can't do it either: `sectionFor` passes the builder only `value` (`plan_type.dart:150-157`). Minimum fix: give `PropertySectionBuilder` the document and handle (or a `PlanServices`-like object view). |
| G3 | Opening **position ∈ [0, L]**, L = host wall's length | **CHANGE** | `LengthProperty.min/max` are constants and `write(T, v)` has no document; the host's length is another object's component. Needs bounds or a validator over (T, document) — same `PlanObject` argument as G1. (Width-by-kind and non-empty room name are fine: `write` throws `ArgumentError` = silent refusal.) |
| G4 | **Tool notices** on the status line: Room tool "Already a room: X", Dimension tool's would-be value (`planner_shell.dart:672-684, 989-1011`) | **CHANGE** | `PlanTool`/`Tool` have no notice; `PlanEditor._statusLine` (`editor/plan_editor.dart:514-519`) shows the tool label and the selection count only. Needs e.g. `PlanTool.notice: ValueListenable<String?> Function(Tool)` or a `ToolNotice` interface the canvas/editor listens to (guarded like the other hooks). |
| G5 | **Separator's DASHED linetype** (`new_document.dart:22`, `ensureDashedLinetype`) | **CHANGE** | 2a's `newPlanDocument` dropped it ("the separator's, sub-project 3", `controller/new_plan.dart:3-4`). No kit hook seeds document tables. Needs `PlanKit.prepare(DraftDocument)` (outside history) run on `newPlan`, `load` and `import`, or the separator's own command must add the record undoably (no such command known). |
| G6 | **Wall-face provider's neighbour edge snap** (09c D4) and exact placement | **CHANGE** (or duplicate) | `attachToWall` needs `SymbolBox`/`boxOfDefinition` for every placed symbol (neighbours) and `placementTransform` (exact, `-0.0` cleaned); both are now plan-library internals (`jet_cad_2d_plan/lib/src/symbols/symbol_box.dart:154`, `symbol_placer.dart:59`) that a kit may not import (A1). Move these pure-Dart helpers into `jet_cad_2d_kit` (contract), or the kit carries a second copy (two owners of one rule; the plan's `symbol_section.dart:132-136` already copies `isOrthonormal` "for sub-project 3"). `AttachmentQuery.footprint` suffices for the moving symbol itself (back-centre = (centre x, max y)). |
| G7 | **"Is this a live wall"** outside `generate` (WallBands, RoomInputs, WallFaces, opening host scan, dimension candidates, room tool) | **CHANGE** (small) | They call `isLiveObject<T>` over a global catalog. `PlanServices` exposes no catalog, `typeIdOf`, or frozen/locked set. A kit-local `ParametricCatalog` of its six types works for the rule, but a **frozen** (E2) wall stays "live" to the kit while every survey/view omits it: the room tool's preview and the wall-face provider disagree with `generate`. Add `PlanServices.typeIdOf(handle)` / `isLive<T>(handle)` honouring the frozen set (and maybe `isLocked`). |
| G8 | **Parameterised and non-field words**: `roomName(n)`, `roomOccupied(name)`, `endOnWall(...)`, `axesTurned(...)`, sample room names | **CHANGE** | `KitNames` holds flat strings; `PlanKit.validate` refuses any namespace outside symbol/category/tool/type/property/unit (`plan_kit.dart:80-93`, `unknownWordId`), so a notice or a template word has no lawful id (abusing `property:` passes validate but is a hack). Needs a message namespace (e.g. `text:<kit>.<id>`) and a placeholder convention with a conformance check that every locale keeps the same placeholders. `numbered_names.dart` (room numbering) is plan-internal: the kit copies it or it moves to the contract. |
| G9 | Hidden vs disabled fields: the flips show for doors only, and a button the capabilities refuse is **not shown** (S-11) | **CHANGE or parity row** | Specs have `enabled` (grey) and `gate` (read-only), no `visible(T)`. Either add `visible` or record the difference in sub-project 4's parity table (A14: needs the human's word for a "dropped"). |
| G10 | Where the kit's **integration tests** run | **DECISION** | `tool/ci/lib/kit_deps.dart:39-59` forbids a kit naming `jet_cad_2d_plan` in **any** Dart file (test/ included). Every shell-level port (tools on a canvas, panel sections, wall-attach end-to-end, R-16 lines, the 20 carried rows) cannot live in the kit. The check does not bind the plan library, so `jet_cad_2d_plan` may take `jet_cad_2d_kit_architecture` as a **dev_dependency** (R-16's TF3 "returns to 6" already presumes the plan's own tests see a room); or they live in `apps/architecture_demo/test`. Pick one; it also decides where the A11 README pictures are generated. |

### 3.2 Expressible as is (OK) or kit-internal (KIT)

| Behaviour | Status | How |
|---|---|---|
| Six types registered, ids `architecture.*`, letters W D N G M S I B | OK | `PlanType` × 6, `PlanTool` × 8; no clash with V L P R C A T F; M is also the symbol tool's mirror key (tool-internal, P2 says no conflict). |
| Room tracing reads walls + separators (cross-type, one kit) | OK | Places: wall/separator `contributesPlace`, room `readsPlaces` (one catalog per controller; `register` refuses only a type doing both). |
| Opening cuts its host wall | OK | `references: [host]` + wall reads `view.referrers`; the engine regenerates the host. Risk: E2 freezes an opening → its host's survey omits it → the wall regenerates **uncut** next to the frozen door. Spec it. |
| Dimension attaches to walls | OK | `references` + `AttachedEnd`; grips/tool use `PlanServices.index` and `objectSnap`. |
| Wall joins | OK | `view.neighbours` filtered by `WallParams`; another kit's object whose reach overlaps becomes a neighbour (perf only). |
| Snap to walls | OK | Generic object snap over generated entities; wall/opening tools' own band snaps are kit-internal. |
| Shared caches (WallBands, RoomInputs, WallFaces) | OK/KIT | `PlanServices.shared` (per kit, per document, `Disposable`). |
| Grips with apertures and F3 | OK | Factories over `PlanServices` (`camera` scale, `objectSnap`); `kSnapAperturePixels` is the Flutter layer's. Opening/room not movable via `ObjectGripProvider.movable`. |
| Tool settings (wall: thickness + justification; door/window/gap: width) | OK | `PlanToolSettings` per tool; tools pull through `settingsOf` (today's tools also read per event). Opening tool-settings section title: `tool:<id>`. |
| Opening section title by kind | OK | `title` hook. |
| Flip hinge / flip swing | OK (but G9) | `ActionProperty` with `gate: reshape`, `enabled: door`. |
| Wall thickness, justification; box width/height; room name; dimension kind | OK | Length/Choice/Text specs; Choice renders as a dropdown, today a `SegmentedButton` (look and test finders change, A4 accepts). Refusals via `write` throwing `ArgumentError`. |
| Room colour in the property panel | OK | `ColourTarget<RoomParams>`; the colour row lists kit targets before units, today's "rooms first, then tables". |
| Room tint in design, **service** and export | OK | The tint is the room's own generated fill (palette hue, `kRoomColorTransparency`), so the service copy and the exporters draw it as drafting; 2b R-16 dropped only **test lines** (TF1, TF3, TF7, EX2, EX3, EX5, premises' `R`) for want of a room fixture — no paint hook is missing. They come back with the kit (see G10). |
| Room label in service (a TEXT `7` look-alike is not unit 7) | OK | Drafting text; the service picker reads `UnitIndex` only. The zone fixture's room returns in sub-project 3. |
| Unit inspector / room relation | none today | No table↔room link exists in `jet_cad_floor_plan` (checked `host/`, `service/`, `tables/`). |
| Export of rooms; separators omitted | OK | Room geometry is drafting; separator `exported: false`. |
| Layer rules for live objects | OK | E1 `typeIdOf` (layer picker, grips, gates). Tools commit with `ObjectLayer(drawingLayer(doc))` (engine). |
| Locked/hidden wall hosts nothing | KIT | `isUsableHost` reads the document's layers. |
| New room's name in the UI language | OK + G8 | `PlanServices.words` (live locale) — needs a template word. |
| Page-dependent text (area, dimension; separator Q0) | OK | `pageKey` + `view.page`. |
| Missing architecture kit | OK | 2a locks: walls, openings, rooms draw as saved, read-only. |
| Box type | OK | `panel_kits.dart` already ports today's box as `box.box`; becomes `architecture.box`. |
| Wall-face provider itself | KIT + G6 | `kind: 'wall-face'`, provider over shared WallBands/WallFaces; F-7 rule from `mayRotate` + `current`'s linear part; hysteresis via `keep.token`. |
| Furniture symbols' `attachTo`, `family` | OK | Contract fields. |
| Engine `diagnose` (room.*, separator.*) | OK (as today) | Not shown by today's UI either; kit tests read `ParametricSystem.diagnostics()`. |
| Paint-allocation non-negotiable | OK | Kit generates only engine entities (A17.2); tool previews are the kit's; consider a kit query-allocation probe for the guarded wall/room hot path (2a Risks). |

### 3.3 Design decisions to take in the sub-project 3 spec
- D-a: **Are the five dining tables units?** Today they carry `jetcad.seating` (`@2`), so they are servable. In the new world that makes `architecture.*` tables units in architecture_demo's service mode and alongside the restaurant kit's tables in restaurant_demo.
- D-b: key renames to meet K2 (`architecture.armchair` invalid) and the version restart (`@1` everywhere, decision 9).
- D-c: where the sample plan (`startup_plan.dart` 422 + `startup_plan_test.dart` 811/14) lives: the kit (an `example`/helper), or the demo app; its room names need G8 words.
- D-d: G10's test home.
- D-e: `SymbolBox`/`placementTransform` into the contract (G6) vs a kit copy.
- D-f: one spec amendment set for 2a (G1-G5, G7-G9) before 0.1.0.

---

## 4. `apps/floor_planner` and the demo to come

- **Structure** (lib 1,750 lines): `main.dart` 206 (`FloorPlannerApp`: owns a `DocumentSession`,
  `DocumentFiles`, `SymbolLibraryLoader` over **furniture + restaurant** sources, `SymbolThumbnails`
  (128), `ExportFontCache`; locales en/de/tr), `document_host.dart` 799 (New, Open sample, Open,
  Save, Save As, Export, Print, dirty/Save-Don't-Save-Cancel, exit guard; builds
  `PlannerShell(key: ObjectKey(document))`), `document_files*.dart` (io/web/stub, `file_selector`,
  web download), `exit_guard*.dart`, `app_strings.dart` 255 (3 locales), `export/export_flow.dart`.
- **Imports**: the internal barrel `package:jet_cad_floor_plan/editor.dart` (exports `PlannerShell`,
  every parametric file, `startup_plan`, symbols, tables), plus `jet_cad_floor_plan.dart` (locales),
  `jet_cad_restaurant_symbols`, `jet_cad_2d`, `jet_cad_2d_flutter`, `file_selector`, `pdf`, `web`.
  Font asset declared from `packages/jet_cad_floor_plan/fonts/Roboto-Regular.ttf`.
- **Platforms**: `macos/`, `web/` only.
- **Tests**: 21 test files, **203 tests**, 13,787 lines incl. support (document commands 16, exit 8,
  files 18, host 7, open 6, replace 11, save 7, separator 3, settle 8, export 39, layers 40 (ported by 2a),
  symbols 36 (loader 15, shell 17, end-to-end 2+1+1), wall attach end-to-end 2); support duplicates
  the package's wall/room/dimension/layer/attach fixtures.
- **Who depends on `jet_cad_2d_plan` today:** no app and no package (only `tool/ci` names it).
  `apps/restaurant_demo` (android/ios/linux/macos/web/windows) depends on `jet_cad_floor_plan`
  ^0.7.2 + restaurant symbols; its two sample plans (`assets/plans/salon.json`, `teras.json`) carry
  only page, symbol and seating components (no walls). It is sub-project 4's.
- **`jet_cad_2d_plan/example/main.dart`**: `PlanEditor` over `PlanController(kits: const [])`; no
  test kit draws walls (§1.3).

**What `apps/architecture_demo` needs** (A11: the architecture kit only):
1. `PlanController(kits: [architectureKit])` + `PlanEditor` (its bar's host file callbacks, `exportName`,
   `printer`, `onExportDialog`, `onPageFlowError`, `shortcuts`, `theme`), symbols = furniture only
   (today's app also loads the restaurant library).
2. Port the document layer: session, files (io/web/stub, `file_selector`, web download), exit guard,
   dirty/save prompts, Open sample, onto `controller.load/save/dirty/markSaved/newPlan`
   (plans are manifest-carrying text; old `.json` plans refused, decision 9).
3. App words (en/de/tr), fonts (`ensurePlanFonts`, `registerFontLicences`), dark theme.
4. Sample plan (D-c) and the "Open sample" bar action (`PlanEditor(bar: actions/leading/trailing)`).
5. Platforms macos + web (match today), CI job, its tests ported (≈160 of 203 are app-level flows;
   layers/export already ported into the plan by 2a), plus wall-attach and symbol end-to-end on the kit.
6. STATUS: the human asked to be told when `apps/architecture_demo` runs on the new packages.

---

## 5. Size estimate

**Lib to move into `jet_cad_2d_kit_architecture`** (≈10.8k lines, plus ≈1-1.5k new glue):
types 8,596 (box 171, wall 1,567, opening 1,658, separator 400, room 2,862, dimension 1,938);
wall attach 550; furniture catalog + names + builder + generator 893 (rewritten in `CatalogSymbol`
over `authoring/shapes.dart`); the type sections of `selection_panel.dart` (~400 lines) become
spec declarations and one or two sections; `live_objects`/`catalog`/`object_grips` (200) replaced by
the `PlanKit` descriptor; sample plan 422 (D-c). Words ≈45 ids × 3 locales + 41 symbol names × 2.

**Tests to port**: ≈ 500 tests, ≈ 33-37k lines:
per-type 347 tests (29.2k lines); wall attach + furniture ≈79 (3.8k); layers 18 (0.6k); shell
rows ≈50 (3k); support fixtures 3.2k lines; the 20 carried rows / R-16 lines in the plan's
tests; the demo's ≈160 app tests (≈9k lines) on top. (Plan library today: 154 test files, 1,443 tests.)

**Contract work first**: G1-G9 amendments (2a/2b specs) + code in `jet_cad_2d_kit` /
`jet_cad_2d_plan` + their tests and mutants.

**Rough task count: 24-30**, e.g.
1-4 contract amendments (object view for displays/sections/bounds G1-G3; tool notice G4; document
prepare G5; move SymbolBox/placementTransform G6; `typeIdOf`/frozen on services G7; message words +
placeholders + conformance G8; `visible` G9);
5 package scaffold, kit descriptor, words, CI job, `check_kit_deps`;
6 box; 7-8 wall (geometry/bands, type/grips/tool/settings);
9-11 opening (geometry, type/grips, three tools);
12-14 separator + room (trace/inputs/label, type/grips, tool/notice);
15-17 dimension (geometry/attach, type/grips, tool/notice);
18 property sections parity (panel ports, WS*, readOnly V-5);
19-20 furniture catalog, generator, `.jetlib`, snapshot, conformance; 
21 wall-face provider + 09c ports + F-7;
22 integration home (G10) + R-16 lines + the 20 carried rows;
23 sample plan; 24-26 `apps/architecture_demo` (document flows, files/platforms, tests);
27 final gate, CHANGELOGs/READMEs, results note.
Consider splitting into 3a (contract amendments + kit) and 3b (demo), as sub-project 2 was split.
