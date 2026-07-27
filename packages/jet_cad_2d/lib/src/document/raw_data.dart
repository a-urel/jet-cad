import '../core/handle.dart';
import 'origin_component.dart';

/// The preserve-unknown slot: an opaque blob per handle, per source format.
///
/// The engine stores, serializes and returns these payloads and never inspects
/// them. Modelling them as DXF group codes would have put a format concept in
/// the core document; keeping them opaque is what makes "the engine names no
/// format" true even here.
class RawDataStore {
  final Map<Handle, Map<SourceKind, Object?>> _byHandle = {};

  bool get isEmpty => _byHandle.isEmpty;

  /// Ascending, so serialization and iteration are stably ordered.
  Iterable<Handle> get handles {
    final list = _byHandle.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return list;
  }

  void set(Handle handle, SourceKind source, Object? payload) =>
      (_byHandle[handle] ??= {})[source] = payload;

  Object? get(Handle handle, SourceKind source) => _byHandle[handle]?[source];

  /// A read-only view: callers must go through [set]/[remove] to mutate this
  /// store, so its per-handle sources cannot go out of sync with [handles].
  Map<SourceKind, Object?> allFor(Handle handle) =>
      Map.unmodifiable(_byHandle[handle] ?? const {});

  void remove(Handle handle) => _byHandle.remove(handle);

  /// Shape: `{ handleDecimal: { sourceName: payload } }`, handles in numeric
  /// order and sources in enum declaration order, so output is
  /// byte-deterministic.
  Map<String, Object?> toJson() => {
        for (final handle in handles)
          handle.value.toString(): {
            for (final source in SourceKind.values)
              if (_byHandle[handle]!.containsKey(source))
                source.name: _byHandle[handle]![source],
          },
      };

  void loadJson(Map<String, Object?> json) {
    clear();
    for (final key in json.keys) {
      final handle = Handle.checked(int.parse(key));
      final perSource = (json[key]! as Map).cast<String, Object?>();
      for (final sourceName in perSource.keys) {
        set(handle, SourceKind.values.byName(sourceName),
            perSource[sourceName]);
      }
    }
  }

  void clear() => _byHandle.clear();
}
