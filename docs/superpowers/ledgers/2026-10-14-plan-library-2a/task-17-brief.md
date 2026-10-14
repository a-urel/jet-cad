### Task 17: `PlanPropertyPanel` (spec P2 "The widgets", P3 "Property specs", "Colour", P4 "Locks")

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart` (new; the field rules ported from `selection_panel.dart`)
- Create: `packages/jet_cad_2d_plan/lib/src/panels/symbol_section.dart` (port of `symbols/symbol_section.dart`, plus the Rotation row's reading)
- Create: `packages/jet_cad_2d_plan/lib/src/panels/colour_row.dart` (port of `colors/color_picker.dart`, generic over `ColourTarget`)
- Create: `packages/jet_cad_2d_plan/lib/src/panels/frame_safe_relay.dart` (port of `planner_shell.dart:1702-1752`)
- Create: `packages/jet_cad_2d_plan/lib/src/panels/kit_lookup.dart` (new: `planTypeOf`, `planToolOf`, `planWordOf`)
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (export `PlanPropertyPanel`)
- Test support: `packages/jet_cad_2d_plan/test/support/panel_kits.dart` (the box kit and the disc kit; not `box_kit.dart`, which is Task 10's lock fixture)
- Test (new): `packages/jet_cad_2d_plan/test/panels/property_panel_test.dart` (P-1 … P-7, P-two-types, P-swap-pending)
- Test (ported): `packages/jet_cad_2d_plan/test/panels/selection_panel_test.dart`, `test/panels/colour_row_test.dart`, `test/panels/symbol_section_test.dart`, `test/panels/hover_removal_test.dart`

(All paths below are under `packages/jet_cad_2d_plan/` unless they start at the repository root. "`floor_plan/`" abbreviates `packages/jet_cad_floor_plan/`.)

**Interfaces:**
- Consumes:
  - Task 3 (`package:jet_cad_2d_kit/jet_cad_2d_kit.dart`): `PropertySpec` and its eight kinds (`LengthProperty`, `AngleProperty`, `NumberProperty` with `decimals`, `ChoiceProperty` with `values` and `static segmentOf`, `ToggleProperty`, `TextProperty` with `maxLength`, `ValueDisplay` with `unit`, `ActionProperty`), `ValueUnit`, `PlanGate`, `PropertyField` (`spec`, `wordId`, `enabled`, `value`, `commit`), `ColourTarget`. Angles are radians in and out of a field; the degrees are this task's.
  - Task 4: `PlanType` (`parametric`, `hasColour`, `hasSection`, `fieldsOf`, `titleWordOf`, `colourOf`, `recolour`, `commitField`, `sectionFor`), `PlanTool` (`id`, `settings`), `PlanToolSettings.fieldsOf(Object value, void Function(Object) store, {required String toolId})`, `KitNamesWords`, `KitDiagnostic`, `KitDiagnosticCode.hookFailed`, `PlanServices.settingsOf`.
  - Task 9: `PlanSwatch` (the kit), `PlanStrings` (`toolSymbol`, `name`, `size`, `rotation`, `mirror`, `color`, `colorNone`, `colorRefused`, `colorName(PlanSwatch)`, `readOnlyDocument`, `languageCode`, `decimalSeparator`), `PlanStringsEn`, `formatPanelNumber`, `parsePanelNumber`, `panelNumberText`, `PlanLocaleScope.push`, `planLocalizationsDelegates`, `planSupportedLocales`.
  - Task 13: `PanelFieldFocusNode` (`lib/src/panels/panel_focus.dart`, created by Task 13; not created again here), `PlanSymbol` (`kitId`, `entry`, `component`), `placeSymbol`, `definitionForEntry` (`lib/src/symbols/symbol_placer.dart`), `PlanController.symbols`, `symbolsState`.
  - Task 14: `SymbolBox`, `boxOfEntry`, `boxOfDefinition` (`lib/src/symbols/symbol_box.dart`).
  - Tasks 15, 16: `PlanCanvas`, `PlanShortcutGuard`, `canvas_fixture.dart`, `design_harness.dart` (`pumpDesign(right:)`, `press`, `status`, `focusCanvas`, `canvasFocus`), `PlanToolPalette`.
  - Tasks 8, 10, 11, 12: see "Assumed from earlier tasks".
- Produces:
  - Exported from the barrel: `class PlanPropertyPanel extends StatefulWidget` — `const PlanPropertyPanel({Key? key, required PlanController controller})`.
  - `@internal` (in `plan_property_panel.dart`, not exported): `Widget? Function(BuildContext context, PlanController controller)? propertyPanelLayerField` — the layer field's slot. This task leaves it null; Task 18 sets its initializer to its `LayerPicker` (one line in this file). The panel shows the slot's widget below the colour row while the selection is not empty, no tool's settings show and `permissions.changeLayer` is on (today's rule, `selection_panel.dart:1256-1263`).
  - Internal (`lib/src/panels/`): `FrameSafeRelay` (`FrameSafeRelay(Listenable source)`, `deliver()`, `dispose()`); `PlanType<Component>? planTypeOf(PlanController, String typeId)`, `PlanTool? planToolOf(PlanController, String toolId)`, `String? planWordOf(PlanController, String kitId, String wordId)`; `typedef ColourTargetOf = ({Handle handle, PlanType<Component> type})`, `colourTargets`, `pickedColours`, `recolourCommand`, `colourRowBlocked`, `swatchColor`, `class ColourRow`; the symbol section's model (`isSymbolInstance`, `isServableInstance`, `entryOfInstance`, `familyMembers`, `symbolEntriesOf`, `kRotationStepsPerDegree`, `rotationDegreesOf`, `shownRotation`, `degreesShown`, `rotatedTo`, `mirroredAbout`, `rotateSymbolCommand`, `mirrorSymbolCommand`, `changeSizeCommand`).

Plan decision (**what the panel shows**, spec P2): top to bottom, the active tool's settings section while that tool has settings (titled by its `tool:<id>` word); the one selected object's section (its type's fields, titled by `titleWordOf`, then its escape hatch) or, for one selected placed symbol, the generic symbol section; the colour row over the selection, hidden while a tool's settings show (today's rule, `selection_panel.dart:1264-1268`, CP1, CP11 M-PC9-tool); the layer field's slot. Spec P2 puts the object's section "below" the settings, so it shows under them when an object is selected. A locked object (Task 10's `isLocked`) shows no section and takes no part in the colour row (spec P4: a lock loses "its property section" and "a recolour"). "The layer field" (spec P2) is Task 18's `LayerPicker` (the controller's ruling): this task does not implement it and provides the `@internal` slot `propertyPanelLayerField`, which Task 18 fills.

Plan decision (**the field rules are today's**, `selection_panel.dart:79-89`, `:170-186`, `:760-824`, `:1069-1120`): every text field owns a `PanelFieldFocusNode`; the target is pinned when it gains focus; the value commits on its focus loss and on Enter; Enter and a tap outside hand the focus back to the canvas; a value the field cannot parse, the spec refuses (`ArgumentError`, `StateError`: Task 3), or `controller.execute` refuses (the document, the lock) reverts the field to the stored value; a field with focus is never reloaded; a pinned target that is no longer a live object of its type drops the typed text; text equal to what the field shows for the stored value commits nothing (a shown value committed again writes nothing, `panel_number.dart:1-8`), nor does a parsed value equal to the stored one. While a tool's settings show, every valid keystroke reaches them at once (07 D11, 08 D16, `selection_panel.dart:1087-1106`). What changes is where a field comes from: a `PropertyField` that the type or the tool's settings bind, in place of the closed `_Kind` list.

Plan decision (**the kinds**, spec P3): a length is a text field in mm (suffix `mm`); an angle a text field in degrees (suffix `°`, a signed keyboard), shown to a millionth of a degree as the Rotation row is (`kRotationStepsPerDegree`, `symbol_section.dart:92-96`) and stored in radians (`deg * π / 180`); a number a text field shown with its `decimals`; a text a text field, a text over its `maxLength` (code points) refused at the commit; a toggle a `SwitchListTile`; a choice a `DropdownButton` whose items read `property:<owner>.<id>.<segment>` (`ChoiceProperty.segmentOf`); a value display a read-only line, `length` as `<n> mm`, `area` as `<n> m²` (mm² / 10⁶), `angle` as `<n>°`, `none` as `<n>`; an action an `OutlinedButton`. Every number is printed and parsed with the panel's language separator (`formatPanelNumber`, `parsePanelNumber`, today's `number_text.dart:8-35`) (controller ruling R-i: the language's separator for panel fields; the plan's separator governs drawn values). A field is editable while its spec's `enabled` holds, its `gate` (a `PlanPermissions` flag) is on, and the document's permissions allow `components` and the type's `parametric.editCapability` (today's `_editable`, `selection_panel.dart:356-379`); a tool's settings are no document edit and stay editable (`:73`).

Plan decision (**the words**): every label is the kit's word in `controller.locale` with English fallback (`KitNames.word`), the spec id as the last resort; a settings field's word is `property:<tool id>.<id>` (Task 4 binds it with `toolId:`).

Plan decision (**commits go through the controller**, the controller's ruling): every commit of the panel and the colour row goes through `PlanController.execute(DraftCommand) -> bool` (Tasks 10, 11, `@internal`), which catches every refusal (`PlanLocked`, `DanglingReferenceError`, `ArgumentError`, `KitHookFailure`), shows the lock hint or reports the diagnostic itself, and answers false; the panel never calls `document.commands.execute`. An object field commits `type.commitField(document, handle, field, input)` (Task 4: one `SetComponentCommand<T>`, the spec rebound to the current value); a settings field commits `field.commit(input)`, which stores through the settings store (no undo step, no command); the symbol rows commit today's `Rotate`, `Mirror` and `Change size` commands. What can throw before `execute` is caught by the panel: the spec's refusals (`ArgumentError` out of range, `StateError` disabled, Task 3) revert the field; anything else a kit's `write` or `apply` throws reverts it and reports one `hookFailed` diagnostic (spec P4: "a property's write or apply: the field shows its stored value").

Plan decision (**settling before a swap**, Review Focus 4): the panel registers `_settle` with the controller's pending-input hook (`registerSettle`); it hands the focus of a focused field back, so its focus-loss commit lands in the document it was typed for before `load`, `newPlan` or `import` swaps it (today's `_settlePendingInput`, `planner_shell.dart:855-865`). After a swap every field forgets its pinned and loaded target, so no late focus loss writes into the new plan.

Plan decision (**the selection relay**): the panel listens to the selection through `FrameSafeRelay` (today's `_FrameSafeRelay`, `planner_shell.dart:1702-1752`): the canvas's deactivation clears its hover while the panel, outside the canvas, is still active (HR1).

Ported tests and where the others go: `floor_plan/test/selection_panel_test.dart`'s box cases are ported over the box kit (a stand-in for today's `floor_planner.box`, `floor_plan/lib/src/parametric/box.dart`); its wall cases (`WS*`) are sub-project 3's; `SE13`, `SE15`, `SE16` need the Page panel (Task 18). `floor_plan/test/colors/color_picker_test.dart`'s room cases are ported over the box kit's colour target; `CP2` (tint pixels) is the room's (sub-project 3); `CP7` to `CP12` are tables (2b). `floor_plan/test/symbols/symbol_section_test.dart`'s model and panel cases are ported over a kit library; `SS9` (`definitionForEntry`'s assertion) is Task 13's; `SW6`, `SW9` (table numbers and the runtime table rule) are 2b's; `SW7` (a loader handed to the panel) has no counterpart (the controller owns the loader, Task 13). `floor_plan/test/hover_removal_test.dart`'s `HR1` is ported here (Task 15 hands it on).

- [ ] **Step 1: The kits.** Create `test/support/panel_kits.dart`. `BoxType`, `_corners` and `_insideInterval` are `floor_plan/lib/src/parametric/box.dart:35-124` copied unchanged; the rest is new:

```dart
// Two kits for the property panel (2a Task 17). The box kit's box.box is
// today's demo box (floor_plan/lib/src/parametric/box.dart: a rectangle
// whose outline loses what lies inside an overlapping box), drawn with B,
// with a field of every kind, a gate, an enabled rule, a title hook and a
// colour target. The disc kit's disc.disc is another component type (Review
// Focus 3), with an escape-hatch section that throws for a disc over 5 m,
// and a tool, D, whose settings set the next disc's radius.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

