// The demo's own words (spec 14d L17), in English, German and Turkish, by
// the resolved locale; the planner's come from the package.
import 'package:flutter/widgets.dart';

/// The demo's words in one language.
abstract class DemoStrings {
  const DemoStrings();

  /// The words for [context]'s locale; English for any other.
  static DemoStrings of(BuildContext context) =>
      switch (Localizations.maybeLocaleOf(context)?.languageCode) {
        'de' => const _De(),
        'tr' => const _Tr(),
        _ => const _En(),
      };

  String get title;

  String get design;

  String get service;

  String get save;

  String get revert;

  String get resetLayout;

  String get fit;

  /// Zone spec Z22: the zones' title, the All tab and the fade switch.
  String get zones;

  String get allZones;

  String get fadeOthers;

  /// Host embedding API spec G-5, G-3: the badges' switch, the button that
  /// centres the view on a table, and a badge's minutes.
  String get badges;

  String centerOnTable(String number);

  String minutes(int minutes);

  String get moves;

  String get longPressMenu;

  String get tableNumbersField;

  String get select;

  String get statusOfSelected;

  String get randomStatuses;

  String get tables;

  String get none;
  String get groups;

  String get log;

  String get selectOnlyThis;

  String statusName(String name);
  String logGroupStatus(String area, String status, String group);
  String logMerged(String area, String numbers, String id);
  String logSplit(String area, String id);
  String logGroupTapped(String area, String id, String number);

  String tableTitle(String number);

  String logMode(String area, String mode);

  String logSelected(String area, String numbers);

  String logDirty(String area, bool edited);

  String logRestored(String area, int moved, int dropped);

  String logMenu(String area, String number);

  String logStored(String area, int characters);

  String logReloaded(String area);

  String logStatus(String area, String status, String numbers);

  String logRandom(String area, int count);

  String logExported(String area, String file, int bytes);

  String logTapped(String area, String number);

  String logLayoutChanged(String area);

  /// Host embedding API spec E-1 to E-8: "Link tables", the unlinked count,
  /// the service's pointer line and the log's lines for a double tap, a
  /// move, a link and the design's table changes.
  String get linkTables;

  String unlinked(int count);

  String overTable(String number);

  String get overNoTable;

  /// The floor point ([x], [y]) in millimetres, worded in metres.
  String floorAt(double x, double y);

  String logLinked(String area, int count);

  String logOpened(String area, String number, String? id);

  String logMoved(String area, String numbers);

  String logTableAdded(String area, String number);

  String logTableRemoved(String area, String number);

  String logPlanReplaced(String area);

  /// Host embedding API spec T-1, T-2: the look switch in the app bar,
  /// its tooltip and its two looks, today's and the POS's.
  String get look;

  String get lookStandard;

  String get lookPos;

  /// Host embedding API spec C-1 to C-7 (Slice 4): the side panel's
  /// section of the host's own choices, the editor's three profiles, the
  /// host's own bar, its own export dialog, who owns the keys, the app
  /// bar's table search, the table inspector's field, and the log's lines
  /// for a failed export or print, a key of the demo's, a table linked
  /// from the inspector and a search.
  String get hostChoices;

  String get editor;

  String get editorFull;

  String get editorTables;

  String get editorReadOnly;

  String get ownBar;

  String get ownExportDialog;

  String get planKeys;

  String get findTable;

  String get posId;

  String logPageFlowError(String area, Object error);

  String logKey(String area, String key);

  String logLinkedTable(String area, String number, String? id);

  String logFound(String area, String number);

  String logNotFound(String area, String number);

  /// [mm] in metres, one decimal, with [separator] and a real minus sign.
  static String metres(double mm, String separator) {
    var text = (mm / 1000).toStringAsFixed(1);
    if (text == '-0.0') text = '0.0';
    return text.replaceFirst('.', separator).replaceFirst('-', '\u2212');
  }
}

final class _En extends DemoStrings {
  const _En();

  @override
  String get title => 'Restaurant demo';

  @override
  String get design => 'Design';

