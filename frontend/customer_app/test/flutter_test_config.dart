import 'dart:async';
import 'package:cuu_ho_247/widgets/rescue_location_map.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Deterministic tiles for every widget test; never calls a public OSM server.
class TestMapTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  RescueLocationMap.tileProviderFactory = TestMapTileProvider.new;
  await testMain();
}
