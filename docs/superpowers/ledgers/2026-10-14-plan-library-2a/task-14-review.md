# Task 14 review: attachment, plan.symbol and the move resolver

Base 953356d8, head 29aaea73 (b2a6f29a + 29aaea73). Reviewed from the review package in one pass over lib, then a second pass over the tests; outside-diff checks are named below.

### Spec Compliance

- ✅ Spec compliant. Every file the brief lists has its hunk (6 lib files created, `plan_controller.dart` and `session.dart` modified, 7 test files created, the highlight test added to `test/panels/plan_symbol_gallery_test.dart`). No change outside `packages/jet_cad_2d_plan`; no `analysis_options.yaml`; nothing new exported.
  - P3 registry: `attachment_registry.dart:108-132` asks only the providers of the asked kinds, in `attachTo` order then load order; the nearest marker wins on exact squared distance, the earlier on a tie (`d < bestDistance`); `keep` reaches only its maker via the `Expando` origin (`:110`, `:118-120`), everyone else gets `_withoutKeep`. A throwing provider goes through Task 11's `guardAttachment` (`:136-137`); a throwing factory adds nothing and reports `hookFailed`/`attachments` (`:85-102`).
  - P3 "who uses it": `plan_symbol_tool.dart` and `move_resolver.dart` talk to `AttachmentRegistry` only. I grepped `lib/` for `WallFaces|againstWall|jet_cad_floor_plan`: the only hit is a doc comment (Minor 6).
  - P3 drawing: the plan library paints the marker (`attachment_painter.dart`, `PlanSymbolTool.paintOverlay` attached branch) and the ghost (`paintWorldOverlay` over `_placement = _attached?.transform ?? _free()`).
  - M mirrors while attached: `onKey` asks the registry again with the new mirror (`plan_symbol_tool.dart` onKey → `_syncAttachment`). AT-20 pins it end-to-end through `TestEdge` (ghost and committed transform `[-1,0,0,1,…]`).
  - mayRotate = `permissions.rotate`. When it is false, `current` is the unturned free placement (`_turns` → 0), so a provider sees the turn a click would place. AT-12 pins it on the tool side and MV-1 on the resolver side.
  - P1 lifetimes: `_open` runs `runAttachmentFactories` right after `_session = session` and before `runKitFactories`. I checked `plan_controller.dart:559` against `:577`. `disposeKitProducts` disposes the registry after the grip providers and before the shared cache (session.dart diff). C-life1 pins the order `tool-1, grips-1, edge-1, cache-1, edge+2, …`.
  - P4: an unoffered `attachTo` kind gives one `attachmentKindUnoffered` per kit and kind, reported after the symbol load (`plan_controller.dart:980`) and at `_open` (`:590`). `attachmentKindUnoffered` is not in `DiagnosticsLog.planScoped` (I checked `diagnostics_log.dart:14-20`), so the dedupe holds across swaps.
  - F1/F2: `symbolTool` lives in the session map only. `addTool` guards it (I checked `session.dart:149-150`). Nothing else disposes it. The controller's `toolFor` unwraps `GuardedTool` (`plan_controller.dart:847-850`).
  - Carried requirement, M respects `PlanPermissions.mirror`: `canMirror: () => _permissions.mirror`, `_mirror` gates both the ghost and the placement, and the setter calls `gatesChanged` on a rotate or mirror change. AT-19 is new and has four named mutants.
  - `_allowsTool` refuses plan.symbol with nothing armed (`plan_controller.dart:732`).
