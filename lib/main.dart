import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'screens/splash_screen.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: home,
        );
      },
    );
  }
}
