# Task 1 review: the palettes (D2, D3, D6c constants)

**Reviewer:** independent, detached worktree `/home/user/jet-cad/.worktrees/dark-review` at `23314be`.
**Diff:** `git diff 91d88e4..23314be`, 3 files, +528 lines:
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`: one barrel export added
- `packages/jet_cad_2d_flutter/lib/src/canvas_palette.dart`: new, 206 lines
- `packages/jet_cad_2d_flutter/test/canvas_palette_test.dart`: new, 321 lines

## Verdict: **Approved**

There are no blocking, major or minor findings. Both proposed rulings are accepted (see below). There are three notes.

## 1. Implementation against the spec and plan

Every item was checked line by line against spec D2, D3 and D6c and plan Task 1.

- **`ChromePalette`.**
  - It has the 4 fields D2 names.
  - `light` matches F-2 and `dark` matches the D2 table exactly (`canvas_palette.dart:34-47`).
  - `of(Brightness)` is at `:50-51`.
  - It is `@immutable` with a const constructor. `==` and `hashCode` cover all 4 fields.
- **`PaperPalette`.**
  - It has the 12 fields D3 names.
  - `light` matches F-2 `selection_style.dart` and `dark` matches the D3 table exactly (`:127-156`). I checked each of the 24 literals by eye against the spec table.
  - The pairings hold in both sets.
  - `==` and `hashCode` cover all 12 fields.
- **`forPaper`** (`:164-165`) is literally `foregroundFor(argb & 0xFFFFFF) == 0xFFFFFF ? dark : light`, as D3 writes it. `foregroundFor` is imported from `package:jet_cad_2d`, not re-implemented.
- **Caption colours.** `kStatusCaptionOnLight = Color(0xFF202020)` and `kStatusCaptionOnDark = Color(0xFFFFFFFF)` are in `canvas_palette.dart`, as D6c requires (`:202, :206`).
- **No global mutable state** (invariant 4): there are only `static const` instances.
- **Nothing consumes the palettes yet.**
  - `grep` finds `ChromePalette`, `PaperPalette` and `kStatusCaptionOn*` only in the new file and its test.
  - The painters, tools, goldens and light-theme pixels are untouched, so invariant 2 holds trivially.
  - The barrel export causes no name clash: the planner, symbols and both apps analyze clean.
- **Plan deviation:** the old constants are kept as literals, not aliases. This is R-C1-1, ruled on below.

## 2. Gates (re-run by me, `CI=true`, Flutter in `/home/user/flutter/bin`)

| Package | `flutter test` | analyze | format | Implementer |
|---|---|---|---|---|
| render `jet_cad_2d_flutter` | `+1273 ~1 -7: Some tests failed` | No issues found! | 216 files (0 changed) | same |
| planner `jet_cad_floor_plan` | `+1167: All tests passed!` | No issues found! | 193 files (0 changed) | same |
| `jet_cad_restaurant_symbols` | `+94: All tests passed!` | No issues found! | 13 files (0 changed) | same |
| app `floor_planner` | `+201: All tests passed!` | No issues found! | 44 files (0 changed) | same |
| demo `restaurant_demo` | `+17: All tests passed!` | No issues found! | 3 files (0 changed) | same |

- **The render package's 7 failures** are exactly the standing text-ladder goldens: `text_ladder_golden_test.dart` rungs 1-5 and `text_lod_ladder_golden_test.dart` rungs 1-2, all on `RenderBackend.canvas`.
- **The count change** is +1273 against the branch point's +1240, which is the 33 new tests. `canvas_palette_test` appears in the log as 33 test lines.

Logs are in `scratchpad/review1/` (`gate-render-*.log`, `test-*.log`, `analyze-*.log`, `format-*.log`).

## 3. Mutants (re-fired by me)

**Method:**
1. Back up `canvas_palette.dart` to scratch.
2. Apply an exact-string mutation (asserted unique).
3. Run `CI=true flutter test test/canvas_palette_test.dart`.
4. Copy the backup back and run `diff` (exit 0 every time).

The script is `scratchpad/review1/mut.py` and the logs are `mut-<id>.log`. `git status` afterwards shows only the pub-get rewrite of `packages/jet_cad/analysis_options.yaml`.

| ID | Mutation | Result | Red tests |
|---|---|---|---|
| M-DT-3 | `forPaper` → `((argb >> 8) & 0xFF) < 128 ? dark : light` | **red** | the swatches-and-greys test; the wide-sweep test |
| M-DT-1 | `forPaper` inverted (`? light : dark`) | **red** | same two |
| M-DT-19 | light `pageBreak` `0xFF3366CC` → `0xFF3366CD` | **red** | `PaperPalette.light, field by field`; the transitional old-constants test |
| M-DT-20 | dark `gripMove` → `0xFF7A3FD1` (today's light value) | **red** | `gripMove has 3:1 on 0xff1f3a5f` and `on 0xff303030`; `PaperPalette.dark, field by field` |
| value equality | `gripHot` clause dropped from `PaperPalette.==` | **red** | `PaperPalette compares by value, every field` |
| MASK (R-C1-2) | `foregroundFor(argb)` with no `& 0xFFFFFF` | survives | none (`+33: All tests passed!`): equivalent, see ruling |
| O1 (own) | mask `0xFFFF`, which drops the red channel | **red** | both M-DT-3 tests (the saturated red primary catches it) |
| O2 (own) | `other.windowBand == selection` in `PaperPalette.==`, a swap between two fields that are equal in both sets | **red** | `PaperPalette compares by value, every field` ("differs in windowBand"). I expected this one to survive; the per-field perturbation catches it. |
| O3 (own) | dark `hover` alpha `0x99` → `0xFF` (a translucent field, outside the contrast table) | **red** | `PaperPalette.dark, field by field` |
| O4 (own) | `kStatusCaptionOnDark` → `Color(0x00FFFFFF)`, the transparent `0xRRGGBB` trap D6c warns about | **red** | `the D6c caption colours` |

The implementer's table lists other mutants: EQ-chrome, HASH-chrome, OF-swap, OLD-const and CAPTION. I did not re-fire them, because my set covers the same lines or riskier ones. Every named mutant for Task 1 (M-DT-3, M-DT-19, M-DT-20, value equality) is killed. M-DT-1 is killed here too, although it is not named for Task 1.

## 4. Degenerate fixtures

- **M-DT-3** covers the four swatches, `0x757575` and `0x767676`, plus a sweep:
  - all 256 greys;
  - 9 saturated colours, which separate luminance from byte sums;
  - 2 translucent values.

  The sweep asserts that both sets are hit more than 50 times. The swatch test has a hand-written oracle and also checks that oracle against `foregroundFor`, so neither side can drift alone. Nothing here is White-only.
- **The M-DT-20 oracle is independent.** The test has its own `relativeLuminance` and `contrast`. A sanity test checks the oracle against the spec's measured 5.31, 7.46 and 8.24, plus 21.0, so an oracle that passes everything would go red. The 9-field opaque list also asserts alpha `0xFF`, so a field made translucent fails rather than silently dropping out of the bar.
- **The equality tests** copy the **dark** palette, not the default, and perturb each field in turn.
- **No camera or theme fixtures** are involved yet: this is a pure value test.

## 5. Untouched-by-construction checks

`git diff 91d88e4..23314be --stat` on these paths is empty:
- `*analysis_options.yaml`
- `packages/jet_cad_2d` (the engine)
- `*golden*`
- `*invariants*`
- `selection_overlay_test.dart` (the Paint-identity tests)

So no analysis_options file is committed, the engine is untouched, and the allocation invariants, Paint-identity tests and goldens are unedited.

## Rulings

### R-C1-1: **Accepted**

The ruling keeps the old constants as literals, adds a transitional equality test, and has Task 3 delete both the constants and that test.

- **The constraint is real.** I verified it in a scratch file. `const int k = P.light.x;` gives `error - The property 'x' can't be accessed on the type 'P' in a constant expression - const_eval_property_access`.
- **`final` would break the build.** `ruler_painter.dart:134` and `:168` use `kRulerInk` inside `const TextStyle(...)`, so making the constants `final` would not compile.
- **The plan's intent is met.** The intent is that nothing else changes yet and the constants cannot drift from `.light`. The transitional test pins all 16 constants to the `.light` fields, and my M-DT-19 run shows it goes red on drift.
- **The other direction is worse.** Building `ChromePalette.light` and `PaperPalette.light` from the old constants would compile. But it would make `canvas_palette.dart` import the two files whose colours Task 3 deletes, and Task 3 would then have to edit the palette file. The implementer's choice leaves the palette file in its final form from Task 1.
- **Task 3 cannot forget the cleanup.** Task 3's removal of the constants breaks the compile of `canvas_palette_test.dart` until the transitional test is deleted.
- **Cost if wrong:** none at runtime.

