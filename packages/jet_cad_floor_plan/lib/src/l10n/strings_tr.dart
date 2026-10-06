// The planner's words in Turkish (spec 14d L1).
import 'package:jet_cad_2d/jet_cad_2d.dart'
    show
        LayerNameBadCharacter,
        LayerNameDuplicate,
        LayerNameEdgeSpace,
        LayerNameEmpty,
        LayerNameProblem,
        LayerNameTooLong;

import '../host/floor_plan_types.dart'
    show DuplicateNumber, NumberingWarning, Unnumbered;
import '../tables/table_numbers.dart'
    show TableNumberProblem, kTableNumberMaxLength;
import 'strings.dart';

/// The planner's words in Turkish.
class FloorPlanStringsTr extends FloorPlanStrings {
  const FloorPlanStringsTr();

  @override
  String get languageCode => 'tr';

  @override
  String get decimalSeparator => ',';

  @override
  String layerNameProblem(LayerNameProblem problem) => switch (problem) {
        LayerNameEmpty() => 'Katman adı boş olamaz.',
        LayerNameEdgeSpace() => 'Katman adı boşlukla başlayamaz veya bitemez.',
        LayerNameTooLong(:final max) =>
          'Katman adı en fazla $max karakter olabilir.',
        LayerNameBadCharacter(:final character) =>
          'Katman adı $character içeremez.',
        LayerNameDuplicate(:final existing) =>
          '$existing adlı bir katman zaten var.',
      };

  @override
  String tableNumberProblem(TableNumberProblem problem) => switch (problem) {
        TableNumberProblem.length =>
          '1 ile $kTableNumberMaxLength karakter arası',
        TableNumberProblem.control =>
          'Satır sonu veya kontrol karakteri olamaz',
      };

  @override
  String tableNumberUsed(String number) =>
      '$number numarası zaten kullanılıyor';

  @override
  String numberingWarning(NumberingWarning warning) => switch (warning) {
        DuplicateNumber(:final number, :final count) =>
          '$number numarası $count masada kullanılıyor',
        Unnumbered(:final seats) => '$seats kişilik bir masanın numarası yok',
      };

  @override
  String roomOccupied(String name) => 'Zaten bir oda: $name';

  @override
  String get toolSelect => 'Seç';

  @override
  String get toolLine => 'Çizgi';

  @override
  String get toolPolyline => 'Çoklu çizgi';

  @override
  String get toolRectangle => 'Dikdörtgen';

  @override
  String get toolBox => 'Kutu';

  @override
  String get toolWall => 'Duvar';

  @override
  String get toolDoor => 'Kapı';

  @override
  String get toolWindow => 'Pencere';

  @override
  String get toolGap => 'Boşluk';

  @override
  String get toolRoom => 'Oda';

  @override
  String get toolSeparator => 'Ayırıcı';

  @override
  String get toolDimension => 'Ölçü';

  @override
  String get toolCircle => 'Daire';

  @override
  String get toolArc => 'Yay';

  @override
  String get toolText => 'Metin';

  @override
  String get toolSymbol => 'Sembol';

  @override
  String get fill => 'Dolgu';

  @override
  String get tabTools => 'Araçlar';

  @override
  String get tabSymbols => 'Semboller';

  @override
  String get objectSnapOn => 'OSNAP';

  @override
  String get objectSnapOff => 'OSNAP kapalı';

  @override
  String get edited => 'Değiştirildi';

  @override
  String get undo => 'Geri al';

  @override
  String get redo => 'Yinele';

  @override
  String get exportEllipsis => 'Dışa aktar…';

  @override
  String get printEllipsis => 'Yazdır…';

  @override
  String get controlKey => 'Ctrl';

  @override
  String get shiftKey => 'Shift';

  @override
  String get exportTitle => 'Dışa aktar';

  @override
  String get exportAction => 'Dışa aktar';

  @override
  String get cancel => 'İptal';

  @override
  String get searchSymbols => 'Sembol ara';

  @override
  String get clear => 'Temizle';

  @override
  String get loadingSymbols => 'Semboller yükleniyor…';

  @override
  String get symbolsFailed => 'Semboller yüklenemedi.';

  @override
  String get retry => 'Tekrar dene';

  @override
  String selectedCount(int count) => '$count seçili';

  @override
  String dpi(int dpi) => '$dpi dpi';

  @override
  String noSymbolsMatch(String query) => '"$query" ile eşleşen sembol yok';
}
