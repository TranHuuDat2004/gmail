import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../main.dart'; 

class DisplaySettingsScreen extends StatefulWidget {
  const DisplaySettingsScreen({super.key});

  @override
  State<DisplaySettingsScreen> createState() => _DisplaySettingsScreenState();
}

class _DisplaySettingsScreenState extends State<DisplaySettingsScreen> {  String? _selectedEditorFont = 'Roboto'; // Default editor font
  double _selectedEditorFontSize = 14.0; // Default editor font size
  
  // Available font sizes that match compose screen
  final List<double> _availableFontSizes = const [10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 24.0];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadDisplaySettings();
  }
  Future<void> _loadDisplaySettings() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    DocumentSnapshot userSettings = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('settings')
        .doc('editor')
        .get();

    if (userSettings.exists && userSettings.data() != null) {
      Map<String, dynamic> data = userSettings.data() as Map<String, dynamic>;
      setState(() {
        _selectedEditorFont = data['fontFamily'] ?? 'Roboto';
        final loadedFontSize = (data['fontSize'] as num?)?.toDouble() ?? 14.0;
        if (_availableFontSizes.contains(loadedFontSize)) {
          _selectedEditorFontSize = loadedFontSize;
        } else {
          // Find the closest available font size
          _selectedEditorFontSize = _availableFontSizes.reduce((a, b) => 
            (a - loadedFontSize).abs() < (b - loadedFontSize).abs() ? a : b);
        }
      });
    } else {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('settings')
          .doc('editor')
          .set({
        'fontFamily': _selectedEditorFont,
        'fontSize': _selectedEditorFontSize,
      });
    }
  }
  Future<void> _updateDisplaySettings({bool? newThemeValue}) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    if (newThemeValue != null) {
      await themeProvider.toggleTheme(newThemeValue, currentUser.uid);
    }

    await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('settings')
        .doc('editor')
        .set({
      'fontFamily': _selectedEditorFont,
      'fontSize': _selectedEditorFontSize,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final theme = Theme.of(context); 

    // Define colors based on theme
    final scaffoldBackgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.grey[100];
    final appBarBackgroundColor = isDarkMode ? const Color(0xFF202124) : Colors.white;
    final appBarTextColor = isDarkMode ? Colors.grey[300] : Colors.black87;
    final appBarIconColor = isDarkMode ? Colors.grey[400] : Colors.black54;
    final primaryTextColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : Colors.black54;
    final sectionHeaderColor = isDarkMode ? theme.colorScheme.primaryContainer : theme.colorScheme.primary;
    final noteTextColor = isDarkMode ? Colors.grey[500] : Colors.grey[600];
    final switchActiveColor = isDarkMode ? theme.colorScheme.primaryContainer : theme.colorScheme.primary;
    final switchInactiveTrackColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];
    final switchInactiveThumbColor = isDarkMode ? Colors.grey[400] : Colors.grey[500];
    final dropdownTextColor = primaryTextColor;
    final dropdownHintColor = secondaryTextColor;
    final dropdownIconColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final dropdownBackgroundColor = isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
    final sliderActiveColor = switchActiveColor;
    final sliderInactiveColor = switchInactiveTrackColor;
    final dividerColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Display Settings', style: TextStyle(color: appBarTextColor)),
        backgroundColor: appBarBackgroundColor,
        elevation: isDarkMode ? 0.5 : 1.0,
        iconTheme: IconThemeData(color: appBarIconColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            SwitchListTile(
              title: Text('Light/Dark Theme', style: TextStyle(color: primaryTextColor)),
              value: isDarkMode,
              onChanged: (bool value) {
                _updateDisplaySettings(newThemeValue: value);
              },
              secondary: Icon(
                isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                color: primaryTextColor,
              ),
              activeColor: switchActiveColor,
              inactiveTrackColor: switchInactiveTrackColor,
              inactiveThumbColor: switchInactiveThumbColor,
              trackOutlineColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                return Colors.grey[500];
              }),
              trackColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                if (!isDarkMode && states.contains(MaterialState.selected)) {
                  return Colors.white;
                }
                if (isDarkMode && states.contains(MaterialState.selected)) {
                  return const Color(0xFF3c4043);
                }
                return null;
              }),
            ),
            Divider(color: dividerColor),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              child: Text(
                'Email Editor Font Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: sectionHeaderColor),
              ),
            ),
            ListTile(
              title: Text('Editor Font Family', style: TextStyle(color: primaryTextColor)),              trailing: DropdownButton<String>(
                value: _selectedEditorFont,
                hint: Text('Default', style: TextStyle(color: dropdownHintColor)),
                focusColor: Colors.transparent, 
                dropdownColor: dropdownBackgroundColor, 
                iconEnabledColor: dropdownIconColor, 
                style: TextStyle(color: dropdownTextColor), 
                items: <String>['Arial', 'Roboto', 'TimesNewRoman']
                    .map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: TextStyle(fontFamily: value, color: dropdownTextColor)), 
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedEditorFont = newValue;
                  });
                  _updateDisplaySettings();
                },
              ),
            ),            ListTile(
              title: Text('Editor Font Size: ${_selectedEditorFontSize.toInt()}', style: TextStyle(color: primaryTextColor)),
              subtitle: Slider(
                value: _selectedEditorFontSize,
                min: _availableFontSizes.first,
                max: _availableFontSizes.last,
                divisions: _availableFontSizes.length - 1,
                label: _selectedEditorFontSize.round().toString(),
                onChanged: (double value) {
                  // Find the closest available font size
                  final closestSize = _availableFontSizes.reduce((a, b) => 
                    (a - value).abs() < (b - value).abs() ? a : b);
                  setState(() {
                    _selectedEditorFontSize = closestSize;
                  });
                  _updateDisplaySettings();
                },
                activeColor: sliderActiveColor,
                inactiveColor: sliderInactiveColor,
                thumbColor: sliderActiveColor, // Explicitly set thumb color
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 8.0, right: 8.0),
              child: Text(
                'Note: These font settings apply to the text editor when composing emails.',
                style: TextStyle(fontSize: 12, color: noteTextColor, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
