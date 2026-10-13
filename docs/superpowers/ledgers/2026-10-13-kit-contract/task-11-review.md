# Task 11 review (K9)

### Spec Compliance
- Spec compliant. All four files match the brief; the diff touches only the listed files. ci.yml has exactly the four additions (Analyze line, Format line, new step, publishable entry). The Format line was re-wrapped with `host_probe/lib` on its own line; the folded `>-` scalar yields the same command.
- Cannot verify from diff: the `package` matrix entry for jet_cad_2d_kit (Task 1) and any standing-list entry it needs. The matrix entry is visible in the current ci.yml and is present.

### Strengths
- Rule logic is small and separated from I/O (lib/kit_deps.dart vs check_kit_deps.dart), so it is testable on in-memory fixtures and, for D9-D12, through the real script on temp trees.
- Directive regex reads `[^;]*`, so conditional URIs are scanned and comments and string literals are ignored. D5 and D6 target the right mutations. Output is sorted, so it is deterministic.

### ci.yml look (named risk)
- New step is placed after check_readmes and before the README probe, with the same shape as sibling steps (`run: dart run tool/ci/...`, root cwd, no working-directory). Analyze and Format lists both gained check_kit_deps.dart. `publishable` matrix gained packages/jet_cad_2d_kit in sorted position. The job's `cmp LICENSE` and `dart pub publish --dry-run` steps are generic over `matrix.package`, so the new entry needs nothing more. YAML structure and indentation are valid.

### Issues
#### Critical / Important
- None.
#### Minor
1. tool/ci/lib/kit_deps.dart:~28 `_directive` anchors at line start, so a directive-looking line inside a block comment or a multi-line string would be read as an import (false positive, fail-safe direction). A `;` inside a URI would truncate a directive. Neither is realistic.
2. tool/ci/check_kit_deps.dart: a package dir whose directory name matches but whose pubspec `name` differs is checked by pubspec name, so it is silently skipped when the name is not a kit. Matches the stated plan decision.

### Assessment
**Task quality:** Approved
**Reasoning:** Matches the brief, mutations and gates are credibly reported, and the CI wiring mirrors the sibling checks.
