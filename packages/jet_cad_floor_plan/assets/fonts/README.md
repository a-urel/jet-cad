# The app's font

`Roboto-Regular.ttf` is the family `Roboto` the app declares in
`pubspec.yaml`, which is what `DraftDocument`'s Standard text style asks for.
The screen draws text in it, and the PDF export embeds the same bytes, so the
screen, the text golden and the PDF use one font (spec 13 D7).

- Source: `packages/jet_cad_2d_flutter/test/golden/fonts/Roboto-Regular.ttf`,
  which came from Flutter 3.27.3's
  `bin/cache/artifacts/material_fonts/Roboto-Regular.ttf`
- SHA-256: `79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95`
- Licence: Apache 2.0, `Roboto_LICENSE.txt` beside it (registered with
  `LicenseRegistry` under `Roboto` at start-up)
- Copied unmodified, 2026-10-01, plan 13 Task 7

`test/export/export_font_test.dart` asserts that both files equal the
vendored ones byte for byte.
