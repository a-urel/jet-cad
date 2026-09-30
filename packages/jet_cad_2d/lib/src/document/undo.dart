import 'dart:async';

import 'command.dart';
import 'doc_change.dart';

/// One history entry: the command that leaves a state, and the id of the
/// state it returns to.
typedef _Entry = ({DraftCommand command, int returnsTo});

/// Bounded undo and redo stacks over numbered states.
///
/// The depth limit exists because a runtime viewer wants recoverable edits
/// without an unbounded history; the mechanism is identical to the designer's.
///
/// Every state the stacks move between has an id ([state]). An entry records
/// the command that moves away from the current state and the id of the state
/// that command returns to, so undo and redo restore the recorded id rather
/// than recompute one. The mutations are whole transitions of the stack, never
/// loose pushes and pops, so no caller can stamp an id by accident: undo and
/// redo are take ([beginUndo]) → apply → [commitUndo] or [abortUndo].
class UndoStack {
  final int limit;
  final List<_Entry> _undo = [];
  final List<_Entry> _redo = [];
  int _state = 0;
  int _next = 0;

  UndoStack({this.limit = 200});

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get undoDepth => _undo.length;

  /// The current state's id. Opaque: only equality means anything, and an id
  /// is never reused by this stack.
  int get state => _state;

  /// A newly applied command's [inverse] leaves a fresh state.
  ///
  /// Clears the redo stack: once a fresh edit lands, the previously-undone
  /// future is no longer reachable, and neither is any state only its entries
  /// reached. Eviction past [limit] drops the oldest entry and with it the only
  /// way back to its recorded state.
  void recordExecute(DraftCommand inverse) {
    _undo.add((command: inverse, returnsTo: _state));
    _state = ++_next;
    if (_undo.length > limit) _undo.removeAt(0);
    _redo.clear();
  }

  /// The command an undo would apply. Does not pop it: the caller applies it,
  /// then calls [commitUndo] on success or [abortUndo] on failure.
  DraftCommand beginUndo() => _undo.last.command;

  /// The undo begun by [beginUndo] applied; [redoInverse] is its inverse.
  ///
  /// Pops the entry, records [redoInverse] as the way back to the current
  /// state, and moves to the state the entry returns to.
  void commitUndo(DraftCommand redoInverse) {
    final entry = _undo.removeLast();
    _redo.add((command: redoInverse, returnsTo: _state));
    _state = entry.returnsTo;
  }

  /// The undo begun by [beginUndo] failed and mutated nothing: both stacks
  /// and [state] stay exactly as they were, the entry with its original
  /// return id. An explicit call so the caller's shape stays take → apply →
  /// commit or abort.
  void abortUndo() {}

  /// The command a redo would apply. Does not pop it: the caller applies it,
  /// then calls [commitRedo] on success or [abortRedo] on failure.
  DraftCommand beginRedo() => _redo.last.command;

  /// The redo begun by [beginRedo] applied; [undoInverse] is its inverse.
  ///
  /// Pops the entry, records [undoInverse] on the undo stack as the way back
  /// to the current state — without clearing the redo stack, which a second
  /// redo in a row still needs — and moves to the state the entry returns to.
  /// Needs no eviction: an undo moves an entry from the undo stack to the redo
  /// stack and a redo moves it back, so their sum never exceeds [limit].
  void commitRedo(DraftCommand undoInverse) {
    final entry = _redo.removeLast();
    _undo.add((command: undoInverse, returnsTo: _state));
    _state = entry.returnsTo;
  }

  /// The redo begun by [beginRedo] failed and mutated nothing: both stacks
  /// and [state] stay exactly as they were.
  void abortRedo() {}

  /// Drops both stacks. Keeps [state]: the document did not change, only the
  /// way back did.
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

  /// Called synchronously, after a mutation has been applied and before
  /// `execute`/`undo`/`redo` returns.
  ///
  /// Derived structures that must be correct for the *next statement* — the
  /// spatial index above all — use this rather than [changes], which is an
  /// asynchronous broadcast stream and therefore fires a microtask too late.
  /// The stream remains the right channel for UI, where that latency is
  /// invisible.
  ///
  /// Nullable and settable rather than a direct dependency, because this layer
  /// must not import the index — the dependency runs the other way.
  ///
  /// **Must not throw.** Unlike [changes] — an async broadcast controller
  /// whose listeners run outside this call stack and so can never make
  /// `execute`/`undo`/`redo` itself fail — this callback runs synchronously,
  /// inline, after the mutation and the history push have both already
  /// happened. A throwing callback therefore propagates out of
  /// `execute`/`undo`/`redo` with the mutation and the history change both
  /// already standing: the caller sees an exception and reasonably concludes
  /// nothing happened, exactly the hazard [_checkNotDisposed] and
  /// [DraftDocument.purge]'s own guard exist to close elsewhere. A reader-only
  /// callback (recomputing a derived index, say) should never throw in the
  /// first place; this is not a contract this dispatcher can enforce, so it is
  /// stated here instead.
  void Function(DocChange change)? onAfterMutate;

  /// Called before `execute`, `undo` and `redo` mutate anything.
  ///
  /// Exists so a derived structure that is mid-walk can refuse the mutation:
  /// changing the document inside a query visitor changes the structure being
  /// walked. Nullable and settable rather than a direct dependency, because
  /// this layer must not import the index — the dependency runs the other
  /// way.
  void Function()? onBeforeMutate;

