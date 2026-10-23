// Ported from jet_cad_floor_plan/test/host/editor_panels_test.dart (3a Task 26, spec C6); assertions unchanged.
//
// Host embedding API spec C-5's panels (Slice 4 plan, Task 5; S-9 d e,
// S-10, S-11, C-8, V-5): every Selection panel field and button by its
// flag, the layer picker, the Layer and Page panels shown and edited by
// theirs, a hidden panel kept offstage with its state, `readOnly` letting
// nothing edit through the UI while the host's own calls still work, and
// `tablesOnly` hiding the Material menus. Through `FloorPlanView` on the
// editor fixture under `editorCamera()`, with `editor_tools_test.dart`'s
// host and helpers; screen points come from the camera's forward
// transform.
//
// The architecture remainder (the unit cases are 2b's): T5-f, the Wall
// tool's settings, V-5's "each selectable", R-3's changeLayer/reshape and
// R-4's Door tool, through PlanEditor over the editor fixture (2b's units
// on the sample flat, ruling IT-R2). The panel keys are the plan's
// (`property-<id>` or `setting-<id>`, `section-<type>` or
// `settings-<tool>`, rulings IT-R6, IT-R7); a choice is a dropdown.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/chrome/text_field.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_rig.dart';
import '../support/editor_fixture.dart';
import '../support/room_plans.dart' show select;
import '../support/units.dart';

/// The panel field [f]'s widget.
PlanTextField fieldOf(WidgetTester tester, Finder f) =>
    tester.widget<PlanTextField>(f);

/// Types [text] into the read-only field [f] the only way a test can --
/// into its controller, the field focused -- and leaves it: its focus-loss
/// commit runs.
Future<void> typeIntoReadOnly(
    WidgetTester tester, Finder f, String text) async {
  await tester.tap(f);
  await tester.pump();
  fieldOf(tester, f).controller.text = text;
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
}

