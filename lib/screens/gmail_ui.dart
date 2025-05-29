import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'search_overlay_screen.dart';
import '../widgets/custom_drawer.dart';
import 'email_detail_screen.dart';
import 'compose_email_screen.dart';
import '../widgets/email_list_item.dart';
// Import other screens/widgets used by GmailUI as needed, for example:
// import './login.dart'; // If needed for navigation from GmailUI
// import './settings_screen.dart'; // If needed

class GmailUI extends StatefulWidget {
  GmailUI({super.key});

  @override
  State<GmailUI> createState() => _GmailUIState();
}

class _GmailUIState extends State<GmailUI> {
  bool showDetail = false;
  String selectedLabel = "Inbox";
  bool isDetailedView = true; // Added for display mode

  final List<String> userLabels = ["Work", "Family"];

  // Callback for updating labels from LabelManagementScreen
  void _updateUserLabels(List<String> updatedLabels) {
    setState(() {
      userLabels.clear();
      userLabels.addAll(updatedLabels);
      // userLabels.sort(); // Optional: sort labels
    });
  }

  final List<Map<String, dynamic>> emails = [
    {
      "sender": "Amazon",
      "subject": "Your order has been shipped!",
      "time": "8:30 AM",
      "avatar": "assets/images/amazon.png", // Corrected path
      "preview": "Your package is on the way! Track your shipment here...",
      "hasAttachment": true,
      "label": "Inbox",
      "starred": false,
    },    {
      "sender": "Steam",
      "subject": "New game discounts available",
      "time": "7:45 AM",
      "avatar": "assets/images/steam.png", // Corrected path
      "preview": "Check out the latest deals on your wishlist games!",
      "hasAttachment": false,
      "label": "Promotions",
      "starred": false,
    },
    {
      "sender": "Boss",
      "subject": "Project update",
      "time": "Yesterday",
      "avatar": "assets/images/Google.png", // Corrected path
      "preview": "Please send the latest report by EOD.",
      "hasAttachment": true,
      "label": "Work",
      "starred": false,
    },
    // ...other emails... Ensure all "avatar" paths here also start with "assets/images/"
    // For example, if you have an entry for "mahiru.png", it should be:
    // {
    //   ...
    //   "avatar": "assets/images/mahiru.png",
    //   ...
    // },
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
                    backgroundImage: AssetImage("assets/images/mahiru.png"),
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
        emails: emails,
        onUserLabelsUpdated: _updateUserLabels, // Pass the callback here
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 18.0, right: 15.0, top: 8.0, bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedLabel.toUpperCase(),
                  style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
                ),
                IconButton(
                  icon: Icon(
                    isDetailedView ? Icons.view_list_outlined : Icons.view_comfortable_outlined,
                    color: Colors.black54,
                    size: 22, // Slightly increased size for better visibility
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: isDetailedView ? 'Switch to compact view' : 'Switch to comfortable view',
                  onPressed: () {
                    setState(() {
                      isDetailedView = !isDetailedView;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredEmails.length,
              itemBuilder: (context, index) {
                final email = filteredEmails[index];
                // bool isStarred = email['starred'] == true; // Moved into a StatefulWidget for the ListTile
                bool isUnread = email["read"] == false;

                return EmailListItem(
                  email: email,
                  isDetailedView: isDetailedView,
                  isUnread: isUnread,
                  onTap: () {
                    setState(() {
                      email["read"] = true; // Mark as read on tap
                    });
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EmailDetailScreen(email: email),
                      ),
                    );
                  },
                  onStarPressed: (bool newStarState) {
                    setState(() {
                      email['starred'] = newStarState;
                      // Here you would typically also update your backend or persistent storage
                    });
                  },
                );
              },
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
