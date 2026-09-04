import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/exchange_rate_notifier.dart';
import '../controllers/settings_notifier.dart';

const _currencies = <String>['USD', 'EUR', 'GBP', 'JPY', 'MMK', 'AUD', 'CAD'];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  String? _baseCurrency;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initialize(SettingsState settings, Map<String, double> rates) {
    if (_initialized) return;
    _initialized = true;
    _baseCurrency = _currencies.contains(settings.baseCurrency)
        ? settings.baseCurrency
        : 'USD';
    for (final code in _currencies) {
      final rate = rates[code];
      _controllers[code] = TextEditingController(
        text: rate == null ? '' : rate.toString(),
      );
    }
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final rates = <String, double>{
      for (final entry in _controllers.entries)
        if (entry.key != _baseCurrency && entry.value.text.trim().isNotEmpty)
          entry.key: double.parse(entry.value.text.trim()),
    };
    try {
      await ref
          .read(settingsNotifierProvider.notifier)
          .setBaseCurrency(_baseCurrency!);
      await ref.read(exchangeRateNotifierProvider.notifier).replaceRates(rates);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Settings saved')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save settings. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsNotifierProvider);
    final rates = ref.watch(exchangeRateNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Failed to load settings: $error')),
        data: (settingsData) => rates.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              Center(child: Text('Failed to load rates: $error')),
          data: (rateData) {
            _initialize(settingsData, rateData);
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _baseCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Base currency',
                      border: OutlineInputBorder(),
                    ),
                    items: _currencies
                        .map(
                          (code) =>
                              DropdownMenuItem(value: code, child: Text(code)),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _baseCurrency = value),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Exchange rates to $_baseCurrency',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter how much one unit of each currency is worth in $_baseCurrency. Leave blank for a 1:1 fallback.',
                  ),
                  const SizedBox(height: 16),
                  for (final entry in _controllers.entries.where(
                    (entry) => entry.key != _baseCurrency,
                  )) ...[
                    TextFormField(
                      controller: entry.value,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: '${entry.key} → $_baseCurrency',
                        hintText: 'e.g. 1.10',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final rate = double.tryParse(value.trim());
                        if (rate == null || !rate.isFinite || rate <= 0) {
                          return 'Enter a rate greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Save settings'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
