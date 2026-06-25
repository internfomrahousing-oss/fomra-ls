import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../models/land_lead.dart';
import '../../theme/app_theme.dart';

enum _LocationMode { manual, live }

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
  String? _locationStatus;

  // Terms
  String? _termsType;

  // Photo
  Uint8List? _photoBytes;
  String?    _photoName;

  @override
  void dispose() {
    for (final c in [
      _locationCtrl, _gpsCtrl, _villageCtrl, _talukCtrl, _districtCtrl,
      _pincodeCtrl, _surveyCtrl, _subDivCtrl, _extentCtrl, _ownerCtrl,
      _contactCtrl, _roadWidthCtrl, _notesCtrl,
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

  // ── Photo picker ───────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes != null) {
      setState(() {
        _photoBytes = file.bytes;
        _photoName  = file.name;
      });
    }
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
      landExtent: _extentCtrl.text.trim(),
      ownerName: _ownerCtrl.text.trim(),
      contactDetails: _contactCtrl.text.trim(),
      landType: _landType,
      roadWidth: _roadWidthCtrl.text.trim(),
      accessDetails: _termsType ?? '',
      notes: combinedNotes,
      addedOn: DateTime.now(),
    );

    Navigator.pop(context, lead);
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
              title: 'Site Photo',
              subtitle: 'Upload a photo of the land',
            ),
            const SizedBox(height: 14),

            _PhotoUpload(
              photoBytes: _photoBytes,
              photoName:  _photoName,
              onPick:     _pickPhoto,
              onRemove:   () => setState(() {
                _photoBytes = null;
                _photoName  = null;
              }),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Lead',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      decoration: InputDecoration(
        labelText: 'Terms',
        hintText: 'Select deal terms',
        prefixIcon: const Icon(Icons.handshake_outlined,
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
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: _kTermsOptions
          .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$1)))
          .toList(),
    );
  }
}


// ── Photo Upload ────────────────────────────────────────────────────────────

class _PhotoUpload extends StatelessWidget {
  final Uint8List? photoBytes;
  final String?    photoName;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _PhotoUpload({
    required this.photoBytes,
    required this.photoName,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (photoBytes != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                photoBytes!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
          ]),
          if (photoName != null) ...[
            const SizedBox(height: 6),
            Text(photoName!,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Replace Photo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1.5,
              style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_a_photo_outlined,
                  color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 10),
            const Text('Tap to upload site photo',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const SizedBox(height: 3),
            const Text('JPG, PNG supported',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
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
