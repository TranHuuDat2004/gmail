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
  final TextEditingController _autoReplyMessageController = TextEditingController(
      text: "I am currently unavailable and will get back to you soon.");
  bool _isLoading = true; // Thêm trạng thái loading

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (_currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('settings')
          .doc('autoAnswer')
          .get();
      if (doc.exists) {
        setState(() {
          _isAutoAnswerEnabled = doc.data()?['enabled'] ?? false;
          _autoReplyMessageController.text = doc.data()?['message'] ??
              "I am currently unavailable and will get back to you soon.";
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
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
  }

  Future<void> _saveSettings() async {
    if (_currentUser == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('settings')
          .doc('autoAnswer')
          .set({
        'enabled': _isAutoAnswerEnabled,
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

  @override
  void dispose() {
    _autoReplyMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto Answer Mode'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black54),
        titleTextStyle: const TextStyle(color: Colors.black87, fontSize: 20),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
                    activeColor: Colors.blue,
                    inactiveTrackColor: Colors.white,
                    inactiveThumbColor: Colors.grey[400],
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
                    icon: const Icon(Icons.save, color: Colors.blue),
                    label: const Text('Save'),
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black87,
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