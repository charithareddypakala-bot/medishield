import 'package:flutter/material.dart';

import '../../core/services/medication_reminder_service.dart';
import '../../core/services/medishield_repository.dart';
import '../../core/theme/app_colors.dart';
import 'medicine_store.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool medicineReminders = false;
  bool voiceReminders = false;
  bool missedDoseAlerts = false;
  bool expiryAlerts = false;
  bool caretakerNotifications = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await MediShieldRepository.getSettings();
      if (!mounted) return;
      setState(() {
        medicineReminders = settings['medicineReminders'] == true;
        voiceReminders = settings['voiceReminders'] == true;
        missedDoseAlerts = settings['missedDoseAlerts'] == true;
        expiryAlerts = settings['expiryAlerts'] == true;
        caretakerNotifications = settings['caretakerNotifications'] == true;
        _loading = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error.toString();
          _loading = false;
        });
    }
  }

  Future<void> _updatePreference(
    String key,
    bool previous,
    bool value,
    void Function(bool) assign,
  ) async {
    setState(() => assign(value));
    try {
      await MediShieldRepository.updateSettings({key: value});
    } catch (error) {
      if (!mounted) return;
      setState(() => assign(previous));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _updateMedicineReminders(bool value) async {
    final previous = medicineReminders;
    if (value) {
      bool granted;
      try {
        granted = await MedicationReminderService.instance.requestPermissions();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.toString())));
        }
        return;
      }
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Allow notifications in Android settings to receive medicine reminders.',
              ),
            ),
          );
        }
        return;
      }
      try {
        await MedicineStore.instance.loadFromBackend();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.toString())));
        }
        return;
      }
    }

    if (mounted) setState(() => medicineReminders = value);
    try {
      await MediShieldRepository.updateSettings({'medicineReminders': value});
      await MedicationReminderService.instance.syncMedicines(
        MedicineStore.instance.medicines
            .map(
              (medicine) => MedicationReminder(
                id: medicine.id,
                name: medicine.name,
                strength: medicine.strength,
                schedule: medicine.schedule,
              ),
            )
            .toList(),
        enabled: value,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => medicineReminders = previous);
      await MedicationReminderService.instance.syncMedicines(
        MedicineStore.instance.medicines
            .map(
              (medicine) => MedicationReminder(
                id: medicine.id,
                name: medicine.name,
                strength: medicine.strength,
                schedule: medicine.schedule,
              ),
            )
            .toList(),
        enabled: previous,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Notification Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Text(
                  'Medication Notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Choose which notifications you want to receive.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),

                const SizedBox(height: 18),

                _switchTile(
                  icon: Icons.medication_outlined,
                  title: 'Medicine Reminders',
                  subtitle: 'Remind me when it is time to take medicine',
                  value: medicineReminders,
                  onChanged: _updateMedicineReminders,
                ),

                _switchTile(
                  icon: Icons.volume_up_outlined,
                  title: 'Voice Reminders',
                  subtitle: 'Play a voice reminder from the app',
                  value: voiceReminders,
                  onChanged: (value) => _updatePreference(
                    'voiceReminders',
                    voiceReminders,
                    value,
                    (v) => voiceReminders = v,
                  ),
                ),

                _switchTile(
                  icon: Icons.warning_amber_outlined,
                  title: 'Missed Dose Alerts',
                  subtitle: 'Notify me when a scheduled dose is unconfirmed',
                  value: missedDoseAlerts,
                  onChanged: (value) => _updatePreference(
                    'missedDoseAlerts',
                    missedDoseAlerts,
                    value,
                    (v) => missedDoseAlerts = v,
                  ),
                ),

                _switchTile(
                  icon: Icons.calendar_month_outlined,
                  title: 'Expiry Alerts',
                  subtitle: 'Alert me about medicines nearing expiry',
                  value: expiryAlerts,
                  onChanged: (value) => _updatePreference(
                    'expiryAlerts',
                    expiryAlerts,
                    value,
                    (v) => expiryAlerts = v,
                  ),
                ),

                _switchTile(
                  icon: Icons.people_outline,
                  title: 'Caretaker Notifications',
                  subtitle: 'Allow notifications related to caretaker activity',
                  value: caretakerNotifications,
                  onChanged: (value) => _updatePreference(
                    'caretakerNotifications',
                    caretakerNotifications,
                    value,
                    (v) => caretakerNotifications = v,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        secondary: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
        ),
      ),
    );
  }
}
