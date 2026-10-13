import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuu_ho_247/widgets/rescue_location_map.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';

/// UI suites have no device GPS. GPS-specific tests inject their own platform.
class TestDeniedGps extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;
}

/// Deterministic tiles for every widget test; never calls a public OSM server.
class TestMapTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  RescueLocationMap.tileProviderFactory = TestMapTileProvider.new;
  TestWidgetsFlutterBinding.ensureInitialized();
  GeolocatorPlatform.instance = TestDeniedGps();
  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final bytes =
        await File('assets/fonts/plus_jakarta_sans/PlusJakartaSans.ttf')
            .readAsBytes();
    await (FontLoader('Plus Jakarta Sans')
          ..addFont(Future.value(ByteData.sublistView(bytes))))
        .load();
  });
  await testMain();
}
