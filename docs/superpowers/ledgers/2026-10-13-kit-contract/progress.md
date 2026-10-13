# SDD ledger — plan: docs/superpowers/plans/2026-10-13-kit-contract.md

Spec: docs/superpowers/specs/2026-10-13-kit-contract-design.md (umbrella: 2026-10-13-kit-architecture-design.md)
Branch: feat/kit-architecture, plan committed at c9c6929

## Pre-flight scan (preflight.md, 13 findings) — rulings

- Ruling: F1 add `import 'dart:typed_data';` to T6 sources_test — will not compile otherwise — cost: none.
- Ruling: F2 M-D5's fixture puts an allowed package URI first so firstMatch misses the forbidden one — mutation must be able to survive-check — cost: none.
- Ruling: F3 T1 adds the jet_cad_2d_kit CI matrix entry (SC16) and runs `cd tool/ci && dart test` in its gate; T11 keeps the rest of the CI changes — no silently red commits — cost: T1 slightly larger.
- Ruling: F4 every `git add` lists explicit files (Global L25 wins over the task text) — cost: none.
- Ruling: F5 positive controls, premises and fixture-sanity tests are exempt from naming a mutation; M-B1 and M-V0a2 are added to their Step lists — CLAUDE.md's bar targets behaviour tests — cost if wrong: a few unpinned sanity tests.
- Ruling: F6 fix the V0a comment (the sort-by-key is the effective mutation) and M-F15's rationale (catalogInvalid); conformance check 6 is documented as shadowed by K2 constructors and kept as defence in depth — cost: none.
- Ruling: F7 docs/kits.md snippets use the example's `buildCafeCatalog()` and words the cafe kit has; Step 5's name check covers them — cost: none.
- Ruling: F8 accept `SymbolLibrary.kits` (a list, for merged libraries) and add a spec amendment line — merge spans kits — cost: none.
- Ruling: F9 "five edits" wording — cost: none.
- Ruling: F10 no /tmp copies: regenerate committed files and check `git diff --quiet` — Global L27 — cost: none.
- Ruling: F11 buildLibraryDocument builds and validates components before creating the DraftDocument (or disposes on throw) — no leak — cost: none.
- Ruling: F12 fold the duplicated foreignWordId block; `_sameBytes` uses the engine/collection `listEquals`; the directive regex copy across packages stays — cross-package sharing would break the dependency rule — cost: none.
- Ruling: F13 the new package's analysis_options.yaml is committed once in Task 1 — the human chose it in chat ("Bir kez commit edilsin") — cost: none.
Task 1: BASE 178cd98f (plan after pre-flight: 178cd98)
Task 1: implementer dispatched (sonnet, agent a7e756b0162a05ad3)
Task 1: implementer DONE_WITH_CONCERNS, commit amended for the trailer -> 65a16f04
- Ruling: jet_cad_2d generate_document_test (2 hash tests) and jet_cad_2d_flutter text-ladder goldens fail locally — the hash test fails identically on the clean main checkout (1b4670b), so it is environmental, not this branch; CI (Linux) is the arbiter — cost if wrong: a real regression hidden until CI runs.
- Ruling: implementers write the trailer exactly "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" (the human's rule) — cost: none.
Task 1: minor (deferred): import_walker package: URI without '/' throws RangeError instead of reporting a violation
Task 1: minor (deferred): import_walker directive regex not comment-aware (fails closed)
Task 1: complete (commits 178cd98..65a16f0, review clean; the cross-package failures settled by the ruling above)
Task 2: BASE 65a16f0
Task 2: implementer dispatched (sonnet, agent a99033fe0d9546288)
Task 2: minor (deferred): no blank (whitespace) category test — dropping .trim() on category survives
Task 2: minor (deferred): UnitComponent fromJson: missing-field messages unasserted; no mistyped-kind / unknown-field case
Task 2: minor (deferred): no test proves authoring.dart re-exports the model
Task 2: minor (deferred): tags admit interior tabs/newlines (unpinned)
Task 2: complete (commits 65a16f0..1a70657, review clean)
Task 3: BASE 1a70657
Task 3: implementer dispatched (sonnet, agent a6b04ec875640465f)
Task 3: minor (deferred): report quotes "[E]" markers instead of red lines for mutations (process)
Task 3: note for Task 4: Library/Manifest fromJson throw ArgumentError (not FormatException) on well-typed invalid values — the guarded decoder must map ArgumentError too
Task 3: complete (commits 1a70657..eff670d, review clean)
Task 4: BASE eff670d
Task 4: implementer dispatched (opus — 1258-line brief, fifteen rules; agent adf18db50c1be5cf5)
Task 4: minor (deferred): rule 15 tolerance boundaries unpinned — `<= 0` for radius and exact equality for zero-length line survive (add radius linear/2, exactly linear, a line linear/2 long)
Task 4: minor (deferred): _guarded jetcad.library FormatException → rule 2 untested; V12a only makes x non-finite (y check survives)
Task 4: minor (deferred): V6a also breaks rule 7 (comment); many refusal tests name no mutation (implicit "drop the check"); model.dart export order not alphabetical
Task 4: complete (commits eff670d..07d8d75, review clean)
Task 5: BASE 07d8d75
Task 5: implementer dispatched (sonnet, agent a0cb17453cd9bc2be)
Task 5: minor (deferred): merge's kits dedupe (`!kits.contains(kit)`) untested
Task 5: minor (deferred): KitNames.words and merge's inner maps mutable under @immutable
Task 5: complete (commits 07d8d75..d7f8105, review clean)
Task 6: BASE d7f8105
Task 6: implementer dispatched (sonnet, agent a9a1a21a4895d66dd)
Task 6: note — pre-flight F1 was wrong: flutter/services.dart does provide Uint8List (analyzer: unnecessary_import); the implementer dropped the import
Task 6: minor (deferred): `!rest.contains('.')` in PlanKit's foreign-word check survives (add `tool:sample` to K4's ids)
Task 6: minor (deferred): missingEnglish reported once per non-English locale (duplicates; spec silent); foreign tool word skips missingEnglish
Task 6: complete (commits d7f8105..6ab88e8, review clean)
Task 7: BASE 6ab88e8
Task 7: implementer dispatched (sonnet, agent aeabad1e8c9404271)
Task 7: minor (deferred): buildLibraryDocument leaks the document if a command/payload throws after it exists (try/dispose); unawaited dispose in finally hides a failed dispose
Task 7: minor (deferred): B1 determinism only in-process
Task 7: complete (commits 6ab88e8..0395b06, review clean)
Task 8: BASE 0395b06
Task 8: implementer dispatched (sonnet, agent ae2a6c28bc256fb2a)
Task 8: minor (deferred): rect/inset/poly/stoolAt now clean coordinates (intended; equal for whole-mm inputs); chairsAround cleans twice (harmless)
Task 8: complete (commits 0395b06..21d14ff, review clean)
Task 9: BASE 21d14ff
Task 9: implementer dispatched (opus — 952-line brief; agent a7e84c1b22197033a)
Task 9: session ended mid-task; implementer had committed b4e973a and left a mutation (libraryKitMismatch check deleted) in conformance.dart — controller reverted it with git checkout (committed file, no other work); implementer resumed
Task 9: review — spec ✅, 1 Important: F19 fixture always has the newest version last, so "last version wins" survives (add stool v2 before v1)
Task 9: minor (deferred): parseSnapshot doc claims canonical re-encoding (only whitespace; fails closed)
Task 9: minor (deferred): `_number` on arc start/sweep unpinned; encodeSnapshot `..sort()` unpinned; no end-to-end generated(moved) → snapshotChanged; catch(e) around encodeLibrary also catches Errors
Task 9: fix round 1/5 (1 addressed, 0 open; commits b4e973a..5c29a55)
Task 9: complete (commits 21d14ff..5c29a55, review clean after round 1)
Task 10: BASE 5c29a55
Task 10: implementer dispatched (sonnet, agent aeb11609ed43fea38)
Task 10: review — spec ✅, 1 Important: docs/kits.md §6/§7/§8 snippets lack their imports (dart:io, authoring.dart, flutter_test, jet_cad_2d_kit.dart) and are untested
- Ruling: the doc snippets must be complete and analysed (plan text gave them without imports; the human's rule: README snippets are verified by analysis against the barrels they import) — move the generator, conformance-test and PlanKit snippets into example/ files that `flutter analyze` covers, and quote them in docs/kits.md with their imports; the generator creates its assets/ directory — cost: Task 10 slightly larger.
Task 10: minor (deferred): §1 tree nests jet_cad_2d_kit under jet_cad_2d_flutter before sub-project 2 adds that dependency; §5 "English required" sentence ambiguous; §8 omits ArgumentError for `en` in locales
Task 10: ⚠️ resolved — tool/ci/check_kit_deps.dart is created in Task 11 (same branch)
Task 10: fix round 1/5 (1 addressed, 0 open; commits 8cff5dd..3b19567)
Task 10: complete (commits 5c29a55..3b19567, review clean after round 1)
Task 11: BASE 3b19567
Task 11: implementer dispatched (sonnet, agent a435b8f0dbe3a2517)
Note: the human asked to be told as soon as apps/architecture_demo is testable on the new packages (end of sub-project 3), and tests everything after sub-project 4 ("evet, teste hazır olunca haber et")
Task 11: minor (deferred): kit_deps directive regex not comment-aware (fails safe); a pubspec name differing from its directory is skipped silently
Task 11: complete (commits 3b19567..b069a3f, review clean)
Task 12: BASE b069a3f
Task 12: implementer dispatched (sonnet, agent abd03bb69b8cf9454)
Task 12: minor (deferred): results note says "(macOS)" for the goldens (unrecorded), attributes [E] markers to Task 1 too, omits Task 1's one flaky query_allocation_test run, and over-states "every mutation reverted with git diff --quiet" — soften to what the reports record
Task 12: complete (commits b069a3f..fea46c3, review clean)
## Final review
Final review (opus, final-review.md): ready after fixes; 4 Important, 5 Minor; R1-R6 API risks for sub-project 2.
- Ruling: FR1 (CI never ran on the branch) — pushing is the human's word; ask at the finish whether to push the branch for CI before the merge — cost if wrong: a Linux-only failure found after merge.
- Ruling: FR2 fix — rule 15 tolerance boundaries get tests (radius linear/2, exactly linear, just above; a line linear/2 long) — CLAUDE.md Tolerance rule.
- Ruling: FR3 fix — results note states only what reports/ledger record (Task 9 mutation left and reverted by the controller; no "(macOS)"; Task 1's flaky query_allocation run; [E] markers Task 3 only).
- Ruling: FR4 — soften docs/kits.md's "retired symbol leaves the gallery" to say the mechanism is sub-project 2's; record it (an optional `retired` field read as false when absent) as a sub-project 2 input in the spec amendments — cost: none.
- Ruling: FR5 fix docs/kits.md §2 claim (conformance checks keys only today) and add `PlanKit.validate()` is empty to the §9 checklist.
- Ruling: FR6 widen check_kit_deps to every Dart file of the package (umbrella A1 wins) — cost: none.
- Ruling: FR7 add a test that every Dart block of docs/kits.md and the kit README appears verbatim in packages/jet_cad_2d_kit/example/ — keeps docs and code in sync.
- Ruling: FR8 spec gap — amend K3: rule 15 refuses a polyline whose points all lie within Tolerance.linear of each other (zero length); rule 11 refuses a unit outline (closed polyline) whose area is at or under Tolerance.linear² — with one-fault tests — cost: two more refusals.
- Ruling: FR9 fix — buildLibraryDocument disposes its document when building throws.
- Ruling: include the cheap deferred minors: T4 jetcad.library FormatException → rule 2 test and V12a y coordinate; T6 `tool:sample` case; T9 parseSnapshot doc wording.
- Ruling: R1-R6 recorded as inputs for sub-project 2's spec in the contract spec's amendments; no change now — none needs a breaking change if settled there.
Final fix wave: 9 commits fea46c3..6464ad7f (implementer opus a00e7ae5acf34d65f); concerns: FR9 untestable from outside (B8 premise only); FR8 area threshold resolves only near the origin; K9 spec text amended to match FR6; tool/ci/host_probe analyzer errors are the git-ignored probe files' absence (pre-existing)
Final re-review (opus, final-rereview.md): FR2-FR9 and item-4 minors ADDRESSED; no new Critical/Important; FR1 open (the human's call).
- Ruling: parked — FR8's rule-11 threshold (area <= linear²) does not scale with size, so in practice only zero-area outlines are refused (a 600 mm × 1e-9 mm sliver loads) — Ruling: stands for sub-project 1; recorded as a sub-project 2 input to switch to a width test (2·area/perimeter <= linear) — cost if wrong: a degenerate sliver outline loads until then.
- Ruling: parked — a bow-tie outline whose lobes cancel is refused as "encloses no area" — a self-intersecting outline is not a valid unit outline anyway — cost: none.
- Ruling: parked — check_kit_deps skips build/ and .dart_tool/ only at a package's top level, and throws on a malformed pubspec anywhere — both fail closed — cost: a spurious CI failure, never a missed violation.
Final review: complete (fix wave fea46c3..6464ad7, re-review clean, 3 parked).
Finish: the human chose 1 ("1"): pushed feat/kit-architecture (344a417), PR https://github.com/a-urel/jet-cad/pull/11 against main; merge waits for green CI and the human's word
## PR #11 review comments (Copilot, CodeRabbit) — the human: "evet, dördünü düzelt ve push et"
- Ruling: PR1 rule 15's zero-length polyline check is O(n²) with allocations on untrusted bytes — replace with an O(n) bounding-box test (width and height <= Tolerance.linear) — same meaning up to the box diagonal; cost: none.
- Ruling: PR2 kitDepsProblems guards loadYaml and reports a malformed pubspec as a problem (the script's own promise) — cost: none.
- Ruling: PR3 CatalogArc doc says the sweep is signed (negative = clockwise) — cost: none.
- Ruling: PR4 the purity walker and kit_deps parse directives with package:analyzer (parseString(...).unit.directives; namespace, configuration and part URIs), analyzer a dev_dependency of jet_cad_2d_kit and a dependency of tool/ci, never a production dependency — the regex missed `import/*c*/'...'` — cost: a heavier test dependency.
- Ruling: PR re-review Important — tool/ci script tests cold-compile analyzer (~5 s per run; D11 ~10 s locally vs the 30 s default timeout) — add Timeout.factor(4) to the script-test group(s) — cost: a slow test fails later instead of sooner
PR review fixes: complete (commits 344a417..2384017; PR1-PR4 + timeout ADDRESSED, re-review clean); ledger re-archived as the branch's last commit and pushed (the human: "evet, dördünü düzelt ve push et")
