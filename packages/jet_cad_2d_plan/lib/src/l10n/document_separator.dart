// Spec Q0 N1 (the assumed Q2): a new plan takes the UI language's decimal
// separator. Applied, wherever a context exists, to
// `PlanStrings.of(context)`, so a host's own language class gives the
// separator its panels use.
// Ported from jet_cad_floor_plan (2a Task 9).
import 'package:jet_cad_2d/jet_cad_2d.dart' show DecimalSeparator;

import 'strings.dart';

/// The decimal separator a new plan takes in [strings]' language (N1):
/// [DecimalSeparator.comma] when the language's panels print `,`
/// ([PlanStrings.decimalSeparator]), [DecimalSeparator.point]
/// otherwise. Only a new plan reads it: nothing converts a plan that exists
/// (N2).
DecimalSeparator documentSeparatorFor(PlanStrings strings) =>
    strings.decimalSeparator == ','
        ? DecimalSeparator.comma
        : DecimalSeparator.point;
