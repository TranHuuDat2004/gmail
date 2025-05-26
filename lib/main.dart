// lib/main.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:gmail/firebase_options.dart';
import 'profile_screen.dart'; // Import the new profile screen
//import 'advanced_search_dialog.dart';
import 'search_overlay_screen.dart';
import 'login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return GmailUI();
        }
        return const LoginPage();
      },
    );
  }
}

class GmailUI extends StatefulWidget {
  GmailUI({super.key});

  @override
  State<GmailUI> createState() => _GmailUIState();
}

class _GmailUIState extends State<GmailUI> {
  bool showDetail = false;
  String selectedLabel = "Inbox";

  final List<String> userLabels = ["Work", "Family"];

  final List<Map<String, dynamic>> emails = [
    {
      "sender": "Amazon",
      "subject": "Your order has been shipped!",
      "time": "8:30 AM",
      "avatar": "images/amazon.png",
      "preview": "Your package is on the way! Track your shipment here...",
      "hasAttachment": true,
      "label": "Inbox",
      "starred": false,
    },    {
      "sender": "Steam",
      "subject": "New game discounts available",
      "time": "7:45 AM",
      "avatar": "images/steam.png",
      "preview": "Check out the latest deals on your wishlist games!",
      "hasAttachment": false,
      "label": "Promotions",
      "starred": false,
    },
    {
      "sender": "Boss",
      "subject": "Project update",
      "time": "Yesterday",
      "avatar": "images/google.png",
      "preview": "Please send the latest report by EOD.",
      "hasAttachment": true,
      "label": "Work",
      "starred": false,
    },
    // ...other emails...
  ];

