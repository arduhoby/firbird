import 'dart:convert';
import 'dart:math' as math;

import 'package:firbird/app/back_to_home_button.dart';
import 'package:firbird/app/app_drawer.dart';
import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:firbird/observation_context/ebird_context_package.dart';
import 'package:firbird/observation_context/ebird_live_observation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

class NearbyBirdsScreen extends StatefulWidget {
  const NearbyBirdsScreen({super.key});

  @override
  State<NearbyBirdsScreen> createState() => _NearbyBirdsScreenState();
}

Future<List<_NearbyBird>> _loadBirdCatalog() async {
  final Map<String, dynamic> json =
      jsonDecode(
            await rootBundle.loadString(
              'assets/audio_catalog/turkey-birdnet-v1.json',
            ),
          )
          as Map<String, dynamic>;
  return (json['species'] as List<dynamic>? ?? const <dynamic>[])
      .cast<Map<String, dynamic>>()
      .map(_NearbyBird.fromJson)
      .toList(growable: false);
}

Map<String, String> _photoUrlsByScientificName(List<_NearbyBird> birds) =>
    <String, String>{
      for (final _NearbyBird bird in birds)
        bird.scientificName.toLowerCase(): bird.imageUrl,
    };

String _observationMergeKey(EbirdRecentObservation observation) =>
    '${observation.locationId}|${observation.scientificName.toLowerCase()}';

List<EbirdRecentObservation> _mergeLiveObservations(
  List<EbirdRecentObservation> existing,
  List<EbirdRecentObservation> live,
) {
  final Map<String, EbirdRecentObservation> archivedBySpecies =
      <String, EbirdRecentObservation>{
        for (final EbirdRecentObservation observation in existing)
          _observationMergeKey(observation): observation,
      };
  final List<EbirdRecentObservation> resolvedLive = live
      .map((EbirdRecentObservation observation) {
        if (observation.observerName?.trim().isNotEmpty == true) {
          return observation;
        }
        final EbirdRecentObservation? archived =
            archivedBySpecies[_observationMergeKey(observation)];
        if (archived?.observerName?.trim().isNotEmpty != true) {
          return observation;
        }
        return observation.copyWith(
          observerName: archived!.observerName,
          observerIdentityFromArchive: true,
        );
      })
      .toList(growable: false);
  final Set<String> liveKeys = resolvedLive.map(_observationMergeKey).toSet();
  return <EbirdRecentObservation>[
    ...existing.where(
      (EbirdRecentObservation observation) =>
          !liveKeys.contains(_observationMergeKey(observation)),
    ),
    ...resolvedLive,
  ];
}

/// Opens the hotspot map without replacing the current route. This is used by
/// live listening so the recorder and inference session keep running behind it.
Future<void> showNearbyHotspotMapSheet(
  BuildContext context, {
  double? latitude,
  double? longitude,
}) async {
  final LatLng? center = await _resolveMapCenter(
    latitude: latitude,
    longitude: longitude,
  );
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _StandaloneHotspotMap(center: center),
    ),
  );
}

Future<LatLng?> _resolveMapCenter({double? latitude, double? longitude}) async {
  if (latitude != null && longitude != null) {
    return LatLng(latitude, longitude);
  }
  if (!await Geolocator.isLocationServiceEnabled()) return null;
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission != LocationPermission.whileInUse &&
      permission != LocationPermission.always) {
    return null;
  }
  final Position position = await Geolocator.getCurrentPosition();
  return LatLng(position.latitude, position.longitude);
}

class _StandaloneHotspotMap extends StatefulWidget {
  const _StandaloneHotspotMap({this.center});

  final LatLng? center;

  @override
  State<_StandaloneHotspotMap> createState() => _StandaloneHotspotMapState();
}

class _StandaloneHotspotMapState extends State<_StandaloneHotspotMap> {
  late final Future<_StandaloneMapData> _data = _loadData();

