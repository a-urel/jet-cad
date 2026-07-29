/// Test and benchmark fixtures. **Not** part of the package's public surface —
/// `jet_cad_2d.dart` deliberately does not export this. It lives in `lib/` for
/// one reason: the Flutter package's render rigs and this package's query
/// benchmark must generate byte-identical documents, and a file under
/// `benchmark/` cannot be imported across packages.
library;

export 'src/testing/generate_document.dart';