  @override
  String get service => 'Service';

  @override
  String get save => 'Save';

  @override
  String get revert => 'Revert';

  @override
  String get resetLayout => 'Reset layout';

  @override
  String get fit => 'Fit';

  @override
  String get zones => 'Zones';

  @override
  String get allZones => 'All';

  @override
  String get fadeOthers => 'Fade the others';

  @override
  String get badges => 'Badges';

  @override
  String centerOnTable(String number) => 'Centre on table $number';

  @override
  String minutes(int minutes) => '$minutes min';

  @override
  String get moves => 'Moves';

  @override
  String get longPressMenu => 'Long press: menu';

  @override
  String get tableNumbersField => 'Table numbers (comma separated)';

  @override
  String get select => 'Select';

  @override
  String get statusOfSelected => 'Status of the selected tables or group';

  @override
  String get randomStatuses => 'Random statuses';

  @override
  String get tables => 'Tables';

  @override
  String get none => 'none';

  @override
  String get groups => 'Groups';

  @override
  String logGroupStatus(String area, String status, String group) =>
      '$area: $status for $group';

  @override
  String logMerged(String area, String numbers, String id) =>
      '$area: Merged {$numbers} as $id';

  @override
  String logSplit(String area, String id) => '$area: Split $id';

  @override
  String logGroupTapped(String area, String id, String number) =>
      '$area: group $id tapped at $number';

  @override
  String get log => 'Log';

  @override
  String get selectOnlyThis => 'Select only this';

  @override
  String statusName(String name) => name;

  @override
  String tableTitle(String number) => 'Table $number';

  @override
  String logMode(String area, String mode) => '$area: mode $mode';

  @override
  String logSelected(String area, String numbers) =>
      '$area: selected {$numbers}';

  @override
  String logDirty(String area, bool edited) =>
      '$area: ${edited ? 'edited' : 'saved'}';

  @override
  String logRestored(String area, int moved, int dropped) =>
      '$area: layout restored, $moved moved, $dropped dropped';

  @override
  String logMenu(String area, String number) => '$area: menu for $number';

  @override
  String logStored(String area, int characters) =>
      '$area: stored $characters characters';

  @override
  String logReloaded(String area) => '$area: reloaded';

  @override
  String logStatus(String area, String status, String numbers) =>
      '$area: $status for {$numbers}';

  @override
  String logRandom(String area, int count) =>
      '$area: random statuses for $count tables';

  @override
  String logExported(String area, String file, int bytes) =>
      '$area: exported $file, $bytes bytes';

  @override
  String logTapped(String area, String number) => '$area: tapped $number';

  @override
  String logLayoutChanged(String area) => '$area: layout changed';

  @override
  String get linkTables => 'Link tables';

  @override
  String unlinked(int count) => 'Unlinked: $count';

  @override
  String overTable(String number) => 'over table $number';

  @override
  String get overNoTable => 'over no table';

  @override
  String floorAt(double x, double y) =>
      'floor at ${DemoStrings.metres(x, '.')}, '
      '${DemoStrings.metres(y, '.')} m';

  @override
  String logLinked(String area, int count) => '$area: linked $count tables';

  @override
  String logOpened(String area, String number, String? id) =>
      '$area: table $number opened (${id == null ? 'no id' : 'id $id'})';

  @override
  String logMoved(String area, String numbers) => '$area: moved {$numbers}';

  @override
  String logTableAdded(String area, String number) =>
      '$area: table $number added';

  @override
  String logTableRemoved(String area, String number) =>
      '$area: table $number removed';

  @override
  String logPlanReplaced(String area) => '$area: plan replaced';

  @override
  String get look => 'Look';

  @override
  String get lookStandard => 'Standard';

  @override
  String get lookPos => 'POS';

  @override
  String get hostChoices => 'Host';

  @override
  String get editor => 'Editor';

  @override
  String get editorFull => 'Full';

  @override
  String get editorTables => 'Tables';

  @override
  String get editorReadOnly => 'Read only';

  @override
  String get ownBar => 'Own bar';

