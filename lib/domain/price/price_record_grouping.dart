import 'package:intl/intl.dart';

import '../../data/models/price_record_model.dart';

class DateGroup {
  const DateGroup(this.label, this.records);

  final String label;
  final List<PriceRecordModel> records;
}

List<DateGroup> groupPriceRecordsByDate(
  List<PriceRecordModel> records, {
  DateTime? now,
}) {
  final anchor = now ?? DateTime.now();
  final groups = <String, List<PriceRecordModel>>{};
  for (final record in records) {
    final date = record.createdAt?.toLocal();
    if (date == null) continue;
    final key = _dateLabel(date, anchor);
    groups.putIfAbsent(key, () => []).add(record);
  }
  return groups.entries.map((e) => DateGroup(e.key, e.value)).toList();
}

String dateLabelFor(DateTime date, {DateTime? now}) {
  return _dateLabel(date, now ?? DateTime.now());
}

String _dateLabel(DateTime date, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final target = DateTime(date.year, date.month, date.day);
  final weekday = _weekdayLabel(date);

  if (target == today) return '今日($weekday)';
  if (target == yesterday) return '昨日($weekday)';
  return '${DateFormat('M月d日').format(date)}($weekday)';
}

String _weekdayLabel(DateTime date) {
  const labels = ['月', '火', '水', '木', '金', '土', '日'];
  final index = date.weekday - 1;
  if (index < 0 || index >= labels.length) return '';
  return labels[index];
}
