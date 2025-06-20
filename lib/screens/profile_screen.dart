import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gmail/screens/edit_profile_screen.dart'; 
import 'package:gmail/screens/change_password_screen.dart'; 
import 'package:gmail/screens/setup_2fa_screen.dart'; 
import 'package:gmail/screens/display_settings_screen.dart'; 
import 'package:gmail/screens/label_screen.dart'; 
import 'package:gmail/screens/notification_settings_screen.dart'; 
import 'package:gmail/screens/auto_answer_mode_screen.dart'; 
import 'package:gmail/screens/search_screen.dart'; 
import 'package:pinput/pinput.dart'; 

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
  ImageProvider? _userAvatarImage; 
  String? _userAvatarUrl; 

  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  bool _is2FAEnabled = false; 
  String? _currentSecurityPin; 
  int _pinAttempts = 0; 
  DateTime? _lockoutEndTime; 
  bool _avatarWasUpdatedInSession = false; 

  String _activeTab = "Personal info";

  PinTheme _defaultPinTheme(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return PinTheme(
      width: 48,
      height: 52,
      textStyle: TextStyle(
          fontSize: 20,
          color: isDarkMode ? Colors.grey[200] : Colors.grey[850],
          fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        border: Border.all(color: isDarkMode ? Colors.grey[700]! : Colors.grey[400]!),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  PinTheme _focusedPinTheme(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return _defaultPinTheme(context).copyDecorationWith(
      border: Border.all(color: isDarkMode ? Colors.blue[300]! : Colors.blue[700]!),
    );
  }

  PinTheme _submittedPinTheme(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return _defaultPinTheme(context).copyWith(
      decoration: _defaultPinTheme(context).decoration!.copyWith(
            color: isDarkMode ? Colors.grey[700] : Colors.grey[100],
          ),
    );
  }

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
        _userPhoneNumber = data['phone']; 
        _userAvatarUrl = data['avatarUrl']; 
        _is2FAEnabled = data['is2FAEnabled'] ?? false; 
        _currentSecurityPin = data['securityPin']; 

        if (_userAvatarUrl != null && _userAvatarUrl!.isNotEmpty) {
          _userAvatarImage = NetworkImage(_userAvatarUrl!);
        } else {
          _userAvatarImage = const AssetImage('assets/images/default_avatar.png');
        }

        if (_userName.isNotEmpty && _userName != "Đang tải..." && _userName != 'Chưa có tên') {
          _userInitial = _userName[0].toUpperCase(); 
        } else {
          _userInitial = "?"; 
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
          currentName: _userName, 
          currentAvatar: _userAvatarImage, 
          currentInitial: _userInitial, 
        ),
      ),
    );

    if (result != null && result is Map) {
      bool hasChanges = false;
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return;

      if (result['name'] != null && result['name'] != _userName) {
        _userName = result['name'];
        await _firestore.collection('users').doc(currentUser.uid).update({'name': _userName});
        if (_userName.isNotEmpty) {
          _userInitial = _userName[0].toUpperCase(); 
        }
        hasChanges = true;
      }

      File? avatarFile = result['avatarFile'] as File?;
      Uint8List? avatarBytes = result['avatarBytes'] as Uint8List?;

      if (avatarFile != null || avatarBytes != null) {
        if (mounted) {
          setState(() { _isUploadingAvatar = true; });
        }
        try {
          String actualFileName = '${DateTime.now().millisecondsSinceEpoch}.jpg'; 
          
          Reference storageRef = _storage.ref().child('avatars/${currentUser.uid}/$actualFileName');
          UploadTask uploadTask;

          if (avatarBytes != null) { 
            uploadTask = storageRef.putData(avatarBytes);
          } else if (avatarFile != null) { 
            uploadTask = storageRef.putFile(avatarFile);
          } else {
            if (mounted) setState(() { _isUploadingAvatar = false; });
            return;
          }
          
          TaskSnapshot snapshot = await uploadTask;
          String downloadUrl = await snapshot.ref.getDownloadURL();

          await _firestore.collection('users').doc(currentUser.uid).update({'avatarUrl': downloadUrl});
          if (mounted) {
            _userAvatarUrl = downloadUrl;
            _userAvatarImage = NetworkImage(downloadUrl); 
            _avatarWasUpdatedInSession = true; 
          }
          hasChanges = true;
        } catch (e) {
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
        setState(() {}); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final appBarBackgroundColor = isDarkMode ? const Color(0xFF202124) : Colors.white;
    final appBarTextColor = isDarkMode ? Colors.grey[300] : Colors.black87;
    final appBarIconColor = isDarkMode ? Colors.grey[400] : Colors.black54;
    final scaffoldBackgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.grey[100];
    final activeTabColor = isDarkMode ? Colors.blue[300]! : Colors.blue[700]!; // Made non-nullable
    final dividerColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!; // Made non-nullable


    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: appBarIconColor),
            onPressed: () => Navigator.pop(context, _avatarWasUpdatedInSession),
          ),
          title: Text('Account', style: TextStyle(color: appBarTextColor)),
          backgroundColor: appBarBackgroundColor,
          elevation: isDarkMode ? 0 : 1.0,
        ),
        body: const Center(child: CircularProgressIndicator()),
        backgroundColor: scaffoldBackgroundColor,
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: appBarIconColor),
          onPressed: () {
            Navigator.pop(context, _avatarWasUpdatedInSession);
          },
        ),
        title: Text('Account', style: TextStyle(color: appBarTextColor)),
        backgroundColor: appBarBackgroundColor,
        elevation: isDarkMode ? 0 : 1.0,        actions: [
          IconButton(
            icon: Icon(Icons.search, color: appBarIconColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            }
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: activeTabColor,
              backgroundImage: _userAvatarImage ?? const AssetImage('assets/images/default_avatar.png'),
              child: null, 
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: BoxDecoration(
              color: appBarBackgroundColor, 
              border: Border(
                  bottom: BorderSide(color: dividerColor, width: 1.0)),
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
                    context: context, // Pass context
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
                    context: context, // Pass context
                  ),
                ),
              ],
            ),
          ),
        ), 
      ), 
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: _activeTab == "Settings"
                    ? _buildSettingsContent(context) // Pass context
                    : _buildPersonalInfoContent(context), // Pass context
          ),
          if (_isUploadingAvatar)
            Container(
              color: Colors.black.withOpacity(0.5), // Darker overlay
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ), 
      backgroundColor: scaffoldBackgroundColor,
    ); 
  }

  Widget _buildPersonalInfoContent(BuildContext context) { // Add context
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final sectionTitleColor = isDarkMode ? Colors.grey[200] : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Text("Personal Info",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: sectionTitleColor)),
        ),
        _buildInfoCard(
          context: context, // Pass context
          children: [
            _buildProfileListItem(
                context: context, // Pass context
                title: "Avatar",
                value: "View or change your avatar",
                currentAvatarForDisplay: _userAvatarImage, 
                initialForDisplay: _userInitial, 
                onTap: _navigateToEditProfile),
            _buildProfileListItem(
                context: context, // Pass context
                icon: Icons.badge_outlined,
                title: "Name",
                value: _userName,
                onTap: _navigateToEditProfile),
            _buildProfileListItem(
                context: context, // Pass context
                icon: Icons.phone_outlined,
                title: "Phone",
                value: _userPhoneNumber ?? "Add recovery phone",
                onTap: null 
                ),
          ],        ),
        const SizedBox(height: 20),
        Text(
          "BẢO MẬT",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: sectionTitleColor,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          context: context, // Pass context
          children: [
            _buildActionButton(
                context: context, // Pass context
                title: "Đổi mật khẩu",
                icon: Icons.lock_outline,
                onTap: () async { 
                  User? currentUser = _auth.currentUser;
                  if (currentUser == null) return;

                  if (_is2FAEnabled) {
                    if (_lockoutEndTime != null && DateTime.now().isBefore(_lockoutEndTime!)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text("Bạn đã nhập sai quá nhiều lần. Vui lòng thử lại sau khi khóa kết thúc."),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    String? enteredPin = await showDialog<String>(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext dialogContext) {
                        TextEditingController pinDialogController = TextEditingController();
                        String? dialogDisplayError;
                        final bool isDialogDarkMode = Theme.of(dialogContext).brightness == Brightness.dark;
                        final dialogBackgroundColor = isDialogDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
                        final dialogTitleColor = isDialogDarkMode ? Colors.grey[200] : Colors.grey[850];
                        final dialogContentColor = isDialogDarkMode ? Colors.grey[400] : Colors.grey[700];
                        final dialogButtonTextColor = isDialogDarkMode ? Colors.blue[300] : Colors.blue[700];
                        final dialogCancelButtonColor = isDialogDarkMode ? Colors.grey[400] : Colors.grey[700];


                        return StatefulBuilder(
                          builder: (context, setStateDialog) {
                            return AlertDialog(
                              backgroundColor: dialogBackgroundColor,
                              title: Text('Xác nhận mã PIN', style: TextStyle(color: dialogTitleColor, fontWeight: FontWeight.bold)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    "Vui lòng nhập mã PIN bảo mật của bạn để tiếp tục đổi mật khẩu.",
                                    style: TextStyle(color: dialogContentColor, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  Center(
                                    child: Pinput(
                                      controller: pinDialogController,
                                      length: 6,
                                      obscureText: true,
                                      obscuringCharacter: '*',
                                      autofocus: true,
                                      defaultPinTheme: _defaultPinTheme(dialogContext), // Pass context
                                      focusedPinTheme: _focusedPinTheme(dialogContext), // Pass context
                                      submittedPinTheme: _submittedPinTheme(dialogContext), // Pass context
                                      showCursor: true,
                                    ),
                                  ),
                                  if (dialogDisplayError != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10.0),
                                      child: Text(
                                        dialogDisplayError!,
                                        style: TextStyle(color: Colors.red[isDialogDarkMode ? 300: 700], fontSize: 12),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                ],
                              ),
                              actions: <Widget>[
                                TextButton(
                                  child: Text('Hủy', style: TextStyle(color: dialogCancelButtonColor)),
                                  onPressed: () => Navigator.of(dialogContext).pop(), 
                                ),
                                TextButton(
                                  child: Text('Xác nhận', style: TextStyle(color: dialogButtonTextColor)),
                                  onPressed: () {
                                    final String pin = pinDialogController.text;
                                    String? formatValidationError;
                                    
                                    if (pin.isEmpty) {
                                      formatValidationError = "Vui lòng nhập mã PIN.";
                                    } else if (pin.length != 6) {
                                      formatValidationError = "Mã PIN phải gồm 6 chữ số.";
                                    } else if (!RegExp(r'^[0-9]{6}$').hasMatch(pin)) { 
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
                          content: const Text("Bạn đã nhập sai PIN 5 lần. Tài khoản tạm khóa nhập PIN trong 5 phút."),
                          backgroundColor: Colors.red[700],
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
            _buildTwoFactorAuthItem(context), // Pass context
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSettingsContent(BuildContext context) { // Add context
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 30),
        
        // Main Settings Section
        _buildInfoCard(
          context: context,
          children: [
            // Quản lý nhãn
            _buildSettingsListItem(
              context: context,
              icon: Icons.label_outline,
              title: "Quản lý nhãn",
              subtitle: "Tạo và quản lý nhãn email",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LabelManagementScreen(),
                  ),
                );
              },
            ),
            
            Divider(color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
            _buildSettingsListItem(
              context: context,
              icon: Icons.notifications_outlined,
              title: "Thông báo",
              subtitle: "Cài đặt thông báo email",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationSettingsScreen(),
                  ),
                );
              },
            ),
            
            Divider(color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
            
            _buildSettingsListItem(
              context: context,
              icon: Icons.reply_all,
              title: "Chế độ tự động trả lời",
              subtitle: "Thiết lập tin nhắn tự động",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AutoAnswerModeScreen(),
                  ),
                );
              },
            ),
            
            Divider(color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
            
            // Hiển thị
            _buildSettingsListItem(
              context: context,
              icon: Icons.palette_outlined,
              title: "Hiển thị",
              subtitle: "Chủ đề và font chữ",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DisplaySettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSettingsListItem({
    required BuildContext context, // Add context
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final iconColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];
    final titleColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.grey[500] : Colors.grey[600];
    final trailingIconColor = isDarkMode ? Colors.grey[600] : Colors.grey[500];

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title,
          style: TextStyle(
              fontSize: 16, color: titleColor)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(color: subtitleColor, fontSize: 14))
          : null,
      trailing:
          Icon(Icons.arrow_forward_ios, size: 16, color: trailingIconColor),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8),
    );
  }

  Widget _buildNavTab(String title,
      {bool isActive = false, VoidCallback? onTap, required BuildContext context}) { // Add context
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final activeColor = isDarkMode ? Colors.blue[300]! : Colors.blue[700]!; // Made non-nullable
    final inactiveColor = isDarkMode ? Colors.grey[500]! : Colors.grey[700]!; // Made non-nullable
    final tabBackgroundColor = isDarkMode ? const Color(0xFF202124) : Colors.white;


    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        decoration: BoxDecoration( // Added BoxDecoration to control background
          color: tabBackgroundColor, // Apply tab background color
          border: isActive
            ? Border(
                bottom: BorderSide(
                    color: activeColor,
                    width: 2.5),
              )
            : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? activeColor : inactiveColor,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required List<Widget> children, required BuildContext context}) { // Add context
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final cardBackgroundColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final cardBorderColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final dividerColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];


    return Card(
      elevation: 0,
      color: cardBackgroundColor,
      margin: const EdgeInsets.symmetric(vertical: 0),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: cardBorderColor, width: 0.8)),
      child: Column(
        children: List.generate(children.length, (index) {
          final isLastItem = index == children.length - 1;
          final currentWidget = children[index];
          bool shouldAddDivider = false;
          if (currentWidget is ListTile && !isLastItem) {
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
                    color: dividerColor, // Use themed divider color
                    indent: (currentWidget is ListTile && currentWidget.leading != null) ? 56 : 16, 
                    endIndent: 0),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildProfileListItem({
    required BuildContext context, // Add context
    IconData? icon,
    required String title,
    required String value,
    ImageProvider? currentAvatarForDisplay,
    String? initialForDisplay,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final iconColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];
    final titleColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.grey[500] : Colors.grey[600];
    final trailingIconColor = isDarkMode ? Colors.grey[600] : Colors.grey[500];
    final avatarPlaceholderColor = isDarkMode ? Colors.blue[300] : Colors.blue[700];

    Widget leadingWidget;
    if (title == "Avatar") {
      leadingWidget = CircleAvatar(
        backgroundImage: currentAvatarForDisplay ?? const AssetImage('assets/images/default_avatar.png'),
        backgroundColor: avatarPlaceholderColor,
        radius: 18,
      );
    } else {
      leadingWidget = Icon(icon, color: iconColor);
    }

    return ListTile(
      leading: leadingWidget,
      title: Text(title,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.normal,
              color: titleColor)),
      subtitle: value.isNotEmpty
          ? Text(value, style: TextStyle(color: subtitleColor, fontSize: 13))
          : null,
      trailing: onTap != null
          ? Icon(Icons.arrow_forward_ios, size: 16, color: trailingIconColor)
          : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }

  Widget _buildTwoFactorAuthItem(BuildContext context) { // Add context
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final iconColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];
    final titleColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final switchActiveColor = isDarkMode ? Colors.blue[300] : Colors.blue[700];
    final switchActiveTrackColor = isDarkMode ? Colors.blue[700] : Colors.blue[200]; // Adjusted for better contrast in dark
    final switchInactiveThumbColor = isDarkMode ? Colors.grey[600] : Colors.grey[400];
    final switchInactiveTrackColor = isDarkMode ? Colors.grey[800] : Colors.white;


    return ListTile(
      leading: Icon(Icons.security_outlined, color: iconColor),
      title: Text(
        "Xác thực 2 yếu tố (2FA)",
        style: TextStyle(
          color: titleColor,
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
                  content: const Text("Bạn đã nhập sai quá nhiều lần. Vui lòng thử lại sau."),
                  backgroundColor: Colors.red[isDarkMode ? 400 : 700],
                ),
              );
              return;
            }

            bool confirmInitialDisable = await showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    final bool isDialogDarkMode = Theme.of(dialogContext).brightness == Brightness.dark;
                    final dialogBackgroundColor = isDialogDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
                    final dialogTitleColor = isDialogDarkMode ? Colors.grey[200] : Colors.black87;
                    final dialogContentColor = isDialogDarkMode ? Colors.grey[400] : Colors.black54;
                    final dialogCancelButtonColor = isDialogDarkMode ? Colors.grey[400] : Colors.grey[700];
                    final dialogConfirmButtonColor = isDialogDarkMode ? Colors.red[300] : Colors.red[700];

                    return AlertDialog(
                      backgroundColor: dialogBackgroundColor,
                      title: Text(
                        "Tắt xác thực 2 yếu tố?",
                        style: TextStyle(color: dialogTitleColor),
                      ),
                      content: Text(
                        "Bạn có chắc chắn muốn tắt xác thực 2 yếu tố không? Điều này có thể làm giảm tính bảo mật cho tài khoản của bạn.",
                        style: TextStyle(color: dialogContentColor),
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: Text(
                            "Hủy",
                            style: TextStyle(color: dialogCancelButtonColor),
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                        ),
                        TextButton(
                          child: Text(
                            "Tắt",
                            style: TextStyle(color: dialogConfirmButtonColor),
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                        ),
                      ],
                    );
                  },
                ) ?? false;

            if (confirmInitialDisable) {
              String? enteredPin = await showDialog<String>(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext dialogContext) { // Renamed context to dialogContext
                  TextEditingController pinDialogController = TextEditingController();
                  String? dialogDisplayError;
                  final bool isDialogDarkMode = Theme.of(dialogContext).brightness == Brightness.dark; // Use dialogContext
                  final dialogBackgroundColor = isDialogDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
                  final dialogTitleColor = isDialogDarkMode ? Colors.grey[200] : Colors.grey[850];
                  final dialogContentColor = isDialogDarkMode ? Colors.grey[400] : Colors.grey[700];
                  final dialogButtonTextColor = isDialogDarkMode ? Colors.blue[300] : Colors.blue[700];
                  final dialogCancelButtonColor = isDialogDarkMode ? Colors.grey[400] : Colors.grey[700];


                  return StatefulBuilder(
                    builder: (context, setStateDialog) { // This context is fine
                      return AlertDialog(
                        backgroundColor: dialogBackgroundColor,
                        title: Text('Xác nhận mã PIN', style: TextStyle(color: dialogTitleColor, fontWeight: FontWeight.bold)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Vui lòng nhập mã PIN bảo mật của bạn để tắt xác thực 2 yếu tố.",
                              style: TextStyle(color: dialogContentColor, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: Pinput(
                                controller: pinDialogController,
                                length: 6,
                                obscureText: true,
                                obscuringCharacter: '*',
                                autofocus: true,
                                defaultPinTheme: _defaultPinTheme(dialogContext), // Pass dialogContext
                                focusedPinTheme: _focusedPinTheme(dialogContext), // Pass dialogContext
                                submittedPinTheme: _submittedPinTheme(dialogContext), // Pass dialogContext
                                showCursor: true,
                              ),
                            ),
                            if (dialogDisplayError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 10.0),
                                child: Text(
                                  dialogDisplayError!,
                                  style: TextStyle(color: Colors.red[isDialogDarkMode ? 300 : 700], fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: Text('Hủy', style: TextStyle(color: dialogCancelButtonColor)),
                            onPressed: () {
                              Navigator.of(dialogContext).pop(); // Use dialogContext
                            },
                          ),
                          TextButton(
                            child: Text('Xác nhận', style: TextStyle(color: dialogButtonTextColor)),
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
                      content: const Text("Bạn đã nhập sai PIN 5 lần. Tài khoản tạm khóa nhập PIN trong 5 phút."),
                      backgroundColor: Colors.red[400],
                    ),
                  );
                }
              } else if (enteredPin != null && _currentSecurityPin != null && enteredPin == _currentSecurityPin) {
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
              }
            }
          }
        },
        activeColor: switchActiveColor,
        activeTrackColor: switchActiveTrackColor,
        inactiveThumbColor: switchInactiveThumbColor,
        inactiveTrackColor: switchInactiveTrackColor,
        trackOutlineColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (!isDarkMode && !states.contains(MaterialState.selected)) {
            return Colors.grey[700]; // Dark grey border for the track in light mode
          }
          return null; // Default behavior for other states
        }),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildActionButton({
    required BuildContext context, // Add context
    required String title,
    required IconData icon,
    VoidCallback? onTap,
    bool isLinkStyle = false,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final iconColor = isLinkStyle 
        ? (isDarkMode ? Colors.blue[300] : Colors.blue[700]) 
        : (isDarkMode ? Colors.grey[400] : Colors.grey[700]);
    final textColor = isLinkStyle 
        ? (isDarkMode ? Colors.blue[300] : Colors.blue[700]) 
        : (isDarkMode ? Colors.grey[200] : Colors.black87);
    final trailingIconColor = isDarkMode ? Colors.grey[600] : Colors.grey[500];

    return ListTile(
      leading:
          Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.normal,
          fontSize: 15,
        ),
      ),
      trailing: isLinkStyle
          ? null
          : Icon(Icons.arrow_forward_ios, size: 16, color: trailingIconColor),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
