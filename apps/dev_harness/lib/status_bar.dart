import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'ribbon/ribbon_model.dart';

/// Bottom status strip: current harness status on the left, an optional cluster
/// of viewport navigation tools in the middle, and the current selection
/// summary on the right.
///
/// [navTools] are rendered as tooltip'd icon buttons; each is wired by the host
/// (a null [RibbonTool.onPressed] simply renders disabled).
class StatusBar extends StatelessWidget {
  const StatusBar({
    super.key,
    required this.status,
    required this.selection,
    this.navTools = const [],
  });

  final String status;
  final List<String> selection;
  final List<RibbonTool> navTools;

  Widget _navButton(RibbonTool tool) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: ShadTooltip(
        builder: (_) => Text(tool.label),
        child: ShadIconButton.ghost(
          icon: Icon(tool.icon, size: 14),
          width: 26,
          height: 26,
          padding: EdgeInsets.zero,
          onPressed: tool.onPressed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final ids = selection.isEmpty ? '—' : selection.join(', ');
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border(top: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Row(
        children: [
          Text(status, style: theme.textTheme.small),
          if (navTools.isNotEmpty) ...[
            const SizedBox(width: 16),
            for (final t in navTools) _navButton(t),
          ],
          const Spacer(),
          Text('selection: $ids', style: theme.textTheme.muted),
        ],
      ),
    );
  }
}
