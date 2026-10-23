# Alignment guides spec, revision 1: OpenCode review

Reviewer: OpenCode CLI v2.1.1, model `github-copilot/gpt-6.1-sol` (the default `flint-40b-free` failed: "Upstream request failed: Endpoint is unavailable."). Requested by the human, 2026-10-23. Findings verbatim; all twelve folded into revision 2 as O-1 to O-12.

1. **Important — “Priority against the existing chain.”** The stated priority changes attachment behaviour rather than preserving it. `SelectTool` invokes the move resolver even after OSNAP succeeds (`packages/jet_cad_2d_flutter/lib/src/select_tool.dart:462–473`); placement likewise resolves attachment after snapping (`packages/jet_cad_2d_plan/lib/src/tools/plan_symbol_tool.dart:292–299`). An attachment can therefore override an OSNAP hit today. **Fix:** explicitly order attachment versus OSNAP, preserving the current attachment result unless this behavioural change is deliberately approved.

2. **Important — “The boxes” / “Priority.”** “Raw delta” has no defined origin. Body drags capture a **snapped** press point as their base (`packages/jet_cad_2d_flutter/lib/src/select_tool.dart:420–425`), and movement is `target − base` (`packages/jet_cad_2d_flutter/lib/src/grip_drag.dart:253–260`). Using `rawPointer − rawPress` for guides but `resolvedPointer − snappedBase` otherwise creates different movement baselines, potentially jumping when capture changes. **Fix:** specify both equations, how guide offsets become the final target, and which baseline determines Shift’s pinned axis. Test an off-grid press whose initial OSNAP/base differs from the raw press.

3. **Important — “Architecture: Camera moves mid-drag.”** Service has no existing `_onCamera` retarget path. It updates `_dx/_dy` only in `_drag`, and release commits those stored values (`packages/jet_cad_2d_plan/lib/src/service/service_tool.dart:433–451`). **Fix:** explicitly add service camera subscription, retarget from the last screen position, retain device/Alt state, and unsubscribe on release, cancel and disposal. Test camera changes without pointer movement. Preserve second-finger cancellation, which currently calls `cancel` (`packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart:227–241`).

4. **Important — “The boxes” / “Reference cache.”** `boxOfDefinition` includes only directly owned supported leaves, ignoring nested instances (`packages/jet_cad_2d_kit/lib/src/model/symbol_box.dart:153–170`). Service candidates instead use `document.definitionBounds` (`packages/jet_cad_2d_plan/lib/src/service/unit_picker.dart:261–263`). Thus the proposed paths can disagree or omit an entirely nested symbol. **Fix:** choose one bounds contract for both modes; either recursively include nested geometry or explicitly exclude unsupported definitions. Define handling of empty/non-finite boxes and hidden references; service’s existing candidate builder already rejects invisible, singular and non-finite candidates (`unit_picker.dart:256–274`).

5. **Minor — “Reference cache.”** `UnitPicker.candidates` does not expose world corners: it contains `PickCandidate` objects holding an inverse transform and local box (`packages/jet_cad_2d_plan/lib/src/service/unit_picker.dart:155–177`). Corners belong to `UnitCandidate`, and `_build` discards them (`unit_picker.dart:229–243`). **Fix:** name `UnitPicker.candidatesOf` as the available source, retain corners through an explicit cache change, or compute world bounds once during guide-cache construction.

6. **Important — “Candidates on one axis,” equal spacing.** “Adjacent,” “before/after,” and “that row” are insufficiently defined for overlapping or staggered references. A reference may overlap the moving box’s y-range without overlapping another reference’s y-range; their alleged gap then has no drawable overlap midpoint. Existing gap marks require that overlap. Geometric boundary decisions also need an explicit tolerance (`packages/jet_cad_2d/lib/src/core/tolerance.dart:4–10,23–37`). **Fix:** define interval eligibility, adjacency ordering, non-negative gaps, overlap requirements for every participating pair, and the exact between/continuation equations. Specify a total tie-break across both reference handles, feature pairs and signed offsets—not merely “lower handle.”

