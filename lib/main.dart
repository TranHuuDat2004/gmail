// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:gmail/screens/login.dart';
import 'package:gmail/screens/gmail_ui.dart';
import 'package:provider/provider.dart';
import 'themes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Import for StreamSubscription

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, defaultTargetPlatform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('vi_VN', null); // Initialize Vietnamese locale data

  if (kIsWeb) {
    try {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaEnterpriseProvider('6Ld7Y1ArAAAAAM_qsLQA3TAdaOXVZ140wHsxbSXR'), // SITE KEY WEB 
      );
      print('Firebase App Check activated successfully for Web with ReCaptchaEnterpriseProvider.');
    } catch (e) {
      print('Error activating Firebase App Check for Web: $e');
    }
  } 
  // ANDROID APP CHECK
  else if (defaultTargetPlatform == TargetPlatform.android) { 
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      );
      print('Firebase App Check activated for Android.');

      if (kDebugMode) { 
        // Chờ một chút để đảm bảo App Check đã sẵn sàng trước khi lấy token
        await Future.delayed(const Duration(seconds: 1)); 
        String? token = await FirebaseAppCheck.instance.getToken(true); // Lấy token (buộc làm mới nếu cần)
      }
    } catch (e) {
      print('Error activating Firebase App Check for Android or getting debug token: $e');
    }
  }
  
  runApp(const MyApp());
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light; // Default to light
  bool _isDarkMode = false;

  ThemeProvider() {
    // Initial state is light. loadTheme will be called by MyApp.
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _isDarkMode; // Used by DisplaySettingsScreen

  Future<void> loadTheme(String? userId) async {
    if (userId == null) {
      // User is not logged in, force light theme
      _isDarkMode = false;
    } else {
      // User is logged in, load their preference from Firestore
      try {
        DocumentSnapshot displaySettings = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('settings')
            .doc('display')
            .get();
        if (displaySettings.exists && displaySettings.data() != null) {
          final data = displaySettings.data() as Map<String, dynamic>;
          _isDarkMode = data['isDarkMode'] as bool? ?? false; // Default to false if null
        } else {
          _isDarkMode = false; // Default to false if no settings found
        }
      } catch (e) {
        print('Error loading theme from Firestore: $e');
        _isDarkMode = false; // Default to false on error
      }
    }
    _themeMode = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme(bool newIsDarkModeValue, String userId) async {
    // This function assumes userId is not null because it's called from a context
    // where the user is logged in (e.g., display settings screen).
    _isDarkMode = newIsDarkModeValue;
    _themeMode = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
    notifyListeners(); // Update UI immediately

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('display')
          .set({'isDarkMode': _isDarkMode}, SetOptions(merge: true));
    } catch (e) {
      print('Error saving theme to Firestore: $e');
      // Optionally, handle the error, e.g., by reverting the theme change
      // and notifying listeners again if the save fails.
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ThemeProvider _themeProvider;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _themeProvider = ThemeProvider();
    // Initial theme load based on current user, if any.
    // This ensures the theme is set correctly when the app starts.
    _themeProvider.loadTheme(FirebaseAuth.instance.currentUser?.uid);

    // Listen to authentication state changes to update the theme accordingly.
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _themeProvider.loadTheme(user?.uid);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _themeProvider,
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Gmail Clone',
            theme: lightTheme, // Defined in themes.dart
            darkTheme: darkTheme, // Defined in themes.dart
            themeMode: themeProvider.themeMode, // Controlled by ThemeProvider
            home: const AuthGate(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key}); // No longer needs themeProvider

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          // User is logged in
          return GmailUI(user: snapshot.data); // Pass user if GmailUI needs it
        } else {
          // User is not logged in
          return const LoginPage();
        }
      },
    );
  }
}