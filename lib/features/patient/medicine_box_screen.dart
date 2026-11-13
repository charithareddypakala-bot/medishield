import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'dose_status_store.dart';
import 'medicine_store.dart';

class MedicineBoxScreen extends StatefulWidget {
  const MedicineBoxScreen({super.key});

  @override
  State<MedicineBoxScreen> createState() =>
      _MedicineBoxScreenState();
}

class _MedicineBoxScreenState extends State<MedicineBoxScreen> {
  final MedicineStore _medicineStore = MedicineStore.instance;

  int _selectedSlot = 2;

  @override
  void initState() {
    super.initState();
    _medicineStore.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _medicineStore.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Medicine? _medicineForSlot(int slot) {
    return _medicineStore.medicineInSlot(slot);
  }

  Medicine? get _selectedMedicine {
    return _medicineForSlot(_selectedSlot);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Medicine Box',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(
                alpha: 0.10,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: AppColors.success,
                ),
                SizedBox(width: 5),
                Text(
                  'Assignments',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConnectionCard(),

              const SizedBox(height: 16),

              _buildSlotGrid(),

              const SizedBox(height: 20),

              _buildSelectedSlotDetails(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    final assignedCount =
        _medicineStore.physicalMedicines.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(
                alpha: 0.10,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              color: AppColors.success,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'MediShield Smart Box',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$assignedCount of 6 slots assigned',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.inventory_2_outlined,
            color: AppColors.primary,
            size: 21,
          ),
        ],
      ),
    );
  }

  Widget _buildSlotGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.18,
      ),
      itemBuilder: (context, index) {
        final slot = index + 1;

        return _buildSlotCard(slot);
      },
    );
  }

  Widget _buildSlotCard(int slot) {
    final medicine = _medicineForSlot(slot);
    final isSelected = _selectedSlot == slot;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedSlot = slot;
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.lightBlue
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: medicine == null
            ? _buildEmptySlotContent(slot)
            : _buildOccupiedSlotContent(
                slot,
                medicine,
              ),
      ),
    );
  }

  Widget _buildOccupiedSlotContent(
    int slot,
    Medicine medicine,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Slot $slot',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            const Icon(
              Icons.medication_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ],
        ),

        const SizedBox(height: 10),

        const Icon(
          Icons.medication_outlined,
          size: 28,
          color: AppColors.primary,
        ),

        const SizedBox(height: 7),

        Text(
          medicine.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          medicine.schedule,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.secondary,
          ),
        ),

        const SizedBox(height: 5),

        _buildDoseStatus(medicine),
      ],
    );
  }

  Widget _buildEmptySlotContent(int slot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Slot $slot',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            const Icon(
              Icons.radio_button_unchecked,
              size: 19,
              color: AppColors.secondary,
            ),
          ],
        ),

        const SizedBox(height: 10),

        const Icon(
          Icons.inbox_outlined,
          size: 28,
          color: AppColors.secondary,
        ),

        const SizedBox(height: 7),

        const Text(
          'Empty slot',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          'Not assigned',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.secondary,
          ),
        ),

        const SizedBox(height: 5),

        const Text(
          'Empty',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDoseStatus(Medicine medicine) {
    final event = DoseStatusStore.instance.todayEventForMedicine(medicine.id);
    return Text(
      event?.status.label ?? 'No dose event today',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: event?.status == DoseStatus.takenConfirmed
            ? AppColors.success
            : AppColors.secondary,
      ),
    );
  }

  Widget _buildSelectedSlotDetails() {
    final medicine = _selectedMedicine;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected: Slot $_selectedSlot',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),

          const SizedBox(height: 12),

          if (medicine == null)
            _buildEmptySlotDetails()
          else
            _buildMedicineDetails(medicine),

          const SizedBox(height: 14),

          const Divider(),

          const SizedBox(height: 12),

          const Text(
            'Physical slot status',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),

          const SizedBox(height: 5),

          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Live device telemetry is not available from the backend.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            'The app should distinguish a scheduled dose '
            'from an actual hardware event. A slot should '
            'not be shown as dispensed until the device '
            'confirms it.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineDetails(Medicine medicine) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next scheduled dose: ${medicine.schedule}',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.secondary,
          ),
        ),

        const SizedBox(height: 7),

        Text(
          '${medicine.name} · ${medicine.strength}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          medicine.instructions,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySlotDetails() {
    return Text(
      'No medicine is assigned to this slot.',
      style: TextStyle(
        fontSize: 13,
        color: AppColors.secondary,
      ),
    );
  }

}
