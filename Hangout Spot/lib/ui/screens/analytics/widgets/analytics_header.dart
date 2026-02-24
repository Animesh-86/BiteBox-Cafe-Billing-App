import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/ui/screens/analytics/theme/analytics_theme.dart';
import 'package:hangout_spot/ui/screens/analytics/utils/date_filter_utils.dart';
import 'package:hangout_spot/logic/locations/location_provider.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/ui/screens/analytics/providers/analytics_data_provider.dart';
import 'package:intl/intl.dart';

class AnalyticsHeader extends ConsumerWidget {
  final String title;
  final VoidCallback onMenuPressed;
  final DateFilter currentFilter;
  final Function(DateFilter) onFilterChanged;
  final VoidCallback? onExportPressed;
  final bool isExporting;

  const AnalyticsHeader({
    super.key,
    required this.title,
    required this.onMenuPressed,
    required this.currentFilter,
    required this.onFilterChanged,
    this.onExportPressed,
    this.isExporting = false,
  });

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: currentFilter.startDate,
        end: currentFilter.endDate,
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AnalyticsTheme.primaryGold,
              surface: AnalyticsTheme.cardBackground,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onFilterChanged(DateFilter.custom(picked.start, picked.end));
    }
  }

  void _showDateFilterSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AnalyticsTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Date Range',
                style: TextStyle(
                  color: AnalyticsTheme.primaryGold,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterOption(context, 'Today', DateFilter.today()),
                  _buildFilterOption(
                    context,
                    'Yesterday',
                    DateFilter.yesterday(),
                  ),
                  _buildFilterOption(context, 'This Week', DateFilter.thisWeek()),
                  _buildFilterOption(
                    context,
                    'This Month',
                  DateFilter.thisMonth(),
                ),
                _buildFilterOption(context, 'This Year', DateFilter.thisYear()),
                _buildFilterOption(
                  context,
                  'Last 7 Days',
                  DateFilter.last7Days(),
                ),
                _buildFilterOption(
                  context,
                  'Last 30 Days',
                  DateFilter.last30Days(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _selectDateRange(context);
                },
                icon: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.black,
                ),
                label: const Text(
                  'Custom Range',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AnalyticsTheme.primaryGold,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(
    BuildContext context,
    String label,
    DateFilter filter,
  ) {
    final isSelected = currentFilter.type == filter.type;
    return InkWell(
      onTap: () {
        onFilterChanged(filter);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AnalyticsTheme.primaryGold
              : AnalyticsTheme.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AnalyticsTheme.primaryGold.withOpacity(isSelected ? 1 : 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AnalyticsTheme.primaryText,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _showOutletSelector(
    BuildContext context,
    WidgetRef ref,
    Location? currentOutlet,
  ) async {
    final locations = await ref.read(locationsStreamProvider.future);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AnalyticsTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Outlet',
                style: TextStyle(
                  color: AnalyticsTheme.primaryGold,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: currentOutlet == null
                        ? AnalyticsTheme.primaryGold.withOpacity(0.2)
                        : AnalyticsTheme.secondaryBeige.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.store_mall_directory_rounded,
                    color: currentOutlet == null
                        ? AnalyticsTheme.primaryGold
                      : AnalyticsTheme.secondaryText,
                ),
              ),
              title: Text(
                'All Outlets',
                style: TextStyle(
                  color: currentOutlet == null
                      ? AnalyticsTheme.primaryGold
                      : AnalyticsTheme.primaryText,
                  fontWeight: currentOutlet == null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              trailing: currentOutlet == null
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AnalyticsTheme.primaryGold,
                    )
                  : null,
              onTap: () {
                ref.read(analyticsSelectedOutletProvider.notifier).state = null;
                Navigator.pop(context);
              },
            ),
            const Divider(color: Colors.white12),
            ...locations.map(
              (location) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: location.id == currentOutlet?.id
                        ? AnalyticsTheme.primaryGold.withOpacity(0.2)
                        : AnalyticsTheme.secondaryBeige.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    color: location.id == currentOutlet?.id
                        ? AnalyticsTheme.primaryGold
                        : AnalyticsTheme.secondaryText,
                  ),
                ),
                title: Text(
                  location.name,
                  style: TextStyle(
                    color: location.id == currentOutlet?.id
                        ? AnalyticsTheme.primaryGold
                        : AnalyticsTheme.primaryText,
                    fontWeight: location.id == currentOutlet?.id
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle:
                    location.address != null && location.address!.isNotEmpty
                    ? Text(
                        location.address!,
                        style: TextStyle(
                          color: AnalyticsTheme.secondaryText,
                          fontSize: 12,
                        ),
                      )
                    : null,
                trailing: location.id == currentOutlet?.id
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AnalyticsTheme.primaryGold,
                      )
                    : null,
                onTap: () {
                  ref.read(analyticsSelectedOutletProvider.notifier).state =
                      location;
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFilterLabel() {
    switch (currentFilter.type) {
      case DateFilterType.today:
        return 'Today';
      case DateFilterType.yesterday:
        return 'Yesterday';
      case DateFilterType.thisWeek:
        return 'This Week';
      case DateFilterType.thisMonth:
        return 'This Month';
      case DateFilterType.thisYear:
        return 'This Year';
      case DateFilterType.last7Days:
        return 'Last 7 Days';
      case DateFilterType.last30Days:
        return 'Last 30 Days';
      case DateFilterType.custom:
        final format = DateFormat('dd MMM');
        return '${format.format(currentFilter.startDate)} - ${format.format(currentFilter.endDate)}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOutlet = ref.watch(analyticsSelectedOutletProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AnalyticsTheme.cardBackground.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(color: AnalyticsTheme.borderColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Menu | Title | Export
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AnalyticsTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AnalyticsTheme.borderColor),
                ),
                child: IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  color: AnalyticsTheme.primaryGold,
                  onPressed: onMenuPressed,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AnalyticsTheme.primaryGold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (isExporting)
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AnalyticsTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AnalyticsTheme.borderColor),
                  ),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AnalyticsTheme.primaryGold,
                    ),
                  ),
                )
              else if (onExportPressed != null)
                Container(
                  decoration: BoxDecoration(
                    color: AnalyticsTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AnalyticsTheme.borderColor),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.download_rounded),
                    color: AnalyticsTheme.primaryGold,
                    tooltip: 'Export to Excel',
                    onPressed: onExportPressed,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                )
              else
                const SizedBox(width: 40, height: 40),
            ],
          ),
          const SizedBox(height: 16),
          // Bottom Row: Outlet Selector | Date Selector
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showOutletSelector(context, ref, activeOutlet),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: AnalyticsTheme.glassCard().copyWith(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AnalyticsTheme.primaryGold.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          activeOutlet == null
                              ? Icons.store_mall_directory_rounded
                              : Icons.store_rounded,
                          color: AnalyticsTheme.primaryGold,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Outlet',
                                style: TextStyle(
                                  color: AnalyticsTheme.secondaryText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeOutlet?.name ?? 'All Outlets',
                                style: const TextStyle(
                                  color: AnalyticsTheme.primaryText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (activeOutlet?.address != null &&
                                  activeOutlet!.address!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    activeOutlet.address!,
                                    style: TextStyle(
                                      color: AnalyticsTheme.secondaryText,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AnalyticsTheme.primaryGold,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _showDateFilterSelector(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: AnalyticsTheme.glassCard().copyWith(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AnalyticsTheme.primaryGold.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: AnalyticsTheme.primaryGold,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Duration',
                                style: TextStyle(
                                  color: AnalyticsTheme.secondaryText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getFilterLabel(),
                                style: const TextStyle(
                                  color: AnalyticsTheme.primaryText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AnalyticsTheme.primaryGold,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
