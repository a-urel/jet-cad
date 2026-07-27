import '../core/handle.dart';

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
  const CommandApplied({required this.label, required this.touched});
}

final class CommandUndone extends DocChange {
  final String label;
  @override
  final Set<Handle> touched;
  const CommandUndone({required this.label, required this.touched});
}

final class CommandRedone extends DocChange {
  final String label;
  @override
  final Set<Handle> touched;
  const CommandRedone({required this.label, required this.touched});
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