  @override
  Widget build(BuildContext context) {
    final filteredEmails = selectedLabel == "All inboxes"
        ? emails
        : emails.where((e) => e["label"] == selectedLabel || (selectedLabel == "Inbox" && (e["label"] == null || e["label"] == "Inbox"))).toList();
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        toolbarHeight: 70,
        title: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 8, left: 12, right: 12), // Thụt lề trái/phải
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black54),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Menu',
                ),
              ),
              Expanded(
                child: TextField(
                  readOnly: true,
                  cursorColor: Colors.black,
                  decoration: const InputDecoration(
                    hintText: "Search in mail",
                    hintStyle: TextStyle(color: Colors.black38),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  style: const TextStyle(color: Colors.black87),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SearchOverlayScreen()),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                  },
                  child: CircleAvatar(
                    backgroundImage: AssetImage("images/mahiru.png"),
                    radius: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      drawer: CustomDrawer(
        selectedLabel: selectedLabel,
        onLabelSelected: (label) {
          setState(() {
            selectedLabel = label;
          });
          Navigator.pop(context);
        },
        userLabels: userLabels,
        emails: emails, // Pass emails list into the drawer
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 8, bottom: 4),
            child: Text(
              selectedLabel,
              style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView.builder(
                itemCount: filteredEmails.length,
                itemBuilder: (context, index) {
                  final email = filteredEmails[index];
                  final bool isUnread = email["unread"] ?? true;
                  return ListTile(
                    leading: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                        );
                      },
                      child: email["avatar"] != null
                          ? CircleAvatar(
                              backgroundColor: Colors.transparent,
                              backgroundImage: AssetImage(email["avatar"]),
                            )
                          : CircleAvatar(
                              backgroundColor: Colors.blue[100],
                              child: Text(
                                (email["sender"] ?? "").isNotEmpty ? email["sender"][0].toUpperCase() : "?",
                                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                              ),
                            ),
                    ),
                    title: Text(
                      email["sender"] ?? '',
                      style: TextStyle(
                        fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email["subject"] ?? '',
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                            color: Colors.black87,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (email["preview"] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              email["preview"],
                              style: const TextStyle(color: Colors.black45, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    trailing: SizedBox(
                      height: 48,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            email["time"] ?? '',
                            style: const TextStyle(color: Colors.black54, fontSize: 13),
                          ),
                          IconButton(
                            icon: Icon(
                              email["starred"] == true ? Icons.star : Icons.star_border,
                              color: email["starred"] == true ? Colors.amber : Colors.grey,
                              size: 22,
                            ),
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            onPressed: () {
                              setState(() {
                                email["starred"] = !(email["starred"] ?? false);
                              });
                            },
                            tooltip: email["starred"] == true ? 'Unstar' : 'Star',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        email["unread"] = false;
                      });
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EmailDetailScreen(email: email)),
                      );
                    },
                    tileColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: const Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.white,
        elevation: 2.0,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ComposeEmailScreen()),
          );
        },
        icon: const Icon(Icons.edit, color: Colors.redAccent),
        label: const Text("Compose", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class CustomDrawer extends StatelessWidget {
  final String selectedLabel;
  final Function(String) onLabelSelected;
  final List<String> userLabels;
  final List<Map<String, dynamic>> emails; // added

  const CustomDrawer({
    super.key,
    required this.selectedLabel,
    required this.onLabelSelected,
    required this.userLabels,
    required this.emails, // added
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FC),
            ),
            child: Row(
              children: const [
                Icon(Icons.mail, color: Colors.redAccent, size: 32),
                SizedBox(width: 10),
                Text("Gmail", style: TextStyle(color: Colors.black87, fontSize: 22)),
              ],
            ),
          ),
          _buildDrawerItem(Icons.all_inbox, "All inboxes", count: emails.length, isSelected: selectedLabel == "All inboxes"),
          _buildDrawerItem(Icons.inbox, "Inbox", count: emails.where((e) => e['label'] == 'Inbox').length, isSelected: selectedLabel == "Inbox"),
          _buildDrawerItem(Icons.star_border, "Starred", count: emails.where((e) => e['starred'] == true).length, isSelected: selectedLabel == "Starred"),
          _buildDrawerItem(Icons.send, "Sent", count: emails.where((e) => e['label'] == 'Sent').length, isSelected: selectedLabel == "Sent"),
          _buildDrawerItem(Icons.drafts_outlined, "Drafts", count: emails.where((e) => e['label'] == 'Drafts').length, isSelected: selectedLabel == "Drafts"),
          _buildDrawerItem(Icons.delete_outline, "Trash", count: emails.where((e) => e['label'] == 'Trash').length, isSelected: selectedLabel == "Trash"),
          _buildDrawerItem(Icons.people_outline, "Social", count: emails.where((e) => e['label'] == 'Social').length, isSelected: selectedLabel == "Social"),
          _buildDrawerItem(Icons.local_offer_outlined, "Promotions", count: emails.where((e) => e['label'] == 'Promotions').length, isSelected: selectedLabel == "Promotions"),
          _buildDrawerItem(Icons.update, "Updates", count: emails.where((e) => e['label'] == 'Forums').length, isSelected: selectedLabel == "Updates"),
          _buildDrawerItem(Icons.forum_outlined, "Forums", count: emails.where((e) => e['label'] == 'Forums').length, isSelected: selectedLabel == "Forums"),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text("Labels", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          ),
          ...userLabels.map((label) => _buildDrawerItem(Icons.label, label, count: emails.where((e) => e['label'] == label).length, isSelected: selectedLabel == label)).toList(),
          const Divider(), // Added Divider
          ListTile( // Added Logout Button
            leading: const Icon(Icons.logout, color: Colors.black54),
            title: const Text('Đăng xuất', style: TextStyle(color: Colors.black87)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, {bool isSelected = false, int count = 0}) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.redAccent : Colors.black54),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.redAccent : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: count > 0 ? Text(count.toString(), style: const TextStyle(color: Colors.black54)) : null,
      tileColor: isSelected ? const Color(0xFFF6F8FC) : Colors.white,
      shape: isSelected ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)) : null,
      contentPadding: isSelected ? const EdgeInsets.symmetric(horizontal: 24.0) : null,
      onTap: () => onLabelSelected(title),
    );
  }
}

