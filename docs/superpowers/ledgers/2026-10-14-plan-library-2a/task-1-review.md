# Task 1 review: engine seams E1, E3, E4 (aee66cb7..3d84a62c)

### Spec Compliance

- ✅ Spec compliant. Every file the brief names has its hunk, and nothing else changed (diff stat: 11 files, all under `packages/jet_cad_2d`; `jet_cad_2d_flutter` and the old packages are untouched).
  - E1: `typeIds => {for (final t in _types) t.typeId}` and `typeIdOf => _naming(target, _types, group)?.typeId` (parametric_system.dart:561-576 in the diff), with the brief's doc comments, placed after `objectsOf`. `_naming` (regeneration.dart:18-26) checks root-level `GroupNode` first, then the last registration that `has` it. That is the rule the plan decision names.
  - E3: new `lib/src/core/partial_mutation_error.dart` matches the brief word for word. The barrel export sits between `list_equality` and `tolerance`. All four throws are converted (commands.dart:1006, regeneration.dart:735, :793, :1040). `grep -rn "partially" lib` now lists exactly the 4 throws plus the 3 doc comments, and `grep -c "PartialMutationError("` gives 5: the 4 throws plus the constructor. Messages are unchanged. The imports go into `commands.dart` and `parametric_system.dart`, as the brief says (`regeneration.dart` is a part file).
  - E4: `loadJson(json, {List<Diagnostic>? diagnostics})` matches the brief's body. The `diagnostics == null` path calls the factory with no try, so it behaves as before. With a list, only `factory(payload)` is inside the try: `Handle.checked`/`int.parse`/payload cast and the store `set` stay outside it, so a malformed file still fails and only the factory's throw is absorbed. `catch (error)` catches `Error` too. The `toJson` reorder (unknown payloads first, registered values second) carries the brief's comment.
  - E4 plumbing: `keepUnreadableComponents = false` on `decode` and `decodeString`, passed on, and `diagnostics: keepUnreadableComponents ? (diagnostics ?? <Diagnostic>[]) : null` (json_codec.dart:143-146). This follows ruling R-c.
  - CHANGELOG: the `## Unreleased` text matches the brief, between `# Changelog` and `## 0.7.2`. No version bump.
- ⚠️ Cannot verify from diff:
  - The dependents' results (Step 13: kit, flutter, gpu, floor_plan, restaurant_symbols) and the "only standing failures" claim for `jet_cad_2d`. I did not re-run them, per the review rules. The controller should accept them as reported or spot-check `packages/jet_cad_2d_kit` (`SymbolLibrary.decode` is the consumer that E4's opt-in protects).
  - Task 7's `decodePlan` passing `keepUnreadableComponents: true` spans tasks. Check it at Task 7.

### Strengths

- The E4 opt-in keeps the old path exactly as it was (component.dart diff :398-401): no try is added on the null path, so `SymbolLibrary.decode`'s throw is preserved.
- The try in E4 is narrow. It wraps only `factory(payload)` (component.dart diff :402-417), so a store or parse failure is never misreported as `component.unreadable`.
- The E3 tests are real differential fixtures. `_TripTarget`/`_Arm` (partial_mutation_test.dart:48-101) make each rollback fail at a chosen command, and each matcher pins the site-specific message fragment, so the four tests cannot pass on one another's site. Each mutation M-E3a..d goes red at its own test (report table).
- The fixtures are off the origin and rotated, with non-round sizes, and they include a doubly registered type id (`e1Catalog`, catalog_queries_test.dart:18-26) and a root group carrying two registered types. These are the cases that would expose a first-found or no-root-rule implementation (M-E1c/M-E1d).
- E4-1 and E4-5 check byte-for-byte write-back through both `registry.toJson()` and the codec.
- I checked for subclass or `implements` overrides of `ComponentRegistry.loadJson` across `packages/` and `apps/`, because the new named parameter would break one: there are none. The only callers are the codec and the tests.

### Issues

#### Critical (Must Fix)
None.

#### Important (Should Fix)
None.

#### Minor (Nice to Have)

1. `packages/jet_cad_2d/lib/src/document/commands.dart:958` is a 115-column doc-comment line ("than see the child's own exception and conclude nothing happened. The dispatcher pushes no history and emits no"). This diff introduced it. The report's Deviation 1 says the comment was "re-broken … to fit", which is inaccurate for this line. `dart format` does not reflow comments and the analyzer has no line-length lint, so the gates stay green, but the comment block is now ragged. Fix: re-wrap 956-959 at 80 columns. (I checked the other lines over 80 columns in the touched files, commands.dart:363 and regeneration.dart:181 and :443. All three were there before this commit.)
2. No test covers the plan decision "a group whose component `loadJson` kept raw … answers null" from `typeIdOf`. It follows structurally (kept-raw payloads live in `_unknown`, not in a store, so `_Registration.has` is false), and Task 11 depends on it. One line in E4-5 would pin the cross-seam contract: `expect(catalog.typeIdOf(loaded, saved.unreadable), isNull)` with a catalog registering Spar. No named mutation currently guards it.
3. The `toJson` reorder also changes the output of one pre-existing path the brief does not mention, as the implementer's self-review notes: `restore` of a snapshot, or a direct `attachUnknown`, carrying a registered type id on a handle that also has a registered value. The registered value now wins where the raw payload used to. This is consistent with the brief's intent, and before E4 no shipped path produced such a collision. Noted only so the whole-branch review knows the encoding changed for that case too.

### Assessment

**Task quality:** Approved

**Reasoning:** All three seams are implemented exactly as the brief and ruling R-c specify. The old behaviour is kept wherever the opt-in is off, and every mutation the brief names is covered by a test that goes red under it. The remaining items are a comment-wrap slip and one missing cross-seam assertion.
