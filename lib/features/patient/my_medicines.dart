import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'ai_prescription_scanner.dart';
import 'medicine_store.dart';

class MyMedicinesScreen extends StatefulWidget {
  const MyMedicinesScreen({super.key});

  @override
  State<MyMedicinesScreen> createState() => _MyMedicinesScreenState();
}

class _MyMedicinesScreenState extends State<MyMedicinesScreen> {
  final MedicineStore store = MedicineStore.instance;
  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';
  String _filter = 'all';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    store.addListener(_refresh);
    if (store.medicines.isEmpty) {
      store.loadFromBackend().catchError((_) {});
    }
  }

  @override
  void dispose() {
    store.removeListener(_refresh);
    searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  List<Medicine> get filteredMedicines {
    if (searchQuery.trim().isEmpty) {
      return store.medicines;
    }

    final query = searchQuery.toLowerCase();

    return store.medicines.where((medicine) {
      return medicine.name.toLowerCase().contains(query) ||
          medicine.purpose.toLowerCase().contains(query) ||
          medicine.strength.toLowerCase().contains(query);
    }).toList();
  }

  List<Medicine> get physicalMedicines {
    if (_filter == 'reminder') return const [];
    return filteredMedicines
        .where((medicine) => medicine.slot != null)
        .toList();
  }

  List<Medicine> get reminderMedicines {
    if (_filter == 'box') return const [];
    return filteredMedicines
        .where((medicine) => medicine.slot == null)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Medicines',
          style: TextStyle(
            color: AppColors.darkBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.darkBlue),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: AppColors.secondaryText),
                  const SizedBox(width: 8),
                  const Text(
                    'Show:',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _filter,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All medicines'),
                      ),
                      DropdownMenuItem(
                        value: 'box',
                        child: Text('Medicine box'),
                      ),
                      DropdownMenuItem(
                        value: 'reminder',
                        child: Text('App reminders'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _filter = value ?? 'all'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await store.loadFromBackend(search: searchQuery);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    if (store.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (store.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          store.errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_filter != 'reminder') ...[
                      _buildMedicineBoxSummary(),
                      const SizedBox(height: 18),
                      _buildSectionTitle(
                        'Medicine Box',
                        '6 physical medicine slots',
                      ),
                      const SizedBox(height: 10),
                      _buildSixSlots(),
                    ],
                    if (_filter != 'box') ...[
                      const SizedBox(height: 22),
                      _buildSectionTitle(
                        'App Reminder Only',
                        'Medicines not stored in the box',
                      ),
                      const SizedBox(height: 10),
                      if (reminderMedicines.isEmpty)
                        _buildEmptyReminderCard()
                      else
                        ...reminderMedicines.map(_buildReminderMedicineCard),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _showAddMedicineOptions,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Medicine',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: searchController,
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 300), () {
            store.loadFromBackend(search: value).catchError((_) {});
          });
        },
        decoration: InputDecoration(
          hintText: 'Search medicines...',
          prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    searchController.clear();

                    setState(() {
                      searchQuery = '';
                    });
                    _searchDebounce?.cancel();
                    store.loadFromBackend().catchError((_) {});
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildMedicineBoxSummary() {
    final assignedCount = store.physicalMedicines.length;
    final emptyCount = 6 - assignedCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.medication_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MediShield Medicine Box',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$assignedCount of 6 slots assigned · '
                  '$emptyCount available',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: AppColors.success,
                ),
                SizedBox(width: 5),
                Text(
                  'Assignments',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.darkBlue,
            ),
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
        ),
      ],
    );
  }

  Widget _buildSixSlots() {
    return Column(
      children: List.generate(6, (index) {
        final slotNumber = index + 1;
        final medicine = store.medicineInSlot(slotNumber);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildSlotCard(slotNumber: slotNumber, medicine: medicine),
        );
      }),
    );
  }

  Widget _buildSlotCard({
    required int slotNumber,
    required Medicine? medicine,
  }) {
    final isOccupied = medicine != null;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOccupied
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: isOccupied ? AppColors.lightBlue : AppColors.background,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(
                '$slotNumber',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isOccupied
                      ? AppColors.primary
                      : AppColors.secondaryText,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: isOccupied
                ? _buildOccupiedSlotContent(medicine)
                : _buildEmptySlotContent(),
          ),
          if (isOccupied)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editMedicine(medicine);
                } else if (value == 'remove') {
                  _removeFromSlot(medicine);
                } else if (value == 'delete') {
                  _deleteMedicine(medicine);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'remove',
                  child: Text('Move to App Reminder Only'),
                ),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            )
          else
            TextButton(
              onPressed: () {
                _showAddMedicineOptions(suggestedSlot: slotNumber);
              },
              child: const Text(
                'Assign',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOccupiedSlotContent(Medicine medicine) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          medicine.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${medicine.strength} · Slot ${medicine.slot}',
          style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(
              Icons.schedule_outlined,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              medicine.schedule,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        if (medicine.expiryWarning) ...[
          const SizedBox(height: 5),
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: AppColors.warning,
              ),
              SizedBox(width: 4),
              Text(
                'Expiry needs attention',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEmptySlotContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Empty Slot',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'No medicine assigned',
          style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
        ),
      ],
    );
  }

  Widget _buildEmptyReminderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.notifications_none, color: AppColors.secondaryText),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No App Reminder Only medicines.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderMedicineCard(Medicine medicine) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  medicine.purpose.trim().isEmpty
                      ? medicine.strength
                      : '${medicine.strength} · ${medicine.purpose}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${medicine.schedule} · App Reminder Only',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _editMedicine(medicine);
              } else if (value == 'delete') {
                _deleteMedicine(medicine);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddMedicineOptions({int? suggestedSlot}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Medicine',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose how you want to add your medicine.',
                  style: TextStyle(color: AppColors.secondaryText),
                ),
                const SizedBox(height: 18),
                _bottomSheetOption(
                  icon: Icons.edit_outlined,
                  title: 'Add Manually',
                  subtitle: 'Enter medicine details yourself',
                  onTap: () async {
                    Navigator.pop(sheetContext);

                    await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManualAddMedicineScreen(
                          suggestedSlot: suggestedSlot,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _bottomSheetOption(
                  icon: Icons.document_scanner_outlined,
                  title: 'Upload Prescription',
                  subtitle: 'Upload an image to your account',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AiPrescriptionScannerScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bottomSheetOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkBlue,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.secondaryText),
          ],
        ),
      ),
    );
  }

  void _editMedicine(Medicine medicine) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManualAddMedicineScreen(existingMedicine: medicine),
      ),
    );
  }

  void _removeFromSlot(Medicine medicine) {
    store
        .assignSlotOnBackend(medicine, null)
        .then((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${medicine.name} moved to App Reminder Only.'),
              ),
            );
          }
        })
        .catchError((error) {
          if (mounted)
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(error.toString())));
        });
  }

  void _deleteMedicine(Medicine medicine) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Medicine'),
          content: Text('Are you sure you want to delete ${medicine.name}?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await store.deleteFromBackend(medicine.id);
                  if (!dialogContext.mounted || !mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Medicine deleted.')),
                  );
                } catch (error) {
                  if (mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// MANUAL ADD / EDIT MEDICINE
// ---------------------------------------------------------------------------

class ManualAddMedicineScreen extends StatefulWidget {
  final int? suggestedSlot;
  final Medicine? existingMedicine;

  const ManualAddMedicineScreen({
    super.key,
    this.suggestedSlot,
    this.existingMedicine,
  });

  @override
  State<ManualAddMedicineScreen> createState() =>
      _ManualAddMedicineScreenState();
}

class _ManualAddMedicineScreenState extends State<ManualAddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController strengthController;
  late final TextEditingController purposeController;
  late final TextEditingController scheduleController;
  late final TextEditingController instructionsController;

  DateTime? selectedExpiryDate;

  int? selectedSlot;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final medicine = widget.existingMedicine;

    nameController = TextEditingController(text: medicine?.name ?? '');

    strengthController = TextEditingController(text: medicine?.strength ?? '');

    purposeController = TextEditingController(text: medicine?.purpose ?? '');

    scheduleController = TextEditingController(text: medicine?.schedule ?? '');

    instructionsController = TextEditingController(
      text: medicine?.instructions ?? '',
    );

    selectedExpiryDate = medicine?.expiryDate;

    selectedSlot = medicine?.slot ?? widget.suggestedSlot;
  }

  @override
  void dispose() {
    nameController.dispose();
    strengthController.dispose();
    purposeController.dispose();
    scheduleController.dispose();
    instructionsController.dispose();
    super.dispose();
  }

  bool get isEditing => widget.existingMedicine != null;

  Future<void> _selectExpiryDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedExpiryDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      selectedExpiryDate = pickedDate;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isEditing ? 'Edit Medicine' : 'Add Medicine',
          style: const TextStyle(
            color: AppColors.darkBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.darkBlue),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            children: [
              _field(
                label: 'Medicine Name',
                hint: 'Enter medicine name',
                controller: nameController,
                icon: Icons.medication_outlined,
              ),
              const SizedBox(height: 15),

              _field(
                label: 'Strength',
                hint: 'Example: 500 mg',
                controller: strengthController,
                icon: Icons.science_outlined,
              ),
              const SizedBox(height: 15),

              _field(
                label: 'Purpose (optional)',
                hint: 'Example: Pain relief',
                controller: purposeController,
                icon: Icons.health_and_safety_outlined,
                optional: true,
              ),
              const SizedBox(height: 15),

              _field(
                label: 'Dose Time',
                hint: 'Example: 08:00 AM',
                controller: scheduleController,
                icon: Icons.schedule_outlined,
              ),
              const SizedBox(height: 15),

              _buildExpiryDateSelector(),
              const SizedBox(height: 15),

              _field(
                label: 'Instructions',
                hint: 'Example: 1 dose · After food',
                controller: instructionsController,
                icon: Icons.info_outline,
              ),
              const SizedBox(height: 22),

              _buildStorageSelector(),
              const SizedBox(height: 28),

              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _saveMedicine,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEditing ? 'Save Changes' : 'Save Medicine',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiryDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Expiry Date (optional)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 7),
        InkWell(
          onTap: _selectExpiryDate,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedExpiryDate == null
                        ? 'Select expiry date'
                        : _formatExpiryDate(selectedExpiryDate!),
                    style: TextStyle(
                      fontSize: 14,
                      color: selectedExpiryDate == null
                          ? AppColors.secondaryText
                          : AppColors.darkBlue,
                    ),
                  ),
                ),
                if (selectedExpiryDate == null)
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: AppColors.primary,
                  )
                else
                  IconButton(
                    tooltip: 'Clear expiry date',
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.secondaryText,
                    ),
                    onPressed: () => setState(() => selectedExpiryDate = null),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatExpiryDate(DateTime date) {
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

    return '${months[date.month - 1]} '
        '${date.day}, '
        '${date.year}';
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool optional = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          validator: (value) {
            final text = value?.trim() ?? '';
            if (!optional && text.isEmpty) {
              return 'Please enter $label';
            }

            if (text.isNotEmpty && text.length < 2) {
              return '${label.replaceAll(' (optional)', '')} must be at least 2 characters.';
            }

            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.secondaryText),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStorageSelector() {
    final availableSlots = MedicineStore.instance.availableSlots(
      excludingMedicineId: widget.existingMedicine?.id,
    );

    final currentSlot = widget.existingMedicine?.slot;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Storage Location',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: selectedSlot,
              isExpanded: true,
              hint: const Text('Select storage location'),
              items: [
                ...availableSlots.map((slot) {
                  return DropdownMenuItem<int?>(
                    value: slot,
                    child: Text('Slot $slot'),
                  );
                }),
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('App Reminder Only'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedSlot = value;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          currentSlot != null
              ? 'Current location: Slot $currentSlot'
              : 'Choose a physical slot or App Reminder Only.',
          style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
        ),
      ],
    );
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Final safety check before saving.
    if (selectedSlot != null &&
        MedicineStore.instance.isSlotOccupied(
          selectedSlot!,
          excludingMedicineId: widget.existingMedicine?.id,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That slot is already assigned. '
            'Please choose another slot.',
          ),
        ),
      );
      return;
    }

    final medicine = Medicine(
      id:
          widget.existingMedicine?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: nameController.text.trim(),
      strength: strengthController.text.trim(),
      purpose: purposeController.text.trim(),
      schedule: scheduleController.text.trim(),
      instructions: instructionsController.text.trim(),
      expiryDate: selectedExpiryDate,
      slot: selectedSlot,
      expiryWarning: false,
    );

    setState(() => _saving = true);
    try {
      if (widget.existingMedicine != null) {
        await MedicineStore.instance.updateOnBackend(medicine);
      } else {
        await MedicineStore.instance.createOnBackend(medicine);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
