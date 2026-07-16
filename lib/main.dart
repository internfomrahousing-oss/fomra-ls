import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_link.dart';
import 'services/auth_service.dart';
import 'services/session_scoped_local_storage.dart';
import 'services/push_service.dart';
import 'services/offline_sync_service.dart';
import 'services/lead_drop_reason_catalog_service.dart';
import 'services/profile_photo_service.dart';
import 'services/supabase_config.dart';
import 'services/theme_controller.dart';
import 'services/role_access.dart';
import 'services/view_scope.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/set_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/land_lead/land_workspace_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/audit/audit_trail_screen.dart';
import 'screens/notifications/notification_center_screen.dart';
import 'screens/task_management/task_management_screen.dart';
import 'screens/settings/change_password_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/broker/broker_management_screen.dart';
import 'screens/legal/legal_tracker_screen.dart';
import 'screens/legal_verification/legal_verification_screen.dart';
import 'screens/survey/survey_tracker_screen.dart';
import 'screens/owner/owner_history_screen.dart';
import 'screens/cost/cost_calculator_screen.dart';

void main() {
  // Snapshot the launch URL before Flutter's hash router can rewrite the
  // fragment (invite / recovery tokens live there).
  AuthLink.capture();
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = FlutterError.presentError;
    await ThemeController.instance.load();
    // Restore the Reporting Manager / Head Team-vs-Individual selection before
    // the first frame so their view doesn't flip after load.
    await ViewScope.instance.load();
    runApp(const FomraLSApp());
  }, (error, stack) {
    debugPrint('ZONE ERROR: $error\n$stack');
  });
}

class FomraLSApp extends StatelessWidget {
  const FomraLSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'FomraLS',
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        darkTheme: appThemeDark(),
        themeMode: themeMode,
        // Slightly larger global type (~8%) without touching per-widget sizes,
        // so existing spacing/layout is preserved. Still honours the OS
        // accessibility setting, just with a raised floor.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: mq.textScaler.clamp(
                minScaleFactor: 1.08,
                maxScaleFactor: 1.3,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const _StartupScreen(),
        routes: {
          '/login':               (_) => const LoginScreen(),
          '/set-password':        (_) => const SetPasswordScreen(),
          '/home':                (_) => const HomeScreen(),
          '/employee-portal':     (_) => const TaskManagementScreen(
                                      portalMode: TaskPortalMode.employee),
          '/management-portal':   (_) => const TaskManagementScreen(
                                      portalMode: TaskPortalMode.management),
          '/land-lead':           (_) => const LandWorkspaceScreen(initialTab: 0),
          '/employee-management': (_) => const SettingsScreen(),
          '/task-management':     (_) => const LandWorkspaceScreen(initialTab: 0),
          '/market-intelligence': (_) => const HomeScreen(),
          '/legal-verification':  (_) => const LegalVerificationScreen(),
          '/broker-management':   (_) => const BrokerManagementScreen(),
          '/legal-tracker':       (_) => const LegalTrackerScreen(),
          '/survey-tracker':      (_) => const SurveyTrackerScreen(),
          '/owner-history':       (_) => const OwnerHistoryScreen(),
          '/cost-calculator':     (_) => const CostCalculatorScreen(),
          '/reports':             (_) => const ReportsScreen(),
          '/notifications':       (_) => const NotificationCenterScreen(),
          '/audit-trail':         (_) => RoleAccess.canViewAudit
                                      ? const AuditTrailScreen()
                                      : const HomeScreen(),
          '/settings':            (_) => const SettingsScreen(),
          '/change-password':     (_) => const ChangePasswordScreen(),
        },
      ),
    );
  }
}

/// Initializes Supabase then navigates to /login.
/// Shows a spinner while connecting and an error box (with Retry) on failure.
class _StartupScreen extends StatefulWidget {
  const _StartupScreen();

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (mounted) setState(() => _error = null);
    String? error;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnon,
        authOptions: const FlutterAuthClientOptions(
          detectSessionInUri: false,
          // Per-tab session persistence so different tabs can hold different
          // accounts (Management vs Employee) at the same time.
          localStorage: SessionScopedLocalStorage(
            persistSessionKey: 'fomrals-supabase-session',
          ),
        ),
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw 'Connection timed out.\nCheck your internet and try again.',
      );
    } catch (e) {
      error = e.toString();
    }
    // Bring up Firebase push in the background — fully guarded, never blocks or
    // crashes startup if Firebase isn't configured on this platform.
    if (error == null) unawaited(PushService.init());
    if (error == null) unawaited(OfflineSyncService.instance.start());
    if (error == null) unawaited(LeadDropReasonCatalogService.instance.load());
    if (error == null) unawaited(ProfilePhotoService.instance.load());
    bool loggedIn = false;
    if (error == null) {
      try {
        loggedIn = await AuthService.instance.checkSession();
      } catch (_) {
        loggedIn = false;
      }
    }

    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
    } else if (AuthLink.isAuthCallback) {
      // Arrived from an invite / password-recovery email link.
      Navigator.of(context).pushReplacementNamed('/set-password');
    } else {
      Navigator.of(context)
          .pushReplacementNamed(loggedIn ? '/home' : '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2563EB),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: const Icon(Icons.house_outlined,
                    color: Colors.white, size: 42),
              ),
              const SizedBox(height: 20),
              const Text(
                'FomraLS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Fomra Housing Pvt. Ltd.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 48),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off_outlined,
                          color: Colors.white70, size: 28),
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _init,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                      color: Colors.white54, strokeWidth: 2.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Connecting…',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
