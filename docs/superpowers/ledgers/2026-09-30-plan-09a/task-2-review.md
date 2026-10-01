# Task 2 review (51a9bda) - independent

Verdict: Approved (two minor findings, non-blocking).

Gates (mine): app `02:22 +608: All tests passed!`, analyze No issues, format 0 changed, `flutter build web --release` "Built build/web"; engine `00:14 +1121 -2` (standing 2); render `00:41 +974 ~1 -7` (standing). git status: only packages/jet_cad/analysis_options.yaml.

Findings
1. MINOR test symbol_component_test.dart SC6 (fromJson missing field): input omits name, category and tags together, and the fields are read in order, so the first absent one (name/category) throws. A mutant tolerating a missing `tags`, `version` or `name` alone stays green (+12 All passed, each fired). Fix: one expectation per omitted field.
2. MINOR symbol_component.dart hashCode: dropping `tags` from the hash stays green; legal (equal objects still hash equal), not a defect. Identity hashCode is caught by SC1.
3. INFO SC10 has no mutant (report says so honestly). Confirmed: SymbolComponent is not in parametricCatalog (catalog.dart diff adds only the import and `SymbolComponent.register(r)` in registerAppComponents); SC11/SC12 claims are true: purge() (draft_document.dart:192-213) compacts geometry/entity slots, invalidates and notifies, never touches components/tree. The fixtures are non-degenerate (handle 4200, basePoint (900,400), off-origin leaves, unsorted tags, version 3, hole at slot 0 so purge moves a slot).

Mutant matrix (my runs, symbol_component_test.dart; backup diff exit 0 each time)
- tags compared by length only: RED SC1, SC2
- equality drops key / category: RED SC1
- toJson key order broken (duplicate key): RED SC5, SC7, SC11
- tags not copied: RED SC3
- empty key accepted / version 0 accepted: RED SC4
- hashCode identity: RED SC1; hashCode drops tags: GREEN (finding 2)
- registration dropped from registerAppComponents: RED SC7-SC12 (+6 -6)
- purge also clears components (draft_document.dart): RED SC11, SC12
- fromJson tolerating missing tags / version / name: GREEN each (finding 1)
