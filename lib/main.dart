import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

// Importación de las pantallas
import 'login_page.dart';
import 'register_page.dart';
import 'reset_password_page.dart';
import 'home_page.dart';
import 'messages_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'privacy_page.dart';
import 'about_page.dart';
import 'profile_form_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "DoctorApp",
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF4F9F9),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      // Pantalla inicial depende del estado de autenticación
      home: const AuthGate(),

      // Definición de rutas
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/reset': (context) => const ResetPasswordPage(),
        '/home': (context) => const HomePage(),
        '/messages': (context) => const MessagesPage(),
        '/profile': (context) => const ProfilePage(),
        '/settings': (context) => const SettingsPage(),
        '/privacy': (context) => const PrivacyPage(),
        '/about': (context) => const AboutPage(),
        '/profile_form': (context) => ProfileFormPage(
          uid: FirebaseAuth.instance.currentUser?.uid ?? '',
        ),
      },
    );
  }
}

/// Controla si el usuario está autenticado o no
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mientras se carga el estado de Firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Si el usuario está autenticado
        if (snapshot.hasData) {
          return const HomePage();
        }

        // Si no está autenticado
        return const LoginPage();
      },
    );
  }
}
