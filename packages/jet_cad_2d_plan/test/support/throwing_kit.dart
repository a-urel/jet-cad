// The throwing kit (spec 2a "Tests"): every hook of a kit can be switched
// to throw, one at a time or all together, by its name in `failing`. Task
// 11's guard is proven against it: each hook has a test and a named mutant
// (that hook's guard removed). Three types, so every engine hook is
// reachable: `boom.block` (grips, properties, section, title, colour),
// `boom.post` (contributes places) and `boom.zone` (reads them).
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart' hide Tolerance;
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
  // The grip provider: its factory, then each call; Task 11 adds its
  // dispose.
  'gripsCreate', 'gripsOf', 'gripsDrag', 'gripsPreview', 'gripsMovable',
  'gripsDispose',
  // The tool's shared cache (Task 11): its dispose.
  'cacheDispose',
  // The tool: its factory, its events, its painting; Task 11 adds a getter
  // (isMidShape) and its dispose.
  'toolCreate', 'toolDown', 'toolMove', 'toolUp', 'toolExit', 'toolKey',
  'toolCancel', 'toolPaint', 'toolMidShape', 'toolDispose',
  // The attachment provider: its factory, then attach.
  'attachCreate', 'attach',
  // Properties, the section (its builder, then the widget it returns), the
  // colour target and the title.
  'read', 'write', 'apply', 'section', 'sectionWidget', 'colourRead',
  'colourWrite', 'title',
  // Spec 3a C1.1, C1.7: a text display's read, a length's range, a spec's visible.
  'display', 'range', 'visible',
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
          TextDisplay<BlockComponent>(
              id: 'shown',
              read: (b, o) {
                check('display');
                return '${b.size.round()} mm at ${o.handle.value}';
              }),
          LengthProperty<BlockComponent>(
              id: 'span',
              read: (b) => b.size,
              write: (b, v) => b.copyWith(size: v),
              min: 10,
              max: 10000,
              range: (b, o) {
                check('range');
                return (10, 10000);
              }),
          ActionProperty<BlockComponent>(
              id: 'grow',
              apply: (b) {
                check('apply');
                return b.copyWith(size: b.size * 2);
              },
              visible: (b) {
                check('visible');
                return true;
              }),
        ],
        section: (context, section) {
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
          services.shared<BoomCache>((_) => BoomCache(this));
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
        'property:boom.block.shown': 'Shown',
        'property:boom.block.span': 'Span',
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
  int get hashCode =>
      Object.hash(runtimeType, size, swatch, Object.hashAll(refs));
}

final class BlockComponent extends BoomComponent {
  const BlockComponent({required super.size, super.swatch, super.refs});

  static const String componentTypeId = 'boom.block';

  @override
  String get typeId => componentTypeId;

  @override
  BlockComponent copyWith({double? size, List<Handle>? refs}) => BlockComponent(
      size: size ?? this.size, swatch: swatch, refs: refs ?? this.refs);

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
  PostComponent copyWith({double? size, List<Handle>? refs}) => PostComponent(
      size: size ?? this.size, swatch: swatch, refs: refs ?? this.refs);

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
  ZoneComponent copyWith({double? size, List<Handle>? refs}) => ZoneComponent(
      size: size ?? this.size, swatch: swatch, refs: refs ?? this.refs);

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
      Generated(EntityKind.polyline,
          polylinePayload(boomSquare(p.size), closed: true)),
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

/// A per-document cache the tool asks for; only its dispose is switched.
final class BoomCache implements Disposable {
  BoomCache(this.kit);

  final ThrowingKit kit;

  @override
  void dispose() => kit.check('cacheDispose');
}

/// One stretch grip at the block's right edge; a drag sets the size.
final class BoomGrips implements ObjectGripProvider, Disposable {
  BoomGrips(this.kit);

  final ThrowingKit kit;

  @override
  void dispose() => kit.check('gripsDispose');

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
  bool get isMidShape {
    kit.check('toolMidShape');
    return false;
  }

  @override
  void dispose() {
    kit.check('toolDispose');
    super.dispose();
  }

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
