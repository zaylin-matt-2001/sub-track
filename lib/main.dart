import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/theme/app_theme.dart';
import 'core/database/app_database.dart';
import 'features/subscriptions/presentation/controllers/providers.dart';
import 'features/subscriptions/presentation/controllers/subscription_notifier.dart';
import 'features/subscriptions/presentation/screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open();
  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const SubTrackApp(),
    ),
  );
}

class SubTrackApp extends StatelessWidget {
  const SubTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SubTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const _AppResumeRefresher(child: DashboardScreen()),
    );
  }
}

/// Re-reads "today" when the app resumes from background so the relative
/// due-date labels in [DashboardScreen] do not go stale (PRD §4.3, §5.1).
class _AppResumeRefresher extends ConsumerStatefulWidget {
  final Widget child;
  const _AppResumeRefresher({required this.child});

  @override
  ConsumerState<_AppResumeRefresher> createState() =>
      _AppResumeRefresherState();
}

class _AppResumeRefresherState extends ConsumerState<_AppResumeRefresher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Cheap: the notifier's _current is unchanged; this just rebuilds the
      // labels by triggering a re-emission of the same state. (PRD §4.3.)
      ref.invalidate(subscriptionNotifierProvider);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
