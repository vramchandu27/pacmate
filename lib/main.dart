import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/network/firebase_service.dart';
import 'core/security/rate_limiter.dart';
import 'core/session/inactivity_detector.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

// ── Local notifications channel ───────────────────────────────────────────────
final _localNotifications = FlutterLocalNotificationsPlugin();
const _androidChannel = AndroidNotificationChannel(
  'packmate_default',
  'PacMate Notifications',
  description: 'General PacMate notifications',
  importance: Importance.high,
);

// Background FCM handler — must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Background messages are auto-shown by the OS; nothing extra needed here.
}

Future<void> _initLocalNotifications() async {
  await _localNotifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidChannel);
}

void _showLocalNotification(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;
  _localNotifications.show(
    notification.hashCode,
    notification.title,
    notification.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        icon: '@mipmap/ic_launcher',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase ──────────────────────────────────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── FCM background handler (must register before runApp) ─────────────────
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ── Local notifications setup ─────────────────────────────────────────────
  await _initLocalNotifications();

  // ── FCM foreground handler — show banner while app is open ────────────────
  FirebaseMessaging.onMessage.listen(_showLocalNotification);

  // Crashlytics — catch all Flutter framework errors
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Catch async errors outside Flutter framework
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // ── Firebase App Check ────────────────────────────────────────────────────
  // Attests that requests come from legitimate app instances.
  // Debug builds use the debug provider so development isn't blocked.
  // Production: enable enforcement in the Firebase console for Auth, Firestore,
  //             Storage, and Cloud Functions.
  // PlayIntegrity only works for Play Store distributed apps.
  // Use debug provider for sideloaded APKs (direct sharing / beta testing).
  // Switch back to playIntegrity when publishing to Play Store.
  await FirebaseAppCheck.instance.activate(
    androidProvider: kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
    appleProvider:   kReleaseMode ? AppleProvider.deviceCheck : AppleProvider.debug,
  );

  // ── Firebase Service init (offline persistence + FCM permissions) ─────────
  await FirebaseService.instance.initialize();

  // ── SharedPreferences (rate limiter persistence) ──────────────────────────
  final prefs = await SharedPreferences.getInstance();

  // ── UI ────────────────────────────────────────────────────────────────────
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.navy,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const PacMateApp(),
    ),
  );
}

class PacMateApp extends ConsumerWidget {
  const PacMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (context, child) => InactivityDetector(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
