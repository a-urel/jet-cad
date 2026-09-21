# Review — `docs/superpowers/specs/2026-09-21-interaction-core-design.md` (revision 1)

Three reviewers, same prompt, same day: Claude (Fable 5.1, a fresh review
subagent on Opus), Codex (gpt-5.5, `codex exec --sandbox read-only
--ephemeral`), Copilot CLI (`copilot -p --allow-all-tools`). Every finding
below was re-verified by the session against `main@fa51d27` and the installed
SDK (Flutter 3.47.2 under `/opt/homebrew/Caskroom/flutter/3.27.3/flutter`).
Repo untouched by all three (`git status` clean after each). Raw reports
were kept in the session scratchpad; this note is the record.

Counts as raised: Claude 4 blocker / 10 major / 11 minor; Codex 2 / 8 / 3;
Copilot 1 / 4 / 2. After merging duplicates and verification: **5 blockers,
14 majors, 12 minors upheld; 1 claim not upheld as stated.** Revision 2 of
the spec applies every upheld item; the ruling on each is written beside it.

Verdict on revision 1: **not ready to plan from.** Two of the blockers are
contradictions between the spec's own decisions, two are engine facts the
spec misread (the float32 rebase, the dirty overlay), one is a group
resolution that returns the wrong node.

## Blockers

