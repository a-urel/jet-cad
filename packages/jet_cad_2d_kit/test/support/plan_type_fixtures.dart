// Fixtures for PlanType and PlanKit (spec 2a P1): engine types for the slab
// and the post of code_fixtures.dart, their PlanTypes, and a document with
// one live object of each, in rotated groups off the origin.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ObjectGripProvider;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import 'code_fixtures.dart';

/// An engine type that generates nothing and logs every object it is asked
/// to generate.
final class LoggingType<T extends Component> extends ParametricType<T> {
  LoggingType();

  final List<Handle> generated = [];

  @override
  Capability get editCapability => Capability.components;

  @override
  Aabb2 reach(T params, Transform2 toWorld) => Aabb2.empty();

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    generated.add(self);
    return const [];
  }
}

String? slabSwatch(Slab s) => s.swatch;

Slab slabRecolour(Slab s, String? swatch) =>
    s.copyWith(swatch: swatch, clearSwatch: swatch == null);

String? postSwatch(Post p) => p.swatch;

Post postRecolour(Post p, String? swatch) =>
    Post(width: p.width, shape: p.shape, swatch: swatch);

/// The slab type: every property kind, a title hook, a colour target, an
/// optional section and grips.
PlanType<Slab> slabType({
  ParametricType<Slab>? engine,
  PropertySectionBuilder<Slab>? section,
  ObjectGripProvider Function(PlanServices)? grips,
}) =>
    PlanType<Slab>(
      id: Slab.id,
      fromJson: Slab.fromJson,
      parametric: engine ?? LoggingType<Slab>(),
      properties: slabSpecs(),
      title: (s) => s.raised ? 'type:test.slab.raised' : 'type:test.slab',
      colour: const ColourTarget<Slab>(read: slabSwatch, write: slabRecolour),
      section: section,
      grips: grips,
    );

/// The post type: a colour target, no title, no section, not exported.
PlanType<Post> postType({ParametricType<Post>? engine}) => PlanType<Post>(
      id: Post.id,
      fromJson: Post.fromJson,
      parametric: engine ?? LoggingType<Post>(),
      properties: postSpecs(),
      colour: const ColourTarget<Post>(read: postSwatch, write: postRecolour),
      exported: false,
    );

const Handle hSlab = Handle(4100);
const Handle hPost = Handle(4200);
const Handle hBare = Handle(4300);

final Transform2 slabAt = Transform2.translation(2150.5, -730.25)
    .multiply(Transform2.rotation(math.pi / 7));
final Transform2 postAt =
    Transform2.translation(-1840.75, 960.5).multiply(Transform2.rotation(-0.4));

DraftCommand addObject<T extends Component>(
        DraftDocument doc, Handle h, Transform2 at, T value) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: at,
          children: const [])),
      SetComponentCommand<T>(h, value),
    ], label: 'Add object');

/// A document whose catalog holds [types] (registered through
/// `registerInto`, with [guard] when given), a slab at [hSlab], a post at
/// [hPost] and a plain group at [hBare]. The caller disposes the document.
({DraftDocument doc, ParametricCatalog catalog}) objectDocument(
    List<PlanType<Component>> types,
    {TypeGuard? guard,
    Slab slab = const Slab(),
    Post post = const Post()}) {
  final catalog = ParametricCatalog();
  for (final type in types) {
    type.registerInto(catalog, guard: guard);
  }
  final doc = DraftDocument.empty();
  ParametricSystem(doc, catalog).install();
  doc.commands
    ..execute(addObject(doc, hSlab, slabAt, slab))
    ..execute(addObject(doc, hPost, postAt, post))
    ..execute(AddNodeCommand(GroupNode(
        handle: hBare,
        parent: doc.rootHandle,
        transform: Transform2.translation(400.5, 300.25),
        children: const [])))
    ..clearHistory();
  return (doc: doc, catalog: catalog);
}
