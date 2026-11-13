import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/api_client.dart';
import '../../core/services/medication_reminder_service.dart';
import '../../core/services/medishield_repository.dart';
import '../../core/theme/app_colors.dart';

import 'ai_prescription_scanner.dart';
import 'caretaker_access.dart';
import 'dose_status_store.dart';
import 'expiry_alerts_screen.dart';
import 'medicine_box_screen.dart';
import 'medicine_store.dart';
import 'my_medicines.dart';
import 'patient_notifications.dart';
import 'patient_schedule.dart';
import 'notification_settings.dart';
import 'patient_settings.dart';
import 'patient_profile.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  final MedicineStore _medicineStore = MedicineStore.instance;

  final DoseStatusStore _doseStore = DoseStatusStore.instance;

  int _selectedNavIndex = 0;
  bool _loading = true;
  String? _loadError;
  Map<String, dynamic> _profile = const {};
  Map<String, dynamic> _summary = const {};

  @override
  void initState() {
    super.initState();

    _medicineStore.addListener(_refreshDashboard);
    _doseStore.addListener(_refreshDashboard);

    _loadDashboard();
  }

  @override
  void dispose() {
    _medicineStore.removeListener(_refreshDashboard);
    _doseStore.removeListener(_refreshDashboard);

    super.dispose();
  }

  void _refreshDashboard() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadDashboard() async {
    if (!AppSession.instance.isLoggedIn) {
      await AppSession.instance.expireSession();
      return;
    }

    if (mounted)
      setState(() {
        _loading = true;
        _loadError = null;
      });
    try {
      final results = await Future.wait<dynamic>([
        MediShieldRepository.getProfile(),
        MediShieldRepository.getDashboard(),
        _medicineStore.loadFromBackend(),
        _doseStore.loadTodayFromBackend(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _summary = results[1] as Map<String, dynamic>;
        _loading = false;
      });
      try {
        final settings = await MediShieldRepository.getSettings();
        await MedicationReminderService.instance.syncMedicines(
          _medicineStore.medicines
              .map(
                (medicine) => MedicationReminder(
                  id: medicine.id,
                  name: medicine.name,
                  strength: medicine.strength,
                  schedule: medicine.schedule,
                ),
              )
              .toList(),
          enabled: settings['medicineReminders'] == true,
        );
      } catch (_) {
        // Keep the dashboard usable if reminders cannot be refreshed.
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  // ===========================================================================
  // DOSE STATUS
  // ===========================================================================

  List<DoseEvent> get _todayDoseEvents {
    return _doseStore.todayEvents;
  }

  int get _todayTotal {
    return _todayDoseEvents.length;
  }

  int get _todayConfirmed {
    return _todayDoseEvents
        .where((event) => event.status == DoseStatus.takenConfirmed)
        .length;
  }

  int get _todayUpcoming {
    return _todayDoseEvents
        .where(
          (event) =>
              event.status == DoseStatus.scheduled ||
              event.status == DoseStatus.dispensingRequested ||
              event.status == DoseStatus.dispensed ||
              event.status == DoseStatus.removalDetected ||
              event.status == DoseStatus.awaitingPatientConfirmation,
        )
        .length;
  }

  Medicine? get _nextScheduledMedicine {
    final activeEvents = _todayDoseEvents
        .where((event) => event.status != DoseStatus.takenConfirmed)
        .toList();
    if (activeEvents.isEmpty) return null;
    final activeEvent = activeEvents.first;
    for (final medicine in _medicineStore.medicines) {
      if (medicine.id == activeEvent.medicineId) return medicine;
    }
    return null;
  }

  int get _todayUnconfirmed {
    return _todayDoseEvents
        .where((event) => event.status == DoseStatus.overdueUnconfirmed)
        .length;
  }

  double get _todayProgress {
    if (_todayTotal == 0) {
      return 0;
    }

    return _todayConfirmed / _todayTotal;
  }

  Future<void> _confirmDose(DoseEvent event) async {
    try {
      final success = await _doseStore.confirmTaken(event.id);
      if (!success || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${event.medicineName} marked as taken.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  void _openMyMedicines() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyMedicinesScreen()),
    );
  }

  void _openSchedule() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PatientScheduleScreen()),
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PatientNotificationsScreen()),
    );
  }

  void _openMedicineBox() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MedicineBoxScreen()),
    );
  }

  void _openAiPrescriptionScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiPrescriptionScannerScreen()),
    );
  }

  void _openExpiryAlerts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExpiryAlertsScreen()),
    );
  }

  Future<void> _openMyProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MyProfileScreen()),
    );
    if (mounted) await _loadDashboard();
  }

  void _openNotificationSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
    );
  }

  void _openCaretakerAccess() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CaretakerAccessScreen()),
    );
  }

  void _openPatientSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PatientSettingsScreen()),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 42),
                      const SizedBox(height: 12),
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadDashboard,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            : _buildBody(),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBody() {
    switch (_selectedNavIndex) {
      case 1:
        return _buildMedicinesTab();

      case 2:
        return _buildMedicineBoxTab();

      case 3:
        return _buildProfileTab();

      default:
        return _buildHomeTab();
    }
  }

  // ===========================================================================
  // HOME TAB
  // ===========================================================================

  Widget _buildHomeTab() {
    final assignedCount = _medicineStore.physicalMedicines.length;

    final nextMedicine = _nextScheduledMedicine;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadDashboard();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _buildHeader(),

          const SizedBox(height: 20),

          _buildMedicineBoxConnectionCard(assignedCount),

          const SizedBox(height: 16),

          _buildNextMedicineCard(nextMedicine),

          const SizedBox(height: 16),

          _buildMedicationProgressCard(),

          const SizedBox(height: 22),

          _buildTodayMedicinesSection(),

          const SizedBox(height: 22),

          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),

          const SizedBox(height: 12),

          _buildQuickActions(),

          const SizedBox(height: 22),

          _buildReminderInfoCard(),
        ],
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader() {
    final now = DateTime.now();

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

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final dateText =
        '${weekdays[now.weekday - 1]}, '
        '${now.day} ${months[now.month - 1]} '
        '${now.year}';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MEDISHIELD · PATIENT APP',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Hello, ${_profile['name'] ?? 'there'}',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                dateText,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),

        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: Colors.white,
            size: 27,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // MEDICINE BOX CONNECTION
  // ===========================================================================

  Widget _buildMedicineBoxConnectionCard(int assignedCount) {
    return InkWell(
      onTap: _openMedicineBox,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primary,
                size: 27,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Medicine box slots',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    '$assignedCount of 6 medicine '
                    'slots assigned',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.lightGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: AppColors.success),
                  SizedBox(width: 5),
                  Text(
                    'Configured',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // NEXT MEDICINE
  // ===========================================================================

  Widget _buildNextMedicineCard(Medicine? medicine) {
    if (medicine == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'No medicines scheduled yet.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
      );
    }

    final location = medicine.slot != null
        ? 'Slot ${medicine.slot}'
        : 'App Reminder Only';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'NEXT MEDICINE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Colors.white70,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Upcoming',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Text(
            medicine.name,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),

          if (medicine.strength.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              medicine.strength,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],

          const SizedBox(height: 15),

          Row(
            children: [
              _whiteDetail(Icons.access_time, medicine.schedule),

              const SizedBox(width: 18),

              _whiteDetail(Icons.inventory_2_outlined, location),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            medicine.instructions,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),

          const SizedBox(height: 18),

          GestureDetector(
            onTap: _openSchedule,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View medicine schedule',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 5),
                Icon(Icons.arrow_forward, size: 16, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _whiteDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TODAY'S MEDICATION PROGRESS
  // ===========================================================================

  Widget _buildMedicationProgressCard() {
    final confirmed = _todayConfirmed;
    final total = _todayTotal;
    final progress = _todayProgress;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Today's Medication",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),

              Text(
                '$confirmed of $total confirmed',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: AppColors.border,
              color: AppColors.success,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              _progressStatus('Confirmed $confirmed', AppColors.success),

              const SizedBox(width: 10),

              _progressStatus('Upcoming $_todayUpcoming', AppColors.primary),

              const SizedBox(width: 10),

              _progressStatus(
                'Unconfirmed $_todayUnconfirmed',
                AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressStatus(String text, Color color) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),

          const SizedBox(width: 5),

          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.secondaryText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TODAY'S MEDICINES
  // ===========================================================================

  Widget _buildTodayMedicinesSection() {
    final events = _todayDoseEvents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today’s Medicines',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),

        const SizedBox(height: 12),

        if (events.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'No medicines scheduled for today.',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          )
        else
          ...events.map((event) {
            Medicine? match;
            for (final item in _medicineStore.medicines) {
              if (item.id == event.medicineId) {
                match = item;
                break;
              }
            }
            final medicine =
                match ??
                Medicine(
                  id: event.medicineId,
                  name: event.medicineName,
                  strength: '',
                  purpose: '',
                  schedule: event.scheduledTime,
                  instructions: '',
                  slot: event.slot,
                );
            return _buildTodayMedicineCard(medicine, event);
          }),
      ],
    );
  }

  Widget _buildTodayMedicineCard(Medicine medicine, DoseEvent? event) {
    final isTaken = event?.status == DoseStatus.takenConfirmed;

    final isOverdue = event?.status == DoseStatus.overdueUnconfirmed;

    final isDeviceError = event?.status == DoseStatus.deviceError;

    String statusText;

    if (isTaken) {
      statusText = 'Taken';
    } else if (isOverdue) {
      statusText = 'Overdue';
    } else if (isDeviceError) {
      statusText = 'Device Error';
    } else {
      statusText = 'Upcoming';
    }

    Color statusColor;

    if (isTaken) {
      statusColor = AppColors.success;
    } else if (isOverdue || isDeviceError) {
      statusColor = AppColors.error;
    } else {
      statusColor = AppColors.primary;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.medication_outlined,
                  color: AppColors.primary,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      medicine.strength,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(
                Icons.schedule_outlined,
                size: 17,
                color: AppColors.secondaryText,
              ),

              const SizedBox(width: 6),

              Text(
                medicine.schedule,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                ),
              ),

              const SizedBox(width: 16),

              const Icon(
                Icons.inventory_2_outlined,
                size: 17,
                color: AppColors.secondaryText,
              ),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  medicine.slot != null
                      ? 'Slot ${medicine.slot}'
                      : 'App Reminder Only',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            medicine.instructions,
            style: const TextStyle(fontSize: 13, color: AppColors.text),
          ),

          if (event != null && !isTaken && !isOverdue && !isDeviceError) ...[
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDose(event),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Confirm Taken'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.success,
                  side: const BorderSide(color: AppColors.success),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],

          if (isOverdue) ...[
            const SizedBox(height: 10),

            const Text(
              'This dose has not been confirmed.',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],

          if (isDeviceError) ...[
            const SizedBox(height: 10),

            const Text(
              'Please check the medicine box.',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // QUICK ACTIONS
  // ===========================================================================

  Widget _buildQuickActions() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: [
        _quickAction(
          icon: Icons.document_scanner_outlined,
          title: 'Prescription\nUpload',
          onTap: _openAiPrescriptionScanner,
          color: AppColors.primary,
        ),

        _quickAction(
          icon: Icons.calendar_month_outlined,
          title: 'My Schedule',
          onTap: _openSchedule,
          color: AppColors.success,
        ),

        _quickAction(
          icon: Icons.history_outlined,
          title: 'Dose History',
          onTap: _showDoseHistory,
          color: AppColors.darkBlue,
        ),

        _quickAction(
          icon: Icons.warning_amber_rounded,
          title: 'Expiry Alerts',
          onTap: _openExpiryAlerts,
          color: AppColors.warning,
        ),
      ],
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 22),
              ),

              const SizedBox(height: 9),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // REMINDER INFO
  // ===========================================================================

  Widget _buildReminderInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_active_outlined, color: AppColors.primary),

          SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MediShield reminder',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'Your medicine box will remind you '
                  'when a scheduled medicine is due.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // OTHER TABS
  // ===========================================================================

  Widget _buildMedicinesTab() {
    return const MyMedicinesScreen();
  }

  Widget _buildMedicineBoxTab() {
    return const MedicineBoxScreen();
  }

  // ===========================================================================
  // PROFILE TAB
  // ===========================================================================

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: AppColors.lightBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                (_profile['name'] ?? 'Patient').toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                '${(_profile['email'] ?? '').toString()} · MediShield account',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        _profileOption(Icons.person_outline, 'Patient Profile', _openMyProfile),

        _profileOption(
          Icons.notifications_active_outlined,
          'Notifications',
          _openNotifications,
        ),

        _profileOption(
          Icons.notifications_outlined,
          'Notification Settings',
          _openNotificationSettings,
        ),

        _profileOption(
          Icons.family_restroom_outlined,
          'Caretaker Access',
          _openCaretakerAccess,
        ),

        _profileOption(
          Icons.settings_outlined,
          'Settings',
          _openPatientSettings,
        ),

        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            await AuthService.logout(returnToWelcome: true);
          },
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }

  Widget _profileOption(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.secondaryText,
        ),
        onTap: onTap,
      ),
    );
  }

  // ===========================================================================
  // BOTTOM NAVIGATION
  // ===========================================================================

  Widget _buildBottomNavigationBar() {
    return NavigationBar(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (index) {
        setState(() {
          _selectedNavIndex = index;
        });
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),

        NavigationDestination(
          icon: Icon(Icons.medication_outlined),
          selectedIcon: Icon(Icons.medication),
          label: 'Medicines',
        ),

        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: 'Medicine Box',
        ),

        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  // ===========================================================================
  // DOSE HISTORY
  // ===========================================================================

  Future<void> _showDoseHistory() async {
    late final List<DoseEvent> events;
    try {
      final records = await MediShieldRepository.getDoseHistory();
      events = records.map(DoseEvent.fromJson).toList();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }
    if (!mounted) return;

    events.sort((a, b) {
      final aTime = a.eventTime ?? a.scheduledDate;
      final bTime = b.eventTime ?? b.scheduledDate;

      return bTime.compareTo(aTime);
    });

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dose History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Dose history is based on '
                  'MediShield dose events and '
                  'patient confirmations.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.secondaryText,
                  ),
                ),

                const SizedBox(height: 20),

                if (events.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.history_outlined,
                          color: AppColors.secondaryText,
                        ),

                        SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            'No dose events yet.',
                            style: TextStyle(color: AppColors.secondaryText),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: events.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final event = events[index];

                        return _buildDoseHistoryItem(event);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDoseHistoryItem(DoseEvent event) {
    final isTaken = event.status == DoseStatus.takenConfirmed;

    final isOverdue = event.status == DoseStatus.overdueUnconfirmed;

    Color statusColor;

    if (isTaken) {
      statusColor = AppColors.success;
    } else if (isOverdue) {
      statusColor = AppColors.error;
    } else {
      statusColor = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              isTaken
                  ? Icons.check_circle_outline
                  : isOverdue
                  ? Icons.warning_amber_outlined
                  : Icons.schedule_outlined,
              color: statusColor,
              size: 21,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.medicineName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  event.scheduledTime,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),

                if (event.note != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    event.note!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              event.status.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
