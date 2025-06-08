import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? buttonBackgroundColor; 
  final Color? buttonForegroundColor; 

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.buttonBackgroundColor, 
    this.buttonForegroundColor, 
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = buttonBackgroundColor ??
        (isDarkMode ? Colors.grey[700]! : Colors.grey[200]!);
    final Color fgColor = buttonForegroundColor ??
        (isDarkMode ? Colors.white70 : Colors.black87);

    return ElevatedButton.icon(
      icon: Icon(icon, color: fgColor, size: 18), 
      label: Text(label, style: TextStyle(color: fgColor, fontSize: 13, fontWeight: FontWeight.w500)), 
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor, 
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), 
        elevation: 0, 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0), 
        ),
      ),
    );
  }
}
