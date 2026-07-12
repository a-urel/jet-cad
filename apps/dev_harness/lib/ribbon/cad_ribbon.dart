import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'ribbon_model.dart';

/// Presentational CAD ribbon: a persistent quick-access strip (live actions)
/// above a [ShadTabs] bar whose selected tab shows titled groups of tools.
///
/// Live tools carry a [RibbonTool.onPressed]; decorative tools do not — tapping
/// one calls [onDecorative] if provided, else shows a "not implemented" toast.
class CadRibbon extends StatefulWidget {
  const CadRibbon({
    super.key,
    required this.tabs,
    this.quickActions = const [],
    this.onDecorative,
  });

  final List<RibbonTab> tabs;
  final List<RibbonTool> quickActions;
  final void Function(String toolLabel)? onDecorative;

  @override
  State<CadRibbon> createState() => _CadRibbonState();
}

class _CadRibbonState extends State<CadRibbon> {
  late String _selected = widget.tabs.isEmpty ? '' : widget.tabs.first.title;

  void _handle(BuildContext context, RibbonTool tool) {
    final onPressed = tool.onPressed;
    if (onPressed != null) {
      onPressed();
      return;
    }
    final onDecorative = widget.onDecorative;
    if (onDecorative != null) {
      onDecorative(tool.label);
      return;
    }
    ShadToaster.of(context).show(
      ShadToast(
        title: Text('🚧 ${tool.label}'),
        description: const Text('Not implemented yet'),
      ),
    );
  }

  Widget _toolButton(BuildContext context, RibbonTool tool) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ShadButton.ghost(
        // The default regular-size button clamps its content to a fixed
        // height sized for a single line, which clips this two-line
        // icon-over-label layout. height: 0 tells ShadButton to size itself
        // to its child instead (see shadcn_ui button.dart: "When the height
        // is 0, we set maxHeight to infinity to allow the button to size
        // itself based on its child").
        height: 0,
        onPressed: () => _handle(context, tool),
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tool.icon, size: 18),
              const SizedBox(height: 4),
              Text(
                tool.label,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group(BuildContext context, RibbonGroup group) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ShadCard(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final t in group.tools) _toolButton(context, t)],
            ),
            const SizedBox(height: 4),
            Text(group.title, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _tabContent(BuildContext context, RibbonTab tab) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (final g in tab.groups) _group(context, g)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.quickActions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final a in widget.quickActions)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ShadButton.ghost(
                      onPressed: () => _handle(context, a),
                      leading: Icon(a.icon, size: 16),
                      child: Text(a.label),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: ShadTabs<String>(
            value: _selected,
            onChanged: (v) => setState(() => _selected = v),
            tabs: [
              for (final tab in widget.tabs)
                ShadTab<String>(
                  value: tab.title,
                  content: _tabContent(context, tab),
                  child: Text(tab.title),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
