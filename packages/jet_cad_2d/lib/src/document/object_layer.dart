import '../core/handle.dart';
import 'component.dart';

/// The layer of a parametric object, carried on its group (spec 12b D2).
///
/// A `GroupNode` has no layer of its own, so an object's layer is this
/// component; the parametric system writes it onto every generated child.
/// Absent means layer 0, which is every object in every file written before
/// schema 7. A component naming a layer the table no longer holds is kept
/// as stored and diagnosed by `validate()`; `objectLayer` reads it as
/// layer 0.
///
/// Registered by `ComponentRegistry.registerBuiltIns`, so every document
/// decodes it, and **not** internal: it is document content that a foreign
/// format may carry.
class ObjectLayer implements Component {
  static const String componentTypeId = 'jet_cad.object_layer';

  final Handle layer;

  const ObjectLayer(this.layer);

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'layer': layer.toJson()};

  static ObjectLayer fromJson(Map<String, Object?> json) =>
      ObjectLayer(Handle.fromJson(json['layer']));

  @override
  bool operator ==(Object other) =>
      other is ObjectLayer && other.layer == layer;

  @override
  int get hashCode => layer.hashCode;

  @override
  String toString() => 'ObjectLayer(${layer.toHex()})';
}
