import 'package:flutter/material.dart';

class DisplaySettingsScreen extends StatefulWidget {
  const DisplaySettingsScreen({super.key});

  @override
  State<DisplaySettingsScreen> createState() => _DisplaySettingsScreenState();
}

class _DisplaySettingsScreenState extends State<DisplaySettingsScreen> {
  bool _isDarkMode = false;
  String? _selectedFont;
  double _selectedFontSize = 14.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Display Settings'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black54),
        titleTextStyle: const TextStyle(color: Colors.black87, fontSize: 20),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            SwitchListTile(
              title: const Text('Light/Dark Theme'),
              value: _isDarkMode,
              onChanged: (bool value) {
                setState(() {
                  _isDarkMode = value;
                });
                // Add theme switching logic here
              },
              secondary: Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode),
              activeColor: Colors.blue, // Changed active color to blue
              inactiveTrackColor: Colors.white, // Set inactive track to white
              inactiveThumbColor: Colors.grey[400], // Optional: adjust thumb color for contrast
            ),
            const Divider(),
            ListTile(
              title: const Text('Font Family'),
              trailing: DropdownButton<String>(
                value: _selectedFont,
                hint: const Text('Default'),
                iconEnabledColor: Colors.blue, // Set icon color to blue
                dropdownColor: Colors.white, // Set dropdown menu background to white
                focusColor: Colors.transparent, // Optional: to remove focus highlight if not desired
                items: <String>['Roboto', 'Open Sans', 'Lato', 'Montserrat']
                    .map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedFont = newValue;
                  });
                  // Add font change logic here
                },
                // Consider adding focusColor or dropdownColor if needed for theming
              ),
            ),
            ListTile(
              title: Text('Font Size: ${_selectedFontSize.toInt()}'),
              subtitle: Slider(
                value: _selectedFontSize,
                min: 10,
                max: 24,
                divisions: 14,
                label: _selectedFontSize.round().toString(),
                onChanged: (double value) {
                  setState(() {
                    _selectedFontSize = value;
                  });
                  // Add font size change logic here
                },
                activeColor: Colors.blue, // Changed active color to blue
                inactiveColor: Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
    );
  }
}
