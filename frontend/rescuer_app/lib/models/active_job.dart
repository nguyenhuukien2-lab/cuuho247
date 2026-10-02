import 'request_preview.dart';
import 'rescuer_status.dart';

class ActiveJob {
  const ActiveJob({
    required this.requestId,
    required this.preview,
    required this.status,
    this.customerName,
    this.customerPhone,
    this.exactAddress,
    this.description,
    this.quotedTotalVnd,
    this.quoteService,
    this.quoteExtras,
    this.quoteNote,
    this.acceptedAt,
    this.enRouteAt,
    this.arrivedAt,
    this.inProgressAt,
    this.finishedAt,
  });

  final String requestId;
  final RequestPreview preview;
  final RescueJobStatus status;
  final String? customerName;
  final String? customerPhone;
  final String? exactAddress;
  final String? description;
  final int? quotedTotalVnd;
  final String? quoteService;
  final String? quoteExtras;
  final String? quoteNote;
  final DateTime? acceptedAt;
  final DateTime? enRouteAt;
  final DateTime? arrivedAt;
  final DateTime? inProgressAt;
  final DateTime? finishedAt;

  ActiveJob copyWith({
    RescueJobStatus? status,
    int? quotedTotalVnd,
    String? quoteService,
    String? quoteExtras,
    String? quoteNote,
    DateTime? acceptedAt,
    DateTime? enRouteAt,
    DateTime? arrivedAt,
    DateTime? inProgressAt,
    DateTime? finishedAt,
  }) => ActiveJob(
    requestId: requestId,
    preview: preview,
    status: status ?? this.status,
    customerName: customerName,
    customerPhone: customerPhone,
    exactAddress: exactAddress,
    description: description,
    quotedTotalVnd: quotedTotalVnd ?? this.quotedTotalVnd,
    quoteService: quoteService ?? this.quoteService,
    quoteExtras: quoteExtras ?? this.quoteExtras,
    quoteNote: quoteNote ?? this.quoteNote,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    enRouteAt: enRouteAt ?? this.enRouteAt,
    arrivedAt: arrivedAt ?? this.arrivedAt,
    inProgressAt: inProgressAt ?? this.inProgressAt,
    finishedAt: finishedAt ?? this.finishedAt,
  );
}
