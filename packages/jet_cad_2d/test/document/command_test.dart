import 'dart:async';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

/// Minimal target: the stores a command may touch, and nothing else.
class FakeTarget implements CommandTarget {
  @override
  final EntityStore entities = EntityStore();
  @override
  final GeometryStore geometry = GeometryStore();
  @override
  final DocumentTables tables = DocumentTables.standard();
  @override
  final ComponentRegistry components = ComponentRegistry()..registerBuiltIns();
  @override
  final HandleSeed handleSeed = HandleSeed(ReservedHandles.firstFree);
  @override
  late final DocumentTree tree = DocumentTree(
    rootNode: GroupNode(
      handle: handleSeed.next(),
      parent: Handle.none,
      transform: Transform2.identity(),
      children: const [],
    ),
  );

  int invalidations = 0;
  @override
  void invalidateDerived() => invalidations++;
}

/// A command that only records that it ran, so the dispatcher can be tested
/// without depending on any concrete command.
class CounterCommand extends DraftCommand {
  static int applied = 0;

  final Capability _capability;
  final Handle target;

  CounterCommand(this._capability, this.target);

  @override
  Capability get capability => _capability;

  @override
  String get label => 'counter';

  @override
  CommandResult apply(CommandTarget t) {
    applied++;
    t.invalidateDerived();
    return CommandResult(
      inverse: CounterCommand(_capability, target),
      touched: {target},
    );
  }
}

class ThrowingCommand extends DraftCommand {
  @override
  Capability get capability => Capability.geometry;
  @override
  String get label => 'throwing';
  @override
  CommandResult apply(CommandTarget t) => throw StateError('boom');
}

/// Applies cleanly (so it lands on the undo stack via `execute`), but hands
/// back a [ThrowingCommand] as its inverse — so replaying it via `undo()`
/// throws.
class FlakyInverseCommand extends DraftCommand {
  @override
  Capability get capability => Capability.geometry;
  @override
  String get label => 'flaky-inverse';
  @override
  CommandResult apply(CommandTarget t) =>
      CommandResult(inverse: ThrowingCommand(), touched: const {});
}

/// Applies cleanly and its inverse ([FlakyUndoStep]) also applies cleanly,
/// but *that* inverse is a [ThrowingCommand] — so the entry only misbehaves
/// two levels deep: `undo()` succeeds, and it's the subsequent `redo()` that
/// throws.
class FlakyRedoCommand extends DraftCommand {
  @override
  Capability get capability => Capability.geometry;
  @override
  String get label => 'flaky-redo';
  @override
  CommandResult apply(CommandTarget t) =>
      CommandResult(inverse: FlakyUndoStep(), touched: const {});
}

class FlakyUndoStep extends DraftCommand {
  @override
  Capability get capability => Capability.geometry;
  @override
  String get label => 'flaky-undo-step';
  @override
  CommandResult apply(CommandTarget t) =>
      CommandResult(inverse: ThrowingCommand(), touched: const {});
}

