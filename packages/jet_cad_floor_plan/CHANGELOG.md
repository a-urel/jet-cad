# Changelog

## 0.7.2

Two exports, screenshots and documentation. Plans are stored as in 0.7.1
(schema 10).

- The barrel exports `SymbolLibraryState` (`SymbolLibraryLoading`,
  `SymbolLibraryReady`, `SymbolLibraryFailed`) and `TableNumberProblem`:
  a host that implements `FloorPlanStrings` names `TableNumberProblem`, and a
  host that watches its `SymbolLibraryLoader` names its states, without
  importing `editor.dart`.
- The editor's rulers use the app's font, through the renderer's
  `RulerFrame` change in `jet_cad_2d_flutter` 0.7.2.
- Screenshots, in the pub.dev gallery and in the README: the editor in
  light and dark, and the service view (statuses and a group, a POS theme
  with a zone in focus, a rubber band, table colours).
- The README has a package table.
- Funding links (GitHub Sponsors, Buy Me a Coffee) in the pubspec.
- Depends on `jet_cad_2d: ^0.7.2` and `jet_cad_2d_flutter: ^0.7.2`.

## 0.7.1

The first release on pub.dev. The code is jet-cad 0.7.0's planner (git
tag `v0.7.0`); what changed is how it is packaged: its own LICENSE (Apache
2.0), a README and a runnable example, `sdk: ^3.6.0`, and its dependencies
on `jet_cad_2d` and `jet_cad_2d_flutter` from pub.dev (`^0.7.1`). Plans
are stored as in 0.7.0 (schema 10): a plan saved by either release opens in the other.

**Moving a host from git to pub.dev:**

1. Replace the git dependencies on `jet_cad_floor_plan` and
   `jet_cad_restaurant_symbols` with `jet_cad_floor_plan: ^0.7.1`.
2. Remove the import of `jet_cad_restaurant_symbols`. Copy its library
   and names into your app as the host guide's "The restaurant symbols"
   says, and give the loader your own `SymbolLibrarySource` in place of
   `restaurantSymbolSource`.
3. Keep the source's name `restaurant`, and never load your copy together
   with the package's source: the same keys in two sources make the
   loader fail.

From this release on, `jet_cad_floor_plan` has its own version on pub.dev
and its own git tags (`jet_cad_floor_plan-vX.Y.Z`). Before it, the package
was released with the other jet-cad packages under one version; that
history is in the repository's
[CHANGELOG.md](https://github.com/a-urel/jet-cad/blob/main/CHANGELOG.md).
