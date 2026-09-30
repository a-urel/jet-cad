// Spec 06 D5, as amended by fix/live-object-rule: `ParametricCatalog.names`
// and `ParametricCatalog.objectsOf` answer the engine's own object rule, the
// one the survey uses. A live object is a root-level `GroupNode` carrying a
// registered parametric component; when it carries two, the later
// registration names it.
//
// The catalogs here register five types, so the pair under test (Hinge and
// Caption) is neither the first nor the last registered. Every group sits
// rotated and off the origin, and no handle under test is the lowest
// allocated.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

/// A component that is not parametric: registered in the document's
/// registry only, never in a catalog.
final class Memo implements Component {
  const Memo(this.n);
  static const String id = 'test.lo.memo';
  final int n;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'n': n};
  static Memo fromJson(Map<String, Object?> j) => Memo(j['n']! as int);
  @override
  bool operator ==(Object o) => o is Memo && o.n == n;
  @override
  int get hashCode => n.hashCode;
}

/// SoftRect, Hinge, Post, Caption, Whisker: Hinge before Caption.
ParametricCatalog hingeFirst() => ParametricCatalog()
  ..register<SoftRect>(
      SoftRect.id, SoftRect.fromJson, const RectType(Capability.components))
  ..register<Hinge>(Hinge.id, Hinge.fromJson, const HingeType())
  ..register<Post>(Post.id, Post.fromJson, const PostType())
  ..register<Caption>(Caption.id, Caption.fromJson, const CaptionType())
  ..register<Whisker>(Whisker.id, Whisker.fromJson, const WhiskerType());

/// The same five, with Hinge and Caption swapped: Caption before Hinge.
ParametricCatalog captionFirst() => ParametricCatalog()
  ..register<SoftRect>(
      SoftRect.id, SoftRect.fromJson, const RectType(Capability.components))
  ..register<Caption>(Caption.id, Caption.fromJson, const CaptionType())
  ..register<Post>(Post.id, Post.fromJson, const PostType())
  ..register<Hinge>(Hinge.id, Hinge.fromJson, const HingeType())
  ..register<Whisker>(Whisker.id, Whisker.fromJson, const WhiskerType());

/// A document with [cat]'s system installed, three handles burnt so no
/// handle under test is the lowest allocated.
(DraftDocument, ParametricSystem) docWith(ParametricCatalog cat) {
  final doc = DraftDocument.empty();
  final system = ParametricSystem(doc, cat)..install();
  for (var i = 0; i < 3; i++) {
    doc.handleSeed.next();
  }
  return (doc, system);
}

DraftCommand addGroup(Handle h, Handle parent, Transform2 at) => AddNodeCommand(
    GroupNode(handle: h, parent: parent, transform: at, children: const []));

/// Each of [cat]'s registered types asked of [h]: its name and the answer.
Map<String, bool> askAll(ParametricCatalog cat, CommandTarget t, Handle h) => {
      SoftRect.id: cat.names<SoftRect>(t, h),
      Hinge.id: cat.names<Hinge>(t, h),
      Post.id: cat.names<Post>(t, h),
      Caption.id: cat.names<Caption>(t, h),
      Whisker.id: cat.names<Whisker>(t, h),
    };

/// [group]'s children's kinds, ascending by handle.
List<EntityKind> kinds(DraftDocument doc, Handle group) => [
      for (final k in kids(doc, group))
        doc.entities.kindAt(doc.entities.slotOf(k)!),
    ];

