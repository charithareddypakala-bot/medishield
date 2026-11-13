import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/medishield_repository.dart';
import '../../core/theme/app_colors.dart';
import '../patient/notification_settings.dart';

class CaretakerDashboard extends StatefulWidget {
  const CaretakerDashboard({super.key});

  @override
  State<CaretakerDashboard> createState() => _CaretakerDashboardState();
}

class _CaretakerDashboardState extends State<CaretakerDashboard> {
  int _selectedIndex = 0;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _profile = const {};
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        MediShieldRepository.getProfile(),
        MediShieldRepository.getApprovedPatients(),
        MediShieldRepository.getCaretakerRequests(),
        MediShieldRepository.getDoseHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _patients = results[1] as List<Map<String, dynamic>>;
        _requests = results[2] as List<Map<String, dynamic>>;
        _history = results[3] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Widget _page() {
    switch (_selectedIndex) {
      case 1: return _patientsPage();
      case 2: return _requestsPage();
      case 3: return _reportsPage();
      case 4: return _profilePage();
      default: return _homePage();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Try again'))])))
                  : RefreshIndicator(onRefresh: _load, child: _page()),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Patients'),
            NavigationDestination(icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications), label: 'Requests'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      );

  Widget _homePage() => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _header('Hello, ${_profile['name'] ?? 'Caretaker'}', 'MediShield account overview'),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _countCard('Linked patients', '${_patients.length}', Icons.people_outline)),
            const SizedBox(width: 10),
            Expanded(child: _countCard('Open requests', '${_requests.where((r) => r['status'] == 'pending').length}', Icons.hourglass_top_outlined)),
          ]),
          const SizedBox(height: 22),
          _section('Linked patients'),
          if (_patients.isEmpty) _empty('No approved patient links yet.') else ..._patients.take(3).map(_patientCard),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _showAddPatientDialog, icon: const Icon(Icons.person_add_alt_1), label: const Text('Request patient access')),
          const SizedBox(height: 20),
          _section('Backend access limits'),
          const Text('The current API provides patient link status. It does not expose a caretaker view of linked patients’ medicines, doses, or dispenser telemetry.'),
        ],
      );

  Widget _patientsPage() => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _header('Linked patients', 'Approved links from MediShield'),
          const SizedBox(height: 14),
          if (_patients.isEmpty) _empty('No approved patient links yet.') else ..._patients.map(_patientCard),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _showAddPatientDialog, icon: const Icon(Icons.person_add_alt_1), label: const Text('Request patient access')),
        ],
      );

  Widget _requestsPage() => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _header('Care requests', 'Statuses loaded from your account'),
          const SizedBox(height: 14),
          if (_requests.isEmpty)
            _empty('There are no care requests.')
          else
            ..._requests.map((request) {
              final patientEmail = (request['patientEmail'] ?? 'Patient account').toString();
              final status = (request['status'] ?? 'pending').toString();
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.link_outlined, color: AppColors.primary),
                  title: Text(patientEmail),
                  subtitle: Text('Request status: $status'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            }),
        ],
      );

  Widget _reportsPage() => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _header('Dose reports', 'Dose history returned by the backend'),
          const SizedBox(height: 14),
          if (_history.isEmpty)
            _empty('No dose history is available for this account.')
          else
            ..._history.map((event) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.medication_outlined, color: AppColors.primary),
                    title: Text((event['medicineName'] ?? 'Medicine').toString()),
                    subtitle: Text('${event['scheduledDate'] ?? ''} · ${event['scheduledTime'] ?? ''}'),
                    trailing: Text((event['status'] ?? 'scheduled').toString()),
                  ),
                )),
        ],
      );

  Widget _profilePage() => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _header((_profile['name'] ?? 'Profile').toString(), (_profile['email'] ?? '').toString()),
          const SizedBox(height: 12),
          Card(child: ListTile(title: const Text('Phone'), subtitle: Text((_profile['phone'] ?? 'Not provided').toString()))),
          Card(child: ListTile(title: const Text('Account role'), subtitle: Text((_profile['role'] ?? 'caretaker').toString()))),
          Card(child: ListTile(leading: const Icon(Icons.notifications_outlined), title: const Text('Notification preferences'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())))),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await AuthService.logout(returnToWelcome: true);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      );

  Widget _header(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: AppColors.secondaryText)),
        ],
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
      );

  Widget _countCard(String label, String value, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [Icon(icon, color: AppColors.primary), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), Text(label)]))]),
        ),
      );

  Widget _patientCard(Map<String, dynamic> link) {
    final patient = link['patient'] is Map
        ? Map<String, dynamic>.from(link['patient'] as Map)
        : link;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text((patient['name'] ?? 'Patient').toString()),
        subtitle: Text((patient['email'] ?? 'Linked account').toString()),
        trailing: Chip(label: Text((link['status'] ?? 'approved').toString())),
      ),
    );
  }

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.secondaryText))),
      );

  Future<void> _showAddPatientDialog() async {
    final idController = TextEditingController();
    final messageController = TextEditingController();
    final patientId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request patient access'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enter the patient’s MediShield email address or account ID.'),
          const SizedBox(height: 12),
          TextField(controller: idController, decoration: const InputDecoration(labelText: 'Patient email or account ID')),
          TextField(controller: messageController, decoration: const InputDecoration(labelText: 'Message (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, idController.text.trim()), child: const Text('Send request')),
        ],
      ),
    );
    if (patientId == null || patientId.isEmpty) return;
    try {
      await MediShieldRepository.createCaretakerRequest(
        patientId: patientId,
        caretakerId: AppSession.instance.currentUser?.id,
        message: messageController.text.trim().isEmpty ? null : messageController.text.trim(),
      );
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      idController.dispose();
      messageController.dispose();
    }
  }
}
