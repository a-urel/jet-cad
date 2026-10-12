# Release 0.6.0 — the independent review and its fixes

**Prepared** on `release/0.6.0`, cut from `feat/plan-colors-slice-2` at
`752eace` (Slice 2 of plan colours, reviewed and approved; Slice 1 already
on `main` at `ce0a4f9`), while the human slept: the human's *"uyku saatim
geldi. otomatik devam et. çok gerekmedikçe durma!"* (2026-10-12). The
release commit is `d65369d`: the five packages (`jet_cad_2d`,
`jet_cad_2d_flutter`, `jet_cad_2d_gpu`, `jet_cad_floor_plan`,
`jet_cad_restaurant_symbols`) at 0.6.0, the dormant `packages/jet_cad`
untouched; the CHANGELOG's Unreleased section become 0.6.0 ("Nothing yet."
left under Unreleased); the host guide covering 0.6.0, §1's ref a
placeholder (`<the commit SHA of v0.6.0>`) that the commit after the merge
fills; STATUS. The root `pubspec.lock` is unchanged by `flutter pub get`.

**Gates at `d65369d`:** `tool/ci` `dart test` +64; `check_guide`, all 53
code blocks in the host probe; `tool/ci/host_probe.sh` by git at the full
SHA, exit 0 ("no GPU renderer, no build hook; build/web is 42M");
`old_host_probe.sh v0.3.0`, `v0.4.0` and `v0.5.1`, each "main.dart
analyses against d65369d…". The package suites ran at Slice 2's head
`752eace` (the release commit changes no code): the planner +1984, the
render package the standing set but the recorded macOS pair
(`text_lod_ladder` rungs 1–2 pass), and, at Slice 2's Task 6, the engine
1290 and GPU 20 exactly, restaurant symbols 97, the floor planner app 212,
the restaurant demo 68.

## The review (an independent Opus reviewer, read-only)

**Verdict: Approved with fixes.** Verified clean: exactly the five
pubspecs move; the packages depend on each other by `path:` only, no lock
tracked; the CHANGELOG's compatibility statement (a 0.6.0 plan refused by
0.5.1 as a `FormatException` naming `unsupported schemaVersion 10`; the
9 → 10 migration empty; service layouts unchanged; the Flutter floor
unchanged); every listed item against the code; the guide's 0.6.0 and
"since 0.6.0" markers and §1's placeholder in 0.5.1's form; P-1 statically
(the 0.5.1 probe neither implements `FloorPlanStrings` nor
`FloorPlanController`; no sealed type or enum on the host barrel gained a
member; every other new parameter is named and optional).

| # | Finding | Severity | Applied |
|---|---|---|---|
| R-1 | A class that `implements FloorPlanController` (a hand-written test double) no longer compiles: `setTableColor`, `setTablesColor`, and `exportPlan`/`printPlan`'s new `tableColorOpacity`; the CHANGELOG said "two changes can break a host's own code" | Important | "Three changes" in the intro; a "Breaking for a host's own controller double" bullet |
| R-2 | `jet_cad_2d` unlisted: `SetEntityStyleCommand`, and the regeneration now restamping a matched child's colour and transparency | Important | A `jet_cad_2d` bullet |
| R-3 | The new `ArgumentError`s of `exportPlan`/`printPlan` and `exportBytes`/`exportPdfBytes` for an opacity not finite or outside [0, 1] | Minor | Stated in both bullets |
| R-4 | A recolour reported on `designChanges` as `FloorPlanTableChanged` (`FloorPlanTableDetail.==` includes `color`) | Minor | Stated in the table bullet |
| R-5 | The `jet_cad_2d_flutter` bullet named only `PageUnderlayFill` | Minor | `PageUnderlayPolygon`, `PageUnderlayCircle`, `drawPageUnderlay` named |
| R-6 | The Colour row under `readOnly` shows for a room too; the bundled libraries re-encoded at schema 10; `RoomParams`' `color`, `colorValue`, `copyWith(color:)` | Minor | All three stated |
| R-7 | STATUS: the in-flight entry and the resume headline stale; no release entry; the date | Minor | Updated; a "Release 0.6.0" in-flight entry |

## After the merge (the human's word)

`git merge --no-ff release/0.6.0` into `main` (it brings Slice 2's eleven
commits with it); then one commit filling the guide's §1 with the merge's
SHA and recording it in STATUS; the push and the tag `v0.6.0` at the
merge, the human's.
