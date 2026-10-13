## Global Constraints

- **Names (e75064e):** the package is `jet_cad_2d_kit` at `packages/jet_cad_2d_kit`, libraries `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` and `package:jet_cad_2d_kit/authoring.dart`; the plan library is `jet_cad_2d_plan`; kits are `jet_cad_2d_kit_<domain>`. Dart type names are unchanged (`PlanKit`, `KitNames`, `CatalogSymbol`, ...).
- **Version and environment:** `version: 0.1.0`, `resolution: workspace`, `sdk: ^3.6.0`, `flutter: ">=3.44.0"` (the same floor as `jet_cad_2d_flutter`).
- **Dependencies (K1):** the Flutter SDK, `jet_cad_2d: ^0.7.2`, `meta: ^1.18.0`, `vector_math: ^2.2.0`; dev: `flutter_test` (SDK), `lints: ^6.1.0`. Not `jet_cad_2d_flutter` (sub-project 2 adds it). **Never `jet_cad_2d_plan` and never any `jet_cad_2d_kit_*`** (umbrella A1), in the pubspec or in any import.
- **No `dart:io` anywhere under `lib/`.** **Model and authoring are pure Dart:** every file under `lib/src/model/` and everything reachable from `lib/authoring.dart` imports only `dart:async`, `dart:collection`, `dart:convert`, `dart:core`, `dart:math`, `dart:typed_data`, `package:jet_cad_2d`, `package:meta`, `package:vector_math` and package-local files that obey the same rule (K1; the purity test of Task 1 enforces it).
- **The old packages are untouched** (umbrella A12, spec "Out of scope"): no change under `packages/jet_cad_floor_plan`, `packages/jet_cad_restaurant_symbols`, `packages/jet_cad_2d`, `packages/jet_cad_2d_flutter` or `apps/`. Logic and tests are ported by copying and adapting, never by importing.
- **Components (K2):** immutable, value-equal, `toJson` keys in a fixed alphabetical order, bad values refused in the constructor with `ArgumentError` (never an `assert`: a release build must refuse too).
- **Geometric decisions use `Tolerance.standard`; stored-value comparisons are exact `==`** (CLAUDE.md): radius and sweep against the tolerance; closedness (`isClosedPolyline`), bytes and snapshot texts by `==`.
- **Draw order is ascending handle value:** a `SymbolEntry`'s leaves are sorted by handle; the builder allocates handles in catalog order (definition, its leaves, the next definition).
- **Never commit `analysis_options.yaml` changes.** The existing ones are tracked and `flutter pub get` rewrites three of them in this workspace: never stage those. Plan decision: the new package's own `analysis_options.yaml` is created and committed **once**, in Task 1, by explicit path (as `3694f5c` did for the restaurant package); a new package without it would analyse with no lints. Stage files by explicit path only: never `git add -A` or `git add .`. Run `git status --short` after every pub operation.
- **Never synthesize test output.** Quote what commands print. Reviewers re-run every claim.
- **Mutations run on committed files only, and are reverted with `git checkout -- <file>`,** then `git diff --quiet -- <file>` must exit 0. **In every task, run the Commit step before the Mutation check step** (they are listed the other way round below; commit first, then mutate the committed files). Never restore from a `/tmp` copy (a stale backup once destroyed a file here), and never `git checkout --` a file with uncommitted work (that once destroyed more).
- **Code, comments and commit messages in English.** Every commit message ends with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **`cd packages/jet_cad_2d_kit && dart pub publish --dry-run` exits 0 with 0 warnings** at the exit gate. **Never run `dart pub publish` without `--dry-run`**: the wave publishes (umbrella A10), the human publishes. Never push, tag or merge.
- **Every task ends green:** `cd packages/jet_cad_2d_kit && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` (Tasks 1 and 11 add the `tool/ci` gate; Tasks 1 and 12 run all three CLAUDE.md gates). The package's language version is 3.6, so `dart format` uses the short style: run `dart format .` in the package before the format gate; the code blocks below are not guaranteed to be formatted.
- **Testing bar (CLAUDE.md):** every behaviour or refusal test names the mutation that turns it red; positive controls, premise checks and fixture-sanity tests are exempt (they pin the fixtures, not a behaviour). Each task has a mutation step: apply each named mutation, run the named test, see it red, revert with `git checkout --`. Fixtures are off the origin, at non-zero rotations where geometry matters, with non-default attributes.
- Worktree-guarded sessions refuse bash loops and `$VAR` pipelines: run commands one by one.

