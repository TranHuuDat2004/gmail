import 'package:flutter/material.dart';

class AutoAnswerModeScreen extends StatefulWidget {
  const AutoAnswerModeScreen({super.key});

  @override
  State<AutoAnswerModeScreen> createState() => _AutoAnswerModeScreenState();
}

class _AutoAnswerModeScreenState extends State<AutoAnswerModeScreen> {
  bool _isAutoAnswerEnabled = false;
  final TextEditingController _autoReplyMessageController = TextEditingController(text: "I am currently unavailable and will get back to you soon.");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto Answer Mode'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black54),
        titleTextStyle: const TextStyle(color: Colors.black87, fontSize: 20),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            SwitchListTile(
              title: const Text('Enable Auto Answer Mode'),
              value: _isAutoAnswerEnabled,
              onChanged: (bool value) {
                setState(() {
                  _isAutoAnswerEnabled = value;
                });
              },
              secondary: const Icon(Icons.reply_all),
              activeColor: Colors.blue, // Active color remains blue
              inactiveTrackColor: Colors.white, // Set inactive track to white
              inactiveThumbColor: Colors.grey[400], // Optional: adjust thumb color for contrast
            ),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Auto-Reply Message:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _autoReplyMessageController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter your auto-reply message here',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.save, color: Colors.blue), // Icon color set to blue
              label: const Text('Save'),
              onPressed: () {
                // Add save logic here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings saved (not really!)')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200], // Light grey background
                foregroundColor: Colors.black87, // Black text/icon
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
    );
  }
}