class EmailDetailScreen extends StatefulWidget {
  final Map<String, dynamic> email;
  const EmailDetailScreen({super.key, required this.email});

  @override
  State<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  bool showDetails = false;
  bool isRead = false;
  bool isStarred = false;

  @override
  Widget build(BuildContext context) {
    final email = widget.email;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black54),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Move to Trash',
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(isRead ? Icons.mark_email_unread : Icons.mark_email_read),
            tooltip: isRead ? 'Mark as Unread' : 'Mark as Read',
            onPressed: () {
              setState(() {
                isRead = !isRead;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.label_outline),
            tooltip: 'Assign Labels',
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(isStarred ? Icons.star : Icons.star_border),
            tooltip: isStarred ? 'Unstar' : 'Star',
            onPressed: () {
              setState(() {
                isStarred = !isStarred;
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  backgroundImage: email["avatar"] != null ? AssetImage(email["avatar"]) : null,
                  child: email["avatar"] == null
                      ? Text(
                          (email["sender"] ?? "?")[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email["sender"] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            showDetails = !showDetails;
                          });
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Đến tôi",
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              showDetails ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showDetails) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("From: "+(email["sender"] ?? ""), style: const TextStyle(fontSize: 15, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text("To: you@gmail.com", style: const TextStyle(fontSize: 15, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text("CC: ...", style: const TextStyle(fontSize: 15, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text("BCC: ...", style: const TextStyle(fontSize: 15, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text("Date/Time: "+(email["time"] ?? ""), style: const TextStyle(fontSize: 15, color: Colors.black87)),
                  ],
                ),
              ),
            ],
            const Divider(height: 32),
            Text(
              email["subject"] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
              maxLines: null,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 8),
            Text(email["preview"] ?? "(No content)", style: const TextStyle(fontSize: 16, color: Colors.black87)),
            if (email["hasAttachment"] == true)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  children: const [
                    Icon(Icons.attachment, color: Colors.grey),
                    SizedBox(width: 8),
                    Text("Download Attachment", style: TextStyle(color: Colors.blue)),
                  ],
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.reply,
                label: "Reply",
                onTap: () {},
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ActionButton(
                icon: Icons.forward,
                label: "Forward",
                onTap: () {},
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.backgroundColor = const Color(0xFFF6F8FC)});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black54, size: 20),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class ComposeEmailScreen extends StatefulWidget {
  const ComposeEmailScreen({super.key});
  @override
  State<ComposeEmailScreen> createState() => _ComposeEmailScreenState();
}

class _ComposeEmailScreenState extends State<ComposeEmailScreen> {
  final TextEditingController toController = TextEditingController();
  final TextEditingController ccController = TextEditingController();
  final TextEditingController bccController = TextEditingController();
  final TextEditingController fromController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();

  bool showCcBcc = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Nền trắng hoàn toàn
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("", style: TextStyle(color: Colors.black87)),
        iconTheme: const IconThemeData(color: Colors.black54),
        actions: [
          IconButton(icon: const Icon(Icons.attach_file), onPressed: () {}),
          IconButton(icon: const Icon(Icons.save), onPressed: () {}),
          IconButton(icon: const Icon(Icons.close), onPressed: () { Navigator.pop(context); }),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(0),
        child: Container(
          color: Colors.white, // Nền trắng hoàn toàn
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text("Đến", style: TextStyle(fontSize: 16, color: Colors.black87)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: toController,
                      cursorColor: Colors.black,
                      style: const TextStyle(color: Colors.black87, fontSize: 16),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 32,
                    child: IconButton(
                      icon: Icon(showCcBcc ? Icons.expand_less : Icons.expand_more, size: 22, color: Colors.black54),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          showCcBcc = !showCcBcc;
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (showCcBcc) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text("Cc", style: TextStyle(fontSize: 16, color: Colors.black87)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: ccController,
                        cursorColor: Colors.black,
                        style: const TextStyle(color: Colors.black87, fontSize: 16),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 36), // Để căn icon cho thẳng hàng
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text("Bcc", style: TextStyle(fontSize: 16, color: Colors.black87)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: bccController,
                        cursorColor: Colors.black,
                        style: const TextStyle(color: Colors.black87, fontSize: 16),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 36),
                  ],
                ),
              ],
              const Divider(height: 24, color: Color(0xFFE0E0E0)),
              Row(
                children: [
                  const Text("Từ", style: TextStyle(fontSize: 16, color: Colors.black87)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fromController,
                      cursorColor: Colors.black,
                      style: const TextStyle(color: Colors.black87, fontSize: 16),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: "Nhập email gửi đi",
                        hintStyle: TextStyle(color: Colors.black38),
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 32,
                    child: Icon(Icons.expand_more, size: 22, color: Colors.black54),
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFE0E0E0)),
              TextField(
                controller: subjectController,
                cursorColor: Colors.black,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                decoration: const InputDecoration(
                  labelText: "Tiêu đề",
                  border: InputBorder.none,
                  labelStyle: TextStyle(color: Colors.black54),
                ),
              ),
              const Divider(height: 24, color: Color(0xFFE0E0E0)),
              TextField(
                controller: bodyController,
                cursorColor: Colors.black,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: "Soạn email",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.black54),
                ),
                maxLines: 12,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F8FC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Color(0xFFE0E0E0), width: 1),
                    ),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {},
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.send, color: Color(0xFF5F6368), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Gửi",
                                style: TextStyle(
                                  color: Color(0xFF5F6368),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchResultsScreen extends StatelessWidget {
  final String query;
  final List<Map<String, dynamic>> results;
  const SearchResultsScreen({super.key, required this.query, required this.results});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Search: "$query"', style: const TextStyle(color: Colors.black87)),
        iconTheme: const IconThemeData(color: Colors.black54),
      ),
      body: Container(
        color: const Color(0xFFF6F8FC),
        child: ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final email = results[index];
            return ListTile(
              leading: CircleAvatar(backgroundImage: AssetImage(email["avatar"] ?? "images/google.png")),
              title: Text(email["sender"] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(email["subject"] ?? ''),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EmailDetailScreen(email: email)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class AdvancedSearchDialog extends StatelessWidget {
  const AdvancedSearchDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController keywordController = TextEditingController();
    DateTime? fromDate;
    DateTime? toDate;
    bool hasAttachment = false;

    return AlertDialog(
      title: const Text("Advanced Search", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keywordController,
              decoration: const InputDecoration(
                labelText: "Keyword",
                hintText: "Enter keyword",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onTap: () async {
                      final result = await showDatePicker(
                        context: context,
                        initialDate: fromDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (result != null) {
                        fromDate = result;
                      }
                    },
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "From",
                      hintText: fromDate != null ? "${fromDate!.day}/${fromDate!.month}/${fromDate!.year}" : "Select date",
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onTap: () async {
                      final result = await showDatePicker(
                        context: context,
                        initialDate: toDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (result != null) {
                        toDate = result;
                      }
                    },
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "To",
                      hintText: toDate != null ? "${toDate!.day}/${toDate!.month}/${toDate!.year}" : "Select date",
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text("Has attachment?", style: TextStyle(fontSize: 16, color: Colors.black87)),
                const SizedBox(width: 8),
                Switch(
                  value: hasAttachment,
                  onChanged: (value) {
                    hasAttachment = value;
                  },
                  activeColor: Colors.redAccent,
                  inactiveTrackColor: Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("Cancel", style: TextStyle(color: Colors.black54)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'keyword': keywordController.text,
              'fromDate': fromDate,
              'toDate': toDate,
              'hasAttachment': hasAttachment,
            });
          },
          child: const Text("Search"),
        ),
      ],
    );
  }
}
