### Spec Compliance
- ✅ Spec compliant (K2 tables, brief interfaces, plan decisions: kit-id first segment, tag outer white space, family always written, unknown fields ignored). Both barrels export model.dart; json_fields.dart is not exported; imports are pure (jet_cad_2d, meta, package-local). Old packages untouched (10 files, all under packages/jet_cad_2d_kit).
- ⚠️ Cannot verify from diff: the report's "+55 passed" / analyze / format results and mutation reds (not re-run, per prompt). No TDD red transcript exists (report admits source was written first); mutation step is the only red evidence.

### Strengths
- Constructor refusals are real ArgumentErrors named by field (symbol_component.dart:36-72), cases table drives one test per refusal (test C5); lists copied unmodifiable before validation, so a caller cannot mutate after the check.
- field<T> (json_fields.dart:9-17) gives FormatException for missing/mistyped, incl. nullable `field<String?>` for family; stringList handles non-string items. C9/C10 iterate every field.
- Fixtures are non-default (version 3, unsorted tags, non-ASCII tags, two kinds, family); pinned JSON text; Review Focus 2 and 3 pinned (C6, C12).

### Issues
#### Critical
none
#### Important
none
#### Minor
1. symbol_component_test.dart: C5 has "a blank name" ('   ') but no blank category; dropping `.trim()` on category (symbol_component.dart:48) survives. Add `'a blank category': ('category', () => sofa(category: '   '))`.
2. unit_component_test.dart U5:70-75: missing-field cases assert only `throwsFormatException`, not that the message names the field; a mistyped `kind` (e.g. 5) is not tested, and no unknown-field-ignored case exists for UnitComponent (the Plan decision applies to it too; unit_component.dart fromJson). Weak against a mutation that refuses unknown keys there.
3. No test imports `package:jet_cad_2d_kit/authoring.dart` to prove it re-exports the model (authoring.dart:6); dropping that export is undetected unless a later task adds it.
4. symbol_component.dart:46 tag check admits inner tabs/newlines ('a\tb', 'a\nb') since only outer white space is refused; spec says spaces allowed, so arguably fine, but an interior control character in a search word is unpinned either way.
5. unit_component.dart:68-74: `labelling` is read first, so a map missing both `kind` and `labelling` reports labelling; harmless.

### Assessment
**Task quality:** Approved
**Reasoning:** Matches K2 and the brief with no scope creep; refusal/equality/JSON behaviour is well pinned with named mutations. Only test-strength gaps remain, none blocking.