  /// Spec 06 D2: wraps every command [execute] runs — never [undo] or
  /// [redo], which replay concrete inverses. The parametric system takes
  /// this slot to fold a regeneration into the same undo step.
  ///
  /// Contract: a pure wrapper. It may return [command] unchanged, and it
  /// must not mutate anything itself. One slot, one owner: whoever takes it
  /// releases it only if it is still their own tear-off.
  DraftCommand Function(DraftCommand command)? expander;

  CommandDispatcher({
    required this.target,
    this.permissions = DraftPermissions.all,
    int undoLimit = 200,
  }) : _history = UndoStack(limit: undoLimit);

  Stream<DocChange> get changes => _changes.stream;

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  /// How many entries `undo()` could pop. One [CompoundCommand] is one.
  int get undoDepth => _history.undoDepth;

  /// The id of the state the document is in, as far as this dispatcher's
  /// history knows it.
  ///
  /// Opaque: only equality between two ids read from **this** dispatcher means
  /// anything — two dispatchers' ids are unrelated. [execute] moves to an id
  /// never used before by this dispatcher; [undo] and [redo] return to exactly
  /// the id recorded when the state was left, so an edit then an undo reads
  /// the pre-edit id again. An id is never reused: an edit after an undo does
  /// not return to the undone state's id, and a state lost to eviction or to a
  /// cleared redo stack is never reached again. A failed [undo] or [redo]
  /// leaves it unchanged.
  ///
  /// Only what goes through this dispatcher moves it. [clearHistory],
  /// [notifyLoaded] and [notifyPurged] keep it (the way back changed, not the
  /// document); a table edit (`TableSection.add`/`remove`),
  /// `DraftDocument.purge` and the handle seed are not commands and do not
  /// move it either, so equal ids mean the same history state, not
  /// byte-equal documents.
  int get stateId => _history.state;

  void execute(DraftCommand command) {
    onBeforeMutate?.call();
    _checkNotDisposed();
    final effective = expander?.call(command) ?? command;
    _require(effective);
    // The inverse is pushed only after apply returns, so a command that
    // throws leaves no history behind: history matches what actually
    // mutated the target, never what merely attempted to.
    final result = effective.apply(target);
    _history.recordExecute(result.inverse);
    final change = CommandApplied(
        label: effective.label,
        touched: result.touched,
        capability: effective.capability);
    _changes.add(change);
    onAfterMutate?.call(change);
  }

  void undo() {
    onBeforeMutate?.call();
    _checkNotDisposed();
    if (!_history.canUndo) return;
    final inverse = _history.beginUndo();
    final CommandResult result;
    try {
      _require(inverse);
      result = inverse.apply(target);
    } catch (_) {
      // Neither a denied permission check nor a failing replay may silently
      // discard the entry: it stays exactly where it is, with the state id it
      // returns to, so a later permission grant, or a caller that catches and
      // retries, can still undo it — and lands on the right id when it does.
      // DraftCommand.apply's own contract says a command "must either
      // complete fully or leave the target unmutated" — so a throwing inverse
      // means nothing was mutated, and keeping the entry is safe. Without
      // this, the command would vanish from both stacks — a single denied or
      // failing undo would permanently and silently strand that edit.
      _history.abortUndo();
      rethrow;
    }
    _history.commitUndo(result.inverse);
    final change = CommandUndone(
        label: inverse.label,
        touched: result.touched,
        capability: inverse.capability);
    _changes.add(change);
    onAfterMutate?.call(change);
  }

  void redo() {
    onBeforeMutate?.call();
    _checkNotDisposed();
    if (!_history.canRedo) return;
    final inverse = _history.beginRedo();
    final CommandResult result;
    try {
      _require(inverse);
      result = inverse.apply(target);
    } catch (_) {
      // Same reasoning as in undo(): the entry stays on the redo stack,
      // with its recorded state id.
      _history.abortRedo();
      rethrow;
    }
    _history.commitRedo(result.inverse);
    final change = CommandRedone(
        label: inverse.label,
        touched: result.touched,
        capability: inverse.capability);
    _changes.add(change);
    onAfterMutate?.call(change);
  }

  /// The whole document was replaced; history no longer applies to it.
  void notifyLoaded() {
    _history.clear();
    const change = DocumentLoaded();
    _changes.add(change);
    onAfterMutate?.call(change);
  }

  /// Slots were compacted. Every slot-keyed derived structure is invalid and
  /// history cannot be replayed against the new numbering.
  void notifyPurged() {
    _history.clear();
    const change = DocumentPurged();
    _changes.add(change);
    onAfterMutate?.call(change);
  }

  void clearHistory() => _history.clear();

  Future<void> dispose() => _changes.close();

  /// Whether [dispose] has run. Anything that mutates the target and then
  /// notifies — [DraftDocument.purge] is the one such operation that is not a
  /// command — must consult this *before* it mutates, for the reason given on
  /// [_checkNotDisposed].
  bool get isDisposed => _changes.isClosed;

  void _require(DraftCommand command) {
    for (final capability in command.capabilities) {
      if (!permissions.allows(capability)) {
        throw PermissionDeniedError(capability, command.label);
      }
    }
  }

  /// Guards against mutating the target or history after [dispose]: without
  /// this, `execute`/`undo`/`redo` would run `apply` and update `_history`
  /// before `_changes.add` (on the now-closed controller) throws — mutating
  /// state on a dispatcher the caller believes is inert, and surfacing only
  /// an opaque `StateError` from the stream rather than from this contract.
  void _checkNotDisposed() {
    if (isDisposed) {
      throw StateError('CommandDispatcher used after dispose()');
    }
  }
}
