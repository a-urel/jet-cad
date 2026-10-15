// Spec 3a C1.5: the kit asks "is this a live T" of the plan's services,
// never of a catalog of its own. Two test types in a catalog of their own,
// groups far off the origin and turned by 0.3 + 0.7k rad, one of them
// frozen.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/src/live.dart';

final class Peg implements Component {
  const Peg();

  static const String id = 'architecture.peg';

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() => const {};

  static Peg fromJson(Map<String, Object?> json) => const Peg();
}

final class Pin implements Component {
  const Pin();

  static const String id = 'architecture.pin';

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() => const {};

  static Pin fromJson(Map<String, Object?> json) => const Pin();
}

/// A type that draws nothing: only the naming rule is under test.
final class Inert<T extends Component> extends ParametricType<T> {
  const Inert();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(T params, Transform2 toWorld) => Aabb2.empty();

  @override
  List<Generated> generate(ParametricView view, Handle self) => const [];
}

Handle add<T extends Component>(DraftDocument doc, int h, T value, double k) {
  final handle = Handle(h);
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: handle,
        parent: doc.rootHandle,
        transform: Transform2.translation(4500000 + 311.5 * k, -173.25 * k)
            .multiply(Transform2.rotation(0.3 + 0.7 * k)),
        children: const [])),
    SetComponentCommand<T>(handle, value),
  ], label: 'Add'));
  return handle;
}

void main() {
  test(
      'SC-live liveTypesOf answers the services\' live type id; isLiveOf and '
      'liveObjectsOf read it: a frozen object is in neither, while the '
      'catalog still names it', () {
    final doc = DraftDocument.empty();
    addTearDown(doc.dispose);
    final catalog = ParametricCatalog()
      ..register<Peg>(Peg.id, Peg.fromJson, const Inert<Peg>())
      ..register<Pin>(Pin.id, Pin.fromJson, const Inert<Pin>());
    catalog.registerComponents(doc.components);
    final frozen = add(doc, 4050, const Peg(), 1);
    final a = add(doc, 4100, const Peg(), 2);
    final b = add(doc, 4200, const Pin(), 3);
    final c = add(doc, 4300, const Peg(), 4);
    final services =
        FakePlanServices(document: doc, catalog: catalog, frozen: {frozen});
    addTearDown(services.dispose);
    expect(catalog.typeIdOf(doc, frozen), Peg.id,
        reason: 'premise: the catalog names a frozen object');

    final live = liveTypesOf(services);
    // M-SC-live-3: liveTypesOf answering null for everything.
    expect(live(a), Peg.id);
    expect(live(b), Pin.id);
    expect(live(frozen), isNull);
    expect(live(doc.rootHandle), isNull);
    // M-SC-live-2: isLiveOf asking only "is it live".
    expect(isLiveOf(live, a, Peg.id), isTrue);
    expect(isLiveOf(live, b, Peg.id), isFalse);
    expect(isLiveOf(live, frozen, Peg.id), isFalse);
    // M-SC-live-1: liveObjectsOf without its filter.
    expect(liveObjectsOf<Peg>(doc, live, Peg.id), [a, c]);
    expect(liveObjectsOf<Pin>(doc, live, Pin.id), [b]);
  });
}
