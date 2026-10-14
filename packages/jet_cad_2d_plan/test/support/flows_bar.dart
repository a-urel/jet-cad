// The editor bar's two page buttons over EditorPageFlows, as Task 20's
// PlanEditorBar has them: Export (`toolbar-export`) only with onExport and
// while permissions.export is on; Print (`toolbar-print`) while
// permissions.print is on; each enabled while the controller's flows are
// ready. The flows read this widget's fields at each call.
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/export/editor_page_flows.dart';
import 'package:jet_cad_2d_plan/src/export/export_dialog.dart';
import 'package:jet_cad_2d_plan/src/export/page_printer.dart';
import 'package:jet_cad_2d_plan/src/export/registries.dart';

class FlowsBar extends StatefulWidget {
  const FlowsBar(
      {super.key,
      required this.controller,
      this.onExport,
      this.printer,
      this.exportName = 'plan',
      this.onExportDialog,
      this.onPageFlowError});

  final PlanController controller;
  final void Function(PlanExport export)? onExport;
  final PagePrinter? printer;
  final String exportName;
  final PlanExportDialog? onExportDialog;
  final void Function(Object error)? onPageFlowError;

  @override
  State<FlowsBar> createState() => FlowsBarState();
}

class FlowsBarState extends State<FlowsBar> {
  late EditorPageFlows flows = _flowsFor(widget.controller);

  EditorPageFlows _flowsFor(PlanController c) => EditorPageFlows(
        controller: c,
        settings: () => (
          onExport: widget.onExport,
          printer: widget.printer ?? const PrintingPagePrinter(),
          exportName: widget.exportName,
        ),
        hooks: () => (
          exportDialog: widget.onExportDialog,
          onError: widget.onPageFlowError,
        ),
      );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(FlowsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
      flows.dispose();
      flows = _flowsFor(widget.controller);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    flows.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Widget _button(String key, IconData icon, VoidCallback run) =>
      ValueListenableBuilder<bool>(
        valueListenable: flows.ready,
        builder: (_, ready, __) => IconButton(
            key: Key(key), icon: Icon(icon), onPressed: ready ? run : null),
      );

  @override
  Widget build(BuildContext context) {
    final permissions = widget.controller.permissions;
    return Material(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (flows.canExport && permissions.export)
          _button('toolbar-export', Icons.ios_share_outlined,
              () => unawaited(flows.export(context))),
        if (permissions.print)
          _button('toolbar-print', Icons.print_outlined,
              () => unawaited(flows.print(context))),
      ]),
    );
  }
}
