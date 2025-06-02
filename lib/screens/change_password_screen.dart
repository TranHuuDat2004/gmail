// lib/change_password_screen.dart
import 'package:firebase_auth/firebase_auth.dart'; // THÊM IMPORT
import 'package:flutter/material.dart';
import 'package:gmail/screens/login.dart'; // ĐẢM BẢO IMPORT LOGINPAGE

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String? _onScreenErrorMessage; // THÊM: Biến lưu trữ thông báo lỗi trên màn hình

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitChangePassword() async {
    setState(() {
      _onScreenErrorMessage = null; // Xóa lỗi cũ khi bắt đầu submit
    });

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _onScreenErrorMessage = 'Lỗi: Người dùng không được xác định.';
            _isLoading = false;
          });
        }
        return;
      }

      final String? email = user.email;
      if (email == null) {
        if (mounted) {
          setState(() {
            _onScreenErrorMessage = 'Lỗi: Không tìm thấy email người dùng.';
            _isLoading = false;
          });
        }
        return;
      }

      bool passwordChangeAndSignOutSucceeded = false; // MODIFIED: Flag to track core success

      try {
        // Bước 1: Xác thực lại người dùng với mật khẩu hiện tại
        AuthCredential credential = EmailAuthProvider.credential(
          email: email,
          password: _currentPasswordController.text,
        );
        // Thêm try-catch riêng cho reauthenticate để bắt lỗi sai mật khẩu hiện tại
        try {
          await user.reauthenticateWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'wrong-password' || e.code == 'invalid-credential') { // MODIFIED: Added 'invalid-credential'
            if (mounted) {
              setState(() {
                _onScreenErrorMessage = 'Mật khẩu hiện tại không đúng.';
                _isLoading = false;
              });
            }
            return; // Dừng thực thi nếu mật khẩu hiện tại sai
          }
          // Nếu là lỗi khác trong quá trình reauthenticate, throw lại để khối catch bên ngoài xử lý
          rethrow;
        }

        // KIỂM TRA NẾU MẬT KHẨU MỚI TRÙNG MẬT KHẨU CŨ
        if (_currentPasswordController.text == _newPasswordController.text) {
          if (mounted) {
            setState(() {
              _onScreenErrorMessage = 'Mật khẩu mới không được trùng với mật khẩu hiện tại.';
              _isLoading = false;
            });
          }
          return;
        }

        await user.updatePassword(_newPasswordController.text);

        // Capture Navigator and ScaffoldMessenger state before the sign-out
        // final NavigatorState navigator = Navigator.of(context); // Không cần navigator trực tiếp ở đây nữa
        // final ScaffoldMessengerState scaffoldMessenger = ScaffoldMessenger.of(context); // Không cần scaffoldMessenger trực tiếp ở đây nữa

        await FirebaseAuth.instance.signOut();
        passwordChangeAndSignOutSucceeded = true; // MODIFIED: Core operations succeeded

        // Use captured instances. These actions should proceed.
        // scaffoldMessenger.showSnackBar(
        //   const SnackBar(
        //     content: Text('Mật khẩu đã được thay đổi thành công! Vui lòng đăng nhập lại.'),
        //     backgroundColor: Colors.green, // MODIFIED: Green background for success
        //   ),
        // );
        // navigator.pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);

        // THAY THẾ SnackBar bằng AlertDialog
        if (mounted) { // Kiểm tra mounted trước khi sử dụng context
          showDialog(
            context: context,
            barrierDismissible: false, // Người dùng không thể tắt bằng cách chạm bên ngoài
            builder: (BuildContext dialogContext) {
              // Determine dialog colors based on the dialogContext's theme
              final bool isDialogDarkMode = Theme.of(dialogContext).brightness == Brightness.dark;
              final effectiveDialogBackgroundColor = isDialogDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
              final effectiveDialogSuccessIconColor = isDialogDarkMode ? Colors.green[300]! : Colors.green;
              final effectiveDialogSuccessTitleColor = isDialogDarkMode ? Colors.green[300]! : Colors.green;
              final effectiveDialogContentColor = isDialogDarkMode ? Colors.grey[300]! : Colors.black54;
              final effectiveDialogButtonBackgroundColor = isDialogDarkMode ? Colors.blue[600]! : Colors.blue[700]!
;
              final effectiveDialogButtonForegroundColor = Colors.white;

              return AlertDialog(
                backgroundColor: effectiveDialogBackgroundColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                icon: Icon(Icons.check_circle_outline, color: effectiveDialogSuccessIconColor, size: 50),
                title: Text(
                  'Thành công',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: effectiveDialogSuccessTitleColor, fontWeight: FontWeight.bold, fontSize: 22),
                ),
                content: Text(
                  'Mật khẩu của bạn đã được thay đổi thành công. Vui lòng đăng nhập lại.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: effectiveDialogContentColor),
                ),
                actionsAlignment: MainAxisAlignment.center, // Căn giữa nút OK
                actions: <Widget>[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: effectiveDialogButtonBackgroundColor,
                      foregroundColor: effectiveDialogButtonForegroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    child: const Text('OK', style: TextStyle(fontSize: 18)), // Chữ OK to hơn
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // Đóng AlertDialog
                      // Điều hướng về trang login sau khi người dùng nhấn OK
                      // Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false); // Bỏ dòng này
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginPage()), 
                        (Route<dynamic> route) => false
                      );
                    },
                  ),
                ],
              );
            },
          );
        }

      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Đã xảy ra lỗi. Vui lòng thử lại.';
        // Bỏ trường hợp 'wrong-password' ở đây vì đã xử lý ở trên
        if (e.code == 'weak-password') {
          errorMessage = 'Mật khẩu mới quá yếu.';
        } else if (e.code == 'user-mismatch') {
          errorMessage = 'Thông tin xác thực không khớp với người dùng hiện tại.';
        } else if (e.code == 'requires-recent-login') {
          errorMessage = 'Thao tác này yêu cầu đăng nhập gần đây. Vui lòng đăng xuất và đăng nhập lại.';
        }
        if (mounted) {
          setState(() {
            _onScreenErrorMessage = errorMessage;
          });
        }
      } catch (e) {
        // MODIFIED: Only show generic error if core password change/sign out failed
        if (mounted && !passwordChangeAndSignOutSucceeded) {
          setState(() {
            _onScreenErrorMessage = 'Đã xảy ra lỗi không xác định. Vui lòng thử lại.';
          });
        } else if (passwordChangeAndSignOutSucceeded) {
          // Core ops succeeded, but a UI operation (SnackBar/Navigate) likely failed.
          // Log this error, but don't show the generic "unknown error" to the user.
          // print("Error during post-signout UI update: $e");
        }
      } finally {
        if (mounted) { // MODIFIED: Added mounted check
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Define colors based on theme
    final scaffoldBackgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final appBarBackgroundColor = isDarkMode ? const Color(0xFF202124) : Colors.white;
    final appBarTextColor = isDarkMode ? Colors.grey[300] : Colors.black87;
    final appBarIconColor = isDarkMode ? Colors.grey[400] : Colors.black54;
    final textFieldLabelColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];
    final textFieldInputColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final textFieldBorderColor = isDarkMode ? Colors.grey[600]! : Colors.grey[400]!;
    final textFieldFocusedBorderColor = isDarkMode ? theme.colorScheme.primary : Colors.blue[700]!;
    final textFieldFloatingLabelColor = isDarkMode ? theme.colorScheme.primary : Colors.blue[700];
    final textFieldIconColor = isDarkMode ? Colors.grey[500] : Colors.grey[600];
    final errorMessageColor = isDarkMode ? Colors.red[300]! : Colors.red[700]!;
    final buttonBackgroundColor = isDarkMode ? Colors.blue[600] : Colors.blue[700];
    final buttonForegroundColor = Colors.white;
    final loadingIndicatorColor = Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor, 
      appBar: AppBar(
        title: Text('Đổi mật khẩu', style: TextStyle(color: appBarTextColor)),
        backgroundColor: appBarBackgroundColor,
        foregroundColor: appBarTextColor, 
        elevation: isDarkMode ? 0 : 1,
        iconTheme: IconThemeData(color: appBarIconColor), 
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _currentPasswordController,
                obscureText: !_isCurrentPasswordVisible,
                style: TextStyle(color: textFieldInputColor), 
                decoration: InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                  labelStyle: TextStyle(color: textFieldLabelColor), 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: textFieldBorderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: textFieldBorderColor)), // Explicitly set for enabled state
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: textFieldFocusedBorderColor, width: 2.0),
                  ),
                  floatingLabelStyle: TextStyle(color: textFieldFloatingLabelColor), 
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isCurrentPasswordVisible ? Icons.visibility_off : Icons.visibility,
                      color: textFieldIconColor, 
                    ),
                    onPressed: () {
                      setState(() {
                        _isCurrentPasswordVisible = !_isCurrentPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mật khẩu hiện tại';
                  }
                  // Thêm logic kiểm tra độ dài hoặc ký tự đặc biệt nếu cần
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _newPasswordController,
                obscureText: !_isNewPasswordVisible,
                style: TextStyle(color: textFieldInputColor), 
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới',
                  labelStyle: TextStyle(color: textFieldLabelColor), 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: textFieldBorderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: textFieldBorderColor)), // Explicitly set for enabled state
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: textFieldFocusedBorderColor, width: 2.0),
                  ),
                  floatingLabelStyle: TextStyle(color: textFieldFloatingLabelColor), 
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isNewPasswordVisible ? Icons.visibility_off : Icons.visibility,
                      color: textFieldIconColor, 
                    ),
                    onPressed: () {
                      setState(() {
                        _isNewPasswordVisible = !_isNewPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mật khẩu mới';
                  }
                  if (value.length < 6) {
                    return 'Mật khẩu mới phải có ít nhất 6 ký tự';
                  }
                  // Thêm logic kiểm tra độ mạnh mật khẩu nếu cần
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                style: TextStyle(color: textFieldInputColor), 
                decoration: InputDecoration(
                  labelText: 'Xác nhận mật khẩu mới',
                  labelStyle: TextStyle(color: textFieldLabelColor), 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: textFieldBorderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: textFieldBorderColor)), // Explicitly set for enabled state
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: textFieldFocusedBorderColor, width: 2.0),
                  ),
                  floatingLabelStyle: TextStyle(color: textFieldFloatingLabelColor), 
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                      color: textFieldIconColor, 
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng xác nhận mật khẩu mới';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Mật khẩu xác nhận không khớp';
                  }
                  return null;
                },
              ),
              // THÊM: Hiển thị thông báo lỗi trên màn hình
              if (_onScreenErrorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 15.0, bottom: 10.0),
                  child: Text(
                    _onScreenErrorMessage!,
                    style: TextStyle(color: errorMessageColor, fontSize: 14), 
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitChangePassword, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonBackgroundColor, 
                  foregroundColor: buttonForegroundColor, 
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: loadingIndicatorColor) 
                      )
                    : const Text('ĐỔI MẬT KHẨU', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}