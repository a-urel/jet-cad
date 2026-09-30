import 'dart:math';
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

// Spec 12a D3: the dispatcher numbers the states it moves between. Every
// fixture is a real DraftDocument whose two lines sit well off the origin,
// and every edit writes coordinates no earlier edit wrote, so two states have
// equal content exactly when they are the same state.

GeometryPayload line(double x1, double y1, double x2, double y2) =>
    GeometryPayload(
      coords: Float64List.fromList([x1, y1, x2, y2]),
      scalars: Float64List(0),
    );

EntityRecord lineRecord(Handle handle, Handle owner) => EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    );

class Fixture {
  Fixture({int undoLimit = 200})
      : doc = DraftDocument.empty(undoLimit: undoLimit) {
    a = doc.handleSeed.next();
    b = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(a, doc.rootHandle),
      payload: line(1250.5, -730.25, 1810.0, -415.75),
    ));
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(b, doc.rootHandle),
      payload: line(-2230.0, 940.5, -1675.25, 1320.0),
    ));
    // The fixture's own additions are not undo steps of the tests.
    doc.commands.clearHistory();
  }

  final DraftDocument doc;
  late final Handle a;
  late final Handle b;
  int _edits = 0;

  CommandDispatcher get commands => doc.commands;
  int get id => doc.commands.stateId;

  /// Rewrites [handle]'s line to coordinates no earlier edit wrote.
  void edit(Handle handle) {
    final x = 3170.25 + 97.5 * ++_edits;
    commands.execute(SetEntityGeometryCommand(
      handle,
      line(x, -0.5 * x - 611.0, x + 410.75, 0.25 * x + 175.5),
    ));
  }

  List<double> _coords(Handle handle) {
    final slot = doc.entities.slotOf(handle)!;
    return doc.geometry.read(doc.entities.geomIndexAt(slot)).coords;
  }

  /// Both lines' coordinates: what the document holds, independent of ids.
  String get content => '${_coords(a)} ${_coords(b)}';
}

