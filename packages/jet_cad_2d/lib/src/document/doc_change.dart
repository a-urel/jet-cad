import '../core/handle.dart';
import 'command.dart';

/// Typed document events.
///
/// Selection is deliberately absent: selection is view state and belongs to the
/// widget layer's own controller, which is a `Stream` for the same reason this
/// is — both carry deltas rather than snapshots.
sealed class DocChange {
  const DocChange();

  /// Handles whose state changed. Empty when the whole document changed.
  Set<Handle> get touched => const {};
}

final class CommandApplied extends DocChange {
  final String label;
  @override
  final Set<Handle> touched;

  /// What kind of edit this was — the command's [DraftCommand.capability],
  /// a [CompoundCommand]'s summary. [Capability.components] means no
  /// geometry and no structure moved: the spatial index and the tile cache
  /// skip it (spec D13). Defaults to [Capability.geometry] so a change built
  /// without it keeps the meaning every consumer gave it before.
  final Capability capability;

  const CommandApplied(
      {required this.label,
      required this.touched,
      this.capability = Capability.geometry});
}

final class CommandUndone extends DocChange {
  final String label;
  @override
  final Set<Handle> touched;

  /// See [CommandApplied.capability].
  final Capability capability;

  const CommandUndone(
      {required this.label,
      required this.touched,
      this.capability = Capability.geometry});
}

final class CommandRedone extends DocChange {
  final String label;
  @override
  final Set<Handle> touched;

  /// See [CommandApplied.capability].
  final Capability capability;

  const CommandRedone(
      {required this.label,
      required this.touched,
      this.capability = Capability.geometry});
}

/// The whole document was replaced.
final class DocumentLoaded extends DocChange {
  const DocumentLoaded();
}

/// Slots were compacted by an explicit purge. Every derived structure keyed by
/// a slot is invalid; the undo stack has been cleared.
final class DocumentPurged extends DocChange {
  const DocumentPurged();
}
