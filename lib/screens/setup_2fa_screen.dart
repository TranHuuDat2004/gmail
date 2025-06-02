import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pinput/pinput.dart';

// TODO: Cân nhắc sử dụng package như 'pinput' để có giao diện nhập PIN đẹp hơn
// và trực quan hơn cho người dùng, giống như hình ảnh bạn đã cung cấp.

class Setup2FAScreen extends StatefulWidget {
  final String userId;

  const Setup2FAScreen({super.key, required this.userId});

  @override
  State<Setup2FAScreen> createState() => _Setup2FAScreenState();
}

class _Setup2FAScreenState extends State<Setup2FAScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  bool _isLoading = false;
  String? _pinErrorText;
  String? _confirmPinErrorText;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _activatePinSecurity() async {
    final String pin = _pinController.text.trim();
    final String confirmPin = _confirmPinController.text.trim();

    // Reset error messages
    setState(() {
      _pinErrorText = null;
      _confirmPinErrorText = null;
    });

    // Validate PIN
    if (pin.isEmpty || pin.length != 6) {
      setState(() {
        _pinErrorText = "Mã PIN phải gồm 6 chữ số.";
      });
      return;
    }
    // Sửa RegExp: bỏ dấu nháy đơn thừa ở cuối
    if (!RegExp(r'^[0-9]{6}$').hasMatch(pin)) {
      setState(() {
        _pinErrorText = "Mã PIN chỉ được chứa số.";
      });
      return;
    }

    // Validate Confirm PIN
    if (confirmPin.isEmpty || confirmPin.length != 6) {
      setState(() {
        _confirmPinErrorText = "Vui lòng xác nhận mã PIN gồm 6 chữ số.";
      });
      return;
    }
    if (pin != confirmPin) {
      setState(() {
        _confirmPinErrorText = "Mã PIN xác nhận không khớp.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore.collection('users').doc(widget.userId).update({
        'is2FAEnabled': true,
        // Lưu mã PIN người dùng tự đặt.
        // Tên field 'securityPin' được sử dụng để lưu mã PIN do người dùng định nghĩa,
        // thay cho tên cũ 'twoFactorSecret' để rõ ràng hơn.
        'securityPin': pin, 
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Mã PIN bảo mật đã được kích hoạt thành công!"),
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.green[700] : Colors.green, // Themed SnackBar
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // Trả về true để báo thành công
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi khi kích hoạt mã PIN: ${e.toString()}"),
            backgroundColor: Theme.of(context).colorScheme.error, // Themed SnackBar
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
    final primaryTextColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : Colors.black54;
    final labelTextColor = isDarkMode ? Colors.grey[300] : Colors.black87;
    final errorTextColor = isDarkMode ? Colors.red[300]! : theme.colorScheme.error;
    final buttonBackgroundColor = isDarkMode ? Colors.blue[600] : Colors.blue[700];
    final buttonForegroundColor = Colors.white;
    final cancelButtonColor = isDarkMode ? Colors.grey[500] : Colors.grey[700];
    final loadingIndicatorColor = isDarkMode ? Colors.white : buttonBackgroundColor;

    // Pinput themes
    final defaultPinTheme = PinTheme(
      width: 52, // Adjusted for better spacing
      height: 58, // Adjusted for better spacing
      textStyle: TextStyle(
          fontSize: 22, // Larger font
          color: isDarkMode ? Colors.grey[100] : const Color.fromRGBO(30, 60, 87, 1),
          fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        border: Border.all(color: isDarkMode ? Colors.grey[700]! : const Color.fromRGBO(200, 205, 210, 1)), // Adjusted border color
        borderRadius: BorderRadius.circular(12), // More rounded
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: isDarkMode ? Colors.blue[400]! : const Color.fromRGBO(114, 178, 238, 1), width: 2), // Thicker border on focus
      borderRadius: BorderRadius.circular(12),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: isDarkMode ? Colors.grey[700] : const Color.fromRGBO(234, 239, 243, 1),
      ),
    );
    
    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        border: Border.all(color: errorTextColor),
      ),
    );


    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Tạo Mã PIN Bảo Mật",
          style: TextStyle(color: appBarTextColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: appBarBackgroundColor,
        elevation: isDarkMode ? 0 : 1, 
        iconTheme: IconThemeData(color: appBarIconColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              "Tạo một mã PIN gồm 6 chữ số để tăng cường bảo mật cho tài khoản của bạn.",
              style: TextStyle(fontSize: 16, color: secondaryTextColor), // USE secondaryTextColor HERE
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Text(
              "Nhập mã PIN (6 chữ số):", 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: labelTextColor),
            ),
            const SizedBox(height: 12), 
            Pinput(
              length: 6,
              controller: _pinController,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: focusedPinTheme,
              submittedPinTheme: submittedPinTheme,
              errorPinTheme: errorPinTheme, // Apply error theme
              errorTextStyle: TextStyle(color: errorTextColor, fontSize: 12),
              pinAnimationType: PinAnimationType.fade,
              validator: (s) {
                if (s == null || s.isEmpty || s.length != 6) {
                  return "Mã PIN phải gồm 6 chữ số.";
                }
                if (!RegExp(r'^[0-9]{6}$').hasMatch(s)) {
                  return "Mã PIN chỉ được chứa số.";
                }
                return null;
              },
              pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
              showCursor: true,
              obscureText: true, 
              obscuringCharacter: '●', // Changed obscuring character
            ),
            if (_pinErrorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _pinErrorText!,
                  style: TextStyle(color: errorTextColor, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 25),
            Text(
              "Xác nhận mã PIN:", 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: labelTextColor),
            ),
            const SizedBox(height: 12),
            Pinput(
              length: 6,
              controller: _confirmPinController,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: focusedPinTheme,
              submittedPinTheme: submittedPinTheme,
              errorPinTheme: errorPinTheme, // Apply error theme
              errorTextStyle: TextStyle(color: errorTextColor, fontSize: 12),
              pinAnimationType: PinAnimationType.fade,
              validator: (s) {
                if (s == null || s.isEmpty || s.length != 6) {
                  return "Vui lòng xác nhận mã PIN gồm 6 chữ số.";
                }
                if (_pinController.text != s) {
                  return "Mã PIN xác nhận không khớp.";
                }
                return null;
              },
              pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
              showCursor: true,
              obscureText: true, 
              obscuringCharacter: '●', // Changed obscuring character
            ),
            if (_confirmPinErrorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _confirmPinErrorText!,
                  style: TextStyle(color: errorTextColor, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 40),
            _isLoading
                ? Center(child: CircularProgressIndicator(color: loadingIndicatorColor))
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonBackgroundColor,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // More rounded
                      ),
                      foregroundColor: buttonForegroundColor,
                    ),
                    onPressed: _activatePinSecurity,
                    child: const Text("Xác nhận và Kích hoạt"),
                  ),
            const SizedBox(height: 15),
            TextButton(
              child: Text(
                "Hủy bỏ",
                style: TextStyle(color: cancelButtonColor),
              ),
              onPressed: () {
                Navigator.pop(context, false); // Trả về false để báo hủy
              },
            ),
          ],
        ),
      ),
    );
  }
}