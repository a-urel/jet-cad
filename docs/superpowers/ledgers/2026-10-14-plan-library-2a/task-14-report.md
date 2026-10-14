# Task 14 report: attachment, plan.symbol and the move resolver

Status: DONE_WITH_CONCERNS (concerns below are about the brief's fixtures, not open defects).
Base 953356d8. Commits:
- b2a6f29a feat(plan): attachment, plan.symbol and the move resolver (P3)
- 29aaea73 test(plan): MV-2 pins that a symbol attaching nowhere asks no registry

## Implemented

- `lib/src/attach/attachment_registry.dart`: `PlanAttachmentRegistry` (add with a guarded factory, kinds, nearest-marker attach with the earlier winning a tie, keep handed back only to its maker through an `Expando`, `_ask` through Task 11's `guardAttachment`, dispose of Disposable providers).
- `lib/src/attach/attachment_painter.dart`: `paintAttachmentMarker` (the nearest glyph).
- `lib/src/symbols/symbol_box.dart` (port + `footprintOf`), `lib/src/symbols/symbol_ghost.dart` (port).
- `lib/src/tools/plan_symbol_tool.dart`: `PlanSymbolTool`, `kAttachPixels`, `kGhostCrossPixels`; port of `SymbolPlaceTool` over the registry and `SymbolComponent.attachTo`; no WallFaces, no band invalidation.
- `lib/src/tools/move_resolver.dart`: `PlanMoveResolver`, `isOrthonormal`.
- `session.dart` (F1/F2): constructor `moveResolver` passed to `buildGenericTools`; `symbolTool`; `runAttachmentFactories`; `addSymbolTool` (into the map, which alone disposes it); the registry disposed in `disposeKitProducts()` after the grip providers, before the shared cache.
- `plan_controller.dart`: controller-lifetime `_moveResolver`; `_open` passes it, runs the attachment factories right after `_session = session`, adds plan.symbol (canRotate/canMirror read `_permissions.rotate` / `.mirror`), registers its needs, ends with `_reportUnofferedKinds()`; `_allowsTool` refuses plan.symbol with nothing armed; the permissions setter calls `symbolTool.gatesChanged()` when plan.symbol is active and rotate or mirror changed; `_loadSymbols` reports unoffered kinds.
- Mirror (Task 12 carry): plan.symbol's M and its ghost/placement respect `PlanPermissions.mirror` through `canMirror`; pinned by AT-19 (new).
- TestEdge hysteresis (Task 6 carry) is driven by AT-20 (new, tool + registry) and the test kit's edge is now made per document in every testKit controller (C-life1, C-svc).

## TDD evidence

RED (before any lib file existed), `flutter test test/attach test/symbols/symbol_box_test.dart test/symbols/symbol_ghost_test.dart test/tools test/controller/attachment_controller_test.dart test/panels/plan_symbol_gallery_test.dart`, first error:
```
test/attach/attachment_registry_test.dart:8:8: Error: Error when reading 'lib/src/attach/attachment_registry.dart': No such file or directory
test/attach/attachment_registry_test.dart:23:14: Error: Type 'PlanAttachmentRegistry' not found.
```
and the highlight test (compiling) red:
```
00:01 +14 -1: the gallery the highlight follows the active tool and the armed entry (M-09b9) [E]
Expected: 'demo.bed.double@1'
  Actual: <null>
```
GREEN after implementation: the same set first showed 5 failures (4 ghost tests, 1 tool test), all fixture-caused (see Deviations 2 and 3); after the fixture changes, and the two Task 8 expectations updated (Deviation 4):
```
00:05 +393: All tests passed!
```

## Mutations (each on committed files; reverted with `git checkout -- <file>`; `git diff --quiet -- <file>` printed `revert 0` every time)

| Id | File: change | Test | Red line |
|---|---|---|---|
| M-AT2a | registry: `return a;` after `_origin[a] = p;` | AT-2 | `Expected: 'near' Actual: 'far'` |
| M-AT2b | registry: `d < bestDistance` -> `<=` | AT-2 | `Expected: 'near' Actual: 'tie'` |
| M-AT3 | registry: iterate `_byKind.keys` | AT-3 | `Expected: 'w' Actual: 'c'` |
| M-AT4 | registry: `final q = query;` | AT-4 | `Expected: null Actual: <Instance of 'Attachment'>` |
| M-AT5 | registry: `_ask` => `p.provider.attach(q)` | AT-5 | `Bad state: the wall-face provider broke` |
| M-AT6 | registry: delete `disposable.dispose();` | AT-6, AT-14 | `Expected: <1> Actual: <0>` (both) |
| M-AT7 | registry: `add` without its try/catch | AT-7 | `Invalid argument(s): no faces` |
| M-AT20 (new) | registry: `final q = keep == null ? query : (bare ??= _withoutKeep(query));` (keep to nobody) | AT-20, AT-4 | AT-20 `Expected: null Actual: <Instance of 'Attachment'>`; AT-4 `Expected: same instance ... Actual: <null>` |
| M-AT8a | tool: `pointer: _at.point.clone()` | AT-8 | `Expected: Vector2:<[80123.4,-35211.7]> Actual: Vector2:<[80125.3,-35200.7]>` |
| M-AT8b | tool: capture `kSnapAperturePixels / _rawScale` | AT-8 | `Expected: a numeric value within <1e-9> of <320.0> Actual: <200.0>` |
| M-AT9 | tool: `_place` `transform: null` | AT-9 | `Actual: [1.0, 0.0, 0.0, 1.0, 80425.3, -37310.7]` |
| M-AT9b | tool: delete the attached block of `paintOverlay` | AT-9 | `Expected: an object with length of <4> Actual: [Instance of '_InvocationMirror', Instance of '_InvocationMirror']` |
| M-AT10 | tool: drop `|| !_rawObjectSnap` | AT-10 | `Expected: empty Actual: [Instance of 'AttachmentQuery']` |
| M-AT11a | tool: `keep: null` | AT-11; AT-20 | AT-11 `Expected: same instance as <Instance of 'Attachment'> Actual: <null>`; AT-20 `Expected: null Actual: <Instance of 'Attachment'>` (`kept: 250 > 200`) |
| M-AT11b | tool: delete `_attached = null;` in `_onArmed` | AT-11 | `Expected: null Actual: <Instance of 'Attachment'>` |
| M-AT12 | tool: `mayRotate: true` | AT-12 | `Expected: false Actual: <true>` |
| M-MV1a | resolver: `pointer: t.transformPoint(box.backCentre)` | MV-1 | `Expected: Vector2:<[99760.75,-70126.0]> Actual: Vector2:<[99450.25,-70000.75]>` |
| M-MV1b | resolver: `exclude: const {}` | MV-1 | `Expected: Set:[21] Actual: Set:[]` |
| M-MV2a | resolver: drop `|| symbol.attachTo.isEmpty` | MV-2 | first run SURVIVED (`+1: All tests passed!`, see Deviation 6); after 29aaea73: `Expected: <0> Actual: <1>` `no attachTo: the registry is not asked` |
| M-MV2b | resolver: delete the object-snap line | MV-2 | `Expected: null Actual: ({Vector2 marker, Transform2 transform}):<(marker: [1.0,1.0], ...)>` |
| M-MV3a | resolver: `keep: null` | MV-3 | `Expected: same instance as <Instance of 'Attachment'> Actual: <null>` |
| M-MV3b | resolver: `_sync` ignores the state (`identical(doc, _document?.target)` only) | MV-3 | `Expected: null Actual: <Instance of 'Attachment'>` |
| M-AT14 | session: delete `if (registry is PlanAttachmentRegistry) registry.dispose();` | AT-14; C-life1 | AT-14 `Expected: <1> Actual: <0>`; C-life1 red (`Expected: [ ... Actual: SubListIterable<String>:[`) |
| M-AT16 | controller: delete `_reportUnofferedKinds();` in `_loadSymbols` | AT-16 | `Actual: WhereIterable<(String, String?, KitDiagnosticCode)>:[]` |
| M-AT17a | controller: delete the `_armed.value == null` line of `_allowsTool` | AT-17 | `Expected: false Actual: <true>` |
| M-AT17b | controller: `canRotate: () => true` for plan.symbol | AT-17 | `Expected: KeyEventResult:<KeyEventResult.ignored> Actual: KeyEventResult:<KeyEventResult.handled>` |
| M-AT18 | controller: drop `moveResolver: _moveResolver` | AT-18 | `Expected: non-empty Actual: []` |
| M-AT19a (new) | controller: `canMirror: () => true` | AT-19 | `Expected: a value greater than <0> Actual: <-1.0>` (`the ghost drops the stored mirror at once`) |
| M-AT19b (new) | controller: setter checks rotate only (`old.mirror != value.mirror` dropped) | AT-19 | `Expected: a value greater than <0> Actual: <-1.0>` |
| tool mirror (new) | tool: `_mirror => _mirrored` | AT-19 | `Expected: a value greater than <0> Actual: <-1.0>` |
| tool M key (new) | tool: M branch without `canMirror` | AT-19 | `Expected: KeyEventResult:<KeyEventResult.ignored> Actual: KeyEventResult:<KeyEventResult.handled>` |
| M-09b9 | gallery `_selectedId` ignores the active tool | highlight test | `Expected: null Actual: 'demo.bed.double@1'` |
| ported F-16 (sanity) | tool: delete the permission check in `_place` | permissions group | 3 tests `[E]` |
| ported M-DT-8 (sanity) | tool: delete `_markerPaint.color = paper.snap;` | paper set | `Expected: <4284470927> Actual: <4278190080>` |

## Gate outputs (packages/jet_cad_2d_plan, at 29aaea73)

```
flutter test                                        00:05 +393: All tests passed!
flutter analyze                                     No issues found! (ran in 2.9s)
dart format --output=none --set-exit-if-changed .   Formatted 97 files (0 changed) in 0.18 seconds.  (exit 0)
git status --short                                  (empty)
```
No other package touched; no analysis_options.yaml staged or modified.

## Files

Created (lib): `packages/jet_cad_2d_plan/lib/src/attach/attachment_registry.dart`, `.../attach/attachment_painter.dart`, `.../symbols/symbol_box.dart`, `.../symbols/symbol_ghost.dart`, `.../tools/plan_symbol_tool.dart`, `.../tools/move_resolver.dart`.
Modified (lib): `.../controller/plan_controller.dart`, `.../controller/session.dart`.
Created (test): `test/support/attach_fixtures.dart`, `test/attach/attachment_registry_test.dart`, `test/symbols/symbol_box_test.dart`, `test/symbols/symbol_ghost_test.dart`, `test/tools/plan_symbol_tool_test.dart`, `test/tools/move_resolver_test.dart`, `test/controller/attachment_controller_test.dart`.
Modified (test): `test/panels/plan_symbol_gallery_test.dart` (highlight test), `test/controller/lifetimes_test.dart` (Deviation 4).
Nothing new exported from the barrel.

## Deviations from the brief

1. **`Disposable` check in `PlanAttachmentRegistry.dispose`** (compile fix): the brief's `final provider = p.provider; if (provider is Disposable) provider.dispose();` does not compile (`The method 'dispose' isn't defined for the type 'AttachmentProvider'`: Disposable is not a subtype of AttachmentProvider, so no promotion). Written as `if (p.provider case final Disposable disposable)`. Also each provider's dispose is guarded: one that throws is reported (`hookFailed`, subject its kind) and the others are still disposed (spec P4; the session's own `_disposeGuarded` does the same for grip providers). M-AT6 deletes `disposable.dispose();`.
2. **`add` reads `provider.kind` inside the factory's try**: a kit's `kind` getter that throws is the same failure as a throwing factory (no provider, one `hookFailed` subject `attachments`) rather than an escape from `_open`.
3. **Ghost test fixture (A12 finding: the brief's mapping makes ported assertions fail).** With the brief's mapping (`office.chair`→`fixture.sofa.three`, `bath.toilet`→`fixture.nightstand.single`, `dining.table.rect.six`→`fixture.armchair.single`, library = the fixture library) four ported tests fail on asset-tied counts, observed:
   - "the fixtures are not degenerate": `Expected: contains EntityKind:<EntityKind.arc>` (the nightstand has no arc);
   - "a closed polyline's contour is closed": `Expected: <false> Actual: <true> circle leaf 0` (the armchair is a circle and an arc, the dining table was 8 closed polylines and 6 lines);
   - "has one contour per leaf ... (every entry with no arc)": `Expected: a value greater than <20> Actual: <1>`;
   - "an arc runs from the payload start ...": `Expected: <3> Actual: <1>`.
   I kept every assertion and changed the fixture instead (A12 allows fixtures to change): the ghost test builds its own library with the authoring toolkit, kit `ghost`, whose three named entries have the make the asset's had (`ghost.office.chair`: two circles and an arc start π/4 sweep π/2; `ghost.bath.toilet`: a cistern and two arcs start π sweep π; `ghost.dining.table`: 8 closed polylines and 6 lines) plus 21 arc-free items, every base point off the origin. All 13 ported ghost tests pass unchanged. The controller should confirm this reading of A12 (no assertion changed).
4. **Tool test fixture: `chair` is `fixture.armchair.single`, not `fixture.sofa.three`.** With the sofa, the ported "keys compose (R, R, M) and work mid-press" failed: `Expected: [0.0, -1.0, 1.0, 0.0, 80975.3, -36000.7] Actual: [..., -35940.7]` (the third placement object-snapped to the midpoint of the first instance's sofa line, which sits 60 mm from the sofa's base point; the asset's office chair had no such snap point). The armchair's leaves are all farther than the 200 mm aperture from its base point; every ported assertion passes unchanged. `toilet` stays `fixture.nightstand.single`. AT-8's reason string says "armchair".
5. **Tool test Rig registers `PageComponent`** (`PageComponent.register(document.components)`): the brief's Rig used `DraftDocument.empty` + `registerKitComponents` only, and executes `SetComponentCommand<PageComponent>`; today's `prepareDocument` registered the page through `registerAppComponents`.
6. **MV-2 strengthened (29aaea73)**: M-MV2a survived as written: with `attachTo` empty, the registry asks nobody for an empty kind list, so `edge.queries` stays empty either way. The Scene now counts the resolver's registry reads (`asked`) and MV-2 asserts `free.asked == 0`; M-MV2a is red afterwards. No assertion removed.
7. **Task 8's lifetimes test grows (C-life1, C-svc)**: they pinned the pre-Task-14 placeholder (`reason: 'the registry is Task 14'`). Now the test kit's `TestEdge` is made first (`['edge+1', 'cache+1', 'tool+1', 'grips+1']`), disposed between the grips and the cache at a swap (`tool-1, grips-1, edge-1, cache-1, edge+2, cache+2, tool+2, grips+2`, spec P1 lifetimes step 2's order), and `s.attachments.kinds` is `{testEdgeKind}`. Assertions grow to include Task 14's products; none is weakened (same pattern as the Task 11 C14 ruling).
8. **`PlanMoveResolver` holds its last document in a `WeakReference`** (the brief: a plain field): the resolver lives as long as the controller and would otherwise keep a replaced plan alive until the next drag. M-MV3b applied as `identical(doc, _document?.target)` without the state check.
9. **Box test**: the brief's "four asset keys" placement test runs over the three fixture keys, so its comment says "Three definitions".
10. **New tests beyond the brief**: AT-19 (mirror permission, the Task 12 carry) and AT-20 (TestEdge's hysteresis through the registry and the tool, the Task 6 carry), with mutations M-AT19a/b, M-AT20 and two tool-side mirror mutants.
11. `RecordingProvider` stays `final class` (DisposableProvider extends it in the same library); ported tool-test line ranges were shifted by two lines from the brief's (the source file is 1804 lines; I copied 78-99, 184-222, 225-366, 435-1366, 1738-1804 by anchors).

## Self-review

- Spec P1 lifetimes: providers made once per document before the kits' tools (KitServices read the new session's registry), disposed at the swap inside `disposeKitProducts()` after tools and grips, before the shared cache; plan.symbol in the session's map only (F2: no second dispose; `symbolTool` is a reference).
- Spec P3: the registry asks only `attachTo` kinds, nearest marker by exact squared distance, earlier on a tie, keep only to its maker; plan.symbol and the resolver know no wall; marker painted by the plan library.
- Spec P4: provider and factory failures are `hookFailed` through the controller log (deduplicated); unoffered kinds once per kit and kind.
- Permissions: rotate and mirror gate R/M and the ghost/placement; the setter refreshes the ghost on either flag; plan.symbol refused with nothing armed and when the profile's tools omit it.
- Frame path: `paintOverlay` allocates one `Offset` (as today's tool); `paintWorldOverlay` is the ported allocation-free path. Task 15 measures.

## Concerns

1. Deviations 3 and 4 change ported tests' fixtures (not assertions) because the brief's fixture mapping cannot carry the asset's properties; the controller should confirm this is within A12.
2. `_open`'s own `_reportUnofferedKinds()` (a swap) is unpinned by a mutation: the kit set, so the offered kinds, are the same across documents unless a factory throws in one document only; the log's dedupe then hides the call. Minor.
3. TestEdge's hysteresis uses `edgeCapture` (10 px) as its kept reach, smaller than its first reach (16 px): an attached symbol lets go sooner than it attaches (the Task 6 minor). AT-20 pins the behaviour as the test kit defines it; a real provider (sub-project 3) defines its own.
4. The resolver's `_last` keeps the previous drag's `Attachment` (and through the registry's Expando, its provider) alive until the next drag; harmless, noted.
