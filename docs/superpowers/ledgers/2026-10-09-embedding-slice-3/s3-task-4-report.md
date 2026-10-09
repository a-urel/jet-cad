# Slice 3, Task 4: demo, guide, probe, CHANGELOG, gates (implementer's report)

- **Branch:** `claude/exciting-pasteur-9m22jv`, from `74024d7` (Task 3).
- **Pushed:** `74024d7..61ca42e`.
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`.
- **Scratch:** everything in `scratchpad/s3t4/`: the demo mutant runner `mut.py` and `mut.log`, the probe mutant's `probe-mutant.log`, the gate runner `gates.sh` and its logs in `gates/`, the build logs, the smoke scripts and screenshots in `smoke/` and `smoke/shots/`.
- **`analysis_options.yaml`:** none touched or committed. `git status` was clean before each commit and after every gate.
- **Not touched:** the planner's `lib/src/` painters, `service_view.dart`, `floor_plan_view.dart`, `planner_shell.dart`, `floor_plan_theme.dart` and their tests. No defect found in them (Findings).
- **Not written, as instructed:** the results note, STATUS, the roadmap row, the spec's Review section.

## Commits

| SHA | What |
|---|---|
| `a5c9fdc` | feat(demo): a Standard / POS look switch; `theme_colours_test`'s one named allowance |
| `28b10b3` | docs: the host guide's § 9 "Themes" and its probe |
| `accc153` | docs: the CHANGELOG's Unreleased gains Slice 3 |
| `61ca42e` | fix(demo): the POS look's veil keeps the paper's colour (found by the smoke check); one guide sentence |

## 1. Demo (`apps/restaurant_demo`)

### Files

- `lib/demo_theme.dart` (new):
  - `DemoLook { standard, pos }`.
  - `posColorScheme(Brightness)`: a hand-built `ColorScheme` of shadcn's zinc tokens, light and dark. The file header says the tokens are a **proposal**, shadcn's published palette, not a POS's real ones.
  - `kPosFloorPlanLight` / `kPosFloorPlanDark` and `posFloorPlanTheme(brightness)`. Their fields:
    - captions `TextStyle(fontFamily: 'Roboto', fontSize: 12, fontWeight: bold)`, fill opacity 0.8;
    - `groupFrameColor` the primary (zinc-900 / zinc-50); the chip follows the frame (S-7, `groupChipColor` left null); chip text Roboto w600; chip radius 6;
    - selection orange-600 on light paper, orange-400 on dark paper, the same in both themes (the colours are per paper);
    - `focusVeilOpacity` 0.75, the paper's colour kept (`61ca42e`);
    - `canvasBackground` the muted token (zinc-100 / zinc-800); `serviceBarHeight` 52.
  - `kPosViewOverride = FloorPlanTheme(selectionWidth: 3)`.
  - `posViewTheme(ambient)`: `ThemeData(colorScheme: posColorScheme(ambient.brightness), extensions: ambient.extensions.values)`.
- `lib/main.dart`:
  - `RestaurantDemo` holds `_look`. The app's `theme` and `darkTheme` are `ThemeData(colorSchemeSeed: teal, brightness: …, extensions: [if (pos) posFloorPlanTheme(brightness)])`, so the extension sits in the app's light and dark `ThemeData`. Under Standard the list is empty, which is equal to today's `ThemeData`.
  - `DemoHome` gains `look` and `onLook`.
  - The app bar gains a `Tooltip(Look)` around a `SegmentedButton<DemoLook>` (`look-toggle`, `look-standard`, `look-pos`).
  - The view is always wrapped in `Theme(data: _viewTheme(Theme.of(context)))`:
    - under POS, `posViewTheme(ambient)`, cached by the ambient's identity;
    - under Standard, the ambient itself.
    The tree keeps its shape because a view remounted on its controller within one frame throws (Task 1 finding 6).
  - The view passes `theme: look == pos ? kPosViewOverride : null`.
- `lib/demo_strings.dart`:
  - en: Look / Standard / POS
  - de: Aussehen / Standard / Kasse
  - tr: Görünüm / Standart / Kasa
- `packages/jet_cad_floor_plan/test/invariants/theme_colours_test.dart`: `kAllowedFiles` gains `../../apps/restaurant_demo/lib/demo_theme.dart`, a whole-file entry with a comment. This is the plan's one named allowance and the only existing test edited.

### Tests: `test/look_test.dart` (3 tests; demo total 57 → 60)

The fixture is the Salon sample, whose fitted camera is off identity and off origin, at 1600×1000, in both modes. Expected colours are the theme's tokens or are composited by the test.

**DL1 (light platform) and DL2 (dark platform)** each check:

- **Standard premises:**
  - no extension and no view theme at the view;
  - the bar is 44 px, in the seed's `surfaceContainer`;
  - the surround is the seed's `surface`;
  - the overlay is 2 px in the standard set's colour, with more than 200 outline pixels around 7;
  - (light) Bill is composited at 0.6 over White on more than 1000 pixels.
- **POS, design mode:**
  - at the view's element, `Theme.of(...).extension` equals `posFloorPlanTheme(brightness)` (the app's extension carried into the local `Theme`);
  - the colour scheme equals `posColorScheme`;
  - `FloorPlanView.theme` equals `FloorPlanTheme(selectionWidth: 3)`, and the extension sets no width (the merge);
  - the surround pixel is exactly `canvasBackground`;
  - `SelectionOverlayPainter.selectionStrokePixels` is 3 and `paper.selection` is the theme's colour for the paper. Under the dark theme the White page is on the dark canvas, so it is `selectionOnDark`;
  - the outline pixels in the theme's colour are more than 1.4 × the standard 2 px count, and no pixel of the standard colour is left.
- **POS, service mode:**
  - the bar is 52 px, and the canvas starts at its bottom;
  - the bar's pixel is exactly the hand-built scheme's `surfaceContainer` (the F-4 recipe reaching the chrome);
  - the surround is `canvasBackground`;
  - the selection is as in the design mode;
  - (light) Bill is at 0.6 × **0.8** (a literal, not read back) over White on more than 1000 pixels;
  - the resolved caption style is (12, bold, Roboto).
- **Standard again**, switched in the design: both modes' view regions are **byte-identical** to the first Standard shots, and the bar is 44 again.
- **Caption size:** zoomed ×3 on table 2, the caption's ink grows by at least 80 pixels from Standard to POS (4 glyphs of 12² against 11²: 92). The test font draws every glyph one em wide, so weight is not visible in pixels; it is checked in the resolved style (see the web check for real bold).

**DL3:** the switch's tooltip and labels in English, German and Turkish, and the switch working after a language change.

### Demo mutants

Run by `mut.py`: each edit is asserted to match once, the file is restored from a copy, and `md5sum -c` was OK afterwards.

| Mutant | Result | Red in |
|---|---|---|
| DM1: no view override under POS | red | DL1, DL2 |
| DM2: the local Theme drops the extensions | red | DL1, DL2, DL3 |
| DM3: the app theme without the extension | red | DL1, DL2, DL3 |
| DM4: no local Theme under POS | red | DL1, DL2 |
| DM5: the local Theme cached once (stale ambient from the switch's t = 0 frame) | red | DL1, DL2, DL3 |
| DM6: the light caption at 11 px | red | DL1 |
| DM7: the dark theme's two selection tokens swapped | **survived, equivalent** | none. The test reads the token for the paper; swapping is a token choice, not a wiring fault. A planner that picked the wrong set would be red. |
| DM8: Standard passes the view override | red | DL1, DL2 |
| DM9: the light fill opacity 1.0 | red | DL1 (after the 0.8 was pinned as a literal; it first survived because the test read the field back) |
| DM10: the dark `canvasBackground` dropped | red | DL2 |
| DM11: the light bar height dropped | red | DL1 |
| DM12: the Turkish tooltip in English | red | DL3 |
| DM13: the colour scan without the demo theme file | red | `theme_colours_test` M-DT-14 (and its mutants test) |

## 2. Host guide (`docs/host-guide.md`)

§ 9 "Themes" keeps its four lines and adds a section marked *Unreleased on `main`*. It covers:

- **A table of the sixteen fields by group:** what each reaches, by mode (both modes for the selection fields and `canvasBackground`), and what null is (today's value). Units are logical pixels on the screen; the margin is in plan millimetres.
- **One extension per `ThemeData`, light and dark,** with code blocks for `floorLookLight`, `floorLookDark`, `posLightTheme` and `posDarkTheme`, and the `theme:` / `darkTheme:` lines.
- **`FloorPlanView(theme:)`:** field by field over the extension where the view is; the styles merge by `TextStyle.merge`; null means the extension alone; the resolved look is compared by `==`, so an equal theme rebuilds no painter. The code block is `theme: const FloorPlanTheme(selectionWidth: 3)`.
- **The local-`Theme` recipe (F-4)** for the rest of the chrome, with blocks for `posColorScheme`, `floorTheme` and the `Expanded(Theme(data: floorTheme(...), child: FloorPlanView(`. The colours are named as shadcn's zinc, an example. Three bullets:
  - a local `Theme` replaces the whole `ThemeData`, so carry the extensions over;
  - the Export dialog follows the local `Theme` but never the view's `theme:` (S-12), and draws none of the look;
  - the screen that builds the local `Theme` rebuilds the view, and its overlay builder, on a theme switch.
- **Light and dark:**
  - the selection is chosen by the paper, so a light page in a dark theme takes `selectionOnDark`;
  - **`canvasBackground` does not decide the dark canvas; the theme's brightness does** (Task 2 review R-4);
  - a page-less plan on a light `canvasBackground` in a dark theme is drawn with dark ink.
- **Each field exactly:**
  - **The ink rule (S-6):** on the drawn colour over the paper; a chip's ink on the chip colour.
  - **Size and placement:** 11 px by default; below the number at the resolved size; skipped as before.
  - **Fonts (S-2):** today's default is the platform's font. Set `fontFamily: 'Roboto'` with `ensureFloorPlanFonts` and the pubspec entry. Only the regular face ships, and bold is emboldened from it (verified on the web, § 6). A family that is not loaded falls back.
  - **Defaults that follow another field (S-7):** the chip follows the frame; a group none of whose tables is in the focus is faded by the veil's opacity, and its chip veiled.
  - **The veil (S-9):** the colour's alpha is multiplied; otherwise it is the paper's colour at the opacity. A paper-coloured veil does not show over the paper, and another colour shows a tinted box per faded table (`61ca42e`).
  - **Widths (S-8):** the outline, a selected point's cross and the move preview's cross; the hover stays 1.5 px at 60 %; grips and snap marks keep the paper's colours.
  - **The bar (S-10):** the canvas starts under it; changed while shown, the plan moves with the canvas.
  - **The canvas:** a translucent colour is used as given, and the ink is chosen on its RGB.
  - **Range checks (S-5):** an `ArgumentError` naming the field, at build; the constructor is `const` and never throws.
  - **An animated switch:** values are interpolated and clamped between their ends; one-sided fields and a style with a one-sided `color` switch at halfway; an extension only in the new theme applies at once, one only in the old theme stays to the end; painters rebuild at most once per frame of the switch, never for a pan.
  - **Never stored, exported or printed (P-5).**
- **§ 3 and § 4:** § 3's `MaterialApp` block gains `theme:` / `darkTheme:` and a bullet pointing to § 9. § 4's view block gains `theme:`, and its parenthetical names it.

## 3. Host probe and its mutant

- `tool/ci/host_probe/lib/main.dart` holds every new block verbatim, taken from the formatted probe:
  - `floorLookLight` and `floorLookDark`;
  - `posLightTheme` and `posDarkTheme`, used by `PosApp`'s `MaterialApp`;
  - `posColorScheme` and `floorTheme`;
  - the view inside `Theme(data: floorTheme(Theme.of(context)))`, with `theme: const FloorPlanTheme(selectionWidth: 3)`.
- `check_guide`: "docs/host-guide.md: all 37 code blocks are in the host probe" (32 before, 5 new), exit 0.
- **The mutant:**
  - In the probe, `posDarkTheme`'s `extensions: const [floorLookDark]` was changed to `[floorLookLight]`, a plausible host slip.
  - `check_guide` printed "docs/host-guide.md: not in the host probe: dart: /// The floor plan's look in the POS's light theme: bold captions in the" and exited 1.
  - The probe was restored from a copy (`cmp` equal), and `check_guide` exited 0 again (`scratchpad/s3t4/probe-mutant.log`).

## 4. CHANGELOG (*Unreleased*)

- **The intro:**
  - names Slices 1 to 3;
  - says the look is never stored, so Slice 3 changes no stored format;
  - says that with no theme every pixel is 0.3.0's.
- **A bullet "The look":**
  - `FloorPlanTheme`, its sixteen fields by group, and what null is;
  - the per-paper selection and its hover;
  - `canvasBackground` not deciding the dark canvas;
  - the bar moving the canvas;
  - `copyWith`, `merge`, `lerp` (clamped; one-sided fields switch at halfway), `==`, `hashCode` and `toString`;
  - `FloorPlanView.theme`, applied field by field and through `TextStyle.merge`;
  - the `ArgumentError` with its ranges;
  - the local-`Theme` recipe and the Export dialog (which the view's `theme:` never reaches);
  - fonts;
  - read at rebuild, never stored, exported or printed.
- **For `jet_cad_2d_flutter`:**
  - `PaperPalette.withSelection` (the hover at 60 % of the alpha; `light.withSelection(light.selection) == light`);
  - `SelectionOverlayPainter.selectionStrokePixels` (default 2; asserted finite and above 0; repaints when it changes).
- **Known limits gain:** the demo's POS look has not been seen on a tablet or a terminal, and its colours are a proposal.

## 5. Gates (real runs; logs in `scratchpad/s3t4/gates/`)

Every gate below ran at `accc153`. `61ca42e` changes only two lines of `demo_theme.dart` and one guide sentence. After it, the demo, `check_guide` and both probes were run again (rows marked †).

| Gate | Result |
|---|---|
| planner `flutter test --enable-vmservice --file-reporter json` | "04:56 +1679: All tests passed!", exit 0 |
| planner comparison (`expect_failures.dart --package packages/jet_cad_floor_plan --root packages/jet_cad_floor_plan`) | "packages/jet_cad_floor_plan: 1679 tests; the standing failures and skips, exactly", exit 0 |
| planner analyze / format | "No issues found!" / "Formatted 264 files (0 changed)" |
| demo test / analyze / format | "+60: All tests passed!" / no issues / 8 files, 0 changed. † At `61ca42e`: "+60: All tests passed!", no issues, 0 changed. |
| floor planner test / analyze / format | "+212: All tests passed!" / no issues / 47 files, 0 changed |
| restaurant symbols test / analyze / format | "+97: All tests passed!" / no issues / 15 files, 0 changed |
| engine `dart test` | "+1256 -2" (exit 1, the standing two). Comparison: "packages/jet_cad_2d: 1258 tests; the standing failures and skips, exactly", exit 0. `dart analyze --fatal-infos`: no issues. Format: 170 files, 0 changed. |
| `jet_cad_2d_flutter` `flutter test` | "+1382 ~1 -7" (exit 1, the standing seven and one skip). Comparison: "1390 tests; … exactly", exit 0. Analyze: no issues. Format: 225 files, 0 changed. |
| `jet_cad_2d_gpu` | "+20: All tests passed!". Comparison: "20 tests; … exactly". Analyze: no issues. Format: 10 files, 0 changed. |
| `tool/ci` | `dart test` "+63: All tests passed!". `dart analyze --fatal-infos lib test expect_failures.dart check_guide.dart check_host_lock.dart`: no issues. Format (CI's list, with `host_probe/lib`): 11 files, 0 changed. `check_guide`: all 37 code blocks, exit 0 (†, again at `61ca42e`). |
| host probe `tool/ci/host_probe.sh file:///home/user/jet-cad <full sha>` | At `accc153678cc…` and † at `61ca42ecf9cc8da07341ca8914ebc685e1deae5f`: exit 0, analyze "No issues found!", "✓ Built build/web", "host probe: no GPU renderer, no build hook; build/web is 42M". The lock has 40 packages, none of them `flutter_scene`, `flutter_gpu`, `flutter_gpu_shaders`, `scene` or `jet_cad_2d_gpu`. |
| `tool/ci/old_host_probe.sh v0.3.0` | "No issues found!", "old host probe: v0.3.0's main.dart analyses against accc153…" and † against `61ca42e…`, exit 0. `main.dart` restored, tree clean. |

The planner count is 1679, unchanged from Task 3: the only planner test touched is the allowance line in `theme_colours_test`.

### Web builds (`rm -rf build && flutter build web --release`)

| App | Result | `build/web` | `main.dart.js` | `assets/packages` | `cad.shaderbundle` in main.dart.js |
|---|---|---|---|---|---|
| `apps/restaurant_demo` (at `61ca42e`'s tree) | "✓ Built build/web" | 42M | 3,752,103 B (Slice 2: 3,738,446) | jet_cad_floor_plan, jet_cad_restaurant_symbols (no flutter_scene) | 0 |
| `apps/floor_planner` | "✓ Built build/web" | 42M | 3,590,019 B (Slice 2: 3,589,709) | jet_cad_floor_plan, jet_cad_restaurant_symbols (no flutter_scene) | 0 |

## 6. Web smoke check

**Setup:**
- Headless Chromium through Playwright (`/opt/node-tools/node_modules/playwright`, `PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers`), viewport 1600×1000, `locale: 'en-US'`.
- One run with `colorScheme: 'light'` and one with `'dark'`.
- CanvasKit was served from the build's own copy.
- **The baseline:** the demo was also built at `74024d7` (Task 3, before the switch) in a temporary worktree (since removed) and run through the same Standard steps.
- Script: `smoke/smoke.js`. Screenshots: `smoke/shots/{new,base}-{light,dark}-*.png`.

**Steps (the Salon):**
1. Design.
2. Service, then the following by the demo's own controls (number field, status buttons, the service bar's Merge, the zone tab, the switch, Fit):
   - Bill on 2 and 6, Eating on 4;
   - G1 = {8, 9} and G2 = {5, 6};
   - zone B with "Fade the others", fitted;
   - 7 selected.
3. Design.
4. POS, in the design mode.
5. Service.
6. Random statuses.
7. Design, then Standard.
8. Service.

**Output:** "groups line: G1: 8+9, G2: 5+6", and "console errors: []" for the new build light and dark and for the baseline light and dark.

**Standard is today's, in pixels.** ImageMagick `compare -metric AE` over the view region (x < 1300, y ≥ 56) of the new build against the `74024d7` build gave **0 differing pixels** for every Standard shot (design, service with everything set, design with 7 selected), light and dark. "Standard again" in the design is 0 pixels from the first. (The service's "again" differs only because Random statuses ran in between.)

**What the POS look showed** (pixels sampled from the screenshots):

| | light | dark |
|---|---|---|
| Service bar | taller (canvas starts at y 108 against 100), `#F4F4F5` (zinc-100, the hand-built `surfaceContainer`; Standard `#E9EFED`) | `#18181B` (Standard `#1A2120`) |
| Surround (service) | `#F4F4F5` = `canvasBackground` (Standard `#F4FBF8`, the seed's surface) | `#27272A` (Standard `#0E1513`) |
| Surround (design, below the sheet) | `#F4F4F5` (Standard `#F4FBF8`); the editor's panels and toolbar in the zinc scheme (`#FAFAFA` / `#F4F4F5`) | `#27272A`; panels `#18181B` |
| Selection on 7, both modes | `#EA580C` (orange-600), visibly heavier at 3 px (Standard `#5693EE`-ish blue anti-aliased, 2 px) | `#FB923C` (orange-400, the dark canvas's set) |
| Group frame G2 (straddles the focus) | near-black (zinc-900, `#404042` at an anti-aliased edge; Standard violet `#9160D9`) | near-white (`#D4D4D5`; Standard `#A78AD9`) |
| Chip "5+6" | `#18181B` with white text (the chip follows the frame); rounder corners | `#FAFAFA` with dark text |
| G1 {8, 9} outside the focus | the frame faded to grey, its chip veiled | the same, on dark |
| Veil over 1–5 and 8–11 | the drawing faded more than Standard (0.75); after `61ca42e` paper-coloured, so no box shows | the same on the dark canvas |
| Bill on 6 | fill dimmed (`#F3A09E` against Standard `#EF8886`); caption **bold** and slightly larger, dark ink | fill `#7E2B2B` against `#952E2E`; bold white caption |
| Random statuses | every caption bold; fills dimmed; captions inked by the dimmed fill | the same |
| Standard again | design 0 px from the first Standard design | the same |

So the bold caption, in Roboto Regular emboldened by the engine, is real on CanvasKit (the guide's sentence).

**Before `61ca42e`** the POS look set `focusVeilColor` to the muted token. The screenshots then showed a light-grey box (light) or a black box (dark) over each faded table's bounds. That is why the demo now keeps the paper's colour and the guide says so (finding 1).

## Findings

1. **A veil colour other than the paper's draws a box per faded table.** The veil fills each faded table's box, so with `focusVeilColor` unlike the paper the boxes show (seen on White and on the dark canvas). This behaves as S-9 specifies: it is not a defect in Task 3's code. The demo now keeps the paper's colour (`61ca42e`), and the guide's veil bullet says what a host will see.
2. **Changing the bar height in the service moves the plan, and switching back does not restore it** (S-10 as ruled; not a defect). Sequence:
   - Standard service, then design;
   - POS in the design, then service: R-13 keeps the plan's global place with the 52 px bar;
   - Standard while in the service: the canvas grows up by 8 px and the plan moves with it.

   The net effect is the plan 8 px higher than at the start. DL1 and DL2 switch the look back in the design so that today's pixels compare exactly; their comment says why. A host that switches looks during service sees this shift; worth a line for the review or Slice 4's C-1.
3. **An app-level theme switch reaches the view only after its animation's first ticks.** The frame after the switch is `t = 0` (the old `ThemeData`, from `Tween.transform`), so a local `Theme` built from it has no extension yet. The demo's cache is keyed by the ambient's identity, so it follows the next frames; DM5 (cache once) is red. The demo tests pump past 200 ms. No guide change: hosts rebuilding from `Theme.of` each build get this for free.
4. **The recipe's local `ThemeData(colorScheme: …)` drops the app's other theme settings** (typography, component themes). `copyWith(colorScheme:)` would keep them but would not re-derive the scheme-derived component colours. The guide shows the constructor form and the carried extensions; a host with heavy component theming may want to carry more. I left it as is.
5. **DM7 is an equivalent mutant**, as the table above says.
6. **No defect found** in Tasks 1 to 3's files. The demo, the probe and the smoke check exercise them, and everything they showed matches T-1 to T-4 and S-2 to S-12.
7. **For the human:**
   - a look at the POS look on a tablet and a terminal;
   - a native read of the German "Aussehen / Kasse" and the Turkish "Görünüm / Standart / Kasa". "Kasse" and "Kasa" were chosen over "POS", which in Turkish means the card terminal.
