# Changelog

## 0.7.3

- `SelectTool` passes the dragged selection as `resolveDragPoint`'s new
  `exclude` while a move drag lives: a dragged object no longer snaps to
  its own pre-drag geometry.
- Depends on `jet_cad_2d: ^0.7.3`.

## 0.7.2

Screenshots and documentation, and one small change in the rulers. Plans
are stored as in 0.7.1.

- `RulerFrame` passes the ambient `DefaultTextStyle`'s font family to the
  rulers' labels and to the corner's unit symbol, so the rulers follow the
  host's text font. With no ambient family the labels are drawn exactly as
  in 0.7.1.
- Screenshots, in the pub.dev gallery and in the README: the canvas in
  light and dark, the selection's grips, the crossing band and the symbol
  gallery.
- The README has a package table and links the host guide.
- Funding links (GitHub Sponsors, Buy Me a Coffee) in the pubspec.
- Depends on `jet_cad_2d: ^0.7.2`.

## 0.7.1

The first release on pub.dev. The code is jet-cad 0.7.0's render package
(git tag `v0.7.0`); what changed is how it is packaged: its own LICENSE
(Apache 2.0), a README written for pub.dev, a runnable example, `sdk:
^3.6.0`, and its dependency on `jet_cad_2d` from pub.dev (`^0.7.1`).

From this release on, `jet_cad_2d_flutter` has its own version on pub.dev
and its own git tags (`jet_cad_2d_flutter-vX.Y.Z`). Before it, the package
was released with the other jet-cad packages under one version; that
history is in the repository's
[CHANGELOG.md](https://github.com/a-urel/jet-cad/blob/main/CHANGELOG.md).
