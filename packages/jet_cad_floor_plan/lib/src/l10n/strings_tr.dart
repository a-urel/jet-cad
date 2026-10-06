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
          '1 ile $kTableNumberMaxLength karakter arasında olmalı',
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

  @override
  String get tableTitle => 'Masa';

  @override
  String get width => 'Genişlik';

  @override
  String get height => 'Yükseklik';

  @override
  String get thickness => 'Kalınlık';

  @override
  String get justifyLeft => 'Sol';

  @override
  String get justifyCentre => 'Orta';

  @override
  String get justifyRight => 'Sağ';

  @override
  String get position => 'Konum';

  @override
  String get flipHinge => 'Menteşeyi çevir';

  @override
  String get flipSwing => 'Açılışı çevir';

  @override
  String get name => 'Ad';

  @override
  String get area => 'Alan';

  @override
  String get value => 'Değer';

  @override
  String get aligned => 'Hizalı';

  @override
  String get horizontal => 'Yatay';

  @override
  String get vertical => 'Dikey';

  @override
  String get end1 => 'Uç 1';

  @override
  String get end2 => 'Uç 2';

  @override
  String get endFixed => 'Sabit';

  @override
  String get leftFace => 'sol yüzey';

  @override
  String get centreline => 'eksen';

  @override
  String get rightFace => 'sağ yüzey';

  @override
  String get size => 'Boyut';

  @override
  String get rotation => 'Döndürme';

  @override
  String get mirror => 'Aynala';

  @override
  String get number => 'Numara';

  @override
  String get seats => 'Kişilik';

  @override
  String get rotateLeft => '90° sola döndür';

  @override
  String get rotateRight => '90° sağa döndür';

  @override
  String get pageTitle => 'Sayfa';

  @override
  String get customSize => 'Özel';

  @override
  String get portrait => 'Dikey';

  @override
  String get landscape => 'Yatay';

  @override
  String get scale => 'Ölçek';

  @override
  String get grid => 'Izgara';

  @override
  String get snapToGrid => 'Izgaraya yapış';

  @override
  String get pageBreaks => 'Sayfa sonları';

  @override
  String get paper => 'Kâğıt';

  @override
  String axesTurned(String degrees) => 'Eksenler $degrees° döndürülmüş';

  @override
  String endOnWall(String wall, bool atStart, String side) =>
      'Duvar $wall, ${atStart ? 'başlangıç' : 'bitiş'}, $side';

  @override
  String get layersLocked => 'Bu belgede katmanlar değiştirilemez';

  @override
  String get selectLayerToDelete => 'Silmek için bir katman seçin';

  @override
  String get layerZeroUndeletable => '0 katmanı silinemez';

  @override
  String get currentLayerUndeletable => 'Geçerli katman silinemez';

  @override
  String get layerInUse => 'Bu katman kullanımda';

  @override
  String get layers => 'Katmanlar';

  @override
  String get newLayer => 'Yeni katman';

  @override
  String get deleteLayer => 'Katmanı sil';

  @override
  String get mixed => 'Karışık';

  @override
  String get readOnlyDocument => 'Salt okunur belge';

  @override
  String get plainGroupNoLayer => 'Düz bir grubun katmanı yok: taşınamaz';

  @override
  String get layer => 'Katman';

  @override
  String get moveSelectionToLayer => 'Seçimi bir katmana taşı';

  @override
  String get hiddenLayerNotCurrent => 'Gizli bir katman geçerli olamaz';

  @override
  String get currentLayer => 'Geçerli katman';

  @override
  String get makeCurrent => 'Geçerli yap';

  @override
  String get currentLayerNotHidden => 'Geçerli katman gizlenemez';

  @override
  String get hideLayer => 'Katmanı gizle';

  @override
  String get showLayer => 'Katmanı göster';

  @override
  String get unlockLayer => 'Katman kilidini aç';

  @override
  String get lockLayer => 'Katmanı kilitle';

  @override
  String get layerColour => 'Katman rengi';

  @override
  String missingLayer(String hex) => 'Eksik katman $hex';

  @override
  String colourName(int aci) => switch (aci) {
        1 => 'Kırmızı',
        2 => 'Sarı',
        3 => 'Yeşil',
        4 => 'Camgöbeği',
        5 => 'Mavi',
        6 => 'Eflatun',
        7 => 'Ön plan',
        8 => 'Koyu gri',
        9 => 'Açık gri',
        _ => '$aci',
      };

  @override
  String roomName(int n) => 'Oda $n';

  @override
  String layerName(int n) => 'Katman $n';

  @override
  String get sampleHall => 'Hol';

  @override
  String get sampleKitchen => 'Mutfak';

  @override
  String get sampleBath => 'Banyo';

  @override
  String get sampleLiving => 'Oturma odası';

  @override
  String get sampleDining => 'Yemek odası';

  @override
  String sampleBedroom(int n) => 'Yatak odası $n';
}
