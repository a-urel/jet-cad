// The restaurant kit's service unit: every seated symbol is a numbered
// table whose capacity is its seat count (spec 4a decision 10).
//
// Pure Dart: no Flutter, no dart:io.
import 'package:jet_cad_2d_kit/authoring.dart';

/// The unit of a symbol that seats [capacity]: a numbered `table`.
CatalogUnit tableUnit(int capacity) => CatalogUnit(
      kind: UnitKinds.table,
      capacity: capacity,
      labelling: UnitLabelling.numbered,
    );
