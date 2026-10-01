// Spec 06 D5, as amended by fix/post-11 (post-11 found item (d)): an edit
// that writes a registered parametric component on a handle that is not a
// live root-level group after the edit is refused, the whole edit undone and
// nothing recorded. A component the edit did not write (a delete, a
// re-parent, a file's misplaced one) and a detach are never refused.
//
// The type written is `Hinge`, not the catalog's first registration. Every
// group sits rotated and off the origin, next to two live ClipRects.
import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

/// A component that is not parametric: registered in the document's
/// registry only, never in a catalog.
final class Note implements Component {
  const Note(this.n);
  static const String id = 'test.mp.note';
  final int n;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'n': n};
  static Note fromJson(Map<String, Object?> j) => Note(j['n']! as int);
  @override
  bool operator ==(Object o) => o is Note && o.n == n;
  @override
  int get hashCode => n.hashCode;
}

/// The select tool's delete cascade for one group.
DraftCommand deleteObject(DraftDocument doc, Handle g) => CompoundCommand([
      for (final k in kids(doc, g)) RemoveEntityCommand(k),
      RemoveNodeCommand(g),
    ], label: 'Delete');

/// A group node at [at] under [parent].
DraftCommand addGroup(Handle h, Handle parent, Transform2 at) => AddNodeCommand(
    GroupNode(handle: h, parent: parent, transform: at, children: const []));

/// The handles of [scene]'s holders.
final class Scene {
  Scene(this.doc, this.outer, this.nested, this.dead, this.line, this.never);
  final DraftDocument doc;

  /// A plain root-level group (no component), holding [nested].
  final Handle outer;

  /// A group whose parent is [outer]: live, not root-level.
  final Handle nested;

  /// A root-level group that was added and then removed.
  final Handle dead;

  /// A plain line owned by the root.
  final Handle line;

  /// Above the handle seed: never allocated.
  final Handle never;
}

/// A and B (ClipRect, overlapping), then [Scene]'s holders, all through
/// the dispatcher with the system installed.
Scene scene() {
  final doc = paramDoc();
  pair(doc);
  final outer = doc.handleSeed.next();
  doc.commands.execute(addGroup(outer, doc.rootHandle,
      Transform2.translation(-4200, 9100).multiply(Transform2.rotation(1.1))));
  final nested = doc.handleSeed.next();
  doc.commands.execute(addGroup(nested, outer,
      Transform2.translation(130, -45).multiply(Transform2.rotation(-0.35))));
  final dead = doc.handleSeed.next();
  doc.commands.execute(addGroup(dead, doc.rootHandle, onA(-900, 400, 0.8)));
  doc.commands.execute(RemoveNodeCommand(dead));
  final add = addDrafted(doc, EntityKind.line,
      linePayload(Vector2(7010.5, 3020.25), Vector2(7133.1, 3071.9)),
      layer: ReservedHandles.layerZero);
  doc.commands.execute(add);
  final never = Handle(doc.handleSeed.current.value + 77);
  return Scene(doc, outer, nested, dead, add.record.handle, never);
}

/// [s]'s document as a file would bring it in: a `Hinge` written straight
/// into the store on [s.dead], [s.nested] and [s.line], without an edit,
/// then saved and loaded.
DraftDocument fileWithMisplaced(Scene s) {
  for (final h in [s.dead, s.nested, s.line]) {
    s.doc.components.attach<Hinge>(h, const Hinge(true));
  }
  return reload(enc(s.doc));
}

/// [canon] without `handleSeed`, which never moves backward: an undo of
/// an edit whose regeneration added children restores everything else.
String noSeed(DraftDocument d) {
  final j = jsonDecode(canon(d, sortNodes: true)) as Map<String, Object?>;
  j.remove('handleSeed');
  return jsonEncode(j);
}

Matcher refusedAt(Handle h) => throwsA(isA<StateError>().having(
    (e) => e.message,
    'message',
    allOf(contains(Hinge.id), contains(h.toHex()),
        contains('not a live root-level group'))));

