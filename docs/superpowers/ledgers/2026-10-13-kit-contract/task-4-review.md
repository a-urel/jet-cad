# Task 4 review: SymbolLibrary.decode and K3's fifteen rules

Base eff670d9, head 07d8d752. Read the diff package in two passes: the validator, then the test and fixtures.

### Spec Compliance

- ✅ Spec compliant. All four files match the brief's code blocks. I checked this by flattening whitespace in the three brief blocks (brief lines 30-236, 242-818 and 826-1211) and in `git show 07d8d752:<file>`, then running `cmp`: fixtures, test and validator are identical apart from formatting.
  - `model.dart` gains the export.
  - The commit trailer is exactly `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - Spec K3 rules 1-15, with the amendments (rule 2 units and a misplaced LibraryComponent, rule 9 as a unit with a family, rule 14 as BYBLOCK only, `kits` as a list), are all implemented: `symbol_library.dart` diff lines 173-418.
- Every rule has at least one one-fault test that pins `e.rule` (`expectRefused`, test diff line 449):
  - rule 1: V1a-V1g
  - rule 2: V2a-V2e
  - rule 3: V3a-V3b
  - rule 4: V4a-V4e
  - rule 5: V5a-V5e
  - rule 6: V6a
  - rule 7: V7a-V7b
  - rule 8: V8a-V8g
  - rule 9: V9a
  - rule 10: V10a-V10b
  - rule 11: V11a-V11b
  - rule 12: V12a
  - rule 13: V13a-V13c
  - rule 14: V14a-V14r
  - rule 15: V15a-V15r
  - plus the positive controls V0a-V0g, V6b and V15s.
- ⚠️ Cannot verify from the diff: the green run and the mutation table come from the implementer's report. I did not re-run them, because `flutter test` triggers a workspace `pub get` that rewrites tracked `analysis_options.yaml` files, which would break this review's read-only rule. The handle hexes the report quotes are consistent with the fixtures: 1068 = 4200, 10D6 = 4310, 113A = 4410, 1072 = 4210, 1074 = 4212, 1075 = 4213.

### Strengths

- **Nothing but `SymbolLibraryError` escapes `decode`.** `decode` (validator lines 122-144) wraps `utf8.decode`, `jsonDecode` and the whole codec in `catch (e)`. That clause also catches `Error`s such as a TypeError, a null-check failure or a StackOverflowError, and turns them into rule 1. Guarded refusals are rethrown untouched.
  - I checked the named risk "can `_validate` throw anything else?". Every index access is preceded by its count check: `pointAt(1)` after the line's 4-coordinate check, `scalars[0]` and `scalars[2]` after the circle and arc scalar counts, and `isClosedPolyline` only after `pointCount >= 2`.
  - The `EntityKind` and node switches are exhaustive.
  - `doc` is disposed in `finally`.
  - V1g pins the structural cases and M-V1g proves the `catch` is load-bearing.
- **The codec is checked against the decode path.** `json_codec.dart:93-143` registers components before `components.loadJson`, so the guarded factories run inside the `try`. Diagnostics from `_loadTree` and `_rebuildFills` both feed rule 1.
- **Rule mapping is precise.** `_ruleOf` (validator lines 164-171) maps by the `ArgumentError.name`, and each arm is pinned: V5b-V5e for `key`, V8a-V8f for tags, attachTo and family, V8g for the unit's `kind`, and V2c for the library. V5a's comment and M-V5a show the kit check is not shadowed by rule 7.
- **Tolerance decisions match CLAUDE.md.** Radius and sweep compare against `Tolerance.standard`; closedness uses `isClosedPolyline`, which is exact. The sweep boundary is pinned on both sides and at the bound itself (V15p-V15r, V15s).
- **Fixtures are not degenerate:**
  - base points (900,400), (1250,860) and (510,35);
  - every leaf off the origin;
  - arc start angles 0.25 and 0.5;
  - handles 4200, 4300 and 4400;
  - leaves inserted out of handle order and interleaved across symbols, which V0b proves with a premise check;
  - versions 3, 2 and 1;
  - one unit and one family.
  - The only defaults are the BYBLOCK style, which rule 14 requires.
- **The report is sound.** Its mutation table quotes red lines, and it explains the M-V11a variant (`if (false)` rather than a deletion, which would leave an unused local).

### Issues

#### Critical (Must Fix)
None.

#### Important (Should Fix)
None.

#### Minor (Nice to Have)

1. **Radius and zero-length tolerance are unpinned** (rule 15, `symbol_library.dart` validator lines 398 and 408; test V15j/V15l-V15n).
   - Spec K3.15 says "a radius or sweep at or under `Tolerance`". The sweep has three boundary cases; the radius has only 0.0 and -5.0. So the mutation `p.scalars[0] <= 0` in place of `<= Tolerance.standard.linear` survives, by inspection: V15l, V15m and V15n are still refused, and V0f's 1e-3 is still accepted.
   - Likewise V15j uses identical points, so replacing `isDegenerateSegment` (`distanceTo <= Tolerance.standard.linear`, `drafting.dart:140`) with exact equality survives.
   - Fix:
     - Add a circle radius of `Tolerance.standard.linear / 2` and one exactly at the tolerance (1e-9), expecting rule 15.
     - Add a line whose ends are `linear / 2` apart, expecting rule 15.
     - Name the mutation for each.
2. **Unnamed and unpinned mutations in the guard and in rule 12:**
   - The `FormatException` → rule 2 arm in `_guarded` (validator line 159) has no test. A mistyped library field, such as `'format': '1'`, would reach it through `json_fields.dart`'s FormatException. So the mutation `rule = 1` survives.
   - Deleting the whole `on FormatException` clause also survives V1f: the codec's `catch (e)` still gives rule 1, and the message still contains `"family"`.
   - V12a only makes x non-finite, so dropping `|| !base.y.isFinite` (validator line 253) survives.
   - All three are plan-mandated.
3. **V6a also breaks rule 7** (test diff, rule 6 group). It changes the table's key and version to the sofa's but keeps the table's definition name, so it is a two-fault edit. It reaches rule 6 only because the duplicate check runs before the name check.
   - It still discriminates: dropping the rule-6 check makes it red with rule 7.
   - A comment like V11b's ("two edits: …") would make the dependence on check order explicit. This is plan-mandated.
4. **Many refusal tests name no mutation, against Global Constraint L17** ("every behaviour or refusal test names the mutation that turns it red"):
   - V1a, V1c-V1f
   - V2a, V2c-V2e
   - V3a-V3b
   - V4a-V4c, V4e
   - V6a, V8g, V10a, V12a, V13a, V13b
   - most of V15a-V15o
   - The implicit mutation in each is "drop the check", and each would go red by inspection. This is plan-mandated; it is recorded for the controller rather than as a defect in the implementation.
5. **The export is out of alphabetical order** (`model.dart` diff line 25). `symbol_library.dart` sits before `symbol_component.dart`. The brief's "keep the list alphabetical" contradicts its own "after register.dart" placement, and the implementer followed the placement. It is cosmetic: `directives_ordering` is not enabled, and analyze is clean.

### Assessment

**Task quality:** Approved

**Reasoning:** The validator implements all fifteen K3 rules as amended. Every rule has a one-fault test that pins its rule number. No non-`SymbolLibraryError` throwable can escape `decode`, and the fixtures are off-origin and out of order. The remaining gaps are boundary pins for radius and zero-length tolerance and a few unnamed mutations, all inherited from the plan.
