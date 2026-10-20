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
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../model/kit_ids.dart';
import '../model/plan_words.dart';
import 'colour.dart';
import 'plan_services.dart';
import 'properties.dart';

/// A type's escape hatch (umbrella A4): its own panel section over
/// [PlanSection.value], committing a changed copy through
/// [PlanSection.commit], one undo step. One context, so a later field joins
/// it without breaking a kit (spec 3a C1.1).
typedef PropertySectionBuilder<T> = Widget Function(
    BuildContext context, PlanSection<T> section);

/// What a section is built over (spec 3a C1.1): the object's component, the
/// one commit, the kit's words, the object, and the kit's services.
@immutable
final class PlanSection<T> {
  const PlanSection({
    required this.value,
    required this.commit,
    required this.words,
    required this.object,
    required this.services,
  });

  final T value;

  /// Hands the plan one `SetComponentCommand<T>` of [next].
  final void Function(T next) commit;
  final KitWords words;
  final PlanObject object;
  final PlanServices services;
}

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
    List<Vector2>? Function(T value, PlanObject object)? area,
    String? Function(T value)? name,
    this.exported = true,
  })  : _section = section,
        _title = title,
        _colour = colour,
        _area = area,
        _name = name;

  /// `<kit id>.<type>`, equal to the component's codec type id: the
  /// manifest finds the plan's kits by it.
  final String id;

  final ComponentFactory<T> fromJson;
  final ParametricType<T> parametric;

  /// Made once per document (spec 2a P1, lifetimes).
  final ObjectGripProvider Function(PlanServices)? grips;

  /// The panel's fields, in order. Safe to list through
  /// `PlanType<Component>`, but a spec's members that take a `T` (`read`,
  /// `write`, `enabled`, `apply`) throw a `TypeError` when read through it
  /// (see [PropertySpec]): use the fields through [fieldsOf] and
  /// [commitField], which keep `T`.
  final List<PropertySpec<T>> properties;

  /// False leaves the type's objects out of every export.
  final bool exported;

  final PropertySectionBuilder<T>? _section;
  final String Function(T)? _title;
  final ColourTarget<T>? _colour;
  final List<Vector2>? Function(T value, PlanObject object)? _area;
  final String? Function(T value)? _name;

  bool get hasColour => _colour != null;

  /// True when the type declares its objects' area (see [areaOf]).
  bool get hasArea => _area != null;

  /// True when the type declares its objects' own name (see [nameOf]).
  bool get hasName => _name != null;
  bool get hasSection => _section != null;

  /// Registers this type into [catalog] under [id], with `T` kept: through
  /// [guard]'s wrapper when one is given (the plan library's).
  void registerInto(ParametricCatalog catalog, {TypeGuard? guard}) {
    final type = guard == null
        ? parametric
        : guard.wrap<T>(kitOfKey(id), id, parametric);
    catalog.register<T>(id, fromJson, type);
  }

  /// The fields of [group]'s `T`, bound to its current value and to the
  /// object (spec 3a C1.1) with the kit's [words] (ruling R-P4), each under
  /// `property:<id>.<spec id>`; empty when [group] carries no `T`.
  List<PropertyField> fieldsOf(
      DraftDocument document, Handle group, PlanWords words) {
    final value = document.components.get<T>(group);
    if (value == null) return const [];
    final object = DocumentPlanObject(document, group, words);
    return [
      for (final spec in properties)
        spec.bind(value, wordId: 'property:$id.${spec.id}', object: object),
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

  /// [group]'s area: its closed outline in world millimetres, anticlockwise,
  /// without a closing duplicate. Null without an area capability, a `T`, or
  /// when the object has no area now (the capability returned null).
  List<Vector2>? areaOf(DraftDocument document, Handle group, PlanWords words) {
    final value = document.components.get<T>(group);
    final area = _area;
    if (value == null || area == null) return null;
    return area(value, DocumentPlanObject(document, group, words));
  }

  /// [group]'s own name (a room's "VIP"); null without a name capability, a
  /// `T`, or when the object has no name (the capability returned null).
  String? nameOf(DraftDocument document, Handle group) {
    final value = document.components.get<T>(group);
    final name = _name;
    if (value == null || name == null) return null;
    return name(value);
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
  /// The object is the document's now, so a range is checked against it.
  ///
  /// Throws [ArgumentError] when [field] is not one of this type's specs,
  /// [group] carries no `T` or the field is a display, and what the
  /// field's commit throws (spec 2a P3: out of range, disabled).
  DraftCommand commitField(DraftDocument document, Handle group,
      PropertyField field, Object? input, PlanWords words) {
    final spec = properties.firstWhere((s) => identical(s, field.spec),
        orElse: () => throw ArgumentError.value(
            field.wordId, 'field', 'is not a field of $id'));
    final value = document.components.get<T>(group);
    if (value == null) {
      throw ArgumentError.value(group, 'group', 'carries no $id');
    }
    final commit = spec
        .bind(value,
            wordId: field.wordId,
            object: DocumentPlanObject(document, group, words))
        .commit;
    if (commit == null) {
      throw ArgumentError.value(field.wordId, 'field', 'is read-only');
    }
    return SetComponentCommand<T>(group, commit(input) as T);
  }

  /// [group]'s escape-hatch section, or null without one or a `T`. Its
  /// commit hands [execute] one `SetComponentCommand<T>`; [words] and
  /// [services] are the type's kit's.
  Widget? sectionFor(
      BuildContext context,
      DraftDocument document,
      Handle group,
      void Function(DraftCommand) execute,
      KitWords words,
      PlanServices services) {
    final value = document.components.get<T>(group);
    final section = _section;
    if (value == null || section == null) return null;
    return section(
        context,
        PlanSection<T>(
            value: value,
            commit: (next) => execute(SetComponentCommand<T>(group, next)),
            words: words,
            object: DocumentPlanObject(document, group, words),
            services: services));
  }

  /// This type's grip provider over [services], or null without one.
  ObjectGripProvider? gripsFor(PlanServices services) => grips?.call(services);

  @override
  String toString() => 'PlanType($id)';
}
