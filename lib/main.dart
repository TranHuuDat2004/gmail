import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Optional: Define a global light theme
      // theme: ThemeData.light().copyWith(
      //   primaryColor: Colors.blue, // Example primary color for light theme
      //   appBarTheme: const AppBarTheme(
      //     backgroundColor: Colors.white,
      //     elevation: 1,
      //     iconTheme: IconThemeData(color: Colors.black54),
      //     titleTextStyle: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w500),
      //   ),
      //   // Add other global theme properties if needed
      // ),
      home: GmailUI(),
    );
  }
}

class GmailUI extends StatelessWidget {
  final List<Map<String, String>> emails = [
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

  GmailUI({super.key}); // Added super.key

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, // Light theme AppBar background
        elevation: 1.0, // Add a slight shadow for separation
        iconTheme: const IconThemeData(color: Colors.black54), // Darker icon for drawer
        title: Container(
          decoration: BoxDecoration(
            color: Colors.grey[200], // Lighter background for search bar
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const TextField(
            decoration: InputDecoration(
              icon: Icon(Icons.search, color: Colors.black54), // Darker search icon
              hintText: "Search in mail",
              hintStyle: TextStyle(color: Colors.black38), // Darker hint text
              border: InputBorder.none,
            ),
            style: TextStyle(color: Colors.black87), // Darker input text
          ),
        ),
        actions: const [ // Added const
          CircleAvatar(
            backgroundImage: AssetImage("images/nokotan.jpg"), // Assuming this image works on light bg
          ),
          SizedBox(width: 16),
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
              // Fallback in case image fails or for a consistent look
              // backgroundColor: Colors.grey[300],
              // child: Text(email["sender"]![0], style: const TextStyle(color: Colors.black54)),
            ),
            title: Text(email["sender"]!,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.black87)), // Darker text
            subtitle: Text(email["subject"]!,
                style: const TextStyle(color: Colors.black54)), // Darker, less prominent text
            trailing: Text(email["time"]!,
                style: const TextStyle(color: Colors.black54)), // Darker, less prominent text
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.white, // Light background for FAB
        elevation: 2.0, // Add some shadow
        onPressed: () {},
        icon: const Icon(Icons.edit, color: Colors.redAccent), // Keep accent color for icon
        label: const Text("Compose", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)), // Keep accent color for text
      ),
      backgroundColor: Colors.white, // Main background to white
    );
  }
}

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key}); // Added super.key

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white, // Drawer background to white
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.grey[100], // Light header background
            ),
            child: Row(
              children: const [ // Added const
                Icon(Icons.mail, color: Colors.redAccent, size: 32), // Accent color for icon
                SizedBox(width: 10),
                Text("Gmail",
                    style: TextStyle(color: Colors.black87, fontSize: 22)), // Darker text
              ],
            ),
          ),
          _buildDrawerItem(Icons.all_inbox, "All inboxes"),
          _buildDrawerItem(Icons.inbox, "Primary"),
          _buildDrawerItem(Icons.people_outline, "Social"), // Using outline for consistency
          _buildDrawerItem(Icons.local_offer_outlined, "Promotions"), // Using outline
          _buildDrawerItem(Icons.update, "Updates", isSelected: true),
          _buildDrawerItem(Icons.forum_outlined, "Forums"), // Using outline
          _buildDrawerItem(Icons.star_border, "Starred"), // Border version for light theme
          _buildDrawerItem(Icons.schedule_outlined, "Scheduled"), // Using outline
          _buildDrawerItem(Icons.drafts_outlined, "Drafts"), // Using outline
          _buildDrawerItem(Icons.delete_outline, "Trash"), // Using outline
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title,
      {bool isSelected = false}) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.redAccent : Colors.black54), // Accent if selected, else dark grey
      title: Text(title, style: TextStyle(color: isSelected ? Colors.redAccent : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      tileColor: isSelected ? Colors.red[50] : Colors.transparent, // Light accent background if selected
      shape: isSelected ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)) : null,
      contentPadding: isSelected ? const EdgeInsets.symmetric(horizontal: 24.0) : null, // More padding for selected
      onTap: () {
        // Handle navigation
      },
    );
  }
}