// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'FirBird';

  @override
  String get homeHeadline => 'Kuşları çevrimdışı tanıyın.';

  @override
  String get homeDescription =>
      'Cihaz üzerinde tanımlamaya başlamak için mevcut bir fotoğraf seçin.';

  @override
  String get selectPhoto => 'Fotoğraf seç';

  @override
  String get onboardingTitle => 'Cihazınızda kalan kuş tanımlama';

  @override
  String get onboardingBody =>
      'FirBird, internet bağlantısı olmadan mevcut fotoğraflarınızdaki kuşları tanımlar.';

  @override
  String get onboardingPrivacy =>
      'Fotoğraflarınız ve konumunuz tanımlama için yüklenmez.';

  @override
  String get getStarted => 'Başlayın';

  @override
  String get about => 'FirBird hakkında';

  @override
  String get recentIdentifications => 'Son tanımlamalar';

  @override
  String get regionPackages => 'Bölge paketleri';

  @override
  String get exploreBirds => 'Kuşları keşfet';

  @override
  String get settings => 'Ayarlar';

  @override
  String get photoPlaceholder =>
      'Fotoğraf seçimi ve metadata inceleme sonraki fazda eklenecek.';

  @override
  String get historyPlaceholder =>
      'Cihazınızdaki tanımlama geçmişi burada görünecek.';

  @override
  String get packagesPlaceholder =>
      'Kurulu ve indirilebilir çevrimdışı kuş bölgesi paketleri burada görünecek.';

  @override
  String get explorePlaceholder => 'Yerel tür kataloğu burada sunulacak.';

  @override
  String get settingsPlaceholder =>
      'Dil, gizlilik, geçmiş ve paket tercihleri burada sunulacak.';

  @override
  String get speciesDetail => 'Tür detayı';

  @override
  String get speciesPlaceholder =>
      'Tür bilgileri, attribution ve kaynaklar burada gösterilecek.';

  @override
  String get openSpeciesDetail => 'Tür detayını aç';

  @override
  String get photoPreview => 'Seçilen fotoğraf önizlemesi';

  @override
  String get changePhoto => 'Fotoğrafı değiştir';

  @override
  String get photoInformation => 'Fotoğraf bilgisi';

  @override
  String get photoPickerDescription =>
      'Galerinizden bir fotoğraf seçin. Fotoğraf cihazınızda kalır.';

  @override
  String get orientation => 'Yönelim';

  @override
  String get notAvailable => 'Mevcut değil';

  @override
  String get photoDateFound => 'Fotoğrafta çekim tarihi bulundu.';

  @override
  String get photoDateNotFound => 'Fotoğrafta çekim tarihi bulunamadı.';

  @override
  String get photoLocationFound => 'Fotoğrafta konum bilgisi bulundu.';

  @override
  String get photoLocationNotFound => 'Fotoğrafta konum bilgisi bulunamadı.';

  @override
  String get usePhotoDate => 'Fotoğraf tarihini kullan';

  @override
  String get usePhotoLocation => 'Fotoğraf konumunu kullan';

  @override
  String get locationConsentDescription =>
      'Kesin koordinatınız yalnızca bu cihazda kullanılır.';

  @override
  String get metadataReadFailed =>
      'Fotoğraf okunamadı. Desteklenen başka bir görsel deneyin.';

  @override
  String get setLocationAndDate => 'Konum ve tarihi belirle';

  @override
  String get location => 'Konum';

  @override
  String get locationDescription =>
      'Konum isteğe bağlıdır ve yalnızca bu cihazda sonuçları iyileştirmek için kullanılır.';

  @override
  String get useExifLocation => 'Fotoğrafın EXIF konumunu kullan';

  @override
  String get exifLocationAvailable =>
      'Fotoğrafta konum bilgisi var. Kullanmayı siz seçersiniz.';

  @override
  String get exifLocationUnavailable =>
      'Önce konum metadata\'sı olan bir fotoğraf seçin.';

  @override
  String get selectOnMap => 'Haritadan seç';

  @override
  String get useCurrentLocation => 'Mevcut konumumu kullan';

  @override
  String get selectFromRegionList => 'Bölge listesinden seç';

  @override
  String get region => 'Bölge';

  @override
  String get locationUnknown => 'Konumu bilmiyorum';

  @override
  String get date => 'Tarih';

  @override
  String get useExifDate => 'Fotoğrafın EXIF tarihini kullan';

  @override
  String get exifDateUnavailable =>
      'Önce çekim tarihi metadata\'sı olan bir fotoğraf seçin.';

  @override
  String get selectDate => 'Tarihi elle seç';

  @override
  String get useToday => 'Bugünün tarihini kullan';

  @override
  String get dateUnknown => 'Tarihi bilmiyorum';

  @override
  String get locationServicesDisabled =>
      'Konum servisleri kapalı. Bölge seçebilir veya haritayı kullanabilirsiniz.';

  @override
  String get locationPermissionDenied =>
      'Konum izni verilmedi. Bölge seçebilir veya haritayı kullanabilirsiniz.';

  @override
  String get locationUnavailable =>
      'Mevcut konum kullanılamıyor. Bölge seçebilir veya haritayı kullanabilirsiniz.';

  @override
  String get approximateGridSelected => 'Yaklaşık harita gridi seçildi';

  @override
  String get contextSummary => 'Gözlem bağlamı';

  @override
  String get identify => 'Tanımla';

  @override
  String get analyzing => 'Analiz ediliyor';

  @override
  String get preparingImage => 'Görsel hazırlanıyor';

  @override
  String get findingBird => 'Kuş aranıyor';

  @override
  String get comparingSpecies => 'Türler karşılaştırılıyor';

  @override
  String get calculatingRegionalResults => 'Bölgesel sonuçlar hesaplanıyor';

  @override
  String get inferenceFailed =>
      'Tanımlama tamamlanamadı. Lütfen tekrar deneyin.';

  @override
  String get identificationResult => 'Tanımlama sonucu';

  @override
  String get mockResultNotice =>
      'İlk mobil model hazırlanırken bu ekran deterministik mock sonuç gösterir.';

  @override
  String get bestMatch => 'İlk eşleşme';

  @override
  String get topCandidates => 'İlk 5 aday';

  @override
  String get highMatch => 'Yüksek eşleşme';

  @override
  String get mediumMatch => 'Orta eşleşme';

  @override
  String get lowMatch => 'Düşük eşleşme';

  @override
  String get locationEffect => 'Konum etkisi';

  @override
  String get dateEffect => 'Tarih etkisi';

  @override
  String get contextAffected =>
      'Bu bağlam adayları yeniden sıralamak için kullanıldı.';

  @override
  String get contextNotUsed =>
      'Görsel adaylar bu bağlam kullanılmadan gösteriliyor.';

  @override
  String get modelVersion => 'Model sürümü';

  @override
  String get shareResult => 'Sonucu paylaş';

  @override
  String get saveToHistory => 'Geçmişe kaydet';

  @override
  String shareText(Object turkishName, Object scientificName) {
    return 'FirBird bu kuşu $turkishName ($scientificName) olarak eşleştirdi.';
  }

  @override
  String get family => 'Familya';

  @override
  String get habitat => 'Habitat';

  @override
  String get migrationStatus => 'Göç durumu';

  @override
  String get sources => 'Kaynaklar';

  @override
  String get mockDataValue => 'Lisanslı Türkiye paketiyle kullanılabilir.';

  @override
  String get mockSpeciesNotice =>
      'Bu ekran mock katalog kaydını kullanır. Gerçek tür içeriği ve attribution bölge paketiyle eklenecek.';

  @override
  String get historyEmpty => 'Bu cihazda kaydedilmiş tanımlama yok.';

  @override
  String get clearHistory => 'Geçmişi sil';

  @override
  String get historySetting => 'Tanımlama geçmişini kaydet';

  @override
  String get historySettingDescription =>
      'Sonuçlar yalnızca bu cihazda tutulur. Orijinal fotoğraflar kopyalanmaz.';

  @override
  String get activePackage => 'Aktif bölge paketi';

  @override
  String get privacy => 'Gizlilik';

  @override
  String get privacySummary => 'Fotoğraflar ve konum cihazınızda kalır.';

  @override
  String get sexAgeTitle => 'Cinsiyet & Yaşam Evresi';

  @override
  String get sexLabel => 'Cinsiyet';

  @override
  String get ageLabel => 'Yaşam Evresi';

  @override
  String get sexFemale => 'Dişi';

  @override
  String get sexMale => 'Erkek';

  @override
  String get sexUnknown => 'Belirsiz';

  @override
  String get ageChick => 'Yavru';

  @override
  String get ageJuvenile => 'Genç';

  @override
  String get ageAdult => 'Yetişkin';

  @override
  String get ageUnknown => 'Belirsiz';

  @override
  String get sexAgeMethodBioclip2 => 'BioCLIP 2 görsel tahmini';

  @override
  String get sexAgeMethodUserValidated => 'Kullanıcı doğrulaması';

  @override
  String get sexAgeMethodHybrid => 'Karma yöntem';

  @override
  String get sexUnreliableWarning =>
      'Bu türde dişi/erkek ayrımı fotoğraftan güvenilir olmayabilir.';

  @override
  String get sexSeasonalWarning =>
      'Cinsiyet tahmini yalnızca tüy görünümüne dayanmaktadır; mevsime göre değişebilir.';

  @override
  String get sexAgeConflictWarning =>
      'Cinsiyet ve yaşam evresi bilgileri birbiriyle çelişiyor olabilir.';

  @override
  String get correctSexAge => 'Düzelt / Doğrula';

  @override
  String get correctionTitle => 'Cinsiyet & Yaşam Evresi Doğrulama';

  @override
  String get correctionApprovalQuestion => 'Model tahmini size uygun mu?';

  @override
  String get correctionApprove => 'Evet, uygun';

  @override
  String get correctionNotCorrect => 'Hayır, düzelt';

  @override
  String get correctionWhichParam => 'Hangi bilgiyi düzeltmek istiyorsunuz?';

  @override
  String get correctionNext => 'Devam';

  @override
  String get correctionSexQuestion => 'Cinsiyeti seçin';

  @override
  String get correctionAgeQuestion => 'Yaşam evresini seçin';

  @override
  String get correctionNotSure => 'Emin değilim';

  @override
  String get correctionSave => 'Kaydet';

  @override
  String get correctionCancel => 'Vazgeç';

  @override
  String get correctionPhotoQuality => 'Fotoğraf net ve kuş tam görünüyor';

  @override
  String get correctionExpertVerified => 'Uzman tarafından doğrulandı';

  @override
  String get correctionSpecies => 'Tür (Species)';

  @override
  String get correctionSpeciesQuestion => 'Doğru türü seçin:';

  @override
  String get correctionSearchSpecies => 'Tür ara...';
}
