// Property specs (spec 2a P3, umbrella A4): the fields a kit's type or a
// tool's settings show in the plan library's property panel, as data. Each
// spec reads one value of its owner `T` and writes a changed copy. A spec
// may read the object it is shown for (spec 3a C1.1: a text display, a
// length's range) and may be hidden (C1.7).
//
// Free of Flutter: nothing here draws. The panel (the plan library) turns a
// spec into a widget through the erased PropertyField. The object's words
// are the pure PlanWords (3a rulings R-P4, R-P7).
import 'package:jet_cad_2d/jet_cad_2d.dart'
    show DraftDocument, Handle, Transform2;
import 'package:meta/meta.dart' show internal;

import '../model/plan_words.dart';

/// A PlanPermissions flag a field needs (spec 2a P2, P3). A field whose gate
/// is off is shown read-only; an action whose gate is off is not shown
/// (spec 3a C1.7).
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

  /// A unit's label (spec 2b S4; today's `renumber`).
  relabel,
}

/// How a [ValueDisplay] prints its number: a length in mm, an area in mm²,
/// an angle in radians, or a plain number.
enum ValueUnit { length, area, angle, none }

/// The object a property or a section is shown for (spec 3a C1.1), read
/// only: what a spec needs beyond its owner, such as a child's text,
/// another object's component, or the world transform.
abstract interface class PlanObject {
  /// The document the object lives in.
  DraftDocument get document;

  /// The object's group.
  Handle get handle;

  /// Its world transform: `document.tree.accumulatedTransform(handle)`.
  Transform2 get world;

  /// The owning kit's words at the plan's locale (rulings R-P4, R-P7): a
  /// type's or a `text:` word, the UI language's decimal separator.
  PlanWords get words;
}

/// A [PlanObject] over [document] and [handle], with [words]; [world] is
/// computed on its first read.
final class DocumentPlanObject implements PlanObject {
  DocumentPlanObject(this.document, this.handle, this.words);

  @override
  final DraftDocument document;

  @override
  final Handle handle;

  @override
  final PlanWords words;

  @override
  late final Transform2 world = document.tree.accumulatedTransform(handle);
}

final RegExp _specId = RegExp(r'^[a-z][a-z0-9-]*$');

/// One field of an owner `T`: a type's component or a tool's settings.
///
/// Its word is `property:<owner id>.<id>` (a choice's values:
/// `property:<owner id>.<id>.<value>`).
///
/// **Covariance.** The plan library holds specs of many `T`s at once. A
/// member whose type takes a `T` ([enabled], [visible], a kind's `read`,
/// `write` and `range`) throws a `TypeError` when it is read through a
/// supertype such as `PropertySpec<Object?>`. Only [id], [gate], a kind's
/// bounds and [bind] are safe there; [bind] is how the plan library uses a
/// spec.
sealed class PropertySpec<T> {
  PropertySpec._(this.id, this.enabled, this.gate, this.visible) {
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

  /// False hides the field: it takes no room in the panel (spec 3a C1.7).
  /// Evaluated when the spec is bound, so a throw is the binding's. Null:
  /// always visible.
  final bool Function(T)? visible;

  /// Whether binding needs the object (a [TextDisplay], a
  /// [LengthProperty] with a `range`): a tool's settings, which have none,
  /// may not hold such a spec (`PlanKit.validate`). Safe through a
  /// supertype: it reads the spec's own members with its own `T`.
  @internal
  bool get needsObject => false;

  /// This spec bound to [value], an owner `T`, under [wordId], for
  /// [object] (a type's field; null for a tool's settings): the erased form
  /// the plan library uses (spec 2a P1, erased operations). A kit never
  /// calls it.
  ///
  /// The field's `commit` returns the changed owner and, when it is not
  /// null, passes it to [onCommit] first. Throws [ArgumentError] when
  /// [value] is not a `T`, and when the spec needs an object ([needsObject])
  /// and [object] is null.
  PropertyField bind(Object? value,
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object});
}

/// A length in millimetres, within [min] and [max] (inclusive; null:
/// unbounded) and, with a [range], within what it gives for the value and
/// the object at the commit (inclusive too; spec 3a C1.1).
final class LengthProperty<T> extends PropertySpec<T> {
  LengthProperty({
    required String id,
    required this.read,
    required this.write,
    this.min,
    this.max,
    this.range,
    bool Function(T)? enabled,
    bool Function(T)? visible,
    PlanGate? gate,
  }) : super._(id, enabled, gate, visible) {
    _checkBounds(min, max);
  }

  final double Function(T) read;
  final T Function(T, double) write;
  final double? min;
  final double? max;

  /// The bounds the object allows, read at each commit: an opening's
  /// position along its host wall. A null result refuses every value.
  final (double, double)? Function(T value, PlanObject object)? range;

  @override
  bool get needsObject => range != null;

