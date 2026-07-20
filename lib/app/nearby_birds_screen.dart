import 'dart:convert';
import 'dart:io';

import 'package:firbird/app/back_to_home_button.dart';
import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class NearbyBirdsScreen extends StatefulWidget {
  const NearbyBirdsScreen({super.key});

  @override
  State<NearbyBirdsScreen> createState() => _NearbyBirdsScreenState();
}

class _NearbyBirdsScreenState extends State<NearbyBirdsScreen> {
  late final Future<List<_NearbyBird>> _birds = _loadBirds();
  DateTime _date = DateTime.now();
  bool _includeRare = false;
  bool _locating = false;
  bool _hasApproximateLocation = false;
  String? _locationMessage;
  String? _selectedRegion;

  static const List<String> _regions = <String>[
    'Marmara',
    'Ege',
    'Akdeniz',
    'İç Anadolu',
    'Karadeniz',
    'Doğu Anadolu',
    'Güneydoğu Anadolu',
  ];

  Future<List<_NearbyBird>> _loadBirds() async {
    final Directory? external = await getExternalStorageDirectory();
    if (external == null) return const <_NearbyBird>[];
    final File file = File(
      path.join(external.path, 'firbird_test_model', 'candidates.json'),
    );
    if (!await file.exists()) return const <_NearbyBird>[];
    final Map<String, dynamic> json =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return (json['candidates'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_NearbyBird.fromJson)
        .toList(growable: false);
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
          _hasApproximateLocation = true;
          _selectedRegion = _regionFor(position);
          _locationMessage = _selectedRegion == null
              ? 'Yaklaşık konum bu oturum için kullanılıyor.'
              : 'Yaklaşık konuma göre $_selectedRegion seçildi.';
        });
      }
    } on _NearbyLocationException catch (error) {
      if (mounted) setState(() => _locationMessage = error.message);
    } catch (_) {
      if (mounted) setState(() => _locationMessage = 'Konum alınamadı.');
    } finally {
      if (mounted) setState(() => _locating = false);
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Yakınımdaki kuşlar'),
      leading: const BackToHomeButton(),
    ),
    body: FutureBuilder<List<_NearbyBird>>(
      future: _birds,
      builder: (BuildContext context, AsyncSnapshot<List<_NearbyBird>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<_NearbyBird> all = snapshot.data ?? const <_NearbyBird>[];
        final List<_NearbyBird> visible =
            all
                .where((_NearbyBird bird) => _includeRare || !bird.isRare)
                .toList()
              ..sort(
                (_NearbyBird a, _NearbyBird b) =>
                    a.turkishName.compareTo(b.turkishName),
              );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Text(
              'Bölgende görülebilecek kuşlar',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Bu ilk sürüm, kurulu Türkiye paketindeki düzenli ve göçmen türleri gösterir. İlçe/10 km düzeyindeki dağılım verisi Balkan paketiyle birlikte eklenecek.',
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
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Nadir kayıtları da göster'),
              subtitle: const Text(
                'Varsayılan olarak yalnızca düzenli/göçmen türler listelenir.',
              ),
              value: _includeRare,
              onChanged: (bool value) => setState(() => _includeRare = value),
            ),
            const Divider(),
            Text(
              '${visible.length} tür',
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
            else
              ...visible.map(
                (_NearbyBird bird) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.flutter_dash_outlined),
                    title: Text(bird.turkishName),
                    subtitle: Text(
                      '${bird.scientificName}\n${bird.isRare ? 'Türkiye · nadir kayıt' : 'Türkiye · düzenli / göçmen'}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push('/species/demo', extra: bird.prediction),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _NearbyLocationException implements Exception {
  const _NearbyLocationException(this.message);
  final String message;
}

class _NearbyBird {
  const _NearbyBird({
    required this.turkishName,
    required this.scientificName,
    required this.englishName,
    required this.isRare,
  });

  factory _NearbyBird.fromJson(Map<String, dynamic> json) => _NearbyBird(
    turkishName:
        json['turkishName'] as String? ?? json['scientificName'] as String,
    scientificName: json['scientificName'] as String,
    englishName: json['englishName'] as String? ?? '',
    isRare: json['occurrence'] == 'accidental',
  );

  final String turkishName;
  final String scientificName;
  final String englishName;
  final bool isRare;

  SpeciesPrediction get prediction => SpeciesPrediction(
    speciesId: scientificName.toLowerCase().replaceAll(' ', '-'),
    turkishName: turkishName,
    scientificName: scientificName,
    englishName: englishName,
    score: 0,
    originLabel: isRare
        ? 'Türkiye · nadir kayıt'
        : 'Türkiye · düzenli / göçmen',
  );
}
