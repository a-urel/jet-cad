# Changelog

## Unreleased

- `SelectTool.moveAdjuster` (`MoveAdjuster`, null by default): a generic seam
  for a body move drag. It is told when a drag of a set begins (`begin`) and
  ends (`end`); on every retarget, after the snap chain and before the move,
  `adjust` may replace the target point (it gets the raw point, the drag's
  base, the ortho base while Shift pins an axis, whether the chain's point
  came from object snap, the pointer kind and Alt); it paints into the
  tool's overlay above the selection preview (`paint`); `suppress` tells it an
  attachment replaced the event's move; its `changes` listenable makes the
  tool re-target from the last screen point. The tool keeps the last pointer
  kind and Alt state for camera-driven re-targets. With no adjuster the tool
  behaves, and allocates, exactly as before.
- `PaperPalette.guide` (an optional constructor argument, null by default),
  `guideColor` (the effective colour: `guide`, else the built-in magenta for
  the paper, `lightGuide` `0xFFE0218A` on a light paper, `darkGuide`
  `0xFFFF5CB0` on a dark one) and `withGuide`. `==`, `hashCode` and the
  copies carry the field, so existing callers compile unchanged. It is the
  alignment guides' colour, distinct from `preview` (the move's base-to-target
  line).
- Release note: `jet_cad_2d_plan` depends on `jet_cad_2d_flutter: ^0.7.3` and
  its alignment guides use this seam and the palette colour, so publish this
  package before the plan library's floor is raised to it.

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
