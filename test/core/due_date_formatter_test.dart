import 'package:flutter_test/flutter_test.dart';
import 'package:sub_track/core/utils/due_date_formatter.dart';

DateTime _d(int y, int m, int d, [int h = 0, int mi = 0]) =>
    DateTime(y, m, d, h, mi);

void main() {
  final today = _d(2026, 9, 15);

  group('dueDateLabel — PRD §4.3 branches', () {
    test('dueDate == today → "Due today" (warning)', () {
      final label = dueDateLabel(_d(2026, 9, 15), today);
      expect(label.text, 'Due today');
      expect(label.severity, DueDateSeverity.warning);
    });

    test('time-of-day on today is ignored (23:59 same day → "Due today")', () {
      final label = dueDateLabel(_d(2026, 9, 15, 23, 59), today);
      expect(label.text, 'Due today');
      expect(label.severity, DueDateSeverity.warning);
    });

    test('dueDate 1 day past → "Overdue by 1 day" (error)', () {
      final label = dueDateLabel(_d(2026, 9, 14), today);
      expect(label.text, 'Overdue by 1 day');
      expect(label.severity, DueDateSeverity.error);
    });

    test('dueDate 3 days past → "Overdue by 3 days" (error)', () {
      final label = dueDateLabel(_d(2026, 9, 12), today);
      expect(label.text, 'Overdue by 3 days');
      expect(label.severity, DueDateSeverity.error);
    });

    test('dueDate == today + 1 → "Tomorrow" (normal)', () {
      final label = dueDateLabel(_d(2026, 9, 16), today);
      expect(label.text, 'Tomorrow');
      expect(label.severity, DueDateSeverity.normal);
    });

    test('dueDate within 2..7 days → "In N days" (normal)', () {
      expect(dueDateLabel(_d(2026, 9, 17), today).text, 'In 2 days');
      expect(dueDateLabel(_d(2026, 9, 20), today).text, 'In 5 days');
      expect(dueDateLabel(_d(2026, 9, 22), today).text, 'In 7 days');
    });

    test('dueDate > today + 7 → "Next bill: MMM dd" (normal)', () {
      final label = dueDateLabel(_d(2026, 10, 15), today);
      expect(label.text, 'Next bill: Oct 15');
      expect(label.severity, DueDateSeverity.normal);
    });

    test('cross-month future date formats abbreviated month correctly', () {
      final label = dueDateLabel(_d(2027, 1, 5), today);
      expect(label.text, 'Next bill: Jan 5');
    });
  });

  group('dueDateLabel — time normalization', () {
    test('ignores time component on today reference', () {
      final lateToday = _d(2026, 9, 15, 0, 1);
      final label = dueDateLabel(_d(2026, 9, 15), lateToday);
      expect(label.text, 'Due today');
    });
  });
}
