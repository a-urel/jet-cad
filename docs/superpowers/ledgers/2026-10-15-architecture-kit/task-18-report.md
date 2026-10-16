# Task 18 report: the room type, grips, properties and colour

Status: **DONE_WITH_CONCERNS**. Commit `c511304d feat(kit-architecture): the room type, its grips, fields and colour` (on HEAD 660d3ffe).

There is one concern, and it needs a ruling. In `room_panel_test`, the case "RN5 a refused edit" has a premise that cannot hold over the plan library. The case is committed with `skip: true` and its assertions unchanged. See "Concerns" below.

## Implementation summary

- **`lib/src/room/room.dart`** is today's `parametric/room.dart` (lines 1-470), ported. Only the brief's changes were made:
  - the import of the contract's `PlanSwatch` and `planSwatchNamed`, and of `../ids.dart`;
  - `componentTypeId = ArchitectureTypes.room`;
  - `PlanSwatch? get colorValue => planSwatchNamed(color)`;
  - a two-line port note.

  `diff` against the source shows only those lines.
- **`lib/src/room/room_grips.dart`** is today's `room_grips.dart` unchanged, plus a port note.
- **`lib/src/room/room_plan.dart`** is the brief's code, verbatim:
  - `roomPlanType` with the name `TextProperty` (trimmed, empty name throws `ArgumentError`, gated by `PlanGate.reshape`);
  - the area `TextDisplay` over `roomAreaText`;
  - the colour `ColourTarget`;
  - the grips `RoomGrips(aperture: kSnapAperturePixels / camera.scale)`;
  - `debugRoomAreaReads`, and a per-document `Expando` memo keyed by `(room, commands.stateId)`.

  The `'—'` is U+2014: `od` shows `342 200 224`.
- **Wiring:**
  - `kit.dart`: `roomPlanType` goes after `separatorPlanType` in `types`.
  - The barrel exports `RoomParams`.
  - `type_naming.dart`: the room is registered after the separator.
- **Kit test support:**
  - `catalog.dart`: the room's registration.
  - `room_fixture.dart`: `addRoom`, `addSampleRooms` and `renameRoom` copied unchanged. Task 16's header sentence about them is removed.
- **Integration support:** `test/support/room_plans.dart`.
  - The copied plan model and helpers are as the brief lists. `addRoom` was also added (see Deviations).
  - The new code is the brief's: `R`, `RoomPlan`, `roomPlan` (a `PlanBuild`), `rooms`, `nameOf`, `pumpAt`, `clickAt`, `dragWorld`, `undoKey`, `toggleF3`, `osnap`, `select`.
  - It re-exports the rig's `globalAt`, `kitCatalog`, `press`, `pumpEditor` and `status`, and the wall fixture's `driftOf`, `enc`, `kids`, `kindOf` and `payloadOf`.

### The FREEZE RULE

No new cache over live walls, separators or rooms was added:

- **`RoomGrips`** reads only the room's own leaves and the page at each call.
- **`roomAreaText`'s memo** caches the room's own TEXT child string per `(room, stateId)`. The uncached read does not depend on liveness at all, so a freeze cannot make the memo disagree with a fresh read. Freezing does not move `stateId`, and it does not change any entity.
- **The separator grips** in GR5 go through `roomInputsOf(services)`, which Task 16 already covered.

So no freeze test or mutation applies; none was invented.

### On the dispatch notes about decimal separators and words

The spec says the Area line is "as drawn" (C3.5, "area (`TextDisplay`, as drawn, '—' without a TEXT child)"). The label's separator is the page's: `pageKey` covers unit, scale and decimal separator, and `formatArea` takes `DecimalSeparator` from the page. It is not `KitWords.decimalSeparator`.

I added one step to RM-area that pins exactly this with a non-'.' language. It uses German words with `decimalSeparator: ','`:
- on a point page the line reads `12.16 m²`;
- after `PageComponent.decimalSeparator = comma` it reads `12,16 m²`.

Mutation M-RM-13 covers it (below).

Room naming and numbering (`text:architecture.room-name`, `numberedNameIndex`) belong to the Room tool, which is Task 19. No word id was invented here.

## TDD evidence

**RED.** The kit tests were run before the lib files existed: `flutter test test/room`.

