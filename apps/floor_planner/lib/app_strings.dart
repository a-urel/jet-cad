// The floor planner app's own words (spec 14d L16): its file commands and
// dialogs, in English, German and Turkish, by the resolved locale; the
// planner's words come from the package.
import 'package:flutter/widgets.dart';

import 'document_files.dart' show FileKind;

/// The app's words in one language.
abstract class AppStrings {
  const AppStrings();

  /// The words for [context]'s locale; English for any other.
  static AppStrings of(BuildContext context) =>
      switch (Localizations.maybeLocaleOf(context)?.languageCode) {
        'de' => const _De(),
        'tr' => const _Tr(),
        _ => const _En(),
      };

  /// "New".
  String get newDocument;

  /// "Open…".
  String get open;

  /// "Open sample".
  String get openSample;

  /// "Save".
  String get save;

  /// "Save As…".
  String get saveAs;

  /// "Untitled".
  String get untitled;

  /// A file type's name in the open and save panels (L16, review 14d-1
  /// F-5).
  String fileTypeLabel(FileKind kind);

  /// "Could not open the file".
  String get couldNotOpenFile;

  /// "Export failed".
  String get exportFailed;

  /// "Print failed".
  String get printFailed;

  /// "OK".
  String get ok;

  /// "Your changes are lost if you do not save them.".
  String get changesLost;

  /// "Don't Save".
  String get dontSave;

  /// "Save as".
  String get saveAsTitle;

  /// "File name".
  String get fileName;

  String couldNotOpen(String name);

  String couldNotSave(String name);

  String saveChangesTo(String name);
}

final class _En extends AppStrings {
  const _En();

  @override
  String get newDocument => 'New';

  @override
  String get open => 'Open…';

  @override
  String get openSample => 'Open sample';

  @override
  String get save => 'Save';

  @override
  String get saveAs => 'Save As…';

  @override
  String get untitled => 'Untitled';

  @override
  String fileTypeLabel(FileKind kind) => switch (kind) {
        FileKind.jetplan => 'Jet plan',
        FileKind.pdf => 'PDF document',
        FileKind.png => 'PNG image',
      };

  @override
  String get couldNotOpenFile => 'Could not open the file';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get printFailed => 'Print failed';

  @override
  String get ok => 'OK';

  @override
  String get changesLost => 'Your changes are lost if you do not save them.';

  @override
  String get dontSave => 'Don\'t Save';

  @override
  String get saveAsTitle => 'Save as';

  @override
  String get fileName => 'File name';

  @override
  String couldNotOpen(String name) => 'Could not open $name';

  @override
  String couldNotSave(String name) => 'Could not save $name';

  @override
  String saveChangesTo(String name) => 'Save the changes to $name?';
}

final class _De extends AppStrings {
  const _De();

  @override
  String get newDocument => 'Neu';

  @override
  String get open => 'Öffnen…';

  @override
  String get openSample => 'Beispiel öffnen';

  @override
  String get save => 'Speichern';

  @override
  String get saveAs => 'Speichern unter…';

  @override
  String get untitled => 'Unbenannt';

  @override
  String fileTypeLabel(FileKind kind) => switch (kind) {
        FileKind.jetplan => 'Jet-Plan',
        FileKind.pdf => 'PDF-Dokument',
        FileKind.png => 'PNG-Bild',
      };

  @override
  String get couldNotOpenFile => 'Die Datei konnte nicht geöffnet werden';

  @override
  String get exportFailed => 'Export fehlgeschlagen';

  @override
  String get printFailed => 'Drucken fehlgeschlagen';

  @override
  String get ok => 'OK';

  @override
  String get changesLost =>
      'Ihre Änderungen gehen verloren, wenn Sie sie nicht speichern.';

  @override
  String get dontSave => 'Nicht speichern';

  @override
  String get saveAsTitle => 'Speichern unter';

  @override
  String get fileName => 'Dateiname';

  @override
  String couldNotOpen(String name) => '$name konnte nicht geöffnet werden';

  @override
  String couldNotSave(String name) => '$name konnte nicht gespeichert werden';

  @override
  String saveChangesTo(String name) => 'Änderungen an $name speichern?';
}

final class _Tr extends AppStrings {
  const _Tr();

  @override
  String get newDocument => 'Yeni';

  @override
  String get open => 'Aç…';

  @override
  String get openSample => 'Örneği aç';

  @override
  String get save => 'Kaydet';

  @override
  String get saveAs => 'Farklı kaydet…';

  @override
  String get untitled => 'Adsız';

  @override
  String fileTypeLabel(FileKind kind) => switch (kind) {
        FileKind.jetplan => 'Jet planı',
        FileKind.pdf => 'PDF belgesi',
        FileKind.png => 'PNG görüntüsü',
      };

  @override
  String get couldNotOpenFile => 'Dosya açılamadı';

  @override
  String get exportFailed => 'Dışa aktarma başarısız';

  @override
  String get printFailed => 'Yazdırma başarısız';

  @override
  String get ok => 'Tamam';

  @override
  String get changesLost => 'Kaydetmezseniz değişiklikleriniz kaybolur.';

  @override
  String get dontSave => 'Kaydetme';

  @override
  String get saveAsTitle => 'Farklı kaydet';

  @override
  String get fileName => 'Dosya adı';

  @override
  String couldNotOpen(String name) => '$name açılamadı';

  @override
  String couldNotSave(String name) => '$name kaydedilemedi';

  @override
  String saveChangesTo(String name) =>
      '$name belgesindeki değişiklikler kaydedilsin mi?';
}