**B1. Window-selecting a group by "any member" contradicts D1.** (Codex,
Copilot; verified against D1's own text.) D8 said a group is selected when
any member is, window or crossing alike. Window means "fully encloses".
**Ruling:** containers follow one rule in both modes — window selects a
container when **every** member leaf's world AABB is enclosed; crossing when
**any** member leaf's stroke is touched. Instances descend the same way, so
the instance "world box" test and the missing `boxOfInstance` accessor
(Claude F6) go away. New mutant M-02r: group of two leaves, one in, one out.

**B2. The overlay's world-space `ui.Path` throws away the float32 rebase.**
(Claude; verified — `viewport_transform.dart:12-13`, `camera_controller.dart`
`rebaseOriginFor`, `draft_painter.dart:73-78` "at 4.5e6, float32 spacing is
about 0.5 units", `canvas_draw_sink.dart:67,100` the residual matrix.)
`ui.Path` stores float32; the renderer never hands `dart:ui` an absolute
world coordinate; the generated corpus sits at x = 4.5e6, the startup plan at
x = 5e3 so the look cannot see it. **Ruling:** the outline cache stores
world geometry as `Float64List`s at selection time and builds its `ui.Path`
in the space rebased by `rebaseOriginFor(camera.visibleWorld(size))`; the
cache is tagged with that origin and rebuilt when it changes (stable across
small pans by construction). Per frame the canvas transform is
`worldToScreen ∘ translate(origin)` as one reusable `Float64List(16)`, the
way `CanvasDrawSink` does it. New mutant M-02v at `kDefaultOriginX`.

**B3. D2's "topmost group" prose resolves to the wrong node.** (Copilot F2,
Claude F3, from opposite premises; the code is: the root **is** in `_nodes`
— `tree.dart:61-63` — so `ancestorsOf(owner)` ends with the root, and for a
group directly under the root it is `[root]`.) The prose "last `GroupNode`
before the root" reads as the root itself, or as nothing. **Ruling:**
`candidates = [owner, ...tree.ancestorsOf(owner)]` with the root removed;
the selection is the last candidate that is a `GroupNode`, or the leaf when
there is none. M-02p's fixture gains the single-level case. `NodeCycleError`
is caught and resolves to the leaf (Claude F25, `query_filter.dart:121-132`
precedent).

**B4. D8's window predicate read `boxOfLeaf`, which is null for every leaf
edited since the last rebuild.** (Claude F4; verified `spatial_index.dart:
2429-2434`, `container_index.dart:758`, `dirty_list.dart:80`.) **Ruling:**
`boxOfLeaf(slot) ?? dirty.boxOf(slot)`, the established idiom. New mutant
M-02s: edit one straddling leaf, run the window band before a rebuild.

**B5. The delete cascade was not atomic per object and could double-delete a
fill.** (Codex F-02; verified `commands.dart:144-201` — removing a boundary
removes its one dependent fill in the same command; `undo.dart:102,193`
`execute` throws `PermissionDeniedError` rather than skipping — Copilot F3.)
**Ruling:** a preflight per selected object builds the exact command list
(leaves via `leavesByOwner()`, child nodes via `childNodesOf`, nested groups
recursively; fill slots whose boundary is in the same list are skipped), checks
`permissions.allows(capability)` for every command in it, executes only a
fully-permitted list, and removes the object's key from the selection
**after** the list succeeds. A refused object stays selected and untouched.
Still N undo steps; the intermediate-inconsistency hazard of a partial undo
(Claude F19) is recorded for 06.

## Major

**M1. The instance key's `entity = Handle.none` made D11's prune rule drop
every selected instance on the first `DocChange`.** (Claude F2; Codex F-10
on the same field's ambiguity.) **Ruling:** the key is `(chain, target)`:
`target` is the selected object's handle (instance, group or leaf), `chain`
the instance handles strictly above it. Under D2 the chain is always empty in
02; the field exists so entering a container later extends it. Prune: `target`
resolves in `entities` or `tree`, every chain handle to an `InstanceNode`.
M-02c as the roadmap wrote it is therefore **equivalent under D2** (the log
says why); its replacement M-02c′ mutates `resolveHit` to return the leaf.

**M2. `SelectionKey(chain: hit.chain)` would copy the buffer's capacity, not
its length.** (Claude F8; `hit.dart:28,31,33`.) **Ruling:** copy
`[0, chainLength)`; a `truncated` hit is treated as a miss (Claude F18).

**M3. Nobody owned the hover key.** (Claude F11.) **Ruling:** `hover` lives
on `SelectionController` (`hover`, `setHover`), notifying on change; the
overlay skips it when it is selected.

**M4. The overlay `CustomPaint` would lay out at `Size.zero` in a loose
`Stack`.** (Claude F5; `basic.dart:839`, `draft_canvas.dart:465-479` passes
`Size.infinite`.) **Ruling:** `Positioned.fill` + `size: Size.infinite`; the
`Size` handed to `paint` is the viewport the tool receives.

**M5. `Focus.onKeyEvent` sees down, repeat and up; Delete would run twice.**
(Codex F-06, Claude F13.) **Ruling:** `onKey` acts on `KeyDownEvent` only.
New mutant M-02x.

**M6. The controllers were placed where the top bar cannot reach them.**
(Copilot F5, Claude F14; `main.dart:59-84`.) **Ruling:** `_PlannerShellState`
owns `SelectionController`, `ToolController` and the `ToolContext`, disposes
them beside the camera, passes them down; the status text's merged listenable
is a `late final` field.

**M7. Button handling ignored Flutter's multi-button semantics and pointer
identity; `PointerCancel` was unwired.** (Claude F15, Codex F-05, Copilot F7;
`pointer_binding.dart:935-1006`, `events.dart:263`.) **Ruling:** the layer
tracks one active pointer id and the previous `buttons`; primary is
recognised on its **transition** in or out of the mask; any event whose mask
contains the pan button is camera-owned and ignored; `onPointerCancel` →
`tool.cancel`. New mutant M-02y.

**M8. Cache invalidation on exact handle match never fired for instance or
group keys.** (Claude F12.) **Ruling for 02:** every `DocChange` rebuilds
every cached outline. Selection is small and changes arrive at command rate;
03 narrows this with a measurement if its drag needs it. New mutant M-02w.

**M9. `ToolController`'s forwarding over a changing active tool was
unspecified.** (Codex F-08; `Listenable.merge` needs a stable iterable.)
**Ruling:** the controller listens to the active tool, swaps the listener in
`activate` after cancelling the outgoing tool, removes it in `dispose`.

**M10. Band crossing's broad phase must widen like `pickInto`'s.** (Codex
F-03; `spatial_index.dart:462` `_broadPhaseMargin().pick`.) **Ruling:**
crossing widens the query box by the same margin; window does not need it.

**M11. Fills are not pickable and the spec treated them as leaves.** (Codex
F-04; `spatial_index.dart:772,998-1013`.) **Ruling:** band walks skip
`EntityKind.fill`; a fill is never a key; a region is selected through its
boundary.

**M12. The descent omitted `transformOfLeaf`.** (Claude F7;
`spatial_index.dart:564`.) **Ruling:** stated; new mutant M-02t with a
grouped leaf inside a definition (`generateDocument(groupCount:)`).

**M13. M-02d's fixture was red on the unmutated code.** (Codex F-11, Claude
F9.) **Ruling:** 3 px hits, 10 px misses, ×10 makes 10 px hit. M-02l keeps
only its scale-0.25 half.

**M14. M-02q could not be planted without editing `DraftCanvas`.** (Claude
F10; `_repaint` is private.) **Ruling:** dropped as a mutant; its assertion
is an invariant test under criterion 6. The roadmap's M-02e (`shouldRepaint`
false unconditionally) is equivalent under D9 with the reason logged (Claude
F22); the spec's `repaint: null` mutant is M-02e′.

