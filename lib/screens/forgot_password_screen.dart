import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'login.dart'; 

enum ForgotPasswordStep {
  enterEmail,
  enterOtp,
  enterNewPassword,
  success,
  error
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKeyEmail = GlobalKey<FormState>();
  final _formKeyOtp = GlobalKey<FormState>();
  final _formKeyNewPassword = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _message; // General message for errors or success

  ForgotPasswordStep _currentStep = ForgotPasswordStep.enterEmail;
  String? _verificationId;
  String _fullPhoneNumber = ''; // To store the phone number fetched from Firestore
  String _uidToUpdate = ''; // To store the UID of the user whose password will be updated

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Helper to format phone number
  String _formatPhoneNumberForFirebase(String localPhoneNumber) {
    String cleaned = localPhoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    if (!cleaned.startsWith('+')) {
      return '+84$cleaned';
    }
    return cleaned;
  }


  Future<void> _submitEmailAndSendOtp() async {
    if (!_formKeyEmail.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _message = null;
    });

    final String email = _emailController.text.trim();

    try {
      // 1. Check if email exists in Firestore and get phone number & UID
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _message = 'Email không tồn tại trong hệ thống.';
          _currentStep = ForgotPasswordStep.error;
          _isLoading = false;
        });
        return;
      }

      final userData = querySnapshot.docs.first.data();
      _fullPhoneNumber = userData['phone'] as String? ?? '';
      _uidToUpdate = querySnapshot.docs.first.id; 


      if (_fullPhoneNumber.isEmpty) {
        setState(() {
          _message = 'Không tìm thấy số điện thoại liên kết với email này.';
          _currentStep = ForgotPasswordStep.error;
          _isLoading = false;
        });
        return;
      }
      
      final String firebaseFormattedPhone = _formatPhoneNumberForFirebase(_fullPhoneNumber);

      // 2. Send OTP
      await _auth.verifyPhoneNumber(
        phoneNumber: firebaseFormattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          setState(() { _isLoading = true; });
          try {
            await _auth.signInWithCredential(credential);
            if (_auth.currentUser != null && _auth.currentUser!.uid == _uidToUpdate) {
                 setState(() {
                    _currentStep = ForgotPasswordStep.enterNewPassword;
                    _message = 'Xác minh OTP thành công (tự động). Vui lòng nhập mật khẩu mới.';
                 });
            } else {
                await _auth.signOut();
                setState(() {
                    _message = 'Lỗi liên kết tài khoản. Vui lòng thử lại hoặc liên hệ hỗ trợ.';
                    _currentStep = ForgotPasswordStep.error;
                });
            }
          } catch (e) {
             setState(() {
                _message = 'Lỗi xác minh OTP tự động: ${e.toString()}';
                _currentStep = ForgotPasswordStep.error;
             });
          } finally {
            setState(() { _isLoading = false; });
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _message = 'Gửi OTP thất bại: ${e.message}';
            _currentStep = ForgotPasswordStep.error;
            _isLoading = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _currentStep = ForgotPasswordStep.enterOtp;
            _message = 'Mã OTP đã được gửi đến số điện thoại liên kết với email của bạn.';
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() {
        _message = 'Đã xảy ra lỗi: ${e.toString()}';
        _currentStep = ForgotPasswordStep.error;
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyOtpAndPreparePasswordUpdate() async {
    if (!_formKeyOtp.currentState!.validate() || _verificationId == null) {
      return;
    }
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null && userCredential.user!.uid == _uidToUpdate) {
        setState(() {
          _currentStep = ForgotPasswordStep.enterNewPassword;
          _message = 'Xác minh OTP thành công. Vui lòng nhập mật khẩu mới.'; 
          _isLoading = false;
        });
      } else {
        await _auth.signOut();
        setState(() {
          _message = 'Lỗi xác thực người dùng. Không thể cập nhật mật khẩu. Vui lòng thử lại hoặc liên hệ hỗ trợ.';
          _currentStep = ForgotPasswordStep.error;
          _isLoading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Xác minh OTP thất bại.';
      if (e.code == 'invalid-verification-code') {
        errorMessage = 'Mã OTP không hợp lệ.';
      } else if (e.code == 'session-expired') {
        errorMessage = 'Mã OTP đã hết hạn. Vui lòng thử gửi lại.';
      }
      setState(() {
        _message = errorMessage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _message = 'Lỗi xác minh OTP: ${e.toString()}';
        _currentStep = ForgotPasswordStep.error;
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePassword() async {
    if (!_formKeyNewPassword.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _message = null;
    });

    final String newPassword = _newPasswordController.text;
    final User? currentUser = _auth.currentUser;

    if (currentUser == null || currentUser.uid != _uidToUpdate) {
      setState(() {
        _message = 'Lỗi: Không tìm thấy người dùng hợp lệ để cập nhật mật khẩu. Vui lòng bắt đầu lại.';
        _currentStep = ForgotPasswordStep.error; // Or back to enterEmail
        _isLoading = false;
      });
      if (currentUser != null) await _auth.signOut();
      return;
    }

    try {
      await currentUser.updatePassword(newPassword);
      setState(() {
        _currentStep = ForgotPasswordStep.success;
        _message = 'Mật khẩu của bạn đã được cập nhật thành công!';
        _isLoading = false;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
          );
        }
      });

    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Cập nhật mật khẩu thất bại.';
      if (e.code == 'weak-password') {
        errorMessage = 'Mật khẩu mới quá yếu.';
      } else if (e.code == 'requires-recent-login') {
        errorMessage = 'Thao tác này yêu cầu đăng nhập gần đây. Vui lòng thử lại từ đầu.';
        await _auth.signOut();
        _currentStep = ForgotPasswordStep.enterEmail; // Force restart
      }
      setState(() {
        _message = errorMessage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _message = 'Lỗi cập nhật mật khẩu: ${e.toString()}';
        _currentStep = ForgotPasswordStep.error;
        _isLoading = false;
      });
    }
  }

  void _resetProcess() {
    setState(() {
      _currentStep = ForgotPasswordStep.enterEmail;
      _emailController.clear();
      _otpController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _message = null;
      _isLoading = false;
      _verificationId = null;
      _fullPhoneNumber = '';
      _uidToUpdate = '';
    });
  }

  // --- UI Building Methods ---

  Widget _buildEnterEmailStep(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKeyEmail,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Đặt lại mật khẩu',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A73E8)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nhập email đã đăng ký. Chúng tôi sẽ gửi mã OTP đến số điện thoại liên kết để xác minh.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _emailController,
            cursorColor: Colors.grey[700],
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: TextStyle(color: Colors.grey[700]),
              prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[700]),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập email của bạn';
              }
              if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@mail\.com$").hasMatch(value)) {
                return 'Vui lòng nhập địa chỉ email @mail.com hợp lệ';
              }
              return null;
            },
            enabled: !_isLoading,
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _isLoading ? null : _submitEmailAndSendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.0),
              ),
              elevation: _isLoading ? 2 : 6,
              shadowColor: const Color(0x331A73E8),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text(
                    'GỬI OTP',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterOtpStep(BuildContext context) {
    final theme = Theme.of(context);
    // Define the specific messages that should be green
    const String otpSentSuccessMessage = 'Mã OTP đã được gửi đến số điện thoại liên kết với email của bạn.';
    const String defaultOtpPrompt = 'Mã OTP đã được gửi đến số điện thoại của bạn. Vui lòng nhập vào bên dưới.';

    final String displayedText = _message ?? defaultOtpPrompt;
    Color textColor;

    if (displayedText == otpSentSuccessMessage || displayedText == defaultOtpPrompt) {
      if (_message != null && (_currentStep == ForgotPasswordStep.error || _message!.toLowerCase().contains('lỗi') || _message!.toLowerCase().contains('thất bại'))) {
        textColor = Colors.redAccent;
      } else {
        textColor = Colors.green; 
      }
    } else if (_message != null && (_currentStep == ForgotPasswordStep.error || _message!.toLowerCase().contains('lỗi') || _message!.toLowerCase().contains('thất bại'))) {
      textColor = Colors.redAccent;
    } else {
      textColor = Colors.black54;
    }

    return Form(
      key: _formKeyOtp,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Nhập mã OTP',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A73E8)),
          ),
          const SizedBox(height: 12),
          Text(
            displayedText,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: textColor),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _otpController,
            cursorColor: Colors.grey[700],
            decoration: InputDecoration(
              labelText: 'Mã OTP',
              labelStyle: TextStyle(color: Colors.grey[700]),
              prefixIcon: Icon(Icons.password_outlined, color: Colors.grey[700]),
               enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập mã OTP';
              }
              if (value.length != 6) { // Standard OTP length
                return 'Mã OTP phải có 6 chữ số';
              }
              return null;
            },
            enabled: !_isLoading,
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtpAndPreparePasswordUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.0),
              ),
               elevation: _isLoading ? 2 : 6,
              shadowColor: const Color(0x331A73E8),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text(
                    'XÁC MINH OTP',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
          ),
           const SizedBox(height: 16),
            TextButton(
              onPressed: _isLoading ? null : _resetProcess, // Go back to email input
              child: const Text('Nhập lại Email?', style: TextStyle(color: Color(0xFF1A73E8))),
            ),
        ],
      ),
    );
  }

  Widget _buildEnterNewPasswordStep(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKeyNewPassword,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Tạo mật khẩu mới',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A73E8)),
          ),
          const SizedBox(height: 12),
           Text(
            _message ?? 'Vui lòng nhập mật khẩu mới cho tài khoản của bạn.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, 
              color: (_message == 'Xác minh OTP thành công. Vui lòng nhập mật khẩu mới.') 
                     ? Colors.green 
                     : (_message != null && _currentStep == ForgotPasswordStep.error ? Colors.redAccent : Colors.black54)
            ),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _newPasswordController,
            cursorColor: Colors.grey[700],
            decoration: InputDecoration(
              labelText: 'Mật khẩu mới',
              labelStyle: TextStyle(color: Colors.grey[700]),
              prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[700]),
               enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập mật khẩu mới';
              }
              if (value.length < 6) {
                return 'Mật khẩu phải có ít nhất 6 ký tự';
              }
              return null;
            },
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            cursorColor: Colors.grey[700],
            decoration: InputDecoration(
              labelText: 'Xác nhận mật khẩu mới',
              labelStyle: TextStyle(color: Colors.grey[700]),
              prefixIcon: Icon(Icons.lock_reset_outlined, color: Colors.grey[700]),
               enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng xác nhận mật khẩu mới';
              }
              if (value != _newPasswordController.text) {
                return 'Mật khẩu xác nhận không khớp';
              }
              return null;
            },
            enabled: !_isLoading,
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _isLoading ? null : _updatePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.0),
              ),
               elevation: _isLoading ? 2 : 6,
              shadowColor: const Color(0x331A73E8),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text(
                    'CẬP NHẬT MẬT KHẨU',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStep(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
        const SizedBox(height: 24),
        Text(
          'Thành công!',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green),
        ),
        const SizedBox(height: 12),
        Text(
          _message ?? 'Mật khẩu của bạn đã được cập nhật.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (Route<dynamic> route) => false,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A73E8),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.0),
            ),
          ),
          child: const Text(
            'ĐĂNG NHẬP NGAY',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorStep(BuildContext context) {
     final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 80),
        const SizedBox(height: 24),
        Text(
          'Đã xảy ra lỗi',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.redAccent),
        ),
        const SizedBox(height: 12),
        Text(
          _message ?? 'Một lỗi không mong muốn đã xảy ra. Vui lòng thử lại.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: _resetProcess, // Reset the flow to start over
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A73E8),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.0),
            ),
          ),
          child: const Text(
            'THỬ LẠI',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    Widget currentStepWidget;
    switch (_currentStep) {
      case ForgotPasswordStep.enterEmail:
        currentStepWidget = _buildEnterEmailStep(context);
        break;
      case ForgotPasswordStep.enterOtp:
        currentStepWidget = _buildEnterOtpStep(context);
        break;
      case ForgotPasswordStep.enterNewPassword:
        currentStepWidget = _buildEnterNewPasswordStep(context);
        break;
      case ForgotPasswordStep.success:
        currentStepWidget = _buildSuccessStep(context);
        break;
      case ForgotPasswordStep.error:
        currentStepWidget = _buildErrorStep(context);
        break;
    }

    Widget globalMessageWidget = const SizedBox.shrink();
    if (_message != null && 
        _currentStep != ForgotPasswordStep.enterOtp && 
        _currentStep != ForgotPasswordStep.enterNewPassword && 
        _currentStep != ForgotPasswordStep.success && 
        _currentStep != ForgotPasswordStep.error) { 
      globalMessageWidget = Padding(
        padding: const EdgeInsets.only(top: 20.0),
        child: Text(
          _message!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: (_currentStep == ForgotPasswordStep.error || (_message?.toLowerCase().contains('lỗi') ?? false) || (_message?.toLowerCase().contains('thất bại') ?? false) )
                   ? Colors.redAccent
                   : Colors.green,
            fontSize: 14,
          ),
        ),
      );
    }


    return WillPopScope(
      onWillPop: () async {
        if (_currentStep == ForgotPasswordStep.enterOtp || _currentStep == ForgotPasswordStep.enterNewPassword) {
          if (_auth.currentUser != null) {
            await _auth.signOut();
          }
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (Route<dynamic> route) => false,
            );
          }
          return false; // Prevent default pop
        }
        return true; 
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Quên mật khẩu'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async { // Made async
              if (_currentStep == ForgotPasswordStep.enterOtp || _currentStep == ForgotPasswordStep.enterNewPassword) {
                if (_auth.currentUser != null) {
                  await _auth.signOut();
                }
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (Route<dynamic> route) => false,
                  );
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: currentStepWidget,
                  ),
                  globalMessageWidget, 
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
