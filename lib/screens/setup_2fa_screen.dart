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
          const SnackBar(
              content: Text("Mã PIN bảo mật đã được kích hoạt thành công!")),
        );
        Navigator.pop(context, true); // Trả về true để báo thành công
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi khi kích hoạt mã PIN: ${e.toString()}")),
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
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(
          fontSize: 20, color: Color.fromRGBO(30, 60, 87, 1), fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        border: Border.all(color: const Color.fromRGBO(234, 239, 243, 1)),
        borderRadius: BorderRadius.circular(20),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: const Color.fromRGBO(114, 178, 238, 1)),
      borderRadius: BorderRadius.circular(8),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: const Color.fromRGBO(234, 239, 243, 1),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white, // Nền trắng
      appBar: AppBar(
        title: const Text(
          "Tạo Mã PIN Bảo Mật",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0, // Bỏ shadow
        iconTheme:
            const IconThemeData(color: Colors.black), // Icon back màu đen
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              "Tạo một mã PIN gồm 6 chữ số để tăng cường bảo mật cho tài khoản của bạn.",
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            const Text(
              "Nhập mã PIN (6 chữ số):", // Label for the first Pinput
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8), // Spacing for the first Pinput
            // _buildPinTextField(
            //   controller: _pinController,
            //   labelText: "Nhập mã PIN (6 chữ số)",
            //   errorText: _pinErrorText,
            // ),
            Pinput(
              length: 6, // Ensure 6 input cells are displayed
              controller: _pinController,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: focusedPinTheme,
              submittedPinTheme: submittedPinTheme,
              validator: (s) {
                if (s == null || s.isEmpty || s.length != 6) {
                  return "Mã PIN phải gồm 6 chữ số.";
                }
                if (!RegExp(r'^[0-9]{6}$'
).hasMatch(s)) {
                  return "Mã PIN chỉ được chứa số.";
                }
                return null;
              },
              pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
              showCursor: true,
              onCompleted: (pin) => print(pin),
              obscureText: true, // PIN sẽ được che đi
              obscuringCharacter: '*', // Ký tự che là dấu *
            ),
            if (_pinErrorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _pinErrorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              "Xác nhận mã PIN:", // Label for the second Pinput
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8), // Spacing for the second Pinput
            // _buildPinTextField(
            //   controller: _confirmPinController,
            //   labelText: "Xác nhận mã PIN",
            //   errorText: _confirmPinErrorText,
            // ),
            Pinput(
              length: 6, // Ensure 6 input cells are displayed
              controller: _confirmPinController,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: focusedPinTheme,
              submittedPinTheme: submittedPinTheme,
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
              onCompleted: (pin) => print(pin),
              obscureText: true, // PIN sẽ được che đi
              obscuringCharacter: '*', // Ký tự che là dấu *
            ),
            if (_confirmPinErrorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _confirmPinErrorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 40),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.blue[700], // Nút màu xanh dương
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      foregroundColor: Colors.white, // Chữ màu trắng
                    ),
                    onPressed: _activatePinSecurity,
                    child: const Text("Xác nhận và Kích hoạt"),
                  ),
            const SizedBox(height: 15),
            TextButton(
              child: Text(
                "Hủy bỏ",
                style: TextStyle(color: Colors.grey[700]),
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