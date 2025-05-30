import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'register.dart'; // Để điều hướng đến trang đăng ký
import 'gmail_ui.dart'; // Thêm import cho GmailUI

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController(); // Renamed from _phoneController
  final TextEditingController _passwordController = TextEditingController();
  String? _error;
  bool _isLoading = false;
  late AnimationController _animationController; // Đổi tên thống nhất
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController( // Đổi tên _controller thành _animationController
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }
  @override
  void dispose() {
    _animationController.dispose(); // Đổi tên _controller thành _animationController
    _emailController.dispose(); // Renamed from _phoneController
    _passwordController.dispose();
    super.dispose();
  }
  Future<void> _handleLogin() async {
    if (!mounted) return;
    setState(() {
      _error = null;
      _isLoading = true;
    });

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Email và Mật khẩu không được để trống.';
        _isLoading = false;
      });
      return;
    }

    try {
      // Thực hiện đăng nhập bằng Firebase Authentication
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Nếu đăng nhập thành công, StreamBuilder trong main.dart sẽ tự động xử lý điều hướng
      // Bạn có thể hiển thị SnackBar nếu muốn, nhưng không cần Navigator.pushReplacement ở đây nữa
      // vì StreamBuilder sẽ làm điều đó.
      if (mounted && userCredential.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng nhập thành công!'), duration: Duration(seconds: 1)), // Giảm thời gian SnackBar một chút
        );
        // Điều hướng ngay lập tức và xóa các trang trước đó khỏi stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => GmailUI()), // Đảm bảo GmailUI không có const nếu là StatefulWidget
          (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Đăng nhập thất bại. Vui lòng thử lại.';
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          errorMessage = 'Email hoặc mật khẩu không đúng.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Địa chỉ email không hợp lệ.';
        } else if (e.code == 'user-disabled') {
          errorMessage = 'Tài khoản này đã bị vô hiệu hóa.';
        }
        // Thêm các mã lỗi khác nếu cần
        setState(() {
          _error = errorMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Đã xảy ra lỗi không mong muốn: ${e.toString()}';
        });
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController, // Sử dụng _animationController
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
                      'Đăng nhập',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A73E8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController, // Ensure this uses the renamed _emailController
                    cursorColor: Colors.grey,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF1A73E8)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
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
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13.5),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: _isLoading ? 2 : 6,
                        shadowColor: const Color(0x331A73E8),
                        disabledBackgroundColor: const Color(0xFF1A73E8).withOpacity(0.6),
                        disabledForegroundColor: Colors.white.withOpacity(0.8),
                      ),
                      onPressed: _isLoading ? null : _handleLogin,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child)),
                        child: _isLoading
                            ? const SizedBox(
                                key: ValueKey('loader_login'),
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text(
                                'Đăng nhập',
                                key: ValueKey('login_text'),
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.8),
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
                        onPressed: _isLoading ? null : () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const RegisterPage()),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1A73E8),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Đăng ký'),
                      ),
                    ],
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
