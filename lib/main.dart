// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 
import 'package:gmail/screens/login.dart'; // THAY 'gmail' BẰNG TÊN PACKAGE CỦA BẠN
import 'package:gmail/screens/gmail_ui.dart'; // THAY 'gmail' BẰNG TÊN PACKAGE CỦA BẠN

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, defaultTargetPlatform; // Thêm kDebugMode, defaultTargetPlatform
// import 'dart:io' show Platform; // Không cần nếu dùng defaultTargetPlatform

import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );  
  
  if (kIsWeb) {
    try {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaEnterpriseProvider('6Ld7Y1ArAAAAAM_qsLQA3TAdaOXVZ140wHsxbSXR'), // SITE KEY WEB CỦA BẠN
      );
      print('Firebase App Check activated successfully for Web with ReCaptchaEnterpriseProvider.');
    } catch (e) {
      print('Error activating Firebase App Check for Web: $e');
    }
  } 
  // THÊM KHỐI NÀY CHO ANDROID APP CHECK
  else if (defaultTargetPlatform == TargetPlatform.android) { 
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      );
      print('Firebase App Check activated for Android.');

      if (kDebugMode) { 
        // Chờ một chút để đảm bảo App Check đã sẵn sàng trước khi lấy token
        await Future.delayed(const Duration(seconds: 1)); 
        String? token = await FirebaseAppCheck.instance.getToken(true); // Lấy token (buộc làm mới nếu cần)
        print("--------------------------------------------------------------------");
        print("AppCheck Debug Token (Android): $token");
        print("--------------------------------------------------------------------");
        print("COPY THE ABOVE TOKEN and add it to Firebase Console:");
        print("Firebase Console > App Check > Your Android App (menu 3 chấm) > Manage debug tokens > Add debug token");
        print("--------------------------------------------------------------------");
      }
    } catch (e) {
      print('Error activating Firebase App Check for Android or getting debug token: $e');
    }
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gmail Clone', 
      theme: ThemeData(
        primarySwatch: Colors.red, 
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto', 
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return GmailUI(); 
            // Tạm thời comment out GmailUI nếu chưa sẵn sàng, để test luồng đăng nhập/đăng ký
            //return Scaffold(appBar: AppBar(title: Text("Logged In: ${snapshot.data!.email ?? snapshot.data!.phoneNumber}")), body: Center(child: Text("Welcome!")));
          }
          return const LoginPage();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}