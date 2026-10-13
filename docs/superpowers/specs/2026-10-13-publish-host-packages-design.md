# Publishing the host packages on pub.dev — design

**Date:** 2026-10-13. **Status:** revision 2, awaiting the human's review
of this file. Revision 1 (`3874c2f`) was written after the human approved
its three sections in chat and was reviewed independently: **Approve with
fixes**, V-1 to V-14, no blocker; revision 2 folds in every fix (see
[Review](#review)).

**Asked for by the human, 2026-10-13:** *"bence tümünü sırayla
yayınlayalım. restoran sembolleri de yayınlandıktan sonra restoran
yazılımı içinden pub.dev üzerinden kurarak kullanabilirim."* The restaurant
software is to install the planner from pub.dev instead of by git.

**Branch:** `feat/publish-host-packages`, cut by hand from `main` at
`d41e5f6` (the engine's publication merged at `1dc167d`). **Size:** M, one
plan. **Touched:**

- the pubspecs of `jet_cad_2d_flutter`, `jet_cad_floor_plan`,
  `jet_cad_restaurant_symbols`, `jet_cad_2d_gpu` and the three apps of the
  live line (D1);
- the two published packages' LICENSE, README, CHANGELOG, example,
  `.pubignore` and doc comments (D2, D3);
- CI: `publishable` (D5), the host probe — `host_probe.sh`,
  `pubspec.yaml.in`, `lib/main.dart`, a `.gitignore` — and
  `check_host_lock.dart` with its library and tests (D6),
  `tool/ci/test/guide_test.dart` (D8);
- the host guide §1 and a new symbols subsection (D8, D9);
- the root CHANGELOG and STATUS (D10).

**Release:** `jet_cad_2d_flutter` 0.7.1, then `jet_cad_floor_plan` 0.7.1,
published by the human after `jet_cad_2d` 0.7.1.

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
   its own code and assets meanwhile (D9).
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

- **F-1. Workspace resolution of hosted constraints.** Measured twice in
  throwaway worktrees. With every pubspec in D1's form (hosted `^0.7.1`
  everywhere, the two packages at `version: 0.7.1`, `sdk: ^3.6.0`, no
  `publish_to`), root `flutter pub get` prints *"Got dependencies!"*;
  `.dart_tool/package_config.json` resolves `jet_cad_2d`,
  `jet_cad_2d_flutter` and `jet_cad_floor_plan` to `../packages/<name>`
  at language 3.6, and no tracked file is modified by `pub get`. dart.dev's
  workspaces page: workspace packages depending on each other resolve to
  the local copy, regardless of source. **The caret's upper bound is
  enforced:** with the engine's version set to 0.8.0 (or 0.7.0), `pub get`
  fails (*"Because restaurant_demo depends on jet_cad_2d ^0.7.1 and
  jet_cad_workspace depends on jet_cad_2d, version solving failed."*). **The
  lower bound is not:** the local sibling is always the one resolved.
- **F-2. Dry runs.** A dependent's dry run does not need its dependency on
  pub.dev. In D1's form, with LICENSE, CHANGELOG and `.pubignore` committed
  per D2/D3: the render package *"Total compressed archive size: 226 KB …
  Package has 0 warnings."*, exit 0; the planner 459 KB, one warning (no
  `repository`), exit 65. Without them, the render package's archive was
  1005 KB with `test/` inside. The server may still refuse an upload whose
  dependency it cannot resolve: D10's order stands. The `dart` on the
  local path is Flutter's wrapper, as in CI's `flutter-action`.
- **F-3. Pub refuses `path:` dependencies in a published package.**
  `jet_cad_2d_flutter` and `jet_cad_floor_plan` depend on the engine (and
  the planner on the render package) by `path:` today.
- **F-4. `jet_cad_2d_flutter`** at 0.7.0: `publish_to: none`, `sdk:
  ^3.5.0` with a comment tying it to the language version (spec 13 R-4),
  `flutter: ">=3.44.0"`, `repository:` the dead `ahmeturel/jet-cad`;
  dependencies `jet_cad_2d` (path), `meta`, `vector_math`, `pdf`. No
  LICENSE, no CHANGELOG; its README is a developer's note (rigs, golden
  commands). Tracked bytes: `lib/` 734,816, `test/` 2,612,245. `shaders/`
  (`cad_stroke.vert`, `cad_stroke.frag`) is read by the package's own
  `test/gpu/` suites and compiled by `jet_cad_2d_gpu`'s
  `tool/build_shaders.sh` (by a repository path); nothing in the render
  package's `lib/` loads it at run time, though
  `lib/src/gpu/geometry_collector.dart` names `shaders/cad_stroke.vert` in
  a doc comment. Public libraries: `jet_cad_2d_flutter.dart` (59 exports)
  and `export_testing.dart` (a PDF reader for tests; imports only
  `dart:convert`, `dart:math`, `dart:typed_data`; used by the render
  package's tests, `apps/floor_planner`'s tests and one planner test).
  `dart doc --dry-run`: 6 warnings.
- **F-5. `jet_cad_floor_plan`** at 0.7.0: `publish_to: none`, `sdk:
  ^3.5.0` with the same language-version comment, `flutter: ">=3.44.0"`,
  no `repository:`; its description cites spec slices. Dependencies
  `jet_cad_2d`, `jet_cad_2d_flutter` (path), `flutter_localizations`,
  `meta`, `pdf`, `printing`, `vector_math`. Assets:
  `assets/library/furniture.jetlib`, `lib/fonts/Roboto-Regular.ttf` and
  `assets/fonts/Roboto_LICENSE.txt` (Apache 2.0). No LICENSE, README or
  CHANGELOG. Tracked bytes: `lib/` 1,410,777, `test/` 3,630,238; `tool/`
  holds the furniture library's generator. Public libraries:
  `jet_cad_floor_plan.dart` (the host API; it re-exports one render type,
  `SymbolThumbnails`, and exports `SymbolNames` and
  `SymbolLibrarySource`), `editor.dart` (its header: *"Explicitly
  internal: a host embeds the planner through `jet_cad_floor_plan.dart`"*),
  `symbols.dart` (a symbol catalog's types and builder, pure Dart) and
  `symbol_sources.dart`. `dart doc --dry-run`: 23 warnings.
- **F-6. Language 3.6.** In D1's form, `dart format` changes no file in
  either package (232 and 296 files), and `flutter analyze` finds no issue
  in the render package, the planner, the symbols, the GPU package and
  the three Flutter apps.
- **F-7. No `dart:io`, `dart:ffi`, `dart:html` or `package:web`** in
  either package's `lib/`; no package's `lib/` imports another's `src/`.
- **F-8. The restaurant symbols at run time.** A host uses one value,
  `restaurantSymbolSource`: the name `'restaurant'`, a reader of
  `assets/restaurant.jetlib` (128 KB, the engine's JSON format, schema 10,
  generated by `tool/generate_restaurant_library.dart` from the package's
  catalog) and `restaurantSymbolNames`, a Dart constant in
  `lib/src/names.dart` (169 lines) that imports
  `package:jet_cad_floor_plan/symbol_sources.dart`. The loader fails
  (`SymbolLibraryFailed`) when one key and version is in two sources,
  whatever their names; the name appears only in the message
  (`symbol_library.dart`). Placing a symbol copies its definition into the
  plan (`symbol_placer.dart`, `definitionForEntry`), so saved plans do not
  need the library. The package depends on `jet_cad_2d` and
  `jet_cad_floor_plan` by `path:`.
- **F-9. Hosts import the planner only.** `apps/restaurant_demo` and the
  host probe import `jet_cad_floor_plan.dart` and
  `jet_cad_restaurant_symbols.dart`, nothing else of the repository.
- **F-10. The host probe.** `tool/ci/host_probe.sh <url> <sha>` writes the
  probe's pubspec from `pubspec.yaml.in` (the planner and the restaurant
  symbols by git at the SHA), resolves, runs `check_host_lock.dart` (no GPU
  renderer, no build hook), analyses and builds for the web.
  `old_host_probe.sh <tag>` swaps in the probe's `main.dart` as the tag had
  it and analyses it; CI runs it for `v0.3.0`, `v0.4.0`, `v0.5.1` and
  `v0.6.0` (the host embedding API spec's invariant 1); each of those
  `main.dart` files imports `jet_cad_restaurant_symbols`.
  `check_guide.dart` (`tool/ci/lib/guide.dart`, `missingBlocks`) requires
  each guide block to be **contained**, white space collapsed, in the
  probe's `main.dart` (Dart) or `pubspec.yaml.in` (YAML), after
  `_pubspecShape` masks the template's git `url:` and `ref:`.
  `tool/ci/test/guide_test.dart` encodes the git recipe: GD1 expects two
  YAML blocks, GD3 replaces `path: packages/jet_cad_restaurant_symbols`,
  GD4 expects `url: https://github.com/a-urel/jet-cad.git` in the guide.
- **F-11. D6, measured.** A template of `jet_cad_floor_plan: ^0.7.1` and
  a `dependency_overrides` block taking the four packages from git at the
  probe's URL and ref, in D1's form, committed in a throwaway worktree:
  `host_probe.sh file://<worktree> <sha>` exits 0. The lock reads
  *"jet_cad_2d 0.7.1 from git … (overridden)"*, the same for the render
  package and the planner, and *"jet_cad_restaurant_symbols 0.7.0 from git
  … (overridden)"*: the restaurant package's hosted constraint and the
  planner's override resolve to one source. The lock check, the analysis
  and the web build pass; `old_host_probe.sh` for `v0.3.0`, `v0.4.0`,
  `v0.5.1` and `v0.6.0` each print *"No issues found!"*. The restaurant
  package needs no `dependencies:` entry: the override alone puts it in
  the graph.
- **F-12. How often each package changed** (files under `lib/`, and the
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

- **F-13.** `jet_cad_2d_flutter` and `jet_cad_floor_plan` answer 404 on
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

**Bounds.** The workspace enforces a caret's upper bound and never its
lower bound (F-1). So:

- a version bump of a sibling past its dependents' caret (0.7.x → 0.8.0)
  breaks `pub get` until every dependent's constraint follows, **in the
  same commit**;
- **the lower-bound rule, at a dependent's release:** a dependent that
  uses API new in 0.7.2 could declare `^0.7.1`, pass every gate (the local
  sibling is always resolved) and publish a false lower bound. So when a
  dependent is released, its lower bound on each sibling is raised to that
  sibling's current version, which is on pub.dev by then (D10's order),
  and pana is run on the dependent's archive before `dart pub publish`:
  its *"Compatible with dependency constraint lower bounds"* check
  resolves the siblings from pub.dev at the lower bounds and analyses the
  package against them, which is the check itself, not a proxy. A release
  that does not change a dependent does not touch its constraints: an
  engine patch does not force the render package or the planner to
  republish (Decision 4). No CI job checks this: between releases the
  rule has nothing to say.

### D2. `jet_cad_2d_flutter` 0.7.1

- `publish_to: none` removed; `version: 0.7.1`; `sdk: ^3.6.0` (the floor
  pub workspaces document), its comment reworded: the bound now follows
  the workspaces floor and sets language 3.6, which formats and analyses
  as 3.5 did (F-6); `flutter: ">=3.44.0"` stays and is what binds.
  `repository: https://github.com/a-urel/jet-cad`, `issue_tracker:`,
  topics; a description of what the package is, without spec references.
- LICENSE: the root's, byte for byte.
- `.pubignore`, anchored: `/test/`, `/build/`, `/shaders/`. The shaders
  are not run-time assets of this package (F-4): its tests read them and
  `jet_cad_2d_gpu` compiles them from the repository, which the GPU
  package keeps doing. The doc comment in `geometry_collector.dart` that
  names `shaders/cad_stroke.vert` says the file is in the repository, not
  in the package.
- README written for pub.dev: what it renders (`DraftCanvas`, the camera,
  rulers, the interaction layer, the PDF and PNG export), the smallest
  widget that shows a `DraftDocument`, what is API (the barrel; nothing
  under `src/`; `export_testing.dart` is a test instrument, not API), the
  0.x rule. No screenshots (the human, for the engine: *"görselsiz
  kalsın"*).
- CHANGELOG from 0.7.1: 0.7.0's code, packaged; the history before it in
  the root CHANGELOG.
- **`example/`: no pubspec of its own**, as the engine's: `example/lib/main.dart`
  is a small Flutter app that shows a document in a `DraftCanvas`,
  analysed with the package, and `test/example_test.dart` pumps it and
  asserts what it draws, with a named mutant that turns it red
  (CLAUDE.md's testing bar). Not `flutter create example`: a standalone
  example pubspec with `path: ..` is outside the workspace and fails root
  `pub get` (*"could not find package jet_cad_2d at https://pub.dev"*,
  measured), and after the publication would quietly resolve the engine
  from pub.dev.
- `dart doc` warnings: 6 → 0.

### D3. `jet_cad_floor_plan` 0.7.1

The same as D2, with:

- dependencies `jet_cad_2d: ^0.7.1` and `jet_cad_2d_flutter: ^0.7.1`;
  `repository:` and `issue_tracker:` added (it has none: the one dry-run
  warning of F-2);
- `.pubignore`: `/test/`, `/build/`, `/tool/`; the three assets (F-5) stay
  in;
- README: embedding the planner (`FloorPlanController`, `FloorPlanView`),
  the fonts, a link to the host guide by absolute GitHub URL, and a short
  section on adding a symbol library of one's own (D9);
- `editor.dart` stays published and says, in its library comment and in
  the README, that it is the app's editor frame and not host API (F-5);
- `example/lib/main.dart` (no pubspec): a small app that shows
  `FloorPlanView` with the furniture library; `test/example_test.dart`
  with a named mutant;
- `dart doc` warnings: 23 → 0.

### D4. The barrels

Published as they stand, as the engine's was. The plan's audit lists, for
each package, the types that appear in a public signature but are not
exported (no package imports another's `src/`, F-7). The findings go into
the results note; narrowing is a spec of its own.

### D5. CI: `publishable`

The job becomes a matrix over `packages/jet_cad_2d`,
`packages/jet_cad_2d_flutter` and `packages/jet_cad_floor_plan`. Each
entry runs, after `flutter pub get`:

- `cmp LICENSE <package>/LICENSE` (the byte-identical licence of Decision
  2 has a check);
- `dart pub publish --dry-run`, which exits 65 on any warning.

A dependent's dry run does not need its dependency on pub.dev
(F-2), so the job can be green before the publishing order completes.

### D6. The host probe

**The template.** `pubspec.yaml.in` carries the host guide's dependency
line (`jet_cad_floor_plan: ^0.7.1`) and, after the `flutter:` section, a
`dependency_overrides` block that takes `jet_cad_2d`,
`jet_cad_2d_flutter`, `jet_cad_floor_plan` and
`jet_cad_restaurant_symbols` from git at `@URL@` and `@REF@`. The
restaurant package has no `dependencies:` entry: the override puts it in
the graph (F-11). The probe therefore checks the commit under test, never
pub.dev's current state. `_pubspecShape`'s masking of `url:` and `ref:`
stays; it now touches only the override block, which the guide never
shows.

**The lock check proves it.** Once the packages are on pub.dev, a dropped
or misspelt override would resolve silently from there and every probe
step would stay green. `check_host_lock.dart` gains a second check: each
of the four packages is in the lock with `source: git` and a
`resolved-ref` equal to the probe's ref (passed by `host_probe.sh`). Its
tests cover each verdict; named mutants: a fixture lock with one of the
four `hosted`, and one with another ref, each must turn a test red.

**The symbols, as a host has them.** After `pub get`, `host_probe.sh`
copies `restaurant.jetlib` and `lib/src/names.dart` from the overridden
restaurant package's root (its `rootUri` in
`.dart_tool/package_config.json`) into the probe: the `.jetlib` to
`assets/restaurant.jetlib`, `names.dart` to `lib/restaurant_names.dart`
with its import rewritten to `package:jet_cad_floor_plan/jet_cad_floor_plan.dart`
(D9's recipe). Both copied paths are in `tool/ci/host_probe/.gitignore`.
The probe's own `main.dart` builds its `SymbolLibrarySource` from them,
as the guide says; the released `main.dart` files of `v0.3.0` … `v0.6.0`
still import the package and keep analysing (F-11).

**Invariant 1 from now on.** `old_host_probe.sh` takes any tag: a future
host release's probe is read from its `jet_cad_floor_plan-vX.Y.Z` tag, and
the four existing tags keep running through the override.

### D7. A publication-time probe, by hand

Once the planner is published, the probe is resolved once without the
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

`tool/ci/test/guide_test.dart` follows (F-10): GD1's count of YAML blocks
is the new guide's; GD3 and GD4 are rewritten for the hosted line and the
symbols' asset fragment, each still turning red when the probe lacks a
line the guide has.

### D9. The restaurant symbols in a host

A new subsection of the guide:

1. From the repository tree at the tag of the planner release the host
   depends on (`jet_cad_floor_plan-vX.Y.Z`), copy
   `packages/jet_cad_restaurant_symbols/assets/restaurant.jetlib` into the
   host's assets and `packages/jet_cad_restaurant_symbols/lib/src/names.dart`
   into the host's `lib/`, its import changed to
   `package:jet_cad_floor_plan/jet_cad_floor_plan.dart` (which exports
   `SymbolNames`, F-5).
2. Declare the asset. The guide shows it as a fragment (`  assets:` and
   its line) that the probe's template holds, contiguous, after §2's
   `fonts:` (`check_guide` matches by containment; a block that restarts
   at `flutter:` would not be contained, measured).
3. Build `SymbolLibrarySource(name: 'restaurant', read: …, names: …)` and
   pass it with `furnitureSymbolSource` to `SymbolLibraryLoader`.

Never load the copied library together with the package's
`restaurantSymbolSource`: the same keys and versions in two sources make
the loader fail (F-8); the name `'restaurant'` is kept so the loader's
messages read as before. Saved plans do not depend on the library (F-8).
A change to the symbols reaches hosts with a planner release, whose tag
then carries it. Every code block of the subsection is in the probe (D6).

`jet_cad_restaurant_symbols` itself stays in the repository, unpublished,
its generator and catalog the source of the file.

### D10. Versions, tags and the publishing order

- Tags per package: `jet_cad_2d-vX.Y.Z`, `jet_cad_2d_flutter-vX.Y.Z`,
  `jet_cad_floor_plan-vX.Y.Z`, pushed by the human. The shared `vX.Y.Z`
  line ends at `v0.7.0`. `jet_cad_2d_gpu` and `jet_cad_restaurant_symbols`
  keep their version fields and take no tag.
- A change across packages is published bottom-up: engine, render
  package, planner; each step waits until the previous version shows on
  pub.dev. D1's lower-bound rule holds at every release.
- The root CHANGELOG becomes an index: a link to each published package's
  CHANGELOG, then the shared history up to 0.7.0 unchanged. Its current
  preamble and its *Unreleased* entry (which tell a git host not to take
  the engine from pub.dev) are replaced.
- STATUS: the ruling *"The engine's own version"*, which says the host
  packages keep one version and one `vX.Y.Z` tag, is rewritten to
  Decision 4 and this section; the ruling *"The host packages go to
  pub.dev too"* points at this spec.
- The planner's CHANGELOG states every release that changes the schema of
  saved plans (terminals that share plans move together), as the root's
  did.
- STATUS carries the human's checklist, per package in order: `main`
  pushed and CI green; for a dependent, its lower bounds per D1 and pana's
  lower-bounds check green; `dart pub publish --dry-run`; `dart pub
  publish`; the tag; the version visible on pub.dev; after the planner,
  D7.

### D11. The restaurant software's move

Written into the planner's 0.7.1 CHANGELOG entry and the results note, for
the human to apply in the restaurant software: replace the two git
dependencies with `jet_cad_floor_plan: ^0.7.1`; drop the import of
`jet_cad_restaurant_symbols` and copy the library and its names as D9
says.

## Testing and exit gate

- Every package's gate green (CLAUDE.md), with the standing failures and
  skips exactly; `tool/ci` tests and `check_guide.dart` green.
- `dart pub publish --dry-run`: 0 errors, 0 warnings, for each of the
  three packages, committed state; `cmp` of each LICENSE.
- `dart doc --dry-run`: 0 warnings for both packages.
- Named mutants, each fired from a copy and restored from it, each
  turning a test red: the two examples' tests (D2, D3); the lock check's
  source and ref (D6).
- The probe: `host_probe.sh` and the four `old_host_probe.sh` runs green
  locally.
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
  dry runs, pana's lower-bounds check (D1), the examples and D7 are the
  guard; the human publishes.
- **The guide describes pub.dev before the packages are there.** Between
  the merge and the publication the guide's recipe does not resolve; the
  publication follows the merge, as for the engine.

## Review

Revision 1 (`3874c2f`), one Opus reviewer subagent, read-only, with its own
throwaway worktree (removed): **Approve with fixes**, no blocker. It
measured D6 in full (F-11) and D1's form (F-1, F-2, F-6).

| # | Finding | In revision 2 |
|---|---|---|
| V-1 | A `flutter create` example breaks the workspace | D2, D3: `example/lib/main.dart`, no pubspec |
| V-2 | The names are Dart, importing `symbol_sources.dart`; how the probe gets the files | F-8, D6, D9 |
| V-3 | A guide block restarting at `flutter:` is not contained in the template | D9 step 2 |
| V-4 | `guide_test.dart` encodes the git recipe | F-10, D8, Touched |
| V-5 | Nothing proves the probe tests the commit | D6: the lock's source and ref, with mutants |
| V-6 | The workspace never checks a lower bound | F-1, D1: the rule at a dependent's release, checked by pana's lower-bounds analysis (the reviewer's CI script would force every dependent to republish on an engine patch, against Decision 4) |
| V-7 | STATUS's ruling and the root CHANGELOG contradict Decision 4 | D10 |
| V-8 | D7 cannot run before the planner is published | D7 |
| V-9 | The loader fails on keys, not on the name | F-8, D9 |
| V-10 | The GPU package compiles the shaders | F-4, D2 |
| V-11 | Sizes | F-4, F-5: tracked bytes |
| V-12 | Invariant 1 after `v0.7.0` | D6 |
| V-13 | The symbols are untagged | D9 |
| V-14 | `dart doc` baselines; the `sdk:` comments; a LICENSE check | F-4, F-5, D2, D5 |
