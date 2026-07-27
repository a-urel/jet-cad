import 'dart:async';

import 'command.dart';
import 'doc_change.dart';

/// Bounded undo and redo stacks.
///
/// The depth limit exists because a runtime viewer wants recoverable edits
/// without an unbounded history; the mechanism is identical to the designer's.
class UndoStack {
  final int limit;
  final List<DraftCommand> _undo = [];
  final List<DraftCommand> _redo = [];

  UndoStack({this.limit = 200});

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get undoDepth => _undo.length;

  /// Records a newly applied command's inverse. Clears the redo stack: once a
  /// fresh edit lands, the previously-undone future is no longer reachable.
  void push(DraftCommand inverse) {
    _undo.add(inverse);
    if (_undo.length > limit) _undo.removeAt(0);
    _redo.clear();
  }

  DraftCommand takeUndo() => _undo.removeLast();

  void pushRedo(DraftCommand inverse) => _redo.add(inverse);

  DraftCommand takeRedo() => _redo.removeLast();

  /// Records a redo's inverse back onto the undo stack, without touching the
  /// redo stack the way [push] would. `redo` uses this — `push` would clear
  /// the very redo stack `redo` is in the middle of replaying, which would
  /// make a second `redo()` in a row a no-op.
  void pushUndoOnly(DraftCommand inverse) => _undo.add(inverse);

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}

/// Applies commands, enforces capabilities in one place, and publishes changes.
class CommandDispatcher {
  final CommandTarget target;
  final UndoStack _history;
  final StreamController<DocChange> _changes =
      StreamController<DocChange>.broadcast();

  DraftPermissions permissions;

  CommandDispatcher({
    required this.target,
    this.permissions = DraftPermissions.all,
    int undoLimit = 200,
  }) : _history = UndoStack(limit: undoLimit);

  Stream<DocChange> get changes => _changes.stream;

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  void execute(DraftCommand command) {
    _checkNotDisposed();
    _require(command);
    // The inverse is pushed only after apply returns, so a command that
    // throws leaves no history behind: history matches what actually
    // mutated the target, never what merely attempted to.
    final result = command.apply(target);
    _history.push(result.inverse);
    _changes.add(CommandApplied(label: command.label, touched: result.touched));
  }

  void undo() {
    _checkNotDisposed();
    if (!_history.canUndo) return;
    final inverse = _history.takeUndo();
    final CommandResult result;
    try {
      _require(inverse);
      result = inverse.apply(target);
    } catch (_) {
      // Neither a denied permission check nor a failing replay may silently
      // discard the entry: put it back exactly where it came from so a later
      // permission grant, or a caller that catches and retries, can still
      // undo it. DraftCommand.apply's own contract says a command "must
      // either complete fully or leave the target unmutated" — so a throwing
      // inverse means nothing was mutated, and restoring the entry is safe.
      // Without this, the popped command would vanish from both stacks — a
      // single denied or failing undo would permanently and silently strand
      // that edit.
      _history.pushUndoOnly(inverse);
      rethrow;
    }
    _history.pushRedo(result.inverse);
    _changes.add(CommandUndone(label: inverse.label, touched: result.touched));
  }

  void redo() {
    _checkNotDisposed();
    if (!_history.canRedo) return;
    final inverse = _history.takeRedo();
    final CommandResult result;
    try {
      _require(inverse);
      result = inverse.apply(target);
    } catch (_) {
      // Same reasoning as in undo(): restore to the redo stack it was popped
      // from, not the undo stack.
      _history.pushRedo(inverse);
      rethrow;
    }
    _history.pushUndoOnly(result.inverse);
    _changes.add(CommandRedone(label: inverse.label, touched: result.touched));
  }

  /// The whole document was replaced; history no longer applies to it.
  void notifyLoaded() {
    _history.clear();
    _changes.add(const DocumentLoaded());
  }

  /// Slots were compacted. Every slot-keyed derived structure is invalid and
  /// history cannot be replayed against the new numbering.
  void notifyPurged() {
    _history.clear();
    _changes.add(const DocumentPurged());
  }

  void clearHistory() => _history.clear();

  Future<void> dispose() => _changes.close();

  void _require(DraftCommand command) {
    if (!permissions.allows(command.capability)) {
      throw PermissionDeniedError(command.capability, command.label);
    }
  }

  /// Guards against mutating the target or history after [dispose]: without
  /// this, `execute`/`undo`/`redo` would run `apply` and update `_history`
  /// before `_changes.add` (on the now-closed controller) throws — mutating
  /// state on a dispatcher the caller believes is inert, and surfacing only
  /// an opaque `StateError` from the stream rather than from this contract.
  void _checkNotDisposed() {
    if (_changes.isClosed) {
      throw StateError('CommandDispatcher used after dispose()');
    }
  }
}