7. **Important — “Candidates” / per-axis grid mixing.** Row membership can become invalid after the other axis snaps. An x-spacing candidate selected using raw y may cease overlapping its neighbours after y receives a guide or grid correction. Grid snapping independently rewrites coordinates today (`packages/jet_cad_2d/lib/src/index/drag_snap.dart:88–100`). **Fix:** define whether eligibility uses raw, intermediate or final boxes, and a bounded conflict-resolution rule. Validate spacing eligibility and mark geometry against the final combined translation; prohibit alternating re-solves between axes.

8. **Important — “Reference cache,” placement lifecycle.** “Built once per drag start” does not cover placement hover, successive placements, or re-arming. The ghost updates while idle (`packages/jet_cad_2d_plan/lib/src/tools/plan_symbol_tool.dart:340–350`), and release places an instance while leaving the tool armed (`plan_symbol_tool.dart:354–366`). **Fix:** define placement-cache creation before first hover resolution and invalidation after placement, undo/redo, document replacement, definition/layer changes and re-arm. Otherwise newly placed neighbours are absent or rebuilding per hover defeats the allocation constraint.

9. **Important — “The look,” `guideWidth`.** The proposed width has no specified transport to painters. `Tool.paintOverlay` receives only camera, viewport and `PaperPalette` (`packages/jet_cad_2d_flutter/lib/src/tool.dart:126–130`); `planPaperPaletteFor` currently resolves colours only (`packages/jet_cad_2d_plan/lib/src/theme/plan_theme.dart:429–445`). **Fix:** specify a build-resolved guide-style channel carrying width to all three tool paths, without reading Flutter theme state during paint. Also define whether a new `PaperPalette` constructor argument is optional to preserve existing callers.

10. **Important — “Turning them off,” controller API.** A property typed merely as `Listenable` cannot expose the promised `.on` and `.toggle()`. Moreover, copying snap’s notification model directly is unsafe: `EffectiveSnap` forwards only user notifications (`packages/jet_cad_2d_plan/lib/src/controller/services.dart:139–155`), while allowed-state changes use a separate deferred notifier (`packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart:573–594`). **Fix:** freeze a named public settings type and export it; define notifications for both preference and allowance changes, frame-safe delivery, and immediate clearing/re-resolution of active guides when disabled.

11. **Minor — “Turning them off,” action enums.** Adding `PlanServiceAction.guides` requires changes to **two exhaustive switches**, for button creation and grouping (`packages/jet_cad_2d_plan/lib/src/service/view/plan_service_view.dart:879–912`). Editor switches have fallbacks that would silently omit an unhandled action (`packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart:582–587,639–654`). **Fix:** explicitly include switch updates, default ordering/group placement, and host migration guidance for exhaustive enum switches. Repository demo usages found are explicit lists, not exhaustive switches.

12. **Important — “Constraints” / allocation testing.** Measuring only solver and guide paint misses per-reference allocations in adapters, viewport filtering and moving-box construction. Existing plan paint tests pin painter/sink identity rather than tool-event allocations (`packages/jet_cad_2d_plan/test/invariants/canvas_paint_allocation_test.dart:6–19`). Boxed-double regressions are already documented in picking (`packages/jet_cad_2d_plan/test/invariants/pick_allocation_test.dart:14–33`). **Fix:** require warmed end-to-end retarget measurements in all three tools, including camera retargets, with varying reference/selection counts; watch `_Double`, bounds, transforms, records and collection allocations, using named mutants.

## Revision 2: Copilot CLI review

