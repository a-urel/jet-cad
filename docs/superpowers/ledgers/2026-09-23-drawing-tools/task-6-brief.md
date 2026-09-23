### Task 6: `TextTool`

Package: `packages/jet_cad_2d_flutter`.

**Files:**
- Create: `lib/src/draw/text_tool.dart`
- Modify: `lib/jet_cad_2d_flutter.dart` (one export)
- Test: `test/draw/text_tool_test.dart` (TX1–TX7)

**Interfaces:**
- Consumes: Task 3 (`PlacementTool`), Task 1 (`textPayload`,
  `textHeightMm`, `addDrafted`).
- Produces:

  ```dart
  final class TextPlacement { const TextPlacement(this.point, this.heightMm); final Vector2 point; final double heightMm; }
  class TextTool extends PlacementTool {
    TextTool();
    final TextEditingController controller;       // tool-owned (D9)
    ValueListenable<TextPlacement?> get pending;
    void commitText(String s, ToolContext ctx);
    void cancelText(ToolContext ctx);
  }
  ```

- [ ] **Step 1: Write the failing tests.** Create
  `test/draw/text_tool_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/services.dart'
    show LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/draw/text_tool.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show screenOf, snapshot;

Handle? textOf(DraftDocument doc) {
  for (final slot in doc.entities.liveSlots) {
    if (doc.entities.kindAt(slot) == EntityKind.text) {
      return doc.entities.handleAt(slot);
    }
  }
  return null;
}

void main() {
  for (final flipY in const [true, false]) {
    test('TX1 flipY $flipY: a click sets pending at the exact point, 2.5 '
        'paper mm at 1:20, and dispatches nothing (M-05j)', () {
      final s = drawScene();
      final tool = TextTool();
      addTearDown(tool.dispose);
      final rig = drawRig(s.document, tool, flipY: flipY, objectSnap: false);
      final before = snapshot(s.document);
      final at = screenOf(rig.camera, 7050.5, 3080.25);
      clickAt(rig, at);
      final placed = tool.pending.value!;
      expect(placed.point, worldAt(rig, at));
      expect(placed.heightMm, 50.0);
      expect(snapshot(s.document), before);
    });
  }

  test('TX2 commitText commits one text with the string and height', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    final at = screenOf(rig.camera, 7050.5, 3080.25);
    clickAt(rig, at);
    tool.commitText('Kitchen ', rig.context);
    final h = textOf(s.document)!;
    final slot = s.document.entities.slotOf(h)!;
    final r = s.document.entities.read(slot);
    final p =
        s.document.geometry.read(s.document.entities.geomIndexAt(slot));
    expect(r.text, 'Kitchen ', reason: 'stored exactly as typed');
    expect(r.textAttrs, 0);
    final w = worldAt(rig, at);
    expect(p.coords, Float64List.fromList([w.x, w.y]));
    expect(p.scalars, Float64List.fromList([50, 0, 1, 0]));
    expect(tool.pending.value, isNull);
    expect(s.document.commands.undoDepth, 1);
  });

  test('TX3 an empty string cancels, byte-identical', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    final before = snapshot(s.document);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    tool.commitText('', rig.context);
    expect(snapshot(s.document), before);
    expect(tool.pending.value, isNull);
  });

  test('TX4 a canvas click while pending commits the controller text and '
      'starts nothing new (M-05y)', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    tool.controller.text = 'Bath';
    clickAt(rig, screenOf(rig.camera, 7120, 3040));
    final h = textOf(s.document)!;
    expect(s.document.entities.read(s.document.entities.slotOf(h)!).text,
        'Bath');
    expect(tool.pending.value, isNull);
    expect(tool.controller.text, isEmpty);
  });

  test('TX5 Escape and a tool switch each cancel, byte-identical', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    final before = snapshot(s.document);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    tool.controller.text = 'x';
    keyDown(rig, LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape);
    expect(tool.pending.value, isNull);
    expect(snapshot(s.document), before);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    tool.controller.text = 'y';
    rig.tools.activate(SelectTool());
    expect(tool.pending.value, isNull);
    expect(snapshot(s.document), before);
  });

  test('TX6 Enter with the canvas focused commits the controller text', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    clickAt(rig, screenOf(rig.camera, 7050, 3080));
    tool.controller.text = 'Hall';
    keyDown(rig, LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
    expect(textOf(s.document), isNotNull);
  });

  test('TX7 a shift click takes no ortho', () {
    final s = drawScene();
    final tool = TextTool();
    addTearDown(tool.dispose);
    final rig = drawRig(s.document, tool, objectSnap: false);
    final at = screenOf(rig.camera, 7050.5, 3080.25);
    clickAt(rig, at, shift: true);
    expect(tool.pending.value!.point, worldAt(rig, at));
    expect(tool.orthoBase, isNull);
  });
}
```

  A `TextTool` owns a `TextEditingController`, so every test disposes it
  (`addTearDown(tool.dispose)`).

