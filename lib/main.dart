import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'l10n/fallback_localization_delegate.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'screens/splash_screen.dart';
import 'state/app_state.dart';
import 'services/push_notification_service.dart';

final PushNotificationService _pushNotificationService =
    PushNotificationService.instance;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _pushNotificationService.handleRemoteMessage(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _pushNotificationService.initialize();
    FirebaseMessaging.onMessage.listen(
      _pushNotificationService.handleRemoteMessage,
    );
    FirebaseMessaging.onMessageOpenedApp.listen(
      _pushNotificationService.handleRemoteMessage,
    );
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..bootstrap(),
      child: const LegebereApp(),
    ),
  );
}

class LegebereApp extends StatelessWidget {
  const LegebereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        Widget home;
        switch (appState.status) {
          case AppStatus.loading:
            home = const SplashScreen();
            break;
          case AppStatus.unauthenticated:
            home = const AuthScreen();
            break;
          case AppStatus.authenticated:
            home = const HomeShell();
            break;
        }

        return MaterialApp(
          title: 'Legebere',
          onGenerateTitle: (context) => context.tr('Legebere'),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: appState.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            FallbackLocalizationDelegate<MaterialLocalizations>(
              GlobalMaterialLocalizations.delegate,
            ),
            FallbackLocalizationDelegate<WidgetsLocalizations>(
              GlobalWidgetsLocalizations.delegate,
            ),
            FallbackLocalizationDelegate<CupertinoLocalizations>(
              GlobalCupertinoLocalizations.delegate,
            ),
          ],
          home: home,
        );
      },
    );
  }
}