## Minor

- Group leaves are enumerated with `leavesByOwner()` and `childNodesOf`, both
  existing (Copilot F4, Claude F19). `_unlink` copies the children list, so
  the cascade order is safe (verified `tree.dart:612-625`).
- `Listener(behavior: HitTestBehavior.opaque)` spelled out (Copilot F6).
- `Listener.onPointerHover` for hovers; `MouseRegion.onExit` for exit only;
  hover and band cleared in `dispose` (Codex F-13).
- `Canvas.transform` takes a `Float64List(16)`, `screenToWorld` a `Vector2`
  (Claude F17).
- The band rectangle assumes an axis-aligned camera; one sentence says so
  (Claude F20).
- "Hover picks allocate nothing" → "nothing per entity", the O(1) per-event
  allocations named (Claude F16).
- "Overlay never walks the document" → "`paint` never walks" (Codex F-09).
- D11 delivery wording: "after async delivery; tests pump a microtask;
  tool-initiated delete updates the selection synchronously" (Codex F-07).
- M-02f is killed by sampling `phase == pressed` after the 2 px move; M-02g
  gains a zero-dx vertical drag (Claude F21).
- Decisions without a mutant got one: ascending-order sort dropped (M-02z),
  `replace` notifies unconditionally (M-02aa), a fresh `Paint` per frame
  (M-02ab), hover skip removed (M-02ac) (Claude F23).
- Band walks dedupe slots (a slot may be visited from tree and overlay,
  `container_index.dart:512-515`; Claude "not checked", verified).
- Citations corrected: `onAfterMutate` at `spatial_index.dart:141`, the
  `doc_change.dart` quote at 5-7, the compound grep restated as
  `class .*(Compound|Batch|Multi).*Command` (Claude F24).
- M-02e′'s fixture mutates the controller without rebuilding the widget
  (Codex F-12).

## Raised, checked, not upheld as stated

- Claude F3's premise "the document root is not in `_nodes`" — it is
  (`tree.dart:61-63`). The finding's conclusion (the prose picks the wrong
  node) holds for the opposite reason and is B3 above.

## Verified true, no action

All three reports' "verified as correct" lists agree with each other and
with the session's own reading: the citations to `spatial_index.dart`,
`hit.dart`, `query_filter.dart`, `container_index.dart`, `segment_clip.dart`,
`primitives.dart`, `text_geometry.dart`, `node.dart`, `tree.dart`,
`commands.dart`, `command.dart`, `undo.dart`, `draft_canvas.dart`,
`camera_gesture_detector.dart`, `gesture_fixture.dart`, `spy_canvas.dart`
and `main.dart` hold at `fa51d27`; `pickInto`'s approximated-radius rule for
circles under non-uniform scale is real; `generateDocument` has every knob the
differential test names; every roadmap open question is answered.
