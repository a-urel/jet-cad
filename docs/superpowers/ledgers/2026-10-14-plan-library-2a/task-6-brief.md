### Task 6: The `jet_cad_2d_plan` package, kit-set validation, the test kits and CI (spec P4 "The kit set", "Tests")

#### Test kit API

Every later task imports these from `packages/jet_cad_2d_plan/test/support/`. Names are fixed here; later tasks only **add** to these files (Task 7 adds `planText` to `harness.dart`, Task 8 adds `controllerFor`).

`test/support/test_kit.dart`:
- ids: `const String slabTypeId = 'test.slab'`, `const String slabToolId = 'test.slab'`, `const String discTypeId = 'disc.round'`, `const String readerTypeId = 'test.reader'`, `const String testEdgeKind = 'test-edge'`.
- kits (a fresh descriptor per call, so no state leaks between tests): `PlanKit testKit({String version = '1.2.0', KitLog? log})` (id `test`: type `test.slab`, tool `test.slab` with settings, one `test-edge` provider, words `en` + `tr`, no `de`); `PlanKit discKit({String version = '0.4.0'})` (id `disc`: type `disc.round`, a second component type for the covariance tests); `PlanKit conflictKit()` (id `test`: type `test.reader`, which both contributes and reads places).
- descriptors: `PlanType<SlabComponent> slabType({KitLog? log})`, `PlanTool slabTool({KitLog? log})`, `List<PropertySpec<SlabComponent>> slabProperties()`, `List<PropertySpec<SlabSettings>> slabSettingSpecs()`, `Widget slabSection(BuildContext, SlabComponent, void Function(SlabComponent), KitWords)`, `String slabTitle(SlabComponent)`.
- components: `SlabComponent` (`width`, `height`, `angle`, `thickness`, `finish`, `labelled`, `label`, `flipped`, `swatch`; `copyWith`, `withSwatch`, `fromJson`), `SlabSettings` (`width`, `height`), `DiscComponent` (`radius`, `swatch`), `ReaderComponent` (`size`).
- engine and Flutter-layer parts: `SlabType`, `DiscType`, `ReaderType` (`ParametricType`s), `SlabGrips` (`ObjectGripProvider`, `Disposable`), `SlabTool` (`PlacementTool`: first press anchors, second commits), `SlabCache` (`Disposable`, what the tool and the grips share through `PlanServices.shared`), `TestEdge` (`AttachmentProvider`, `Disposable`; a horizontal edge at world `y`, kind configurable, hysteresis through `keep`, `mayRotate: false` honoured).
- geometry: `List<Vector2> slabCorners(SlabComponent)`, `List<Vector2> discOutline(DiscComponent)`.
- words: `const KitNames testWords`, `const KitNames discWords`.
- lifecycle log: `KitLog` (`events`, `int created(String what)`, `void disposed(String what, int serial)`): products log `tool+N`/`tool-N`, `grips+N`/`grips-N`, `cache+N`/`cache-N`, `edge+N`/`edge-N`.
- placement: `CompoundCommand placeObjectCommand<T extends Component>(DraftDocument d, T component, {required Vector2 at, Handle? handle})`, `Handle addObject<T extends Component>(DraftDocument d, T component, {required Vector2 at})`. **`T` must be the concrete component type** (pass a value whose static type is `SlabComponent`, not `Component`): `SetComponentCommand<T>` stores by `T`.

`test/support/throwing_kit.dart`:
- `const Set<String> boomHooks` (every hook name below), `final class BoomFailure implements Exception` (`hook`).
- `final class ThrowingKit` — `ThrowingKit({Iterable<String> failing = const []})` (an unknown hook name is an `ArgumentError`); `final Set<String> failing` (mutable: a test switches hooks on after a load); `void failAll()`; `void check(String hook)` (throws `BoomFailure(hook)` when `failing` holds it); `late final PlanKit kit` (id `boom`, version `0.3.0`).
- its types: `boom.block` (`BlockComponent`; grips, two properties, a section, a title, a colour target), `boom.post` (`PostComponent`; contributes places), `boom.zone` (`ZoneComponent`; reads places); its tool `boom.tool` (`BoomTool`); its provider kind `boom-edge` (`BoomEdge extends TestEdge`, edge at `y = -2000`). `BoomComponent` is their sealed base (`size`, `swatch`, `refs`); `BoomType<T>`, `BoomGrips`, `BoomSection` (a widget whose build calls `check('sectionWidget')`).
- hook names: `reach`, `references`, `pageKey`, `placeBox`, `placeInput`, `readBox`, `dissolves`, `generate`, `diagnose` (the `ParametricType`), `fromJson`, `gripsCreate`, `gripsOf`, `gripsDrag`, `gripsPreview`, `gripsMovable`, `toolCreate`, `toolDown`, `toolMove`, `toolUp`, `toolExit`, `toolKey`, `toolCancel`, `toolPaint`, `attachCreate`, `attach`, `read`, `write`, `apply`, `section`, `sectionWidget`, `colourRead`, `colourWrite`, `title`.

