import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:fomra_ls/widgets/add_lead_ui.dart';

const _captured = LatLng(13.0827, 80.2707);

Future<void> _pump(
  WidgetTester tester, {
  required LatLng? pinnedPoint,
  Future<void> Function(LatLng)? onTap,
  Future<void> Function()? onMyLocation,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final widget = MaterialApp(
    home: Scaffold(
      body: AddLeadMapPicker(
        mapController: MapController(),
        defaultCenter: const LatLng(13.0827, 80.2707),
        pinnedPoint: pinnedPoint,
        resolving: false,
        onMapReady: () {},
        onTap: onTap,
        onMyLocation: onMyLocation,
      ),
    ),
  );

  // The tile layer fetches map tiles over the network, which leaves real
  // pending timers a plain pump() would trip over. runAsync lets them settle —
  // the tiles themselves don't matter here, the pin and the options do.
  await tester.runAsync(() async {
    await tester.pumpWidget(widget);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pump();
}

void main() {
  testWidgets('read-only: the map renders a pin at the captured point',
      (tester) async {
    await _pump(tester, pinnedPoint: _captured);
    expect(tester.takeException(), isNull);

    expect(find.byType(FlutterMap), findsOneWidget);

    // Exactly one marker, at the captured coordinates.
    final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(markerLayer.markers, hasLength(1));
    expect(markerLayer.markers.single.point, _captured);
  });

  testWidgets('read-only: tapping the map cannot move the pin', (tester) async {
    await _pump(tester, pinnedPoint: _captured);
    expect(tester.takeException(), isNull);

    // No tap handler at all — live GPS is the only way to set the pin.
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.onTap, isNull);
  });

  testWidgets('read-only: no "My Location" button and no tap hint',
      (tester) async {
    await _pump(tester, pinnedPoint: _captured);
    expect(tester.takeException(), isNull);

    expect(find.text('My Location'), findsNothing);
    expect(
      find.textContaining('Tap the map to drop a pin'),
      findsNothing,
      reason: 'the hint would be a lie when taps are ignored',
    );
  });

  testWidgets('read-only: still pans and zooms', (tester) async {
    await _pump(tester, pinnedPoint: _captured);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.interactionOptions.flags & InteractiveFlag.drag,
        isNot(0));
  });

  testWidgets('centres on the pin at a street-level zoom', (tester) async {
    await _pump(tester, pinnedPoint: _captured);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));

    expect(map.options.initialCenter, _captured);
    expect(map.options.initialZoom, 16);
    expect(map.options.initialZoom, inInclusiveRange(16, 18));
  });

  testWidgets('no pin means no marker to show', (tester) async {
    await _pump(tester, pinnedPoint: null);
    expect(tester.takeException(), isNull);
    expect(find.byType(MarkerLayer), findsNothing);
  });

  testWidgets('the picker mode still offers tap-to-pin and My Location',
      (tester) async {
    await _pump(
      tester,
      pinnedPoint: null,
      onTap: (_) async {},
      onMyLocation: () async {},
    );
    expect(tester.takeException(), isNull);

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.onTap, isNotNull);
    expect(find.text('My Location'), findsOneWidget);
    expect(find.textContaining('Tap the map to drop a pin'), findsOneWidget);
  });
}
