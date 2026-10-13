# Task 10 review (5c29a554..8cff5dd5)

### Spec Compliance
- Spec compliant: all five listed files have hunks; the brief's text is delivered verbatim. Trailer is exactly `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Cannot verify from the diff: `tool/ci/check_kit_deps.dart` (docs/kits.md section 1) does not exist yet (Task 11 / K9); the controller should confirm Task 11 lands it before the doc is published.

### Strengths
- Every rule and name I checked is true of the code: key pattern (kit_ids.dart `{2,}` = kit id + 2 or more segments), version >= 1, 15 rules and their numbers (symbol_library.dart), word ids `symbol:<key>` / `category:<kit>/<English>` (kit_names.dart), PlanKit.validate coverage, conformance problem list (conformance.dart), `updateSnapshot` add-only, `registerKitComponents` registers exactly four, semver steps match umbrella lines 444-446, A16 key/version rules match.
- The catalog block in docs/kits.md and README.md is a verbatim substring of example.dart (checked by script, both True). The example has a test; E1 would go red under M-E1 (5 leaves -> 7).

### Issues
#### Important
1. docs/kits.md section 7 (generator) and section 8 (conformance test) snippets do not compile as written: `File` without `import 'dart:io'`, no `authoring.dart` import in the generator (`encodeLibrary`, `parseSnapshot`, `updateSnapshot`, `geometrySnapshot`, `encodeSnapshot`), no `flutter_test` import in the test (`test`, `expect`); the section 6 PlanKit snippet has no `jet_cad_2d_kit.dart` import. These are the published authoring path and are not covered by example_test (only `buildCafeCatalog` is). Fix: add the import lines to each snippet (or state "imports elided" explicitly), ideally put the generator/test snippets in example/ so a test or analyze covers them.
#### Minor
2. docs/kits.md section 1 tree places `jet_cad_2d_kit` under `jet_cad_2d_flutter`, but pubspec.yaml does not depend on it (global constraint: sub-project 2 adds it). Say "will depend" or drop the nesting for now.
3. docs/kits.md section 1 cites `tool/ci/check_kit_deps.dart` as failing CI; it does not exist until Task 11 (see Spec note).
4. Generator snippet writes `assets/cafe.jetlib` without creating `assets/`; first run on a fresh kit throws PathNotFoundException. Add `createSync(recursive: true)` of the parent.
5. docs/kits.md section 5: "English is required for every word with no stored English." reads ambiguously (means tool/type/property words); and `conformance` throws ArgumentError when `locales` lists `en` (conformance.dart), which section 8 does not mention.
6. Report says RED step skipped (test and example created together); no impact on the delivered state.

### Assessment
**Task quality:** Approved with fixes recommended (item 1 before the doc is published/dry run).
**Reasoning:** Content is accurate against the code and the example is tested; the only substantive gap is uncompilable, untested snippets in a published doc.
