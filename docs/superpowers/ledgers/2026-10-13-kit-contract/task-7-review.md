# Task 7 review (commit 0395b061, base 6ab88e8b)

## Spec Compliance
Compliant. The four files match the brief (code verbatim, then formatted), the exports are in place, the commit trailer is exact, F11 is honoured (components built and validated at builder.dart:30-52 before DraftDocument.empty() at :53). The handle order is definition, its leaves, next definition, in catalog order (:58-86). Leaf attributes are layer 0 / BYBLOCK / flags 0 (K3 rule 14). The empty catalog builds (B7).

## Strengths
- B2 asserts exact handle arithmetic and owner order, not just sortedness; B3 uses off-origin points, a negative-sweep arc, assigned labelling, and a versioned key.
- B5 pins three distinct decoder rules (6, 11, 15) through encodeLibrary; B6 pins the constructor ArgumentError path.
- Mutations in the report are each tied to a named test.

## Issues
### Critical
none
### Important
none
### Minor
1. builder.dart:55-92: if doc.commands.execute (or a payload helper) throws after DraftDocument.empty(), the document leaks. F11 covers component validation only, which is handled; geometry-level throws (e.g. NaN radius, empty polyline points) are not. Wrap in try/catch that disposes on throw.
2. builder.dart:109-113: unawaited(doc.dispose()) in finally swallows a dispose failure; acceptable for a generator, noted only.
3. builder_test.dart B3: family drop is covered only by the shared SymbolComponent equality (the M-B3a mutation names attachTo only); fine, not a gap in behaviour.
4. B1 is a fixture-level determinism check (same process, same seed); it does not catch a mutation that depends on cross-process state. Acceptable.

## Assessment
Task quality: Approved.
Reasoning: Faithful to the brief and the F11 ruling, well-mutated tests, no correctness defects found. Only a minor leak on geometry-level throws.
