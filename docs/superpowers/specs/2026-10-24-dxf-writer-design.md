# DXF writer: `jet_cad_2d_dxf`, and DXF export from the plan library

**Date:** 2026-10-24. **Status:** revision 1, approved by the human
(*"Spec'i onaylıyorum"*, 2026-10-24); self-reviewed by the controller, no
reviewer session. **Not scheduled:** the human asked for this spec for planning
(*"planlama için soruyorum. aciliyeti yok"*, *"spec yeterli şimdilik"*). No
implementation plan follows until the human asks for one.
**Packages:** new `jet_cad_2d_dxf` (pure Dart, over `jet_cad_2d` alone);
`jet_cad_2d_plan` (one opt-in exporter, one public field, one result field).
**Parent decision:** kit-architecture spec A17
([2026-10-13-kit-architecture-design.md](2026-10-13-kit-architecture-design.md)),
*"ileride autocad dosya formatı da desteklenecek"*. This is the first
sub-project that builds on it.

## Intent

A plan made in jet-cad can be handed to someone who works in AutoCAD. They
open the file and see the drawing: walls, rooms, doors, furniture, tables,
text and the units' colours. It is on the layers it was drawn on, in the
colours, linetypes and lineweights it was drawn with, and stacked in the
order jet-cad draws it. Other CAD software sees plain lines, polylines,
arcs, circles, hatches, text and blocks. The file also carries jet-cad's own
meaning (this group is a wall, this block is a table of four) in a place
AutoCAD keeps and ignores, so that a later DXF **reader** can open it again
as a plan rather than as plain geometry.

Writing comes first because it delivers on its own (a plan reaches AutoCAD)
and because its scope is closed: we choose what we write. Reading is open
ended, since AutoCAD's users choose what we must read. It is a later spec.

## Decisions

- **H1 — Writer first, spec only** (the human, 2026-10-24). This spec covers
  DXF output. Reading DXF and DWG are later sub-projects, and no plan is
  written until the human asks.
