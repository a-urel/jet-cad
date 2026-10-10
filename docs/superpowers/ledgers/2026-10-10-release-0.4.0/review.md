# Release 0.4.0 — independent review

**Target:** `release/0.4.0` at `84c76df`
(`84c76dffa64669b833578cfa637b48a48935d4b0`, "chore: version 0.4.0 and its
changelog"), one commit on `main`'s `bb387c9`. Compared against `v0.3.0`
= `1b0c37a`. The range holds the host embedding API's Slices 1–4 (merged
at `1b32e0a`, `fe93d23`, `d26c9fe`, `4331c74`), O-10 (`a803f86`), O-11
(`aed5c4d`) and docs.

**Reviewer's setup:**
- The release worktree,
  `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/release-0.4.0`,
  is used read-only. The only writes there were made by the probe scripts,
  into the git-ignored outputs of `tool/ci/host_probe`.
- Two scratch worktrees under `…/scratchpad/rel4-review/`:
  - `old`, detached at `v0.3.0`;
  - `new`, detached at `84c76df`.
  Each ran `flutter pub get` once.
- Flutter 3.47.6 (`/opt/homebrew/bin/flutter`) on macOS (Darwin 27).
- An API dump tool of my own, `rel4-review/apidump`, built on analyzer
  13.3.0 from the pub cache. It lives outside the repo.

Nothing was committed or pushed, and Monépro was not touched. In my
scratch worktrees I made two temporary changes, both removed
afterwards: a test file (Check 2) and a simulated post-merge guide edit
(Check 4).

**Afterwards:**
- Both scratch worktrees were removed with `git worktree remove`.
  `git worktree list` shows neither.
- In the release worktree, `git status --short` is empty, and HEAD is
  still `84c76dffa64669b833578cfa637b48a48935d4b0`.

## Verdict

**Approved with fixes.** Every check that matters for a POS is green:
- **The API.** The barrel diff matches the CHANGELOG, with one gap
  (R-1). The only changes to existing signatures are new optional named
  parameters, plus two `@internal` members. "Nothing a 0.3.0 host calls
  changes its signature" holds as worded, and the 0.3.0 probe analyses
  clean at `84c76df`.
- **Schema 9.** 0.3.0 refuses a plan that 0.4.0 saves, with or without
  table data. The refusal is a `FormatException` that names schema 9,
  and `load` changes nothing.
- **Old plans and service layouts.** A schema-8 plan opens in 0.4.0
  unchanged: its re-encoding differs only in `schemaVersion`. Service
  layouts written by each tree were re-read by the other byte for byte.
- **Versions.** The five pubspecs, and nothing else, are at 0.4.0.
- **The probes.**
  - The host probe at the full SHA is green: 40 packages, no GPU
    renderer, a 42M web build.
  - The 0.3.0 host probe analyses clean against `84c76df`.
  - The 3.44 floor holds after `pub downgrade`.
- **Monépro's graph** resolves with 0.4.0, holds no GPU renderer, and
  moves only `pdf` and `printing`, each by a patch.
- **The gates I ran.** `flutter analyze` is clean in the five packages
  and the demo, and the demo passes (68). In the planner, the engine and
  the renderer, the only failures are the macOS ones already known
  (R-5).

The fixes are wording and none blocks the merge. R-1 is a CHANGELOG
gap; R-2 is a stale guide sentence.

## Findings

### R-1 — Minor: the CHANGELOG leaves out some of `editor.dart`'s additions

The barrel diff (Check 1) shows two gaps in the 0.4.0 section's
`editor.dart` bullets.

**Slice 1's additions to `PlannerShell` and `PlannerView`.** Each gains
these optional constructor parameters, each with a public getter:
- `tableOverlays` (`Widget?`);
- `userCamera` (`bool`, default `true`);
- `cameraEpoch` (`int Function()?`);
- `onCanvasPlaced` (`void Function(Object, Rect?)?`);
- `startFitIsRequest` (`bool`, default `false`).

They are in `planner_shell.dart` l. 198–219 and `planner_view.dart`
l. 111–154, added in `03c6d66` among others. The section lists Slice 3's
and Slice 4's `editor.dart` additions (CHANGELOG l. 165, l. 300–310), but
none of Slice 1's.

**A new exported widget, `PlannerTextKeys`.** It comes from
`src/shortcut_guard.dart` l. 97 (`8f45473`). `editor.dart` exports that
whole file, so the barrel gains it without an `editor.dart` diff.

The 0.3.0 review held (R-1) that `editor.dart`'s additions belong in the
CHANGELOG. Nothing breaks: every addition is optional or new.

**Fix:** add one bullet to 0.4.0:

> `jet_cad_floor_plan`'s `editor.dart`: `PlannerShell` and `PlannerView`
> take `tableOverlays`, `userCamera`, `cameraEpoch`, `onCanvasPlaced` and
> `startFitIsRequest` (the view's per-table widgets and camera, forwarded
> by `FloorPlanView`); `PlannerTextKeys`, the wrapper that keeps a
> field's keys from a host's bindings above it. Every one optional, its
> default today's behaviour.

### R-2 — Minor: the host guide still says every plan from 0.2.0 on is at schema 8

