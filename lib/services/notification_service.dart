import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  StreamSubscription? _emailSubscription;
  StreamSubscription? _settingsSubscription;
  String? _lastEmailId;
  bool _allowNotifications = true;
  GlobalKey<ScaffoldMessengerState>? _scaffoldMessengerKey;

  void initialize(GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey) {
    _scaffoldMessengerKey = scaffoldMessengerKey;
    _startListening();
  }

  void dispose() {
    _emailSubscription?.cancel();
    _settingsSubscription?.cancel();
    _emailSubscription = null;
    _settingsSubscription = null;
  }

  void _startListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _loadNotificationSettings(user.uid);
    _listenToNotificationSettings(user.uid);
    _listenToNewEmails(user.uid);
  }

  Future<void> _loadNotificationSettings(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        _allowNotifications = data['allowNotifications'] ?? true;
      }
    } catch (e) {
      print('Error loading notification settings: $e');
      _allowNotifications = true;
    }
  }

  void _listenToNotificationSettings(String userId) {
    _settingsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        _allowNotifications = data['allowNotifications'] ?? true;
      }
    }, onError: (error) {
      print('Error listening to notification settings: $error');
    });
  }

  void _listenToNewEmails(String userId) {
    _emailSubscription = FirebaseFirestore.instance
        .collection('emails')
        .where('involvedUserIds', arrayContains: userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final emailId = doc.id;
        final data = doc.data();
        
        // Check if this is a new email (not sent by current user)
        final senderId = data['senderId'] as String?;
        final isNewEmail = senderId != userId && emailId != _lastEmailId;
        
        if (isNewEmail && _allowNotifications) {
          _showNewEmailNotification(
            sender: data['senderDisplayName'] ?? data['from'] ?? 'Người gửi',
            subject: data['subject'] ?? '(Không có tiêu đề)',
            time: data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : DateTime.now(),
          );
        }
        _lastEmailId = emailId;
      }
    }, onError: (error) {
      print('Error listening to emails: $error');
    });
  }
  void _showNewEmailNotification({
    required String sender,
    required String subject,
    required DateTime time,
  }) {
    if (_scaffoldMessengerKey?.currentState == null) return;

    final snackBar = SnackBar(
      content: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[600],
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.mail, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thư mới từ $sender',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  _scaffoldMessengerKey!.currentState!.hideCurrentSnackBar();
                },
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      margin: const EdgeInsets.only(top: 50, left: 16, right: 16),
    );

    _scaffoldMessengerKey!.currentState!.showSnackBar(snackBar);
  }

  void onUserChanged() {
    dispose();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _startListening();
    }
  }
}