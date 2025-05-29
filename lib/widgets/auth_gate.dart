import 'package:flutter/material.dart';
import '../screens/gmail_ui.dart'; // This will be a new file
// import 'login.dart'; // Assuming LoginPage might be used by AuthGate in the future

class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Simplified AuthGate: Directly return GmailUI as Firebase is removed.
    // If LoginPage should be the default, this can be changed.
    return GmailUI();
    // Original Firebase-dependent StreamBuilder removed:
    // return StreamBuilder<User?>(
    //   stream: FirebaseAuth.instance.authStateChanges(),
    //   builder: (context, snapshot) {
    //     if (snapshot.connectionState == ConnectionState.waiting) {
    //       return const Scaffold(
    //         body: Center(child: CircularProgressIndicator()),
    //       );
    //     }
    //     if (snapshot.hasData) {
    //       return GmailUI();
    //     }
    //     return const LoginPage(); // LoginPage would be imported if used
    //   },
    // );
  }
}
