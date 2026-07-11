import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:fomra_ls/utils/lead_location_parser.dart';

void main() {
  group('parseLeadGps', () {
    test('parses DMS with seconds', () {
      final p = parseLeadGps('13°07\'08.7"N 80°16\'53.0"E');
      expect(p, isNotNull);
      expect(p!.latitude, closeTo(13.119083, 0.0001));
      expect(p.longitude, closeTo(80.281389, 0.0001));
    });

    test('parses decimal with N/E labels', () {
      final p = parseLeadGps('13.119083° N, 80.281389° E');
      expect(p, isNotNull);
      expect(p!.latitude, closeTo(13.119083, 0.000001));
      expect(p.longitude, closeTo(80.281389, 0.000001));
    });

    test('parses plain decimal pair', () {
      final p = parseLeadGps('13.119083, 80.281389');
      expect(p, isNotNull);
      expect(p!.latitude, closeTo(13.119083, 0.000001));
      expect(p.longitude, closeTo(80.281389, 0.000001));
    });

    test('does not mis-parse DMS as wrong decimal', () {
      final p = parseLeadGps('13°07\'08.7"N 80°16\'53.0"E');
      expect(p, isNotNull);
      expect(p!.latitude, isNot(closeTo(8.7, 0.1)));
      expect(p.latitude, greaterThan(13.0));
    });

    test('returns null for garbage', () {
      expect(parseLeadGps('not coordinates'), isNull);
    });
  });

  group('formatLeadGps', () {
    test('formats decimal degrees', () {
      expect(
        formatLeadGps(13.119083, 80.281389),
        '13.119083° N, 80.281389° E',
      );
    });
  });
}
