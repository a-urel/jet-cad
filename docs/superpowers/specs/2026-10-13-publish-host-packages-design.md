# Publishing the host packages on pub.dev — design

**Date:** 2026-10-13. **Status:** revision 1, written after the human
approved its three sections in chat; awaiting the human's review of this
file.

**Asked for by the human, 2026-10-13:** *"bence tümünü sırayla
yayınlayalım. restoran sembolleri de yayınlandıktan sonra restoran
yazılımı içinden pub.dev üzerinden kurarak kullanabilirim."* The restaurant
software is to install the planner from pub.dev instead of by git.

**Branch:** `feat/publish-host-packages`, cut by hand from `main` at
`d41e5f6` (the engine's publication merged at `1dc167d`). **Size:** M, one
plan. **Touched:** the pubspecs of `jet_cad_2d_flutter`,
`jet_cad_floor_plan`, `jet_cad_restaurant_symbols`; the two published
packages' LICENSE, README, CHANGELOG, example, `.pubignore` and doc
comments; CI (`publishable`, the host probe and its template); the host
guide §1; the root CHANGELOG; STATUS. **Release:** `jet_cad_2d_flutter`
0.7.1, then `jet_cad_floor_plan` 0.7.1, published by the human after
`jet_cad_2d` 0.7.1.

## Purpose

A host installs the floor planner with `dart pub add jet_cad_floor_plan`
and gets the render package and the engine with it, each from pub.dev at a
version that means something. The repository stops being the only way to
the planner; the git-and-SHA recipe of the host guide goes.

## Decisions taken in the brainstorm (the human, 2026-10-13)

1. **Publish in order:** `jet_cad_2d` → `jet_cad_2d_flutter` →
   `jet_cad_floor_plan` (*"tümünü sırayla yayınlayalım"*). The engine's
   step is done in its own branch (merged at `1dc167d`; record
   [2026-10-13-publish-jet-cad-2d.md](../notes/2026-10-13-publish-jet-cad-2d.md));
   this spec covers the next two. `jet_cad_2d_gpu` is not published.
2. **Apache 2.0 for every published package** (*"tümü için lisans apache
   2.0 olsun"*).
3. **The restaurant symbols: a fourth step, deferred** (a SWOT in chat;
   *"tamam yaz"*). Not published by this spec: a pub.dev release cannot be
   taken back, and the library's source name and entry keys become a
   contract once published. The restaurant software carries the library in
   its own assets meanwhile (D9).
4. **Each package its own version** (*"Her biri bağımsız"*): its own
   semver, CHANGELOG and tag; published only when it changes.
5. **pub.dev only for hosts** (*"Yalnız pub.dev"*): the host guide
   describes pub.dev alone; CI checks the commit under test through
   `dependency_overrides`.
6. **Approach A** (*"evet a"*): every dependency on a published package
   is a hosted constraint, in the repository as in the archive; no
   `path:` to a published package, no rewriting at publish time, no
   committed `pubspec_overrides.yaml`.
7. Sections 1 (the packages), 2 (CI and the probes) and 3 (the host guide
   and the release flow) approved as presented (*"onaylıyorum"*, three
   times).

## Facts (at `d41e5f6`)

- **F-1. Workspace resolution of a hosted constraint.** Measured in a
  throwaway worktree: with `jet_cad_2d_flutter`'s dependency changed to
  `jet_cad_2d: ^0.7.1` while 0.7.1 is not on pub.dev, `flutter pub get` at
  the root succeeds and `.dart_tool/package_config.json` resolves
  `jet_cad_2d` to `../packages/jet_cad_2d`. dart.dev's workspaces page:
  workspace packages depending on each other resolve to the local copy,
  regardless of source.
- **F-2. A dependent's dry run.** In the same worktree, `dart pub -C
  packages/jet_cad_2d_flutter publish --dry-run` raised one error (no
  LICENSE) and two warnings (a modified checked-in file, no CHANGELOG),
  and nothing about `jet_cad_2d` 0.7.1 being absent from pub.dev. Exit 65.
  The archive was 1005 KB, `test/` included. The server may still refuse
  an upload whose dependency it cannot resolve: the order of D10 stands.
- **F-3. Pub refuses `path:` dependencies in a published package.**
  `jet_cad_2d_flutter` and `jet_cad_floor_plan` depend on the engine (and
  the planner on the render package) by `path:`.
- **F-4. `jet_cad_2d_flutter`** at 0.7.0: `publish_to: none`, `sdk:
  ^3.5.0`, `flutter: ">=3.44.0"`, `repository:` the dead
  `ahmeturel/jet-cad`; dependencies `jet_cad_2d` (path), `meta`,
  `vector_math`, `pdf`. No LICENSE, no CHANGELOG; its README is a
  developer's note (rigs, golden commands). `lib/` 852 KB; `test/` 3.5 MB;
  `shaders/` (16 KB) read only by its own `test/gpu/` suites. Public
  libraries: `jet_cad_2d_flutter.dart` (59 exports) and
  `export_testing.dart` (a PDF reader for tests; imports only
  `dart:convert`, `dart:math`, `dart:typed_data`; used by the render
  package's tests, `apps/floor_planner`'s tests and one planner test).
- **F-5. `jet_cad_floor_plan`** at 0.7.0: `publish_to: none`, `sdk:
  ^3.5.0`, `flutter: ">=3.44.0"`, no `repository:`; its description cites
  spec slices. Dependencies `jet_cad_2d`, `jet_cad_2d_flutter` (path),
  `flutter_localizations`, `meta`, `pdf`, `printing`, `vector_math`.
  Assets: `assets/library/furniture.jetlib`, `lib/fonts/Roboto-Regular.ttf`
  and `assets/fonts/Roboto_LICENSE.txt` (Apache 2.0). No LICENSE, README
  or CHANGELOG. `lib/` 1.6 MB, `test/` 3.8 MB, `tool/` (the furniture
  library's generator). Public libraries: `jet_cad_floor_plan.dart` (the
  host API; it re-exports one render type, `SymbolThumbnails`),
  `editor.dart` (its header: *"Explicitly internal: a host embeds the
  planner through `jet_cad_floor_plan.dart`"*), `symbols.dart` (a symbol
  catalog's types and builder, pure Dart) and `symbol_sources.dart`.
- **F-6. The restaurant symbols at run time.** A host uses one value,
  `restaurantSymbolSource`: the name `'restaurant'`, a reader of
  `assets/restaurant.jetlib` (128 KB, the engine's JSON format, schema 10,
  generated by `tool/generate_restaurant_library.dart` from the package's
  catalog) and `restaurantSymbolNames` (German and Turkish, a 169-line
  constant). `SymbolLibrarySource` and `SymbolNames` are on the planner's
  barrel. Placing a symbol copies its definition into the plan
  (`symbol_placer.dart`, `definitionForEntry`), so saved plans do not need
  the library. The package depends on `jet_cad_2d` and
  `jet_cad_floor_plan` by `path:`.
- **F-7. Hosts import the planner only.** `apps/restaurant_demo` and the
  host probe import `jet_cad_floor_plan.dart` and
  `jet_cad_restaurant_symbols.dart`, nothing else of the repository.
- **F-8. The host probe.** `tool/ci/host_probe.sh <url> <sha>` writes the
  probe's pubspec from `pubspec.yaml.in` (the planner and the restaurant
  symbols by git at the SHA), resolves, runs `check_host_lock.dart` (no GPU
  renderer, no build hook), analyses and builds for the web.
  `old_host_probe.sh <tag>` swaps in the probe's `main.dart` as the tag had
  it and analyses it; CI runs it for `v0.3.0`, `v0.4.0`, `v0.5.1` and
  `v0.6.0` (the host embedding API spec's invariant 1). Every one of those
  `main.dart` files imports `jet_cad_restaurant_symbols`.
  `check_guide.dart` requires every code block of the host guide to be in
  the probe.
- **F-9. How often each package changed** (files under `lib/`, and the
  symbols' assets, per release):

  | Release | engine | render | planner | symbols |
  |---|---|---|---|---|
  | 0.1.0 → 0.2.0 | 3 | 13 | 15 | 1 |
  | 0.2.0 → 0.3.0 | 0 | 0 | 10 | 0 |
  | 0.3.0 → 0.4.0 | 3 | 11 | 36 | 1 |
  | 0.4.0 → 0.5.0 | 4 | 0 | 2 | 0 |
  | 0.5.0 → 0.5.1 | 0 | 0 | 7 | 0 |
  | 0.5.1 → 0.6.0 | 4 | 3 | 23 | 1 |
  | 0.6.0 → 0.7.0 | 0 | 3 | 4 | 0 |

- **F-10.** `jet_cad_2d_flutter` and `jet_cad_floor_plan` answer 404 on
  `pub.dev/api/packages/<name>` (2026-10-13): both names are free.

## Design

### D1. The dependency lines

Every dependency on `jet_cad_2d`, `jet_cad_2d_flutter` or
`jet_cad_floor_plan`, in every pubspec of the live line, is a hosted
constraint: `jet_cad_2d: ^0.7.1`, `jet_cad_2d_flutter: ^0.7.1`,
`jet_cad_floor_plan: ^0.7.1`. This covers the two packages to publish,
`jet_cad_restaurant_symbols`, `jet_cad_2d_gpu` and the apps. A dependency
on an unpublished package (`jet_cad_restaurant_symbols`,
`jet_cad_2d_gpu`) stays `path:`. The workspace resolves every one of them
to the local copy (F-1), so development, tests and the apps are unchanged.

A dependent raises its lower bound only when it needs a newer version
(`jet_cad_2d_flutter: ^0.7.2`); under 0.x, a minor bump of a dependency
(0.8.0) means a new constraint and a new release of every dependent.

### D2. `jet_cad_2d_flutter` 0.7.1

- `publish_to: none` removed; `version: 0.7.1`; `sdk: ^3.6.0` (the floor
  pub workspaces document; `flutter: ">=3.44.0"` stays and is what binds);
  `repository: https://github.com/a-urel/jet-cad`, `issue_tracker:`, and
  topics; a description of what the package is, without spec references.
- LICENSE: the root's, byte for byte.
- `.pubignore`, anchored: `/test/`, `/build/`, `/shaders/` (F-4: the
  shaders serve the package's own tests).
- README written for pub.dev: what it renders (`DraftCanvas`, the camera,
  rulers, the interaction layer, the PDF and PNG export), the smallest
  widget that shows a `DraftDocument`, what is API (the barrel; nothing
  under `src/`; `export_testing.dart` is a test instrument, not API), the
  0.x rule. No screenshots (the human, for the engine: *"görselsiz
  kalsın"*).
- CHANGELOG from 0.7.1: 0.7.0's code, packaged; the history before it in
  the root CHANGELOG.
- `example/`: a small Flutter app that shows a document in a
  `DraftCanvas`; a widget test pumps it and asserts what it draws, with a
  named mutant that turns it red (CLAUDE.md's testing bar).
- `dart doc` warnings brought to zero.

### D3. `jet_cad_floor_plan` 0.7.1

The same as D2, with:

- dependencies `jet_cad_2d: ^0.7.1` and `jet_cad_2d_flutter: ^0.7.1`;
- `.pubignore`: `/test/`, `/build/`, `/tool/`; the three assets (F-5) stay
  in;
- README: embedding the planner (`FloorPlanController`, `FloorPlanView`),
  the fonts, a link to the host guide by absolute GitHub URL, and a short
  section on adding a symbol library of one's own (D9);
- `editor.dart` stays published and says, in its library comment and in
  the README, that it is the app's editor frame and not host API (F-5);
- `example/`: a small app that shows `FloorPlanView` with the furniture
  library; a widget test with a named mutant.

### D4. The barrels

Published as they stand, as the engine's was. The plan's audit lists, for
each package: imports of another package's `src/`, and types that appear
in a public signature but are not exported. The findings go into the
results note; narrowing is a spec of its own.

### D5. CI: `publishable`

The job becomes a matrix over `packages/jet_cad_2d`,
`packages/jet_cad_2d_flutter` and `packages/jet_cad_floor_plan`, each
running `dart pub publish --dry-run`, which exits 65 on any warning. A
dependent's dry run does not need its dependency on pub.dev (F-2), so the
job can be green before the publishing order completes.

### D6. The host probe

`pubspec.yaml.in` carries the host guide's new dependency line
(`jet_cad_floor_plan: ^0.7.1`) and, after it, a `dependency_overrides`
block that takes `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_floor_plan`
and `jet_cad_restaurant_symbols` from git at `@URL@` and `@REF@`. The probe
therefore checks the commit under test, never pub.dev's current state, and
`check_host_lock.dart` keeps its checks. The override block is not in the
guide; `check_guide.dart`'s direction (every guide block is in the probe)
is unaffected.

The probe's own `main.dart` follows the guide's new symbols recipe (D9):
`host_probe.sh` copies `restaurant.jetlib` from the commit under test into
the probe's assets, and the probe builds its own `SymbolLibrarySource`.
The probe still depends on `jet_cad_restaurant_symbols` (through the
override), so the released `main.dart` files of `v0.3.0` … `v0.6.0`, which
import it, keep analysing (invariant 1).

**To measure in the plan, not assume:** that `pub get` resolves the
template with the overrides while the hosted versions are absent from
pub.dev, and that the restaurant package's hosted constraint on the
planner and the planner's git override resolve to one source.

### D7. A publication-time probe, by hand

After each package is published, the probe is resolved once without the
override block, from pub.dev alone, and analysed. This checks what a host
actually receives. It is a step of D10's checklist, not a CI job: its
verdict would depend on the network and on pub.dev's state.

### D8. The host guide §1

Rewritten for pub.dev: `dart pub add jet_cad_floor_plan` (or
`jet_cad_floor_plan: ^0.7.1` in the pubspec); the engine and the render
package come with it; import the planner's barrel only; anything under
`src/` is not API; Flutter 3.44 or later. Removed: the git dependencies,
the SHA, *"Why a SHA and not the tag"*, and the engine branch's sentence
telling a git host not to add the engine from pub.dev. §2 (fonts) is
unchanged: the asset key `packages/jet_cad_floor_plan/fonts/...` is the
same from pub.dev.

### D9. The restaurant symbols in a host

A new subsection of the guide: copy `restaurant.jetlib` and the German and
Turkish names from the repository tree at the planner's release tag
(`jet_cad_floor_plan-vX.Y.Z`) into the host's assets; declare the asset;
build `SymbolLibrarySource(name: 'restaurant', read: …, names: …)`; pass
it with `furnitureSymbolSource` to `SymbolLibraryLoader`. Keep the name
`'restaurant'`: a key and version in two sources make the loader fail.
Saved plans do not depend on the library (F-6). Every code block of the
subsection is in the probe (D6).

`jet_cad_restaurant_symbols` itself stays in the repository, unpublished,
its generator and catalog the source of the file.

### D10. Versions, tags and the publishing order

- Tags per package: `jet_cad_2d-vX.Y.Z`, `jet_cad_2d_flutter-vX.Y.Z`,
  `jet_cad_floor_plan-vX.Y.Z`, pushed by the human. The shared `vX.Y.Z`
  line ends at `v0.7.0`. `jet_cad_2d_gpu` and `jet_cad_restaurant_symbols`
  keep their version fields and take no tag.
- A change across packages is published bottom-up: engine, render
  package, planner; each step waits until the previous version shows on
  pub.dev.
- The root CHANGELOG becomes an index: a link to each published package's
  CHANGELOG, then the shared history up to 0.7.0 unchanged.
- The planner's CHANGELOG states every release that changes the schema of
  saved plans (terminals that share plans move together), as the root's
  did.
- STATUS carries the human's checklist, per package in order: `main`
  pushed and CI green; `dart pub publish --dry-run`; `dart pub publish`;
  the tag; the version visible on pub.dev; after the planner, D7.

### D11. The restaurant software's move

Written into the planner's 0.7.1 CHANGELOG entry and the results note,
for the human to apply in the restaurant software: replace the two git dependencies with
`jet_cad_floor_plan: ^0.7.1`; drop the import of
`jet_cad_restaurant_symbols` and build the source as D9 says; move
`restaurant.jetlib` and the names into the software's assets.

## Testing and exit gate

- Every package's gate green (CLAUDE.md), with the standing failures and
  skips exactly; `tool/ci` tests and `check_guide.dart` green.
- `dart pub publish --dry-run`: 0 errors, 0 warnings, for each of the
  three packages, committed state.
- Each new example's test goes red under a named mutant, fired from a
  copy and restored from it.
- The probe: `host_probe.sh` and the four `old_host_probe.sh` runs green
  locally, and the two measurements of D6 recorded.
- pana run on each archive's file set and recorded (the repository check
  waits for GitHub's `main`, as for the engine).
- CI green on the pushed branch (the push is the human's word).
- An independent review of the branch (an Opus subagent; no Codex).

## Out of scope

- Publishing `jet_cad_restaurant_symbols` (Decision 3) and
  `jet_cad_2d_gpu`.
- Narrowing any barrel (D4).
- Publishing from GitHub tags automatically; a verified publisher.
- The dormant `packages/jet_cad`'s missing `publish_to` (the engine
  review's R-4, the human's).
- Screenshots.

## Risks

- **A release cannot be taken back** (only retracted within 7 days). The
  dry runs, the examples and D7 are the guard; the human publishes.
- **The guide describes pub.dev before the packages are there.** Between
  the merge and the publication the guide's recipe does not resolve; the
  publication follows the merge, as for the engine.
- **The override and the restaurant package's hosted constraint** may
  resolve to two sources in the probe; D6 measures it first, and the plan
  stops there if it does.
