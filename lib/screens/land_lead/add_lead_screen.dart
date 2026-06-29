import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../models/add_lead_result.dart';
import '../../models/land_lead.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_input.dart';
import '../../theme/fomra_theme_context.dart';
import '../../services/api_client.dart';
import '../../utils/image_compressor.dart';
import '../../utils/lead_location_parser.dart';
import '../../utils/tngis_parcel_lookup.dart';

enum _LocationMode { manual, live }

const _kMaxSitePhotos = 4;

const _kTermsOptions = [
  ('Outrate',          Icons.currency_rupee_outlined),
  ('Joint Venture',    Icons.handshake_outlined),
  ('Marketing',        Icons.campaign_outlined),
  ('Deferred Payment', Icons.schedule_outlined),
  ('Others',           Icons.more_horiz_outlined),
];

class AddLeadScreen extends StatefulWidget {
  const AddLeadScreen({super.key});

  @override
  State<AddLeadScreen> createState() => _AddLeadScreenState();
}

class _AddLeadScreenState extends State<AddLeadScreen> {
  final _formKey = GlobalKey<FormState>();

  // Section 1 — MCQ
  InputSource? _inputSource;

  // Section 2 — location fill-up
  final _locationCtrl   = TextEditingController();
  final _gpsCtrl        = TextEditingController();
  final _villageCtrl    = TextEditingController();
  final _talukCtrl      = TextEditingController();
  final _districtCtrl   = TextEditingController();
  final _surveyCtrl     = TextEditingController();
  final _subDivCtrl     = TextEditingController();
  final _extentCtrl     = TextEditingController();
  final _ownerCtrl      = TextEditingController();
  final _contactCtrl    = TextEditingController();
  final _pincodeCtrl    = TextEditingController();
  final _roadWidthCtrl  = TextEditingController();
  final _notesCtrl      = TextEditingController();
  LandType _landType = LandType.agricultural;

  _LocationMode _locationMode = _LocationMode.manual;
  bool _fetchingLocation = false;
  bool _resolvingPin = false;
  String? _locationStatus;
  LatLng? _pinnedPoint;
  final _mapController = MapController();
  bool _mapReady = false;

  static const _kDefaultMapCenter = LatLng(13.0827, 80.2707);
  static const _kOsmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Terms
  String? _termsType;

  // Photos (max 4)
  final List<_SitePhotoDraft> _photos = [];
  bool _compressingPhoto = false;

  @override
  void dispose() {
    for (final c in [
      _locationCtrl, _gpsCtrl, _villageCtrl, _talukCtrl, _districtCtrl,
      _pincodeCtrl, _surveyCtrl, _subDivCtrl, _extentCtrl, _ownerCtrl,
      _contactCtrl, _roadWidthCtrl, _notesCtrl,
    ]) {
      c.dispose();
    }
    _mapController.dispose();
    super.dispose();
  }

  // ── Location fill from coordinates ─────────────────────────────────────────

  Future<void> _fillFromCoordinates(
    double lat,
    double lng, {
    bool clearLoading = true,
  }) async {
    _gpsCtrl.text =
        '${lat.toStringAsFixed(6)}° N, ${lng.toStringAsFixed(6)}° E';

    if (!mounted) return;
    setState(() => _locationStatus = 'Fetching address…');

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lng&format=json&addressdetails=1',
      );
      final response = await http.get(uri, headers: {
        'Accept-Language': 'en',
        'User-Agent': 'FomraLS/1.0 (in.fomrahousing)',
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>? ?? {};

        final location = _first(addr, [
          'suburb', 'neighbourhood', 'quarter',
          'town', 'village', 'city', 'municipality',
        ]);
        if (location.isNotEmpty) _locationCtrl.text = location;

        final village = _first(addr, ['village', 'hamlet', 'suburb', 'neighbourhood']);
        if (village.isNotEmpty) _villageCtrl.text = village;

        final taluk = _first(addr, ['county', 'city_district', 'district']);
        if (taluk.isNotEmpty) _talukCtrl.text = taluk;

        final district = _first(addr, ['state_district', 'county']);
        if (district.isNotEmpty) _districtCtrl.text = district;

        final postcode = addr['postcode'] as String? ?? '';
        if (postcode.isNotEmpty) _pincodeCtrl.text = postcode;

        setState(() => _locationStatus = 'Location filled ✓');
      } else {
        setState(() => _locationStatus = 'Address lookup failed — GPS coordinates saved.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationStatus =
          'Error: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (clearLoading && mounted) {
        setState(() {
          _fetchingLocation = false;
          _resolvingPin = false;
        });
      }
    }
  }

