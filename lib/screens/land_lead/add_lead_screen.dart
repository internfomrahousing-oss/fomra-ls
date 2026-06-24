import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../models/land_lead.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';

enum _LocationMode { manual, live }

class AddLeadScreen extends StatefulWidget {
  const AddLeadScreen({super.key});

  @override
  State<AddLeadScreen> createState() => _AddLeadScreenState();
}

class _AddLeadScreenState extends State<AddLeadScreen> {
  final _formKey = GlobalKey<FormState>();

  // Section 1 — MCQ
  InputSource? _inputSource;

  // Section 2 — fill-up fields
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
  final _accessCtrl     = TextEditingController();
  final _notesCtrl      = TextEditingController();
  LandType _landType = LandType.agricultural;

  _LocationMode _locationMode = _LocationMode.manual;
  bool _fetchingLocation = false;
  String? _locationStatus;

  // ── TN land code resolution ────────────────────────────────────────────────
  String? _resolvedDc;
  String? _resolvedTc;
  String? _resolvedVc;
  bool _resolvingCodes = false;
  String? _codeStatusMsg;

  // ── Patta ──────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _pattaResult;
  bool _fetchingPatta = false;
  String? _pattaError;

  // ── EC ─────────────────────────────────────────────────────────────────────
  String? _resolvedEcZone;
  String? _resolvedEcDc;
  List<Map<String, dynamic>> _ecSroList = [];
  bool _loadingEcSros = false;
  String? _selectedEcSro;
  Map<String, dynamic>? _ecResult;
  bool _fetchingEc = false;
  String? _ecError;
  final _ecFromCtrl = TextEditingController();
  final _ecToCtrl   = TextEditingController();
  bool _autoFetchTriggered = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _ecToCtrl.text =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    _ecFromCtrl.text = '01/01/1990';
    // Rebuild when survey number changes so the Fetch button reacts
    _surveyCtrl.addListener(() {
      _autoFetchTriggered = false;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    for (final c in [
      _locationCtrl, _gpsCtrl, _villageCtrl, _talukCtrl, _districtCtrl,
      _pincodeCtrl, _surveyCtrl, _subDivCtrl, _extentCtrl, _ownerCtrl,
      _contactCtrl, _roadWidthCtrl, _accessCtrl, _notesCtrl,
      _ecFromCtrl, _ecToCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
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
      _gpsCtrl.text =
          '${lat.toStringAsFixed(6)}° N, ${lng.toStringAsFixed(6)}° E';

      setState(() => _locationStatus = 'Fetching address…');

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lng&format=json&addressdetails=1',
      );
      final response = await http.get(uri, headers: {
        'Accept-Language': 'en',
        'User-Agent': 'FomraLS/1.0 (in.fomrahousing)',
      });

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

        _setStatus('Location filled ✓');

        // Auto-resolve TN land codes for Patta & EC in the background
        _resolveLocationCodes(
          district.isNotEmpty ? district : taluk,
          taluk,
          village,
          hints: [
            location,
            village,
            taluk,
            district,
            _first(addr, ['state_district', 'county', 'state']),
            _first(addr, ['city', 'town', 'municipality', 'suburb', 'neighbourhood']),
          ],
        );
      } else {
        _setStatus('Address lookup failed — GPS coordinates saved.');
      }
    } on LocationServiceDisabledException {
      _setStatus('Location services are disabled. Enable them in browser settings.');
    } catch (e) {
      _setStatus('Error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  void _setStatus(String msg) {
    if (!mounted) return;
    setState(() {
      _fetchingLocation = false;
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

  // ── TN land code resolution ────────────────────────────────────────────────

  String _normalise(String s) => s
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\b(district|taluk|village|municipality|corporation)\b'), '')
      .trim();

  Map<String, dynamic>? _fuzzyMatch(List<dynamic> items, String name) {
    if (name.trim().isEmpty) return null;
    final norm = _normalise(name);
    // Exact match
    for (final item in items) {
      final m = item as Map<String, dynamic>;
      if (_normalise(m['name'] as String) == norm) return m;
    }
    // Contains match
    for (final item in items) {
      final m = item as Map<String, dynamic>;
      final n = _normalise(m['name'] as String);
      if (n.contains(norm) || norm.contains(n)) return m;
    }
    // First-word match (only for words longer than 3 chars)
    final firstWord = norm.split(' ').first;
    if (firstWord.length > 3) {
      for (final item in items) {
        final m = item as Map<String, dynamic>;
        if (_normalise(m['name'] as String).startsWith(firstWord)) return m;
      }
    }
    return null;
  }

  Future<void> _resolveLocationCodes(
      String district, String taluk, String village,
      {List<String> hints = const []}) async {
    if (!mounted) return;
    setState(() {
      _resolvingCodes = true;
      _codeStatusMsg = 'Resolving TN land codes…';
      _resolvedDc = null;
      _resolvedTc = null;
      _resolvedVc = null;
    });

    try {
      final districtCandidates = [district, ...hints].where((s) => s.trim().isNotEmpty).toList();
      final talukCandidates = [taluk, ...hints].where((s) => s.trim().isNotEmpty).toList();
      final villageCandidates = [village, ...hints].where((s) => s.trim().isNotEmpty).toList();

      // Step 1 — districts
      final districts = await ApiClient.getList('/api/tnlands/districts');
      Map<String, dynamic>? dMatch;
      for (final candidate in districtCandidates) {
        dMatch = _fuzzyMatch(districts, candidate);
        if (dMatch != null) break;
      }
      if (dMatch == null) {
        _setCodeStatus('District not found in TN records — enter survey data manually.');
        return;
      }
      final dc = dMatch['code'] as String;

      // Step 2 — taluks
      final taluks = await ApiClient.getList('/api/tnlands/taluks?dc=$dc');
      Map<String, dynamic>? tMatch;
      for (final candidate in talukCandidates) {
        tMatch = _fuzzyMatch(taluks, candidate);
        if (tMatch != null) break;
      }
      if (tMatch == null) {
        if (mounted) setState(() => _resolvedDc = dc);
        _setCodeStatus('District matched. Taluk not found — select manually.');
        _resolveEcCodes([district, taluk, ...hints]);
        return;
      }
      final tc = tMatch['code'] as String;

      // Step 3 — villages
      final villages =
          await ApiClient.getList('/api/tnlands/villages?dc=$dc&tc=$tc');
      Map<String, dynamic>? vMatch;
      for (final candidate in villageCandidates) {
        vMatch = _fuzzyMatch(villages, candidate);
        if (vMatch != null) break;
      }

      if (!mounted) return;
      setState(() {
        _resolvedDc = dc;
        _resolvedTc = tc;
        _resolvedVc = vMatch?['code'] as String?;
      });

      _setCodeStatus(vMatch != null
          ? 'Land codes resolved ✓  Ready to fetch Patta & EC'
          : 'District & taluk matched. Village not found — fetch may still work.');

      _resolveEcCodes([district, taluk, village, ...hints]);
    } on ApiException catch (e) {
      _setCodeStatus('Code lookup failed: ${e.message}');
    } catch (e) {
      _setCodeStatus('Code lookup failed: ${e.toString().split(':').last.trim()}');
    }
  }

  Future<void> _resolveEcCodes(List<String> districtHints) async {
    for (final zone in ['1', '2', '3']) {
      try {
        final ecDistricts =
            await ApiClient.getList('/api/tnlands/ec/districts?zone=$zone');
        Map<String, dynamic>? dMatch;
        for (final hint in districtHints.where((s) => s.trim().isNotEmpty)) {
          dMatch = _fuzzyMatch(ecDistricts, hint);
          if (dMatch != null) break;
        }
        if (dMatch != null) {
          if (!mounted) return;
          setState(() {
            _resolvedEcZone = zone;
            _resolvedEcDc = dMatch['code'] as String;
          });
          _loadEcSros(zone, dMatch['code'] as String);
          return;
        }
      } catch (_) {
        // try next zone
      }
    }
  }

  Future<void> _loadEcSros(String zone, String dc) async {
    if (!mounted) return;
    setState(() => _loadingEcSros = true);
    try {
      final sros =
          await ApiClient.getList('/api/tnlands/ec/sros?zone=$zone&dc=$dc');
      if (!mounted) return;
      setState(() {
        _ecSroList = sros.map((s) => s as Map<String, dynamic>).toList();
        if (_ecSroList.isNotEmpty && _selectedEcSro == null) {
          _selectedEcSro = _ecSroList.first['code'] as String?;
        }
        _loadingEcSros = false;
      });
      _maybeAutoFetchRecords();
    } catch (_) {
      if (mounted) setState(() => _loadingEcSros = false);
    }
  }

  void _maybeAutoFetchRecords() {
    if (!mounted || _autoFetchTriggered) return;
    if (_surveyCtrl.text.trim().isEmpty) return;
    if (!_pattaReady || !_ecReady) return;
    _autoFetchTriggered = true;
    _fetchPatta();
    _fetchEc();
  }

  void _setCodeStatus(String msg) {
    if (!mounted) return;
    setState(() {
      _resolvingCodes = false;
      _codeStatusMsg = msg;
    });
  }

  // ── Patta fetch ────────────────────────────────────────────────────────────

  Future<void> _fetchPatta() async {
    final surveyNo = _surveyCtrl.text.trim();
    if (_resolvedDc == null || surveyNo.isEmpty) return;

    setState(() {
      _fetchingPatta = true;
      _pattaError = null;
      _pattaResult = null;
    });

    try {
      final params = StringBuffer('dc=$_resolvedDc')
        ..write('&tc=${_resolvedTc ?? ''}')
        ..write('&vc=${_resolvedVc ?? ''}')
        ..write('&surveyNo=${Uri.encodeComponent(surveyNo)}')
        ..write('&subDiv=${Uri.encodeComponent(_subDivCtrl.text.trim())}');

      final result = await ApiClient.get('/api/tnlands/patta?$params');
      if (!mounted) return;
      setState(() {
        _pattaResult = result;
        _fetchingPatta = false;
      });
      _autoFillFromPatta(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _pattaError = e.message;
        _fetchingPatta = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pattaError = e.toString().split(':').last.trim();
        _fetchingPatta = false;
      });
    }
  }

  // Auto-populates owner name and extent from a successful patta response.
  void _autoFillFromPatta(Map<String, dynamic> patta) {
    final fields = (patta['fields'] as Map<String, dynamic>?) ?? {};
    final owners = (patta['owners'] as List<dynamic>?) ?? [];

    // Fill owner name if the field is still empty
    if (_ownerCtrl.text.trim().isEmpty) {
      if (owners.isNotEmpty) {
        final first = owners.first as Map<String, dynamic>;
        final name  = first.values
            .map((v) => v.toString().trim())
            .firstWhere((v) => v.length > 2, orElse: () => '');
        if (name.isNotEmpty) _ownerCtrl.text = name;
      } else {
        for (final key in [
          'Patta Holder Name', 'Owner Name', 'Holder Name', 'Name',
        ]) {
          final val = fields[key]?.toString().trim() ?? '';
          if (val.isNotEmpty) { _ownerCtrl.text = val; break; }
        }
      }
    }

    // Fill land extent if the field is still empty
    if (_extentCtrl.text.trim().isEmpty) {
      for (final key in [
        'Total Extent', 'Survey Extent', 'Extent', 'Area', 'Land Area',
      ]) {
        final val = fields[key]?.toString().trim() ?? '';
        if (val.isNotEmpty) { _extentCtrl.text = val; break; }
      }
    }
  }

  // ── EC fetch ───────────────────────────────────────────────────────────────

  Future<void> _fetchEc() async {
    final surveyNo = _surveyCtrl.text.trim();
    if (_resolvedEcZone == null ||
        _resolvedEcDc == null ||
        _selectedEcSro == null ||
        surveyNo.isEmpty ||
        _ecFromCtrl.text.trim().isEmpty ||
        _ecToCtrl.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _fetchingEc = true;
      _ecError = null;
      _ecResult = null;
    });

    try {
      final params = StringBuffer('zone=$_resolvedEcZone')
        ..write('&dc=$_resolvedEcDc')
        ..write('&sro=$_selectedEcSro')
        ..write('&surveyNo=${Uri.encodeComponent(surveyNo)}')
        ..write('&subDiv=${Uri.encodeComponent(_subDivCtrl.text.trim())}')
        ..write('&fromDate=${Uri.encodeComponent(_ecFromCtrl.text.trim())}')
        ..write('&toDate=${Uri.encodeComponent(_ecToCtrl.text.trim())}');

      final result = await ApiClient.get('/api/tnlands/ec/search?$params');
      if (!mounted) return;
      setState(() {
        _ecResult = result;
        _fetchingEc = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _ecError = e.message;
        _fetchingEc = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ecError = e.toString().split(':').last.trim();
        _fetchingEc = false;
      });
    }
  }

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
      landExtent: _extentCtrl.text.trim(),
      ownerName: _ownerCtrl.text.trim(),
      contactDetails: _contactCtrl.text.trim(),
      landType: _landType,
      roadWidth: _roadWidthCtrl.text.trim(),
      accessDetails: _accessCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      addedOn: DateTime.now(),
    );

    Navigator.pop(context, lead);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  bool get _pattaReady =>
      _resolvedDc != null &&
      _resolvedTc != null &&
      _surveyCtrl.text.trim().isNotEmpty;

  bool get _ecReady =>
      _resolvedEcZone != null &&
      _resolvedEcDc != null &&
      _selectedEcSro != null &&
      _surveyCtrl.text.trim().isNotEmpty &&
      _ecFromCtrl.text.trim().isNotEmpty &&
      _ecToCtrl.text.trim().isNotEmpty;

  @override
  void didUpdateWidget(covariant AddLeadScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeAutoFetchRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('Add Land Lead'),
        actions: [
          TextButton(
            onPressed: _submit,
            child: const Text('SAVE',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Section 1: Input Source ──────────────────────────────
            const _SectionHeader(
              number: '1',
              title: 'Input Source',
              subtitle: 'Who brought this lead?',
            ),
            const SizedBox(height: 12),
            _InputSourceGrid(
              selected: _inputSource,
              onSelect: (s) => setState(() => _inputSource = s),
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

            const _ReadOnlyField(label: 'Lead ID', value: 'Auto-generated on save'),
            const SizedBox(height: 16),

            _LocationModeToggle(
              mode: _locationMode,
              onChanged: (m) => setState(() => _locationMode = m),
            ),
            const SizedBox(height: 14),

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
                  : 'e.g. 12.971600° N, 77.594600° E',
              icon: Icons.gps_fixed,
            ),
            const SizedBox(height: 12),

            _Field(
              ctrl: _locationCtrl,
              label: 'Location',
              hint: _locationMode == _LocationMode.live
                  ? 'Auto-filled after capture'
                  : 'e.g. Whitefield, Bangalore',
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

            // Survey No + Sub Division side by side
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
              required: true,
            ),
            const SizedBox(height: 12),

            _Field(
              ctrl: _contactCtrl,
              label: 'Contact Details',
              hint: 'Phone / Email',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              required: true,
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
            const SizedBox(height: 12),

            _Field(
              ctrl: _accessCtrl,
              label: 'Access Details',
              hint: 'Approach road, entry point…',
              icon: Icons.directions_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            _Field(
              ctrl: _notesCtrl,
              label: 'Notes',
              hint: 'Any additional observations',
              icon: Icons.notes_outlined,
              maxLines: 3,
            ),

            const SizedBox(height: 28),

            // ── Section 3: Land Records ──────────────────────────────
            const _SectionHeader(
              number: '3',
              title: 'Land Records',
              subtitle: 'Auto-fetch Patta & EC from TN portals',
            ),
            const SizedBox(height: 12),

            // Manual resolve button — works even when location was typed by hand
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: _resolvingCodes ||
                        (_districtCtrl.text.trim().isEmpty &&
                            _talukCtrl.text.trim().isEmpty &&
                            _villageCtrl.text.trim().isEmpty)
                    ? null
                    : () => _resolveLocationCodes(
                          _districtCtrl.text.trim(),
                          _talukCtrl.text.trim(),
                          _villageCtrl.text.trim(),
                        ),
                icon: _resolvingCodes
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.manage_search_outlined, size: 18),
                label: Text(_resolvingCodes
                    ? 'Resolving codes…'
                    : 'Resolve TN Land Codes'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Code resolution status banner
            if (_resolvingCodes || _codeStatusMsg != null) ...[
              _CodeStatusBanner(
                resolving: _resolvingCodes,
                message: _codeStatusMsg ?? 'Resolving TN land codes…',
                resolved: _codeStatusMsg != null && _codeStatusMsg!.contains('✓'),
              ),
              const SizedBox(height: 14),
            ],

            // ── Patta subsection ─────────────────────────────────────
            const _RecordSectionLabel(
              icon: Icons.article_outlined,
              title: 'Patta / Chitta',
              subtitle: 'eservices.tn.gov.in',
            ),
            const SizedBox(height: 8),

            if (!_pattaReady && _codeStatusMsg == null)
              const _HintText('Capture live location first, then fill survey number.')
            else if (!_pattaReady && _surveyCtrl.text.trim().isEmpty)
              const _HintText('Enter survey number above to enable fetch.')
            else if (!_pattaReady)
              const _HintText('Location codes not fully resolved — fetch may be incomplete.'),

            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed:
                    (_pattaReady && !_fetchingPatta) ? _fetchPatta : null,
                icon: _fetchingPatta
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.article_outlined),
                label: Text(_fetchingPatta
                    ? 'Fetching Patta…'
                    : 'Fetch Patta & FMB'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.25),
                  disabledForegroundColor: Colors.white54,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_pattaError != null) ...[
              const SizedBox(height: 8),
              _ErrorBanner(message: _pattaError!),
            ],
            if (_pattaResult != null) ...[
              const SizedBox(height: 12),
              _PattaResultCard(data: _pattaResult!),
            ],

            const SizedBox(height: 20),

            // ── EC subsection ────────────────────────────────────────
            const _RecordSectionLabel(
              icon: Icons.verified_outlined,
              title: 'Encumbrance Certificate (EC)',
              subtitle: 'tnreginet.gov.in',
            ),
            const SizedBox(height: 8),

            // SRO picker (auto-loaded after location resolution)
            if (_loadingEcSros) ...[
              const _HintText('Loading Sub-Registrar Offices…'),
              const SizedBox(height: 4),
              const LinearProgressIndicator(),
            ] else if (_ecSroList.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedEcSro,
                onChanged: (v) => setState(() => _selectedEcSro = v),
                decoration: InputDecoration(
                  labelText: 'Sub-Registrar Office (SRO)',
                  prefixIcon: const Icon(Icons.account_balance_outlined,
                      size: 20, color: AppColors.primary),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                ),
                items: _ecSroList
                    .map((s) => DropdownMenuItem(
                        value: s['code'] as String,
                        child: Text(s['name'] as String,
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
              ),
              const SizedBox(height: 10),
            ] else if (_resolvedEcDc == null) ...[
              const _HintText('Capture live location to auto-load SRO list.'),
              const SizedBox(height: 6),
            ] else ...[
              const _HintText('No SROs found for this location.'),
              const SizedBox(height: 6),
            ],

            // Date range
            Row(children: [
              Expanded(
                child: _DateField(
                  ctrl: _ecFromCtrl,
                  label: 'From Date',
                  onTap: () => _pickDate(_ecFromCtrl),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  ctrl: _ecToCtrl,
                  label: 'To Date',
                  onTap: () => _pickDate(_ecToCtrl),
                ),
              ),
            ]),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: (_ecReady && !_fetchingEc) ? _fetchEc : null,
                icon: _fetchingEc
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.verified_outlined),
                label: Text(_fetchingEc ? 'Fetching EC…' : 'Fetch EC'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.info.withValues(alpha: 0.25),
                  disabledForegroundColor: Colors.white54,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_ecError != null) ...[
              const SizedBox(height: 8),
              _ErrorBanner(message: _ecError!),
            ],
            if (_ecResult != null) ...[
              const SizedBox(height: 12),
              _EcResultCard(data: _ecResult!),
            ],

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Lead',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    DateTime? initial;
    try {
      final parts = ctrl.text.split('/');
      if (parts.length == 3) {
        initial = DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      ctrl.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }
}

// ── Code status banner ────────────────────────────────────────────────────────

class _CodeStatusBanner extends StatelessWidget {
  final bool resolving;
  final String message;
  final bool resolved;

  const _CodeStatusBanner({
    required this.resolving,
    required this.message,
    required this.resolved,
  });

  @override
  Widget build(BuildContext context) {
    final color = resolved
        ? AppColors.success
        : resolving
            ? AppColors.info
            : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        if (resolving)
          SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: color))
        else
          Icon(
              resolved
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              size: 16,
              color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: TextStyle(fontSize: 12, color: color)),
        ),
      ]),
    );
  }
}

// ── Record section label ──────────────────────────────────────────────────────

class _RecordSectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _RecordSectionLabel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppColors.primary, size: 17),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ]),
      ]);
}

