# PR #11 review fixes — implementer report

Status: DONE_WITH_CONCERNS (concerns at the end). Branch feat/kit-architecture, not pushed.

## Commits

- 9f05eca1 fix(kit): rule 15's zero-length polyline is an O(n) bounding-box test (PR1)
- ddd6d306 fix(ci): check_kit_deps reports an unreadable pubspec as a problem (PR2)
- 2daa1935 docs(kit): CatalogArc's sweep is signed (PR3)
- cc5e6fcc fix(kit,ci): read import directives with the Dart parser (PR4)

## PR1 — rule 15, O(n) and allocation-free

`SymbolLibrary._allWithinTolerance` (packages/jet_cad_2d_kit/lib/src/model/symbol_library.dart)
now takes one pass over `p.coords` (min/max x and y, no `Vector2`) and returns
`maxX - minX <= linear && maxY - minY <= linear` (`Tolerance.standard.linear`).
The refusal message says "its points all lie within a box the tolerance wide and high".
docs/kits.md rule 15 updated to say the same ("all lie in a box the engine's tolerance wide and high").

Semantics: the box test is the pairwise test up to the box diagonal: points
(x, y) and (x + linear, y + linear) are √2·linear apart (loaded before, refused now).
No existing test changed outcome (V15aa, V15ab, V15ac, V15ad all green unchanged);
only the comments of V15aa/V15ac were rewritten to name mutations of the new check.

New tests (test/model/symbol_library_test.dart):
- V15ae 200k coincident points (120, 340) refused, with a `Stopwatch` bound of 5 s around `decode`.
  A test `timeout:` cannot interrupt a synchronous decode (tried first: under the pairwise
  mutation a 400k-point test with a 10 s timeout ran 2:27 and passed), hence the stopwatch.
  Real code: about 40 ms here for 200k (72 ms measured for 400k).
- V15af 100k coincident points plus a last one 2·linear away loads (pointCount 100001).
- V15ag a vertical and a horizontal 2-point polyline 2·linear long load.

Mutations (on committed 9f05eca1, each reverted with `git checkout --`, `git diff --quiet` exit 0 → `clean=0`):
- M-V15ae, the former pairwise loop restored:
  `00:36 +107 -1: rule 15: leaf geometry (ported R20-R27e) V15ae a polyline of 200k coincident points is refused, fast [E]`
  `  Expected: a value less than Duration:<0:00:05.000000>` / `    Actual: Duration:<0:00:36.495528>`
- M-V15aa drop (`return false;`): V15aa [E], V15ab [E], V15ae [E] (`00:00 +109 -3: Some tests failed.`)
- M-V15aa compare with 0: `00:00 +103 -1: ... V15aa a polyline of three points within linear of each other [E]`
- M-V15ac box of the first two points (`&& i < 4`): V15ac [E], V15ad [E], V15af [E]
- M-V15af loop one point short (`i + 3 < c.length`): V15ac, V15ad, V15af, V15ag vertical, V15ag horizontal [E]
- M-V15ag `||` for `&&`: V11d, V11e, V15ac, V15af, V15ag vertical, V15ag horizontal [E]
- M-V15ag width only: `V15af ... [E]`, `V15ag a vertical polyline 2 * linear long loads [E]`
- M-V15ag height only: V11d, V11e, V15ac, `V15ag a horizontal polyline 2 * linear long loads [E]`

## PR2 — kitDepsProblems guards loadYaml

tool/ci/lib/kit_deps.dart: `loadYaml` in try / `on YamlException catch (e)`; problem
`'${p.dir}: pubspec.yaml is not readable YAML: ${e.message}'`, then `continue`.
`PackageSource` gained a required `dir` (the script passes `d.path`; the test helper passes the name).
The two other pubspec problems ("a pubspec that is not a map", "a pubspec without a name")
now also carry the `<dir>:` prefix (they had no package named at all).

