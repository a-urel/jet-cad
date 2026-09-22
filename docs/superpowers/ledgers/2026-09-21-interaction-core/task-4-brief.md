### Task 4: `Tool`, `ToolContext`, `ToolPointerEvent`, `ToolController`

**Files:**
- Create: `lib/src/tool.dart`
- Test: `test/tool_controller_test.dart`

**Interfaces:** exactly the Architecture block of the spec. `ToolContext`
also carries `void execute(DraftCommand)`.

- [ ] **Step 1: Failing tests** (criterion 7, spec M-02 none — the
  interface test): a `_CountingTool extends Tool` in the test file whose
  `cancel` increments a counter and whose `phase` is settable;
  `ToolController(initial: a, context: ctx)`; a listener counter on the
  controller; `a.notifyListeners()` → controller notified; `activate(b)` →
  `a.cancelCount == 1`, controller notified once more; `a.notifyListeners()`
  → **not** forwarded any more; `b.notifyListeners()` → forwarded;
  `dispose()` then `b.notifyListeners()` → nothing (no throw).

- [ ] **Step 2: Implement `tool.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show KeyEvent;
import 'package:flutter/widgets.dart' show KeyEventResult, Offset, Size, Canvas;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'camera_controller.dart';
import 'selection.dart';
import 'viewport_transform.dart';

final class ToolPointerEvent {
  const ToolPointerEvent({
    required this.screen, required this.world, required this.pointer,
    required this.buttons, required this.shift, required this.control,
    required this.meta, required this.alt, required this.pickRadiusWorld,
  });
  final Offset screen; final Vector2 world; final int pointer; final int buttons;
  final bool shift, control, meta, alt; final double pickRadiusWorld;
}

final class ToolContext {
  const ToolContext({required this.document, required this.index,
      required this.camera, required this.selection});
  final DraftDocument document; final SpatialIndex index;
  final CameraController camera; final SelectionController selection;
  void execute(DraftCommand command) => document.commands.execute(command);
}

enum ToolPhase { idle, pressed, dragging }

abstract class Tool extends ChangeNotifier {
  String get name;
  ToolPhase get phase;
  void onPointerDown(ToolPointerEvent e, ToolContext ctx);
  void onPointerMove(ToolPointerEvent e, ToolContext ctx);
  void onPointerUp(ToolPointerEvent e, ToolContext ctx);
  void onPointerExit(ToolContext ctx);
  KeyEventResult onKey(KeyEvent event, ToolContext ctx);
  void cancel(ToolContext ctx);
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport);
}

class ToolController extends ChangeNotifier {
  ToolController({required Tool initial, required this.context}) : _active = initial {
    _active.addListener(_forward);
  }
  final ToolContext context;
  Tool _active;
  Tool get active => _active;

  void activate(Tool next) {
    if (identical(next, _active)) return;
    _active.cancel(context);
    _active.removeListener(_forward);
    _active = next;
    _active.addListener(_forward);
    notifyListeners();
  }

  void _forward() => notifyListeners();

  @override
  void dispose() {
    _active.removeListener(_forward);
    super.dispose();
  }
}
```

- [ ] **Step 3: Run, gate line, commit**

```sh
git add lib/src/tool.dart test/tool_controller_test.dart
git commit -m "feat(tools): the Tool interface and ToolController"
```

---

