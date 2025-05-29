import 'package:flutter/material.dart';
import 'package:gmail/screens/login.dart';
import 'package:gmail/screens/settings_screen.dart';
import '../screens/label_screen.dart';
import '../screens/display_settings_screen.dart'; 
import '../screens/auto_answer_mode_screen.dart';

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

  @override
  Widget build(BuildContext context) {
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
          _buildDrawerItem(Icons.all_inbox, "All inboxes", count: emails.length, isSelected: selectedLabel == "All inboxes"),
          _buildDrawerItem(Icons.inbox, "Inbox", count: emails.where((e) => e['label'] == 'Inbox').length, isSelected: selectedLabel == "Inbox"),
          _buildDrawerItem(Icons.star_border, "Starred", count: emails.where((e) => e['starred'] == true).length, isSelected: selectedLabel == "Starred"),
          _buildDrawerItem(Icons.send, "Sent", count: emails.where((e) => e['label'] == 'Sent').length, isSelected: selectedLabel == "Sent"),
          _buildDrawerItem(Icons.drafts_outlined, "Drafts", count: emails.where((e) => e['label'] == 'Drafts').length, isSelected: selectedLabel == "Drafts"),
          _buildDrawerItem(Icons.delete_outline, "Trash", count: emails.where((e) => e['label'] == 'Trash').length, isSelected: selectedLabel == "Trash"),
          _buildDrawerItem(Icons.local_offer_outlined, "Promotions", count: emails.where((e) => e['label'] == 'Promotions').length, isSelected: selectedLabel == "Promotions"),
          _buildDrawerItem(Icons.update, "Updates", count: emails.where((e) => e['label'] == 'Forums').length, isSelected: selectedLabel == "Updates"), // Assuming 'Forums' was a typo for 'Updates' label in emails data
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
            leading: const Icon(Icons.reply_all, color: Colors.black54),
            title: const Text('Auto Answer Mode', style: TextStyle(color: Colors.black87)),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AutoAnswerModeScreen()),
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Labels",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.black45),
                  tooltip: 'Thêm label',
                  onPressed: () async {
                    Navigator.pop(context); // Đóng Drawer
                    final result = await Navigator.push( // Changed to await result
                      context,
                      MaterialPageRoute(
                        builder: (context) => LabelManagementScreen(
                          currentLabels: List<String>.from(userLabels), // Pass a copy
                          onLabelsUpdated: (updatedLabels) {
                            // This callback within LabelManagementScreen itself is fine.
                            // The important part is how CustomDrawer receives the final list.
                          },
                        ),
                      ),
                    );
                    if (result is List<String>) { // Check if result is a list of strings
                        onUserLabelsUpdated(result); // Update labels in GmailUI
                    }
                  },
                ),
              ],
            ),
          ),
          ...userLabels.map((label) => _buildDrawerItem(Icons.label, label, count: emails.where((e) => e['label'] == label).length, isSelected: selectedLabel == label)).toList(),
          const Divider(), // Added Divider

          ListTile(
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
              // TODO: Điều hướng đến màn hình Trợ giúp & Phản hồi thực tế
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mở Trợ giúp & Phản hồi")));
            },
          ),
          ListTile( // Added Logout Button
            leading: const Icon(Icons.logout, color: Colors.black54),
            title: const Text('Đăng xuất', style: TextStyle(color: Colors.black87)),
            onTap: () async {
              // Removed: await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, {bool isSelected = false, int count = 0}) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.redAccent : Colors.black54),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.redAccent : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: count > 0 ? Text(count.toString(), style: const TextStyle(color: Colors.black54)) : null,
      tileColor: isSelected ? const Color(0xFFF6F8FC) : Colors.white,
      shape: isSelected ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)) : null,
      contentPadding: isSelected ? const EdgeInsets.symmetric(horizontal: 24.0) : null,
      onTap: () => onLabelSelected(title),
    );
  }
}
