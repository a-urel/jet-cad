// The document a new plan opens with (today's spec 12a D4, Q0 N1): the
// plan's components registered, millimetres, the default page, no history.
// Ported from jet_cad_floor_plan's new_document.dart, without its DASHED
// linetype (the separator's, sub-project 3) and with the registration
// passed in (the kits').
import 'dart:ui' show Locale;

import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../l10n/document_separator.dart';
import '../l10n/strings.dart';

/// A4 landscape at 1:50 in metres, every field at its default, with a
/// fixed origin that centres the sheet on the world origin.
PageComponent defaultPlanPage(
        {DecimalSeparator decimalSeparator = DecimalSeparator.point}) =>
    PageComponent(
        originX: -7425, originY: -5250, decimalSeparator: decimalSeparator);

/// A new plan's document over [measurer]: [register] run once on its
/// registry, millimetres, [defaultPlanPage] attached through the log, then
/// the history cleared, so Undo is off and the save point finds it clean.
DraftDocument newPlanDocument(TextMeasurer measurer,
    {required void Function(ComponentRegistry registry) register,
    DecimalSeparator decimalSeparator = DecimalSeparator.point}) {
  final doc = DraftDocument.empty(measurer: measurer);
  register(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle, defaultPlanPage(decimalSeparator: decimalSeparator)));
  doc.commands.clearHistory();
  return doc;
}

/// The separator a new plan takes in [locale]'s language: the built-in
/// language's ([PlanStrings.forLocale]), so comma for German and Turkish,
/// point otherwise (today's `documentSeparatorFor` over
/// `FloorPlanStrings.forLocale`): the plan library's one mapping.
DecimalSeparator decimalSeparatorFor(Locale locale) =>
    documentSeparatorFor(PlanStrings.forLocale(locale));
