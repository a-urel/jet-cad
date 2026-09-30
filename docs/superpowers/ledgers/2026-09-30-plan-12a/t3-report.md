# Task 3 report — the set-up helper, the default page, the registration

**Commit:** `7b08ae9` `feat(app): the empty document and one registration` on
`plan-12a/document-lifecycle` (parent `06c9c44`). Not pushed. It touches 4 files, all
in the app: `lib/new_document.dart` (new), `lib/parametric/catalog.dart`,
`lib/startup_plan.dart`, `test/new_document_test.dart` (new). No engine or render file
changed, and `analysis_options.yaml` was not committed.

## API as landed

- `lib/parametric/catalog.dart`: `void registerAppComponents(ComponentRegistry r)`
  calls `PageComponent.register(r)` and then `parametricCatalog.registerComponents(r)`.
  Its dartdoc says to call it once per registry, because a second
  `PageComponent.register` wipes a live page. The catalog's registrations skip types that
  are already registered.
- `lib/new_document.dart` is pure Dart, with no Flutter import:
  - `DraftDocument prepareDocument(TextMeasurer measurer)` does
    `DraftDocument.empty(measurer:)`, `registerAppComponents(doc.components)`,
    `header.units = DrawingUnits.millimeters` and `ensureDashedLinetype(doc)`.
  - `PageComponent defaultPage() => PageComponent(originX: -7425, originY: -5250);`
  - `DraftDocument newDocument(TextMeasurer measurer)` does `prepareDocument`, then
    `execute(SetComponentCommand<PageComponent>(root, defaultPage()))`, then
    `clearHistory()`.
- `lib/startup_plan.dart`:
  - `startupPlan` now begins with `prepareDocument(measurer)`. This replaces
    `DraftDocument.empty` and `ensureDashedLinetype`.
  - The late `PageComponent.register(doc.components)` and `header.units = …` lines are
    removed, because the set-up now does both. The page is still attached at the same
    point, centred on the extents.
  - The first-line comment is corrected (D4): the file is the sample for Open sample and
    for tests, and launch and New use `new_document.dart`.

**Byte identity of `startupPlan`.** I encoded it with `encodeToString` using a temporary
probe test, which I ran and then deleted. The probe was never committed; its source is
in the scratchpad as `p12t3-probe.dart.txt`.

| | Size | sha256 |
|---|---|---|
| Before the change | 176,573 bytes | `6addf747…9b65eb` |
| After the change | 176,573 bytes | `6addf747…9b65eb` |

`cmp` exits 0, so the bytes are equal. The registry sorts type ids when it encodes, so
registering the page earlier does not change the order.

## Tests (`test/new_document_test.dart`, 6 tests)

- **ND1** covers `newDocument`:
  - It has `entities.liveCount == 0`, `undoDepth == 0`, and `canUndo` and `canRedo` both
    false.
  - Its units are millimetres. A control check first shows that the default of
    `DraftDocument.empty` is not millimetres.
  - `linetypes[ReservedHandles.dashedLinetype] == kDashedLinetypeRecord`, and
    `byName('DASHED')` is at handle 6.
  - The page `==` the literal `PageComponent(originX: -7425, originY: -5250)`. The
    literal is written out in the test, not read from `defaultPage` (T-11, the M-12a-27
    target).
  - `sheetWorldRect` is `[-7425, -5250, 7425, 5250]`, which is what the literal means.
- **ND2** covers `prepareDocument` alone:
  - `PageComponent` and `WallParams` are both registered.
  - There is no page, no entity and no history.
  - The units are millimetres and DASHED is at handle 6.
- **ND3** covers the new document's round trip:
  - `encodeToString` succeeds, and `decodeString(…, registerComponents: registerAppComponents)`
    gives a page `==` the literal and `==` the original.
  - The root has no unknown payload.
  - The units and DASHED survive, and re-encoding gives the same bytes.
