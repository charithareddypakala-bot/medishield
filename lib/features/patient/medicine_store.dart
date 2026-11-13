import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/medishield_repository.dart';
import '../../core/services/medication_reminder_service.dart';

class Medicine {
  final String id;

  String name;
  String strength;
  String purpose;
  String schedule;
  String instructions;

  /// Actual expiry date of the medicine.
  DateTime? expiryDate;

  /// 1–6 = physical medicine-box slot.
  /// null = App Reminder Only.
  int? slot;

  bool expiryWarning;

  Medicine({
    required this.id,
    required this.name,
    required this.strength,
    this.purpose = '',
    required this.schedule,
    required this.instructions,
    this.expiryDate,
    this.slot,
    this.expiryWarning = false,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
    id: (json['_id'] ?? json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    strength: (json['strength'] ?? '').toString(),
    purpose: (json['purpose'] ?? '').toString(),
    schedule: (json['schedule'] ?? '').toString(),
    instructions: (json['instructions'] ?? '').toString(),
    expiryDate: DateTime.tryParse(json['expiryDate']?.toString() ?? ''),
    slot: json['slot'] is num ? (json['slot'] as num).toInt() : null,
    expiryWarning: json['expiryWarning'] == true,
  );

  Map<String, dynamic> toApiJson() => {
    'name': name,
    'strength': strength,
    'purpose': purpose,
    'schedule': schedule,
    'instructions': instructions,
    'expiryDate': expiryDate?.toIso8601String(),
    if (slot != null) 'slot': slot,
    'storageType': slot == null ? 'app_reminder' : 'medicine_box',
    'expiryWarning': expiryWarning,
  };

  /// Returns a readable expiry date.
  String get expiry {
    if (expiryDate == null) {
      return 'Not available';
    }

    return '${_monthName(expiryDate!.month)} '
        '${expiryDate!.day}, '
        '${expiryDate!.year}';
  }

  static String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }
}

class MedicineStore extends ChangeNotifier {
  MedicineStore._();

  static final MedicineStore instance = MedicineStore._();

  bool isLoading = false;
  String? errorMessage;
  int _loadRequestId = 0;

  Future<void> loadFromBackend({String search = '', int? slot}) async {
    final requestId = ++_loadRequestId;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final results = await MediShieldRepository.getMedicines(
        search: search,
        slot: slot,
      );
      if (requestId != _loadRequestId) return;
      _medicines
        ..clear()
        ..addAll(results.map(Medicine.fromJson));
      if (search.trim().isEmpty && slot == null) {
        unawaited(_syncRemindersFromBackend());
      }
    } catch (error) {
      if (requestId == _loadRequestId) errorMessage = error.toString();
      rethrow;
    } finally {
      if (requestId == _loadRequestId) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<Medicine> createOnBackend(Medicine medicine) async {
    final json = await MediShieldRepository.createMedicine(
      medicine.toApiJson(),
    );
    final created = Medicine.fromJson(json);
    _medicines.add(created);
    await _syncRemindersFromBackend();
    notifyListeners();
    return created;
  }

  Future<Medicine> updateOnBackend(Medicine medicine) async {
    final index = _medicines.indexWhere((item) => item.id == medicine.id);
    final previousSlot = index >= 0 ? _medicines[index].slot : medicine.slot;
    var json = await MediShieldRepository.updateMedicine(
      medicine.id,
      medicine.toApiJson(),
    );
    if (previousSlot != medicine.slot) {
      json = await MediShieldRepository.assignMedicineSlot(
        medicine.id,
        medicine.slot,
      );
    }
    final updated = Medicine.fromJson(json);
    if (index >= 0) _medicines[index] = updated;
    await _syncRemindersFromBackend();
    notifyListeners();
    return updated;
  }

  Future<void> deleteFromBackend(String id) async {
    await MediShieldRepository.deleteMedicine(id);
    _medicines.removeWhere((item) => item.id == id);
    await _syncRemindersFromBackend();
    notifyListeners();
  }

  Future<Medicine> assignSlotOnBackend(Medicine medicine, int? slot) async {
    final json = await MediShieldRepository.assignMedicineSlot(
      medicine.id,
      slot,
    );
    final updated = Medicine.fromJson(json);
    final index = _medicines.indexWhere((item) => item.id == medicine.id);
    if (index >= 0) _medicines[index] = updated;
    notifyListeners();
    return updated;
  }

  final List<Medicine> _medicines = [];

  Future<void> _syncRemindersFromBackend() async {
    try {
      final medicines = await MediShieldRepository.getMedicines();
      await MedicationReminderService.instance.syncMedicines(
        medicines
            .map(Medicine.fromJson)
            .map(
              (medicine) => MedicationReminder(
                id: medicine.id,
                name: medicine.name,
                strength: medicine.strength,
                schedule: medicine.schedule,
              ),
            )
            .toList(),
      );
    } catch (_) {
      // The medicine edit was saved; a reminder refresh can retry next launch.
    }
  }

  List<Medicine> get medicines => List.unmodifiable(_medicines);

  List<Medicine> get physicalMedicines =>
      _medicines.where((medicine) => medicine.slot != null).toList();

  List<Medicine> get appReminderMedicines =>
      _medicines.where((medicine) => medicine.slot == null).toList();

  Medicine? medicineInSlot(int slot) {
    for (final medicine in _medicines) {
      if (medicine.slot == slot) {
        return medicine;
      }
    }

    return null;
  }

  bool isSlotOccupied(int slot, {String? excludingMedicineId}) {
    return _medicines.any(
      (medicine) => medicine.slot == slot && medicine.id != excludingMedicineId,
    );
  }

  List<int> availableSlots({String? excludingMedicineId}) {
    return List.generate(6, (index) => index + 1)
        .where(
          (slot) =>
              !isSlotOccupied(slot, excludingMedicineId: excludingMedicineId),
        )
        .toList();
  }

  Medicine? get nextMedicine {
    if (_medicines.isEmpty) {
      return null;
    }

    final sorted = [..._medicines];

    sorted.sort(
      (a, b) =>
          _timeToMinutes(a.schedule).compareTo(_timeToMinutes(b.schedule)),
    );

    return sorted.first;
  }

  int _timeToMinutes(String time) {
    try {
      final parts = time.trim().split(' ');

      final hm = parts[0].split(':');

      int hour = int.parse(hm[0]);

      final minute = int.parse(hm[1]);

      final period = parts.length > 1 ? parts[1].toUpperCase() : '';

      if (period == 'PM' && hour != 12) {
        hour += 12;
      }

      if (period == 'AM' && hour == 12) {
        hour = 0;
      }

      return hour * 60 + minute;
    } catch (_) {
      return 9999;
    }
  }
}