void main() {
  test(
      'LO1 a root-level group carrying one registered type is that type\'s '
      'object and no other\'s', () {
    final cat = hingeFirst();
    final (doc, _) = docWith(cat);
    final h = doc.handleSeed.next();
    doc.commands.execute(create(
        doc, h, onA(-640.5, 310.25, 0.9), const Caption('LO1', 12.5, -7.25)));
    expect(kinds(doc, h), [EntityKind.text]);

    expect(askAll(cat, doc, h), {
      SoftRect.id: false,
      Hinge.id: false,
      Post.id: false,
      Caption.id: true,
      Whisker.id: false,
    });
    expect(cat.objectsOf<Caption>(doc), [h]);
    expect(cat.objectsOf<Hinge>(doc), isEmpty);
    expect(cat.objectsOf<SoftRect>(doc), isEmpty);
  });

  test(
      'LO2 a root-level group carrying Hinge and Caption is the later '
      'registration\'s object, in the query and in the regeneration; the '
      'opposite catalog order flips both', () {
    for (final (cat, later, earlier) in [
      (hingeFirst(), Caption.id, Hinge.id),
      (captionFirst(), Hinge.id, Caption.id),
    ]) {
      final (doc, system) = docWith(cat);
      final h = doc.handleSeed.next();
      // Through the dispatcher: the survey decides what is generated.
      doc.commands.execute(CompoundCommand([
        addGroup(h, doc.rootHandle, onA(1210.75, -455.5, -0.4)),
        SetComponentCommand<Hinge>(h, const Hinge(false)),
        SetComponentCommand<Caption>(h, const Caption('LO2', -3.5, 8.25)),
      ], label: 'Add both'));
      // Both components are stored whichever names the object.
      expect(doc.components.get<Hinge>(h), const Hinge(false), reason: later);
      expect(doc.components.get<Caption>(h), const Caption('LO2', -3.5, 8.25),
          reason: later);

      final captionNames = later == Caption.id;
      expect(
          askAll(cat, doc, h),
          {
            SoftRect.id: false,
            Hinge.id: !captionNames,
            Post.id: false,
            Caption.id: captionNames,
            Whisker.id: false,
          },
          reason: later);
      expect(cat.objectsOf<Caption>(doc), captionNames ? [h] : isEmpty,
          reason: later);
      expect(cat.objectsOf<Hinge>(doc), captionNames ? isEmpty : [h],
          reason: later);
      expect(system.catalog.names<Caption>(doc, h), captionNames,
          reason: later);

      // The survey agrees: the later registration's type generated.
      expect(kinds(doc, h),
          captionNames ? [EntityKind.text] : [EntityKind.line, EntityKind.arc],
          reason: 'generated by $later, not $earlier');
      expect(system.drift(), isEmpty, reason: later);
    }
  });

  test(
      'LO3 a nested group, a root-level instance, a leaf, a deleted '
      'object\'s handle and a never-allocated handle carrying a Caption are '
      'not objects; a live one beside them is', () {
    final cat = hingeFirst();
    final (doc, _) = docWith(cat);
    final outer = doc.handleSeed.next();
    doc.commands.execute(addGroup(
        outer,
        doc.rootHandle,
        Transform2.translation(-4200, 9100)
            .multiply(Transform2.rotation(1.1))));
    final nested = doc.handleSeed.next();
    doc.commands.execute(addGroup(nested, outer,
        Transform2.translation(130, -45).multiply(Transform2.rotation(-0.35))));
    final definition = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
        handle: definition,
        name: 'Stool',
        basePoint: Vector2(35.5, -12.25),
        children: const []));
    final instance = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: instance,
        parent: doc.rootHandle,
        transform: onA(-240, 95, -0.35),
        definition: definition,
        layer: ReservedHandles.layerZero)));
    final add = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(7010.5, 3020.25), Vector2(7133.1, 3071.9)));
    doc.commands.execute(add);
    final leaf = add.record.handle;
    final live = doc.handleSeed.next();
    doc.commands.execute(
        create(doc, live, onA(300.5, 800.25, 0.2), const Caption('L', 1, 2)));
    final dead = doc.handleSeed.next();
    doc.commands.execute(
        create(doc, dead, onA(-900, 400, 0.8), const Caption('D', 3, 4)));
    doc.commands.execute(CompoundCommand([
      for (final k in kids(doc, dead)) RemoveEntityCommand(k),
      RemoveNodeCommand(dead),
    ], label: 'Delete'));
    final never = Handle(doc.handleSeed.current.value + 77);

    // As a file would leave them: written straight into the store.
    const c = Caption('stray', 5.5, -6.5);
    for (final h in [nested, instance, leaf, dead, never]) {
      doc.components.attach<Caption>(h, c);
    }
    expect(doc.tree[nested], isA<GroupNode>());
    expect(doc.tree[instance], isA<InstanceNode>());
    expect(doc.tree[instance]!.parent, doc.rootHandle);
    expect(doc.tree[dead], isNull);

    for (final h in [nested, instance, leaf, dead, never]) {
      expect(askAll(cat, doc, h).values, everyElement(isFalse),
          reason: h.toHex());
    }
    expect(cat.names<Caption>(doc, live), isTrue);
    expect(cat.objectsOf<Caption>(doc), [live]);
    // Control: every holder does carry the component.
    expect(doc.components.withComponent<Caption>(),
        unorderedEquals([nested, instance, leaf, live, dead, never]));
  });

  test(
      'LO4 an unregistered type, a supertype and Component itself name '
      'nothing: the match is exact', () {
    final cat = hingeFirst();
    final (doc, _) = docWith(cat);
    doc.components.register<Memo>(Memo.id, Memo.fromJson);
    final soft = doc.handleSeed.next();
    doc.commands.execute(
        create(doc, soft, onA(-50.5, 1400.25, 1.3), const SoftRect(320, 180)));
    final memoOnly = doc.handleSeed.next();
    doc.commands
        .execute(addGroup(memoOnly, doc.rootHandle, onA(2200.5, 95.75, -1.1)));
    doc.commands.execute(SetComponentCommand<Memo>(memoOnly, const Memo(7)));
    doc.commands.execute(SetComponentCommand<Memo>(soft, const Memo(8)));

    expect(cat.names<SoftRect>(doc, soft), isTrue);
    expect(cat.names<RectParams>(doc, soft), isFalse);
    expect(cat.names<Component>(doc, soft), isFalse);
    expect(cat.names<Memo>(doc, soft), isFalse);
    expect(cat.names<Memo>(doc, memoOnly), isFalse);
    expect(cat.names<Component>(doc, memoOnly), isFalse);
    expect(askAll(cat, doc, memoOnly).values, everyElement(isFalse));
    expect(cat.objectsOf<Memo>(doc), isEmpty);
    expect(cat.objectsOf<SoftRect>(doc), [soft]);
  });

  test(
      'LO5 objectsOf is ascending when the objects were created out of '
      'handle order', () {
    final cat = hingeFirst();
    final (doc, _) = docWith(cat);
    final h1 = doc.handleSeed.next();
    final h2 = doc.handleSeed.next();
    final h3 = doc.handleSeed.next();
    // Created, and so stored, in the order h3, h1, h2.
    for (final (h, x) in [(h3, 900.5), (h1, -300.25), (h2, 450.75)]) {
      doc.commands.execute(
          create(doc, h, onA(x, -120.5, 0.7), Caption('$x', x / 10, 1.5)));
    }
    expect(cat.objectsOf<Caption>(doc), [h1, h2, h3]);
  });
}
