# Task 15 report: the opening tools (spec 3a C3.3, C1.5, C1.11, C6, C7)

## Final status: DONE. Commit f3f25f3f, after the controller's ruling (see "Resumed after the ruling" at the end)

The sections below "Resumed" are the first pass, which stopped on OS3. They are kept as written.

## First pass: BLOCKED. The brief's stop condition was hit (OS3, `expect(position, findsNothing)`)

All the code and tests are written. Every case passes except one assertion in OS3.
The brief calls this exact failure "a finding (stop and report it), not a test to
change". **Nothing is committed** and the mutation step has not run. The
work is uncommitted in the worktree (HEAD 645bef75):

```
 M packages/jet_cad_2d_integration/test/opening/opening_kink_test.dart
 M packages/jet_cad_2d_integration/test/opening/opening_panel_test.dart
 M packages/jet_cad_2d_integration/test/support/opening_support.dart
 M packages/jet_cad_2d_kit_architecture/lib/src/kit.dart
 M packages/jet_cad_2d_kit_architecture/lib/src/opening/opening_plan.dart
?? packages/jet_cad_2d_integration/test/opening/opening_tool_test.dart
?? packages/jet_cad_2d_kit_architecture/lib/src/opening/opening_tool.dart
?? packages/jet_cad_2d_kit_architecture/test/opening/opening_tool_test.dart
```

No `analysis_options.yaml` was rewritten, so `git status` shows none.

## The finding (OS3)

OS3 runs with the Door tool active and an opening (the window) selected. Today the
Selection panel showed **only** the tool's settings (`selection_panel.dart:1060-1066`).
The plan library's panel shows the tool's settings section **and** the selected
object's section. See `packages/jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart:1053-1054`:

```dart
      if (tool != null) _settingsSection(tool, title),
      if (object != null) _objectSection(object, title),
```

