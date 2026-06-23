import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../models/site_verification.dart';
import '../../theme/app_theme.dart';

class AddSiteVerificationScreen extends StatefulWidget {
  final String? pendingId;
  final String? prefillLeadRef;
  final String? prefillGps;
  final String? prefillAddress;
  final String? prefillRoadAccess;
  final String? prefillPincode;

  const AddSiteVerificationScreen({
    super.key,
    this.pendingId,
    this.prefillLeadRef,
    this.prefillGps,
    this.prefillAddress,
    this.prefillRoadAccess,
    this.prefillPincode,
  });

  @override
  State<AddSiteVerificationScreen> createState() =>
      _AddSiteVerificationScreenState();
}

class _AddSiteVerificationScreenState
    extends State<AddSiteVerificationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _leadRefCtrl = TextEditingController();
  final _gpsCtrl = TextEditingController();
  final _geoAddressCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _roadAccessCtrl = TextEditingController();
  final _landmarksCtrl = TextEditingController();
  final _observationsCtrl = TextEditingController();

  bool _fetchingLocation = false;
  String? _locationStatus;

  final List<PhotoAttachment> _photos = [];
  VideoAttachment? _video;

  @override
  void initState() {
    super.initState();
    if (widget.prefillLeadRef != null) _leadRefCtrl.text = widget.prefillLeadRef!;
    if (widget.prefillGps != null) _gpsCtrl.text = widget.prefillGps!;
    if (widget.prefillAddress != null) _geoAddressCtrl.text = widget.prefillAddress!;
    if (widget.prefillRoadAccess != null) _roadAccessCtrl.text = widget.prefillRoadAccess!;
    if (widget.prefillPincode != null) _pincodeCtrl.text = widget.prefillPincode!;
  }

  @override
  void dispose() {
    for (final c in [
      _leadRefCtrl, _gpsCtrl, _geoAddressCtrl, _pincodeCtrl,
      _roadAccessCtrl, _landmarksCtrl, _observationsCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Geo-location ───────────────────────────────────────────────────────────

  Future<void> _fetchLiveLocation() async {
    setState(() {
      _fetchingLocation = true;
      _locationStatus = 'Requesting permission…';
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setStatus('Location permission denied. Enable it in browser settings.');
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
      final response = await http.get(uri,
          headers: {
            'Accept-Language': 'en',
            'User-Agent': 'FomraLS/1.0 (in.fomrahousing)',
          });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final location = _first(addr, [
          'suburb', 'neighbourhood', 'quarter', 'town', 'village', 'city',
        ]);
        _geoAddressCtrl.text = location.isNotEmpty
            ? location
            : (data['display_name'] as String? ?? '');

        // Pincode
        final postcode = addr['postcode'] as String? ?? '';
        if (postcode.isNotEmpty) _pincodeCtrl.text = postcode;

        _setStatus('Location captured ✓');
      } else {
        _setStatus('GPS saved — address lookup failed.');
      }
    } on LocationServiceDisabledException {
      _setStatus('Location services disabled. Enable in browser settings.');
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

  Future<void> _pickPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;

    final oversized = <String>[];
    final valid = <PhotoAttachment>[];

    for (final f in result.files) {
      if (f.size > 1 * 1024 * 1024) {
        oversized.add('${f.name} (${_sizeLabel(f.size)})');
      } else {
        valid.add(PhotoAttachment(
          name: f.name,
          sizeBytes: f.size,
          previewBytes: f.bytes,
        ));
      }
    }

    if (oversized.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${oversized.length} photo(s) over 1 MB skipped:\n${oversized.join(', ')}'),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 4),
      ));
    }

    if (valid.isNotEmpty) setState(() => _photos.addAll(valid));
  }

  // ── Video picker ───────────────────────────────────────────────────────────

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final f = result.files.first;
    if (f.size > 20 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Video exceeds 20 MB limit. Choose a smaller file.'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }

    setState(() =>
        _video = VideoAttachment(name: f.name, sizeBytes: f.size));
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_gpsCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please capture the geo-location before saving.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final sv = SiteVerification(
      id: widget.pendingId ?? SiteVerification.generateId(),
      leadReference: _leadRefCtrl.text.trim(),
      geoCoordinates: _gpsCtrl.text.trim(),
      geoAddress: _geoAddressCtrl.text.trim(),
      pincode: _pincodeCtrl.text.trim(),
      photographs: List.from(_photos),
      video: _video,
      roadAccess: _roadAccessCtrl.text.trim(),
      nearbyLandmarks: _landmarksCtrl.text.trim(),
      siteObservations: _observationsCtrl.text.trim(),
      capturedOn: DateTime.now(),
    );

    Navigator.pop(context, sv);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
        title: const Text('Site Capture'),
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
            // ── Lead Reference ─────────────────────────────────────
            const _SectionLabel(icon: Icons.link, title: 'Lead Reference'),
            const SizedBox(height: 10),
            _Field(
              ctrl: _leadRefCtrl,
              label: 'Lead ID / Reference',
              hint: 'e.g. LL-202601XXXX  (optional)',
              icon: Icons.tag,
            ),

            const SizedBox(height: 24),

            // ── Geo-location ───────────────────────────────────────
            const _SectionLabel(icon: Icons.gps_fixed, title: 'Geo-Location'),
            const SizedBox(height: 10),
            _LiveLocationButton(
              fetching: _fetchingLocation,
              status: _locationStatus,
              onTap: _fetchingLocation ? null : _fetchLiveLocation,
            ),
            const SizedBox(height: 10),
            _Field(
              ctrl: _gpsCtrl,
              label: 'GPS Coordinates',
              hint: 'Auto-filled by Live Location',
              icon: Icons.my_location,
            ),
            const SizedBox(height: 10),
            _Field(
              ctrl: _geoAddressCtrl,
              label: 'Location Address',
              hint: 'Auto-filled by Live Location',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 10),
            _Field(
              ctrl: _pincodeCtrl,
              label: 'Pincode',
              hint: 'Auto-filled or type manually',
              icon: Icons.local_post_office_outlined,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 24),

            // ── Photographs ────────────────────────────────────────
            const _SectionLabel(icon: Icons.photo_camera_outlined, title: 'Photographs'),
            const SizedBox(height: 6),
            Text('Max 1 MB per photo · JPEG, PNG, WEBP',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.8))),
            const SizedBox(height: 10),
            _PhotosSection(
              photos: _photos,
              onPick: _pickPhotos,
              onRemove: (i) => setState(() => _photos.removeAt(i)),
            ),

            const SizedBox(height: 24),

            // ── Video ──────────────────────────────────────────────
            const _SectionLabel(icon: Icons.videocam_outlined, title: 'Video'),
            const SizedBox(height: 6),
            Text('Max 20 MB · MP4, MOV, AVI',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.8))),
            const SizedBox(height: 10),
            _VideoSection(
              video: _video,
              onPick: _pickVideo,
              onRemove: () => setState(() => _video = null),
            ),

            const SizedBox(height: 24),

            // ── Fill-up Fields ─────────────────────────────────────
            const _SectionLabel(icon: Icons.edit_note_outlined, title: 'Site Details'),
            const SizedBox(height: 10),

            _Field(
              ctrl: _roadAccessCtrl,
              label: 'Road Access',
              hint: 'Describe road condition, width, type…',
              icon: Icons.add_road,
              maxLines: 2,
              required: true,
            ),
            const SizedBox(height: 12),

            _Field(
              ctrl: _landmarksCtrl,
              label: 'Nearby Landmarks',
              hint: 'Schools, hospitals, junctions, water bodies…',
              icon: Icons.place_outlined,
              maxLines: 2,
              required: true,
            ),
            const SizedBox(height: 12),

            _Field(
              ctrl: _observationsCtrl,
              label: 'Site Observations',
              hint:
                  'Overall condition, soil type, encroachments, utilities available…',
              icon: Icons.notes_outlined,
              maxLines: 4,
              required: true,
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Verification',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
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

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionLabel({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
      ]);
}

