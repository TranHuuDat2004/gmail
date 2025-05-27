// lib/features/profile/profile_screen.dart (Hoặc tên file của bạn)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gmail/edit_profile_screen.dart'; // Sửa đường dẫn nếu cần
import 'package:gmail/change_password_screen.dart'; // Sửa đường dẫn
// Import các màn hình cài đặt con (bạn sẽ tạo sau)
// import 'package:gmail/features/settings/notification_settings_screen.dart';
// import 'package:gmail/features/settings/display_settings_screen.dart';
// import 'package:gmail/features/settings/auto_answer_mode_screen.dart';
// import 'package:gmail/features/settings/label_management_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = "Trần Hữu Đạt";
  String _userInitial = "Đ";
  String? _userPhoneNumber;
  ImageProvider? _userAvatarImage;

  // Thêm biến để quản lý tab đang active
  String _activeTab = "Home"; // Mặc định là "Personal info"

  @override
  void initState() {
    super.initState();
    if (_userName.isNotEmpty) {
      var nameParts = _userName.split(' ');
      if (nameParts.isNotEmpty && nameParts.last.isNotEmpty) {
        _userInitial = nameParts.last[0].toUpperCase();
      } else if (_userName.isNotEmpty) {
        _userInitial = _userName[0].toUpperCase();
      }
    }
    _userAvatarImage =
        const AssetImage('images/mahiru.png'); // Đảm bảo ảnh này tồn tại
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          currentName: _userName,
          currentAvatar: _userAvatarImage,
        ),
      ),
    );
    if (result != null && result is Map) {
      setState(() {
        _userName = result['name'] ?? _userName;
        if (result['avatarFile'] != null && result['avatarFile'] is File) {
          _userAvatarImage = FileImage(result['avatarFile'] as File);
        }
        if (_userName.isNotEmpty) {
          var nameParts = _userName.split(' ');
          if (nameParts.isNotEmpty && nameParts.last.isNotEmpty) {
            _userInitial = nameParts.last[0].toUpperCase();
          } else if (_userName.isNotEmpty) {
            _userInitial = _userName[0].toUpperCase();
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ... (AppBar không đổi nhiều, có thể giữ nguyên)
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            Image.asset(
              'images/Google.png', // Ensure this path is correct and image exists
              height: 24,
              errorBuilder: (context, error, stackTrace) => const Text('G',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Colors.blue)),
            ),
            const SizedBox(width: 8),
            const Text('Account', style: TextStyle(color: Colors.black87)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1.0,
        actions: [
          IconButton(
              icon: const Icon(Icons.search, color: Colors.black54),
              onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.black54),
              onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.apps, color: Colors.black54),
              onPressed: () {}),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.blue[700],
              backgroundImage: _userAvatarImage,
              child: _userAvatarImage == null
                  ? Text(_userInitial,
                      style: const TextStyle(color: Colors.white, fontSize: 16))
                  : null,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1.0)),
            ),
            // 👇👇👇 THAY ĐỔI BẮT ĐẦU TỪ ĐÂY 👇👇👇
            child: Row(
              // Bọc các tab trong một Row
              children: <Widget>[
                Expanded(
                  // Bọc mỗi _buildNavTab trong Expanded
                  child: _buildNavTab(
                    "Home",
                    isActive: _activeTab == "Home",
                    onTap: () {
                      setState(() {
                        _activeTab = "Home";
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _buildNavTab(
                    "Personal info",
                    isActive: _activeTab == "Personal info",
                    onTap: () {
                      setState(() {
                        _activeTab = "Personal info";
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _buildNavTab(
                    "Settings",
                    isActive: _activeTab == "Settings",
                    onTap: () {
                      setState(() {
                        _activeTab = "Settings";
                      });
                    },
                  ),
                ),
                // Nếu bạn có thêm tab, cũng bọc chúng trong Expanded
                // Ví dụ:
                // Expanded(
                //   child: _buildNavTab(
                //     "Data & privacy",
                //     isActive: _activeTab == "Data & privacy",
                //     onTap: () {
                //       setState(() { _activeTab = "Data & privacy"; });
                //     },
                //   ),
                // ),
              ],
            ),
            // 👆👆👆 THAY ĐỔI KẾT THÚC Ở ĐÂY 👆👆👆
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        // 👇👇👇 HIỂN THỊ NỘI DUNG DỰA TRÊN _activeTab 👇👇👇
        child: _activeTab == "Personal info"
            ? _buildPersonalInfoContent()
            : _activeTab == "Settings"
                ? _buildSettingsContent()
                : _buildHomeContent(), // Hoặc một placeholder cho các tab khác
      ),
      backgroundColor: Colors.grey[100],
    );
  }

  Widget _buildHomeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // Avatar và Welcome message có thể giữ lại ở trên cùng cho tất cả các tab
        // nếu bạn muốn, hoặc chỉ hiển thị ở tab "Home" hoặc "Personal info".
        // Hiện tại mình để nó hiển thị lại trong mỗi hàm _build...Content cho dễ quản lý.
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.blue[700],
          backgroundImage: _userAvatarImage,
          child: _userAvatarImage == null
              ? Text(_userInitial,
                  style: const TextStyle(fontSize: 40, color: Colors.white))
              : null,
        ),
        const SizedBox(height: 16),
        Text('Welcome, $_userName',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            children: <TextSpan>[
              const TextSpan(
                  text:
                      'Manage your info, privacy, and security to make Google work better for you. '),
              TextSpan(
                  text: 'Learn more',
                  style: TextStyle(color: Colors.blue[700])),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Card "Privacy & personalization" và "Your account is protected" (trong một Row)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInfoActionCard(
                title: "Privacy & personalization",
                description:
                    "See the data in your Google Account and choose what activity is saved to personalize your Google experience.",
                actionText: "Manage your data & privacy",
                onActionTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Navigate to Manage Data & Privacy")));
                },
                // Thay bằng Image.asset('assets/images/privacy_personalization_icon.png') nếu có
                leadingIconWidget: const Icon(Icons.palette_outlined,
                    size: 40, color: Colors.orangeAccent), // Placeholder icon
              ),
            ),
            const SizedBox(width: 16), // Khoảng cách giữa 2 card
            Expanded(
              child: _buildInfoActionCard(
                title: "Your account is protected",
                description:
                    "The Security Checkup checked your account and found no recommended actions.",
                actionText: "See details",
                onActionTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Navigate to Security Checkup Details")));
                },
                // Thay bằng Image.asset('assets/images/account_protected_icon.png') nếu có
                leadingIconWidget: const Icon(Icons.shield_outlined,
                    size: 40, color: Colors.green), // Placeholder icon
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Card "Privacy Checkup"
        _buildInfoActionCard(
          title: "Privacy Checkup",
          description:
              "Choose the privacy settings that are right for you with this step-by-step guide.",
          actionText: "Take Privacy Checkup",
          onActionTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Navigate to Privacy Checkup")));
          },
          // Thay bằng Image.asset('assets/images/privacy_checkup_banner.png') nếu có
          // Nếu là banner lớn, bạn có thể cần custom widget này thêm
          leadingIconWidget: const Icon(Icons.privacy_tip_outlined,
              size: 60,
              color:
                  Colors.blue), // Placeholder icon, có thể là một banner Image
          isFullWidthImage: true, // Giả sử đây là banner
        ),
        const SizedBox(height: 30),

        // Phần "Looking for something else?"
        Text(
          "Looking for something else?",
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800]),
        ),
        const SizedBox(height: 12),
        _buildLookingForSomethingElseItem(
          icon: Icons.search,
          text: "Search Google Account",
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Open Search Google Account")));
          },
        ),
        _buildLookingForSomethingElseItem(
          icon: Icons.help_outline,
          text: "See help options",
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Open Help Options")));
          },
        ),
        _buildLookingForSomethingElseItem(
          icon: Icons.feedback_outlined,
          text: "Send feedback",
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Open Send Feedback")));
          },
        ),
        const SizedBox(height: 20), // Thêm khoảng trống ở cuối
      ],
    );
  }

