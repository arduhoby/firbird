import 'dart:io';

import 'package:exif/exif.dart';
import 'package:firbird/app/crop_confirmation_screen.dart';
import 'package:firbird/app/identification_screens.dart';
import 'package:firbird/app/history_and_settings_screens.dart';
import 'package:firbird/app/back_to_home_button.dart';
import 'package:firbird/app/app_drawer.dart';
import 'package:firbird/app/observation_context_screen.dart';
import 'package:firbird/app/nearby_birds_screen.dart';
import 'package:firbird/app/model_download_screen.dart';
import 'package:firbird/app/live_audio_recording_screen.dart';
import 'package:firbird/app/firbird_theme.dart';
import 'package:firbird/app/media_player_screen.dart';
import 'package:firbird/data/app_database.dart';
import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:firbird/inference/onnx_bird_inference_engine.dart';
import 'package:firbird/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:latlong2/latlong.dart';

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/download',
      builder: (BuildContext context, GoRouterState state) =>
          const ModelDownloadScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const HomeScreen(),
    ),
    GoRoute(
      path: '/crop',
      builder: (BuildContext context, GoRouterState state) =>
          state.extra is IdentificationRequest
              ? CropConfirmationScreen(request: state.extra! as IdentificationRequest)
              : const _MissingRouteDataScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (BuildContext context, GoRouterState state) =>
          const OnboardingScreen(),
    ),
    GoRoute(
      path: '/photo',
      builder: (BuildContext context, GoRouterState state) =>
          PhotoSelectionScreen(initialMode: state.extra as String?),
    ),
    GoRoute(
      path: '/live_audio',
      builder: (BuildContext context, GoRouterState state) =>
          const LiveAudioRecordingScreen(),
    ),
    GoRoute(path: '/player', builder: (BuildContext context, GoRouterState state) => const MediaPlayerScreen()),
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
          const TurkeyPackagesScreen(),
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
          state.extra is IdentificationRequest
              ? AnalysisScreen(request: state.extra! as IdentificationRequest)
              : const _MissingRouteDataScreen(),
    ),
    GoRoute(
      path: '/result',
      builder: (BuildContext context, GoRouterState state) =>
          state.extra is InferenceResult
              ? ResultsScreen(result: state.extra! as InferenceResult)
              : const _MissingRouteDataScreen(),
    ),
  ],
);

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final AppDatabase db = ref.read(appDatabaseProvider);
    final String modeStr = await db.themeMode();
    state = switch (modeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final AppDatabase db = ref.read(appDatabaseProvider);
    final String modeStr = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await db.setThemeMode(modeStr);
  }
}

class _MissingRouteDataScreen extends StatelessWidget {
  const _MissingRouteDataScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.route_outlined, size: 48),
                const SizedBox(height: 16),
                const Text('Bu ekran için gerekli tanımlama verisi bulunamadı.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Ana sayfaya dön'),
                ),
              ],
            ),
          ),
        ),
      );
}

final NotifierProvider<ThemeNotifier, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

class FirBirdApp extends ConsumerWidget {
  const FirBirdApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'FirBird 3',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      themeMode: themeMode,
      theme: FirBirdTheme.light(),
      darkTheme: FirBirdTheme.dark(),
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
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/logo/firbird_logo.png',
                    height: 110,
                    width: 110,
                    fit: BoxFit.cover,
                  ),
                ),
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
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('FirBird 3'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menü',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: l10n.about,
            onPressed: () => context.go('/onboarding'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: <Widget>[
          Text(l10n.homeTagline, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(l10n.homePrivacy, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          _IdentificationHero(
            onTap: () => context.push('/photo', extra: 'gallery'),
          ),
          const SizedBox(height: 12),
          Row(children: <Widget>[
            Expanded(child: _QuickAction(icon: Icons.mic_none_rounded, title: 'Canlı dinle', onTap: () => context.push('/live_audio'))),
            const SizedBox(width: 8),
            Expanded(child: _QuickAction(icon: Icons.audio_file_outlined, title: 'Ses dosyası', onTap: () => context.push('/photo', extra: 'audio'))),
            const SizedBox(width: 8),
            Expanded(child: _QuickAction(icon: Icons.camera_alt_outlined, title: 'Kamera', onTap: () => context.push('/photo', extra: 'camera'))),
          ]),
          const SizedBox(height: 24),
          Text(l10n.appAboutTitle, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.shield_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'FirBird 3 v0.4.0, Türkiye’deki 503 kuş türünü fotoğraf ve ses kaydından cihaz üzerinde tanımlar. Fotoğraf, ses ve konum verileri tanımlama için cihazından ayrılmaz. Harita yalnızca sen açmayı seçersen internet kullanır.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (int index) {
          switch (index) {
            case 1:
              context.push('/explore');
            case 2:
              context.push('/history');
            case 3:
              context.push('/settings');
          }
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Tanımla'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Yakınımda'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Geçmiş'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Ayarlar'),
        ],
      ),
    );
  }
}

