// The one command that gives a placed unit a label (spec 2b S2 "The
// label", S3 setUnitLabel; Task 10's unit section): the label ATTRIB's
// text when the unit has one, its own tag passed back (a blank tag would
// lose it), else a new UNIT ATTRIB stamped as the placer stamps a numbered
// unit's (today's _writeNumber and addTableLabelCommand,
// selection_panel.dart:663-683, tables/table_label.dart:105-153).
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show kUnitLabelTag;

import 'unit_index.dart';
import 'unit_label.dart' show addUnitLabelCommand;

/// The command that makes [text] the label of the placed unit [unit] of
/// [doc], or null when [text] already is its label (compared trimmed, as
/// the label reads). Allocates one handle for a new label. The caller has
/// checked the text rule and that no other unit holds [text].
DraftCommand? unitLabelCommand(DraftDocument doc, UnitInfo unit, String text) {
  if ((unit.text ?? '') == text.trim()) return null;
  final label = unit.label;
  if (label != null) return SetEntityTextCommand(label, text, kUnitLabelTag);
  final node = doc.tree[unit.instance]! as InstanceNode;
  return addUnitLabelCommand(doc,
      instance: unit.instance,
      definition: node.definition,
      placement: node.transform,
      text: text);
}