// ── Hint text ─────────────────────────────────────────────────────────────────

class _HintText extends StatelessWidget {
  final String text;
  const _HintText(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      );
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.error),
          const SizedBox(width: 6),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.error))),
        ]),
      );
}

// ── Patta result card ─────────────────────────────────────────────────────────

class _PattaResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PattaResultCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final fields = (data['fields'] as Map<String, dynamic>?) ?? {};
    final owners = (data['owners'] as List<dynamic>?) ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.check_circle_outline,
              color: AppColors.success, size: 18),
          const SizedBox(width: 6),
          const Expanded(
            child: Text('Patta Record Found',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.success)),
          ),
          Text(data['source'] as String? ?? '',
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ]),
        if (fields.isNotEmpty) ...[
          const Divider(height: 16),
          ...fields.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 130,
                          child: Text(e.key,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary))),
                      Expanded(
                          child: Text(e.value.toString(),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500))),
                    ]),
              )),
        ],
        if (owners.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Owners',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          ...owners.map((o) {
            final owner = o as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                  owner.values
                      .where((v) => v.toString().isNotEmpty)
                      .join('  —  '),
                  style: const TextStyle(fontSize: 11)),
            );
          }),
        ],
      ]),
    );
  }
}

// ── EC result card ────────────────────────────────────────────────────────────

