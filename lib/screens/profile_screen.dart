// lib/features/profile/profile_screen.dart (Hoặc tên file của bạn)
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gmail/screens/edit_profile_screen.dart'; // Sửa đường dẫn nếu cần
import 'package:gmail/screens/change_password_screen.dart'; // Sửa đường dẫn
// THÊM IMPORT CHO MÀN HÌNH CÀI ĐẶT 2FA
import 'package:gmail/screens/setup_2fa_screen.dart'; 
import 'package:pinput/pinput.dart'; // THÊM IMPORT CHO PINPUT

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String _userName = "Đang tải...";
  String _userInitial = "";
  String? _userPhoneNumber;
  ImageProvider? _userAvatarImage; // Sẽ là NetworkImage, FileImage hoặc AssetImage
  String? _userAvatarUrl; // URL từ Firestore

  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  bool _is2FAEnabled = false; // THÊM: Biến trạng thái cho 2FA
  String? _currentSecurityPin; // THÊM: Lưu mã PIN hiện tại của người dùng
  int _pinAttempts = 0; // THÊM: Đếm số lần nhập PIN sai
  DateTime? _lockoutEndTime; // THÊM: Thời điểm kết thúc khóa
  bool _avatarWasUpdatedInSession = false; // ADDED: To track avatar changes

  // Thêm biến để quản lý tab đang active
  String _activeTab = "Personal info"; // THAY ĐỔI: Mặc định là "Personal info"

  // ĐỊNH NGHĨA PIN THEMES ĐỂ TÁI SỬ DỤNG
  final PinTheme _defaultPinTheme = PinTheme(
    width: 48,
    height: 52,
    textStyle: TextStyle(fontSize: 20, color: Colors.grey[850], fontWeight: FontWeight.w600),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.grey[400]!),
      borderRadius: BorderRadius.circular(8),
    ),
  );

  late final PinTheme _focusedPinTheme = _defaultPinTheme.copyDecorationWith(
    border: Border.all(color: Colors.blue[700]!),
  );

  late final PinTheme _submittedPinTheme = _defaultPinTheme.copyWith(
    decoration: _defaultPinTheme.decoration!.copyWith(
      color: Colors.grey[100],
    ),
  );

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      // Xử lý trường hợp người dùng chưa đăng nhập (ví dụ: điều hướng về login)
      if (mounted) {
        setState(() {
          _isLoading = false;
          _userName = "N/A";
        });
      }
      return;
    }

    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (mounted && userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        _userName = data['name'] ?? 'Chưa có tên';
        _userPhoneNumber = data['phone']; // Có thể null
        _userAvatarUrl = data['avatarUrl']; // Có thể null
        _is2FAEnabled = data['is2FAEnabled'] ?? false; // THÊM: Tải trạng thái 2FA từ Firestore
        _currentSecurityPin = data['securityPin']; // THÊM: Tải mã PIN hiện tại

        if (_userAvatarUrl != null) {
          _userAvatarImage = NetworkImage(_userAvatarUrl!);
        } else {
          // Nếu không có avatarUrl, _userAvatarImage sẽ là null.
          // CircleAvatar sẽ tự động hiển thị _userInitial.
          _userAvatarImage = null; 
        }

        if (_userName.isNotEmpty && _userName != "Đang tải..." && _userName != 'Chưa có tên') {
          // Cập nhật logic: Luôn lấy ký tự đầu tiên của toàn bộ tên
          _userInitial = _userName[0].toUpperCase(); 
        } else {
          _userInitial = "?"; // Hoặc một ký tự mặc định khác
        }
      } else {
        _userName = "Không tìm thấy dữ liệu";
        _userInitial = "N/A";
      }    } catch (e) {
      if (mounted) {
        _userName = "Lỗi tải dữ liệu";
        _userInitial = "!"; 
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          currentName: _userName, // Ensure currentName is passed
          currentAvatar: _userAvatarImage, // Truyền ImageProvider hiện tại
          currentInitial: _userInitial, // Pass the user's initial
        ),
      ),
    );

    if (result != null && result is Map) {
      bool hasChanges = false;
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Cập nhật tên
      if (result['name'] != null && result['name'] != _userName) {
        _userName = result['name'];
        await _firestore.collection('users').doc(currentUser.uid).update({'name': _userName});
        if (_userName.isNotEmpty) {
          // Cập nhật logic: Luôn lấy ký tự đầu tiên của toàn bộ tên
          _userInitial = _userName[0].toUpperCase(); 
        }
        hasChanges = true;
      }

      // Cập nhật avatar
      File? avatarFile = result['avatarFile'] as File?;
      Uint8List? avatarBytes = result['avatarBytes'] as Uint8List?;

      if (avatarFile != null || avatarBytes != null) {
        if (mounted) {
          setState(() { _isUploadingAvatar = true; });
        }
        try {
          String actualFileName = '${DateTime.now().millisecondsSinceEpoch}.jpg'; // Filename without UID prefix
          
          // Corrected path structure to match /avatars/{userId}/{fileName}
          Reference storageRef = _storage.ref().child('avatars/${currentUser.uid}/$actualFileName');
          UploadTask uploadTask;

          if (avatarBytes != null) { // Ưu tiên bytes cho web
            uploadTask = storageRef.putData(avatarBytes);
          } else if (avatarFile != null) { // Sau đó là file cho mobile
            uploadTask = storageRef.putFile(avatarFile);
          } else {
            // Should not happen if logic is correct, but as a fallback:
            if (mounted) setState(() { _isUploadingAvatar = false; });
            return;
          }
          
          TaskSnapshot snapshot = await uploadTask;
          String downloadUrl = await snapshot.ref.getDownloadURL();

          await _firestore.collection('users').doc(currentUser.uid).update({'avatarUrl': downloadUrl});
          if (mounted) {
            _userAvatarUrl = downloadUrl;
            _userAvatarImage = NetworkImage(downloadUrl); // Cập nhật để hiển thị ngay
            _avatarWasUpdatedInSession = true; // CHANGED: Set flag to true
          }
          hasChanges = true;
        } catch (e) {
          // print("Lỗi tải avatar: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lỗi tải lên avatar. Vui lòng thử lại.')),
            );
          }
        } finally {
          if (mounted) {
            setState(() { _isUploadingAvatar = false; });
          }
        }
      }
      if (hasChanges && mounted) {
        setState(() {}); // Cập nhật UI nếu có thay đổi
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black54),
            onPressed: () => Navigator.pop(context, _avatarWasUpdatedInSession), // CHANGED: Pass flag back
          ),
          title: const Text('Account', style: TextStyle(color: Colors.black87)),
          backgroundColor: Colors.white,
          elevation: 1.0,
        ),
        body: const Center(child: CircularProgressIndicator()),
        backgroundColor: Colors.grey[100],
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () {
            Navigator.pop(context, _avatarWasUpdatedInSession); // CHANGED: Pass flag back
          },
        ),
        title: const Text('Account', style: TextStyle(color: Colors.black87)), // Bỏ logo Google
        backgroundColor: Colors.white, // Nền trắng cho AppBar
        elevation: 1.0, // THÊM DẤU PHẨY
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
              backgroundColor: Colors.blue[700], // Giữ màu xanh cho avatar placeholder
              backgroundImage: _userAvatarImage, // Sử dụng _userAvatarImage đã được cập nhật
              child: (_userAvatarImage == null && _userInitial.isNotEmpty)
                  ? Text(_userInitial,
                      style: const TextStyle(color: Colors.white, fontSize: 16))
                  : null,
            ),
          ),
        ], // KẾT THÚC actions
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, // Nền trắng cho thanh tab
              border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1.0)),
            ),
            child: Row(
              children: <Widget>[
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
              ],
            ),
          ),
        ), // KẾT THÚC bottom
      ), // KẾT THÚC AppBar
      body: Stack( // Sử dụng Stack để hiển thị loading indicator khi tải avatar
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: _activeTab == "Settings"
                    ? _buildSettingsContent()
                    : _buildPersonalInfoContent(),
          ),
          if (_isUploadingAvatar)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ), // KẾT THÚC body Stack
      backgroundColor: Colors.grey[100], // Nền xám nhạt cho body
    ); // KẾT THÚC Scaffold
  }
  // LOẠI BỎ HÀM _buildHomeContent()
  // Widget _buildHomeContent() { ... }

  Widget _buildPersonalInfoContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(bottom: 10.0),
          child: Text("Personal Info",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87)),
        ),
        _buildInfoCard(
          children: [
            _buildProfileListItem(
                title: "Avatar",
                value: "View or change your avatar",
                currentAvatarForDisplay: _userAvatarImage, // Truyền _userAvatarImage
                initialForDisplay: _userInitial, // Truyền _userInitial
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
                onTap: null // THAY ĐỔI: Không cho phép onTap cho mục Phone
                ),
          ],
        ),
        const SizedBox(height: 20),
        _buildInfoCard(
          children: [
            // _buildActionButton(  // Bỏ nút Chỉnh sửa hồ sơ
            //     title: "Chỉnh sửa hồ sơ",
            //     icon: Icons.edit_outlined,
            //     onTap: _navigateToEditProfile),
            _buildActionButton(
                title: "Đổi mật khẩu",
                icon: Icons.lock_outline,
                onTap: () async { 
                  User? currentUser = _auth.currentUser;
                  if (currentUser == null) return;

                  if (_is2FAEnabled) {
                    if (_lockoutEndTime != null && DateTime.now().isBefore(_lockoutEndTime!)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Bạn đã nhập sai quá nhiều lần. Vui lòng thử lại sau khi khóa kết thúc."),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    String? enteredPin = await showDialog<String>(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        TextEditingController pinDialogController = TextEditingController();
                        String? dialogDisplayError;

                        return StatefulBuilder(
                          builder: (context, setStateDialog) {
                            return AlertDialog(
                              backgroundColor: Colors.white,
                              title: Text('Xác nhận mã PIN', style: TextStyle(color: Colors.grey[850], fontWeight: FontWeight.bold)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    "Vui lòng nhập mã PIN bảo mật của bạn để tiếp tục đổi mật khẩu.",
                                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 20),
                                  Center(
                                    child: Pinput(
                                      controller: pinDialogController,
                                      length: 6,
                                      obscureText: true,
                                      obscuringCharacter: '*',
                                      autofocus: true,
                                      defaultPinTheme: _defaultPinTheme,
                                      focusedPinTheme: _focusedPinTheme,
                                      submittedPinTheme: _submittedPinTheme,
                                      showCursor: true,
                                    ),
                                  ),
                                  if (dialogDisplayError != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10.0),
                                      child: Text(
                                        dialogDisplayError!,
                                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                ],
                              ),
                              actions: <Widget>[
                                TextButton(
                                  child: Text('Hủy', style: TextStyle(color: Colors.grey[700])),
                                  onPressed: () => Navigator.of(context).pop(), 
                                ),
                                TextButton(
                                  child: Text('Xác nhận', style: TextStyle(color: Colors.blue[700])),
                                  onPressed: () {
                                    final String pin = pinDialogController.text;
                                    String? formatValidationError;
                                    
                                    if (pin.isEmpty) {
                                      formatValidationError = "Vui lòng nhập mã PIN.";
                                    } else if (pin.length != 6) {
                                      formatValidationError = "Mã PIN phải gồm 6 chữ số.";
                                    } else if (!RegExp(r'^[0-9]{6}$').hasMatch(pin)) { // CORRECTED RegExp
                                      formatValidationError = "Mã PIN chỉ được chứa số.";
                                    }

                                    if (formatValidationError != null) {
                                      setStateDialog(() {
                                        dialogDisplayError = formatValidationError;
                                      });
                                      return;
                                    }
                                    setStateDialog(() { dialogDisplayError = null; });

                                    if (_currentSecurityPin == null) {
                                      setStateDialog(() {
                                        dialogDisplayError = "Lỗi: Không tìm thấy mã PIN đã lưu. Vui lòng kiểm tra cài đặt 2FA.";
                                      });
                                      return;
                                    }

                                    if (pin == _currentSecurityPin) {
                                      Navigator.of(context).pop(pin); // Correct PIN
                                    } else {
                                      setState(() { 
                                        _pinAttempts++;
                                        if (_pinAttempts >= 5) {
                                          _lockoutEndTime = DateTime.now().add(const Duration(minutes: 5));
                                          _pinAttempts = 0; 
                                          Navigator.of(context).pop("LOCKED_OUT");
                                        } else {
                                          setStateDialog(() {
                                            dialogDisplayError = "Mã PIN không chính xác. Còn ${5 - _pinAttempts} lần thử.";
                                          });
                                        }
                                      });
                                    }
                                  },
                                ),
                              ],
                            );
                          }
                        );
                      },
                    );

                    if (enteredPin == "LOCKED_OUT") {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Bạn đã nhập sai PIN 5 lần. Tài khoản tạm khóa nhập PIN trong 5 phút."),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } else if (enteredPin != null && _currentSecurityPin != null && enteredPin == _currentSecurityPin) {
                      setState(() { 
                        _pinAttempts = 0; 
                        _lockoutEndTime = null;
                      });
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                      );
                    }
                  } else {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ChangePasswordScreen()));
                  }
                }),
            _buildTwoFactorAuthItem(),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSettingsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            "Cài đặt ứng dụng",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800], // Giữ màu chữ cho tiêu đề Settings
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Mở Cài đặt Thông báo (chưa làm)")));
              },
            ),
            _buildSettingsListItem(
              icon: Icons.palette_outlined,
              title: 'Hiển thị',
              subtitle: 'Chủ đề, font chữ',
              onTap: () {
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Mở Cài đặt Tự động trả lời (chưa làm)")));
              },
            ),
            _buildSettingsListItem(
              icon: Icons.label_outline,
              title: 'Quản lý nhãn',
              subtitle: 'Tạo, sửa, xóa các nhãn email', // Thêm mô tả rõ hơn
              onTap: () {
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

  Widget _buildNavTab(String title,
      {bool isActive = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        decoration: isActive
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: Colors.blue[700]!,
                      width: 2.5),
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
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 0),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: Colors.grey[300]!, width: 0.8)),
      child: Column(
        children: List.generate(children.length, (index) {
          final isLastItem = index == children.length - 1;
          final currentWidget = children[index];
          bool shouldAddDivider = false;
          if (currentWidget is ListTile && !isLastItem) {
            // Kiểm tra xem widget tiếp theo có phải là ListTile không để quyết định có thêm Divider không
            // Điều này giúp tránh Divider nếu item cuối cùng không phải ListTile hoặc là item cuối cùng.
            if (index + 1 < children.length && children[index+1] is ListTile) {
               shouldAddDivider = true;
            }
          }

          return Column(
            children: [
              currentWidget,
              if (shouldAddDivider)
                Divider(
                    height: 1,
                    // Cẩn thận với type cast, đảm bảo currentWidget thực sự là ListTile nếu có leading
                    indent: (currentWidget is ListTile && currentWidget.leading != null) ? 56 : 16, 
                    endIndent: 0),
            ],
          );
        }),
      ),
    );
  }

  // Cập nhật _buildProfileListItem để hiển thị avatar đúng
  Widget _buildProfileListItem({
    IconData? icon,
    required String title,
    required String value,
    ImageProvider? currentAvatarForDisplay, // Đổi tên để rõ ràng hơn
    String? initialForDisplay, // Đổi tên
    VoidCallback? onTap,
  }) {
    Widget leadingWidget;
    if (title == "Avatar") {
      leadingWidget = CircleAvatar(
        backgroundImage: currentAvatarForDisplay, // Sử dụng ImageProvider được truyền vào
        backgroundColor: Colors.blue[700],
        radius: 18,
        child: (currentAvatarForDisplay == null && initialForDisplay != null && initialForDisplay.isNotEmpty)
            ? Text(initialForDisplay,
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
      trailing: onTap != null // THAY ĐỔI: Chỉ hiển thị icon nếu có onTap
          ? Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[500])
          : null, // Không hiển thị gì nếu không có onTap
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }

  // HÀM MỚI ĐỂ BUILD MỤC 2FA VỚI SWITCH
  Widget _buildTwoFactorAuthItem() {
    return ListTile(
      leading: Icon(Icons.security_outlined, color: Colors.grey[700]),
      title: Text(
        "Xác thực 2 yếu tố (2FA)",
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.normal,
          fontSize: 15,
        ),
      ),
      trailing: Switch(
        value: _is2FAEnabled,
        onChanged: (bool value) async {
          User? currentUser = _auth.currentUser;
          if (currentUser == null) return;

          if (value) {
            // User wants to turn ON 2FA
            final setupSuccess = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Setup2FAScreen(userId: currentUser.uid)),
            );

            if (setupSuccess == true) {
              await _loadUserData(); 
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Xác thực 2 yếu tố đã được bật thành công.")),
                );
              }
            }
          } else {
            // User wants to turn OFF 2FA
            if (_lockoutEndTime != null && DateTime.now().isBefore(_lockoutEndTime!)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Bạn đã nhập sai quá nhiều lần. Vui lòng thử lại sau."),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            bool confirmInitialDisable = await showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      backgroundColor: Colors.white,
                      title: const Text(
                        "Tắt xác thực 2 yếu tố?",
                        style: TextStyle(color: Colors.black87),
                      ),
                      content: const Text(
                        "Bạn có chắc chắn muốn tắt xác thực 2 yếu tố không? Điều này có thể làm giảm tính bảo mật cho tài khoản của bạn.",
                        style: TextStyle(color: Colors.black54),
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: Text(
                            "Hủy",
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                        ),
                        TextButton(
                          child: Text(
                            "Tắt",
                            style: TextStyle(color: Colors.red[700]),
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                        ),
                      ],
                    );
                  },
                ) ?? false;

            if (confirmInitialDisable) {
              // Re-affirming structure for PIN dialog when turning OFF 2FA
              String? enteredPin = await showDialog<String>(
                context: context,
                barrierDismissible: false, 
                builder: (BuildContext context) {
                  TextEditingController pinDialogController = TextEditingController();
                  String? dialogDisplayError; 

                  return StatefulBuilder( 
                    builder: (context, setStateDialog) {
                      return AlertDialog(
                        backgroundColor: Colors.white,
                        title: Text('Xác nhận mã PIN', style: TextStyle(color: Colors.grey[850], fontWeight: FontWeight.bold)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center, 
                          children: [
                            Text(
                              "Vui lòng nhập mã PIN bảo mật của bạn để tắt xác thực 2 yếu tố.",
                              style: TextStyle(color: Colors.grey[700], fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 20),
                            Center( 
                              child: Pinput(
                                controller: pinDialogController,
                                length: 6,
                                obscureText: true,
                                obscuringCharacter: '*',
                                autofocus: true,
                                defaultPinTheme: _defaultPinTheme, 
                                focusedPinTheme: _focusedPinTheme, 
                                submittedPinTheme: _submittedPinTheme, 
                                showCursor: true,
                              ),
                            ),
                            if (dialogDisplayError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 10.0),
                                child: Text(
                                  dialogDisplayError!,
                                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: Text('Hủy', style: TextStyle(color: Colors.grey[700])),
                            onPressed: () {
                              Navigator.of(context).pop(); 
                            },
                          ),
                          TextButton(
                            child: Text('Xác nhận', style: TextStyle(color: Colors.blue[700])),
                            onPressed: () {
                              final String pin = pinDialogController.text;
                              String? formatValidationError;

                              if (pin.isEmpty) {
                                formatValidationError = "Vui lòng nhập mã PIN.";
                              } else if (pin.length != 6) {
                                formatValidationError = "Mã PIN phải gồm 6 chữ số.";
                              } else if (!RegExp(r'^[0-9]{6}$').hasMatch(pin)) { // Correct RegExp
                                formatValidationError = "Mã PIN chỉ được chứa số.";
                              }

                              if (formatValidationError != null) {
                                setStateDialog(() {
                                  dialogDisplayError = formatValidationError;
                                });
                                return;
                              }
                              setStateDialog(() {
                                dialogDisplayError = null;
                              });

                              if (_currentSecurityPin == null) {
                                setStateDialog(() {
                                  dialogDisplayError = "Lỗi: Không tìm thấy mã PIN đã lưu.";
                                });
                                return;
                              }

                              if (pin == _currentSecurityPin) {
                                Navigator.of(context).pop(pin); 
                              } else {
                                setState(() { 
                                  _pinAttempts++;
                                  if (_pinAttempts >= 5) {
                                    _lockoutEndTime = DateTime.now().add(const Duration(minutes: 5));
                                    _pinAttempts = 0; 
                                    Navigator.of(context).pop("LOCKED_OUT");
                                  } else {
                                    setStateDialog(() {
                                      dialogDisplayError = "Mã PIN không chính xác. Còn ${5 - _pinAttempts} lần thử.";
                                    });
                                  }
                                });
                              }
                            },
                          ),
                        ],
                      );
                    }
                  );
                },
              );
              // Handle dialog result for turning OFF 2FA
              if (enteredPin == "LOCKED_OUT") {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Bạn đã nhập sai PIN 5 lần. Tài khoản tạm khóa nhập PIN trong 5 phút."),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else if (enteredPin != null && _currentSecurityPin != null && enteredPin == _currentSecurityPin) {
                // PIN chính xác, proceed to disable 2FA
                await _firestore.collection('users').doc(currentUser.uid).update({
                  'is2FAEnabled': false,
                  'securityPin': FieldValue.delete(), 
                });
                if (mounted) {
                  setState(() {
                    _is2FAEnabled = false;
                    _currentSecurityPin = null; 
                    _pinAttempts = 0; 
                    _lockoutEndTime = null; 
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Xác thực 2 yếu tố đã được tắt thành công.")));
                }
              } else if (enteredPin == null) {
                // User cancelled the PIN dialog - do nothing, 2FA remains as is.
              }
            }
          }
        },
        activeColor: Colors.blue[700], // Màu của thumb khi ON
        activeTrackColor: Colors.blue[200], // Màu của track khi ON
        inactiveThumbColor: Colors.grey[400], // Màu của thumb khi OFF
        inactiveTrackColor: Colors.white, // Màu của track khi OFF
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
