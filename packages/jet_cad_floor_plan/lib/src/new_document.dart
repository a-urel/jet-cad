// The empty document, and the set-up every document the app makes shares
// (spec 12a D4). New and launch call [newDocument]; the sample
// (`startupPlan`) starts from [prepareDocument] and draws its flat on it.
// An opened file does neither: it is decoded with `registerAppComponents`
// and gets no DASHED record (spec 12a D8, R-3).
//
// No Flutter import: this file is Dart over `package:jet_cad_2d` only.
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'parametric/catalog.dart';
import 'parametric/separator.dart';

/// A fresh document over [measurer] with the app's set-up and nothing else
/// (spec 12a D4): the app's component types registered, once
/// ([registerAppComponents]); the header's units millimetres (the header's
/// own default is unitless); the DASHED linetype record at handle 6,
/// outside the history (spec 10 D3). No page, no entity, no history.
DraftDocument prepareDocument(TextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  registerAppComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  ensureDashedLinetype(doc);
  return doc;
}

/// The page a new document gets (spec 12a D4, S-3, T-11): A4 landscape at
/// 1:50 in metres, every field at its default, with a **fixed origin**. The
/// sheet is 297 × 210 paper mm, 14,850 × 10,500 world mm at 1:50, so this
/// origin centres it on the world origin. Not centred on the extents, as
/// the sample's page is: an empty document's extents have a NaN centre,
/// which the page refuses.
///
/// Its [decimalSeparator] is the one the plan's text prints with (spec Q0
/// N1): a caller with a language passes that language's
/// (`documentSeparatorFor`); without one it is the engine's default,
/// [DecimalSeparator.point].
///
/// A function, not a constant: `PageComponent`'s constructor validates its
/// fields, so it is not `const`.
PageComponent defaultPage(
        {DecimalSeparator decimalSeparator = DecimalSeparator.point}) =>
    PageComponent(
        originX: -7425, originY: -5250, decimalSeparator: decimalSeparator);

/// The document New and launch open (spec 12a D4): [prepareDocument], then
/// [defaultPage] with [decimalSeparator] attached through the log (spec Q0
/// N1), then the history cleared, so a fresh document has Undo disabled
/// and the host's save point finds it clean.
DraftDocument newDocument(TextMeasurer measurer,
    {DecimalSeparator decimalSeparator = DecimalSeparator.point}) {
  final doc = prepareDocument(measurer);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle, defaultPage(decimalSeparator: decimalSeparator)));
  doc.commands.clearHistory();
  return doc;
}