class _EcResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _EcResultCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final records = (data['records'] as List<dynamic>?) ?? [];
    final count = data['count'] as int? ?? records.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.verified_outlined,
              color: AppColors.info, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text('$count EC Record${count == 1 ? '' : 's'} Found',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.info)),
          ),
          Text(data['source'] as String? ?? '',
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ]),
        if (records.isNotEmpty) ...[
          const Divider(height: 16),
          ...records.take(5).map((r) {
            final rec = r as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: rec.entries
                        .where((e) => e.value.toString().isNotEmpty)
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                        width: 110,
                                        child: Text(e.key,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color:
                                                    AppColors.textSecondary))),
                                    Expanded(
                                        child: Text(e.value.toString(),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.w500))),
                                  ]),
                            ))
                        .toList()),
              ),
            );
          }),
          if (records.length > 5)
            Text('+${records.length - 5} more records',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
        ],
      ]),
    );
  }
}

// ── Date field ────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final VoidCallback onTap;

  const _DateField({
    required this.ctrl,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'DD/MM/YYYY',
        prefixIcon: const Icon(Icons.calendar_today_outlined,
            size: 18, color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
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
        color: const Color(0xFFE8EEF8),
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
                  color: active ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.normal,
                      color: active
                          ? Colors.white
                          : AppColors.textSecondary)),
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
                      'Auto-fills GPS, location, village, taluk & district',
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
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
            color: AppColors.primary, shape: BoxShape.circle),
        child: Center(
          child: Text(number,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        Text(subtitle,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ]),
    ]);
  }
}

