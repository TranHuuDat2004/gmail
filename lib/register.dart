import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _error;
  bool _isLoading = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!mounted) return;
    setState(() {
      _error = null;
      _isLoading = true;
    });

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String name = _nameController.text.trim();
    final String phone = _phoneController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty || phone.isEmpty) {
      setState(() {
        _error = 'Vui lòng điền đầy đủ thông tin.';
        _isLoading = false;
      });
      return;
    }

    try {
      print('BẮT ĐẦU QUÁ TRÌNH ĐĂNG KÝ CHO: $email');
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? newUser = userCredential.user;
      print("Đăng ký Auth thành công! User ID: ${newUser?.uid}");

      if (newUser != null) {
        print("CHUẨN BỊ LƯU DỮ LIỆU VÀO FIRESTORE CHO UID: ${newUser.uid}");
        try {
          await _firestore.collection('users').doc(newUser.uid).set({
            'name': name,
            'email': email,
            'phone': phone,
            'createdAt': FieldValue.serverTimestamp(),
          });
          print("LƯU FIRESTORE THÀNH CÔNG!");
        } catch (firestoreError) {
          print("!!! LỖI KHI LƯU VÀO FIRESTORE: $firestoreError");
          // Ngay cả khi lỗi Firestore, tài khoản Auth đã được tạo.
          // Cân nhắc việc xóa tài khoản Auth nếu lưu Firestore là bắt buộc.
          // Hoặc thông báo cho người dùng và cho phép họ thử lại sau.
          if (mounted) {
            setState(() {
              _error = "Đăng ký thành công nhưng có lỗi lưu thông tin chi tiết.";
              // Không dừng _isLoading ở đây để finally xử lý
            });
            // Không return, để finally chạy
          }
        }

        try {
          await newUser.updateDisplayName(name);
          print("Updated Auth display name.");
        } catch (profileError) {
          print("Error updating Auth display name: $profileError");
        }

        if (mounted && _error == null) { // Chỉ điều hướng nếu không có lỗi lưu Firestore
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đăng ký thành công! Chào mừng $name. Vui lòng đăng nhập.')),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      } else {
        print("!!! LỖI: User mới tạo là null sau khi createUserWithEmailAndPassword");
        if (mounted) {
          setState(() {
            _error = "Lỗi tạo tài khoản, không nhận được thông tin người dùng.";
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() {
          switch (e.code) {
            case 'invalid-email':
              _error = 'Định dạng email không hợp lệ.';
              break;
            case 'email-already-in-use':
              _error = 'Email này đã được sử dụng.';
              break;
            case 'weak-password':
              _error = 'Mật khẩu quá yếu.';
              break;
            default:
              _error = e.message ?? 'Lỗi đăng ký không xác định.';
          }
        });
      }
    } catch (e) {
      print('Unexpected error during registration: $e');
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
  }

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
                    cursorColor: Colors.grey, // Added cursor color
                    decoration: const InputDecoration(
                        labelText: 'Họ tên',
                        labelStyle: TextStyle(color: Colors.grey), // Added label style
                        prefixIcon: Icon(Icons.person_outline, color: Color(0xFF1A73E8)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        ),
                    textCapitalization: TextCapitalization.words,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _phoneController,
                    cursorColor: Colors.grey, // Added cursor color
                    decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        labelStyle: TextStyle(color: Colors.grey), // Added label style
                        prefixIcon: Icon(Icons.phone_outlined, color: Color(0xFF1A73E8)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        ),
                    keyboardType: TextInputType.phone,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _emailController,
                    cursorColor: Colors.grey, // Added cursor color
                    decoration: const InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Colors.grey), // Added label style
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
                      onPressed: _isLoading ? null : _handleRegister,
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
                            : const Text(
                                'Đăng ký',
                                key: ValueKey('register_text'),
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
                    'Firebase Demo - Register',
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