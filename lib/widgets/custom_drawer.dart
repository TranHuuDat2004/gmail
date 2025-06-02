import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for logout
import 'package:gmail/screens/settings_screen.dart';
import 'package:gmail/screens/label_screen.dart'; // Corrected import path
import 'package:gmail/screens/display_settings_screen.dart'; 
import 'package:gmail/screens/auto_answer_mode_screen.dart';
import 'package:gmail/screens/login.dart'; // Thêm import cho LoginPage

class CustomDrawer extends StatelessWidget {
  final String selectedLabel;
  final Function(String) onLabelSelected;
  final List<String> userLabels;
  final List<Map<String, dynamic>> emails;
  final Function(List<String>) onUserLabelsUpdated; // Added for label management

  const CustomDrawer({
    super.key,
    required this.selectedLabel,
    required this.onLabelSelected,
    required this.userLabels,
    required this.emails,
    required this.onUserLabelsUpdated, // Added for label management
  });

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
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context); // Get the current theme
    final bool isDarkMode = theme.brightness == Brightness.dark;

    // Define colors based on theme
    final drawerBackgroundColor = isDarkMode ? const Color(0xFF202124) : Colors.white;
    final headerBackgroundColor = isDarkMode ? const Color(0xFF202124) : const Color(0xFFF6F8FC);
    final headerIconColor = isDarkMode ? Colors.grey[400] : Colors.redAccent;
    final headerTextColor = isDarkMode ? Colors.grey[300] : Colors.black87;
    final dividerColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];
    final defaultIconColor = isDarkMode ? Colors.grey[400] : Colors.black54;
    final defaultTextColor = isDarkMode ? Colors.grey[300] : Colors.black87;
    final labelsHeaderColor = isDarkMode ? Colors.grey[500] : Colors.black54;

    return Drawer(
      backgroundColor: drawerBackgroundColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: headerBackgroundColor,
            ),
            child: Row(
              children: [
                Icon(Icons.mail, color: headerIconColor, size: 32),
                const SizedBox(width: 10),
                Text("Gmail", style: TextStyle(color: headerTextColor, fontSize: 22)),
              ],
            ),
          ),
          _buildDrawerItem(
            context, // Pass context
            Icons.inbox,
            "Inbox",
            count: currentUserId != null ? emails.where((e) {
              final labelsMap = e['emailLabels'] as Map<String, dynamic>?;
              final userLabels = labelsMap?[currentUserId] as List<dynamic>?;
              return userLabels?.contains('Inbox') ?? false;
            }).length : 0,
            isSelected: selectedLabel == "Inbox",
            onTap: () => onLabelSelected("Inbox")
          ),
          _buildDrawerItem(
            context, // Pass context
            Icons.star_border, 
            "Starred", 
            count: currentUserId != null ? emails.where((e) {
              final labelsMap = e['emailLabels'] as Map<String, dynamic>?;
              final userLabels = labelsMap?[currentUserId] as List<dynamic>?;
              return userLabels?.contains('Starred') ?? false;
            }).length : 0,
            isSelected: selectedLabel == "Starred",
            onTap: () => onLabelSelected("Starred")
          ),
          _buildDrawerItem(
            context, // Pass context
            Icons.send, 
            "Sent", 
            count: currentUserId != null ? emails.where((e) {
              final labelsMap = e['emailLabels'] as Map<String, dynamic>?;
              final userLabels = labelsMap?[currentUserId] as List<dynamic>?;
              return userLabels?.contains('Sent') ?? false;
            }).length : 0,
            isSelected: selectedLabel == "Sent",
            onTap: () => onLabelSelected("Sent")
          ),
          _buildDrawerItem(
            context, // Pass context
            Icons.drafts_outlined, 
            "Drafts", 
            count: currentUserId != null ? emails.where((e) {
              final labelsMap = e['emailLabels'] as Map<String, dynamic>?;
              final userLabels = labelsMap?[currentUserId] as List<dynamic>?;
              return userLabels?.contains('Drafts') ?? false;
            }).length : 0,
            isSelected: selectedLabel == "Drafts",
            onTap: () => onLabelSelected("Drafts")
          ),
          _buildDrawerItem(
            context, // Pass context
            Icons.delete_outline, 
            "Trash", 
            count: currentUserId != null ? emails.where((e) => (e['isTrashedBy'] as List<dynamic>? ?? []).contains(currentUserId)).length : 0,
            isSelected: selectedLabel == "Trash",
            onTap: () => onLabelSelected("Trash")
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
            ),
            trailing: IconButton(
              icon: Icon(Icons.add, color: defaultIconColor),
              tooltip: 'Tạo nhãn mới',
              onPressed: () {
                Navigator.pop(context); // Close the drawer first
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LabelManagementScreen(
                      currentLabels: userLabels, 
                      onLabelsUpdated: onUserLabelsUpdated, 
                    ),
                  ),
                );
              },
            ),
            contentPadding: const EdgeInsets.only(left: 16.0, right: 12.0), // Adjust padding to align title and button
            dense: true, // Makes the ListTile more compact
          ),
          // Calls to _buildDrawerItem for user labels no longer pass context
          ...userLabels.map((label) => _buildDrawerItem(
                context, // Pass context
                Icons.label_outline,
                label,
                count: currentUserId != null ? emails.where((e) {
                  final labelsMap = e['emailLabels'] as Map<String, dynamic>?;
                  final userLabelsForThisEmail = labelsMap?[currentUserId] as List<dynamic>?;
                  return userLabelsForThisEmail?.contains(label) ?? false;
                }).length : 0,
                isSelected: selectedLabel == label,
                onTap: () => onLabelSelected(label)
              )).toList(),
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

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, {bool isSelected = false, int count = 0, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    final Color selectedColor = isDarkMode ? const Color(0xFFE8EAED) : Colors.redAccent; // Light text/icon for selected in dark
    final Color unselectedIconColor = isDarkMode ? Colors.grey[400]! : Colors.black54;
    final Color unselectedTextColor = isDarkMode ? Colors.grey[300]! : Colors.black87;
    final Color selectedTileColor = isDarkMode ? const Color(0xFF4A4A4F) : Colors.red.withOpacity(0.08); // Darker selection for dark mode
    final Color countColor = isDarkMode ? Colors.grey[500]! : (isSelected ? Colors.redAccent.withOpacity(0.7) : Colors.black87.withOpacity(0.7));


    final itemColor = isSelected ? selectedColor : unselectedTextColor;
    final iconColor = isSelected ? selectedColor : unselectedIconColor;

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          color: itemColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: count > 0 ? Text(count.toString(), style: TextStyle(color: countColor)) : null,
      tileColor: isSelected ? selectedTileColor : Colors.transparent,
      shape: isSelected ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSelected ? 25 : 8)) : null, // More rounded for selected
      contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: isSelected ? 2.0 : 0.0), // Slightly more vertical padding for selected
      onTap: () {
        if (onTap != null) {
          onTap();
        } else {
          // Default behavior if specific onTap is not provided (though it should be for these items)
          onLabelSelected(title);
        }
        // Consider closing the drawer here if that's the desired UX
        // Navigator.pop(context); 
      },
    );
  }
}
