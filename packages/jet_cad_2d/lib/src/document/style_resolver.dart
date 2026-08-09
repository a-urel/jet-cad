import '../core/handle.dart';
import 'draft_document.dart';
import 'node.dart';
import 'resolved_style.dart';
import 'style.dart';
import 'style_context.dart';
import 'tables.dart';

abstract class StyleResolver {
  /// The context an instance imposes on its definition's contents.
  StyleContext contextFor(Handle instance, StyleContext inherited);

  /// Concrete paint for one entity slot under a context.
  ///
  /// Takes a slot rather than a handle because the frame path holds slots:
  /// `forEachInRect` yields them, and a handle-keyed signature would add a map
  /// lookup per entity per frame to satisfy the signature alone.
  ResolvedStyle styleFor(int slot, StyleContext ctx);
}

class DocumentStyleResolver implements StyleResolver {
  DocumentStyleResolver(this.document);

  final DraftDocument document;

  @override
  StyleContext contextFor(Handle instance, StyleContext inherited) {
    final node = document.tree[instance];
    if (node is! InstanceNode) return inherited;
    // An instance on layer 0 is substituted onto the layer it is placed
    // through, exactly as an entity is in [styleFor]. That one effective layer
    // answers both questions this method asks — which layer supplies this
    // instance's own BYLAYER colour, and which layer it passes down — so it is
    // computed once. Reading `node.layer` for the colour while passing the
    // substituted layer down would make one node report two effective layers.
    final layer =
        node.layer == ReservedHandles.layerZero ? inherited.layer : node.layer;
    final encoded = encodeColor(node.color);
    final color = switch (encoded) {
      kByBlock => inherited.color,
      kByLayer => _layerColorOf(layer, inherited),
      _ => encoded,
    };
    return StyleContext(
      color: color,
      linetype: inherited.linetype,
      linetypeScale: inherited.linetypeScale,
      lineweight: inherited.lineweight,
      transparency: inherited.transparency,
      layer: layer,
    );
  }

  @override
  ResolvedStyle styleFor(int slot, StyleContext ctx) {
    final entityLayer = document.entities.layerAt(slot);
    // The layer-0 rule is SUBSTITUTION, not deferral: an entity on layer 0
    // takes the layer it is placed through, which is what the context carries.
    // When nothing substitutes — a root-level entity, or an instance chain that
    // is itself all layer 0 — the effective layer is still layer 0, and layer 0
    // is a real DXF layer whose record governs. Skipping the lookup there would
    // make layer 0's record unreachable and would quietly give BYLAYER the
    // meaning of BYBLOCK.
    final layer =
        entityLayer == ReservedHandles.layerZero ? ctx.layer : entityLayer;
    final record = document.tables.layers[layer];

    final encoded = document.entities.colorAt(slot);
    final color = switch (encoded) {
      kByBlock => ctx.color,
      kByLayer => _concreteLayerColor(record, ctx),
      _ => encoded,
    };

    final lw = document.entities.lineweightAt(slot);
    final lineweight = switch (lw) {
      kByBlock => ctx.lineweight,
      kByLayer => record?.lineweight ?? ctx.lineweight,
      kLineweightDefault => ctx.lineweight,
      _ => lw,
    };

    final tr = document.entities.transparencyAt(slot);
    final transparency = switch (tr) {
      kByBlock => ctx.transparency,
      kByLayer => record?.transparency ?? ctx.transparency,
      _ => tr,
    };

    final lt = document.entities.linetypeAt(slot);
    final linetype = lt == ReservedHandles.byBlockLinetype
        ? ctx.linetype
        : lt == ReservedHandles.byLayerLinetype
            ? (record?.linetype ?? ctx.linetype)
            : lt;

    return ResolvedStyle(
      argb: ((255 - transparency.clamp(0, 255)) << 24) | _rgbOf(color),
      lineweightHundredths:
          lineweight == kLineweightDefault ? ctx.lineweight : lineweight,
      linetype: linetype,
      linetypeScale: document.entities.linetypeScaleAt(slot),
    );
  }

  int _layerColorOf(Handle layer, StyleContext inherited) =>
      _concreteLayerColor(document.tables.layers[layer], inherited);

  int _concreteLayerColor(LayerRecord? record, StyleContext ctx) {
    if (record == null) return ctx.color;
    final encoded = encodeColor(record.color);
    // A layer whose own colour is BYLAYER or BYBLOCK is malformed; the context
    // is the only defined answer left.
    return (encoded == kByLayer || encoded == kByBlock) ? ctx.color : encoded;
  }

  int _rgbOf(int encoded) => switch (decodeColor(encoded)) {
        IndexedColor(:final aci) => aciToRgb(aci),
        TrueColor(:final rgb) => rgb,
        // Unreachable: both branches resolve to a concrete value above.
        _ => aciToRgb(7),
      };
}
