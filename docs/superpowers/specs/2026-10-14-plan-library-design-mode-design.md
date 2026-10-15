# The plan library, design mode (sub-project 2a) — design

**Date:** 2026-10-14. **Status:** revision 3. Revision 1 was written after the
human approved the design section by section in chat. Revision 2 applies an
independent Opus review (3 blocking, 11 important, 13 minor findings, each
checked against the code), on the human's *"evet, revizyonu yap"*; revision
3 applies that reviewer's re-review of revision 2 (N1-N9). Awaiting the
human's review of this file.

**Binds:** the umbrella spec
[2026-10-13-kit-architecture-design.md](2026-10-13-kit-architecture-design.md)
(A1-A17) and the contract spec
[2026-10-13-kit-contract-design.md](2026-10-13-kit-contract-design.md)
(K1-K9, its amendments, and "Inputs for sub-project 2", R1-R7). The
umbrella's amendment of 2026-10-14 records the split of sub-project 2.

**Branch:** `feat/plan-library-2a`, cut by hand from `main` at `6083906`
(`origin/main` at `27244bf`, an ancestor), worktree
`.claude/worktrees/plan-library-2a`.

## Decisions taken in the brainstorm (the human, 2026-10-14)

1. **Sub-project 2 is split in two** (*"İkiye böl"*). **2a**, this spec,
   covers the contract's code side and the plan library in design mode.
   **2b** covers the service mode: units, statuses, the band, groups, zones,
   focus, overlays, events and host data, with their themes, touch and
   keyboard parts. Each has its own spec, plan, branch and review. The wave
   (A10) still ships them together.
2. **Approach 1: thin adapters over the Flutter layer** (*"onaylıyorum"*). A
   kit contributes the engine's own `ParametricType` and the Flutter layer's
   `Tool` and `ObjectGripProvider`, each wrapped in a contract descriptor.
   The plan library composes them.
   - Rejected: an object model of the plan library's own that hides the
     engine. It would rewrite the parametric and grip layers, and the ported
     tests would no longer serve as the oracle (A12).
   - Rejected: kits that register into the engine directly. That leaves no
     failure boundary and no declarative properties.
3. **Sections P1-P5 were approved one by one** (*"uygun, devam et"*).
4. **`DraftDocument` keeps its name** (*"DraftDocument kalsın"*). The
   `Draft*` family stays whole. An importer returns a plan's text, so a host
   never names the engine's document (P5), unless it writes its own
   exporter, which renders a document and so receives one.
5. **Nothing of today's host API is dropped by this spec.** Every
   design-mode capability is mapped in P7 to 2a, 2b or sub-project 4. A row
   may say "dropped" only with the human's word (A14).

## Facts (at `6083906`, read from the code; checked by the review)

**The Flutter layer**
- **It has no controller.** State is split over several objects:
  - `CameraController` (`jet_cad_2d_flutter/lib/src/camera_controller.dart:44`);
  - `SelectionController` (`selection.dart:106`);
  - `ToolController` (`tool.dart:159`);
  - `ToolContext` (`tool.dart:82`), which holds the document, index,
    camera, selection, page, snap and grips;
  - `PageNotifier`;
  - `SnapSettings`, which holds only the F3 flag.

  `PlannerShell` assembles them by hand.
- **Tools.** `Tool` (`tool.dart:116`) commits through `ToolContext.execute`,
  which calls `document.commands.execute` directly (`tool.dart:109`).
  `SelectTool` rethrows what an edit throws (`select_tool.dart:546-550`).
- **Grips.** `ObjectGripProvider` (`grip_cache.dart:33`) never receives a
  `ToolContext`. Today's providers get world apertures and the effective
  object-snap flag through their constructors (`planner_shell.dart:648-656`).

**The engine**
- **Commands do not name their handles before they apply.** `DraftCommand`
  exposes only `capability`, `label` and `apply`
  (`jet_cad_2d/lib/src/document/command.dart:122-137`). The touched handles
  exist only in `CommandResult.touched`.
- **Permissions are four groups:** `components`, `transform`, `geometry`,
  `structure` (`command.dart:25-54`). Moving and rotating are both
  `transform`. Today's per-action flags are UI gates (`SelectGates`,
  `select_gates.dart:22-60`, and the panels).
- **The dispatcher's order is fixed** (`document/undo.dart:188-199`):
  1. `onBeforeMutate`, an index-walk guard that changes no state;
  2. the dispose check;
  3. the one `expander` (`:151`);
  4. the permission check;
  5. `apply`.

  `undo` and `redo` skip the expander. Expanders already stack:
  `TableLabelSystem` keeps the previous one and wraps it
  (`jet_cad_floor_plan/lib/src/tables/table_label_system.dart:27-48`).
- **A regeneration that throws is already rolled back.** `_run` puts the
  survey, `dissolves`, `generate` and the apply loop under one rollback
  (`parametric/regeneration.dart:968-1046`), and rethrows the error unchanged
  (`:1013`, `:1045`). A rollback that itself throws raises a plain "partially
  mutated" `StateError` (`:735`, `:1040`).
- **When `apply` throws, the dispatcher records nothing:** no history, no
  change event, no `onAfterMutate` (`undo.dart:193-199`), so the spatial
  index learns of an edit only after a successful `apply`.
  `commands.notifyLoaded()` (`:263-268`) clears history and rebuilds
  listeners through `DocumentLoaded`.
- **Kit code runs on every edit:** `_survey` calls `reach` and `references`
  for every live object (`regeneration.dart:243-264`). `reach(T params,
  Transform2 toWorld)` receives no handle (`parametric_system.dart:32`). A
  neighbour's edit regenerates an object again, and `generate` has no way to
  answer "keep my children". `ParametricCatalog`
  (`parametric_system.dart:488`) has `register` and no listing query.
  `register` throws for a type that both contributes and reads places
  (`:497`).
