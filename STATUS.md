# jet-cad — project status

**Last updated:** 2026-10-10. **`main` carries release 0.4.0** (tag
`v0.4.0` → `8367010`, after `v0.3.0` → `1b0c37a`, `v0.2.0` → `7355c00` and `v0.1.0` → `22206f5`) and everything since. The history of every plan
before this point — its records, reviews and resume points — is in
[STATUS-HISTORY.md](STATUS-HISTORY.md), unedited.

## Where the project stands

The product is a **parametric floor planner** embedded in a restaurant
point-of-sale application. The roadmap's sub-projects **01–13** (the app,
interaction, page and rulers, drawing tools, the parametric layer, walls,
openings, symbols, rooms, dimensions, the app shell, export and print)
and **14** (the restaurant embedding) are merged; see
[roadmap/00-README.md](roadmap/00-README.md)'s Status table for each
one's spec, plan and results.

- **Release 0.1.0** ([CHANGELOG.md](CHANGELOG.md)): the four packages a
  POS depends on by git, at one commit SHA
  ([docs/host-guide.md](docs/host-guide.md)). CI on GitHub Actions
  (`.github/workflows/ci.yml`) runs every gate on pushes to `main` and
  `claude/**` and on pull requests, compares the standing failures and
  skips exactly (`tool/ci/standing_*.txt`), and builds the host probe by
  git at the commit under test. In that probe it then analyses each
  released host's `main.dart`, read from its tag: `v0.3.0` (the host
  embedding API spec's invariant 1) and `v0.4.0` (since 2026-10-10, the
  0.4.0 review's R-7), by `tool/ci/old_host_probe.sh <tag>`.
- **14d** (POS readiness: three languages, the service layout and
  options, the release) and its independent review: results
  [14d-2](docs/superpowers/notes/2026-10-06-plan-14d2-results.md),
  [14d-1](docs/superpowers/notes/2026-10-06-plan-14d1-results.md),
  [14d-3](docs/superpowers/notes/2026-10-06-plan-14d3-results.md),
  [review](docs/superpowers/notes/2026-10-06-14d-review.md).
- **Main's own line before the 14d merge** (PRs 1–9, 2026-10-05): the dark
  theme and dark canvas, table groups and their fixes; their records are
  in STATUS-HISTORY.md's first entries.
