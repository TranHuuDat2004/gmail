import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for logout
import 'package:gmail/screens/settings_screen.dart';
import 'package:gmail/screens/label_screen.dart'; // Corrected import path
import 'package:gmail/screens/display_settings_screen.dart'; 
import 'package:gmail/screens/auto_answer_mode_screen.dart';
import 'package:gmail/screens/login.dart'; // Thêm import cho LoginPage
import 'package:cloud_firestore/cloud_firestore.dart'; // Thêm import
import 'dart:async'; // Thêm import cho StreamSubscription


class CustomDrawer extends StatefulWidget {
  final String selectedLabel;
  final Function(String) onLabelSelected;
  final List<String> userLabels;
  final Function(List<String>) onUserLabelsUpdated;
  final String? currentUserDisplayName;
  final String? currentUserEmail;
  final String? currentUserAvatarUrl;

  const CustomDrawer({
    super.key,
    required this.selectedLabel,
    required this.onLabelSelected,
    required this.userLabels,
    required this.onUserLabelsUpdated,
    this.currentUserDisplayName,
    this.currentUserEmail,
    this.currentUserAvatarUrl,
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  List<Map<String, dynamic>> _allEmails = [];
  List<Map<String, dynamic>> _allDrafts = [];
  bool _isLoadingCounts = true;
  StreamSubscription? _emailStreamSubscription;
  StreamSubscription? _draftStreamSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserLabels();
    _loadAllEmailsForCounting();
  }

  @override
  void dispose() {
    _emailStreamSubscription?.cancel();
    _draftStreamSubscription?.cancel();
    super.dispose();
  }

  // Public method to refresh email counts from parent widget
  void refreshEmailCounts() {
    _loadAllEmailsForCounting();
  }

  // Load user-created labels from Firestore
  Future<void> _loadUserLabels() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final labelsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('labels')
          .orderBy('name', descending: false)
          .get();

      if (mounted) {
        final userCreatedLabels = labelsSnapshot.docs
            .map((doc) => doc['name'] as String)
            .toList();
        
        // Update parent widget with labels
        widget.onUserLabelsUpdated(userCreatedLabels);
      }
    } catch (e) {
      print("Error loading user labels: $e");
    }
  }
  // Load all emails and drafts for counting purposes with real-time updates
  Future<void> _loadAllEmailsForCounting() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoadingCounts = false;
      });
      return;
    }

    try {
      // Cancel existing subscriptions
      await _emailStreamSubscription?.cancel();
      await _draftStreamSubscription?.cancel();

      // Load all emails with real-time updates
      final emailsQuery = FirebaseFirestore.instance
          .collection('emails')
          .where('involvedUserIds', arrayContains: currentUser.uid);
      
      _emailStreamSubscription = emailsQuery.snapshots().listen((emailsSnapshot) {
        final allEmails = emailsSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          data['isDraft'] = false;
          return data;
        }).toList();

        if (mounted) {
          setState(() {
            _allEmails = allEmails;
            _isLoadingCounts = false;
          });
        }
      }, onError: (error) {
       
        if (mounted) {
          setState(() {
            _isLoadingCounts = false;
          });
        }
      });

      // Load all drafts with real-time updates
      _draftStreamSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('drafts')
          .snapshots().listen((draftsSnapshot) {
        final allDrafts = draftsSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          data['isDraft'] = true;
          data['emailLabels'] = {currentUser.uid: ['Drafts']};
          data['emailIsReadBy'] = {currentUser.uid: true};
          return data;
        }).toList();

        if (mounted) {
          setState(() {
            _allDrafts = allDrafts;
            _isLoadingCounts = false;
          });
        }
      }, onError: (error) {
       
        if (mounted) {
          setState(() {
            _isLoadingCounts = false;
          });
        }
      });
    } catch (e) {
     
      if (mounted) {
        setState(() {
          _isLoadingCounts = false;
        });
      }
    }
  }

  // Hàm xử lý đăng xuất
  Future<void> _handleLogout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // Sau khi đăng xuất thành công, điều hướng về LoginPage
      // và xóa tất cả các màn hình trước đó khỏi stack.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false, // Xóa tất cả các route trước đó
      );
    } catch (e) {
      // Xử lý lỗi nếu có (ví dụ: hiển thị SnackBar)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đăng xuất: ${e.toString()}')),
      );
    }
  }  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context); // Get the current theme
    final bool isDarkMode = theme.brightness == Brightness.dark;    // Define colors based on theme
    final drawerBackgroundColor = isDarkMode ? const Color(0xFF202124) : Colors.white;
    final headerBackgroundColor = isDarkMode ? const Color(0xFF202124) : const Color(0xFFF6F8FC);
    final headerTextColor = isDarkMode ? Colors.grey[300] : Colors.black87;
    final dividerColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];
    final defaultIconColor = isDarkMode ? Colors.grey[400] : Colors.black54;
    final defaultTextColor = isDarkMode ? Colors.grey[300] : Colors.black87;
    final labelsHeaderColor = isDarkMode ? Colors.grey[500] : Colors.black54;

    return Drawer(
      backgroundColor: drawerBackgroundColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [          DrawerHeader(
            decoration: BoxDecoration(
              color: headerBackgroundColor,
            ),
            child: Row(
              children: [
                Text("Wamail", style: TextStyle(color: headerTextColor, fontSize: 22)),
              ],
            ),          ),_buildDrawerItem(
            context, // Pass context
            Icons.inbox,
            "Inbox",
            count: _isLoadingCounts ? 0 : (currentUserId != null ? _allEmails.where((e) {
              // Filter out trashed and permanently deleted emails
              final isTrashedBy = List<String>.from(e['isTrashedBy'] ?? []);
              final permanentlyDeletedBy = List<String>.from(e['permanentlyDeletedBy'] ?? []);
              if (isTrashedBy.contains(currentUserId) || permanentlyDeletedBy.contains(currentUserId)) {
                return false;
              }
              
              final labelsMap = e['emailLabels'] as Map<String, dynamic>?;
              final userLabels = labelsMap?[currentUserId] as List<dynamic>?;
              return userLabels?.contains('Inbox') ?? false;
            }).length : 0),
            unreadCount: _isLoadingCounts ? 0 : (currentUserId != null ? _allEmails.where((e) {
              // Filter out trashed and permanently deleted emails first
              final isTrashedBy = List<String>.from(e['isTrashedBy'] ?? []);
              final permanentlyDeletedBy = List<String>.from(e['permanentlyDeletedBy'] ?? []);
              if (isTrashedBy.contains(currentUserId) || permanentlyDeletedBy.contains(currentUserId)) {
                return false;
              }
              
              // Check if email is in Inbox
              final labelsMap = e['emailLabels'] as Map<String, dynamic>?;
              final userLabels = labelsMap?[currentUserId] as List<dynamic>?;
              final isInInbox = userLabels?.contains('Inbox') ?? false;
              
              // Check if email is unread
              final emailIsReadBy = e['emailIsReadBy'] as Map<String, dynamic>?;
              final isUnread = !(emailIsReadBy?[currentUserId] ?? false);
              
              return isInInbox && isUnread;
            }).length : 0),
            isSelected: widget.selectedLabel == "Inbox",
            onTap: () => widget.onLabelSelected("Inbox")
          ),
          _buildDrawerItem(
            context, // Pass context
            Icons.star_border, 
            "Starred", 
            count: _isLoadingCounts ? 0 : (currentUserId != null ? _allEmails.where((e) {
              // Filter out trashed and permanently deleted emails
              final isTrashedBy = List<String>.from(e['isTrashedBy'] ?? []);
              final permanentlyDeletedBy = List<String>.from(e['permanentlyDeletedBy'] ?? []);
              if (isTrashedBy.contains(currentUserId) || permanentlyDeletedBy.contains(currentUserId)) {
                return false;
              }
              
              final labelsMap = e['emailLabels'] as Map<String, dynamic>?;
              final userLabels = labelsMap?[currentUserId] as List<dynamic>?;
              return userLabels?.contains('Starred') ?? false;
            }).length : 0),
            isSelected: widget.selectedLabel == "Starred",
            onTap: () => widget.onLabelSelected("Starred")
          ),
          _buildDrawerItem(
            context, // Pass context
            Icons.send, 
            "Sent", 
            count: _isLoadingCounts ? 0 : (currentUserId != null ? _allEmails.where((e) {
              // Filter out trashed and permanently deleted emails
              final isTrashedBy = List<String>.from(e['isTrashedBy'] ?? []);
              final permanentlyDeletedBy = List<String>.from(e['permanentlyDeletedBy'] ?? []);
              if (isTrashedBy.contains(currentUserId) || permanentlyDeletedBy.contains(currentUserId)) {
                return false;
              }
              
              final labelsMap = e['emailLabels'] as Map<String, dynamic>?;
              final userLabels = labelsMap?[currentUserId] as List<dynamic>?;
              return userLabels?.contains('Sent') ?? false;
            }).length : 0),
            isSelected: widget.selectedLabel == "Sent",
            onTap: () => widget.onLabelSelected("Sent")
          ),
          _buildDrawerItem(
            context, // Pass context
            Icons.drafts_outlined, 
            "Drafts", 
            count: _isLoadingCounts ? 0 : (currentUserId != null ? _allDrafts.length : 0),
            isSelected: widget.selectedLabel == "Drafts",
            onTap: () => widget.onLabelSelected("Drafts")
          ),
          _buildDrawerItem(
            context, // Pass context
            Icons.delete_outline, 
            "Trash", 
            count: _isLoadingCounts ? 0 : (currentUserId != null ? _allEmails.where((e) => (e['isTrashedBy'] as List<dynamic>? ?? []).contains(currentUserId)).length : 0),
            isSelected: widget.selectedLabel == "Trash",
            onTap: () => widget.onLabelSelected("Trash")
          ),
          Divider(color: dividerColor),
          ListTile(
            leading: Icon(Icons.settings_display, color: defaultIconColor),
            title: Text('Display Settings', style: TextStyle(color: defaultTextColor)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DisplaySettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.reply_all_outlined, color: defaultIconColor),
            title: Text('Chế độ tự động trả lời', style: TextStyle(color: defaultTextColor)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AutoAnswerModeScreen()));
            },
          ),
          Divider(color: dividerColor),
          ListTile(
            title: Text(
              "Labels",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: labelsHeaderColor, fontWeight: FontWeight.w500),
            ),            trailing: IconButton(
              icon: Icon(Icons.add, color: defaultIconColor),
              tooltip: 'Tạo nhãn mới',              onPressed: () async {
                Navigator.pop(context); // Close the drawer first
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LabelManagementScreen()),
                );
                
                // Handle the result
                if (result is Map<String, dynamic> && result['action'] == 'selectLabel') {
                  final String? label = result['label'];
                  if (label != null) {
                    widget.onLabelSelected(label);
                  }
                }
                
                // Refresh user labels and email counts after returning from label management
                _loadUserLabels();
                _loadAllEmailsForCounting();
              },
            ),contentPadding: const EdgeInsets.only(left: 16.0, right: 12.0), // Adjust padding to align title and button
            dense: true, // Makes the ListTile more compact
          ),          // Show only first 3 labels
          ...widget.userLabels.take(3).map((label) => _buildDrawerItem(
                context,
                Icons.label_outline,
                label,
                count: _isLoadingCounts ? 0 : (currentUserId != null ? _allEmails.where((e) {
                  // Filter out trashed and permanently deleted emails
                  final isTrashedBy = List<String>.from(e['isTrashedBy'] ?? []);
                  final permanentlyDeletedBy = List<String>.from(e['permanentlyDeletedBy'] ?? []);
                  if (isTrashedBy.contains(currentUserId) || permanentlyDeletedBy.contains(currentUserId)) {
                    return false;
                  }
                  
                  final labelsMap = e['emailLabels'] as Map<String, dynamic>?;
                  final userLabelsForThisEmail = labelsMap?[currentUserId] as List<dynamic>?;
                  return userLabelsForThisEmail?.contains(label) ?? false;
                }).length : 0),
                isSelected: widget.selectedLabel == label,
                onTap: () => widget.onLabelSelected(label)
              )).toList(),// Show "See more" button if there are more than 3 labels
           if (widget.userLabels.length > 3)
            ListTile(
              leading: Icon(Icons.more_horiz, color: defaultIconColor),
              title: Text(
                'Xem thêm ${widget.userLabels.length - 3} nhãn khác',
                style: TextStyle(
                  color: defaultTextColor,
                ),
              ),              onTap: () async { // <-- Sửa 1: Thêm async
                Navigator.pop(context); // Đóng drawer
                // Sửa 2: Dùng await để chờ kết quả
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LabelManagementScreen()),
                );

                // Sửa 3: Xử lý kết quả trả về
                if (result is Map<String, dynamic> && result['action'] == 'selectLabel') {
                  final String? label = result['label'];
                  if (label != null) {
                    widget.onLabelSelected(label); // Gọi callback để cập nhật GmailUI
                  }
                }
                
                // Refresh user labels and email counts after returning from label management
                _loadUserLabels();
                _loadAllEmailsForCounting();
              },
            ),
          Divider(color: dividerColor),
          ListTile( 
            leading: Icon(Icons.settings_outlined, color: defaultIconColor),
            title: Text('Cài đặt', style: TextStyle(color: defaultTextColor)),
            onTap: () {
              Navigator.pop(context); // Đóng drawer trước
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
           ListTile( 
            leading: Icon(Icons.help_outline, color: defaultIconColor),
            title: Text('Trợ giúp & phản hồi', style: TextStyle(color: defaultTextColor)),
            onTap: () {
              Navigator.pop(context); // Đóng drawer
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mở Trợ giúp & Phản hồi")));
            },
          ),
          Divider(color: dividerColor), // Thêm Divider trước nút Đăng xuất nếu muốn tách biệt rõ hơn
          ListTile( 
            leading: Icon(Icons.logout, color: defaultIconColor),
            title: Text('Đăng xuất', style: TextStyle(color: defaultTextColor)),
            onTap: () {
              _handleLogout(context); // Gọi hàm xử lý đăng xuất
            },
          ),
        ],
      ),
    );
  }
  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, {bool isSelected = false, int count = 0, int unreadCount = 0, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;    final Color selectedColor = isDarkMode ? const Color(0xFFE8EAED) : Colors.blue; // Changed to blue for light mode
    final Color unselectedIconColor = isDarkMode ? Colors.grey[400]! : Colors.black54;
    final Color unselectedTextColor = isDarkMode ? Colors.grey[300]! : Colors.black87;
    final Color selectedTileColor = isDarkMode ? const Color(0xFF4A4A4F) : Colors.blue.withOpacity(0.08); // Changed to blue for light mode
    final Color countColor = isDarkMode ? Colors.grey[500]! : (isSelected ? Colors.blue.withOpacity(0.7) : Colors.black87.withOpacity(0.7)); // Changed to blue for light mode
    final Color unreadCountColor = Colors.red;    final itemColor = isSelected ? selectedColor : unselectedTextColor;
    final iconColor = isSelected ? selectedColor : unselectedIconColor;

    // Build trailing widget based on counts
    Widget? trailing;
    if (unreadCount > 0 && title == "Inbox") {
      // For Inbox with unread emails, show red unread count
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: unreadCountColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          unreadCount.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (count > 0) {
      // For other sections, show regular count
      trailing = Text(count.toString(), style: TextStyle(color: countColor));
    }

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          color: itemColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: trailing,
      tileColor: isSelected ? selectedTileColor : Colors.transparent,
      shape: isSelected ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSelected ? 25 : 8)) : null, // More rounded for selected
      contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: isSelected ? 2.0 : 0.0), // Slightly more vertical padding for selected
      onTap: () {
        if (onTap != null) {
          onTap();
        } else {
          // Default behavior if specific onTap is not provided (though it should be for these items)
          widget.onLabelSelected(title);
        }
        // Consider closing the drawer here if that's the desired UX
        Navigator.pop(context); 
      },
    );
  }
}