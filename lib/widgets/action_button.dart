import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor = const Color(0xFFF6F8FC),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black54, size: 20),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
