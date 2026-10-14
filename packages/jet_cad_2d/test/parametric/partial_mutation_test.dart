// Spec 2a E3: every failed rollback throws PartialMutationError, a
// StateError carrying the message it always had. Each case makes one
// rollback throw on purpose. [_TripTarget] is the document as a command
// target whose invalidateDerived throws once a set number of further calls
// have passed: every command calls it exactly once, after it has mutated.
// [_Arm] sets that number right after the triggering edit applies, so the
// surveys and the edit run as usual up to the chosen command. A
// ParametricEdit is applied to the tripping target directly, as
// regeneration_test's P9 applies one.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

final class _Tripped implements Exception {
  const _Tripped();
  @override
  String toString() => 'tripped';
}

/// [doc] as a command target whose [invalidateDerived] throws once
/// [allowed] further calls have passed; null never trips.
final class _TripTarget implements CommandTarget {
  _TripTarget(this.doc);

  final DraftDocument doc;
  int? allowed;

  @override
  EntityStore get entities => doc.entities;
  @override
  GeometryStore get geometry => doc.geometry;
  @override
  DocumentTree get tree => doc.tree;
  @override
  DocumentTables get tables => doc.tables;
  @override
  ComponentRegistry get components => doc.components;
  @override
  HandleSeed get handleSeed => doc.handleSeed;
  @override
  DocumentHeader get header => doc.header;
  @override
  FillIndex get fills => doc.fills;

  @override
  void invalidateDerived() {
    doc.invalidateDerived();
    final left = allowed;
    if (left == null) return;
    if (left == 0) throw const _Tripped();
    allowed = left - 1;
  }
}

/// [inner], then [target] armed to trip after [allow] further calls. Its
/// inverse is [inner]'s, so undoing it calls invalidateDerived once.
final class _Arm extends DraftCommand {
  _Arm(this.inner, this.target, this.allow);

  final DraftCommand inner;
  final _TripTarget target;
  final int allow;

  @override
  Capability get capability => inner.capability;
  @override
  Set<Capability> get capabilities => inner.capabilities;
  @override
  String get label => 'Armed edit';

  @override
  CommandResult apply(CommandTarget t) {
    final result = inner.apply(t);
    target.allowed = allow;
    return result;
  }
}

const Handle hPin = Handle(3000);
final Transform2 pinAt =
    Transform2.translation(8400, 1900).multiply(Transform2.rotation(-1.05));

/// A [PartialMutationError] from the site whose message contains [site].
Matcher partial(String site) => throwsA(isA<PartialMutationError>()
    .having((e) => e.message, 'message', contains(site))
    .having((e) => e.message, 'message', contains('partially mutated')));

/// The select tool's delete of one object: its children, then its node.
DraftCommand deleteObject(DraftDocument doc, Handle g) => CompoundCommand([
      for (final k in kids(doc, g)) RemoveEntityCommand(k),
      RemoveNodeCommand(g),
    ], label: 'Delete');

void main() {
  test('E3-compound a compound whose rollback throws', () {
    final doc = DraftDocument.empty();
    final trip = _TripTarget(doc)..allowed = 1;
    final first = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(7010.5, 3020.25), Vector2(7133.1, 3071.9)),
        layer: ReservedHandles.layerZero);
    final second = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(-410.75, 8800.5), Vector2(-388.25, 9012)),
        layer: ReservedHandles.layerZero);
    // M-E3a: CompoundCommand.apply throws a plain StateError.
    expect(
        () => CompoundCommand([first, second], label: 'Two lines').apply(trip),
        partial('child 1 threw'));
  });

  test('E3-undo a parametric edit whose undo of the edit throws', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, parked, const ClipRect(2000, 1000)));
    final trip = _TripTarget(doc);
    // allow 0: the first regeneration command trips, then the undo of the
    // edit trips too.
    final edit = doc.commands.expander!(_Arm(
        SetComponentCommand<ClipRect>(hA, const ClipRect(3100, 450)), trip, 0));
    // M-E3b: _undoInner throws a plain StateError.
    expect(() => edit.apply(trip), partial('undoing the edit then threw'));
  });

  test('E3-cascade a parametric edit whose reference cascade rollback throws',
      () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, const Post(2000, 1000)));
    doc.commands.execute(create(doc, hPin, pinAt, const Pin(hA, 450)));
    expect(kids(doc, hPin), hasLength(1),
        reason: "fixture: the pin copies A's bottom edge, so the cascade "
            'removes a child and then the node');
    final trip = _TripTarget(doc);
    // allow 1: the cascade's first removal lands, its second trips, and the
    // rollback of the first trips.
    final edit = doc.commands.expander!(_Arm(deleteObject(doc, hA), trip, 1));
    // M-E3c: _cascade's rollback throws a plain StateError.
    expect(() => edit.apply(trip), partial('the reference cascade threw'));
  });

  test('E3-regeneration a parametric edit whose regeneration rollback throws',
      () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, parked, const ClipRect(2000, 1000)));
    expect(kids(doc, hA), hasLength(4),
        reason: 'fixture: all four edges change, so the plan has four '
            'commands');
    final trip = _TripTarget(doc);
    // allow 1: the first regeneration command lands, the second trips, and
    // the rollback of the first trips.
    final edit = doc.commands.expander!(_Arm(
        SetComponentCommand<ClipRect>(hA, const ClipRect(3100, 450)), trip, 1));
    // M-E3d: _run's apply loop throws a plain StateError.
    expect(() => edit.apply(trip), partial('regeneration threw'));
  });
}
