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
              return AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 50),
                title: const Text(
                  'Thành công',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 22),
                ),
                content: const Text(
                  'Mật khẩu của bạn đã được thay đổi thành công. Vui lòng đăng nhập lại.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54), // MODIFIED: Changed color to dark gray
                ),
                actionsAlignment: MainAxisAlignment.center, // Căn giữa nút OK
                actions: <Widget>[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700], // Nền xanh như login
                      foregroundColor: Colors.white, // Chữ trắng
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
    return Scaffold(
      backgroundColor: Colors.white, // THAY ĐỔI: Nền trắng cho Scaffold
      appBar: AppBar(
        title: const Text('Đổi mật khẩu'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black54), // THAY ĐỔI: Màu icon back
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
                decoration: InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  focusedBorder: OutlineInputBorder(// THÊM: Màu viền khi focus
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: Colors.blue[700]!, width: 2.0),
                  ),
                  floatingLabelStyle: TextStyle(color: Colors.blue[700]), // THÊM: Màu label khi focus
                  suffixIcon: IconButton(
                    icon: Icon(_isCurrentPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
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
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  focusedBorder: OutlineInputBorder(// THÊM: Màu viền khi focus
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: Colors.blue[700]!, width: 2.0),
                  ),
                  floatingLabelStyle: TextStyle(color: Colors.blue[700]), // THÊM: Màu label khi focus
                  suffixIcon: IconButton(
                    icon: Icon(_isNewPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
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
                decoration: InputDecoration(
                  labelText: 'Xác nhận mật khẩu mới',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  focusedBorder: OutlineInputBorder(// THÊM: Màu viền khi focus
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: Colors.blue[700]!, width: 2.0),
                  ),
                  floatingLabelStyle: TextStyle(color: Colors.blue[700]), // THÊM: Màu label khi focus
                  suffixIcon: IconButton(
                    icon: Icon(_isConfirmPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
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
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitChangePassword, // THAY ĐỔI: Vô hiệu hóa nút khi đang loading
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(// THAY ĐỔI: Hiển thị CircularProgressIndicator khi loading
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
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