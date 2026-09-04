import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/constants/subscription_icons.dart';
import '../../domain/entities/subscription.dart';
import '../../../settings/presentation/controllers/settings_notifier.dart';
import '../controllers/subscription_notifier.dart';
import 'icon_picker.dart';

const int _nameMaxLength = 30;
const double _dateMinYearsBack = 1;
const double _dateMaxYearsAhead = 5;
const _currencyCodes = <String>[
  'USD',
  'EUR',
  'GBP',
  'JPY',
  'MMK',
  'AUD',
  'CAD',
];

class AddEditSubscriptionSheet extends ConsumerStatefulWidget {
  final Subscription? existing;
  final DateTime Function() todayResolver;

  const AddEditSubscriptionSheet({
    super.key,
    this.existing,
    this.todayResolver = _defaultToday,
  });

  static DateTime _defaultToday() => DateTime.now();

  static Future<void> show(BuildContext context, {Subscription? existing}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: AddEditSubscriptionSheet(existing: existing),
      ),
    );
  }

  @override
  ConsumerState<AddEditSubscriptionSheet> createState() =>
      _AddEditSubscriptionSheetState();
}

class _AddEditSubscriptionSheetState
    extends ConsumerState<AddEditSubscriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtl;
  late final TextEditingController _costCtl;
  late BillingCycle _cycle;
  late Category _category;
  late DateTime _dueDate;
  String? _iconId;
  bool _iconPickedExplicitly = false;
  bool _saving = false;
  late bool _isActive;
  late String _currencyCode;
  bool _currencyPickedExplicitly = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtl = TextEditingController(text: e.name);
      _costCtl = TextEditingController(text: _costToString(e.cost));
      _cycle = e.billingCycle;
      _category = e.category;
      _dueDate = e.nextDueDate;
      _iconId = e.iconName ?? categoryDefaultIconId[e.category];
      _iconPickedExplicitly = e.iconName != null;
      _isActive = e.isActive;
      _currencyCode = e.currencyCode.toUpperCase();
      _currencyPickedExplicitly = true;
    } else {
      _nameCtl = TextEditingController();
      _costCtl = TextEditingController();
      _cycle = BillingCycle.monthly;
      _category = Category.other;
      _dueDate = _todayDateOnly();
      _iconId = categoryDefaultIconId[_category];
      _iconPickedExplicitly = false;
      _isActive = true;
      _currencyCode = 'USD';
    }
  }

  DateTime _todayDateOnly() {
    final now = widget.todayResolver();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _costCtl.dispose();
    super.dispose();
  }

  void _onCategoryChanged(Category next) {
    setState(() {
      _category = next;
      if (!_iconPickedExplicitly) {
        _iconId = categoryDefaultIconId[next];
      }
    });
  }

  void _onIconPicked(String id) {
    setState(() {
      _iconId = id;
      _iconPickedExplicitly = true;
    });
  }

  Future<void> _pickDate() async {
    final today = _todayDateOnly();
    final first = DateTime(
      today.year - _dateMinYearsBack.toInt(),
      today.month,
      today.day,
    );
    final last = DateTime(
      today.year + _dateMaxYearsAhead.toInt(),
      today.month,
      today.day,
    );
    final initial = _dueDate.isBefore(first)
        ? first
        : (_dueDate.isAfter(last) ? last : _dueDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  String? _validateName(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return 'Required';
    if (v.length > _nameMaxLength) return 'Max $_nameMaxLength characters';
    return null;
  }

  String? _validateCost(String? raw) {
    final cleaned = (raw ?? '').replaceAll(RegExp(r'[\$,\s]'), '');
    if (cleaned.isEmpty) return 'Required';
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return 'Enter a number';
    if (parsed.isNaN || parsed.isInfinite) return 'Enter a valid number';
    if (parsed <= 0) return 'Must be greater than 0';
    return null;
  }

  double _parseCost(String raw) =>
      double.parse(raw.replaceAll(RegExp(r'[\$,\s]'), ''));

  String _effectiveCurrencyCode() {
    if (_isEdit || _currencyPickedExplicitly) return _currencyCode;
    return ref.read(settingsNotifierProvider).valueOrNull?.baseCurrency ??
        'USD';
  }

  Future<void> _onSave() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_iconId == null || !subscriptionIconCatalog.containsKey(_iconId)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pick an icon')));
      return;
    }

    setState(() => _saving = true);
    final cost = _parseCost(_costCtl.text);
    final name = _nameCtl.text.trim();
    final notifier = ref.read(subscriptionNotifierProvider.notifier);

    try {
      if (_isEdit) {
        final updated = widget.existing!.copyWith(
          name: name,
          cost: cost,
          billingCycle: _cycle,
          nextDueDate: _dueDate,
          category: _category,
          iconName: _iconId,
          isActive: _isActive,
          currencyCode: _effectiveCurrencyCode(),
        );
        await notifier.updateSubscription(updated);
      } else {
        final entity = Subscription(
          name: name,
          cost: cost,
          billingCycle: _cycle,
          nextDueDate: _dueDate,
          category: _category,
          iconName: _iconId,
          isActive: _isActive,
          currencyCode: _effectiveCurrencyCode(),
        );
        await notifier.addSubscription(entity);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
  }

  void _onCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseCurrency =
        ref.watch(settingsNotifierProvider).valueOrNull?.baseCurrency ?? 'USD';
    final displayedCurrency = _isEdit || _currencyPickedExplicitly
        ? _currencyCode
        : baseCurrency;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    _isEdit ? 'Edit subscription' : 'Add subscription',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _saving ? null : _onCancel,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('name-field'),
                controller: _nameCtl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                maxLength: _nameMaxLength,
                textInputAction: TextInputAction.next,
                validator: _validateName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('cost-field'),
                controller: _costCtl,
                decoration: InputDecoration(
                  labelText: 'Cost',
                  prefixText: '$displayedCurrency ',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\.\$,\s]')),
                ],
                validator: _validateCost,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('currency-field'),
                initialValue: displayedCurrency,
                decoration: const InputDecoration(
                  labelText: 'Subscription currency',
                  border: OutlineInputBorder(),
                ),
                items: _currencyCodes
                    .map(
                      (code) =>
                          DropdownMenuItem(value: code, child: Text(code)),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (code) {
                        if (code == null) return;
                        setState(() {
                          _currencyCode = code;
                          _currencyPickedExplicitly = true;
                        });
                      },
              ),
              const SizedBox(height: 12),
              SegmentedButton<BillingCycle>(
                segments: const [
                  ButtonSegment(
                    value: BillingCycle.monthly,
                    label: Text('Monthly'),
                  ),
                  ButtonSegment(
                    value: BillingCycle.yearly,
                    label: Text('Yearly'),
                  ),
                ],
                selected: {_cycle},
                onSelectionChanged: (set) => setState(() => _cycle = set.first),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Category>(
                // ignore: deprecated_member_use
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: Category.values
                    .map(
                      (c) => DropdownMenuItem<Category>(
                        value: c,
                        child: Text(c.storageId),
                      ),
                    )
                    .toList(),
                onChanged: (c) {
                  if (c != null) _onCategoryChanged(c);
                },
              ),
              const SizedBox(height: 16),
              Text('Icon', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              IconPicker(selectedId: _iconId, onChanged: _onIconPicked),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                key: const ValueKey('active-switch'),
                title: Text(
                  _isActive ? 'Active' : 'Paused',
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: Text(
                  _isActive
                      ? 'Counts toward monthly and yearly burn rate.'
                      : 'Excluded from burn rate until reactivated.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                value: _isActive,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Next due date',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_dueDate.year.toString().padLeft(4, '0')}-'
                        '${_dueDate.month.toString().padLeft(2, '0')}-'
                        '${_dueDate.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _saving ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Pick'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _onCancel,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('save-button'),
                      onPressed: _saving ? null : _onSave,
                      child: Text(
                        _saving
                            ? 'Saving…'
                            : (_isEdit ? 'Save changes' : 'Save'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _costToString(double c) {
  if (c == c.truncateToDouble()) return c.toStringAsFixed(1);
  return c.toString();
}
