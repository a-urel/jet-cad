# Touch spike (14t) — what a finger does today

**Branch:** `claude/exciting-pasteur-9m22jv` at `387c401`. **Umbrella:**
[2026-10-03-restaurant-embedding-design.md](../specs/2026-10-03-restaurant-embedding-design.md)
D17 ("spike first"). **No device was available**: the spike ran a
pointer-logging Flutter web probe in headless Chromium driven by CDP
`Input.dispatchTouchEvent` (Flutter 3.47.6), and read the render package's
input code. Native iOS and Android, and a real browser on a tablet, are
owed to the human.

## Facts measured (Chromium, Flutter web)

- **TS-1. A finger is its own pointer.** Each contact arrives as
  `PointerDownEvent` → `PointerMoveEvent`s → `PointerUpEvent` with
  `kind: touch`, `buttons: 1` (primary) while down, a fresh `pointer` id
  per contact and a fresh `device` per contact. Two fingers' moves
  interleave event by event.
- **TS-2. No pan-zoom events for touch.** A two-finger pinch arrives as two
  pointers; no `PointerPanZoom*` and no `PointerScaleEvent` (those are
  desktop trackpads and browser ctrl+wheel). Nothing pinches unless the
  app tracks the fingers.
- **TS-3. A synthetic hover after every touch up.** After each touch
  `PointerUpEvent` (and after a `PointerCancelEvent`) the web engine sends
  a `PointerHoverEvent` with `pointer: 0`, `kind: touch`, `buttons: 0` at
  the finger's last position.
- **TS-4. Cancel arrives.** A `touchcancel` becomes a `PointerCancelEvent`
  with `buttons: 0`.
- **TS-5. No contact size.** `radiusMajor` is 0 for CDP touches; nothing
  may depend on it.

## Facts read (render package)

- **TS-6.** `InteractionLayer` follows **one** pointer: the first primary
  down claims it; any other pointer's down is ignored; a move with the
  primary set on a pointer while none is active is promoted to a down
  (`interaction_layer.dart:149-158`, written for a mouse whose button goes
  down while it hovers). With touch, after the first finger of a pinch
  lifts, the second finger's next move **becomes a down** (14c review
  F-10).
- **TS-7.** `CameraGestureDetector` pans on a middle-button drag, zooms on
  signals and trackpad pan-zoom; it has **no multi-touch pinch and no
  two-finger pan** (umbrella F-11).
- **TS-8.** The tools' first-down behaviour: `SelectTool`,
  `TableSelectTool` and `SymbolPlaceTool` only classify a press on down
  and act on the up or after their slop, and their `cancel` drops the
  press with no command. **`PlacementTool` (every drawing tool) acts on
  down** and reports `phase: idle` throughout: it places a point, and the
  down that completes a shape **executes its command** (`RoomTool` and
  `OpeningTool` commit on a single down; the last down of a line,
  rectangle, circle or arc commits; the text tool opens an entry). Its
  `cancel` drops the whole pending shape (corrected after the spec
  review, R-1).
- **TS-9. Mouse-sized targets.** The pick radius is 6 px
  (`kPickRadiusPixels`), the grip hit radius 7 px (`kGripHitPixels`), the
  select tool's band slop 4 px (`kBandSlopPixels`); a fingertip's tap
  jitters past 4 px, so a tap can become a tiny band or move. Only
  `TableSelectTool` uses `kTouchSlop` (18 px).
- **TS-10.** Every routed hover reaches the active tool as a move with
  `buttons: 0`: with TS-3, a tap leaves a hover highlight (the select
  tool) or a snap marker (a drawing tool) under the lifted finger.

## Consequences for the spec

A pinch today drags or bands with its first finger while the second is
ignored; in a drawing tool the first finger has already placed a point.
The spec has to (a) recognise the pinch in the camera layer, (b) keep the
tool from acting on a finger that turns out to be the first of a pinch,
(c) take a gesture with two or more fingers away from the tool until every
finger lifts, (d) size targets and slop by pointer kind, (e) drop touch
hovers.