  Future<void> _fillSurveyFromTngis(LatLng point) async {
    if (!mounted) return;
    setState(() => _locationStatus = 'Fetching survey from TNGIS…');

    try {
      final parcel = await fetchTngisParcelAt(point);
      if (!mounted) return;

      if (parcel.surveyNumber != null && parcel.surveyNumber!.isNotEmpty) {
        _surveyCtrl.text = parcel.surveyNumber!;
      }
      if (parcel.subDivision != null && parcel.subDivision!.isNotEmpty) {
        _subDivCtrl.text = parcel.subDivision!;
      }
      if (parcel.village != null && parcel.village!.isNotEmpty) {
        _villageCtrl.text = parcel.village!;
      }
      if (parcel.taluk != null && parcel.taluk!.isNotEmpty) {
        _talukCtrl.text = parcel.taluk!;
      }
      if (parcel.district != null && parcel.district!.isNotEmpty) {
        _districtCtrl.text = parcel.district!;
      }

      if (!mounted) return;
      setState(() => _locationStatus = parcel.hasSurvey
          ? 'Location & survey filled ✓'
          : 'Location filled — survey not found at this pin');
    } on ApiException catch (e) {
      if (!mounted) return;
      final hadLocation = _locationStatus?.contains('✓') == true;
      setState(() => _locationStatus = hadLocation
          ? 'Location filled — survey lookup failed (${e.message})'
          : 'Survey lookup failed: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationStatus =
          'Survey lookup error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  void _onLocationModeChanged(_LocationMode mode) {
    setState(() => _locationMode = mode);
    if (mode == _LocationMode.manual) {
      final parsed = parseLeadGps(_gpsCtrl.text) ?? _pinnedPoint;
      if (parsed != null) {
        _pinnedPoint = parsed;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _centerMapOn(parsed));
      }
    }
  }

  void _onMapReady() {
    setState(() => _mapReady = true);
    final parsed = _pinnedPoint ?? parseLeadGps(_gpsCtrl.text);
    if (parsed != null) {
      _pinnedPoint = parsed;
      _centerMapOn(parsed);
    }
  }

  void _centerMapOn(LatLng point) {
    if (!_mapReady) return;
    _mapController.move(point, _mapController.camera.zoom.clamp(12.0, 18.0));
  }

  Future<void> _onMapPin(LatLng point) async {
    setState(() {
      _pinnedPoint = point;
      _resolvingPin = true;
      _locationStatus = 'Pin placed — fetching land details…';
    });
    _centerMapOn(point);
    try {
      await _fillFromCoordinates(point.latitude, point.longitude, clearLoading: false);
      await _fillSurveyFromTngis(point);
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationStatus =
          'Error: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() {
          _resolvingPin = false;
          _fetchingLocation = false;
        });
      }
    }
  }

  Future<void> _centerMapOnMyLocation() async {
    setState(() {
      _fetchingLocation = true;
      _locationStatus = 'Getting your location…';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setStatus('Location services disabled. Enable GPS to center the map.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setStatus('Location permission denied.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final point = LatLng(position.latitude, position.longitude);
      await _onMapPin(point);
    } on LocationServiceDisabledException {
      _setStatus('Location services are disabled.');
    } catch (e) {
      _setStatus('Error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  // ── Live location ──────────────────────────────────────────────────────────

  Future<void> _fetchLiveLocation() async {
    setState(() {
      _fetchingLocation = true;
      _locationStatus = 'Requesting permission…';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setStatus('Location services disabled. Please enable GPS in device settings.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _setStatus('Location permission permanently denied. Enable it in App Settings.');
        return;
      }
      if (permission == LocationPermission.denied) {
        _setStatus('Location permission denied.');
        return;
      }

      setState(() => _locationStatus = 'Getting GPS coordinates…');

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final lat = position.latitude;
      final lng = position.longitude;
      await _fillFromCoordinates(lat, lng, clearLoading: false);
      await _fillSurveyFromTngis(LatLng(lat, lng));
    } on LocationServiceDisabledException {
      _setStatus('Location services are disabled. Enable them in browser settings.');
    } catch (e) {
      _setStatus('Error: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  void _setStatus(String msg) {
    if (!mounted) return;
    setState(() {
      _fetchingLocation = false;
      _resolvingPin = false;
      _locationStatus = msg;
    });
  }

  String _first(Map<String, dynamic> addr, List<String> keys) {
    for (final k in keys) {
      final v = addr[k];
      if (v != null && (v as String).isNotEmpty) return v;
    }
    return '';
  }

  // ── Photo picker ───────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    if (_photos.length >= _kMaxSitePhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum $_kMaxSitePhotos photos per lead'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _compressingPhoto = true);

    try {
      final compressed = await ImageCompressor.compressTo250Kb(file.bytes!);
      if (!mounted) return;
      setState(() {
        _photos.add(_SitePhotoDraft(
          bytes: compressed,
          name: file.name,
          originalSize: file.bytes!.length,
        ));
        _compressingPhoto = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _compressingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.error,
      ));
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  // ── Build terms details string ─────────────────────────────────────────────

  // ── Submit ─────────────────────────────────────────────────────────────────

  void _submit() {
    if (_inputSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an Input Source'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final combinedNotes = _notesCtrl.text.trim();

    final lead = LandLead(
      leadId: '',
      inputSource: _inputSource!,
      location: _locationCtrl.text.trim(),
      gpsCoordinates: _gpsCtrl.text.trim(),
      village: _villageCtrl.text.trim(),
      taluk: _talukCtrl.text.trim(),
      district: _districtCtrl.text.trim(),
      pincode: _pincodeCtrl.text.trim(),
      surveyNumber: _surveyCtrl.text.trim(),
      subDivision: _subDivCtrl.text.trim(),
      landExtent: _extentCtrl.text.trim(),
      ownerName: _ownerCtrl.text.trim(),
      contactDetails: _contactCtrl.text.trim(),
      landType: _landType,
      roadWidth: _roadWidthCtrl.text.trim(),
      accessDetails: _termsType ?? '',
      notes: combinedNotes,
      addedOn: DateTime.now(),
    );

    Navigator.pop(
      context,
      AddLeadResult(
        lead: lead,
        sitePhotoBytes: _photos.map((p) => p.bytes).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.fomraPageBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.heroGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('Add Land Lead',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TextButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save_outlined, size: 16, color: Colors.white),
              label: const Text('SAVE',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── Section 1: Input Source ──────────────────────────────
            const _SectionHeader(
              number: '1',
              title: 'Input Source',
              subtitle: 'Who brought this lead?',
            ),
            const SizedBox(height: 12),
            _InputSourceDropdown(
              value: _inputSource,
              onChanged: (s) => setState(() => _inputSource = s),
            ),
            if (_inputSource == null)
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: Text('* Required',
                    style: TextStyle(color: AppColors.error, fontSize: 12)),
              ),

            const SizedBox(height: 24),

            // ── Section 2: Data Captured ─────────────────────────────
            const _SectionHeader(
              number: '2',
              title: 'Data Captured',
              subtitle: 'Pre-survey land details',
            ),
            const SizedBox(height: 16),

            const _ReadOnlyField(
              label: 'Lead ID',
              value: 'Auto-generated (e.g. 06202600001)',
            ),
            const SizedBox(height: 16),

            _LocationModeToggle(
              mode: _locationMode,
              onChanged: _onLocationModeChanged,
            ),
            const SizedBox(height: 14),

            if (_locationMode == _LocationMode.manual) ...[
              _LocationPinMap(
                mapController: _mapController,
                tileUrl: _kOsmTileUrl,
                defaultCenter: _kDefaultMapCenter,
                pinnedPoint: _pinnedPoint,
                resolving: _resolvingPin,
                status: _locationStatus,
                fetchingMyLocation: _fetchingLocation,
                onMapReady: _onMapReady,
                onTap: _onMapPin,
                onMyLocation: _centerMapOnMyLocation,
              ),
              const SizedBox(height: 14),
            ],

            if (_locationMode == _LocationMode.live) ...[
              _LiveLocationButton(
                fetching: _fetchingLocation,
                status: _locationStatus,
                onTap: _fetchingLocation ? null : _fetchLiveLocation,
              ),
              const SizedBox(height: 14),
            ],

            _Field(
              ctrl: _gpsCtrl,
              label: 'GPS Coordinates',
              hint: _locationMode == _LocationMode.live
                  ? 'Auto-filled after capture'
                  : 'Pin on map or type manually',
              icon: Icons.gps_fixed,
            ),
            const SizedBox(height: 12),

            _Field(
              ctrl: _locationCtrl,
              label: 'Location',
              hint: _locationMode == _LocationMode.live
                  ? 'Auto-filled after capture'
                  : 'Pin on map or type manually',
              icon: Icons.location_on_outlined,
              required: true,
            ),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(
                  child: _Field(
                      ctrl: _villageCtrl,
                      label: 'Village',
                      hint: 'Village name',
                      icon: Icons.home_outlined)),
              const SizedBox(width: 10),
              Expanded(
                  child: _Field(
                      ctrl: _talukCtrl,
                      label: 'Taluk',
                      hint: 'Taluk',
                      icon: Icons.account_balance_outlined)),
            ]),
            const SizedBox(height: 12),

            _Field(
                ctrl: _districtCtrl,
                label: 'District',
                hint: 'e.g. Bangalore Rural',
                icon: Icons.map_outlined),
            const SizedBox(height: 12),

            _Field(
              ctrl: _pincodeCtrl,
              label: 'Pincode',
              hint: 'e.g. 560066',
              icon: Icons.local_post_office_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(
                child: _Field(
                  ctrl: _surveyCtrl,
                  label: 'Survey Number',
                  hint: 'e.g. 42/3A',
                  icon: Icons.tag,
                  required: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  ctrl: _subDivCtrl,
                  label: 'Sub Division',
                  hint: 'e.g. 1  (optional)',
                  icon: Icons.call_split_outlined,
                ),
              ),
            ]),
            const SizedBox(height: 12),

            _Field(
              ctrl: _extentCtrl,
              label: 'Land Extent',
              hint: 'e.g. 2.5 acres / 50 cents',
              icon: Icons.straighten,
              required: true,
            ),
            const SizedBox(height: 12),

            _Field(
              ctrl: _ownerCtrl,
              label: 'Owner Name',
              hint: 'Full name of the land owner',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 12),

            _Field(
              ctrl: _contactCtrl,
              label: 'Contact Details',
              hint: 'Phone / Email',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            _LandTypeDropdown(
              value: _landType,
              onChanged: (v) => setState(() => _landType = v!),
            ),
            const SizedBox(height: 12),

            _Field(
              ctrl: _roadWidthCtrl,
              label: 'Road Width',
              hint: 'e.g. 30 ft / 9 m',
              icon: Icons.open_in_full,
            ),
            const SizedBox(height: 20),

            // ── Section 3: Terms ─────────────────────────────────────
            const _SectionHeader(
              number: '3',
              title: 'Terms',
              subtitle: 'Select the deal terms',
            ),
            const SizedBox(height: 14),

            _TermsDropdown(
              value: _termsType,
              onChanged: (v) => setState(() => _termsType = v),
            ),
            const SizedBox(height: 12),


            _Field(
              ctrl: _notesCtrl,
              label: 'Notes',
              hint: 'Any additional observations',
              icon: Icons.notes_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // ── Section 4: Photo ─────────────────────────────────────
            const _SectionHeader(
              number: '4',
              title: 'Site Photos',
              subtitle: 'Upload up to 4 photos of the land',
            ),
            const SizedBox(height: 14),

            _MultiPhotoUpload(
              photos: _photos,
              maxPhotos: _kMaxSitePhotos,
              compressing: _compressingPhoto,
              onPick: _pickPhoto,
              onRemove: _removePhoto,
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppColors.coloredShadow(AppColors.primary),
                ),
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Lead',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Terms Dropdown ──────────────────────────────────────────────────────────

class _TermsDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _TermsDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      decoration: FomraInput.decoration(
        context: context,
        label: 'Terms',
        hint: 'Select deal terms',
        icon: Icons.handshake_outlined,
      ),
      items: _kTermsOptions
          .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$1)))
          .toList(),
    );
  }
}


// ── Site photo draft ─────────────────────────────────────────────────────────

class _SitePhotoDraft {
  final Uint8List bytes;
  final String name;
  final int originalSize;

  const _SitePhotoDraft({
    required this.bytes,
    required this.name,
    required this.originalSize,
  });
}

// ── Multi photo upload ───────────────────────────────────────────────────────

class _MultiPhotoUpload extends StatelessWidget {
  final List<_SitePhotoDraft> photos;
  final int maxPhotos;
  final bool compressing;
  final VoidCallback onPick;
  final ValueChanged<int> onRemove;

  const _MultiPhotoUpload({
    required this.photos,
    required this.maxPhotos,
    required this.compressing,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final canAdd = photos.length < maxPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.35,
            ),
            itemCount: photos.length,
            itemBuilder: (_, i) {
              final p = photos[i];
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      p.bytes,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => onRemove(i),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${i + 1}/$maxPhotos',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${photos.length} of $maxPhotos photos · max 250 KB each',
            style: TextStyle(fontSize: 11, color: context.fomraTextSecondary),
          ),
          const SizedBox(height: 10),
        ],
        if (compressing)
          Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: context.fomraSurface,
              borderRadius: BorderRadius.circular(FomraInput.borderRadius),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(height: 8),
                Text('Compressing photo to 250 KB…',
                    style: TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          )
        else if (canAdd)
          GestureDetector(
            onTap: onPick,
            child: Container(
              width: double.infinity,
              height: photos.isEmpty ? 140 : 100,
              decoration: BoxDecoration(
                color: context.fomraSurface,
                borderRadius: BorderRadius.circular(FomraInput.borderRadius),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_a_photo_outlined,
                        color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    photos.isEmpty
                        ? 'Tap to upload site photo'
                        : 'Add another photo',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'JPG, PNG · up to $maxPhotos photos',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Map pin picker (manual mode) ─────────────────────────────────────────────

class _LocationPinMap extends StatelessWidget {
  final MapController mapController;
  final String tileUrl;
  final LatLng defaultCenter;
  final LatLng? pinnedPoint;
  final bool resolving;
  final bool fetchingMyLocation;
  final String? status;
  final VoidCallback onMapReady;
  final Future<void> Function(LatLng) onTap;
  final Future<void> Function() onMyLocation;

  const _LocationPinMap({
    required this.mapController,
    required this.tileUrl,
    required this.defaultCenter,
    required this.pinnedPoint,
    required this.resolving,
    required this.fetchingMyLocation,
    required this.status,
    required this.onMapReady,
    required this.onTap,
    required this.onMyLocation,
  });

  @override
  Widget build(BuildContext context) {
    final filled = status != null && status!.contains('✓');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.map_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Pin location on map',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: fetchingMyLocation || resolving ? null : onMyLocation,
            icon: fetchingMyLocation
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, size: 16),
            label: const Text('My location', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 240,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: pinnedPoint ?? defaultCenter,
                    initialZoom: pinnedPoint != null ? 16 : 11,
                    onMapReady: onMapReady,
                    onTap: (_, point) => onTap(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: tileUrl,
                      userAgentPackageName: 'in.fomrahousing.fomrals',
                    ),
                    if (pinnedPoint != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: pinnedPoint!,
                          width: 40,
                          height: 48,
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFFE53935),
                            size: 40,
                          ),
                        ),
                      ]),
                  ],
                ),
                if (pinnedPoint == null && !resolving)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.fomraSurface.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app_outlined,
                              size: 16, color: AppColors.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tap the map to drop a pin — GPS, address & survey fill automatically',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (resolving)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (status != null) ...[
          const SizedBox(height: 8),
          Text(
            status!,
            style: TextStyle(
              fontSize: 11,
              color: filled ? AppColors.success : AppColors.textSecondary,
              fontWeight: filled ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Location Mode Toggle ────────────────────────────────────────────────────

class _LocationModeToggle extends StatelessWidget {
  final _LocationMode mode;
  final ValueChanged<_LocationMode> onChanged;
  const _LocationModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.fomraSurfaceVar,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        _Tab(
          icon: Icons.edit_outlined,
          label: 'Fill Manually',
          active: mode == _LocationMode.manual,
          onTap: () => onChanged(_LocationMode.manual),
        ),
        _Tab(
          icon: Icons.my_location,
          label: 'Live Location',
          active: mode == _LocationMode.live,
          onTap: () => onChanged(_LocationMode.live),
        ),
      ]),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: active ? Colors.white : context.fomraTextSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.normal,
                      color: active
                          ? Colors.white
                          : context.fomraTextSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Live Location Button ────────────────────────────────────────────────────

class _LiveLocationButton extends StatelessWidget {
  final bool fetching;
  final String? status;
  final VoidCallback? onTap;

  const _LiveLocationButton({
    required this.fetching,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool filled = status != null && status!.contains('✓');

    return Material(
      color: filled
          ? AppColors.success.withValues(alpha: 0.08)
          : AppColors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: filled
                  ? AppColors.success.withValues(alpha: 0.4)
                  : AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: filled ? AppColors.success : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: fetching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Icon(
                      filled ? Icons.location_on : Icons.my_location,
                      color: Colors.white,
                      size: 18,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fetching
                        ? 'Getting live location…'
                        : 'Get Live Location',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          filled ? AppColors.success : AppColors.primary,
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 2),
                    Text(status!,
                        style: TextStyle(
                            fontSize: 11,
                            color: filled
                                ? AppColors.success
                                : AppColors.textSecondary)),
                  ] else
                    const Text(
                      'Auto-fills GPS, location, village, taluk, district & survey',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            if (!fetching)
              Icon(
                filled ? Icons.check_circle : Icons.chevron_right,
                color: filled
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
          ]),
        ),
      ),
    );
  }
}

// ── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.fomraSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.fomraBorder),
        boxShadow: context.fomraCardShadow,
      ),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(number,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.fomraTextPrimary)),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12, color: context.fomraTextSecondary)),
          ]),
        ),
      ]),
    );
  }
}

