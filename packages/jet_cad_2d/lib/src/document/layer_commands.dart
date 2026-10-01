import '../core/handle.dart';
import 'command.dart';
import 'style.dart';

/// The longest layer name, in UTF-16 code units (`String.length`), that a
/// user may give (spec 12b D4). DXF's own limit.
const int kMaxLayerNameLength = 255;

/// The characters DXF forbids in a table name (spec 12b D4).
const String kForbiddenLayerNameCharacters = '<>/\\":;?*|=`';

/// Why [name] cannot be a layer's name in [target], or null when it can
/// (spec 12b D4).
///
/// A name is valid when it is non-empty, equal to itself trimmed, at most
/// [kMaxLayerNameLength] UTF-16 code units, free of
/// [kForbiddenLayerNameCharacters], and not another layer's name under
/// `toLowerCase()` — `TableSection`'s own folding, so a name this accepts is
/// one `TableSection.add` accepts. [self] is the layer being renamed: its own
/// current name is not a duplicate, so a case-only rename is valid.
///
/// The user forms of the layer commands and the panel both call this; a name
/// loaded from a file is a stored value and is never checked against it.
String? layerNameError(CommandTarget target, String name, {Handle? self}) {
  if (name.isEmpty) return 'A layer name cannot be empty.';
  if (name != name.trim()) {
    return 'A layer name cannot start or end with a space.';
  }
  if (name.length > kMaxLayerNameLength) {
    return 'A layer name can be at most $kMaxLayerNameLength characters.';
  }
  for (var i = 0; i < name.length; i++) {
    final c = name[i];
    if (kForbiddenLayerNameCharacters.contains(c)) {
      return 'A layer name cannot contain $c.';
    }
  }
  final existing = target.tables.layers.byName(name);
  if (existing != null && existing.handle != self) {
    return 'A layer named ${existing.name} already exists.';
  }
  return null;
}

/// The **effective** current layer: the layer new drawing goes to (spec 12b
/// D3).
///
/// The stored `header.currentLayer` when it names an existing, visible layer;
/// otherwise layer 0. Every decision that says "current" — the commands'
/// checks, a layer's emptiness, the tools, the panel — uses this, never the
/// stored value. The stored value is not rewritten when it becomes unusable,
/// so showing a hidden stored current layer makes it current again.
Handle drawingLayer(CommandTarget target) {
  final stored = target.header.currentLayer;
  final record = target.tables.layers[stored];
  return record != null && record.visible ? stored : ReservedHandles.layerZero;
}