Reviewer: GitHub Copilot CLI (default model), `--allow-all-tools --deny-tool write`, requested by the human, 2026-10-23. Findings verbatim; all nineteen folded into revision 3 as C-1 to C-19 (C-8 reverses revision 2's object-snap-wins call; C-3 drops the viewport filter).

1. **Critical — "Turning them off / User", editor bar.**
   - The spec puts the toggle "after Snap in the editor's edit group". Snap and Zoom are not toolbar buttons. They are text read-outs built in a separate `readOuts` switch (`plan_editor.dart:638-655`, `osnap-text`).
   - The toolbar groups only hold export, print, undo and redo (`plan_editor.dart:582-587`).
   - The default `bar.actions` path bypasses the action switch entirely: `listEquals(bar.actions, values) ? _Toolbar(groups: [file, edit])` (`plan_editor.dart:634`).
   - Both switches end in `_ =>`, so a new `PlanEditorAction.guides` is silently dropped. The compiler will not flag it.
   - **Fix:** name the real host (a command in the `edit` list, or a read-out widget). Add a test that the toggle appears with the default `actions` and with an explicit list.

2. **Critical — "The boxes", service references.**
   - The spec says "the service document's other symbol instances (bar counters, fixed furniture)" and "same rules as `UnitPicker.candidatesOf`".
   - `candidatesOf` iterates `index.units`, and `UnitIndex.of` keeps only instances whose definition has a `UnitComponent` (`unit_index.dart:~149-153`). Non-unit furniture is never a reference.
   - It also includes generated units nested one level inside a root group (`unit_index.dart:~157-168`). That contradicts "root-level".
   - It checks only layer visibility (`UnitInfo.visible`), not the node's own `visible` flag. The spec cites both.
   - **Fix:** decide whether service references are units only or all root instances. If all, the cache needs its own `tree.nodes` scan. Decide whether generated units count. Pick one visibility rule.

3. **Important — "boxes": "nearby = intersects the visible viewport".**
   - Tools get no viewport `Size` on pointer events. `ToolContext` and `ToolPointerEvent` carry none. Only `paintOverlay` receives it, and `ViewportTransform.visibleWorld(Size)` allocates an `Aabb2` (`viewport_transform.dart:65`).
   - The filter is also O(n) per event.
   - **Fix:** drop the viewport filter and use a world radius or the sorted axis arrays. Or specify that the layer publishes the viewport size.

4. **Important — "Constraints" (O-12): per-event budget "zero".** This is already false for today's tools.
   - `GripDrag.moveTo` builds a `Transform2.translation` per event (`grip_drag.dart:259`); `moveToTransform` allocates too.
   - `SelectTool._onCamera` allocates a `Vector2` per tick.
   - `PlanSymbolTool` allocates in `_free()` (a `Transform2`) and in `_syncAttachment` (`_raw.clone()`, `AttachmentQuery`, `footprintOf`).
   - `ServiceTool` builds `Transform2.translation` per paint (`service_tool.dart:287`).
   - **Fix:** state the invariant as "guides add zero over the baseline", and measure with and without guides. Or list the existing allocations as exempt.

5. **Important — "Architecture" (seam ordering).**
   - Today `_retarget` calls `drag.moveTo(chain point)` before attachment (`select_tool.dart:~462-470`). A guide that "replaces the delta after attachment" means a second `moveTo`, one more `Transform2`, and attachment evaluated on the unguided transform.
   - **Fix:** say where the guided target enters. Suggest solving between `_resolve` and `moveTo`, with the attachment result still overriding.

6. **Important — "The delta": Shift/ortho.**
   - `dRaw` gets "the pin applied on the pinned axis", but a guide capture `o` is then added to that same axis. That breaks the ortho line, which `resolveDragPoint` keeps exact (`drag_snap.dart:96-98`).
   - **Fix:** a pinned axis takes no guide capture.

7. **Important — "The delta": jitter claim.**
   - "A capture switching moves the object by at most the aperture" is wrong when the grid is on. Compare `dChain` (grid-snapped, up to half a step from `dRaw`) with `dRaw+o`. The jump is up to half a step plus the aperture.
   - **Fix:** correct the claim and the test. Consider also solving against the `dChain` box, so an on-grid alignment does not move.

8. **Important — "Priority", rule 3: OSNAP suppresses guides.**
   - Object snap queries the pointer at 10 px against walls, rooms and every endpoint (`kDragSnapMask`, `drag_snap.dart:72`). On a real plan the pointer is often near some geometry.
   - Guides will therefore blink on and off as the pointer crosses geometry, and the object swaps between the OSNAP and guided positions. This is the stated jitter anti-goal.
   - **Fix:** apply the OSNAP-wins rule only when the snapped point is the one in use. Or add a release hysteresis. At minimum, add a test with a wall endpoint near the pointer.

9. **Important — "Modes: place".**
   - `dRaw`, `b` and "drag start" do not exist for placement (no base; hover has no press). The delta section covers moves only.
   - The ghost's box comes from `boxOfEntry(entry)` (direct leaves only, `symbol_box.dart:129`). The entry is not yet in the document, so it cannot use `definitionBounds`, and the "same bounds" claim fails.
   - R and M keys call `_syncAttachment` and `_syncPlacement` without `_update` (`plan_symbol_tool.dart:~395-402`), so the guide solve must be hooked there too.
   - `_track` stores no Alt and no pointer kind, which `_onCamera` retargets need for the aperture and for Alt.
   - **Fix:** define the placement delta as `p − chain` on `at`. Define the box source (for example `boxOfEntry` through `placementTransform`). Say that the key handlers and `_track` also store Alt and kind. Note that attachment's `current: _free()` must stay unguided.

10. **Important — "Candidates", step 5: recheck circularity.**
    - If both axes capture spacing, x's recheck uses the final y and y's recheck uses the final x. The order is undefined and the result can differ by implementation.
    - **Fix:** evaluate both rechecks against the pre-recheck final delta (simultaneous), or fix the order x then y with y seeing the updated x.

11. **Important — "Candidates", continuing spacing.**
    - The pair `(A,B)` is any of the 16 nearest, but the offset formula uses `L` or `R`. Whether `B` must equal `L` is not stated.
    - "16 nearest pairs" has no metric, no non-allocating selection, and no tie rule.
    - A gap `g` of 0 (touching tables) makes every touching pair a snap-to-flush candidate with zero-length marks.
    - Row membership uses `Tolerance.standard`, which is not a number. It should be `.linear` (`tolerance.dart`).
    - **Fix:** require `B == L` (or `A == R`) or say any pair is allowed. Specify the ranking (by distance from `M`, with a fixed-size insertion buffer). Exclude `g ≤ tol` from continuing and from marks.

12. **Important — "Controller / host options".**
    - `PlanServiceView` has no `snapping` option (grep: none). Only `PlanCanvas` writes `snappingAllowed` (`plan_canvas.dart:165,198,210`), and it resets to true on dispose. "Work the way `snapping` does" is false for the service view.
    - Two writers (`PlanCanvas`, `PlanServiceView`) to one controller flag conflict. `PlanEditor` mounts both.
    - **Fix:** name the single owner and how `PlanServiceView.alignmentGuides` combines with the canvas flag, for example an `allowedBy` set or a last-writer rule. Add the dispose reset.

13. **Important — API names (frozen at 1.0).**
    - `alignmentGuides` is a `bool` on three widgets and a `PlanGuideSettings` on the controller. Today the pair is `snapping` (bool) and `snap` (object).
    - **Fix:** use `controller.guides`, or call the widget option `guides`. The `*Allowed` setter should be `@internal` like `snappingAllowed`.
    - Hosts that compare `bar.actions` with `PlanEditorAction.values` (`plan_editor.dart:634`) change behaviour when `values` grows. Say so in the CHANGELOG.

14. **Important — references: seats and chairs.**
    - Units of kind seat are separate instances that "stay where they are" when a table moves (`service_tool.dart`, `_startDrag`). If they are references, the table snaps to chair edges and centres constantly.
    - **Fix:** exclude seats and attached children, or state that they are references and test it.

15. **Minor — box source.** `leavesByOwner` (used by `definitionBounds`) includes ATTRIB entities. `UnitIndex` excludes them from its box (`unit_index.dart:~121-123`). A unit's text label can therefore stretch the box. Verify, and say which box is canonical.

16. **Minor — Alt.** Pressing or releasing Alt without a pointer event does not re-solve. "Next event" leaves a stale preview on a held pointer. Have `onKey` retarget, or document the stale state.

17. **Minor — moving box.** Edge cases are not stated: an empty moving box (a hidden or singular member of a service group), a group member missing from the cache, and a selection of mixed design nodes (handled by "my call"). Add "empty moving box means no guide".

18. **Minor — `PaperPalette`.**
    - One optional default cannot be both light and dark, so a custom dark palette built without `guide` gets the light magenta.
    - The `preview` doc comment already says "guide lines". Clarify the difference.
    - `==`, `hashCode` and `PlanTheme`'s `copyWith`, `merge`, `lerp`, `debugFillProperties` (`plan_theme.dart:146-354`) must also carry `guideOnLight`, `guideOnDark` and `guideWidth`. The spec lists only validation.
    - Add `withGuide`, and apply it in `planPaperPaletteFor`, which currently builds only the selection copy.

19. **Minor — touch.** The aperture depends on device kind, but the design seam stores no kind (`select_tool.dart:_follow` stores only screen and shift). Camera retargets need the last kind. Add to the seam's inputs.