Tests (tool/ci/test/kit_deps_test.dart): D17 (unit: `'name: {\n'` in dir `cinema`, then a kit naming the plan:
both reported, first starts with `cinema: pubspec.yaml is not readable YAML: ` plus a message);
D18 (script: `cinema/pubspec.yaml` = `name: {` → exit 1, stderr names it).

Mutations (on ddd6d306):
- M-D17a no guard: `00:00 +9 -1: the rule D17 ... [E]`, `00:03 +14 -2: the script D18 an unreadable pubspec: exit 1, its directory named [E]`
- M-D17b `return problems` for `continue`: `00:00 +9 -1: the rule D17 a pubspec that is not readable YAML is a problem, not a throw [E]`
- M-D18 script skips a nameless pubspec: `00:03 +15 -1: the script D18 an unreadable pubspec: exit 1, its directory named [E]`

## PR3 — CatalogArc's sweep is signed

catalog.dart: "An arc from the angle [start] through the signed [sweep], both in radians:
a positive sweep turns counter-clockwise from [start], a negative one clockwise."
docs/kits.md: "`CatalogArc` (from `start` through a signed `sweep`, in radians: positive
counter-clockwise, negative clockwise)". Matches the engine (jet_cad_2d geometry/distance.dart:76-77).
Doc-only: no test, no mutation. doc_snippets_test green (kit suite 250/250 after the commit).

## PR4 — directives parsed with package:analyzer

Both readers now use `parseString(content: text, throwIfDiagnostics: false).unit.directives`:
`NamespaceDirective` → `uri.stringValue` plus every `configurations[i].uri.stringValue`;
`PartDirective` → `uri.stringValue`; anything else (part of, library) → nothing; null stringValues dropped.
- packages/jet_cad_2d_kit/test/support/import_walker.dart: new `directiveUris`, the walk loop iterates it.
- tool/ci/lib/kit_deps.dart: new `directiveUris`; `importedPackages` keeps its signature
  (anchored `^package:([a-z0-9_]+)/` on each URI).
- Dependencies: `analyzer: ^13.3.0` (the workspace lock already resolved analyzer 13.3.0, transitive)
  under `dev_dependencies` of jet_cad_2d_kit (pubspec line 29, after `dev_dependencies:`; not under
  `dependencies`) and under `dependencies` of tool/ci. `flutter pub get` at the root: `Got dependencies!`;
  `git status --short` afterwards showed only the two pubspecs (no analysis_options.yaml).
  pubspec.lock is git-ignored (`.gitignore:3:*.lock	pubspec.lock`).

Tests: purity_test P6 (`import/*c*/'package:flutter/widgets.dart';` and `export // c\n 'dart:io';` both reported),
P7 (block-commented import and `'''`-string export: no violation), P8 (a part is followed), P5 kept
(conditional import) with its mutation named. kit_deps_test D19 (comment between keyword and URI, import and
export), D20 (block-commented import, directive-shaped multi-line string: no problem), D8 extended with
`part 'package:e/w.dart'`; D5 (conditional) unchanged.

Mutations (on cc5e6fcc):
- M-P6/M-P7 walker restored to its 2daa1935 (regex) text:
  `00:00 +4 -1: P6 a comment between the keyword and the URI hides nothing [E]`
  `00:00 +4 -2: P7 a commented-out directive and a directive-shaped string are none [E]`
- M-P5 drop configurations: `00:00 +7 -1: P5 a conditional import's second URI is read [E]`
- M-P8 drop PartDirective: `00:00 +6 -1: P8 a part is followed [E]`
- M-D19/M-D20 kit_deps `importedPackages` back to the regex:
  `00:00 +10 -1: the rule D19 a comment between the keyword and the URI hides nothing [E]`
  `00:00 +10 -2: the rule D20 a commented-out directive and a directive-shaped string [E]`
- M-D5 drop configurations: `00:00 +4 -1: the rule D5 imports under lib, test and tool, every directive kind [E]`
- M-D8 drop PartDirective: `00:00 +12 -1: the rule D8 importedPackages reads directives only [E]`

