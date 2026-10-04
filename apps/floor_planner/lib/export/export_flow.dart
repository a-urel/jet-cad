// What the Export and Print flows (spec 13 D8, D9) read and make, apart
// from their dialogs, files and printer. The page, the owners, the bytes
// and the paper size moved to the package (spec 14b-2 H6) and are
// re-exported here; the file kind and name stay with the app's files. The
// host (`document_host.dart`) runs the flows themselves, under busy, after
// its settle.
import 'package:jet_cad_floor_plan/editor.dart';

import '../document_files.dart';

export 'package:jet_cad_floor_plan/editor.dart'
    show
        exportBytes,
        exportOmitOwners,
        exportPageOf,
        exportPdfBytes,
        printPageFormat;

/// The file kind [choice] writes.
FileKind exportFileKind(ExportChoice choice) => switch (choice.format) {
      ExportFormat.pdf => FileKind.pdf,
      ExportFormat.png => FileKind.png,
    };

/// The name the save offers for the document [name]: `<name>.pdf` or
/// `<name>.png` (spec 13 D8).
String exportFileName(String name, ExportChoice choice) =>
    '$name.${exportFileKind(choice).extension}';
