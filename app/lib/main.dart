import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Config.isComplete) {
    runApp(const _MissingConfigApp());
    return;
  }
  await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabasePublishableKey);
  runApp(const DocketApp());
}

final supabase = Supabase.instance.client;

ThemeData _theme(Brightness brightness) => ThemeData(
      colorSchemeSeed: const Color(0xFF3949AB),
      brightness: brightness,
      useMaterial3: true,
    );

class DocketApp extends StatelessWidget {
  const DocketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Docket',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const _AuthGate(),
    );
  }
}

// Shows the login screen or the app depending on whether someone is signed in.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, _) => supabase.auth.currentSession == null ? const LoginScreen() : const HomeScreen(),
    );
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Docket is missing its settings.\n\n'
              'Copy config.example.json to config.json, fill it in, and run:\n'
              'flutter run --dart-define-from-file=config.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
