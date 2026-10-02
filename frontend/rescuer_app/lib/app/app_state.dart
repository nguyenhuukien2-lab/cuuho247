import 'package:flutter/foundation.dart';

import '../models/active_job.dart';
import '../models/request_preview.dart';
import '../models/rescuer_status.dart';

enum RequestFeedState { loading, empty, unavailable, expired, error, ready }

/// UI-only state. It does not call APIs, read GPS, or contain sample requests.
class AppState extends ChangeNotifier {
  int selectedTab = 0;
  bool isOnline = false;
  bool isSignedIn = false;
  bool isBusy = false;
  bool isBackendAvailable = false;
  RequestFeedState requestFeedState = RequestFeedState.unavailable;
  RequestPreview? requestPreview;
  bool hasLocationPermission = false;
  bool isGpsEnabled = false;
  bool isNetworkAvailable = true;
  PartnerReviewStatus partnerStatus = PartnerReviewStatus.draft;
  DocumentReviewStatus identityStatus = DocumentReviewStatus.notSubmitted;
  DocumentReviewStatus licenseStatus = DocumentReviewStatus.notSubmitted;
  VehicleReviewStatus vehicleStatus = VehicleReviewStatus.draft;
  String? fullName;
  String? contactPhone;
  String? contactEmail;
  String? vehicleDisplayName;
  String? vehiclePlate;
  String vehicleServiceType = 'Xe máy hỗ trợ';
  final Set<String> serviceCapabilities = {};
  ActiveJob? activeJob;
  final List<ActiveJob> history = [];

  void selectTab(int index) {
    selectedTab = index;
    notifyListeners();
  }

  void signInLocally() {
    isSignedIn = true;
    notifyListeners();
  }

  void signOutLocally() {
    isSignedIn = false;
    isOnline = false;
    notifyListeners();
  }

  void setOnline(bool value) {
    isOnline =
        value &&
        hasLocationPermission &&
        isGpsEnabled &&
        isNetworkAvailable &&
        isBackendAvailable;
    notifyListeners();
  }

  void setPermissionState({bool? location, bool? gps, bool? network}) {
    if (location != null) hasLocationPermission = location;
    if (gps != null) isGpsEnabled = gps;
    if (network != null) isNetworkAvailable = network;
    if (!hasLocationPermission || !isGpsEnabled || !isNetworkAvailable) {
      isOnline = false;
    }
    notifyListeners();
  }

  void startLocalJob(ActiveJob job) {
    activeJob = job.copyWith(acceptedAt: job.acceptedAt ?? DateTime.now());
    isBusy = true;
    notifyListeners();
  }

  void setJobStatus(RescueJobStatus status) {
    final job = activeJob;
    if (job == null) return;
    final now = DateTime.now();
    activeJob = job.copyWith(
      status: status,
      enRouteAt: status == RescueJobStatus.enRoute ? now : null,
      arrivedAt: status == RescueJobStatus.arrived ? now : null,
      inProgressAt: status == RescueJobStatus.inProgress ? now : null,
      finishedAt: status.isTerminal ? now : null,
    );
    notifyListeners();
  }

  void saveQuote({
    required String service,
    required String extras,
    required String note,
    required int totalVnd,
  }) {
    final job = activeJob;
    if (job != null) {
      activeJob = job.copyWith(
        quotedTotalVnd: totalVnd,
        quoteService: service,
        quoteExtras: extras,
        quoteNote: note,
      );
    }
    notifyListeners();
  }

  void completeJob() {
    final job = activeJob;
    if (job == null) return;
    history.insert(
      0,
      job.copyWith(
        status: RescueJobStatus.completed,
        finishedAt: DateTime.now(),
      ),
    );
    activeJob = null;
    isBusy = false;
    notifyListeners();
  }

  void cancelJob() {
    final job = activeJob;
    if (job == null) return;
    history.insert(
      0,
      job.copyWith(
        status: RescueJobStatus.cancelled,
        finishedAt: DateTime.now(),
      ),
    );
    activeJob = null;
    isBusy = false;
    notifyListeners();
  }

  void setPartnerStatus(PartnerReviewStatus status) {
    partnerStatus = status;
    notifyListeners();
  }

  void submitIdentity() {
    identityStatus = DocumentReviewStatus.submitted;
    notifyListeners();
  }

  void submitLicense() {
    licenseStatus = DocumentReviewStatus.submitted;
    notifyListeners();
  }

  void submitVehicle() {
    vehicleStatus = VehicleReviewStatus.submitted;
    notifyListeners();
  }

  void savePartnerProfile({
    required String name,
    required String phone,
    required String email,
  }) {
    fullName = name.trim();
    contactPhone = phone.trim();
    contactEmail = email.trim();
    notifyListeners();
  }

  void saveVehicle({
    required String displayName,
    required String plate,
    required String type,
  }) {
    vehicleDisplayName = displayName.trim();
    vehiclePlate = plate.trim();
    vehicleServiceType = type;
    notifyListeners();
  }

  void saveCapabilities(Set<String> services) {
    serviceCapabilities
      ..clear()
      ..addAll(services);
    notifyListeners();
  }
}
