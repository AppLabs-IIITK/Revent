import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_manager/firebase_options.dart';
import 'package:events_manager/login_page.dart';
import 'package:events_manager/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:events_manager/event_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Configure Firestore settings
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Initialize notification service
  await NotificationService.initialize();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final kcolorscheme =
        ColorScheme.fromSeed(seedColor: const Color(0xff06222F));
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        colorScheme: kcolorscheme,
        appBarTheme: const AppBarTheme().copyWith(
          titleTextStyle:
              const TextStyle(color: Color(0xffAEE7FF), fontSize: 21),
          backgroundColor: const Color(0xff1A2C34),
          foregroundColor: kcolorscheme.shadow,
        ),
        scaffoldBackgroundColor: kcolorscheme.onSurface,
        cardTheme: const CardThemeData().copyWith(
          color: kcolorscheme.primaryContainer,
          elevation: 5,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: kcolorscheme.onPrimary,
            backgroundColor: kcolorscheme.primary,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(kcolorscheme.primary),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: Color(0xffAEE7FF),
            fontSize: 26,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
          headlineSmall: TextStyle(
            fontSize: 12,
            fontFamily: 'Inter',
            color: Color(0xffAEE7FF),
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontFamily: 'Inter',
            color: Color(0xffAEE7FF),
          ),
        ),
      ),
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.hasData) {
            var user = snapshot.data;
            return EventManager(user: user as User);
          }
          return const LoginPage();
        },
      ),
    );
  }
}