// ── Live Location Button ──────────────────────────────────────────────────────

class _LiveLocationButton extends StatelessWidget {
  final bool fetching;
  final String? status;
  final VoidCallback? onTap;
  const _LiveLocationButton(
      {required this.fetching, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final filled = status != null && status!.contains('✓');
    return Material(
      color: filled
          ? AppColors.success.withValues(alpha: 0.08)
          : AppColors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  shape: BoxShape.circle),
              child: fetching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Icon(
                      filled ? Icons.location_on : Icons.my_location,
                      color: Colors.white,
                      size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fetching ? 'Capturing location…' : 'Capture Live Location',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: filled
                              ? AppColors.success
                              : AppColors.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status ??
                          'Auto-fills GPS coordinates and address',
                      style: TextStyle(
                          fontSize: 11,
                          color: filled
                              ? AppColors.success
                              : AppColors.textSecondary),
                    ),
                  ]),
            ),
            if (!fetching)
              Icon(
                filled ? Icons.check_circle : Icons.chevron_right,
                color:
                    filled ? AppColors.success : AppColors.textSecondary,
              ),
          ]),
        ),
      ),
    );
  }
}

// ── Photos Section ────────────────────────────────────────────────────────────

class _PhotosSection extends StatelessWidget {
  final List<PhotoAttachment> photos;
  final VoidCallback onPick;
  final void Function(int index) onRemove;

