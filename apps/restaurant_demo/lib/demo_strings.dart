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
}
