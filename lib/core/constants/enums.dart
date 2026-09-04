enum BillingCycle {
  monthly,
  yearly;

  String get storageId => name;

  static BillingCycle fromStorage(String? raw) {
    for (final cycle in BillingCycle.values) {
      if (cycle.storageId == raw) return cycle;
    }
    return BillingCycle.monthly;
  }
}

enum Category {
  streaming,
  software,
  fitness,
  utilities,
  other;

  String get storageId {
    switch (this) {
      case Category.streaming:
        return 'Streaming';
      case Category.software:
        return 'Software';
      case Category.fitness:
        return 'Fitness';
      case Category.utilities:
        return 'Utilities';
      case Category.other:
        return 'Other';
    }
  }

  static Category fromStorage(String? raw) {
    for (final category in Category.values) {
      if (category.storageId == raw) return category;
    }
    return Category.other;
  }
}
