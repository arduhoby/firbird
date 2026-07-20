// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'FirBird';

  @override
  String get homeHeadline => 'Identify birds, offline.';

  @override
  String get homeDescription =>
      'Choose an existing photo to start an on-device identification.';

  @override
  String get selectPhoto => 'Select photo';

  @override
  String get onboardingTitle => 'Bird identification that stays on your device';

  @override
  String get onboardingBody =>
      'FirBird identifies birds from your existing photos, even without an internet connection.';

  @override
  String get onboardingPrivacy =>
      'Your photos and location are not uploaded for identification.';

  @override
  String get getStarted => 'Get started';

  @override
  String get about => 'About FirBird';

  @override
  String get recentIdentifications => 'Recent identifications';

  @override
  String get regionPackages => 'Region packages';

  @override
  String get exploreBirds => 'Explore birds';

  @override
  String get settings => 'Settings';

  @override
  String get photoPlaceholder =>
      'Photo selection and metadata review will be added in the next phase.';

  @override
  String get historyPlaceholder =>
      'Your on-device identification history will appear here.';

  @override
  String get packagesPlaceholder =>
      'Installed and available offline bird-region packages will appear here.';

  @override
  String get explorePlaceholder =>
      'The local species catalogue will be available here.';

  @override
  String get settingsPlaceholder =>
      'Language, privacy, history, and package preferences will be available here.';

  @override
  String get speciesDetail => 'Species detail';

  @override
  String get speciesPlaceholder =>
      'Species facts, attribution, and sources will be shown here.';

  @override
  String get openSpeciesDetail => 'Open species detail';

  @override
  String get photoPreview => 'Selected photo preview';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get photoInformation => 'Photo information';

  @override
  String get photoPickerDescription =>
      'Choose a photo from your gallery. It stays on your device.';

  @override
  String get orientation => 'Orientation';

  @override
  String get notAvailable => 'Not available';

  @override
  String get photoDateFound => 'A capture date was found in the photo.';

  @override
  String get photoDateNotFound => 'No capture date was found in the photo.';

  @override
  String get photoLocationFound => 'A photo location was found.';

  @override
  String get photoLocationNotFound => 'No photo location was found.';

  @override
  String get usePhotoDate => 'Use photo date';

  @override
  String get usePhotoLocation => 'Use photo location';

  @override
  String get locationConsentDescription =>
      'Your exact coordinates are only used on this device.';

  @override
  String get metadataReadFailed =>
      'The photo could not be read. Try another supported image.';

  @override
  String get setLocationAndDate => 'Set location and date';

  @override
  String get location => 'Location';

  @override
  String get locationDescription =>
      'Location is optional and only used to refine results on this device.';

  @override
  String get useExifLocation => 'Use photo EXIF location';

  @override
  String get exifLocationAvailable =>
      'A photo location is available. You choose whether to use it.';

  @override
  String get exifLocationUnavailable =>
      'Select a photo with location metadata first.';

  @override
  String get selectOnMap => 'Select on map';

  @override
  String get useCurrentLocation => 'Use my current location';

  @override
  String get selectFromRegionList => 'Select from region list';

  @override
  String get region => 'Region';

  @override
  String get locationUnknown => 'I do not know the location';

  @override
  String get date => 'Date';

  @override
  String get useExifDate => 'Use photo EXIF date';

  @override
  String get exifDateUnavailable =>
      'Select a photo with capture-date metadata first.';

  @override
  String get selectDate => 'Select date manually';

  @override
  String get useToday => 'Use today\'s date';

  @override
  String get dateUnknown => 'I do not know the date';

  @override
  String get locationServicesDisabled =>
      'Location services are disabled. You can choose a region or use the map.';

  @override
  String get locationPermissionDenied =>
      'Location permission was not granted. You can choose a region or use the map.';

  @override
  String get locationUnavailable =>
      'Current location is unavailable. You can choose a region or use the map.';

  @override
  String get approximateGridSelected => 'Approximate map grid selected';

  @override
  String get contextSummary => 'Observation context';

  @override
  String get identify => 'Identify';

  @override
  String get analyzing => 'Analyzing';

  @override
  String get preparingImage => 'Preparing image';

  @override
  String get findingBird => 'Finding bird';

  @override
  String get comparingSpecies => 'Comparing species';

  @override
  String get calculatingRegionalResults => 'Calculating regional results';

  @override
  String get inferenceFailed =>
      'Identification could not be completed. Please try again.';

  @override
  String get identificationResult => 'Identification result';

  @override
  String get mockResultNotice =>
      'This is a deterministic mock result while the first mobile model is being prepared.';

  @override
  String get bestMatch => 'Best match';

  @override
  String get topCandidates => 'Top 5 candidates';

  @override
  String get highMatch => 'High match';

  @override
  String get mediumMatch => 'Medium match';

  @override
  String get lowMatch => 'Low match';

  @override
  String get locationEffect => 'Location effect';

  @override
  String get dateEffect => 'Date effect';

  @override
  String get contextAffected => 'This context was used to rerank candidates.';

  @override
  String get contextNotUsed =>
      'Visual candidates are shown without this context.';

  @override
  String get modelVersion => 'Model version';

  @override
  String get shareResult => 'Share result';

  @override
  String get saveToHistory => 'Save to history';

  @override
  String shareText(Object turkishName, Object scientificName) {
    return 'FirBird matched this bird as $turkishName ($scientificName).';
  }

  @override
  String get family => 'Family';

  @override
  String get habitat => 'Habitat';

  @override
  String get migrationStatus => 'Migration status';

  @override
  String get sources => 'Sources';

  @override
  String get mockDataValue => 'Available with the licensed Türkiye package.';

  @override
  String get mockSpeciesNotice =>
      'This screen uses the mock catalogue record. Real species content and attribution will arrive with the region package.';

  @override
  String get historyEmpty =>
      'No identifications have been saved on this device.';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get historySetting => 'Save identification history';

  @override
  String get historySettingDescription =>
      'Results are stored only on this device. Original photos are not copied.';

  @override
  String get activePackage => 'Active region package';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacySummary => 'Photos and location stay on your device.';
}