void main() {
  setUp(() => CounterCommand.applied = 0);

  group('DraftPermissions', () {
    test('runtime allows transform and components, not geometry or structure',
        () {
      // Exactly the point-of-sale case: move a table, change its properties,
      // but never draw a wall or alter a block definition.
      const p = DraftPermissions.runtime;
      expect(p.allows(Capability.transform), isTrue);
      expect(p.allows(Capability.components), isTrue);
      expect(p.allows(Capability.geometry), isFalse);
      expect(p.allows(Capability.structure), isFalse);
    });

    test('all allows everything and readOnly allows nothing', () {
      for (final c in Capability.values) {
        expect(DraftPermissions.all.allows(c), isTrue);
        expect(DraftPermissions.readOnly.allows(c), isFalse);
      }
    });
  });

  group('CommandDispatcher', () {
    test('executes a permitted command and emits CommandApplied', () async {
      final target = FakeTarget();
      final dispatcher = CommandDispatcher(target: target);
      final events = <DocChange>[];
      final sub = dispatcher.changes.listen(events.add);

      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(42)));
      await Future<void>.delayed(Duration.zero);

      expect(CounterCommand.applied, 1);
      expect(events.single, isA<CommandApplied>());
      expect((events.single as CommandApplied).touched, {const Handle(42)});
      expect(target.invalidations, 1);
      unawaited(sub.cancel());
    });

    test('onAfterMutate fires synchronously, unlike the changes stream', () {
      final target = FakeTarget();
      final dispatcher = CommandDispatcher(target: target);
      final syncSeen = <DocChange>[];
      final asyncSeen = <DocChange>[];
      dispatcher.onAfterMutate = syncSeen.add;
      dispatcher.changes.listen(asyncSeen.add);

      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(1)));

      expect(syncSeen, hasLength(1),
          reason: 'the index must be current for the very next statement');
      expect(asyncSeen, isEmpty,
          reason: 'the stream is a broadcast controller');
    });

    test('rejects a command the permissions forbid, without applying it', () {
      final target = FakeTarget();
      final dispatcher = CommandDispatcher(
        target: target,
        permissions: DraftPermissions.runtime,
      );
      expect(
        () => dispatcher
            .execute(CounterCommand(Capability.geometry, const Handle(1))),
        throwsA(isA<PermissionDeniedError>()),
      );
      expect(CounterCommand.applied, 0);
      expect(dispatcher.canUndo, isFalse);
    });

    test('a throwing command does not land on the undo stack', () {
      final dispatcher = CommandDispatcher(target: FakeTarget());
      expect(() => dispatcher.execute(ThrowingCommand()), throwsStateError);
      expect(dispatcher.canUndo, isFalse);
    });

    test('undo and redo run the stored inverses and emit their events',
        () async {
      final dispatcher = CommandDispatcher(target: FakeTarget());
      final events = <DocChange>[];
      final sub = dispatcher.changes.listen(events.add);

      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(1)));
      expect(dispatcher.canUndo, isTrue);
      expect(dispatcher.canRedo, isFalse);

      dispatcher.undo();
      expect(dispatcher.canUndo, isFalse);
      expect(dispatcher.canRedo, isTrue);

      dispatcher.redo();
      expect(dispatcher.canUndo, isTrue);
      expect(CounterCommand.applied, 3, reason: 'apply, undo, redo each ran');

      await Future<void>.delayed(Duration.zero);
      expect(events.map((e) => e.runtimeType).toList(),
          [CommandApplied, CommandUndone, CommandRedone]);
      unawaited(sub.cancel());
    });

    test('a new command clears the redo stack', () {
      final dispatcher = CommandDispatcher(target: FakeTarget());
      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(1)));
      dispatcher.undo();
      expect(dispatcher.canRedo, isTrue);
      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(2)));
      expect(dispatcher.canRedo, isFalse);
    });

    test('undo respects permissions too', () {
      // Runtime undo must be able to reverse a runtime edit, and must not
      // become a back door to a forbidden one.
      final dispatcher = CommandDispatcher(target: FakeTarget());
      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(1)));
      dispatcher.permissions = DraftPermissions.runtime;
      expect(dispatcher.undo, throwsA(isA<PermissionDeniedError>()));
    });

    test('the undo stack honours its depth limit', () {
      // Runtime may cap the depth; the mechanism is unchanged.
      final dispatcher = CommandDispatcher(target: FakeTarget(), undoLimit: 2);
      for (var i = 0; i < 5; i++) {
        dispatcher.execute(CounterCommand(Capability.geometry, Handle(i + 1)));
      }
      var undone = 0;
      while (dispatcher.canUndo) {
        dispatcher.undo();
        undone++;
      }
      expect(undone, 2);
    });

    test('clearHistory drops both stacks', () {
      final dispatcher = CommandDispatcher(target: FakeTarget());
      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(1)));
      dispatcher.clearHistory();
      expect(dispatcher.canUndo, isFalse);
      expect(dispatcher.canRedo, isFalse);
    });

    test('notifyLoaded emits DocumentLoaded and clears history', () async {
      final dispatcher = CommandDispatcher(target: FakeTarget());
      final events = <DocChange>[];
      final sub = dispatcher.changes.listen(events.add);
      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(1)));
      dispatcher.notifyLoaded();
      await Future<void>.delayed(Duration.zero);
      expect(events.last, isA<DocumentLoaded>());
      expect(dispatcher.canUndo, isFalse);
      unawaited(sub.cancel());
    });

    test('notifyPurged emits DocumentPurged and clears history', () async {
      final dispatcher = CommandDispatcher(target: FakeTarget());
      final events = <DocChange>[];
      final sub = dispatcher.changes.listen(events.add);
      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(1)));
      dispatcher.notifyPurged();
      await Future<void>.delayed(Duration.zero);
      expect(events.last, isA<DocumentPurged>());
      expect(dispatcher.canUndo, isFalse);
      unawaited(sub.cancel());
    });

    test(
        'a denied undo does not strand the entry; it is still undoable once '
        'permission is restored', () {
      final dispatcher = CommandDispatcher(target: FakeTarget());
      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(1)));

      dispatcher.permissions = DraftPermissions.runtime; // denies geometry
      expect(dispatcher.undo, throwsA(isA<PermissionDeniedError>()));
      expect(dispatcher.canUndo, isTrue,
          reason: 'a denied undo must not discard the entry');

      dispatcher.permissions = DraftPermissions.all;
      dispatcher.undo(); // now succeeds against the same entry
      expect(dispatcher.canUndo, isFalse);
      expect(dispatcher.canRedo, isTrue);
    });

    test(
        'a denied redo does not strand the entry; it is still redoable once '
        'permission is restored', () {
      final dispatcher = CommandDispatcher(target: FakeTarget());
      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(1)));
      dispatcher.undo();
      expect(dispatcher.canRedo, isTrue);

      dispatcher.permissions = DraftPermissions.runtime; // denies geometry
      expect(dispatcher.redo, throwsA(isA<PermissionDeniedError>()));
      expect(dispatcher.canRedo, isTrue,
          reason: 'a denied redo must not discard the entry');

      dispatcher.permissions = DraftPermissions.all;
      dispatcher.redo(); // now succeeds against the same entry
      expect(dispatcher.canRedo, isFalse);
      expect(dispatcher.canUndo, isTrue);
    });

    test(
        'an inverse whose apply throws during undo does not strand the '
        'entry', () {
      // This is the FIX 1 path: DraftCommand.apply's contract says a command
      // "must either complete fully or leave the target unmutated", so a
      // throwing inverse means nothing was mutated and the popped entry is
      // still valid to retry.
      final dispatcher = CommandDispatcher(target: FakeTarget());
      dispatcher.execute(FlakyInverseCommand());
      expect(dispatcher.canUndo, isTrue);

      expect(dispatcher.undo, throwsStateError);
      expect(dispatcher.canUndo, isTrue,
          reason: 'a throwing inverse must not strand the entry');
      // Still there to retry (and still throws, since the inverse itself is
      // unconditionally broken — "retryable" means not silently lost, not
      // that a retry must succeed).
      expect(dispatcher.undo, throwsStateError);
    });

    test(
        'an inverse whose apply throws during redo does not strand the '
        'entry', () {
      // Symmetric case for the redo() half of the FIX 1 path.
      final dispatcher = CommandDispatcher(target: FakeTarget());
      dispatcher.execute(FlakyRedoCommand());
      dispatcher.undo();
      expect(dispatcher.canRedo, isTrue);

      expect(dispatcher.redo, throwsStateError);
      expect(dispatcher.canRedo, isTrue,
          reason: 'a throwing inverse must not strand the entry');
      expect(dispatcher.redo, throwsStateError);
    });

    test('redo does not exhaust early when more than one redo is pending', () {
      // The brief's own warning: redo() uses pushUndoOnly rather than push
      // precisely because push clears the redo stack. With two undone
      // commands, the redo stack holds two entries; if redo() used push, the
      // first redo() would wipe the second pending entry as a side effect,
      // and a second redo() would silently no-op instead of succeeding.
      final dispatcher = CommandDispatcher(target: FakeTarget());
      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(1)));
      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(2)));
      dispatcher.undo();
      dispatcher.undo();
      expect(dispatcher.canRedo, isTrue);

      dispatcher.redo();
      expect(dispatcher.canRedo, isTrue,
          reason: 'a second redo must still be pending after the first');
      final appliedBeforeSecondRedo = CounterCommand.applied;
      dispatcher.redo();
      expect(CounterCommand.applied, appliedBeforeSecondRedo + 1,
          reason: 'the second redo must actually run, not no-op');
      expect(dispatcher.canRedo, isFalse);
      expect(dispatcher.canUndo, isTrue);
    });

    test('execute after dispose throws and does not mutate the target',
        () async {
      final target = FakeTarget();
      final dispatcher = CommandDispatcher(target: target);
      await dispatcher.dispose();

      expect(
        () => dispatcher
            .execute(CounterCommand(Capability.geometry, const Handle(1))),
        throwsStateError,
      );
      expect(CounterCommand.applied, 0);
      expect(target.invalidations, 0);
    });

    test('undo after dispose throws without mutating the target', () async {
      final target = FakeTarget();
      final dispatcher = CommandDispatcher(target: target);
      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(1)));
      final appliedBeforeDispose = CounterCommand.applied;
      await dispatcher.dispose();

      expect(dispatcher.undo, throwsStateError);
      expect(CounterCommand.applied, appliedBeforeDispose);
    });
  });
}
