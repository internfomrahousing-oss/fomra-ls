import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';

String formatCallDateTime(DateTime dt) {
  final local = dt.toLocal();
  return '${local.day}/${local.month}/${local.year} '
      '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
}

String formatLogDate(DateTime dt) {
  final local = dt.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

String formatLogTime(DateTime dt) {
  final local = dt.toLocal();
  return '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
}

Future<DateTime?> pickLogDate(BuildContext context, DateTime current) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: current,
    firstDate: DateTime(2020),
    lastDate: DateTime(now.year + 1),
  );
  if (date == null) return null;
  return DateTime(date.year, date.month, date.day, current.hour, current.minute);
}

Future<DateTime?> pickLogTime(BuildContext context, DateTime current) async {
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current),
  );
  if (time == null) return null;
  return DateTime(
    current.year,
    current.month,
    current.day,
    time.hour,
    time.minute,
  );
}

class SeparateDateTimeFields extends StatelessWidget {
  final DateTime value;
  final VoidCallback onEditDate;
  final VoidCallback onEditTime;

  const SeparateDateTimeFields({
    super.key,
    required this.value,
    required this.onEditDate,
    required this.onEditTime,
  });

  @override
  Widget build(BuildContext context) {
    final stack = MediaQuery.sizeOf(context).width < 360;

    final dateField = _DateTimePartField(
      label: 'Date',
      value: formatLogDate(value),
      onEdit: onEditDate,
    );
    final timeField = _DateTimePartField(
      label: 'Time',
      value: formatLogTime(value),
      onEdit: onEditTime,
    );

    if (stack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          dateField,
          const SizedBox(height: 8),
          timeField,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: dateField),
        const SizedBox(width: 8),
        Expanded(child: timeField),
      ],
    );
  }
}

class _DateTimePartField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onEdit;

  const _DateTimePartField({
    required this.label,
    required this.value,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: context.fomraSurfaceVar.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.fomraBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: context.fomraTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.fomraTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }
}
