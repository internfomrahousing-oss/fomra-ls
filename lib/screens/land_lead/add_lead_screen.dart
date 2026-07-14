import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../models/gps_fix.dart';
import '../../models/land_lead.dart';
import '../../theme/app_theme.dart';
import '../../config/maptiler_tiles.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/add_lead_ui.dart';
import '../../widgets/terms_deal_selector.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/portal_page_layout.dart';
import '../../widgets/tngis_parcel_summary.dart';
import '../../widgets/ui/app_feedback.dart';
import '../../services/gps_verification_service.dart';
import '../../services/land_lead_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/api_client.dart';
import '../../utils/image_compressor.dart';
import '../../utils/lead_location_parser.dart';
import '../../utils/reverse_geocode.dart';
import '../../utils/tngis_parcel_lookup.dart';

enum _LocationMode { live }

const _kMaxSitePhotos = 4;

enum MeasurementUnit { acre, ground, cent, sqft }

extension MeasurementUnitLabel on MeasurementUnit {
  String get label => switch (this) {
        MeasurementUnit.acre => 'Acre',
        MeasurementUnit.ground => 'Ground',
        MeasurementUnit.cent => 'Cent',
        MeasurementUnit.sqft => 'Sq. Ft.',
      };
}

/// Best-effort split of a legacy free-text land extent (e.g. "2.5 acres")
/// into a numeric value and one of the known [MeasurementUnit]s, so existing
/// records still populate sensibly in the Measurement Value / Unit fields.
(String, MeasurementUnit?) _parseLandExtent(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return ('', null);
  final match = RegExp(r'([\d.]+)').firstMatch(text);
  final value = match?.group(1) ?? text;
  final lower = text.toLowerCase();
  MeasurementUnit? unit;
  if (lower.contains('acre')) {
    unit = MeasurementUnit.acre;
  } else if (lower.contains('ground')) {
    unit = MeasurementUnit.ground;
  } else if (lower.contains('cent')) {
    unit = MeasurementUnit.cent;
  } else if (lower.contains('sq')) {
    unit = MeasurementUnit.sqft;
  }
  return (value, unit);
}

/// Holds the controllers for one owner's name/contact in the dynamic
/// Owner Contact Details section.
class _OwnerEntry {
  final TextEditingController nameCtrl;
  final TextEditingController contactCtrl;

  _OwnerEntry({String name = '', String contact = ''})
      : nameCtrl = TextEditingController(text: name),
        contactCtrl = TextEditingController(text: contact);

