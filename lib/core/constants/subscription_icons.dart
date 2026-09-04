import 'package:flutter/material.dart';

import 'enums.dart';

const Map<String, IconData> subscriptionIconCatalog = <String, IconData>{
  'streaming': Icons.live_tv,
  'music': Icons.music_note,
  'movie': Icons.movie,
  'software': Icons.code,
  'cloud': Icons.cloud,
  'design': Icons.brush,
  'fitness': Icons.fitness_center,
  'sports': Icons.sports_basketball,
  'health': Icons.favorite,
  'utilities': Icons.bolt,
  'wifi': Icons.wifi,
  'phone': Icons.smartphone,
  'home': Icons.home,
  'news': Icons.menu_book,
  'gaming': Icons.sports_esports,
  'shopping': Icons.shopping_cart,
  'finance': Icons.account_balance,
  'other': Icons.category,
};

const Map<Category, String> categoryDefaultIconId = <Category, String>{
  Category.streaming: 'streaming',
  Category.software: 'software',
  Category.fitness: 'fitness',
  Category.utilities: 'utilities',
  Category.other: 'other',
};

String? canonicalIconId(String? candidate) {
  if (candidate == null) return null;
  return subscriptionIconCatalog.containsKey(candidate) ? candidate : null;
}

IconData resolveIcon({String? iconName, required Category category}) {
  final canonical = canonicalIconId(iconName);
  if (canonical != null) {
    return subscriptionIconCatalog[canonical]!;
  }
  final fallbackId = categoryDefaultIconId[category] ?? 'other';
  return subscriptionIconCatalog[fallbackId]!;
}
