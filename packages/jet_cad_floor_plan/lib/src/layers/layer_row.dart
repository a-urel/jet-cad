// Spec 12b D9: one row of the Layers panel. A row holds no document state
// of its own: the panel hands it the record, the flags it derived from the
// document and the callbacks that dispatch; the row keeps only the inline
// rename field's text, focus and error while the field is open.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../l10n/strings.dart';
import '../panel_focus.dart';
import '../shortcut_guard.dart';

/// The colours a layer may be given (spec 12b decision 6): ACI 1–9, with
/// their names in the colour menu.
const List<(int, String)> kLayerColours = [
  (1, 'Red'),
  (2, 'Yellow'),
  (3, 'Green'),
  (4, 'Cyan'),
  (5, 'Blue'),
  (6, 'Magenta'),
  (7, 'Foreground'),
  (8, 'Dark grey'),
  (9, 'Light grey'),
];

/// The `0xRRGGBB` a layer of [color] is drawn in, as the style resolver
/// draws it: ACI 7 (and anything that is not a colour of its own) in the
/// paper's [foreground], another index through [aciToRgb], a true colour as
/// stored.
int layerSwatchRgb(DraftColor color, int foreground) => switch (color) {
      IndexedColor(aci: 7) => foreground,
      IndexedColor(:final aci) => aciToRgb(aci),
      TrueColor(:final rgb) => rgb,
      _ => foreground,
    };

/// One layer of the Layers panel (spec 12b D9): the current-layer mark, the
/// eye, the lock, the colour swatch and its menu, and the name, which a
/// double-click turns into an inline field.
///
/// Every control is disabled when [enabled] is false (D11). The mark is
/// disabled on a hidden layer (decision 7); the eye's **hide** direction is
/// disabled on the effective current layer ([current]), with a tooltip,
/// while showing is always enabled (S-6). Layer 0 cannot be renamed.
///
/// **The rename field** (key `layer-name-field-<hex>`) opens while
/// [editing]. Enter commits a valid name — the text trimmed, checked by
/// [validate] — through [onRename], once; an invalid one keeps the field
/// open with [validate]'s reason under it. Escape, and focus loss with an
/// invalid name, close it and dispatch nothing; focus loss with a valid
/// name commits it as Enter does. Every way out calls [onEndRename]. The
/// field sits in a [ShellShortcutGuard] with a nearer Escape binding, as
/// the symbol search does, so no shell shortcut fires while typing.
class LayerRow extends StatefulWidget {
  const LayerRow({
    super.key,
    required this.record,
    required this.current,
    required this.selected,
    required this.enabled,
    required this.editing,
    required this.foreground,
    required this.onSelect,
    required this.onMakeCurrent,
    required this.onToggleVisible,
    required this.onToggleLocked,
    required this.onColour,
    required this.onStartRename,
    required this.validate,
    required this.onRename,
    required this.onEndRename,
  });

  final LayerRecord record;

  /// Whether this is the effective current layer (`drawingLayer`).
  final bool current;

  /// Whether this row is the panel's selected row.
  final bool selected;

  /// Whether the permissions allow the panel's commands (D11).
  final bool enabled;

  /// Whether the name field is open.
  final bool editing;

  /// The paper's foreground, `0xRRGGBB`: ACI 7's colour.
  final int foreground;

  final VoidCallback onSelect;

  /// Null when this row's mark has nothing to do (it is already current).
  final VoidCallback? onMakeCurrent;
  final VoidCallback onToggleVisible;
  final VoidCallback onToggleLocked;
  final ValueChanged<int> onColour;
  final VoidCallback onStartRename;

  /// The reason a trimmed name cannot be this layer's, or null.
  final String? Function(String name) validate;

  /// Commits a valid, trimmed name that differs from the record's.
  final ValueChanged<String> onRename;
  final VoidCallback onEndRename;

  @override
  State<LayerRow> createState() => _LayerRowState();
}

class _LayerRowState extends State<LayerRow> {
  final TextEditingController _text = TextEditingController();
  final PanelFieldFocusNode _focus =
      PanelFieldFocusNode(debugLabel: 'layer name');

  /// The reason the last Enter was refused, shown under the field.
  String? _error;

