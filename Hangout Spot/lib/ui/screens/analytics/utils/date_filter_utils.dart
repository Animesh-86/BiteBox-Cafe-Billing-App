import 'package:flutter/material.dart';

enum DateFilterType {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  thisYear,
  last7Days,
  last30Days,
  custom,
}

class DateFilter {
  final DateFilterType type;
  final DateTime startDate;
  final DateTime endDate;
  final String label;

  DateFilter({
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.label,
  });

  factory DateFilter.today([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return DateFilter(
      type: DateFilterType.today,
      startDate: start,
      endDate: now,
      label: 'Today',
    );
  }

  factory DateFilter.yesterday([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final start = DateTime(yesterday.year, yesterday.month, yesterday.day);
    final end = DateTime(
      yesterday.year,
      yesterday.month,
      yesterday.day,
      23,
      59,
      59,
    );
    return DateFilter(
      type: DateFilterType.yesterday,
      startDate: start,
      endDate: end,
      label: 'Yesterday',
    );
  }

  factory DateFilter.thisWeek([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final weekday = now.weekday; // 1 = Monday, 7 = Sunday
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: weekday - 1));
    final end = now;
    return DateFilter(
      type: DateFilterType.thisWeek,
      startDate: start,
      endDate: end,
      label: 'This Week',
    );
  }

  factory DateFilter.thisMonth([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = now;
    return DateFilter(
      type: DateFilterType.thisMonth,
      startDate: start,
      endDate: end,
      label: 'This Month',
    );
  }

  factory DateFilter.thisYear([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = now;
    return DateFilter(
      type: DateFilterType.thisYear,
      startDate: start,
      endDate: end,
      label: 'This Year',
    );
  }

  factory DateFilter.last7Days([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final end = now;
    final start = now.subtract(const Duration(days: 6));
    return DateFilter(
      type: DateFilterType.last7Days,
      startDate: start,
      endDate: end,
      label: 'Last 7 Days',
    );
  }

  factory DateFilter.last30Days([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final end = now;
    final start = now.subtract(const Duration(days: 29));
    return DateFilter(
      type: DateFilterType.last30Days,
      startDate: start,
      endDate: end,
      label: 'Last 30 Days',
    );
  }

  factory DateFilter.custom(DateTime start, DateTime end) {
    return DateFilter(
      type: DateFilterType.custom,
      startDate: start,
      endDate: end,
      label: 'Custom Range',
    );
  }

  static List<DateFilter> getPresets() {
    return [
      DateFilter.yesterday(),
      DateFilter.thisWeek(),
      DateFilter.thisMonth(),
      DateFilter.thisYear(),
    ];
  }
}

class DateFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const DateFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD4A574).withOpacity(0.2)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? const Color(0xFFD4A574)
                : Colors.white.withOpacity(0.2),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFFD4A574)
                : const Color(0xFFEAE0D5),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