enum BoxFinish { matte, gloss }

/// The box's parameters, in mm and radians.
final class BoxParams implements Component {
  const BoxParams(this.width, this.height,
      {this.turn = 0,
      this.count = 1,
      this.finish = BoxFinish.matte,
      this.solid = false,
      this.label = '',
      this.colour});

  static const String componentTypeId = 'box.box';

  final double width;
  final double height;

  /// An angle field's subject; not drawn.
  final double turn;

  /// A number field's subject (one decimal); editable only while [solid].
  final double count;
  final BoxFinish finish;
  final bool solid;
  final String label;

  /// A swatch name, or null.
  final String? colour;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'colour': colour,
        'count': count,
        'finish': finish.name,
        'height': height,
        'label': label,
        'solid': solid,
        'turn': turn,
        'width': width,
      };

  static BoxParams fromJson(Map<String, Object?> json) => BoxParams(
        (json['width']! as num).toDouble(),
        (json['height']! as num).toDouble(),
        turn: (json['turn']! as num).toDouble(),
        count: (json['count']! as num).toDouble(),
        finish: BoxFinish.values.byName(json['finish']! as String),
        solid: json['solid']! as bool,
        label: json['label']! as String,
        colour: json['colour'] as String?,
      );

  BoxParams copyWith(
          {double? width,
          double? height,
          double? turn,
          double? count,
          BoxFinish? finish,
          bool? solid,
          String? label}) =>
      BoxParams(width ?? this.width, height ?? this.height,
          turn: turn ?? this.turn,
          count: count ?? this.count,
          finish: finish ?? this.finish,
          solid: solid ?? this.solid,
          label: label ?? this.label,
          colour: colour);

  BoxParams withColour(String? colour) => BoxParams(width, height,
      turn: turn,
      count: count,
      finish: finish,
      solid: solid,
      label: label,
      colour: colour);

  @override
  bool operator ==(Object other) =>
      other is BoxParams &&
      other.width == width &&
      other.height == height &&
      other.turn == turn &&
      other.count == count &&
      other.finish == finish &&
      other.solid == solid &&
      other.label == label &&
      other.colour == colour;

  @override
  int get hashCode =>
      Object.hash(width, height, turn, count, finish, solid, label, colour);
}

// BoxType, _corners, _insideInterval: floor_plan/lib/src/parametric/box.dart
// :35-124, unchanged.

/// The box at [at] (its lower-left corner) in a group turned [turn] about
/// it: one step, labelled `Add box`; the group takes the current layer.
CompoundCommand boxCommand(DraftDocument doc, Handle h, Vector2 at,
        BoxParams params,
        {double turn = 0}) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: Transform2.translation(at.x, at.y)
              .multiply(Transform2.rotation(turn)),
          children: const [])),
      SetComponentCommand<BoxParams>(h, params),
      SetComponentCommand<ObjectLayer>(h, ObjectLayer(drawingLayer(doc))),
    ], label: 'Add box');

/// floor_plan/lib/src/parametric/box_tool.dart:10-47: two opposite corners,
/// world-axis aligned, one box.
class BoxTool extends RectangleTool {
  BoxTool();

  @override
  String get name => 'Box';

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    final c1 = points.first;
    if (isDegenerateRectangle(c1, point)) return;
    commit(ctx, () {
      final doc = ctx.document;
      return boxCommand(
          doc,
          doc.handleSeed.next(),
          Vector2(math.min(c1.x, point.x), math.min(c1.y, point.y)),
          BoxParams((point.x - c1.x).abs(), (point.y - c1.y).abs()));
    }, needs: const {
      Capability.structure,
      Capability.components,
      Capability.geometry,
    });
    clearShape();
  }
}

final PlanType<BoxParams> boxType = PlanType<BoxParams>(
  id: BoxParams.componentTypeId,
  fromJson: BoxParams.fromJson,
  parametric: const BoxType(),
  properties: [
    LengthProperty<BoxParams>(
        id: 'width',
        read: (p) => p.width,
        write: (p, v) => p.copyWith(width: v),
        min: 1,
        gate: PlanGate.reshape),
    LengthProperty<BoxParams>(
        id: 'height',
        read: (p) => p.height,
        write: (p, v) => p.copyWith(height: v),
        min: 1,
        gate: PlanGate.reshape),
    AngleProperty<BoxParams>(
        id: 'turn', read: (p) => p.turn, write: (p, v) => p.copyWith(turn: v)),
    NumberProperty<BoxParams>(
        id: 'count',
        read: (p) => p.count,
        write: (p, v) => p.copyWith(count: v),
        min: 0,
        max: 99,
        decimals: 1,
        enabled: (p) => p.solid),
    ChoiceProperty<BoxParams, BoxFinish>(
        id: 'finish',
        values: BoxFinish.values,
        read: (p) => p.finish,
        write: (p, v) => p.copyWith(finish: v)),
    ToggleProperty<BoxParams>(
        id: 'solid',
        read: (p) => p.solid,
        write: (p, v) => p.copyWith(solid: v)),
    TextProperty<BoxParams>(
        id: 'label',
        read: (p) => p.label,
        write: (p, v) => p.copyWith(label: v),
        maxLength: 12),
    ValueDisplay<BoxParams>(
        id: 'area', read: (p) => p.width * p.height, unit: ValueUnit.area),
    ActionProperty<BoxParams>(
        id: 'swap', apply: (p) => p.copyWith(width: p.height, height: p.width)),
  ],
  title: (p) => p.solid ? 'type:box.box.solid' : 'type:box.box',
  colour: ColourTarget<BoxParams>(
      read: (p) => p.colour, write: (p, s) => p.withColour(s)),
);

final PlanKit boxKit = PlanKit(
  id: 'box',
  version: '1.0.0',
  types: [boxType],
  tools: [
    PlanTool(
        id: 'box.draw',
        icon: Icons.crop_din,
        letter: 'B',
        needs: const {
          Capability.structure,
          Capability.components,
          Capability.geometry,
        },
        create: (_) => BoxTool()),
  ],
  names: const KitNames({
    'en': {
      'type:box.box': 'Box',
      'type:box.box.solid': 'Solid box',
      'tool:box.draw': 'Box',
      'property:box.box.width': 'Width',
      'property:box.box.height': 'Height',
      'property:box.box.turn': 'Turn',
      'property:box.box.count': 'Count',
      'property:box.box.finish': 'Finish',
      'property:box.box.finish.matte': 'Matte',
      'property:box.box.finish.gloss': 'Gloss',
      'property:box.box.solid': 'Solid',
      'property:box.box.label': 'Label',
      'property:box.box.area': 'Area',
      'property:box.box.swap': 'Swap sides',
    },
    'tr': {'type:box.box': 'Kutu', 'property:box.box.width': 'Genişlik'},
  }),
);

/// The disc's parameters: a circle of [radius] about the group's origin.
final class DiscParams implements Component {
  const DiscParams(this.radius, {this.colour});

  static const String componentTypeId = 'disc.disc';

  final double radius;
  final String? colour;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'colour': colour, 'radius': radius};

  static DiscParams fromJson(Map<String, Object?> json) => DiscParams(
      (json['radius']! as num).toDouble(),
      colour: json['colour'] as String?);

  DiscParams withRadius(double radius) => DiscParams(radius, colour: colour);
  DiscParams withColour(String? colour) => DiscParams(radius, colour: colour);

  @override
  bool operator ==(Object other) =>
      other is DiscParams && other.radius == radius && other.colour == colour;

  @override
  int get hashCode => Object.hash(radius, colour);
}

final class DiscType extends ParametricType<DiscParams> {
  const DiscType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(DiscParams params, Transform2 toWorld) => Aabb2.fromPoints([
        for (final (x, y) in [(-1, -1), (1, -1), (1, 1), (-1, 1)])
          toWorld
              .transformPoint(Vector2(x * params.radius, y * params.radius)),
      ]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<DiscParams>(self)!;
    return [Generated(EntityKind.circle, circlePayload(Vector2.zero(), p.radius))];
  }
}

CompoundCommand discCommand(
        DraftDocument doc, Handle h, Vector2 at, DiscParams params) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: Transform2.translation(at.x, at.y),
          children: const [])),
      SetComponentCommand<DiscParams>(h, params),
      SetComponentCommand<ObjectLayer>(h, ObjectLayer(drawingLayer(doc))),
    ], label: 'Add disc');

/// The disc tool's settings: the next disc's radius.
final class DiscToolSettings {
  const DiscToolSettings({this.radius = 400});

  final double radius;

  @override
  bool operator ==(Object other) =>
      other is DiscToolSettings && other.radius == radius;

  @override
  int get hashCode => radius.hashCode;
}

/// A click places one disc of the settings' radius there.
class DiscTool extends PlacementTool {
  DiscTool(this.services);

  final PlanServices services;

  @override
  String get name => 'Disc';

  @override
  void accept(Vector2 point, ToolContext ctx) {
    final radius = services.settingsOf<DiscToolSettings>('disc.draw').radius;
    commit(ctx, () {
      final doc = ctx.document;
      return discCommand(
          doc, doc.handleSeed.next(), point, DiscParams(radius));
    }, needs: const {
      Capability.structure,
      Capability.components,
      Capability.geometry,
    });
    clearShape();
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {}
}

final PlanType<DiscParams> discType = PlanType<DiscParams>(
  id: DiscParams.componentTypeId,
  fromJson: DiscParams.fromJson,
  parametric: const DiscType(),
  properties: [
    LengthProperty<DiscParams>(
        id: 'radius',
        read: (p) => p.radius,
        write: (p, v) => p.withRadius(v),
        min: 1),
  ],
  colour: ColourTarget<DiscParams>(
      read: (p) => p.colour, write: (p, s) => p.withColour(s)),
  section: (context, value, commit, words) {
    if (value.radius > 5000) throw StateError('a disc over 5 m');
    return OutlinedButton(
        key: const Key('disc-grow'),
        onPressed: () => commit(value.withRadius(value.radius * 2)),
        child: Text(words.word('property:disc.disc.grow')));
  },
);

final PlanKit discKit = PlanKit(
  id: 'disc',
  version: '1.0.0',
  types: [discType],
  tools: [
    PlanTool(
        id: 'disc.draw',
        icon: Icons.circle,
        letter: 'D',
        needs: const {
          Capability.structure,
          Capability.components,
          Capability.geometry,
        },
        settings: PlanToolSettings<DiscToolSettings>(
            initial: const DiscToolSettings(),
            specs: [
              LengthProperty<DiscToolSettings>(
                  id: 'radius',
                  read: (s) => s.radius,
                  write: (s, v) => DiscToolSettings(radius: v),
                  min: 1),
            ]),
        create: (services) => DiscTool(services)),
  ],
  names: const KitNames({
    'en': {
      'type:disc.disc': 'Disc',
      'tool:disc.draw': 'Disc',
      'property:disc.disc.radius': 'Radius',
      'property:disc.disc.grow': 'Grow',
      'property:disc.draw.radius': 'Radius',
    },
  }),
);

/// A controller over a 1:20 page anchored at (7000, 3000), grid snap off,
/// nothing drawn (`floor_plan/test/support/box_rig.dart:16-28`'s
/// `boxDoc`), with [kits] (the box kit by default).
PlanController boxController({List<PlanKit>? kits}) {
  final m = FlutterTextMeasurer();
  final doc = DraftDocument.empty(measurer: m);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: 7000,
          originY: 3000,
          snapToGrid: false)));
  doc.commands.clearHistory();
  final json = ensureManifest(DraftDocumentCodec.encodeToString(doc));
  unawaited(doc.dispose());
  m.clear();
  final c = PlanController(kits: kits ?? [boxKit], json: json);
  addTearDown(c.dispose);
  return c;
}

