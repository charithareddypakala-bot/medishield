import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MedicationReminder {
  const MedicationReminder({
    required this.id,
    required this.name,
    required this.strength,
    required this.schedule,
  });

  final String id;
  final String name;
  final String strength;
  final String schedule;
}

/// Sends the user's real medicine schedule to Android's AlarmManager so
/// reminders can fire even while Flutter is closed or the phone has rebooted.
class MedicationReminderService {
  MedicationReminderService._();

  static final instance = MedicationReminderService._();
  static const _channel = MethodChannel('medishield/reminders');
  bool _initialized = false;
  bool _enabled = false;

  Future<void> initialize() async {
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    await initialize();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _channel.invokeMethod<bool>('requestPermissions') ?? false;
    } on PlatformException catch (error) {
      debugPrint('Could not request reminder permissions: ${error.message}');
      return false;
    }
  }

  Future<void> syncMedicines(
    List<MedicationReminder> medicines, {
    bool? enabled,
  }) async {
    if (!_initialized) await initialize();
    if (enabled != null) _enabled = enabled;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final schedule = <Map<String, Object>>[];
    if (_enabled) {
      for (final medicine in medicines) {
        for (final time in _timesFor(medicine.schedule)) {
          schedule.add({
            'id': _stableId('${medicine.id}:${time.$1}:${time.$2}'),
            'name': medicine.name,
            'strength': medicine.strength,
            'hour': time.$1,
            'minute': time.$2,
          });
        }
      }
    }

    try {
      await _channel.invokeMethod<void>('sync', {
        'enabled': _enabled,
        'items': schedule,
      });
    } on PlatformException catch (error) {
      debugPrint('Could not update medicine alarms: ${error.message}');
    } on MissingPluginException {
      // Windows, web and other platforms do not have the Android alarm bridge.
    }
  }

  List<(int, int)> _timesFor(String schedule) {
    final times = <(int, int)>{};
    final timePattern = RegExp(
      r'\b(?:(\d{1,2}):([0-5]\d)\s*(a\.?m\.?|p\.?m\.?)?|(\d{1,2})\s*(a\.?m\.?|p\.?m\.?))\b',
      caseSensitive: false,
    );
    for (final match in timePattern.allMatches(schedule)) {
      final rawHour = int.tryParse(match.group(1) ?? match.group(4) ?? '');
      if (rawHour == null) continue;
      final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
      final period = (match.group(3) ?? match.group(5) ?? '').toLowerCase();
      var hour = rawHour;
      if (period.startsWith('p') && hour < 12) hour += 12;
      if (period.startsWith('a') && hour == 12) hour = 0;
      if (hour >= 0 && hour <= 23) times.add((hour, minute));
    }
    if (times.isNotEmpty) return times.toList()..sort(_compareTimes);

    final text = schedule.toLowerCase();
    if (RegExp(r'\b(four|4)\s*(times|x|daily|per day)?\b').hasMatch(text)) {
      return [(8, 0), (12, 0), (16, 0), (20, 0)];
    }
    if (RegExp(r'\b(three|3)\s*(times|x|daily|per day)\b').hasMatch(text)) {
      return [(8, 0), (14, 0), (20, 0)];
    }
    if (RegExp(r'\b(twice|two|2)\s*(daily|a day|times|x|per day)\b')
        .hasMatch(text)) {
      return [(8, 0), (20, 0)];
    }
    if (RegExp(r'\b(once daily|once a day|daily|every day)\b').hasMatch(text)) {
      return [(8, 0)];
    }
    return const [];
  }

  int _compareTimes((int, int) left, (int, int) right) =>
      (left.$1 * 60 + left.$2).compareTo(right.$1 * 60 + right.$2);

  int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final byte in value.codeUnits) {
      hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
