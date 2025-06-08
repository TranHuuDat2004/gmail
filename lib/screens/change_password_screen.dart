
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:flutter/material.dart';
import 'package:gmail/screens/login.dart'; 

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
  String? _onScreenErrorMessage; 

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitChangePassword() async {
    setState(() {
      _onScreenErrorMessage = null; 
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

      bool passwordChangeAndSignOutSucceeded = false; 

      try {
        AuthCredential credential = EmailAuthProvider.credential(
          email: email,
          password: _currentPasswordController.text,
        );
        try {
          await user.reauthenticateWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'wrong-password' || e.code == 'invalid-credential') { 
            if (mounted) {
              setState(() {
                _onScreenErrorMessage = 'Mật khẩu hiện tại không đúng.';
                _isLoading = false;
              });
            }
            return; 
          }
          rethrow;
        }

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

        await FirebaseAuth.instance.signOut();
        passwordChangeAndSignOutSucceeded = true; 

        if (mounted) { 
          showDialog(
            context: context,
            barrierDismissible: false, 
            builder: (BuildContext dialogContext) {
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
                actionsAlignment: MainAxisAlignment.center, 
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
                    child: const Text('OK', style: TextStyle(fontSize: 18)), 
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); 
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
        if (mounted && !passwordChangeAndSignOutSucceeded) {
          setState(() {
            _onScreenErrorMessage = 'Đã xảy ra lỗi không xác định. Vui lòng thử lại.';
          });
        } else if (passwordChangeAndSignOutSucceeded) {
        }
      } finally {
        if (mounted) { 
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
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: textFieldBorderColor)), 
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
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: textFieldBorderColor)), 
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
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: textFieldBorderColor)), 
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