  void dispose() {
    nameCtrl.dispose();
    contactCtrl.dispose();
  }
}

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
  final _brokerNameCtrl = TextEditingController();
  final _brokerContactCtrl = TextEditingController();

  // Section 2 — location fill-up
  final _locationCtrl   = TextEditingController();
  final _gpsCtrl        = TextEditingController();
  final _villageCtrl    = TextEditingController();
  final _talukCtrl      = TextEditingController();
  final _districtCtrl   = TextEditingController();
  final _surveyCtrl     = TextEditingController();
  final _subDivCtrl     = TextEditingController();
  final _extentValueCtrl = TextEditingController();
  MeasurementUnit? _extentUnit;
  final _pincodeCtrl    = TextEditingController();
  final _roadWidthCtrl  = TextEditingController();
  LandType _landType = LandType.agricultural;

  static const _kMaxOwners = 4;
  final List<_OwnerEntry> _owners = [_OwnerEntry()];

  _LocationMode _locationMode = _LocationMode.live;
  GpsFix? _verifiedGps;
  bool _fetchingLocation = false;
  bool _resolvingPin = false;
  String? _locationStatus;
  LatLng? _pinnedPoint;
  final _mapController = MapController();
  bool _mapReady = false;
  LatLng? _pendingMapCenter;
  Timer? _gpsDebounce;
  bool _suppressGpsListener = false;
  TngisParcelDetails? _tngisParcel;
  bool _loadingTngis = false;
  int _pinFetchSeq = 0;

  static const _kDefaultMapCenter = LatLng(13.0827, 80.2707);
  static final _kMapTileUrl = MapTilerTiles.standard;

  // Terms (serialized deal selection → LandLead.accessDetails)
  String? _termsType;
  final _notesCtrl = TextEditingController();

  // Photos (max 4)
  final List<AddLeadPhotoDraft> _photos = [];
  List<String> _keptPhotoUrls = [];
  bool _compressingPhoto = false;
  bool _saving = false;
  String _saveStatus = 'Saving lead…';

  final _scrollController = ScrollController();
  final _sectionKeys = List.generate(5, (_) => GlobalKey());
  int _activeSection = 0;

  void _onInputSourceChanged(InputSource? source) {
    setState(() {
      if (_inputSource == InputSource.broker && source != InputSource.broker) {
        _brokerNameCtrl.clear();
        _brokerContactCtrl.clear();
      }
      _inputSource = source;
    });
  }

  void _addOwner() {
    if (_owners.length >= _kMaxOwners) return;
    setState(() => _owners.add(_OwnerEntry()));
  }

  void _removeOwner(int index) {
    if (_owners.length <= 1) return;
    setState(() {
      final removed = _owners.removeAt(index);
      removed.dispose();
    });
  }

  bool get _isBrokerSource => _inputSource == InputSource.broker;

  bool get _isEdit => widget.existingLead != null;

  static const _kProgressLabels = [
    'Input Source',
    'Data Captured',
    'Terms',
    'Site Photos',
    'Notes',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _gpsCtrl.addListener(_onGpsTextChanged);
    final existing = widget.existingLead;
    if (existing == null) return;

    _inputSource = existing.inputSource;
    _brokerNameCtrl.text = existing.brokerName;
    _brokerContactCtrl.text = existing.brokerContact;
    _locationCtrl.text = existing.location;
    _gpsCtrl.text = existing.gpsCoordinates;
    _verifiedGps = GpsFix.tryParse(existing.gpsCoordinates);
    _villageCtrl.text = existing.village;
    _talukCtrl.text = existing.taluk;
    _districtCtrl.text = existing.district;
    _pincodeCtrl.text = existing.pincode;
    _surveyCtrl.text = existing.surveyNumber;
    _subDivCtrl.text = existing.subDivision;
    final parsedExtent = _parseLandExtent(existing.landExtent);
    _extentValueCtrl.text = parsedExtent.$1;
    _extentUnit = parsedExtent.$2;
    _owners[0].nameCtrl.text = existing.ownerName;
    _owners[0].contactCtrl.text = existing.contactDetails;
    for (final extra in existing.additionalOwners.take(_kMaxOwners - 1)) {
      _owners.add(_OwnerEntry(name: extra.name, contact: extra.contact));
    }
    _roadWidthCtrl.text = existing.roadWidth;
    _landType = existing.landType;
    if (existing.accessDetails.isNotEmpty) {
      _termsType = existing.accessDetails;
    }
    _notesCtrl.text = existing.notes;
    _pinnedPoint = parseLeadGps(existing.gpsCoordinates);
    _keptPhotoUrls = List<String>.from(existing.sitePhotoUrls);
    if (_keptPhotoUrls.isEmpty && existing.sitePhotoUrl.isNotEmpty) {
      _keptPhotoUrls = [existing.sitePhotoUrl];
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAutoFetchTngisForExistingLead();
    });
  }

  @override
  void dispose() {
    _gpsDebounce?.cancel();
    _gpsCtrl.removeListener(_onGpsTextChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    for (final c in [
      _locationCtrl, _gpsCtrl, _villageCtrl, _talukCtrl, _districtCtrl,
      _pincodeCtrl, _surveyCtrl, _subDivCtrl, _extentValueCtrl,
      _brokerNameCtrl, _brokerContactCtrl, _roadWidthCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    for (final o in _owners) {
      o.dispose();
    }
    _mapController.dispose();
    super.dispose();
  }

  // ── Location fill from coordinates ─────────────────────────────────────────

  void _onGpsTextChanged() {
    // Typed / pasted GPS is rejected — live capture only.
  }

  Future<void> _applyGpsFromText() async {
    if (!mounted) return;
    // Restore verified live storage if the user tried to edit the field.
    if (_verifiedGps != null) {
      _suppressGpsListener = true;
      _gpsCtrl.text = _verifiedGps!.toStorage();
      _suppressGpsListener = false;
    }
    AppFeedback.error(
        context, 'Manual GPS entry is not allowed. Capture live GPS.');
  }

  void _clearPinDerivedFields() {
    _locationCtrl.clear();
    _villageCtrl.clear();
    _talukCtrl.clear();
    _districtCtrl.clear();
    _pincodeCtrl.clear();
    _surveyCtrl.clear();
    _subDivCtrl.clear();
    _extentValueCtrl.clear();
    _extentUnit = null;
  }

  void _setCtrlIfNonEmpty(TextEditingController ctrl, String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty || text == '-') return;
    ctrl.text = text;
  }

  void _applyTngisParcelToForm(TngisParcelDetails parcel) {
    _setCtrlIfNonEmpty(_surveyCtrl, parcel.surveyNumber);
    _setCtrlIfNonEmpty(_subDivCtrl, parcel.subDivision);
    _setCtrlIfNonEmpty(_villageCtrl, parcel.village);
    _setCtrlIfNonEmpty(_talukCtrl, parcel.taluk);
    _setCtrlIfNonEmpty(_districtCtrl, parcel.district);
    final village = parcel.village?.trim();
    if (village != null && village.isNotEmpty) {
      _locationCtrl.text = village;
    }
    final extent = parcel.landExtentDisplay?.trim();
    if (extent != null && extent.isNotEmpty) {
      final parsed = _parseLandExtent(extent);
      if (parsed.$1.isNotEmpty) {
        _extentValueCtrl.text = parsed.$1;
        _extentUnit = parsed.$2 ?? _extentUnit;
      }
    }
  }

  bool get _needsTngisBackfill =>
      _surveyCtrl.text.trim().isEmpty ||
      _villageCtrl.text.trim().isEmpty ||
      _extentValueCtrl.text.trim().isEmpty;

  Future<void> _maybeAutoFetchTngisForExistingLead() async {
    if (!_isEdit || _pinnedPoint == null || !_needsTngisBackfill) return;
    final fetchSeq = ++_pinFetchSeq;
    setState(() {
      _loadingTngis = true;
      _resolvingPin = true;
      _locationStatus = 'Fetching land details from TNGIS…';
    });
    try {
      final point = _pinnedPoint!;
      final adminEmpty = _villageCtrl.text.trim().isEmpty &&
          _talukCtrl.text.trim().isEmpty &&
          _districtCtrl.text.trim().isEmpty;
      if (adminEmpty) {
        await _fillFromCoordinates(
          point.latitude,
          point.longitude,
          clearLoading: false,
          fetchSeq: fetchSeq,
        );
      }
      if (!_isActivePinFetch(fetchSeq)) return;
      await _fillSurveyFromTngis(point, fetchSeq: fetchSeq);
    } catch (e) {
      if (!_isActivePinFetch(fetchSeq)) return;
      setState(() => _locationStatus =
          'Error: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (_isActivePinFetch(fetchSeq)) {
        setState(() {
          _resolvingPin = false;
          _fetchingLocation = false;
        });
      }
    }
  }

  bool _isActivePinFetch(int fetchSeq) =>
      mounted && fetchSeq == _pinFetchSeq;

  Future<void> _fillFromCoordinates(
    double lat,
    double lng, {
    bool clearLoading = true,
    int? fetchSeq,
  }) async {
    _suppressGpsListener = true;
    _gpsCtrl.text = formatLeadGps(lat, lng);
    _suppressGpsListener = false;

    if (!_isActivePinFetch(fetchSeq ?? _pinFetchSeq) && fetchSeq != null) {
      return;
    }
    if (!mounted) return;
    setState(() => _locationStatus = 'Fetching address…');

    try {
      final geocoded = await fetchReverseGeocode(lat, lng);

      if (fetchSeq != null && !_isActivePinFetch(fetchSeq)) return;
      if (!mounted) return;

      if (geocoded != null) {
        if (geocoded.location.isNotEmpty) _locationCtrl.text = geocoded.location;
        if (geocoded.village.isNotEmpty) _villageCtrl.text = geocoded.village;
        if (geocoded.taluk.isNotEmpty) _talukCtrl.text = geocoded.taluk;
        if (geocoded.district.isNotEmpty) _districtCtrl.text = geocoded.district;
        if (geocoded.pincode.isNotEmpty) _pincodeCtrl.text = geocoded.pincode;

        setState(() => _locationStatus = 'Location filled ✓');
      } else {
        setState(() => _locationStatus = 'Address lookup failed — GPS coordinates saved.');
      }
    } catch (e) {
      if (fetchSeq != null && !_isActivePinFetch(fetchSeq)) return;
      if (!mounted) return;
      setState(() => _locationStatus =
          'Error: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (clearLoading && mounted && (fetchSeq == null || _isActivePinFetch(fetchSeq))) {
        setState(() {
          _fetchingLocation = false;
          _resolvingPin = false;
        });
      }
    }
  }

  Future<void> _fillSurveyFromTngis(
    LatLng point, {
    required int fetchSeq,
  }) async {
    if (!_isActivePinFetch(fetchSeq)) return;

    setState(() {
      _loadingTngis = true;
      _tngisParcel = null;
      _locationStatus = 'Fetching village & parcel from TNGIS…';
    });

    try {
      final parcel = await fetchTngisParcelAt(point);
      if (!_isActivePinFetch(fetchSeq)) return;

      _applyTngisParcelToForm(parcel);

      if (_pincodeCtrl.text.trim().isEmpty) {
        final pinFromAdmin = await fetchPincodeForAdminArea(
          village: _villageCtrl.text,
          taluk: _talukCtrl.text,
          district: _districtCtrl.text,
        );
        if (!_isActivePinFetch(fetchSeq)) return;
        if (pinFromAdmin != null && pinFromAdmin.isNotEmpty) {
          _pincodeCtrl.text = pinFromAdmin;
        }
      }

      if (!_isActivePinFetch(fetchSeq)) return;
      setState(() {
        _tngisParcel = parcel;
        _loadingTngis = false;
        if (parcel.hasSurvey) {
          _locationStatus = parcel.landExtentDisplay != null
              ? 'TNGIS village, survey & extent filled ✓'
              : 'TNGIS village & survey filled ✓';
        } else if (parcel.hasAdminData) {
          _locationStatus = 'TNGIS village details filled ✓';
        } else if (_locationCtrl.text.trim().isNotEmpty ||
            _villageCtrl.text.trim().isNotEmpty) {
          _locationStatus = 'Address filled — parcel not found at this pin';
        } else {
          _locationStatus = 'No parcel at this pin — try zooming onto the plot';
        }
      });
    } on ApiException catch (e) {
      if (!_isActivePinFetch(fetchSeq)) return;
      setState(() {
        _loadingTngis = false;
        _tngisParcel = null;
        _locationStatus = 'TNGIS lookup failed: ${e.message}';
      });
    } catch (e) {
      if (!_isActivePinFetch(fetchSeq)) return;
      setState(() {
        _loadingTngis = false;
        _tngisParcel = null;
        _locationStatus =
            'TNGIS lookup error: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  void _onLocationModeChanged(_LocationMode mode) {
    setState(() => _locationMode = _LocationMode.live);
  }

  void _onMapReady() {
    setState(() => _mapReady = true);
    final parsed =
        _pinnedPoint ?? _pendingMapCenter ?? parseLeadGps(_gpsCtrl.text);
    if (parsed == null) return;
    final firstPin = _pinnedPoint == null;
    if (firstPin) {
      setState(() => _pinnedPoint = parsed);
    }
    _centerMapOn(parsed, zoom: firstPin ? 16.0 : null);
  }

  void _centerMapOn(LatLng point, {double? zoom}) {
    _pendingMapCenter = point;
    if (!_mapReady) return;

    _mapController.move(
      point,
      zoom ?? _mapController.camera.zoom.clamp(12.0, 18.0),
    );
    _pendingMapCenter = null;
  }

  Future<void> _onMapPin(LatLng point) async {
    // Manual map pins are rejected — live GPS only.
    if (!mounted) return;
    AppFeedback.error(
        context, 'Manual map pins are not allowed. Capture live GPS.');
  }

  Future<void> _placePinAndFetchDetails(LatLng point) async {
    final fetchSeq = ++_pinFetchSeq;
    final firstPin = _pinnedPoint == null;

    _clearPinDerivedFields();
    setState(() {
      _pinnedPoint = point;
      _tngisParcel = null;
      _loadingTngis = true;
      _resolvingPin = true;
      _locationStatus = 'Pin placed — fetching land details…';
    });
    _centerMapOn(point, zoom: firstPin ? 16.0 : null);
    await _fetchPinDetailsOnly(point, fetchSeq: fetchSeq);
  }

  Future<void> _fetchPinDetailsOnly(
    LatLng point, {
    required int fetchSeq,
  }) async {
    _centerMapOn(point);
    try {
      await _fillFromCoordinates(
        point.latitude,
        point.longitude,
        clearLoading: false,
        fetchSeq: fetchSeq,
      );
      if (!_isActivePinFetch(fetchSeq)) return;
      await _fillSurveyFromTngis(point, fetchSeq: fetchSeq);
    } catch (e) {
      if (!_isActivePinFetch(fetchSeq)) return;
      setState(() => _locationStatus =
          'Error: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (_isActivePinFetch(fetchSeq)) {
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
      _locationStatus = 'Capturing live GPS…';
      _locationMode = _LocationMode.live;
    });

    try {
      final fix = await GpsVerificationService.captureLive();
      final point = fix.point;
      if (!mounted) return;
      setState(() {
        _verifiedGps = fix;
        _gpsCtrl.text = fix.toStorage();
        _locationStatus =
            '✓ Live GPS · ${fix.summaryLabel}';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _centerMapOn(point);
      });
      await _placePinAndFetchDetails(point);
    } on GpsVerificationException catch (e) {
      _setStatus(e.message);
      setState(() => _verifiedGps = null);
    } catch (e) {
      _setStatus('Error: ${e.toString().replaceAll('Exception: ', '')}');
      setState(() => _verifiedGps = null);
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

  // ── Photo picker ───────────────────────────────────────────────────────────

  /// Mobile (Android/iOS) offers Camera + Gallery via the native picker;
  /// desktop and web keep the standard file picker.
  bool get _mobileNativePickers =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _pickPhoto() async {
    if (_keptPhotoUrls.length + _photos.length >= _kMaxSitePhotos) {
      AppFeedback.warning(context, 'Maximum $_kMaxSitePhotos photos per lead');
      return;
    }

    if (_mobileNativePickers) {
      final source = await _choosePhotoSource();
      if (source == null || !mounted) return;
      try {
        final picked = await ImagePicker().pickImage(
          source: source,
          maxWidth: 2400,
          imageQuality: 90,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        await _addPhotoBytes(bytes, picked.name);
      } catch (e) {
        if (!mounted) return;
        AppFeedback.error(
            context, e.toString().replaceFirst('Exception: ', ''));
      }
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
    await _addPhotoBytes(file.bytes!, file.name);
  }

  Future<ImageSource?> _choosePhotoSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.fomraSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.fomraBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.primary),
              title: const Text('Take photo'),
              subtitle: const Text('Open camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
              title: const Text('Choose from gallery'),
              subtitle: const Text('Pick an existing photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _addPhotoBytes(Uint8List bytes, String name) async {
    setState(() => _compressingPhoto = true);
    try {
      final compressed = await ImageCompressor.compressTo250Kb(bytes);
      if (!mounted) return;
      setState(() {
        _photos.add(AddLeadPhotoDraft(
          bytes: compressed,
          name: name,
          originalSize: bytes.length,
        ));
        _compressingPhoto = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _compressingPhoto = false);
      AppFeedback.error(context, e.toString().replaceFirst('Exception: ', ''));
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
        if (_inputSource == null) return false;
        if (_isBrokerSource) {
          return _brokerNameCtrl.text.trim().isNotEmpty &&
              _brokerContactCtrl.text.trim().isNotEmpty;
        }
        return true;
      case 1:
        return _locationCtrl.text.trim().isNotEmpty &&
            _extentValueCtrl.text.trim().isNotEmpty &&
            _extentUnit != null;
      case 2:
        return (_termsType ?? '').isNotEmpty;
      case 3:
        return _photos.isNotEmpty || _keptPhotoUrls.isNotEmpty;
      case 4:
        return _notesCtrl.text.trim().isNotEmpty;
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

  Future<void> _submit() async {
    if (_saving) return;
    if (_compressingPhoto) {
      AppFeedback.warning(context, 'Please wait — photo is still compressing');
      return;
    }
    if (_inputSource == null) {
      AppFeedback.error(context, 'Please select an Input Source');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final existing = widget.existingLead;
    final gpsText = _gpsCtrl.text.trim();
    final liveFix = _verifiedGps ?? GpsFix.tryParse(gpsText);

    // On edit, keep the lead's existing GPS when it hasn't been re-captured.
    // Older leads may not be stored in LIVE| format, so we don't force a fresh
    // live fix just to save an edit — we only require live GPS for new leads or
    // when the coordinates have actually changed.
    final keepingExistingGps = _isEdit &&
        existing != null &&
        existing.gpsCoordinates.trim().isNotEmpty &&
        gpsText == existing.gpsCoordinates.trim();

    // Require a live GPS fix (reject manual pins / typed coords).
    if (!keepingExistingGps && (liveFix == null || !liveFix.isLive)) {
      AppFeedback.error(context,
          'Capture live GPS before saving. Manual pins are not allowed.');
      return;
    }

    final gpsStorage = liveFix?.toStorage() ?? existing!.gpsCoordinates.trim();

    final combinedNotes = _notesCtrl.text.trim();
    final extentValue = _extentValueCtrl.text.trim();
    final landExtent = extentValue.isEmpty
        ? ''
        : (_extentUnit == null ? extentValue : '$extentValue ${_extentUnit!.label}');
    final additionalOwners = _owners
        .skip(1)
        .where((o) =>
            o.nameCtrl.text.trim().isNotEmpty ||
            o.contactCtrl.text.trim().isNotEmpty)
        .map((o) => OwnerContact(
              name: o.nameCtrl.text.trim(),
              contact: o.contactCtrl.text.trim(),
            ))
        .toList();
    final lead = LandLead(
      leadId: existing?.leadId ?? '',
      inputSource: _inputSource!,
      location: _locationCtrl.text.trim(),
      gpsCoordinates: gpsStorage,
      village: _villageCtrl.text.trim(),
      taluk: _talukCtrl.text.trim(),
      district: _districtCtrl.text.trim(),
      pincode: _pincodeCtrl.text.trim(),
      surveyNumber: _surveyCtrl.text.trim(),
      subDivision: _subDivCtrl.text.trim(),
      landExtent: landExtent,
      ownerName: _owners[0].nameCtrl.text.trim(),
      contactDetails: _owners[0].contactCtrl.text.trim(),
      additionalOwners: additionalOwners,
      brokerName: _isBrokerSource ? _brokerNameCtrl.text.trim() : '',
      brokerContact: _isBrokerSource ? _brokerContactCtrl.text.trim() : '',
      landType: _landType,
      roadWidth: _roadWidthCtrl.text.trim(),
      accessDetails: _termsType ?? '',
      notes: combinedNotes,
      addedOn: existing?.addedOn ?? DateTime.now(),
      createdByName: existing?.createdByName ?? '',
      createdByRole: existing?.createdByRole ?? '',
      status: existing?.status ?? LeadStatus.prospectMeetingPending,
      sitePhotoUrl: _keptPhotoUrls.isNotEmpty ? _keptPhotoUrls.first : '',
      sitePhotoUrls: List<String>.from(_keptPhotoUrls),
    );

    final photoBytes = _photos.map((p) => p.bytes).toList();
    setState(() {
      _saving = true;
      _saveStatus = photoBytes.isNotEmpty
          ? 'Uploading photos…'
          : 'Saving lead…';
    });

    try {
      final sync = OfflineSyncService.instance;
      if (!sync.isOnline) {
        if (_isEdit) {
          await sync.enqueueUpdateLead(lead: lead, photoBytes: photoBytes);
        } else {
          await sync.enqueueCreateLead(lead: lead, photoBytes: photoBytes);
        }
        if (!mounted) return;
        AppFeedback.warning(
            context, 'Saved offline — will sync when network returns.');
        Navigator.pop(context, lead);
        return;
      }

      final saved = _isEdit
          ? await LandLeadService.update(
              lead,
              sitePhotoBytes: photoBytes,
              onProgress: _onSaveProgress,
            )
          : await LandLeadService.create(
              lead,
              sitePhotoBytes: photoBytes,
              onProgress: _onSaveProgress,
            );
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      // Network failure mid-save → queue for later.
      try {
        final sync = OfflineSyncService.instance;
        if (_isEdit) {
          await sync.enqueueUpdateLead(lead: lead, photoBytes: photoBytes);
        } else {
          await sync.enqueueCreateLead(lead: lead, photoBytes: photoBytes);
        }
        if (!mounted) return;
        AppFeedback.warning(
            context, 'Network error — queued offline for sync.');
        Navigator.pop(context, lead);
        return;
      } catch (_) {}
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.error(
        context,
        'Failed to save lead: ${e.toString().replaceFirst('Exception: ', '')}',
        duration: const Duration(seconds: 6),
      );
    }
  }

  void _onSaveProgress(String message) {
    if (!mounted) return;
    setState(() => _saveStatus = message);
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

    return Stack(
      children: [
        FomraAppShell(
      currentRoute: '/land-lead',
      backgroundColor: context.fomraPageBg,
      appBar: AddLeadAppBar(
        title: _isEdit ? 'Edit Land Lead' : 'Add Land Lead',
        onSave: _submit,
        saving: _saving,
      ),
      bottomNavigationBar: AddLeadStickyFooter(
        onCancel: () => Navigator.pop(context),
        onSave: _submit,
        saving: _saving,
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
                                onChanged: _onInputSourceChanged,
                              ),
                              if (_isBrokerSource) ...[
                                const SizedBox(height: AddLeadUi.fieldGap),
                                addLeadFormRow(
                                  context,
                                  _Field(
                                    ctrl: _brokerNameCtrl,
                                    label: 'Broker Name',
                                    hint: 'Full name of the broker',
                                    icon: Icons.person_outline_rounded,
                                    required: true,
                                  ),
                                  _Field(
                                    ctrl: _brokerContactCtrl,
                                    label: 'Broker Contact Number',
                                    hint: 'Phone number',
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                    required: true,
                                  ),
                                ),
                              ],
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
                          trailing: const AddLeadHeaderTag(
                            label: 'Lead ID',
                            tooltip:
                                'Generated automatically after the site is created',
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Live GPS only — map pins and typed coordinates are rejected.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.fomraTextSecondary,
                                ),
                              ),
                              const SizedBox(height: AddLeadUi.fieldGap),
                              AddLeadLiveLocationCard(
                                fetching: _fetchingLocation,
                                status: _locationStatus,
                                onTap: _fetchingLocation
                                    ? null
                                    : _fetchLiveLocation,
                              ),
                              if (_verifiedGps != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Lat ${_verifiedGps!.latitude.toStringAsFixed(6)} · '
                                  'Lng ${_verifiedGps!.longitude.toStringAsFixed(6)} · '
                                  '±${_verifiedGps!.accuracyMeters.toStringAsFixed(0)} m · '
                                  '${_verifiedGps!.timestamp.toLocal()}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
                              if (_loadingTngis || _tngisParcel != null) ...[
                                TngisParcelSummary(
                                  key: ValueKey(
                                    '${_pinnedPoint?.latitude}_'
                                    '${_pinnedPoint?.longitude}_'
                                    '$_pinFetchSeq',
                                  ),
                                  parcel: _tngisParcel ??
                                      const TngisParcelDetails(),
                                  loading: _loadingTngis,
                                ),
                                const SizedBox(height: AddLeadUi.fieldGap),
                              ],
                              _Field(
                                ctrl: _gpsCtrl,
                                label: 'GPS (live verified)',
                                hint: 'Capture live GPS above — manual entry blocked',
                                icon: Icons.gps_fixed_rounded,
                                readOnly: true,
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
                                  hint: 'e.g. 42/3A  (optional)',
                                  icon: Icons.tag_outlined,
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
                                  ctrl: _extentValueCtrl,
                                  label: 'Measurement Value',
                                  hint: 'e.g. 2.5',
                                  icon: Icons.straighten_rounded,
                                  keyboardType: const TextInputType
                                      .numberWithOptions(decimal: true),
                                  required: true,
                                ),
                                _MeasurementUnitDropdown(
                                  value: _extentUnit,
                                  onChanged: (v) =>
                                      setState(() => _extentUnit = v),
                                ),
                              ),
                              const SizedBox(height: AddLeadUi.sectionGap),
                              _OwnerContactSection(
                                owners: _owners,
                                maxOwners: _kMaxOwners,
                                onAdd: _addOwner,
                                onRemove: _removeOwner,
                              ),
                              const SizedBox(height: AddLeadUi.sectionGap),
                              addLeadFormRow(
                                context,
                                _LandTypeDropdown(
                                  value: _landType,
                                  onChanged: (v) =>
                                      setState(() => _landType = v!),
                                ),
                                _Field(
                                  ctrl: _roadWidthCtrl,
                                  label: 'Road Width',
                                  hint: 'e.g. 30 ft / 9 m',
                                  icon: Icons.open_in_full_rounded,
                                ),
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
                          subtitle: 'Select a term to see its relevant details',
                          icon: Icons.handshake_outlined,
                          compact: true,
                          child: TermsDealSelector(
                            value: _termsType,
                            onChanged: (v) =>
                                setState(() => _termsType = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: AddLeadUi.sectionGap),
                      _sectionAnchor(
                        3,
                        _buildSitePhotosSection('4'),
                      ),
                      const SizedBox(height: AddLeadUi.sectionGap),
                      _sectionAnchor(
                        4,
                        AddLeadSectionCard(
                          number: '5',
                          title: 'Notes',
                          subtitle: 'Any additional observations',
                          icon: Icons.sticky_note_2_outlined,
                          child: _Field(
                            ctrl: _notesCtrl,
                            label: 'Notes',
                            hint: 'Any additional observations',
                            icon: Icons.notes_outlined,
                            maxLines: 3,
                            maxLength: 500,
                          ),
                        ),
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
        ),
        if (_saving) AddLeadSaveOverlay(message: _saveStatus),
      ],
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

// ── Text field ──────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final bool required;
  final int maxLines;
  final int? maxLength;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool light;
  final bool readOnly;
  final ValueChanged<String>? onFieldSubmitted;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.required = false,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.readOnly = false,
  }) : light = false, onFieldSubmitted = null;

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
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
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

// ── Measurement Unit Dropdown ───────────────────────────────────────────────

class _MeasurementUnitDropdown extends StatelessWidget {
  final MeasurementUnit? value;
  final ValueChanged<MeasurementUnit?> onChanged;

  const _MeasurementUnitDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.primaryLight
        : AppColors.primary;

    return DropdownButtonFormField<MeasurementUnit>(
      isExpanded: true,
      initialValue: value,
      onChanged: onChanged,
      menuMaxHeight: 260,
      borderRadius: BorderRadius.circular(AddLeadUi.fieldRadius),
      decoration: addLeadInputDecoration(
        context,
        label: 'Measurement Unit',
        hint: 'Select unit',
        icon: Icons.square_foot_rounded,
        required: true,
      ),
      validator: (v) => v == null ? 'Measurement Unit is required' : null,
      items: MeasurementUnit.values
          .map(
            (u) => DropdownMenuItem(
              value: u,
              child: addLeadDropdownRow(
                icon: Icons.square_foot_rounded,
                label: u.label,
                iconColor: iconColor,
              ),
            ),
          )
          .toList(),
      selectedItemBuilder: (ctx) => MeasurementUnit.values
          .map(
            (u) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                u.label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ── Owner Contact Details (dynamic, up to 4 owners) ─────────────────────────

class _OwnerContactSection extends StatelessWidget {
  final List<_OwnerEntry> owners;
  final int maxOwners;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _OwnerContactSection({
    required this.owners,
    required this.maxOwners,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Owner Contact Details',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.fomraTextPrimary,
                ),
              ),
            ),
            if (owners.length < maxOwners)
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('Add Owner'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < owners.length; i++) ...[
          if (i > 0) const SizedBox(height: AddLeadUi.fieldGap),
          _OwnerFields(
            index: i,
            entry: owners[i],
            onRemove: owners.length > 1 ? () => onRemove(i) : null,
          ),
        ],
      ],
    );
  }
}

class _OwnerFields extends StatelessWidget {
  final int index;
  final _OwnerEntry entry;
  final VoidCallback? onRemove;

  const _OwnerFields({
    required this.index,
    required this.entry,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final fields = addLeadFormRow(
      context,
      _Field(
        ctrl: entry.nameCtrl,
        label: index == 0 ? 'Owner Name' : 'Owner ${index + 1} Name',
        hint: 'Full name of the land owner',
        icon: Icons.person_outline_rounded,
      ),
      _Field(
        ctrl: entry.contactCtrl,
        label: index == 0 ? 'Contact Number' : 'Owner ${index + 1} Contact',
        hint: '10-digit mobile number',
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
      ),
    );

    if (onRemove == null) return fields;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? context.fomraSurfaceVar : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AddLeadUi.fieldRadius),
        border: Border.all(color: AddLeadUi.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Owner ${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.fomraTextSecondary,
                  ),
                ),
              ),
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          fields,
        ],
      ),
    );
  }
}
