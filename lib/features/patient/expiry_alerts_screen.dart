import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'medicine_store.dart';

class ExpiryAlertsScreen extends StatefulWidget {
  const ExpiryAlertsScreen({
    super.key,
  });

  @override
  State<ExpiryAlertsScreen> createState() =>
      _ExpiryAlertsScreenState();
}

class _ExpiryAlertsScreenState
    extends State<ExpiryAlertsScreen> {
  final MedicineStore _medicineStore =
      MedicineStore.instance;

  @override
  void initState() {
    super.initState();

    _medicineStore.addListener(
      _refreshScreen,
    );
    if (_medicineStore.medicines.isEmpty) {
      _medicineStore.loadFromBackend().catchError((_) {});
    }
  }

  @override
  void dispose() {
    _medicineStore.removeListener(
      _refreshScreen,
    );

    super.dispose();
  }

  void _refreshScreen() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicines = _medicineStore.medicines;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text(
          'Expiry Alerts',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
      ),

      body: _medicineStore.isLoading && medicines.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _medicineStore.errorMessage != null && medicines.isEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_medicineStore.errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _medicineStore.loadFromBackend().catchError((_) {}),
                      child: const Text('Try again'),
                    ),
                  ]),
                ))
          : medicines.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _buildSummaryCard(
                  medicines,
                ),

                const SizedBox(height: 18),

                ..._sortedMedicines(
                  medicines,
                ).map(
                  (medicine) => _buildExpiryCard(
                    medicine,
                  ),
                ),
              ],
            ),
    );
  }

  // ===========================================================================
  // SUMMARY
  // ===========================================================================

  Widget _buildSummaryCard(
    List<Medicine> medicines,
  ) {
    int expired = 0;
    int urgent = 0;
    int soon = 0;
    int valid = 0;
    int unavailable = 0;

    for (final medicine in medicines) {
      final info = _getExpiryInfo(
        medicine.expiryDate,
      );

      switch (info.status) {
        case 'Expired':
          expired++;
          break;

        case 'Urgent':
          urgent++;
          break;

        case 'Soon':
          soon++;
          break;

        case 'Valid':
          valid++;
          break;

        default:
          unavailable++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Medicine Expiry',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            '${medicines.length} medicine'
            '${medicines.length == 1 ? '' : 's'} tracked',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.secondaryText,
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  '$expired',
                  'Expired',
                  AppColors.error,
                ),
              ),

              Expanded(
                child: _summaryItem(
                  '$urgent',
                  'Urgent',
                  AppColors.error,
                ),
              ),

              Expanded(
                child: _summaryItem(
                  '$soon',
                  'Soon',
                  AppColors.warning,
                ),
              ),

              Expanded(
                child: _summaryItem(
                  '$valid',
                  'Valid',
                  AppColors.success,
                ),
              ),
            ],
          ),

          if (unavailable > 0) ...[
            const SizedBox(height: 12),

            Text(
              '$unavailable medicine'
              '${unavailable == 1 ? '' : 's'} '
              'have no expiry date.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryItem(
    String count,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // EXPIRY CARD
  // ===========================================================================

  Widget _buildExpiryCard(
    Medicine medicine,
  ) {
    final info = _getExpiryInfo(
      medicine.expiryDate,
    );

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: info.backgroundColor,
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: Icon(
              info.icon,
              color: info.iconColor,
              size: 27,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),

                if (medicine.strength.isNotEmpty) ...[
                  const SizedBox(height: 3),

                  Text(
                    medicine.strength,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],

                const SizedBox(height: 5),

                Row(
                  children: [
                    Icon(
                      medicine.slot != null
                          ? Icons.inventory_2_outlined
                          : Icons.notifications_none,
                      size: 14,
                      color: AppColors.secondaryText,
                    ),

                    const SizedBox(width: 4),

                    Text(
                      medicine.slot != null
                          ? 'Slot ${medicine.slot}'
                          : 'App Reminder Only',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                Text(
                  _expiryDateText(
                    medicine.expiryDate,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.text,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  info.daysText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: info.iconColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: info.badgeBackgroundColor,
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: Text(
              info.status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: info.badgeTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EXPIRY CALCULATION
  // ===========================================================================

  _ExpiryInfo _getExpiryInfo(
    DateTime? expiryDate,
  ) {
    if (expiryDate == null) {
      return const _ExpiryInfo(
        status: 'Check',
        daysText: 'Expiry date unavailable',
        icon: Icons.help_outline,
        iconColor: AppColors.secondaryText,
        backgroundColor: AppColors.background,
        badgeBackgroundColor: AppColors.background,
        badgeTextColor: AppColors.secondaryText,
      );
    }

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final expiry = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );

    final difference =
        expiry.difference(today).inDays;

    // -------------------------------------------------------------------------
    // EXPIRED
    // -------------------------------------------------------------------------

    if (difference < 0) {
      final days = difference.abs();

      return _ExpiryInfo(
        status: 'Expired',
        daysText:
            'Expired $days ${days == 1 ? 'day' : 'days'} ago',
        icon: Icons.error_outline,
        iconColor: AppColors.error,
        backgroundColor:
            AppColors.error.withValues(
          alpha: 0.10,
        ),
        badgeBackgroundColor:
            AppColors.error.withValues(
          alpha: 0.12,
        ),
        badgeTextColor: AppColors.error,
      );
    }

    // -------------------------------------------------------------------------
    // TODAY
    // -------------------------------------------------------------------------

    if (difference == 0) {
      return _ExpiryInfo(
        status: 'Urgent',
        daysText: 'Expires today',
        icon: Icons.warning_amber_rounded,
        iconColor: AppColors.error,
        backgroundColor:
            AppColors.error.withValues(
          alpha: 0.10,
        ),
        badgeBackgroundColor:
            AppColors.error.withValues(
          alpha: 0.12,
        ),
        badgeTextColor: AppColors.error,
      );
    }

    // -------------------------------------------------------------------------
    // 1–7 DAYS
    // -------------------------------------------------------------------------

    if (difference <= 7) {
      return _ExpiryInfo(
        status: 'Urgent',
        daysText:
            'Expires in $difference '
            '${difference == 1 ? 'day' : 'days'}',
        icon: Icons.warning_amber_rounded,
        iconColor: AppColors.error,
        backgroundColor:
            AppColors.error.withValues(
          alpha: 0.10,
        ),
        badgeBackgroundColor:
            AppColors.error.withValues(
          alpha: 0.12,
        ),
        badgeTextColor: AppColors.error,
      );
    }

    // -------------------------------------------------------------------------
    // 8–30 DAYS
    // -------------------------------------------------------------------------

    if (difference <= 30) {
      return _ExpiryInfo(
        status: 'Soon',
        daysText:
            'Expires in $difference days',
        icon: Icons.event_available_outlined,
        iconColor: AppColors.warning,
        backgroundColor:
            AppColors.warning.withValues(
          alpha: 0.12,
        ),
        badgeBackgroundColor:
            AppColors.warning.withValues(
          alpha: 0.12,
        ),
        badgeTextColor: AppColors.warning,
      );
    }

    // -------------------------------------------------------------------------
    // MORE THAN 30 DAYS
    // -------------------------------------------------------------------------

    return _ExpiryInfo(
      status: 'Valid',
      daysText:
          'Expires in $difference days',
      icon: Icons.calendar_month_outlined,
      iconColor: AppColors.success,
      backgroundColor:
          AppColors.success.withValues(
        alpha: 0.10,
      ),
      badgeBackgroundColor:
          AppColors.success.withValues(
        alpha: 0.12,
      ),
      badgeTextColor: AppColors.success,
    );
  }

  // ===========================================================================
  // DATE DISPLAY
  // ===========================================================================

  String _expiryDateText(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Expiry date not available';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return 'Expiry: '
        '${months[date.month - 1]} '
        '${date.day}, '
        '${date.year}';
  }

  // ===========================================================================
  // SORTING
  // ===========================================================================

  List<Medicine> _sortedMedicines(
    List<Medicine> medicines,
  ) {
    final sorted = [...medicines];

    sorted.sort(
      (a, b) {
        if (a.expiryDate == null &&
            b.expiryDate == null) {
          return 0;
        }

        if (a.expiryDate == null) {
          return 1;
        }

        if (b.expiryDate == null) {
          return -1;
        }

        return a.expiryDate!.compareTo(
          b.expiryDate!,
        );
      },
    );

    return sorted;
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius:
                    BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'No medicines added',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Add medicines to see their expiry '
              'information here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// EXPIRY INFO MODEL
// =============================================================================

class _ExpiryInfo {
  final String status;
  final String daysText;
  final IconData icon;

  final Color iconColor;
  final Color backgroundColor;

  final Color badgeBackgroundColor;
  final Color badgeTextColor;

  const _ExpiryInfo({
    required this.status,
    required this.daysText,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.badgeBackgroundColor,
    required this.badgeTextColor,
  });
}