```
test/support/catalog.dart:11:8: Error: Error when reading 'lib/src/room/room.dart': No such file or directory
test/support/room_fixture.dart:16:8: Error: Error when reading 'lib/src/room/room.dart': No such file or directory
test/support/catalog.dart:25:62: Error: Couldn't find constructor 'RoomType'.
```

`flutter test test/room/room_plan_test.dart`:

```
test/room/room_plan_test.dart:20:8: Error: Error when reading 'lib/src/room/room_plan.dart': No such file or directory
test/room/room_plan_test.dart:47:69: Error: Undefined name 'roomPlanType'.
```

**GREEN, kit.** `flutter test` gives `00:16 +255: All tests passed!`. The per-file room counts come from the JSON reporter:

| File | Cases | Count |
|---|---|---|
| `room_color_test` | the fixture case, RC1-RC7 | 8 |
| `room_cost_test` | RK1, RK2 | 2 |
| `room_diagnostics_test` | DG1-DG4 | 4 |
| `room_dissolve_test` | RG2, RD1-RD8 | 9 |
| `room_follow_test` | RG3, RS1-RS6, DF1, FZ1 | 9 |
| `room_grips_test` | GR1, GR5 ×2 (origin and corpusGroups), GR6 | 4 |
| `room_object_test` | RP1, RG1, RG4-RG7, RL3, RL4, RA2, RX1 | 10 |
| `room_plan_test` | RM-fields, RM-name, RM-area, RM-colour, RM-grips | 5 |
| `room_tie_test` | DE1, DE2, DE3 | 3 |
| `room_tint_test` | TN1 | 1 |
| `separator_tool_test` | ST1-ST6 | 6 |

RK2's sweep was printed, not asserted. These are the measured numbers; neither RK1 nor RK2 has a budget to loosen:

```
RK2 grid at origin: 97 walls (6 × 7), 22 rooms; move median 2.70 ms [2.70, 2.11, 3.07, 2.48, 2.81]; rooms rebuilt per move [6, 6, 6, 6, 6]
RK2 grid at origin: 312 walls (12 × 12), 73 rooms; move median 5.25 ms [4.62, 5.48, 6.19, 3.80, 5.25]; rooms rebuilt per move [4, 4, 4, 4, 4]
RK2 grid at origin: 612 walls (17 × 17), 146 rooms; move median 7.65 ms [8.00, 7.59, 7.65, 7.78, 7.62]; rooms rebuilt per move [6, 6, 6, 6, 6]
RK2 grid at corpus far origin, 23 deg: 97 walls (6 × 7), 22 rooms; move median 1.53 ms [2.06, 1.73, 1.53, 1.49, 1.46]; rooms rebuilt per move [6, 6, 6, 6, 6]
RK2 grid at corpus far origin, 23 deg: 312 walls (12 × 12), 73 rooms; move median 3.62 ms [4.35, 3.45, 3.93, 3.40, 3.62]; rooms rebuilt per move [4, 4, 4, 4, 4]
RK2 grid at corpus far origin, 23 deg: 612 walls (17 × 17), 146 rooms; move median 7.50 ms [7.32, 7.50, 7.81, 7.81, 7.28]; rooms rebuilt per move [6, 6, 6, 6, 6]
RK2 strips of long exterior walls at origin: 97 walls (8 × 10), 28 rooms; move median 2.49 ms [1.04, 1.00, 2.49, 3.07, 3.39]; rooms rebuilt per move [2, 2, 2, 2, 2]
RK2 strips of long exterior walls at origin: 301 walls (25 × 10), 86 rooms; move median 2.61 ms [3.46, 2.61, 2.53, 2.79, 2.55]; rooms rebuilt per move [2, 2, 2, 2, 2]
RK2 strips of long exterior walls at origin: 601 walls (50 × 10), 168 rooms; move median 6.50 ms [6.50, 6.79, 6.58, 6.03, 5.56]; rooms rebuilt per move [2, 2, 2, 2, 2]
RK2 strips of long exterior walls at corpus far origin, 23 deg: 97 walls (8 × 10), 28 rooms; move median 1.64 ms [2.22, 1.63, 1.64, 1.48, 1.77]; rooms rebuilt per move [2, 2, 2, 2, 2]
RK2 strips of long exterior walls at corpus far origin, 23 deg: 301 walls (25 × 10), 86 rooms; move median 3.64 ms [3.71, 3.58, 4.27, 3.38, 3.64]; rooms rebuilt per move [2, 2, 2, 2, 2]
RK2 strips of long exterior walls at corpus far origin, 23 deg: 601 walls (50 × 10), 168 rooms; move median 6.93 ms [8.11, 6.93, 8.05, 6.59, 6.88]; rooms rebuilt per move [2, 2, 2, 2, 2]
```