  /// Whether the field is open and has not been closed by Enter, Escape or
  /// focus loss: a close hands the focus back, and the focus listener must
  /// then do nothing.
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    if (widget.editing) _begin();
  }

  @override
  void didUpdateWidget(LayerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editing && !oldWidget.editing) _begin();
    if (!widget.editing) _open = false;
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  String get _hex => widget.record.handle.toHex();

  void _begin() {
    _open = true;
    _error = null;
    _text.value = TextEditingValue(
        text: widget.record.name,
        selection: TextSelection(
            baseOffset: 0, extentOffset: widget.record.name.length));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_open) return;
      Scrollable.ensureVisible(context);
      _focus.requestFocus();
    });
  }

  /// Closes the field, committing [name] first when it is valid and new.
  void _close({String? commit}) {
    _open = false;
    if (commit != null && commit != widget.record.name) widget.onRename(commit);
    widget.onEndRename();
  }

  void _enter() {
    if (!_open) return;
    final name = _text.text.trim();
    final error = widget.validate(name);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    _close(commit: name);
    _focus.handBack();
  }

  void _escape() {
    if (!_open) return;
    _close();
    _focus.handBack();
  }

  void _onFocus() {
    if (_focus.hasFocus || !_open) return;
    final name = _text.text.trim();
    _close(commit: widget.validate(name) == null ? name : null);
  }

  @override
  Widget build(BuildContext context) {
    final strings = FloorPlanStrings.of(context);
    final r = widget.record;
    final enabled = widget.enabled;
    final scheme = Theme.of(context).colorScheme;
    final hideBlocked = r.visible && widget.current;
    final swatch =
        Color(0xFF000000 | layerSwatchRgb(r.color, widget.foreground));
    return Material(
      key: Key('layer-row-$_hex'),
      color: widget.selected ? scheme.secondaryContainer : Colors.transparent,
      child: InkWell(
        onTap: widget.onSelect,
        child: ConstrainedBox(
          // The field's error line makes an editing row taller.
          constraints: const BoxConstraints(minHeight: kLayerRowHeight),
          child: Row(
            children: [
              _icon(
                key: 'layer-current-$_hex',
                icon: widget.current
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                tooltip: !r.visible
                    ? strings.hiddenLayerNotCurrent
                    : widget.current
                        ? strings.currentLayer
                        : strings.makeCurrent,
                onPressed: enabled && r.visible ? widget.onMakeCurrent : null,
              ),
              _icon(
                key: 'layer-eye-$_hex',
                icon: r.visible ? Icons.visibility : Icons.visibility_off,
                tooltip: hideBlocked
                    ? strings.currentLayerNotHidden
                    : r.visible
                        ? strings.hideLayer
                        : strings.showLayer,
                onPressed:
                    enabled && !hideBlocked ? widget.onToggleVisible : null,
              ),
              _icon(
                key: 'layer-lock-$_hex',
                icon: r.locked ? Icons.lock : Icons.lock_open,
                tooltip: r.locked ? strings.unlockLayer : strings.lockLayer,
                onPressed: enabled ? widget.onToggleLocked : null,
              ),
              // Tight, so the button's own minimum size does not make the
              // row taller than the icons.
              SizedBox(
                width: 28,
                height: 28,
                child: PopupMenuButton<int>(
                  key: Key('layer-colour-$_hex'),
                  enabled: enabled,
                  tooltip: strings.layerColour,
                  padding: EdgeInsets.zero,
                  onSelected: widget.onColour,
                  itemBuilder: (context) => [
                    for (final (aci, _) in kLayerColours)
                      PopupMenuItem<int>(
                        key: Key('layer-colour-item-$aci'),
                        value: aci,
                        height: 32,
                        child: Row(children: [
                          _Swatch(Color(0xFF000000 |
                              layerSwatchRgb(
                                  IndexedColor(aci), widget.foreground))),
                          const SizedBox(width: 8),
                          Text(strings.colourName(aci)),
                        ]),
                      ),
                  ],
                  child: Center(child: _Swatch(swatch)),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(child: widget.editing ? _field() : _name()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon(
          {required String key,
          required IconData icon,
          required String tooltip,
          required VoidCallback? onPressed}) =>
      // Tight, as the colour button: a Material 3 icon button's minimum
      // size would otherwise make the row 40 high and leave the name less
      // room at 280 px.
      SizedBox(
        width: 28,
        height: 28,
        child: IconButton(
          key: Key(key),
          icon: Icon(icon),
          iconSize: 18,
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: onPressed,
        ),
      );

  Widget _name() {
    final canRename =
        widget.enabled && widget.record.handle != ReservedHandles.layerZero;
    return GestureDetector(
      key: Key('layer-name-$_hex'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onSelect,
      onDoubleTap: canRename ? widget.onStartRename : null,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          widget.record.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }

  Widget _field() => ShellShortcutGuard(
        // Nearer than the guard's own Escape (the symbol search's pattern):
        // Escape in the field reverts and hands the focus back.
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape): _escape,
          },
          child: TextField(
            key: Key('layer-name-field-$_hex'),
            controller: _text,
            focusNode: _focus,
            maxLines: 1,
            style: const TextStyle(fontSize: 13),
            // Enter is handled here, and does not unfocus by itself: an
            // invalid name keeps the field open.
            onEditingComplete: _enter,
            onTapOutside: (_) => _focus.handBack(),
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
        ),
      );
}

/// A row's height: the list's cap is a multiple of it.
const double kLayerRowHeight = 32;

class _Swatch extends StatelessWidget {
  const _Swatch(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(3),
        ),
      );
}