/// One box on [c]'s plan, one step; its group's handle.
Handle addBox(PlanController c, Vector2 at, BoxParams params,
    {double turn = 0}) {
  final doc = c.document;
  final h = doc.handleSeed.next();
  doc.commands.execute(boxCommand(doc, h, at, params, turn: turn));
  return h;
}

/// One disc on [c]'s plan, one step; its group's handle.
Handle addDisc(PlanController c, Vector2 at, DiscParams params) {
  final doc = c.document;
  final h = doc.handleSeed.next();
  doc.commands.execute(discCommand(doc, h, at, params));
  return h;
}

/// [kits]' types in a catalog of their own, for `drift()`.
ParametricCatalog catalogOf(List<PlanKit> kits) {
  final catalog = ParametricCatalog();
  for (final kit in kits) {
    for (final t in kit.types) {
      t.registerInto(catalog);
    }
  }
  return catalog;
}
```

  The file also imports `dart:async` (`unawaited`), `package:flutter_test/flutter_test.dart` (`addTearDown`), `package:jet_cad_2d_plan/jet_cad_2d_plan.dart` and `package:jet_cad_2d_plan/src/file/plan_file.dart` (`ensureManifest`).

- [ ] **Step 2: The new tests.** Create `test/panels/property_panel_test.dart`:

```dart
// Spec 2a P2 ("The widgets"), P3 (properties, colour), P4 (locks), Review
// Focus 3 and 4: PlanPropertyPanel over the box and disc kits, in the
// design composition (the keyboard, the palette, the canvas, the panel on
// the right) under the drawing fixture's rotated, zoomed camera. The boxes
// sit off the origin; box values are away from their defaults.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/panel_kits.dart';
import '../support/canvas_fixture.dart';
import '../support/design_harness.dart';

Finder byKey(String k) => find.byKey(Key(k));

String textOf(WidgetTester tester, String key) =>
    tester.widget<TextField>(byKey(key)).controller!.text;

bool readOnly(WidgetTester tester, String key) =>
    tester.widget<TextField>(byKey(key)).readOnly;

Future<void> select(
    WidgetTester tester, PlanController c, List<Handle> hs) async {
  c.selection.replace([for (final h in hs) SelectionKey.root(h)]);
  await tester.pump();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key).last);
  await tester.tap(byKey(key).last);
  await tester.pumpAndSettle();
}

