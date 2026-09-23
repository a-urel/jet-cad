import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'shortcut_guard.dart';

/// Ruling 05-11: the field's size. Its bottom-left sits at the insertion
/// point's screen position.
const Size kTextEntrySize = Size(240, 32);

/// Spec 05 D9: the inline field for [TextTool].
///
/// **Where it sits.** Outside the `InteractionLayer`, so a click on it is
/// not a canvas click.
///
/// **Keys.** The guard lets the shell's letters through as text, and
/// Escape cancels.
///
/// **Rebuilds.** The field is a stable child of the camera builder, so a pan
/// or zoom moves it and never rebuilds it (Ruling 05-10).
///
/// **Commit and cancel.** Enter commits. Any other loss of focus cancels
/// if the placement is still pending. A canvas click has already committed
/// synchronously in the tool, so its blur finds nothing to cancel.
class TextEntryOverlay extends StatefulWidget {
  const TextEntryOverlay({
    super.key,
    required this.tool,
    required this.tools,
    required this.camera,
  });

  final TextTool tool;
  final ToolController tools;
  final CameraController camera;

  @override
  State<TextEntryOverlay> createState() => _TextEntryOverlayState();
}

class _TextEntryOverlayState extends State<TextEntryOverlay> {
  final FocusNode _focus = FocusNode(debugLabel: 'text-entry');

  @override
  void initState() {
    super.initState();
    widget.tool.pending.addListener(_onPending);
    _focus.addListener(_onFocus);
  }

  /// A placement takes focus for the field; Ruling 05-7 hands it back to
  /// the canvas, the scope's previous child, as soon as the placement ends.
  ///
  /// `autofocus` alone never fires here: the canvas already holds focus (the
  /// layer requests it on the very click that placed the point), and
  /// autofocus only acts on a scope with nothing focused. The field is not
  /// built yet, so the request is deferred until its `Focus` attaches.
  void _onPending() {
    if (widget.tool.pending.value != null) {
      _focus.requestFocus();
    } else if (_focus.hasFocus) {
      _focus.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    }
  }

  /// Spec 05 D9's "any other loss of focus" means one inside the app
  /// (Ruling T7-b). A window switch moves primary focus to the root scope on
  /// `inactive`, and the focus manager restores it on `resumed`; cancelling
  /// here would detach the field and leave the shell's shortcuts dead. The
  /// state is null until the first lifecycle message (and in tests), which
  /// is not a window switch.
  void _onFocus() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    if (!_focus.hasFocus && widget.tool.pending.value != null) {
      widget.tool.cancelText(widget.tools.context);
    }
  }

  void _submit(String s) => widget.tool.commitText(s, widget.tools.context);

  void _cancel() => widget.tool.cancelText(widget.tools.context);

  @override
  void dispose() {
    widget.tool.pending.removeListener(_onPending);
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TextPlacement?>(
        valueListenable: widget.tool.pending,
        builder: (context, placed, _) {
          if (placed == null) return const SizedBox.shrink();
          final field = SizedBox.fromSize(
            key: const Key('text-entry-box'),
            size: kTextEntrySize,
            child: ShellShortcutGuard(
              child: CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.escape): _cancel,
                },
                child: TextField(
                  key: const Key('text-entry'),
                  controller: widget.tool.controller,
                  focusNode: _focus,
                  autofocus: true,
                  maxLines: 1,
                  // Without this, `EditableText` unfocuses on submit with
                  // `UnfocusDisposition.scope`, which clears the scope's
                  // focus history before `_onPending` can hand focus back
                  // to the canvas (Ruling 05-7).
                  onEditingComplete: () {},
                  onSubmitted: _submit,
                  decoration: const InputDecoration(
                      isDense: true, border: OutlineInputBorder()),
                ),
              ),
            ),
          );
          return Stack(
            children: [
              ListenableBuilder(
                listenable: widget.camera,
                builder: (context, child) {
                  final s = widget.camera.value.worldToScreen(placed.point);
                  return Positioned(
                    left: s.x,
                    top: s.y - kTextEntrySize.height,
                    child: child!,
                  );
                },
                child: field,
              ),
            ],
          );
        },
      );
}
