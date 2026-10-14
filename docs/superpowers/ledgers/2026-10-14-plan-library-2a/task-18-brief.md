### Task 18: `PlanLayerPanel`, `PlanPagePanel` and the layer picker (spec P2 widgets, P2 permissions, P4 locks)

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/panels/layer_row.dart` (port)
- Create: `packages/jet_cad_2d_plan/lib/src/panels/plan_layer_panel.dart` (port + the controller seam)
- Create: `packages/jet_cad_2d_plan/lib/src/panels/layer_picker.dart` (port; E1 in place of `isParametricObject`; the lock check)
- Create: `packages/jet_cad_2d_plan/lib/src/panels/plan_page_panel.dart` (port + the controller seam)
- Modify: `packages/jet_cad_2d_plan/lib/src/l10n/strings.dart`, `strings_en.dart`, `strings_de.dart`, `strings_tr.dart` (one word, `lockedNoLayer`)
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (export `PlanLayerPanel`, `PlanPagePanel`)
- Modify: `packages/jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart` (Task 17's `@internal` slot `propertyPanelLayerField`: its initializer becomes the picker, Step 7b; controller ruling R-g)
- Modify (test): `packages/jet_cad_2d_plan/test/panels/colour_row_test.dart` (Task 17's; `CP1` gets back the `layer-picker` assertion Task 17 left here, R-g, R-m)
- Create: `packages/jet_cad_2d_plan/test/support/mark_kit.dart` (a one-type kit; Task 19 reuses it)
- Create: `packages/jet_cad_2d_plan/test/support/layer_plan.dart` (P-6's layers on a `PlanController`)
- Test (ported): `packages/jet_cad_2d_plan/test/panels/selection_page_test.dart` (SE13, SE15, SE16 from Task 17), `packages/jet_cad_2d_plan/test/panels/layer_panel_test.dart`, `test/panels/layer_picker_test.dart`, `test/panels/page_panel_test.dart`, `test/panels/page_panel_theme_test.dart`, `test/panels/page_scale_field_test.dart`, `test/l10n/layer_page_words_test.dart`
- Modify (test): `packages/jet_cad_2d_plan/test/l10n/value_words_test.dart` (Task 9's; the new word)
- Test (new): `packages/jet_cad_2d_plan/test/panels/layer_page_controller_test.dart` (LP-1 … LP-8)

**Interfaces:**
- Consumes:
  - Shared interfaces: `PlanController` (Task 8), `PlanPermissions` (Task 12), `PlanLocked` (Task 10), `PlanKit`, `PlanType`, `KitNames` (Tasks 4, sub-project 1), `ParametricCatalog.typeIdOf` (E1, Task 1).
  - The engine: `layerNameProblem`, `layerNameError`, `drawingLayer`, `objectLayer`, `layerIsEmpty`, `AddLayerCommand`, `SetLayerCommand`, `RemoveLayerCommand`, `SetCurrentLayerCommand`, `SetEntityLayerCommand`, `SetInstanceLayerCommand`, `SetComponentCommand<ObjectLayer>`, `foregroundFor` (`jet_cad_2d/lib/src/document/layer_commands.dart:73-150`, `style_resolver.dart:28`).
  - The Flutter layer: `PageNotifier`, `SelectionController`, `SelectionKey`, `displayPaperFor` (`jet_cad_2d_flutter/lib/src/dark_canvas.dart:26`).
  - `PanelFieldFocusNode` from `lib/src/panels/panel_focus.dart` (Task 13 creates it; this task imports it and creates no other).
  - From earlier tasks, by the names listed in "Assumed from earlier tasks" at the end of this task.
- Produces (exported from `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`):
  - `class PlanLayerPanel extends StatefulWidget` — `const PlanLayerPanel({Key? key, required PlanController controller})`.
  - `class PlanPagePanel extends StatefulWidget` — `const PlanPagePanel({Key? key, required PlanController controller})`.
- Produces (package-internal, `lib/src/panels/`, used by Tasks 17 and 20 and by tests):
  - `PlanLayerPanelState` (`bool get isOpen`, `Handle? get selected`); `PlanPagePanelState` (`void resyncScale()`).
  - `LayerRow`, `kLayerColours`, `layerSwatchRgb`, `kLayerRowHeight` (as today's, plus `required PlanController controller`).
  - `List<LayerRecord> layersInPanelOrder(Iterable<LayerRecord>)`, `String nextLayerName(CommandTarget, [PlanStrings])`, `const int kLayerListVisibleRows = 6`.
  - `Handle? layerOfKey(DraftDocument doc, SelectionKey key, {required bool Function(Handle) isObject})`.
  - `String? layerPickerBlocked(DraftDocument doc, Iterable<SelectionKey> keys, {required bool Function(Handle) isObject, required bool Function(Handle) isLocked, PlanStrings strings = const PlanStringsEn()})`.
  - `DraftCommand? layerMoveCommand(DraftDocument doc, Iterable<SelectionKey> keys, Handle layer, {required bool Function(Handle) isObject})`.
  - `class LayerPicker extends StatelessWidget` — `const LayerPicker({Key? key, required PlanController controller})`.
  - `PlanStrings.lockedNoLayer` (en, de, tr).

Plan decision: **the panels take only the controller** (spec P2, "each widget takes only the controller"). Today's `LayerPanel(document, foreground, editable)` and `PagePanel(document, page, editable)` (`jet_cad_floor_plan/lib/src/layers/layer_panel.dart:82-94`, `page_panel.dart:16-28`) read those three from the controller instead: the document and the page notifier are `controller.document` and `controller.page`; `editable` is `controller.permissions.editLayers` / `.editPage` (spec P2 permissions, "the panels: … layers and page"); the paper's foreground is derived as the shell derives it (`planner_shell.dart:327-342`: `foregroundFor(displayPaperFor(page, surface, brightness))`).

Plan decision: **each panel listens to the controller** (a `ChangeNotifier`) and, on every notification, rebinds its subscriptions when `controller.document` is another object than the one it is bound to. So `load`, `newPlan` and `import` (which swap the document, spec P2 "Documents and views") and a runtime `permissions` change both reach the panel without a key change. Today the shell rebuilt the panels by `ObjectKey(document)` (`floor_plan_view.dart`, the `PlannerShell(key: ObjectKey(document), …)` in `_modes`); the plan library has no shell, so the panel follows by itself.

Plan decision: **every panel commit goes through `controller.execute(DraftCommand) -> bool`** (controller ruling R-b; Task 11's guarded path, so a kit hook that throws during the regeneration a layer or page edit triggers is handled by the failure boundary). `execute` catches `PlanLocked` (and sets `controller.lockHint`, which the canvas shows as the short hint, spec P4), `DanglingReferenceError`, `ArgumentError` and `KitHookFailure`, and answers false; the panels catch only `StateError` (the dispatcher's other refusal, today's `layer_panel.dart:171-180`), which `execute` passes through.

Plan decision: **the layer picker refuses a locked object up front, by its owner chain** (spec P4: a lock loses "a layer change" and "direct edits of its children"): `layerPickerBlocked` answers `PlanStrings.lockedNoLayer` when a key's target or any group or instance above it is locked, checked **before** the plain-group rule, so a missing kit's object (whose type is not registered, so the catalog sees a plain group) is reported as locked. At the choice the picker re-checks today's rules but not the lock: a lock made after the menu opened is refused at commit by the lock expander and caught (spec P4's two layers). `changeLayer` (spec P2) is read at the choice too: a menu opened before the host turned it off answers nothing (today's R-2 rule for `editLayers`, `layer_panel.dart:168-172`).

Plan decision: **the page panel's scale field registers its re-sync with the controller's pending-input settle** (Task 8's hook), as the shell's `_settlePendingInput` called `resyncScale` (`planner_shell.dart:859-865`).

- [ ] **Step 1: The test kit and the layered plan.** Create `packages/jet_cad_2d_plan/test/support/mark_kit.dart`:

```dart
// A one-type kit for the panel and export tests: `mark.cross`, a cross of
// two lines of half-size `size` about the group's local origin. Its type
// is real (it registers, generates and regenerates through the parametric
// system), so a mark is a live parametric object for the catalog (E1).
// `exported: false` gives the same type for the export omission tests.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

final class MarkCross implements Component {
  const MarkCross(this.size);

  static const String componentTypeId = 'mark.cross';

  /// Half the cross's width, in mm.
  final double size;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'size': size};

  static MarkCross fromJson(Map<String, Object?> json) =>
      MarkCross((json['size']! as num).toDouble());

  @override
  bool operator ==(Object other) => other is MarkCross && other.size == size;

  @override
  int get hashCode => size.hashCode;
}

