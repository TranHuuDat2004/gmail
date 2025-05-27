import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _allowNotifications = true;
  String _notificationSoundType = 'sound_and_vibration'; // 'sound_and_vibration', 'silent'

  final Color _activeColor = Colors.blueAccent; // Consistent blue color for active elements

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo ứng dụng'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.red, // Gmail-like color
                  child: Icon(Icons.mail_outline, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Gmail', // This could be dynamic
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Allow Notifications Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 8.0, top: 4.0, bottom: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Cho phép thông báo',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: Colors.black87),
                    ),
                    Transform.scale(
                      scale: 1.0, // Adjust if needed
                      child: Switch(
                        value: _allowNotifications,
                        onChanged: (bool value) {
                          setState(() {
                            _allowNotifications = value;
                          });
                        },
                        activeColor: _activeColor,
                        inactiveThumbColor: Colors.grey[300],
                        inactiveTrackColor: Colors.grey[400]?.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_allowNotifications) ...[
            _buildSectionWithTitleAndContent(
              context,
              "Thông báo",
              _buildNotificationSoundOptionsContent(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
      backgroundColor: Colors.grey[200],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, right: 16.0, top: 20.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSectionWithTitleAndContent(BuildContext context, String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: content,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildNotificationSoundOptionsContent() {
    return Column(
      children: <Widget>[
        RadioListTile<String>(
          title: const Text('Cho phép âm thanh và rung', style: TextStyle(fontSize: 16)),
          value: 'sound_and_vibration',
          groupValue: _notificationSoundType,
          onChanged: (String? value) {
            if (value != null) {
              setState(() {
                _notificationSoundType = value;
              });
            }
          },
          activeColor: _activeColor,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.only(left: 16.0, right: 16.0, top:4.0, bottom:4.0),
        ),
        const Divider(height: 1, indent: 56, endIndent: 16, thickness: 0.5),
        RadioListTile<String>(
          title: const Text('Yên lặng', style: TextStyle(fontSize: 16)),
          value: 'silent',
          groupValue: _notificationSoundType,
          onChanged: (String? value) {
            if (value != null) {
              setState(() {
                _notificationSoundType = value;
              });
            }
          },
          activeColor: _activeColor,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.only(left: 16.0, right: 16.0, top:4.0, bottom:4.0),
        ),
      ],
    );
  }
}