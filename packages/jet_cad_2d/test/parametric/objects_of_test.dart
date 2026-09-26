// `ParametricView.objectsOf` (spec 10 D16, S-3): the ascending live objects
// of a view's survey whose registered component is a given type, read from
// the survey's snapshot and memoised per view and type. A room's `diagnose`
// finds the other rooms with it. Every object sits in its own rotated group
// off the origin.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

import 'support/clients.dart';
import 'support/fixture.dart';

/// A test-local client that asks `objectsOf` from its `diagnose` and its
/// `generate`, twice each, and keeps both answers. [n] only changes so an
/// edit can seed it.
final class Census implements Component {
  const Census(this.n);
  static const String id = 'test.ob1.census';
  final int n;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'n': n};
  static Census fromJson(Map<String, Object?> j) => Census(j['n']! as int);
  @override
  bool operator ==(Object o) => o is Census && o.n == n;
  @override
  int get hashCode => n.hashCode;
}

/// One census: what `objectsOf<Caption>()` answered twice and what
/// `objectsOf<Census>()` answered, in one view.
typedef Asked = ({
  List<Handle> captions,
  List<Handle> again,
  List<Handle> censuses,
});

final class CensusType extends ParametricType<Census> {
  CensusType();
  final List<Asked> fromDiagnose = [];
  final List<Asked> fromGenerate = [];

  static Asked _ask(ParametricView view) => (
        captions: view.objectsOf<Caption>(),
        again: view.objectsOf<Caption>(),
        censuses: view.objectsOf<Census>(),
      );

  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(Census params, Transform2 toWorld) => Aabb2.empty();
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    fromGenerate.add(_ask(view));
    return const [];
  }

  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) {
    fromDiagnose.add(_ask(view));
    return const [];
  }
}

void main() {
  test(
      'OB1 objectsOf lists exactly the live objects carrying a type, '
      'ascending: not a lost, a re-parented or a misplaced one', () {
    const h5100 = Handle(5100), h5200 = Handle(5200), h5300 = Handle(5300);
    const hG = Handle(6000), hN = Handle(6100), hC = Handle(7000);
    final census = CensusType();
    final cat = testCatalog()
      ..register<Census>(Census.id, Census.fromJson, census);
    final doc = DraftDocument.empty();
    final system = ParametricSystem(doc, cat)..install();

    // Created in the order 5300, 5100, 5200.
    final at5300 = onA(1500.25, -700.5, 0.3);
    doc.commands
        .execute(create(doc, h5300, at5300, const Caption('C', 30.5, 10.25)));
    doc.commands.execute(create(
        doc, h5100, onA(-900.75, 400.5, -0.2), const Caption('A', 5.25, 7.5)));
    doc.commands.execute(create(
        doc, h5200, onA(300.5, 1200.25, 0.6), const Caption('B', 15.75, 2.5)));
    // A plain root group, and a Caption on a group nested in it: misplaced,
    // never an object.
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: hG,
        parent: doc.rootHandle,
        transform: onA(-2500.5, -1800.25, 0.45),
        children: const [])));
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: hN,
          parent: hG,
          transform: Transform2.translation(120.5, -40.25),
          children: const [])),
      SetComponentCommand<Caption>(hN, const Caption('N', 1.5, 2.25)),
    ], label: 'Nested caption'));
    doc.commands.execute(create(doc, hC, parked, const Census(1)));
    // Premises: every Caption carries its component, the nested one too.
    expect(doc.components.withComponent<Caption>().toSet(),
        {h5100, h5200, h5300, hN});
    expect(doc.tree[hN]!.parent, hG);

    // From a client's diagnose.
    census.fromDiagnose.clear();
    system.diagnostics();
    final d = census.fromDiagnose.single;
    expect(d.captions, [h5100, h5200, h5300]);
    expect(identical(d.again, d.captions), isTrue,
        reason: 'memoised per view and type');
    expect(d.censuses, [hC]);
    expect(() => d.captions.add(hN), throwsUnsupportedError);

    // From a client's generate, in an edit that deletes 5200, re-parents
    // 5300 under the plain root group and seeds the census.
    census.fromGenerate.clear();
    doc.commands.execute(CompoundCommand([
      for (final k in kids(doc, h5200)) RemoveEntityCommand(k),
      RemoveNodeCommand(h5200),
      RemoveNodeCommand(h5300),
      AddNodeCommand(GroupNode(
          handle: h5300, parent: hG, transform: at5300, children: const [])),
      SetComponentCommand<Census>(hC, const Census(2)),
    ], label: 'Delete B, re-parent C'));
    final g = census.fromGenerate.single;
    expect(g.captions, [h5100]);
    expect(identical(g.again, g.captions), isTrue);
    expect(g.censuses, [hC]);
    expect(() => g.captions.add(h5200), throwsUnsupportedError);
    // Premises after the edit: 5200 is gone, 5300 and the nested group
    // still carry their Captions.
    expect(doc.tree[h5200], isNull);
    expect(doc.components.get<Caption>(h5200), isNull);
    expect(doc.components.get<Caption>(h5300), isNotNull);
    expect(doc.tree[h5300]!.parent, hG);
    expect(system.drift(), isEmpty);

    // A later view sees the same, and undo brings the three back.
    census.fromDiagnose.clear();
    system.diagnostics();
    expect(census.fromDiagnose.single.captions, [h5100]);
    doc.commands.undo();
    census.fromDiagnose.clear();
    system.diagnostics();
    expect(census.fromDiagnose.single.captions, [h5100, h5200, h5300]);
  });
}
