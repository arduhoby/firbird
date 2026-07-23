// ignore_for_file: deprecated_member_use

import 'package:firbird/l10n/app_localizations.dart';
import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:firbird/app/back_to_home_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

class PhotoContextHints {
  const PhotoContextHints({
    required this.exifDate,
    required this.hasExifLocation,
    required this.imagePath,
  });

  final DateTime? exifDate;
  final bool hasExifLocation;
  final String imagePath;
}

class ObservationContextScreen extends StatefulWidget {
  const ObservationContextScreen({this.hints, super.key});

  final PhotoContextHints? hints;

  @override
  State<ObservationContextScreen> createState() =>
      _ObservationContextScreenState();
}

class _ObservationContextScreenState extends State<ObservationContextScreen> {
  static const LatLng _turkiyeCenter = LatLng(39.0, 35.0);

  LocationChoice _locationChoice = LocationChoice.unknown;
  DateChoice _dateChoice = DateChoice.unknown;
  LatLng? _selectedPoint;
  String? _selectedRegion;
  DateTime? _selectedDate;
  bool _isLocating = false;
  bool _onlineMapEnabled = false;
  String? _locationError;

  Future<void> _requestOnlineMap() async {
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
    if (!mounted) return;
    setState(() {
      _onlineMapEnabled = accepted == true;
      _locationChoice = accepted == true ? LocationChoice.map : LocationChoice.region;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationException('servicesDisabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const _LocationException('permissionDenied');
      }

      final Position position = await Geolocator.getCurrentPosition();
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedPoint = LatLng(position.latitude, position.longitude);
        _selectedRegion = null;
        _locationChoice = LocationChoice.current;
      });
    } on _LocationException catch (error) {
      if (mounted) {
        setState(() => _locationError = error.code);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _locationError = 'unavailable');
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime today = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: DateTime(1900),
      lastDate: today,
    );
    if (date == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = date;
      _dateChoice = DateChoice.manual;
    });
  }

  void _selectMapPoint(LatLng point) {
    setState(() {
      _selectedPoint = point;
      _selectedRegion = null;
      _locationChoice = LocationChoice.map;
      _locationError = null;
    });
  }

  void _selectRegion(String? region) {
    setState(() {
      _selectedRegion = region;
      _selectedPoint = null;
      _locationChoice = region == null
          ? LocationChoice.unknown
          : LocationChoice.region;
    });
  }

  void _selectExifLocation() {
    setState(() {
      _selectedPoint = null;
      _selectedRegion = null;
      _locationChoice = LocationChoice.exif;
    });
  }

  void _selectExifDate() {
    setState(() {
      _selectedDate = widget.hints!.exifDate;
      _dateChoice = DateChoice.exif;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.setLocationAndDate),
        leading: const BackToHomeButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(l10n.location, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l10n.locationDescription),
          RadioListTile<LocationChoice>(
            contentPadding: EdgeInsets.zero,
            value: LocationChoice.exif,
            groupValue: _locationChoice,
            title: Text(l10n.useExifLocation),
            subtitle: Text(
              widget.hints?.hasExifLocation == true
                  ? l10n.exifLocationAvailable
                  : l10n.exifLocationUnavailable,
            ),
            onChanged: widget.hints?.hasExifLocation == true
                ? (LocationChoice? _) => _selectExifLocation()
                : null,
          ),
          RadioListTile<LocationChoice>(
            contentPadding: EdgeInsets.zero,
            value: LocationChoice.map,
            groupValue: _locationChoice,
            title: Text(l10n.selectOnMap),
            onChanged: (LocationChoice? _) => _requestOnlineMap(),
          ),
          if (_locationChoice == LocationChoice.map && _onlineMapEnabled)
            _MapPicker(onSelect: _selectMapPoint),
          RadioListTile<LocationChoice>(
            contentPadding: EdgeInsets.zero,
            value: LocationChoice.current,
            groupValue: _locationChoice,
            title: Text(l10n.useCurrentLocation),
            onChanged: _isLocating
                ? null
                : (LocationChoice? _) => _useCurrentLocation(),
          ),
          if (_isLocating) const LinearProgressIndicator(),
          RadioListTile<LocationChoice>(
            contentPadding: EdgeInsets.zero,
            value: LocationChoice.region,
            groupValue: _locationChoice,
            title: Text(l10n.selectFromRegionList),
            onChanged: (LocationChoice? _) =>
                setState(() => _locationChoice = LocationChoice.region),
          ),
          if (_locationChoice == LocationChoice.region)
            DropdownButtonFormField<String>(
              value: _selectedRegion,
              decoration: InputDecoration(labelText: l10n.region),
              items: _turkiyeRegions
                  .map(
                    (String region) => DropdownMenuItem<String>(
                      value: region,
                      child: Text(region),
                    ),
                  )
                  .toList(),
              onChanged: _selectRegion,
            ),
          RadioListTile<LocationChoice>(
            contentPadding: EdgeInsets.zero,
            value: LocationChoice.unknown,
            groupValue: _locationChoice,
            title: Text(l10n.locationUnknown),
            onChanged: (LocationChoice? _) => _selectRegion(null),
          ),
          if (_locationError != null) _LocationError(code: _locationError!),
          const SizedBox(height: 24),
          Text(l10n.date, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          RadioListTile<DateChoice>(
            contentPadding: EdgeInsets.zero,
            value: DateChoice.exif,
            groupValue: _dateChoice,
            title: Text(l10n.useExifDate),
            subtitle: Text(
              widget.hints?.exifDate == null
                  ? l10n.exifDateUnavailable
                  : _formatDate(widget.hints!.exifDate!),
            ),
            onChanged: widget.hints?.exifDate == null
                ? null
                : (DateChoice? _) => _selectExifDate(),
          ),
          RadioListTile<DateChoice>(
            contentPadding: EdgeInsets.zero,
            value: DateChoice.manual,
            groupValue: _dateChoice,
            title: Text(l10n.selectDate),
            subtitle: _selectedDate == null
                ? null
                : Text(_formatDate(_selectedDate!)),
            onChanged: (DateChoice? _) => _pickDate(),
          ),
          RadioListTile<DateChoice>(
            contentPadding: EdgeInsets.zero,
            value: DateChoice.today,
            groupValue: _dateChoice,
            title: Text(l10n.useToday),
            onChanged: (DateChoice? _) => setState(() {
              _selectedDate = DateTime.now();
              _dateChoice = DateChoice.today;
            }),
          ),
          RadioListTile<DateChoice>(
            contentPadding: EdgeInsets.zero,
            value: DateChoice.unknown,
            groupValue: _dateChoice,
            title: Text(l10n.dateUnknown),
            onChanged: (DateChoice? _) => setState(() {
              _selectedDate = null;
              _dateChoice = DateChoice.unknown;
            }),
          ),
          const SizedBox(height: 24),
          _ContextSummary(
            locationChoice: _locationChoice,
            dateChoice: _dateChoice,
            selectedPoint: _selectedPoint,
            selectedRegion: _selectedRegion,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go(
              '/analysis',
              extra: IdentificationRequest(
                image: ImageInput(uri: widget.hints!.imagePath),
                context: IdentificationContext(
                  countryCode: _locationChoice == LocationChoice.unknown
                      ? null
                      : 'TR',
                  observationDate: _selectedDate,
                ),
              ),
            ),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(l10n.identify),
          ),
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

class _MapPicker extends StatelessWidget {
  const _MapPicker({required this.onSelect});

  final ValueChanged<LatLng> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: _ObservationContextScreenState._turkiyeCenter,
            initialZoom: 5.5,
            onTap: (TapPosition _, LatLng point) => onSelect(point),
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'org.firbird3.app',
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationError extends StatelessWidget {
  const _LocationError({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String message = switch (code) {
      'servicesDisabled' => l10n.locationServicesDisabled,
      'permissionDenied' => l10n.locationPermissionDenied,
      _ => l10n.locationUnavailable,
    };

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.location_off_outlined, size: 20, color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onErrorContainer)),
                if (code == 'permissionDenied')
                  TextButton.icon(
                    onPressed: Geolocator.openAppSettings,
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('Ayarları aç'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                      padding: const EdgeInsets.only(top: 6),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextSummary extends StatelessWidget {
  const _ContextSummary({
    required this.locationChoice,
    required this.dateChoice,
    required this.selectedPoint,
    required this.selectedRegion,
  });

  final LocationChoice locationChoice;
  final DateChoice dateChoice;
  final LatLng? selectedPoint;
  final String? selectedRegion;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String location = switch (locationChoice) {
      LocationChoice.map || LocationChoice.current =>
        selectedPoint == null
            ? l10n.locationUnknown
            : l10n.approximateGridSelected,
      LocationChoice.region => selectedRegion ?? l10n.locationUnknown,
      LocationChoice.exif => l10n.useExifLocation,
      LocationChoice.unknown => l10n.locationUnknown,
    };
    final String date = switch (dateChoice) {
      DateChoice.exif => l10n.useExifDate,
      DateChoice.manual => l10n.selectDate,
      DateChoice.today => l10n.useToday,
      DateChoice.unknown => l10n.dateUnknown,
    };

    return Card(
      child: ListTile(
        leading: const Icon(Icons.privacy_tip_outlined),
        title: Text(l10n.contextSummary),
        subtitle: Text(<String>[location, date].join(' • ')),
      ),
    );
  }
}

class _LocationException implements Exception {
  const _LocationException(this.code);

  final String code;
}

enum LocationChoice { exif, map, current, region, unknown }

enum DateChoice { exif, manual, today, unknown }

const List<String> _turkiyeRegions = <String>[
  'Marmara',
  'Ege',
  'Akdeniz',
  'İç Anadolu',
  'Karadeniz',
  'Doğu Anadolu',
  'Güneydoğu Anadolu',
];
