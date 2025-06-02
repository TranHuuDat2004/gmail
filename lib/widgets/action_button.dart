import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? buttonBackgroundColor; // New parameter
  final Color? buttonForegroundColor; // New parameter

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.buttonBackgroundColor, // Initialize
    this.buttonForegroundColor, // Initialize
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Determine colors: Use provided colors if available, otherwise use theme-based defaults
    final Color bgColor = buttonBackgroundColor ??
        (isDarkMode ? Colors.grey[700]! : Colors.grey[200]!);
    final Color fgColor = buttonForegroundColor ??
        (isDarkMode ? Colors.white70 : Colors.black87);

    return ElevatedButton.icon(
      icon: Icon(icon, color: fgColor, size: 18), // Applied foreground color
      label: Text(label, style: TextStyle(color: fgColor, fontSize: 13, fontWeight: FontWeight.w500)), // Applied foreground color
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor, // Applied background color
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), // Adjusted padding
        elevation: 0, // Flat button style like Gmail
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0), // Reduced border radius
        ),
      ),
    );
  }
}