void main() {
  test('execute, undo and redo move the id and return it exactly', () {
    final f = Fixture();
    final s0 = f.id;
    final c0 = f.content;
    f.edit(f.a);
    final s1 = f.id;
    final c1 = f.content;
    f.edit(f.b);
    final s2 = f.id;
    final c2 = f.content;
    expect({s0, s1, s2}, hasLength(3), reason: 'every edit leaves a new id');

    f.commands.undo();
    expect(f.id, s1);
    expect(f.content, c1);
    f.commands.undo();
    expect(f.id, s0);
    expect(f.content, c0);
    // A redo records a new inverse object; the id must still be the one the
    // state had before it was undone.
    f.commands.redo();
    expect(f.id, s1);
    expect(f.content, c1);
    f.commands.redo();
    expect(f.id, s2);
    expect(f.content, c2);

    // A second round over entries a redo re-recorded.
    f.commands.undo();
    expect(f.id, s1);
    f.commands.undo();
    expect(f.id, s0);
    f.commands.redo();
    expect(f.id, s1);
    f.commands.redo();
    expect(f.id, s2);
    expect(f.content, c2);
  });

  test('an edit then an undo reads the pre-edit id', () {
    final f = Fixture();
    f.edit(f.b);
    final before = f.id;
    final contentBefore = f.content;
    f.edit(f.a);
    expect(f.id, isNot(before));
    f.commands.undo();
    expect(f.id, before);
    expect(f.content, contentBefore);
  });

  test('an edit after an undo never returns to the undone id', () {
    final f = Fixture();
    final s0 = f.id;
    f.edit(f.a);
    final s1 = f.id;
    f.commands.undo();
    expect(f.id, s0);

    f.edit(f.a);
    final s2 = f.id;
    expect(f.commands.canRedo, isFalse);
    expect(s2, isNot(s1), reason: 'the undone state is gone for good');
    expect(s2, isNot(s0));
    f.commands.undo();
    expect(f.id, s0);
  });

  test(
      'a long walk: every edit leaves a fresh id, and two ids are equal '
      'exactly when the content is', () {
    // A differential check against the document itself rather than a second
    // model of the stack: the id is right when it identifies the content.
    final f = Fixture(undoLimit: 7);
    final random = Random(0x12a);
    final initial = f.id;
    final seen = <int>{initial};
    final contentById = <int, String>{f.id: f.content};
    final idByContent = <String, int>{f.content: f.id};
    var edits = 0, undos = 0, redos = 0, failures = 0, bottoms = 0;

    for (var step = 0; step < 600; step++) {
      final roll = random.nextInt(20);
      if (roll < 7) {
        f.edit(random.nextBool() ? f.a : f.b);
        expect(seen, isNot(contains(f.id)),
            reason: 'step $step: an edit reused an id');
        edits++;
      } else if (roll < 14) {
        if (!f.commands.canUndo) {
          // A bottom other than the initial state means eviction ran.
          if (f.id != initial) bottoms++;
          continue;
        }
        f.commands.undo();
        undos++;
      } else if (roll < 18) {
        if (!f.commands.canRedo) continue;
        f.commands.redo();
        redos++;
      } else {
        // A denied undo or redo changes nothing, the id included.
        final undo = roll == 18;
        if (undo ? !f.commands.canUndo : !f.commands.canRedo) continue;
        final before = f.id;
        f.commands.permissions = DraftPermissions.readOnly;
        expect(undo ? f.commands.undo : f.commands.redo,
            throwsA(isA<PermissionDeniedError>()));
        f.commands.permissions = DraftPermissions.all;
        expect(f.id, before, reason: 'step $step: a failed replay moved it');
        failures++;
      }
      final id = f.id;
      final content = f.content;
      seen.add(id);
      expect(contentById.putIfAbsent(id, () => content), content,
          reason: 'step $step: one id, two contents');
      expect(idByContent.putIfAbsent(content, () => id), id,
          reason: 'step $step: one content, two ids');
    }

    // The walk is only worth something if it went everywhere.
    expect(edits, greaterThan(100));
    expect(undos, greaterThan(50));
    expect(redos, greaterThan(20));
    expect(failures, greaterThan(20));
    expect(bottoms, greaterThan(0), reason: 'undo reached an evicted bottom');
    expect(seen.length, edits + 1);
  });

  test('eviction at undoLimit: 3 never returns to an evicted state', () {
    final f = Fixture(undoLimit: 3);
    final ids = <int>[f.id];
    final contents = <String>[f.content];
    for (var i = 0; i < 5; i++) {
      f.edit(i.isEven ? f.a : f.b);
      ids.add(f.id);
      contents.add(f.content);
    }
    expect(ids.toSet(), hasLength(6), reason: 'every edit leaves a new id');
    expect(f.commands.undoDepth, 3);

    f.commands.undo();
    f.commands.undo();
    f.commands.undo();
    expect(f.commands.canUndo, isFalse);
    // Edits 1 and 2 were evicted: states 0 and 1 are gone, the bottom is the
    // state after edit 2.
    expect(f.id, ids[2]);
    expect(f.content, contents[2]);
    expect(f.id, isNot(ids[0]));
    expect(f.id, isNot(ids[1]));

    f.commands.redo();
    f.commands.redo();
    f.commands.redo();
    expect(f.id, ids[5]);
    expect(f.content, contents[5]);

    f.commands.undo();
    f.commands.undo();
    f.commands.undo();
    f.edit(f.a);
    expect(ids, isNot(contains(f.id)),
        reason: 'an edit at the bottom is a new state, not an evicted one');
  });

  test('a failed undo, then a successful one, lands on the pre-edit id', () {
    final f = Fixture();
    f.edit(f.b);
    final a = f.id;
    final contentA = f.content;
    f.edit(f.a);
    final b = f.id;
    final contentB = f.content;

    f.commands.permissions = DraftPermissions.readOnly;
    expect(f.commands.undo, throwsA(isA<PermissionDeniedError>()));
    expect(f.id, b);
    expect(f.content, contentB);
    expect(f.commands.canUndo, isTrue);
    expect(f.commands.canRedo, isFalse);

    f.commands.permissions = DraftPermissions.all;
    f.commands.undo();
    expect(f.id, a);
    expect(f.content, contentA);
    f.commands.redo();
    expect(f.id, b);
  });

  test('a failed redo, then a successful one, lands on the redone id', () {
    final f = Fixture();
    f.edit(f.b);
    final a = f.id;
    final contentA = f.content;
    f.edit(f.a);
    final b = f.id;
    final contentB = f.content;
    f.commands.undo();
    expect(f.id, a);

    f.commands.permissions = DraftPermissions.readOnly;
    expect(f.commands.redo, throwsA(isA<PermissionDeniedError>()));
    expect(f.id, a);
    expect(f.content, contentA);
    expect(f.commands.canRedo, isTrue);

    f.commands.permissions = DraftPermissions.all;
    f.commands.redo();
    expect(f.id, b);
    expect(f.content, contentB);
    f.commands.undo();
    expect(f.id, a);
  });

  group('clearing history keeps the id', () {
    for (final (name, clear) in <(String, void Function(DraftDocument))>[
      ('clearHistory', (doc) => doc.commands.clearHistory()),
      ('notifyLoaded', (doc) => doc.commands.notifyLoaded()),
      ('notifyPurged, through DraftDocument.purge', (doc) => doc.purge()),
    ]) {
      test(name, () {
        final f = Fixture();
        final seen = <int>{f.id};
        f.edit(f.a);
        seen.add(f.id);
        f.edit(f.b);
        seen.add(f.id);
        f.edit(f.a);
        seen.add(f.id);
        f.commands.undo();
        final kept = f.id;
        final content = f.content;
        expect(f.commands.canRedo, isTrue);

        clear(f.doc);
        expect(f.id, kept);
        expect(f.content, content);
        expect(f.commands.canUndo, isFalse);
        expect(f.commands.canRedo, isFalse);

        f.edit(f.b);
        expect(seen, isNot(contains(f.id)),
            reason: 'an edit after a clear is still a new state');
        f.commands.undo();
        expect(f.id, kept);
      });
    }
  });

  test("a new dispatcher's first edit leaves its initial id", () {
    // No Fixture: its own adds and clearHistory move the id before any other
    // case reads it, so the id a dispatcher is born with is observed only
    // here. A first edit that reused it would read as "no change" to anyone
    // holding the initial id as a save point.
    final doc = DraftDocument.empty();
    final initial = doc.commands.stateId;
    final handle = doc.handleSeed.next();
    expect(doc.entities.slotOf(handle), isNull);

    doc.commands.execute(AddEntityCommand(
      record: lineRecord(handle, doc.rootHandle),
      payload: line(1250.5, -730.25, 1810.0, -415.75),
    ));
    final edited = doc.commands.stateId;
    List<double> coords() => doc.geometry
        .read(doc.entities.geomIndexAt(doc.entities.slotOf(handle)!))
        .coords;
    expect(edited, isNot(initial), reason: 'the first edit is a new state');
    expect(coords(), [1250.5, -730.25, 1810.0, -415.75]);

    doc.commands.undo();
    expect(doc.commands.stateId, initial);
    expect(doc.entities.slotOf(handle), isNull);
    expect(doc.commands.canUndo, isFalse);

    doc.commands.redo();
    expect(doc.commands.stateId, edited);
    expect(coords(), [1250.5, -730.25, 1810.0, -415.75]);
  });
}
