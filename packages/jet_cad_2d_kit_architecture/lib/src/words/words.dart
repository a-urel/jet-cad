// The architecture kit's words (spec 3a C2 "Words", C1.6): tool:, type:,
// property: and text: ids in English, German and Turkish. Task 23 adds the
// furniture library's symbol: and category: words.
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show KitNames;

import 'de.dart';
import 'en.dart';
import 'tr.dart';

/// The kit's words by locale.
const KitNames architectureNames =
    KitNames({'en': englishWords, 'de': germanWords, 'tr': turkishWords});

/// The words whose right word is the English one, per locale: conformance's
/// `sameAsEnglish` (contract K7). The dimension's notice is the value alone
/// in every language.
const Map<String, Set<String>> architectureSameAsEnglish = {
  'de': {
    'property:architecture.opening.position',
    'property:architecture.room.name',
    'property:architecture.dimension.kind.horizontal',
    'text:architecture.dimension-value',
  },
  'tr': {
    'text:architecture.dimension-value',
  },
};