**GREEN, integration.** `flutter test --enable-vmservice test/room` gives `00:04 +17 ~1: All tests passed!`:
- grips: 9 (GR1 shell ×2, GR2 ×2, GR3, GR4 ×2, GR5 shell ×2);
- panel: 7, plus 1 skipped;
- colour: RC8.

**Non-ASCII checks.** Counts of `m²`, `ft²`, `—`, `×`, `°`, `−` and `≈` were compared with `grep -o | wc -l` against each source's copied line ranges. They are equal for every whole-file port and every partial range. The only differences are fully explained:
- **Integration panel:** today's `roomsPlan` doc comment was not copied (2 `m²`, 3 `×`).
- **Integration `gripPlan`:** it carries today's two premise `expect`s (+2 `m²`).
- **ST4:** its non-ASCII lines match the source's lines 359-377.

## Gates

**Kit** (`packages/jet_cad_2d_kit_architecture`):

| Check | Result |
|---|---|
| `flutter test` | `00:16 +255: All tests passed!` |
| `flutter analyze` | `No issues found!` |
| `dart format --output=none --set-exit-if-changed .` | exit 0 |
| `dart pub publish --dry-run` (after the commit) | `Package has 0 warnings.` |

**Integration** (`packages/jet_cad_2d_integration`):

| Check | Result |
|---|---|
| `flutter test --enable-vmservice` | `00:12 +71 ~1: All tests passed!` (the `~1` is the skipped RN5 case) |
| `flutter analyze` | `No issues found!` |
| `dart format --output=none --set-exit-if-changed .` | exit 0 |

**Repository root:**
- `dart run tool/ci/check_kit_deps.dart` printed `kit dependencies: 2 package(s) checked, none names the plan library or another kit`, exit 0.
- `git status --short` is clean after the commit and after the mutations. No `analysis_options.yaml` was touched.

## Mutations

Each was run on the committed files, reverted with `git checkout -- <file>`, and then `git diff --quiet` exited 0.

| Mutation | Test | Red line |
|---|---|---|
| M-RM-1 `v.trim()` → `v` | RM-name | `Expected: 'Snug  room'` / `Actual: '  Snug  room \t'` |
| M-RM-2 empty-name `throw` removed | RM-name | `Expected: throws <Instance of 'ArgumentError'>` / `Actual: ... returned <Instance of 'SetComponentCommand<RoomParams>'>` |
| M-RM-3 `'—'` → `''` | RM-area | `Expected: '—'` / `Actual: ''` |
| M-RM-4 memo key without `state` | RM-area | `Expected: '130.91 ft²'` / `Actual: '12.16 m²'` |
| M-RM-5 memo write removed | RM-area | `Expected: <1>` / `Actual: <2>` |
| M-RM-6 `labels[1]` → `labels[0]` | RM-area, integration RN6 | `Expected: '12.16 m²'` / `Actual: 'Room 2'` (both) |
| M-RM-7 colour write keeps `p` | RM-colour | `Null check operator used on a null value` at `room_plan_test.dart 152:65` (`recolour` returns null) |
| M-RM-8 aperture without `/ scale` | RM-grips; kit GR6; integration GR2 (both placements) | RM-grips: `Expected: null` / `Actual: <Instance of 'SetComponentCommand<RoomParams>'>`. GR6: `Expected: empty` / `Actual: [(EntityKind.line, ...)]`. GR2: `Expected: null` / `Actual: (double, double):<(26.666..., -20.000...)>` |
| M-RM-9 `movable` → `true` | RM-grips; integration GR4 (both placements) | `Expected: false` / `Actual: <true>` |
| M-RM-10 `colorValue => null` | RC2, RC5 | RC2: `Expected: TrueColor:<TrueColor(0x00897b)>` / `Actual: IndexedColor:<IndexedColor(7)>`. RC5: `Expected: PlanSwatch:<PlanSwatch.red>` / `Actual: <null>` |
| M-RM-11 id `'architecture.rooms'` | RP1 | `Expected: 'architecture.room'` / `Actual: 'architecture.rooms'` |
| M-RM-12 `roomPlanType` removed from `types` | RM-fields; integration `test/room` | RM-fields: `Expected: contains PlanType<RoomParams>:<PlanType(architecture.room)>`. Integration: `00:01 +0 ~1 -17: Some tests failed.` (every case red) |
| M-RM-13 (added) area text reformatted through `object.words.decimalSeparator` | RM-area | `Expected: '12.16 m²'` / `Actual: '12,16 m²'` |

