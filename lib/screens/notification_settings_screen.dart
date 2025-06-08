import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {  bool _allowNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
  }
  @override
  void dispose() {
    super.dispose();
  }
  Future<void> _loadNotificationSetting() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _allowNotifications = data['allowNotifications'] ?? true;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading notification setting: $e');
      // Use default value on error
      if (mounted) {
        setState(() {
          _allowNotifications = true;
        });
      }
    }
  }
  Future<void> _updateNotificationSetting(bool value) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'allowNotifications': value});
      }
    } catch (e) {
      print('Error updating notification setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật cài đặt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;    final scaffoldBackgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.grey[200];
    final cardBackgroundColor = isDarkMode ? const Color(0xFF202124) : Colors.white;
    final textColor = isDarkMode ? Colors.grey[200] : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo ứng dụng'),
        backgroundColor: cardBackgroundColor,
        foregroundColor: textColor,
        elevation: 1,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
            child: Material(
              color: cardBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 8.0, top: 4.0, bottom: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cho phép thông báo',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: textColor),
                    ),
                    Transform.scale(
                      scale: 1.0,
                      child: Switch(
                        value: _allowNotifications,                        onChanged: (bool value) async {
                          setState(() {
                            _allowNotifications = value;
                          });
                          await _updateNotificationSetting(value);
                          
                          // Show confirmation
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(value ? 'Đã bật thông báo' : 'Đã tắt thông báo'),
                                duration: const Duration(seconds: 1),
                                backgroundColor: isDarkMode ? Colors.green[700] : Colors.green,
                              ),
                            );
                          }                        },                        activeColor: isDarkMode ? theme.colorScheme.primaryContainer : theme.colorScheme.primary,
                        inactiveTrackColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                        inactiveThumbColor: isDarkMode ? Colors.grey[400] : Colors.grey[500],
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
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: scaffoldBackgroundColor,
    );
  }
}