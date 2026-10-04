// The furniture library as it shipped before 09c (plan 09c-1 Task 3b), for
// the tests that pin what a plan saved before 09c holds: the catalog test
// and the end-to-end test (Task 11).
import 'dart:io';

import 'package:jet_cad_floor_plan/src/symbols/symbol_library.dart';

/// The asset as it shipped before 09c (commit 9414208, byte-equal to `main`
/// 4d6b78f): the 27 version-1 symbols a plan saved before 09c holds. A test
/// fixture, not an asset: it is not declared in the pubspec.
const pre09cLibraryPath = 'test/fixtures/furniture_pre_09c.jetlib';

SymbolLibrary pre09cLibrary() =>
    SymbolLibrary.decode(File(pre09cLibraryPath).readAsBytesSync());
