# Release 0.7.0 — the independent review and its fixes

**Prepared** on `release/0.7.0`, cut from `main` at `7d3ce8d` (rubber-band
selection merged at `232d905`), on the human's *"başla"* (2026-10-13).
The release commit is `aa5d07e`: the five packages (`jet_cad_2d`,
`jet_cad_2d_flutter`, `jet_cad_2d_gpu`, `jet_cad_floor_plan`,
`jet_cad_restaurant_symbols`) at 0.7.0, the dormant `packages/jet_cad`
untouched; the CHANGELOG's Unreleased section become 0.7.0 ("Nothing
yet." left under Unreleased); the host guide covering 0.7.0, §1's ref a
placeholder (`<the commit SHA of v0.7.0>`) that the commit after the
merge fills; CI's old-host probes gain `v0.6.0` (ruling 7 of the
rubber-band ledger); STATUS. The root `pubspec.lock` is unchanged by
`flutter pub get`.

**Gates at `aa5d07e`:** `tool/ci` `dart test` +64; `check_guide`, all 54
code blocks in the host probe; `tool/ci/host_probe.sh` by git at the full
SHA ("no GPU renderer, no build hook; build/web is 42M");
`old_host_probe.sh v0.3.0`, `v0.4.0`, `v0.5.1` and `v0.6.0`, each
"main.dart analyses against aa5d07e…". The release commit changes no
code; the package suites ran green in CI at `7d3ce8d` (run 38353978372,
all ten jobs).

## The review (an independent Opus reviewer, read-only)

**Verdict: Approved with fixes.** Verified clean: exactly the five
pubspecs move; `jet_cad_2d`, `jet_cad_2d_gpu` and the restaurant symbols
carry no code change since `3bf64a7`, so schema 10 and the service layout
are unchanged; `jet_cad_2d_flutter` adds only `bandModeFor` and
`SelectionBandPainter` (the `SelectTool` refactor private, its look
identical); the planner's barrel adds only `FloorPlanFloorDrag`, and
`FloorPlanView.floorDrag` is named and optional; `ServiceOptions` is under
`src/`; no public type a host implements or extends gained a member
(`FloorPlanController`, `FloorPlanStrings`, `Tool` unchanged) and no
existing enum or sealed type gained one; §1 in 0.6.0's form; the CI step
and its comment; STATUS coherent but for R-4.

| # | Finding | Severity | Applied |
|---|---|---|---|
| R-1 | The guide's §11 "Schema 10" said "a plan saved by 0.6.0" and did not say 0.6.0 and 0.7.0 share plans; 0.3.0, 0.5.0 and 0.5.1 each updated the matching sentence | Important | "Saved by 0.6.0 or 0.7.0"; "0.6.0 and 0.7.0 save the same plans and service layouts, so they can share them" |
| R-2 | The CHANGELOG left out what a host observes: `selectedTables` once per band and no tap, double tap or hover; Escape under `shortcuts: false` and every key taken mid-band; a reach-only finger under `band` bands instead of moving the table; `contextMenu`'s changed documentation; "one-finger or mouse" omitted the stylus | Minor | A "What a band reports" bullet, the reach sentence, a `contextMenu` bullet, "one-finger, mouse or stylus"; the guide's "Cancelling" gains the every-key sentence (checked in `TableSelectTool.onKey`) |
| R-3 | `FloorPlanFloorDrag` and `FloorPlanView.floorDrag` named only inside code | Minor | Named outright, with `pan`/`band` and the default |
| R-4 | STATUS's "Where the project stands" listed the old-host probes without `v0.6.0` | Minor | `v0.6.0` added, citing ruling 7 |
| R-5 | The guide's `longPress` bullet and touch section mention the band without a *since 0.7.0* marker; the `floorDrag` bullet omitted the stylus | Minor | Both marked; "one-finger, mouse or stylus" |

## After the merge (the human's word)

`git merge --no-ff release/0.7.0` into `main`; then one commit filling
the guide's §1 with the merge's SHA and recording it in STATUS; the push
and the tag `v0.7.0` at the merge, the human's.
