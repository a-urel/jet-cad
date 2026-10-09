import 'package:jet_cad_2d/jet_cad_2d.dart' show DraftDocument;

import 'selection.dart';
import 'tool.dart';

/// What the select tool and the grip cache may do, asked live (host
/// embedding API spec C-5, F-15; Slice 4's S-9 and S-15): a pick override,
/// a band filter, and the move, rotate, reshape, delete and idle-key gates.
///
/// Every member allows by default, so [SelectGates.all] (and no gates at
/// all) is today's select tool. An application extends this class and
/// overrides what it restricts; its answers may change at any time.
///
/// **Read at each press, hover, key and frame, never captured.** The select
/// tool asks at the press (the pick), at the slop (the drag's gate), at the
/// up (the drag's gate again, S-9h: a drag whose gate closed meanwhile is
/// cancelled and executes nothing), at the band's release and at each key;
/// the grip cache asks at each hit test and the overlay at each frame. A
/// getter here must therefore be cheap and allocate nothing. A change that
/// should reach the screen before the next pointer event is announced with
/// `GripCache.gatesChanged`.
class SelectGates {
  const SelectGates();

  /// Every gate open, no pick override: today's select tool.
  static const SelectGates all = SelectGates();

  /// Whether [pick] replaces the tool's own pick (the index's topmost hit),
  /// for presses **and** hovers. False by default.
  bool get restrictsPick => false;

  /// The key a press or hover at [e] picks, or null for none; asked only
  /// while [restrictsPick]. A pick filtered after the index's topmost hit
  /// would miss what lies under it (S-15), so this answers the whole pick.
  SelectionKey? pick(ToolPointerEvent e, ToolContext ctx) => null;

  /// Whether a rubber band may select [key] of [d]: a band selects only the
  /// keys this accepts. True by default.
  bool bandAccepts(DraftDocument d, SelectionKey key) => true;

  /// A body drag and a centre (`GripRole.move`) grip drag move the
  /// selection; the move cursor shows only while this is true.
  bool get move => true;

  /// The rotation grip is drawn, hit and dragged.
  bool get rotate => true;

  /// Every grip but the centre one is drawn, hit and dragged.
  bool get reshape => true;

  /// Delete and Backspace delete the selection while no gesture runs.
  bool get delete => true;

  /// The tool's own keys act while no gesture runs: Escape (clearing the
  /// selection), Delete and Backspace. A gesture's own keys (a drag's
  /// Escape and Shift) are the gesture's, whatever this says (S-16).
  bool get idleKeys => true;
}
