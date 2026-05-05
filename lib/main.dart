import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/monitoring_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: TruckFleetApp(),
    ),
  );
}

class TruckFleetApp extends StatelessWidget {
  const TruckFleetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TruckFleet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // StreamBuilder reactivo: escucha cambios de sesión en tiempo real.
      // Cuando se hace signOut(), Firebase emite null y la app va al Login.
      // Cuando se hace signIn(), emite el user y la app va al Home.
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