  @override
  String get ownExportDialog => 'Own export dialog';

  @override
  String get planKeys => "The plan's keys";

  @override
  String get findTable => 'Find a table';

  @override
  String get posId => 'POS id';

  @override
  String logPageFlowError(String area, Object error) =>
      '$area: export or print failed ($error)';

  @override
  String logKey(String area, String key) => "$area: $key, the demo's key";

  @override
  String logLinkedTable(String area, String number, String? id) => id == null
      ? '$area: table $number unlinked'
      : '$area: table $number is $id';

  @override
  String logFound(String area, String number) => '$area: table $number found';

  @override
  String logNotFound(String area, String number) => '$area: no table $number';
}

final class _De extends DemoStrings {
  const _De();

  @override
  String get title => 'Restaurant-Demo';

  @override
  String get design => 'Entwurf';

  @override
  String get service => 'Service';

  @override
  String get save => 'Speichern';

  @override
  String get revert => 'Verwerfen';

  @override
  String get resetLayout => 'Anordnung zurücksetzen';

  @override
  String get fit => 'Einpassen';

  @override
  String get zones => 'Bereiche';

  @override
  String get allZones => 'Alle';

  @override
  String get fadeOthers => 'Andere abblenden';

  @override
  String get badges => 'Tischanzeigen';

  @override
  String centerOnTable(String number) => 'Auf Tisch $number zentrieren';

  @override
  String minutes(int minutes) => '$minutes Min.';

  @override
  String get moves => 'Verschieben';

  @override
  String get longPressMenu => 'Langes Drücken: Menü';

  @override
  String get tableNumbersField => 'Tischnummern (durch Komma getrennt)';

  @override
  String get select => 'Auswählen';

  @override
  String get statusOfSelected => 'Status der ausgewählten Tische oder Gruppe';

  @override
  String get randomStatuses => 'Zufällige Status';

  @override
  String get tables => 'Tische';

  @override
  String get none => 'keine';

  @override
  String get groups => 'Gruppen';

  @override
  String logGroupStatus(String area, String status, String group) =>
      '$area: $status für $group';

  @override
  String logMerged(String area, String numbers, String id) =>
      '$area: {$numbers} als $id zusammengelegt';

  @override
  String logSplit(String area, String id) => '$area: $id getrennt';

  @override
  String logGroupTapped(String area, String id, String number) =>
      '$area: Gruppe $id bei $number angetippt';

  @override
  String get log => 'Protokoll';

  @override
  String get selectOnlyThis => 'Nur diesen auswählen';

  @override
  String statusName(String name) => switch (name) {
        'Free' => 'Frei',
        'Ordered' => 'Bestellt',
        'Eating' => 'Beim Essen',
        'Bill' => 'Rechnung',
        _ => name
      };

  @override
  String tableTitle(String number) => 'Tisch $number';

  @override
  String logMode(String area, String mode) => '$area: Modus $mode';

  @override
  String logSelected(String area, String numbers) =>
      '$area: ausgewählt {$numbers}';

  @override
  String logDirty(String area, bool edited) =>
      '$area: ${edited ? 'geändert' : 'gespeichert'}';

  @override
  String logRestored(String area, int moved, int dropped) =>
      '$area: Anordnung wiederhergestellt, $moved verschoben, $dropped verworfen';

  @override
  String logMenu(String area, String number) => '$area: Menü für $number';

  @override
  String logStored(String area, int characters) =>
      '$area: $characters Zeichen gespeichert';

  @override
  String logReloaded(String area) => '$area: neu geladen';

  @override
  String logStatus(String area, String status, String numbers) =>
      '$area: $status für {$numbers}';

  @override
  String logRandom(String area, int count) =>
      '$area: zufällige Status für $count Tische';

  @override
  String logExported(String area, String file, int bytes) =>
      '$area: $file exportiert, $bytes Bytes';

  @override
  String logTapped(String area, String number) => '$area: $number angetippt';

  @override
  String logLayoutChanged(String area) => '$area: Anordnung geändert';

