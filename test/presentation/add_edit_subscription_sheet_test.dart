import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_track/app/theme/app_theme.dart';
import 'package:sub_track/core/constants/enums.dart';
import 'package:sub_track/features/subscriptions/domain/entities/subscription.dart';
import 'package:sub_track/features/subscriptions/domain/repositories/subscription_repository.dart';
import 'package:sub_track/features/subscriptions/presentation/controllers/providers.dart';
import 'package:sub_track/features/subscriptions/presentation/widgets/add_edit_subscription_sheet.dart';

class _RecordingRepo implements SubscriptionRepository {
  final List<Subscription> rows = <Subscription>[];
  int _nextId = 1;

  final List<String> calls = <String>[];

  @override
  Future<List<Subscription>> getAll() async {
    calls.add('getAll');
    return List.unmodifiable(rows);
  }

  @override
  Future<Subscription> add(Subscription s) async {
    calls.add('add');
    final saved = s.copyWith(id: _nextId++);
    rows.add(saved);
    return saved;
  }

  @override
  Future<void> update(Subscription s) async {
    calls.add('update');
    final idx = rows.indexWhere((r) => r.id == s.id);
    if (idx == -1) {
      rows.add(s);
    } else {
      rows[idx] = s;
    }
  }

  @override
  Future<void> delete(int id) async {
    calls.add('delete');
    rows.removeWhere((r) => r.id == id);
  }
}