- [ ] **Step 2: Run it and see it fail** (compile error).

- [ ] **Step 3: Implement `lib/src/draw/text_tool.dart`.**

```dart
import 'dart:ui' show Canvas;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/widgets.dart' show TextEditingController;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tool.dart';
import 'placement_tool.dart';

/// Where a pending text will go, and how tall (spec 05 D9).
final class TextPlacement {
  const TextPlacement(this.point, this.heightMm);
  final Vector2 point;
  final double heightMm;
}

/// Spec 05 D9. A click sets [pending]; the app's field edits [controller].
///
/// **The rule, stated once.** Enter, or a canvas click, commits a non-empty
/// string. Escape, a tool switch, or any other loss of focus cancels. The
/// tool owns the text, so a canvas click commits synchronously, before the
/// layer's focus request takes effect.
class TextTool extends PlacementTool {
  TextTool();

  final TextEditingController controller = TextEditingController();
  final ValueNotifier<TextPlacement?> _pending =
      ValueNotifier<TextPlacement?>(null);

  ValueListenable<TextPlacement?> get pending => _pending;

  @override
  String get name => 'Text';

  @override
  bool get isPending => _pending.value != null;

  @override
  Vector2? get orthoBase => null;

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (_pending.value != null) {
      commitText(controller.text, ctx);
      return;
    }
    controller.clear();
    _pending.value = TextPlacement(point, textHeightMm(ctx.page?.value));
  }

  @override
  void finish(ToolContext ctx) => commitText(controller.text, ctx);

  void commitText(String s, ToolContext ctx) {
    final placed = _pending.value;
    if (placed == null) return;
    if (s.isNotEmpty) {
      commit(
          ctx,
          () => addDrafted(ctx.document, EntityKind.text,
              textPayload(placed.point, placed.heightMm),
              text: s));
    }
    cancel(ctx);
  }

  void cancelText(ToolContext ctx) => cancel(ctx);

  @override
  void clearShape() {
    super.clearShape();
    _pending.value = null;
    controller.clear();
  }

  /// A small insertion cross at the pending point, 6 screen px per arm.
  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    final placed = _pending.value;
    if (placed == null) return;
    final x = placed.point.x - origin.x, y = placed.point.y - origin.y;
    final arm = 6 / scale;
    band
      ..reset()
      ..moveTo(x - arm, y)
      ..lineTo(x + arm, y)
      ..moveTo(x, y - arm)
      ..lineTo(x, y + arm);
    canvas.drawPath(band, bandPaint);
  }

  @override
  void dispose() {
    controller.dispose();
    _pending.dispose();
    super.dispose();
  }
}
```

  Add the export.

- [ ] **Step 4: Run the tests and see them pass.**
  Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/text_tool_test.dart`

- [ ] **Step 5: Gate and commit.**

```bash
git add packages/jet_cad_2d_flutter/lib/src/draw/text_tool.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/draw/text_tool_test.dart
git commit -m "$(cat <<'EOF'
feat(draw): the text tool owns its text and commits on a canvas click

A click sets a pending placement, 2.5 paper mm at the page scale, and
the tool's own TextEditingController holds the string. Enter or a
canvas click commits a non-empty string synchronously; Escape and a tool
switch cancel byte-identically. Spec 05 D9.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

