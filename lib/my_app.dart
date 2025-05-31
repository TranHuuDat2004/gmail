import 'package:flutter/material.dart';
import 'widgets/auth_gate.dart'; // This will be a new file

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthGate(), // AuthGate will now directly return GmailUI or LoginPage
    );
  }
}
