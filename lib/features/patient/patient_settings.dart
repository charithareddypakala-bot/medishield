import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/medishield_repository.dart';
import '../../core/theme/app_colors.dart';

class PatientSettingsScreen
    extends StatefulWidget {
  const PatientSettingsScreen({super.key});

  @override
  State<PatientSettingsScreen> createState() =>
      _PatientSettingsScreenState();
}

class _PatientSettingsScreenState
    extends State<PatientSettingsScreen> {
  bool voiceReminder = false;
  bool automaticExpiryAlerts = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await MediShieldRepository.getSettings();
      if (mounted) setState(() {
        voiceReminder = settings['voiceReminders'] == true;
        automaticExpiryAlerts = settings['expiryAlerts'] == true;
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<void> _setPreference(String key, bool previous, bool value, void Function(bool) update) async {
    setState(() => update(value));
    try {
      await MediShieldRepository.updateSettings({key: value});
    } catch (error) {
      if (!mounted) return;
      setState(() => update(previous));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _sectionTitle('Medicine Box'),

          _settingsTile(
            icon: Icons.inventory_2_outlined,
            title: 'Medicine Box',
            subtitle: 'View box connection and slot status',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Drawer assignments are stored in your MediShield account. Live device telemetry is not available.',
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          _sectionTitle('Reminder Preferences'),

          _switchTile(
            icon: Icons.volume_up_outlined,
            title: 'Voice Reminders',
            subtitle: 'Enable spoken medicine reminders',
            value: voiceReminder,
            onChanged: (value) => _setPreference('voiceReminders', voiceReminder, value, (v) => voiceReminder = v),
          ),

          _switchTile(
            icon: Icons.event_available_outlined,
            title: 'Automatic Expiry Alerts',
            subtitle: 'Receive alerts before medicines expire',
            value: automaticExpiryAlerts,
            onChanged: (value) => _setPreference('expiryAlerts', automaticExpiryAlerts, value, (v) => automaticExpiryAlerts = v),
          ),

          const SizedBox(height: 18),

          _sectionTitle('Security'),

          _settingsTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: () {
              _showChangePasswordDialog();
            },
          ),

          const SizedBox(height: 18),

          _sectionTitle('Support'),

          _settingsTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get help using MediShield',
            onTap: () {},
          ),

          _settingsTile(
            icon: Icons.info_outline,
            title: 'About MediShield',
            subtitle: 'App information',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'MediShield',
                applicationVersion: '1.0.0',
                applicationLegalese:
                    'Smart medicine reminder system',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        bottom: 9,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: AppColors.primary,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.secondaryText,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.secondaryText,
        ),
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
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Icon(
          icon,
          color: AppColors.primary,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.secondaryText,
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Change Password',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (next.text.length < 8 || next.text != confirm.text) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Enter matching passwords with at least 8 characters.')),
                );
                return;
              }
              AuthService.changePassword(
                currentPassword: current.text,
                newPassword: next.text,
              ).then((_) {
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password updated successfully.')),
                );
              }).catchError((error) {
                if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(error.toString())),
                );
              });
            },
            child: const Text('Update'),
          ),
        ],
      ),
    ).whenComplete(() {
      current.dispose();
      next.dispose();
      confirm.dispose();
    });
  }
}
