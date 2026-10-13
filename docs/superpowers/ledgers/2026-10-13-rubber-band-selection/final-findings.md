# Final review findings to fix (one fix wave)

Branch `feat/rubber-band`, head `cc196aa0`. Spec:
`docs/superpowers/specs/2026-10-13-rubber-band-selection-design.md`. The
reviewer verified each proposed pin green on HEAD and red on its mutant in a
scratch copy; its probe files are in
`/private/tmp/claude-501/-Users-ahmeturel-Projects-oss-jet-cad/839ff77a-2f40-4def-ba76-a7eafcb97c71/scratchpad/`
(`probe_test.dart` etc.) — read them for the exact probe code if useful.

## Tests (no production code change)

1. **The tool's notifications during a band are unpinned.** Dropping
   `notifyListeners()` at `packages/jet_cad_floor_plan/lib/src/service/table_select_tool.dart:297`
   (the banding move) or `:641` (Escape mid-band) survives every test — a
   band frozen on screen, or an Escaped band left painted, would pass. In
   `test/service/table_band_test.dart` (RB14/RB15, or a new RB15b) count the
   tool's notifications: `var n = 0; r.tool.addListener(() => n++);` — after
   the band starts, a further move notifies (`n` grows); Escape mid-band
   notifies. Mutants M-RB22 (drop :297's notify) and M-RB23 (drop :641's):
   each red, reverted.
2. **R-1 (the modifier is read at the down) is unpinned.** Mutant B (read
   `e.shift || e.control || e.meta` at the up in `_band`, :387) and mutant D
   (read the modifiers at the first move in `_startsBand`, :307) survive.
   Add **RB2b** in `table_band_test.dart`, two legs:
   - under `pan`: selection {9}; `down(s, shift: true)`, moves and up with
     **no** modifier over 1 and 2 → selection {1, 2, 9} (kills D: it would
     pan; kills B: it would replace);
   - under `band`: a plain down; `shift: true` on the moves and the up only
     → a replace, {1, 2} (kills B: union).
   The rig's `move`/`up` helpers must accept modifiers per event. Mutants
   M-RB24 (B) and M-RB25 (D): each red, reverted.
3. **The crossing's `!t.locked` (`table_select_tool.dart:421-422`) is
   unpinned** (mutant C, dropping it, survives). Spec RB-3 step 3: a crossing
   takes a group only through an **unlocked** member. Add a leg to RB10:
   select {1}; a crossing band over table 8's right edge only (8 is group h's
   locked member), asserting in the test that the band box does not overlap
   7's leaves (premise) → the selection is empty (a plain band replaces with
   an empty K). Mutant M-RB26 (drop `!t.locked`): red, reverted.
4. **RB13's "no double tap" leg is vacuous** (mutant F — moving the
   `_startsBand` block above `_lastTap = null`, `:261-268` — survives). At
   `table_band_test.dart:~718`, after the band's `r.up(top)`, add
   `r.tap(top); expect(r.doubleTaps, isEmpty);` (the rig's timestamps are
   all zero, so under F the chain completes). Mutant M-RB27 (F): red,
   reverted.
5. **`test/host/band_view_test.dart:306-309`**: RBV4's name says "a mode
   switch mid-band leaves nothing selected" but asserts `{'5'}`; rename to
   "…leaves the selection as it was".

## Docs (wording)

6. **"The camera pans with … the wheel" is false on desktop.**
   `GesturePolicy.wheelZooms` applies on desktop and in Chromium/WebKit, and
   Ctrl/Cmd+wheel always zooms (`packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart:186-206`);
   only Firefox pans on the wheel; the guide's own table (~`docs/host-guide.md:989`)
   says the mouse wheel zooms. Reword, in all of:
   `packages/jet_cad_floor_plan/lib/src/host/floor_plan_types.dart:~193`,
   `packages/jet_cad_floor_plan/lib/src/host/floor_plan_view.dart:~104`,
   `CHANGELOG.md:~17`, `docs/host-guide.md:~546` and `~1387` (and §10 Touch
   if it says the same), and the spec `:~146` and `:~369`, to the effect of
   "the camera then pans with two fingers, a trackpad's scroll and the middle
   button (the mouse wheel zooms)". Grep the touched files for "wheel" to
   catch every place. In the spec, add the correction as a dated errata line
   under the Status header ("2026-10-13 errata: the wheel zooms on desktop;
   RB-1's pan list corrected") rather than silently rewriting approved text
   — but do correct the two sentences.
7. **Rewrap** `docs/host-guide.md:546-549` and `:2184-2187` to the
   surrounding width (≤ 80 columns).

## Gates

The planner's suite with `flutter test --enable-vmservice` (from
`packages/jet_cad_floor_plan`), `flutter analyze`, `dart format
--output=none --set-exit-if-changed .`; `dart run tool/ci/check_guide.dart`
from the repo root; the host probe only if a guide code block changed (none
should).
