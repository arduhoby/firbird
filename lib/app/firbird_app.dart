import 'dart:io';

import 'package:exif/exif.dart';
import 'package:firbird/app/identification_screens.dart';
import 'package:firbird/app/history_and_settings_screens.dart';
import 'package:firbird/app/back_to_home_button.dart';
import 'package:firbird/app/observation_context_screen.dart';
import 'package:firbird/app/nearby_birds_screen.dart';
import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:firbird/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

final GoRouter _router = GoRouter(
  initialLocation: '/onboarding',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const HomeScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (BuildContext context, GoRouterState state) =>
          const OnboardingScreen(),
    ),
    GoRoute(
      path: '/photo',
      builder: (BuildContext context, GoRouterState state) =>
          const PhotoSelectionScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (BuildContext context, GoRouterState state) =>
          const HistoryScreen(),
    ),
    GoRoute(
      path: '/context',
      builder: (BuildContext context, GoRouterState state) =>
          ObservationContextScreen(
            hints: state.extra is PhotoContextHints
                ? state.extra! as PhotoContextHints
                : null,
          ),
    ),
    GoRoute(
      path: '/packages',
      builder: (BuildContext context, GoRouterState state) =>
          const FeatureScreen(feature: AppFeature.packages),
    ),
    GoRoute(
      path: '/explore',
      builder: (BuildContext context, GoRouterState state) =>
          const NearbyBirdsScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (BuildContext context, GoRouterState state) =>
          const SettingsScreen(),
    ),
    GoRoute(
      path: '/species/demo',
      builder: (BuildContext context, GoRouterState state) =>
          SpeciesDetailScreen(
            prediction:
                state.extra as SpeciesPrediction? ??
                const SpeciesPrediction(
                  speciesId: 'carduelis-carduelis',
                  turkishName: 'Saka',
                  scientificName: 'Carduelis carduelis',
                  englishName: 'European Goldfinch',
                  score: 0,
                ),
          ),
    ),
    GoRoute(
      path: '/analysis',
      builder: (BuildContext context, GoRouterState state) =>
          AnalysisScreen(request: state.extra! as IdentificationRequest),
    ),
    GoRoute(
      path: '/result',
      builder: (BuildContext context, GoRouterState state) =>
          ResultsScreen(result: state.extra! as InferenceResult),
    ),
  ],
);

class FirBirdApp extends StatelessWidget {
  const FirBirdApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color seedColor = Color(0xFF166534);

