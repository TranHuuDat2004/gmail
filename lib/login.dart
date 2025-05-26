import 'package:flutter/material.dart';
//import 'package:firebase_auth/firebase_auth.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gmail/main.dart'; // Added for direct navigation to GmailUI
import 'register.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController(); // Changed from _emailController
  final TextEditingController _passwordController = TextEditingController();
  String? _error;
  bool _isLoading = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  //final FirebaseAuth _auth = FirebaseAuth.instance;
  //final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    _phoneController.dispose(); // Changed from _emailController
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // For testing: Directly navigate to GmailUI
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => GmailUI()),
    );
    return;

    // Original login logic (commented out for now as per request)
    /*
    if (!mounted) return;
    setState(() {
      _error = null;
      _isLoading = true;
    });

    final String phoneNumber = _phoneController.text.trim(); // Changed from email
    final String password = _passwordController.text.trim();

    if (phoneNumber.isEmpty || password.isEmpty) { // Changed from email
      setState(() {
        _error = 'Số điện thoại và Mật khẩu không được để trống.'; // Changed message
        _isLoading = false;
      });
      return;
    }

    try {
      print('Attempting login for: $phoneNumber'); // Changed from email
      // Note: Firebase phone authentication is more complex than email/password.
      // This simplified version won't work directly with Firebase phone auth.
      // For a real implementation, you'd use _auth.signInWithPhoneNumber or a custom method.
      // For now, we'll assume a placeholder for direct navigation.
      // UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      //   email: phoneNumber, // This would need to be adapted for phone
      //   password: password,
      // );
      // print("Signed in successfully: ${userCredential.user?.uid}");
      // await _processSuccessfulLogin(userCredential.user!);

      // Placeholder for successful "login" for testing
       if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => GmailUI()),
          );
        }

    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() {
          switch (e.code) {
            case 'user-not-found':
              _error = 'Không tìm thấy người dùng với số điện thoại này.'; // Changed message
              break;
            case 'wrong-password':
              _error = 'Sai mật khẩu.';
              break;
            case 'invalid-email': // This case might become irrelevant or change with phone auth
              _error = 'Định dạng số điện thoại không hợp lệ.'; // Changed message
              break;
            case 'invalid-credential':
               _error = 'Thông tin đăng nhập không đúng.'; break;
            default:
              _error = e.message ?? 'Lỗi xác thực không xác định.';
          }
        });
      }
    } catch (e) {
      print('Unexpected error during login: $e');
      if (mounted) {
        setState(() {
          _error = 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
    */
  }

  /*Future<void> _processSuccessfulLogin(User user) async {
    if (!mounted) return;
    print("Login successful for UID: ${user.uid}. Fetching Firestore data (if any)...");
    String displayName = user.displayName ?? "Người dùng";

    try {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists && userDoc.data() != null) {
            final data = userDoc.data() as Map<String, dynamic>;
            displayName = data['name'] ?? user.displayName ?? 'Người dùng';
            final String email = data['email'] ?? user.email ?? 'N/A';
            final String phone = data['phone'] ?? 'N/A';
            print("User data fetched: Name=$displayName, Email=$email, Phone=$phone");
        } else {
            print("User document not found in Firestore for UID: ${user.uid}, but Auth login successful.");
        }

        if (mounted) {
          // AuthGate trong main.dart sẽ xử lý việc hiển thị GmailUI.
          // Chúng ta chỉ cần thông báo cho người dùng ở đây.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đăng nhập thành công! Xin chào ${displayName}.')),
          );
          _phoneController.clear(); // Changed from _emailController
          _passwordController.clear();
          FocusScope.of(context).unfocus();
        }

    } catch(e) {
         print("Error fetching Firestore data post-login: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Đăng nhập thành công Auth! Lỗi tải chi tiết người dùng Firestore.')),
            );
             _phoneController.clear(); // Changed from _emailController
             _passwordController.clear();
             FocusScope.of(context).unfocus();
            // AuthGate vẫn sẽ xử lý chuyển màn hình vì đăng nhập Auth thành công.
          }
    }
  }*/


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              color: Colors.white, // Card đăng nhập cũng có nền trắng
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
                      'Đăng nhập',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A73E8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _phoneController, // Changed from _emailController
                    cursorColor: Colors.grey, // Added cursor color
                    decoration: const InputDecoration(
                        labelText: 'Số điện thoại', // Changed label
                        labelStyle: TextStyle(color: Colors.grey), // Added label style
                        prefixIcon: Icon(Icons.phone_outlined, color: Color(0xFF1A73E8)), // Changed icon
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        ),
                    keyboardType: TextInputType.phone, // Changed keyboard type
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _passwordController,
                    cursorColor: Colors.grey, // Added cursor color
                    decoration: const InputDecoration(
                        labelText: 'Mật khẩu',
                        labelStyle: TextStyle(color: Colors.grey), // Added label style
                        prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF1A73E8)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        ),
                    obscureText: true,
                    enabled: !_isLoading,
                  ),
                  AnimatedOpacity(
                    opacity: _error != null ? 1 : 0,
                    duration: const Duration(milliseconds: 400),
                    child: _error != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 6),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 13.5),
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
                      onPressed: _isLoading ? null : _handleLogin,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(scale: animation, child: child)),
                        child: _isLoading
                            ? const SizedBox(
                                key: ValueKey('loader'),
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Đăng nhập',
                                key: ValueKey('login_text'),
                                style: TextStyle(
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
                      const Text('Chưa có tài khoản?'),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => const RegisterPage()),
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
                        child: const Text('Đăng ký'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
