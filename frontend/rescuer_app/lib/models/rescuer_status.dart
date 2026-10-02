enum PartnerReviewStatus { draft, submitted, approved, rejected, suspended }

enum DocumentReviewStatus { notSubmitted, submitted, approved, needsChanges }

enum VehicleReviewStatus { draft, submitted, approved, rejected, suspended }

enum RescueJobStatus {
  accepted,
  enRoute,
  arrived,
  inProgress,
  completed,
  cancelled,
}

extension RescueJobStatusText on RescueJobStatus {
  String get label => switch (this) {
    RescueJobStatus.accepted => 'Đã nhận đơn',
    RescueJobStatus.enRoute => 'Đang di chuyển',
    RescueJobStatus.arrived => 'Đã đến nơi',
    RescueJobStatus.inProgress => 'Đang xử lý',
    RescueJobStatus.completed => 'Đã hoàn tất',
    RescueJobStatus.cancelled => 'Đã hủy',
  };

  bool get isTerminal =>
      this == RescueJobStatus.completed || this == RescueJobStatus.cancelled;
}

extension PartnerReviewStatusText on PartnerReviewStatus {
  String get label => switch (this) {
    PartnerReviewStatus.draft => 'Bản nháp',
    PartnerReviewStatus.submitted => 'Đang chờ duyệt',
    PartnerReviewStatus.approved => 'Đã duyệt',
    PartnerReviewStatus.rejected => 'Cần bổ sung',
    PartnerReviewStatus.suspended => 'Tạm ngưng',
  };
}

extension DocumentReviewStatusText on DocumentReviewStatus {
  String get label => switch (this) {
    DocumentReviewStatus.notSubmitted => 'Chưa gửi',
    DocumentReviewStatus.submitted => 'Đang xem xét',
    DocumentReviewStatus.approved => 'Đã duyệt',
    DocumentReviewStatus.needsChanges => 'Cần bổ sung',
  };
}

extension VehicleReviewStatusText on VehicleReviewStatus {
  String get label => switch (this) {
    VehicleReviewStatus.draft => 'Bản nháp',
    VehicleReviewStatus.submitted => 'Đang chờ duyệt',
    VehicleReviewStatus.approved => 'Đã duyệt',
    VehicleReviewStatus.rejected => 'Cần bổ sung',
    VehicleReviewStatus.suspended => 'Tạm ngưng',
  };
}