class _IdentificationHero extends StatelessWidget {
  const _IdentificationHero({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(children: <Widget>[
              Container(width: 48, height: 48, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(16)), child: Icon(Icons.auto_awesome_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 24)),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text('Kuşu tanımla', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('Bir fotoğraf seçerek başla')])) ,
              const Icon(Icons.arrow_forward_rounded),
            ]),
          ),
        ),
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
}

class PhotoSelectionScreen extends ConsumerStatefulWidget {
  const PhotoSelectionScreen({this.initialMode, super.key});

  final String? initialMode;

  @override
  ConsumerState<PhotoSelectionScreen> createState() => _PhotoSelectionScreenState();
}

class _PhotoSelectionScreenState extends ConsumerState<PhotoSelectionScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedMedia;
  bool _isAudio = false;
  _PhotoMetadata _metadata = const _PhotoMetadata();
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();
  bool _dateUnknown = false;
  bool _locationUnknown = true;
  String? _selectedRegion;
  LatLng? _selectedPoint;
  bool _showMap = false;
  bool _onlineMapEnabled = false;
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

  @override
  void initState() {
    super.initState();
    if (widget.initialMode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectMedia(mode: widget.initialMode!);
      });
    }
  }

  Future<void> _selectMedia({required String mode}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      XFile? mediaFile;
      
      if (mode == 'audio') {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'mp4'],
        );
        if (result != null && result.files.single.path != null) {
          mediaFile = XFile(result.files.single.path!);
        }
      } else if (mode == 'camera') {
        mediaFile = await _picker.pickImage(
          source: ImageSource.camera,
          requestFullMetadata: true,
        );
      } else {
        mediaFile = await _picker.pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: true,
        );
      }

      if (mediaFile == null || !mounted) {
        return;
      }

      final bool isAudio = (mode == 'audio');
      _PhotoMetadata metadata = const _PhotoMetadata();
      if (!isAudio) {
        metadata = await _readMetadata(mediaFile);
      }
      
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedMedia = mediaFile;
        _isAudio = isAudio;
        _metadata = metadata;
        _selectedDate = metadata.capturedAt ?? DateTime.now();
        _dateUnknown = isAudio;
        _locationUnknown = true;
        _selectedRegion = null;
        _selectedPoint = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = mode == 'audio'
            ? 'Ses dosyası açılamadı. Başka bir kayıt deneyin.'
            : 'Fotoğraf açılamadı. Desteklenen başka bir görsel deneyin.';
      });
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
      if (mounted) {
        setState(() {
          _selectedPoint = LatLng(position.latitude, position.longitude);
          _selectedRegion = null;
          _locationUnknown = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage =
            'Konum alınamadı. Bölgeden seçebilir veya konumsuz devam edebilirsiniz.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _toggleOnlineMap() async {
    if (_onlineMapEnabled) {
      setState(() => _showMap = !_showMap);
      return;
    }
    final bool? accepted = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Çevrimiçi haritayı aç?', style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 10),
            const Text('Harita görüntüleri OpenStreetMap üzerinden yüklenir. Fotoğrafınız, sesiniz ve tanımlama verileriniz gönderilmez. Bu izin yalnızca bu oturum için geçerlidir.'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(sheetContext, true),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Bu oturumda haritayı aç'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext, false),
              child: const Text('Bölgeden seç'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || accepted != true) return;
    setState(() {
      _onlineMapEnabled = true;
      _showMap = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final XFile? selectedMedia = _selectedMedia;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectPhoto),
        leading: const BackToHomeButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          if (selectedMedia == null)
            _EmptyPhotoState(
              isLoading: _isLoading, 
              onSelectGallery: () => _selectMedia(mode: 'gallery'),
              onSelectAudio: () => _selectMedia(mode: 'audio'),
              onSelectCamera: () => _selectMedia(mode: 'camera'),
            )
          else ...<Widget>[
            if (_isAudio)
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.audiotrack, size: 64),
                      const SizedBox(height: 16),
                      Text(selectedMedia.name, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(selectedMedia.path),
                  fit: BoxFit.contain,
                  semanticLabel: l10n.photoPreview,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _selectMedia(mode: _isAudio ? 'audio' : 'gallery'),
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(_isAudio ? 'Farklı Ses/Video' : 'Galeri'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _selectMedia(mode: 'camera'),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Kamera'),
                  ),
                ),
              ],
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
                initialValue: _selectedRegion,
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
                onPressed: _toggleOnlineMap,
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
              onPressed: () async {
                final String mode = await ref.read(appDatabaseProvider).cropMode();
                final request = IdentificationRequest(
                  image: ImageInput(uri: selectedMedia.path),
                  context: IdentificationContext(
                    countryCode: _locationUnknown ? null : 'TR',
                    observationDate: _dateUnknown ? null : _selectedDate,
                  ),
                );
                if (!context.mounted) return;
                if (_isAudio) {
                  context.push('/analysis', extra: request);
                } else if (mode == 'manual') {
                  context.push('/crop', extra: request);
                } else {
                  context.push('/analysis', extra: request);
                }
              },
              child: Text(l10n.identify),
            ),
          ],
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
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
    required this.onSelectGallery,
    required this.onSelectAudio,
    required this.onSelectCamera,
  });

  final bool isLoading;
  final VoidCallback onSelectGallery;
  final VoidCallback onSelectAudio;
  final VoidCallback onSelectCamera;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(
          Icons.flutter_dash_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Kuş Tanımlamak İçin',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Aşağıdaki yöntemlerden biriyle dosya veya anlık çekim seçebilirsiniz.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isLoading ? null : onSelectGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Fotoğraf Seç (Galeri)'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isLoading ? null : onSelectAudio,
            icon: const Icon(Icons.audiotrack_outlined),
            label: const Text('Dosyadan Ses veya Video Seç'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isLoading ? null : () => context.push('/live_audio'),
            icon: const Icon(Icons.graphic_eq),
            label: const Text('Anlık Canlı Ses Tanımlama (Mikrofon)'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              foregroundColor: Theme.of(context).colorScheme.onTertiary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onSelectCamera,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Anlık Fotoğraf / Kamera İle'),
          ),
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

class TurkeyPackagesScreen extends StatelessWidget {
  const TurkeyPackagesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: const AppDrawer(),
    appBar: AppBar(
      title: const Text('Bölge paketleri'),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menü',
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      actions: const [
        BackToHomeButton(),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: const ListTile(
            leading: Icon(Icons.check_circle_outline),
            title: Text('Türkiye paketi'),
            subtitle: Text(
              'Sürüm 0.1.0 · Uygulamaya dahil · 503 tür kaydı',
            ),
            trailing: Text('Hazır'),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.download_for_offline_outlined),
            title: Text('Balkanlar paketi'),
            subtitle: Text('Yakında isteğe bağlı indirilebilir olacak.'),
            trailing: Text('Yakında'),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () async {
            await OnnxBirdInferenceEngine.ensureTurkeyPackageInstalled();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Türkiye paketi hazır.')),
              );
            }
          },
          icon: const Icon(Icons.offline_bolt_outlined),
          label: const Text('Türkiye paketini hazırla'),
        ),
      ],
    ),
  );
}

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
