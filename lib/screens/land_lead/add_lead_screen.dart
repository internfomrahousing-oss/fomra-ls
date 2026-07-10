import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../models/add_lead_result.dart';
import '../../models/land_lead.dart';
import '../../theme/app_theme.dart';
import '../../config/maptiler_tiles.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/add_lead_ui.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/portal_page_layout.dart';
import '../../services/api_client.dart';
import '../../utils/image_compressor.dart';
import '../../utils/lead_location_parser.dart';
import '../../utils/tngis_parcel_lookup.dart';

enum _LocationMode { manual, live }

const _kMaxSitePhotos = 4;

const _kTermsOptions = [
  ('Outrate',          Icons.currency_rupee_rounded),
  ('Joint Venture',    Icons.handshake_rounded),
  ('Marketing',        Icons.campaign_rounded),
  ('Deferred Payment', Icons.schedule_rounded),
  ('Others',           Icons.more_horiz_rounded),
];

class AddLeadScreen extends StatefulWidget {
  final LandLead? existingLead;

  const AddLeadScreen({super.key, this.existingLead});

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
  Timer? _gpsDebounce;
  bool _suppressGpsListener = false;

  static const _kDefaultMapCenter = LatLng(13.0827, 80.2707);
  static final _kMapTileUrl = MapTilerTiles.standard;

  // Terms
  String? _termsType;

  // Photos (max 4)
  final List<AddLeadPhotoDraft> _photos = [];
  List<String> _keptPhotoUrls = [];
  bool _compressingPhoto = false;

  final _scrollController = ScrollController();
  final _sectionKeys = List.generate(4, (_) => GlobalKey());
  int _activeSection = 0;

  bool get _isEdit => widget.existingLead != null;

  static const _kProgressLabels = [
    'Input Source',
    'Data Captured',
    'Terms',
    'Site Photos',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _gpsCtrl.addListener(_onGpsTextChanged);
    final existing = widget.existingLead;
    if (existing == null) return;

    _inputSource = existing.inputSource;
    _locationCtrl.text = existing.location;
    _gpsCtrl.text = existing.gpsCoordinates;
    _villageCtrl.text = existing.village;
    _talukCtrl.text = existing.taluk;
    _districtCtrl.text = existing.district;
    _pincodeCtrl.text = existing.pincode;
    _surveyCtrl.text = existing.surveyNumber;
    _subDivCtrl.text = existing.subDivision;
    _extentCtrl.text = existing.landExtent;
    _ownerCtrl.text = existing.ownerName;
    _contactCtrl.text = existing.contactDetails;
    _roadWidthCtrl.text = existing.roadWidth;
    _notesCtrl.text = existing.notes;
    _landType = existing.landType;
    if (existing.accessDetails.isNotEmpty) {
      _termsType = existing.accessDetails;
    }
    _pinnedPoint = parseLeadGps(existing.gpsCoordinates);
    _keptPhotoUrls = List<String>.from(existing.sitePhotoUrls);
    if (_keptPhotoUrls.isEmpty && existing.sitePhotoUrl.isNotEmpty) {
      _keptPhotoUrls = [existing.sitePhotoUrl];
    }
  }

  @override
  void dispose() {
    _gpsDebounce?.cancel();
    _gpsCtrl.removeListener(_onGpsTextChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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

  void _onGpsTextChanged() {
    if (_suppressGpsListener) return;
    _gpsDebounce?.cancel();
    _gpsDebounce = Timer(const Duration(milliseconds: 650), _applyGpsFromText);
  }

  Future<void> _applyGpsFromText() async {
    if (!mounted) return;
    final parsed = parseLeadGps(_gpsCtrl.text);
    if (parsed == null) return;

    if (_pinnedPoint != null &&
        (_pinnedPoint!.latitude - parsed.latitude).abs() < 1e-5 &&
        (_pinnedPoint!.longitude - parsed.longitude).abs() < 1e-5) {
      return;
    }

    if (_locationMode == _LocationMode.live) {
      setState(() => _locationMode = _LocationMode.manual);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onMapPin(parsed);
      });
      return;
    }

    await _onMapPin(parsed);
  }