  @override
  PropertyField bind(Object? value,
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
    final owner = _owner<T>(value);
    final range = this.range;
    if (range != null && object == null) _noObject(wordId);
    return _BoundField<T>(this, owner, wordId, read(owner), (input) {
      final v = _inRange(_finite(input, id), min, max, id);
      if (range != null) {
        final allowed = range(owner, object!);
        if (allowed == null) {
          throw ArgumentError.value(v, id, 'has no range for this object');
        }
        _inRange(v, allowed.$1, allowed.$2, id);
      }
      return write(owner, v);
    }, onCommit);
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
    bool Function(T)? visible,
    PlanGate? gate,
  }) : super._(id, enabled, gate, visible);

  final double Function(T) read;
  final T Function(T, double) write;

  @override
  PropertyField bind(Object? value,
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
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
    bool Function(T)? visible,
    PlanGate? gate,
  }) : super._(id, enabled, gate, visible) {
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
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
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
    bool Function(T)? visible,
    PlanGate? gate,
  })  : values = List.unmodifiable(values),
        super._(id, enabled, gate, visible) {
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
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
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
    bool Function(T)? visible,
    PlanGate? gate,
  }) : super._(id, enabled, gate, visible);

  final bool Function(T) read;
  final T Function(T, bool) write;

  @override
  PropertyField bind(Object? value,
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
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
    bool Function(T)? visible,
    PlanGate? gate,
  }) : super._(id, enabled, gate, visible) {
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
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
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

/// A read-only number of the owner. Its field's commit is null.
final class ValueDisplay<T> extends PropertySpec<T> {
  ValueDisplay({
    required String id,
    required this.read,
    required this.unit,
    bool Function(T)? enabled,
    bool Function(T)? visible,
    PlanGate? gate,
  }) : super._(id, enabled, gate, visible);

  final double Function(T) read;
  final ValueUnit unit;

  @override
  PropertyField bind(Object? value,
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner), null, onCommit);
  }
}

/// A read-only line of text read from the object (spec 3a C1.1): a room's
/// area and a dimension's value as drawn, a dimension's axes and ends. Its
/// field's value is the `String` and its commit is null; a null read omits
/// the line (the field is not visible). Bound to an object only: a tool's
/// settings may not hold one (`PlanKit.validate`).
final class TextDisplay<T> extends PropertySpec<T> {
  TextDisplay({
    required String id,
    required this.read,
    bool Function(T)? enabled,
    bool Function(T)? visible,
    PlanGate? gate,
  }) : super._(id, enabled, gate, visible);

  final String? Function(T value, PlanObject object) read;

  @override
  bool get needsObject => true;

  @override
  PropertyField bind(Object? value,
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
    final owner = _owner<T>(value);
    if (object == null) _noObject(wordId);
    final text = read(owner, object);
    return _BoundField<T>(this, owner, wordId, text, null, onCommit,
        shown: text != null);
  }
}

/// A button: a door's Flip hinge. Its field's value is null and its commit
/// ignores its input and returns [apply] of the owner.
final class ActionProperty<T> extends PropertySpec<T> {
  ActionProperty({
    required String id,
    required this.apply,
    bool Function(T)? enabled,
    bool Function(T)? visible,
    PlanGate? gate,
  }) : super._(id, enabled, gate, visible);

  final T Function(T) apply;

  @override
  PropertyField bind(Object? value,
      {required String wordId,
      void Function(T next)? onCommit,
      PlanObject? object}) {
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

  /// The spec's `visible` of the bound owner (true when it has none), and
  /// false for a [TextDisplay] whose read gave null (spec 3a C1.7).
  bool get visible;

  /// The bound owner's value: a `double` for a length (mm), an angle
  /// (radians), a number and a value display; the value for a choice; a
  /// `bool`; a `String` for a text and a text display (null for a display
  /// that reads nothing); null for an action.
  Object? get value;

  /// Null for a [ValueDisplay] and a [TextDisplay]. Otherwise: the owner
  /// changed by [input] (an action ignores it). Throws [ArgumentError] for
  /// an input of the wrong type, not finite, out of range (a length's
  /// `range` included), not among a choice's values or too long, and
  /// [StateError] while the field is not [enabled].
  Object? Function(Object? input)? get commit;
}

final class _BoundField<T> implements PropertyField {
  factory _BoundField(
      PropertySpec<T> spec,
      T owner,
      String wordId,
      Object? value,
      T Function(Object? input)? change,
      void Function(T next)? onCommit,
      {bool shown = true}) {
    final enabled = spec.enabled?.call(owner) ?? true;
    final visible = shown && (spec.visible?.call(owner) ?? true);
    return _BoundField._(
        spec,
        wordId,
        value,
        enabled,
        visible,
        change == null
            ? null
            : (input) {
                if (!enabled) throw StateError('$wordId is not enabled');
                final next = change(input);
                onCommit?.call(next);
                return next;
              });
  }

  _BoundField._(this.spec, this.wordId, this.value, this.enabled, this.visible,
      this.commit);

  @override
  final PropertySpec<T> spec;

  @override
  final String wordId;

  @override
  final Object? value;

  @override
  final bool enabled;

  @override
  final bool visible;

  @override
  final Object? Function(Object? input)? commit;
}

T _owner<T>(Object? value) {
  if (value is T) return value;
  throw ArgumentError.value(value, 'value', 'is not a $T');
}

Never _noObject(String wordId) => throw ArgumentError.value(
    wordId, 'object', 'reads the object it is shown for: bind it to one');

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
