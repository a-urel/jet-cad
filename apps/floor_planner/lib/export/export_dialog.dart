// The Export dialog (spec 13 D8): the format, PDF or PNG, and for a PNG its
// resolution, 96, 150 or 300 dpi; Export or Cancel. Escape cancels.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show ExportDpi;

/// What an export writes (spec 13 D8).
enum ExportFormat { pdf, png }

/// The dialog's answer: the format and, for a PNG, the resolution. A PDF
/// keeps the last resolution chosen, so switching back to PNG shows it.
@immutable
final class ExportChoice {
  const ExportChoice({required this.format, required this.dpi});

  /// The first choice of an app session (spec 13 D8): PDF, 150 dpi.
  static const ExportChoice initial =
      ExportChoice(format: ExportFormat.pdf, dpi: ExportDpi.d150);

  final ExportFormat format;
  final ExportDpi dpi;

  ExportChoice copyWith({ExportFormat? format, ExportDpi? dpi}) =>
      ExportChoice(format: format ?? this.format, dpi: dpi ?? this.dpi);

  @override
  bool operator ==(Object other) =>
      other is ExportChoice && other.format == format && other.dpi == dpi;

  @override
  int get hashCode => Object.hash(format, dpi);

  @override
  String toString() => 'ExportChoice(${format.name}, ${dpi.value} dpi)';
}

/// Asks for the export's format and resolution, starting from [initial].
/// Null when cancelled (Cancel, Escape or a tap outside).
Future<ExportChoice?> showExportDialog(
        BuildContext context, ExportChoice initial) =>
    showDialog<ExportChoice>(
      context: context,
      builder: (_) => _ExportDialog(initial: initial),
    );

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.initial});

  final ExportChoice initial;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late ExportChoice _choice = widget.initial;

  void _cancel() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): _cancel,
        },
        child: AlertDialog(
          key: const Key('export-dialog'),
          title: const Text('Export'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<ExportFormat>(
                key: const Key('export-format'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: ExportFormat.pdf,
                      label: Text('PDF', key: Key('export-format-pdf'))),
                  ButtonSegment(
                      value: ExportFormat.png,
                      label: Text('PNG', key: Key('export-format-png'))),
                ],
                selected: {_choice.format},
                onSelectionChanged: (s) => setState(
                    () => _choice = _choice.copyWith(format: s.single)),
              ),
              if (_choice.format == ExportFormat.png) ...[
                const SizedBox(height: 12),
                SegmentedButton<ExportDpi>(
                  key: const Key('export-dpi'),
                  showSelectedIcon: false,
                  segments: [
                    for (final d in ExportDpi.values)
                      ButtonSegment(
                          value: d,
                          label: Text('${d.value} dpi',
                              key: Key('export-dpi-${d.value}'))),
                  ],
                  selected: {_choice.dpi},
                  onSelectionChanged: (s) =>
                      setState(() => _choice = _choice.copyWith(dpi: s.single)),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              key: const Key('export-cancel'),
              onPressed: _cancel,
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('export-ok'),
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(_choice),
              child: const Text('Export'),
            ),
          ],
        ),
      );
}
