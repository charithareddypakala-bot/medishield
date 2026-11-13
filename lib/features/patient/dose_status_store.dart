import 'package:flutter/foundation.dart';

import '../../core/services/medishield_repository.dart';

enum DoseStatus {
  scheduled,
  dispensingRequested,
  dispensed,
  removalDetected,
  awaitingPatientConfirmation,
  takenConfirmed,
  overdueUnconfirmed,
  deviceError,
}

extension DoseStatusExtension on DoseStatus {
  String get label {
    switch (this) {
      case DoseStatus.scheduled:
        return 'Scheduled';

      case DoseStatus.dispensingRequested:
        return 'Dispensing Requested';

      case DoseStatus.dispensed:
        return 'Dispensed';

      case DoseStatus.removalDetected:
        return 'Removal Detected';

      case DoseStatus.awaitingPatientConfirmation:
        return 'Awaiting Confirmation';

      case DoseStatus.takenConfirmed:
        return 'Taken Confirmed';

      case DoseStatus.overdueUnconfirmed:
        return 'Overdue / Unconfirmed';

      case DoseStatus.deviceError:
        return 'Device Error';
    }
  }
}

class DoseEvent {
  final String id;
  final String medicineId;
  final String medicineName;
  final String scheduledTime;
  final DateTime scheduledDate;
  final int? slot;

  DoseStatus status;

  DateTime? eventTime;
  String? note;

  DoseEvent({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.scheduledTime,
    required this.scheduledDate,
    required this.slot,
    this.status = DoseStatus.scheduled,
    this.eventTime,
    this.note,
  });

  factory DoseEvent.fromJson(Map<String, dynamic> json) {
    final statusName = json['status']?.toString() ?? 'scheduled';
    final status = DoseStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => DoseStatus.scheduled,
    );
    final medicine = json['medicine'];
    return DoseEvent(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      medicineId: (medicine is Map
              ? (medicine['_id'] ?? medicine['id'])
              : medicine ?? '')
          .toString(),
      medicineName: (json['medicineName'] ?? 'Medicine').toString(),
      scheduledTime: (json['scheduledTime'] ?? '').toString(),
      scheduledDate: DateTime.tryParse(json['scheduledDate']?.toString() ?? '') ??
          DateTime.now(),
      slot: json['slot'] is num ? (json['slot'] as num).toInt() : null,
      status: status,
      eventTime: DateTime.tryParse(json['eventTime']?.toString() ?? ''),
      note: json['note']?.toString(),
    );
  }
}

class DoseStatusStore extends ChangeNotifier {
  DoseStatusStore._();

  static final DoseStatusStore instance =
      DoseStatusStore._();

  final List<DoseEvent> _events = [];

  bool isLoading = false;
  String? errorMessage;

  Future<void> loadTodayFromBackend() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final results = await MediShieldRepository.getTodayDoses();
      _events
        ..clear()
        ..addAll(results.map(DoseEvent.fromJson));
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =====================================================
  // GETTERS
  // =====================================================

  List<DoseEvent> get events =>
      List.unmodifiable(_events);

  // =====================================================
  // FIND EVENT
  // =====================================================

  DoseEvent? findEvent(
    String eventId,
  ) {
    for (final event in _events) {
      if (event.id == eventId) {
        return event;
      }
    }

    return null;
  }

  // =====================================================
  // FIND EVENTS FOR MEDICINE
  // =====================================================

  List<DoseEvent> eventsForMedicine(
    String medicineId,
  ) {
    return _events
        .where(
          (event) =>
              event.medicineId == medicineId,
        )
        .toList();
  }

  // =====================================================
  // FIND TODAY'S EVENT FOR MEDICINE
  // =====================================================

  DoseEvent? todayEventForMedicine(
    String medicineId,
  ) {
    for (final event in _events) {
      if (event.medicineId == medicineId) {
        return event;
      }
    }

    return null;
  }

  Future<bool> confirmTaken(String eventId) async {
    final event = findEvent(eventId);
    if (event == null) return false;
    await MediShieldRepository.confirmDose(eventId);
    event.status = DoseStatus.takenConfirmed;
    event.eventTime = DateTime.now();
    event.note = 'Confirmed by patient';
    notifyListeners();
    return true;
  }

  // =====================================================
  // TODAY'S EVENTS
  // =====================================================

  List<DoseEvent> get todayEvents {
    // The source is GET /doses/today; trust the backend's timezone boundary.
    final events = List<DoseEvent>.from(_events);
    events.sort((a, b) => _timeToMinutes(a.scheduledTime)
        .compareTo(_timeToMinutes(b.scheduledTime)));
    return events;
  }

  // =====================================================
  // TODAY'S CONFIRMED COUNT
  // =====================================================

  int get todayConfirmedCount {
    return todayEvents
        .where(
          (event) =>
              event.status ==
              DoseStatus.takenConfirmed,
        )
        .length;
  }

  // =====================================================
  // TODAY'S OVERDUE COUNT
  // =====================================================

  int get todayOverdueCount {
    return todayEvents
        .where(
          (event) =>
              event.status ==
              DoseStatus.overdueUnconfirmed,
        )
        .length;
  }

  // =====================================================
  // TODAY'S PENDING CONFIRMATION COUNT
  // =====================================================

  int get todayPendingConfirmationCount {
    return todayEvents
        .where(
          (event) =>
              event.status ==
                  DoseStatus.dispensed ||
              event.status ==
                  DoseStatus.removalDetected ||
              event.status ==
                  DoseStatus
                      .awaitingPatientConfirmation,
        )
        .length;
  }

  // =====================================================
  // TODAY'S SCHEDULED COUNT
  // =====================================================

  int get todayScheduledCount {
    return todayEvents
        .where(
          (event) =>
              event.status ==
              DoseStatus.scheduled,
        )
        .length;
  }

  // =====================================================
  // CHECK WHETHER EVENT IS COMPLETED
  // =====================================================

  bool isTaken(
    DoseEvent event,
  ) {
    return event.status ==
        DoseStatus.takenConfirmed;
  }

  // =====================================================
  // CHECK WHETHER EVENT IS PENDING
  // =====================================================

  bool isPending(
    DoseEvent event,
  ) {
    return event.status ==
            DoseStatus.scheduled ||
        event.status ==
            DoseStatus.dispensingRequested ||
        event.status ==
            DoseStatus.dispensed ||
        event.status ==
            DoseStatus.removalDetected ||
        event.status ==
            DoseStatus
                .awaitingPatientConfirmation;
  }

  // =====================================================
  // CHECK WHETHER EVENT IS OVERDUE
  // =====================================================

  bool isOverdue(
    DoseEvent event,
  ) {
    return event.status ==
        DoseStatus.overdueUnconfirmed;
  }

  // =====================================================
  // CLEAR ALL EVENTS
  // =====================================================

  void clearEvents() {
    _events.clear();

    notifyListeners();
  }

  int _timeToMinutes(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$', caseSensitive: false)
        .firstMatch(value.trim());
    if (match == null) return 24 * 60;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)?.toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return hour * 60 + minute;
  }
}