final class MarkCrossType extends ParametricType<MarkCross> {
  const MarkCrossType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(MarkCross params, Transform2 toWorld) {
    final s = params.size;
    return Aabb2.fromPoints([
      for (final c in [
        Vector2(-s, -s),
        Vector2(s, -s),
        Vector2(s, s),
        Vector2(-s, s),
      ])
        toWorld.transformPoint(c),
    ]);
  }

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final s = view.paramsOf<MarkCross>(self)!.size;
    return [
      Generated(EntityKind.line, linePayload(Vector2(-s, -s), Vector2(s, s))),
      Generated(EntityKind.line, linePayload(Vector2(-s, s), Vector2(s, -s))),
    ];
  }
}

/// The kit `mark` (version 1.0.0) with its one type; [exported] false
/// leaves marks out of every export (spec P5, "omitted types").
PlanKit markKit({bool exported = true}) => PlanKit(
      id: 'mark',
      version: '1.0.0',
      types: [
        PlanType<MarkCross>(
          id: MarkCross.componentTypeId,
          fromJson: MarkCross.fromJson,
          parametric: const MarkCrossType(),
          exported: exported,
        ),
      ],
      names: const KitNames({
        'en': {'type:mark.cross': 'Cross'},
      }),
    );

/// Adds a mark of half-size [size] at [at] on [layer] to [doc], as a tool
/// adds an object: one compound of its group, its component and its
/// `ObjectLayer`. Returns the group's handle.
Handle addMark(DraftDocument doc, Handle layer,
    {required Transform2 at, double size = 450.5}) {
  final h = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h, parent: doc.rootHandle, transform: at, children: const [])),
    SetComponentCommand<MarkCross>(h, MarkCross(size)),
    SetComponentCommand<ObjectLayer>(h, ObjectLayer(layer)),
  ], label: 'Add mark'));
  return h;
}
```

Create `packages/jet_cad_2d_plan/test/support/layer_plan.dart` (P-6's layers, ported from `apps/floor_planner/test/support/layer_fixture.dart:24-103` and `:157-243`, on a `PlanController` instead of a bare document):

```dart
// Plan 12b P-6 on a PlanController: layers `A` (ACI 1), `B` (ACI 5, locked)
// and `C` (ACI 3, hidden) beside a visible layer 0, each added by
// `AddLayerCommand`; with `objects`, a mark on `A` and a mark on `B`, each
// turned and far from the origin. The plan is built on a scratch
// controller, saved and loaded into the returned one, so it opens clean
// with an empty history, as `layerDoc()`'s `clearHistory()` left it, and
// carries the manifest a plan needs (spec P4).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'mark_kit.dart';

/// Plan millimetres ([x], [y]) at the fixtures' far origin: nothing sits
/// at the origin (CLAUDE.md's testing bar).
Vector2 at(double x, double y) => Vector2(x - 31250.5, y + 18420.25);

/// A group's transform: at plan point ([x], [y]), turned by [turn] rad.
Transform2 placed(double x, double y, double turn) {
  final p = at(x, y);
  return Transform2.translation(p.x, p.y).multiply(Transform2.rotation(turn));
}

/// A controller over P-6's layers, and what was added to it.
final class LayerPlan {
  LayerPlan._(this.controller, this.a, this.b, this.c, this.marks);

  final PlanController controller;

  /// `A` (ACI 1), `B` (ACI 5, locked) and `C` (ACI 3, hidden).
  final Handle a, b, c;

  /// With `objects`: `[0]` a mark on `A`, `[1]` a mark on `B`.
  final List<Handle> marks;

  DraftDocument get doc => controller.document;
}

/// P-6's layers on a fresh plan of [kits] ([markKit] by default). [more]
/// adds to the scratch document before it is saved; what it returns is
/// kept in [LayerPlan.marks] after the fixture's own marks.
LayerPlan layerPlan(
    {bool objects = false,
    List<PlanKit>? kits,
    List<Handle> Function(DraftDocument doc, Handle a, Handle b, Handle c)?
        more}) {
  final scratch = PlanController(kits: [markKit()]);
  final doc = scratch.document;
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  Handle add(String name, int aci, {bool visible = true, bool locked = false}) {
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: handle,
      name: name,
      color: IndexedColor(aci),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: visible,
      locked: locked,
    )));
    return handle;
  }

  final a = add('A', 1);
  final b = add('B', 5, locked: true);
  final c = add('C', 3, visible: false);
  final marks = <Handle>[
    if (objects) ...[
      addMark(doc, a, at: placed(5250.5, 2750.25, 0.35)),
      addMark(doc, b, at: placed(-3100.25, 4400.5, -0.6)),
    ],
    ...?more?.call(doc, a, b, c),
  ];
  final json = scratch.save();
  scratch.dispose();
  final controller = PlanController(kits: kits ?? [markKit()], json: json);
  addTearDown(controller.dispose);
  return LayerPlan._(controller, a, b, c, marks);
}

/// A drafted line on [layer] from plan point ([x1], [y1]) to ([x2], [y2]),
/// as the Line tool adds it: one command. Returns its handle.
Handle addLineOn(DraftDocument doc, Handle layer, double x1, double y1,
    double x2, double y2) {
  final s = at(x1, y1), e = at(x2, y2);
  final add = addDrafted(
      doc,
      EntityKind.line,
      GeometryPayload(
          coords: Float64List.fromList([s.x, s.y, e.x, e.y]),
          scalars: Float64List(0)),
      layer: layer);
  doc.commands.execute(add);
  return add.record.handle;
}
```

Then copy, verbatim apart from the substitutions below, `addRegionOn` (`apps/floor_planner/test/support/layer_fixture.dart:173-203`), `addSymbolOn` (`:205-243`), `layerOf` (`:245-247`) and `objectLayerOf` (`:249-251`) to the end of `layer_plan.dart`. Substitutions: the parameter `LayerDoc l` becomes `DraftDocument doc` (drop the `final doc = l.doc;` lines) and `l.at(` becomes `at(`.

- [ ] **Step 2: The new tests (they fail first).** Create `packages/jet_cad_2d_plan/test/panels/layer_page_controller_test.dart`:

```dart
// Spec P2 (the widgets take only the controller; `editLayers`,
// `editPage` and `changeLayer`; documents swapped inside the controller)
// and P4 (a locked object's layer change refused up front and at commit):
// the Layer and Page panels and the layer picker over a PlanController.
import 'dart:async' show StreamSubscription;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/src/controller/permissions.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/l10n/strings_en.dart';
import 'package:jet_cad_2d_plan/src/panels/layer_picker.dart';
import 'package:jet_cad_2d_plan/src/panels/plan_layer_panel.dart';
import 'package:jet_cad_2d_plan/src/panels/plan_page_panel.dart';

import '../support/layer_plan.dart';
import '../support/mark_kit.dart';

const _en = PlanStringsEn();

Finder byKey(String k) => find.byKey(Key(k));

String hx(Handle h) => h.toHex();

bool enabled(WidgetTester tester, String key) =>
    tester.widget<IconButton>(byKey(key)).onPressed != null;

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// [c]'s Layer and Page panels in a 280-wide right column.
Future<void> pumpPanels(WidgetTester tester, PlanController c) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 280,
          child: SingleChildScrollView(
            child: Column(children: [
              PlanLayerPanel(controller: c),
              PlanPagePanel(controller: c),
            ]),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

/// The picker alone, shown while the selection is not empty and rebuilt on
/// every selection and document change, as `PlanPropertyPanel` mounts it.
class PickerHost extends StatefulWidget {
  const PickerHost(this.controller, {super.key});

  final PlanController controller;

  @override
  State<PickerHost> createState() => _PickerHostState();
}

class _PickerHostState extends State<PickerHost> {
  late final StreamSubscription<DocChange> _changes;

  @override
  void initState() {
    super.initState();
    widget.controller.selection.addListener(_refresh);
    _changes =
        widget.controller.document.commands.changes.listen((_) => _refresh());
  }

  @override
  void dispose() {
    _changes.cancel();
    widget.controller.selection.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.controller.selection.isEmpty
      ? const SizedBox.shrink()
      : LayerPicker(controller: widget.controller);
}

Future<void> pumpPicker(WidgetTester tester, PlanController c) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 280, child: PickerHost(c))))));
  await tester.pump();
}

Future<void> openPicker(WidgetTester tester) async {
  await tester.tap(byKey('layer-picker'));
  await tester.pumpAndSettle();
}

String pickerTooltip(WidgetTester tester) => tester
    .widget<Tooltip>(find.ancestor(
        of: byKey('layer-picker'), matching: find.byType(Tooltip)))
    .message!;

bool pickerEnabled(WidgetTester tester) =>
    tester.widget<PopupMenuButton<Handle>>(byKey('layer-picker')).enabled;

