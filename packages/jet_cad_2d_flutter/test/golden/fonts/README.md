# Why a font lives in the test tree

`flutter_test` renders every string in **Ahem** unless a real font is loaded:
each glyph becomes one solid box filling the em. That is enough to see
justification, rotation and shear, and it is *structurally* unable to show the
one thing the text ladder's fifth rung exists to check — a mirrored label has
to read backwards, and a mirrored box is a box.

So `text_ladder_golden_test.dart` loads this file under the family name
`Roboto`, which is what `DraftDocument`'s Standard text style asks for.

**Vendored rather than read out of the Flutter SDK on the fly.** A golden is a
byte comparison, and `bin/cache/artifacts/material_fonts/Roboto-Regular.ttf`
is a different file in a different SDK release; reading it from `FLUTTER_ROOT`
would make every golden here expire on the next `flutter upgrade` for a reason
that has nothing to do with this code.

- Source: `flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf`,
  Flutter 3.27.3
- SHA-256: `79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95`
- Licence: Apache 2.0, `Roboto_LICENSE.txt` beside it, copied unmodified
