typedef Json = Map<String, dynamic>;

class RescuerSnapshot {
  const RescuerSnapshot({
    this.profile,
    this.vehicles = const [],
    this.capabilities = const [],
    this.documents = const [],
    this.online,
    this.location,
    this.services = const [],
  });
  final Json? profile;
  final List<Json> vehicles;
  final List<Json> capabilities;
  final List<Json> documents;
  final Json? online;
  final Json? location;
  final List<Json> services;
  bool documentReady(Json d) {
    final expires = d['expires_at'] == null
        ? null
        : DateTime.tryParse(d['expires_at'] as String);
    return d['uploaded_at'] != null &&
        ['submitted', 'approved'].contains(d['verification_status']) &&
        (d['expires_at'] == null ||
            (expires != null && expires.isAfter(DateTime.now().toUtc())));
  }

  bool get documentsReady =>
      ['identity', 'license'].every(
        (type) => documents.any(
          (d) => d['document_type'] == type && documentReady(d),
        ),
      ) &&
      vehicles.any(
        (v) =>
            v['is_active'] == true &&
            documents.any(
              (d) =>
                  d['vehicle_id'] == v['id'] &&
                  d['document_type'] == 'vehicle_registration' &&
                  documentReady(d),
            ),
      );
  bool get approved => profile?['verification_status'] == 'approved';
  List<Json> get eligibleVehicles => vehicles
      .where(
        (v) =>
            v['verification_status'] == 'approved' &&
            v['is_active'] == true &&
            capabilities.any(
              (c) =>
                  c['vehicle_id'] == v['id'] &&
                  c['verification_status'] == 'approved' &&
                  c['is_enabled'] == true,
            ),
      )
      .toList();
  bool get canSubmit {
    if (!['draft', 'rejected'].contains(profile?['verification_status'])) {
      return false;
    }
    bool valid(Json d) => documentReady(d);
    return ['identity', 'license'].every(
          (kind) =>
              documents.any((d) => d['document_type'] == kind && valid(d)),
        ) &&
        vehicles.any(
          (v) =>
              v['is_active'] == true &&
              [
                'draft',
                'submitted',
                'approved',
              ].contains(v['verification_status']) &&
              documents.any(
                (d) =>
                    d['vehicle_id'] == v['id'] &&
                    d['document_type'] == 'vehicle_registration' &&
                    valid(d),
              ),
        );
  }
}

/// Deliberately stores only the pre-claim projection, even if the server sends extras.
class AvailableRequest {
  const AvailableRequest({
    required this.id,
    required this.service,
    required this.vehicle,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
  });
  factory AvailableRequest.fromJson(Json json) {
    final coarse = Map<String, dynamic>.from(
      json['approximate_location'] as Map,
    );
    if (coarse['precision'] != 'coarse' ||
        (coarse['cell_size_degrees'] as num) < 0.01) {
      throw const FormatException('Invalid coarse location');
    }
    return AvailableRequest(
      id: json['request_id'] as String,
      service: json['service_type'] as String,
      vehicle: json['vehicle_type'] as String,
      latitude: (coarse['latitude'] as num).toDouble(),
      longitude: (coarse['longitude'] as num).toDouble(),
      distanceKm: (json['estimated_distance_km'] as num).toInt(),
    );
  }
  final String id, service, vehicle;
  final double latitude, longitude;
  final int distanceKm;
}

class RequestPage {
  const RequestPage(this.items, this.cursor);
  final List<AvailableRequest> items;
  final Json? cursor;
}

class JobAssignment {
  const JobAssignment({
    required this.id,
    required this.requestId,
    required this.vehicleId,
    required this.state,
    required this.version,
    this.acceptedAt,
  });
  factory JobAssignment.fromJson(Json json) => JobAssignment(
    id: json['assignment_id'] as String,
    requestId: json['request_id'] as String,
    vehicleId: json['vehicle_id'] as String,
    state: json['state'] as String,
    version: (json['version'] as num).toInt(),
    acceptedAt: DateTime.tryParse(json['accepted_at'] as String? ?? ''),
  );
  final String id, requestId, vehicleId, state;
  final int version;
  final DateTime? acceptedAt;
  bool get isActive =>
      ['accepted', 'en_route', 'arrived', 'in_progress'].contains(state);
}

/// Only populated from the authenticated active-job RPC, never discovery.
class ActiveJob {
  const ActiveJob({
    required this.assignment,
    this.service,
    this.vehicle,
    this.contactName,
    this.contactPhone,
    this.address,
    this.description,
    this.latitude,
    this.longitude,
  });
  factory ActiveJob.fromJson(Json json) => ActiveJob(
    assignment: JobAssignment.fromJson(json),
    service: json['service_type'] as String?,
    vehicle: json['vehicle_type'] as String?,
    contactName: json['contact_name'] as String?,
    contactPhone: json['contact_phone'] as String?,
    address: json['location_text'] as String?,
    description: json['description'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );
  final JobAssignment assignment;
  final String? service,
      vehicle,
      contactName,
      contactPhone,
      address,
      description;
  final double? latitude, longitude;
}

class LocationSample {
  const LocationSample(
    this.latitude,
    this.longitude,
    this.accuracy,
    this.capturedAt,
  );
  final double latitude, longitude, accuracy;
  final DateTime capturedAt;
}

class RescuerFailure implements Exception {
  const RescuerFailure(this.message);
  final String message;
}

enum LocationHelp { permission, disabled, precision }

class LocationFailure extends RescuerFailure {
  const LocationFailure(super.message, this.help);
  final LocationHelp help;
}

class ReadinessItem {
  const ReadinessItem(this.title, this.detail, this.complete, this.section);
  final String title, detail, section;
  final bool complete;
}
