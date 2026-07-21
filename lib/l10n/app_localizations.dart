import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'FirBird'**
  String get appName;

  /// No description provided for @homeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Identify birds, offline.'**
  String get homeHeadline;

  /// No description provided for @homeDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose an existing photo to start an on-device identification.'**
  String get homeDescription;

  /// No description provided for @selectPhoto.
  ///
  /// In en, this message translates to:
  /// **'Select photo'**
  String get selectPhoto;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Bird identification that stays on your device'**
  String get onboardingTitle;

  /// No description provided for @onboardingBody.
  ///
  /// In en, this message translates to:
  /// **'FirBird identifies birds from your existing photos, even without an internet connection.'**
  String get onboardingBody;

  /// No description provided for @onboardingPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your photos and location are not uploaded for identification.'**
  String get onboardingPrivacy;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About FirBird'**
  String get about;

  /// No description provided for @recentIdentifications.
  ///
  /// In en, this message translates to:
  /// **'Recent identifications'**
  String get recentIdentifications;

  /// No description provided for @regionPackages.
  ///
  /// In en, this message translates to:
  /// **'Region packages'**
  String get regionPackages;

  /// No description provided for @exploreBirds.
  ///
  /// In en, this message translates to:
  /// **'Explore birds'**
  String get exploreBirds;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @photoPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Photo selection and metadata review will be added in the next phase.'**
  String get photoPlaceholder;

  /// No description provided for @historyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Your on-device identification history will appear here.'**
  String get historyPlaceholder;

  /// No description provided for @packagesPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Installed and available offline bird-region packages will appear here.'**
  String get packagesPlaceholder;

  /// No description provided for @explorePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'The local species catalogue will be available here.'**
  String get explorePlaceholder;

  /// No description provided for @settingsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Language, privacy, history, and package preferences will be available here.'**
  String get settingsPlaceholder;

  /// No description provided for @speciesDetail.
  ///
  /// In en, this message translates to:
  /// **'Species detail'**
  String get speciesDetail;

  /// No description provided for @speciesPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Species facts, attribution, and sources will be shown here.'**
  String get speciesPlaceholder;

  /// No description provided for @openSpeciesDetail.
  ///
  /// In en, this message translates to:
  /// **'Open species detail'**
  String get openSpeciesDetail;

  /// No description provided for @photoPreview.
  ///
  /// In en, this message translates to:
  /// **'Selected photo preview'**
  String get photoPreview;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @photoInformation.
  ///
  /// In en, this message translates to:
  /// **'Photo information'**
  String get photoInformation;

  /// No description provided for @photoPickerDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo from your gallery. It stays on your device.'**
  String get photoPickerDescription;

  /// No description provided for @orientation.
  ///
  /// In en, this message translates to:
  /// **'Orientation'**
  String get orientation;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @photoDateFound.
  ///
  /// In en, this message translates to:
  /// **'A capture date was found in the photo.'**
  String get photoDateFound;

  /// No description provided for @photoDateNotFound.
  ///
  /// In en, this message translates to:
  /// **'No capture date was found in the photo.'**
  String get photoDateNotFound;

  /// No description provided for @photoLocationFound.
  ///
  /// In en, this message translates to:
  /// **'A photo location was found.'**
  String get photoLocationFound;

  /// No description provided for @photoLocationNotFound.
  ///
  /// In en, this message translates to:
  /// **'No photo location was found.'**
  String get photoLocationNotFound;

  /// No description provided for @usePhotoDate.
  ///
  /// In en, this message translates to:
  /// **'Use photo date'**
  String get usePhotoDate;

  /// No description provided for @usePhotoLocation.
  ///
  /// In en, this message translates to:
  /// **'Use photo location'**
  String get usePhotoLocation;

  /// No description provided for @locationConsentDescription.
  ///
  /// In en, this message translates to:
  /// **'Your exact coordinates are only used on this device.'**
  String get locationConsentDescription;

  /// No description provided for @metadataReadFailed.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be read. Try another supported image.'**
  String get metadataReadFailed;

  /// No description provided for @setLocationAndDate.
  ///
  /// In en, this message translates to:
  /// **'Set location and date'**
  String get setLocationAndDate;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @locationDescription.
  ///
  /// In en, this message translates to:
  /// **'Location is optional and only used to refine results on this device.'**
  String get locationDescription;

  /// No description provided for @useExifLocation.
  ///
  /// In en, this message translates to:
  /// **'Use photo EXIF location'**
  String get useExifLocation;

  /// No description provided for @exifLocationAvailable.
  ///
  /// In en, this message translates to:
  /// **'A photo location is available. You choose whether to use it.'**
  String get exifLocationAvailable;

  /// No description provided for @exifLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Select a photo with location metadata first.'**
  String get exifLocationUnavailable;

  /// No description provided for @selectOnMap.
  ///
  /// In en, this message translates to:
  /// **'Select on map'**
  String get selectOnMap;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get useCurrentLocation;

  /// No description provided for @selectFromRegionList.
  ///
  /// In en, this message translates to:
  /// **'Select from region list'**
  String get selectFromRegionList;

  /// No description provided for @region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get region;

  /// No description provided for @locationUnknown.
  ///
  /// In en, this message translates to:
  /// **'I do not know the location'**
  String get locationUnknown;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @useExifDate.
  ///
  /// In en, this message translates to:
  /// **'Use photo EXIF date'**
  String get useExifDate;

  /// No description provided for @exifDateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Select a photo with capture-date metadata first.'**
  String get exifDateUnavailable;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date manually'**
  String get selectDate;

  /// No description provided for @useToday.
  ///
  /// In en, this message translates to:
  /// **'Use today\'s date'**
  String get useToday;

  /// No description provided for @dateUnknown.
  ///
  /// In en, this message translates to:
  /// **'I do not know the date'**
  String get dateUnknown;

  /// No description provided for @locationServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled. You can choose a region or use the map.'**
  String get locationServicesDisabled;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was not granted. You can choose a region or use the map.'**
  String get locationPermissionDenied;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Current location is unavailable. You can choose a region or use the map.'**
  String get locationUnavailable;

  /// No description provided for @approximateGridSelected.
  ///
  /// In en, this message translates to:
  /// **'Approximate map grid selected'**
  String get approximateGridSelected;

  /// No description provided for @contextSummary.
  ///
  /// In en, this message translates to:
  /// **'Observation context'**
  String get contextSummary;

  /// No description provided for @identify.
  ///
  /// In en, this message translates to:
  /// **'Identify'**
  String get identify;

  /// No description provided for @analyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing'**
  String get analyzing;

  /// No description provided for @preparingImage.
  ///
  /// In en, this message translates to:
  /// **'Preparing image'**
  String get preparingImage;

  /// No description provided for @findingBird.
  ///
  /// In en, this message translates to:
  /// **'Finding bird'**
  String get findingBird;

  /// No description provided for @comparingSpecies.
  ///
  /// In en, this message translates to:
  /// **'Comparing species'**
  String get comparingSpecies;

  /// No description provided for @calculatingRegionalResults.
  ///
  /// In en, this message translates to:
  /// **'Calculating regional results'**
  String get calculatingRegionalResults;

  /// No description provided for @inferenceFailed.
  ///
  /// In en, this message translates to:
  /// **'Identification could not be completed. Please try again.'**
  String get inferenceFailed;

  /// No description provided for @identificationResult.
  ///
  /// In en, this message translates to:
  /// **'Identification result'**
  String get identificationResult;

  /// No description provided for @mockResultNotice.
  ///
  /// In en, this message translates to:
  /// **'This is a deterministic mock result while the first mobile model is being prepared.'**
  String get mockResultNotice;

  /// No description provided for @bestMatch.
  ///
  /// In en, this message translates to:
  /// **'Best match'**
  String get bestMatch;

  /// No description provided for @topCandidates.
  ///
  /// In en, this message translates to:
  /// **'Top 5 candidates'**
  String get topCandidates;

  /// No description provided for @highMatch.
  ///
  /// In en, this message translates to:
  /// **'High match'**
  String get highMatch;

  /// No description provided for @mediumMatch.
  ///
  /// In en, this message translates to:
  /// **'Medium match'**
  String get mediumMatch;

  /// No description provided for @lowMatch.
  ///
  /// In en, this message translates to:
  /// **'Low match'**
  String get lowMatch;

  /// No description provided for @locationEffect.
  ///
  /// In en, this message translates to:
  /// **'Location effect'**
  String get locationEffect;

  /// No description provided for @dateEffect.
  ///
  /// In en, this message translates to:
  /// **'Date effect'**
  String get dateEffect;

  /// No description provided for @contextAffected.
  ///
  /// In en, this message translates to:
  /// **'This context was used to rerank candidates.'**
  String get contextAffected;

  /// No description provided for @contextNotUsed.
  ///
  /// In en, this message translates to:
  /// **'Visual candidates are shown without this context.'**
  String get contextNotUsed;

  /// No description provided for @modelVersion.
  ///
  /// In en, this message translates to:
  /// **'Model version'**
  String get modelVersion;

  /// No description provided for @shareResult.
  ///
  /// In en, this message translates to:
  /// **'Share result'**
  String get shareResult;

  /// No description provided for @saveToHistory.
  ///
  /// In en, this message translates to:
  /// **'Save to history'**
  String get saveToHistory;

  /// No description provided for @shareText.
  ///
  /// In en, this message translates to:
  /// **'FirBird matched this bird as {turkishName} ({scientificName}).'**
  String shareText(Object turkishName, Object scientificName);

  /// No description provided for @family.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get family;

  /// No description provided for @habitat.
  ///
  /// In en, this message translates to:
  /// **'Habitat'**
  String get habitat;

  /// No description provided for @migrationStatus.
  ///
  /// In en, this message translates to:
  /// **'Migration status'**
  String get migrationStatus;

  /// No description provided for @sources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sources;

  /// No description provided for @mockDataValue.
  ///
  /// In en, this message translates to:
  /// **'Available with the licensed Türkiye package.'**
  String get mockDataValue;

  /// No description provided for @mockSpeciesNotice.
  ///
  /// In en, this message translates to:
  /// **'This screen uses the mock catalogue record. Real species content and attribution will arrive with the region package.'**
  String get mockSpeciesNotice;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No identifications have been saved on this device.'**
  String get historyEmpty;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearHistory;

  /// No description provided for @historySetting.
  ///
  /// In en, this message translates to:
  /// **'Save identification history'**
  String get historySetting;

  /// No description provided for @historySettingDescription.
  ///
  /// In en, this message translates to:
  /// **'Results are stored only on this device. Original photos are not copied.'**
  String get historySettingDescription;

  /// No description provided for @activePackage.
  ///
  /// In en, this message translates to:
  /// **'Active region package'**
  String get activePackage;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacySummary.
  ///
  /// In en, this message translates to:
  /// **'Photos and location stay on your device.'**
  String get privacySummary;

  /// No description provided for @sexAgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Sex & Life Stage'**
  String get sexAgeTitle;

  /// No description provided for @sexLabel.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get sexLabel;

  /// No description provided for @ageLabel.
  ///
  /// In en, this message translates to:
  /// **'Life Stage'**
  String get ageLabel;

  /// No description provided for @sexFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get sexFemale;

  /// No description provided for @sexMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get sexMale;

  /// No description provided for @sexUnknown.
  ///
  /// In en, this message translates to:
  /// **'Uncertain'**
  String get sexUnknown;

  /// No description provided for @ageChick.
  ///
  /// In en, this message translates to:
  /// **'Chick'**
  String get ageChick;

  /// No description provided for @ageJuvenile.
  ///
  /// In en, this message translates to:
  /// **'Juvenile'**
  String get ageJuvenile;

  /// No description provided for @ageAdult.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get ageAdult;

  /// No description provided for @ageUnknown.
  ///
  /// In en, this message translates to:
  /// **'Uncertain'**
  String get ageUnknown;

  /// No description provided for @sexAgeMethodBioclip2.
  ///
  /// In en, this message translates to:
  /// **'BioCLIP 2 visual estimate'**
  String get sexAgeMethodBioclip2;

  /// No description provided for @sexAgeMethodUserValidated.
  ///
  /// In en, this message translates to:
  /// **'User validated'**
  String get sexAgeMethodUserValidated;

  /// No description provided for @sexAgeMethodHybrid.
  ///
  /// In en, this message translates to:
  /// **'Hybrid method'**
  String get sexAgeMethodHybrid;

  /// No description provided for @sexUnreliableWarning.
  ///
  /// In en, this message translates to:
  /// **'Sex determination from photos may not be reliable for this species.'**
  String get sexUnreliableWarning;

  /// No description provided for @sexSeasonalWarning.
  ///
  /// In en, this message translates to:
  /// **'Sex estimate is based on plumage only and may vary by season.'**
  String get sexSeasonalWarning;

  /// No description provided for @sexAgeConflictWarning.
  ///
  /// In en, this message translates to:
  /// **'Sex and life stage information may be conflicting.'**
  String get sexAgeConflictWarning;

  /// No description provided for @correctSexAge.
  ///
  /// In en, this message translates to:
  /// **'Correct / Validate'**
  String get correctSexAge;

  /// No description provided for @correctionTitle.
  ///
  /// In en, this message translates to:
  /// **'Sex & Life Stage Validation'**
  String get correctionTitle;

  /// No description provided for @correctionApprovalQuestion.
  ///
  /// In en, this message translates to:
  /// **'Does the model prediction look correct?'**
  String get correctionApprovalQuestion;

  /// No description provided for @correctionApprove.
  ///
  /// In en, this message translates to:
  /// **'Yes, correct'**
  String get correctionApprove;

  /// No description provided for @correctionNotCorrect.
  ///
  /// In en, this message translates to:
  /// **'No, correct it'**
  String get correctionNotCorrect;

  /// No description provided for @correctionWhichParam.
  ///
  /// In en, this message translates to:
  /// **'Which information would you like to correct?'**
  String get correctionWhichParam;

  /// No description provided for @correctionNext.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get correctionNext;

  /// No description provided for @correctionSexQuestion.
  ///
  /// In en, this message translates to:
  /// **'Select sex'**
  String get correctionSexQuestion;

  /// No description provided for @correctionAgeQuestion.
  ///
  /// In en, this message translates to:
  /// **'Select life stage'**
  String get correctionAgeQuestion;

  /// No description provided for @correctionNotSure.
  ///
  /// In en, this message translates to:
  /// **'Not sure'**
  String get correctionNotSure;

  /// No description provided for @correctionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get correctionSave;

  /// No description provided for @correctionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get correctionCancel;

  /// No description provided for @correctionPhotoQuality.
  ///
  /// In en, this message translates to:
  /// **'Photo is clear and bird is fully visible'**
  String get correctionPhotoQuality;

  /// No description provided for @correctionExpertVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified by an expert'**
  String get correctionExpertVerified;

  /// No description provided for @correctionSpecies.
  ///
  /// In en, this message translates to:
  /// **'Species'**
  String get correctionSpecies;

  /// No description provided for @correctionSpeciesQuestion.
  ///
  /// In en, this message translates to:
  /// **'Select correct species:'**
  String get correctionSpeciesQuestion;

  /// No description provided for @correctionSearchSpecies.
  ///
  /// In en, this message translates to:
  /// **'Search species...'**
  String get correctionSearchSpecies;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
