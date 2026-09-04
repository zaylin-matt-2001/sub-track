import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sub_track/core/constants/enums.dart';
import 'package:sub_track/core/constants/subscription_icons.dart';

void main() {
  group('subscriptionIconCatalog', () {
    test('contains every PRD §3.2a id with a non-null IconData', () {
      const expectedIds = <String>[
        'streaming',
        'music',
        'movie',
        'software',
        'cloud',
        'design',
        'fitness',
        'sports',
        'health',
        'utilities',
        'wifi',
        'phone',
        'home',
        'news',
        'gaming',
        'shopping',
        'finance',
        'other',
      ];

      for (final id in expectedIds) {
        expect(
          subscriptionIconCatalog.containsKey(id),
          isTrue,
          reason: 'missing icon id: $id',
        );
        expect(
          subscriptionIconCatalog[id],
          isA<IconData>(),
          reason: 'icon id has null data: $id',
        );
      }
    });
  });

  group('categoryDefaultIconId', () {
    test('maps every category per PRD §3.2a', () {
      expect(categoryDefaultIconId[Category.streaming], 'streaming');
      expect(categoryDefaultIconId[Category.software], 'software');
      expect(categoryDefaultIconId[Category.fitness], 'fitness');
      expect(categoryDefaultIconId[Category.utilities], 'utilities');
      expect(categoryDefaultIconId[Category.other], 'other');
    });
  });

  group('canonicalIconId', () {
    test('returns the candidate when it is in the catalog', () {
      expect(canonicalIconId('streaming'), 'streaming');
      expect(canonicalIconId('fitness'), 'fitness');
    });

    test('returns null for unknown or null', () {
      expect(canonicalIconId('not-an-icon'), isNull);
      expect(canonicalIconId(null), isNull);
      expect(canonicalIconId(''), isNull);
    });
  });

  group('resolveIcon', () {
    test('uses the explicit iconName when in catalog', () {
      expect(
        resolveIcon(iconName: 'streaming', category: Category.software),
        subscriptionIconCatalog['streaming'],
      );
    });

    test('falls back to the category default when iconName is unknown', () {
      expect(
        resolveIcon(iconName: 'not-an-icon', category: Category.utilities),
        subscriptionIconCatalog['utilities'],
      );
    });

    test('falls back to the category default when iconName is null', () {
      expect(
        resolveIcon(iconName: null, category: Category.fitness),
        subscriptionIconCatalog['fitness'],
      );
    });

    test('falls back to "other" for unknown category + unknown icon', () {
      expect(
        resolveIcon(iconName: 'nope', category: Category.other),
        subscriptionIconCatalog['other'],
      );
    });
  });
}
