import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/medishield_repository.dart';
import '../../core/theme/app_colors.dart';
import 'dose_status_store.dart';
import 'medicine_store.dart';

class AiPrescriptionScannerScreen extends StatefulWidget {
  const AiPrescriptionScannerScreen({super.key});

  @override
  State<AiPrescriptionScannerScreen> createState() =>
      _AiPrescriptionScannerScreenState();
}

class _AiPrescriptionScannerScreenState
    extends State<AiPrescriptionScannerScreen> {
  static const _maxFileBytes = 5 * 1024 * 1024;
  final _picker = ImagePicker();
  String? _fileName;
  Uint8List? _fileBytes;
  Uint8List? _previewBytes;
  Uint8List? _reviewPreviewBytes;
  String? _reviewFileName;
  List<Map<String, dynamic>> _history = [];
  List<_MedicineDraft> _drafts = [];
  Map<String, dynamic>? _scan;
  bool _loadingHistory = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await MediShieldRepository.getPrescriptionHistory();
      if (mounted) {
        setState(() {
          _history = history;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _chooseFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (result.isEmpty) return;
      final file = result.first;
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxFileBytes) {
        _showMessage('Choose a prescription file smaller than 5 MB.');
        return;
      }
      _clearDrafts();
      setState(() {
        _fileName = file.name;
        _fileBytes = bytes;
        _previewBytes = file.extension?.toLowerCase() == 'pdf' ? null : bytes;
        _reviewPreviewBytes = null;
        _reviewFileName = null;
        _scan = null;
      });
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _takePhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > _maxFileBytes) {
        _showMessage('The photo is larger than 5 MB. Choose a smaller image.');
        return;
      }
      _clearDrafts();
      setState(() {
        _fileName = image.name;
        _fileBytes = bytes;
        _previewBytes = bytes;
        _reviewPreviewBytes = null;
        _reviewFileName = null;
        _scan = null;
      });
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _analyze() async {
    final bytes = _fileBytes;
    final fileName = _fileName;
    if (bytes == null || fileName == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final scan = await MediShieldRepository.uploadPrescription(
        bytes: bytes,
        fileName: fileName,
      );
      if (!mounted) return;
      setState(() {
        _reviewPreviewBytes = _previewBytes;
        _reviewFileName = fileName;
      });
      _setScan(scan);
      setState(() {
        _fileName = null;
        _fileBytes = null;
        _previewBytes = null;
      });
      await _loadHistory();
      if ((scan['extractedMedicines'] as List? ?? const []).isEmpty) {
        _showMessage(
          'No medicine names could be identified. You can add medicines after checking the prescription.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
        _showMessage(error.toString());
        await _loadHistory();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setScan(Map<String, dynamic> scan) {
    _clearDrafts();
    final existing = MedicineStore.instance.medicines
        .map((m) => m.slot)
        .whereType<int>()
        .toSet();
    var nextSlot = 1;
    final extracted = (scan['extractedMedicines'] as List? ?? const []).map(
      (item) => Map<String, dynamic>.from(item as Map),
    );
    final drafts = <_MedicineDraft>[];
    for (final medicine in extracted) {
      while (existing.contains(nextSlot) && nextSlot <= 6) {
        nextSlot++;
      }
      final slot = nextSlot <= 6 ? nextSlot : null;
      if (slot != null) {
        existing.add(slot);
        nextSlot++;
      }
      drafts.add(_MedicineDraft.fromJson(medicine, suggestedSlot: slot));
    }
    setState(() {
      _scan = scan;
      _drafts = drafts;
    });
  }

  void _clearDrafts() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    _drafts = [];
  }

  void _openHistoryItem(Map<String, dynamic> scan) {
    if (scan['reviewedAt'] != null) {
      _showMessage('These prescription medicines have already been saved.');
      return;
    }
    _reviewPreviewBytes = null;
    _reviewFileName = null;
    _setScan(scan);
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 250),
    );
  }

  void _addMedicine() => setState(() => _drafts.add(_MedicineDraft.empty()));

  void _removeMedicine(_MedicineDraft draft) {
    setState(() => _drafts.remove(draft));
    draft.dispose();
  }

  Future<void> _saveMedicines() async {
    final scan = _scan;
    if (scan == null || _drafts.isEmpty) {
      _showMessage('Add at least one medicine before saving.');
      return;
    }
    final slots = _drafts.map((draft) => draft.slot).whereType<int>().toList();
    if (slots.toSet().length != slots.length) {
      _showMessage(
        'A drawer can only be assigned to one medicine. Choose different drawers.',
      );
      return;
    }
    for (final draft in _drafts) {
      if (draft.name.text.trim().length < 2) {
        _showMessage('Enter the medicine name or remove the medicine card.');
        return;
      }
      if (draft.hasInvalidTimes) {
        _showMessage(
          'Enter times as 24-hour values, for example 08:00, 20:00.',
        );
        return;
      }
    }
    setState(() => _busy = true);
    try {
      await MediShieldRepository.confirmPrescription(
        scanId: scan['_id'].toString(),
        medicines: _drafts.map((draft) => draft.toJson()).toList(),
      );
      await MedicineStore.instance.loadFromBackend();
      await DoseStatusStore.instance.loadTodayFromBackend();
      await _loadHistory();
      if (!mounted) return;
      _clearDrafts();
      setState(() {
        _scan = null;
        _reviewPreviewBytes = null;
        _reviewFileName = null;
      });
      _showMessage('Confirmed medicines were saved to your schedule.');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('AI Prescription Scanner'),
      backgroundColor: Colors.white,
    ),
    body: RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _uploadCard(),
          if (_error != null) _messageCard(_error!, Icons.error_outline),
          if (_scan != null) ...[
            const SizedBox(height: 18),
            _scanDetails(_scan!),
            const SizedBox(height: 12),
            if (_drafts.isEmpty)
              _messageCard(
                'No medicines were confidently identified. Add a medicine only after checking the prescription.',
                Icons.info_outline,
              ),
            ..._drafts.asMap().entries.map(
              (entry) => _medicineCard(entry.key, entry.value),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _addMedicine,
              icon: const Icon(Icons.add),
              label: const Text('Add medicine'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy || _drafts.isEmpty ? null : _saveMedicines,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_busy ? 'Saving…' : 'Confirm and save schedule'),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Prescription history',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (_loadingHistory)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_history.isEmpty)
            _messageCard(
              'No prescriptions uploaded yet.',
              Icons.description_outlined,
            )
          else
            ..._history.map(_historyCard),
        ],
      ),
    ),
  );

  Widget _uploadCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Scan a prescription',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          const Text(
            'Choose a JPG, PNG, or PDF, or take a photo. The backend reads the document and extracts only information it can support.',
          ),
          const SizedBox(height: 14),
          if (_fileBytes != null) ...[
            if (_previewBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _previewBytes!,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              )
            else
              const Icon(
                Icons.picture_as_pdf_outlined,
                size: 54,
                color: AppColors.primary,
              ),
            Text(
              _fileName ?? 'Prescription file',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          OutlinedButton.icon(
            onPressed: _busy ? null : _chooseFile,
            icon: const Icon(Icons.attach_file),
            label: Text(
              _fileBytes == null
                  ? 'Choose JPG, PNG, or PDF'
                  : 'Choose another file',
            ),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _takePhoto,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Take prescription photo'),
          ),
          FilledButton.icon(
            onPressed: _fileBytes == null || _busy ? null : _analyze,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.document_scanner_outlined),
            label: Text(
              _busy ? 'Reading and extracting…' : 'Analyze prescription',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _scanDetails(Map<String, dynamic> scan) {
    final confidence = (scan['ocrConfidence'] as num?)?.toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (scan['fileName'] ?? 'Prescription').toString(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (_reviewFileName != null && _reviewPreviewBytes != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _reviewPreviewBytes!,
                  height: 180,
                  fit: BoxFit.contain,
                ),
              ),
            ],
            const SizedBox(height: 5),
            Text(
              'Doctor: ${(scan['doctorName'] as String?)?.isNotEmpty == true ? scan['doctorName'] : 'Not found'}',
            ),
            Text(
              'Hospital: ${(scan['hospital'] as String?)?.isNotEmpty == true ? scan['hospital'] : 'Not found'}',
            ),
            Text(
              'Patient: ${(scan['patientName'] as String?)?.isNotEmpty == true ? scan['patientName'] : 'Not found'}',
            ),
            Text(
              'Prescription date: ${(scan['prescriptionDate'] as String?)?.isNotEmpty == true ? scan['prescriptionDate'] : 'Not found'}',
            ),
            if (confidence != null)
              Text('OCR confidence: ${(confidence * 100).round()}%'),
            if ((scan['notes'] as String?)?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  scan['notes'].toString(),
                  style: const TextStyle(color: AppColors.warning),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _medicineCard(int index, _MedicineDraft draft) {
    final reservedByOtherDrafts = _drafts
        .where((candidate) => !identical(candidate, draft))
        .map((candidate) => candidate.slot)
        .whereType<int>()
        .toSet();
    final availableSlots = MedicineStore.instance
        .availableSlots()
        .where((slot) => !reservedByOtherDrafts.contains(slot))
        .toList();
    final slots = <int>[
      ...availableSlots,
      if (draft.slot != null && !availableSlots.contains(draft.slot))
        draft.slot!,
      0,
    ];
    final confidence = (draft.confidence * 100).round();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Medicine ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : () => _removeMedicine(draft),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (draft.reviewRequired)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  "We couldn't confidently read this medicine.",
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (draft.confidence > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Extraction confidence: $confidence%'),
              ),
            _textField('Medicine name', draft.name),
            _textField('Strength', draft.strength),
            _textField('Form', draft.form),
            _textField('Dosage', draft.dosage),
            _textField('Frequency', draft.frequency),
            _textField('Meal instructions', draft.meal),
            _textField('Duration', draft.duration),
            _textField('Quantity', draft.quantity),
            _textField(
              'Special instructions',
              draft.specialInstructions,
              maxLines: 2,
            ),
            _textField('Times (24-hour, comma separated)', draft.times),
            DropdownButtonFormField<int>(
              initialValue: draft.slot ?? 0,
              decoration: const InputDecoration(labelText: 'Dispenser drawer'),
              items: [
                ...slots
                    .where((slot) => slot != 0)
                    .map(
                      (slot) => DropdownMenuItem<int>(
                        value: slot,
                        child: Text('Drawer $slot'),
                      ),
                    ),
                const DropdownMenuItem<int>(
                  value: 0,
                  child: Text('App reminder only'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) =>
                        setState(() => draft.slot = value == 0 ? null : value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, isDense: true),
    ),
  );

  Widget _historyCard(Map<String, dynamic> scan) {
    final saved = scan['reviewedAt'] != null;
    final medicines = (scan['extractedMedicines'] as List? ?? const []).length;
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.description_outlined,
          color: AppColors.primary,
        ),
        title: Text(
          (scan['fileName'] ?? 'Prescription').toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          saved
              ? '$medicines medicines saved'
              : '$medicines medicines extracted · ${(scan['status'] ?? 'pending').toString()}',
        ),
        trailing: saved
            ? const Icon(Icons.check_circle_outline, color: AppColors.primary)
            : const Icon(Icons.edit_outlined),
        onTap: saved ? null : () => _openHistoryItem(scan),
      ),
    );
  }

  Widget _messageCard(String text, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondaryText),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

class _MedicineDraft {
  _MedicineDraft({
    required this.name,
    required this.strength,
    required this.form,
    required this.dosage,
    required this.frequency,
    required this.meal,
    required this.duration,
    required this.quantity,
    required this.specialInstructions,
    required this.times,
    required this.confidence,
    required this.reviewRequired,
    required this.slot,
  });

  final TextEditingController name;
  final TextEditingController strength;
  final TextEditingController form;
  final TextEditingController dosage;
  final TextEditingController frequency;
  final TextEditingController meal;
  final TextEditingController duration;
  final TextEditingController quantity;
  final TextEditingController specialInstructions;
  final TextEditingController times;
  final double confidence;
  final bool reviewRequired;
  int? slot;

  factory _MedicineDraft.fromJson(
    Map<String, dynamic> json, {
    int? suggestedSlot,
  }) => _MedicineDraft(
    name: TextEditingController(text: (json['name'] ?? '').toString()),
    strength: TextEditingController(text: (json['strength'] ?? '').toString()),
    form: TextEditingController(text: (json['form'] ?? '').toString()),
    dosage: TextEditingController(text: (json['dosage'] ?? '').toString()),
    frequency: TextEditingController(
      text: (json['frequency'] ?? '').toString(),
    ),
    meal: TextEditingController(text: (json['meal'] ?? '').toString()),
    duration: TextEditingController(text: (json['duration'] ?? '').toString()),
    quantity: TextEditingController(text: (json['quantity'] ?? '').toString()),
    specialInstructions: TextEditingController(
      text: (json['specialInstructions'] ?? '').toString(),
    ),
    times: TextEditingController(
      text: ((json['times'] as List?) ?? const []).join(', '),
    ),
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    reviewRequired: json['reviewRequired'] == true,
    slot: suggestedSlot,
  );

  factory _MedicineDraft.empty() => _MedicineDraft.fromJson(const {});

  List<String> get parsedTimes => times.text
      .split(',')
      .map((value) => value.trim())
      .where(
        (value) =>
            value.isNotEmpty &&
            RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value),
      )
      .toSet()
      .toList();

  bool get hasInvalidTimes => times.text
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .any((value) => !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value));

  Map<String, dynamic> toJson() => {
    'name': name.text.trim(),
    'strength': strength.text.trim(),
    'form': form.text.trim(),
    'dosage': dosage.text.trim(),
    'frequency': frequency.text.trim(),
    'times': parsedTimes,
    'meal': meal.text.trim(),
    'duration': duration.text.trim(),
    'quantity': quantity.text.trim(),
    'specialInstructions': specialInstructions.text.trim(),
    'slot': slot,
  };

  void dispose() {
    name.dispose();
    strength.dispose();
    form.dispose();
    dosage.dispose();
    frequency.dispose();
    meal.dispose();
    duration.dispose();
    quantity.dispose();
    specialInstructions.dispose();
    times.dispose();
  }
}
