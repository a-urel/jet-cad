# Task 4 review (478c6dc) - independent

Verdict: Approved. No blocking or major findings.

Gates (mine): app `03:17 +683: All tests passed!`, analyze No issues, format 0 changed; engine `00:21 +1121 -2` (standing 2); render `00:56 +974 ~1 -7` (standing). git status: only packages/jet_cad/analysis_options.yaml; every mutant restored (diff exit 0).

Findings
1. MINOR symbol_placer.dart (capabilities set {structure, geometry, components}): derived from the commands, asserted in P5; I found no mutant that changes it without another test failing. No action.
2. INFO D14: a found definition is reused even if its leaves were edited (symbol_placer.dart lookup, ~line 84); matches spec D6 step 1 / D14 known limit, documented in the class comment.
3. INFO payload aliasing: `payload: leaf.payload` is shared with the library entry, but GeometryStore copies on add (geometry_store.dart:95-96), so a placement cannot mutate the entry. Not separately tested; engine guarantee.
4. INFO P10 (target document holding handles the library uses): covered; M-09i (leaves keep library handles) is red on P5, P10, P11.
Transform: code and P1 agree with translation(at).rotation(q*90).scale(m,1).translation(-base), verified independently (Transform2.multiply applies the argument first; expectedWorld in the test is written without Transform2). Mirror flips local x for every turn (P4, det -1); -0.0 normalised (P3, P14).

Not found uncaught: instance parent/layer, definition name, component attach and fields, basePoint, label, each leaf record field (layer, linetype, colour, lineweight, transparency, flags), leaf order, handle allocation order, orphan-component guard, version in lookup, #2 suffix. One parent mutant (parent = definition) fails through CycleDetectedError across the suite rather than a named parent assertion; P6 asserts `inst.parent == rootHandle`.

# Task 4 review (478c6dc) - PARTIAL (container restarted once; gates/mutants pending)

Code read: placementTransform matches spec formula. Transform2.multiply(a.multiply(b) = a.b, argument first) verified in transform2.dart:62; Transform2.rotation = (cos, sin, -sin, cos) so the exact-table matrix (cos[q], sin[q], -sin[q], cos[q]) is the same convention. Test P1 checks against an independent expectedWorld (mirror local x, rotate (x,y)->(-y,x) for q=1, add at) for q 0-3 mirrored/not with off-origin base and at; P3 pins exact 0/+-1 and no -0.0; P4 pins det -1 and local +x under q=1 mirrored -> (0,-1). Handles are allocated at construction (placer lines ~84-127), not in commands.

## Mutant log (raw, mine; restored-ok = diff vs backup exit 0)
Gates: app `03:17 +683: All tests passed!`, analyze No issues, format 0 changed; engine `00:21 +1121 -2`; render `00:56 +974 ~1 -7`.
batch 1: M-09a (no -basePoint): RED P1 | scale-before-rotate order (M-09v family): RED P1, P4 | M-09c drop rotation: RED P1, P2, P4 | M-09c drop mirror: RED P1, P4. all restored-ok
batch 2: mirror flips y: RED P1,P4 | M-09n rotation(rad): RED P3,P4,P14 | -0.0 not normalised: RED P3,P14 | q not modulo: RED P2 | M-09b copy every time: RED P8c,P11,P15 (+others). all restored-ok
batch 3: M-09h ignore version: RED P11 | orphan guard off: RED P13 | M-09i leaves keep library handles: RED P5,P10,P11 | M-09t no #n suffix: RED P12 | (my first M-09e text was a no-op, GREEN, not counted; redone below)
batch 4: M-09e real (AddDefinitionCommand omitted): RED P8c,P9,P10,P11,P12 (+more) restored-ok | suffix starts at 3: RED P12 | name not key@version: RED P11,P12,P15 | definition basePoint dropped: RED P6 | component category altered: RED P6 | (my 'component not attached' text was a no-op, GREEN, not counted; redone below)
batch 5: component not attached (real): RED P8c,P9,P10,P11,P12 ... restored-ok
batch 6: component tags altered: RED P6 | instance parent = definition: RED (CycleDetectedError throws across the suite; a cruder mutant than parent=other node, not isolated to a test) | instance layer: RED P6 | label: RED P5 | leaf colour altered: RED P6 | leaf lineweight altered: RED P6. restored-ok
batch 7: leaf flags/linetype/layer/transparency altered: RED P6 each | leaves reversed order: RED P6,P16 | M-09f1 instance first: RED P9,P10,P16. restored-ok
batch 8: M-09d colour/lineweight/transparency/linetype/linetypeScale: RED P8 (its own field) and P8c each | M-09o descending leaf handles: RED P5,P6,P16. restored-ok
