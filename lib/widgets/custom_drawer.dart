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
  Widget build(BuildContext context) { // context is defined here
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FC),
            ),
            child: Row(
              children: const [
                Icon(Icons.mail, color: Colors.redAccent, size: 32),
                SizedBox(width: 10),
                Text("Gmail", style: TextStyle(color: Colors.black87, fontSize: 22)),
              ],
            ),
          ),
          // Calls to _buildDrawerItem no longer pass context
          _buildDrawerItem(Icons.all_inbox, "All inboxes", count: emails.length, isSelected: selectedLabel == "All inboxes"),
          _buildDrawerItem(Icons.inbox, "Inbox", count: emails.where((e) => e['label'] == 'Inbox').length, isSelected: selectedLabel == "Inbox"),
          _buildDrawerItem(Icons.star_border, "Starred", count: emails.where((e) => e['starred'] == true).length, isSelected: selectedLabel == "Starred"),
          _buildDrawerItem(Icons.send, "Sent", count: emails.where((e) => e['label'] == 'Sent').length, isSelected: selectedLabel == "Sent"),
          _buildDrawerItem(Icons.drafts_outlined, "Drafts", count: emails.where((e) => e['label'] == 'Drafts').length, isSelected: selectedLabel == "Drafts"),
          _buildDrawerItem(Icons.delete_outline, "Trash", count: emails.where((e) => e['label'] == 'Trash').length, isSelected: selectedLabel == "Trash"),
          _buildDrawerItem(Icons.local_offer_outlined, "Promotions", count: emails.where((e) => e['label'] == 'Promotions').length, isSelected: selectedLabel == "Promotions"),
          _buildDrawerItem(Icons.update, "Updates", count: emails.where((e) => e['label'] == 'Forums' || e['label'] == 'Updates').length, isSelected: selectedLabel == "Updates"),
          const Divider(),
          ListTile( // Added Display Settings Button
            leading: const Icon(Icons.settings_display, color: Colors.black54),
            title: const Text('Display Settings', style: TextStyle(color: Colors.black87)),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DisplaySettingsScreen()),
              );
            },
          ),
          ListTile( // Added Auto Answer Mode Button
            leading: const Icon(Icons.reply_all_outlined, color: Colors.black54),
            title: const Text('Chế độ tự động trả lời', style: TextStyle(color: Colors.black87)),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AutoAnswerModeScreen()));
            },
          ),
          const Divider(),
          // Replace Padding with ListTile for "Labels" header and add button
          ListTile(
            title: Text(
              "Labels",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black54, fontWeight: FontWeight.w500),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add, color: Colors.black54),
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
          ...userLabels.map((label) => _buildDrawerItem(Icons.label, label, count: emails.where((e) => e['label'] == label).length, isSelected: selectedLabel == label)).toList(),
          const Divider(),
          ListTile( // Cài đặt
            leading: const Icon(Icons.settings_outlined, color: Colors.black54),
            title: const Text('Cài đặt', style: TextStyle(color: Colors.black87)),
            onTap: () {
              Navigator.pop(context); // Đóng drawer trước
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
           ListTile( // Ví dụ thêm mục Trợ giúp & Phản hồi
            leading: const Icon(Icons.help_outline, color: Colors.black54),
            title: const Text('Trợ giúp & phản hồi', style: TextStyle(color: Colors.black87)),
            onTap: () {
              Navigator.pop(context); // Đóng drawer
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mở Trợ giúp & Phản hồi")));
            },
          ),
          const Divider(), // Thêm Divider trước nút Đăng xuất nếu muốn tách biệt rõ hơn
          ListTile( // LOGOUT BUTTON - Đặt ở dưới cùng
            leading: const Icon(Icons.logout, color: Colors.black54),
            title: const Text('Đăng xuất', style: TextStyle(color: Colors.black87)),
            onTap: () {
              _handleLogout(context); // Gọi hàm xử lý đăng xuất
            },
          ),
        ],
      ),
    );
  }

  // _buildDrawerItem reverted to its original form (no BuildContext parameter)
  Widget _buildDrawerItem(IconData icon, String title, {bool isSelected = false, int count = 0}) {
    final itemColor = isSelected ? Colors.redAccent : Colors.black87;
    final iconColor = isSelected ? Colors.redAccent : Colors.black54;

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          color: itemColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: count > 0 ? Text(count.toString(), style: TextStyle(color: itemColor.withOpacity(0.7))) : null,
      tileColor: isSelected ? Colors.red.withOpacity(0.08) : Colors.transparent,
      shape: isSelected ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      onTap: () {
        // Navigator.pop(context); // Removed: Drawer will not close automatically on label selection
        onLabelSelected(title);
      },
    );
  }
}
