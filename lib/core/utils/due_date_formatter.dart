import 'package:intl/intl.dart';

enum DueDateSeverity { normal, warning, error }

class DueDateLabel {
  final String text;
  final DueDateSeverity severity;

  const DueDateLabel(this.text, this.severity);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DueDateLabel dueDateLabel(DateTime dueDate, DateTime today) {
  final due = _dateOnly(dueDate);
  final ref = _dateOnly(today);
  final diffDays = due.difference(ref).inDays;

  if (diffDays == 0) {
    return const DueDateLabel('Due today', DueDateSeverity.warning);
  }
  if (diffDays < 0) {
    final overdueBy = -diffDays;
    final unit = overdueBy == 1 ? 'day' : 'days';
    return DueDateLabel('Overdue by $overdueBy $unit', DueDateSeverity.error);
  }
  if (diffDays == 1) {
    return const DueDateLabel('Tomorrow', DueDateSeverity.normal);
  }
  if (diffDays <= 7) {
    return DueDateLabel('In $diffDays days', DueDateSeverity.normal);
  }
  final formatted = DateFormat.MMMd().format(due);
  return DueDateLabel('Next bill: $formatted', DueDateSeverity.normal);
}
