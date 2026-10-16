// Spec P5 "Words": the widgets push the app's Localizations locale into
// controller.locale; a kit's KitWords read it live. Every widget of the
// plan library calls [PlanLocaleScope.push] from didChangeDependencies
// (which a change of the app's locale triggers, through the dependency
// `maybeLocaleOf` registers) and when it is handed another controller.
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../controller/plan_controller.dart';
import 'strings.dart';

/// Pushes the locale of a widget's [Localizations] into its controller.
abstract final class PlanLocaleScope {
  static const Locale _english = Locale('en');

  /// Reports [context]'s locale and its [PlanStrings] to [controller]
  /// (`reportLocale`, Task 8, with this task's `strings:`),
  /// English when no [Localizations] is above (as `PlanStrings.of` answers
  /// English there), and registers [context] as a dependent of the locale.
  ///
  /// Never notifies during a build: the report lands after the current
  /// frame (one is scheduled when none is pending), and only while
  /// [context] is still mounted and [controller] not disposed (a host may
  /// dispose it in the frame the report was owed in, Task 15); an
  /// unchanged locale notifies nothing.
  static void push(BuildContext context, PlanController controller) {
    final next = Localizations.maybeLocaleOf(context) ?? _english;
    // The language class too (a host's own gives its own separator: NS7).
    final strings = PlanStrings.of(context);
    // Taken in now so the build that follows words a notice in the new
    // language (spec 4a O4); the listeners hear of it after the frame.
    controller.adoptLocale(next);
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (context.mounted && !controller.isDisposed) {
          controller.reportLocale(next, strings: strings);
        }
      })
      ..ensureVisualUpdate();
  }
}
