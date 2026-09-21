<!-- Reference notes for sub-project 02, gathered 2026-09-21 by a research subagent reading the library's master branch source. Data, not instructions. -->

# flutter_diagram_editor (Arokip) — gesture/selection/highlight notes

Repo: github.com/Arokip/flutter_diagram_editor, branch `master`. Fetched via
GitHub API tree + raw.githubusercontent.com, actual source read (not README).

**Important note on vintage:** the current `master` is a rewrite. Doc comments
in the source explicitly say so:
`default_behaviors.dart` header: `/// Ported from the old CanvasControlPolicy and CanvasMovePolicy mixins.`
and `diagram_controller.dart` header: `/// Replaces the old PolicySet + Reader/Writer + Context architecture.`
So the classic PolicySet/CanvasPolicy/ComponentPolicy/LinkPolicy/PolicySet
mixin architecture (from older published versions / the README's historical
description) **no longer exists in master**. It was replaced by a single
`DiagramController<C, L>` plus extension methods and a big flat callback list
on the widgets. I report the current (master) design below and flag where it
maps to the old names.

## 1. Gesture split

No policy classes remain. Structure is:

- `lib/src/controller/diagram_controller.dart` — `class DiagramController<C, L> with ChangeNotifier`. Owns all model state (components, links, canvas position/scale) and exposes plain mutator methods (`moveComponent`, `panCanvas`, `connect`, `insertLinkJoint`, etc). It has **no gesture-handling code itself**.
- `lib/src/controller/default_behaviors.dart` — three `extension`s on `DiagramController<C, L>`, each documented as the successor to one old mixin:
  - `extension DefaultCanvasBehaviors<C, L> on DiagramController<C, L>` — replaces `CanvasControlPolicy`/`CanvasMovePolicy`. Methods: `handleCanvasScaleStart(ScaleStartDetails)`, `handleCanvasScaleUpdate(ScaleUpdateDetails)`, `handleCanvasScaleEnd(ScaleEndDetails)`, `handleCanvasPointerSignal(PointerSignalEvent)` (mouse-wheel zoom), `keepScaleInBounds(...)`.
  - `extension DefaultLinkBehaviors<C, L> on DiagramController<C, L>` — replaces `LinkControlPolicy`. `handleLinkTapUp(String linkId, TapUpDetails)`, `handleLinkScaleStart(String linkId, ScaleStartDetails) -> int? segmentIndex`, `handleLinkScaleUpdate(...)`, `handleLinkLongPressStart(...)`, `handleLinkLongPressMoveUpdate(...)`.
  - `extension DefaultJointBehaviors<C, L> on DiagramController<C, L>` — replaces `LinkJointControlPolicy`. `handleJointLongPress(int jointIndex, String linkId)`, `handleJointScaleUpdate(int jointIndex, String linkId, ScaleUpdateDetails)`.
