import 'dart:typed_data';

enum VerificationStatus { scheduled, inProgress, completed, failed }

class PhotoAttachment {
  final String name;
  final int sizeBytes;
  final Uint8List? previewBytes;

  PhotoAttachment({
    required this.name,
    required this.sizeBytes,
    this.previewBytes,
  });

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class VideoAttachment {
  final String name;
  final int sizeBytes;

  VideoAttachment({required this.name, required this.sizeBytes});

  String get sizeLabel {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class SiteVerification {
  final String id;
  final String leadReference;
  final String geoCoordinates;
  final String geoAddress;
  final String pincode;
  final List<PhotoAttachment> photographs;
  final VideoAttachment? video;
  final String roadAccess;
  final String nearbyLandmarks;
  final String siteObservations;
  final DateTime capturedOn;
  VerificationStatus status;

  SiteVerification({
    required this.id,
    required this.leadReference,
    required this.geoCoordinates,
    required this.geoAddress,
    required this.pincode,
    required this.photographs,
    this.video,
    required this.roadAccess,
    required this.nearbyLandmarks,
    required this.siteObservations,
    required this.capturedOn,
    this.status = VerificationStatus.completed,
  });

  static String generateId() {
    final now = DateTime.now();
    final seq =
        (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return 'SV-${now.year}${now.month.toString().padLeft(2, '0')}$seq';
  }
}

extension VerificationStatusLabel on VerificationStatus {
  String get label => switch (this) {
        VerificationStatus.scheduled => 'Scheduled',
        VerificationStatus.inProgress => 'In Progress',
        VerificationStatus.completed => 'Completed',
        VerificationStatus.failed => 'Failed',
      };
}