## Gates (final, on HEAD cc5e6fcc, clean tree)

packages/jet_cad_2d_kit:
- `flutter test` → `00:02 +253: All tests passed!`
- `flutter analyze` → `No issues found! (ran in 4.1s)`
- `dart format --output=none --set-exit-if-changed .` → `Formatted 48 files (0 changed) in 0.07 seconds.` exit 0
- `dart pub publish --dry-run` → `Total compressed archive size: 57 KB.` / `Validating package...` /
  `The server may enforce additional checks.` / `Package has 0 warnings.` exit 0

tool/ci:
- `dart test` → `00:40 +114: All tests passed!`
- `dart analyze --fatal-infos lib test expect_failures.dart check_guide.dart check_host_lock.dart package_root.dart check_screenshots.dart check_readmes.dart check_kit_deps.dart` (CI's list) → `No issues found!`
- `dart format --output=none --set-exit-if-changed <CI's list incl. host_probe/lib ../readme_probe/lib>` → `Formatted 25 files (0 changed) in 0.03 seconds.` exit 0

Repo: `dart run tool/ci/check_kit_deps.dart` → `kit dependencies: 1 package(s) checked, none names the plan library or another kit` exit 0.

## Concerns

1. tool/ci's `dart test` went from about 6 s to 40 s: every script test runs `dart run check_kit_deps.dart`,
   which now JIT-compiles analyzer (the repo check alone: 5.3 s wall). CI cost, not correctness.
2. A bare `dart analyze --fatal-infos` in tool/ci (no path list) reports 3 errors in host_probe/lib/main.dart
   (`restaurant_names.dart` does not exist: a git-ignored generated file). Pre-existing, not touched; CI analyses an
   explicit list that excludes host_probe, and that list is clean.
3. PR1 changes rule 15's meaning slightly (box, not pairwise distance; differs only up to the box diagonal, as
   the ruling says). docs/kits.md is updated; the spec's K3 rule 15 text and its amendment
   (docs/superpowers/specs/2026-10-13-kit-contract-design.md:166-168, 382-384) still say "within
   Tolerance.linear of each other" — left for the controller (binding authority, not mine to amend).
4. analyzer 13.3.0 declares `sdk: ^3.11.0` while the kit says `sdk: ^3.6.0`; it is a dev_dependency only, the
   publish dry-run reports 0 warnings, and the workspace resolves it.

## Follow-up: spec amendment (concern 3)

- ec365c03 docs(spec): rule 15's zero-length test is a bounding box (PR review)
- docs/superpowers/specs/2026-10-13-kit-contract-design.md: K3 rule 15 now reads "a polyline under 2 points or
  whose points' bounding box has width and height both at or under `Tolerance.linear` (amended by the final review
  and the PR review)"; the final review's rule-15 amendment is reworded to the box (noting its first wording); a new
  section "Amendments from the PR review (2026-10-13)" records PR1–PR4 in one line. Staged by explicit path; doc
  only, no gate affected. Not pushed.

## Follow-up: script-test timeout (re-review risk)

- 2384017b test(ci): the script tests allow analyzer's cold compile
- tool/ci/test/kit_deps_test.dart: the `the script` group (every test spawns `dart run check_kit_deps.dart`)
  now has `timeout: const Timeout.factor(4)`, with a comment on analyzer's cold compile. It is the only group
  that needs it: of the scripts the tool/ci tests spawn (scripts_test.dart: expect_failures, check_guide,
  check_host_lock, package_root; kit_deps_test.dart: check_kit_deps), only check_kit_deps reaches analyzer
  (lib/kit_deps.dart is the only analyzer importer).
- Gates: `dart test` → `00:40 +114: All tests passed!`; CI-list `dart analyze --fatal-infos` → `No issues found!`;
  CI-list `dart format --output=none --set-exit-if-changed` → `Formatted 25 files (0 changed) in 0.03 seconds.` exit 0.
