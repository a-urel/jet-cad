// A kit's parametric type (spec 2a P1): the engine's ParametricType and its
// component factory, wrapped with the type's property specs, colour target,
// grips, title and escape-hatch section.
//
// Covariance: the plan library holds every type as PlanType<Component>. A
// member whose type takes a `T` would fail the VM's covariance check when
// read through that static type, and `catalog.register` would infer
// `T = Component`. So those members are private, and the plan library calls
// only the erased operations below, which run over the class's own `T`, as
// the engine's own registration does.
import 'package:flutter/widgets.dart' show BuildContext, Widget;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ObjectGripProvider;
import 'package:meta/meta.dart';

import '../model/kit_ids.dart';
import 'colour.dart';
import 'plan_services.dart';
import 'properties.dart';

/// A type's escape hatch (umbrella A4): its own panel section over [value],
/// committing a changed copy through [commit], one undo step.
typedef PropertySectionBuilder<T> = Widget Function(
    BuildContext context, T value, void Function(T) commit, KitWords words);

/// Wraps a kit's engine type at the contract's boundary (spec 2a P4, the
/// failure boundary). Implemented by the plan library; [wrap] keeps `T`.
abstract interface class TypeGuard {
  ParametricType<T> wrap<T extends Component>(
      String kitId, String typeId, ParametricType<T> type);
}

@immutable
final class PlanType<T extends Component> {
  const PlanType({
    required this.id,
    required this.fromJson,
    required this.parametric,
    this.grips,
    this.properties = const [],
    PropertySectionBuilder<T>? section,
    String Function(T)? title,
    ColourTarget<T>? colour,
    this.exported = true,
  })  : _section = section,
        _title = title,
        _colour = colour;

  /// `<kit id>.<type>`, equal to the component's codec type id: the
  /// manifest finds the plan's kits by it.
  final String id;

  final ComponentFactory<T> fromJson;
  final ParametricType<T> parametric;

  /// Made once per document (spec 2a P1, lifetimes).
  final ObjectGripProvider Function(PlanServices)? grips;

  /// The panel's fields, in order. Safe to list through
  /// `PlanType<Component>`; use them through [fieldsOf].
  final List<PropertySpec<T>> properties;

  /// False leaves the type's objects out of every export.
  final bool exported;

  final PropertySectionBuilder<T>? _section;
  final String Function(T)? _title;
  final ColourTarget<T>? _colour;

  bool get hasColour => _colour != null;
  bool get hasSection => _section != null;

  /// Registers this type into [catalog] under [id], with `T` kept: through
  /// [guard]'s wrapper when one is given (the plan library's).
  void registerInto(ParametricCatalog catalog, {TypeGuard? guard}) {
    final type = guard == null
        ? parametric
        : guard.wrap<T>(kitOfKey(id), id, parametric);
    catalog.register<T>(id, fromJson, type);
  }

  /// The fields of [group]'s `T`, bound to its current value, each under
  /// `property:<id>.<spec id>`; empty when [group] carries no `T`.
  List<PropertyField> fieldsOf(CommandTarget target, Handle group) {
    final value = target.components.get<T>(group);
    if (value == null) return const [];
    return [
      for (final spec in properties)
        spec.bind(value, wordId: 'property:$id.${spec.id}'),
    ];
  }

  /// The word id of [group]'s section title: `type:<id>`, unless the
  /// type's `title` names another for its current value.
  String titleWordOf(CommandTarget target, Handle group) {
    final value = target.components.get<T>(group);
    final title = _title;
    if (value == null || title == null) return 'type:$id';
    return title(value);
  }

  /// [group]'s swatch; null without a colour target, a `T`, or a swatch.
  String? colourOf(CommandTarget target, Handle group) {
    final value = target.components.get<T>(group);
    final colour = _colour;
    if (value == null || colour == null) return null;
    return colour.read(value);
  }

  /// The one command that gives [group] [swatch] (null clears it); null
  /// without a colour target or a `T`, or when the swatch is already it.
  DraftCommand? recolour(CommandTarget target, Handle group, String? swatch) {
    final value = target.components.get<T>(group);
    final colour = _colour;
    if (value == null || colour == null) return null;
    final next = colour.write(value, swatch);
    if (next == value) return null;
    return SetComponentCommand<T>(group, next);
  }

  /// The one command that commits [input] through [field], one of this
  /// type's fields: bound again to [group]'s current value, so a field
  /// read before another edit never writes back what that edit changed.
  ///
  /// Throws [ArgumentError] when [field] is not one of this type's specs,
  /// [group] carries no `T` or the field is a display, and what the
  /// field's commit throws (spec 2a P3: out of range, disabled).
  DraftCommand commitField(
      CommandTarget target, Handle group, PropertyField field, Object? input) {
    final spec = properties.firstWhere((s) => identical(s, field.spec),
        orElse: () => throw ArgumentError.value(
            field.wordId, 'field', 'is not a field of $id'));
    final value = target.components.get<T>(group);
    if (value == null) {
      throw ArgumentError.value(group, 'group', 'carries no $id');
    }
    final commit = spec.bind(value, wordId: field.wordId).commit;
    if (commit == null) {
      throw ArgumentError.value(field.wordId, 'field', 'is read-only');
    }
    return SetComponentCommand<T>(group, commit(input) as T);
  }

  /// [group]'s escape-hatch section, or null without one or a `T`. Its
  /// commit hands [execute] one `SetComponentCommand<T>`.
  Widget? sectionFor(BuildContext context, CommandTarget target, Handle group,
      void Function(DraftCommand) execute, KitWords words) {
    final value = target.components.get<T>(group);
    final section = _section;
    if (value == null || section == null) return null;
    return section(context, value,
        (next) => execute(SetComponentCommand<T>(group, next)), words);
  }

  /// This type's grip provider over [services], or null without one.
  ObjectGripProvider? gripsFor(PlanServices services) => grips?.call(services);

  @override
  String toString() => 'PlanType($id)';
}
