import 'entity.dart';
import 'operation.dart';

/// Typed document events. Selection is deliberately NOT here: selection is
/// view state and belongs to the viewport controller's own stream (spec).
sealed class DocChange {
  const DocChange();
}

final class EntitiesAdded extends DocChange {
  final List<EntityId> ids;
  const EntitiesAdded(this.ids);
}

final class EntitiesRemoved extends DocChange {
  final List<EntityId> ids;
  const EntitiesRemoved(this.ids);
}

final class OperationCommitted extends DocChange {
  final Operation operation;
  const OperationCommitted(this.operation);
}

final class UndoPerformed extends DocChange {
  final Operation operation;
  const UndoPerformed(this.operation);
}

final class RedoPerformed extends DocChange {
  final Operation operation;
  const RedoPerformed(this.operation);
}

final class DocumentLoaded extends DocChange {
  const DocumentLoaded();
}
