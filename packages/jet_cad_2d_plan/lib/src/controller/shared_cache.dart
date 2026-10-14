// PlanServices.shared (spec 2a P1): a per-document cache keyed by (kit id,
// type). The first call creates; later calls return the same value; a
// value that is Disposable is disposed with its document, last made first.
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

final class SharedCache {
  final Map<(String, Type), Object> _values = {};
  final List<Object> _made = [];
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
      _made.add(made);
      return made;
    } finally {
      _making.remove(key);
    }
  }

  void dispose() {
    _disposed = true;
    for (final value in _made.reversed) {
      if (value is Disposable) value.dispose();
    }
    _made.clear();
    _values.clear();
  }
}
