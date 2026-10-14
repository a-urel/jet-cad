// Property specs (spec 2a P3, umbrella A4): the fields a kit's type or a
// tool's settings show in the plan library's property panel, as data. Each
// spec reads one value of its owner `T` and writes a changed copy.
//
// Free of Flutter: nothing here draws. The panel (the plan library) turns a
// spec into a widget through the erased PropertyField.

/// A PlanPermissions flag a field needs (spec 2a P2, P3). A field whose gate
/// is off is shown read-only.
enum PlanGate {
  move,
  rotate,
  mirror,
  reshape,
  delete,
  changeLayer,
  recolor,
  editLayers,
  editPage,
}

/// How a [ValueDisplay] prints its number: a length in mm, an area in mm²,
/// an angle in radians, or a plain number.
enum ValueUnit { length, area, angle, none }

final RegExp _specId = RegExp(r'^[a-z][a-z0-9-]*$');

/// One field of an owner `T`: a type's component or a tool's settings.
///
/// Its word is `property:<owner id>.<id>` (a choice's values:
/// `property:<owner id>.<id>.<value>`).
///
/// **Covariance.** The plan library holds specs of many `T`s at once. A
/// member whose type takes a `T` ([enabled], a kind's `read` and `write`)
/// throws a `TypeError` when it is read through a supertype such as
/// `PropertySpec<Object?>`. Only [id], [gate], a kind's bounds and [bind]
/// are safe there; [bind] is how the plan library uses a spec.
sealed class PropertySpec<T> {
  PropertySpec._(this.id, this.enabled, this.gate) {
    if (!_specId.hasMatch(id)) {
      throw ArgumentError.value(id, 'id',
          'must be a lower-case letter, then lower-case letters, digits and hyphens');
    }
  }

  /// Unique within its owner's specs.
  final String id;

  /// False greys the field out and its commit throws [StateError]. Null:
  /// always enabled.
  final bool Function(T)? enabled;

  /// The permission the field needs, or null for none.
  final PlanGate? gate;

  /// This spec bound to [value], an owner `T`, under [wordId]: the erased
  /// form the plan library uses (spec 2a P1, erased operations). A kit never
  /// calls it.
  ///
  /// The field's `commit` returns the changed owner and, when it is not
  /// null, passes it to [onCommit] first. Throws [ArgumentError] when
  /// [value] is not a `T`.
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit});
}

/// A length in millimetres, within [min] and [max] (inclusive; null:
/// unbounded).
final class LengthProperty<T> extends PropertySpec<T> {
  LengthProperty({
    required String id,
    required this.read,
    required this.write,
    this.min,
    this.max,
    bool Function(T)? enabled,
    PlanGate? gate,
  }) : super._(id, enabled, gate) {
    _checkBounds(min, max);
  }

  final double Function(T) read;
  final T Function(T, double) write;
  final double? min;
  final double? max;

  @override
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(
        this,
        owner,
        wordId,
        read(owner),
        (input) => write(owner, _inRange(_finite(input, id), min, max, id)),
        onCommit);
  }
}

/// An angle, stored in radians. The field's value and its commit's input
/// are radians; the panel shows and parses degrees (spec 2a Task 17).
final class AngleProperty<T> extends PropertySpec<T> {
  AngleProperty({
    required String id,
    required this.read,
    required this.write,
    bool Function(T)? enabled,
    PlanGate? gate,
  }) : super._(id, enabled, gate);

  final double Function(T) read;
  final T Function(T, double) write;

  @override
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner),
        (input) => write(owner, _finite(input, id)), onCommit);
  }
}

/// A plain number within [min] and [max], rounded on commit to [decimals]
/// places (0 to 10), so what is stored is what the panel shows.
final class NumberProperty<T> extends PropertySpec<T> {
  NumberProperty({
    required String id,
    required this.read,
    required this.write,
    this.min,
    this.max,
    this.decimals = 0,
    bool Function(T)? enabled,
    PlanGate? gate,
  }) : super._(id, enabled, gate) {
    _checkBounds(min, max);
    if (decimals < 0 || decimals > 10) {
      throw ArgumentError.value(decimals, 'decimals', 'must be 0 to 10');
    }
  }

  final double Function(T) read;
  final T Function(T, double) write;
  final double? min;
  final double? max;
  final int decimals;

  @override
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner), (input) {
      final rounded =
          double.parse(_finite(input, id).toStringAsFixed(decimals));
      return write(owner, _inRange(rounded, min, max, id));
    }, onCommit);
  }
}

/// One of [values], compared with `==`. A value's word segment is
/// [segmentOf] it: an enum's name, else its `toString`. A segment is not
/// empty, given once, and holds no `.` or `:`, the separators of the word
/// id `property:<owner>.<spec>.<value>`; a value whose segment would is an
/// [ArgumentError] when the spec is made.
final class ChoiceProperty<T, V> extends PropertySpec<T> {
  ChoiceProperty({
    required String id,
    required List<V> values,
    required this.read,
    required this.write,
    bool Function(T)? enabled,
    PlanGate? gate,
  })  : values = List.unmodifiable(values),
        super._(id, enabled, gate) {
    if (this.values.isEmpty) {
      throw ArgumentError.value(values, 'values', 'must not be empty');
    }
    final seen = <String>{};
    for (final v in this.values) {
      final segment = segmentOf(v);
      if (segment.isEmpty || !seen.add(segment)) {
        throw ArgumentError.value(
            v, 'values', 'gives the word segment "$segment" twice or empty');
      }
      if (segment.contains('.') || segment.contains(':')) {
        throw ArgumentError.value(v, 'values',
            'gives the word segment "$segment", which holds "." or ":"');
      }
    }
  }