  Future<_StandaloneMapData> _loadData() async {
    final List<_NearbyBird> birds = await _loadBirdCatalog();
    return _StandaloneMapData(
      package: EbirdContextPackage.fromJsonStrings(
        manifest: await rootBundle.loadString(
          'assets/ebird_context/manifest.json',
        ),
        hotspots: await rootBundle.loadString(
          'assets/ebird_context/hotspots.json',
        ),
        recentObservations: await rootBundle.loadString(
          'assets/ebird_context/recent_observations.json',
        ),
      ),
      photoUrls: _photoUrlsByScientificName(birds),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Haritayı kapat',
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Yakındaki gözlem noktaları'),
    ),
    body: FutureBuilder<_StandaloneMapData>(
      future: _data,
      builder: (BuildContext context, AsyncSnapshot<_StandaloneMapData> snap) {
        if (!snap.hasData) {
          if (snap.hasError) {
            return const Center(child: Text('Harita verisi yüklenemedi.'));
          }
          return const Center(child: CircularProgressIndicator());
        }
        return Padding(
          padding: const EdgeInsets.all(12),
          child: _HotspotMapCard(
            expanded: true,
            onToggle: () {},
            center: widget.center,
            hotspots: snap.data!.package.hotspots,
            recentObservations: snap.data!.package.recentObservations,
            photoUrls: snap.data!.photoUrls,
            hasGps: widget.center != null,
          ),
        );
      },
    ),
  );
}

/* Duplicate block retained only temporarily by an earlier patch; disabled.
The active implementation is above. */
/*
/// Opens the hotspot map without replacing the current route. This is used by
/// live listening so the recorder and inference session keep running behind it.
Future<void> showNearbyHotspotMapSheet(
  BuildContext context, {
  double? latitude,
  double? longitude,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _StandaloneHotspotMap(
        center: latitude != null && longitude != null
            ? LatLng(latitude, longitude)
            : null,
      ),
    ),
  );
}

class _StandaloneHotspotMap extends StatefulWidget {
  const _StandaloneHotspotMap({this.center});

  final LatLng? center;

  @override
  State<_StandaloneHotspotMap> createState() => _StandaloneHotspotMapState();
}

class _StandaloneHotspotMapState extends State<_StandaloneHotspotMap> {
  late final Future<EbirdContextPackage> _package = _loadPackage();

  Future<EbirdContextPackage> _loadPackage() async =>
      EbirdContextPackage.fromJsonStrings(
        manifest: await rootBundle.loadString(
          'assets/ebird_context/manifest.json',
        ),
        hotspots: await rootBundle.loadString(
          'assets/ebird_context/hotspots.json',
        ),
        recentObservations: await rootBundle.loadString(
          'assets/ebird_context/recent_observations.json',
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Haritayı kapat',
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Yakındaki gözlem noktaları'),
    ),
    body: FutureBuilder<EbirdContextPackage>(
      future: _package,
      builder: (BuildContext context, AsyncSnapshot<EbirdContextPackage> snap) {
        if (!snap.hasData) {
          if (snap.hasError) {
            return const Center(child: Text('Harita verisi yüklenemedi.'));
          }
          return const Center(child: CircularProgressIndicator());
        }
        return Padding(
          padding: const EdgeInsets.all(12),
          child: _HotspotMapCard(
            expanded: true,
            onToggle: () {},
            center: widget.center,
            hotspots: snap.data!.hotspots,
            recentObservations: snap.data!.recentObservations,
            hasGps: widget.center != null,
          ),
        );
      },
    ),
  );
}

*/
class _NearbyBirdsScreenState extends State<NearbyBirdsScreen> {
  late final Future<List<_NearbyBird>> _birds = _loadBirdCatalog();
  DateTime _date = DateTime.now();
  bool _locating = false;
  bool _hasApproximateLocation = false;
  String? _locationMessage;
  String? _selectedRegion;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  // Harita
  Position? _currentPosition;
  bool _mapExpanded = false;
  List<EbirdHotspot> _hotspots = <EbirdHotspot>[];
  List<EbirdRecentObservation> _recentObservations = <EbirdRecentObservation>[];
  bool _hotspotsLoaded = false;
  final EbirdLiveObservationService _liveObservationService =
      EbirdLiveObservationService();
  int _nearbyRadiusKm = 20;
  bool _nearbyRefreshLoading = false;
  String? _nearbyRefreshStatus;

  static const List<String> _regions = <String>[
    'Marmara',
    'Ege',
    'Akdeniz',
    'İç Anadolu',
    'Karadeniz',
    'Doğu Anadolu',
    'Güneydoğu Anadolu',
  ];