## Ported-test accounting (old case → new case, change class)

**Kit cases:**
- **`room_object_test`** (10 of 10): RP1, RG1, RG4-RG7, RL3, RL4, RA2, RX1.
  - Imports.
  - `RoomInputs(x)` → `RoomInputs(x, liveOf(x))` (fixture).
  - RP1's two `'floor_planner.room'` → `'architecture.room'` (class 1).
  - `kDashedLinetypeRecord` is imported from `separator_linetype.dart`, its kit home (an import path only).
- **`room_tint_test`** TN1: imports and `RoomInputs` ×3.
- **`room_diagnostics_test`** DG1-DG4: imports and `RoomInputs` ×1.
- **`room_dissolve_test`** RG2, RD1-RD8: imports and `RoomInputs` ×1.
- **`room_follow_test`** RG3, RS1-RS6, DF1, FZ1:
  - imports (catalog dropped; wall grips → `testing.dart` + `wall_plan.dart`; `separator_linetype.dart` added);
  - `dragEnd` → `wallPlanType.gripsFor(FakePlanServices)` (fixture, the brief's code);
  - `RoomInputs` ×3.
- **`room_tie_test`** DE2, DE3: appended verbatim with the `room_label.dart` import. The file now has DE1-DE3.
- **`room_cost_test`** RK1, RK2: helpers and cases verbatim; LZ3 not copied (R-P10).
- **`room_color_test`** (fixture case, RC1-RC7):
  - imports;
  - `FloorPlanColor`/`floorPlanColorNamed` → `PlanSwatch`/`planSwatchNamed` (the contract's names);
  - RC6 `['floor_planner.room']` → `['architecture.room']` (class 1).
- **`room_grips_test`** GR1, GR5 ×2, GR6:
  - `ObjectGrips(labelAperture)` → `roomGripsAt(doc, ap)` (fixture);
  - GR5's dispatcher → `separatorGripsWith` per F3, with `objectsNow()` and both services' `invalidate()` (fixture, the brief's code);
  - `gripPlan`'s `shell` parameter dropped.
- **`separator_tool_test`** ST4: verbatim, with `rooms` = `testCatalog().objectsOf<RoomParams>` and `Traced` in the `show`. It is inserted between ST3 and ST5 (today's order). The file now has ST1-ST6.

**Integration cases:**
- **`room_grips_test`**: GR1 (shell) ×2, GR2 ×2, GR3, GR4 ×2, GR5 (shell) ×2.
  - `view` → controller: selection, camera, grips are class 3 plus R-P9.
  - `pumpShell` → `pumpAt`; `tapWorld` → `clickAt` (fixtures).
  - GR4's last face is read from the drawn tint's shoelace area (the brief's code, R-P1). The value asserted is unchanged.
- **`room_panel_test`**: the fixture case, RN1, RN2, RN3, RN4, RN5, RN6 pass. RN5 (refused edit) is skipped (see Concerns).
  - Finders → `section-architecture.room`, `property-name`, `property-area`, `section-architecture.wall` (class 3).
  - RN3's letter set is rebuilt from what the plan binds plus today's 16-letter guard list, copied (the brief's code). `palette.fill` → `c.fill` (R-P9).
  - RN5 (refused edit): the load goes through `save()` and `architectureController(json:)` (the brief's code).
- **`room_color_test`** RC8:
  - the export is `PlanController.export('plan.png', PlanExportChoice(dpi: d96))` (the brief's code);
  - `attachPage` → `SetComponentCommand<PageComponent>`.

## Files changed

**Kit** (`packages/jet_cad_2d_kit_architecture/`):
- `lib/jet_cad_2d_kit_architecture.dart`
- `lib/src/kit.dart`
- `lib/src/type_naming.dart`
- `lib/src/room/room.dart`
- `lib/src/room/room_grips.dart`
- `lib/src/room/room_plan.dart`
- `test/support/catalog.dart`
- `test/support/room_fixture.dart`
- `test/room/room_plan_test.dart`
- `test/room/room_object_test.dart`
- `test/room/room_grips_test.dart`
- `test/room/room_color_test.dart`
- `test/room/room_tint_test.dart`
- `test/room/room_diagnostics_test.dart`
- `test/room/room_dissolve_test.dart`
- `test/room/room_follow_test.dart`
- `test/room/room_tie_test.dart`
- `test/room/room_cost_test.dart`
- `test/separator/separator_tool_test.dart`

**Integration** (`packages/jet_cad_2d_integration/`):
- `test/support/room_plans.dart`
- `test/room/room_grips_test.dart`
- `test/room/room_panel_test.dart`
- `test/room/room_color_test.dart`

## Deviations

1. **`room_cost_test` copy range.** The brief says to copy source lines 18-73. `addRooms` actually runs to line 79, so 18-73 would cut it mid-body. I copied 18-79.
2. **LZ3's header line.** The brief's Step 3 text says "(Task 25)". Its own placement table and ruling R-P10 say LZ3 is Task 26's, so the header reads "(Task 26, ruling R-P10)".
3. **Two kit-test imports the brief's list got wrong** (analyzer errors, fixed without touching any assertion):
   - `room_grips_test`: `Grip` and `GripRole` are the engine's (`jet_cad_2d`), not `jet_cad_2d_flutter`'s. The `show` is `ObjectGripProvider, SelectionKey`.
   - `room_object_test`: `kDashedLinetypeRecord` lives in the kit's `separator_linetype.dart`; today it was in `separator.dart`. That import was added.
4. **Port-note lines wrapped.** The two port notes in `room.dart` and `room_grips.dart` are wrapped to two lines (80 columns). The words are the brief's.
5. **`room_plans.dart` gains `addRoom`**, today's helper (`room_fixture.dart:561-579`) copied unchanged. RN6 adds a room ('Store') mid-test, and the brief's list of support names omits the helper it needs.
6. **Integration grips test: `k`** (today's `:37`) is copied too. Its cases use it, and the brief's copy list omits it.
7. **RM-area gains one step:** the decimal separator is the page's, with German words carrying `','`. Mutation M-RM-13 covers it. This is an addition; no brief assertion changed.
8. **Local copies dropped in the integration panel test.** Its local `status`, `press`, `select` and `nameOf` copies are dropped because the rig and `room_plans.dart` provide them (R-P14). The only behaviour difference is that the rig's `press` returns `bool`, which RN2 ignores.
9. **No unused imports.** The integration files import only what they use (`unused_import`/`unnecessary_import`). `room_grips_test` and `room_color_test` therefore do not import `jet_cad_2d_integration.dart`.

## Concerns

### 1. `room_panel_test` "RN5 a refused edit": the premise cannot hold over the plan library

The case needs a ruling. It is committed with `skip: true`; its assertions are today's, unchanged, with a comment pointing here.

**What happens.** The file is loaded as the brief says: `save()`, edit A's fill to name B's boundary, then `architectureController(json:)`. The plan library then **freezes room A at open**: A's regeneration fails, and the plan's boundary freezes the failing object (C1.10, Task 7/11).

**Evidence.** I ran a probe test, which was deleted afterwards and never committed:

```
PROBE frozen at open: true false
PROBE raw rename threw: PlanLocked; doc unchanged: true; frozen A: true
PROBE A selected: section 0, name field 0
```

**Consequences:**
- The premise `expect(() => doc.commands.execute(SetComponentCommand<RoomParams>(src.a, ...)), throwsStateError)` fails with:
  ```
  Expected: throws <Instance of 'StateError'>
  Actual: <Closure: () => void>
  Which: threw PlanLocked:<PlanLocked: the edit would change a locked object>
  ```
- With the premise's matcher relaxed (a local, uncommitted probe), the next step fails: `The finder "Found 0 widgets with key [<'property-name'>]" (used in a call to "tap()")`. A frozen room shows no Room section, so "reverts and re-pins" cannot be exercised.

**Options for the controller or the human:**
- **(a)** Rule it "not ported, premise impossible": the plan freezes a room whose regeneration the engine refuses at open, so no panel edit reaches it. Delete the case. The refusal is already covered for frozen objects by the plan's `frozen_write_test` and `guarded_tool_test`.
- **(b)** Rewrite the case to today's intent under the plan's model, which needs a ruling for the changed assertions:
  - the premise becomes `throwsA(isA<PlanLocked>())` (`PlanLocked` is public);
  - "A shows no Room section" replaces "reverts and re-pins";
  - "B is sound: its rename lands" is kept.

No other ported assertion needed a change.

---

## Fix report: the coordinator's ruling on RN5

Commit: `3746c3ed test(kit-architecture): RN5 as RN5-open and RN5-refused`, on top of c511304d.

The ruling: no skipped test in the tree. The old case is split in two, and its premise is recorded as impossible ("Decided: the old premise (an engine StateError reaching a live room) cannot exist under C1.10's freeze at open").

`skip: true` is gone. The old "RN5 a refused edit" case is replaced by two cases in `packages/jet_cad_2d_integration/test/room/room_panel_test.dart`, under one header comment that cites the ruling.

### RN5-open

The brief's premise setup is kept: save, edit A's fill to name B's boundary, then reopen with `architectureController(json:)`. The case then asserts:
- `c.frozen` contains A and does not contain B;
- a raw rename of A throws `throwsA(isA<PlanLocked>())`;
- `canon` is unchanged and the undo depth is 0;
- selecting A raises no exception, and `section-architecture.room` finds nothing.

The old "B is sound" block is kept word for word: `Hall`, `['Hall', '12.16 m²']`, undo depth 1.

### RN5-refused

This runs on a live room A:
- Enter with `''` gives `takeException()` null; the field reverts to `'Kitchen'`; `canon` is unchanged.
- Re-pinned: typing `' \t '` and then a focus loss is refused alike: the field shows `'Kitchen'`, `canon` is unchanged, and the undo depth is 0.
- The field is still A's and editable: `readOnly` is false, and `'Study'` lands on A (`['Study', '10.83 m²']`), with B untouched and undo depth 1.

### Support change

`room_plans.dart` now re-exports `canon` from `wall_fixture.dart`.

### Gates

| Check | Result |
|---|---|
| Integration `flutter test --enable-vmservice` | `00:13 +73: All tests passed!` (no skip) |
| Integration `flutter analyze` | `No issues found!` |
| Integration format | exit 0 |
| Kit `flutter test` | `00:15 +255: All tests passed!` |
| Kit `flutter analyze` | `No issues found!` |
| Kit format | exit 0 |
| Kit `dart pub publish --dry-run` | `Package has 0 warnings.` |
| `dart run tool/ci/check_kit_deps.dart` | `kit dependencies: 2 package(s) checked, none names the plan library or another kit`, exit 0 |

### Mutation

**M-RM-2 against RN5-refused.** In `lib/src/room/room_plan.dart`, the empty-name `throw` block was deleted. The kit-side mutation is the one named because the panel's revert lives in the plan library: the panel passes the trimmed `''` to the type's `write`, and only the kit refuses it. The test went red:

```
Expected: 'Kitchen'
  Actual: ''
00:01 +0 -1: RN5-refused a name the room type refuses reverts and re-pins; no exception escapes Enter or the focus loss (M-RM-2) [E]
```

It was reverted with `git checkout --`, and `git diff --quiet` exited 0. The tree is clean.

### Ported-test accounting (amended)

- `room_panel_test` "RN5 a refused edit": **premise impossible (Decided) → RN5-open + RN5-refused**.
- The panel file now has the fixture case, RN1, RN2, RN3, RN4, RN5, RN5-open, RN5-refused and RN6. All pass.

The concern in the original report is resolved by this ruling.
