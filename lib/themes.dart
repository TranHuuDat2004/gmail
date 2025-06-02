import 'package:flutter/material.dart';

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: Colors.blue, // Gmail's blue for primary actions
  scaffoldBackgroundColor: Colors.white,
  cardColor: Colors.white,
  dividerColor: Colors.grey[300],
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.white,
    elevation: 1,
    iconTheme: const IconThemeData(color: Colors.black54),
    toolbarTextStyle: const TextTheme(
      titleLarge: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w500),
    ).bodyMedium,
    titleTextStyle: const TextTheme(
      titleLarge: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w500),
    ).titleLarge,
  ),
  iconTheme: const IconThemeData(color: Colors.black54),
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Colors.grey[800]),
    bodyMedium: TextStyle(color: Colors.grey[700]),
    titleMedium: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
    labelLarge: const TextStyle(color: Colors.white), // For buttons
  ),
  buttonTheme: ButtonThemeData(
    buttonColor: Colors.blue,
    textTheme: ButtonTextTheme.primary,
    colorScheme: ColorScheme.light(
      primary: Colors.blue,
      secondary: Colors.blueAccent,
      surface: Colors.white,
      background: Colors.white,
      error: Colors.red,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black,
      onBackground: Colors.black,
      onError: Colors.white,
      brightness: Brightness.light,
    ),
  ),
  listTileTheme: ListTileThemeData(
    iconColor: Colors.grey[700],
  ),
  drawerTheme: DrawerThemeData(
    backgroundColor: Colors.white,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: Colors.blue,
    unselectedItemColor: Colors.grey[600],
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: Colors.white, // Gmail's compose button color
    foregroundColor: const Color(0xFF1967D2), // Blue icon/text
  ),
  inputDecorationTheme: InputDecorationTheme(
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.blue, width: 2.0),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey[400]!),
    ),
    labelStyle: TextStyle(color: Colors.grey[700]),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return Colors.blue;
      }
      return Colors.grey[400];
    }),
    trackColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return Colors.blue.withOpacity(0.5);
      }
      return Colors.grey[300];
    }),
  ),
  colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(background: Colors.white, brightness: Brightness.light, surface: Colors.white),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF8AB4F8), // Gmail's accessible blue for dark theme
  scaffoldBackgroundColor: const Color(0xFF1F1F1F), // Main dark background
  cardColor: const Color(0xFF2A2A2A), // Slightly lighter for cards/surfaces
  dividerColor: Colors.grey[800],
  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFF202124), // Darker app bar
    elevation: 0, // Consistent with Material 3
    iconTheme: IconThemeData(color: Colors.grey[400]), // Lighter icons for dark app bar
    titleTextStyle: TextStyle(color: Colors.grey[200], fontSize: 20, fontWeight: FontWeight.w500),
  ),
  iconTheme: const IconThemeData(color: Color(0xFFE8EAED)),
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Colors.grey[300]),
    bodyMedium: TextStyle(color: Colors.grey[400]),
    titleMedium: TextStyle(color: Colors.grey[200], fontWeight: FontWeight.w500),
    labelLarge: const TextStyle(color: Color(0xFF1F1F1F)), // For buttons with light background
  ),
  buttonTheme: ButtonThemeData(
    buttonColor: const Color(0xFF8AB4F8),
    textTheme: ButtonTextTheme.primary,
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF8AB4F8),
      secondary: const Color(0xFF8AB4F8), // Or another accent
      surface: const Color(0xFF2A2A2A),
      background: const Color(0xFF1F1F1F),
      error: Colors.redAccent,
      onPrimary: const Color(0xFF1F1F1F), // Text on primary buttons
      onSecondary: const Color(0xFF1F1F1F),
      onSurface: const Color(0xFFE8EAED), // Text on surfaces
      onBackground: const Color(0xFFE8EAED),
      onError: Colors.black,
      brightness: Brightness.dark,
    ),
  ),
  listTileTheme: ListTileThemeData(
    iconColor: Colors.grey[400],
  ),
  drawerTheme: DrawerThemeData(
    backgroundColor: const Color(0xFF2A2A2A),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: const Color(0xFF2A2A2A),
    selectedItemColor: const Color(0xFF8AB4F8),
    unselectedItemColor: Colors.grey[500],
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: const Color(0xFFE8EAED), // Light grey background for FAB in dark mode (matching image)
    foregroundColor: const Color(0xFF8AB4F8), // Light blue icon/text on FAB (matching image)
    elevation: 2.0, // Default elevation
    // shape: StadiumBorder(), // Default shape for extended FAB
  ),
  inputDecorationTheme: InputDecorationTheme(
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: const Color(0xFF8AB4F8), width: 2.0),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey[700]!),
    ),
    labelStyle: TextStyle(color: Colors.grey[400]),
    hintStyle: TextStyle(color: const Color(0xFF9AA0A6)), // Lighter hint text for dark theme
  ),
  switchTheme: SwitchThemeData(
    thumbColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return const Color(0xFF8AB4F8);
      }
      return Colors.grey[600]; // Darker thumb for inactive
    }),
    trackColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return const Color(0xFF8AB4F8).withOpacity(0.5);
      }
      return Colors.grey[800]; // Darker track for inactive
    }),
  ),
  colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(background: const Color(0xFF1F1F1F), brightness: Brightness.dark, surface: const Color(0xFF2A2A2A)),
);
