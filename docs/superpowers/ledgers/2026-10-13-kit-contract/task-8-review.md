# Task 8 review (shared shape helpers, K6)

### Spec Compliance
- ✅ Spec compliant. All listed symbols and constants exported (authoring.dart export added); code equals the brief.
- Named risk checked: port geometry vs packages/jet_cad_restaurant_symbols/lib/src/shapes.dart. Constants identical (450/100/190/40, back 60, footrest 150). chairAt: same frame (u,v), same corner order, same back line endpoints, same cleaning. chairsAround: same d = r + 225 - 100, same angle expression (-pi/2 + 2*pi*i/count, same evaluation order), facing a + pi, centre cleaned. stoolsAround: same d; the port cleans the centre inside stoolAt via _p instead of in stoolsAround, giving the same value. stoolAt order seat then 150 ring same. cleanCoordinate identical to _clean. Only intended deviation: rect/inset/poly/stoolAt now clean (brief plan decision; no-op on whole-mm inputs).
- ⚠️ stoolAt now cleans a caller's centre (original did not); documented plan decision, only matters for non-1e-6 inputs.

### Strengths
- Faithful port, `_around` removes the original's duplicated angle expression without changing arithmetic. Tests use off-origin centres and non-axis angles; each mutation is named and was reported red.

### Issues
#### Critical / Important: none
#### Minor
1. shapes.dart `_p` and `cleanCoordinate` double-clean in chairsAround (centre cleaned, then chairAt cleans corners); harmless, same as original.

### Assessment
**Task quality:** Approved
**Reasoning:** Geometry is arithmetic-identical to the restaurant helpers; brief followed exactly.
