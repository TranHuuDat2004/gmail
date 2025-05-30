// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Đảm bảo file này đã được cập nhật sau khi chạy flutterfire configure với project Firebase MỚI
import 'package:gmail/screens/login.dart'; // THAY 'gmail' bằng tên package thực tế của bạn nếu cần
// Ví dụ: import 'package:your_project_name/screens/login.dart';
// Hoặc: import 'auth_gate.dart'; // Nếu bạn dùng AuthGate để điều hướng ban đầu
import 'package:gmail/screens/gmail_ui.dart'; // Thêm import cho GmailUI

// Thêm các import này cho Firebase App Check
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Thêm import cho FirebaseAuth
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );  
  
  if (kIsWeb) {
    // Khối try-catch để bắt lỗi nếu có vấn đề khi kích hoạt App Check
    try {
      // Kích hoạt Firebase App Check cho nền tảng web
      await FirebaseAppCheck.instance.activate(
        // Sử dụng ReCaptchaEnterpriseProvider vì bạn đã tạo Site Key Enterprise
        // và đăng ký nó trong Firebase App Check Console.
        webProvider: ReCaptchaEnterpriseProvider('6Ld7Y1ArAAAAAM_qsLQA3TAdaOXVZ140wHsxbSXR'), // <-- SITE KEY ENTERPRISE CỦA BẠN
      );
      print('Firebase App Check activated successfully with ReCaptchaEnterpriseProvider.');
    } catch (e) {
      // In ra lỗi nếu kích hoạt App Check thất bại
      print('Error activating Firebase App Check: $e');
    }
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gmail Clone', // Thay bằng tên ứng dụng của bạn
      theme: ThemeData(
        primarySwatch: Colors.red, // Hoặc màu chủ đạo của bạn
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto', // Hoặc font chữ bạn muốn sử dụng
      ),
      // Sử dụng StreamBuilder để kiểm tra trạng thái đăng nhập
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Hiển thị màn hình chờ nếu cần
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            // Nếu người dùng đã đăng nhập, hiển thị GmailUI
            return GmailUI(); // Đảm bảo GmailUI được import và không có const nếu nó là StatefulWidget
          }
          // Nếu người dùng chưa đăng nhập, hiển thị LoginPage
          return const LoginPage();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}