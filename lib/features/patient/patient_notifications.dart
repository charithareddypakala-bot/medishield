import 'package:flutter/material.dart';

import '../../core/services/medishield_repository.dart';
import '../../core/theme/app_colors.dart';

class PatientNotificationsScreen extends StatefulWidget {
  const PatientNotificationsScreen({super.key});

  @override
  State<PatientNotificationsScreen> createState() => _PatientNotificationsScreenState();
}

class _PatientNotificationsScreenState extends State<PatientNotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        MediShieldRepository.getTodayDoses(),
        MediShieldRepository.getMedicines(),
      ]);
      final doses = results[0] as List<Map<String, dynamic>>;
      final medicines = results[1] as List<Map<String, dynamic>>;
      final notices = <Map<String, dynamic>>[];
      for (final event in doses) {
        final status = (event['status'] ?? '').toString();
        final name = (event['medicineName'] ?? 'Medicine').toString();
        if (status == 'overdueUnconfirmed') {
          notices.add({'title': 'Dose needs attention', 'body': '$name has not been confirmed.', 'icon': Icons.warning_amber_rounded, 'color': AppColors.warning, 'time': event['scheduledTime'] ?? ''});
        } else if (status == 'awaitingPatientConfirmation') {
          notices.add({'title': 'Confirm your dose', 'body': '$name is awaiting your confirmation.', 'icon': Icons.notifications_active_outlined, 'color': AppColors.primary, 'time': event['scheduledTime'] ?? ''});
        } else if (status == 'deviceError') {
          notices.add({'title': 'Dispenser event', 'body': 'The backend reported a device error for $name.', 'icon': Icons.error_outline, 'color': AppColors.error, 'time': event['scheduledTime'] ?? ''});
        }
      }
      final today = DateTime.now();
      for (final medicine in medicines) {
        final expiry = DateTime.tryParse(medicine['expiryDate']?.toString() ?? '');
        if (expiry == null) continue;
        final days = expiry.difference(DateTime(today.year, today.month, today.day)).inDays;
        if (days <= 30) {
          notices.add({'title': days < 0 ? 'Medicine expired' : 'Expiry alert', 'body': '${medicine['name']} ${days < 0 ? 'has expired' : 'expires in $days days'}.', 'icon': Icons.event_busy_outlined, 'color': days < 0 ? AppColors.error : AppColors.warning, 'time': expiry.toLocal().toString().split(' ').first});
        }
      }
      if (mounted) setState(() { _items = notices; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Notifications')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Try again'))])))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? ListView(children: const [SizedBox(height: 140), Center(child: Text('No backend alerts right now.'))])
                        : ListView.separated(
                            padding: const EdgeInsets.all(18),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final color = item['color'] as Color;
                              return Card(child: ListTile(leading: CircleAvatar(backgroundColor: color.withValues(alpha: .1), child: Icon(item['icon'] as IconData, color: color)), title: Text(item['title'].toString()), subtitle: Text('${item['body']}\n${item['time']}'), isThreeLine: true));
                            },
                          ),
                  ),
      );
}