    return MaterialApp.router(
      title: 'FirBird',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(),
              Icon(
                Icons.flutter_dash_outlined,
                size: 88,
                color: Theme.of(context).colorScheme.primary,
                semanticLabel: l10n.appName,
              ),
              const SizedBox(height: 32),
              Text(
                l10n.onboardingTitle,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(l10n.onboardingBody, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(l10n.onboardingPrivacy, textAlign: TextAlign.center),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/'),
                child: Text(l10n.getStarted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: l10n.about,
            onPressed: () => context.go('/onboarding'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(
            l10n.homeHeadline,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(l10n.homeDescription),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => context.push('/photo'),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(l10n.selectPhoto),
          ),
          const SizedBox(height: 16),
          _HomeAction(
            icon: Icons.history_outlined,
            label: l10n.recentIdentifications,
            onTap: () => context.push('/history'),
          ),
          _HomeAction(
            icon: Icons.inventory_2_outlined,
            label: l10n.regionPackages,
            onTap: () => context.push('/packages'),
          ),
          _HomeAction(
            icon: Icons.travel_explore_outlined,
            label: l10n.exploreBirds,
            onTap: () => context.push('/explore'),
          ),
          _HomeAction(
            icon: Icons.settings_outlined,
            label: l10n.settings,
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class PhotoSelectionScreen extends StatefulWidget {
  const PhotoSelectionScreen({super.key});

  @override
  State<PhotoSelectionScreen> createState() => _PhotoSelectionScreenState();
}

class _PhotoSelectionScreenState extends State<PhotoSelectionScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  _PhotoMetadata _metadata = const _PhotoMetadata();
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();
  bool _dateUnknown = false;
  bool _locationUnknown = true;
  String? _selectedRegion;
  LatLng? _selectedPoint;
  bool _showMap = false;
  bool _locating = false;

  static const List<String> _regions = <String>[
    'Marmara',
    'Ege',
    'Akdeniz',
    'İç Anadolu',
    'Karadeniz',
    'Doğu Anadolu',
    'Güneydoğu Anadolu',
  ];

  Future<void> _selectPhoto() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: true,
      );
      if (image == null || !mounted) {
        return;
      }

      final _PhotoMetadata metadata = await _readMetadata(image);
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedImage = image;
        _metadata = metadata;
        _selectedDate = metadata.capturedAt ?? DateTime.now();
        _dateUnknown = false;
        _locationUnknown = true;
        _selectedRegion = null;
        _selectedPoint = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = 'metadataReadFailed');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<_PhotoMetadata> _readMetadata(XFile image) async {
    final Map<String, IfdTag> tags = await readExifFromBytes(
      await image.readAsBytes(),
    );
    final DateTime? capturedAt = _parseExifDate(
      tags['EXIF DateTimeOriginal']?.printable ??
          tags['Image DateTime']?.printable,
    );
    final bool hasGps =
        tags.containsKey('GPS GPSLatitude') &&
        tags.containsKey('GPS GPSLongitude');

    return _PhotoMetadata(
      capturedAt: capturedAt,
      hasGps: hasGps,
      orientation: tags['Image Orientation']?.printable,
    );
  }

  DateTime? _parseExifDate(String? value) {
    if (value == null) {
      return null;
    }

    final RegExpMatch? match = RegExp(
      r'^(\d{4}):(\d{2}):(\d{2})\s+(\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(value);
    if (match == null) {
      return null;
    }

    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) setState(() => _selectedDate = date);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('permission');
      }
      final Position position = await Geolocator.getCurrentPosition();
      if (mounted)
        setState(() {
          _selectedPoint = LatLng(position.latitude, position.longitude);
          _selectedRegion = null;
          _locationUnknown = false;
        });
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'locationUnavailable');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final XFile? selectedImage = _selectedImage;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectPhoto),
        leading: const BackToHomeButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          if (selectedImage == null)
            _EmptyPhotoState(isLoading: _isLoading, onSelectPhoto: _selectPhoto)
          else ...<Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(selectedImage.path),
                fit: BoxFit.contain,
                semanticLabel: l10n.photoPreview,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _selectPhoto,
              icon: const Icon(Icons.swap_horiz),
              label: Text(l10n.changePhoto),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.photoInformation,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _MetadataSummary(metadata: _metadata),
            const SizedBox(height: 16),
            Text(
              'Tarih ve konum',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tarih bilinmiyor'),
              subtitle: Text(
                _dateUnknown
                    ? 'Tarih kullanılmayacak.'
                    : _formatDate(_selectedDate),
              ),
              value: _dateUnknown,
              onChanged: (bool? value) =>
                  setState(() => _dateUnknown = value ?? false),
            ),
            if (!_dateUnknown)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Tarihi değiştir'),
                subtitle: Text(_formatDate(_selectedDate)),
                onTap: _pickDate,
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Konumu bilmiyorum'),
              subtitle: Text(
                _locationUnknown
                    ? 'Konum sonucu etkilemeyecek.'
                    : 'Yaklaşık konum seçildi.',
              ),
              value: _locationUnknown,
              onChanged: (bool? value) =>
                  setState(() => _locationUnknown = value ?? true),
            ),
            if (!_locationUnknown) ...<Widget>[
              OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: Text(
                  _locating ? 'Konum alınıyor…' : 'Mevcut konumumu kullan',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedRegion,
                decoration: const InputDecoration(
                  labelText: 'Bölgeden seç',
                  border: OutlineInputBorder(),
                ),
                items: _regions
                    .map(
                      (String region) => DropdownMenuItem<String>(
                        value: region,
                        child: Text(region),
                      ),
                    )
                    .toList(),
                onChanged: (String? region) => setState(() {
                  _selectedRegion = region;
                  _selectedPoint = null;
                }),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _showMap = !_showMap),
                icon: const Icon(Icons.map_outlined),
                label: Text(_showMap ? 'Haritayı kapat' : 'Haritadan seç'),
              ),
              if (_showMap)
                SizedBox(
                  height: 240,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: const LatLng(39.0, 35.0),
                      initialZoom: 5.5,
                      onTap: (TapPosition _, LatLng point) => setState(() {
                        _selectedPoint = point;
                        _selectedRegion = null;
                      }),
                    ),
                    children: <Widget>[
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      if (_selectedPoint != null)
                        MarkerLayer(
                          markers: <Marker>[
                            Marker(
                              point: _selectedPoint!,
                              width: 36,
                              height: 36,
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push(
                '/analysis',
                extra: IdentificationRequest(
                  image: ImageInput(uri: selectedImage.path),
                  context: IdentificationContext(
                    countryCode: _locationUnknown ? null : 'TR',
                    observationDate: _dateUnknown ? null : _selectedDate,
                  ),
                ),
              ),
              child: Text(l10n.identify),
            ),
          ],
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              l10n.metadataReadFailed,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return <String>[
      date.year.toString().padLeft(4, '0'),
      date.month.toString().padLeft(2, '0'),
      date.day.toString().padLeft(2, '0'),
    ].join('-');
  }
}

class _EmptyPhotoState extends StatelessWidget {
  const _EmptyPhotoState({
    required this.isLoading,
    required this.onSelectPhoto,
  });

  final bool isLoading;
  final VoidCallback onSelectPhoto;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Column(
      children: <Widget>[
        Icon(
          Icons.photo_library_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(l10n.photoPickerDescription, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: isLoading ? null : onSelectPhoto,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(l10n.selectPhoto),
        ),
        if (isLoading) ...<Widget>[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}

class _MetadataSummary extends StatelessWidget {
  const _MetadataSummary({required this.metadata});

  final _PhotoMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String orientation = metadata.orientation ?? l10n.notAvailable;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(<String>[l10n.orientation, orientation].join(': ')),
            Text(
              metadata.capturedAt == null
                  ? l10n.photoDateNotFound
                  : l10n.photoDateFound,
            ),
            Text(
              metadata.hasGps
                  ? l10n.photoLocationFound
                  : l10n.photoLocationNotFound,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoMetadata {
  const _PhotoMetadata({
    this.capturedAt,
    this.hasGps = false,
    this.orientation,
  });

  final DateTime? capturedAt;
  final bool hasGps;
  final String? orientation;
}

enum AppFeature { history, packages, explore, settings, speciesDetail }

class FeatureScreen extends StatelessWidget {
  const FeatureScreen({required this.feature, super.key});

  final AppFeature feature;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final _FeatureContent content = _FeatureContent.from(feature, l10n);

    return Scaffold(
      appBar: AppBar(
        title: Text(content.title),
        leading: const BackToHomeButton(),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                content.icon,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                content.title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(content.description, textAlign: TextAlign.center),
              if (feature == AppFeature.explore) ...<Widget>[
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => context.go('/species/demo'),
                  child: Text(l10n.openSpeciesDetail),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureContent {
  const _FeatureContent({
    required this.title,
    required this.description,
    required this.icon,
  });

  factory _FeatureContent.from(AppFeature feature, AppLocalizations l10n) {
    return switch (feature) {
      AppFeature.history => _FeatureContent(
        title: l10n.recentIdentifications,
        description: l10n.historyPlaceholder,
        icon: Icons.history_outlined,
      ),
      AppFeature.packages => _FeatureContent(
        title: l10n.regionPackages,
        description: l10n.packagesPlaceholder,
        icon: Icons.inventory_2_outlined,
      ),
      AppFeature.explore => _FeatureContent(
        title: l10n.exploreBirds,
        description: l10n.explorePlaceholder,
        icon: Icons.travel_explore_outlined,
      ),
      AppFeature.settings => _FeatureContent(
        title: l10n.settings,
        description: l10n.settingsPlaceholder,
        icon: Icons.settings_outlined,
      ),
      AppFeature.speciesDetail => _FeatureContent(
        title: l10n.speciesDetail,
        description: l10n.speciesPlaceholder,
        icon: Icons.menu_book_outlined,
      ),
    };
  }

  final String title;
  final String description;
  final IconData icon;
}