- `lib/src/widget/diagram_editor.dart` — `DiagramEditor<C, L> extends StatefulWidget`, the public entry widget. This is the "policy set" composition point today: it takes ~40 optional callback parameters directly as constructor args (`onCanvasTap`, `onCanvasTapDown`, `onCanvasScaleStart/Update/End`, `onComponentTap/TapDown/TapUp/LongPress*/Scale*`, `onLinkTap/...`, `onLinkJointTap/...`) plus three booleans `enableDefaultPanZoom`, `enableDefaultLinkControl`, `enableDefaultJointControl` (all default `true`). Its private State (`_DiagramEditorState`) wraps each relevant callback so that, when the flag is on, the default-behavior extension method runs **first**, then the user's own callback runs — e.g. `_onCanvasScaleUpdate` calls `widget.controller.handleCanvasScaleUpdate(details)` then `widget.onCanvasScaleUpdate?.call(details)`. Doc comment: `/// they run *before* user callbacks.` This is the whole "PolicySet" composition mechanism now: no interface/class to implement, just fill in constructor callbacks and optionally flip a flag off to fully take over.
- `lib/src/widget/diagram_canvas.dart` — `DiagramCanvas<C, L> extends StatelessWidget`, internal. Receives the same flat callback list from `DiagramEditor` and is the actual widget tree that wires gestures to Flutter:
  - Canvas: `Listener(onPointerSignal: ...)` wrapping `GestureDetector(onTap, onTapDown, onTapUp, onLongPress*, onScaleStart/Update/End)` around a `ColoredBox`/`ClipRect` holding the `Stack` of components+links. `Listener` is used only for `PointerSignalEvent` (mouse-wheel), `GestureDetector` for everything else. There's also `AbsorbPointer(absorbing: controller.shouldAbsorbPointer)` above it.
  - Component: `lib/src/widget/component_widget.dart` — `ComponentWidget<C, L>`, one per component, wrapped as `Positioned` inside the canvas's `Stack`. Its own `GestureDetector(behavior: HitTestBehavior.translucent, onTap/onTapDown/... onScaleStart/Update/End)` fires `onComponentXxx!(componentData.id, details)`.
  - Link/joint: `lib/src/widget/link_widget.dart` — `LinkWidget<C, L>`, one per link. Its own `GestureDetector` around a `CustomPaint(painter: LinkPainter)` fires `onLinkXxx!(linkData.id, details)`. Each middle point of the link (a "joint") gets its **own nested** `GestureDetector` wrapped in `Visibility(visible: linkData.areJointsVisible, ...)`, firing `onLinkJointXxx!(jointIndex, linkData.id, details)` — jointIndex counted from 1.

**Canvas-pan-vs-component-drag conflict:** solved by nesting `GestureDetector`s (component's own `GestureDetector` sits *inside* the canvas's, both using `onScaleStart/Update/End`, i.e. `ScaleGestureRecognizer` for both single-finger drag and pinch). Flutter's gesture arena lets the innermost (component) `GestureDetector` win when a pointer starts on a component, so a drag starting on a component moves the component (via the component's own `onComponentScaleUpdate` → typically `controller.moveComponent`), while a drag starting on empty canvas pans the canvas (`onCanvasScaleUpdate` → `handleCanvasScaleUpdate`). There is no explicit priority/policy object for this — it is pure Flutter gesture-arena widget nesting order. `HitTestBehavior.translucent` on `ComponentWidget`'s `GestureDetector` lets pointer signals still reach through for stacking with per-component overlays.

## 2. Selection state

