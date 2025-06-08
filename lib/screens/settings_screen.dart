import 'package:flutter/material.dart';
import 'profile_screen.dart'; 
import 'notification_settings_screen.dart';
import 'display_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt chung'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white,
        foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
        elevation: 1,
      ),
      body: ListView(
        children: <Widget>[
          _buildSettingsSectionTitle(context, "Tài khoản"),
          ListTile(
            leading: Icon(
              Icons.account_circle_outlined,
              color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFE8EAED) : Colors.grey[800],
            ),
            title: Text('Hồ sơ & Bảo mật', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFE8EAED) : Colors.grey[800])),
            subtitle: Text('Thông tin cá nhân, mật khẩu, 2FA', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFB0B3B8) : Colors.grey[800])),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFE8EAED)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),

          _buildSettingsSectionTitle(context, "Ứng dụng"),
          ListTile(
            leading: Icon(
              Icons.notifications_outlined,
              color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFE8EAED) : Colors.grey[800],
            ),
            title: Text('Thông báo', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFE8EAED) : Colors.grey[800])),
            subtitle: Text('Cài đặt âm thanh, rung, ưu tiên', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFB0B3B8) : Colors.grey[800])),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFE8EAED)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationSettingsScreen()),
              );
            },
          ),          const Divider(height: 1, color: Color(0xFF444746)),
          ListTile(
            leading: Icon(
              Icons.palette_outlined,
              color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFE8EAED) : Colors.grey[800],
            ),
            title: Text('Hiển thị', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFE8EAED) : Colors.grey[800])),
            subtitle: Text('Chủ đề, font chữ', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFB0B3B8) : Colors.grey[800])),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFE8EAED)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DisplaySettingsScreen()),
              );
            },
          ),
        ],
      ),
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF232323) : Colors.grey[100],
    );
  }

  Widget _buildSettingsSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    
    // Định nghĩa màu xanh cho cả hai chế độ
    final Color accentColor = isDark ? Colors.blue[300]! : const Color(0xFF1A73E8);
    
    // Định nghĩa màu cho các mục khác (nếu có)
    final Color otherSectionColor = isDark ? Colors.grey[300]! : Colors.grey[700]!;

    // Quyết định màu dựa trên tiêu đề
    final Color sectionColor = (title.toLowerCase().contains('tài khoản') || title.toLowerCase().contains('ứng dụng'))
        ? accentColor
        : otherSectionColor;
        
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: sectionColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}