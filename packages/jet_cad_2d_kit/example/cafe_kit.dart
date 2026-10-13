// The kit's descriptor (docs/kits.md section 6).
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import 'example.dart';

final PlanKit cafeKit = PlanKit(
  id: 'cafe',
  version: '0.1.0',
  symbols: [
    SymbolLibrarySource(
      label: 'cafe',
      read: bundledLibrary('packages/jet_cad_2d_kit_cafe/assets/cafe.jetlib'),
    ),
  ],
  names: cafeNames,
);