- **H2 — "Not exported" means not exported in any format** (the human:
  *"'dışa aktarılmasın' seçildiyse hiç bir dosya formatında
  aktarılmasın"*). An object of a type with `exported: false` is absent from
  a PDF, a PNG and a DXF, and from every exporter added later. In a DXF that
  means no entity, no block reference, no group, and none of its jet-cad
  data.
- **H3 — Everything left out now will be added sooner or later** (the human:
  *"şu anda dahil etmeyeceğimiz özellikleri de er ya da geç ekleyeceğiz"*).
  So nothing below is a non-goal. Each omission is listed under
  [Later, with the door kept open](#later-with-the-door-kept-open) with the
  rule in this design that keeps it addable without a rewrite. A design
  choice that would close one of those doors is wrong even if it works.
- **H4 — Units' colours appear in the DXF** (the human: *"evet
  görünsünler"*, accepting the proposal). They go on a layer of their own,
  as semi-transparent solid hatches under the drawing, so an AutoCAD user
  can turn that layer off.
- **H5 — Inherited from A17, binding here:**
  - The package `jet_cad_2d_dxf` depends on the engine alone: never on the
    plan library, a kit or Flutter.
  - A kit generates only engine entity kinds, so the writer needs no kit
    code and a plan exports whole even with a kit missing.
  - Symbols stay BLOCK and INSERT.
  - Kit semantics travel as data under one registered application name.

## Goals

- **G1** — `jet_cad_2d_dxf` turns a `DraftDocument` into DXF bytes that
  AutoCAD opens without a recovery prompt or an audit error, and that
  `ezdxf`'s `audit()` passes with no errors.
- **G2** — Every leaf the screen draws is written, with its stored style
  (layer, colour, linetype, linetype scale, lineweight, transparency,
  invisibility). The draw order matches: what is on top in jet-cad is on top
  in AutoCAD.
- **G3** — Every definition becomes a BLOCK, every instance an INSERT
  (with its attributes), and every layer, linetype and text style a table
  record.
- **G4** — Every serialisable jet-cad component and the scene tree's shape
  are written as data that AutoCAD keeps and a future reader can restore
  ([Semantics](#semantics-the-jetcad-data)).
- **G5** — The plan library ships `PlanDxfExporter` (`plan.dxf`). A host
  opts in by passing it in `PlanController(exporters: …)`. It honours H2
  and draws the units' colours (H4).
- **G6** — Nothing is dropped silently. Whatever the writer cannot write
  exactly is reported as a `Diagnostic` and reaches the host.
- **G7** — Output is byte-deterministic: the same document always gives
  the same bytes, as the engine's own codec does.

## Anti-goals

These would make the work a failure even if every test passed:

- A file AutoCAD opens only after "recover", or opens with things silently
  missing.
- A writer whose structure has to be torn up to add a reader, an entity
  kind, a fill style, a DXF version or DWG (H3).
- Kit or plan-library code inside `jet_cad_2d_dxf` (H5).
- Any change to the frame path. The writer is not on it, and the two
  allocation invariants must not move.
- Tests that pass on degenerate fixtures: everything at the origin, at the
  identity transform, on layer 0, in the default style.

## Shape of the package

`jet_cad_2d_dxf`, version 0.1.0, Apache-2.0, published by the human as the
other packages are. It is pure Dart and depends on `jet_cad_2d` and on
nothing that pulls in Flutter.

The writer has **two layers**, and the boundary between them is the main
door H3 relies on:

1. **Model to tags.** The document is walked and a stream of DXF tags
   (group code and value pairs, in section order) is produced. All DXF
   meaning lives here: sections, tables, blocks, entities, objects and
   handles.
2. **Tags to bytes.** A serialiser writes the stream as ASCII DXF. Binary
   DXF later is another serialiser, and so, one day, may DWG be (see Later).

Inside layer 1:

- **One emitter per `EntityKind`**, reached through an exhaustive `switch`
  on the enum with no `default`. When the engine gains a kind (ellipse,
  spline, bulge polyline), the analyser stops the build at the writer until
  that kind has an emitter.
- **One emitter for a fill's style.** Today only solid exists, but the
  emitter takes the style as input, so pattern and gradient are new cases in
  the same HATCH emitter rather than new code paths.
- **A `DxfVersion` enum** carries everything version-specific. It has one
  value today, `r2013` (`AC1027`, R2013 / R2014 and later), and no behaviour
  may branch on anything else.

Public surface, as a sketch; names are the builder's:

```dart
DxfWriteResult writeDxf(
  DraftDocument document, {
  DxfVersion version = DxfVersion.r2013,
  Set<Handle> omitOwners = const {},      // H2: group handles not to write
  List<DxfExtraFill> extraFills = const [], // H4: the units' colours
});

final class DxfWriteResult {
  final Uint8List bytes;
  final List<Diagnostic> diagnostics;   // the engine's Diagnostic
}
```

`DxfExtraFill` is the writer's own pure-Dart type: a closed polygon or a
circle in a placement's space, an ARGB colour, and a layer name. The plan
library's exporter converts its `PageUnderlayFill`s into these. The writer
never sees a Flutter type.

## Mapping

### Version and header

- **AC1027 (R2013) is the target. My call.** It is the oldest version that
  is UTF-8 throughout (Turkish text needs no `$DWGCODEPAGE`), and it carries
  true colour, transparency and lineweight natively. Every AutoCAD since
  2013 and every current DXF reader opens it.
- `$INSUNITS` from `DocumentHeader.units`: unitless 0, inches 1, feet 2,
  millimetres 4, centimetres 5, metres 6. `$MEASUREMENT` is 1 for metric
  units and 0 otherwise. `$LTSCALE` comes from `globalLinetypeScale`.
- `$EXTMIN`/`$EXTMAX`: `importedExtents` when set, otherwise the document's
  computed extents.
- `$HANDSEED` lies above every handle written.
- `customVariables` are preserved header variables. Writing them back is
  the reader spec's business, since only a reader fills them (see Later).
  Today the writer reports one `Diagnostic` if any are present and does not
  write them.

### Handles

Engine handles are DXF-native integers, so **an engine record is written
under its own handle**, in hex. If the record has an `OriginComponent` with
`source == dxf`, that id is used instead, as the architecture spec says.
Records DXF needs and the engine does not have get handles minted above the
document's highest handle, in a fixed order so output stays deterministic
(G7). These include block records, ENDBLK, dictionaries, XRECORDs, layouts,
the VPORT and the extension dictionaries. A collision between an origin id
and any other handle written is resolved by minting a fresh handle and
reporting a `Diagnostic`. It never yields a duplicate.

### Draw order

The engine draws in **ascending handle value**, and a DXF without a sort
table draws in file order. So entities are written in ascending handle
order within each container: model space and each block. No
`SORTENTSTABLE` is needed.

This matters for fills. `AddRegionCommand` mints the fill's handle before
its boundary's, so the hatch is written first and sits under its outline,
as on screen. A test pins this with a fixture where a later handle overlaps
an earlier one.

### Tables

| Engine | DXF |
|---|---|
| `LayerRecord` (name, colour, linetype, lineweight, transparency, visible, locked) | LAYER. Hidden: negative colour. Locked: flag 4. |
| `LinetypeRecord` (`DashPattern`) | LTYPE. Reserved BYLAYER, BYBLOCK and CONTINUOUS map to DXF's own records. |
| `TextStyleRecord` (font family, width factor, oblique, fixed height, SHX) | STYLE. A TTF family is written by font file name plus the family as the `ACAD` 1071 XDATA AutoCAD reads. SHX is written as SHX. A machine without the font (Roboto, the plan's face) substitutes one: declared lossy for display, as the architecture spec does for SHX. |
| `PatternRecord` | Not written: no fill uses a pattern yet (Later). |
| `DimStyleRecord` | Not written: no DIMENSION entity yet (Later). |
| — | APPID `ACAD` and `JETCAD`, VPORT `*Active`, BLOCK_RECORDs, and the minimal VIEW / UCS / DIMSTYLE records AutoCAD requires. |

Exactly which minimal records and objects R2013 needs to open cleanly
(layouts, `*Paper_Space`, root dictionary, `ACAD_GROUP`) is the builder's to
establish, against `ezdxf`'s `new()` output and AutoCAD.

### Entity style columns

- **Colour.** `ByLayerColor` is 256, `ByBlockColor` is 0, `IndexedColor` is
  its ACI in code 62, and `TrueColor` is code 420 (with the nearest ACI in
  62 for old readers).
- **Lineweight.** Code 370. The engine's −1, −2 and −3 are DXF's own BYLAYER,
  BYBLOCK and DEFAULT. A value that is not one of DXF's standard lineweights
  is written as the nearest standard one, with a `Diagnostic`.
- **Transparency.** Code 440. The engine's 0–255 maps onto DXF's alpha
  encoding. Exact formula: the builder's, pinned by a test at 0, 255 and a
  middle value.
- **Linetype and linetype scale.** Codes 6 and 48.
- **Invisible.** Code 60 from `EntityFlags.invisible` only.
  `EntityFlags.unpickable` is stripped (roadmap 13, decision 5).
- **Hidden nodes.** A leaf under a node with `visible == false` is written
  invisible, so AutoCAD agrees with the screen.

### Entities

| `EntityKind` | DXF |
|---|---|
| `point` | POINT |
| `line` | LINE |
| `polyline` | LWPOLYLINE. Closed when the stored last vertex `==` the first: a stored-value test, so exact. The repeated vertex is dropped and flag 70 bit 1 set. |
| `circle` | CIRCLE |
| `arc` | ARC. The engine's start plus signed sweep becomes DXF's counter-clockwise start/end. A negative sweep swaps the ends. |
| `text` | TEXT, with justification from `TextJustifyH`/`V` (codes 72/73) and the second alignment point where DXF requires one. Height is cap height, as the engine already stores it. |
| `attrib` | ATTDEF inside a BLOCK. ATTRIB after its INSERT (code 66 = 1, closed by SEQEND). |
| `fill` | HATCH, solid, true colour and transparency from the fill's columns. Its boundary loop comes from the boundary entity it references: a polyline path or a circle edge. Non-associative (code 71 = 0) in this spec; associativity is Later. |

Coordinates stay in the double precision the engine stores. Formatting
must round-trip every `double` exactly (shortest round-trip form), because
site-plan coordinates near 4.5e6 lose meaning at fixed decimals.

### Containers and transforms

The DXF this spec writes uses three containers. Each engine node maps onto
them as follows.

- **`Definition`** becomes a BLOCK whose base point is `basePoint`, with its
  children inside in ascending handle order. An xref definition (`isXref`) is
  written as an xref block record with its `xrefPath` and no content.
- **`InstanceNode`** becomes an INSERT. Its 2×3 affine is decomposed into
  insertion point, rotation and X/Y scale. A negative determinant (a mirror)
  is a negative X scale. DXF INSERT cannot express **shear**: an instance
  whose transform has shear is written **exploded**, its definition's leaves
  transformed into the parent's space, with a `Diagnostic`. *My call;* the
  alternative of refusing the export loses a whole drawing over one object.
  The instance's own style fields (layer, colour, lineweight, linetype,
  transparency) go on the INSERT, so BYBLOCK resolves as on screen.
- **`GroupNode`** has a transform, and DXF's GROUP has none. A group's
  world transform is therefore **baked into its leaves' coordinates**, and
  instances inside it compose it into their INSERT. *My call:* writing each
  group as an anonymous block plus INSERT would turn every wall into a
  block in AutoCAD, which is wrong to an AutoCAD user. The group's original
  transform is not lost: it is recorded in its JETCAD data (Semantics), so a
  reader restores the tree.
- **Baking can bend shapes.** A circle or arc under a non-uniform or
  sheared baked transform becomes an ELLIPSE. The writer may emit ELLIPSE
  even though the engine has no ellipse kind. A text under such a transform
  is written with the closest width factor and oblique angle, with a
  `Diagnostic`. A polyline, line or point bakes exactly.
- **DXF GROUP objects.** *My call:* every `GroupNode` that carries a
  component, or whose `exportAsDxfGroup` is set, is written as an unnamed,
  selectable DXF GROUP (in `ACAD_GROUP`) of every leaf and INSERT beneath
  it. Clicking a wall in AutoCAD then selects the wall, as in jet-cad.
  Nested groups are separate GROUPs; DXF allows an entity in several.

### Omitted objects (H2)

`omitOwners` holds group handles. Nothing at or beneath an omitted group is
written: no entity, no INSERT, no GROUP, no JETCAD data. A definition used
**only** by omitted instances is not written either. A BLOCK holding an
omitted object's geometry would carry it into the file, against H2. The
units' colours of omitted objects are already excluded by
`unitColourUnderlay(…, omitted:)`.

### The units' colours (H4)

- They go on a layer of their own, named `JETCAD-UNIT-COLOURS`
  (*name: my call*). It is minted by the writer from the `extraFills`'
  layer name, colour white/7, continuous, plottable.
- Each fill is a solid HATCH with the unit's true colour and the transparency
  from its alpha. Its geometry is transformed to world by its placement: a
  polygon as a polyline path, a circle as a circle edge (an ellipse edge
  under a non-uniform placement).
- They are written **first** in model space, before every document entity,
  so they sit under the drawing as they do in the PDF. Their handles are
  minted (above the document's), so they are the one exception to
  "ascending handle order" in model space, and the structural test says so.
  Each carries a JETCAD record `{ "v": 1, "derived": "unitColour" }`, so a
  reader knows to skip them: they are recomputed from the plan, never
  imported as content.

## Semantics: the JETCAD data

A17's promise: "every contract and kit component is JSON on a handle, so a
DXF writer can carry it as extended data under one registered application
name, and a DXF reader can restore it." This spec fixes the layout, so the
reader spec reads it and does not guess.

- **Application name** `JETCAD`, registered in the APPID table.
- **Per handle:** every component on the handle except internal ones
  (`OriginComponent` is registered internal: never written) is written as
  one JSON object. That covers registered components through their
  `toJson`, and unknown components preserved by the registry as they were
  read. The object is `{ "v": 1, "components": { typeId: json, … } }`.
- **Where:** in an **XRECORD** in the entity's (or GROUP's, or BLOCK
  record's) extension dictionary, under the key `JETCAD`. Not XDATA: XDATA
  has a 255-character string limit and about 16 KB per entity, and a kit's
  JSON can exceed both. The JSON string is split into code-1 chunks of at
  most 255 bytes, cut on UTF-8 character boundaries.
- **The tree:** a GroupNode's record also carries `node`: its handle,
  parent, transform (the six affine numbers), `visible`, and child order.
  An InstanceNode's carries its handle and parent. Draw order and nesting
  are restorable from these plus the handles.
- **The document:** an XRECORD under `JETCAD` in the named object
  dictionary holds `{ "v": 1, "schema": <codec schema version>, … }` and
  anything document-level the plan's text carries (its manifest). Exactly
  what goes there is the builder's, with one rule: a reader needs nothing
  else to know which kits a plan used.
- **AutoCAD's view:** AutoCAD and other software keep extension
  dictionaries they do not understand and show nothing of them.

`RawDataStore` (the preserve-unknown slot) holds DXF data only once a
reader exists. Its DXF payload shape (an ordered list of `[code, value]`
pairs per handle) is reserved here, and the reader spec decides how the
writer re-emits it. Today a DXF payload present in a document gives one
`Diagnostic` and is not written.

## The plan library

- **`PlanDxfExporter`**, id `plan.dxf`, extension `dxf`, MIME
  `image/vnd.dxf`. It implements `PlanExporter`, not `PlanPageExporter`: a
  DXF is model space and needs no page. It **is not** in the default
  `plan.pdf`/`plan.png` list. *My call:* a POS host that does not want DXF
  in its export dialog gets none, and one that wants it adds one constructor
  call. It lives in the plan library rather than in the host, because the
  units' colours reach exporters through the library-internal `unitFillsOf`.
  `jet_cad_2d_plan` gains a dependency on `jet_cad_2d_dxf` (pure Dart).
  This leaves A17's rule intact: the DXF package still knows nothing of the
  plan library.
- It passes `request.omitted` as `omitOwners` and converts `unitFillsOf`'s
  fills to `DxfExtraFill`s. It ignores the DPI choice.
- **H2 enforced by test.** One shared test drives every exporter the plan
  library ships (`plan.pdf`, `plan.png`, `plan.dxf`) over a plan with an
  `exported: false` object at a non-origin, rotated placement. It asserts
  that each output equals the output of the same plan with that object
  deleted: bytes for PNG and DXF, and the drawing operators for PDF if its
  metadata differs. A new built-in exporter joins the test's list. The `PlanExporter` documentation states H2 as the
  contract for host exporters too: the library hands them `omitted` and
  cannot police them.
- **Diagnostics reach the host (G6).** `PlanExportRequest` gains a way for
  an exporter to report `Diagnostic`s, and `PlanExport` (what
  `PlanController.export` returns) gains a `diagnostics` list. Both are
  additions, not breaking changes. The editor's built-in flow shows nothing
  new in this spec; a host can read them. Surfacing them in the UI is
  Later. *My call.*
- `docs/host-guide.md` and the plan library's CHANGELOG/README get the
  opt-in line. The restaurant demo opts in, so the human has a DXF to open.

## Verification

The repo's testing bar applies in full: a test lands only if a named
mutation turns it red, and no fixture sits at the identity, the origin, layer
0 or the default style unless that is what it tests.

- **Differential oracle: `ezdxf`** (Python, MIT). A test writes a document,
  has `ezdxf` read it and run `audit()`, and compares what `ezdxf` reports
  with what the document holds. It compares entity counts and kinds,
  coordinates within `Tolerance`, layers, colours, transforms of INSERTs,
  block contents, GROUP membership and the JETCAD JSON decoded back. A
  pinned `ezdxf` version runs from a small Python script under `tool/`.
  These tests carry a tag that the default `dart test` excludes
  (`dart_test.yaml`), so the gate stays runnable without Python. A CI job
  installs the pinned `ezdxf` and runs them. *My call.* Run locally without
  Python, they **fail** rather than skip: an oracle that silently skips is
  a synthesized result.
- **Structural tests in Dart** (default suite): section order, handle
  uniqueness, `$HANDSEED` above every handle, every pointer handle resolves,
  draw order matches ascending handle, chunking cuts on UTF-8 boundaries
  (a fixture with Turkish text across a 255-byte cut), determinism (two
  writes, same bytes).
- **Golden files** for a few small documents. A diff is reviewed, never
  blindly regenerated.
- **Mutations the suite must catch,** at least:
  - arc sweep sign ignored;
  - INSERT rotation sign flipped;
  - mirror written as a positive scale;
  - group transform not baked;
  - group transform baked twice (inside an INSERT);
  - closed polyline left open;
  - hatch written after its boundary;
  - BYLAYER and BYBLOCK swapped;
  - omitted group's leaves written;
  - an internal component written;
  - a chunk cut mid-character.
- **The manual check of record:** the human opens the restaurant demo's
  `plan.dxf` in AutoCAD (AutoCAD for Mac, or the free AutoCAD web app in
  a browser; DWG TrueView is Windows-only) and confirms it opens without
  recovery and looks like the PDF. The results
  note records that check.

## Later, with the door kept open

H3: each of these will be added. The rule that keeps it addable is part of
this design.

| Later | What keeps the door open |
|---|---|
| **DXF reader**, first for our own files, then for real AutoCAD files | The JETCAD XRECORD layout and the `RawDataStore` DXF payload shape are fixed here. `OriginComponent` ids are written back. Derived data (units' colours) is marked. |
| **Polyline bulges, ELLIPSE, SPLINE as engine kinds** | One emitter per kind behind an exhaustive switch: a new kind fails the build until it is written. The writer already emits ELLIPSE for baked shapes. |
| **Pattern, gradient and image fills** | The HATCH emitter takes the fill style as input. `PatternRecord` is already DXF-shaped (angle, base, offset, dashes). |
| **Associative hatches** | The hatch knows its boundary handle. Associativity is codes 71 and 330 plus a reactor on the boundary. |
| **Other DXF versions** (R2000 / AC1015, R2018 / AC1032) | Everything version-specific goes through `DxfVersion`. Nothing may branch on anything else. |
| **Binary DXF** | Model-to-tags and tags-to-bytes are separate layers; binary is a second serialiser. |
| **DWG** | Through the same tag stream or document model. The licensing route is the decision of its time: an external converter, the ODA SDK or a writer of our own. LibreDWG's GPL-3 is incompatible with Apache-2.0. |
| **Paper space, layouts, the page and a title block** | Model space is written alone. The page is never mixed into it, so a layout can be added beside it. |
| **DIMENSION entities** | Dimensions export as the plain geometry they are today. `DimStyleRecord` exists for the day a dimension becomes an entity. |
| **Header variables preserved from an import** | Reserved for the reader spec, with a `Diagnostic` today. |
| **Diagnostics in the UI** | They already reach `PlanExport.diagnostics`. |
| **DXF in the default exporter list** | One line in the default list. |

## Left to the builder

- Names of every type, file and function.
- The exact minimal set of tables, objects and layouts R2013 needs, proven
  against `ezdxf` and AutoCAD.
- The transparency encoding, the nearest-ACI rule, the standard lineweight
  table and the shortest-round-trip number format.
- How the plan is split into tasks. A likely cut: the writer core and its
  oracle; then blocks, groups and the JETCAD data; then the plan exporter,
  the units' colours and the shared H2 test.
- Whether the oracle script and CI job live under `tool/ci/` beside the
  existing host probe.

## Effort

About three to four plans at this repo's recent pace, so one to one and a
half weeks of SDD work. The ezdxf oracle and AutoCAD's strictness about the
minimal R2013 structure are the main risks to that figure.