- **A component factory that throws aborts the whole load**
  (`document/component.dart:310`). An unknown type id is kept raw (`:304`),
  and saving merges raw and registered entries by type id without collision
  (`:254-281`). `ComponentRegistry.loadJson` takes no diagnostics list
  (`:295`); the codec has one (`codec/json_codec.dart:134`).

**The planner and the kit package**
- **Load discards its diagnostics** (`FloorPlanController._decode`,
  `floor_plan_controller.dart:1313-1321`).
- **The closed lists** are named in the umbrella's Facts.
- **Wall attachment** reaches the tools through constructor arguments
  (`WallFaces`, `againstWallTag`). Under `rotate: false` a symbol attaches
  only to a face its back already faces, and keeps its turn
  (`planner_shell.dart:436`, `:500`).
- **`jet_cad_2d_kit`** has `PlanKit(id, version, symbols, names)`,
  `SymbolLibrarySource(label, read)` whose `read` returns a `Future`
  (`symbol_library_source.dart:16`), `KitNames`, the four `jetcad.*`
  components, the library format, 19 `KitProblemCode` values and the pure
  `authoring.dart`. It depends on Flutter and the engine, **not on
  `jet_cad_2d_flutter`**.

## P1. The contract's code side (`jet_cad_2d_kit`)

`jet_cad_2d_kit` gains a dependency on `jet_cad_2d_flutter`; A1's graph
already places it there. `authoring.dart` stays pure Dart, and the existing
purity test keeps it so.

```dart
final class PlanKit {
  const PlanKit({
    required this.id, required this.version,
    this.symbols = const [], this.types = const [], this.tools = const [],
    this.attachments = const [], this.names = KitNames.empty,
  });
  final List<PlanType<Component>> types;
  final List<PlanTool> tools;
  final List<AttachmentProvider Function(PlanServices)> attachments;
}
```

**`PlanType<T extends Component>`** describes a parametric type:

- **Fields.** `id` (`'<kit>.<type>'`, equal to the component's codec type
  id, which the manifest relies on), `parametric` (the engine's
  `ParametricType<T>`), `grips` (`ObjectGripProvider Function(PlanServices)?`),
  `properties` (`List<PropertySpec<T>>`, P3), `section` (A4's escape hatch),
  `colour` (`ColourTarget<T>?`, P3), `exported` (default `true`; `false`
  leaves the type out of export).
- **Covariance.** The plan holds every type as `PlanType<Component>`. A
  field of a function type over `T` read through that static type fails
  Dart's runtime covariance check, and `catalog.register` would infer
  `T = Component`.
- **So the plan never reads a `T`-typed member from outside.** It calls only
  erased operations that the class implements over its own `T`, as the
  engine's `_Registration` does:
  - `registerInto(ParametricCatalog)` (the catalog registers the factories
    into a document's registry itself, through `registerComponents`);
  - `fieldsOf(CommandTarget, Handle)`, which returns `PropertyField`s bound
    to that object;
  - `colourOf` and `recolour`;
  - `sectionFor`.

**`PlanTool`** describes a palette entry:

- **Fields.** `id` (`'<kit>.<tool>'`), `icon`, `letter` (a suggestion, P2),
  `needs` (a `Set<Capability>`: what the tool's commits require; empty for
  a tool that only reads), `settings` (`PlanToolSettings<S>?`, P3, with the
  same erased-operations rule), `create` (`Tool Function(PlanServices)`).

**`PlanServices`** is a live view, one per kit per controller:

```dart
abstract interface class PlanServices {
  DraftDocument get document;          // the current document
  SpatialIndex get index;
  CameraController get camera;         // for apertures in world units
  bool get objectSnap;                 // the effective flag: F3 and the editor's snapping
  AttachmentRegistry get attachments;
  KitWords get words;                  // this kit's words at the controller's locale
  S settingsOf<S extends Object>(String toolId);
  T shared<T extends Object>(T Function(PlanServices) create);
}
```

- **`shared` is a per-document cache keyed by (kit id, type).** The first
  call creates; later calls return the same instance. A cache that
  implements `Disposable` is disposed with its document. It replaces the
  shell-owned `WallBands`, `WallFaces` and `RoomInputs`, which a kit's tool,
  grips and provider then share. Keying by kit keeps two kits that ask for
  the same type apart.
- **Lifetimes.** A kit's factories (`PlanTool.create`, `grips`,
  `attachments`) run **once per document**. When `load`, `newPlan` or
  `import` swaps the document, the controller:
  1. cancels the active tool and returns to `plan.select`;
  2. disposes the previous document's tools, grip providers, attachment
     providers and `shared` cache;
  3. runs the factories again over the new document.

  So nothing a kit holds outlives its document; `RoomInputs`, which keeps
  its document, is safe.
- **Reserved ids.** The plan library's own tools are `plan.select`,
  `plan.line`, `plan.polyline`, `plan.rectangle`, `plan.circle`,
  `plan.arc`, `plan.text` and `plan.symbol`. `plan` and `jetcad` are
  reserved kit ids.
- **The engine's types stay visible to kits** (`DraftDocument`,
  `DraftCommand`, `ParametricType`, `Component`), per decision 2 and R5.

## P2. `jet_cad_2d_plan`: the controller, the symbols, the widgets

### `PlanController`

```dart
PlanController({
  required List<PlanKit> kits,
  String? json,                         // today's constructor json:
  PlanPermissions permissions = PlanPermissions.full,
  PlanSymbolLoader? symbols,            // shared across controllers; never disposed by one
  SymbolThumbnails? thumbnails,         // likewise
  List<PlanExporter> exporters = const [],
  List<PlanImporter> importers = const [],
  double minScale, double maxScale,
})
```