- **ND4** decodes the sample's bytes. Its setUp checks that the sample's page is not the
  default literal (so the fixture is not degenerate) and that the sample has 10 live walls.
  - **ND4a**, with `registerAppComponents`: the page `==` the sample's page, and
    `liveObjectsOf<WallParams>` `==` the sample's walls.
  - **ND4b**, with `PageComponent.register` alone: the page is present, there are no live
    walls, and the first wall's handle has an unknown payload.
  - **ND4c**, with `parametricCatalog.registerComponents` alone: the walls are live,
    `PageComponent` is not registered, the page is null, and the root has an unknown
    payload.
  - ND4b and ND4c are the helper's contract: each registration is necessary. They are
    controls, so no product mutant is aimed at them specifically. The decode-level
    M-12a-7 and M-12a-7b belong to Task 5.

## Mutants

Each mutant was made the same way:

1. `cp` the file to a scratchpad backup (`p12t3-new_document.dart.bak` or
   `p12t3-catalog.dart.bak`).
2. Mutate it with `sed`.
3. Run `CI=true flutter test test/new_document_test.dart`.
4. `cp` the backup back.
5. `diff` the file against the backup. Every `diff` exited 0.

| Mutant | Change | Red tests (failing line) |
|---|---|---|
| **M-12a-27** | `defaultPage` origin from the portrait size: `-widthMm·scale/2`, `-heightMm·scale/2` = (-5250, -7425) | ND1 at line 41 (page `==` literal); ND3 at line 73. Result: +4 -2 |
| MA | `newDocument` without `clearHistory()` | ND1 at line 28 (`undoDepth == 0`). Result: +5 -1 |
| MB | `prepareDocument` does not set units | ND1 at line 34, ND2 at line 59, ND3 at line 76. Result: +3 -3 |
| MC | `prepareDocument` without `ensureDashedLinetype` | ND1 at line 35, ND2 at line 60, ND3 at line 77. Result: +3 -3 |
| MD | `registerAppComponents` without `PageComponent.register` | All 6 fail. ND1 and ND3 throw at `newDocument` (lines 25 and 67), ND2 fails at line 54, and ND4's setUp throws at `startupPlan` (line 87). Result: +0 -6 |
| ME | `registerAppComponents` without the catalog | ND2 at line 55; ND4a at line 102 (live walls). Result: +4 -2 |

## Gates

Each gate was run with `CI=true` and `PATH=/root/flutter/bin:$PATH`.

| Package | Tests | Analyze | Format |
|---|---|---|---|
| Engine `packages/jet_cad_2d` | `dart test`: **+1106 -2**, exit 1. The 2 failures are the standing `generate_document_test` ones ("the default document is the one Plan 2 measured…" and "both text fractions default to zero…") | `dart analyze`: "No issues found!", exit 0 | `dart format`: 159 files, 0 changed, exit 0 |
| Render `packages/jet_cad_2d_flutter` | `flutter test`: **+974 ~1 -7**, exit 1. The 7 failures are the standing `text_ladder` rungs 1–5 and `text_lod_ladder` rungs 1–2 | `flutter analyze`: "No issues found!", exit 0 | `dart format`: 178 files, 0 changed, exit 0 |
| App `apps/floor_planner` | `flutter test`: **+520** (514 + 6), "All tests passed!", exit 0 | `flutter analyze`: "No issues found!", exit 0 | `dart format`: 106 files, 0 changed, exit 0 |

The engine and render counts are the same as the numbers in the brief.

The first app format check exited 1 on the new test file. I ran `dart format` on it and
checked the format again, and it exited 0. The test line numbers above are from the
formatted file. The format change did not move any of them.

## Deviations

- **`defaultPage()` instead of `kDefaultPage`.** `PageComponent`'s constructor validates
  its fields and is not `const`, so I used the plan's "or a function" option. I did not
  keep the `k` prefix, because it signals a constant. Nothing else in the plan or spec
  names `kDefaultPage`.
- **`prepareDocument` and `newDocument` take a `TextMeasurer`.** This follows the plan's
  signature. `startupPlan` still takes a `FlutterTextMeasurer` and passes it on.

## Outside scope (reported, not fixed)

- Line 28 of the header comment in `startup_plan.dart` still says the sample is "the
  fixture a human looks at every session". Since D4 the app launches on the empty
  document, so this is now slightly stale. The plan asked only for the first-line comment
  to be corrected, so I left this line alone.
