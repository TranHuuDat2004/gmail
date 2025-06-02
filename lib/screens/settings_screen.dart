// lib/settings_screen.dart
import 'package:flutter/material.dart';
import 'profile_screen.dart'; // Dẫn đến ProfileScreen
import 'change_password_screen.dart'; // Dẫn đến ChangePasswordScreen
import 'notification_settings_screen.dart';
// import 'two_fa_screen.dart'; // Bạn sẽ tạo màn hình này sau nếu cần
// import 'notification_settings_screen.dart';
// import 'display_settings_screen.dart';
// import 'auto_answer_settings_screen.dart';
// import 'label_management_screen.dart';

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
            leading: const Icon(Icons.account_circle_outlined, color: Color(0xFFE8EAED)),
            title: const Text('Hồ sơ & Bảo mật', style: TextStyle(color: Color(0xFFE8EAED))),
            subtitle: const Text('Thông tin cá nhân, mật khẩu, 2FA', style: TextStyle(color: Color(0xFFB0B3B8))),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFE8EAED)),
            onTap: () {
              // Mục này có thể dẫn đến một màn hình con khác liệt kê
              // Profile, Change Password, 2FA riêng biệt,
              // hoặc trực tiếp đến ProfileScreen như hiện tại.
              // Để đơn giản, ta sẽ dẫn đến ProfileScreen trước.
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFF444746)),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Color(0xFFE8EAED)),
            title: const Text('Đổi mật khẩu', style: TextStyle(color: Color(0xFFE8EAED))),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFE8EAED)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
              );
            },
          ),
          // Nếu có màn hình 2FA riêng:
          // const Divider(height: 1),
          // ListTile(
          //   leading: const Icon(Icons.security_outlined),
          //   title: const Text('Xác thực 2 yếu tố (2FA)'),
          //   trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          //   onTap: () {
          //     // Navigator.push(context, MaterialPageRoute(builder: (context) => const TwoFAScreen()));
          //      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mở màn hình 2FA")));
          //   },
          // ),

          _buildSettingsSectionTitle(context, "Ứng dụng"),
          ListTile(
            leading: const Icon(Icons.notifications_outlined, color: Color(0xFFE8EAED)),
            title: const Text('Thông báo', style: TextStyle(color: Color(0xFFE8EAED))),
            subtitle: const Text('Cài đặt âm thanh, rung, ưu tiên', style: TextStyle(color: Color(0xFFB0B3B8))),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFE8EAED)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationSettingsScreen()),
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFF444746)),
          ListTile(
            leading: const Icon(Icons.palette_outlined, color: Color(0xFFE8EAED)),
            title: const Text('Hiển thị', style: TextStyle(color: Color(0xFFE8EAED))),
            subtitle: const Text('Chủ đề, font chữ', style: TextStyle(color: Color(0xFFB0B3B8))),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFE8EAED)),
            onTap: () {
              // Navigator.push(context, MaterialPageRoute(builder: (context) => const DisplaySettingsScreen()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mở Cài đặt Hiển thị")));
            },
          ),
          const Divider(height: 1, color: Color(0xFF444746)),
          ListTile(
            leading: const Icon(Icons.reply_all_outlined, color: Color(0xFFE8EAED)),
            title: const Text('Chế độ tự động trả lời', style: TextStyle(color: Color(0xFFE8EAED))),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFE8EAED)),
            onTap: () {
              // Navigator.push(context, MaterialPageRoute(builder: (context) => const AutoAnswerSettingsScreen()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mở Cài đặt Tự động trả lời")));
            },
          ),
          const Divider(height: 1, color: Color(0xFF444746)),
          ListTile(
            leading: const Icon(Icons.label_outline, color: Color(0xFFE8EAED)),
            title: const Text('Quản lý nhãn', style: TextStyle(color: Color(0xFFE8EAED))),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFE8EAED)),
            onTap: () {
              // Navigator.push(context, MaterialPageRoute(builder: (context) => const LabelManagementScreen()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mở Quản lý nhãn")));
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
    final Color blueColor = const Color(0xFF1A73E8); // Màu xanh nút đăng nhập
    final Color sectionColor = (title.toLowerCase().contains('tài khoản') || title.toLowerCase().contains('ứng dụng'))
        ? blueColor
        : (isDark ? Colors.grey[300]! : Colors.grey[700]!);
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