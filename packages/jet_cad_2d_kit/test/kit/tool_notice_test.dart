// Spec 3a C1.2: a kit's Tool may implement ToolNotice, against the barrel
// alone. A premise of the export (exempt from the mutation rule beyond
// M-TN-export: without it this file does not compile); the behaviour is
// the plan library's (its guard, controller and status line).
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

final class Speaking extends Tool implements ToolNotice {
  final ValueNotifier<KitText?> said = ValueNotifier(null);

  @override
  ValueListenable<KitText?> get notice => said;

  @override
  String get name => 'speaking';
  @override
  ToolPhase get phase => ToolPhase.idle;
  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerExit(ToolContext ctx) {}
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;
  @override
  void cancel(ToolContext ctx) {}
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {}
}

void main() {
  test('TN-iface a Tool implements ToolNotice with a KitText listenable', () {
    final t = Speaking();
    addTearDown(t.said.dispose);
    final ToolNotice n = t;
    expect(n.notice.value, isNull);
    t.said.value = const KitText('text:test.busy', {'name': 'Slab 1'});
    expect(n.notice.value, const KitText('text:test.busy', {'name': 'Slab 1'}));
  });
}