`docs/host-guide.md` l. 1997–1998, §11, says: "**Schema 8** *(since
0.2.0)*. A plan saved by 0.2.0 or later is at schema 8". The next bullet
(l. 2002) says that a plan saved by 0.4.0 or later is at schema 9. Both
cannot be true, and the first one became false with this release. The
0.3.0 text was right when 0.3.0 was current.

**Fix:** at l. 1997, replace "A plan saved by 0.2.0 or later is" with "A
plan saved by 0.2.0 or 0.3.0 is". Keep the rest of the bullet.

### R-3 — Info: "a hidden panel keeps its state" holds unless all three are hidden

CHANGELOG l. 251 says, of a run-time capabilities change, "a hidden
panel keeps its state". The guide (l. 1475–1476, l. 1614–1616) and
Slice 4's results ("Found, not fixed") are more exact. With
`selectionPanel`, `layerPanel` and `pagePanel` all false, the right
column is not built, and the panels' state is lost, such as the Layers
section's open state.

No shipped profile hides all three; `tablesOnly` keeps the Selection
panel. **Optional fix:** "a hidden panel keeps its state (unless all
three are hidden)".

### R-4 — Info: "Nothing a 0.3.0 host calls changes its signature" is exact as worded

The barrel diff has 20 changed lines. 18 of them only add optional named
parameters. The other two are `@internal` members, and both are listed
or harmless:
- `FloorPlanController.camera`: was a `CameraController`, is now
  `ValueListenable<FloorPlanCamera>`. The CHANGELOG lists this; the old
  member is renamed `cameraController`.
- `canvasMeasured`: gains `{Offset? chrome}`.

**Value types.** `FloorPlanTable`, `TableStatus`, `TableGroup`,
`FloorPlanExport` and `ServiceLayoutRestore` have byte-identical class
bodies in both trees. So spec P-1 ("no `==`, `hashCode` or `toString`
changes") holds for them.

**Implementers and subclasses.**
- `FloorPlanController` is still a plain class, so an implementer must
  add the new members. The CHANGELOG says so.
- In the engine, a subclass of `DocumentTree` that overrides `addNode`
  would have to add `{int? index}`. A POS has no reason to subclass it.

The 0.3.0 host probe analyses clean (Check 5). No fix needed.

### R-5 — Info: on macOS, three suites fail only where they are known to

The results, run in my `new` worktree:
- **Planner** (`flutter test`): `+1908 ~3 -1`. The one failure is
  Slice 3's T-1 caption test in `test/service/table_theme_painter_test.dart`
  ("Expected: a value greater than <176420>, Actual: <175568>"). It is a
  glyph-pixel count, and STATUS lists it under "Owed to the human" as a
  macOS failure.
- **Engine** (`dart test`): `+1270 -2`. The two failures are the
  `generate_document_test` fingerprints, which are in the standing set
  and owe a macOS re-baseline.
- **Renderer** (`flutter test`): `+1431 ~1 -5`. The five failures are
  the text ladder's rungs 1–5, and the skip is the paint micro-benchmark
  rig. Both are in the standing set. The standing set's two text-lod
  rungs pass here, as STATUS records for macOS.

CI on Linux is the gate of record. This is Info for a macOS developer
running the gates by hand.

### R-6 — Info: a POS's lock moves `pdf` and `printing` by a patch, as at 0.3.0

I resolved Monépro's own `pubspec.yaml` and `pubspec.lock` (develop,
`e4cb1f1`), adding the guide's two git dependencies at `84c76df`. It
adds the four jet-cad packages at 0.4.0 and moves:
- `pdf` 3.13.0 → 3.13.1;
- `printing` 5.15.0 → 5.15.1.

That is 186 → 190 packages, with no GPU renderer, and the `sdks:` floor
is unchanged (`flutter: ">=3.44.0"`). Monépro pins Flutter 3.47.6 in all
four workflows. It still does not depend on jet-cad: nothing in its
`pubspec.yaml`, `lib/` or `test/`.

### R-7 — Info: other version strings, correctly left alone

- `packages/jet_cad/pubspec.yaml` `version: 0.3.0`: the dormant line,
  unchanged since Plan 04, as the 0.3.0 review found.
- `.github/workflows/ci.yml` l. 162–166 and `tool/ci/test/scripts_test.dart`
  SC18/SC19 name `v0.3.0` on purpose: the P-1 job analyses the 0.3.0
  host's code.
  - After the tag, the human may want the job to analyse `v0.4.0`'s
    `main.dart` as well. That is a follow-up, not part of this release.
- `apps/floor_planner/lib/document_files_web.dart` l. 11: "0.4.0 removed
  it and 0.3.x's leaks" is about the `cross_file` package (`0b3bf76`,
  2026-09-30), not jet-cad.
- Fixtures that are not jet-cad versions:
  - `scene: ^0.3.0` in `no_gpu_dependency_test.dart` l. 343;
  - `scene: ">=0.3.0"` in `host_lock_test.dart` l. 129.
- STATUS l. 3–4, the roadmap's row 14 ("unreleased") and the guide's §1
  placeholders are the post-merge lines (Check 4).

### R-8 — Info: Known limits leave out one item that a web POS can meet

