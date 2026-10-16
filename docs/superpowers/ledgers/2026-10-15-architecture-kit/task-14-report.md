# Task 14 report: the opening type, grips and properties (spec 3a C3.3, C1.1, C1.7, C1.10, C6, C7)

Status: DONE_WITH_CONCERNS (one brief defect fixed in a new test; see Deviations D1).

Commits:
- `7ca6a275 feat(architecture): the opening type, its slide grip and its fields (spec 3a C3.3)`
- `645bef75 test(architecture): the opening's position range follows its host between commits (spec 3a C1.1)` (OT-range-live, added on the controller's dispatch note; see "New test beyond the brief")

## Implementation summary

- `lib/src/opening/opening_grips.dart`: ported from `jet_cad_floor_plan/lib/src/parametric/opening_grips.dart` as Step 7 gives it. `diff` against the source shows only:
  - the imports;
  - the port line in the class doc;
  - the constructor and its `live` field;
  - `_Slide.of(d, group, live)` at the three call sites;
  - `_Slide.of`'s `LiveTypeOf` parameter and its two adapter calls.
- `lib/src/opening/opening_plan.dart`: Step 8 verbatim. It holds `openingTitle`, `openingWidthOf`, `openingPositionRange` (asks `kitTypeIdOf`, so L is the host's group-local centreline length), the flips, `openingGripsOf` and `openingPlanType`. All four fields carry `gate: PlanGate.reshape`, and the flips have `visible: _isDoor`.
- `lib/src/type_naming.dart` (R-P19): Step 8 verbatim. `kitTypeIdOf` is the engine's naming rule over a private catalog of box, wall and opening.
- `lib/src/kit.dart`: `types: [boxPlanType, wallPlanType, openingPlanType]`.
- `lib/src/wall/wall_grips.dart` (R14-5):
  - imports `ids`, `opening`, and `opening_geometry` (show `layoutInDocument`, `placeCut`, `storedCentreOf`);
  - today's "Openings stay put" doc bullet is restored;
  - `..._keptPut(d, moved),` sits after the walls' commands in the same compound;
  - `_keptPut` is an instance method reading `_live`;
  - today's `_seated` is unchanged.
- Words: only Task 9's ids are used. `tool:architecture.{door,window,gap}` and `property:architecture.opening.{width,position,flip-hinge,flip-swing}` are present in en, de and tr (7 hits each). No word id was invented.

## TDD evidence

All tests were written first. Kit tests: `opening_plan_test` (from the brief), and the ported `opening_object_test`, `opening_end_drag_test` and `opening_grips_test` (with OT-grips).

RED for the kit, `flutter test test/opening/` before any lib file existed:
```
test/opening/opening_grips_test.dart:12:8: Error: Error when reading 'lib/src/opening/opening_grips.dart': No such file or directory
test/opening/opening_grips_test.dart:14:8: Error: Error when reading 'lib/src/opening/opening_plan.dart': No such file or directory
test/opening/opening_plan_test.dart:15:8: Error: Error when reading 'lib/src/opening/opening_plan.dart': No such file or directory
```
`opening_object_test` and `opening_end_drag_test` compiled against Task 12's `WallGrips`, so their red was assertion-level, from the missing `_keptPut`:
- EP1 `[E]`: `Expected: a value less than <0.000001>  Actual: <700.0000000001216>`
- EP3 `[E]`: `Expected: a numeric value within <1e-9> of <1266.566156604079>  Actual: <1500.0>`
- EP5 (start) `[E]`: `Expected: <-2899.5000000002906>  Actual: <600.5>`
- EP6 `[E]` and EP9 `[E]`: `Expected: [4000]  Actual: []`
- EP7 `[E]`: `Expected: an object with length of <0>`
- EP8 `[E]`: `Expected: <349.5000000000855>  Actual: <350.0000000000236>`

RED for the integration package, `flutter test --enable-vmservice test/opening/`: all 12 cases were `[E]`. The first exception in each was:
```
The following UnregisteredComponentError was thrown running a test:
UnregisteredComponentError(OpeningParams): call registry.register first
```
The 12 cases are OS1, OS2, OS4, OT-panel-range, OR8, RD1, SG1 (shell), SG2, SG4, KJ4, KJ5 and OT-frozen-host. None passed early.

GREEN:
- kit `dart format . && flutter test`: `00:09 +142: All tests passed!` (113 before, plus 29). With OT-range-live it is `+143`.
- integration `flutter test --enable-vmservice`: `00:06 +40: All tests passed!` (28 before, plus 12).

Printed output:
- `RD1 leaf [1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00] body [0.00, 0.00, 0.00] paper 0.22`
- `KJ5: B turned to 1.9546510425823964°`

## Gates (after both commits)

- **kit**
  - `flutter test`: `00:09 +143: All tests passed!`
  - `flutter analyze`: `No issues found!`
  - format: `Formatted 55 files (0 changed)`, exit 0
  - `dart pub publish --dry-run`: `Package has 0 warnings.`
- **integration**
  - `flutter test --enable-vmservice`: `00:07 +40: All tests passed!`
  - `flutter analyze`: `No issues found!`
  - format: `Formatted 17 files (0 changed)`, exit 0
- **repository**
  - `dart run tool/ci/check_kit_deps.dart`: `kit dependencies: 2 package(s) checked, none names the plan library or another kit`
  - `git status --short`: empty. No `analysis_options.yaml` was touched.

## Mutation results

All were run on committed files. Each was reverted with `git checkout -- <file>`, and `git diff --quiet` then exited 0.

| Id | Mutation | Red |
|---|---|---|
| M-OT-1 | `openingTitle`: the window's and gap's words swapped | OT-title `[E]`: `Which: at location [1] is 'tool:architecture.gap' instead of 'tool:architecture.window'` |
| M-OT-2 | `isOpeningWidth(OpeningKind.door, w)` | OT-width `[E]`: `returned OpeningParams:<OpeningParams(gap on 3E8 at 600.0, 0.000004, start, left)>` |
| M-OT-3 | L + 1 | OT-range `[E]` (`door … at 4000.0000000000005` accepted); OS1 `[E]` (`Expected: '1812.5' Actual: '6001'`); OT-panel-range `[E]` |
| M-OT-4 | first `return null;` → `(0.0, double.maxFinite)` | OT-range `[E]` (`window on 5DC at 0.0` accepted: Q, the box host); OT-panel-range `[E]` (`Expected: '300' Actual: '0'`) |
| M-OT-5 | `doc.components.get<WallParams>(o.host) == null` | OT-range `[E]`: `window on FA0 at 0.0` accepted (R, whose host D carries `WallParams`) |
| M-OT-6 | L in world | OT-range `[E]`: `door … at 4000.0000000000005` accepted. World L is 5,000, so nextUp(L) and 4,500 both pass. |
| M-OT-7 | no `visible: _isDoor` on flip-hinge | OT-flip `[E]`: `Expected: [true, true, false, false, false, false]  Actual: [true, true, true, false, true, false]` |
| M-OT-8 | `_flipHinge` always sets start | OT-flip `[E]`: `Expected: HingeEnd:<HingeEnd.end>  Actual: HingeEnd:<HingeEnd.start>` |
| M-OT-9 | no `gate` on width | OT-fields `[E]`: `at location [0] is <null> instead of PlanGate:<PlanGate.reshape>` |
| M-OT-10 | the aperture ignores `objectSnap` | OT-grips `[E]`: `Expected: … within <0.000001> of <1552.63…>  Actual: <1567.63…>` (object snap off still snaps) |
| M-OT-11 | `/ scale` → `* scale` | OT-grips `[E]`: `Expected: … within <1e-9> of <2017.63…>  Actual: <2002.63…>` |
| M-OT-12 | `openingPlanType` removed from the kit | OT-kit `[E]`: `Expected: <2>  Actual: <-1>`; OS1, OS2, OS4 and OT-panel-range `[E]` |
| M-OT-13 | `references` → `const []` | OT-frozen-host `[E]`: `Expected: false  Actual: <true>` (the wall edit applies) |
| M-OT-14 | see below | OT-frozen-host `[E]`: `Expected: false  Actual: <true>` |
| M-OT-15 | `..._keptPut(d, moved),` deleted | EP1, EP3, EP5 (start), EP6, EP7, EP8, EP9 `[E]`. EP1: `Actual: <700.0000000001216>` |
| M-OT-16 | the `_live(o)` filter deleted | EP6 `[E]`: `Expected: [4000]  Actual: [4000, 5100, 5200]` |
| M-OT-17 | `position: p` | EP7 `[E]`: `Expected: an object with length of <0> … Which: has length of <95>` |
| M-OT-18 | `s.cut?.clamped != true` → `true` | SG3 and SG3 (old D13) `[E]`: `Expected: not null  Actual: <null>` |
| M-OT-19 (new) | `openingPositionRange` memoises L per host handle (a stale cache, the class of Task 12's band-cache finding) | OT-range-live `[E]`: `Invalid argument (position): is outside [0.0, 4000.0]: 4500.0` |

M-OT-14 was run as an equivalent mutation. The brief names `jet_cad_2d_plan/lib/src/kits/locks.dart`, but Task 7's statements that lock a frozen object's references are in `lib/src/kits/guard.dart`, in `_freeze`:
```dart
      if (references != null)
        for (final object in objects) ...references(document, object),
```
`locks.dart` only offers `addBroken`. I deleted those two lines in `guard.dart`, and OT-frozen-host went red as shown. I then restored the file with `git checkout`, and `git diff --quiet` exited 0.

## Ported-test accounting (32 cases)

| Old (`jet_cad_floor_plan/test/`) | Cases | New | Change classes |
|---|---|---|---|
| `opening_object_test.dart` | OR1, OR2, OR4, OR5, DF1 | kit `test/opening/opening_object_test.dart` | A13-imports; A14-grips at :470 |
| `opening_end_drag_test.dart` | EP1, EP2, EP3, EP4, EP5, EP5 (start), EP6, EP7, EP8, EP9 | kit `test/opening/opening_end_drag_test.dart` | A13-imports; A14-grips at the 9 lines; A13-live at :578, :652, :715, :748, :764; D2 at EP8 and EP9 |
| `opening_grips_test.dart` | SG1 provider, SG1 apertureDir, SG5, SG3, SG3 old D13, SG6, SG7 (+ new OT-grips) | kit `test/opening/opening_grips_test.dart` | A13-imports, with the shell imports and `dart:typed_data` dropped; A14-grips; A13-live; SG6 → `_Dispatch(doc)` (R14-7); D2 at SG3 old D13 |
| `opening_grips_test.dart` | SG1 (shell), SG2, SG4 | integration `test/opening/opening_grips_test.dart` | the harness swap (R14-8: `openingController(openingPlanText(shellPage, …))`, `pumpEditor`, `view.*` → `c.*`/`cameraOf(c)`) |
| `opening_panel_test.dart` | OS1, OS2, OS4 (+ new OT-panel-range) | integration `test/opening/opening_panel_test.dart` | finders (R14-10, class 3); harness; OS4's fixture through `after:` |
| `opening_kink_test.dart` | KJ4, KJ5 | integration `test/opening/opening_kink_test.dart` | harness; KJ4 `hostFrameInDocument(…).uE` → `OpeningOracle(c.document).span(hA).$2`; KJ5 `worldWallOf` → `worldEndsOf` (R14-9) |
| `opening_paint_test.dart` | RD1 | integration `test/opening/opening_paint_test.dart` | harness; premises read after the load; `globalOf(p)` → `globalAt(tester, c, p)` |
| `opening_symbol_test.dart` | OR8 | integration `test/opening/opening_symbol_test.dart` | harness; `globalOf` → `globalAt`; `view.selection` → `c.selection` |

Every ported kit file was diffed against its source. The only differences are the listed lines, the moved provider lines (D2) and `dart format` rewraps.

Every non-ASCII line in the new files was checked against its source with a script: there were no mismatches.

The KJ4 oracle swap (R14-9) holds within 1e-6: KJ4 passes, so there was no finding at the kink.

## Deviations

- **D1 (a brief defect in the new OT-frozen-host).**
  - **What failed.** `expect(enc(doc), before)` failed after the refused wall edit, which is the first check:
    ```
    Which: is different.
           Expected: ... "handle":23,"owner": ...
             Actual: ... "handle":24,"owner": ...
    ```
  - **Why.** The plan library's lock (`locks.dart`) applies a command, then applies its inverse and throws `PlanLocked`. Undoing the wall's regeneration re-adds the wall's entities in another slot order. The entities, nodes and components are otherwise identical, and slot order is history, not state (06 D11).
  - **The fix.** The test now compares `canon(doc)`, as the plan library's own `test/kits/frozen_references_test.dart` does. A comment in the test says why.
  - **What still holds.** The refusal itself (`c.execute(...)` false, `lockHint` true, undo depth 0, delete false, the wall node kept) is unchanged, and M-OT-13 and M-OT-14 still turn the case red.
- **D2 (A14-grips where no `doc` is in scope).** In SG3 (old D13), EP8 and EP9, today's provider is built before a loop that creates one document per iteration. `liveOf(doc)` needs that document, so each `OpeningGrips(live: liveOf(doc), …)` or `WallGrips(live: liveOf(doc))` line moved inside its loop, right after `final doc = wallDoc();`. Both providers' `drag` and `gripsOf` keep no state between calls in these cases, so the meaning is unchanged. No assertion was touched.
- **D3 (copied-oracle range).** `opening_fixture.dart`'s pure block ends at :782 (`oracleCut`). Lines :783-786 are a blank line and the random-plans section header, so :24-782 was copied.
- **D4 (`mitreLimit` copied too).** `oracleTeeFootprint` in the copied block reads the kit's internal `mitreLimit`, which the integration package cannot import. The support file adds a copy of `jet_cad_floor_plan/lib/src/parametric/wall.dart:50-52` under its own "Copied from" line: the constant `4`, with its doc and name. The oracle block itself stays unchanged.
- **D5 (OR8 and RD1 drift checks kept).** The brief drops OR8's :375-377 and RD1's :72-74 with the temporary system. The `expect(driftOf(doc), isEmpty)` lines among them are kept, run on `c.document` after the load, so no assertion is lost.
- **D6 (panel fixture).** In the panel fixture, the `final a = next();` lines became `a = next();` and so on. The handles must leave the build closure, so they are `late` locals. The record is built after the closure, and OS4's `after:` receives it. Every value is unchanged.
- **Integration headers.** Each C6 file starts with a "Ported from … (spec 3a C6, C7)" line and `// ignore_for_file: invalid_use_of_internal_member`, then today's header. The C6 grips file does not import `jet_cad_2d_plan`: it does not use it, and `unused_import` is an error.

## New test beyond the brief

**OT-range-live** (kit `opening_plan_test.dart`) answers the dispatch note: "change the host wall between two commits so the range really moves".
- The `position` field is read once.
- Then A, which is turned 0.6 rad, scaled 1.25 and at the far origin, goes through three states: L = 4,000, then lengthened to L = 4,800, then shortened to L = 3,000.
- Each commit goes through `commitField` with that field read at the start. 4,500 is refused, then commits. 3,900 is refused. 3,000, the new L, commits.
- M-OT-19 (a per-host memoised L) turns it red.

## Concerns

- D1: the brief's `enc` equality after a lock refusal cannot hold against the plan library as it is. Any later task that asserts byte equality after a `PlanLocked` refusal will hit the same thing; `canon` is the right comparison.
- M-OT-14's file in the brief was wrong: the code is in `guard.dart`, not `locks.dart`.
- OR8 ran under `pumpEditor`'s camera, turned 0.35 rad, and its window band still selects A. No `turn: 0` was needed.

## Files changed

Kit (`packages/jet_cad_2d_kit_architecture/`):
- New:
  - `lib/src/opening/opening_grips.dart`
  - `lib/src/opening/opening_plan.dart`
  - `lib/src/type_naming.dart`
  - `test/opening/opening_plan_test.dart`
  - `test/opening/opening_object_test.dart`
  - `test/opening/opening_grips_test.dart`
  - `test/opening/opening_end_drag_test.dart`
- Modified:
  - `lib/src/kit.dart`
  - `lib/src/wall/wall_grips.dart`

Integration (`packages/jet_cad_2d_integration/`), all new:
- `test/support/opening_support.dart`
- `test/opening/opening_panel_test.dart`
- `test/opening/opening_grips_test.dart`
- `test/opening/opening_kink_test.dart`
- `test/opening/opening_paint_test.dart`
- `test/opening/opening_symbol_test.dart`
- `test/opening/opening_frozen_test.dart`