  @override
  String get linkTables => 'Tische verknüpfen';

  @override
  String unlinked(int count) => 'Nicht verknüpft: $count';

  @override
  String overTable(String number) => 'über Tisch $number';

  @override
  String get overNoTable => 'über keinem Tisch';

  @override
  String floorAt(double x, double y) =>
      'Boden bei ${DemoStrings.metres(x, ',')}; '
      '${DemoStrings.metres(y, ',')} m';

  @override
  String logLinked(String area, int count) => '$area: $count Tische verknüpft';

  @override
  String logOpened(String area, String number, String? id) =>
      '$area: Tisch $number geöffnet (${id == null ? 'keine ID' : 'ID $id'})';

  @override
  String logMoved(String area, String numbers) =>
      '$area: {$numbers} verschoben';

  @override
  String logTableAdded(String area, String number) =>
      '$area: Tisch $number hinzugefügt';

  @override
  String logTableRemoved(String area, String number) =>
      '$area: Tisch $number entfernt';

  @override
  String logPlanReplaced(String area) => '$area: Plan ersetzt';

  @override
  String get look => 'Aussehen';

  @override
  String get lookStandard => 'Standard';

  @override
  String get lookPos => 'Kasse';

  @override
  String get hostChoices => 'Host';

  @override
  String get editor => 'Editor';

  @override
  String get editorFull => 'Voll';

  @override
  String get editorTables => 'Tische';

  @override
  String get editorReadOnly => 'Nur lesen';

  @override
  String get ownBar => 'Eigene Leiste';

  @override
  String get ownExportDialog => 'Eigener Exportdialog';

  @override
  String get planKeys => 'Tasten des Plans';

  @override
  String get findTable => 'Tisch suchen';

  @override
  String get posId => 'Kassen-ID';

  @override
  String logPageFlowError(String area, Object error) =>
      '$area: Export oder Druck fehlgeschlagen ($error)';

  @override
  String logKey(String area, String key) => '$area: $key, Taste der Demo';

  @override
  String logLinkedTable(String area, String number, String? id) => id == null
      ? '$area: Tisch $number nicht mehr verknüpft'
      : '$area: Tisch $number ist $id';

  @override
  String logFound(String area, String number) =>
      '$area: Tisch $number gefunden';

  @override
  String logNotFound(String area, String number) => '$area: kein Tisch $number';
}

final class _Tr extends DemoStrings {
  const _Tr();

  @override
  String get title => 'Restoran demosu';

  @override
  String get design => 'Tasarım';

  @override
  String get service => 'Servis';

  @override
  String get save => 'Kaydet';

  @override
  String get revert => 'Geri döndür';

  @override
  String get resetLayout => 'Düzeni sıfırla';

  @override
  String get fit => 'Sığdır';

  @override
  String get zones => 'Bölgeler';

  @override
  String get allZones => 'Tümü';

  @override
  String get fadeOthers => 'Diğerlerini soldur';

  @override
  String get badges => 'Rozetler';

  @override
  String centerOnTable(String number) => 'Ortala: masa $number';

  @override
  String minutes(int minutes) => '$minutes dk';

  @override
  String get moves => 'Taşıma';

  @override
  String get longPressMenu => 'Uzun basış: menü';

  @override
  String get tableNumbersField => 'Masa numaraları (virgülle ayrılmış)';

  @override
  String get select => 'Seç';

  @override
  String get statusOfSelected => 'Seçili masaların veya grubun durumu';

  @override
  String get randomStatuses => 'Rastgele durumlar';

  @override
  String get tables => 'Masalar';

  @override
  String get none => 'yok';

  @override
  String get groups => 'Gruplar';

  @override
  String logGroupStatus(String area, String status, String group) =>
      '$area: $group için $status';

  @override
  String logMerged(String area, String numbers, String id) =>
      '$area: {$numbers}, $id olarak birleştirildi';

  @override
  String logSplit(String area, String id) => '$area: $id ayrıldı';

  @override
  String logGroupTapped(String area, String id, String number) =>
      '$area: $id grubunda $number masasına dokunuldu';