/// Types [text] into the field [f] and submits it.
Future<void> typeAndSubmit(WidgetTester tester, Finder f, String text) async {
  await tester.enterText(f, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

/// The first wall, room and dimension of the design.
Handle firstOf<T extends Component>(DraftDocument d) =>
    d.components.withComponent<T>().first;

/// The first door of the design, by handle.
Handle doorOf(DraftDocument d) =>
    d.components.withComponent<OpeningParams>().firstWhere(
        (o) => d.components.get<OpeningParams>(o)!.kind == OpeningKind.door);

void main() {
  group('the Selection panel by its flags (S-10, S-11)', () {
    testWidgets(
        'T5-f full.copyWith(reshape: false): a wall\'s thickness read-only '
        '(a typed value not committed) and its justification disabled; a '
        'door\'s flips absent and its width read-only; a room\'s name '
        'read-only; the dimension kind disabled; the Size menu absent while '
        'Mirror stays; under full each edits', (tester) async {
      final c = await mountEditor(tester,
          permissions: PlanPermissions.full.copyWith(reshape: false));
      final d = c.document;
      final before = encoded(c);
      // The wall.
      final wall = firstOf<WallParams>(d);
      await select(tester, c, [wall]);
      expect(fieldOf(tester, field('thickness')).readOnly, isTrue);
      await typeIntoReadOnly(tester, field('thickness'), '300');
      expect(encoded(c), before);
      expect(menuOf(tester, 'justification').enabled, isFalse);
      // The door.
      final door = doorOf(d);
      await select(tester, c, [door]);
      expect(sectionFinder(ArchitectureTypes.opening, ArchitectureTools.door),
          findsOneWidget);
      expect(field('flip-hinge'), findsNothing);
      expect(field('flip-swing'), findsNothing);
      expect(fieldOf(tester, field('width')).readOnly, isTrue);
      expect(fieldOf(tester, field('position')).readOnly, isTrue);
      // The room.
      await select(tester, c, [firstOf<RoomParams>(d)]);
      expect(fieldOf(tester, field('name')).readOnly, isTrue);
      // The dimension.
      final dim = firstOf<DimensionParams>(d);
      await select(tester, c, [dim]);
      expect(menuOf(tester, 'kind').enabled, isFalse);
      // A symbol with a family: the Size menu (ruling IT-R8: armed and
      // placed with a click, as a user would).
      expect(await symbolsReady(tester, c), isTrue,
          reason: 'premise: the furniture library loaded');
      expect(
          c.armSymbol(c.symbols
              .firstWhere((s) => s.component.key == 'architecture.sofa.two')),
          isTrue);
      await tester.pump();
      await click(tester, screenOf(tester, c, Vector2(24600, 13600)));
      await press(tester, LogicalKeyboardKey.escape);
      final placed = d.tree.nodes.whereType<InstanceNode>().last.handle;
      await select(tester, c, [placed]);
      expect(byKey('symbol-section'), findsOneWidget);
      expect(byKey('symbol-size-menu'), findsNothing);
      expect(byKey('symbol-mirror'), findsOneWidget);
      final placedState = encoded(c);
      // Under full each edits.
      await setPermissions(tester, c, PlanPermissions.full);
      expect(byKey('symbol-size-menu'), findsOneWidget);
      await select(tester, c, [wall]);
      expect(fieldOf(tester, field('thickness')).readOnly, isFalse);
      await typeAndSubmit(tester, field('thickness'), '300');
      expect(d.components.get<WallParams>(wall)!.thickness, 300);
      expect(menuOf(tester, 'justification').enabled, isTrue);
      await select(tester, c, [door]);
      final hinge = d.components.get<OpeningParams>(door)!.hinge;
      await tester.tap(field('flip-hinge'));
      await tester.pump();
      expect(d.components.get<OpeningParams>(door)!.hinge, isNot(hinge));
      await select(tester, c, [dim]);
      await choose(tester, 'kind', 'vertical');
      await tester.pump();
      expect(d.components.get<DimensionParams>(dim)!.kind, DimKind.vertical);
      expect(encoded(c), isNot(placedState));
    });

    testWidgets(
        'a tool\'s settings are no edit of the document: with the Wall tool '
        'active under full.copyWith(reshape: false), its thickness edits',
        (tester) async {
      final c = await mountEditor(tester,
          permissions: PlanPermissions.full.copyWith(reshape: false));
      await press(tester, LogicalKeyboardKey.keyW);
      expect(c.activeTool.value, ArchitectureTools.wall);
      expect(fieldOf(tester, field('thickness')).readOnly, isFalse);
      expect(menuOf(tester, 'justification').enabled, isTrue);
    });
  });

  group('readOnly (V-5)', () {
    testWidgets(
        'a table, a wall, a room and a dimension are each selectable by a '
        'click, their sections read-only: no ±90, Mirror, flips or layer '
        'picker', (tester) async {
      final c =
          await mountEditor(tester, permissions: PlanPermissions.readOnly);
      Future<void> clickAt(Vector2 w) => click(tester, screenOf(tester, c, w));
      await clickAt(edgeOf(c, '1'));
      expect(byKey('unit-section'), findsOneWidget);
      expect(fieldOf(tester, byKey('unit-label')).readOnly, isTrue);
      expect(fieldOf(tester, byKey('symbol-rotation')).readOnly, isTrue);
      for (final k in [
        'unit-rotate-left',
        'unit-rotate-right',
        'symbol-mirror',
        'layer-picker'
      ]) {
        expect(byKey(k), findsNothing, reason: k);
      }
      // The north wall, beyond its inner face.
      await clickAt(Vector2(25500, 16850));
      expect(sectionFinder(ArchitectureTypes.wall, ArchitectureTools.wall),
          findsOneWidget);
      expect(fieldOf(tester, field('thickness')).readOnly, isTrue);
      expect(menuOf(tester, 'justification').enabled, isFalse);
      // The living room, by its name label.
      await clickAt(Vector2(22857, 15478));
      expect(byKey('section-architecture.room'), findsOneWidget);
      expect(fieldOf(tester, field('name')).readOnly, isTrue);
      // The overall depth, by its dimension line.
      await clickAt(Vector2(26300, 15000));
      expect(byKey('section-architecture.dimension'), findsOneWidget);
      expect(menuOf(tester, 'kind').enabled, isFalse);
      // The east wall's window.
      await clickAt(Vector2(25875, 14200));
      expect(sectionFinder(ArchitectureTypes.opening, ArchitectureTools.door),
          findsOneWidget);
      expect(fieldOf(tester, field('width')).readOnly, isTrue);
      expect(byKey('layer-picker'), findsNothing);
    });
  });

  group("the review's killers (Task 5 review R-2, R-3, R-4)", () {
    testWidgets(
        'R-3 full.copyWith(changeLayer: false): no layer picker for 1, while '
        'the wall\'s thickness edits; full.copyWith(reshape: false): the '
        'picker for 1, while the thickness is read-only', (tester) async {
      final c = await mountEditor(tester,
          permissions: PlanPermissions.full.copyWith(changeLayer: false));
      final d = c.document;
      await select(tester, c, [tableOf(c, '1')]);
      expect(byKey('layer-picker'), findsNothing);
      final wall = firstOf<WallParams>(d);
      await select(tester, c, [wall]);
      expect(fieldOf(tester, field('thickness')).readOnly, isFalse);
      await typeAndSubmit(tester, field('thickness'), '300');
      expect(d.components.get<WallParams>(wall)!.thickness, 300);
      await setPermissions(
          tester, c, PlanPermissions.full.copyWith(reshape: false));
      await select(tester, c, [tableOf(c, '1')]);
      expect(byKey('layer-picker'), findsOneWidget);
      await select(tester, c, [wall]);
      expect(fieldOf(tester, field('thickness')).readOnly, isTrue);
    });

    testWidgets(
        'R-4 a tool\'s settings are no edit: with the Door tool active under '
        'full.copyWith(reshape: false), its width edits the tool, not the '
        'design', (tester) async {
      final c = await mountEditor(tester,
          permissions: PlanPermissions.full.copyWith(reshape: false));
      await press(tester, LogicalKeyboardKey.keyD);
      expect(c.activeTool.value, ArchitectureTools.door);
      expect(fieldOf(tester, field('width')).readOnly, isFalse);
      final before = encoded(c);
      await typeAndSubmit(tester, field('width'), '1000');
      expect(fieldOf(tester, field('width')).controller.text, '1000');
      expect(encoded(c), before);
    });
  });
}