- Ported assertions unchanged. I checked this by extracting the `expect(` lines and diffing source against port:
  - Ghost test: 48 of 48 identical except `e.key` → `e.symbol.key`.
  - Tool test, source `:435-1366` and `:1738-1804`: all 218 present. The only differences are `ghostPathFor(x)` → `ghostPathFor(x.entry)` and one re-wrapped `toilet.key` → `toilet.component.key`.
  - Box test: the ported ranges match `jet_cad_floor_plan/test/symbols/symbol_box_test.dart:341-436`, with the brief's key mapping.
  - The fixture-only changes (the ghost test's own `ghost` library, `chair` = `fixture.armchair.single`, `PageComponent.register` in the Rig) are within A12, as the controller ruled.
- Deviations from the brief that I judge sound:
  - `dispose` uses a pattern instead of `is` promotion. `Disposable` is not a subtype of `AttachmentProvider`, so the brief's form cannot promote.
  - The `WeakReference` document in the resolver.
  - MV-2 strengthened with the `asked` counter. With an empty kinds list the registry is a no-op, so M-MV2a would otherwise survive.
- ⚠️ Cannot verify from diff:
  - `guardAttachment`'s subject and dedupe (Task 11). AT-5 asserts `('alpha','wall-face',hookFailed)` against the real guard, so the controller only needs to trust that test run.
  - The implementer's mutation table and gate outputs. I did not re-run them.

### Strengths

- The registry is small and correct. The `Expando` origin makes the "keep only to its maker" decision cheap and isolates two kits offering the same kind. `bare` is built at most once per call.
- The report is honest. M-MV2a survived as first written, and the implementer strengthened MV-2 instead of claiming it.
- The fixtures sit off the origin and are turned and mirrored: the Scene in MV is placed at quarterTurns 1 and mirrored, at (1e5, −7e4), with the camera at 0.1 px/mm. AT-8 checks that the grid premise moves the point, which kills the snapped-vs-raw pointer degenerate.
- AT-20 drives the test kit's real `TestEdge` through registry and tool, so the keep-to-maker plumbing is shown to change a provider's decision. It does more than record a field.
- The guarded dispose in the registry (one throwing `dispose` is reported and the others still run) is consistent with the session's `_disposeGuarded`.
- `_reportUnofferedKinds` and the setter's `gatesChanged` branch are placed exactly where the brief asks.

### Issues

#### Critical (Must Fix)
None.

#### Important (Should Fix)
None.

#### Minor (Nice to Have)

1. **`packages/jet_cad_2d_plan/lib/src/tools/plan_symbol_tool.dart:235`: dead parameter.** `_syncAttachment(ToolContext ctx)` never reads `ctx`, so the `if (ctx != null)` guard in `gatesChanged` (`:195`) does nothing: `_hasRaw` already guards. This follows the brief's shape. Drop the parameter, or say why it is kept.
2. **`packages/jet_cad_2d_plan/lib/src/attach/attachment_registry.dart:33` and `:95-110`: two additions without a test.** The behaviours are reasonable, but neither has a named mutation:
   - the `kind` getter read inside the factory's try (Deviation 2);
   - the guarded per-provider dispose (Deviation 1), with subject = kind.

   Add an AT-7b (a provider whose `kind` throws) and an AT-6b (one `dispose` throws, the other is still disposed, one `hookFailed`).
3. **`packages/jet_cad_2d_plan/test/tools/move_resolver_test.dart`: unpinned resolver branches.**
   - The scaled arm of MV-2 (`:141`) and its non-symbol arm (`:148`) name no mutation. Deleting `isOrthonormal` (`move_resolver.dart:61`) or `n.parent != doc.rootHandle` (`:56`) has no recorded red.
   - The child-instance arm and the missing-definition arm have no case at all.
   - `_sync`'s node-change reset (`:91`) is unpinned.
   - MV-4 (`:173`) names no mutation, and it cannot tell `boxOfDefinition` from `boxOfEntry`: the leaves are unedited, so both give the same box. The brief chose not to port the source's "reads the live leaves" test (asset literal boxes), which leaves `boxOfDefinition`'s liveness unpinned in this package. A fixture-library version (remove one leaf, then expect the box to shrink) would restore it.
4. **`packages/jet_cad_2d_plan/test/tools/plan_symbol_tool_test.dart:1550-1555`: AT-20 pins `TestEdge`'s inverted hysteresis.**
   - The kept reach (edge capture, 200 mm) is smaller than the first reach (320 mm), so the ghost lets go at 250 mm and re-attaches on the next hover at the same pointer.
   - The test is right that this proves keep-to-maker, but it enshrines an oscillation as expected behaviour of the test kit (the Task 6 carry the implementer names).
   - Record it for sub-project 3 so no real provider copies the convention.
5. **`packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart:590`: `_open`'s call is unpinned.**
   - `_reportUnofferedKinds()` at the end of `_open` has no mutation, because the log's dedupe hides it across swaps (the implementer flags this).
   - AT-16's `hasLength(1)` after `newPlan()` (`attachment_controller_test.dart:108`) passes with or without the call.
6. **`packages/jet_cad_2d_plan/lib/src/symbols/symbol_box.dart:134`: stale doc comment.** It names `WallFaces` as the caller that memoises. That type is not in this package; the memo now lives in `PlanMoveResolver._boxes`. It is only a doc reference, but it contradicts "no WallFaces in the plan library".

Outside-diff checks I made, one per named risk:
- **Risk: the old plan.symbol keeps listening to the controller's `_armed` across a swap.** I checked `_replace` and `_drop` (`plan_controller.dart:611-641`). The old session is disposed post-frame. Its symbol tool is cancelled when select is activated, so `_listening` is null and an `_onArmed` in the window never reaches the disposed registry. The controller's `dispose` disposes the sessions before `_armed`. Benign.
- **Risk: `snappingAllowed = false` still attaches.** The session's `snap` is `EffectiveSnap` (`plan_controller.dart:248`), so `ctx.snap.objectSnap` already folds the canvas option. The tool and the resolver honour it.
- **Risk: plan.symbol is not guarded.** `addTool` wraps with `_guard('plan', id, tool)` (`session.dart:149-150`).

### Assessment

**Task quality:** Approved

**Reasoning:** The registry, tool, resolver and controller wiring meet spec P1, P3 and P4 and the mirror carry. I confirmed mechanically that the ported assertions are unchanged, and the new behaviour has named, observed mutants. What remains is test-coverage polish: the resolver's unnamed arms, the untested guarded dispose, and boxOfDefinition's liveness. There is also one stale comment.
