// PlanServices.shared (spec 2a P1): a per-document cache keyed by (kit id,
// type). The first call creates; later calls return the same value; a
// value that is Disposable is disposed with its document, last made first.
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

final class SharedCache {
  final Map<(String, Type), Object> _values = {};
  final List<(String, Object)> _made = [];
  final Set<(String, Type)> _making = {};
  bool _disposed = false;

  T get<T extends Object>(
      String kitId, PlanServices services, T Function(PlanServices) create) {
    if (_disposed) {
      throw StateError('$kitId: shared<$T> of a plan that was replaced');
    }
    final key = (kitId, T);
    final found = _values[key];
    if (found != null) return found as T;
    if (!_making.add(key)) {
      throw StateError('$kitId: shared<$T> asked for itself while being made');
    }
    try {
      final made = create(services);
      _values[key] = made;
      _made.add((kitId, made));
      return made;
    } finally {
      _making.remove(key);
    }
  }

  /// Disposes every [Disposable] value, last made first. With [onError], a
  /// value whose `dispose` throws is reported there (its kit's id) and the
  /// rest are still disposed (spec 2a P4: a swap completes).
  void dispose({void Function(String kitId, Object error)? onError}) {
    _disposed = true;
    for (final (kitId, value) in _made.reversed) {
      if (value is! Disposable) continue;
      if (onError == null) {
        value.dispose();
        continue;
      }
      try {
        value.dispose();
      } catch (error) {
        onError(kitId, error);
      }
    }
    _made.clear();
    _values.clear();
  }
}
