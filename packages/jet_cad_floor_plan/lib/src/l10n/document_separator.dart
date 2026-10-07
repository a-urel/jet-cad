// Spec Q0 N1 (the assumed Q2): a new plan takes the UI language's decimal
// separator. Applied, wherever a context exists, to
// `FloorPlanStrings.of(context)`, so a host's own language class gives the
// separator its panels use.
import 'package:jet_cad_2d/jet_cad_2d.dart' show DecimalSeparator;

import 'strings.dart';

/// The decimal separator a new plan takes in [strings]' language (N1):
/// [DecimalSeparator.comma] when the language's panels print `,`
/// ([FloorPlanStrings.decimalSeparator]), [DecimalSeparator.point]
/// otherwise. Only a new plan reads it: nothing converts a plan that exists
/// (N2).
DecimalSeparator documentSeparatorFor(FloorPlanStrings strings) =>
    strings.decimalSeparator == ','
        ? DecimalSeparator.comma
        : DecimalSeparator.point;