So `property-position` (the window's object field) is present in tool mode.
The failure, from `flutter test --enable-vmservice test/opening/opening_panel_test.dart --plain-name "OS3"`:

```
Expected: no matching candidates
  Actual: _KeyWidgetFinder:<Found 1 widget with key [<'property-position'>]: [
            TextField-[<'property-position'>](controller:
TextEditingController#e14a0(TextEditingValue(text: ┤4100├, ...
   Which: means one was found but none were expected
...
  file:///.../jet_cad_2d_integration/test/opening/opening_panel_test.dart line 334
```

Line 334 is the ported `expect(position, findsNothing);`, right after
`await select(tester, c, [p.window]);`. The earlier
`expect(position, findsNothing, reason: 'no position in tool mode')`, with nothing
selected, passes.

**Diagnostic, not kept:** I ran a throw-away copy of the file with only line 334
deleted (`sed '334d'`, run, then deleted). OS3 then passes in full: the
keystroke-by-keystroke settings, the click with no Enter placing a 720 door, N's and
G's own settings, and the return to Select. So this one assertion is the only conflict.

**Collateral failures:** in the full run, OS4 and OT-panel-range then fail with framework
exceptions ("building _FocusInheritedScope", "routing a pointer event"). Each passes
when run on its own (`--plain-name "OS4"`: `+1: All tests passed!`;
`--plain-name "OT-panel-range"`: `+1: All tests passed!`). They fail only because of OS3's
mid-test failure.

**Options for the controller (not mine to choose):**
- (a) Change the plan library so the panel hides the object section while a tool's settings show, as today does. This is a plan-library change outside this task's files.
- (b) Rule that the plan's two-section panel is the 3a behaviour. OS3's line 334 then changes, which is an assertion change and needs a ruling.

## Implementation summary

- `lib/src/opening/opening_tool.dart` (new) is ported per Step 5:
  - `OpeningSettings` is unchanged except its doc comment; `openingToolIdOf` is new.
  - It is `OpeningTool(kind, services)`. `_width` reads `services.settingsOf<OpeningSettings>(openingToolIdOf(kind)).width` at every use.
  - `_bands = wallBandsOf(services)`, `_live = liveTypesOf(services)`. `wallsInDocument(doc, host, _live)` and `openingsInDocument(doc, host, _live)`.
  - `dispose` no longer disposes the bands. `paintRubberBand` and `isUsableHost` are unchanged.
- `lib/src/opening/opening_plan.dart` gains `_openingPlanTool`, `doorPlanTool` (D), `windowPlanTool` (N) and `gapPlanTool` (G) as in Step 6, plus the header sentence and the two imports.
- `lib/src/kit.dart`: `tools: [boxPlanTool, wallPlanTool, doorPlanTool, windowPlanTool, gapPlanTool]`.
- Integration support `opening_support.dart` gains `placementOf`, `settingsText`, `toolSection`, `settingWidth`, `openings`, `added` and `addWallFromSeed` (Step 3.1, verbatim). Nothing in the rig is duplicated.

### The frozen-wall check the dispatch asked for (deviation D1: a fix beyond the brief)

**Finding.** The tool keeps two caches of its own, and both are keyed on `WallBands.generation`:
- the host-scan memo (`_scanHost`, Ruling 08-12);
- the frame cache (`_layout`, `_others`, `_otherCuts`, Ruling 08-13).

The memo-hit path of `_hostAt` compared `_bands.generation` **without going through
the bands' `_refresh`**. Task 12 said that anything reading the bands must go through it.

The consequence: suppose a wall is frozen with no document change, and the next hover
comes at the identical raw point. The memo returned the frozen wall as host, and the
cached frame built a preview on it. Or, when the frozen wall was an obstacle of the
hovered host, the cached frame still clamped against it.

A click was always safe, because `onPointerDown` calls `_bands.invalidate()`. A hover at a
different raw point was also safe, because `hostAt` refreshes and the generation moves
before `_frameFor`.

**Test first (RED).** The new kit case is "OL-frozen (memo) (spec 3a C1.5)". Against the
port as written in the brief:

```
00:00 +0 -1: OL-frozen (memo) ...
  Expected: empty
    Actual: [
  frozen since the last hover at this point: no host
```

**Fix.**
- On a memo hit, `_hostAt` calls `_bands.liveWalls(doc)`. That is the public entry to `_refresh`, and it returns a view: no allocation. A cached wall that is no longer live then moves the generation, so both the memo and the frame cache miss.
- The refresh runs at most once per pointer event, through a `_bandsFresh` flag:
  - it is cleared in `onPointerMove` and `onPointerDown`, and after the event's last read in `hovered` and `accept`;
  - it is set by both of `_hostAt`'s paths.
- Without the flag the memo-hit refresh doubled the per-move cost:

```
OT4 n=600: median per hover over no wall 78.98 us (whole pointer move), host scan alone 39.20 us; over a wall, with the preview, 85.94 us
```

  With the flag it is back to the port's level:

```
OT4 n=600: median per hover over no wall 43.68 us (whole pointer move), host scan alone 41.64 us; over a wall, with the preview, 50.52 us
```

  The port before the fix measured:

```
OT4 n=600: median per hover over no wall 42.90 us (whole pointer move), host scan alone 41.38 us; over a wall, with the preview, 49.30 us
```

**How the test works.** The test uses two rigs, each over its own services with a
mutable `frozen` set. `FakePlanServices` keeps the set it is given, as the plan's
`FailureBoundary._freeze` does `frozen.addAll`.
- Rig 1 hovers X, freezes X, and hovers the same point: there must be no preview.
- Rig 2 hovers A where X crosses it (X clamps the door), freezes X, and hovers the same point. The preview must equal one from a rig with X frozen from the start, compared deep as `[kind, ...numbers]`.

A first version unfroze X between the two halves. That is not the bands' contract
(un-freezing comes with a document change), so it was split into two rigs.

**Proposed mutation (not run, nothing committed):** M-OL-9, in `_hostAt`, delete the
`if (!_bandsFresh) { _bands.liveWalls(doc); _bandsFresh = true; }` block. OL-frozen
(memo) should go red at `'frozen since the last hover at this point: no host'`, which is
the RED above.

## TDD evidence

RED, kit: `flutter test test/opening/opening_tool_test.dart`, before any lib file:

```
test/opening/opening_tool_test.dart:24:8: Error: Error when reading 'lib/src/opening/opening_tool.dart': No such file or directory
test/opening/opening_tool_test.dart:54:3: Error: Type 'OpeningTool' not found.
test/opening/opening_tool_test.dart:67:5: Error: Method not found: 'openingToolIdOf'.
...
test/opening/opening_tool_test.dart:982:20: Error: Undefined name 'doorPlanTool'.
```

RED, integration: `flutter test --enable-vmservice test/opening/`.
- OT1 (shell):
  ```
  The finder "Found 0 widgets with key [<'tool-architecture.door'>]: []" (used in a call to "tap()")
  could not find any matching widgets.
  ```
- KJ3:
  ```
  Expected: <1>
    Actual: <0>
  ```
- OS3:
  ```
  Expected: 'Door'
    Actual: 'Select'
  ```
- **Deviation D2 (brief's expectation not met):** OS1 (runtime) and OT1 (rv9-guardDNG) were **green** before the implementation. They assert that D, N and G typed into a field do **not** switch tools. With no D/N/G tool in the kit there is nothing to switch to, so they are regression guards that pass on both sides. No assertion was changed.

GREEN, kit: `flutter test test/opening/opening_tool_test.dart` gives `00:02 +21: All tests passed!`:
- 16 ported cases;
- OT1 (preview);
- OL-tools, OL-settings and OL-frozen;
- OL-frozen (memo).

HF7 prints `HF7: 314 walls (209 cut), 525 openings, 384 fitting, 768 gap edges (182 beyond a dropped piece), 0 mismatches`.

Integration: every new and ported case passes except OS3 (above). The OT1 (shell), OT1 (rv9-guardDNG), KJ3 and OS1 (runtime) runs were green.

## Gates (run, with the work uncommitted)

- Kit:
  - `flutter test`: `00:09 +164: All tests passed!`
  - `flutter analyze`: `No issues found!`
  - `dart format --output=none --set-exit-if-changed .`: exit 0
  - `dart pub publish --dry-run`: `Package has 1 warning.` The warning is `2 checked-in files are modified in git`, which comes from the uncommitted work.
- Integration:
  - `flutter analyze`: `No issues found!`
  - format: exit 0
  - `flutter test --enable-vmservice`: `00:08 +42 -3: Some tests failed.` The three are OS3 (the finding) and its collateral OS4 and OT-panel-range.
- Repo root: `dart run tool/ci/check_kit_deps.dart` gives `kit dependencies: 2 package(s) checked, none names the plan library or another kit` (exit 0).

## Mutations

None were run: the brief says to mutate committed files only, and nothing is committed.
M-OL-1 to M-OL-8 and the proposed M-OL-9 wait for the ruling.

## Ported-test accounting

Change classes: A12 means fixture, imports or harness; A13-live is Task 13's live-reader argument; R15-x are this task's rulings.

| Old (jet_cad_floor_plan/test/…) | New | Change class |
|---|---|---|
| opening_tool_test OT1 (stored centre) `:346` | kit opening_tool_test | rig over FakePlanServices (R15-1) |
| OT1 (ffw-noFitRaw) `:407` | kit | R15-1 |
| OT2 `:442` | kit | R15-1 |
| OT2 (rv9-hingeRaw) `:489` | kit | R15-1 |
| OT2 (rv9-swingResolved) `:518` | kit | R15-1 |
| OT1 (rv9-selfFirst) `:545` | kit | R15-1; `settings.value =` → `setWidth` |
| OT1 (liveness) `:590` | kit | R15-1 (strays null via `liveTypeIdOf` over `testCatalog`) |
| OT3 (pure) `:668` | kit | none |
| OT3 (X10-gate) `:700` | kit | `setWidth` ×2; A13-live at `layoutInDocument` |
| OT3 (rv10-storedCuts) `:795` | kit | `setWidth` |
| OT3 (t11-apertureDir) `:851` | kit | `setWidth` |
| OT5 `:892` | kit | R15-1 |
| OT4 (X9-cache) `:933` | kit | R15-1 |
| OT4 (t10-scanMemo) `:1031` | kit | R15-1 |
| OT4 (cost) `:1054` | kit | R15-1 (prints) |
| HF7 `:1111` | kit | A13-live at `layoutInDocument`, `openingsInDocument` |
| OT1 (shell), preview line `:263-264` | kit "OT1 (preview)" | R15-2 (moved) |
| OT1 (shell) `:206` | integration opening_tool_test | C6 harness; keys R15-4; settings by typing (R15-3); `place(toolId, word, raw)`; preview line moved (R15-2) |
| OT1 (rv9-guardDNG) `:633` | integration opening_tool_test | C6 harness; `clickAt` → `tapWorld` |
| opening_kink_test KJ3 `:288` | integration opening_kink_test (before KJ4) | C6 harness; `hostFrameInDocument(..)!.uE` → `OpeningOracle(c.document).span(hA).$2` (R14-9) |
| opening_panel_test OS1 (runtime) `:299` | integration opening_panel_test (after OS1) | Task 14's 5.2 harness |
| opening_panel_test OS3 `:404` | integration opening_panel_test (after OS2) | 5.2 harness; `settingsText` vs `'OpeningSettings($want)'` (R15-3); `toolSection`, `settingWidth` (R15-4); today's `:425` `expect(position, findsNothing)` (with the window selected): **assertion changed by binding spec (2a P-panel)**. It is now: the settings width row is present, `property-position` is present, and its top `dy` is greater than the width row's bottom `dy` |

New cases: OL-tools, OL-settings and OL-frozen (from the brief), and OL-frozen (memo) (D1).

The ported kit sections were cut from the source with `sed` (byte-exact). The diff
against the source shows only the listed lines. The integration ports were diffed
against their source cases, and only the listed changes appear. The non-ASCII
literals (`×`, `°`, `≈`, `−`, `√`, `·`) come from the source bytes.

## Deviations

- **D1:** the frozen-cache fix in `_hostAt` plus the `_bandsFresh` flag, and the new OL-frozen (memo) case, as above.
- **D2:** OS1 (runtime) and rv9-guardDNG were not red before the implementation, as above.
- **D3:** imports and file headers.
  - The kit test imports are in `directives_ordering` order: `vector_math` last among the packages. `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` is not imported because it is unused.
  - The integration `opening_tool_test.dart` keeps a short header after the two required first lines.
  - `opening_kink_test.dart`'s header now names KJ3 as ported here.

## Concerns

1. OS3 needs a ruling: (a) a plan-library change, or (b) accept the two-section panel and change line 334's assertion. See the finding above.
2. When a test fails partway, OS4 and OT-panel-range in the same file fail with framework exceptions. They are not independent failures, but the harness lets one test's failure leak into the next.

## Resumed after the ruling (controller: option (b))

**The OS3 change.** The binding spec is the 2a design-mode spec's `PlanPropertyPanel`
row (`docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md:345`): "The
active tool's settings ... Below them, the one selected object's section". At the old
line 334, `expect(position, findsNothing)` became:
- `expect(settingWidth, findsOneWidget)`;
- `expect(position, findsOneWidget)`;
- `expect(tester.getTopLeft(position).dy, greaterThan(tester.getBottomLeft(settingWidth).dy), reason: 'the selected object\'s section is below the tool\'s settings')`.

A comment there cites the spec row and the ruling. Every other OS3 assertion is
untouched. In the accounting this is "assertion changed by binding spec (2a P-panel)".

**Commit:** `f3f25f3f feat(architecture): the Door, Window and Gap tools (spec 3a C3.3)`.
- It contains the brief's 8 paths, staged by explicit path.
- The message is the brief's, plus one sentence on the per-event re-check of the bands (D1), and ends with the trailer.

**Gates (after the commit):**
- Kit:
  - `flutter test`: `00:09 +164: All tests passed!`
  - `flutter analyze`: `No issues found!`
  - format: exit 0
  - `dart pub publish --dry-run`: `Package has 0 warnings.`
- Integration:
  - `flutter test --enable-vmservice`: `00:07 +45: All tests passed!` OS4 and OT-panel-range pass now.
  - `flutter analyze`: `No issues found!`
  - format: exit 0
- `dart run tool/ci/check_kit_deps.dart`: `kit dependencies: 2 package(s) checked, none names the plan library or another kit`
- `git status --short`: empty.

### Mutations

All were on committed files. Each was reverted with `git checkout -- <file>`, and
`git diff --quiet -- <file>` exited 0 every time (`clean 0`).

- **M-OL-1:** `opening_plan.dart`, the door's letter `'D'` → `'X'`.
  - Kit: `OL-tools ... [E]` (`Expected: [` / `Actual: [`).
  - Integration: OT1 (shell) and OS3 are red too.
- **M-OL-2:** `defaultFor`, `kind == OpeningKind.window ? 1200 : 900` → `900`.
  - Kit, OL-tools: `Expected: [900, 1200, 900]` / `Actual: [900.0, 900.0, 900.0]`.
  - Integration, OS3: `Expected: 'OpeningSettings(1200.0)'` / `Actual: 'OpeningSettings(900.0)'`.
- **M-OL-3:** the width spec, `openingWidthOf(kind, w)` → `openingWidthOf(OpeningKind.door, w)`.
  - Kit, OL-tools: `Expected: throws <Instance of 'ArgumentError'>` / `Actual: <Closure: () => Object?>`.
  - Integration, OS3: `Expected: 'OpeningSettings(900.0)'` / `Actual: 'OpeningSettings(0.000003)'` (`gap "0.000003"`).
- **M-OL-4:** the width read once (`late final double _first`; `_width => _first`).
  - OL-settings: `Expected: [900, 750]` / `Actual: [900.0, 900.0]`.
  - OT3 (X10-gate) is red too: `Expected: a numeric value within <1e-11> of <2134.4067584377062>` / `Actual: <2135.40675843698>`.
- **M-OL-5:** in `_frameFor`, other walls are taken as live (`(h) => h == host ? _live(h) : ArchitectureTypes.wall`).
  - OL-frozen: `Expected: a numeric value within <0.000001> of <1875>` / `Actual: <1349.740033882957>`.
  - OL-frozen (memo) is red too: `Expected: not [`.
- **M-OL-6 (pair):** `wall_bands.dart`'s rebuild over every `WallParams` holder, and `_frameFor`'s `(h) => ArchitectureTypes.wall`.
  - OL-frozen: `Expected: empty` / `Actual: [26]` / `a frozen wall hosts nothing`.
  - OT1 (liveness) is red too: `Expected: an object with length of <1>` / `Actual: []`.
  - OL-frozen (memo) is red too.
  - Both files were reverted, and `git diff --quiet` exited 0 on each.
- **M-OL-7:** `doorPlanTool` removed from `architectureKit.tools`.
  - Kit: `OL-tools ... [E]`.
  - Integration: OT1 (shell) is red (`could not find any matching widgets.`), and so is OS3.
- **M-OL-8:** the swing swapped in `_place`.
  - OT2: `Expected: (HingeEnd, SwingSide):<(HingeEnd.start, SwingSide.left)>` / `Actual: (HingeEnd, SwingSide):<(HingeEnd.start, SwingSide.right)>`.
  - OT2 (rv9-hingeRaw) and OT2 (rv9-swingResolved) are red too.
- **M-OL-9:** the memo-hit refresh block deleted from `_hostAt`.
  - OL-frozen (memo): `Expected: empty` / `Actual: [` / `frozen since the last hover at this point: no host`.
- **M-OL-9b (extra):** every `_bandsFresh = false;` disabled, so the flag is never cleared after the first event.
  - OL-frozen (memo): red at `frozen since the last hover at this point: no host`.
- **M-OS3 (extra, `jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart`):** the object section put before the tool's settings.
  - OS3's new assertion: `Expected: a value greater than <276.0>` / `Actual: <132.0>` / `the selected object's section is below the tool's settings`.

### OS1 (runtime) and OT1 (rv9-guardDNG): do they bite now?

**Not through a kit mutation.**
- M-OL-1 (the door's letter → `X`): both stay green. A letter that is not D cannot switch tools from a field either.
- M-OL-7 (no door tool): both stay green.

They assert an absence: no tool switch from a field.

**They do bite through the plan library's guard, now that the kit's letters exist.**
In `jet_cad_2d_plan/lib/src/shortcuts/plan_shortcut_guard.dart`, I deleted the
`for (final key in planLetterKeys(controller)) SingleActivator(key): ...` entry. Both go red:
- rv9-guardDNG: `Expected: false` / `Actual: <true>`;
- OS1 (runtime): `Expected: a string starting with 'Select'` / `Actual: 'Door'`.

**The same guard mutation with the three tools also removed from the kit leaves both
green** (`+1: All tests passed!` each). So they become effective guards only with this
task's tools. Before Task 15 they were vacuous. All files were reverted (`clean 0`).