Slice 4's results list, under "Found, not fixed", an issue in Flutter
web with semantics on: "a click on a button's semantics node unfocuses
a focused text field". It is Flutter's behaviour, not the planner's, and
mouse users without the semantics tree are unaffected. Neither the
CHANGELOG nor the guide mentions it.

Monépro ships a web build, so a screen-reader user typing in a planner
field (a panel's field, the Symbols search, a host field in a bar) would
meet it. **Optional:** add one Known-limits sentence.

The other "Found, not fixed" items are either in the Known limits or
the guide, or do not reach a host. They are:
- the stale select cursor;
- the `editLayers: false` tooltip text;
- the one-frame `StateError` when two views are mounted on one
  controller, which the guide's one-view rule covers.

### R-9 — Info: "but for the fix below" is in the singular

The intro (l. 23–25) says that every pixel and key is 0.3.0's "but for
the fix below". The section has two such bullets:
- "Changes a host may notice": fits are clamped to the zoom bounds, a
  no-op for real plans at the default bounds.
- "A fix a 0.3.0 host may notice": `undo()` and `redo()` wait for an
  idle tool, the export guard is shared, and the fields keep their keys.

Only the second changes a key. The sentence is defensible as written.
"but for the changes below" would be exact. Optional.

## Check 1 — the CHANGELOG against the API diff

**Method.** I wrote `apidump/bin/apidump.dart`, which uses analyzer
13.3.0's `AnalysisContextCollection`. For each barrel it resolves the
library and walks `exportNamespace.definedNames2`. For each name it
prints:
- the element kind and its display string;
- for interfaces, a `<header>` line with `abstract`, `sealed`, `final`,
  `base`, `interface` and `mixin`, and the supertypes;
- every public constructor, field, getter, setter and method, with the
  flags `@internal`, `@visibleForTesting`, `@deprecated`, `abstract` and
  `static`.

Unlike the 0.2.0 and 0.3.0 tool, a field's `@internal` is carried onto
its synthetic getter. One artefact: a top-level function prints as
`[static]`.

The barrels:
- `jet_cad_2d`: `jet_cad_2d.dart`, `testing.dart`.
- `jet_cad_2d_flutter`: `jet_cad_2d_flutter.dart`, `export_testing.dart`.
- `jet_cad_floor_plan`: `jet_cad_floor_plan.dart`, `editor.dart`,
  `symbols.dart`, `symbol_sources.dart`.
- `jet_cad_restaurant_symbols.dart`.
- `jet_cad_2d_gpu.dart`.

```
$ dart run bin/apidump.dart …/rel4-review/old ${=B} > old.api 2>old.err; echo old=$?
old=0
$ dart run bin/apidump.dart …/rel4-review/new ${=B} > new.api 2>new.err; echo new=$?
new=0
    6345 old.api
    6887 new.api
# stderr: names per barrel, old → new
jet_cad_2d.dart 248 → 248; testing.dart 5 → 5; jet_cad_2d_flutter.dart 177 → 180;
export_testing.dart 16 → 16; jet_cad_floor_plan.dart 28 → 50; editor.dart 343 → 349;
symbols.dart 16 → 16; symbol_sources.dart 4 → 4; jet_cad_restaurant_symbols.dart 6 → 6;
jet_cad_2d_gpu.dart 9 → 9
$ diff old.api new.api | grep -c '^<'      →  20
$ diff old.api new.api | grep -c '^>'      → 562
  (by barrel: 426 host barrel, 87 editor.dart, 44 jet_cad_2d_flutter, 5 jet_cad_2d)
```

**The 20 changed lines** (`<` at v0.3.0). Each has a `>` counterpart
that only adds optional named parameters, except the two `@internal`
ones:

```
< jet_cad_2d.dart :: AddNodeCommand .. AddNodeCommand(Node node)
> jet_cad_2d.dart :: AddNodeCommand .. AddNodeCommand(Node node, {int? index})
< jet_cad_2d.dart :: DocumentTree .. void addNode(Node node)
> jet_cad_2d.dart :: DocumentTree .. void addNode(Node node, {int? index})
< …GripCache(…, {ObjectGripProvider? objects})                    > + SelectGates? gates
< …InteractionLayer({Key? key, required ToolController tools, required Widget child})  > + bool autofocus = true
< …SelectTool({MoveResolver? moveResolver})                        > + SelectGates? gates
< …SelectionOverlayPainter({…, void Function()? onPaintForTest})   > + double selectionStrokePixels = kSelectionStrokePixels
< …ToolPointerEvent({…, double? reachRadiusWorld})                 > + Duration timeStamp = Duration.zero
< …factory FloorPlanController({…, String? json})                  > + double minScale = kMinScale, double maxScale = kMaxScale
< …FloorPlanController .. [@internal] CameraController get camera  > ValueListenable<FloorPlanCamera> get camera; [@internal] CameraController get cameraController
< …FloorPlanController .. [@internal] field final late CameraController camera
< …FloorPlanController .. [@internal] void canvasMeasured(FloorPlanMode shown, Offset origin)  > + {Offset? chrome}
< …FloorPlanView({…, void Function(String)? onSplitRequested})     > + 19 named, optional (below)
< editor.dart :: LayerPanel / PagePanel (…)                         > + bool editable = true
< editor.dart :: PlannerShell(…)                                    > + startFitIsRequest, cameraEpoch, userCamera, onCanvasPlaced, tableOverlays, editorBar, onIdle, capabilities, onTools, onToolChanged, shortcuts, autofocus, tableInspector, onDelete
< editor.dart :: PlannerView(…)                                     > + selectionStrokePixels, startFitIsRequest, tableOverlays, cameraEpoch, userCamera, onCanvasPlaced, autofocus
< editor.dart :: SelectionPanel(…)                                  > + Listenable? selectionChanges, capabilities = full
< editor.dart :: SymbolPanel(…)                                     > + filter, bool placeable = true, toolChanges
< editor.dart :: SymbolPlaceTool(armed, {WallFaces? faces})         > + canRotate, canMirror
< editor.dart :: ToolPalette(…)                                     > + bool showFill = true, toolChanges
```

The real `>` lines are quoted in full in `rel4-review/api.short.diff`.

| Barrel | Change | In CHANGELOG |
|---|---|---|
| host | 22 new names: `FloorPlanCamera`, `FloorPlanDesignChange` and its four subclasses, `FloorPlanEditorAction`, `FloorPlanEditorBar`, `FloorPlanEditorCapabilities`, `FloorPlanExportChoice`, `FloorPlanExportDpi`, `FloorPlanExportFormat`, `FloorPlanOverlayLayout`, `FloorPlanOverlaySize`, `FloorPlanServiceAction`, `FloorPlanServiceBar`, `FloorPlanSymbol`, `FloorPlanTableDetail`, `FloorPlanTableOverlay`, `FloorPlanTableOverlayBuilder`, `FloorPlanTheme`, `FloorPlanTool` | yes, every one, with its members |
| host | `FloorPlanController`: `minScale`/`maxScale`, `tableDetails`, `tableAt`, `camera`, `canvasRect`, `worldToGlobal`, `globalToWorld`, `panBy`, `zoomBy`, `centerOn`, `setTableData`, `setTablesData`, `designChanges`, `mergeCandidate`, `exportPlan`, `printPlan`, `activeTool`, `selectTool`, `editorSelectedTables`, `deleteSelection` | yes |
| host | `FloorPlanView`: `userCamera`, `tableOverlayBuilder`/`Layout`/`Modes`, `onTablesMoved`, `onTableDoubleTap`, `onFloorTap`, `onTableHover`, `theme`, `onExportDialog`, `onPageFlowError`, `serviceBar`, `editorBar`, `editorCapabilities`, `tableInspectorBuilder`, `shortcuts`, `autofocus` | yes |
| host | `@internal`: `cameraController`, `tableDetailInstances`, `pageFlowReady`, `isDisposed`, `owesFirstFit`, `cameraEpoch`, `registerDelete`/`Idle`/`Tools`, `canvasAssumed`, `canvasPlaced`, `chromeMoved`, `toolChanged`, `FloorPlanCamera(transform)`, `FloorPlanSymbol.of`; `@visibleForTesting` `designScans` | rightly omitted (`camera`'s rename listed) |
| `jet_cad_2d` | `AddNodeCommand({index})` + getter, `DocumentTree.addNode({index})`, `indexInParent` | yes (O-10) |
| `jet_cad_2d_flutter` | `InputClaim`, `RenderInputClaim` | yes |
| `jet_cad_2d_flutter` | `ToolPointerEvent.timeStamp`, `PaperPalette.withSelection`, `SelectionOverlayPainter.selectionStrokePixels` | yes |
| `jet_cad_2d_flutter` | `SelectGates`, `SelectTool.gates`/`deleteSelection`, `GripCache(gates:)`/`moveGripsLive`/`stretchGripsLive`/`gatesChanged`, `InteractionLayer.autofocus` | yes |
| `editor.dart` | `isControlCodeUnit`, `TableDiagnosticCodes.invalidData` | yes |
| `editor.dart` | `PlannerView.selectionStrokePixels` | yes |
| `editor.dart` | Slice 4's `PlannerShell`, `PlannerView.autofocus`, `DocumentToolbar.groups`, `ToolPalette`, `SymbolPanel`, `SymbolPlaceTool`, `SelectionPanel`, `LayerPanel`, `PagePanel`, four `Shell*` typedefs | yes |
| `editor.dart` | `PlannerShell`/`PlannerView`: `tableOverlays`, `userCamera`, `cameraEpoch`, `onCanvasPlaced`, `startFitIsRequest`; `PlannerTextKeys` | **no**: R-1 |
| `testing`, `export_testing`, `symbols`, `symbol_sources`, restaurant, GPU | none | — |

**Members checked against the CHANGELOG's lists:**
- `FloorPlanTool` has the palette's fifteen values, then `symbol`.
- `FloorPlanTheme` has sixteen nullable fields, with `copyWith`,
  `merge`, `lerp`, `==`, `hashCode` and `toString`.
- `FloorPlanEditorCapabilities` has the twenty-two flags plus `tools`,
  `full`, `tablesOnly`, `readOnly`, `copyWith`, `==` and `hashCode`.
- `FloorPlanTableDetail` has `table`, `center`, `size`, `rotation`,
  `mirrored`, `corners`, `layer`, `locked` and `data`.
- `FloorPlanCamera` has `scale`, `worldToCanvas`, `canvasToWorld`,
  `visibleWorld` and `==`.
- The exporter types have the values listed.

**Constants checked against the source:**
- `kMinScale = 0.001` and `kMaxScale = 100.0` (`startup_plan.dart`
  l. 50–51);
- the `1e-6` floor (`floor_plan_controller.dart` l. 282, 390);
- the table-data limits 32, 64 and 1024 and `'jetcad.table_data'`
  (`table_data_component.dart` l. 20–26, 70);
- `kDoubleTapTimeout` / `kDoubleTapSlop` (300 ms, 100 px;
  `floor_plan_view.dart` l. 162);
- `FloorPlanExportChoice.initial`, PDF at `d150`
  (`floor_plan_types.dart` l. 103);
- `kSelectionStrokePixels = 2.0`.

**Nothing listed is wrong.** One wording point is R-3.

**Dependencies.** The pubspecs change only in their versions and in the
planner's new `vm_service: ^15.2.0`, which is under `dev_dependencies`
(pubspec l. 34–38). No host-graph change comes from it: the probe has 40
packages, as at 0.3.0.

## Check 2 — the compatibility claim

**The source facts:**
- `kSchemaVersion` is 8 at `v0.3.0` and 9 at `84c76df`
  (`schema_version.dart` l. 38 → l. 48).
- The v8→v9 migration is empty: `json_codec.dart` l. 106 accepts
  `1 <= version <= kSchemaVersion`.
- `service_layout.dart` and the rest of `jet_cad_2d/lib/src/codec` are
  unchanged since `v0.3.0`; only `schema_version.dart` changed:

```
$ git diff --stat v0.3.0..HEAD -- packages/jet_cad_floor_plan/lib/src/host/service_layout.dart packages/jet_cad_2d/lib/src/codec
 packages/jet_cad_2d/lib/src/codec/schema_version.dart | 12 +++++++++++-
 1 file changed, 11 insertions(+), 1 deletion(-)
$ git diff --stat v0.3.0..HEAD -- packages/jet_cad_2d_gpu packages/jet_cad_restaurant_symbols
 packages/jet_cad_2d_gpu/pubspec.yaml                         | 2 +-
 packages/jet_cad_restaurant_symbols/assets/restaurant.jetlib | 2 +-   # re-encoded at 9 (listed)
 packages/jet_cad_restaurant_symbols/pubspec.yaml             | 2 +-
```

**A cross-tree round trip.** I put one temporary test in each scratch
tree's `packages/jet_cad_floor_plan/test/`, outside git, and removed it
afterwards. `--dart-define`s choose the tree and the phase. The input
is v0.3.0's demo `salon.json` at schema 8. (The release's copy differs
only in `"schemaVersion": 9`; see `git diff v0.3.0..HEAD -- …/salon.json`.)

- **Write**, in each tree:
  1. Construct a `FloorPlanController` from it and save `designJson()`.
  2. Switch to selection, move table `1` by (350, −125), and save
     `serviceLayoutJson()` and `tables`.
  3. In the new tree only, also save the plan after
     `setTableData('1', {'pos_table_id': 'abc-123'})`.
- **Read in old:**
  1. Construct from each new plan, with and without data, and require a
     `FormatException`.
  2. `load` each into a live controller, and require a
     `FormatException` with `designJson()` unchanged.
  3. Restore the new tree's layout onto old's plan, and require nothing
     dropped and `serviceLayoutJson()` byte-equal to it.
- **Read in new:**
  1. Construct from the old tree's schema-8 plan.
  2. Require `designJson()` to equal the new tree's own encoding, and
     `tables` to equal both trees' `tables`.
  3. Require `dirty` false, and every `tableDetails` entry with empty
     `data`.
  4. Restore old's layout, and require nothing dropped and the output
     byte-equal.

```
00:00 +0: xfer old write
wrote 18926 B plan, 165 B layout, 11 tables, schema 8
00:00 +1: All tests passed!
00:00 +0: xfer new write
wrote 18926 B plan, 165 B layout, 11 tables, schema 9, data on table 1: true
00:00 +1: All tests passed!
00:00 +0: xfer old read
old reads new.design.json: FormatException: FormatException: Not a floor plan: SchemaVersionError: unsupported schemaVersion 9 (this build writes 8)
old load(new.design.json): FormatException: Not a floor plan: SchemaVersionError: unsupported schemaVersion 9 (this build writes 8); plan unchanged
old reads new.data.design.json: FormatException: FormatException: Not a floor plan: SchemaVersionError: unsupported schemaVersion 9 (this build writes 8)
old load(new.data.design.json): FormatException: Not a floor plan: SchemaVersionError: unsupported schemaVersion 9 (this build writes 8); plan unchanged
old reads new layout: byte-equal, applied 1, dropped 0
00:00 +1: All tests passed!
00:00 +0: xfer new read
new reads old: plan opens (designJson == new.design.json, tables equal, 11 details, no data, clean), layout byte-equal, applied 1, dropped 0
00:00 +1: All tests passed!
$ cmp old.layout.json new.layout.json && echo "layouts byte-equal"
layouts byte-equal
# python3 -I, comparing the plans:
old len 18926 new len 18926 data len 18989
old==new with 8->9 swapped: True
key /components/jetcad.table_data only in data {"29": {"data": {"pos_table_id": "abc-123"}}}
salon v8 == old re-encode (as JSON): True
```

The claims hold:
- 0.3.0 refuses a 0.4.0 plan, with or without data, and the message
  says why.
- A 0.3.0 plan opens in 0.4.0 unchanged, and is re-saved at schema 9
  with no other byte different.
- Service layouts cross in both directions byte for byte.
- Table data is the component `jetcad.table_data` on the placement
  (handle 29 for table `1`), as the CHANGELOG says.

## Check 3 — versions

```
$ grep -n "^version:" packages/*/pubspec.yaml apps/*/pubspec.yaml tool/ci/pubspec.yaml
packages/jet_cad_2d/pubspec.yaml:5:version: 0.4.0
packages/jet_cad/pubspec.yaml:3:version: 0.3.0                 # dormant (R-7)
packages/jet_cad_2d_flutter/pubspec.yaml:6:version: 0.4.0
packages/jet_cad_2d_gpu/pubspec.yaml:6:version: 0.4.0
packages/jet_cad_restaurant_symbols/pubspec.yaml:8:version: 0.4.0
apps/dev_harness/pubspec.yaml:4:version: 0.0.1
packages/jet_cad_floor_plan/pubspec.yaml:8:version: 0.4.0
apps/dev_harness_2d/pubspec.yaml:7:version: 0.0.1
apps/restaurant_demo/pubspec.yaml:8:version: 0.0.1
tool/ci/pubspec.yaml:7:version: 0.1.0
apps/floor_planner/pubspec.yaml:7:version: 0.0.1
$ git show HEAD -- packages | grep '^[-+]version'      # five pairs
-version: 0.3.0 / +version: 0.4.0   (×5)
```

**Stray versions.** I ran `git grep -nE '0\.3\.0|v0\.3|0\.4\.0|v0\.4' --
. ':!docs/superpowers' ':!*.lock' ':!*lock.txt' ':!CHANGELOG.md'
':!STATUS-HISTORY.md'`, outside `packages/jet_cad/`. Every hit is one of
these:
- the five pubspecs;
- the guide's 0.4.0 lines (Check 4);
- STATUS's history and in-flight lines;
- the roadmap's row 14;
- the P-1 job and its tests;
- the `scene` fixtures;
- the `cross_file` comment (R-7).

Nothing stale needs to move except the guide's sentence (R-2).

**The workspace lock and `analysis_options.yaml`.** I checked them in
the scratch `new` worktree, after its `flutter pub get`:

```
$ git -C …/new status --short        # before my test file was added
(empty)
$ git diff --stat v0.3.0..HEAD -- '*analysis_options.yaml' '*pubspec.lock'
(empty)
```

## Check 4 — `docs/host-guide.md`

- **Header** (l. 7): **0.4.0**.
- **§1** uses the placeholder form, version for version:
  ```
  $ diff <(git show dcfff59:docs/host-guide.md | sed -n 1,56p | sed 's/0\.3\.0/0.4.0/g') <(sed -n 1,56p docs/host-guide.md) && echo "§1 identical to dcfff59's, version for version"
  §1 identical to dcfff59's, version for version
  ```
  `dcfff59` is 0.3.0's release commit. l. 18–19 read "the SHA the
  release tag `v0.4.0` points at (`git rev-parse 'v0.4.0^{commit}'`; the
  guide on `main` names it)"; l. 29 and l. 34 read `ref: <the commit SHA
  of v0.4.0>`; l. 41 reads `ref: v0.4.0`.
- **No unreleased markers.**
  `grep -n -i 'unreleased\|not yet released\|on main\b\|on \`main\`'`
  finds only l. 19, the placeholder's "the guide on `main` names it". The
  release commit turns all 17 "*unreleased on `main`*" markers into
  "*since 0.4.0*" (`git show HEAD -- docs/host-guide.md`).
- **Each "since 0.4.0" is new since `v0.3.0`** (the API diff, Check 1):
  - l. 213: the overlay arguments and the four event callbacks.
  - l. 216 and l. 1715: `theme`.
  - l. 218 and l. 1194: the last eight chrome-and-keys arguments.
  - l. 235: the public camera, `panBy`/`zoomBy`/`centerOn` and the bounds.
  - l. 528: host data.
  - l. 547: per-table widgets.
  - l. 941 and l. 1189: the four gestures.
  - l. 1211: the bars.
  - l. 1433: capabilities.
  - l. 1630: keyboard and focus.
  - l. 1972: capabilities are not a security boundary.
  - l. 1978: `shortcuts: false` and `deleteSelection()`.
  - l. 2002: schema 9.

  Every "since 0.3.0" (l. 233, l. 447) and every "since 0.2.0" is kept.
- **Stale:** the l. 1997 schema-8 sentence (R-2).
- **The floor paragraph** (l. 51–52): "Flutter 3.44 or later; 0.4.0 was
  built and tested with Flutter 3.47.6". Both are true (Check 5, and
  `flutter --version`: `Flutter 3.47.6 • channel stable`).
- **The Known limits are backed by the guide:**
  - `canvasRect` (l. 622);
  - `selectTool(symbol)` and `against-wall` (l. 1621–1623);
  - `onTapOutside` (l. 1658, l. 1706);
  - the rulers (l. 1534);
  - data "for shape, never meaning" (l. 1108).

```
$ dart run tool/ci/check_guide.dart          # in the release worktree
docs/host-guide.md: all 48 code blocks are in the host probe
check_guide exit=0
$ cd tool/ci && dart test 2>&1 | tail -3
00:03 +61: test/scripts_test.dart: SC19 old_host_probe.sh the tag's main.dart analysed; this commit's put back
00:04 +62: test/scripts_test.dart: SC19 old_host_probe.sh analysis fails: exit non-zero, main.dart put back
00:04 +63: All tests passed!
exit=0
```

**The post-merge edit, simulated** in my scratch `new` worktree and then
reverted. As `14616d9` did for 0.2.0, it puts a dummy 40-hex SHA into
l. 18–19 ("…points at,\n`<S>` (the merge of release 0.4.0 into\n`main`):")
and into l. 29 and l. 34:

```
 docs/host-guide.md | 9 +++++----
 1 file changed, 5 insertions(+), 4 deletions(-)
docs/host-guide.md: all 48 code blocks are in the host probe
check_guide exit=0
00:00 +5: All tests passed!                # tool/ci test/guide_test.dart
reverted
```

The post-merge lines are the same as 0.3.0's:
- STATUS l. 3–4 and the "In flight" bullet;
- "Resume here";
- the roadmap's row 14 ("unreleased" ×4 → "released in 0.4.0", and
  "**Release 0.4.0**: merged at `<S>`, tag `v0.4.0`.");
- the ledger archived to `docs/superpowers/ledgers/…-release-0.4.0/`.

`tool/ci` needs no edit, apart from R-7's optional P-1 follow-up.

## Check 5 — gates and the probe

`flutter analyze`, in the scratch `new` worktree at `84c76df`:

```
== packages/jet_cad_2d
No issues found! (ran in 1.5s)
exit=0
== packages/jet_cad_2d_flutter
No issues found! (ran in 4.2s)
exit=0
== packages/jet_cad_floor_plan
No issues found! (ran in 5.4s)
exit=0
== packages/jet_cad_restaurant_symbols
No issues found! (ran in 2.8s)
exit=0
== packages/jet_cad_2d_gpu
No issues found! (ran in 2.5s)
exit=0
== apps/restaurant_demo
No issues found! (ran in 3.0s)
exit=0
```

The suites, on macOS (see R-5):

```
$ cd packages/jet_cad_floor_plan && flutter test
01:39 +1908 ~3 -1: Some tests failed.            # T-1, macOS, owed in STATUS
$ cd apps/restaurant_demo && flutter test
00:17 +68: All tests passed!
demo exit=0
$ cd packages/jet_cad_2d && dart test
00:06 +1270 -2: Some tests failed.
Failing tests:
  test/testing/generate_document_test.dart: both text fractions default to zero and change nothing
  test/testing/generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte
$ cd packages/jet_cad_2d_flutter && flutter test
00:24 +1431 ~1 -5: Some tests failed.
render exit=1
# [E]: text_ladder_golden_test.dart rungs 1–5 (RenderBackend.canvas); the skip is the paint micro-benchmark rig
```

**The host probe at the full SHA**, run from the release worktree.
Before the run, `tool/ci/host_probe` already held ignored outputs from
an earlier run (09:01). The script removes them and rebuilds.

```
$ git rev-parse HEAD
84c76dffa64669b833578cfa637b48a48935d4b0
$ tool/ci/host_probe.sh "file:///Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/release-0.4.0" 84c76dffa64669b833578cfa637b48a48935d4b0; echo "probe exit=$?"
probe exit=0
# from its log:
…/tool/ci/host_probe/pubspec.lock: 40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
No issues found! (ran in 3.5s)
Compiling lib/main.dart for the Web...                             33.3s
✓ Built build/web
host probe: no GPU renderer, no build hook; build/web is  42M
```

The probe's lock resolves the four host packages at `resolved-ref:
"84c76dffa64669b833578cfa637b48a48935d4b0"` (4 matches), each at
`version: "0.4.0"`, and its `sdks:` reads `dart: ">=3.13.0 <4.0.0"`,
`flutter: ">=3.44.0"`.

**The 0.3.0 host's code** against this commit:

```
$ tool/ci/old_host_probe.sh v0.3.0; echo "old probe exit=$?"
old probe exit=0
Analyzing host_probe...
No issues found! (ran in 3.4s)
old host probe: v0.3.0's main.dart analyses against 84c76dffa64669b833578cfa637b48a48935d4b0
$ git status --short          # in the release worktree, afterwards
(empty)
```

**The Flutter floor.** I copied the resolved probe (`lib`, `web`,
`pubspec.yaml` and the lock) to `rel4-review/probe-floor`, so that the
release worktree's probe stays at the commit's resolution:

```
$ flutter pub downgrade | tail -3
Changed 26 dependencies!
25 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
exit=0
sdks:
  dart: ">=3.12.0 <4.0.0"
  flutter: ">=3.44.0"
$ dart run …/tool/ci/check_host_lock.dart pubspec.lock
pubspec.lock: 40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
lockcheck exit=0
$ flutter analyze           # at the downgraded versions
No issues found! (ran in 5.7s)
analyze exit=0
```

The floor of Flutter 3.44 (Dart 3.12) holds, as at 0.3.0. The host
packages' pubspecs still say `flutter: ">=3.44.0"`, and the GPU package
says `>=3.47.0`; neither changed. No Flutter 3.44 SDK is installed here,
so as in 0.3.0's review the floor is shown by the downgraded resolution
and analysis, not by a 3.44 build.

## Check 6 — a POS's graph (Monépro)

I copied Monépro's `pubspec.yaml` and `pubspec.lock` (develop,
`e4cb1f1`, "docs(cloud): verify #620's background Flutter install…",
2026-10-09) to `rel4-review/monepro-res`. There I added the guide's two
git dependencies at `file://<release worktree>` @
`84c76dffa64669b833578cfa637b48a48935d4b0`. Monépro has no jet-cad
dependency to repoint. Nothing in Monépro was touched.

```
$ flutter pub get | tail -4
  yaml 3.1.3 (3.1.4 available)
Changed 6 dependencies!
89 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
pub get exit=0
+ jet_cad_2d 0.4.0 from git …/release-0.4.0 at 84c76d in packages/jet_cad_2d
+ jet_cad_2d_flutter 0.4.0 from git …/release-0.4.0 at 84c76d in packages/jet_cad_2d_flutter
+ jet_cad_floor_plan 0.4.0 from git …/release-0.4.0 at 84c76d in packages/jet_cad_floor_plan
+ jet_cad_restaurant_symbols 0.4.0 from git …/release-0.4.0 at 84c76d in packages/jet_cad_restaurant_symbols
> pdf 3.13.1 (was 3.13.0)
> printing 5.15.1 (was 5.15.0)
$ dart run …/tool/ci/check_host_lock.dart pubspec.lock
pubspec.lock: 190 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
lockcheck exit=0
# versions changed against Monépro's lock (python, parsing both locks):
packages 186 -> 190
jet_cad_2d None -> 0.4.0
jet_cad_2d_flutter None -> 0.4.0
jet_cad_floor_plan None -> 0.4.0
jet_cad_restaurant_symbols None -> 0.4.0
pdf 3.13.0 -> 3.13.1
printing 5.15.0 -> 5.15.1
# sdks: before and after
  dart: ">=3.12.0 <4.0.0"
  flutter: ">=3.44.0"
```

`resolved-ref: "84c76dff…"` has 4 matches. No GPU renderer is in the
graph. Monépro pins Flutter 3.47.6 in `deploy-production.yml`,
`quality-gates.yml`, `tests.yml` and `deploy-staging.yml`. See R-6.

## Check 7 — the CHANGELOG's intro and Known limits

**The intro** (l. 15–27) is accurate:
- it names the four slices' substance;
- "Move every terminal that shares stored plans together", schema 9,
  with or without data (Check 2);
- service layouts are unchanged (Check 2);
- the look, the bars, the capabilities and the keys are never stored;
- the signature sentence (R-4);
- CI analyses the 0.3.0 probe (`ci.yml` l. 162–166);
- the floor of 3.44 and Flutter 3.47.6 (Check 5).

Two small points:
- "but for the fix below" (R-9).
- O-10 and O-11 are in the section's bullets (l. 183–199), not in the
  intro's first sentence. That is fine: the intro describes the API.

**Known limits** (l. 312–336). Each claim is true and backed by the
guide (Check 4):
- the looks owed: the badges, double tap, pointer line, Link tables, the
  POS look, the three profiles and the own bar;
- the native de/tr read;
- the refused R/M reaching the next binding;
- `selectTool(symbol)` re-arming only the last symbol;
- `against-wall` under `rotate: false` (Slice 4's F-7);
- the rulers cancelling a shape;
- the `TextField` focus with `onTapOutside`;
- capabilities are not a security boundary;
- `canvasRect` and a transforming ancestor;
- data checked for shape, not meaning;
- Q2;
- the GPU package, `packages/jet_cad` and the apps are not released.

0.3.0's Q-Z1 and Q-Z4 limits are now answered, by the public camera and
`tableOverlayBuilder`, and by `FloorPlanTableDetail.data` and
`setTableData`. Dropping them is right.

**What Monépro will meet**, against the slices' "Found, not fixed" and
"Owed":
- Schema 9 moves every terminal at once: in the intro, in bold.
- A screen-reader user on the web: missing (R-8).
- Many badges per frame: the 117-badge software cost is unmeasured on a
  device. It is covered by "the smoothness of pan and zoom with them have
  not been checked".
- Monépro's own owed items are Q-H3 (overlay sizes and detail levels)
  and its real shadcn tokens. They are its decisions, not the release's
  limits; STATUS's "Resume here" tracks them.
- The macOS T-1 test failure is a test of the planner's own, not
  behaviour a host sees (R-5).
