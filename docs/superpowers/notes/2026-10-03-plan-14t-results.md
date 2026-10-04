# Plan 14t results — touch

**Branch:** `claude/exciting-pasteur-9m22jv` (after 14b-1, 14s, 14a, 14b-2,
14c). **Spike:** [2026-10-03-touch-spike.md](2026-10-03-touch-spike.md).
**Spec:** [2026-10-03-touch-design.md](../specs/2026-10-03-touch-design.md),
revision 2. **Plan:** [2026-10-03-touch.md](../plans/2026-10-03-touch.md).
**Approval:** the human, travelling, asked not to be asked unless needed
and said "Devam et" (2026-10-03); the umbrella's D17 is approved.
**Not merged.**

On a touch screen, in both modes, two fingers pinch about their midpoint
and pan together; a finger that turns out to start a pinch never acts as a
tap, a drag or a drawing point; once two fingers are down nothing reaches
a tool until every finger lifts; a second finger during a table drag
cancels it. A drawing tool sees a finger only when it lifts, at the lift,
and its slide past the slop as a hover (the snap marker follows it). A
finger reaches 24 px — after a precise 6 px pick misses — and its grips,
slop and table picks are finger-sized. Mouse, trackpad and stylus behave as
before.

## Commits

| Step | Commits | Review |
|---|---|---|
| Spike, spec rev 1, rev 2 | `9611727`, `ccebdff` | rev 1: Ready with fixes (R-1..R-13; R-1 critical: a drawing tool's down executes), applied in rev 2 |
| Plan | `c6bb290` | — |
| 1 Touch sessions in the layer | `da3c8a9` | **Approved with fixes** (shared review of 1–4; F-1 a finger's exit cancelled a mouse band) |
| 2 The pinch | `f91f2ce` | idem |
| 3 Finger-sized targets | `7cd9a70` | idem |
| 4 The selection mode, the drawing tools | `4a338c9` | idem → `7ae3c3b` (F-1..F-7) |

One implementer (this session); the spec's reviewer prototyped T3 and T4
and ran the suites against them; the code reviewer re-ran the gates in its
own worktree and fired its own mutants.

## Gates (Linux container, Flutter 3.47.6 / Dart 3.13.5)

| Package | Result |
|---|---|
| engine `packages/jet_cad_2d` | **untouched** |
| render `packages/jet_cad_2d_flutter` | **1,229 passed** + 1 skip + 7 standing (text ladder rungs 1–5, text LOD ladder rungs 1–2, as before); analyze, format clean |
| planner `packages/jet_cad_floor_plan` | **969 passed**; analyze, format clean |
| app `apps/floor_planner` | **192 passed**; analyze, format clean |
| demo `apps/restaurant_demo` | **17 passed**; analyze, format clean |
| web builds | `apps/floor_planner` and `apps/restaurant_demo`: `✓ Built build/web` |

**Touch smoke (Chromium, CDP touch events, tr-TR), at `4a338c9` and again at `7ae3c3b`:** in the
demo's service mode a touch tap on table 3 logged "tapped 3"; a one-finger
drag of table 6 moved it and logged one layout change; a drag of table 7
joined by a second finger zoomed the view by the fingers' span ratio
(189 → 537 px, about 2.8×) and logged no layout change; no page error.

## Mutants fired

Spec-named, red: **M-14t-1** (the zoom about the first finger), **-2** (a
cumulative ratio), **-3** (no pan), **-4** (no re-base), **-5** (no
hold-back), **-6** (a tap at the wrong position, both modes), **-7** (no
cancel on a second finger: through the widgets, the tool stuck), **-9**
(touch promotion), **-10** (a touch hover routed), **-11** (no reach),
**-12** (the slop not by kind), **-13** (the grip radius not by kind),
**-14** (the session not cleared on leaving), **-15** (the long press from
the routed down), **-16** (the hold-back for a mouse), **-17** (every tool
in press mode: the Room tool commits through a pinch), **-18** (the reach
first: the later neighbour picked), **-19** (the rotation grip first),
**-20** (cancel whatever the phase; at the layer), **-21** (no minimum
span), **-22** (multi never reset), **-24** (a held finger's cancel
routed), **-25** (a stylus as touch, layer and camera), **-26** (no reach
in the selection mode; a mouse given it). Own, red: the zoom about the old
midpoint, a third finger in the pair, a tool change keeping the held
finger, focus at the physical down, no exit at a session's end, a lift
mode on a timeout, a lift-mode aim routed as a press, the slop not strict,
the reach not set, a finger while a mouse is pressed, the ruler marking a
finger, the rotation grip at the mouse radius on touch, the table reach
taking the later-drawn, the reach ignored, the polygon distance to one
edge.

The code review's 47 mutants: 38 red; its six test gaps (the press-mode
opt-ins of `SelectTool` and `SymbolPlaceTool`, the grip distance's
rotation terms, the reach's instance scale, a mouse given a 6 px table
reach, the long press through the view) are red after `7ae3c3b`, with the
three fixes' own mutants (an exit while a mouse holds the layer, a mouse
routed during a session, a lift off the canvas routed).

