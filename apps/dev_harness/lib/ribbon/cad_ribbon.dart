import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'ribbon_model.dart';

/// Presentational CAD ribbon: a left-aligned [ShadTabs] bar whose selected tab
/// shows titled groups of tools. [quickActions] render as a leading "Edit"
/// group, present on every tab.
///
/// Live tools carry a [RibbonTool.onPressed]; decorative tools do not — tapping
/// one calls [onDecorative] if provided, else shows a "not implemented" toast.
class CadRibbon extends StatefulWidget {
  const CadRibbon({
    super.key,
    required this.tabs,
    this.quickActions = const [],
    this.onDecorative,
    this.initialTab,
  });

  final List<RibbonTab> tabs;
  final List<RibbonTool> quickActions;
  final void Function(String toolLabel)? onDecorative;
  final String? initialTab;

  @override
  State<CadRibbon> createState() => _CadRibbonState();
}

class _CadRibbonState extends State<CadRibbon> {
  late String _selected =
      widget.initialTab ?? (widget.tabs.isEmpty ? '' : widget.tabs.first.title);

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
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: ShadButton.ghost(
        // The default regular-size button clamps its content to a fixed
        // height sized for a single line, which clips this two-line
        // icon-over-label layout. height: 0 tells ShadButton to size itself
        // to its child instead (see shadcn_ui button.dart: "When the height
        // is 0, we set maxHeight to infinity to allow the button to size
        // itself based on its child").
        height: 0,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        onPressed: () => _handle(context, tool),
        child: SizedBox(
          width: 48,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tool.icon, size: 18),
              const SizedBox(height: 2),
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
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ShadCard(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final t in group.tools) _toolButton(context, t)],
            ),
            const SizedBox(height: 2),
            Text(group.title, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _tabContent(BuildContext context, RibbonTab tab) {
    // Quick actions (undo/redo/fit) lead every tab as an "Edit" group so they
    // stay reachable regardless of the active tab.
    final groups = <RibbonGroup>[
      if (widget.quickActions.isNotEmpty)
        RibbonGroup('Edit', widget.quickActions),
      ...tab.groups,
    ];
    // ShadTabs stacks the bar and content in a center-aligned Column, so a
    // content row narrower than the window floats to the middle. Pin it left.
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (final g in groups) _group(context, g)],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: ShadTabs<String>(
        value: _selected,
        // Content-size the tabs and cluster them left instead of stretching
        // each one to fill the bar (the non-scrollable default).
        scrollable: true,
        tabBarAlignment: Alignment.centerLeft,
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
    );
  }
}
