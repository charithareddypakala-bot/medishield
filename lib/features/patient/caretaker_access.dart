import 'package:flutter/material.dart';

import '../../core/services/medishield_repository.dart';
import '../../core/theme/app_colors.dart';

class CaretakerAccessScreen extends StatefulWidget {
  const CaretakerAccessScreen({super.key});

  @override
  State<CaretakerAccessScreen> createState() => _CaretakerAccessScreenState();
}

class _CaretakerAccessScreenState extends State<CaretakerAccessScreen> {
  List<Map<String, dynamic>> _requests = [];
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
      final requests = await MediShieldRepository.getCaretakerRequests();
      if (mounted) setState(() { _requests = requests; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<void> _respond(String id, bool approve) async {
    try {
      await MediShieldRepository.updateCaretakerRequest(id, approve: approve);
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _requestCaretaker() async {
    final controller = TextEditingController();
    final caretakerId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request caretaker access'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enter the caretaker’s MediShield email address or account ID.'),
          const SizedBox(height: 12),
          TextField(controller: controller, decoration: const InputDecoration(labelText: 'Caretaker email or account ID')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Send request')),
        ],
      ),
    );
    controller.dispose();
    if (caretakerId == null || caretakerId.isEmpty) return;
    try {
      await MediShieldRepository.createCaretakerRequest(caretakerId: caretakerId);
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Caretaker Access')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _requestCaretaker,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Request caretaker'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Try again'))])))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _requests.isEmpty
                        ? ListView(children: const [SizedBox(height: 140), Center(child: Text('No caretaker requests yet.'))])
                        : ListView.builder(
                            padding: const EdgeInsets.all(18),
                            itemCount: _requests.length,
                            itemBuilder: (context, index) {
                              final request = _requests[index];
                              final status = (request['status'] ?? 'pending').toString();
                              final id = (request['_id'] ?? request['id'] ?? '').toString();
                              final caretakerEmail = (request['caretakerEmail'] ?? 'Caretaker').toString();
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    ListTile(leading: const Icon(Icons.people_outline, color: AppColors.primary), title: Text(caretakerEmail), subtitle: Text('Access request: $status')),
                                    if (request['message'] != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(request['message'].toString())),
                                    if (status == 'pending') Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                      TextButton(onPressed: () => _respond(id, false), child: const Text('Decline')),
                                      const SizedBox(width: 8),
                                      FilledButton(onPressed: () => _respond(id, true), child: const Text('Approve')),
                                    ]),
                                  ]),
                                ),
                              );
                            },
                          ),
                  ),
      );
}
