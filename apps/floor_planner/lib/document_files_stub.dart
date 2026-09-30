// `DocumentFiles` where neither the io library nor JS interop exists
// (spec 12a D9): `document_files.dart` exports this by default, so the
// selection always resolves. No platform the app ships on reaches it.
import 'document_files.dart';

/// No platform implementation exists here; always throws
/// [UnsupportedError].
DocumentFiles createDocumentFiles({required DocumentNamePrompt askName}) =>
    throw UnsupportedError('DocumentFiles: no file access on this platform');
