# The kit architecture: a domain-neutral plan library and pluggable kits — design

**Date:** 2026-10-13. **Status:** revision 1, the umbrella spec, written after
the human approved the target architecture in chat; awaiting the human's
review of this file. Each sub-project (A13) gets its own spec and plan; this
file binds them all.

**Asked for by the human, 2026-10-13:** *"restoran sembolleri ayrı paket
olmalı. readme'deki ekran görüntüleri de buna uygun olarak seçilmeli.
ileride yeni sembol kütüphaneleri olacak (örneğin sinemada ya da uçakta
koltuk seçme, vs) yapımız ve dağıtım stratejimiz buna uygun olmalı."* Then:
*"maliyeti şimdilik gözardı edelim. amacımız ideal mimariyi oluşturmak
olsun"*, and *"best-practice'lere uygun sade ve şık bir mimari olsun."*

**Branch:** `feat/kit-architecture`, cut by hand from `main` at `1b4670b`
(`main` equal to `origin/main`), worktree `.claude/worktrees/kit-architecture`.
**Size:** XL, four sub-projects, one release wave (A13).

## Decisions taken in the brainstorm (the human, 2026-10-13)

Each was put as a question with options; the quote is the human's answer.

1. **The restaurant symbols are published, now, at 0.x** (*"Şimdi, 0.x
   olarak"*). This closes STATUS's "the fourth step, deferred" (the
   restaurant symbols were to wait for a few planner releases and a settled
   schema and versioning policy; the SWOT in chat, *"tamam yaz"*). The
   reasons for waiting were that a pub.dev release cannot be taken back and
   that the keys become a contract once published. A16 answers both.
2. **Domain packages are kits that carry symbols and parametric types**
   (*"Sembol + parametrik (kit)"*): a cinema kit will bring a parametric
   seat row, not only static symbols.
3. **Independent versions** (*"Bağımsız, 0.1.0'dan"*): a kit has its own
   semver from 0.1.0, not the planner's number.
4. **A demo per domain** (*"Alan başına demo"*), and *"gerekirse demo
   uygulamalar da farklı olabilir"*.
