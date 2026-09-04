import 'package:flutter/material.dart';

import '../../../../core/constants/subscription_icons.dart';

class IconPicker extends StatelessWidget {
  final String? selectedId;
  final ValueChanged<String> onChanged;

  const IconPicker({
    super.key,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final entries = subscriptionIconCatalog.entries.toList(growable: false);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final id = entries[i].key;
        final icon = entries[i].value;
        final selected = id == selectedId;
        return InkResponse(
          onTap: () => onChanged(id),
          radius: 24,
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: selected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary, width: 2)
                  : null,
            ),
            child: Icon(
              icon,
              color: selected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}
