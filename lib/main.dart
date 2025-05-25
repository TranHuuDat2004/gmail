// lib/main.dart

import 'package:flutter/material.dart';
import 'profile_screen.dart'; // Import the new profile screen

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GmailUI(),
    );
  }
}

class GmailUI extends StatelessWidget {
  final List<Map<String, String>> emails = [
    // Your email list data... (kept it short for brevity)
    {
      "sender": "Amazon",
      "subject": "Your order has been shipped!",
      "time": "8:30 AM",
      "avatar": "images/amazon.png"
    },
    {
      "sender": "Steam",
      "subject": "New game discounts available",
      "time": "7:45 AM",
      "avatar": "images/steam.png"
    },
    // ... add all your other emails here
    {
      "sender": "Netflix",
      "subject": "New movies you might like",
      "time": "6:15 AM",
      "avatar": "images/netflix.png"
    },
    {
      "sender": "LinkedIn",
      "subject": "Job recommendations for you",
      "time": "5:00 AM",
      "avatar": "images/linkedin.png"
    },
    {
      "sender": "Spotify",
      "subject": "Your weekly playlist is ready",
      "time": "4:20 AM",
      "avatar": "images/spotify.png"
    },
    {
      "sender": "Gamefound",
      "subject": "Update in your backed project",
      "time": "2:41 AM",
      "avatar": "images/gamefound.jpg"
    },
    {
      "sender": "YouTube",
      "subject": "New video from your favorite channel",
      "time": "1:35 AM",
      "avatar": "images/youtube.png"
    },
    {
      "sender": "Trello",
      "subject": "Task reminder: Finish the report",
      "time": "Yesterday",
      "avatar": "images/trello.jpg"
    },
    {
      "sender": "Google",
      "subject": "Security alert: Login from new device",
      "time": "Yesterday",
      "avatar": "images/google.png"
    },
    {
      "sender": "BoardGameGeek",
      "subject": "Top 10 trending board games",
      "time": "2 Mar",
      "avatar": "images/boardgamegeek.png"
    },
    {
      "sender": "PayPal",
      "subject": "You received a payment",
      "time": "1 Mar",
      "avatar": "images/paypal.png"
    },
    {
      "sender": "Discord",
      "subject": "New message in your server",
      "time": "29 Feb",
      "avatar": "images/discord.jpg"
    },
  ];

  GmailUI({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1.0,
        iconTheme: const IconThemeData(color: Colors.black54),
        title: Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const TextField(
            decoration: InputDecoration(
              icon: Icon(Icons.search, color: Colors.black54),
              hintText: "Search in mail",
              hintStyle: TextStyle(color: Colors.black38),
              border: InputBorder.none,
            ),
            style: TextStyle(color: Colors.black87),
          ),
        ),
        actions: [
          GestureDetector(
            // MODIFIED: Wrap CircleAvatar with GestureDetector
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const ProfileScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity:
                          animation, // animation ở đây là Animation<double> từ 0.0 đến 1.0
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 500),
                ),
              );
            },
            child: const CircleAvatar(
              backgroundImage:
                  AssetImage("images/mahiru.png"), // Your Gmail avatar
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      drawer: CustomDrawer(),
      body: ListView.builder(
        itemCount: emails.length,
        itemBuilder: (context, index) {
          final email = emails[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: AssetImage(email["avatar"]!),
            ),
            title: Text(email["sender"]!,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.black87)),
            subtitle: Text(email["subject"]!,
                style: const TextStyle(color: Colors.black54)),
            trailing: Text(email["time"]!,
                style: const TextStyle(color: Colors.black54)),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.white,
        elevation: 2.0,
        onPressed: () {},
        icon: const Icon(Icons.edit, color: Colors.redAccent),
        label: const Text("Compose",
            style: TextStyle(
                color: Colors.redAccent, fontWeight: FontWeight.w500)),
      ),
      backgroundColor: Colors.white,
    );
  }
}

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.grey[100],
            ),
            child: Row(
              children: const [
                Icon(Icons.mail, color: Colors.redAccent, size: 32),
                SizedBox(width: 10),
                Text("Gmail",
                    style: TextStyle(color: Colors.black87, fontSize: 22)),
              ],
            ),
          ),
          _buildDrawerItem(Icons.all_inbox, "All inboxes"),
          _buildDrawerItem(Icons.inbox, "Primary"),
          _buildDrawerItem(Icons.people_outline, "Social"),
          _buildDrawerItem(Icons.local_offer_outlined, "Promotions"),
          _buildDrawerItem(Icons.update, "Updates", isSelected: true),
          _buildDrawerItem(Icons.forum_outlined, "Forums"),
          _buildDrawerItem(Icons.star_border, "Starred"),
          _buildDrawerItem(Icons.schedule_outlined, "Scheduled"),
          _buildDrawerItem(Icons.drafts_outlined, "Drafts"),
          _buildDrawerItem(Icons.delete_outline, "Trash"),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title,
      {bool isSelected = false}) {
    return ListTile(
      leading:
          Icon(icon, color: isSelected ? Colors.redAccent : Colors.black54),
      title: Text(title,
          style: TextStyle(
              color: isSelected ? Colors.redAccent : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      tileColor: isSelected ? Colors.red[50] : Colors.transparent,
      shape: isSelected
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
          : null,
      contentPadding:
          isSelected ? const EdgeInsets.symmetric(horizontal: 24.0) : null,
      onTap: () {
        // Handle drawer item navigation
      },
    );
  }
}