Future<void> enterAndSubmit(
    WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await tester.pump();
  await tester.enterText(byKey(key), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

Future<PlanController> panel(WidgetTester tester, PlanController c) async {
  await pumpDesign(tester, c, right: PlanPropertyPanel(controller: c));
  return c;
}

void main() {
  testWidgets(
      'P-1 every kind shows the stored value (an angle in degrees, an area '
      'in m²) and each edit is one step storing exactly its value (M-P-1a, '
      'M-P-1b, M-P-1c)', (tester) async {
    final c = boxController();
    final b = addBox(c, Vector2(7010, 3020),
        const BoxParams(120, 70, turn: math.pi / 6, count: 3, label: 'Shelf'),
        turn: 0.61);
    await panel(tester, c);
    await select(tester, c, [b]);
    BoxParams p() => c.document.components.get<BoxParams>(b)!;
    final depth = c.document.commands.undoDepth;
    expect(textOf(tester, 'property-width'), '120');
    expect(textOf(tester, 'property-turn'), '30');
    expect(textOf(tester, 'property-count'), '3');
    expect(textOf(tester, 'property-label'), 'Shelf');
    expect(tester.widget<Text>(byKey('property-area')).data, '0.0084 m²');

    await enterAndSubmit(tester, 'property-turn', '45');
    // M-P-1a: degrees stored as typed.
    expect(p().turn, 45 * math.pi / 180);
    await tapKey(tester, 'property-solid');
    expect(p().solid, isTrue);
    await enterAndSubmit(tester, 'property-count', '2.26');
    expect(p().count, 2.3, reason: 'one decimal (Task 3 rounds)');
    await enterAndSubmit(tester, 'property-label', 'Desk');
    expect(p().label, 'Desk');
    await tapKey(tester, 'property-finish');
    await tapKey(tester, 'property-finish-gloss');
    expect(p().finish, BoxFinish.gloss);
    expect(
        find.descendant(of: byKey('property-finish'), matching: find.text('Gloss')),
        findsOneWidget);
    await tapKey(tester, 'property-swap');
    expect([p().width, p().height], [70, 120]);
    // M-P-1b: the unchanged-text check dropped makes an Enter on the shown
    // text a second step.
    await enterAndSubmit(tester, 'property-label', 'Desk');
    expect(c.document.commands.undoDepth, depth + 6);
    // M-P-1c: a value the spec refuses (Task 3: over maxLength) reverts.
    await enterAndSubmit(tester, 'property-label', 'A label of 13');
    expect(textOf(tester, 'property-label'), 'Desk');
    expect(c.document.commands.undoDepth, depth + 6);
  });

  testWidgets(
      'P-2 a field\'s gate: reshape off makes Width and Height read-only and '
      'refuses their commit; ungated fields stay editable (M-P-2)',
      (tester) async {
    final c = boxController();
    final b = addBox(c, Vector2(7010, 3020), const BoxParams(120, 70));
    await panel(tester, c);
    c.permissions = PlanPermissions.full.copyWith(reshape: false);
    await tester.pump();
    await select(tester, c, [b]);
    expect(readOnly(tester, 'property-width'), isTrue);
    expect(readOnly(tester, 'property-height'), isTrue);
    expect(readOnly(tester, 'property-label'), isFalse);
    final depth = c.document.commands.undoDepth;
    await enterAndSubmit(tester, 'property-width', '150');
    expect(c.document.components.get<BoxParams>(b)!.width, 120);
    expect(c.document.commands.undoDepth, depth);
  });

  testWidgets(
      'P-3 a field the spec\'s enabled rule refuses is read-only until the '
      'rule holds (M-P-3)', (tester) async {
    final c = boxController();
    final b = addBox(c, Vector2(7010, 3020), const BoxParams(120, 70));
    await panel(tester, c);
    await select(tester, c, [b]);
    expect(readOnly(tester, 'property-count'), isTrue);
    await tapKey(tester, 'property-solid');
    expect(readOnly(tester, 'property-count'), isFalse);
  });

  testWidgets(
      'P-4 the section is titled by the type\'s title hook: Box, then Solid '
      'box once solid; Kutu in Turkish (M-P-4)', (tester) async {
    final c = boxController();
    final b = addBox(c, Vector2(7010, 3020), const BoxParams(120, 70));
    await panel(tester, c);
    await select(tester, c, [b]);
    Text title() => tester.widget<Text>(byKey('section-box.box'));
    expect(title().data, 'Box');
    await tapKey(tester, 'property-solid');
    expect(title().data, 'Solid box');
    c.reportLocale(const Locale('tr'));
    await tapKey(tester, 'property-solid');
    expect(title().data, 'Kutu');
  });

  testWidgets(
      'P-5 an armed tool with settings shows them; a typed radius reaches the '
      'settings at once, no undo step, and the next click\'s disc has it '
      '(M-P-5a, M-P-5b)', (tester) async {
    final c = boxController(kits: [boxKit, discKit]);
    await panel(tester, c);
    await focusCanvas(tester);
    await press(tester, LogicalKeyboardKey.keyD);
    expect(byKey('settings-disc.draw'), findsOneWidget);
    expect(textOf(tester, 'setting-radius'), '400');
    final depth = c.document.commands.undoDepth;
    await tester.tap(byKey('setting-radius'));
    await tester.pump();
    await tester.enterText(byKey('setting-radius'), '250');
    await tester.pump();
    expect(c.document.commands.undoDepth, depth, reason: 'settings: no step');
    // No Enter: the click places with what the keystrokes stored.
    await tester.tapAt(globalOf(tester, c, 7150, 3110));
    await tester.pump();
    final discs = c.document.components.withComponent<DiscParams>().toList();
    expect(discs, hasLength(1));
    expect(c.document.components.get<DiscParams>(discs.single)!.radius, 250);
    expect(c.document.commands.undoDepth, depth + 1);
  });

  testWidgets(
      'P-6 a locked object shows no section and no colour row (spec P4) '
      '(M-P-6a, M-P-6b)', (tester) async {
    final c = boxController();
    final b = addBox(c, Vector2(7010, 3020), const BoxParams(120, 70));
    await panel(tester, c);
    await select(tester, c, [b]);
    expect(byKey('section-box.box'), findsOneWidget);
    expect(byKey('color-picker'), findsOneWidget);
    c.lockBroken({b});
    await select(tester, c, []);
    await select(tester, c, [b]);
    expect(byKey('section-box.box'), findsNothing);
    expect(byKey('color-picker'), findsNothing);
  });

  testWidgets(
      'P-7 the escape hatch: its commit is one step; a builder that throws is '
      'contained and the fields stay (M-P-7)', (tester) async {
    final c = boxController(kits: [boxKit, discKit]);
    final d = addDisc(c, Vector2(7300, 3150), const DiscParams(300));
    final big = addDisc(c, Vector2(7600, 3150), const DiscParams(6000));
    await panel(tester, c);
    await select(tester, c, [d]);
    final depth = c.document.commands.undoDepth;
    await tapKey(tester, 'disc-grow');
    expect(c.document.components.get<DiscParams>(d)!.radius, 600);
    expect(c.document.commands.undoDepth, depth + 1);
    await select(tester, c, [big]);
    expect(tester.takeException(), isNull);
    expect(textOf(tester, 'property-radius'), '6000');
    expect(byKey('disc-grow'), findsNothing);
  });

  testWidgets(
      'P-two-types (Review Focus 3) two kits\' types of different component '
      'types: each edits through its fields, and one tap recolours both in '
      'one step, with no runtime type error (M-P-two)', (tester) async {
    final c = boxController(kits: [boxKit, discKit]);
    final b = addBox(c, Vector2(7010, 3020), const BoxParams(120, 70),
        turn: 0.61);
    final d = addDisc(c, Vector2(7300, 3150), const DiscParams(300));
    await panel(tester, c);
    await select(tester, c, [b]);
    await enterAndSubmit(tester, 'property-width', '150');
    expect(c.document.components.get<BoxParams>(b)!.width, 150);
    await select(tester, c, [d]);
    await enterAndSubmit(tester, 'property-radius', '350');
    expect(c.document.components.get<DiscParams>(d)!.radius, 350);
    await select(tester, c, [b, d]);
    final depth = c.document.commands.undoDepth;
    await tapKey(tester, 'color-swatch-teal');
    expect(c.document.components.get<BoxParams>(b)!.colour, 'teal');
    expect(c.document.components.get<DiscParams>(d)!.colour, 'teal');
    expect(c.document.commands.undoDepth, depth + 1);
    expect(tester.takeException(), isNull);
    expect([
      for (final x in c.diagnostics.value)
        if (x.code == KitDiagnosticCode.hookFailed) x
    ], isEmpty);
  });

  testWidgets(
      'P-swap-pending (Review Focus 4) load while a field holds a typed, '
      'uncommitted value: no exception; the value settles into the old plan '
      'and never into the new one (M-P-swap)', (tester) async {
    final other = boxController();
    final twin = addBox(other, Vector2(7010, 3020), const BoxParams(120, 70));
    final json = other.save();
    final c = boxController();
    final b = addBox(c, Vector2(7010, 3020), const BoxParams(120, 70));
    expect(twin, b, reason: 'premise: the same handle in both plans');
    await panel(tester, c);
    await select(tester, c, [b]);
    await tester.tap(byKey('property-width'));
    await tester.pump();
    await tester.enterText(byKey('property-width'), '150');
    await tester.pump();
    final old = c.document;
    c.load(json);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(identical(c.document, old), isFalse, reason: 'premise: swapped');
    expect(old.components.get<BoxParams>(b)!.width, 150,
        reason: 'settled into the plan it was typed for');
    expect(c.document.components.get<BoxParams>(b)!.width, 120);
    // A later focus loss writes nothing into the new plan.
    await select(tester, c, [b]);
    await tester.tap(byKey('section-box.box'));
    await tester.pump();
    expect(c.document.components.get<BoxParams>(b)!.width, 120);
    expect(c.document.commands.canUndo, isFalse);
  });
}
```

- [ ] **Step 3: Run them to see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/panels/property_panel_test.dart`. Expected: compilation errors naming `PlanPropertyPanel`; no test runs.

- [ ] **Step 4: The lookups.** Create `lib/src/panels/kit_lookup.dart`:

```dart
// A kit's type, tool and word by id, over the controller's kit set (load
// order). Not memoised: a kit set holds a handful of kits, and the panel
// asks once per field per build.
import 'package:jet_cad_2d/jet_cad_2d.dart' show Component;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../controller/plan_controller.dart';

PlanType<Component>? planTypeOf(PlanController controller, String typeId) {
  for (final kit in controller.kits.kits) {
    for (final t in kit.types) {
      if (t.id == typeId) return t;
    }
  }
  return null;
}

PlanTool? planToolOf(PlanController controller, String toolId) {
  for (final kit in controller.kits.kits) {
    for (final t in kit.tools) {
      if (t.id == toolId) return t;
    }
  }
  return null;
}

/// [wordId] of kit [kitId] in the controller's locale, else English, else
/// null (`KitNames.word`).
String? planWordOf(PlanController controller, String kitId, String wordId) =>
    controller.kits
        .kitOf(kitId)
        ?.names
        .word(controller.locale.value.languageCode, wordId);
```

- [ ] **Step 5: The relay.** Create `lib/src/panels/frame_safe_relay.dart`: `floor_plan/lib/src/planner_shell.dart:1702-1752` copied, with `_FrameSafeRelay` renamed `FrameSafeRelay` (public within the package, not exported), the doc comment's "from the shell's own update" read "from its owner's update", and the imports `package:flutter/foundation.dart` (`ChangeNotifier`, `Listenable`) and `package:flutter/scheduler.dart` (`SchedulerBinding`, `SchedulerPhase`).

- [ ] **Step 6: The symbol section's model.** Create `lib/src/panels/symbol_section.dart`: `floor_plan/lib/src/symbols/symbol_section.dart:1-231` copied, with exactly these adaptations:
  1. The header (`:1-4`) gains: `// Ported to the kit model: a symbol is a jetcad.symbol definition (the kit's SymbolComponent), a servable one carries a UnitComponent, and a size family is SymbolComponent.family (the K2 field) instead of a family: tag.`
  2. Imports (`:7-15`) become `dart:math`, `package:jet_cad_2d/jet_cad_2d.dart`, `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` (`SymbolComponent`, `SymbolEntry`, `UnitComponent`), `package:vector_math/vector_math_64.dart` (`Vector2`), `../symbols/plan_symbol.dart`, `../symbols/symbol_box.dart`, `../symbols/symbol_placer.dart` (`definitionForEntry`).
  3. `isServableInstance` (`:27-33`): `SeatingComponent` → `UnitComponent`.
  4. `entryOfInstance` (`:35-51`) takes `Iterable<SymbolEntry> entries` in place of `SymbolLibrary library`, loops `for (final e in entries)`, and reads `e.symbol.key`, `e.symbol.version`, `highest.symbol.version`.
  5. `familyTagOf` (`:53-59`) is deleted; `familyMembers` (`:61-90`) becomes:

```dart
final Expando<Map<String, List<SymbolEntry>>> _families =
    Expando<Map<String, List<SymbolEntry>>>('families');

/// The members of [entry]'s size family (V-4, V-5): every entry of [entries]
/// whose symbol has its `family`, one per key (its highest version), none
/// servable, sorted by width then depth. Empty when [entry] has no family.
/// Memoised per entries list and family: the panel rebuilds on every hover.
List<SymbolEntry> familyMembers(List<SymbolEntry> entries, SymbolEntry entry) {
  final family = entry.symbol.family;
  if (family == null) return const [];
  final memo = _families[entries] ??= {};
  return memo[family] ??= () {
    final byKey = <String, SymbolEntry>{};
    for (final e in entries) {
      if (e.unit != null || e.symbol.family != family) continue;
      final seen = byKey[e.symbol.key];
      if (seen == null || e.symbol.version > seen.symbol.version) {
        byKey[e.symbol.key] = e;
      }
    }
    final members = [
      for (final e in byKey.values)
        if (boxOfEntry(e) != null) e
    ]..sort((a, b) {
        final x = boxOfEntry(a)!, y = boxOfEntry(b)!;
        final w = x.width.compareTo(y.width);
        return w != 0 ? w : x.depth.compareTo(y.depth);
      });
    return List<SymbolEntry>.unmodifiable(members);
  }();
}

final Expando<List<SymbolEntry>> _entriesOf = Expando<List<SymbolEntry>>();

/// The entries of the controller's loaded symbols, one list per symbols
/// list, so [familyMembers]' memo holds across builds.
List<SymbolEntry> symbolEntriesOf(List<PlanSymbol> symbols) =>
    _entriesOf[symbols] ??=
        List<SymbolEntry>.unmodifiable([for (final s in symbols) s.entry]);
```

  6. `rotatedTo` (`:117-147`) calls a local `_isOrthonormal`, copied from `floor_plan/lib/src/symbols/wall_attach.dart:402-407` (the wall attachment is sub-project 3's).
  7. `changeSizeCommand` (`:196-223`): `?.key == entry.key` → `?.key == entry.symbol.key`.
  8. Append the Rotation row's reading (`floor_plan/lib/src/selection_panel.dart:590-597`) and the panel's degrees:

```dart
/// [instance]'s Rotation as the row shows it (09c D7): to a millionth of a
/// degree, so 30 is not 29.999999999999996; 360 shows as 0.
double shownRotation(DraftDocument doc, Handle instance) {
  final deg = rotationDegreesOf((doc.tree[instance]! as InstanceNode).transform);
  final shown =
      (deg * kRotationStepsPerDegree).roundToDouble() / kRotationStepsPerDegree;
  return shown >= 360 ? 0.0 : shown;
}

/// [radians] in degrees as an angle field shows them: to a millionth of a
/// degree, no `-0.0`.
double degreesShown(double radians) {
  final shown = (radians * 180 / math.pi * kRotationStepsPerDegree)
          .roundToDouble() /
      kRotationStepsPerDegree;
  return shown == 0 ? 0.0 : shown;
}
```

- [ ] **Step 7: The colour row.** Create `lib/src/panels/colour_row.dart`:

```dart
// The property panel's colour row (spec 2a P3, "Colour"; plan colours spec
// PC-9): None and the plan's eight swatches over every selected object
// whose type has a colour target, in one step labelled Colour, gated by
// recolor. Ported from jet_cad_floor_plan/lib/src/colors/color_picker.dart:
// the closed list of rooms and tables (pickedColors, :18-53) becomes the
// types' colour targets (PlanType.colourOf, recolour); the swatches,
// marks, tooltips and semantics are today's.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../controller/plan_controller.dart';
import '../l10n/strings.dart';
import 'kit_lookup.dart';

typedef ColourTargetOf = ({Handle handle, PlanType<Component> type});

/// The objects among [keys] whose type has a colour target, each once, in
/// key order: live objects (E1) that are not locked (spec P4).
List<ColourTargetOf> colourTargets(
    PlanController c, Iterable<SelectionKey> keys) {
  if (keys.isEmpty) return const [];
  final doc = c.document;
  return [
    for (final h in {for (final k in keys) k.target})
      if (!c.isLocked(h))
        if (c.catalog.typeIdOf(doc, h) case final typeId?)
          if (planTypeOf(c, typeId) case final type? when type.hasColour)
            (handle: h, type: type),
  ];
}

/// Each target's stored swatch name (null for none), in [colourTargets]'
/// order.
List<String?> pickedColours(PlanController c, Iterable<SelectionKey> keys) => [
      for (final t in colourTargets(c, keys))
        t.type.colourOf(c.document, t.handle),
    ];

/// The one command that sets [swatch] (null: none) on every target among
/// [keys], labelled 'Colour'; null when none would change.
DraftCommand? recolourCommand(
    PlanController c, Iterable<SelectionKey> keys, PlanSwatch? swatch) {
  final doc = c.document;
  final edits = <DraftCommand>[
    for (final t in colourTargets(c, keys))
      if (t.type.recolour(doc, t.handle, swatch?.name) case final edit?) edit,
  ];
  return edits.isEmpty ? null : CompoundCommand(edits, label: 'Colour');
}

/// Why the row is read-only for [keys], or null when it acts (today's
/// `colorPickerBlocked`, `color_picker.dart:72-86`):
/// [PlanStrings.readOnlyDocument] when the document's permissions refuse
/// `components` or a target type's edit capability; [PlanStrings.colorRefused]
/// when `recolor` is off.
String? colourRowBlocked(
    PlanController c, Iterable<SelectionKey> keys, PlanStrings strings) {
  final p = c.document.commands.permissions;
  if (!p.allows(Capability.components) ||
      colourTargets(c, keys)
          .any((t) => !p.allows(t.type.parametric.editCapability))) {
    return strings.readOnlyDocument;
  }
  if (!c.permissions.recolor) return strings.colorRefused;
  return null;
}
```

  followed by `swatchColor` copied from `color_picker.dart:88-93` unchanged, and the widget, `color_picker.dart:95-187` copied with these adaptations: the class is `ColourRow({super.key, required this.controller, this.darkCanvasPaper})` with `final PlanController controller;` (no `document`, `selection`, `capabilities`); `FloorPlanStrings.of` → `PlanStrings.of`; `colorPickerBlocked(document, keys, capabilities, strings)` → `colourRowBlocked(controller, keys, strings)`; `pickedColors(document, keys)` → `pickedColours(controller, keys)`; `FloorPlanColor` → `PlanSwatch`; `strings.colorName(c)` takes the `PlanSwatch`; `selection.keys` → `controller.selection.keys`; and `_choose` becomes:

```dart
  void _choose(PlanSwatch? swatch, PlanStrings strings) {
    final keys = controller.selection.keys;
    if (colourRowBlocked(controller, keys, strings) != null) return;
    final command = recolourCommand(controller, keys, swatch);
    // A refusal is caught inside execute (the lock hint, the diagnostic).
    if (command != null) controller.execute(command);
  }
```

- [ ] **Step 8: The panel.** Create `lib/src/panels/plan_property_panel.dart`:

```dart
// Spec 2a P2 ("The widgets"), P3 (properties, colour), P4 (locks): the
// active tool's settings while a tool with settings is active; the one
// selected object's section (its type's fields titled by its title word,
// then its escape hatch) or the generic symbol section (name, size,
// rotation, mirror, the family's Size menu); the colour row over the
// selection. A locked object shows no section.
//
// The field rules are today's (jet_cad_floor_plan/lib/src/selection_panel.dart,
// spec 06 D13 F1/F2, 07 D11, 10 D21, fix/post-07, post-11): a field owns a
// PanelFieldFocusNode, pins its target at focus gain, commits on its focus
// loss and on Enter, hands the focus back to the canvas, reverts what it
// cannot parse or what is refused, and is never reloaded while focused.
// What changes is where a field comes from: a PropertyField that the type
// (PlanType.fieldsOf) or the tool's settings (PlanToolSettings.fieldsOf)
// bind, in place of the closed list of _Kind values.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:meta/meta.dart' show internal;

import '../controller/plan_controller.dart';
import '../kits/section_boundary.dart' show KitSectionBoundary;
import '../l10n/locale_scope.dart';
import '../l10n/number_text.dart';
import '../l10n/strings.dart';
import '../l10n/strings_en.dart';
import '../shortcuts/plan_shortcut_guard.dart';
import '../symbols/symbol_box.dart';
import 'colour_row.dart';
import 'frame_safe_relay.dart';
import 'kit_lookup.dart';
import 'panel_focus.dart';
import 'symbol_section.dart';

/// The selected object's and the active tool's properties, over
/// [controller].
class PlanPropertyPanel extends StatefulWidget {
  const PlanPropertyPanel({super.key, required this.controller});

  final PlanController controller;

  @override
  State<PlanPropertyPanel> createState() => _PlanPropertyPanelState();
}

/// The layer field's slot (spec P2, "The layer field"): Task 18 sets this
/// initializer to its `LayerPicker`. Null shows none.
@internal
Widget? Function(BuildContext context, PlanController controller)?
    propertyPanelLayerField;

/// What a field edits: one object of a type, one tool's settings, or one
/// placed symbol's rotation.
sealed class _Target {
  const _Target();
}

final class _ObjectTarget extends _Target {
  const _ObjectTarget(this.handle, this.typeId);

  final Handle handle;
  final String typeId;

  @override
  bool operator ==(Object other) =>
      other is _ObjectTarget && other.handle == handle && other.typeId == typeId;

  @override
  int get hashCode => Object.hash(handle, typeId);
}

final class _ToolTarget extends _Target {
  const _ToolTarget(this.toolId);

  final String toolId;

  @override
  bool operator ==(Object other) =>
      other is _ToolTarget && other.toolId == toolId;

  @override
  int get hashCode => toolId.hashCode;
}

final class _SymbolTarget extends _Target {
  const _SymbolTarget(this.handle);

  final Handle handle;

  @override
  bool operator ==(Object other) =>
      other is _SymbolTarget && other.handle == handle;

  @override
  int get hashCode => handle.hashCode;
}

enum _Scope { object, tool, symbol }

/// One text field's state (today's `_Field`, `selection_panel.dart:160-186`):
/// [pinned] is the target recorded at focus gain; [loadedTarget] and
/// [loadedText] are what the field last showed, so a reload can tell a real
/// change from a notification that carries none.
final class _Field {
  _Field(this.scope, this.id);

  final _Scope scope;

  /// The spec id; `rotation` for the symbol's row.
  final String id;
  final TextEditingController text = TextEditingController();
  final PanelFieldFocusNode focus = PanelFieldFocusNode();
  _Target? pinned;
  _Target? loadedTarget;
  String? loadedText;

  void dispose() {
    text.dispose();
    focus.dispose();
  }
}

class _PlanPropertyPanelState extends State<PlanPropertyPanel> {
  PlanController get _c => widget.controller;

  final Map<(_Scope, String), _Field> _fields = {};

  /// The document the subscriptions below belong to.
  DraftDocument? _document;
  StreamSubscription<DocChange>? _changes;
  FrameSafeRelay? _selection;
  VoidCallback? _releaseSettle;

  /// The panel's words: set before the first build and on a change of
  /// language, when the fields are shown again in it (spec 14d L12).
  PlanStrings _strings = const PlanStringsEn();

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlanLocaleScope.push(context, _c);
    final next = PlanStrings.of(context);
    if (identical(next, _strings)) return;
    _strings = next;
    for (final f in _fields.values) {
      if (!f.focus.hasFocus && f.loadedTarget != null) _show(f);
    }
  }

  @override
  void didUpdateWidget(PlanPropertyPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, _c)) return;
    _detach(oldWidget.controller);
    _forgetTargets();
    _attach();
    PlanLocaleScope.push(context, _c);
  }

  @override
  void dispose() {
    _detach(_c);
    for (final f in _fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  static List<Listenable> _listened(PlanController c) =>
      [c.activeTool, c.toolSettings, c.symbolsState, c.locked, c.locale];

  void _attach() {
    final c = _c;
    c.addListener(_onController);
    for (final l in _listened(c)) {
      l.addListener(_sync);
    }
    _releaseSettle = c.registerSettle(_settle);
    _bindDocument();
  }

  void _detach(PlanController c) {
    c.removeListener(_onController);
    for (final l in _listened(c)) {
      l.removeListener(_sync);
    }
    _releaseSettle?.call();
    _releaseSettle = null;
    _unbindDocument();
  }

  void _bindDocument() {
    _document = _c.document;
    _changes = _document!.commands.changes.listen((_) => _sync());
    _selection = FrameSafeRelay(_c.selection)..addListener(_sync);
  }

  void _unbindDocument() {
    _changes?.cancel();
    _changes = null;
    _selection
      ?..removeListener(_sync)
      ..dispose();
    _selection = null;
  }

  /// After a swap no field may write into the new plan what it pinned in
  /// the old one.
  void _forgetTargets() {
    for (final f in _fields.values) {
      f
        ..pinned = null
        ..loadedTarget = null
        ..loadedText = null;
    }
  }

  void _onController() {
    if (!identical(_c.document, _document)) {
      _unbindDocument();
      _forgetTargets();
      _bindDocument();
    }
    _sync();
  }

  /// Review Focus 4: before the controller swaps the document, a focused
  /// field hands its focus back, and its focus-loss commit lands in the plan
  /// it was typed for (today's `_settlePendingInput`,
  /// `planner_shell.dart:855-865`).
  void _settle() {
    var any = false;
    for (final f in _fields.values) {
      if (f.focus.hasFocus) {
        f.focus.handBack();
        any = true;
      }
    }
    if (any) FocusManager.instance.applyFocusChangesIfNeeded();
  }

  // ---- targets ----

  /// The one selected key's target when it is a root-level key.
  Handle? get _single {
    final keys = _c.selection.keys;
    if (keys.length != 1) return null;
    final key = keys.single;
    return key.chain.isEmpty ? key.target : null;
  }

  _ObjectTarget? get _objectTarget {
    final h = _single;
    if (h == null || _c.isLocked(h)) return null;
    final typeId = _c.catalog.typeIdOf(_c.document, h);
    if (typeId == null || planTypeOf(_c, typeId) == null) return null;
    return _ObjectTarget(h, typeId);
  }

  _SymbolTarget? get _symbolTarget {
    final h = _single;
    if (h == null || _c.isLocked(h) || !isSymbolInstance(_c.document, h)) {
      return null;
    }
    return _SymbolTarget(h);
  }

  _ToolTarget? get _toolTarget {
    final id = _c.activeTool.value;
    return planToolOf(_c, id)?.settings == null ? null : _ToolTarget(id);
  }

  _Target? _targetOf(_Field f) => switch (f.scope) {
        _Scope.object => _objectTarget,
        _Scope.tool => _toolTarget,
        _Scope.symbol => _symbolTarget,
      };

  /// [t]'s fields, bound now; none when [t] is no longer a live object of
  /// its type.
  List<PropertyField> _bound(_Target t) {
    final c = _c;
    switch (t) {
      case _ObjectTarget(:final handle, :final typeId):
        if (c.catalog.typeIdOf(c.document, handle) != typeId) return const [];
        return planTypeOf(c, typeId)!.fieldsOf(c.document, handle);
      case _ToolTarget(:final toolId):
        final settings = planToolOf(c, toolId)?.settings;
        if (settings == null) return const [];
        return settings.fieldsOf(c.toolSettings.valueOf(toolId),
            (v) => c.toolSettings.store(toolId, v),
            toolId: toolId);
      case _SymbolTarget():
        return const [];
    }
  }

  PropertyField? _fieldOf(_Target t, String id) {
    for (final f in _bound(t)) {
      if (f.spec.id == id) return f;
    }
    return null;
  }

  // ---- reading and parsing ----

  /// What [f] shows for [t] now, or null when [t] is no longer live.
  String? _shown(_Target t, _Field f) {
    if (t case _SymbolTarget(:final handle)) {
      return isSymbolInstance(_c.document, handle)
          ? formatPanelNumber(shownRotation(_c.document, handle), _strings)
          : null;
    }
    final field = _fieldOf(t, f.id);
    return field == null ? null : _textOf(field);
  }

  String? _textOf(PropertyField field) {
    final value = field.value;
    switch (field.spec) {
      case TextProperty():
        return value is String ? value : null;
      case AngleProperty():
        return value is double
            ? formatPanelNumber(degreesShown(value), _strings)
            : null;
      case NumberProperty(:final decimals):
        return value is double
            ? formatPanelNumber(
                double.parse(value.toStringAsFixed(decimals)), _strings)
            : null;
      case LengthProperty():
        return value is double ? formatPanelNumber(value, _strings) : null;
      case ChoiceProperty() ||
            ToggleProperty() ||
            ValueDisplay() ||
            ActionProperty():
        return null;
    }
  }

  double? _number(String text) {
    final v = parsePanelNumber(text, _strings);
    return v != null && v.isFinite ? v : null;
  }

  /// [f]'s text as the input to commit to [t], or null when the field
  /// reverts instead.
  Object? _parse(_Target t, _Field f) {
    final text = f.text.text.trim();
    if (t is _SymbolTarget) return _number(text);
    final field = _fieldOf(t, f.id);
    if (field == null) return null;
    switch (field.spec) {
      case TextProperty(:final maxLength):
        return maxLength != null && text.runes.length > maxLength
            ? null
            : text;
      case AngleProperty():
        final degrees = _number(text);
        return degrees == null ? null : degrees * math.pi / 180;
      case LengthProperty() || NumberProperty():
        return _number(text);
      case ChoiceProperty() ||
            ToggleProperty() ||
            ValueDisplay() ||
            ActionProperty():
        return null;
    }
  }

  /// Whether [t]'s field [id] edits (today's `_editable` and `_capable`,
  /// `selection_panel.dart:356-391`).
  bool _editable(_Target t, String id) {
    final c = _c;
    final engine = c.document.commands.permissions;
    switch (t) {
      case _SymbolTarget():
        // A rotation is a TransformNodeCommand (09c D7).
        return c.permissions.rotate && engine.allows(Capability.transform);
      case _ToolTarget():
        // A tool's settings are no edit of the document (:73).
        final field = _fieldOf(t, id);
        return field != null && field.enabled && field.commit != null;
      case _ObjectTarget(:final typeId):
        final field = _fieldOf(t, id);
        if (field == null || !field.enabled || field.commit == null) {
          return false;
        }
        final gate = field.spec.gate;
        if (gate != null && !c.permissions.allows(gate)) return false;
        return engine.allows(Capability.components) &&
            engine.allows(planTypeOf(c, typeId)!.parametric.editCapability);
    }
  }

  // ---- writing ----

  String _kitOf(_Target t) => switch (t) {
        _ObjectTarget(:final typeId) => kitOfKey(typeId),
        _ToolTarget(:final toolId) => kitOfKey(toolId),
        _SymbolTarget() => 'plan',
      };

  /// Runs [edit]. A commit goes through `controller.execute`, which catches
  /// every refusal itself (the lock hint, the diagnostics) and answers
  /// false. What can throw here is what runs before it: the spec's refusals
  /// (`ArgumentError` out of range, `StateError` disabled: Task 3) change
  /// nothing and the field shows the stored value; anything else a kit's
  /// `write` or `apply` threw is one diagnostic (spec P4).
  void _guarded(_Target t, String what, void Function() edit) {
    final c = _c;
    try {
      edit();
    } on ArgumentError {
      // Refused by the spec: nothing changed.
    } on StateError {
      // Refused: a disabled field. Nothing changed.
    } on Object catch (error) {
      c.diagnosticsLog.report(KitDiagnostic(
          kitId: _kitOf(t),
          subject: switch (t) {
            _ObjectTarget(:final typeId) => typeId,
            _ToolTarget(:final toolId) => toolId,
            _SymbolTarget() => 'plan.symbol',
          },
          code: KitDiagnosticCode.hookFailed,
          message: '$what threw',
          error: error));
    }
  }

  /// Stores [input] as [t]'s field [id]: one command for an object or a
  /// symbol, the settings for a tool, nothing when the value is unchanged.
  void _write(_Target t, String id, Object? input) {
    final c = _c;
    _guarded(t, 'the property "$id"', () {
      switch (t) {
        case _SymbolTarget(:final handle):
          final command =
              rotateSymbolCommand(c.document, handle, input! as double);
          if (command != null) c.execute(command);
        case _ObjectTarget(:final handle, :final typeId):
          final field = _fieldOf(t, id);
          if (field == null || (input != null && input == field.value)) {
            return;
          }
          c.execute(planTypeOf(c, typeId)!
              .commitField(c.document, handle, field, input));
        case _ToolTarget():
          final field = _fieldOf(t, id);
          if (field == null || (input != null && input == field.value)) {
            return;
          }
          field.commit!(input);
      }
    });
  }

  /// A click (a toggle, a choice, an action) acts on the target shown now.
  void _act(_Target t, String id, Object? input) {
    _write(t, id, input);
    if (mounted) setState(() {});
  }

  // ---- the field cycle (selection_panel.dart:760-1008) ----

  _Field _fieldFor(_Scope scope, String id) =>
      _fields.putIfAbsent((scope, id), () {
        final f = _Field(scope, id);
        f.focus.addListener(() => _onFocusChange(f));
        _show(f);
        return f;
      });

  /// Records the target on focus gain; commits on focus loss. `??=`: a
  /// focused node that notifies again keeps its pin.
  void _onFocusChange(_Field f) {
    if (f.focus.hasFocus) {
      f.pinned ??= _targetOf(f);
      return;
    }
    _commit(f);
  }

  /// Commits [f]'s text to its pinned target, then shows the current
  /// target's value. Text equal to what the field shows for the stored
  /// value commits nothing.
  void _commit(_Field f) {
    final t = f.pinned;
    if (t != null) {
      final shown = _shown(t, f);
      if (shown != null &&
          f.text.text.trim() != shown &&
          _editable(t, f.id)) {
        final input = _parse(t, f);
        if (input != null) _write(t, f.id, input);
      }
    }
    _show(f);
    f.pinned = f.focus.hasFocus ? _targetOf(f) : null;
    if (mounted) setState(() {});
  }

  /// Writes the current target's value into [f], unconditionally.
  void _show(_Field f) {
    final t = _targetOf(f);
    final shown = t == null ? null : _shown(t, f);
    f.loadedTarget = shown == null ? null : t;
    f.loadedText = shown;
    if (shown != null && f.text.text != shown) f.text.text = shown;
  }

  /// Copies the model into the fields, never into a focused one, and only
  /// where the target or its shown value changed (06 D13 F1).
  void _load() {
    for (final f in _fields.values) {
      final t = _targetOf(f);
      final shown = t == null ? null : _shown(t, f);
      if (shown == null) {
        f.loadedTarget = null;
        f.loadedText = null;
        continue;
      }
      if (f.focus.hasFocus) continue;
      if (t == f.loadedTarget && shown == f.loadedText) continue;
      _show(f);
    }
  }

  void _sync() {
    _load();
    if (mounted) setState(() {});
  }

  /// 07 D11, 08 D16: while a tool's settings show, every valid keystroke
  /// reaches them at once (a canvas click accepts its point before the
  /// field's focus-loss commit runs).
  void _onChanged(_Field f) {
    final t = f.pinned;
    if (t is! _ToolTarget) return;
    final input = _parse(t, f);
    if (input != null) _write(t, f.id, input);
  }

  // ---- widgets ----

  Widget _textField(Key key, String label, _Field f, bool editable,
          {String? suffix, bool signed = false, bool isText = false}) =>
      TextField(
        key: key,
        controller: f.text,
        focusNode: f.focus,
        readOnly: !editable,
        // No maxLength formatter: a text over the spec's maxLength is
        // refused at the commit and the field reverts (Task 3's refusal).
        decoration: InputDecoration(labelText: label, suffixText: suffix),
        keyboardType: isText
            ? TextInputType.text
            : TextInputType.numberWithOptions(decimal: true, signed: signed),
        onChanged: (_) => _onChanged(f),
        onSubmitted: (_) => _commit(f),
        // Enter hands the focus back to the canvas, past any other panel
        // field (fix/post-07 F3); onSubmitted still runs after it.
        onEditingComplete: f.focus.handBack,
        // Only unfocuses (06 D13 F2): the commit is _onFocusChange's.
        onTapOutside: (_) => f.focus.handBack(),
      );

  String _valueText(Object? value, ValueUnit unit) {
    if (value is! double) return '—';
    return switch (unit) {
      ValueUnit.length => '${formatPanelNumber(value, _strings)} mm',
      ValueUnit.area => '${formatPanelNumber(value / 1e6, _strings)} m²',
      ValueUnit.angle => '${formatPanelNumber(degreesShown(value), _strings)}°',
      ValueUnit.none => formatPanelNumber(value, _strings),
    };
  }

  Widget _row(_Target t, _Scope scope, PropertyField field, String kitId) {
    final id = field.spec.id;
    final name = '${scope == _Scope.tool ? 'setting' : 'property'}-$id';
    final key = Key(name);
    final label = planWordOf(_c, kitId, field.wordId) ?? id;
    final editable = _editable(t, id);
    switch (field.spec) {
      case LengthProperty():
        return _textField(key, label, _fieldFor(scope, id), editable,
            suffix: 'mm');
      case AngleProperty():
        return _textField(key, label, _fieldFor(scope, id), editable,
            suffix: '°', signed: true);
      case NumberProperty(:final min):
        return _textField(key, label, _fieldFor(scope, id), editable,
            signed: min == null || min < 0);
      case TextProperty():
        return _textField(key, label, _fieldFor(scope, id), editable,
            isText: true);
      case ToggleProperty():
        return SwitchListTile(
          key: key,
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: field.value == true,
          onChanged: editable ? (v) => _act(t, id, v) : null,
        );
      case ChoiceProperty(:final values):
        return InputDecorator(
          decoration:
              InputDecoration(labelText: label, border: InputBorder.none),
          child: DropdownButton<Object?>(
            key: key,
            isExpanded: true,
            value: field.value,
            items: [
              for (final v in values)
                DropdownMenuItem<Object?>(
                  value: v,
                  child: Text(
                      planWordOf(_c, kitId,
                              '${field.wordId}.${ChoiceProperty.segmentOf(v)}') ??
                          ChoiceProperty.segmentOf(v),
                      key: Key('$name-${ChoiceProperty.segmentOf(v)}')),
                ),
            ],
            onChanged: editable ? (v) => _act(t, id, v) : null,
          ),
        );
      case ValueDisplay(:final unit):
        return InputDecorator(
          decoration:
              InputDecoration(labelText: label, border: InputBorder.none),
          child: Text(_valueText(field.value, unit), key: key),
        );
      case ActionProperty():
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton(
              key: key,
              onPressed: editable ? () => _act(t, id, null) : null,
              child: Text(label)),
        );
    }
  }

  List<Widget> _settingsSection(_ToolTarget t, TextStyle? title) {
    final kit = kitOfKey(t.toolId);
    return [
      Text(planWordOf(_c, kit, 'tool:${t.toolId}') ?? t.toolId,
          key: Key('settings-${t.toolId}'), style: title),
      for (final field in _bound(t)) _row(t, _Scope.tool, field, kit),
    ];
  }

  List<Widget> _objectSection(_ObjectTarget t, TextStyle? title) {
    final c = _c;
    final doc = c.document;
    final type = planTypeOf(c, t.typeId)!;
    final kit = kitOfKey(t.typeId);
    return [
      Text(planWordOf(c, kit, type.titleWordOf(doc, t.handle)) ?? t.typeId,
          key: Key('section-${t.typeId}'), style: title),
      for (final field in _bound(t)) _row(t, _Scope.object, field, kit),
      if (type.hasSection)
        // Spec P4: a section builder that throws shows a small box in its
        // place (Task 11's boundary).
        KitSectionBoundary(
          kitId: kit,
          typeId: t.typeId,
          log: c.diagnosticsLog,
          builder: (context) => type.sectionFor(
              context,
              doc,
              t.handle,
              (command) => _guarded(t, 'the section\'s commit',
                  () => c.execute(command)),
              KitNamesWords(c.kits.kitOf(kit)!.names, () => c.locale.value)),
        ),
    ];
  }

  /// The Symbol section (09c D7; `selection_panel.dart:1122-1191`).
  List<Widget> _symbolSection(_SymbolTarget t, TextStyle? title) {
    final c = _c;
    final doc = c.document;
    final h = t.handle;
    final node = doc.tree[h]! as InstanceNode;
    final component = doc.components.get<SymbolComponent>(node.definition)!;
    final box = boxOfDefinition(doc, node.definition);
    final entries = symbolEntriesOf(c.symbols);
    final entry = entryOfInstance(entries, doc, h);
    final members = entry == null || isServableInstance(doc, h)
        ? const <SymbolEntry>[]
        : familyMembers(entries, entry);
    String size(SymbolBox b) => '${formatPanelNumber(b.width, _strings)} × '
        '${formatPanelNumber(b.depth, _strings)}';
    final p = c.permissions;
    final engine = doc.commands.permissions;
    final turnable = engine.allows(Capability.transform);
    final resizable = engine.allows(Capability.structure) &&
        engine.allows(Capability.geometry) &&
        engine.allows(Capability.components) &&
        turnable;
    final name = c.kits
            .kitOf(kitOfKey(component.key))
            ?.names
            .symbolName(_strings.languageCode, component) ??
        component.name;
    return [
      Text(_strings.toolSymbol, key: const Key('symbol-section'), style: title),
      InputDecorator(
        decoration:
            InputDecoration(labelText: _strings.name, border: InputBorder.none),
        child: Text(name, key: const Key('symbol-name')),
      ),
      InputDecorator(
        decoration:
            InputDecoration(labelText: _strings.size, border: InputBorder.none),
        child: Text(box == null ? '—' : size(box),
            key: const Key('symbol-size')),
      ),
      _textField(const Key('symbol-rotation'), _strings.rotation,
          _fieldFor(_Scope.symbol, 'rotation'), _editable(t, 'rotation'),
          suffix: '°', signed: true),
      // A button the permissions refuse is not shown (S-11).
      if (p.mirror) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('symbol-mirror'),
          onPressed: turnable
              ? () => _guarded(t, 'Mirror', () {
                    final command = mirrorSymbolCommand(doc, h);
                    if (command != null) c.execute(command);
                  })
              : null,
          icon: const Icon(Icons.flip),
          label: Text(_strings.mirror),
        ),
      ],
      if (members.isNotEmpty && p.reshape) ...[
        const SizedBox(height: 8),
        DropdownButton<SymbolEntry>(
          key: const Key('symbol-size-menu'),
          isExpanded: true,
          value: members
              .where((m) => m.symbol.key == component.key)
              .firstOrNull,
          items: [
            for (final m in members)
              DropdownMenuItem(
                value: m,
                child: Text(size(boxOfEntry(m)!),
                    key: Key('symbol-size-${m.symbol.key}')),
              ),
          ],
          onChanged: resizable
              ? (m) {
                  if (m == null) return;
                  _guarded(t, 'Change size', () {
                    final command = changeSizeCommand(doc, h, m);
                    if (command != null) c.execute(command);
                  });
                  if (mounted) setState(() {});
                }
              : null,
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    // A parent rebuild may arrive before the controller's notification.
    if (!identical(c.document, _document)) {
      _unbindDocument();
      _forgetTargets();
      _bindDocument();
    }
    final title = Theme.of(context).textTheme.titleSmall;
    final tool = _toolTarget;
    final object = _objectTarget;
    final symbol = object == null ? _symbolTarget : null;
    // CP1, CP11 (M-PC9-tool): no colour row while a tool's settings show.
    final colours =
        tool == null && colourTargets(c, c.selection.keys).isNotEmpty;
    final sections = <List<Widget>>[
      if (tool != null) _settingsSection(tool, title),
      if (object != null) _objectSection(object, title),
      if (symbol != null) _symbolSection(symbol, title),
      if (colours)
        [
          ColourRow(
              controller: c,
              darkCanvasPaper: darkCanvasFor(
                      page: c.page.value?.background,
                      brightness: Theme.of(context).brightness)
                  ? kDarkCanvasPaper
                  : null),
        ],
      // The layer field (Task 18 fills the slot): a non-empty selection,
      // no tool's settings, changeLayer on (selection_panel.dart:1256-1263).
      if (propertyPanelLayerField case final layer?
          when tool == null &&
              c.selection.keys.isNotEmpty &&
              c.permissions.changeLayer)
        if (layer(context, c) case final field?) [field],
    ];
    if (sections.isEmpty) return const SizedBox.shrink();
    return PlanShortcutGuard(
      controller: c,
      child: Material(
        key: const Key('property-panel'),
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, section) in sections.indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                ...section,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 9: The barrel.** In `lib/jet_cad_2d_plan.dart` add, in sorted position, `export 'src/panels/plan_property_panel.dart' show PlanPropertyPanel;` (the layer slot stays internal).

- [ ] **Step 10: Run the new tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/panels/property_panel_test.dart`. Expected: `All tests passed!` (nine tests).

- [ ] **Step 11: Port the panel tests.** Assertions unchanged in every ported test; only the fixture, the pump, the keys, the imports and the subjects named below change. Each file starts with `// Ported from jet_cad_floor_plan/test/<file>; assertions unchanged.` and imports `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`, `../support/panel_kits.dart`, `../support/canvas_fixture.dart`, `../support/design_harness.dart` in place of the `jet_cad_floor_plan` imports.
  1. **`test/panels/selection_panel_test.dart`** from `floor_plan/test/selection_panel_test.dart`: `SE1` (`:142-151`), `SE2` (`:153-167`), `SE3` (`:169-182`), `SE4` (`:184-199`), `SE5` (`:201-208`), `SE6` (`:210-224`), `SE7` (`:226-237`), `SE8` (`:239-265`), `SE9` (`:267-306`), `SE10` (`:308-326`), `WS7 (Box)` (`:625-652`), `SE18` (`:785-814`), `SE17` (`:816-846`), `SE11` (`:909-925`), `SE12` (`:927-940`), `SE14` (`:964-980`), with the helpers they use (`textOf`, `tapKey`, `select`, `pumpBoxes`, `enterAndSubmit`, `canvasFocus`, `typeWidthThenHeight`, `sizeOf`: `:30-41`, `:114-139`, `:875-907`). Adaptations:
     - Finders: `box-width` → `property-width`, `box-height` → `property-height`; `find.byKey(const Key('selection-panel'))` → `find.byKey(const Key('property-panel'))` (the panel's title `Box` is the box kit's `type:box.box` word, as today's `toolBox` word).
     - `pumpDraw(tester, boxDoc(FlutterTextMeasurer()))` → `final c = boxController(); await pumpDesign(tester, c, right: PlanPropertyPanel(controller: c));`; `drawTwoBoxes(tester, view)` → the same four clicks after `press(tester, LogicalKeyboardKey.keyB)` (the box kit's letter), copied from `floor_plan/test/support/box_rig.dart:89-96` with `globalOf(tester, c, …)`; `pumpBoxes` (`:127-132`) likewise; `boxes(view.document)` → `c.document.components.withComponent<BoxParams>().toList()`.
     - `view.selection` → `c.selection`; `view.document` → `c.document`; `select(tester, view, …)` → `select(tester, c, …)`; `sizeOf(view, b)` → `sizeOf(c, b)`.
     - `SE3`: `ParametricSystem(view.document, parametricCatalog).drift()` → `ParametricSystem(c.document, catalogOf([boxKit])).drift()`.
     - `SE5`: `view.document.commands.permissions = DraftPermissions.runtime` stays, on `c.document`.
     - `SE11`, `SE12`: `press(tester, LogicalKeyboardKey.keyW); expect(status(tester), 'Wall');` → `press(tester, LogicalKeyboardKey.keyB); expect(status(tester), 'Box');` (W, the Wall tool's letter, is sub-project 3's; B is the box kit's tool, labelled `Box`). `SE7` keeps its B and its `isNot('Box')`, which now names the box kit's tool.
     - `SE17`: `BoxParams(1e20, height)` is the box kit's `BoxParams`, whose other fields stay at their defaults for a drawn box.
     - `SE18`: `panelNumberText` from `package:jet_cad_2d_plan/src/l10n/panel_number.dart` (Task 9's port).
  2. **`test/panels/colour_row_test.dart`** from `floor_plan/test/colors/color_picker_test.dart`: `CP1` (`:323-391`), `CP3` (`:464-527`), `CP4` (`:529-588`), `CP5` (`:590-603`), `CP6b` (`:605-628`), `CP6` (`:630-637`) and the helpers `swatch`, `picker`, `semanticsOf`, `tooltipOf`, `marked`, `k` (`:45-73`). The subjects change with the kits: today's rooms A and B become two boxes, A at `(7010.25, 3020.5)` in a group turned 0.61 rad (`addBox(…, turn: 0.61)`) and B at `(7400.75, 3120.25)` unturned; the wall `r.w` becomes a plain line (`addDrafted` on layer 0); `RoomParams.color` becomes `BoxParams.colour`. The fixture `roomsPlan()` (`:83-108`) is replaced by `({PlanController c, Handle a, Handle b, Handle line}) boxesPlan()` over `boxController(kits: [boxKit, discKit])`, history cleared; `Rig.pump` (`:110-148`) pumps `MaterialApp(locale:, theme:, supportedLocales: planSupportedLocales, localizationsDelegates: planLocalizationsDelegates, home: Scaffold(body: Row(children: [Expanded(child: PlanCanvas(controller: c)), SizedBox(width: 280, child: SingleChildScrollView(child: PlanPropertyPanel(controller: c)))])))` with the permissions in place of `capabilities`; `paint(doc, room, name)` (`:186-188`) becomes `c.document.commands.execute(SetComponentCommand<BoxParams>(h, box.withColour(name)))`; `recolorCommand(doc, keys, FloorPlanColor.teal)` → `recolourCommand(c, keys, PlanSwatch.teal)`, its children `whereType<SetComponentCommand<BoxParams>>()`; `FloorPlanColor` → `PlanSwatch`; `const FloorPlanStringsEn()` → `const PlanStringsEn()`. Per test:
     - `CP1`: "a separator alone" (`:332-333`) is dropped with the separator (sub-project 3); "While the Wall tool's settings show" (`:335-353`) arms the disc tool instead (`c.selectTool('disc.draw')`, its settings section `settings-disc.draw` in place of `wall-section`), the remaining assertions unchanged; `find.byKey(const Key('layer-picker'))` (`:357`) moves to Task 18 with the picker (this task does not mount it).
     - `CP4`: `FloorPlanEditorCapabilities.full.copyWith(recolor: false)` → `c.permissions = PlanPermissions.full.copyWith(recolor: false)`.
     - `CP6b`: the two rigs pump `ThemeData.light()` and `ThemeData.dark()` over `boxesPlan()` (a White page: the dark theme shows it dark, K1).
  3. **`test/panels/symbol_section_test.dart`** from `floor_plan/test/symbols/symbol_section_test.dart`: `SS1`-`SS8` (`:138-283`), `SS10` (`:302-319`), `SS11` (`:321-343`), `SW1` (`:398-422`, without its table half), `SW2` (`:424-450`), `SW3` (`:452-471`), `SW4` (`:473-498`, without its table half), `SW5` (`:500-517`), `SW8` (`:588-596`), and the helpers `:47-135` (`entry`, `kDeg30`, `rig`, `place`, `transformOf`, `footprint`, `expectNear`, `far`) and `:347-396` (`byKey`, `select`, `typeRotation`, `editable`, `mirrorEnabled`, `menuEnabled`). Adaptations:
     - The catalog (`:32-58`): `FurnitureSymbol` and `PolylineShape` → the kit's authoring `CatalogSymbol`, `CatalogPolyline`, `CatalogLine` (`package:jet_cad_2d_kit/authoring.dart`): `rect(key, w, d, {seats, baseX, family})` gives `CatalogSymbol(key: key, name: 'Test $key', category: 'Tests', tags: tags, family: family, unit: seats == null ? null : CatalogUnit(kind: UnitKinds.table, capacity: seats), base: (baseX ?? w / 2, d / 2), shapes: [CatalogPolyline([(0, 0), (w, 0), (w, d), (0, d)], closed: true), CatalogLine((w * 0.2, d * 0.7), (w * 0.8, d * 0.7))])`; the beds' `family:test-bed` tag becomes `family: 'test-bed'` (tags `['bed']`), the tables' `family:test-tables` becomes `family: 'test-tables'` (tags `['table']`), `against-wall` goes (the attachment is Task 14's). `libraryBytes()` is `encodeLibrary(Catalog(kit: 'test', symbols: catalog))`; `library` is `SymbolLibrary.decode(libraryBytes())`; `entry(key)` reads `e.symbol.key`.
     - `rig()` (`:68-80`) becomes `DraftDocument.empty(measurer: FlutterTextMeasurer())` with `registerKitComponents(doc.components)` and millimetre units (no parametric or table system: a symbol needs neither); `place` uses Task 13's `placeSymbol`.
     - `familyMembers(library, …)` → `familyMembers(library.entries, …)`; `entryOfInstance(library, doc, h)` → `entryOfInstance(library.entries, doc, h)`; `SS8`'s v2 library is built the same way from one `CatalogSymbol` of version 2.
     - The panel group: `pumpPanel` (`:349-363`) becomes `Future<PlanController> pumpPanel(WidgetTester tester, {Completer<Uint8List>? gate})` over `PlanController(kits: [PlanKit(id: 'test', version: '1.0.0', symbols: [SymbolLibrarySource(label: 'test', read: () => gate?.future ?? Future.value(libraryBytes()))])])`, pumping `MaterialApp(home: Scaffold(body: SingleChildScrollView(child: PlanPropertyPanel(controller: c))))` and, without a gate, pumping under `tester.runAsync` until `c.symbolsState.value` is `ready`; instances are placed on `c.document`; `select` drives `c.selection`; `loader(tester, load: false)` and `tester.runAsync(l.load)` (`SW3`) become the gate and `gate.complete(libraryBytes())` followed by the same pumping.
     - `SW4`: `doc.commands.permissions = …` on `c.document`; its table assertions (`:484-487`) and its last table selection go with the 2b rule ("a table turns in the design mode only").
  4. **`test/panels/hover_removal_test.dart`** from `floor_plan/test/hover_removal_test.dart`: `HR1` (`:31-56`). Adaptations: `boxDoc(measurer)` and `pumpDraw` → `final c = boxController(); await pumpDesign(tester, c, right: PlanPropertyPanel(controller: c));`; the line is added on `c.document`; `globalOf(tester, view, …)` → `globalOf(tester, c, …)`; `view.selection.hover` → `c.selection.hover`; `find.byType(PlannerView)` → `find.byType(PlanCanvasView)` (`package:jet_cad_2d_plan/src/canvas/plan_canvas_view.dart`). `HR2` (a hovered table) is 2b's.

- [ ] **Step 12: Run the ported tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/panels`. Expected: `All tests passed!`. A ported test that fails on an assertion is a finding: stop and report it; never change the assertion.

- [ ] **Step 13: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — each exits 0. `git status --short` lists only this task's files.

- [ ] **Step 14: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart packages/jet_cad_2d_plan/lib/src/panels/symbol_section.dart packages/jet_cad_2d_plan/lib/src/panels/colour_row.dart packages/jet_cad_2d_plan/lib/src/panels/frame_safe_relay.dart packages/jet_cad_2d_plan/lib/src/panels/kit_lookup.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/test/support/panel_kits.dart packages/jet_cad_2d_plan/test/panels/property_panel_test.dart packages/jet_cad_2d_plan/test/panels/selection_panel_test.dart packages/jet_cad_2d_plan/test/panels/colour_row_test.dart packages/jet_cad_2d_plan/test/panels/symbol_section_test.dart packages/jet_cad_2d_plan/test/panels/hover_removal_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): PlanPropertyPanel (P2, P3)

The panel shows the active tool's settings, the one selected object's
fields bound by its type, titled by its title word, with its escape
hatch, or the generic symbol section, and the colour row over every
selected object with a colour target. The eight kinds render with
today's field rules: pin on focus, commit on blur or Enter, revert what
is refused, degrees for angles. A locked object shows no section. A
field being edited settles into its plan before a swap.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 15: Mutation check** (on the committed files; after each: run the named test, quote its red line, `git checkout -- <file>`, `git diff --quiet -- <file>` exits 0):
  - M-P-1a `lib/src/panels/plan_property_panel.dart`: in `_parse`, `degrees * math.pi / 180` → `degrees` → P-1 red.
  - M-P-1b `plan_property_panel.dart`: in `_commit`, delete `f.text.text.trim() != shown &&` and in `_write` both `(input != null && input == field.value)` tests → P-1 red (the second Enter is a step).
  - M-P-1c `plan_property_panel.dart`: in `_commit`, delete `_show(f);` → P-1 red (the refused label stays in the field).
  - M-P-2 `plan_property_panel.dart`: delete `if (gate != null && !c.permissions.allows(gate)) return false;` → P-2 red.
  - M-P-3 `plan_property_panel.dart`: in `_editable`'s object case, `!field.enabled ||` deleted → P-3 red.
  - M-P-4 `plan_property_panel.dart`: `type.titleWordOf(doc, t.handle)` → `'type:${t.typeId}'` → P-4 red.
  - M-P-5a `plan_property_panel.dart`: `_onChanged`'s body → `{}` → P-5 red (the disc has 400).
  - M-P-5b `plan_property_panel.dart`: in `_write`'s tool case, `field.commit!(input);` deleted → P-5 red.
  - M-P-6a `plan_property_panel.dart`: in `_objectTarget`, `|| _c.isLocked(h)` deleted → P-6 red; M-P-6b `colour_row.dart`: `if (!c.isLocked(h))` deleted → P-6 red.
  - M-P-7 `plan_property_panel.dart`: the `KitSectionBoundary(…)` becomes `type.sectionFor(context, doc, t.handle, (command) => c.execute(command), KitNamesWords(c.kits.kitOf(kit)!.names, () => c.locale.value)) ?? const SizedBox.shrink()` built inline with the panel's `context` → P-7 red (the builder's `StateError` escapes the build).
  - M-P-two `plan_property_panel.dart`: `c.execute(planTypeOf(c, typeId)!.commitField(c.document, handle, field, input));` → `c.execute(SetComponentCommand<Component>(handle, field.commit!(input)! as Component));` → P-two-types red.
  - M-P-swap `plan_property_panel.dart`: delete `_releaseSettle = c.registerSettle(_settle);` → P-swap-pending red (the old plan keeps 120).
  - M-07p (the ported `WS7 (Box)`'s) `plan_property_panel.dart`: `f.pinned ??= _targetOf(f);` → `f.pinned = null;` and in `_commit`, `final t = f.pinned;` → `final t = _targetOf(f);` → `WS7 (Box)` red.
  - M-F3 (the ported `SE11`'s) `plan_property_panel.dart`: `onTapOutside: (_) => f.focus.handBack(),` → `onTapOutside: (_) => f.focus.unfocus(),` → `SE11` red.
  - M-PC9-a (the ported `CP3`'s) `colour_row.dart`: `return edits.isEmpty ? null : CompoundCommand(edits, label: 'Colour');` → `return CompoundCommand(edits, label: 'Colour');` → `CP3` red (a colour chosen twice is a step).
  - M-PC9-b (the ported `CP4`'s) `colour_row.dart`: delete `if (!c.permissions.recolor) return strings.colorRefused;` → `CP4` red.
  - M-HR1 (the ported `HR1`'s) `plan_property_panel.dart`: `_selection = FrameSafeRelay(_c.selection)..addListener(_sync);` → `_c.selection.addListener(_sync);` (and the matching removal) → `HR1` red.
  - M-09c-x (the ported `SS1`'s) `symbol_section.dart`: `math.atan2(-t.c, t.d)` → `math.atan2(t.b, t.a)` → `SS1` red.
  - M-09c-bi (the ported `SS7`'s) `symbol_section.dart`: delete `e.unit != null ||` → `SS7` red.

#### Assumed from earlier tasks

Each name below is used as written; where the earlier task named it otherwise, the implementer uses that task's name and reports the difference.
- Task 8 (`PlanController`): `DraftDocument get document`; `ParametricCatalog get catalog` (with E1's `typeIdOf`); `SelectionController get selection`; `PageNotifier get page`; `ValueListenable<String> get activeTool`; `ValueListenable<Locale> get locale` with `@internal void reportLocale(Locale)` (the widgets' report, Task 9's `PlanLocaleScope`); `ValueListenable<List<KitDiagnostic>> get diagnostics` and `@internal DiagnosticsLog get diagnosticsLog` (`report`, Task 11's `add`); `KitSet get kits` (`kits`, `kitOf`); `String save()`; `void load(String json)`, which runs every registered settler before it swaps the document and notifies after; `@internal VoidCallback registerSettle(VoidCallback settle)` (the returned callback withdraws it); `@internal` the tool settings store `toolSettings`: a `Listenable` with `Object valueOf(String toolId)` (the stored value, else the tool's `initial`) and `void store(String toolId, Object value)` that notifies; `PlanServices.settingsOf<S>` reads the same store.
- Task 10: `ValueListenable<Set<Handle>> get locked`; `bool isLocked(Handle)`; `void lockBroken(Set<Handle>)`; `PlanLocked` (`lib/src/kits/locks.dart`).
- Tasks 10, 11 (`lib/src/kits/guard.dart`): `bool PlanController.execute(DraftCommand command)` (public, Task 11) — the guarded path, which catches every refusal (`PlanLocked`, `DanglingReferenceError`, `ArgumentError`, `KitHookFailure`), shows the lock hint or reports the diagnostic itself and answers false (the controller's ruling); `ValueNotifier<bool> PlanController.lockHint`; `KitSectionBoundary({required String kitId, required String typeId, required DiagnosticsLog log, required Widget? Function(BuildContext context) builder})` (`lib/src/kits/section_boundary.dart`), which builds `builder`'s widget, shows its small "section failed" box (Task 9's `sectionFailed` word) when `builder` throws and reports `hookFailed` once.
- Task 12: `PlanPermissions` (`rotate`, `mirror`, `reshape`, `recolor`, `allows(PlanGate)`, `copyWith`, `full`); `PlanController.permissions` (get, set).
- Task 13: `List<PlanSymbol> get symbols` (the same list object until the next load of symbols), `ValueListenable<PlanSymbolsState> get symbolsState`; `PlanSymbol.entry`; `placeSymbol(DraftDocument, SymbolEntry, {required Vector2 at, int quarterTurns, bool mirrored, Transform2? transform})`, which attaches the entry's `UnitComponent` to a copied definition.
- Task 14: `lib/src/symbols/symbol_box.dart` with `SymbolBox` (`width`, `depth`, `left`, `right`, `front`, `back`), `boxOfEntry(SymbolEntry)`, `boxOfDefinition(DraftDocument, Handle)`.
- Task 16: the box kit's B and the disc kit's D take their letters through `planToolEntries`.

#### Interface problem

Resolved by controller rulings: 1 by R-i (panel fields use the language's decimal separator, spec P3 corrected; the plan's separator governs drawn values); 2 by R-g (the slot `propertyPanelLayerField`, filled by Task 18, which restores `CP1`'s `layer-picker` assertion); 3 by Task 8's Produces (`@internal ToolSettingsStore get toolSettings` with `valueOf`, `store`, a `ChangeNotifier`) and R-n (the settings are the controller's and survive a swap).

---

