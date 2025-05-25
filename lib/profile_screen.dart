// lib/profile_screen.dart
import 'dart:io'; // Thêm import này
import 'package:flutter/material.dart';
import 'edit_profile_screen.dart'; // Import màn hình chỉnh sửa
import 'change_password_screen.dart'; // Import màn hình đổi mật khẩu
// import 'custom_page_route.dart'; // Nếu bạn dùng custom route
// import 'package:flutter/gestures.dart'; // Uncomment if you use TapGestureRecognizer

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = "Trần Hữu Đạt";
  String _userInitial = "Đ";
  String? _userPhoneNumber;
  ImageProvider?
      _userAvatarImage; // e.g., AssetImage('images/your_actual_profile_avatar.png')

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
        AssetImage('images/mahiru.png'); // Example if using the same avatar
    // HOẶC nếu bạn có URL:
    // _userAvatarImage = NetworkImage('URL_TO_USER_AVATAR_IMAGE');
  }

// Hàm để điều hướng và nhận kết quả từ EditProfileScreen
  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute( // Hoặc dùng custom route của bạn
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
        // Cập nhật lại _userInitial nếu tên thay đổi
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
              backgroundImage:
                  _userAvatarImage, // SẼ SỬ DỤNG HÌNH ẢNH NẾU _userAvatarImage KHÔNG NULL
              child: _userAvatarImage ==
                      null // CHỈ HIỂN THỊ CHỮ NẾU _userAvatarImage LÀ NULL
                  ? Text(
                      _userInitial,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    )
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
                bottom: BorderSide(color: Colors.grey[300]!, width: 1.0),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildNavTab("Home", isActive: false, onTap: () {}),
                  _buildNavTab("Personal info", isActive: true, onTap: () {}),
                  _buildNavTab("Data & privacy", isActive: false, onTap: () {}),
                  _buildNavTab("Security", isActive: false, onTap: () {}),
                  _buildNavTab("People & sharing",
                      isActive: false, onTap: () {}),
                  _buildNavTab("Payments & subscriptions",
                      isActive: false, onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue[700],
              backgroundImage: _userAvatarImage,
              child: _userAvatarImage == null
                  ? Text(
                      _userInitial,
                      style: const TextStyle(fontSize: 40, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome, $_userName',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
              textAlign: TextAlign.center,
            ),
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
                    style: TextStyle(color: Colors.blue[700]),
                    // recognizer: TapGestureRecognizer()..onTap = () { /* Handle learn more tap */ }
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Personal Info",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
              ),
            ),
            const SizedBox(height: 10),
            _buildInfoCard(
              children: [
                _buildProfileListItem(
                  title: "Avatar",
                  value: "View or change your avatar",
                  currentAvatar: _userAvatarImage,
                  initial: _userInitial,
                  onTap: _navigateToEditProfile, // GỌI HÀM KHI NHẤN VÀO AVATAR TRONG LIST
                ),
                _buildProfileListItem(
                  icon: Icons.badge_outlined,
                  title: "Name",
                  value: _userName,
                  onTap: _navigateToEditProfile, // HOẶC KHI NHẤN VÀO TÊN
                ),
                _buildProfileListItem(
                  icon: Icons.phone_outlined,
                  title: "Phone",
                  value: _userPhoneNumber ?? "Add recovery phone",
                  onTap: () { /* Navigate to edit phone screen, tương tự _navigateToEditProfile */ },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoCard(
              children: [
                _buildActionButton(
                  title: "Chỉnh sửa hồ sơ",
                  icon: Icons.edit_outlined,
                  onTap: _navigateToEditProfile, // SỬ DỤNG HÀM ĐÃ TẠO
                ),
                _buildActionButton(
                  title: "Đổi mật khẩu",
                  icon: Icons.lock_outline,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                      // Hoặc dùng custom route: SlideRightRoute(page: const ChangePasswordScreen()),
                    );
                  },
                ),
                // ... (nút 2-step verification)
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
      backgroundColor: Colors.grey[100],
    );
  }

  Widget _buildNavTab(String title,
      {bool isActive = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
        decoration: isActive
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.blue[700]!, width: 2.0),
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
          // Check if current and next are ListTiles to add divider correctly for action buttons
          final currentIsListTile = children[index] is ListTile;
          final nextIsListTile = !isLastItem && children[index + 1] is ListTile;

          return Column(
            children: [
              children[index],
              if (currentIsListTile && nextIsListTile && !isLastItem)
                Divider(
                    height: 1,
                    indent: (children[index] as ListTile).leading != null
                        ? 56
                        : 16, // Indent based on leading icon
                    endIndent: 0),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildProfileListItem({
    IconData? icon, // Made optional for Avatar case
    required String title,
    required String value,
    ImageProvider? currentAvatar,
    String? initial,
    VoidCallback? onTap,
  }) {
    Widget leadingWidget;
    if (title == "Avatar") {
      leadingWidget = CircleAvatar(
        backgroundImage:
            currentAvatar, // currentAvatar sẽ là _userAvatarImage khi gọi hàm
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