void main() {
  testWidgets(
      'LP-1 a load swaps the document under the Layer panel: the new rows '
      'show, the old document loses the panel\'s listener, the selected row '
      'is dropped, and a control acts on the new document', (tester) async {
    final first = layerPlan();
    final second = layerPlan(objects: true);
    final c = first.controller;
    final old = c.document;
    final base = old.tables.debugListenerCount;
    await pumpPanels(tester, c);
    expect(old.tables.debugListenerCount, base + 1, reason: 'premise');
    await tester.tap(byKey('layer-row-${hx(first.c)}'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
        tester.state<PlanLayerPanelState>(find.byType(PlanLayerPanel)).selected,
        first.c,
        reason: 'premise: a row is selected');

    // The two plans' layers share their handles (one seed sequence), so a
    // panel left on the old document would keep the selected row: the
    // listener count and the dropped selection tell the two apart.
    final json = second.controller.save();
    c.load(json);
    await settle(tester);
    final now = c.document;
    expect(identical(now, old), isFalse, reason: 'premise: swapped');
    // M-LP-1: `_onController` rebuilds without `_bind()`.
    expect(old.tables.debugListenerCount, base,
        reason: 'the old document lost the panel');
    expect(
        tester.state<PlanLayerPanelState>(find.byType(PlanLayerPanel)).selected,
        isNull);
    final lock = 'layer-lock-${hx(second.a)}';
    expect(byKey(lock), findsOneWidget);
    await tester.tap(byKey(lock));
    await settle(tester);
    expect(now.tables.layers[second.a]!.locked, isTrue);
    expect(now.commands.undoDepth, 1);
  });

  testWidgets(
      'LP-2 editLayers off at runtime disables + and every row control with '
      'the neutral reason; a colour menu opened before picks nothing; on '
      'again enables them', (tester) async {
    final fx = layerPlan();
    final c = fx.controller;
    await pumpPanels(tester, c);
    final a = hx(fx.a);
    // The colour menu opened while editing is allowed.
    await tester.tap(byKey('layer-colour-$a'));
    await tester.pumpAndSettle();
    final before = DraftDocumentCodec.encodeToString(c.document);

    c.permissions = PlanPermissions.full.copyWith(editLayers: false);
    await tester.pump();
    final item = byKey('layer-colour-item-4');
    expect(item, findsWidgets, reason: 'the menu is still open');
    await tester.tap(item.last);
    await tester.pumpAndSettle();
    // M-LP-2: `_allowed` ignores `permissions.editLayers`.
    expect(DraftDocumentCodec.encodeToString(c.document), before);
    expect(c.document.commands.undoDepth, 0);
    for (final key in [
      'layers-add',
      'layer-eye-$a',
      'layer-lock-$a',
      'layer-current-$a',
    ]) {
      expect(enabled(tester, key), isFalse, reason: key);
    }
    expect(
        tester.widget<PopupMenuButton<int>>(byKey('layer-colour-$a')).enabled,
        isFalse);
    expect(
        tester
            .widget<Tooltip>(find.ancestor(
                of: byKey('layers-delete'), matching: find.byType(Tooltip)))
            .message,
        _en.layersLocked);
    expect(byKey('layers-list'), findsOneWidget, reason: 'the list is shown');

    c.permissions = PlanPermissions.full;
    await tester.pump();
    expect(enabled(tester, 'layers-add'), isTrue);
    expect(enabled(tester, 'layer-eye-$a'), isTrue);
  });

  testWidgets(
      'LP-3 a load swaps the document under the Page panel: it shows the new '
      'page\'s scale and unit and edits the new document', (tester) async {
    final first = layerPlan();
    final c = first.controller;
    // A second plan at 1:20 in cm, built on its own controller.
    final other = layerPlan().controller;
    final root = other.document.rootHandle;
    final page = other.document.components.get<PageComponent>(root)!;
    other.document.commands.execute(SetComponentCommand<PageComponent>(
        root,
        page.copyWith(
            scaleDenominator: 20, displayUnit: DisplayUnit.centimeters)));
    final json = other.save();
    await pumpPanels(tester, c);
    expect(tester.widget<TextField>(byKey('page-scale')).controller!.text,
        isNot('20'),
        reason: 'premise');

    c.load(json);
    await settle(tester);
    // M-LP-3: `_onController` does not rebind the page notifier.
    expect(
        tester.widget<TextField>(byKey('page-scale')).controller!.text, '20');
    expect(
        tester.widget<DropdownButton<DisplayUnit>>(byKey('page-unit')).value,
        DisplayUnit.centimeters);
    await tester.tap(byKey('page-grid'));
    await tester.pump();
    expect(c.document.commands.undoDepth, 1, reason: 'the new document');
  });

  testWidgets(
      'LP-4 editPage off at runtime disables every page control and a tap '
      'writes nothing; on again enables them', (tester) async {
    final fx = layerPlan();
    final c = fx.controller;
    await pumpPanels(tester, c);
    c.permissions = PlanPermissions.full.copyWith(editPage: false);
    await tester.pump();
    bool presetEnabled() =>
        tester
            .widget<DropdownButton<SheetSize?>>(byKey('page-preset'))
            .onChanged !=
        null;
    // M-LP-4: `_editable` ignores `permissions.editPage`.
    expect(presetEnabled(), isFalse);
    expect(tester.widget<TextField>(byKey('page-scale')).enabled, isFalse);
    expect(tester.widget<CheckboxListTile>(byKey('page-grid')).onChanged,
        isNull);
    expect(tester.widget<InkWell>(byKey('page-swatch-3')).onTap, isNull);
    final before = DraftDocumentCodec.encodeToString(c.document);
    await tester.tap(byKey('page-grid'));
    await tester.tap(byKey('page-swatch-3'));
    await tester.pump();
    expect(DraftDocumentCodec.encodeToString(c.document), before);
    expect(enabled(tester, 'layers-add'), isTrue,
        reason: 'editLayers is another flag');

    c.permissions = PlanPermissions.full;
    await tester.pump();
    expect(presetEnabled(), isTrue);
  });

  testWidgets(
      'LP-5 the controller\'s settle re-syncs a typed, unsubmitted scale: '
      'the field shows the page\'s scale and nothing is written', (tester) async {
    final fx = layerPlan();
    final c = fx.controller;
    await pumpPanels(tester, c);
    final shown = tester.widget<TextField>(byKey('page-scale')).controller!.text;
    await tester.enterText(byKey('page-scale'), '77');
    await tester.pump();
    expect(tester.widget<TextField>(byKey('page-scale')).controller!.text,
        '77',
        reason: 'premise: typed, not submitted');

    c.settlePendingInput();
    await tester.pump();
    // M-LP-5: the panel registers no settler.
    expect(
        tester.widget<TextField>(byKey('page-scale')).controller!.text, shown);
    expect(c.document.commands.undoDepth, 0);
  });

  testWidgets(
      'LP-6 a missing kit\'s object in the selection: the picker is disabled '
      'with the lock\'s reason, ahead of the plain group\'s', (tester) async {
    // The marks are saved by a plan that has the kit, then opened without
    // it: they are locked (spec P4) and their type is not in the catalog.
    final fx = layerPlan(objects: true, kits: const []);
    final c = fx.controller;
    final line = addLineOn(c.document, fx.a, 1250.5, 3400.25, 4100.75, 3650.5);
    final mark = fx.marks[0];
    expect(c.isLocked(mark), isTrue, reason: 'premise: a missing kit');
    expect(c.catalog.typeIdOf(c.document, mark), isNull,
        reason: 'premise: no type for it');
    await pumpPicker(tester, c);
    c.selection.replace([SelectionKey.root(line), SelectionKey.root(mark)]);
    await tester.pump();
    expect(pickerEnabled(tester), isFalse);
    // M-LP-6: drop the lock test from `layerPickerBlocked`; the reason
    // becomes the plain group's.
    expect(pickerTooltip(tester), _en.lockedNoLayer);
    c.selection.replace([SelectionKey.root(line)]);
    await tester.pump();
    expect(pickerEnabled(tester), isTrue, reason: 'the line alone moves');
  });

  testWidgets(
      'LP-7 an object locked after the picker\'s menu opened: the choice is '
      'refused at commit by the lock, caught, and nothing changes',
      (tester) async {
    final fx = layerPlan(objects: true);
    final c = fx.controller;
    final mark = fx.marks[0];
    expect(c.catalog.typeIdOf(c.document, mark), MarkCross.componentTypeId,
        reason: 'premise: a live object of the kit');
    await pumpPicker(tester, c);
    c.selection.replace([SelectionKey.root(mark)]);
    await tester.pump();
    await openPicker(tester);
    c.lockBroken({mark});
    final before = DraftDocumentCodec.encodeToString(c.document);
    await tester.tap(byKey('layer-picker-item-${hx(ReservedHandles.layerZero)}'));
    await tester.pumpAndSettle();
    // M-LP-7: `LayerPicker._choose` calling `document.commands.execute`
    // in place of `controller.execute`.
    expect(tester.takeException(), isNull);
    expect(DraftDocumentCodec.encodeToString(c.document), before);
    expect(objectLayerOf(c.document, mark), fx.a);
    // M-LP-7b: `PlanController.execute`'s `on PlanLocked` clause does not
    // raise the canvas's lock hint.
    expect(c.lockHint.value, isTrue, reason: 'the refusal is shown');
  });

  testWidgets(
      'LP-8 changeLayer off while the picker\'s menu is open: the choice '
      'does nothing', (tester) async {
    final fx = layerPlan(objects: true);
    final c = fx.controller;
    final line = addLineOn(c.document, fx.a, 1250.5, 3400.25, 4100.75, 3650.5);
    c.document.commands.clearHistory();
    await pumpPicker(tester, c);
    c.selection.replace([SelectionKey.root(line)]);
    await tester.pump();
    await openPicker(tester);
    c.permissions = PlanPermissions.full.copyWith(changeLayer: false);
    await tester.pump();
    await tester.tap(byKey('layer-picker-item-${hx(ReservedHandles.layerZero)}'));
    await tester.pumpAndSettle();
    // M-LP-8: drop the `changeLayer` test from `_choose`.
    expect(c.document.commands.undoDepth, 0);
    expect(layerOf(c.document, line), fx.a);
  });
}
```

Run: `cd packages/jet_cad_2d_plan && flutter test test/panels/layer_page_controller_test.dart`. Expected: compilation errors (`Error when reading 'lib/src/panels/layer_picker.dart'`, `Undefined name 'PlanLayerPanel'`).

- [ ] **Step 3: The ported tests.** Each file is the source file copied, with the fixture and import adaptations below; **every `expect` is unchanged** (A12). Where a source test is not ported, the reason is given.

**`test/panels/page_panel_test.dart`** — from `packages/jet_cad_floor_plan/test/page_panel_test.dart` (all 7 tests: "each toggle is exactly one command, and undo reverts the control"; "preset, orientation, unit and swatch each issue one command"; "the scale field commits on submit, refuses junk"; PS1, PS2, PS3; "a custom size shows Custom"). Adaptations:
- Imports `:5-6` become `package:jet_cad_2d_plan/src/controller/plan_controller.dart`, `package:jet_cad_2d_plan/src/l10n/localizations.dart` (Task 9) and `package:jet_cad_2d_plan/src/panels/plan_page_panel.dart`.
- `docWithPage()` (`:9-16`) and `separatorPage(s)` (`:105-118`) return a `PlanController` whose document carries the source's page with an empty history:

```dart
PlanController planWithPage(PageComponent page) {
  final scratch = PlanController(kits: const []);
  scratch.document.commands.execute(SetComponentCommand<PageComponent>(
      scratch.document.rootHandle, page));
  final json = scratch.save();
  scratch.dispose();
  return PlanController(kits: const [], json: json);
}
```

  `docWithPage()` is `planWithPage(PageComponent(originX: 7350, originY: -1230))`; `separatorPage(s)` passes the source's `PageComponent(...)` of `:110-115` unchanged. Each test then reads `final doc = c.document;` and `addTearDown(c.dispose)` replaces `addTearDown(page.dispose)`.
- `pump(tester, doc, page)` and `pumpIn(tester, locale, doc, page)` pump `PlanPagePanel(controller: c)` in the same `SizedBox(width: 280)`; `floorPlanSupportedLocales` / `floorPlanLocalizationsDelegates` become `planSupportedLocales` / `planLocalizationsDelegates`.

**`test/panels/layer_panel_test.dart`** — from `apps/floor_planner/test/layers/layer_panel_test.dart`, every test of `:155-917` except "in the app: the panel sits between the Selection and Page panels; Open shows …" (`:826-865`: the app's document host; the panel's place in the editor is Task 20's ED test). Adaptations:
- Imports `:14-24`: drop `package:floor_planner/document_host.dart`, `package:jet_cad_floor_plan/editor.dart` and the three `../support/` imports; add `package:jet_cad_2d_plan/src/controller/plan_controller.dart`, `package:jet_cad_2d_plan/src/panels/plan_layer_panel.dart`, `package:jet_cad_2d_plan/src/panels/layer_row.dart`, `package:jet_cad_2d_plan/src/shortcuts/plan_shortcut_guard.dart` (Task 15: `planLetterKeys`, `kUndoChords`, `kRedoChords`) and `../support/layer_plan.dart`.
- `ShellCounter`/`pumpPanel` (`:28-71`): `pumpPanel(tester, LayerPlan fx, {ShellCounter? shell})` pumps `PlanLayerPanel(controller: fx.controller)` in place of `LayerPanel(document: doc, foreground: foreground)`; the bindings bind `planLetterKeys(fx.controller)` in place of `kShellLetterKeys` (spec P2: the guard is built from the letters in use, so the shell's own letters are those).
- `sessionOver(doc)` (`:150-151`) is deleted; `session.dirty` reads `fx.controller.dirty` (the controller opened the plan clean).
- `LayerPanelState` / `find.byType(LayerPanel)` become `PlanLayerPanelState` / `find.byType(PlanLayerPanel)`.
- `layerDoc()` becomes `layerPlan()`; `layerFixture(room: false, dimension: false)` becomes `layerPlan(objects: true)` (a mark on `A`, a mark on `B`: `B` is "in use", `C` is empty, as the walls and the door made them); `fx.doc` is unchanged in meaning.
- The swatch test (`:279-300`): the loop's `foreground` is produced by the page, not passed: before each `pumpPanel`, `fx.doc.commands.execute(SetComponentCommand<PageComponent>(root, page.copyWith(background: foreground == 0x000000 ? 0xFFFFFFFF : 0xFF1F3A5F)))` (White takes black ink, Blueprint white: `foregroundFor`, `style_resolver.dart:28`). Its assertions are unchanged.
- S-6 (`:374-398`): the source document is a scratch `PlanController(kits: const [])` whose document gets the two restore commands of `:380-382`; `doc` is `PlanController(kits: const [], json: scratch.save()).document` (the controller added to the test's tear-downs) in place of the `decodeString(… registerAppComponents)` call.
- The "another document" test (`:807-824`): `one` and `two` are `layerPlan()` and `layerPlan(objects: true)`; the panel is pumped with `one.controller`, then with `two.controller` (another controller handed to the same panel: `didUpdateWidget`); the listener-count assertions are unchanged. (The same controller swapping its document is LP-1.)
- "no shell shortcut fires while typing" (`:602-636`): the premise key `LogicalKeyboardKey.keyW` becomes `planLetterKeys(fx.controller).first` and the loop over `kShellLetterKeys` loops over `planLetterKeys(fx.controller)` (W is no generic letter in 2a, spec P2).

**`test/panels/layer_picker_test.dart`** — from `apps/floor_planner/test/layers/layer_picker_test.dart`, the tests of `:135-350` and `:403-521`. Not ported: "in the app: below the Selection section's type section for a wall …" (`:352-401`: the property panel's layout and the Wall and Door tools, Task 17 and sub-project 3) and "a move the document refuses (a regeneration that throws on a broken file) is caught" (`:523-558`: the refusal now goes through Task 11's probe-and-freeze flow, which the F-* tests pin; the picker's catch is LP-7). Adaptations:
- Imports `:17-27`: as for the panel test, plus `package:jet_cad_2d_plan/src/panels/layer_picker.dart`; `_en` is `PlanStringsEn()`.
- `PickerDoc` (`:36-64`) is built on `layerPlan(objects: true, more: …)`: `more` adds the visible layer `D` (`:40-47`), the line, the region and the symbol (`:48-50`, through `layer_plan.dart`'s `addLineOn`, `addRegionOn`, `addSymbolOn`; the fixture keeps their handles in its own fields, captured in the closure) and a second mark on `A` (`addMark(doc, a, at: placed(8800.25, -950.5, 1.1))`), and returns `[thatMark]`. So `p.wall` is `fx.marks[0]` (on `A`), `p.l.walls[1]` is `fx.marks[2]` (on `A`), and `p.door` is `fx.marks[1]` (on `B`). `p.l.a` / `.b` / `.c` read `fx.a` / `.b` / `.c`; `p.doc` is `fx.doc`. The handles `more` creates on the scratch document are the loaded plan's (a save and a load keep handles).
- `pumpPanel(tester, doc)` (`:68-90`) pumps the `PickerHost` of `layer_page_controller_test.dart` (copied into this file) over `fx.controller` and returns `fx.controller.selection`. The two panel-level premises of the first test (`expect(byKey('selection-panel'), findsNothing)` and `expect(byKey('wall-section'), findsNothing, reason: 'premise: a line')`) are dropped with the panel; the picker's own `findsNothing` for an empty selection stays.
- "every registered parametric type … alone" (`:403-451`): the kit has one type, so the six cases become four marks: `more` adds a mark on `D` (`placed(-6400.5, 9100.25, 0.7)`, the box's place) and a mark on layer 0 (`placed(-9800.25, -7300.5, -0.3)`, the separator's place); the cases are `('mark on D', markD, 'D')`, `('mark on A', fx.marks[0], 'A')`, `('mark on B', fx.marks[1], 'B')`, `('mark on 0', mark0, '0')`, and the final move moves `mark0` to `D` where the source moved the separator. `isParametricObject(doc, h)` reads `fx.controller.catalog.typeIdOf(doc, h) != null`. Its assertions are unchanged.
- The swatch test's page change (see the panel test above) and every other direct document write in these tests use `fx.doc.commands.execute(…)`, as the source did.

**`test/panels/page_panel_theme_test.dart`** — from `packages/jet_cad_floor_plan/test/canvas_ui_test.dart`: the premise test (`:36-47`) and D6a (`:49-90`, both themes; Task 15 sent it here). Adaptations: imports `package:jet_cad_2d_plan/src/controller/plan_controller.dart`, `package:jet_cad_2d_plan/src/panels/plan_page_panel.dart` and `../support/canvas_fixture.dart` (Task 15's port of `palette_fixture.dart`) in place of `:14-20`; the document and notifier of `:58-65` become `planWithPage(PageComponent(originX: 7350, originY: -1230, background: ivory))` (the helper of `page_panel_test.dart` above, copied) with `addTearDown(c.dispose)`; `PagePanel(document: doc, page: page)` becomes `PlanPagePanel(controller: c)`; `doc` reads `c.document`. The text entry tests of `canvas_ui_test.dart` stay with Task 15.

**`test/panels/selection_page_test.dart`** — the property-panel cases Task 17 sent here because they need the Page panel: `packages/jet_cad_floor_plan/test/selection_panel_test.dart`'s SE13 (`:942-962`, Enter in the page panel's scale after Width then Height commits both), SE15 (`:982-1007`) and SE16 (`:1009-1034`). They are ported with Task 17's adaptations of `selection_panel_test.dart` (Task 17's `panel_kits.dart`, the box kit's box in place of `floor_planner.box`, Task 16's `design_harness.dart`), the right column pumped as a `Column` of `PlanPropertyPanel(controller: c)` and `PlanPagePanel(controller: c)`; every `expect` unchanged (A12; controller ruling R-m: the assertions moved to the task that owns the Page panel).

**`test/panels/page_scale_field_test.dart`** — the page-panel cases Task 16 sent here from `packages/jet_cad_floor_plan/test/planner_draw_test.dart`: A9 (`:258-…`, letters and Cmd+Z in the scale field neither switch the tool nor undo), A14 (`:414-…`, Escape in the field keeps a pending shape), A15 (`:432-…`, a click into the field cancels a pending text entry), A18 (`:519-…`, Enter commits and hands the focus back), A19 (`:558-…`, a mouse click outside re-syncs), A23 (`:700-…`), A24 (`:725-…`), A25 (`:749-…`, a window blur keeps the typed text), A26 (`:779-…`, 1e20 then Enter writes nothing more). Adaptations: the fixture and helpers are Task 15's `test/support/canvas_fixture.dart` (its port of `planner_draw_test.dart:14-87`: `drawController`, `pumpDraw`, `globalOf`), with the same adaptations Task 16's `palette_draw_test.dart` makes to this file; the shell is replaced by the composition the editor will make: `PlanShortcuts(controller: c, child: Row(children: [Expanded(child: PlanCanvas(controller: c)), SizedBox(width: 280, child: PlanShortcutGuard(controller: c, child: PlanPagePanel(controller: c)))]))` at 1440 x 900; tool letters are the generic ones (`L`, `P`, `T`). A16 and A27 read the bar's read-outs and go to Task 20.

**`test/l10n/layer_page_words_test.dart`** — the panel parts Task 9 sent here:
- NN1 from `packages/jet_cad_floor_plan/test/l10n/numbered_names_test.dart:18-44` (`withLayers` and NN1), verbatim but for `FloorPlanStringsDe`/`Tr` → `PlanStringsDe`/`Tr` and the imports (`package:jet_cad_2d_plan/src/l10n/strings_de.dart`, `strings_tr.dart`, `package:jet_cad_2d_plan/src/panels/plan_layer_panel.dart` for `nextLayerName`).
- PW1 and PW2 from `test/l10n/panel_words_test.dart:74-127`, the Page panel and layer parts: the Wall section's words, fields and edits (`'Duvar'`, `'Kalınlık'`, `'Sol'`, `'Orta'`, `'Sağ'`, `wall-thickness`, `'Dicke'`, `'Thickness'`, `wallOf`) go with the wall to sub-project 3, and the zoom read-out (`find.textContaining('1:12,5 · ')`) to Task 20's bar test; every other assertion is unchanged. `wallPlan()` (`:20-35`) becomes a `layerPlan(more: …)` whose `more` sets the page to `scaleDenominator: 12.5` and adds a mark on `A` (returned, so `fx.marks.last` is it); `app(c, locale)` (`:37-41`) pumps, under the same `MaterialApp(locale:, supportedLocales: planSupportedLocales, localizationsDelegates: planLocalizationsDelegates)`, a `Column` of `PlanLayerPanel(controller: c)`, `PlanPagePanel(controller: c)` and the `PickerHost` of `layer_page_controller_test.dart` (copied), so the picker's `'Katman'` is shown; `pumpWall` selects the mark in place of the wall.
- SE2 from `test/l10n/stale_error_test.dart:89-113`, whole, its name's id renamed `SE2L` (Task 17's ported `selection_panel_test.dart` already holds `SE2`; the assertions are unchanged): `twoTables()` (`:18-36`) becomes `layerPlan(more: …)` adding the layer `Bar` of `:25-35` (two tables are SE1's, 2b), and `pump` (`:38-55`) pumps `PlanLayerPanel(controller: c)` under the locale notifier. SE1 (a table number) is 2b's.

Run: `cd packages/jet_cad_2d_plan && flutter test test/panels test/l10n/layer_page_words_test.dart`. Expected: compilation errors (the panels do not exist yet).

- [ ] **Step 4: The one new word.** In Task 9's `lib/src/l10n/strings.dart`, beside the picker's words (`readOnlyDocument`, `plainGroupNoLayer`):

```dart
  /// The layer picker's reason when a locked object is in the selection
  /// (2a spec P4: a lock loses a layer change).
  String get lockedNoLayer;
```

`strings_en.dart`: `@override String get lockedNoLayer => 'Locked objects cannot change layer';` — `strings_de.dart`: `'Gesperrte Objekte können die Ebene nicht wechseln'` — `strings_tr.dart`: `'Kilitli nesnelerin katmanı değiştirilemez'`. In Task 9's `test/l10n/value_words_test.dart`, inside `main()` after W-VW6:

```dart
  test('LP-W the layer picker\'s lock word in each language', () {
    // M-LP-W: a language that returns the English text for the new word.
    expectWorded((s) => s.lockedNoLayer,
        english: 'Locked objects cannot change layer');
  });
```

- [ ] **Step 5: `layer_row.dart`.** Copy `packages/jet_cad_floor_plan/lib/src/layers/layer_row.dart:1-367` to `packages/jet_cad_2d_plan/lib/src/panels/layer_row.dart`. Adaptations, and nothing else:
  1. The header comment gains a line `// Ported from jet_cad_floor_plan/lib/src/layers/layer_row.dart.`
  2. Imports `:9-11` become:

     ```dart
     import '../controller/plan_controller.dart';
     import '../l10n/strings.dart';
     import '../shortcuts/plan_shortcut_guard.dart';
     import 'panel_focus.dart';
     ```

  3. The constructor (`:46-63`) gains `required this.controller,` as its first named parameter, and the class gains:

     ```dart
     /// The controller whose letters in use the rename field keeps out of
     /// the shortcuts (spec P2: the guard is built from the letters in use).
     final PlanController controller;
     ```

  4. `FloorPlanStrings` becomes `PlanStrings` (`:14` comment, `:188`).
  5. `_field()` (`:316`): `ShellShortcutGuard(` becomes `PlanShortcutGuard(controller: widget.controller,`.

- [ ] **Step 6: `plan_layer_panel.dart`.** Create it. Its top-level helpers are `layer_panel.dart:12-50` copied with `FloorPlanStrings` → `PlanStrings` and `FloorPlanStringsEn` → `PlanStringsEn`; the widget is new around the ported state:

```dart
// Spec 12b D9, D10, D11 and 2a spec P2: the Layers section of the right
// panel, over a PlanController. Ported from
// jet_cad_floor_plan/lib/src/layers/layer_panel.dart.
import 'dart:async' show StreamSubscription;

import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show PageNotifier, displayPaperFor;

import '../controller/plan_controller.dart';
import '../l10n/locale_scope.dart';
import '../l10n/numbered_names.dart';
import '../l10n/strings.dart';
import '../l10n/strings_en.dart';
import '../theme/plan_theme.dart';
import 'layer_row.dart';

// <layer_panel.dart:12-50 here: kLayerListVisibleRows, layersInPanelOrder,
//  nextLayerName, with PlanStrings / PlanStringsEn>

/// The Layers section (spec 12b D9) of [controller]'s plan: a collapsible
/// list of every layer, one [LayerRow] each, with + and delete below.
///
/// **No copy of the layers.** Every build reads the controller's document;
/// the panel rebuilds on its `commands.changes`, its `tables.changes`, the
/// page (ACI 7's swatch follows the paper) and the controller (a document
/// swapped by `load`, `newPlan` or `import`, or new permissions), and moves
/// its subscriptions to a swapped-in document.
///
/// **Each user action is exactly one command**, through
/// `controller.execute`, which answers false for a refusal (`PlanLocked`,
/// `DanglingReferenceError`, `ArgumentError`, a kit's failure); a
/// `StateError` is caught here: nothing changed.
///
/// **Permissions:** every control is disabled while the controller's
/// `permissions.editLayers` is false or the document's permissions refuse
/// [Capability.structure] (D11); the list is still shown.
class PlanLayerPanel extends StatefulWidget {
  const PlanLayerPanel({super.key, required this.controller});

  final PlanController controller;

  @override
  State<PlanLayerPanel> createState() => PlanLayerPanelState();
}

class PlanLayerPanelState extends State<PlanLayerPanel> {
  StreamSubscription<DocChange>? _changes;

  /// The document and page notifier the subscriptions are on.
  DraftDocument? _bound;
  PageNotifier? _boundPage;

  /// Whether the list is shown. Per session, not stored.
  bool _open = true;

  /// The selected row's layer (for delete), or null.
  Handle? _selected;

  /// The layer whose name field is open, or null.
  Handle? _editing;

  final ScrollController _scroll = ScrollController();

  /// Whether the list is shown (the header toggles it).
  bool get isOpen => _open;

  /// The selected row's layer, or null.
  Handle? get selected => _selected;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
    _bind();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlanLocaleScope.push(context, widget.controller);
  }

  @override
  void didUpdateWidget(PlanLayerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
      _bind();
      PlanLocaleScope.push(context, widget.controller);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _unbind();
    _scroll.dispose();
    super.dispose();
  }

  /// A new document (load, newPlan, import) or new permissions: rebinds
  /// when the document is another one, rebuilds either way.
  void _onController() {
    if (!identical(_bound, widget.controller.document)) _bind();
    _refresh();
  }

  void _bind() {
    _unbind();
    final document = widget.controller.document;
    _bound = document;
    _changes = document.commands.changes.listen((_) => _refresh());
    document.tables.changes.addListener(_refresh);
    _boundPage = widget.controller.page..addListener(_refresh);
    _selected = null;
    _editing = null;
  }

  void _unbind() {
    _changes?.cancel();
    _changes = null;
    _bound?.tables.changes.removeListener(_refresh);
    _boundPage?.removeListener(_refresh);
    _bound = null;
    _boundPage = null;
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  DraftDocument get _doc => widget.controller.document;

  bool get _allowed =>
      widget.controller.permissions.editLayers &&
      _doc.commands.permissions.allows(Capability.structure);

  /// Executes [command] through the controller. A refusal is caught: the
  /// dispatcher, the parametric system or the lock expander rolled it
  /// back, so nothing changed, and no gesture surfaces an exception.
  /// Nothing while the panel may not edit: a menu opened before
  /// `editLayers` was turned off still answers after it.
  void _execute(DraftCommand command) {
    if (!_allowed) return;
    try {
      // False: refused (a lock, which raises the hint, a dangling
      // reference, an ArgumentError, a kit's failure); nothing changed.
      widget.controller.execute(command);
    } on StateError {
      // Refused by the dispatcher: nothing changed.
    }
  }

  /// ACI 7's ink on the paper the canvas shows (`planner_shell.dart:327-342`):
  /// the page's background, a dark canvas's paper, or the canvas
  /// background (the theme's surface) for a plan without a page.
  int _foreground(BuildContext context) {
    final theme = Theme.of(context);
    final surface = PlanTheme.of(context)?.canvasBackground ??
        theme.colorScheme.surface;
    return foregroundFor(displayPaperFor(
        page: widget.controller.page.value?.background,
        surface: surface.toARGB32(),
        brightness: theme.brightness));
  }

  // _update, _add, _delete, _deleteBlocked: layer_panel.dart:182-229
  // verbatim, with `FloorPlanStrings` -> `PlanStrings`.

  @override
  Widget build(BuildContext context) {
    // layer_panel.dart:233-352 verbatim, with three changes:
    // - `FloorPlanStrings.of(context)` -> `PlanStrings.of(context)` (:243,
    //   :310);
    // - `foreground: widget.foreground` (:286) -> `foreground: foreground`,
    //   after `final foreground = _foreground(context);` beside `:240`;
    // - `LayerRow(` (:279) gains `controller: widget.controller,`.
  }
}
```

The two comment blocks above stand for the source ranges named in them: the implementer copies those lines in their place, with exactly the substitutions listed, and the result has no `// layer_panel.dart` comments left.

- [ ] **Step 7: `layer_picker.dart`.** Create it:

```dart
// Spec 12b D11, D12 and 2a spec P2, P4: the selection's layer menu.
// Ported from jet_cad_floor_plan/lib/src/layers/layer_picker.dart: "is a
// live object" is the catalog's (E1) in place of the floor planner's
// closed list (`isParametricObject`, :16-29), and a locked object refuses
// its layer change.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show SelectionKey;

import '../controller/plan_controller.dart';
import '../l10n/strings.dart';
import '../l10n/strings_en.dart';
import 'plan_layer_panel.dart' show layersInPanelOrder;

// <layer_picker.dart:31-43 verbatim: _owningInstance, _boundaryOfFill>

/// Key [key]'s layer as the picker shows it (spec 12b D12), or null for a
/// plain group or a key that no longer resolves:
///
/// - an instance's own layer;
/// - an ATTRIB's: its owning instance's;
/// - a live parametric object's ([isObject]): its `objectLayer`;
/// - a drafted region's: its boundary's, whichever record was picked;
/// - any other root entity's: its own.
Handle? layerOfKey(DraftDocument doc, SelectionKey key,
    {required bool Function(Handle h) isObject}) {
  final h = key.target;
  final node = doc.tree[h];
  if (node is InstanceNode) return node.layer;
  if (node is GroupNode) return isObject(h) ? objectLayer(doc, h) : null;
  if (node != null) return null;
  final entities = doc.entities;
  final slot = entities.slotOf(h);
  if (slot == null) return null;
  if (_owningInstance(doc, slot) case final owner?) return owner.layer;
  final boundary = _boundaryOfFill(doc, slot);
  return entities.layerAt(boundary == null ? slot : entities.slotOf(boundary)!);
}

/// Whether [h], or a group or instance above it (its entity owner, then
/// the tree's parents up to the root), is locked.
bool _lockedOrUnderLock(
    DraftDocument doc, Handle h, bool Function(Handle h) isLocked) {
  if (isLocked(h)) return true;
  final slot = doc.entities.slotOf(h);
  Handle? up = slot != null ? doc.entities.ownerAt(slot) : doc.tree[h]?.parent;
  final root = doc.rootHandle;
  while (up != null && up != root) {
    if (isLocked(up)) return true;
    up = doc.tree[up]?.parent;
  }
  return false;
}

/// Why the picker is disabled for [keys] in [doc], or null when it is
/// enabled: a permission set without `Capability.components` (D11); a
/// locked object, or a key under one, among the keys (2a spec P4); a plain
/// group among the keys (D12). In [strings]' language.
String? layerPickerBlocked(DraftDocument doc, Iterable<SelectionKey> keys,
    {required bool Function(Handle h) isObject,
    required bool Function(Handle h) isLocked,
    PlanStrings strings = const PlanStringsEn()}) {
  if (!doc.commands.permissions.allows(Capability.components)) {
    return strings.readOnlyDocument;
  }
  for (final k in keys) {
    if (_lockedOrUnderLock(doc, k.target, isLocked)) {
      return strings.lockedNoLayer;
    }
  }
  for (final k in keys) {
    final node = doc.tree[k.target];
    if (node is GroupNode && !isObject(k.target)) {
      return strings.plainGroupNoLayer;
    }
  }
  return null;
}

/// The one command that moves [keys] to [layer] (spec 12b D12), or null
/// when every member is already on it: `layer_picker.dart:88-153`, with a
/// live parametric object decided by [isObject].
DraftCommand? layerMoveCommand(
    DraftDocument doc, Iterable<SelectionKey> keys, Handle layer,
    {required bool Function(Handle h) isObject}) {
  // layer_picker.dart:107-152 verbatim, with `isParametricObject(doc, h)`
  // (:119) -> `isObject(h)`.
}

bool _never(Handle _) => false;

/// Spec 12b D12: the property panel's layer menu over [controller]'s
/// selection. It shows the selection's common layer ([layerOfKey]), or the
/// strings' `mixed`; choosing a layer dispatches [layerMoveCommand]'s one
/// command through `controller.execute`, built from the document and the
/// selection as they are at the choice. Disabled, with the reason as its
/// tooltip, when [layerPickerBlocked] says so. It keeps no state: its
/// parent rebuilds it on every selection and document change.
class LayerPicker extends StatelessWidget {
  const LayerPicker({super.key, required this.controller});

  final PlanController controller;

  bool _isObject(Handle h) =>
      controller.catalog.typeIdOf(controller.document, h) != null;

  void _choose(Handle layer) {
    final document = controller.document;
    final keys = controller.selection.keys;
    // A menu opened before the host turned `changeLayer` off picks nothing.
    if (!controller.permissions.changeLayer) return;
    // Today's re-check (permissions, a plain group). A lock made after the
    // menu opened is refused at commit by the lock expander (spec P4).
    if (keys.isEmpty ||
        layerPickerBlocked(document, keys,
                isObject: _isObject, isLocked: _never) !=
            null) {
      return;
    }
    if (document.tables.layers[layer] == null) return;
    final command =
        layerMoveCommand(document, keys, layer, isObject: _isObject);
    if (command == null) return;
    try {
      // False: refused (a lock, which raises the hint, a dangling
      // reference, an ArgumentError, a kit's failure); nothing changed.
      controller.execute(command);
    } on StateError {
      // Refused by the dispatcher: nothing changed.
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = controller.document;
    final keys = controller.selection.keys;
    final strings = PlanStrings.of(context);
    final blocked = layerPickerBlocked(document, keys,
        isObject: _isObject, isLocked: controller.isLocked, strings: strings);
    Handle? common;
    var mixed = false;
    for (final k in keys) {
      final l = layerOfKey(document, k, isObject: _isObject);
      if (l == null) continue;
      if (common == null) {
        common = l;
      } else if (common != l) {
        mixed = true;
        break;
      }
    }
    // layer_picker.dart:209-255 verbatim (the label and the Row with its
    // PopupMenuButton), with `FloorPlanStrings` -> `PlanStrings`.
  }
}
```

As in Step 6, each comment that names a source range is replaced by those lines with the listed substitutions.

- [ ] **Step 7b: Fill the property panel's layer slot** (controller ruling R-g). In Task 17's `lib/src/panels/plan_property_panel.dart`, add `import 'layer_picker.dart';` and give the slot its initializer (nothing else in the file changes; the panel already mounts the slot's widget below the colour row while the selection is not empty, no tool's settings show and `permissions.changeLayer` is on):

```dart
/// The layer field's slot (spec P2, "The layer field"): the layer picker
/// (Task 18). Null shows none.
@internal
Widget? Function(BuildContext context, PlanController controller)?
    propertyPanelLayerField =
    (context, controller) => LayerPicker(controller: controller);
```

  In Task 17's `test/panels/colour_row_test.dart`, `CP1` gets back the source's `find.byKey(const Key('layer-picker'))` assertion (`floor_plan/test/colors/color_picker_test.dart:357`), copied unchanged at its place (A12; controller ruling R-m: Task 17 moved it here, to the task that owns the picker).

- [ ] **Step 8: `plan_page_panel.dart`.** Create it. The swatches (`page_panel.dart:39-44`), `_onScaleTapOutside` (`:93-125`, its comment included), `_submitScale` (`:130-139`) and the whole `build` body (`:142-340`) are copied verbatim apart from the substitutions named in the comments below; the rest is:

```dart
// Spec D12 (the page panel) and 2a spec P2: the page's controls over a
// PlanController. Ported from jet_cad_floor_plan/lib/src/page_panel.dart.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show PageNotifier;

import '../controller/plan_controller.dart';
import '../l10n/locale_scope.dart';
import '../l10n/number_text.dart';
import '../l10n/strings.dart';
import '../l10n/strings_en.dart';
import 'panel_focus.dart';

/// The page panel (spec D12) of [controller]'s plan. Every control
/// executes one `SetComponentCommand<PageComponent>` through
/// `controller.execute`; the panel rebuilds from the page notifier, so
/// undo moves the controls back. With `permissions.editPage` false every
/// control is disabled and the values are still shown. It follows a
/// swapped document, and its scale field's re-sync is registered with the
/// controller's pending-input settle.
class PlanPagePanel extends StatefulWidget {
  const PlanPagePanel({super.key, required this.controller});

  final PlanController controller;

  @override
  State<PlanPagePanel> createState() => PlanPagePanelState();
}

class PlanPagePanelState extends State<PlanPagePanel> {
  final TextEditingController _scale = TextEditingController();
  final PanelFieldFocusNode _scaleFocus = PanelFieldFocusNode();

  // <page_panel.dart:39-44: _swatches, verbatim>

  /// The panel's words (spec 14d L12): set before the first build; a
  /// change of language shows the scale again in it.
  PlanStrings _strings = const PlanStringsEn();

  /// The page notifier [_syncScale] listens to: the controller's, rebound
  /// on a swap.
  PageNotifier? _page;

  /// Withdraws [resyncScale]'s registration with the controller.
  VoidCallback? _releaseSettle;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
    _bindPage();
    _releaseSettle = widget.controller.registerSettle(resyncScale);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlanLocaleScope.push(context, widget.controller);
    final next = PlanStrings.of(context);
    if (identical(next, _strings)) return;
    _strings = next;
    if (!_scaleFocus.hasFocus) _syncScale();
  }

  @override
  void didUpdateWidget(PlanPagePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onController);
      _releaseSettle?.call();
      widget.controller.addListener(_onController);
      _releaseSettle = widget.controller.registerSettle(resyncScale);
      _bindPage();
      PlanLocaleScope.push(context, widget.controller);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _releaseSettle?.call();
    _page?.removeListener(_syncScale);
    _scale.dispose();
    _scaleFocus.dispose();
    super.dispose();
  }

  /// A swapped document has a new page notifier: listen to it and show its
  /// scale. New permissions rebuild.
  void _onController() {
    if (!identical(_page, widget.controller.page)) _bindPage();
    if (mounted) setState(() {});
  }

  void _bindPage() {
    _page?.removeListener(_syncScale);
    _page = widget.controller.page..addListener(_syncScale);
    _syncScale();
  }

  /// Shows the page's scale, read from the document, not from the notifier
  /// (page_panel.dart:74-77: a command updates the document at once, the
  /// notifier only after the change stream delivers).
  void _syncScale() {
    final document = widget.controller.document;
    final page = document.components.get<PageComponent>(document.rootHandle);
    if (page == null) return;
    final text = formatPanelNumber(page.scaleDenominator, _strings);
    if (_scale.text != text) _scale.text = text;
  }

  /// Shows the stored scale in the scale field, dropping any text typed and
  /// not submitted, and commits nothing: the controller's settle calls it
  /// before a flow reads the document (D14: unsubmitted text is not saved).
  void resyncScale() => _syncScale();

  bool get _editable => widget.controller.permissions.editPage;

  // <page_panel.dart:93-125 verbatim: _onScaleTapOutside and its comment>

  void _set(PageComponent next) {
    if (!_editable) return;
    final document = widget.controller.document;
    try {
      // False: refused (a lock, which raises the hint, a dangling
      // reference, an ArgumentError, a kit's failure); nothing changed.
      widget.controller.execute(
          SetComponentCommand<PageComponent>(document.rootHandle, next));
    } on StateError {
      // Refused by the dispatcher: nothing changed.
    }
  }

  // <page_panel.dart:130-139 verbatim: _submitScale>

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<PageComponent?>(
        valueListenable: widget.controller.page,
        builder: (context, page, _) {
          // page_panel.dart:145-338 verbatim, with
          // `final editable = widget.editable;` (:147) ->
          // `final editable = _editable;`.
        },
      );
}
```

- [ ] **Step 9: The barrel.** Add to `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart`, in the alphabetical place Task 6's barrel keeps:

```dart
export 'src/panels/plan_layer_panel.dart' show PlanLayerPanel;
export 'src/panels/plan_page_panel.dart' show PlanPagePanel;
```

- [ ] **Step 10: Run the tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/panels test/l10n`. Expected: `All tests passed!`.

- [ ] **Step 11: The gates.** Run `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`. Expected: `All tests passed!`, `No issues found!`, format exit 0. Then `git status --short`: only this task's files (restore any rewritten `analysis_options.yaml` with `git checkout --`).

- [ ] **Step 12: Commit.**

```bash
git add packages/jet_cad_2d_plan/test/panels/selection_page_test.dart packages/jet_cad_2d_plan/test/panels/page_scale_field_test.dart packages/jet_cad_2d_plan/lib/src/panels/layer_row.dart packages/jet_cad_2d_plan/lib/src/panels/plan_layer_panel.dart packages/jet_cad_2d_plan/lib/src/panels/layer_picker.dart packages/jet_cad_2d_plan/lib/src/panels/plan_page_panel.dart packages/jet_cad_2d_plan/lib/src/l10n/strings.dart packages/jet_cad_2d_plan/lib/src/l10n/strings_en.dart packages/jet_cad_2d_plan/lib/src/l10n/strings_de.dart packages/jet_cad_2d_plan/lib/src/l10n/strings_tr.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/test/support/mark_kit.dart packages/jet_cad_2d_plan/test/support/layer_plan.dart packages/jet_cad_2d_plan/test/panels/layer_panel_test.dart packages/jet_cad_2d_plan/test/panels/layer_picker_test.dart packages/jet_cad_2d_plan/test/panels/page_panel_test.dart packages/jet_cad_2d_plan/test/panels/layer_page_controller_test.dart packages/jet_cad_2d_plan/test/panels/page_panel_theme_test.dart packages/jet_cad_2d_plan/test/l10n/layer_page_words_test.dart packages/jet_cad_2d_plan/test/l10n/value_words_test.dart packages/jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart packages/jet_cad_2d_plan/test/panels/colour_row_test.dart
```

Then:

```bash
git commit -m "$(cat <<'EOF'
feat(plan): PlanLayerPanel, PlanPagePanel and the layer picker

The Layers and Page panels and the property panel's layer menu, ported
from the floor planner over a PlanController: they follow a swapped
document and runtime permissions (editLayers, editPage, changeLayer),
commit through the controller and catch a lock's refusal. The picker
asks the catalog whether a group is a live object (E1) and refuses a
locked object up front; the scale field's re-sync joins the controller's
pending-input settle.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 13: Mutation check** (on the committed files; after each, `git checkout -- <file>` and `git diff --quiet -- <file>` exits 0):
  - M-LP-1: in `plan_layer_panel.dart`'s `_onController`, delete the line `if (!identical(_bound, widget.controller.document)) _bind();` → LP-1 red.
  - M-LP-2: in `plan_layer_panel.dart`, `_allowed` becomes `_doc.commands.permissions.allows(Capability.structure)` → LP-2 red.
  - M-LP-3: in `plan_page_panel.dart`'s `_onController`, delete the line `if (!identical(_page, widget.controller.page)) _bindPage();` → LP-3 red.
  - M-LP-4: in `plan_page_panel.dart`, `_editable` becomes `true` → LP-4 red.
  - M-LP-5: in `plan_page_panel.dart`'s `initState`, delete `_releaseSettle = widget.controller.registerSettle(resyncScale);` → LP-5 red.
  - M-LP-6: in `layer_picker.dart`'s `layerPickerBlocked`, delete the loop over `_lockedOrUnderLock` → LP-6 red.
  - M-LP-7: in `layer_picker.dart`'s `_choose`, `controller.execute(command)` → `controller.document.commands.execute(command)` → LP-7 red (the `PlanLocked` reaches the test).
  - M-LP-7b: in `lib/src/controller/plan_controller.dart`'s `execute` (Task 11), delete `lockHint.value = true;` → LP-7 red (the hint is not raised).
  - M-LP-8: in `_choose`, delete `if (!controller.permissions.changeLayer) return;` → LP-8 red.
  - M-LP-slot: in `plan_property_panel.dart`, delete the slot's initializer (`= (context, controller) => LayerPicker(controller: controller)`) → `test/panels/colour_row_test.dart`'s `CP1` red (no `layer-picker`).
  - M-LP-9: in `layer_picker.dart`, `_isObject` returns `false` → the ported "every registered parametric type … alone" test red (the picker is disabled with the plain group's reason).
  - M-LP-W: in `strings_tr.dart`, `lockedNoLayer` returns the English text → LP-W red.
  - M-LP-10: in `layer_row.dart`, `PlanShortcutGuard(controller: widget.controller, child: …)` becomes its `child` alone → the ported "no shell shortcut fires while typing" test red.

#### Assumed from earlier tasks

Each name below is used as written; where the earlier task named it otherwise, the implementer uses that task's name and reports the difference.
- Task 8 (`lib/src/controller/plan_controller.dart`): `PlanController` is a `ChangeNotifier` that notifies its listeners after `load`, `newPlan` and `import` swap the document (with `document`, `page` and `selection` already naming the new ones) and when `permissions` is set; `DraftDocument get document`; `PageNotifier get page`; `SelectionController get selection`; `ParametricCatalog get catalog`; `ValueListenable<bool> get dirty`; `String save()`; `void load(String json)`; `VoidCallback registerSettle(VoidCallback settle)` (registers into the pending-input hook list; the returned callback withdraws it); `void settlePendingInput()` (runs every registered settler).
- Task 9: `PlanStrings` (`lib/src/l10n/strings.dart`) with `PlanStrings.of(BuildContext)` and today's panel words under their `FloorPlanStrings` names (`layers`, `newLayer`, `deleteLayer`, `layersLocked`, `selectLayerToDelete`, `layerZeroUndeletable`, `currentLayerUndeletable`, `layerInUse`, `layerName(n)`, `layerNameProblem(p)`, `colourName(aci)`, `readOnlyDocument`, `plainGroupNoLayer`, `mixed`, `layer`, `missingLayer`, `moveSelectionToLayer`, `pageTitle`, `customSize`, `portrait`, `landscape`, `scale`, `pageDecimalSeparator`, `grid`, `snapToGrid`, `pageBreaks`, `paper`, `decimalSeparator`, and the row's tooltips); `PlanStringsEn` (`strings_en.dart`); `numberedNameIndex` (`l10n/numbered_names.dart`); `formatPanelNumber`, `parsePanelNumber` (`l10n/number_text.dart`); `planSupportedLocales`, `planLocalizationsDelegates` (`l10n/localizations.dart`); `PlanLocaleScope.push(BuildContext, PlanController)` (`l10n/locale_scope.dart`); `PlanTheme.of(BuildContext)` returning the resolved `PlanTheme?` with a nullable `Color? canvasBackground` (`theme/plan_theme.dart`).
- Task 10 (`lib/src/kits/locks.dart`): `PlanLocked`; `bool PlanController.isLocked(Handle)`; `void PlanController.lockBroken(Set<Handle>)` (adds the handles to the locked set and clears the history); a missing kit's objects are locked from the load.
- Task 11: `bool PlanController.execute(DraftCommand)` — the guarded path (controller ruling R-b); it catches `PlanLocked` (setting `lockHint`), `DanglingReferenceError`, `ArgumentError` and `KitHookFailure` and answers false; `StateError` passes through; `ValueNotifier<bool> PlanController.lockHint` (Task 15 shows it and clears it after `kLockHintDuration`).
- Task 12 (`lib/src/controller/permissions.dart`): `PlanPermissions` with `bool editLayers`, `editPage`, `changeLayer`, `PlanPermissions.full`, `copyWith`; `PlanController.permissions` get and set.
- Task 15 (its body moves the guard ahead of Task 16): `PlanShortcutGuard({required PlanController controller, required Widget child})` and `List<LogicalKeyboardKey> planLetterKeys(PlanController)` in `lib/src/shortcuts/plan_shortcut_guard.dart`, which re-exports `chords.dart` (`kUndoChords`, `kRedoChords`); Task 16 makes `planLetterKeys` the letters actually in use. `test/support/canvas_fixture.dart` (the port of `palette_fixture.dart`: `pumpThemed`, `lightTheme`, `darkTheme`, `blueprint`).
- Task 13: `PanelFieldFocusNode` at `lib/src/panels/panel_focus.dart` (the port of `jet_cad_floor_plan/lib/src/panel_focus.dart`, with `handBack()`; Task 13 creates it, and Tasks 17 and 18 import it).
- Task 9: `test/l10n/value_words_test.dart` with `expectWorded` (the port of `value_words_test.dart:20-39`).

#### Interface problem

Resolved by controller ruling R-g: Task 17 leaves the `@internal` slot `propertyPanelLayerField` in `plan_property_panel.dart`; this task ports `layer_picker.dart` (Step 7) and fills the slot (one line in that file, listed under Files), with LP-6 … LP-8 and M-LP-6 … M-LP-9 here.

---

