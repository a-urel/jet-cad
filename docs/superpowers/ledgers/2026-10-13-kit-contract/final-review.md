# Final whole-branch review: kit contract, sub-project 1

Range `1b4670b2..fea46c30` (21 commits, `feat/kit-architecture`), against
`docs/superpowers/specs/2026-10-13-kit-contract-design.md` (K1-K9 and its
amendments) under the umbrella (A1-A17). Reviewed in passes: the package's
`lib/` line by line, its tests by name and fixture, `tool/ci/`, the CI diff,
`docs/kits.md`, README/CHANGELOG/example, the results note. The plan body
(about 6000 lines) was skimmed, not re-audited: the per-task reviews own it.

## Verified independently (this session)

- `packages/jet_cad_2d_kit`: `flutter test` +225 all passed; `flutter analyze`
  no issues; `dart format` 47 files, 0 changed.
- `tool/ci`: `dart test` +106 all passed; `dart run tool/ci/check_kit_deps.dart`
  prints "1 package(s) checked".
- `dart run test/fixtures/sample_kit/generate.dart` under plain `dart run`
  (pure-Dart claim holds) rewrites nothing.
- `git status --short` empty after all of it (no analysis_options.yaml
  rewritten).
- Only `packages/jet_cad_2d_kit/analysis_options.yaml` among committed
  analysis options; no file of the old packages, engine, Flutter layer, gpu
  or apps touched; all 21 commits carry
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Every Dart block of `docs/kits.md` (4) and of the README (1) is verbatim in
  `example/*.dart` today.
- Engine facts the validator relies on: `GeometryStore.read` copies (the
  entries outlive the disposed document safely); arc scalars are
  `[r, start, sweep]`; `isDegenerateSegment` uses `Tolerance`; the codec
  emits diagnostics only for repairs (cycles, fills), never for an unknown
  component type, so K3's "preserved and ignored" holds.

## Strengths

- The validator (`symbol_library.dart`) is a faithful, readable port of K3:
  every refusal carries its rule number; components decode through guarded
  factories so a bad key or tag lands on rule 5 or 8, not a codec error; one
  wrapped registry function keeps decoder and `registerKitComponents` from
  drifting.
- `encodeLibrary` decodes its own output: a generator can never write a
  library the format refuses.
- The snapshot/`updateSnapshot` merge is the right design for A16: a changed
  `key@N` can only show as a red test, never as a regenerated file.
- Fixtures are deliberately non-degenerate (off origin, versions 3/2/1,
  handles far apart, leaves inserted out of order and interleaved), and the
  results note names a mutation for nearly every test.
- The purity walker is an allow-list and is itself tested against fixtures
  (P2-P5), so P1 cannot pass vacuously.

## Issues

### Important

1. **The branch has never been through CI.** It is not pushed and has no PR;
   CI triggers only on pushes to `main`/`claude/**` and on PRs
   (`.github/workflows/ci.yml:8-12`). The new matrix entries (`:43`, `:167`),
   the `check_kit_deps` step (`:151`) and, above all, F0's byte equality of the
   macOS-generated `test/fixtures/sample_kit/sample.jetlib` against a Linux
   build are unverified. The ledger already names CI as the arbiter. Fix:
   push and open the PR; merge only on green.
2. **Rule 15's tolerance decisions are unpinned** (deferred T4).
   `symbol_library.dart:392` (zero-length line via `isDegenerateSegment`) and
   `:402` (radius `<= Tolerance.standard.linear`): replacing either with an
   exact `== 0` / `<= 0` survives the suite. "Geometric decisions use
   Tolerance" is a CLAUDE.md non-negotiable; the arc sweep is pinned (V15r,
   V15s), these two are not. Fix: a radius at `linear/2` and at exactly
   `linear` refused, one just above loads; a line `linear/2` long refused.
3. **The results note over-states its record** (deferred T12).
   `docs/superpowers/notes/2026-10-13-kit-contract-results.md`, "Mutations of
   Tasks 1-11": "Each ran on a committed file and was reverted with
   `git checkout --`, `git diff --quiet` exit 0, as recorded in the task
   reports" is not true of Task 9, whose session left a mutation in
   `conformance.dart` that the controller reverted (ledger). "(macOS)" for
   the goldens is unrecorded; the flaky `query_allocation_test` run of Task 1
   is omitted. A note of record must say only what the reports record.
4. **A16's "retired symbol leaves the gallery" has no mechanism.**
   `docs/kits.md:207-209` (and A16) promise it, but nothing in
   `SymbolComponent`, `CatalogSymbol` or the library marks a key as retired,
   so sub-project 2's gallery cannot implement it. Fix now (cheap): add it to
   the spec's Risks/Amendments as a sub-project 2 input (likely an optional
   `retired` field in `jetcad.symbol` and the catalog), or soften the doc
   line until then.

### Minor

5. `docs/kits.md:43-44` says the conformance test refuses types and tools not
   under the kit's id; it checks keys only (types/tools are sub-project 2).
   §9's checklist never tells a kit to assert `PlanKit.validate()` is empty,
   yet foreign `tool:`/`type:` words and unknown namespaces are caught only
   there.