- **The cleanup batch** (the human, 2026-10-07: *"2 ile devam et, R-13'te
  planın yeri korunsun"*), merged into `main` at `c667ed6` on the human's
  *"evet, main'e merge et"*: R-13 as amended (a mode switch keeps the plan
  in place on the screen; the controller reframes the camera), the floor
  planner's file panels worded in the app's language (14d-1 review F-5),
  `actions/checkout@v5`, this STATUS cut down with its history moved
  whole; an independent review (*Approved with fixes*), fixed in
  `6c7b5c9`. Record:
  [2026-10-07-cleanup.md](docs/superpowers/notes/2026-10-07-cleanup.md).
- **Q0, the plan's decimal separator** (the human, 2026-10-07: *"Q0 ile
  devam et"*), merged into `main` at `032880c` on the human's *"evet,
  main'e merge et"*: a plan carries its separator (`.` or `,`), chosen on
  the Page panel; dimensions, room areas and the rulers print it; a new
  plan takes the UI language's (Q2 assumed yes, N1); **schema 8**, which
  0.1.0 refuses (released in 0.2.0). Spec
  [2026-10-07-decimal-separator-design.md](docs/superpowers/specs/2026-10-07-decimal-separator-design.md)
  (rev 2), plan [2026-10-07-decimal-separator.md](docs/superpowers/plans/2026-10-07-decimal-separator.md),
  results [2026-10-07-decimal-separator-results.md](docs/superpowers/notes/2026-10-07-decimal-separator-results.md),
  ledger [docs/superpowers/ledgers/2026-10-07-decimal-separator/](docs/superpowers/ledgers/2026-10-07-decimal-separator/).
- **The GPU split** (the human, 2026-10-07: *"POS entegrasyonuna geç"*,
  then *"Önce jet-cad ön koşulu"*: Monépro's spec 103 §10 lists it
  first), merged into `main` at `56974b6` on the human's *"evet, main'e
  merge et"*: the GPU renderer moves out of `jet_cad_2d_flutter` into
  `packages/jet_cad_2d_gpu`, so a host's graph holds no `flutter_scene`
  and runs no build hook, its web build is 12 MB smaller and its Flutter
  floor is 3.44 again (released in 0.2.0). CI's host probe fails on a
  lock that resolves the GPU renderer. Spec
  [2026-10-07-gpu-package-split-design.md](docs/superpowers/specs/2026-10-07-gpu-package-split-design.md)
  (rev 2), plan [2026-10-07-gpu-package-split.md](docs/superpowers/plans/2026-10-07-gpu-package-split.md),
  results [2026-10-07-gpu-split-results.md](docs/superpowers/notes/2026-10-07-gpu-split-results.md),
  ledger [docs/superpowers/ledgers/2026-10-07-gpu-split/](docs/superpowers/ledgers/2026-10-07-gpu-split/).
- **Release 0.2.0** (the human, 2026-10-08: *"devam, 0.2.0 sürümüyle
  başla"*), merged into `main` at `7355c00`: the four host packages
  (and `jet_cad_2d_gpu`) at 0.2.0; the CHANGELOG's Unreleased section
  becomes 0.2.0 (Q0's separator and schema 8, the GPU split); the host
  guide's "unreleased" markers read "since 0.2.0". An independent review
  (*Approved with fixes*) is applied; ledger
  [docs/superpowers/ledgers/2026-10-08-release-0.2.0/](docs/superpowers/ledgers/2026-10-08-release-0.2.0/).
  Merged on the human's *"evet, main'e merge et"*; the guide names
  `7355c00`. The human pushed the tag `v0.2.0` →
  `7355c00` (2026-10-08).
- **Zone focus** (the human, 2026-10-08: *"evet, bölgelerle devam et"*;
  ruled that a zone lives in the host's database), merged into `main` at
  `ffe8cb8` on the human's *"evet, main'e merge et"*: `fitToTables` frames
  a set of tables by number, `setTableFocus` fades the others in the
  selection mode, `FloorPlanTable.visible`; the host guide's "Zones:
  framing and focus"; the demo's Salon zones (released in 0.3.0).
  Spec [2026-10-08-zone-focus-design.md](docs/superpowers/specs/2026-10-08-zone-focus-design.md)
  (rev 2), plan [2026-10-08-zone-focus.md](docs/superpowers/plans/2026-10-08-zone-focus.md),
  results [2026-10-08-zone-focus-results.md](docs/superpowers/notes/2026-10-08-zone-focus-results.md),
  ledger [docs/superpowers/ledgers/2026-10-08-zone-focus/](docs/superpowers/ledgers/2026-10-08-zone-focus/).
- **Release 0.3.0** (the human, 2026-10-08: *"evet, 0.3.0 sürümünü
  hazırla"*), merged into `main` at `1b0c37a` on the human's *"evet, main'e
  merge et"*: the four host packages (and `jet_cad_2d_gpu`) at 0.3.0;
  the CHANGELOG's 0.3.0 carries zones, with known limits (no public
  world-to-screen mapping, Q-Z1; tables linked by number, Q-Z4). Plans
  and service layouts are unchanged, so 0.2.0 and 0.3.0 terminals share
  them. An independent review (*Approved with fixes*, CHANGELOG wording
  only) is applied; ledger
  [docs/superpowers/ledgers/2026-10-08-release-0.3.0/](docs/superpowers/ledgers/2026-10-08-release-0.3.0/).
  The guide names `1b0c37a`. The human pushed the tag `v0.3.0` →
  `1b0c37a` (2026-10-08).
- **The host embedding API** (the human, 2026-10-08: *"Monépro
  entegrasyonuna geç. Önce beyin fırtınası. Temel nokta, başka bir
  uygulamaya gömecek esnekliğe sahip olması…"*): brainstormed with the
  human (2026-10-09), umbrella spec
  [2026-10-09-host-embedding-api-design.md](docs/superpowers/specs/2026-10-09-host-embedding-api-design.md)
  revision 3 (`4f5c8fc`). Revision 1 reviewed independently (*Approve with
  fixes*, V-1 to V-22, all folded in); the human ruled schema 9 for host
  data on a table (Q-H1) and a double tap without delay (Q-H2). Four
  slices, each its own plan and merge: 1 geometry, public camera and
  per-table widgets; 2 events and table data (schema 9); 3
  `FloorPlanTheme`; 4 the bars, keyboard and editor capabilities. Ledger:
  `.superpowers/sdd/2026-10-09-host-embedding-api/`. **Slice 1**
  (the human: *"evet, Dilim 1 ile devam et"*): plan
  [2026-10-09-embedding-slice-1.md](docs/superpowers/plans/2026-10-09-embedding-slice-1.md),
  results [2026-10-09-embedding-slice-1-results.md](docs/superpowers/notes/2026-10-09-embedding-slice-1-results.md);
  Tasks 1–5 done, each reviewed independently and fixed (`85918c4` …
  `84ee8e9`); the whole range reviewed independently (*Approve with
  fixes*, F-1 to F-8, applied in `98c0c1d`). **Merged into `main` at
  `1b32e0a`** on the human's *"evet, main'e merge et"*; ledger
  [docs/superpowers/ledgers/2026-10-09-embedding-slice-1/](docs/superpowers/ledgers/2026-10-09-embedding-slice-1/).
  **Slice 2** (the human: *"tamam, Dilim 2 ile devam et"*): host data on
  a table (`setTableData`, `FloorPlanTableDetail.data`, **schema 9**),
  `designChanges`, `onTablesMoved`, `onTableDoubleTap`, `onFloorTap`,
  `onTableHover`; plan
  [2026-10-09-embedding-slice-2.md](docs/superpowers/plans/2026-10-09-embedding-slice-2.md),
  results [2026-10-09-embedding-slice-2-results.md](docs/superpowers/notes/2026-10-09-embedding-slice-2-results.md);
  Tasks 1–5 done, each of 1–4 reviewed independently and fixed; the whole
  range reviewed independently (*Approve with fixes*, F-1 to F-7, applied
  in `8f813b2` … `e6a1d06`). **Merged into `main` at `fe93d23`** on the human's
  *"evet, main'e merge et"*; ledger
  [docs/superpowers/ledgers/2026-10-09-embedding-slice-2/](docs/superpowers/ledgers/2026-10-09-embedding-slice-2/).
  Released in 0.4.0. **Slice 3** (the human: *"tamam, Dilim 3 ile
  devam et"*): `FloorPlanTheme`, a `ThemeExtension` merged field by field
  with `FloorPlanView(theme:)`: status captions and fills, group frames
  and chips, the selection per paper and its width (both modes), the
  focus veil, `canvasBackground`, the service bar's height; with no
  theme every pixel is today's. Plan
  [2026-10-09-embedding-slice-3.md](docs/superpowers/plans/2026-10-09-embedding-slice-3.md),
  results [2026-10-09-embedding-slice-3-results.md](docs/superpowers/notes/2026-10-09-embedding-slice-3-results.md);
  Tasks 1–4 done, each of 1–3 reviewed independently and fixed; the whole
  range reviewed independently (*Approve with fixes*, applied in `237a28e`,
  `9eb8434`). **Merged into `main` at `d26c9fe`** on the human's *"evet, main'e
  merge et"*; ledger
  [docs/superpowers/ledgers/2026-10-09-embedding-slice-3/](docs/superpowers/ledgers/2026-10-09-embedding-slice-3/).
  Released in 0.4.0. **Slice 4** (the human: *"tamam, Dilim 4 ile
  devam et"*): the bars (`FloorPlanServiceBar`, `FloorPlanEditorBar`:
  shown or not, their actions in order, host widgets at either end), a bar
  of the host's own (`mergeCandidate`, `activeTool` / `selectTool`,
  `editorSelectedTables`, `exportPlan` / `printPlan`, `deleteSelection()`;
  `undo()` / `redo()` wait for an idle tool), `onExportDialog` and
  `onPageFlowError`, `FloorPlanEditorCapabilities` (`full`, `tablesOnly`,
  `readOnly`) gating every edit path, the table inspector slot,
  `shortcuts` and `autofocus`; chrome changes keep the plan in place; the
  planner's own fields keep their keys from a host's `Shortcuts`. With no
  new parameter the planner behaves and draws as before, but S-4. Plan
  [2026-10-09-embedding-slice-4.md](docs/superpowers/plans/2026-10-09-embedding-slice-4.md),
  results [2026-10-09-embedding-slice-4-results.md](docs/superpowers/notes/2026-10-09-embedding-slice-4-results.md);
  Tasks 1–7 done, each of 1–6 reviewed independently and fixed, Task 7's
  finding 1 fixed in the planner; the whole range reviewed independently
  (*Approve with fixes*, F-1 to F-8, applied in `44b6775`, `492c70c`,
  `fdf3309`). Removing a design view while a pointer hovers no longer
  throws (Slice 3's finding; the frame-safe relay `c65a3a0`, pinned by
  `f0c77cf`). **Merged into `main` at `4331c74`** on the human's *"evet, main'e merge
  et"* (confirmed: *"Yine de sen merge et"*); ledger
  [docs/superpowers/ledgers/2026-10-09-embedding-slice-4/](docs/superpowers/ledgers/2026-10-09-embedding-slice-4/).
  Released in 0.4.0. The umbrella's four slices are all merged.
- **O-10, an undone node removal restores the node's index** (the human,
  2026-10-10), merged into `main` at `a803f86` on the human's *"evet,
  main'e merge et"*: `RemoveNodeCommand`'s inverse carries the node's
  index in its parent's raw `children`, so Delete then Undo writes a plan
  back byte for byte, for one node and a compound delete; every test that
  compared child lists sorted now compares the bytes. Plan
  [2026-10-10-undo-node-index.md](docs/superpowers/plans/2026-10-10-undo-node-index.md),
  results [2026-10-10-undo-node-index-results.md](docs/superpowers/notes/2026-10-10-undo-node-index-results.md)
  (independent review *Approve with fixes*, F-1 to F-5 applied). Run
  natively in one session: no SDD ledger. Released in 0.4.0.
  Its merge commit was never pushed to `main` on its own; it reached
  `origin/main` through Slice 4's branch (`263e2ca`). Slice 4's DS1 and DS2 (`keyboard_focus_test.dart`) now compare the
  undone encoding with the one before the delete, on Slice 4's branch
  (`a5b1ead`).
- **O-11, a table whose corners are not finite** (the human, 2026-10-10),
  merged into `main` at `aed5c4d` on the human's *"evet, main'e merge
  et"*, from `fix/non-finite-corners`: selecting such a table (the embedding
  fixture's `9`) no longer trips `drawLine`'s NaN assertion, and its PDF
  (Export and Print) no longer trips the pdf package's `!value.isNaN`.
  `GripCache` keeps no non-finite bounds in its box and no non-finite
  grip, and a grip whose screen distance is NaN is never hit;
  `SelectionOverlayPainter` draws no rotation grip and no point cross at
  a non-finite screen position; `PdfDrawSink` draws nothing under a
  residual with an entry that is not finite. Named mutants M-O11a to
  M-O11i, each killed; an independent review (*Approve with fixes*: the
  NaN hit test, the mutant names, the CHANGELOG's wording), applied in
  `efbb4ef`. Run natively in one session: no SDD ledger; the record is
  the spec's O-11. Released in 0.4.0. As O-10's, its merge commit
  reached `origin/main` through Slice 4's branch (`263e2ca`). Slice 4's
  `page_flows_test.dart` dropped `finitePlanJson()` for
  `embeddingPlanJson()` on Slice 4's branch (`503c504`). Left as found: `CanvasDrawSink.point` carries a
  non-finite residual by hand into `drawRect` (unreachable for table 9,
  whose box is culled).
- **Release 0.4.0** (the human, 2026-10-10: *"0.4.0 sürümünü hazırla"*),
  merged into `main` at `8367010` on the human's *"evet, main'e merge
  et"*: the four host packages (and `jet_cad_2d_gpu`) at 0.4.0; the
  CHANGELOG's 0.4.0 carries the host embedding API's four slices, O-10
  and O-11, with known limits. **Schema 9**: 0.3.0 refuses a 0.4.0 plan,
  so every terminal that shares stored plans moves together; service
  layouts are unchanged. An independent review (*Approved with fixes*:
  CHANGELOG and guide wording only) is applied; ledger
  [docs/superpowers/ledgers/2026-10-10-release-0.4.0/](docs/superpowers/ledgers/2026-10-10-release-0.4.0/).
  The guide names `8367010`. The human pushed `main` and the tag
  `v0.4.0` → `8367010` (2026-10-10).

- **A removed node takes its components** (the host embedding API
  spec's O-8; the human, 2026-10-09), merged into `main` at `8b0f6b0` on
  the human's word (2026-10-10). Deleting a node now removes every
  component on its handle (registered and preserve-unknown) and undo
  restores them, the node at its index: `RemoveNodeCommand` snapshots and
  detaches them, `AddNodeCommand(node, {index, components})` checks the
  snapshot (`ComponentRegistry.checkRestorable`: an unmapped type id or a
  value of another class) before any write and restores it after
  `addNode`; both declare `{structure, components}` (the add only when it
  carries any). The parametric planner's detaches (06 D8's cleanup, the
  dissolve's) and 0.4.0's table-data expander detach are gone. Schema
  stays 9. Spec
  [2026-10-09-node-components-on-delete-design.md](docs/superpowers/specs/2026-10-09-node-components-on-delete-design.md)
  (revision 3, reviewed, approved), plan
  [2026-10-10-node-components-on-delete.md](docs/superpowers/plans/2026-10-10-node-components-on-delete.md)
  (subagent-driven, three tasks, each reviewed; whole-branch review and
  its fix wave), results
  [2026-10-10-node-components-results.md](docs/superpowers/notes/2026-10-10-node-components-results.md)
  (M-1 to M-18, the rulings), ledger
  [docs/superpowers/ledgers/2026-10-09-node-components-on-delete/](docs/superpowers/ledgers/2026-10-09-node-components-on-delete/).
  Not pushed.

## In flight

Nothing.

## Owed to the human

- **Looks:** macOS, the web and a tablet, for 14 and 14d (the demo and
  the floor planner in three languages; the service mode's menu, groups
  and layout; the dark theme).
- **A native German read** of the German text (*Am Raster fangen*,
  *Zufällige Status* among others); the Turkish read.
- **A ruling:** a context click on a group member selects its whole group
  (made at the 14d merge, documented in the host guide).
- **Slice 1, a look:** the demo's badges, pan and zoom smoothness and
  interactive badges by touch, on a tablet and a terminal; the German
  and Turkish read of the demo's new strings.
- **Slice 2, a look:** the demo's double tap, pointer line and *Link
  tables* on a tablet and a terminal; the German and Turkish read of its
  new strings.
- **Slice 3, a look:** the demo's POS look on a tablet and a terminal,
  light and dark; a native read of its new strings (de "Aussehen /
  Kasse", tr "Görünüm / Standart / Kasa").
- **Slice 4, a look:** the demo's three editor profiles, its own bar
  and its own keys on a tablet and a terminal; a native read of its new
  words (de *Host / Editor / Voll / Tische / Nur lesen / Eigene Leiste /
  Eigener Exportdialog / Tasten des Plans / Tisch suchen / Kassen-ID*, tr
  *Ana uygulama / Düzenleyici / Tam / Masalar / Salt okunur / Kendi
  çubuğu / Kendi dışa aktarma penceresi / Planın tuşları / Masa bul / Kasa
  kimliği*).
- **macOS:** the render package's text lod ladder rungs 1 and 2 pass
  there, so its standing set differs from Linux's (recorded, not ruled).
  Slice 3's T-1 failure there (the human: *"T-1'i ayrı görev olarak
  düzelt"*) is fixed: its "bold inks more" check held on Linux only (the
  engine's synthetic bold spreads the ink differently on macOS: 176,420
  regular against 175,568 bold); it now asserts that bold renders unlike
  regular, which still kills Slice 3's X18 (the weight forced to w400).
  Merged into `main` at `7d7d8a4` on the human's *"evet, main'e merge
  et"*. Confirmed on macOS (Flutter 3.47.6, 2026-10-10, at `8367010`):
  `table_theme_painter_test.dart` +25, all passed.
- **Zone focus, a look** (Q-Z3): the margin, the 3 m span and the veil on
  a tablet and a terminal, light and dark; the demo's three zone strings
  in German and Turkish.
- **Q2's ruling:** does a new plan's decimal separator follow the UI
  language (Q0's N1, assumed yes)? If "`.` always", `documentSeparatorFor`
  becomes a constant and the settling goes.
- **The macOS re-baseline** of the engine's two `generate_document_test`
  fingerprints (moved by 12b's schema 7, Q0's schema 8 and Slice 2's
  schema 9).
- **A look at Q0** in German and Turkish: the Page panel's control, the
  plan's text, the PDF.
- **The GPU split's device run:** the dev harness's `BACKEND=residentGpu`
  on macOS, which now loads the bundle from `jet_cad_2d_gpu`'s asset key
  (every GPU run was the human's).

## Standing failures and skips

On Linux, compared exactly by CI: the engine's two `generate_document_test`
fingerprints and the render package's seven text-ladder goldens (macOS
values), and the render package's paint micro-benchmark rig (skipped,
run by hand). See `tool/ci/standing_failures.txt` and `standing_skips.txt`.

## Resume here

**Next: the human's choice.** 0.4.0 (tag `v0.4.0` → `8367010`) carries the host embedding API's four slices
(**schema 9**, every terminal that shares stored plans moves together).
Monépro owes Q-H3 and its real shadcn tokens, and can name
`controller.camera`, `tableOverlayBuilder` (Q-Z1),
`FloorPlanTableDetail.data` (Q-Z4), `FloorPlanTheme`, and from Slice 4
`tablesOnly` for "edit floor drawing", `shortcuts: false` beside
`PosShortcutsHost`, `onExportDialog` for a `ShadDialog` and the inspector
for linking `pos_tables` rows, in its spec 103. Found, not fixed (Slice
4's results): F-7 (an `against-wall` table turns to its wall under
`rotate: false`), a second view on one controller for one frame.
---
## What this project is

A CAD workspace holding **two independent product lines that share a name
and nothing else**.

- **The live line, the 2D floor planner:** `jet_cad_2d` (a pure-Dart 2D
  CAD engine and document model: no OCCT, no FFI, no Flutter),
  `jet_cad_2d_flutter` (rendering and interaction), `jet_cad_2d_gpu` (the
  GPU renderer, the dev harness's only; never a host's), `jet_cad_floor_plan`
  (the planner: shell, tools, parametric objects, panels, the host API),
  `jet_cad_restaurant_symbols` (the restaurant library), the apps
  `floor_planner` and `restaurant_demo`.
- **The dormant line, `jet_cad`:** a Flutter package over Open CASCADE
  by FFI with a macOS viewport (`packages/jet_cad`, `apps/dev_harness`).
  Nothing is worked on there; it is outside the gates and CI.

## Repo layout

```
packages/
  jet_cad_2d/                  # the engine (pure Dart)
  jet_cad_2d_flutter/          # rendering, interaction, the gallery
  jet_cad_2d_gpu/              # the GPU renderer (harness only)
  jet_cad_floor_plan/          # the planner and its host API
  jet_cad_restaurant_symbols/  # the restaurant symbol library
  jet_cad/                     # DORMANT — OCCT 3D over FFI
apps/
  floor_planner/               # the planner as an app (files, export, print)
  restaurant_demo/             # the POS demo host, three languages
  dev_harness_2d/              # measurement harness (profile on a device)
  dev_harness/                 # DORMANT — the jet_cad viewport harness
tool/ci/                       # CI's tools: the standing comparison, the
                               #   host guide's check, the host probe
roadmap/                       # the product target, decomposed (inputs)
docs/host-guide.md             # embedding the planner in a POS
docs/superpowers/
  specs/   plans/   notes/     # binding specs, plans, results of record
  ledgers/                     # per-task records of merged plans
.superpowers/sdd/              # git-ignored ledger of a plan in flight
```

---

## Rulings that still bind future work

Plan 3c's ledger carries 56 numbered rulings, archived in full at
[docs/superpowers/ledgers/](docs/superpowers/ledgers/). These are the ones that
constrain work not yet done:

**Ruling 4 — the cache limit is not a tuning knob.** `kParagraphCacheLimit` is
owned by Plan 3c Task 9 and may be raised **once**, and only with the
measured distinct-visible-key count recorded beside it. Lowering
`attributedInstanceFraction` is equally acceptable. **Relaxing the
zero-new-layouts gate row is not.** Otherwise the gate passes because the corpus
was thinned rather than because the cache works.

> **Status as of 2026-08-23: the raise is now *available* and is still
> unspent.** Plan 3f Task 8 produced the count the ruling asks for —
> **3,876** distinct `(text, styleHandle, argb)` keys at the whole-drawing
> camera on the 50,000-entity corpus at `kMinTextCapPixels = 3.0`, read by
> three independent mechanisms. Plan 3f declined to spend it: the raise can
> only happen once, Plan 3g may want it, and holding 3,876 live native
> `ui.Paragraph` objects in one frame is a memory cost nobody has measured on
> any target. **A human decides whether to spend it.** Plan 3f also refused
> the other route — raising `kMinTextCapPixels` from 3.0 to 6.0 makes the
> gate rows comply and would be a threshold chosen because a gate needed it,
> which is the same failure this ruling names one level up.

**Ruling 20 — discharged in Task 10, with numbers.** The residual-path norm is
**1.00** allocations per leaf (one `Transform2`). A text leaf through
`resolveTextAttributes` + `textLocalTransform` was **9.00**; through one
long-lived `TextLayout` it is **0.87–1.00**, at or below the norm. The spec's
second `Float64List(16)` was not the fix — under the plan's shape the sink
composes nothing — the reusable layout was, and `TextLayout` lost `@internal`
for it. Gate:
`packages/jet_cad_2d/test/invariants/text_paint_allocation_test.dart`. Every
assertion there is a **ratio**, because the profiler was observed once to read
0.07 where two other runs read 1.00.

**Ruling 10 — `boxOfLeaf` returns null after an edit, correctly.** Dirtying a
leaf removes it from the packed R-tree and parks it in the overlay. Any test
reading a box after an edit must use the codebase idiom:
`index.boxOfLeaf(slot) ?? index.dirty.boxOf(slot)`.

**Ruling 12 — never `tables.textStyles[...]!`.** `JsonCodec._loadTables` clears
the seeded defaults and `TableSection.remove` is public, so a document missing
handle 5 crashes on plain `doc.extents`. Use
`DraftDocument.textStyleOf(Handle)`, which falls back to a `const
TextStyleRecord`.

**Ruling 22 — pin the layout em size exactly, not positively.** The measurer's
one unforgivable failure is laying a paragraph out at anything other than
`kNominalTextPixels`, and `expect(ascent, greaterThan(0))` is satisfied by every
positive em size. `flutter_test`'s font is exactly 0.75em ascent / 0.25em
descent / 1em per character, so the assertions are exact: `WC` at nominal is
ascent 75.0, descent 25.0, advance 200.0. A Flutter upgrade that moves the test
font fails loudly, which this plan prefers to a silent pass.

**Ruling 23 — the two measurers must agree, and one guard is still owed.**
`Paragraph.longestLine` is `-FLT_MAX` for a paragraph with no lines, and
`-FLT_MAX` is **finite**, so no `isFinite` guard catches it.
`FlutterTextMeasurer` now shares `ascent`/`descent`'s `lines.isEmpty` guard for
`advanceWidth` so it returns `0.0`, matching `MetricModelMeasurer`. The seam's
premise — and the differential oracle's validity — is that the two are
interchangeable. The draw-path `isEmpty` guard landed in Task 10, in the
painter *and* in the reference walk, and both halves are pinned by mutation.

**Ruling 28 — the paragraph flip lives in the sink, not the painter.**
`Canvas.drawParagraph` draws y-down from the top of the line; the residual maps
glyph space, y-up from the baseline. `CanvasDrawSink.text` reconciles them with
`translate(0, alphabeticBaseline)` then `scale(1, -1)`. It must **not** move
into the painter: it is a `dart:ui` fact, and `reference_walk` composes the
same residual independently — sharing it would have the oracle share the
assumption it exists to test.

**Ruling 33 — the fixture set, not any one task, is the recurring hole.** Three
Task 10 mutations survived a green suite, all degenerate fixtures: no blank
text entity anywhere (the corpus *replaces* blanks with labels rather than
adding them), and **no text entity on a non-STANDARD style anywhere**, which is
Ruling 13's exact hole reopening one plan later in two new call sites. Both are
now covered by hand-built fixtures. Any new text call site must be checked
against both before it is called done.

**Ruling 53 — a gate that fails on correct code is worse than no gate.**
`text_paint_allocation_test` failed one full-suite run in eleven while the code
was right: the subject read 1.00, the *control* read 0.60, and because every
assertion was a ratio a low control **tightened** the bound. Ruling 31's ratios
answer the artefact only when all loops read low together. The repair is a
plausibility guard on the controls — whose answers are fixed by construction, so
retrying cannot mask a subject regression — and a failure message that names the
meter rather than the subject. Any measurement gate here needs the same
distinction between *a bad result* and *a bad read*.

**Ruling 54 — report a cache hit rate split by source or not at all.** Blended,
this corpus reads as a mediocre cache. Split, 9,928 label draws are served by
140 entries (98.6%) while all 4,000 attributes miss every time. One number hid
which half was the problem.

**Ruling 49/50 — a named killer is not a killer until it has fired.** Four of
the twenty spec mutants Task 13 ran survived the very suite the spec names for
them, and three of the four failed the same way: the test named the right
property against a fixture that could not tell right from wrong. *Rotation is
not symmetric about its sign* survives negating both sides. Every text case in
`extents_test` passes `entityBounds` an explicit measurer, so none of them
tests the document's field. `query_allocation_test` watched
`{Vector2, _Record}` and a per-candidate `TextMetrics` was not on the list —
**55.533 allocations per pick against a budget of 0.5**, invisible. Any spec
row that says "killed by X" is a hypothesis until X has been seen to go red.

**Ruling 51 — two spec mutants have no site, and that is the design working.**
*Lay the paragraph out at the effective em size* cannot be written:
`_buildEntry` is handed no size and `fontSize` is a constant. *Swap the
measurer mid-life* cannot be written either: `DraftDocument.textMeasurer` is
`final` for exactly that reason and its doc comment says so. Both were run in
their nearest reachable form and both restatements are recorded beside their
rows in the log — never silently.

**Ruling 39/40 — the cache limit is settled, with a measured margin.** 18 keys
at the working-set camera against 512; the limit does not move and Ruling 4's
one permitted raise is unspent. The margin is the key-pressure ladder, not a
feeling: binding starts around 12000–24000 world units wide.

**Ruling 44 — measurement machinery fails by printing a plausible number.**
Three of Task 12's mutants survived a green suite, and none of the three would
have errored: a dropped `DraftCanvas.drawText` forward prints a text-off row
identical to text-on; a `resetCounters` that also cleared the cache prints one
new layout per visible string and makes a working cache read as a failing gate;
a `TextKeySink` without the colour axis under-reports the gate's own number.
Any new counter, flag or rig sink needs a test that a *wrong reading* would
fail, not just one that a crash would.

**Ruling 34 — Plan 3c Task 11 Step 2's rung-4 criterion is backwards, and the
engine wins.** The step says to check that the crossed cells are "wider at the
same slope rather than more slanted". `composeTransform` shears *before* the
width-factor x-scale — `w * (x + k*y)`, which `textLocalTransform`'s doc names
as the DXF reading and `text_geometry_test.dart` pins as
`c = widthFactor * tan(oblique) * scale`. The stem slope is therefore
`widthFactor * tan(oblique)` and the wide cell **is** more slanted; the plan's
sentence describes the swapped order, which is the drawing rung 4 exists to
reject. If any later task quotes that sentence, it is quoting the mutant.

**Ruling 37 — a colour golden needs a repeated string, not a palette.** See
[Resume here](STATUS-HISTORY.md#resume-here); it constrains Task 13's "visibly by a colour
golden" requirement to a property of the fixture.

**Ruling 36 — a golden document must carry a real measurer.** The painter
takes its scale from `document.textMeasurer` while the sink lays the paragraph
out through its own; the glyphs sit inside the box the document believes they
occupy only while the two agree. A golden on `MetricModelMeasurer` pins a
drawing no production wiring produces — the degenerate fixture in its most
expensive form, a *reviewed* one.

**Ruling 17 — the corpus must hold exactly 20 distinct labels.**
`expect(labels.length, 20)`, not `lessThanOrEqualTo(20)`. The distribution is
the exact property Task 12's distinct-key measurement is taken against; a
degenerate assertion collapsing it to one label would silently void the gate.


---

## Commands

```sh
# engine (pure Dart)
cd packages/jet_cad_2d
dart test
dart test test/invariants/query_allocation_test.dart
dart run benchmark/query_throughput.dart
dart analyze && dart format --output=none --set-exit-if-changed .

# render layer (Flutter)
cd packages/jet_cad_2d_flutter
flutter test
flutter test --tags golden
flutter test --exclude-tags golden          # any platform but the one they were made on
flutter test --tags rig --run-skipped   # R1/R3, and R4's text counters
flutter test --tags rig --run-skipped test/rig/paint_microbench_test.dart \
  --plain-name "text paint at 50000"    # the gate's feasibility number
flutter analyze && dart format --output=none --set-exit-if-changed .

# real-device frame timings  (TEXT/DRAW_TEXT must be "true"/"false", not 1/0)
cd apps/dev_harness_2d
flutter drive --profile -d macos --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart \
  --dart-define=TEXT=true --dart-define=DRAW_TEXT=false
```

---

More gates: `packages/jet_cad_floor_plan`, `packages/jet_cad_restaurant_symbols`,
`apps/floor_planner`, `apps/restaurant_demo` — each `flutter test`,
`flutter analyze`, the format check; `tool/ci` — `dart test`,
`dart run tool/ci/check_guide.dart`; the host probe —
`tool/ci/host_probe.sh <git url> <sha>`, then
`tool/ci/old_host_probe.sh v0.3.0` and `tool/ci/old_host_probe.sh v0.4.0`.

---

## Traps

- **`flutter pub get` rewrites three `analysis_options.yaml` files** in this
  workspace. They must **never** be committed. Check `git status` after any pub
  operation.
- **The degenerate fixture is the dominant defect class here.** Plan 3c alone
  shipped it three times: fixtures all at the identity transform, all at the
  origin, all with default attributes, all one distinct string. Every one was
  caught by mutation testing, none by reading. A test that cannot be made red by
  a named mutation is not evidence.
- **`query_allocation_test` is a standing gate, not a Plan 2 artifact.** A
  `measure()` that allocates on a cache *hit* breaks it. This already bit once:
  Task 2's record-tuple memo allocated 41.5 objects per pick-path call, found in
  Task 6.
- **Reviewers verify claims independently.** Synthesized test output invalidates
  a task.
- **Never `git checkout` a file to revert a mutation.** It restores HEAD, so it
  silently wipes every uncommitted change in that file — Task 10 lost a full
  task's painter work that way. Copy the file aside first and restore from the
  copy in a `finally` block.
- **`flutter_test` renders Ahem, not a real font,** unless one is loaded. Any
  golden asserting something about glyph *shape* — that a mirrored label reads
  backwards, most of all — needs `test/golden/fonts/Roboto-Regular.ttf` loaded
  through a `FontLoader`, or it asserts nothing while looking like it does.
- **`bool.fromEnvironment` accepts only `"true"` and `"false"`.**
  `--dart-define=TEXT=1` reads as **false**. One device rig run measured the
  wrong document and printed numbers that looked entirely correct; only the
  `corpus=on/off` line it now prints gave it away.
- **`flutter drive` rewrites
  `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`.** CocoaPods
  bumps `MACOSX_DEPLOYMENT_TARGET` 10.15 → 12.0 in all three configurations.
  Same class as the `analysis_options.yaml` trap: revert it, do not commit it.
- **A rig transcript that stops early is a failed run, not a bad grep.** R4a
  and R4b printed `build`, `raster` and `command` and then threw, for months,
  because their repaint guard was the canvas-only copy. The numbers looked
  complete because the missing lines were the ones nobody expects to read. Any
  rig guard belongs *before* the first print or nowhere.
- **A transcript taken before 2026-08-21 has a different shape.**
  `screenSpaceLeafCount` moved out of R2's `lineweightScale` line into the
  shared `printInvariants` line. Old greps will miss it.
- **The `plan-3c` ledger is the only progress record** for that plan — TodoWrite
  was unavailable in the session that ran it. Keep appending to it.
- **This session's git proxy refuses tag pushes** (2026-10-06: *unexpected
  disconnect*, four tries); branch pushes work. A tag is pushed by the
  human.
- **The pub git cache keeps a mirror per URL.** A probe run against a new
  shallow `file://` clone at the same path fails (*Could not read* the
  parent); delete `~/.pub-cache/git/cache/<name>-*` first. CI starts
  clean.