  @override
  String get log => 'Günlük';

  @override
  String get selectOnlyThis => 'Yalnız bunu seç';

  @override
  String statusName(String name) => switch (name) {
        'Free' => 'Boş',
        'Ordered' => 'Sipariş verildi',
        'Eating' => 'Yemekte',
        'Bill' => 'Hesap',
        _ => name
      };

  @override
  String tableTitle(String number) => 'Masa $number';

  @override
  String logMode(String area, String mode) => '$area: mod $mode';

  @override
  String logSelected(String area, String numbers) => '$area: seçili {$numbers}';

  @override
  String logDirty(String area, bool edited) =>
      '$area: ${edited ? 'değiştirildi' : 'kaydedildi'}';

  @override
  String logRestored(String area, int moved, int dropped) =>
      '$area: düzen geri yüklendi, $moved taşındı, $dropped atıldı';

  @override
  String logMenu(String area, String number) => '$area: $number için menü';

  @override
  String logStored(String area, int characters) =>
      '$area: $characters karakter saklandı';

  @override
  String logReloaded(String area) => '$area: yeniden yüklendi';

  @override
  String logStatus(String area, String status, String numbers) =>
      '$area: {$numbers} için $status';

  @override
  String logRandom(String area, int count) =>
      '$area: $count masa için rastgele durum';

  @override
  String logExported(String area, String file, int bytes) =>
      '$area: $file dışa aktarıldı, $bytes bayt';

  @override
  String logTapped(String area, String number) =>
      '$area: $number numaralı masaya dokunuldu';

  @override
  String logLayoutChanged(String area) => '$area: düzen değişti';

  @override
  String get linkTables => 'Masaları bağla';

  @override
  String unlinked(int count) => 'Bağlanmamış: $count';

  @override
  String overTable(String number) => 'masa $number üzerinde';

  @override
  String get overNoTable => 'masa üzerinde değil';

  @override
  String floorAt(double x, double y) => 'zemin: ${DemoStrings.metres(x, ',')}; '
      '${DemoStrings.metres(y, ',')} m';

  @override
  String logLinked(String area, int count) => '$area: $count masa bağlandı';

  @override
  String logOpened(String area, String number, String? id) =>
      '$area: masa $number açıldı '
      '(${id == null ? 'kimlik yok' : 'kimlik $id'})';

  @override
  String logMoved(String area, String numbers) => '$area: {$numbers} taşındı';

  @override
  String logTableAdded(String area, String number) =>
      '$area: masa $number eklendi';

  @override
  String logTableRemoved(String area, String number) =>
      '$area: masa $number kaldırıldı';

  @override
  String logPlanReplaced(String area) => '$area: plan değiştirildi';

  @override
  String get look => 'Görünüm';

  @override
  String get lookStandard => 'Standart';

  @override
  String get lookPos => 'Kasa';

  @override
  String get hostChoices => 'Ana uygulama';

  @override
  String get editor => 'Düzenleyici';

  @override
  String get editorFull => 'Tam';

  @override
  String get editorTables => 'Masalar';

  @override
  String get editorReadOnly => 'Salt okunur';

  @override
  String get ownBar => 'Kendi çubuğu';

  @override
  String get ownExportDialog => 'Kendi dışa aktarma penceresi';

  @override
  String get planKeys => 'Planın tuşları';

  @override
  String get findTable => 'Masa bul';

  @override
  String get posId => 'Kasa kimliği';

  @override
  String logPageFlowError(String area, Object error) =>
      '$area: dışa aktarma veya yazdırma başarısız ($error)';

  @override
  String logKey(String area, String key) => '$area: $key, demonun tuşu';

  @override
  String logLinkedTable(String area, String number, String? id) => id == null
      ? '$area: masa $number bağlantısı kaldırıldı'
      : '$area: masa $number, $id';

  @override
  String logFound(String area, String number) => '$area: masa $number bulundu';

  @override
  String logNotFound(String area, String number) => '$area: masa $number yok';
}
