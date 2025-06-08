import 'package:flutter/material.dart';
import 'login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController(); // Added
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailLocalPartController = TextEditingController();
  final TextEditingController _otpController = TextEditingController(); // Controller for OTP input

  String? _error;
  bool _isLoading = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  String? _verificationId; 
  bool _showOtpInput = false; 
  String _tempName = "";
  String _tempPhone = "";
  String _tempEmail = "";
  String _tempPassword = "";

  void _editInformation() {
    if (!mounted) return;
    setState(() {
      _showOtpInput = false;
      _verificationId = null;
      _otpController.clear();
      _error = null; 
      _isLoading = false; 
    });
  }

  String _formatPhoneNumberForFirebase(String localPhoneNumber) {
    String cleaned = localPhoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    return '+84$cleaned';
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
  }
  @override
  void dispose() {
    _controller.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailLocalPartController.dispose();
    _otpController.dispose(); // Dispose OTP controller
    super.dispose();
  }  Future<void> _finalizeRegistration(
      PhoneAuthCredential credential, // This is the PhoneAuthCredential from OTP
      String name,
      String originalPhone,
      String email,
      String password) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    User? newUser; // Keep track of the newly created user

    try {
      // Step 1: Create the user with email and password
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      newUser = userCredential.user;

      if (newUser != null) {
        // Step 2: Try to link the phone credential
        try {
          await newUser.linkWithCredential(credential);
          await FirebaseFirestore.instance.collection('users').doc(newUser.uid).set({
            'name': name,
            'phone': originalPhone, 
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
            'phoneVerified': true,
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Đăng ký và xác minh SĐT thành công!'),
                  backgroundColor: Colors.green),
            );
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            );
          }
        } on FirebaseAuthException catch (linkException) {
          if (linkException.code == 'credential-already-in-use' ||
              linkException.code == 'account-exists-with-different-credential') {
            await newUser.delete(); // Delete the orphaned email/password account
            if (!mounted) return;
            setState(() {
              _error = 'Số điện thoại này đã được sử dụng bởi một tài khoản khác. Vui lòng sử dụng số điện thoại khác.';
              _isLoading = false;
              _showOtpInput = false; // Hide OTP field, user needs to restart with new phone or login
            });
          } else {
            // Another linking error
            await newUser.delete(); // Also delete for other linking errors to be safe
            if (!mounted) return;
            setState(() {
              _error = 'Liên kết số điện thoại thất bại: ${linkException.message}';
              _isLoading = false;
            });
          }
        }
      } else { // newUser is null after createUserWithEmailAndPassword
          if (!mounted) return;
          setState(() {
              _error = 'Không thể tạo tài khoản người dùng.';
              _isLoading = false;
          });
      }
    } on FirebaseAuthException catch (e) { // Errors from createUserWithEmailAndPassword
      if (!mounted) return;
      String errorMessage = 'Hoàn tất đăng ký thất bại.';
      if (e.code == 'weak-password') {
        errorMessage = 'Mật khẩu quá yếu.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Địa chỉ email này đã được sử dụng.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Địa chỉ email không hợp lệ.';
      }
      else {
        errorMessage = 'Lỗi tạo tài khoản: ${e.message} (code: ${e.code})';
      }
      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (newUser != null) {
        try {
        } catch (deleteError) {
          print("Error deleting user during general catch: $deleteError");
        }
      }
      setState(() {
        _error = 'Đã xảy ra lỗi không mong muốn khi hoàn tất đăng ký: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRegisterOrSendOtp() async {
    if (!mounted) return;
    setState(() {
      _error = null;
      _isLoading = true;
    });

    _tempPassword = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim(); // Added
    _tempName = _nameController.text.trim();
    _tempPhone = _phoneController.text.trim();
    _tempEmail = '${_emailLocalPartController.text.trim()}@mail.com';


    if (_tempPassword.isEmpty || confirmPassword.isEmpty || _tempName.isEmpty || _tempPhone.isEmpty || _emailLocalPartController.text.trim().isEmpty) { // Added confirmPassword check
      setState(() {
        _error = 'Vui lòng điền đầy đủ thông tin.';
        _isLoading = false;
      });
      return;
    }

    if (_tempPassword != confirmPassword) { // Added password match check
      setState(() {
        _error = 'Mật khẩu và xác nhận mật khẩu không khớp.';
        _isLoading = false;
      });
      return;
    }

    if (_emailLocalPartController.text.trim().contains('@')) {
      setState(() {
        _error = 'Phần tên đăng nhập email không được chứa ký tự \'@\' ';
        _isLoading = false;
      });
      return;
    }

    if (!_isValidPhoneNumber(_tempPhone)) {
      setState(() {
        _error = 'Số điện thoại không hợp lệ. Vui lòng nhập đúng định dạng.';
        _isLoading = false;
      });
      return;
    }

    if (_tempPassword.length < 6) {
      setState(() {
        _error = 'Mật khẩu phải có ít nhất 6 ký tự.';
        _isLoading = false;
      });
      return;
    }

    try {
      List<String> signInMethods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(_tempEmail);
      if (signInMethods.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'Địa chỉ email này đã được sử dụng. Vui lòng sử dụng email khác.';
          _isLoading = false;
        });
        return;
      }

      String formattedPhone = _formatPhoneNumberForFirebase(_tempPhone);
      print(">>> Sending OTP to Firebase with phone: $formattedPhone"); // THÊM DÒNG NÀY
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (!mounted) return;
          await _finalizeRegistration(credential, _tempName, _tempPhone, _tempEmail, _tempPassword);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          String phoneError = 'Xác minh SĐT thất bại.';
          if (e.code == 'invalid-phone-number') {
            phoneError = 'Số điện thoại không hợp lệ cho việc gửi OTP.';
          } else {
            phoneError = 'Lỗi gửi OTP: ${e.message} (code: ${e.code})';
          }
          setState(() {
            _error = phoneError;
            _isLoading = false;
            _showOtpInput = false; // Hide OTP field on failure
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _showOtpInput = true; // Show OTP input field
            _isLoading = false; // Stop loading to allow OTP input
            _error = 'Mã OTP đã được gửi. Vui lòng nhập vào bên dưới.'; // This message will be green
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) return;
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thời gian chờ OTP tự động đã hết. Vui lòng thử lại.')),
          );
          setState(() {
            _isLoading = false;
            _showOtpInput = false; // Hide OTP field
             _verificationId = verificationId; // Store it in case user wants to resend from this state
          });
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Lỗi khi bắt đầu xác minh SĐT: ${e.toString()}';
        _isLoading = false;
        _showOtpInput = false;
      });
    }
  }

  Future<void> _verifyOtpAndFinalize() async {
    if (_verificationId == null || _otpController.text.trim().isEmpty) {
      setState(() {
        _error = "Vui lòng nhập mã OTP.";
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      // Pass the temporarily stored user details
      await _finalizeRegistration(credential, _tempName, _tempPhone, _tempEmail, _tempPassword);
    } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        String otpError = "Xác minh OTP thất bại.";
        if (e.code == 'invalid-verification-code') {
            otpError = "Mã OTP không hợp lệ.";
        } else if (e.code == 'session-expired') {
            otpError = "Mã OTP đã hết hạn. Vui lòng gửi lại OTP.";
             _showOtpInput = false; // Hide OTP field as it's expired
        } else {
            otpError = "Lỗi xác minh OTP: ${e.message}";
        }
        setState(() {
            _error = otpError;
            _isLoading = false;
        });
    } 
    catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Lỗi không mong muốn khi xác minh OTP: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  // Phone number validation function
  bool _isValidPhoneNumber(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    RegExp phoneRegex = RegExp(r'^(03|05|07|08|09|02)\d{8}$');
    
    return phoneRegex.hasMatch(cleanPhone);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isOtpSentMessage = _error != null && _error == 'Mã OTP đã được gửi. Vui lòng nhập vào bên dưới.';
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(
            opacity: _fadeAnim.value,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: child,
            ),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      'Đăng ký',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A73E8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    cursorColor: Colors.grey,
                    decoration: const InputDecoration(
                        labelText: 'Họ tên',
                        labelStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.person_outline, color: Color(0xFF1A73E8)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        ),
                    textCapitalization: TextCapitalization.words,
                    enabled: !_isLoading && !_showOtpInput, // Disable if loading or showing OTP
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _phoneController,
                    cursorColor: Colors.grey,
                    decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        labelStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.phone_outlined, color: Color(0xFF1A73E8)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        ),
                    keyboardType: TextInputType.phone,
                    enabled: !_isLoading && !_showOtpInput, // Disable if loading or showing OTP
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailLocalPartController,
                          cursorColor: Colors.grey,
                          decoration: const InputDecoration(
                            labelText: 'Tên đăng nhập Email',
                            hintText: 'tendangnhap',
                            labelStyle: TextStyle(color: Colors.grey),
                            prefixIcon: Icon(Icons.alternate_email, color: Color(0xFF1A73E8)),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                          ),
                          enabled: !_isLoading && !_showOtpInput, // Disable if loading or showing OTP
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, top: 20.0),
                        child: Text(
                          '@mail.com',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _passwordController,
                    cursorColor: Colors.grey,
                    decoration: const InputDecoration(
                        labelText: 'Mật khẩu',
                        labelStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF1A73E8)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        ),
                    obscureText: true,
                    enabled: !_isLoading && !_showOtpInput, // Disable if loading or showing OTP
                  ),
                  const SizedBox(height: 18), // Added
                  TextField( // Added Confirm Password Field
                    controller: _confirmPasswordController,
                    cursorColor: Colors.grey,
                    decoration: const InputDecoration(
                        labelText: 'Xác nhận mật khẩu',
                        labelStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF1A73E8)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        ),
                    obscureText: true,
                    enabled: !_isLoading && !_showOtpInput, // Disable if loading or showing OTP
                  ),

                  // Conditionally show OTP input field
                  if (_showOtpInput) ...[
                    const SizedBox(height: 20),
                    TextField(
                      controller: _otpController,
                      cursorColor: Colors.grey,
                      decoration: InputDecoration(
                        labelText: 'Mã OTP',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.sms_outlined, color: Color(0xFF1A73E8)),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        hintText: 'Nhập mã OTP 6 số',
                        counterText: "", // Hide counter
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6, // OTP is usually 6 digits
                      enabled: !_isLoading, // Enable only if not loading
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _isLoading ? null : _handleRegisterOrSendOtp, // Gọi lại hàm gửi OTP
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF1A73E8),
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Gửi lại OTP'),
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : _editInformation,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[600],
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Chỉnh sửa thông tin'),
                        ),
                      ],
                    ),
                  ],

                  AnimatedOpacity(
                    opacity: _error != null ? 1 : 0,
                    duration: const Duration(milliseconds: 400),
                    child: _error != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 6),
                            child: Text(
                              _error!,
                              style: TextStyle( // Changed color based on message
                                  color: isOtpSentMessage ? Colors.green : Colors.redAccent,
                                  fontSize: 13.5),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : const SizedBox(height: 18),
                  ),
                  const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: _isLoading ? 2 : 6,
                        shadowColor: const Color(0x331A73E8),
                        disabledBackgroundColor:
                            const Color(0xFF1A73E8).withOpacity(0.6),
                        disabledForegroundColor: Colors.white.withOpacity(0.8),
                      ),
                      onPressed: _isLoading ? null : (_showOtpInput ? _verifyOtpAndFinalize : _handleRegisterOrSendOtp),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(scale: animation, child: child)),
                        child: _isLoading
                            ? const SizedBox(
                                key: ValueKey('loader_reg'),
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _showOtpInput ? 'Xác minh OTP & Đăng ký' : 'Gửi OTP & Đăng ký',
                                key: ValueKey(_showOtpInput ? 'verify_otp_text' : 'register_text'),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Đã có tài khoản?'),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => const LoginPage()),
                                );
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1A73E8),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Đăng nhập'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text( 
                    '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFB0B4BA),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}