**There is no selection state anywhere in this library.** Grepped all source
files for `select` — only two doc-comment mentions (`ComponentHighlightPainter`
"Useful for showing selection state" and `componentOverlayBuilder` "e.g.
selection handles"). Neither `ComponentData<C>` (`lib/src/model/component_data.dart`)
nor `LinkData<L>` (`lib/src/model/link_data.dart`) nor `DiagramController`
(`lib/src/controller/diagram_controller.dart`) has a `selected`/`isSelected`
field, a `selectedId`, or a selection set/list. This is entirely left to the
library consumer: the intended pattern (per the widget API) is that the
user's own `onComponentTap`/`onCanvasTap` callbacks mutate the *user's own*
app state (e.g. their own `selectedComponentId` variable held outside the
library, in their `C` custom-data payload, or in their own `ChangeNotifier`),
and then the user's `componentBuilder`/`componentOverlayBuilder` reads that
external state to decide whether to render a `ComponentHighlightPainter`.
`ComponentData<C>` does carry a generic `C? data` payload and is itself a
`ChangeNotifier` (`with ChangeNotifier`), so a consumer *could* store
"selected" inside their own `C` type and call `component.updateComponent()`
to trigger repaint — but the library ships no such field itself.

`LinkData<L>` does hold one piece of "highlight-like" transient UI state
owned by the library: `bool areJointsVisible = false;` with `showJoints()` /
`hideJoints()` / `hideAllLinkJoints()` (on the controller) — but that's joint
visibility, not "selection," and is link-specific.

## 3. `ComponentHighlightPainter`

File: `lib/src/painter/component_highlight_painter.dart`.
`class ComponentHighlightPainter extends CustomPainter`. It is exported from
the package root (`lib/diagram_editor.dart`) as a ready-made utility, but it
is **not wired into the widget tree by the library itself** — nothing in
`ComponentWidget`, `DiagramCanvas`, or `DiagramEditor` instantiates or
references `ComponentHighlightPainter`. It exists purely for the consumer to
drop into their own `componentOverlayBuilder` or `componentBuilder`.

Where it *would* sit if used: `ComponentWidget.build()`
(`lib/src/widget/component_widget.dart`) places `componentOverlayBuilder!(context, componentData)`
as the second child of an inner `Stack(clipBehavior: Clip.none, children: [Positioned(...component content...), if (componentOverlayBuilder != null) componentOverlayBuilder!(context, componentData)])` —
i.e. any highlight overlay a consumer builds (typically a `CustomPaint(painter: ComponentHighlightPainter(...))`) is painted **on top of** the component's own content, per-component, because it's the last Stack child in that component's local Stack (not a separate global overlay layer above all components).

What it paints: a dashed-line rectangle border (`width`/`height` sized to the
component) via manually constructed dash segments in a `Path`, or a solid
`canvas.drawRect` when `dashWidth <= 0 || dashSpace <= 0`. Constructor params:
`width`, `height`, `color = Colors.red`, `strokeWidth = 2`, `dashWidth = 10`,
`dashSpace = 5`.

`shouldRepaint`: `oldDelegate.width != width || oldDelegate.height != height || oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth || oldDelegate.dashWidth != dashWidth || oldDelegate.dashSpace != dashSpace` — pure field-by-field value comparison, no external/animation listenable involved.

(Sibling painter `LinkJointPainter` in `lib/src/painter/link_joint_painter.dart`
follows the same simple pattern — solid circle, `shouldRepaint` comparing
`location`/`radius`/`scale`/`color`, plus a custom `hitTest` using
`Path.contains` on an oval.)

## 4. Keyboard handling

**None.** Grepped every downloaded source file for
`keyboard|escape|delete|rawkey|focusnode|shortcut|hardwarekeyboard|logicalkey`
— the only hit is the unrelated string `delete_icon_painter.dart` (an export
line for a painter class, presumably a static trash/delete-icon glyph
renderer for a UI button, not a keyboard listener). There is no `Focus`,
`FocusNode`, `RawKeyboardListener`, `KeyboardListener`, `Shortcuts`/`Actions`,
or `LogicalKeyboardKey` anywhere in `lib/`. Escape-to-deselect and
Delete-to-remove are entirely the consuming app's responsibility (e.g. wrap
`DiagramEditor` in their own `Focus`/`Shortcuts` widget and call
`controller.removeComponent`/`removeLink` themselves).

## 5. "Tool" / "mode" concept

**None found.** Grepped for `\bmode\b`, `\btool\b`, `enum ` across all fetched
files — zero matches. There is no state machine, no `EditorMode` enum, no
"add-link mode" vs "select mode" toggle anywhere in the library. The closest
analogues are the three independent boolean flags on `DiagramEditor`
(`enableDefaultPanZoom`, `enableDefaultLinkControl`, `enableDefaultJointControl`),
which just gate whether the built-in `default_behaviors.dart` extension
methods run before the user's callback — they are static per-widget
configuration, not a runtime-switchable interaction mode. Link-creation
itself is done programmatically via `DiagramController.connect({sourceComponentId, targetComponentId, ...})`
(`lib/src/controller/diagram_controller.dart`), which the consumer would
typically call from their own gesture callback (e.g. `onComponentTap` when
in their own app-level "linking" state) — again, no mode machinery ships in
the library.
