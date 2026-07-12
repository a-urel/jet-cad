import 'package:flutter/widgets.dart' show IconData;

/// A no-argument action bound to a ribbon tool.
typedef RibbonAction = void Function();

/// One button in the ribbon. A tool with a null [onPressed] is decorative
/// (not implemented yet) — the ribbon shows a toast when it is tapped.
class RibbonTool {
  const RibbonTool(this.label, this.icon, {this.onPressed});

  final String label;
  final IconData icon;
  final RibbonAction? onPressed;

  bool get isDecorative => onPressed == null;
}

/// A titled cluster of related tools within a tab.
class RibbonGroup {
  const RibbonGroup(this.title, this.tools);

  final String title;
  final List<RibbonTool> tools;
}

/// A top-level ribbon tab (File, Sketch, Model, …).
class RibbonTab {
  const RibbonTab(this.title, this.groups);

  final String title;
  final List<RibbonGroup> groups;
}