  /// Bundled hotspot verisini yükle (ebird_context/hotspots.json asset'i)
  Future<void> _loadHotspots() async {
    if (_hotspotsLoaded) return;
    try {
      final List<String> documents = await Future.wait(<Future<String>>[
        rootBundle.loadString('assets/ebird_context/hotspots.json'),
        rootBundle.loadString('assets/ebird_context/recent_observations.json'),
      ]);
      final dynamic decodedHotspots = jsonDecode(documents[0]);
      final dynamic decodedObservations = jsonDecode(documents[1]);
      final List<dynamic> hotspotList = decodedHotspots is List<dynamic>
          ? decodedHotspots
          : <dynamic>[];
      final List<dynamic> observationList = decodedObservations is List<dynamic>
          ? decodedObservations
          : <dynamic>[];
      setState(() {
        _hotspots = hotspotList
            .cast<Map<String, dynamic>>()
            .map(EbirdHotspot.fromJson)
            .toList(growable: false);
        _recentObservations = observationList
            .cast<Map<String, dynamic>>()
            .map(EbirdRecentObservation.fromJson)
            .toList(growable: false);
        _hotspotsLoaded = true;
      });
    } catch (e) {
      debugPrint('Hotspot verisi yüklenemedi: $e');
      if (mounted) setState(() => _hotspotsLoaded = true);
    }
  }

