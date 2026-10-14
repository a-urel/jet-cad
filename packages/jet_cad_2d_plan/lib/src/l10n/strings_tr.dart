// The plan library's words in Turkish (spec P5; ported from
// jet_cad_floor_plan's strings_tr.dart, spec 14d L1).
import 'package:jet_cad_2d/jet_cad_2d.dart'
    show
        LayerNameBadCharacter,
        LayerNameDuplicate,
        LayerNameEdgeSpace,
        LayerNameEmpty,
        LayerNameProblem,
        LayerNameTooLong;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch, UnitKinds;

import '../units/unit_label.dart' show UnitLabelProblem, kUnitLabelMaxLength;
import '../units/unit_problems.dart'
    show BadLabel, DuplicateLabel, Unlabelled, UnitLabelWarning;
import 'strings.dart';

/// The plan library's words in Turkish.
class PlanStringsTr extends PlanStrings {
  const PlanStringsTr();

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
  String get toolSelect => 'Seç';

  @override
  String get toolLine => 'Çizgi';

  @override
  String get toolPolyline => 'Çoklu çizgi';

  @override
  String get toolRectangle => 'Dikdörtgen';

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
  String get newDocument => 'Yeni';

  @override
  String get open => 'Aç…';

  @override
  String get save => 'Kaydet';

  @override
  String get saveAs => 'Farklı kaydet…';

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
  String get name => 'Ad';

  @override
  String get size => 'Boyut';

  @override
  String get rotation => 'Döndürme';

  @override
  String get mirror => 'Aynala';

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
  String get pageDecimalSeparator => 'Ondalık ayırıcı';

  @override
  String get paper => 'Kâğıt';

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
  String get lockedNoLayer => 'Kilitli nesnelerin katmanı değiştirilemez';

  @override
  String get layer => 'Katman';

  @override
  String get color => 'Renk';

  @override
  String get colorNone => 'Yok';

  @override
  String get colorRefused => 'Renkler burada değiştirilemez';

  @override
  String colorName(PlanSwatch swatch) => switch (swatch) {
        PlanSwatch.red => 'Kırmızı',
        PlanSwatch.orange => 'Turuncu',
        PlanSwatch.yellow => 'Sarı',
        PlanSwatch.green => 'Yeşil',
        PlanSwatch.teal => 'Turkuaz',
        PlanSwatch.blue => 'Mavi',
        PlanSwatch.purple => 'Mor',
        PlanSwatch.grey => 'Gri',
      };

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
  String layerName(int n) => 'Katman $n';

  @override
  String get lockedHint => 'Bu nesne kilitli';

  @override
  String get sectionFailed => 'Bu bölüm gösterilemiyor';

  @override
  String get planDamaged =>
      'Bir düzenleme başarısız oldu; plan bozulmuş olabilir';

  @override
  String get merge => 'Birleştir';

  @override
  String get split => 'Ayır';

  @override
  String get number => 'Numara';

  @override
  String get label => 'Etiket';

  @override
  String get capacity => 'Kişilik';

  @override
  String get rotateLeft => '90° sola döndür';

  @override
  String get rotateRight => '90° sağa döndür';

  @override
  String labelProblem(UnitLabelProblem problem) => switch (problem) {
        UnitLabelProblem.length =>
          '1 ile $kUnitLabelMaxLength karakter arasında olmalı',
        UnitLabelProblem.control => 'Satır sonu veya kontrol karakteri olamaz',
      };

  @override
  String labelUsed(String label) => '$label numarası zaten kullanılıyor';

  @override
  String labelWarning(UnitLabelWarning warning) => switch (warning) {
        DuplicateLabel(:final label, :final count) =>
          '$label numarası $count masada kullanılıyor',
        Unlabelled(:final kind, :final capacity) => kind == UnitKinds.table
            ? '$capacity kişilik bir masanın numarası yok'
            : '$capacity kişilik ${unitKind(kind) ?? kind}: numara yok',
        BadLabel(:final label, :final problem) =>
          '"$label" bir etiket değil: ${labelProblem(problem)}',
      };

  @override
  String? unitKind(String kind) => switch (kind) {
        UnitKinds.table => 'Masa',
        UnitKinds.seat => 'Koltuk',
        _ => null,
      };
}