**Ledger:** record that plan Task 1's "as aliases" is satisfied by literals plus the equality test. Task 3 must delete `the old chrome and selection constants equal the .light fields` along with the constants.

### R-C1-2: **Accepted**

The ruling is that the alpha-mask mutant is equivalent.

- **`foregroundFor` ignores the alpha byte by construction.** It reads only `(background >> 16|8|0) & 0xFF` (`packages/jet_cad_2d/lib/src/document/style_resolver.dart:29-37`). Removing `& 0xFFFFFF` therefore cannot change any result. The same holds under JS 32-bit bitwise semantics on web: the `& 0xFF` after the shift discards the sign extension.
- **My re-run matches:** `+33: All tests passed!`.
- **Keeping the mask is right.** It is the spec's literal formula, and it documents that the alpha is ignored.
- **The sweep still exercises translucent papers** (`0x001F3A5F`, `0x80FFFFFF`), so the dropped-mask mutant is covered behaviourally if `foregroundFor` ever starts reading alpha.
- **Cost if wrong:** nil.

## Notes (no action required for Task 1)

1. **Note: `hashCode` field-omission mutants survive.** Dropping one field from `Object.hash(...)` would not be caught. This is not a defect: the hash contract allows collisions, and `==` is fully covered.
2. **Note: the palettes have no `toString`.** A `same()` failure prints `Instance of 'PaperPalette'`, and the tests compensate with `reason:`. Task 2 and later may want a `toString` when painter `shouldRepaint` tests fail. It is not in the spec and is optional.
3. **Note: the extra tests are fine.** The implementer added tests beyond the plan list: the dark literals, the caption constants, the pairings, `of()` and the oracle sanity test. All are cheap and each has a killing mutant above or in the implementer's table.