`test/support/harness.dart`:
- `ParametricCatalog catalogOf(List<PlanKit> kits)` (every type's `registerInto`, load order, no guard);
- `void registerPlanComponents(ComponentRegistry registry, ParametricCatalog catalog)` (the page, `registerKitComponents`, the catalog's);
- `DraftDocument planDocument(List<PlanKit> kits, {TextMeasurer measurer = const InsertionPointMeasurer(), DecimalSeparator separator = DecimalSeparator.point})` (a new plan's document: millimetres, the default page at (-7425, -5250), no history);
- `ParametricSystem installSystem(DraftDocument d, List<PlanKit> kits)` (installed, disposed at tear-down);
- `Handle addLine(DraftDocument d, Vector2 a, Vector2 b)`, `List<Handle> leavesOf(DraftDocument d, Handle owner)`, `Float64List coordsOf(DraftDocument d, Handle leaf)`;
- `ToolPointerEvent pointerAt(Vector2 world, {int buttons = kPrimaryButton, Offset screen = Offset.zero, double pickRadiusWorld = 1})`;
- `Future<void> pumpApp(WidgetTester tester, Widget child, {Size size = const Size(1440, 900)})` (no later task changes it: the widget tasks pump their own hosts with `planLocalizationsDelegates`, Task 9).

#### Contract signatures this task assumes (Tasks 3 and 4)

The shared interfaces name the property kinds and the attachment value types but not their constructors. The code below assumes named parameters spelled as spec P3 spells the fields. **If Tasks 3-4 landed other spellings, adapt only the constructor calls in `test_kit.dart` and `throwing_kit.dart`; never the kits' behaviour.**
- `LengthProperty<T>({required String id, required double Function(T) read, required T Function(T, double) write, double? min, double? max, bool Function(T)? enabled, PlanGate? gate})`; `AngleProperty<T>` the same without `min`/`max` (radians); `NumberProperty<T>` the same plus `int decimals`; `ChoiceProperty<T, V>({required String id, required List<V> values, required V Function(T) read, required T Function(T, V) write, ...})`; `ToggleProperty<T>` over `bool`; `TextProperty<T>` over `String` plus `int? maxLength`; `ValueDisplay<T>({required String id, required double Function(T) read, required ValueUnit unit, ...})`; `ActionProperty<T>({required String id, required T Function(T) apply, ...})`.
- `Attachment({required Transform2 transform, required Vector2 marker, required Object token})`; `AttachmentQuery` read through its fields `footprint`, `current`, `pointer`, `capture`, `edgeCapture`, `mirrored`, `mayRotate`, `exclude`, `keep`.
- `PlanType` exposes public `fromJson`, `parametric`, `grips` and `properties` (confirmed by Task 4); `validateKitSet` reads `type.parametric.contributesPlace` and `readsPlaces`, which are not `T`-typed. `AttachmentQuery` requires `mirrored` and `mayRotate`; angles in a `PropertyField` are radians.
- `PlanKit.validate()` (Task 4) reports a duplicate type or tool id **within** one kit as `duplicateType` / `duplicateTool`. `validateKitSet` reports only duplicates **across** kits, so nothing is reported twice.
- `Disposable` (`abstract interface class Disposable { void dispose(); }`) is Task 4's, in `jet_cad_2d_kit`'s `plan_services.dart`; this task's kits implement it.

**Files:**
- Create: `packages/jet_cad_2d_plan/pubspec.yaml`, `packages/jet_cad_2d_plan/analysis_options.yaml`, `packages/jet_cad_2d_plan/LICENSE`, `packages/jet_cad_2d_plan/README.md`, `packages/jet_cad_2d_plan/CHANGELOG.md`
- Create: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart`, `packages/jet_cad_2d_plan/lib/src/kits/kit_set.dart`
- Create: `packages/jet_cad_2d_plan/test/support/test_kit.dart`, `packages/jet_cad_2d_plan/test/support/throwing_kit.dart`, `packages/jet_cad_2d_plan/test/support/harness.dart`
- Test: `packages/jet_cad_2d_plan/test/kits/kit_set_test.dart`, `packages/jet_cad_2d_plan/test/kits/test_kits_test.dart`
- Modify: `pubspec.yaml` (root, the `workspace:` list), `.github/workflows/ci.yml` (the `package` matrix and the `publishable` matrix)

**Interfaces:**
- Consumes (contract, Tasks 3-4, exactly as the plan's Shared interfaces): `PlanKit` (`id`, `version`, `types`, `tools`, `attachments`, `names`, `validate()`), `PlanType`, `PlanTool`, `PlanToolSettings`, `PropertySpec` and its eight kinds, `PlanGate`, `ValueUnit`, `ColourTarget`, `KitWords`, `PlanServices`, `AttachmentProvider`, `AttachmentQuery`, `Attachment`, `KitProblem`, `KitProblemCode` (with `duplicateKit`, `duplicateType`, `duplicateTool`, `reservedKitId`, `typeOutsideKit`, `toolOutsideKit`, `typePlaceConflict`), `KitNames`, `registerKitComponents`, `Disposable` (Task 4). Engine: `ParametricCatalog`, `ParametricSystem(document, catalog)` (E2's `isFrozen` is optional and not used here), `ParametricType`. Flutter layer: `PlacementTool`, `Tool`, `ToolContext`, `ToolPointerEvent`, `ObjectGripProvider`, `Grip`.
- Produces (exported from `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`):
  - `final class KitSet` — `List<PlanKit> get kits` (load order), `PlanKit? kitOf(String id)`, plus `List<PlanType<Component>> get types` and `List<PlanTool> get tools` (kit by kit in load order) and `PlanType<Component>? typeOf(String typeId)`.
  - `KitSet validateKitSet(List<PlanKit> kits)` — throws `KitSetError` listing every problem.
  - `final class KitSetError extends ArgumentError` — `List<KitProblem> problems`; `name == 'kits'`; `message` has one line `  <code>: <message>` per problem.
  - `const Set<String> reservedKitIds = {'plan', 'jetcad'}`.
  - The package itself, resolvable in the workspace, in CI's `package` and `publishable` matrices.
  - The test kit API above.

Plan decision: `validateKitSet` reports, per kit in load order: a reserved id, a duplicate kit id (at the later kit), the kit's own `validate()` problems (each message prefixed `<kit id>: `), then per type a type id another kit already gave (`duplicateType`) and a place conflict (`typePlaceConflict`), then per tool a tool id another kit already gave (`duplicateTool`). A duplicate inside one kit is `validate()`'s, so it is reported once. A type id repeated by a kit with a duplicate kit id is covered by `duplicateKit` and is not reported again.
Plan decision: the conflict is read from the descriptor (`type.parametric.contributesPlace && type.parametric.readsPlaces`), the same flags `ParametricCatalog.register` refuses (`parametric_system.dart:497-505`), so the set is refused before any catalog exists.
Plan decision: the publishable dry run joins CI in this task, as `jet_cad_2d_kit`'s did in sub-project 1's Task 11: a later task that breaks it is red on that task's push.

- [ ] **Step 1: The pubspec.** Create `packages/jet_cad_2d_plan/pubspec.yaml`:

```yaml
name: jet_cad_2d_plan
description: >-
  The plan library for jet_cad_2d: a plan controller and composable
  design-mode widgets over kits that contribute types, tools and symbols.
version: 0.8.0
repository: https://github.com/a-urel/jet-cad
issue_tracker: https://github.com/a-urel/jet-cad/issues
funding:
  - https://github.com/sponsors/a-urel
  - https://buymeacoffee.com/yazemo
topics:
  - cad
  - floor-plan
  - editor
resolution: workspace

environment:
  sdk: ^3.6.0
  flutter: ">=3.44.0"

dependencies:
  flutter:
    sdk: flutter
  jet_cad_2d: ^0.7.2
  jet_cad_2d_flutter: ^0.7.2
  jet_cad_2d_kit: ^0.1.0
  meta: ^1.18.0
  vector_math: ^2.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  lints: ^6.1.0
```

  (Later tasks add what their ported code uses, with `jet_cad_floor_plan`'s constraints: `flutter_localizations` in Task 9, `pdf` and `printing` in Task 19, `vm_service` as a dev dependency if Task 15's invariant needs it.)

- [ ] **Step 2: The analysis options**, a copy of `jet_cad_2d_kit`'s (itself `jet_cad_2d_flutter`'s strict set without the platform folders). Create `packages/jet_cad_2d_plan/analysis_options.yaml`:

```yaml
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    unused_import: error
    unused_local_variable: error
  exclude:
    - build/**

linter:
  rules:
    - always_declare_return_types
    - avoid_dynamic_calls
    - prefer_final_locals
    - unawaited_futures
```

  This file is committed **once**, here, by explicit path (Global Constraints). No later task stages it.

- [ ] **Step 3: Licence, README, CHANGELOG.** From the worktree root: `cp LICENSE packages/jet_cad_2d_plan/LICENSE`, then `cmp LICENSE packages/jet_cad_2d_plan/LICENSE` (no output). Create `packages/jet_cad_2d_plan/README.md` (Task 20 completes it):

```markdown
# jet_cad_2d_plan

The plan library of jet_cad_2d: a `PlanController` that owns one plan, and
the composable widgets of design mode, over the kits a host loads. Work in
progress: see `docs/kits.md` in the repository.
```

  Create `packages/jet_cad_2d_plan/CHANGELOG.md` (Task 20 writes the full notes):

```markdown
## 0.8.0 (unreleased)

- The plan library: kit-set validation. Later entries of this branch add
  the plan file, `PlanController` and the design-mode widgets.
```

- [ ] **Step 4: The barrel.** Create `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart`:

```dart
/// The plan library of jet_cad_2d: a `PlanController` over one plan and the
/// composable widgets of design mode, over the kits a host loads.
library;

export 'src/kits/kit_set.dart';
```

- [ ] **Step 5: The workspace entry.** In the root `pubspec.yaml`, add `  - packages/jet_cad_2d_plan` to the `workspace:` list directly after `  - packages/jet_cad_2d_kit`. From the worktree root run `flutter pub get`; expected: it resolves (`Got dependencies!` or `Changed N dependencies!`). Then `git status --short`; expected: ` M pubspec.yaml`, `?? packages/jet_cad_2d_plan/`, the untracked plan file if it is still untracked, and possibly rewritten `analysis_options.yaml` files of other packages — **leave those unstaged**.

- [ ] **Step 6: The test kits and the harness.** Create `packages/jet_cad_2d_plan/test/support/test_kit.dart`:

```dart
// The test kit of the plan library (spec 2a "Tests"): one parametric type,
// `test.slab`, with all eight property kinds, a gate, a title hook, a
// colour target, grips and an escape-hatch section; one tool with
// settings; a `test-edge` attachment provider; English and Turkish words,
// no German (the fallback). `discKit` gives a second kit whose type has
// another component type (the covariance tests); `conflictKit` a type that
// both contributes and reads places (the kit-set refusal).
//
// Fixtures sit off the origin, turned, with non-default attributes
// (CLAUDE.md): a slab's outline is turned by its own `angle` inside a group
// placed by translation.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

const String slabTypeId = 'test.slab';
const String slabToolId = 'test.slab';
const String discTypeId = 'disc.round';
const String readerTypeId = 'test.reader';
const String testEdgeKind = 'test-edge';

/// What the kits' factories made and disposed, in order: `tool+1`,
/// `cache+1`, `grips+1`, ..., `tool-1`. A serial per kind of product.
final class KitLog {
  final List<String> events = [];
  final Map<String, int> _serials = {};

  /// Logs `<what>+<n>` and returns `n`, this product's serial.
  int created(String what) {
    final n = (_serials[what] ?? 0) + 1;
    _serials[what] = n;
    events.add('$what+$n');
    return n;
  }

  void disposed(String what, int serial) => events.add('$what-$serial');
}

// ---------------------------------------------------------------------------
// The slab.

/// A rectangle [width] x [height] (mm) centred on its group's origin and
/// turned by [angle] (radians), with the attributes the eight property
/// kinds edit.
@immutable
final class SlabComponent implements Component {
  SlabComponent({
    required this.width,
    required this.height,
    this.angle = 0,
    this.thickness = 120,
    this.finish = 'plain',
    this.labelled = false,
    this.label = '',
    this.flipped = false,
    this.swatch,
  }) {
    if (!width.isFinite || width <= 0) {
      throw ArgumentError.value(width, 'width', 'must be finite and above 0');
    }
    if (!height.isFinite || height <= 0) {
      throw ArgumentError.value(height, 'height', 'must be finite and above 0');
    }
    if (!angle.isFinite) {
      throw ArgumentError.value(angle, 'angle', 'must be finite');
    }
  }

  static const String componentTypeId = slabTypeId;

  final double width;
  final double height;
  final double angle;
  final double thickness;
  final String finish;
  final bool labelled;
  final String label;
  final bool flipped;
  final String? swatch;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'angle': angle,
        'finish': finish,
        'flipped': flipped,
        'height': height,
        'label': label,
        'labelled': labelled,
        'swatch': swatch,
        'thickness': thickness,
        'width': width,
      };

  static SlabComponent fromJson(Map<String, Object?> json) => SlabComponent(
        width: (json['width']! as num).toDouble(),
        height: (json['height']! as num).toDouble(),
        angle: ((json['angle'] as num?) ?? 0).toDouble(),
        thickness: ((json['thickness'] as num?) ?? 120).toDouble(),
        finish: json['finish'] as String? ?? 'plain',
        labelled: json['labelled'] as bool? ?? false,
        label: json['label'] as String? ?? '',
        flipped: json['flipped'] as bool? ?? false,
        swatch: json['swatch'] as String?,
      );

  SlabComponent copyWith({
    double? width,
    double? height,
    double? angle,
    double? thickness,
    String? finish,
    bool? labelled,
    String? label,
    bool? flipped,
  }) =>
      SlabComponent(
        width: width ?? this.width,
        height: height ?? this.height,
        angle: angle ?? this.angle,
        thickness: thickness ?? this.thickness,
        finish: finish ?? this.finish,
        labelled: labelled ?? this.labelled,
        label: label ?? this.label,
        flipped: flipped ?? this.flipped,
        swatch: swatch,
      );

  /// This slab in the plan's swatch [swatch] (null: none).
  SlabComponent withSwatch(String? swatch) => SlabComponent(
        width: width,
        height: height,
        angle: angle,
        thickness: thickness,
        finish: finish,
        labelled: labelled,
        label: label,
        flipped: flipped,
        swatch: swatch,
      );

  @override
  bool operator ==(Object other) =>
      other is SlabComponent &&
      other.width == width &&
      other.height == height &&
      other.angle == angle &&
      other.thickness == thickness &&
      other.finish == finish &&
      other.labelled == labelled &&
      other.label == label &&
      other.flipped == flipped &&
      other.swatch == swatch;

  @override
  int get hashCode => Object.hash(width, height, angle, thickness, finish,
      labelled, label, flipped, swatch);

  @override
  String toString() => 'SlabComponent($width x $height @ $angle)';
}

/// The slab's corners in its group's space, counter-clockwise.
List<Vector2> slabCorners(SlabComponent s) {
  final c = math.cos(s.angle), n = math.sin(s.angle);
  final hw = s.width / 2, hh = s.height / 2;
  return [
    for (final (x, y) in [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)])
      Vector2(x * c - y * n, x * n + y * c),
  ];
}

/// The slab's engine type: its outline, one closed polyline.
final class SlabType extends ParametricType<SlabComponent> {
  const SlabType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(SlabComponent params, Transform2 toWorld) => Aabb2.fromPoints(
      [for (final c in slabCorners(params)) toWorld.transformPoint(c)]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<SlabComponent>(self)!;
    return [
      Generated(
          EntityKind.polyline, polylinePayload(slabCorners(p), closed: true)),
    ];
  }
}

/// What the slab tool and the slab grips share, through
/// `PlanServices.shared`: one per document.
final class SlabCache implements Disposable {
  SlabCache({this.log}) : serial = log?.created('cache') ?? 0;

  final KitLog? log;
  final int serial;
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    log?.disposed('cache', serial);
  }
}

/// One stretch grip, at the middle of the slab's right edge; dragging it
/// sets the width to twice the drop's distance along the slab's axis.
final class SlabGrips implements ObjectGripProvider, Disposable {
  SlabGrips(this.cache, {this.log}) : serial = log?.created('grips') ?? 0;

  final SlabCache cache;
  final KitLog? log;
  final int serial;

  static Transform2? _toWorld(DraftDocument d, Handle group) {
    final node = d.tree[group];
    return node is GroupNode ? node.transform : null;
  }

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    final s = d.components.get<SlabComponent>(group);
    final t = _toWorld(d, group);
    if (s == null || t == null) return const [];
    final p = t.transformPoint(Vector2(math.cos(s.angle) * s.width / 2,
        math.sin(s.angle) * s.width / 2));
    return [Grip(GripRole.stretch, 0, p.x, p.y)];
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    final s = d.components.get<SlabComponent>(group);
    final t = _toWorld(d, group);
    if (s == null || t == null) return null;
    final local = t.invert().transformPoint(world);
    final width =
        2 * (local.x * math.cos(s.angle) + local.y * math.sin(s.angle));
    if (width <= Tolerance.standard.linear) return null;
    return SetComponentCommand<SlabComponent>(group, s.copyWith(width: width));
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    final command = drag(d, group, grip, world);
    if (command is! SetComponentCommand<SlabComponent>) return const [];
    final t = _toWorld(d, group)!;
    return [
      (
        EntityKind.polyline,
        polylinePayload(
            [for (final c in slabCorners(command.value!)) t.transformPoint(c)],
            closed: true)
      ),
    ];
  }

  @override
  bool movable(DraftDocument d, Handle group) => true;

  @override
  void dispose() => log?.disposed('grips', serial);
}

/// The slab tool's settings: the size of the next slab, in mm.
@immutable
final class SlabSettings {
  const SlabSettings({required this.width, required this.height});

  final double width;
  final double height;

  SlabSettings copyWith({double? width, double? height}) =>
      SlabSettings(width: width ?? this.width, height: height ?? this.height);

  @override
  bool operator ==(Object other) =>
      other is SlabSettings && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// Two presses: the first anchors the slab's centre, the second turns it
/// towards the press and commits a slab of the tool's settings' size.
final class SlabTool extends PlacementTool {
  SlabTool(this.services, {this.log})
      : cache = services.shared<SlabCache>((_) => SlabCache(log: log)),
        serial = log?.created('tool') ?? 0;

  final PlanServices services;
  final KitLog? log;
  final SlabCache cache;
  final int serial;

  @override
  String get name => 'Slab';

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    final start = points.first;
    final d = point - start;
    if (d.length <= Tolerance.standard.linear) return;
    final size = services.settingsOf<SlabSettings>(slabToolId);
    commit(
        ctx,
        () => placeObjectCommand<SlabComponent>(
            ctx.document,
            SlabComponent(
                width: size.width,
                height: size.height,
                angle: math.atan2(d.y, d.x)),
            at: start),
        needs: const {
          Capability.structure,
          Capability.components,
          Capability.geometry,
        });
    clearShape();
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {}

  @override
  void dispose() {
    log?.disposed('tool', serial);
    super.dispose();
  }
}

/// The slab's eight property kinds: two lengths, an angle gated by
/// `rotate`, a number, a choice, a toggle, a text enabled only while
/// labelled, the area shown, and a flip.
List<PropertySpec<SlabComponent>> slabProperties() => [
      LengthProperty<SlabComponent>(
          id: 'width',
          read: (s) => s.width,
          write: (s, v) => s.copyWith(width: v),
          min: 100,
          max: 20000),
      LengthProperty<SlabComponent>(
          id: 'height',
          read: (s) => s.height,
          write: (s, v) => s.copyWith(height: v),
          min: 100,
          max: 20000),
      AngleProperty<SlabComponent>(
          id: 'angle',
          read: (s) => s.angle,
          write: (s, v) => s.copyWith(angle: v),
          gate: PlanGate.rotate),
      NumberProperty<SlabComponent>(
          id: 'thickness',
          read: (s) => s.thickness,
          write: (s, v) => s.copyWith(thickness: v),
          min: 1,
          max: 500,
          decimals: 1),
      ChoiceProperty<SlabComponent, String>(
          id: 'finish',
          values: const ['plain', 'tiled', 'polished'],
          read: (s) => s.finish,
          write: (s, v) => s.copyWith(finish: v)),
      ToggleProperty<SlabComponent>(
          id: 'labelled',
          read: (s) => s.labelled,
          write: (s, v) => s.copyWith(labelled: v)),
      TextProperty<SlabComponent>(
          id: 'label',
          read: (s) => s.label,
          write: (s, v) => s.copyWith(label: v),
          maxLength: 24,
          enabled: (s) => s.labelled),
      ValueDisplay<SlabComponent>(
          id: 'area', read: (s) => s.width * s.height, unit: ValueUnit.area),
      ActionProperty<SlabComponent>(
          id: 'flip', apply: (s) => s.copyWith(flipped: !s.flipped)),
    ];

/// The slab tool's settings' specs; their words are the slab's own
/// (`property:test.slab.width`, `property:test.slab.height`).
List<PropertySpec<SlabSettings>> slabSettingSpecs() => [
      LengthProperty<SlabSettings>(
          id: 'width',
          read: (s) => s.width,
          write: (s, v) => s.copyWith(width: v),
          min: 100,
          max: 20000),
      LengthProperty<SlabSettings>(
          id: 'height',
          read: (s) => s.height,
          write: (s, v) => s.copyWith(height: v),
          min: 100,
          max: 20000),
    ];

/// The escape hatch: one button that widens the slab by 250 mm.
Widget slabSection(BuildContext context, SlabComponent value,
        void Function(SlabComponent) commit, KitWords words) =>
    TextButton(
        key: const Key('test-slab-widen'),
        onPressed: () => commit(value.copyWith(width: value.width + 250)),
        child: Text(words.word('property:test.slab.widen')));

/// A flipped slab's section is titled by another word.
String slabTitle(SlabComponent s) =>
    s.flipped ? 'type:test.slab.flipped' : 'type:test.slab';

PlanType<SlabComponent> slabType({KitLog? log}) => PlanType<SlabComponent>(
      id: slabTypeId,
      fromJson: SlabComponent.fromJson,
      parametric: const SlabType(),
      grips: (services) => SlabGrips(
          services.shared<SlabCache>((_) => SlabCache(log: log)),
          log: log),
      properties: slabProperties(),
      section: slabSection,
      title: slabTitle,
      colour: ColourTarget<SlabComponent>(
          read: (s) => s.swatch, write: (s, swatch) => s.withSwatch(swatch)),
    );

PlanTool slabTool({KitLog? log}) => PlanTool(
      id: slabToolId,
      icon: Icons.crop_square,
      letter: 'S',
      needs: const {
        Capability.structure,
        Capability.components,
        Capability.geometry,
      },
      settings: PlanToolSettings<SlabSettings>(
          initial: const SlabSettings(width: 1200, height: 600),
          specs: slabSettingSpecs()),
      create: (services) => SlabTool(services, log: log),
    );

// ---------------------------------------------------------------------------
// The test edge.

/// A horizontal edge at world [y], of kind [kind]: a symbol whose pointer
/// comes within `capture` of it (within `edgeCapture` while it is already
/// attached here, `keep`) sits unturned with its local `minY` on the edge,
/// mirrored when asked. With `mayRotate` false it attaches only a symbol
/// whose turn already fits (unturned, or the plain mirror).
class TestEdge implements AttachmentProvider, Disposable {
  TestEdge({this.kind = testEdgeKind, this.y = 3000, this.log})
      : serial = log?.created('edge') ?? 0;

  @override
  final String kind;
  final double y;
  final KitLog? log;
  final int serial;

  @override
  Attachment? attach(AttachmentQuery query) {
    final kept = identical(query.keep?.token, this);
    final reach = kept ? query.edgeCapture : query.capture;
    if ((query.pointer.y - y).abs() > reach) return null;
    final x = query.mirrored ? -1.0 : 1.0;
    if (!query.mayRotate) {
      final t = query.current;
      const tol = Tolerance.standard;
      if ((t.a - x).abs() > tol.angular || t.b.abs() > tol.angular) {
        return null;
      }
    }
    return Attachment(
        transform: Transform2(x, 0, 0, 1, query.pointer.x, y - query.footprint.minY),
        marker: Vector2(query.pointer.x, y),
        token: this);
  }

  @override
  void dispose() => log?.disposed('edge', serial);
}

// ---------------------------------------------------------------------------
// The test kit's words.

const KitNames testWords = KitNames({
  'en': {
    'type:test.slab': 'Slab',
    'type:test.slab.flipped': 'Flipped slab',
    'tool:test.slab': 'Slab',
    'property:test.slab.width': 'Width',
    'property:test.slab.height': 'Height',
    'property:test.slab.angle': 'Angle',
    'property:test.slab.thickness': 'Thickness',
    'property:test.slab.finish': 'Finish',
    'property:test.slab.finish.plain': 'Plain',
    'property:test.slab.finish.tiled': 'Tiled',
    'property:test.slab.finish.polished': 'Polished',
    'property:test.slab.labelled': 'Labelled',
    'property:test.slab.label': 'Label',
    'property:test.slab.area': 'Area',
    'property:test.slab.flip': 'Flip',
    'property:test.slab.widen': 'Widen',
  },
  'tr': {
    'type:test.slab': 'Döşeme',
    'type:test.slab.flipped': 'Ters döşeme',
    'tool:test.slab': 'Döşeme',
    'property:test.slab.width': 'Genişlik',
    'property:test.slab.height': 'Yükseklik',
    'property:test.slab.angle': 'Açı',
    'property:test.slab.thickness': 'Kalınlık',
    'property:test.slab.finish': 'Kaplama',
    'property:test.slab.finish.plain': 'Düz',
    'property:test.slab.finish.tiled': 'Fayanslı',
    'property:test.slab.finish.polished': 'Cilalı',
    'property:test.slab.labelled': 'Etiketli',
    'property:test.slab.label': 'Etiket',
    'property:test.slab.area': 'Alan',
    'property:test.slab.flip': 'Çevir',
    'property:test.slab.widen': 'Genişlet',
  },
});

/// The test kit: one type, one tool, one provider; a fresh descriptor per
/// call. [log] records its factories' products.
PlanKit testKit({String version = '1.2.0', KitLog? log}) => PlanKit(
      id: 'test',
      version: version,
      types: [slabType(log: log)],
      tools: [slabTool(log: log)],
      attachments: [(services) => TestEdge(log: log)],
      names: testWords,
    );

// ---------------------------------------------------------------------------
// The disc kit: another component type, for the covariance tests.

@immutable
final class DiscComponent implements Component {
  DiscComponent({required this.radius, this.swatch}) {
    if (!radius.isFinite || radius <= 0) {
      throw ArgumentError.value(radius, 'radius', 'must be finite and above 0');
    }
  }

  static const String componentTypeId = discTypeId;

  final double radius;
  final String? swatch;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'radius': radius, 'swatch': swatch};

  static DiscComponent fromJson(Map<String, Object?> json) => DiscComponent(
      radius: (json['radius']! as num).toDouble(),
      swatch: json['swatch'] as String?);

  DiscComponent copyWith({double? radius}) =>
      DiscComponent(radius: radius ?? this.radius, swatch: swatch);

  DiscComponent withSwatch(String? swatch) =>
      DiscComponent(radius: radius, swatch: swatch);

  @override
  bool operator ==(Object other) =>
      other is DiscComponent && other.radius == radius && other.swatch == swatch;

  @override
  int get hashCode => Object.hash(radius, swatch);
}

/// A 24-gon of the disc's radius, centred on its group's origin.
List<Vector2> discOutline(DiscComponent d) => [
      for (var i = 0; i < 24; i++)
        Vector2(d.radius * math.cos(i * math.pi / 12),
            d.radius * math.sin(i * math.pi / 12)),
    ];

final class DiscType extends ParametricType<DiscComponent> {
  const DiscType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(DiscComponent params, Transform2 toWorld) => Aabb2.fromPoints(
      [for (final p in discOutline(params)) toWorld.transformPoint(p)]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<DiscComponent>(self)!;
    return [
      Generated(
          EntityKind.polyline, polylinePayload(discOutline(p), closed: true)),
    ];
  }
}

const KitNames discWords = KitNames({
  'en': {
    'type:disc.round': 'Round disc',
    'property:disc.round.radius': 'Radius',
  },
});

PlanKit discKit({String version = '0.4.0'}) => PlanKit(
      id: 'disc',
      version: version,
      types: [
        PlanType<DiscComponent>(
          id: discTypeId,
          fromJson: DiscComponent.fromJson,
          parametric: const DiscType(),
          properties: [
            LengthProperty<DiscComponent>(
                id: 'radius',
                read: (d) => d.radius,
                write: (d, v) => d.copyWith(radius: v),
                min: 50,
                max: 10000),
          ],
          colour: ColourTarget<DiscComponent>(
              read: (d) => d.swatch, write: (d, swatch) => d.withSwatch(swatch)),
        ),
      ],
      names: discWords,
    );

// ---------------------------------------------------------------------------
// The conflict kit: a type the engine refuses (spec 10 D16).

@immutable
final class ReaderComponent implements Component {
  const ReaderComponent(this.size);

  static const String componentTypeId = readerTypeId;

  final double size;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'size': size};

  static ReaderComponent fromJson(Map<String, Object?> json) =>
      ReaderComponent((json['size']! as num).toDouble());

  @override
  bool operator ==(Object other) =>
      other is ReaderComponent && other.size == size;

  @override
  int get hashCode => size.hashCode;
}

/// Both contributes places and reads them: `ParametricCatalog.register`
/// throws for it (`parametric_system.dart:497-505`).
final class ReaderType extends ParametricType<ReaderComponent> {
  const ReaderType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  bool get contributesPlace => true;

  @override
  bool get readsPlaces => true;

  @override
  Aabb2 reach(ReaderComponent params, Transform2 toWorld) => Aabb2.fromPoints([
        toWorld.transformPoint(Vector2(0, 0)),
        toWorld.transformPoint(Vector2(params.size, params.size)),
      ]);

  @override
  List<Generated> generate(ParametricView view, Handle self) => const [];
}

PlanKit conflictKit() => PlanKit(
      id: 'test',
      version: '1.0.0',
      types: [
        PlanType<ReaderComponent>(
            id: readerTypeId,
            fromJson: ReaderComponent.fromJson,
            parametric: const ReaderType()),
      ],
      names: const KitNames({
        'en': {'type:test.reader': 'Reader'},
      }),
    );

// ---------------------------------------------------------------------------
// Placing objects.

/// A root-level group at [at] carrying [component] and the drawing layer:
/// one undo step. [T] must be the component's concrete type: the store is
/// chosen by it.
CompoundCommand placeObjectCommand<T extends Component>(
    DraftDocument d, T component,
    {required Vector2 at, Handle? handle}) {
  final h = handle ?? d.handleSeed.next();
  return CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h,
        parent: d.rootHandle,
        transform: Transform2.translation(at.x, at.y),
        children: const [])),
    SetComponentCommand<T>(h, component),
    SetComponentCommand<ObjectLayer>(h, ObjectLayer(drawingLayer(d))),
  ], label: 'Add ${component.typeId}');
}

/// [placeObjectCommand], executed; the new object's handle.
Handle addObject<T extends Component>(DraftDocument d, T component,
    {required Vector2 at}) {
  final h = d.handleSeed.next();
  d.commands.execute(placeObjectCommand<T>(d, component, at: at, handle: h));
  return h;
}
```

  Create `packages/jet_cad_2d_plan/test/support/throwing_kit.dart`:

```dart
// The throwing kit (spec 2a "Tests"): every hook of a kit can be switched
// to throw, one at a time or all together, by its name in `failing`. Task
// 11's guard is proven against it: each hook has a test and a named mutant
// (that hook's guard removed). Three types, so every engine hook is
// reachable: `boom.block` (grips, properties, section, title, colour),
// `boom.post` (contributes places) and `boom.zone` (reads them).
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'test_kit.dart';

/// Every hook the throwing kit can fail.
const Set<String> boomHooks = {
  // The engine's ParametricType.
  'reach', 'references', 'pageKey', 'placeBox', 'placeInput', 'readBox',
  'dissolves', 'generate', 'diagnose',
  // The component's factory.
  'fromJson',
  // The grip provider: its factory, then each call.
  'gripsCreate', 'gripsOf', 'gripsDrag', 'gripsPreview', 'gripsMovable',
  // The tool: its factory, its events, its painting.
  'toolCreate', 'toolDown', 'toolMove', 'toolUp', 'toolExit', 'toolKey',
  'toolCancel', 'toolPaint',
  // The attachment provider: its factory, then attach.
  'attachCreate', 'attach',
  // Properties, the section (its builder, then the widget it returns), the
  // colour target and the title.
  'read', 'write', 'apply', 'section', 'sectionWidget', 'colourRead',
  'colourWrite', 'title',
};

/// What a failing hook throws: not an `Error`, as a kit's own exception
/// would not be.
final class BoomFailure implements Exception {
  const BoomFailure(this.hook);

  final String hook;

  @override
  String toString() => 'BoomFailure($hook)';
}

final class ThrowingKit {
  /// [failing] names hooks of [boomHooks]; any other name is an
  /// [ArgumentError].
  ThrowingKit({Iterable<String> failing = const []}) : failing = {} {
    for (final hook in failing) {
      if (!boomHooks.contains(hook)) {
        throw ArgumentError.value(hook, 'failing', 'is no hook of the kit');
      }
      this.failing.add(hook);
    }
  }

  /// The hooks that throw now. Mutable: a test switches a hook on after a
  /// load, so the load itself runs clean.
  final Set<String> failing;

  void failAll() => failing.addAll(boomHooks);

  void check(String hook) {
    if (failing.contains(hook)) throw BoomFailure(hook);
  }

  late final PlanKit kit = PlanKit(
    id: 'boom',
    version: '0.3.0',
    types: [
      PlanType<BlockComponent>(
        id: BlockComponent.componentTypeId,
        fromJson: (json) {
          check('fromJson');
          return BlockComponent.fromJson(json);
        },
        parametric: BoomType<BlockComponent>(this),
        grips: (services) {
          check('gripsCreate');
          return BoomGrips(this);
        },
        properties: [
          NumberProperty<BlockComponent>(
              id: 'size',
              read: (b) {
                check('read');
                return b.size;
              },
              write: (b, v) {
                check('write');
                return b.copyWith(size: v);
              },
              min: 10,
              max: 10000,
              decimals: 0),
          ActionProperty<BlockComponent>(
              id: 'grow',
              apply: (b) {
                check('apply');
                return b.copyWith(size: b.size * 2);
              }),
        ],
        section: (context, value, commit, words) {
          check('section');
          return BoomSection(kit: this);
        },
        title: (b) {
          check('title');
          return 'type:boom.block';
        },
        colour: ColourTarget<BlockComponent>(read: (b) {
          check('colourRead');
          return b.swatch;
        }, write: (b, swatch) {
          check('colourWrite');
          return b.withSwatch(swatch);
        }),
      ),
      PlanType<PostComponent>(
        id: PostComponent.componentTypeId,
        fromJson: (json) {
          check('fromJson');
          return PostComponent.fromJson(json);
        },
        parametric: BoomType<PostComponent>(this, contributes: true),
      ),
      PlanType<ZoneComponent>(
        id: ZoneComponent.componentTypeId,
        fromJson: (json) {
          check('fromJson');
          return ZoneComponent.fromJson(json);
        },
        parametric: BoomType<ZoneComponent>(this, reads: true),
      ),
    ],
    tools: [
      PlanTool(
        id: 'boom.tool',
        icon: Icons.warning_amber,
        letter: 'B',
        needs: const {
          Capability.structure,
          Capability.components,
          Capability.geometry,
        },
        create: (services) {
          check('toolCreate');
          return BoomTool(this);
        },
      ),
    ],
    attachments: [
      (services) {
        check('attachCreate');
        return BoomEdge(this);
      },
    ],
    names: const KitNames({
      'en': {
        'type:boom.block': 'Block',
        'type:boom.post': 'Post',
        'type:boom.zone': 'Zone',
        'tool:boom.tool': 'Boom',
        'property:boom.block.size': 'Size',
        'property:boom.block.grow': 'Grow',
      },
    }),
  );
}

/// The three boom components: a square of [size] (mm) centred on the
/// group's origin, a plan swatch, and the objects it references.
@immutable
sealed class BoomComponent implements Component {
  const BoomComponent({required this.size, this.swatch, this.refs = const []});

  final double size;
  final String? swatch;
  final List<Handle> refs;

  BoomComponent copyWith({double? size, List<Handle>? refs});
  BoomComponent withSwatch(String? swatch);

  @override
  Map<String, Object?> toJson() => {
        'refs': [for (final h in refs) h.value],
        'size': size,
        'swatch': swatch,
      };

  static ({double size, String? swatch, List<Handle> refs}) read(
          Map<String, Object?> json) =>
      (
        size: (json['size']! as num).toDouble(),
        swatch: json['swatch'] as String?,
        refs: [
          for (final v in (json['refs'] as List<Object?>?) ?? const <Object?>[])
            Handle.fromJson(v),
        ],
      );

  @override
  bool operator ==(Object other) =>
      other is BoomComponent &&
      other.runtimeType == runtimeType &&
      other.size == size &&
      other.swatch == swatch &&
      listEquals(other.refs, refs);

  @override
  int get hashCode => Object.hash(runtimeType, size, swatch, Object.hashAll(refs));
}

final class BlockComponent extends BoomComponent {
  const BlockComponent({required super.size, super.swatch, super.refs});

  static const String componentTypeId = 'boom.block';

  @override
  String get typeId => componentTypeId;

  @override
  BlockComponent copyWith({double? size, List<Handle>? refs}) =>
      BlockComponent(size: size ?? this.size, swatch: swatch, refs: refs ?? this.refs);

  @override
  BlockComponent withSwatch(String? swatch) =>
      BlockComponent(size: size, swatch: swatch, refs: refs);

  static BlockComponent fromJson(Map<String, Object?> json) {
    final r = BoomComponent.read(json);
    return BlockComponent(size: r.size, swatch: r.swatch, refs: r.refs);
  }
}

final class PostComponent extends BoomComponent {
  const PostComponent({required super.size, super.swatch, super.refs});

  static const String componentTypeId = 'boom.post';

  @override
  String get typeId => componentTypeId;

  @override
  PostComponent copyWith({double? size, List<Handle>? refs}) =>
      PostComponent(size: size ?? this.size, swatch: swatch, refs: refs ?? this.refs);

  @override
  PostComponent withSwatch(String? swatch) =>
      PostComponent(size: size, swatch: swatch, refs: refs);

  static PostComponent fromJson(Map<String, Object?> json) {
    final r = BoomComponent.read(json);
    return PostComponent(size: r.size, swatch: r.swatch, refs: r.refs);
  }
}

final class ZoneComponent extends BoomComponent {
  const ZoneComponent({required super.size, super.swatch, super.refs});

  static const String componentTypeId = 'boom.zone';

  @override
  String get typeId => componentTypeId;

  @override
  ZoneComponent copyWith({double? size, List<Handle>? refs}) =>
      ZoneComponent(size: size ?? this.size, swatch: swatch, refs: refs ?? this.refs);

  @override
  ZoneComponent withSwatch(String? swatch) =>
      ZoneComponent(size: size, swatch: swatch, refs: refs);

  static ZoneComponent fromJson(Map<String, Object?> json) {
    final r = BoomComponent.read(json);
    return ZoneComponent(size: r.size, swatch: r.swatch, refs: r.refs);
  }
}

/// The square's corners in its group's space.
List<Vector2> boomSquare(double size) => [
      Vector2(-size / 2, -size / 2),
      Vector2(size / 2, -size / 2),
      Vector2(size / 2, size / 2),
      Vector2(-size / 2, size / 2),
    ];

Aabb2 _boxOf(double size, Transform2 toWorld) => Aabb2.fromPoints(
    [for (final c in boomSquare(size)) toWorld.transformPoint(c)]);

/// Every engine hook calls [ThrowingKit.check] with its own name first. A
/// reference that dangles orphans (keeps) the referrer, so a fixture never
/// cascades by accident.
final class BoomType<T extends BoomComponent> extends ParametricType<T> {
  const BoomType(this.kit, {this.contributes = false, this.reads = false});

  final ThrowingKit kit;
  final bool contributes;
  final bool reads;

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(T params, Transform2 toWorld) {
    kit.check('reach');
    return _boxOf(params.size, toWorld);
  }

  @override
  Iterable<Handle> references(T params) {
    kit.check('references');
    return params.refs;
  }

  @override
  ReferencePolicy get referencePolicy => ReferencePolicy.orphan;

  @override
  Object? pageKey(PageComponent? page) {
    kit.check('pageKey');
    return null;
  }

  @override
  bool dissolves(ParametricView view, Handle self) {
    kit.check('dissolves');
    return false;
  }

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    kit.check('generate');
    final p = view.paramsOf<T>(self)!;
    if (reads) view.placedIn(_boxOf(p.size, view.toWorld(self)));
    return [
      Generated(
          EntityKind.polyline, polylinePayload(boomSquare(p.size), closed: true)),
    ];
  }

  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) {
    kit.check('diagnose');
    return const [];
  }

  @override
  bool get contributesPlace => contributes;

  @override
  Aabb2? placeBox(ParametricView view, Handle self) {
    kit.check('placeBox');
    final p = view.paramsOf<T>(self);
    return p == null ? null : _boxOf(p.size, view.toWorld(self));
  }

  @override
  Object placeInput(ParametricView view, Handle self) {
    kit.check('placeInput');
    final p = view.paramsOf<T>(self);
    final b = p == null ? null : _boxOf(p.size, view.toWorld(self));
    return (b?.minX, b?.minY, b?.maxX, b?.maxY);
  }

  @override
  bool get readsPlaces => reads;

  @override
  Aabb2 readBox(T params, Transform2 toWorld, Aabb2 stored) {
    kit.check('readBox');
    return _boxOf(params.size, toWorld);
  }
}

/// One stretch grip at the block's right edge; a drag sets the size.
final class BoomGrips implements ObjectGripProvider {
  BoomGrips(this.kit);

  final ThrowingKit kit;

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    kit.check('gripsOf');
    final b = d.components.get<BlockComponent>(group);
    final node = d.tree[group];
    if (b == null || node is! GroupNode) return const [];
    final p = node.transform.transformPoint(Vector2(b.size / 2, 0));
    return [Grip(GripRole.stretch, 0, p.x, p.y)];
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    kit.check('gripsDrag');
    final b = d.components.get<BlockComponent>(group);
    final node = d.tree[group];
    if (b == null || node is! GroupNode) return null;
    final size = 2 * node.transform.invert().transformPoint(world).x.abs();
    if (size <= Tolerance.standard.linear) return null;
    return SetComponentCommand<BlockComponent>(group, b.copyWith(size: size));
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    kit.check('gripsPreview');
    return const [];
  }

  @override
  bool movable(DraftDocument d, Handle group) {
    kit.check('gripsMovable');
    return true;
  }
}

/// A press places a 400 mm block at the press; every other call only
/// checks its hook.
final class BoomTool extends Tool {
  BoomTool(this.kit);

  final ThrowingKit kit;

  @override
  String get name => 'Boom';

  @override
  ToolPhase get phase => ToolPhase.idle;

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    kit.check('toolDown');
    if (e.buttons & kPrimaryButton == 0) return;
    ctx.execute(placeObjectCommand<BlockComponent>(
        ctx.document, const BlockComponent(size: 400),
        at: e.world));
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) =>
      kit.check('toolMove');

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) => kit.check('toolUp');

  @override
  void onPointerExit(ToolContext ctx) => kit.check('toolExit');

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    kit.check('toolKey');
    return KeyEventResult.ignored;
  }

  @override
  void cancel(ToolContext ctx) => kit.check('toolCancel');

  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
          PaperPalette paper) =>
      kit.check('toolPaint');

  @override
  void paintWorldOverlay(
          Canvas canvas, Vector2 origin, double scale, PaperPalette paper) =>
      kit.check('toolPaint');
}

/// The test edge at `y = -2000`, kind `boom-edge`, whose attach can throw.
final class BoomEdge extends TestEdge {
  BoomEdge(this.kit) : super(kind: 'boom-edge', y: -2000);

  final ThrowingKit kit;

  @override
  Attachment? attach(AttachmentQuery query) {
    kit.check('attach');
    return super.attach(query);
  }
}

/// The block's section: its build checks `sectionWidget`.
final class BoomSection extends StatelessWidget {
  const BoomSection({super.key, required this.kit});

  final ThrowingKit kit;

  @override
  Widget build(BuildContext context) {
    kit.check('sectionWidget');
    return const Text('boom', key: Key('boom-section'));
  }
}
```

  Create `packages/jet_cad_2d_plan/test/support/harness.dart`:

```dart
// The plan library's test helpers (spec 2a "Tests"): plan documents over a
// list of kits and their parametric system, pointer events for driving a
// tool without a canvas, and a pump that puts a widget in an app. Later
// tasks add to it: Task 7 `planText`, Task 8 `controllerFor`.
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// Every kit's types registered, in load order, without a guard.
ParametricCatalog catalogOf(List<PlanKit> kits) {
  final catalog = ParametricCatalog();
  for (final kit in kits) {
    for (final type in kit.types) {
      type.registerInto(catalog);
    }
  }
  return catalog;
}

/// The page, the contract's four components and [catalog]'s: what a plan
/// document registers. Once per registry (`PageComponent.register` wipes
/// a live page).
void registerPlanComponents(
    ComponentRegistry registry, ParametricCatalog catalog) {
  PageComponent.register(registry);
  registerKitComponents(registry);
  catalog.registerComponents(registry);
}

/// A new plan's document over [kits]: millimetres, the default page (A4
/// landscape at 1:50, origin (-7425, -5250)) printing [separator], no
/// history. No system is installed.
DraftDocument planDocument(List<PlanKit> kits,
    {TextMeasurer measurer = const InsertionPointMeasurer(),
    DecimalSeparator separator = DecimalSeparator.point}) {
  final d = DraftDocument.empty(measurer: measurer);
  registerPlanComponents(d.components, catalogOf(kits));
  d.header.units = DrawingUnits.millimeters;
  d.commands.execute(SetComponentCommand<PageComponent>(
      d.rootHandle,
      PageComponent(
          originX: -7425, originY: -5250, decimalSeparator: separator)));
  d.commands.clearHistory();
  return d;
}

/// [kits]' parametric system on [d], installed now and disposed at
/// tear-down. Call inside a test.
ParametricSystem installSystem(DraftDocument d, List<PlanKit> kits) {
  final system = ParametricSystem(d, catalogOf(kits))..install();
  addTearDown(system.dispose);
  return system;
}

/// A root line from [a] to [b] on layer 0, executed; its handle.
Handle addLine(DraftDocument d, Vector2 a, Vector2 b) {
  final command = addDrafted(d, EntityKind.line, linePayload(a, b),
      layer: ReservedHandles.layerZero);
  d.commands.execute(command);
  return command.record.handle;
}

/// The handles of the entities [owner] holds, ascending by slot.
List<Handle> leavesOf(DraftDocument d, Handle owner) => [
      for (final slot in d.entities.liveSlots)
        if (d.entities.ownerAt(slot) == owner) d.entities.handleAt(slot),
    ];

/// [leaf]'s stored coordinates.
Float64List coordsOf(DraftDocument d, Handle leaf) {
  final slot = d.entities.slotOf(leaf)!;
  return d.geometry.read(d.entities.geomIndexAt(slot)).coords;
}

/// A primary-button event at [world], for driving a tool directly.
ToolPointerEvent pointerAt(Vector2 world,
        {int buttons = kPrimaryButton,
        Offset screen = Offset.zero,
        double pickRadiusWorld = 1}) =>
    ToolPointerEvent(
        screen: screen,
        world: world,
        pointer: 1,
        buttons: buttons,
        shift: false,
        control: false,
        meta: false,
        alt: false,
        pickRadiusWorld: pickRadiusWorld);

/// [child] in a Material app of [size] logical pixels.
Future<void> pumpApp(WidgetTester tester, Widget child,
    {Size size = const Size(1440, 900)}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
}
```

- [ ] **Step 7: Write the failing tests.** Create `packages/jet_cad_2d_plan/test/kits/kit_set_test.dart`:

```dart
// Spec 2a P4 "The kit set": validateKitSet refuses a set with one
// ArgumentError (KitSetError) that lists every problem with its code, in
// load order; a sound set is held in load order.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show ParametricCatalog;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/test_kit.dart';

/// The codes [kits] are refused with, in order; empty when accepted.
List<KitProblemCode> codesOf(List<PlanKit> kits) {
  try {
    validateKitSet(kits);
  } on KitSetError catch (e) {
    return [for (final p in e.problems) p.code];
  }
  return const [];
}

KitSetError errorOf(List<PlanKit> kits) {
  try {
    validateKitSet(kits);
  } on KitSetError catch (e) {
    return e;
  }
  fail('the set was accepted');
}

void main() {
  test('KS1 a sound set is held in load order: kits, types, tools, lookups',
      () {
    final slab = testKit();
    final disc = discKit();
    final set = validateKitSet([slab, disc]);
    // M-KS1: the kits sorted by id ('disc' before 'test').
    expect([for (final k in set.kits) k.id], ['test', 'disc']);
    expect([for (final t in set.types) t.id], ['test.slab', 'disc.round']);
    expect([for (final t in set.tools) t.id], ['test.slab']);
    expect(set.kitOf('disc'), same(disc));
    expect(set.kitOf('plan'), isNull);
    expect(set.typeOf('disc.round'), same(disc.types.single));
    expect(set.typeOf('test.reader'), isNull);
    expect(validateKitSet(const []).kits, isEmpty);
  });

  test('KS2 two kits with one id: duplicateKit, once, naming the id', () {
    final e = errorOf([testKit(), testKit(version: '2.0.0')]);
    // M-KS2: the duplicate-kit check removed.
    expect([for (final p in e.problems) p.code], [KitProblemCode.duplicateKit]);
    expect(e.problems.single.message, contains('"test"'));
  });

  test('KS3 the reserved ids plan and jetcad', () {
    // M-KS3: reservedKitIds = {'plan'}.
    expect(
        codesOf([
          const PlanKit(id: 'plan', version: '1.0.0'),
          const PlanKit(id: 'jetcad', version: '1.0.0'),
        ]),
        [KitProblemCode.reservedKitId, KitProblemCode.reservedKitId]);
  });

  test("KS4 a type id another kit already gave: duplicateType, once", () {
    final e = errorOf([
      testKit(),
      PlanKit(id: 'ex', version: '1.0.0', types: [slabType()]),
    ]);
    final codes = [for (final p in e.problems) p.code];
    // M-KS4: the cross-kit type check removed.
    expect(codes.where((c) => c == KitProblemCode.duplicateType), hasLength(1));
    // The kit's own validate() finds the type outside its id (Task 4).
    expect(codes, contains(KitProblemCode.typeOutsideKit));
    final duplicate = e.problems
        .singleWhere((p) => p.code == KitProblemCode.duplicateType)
        .message;
    expect(duplicate, allOf(contains('test.slab'), contains('"ex"'), contains('"test"')));
  });

  test("KS5 a tool id another kit already gave: duplicateTool, once", () {
    final codes = codesOf([
      testKit(),
      PlanKit(id: 'ex', version: '1.0.0', tools: [slabTool()]),
    ]);
    // M-KS5: the cross-kit tool check removed.
    expect(codes.where((c) => c == KitProblemCode.duplicateTool), hasLength(1));
    expect(codes, contains(KitProblemCode.toolOutsideKit));
  });

  test('KS6 a duplicate inside one kit is reported once, by its validate()',
      () {
    final codes = codesOf([
      PlanKit(
          id: 'test',
          version: '1.0.0',
          types: [slabType(), slabType()],
          names: testWords),
    ]);
    // M-KS6: the cross-kit check also counts an earlier occurrence in the
    // same kit (`typeKits.containsKey(type.id)` in place of `first !=
    // kit.id`): two duplicateType.
    expect(codes.where((c) => c == KitProblemCode.duplicateType), hasLength(1));
  });

  test('KS7 a type that both contributes and reads places: typePlaceConflict',
      () {
    // Premise: the engine itself refuses this type.
    expect(
        () => ParametricCatalog().register<ReaderComponent>(
            readerTypeId, ReaderComponent.fromJson, const ReaderType()),
        throwsArgumentError);
    final e = errorOf([conflictKit()]);
    // M-KS7: the conflict check removed.
    expect([for (final p in e.problems) p.code],
        [KitProblemCode.typePlaceConflict]);
    expect(e.problems.single.message, contains('test.reader'));
  });

  test("KS8 each kit's own validate() problems, prefixed by its id", () {
    final e = errorOf([testKit(version: ' ')]);
    // M-KS8: the kits' validate() not called.
    expect([for (final p in e.problems) p.code], [KitProblemCode.emptyVersion]);
    expect(e.problems.single.message, startsWith('test: '));
  });

  test('KS9 every problem in one ArgumentError, in load order, one line each',
      () {
    final e = errorOf([
      const PlanKit(id: 'plan', version: '1.0.0'),
      testKit(),
      testKit(version: '2.0.0'),
      conflictKit(),
    ]);
    // M-KS9: throw at the first problem found.
    expect([for (final p in e.problems) p.code], [
      KitProblemCode.reservedKitId,
      KitProblemCode.duplicateKit,
      KitProblemCode.duplicateKit,
      KitProblemCode.typePlaceConflict,
    ]);
    expect(e, isA<ArgumentError>());
    expect(e.name, 'kits');
    final lines = (e.message as String).split('\n').skip(1).toList();
    expect(lines, [for (final p in e.problems) '  $p']);
  });
}
```

  Create `packages/jet_cad_2d_plan/test/kits/test_kits_test.dart` (fixture sanity: exempt from the mutation rule, it pins the fixtures):

```dart
// The test kits are sound (spec 2a "Tests"): the test kit's words are
// English and Turkish only, every id it uses has its English word, and the
// throwing kit throws for the hooks it is told to and no others.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/test_kit.dart';
import '../support/throwing_kit.dart';

void main() {
  test('TK1 the test kit validates; its words are en and tr, no de', () {
    final kit = testKit();
    expect(kit.validate(), isEmpty);
    expect(kit.names.words.keys.toSet(), {'en', 'tr'});
    final english = kit.names.words['en']!;
    for (final spec in slabProperties()) {
      expect(english, contains('property:test.slab.${spec.id}'));
    }
    expect(english.keys.toSet(), kit.names.words['tr']!.keys.toSet());
  });

  test('TK2 the disc kit, the conflict kit and the throwing kit validate', () {
    expect(discKit().validate(), isEmpty);
    expect(conflictKit().validate(), isEmpty);
    expect(ThrowingKit().kit.validate(), isEmpty);
  });

  test('TK3 the throwing kit throws for its failing hooks only', () {
    expect(() => ThrowingKit(failing: ['nope']), throwsArgumentError);
    final kit = ThrowingKit(failing: ['reach']);
    expect(() => kit.check('reach'),
        throwsA(isA<BoomFailure>().having((f) => f.hook, 'hook', 'reach')));
    kit.check('generate');
    kit.failAll();
    expect(kit.failing, boomHooks);
    for (final hook in boomHooks) {
      expect(() => kit.check(hook), throwsA(isA<BoomFailure>()), reason: hook);
    }
  });

  test('TK4 a slab off the origin, turned: its corners and its JSON', () {
    final s = SlabComponent(width: 1800, height: 900, angle: 0.4, swatch: 'red');
    final c = slabCorners(s);
    // (900, -450) turned by 0.4 rad, by hand.
    expect(c[1].x, closeTo(900 * 0.9210609940 + 450 * 0.3894183423, 1e-6));
    expect(c[1].y, closeTo(900 * 0.3894183423 - 450 * 0.9210609940, 1e-6));
    expect(SlabComponent.fromJson(s.toJson()), s);
    expect(s.toJson().keys.toList(), [
      'angle', 'finish', 'flipped', 'height', 'label', 'labelled', 'swatch',
      'thickness', 'width',
    ]);
    expect(discOutline(DiscComponent(radius: 650)).first, Vector2(650, 0));
  });
}
```

- [ ] **Step 8: Run them to see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/kits`. Expected: a compilation error naming `validateKitSet` / `KitSetError` (`Undefined name` / `Undefined class`); `test_kits_test.dart` compiles only if Tasks 3-4 are in (it depends on them alone).

- [ ] **Step 9: The kit set.** Create `packages/jet_cad_2d_plan/lib/src/kits/kit_set.dart`:

```dart
// The kit set (spec 2a P4, umbrella A3): the kits a controller loads,
// validated together. Every problem is found before one ArgumentError
// lists them all; a set that passes is held in load order.
import 'package:jet_cad_2d/jet_cad_2d.dart' show Component;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:meta/meta.dart';

/// The kit ids no kit may take (spec P1): the plan library's own tools are
/// `plan.*`, and the contract's components are `jetcad.*`.
const Set<String> reservedKitIds = {'plan', 'jetcad'};

/// The kits a controller loads, validated by [validateKitSet], in load
/// order.
@immutable
final class KitSet {
  KitSet._(List<PlanKit> kits)
      : kits = List.unmodifiable(kits),
        types = List.unmodifiable([for (final k in kits) ...k.types]),
        tools = List.unmodifiable([for (final k in kits) ...k.tools]),
        _byId = {for (final k in kits) k.id: k},
        _types = {
          for (final k in kits)
            for (final t in k.types) t.id: t,
        };

  /// The kits, in load order.
  final List<PlanKit> kits;

  /// Every kit's types, kit by kit in load order.
  final List<PlanType<Component>> types;

  /// Every kit's tools, kit by kit in load order.
  final List<PlanTool> tools;

  final Map<String, PlanKit> _byId;
  final Map<String, PlanType<Component>> _types;

  /// The kit [id], or null when it is not loaded.
  PlanKit? kitOf(String id) => _byId[id];

  /// The type [typeId] of a loaded kit, or null.
  PlanType<Component>? typeOf(String typeId) => _types[typeId];
}

/// A refused kit set (spec P4): one [ArgumentError] naming every problem,
/// one line each, `  <code>: <message>`.
final class KitSetError extends ArgumentError {
  KitSetError(List<KitProblem> problems)
      : problems = List.unmodifiable(problems),
        super(_describe(problems), 'kits');

  final List<KitProblem> problems;

  static String _describe(List<KitProblem> problems) => [
        'the kit set has ${problems.length} problem(s):',
        for (final p in problems) '  $p',
      ].join('\n');
}

/// [kits] validated together (spec P4), or a [KitSetError] listing, kit by
/// kit in load order: a reserved id; a kit id an earlier kit has; the
/// kit's own `validate()` problems, each prefixed by its id; a type id an
/// earlier kit gave, and a type that both contributes and reads places;
/// a tool id an earlier kit gave. A duplicate inside one kit is that kit's
/// `validate()`'s to report. Symbol keys are not checked here: the symbol
/// loader drops a later kit's duplicate key (spec P2).
KitSet validateKitSet(List<PlanKit> kits) {
  final problems = <KitProblem>[];
  final kitIds = <String>{};
  final typeKits = <String, String>{};
  final toolKits = <String, String>{};
  for (final kit in kits) {
    if (reservedKitIds.contains(kit.id)) {
      problems.add(KitProblem(KitProblemCode.reservedKitId,
          'the kit id "${kit.id}" is reserved for the plan library'));
    }
    if (!kitIds.add(kit.id)) {
      problems.add(KitProblem(KitProblemCode.duplicateKit,
          'two kits have the id "${kit.id}"'));
    }
    for (final p in kit.validate()) {
      problems.add(KitProblem(p.code, '${kit.id}: ${p.message}'));
    }
    for (final type in kit.types) {
      final first = typeKits.putIfAbsent(type.id, () => kit.id);
      if (first != kit.id) {
        problems.add(KitProblem(
            KitProblemCode.duplicateType,
            'the type "${type.id}" of the kit "${kit.id}" is already the '
            'kit "$first"\'s'));
      }
      final parametric = type.parametric;
      if (parametric.contributesPlace && parametric.readsPlaces) {
        problems.add(KitProblem(
            KitProblemCode.typePlaceConflict,
            '${kit.id}: the type "${type.id}" both contributes places and '
            'reads them, which the engine refuses'));
      }
    }
    for (final tool in kit.tools) {
      final first = toolKits.putIfAbsent(tool.id, () => kit.id);
      if (first != kit.id) {
        problems.add(KitProblem(
            KitProblemCode.duplicateTool,
            'the tool "${tool.id}" of the kit "${kit.id}" is already the '
            'kit "$first"\'s'));
      }
    }
  }
  if (problems.isNotEmpty) throw KitSetError(problems);
  return KitSet._(kits);
}
```

  (`PlanTool.id` is read the same way; if Task 4 named the tool's id field otherwise, use its getter.)

- [ ] **Step 10: Run the tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/kits`. Expected: `All tests passed!`.

- [ ] **Step 11: The CI matrices.** In `.github/workflows/ci.yml`:
  - in `jobs.package.strategy.matrix.include`, after the `packages/jet_cad_2d_kit` entry (`- package: packages/jet_cad_2d_kit` / `tool: flutter`), add, at the same indentation:

```yaml
          - package: packages/jet_cad_2d_plan
            tool: flutter
```

  - in `jobs.publishable.strategy.matrix.package`, after `- packages/jet_cad_2d_kit`, add `          - packages/jet_cad_2d_plan`.

  Check the workflow parses: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"` (no output). `git diff .github/workflows/ci.yml` shows exactly these three added lines. `tool/ci/test/scripts_test.dart` SC16 (`:333-347`) requires every `packages/*` with a pubspec in the `package` matrix: it is red without the first addition.

- [ ] **Step 12: Format and the gates.** Run, each expected to exit 0:
  - `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` (expected: `All tests passed!`, `No issues found!`).
  - `cd tool/ci && dart test` (SC16 green with Step 11).
  - from the root: `dart run tool/ci/check_kit_deps.dart` (expected: the line `kit dependencies: N package(s) checked, none names the plan library or another kit`; the plan library is neither the contract nor a kit, so it is not counted).
  - `cd packages/jet_cad_2d_kit && flutter test` (unchanged by this task; the kits under test use its contract).

- [ ] **Step 13: Commit.** `git status --short` first; stage by explicit path only:

```bash
git add pubspec.yaml .github/workflows/ci.yml packages/jet_cad_2d_plan/pubspec.yaml packages/jet_cad_2d_plan/analysis_options.yaml packages/jet_cad_2d_plan/LICENSE packages/jet_cad_2d_plan/README.md packages/jet_cad_2d_plan/CHANGELOG.md packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/lib/src/kits/kit_set.dart packages/jet_cad_2d_plan/test/support/test_kit.dart packages/jet_cad_2d_plan/test/support/throwing_kit.dart packages/jet_cad_2d_plan/test/support/harness.dart packages/jet_cad_2d_plan/test/kits/kit_set_test.dart packages/jet_cad_2d_plan/test/kits/test_kits_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): the jet_cad_2d_plan package, kit-set validation, test kits

A workspace member at 0.8.0 with its barrel, and validateKitSet: one
KitSetError lists every problem of a kit set, kit by kit in load order
(reserved and duplicate kit ids, each kit's own validate(), type and tool
ids another kit gave, a type that both contributes and reads places).
The test kit, the throwing kit and the harness every later task uses,
and the package in CI's package and publishable matrices.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 14: The publish dry run** (after the commit: a dry run warns about uncommitted files). Run: `cd packages/jet_cad_2d_plan && dart pub publish --dry-run`. Expected: exit 0 and `Package has 0 warnings.`. A warning is a defect of this task (the description's length, the CHANGELOG's version line, the LICENSE): fix it, amend nothing, commit the fix by explicit path. **Never** run it without `--dry-run`.

- [ ] **Step 15: Mutation step** (committed files only; after each: run the named test, see it red, then `git checkout -- packages/jet_cad_2d_plan/lib/src/kits/kit_set.dart` and `git diff --quiet -- packages/jet_cad_2d_plan/lib/src/kits/kit_set.dart` exits 0). Run each test with `cd packages/jet_cad_2d_plan && flutter test test/kits/kit_set_test.dart --plain-name '<id> '`.
  - M-KS1: `return KitSet._([...kits]..sort((a, b) => a.id.compareTo(b.id)));` in place of `return KitSet._(kits);` → KS1 red.
  - M-KS2: delete the `if (!kitIds.add(kit.id)) { ... }` block → KS2 red (and KS9).
  - M-KS3: `const Set<String> reservedKitIds = {'plan'};` → KS3 red.
  - M-KS4: delete the `if (first != kit.id) { ... duplicateType ... }` block → KS4 red.
  - M-KS5: delete the `if (first != kit.id) { ... duplicateTool ... }` block → KS5 red.
  - M-KS6: in the type loop, replace `final first = typeKits.putIfAbsent(type.id, () => kit.id); if (first != kit.id) {` with `final seen = typeKits.containsKey(type.id); final first = typeKits.putIfAbsent(type.id, () => kit.id); if (seen) {` → KS6 red (two `duplicateType`).
  - M-KS7: delete the `if (parametric.contributesPlace && parametric.readsPlaces) { ... }` block → KS7 red (and KS9).
  - M-KS8: delete the `for (final p in kit.validate()) { ... }` loop → KS8 red.
  - M-KS9: `if (problems.isNotEmpty) throw KitSetError(problems);` moved to the end of the `for (final kit in kits)` body (thrown after the first kit with a problem) → KS9 red.

---

