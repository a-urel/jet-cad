# The plan library's chrome in shadcn — results

**Date:** 2026-10-23. **Branch:** `claude/shadcn-ui-75d8dc`, cut from local
`main` at `46e95ed9`, local `main` (alignment guides, `c5da0931`) merged in at
`6b026d8e`. Not merged into `main`, not pushed.
**Spec:** [2026-10-23-plan-shadcn-chrome-design.md](../specs/2026-10-23-plan-shadcn-chrome-design.md)
(rev 2, approved; rev 1 reviewed by OpenCode on the human's request).
**Plan:** [2026-10-23-plan-shadcn-chrome.md](../plans/2026-10-23-plan-shadcn-chrome.md).
**Ledger:** [docs/superpowers/ledgers/2026-10-23-plan-shadcn-chrome/](../ledgers/2026-10-23-plan-shadcn-chrome/)
(progress, every task's brief and report, `rulings.md` with every test change).

Executed with Sonnet implementers and no reviewer sessions (the human's rule):
the controller read each task's diff, ran its own mutation and re-ran the gates.

## What shipped

- `jet_cad_2d_plan` takes `shadcn_ui ^0.57.1` (resolved 0.57.3) and
  `lucide_icons_flutter ^3.1.25`. Its chrome (editor bar, tool palette, the
  library's own symbol gallery, property, page and layer panels, service bar,
  menus, export dialog) is built from internal parts in `lib/src/chrome/`.
- The scope (`PlanShadScope`) uses an ancestor `ShadTheme` as is, else derives
  one from the Material `ThemeData` (colours, brightness, font family); it
  installs the default text style and icon theme; host slots keep a
  transparent `Material`.
- Canvas-owned reads (canvas background, paper, brightness, layer swatch ink,
  `PlanTheme`) stay Material; a test with disagreeing `ShadTheme` and
  `ThemeData` pins it.
- Icons are Lucide in the library and the architecture kit (`IconData` API
  unchanged).
- No public signature change; `tool/ci/check_api_boundary.dart` (new, in CI)
  proves no `shadcn_ui` or `lucide_icons_flutter` type is reachable from the
  barrel.
- Guards: `test/l10n/shadcn_words_test.dart` (SW1-SW5: one `ShadInput` site
  with the library's text menu and no keyboard toolbar, no word-carrying
  shadcn component, an allowlist of shadcn identifiers, `ShadTooltip` only in
  the chrome); `test/invariants/kept_material_test.dart` (KM1: every Material
  construct kept in `lib/` is listed with its reason; KM2: no `Icons.`).
- The leak collectors (LK1, LK2) read every chrome part's words, open or
  closed.
- The restaurant demo's POS look is a zinc `ShadTheme`; `posColorScheme` and
  `posViewTheme` are gone.
- `docs/host-guide.md` §1 and §10, the CHANGELOGs ("Unreleased"), and the
  screenshots (4 regenerated, then 2 again after the checkbox fix).

## Rulings (in the order made; each with its cost if wrong)

1. SDK floors stay (plan `^3.6.0`, dev_harness `^3.5.0`) against plan Task 1:
   raising them flips `dart format` to the tall style (306 of 324 files,
   including the canvas files the alignment-guides branch owned). shadcn_ui's
   own `>=3.11.0` binds hosts anyway; the guide says so. Cost: pub shows a
   floor lower than real.
2. The host probe's "no build hook" rule (GPU split spec S8) is narrowed to
   allow exactly `objective_c`'s hook, which shadcn_ui brings through
   universal_image → extended_image_library → path_provider_foundation. Every
   other hook and every GPU package still fails. Cost: hosts run one native-
   assets hook; monepro already does.
3. Derived foregrounds below 4.5:1 swap to black or white (Material 2 hosts).
4. Read-only `PlanTextField` keeps today's behaviour (focusable, selectable,
   copyable) by refusing edits, not by `ShadInput.readOnly` (which drops
   focus). Cost: screen readers do not hear "read-only".
5. `PlanMenuButton`'s Escape handler, `PlanIconButton` as a StatefulWidget
   (its tooltip is muted while its menu is open).
6. **R-FRAME:** the tests listed under R-FRAME in `rulings.md` leaned on a frame the old chrome always kept
   scheduled (a Material ink animation never finishes under zero-duration
   pumps). A root-cause probe showed the product is fine: the document
   change's stream microtask runs before the next frame in a real event loop
   and asks for its own frame. The tests now `await tester.idle()` before the
   pump that shows the change; `nextFrame`'s premise "the change asks for a
   frame" is now live (it passed vacuously before; a mutation removing the
   idle turns TF8 red).
7. `Scaffold` stays in `PlanEditor`; `PlanListRow`/`PlanSegmented` content is
   `Flexible` (no overflow at 2× text).
8. `PlanSelect` gained option keys, `expanded`, `focusNode`, Escape returning
   focus (today's dropdown behaviour).
9. The duplicate-label warning is `mutedForeground` (shadcn has no warning
   colour). Cost: it reads quieter.
10. **DC9:** an open select or menu keeps the keyboard (every key but its own
    navigation is consumed), as the Material route did; DC9 unchanged.
11. The custom paper size is the select's placeholder, not a disabled option.
12. The gallery test's `foreground == 0x000000` read is gone with the
    renderer gallery; GG6 checks the same ink.
13. **R-BarGeometry:** shadcn icon buttons are 40 px (were 48); the service
    bar's tests compute edges from the measured width (pinned at 40) and keep
    every documented gap literal. Cost: if 48 px was a contract.
14. **R-BarSurface:** the service bar paints the derived shadcn background
    (the seed `surface`), not `surfaceContainer`.
15. The export dialog's outside tap is a full-page detector under the card
    (the scope's mouse surface hides the route barrier).
16. The gallery's loading spinner stays Material (`CircularProgressIndicator`;
    shadcn 0.57 has none); the panels' transparent `Material` roots stay.
17. The POS demo's `ShadTheme` font is Roboto.
18. A derived theme's unchecked checkbox and off switch take `outlineVariant`
    (shadcn's `input` fill was the dark Material outline; `input` itself stays
    the outline, which the paper swatches' D6a borders need).

Every test change is in the ledger's `rulings.md` (39 entries, each
file:line, old → new, why the same thing is checked).

## Mutations (each turned the named test red, then reverted)

| Task | Mutation | Red |
|---|---|---|
| 1 | a public `ShadThemeData` getter on `PlanEditor` | API boundary CLI, AB6 |
| 1 | the probe's allowed hook name `objective` | SC15, the probe |
| 2 | the scope always derives / never derives / no `DefaultTextStyle` / no slot `Material` | SC2+SC4+SC6 / SC1 / SC4 / HS1 alone |
| 2 | (controller) always derive | SC2, SC4, SC6 |
| 3 | no `groupId`; no select reset; `ShadContextMenuRegion`; no `selected:` semantics; no text menu builder | CP1; CP4; CP6; CP10; SW2 |
| 3 | (controller) no reset after `onChanged` | CP4 |
| 4 | (controller) collectors without `PlanWordsCarrier` | LK1x tooltip, LK1x menu entry |
| 5 | palette reads Material `secondaryContainer` | ED1 |
| 5 | nextFrame without idle | TF8 premise |
| 5 | raw `ShadTooltip` outside the chrome; empty `PlanTooltip.visibleWords` | SW5; LK1x damaged warning |
| 5 | (controller) a `ShadTooltip` reference in colour_row | SW5 |
| 6 | no select reset in the panel | PP3, PP4 |
| 6 | (controller) `readOnly: false` | PP2 |
| 7 | no `groupId`; swatch ink from `ShadTheme` | LP1; LP5 |
| 7 | (controller) modal keys never consume | CP12, CP13 (DC9) |
| 8 | collapse keyed by index | GG1 |
| 8 | (controller) taps ignore `enabled` | GG4 |
| 9 | canvas background from `ShadTheme`; service bar gap 13 | SV3; BC1 ×11 |
| 9 | (controller) `serviceBarHeight` ignored | SV2 |
| 10 | `showShadDialog(context:)` | EX1 ×2, EX2, EX4, EX5 |
| 10 | (controller) outside tap does nothing | EX5 |
| 11 | an `IconButton` / a `Divider` (controller) in a panel; `Icons.remove`; no `Scrollbar` | KM1; KM2; KM1 |
| 12 | no `ShadTheme` wrap under POS | DL1, DL2 |
| close | (controller) no `checkboxTheme` in the derived theme | SC10 |

## Gates (final run at `3a77f5bc`, real last lines)

- `jet_cad_2d`: 1343 passed, 2 failed — the two standing failures of
  `generate_document_test.dart` (`tool/ci/standing_failures.txt`); the package
  is untouched by this branch. Analyze clean, format 0 changed.
- `jet_cad_2d_kit` `00:07 +409: All tests passed!`;
  `jet_cad_2d_kit_architecture` `00:24 +661`; `jet_cad_2d_kit_restaurant`
  `00:02 +184`; analyze and format clean.
- `jet_cad_2d_flutter`: only its 7 standing text-ladder golden failures;
  analyze clean, format 0 changed. `jet_cad_2d_gpu` `00:01 +20: All tests passed!`.
- `jet_cad_2d_plan` `02:02 +1846 ~13: All tests passed!`, analyze clean,
  format 0 changed.
- `jet_cad_2d_integration` `00:58 +240`; `restaurant_demo` `00:28 +114`;
  `architecture_demo` `00:33 +176`; `dev_harness` `00:00 +10`;
  `tool/screenshots` `00:08 +14`; `tool/ci` `00:51 +122`.
- `check_api_boundary`: no exported type mentions shadcn_ui or
  lucide_icons_flutter. `check_guide`: all 38 code blocks are in the host
  probe. `check_screenshots`: every rule holds. `check_kit_deps`: 3 packages,
  none names the plan library or another kit. `tool/readme_probe` analyze
  clean. Host probe (Task 13, at `23b364b9`): green, web build 46 MB.
- `dart pub publish --dry-run`: `jet_cad_2d_plan` and
  `jet_cad_2d_kit_architecture` 0 warnings.
- Both demos build for macOS (`flutter build macos --debug`); the restaurant
  demo's `integration_test` (POS1) passed on the real binary.

## Not done, open

- Interactive runs of both demos at phone, tablet and desktop widths, light
  and dark, were not done by hand; the evidence is the widget tests at those
  widths, the regenerated screenshots (looked at) and the macOS builds.
- Deferred minors: a host `ThemeData` with a null `bodyMedium.fontFamily`
  shows shadcn's Geist; the export dialog's barrier no longer dims; the
  drawer scrim reads Material's `scrim`; layer rows are taller; the gallery
  search lost its magnifier glyph and its soft-keyboard "search" action;
  under POS the demo's own Material widgets read the app's seeded scheme;
  EX8 (`export_flow_test`) failed once in one full run and passed in the
  next four.
- monepro must move to `shadcn_ui ^0.57.1`.
