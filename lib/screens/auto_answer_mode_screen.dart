import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AutoAnswerModeScreen extends StatefulWidget {
  const AutoAnswerModeScreen({super.key});

  @override
  State<AutoAnswerModeScreen> createState() => _AutoAnswerModeScreenState();
}

class _AutoAnswerModeScreenState extends State<AutoAnswerModeScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isAutoAnswerEnabled = false;
  final TextEditingController _autoReplySubjectController = TextEditingController(
      text: "Automatic Reply");
  final TextEditingController _autoReplyMessageController = TextEditingController(
      text: "I am currently unavailable and will get back to you soon.");
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }  Future<void> _loadSettings() async {
    if (_currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      // Load from user_settings collection first
      final userSettingsDoc = await _firestore
          .collection('user_settings')
          .doc(_currentUser!.uid)
          .get();
          
      if (userSettingsDoc.exists) {
        final data = userSettingsDoc.data();
        setState(() {
          _isAutoAnswerEnabled = data?['autoReplyEnabled'] ?? false;
          _autoReplySubjectController.text = data?['autoReplySubject'] ?? "Automatic Reply";
          _autoReplyMessageController.text = data?['autoReplyMessage'] ??
              "I am currently unavailable and will get back to you soon.";
          _isLoading = false;
        });
      } else {
        // Fallback to old settings location
        final doc = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('settings')
            .doc('autoAnswer')
            .get();
        if (doc.exists) {
          setState(() {
            _isAutoAnswerEnabled = doc.data()?['enabled'] ?? false;
            _autoReplySubjectController.text = doc.data()?['subject'] ?? "Automatic Reply";
            _autoReplyMessageController.text = doc.data()?['message'] ??
                "I am currently unavailable and will get back to you soon.";
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print("Error loading auto answer settings: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải cài đặt: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }  Future<void> _saveSettings() async {
    if (_currentUser == null) return;
    try {
      // Save to user_settings collection with email field for auto reply lookup
      await _firestore
          .collection('user_settings')
          .doc(_currentUser!.uid)
          .set({
        'autoReplyEnabled': _isAutoAnswerEnabled,
        'autoReplySubject': _autoReplySubjectController.text.trim(),
        'autoReplyMessage': _autoReplyMessageController.text.trim(),
        'email': _currentUser!.email, // Add email field for lookup
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also save to old location for backward compatibility
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('settings')
          .doc('autoAnswer')
          .set({
        'enabled': _isAutoAnswerEnabled,
        'subject': _autoReplySubjectController.text.trim(),
        'message': _autoReplyMessageController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cài đặt đã được lưu')),
        );
      }
    } catch (e) {
      print("Error saving auto answer settings: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu cài đặt: $e')),
        );
      }
    }
  }
  Future<void> _toggleAutoAnswer(bool value) async {
    setState(() {
      _isAutoAnswerEnabled = value;
    });

    if (_currentUser == null) return;
    
    try {
      // Save to user_settings collection with email field for auto reply lookup
      await _firestore
          .collection('user_settings')
          .doc(_currentUser!.uid)
          .set({
        'autoReplyEnabled': value,
        'autoReplySubject': _autoReplySubjectController.text.trim(),
        'autoReplyMessage': _autoReplyMessageController.text.trim(),
        'email': _currentUser!.email, // Add email field for lookup
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also save to old location for backward compatibility
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('settings')
          .doc('autoAnswer')
          .set({
        'enabled': value,
        'subject': _autoReplySubjectController.text.trim(),
        'message': _autoReplyMessageController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
      print("Error updating auto answer toggle: $e");
      if (mounted) {
        setState(() {
          _isAutoAnswerEnabled = !value; // Revert on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật cài đặt: $e')),
        );
      }
    }
  }
  @override
  void dispose() {
    _autoReplySubjectController.dispose();
    _autoReplyMessageController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Define colors based on theme
    final scaffoldBackgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.grey[100];
    final cardBackgroundColor = isDarkMode ? const Color(0xFF202124) : Colors.white;
    final appBarBackgroundColor = isDarkMode ? const Color(0xFF202124) : Colors.white;
    final appBarTextColor = isDarkMode ? Colors.grey[300] : Colors.black87;
    final appBarIconColor = isDarkMode ? Colors.grey[400] : Colors.black54;
    final primaryTextColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : Colors.black54;
    final switchActiveColor = isDarkMode ? theme.colorScheme.primaryContainer : theme.colorScheme.primary;
    final switchInactiveTrackColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];
    final switchInactiveThumbColor = isDarkMode ? Colors.grey[400] : Colors.grey[500];
    final textFieldBackgroundColor = isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey[50];
    final textFieldBorderColor = isDarkMode ? Colors.grey[600]! : Colors.grey[400]!;
    final textFieldFocusedBorderColor = isDarkMode ? Colors.blue[400]! : Colors.blue[600]!;
    final buttonBackgroundColor = isDarkMode ? Colors.blue[600] : Colors.blue[700];
    final buttonForegroundColor = Colors.white;
    final dividerColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Chế độ tự động trả lời'),
        backgroundColor: appBarBackgroundColor,
        foregroundColor: appBarTextColor,
        elevation: isDarkMode ? 0.5 : 1.0,
        iconTheme: IconThemeData(color: appBarIconColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  // Enable/Disable Auto Answer Card
                  Card(
                    color: cardBackgroundColor,
                    elevation: isDarkMode ? 0 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: SwitchListTile(
                        title: Text(
                          'Bật chế độ tự động trả lời',
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Tự động gửi phản hồi cho email đến',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 14,
                          ),
                        ),
                        value: _isAutoAnswerEnabled,
                        onChanged: (bool value) {
                          _toggleAutoAnswer(value);
                        },
                        secondary: Icon(
                          Icons.reply_all,
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
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Auto-Reply Settings Card
                  Card(
                    color: cardBackgroundColor,
                    elevation: isDarkMode ? 0 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thiết lập tin nhắn tự động',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Subject Field
                          Text(
                            'Tiêu đề:',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _autoReplySubjectController,
                            style: TextStyle(color: primaryTextColor),
                            decoration: InputDecoration(
                              hintText: 'Nhập tiêu đề cho email tự động trả lời',
                              hintStyle: TextStyle(color: secondaryTextColor),
                              filled: true,
                              fillColor: textFieldBackgroundColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: textFieldBorderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: textFieldBorderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: textFieldFocusedBorderColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Message Field
                          Text(
                            'Nội dung tin nhắn:',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _autoReplyMessageController,
                            maxLines: 6,
                            style: TextStyle(color: primaryTextColor),
                            decoration: InputDecoration(
                              hintText: 'Nhập nội dung tin nhắn tự động trả lời...',
                              hintStyle: TextStyle(color: secondaryTextColor),
                              filled: true,
                              fillColor: textFieldBackgroundColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: textFieldBorderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: textFieldBorderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: textFieldFocusedBorderColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Save Button
                  Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonBackgroundColor,
                        foregroundColor: buttonForegroundColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: isDarkMode ? 0 : 2,
                      ),
                      child: const Text(
                        'LƯU CÀI ĐẶT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}