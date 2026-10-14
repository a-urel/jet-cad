# The plan library's font

`Roboto-Regular.ttf` (in `lib/fonts/`, so a host can also declare the bare
family from it: `packages/jet_cad_2d_plan/fonts/Roboto-Regular.ttf`) is the
family `Roboto` that `DraftDocument`'s Standard text style asks for;
`ensurePlanFonts` registers it (spec P5, ported from `jet_cad_floor_plan`).
The screen draws text in it, and the PDF export embeds the same bytes.

- Source: `packages/jet_cad_floor_plan/lib/fonts/Roboto-Regular.ttf`, itself
  a copy of `packages/jet_cad_2d_flutter/test/golden/fonts/Roboto-Regular.ttf`
  (Flutter 3.27.3's `bin/cache/artifacts/material_fonts/Roboto-Regular.ttf`)
- SHA-256: `79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95`
- Licence: Apache 2.0, `Roboto_LICENSE.txt` beside this file (registered with
  `LicenseRegistry` under `Roboto` by `registerFontLicences`)
- Copied unmodified, 2026-10-14, sub-project 2a Task 9

`test/fonts/plan_assets_test.dart` asserts that the font equals the Flutter
layer's golden copy byte for byte.