**It owns:**
- the validated kit set (P4);
- the design document and its manifest;
- the systems built over the document:
  - one `ParametricSystem` over one `ParametricCatalog` holding every kit's
    types, each wrapped by the guard (P4);
  - the lock expander, stacked after it (P4);
- the view state: the spatial index, page, camera, selection, tool
  controller, snap setting, and grip cache (one provider, dispatching by
  `typeIdOf`, E1);
- the kit-facing parts: the attachment registry, the `PlanServices` views,
  the tool settings, the `shared` caches;
- the diagnostics.

**Room for 2b.** The controller holds one design document. 2b adds the
service copy, a second document, beside it. `save()` always encodes the
design document, as `designJson()` does today.

**Commands:**
- **The plan:** `newPlan({String? decimalSeparator})` (default: the
  locale's, as today), `load(String)`, `save()` → `String`, `dirty`,
  `markSaved()`.
- **Undo:** `undo()`, `redo()`, `canUndo`, `canRedo`.
- **Tools and selection:** `selectTool(String id)`, `activeTool`,
  `deleteSelection()`.
- **Export and import:**
  - `export(String exporterId, PlanExportChoice choice, {String? name})`
    returns `Future<PlanExport?>`, where `PlanExport` carries bytes, a name
    and a MIME type. `PlanExportChoice` is today's export choice without the
    format; the exporter's id now names the format.
  - `print(PlanExportChoice choice, {PagePrinter? printer, String? name})`
    returns `Future<bool>`.
  - `import(String importerId, Uint8List bytes)` returns `Future<void>`.
  - **Today's rules hold** (host guide §8):
    - one export or print runs at a time; a second call answers `null`
      (print: `false`);
    - the same answer for a plan with no page where the choice needs one,
      and for a plan replaced while the bytes are being made;
    - pending input (a field being edited) is settled first;
    - the dialog's remembered choice is kept;
    - an error completes the `Future` with that error.
- **Camera:** `panBy`, `zoomBy`, `centerOn`, `fitToView` (today's).
- **Listenables:** `canUndo`, `canRedo` and `activeTool` are
  `ValueListenable`s, so a host's own bar can listen.
- **Undo while drawing:** `undo()` and `redo()` do nothing while a tool is
  part-way through a shape (today's rule).
- **`deleteSelection()`** returns a `bool`. It refuses (`false`) with nothing
  selected, under `delete: false` from a widget, and for a locked object.
- **State:** `locale`, `missingKits`, `locked`, `diagnostics`,
  `symbolsState`, `damaged`.

**Events:** a `Stream<PlanChange>` (object added, changed or removed; plan
replaced). It is domain-neutral; today's `FloorPlanDesignChange` speaks of
tables.

**Documents and views:**
- `load`, `newPlan` and `import` swap the document inside the controller
  and re-run the kit factories (P1, lifetimes). The systems belong to the
  controller, so `DocumentSystems` and its "two shells" trap are not
  ported.
- A controller is shown in one `PlanCanvas` at a time, today's rule. A
  second canvas on the same controller asserts in debug.
- `PlanFormatException` implements `FormatException`. `load` changes
  nothing when it throws (today's contract).

### Permissions

`PlanPermissions` carries:
- the allowed tool ids (`null` = all);
- `move`, `rotate`, `mirror`, `reshape`, `delete`, `changeLayer`,
  `recolor`, `editLayers`, `editPage`, `undo`, `export`, `print`;
- the profiles `full` and `readOnly`. 2b adds the service flags and a
  units-only profile, today's `tablesOnly`.

**Where they are enforced** (the engine cannot tell a rotation from a move,
Facts):
- **Select gates:** move, rotate, mirror, reshape, delete.
- **The palette and `selectTool`:** tool ids. A tool's `needs` are also
  checked against the document's `DraftPermissions`.
- **The panels:** fields gated by P3's `gate`, layers and page.
- **The controller's widget-facing commands.**

`DraftPermissions` gets a group only where a flag maps onto one: no
geometry edits when every geometry-making flag is off, as `readOnly` does
today.

**Host calls and runtime changes:**
- **Host calls are not gated, as today:** a host calling
  `controller.undo()` under `undo: false` still undoes.
- **Permissions can change at runtime.** The widgets rebuild. An active tool
  that is no longer allowed is cancelled and `plan.select` is armed.

### Symbol libraries

- **Loading.** `PlanSymbolLoader` reads every kit's `SymbolLibrarySource`s
  asynchronously, decodes, validates and caches them. A host may share one
  loader and one `SymbolThumbnails` across controllers, today's §4; the
  controller never disposes what it was given. Without one, the controller
  makes and owns its own.
- **State.** `symbolsState` is `loading`, `ready` or `failed`. A plan can
  be edited while symbols load; the gallery shows its loading state.
- **Problems are load problems, not construction errors.** Each is a
  diagnostic, and the load goes on with the rest:
  - a library that cannot be read or decoded is skipped;
  - a library whose kit id is not its kit's is refused;
  - a `key@N` already given by an earlier kit is dropped from the later
    kit.

### The widgets

Each widget takes only the controller, plus its own display options.

| Widget | Role |
|---|---|
| `PlanCanvas` | Rulers, camera gestures, the interaction layer, page chrome, the drawing, the selection and grip overlay, text entry. Fits the plan on its first frame (today's `PlannerView`). Options: `rulers`, `grid`, `snapping`. 2b adds `PlanMode.service`. |
| `PlanToolPalette` | The generic tools, then each kit's, grouped in kit order. Labels come from `tool:<id>`. Holds the fill toggle. |
| `PlanSymbolGallery` | The loaded kits' symbols: search over names and tags, categories, retired symbols hidden (R2), an optional `filter` (today's `symbolFilter`). Choosing a symbol arms `plan.symbol`. |
| `PlanPropertyPanel` | The active tool's settings, while a tool with settings is active, as today. Below them, the one selected object's section: its type's specs (P3) titled by `type:<id>`, or the generic symbol section (name, rotation, mirror, the family's Size menu). The colour row over the selection (P3). The layer field. |
| `PlanLayerPanel`, `PlanPagePanel` | Today's panels. "Live object" comes from the catalog (E1). Editing is gated by `editLayers` and `editPage`. |
| `PlanEditor` | Today's shell layout: top bar; palette or gallery tab on the left; canvas; property, layer and page panels on the right. Options: which panels show, `gallery`, the canvas options, `bar` (today's `editorBar`: actions, `leading`, `trailing`, `visible`), the host's file callbacks, `onExportDialog`, `onPageFlowError`, `printer`, `exportName`, `shortcuts`, `autofocus`, `theme` (a per-view override, today's §9). |
| `PlanShortcuts` | The keyboard (below). `PlanEditor` wraps itself in it; a host composing its own layout uses it. |

### The keyboard

**Commands:**
- File commands (new, open, save, save as, export, print) call the host's
  callbacks, as today.
- Undo and redo; F3 for snapping; F for fill; Escape back to `plan.select`.

**Tool letters:**
- **The generic tools keep today's letters:** V select, L line, P polyline,
  R rectangle, C circle, A arc, T text. `plan.symbol` has none.
- **F is reserved.** Keys a tool handles itself while active (Enter, Delete,
  R and M for symbols) are the tool's business and never conflict.
- **Kit letters follow in load order.** A letter already taken, or F, goes
  to no later tool; that tool gets a diagnostic (A3).

**Text fields keep their keys.** The guard is built from the letters
actually in use, not from today's fixed list of 16.

## P3. Properties, colour and attachment

### Property specs (A4)

```dart
sealed class PropertySpec<T> {
  final String id;                    // word 'property:<type id>.<id>'
  final bool Function(T)? enabled;    // greyed out when false
  final PlanGate? gate;               // a PlanPermissions flag the field needs
}
final class LengthProperty<T>    extends PropertySpec<T> { read, write, min, max }    // mm
final class AngleProperty<T>     extends PropertySpec<T> { read, write }              // radians stored, degrees shown
final class NumberProperty<T>    extends PropertySpec<T> { read, write, min, max, decimals }
final class ChoiceProperty<T, V> extends PropertySpec<T> { values, read, write }      // 'property:<type id>.<id>.<value>'
final class ToggleProperty<T>    extends PropertySpec<T> { read, write }
final class TextProperty<T>      extends PropertySpec<T> { read, write, maxLength }
final class ValueDisplay<T>      extends PropertySpec<T> { read, unit }               // read-only: a room's area, a dimension's value
final class ActionProperty<T>    extends PropertySpec<T> { apply }                    // a button: a door's Flip hinge
```

**Editing:**
- `read(T)` reads a value; `write(T, value)` and `apply(T)` return a changed
  copy.
- The panel commits one `SetComponentCommand<T>`; the parametric system
  regenerates; the whole edit is one undo step.
- **Focus rules are today's:** the target is pinned when a field gains
  focus; the value commits on focus loss or Enter.
- Out-of-range input is refused and the field shows the stored value
  again.
- Panel fields and displays print numbers with the **language's** decimal
  separator, as today's panels do. The plan's own separator (Q0, chosen on
  the Page panel since 0.2.0) governs what is drawn: dimensions, room
  areas, rulers. *(Corrected while planning: revision 3 said the plan's
  separator, which would have changed today's panels.)*

**Units:** `ValueDisplay.unit` is `length`, `area`, `angle` or `none`, and
is printed the same way as the editable kinds.

**Section titles:** a type's section is titled by its `type:<id>` word,
unless its `title(T)` hook returns another word id (an opening titled by its
kind).

**Tool settings** are `PlanToolSettings<S>(initial, specs)`:
- the controller holds one value of `S` per tool;
- the panel edits it with the same specs, whose words are
  `property:<tool id>.<id>`;
- the tool reads it through `PlanServices.settingsOf`.

**The escape hatch:** `section: (context, value, commit) => Widget`, with
`commit(T)` and the kit's words.

**Multiple selection** is out of scope for the specs, as today. The colour
row below is the exception.

### Colour (A3's colour targets)

- `ColourTarget<T>` has `read(T)` and `write(T, swatch)`, where a swatch is
  a name from the plan's palette, as today's `recolorCommand` uses.
- The panel's colour row works over every selected object whose type has a
  target, in one compound command. It is gated by `recolor`.
- This replaces `pickedColors`' closed list. Table colours come in 2b with
  the unit.

### Attachment (A5)

```dart
abstract interface class AttachmentProvider {
  String get kind;                                  // 'wall-face'
  Attachment? attach(AttachmentQuery query);
}
final class AttachmentQuery {
  final Aabb2 footprint;          // the symbol's local box
  final Transform2 current;       // the symbol's transform now (placing: the ghost's)
  final Vector2 pointer;          // raw world point
  final double capture, edgeCapture;
  final bool mirrored;
  final bool mayRotate;           // false: attach only where the current turn fits
  final Set<Handle> exclude;      // the object being moved
  final Attachment? keep;         // the previous answer (hysteresis)
}
final class Attachment {
  final Transform2 transform;     // where the symbol goes
  final Vector2 marker;           // where the plan draws its marker
  final Object token;             // the provider's own (a face run)
}
abstract interface class AttachmentRegistry {
  Attachment? attach(List<String> kinds, AttachmentQuery query);
}
```

**The registry:** it asks the providers of every kind in the symbol's
`attachTo`. When several answer, the marker nearest the pointer wins.

**Who uses it:** `plan.symbol` and `plan.select`'s move resolver, and
nothing else. There is no `WallFaces` and no `againstWallTag` in the plan
library.

**Drawing:** the plan library paints the marker and the ghost, so every
kit's attachment looks alike. `M` mirrors while attached.

**`mayRotate`** is `rotate` from the permissions. With it false, a provider
offers only targets the current turn already fits (today's rule).

**Tests:** the 09c wall-attach tests move with the wall-face provider in
sub-project 3. 2a tests the registry with the test kit's `test-edge`.

## P4. The plan file, the kit set, locks, the failure boundary

### The plan file (A8)

**Saving.** The engine's JSON carries `jetcad.manifest` on its root: the
format (1) and `{kit id: version}` for each kit the plan uses.
- A kit is used when a component type id or a symbol key under its id
  appears in the plan.
- A loaded kit's entry is written with its version.
- A missing kit's entry is kept as read.

**Loading refuses** with `PlanFormatException` and a code when:
- the plan has no manifest;
- the format is above 1;
- the engine's schema check fails (unchanged).

Load diagnostics are kept, not discarded.

**Versions (R6)** are parsed as semver. A plan saved by a newer version of a
loaded kit opens with a warning. A version that does not parse is not
compared and never refuses a load.

### The kit set (A3)

**Errors.** `PlanController(kits:)` throws one `ArgumentError` that lists
every problem:
- a duplicate kit id, type id or tool id;
- the reserved ids `plan` and `jetcad`;
- a type or tool outside its kit's id;
- a type that both contributes and reads places, which `register` refuses;
- each kit's own `validate()`.

**Diagnostics only** (`KitDiagnosticCode`, P4's end):
- a letter that is taken;
- an `attachTo` kind that no provider offers;
- the symbol library problems of P2.

**New `KitProblemCode` values** (R4), landing with 2b's before 0.1.0:
`duplicateKit`, `duplicateType`, `duplicateTool`, `reservedKitId`,
`typeOutsideKit`, `toolOutsideKit`, `typePlaceConflict`.

### Locks: a missing kit, a broken object (A9)

**Which objects are locked:**
- every object whose component type id is under a missing kit's id;
- every placed symbol whose key is under a missing kit's id;
- an object whose type's code failed (below). Such an object is also
  **frozen** (E2): the parametric system treats it as a plain group, so it
  takes no part in any later regeneration, its own or a neighbour's.

**What a lock does:**
- **What a locked object keeps:** it draws as saved; it can be selected as
  a whole.
- **What it loses:** every change: grips, its property section,
  regeneration, move, rotate, mirror, delete, a layer change, a recolour,
  and direct edits of its children.
- **Reporting:** `PlanController.missingKits` lists the missing kits;
  `locked` lists the locked objects.

**How a lock is enforced, in two layers:**
1. **Up front:**
   - the grip provider answers `movable == false` and no grips;
   - the select gates refuse move, rotate, mirror, reshape and delete;
   - the panel shows no section.
2. **On commit:** the lock is an expander stacked after the parametric one,
   as `TableLabelSystem` stacks (Facts). It wraps the command.
   - The wrapper applies the command, then checks every handle in
     `touched` and their ancestors against the locked set.
   - On a hit, it applies the inverse and throws `PlanLocked`.

   This is the apply-check-rollback pattern of the engine's own `_run`;
   a check before apply cannot work, because a command names no handles
   before it applies.

**Where `PlanLocked` is caught:**
- every tool the plan arms, generic or a kit's, is wrapped in a guarding
  `Tool` decorator;
- the panels' commit sites.

`PlanLocked` is a refusal, not a kit diagnostic. The canvas shows a short
hint.

**Undo and a lock.** `undo` and `redo` skip the expander (Facts). A missing
kit's objects are locked from the load, when history is empty. When an
object becomes locked during a session (its code failed), the controller
clears the undo history, so no earlier edit can be undone onto it.

### The failure boundary (A9)

Every kit hook is called at the contract's boundary:
- a kit's `ParametricType` is wrapped in a guarding adapter;
- its tools in the guarding decorator;
- its grips, providers and sections in guarded calls.

| Throws | Outcome |
|---|---|
| any `ParametricType` hook: `reach`, `references`, `pageKey`, the place hooks, `dissolves`, `generate`, `diagnose` | The adapter rethrows it as `KitHookFailure(kitId, typeId, hook, error)`; the engine rolls the edit back and rethrows it unchanged (Facts). The controller then **probes** that type's objects: for each, `ParametricSystem.probe` (E2) runs its hooks in isolation, and the controller freezes and locks every object that throws (E2). It clears the history (above) and executes the user's command once more. If the retry fails again, the command is refused. So one broken object blocks one edit, once, and never its neighbours afterwards. |
| the same hooks, on load | After a load, the controller probes every kit object's `reach` and `references` once, so an object that is already broken is frozen before the first edit. |
| a rollback that throws | The engine's `PartialMutationError` (E3). The controller calls `commands.notifyLoaded()`, which clears history and rebuilds the index and caches. It marks the plan `damaged`, shows a warning, and reports a diagnostic. Saving a damaged plan first encodes and decodes it; if that fails, `save` throws `PlanFormatException` (`damagedUnsavable`) and writes nothing. |
| the component's `fromJson`, on load | E4: the component is kept raw, as an unknown type is. The object is locked and frozen. The diagnostic names it by its handle (`Diagnostic.handles`). |
| grips | That object has none; a drag in flight is cancelled. |
| an attachment provider | Taken as no attachment. |
| a tool's factory | The tool is disabled. |
| a tool's event | The tool is cancelled and `plan.select` is armed. |
| a tool's painting | The overlay is skipped; the tool is cancelled after the frame. |
| a property's `write` or `apply` | The field shows its stored value. |
| a section builder | A small "section failed" box in its place. A widget it returned that fails while building shows Flutter's `ErrorWidget` in its place only; the plan stays usable. |

**Diagnostics.** Each case produces a `KitDiagnostic` (kit id, type or tool
id, code, error), once per subject and code. `KitDiagnosticCode` includes:
`hookFailed`, `rollbackFailed`, `damagedUnsavable`, `componentUnreadable`, `letterTaken`,
`attachmentKindUnoffered`, `libraryUnreadable`, `libraryKitMismatch`,
`symbolDuplicate`, `kitMissing`, `kitNewer`. `PlanController.diagnostics`
is a listenable list.

## P5. Export and import, words, theme

**Registries (A17.4):**

```dart
abstract interface class PlanExporter {
  String get id;              // 'plan.pdf', 'plan.png'; a host's: 'acme.dxf'
  String get extension;
  String get mimeType;        // what today's onExport passes
  Future<Uint8List> export(PlanExportRequest request);
}
final class PlanExportRequest {
  final DraftDocument document;   // a copy made when the export starts
  final PageComponent? page;      // null for a "drawing" export, as today
  final PlanExportChoice choice;
  final Set<Handle> omitted;      // objects of types with exported: false
  final PlanExportFonts fonts;
}
abstract interface class PlanImporter {
  String get id;
  List<String> get extensions;
  Future<String> import(Uint8List bytes);   // a plan's text (decision 4)
}
```

- **Built in:** PDF and PNG (`plan.pdf`, `plan.png`). A host adds its own.
- **Imported text without a manifest** gets an empty one before it is
  loaded, so an imported drawing opens as plain geometry (A17.5).
- **Omitted types:** objects of a type with `exported: false` are listed in
  `omitted` (today's `exportOmitOwners`).
- **The dialog and printing:** the export dialog and printing work as
  today, listing the registry instead of a closed enum.
- **The exporter's document is a copy.** It is decoded from the plan's text
  when the export starts, so edits made while the `Future` runs cannot race
  with it.
- **Who sees `DraftDocument`:** an exporter does, since exporters are code
  that renders. A host that only uses the built-in exporters never does
  (decision 4).

**Words:**
- `PlanStrings` (English, German, Turkish) holds the plan library's own
  words.
- A kit's words come from `KitNames`, falling back to English.
- **The locale:** the widgets push the app's `Localizations` locale into
  `controller.locale`. `KitWords` reads it live, so tools and panels follow
  a change of language.
- **Fonts:** registering the plan's fonts and their licences (today's §2)
  moves to the plan library unchanged.

**Theme:**
- `PlanTheme` is a `ThemeExtension`: the generic part of `FloorPlanTheme`
  (canvas, selection, grips, the attachment marker). 2b adds statuses and
  groups.
- Touch comes from the Flutter layer, as today.

## P6. The remaining contract inputs

- **R2:** `jetcad.symbol` and `CatalogSymbol` gain an optional `retired`
  (absent reads `false`). The gallery hides retired symbols.
- **R3:** `conformance()` gains additive named parameters: type, tool and
  property ids and their words. Each id must be under the kit's id, and its
  English must be complete.
- **R5:** `docs/kits.md` says why the engine's types bind the contract, and
  what the codec's byte equality means for a kit's CI.
- **R7:** rule 11 refuses an outline whose width, `2·area/perimeter`, is at
  or under `Tolerance.linear`, instead of testing its area.
- **R1, and 2b's codes of R4,** belong to 2b.
- **A per-edit system hook for kits** (today's `TableLabelSystem`) belongs to
  2b with the unit. If 2b adds `PlanKit.systems`, it lands before 0.1.0.

## P7. Today's design-mode host API, mapped

Each capability of today's host guide (§2-§5, §8-§11) and
`FloorPlanEditorCapabilities`, and where it goes. Sub-project 4's parity
table (A14) takes these rows over and adds the test for each.

| Today | Where |
|---|---|
| `FloorPlanController(json:)`, `designJson`, `markSaved`, `dirty`, `load` (a `FormatException`, nothing changed), `newPlan` (the locale's separator) | 2a: `PlanController(json:)`, `save`, `markSaved`, `dirty`, `load`, `newPlan` (P2) |
| `designChanges` | 2a: `changes` (`PlanChange`), object-level; amended by 2b: its unit-level events are 2b's `unitChanges` |
| `selectTool(FloorPlanTool)`, `deleteSelection`, `undo`, `redo` | 2a: by tool id (P2) |
| `exportPlan(choice, {name})` → `FloorPlanExport?` (bytes, name, MIME type) and its rules; `printPlan({printer, name})` → `bool`; `onExport`; the view's `exportName` | 2a: `export` → `PlanExport?`, `print` → `bool`, the same rules, `PlanEditor(exportName:)` (P2) |
| `undo`/`redo` doing nothing mid-shape; `canUndo`/`canRedo` listenable | 2a (P2) |
| `deleteSelection()` → `bool` and its refusals | 2a (P2) |
| The per-view `theme:` | 2a: `PlanEditor(theme:)` |
| The camera: `panBy`, `zoomBy`, `centerOn`, `fitToView`, `minScale`/`maxScale` | 2a: `PlanController` (P2) |
| `fitToTables` | 2b |
| One view at a time | 2a: one `PlanCanvas` at a time (P2) |
| Symbol sources, a shared loader and cache, never disposed by the controller | 2a: `PlanSymbolLoader`, `SymbolThumbnails` (P2); the kits carry the sources |
| Capabilities: `tools` | 2a: `PlanPermissions` tool ids |
| `move`, `rotate`, `mirror`, `reshape`, `delete`, `changeLayer`, `recolor`, `undo`, `export`, `print`, `editLayers`, `editPage` | 2a: `PlanPermissions` (P2) |
| `selectionPanel`, `layerPanel`, `pagePanel`, `symbolPalette`, `symbolFilter`, `rulers`, `grid`, `snapping` | 2a: `PlanEditor`, `PlanCanvas`, `PlanSymbolGallery` options (P2) |
| Profiles `full`, `readOnly`; changing capabilities at runtime | 2a (P2) |
| Profile `tablesOnly`, `selectTablesOnly`, `renumber` | 2b |
| `editorBar` (actions, `leading`, `trailing`, `visible`) | 2a: `PlanEditor(bar:)` |
| `serviceBar`, the table inspector, overlays on tables | 2b |
| `onExportDialog`, `onPageFlowError`, `printer` | 2a: `PlanEditor` options |
| `shortcuts: false`, `autofocus`, the shortcut guard, the web's context menu | 2a: `PlanEditor`, `PlanShortcuts` |
| Fonts (§2), languages (§3) | 2a (P5) |
| Themes (§9): the generic part | 2a: `PlanTheme`; statuses and groups 2b |
| Touch (§10) | 2a, from the Flutter layer |
| §6 (the service layout) and §7 (tables, statuses, selection, colours, the band, groups, zones, overlays, events, host data) | 2b |
| §11, "what a host must never assume" | Each row with its section above; sub-project 4 lists them |
| The restaurant symbols' copy steps (§1); the host probe, the README, screenshot and guide checks (A15) | Sub-project 4 |

## E. Engine seams (A12)

Each seam is argued here and lands with its own test.

- **E1, `ParametricCatalog.typeIds` and `typeIdOf(CommandTarget,
  Handle)`:** which types are registered, and which one a group is. They
  replace `isParametricObject`, the if-chain of `ObjectGrips`, and the
  layer picker's list. No public query exists today (Facts).
- **E2, frozen objects:** `ParametricSystem` takes a predicate
  `isFrozen(Handle)`. A frozen object is left out of every survey, view and
  regeneration and treated as a plain group, as an unregistered type is
  today. No hook of its type is called for it. This is the only way to keep
  a broken object out of its neighbours' edits, because `reach` gets no
  handle and `generate` cannot answer "keep my children" (Facts). With it,
  `probe(Handle)` runs one object's hooks (`reach`, `references`,
  `generate` through the system's own view) in isolation, changes nothing,
  and returns the first error or `null`: the controller's probe (P4).
  Writing a frozen object's own type's component is refused with
  `NonLiveWriteError`, a `StateError` subtype naming the handle (the
  refusal of any write on a group that is not live), so the plan library
  turns it into `PlanLocked` (amended in the final review).
- **E3, a typed partial mutation:** the "partially mutated" `StateError` of
  `regeneration.dart:735` and `:1040` becomes `PartialMutationError`, a
  `StateError` subtype, so the controller tells it apart without matching
  message text.
- **E4, a component that cannot be read keeps its data:** when a registered
  factory throws during load, the registry keeps the component raw, as it
  keeps an unknown type, and adds a `Diagnostic` naming the handle to a list
  the codec passes into `ComponentRegistry.loadJson`, instead of aborting
  the load.

No engine change is needed for the lock, because expanders already stack
(Facts). No engine change is needed to name a failing type either: the
guarding adapter knows its type id and the engine rethrows its error
unchanged. The Flutter layer needs no change.

## Package layout

```
packages/jet_cad_2d_kit/lib/src/kit/   plan_kit, plan_type, plan_tool, plan_services,
                                       properties, colour, attachment, kit_diagnostic
packages/jet_cad_2d_plan/lib/
  jet_cad_2d_plan.dart                 the barrel
  src/controller/                      PlanController, permissions, services, shared cache
  src/kits/                            kit-set validation, the catalog and grip composition,
                                       the guarding adapter and decorator, locks
  src/symbols/                         PlanSymbolLoader, the gallery's model
  src/file/                            manifest, load, save, PlanFormatException
  src/canvas/  src/panels/  src/editor/  src/shortcuts/
  src/tools/                           the generic tools, plan.symbol, the move resolver
  src/attach/                          the registry, marker painting
  src/export/                          the registries, PDF, PNG, print
  src/l10n/  src/theme/  src/fonts/
packages/jet_cad_2d_plan/example/      PlanEditor with no kit
```

## Tests

**The kits under test:**
- **The test kit** (`test/support/test_kit.dart`):
  - one parametric type with all eight property kinds, a gate, a title
    hook, a colour target, grips and an escape-hatch section;
  - a second type that both contributes and reads places, for the kit-set
    refusal;
  - one tool with settings;
  - a `test-edge` attachment provider;
  - English and Turkish words, no German (the fallback).
- **The throwing kit:** every hook throws, one at a time and all together.
  For each hook, a named mutant (that hook's guard removed) turns a test
  red. Two cases are named: "an object whose `reach` throws; after one
  refused edit, a plain line is drawn and edited", and "a broken object
  beside a working one of another type; after the probe, the working one's
  edits regenerate and the broken one keeps its geometry".

**What each test group shows:**
- **Locks:** a missing kit's object, a broken object and a locked symbol
  each refuse grips, the gates, the panel and a forged command. The forged
  command checks the apply-check-rollback: the document is unchanged and
  history is unchanged.
- **Lifetimes:** after `load`, no factory product of the previous document
  is reachable. The `shared` cache is disposed, and a tool armed before
  `load` is gone.
- **Covariance:** a kit set with two types of different `T` registers,
  edits, recolours and shows its fields under the test runner's checks.
- **Symbols:** loading, ready and failed states; a duplicate key across
  kits dropped from the later kit; a library under the wrong kit refused; a
  shared loader not disposed.
- **Permissions:** each flag at its enforcement points; a host's `undo()`
  under `undo: false`; a change at runtime cancelling a forbidden active
  tool.
- **Each widget alone**, with only a controller: the composition is real.
- **Ported, with assertions unchanged (A12):**
  - selection and its band;
  - layers, page, undo;
  - export, text entry;
  - the shortcut guard;
  - the panel-focus traps (Plan 06's lessons).
- **The invariant:** a paint-allocation test for the plan library's canvas
  (A12, CLAUDE.md).
- **The engine seams:** each has a test whose named mutant is the seam
  removed.
- **The manifest:**
  - each refusal has its code;
  - a missing kit's entry is kept on save;
  - a newer kit warns;
  - a version that does not parse still opens;
  - an import without a manifest opens as plain geometry.

## Exit gate

- **Local gates:**
  - CLAUDE.md's gates;
  - for `jet_cad_2d_kit` and `jet_cad_2d_plan`: `flutter test`,
    `flutter analyze`, `dart format`;
  - `cd tool/ci && dart test`;
  - `dart run tool/ci/check_kit_deps.dart`.
- **CI:** a `jet_cad_2d_plan` job, and a publishable dry-run entry with 0
  warnings.
- **Review:** one Opus review of the whole branch, then its fix wave; the
  ledger is archived onto the branch as its last commit.
- **The old packages stay untouched** (A12).

## Out of scope

- The service mode and everything in decision 1's 2b list, including R1 and
  P7's 2b rows.
- **Sub-project 3:** the architecture kit's types, the furniture library,
  and the wall-face provider.
- **Sub-project 4:** the restaurant kit, the demos, the pictures, the host
  guide, parity, and the CI moves.
- Multiple selection in the property specs.
- Renaming the engine's `Draft*` family (decision 4).

## Amendments

From the 3a spec
([2026-10-15-architecture-kit-design.md](2026-10-15-architecture-kit-design.md),
"Amendments to other specs"), each written by the task that lands it.

- **P3, property specs and the section builder** (3a C1.1, C1.7): a spec
  is bound with the object it is shown for (`PlanObject`: document,
  handle, world and the kit's words; none for a tool's settings); `TextDisplay` is a read-only
  line read from the object, omitted when it reads nothing;
  `LengthProperty.range` bounds a length by the object, inclusive, a null
  range refusing every value; every spec takes `visible`, evaluated when
  it is bound, and a hidden field takes no room; an action whose gate the
  permissions refuse is hidden, not read-only. The escape hatch is
  `(context, PlanSection<T>)`, the section holding the value, the commit,
  the words, the object and the kit's services. `PlanKit.validate` refuses
  a `TextDisplay` or a `range` in a tool's settings (`settingsNeedObject`).
- **P2, the status line and tool notices** (3a C1.2): a kit's `Tool` may
  implement `ToolNotice` (a `ValueListenable<KitText?>`); the guard
  forwards it (`GuardedTool.notice`; a throw is one `hookFailed`, then
  null); `PlanController.toolNotice` is the active tool's notice and
  `textOf` puts a `KitText` into words (the host's first, then the kit's,
  in the current locale). `PlanEditor`'s status line is the tool's label,
  then ` — n selected` with a selection, then ` — <notice>`, worded when
  it is read, so a language switch re-words it at once.

## Risks

- **The contract is settled against a test kit only.** Sub-project 3's six
  types are the real test. A field they need goes into this spec as an
  amendment before the wave publishes 0.1.0.
- **The guarding adapter sits on the parametric hot path.** It must
  allocate nothing per call in steady state. The existing query-allocation
  invariant covers it once the adapter is in the catalog.
- **The size of the port.** The ported tests are the oracle (A12).

## Revision history

- **Revision 1** (`c78e2a8`): the design approved in chat.
- **Amended in the final review** (2a's whole-branch review, finding I1):
  E2's refusal of a write on a frozen object is typed
  (`NonLiveWriteError`, naming the handle), and the lock maps it to
  `PlanLocked`.
- **Revision 3:** the re-review of revision 2.
  - **N1, N2:** a broken object is frozen (new E2), found by probing after a
    failed edit and after a load; it no longer blocks its neighbours.
  - **N3:** the attribution moves into the adapter, and the old E2 is
    dropped.
  - **N4:** the damaged state rebuilds through `notifyLoaded()`, uses the
    typed `PartialMutationError` (E3), and saves only what decodes.
  - **N5:** a lock covers every change; history is cleared when an object
    becomes locked mid-session.
  - **N6:** the export request carries a copy and an optional page;
    decision 4 names the exporter case.
  - **N7:** P2 and P7 take the export, print, undo, delete, listenable and
    theme rules.
  - **N8:** `registerInto` takes the catalog only. **N9:** E4's plumbing
    and `Diagnostic.handles`.
- **Revision 2:** the Opus review's findings, applied as follows.
  - **B1, the lock:** now apply-check-rollback plus the up-front gates,
    caught by the guarding decorator.
  - **B2, the permissions:** enforced at the gates, the palette, the panels
    and the controller's own commands; host calls are not gated.
  - **B3, symbol libraries:** asynchronous loading with a state; problems
    are diagnostics; a shared loader and thumbnail cache.
  - **I1, E2:** now attribution only. **I2, the lock seam:** E3 is dropped
    and the lock stacks on the expander; the new E3 is the component that
    cannot be read.
  - **I3:** the per-edit hooks are guarded. **I4:** erased operations.
    **I5:** camera and the effective snap flag. **I6:** lifetimes and the
    locale.
  - **I7:** `current` and `mayRotate`. **I8:** colour targets. **I9:**
    display and action specs, gates, titles, when tool settings show.
  - **I10:** the per-edit system hook goes to 2b. **I11:** the P7 table.
  - **M1-M13:** line numbers corrected, the separator explained, word ids
    fixed, `jetcad` reserved, the place conflict listed, the codes named,
    the export request defined, the manifest on import, the letters and
    reserved keys, `shared` keyed by kit, painting and section guards, room
    for the service copy, the CI moves to sub-project 4, `needs` as
    capabilities, symbols of missing kits locked.