**Survive, recorded:** **M-14t-8** (the multi flag reset at a lift):
equivalent — after a lift the remaining finger is neither held nor routed,
and a new finger finds another finger down and makes the session multi
again. **M-14t-23** (the hold-back timer not cancelled on the up): not
fired as a code mutant; harmless by reading — the up clears the held
finger, and the timer then finds none (TL1 and TL4 pump 200 ms after the
up and see exactly one down). A tie between the rotation grip
and a grip, and between two tables' distances, resolved the other way:
measure-zero, not pinned. **M-14t-20 through the shell:** a polyline is a
lift-mode tool, so a pinch's first finger never reaches it; the cancel rule
is pinned at the layer (TL8).

## Amended at execution

- **The press-mode opt-ins** (`SelectTool`, `TableSelectTool`,
  `SymbolPlaceTool`) landed in Task 1, not Tasks 3 and 4: with the layer
  changed and the tools not, the table tool would have seen a finger's drag
  as hovers, and Task 1 would not have ended green.
- **One existing test changed (R-2):** `room_paint_test.dart`'s probe tap
  is a mouse click (RR1's probes sit 60 mm from anything, inside a finger's
  reach). The review's prototype found seven such tests under a one-stage
  24 px pick; the two-stage pick (R-3) left this one.
- **`TablePicker.pick`'s reach** measures the distance to the top's
  boundary in definition units times the instance's `sqrt(|det|)`: exact
  for the placements (turns and mirrors), approximate for a table scaled by
  hand unevenly.

- **Review fixes beyond the spec:** a touch session sends no exit while a
  mouse holds the layer (F-1: the exit cancelled a live mouse band); no
  precise pointer is routed while any touch session runs (F-2, R-9a's
  second half); a lift-mode finger lifted off the canvas places nothing
  (F-7).
- **`kTouchHoldBack` is not pinned by the planner suite** on its own: the
  long press is timed from contact whatever its value (the tool subtracts
  it); the render suite pins the value (TL3).

## Found, not fixed

- **No device was measured.** The spike and the smoke are Chromium's CDP
  emulation. The look and feel on an iPad, an Android tablet and a touch
  laptop — the 100 ms hold-back, a finger's jitter, iOS Safari's own pinch
  against the engine's `touch-action: none` — is owed to the human.
- **A web text entry ends** when a pinch's first finger lands outside it
  (its tap-outside region), accepted (R-9c).
- **A camera event may notify twice** during a pinch (a pan, then a zoom),
  accepted (R-12).
- **Out of scope, as the spec says:** a long press and multi-select by touch
  in the design mode, a two-finger rotation, fling and double-tap zoom, a
  larger snap aperture for touch, a stylus's hover.
- **`fitToView` framing the live tables** (umbrella D17's last clause) is
  withdrawn (amendment A-1): 14b-2 fits the page.

## For the human

- **Look owed, on a tablet:** run `apps/restaurant_demo` (Android, iOS, or
  `flutter run -d chrome` on a touch device): in Service, tap and long-press
  tables, drag one, pinch and pan with two fingers, and start a drag then
  add a finger; in Design, pinch, tap a wall, drag a band, draw a polyline
  by taps (the point lands where the finger lifts).
- **Next:** the restaurant embedding's slices are done; the remaining work
  is the human's look and the merge, on the human's word.
