import 'package:flutter/material.dart';

import '../../core/services/medishield_repository.dart';
import '../../core/theme/app_colors.dart';

class PatientScheduleScreen extends StatefulWidget {
  const PatientScheduleScreen({super.key});

  @override
  State<PatientScheduleScreen> createState() => _PatientScheduleScreenState();
}

class _PatientScheduleScreenState extends State<PatientScheduleScreen> {
  List<Map<String, dynamic>> _events = [];
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
      final events = await MediShieldRepository.getTodayDoses();
      events.sort((a, b) => _minutes(a['scheduledTime']).compareTo(_minutes(b['scheduledTime'])));
      if (mounted) setState(() { _events = events; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  int _minutes(dynamic raw) {
    final value = (raw ?? '').toString().trim().toUpperCase();
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$').firstMatch(value);
    if (match == null) return 24 * 60;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3);
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return hour * 60 + minute;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Today’s Schedule')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Try again'))])))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _events.isEmpty
                        ? ListView(children: const [SizedBox(height: 140), Center(child: Text('No doses are scheduled for today.'))])
                        : ListView.builder(
                            padding: const EdgeInsets.all(18),
                            itemCount: _events.length,
                            itemBuilder: (context, index) {
                              final event = _events[index];
                              final status = (event['status'] ?? 'scheduled').toString();
                              return IntrinsicHeight(
                                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                  SizedBox(width: 64, child: Padding(padding: const EdgeInsets.only(top: 18), child: Text((event['scheduledTime'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)))),
                                  Column(children: [Container(width: 14, height: 14, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)), if (index != _events.length - 1) Expanded(child: Container(width: 2, color: AppColors.border))]),
                                  const SizedBox(width: 12),
                                  Expanded(child: Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(leading: const Icon(Icons.medication_outlined, color: AppColors.primary), title: Text((event['medicineName'] ?? 'Medicine').toString()), subtitle: Text('Slot ${event['slot'] ?? '—'} · ${status.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]}').trim()}')))),
                                ]),
                              );
                            },
                          ),
                  ),
      );
}