  Future<void> _chooseDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  Future<void> _useLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _NearbyLocationException('Konum hizmeti kapalı.');
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const _NearbyLocationException('Konum izni verilmedi.');
      }
      final Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _hasApproximateLocation = true;
          _selectedRegion = _regionFor(position);
          _locationMessage = _selectedRegion == null
              ? 'Yaklaşık konum bu oturum için kullanılıyor.'
              : 'Yaklaşık konuma göre $_selectedRegion seçildi.';
          _mapExpanded = true; // GPS alındığında haritayı otomatik aç
        });
        await _loadHotspots();
      }
    } on _NearbyLocationException catch (error) {
      if (mounted) setState(() => _locationMessage = error.message);
    } catch (_) {
      if (mounted) setState(() => _locationMessage = 'Konum alınamadı.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _toggleMap() async {
    if (!_mapExpanded) {
      await _loadHotspots();
    }
    setState(() => _mapExpanded = !_mapExpanded);
  }

  Future<void> _refreshNearbyEbird() async {
    final Position? position = _currentPosition;
    if (position == null) return;
    if (!await _liveObservationService.hasApiKey()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Önce Ayarlar’dan kişisel eBird API anahtarını ekleyin.',
          ),
        ),
      );
      context.push('/settings');
      return;
    }
    setState(() {
      _nearbyRefreshLoading = true;
      _nearbyRefreshStatus = null;
    });
    try {
      final List<EbirdRecentObservation> downloaded =
          await _liveObservationService.refreshNearby(
            latitude: position.latitude,
            longitude: position.longitude,
            radiusKm: _nearbyRadiusKm,
          );
      if (mounted) {
        setState(() {
          _recentObservations = _mergeLiveObservations(
            _recentObservations,
            downloaded,
          );
          _nearbyRefreshStatus =
              '$_nearbyRadiusKm km içinden ${downloaded.length} güncel kayıt indirildi.';
        });
      }
    } on EbirdLiveDataException catch (error) {
      if (mounted) setState(() => _nearbyRefreshStatus = error.message);
    } finally {
      if (mounted) setState(() => _nearbyRefreshLoading = false);
    }
  }

  String? _regionFor(Position position) {
    if (position.latitude >= 39.4 &&
        position.latitude <= 42.1 &&
        position.longitude >= 26.0 &&
        position.longitude <= 31.8) {
      return 'Marmara';
    }
    return null;
  }

  Set<String> _seasonallyObservedSpecies() {
    final Position? position = _currentPosition;
    if (position == null) return const <String>{};
    final Set<String> result = <String>{};
    for (final EbirdRecentObservation observation in _recentObservations) {
      if (_seasonForMonth(observation.observedAt.month) !=
          _seasonForMonth(_date.month)) {
        continue;
      }
      final double distanceKm = _distanceKm(
        position.latitude,
        position.longitude,
        observation.latitude,
        observation.longitude,
      );
      if (distanceKm <= 20) {
        result.add(observation.scientificName.toLowerCase());
      }
    }
    return result;
  }

  int _seasonForMonth(int month) {
    if (month == 12 || month <= 2) return 0;
    if (month <= 5) return 1;
    if (month <= 8) return 2;
    return 3;
  }

  String _seasonLabel(int month) {
    switch (_seasonForMonth(month)) {
      case 0:
        return 'kış';
      case 1:
        return 'ilkbahar';
      case 2:
        return 'yaz';
      default:
        return 'sonbahar';
    }
  }

  double _distanceKm(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const double earthRadiusKm = 6371;
    final double latitudeDelta = _radians(latitude2 - latitude1);
    final double longitudeDelta = _radians(longitude2 - longitude1);
    final double a =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(_radians(latitude1)) *
            math.cos(_radians(latitude2)) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: const AppDrawer(),
    appBar: AppBar(
      title: const Text('Yakınımdaki kuşlar'),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menü',
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      actions: const [BackToHomeButton()],
    ),
    body: FutureBuilder<List<_NearbyBird>>(
      future: _birds,
      builder: (BuildContext context, AsyncSnapshot<List<_NearbyBird>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<_NearbyBird> all = snapshot.data ?? const <_NearbyBird>[];
        final String normalizedQuery = _query.trim().toLowerCase();
        final Set<String> seasonallyObserved = _seasonallyObservedSpecies();
        final List<_NearbyBird> matched = all
            .where(
              (_NearbyBird bird) =>
                  seasonallyObserved.contains(
                    bird.scientificName.toLowerCase(),
                  ) &&
                  (normalizedQuery.isEmpty ||
                      bird.searchableText.contains(normalizedQuery)),
            )
            .toList(growable: false);
        final List<_NearbyBird> localBirds =
            matched.where((_NearbyBird bird) => !bird.isRare).toList()..sort(
              (_NearbyBird a, _NearbyBird b) =>
                  a.turkishName.compareTo(b.turkishName),
            );
        final List<_NearbyBird> rareBirds =
            matched.where((_NearbyBird bird) => bird.isRare).toList()..sort(
              (_NearbyBird a, _NearbyBird b) =>
                  a.turkishName.compareTo(b.turkishName),
            );
        final Map<String, String> photoUrls = _photoUrlsByScientificName(all);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Text(
              'Bölgende görülebilecek kuşlar',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'GPS konumunun 20 km çevresinde, seçilen tarihle aynı mevsimde kaydedilmiş türler gösterilir. Yerel türler yeşil, nadir kayıtlar kırmızı ayrılır.',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _locating ? null : _useLocation,
              icon: Icon(
                _hasApproximateLocation ? Icons.location_on : Icons.my_location,
              ),
              label: Text(
                _locating ? 'Konum alınıyor…' : 'Mevcut konumumu kullan',
              ),
            ),
            if (_locationMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_locationMessage!),
              ),
            if (_currentPosition != null) ...<Widget>[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'eBird güncel veri',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_nearbyRadiusKm km içindeki son 30 günlük hotspot gözlemlerini, yalnızca sen dokunduğunda indirir.',
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<int>(
                        segments: const <ButtonSegment<int>>[
                          ButtonSegment<int>(value: 20, label: Text('20 km')),
                          ButtonSegment<int>(value: 50, label: Text('50 km')),
                        ],
                        selected: <int>{_nearbyRadiusKm},
                        onSelectionChanged: _nearbyRefreshLoading
                            ? null
                            : (Set<int> values) => setState(
                                () => _nearbyRadiusKm = values.first,
                              ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _nearbyRefreshLoading
                            ? null
                            : _refreshNearbyEbird,
                        icon: _nearbyRefreshLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_for_offline_outlined),
                        label: Text(
                          _nearbyRefreshLoading
                              ? 'eBird’den indiriliyor…'
                              : '$_nearbyRadiusKm km verisini indir',
                        ),
                      ),
                      if (_nearbyRefreshStatus != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Icon(
                              _nearbyRefreshStatus!.contains('indirildi')
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              color: _nearbyRefreshStatus!.contains('indirildi')
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: Text(_nearbyRefreshStatus!)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),

            // ── Harita Kartı ──────────────────────────────────────────
            _HotspotMapCard(
              expanded: _mapExpanded,
              onToggle: _toggleMap,
              center: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    )
                  : null,
              hotspots: _hotspots,
              recentObservations: _recentObservations,
              photoUrls: photoUrls,
              hasGps: _currentPosition != null,
            ),
            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              key: ValueKey<String?>(_selectedRegion),
              initialValue: _selectedRegion,
              decoration: const InputDecoration(
                labelText: 'Bölge seç',
                border: OutlineInputBorder(),
              ),
              items: _regions
                  .map(
                    (String region) => DropdownMenuItem<String>(
                      value: region,
                      child: Text(region),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (String? region) => setState(() {
                _selectedRegion = region;
                _hasApproximateLocation = region != null;
                _locationMessage = region == null
                    ? null
                    : '$region bölgesi bu oturum için kullanılacak.';
              }),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _chooseDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                'Tarih: ${_date.day.toString().padLeft(2, '0')}.${_date.month.toString().padLeft(2, '0')}.${_date.year}',
              ),
            ),
            TextField(
              controller: _searchController,
              onChanged: (String value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Tür ara',
                hintText: 'Örnek: ebabil',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Aramayı temizle',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            Text(
              '${localBirds.length + rareBirds.length} tür · 20 km · ${_seasonLabel(_date.month)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (all.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Türkiye tür paketi telefonda bulunamadı. Önce cihaz içi model/paket kurulmalıdır.',
                  ),
                ),
              )
            else if (_currentPosition == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '20 km çevrendeki mevsimsel kuşları görmek için “Mevcut konumumu kullan” düğmesine dokun.',
                  ),
                ),
              )
            else if (localBirds.isEmpty && rareBirds.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Bu mevsim için 20 km çevrede eşleşen bir kayıt bulunamadı. Haritadaki güncel veriyi indirip yeniden deneyebilirsin.',
                  ),
                ),
              )
            else ...<Widget>[
              if (localBirds.isNotEmpty) ...<Widget>[
                const _BirdGroupHeader(
                  label: 'Yerel ve mevsimsel kuşlar',
                  color: Colors.green,
                ),
                ...localBirds.map(
                  (_NearbyBird bird) => _NearbyBirdCard(
                    bird: bird,
                    color: Colors.green,
                    label: '20 km · bu mevsimde kaydedildi',
                  ),
                ),
              ],
              if (rareBirds.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                const _BirdGroupHeader(
                  label: 'Nadir kuş kayıtları',
                  color: Colors.red,
                ),
                ...rareBirds.map(
                  (_NearbyBird bird) => _NearbyBirdCard(
                    bird: bird,
                    color: Colors.red,
                    label: '20 km · nadir kayıt',
                  ),
                ),
              ],
            ],
          ],
        );
      },
    ),
  );
}