// ── Input Source Grid (MCQ) ─────────────────────────────────────────────────

class _InputSourceGrid extends StatelessWidget {
  final InputSource? selected;
  final ValueChanged<InputSource> onSelect;

  static const _options = [
    (InputSource.broker, Icons.handshake_outlined, 'Broker'),
    (InputSource.landowner, Icons.person_pin_outlined, 'Landowner'),
    (InputSource.referral, Icons.group_outlined, 'Referral'),
    (InputSource.internalTeam, Icons.business_center_outlined, 'Internal Team'),
    (InputSource.existingDatabase, Icons.storage_outlined, 'Existing Database'),
  ];

  const _InputSourceGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _options.map((opt) {
        final isSelected = selected == opt.$1;
        return GestureDetector(
          onTap: () => onSelect(opt.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : const Color(0xFFE0E0E0),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: isSelected ? 0.12 : 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(opt.$2,
                  size: 20,
                  color: isSelected
                      ? AppColors.accentLight
                      : AppColors.primary),
              const SizedBox(width: 8),
              Text(opt.$3,
                  style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 13)),
            ]),
          ),
        );
      }).toList(),
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
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
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
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.error)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      decoration: InputDecoration(
        labelText: 'Land Type *',
        prefixIcon: const Icon(Icons.terrain_outlined,
            size: 20, color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: LandType.values
          .map((t) =>
              DropdownMenuItem(value: t, child: Text(t.label)))
          .toList(),
    );
  }
}