Subscription _seed(String name, double cost,
    {BillingCycle cycle = BillingCycle.monthly,
    DateTime? due,
    Category category = Category.streaming,
    String? iconName}) {
  return Subscription(
    id: 1,
    name: name,
    cost: cost,
    billingCycle: cycle,
    nextDueDate: due ?? DateTime(2026, 9, 15),
    category: category,
    iconName: iconName ?? 'streaming',
  );
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required SubscriptionRepository repo,
  Subscription? existing,
}) async {
  // Use a tall viewport so the bottom sheet's save button stays reachable.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        subscriptionRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => AddEditSubscriptionSheet.show(
                  context,
                  existing: existing,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _fillForm(
  WidgetTester tester, {
  required String name,
  required String cost,
  bool switchToYearly = false,
  Category? category,
}) async {
  final nameField = find.byKey(const ValueKey('name-field'));
  expect(nameField, findsOneWidget);
  await tester.enterText(nameField, name);

  final costField = find.byKey(const ValueKey('cost-field'));
  expect(costField, findsOneWidget);
  await tester.enterText(costField, cost);

  if (switchToYearly) {
    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();
  }

  if (category != null) {
    await tester.tap(find.byType(DropdownButtonFormField<Category>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(category.storageId).last);
    await tester.pumpAndSettle();
  }
}

void main() {
  group('AddEditSubscriptionSheet — validation', () {
    testWidgets('empty name shows inline error and keeps sheet open',
        (tester) async {
      final repo = _RecordingRepo();
      await _pumpSheet(tester, repo: repo);

      await _fillForm(tester, name: '', cost: '9.99');
      await tester.tap(find.byKey(const ValueKey('save-button')));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOneWidget);
      expect(repo.calls, isNot(contains('add')));
      expect(find.text('Add subscription'), findsOneWidget);
    });

    testWidgets('whitespace-only name is rejected', (tester) async {
      final repo = _RecordingRepo();
      await _pumpSheet(tester, repo: repo);

      await _fillForm(tester, name: '    ', cost: '9.99');
      await tester.tap(find.byKey(const ValueKey('save-button')));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOneWidget);
      expect(repo.calls, isNot(contains('add')));
    });

    testWidgets(
      'name is capped at 30 characters by the TextFormField maxLength '
      '(OS-level enforcement)',
      (tester) async {
        final repo = _RecordingRepo();
        await _pumpSheet(tester, repo: repo);

        await _fillForm(tester, name: 'A' * 31, cost: '9.99');

        // OS-level truncation: only 30 chars stored. The validator never sees
        // an over-length string, but a counter is rendered so the user knows
        // the cap. This documents the chosen mechanism.
        final nameField =
            tester.widget<TextFormField>(find.byKey(const ValueKey('name-field')));
        expect(nameField.controller!.text.length, 30);

        await tester.tap(find.byKey(const ValueKey('save-button')));
        await tester.pumpAndSettle();
        expect(repo.calls, contains('add'));
      },
    );

    testWidgets('cost = 0 is rejected', (tester) async {
      final repo = _RecordingRepo();
      await _pumpSheet(tester, repo: repo);

      await _fillForm(tester, name: 'X', cost: '0');
      await tester.tap(find.byKey(const ValueKey('save-button')));
      await tester.pumpAndSettle();

      expect(find.text('Must be greater than 0'), findsOneWidget);
      expect(repo.calls, isNot(contains('add')));
    });

    testWidgets(
      'negative sign is filtered by the cost input formatter; '
      'remaining digits > 0 are accepted',
      (tester) async {
        final repo = _RecordingRepo();
        await _pumpSheet(tester, repo: repo);

        // The decimal-only formatter strips the leading "-", so "-5"
        // becomes "5" in the field. That value passes validation (and is
        // preserved on save). This documents the intended behavior.
        await _fillForm(tester, name: 'X', cost: '-5');
        await tester.tap(find.byKey(const ValueKey('save-button')));
        await tester.pumpAndSettle();

        expect(repo.calls, contains('add'));
        expect(repo.rows.single.cost, 5);
      },
    );

    testWidgets('non-numeric cost is rejected', (tester) async {
      final repo = _RecordingRepo();
      await _pumpSheet(tester, repo: repo);

      // FilteringTextInputFormatter strips letters — verify the field
      // itself prevents typing "abc".
      await _fillForm(tester, name: 'X', cost: 'abc');
      // After the formatter, the cost field should be empty.
      expect(find.text('Required'), findsOneWidget);
      expect(repo.calls, isNot(contains('add')));
    });

    testWidgets('cost with currency symbol is accepted', (tester) async {
      final repo = _RecordingRepo();
      await _pumpSheet(tester, repo: repo);

      await _fillForm(tester, name: 'X', cost: r'$14.99');
      await tester.tap(find.byKey(const ValueKey('save-button')));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('add'));
      expect(repo.rows.single.cost, 14.99);
    });
  });

  group('AddEditSubscriptionSheet — add path', () {
    testWidgets('saves a new row, closes the sheet, updates totals',
        (tester) async {
      final repo = _RecordingRepo();
      await _pumpSheet(tester, repo: repo);

      await _fillForm(tester, name: 'Netflix', cost: '14.99');
      await tester.tap(find.byKey(const ValueKey('save-button')));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('add'));
      expect(repo.rows, hasLength(1));
      expect(repo.rows.single.name, 'Netflix');
      expect(repo.rows.single.cost, 14.99);
      expect(repo.rows.single.billingCycle, BillingCycle.monthly);
      expect(repo.rows.single.iconName, 'other',
          reason: 'default category is Other → icon is "other"');
      expect(find.text('Add subscription'), findsNothing,
          reason: 'sheet must close on successful save');
    });
  });

  group('AddEditSubscriptionSheet — edit path', () {
    testWidgets('edit preserves the existing id', (tester) async {
      final repo = _RecordingRepo()..rows.add(_seed('Netflix', 14.99));
      final existing = repo.rows.single;

      await _pumpSheet(tester, repo: repo, existing: existing);

      // The name field is pre-filled.
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('Edit subscription'), findsOneWidget);

      await _fillForm(tester, name: 'Netflix Premium', cost: '22.99');
      await tester.tap(find.byKey(const ValueKey('save-button')));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('update'));
      expect(repo.rows.single.id, existing.id);
      expect(repo.rows.single.name, 'Netflix Premium');
      expect(repo.rows.single.cost, 22.99);
    });
  });

  group('AddEditSubscriptionSheet — cancel', () {
    testWidgets('cancel does not mutate state and closes the sheet',
        (tester) async {
      final repo = _RecordingRepo();
      await _pumpSheet(tester, repo: repo);

      await _fillForm(tester, name: 'X', cost: '9.99');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.calls, isNot(contains('add')));
      expect(find.text('Add subscription'), findsNothing);
    });
  });

  group('AddEditSubscriptionSheet — icon default-tracking', () {
    testWidgets(
      'changing the category moves the icon to that category default '
      'until the user picks explicitly',
      (tester) async {
        final repo = _RecordingRepo();
        await _pumpSheet(tester, repo: repo);

        // Defaults: Category.other → icon "other".
        // Switch to Streaming — default should follow.
        await tester.tap(find.byType(DropdownButtonFormField<Category>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Streaming').last);
        await tester.pumpAndSettle();

        // The icon grid should now have the "streaming" cell selected.
        // Tap a non-default icon (music) to make the pick explicit.
        await tester.tap(find.byIcon(Icons.music_note));
        await tester.pumpAndSettle();

        // Switch category again — explicit pick must NOT move.
        await tester.tap(find.byType(DropdownButtonFormField<Category>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Software').last);
        await tester.pumpAndSettle();

        await _fillForm(tester, name: 'Music', cost: '4.99');
        await tester.tap(find.byKey(const ValueKey('save-button')));
        await tester.pumpAndSettle();

        expect(repo.rows.single.category, Category.software);
        expect(repo.rows.single.iconName, 'music',
            reason: 'explicit icon pick must stick across category changes');
      },
    );

    testWidgets(
      'in edit mode the stored iconName is treated as explicit',
      (tester) async {
        final repo = _RecordingRepo()
          ..rows.add(_seed('Netflix', 14.99,
              category: Category.software, iconName: 'design'));
        final existing = repo.rows.single;

        await _pumpSheet(tester, repo: repo, existing: existing);

        // Changing category should NOT override the explicit 'design' icon.
        await tester.tap(find.byType(DropdownButtonFormField<Category>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fitness').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('save-button')));
        await tester.pumpAndSettle();

        expect(repo.rows.single.category, Category.fitness);
        expect(repo.rows.single.iconName, 'design');
      },
    );
  });
}