// ── Harita Bileşeni ───────────────────────────────────────────────────────────

class _HotspotMapCard extends StatefulWidget {
  const _HotspotMapCard({
    required this.expanded,
    required this.onToggle,
    required this.center,
    required this.hotspots,
    required this.recentObservations,
    required this.photoUrls,
    required this.hasGps,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final LatLng? center;
  final List<EbirdHotspot> hotspots;
  final List<EbirdRecentObservation> recentObservations;
  final Map<String, String> photoUrls;
  final bool hasGps;

  @override
  State<_HotspotMapCard> createState() => _HotspotMapCardState();
}

class _HotspotMapCardState extends State<_HotspotMapCard> {
  final MapController _mapController = MapController();
  final EbirdLiveObservationService _liveObservationService =
      EbirdLiveObservationService();
  static const LatLng _turkiyeCenter = LatLng(39.0, 35.0);
  static const double _turkiyeZoom = 5.5;
  static const double _gpsZoom = 13.0;
  bool _mapReady = false;
  double _mapZoom = _turkiyeZoom;

  @override
  void didUpdateWidget(_HotspotMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // GPS yeni alındıysa ya da harita henüz yeni açıldıysa merkeze git
    final bool gpsArrived =
        widget.center != null && oldWidget.center != widget.center;
    final bool mapJustOpened =
        widget.expanded && !oldWidget.expanded && widget.center != null;
    if (_mapReady && (gpsArrived || mapJustOpened)) {
      _mapController.move(widget.center!, _gpsZoom);
    }
  }

  void _showHotspotSheet(EbirdHotspot hs) {
    List<EbirdRecentObservation> observations =
        widget.recentObservations
            .where((EbirdRecentObservation item) => item.locationId == hs.id)
            .toList(growable: false)
          ..sort(
            (EbirdRecentObservation a, EbirdRecentObservation b) =>
                b.observedAt.compareTo(a.observedAt),
          );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheetState) {
          final ThemeData theme = Theme.of(ctx);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.teal.shade600.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.flutter_dash,
                          color: Colors.teal.shade600,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          hs.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _HotspotInfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Koordinat',
                    value:
                        '${hs.latitude.toStringAsFixed(4)}°N, ${hs.longitude.toStringAsFixed(4)}°E',
                  ),
                  if (hs.allTimeSpeciesCount != null) ...<Widget>[
                    const SizedBox(height: 8),
                    _HotspotInfoRow(
                      icon: Icons.flutter_dash_outlined,
                      label: 'Toplam tür',
                      value: '${hs.allTimeSpeciesCount} tür',
                    ),
                  ],
                  if (hs.latestObservationAt != null) ...<Widget>[
                    const SizedBox(height: 8),
                    _HotspotInfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Son gözlem',
                      value: _formatDate(hs.latestObservationAt!),
                    ),
                  ],
                  if (hs.subnational1Code != null) ...<Widget>[
                    const SizedBox(height: 8),
                    _HotspotInfoRow(
                      icon: Icons.map_outlined,
                      label: 'Bölge',
                      value: hs.subnational1Code!,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Text(
                        'Son kaydedilen kuşlar',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text('${observations.length} kayıt'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (observations.isEmpty)
                    const Text(
                      'Bu nokta için indirilen güncel pakette gözlem kaydı yok.',
                    )
                  else
                    ...observations.map(
                      (EbirdRecentObservation observation) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _BirdPhoto(
                          scientificName: observation.scientificName,
                          imageUrl:
                              widget.photoUrls[observation.scientificName
                                  .toLowerCase()],
                          size: 52,
                        ),
                        title: Text(
                          observation.turkishName?.trim().isNotEmpty == true
                              ? observation.turkishName!
                              : observation.commonName,
                        ),
                        subtitle: Text(
                          '${observation.scientificName} · ${observation.commonName}\n'
                          '${_formatDate(observation.observedAt)} · '
                          '${observation.observerName?.trim().isNotEmpty == true
                              ? observation.observerIdentityFromArchive
                                    ? 'EBD gözlemci kimliği: ${observation.observerName}'
                                    : 'Gözlemci kimliği: ${observation.observerName}'
                              : observation.isLive
                              ? 'Canlı eBird kaydı · gözlemci kimliği API’de yok'
                              : 'Gözlemci kimliği paylaşılmamış'}',
                        ),
                        isThreeLine: true,
                        trailing: observation.count == null
                            ? null
                            : Text('×${observation.count}'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        setSheetState(() {});
                        try {
                          final List<EbirdRecentObservation> refreshed =
                              await _liveObservationService.refreshHotspot(
                                hs.id,
                              );
                          refreshed.sort(
                            (
                              EbirdRecentObservation a,
                              EbirdRecentObservation b,
                            ) => b.observedAt.compareTo(a.observedAt),
                          );
                          if (ctx.mounted) {
                            setSheetState(
                              () => observations = _mergeLiveObservations(
                                observations,
                                refreshed,
                              ),
                            );
                          }
                        } on EbirdApiKeyMissingException {
                          if (!ctx.mounted) return;
                          await showDialog<void>(
                            context: ctx,
                            builder: (BuildContext dialogContext) => AlertDialog(
                              title: const Text('eBird API anahtarı gerekli'),
                              content: const Text(
                                'Ayarlar bölümünden kendi eBird API anahtarını ekleyin.',
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Vazgeç'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    Navigator.pop(ctx);
                                    context.push('/settings');
                                  },
                                  child: const Text('Ayarlara git'),
                                ),
                              ],
                            ),
                          );
                        } on EbirdLiveDataException catch (error) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(error.message)),
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Son verileri eBird’den yenile'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _mapController.move(
                          LatLng(hs.latitude, hs.longitude),
                          14.0,
                        );
                      },
                      child: const Text('Haritada yakınlaştır'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  double _metersPerPixel(double latitude, double zoom) =>
      156543.03392 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);

  double _niceScaleMeters(double maximumMeters) {
    const List<double> candidates = <double>[
      1,
      2,
      5,
      10,
      20,
      50,
      100,
      200,
      500,
      1000,
      2000,
      5000,
      10000,
      20000,
      50000,
      100000,
      200000,
      500000,
      1000000,
    ];
    return candidates.lastWhere(
      (double value) => value <= maximumMeters,
      orElse: () => candidates.first,
    );
  }

  String _formatDistance(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} km'
      : '${meters.round()} m';

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LatLng initialCenter = widget.center ?? _turkiyeCenter;
    final double initialZoom = widget.center != null ? _gpsZoom : _turkiyeZoom;
    final double effectiveZoom = _mapReady ? _mapZoom : initialZoom;
    final double metersPerPixel = _metersPerPixel(
      widget.center?.latitude ?? _turkiyeCenter.latitude,
      effectiveZoom,
    );
    final double scaleMeters = _niceScaleMeters(metersPerPixel * 120);
    final double scalePixels = (scaleMeters / metersPerPixel).clamp(36, 120);
    final double visibleDiameterMeters =
        metersPerPixel * math.min(MediaQuery.sizeOf(context).width - 48, 340);
    final Map<String, int> observationCounts = <String, int>{};
    for (final EbirdRecentObservation observation
        in widget.recentObservations) {
      observationCounts.update(
        observation.locationId,
        (int count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: <Widget>[
          // Başlık / toggle satırı
          InkWell(
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.map_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Gözlem Noktaları Haritası',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.hasGps
                              ? 'GPS merkezli · turuncu noktalar kuş kaydı içerir'
                              : 'Haritayı aç · kayıtlı noktalar turuncu gösterilir',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: widget.expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
          ),

          // Harita alanı (animasyonlu açılıp kapanır)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: widget.expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: SizedBox(
              height: 340,
              child: Stack(
                children: <Widget>[
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: initialCenter,
                      initialZoom: initialZoom,
                      minZoom: 4,
                      maxZoom: 18,
                      onMapReady: () {
                        _mapReady = true;
                        setState(() {
                          _mapZoom = widget.center != null
                              ? _gpsZoom
                              : _turkiyeZoom;
                        });
                        // Harita hazır olduğunda GPS varsa oraya git
                        if (widget.center != null) {
                          _mapController.move(widget.center!, _gpsZoom);
                        }
                      },
                      onPositionChanged: (MapCamera camera, bool hasGesture) {
                        if ((camera.zoom - _mapZoom).abs() > 0.01 && mounted) {
                          setState(() => _mapZoom = camera.zoom);
                        }
                      },
                    ),
                    children: <Widget>[
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'org.firbird3.app',
                      ),
                      // Hotspot pinleri — tıklanabilir
                      if (widget.hotspots.isNotEmpty)
                        MarkerLayer(
                          markers: widget.hotspots.map((EbirdHotspot hs) {
                            final int observationCount =
                                observationCounts[hs.id] ?? 0;
                            final bool hasObservations = observationCount > 0;
                            return Marker(
                              point: LatLng(hs.latitude, hs.longitude),
                              width: 32,
                              height: 32,
                              child: GestureDetector(
                                onTap: () => _showHotspotSheet(hs),
                                child: Tooltip(
                                  message: hasObservations
                                      ? '${hs.name} · $observationCount kuş kaydı'
                                      : '${hs.name} · bu pakette güncel kayıt yok',
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: hasObservations
                                          ? Colors.deepOrange.shade600
                                          : Colors.teal.shade600.withValues(
                                              alpha: 0.65,
                                            ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                      boxShadow: const <BoxShadow>[
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.flutter_dash,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      // GPS konumu (büyük, belirgin pin)
                      if (widget.center != null)
                        MarkerLayer(
                          markers: <Marker>[
                            Marker(
                              point: widget.center!,
                              width: 42,
                              height: 42,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade700.withValues(
                                    alpha: 0.9,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: const <BoxShadow>[
                                    BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.my_location,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  // OSM atıfı
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '© OpenStreetMap',
                        style: TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(color: Colors.black26, blurRadius: 3),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                width: 2,
                                height: 7,
                                color: Colors.black87,
                              ),
                              Container(
                                width: scalePixels,
                                height: 2,
                                color: Colors.black87,
                              ),
                              Container(
                                width: 2,
                                height: 7,
                                color: Colors.black87,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_formatDistance(scaleMeters)} ölçek · görünüm ≈ ${_formatDistance(visibleDiameterMeters)}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Lejant
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _LegendItem(
                            color: Colors.blue.shade700,
                            icon: Icons.my_location,
                            label: 'GPS konumunuz',
                          ),
                          const SizedBox(height: 4),
                          _LegendItem(
                            color: Colors.teal.shade600,
                            icon: Icons.flutter_dash,
                            label: 'eBird noktası (tıkla)',
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Zoom ~20 km hint (yalnızca GPS varken)
                  if (widget.center != null)
                    Positioned(
                      bottom: 4,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '~20 km yarıçap',
                          style: TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _HotspotInfoRow extends StatelessWidget {
  const _HotspotInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 10),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 10)),
    ],
  );
}

// ── Yardımcı sınıflar ─────────────────────────────────────────────────────────

class _NearbyLocationException implements Exception {
  const _NearbyLocationException(this.message);
  final String message;
}

class _StandaloneMapData {
  const _StandaloneMapData({required this.package, required this.photoUrls});

  final EbirdContextPackage package;
  final Map<String, String> photoUrls;
}

class _BirdGroupHeader extends StatelessWidget {
  const _BirdGroupHeader({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
    child: Row(
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _NearbyBirdCard extends StatelessWidget {
  const _NearbyBirdCard({
    required this.bird,
    required this.color,
    required this.label,
  });

  final _NearbyBird bird;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    color: color.withValues(alpha: 0.06),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: color.withValues(alpha: 0.45)),
    ),
    child: ListTile(
      leading: _BirdPhoto(
        scientificName: bird.scientificName,
        imageUrl: bird.imageUrl,
      ),
      title: Text(bird.turkishName),
      subtitle: Text('${bird.scientificName}\n$label'),
      isThreeLine: true,
      trailing: Icon(Icons.chevron_right, color: color),
      onTap: () => context.push('/species/demo', extra: bird.prediction),
    ),
  );
}

class _BirdPhoto extends StatelessWidget {
  const _BirdPhoto({
    required this.scientificName,
    this.imageUrl,
    this.size = 58,
  });

  final String scientificName;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String resolvedUrl = imageUrl?.trim().isNotEmpty == true
        ? imageUrl!.trim()
        : 'https://birdnet.cornell.edu/taxonomy/api/image/'
              '${Uri.encodeComponent(scientificName)}?size=medium';
    final Widget unavailable = Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Text(
        'Fotoğraf\nalınamadı',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 9),
      ),
    );
    return Semantics(
      image: true,
      label: '$scientificName kuş fotoğrafı',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          resolvedUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => unavailable,
          loadingBuilder:
              (BuildContext context, Widget child, ImageChunkEvent? event) {
                if (event == null) return child;
                return SizedBox(
                  width: size,
                  height: size,
                  child: const Center(
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
        ),
      ),
    );
  }
}

class _NearbyBird {
  const _NearbyBird({
    required this.turkishName,
    required this.scientificName,
    required this.englishName,
    required this.isRare,
    required this.imageUrl,
  });

  factory _NearbyBird.fromJson(Map<String, dynamic> json) => _NearbyBird(
    turkishName:
        json['turkishName'] as String? ?? json['scientificName'] as String,
    scientificName: json['scientificName'] as String,
    englishName: json['englishName'] as String? ?? '',
    isRare: json['occurrence'] == 'accidental',
    imageUrl:
        json['imageUrl'] as String? ??
        'https://birdnet.cornell.edu/taxonomy/api/image/'
            '${Uri.encodeComponent(json['scientificName'] as String)}?size=medium',
  );

  final String turkishName;
  final String scientificName;
  final String englishName;
  final bool isRare;
  final String imageUrl;

  String get searchableText =>
      '$turkishName $scientificName $englishName'.toLowerCase();

  SpeciesPrediction get prediction => SpeciesPrediction(
    speciesId: scientificName.toLowerCase().replaceAll(' ', '-'),
    turkishName: turkishName,
    scientificName: scientificName,
    englishName: englishName,
    thumbnailUrl: imageUrl,
    score: 0,
    originLabel: isRare
        ? 'Türkiye · nadir kayıt'
        : 'Türkiye · düzenli / göçmen',
  );
}