5. **The ideal architecture, cost set aside** (*"maliyeti şimdilik
   gözardı edelim"*).
6. **The plan library is composed of widgets around a controller, and the
   kits sit on a shared contract** (the human's own design, refined in two
   steps): *"canvas (design + preview), property panel ve sembol galerisi
   widget'larını içerir; bunlar controller aracılığıyla beraber çalışır;
   plan kütüphanesi budur"*, then *"hem plan hem de kitler jet_cad_2d_kit'e
   bağlansa, base type vs orada olsa nasıl olur?"*: the plan and the kits
   both depend on `jet_cad_2d_kit`; no kit depends on the plan.
7. **Names:** the plan library is `jet_cad_2d_plan` (the human proposed
   `jet_cad_plan`, *"o zaman jet_cad_plan olsa?"*, after `jet_cad_planner` and
   `jet_cad_designer` were weighed); the contract is `jet_cad_2d_kit`; kits are
   `jet_cad_2d_kit_<domain>`. The second mode keeps its name, `service`
   (*"service uygun bence"*).
8. **Behaviour leaves free-text tags** (*"against-wall yerine daha jenerik
   bir ad olabilir"*, then *"uygun"*): attachment becomes a structured field
   naming target kinds (A5); a size family becomes a structured field;
   tags only feed search.
9. **No backward compatibility; a rewrite** (*"geriye dönük uyumluluk şu
   an gerekli değil"*, then *"hiçbir şeyi tutmaya gerek yok, rewrite
   tercih edelim"*). No deprecated aliases, no bridge release, no reading of
   today's plans. The human confirmed that no real customer plan exists
   (*"Yok, sorun değil"*).
10. **Full host-API parity before the release wave** (*"Evet, tam
    eşdeğerlik"*): every capability in today's host guide §4–§11 has its
    counterpart in `jet_cad_2d_plan` before anything is published (A14).
11. **Every package of this ecosystem carries `2d`** (*"3d tamamen kendi
    ekosistemine sahip olacak ve aralarında bir ilişki öngörmüyorum
    şimdilik. 2d kullanımını tekrar değerlendirelim"*, then *"harika olur!
    adları güncelleyelim"*). The 2D ecosystem is `jet_cad_2d`,
    `jet_cad_2d_flutter`, `jet_cad_2d_kit`, `jet_cad_2d_plan` and
    `jet_cad_2d_kit_<domain>`; a future 3D ecosystem names its own
    `jet_cad_3d_*` and shares nothing with it. Dart type names carry no
    `2d` (`PlanController`, `PlanKit`): the package names the family, the
    type the concept.

## Facts (at `1b4670b`, read from the code, not assumed)

- **Published:** `jet_cad_2d`, `jet_cad_2d_flutter` and `jet_cad_floor_plan`,
  all at 0.7.2 (tags `<package>-v0.7.2` → `5c244b1`). Unpublished:
  `jet_cad_restaurant_symbols` (`publish_to: none`), `jet_cad_2d_gpu`,
  the dormant `jet_cad`.
- **The engine's parametric seam is open.** `ParametricType<T>`
  (`jet_cad_2d/lib/src/parametric/parametric_system.dart:25-173`: `reach`,
  `generate`, `diagnose`, `references`, `pageKey`, `dissolves`, the place
  system) and `ParametricCatalog.register(typeId, factory, type)` (:495).
  The catalog has no public query listing what is registered.
- **Unknown component types survive a load** verbatim
  (`document/component.dart:295-314`), and generated children are ordinary
  entities in the file (`codec/json_codec.dart:68-78`; load trusts geometry,
  parametric spec D10). An object whose type is not registered still draws,
  but becomes a plain group: no regeneration, no grips, no editor section,
  and its children lose the "no direct edit" protection.
- **The planner's own catalog is closed.** `parametricCatalog`
  (`jet_cad_floor_plan/lib/src/parametric/catalog.dart:27-39`) registers six
  types with ids `floor_planner.box|wall|opening|separator|room|dimension`.
  Nine further closed lists enumerate them or their tools: `isParametricObject`
  (`layers/layer_picker.dart:23-29`), `ObjectGrips._of`
  (`parametric/object_grips.dart:80-86`), the `FloorPlanTool` enum
  (`host/editor_capabilities.dart:13-30`), the palette `_entries` with their
  letters (`planner_shell.dart:517-623`), `kShellLetterKeys`
  (`shortcut_guard.dart:8-25`), the per-tool strings (`l10n/strings.dart:61-110`),
  the Selection panel's per-type sections (`selection_panel.dart:149-158`,
  :1251-1430), `pickedColors` (`colors/color_picker.dart:17-35`),
  `exportOmitOwners` (`export/export_bytes.dart:28-29`) and the room inputs
  (`parametric/room_inputs.dart:96-148`, :296-314).
- **The symbol contract lives inside the planner.** `lib/src/symbols/`:
  catalog types named `FurnitureSymbol` and `FurnitureShape` although every
  library uses them; the library builder; the validator (about 25 rules,
  `symbol_library.dart:116-355`); `SymbolComponent` (`jetcad.symbol`) and
  `SeatingComponent` (`jetcad.seating`); `SymbolNames`; the loader. A
  `.jetlib` is the engine codec's JSON of a document of definitions. Its
  builder and decoder import the whole parametric layer through
  `registerAppComponents` although only the two symbol components are
  needed.
- **Behaviour hides in tags:** `against-wall` (wall attachment while placing
  and moving) and `family:<id>` (the Size menu), in
  `symbol_library.dart:18-22`. Servability is the presence of
  `SeatingComponent`; the served top is the first leaf by convention.
- **Service mode is table-shaped.** A table is a root-level instance whose
  definition carries `SeatingComponent` (`tables/table_index.dart:49-59`);
  the controller, the view, the painters, the picker and the select tool
  all take their identity from it. The host barrel exports 50 names, 23
  with `FloorPlan` and 13 with `Table` in them.
- **Wall attachment** is a shell-built `WallFaces` over wall bands, handed to
  `SymbolPlaceTool` and to `SelectTool`'s move resolver
  (`planner_shell.dart:428-497`, `symbols/wall_attach.dart`).
- **Apps:** `apps/floor_planner` drives `PlannerShell` through the internal
  `editor.dart` barrel, design only. `apps/restaurant_demo` uses only the host
  barrel, with the furniture and restaurant sources and two sample plans.

## Purpose

One plan library that knows no domain, and domains that plug into it.
Restaurant, architecture and, later, cinema and aircraft each ship as a kit:
the same widgets design and operate a restaurant floor, a cinema hall or a
cabin. A host installs the plan library and the kits it needs. Nothing in
the plan library names a wall, a table or a seat.

## A1. The packages and their dependencies

```
jet_cad_2d                    engine (unchanged in role)
└─ jet_cad_2d_flutter         Flutter layer: canvas painting, camera, selection, Tool
   └─ jet_cad_2d_kit             the contract: base types and interfaces
      ├─ jet_cad_2d_plan         the plan library: controller and widgets
      ├─ jet_cad_2d_kit_architecture
      ├─ jet_cad_2d_kit_restaurant
      └─ jet_cad_2d_kit_<domain> (later: cinema, aircraft, ...)
```

- **The plan and every kit depend on `jet_cad_2d_kit`; no kit depends on
  `jet_cad_2d_plan`, and no kit depends on another kit.** This is Flutter's
  federated-plugin shape (`url_launcher` and its implementations over
  `url_launcher_platform_interface`). Kits cooperate only through the
  contract (A5).
- A host depends on `jet_cad_2d_plan` and on the kits it loads. The engine and
  the Flutter layer come transitively.
- A CI check (A15) fails when a kit's pubspec or any of its Dart files names
  `jet_cad_2d_plan` or another kit.
- `jet_cad_2d_kit` stays narrow: a type belongs there only when a kit needs to
  name it. Anything only the plan library uses stays in the plan library.

## A2. `jet_cad_2d_kit`: the contract

Two public libraries:

- `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`, the contract (Flutter: it names the
  Flutter layer's `Tool`).
- `package:jet_cad_2d_kit/authoring.dart`, the authoring toolkit, **pure
  Dart**: a kit's library generator runs under plain `dart run`, and a kit's
  conformance test runs under `dart test` or `flutter test`.

The plan components, the library format (encoder, decoder, validator) and
`KitNames` are pure Dart, in files both libraries export: the format has one
owner, and the authoring side never imports Flutter.

**The contract holds:**

| Concept | What it is |
|---|---|
| `PlanKit` | A kit's descriptor: its `id`, its `version`, and what it contributes (below). |
| Plan components | The components the contract writes into a plan: the symbol identity, the service unit (A6), the manifest (A8). Their type ids start with `jetcad.`. |
| The library format | `.jetlib`: encode and decode, in one place, with the validator. |
| `SymbolLibrarySource` | A labelled reader of a library's bytes. The words belong to the kit (`PlanKit.names`), not to a source (sub-project 1, K5). |
| `PlanType` | A parametric type as a kit contributes it: the engine's `ParametricType`, its component factory, its type id, its properties (A4), its grips, its display name. |
| `PlanTool` | A palette entry: tool id, display name, icon, suggested letter, and a factory from `PlanToolServices` (snap, l10n, settings, the attachment registry) to a Flutter-layer `Tool`. |
| Properties | Declarative property specs (A4). |
| Attachment | `AttachmentProvider` and the target kinds (A5). |
| `KitNames` | A kit's words per locale: symbol names by key, categories, tool, type and property names. |
| Diagnostics | The shape of a kit's diagnostics (A9). |

**The authoring toolkit holds:** the catalog language (`CatalogSymbol`,
`CatalogShape` with line, polyline, circle and arc), the library builder, the
shared shape helpers (a chair, chairs around a circle, a stool: today copied
between the furniture and restaurant catalogs), and the conformance test
(A16).

A sketch, to fix the shape; sub-project 1's spec fixes the API:

```dart
final PlanKit restaurantKit = PlanKit(
  id: 'restaurant',
  version: '0.1.0',
  symbols: [restaurantSymbolSource],
  names: restaurantNames,
);

final PlanKit architectureKit = PlanKit(
  id: 'architecture',
  version: '0.1.0',
  symbols: [furnitureSymbolSource],
  types: [wallType, openingType, separatorType, roomType, dimensionType, boxType],
  tools: [wallTool, doorTool, windowTool, gapTool, roomTool, separatorTool, dimensionTool, boxTool],
  attachments: [wallFaceProvider],
  names: architectureNames,
);
```

## A3. `jet_cad_2d_plan`: the plan library

Composable widgets bound to one controller, in the manner of
`QuillEditor` and `QuillToolbar` over a `QuillController`:

| Widget | Role |
|---|---|
| `PlanController` | Holds the plan, the loaded kits, the selection, the mode, undo, and every host-facing command and event. The host owns and disposes it. |
| `PlanCanvas` | The canvas, in `PlanMode.design` or `PlanMode.service`. |
| `PlanToolPalette` | The tools of the loaded kits plus the generic ones. |
| `PlanPropertyPanel` | The selection's properties, drawn from the specs (A4). |
| `PlanSymbolGallery` | The symbols of the loaded kits: search, categories, placing. |
| `PlanLayerPanel`, `PlanPagePanel` | Layers; page, scale and paper. |
| `PlanEditor` | A ready composition of the above in the default layout, for a host that wants one widget. |

- **Kits are given by the host:** `PlanController(kits: [architectureKit,
  restaurantKit])`. The plan library ships no domain kit; without kits it is
  an empty canvas with the generic tools (select, line, polyline, rectangle,
  circle, arc, text).
- **No closed list.** The palette, the shortcuts, the property sections, the
  grips, the layer rules for live objects, the colour targets and the export
  rules are derived from the loaded kits. Every closed list in the Facts
  disappears.
- **Generic behaviours stay in the plan library:** selection and its band,
  layers, pages, undo, export and print, the service mode (A6), themes,
  touch, fonts, the plan library's own words.
- **Load-time validation of the kit set** (A9): a duplicate kit id, type id,
  tool id or `key@version` is an error; a letter wanted by two tools goes to
  the kit loaded first, and the later tool gets none, with a diagnostic.
- **Locales:** the plan library speaks English, German and Turkish. A kit's
  words fall back to English for a locale it lacks.

## A4. Properties are declarative

A `PlanType` lists its editable properties as specs: a length (unit, bounds),
an angle, a number, a choice, a toggle, a text. Each spec reads its value from
the type's parameters and writes a changed copy back. The property panel
draws every spec with its own controls, so every kit's section looks alike,
follows the theme and speaks the locale. A type that needs a control no spec
describes contributes a widget builder; that is the escape hatch, not the
rule.

## A5. Attachment: target kinds instead of `against-wall`

- **A provider offers targets of a named kind.** The architecture kit's
  provider offers `wall-face` targets, the straight runs of a wall's faces
  (today's `WallFaces`). A later cinema kit could offer `seat-row`.
- **A symbol declares the kinds it attaches to,** in a structured field of
  its identity: `attachTo: ['wall-face']`. An empty list attaches to nothing.
- **The plan library mediates.** While a symbol is placed or moved, it asks
  the providers of the symbol's kinds for an attachment at the raw pointer.
  A provider answers with the attached transform and a marker, or with
  nothing. Neither the symbol's kit nor the provider's kit knows the other.
- **A size family is a field too:** `family: 'bed-double'`. Tags are search
  words only and carry no behaviour.
- **Today's wall-attach behaviour is the parity bar** (A14): the capture
  distance, the ghost on the face, the marker, `M` to mirror while attached,
  the face side under a mirrored group; the 09c tests are ported with it.

## A6. The service unit

- **Service mode works on units, not on tables.** A unit is a placed symbol
  whose definition carries the contract's unit component: its `kind`
  (`table` or `seat`; open to later kinds), its `capacity`, and how its
  label is formed.
- A restaurant table is a unit of kind `table` with a capacity of seats. A
  cinema seat is a unit of kind `seat` with a capacity of one and a
  row-and-number label, which the cinema kit's seat-row type assigns.
- Statuses, groups, zones and focus, overlays, events and host data address
  units by id, whatever their kind. The host API names them accordingly (a
  `PlanUnit`, not a `FloorPlanTable`); sub-project 3's spec fixes the names.
- What a seat row generates and how seats are numbered is the cinema kit's
  business, later. The contract only has to carry it, and A16's conformance
  test must hold for a seat kit as for a table kit.

## A7. Identity and naming

| What | Rule |
|---|---|
| A kit's id | Its domain, lower case: `architecture`, `restaurant`. |
| A kit's package | `jet_cad_2d_kit_<id>`. |
| A type id | `<kit id>.<type>`: `architecture.wall`, `architecture.opening`. |
| A symbol key | `<kit id>.<kind>.<variant>`, a version `@N`: `restaurant.table.rect.four@1`. |
| A contract component | `jetcad.<name>`: `jetcad.symbol`, `jetcad.unit`, `jetcad.manifest`. |
| A tool id | `<kit id>.<tool>`: `architecture.wall`. |

The conformance test (A16) enforces that a kit's keys, types and tools use
its own id. A key's version follows the rules of A16.

## A8. The plan file

- **A plan is the engine's document** (the engine's codec and schema) **with
  a manifest** on its root: the `jetcad.manifest` component, carrying the
  plan format's version (1) and, per kit the plan uses, the kit's id and the
  version that last saved it.
- **A file without a manifest is refused** with a clear error: no plan from
  `jet_cad_floor_plan` is read (decision 9).
- A plan copies every placed symbol's definition, as today: a plan never
  needs a library to draw, and changing the libraries a host ships never
  migrates a saved plan.

## A9. A missing or failing kit

- **A plan whose manifest names a kit that is not loaded opens**, and its
  objects of that kit draw as they were saved: their generated geometry is in
  the file (Facts). They are read-only: no regeneration, no grips, no
  property section, no direct edits of their children. The controller
  reports the missing kits, so a host can say so.
- **A kit's code that throws does not take the plan down.** A `generate`,
  a grip, a provider or a tool that throws is caught at the contract's
  boundary: the object keeps its last geometry, the action is not applied,
  and a diagnostic names the kit and the type or tool. This boundary is
  tested by a kit whose every hook throws.

## A10. Versions and the release wave

- `jet_cad_2d_kit` and every kit start at **0.1.0** and follow semver on their
  own. `jet_cad_2d_plan` starts at **0.8.0**, the same product line as
  `jet_cad_floor_plan` 0.7.x.
- The engine and the Flutter layer are released only if a sub-project
  changes them (A12); their README package tables gain the new packages at
  their next release.
- **The order of the wave:** the engine and the Flutter layer if changed,
  then `jet_cad_2d_kit`, then `jet_cad_2d_plan`, `jet_cad_2d_kit_architecture` and
  `jet_cad_2d_kit_restaurant` (any order among the last three; each is checked
  with pana's lower bounds once its dependencies are on pub.dev). The human
  publishes; never from a session.
- **After the wave** the human marks `jet_cad_floor_plan` discontinued on
  pub.dev, replaced by `jet_cad_2d_plan`. No bridge release (decision 9).
- Until the wave, 0.7.x stays the line hosts use; a fix there goes to a
  branch from its tag.

## A11. Documents, demos and pictures

- **`docs/kits.md`**: the contract for kit authors: the naming (A7), the
  key and version rules (A16), the semver steps, the conformance test, and a
  checklist for a new kit (catalog, generator, names, source, types and tools,
  tests, demo, README pictures, CI line).
- **The host guide is rewritten** for `jet_cad_2d_plan` and the kits, with a
  short "From `jet_cad_floor_plan`" section mapping the old names to the new.
- **Demos, one per domain:** `apps/floor_planner` becomes
  `apps/architecture_demo` (the architecture kit only); `apps/restaurant_demo`
  loads the architecture and restaurant kits. A later kit adds its own demo.
- **README pictures show what the package itself gives.** `jet_cad_2d_plan`'s
  are of its widgets with the architecture kit (a plan with walls, rooms,
  doors, windows and furniture); the architecture kit's are of its types; the
  restaurant kit's are of the Salon and the Symbols gallery with its
  section. Generated by `tool/screenshots`, as today.

## A12. The rewrite

- **New packages, written against the contract,** in `packages/jet_cad_2d_kit`,
  `packages/jet_cad_2d_plan`, `packages/jet_cad_2d_kit_architecture` and
  `packages/jet_cad_2d_kit_restaurant`.
- **What is rewritten is the architecture and the API, not the proven
  algorithms.** The wall geometry, opening cuts, room tracing, dimension
  attachment, table labels and numbering, the band, the groups and the
  wall attachment were found correct by mutation and differential testing.
  They move into the new packages with their tests, and those tests are the
  oracle of the move: a ported algorithm's ported test passes unchanged in
  its assertions (fixtures and names may change).
- **The old packages stay on `main` untouched** while the new ones grow, so
  0.7.x can still be fixed. `jet_cad_floor_plan` and
  `jet_cad_restaurant_symbols` leave the repository in the release wave's
  last sub-project, once parity (A14) holds.
- **The engine and the Flutter layer change only where a seam is missing**
  (for example, a query listing a catalog's registered types), each change
  argued in its sub-project's spec.
- **CLAUDE.md's non-negotiables bind the new packages:** the frame path
  allocates nothing per entity in steady state (the plan library gets its
  own paint-allocation invariant test), draw order is ascending handle,
  geometric decisions use `Tolerance`.

## A13. The sub-projects

Each has its own spec, plan, branch and review; they ship together (A10).

1. **The contract, its symbol side.** This umbrella's acceptance;
   `jet_cad_2d_kit` with the plan components, the library format, the sources
   and names, the authoring toolkit and the conformance test; the attachment
   and family fields; the unit component; `docs/kits.md` begun.
2. **The plan library.** `jet_cad_2d_plan`: `PlanController`, the widgets, the
   two modes, `PlanEditor`, the manifest, the kit-set validation, the failure
   boundary, the generic tools; the contract's code side (`PlanType`,
   `PlanTool`, the property specs, the attachment registry) settled against
   a test kit.
3. **The architecture kit.** `jet_cad_2d_kit_architecture`: the six types,
   their tools, grips and properties, the furniture library, the wall-face
   provider; parity with today's design mode.
4. **The restaurant kit and the wave.** `jet_cad_2d_kit_restaurant`; the demos;
   the pictures; the host guide; parity (A14) closed; the old packages
   removed; the release checklist in STATUS.

## A14. Parity

Before the wave, every capability of today's host guide §4–§11 has a
counterpart, listed in a parity table in sub-project 4's spec: the
controller and view (§4), storing the plan (§5), the service layout (§6),
tables, statuses and selection with colours, the band, groups, zones and
focus, overlays, events and host data (§7), callbacks, the bars, the editor's
capabilities, keyboard and focus (§8), themes (§9), touch (§10), and the
"never assume" list (§11). Each row names the old API, the new API and the
test that shows it. A row may say "dropped" only with the human's word.

## A15. CI

- Every new package gets its job: test, analyse, format.
- The dependency rule of A1 is a check in `tool/ci`.
- The host probe builds a host from the new packages (by git before the
  wave, from pub.dev after it), as today's does for the old ones.
- The screenshot, README and guide checks move to the new packages.

## A16. Keys, versions and the conformance test

What made a published key a risk (decision 1) is held by these rules,
written in `docs/kits.md` and enforced by the conformance test every kit
runs on its own catalog:

- **A published `key@N` never changes its geometry or its unit.** A change
  of either is a new `@N+1`. A key is never removed and never reused; a
  retired symbol leaves the gallery but stays in the library, so a plan's
  copy keeps its identity. (A plan never needs it to draw: A8.)
- **Names, categories, words and search tags may change at any version**;
  they are not geometry.
- The test checks: keys, types and tools under the kit's id (A7); lower case;
  every key at every version present in the committed library; the
  committed library equal to the built one; a snapshot of each `key@N`'s
  geometry and unit equal to the committed snapshot; English names for
  everything, and every other locale the kit declares complete.
- **Semver for a kit at 0.x:** a new symbol, a new `@N`, words or tags is a
  patch; a removed or renamed Dart name, a type's parameters changed, or the
  kit id changed is a minor (0.x+1.0).

## A17. Interchange with AutoCAD, later: what keeps the door open

The human, 2026-10-13: *"ileride autocad dosya formatı da desteklenecek,
mimarimizin bu genişlemelere de uygun olduğundan emin olalım."* Not built
by this wave; these rules make sure nothing in it blocks it.

- **The engine is DXF-shaped already** (`roadmap/05-drawing-tools.md`:
  handles, layers, linetypes, by-block and by-layer attributes, block
  definitions and their instances, attributes, text styles, lineweights,
  text height as cap height).
- **Where it will live:** a 2D-ecosystem package over the engine alone,
  `jet_cad_2d_dxf`, reading and writing a `DraftDocument` as DXF. It depends
  on neither the plan library nor a kit. DWG comes through the same
  document model later; its licensing is a decision for its time.
- **The plan library's export and import are open seams,** not a closed
  enum (today's `FloorPlanExportFormat` is one): PDF and PNG are built in,
  and a host adds an exporter or an importer, for example DXF's.
- **Semantics survive a round trip:** every contract and kit component is
  JSON on a handle, so a DXF writer can carry it as extended data under one
  registered application name, and a DXF reader can restore it. Other CAD
  software sees plain blocks, lines and polylines.

**Binding on sub-projects 1–4:**

1. Everything a kit stores is a component on a handle, serialisable to JSON;
   no side table, no state outside the document.
2. A kit generates only the engine's entity kinds (line, polyline, circle,
   arc, text, fill, attribute); a kit never adds an entity kind. So an
   exporter needs no kit code, and a plan exports whole even with a kit
   missing.
3. Symbols stay block definitions with instances (BLOCK and INSERT).
4. Export and import are registries in `jet_cad_2d_plan` (sub-project 2).
5. An imported drawing with no kit semantics opens as plain geometry: plain
   entities, blocks and layers, editable with the generic tools.

## Out of scope

- The cinema and aircraft kits themselves (A6 only makes room for them).
- DXF and DWG themselves (A17 only keeps the door open).
- `jet_cad_2d_gpu` and the dormant `jet_cad`.
- Reading plans made by `jet_cad_floor_plan` (decision 9).
- Opening styles as data (a door leaf drawn from a library): noted as a
  possible later refinement of the architecture kit.

## Risks

- **Size.** Today's planner has 165 test files; the parity table (A14) and
  the ported tests (A12) are the guard against losing behaviour in the move.
- **A contract published too wide or too early** changes the plan and every
  kit at once. Sub-project 2 settles the code side against a test kit before
  anything is published, and A1 keeps the surface narrow.
- **Kits running code inside a host** (A9): the failure boundary is tested,
  not assumed.
- **A long wave.** 0.7.x stays fixable from its tags meanwhile (A10).

## Superseded

- STATUS's "The restaurant symbols: the fourth step, deferred" (decision 1).
- The host guide's "The restaurant symbols" copy steps (§1) and the
  publishing spec's D9, once the wave is out.
- STATUS's D11 (the restaurant software moves to `jet_cad_floor_plan`
  ^0.7.1) stands for the 0.7.x line; that software moves again with the
  wave.

## Amendments

- **2026-10-14, sub-project 2 split** (the human: *"İkiye böl"*): A13's
  sub-project 2 is carried by two specs, 2a (the contract's code side and
  the plan library in design mode,
  [2026-10-14-plan-library-design-mode-design.md](2026-10-14-plan-library-design-mode-design.md))
  and 2b (the service mode). A6's "sub-project 3's spec fixes the names"
  reads "2b's spec".