// Hàm helper để tạo các card thông tin có hành động
  Widget _buildInfoActionCard({
    required String title,
    required String description,
    required String actionText,
    required VoidCallback onActionTap,
    required Widget leadingIconWidget, // Để linh hoạt cho icon hoặc image
    bool isFullWidthImage = false,
  }) {
    return Card(
      elevation: 1.5, // Thêm chút đổ bóng nhẹ
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87)),
                      const SizedBox(height: 6),
                      Text(description,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              height: 1.4)),
                    ],
                  ),
                ),
                if (!isFullWidthImage) ...[
                  // Chỉ hiển thị icon nhỏ nếu không phải banner toàn chiều rộng
                  const SizedBox(width: 16),
                  leadingIconWidget,
                ]
              ],
            ),
            if (isFullWidthImage) ...[
              // Hiển thị banner nếu có
              const SizedBox(height: 16),
              Center(child: leadingIconWidget), // Căn giữa banner
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),
            InkWell(
              onTap: onActionTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  actionText,
                  style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                      fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hàm helper cho các mục "Looking for something else?"
  Widget _buildLookingForSomethingElseItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Card(
      // Bọc mỗi mục trong Card để có đường viền và nền riêng
      elevation: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey[700]),
        title: Text(text,
            style: const TextStyle(color: Colors.black87, fontSize: 15)),
        trailing:
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[500]),
        onTap: onTap,
      ),
    );
  }

  Widget _buildPersonalInfoContent() {
    return Column(
      // 👇👇👇 THAY ĐỔI: Bắt đầu trực tiếp với tiêu đề "Personal Info" 👇👇👇
      crossAxisAlignment: CrossAxisAlignment.start, // Căn lề trái cho tiêu đề
      children: <Widget>[
        // Giữ lại phần hiển thị "Personal Info" và các card bên dưới
        const Padding( // Sử dụng Padding để tiêu đề không quá sát lề trên nếu bỏ các phần trên
          padding: EdgeInsets.only(top: 0, bottom: 10.0), // Điều chỉnh padding top nếu cần
          child: Text("Personal Info",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87)),
        ),
        // const SizedBox(height: 10), // SizedBox này có thể không cần nữa nếu Padding trên đã đủ
        _buildInfoCard(
          children: [
            _buildProfileListItem(
                title: "Avatar",
                value: "View or change your avatar",
                currentAvatar: _userAvatarImage,
                initial: _userInitial,
                onTap: _navigateToEditProfile),
            _buildProfileListItem(
                icon: Icons.badge_outlined,
                title: "Name",
                value: _userName,
                onTap: _navigateToEditProfile),
            _buildProfileListItem(
                icon: Icons.phone_outlined,
                title: "Phone",
                value: _userPhoneNumber ?? "Add recovery phone",
                onTap: () {/* ... */}),
          ],
        ),
        const SizedBox(height: 20),
        _buildInfoCard(
          children: [
            _buildActionButton(
                title: "Chỉnh sửa hồ sơ",
                icon: Icons.edit_outlined,
                onTap: _navigateToEditProfile),
            _buildActionButton(
                title: "Đổi mật khẩu",
                icon: Icons.lock_outline,
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ChangePasswordScreen()));
                }),
            _buildActionButton(
                title: "Xác thực 2 yếu tố (2FA)",
                icon: Icons.security_outlined,
                isLinkStyle: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Mở màn hình 2FA (chưa làm)")));
                }),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSettingsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Căn lề trái cho tiêu đề
      children: <Widget>[
        // Không cần hiển thị lại avatar và welcome message ở đây nếu AppBar đã có
        // Hoặc bạn có thể thêm một tiêu đề khác cho phần Cài đặt
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            "Cài đặt ứng dụng", // Hoặc "General Settings"
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ),
        _buildInfoCard(
          // Sử dụng lại _buildInfoCard để có giao diện đồng nhất
          children: [
            _buildSettingsListItem(
              icon: Icons.notifications_outlined,
              title: 'Thông báo',
              subtitle: 'Cài đặt âm thanh, rung, ưu tiên',
              onTap: () {
                // Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationSettingsScreen()));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Mở Cài đặt Thông báo (chưa làm)")));
              },
            ),
            _buildSettingsListItem(
              icon: Icons.palette_outlined,
              title: 'Hiển thị',
              subtitle: 'Chủ đề, font chữ',
              onTap: () {
                // Navigator.push(context, MaterialPageRoute(builder: (context) => const DisplaySettingsScreen()));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Mở Cài đặt Hiển thị (chưa làm)")));
              },
            ),
            _buildSettingsListItem(
              icon: Icons.reply_all_outlined,
              title: 'Chế độ tự động trả lời',
              subtitle:
                  'Thiết lập trả lời tự động khi bạn vắng mặt', // Thêm mô tả rõ hơn
              onTap: () {
                // Navigator.push(context, MaterialPageRoute(builder: (context) => const AutoAnswerModeScreen()));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Mở Cài đặt Tự động trả lời (chưa làm)")));
              },
            ),
            _buildSettingsListItem(
              icon: Icons.label_outline,
              title: 'Quản lý nhãn',
              subtitle: 'Tạo, sửa, xóa các nhãn email', // Thêm mô tả rõ hơn
              onTap: () {
                // Navigator.push(context, MaterialPageRoute(builder: (context) => const LabelManagementScreen()));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Mở Quản lý nhãn (chưa làm)")));
              },
            ),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  // Hàm helper mới cho các mục cài đặt (tương tự _buildProfileListItem nhưng có thể tùy chỉnh)
  Widget _buildSettingsListItem({
    required IconData icon,
    required String title,
    String? subtitle, // Subtitle là tùy chọn
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(title,
          style: const TextStyle(
              fontSize: 16, color: Colors.black87)), // Tăng nhẹ fontSize
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(color: Colors.grey[600], fontSize: 14))
          : null,
      trailing:
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[500]),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8), // Tăng nhẹ padding vertical
    );
  }

  // ... (Các hàm _buildNavTab, _buildInfoCard, _buildProfileListItem, _buildActionButton không đổi)
  Widget _buildNavTab(String title,
      {bool isActive = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        // Thêm alignment để chữ căn giữa trong không gian của Expanded
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
            vertical: 16.0), // Chỉ cần padding vertical
        decoration: isActive
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: Colors.blue[700]!,
                      width: 2.5), // Tăng độ dày border một chút
                ),
              )
            : null,
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.blue[700] : Colors.grey[700],
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 0),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: Colors.grey[300]!, width: 0.8)),
      child: Column(
        children: List.generate(children.length, (index) {
          final isLastItem = index == children.length - 1;
          final currentIsListTile = children[index] is ListTile;
          final nextIsListTile = !isLastItem && children[index + 1] is ListTile;

          return Column(
            children: [
              children[index],
              if (currentIsListTile && nextIsListTile && !isLastItem)
                Divider(
                    height: 1,
                    indent:
                        (children[index] as ListTile).leading != null ? 56 : 16,
                    endIndent: 0),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildProfileListItem({
    IconData? icon,
    required String title,
    required String value,
    ImageProvider? currentAvatar,
    String? initial,
    VoidCallback? onTap,
  }) {
    Widget leadingWidget;
    if (title == "Avatar") {
      leadingWidget = CircleAvatar(
        backgroundImage: currentAvatar,
        backgroundColor: Colors.blue[700],
        radius: 18,
        child: currentAvatar == null && initial != null
            ? Text(initial,
                style: const TextStyle(color: Colors.white, fontSize: 16))
            : null,
      );
    } else {
      leadingWidget = Icon(icon, color: Colors.grey[700]);
    }

    return ListTile(
      leading: leadingWidget,
      title: Text(title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.normal,
              color: Colors.black87)),
      subtitle: value.isNotEmpty
          ? Text(value, style: TextStyle(color: Colors.grey[600], fontSize: 13))
          : null,
      trailing:
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[500]),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    VoidCallback? onTap,
    bool isLinkStyle = false,
  }) {
    return ListTile(
      leading:
          Icon(icon, color: isLinkStyle ? Colors.blue[700] : Colors.grey[700]),
      title: Text(
        title,
        style: TextStyle(
          color: isLinkStyle ? Colors.blue[700] : Colors.black87,
          fontWeight: FontWeight.normal,
          fontSize: 15,
        ),
      ),
      trailing: isLinkStyle
          ? null
          : Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[500]),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