  const _PhotosSection({
    required this.photos,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Pick button
      OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(photos.isEmpty ? 'Add Photos' : 'Add More Photos'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      if (photos.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('${photos.length} photo(s) added',
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: photos.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            return _PhotoCard(photo: p, onRemove: () => onRemove(i));
          }).toList(),
        ),
      ],
    ]);
  }
}

class _PhotoCard extends StatelessWidget {
  final PhotoAttachment photo;
  final VoidCallback onRemove;
  const _PhotoCard({required this.photo, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        clipBehavior: Clip.hardEdge,
        child: photo.previewBytes != null
            ? Image.memory(photo.previewBytes!,
                fit: BoxFit.cover,
                width: 100,
                height: 100)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_outlined,
                      color: AppColors.primary, size: 28),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(photo.name,
                        style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center),
                  ),
                ],
              ),
      ),
      // Size badge
      Positioned(
        bottom: 4,
        left: 4,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4)),
          child: Text(photo.sizeLabel,
              style:
                  const TextStyle(color: Colors.white, fontSize: 9)),
        ),
      ),
      // Remove button
      Positioned(
        top: 2,
        right: 2,
        child: GestureDetector(
          onTap: onRemove,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
                color: AppColors.error, shape: BoxShape.circle),
            child: const Icon(Icons.close,
                color: Colors.white, size: 14),
          ),
        ),
      ),
    ]);
  }
}

// ── Video Section ─────────────────────────────────────────────────────────────

class _VideoSection extends StatelessWidget {
  final VideoAttachment? video;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _VideoSection({
    required this.video,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (video == null) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.video_call_outlined),
        label: const Text('Add Video'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6)
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.videocam,
              color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(video!.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(video!.sizeLabel,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ]),
        ),
        TextButton(
            onPressed: onPick,
            child: const Text('Change',
                style: TextStyle(fontSize: 12))),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: onRemove,
          tooltip: 'Remove video',
          iconSize: 20,
        ),
      ]),
    );
  }
}

// ── Text field ────────────────────────────────────────────────────────────────

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

// ── helpers ───────────────────────────────────────────────────────────────────

String _sizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