6. `tool/ci/check_kit_deps.dart:26-27,31`: packages are picked by directory
   name and only `lib/`, `test/`, `tool/` are read. Umbrella A1 says "any of
   its Dart files", and the spec header says the umbrella wins. A kit's
   `example/` importing `jet_cad_2d_plan` (a natural README demo) escapes the
   check. Either scan every Dart file and pick by pubspec name, or amend A1
   to allow `example/` explicitly: a decision for the human before
   sub-project 3 writes the first kit.
7. Nothing enforces that the README and `docs/kits.md` blocks stay verbatim
   in `example/` (`tool/ci/check_readmes.dart:15-19` covers three other
   packages). Add `jet_cad_2d_kit` to it or a test in the package.
8. `symbol_library.dart:395-399, 311-314`: a polyline whose points coincide
   passes rule 15 (`CatalogPolyline([p], closed: true)` gives two equal
   points), and a unit outline of two distinct points closed passes rule 11
   with zero area, which service mode will fill as nothing. Spec says only
   "under 2 points"; a spec gap worth closing when sub-project 2 fills
   outlines.
9. `builder.dart:54-96` (deferred T7): the document leaks when a payload
   throws after it exists, e.g. an empty closed `CatalogPolyline`
   (`points.first` StateError). Ruling F11's intent is half met. Harmless in
   a generator; a `try { ... } catch { dispose; rethrow }` closes it.

## API risks for sub-project 2 (concrete only)

- **R1 Per-unit data has no home.** `UnitComponent` sits on the definition
  (kind, capacity, labelling); A6's per-unit label (`assigned`, set by a
  kit's type) and number (`numbered`) need an instance-level contract
  component. Additive, but `registerKitComponents`' "the four and nothing
  else" (doc, `docs/kits.md:57`, register tests) changes. A parametric unit
  (a booth with N seats) cannot carry a capacity at all while K2 says "on a
  definition's handle".
- **R2 Retirement** (issue 4): a new `jetcad.symbol` field. Since every
  `fromJson` requires every current field, a field added later must be
  optional on read, or plans saved before it stop opening. Write that
  convention into the spec.
- **R3 `conformance()` cannot see types, tools or property words** (pure Dart;
  they live on the Flutter `PlanKit`). A16 requires it to check their ids
  and their English. Additive named parameters (ids as strings) solve it;
  do not move the check into `PlanKit.validate` alone, or the kit's test
  needs Flutter-side objects to conform.
- **R4 `KitProblemCode` will grow** (types, tools, attachments). Free before
  the wave; after 0.1.0 each new value breaks exhaustive switches. Land
  sub-project 2's codes before publishing.
- **R5 Engine types in the public API.** `SymbolLeaf` exposes `EntityRecord`
  and `GeometryPayload`, `SymbolEntry.definition` a `Definition`: a breaking
  change of those in `jet_cad_2d` 0.x is a breaking change of the contract
  and of every kit. And K7.1's byte equality couples every kit's CI to the
  codec's exact output: an engine release that changes `encodeToString`
  turns every kit red until regenerated. Document both in `docs/kits.md`.
- **R6 Manifest versions are free strings** (`manifest_component.dart:28`,
  `plan_kit.dart:39`). If sub-project 2 compares versions (a plan saved by a
  newer kit), it must parse semver; tightening later refuses stored
  manifests. Decide in sub-project 2's spec.

## Deferred minors: triage

Must fix before merge: **T4** rule-15 radius and line tolerance boundaries
(issue 2); **T12** the results note's wording (issue 3).

Cheap, recommended, may stand: T4 `_guarded` `jetcad.library`
FormatException -> rule 2 and V12a's y; T6 `tool:sample` for
`!rest.contains('.')`; T9 `parseSnapshot`'s doc ("canonical" is only
whitespace, and an int-written number reads as changed: fails closed);
T11 pubspec name vs directory (folded into issue 6).

May stand: T1 (test support, fails closed), T2 (the re-export is proven at
compile time by `sample_kit.dart`/`example.dart` importing only
`authoring.dart` and naming `UnitKinds`, `KitNames`), T3, T5, T6 duplicates,
T7 (issue 9), T8, T9 remainder (`catch (e)` mapping an Error to
`catalogInvalid` is the desired behaviour), T10 (the §1 tree is the
umbrella's target shape).

## Declined to judge

- Arc sweep sign and magnitude (negative or beyond 2π accepted): K6 says
  counter-clockwise but K3 is silent and the engine's arc semantics rule.
- A base point beyond 1e6 is accepted (rule 12 says finite only).
- No region fallback for locales (`de_AT` -> `de`): a recorded plan decision.
- `KitNames`, `PlanKit`, `SymbolEntry` without value equality; mutable
  `GeometryPayload` buffers inside unmodifiable leaf lists: not required by
  the spec.
- pana lower bounds and the real publish: the wave's (A10).
- The plan document's own text beyond what the code embodies.

## Assessment

**Ready to merge: with fixes.** The package is sound, faithful to K1-K9 and
well tested; issues 1-3 are small and mechanical (a CI run, three fixtures,
a paragraph), issue 4 is one spec line. Nothing in the API needs a breaking
change before sub-project 2 that cannot be done additively, provided R1-R3
are settled in its spec before the wave publishes 0.1.0.
