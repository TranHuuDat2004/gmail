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
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: ListView(
        children: <Widget>[
          _buildSettingsSectionTitle(context, "Tài khoản"),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text('Hồ sơ & Bảo mật'),
            subtitle: const Text('Thông tin cá nhân, mật khẩu, 2FA'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
          const Divider(height: 1),
           ListTile( // Thêm mục đổi mật khẩu riêng nếu muốn truy cập nhanh
            leading: const Icon(Icons.lock_outline),
            title: const Text('Đổi mật khẩu'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Thông báo'),
            subtitle: const Text('Cài đặt âm thanh, rung, ưu tiên'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationSettingsScreen()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Hiển thị'),
            subtitle: const Text('Chủ đề, font chữ'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigator.push(context, MaterialPageRoute(builder: (context) => const DisplaySettingsScreen()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mở Cài đặt Hiển thị")));
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.reply_all_outlined),
            title: const Text('Chế độ tự động trả lời'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigator.push(context, MaterialPageRoute(builder: (context) => const AutoAnswerSettingsScreen()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mở Cài đặt Tự động trả lời")));
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('Quản lý nhãn'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigator.push(context, MaterialPageRoute(builder: (context) => const LabelManagementScreen()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mở Quản lý nhãn")));
            },
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
    );
  }

  Widget _buildSettingsSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}