// Spec P4 "The failure boundary", the section row: a kit's section builder
// that throws leaves a small "section failed" box in its place; a widget
// it returned that fails while building shows Flutter's ErrorWidget in its
// place only, and the plan stays usable. The diagnostic is published after
// the frame (a build must not notify).
import 'package:flutter/material.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../l10n/strings.dart';
import 'guard.dart';

/// Builds a kit's property section through [builder], behind the boundary.
class KitSectionBoundary extends StatelessWidget {
  const KitSectionBoundary({
    super.key,
    required this.kitId,
    required this.typeId,
    required this.log,
    required this.builder,
  });

  final String kitId;
  final String typeId;
  final DiagnosticsLog log;

  /// Calls the type's section (`PlanType.sectionFor`); null for none.
  final Widget? Function(BuildContext context) builder;

  @override
  Widget build(BuildContext context) {
    final Widget? section;
    try {
      section = builder(context);
    } catch (error) {
      log.addAfterFrame(KitDiagnostic(
          kitId: kitId,
          subject: typeId,
          code: KitDiagnosticCode.hookFailed,
          message: 'section: $error',
          error: error));
      final scheme = Theme.of(context).colorScheme;
      return Container(
        key: const Key('kit-section-failed'),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.error),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(PlanStrings.of(context).sectionFailed,
            style: TextStyle(color: scheme.error)),
      );
    }
    return section ?? const SizedBox.shrink();
  }
}