// ── Input Source Dropdown ───────────────────────────────────────────────────

class _InputSourceDropdown extends StatelessWidget {
  final InputSource? value;
  final ValueChanged<InputSource?> onChanged;

  const _InputSourceDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<InputSource>(
      initialValue: value,
      onChanged: onChanged,
      decoration: FomraInput.decoration(
        context: context,
        label: 'Input Source',
        hint: 'Select who brought this lead',
        icon: Icons.source_outlined,
        required: true,
      ),
      items: InputSource.values
          .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
          .toList(),
    );
  }
}

// ── Read-only field ─────────────────────────────────────────────────────────

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.fomraSurfaceVar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.fomraBorder),
      ),
      child: Row(children: [
        const Icon(Icons.tag, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic)),
        ]),
      ]),
    );
  }
}

// ── Text field ──────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final bool required;
  final int maxLines;
  final TextInputType keyboardType;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: required
          ? (v) =>
              (v == null || v.trim().isEmpty) ? '$label is required' : null
          : null,
      decoration: FomraInput.decoration(
        context: context,
        label: label,
        hint: hint,
        icon: icon,
        required: required,
      ),
    );
  }
}

// ── Land Type Dropdown ──────────────────────────────────────────────────────

class _LandTypeDropdown extends StatelessWidget {
  final LandType value;
  final ValueChanged<LandType?> onChanged;

  const _LandTypeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<LandType>(
      initialValue: value,
      onChanged: onChanged,
      decoration: FomraInput.decoration(
        context: context,
        label: 'Land Type',
        icon: Icons.terrain_outlined,
        required: true,
      ),
      items: LandType.values
          .map((t) =>
              DropdownMenuItem(value: t, child: Text(t.label)))
          .toList(),
    );
  }
}
