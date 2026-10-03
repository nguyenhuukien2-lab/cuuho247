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
    this.enRouteAt,
    this.arrivedAt,
    this.inProgressAt,
    this.completedAt,
    this.cancelledAt,
    this.currentQuoteId,
    this.completionQuoteId,
    this.totalVnd,
    this.currency,
  });
  factory JobAssignment.fromJson(Json json) => JobAssignment(
    id: json['assignment_id'] as String,
    requestId: json['request_id'] as String,
    vehicleId: json['vehicle_id'] as String,
    state: json['state'] as String,
    version: (json['version'] as num).toInt(),
    acceptedAt: DateTime.tryParse(json['accepted_at'] as String? ?? ''),
    enRouteAt: DateTime.tryParse(json['en_route_at'] as String? ?? ''),
    arrivedAt: DateTime.tryParse(json['arrived_at'] as String? ?? ''),
    inProgressAt: DateTime.tryParse(json['in_progress_at'] as String? ?? ''),
    completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
    cancelledAt: DateTime.tryParse(json['cancelled_at'] as String? ?? ''),
    currentQuoteId: json['current_quote_id'] as String?,
    completionQuoteId: json['completion_quote_id'] as String?,
    totalVnd: (json['total_vnd'] as num?)?.toInt(),
    currency: json['currency'] as String?,
  );
  final String id, requestId, vehicleId, state;
  final int version;
  final DateTime? acceptedAt, enRouteAt, arrivedAt, inProgressAt;
  final DateTime? completedAt, cancelledAt;
  final String? currentQuoteId, completionQuoteId, currency;
  final int? totalVnd;
  bool get hasQuote =>
      currentQuoteId != null && totalVnd != null && totalVnd! >= 0;
  static const progressStates = [
    'accepted',
    'en_route',
    'arrived',
    'in_progress',
  ];
  String? get nextState => switch (state) {
    'accepted' => 'en_route',
    'en_route' => 'arrived',
    'arrived' => 'in_progress',
    _ => null,
  };
  String? get nextActionLabel => switch (state) {
    'accepted' => 'Đang đến điểm cứu hộ',
    'en_route' => 'Đã đến nơi',
    'arrived' => 'Bắt đầu hỗ trợ',
    _ => null,
  };
  String get stateLabel => switch (state) {
    'accepted' => 'Đã nhận đơn',
    'en_route' => 'Đang đến điểm cứu hộ',
    'arrived' => 'Đã đến nơi',
    'in_progress' => 'Đang hỗ trợ khách',
    'completed' => 'Đã hoàn tất',
    'cancelled' => 'Đã hủy',
    _ => 'Chuyến không còn đang xử lý',
  };
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

class QuoteDetails {
  const QuoteDetails({
    required this.id,
    required this.assignmentId,
    required this.totalVnd,
    required this.status,
    this.currency,
    this.items = const [],
    this.note,
    this.issuedAt,
  });
  factory QuoteDetails.fromJson(Json j) => QuoteDetails(
    id: j['quote_id'] as String,
    assignmentId: j['assignment_id'] as String,
    totalVnd: (j['total_vnd'] as num).toInt(),
    status: j['status'] as String,
    currency: j['currency'] as String?,
    note: j['note'] as String?,
    issuedAt: DateTime.tryParse(j['issued_at'] as String? ?? ''),
    items: (j['items'] as List? ?? [])
        .map((r) => QuoteItem.fromJson(Json.from(r as Map)))
        .toList(),
  );
  final String id, assignmentId, status;
  final int totalVnd;
  final String? currency, note;
  final List<QuoteItem> items;
  final DateTime? issuedAt;
}

class QuoteItem {
  const QuoteItem(this.serviceCode, this.quantity, this.unitPriceVnd);
  factory QuoteItem.fromJson(Json j) => QuoteItem(
    j['service_code'] as String,
    (j['quantity'] as num).toInt(),
    (j['unit_price_vnd'] as num).toInt(),
  );
  final String serviceCode;
  final int quantity, unitPriceVnd;
}

class QuoteDraft {
  const QuoteDraft(this.mainFee, this.surcharge, this.note);
  static const maxVnd = 2147483647;
  factory QuoteDraft.parse(String main, String extra, String note) {
    int amount(String raw, {bool optional = false}) {
      final s = raw.trim();
      if (optional && s.isEmpty) return 0;
      if (!RegExp(r'^\d+$').hasMatch(s)) {
        throw const RescuerFailure(
          'Nhập số tiền nguyên từ 0 trở lên, không có dấu phân cách.',
        );
      }
      final n = int.tryParse(s);
      if (n == null || n > maxVnd) {
        throw const RescuerFailure('Số tiền vượt giới hạn hệ thống.');
      }
      return n;
    }

    final a = amount(main), b = amount(extra, optional: true);
    if (a + b > maxVnd) {
      throw const RescuerFailure('Tổng tiền vượt giới hạn hệ thống.');
    }
    if (note.trim().length > 1000) {
      throw const RescuerFailure('Ghi chú tối đa 1.000 ký tự.');
    }
    return QuoteDraft(a, b, note.trim());
  }
  final int mainFee, surcharge;
  final String note;
  int get total => mainFee + surcharge;
  List<Json> items(String service) => [
    {'service_code': service, 'quantity': 1, 'unit_price_vnd': mainFee},
    if (surcharge > 0)
      {'service_code': service, 'quantity': 1, 'unit_price_vnd': surcharge},
  ];
}

/// Historical DTO deliberately excludes customer contact/address/free text.
class HistoryJob {
  const HistoryJob(this.assignment, this.service, this.vehicle, this.events);
  factory HistoryJob.fromJson(Json j) {
    final a = JobAssignment.fromJson(j);
    if (!['completed', 'cancelled'].contains(a.state)) {
      throw const FormatException('Not a historical job');
    }
    return HistoryJob(
      a,
      j['service_type'] as String?,
      j['vehicle_type'] as String?,
      (j['events'] as List? ?? [])
          .map((r) => HistoryEvent.fromJson(Json.from(r as Map)))
          .toList(),
    );
  }
  final JobAssignment assignment;
  final String? service, vehicle;
  final List<HistoryEvent> events;
}

class HistoryEvent {
  const HistoryEvent(this.state, this.occurredAt);
  factory HistoryEvent.fromJson(Json j) => HistoryEvent(
    j['state'] as String?,
    DateTime.tryParse(j['occurred_at'] as String? ?? ''),
  );
  final String? state;
  final DateTime? occurredAt;
}

class HistoryPage {
  const HistoryPage(this.items, this.cursor);
  final List<HistoryJob> items;
  final Json? cursor;
}

String formatMoney(int? amount, String? currency) {
  if (amount == null) return 'Chưa có chi phí';
  final s = amount.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
  return '$s ${currency == 'VND' ? '₫' : currency ?? ''}'.trim();
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
