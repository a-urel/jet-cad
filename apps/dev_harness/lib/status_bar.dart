import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Bottom status strip: current harness status on the left, current selection
/// summary on the right.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.status, required this.selection});

  final String status;
  final List<int> selection;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final ids = selection.isEmpty ? '—' : selection.join(', ');
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border(top: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Row(
        children: [
          Text(status, style: theme.textTheme.small),
          const Spacer(),
          Text('selection: $ids', style: theme.textTheme.muted),
        ],
      ),
    );
  }
}