  Future<void> _fillFromCoordinates(
    double lat,
    double lng, {
    bool clearLoading = true,
  }) async {
    _suppressGpsListener = true;
    _gpsCtrl.text =
        '${lat.toStringAsFixed(6)}° N, ${lng.toStringAsFixed(6)}° E';
    _suppressGpsListener = false;

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
      // Drop the point on the map (switch to manual mode) so survey/sub-division
      // can be verified and the pin nudged onto the exact parcel if the GPS
      // reading is slightly off the land.
      if (mounted) {
        setState(() {
          _pinnedPoint = LatLng(lat, lng);
          _locationMode = _LocationMode.manual;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final p = _pinnedPoint;
          if (p != null) _centerMapOn(p);
        });
      }
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
    if (_keptPhotoUrls.length + _photos.length >= _kMaxSitePhotos) {
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
        _photos.add(AddLeadPhotoDraft(
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

  void _removeExistingPhoto(int index) {
    setState(() => _keptPhotoUrls.removeAt(index));
  }

  void _onScroll() {
    var best = _activeSection;
    var bestScore = double.infinity;
    for (var i = 0; i < _sectionKeys.length; i++) {
      final ctx = _sectionKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      final score = (top - 148).abs();
      if (top < 220 && score < bestScore) {
        bestScore = score;
        best = i;
      }
    }
    if (best != _activeSection) setState(() => _activeSection = best);
  }

  void _scrollToSection(int index) {
    final ctx = _sectionKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: AddLeadUi.motion,
        curve: AddLeadUi.curve,
        alignment: 0.06,
      );
    }
    setState(() => _activeSection = index);
  }

  bool _sectionCompleted(int index) {
    switch (index) {
      case 0:
        return _inputSource != null;
      case 1:
        return _locationCtrl.text.trim().isNotEmpty &&
            _surveyCtrl.text.trim().isNotEmpty &&
            _extentCtrl.text.trim().isNotEmpty;
      case 2:
        return (_termsType ?? '').isNotEmpty ||
            _notesCtrl.text.trim().isNotEmpty;
      case 3:
        return _photos.isNotEmpty || _keptPhotoUrls.isNotEmpty;
      default:
        return false;
    }
  }

  Widget _sectionAnchor(int index, Widget child) {
    return KeyedSubtree(key: _sectionKeys[index], child: child);
  }

  Widget _buildSitePhotosSection(String number) {
    return AddLeadSectionCard(
      number: number,
      title: 'Site Photos',
      subtitle: _isEdit
          ? 'Remove existing photos or upload new ones (max 4)'
          : 'Upload up to 4 photos of the land',
      icon: Icons.photo_library_outlined,
      child: AddLeadPhotoUpload(
        existingPhotoUrls: _keptPhotoUrls,
        photos: _photos,
        maxPhotos: _kMaxSitePhotos,
        compressing: _compressingPhoto,
        onPick: _pickPhoto,
        onRemove: _removePhoto,
        onRemoveExisting: _isEdit ? _removeExistingPhoto : null,
      ),
    );
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

    final existing = widget.existingLead;
    final lead = LandLead(
      leadId: existing?.leadId ?? '',
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
      addedOn: existing?.addedOn ?? DateTime.now(),
      createdByName: existing?.createdByName ?? '',
      createdByRole: existing?.createdByRole ?? '',
      status: existing?.status ?? LeadStatus.new_,
      sitePhotoUrl: _keptPhotoUrls.isNotEmpty ? _keptPhotoUrls.first : '',
      sitePhotoUrls: List<String>.from(_keptPhotoUrls),
    );

    Navigator.pop(
      context,
      AddLeadResult(
        lead: lead,
        sitePhotoBytes: _photos.map((p) => p.bytes).toList(),
        isEdit: _isEdit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progressSteps = [
      for (var i = 0; i < _kProgressLabels.length; i++)
        AddLeadProgressStep(
          label: _kProgressLabels[i],
          completed: _sectionCompleted(i),
          active: _activeSection == i,
        ),
    ];

    return Scaffold(
      backgroundColor: AddLeadUi.pageBg,
      appBar: AddLeadAppBar(
        title: _isEdit ? 'Edit Land Lead' : 'Add Land Lead',
        onSave: _submit,
      ),
      bottomNavigationBar: AddLeadStickyFooter(
        onCancel: () => Navigator.pop(context),
        onSave: _submit,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FomraBreadcrumbStrip(
            items: FomraBreadcrumbs.fromWorkspace(
              _isEdit ? 'Edit Land Lead' : 'Add Land Lead',
            ),
          ),
          AddLeadProgressNav(
            steps: progressSteps,
            onStepTap: _scrollToSection,
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                24 + MediaQuery.paddingOf(context).bottom + 72,
              ),
              child: portalPageWidthConstraint(
                context,
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionAnchor(
                        0,
                        AddLeadSectionCard(
                          number: '1',
                          title: 'Input Source',
                          subtitle: 'Who brought this lead?',
                          icon: Icons.source_outlined,
                          compact: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _InputSourceDropdown(
                                value: _inputSource,
                                onChanged: (s) =>
                                    setState(() => _inputSource = s),
                              ),
                              if (_inputSource == null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6, left: 4),
                                  child: Text(
                                    '* Required',
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AddLeadUi.sectionGap),
                      _sectionAnchor(
                        1,
                        AddLeadSectionCard(
                          number: '2',
                          title: 'Data Captured',
                          subtitle: 'Pre-survey land details',
                          icon: Icons.map_outlined,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _ReadOnlyField(
                                label: 'Lead ID',
                                value: 'Auto-generated (1, 2, 3 …)',
                              ),
                              const SizedBox(height: AddLeadUi.fieldGap),
                              AddLeadLocationSegment(
                                mode: _locationMode == _LocationMode.manual
                                    ? AddLeadLocationMode.manual
                                    : AddLeadLocationMode.live,
                                onChanged: (m) => _onLocationModeChanged(
                                  m == AddLeadLocationMode.manual
                                      ? _LocationMode.manual
                                      : _LocationMode.live,
                                ),
                              ),
                              const SizedBox(height: AddLeadUi.fieldGap),
                              if (_locationMode == _LocationMode.manual) ...[
                                AddLeadMapPicker(
                                  mapController: _mapController,
                                  tileUrl: _kMapTileUrl,
                                  defaultCenter: _kDefaultMapCenter,
                                  pinnedPoint: _pinnedPoint,
                                  resolving: _resolvingPin,
                                  status: _locationStatus,
                                  fetchingMyLocation: _fetchingLocation,
                                  onMapReady: _onMapReady,
                                  onTap: _onMapPin,
                                  onMyLocation: _centerMapOnMyLocation,
                                ),
                                if (_locationStatus != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _locationStatus!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _locationStatus!.contains('✓')
                                          ? AppColors.success
                                          : context.fomraTextSecondary,
                                      fontWeight: _locationStatus!.contains('✓')
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: AddLeadUi.fieldGap),
                              ],
                              if (_locationMode == _LocationMode.live) ...[
                                AddLeadLiveLocationCard(
                                  fetching: _fetchingLocation,
                                  status: _locationStatus,
                                  onTap: _fetchingLocation
                                      ? null
                                      : _fetchLiveLocation,
                                ),
                                if (_locationStatus != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _locationStatus!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _locationStatus!.contains('✓')
                                          ? AppColors.success
                                          : context.fomraTextSecondary,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: AddLeadUi.fieldGap),
                              ],
                              _Field(
                                ctrl: _gpsCtrl,
                                label: 'GPS Coordinates',
                                hint: _locationMode == _LocationMode.live
                                    ? 'Auto-filled after capture'
                                    : 'Pin on map or type manually',
                                icon: Icons.gps_fixed_rounded,
                                onFieldSubmitted: (_) {
                                  _gpsDebounce?.cancel();
                                  _applyGpsFromText();
                                },
                              ),
                              const SizedBox(height: AddLeadUi.fieldGap),
                              _Field(
                                ctrl: _locationCtrl,
                                label: 'Location',
                                hint: _locationMode == _LocationMode.live
                                    ? 'Auto-filled after capture'
                                    : 'Pin on map or type manually',
                                icon: Icons.location_on_outlined,
                                required: true,
                              ),
                              const SizedBox(height: AddLeadUi.fieldGap),
                              addLeadFormRow(
                                context,
                                _Field(
                                  ctrl: _villageCtrl,
                                  label: 'Village',
                                  hint: 'Village name',
                                  icon: Icons.home_outlined,
                                ),
                                _Field(
                                  ctrl: _talukCtrl,
                                  label: 'Taluk',
                                  hint: 'Taluk',
                                  icon: Icons.account_balance_outlined,
                                ),
                              ),
                              const SizedBox(height: AddLeadUi.fieldGap),
                              addLeadFormRow(
                                context,
                                _Field(
                                  ctrl: _districtCtrl,
                                  label: 'District',
                                  hint: 'e.g. Bangalore Rural',
                                  icon: Icons.map_outlined,
                                ),
                                _Field(
                                  ctrl: _pincodeCtrl,
                                  label: 'Pincode',
                                  hint: 'e.g. 560066',
                                  icon: Icons.local_post_office_outlined,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(height: AddLeadUi.fieldGap),
                              addLeadFormRow(
                                context,
                                _Field(
                                  ctrl: _surveyCtrl,
                                  label: 'Survey Number',
                                  hint: 'e.g. 42/3A',
                                  icon: Icons.tag_outlined,
                                  required: true,
                                ),
                                _Field(
                                  ctrl: _subDivCtrl,
                                  label: 'Sub Division',
                                  hint: 'e.g. 1  (optional)',
                                  icon: Icons.call_split_outlined,
                                ),
                              ),
                              const SizedBox(height: AddLeadUi.fieldGap),
                              addLeadFormRow(
                                context,
                                _Field(
                                  ctrl: _extentCtrl,
                                  label: 'Land Extent',
                                  hint: 'e.g. 2.5 acres / 50 cents',
                                  icon: Icons.straighten_rounded,
                                  required: true,
                                ),
                                _Field(
                                  ctrl: _ownerCtrl,
                                  label: 'Owner Name',
                                  hint: 'Full name of the land owner',
                                  icon: Icons.person_outline_rounded,
                                ),
                              ),
                              const SizedBox(height: AddLeadUi.fieldGap),
                              addLeadFormRow(
                                context,
                                _Field(
                                  ctrl: _contactCtrl,
                                  label: 'Contact Details',
                                  hint: 'Phone / Email',
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                ),
                                _LandTypeDropdown(
                                  value: _landType,
                                  onChanged: (v) =>
                                      setState(() => _landType = v!),
                                ),
                              ),
                              const SizedBox(height: AddLeadUi.fieldGap),
                              _Field(
                                ctrl: _roadWidthCtrl,
                                label: 'Road Width',
                                hint: 'e.g. 30 ft / 9 m',
                                icon: Icons.open_in_full_rounded,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AddLeadUi.sectionGap),
                      _sectionAnchor(
                        2,
                        AddLeadSectionCard(
                          number: '3',
                          title: 'Terms',
                          subtitle: 'Select the deal terms',
                          icon: Icons.handshake_outlined,
                          compact: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _TermsDropdown(
                                value: _termsType,
                                onChanged: (v) =>
                                    setState(() => _termsType = v),
                              ),
                              const SizedBox(height: AddLeadUi.fieldGap),
                              _Field(
                                ctrl: _notesCtrl,
                                label: 'Notes',
                                hint: 'Any additional observations',
                                icon: Icons.notes_outlined,
                                maxLines: 3,
                                light: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AddLeadUi.sectionGap),
                      _sectionAnchor(
                        3,
                        _buildSitePhotosSection('4'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Form widgets ────────────────────────────────────────────────────────────

IconData _inputSourceIcon(InputSource source) => switch (source) {
      InputSource.broker => Icons.handshake_outlined,
      InputSource.landowner => Icons.person_pin_outlined,
      InputSource.referral => Icons.group_outlined,
      InputSource.internalTeam => Icons.business_center_outlined,
      InputSource.existingDatabase => Icons.storage_outlined,
    };

IconData _landTypeIcon(LandType type) => switch (type) {
      LandType.agricultural => Icons.agriculture_outlined,
      LandType.nonAgricultural => Icons.landscape_outlined,
      LandType.residential => Icons.home_outlined,
      LandType.commercial => Icons.storefront_outlined,
      LandType.industrial => Icons.factory_outlined,
      LandType.other => Icons.category_outlined,
    };

class _TermsDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _TermsDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.primaryLight
        : AppColors.primary;

    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      onChanged: onChanged,
      menuMaxHeight: 260,
      borderRadius: BorderRadius.circular(AddLeadUi.fieldRadius),
      decoration: addLeadInputDecoration(
        context,
        label: 'Terms',
        hint: 'Select deal terms',
        icon: Icons.handshake_outlined,
      ),
      items: _kTermsOptions
          .map(
            (t) => DropdownMenuItem(
              value: t.$1,
              child: addLeadDropdownRow(
                icon: t.$2,
                label: t.$1,
                iconColor: iconColor,
              ),
            ),
          )
          .toList(),
      selectedItemBuilder: (ctx) => _kTermsOptions
          .map(
            (t) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t.$1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          )
          .toList(),
    );
  }
}


class _InputSourceDropdown extends StatelessWidget {
  final InputSource? value;
  final ValueChanged<InputSource?> onChanged;

  const _InputSourceDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.primaryLight
        : AppColors.primary;

    return DropdownButtonFormField<InputSource>(
      isExpanded: true,
      initialValue: value,
      onChanged: onChanged,
      menuMaxHeight: 260,
      borderRadius: BorderRadius.circular(AddLeadUi.fieldRadius),
      decoration: addLeadInputDecoration(
        context,
        label: 'Input Source',
        hint: 'Select who brought this lead',
        icon: Icons.source_outlined,
        required: true,
      ),
      items: InputSource.values
          .map(
            (s) => DropdownMenuItem(
              value: s,
              child: addLeadDropdownRow(
                icon: _inputSourceIcon(s),
                label: s.label,
                iconColor: iconColor,
              ),
            ),
          )
          .toList(),
      selectedItemBuilder: (ctx) => InputSource.values
          .map(
            (s) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                s.label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          )
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
      height: AddLeadUi.fieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AddLeadUi.fieldRadius),
        border: Border.all(color: AddLeadUi.cardBorder),
      ),
      child: Row(
        children: [
          addLeadFieldIcon(Icons.tag_outlined, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.fomraTextSecondary,
                    fontStyle: FontStyle.italic,
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

// ── Text field ──────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final bool required;
  final int maxLines;
  final TextInputType keyboardType;
  final bool light;
  final ValueChanged<String>? onFieldSubmitted;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.light = false,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = addLeadInputDecoration(
      context,
      label: label,
      hint: hint,
      icon: icon,
      required: required,
      maxLines: maxLines,
    );

    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onFieldSubmitted: onFieldSubmitted,
      style: TextStyle(
        fontSize: 14,
        color: context.fomraTextPrimary,
        fontWeight: light ? FontWeight.w400 : FontWeight.w500,
      ),
      validator: required
          ? (v) =>
              (v == null || v.trim().isEmpty) ? '$label is required' : null
          : null,
      decoration: light
          ? decoration.copyWith(
              fillColor: const Color(0xFFFCFDFE),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AddLeadUi.fieldRadius),
                borderSide: BorderSide(
                  color: AddLeadUi.cardBorder.withValues(alpha: 0.9),
                ),
              ),
            )
          : decoration,
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
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.primaryLight
        : AppColors.primary;

    return DropdownButtonFormField<LandType>(
      isExpanded: true,
      initialValue: value,
      onChanged: onChanged,
      menuMaxHeight: 280,
      borderRadius: BorderRadius.circular(AddLeadUi.fieldRadius),
      decoration: addLeadInputDecoration(
        context,
        label: 'Land Type',
        icon: Icons.terrain_outlined,
        required: true,
      ),
      items: LandType.values
          .map(
            (t) => DropdownMenuItem(
              value: t,
              child: addLeadDropdownRow(
                icon: _landTypeIcon(t),
                label: t.label,
                iconColor: iconColor,
              ),
            ),
          )
          .toList(),
      selectedItemBuilder: (ctx) => LandType.values
          .map(
            (t) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t.label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          )
          .toList(),
    );
  }
}