void main() {
  test(
      'MP1 a Hinge written on a deleted group, a never-allocated handle or '
      'a nested group is refused: bytes, store and history unchanged', () {
    final s = scene();
    final doc = s.doc;
    for (final h in [s.dead, s.never, s.nested]) {
      final before = enc(doc);
      final depth = doc.commands.undoDepth;
      expect(
          () => doc.commands
              .execute(SetComponentCommand<Hinge>(h, const Hinge(true))),
          refusedAt(h),
          reason: h.toHex());
      expect(enc(doc), before, reason: h.toHex());
      expect(doc.commands.undoDepth, depth, reason: h.toHex());
      expect(doc.components.get<Hinge>(h), isNull, reason: h.toHex());
    }
    expect(doc.components.withComponent<Hinge>(), isEmpty);
    expect(ParametricSystem(doc, catalog).diagnostics(), isEmpty);
  });

  test(
      'MP2 control: a Hinge written on a live root-level group is an object: '
      'generated, undoable', () {
    final s = scene();
    final doc = s.doc;
    final before = noSeed(doc);
    final depth = doc.commands.undoDepth;
    doc.commands
        .execute(SetComponentCommand<Hinge>(s.outer, const Hinge(true)));
    expect(doc.commands.undoDepth, depth + 1);
    expect(doc.components.get<Hinge>(s.outer), const Hinge(true));
    expect(kids(doc, s.outer), hasLength(2), reason: 'a LINE and an ARC');
    expect(ParametricSystem(doc, catalog).drift(), isEmpty);
    doc.commands.undo();
    expect(noSeed(doc), before);
    expect(doc.components.get<Hinge>(s.outer), isNull);
  });

  test(
      'MP3 a compound whose legal child edits A and whose other child writes '
      'a Hinge on a nested group is refused whole', () {
    final s = scene();
    final doc = s.doc;
    final before = enc(doc);
    final depth = doc.commands.undoDepth;
    expect(
        () => doc.commands.execute(CompoundCommand([
              SetComponentCommand<ClipRect>(hA, const ClipRect(2600, 1400)),
              SetComponentCommand<Hinge>(s.nested, const Hinge(true)),
            ], label: 'Both')),
        refusedAt(s.nested));
    expect(doc.components.get<ClipRect>(hA), const ClipRect(2000, 1000));
    expect(doc.components.get<Hinge>(s.nested), isNull);
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, depth);
  });

  test(
      'MP4 a file\'s misplaced Hinge on a deleted group and on a nested '
      'group can be detached: never refused, undoable', () {
    final s = scene();
    final doc = fileWithMisplaced(s);
    expect(
        ParametricSystem(doc, catalog)
            .diagnostics()
            .map((d) => (d.code, d.handles.single)),
        containsAll([
          ('parametric.misplaced', s.dead),
          ('parametric.misplaced', s.nested),
        ]));
    for (final h in [s.dead, s.nested]) {
      final before = enc(doc);
      final depth = doc.commands.undoDepth;
      doc.commands.execute(SetComponentCommand<Hinge>(h, null));
      expect(doc.components.get<Hinge>(h), isNull, reason: h.toHex());
      expect(doc.commands.undoDepth, depth + 1, reason: h.toHex());
      doc.commands.undo();
      expect(enc(doc), before, reason: h.toHex());
      doc.commands.redo();
      expect(doc.components.get<Hinge>(h), isNull, reason: h.toHex());
    }
  });

  test(
      'MP5 a live Hinge object across A\'s top edge: delete, undo, redo, '
      'undo all replay', () {
    final s = scene();
    final doc = s.doc;
    final g = doc.handleSeed.next();
    doc.commands.execute(CompoundCommand([
      addGroup(g, doc.rootHandle, onA(1000, 950, 0.2)),
      SetComponentCommand<Hinge>(g, const Hinge(true)),
    ], label: 'Add hinge'));
    expect(kids(doc, g), hasLength(2));
    final live = canon(doc, sortNodes: true);
    doc.commands.execute(deleteObject(doc, g));
    expect(doc.tree[g], isNull);
    expect(doc.components.get<Hinge>(g), isNull, reason: '06 D8 cleanup');
    final deleted = canon(doc, sortNodes: true);
    doc.commands.undo();
    expect(canon(doc, sortNodes: true), live);
    expect(doc.components.get<Hinge>(g), const Hinge(true));
    doc.commands.redo();
    expect(canon(doc, sortNodes: true), deleted);
    doc.commands.undo();
    expect(canon(doc, sortNodes: true), live);
    expect(kids(doc, g), hasLength(2));
  });

  test(
      'MP6 a file\'s misplaced Hinges refuse no edit that leaves them as '
      'they are: an unrelated move, a move of their line, re-writing the '
      'equal value, removing their nested group; writing a new value is '
      'refused', () {
    final s = scene();
    final doc = fileWithMisplaced(s);
    var depth = doc.commands.undoDepth;

    doc.commands.execute(TransformNodeCommand(hA, parked));
    expect(doc.commands.undoDepth, ++depth);

    doc.commands.execute(SetEntityGeometryCommand(
        s.line, linePayload(Vector2(7020.5, 3010.75), Vector2(7101.3, 3120))));
    expect(doc.commands.undoDepth, ++depth);
    expect(doc.components.get<Hinge>(s.line), const Hinge(true));

    // A loaded Hinge is not the const instance: the comparison is `==`.
    expect(identical(doc.components.get<Hinge>(s.line), const Hinge(true)),
        isFalse);
    doc.commands.execute(SetComponentCommand<Hinge>(s.line, const Hinge(true)));
    expect(doc.commands.undoDepth, ++depth);

    doc.commands.execute(RemoveNodeCommand(s.nested));
    expect(doc.commands.undoDepth, ++depth);
    expect(doc.components.get<Hinge>(s.nested), const Hinge(true),
        reason: 'Ruling 06-3: a misplaced component survives a delete');

    final before = enc(doc);
    expect(
        () => doc.commands
            .execute(SetComponentCommand<Hinge>(s.line, const Hinge(false))),
        refusedAt(s.line));
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, depth);
  });

  test(
      'MP7 a non-parametric component on a deleted group lands as before, '
      'inside a wrapped edit', () {
    final s = scene();
    final doc = s.doc;
    doc.components.register<Note>(Note.id, Note.fromJson);
    final before = enc(doc);
    final depth = doc.commands.undoDepth;
    doc.commands.execute(SetComponentCommand<Note>(s.dead, const Note(3)));
    expect(doc.components.get<Note>(s.dead), const Note(3));
    expect(doc.commands.undoDepth, depth + 1);
    doc.commands.undo();
    expect(enc(doc), before);
  });

  test(
      'MP8 a Hinge written on live object B in the same compound that '
      'deletes B: refused, B still live with its ClipRect', () {
    final s = scene();
    final doc = s.doc;
    // The refused delete's undo re-links B at the root's end (a
    // `RemoveNodeCommand` inverse): draw order is the handle, so the
    // child lists are compared sorted.
    final before = canon(doc, sortNodes: true);
    final depth = doc.commands.undoDepth;
    expect(
        () => doc.commands.execute(CompoundCommand([
              deleteObject(doc, hB),
              SetComponentCommand<Hinge>(hB, const Hinge(true)),
            ], label: 'Delete and write')),
        refusedAt(hB));
    expect(doc.tree[hB], isA<GroupNode>());
    expect(doc.components.get<ClipRect>(hB), const ClipRect(400, 900));
    expect(doc.components.get<Hinge>(hB), isNull);
    expect(canon(doc, sortNodes: true), before);
    expect(doc.commands.undoDepth, depth);
  });

  test(
      'MP9 an object carrying two registered types (ClipRect registered '
      'before Hinge) can be deleted and undone: neither component is '
      'written by the delete', () {
    final s = scene();
    final doc = s.doc;
    doc.commands.execute(SetComponentCommand<Hinge>(hA, const Hinge(false)));
    expect(doc.components.get<ClipRect>(hA), const ClipRect(2000, 1000));
    final live = noSeed(doc);
    final depth = doc.commands.undoDepth;
    doc.commands.execute(deleteObject(doc, hA));
    expect(doc.tree[hA], isNull);
    expect(doc.commands.undoDepth, depth + 1);
    doc.commands.undo();
    expect(noSeed(doc), live);
  });
}
