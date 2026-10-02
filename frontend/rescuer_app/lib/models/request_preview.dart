/// Only the fields allowed before a rescuer accepts a request.
class RequestPreview {
  const RequestPreview({
    this.serviceType,
    this.vehicleType,
    this.approximateLocation,
    this.estimatedDistanceKm,
  });

  final String? serviceType;
  final String? vehicleType;
  final String? approximateLocation;
  final double? estimatedDistanceKm;

  bool get hasData =>
      serviceType != null ||
      vehicleType != null ||
      approximateLocation != null ||
      estimatedDistanceKm != null;
}
