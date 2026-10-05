# Dark canvas — decision note

**Status:** draft for approval. This is a short decision note, not a full
spec: the human chose the fast process (one note, one implementation, one
independent review, screenshots before merge). The `CLAUDE.md` rules, the
named-mutant rule and the "every task ends green" gate still apply.

**Why.** The dark theme (spec 2026-10-04, D4) darkened the UI and the canvas
frame, but kept the sheet in the document's paper colour. So on a White page
the drawing stayed a white sheet inside a dark UI. The human wanted the
drawing itself dark, as in AutoCAD.

## Decisions (the human's answers, 2026-10-05)

- **K1. Display paper.**
  - **Dark theme, light document paper** (`foregroundFor(page.background) ==
    0x000000`: White, Ivory, Grey): the sheet is shown in
    `kDarkCanvasPaper = 0xFF1E1F22`.
  - **Dark theme, dark document paper** (Blueprint or any dark custom paper):
    unchanged, so the page's own colour is shown.
  - **Light theme:** unchanged everywhere.
  - **No page:** unchanged, so the theme surface is the paper.
- **K2. One display paper drives everything that keys on the paper.** In
  `PlannerShell` and `ServiceView`, `_paperArgb()` returns the display paper.
  The following follow it with no further change:
  - the ACI 7 ink;
  - `PaperPalette.forPaper`, so the dark overlay set is used;
  - the status caption;
  - the table group painter.

  `PageChromePainter` gains `sheetArgb` (`int?`). Null means
  `page.background`, which is today's behaviour. When set, it fills the sheet.
  `PlannerView` passes it, and `shouldRepaint` compares it.
- **K3. Fixed drawing colours are re-toned on screen.** It is a display-only
  `StyleResolver` wrapper, `DarkCanvasStyleResolver` in `jet_cad_2d_flutter`.
  - **The inner resolver** is `DocumentStyleResolver(doc, foreground:
    0x000000)`, which gives the drawing as it would be on white paper.
  - **The rule.** The wrapper re-tones each resolved RGB. Alpha, lineweight
    and linetype are untouched.
    - **Target lightness.** Find the OKLab lightness at which the colour has
      the same WCAG contrast against the display paper as the original has
      against white. Find it by bisection, keeping hue.
    - **Gamut.** Bring the result into sRGB by reducing chroma, not by
      clipping.
    - **Neutral colours** (chroma near 0) take that lightness exactly, so
      they may get darker.
    - **Coloured colours** only ever get lighter:
      `max(L, target)`.
    - **Blend.** The two cases blend smoothly by chroma:
      `w = clamp(1 − C/0.08)`.
  - **Expected results**, from a prototype of the rule (the contrast is
    against `#1E1F22` afterwards and against white before):

    | Source | Shown as | Contrast now | Contrast on white |
    |---|---|---|---|
    | black wall `000000` | white | 16.5 | 21 (the maximum) |
    | ACI 7 | white (via black) | 16.5 | 21 |
    | furniture `8A6D3B` | light brown ≈ `A48754` | 4.8 | 4.9 |
    | floor finish `BBBBBB` | dark grey ≈ `4D4D4D` | 1.9 | 1.9 |
    | ACI 5 blue | light blue | 8.6 | 8.6 |
    | ACI 1 red, ACI 2 yellow, ACI 3 green | unchanged | | |
    | `TrueColor(0xFFFFFF)` mask | the paper colour | | |

    The white mask shows as the paper colour, as it does on white paper.
  - **Allocation.** Results are cached in a `Map<int, int>` keyed on RGB. A
    colour is computed once, the first time it is seen. In steady state, each
    entity costs one map lookup and nothing is allocated, beyond the
    `ResolvedStyle` that `styleFor` already returns.
  - **Lifetime.** The wrapper is built and replaced where the resolver is
    replaced today. The key is (foreground, display paper), so the tile cache
    invalidates through the existing `old.painter != painter` path.
  - **Layer panel.** Its ACI 7 swatch keeps the theme's foreground, which is
    UI and not canvas.
- **K4. Output is unchanged.** PDF, PNG and print keep their own white-paper
  resolver. The document, the schema and the saved file are untouched. The
  theme is never saved.

## Tests and named mutants

The fixtures use an off-origin, non-unit camera and both themes. They cover
White and Blueprint pages and a page-less view, and use non-default
TrueColors.

- **M-DC-1.** The sheet fill ignores `sheetArgb`. Test: the dark theme on
  White, checking the sheet pixel and the recording-canvas paint.
- **M-DC-2.** The display paper is applied to dark papers too. Test: dark
  theme on Blueprint, where the sheet stays Blueprint.
- **M-DC-3.** `_paperArgb()` returns `page.background`. Test: the ink and
  `PaperPalette` are the dark set on White in the dark theme.
- **M-DC-4.** The wrapper is not installed. Test: a black wall pixel is
  light.
- **M-DC-5.** Neutral colours use `max(L, target)`. Test: `BBBBBB` becomes
  darker than the source.
- **M-DC-6.** Coloured colours take the target exactly. Test: ACI 2 yellow
  stays `FFFF00`.
- **M-DC-7.** The contrast target is 1:1 or a constant. Test: the contrast
  table above, within ±0.1.
- **M-DC-8.** The cache is skipped. Test: the compute counter stays at 0
  over 10 steady frames, and the allocation invariants pass unedited.
- **M-DC-9.** The export uses the display resolver. Test: an export in the
  dark theme is pixel-identical to the same export in the light theme.
- **M-DC-10.** The light theme is not passed through. Test: the existing
  light-theme suites pass unedited.

## Exit

- **Gates.** Every gate is green.
- **Web builds.** `flutter build web --release` succeeds for both apps.
- **Chromium screenshots** with `colorScheme: 'dark'`:
  - the planner on White;
  - the planner on Blueprint;
  - the service view with statuses and a group.
- **Review.** One independent review.
- **The human's look** at those screenshots comes before the merge.
- **Results note:** `docs/superpowers/notes/2026-10-05-dark-canvas-results.md`.

## Amended at execution

Approved by the human ("Onaylıyorum, başla", 2026-10-05). The review
findings (see the results note) changed three details of K3:

- **The blend constants.** The blend `w = clamp(1 − C/0.08)` became a ramp
  from `kDarkCanvasNeutralChroma = 0.09` (fully neutral: the exact contrast
  mirror) to `kDarkCanvasColouredChroma = 0.15` (fully coloured: never
  darkened). Under the old constant, pale tints (chroma 0.03–0.09) were
  mostly treated as coloured and kept their lightness: `e0ffe0` reached
  contrast 6.8 on the dark sheet, against 1.07 on white. That went against
  K3's intent that a subtle fill stays subtle. Every saturated ACI colour
  (chroma ≥ 0.155) still stays exactly.
- **The caches.** The resolver keeps a `Map<ResolvedStyle, ResolvedStyle>`
  so a steady frame returns the kept object and allocates nothing. Under it
  sits the `Map<int, int>` of computed colours that K3 names, so one RGB is
  computed once, however many styles carry it.
- **White.** Pure white shows as the display paper itself, as K3's table
  promises. The mirror alone gave the neutral `#202020`, a faint seam
  against the paper.
