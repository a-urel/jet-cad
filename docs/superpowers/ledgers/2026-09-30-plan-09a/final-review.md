# Final review plan 09a
VERDICT: Ready with fixes (doc-only: 0 blocking, 0 important, 3 minor, 3 nit)

## 1 Gates (real tails)
engine: 00:16 +1121 -2 ; analyze clean ; format 0 changed
render: 00:47 +974 ~1 -7 ; analyze clean ; format 0 changed
app: 02:59 +780 All passed ; analyze clean ; format 0 changed
web build OK; build/web/assets/assets/library/furniture.jetlib present, cmp identical to assets/library/furniture.jetlib
invariants diff empty; no analysis_options in diff; lib changes exactly as expected.
## 2/3 static audit (so far)
- No dart:io/flutter/dart:ui imports in lib/symbols (comments only); non-ASCII only punctuation in comments. All SHAs in amendment/results exist. `git diff a5e38a0..HEAD -- lib packages` empty (claim true). 29 throw sites = "29 sites" claim true. Footprint of lib changes exactly as expected.
- Spec header line 3 still "design, revision 3" status -- Awaiting approval text to check; minor doc fix.
- Placer: handles ascending (def, leaves, instance); loader sorts leaves by handle; Tolerance used for radius/sweep/zero-length; exact == for stored fields.
## 4 Mutants (final tree, each RESTORED: file diff clean)
T1 Remove owner guard (commands.dart:480 == -> !=): red "RemoveDefinitionCommand refuses while a leaf is owned by it..." + "extents follow a compound placement and its undo"
T1 Add children guard (:430 && false): red "AddDefinitionCommand refuses a definition that lists children, and mutates nothing"
T1 Remove instance guard (:472 == -> !=): red "refuses while an instance names it", "while a node is parented to it"...
T2 registration dropped (catalog.dart:48): red SC7, SC8, SC9, SC10, SC11 (-6 total)
T2 tag-order equality (symbol_component.dart:86 -> true): red SC1, SC2
T3 colour allow-list arm (symbol_library.dart:228 drop ByLayer): red L5 (allow-list accepts every allowed value)
T3 zero sweep == 0 (:291): red R27b, R27c, R27d
T3 children throw (:148 false): red R04 "a leaf handle in children is refused"
T4 M-09a (placer:51 translation(0,0)): red P1 (placementTransform base point lands on at...)
T4 M-09b (placer:83 reuse never): red P7, P8c, P11, P15, P19
T4 M-09i (placer:117 leaves keep library handles): red P5, P10, P11
T4 M-09o (placer:114 leaves reversed): red P16, P19, P6
T5 stale asset (catalog CircleShape(1620,375,15)->16, no regen): red "the asset the committed bytes equal the built library"; file restored, git status clean
T6 M-09c rotation dropped (placer:49) vs symbol_end_to_end_test.dart: red "a real symbol, rotated and mirrored ... painter, pick, snap..." and "the Select tool moves and rotates a placed, mirrored instance"
T3 extra: flags allow (symbol_library.dart:240 false): red R18, R18b. lineweight arm (:232): red L5. T1 Add duplicate-definition arm (commands.dart:425 false): red "refuses a handle that names a definition, a node or an entity".
Total 20 mutants, all red, all restored.

## 5 Cross-task hunts (temporary test apps/floor_planner/test/zz_hunt_test.dart, deleted; git status clean)
PASS: place with ParametricSystem installed + SpatialIndex live: diagnostics/drift/validate empty; containerCount +1; undo restores bytes (modulo handleSeed), containerCount, indexFor(def)==null, no component, no definition, same live entity/node counts and extents; redo restores identical bytes; placing again after undo gets higher handles.
PASS: 3 placements (2 symbols, one twice, rotated/mirrored), purge -> bytes identical; save/load/save byte-identical; components survive; placing on the loaded doc reuses the definitions (2 stay), new handles > all existing, validate empty, undo returns identical bytes.
NOTE: undo does not lower handleSeed, so place+undo+save differs from never-placed in the "handleSeed" field only (existing engine behaviour, handles are never reused). Not a defect.
Web build contains the asset, cmp identical.

## Findings
1 minor docs/specs/2026-09-30-symbol-library-design.md:6 still "Awaiting the human's approval" (approved 2026-09-30); fix header.
2 minor results note M-09u-a cites symbol_component.dart:91 and M-09b cites placer ':84'; the sites are :86 and :83 in the final tree (line refs drift; no claim falsified).
3 minor furniture_catalog.dart `_table`: "Dining table, 4 seats"/"6 seats" are plain rectangle+inset with no chairs; the names claim seats the geometry does not show (only size differs). Worst of the 25 content issues; cosmetic.
4 nit symbol_library.dart:_checkGeometry: circle/arc radius is not bounded by maxCoordinate (scalars only checked finite); a 1e300 radius loads.
5 nit spec amendment/results link ledgers/2026-09-30-plan-09a/ which does not exist until the archive commit (results note says so).
6 nit BYBLOCK leaves under a default instance resolve to ACI 7 / white 0xFFFFFFFF with the default foreground: 09b should check contrast on a light canvas.
No false claims found: SHAs exist, 29 throw sites, 33,423 bytes, lib/ untouched after a5e38a0, gate counts reproduced.
