# Final fix wave report

Commits: `4852e151` (tests), `3bc32d9a` (docs). Head was `cc196aa0`.
Production code unchanged except the two doc comments of finding 6.

## Findings

1. **Notifications** (`test/service/table_band_test.dart`, new RB15b, ~854):
   counts `tool.addListener`; after the band starts a further move grows `n`,
   Escape mid-band grows it again; premises: phase dragging, a painted band.
2. **R-1** (new RB2b, ~445): leg 1 under pan, Shift at the down only, moves
   and up plain, selection {9} -> {1,2,9}, camera matrix unchanged; leg 2
   under band, plain down, Shift on moves and up, {9} -> {1,2}. Premises:
   press on the floor, default option is `pan`. The rig's helpers already took
   modifiers per event; no rig change.
3. **Crossing's `!t.locked`** (RB10, last leg, ~700): select {1}; crossing
   band over 8's right edge; premises asserted: the band overlaps 8's leaves,
   not 7's, and 8's layer differs from 7's (8 is on the locked layer) ->
   selection empty.
4. **RB13** (~771): after the band's up, `r.tap(top)`; `taps == ['2','2']`,
   `doubleTaps` empty.
5. **RBV4** renamed in `test/host/band_view_test.dart:306-309`: "...a mode
   switch mid-band leaves the selection as it was".
6. **Wheel wording** corrected in `floor_plan_types.dart:~193`,
   `floor_plan_view.dart:~104`, `CHANGELOG.md:~17`, `docs/host-guide.md:~546`
   and `~1387`, spec doc-comment `:~149` and Risks `:~374`; dated errata line
   in the spec's Status paragraph. Guide §10 Touch says only "two fingers"
   (true on touch); unchanged apart from the rewrap. Other "wheel" hits
   (zoom during a band, G-3 lock, the guide's wheel table) are correct.
7. **Rewrap**: `docs/host-guide.md:546-548` and `:2184-2187`, all <= 80 cols.
   CHANGELOG bullet reflowed too.

## Mutants (each applied, test run red, reverted by `cp` from a saved copy,
`cmp` confirmed identical)

| Mutant | Edit in `table_select_tool.dart` | Killing test | Failing line |
|---|---|---|---|
| M-RB22 | drop `notifyListeners()` at :297 | RB15b | `table_band_test.dart:868` "a further move repaints" (expected > 2, got 2) |
| M-RB23 | drop `notifyListeners()` at :641 | RB15b | `:873` "Escape repaints" (expected > 3, got 3) |
| M-RB24 (B) | :387 `if (_toggle)` -> `if (e.shift \|\| e.control \|\| e.meta)` | RB2b | `:464` leg 1 "a band adds" (got a replace). Leg 2 alone, in a scratch test since deleted, also red (union with 9) |
| M-RB25 (D) | :307 `_toggle` -> `(e.shift \|\| e.control \|\| e.meta)` | RB2b | `:464` (it pans: selection stays {9}) |
| M-RB26 | :422 drop `!t.locked &&` | RB10 | `:713` "locked member alone: none" |
| M-RB27 (F) | `_startsBand` block moved above `_lastTap = null` | RB13 | `:775` doubleTaps expected empty, got ['2'] |

Every new pin is green on the unmutated code (table_band_test.dart: 17/17).

## Gates (from `packages/jet_cad_floor_plan` unless noted)

- `flutter test --enable-vmservice`: `01:46 +2010: All tests passed!`
- `flutter analyze`: `No issues found! (ran in 4.2s)`
- `dart format --output=none --set-exit-if-changed .`: `Formatted 296 files (0 changed)`
- repo root `dart run tool/ci/check_guide.dart`: `docs/host-guide.md: all 54 code blocks are in the host probe`
- Host probe not rerun: no guide code block changed. The other packages were
  not touched (no change under `jet_cad_2d*`).

## Concerns

None. No `analysis_options.yaml` committed (`git status` showed only the seven
intended files).