  /// The word segment of [value]: an enum's name, else `'$value'`.
  static String segmentOf(Object? value) =>
      value is Enum ? value.name : '$value';

  final List<V> values;
  final V Function(T) read;
  final T Function(T, V) write;

  @override
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner), (input) {
      if (input is! V || !values.contains(input)) {
        throw ArgumentError.value(input, id, 'is not one of $values');
      }
      return write(owner, input);
    }, onCommit);
  }
}

/// A yes or no.
final class ToggleProperty<T> extends PropertySpec<T> {
  ToggleProperty({
    required String id,
    required this.read,
    required this.write,
    bool Function(T)? enabled,
    PlanGate? gate,
  }) : super._(id, enabled, gate);

  final bool Function(T) read;
  final T Function(T, bool) write;

  @override
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner), (input) {
      if (input is! bool) {
        throw ArgumentError.value(input, id, 'is not a bool');
      }
      return write(owner, input);
    }, onCommit);
  }
}

/// A text of at most [maxLength] code points (null: any length).
final class TextProperty<T> extends PropertySpec<T> {
  TextProperty({
    required String id,
    required this.read,
    required this.write,
    this.maxLength,
    bool Function(T)? enabled,
    PlanGate? gate,
  }) : super._(id, enabled, gate) {
    final m = maxLength;
    if (m != null && m < 1) {
      throw ArgumentError.value(m, 'maxLength', 'must be at least 1');
    }
  }

  final String Function(T) read;
  final T Function(T, String) write;
  final int? maxLength;

  @override
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner), (input) {
      if (input is! String) {
        throw ArgumentError.value(input, id, 'is not a String');
      }
      final m = maxLength;
      if (m != null && input.runes.length > m) {
        throw ArgumentError.value(input, id, 'is longer than $m');
      }
      return write(owner, input);
    }, onCommit);
  }
}

/// A read-only number: a room's area, a dimension's value. Its field's
/// commit is null.
final class ValueDisplay<T> extends PropertySpec<T> {
  ValueDisplay({
    required String id,
    required this.read,
    required this.unit,
    bool Function(T)? enabled,
    PlanGate? gate,
  }) : super._(id, enabled, gate);

  final double Function(T) read;
  final ValueUnit unit;

  @override
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner), null, onCommit);
  }
}

/// A button: a door's Flip hinge. Its field's value is null and its commit
/// ignores its input and returns [apply] of the owner.
final class ActionProperty<T> extends PropertySpec<T> {
  ActionProperty({
    required String id,
    required this.apply,
    bool Function(T)? enabled,
    PlanGate? gate,
  }) : super._(id, enabled, gate);

  final T Function(T) apply;

  @override
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(
        this, owner, wordId, null, (_) => apply(owner), onCommit);
  }
}

/// A spec bound to one owner value: one object's component or one tool's
/// settings (spec 2a P3). Erased: the plan library holds fields of many
/// owner types in one list and never sees a `T`.
abstract interface class PropertyField {
  /// For [PropertySpec.id], [PropertySpec.gate], the kind (a type test) and
  /// a kind's bounds or values only: see [PropertySpec]'s covariance note.
  PropertySpec<Object?> get spec;

  /// `property:<owner id>.<spec id>`.
  String get wordId;

  /// The spec's `enabled` of the bound owner; true when it has none.
  bool get enabled;

  /// The bound owner's value: a `double` for a length (mm), an angle
  /// (radians), a number and a display; the value for a choice; a `bool`;
  /// a `String`; null for an action.
  Object? get value;

  /// Null for a [ValueDisplay]. Otherwise: the owner changed by [input]
  /// (an action ignores it). Throws [ArgumentError] for an input of the
  /// wrong type, not finite, out of range, not among a choice's values or
  /// too long, and [StateError] while the field is not [enabled].
  Object? Function(Object? input)? get commit;
}

final class _BoundField<T> implements PropertyField {
  factory _BoundField(
      PropertySpec<T> spec,
      T owner,
      String wordId,
      Object? value,
      T Function(Object? input)? change,
      void Function(T next)? onCommit) {
    final enabled = spec.enabled?.call(owner) ?? true;
    return _BoundField._(
        spec,
        wordId,
        value,
        enabled,
        change == null
            ? null
            : (input) {
                if (!enabled) throw StateError('$wordId is not enabled');
                final next = change(input);
                onCommit?.call(next);
                return next;
              });
  }

  _BoundField._(this.spec, this.wordId, this.value, this.enabled, this.commit);

  @override
  final PropertySpec<T> spec;

  @override
  final String wordId;

  @override
  final Object? value;

  @override
  final bool enabled;

  @override
  final Object? Function(Object? input)? commit;
}

T _owner<T>(Object? value) {
  if (value is T) return value;
  throw ArgumentError.value(value, 'value', 'is not a $T');
}

double _finite(Object? input, String id) {
  if (input is num && input.isFinite) return input.toDouble();
  throw ArgumentError.value(input, id, 'is not a finite number');
}

double _inRange(double v, double? min, double? max, String id) {
  if ((min != null && v < min) || (max != null && v > max)) {
    throw ArgumentError.value(
        v, id, 'is outside [${min ?? '-∞'}, ${max ?? '∞'}]');
  }
  return v;
}

void _checkBounds(double? min, double? max) {
  if (min != null && !min.isFinite) {
    throw ArgumentError.value(min, 'min', 'is not finite');
  }
  if (max != null && !max.isFinite) {
    throw ArgumentError.value(max, 'max', 'is not finite');
  }
  if (min != null && max != null && min > max) {
    throw ArgumentError.value(min, 'min', 'is above max ($max)');
  }
}