## Review Focus

1. **Structurally broken bytes that are not one of K3's faults** (a document whose `components` is a list, a component payload that is a string, `entities` missing) must still end in a `SymbolLibraryError` of rule 1, never in a `TypeError` escaping `SymbolLibrary.decode`. Pinned in Task 4 (V1g).
2. **A kit author's lower-case words outside ASCII** (`çocuk`, `ışık`, a tag with a space, `bar stool`) must be accepted as tags, and an upper-case one refused. Pinned in Task 2 (C6).
3. **A component JSON with a field this build does not know** (written by a newer toolkit) must still read; the field is ignored, not a refusal. Pinned in Task 2 (C12) and Task 3 (L5).
4. **An empty catalog** (a kit with no symbols yet, only types) must build a valid, empty library that decodes and conforms. Pinned in Task 7 (B7) and Task 9 (F18).
5. **One key at two versions with different English names**: the word check must compare a locale's word with the newest version's English, and the snapshot must hold both versions. Pinned in Task 9 (F7, F19).

---

## File structure
## File structure

Paths in the tasks are relative to `packages/jet_cad_2d_kit/` unless they start with `docs/`, `tool/`, `.github/`, `packages/` or name the root `pubspec.yaml`.

```
packages/jet_cad_2d_kit/
  pubspec.yaml, analysis_options.yaml, LICENSE, README.md, CHANGELOG.md
  example/example.dart                     an authoring round trip (Task 10)
  lib/jet_cad_2d_kit.dart                  the contract barrel (Flutter)
  lib/authoring.dart                       the authoring barrel (pure Dart)
  lib/src/model/                           pure Dart, exported by both barrels through model.dart
    model.dart                             the model's single export list
    kit_ids.dart                           kit id, kind and key patterns (K2)
    json_fields.dart                       fromJson field readers (not exported)
    symbol_component.dart                  SymbolComponent, jetcad.symbol (K2)
    unit_component.dart                    UnitComponent, UnitLabelling, UnitKinds, jetcad.unit (K2)
    library_component.dart                 LibraryComponent, jetcad.library (K2)
    manifest_component.dart                ManifestComponent, jetcad.manifest (K2)
    register.dart                          registerKitComponents (+ the wrapped form decode uses)
    symbol_library.dart                    SymbolLibrary, SymbolEntry, SymbolLeaf, SymbolLibraryError (K3)
    kit_names.dart                         KitNames (K4)
    kit_problem.dart                       KitProblem, KitProblemCode (K5, K7)
  lib/src/kit/                             the contract's Flutter side
    symbol_library_source.dart             SymbolLibrarySource (K5)
    bundled_library.dart                   bundledLibrary (K5)
    plan_kit.dart                          PlanKit (K5)
  lib/src/authoring/                       pure Dart
    catalog.dart                           Catalog, CatalogSymbol, CatalogUnit, CatalogShape family (K6)
    builder.dart                           buildLibraryDocument, encodeLibrary (K6)
    shapes.dart                            rect, inset, poly, chairAt, chairsAround, stoolAt, stoolsAround (K6)
    snapshot.dart                          geometrySnapshot, parseSnapshot, encodeSnapshot, updateSnapshot (K7)
    conformance.dart                       conformance (K7)
  test/
    support/import_walker.dart             the purity walker
    support/library_fixtures.dart          the valid library and its one-fault JSON breakers
    invariants/purity_test.dart            K1
    model/*.dart, kit/*.dart, authoring/*.dart
    fixtures/sample_kit/                   the sample kit: sample_kit.dart, generate.dart, sample.jetlib, sample_snapshot.json
docs/kits.md                               K8
tool/ci/lib/kit_deps.dart, tool/ci/check_kit_deps.dart, tool/ci/test/kit_deps_test.dart   K9
.github/workflows/ci.yml                   K9
pubspec.yaml (root)                        the workspace entry
```

---

### Task 1: The package, the workspace entry and the purity test (K1)
